from collections import Counter, defaultdict
from statistics import median
from pipeline.models import AggregatedSpec
from pipeline.specs import STAT_KEYS
from pipeline.season import (TRINKET_MIN_ILVL, TRINKET_CURRENT_TRACK_BONUS,
                             TRINKET_PREV_SEASON_BONUS, TRINKET_MIN_LIFTABLE_PARSES)

_CONS_CATS = ["flask", "phial", "potion", "food", "oil", "rune"]

# ===== Trinket-Tierliste aus WCL-Nutzung (empirisch, statt Sim) =====
# Beide Schmuck-Slots werden gepoolt und nach Haeufigkeit gerankt; Tier = Anteil am
# meistgenutzten Trinket. Bewusst nutzungsbasiert (passt zu "Ist statt Soll"): S/A/B/C/D
# heisst "wie oft die Top-Parses es anlegen", nicht simulierter DPS.
_TRINKET_SLOTS = ("TRINKET1", "TRINKET2")
_TRINKET_MAX = 12
# Schwellen als Anteil am Top-Count (absteigend); erster Treffer gewinnt, Top -> S.
_TRINKET_TIER_CUTS = [(0.70, "S"), (0.45, "A"), (0.25, "B"), (0.10, "C")]


def trinket_view(records, item_name, floor=TRINKET_MIN_ILVL,
                 track_bonus=TRINKET_CURRENT_TRACK_BONUS,
                 prev_bonus=TRINKET_PREV_SEASON_BONUS,
                 min_liftable=TRINKET_MIN_LIFTABLE_PARSES):
    """records (eines Specs, evtl. gemischter Content) -> gerankte, getierte Trinket-Liste.
    Vorsaison-/PvP-Trinkets werden herausgefiltert. Ob ein Trinket auf Season-2-Niveau
    HEBBAR ist, wird primaer ueber Upgrade-Track-Bonus-IDs entschieden (praeziser als Ilvl):
      - traegt ein Gear-Eintrag einen Vorsaison-Marker (TRINKET_PREV_SEASON_BONUS), zaehlt
        dieser Eintrag NIE als hebbar, egal wie hoch sein Ilvl ist (hartes Aus).
      - sonst zaehlt ein Eintrag mit S2-Track-Bonus (TRINKET_CURRENT_TRACK_BONUS) als
        POSITIVBEWEIS, selbst wenn sein Ilvl unter dem Floor liegt (z.B. Hero 5/6 = 318).
      - sonst faellt der Eintrag auf den Ilvl-Pfad zurueck (>= floor); hier braucht es
        mindestens min_liftable solche Parses (Ausreisser-Schutz: ein einzelner hoher
        Ilvl-Parse haelt sonst allein ein altes Item in der Liste).
    Ein Trinket bleibt, wenn es mindestens einen Track-Bonus-Treffer ODER genug
    Ilvl-Treffer hat. Das Ranking (counts) zaehlt weiterhin ALLE Vorkommen, unabhaengig
    vom Filter -- der Filter entscheidet nur ueber bleiben/raus."""
    counts = Counter()
    track_hits = Counter()
    ilvl_hits = Counter()
    for r in records:
        for g in r.gear:
            if g.get("slot") in _TRINKET_SLOTS and g.get("item_id"):
                iid = g["item_id"]
                counts[iid] += 1
                bonus = set(g.get("bonus_ids") or [])
                if bonus & prev_bonus:
                    continue
                if bonus & track_bonus:
                    track_hits[iid] += 1
                elif (g.get("item_level") or 0) >= floor:
                    ilvl_hits[iid] += 1
    for iid in [i for i in counts
                if track_hits.get(i, 0) < 1 and ilvl_hits.get(i, 0) < min_liftable]:
        del counts[iid]
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


def build_trinket_table(records, item_name, only_specs=None, floor=None):
    """Flache Recordliste -> {spec_id: {overall, raid, dungeon}} als Tierlisten.
    only_specs: optionale Menge erlaubter spec_ids (duenne Specs auslassen).
    floor: Ilvl-Floor fuer den Ilvl-Pfad von trinket_view; None = Konstante aus season.py.
    Die Pipeline (run.py) leitet ihn ueber season_markers aus den Daten selbst ab."""
    view_kw = {} if floor is None else {"floor": floor}
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
            "overall": trinket_view(b["all"], item_name, **view_kw),
            "raid": trinket_view(b["raid"], item_name, **view_kw),
            "dungeon": trinket_view(b["dungeon"], item_name, **view_kw),
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


def aggregate(records, spec_id, season, item_name):
    """records: list[ParseRecord] eines Spec x Content. item_name: itemID -> Name."""
    n = len(records)

    stats = []
    for key in STAT_KEYS:
        med = median([r.stats.get(key, 0) for r in records])
        stats.append({"key": key, "rating": int(round(med))})
    stats.sort(key=lambda s: s["rating"], reverse=True)

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

    return AggregatedSpec(sample_size=n, stats=stats,
                          gear=gear, gems=gems, enchants=enchants, consumables=consumables)
