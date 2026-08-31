from pipeline.models import ParseRecord
from pipeline.aggregate import aggregate


def _rec(stats, sig="A", gear=None, cons=None):
    return ParseRecord(
        class_id=1, spec_id=71, content="raid", stats=stats,
        talent_import="", talent_sig=sig,
        gear=gear or [{"slot": "HEAD", "item_id": 100, "enchant_id": 0, "gems": []}],
        consumables=cons or {"flask": 212283, "food": None, "phial": None,
                             "potion": None, "oil": None, "rune": None},
    )


SEASON = {}   # fuer Ratings-Vergleich nicht mehr noetig


def test_aggregate_median_ratings_and_order():
    recs = [
        _rec({"haste": 7000, "crit": 5600, "mastery": 3500, "vers": 3900}),
        _rec({"haste": 7700, "crit": 4900, "mastery": 3500, "vers": 3900}),
        _rec({"haste": 6300, "crit": 6300, "mastery": 3500, "vers": 3900}),
    ]
    agg = aggregate(recs, spec_id=71, season=SEASON, item_name=lambda i: f"item{i}")
    assert agg.sample_size == 3
    rating = {s["key"]: s["rating"] for s in agg.stats}
    # Mediane: haste 7000, crit 5600, mastery 3500, vers 3900
    assert rating == {"haste": 7000, "crit": 5600, "mastery": 3500, "vers": 3900}
    # absteigend nach Rating sortiert
    assert [s["rating"] for s in agg.stats] == sorted((s["rating"] for s in agg.stats), reverse=True)
    assert agg.stats[0]["key"] == "haste"   # hoechstes Rating


def test_aggregate_most_common_talent_and_gear_and_consumables():
    recs = [
        _rec({"haste": 7000, "crit": 5600, "mastery": 3500, "vers": 3900}, sig="A"),
        _rec({"haste": 7000, "crit": 5600, "mastery": 3500, "vers": 3900}, sig="A"),
        _rec({"haste": 7000, "crit": 5600, "mastery": 3500, "vers": 3900}, sig="B"),
    ]
    agg = aggregate(recs, spec_id=71, season=SEASON, item_name=lambda i: f"item{i}")
    assert agg.talents[0]["usagePct"] == 67          # 2 von 3
    assert agg.gear[0]["slot"] == "HEAD" and agg.gear[0]["itemID"] == 100
    assert agg.gear[0]["name"] == "item100"
    assert agg.consumables["flask"] == 212283
    assert "food" not in agg.consumables               # None-Kategorien entfallen
