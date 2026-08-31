from collections import Counter
from statistics import median
from pipeline.models import AggregatedSpec
from pipeline.specs import STAT_KEYS

_CONS_CATS = ["flask", "phial", "potion", "food", "oil", "rune"]


def rating_to_pct(stat, rating, spec_id, season):
    per_pct = season["RATING_PER_PCT"][stat]
    pct = rating / per_pct
    if stat == "mastery":
        pct *= season.get("MASTERY_COEFF", {}).get(spec_id, 1.0)
    return round(pct, 1)


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
        stats.append({"key": key, "pct": rating_to_pct(key, med, spec_id, season)})
    stats.sort(key=lambda s: s["pct"], reverse=True)

    sig, cnt = _most_common([r.talent_sig for r in records])
    imports = [r.talent_import for r in records if r.talent_sig == sig and r.talent_import]
    talents = [{"importString": imports[0] if imports else "",
                "usagePct": round(100 * cnt / n) if n else 0}]

    slot_items = {}
    slot_enchant = {}
    slot_gems = {}
    for r in records:
        for g in r.gear:
            slot_items.setdefault(g["slot"], []).append(g["item_id"])
            if g.get("enchant_id"):
                slot_enchant.setdefault(g["slot"], []).append(g["enchant_id"])
            for gem in g.get("gems", []):
                slot_gems.setdefault(g["slot"], []).append(gem)

    gear = []
    for slot, items in slot_items.items():
        item_id, _ = _most_common(items)
        if item_id:
            gear.append({"slot": slot, "itemID": item_id, "name": item_name(item_id)})
    gear.sort(key=lambda g: g["slot"])

    gems = []
    for slot, ids in slot_gems.items():
        gem_id, _ = _most_common(ids)
        if gem_id:
            gems.append({"slot": slot, "itemID": gem_id, "name": item_name(gem_id)})
    gems.sort(key=lambda g: g["slot"])

    enchants = []
    for slot, ids in slot_enchant.items():
        ench_id, _ = _most_common(ids)
        if ench_id:
            enchants.append({"slot": slot, "id": ench_id, "name": f"enchant:{ench_id}"})
    enchants.sort(key=lambda e: e["slot"])

    consumables = {}
    for cat in _CONS_CATS:
        item_id, _ = _most_common([r.consumables.get(cat) for r in records])
        if item_id:
            consumables[cat] = item_id

    return AggregatedSpec(sample_size=n, stats=stats, talents=talents,
                          gear=gear, gems=gems, enchants=enchants, consumables=consumables)
