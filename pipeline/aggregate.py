from collections import Counter
from statistics import median
from pipeline.models import AggregatedSpec
from pipeline.specs import STAT_KEYS

_CONS_CATS = ["flask", "phial", "potion", "food", "oil", "rune"]


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

    sig, cnt = _most_common([r.talent_sig for r in records])
    imports = [r.talent_import for r in records if r.talent_sig == sig and r.talent_import]
    talents = [{"importString": imports[0] if imports else "",
                "usagePct": round(100 * cnt / n) if n else 0}]

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

    gear = []
    for slot, entries in slot_gear.items():
        item_id, _ = _most_common([g["item_id"] for g in entries])
        if not item_id:
            continue
        # "maximale moegliche Gearstufe": unter den Traegern dieses Items die hoechste
        # itemLevel-Variante nehmen -> deren bonusIDs bringen Sockel + Upgrade-Stufe mit.
        variants = [g for g in entries if g["item_id"] == item_id]
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

    return AggregatedSpec(sample_size=n, stats=stats, talents=talents,
                          gear=gear, gems=gems, enchants=enchants, consumables=consumables)
