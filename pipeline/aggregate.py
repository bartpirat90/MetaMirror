from collections import Counter, defaultdict
from statistics import median
from pipeline.models import AggregatedSpec
from pipeline.specs import STAT_KEYS

_CONS_CATS = ["flask", "phial", "potion", "food", "oil", "rune"]

# ===== Trinket-Tierliste aus WCL-Nutzung (empirisch, statt Sim) =====
# Beide Schmuck-Slots werden gepoolt und nach Haeufigkeit gerankt; Tier = Anteil am
# meistgenutzten Trinket. Bewusst nutzungsbasiert (passt zu "Ist statt Soll"): S/A/B/C/D
# heisst "wie oft die Top-Parses es anlegen", nicht simulierter DPS.
_TRINKET_SLOTS = ("TRINKET1", "TRINKET2")
_TRINKET_MAX = 12
# Schwellen als Anteil am Top-Count (absteigend); erster Treffer gewinnt, Top -> S.
_TRINKET_TIER_CUTS = [(0.70, "S"), (0.45, "A"), (0.25, "B"), (0.10, "C")]


def trinket_view(records, item_name):
    """records (eines Specs, evtl. gemischter Content) -> gerankte, getierte Trinket-Liste."""
    counts = Counter()
    for r in records:
        for g in r.gear:
            if g.get("slot") in _TRINKET_SLOTS and g.get("item_id"):
                counts[g["item_id"]] += 1
    if not counts:
        return []
    ranked = counts.most_common()
    top = ranked[0][1] or 1
    out = []
    for iid, c in ranked[:_TRINKET_MAX]:
        frac = c / top
        tier = "D"
        for cut, letter in _TRINKET_TIER_CUTS:
            if frac >= cut:
                tier = letter
                break
        out.append({"itemID": iid, "tier": tier, "name": item_name(iid)})
    return out


def build_trinket_table(records, item_name, only_specs=None):
    """Flache Recordliste -> {spec_id: {overall, raid, dungeon}} als Tierlisten.
    only_specs: optionale Menge erlaubter spec_ids (duenne Specs auslassen)."""
    by_spec = defaultdict(lambda: {"raid": [], "dungeon": [], "all": []})
    for r in records:
        if only_specs is not None and r.spec_id not in only_specs:
            continue
        b = by_spec[r.spec_id]
        b["all"].append(r)
        if r.content == "raid":
            b["raid"].append(r)
        elif r.content == "mythicplus":
            b["dungeon"].append(r)
    table = {}
    for sid, b in by_spec.items():
        views = {
            "overall": trinket_view(b["all"], item_name),
            "raid": trinket_view(b["raid"], item_name),
            "dungeon": trinket_view(b["dungeon"], item_name),
        }
        if views["overall"] or views["raid"] or views["dungeon"]:
            table[sid] = views
    return table


def _most_common(values):
    values = [v for v in values if v]
    if not values:
        return None, 0
    item, count = Counter(values).most_common(1)[0]
    return item, count


# ===== Hero-Talent-Baum-Aufteilung (empirisch aus den Knoten) =====
# WoW-Specs haben zwei Hero-Talent-Baeume; die Meta-Empfehlung wird pro Baum getrennt.
# In den WCL-Daten kennen wir den Knotentyp NICHT, leiten den SubTreeSelection-Knoten
# aber sicher ab: er ist der Knoten, dessen entryID einen grossen EXKLUSIVEN Cluster
# schaltet (jeder Hero-Baum bringt ~10 eigene, sich gegenseitig ausschliessende Knoten).
# Normale Choice-Nodes schalten keinen exklusiven Cluster -> Score 0.
_HERO_EXCL_MIN = 3          # so viele exklusive Knoten muss die Baumwahl schalten
_HERO_KEEP_FRAC = 0.15      # Hero-Baeume unter diesem Nutzungsanteil (und <2 Parses) fallen weg


def _exclusive_score(groups, present):
    """Wie viele Knoten sind exklusiv fuer genau eine entryID-Gruppe (>=75% hier, <=25% sonst)?"""
    keys = list(groups)
    all_nodes = set().union(*present) if present else set()
    score = 0
    for nid in all_nodes:
        rates = []
        for k in keys:
            idxs = groups[k]
            rates.append(sum(1 for i in idxs if nid in present[i]) / len(idxs) if idxs else 0.0)
        rates.sort()
        top = rates[-1]
        second = rates[-2] if len(rates) > 1 else 0.0
        if top >= 0.75 and second <= 0.25:
            score += 1
    return score


def _detect_subtree(records):
    """Findet (subtreeNodeID, {entryID: [parse-idx]}) oder None, wenn keine klare Baumwahl."""
    node_maps = [{nd["nodeID"]: nd for nd in (r.talent_nodes or []) if nd.get("nodeID")}
                 for r in records]
    present = [set(m.keys()) for m in node_maps]
    n = len(records)
    if n == 0:
        return None
    counts = Counter()
    for s in present:
        counts.update(s)
    best, best_score, best_groups = None, 0, None
    for nid, cnt in counts.items():
        if cnt < 0.5 * n:
            continue
        groups = defaultdict(list)
        for i, m in enumerate(node_maps):
            nd = m.get(nid)
            if nd and nd.get("entryID"):
                groups[nd["entryID"]].append(i)
        if len(groups) < 2:
            continue
        score = _exclusive_score(groups, present)
        if score > best_score:
            best, best_score, best_groups = nid, score, groups
    if best is None or best_score < _HERO_EXCL_MIN:
        return None
    return best, best_groups


def _build_from_idxs(records, idxs, n, hero_node, hero_entry, usage_pct):
    """Meistgenutzter Build innerhalb einer Parse-Auswahl -> Build-Dict fuer die Lua-Daten."""
    sig, _ = _most_common([records[i].talent_sig for i in idxs])
    rep_nodes = next((records[i].talent_nodes for i in idxs
                      if records[i].talent_sig == sig and records[i].talent_nodes), [])
    imports = [records[i].talent_import for i in idxs
               if records[i].talent_sig == sig and records[i].talent_import]
    return {"importString": imports[0] if imports else "",
            "usagePct": usage_pct, "strongest": False,
            "heroNode": int(hero_node or 0), "heroEntryID": int(hero_entry or 0),
            "nodes": rep_nodes}


def build_talents(records):
    """Talent-Builds pro Hero-Baum (meistgenutzter zuerst, als 'strongest' markiert).
    Ohne erkennbare Baumwahl: ein Build mit Sig-Anteil als Nutzungsquote (altes Verhalten)."""
    n = len(records)
    if n == 0:
        return []
    detect = _detect_subtree(records)
    if not detect:
        _, cnt = _most_common([r.talent_sig for r in records])
        b = _build_from_idxs(records, list(range(n)), n, 0, 0,
                             round(100 * cnt / n) if n else 0)
        b["strongest"] = True
        return [b]

    hero_node, groups = detect
    builds = [_build_from_idxs(records, idxs, n, hero_node, entry, round(100 * len(idxs) / n))
              for entry, idxs in groups.items()]
    # nach Nutzung (Gruppengroesse) sortieren; Ausreisser-Baeume verwerfen, groessten behalten.
    builds.sort(key=lambda b: (-b["usagePct"], b["heroEntryID"]))
    keep = [b for b in builds
            if len(groups[b["heroEntryID"]]) >= max(2, _HERO_KEEP_FRAC * n)]
    if not keep:
        keep = builds[:1]
    keep = keep[:2]
    keep[0]["strongest"] = True
    return keep


def aggregate(records, spec_id, season, item_name):
    """records: list[ParseRecord] eines Spec x Content. item_name: itemID -> Name."""
    n = len(records)

    stats = []
    for key in STAT_KEYS:
        med = median([r.stats.get(key, 0) for r in records])
        stats.append({"key": key, "rating": int(round(med))})
    stats.sort(key=lambda s: s["rating"], reverse=True)

    # Talente pro Hero-Baum getrennt (meistgenutzter Baum = "strongest"); daraus baut das
    # Addon in-game je Build den Aktivieren-Import-String (nodeID/entryID/rank).
    talents = build_talents(records)

    slot_gear = {}
    slot_enchant = {}
    slot_gems = {}
    for r in records:
        for g in r.gear:
            slot_gear.setdefault(g["slot"], []).append(g)
            if g.get("enchant_id"):
                slot_enchant.setdefault(g["slot"], []).append(g["enchant_id"])
            for gem in g.get("gems", []):
                slot_gems.setdefault(g["slot"], []).append(gem)

    picks = {}
    for slot, entries in slot_gear.items():
        picks[slot], _ = _most_common([g["item_id"] for g in entries])
    # Ausruestung ist einmalig anlegbar: die Paar-Slots (zwei Ringe / zwei Schmuck)
    # duerfen nicht dasselbe Item picken. Sonst -> zweithaeufigstes, das != erstes ist.
    for a, b in (("RING1", "RING2"), ("TRINKET1", "TRINKET2")):
        if picks.get(a) and picks.get(a) == picks.get(b) and slot_gear.get(b):
            alt_ids = [g["item_id"] for g in slot_gear[b] if g["item_id"] != picks[a]]
            alt, _ = _most_common(alt_ids)
            if alt:
                picks[b] = alt
    gear = []
    for slot, entries in slot_gear.items():
        item_id = picks.get(slot)
        if not item_id:
            continue
        # "maximale moegliche Gearstufe": unter den Traegern dieses Items die hoechste
        # itemLevel-Variante nehmen -> deren bonusIDs bringen Sockel + Upgrade-Stufe mit.
        variants = [g for g in entries if g["item_id"] == item_id]
        if not variants:
            continue
        best = max(variants, key=lambda g: g.get("item_level", 0))
        gear.append({
            "slot": slot,
            "itemID": item_id,
            "itemLevel": best.get("item_level", 0),
            "bonusIDs": list(best.get("bonus_ids", [])),
            "name": item_name(item_id),
        })
    gear.sort(key=lambda g: g["slot"])

    gems = []
    for slot, ids in slot_gems.items():
        gem_id, _ = _most_common(ids)
        if gem_id:
            gems.append({"slot": slot, "itemID": gem_id, "name": item_name(gem_id)})
    gems.sort(key=lambda g: g["slot"])

    ench_item_map = season.get("ENCHANT_ITEM_BY_ID", {})
    enchants = []
    for slot, ids in slot_enchant.items():
        ench_id, _ = _most_common(ids)
        if ench_id:
            enchants.append({"slot": slot, "id": ench_id,
                             "itemID": int(ench_item_map.get(ench_id, 0)),
                             "name": f"enchant:{ench_id}"})
    enchants.sort(key=lambda e: e["slot"])

    consumables = {}
    for cat in _CONS_CATS:
        item_id, _ = _most_common([r.consumables.get(cat) for r in records])
        if item_id:
            consumables[cat] = item_id
    # Kuration ueberlagert Food/Trank/Oel (nicht aus Logs ableitbar), sofern die
    # Pipeline sie mitgibt. In Tests fehlt der Key -> unveraendertes Log-Verhalten.
    curate = season.get("CURATE_CONSUMABLES")
    if curate:
        consumables = curate(spec_id, consumables)

    return AggregatedSpec(sample_size=n, stats=stats, talents=talents,
                          gear=gear, gems=gems, enchants=enchants, consumables=consumables)
