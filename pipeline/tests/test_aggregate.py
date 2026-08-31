from pipeline.models import ParseRecord
from pipeline.aggregate import aggregate, rating_to_pct


def _rec(stats, sig="A", gear=None, cons=None):
    return ParseRecord(
        class_id=1, spec_id=71, content="raid", stats=stats,
        talent_import="", talent_sig=sig,
        gear=gear or [{"slot": "HEAD", "item_id": 100, "enchant_id": 0, "gems": []}],
        consumables=cons or {"flask": 212283, "food": None, "phial": None,
                             "potion": None, "oil": None, "rune": None},
    )


SEASON = {"RATING_PER_PCT": {"haste": 700.0, "crit": 700.0, "vers": 780.0, "mastery": 700.0},
          "MASTERY_COEFF": {71: 2.0}}


def test_rating_to_pct_secondary_and_mastery():
    assert rating_to_pct("haste", 7000, 71, SEASON) == 10.0
    # Mastery: 7000/700 = 10 Punkte * COEFF 2.0 = 20 %
    assert rating_to_pct("mastery", 7000, 71, SEASON) == 20.0


def test_aggregate_medians_and_order():
    recs = [
        _rec({"haste": 7000, "crit": 5600, "mastery": 3500, "vers": 3900}),
        _rec({"haste": 7700, "crit": 4900, "mastery": 3500, "vers": 3900}),
        _rec({"haste": 6300, "crit": 6300, "mastery": 3500, "vers": 3900}),
    ]
    agg = aggregate(recs, spec_id=71, season=SEASON,
                    item_name=lambda i: f"item{i}")
    assert agg.sample_size == 3
    # Median haste = 7000 -> 10%; crit median 5600 -> 8%; mastery 3500/700*2=10%; vers 3900/780=5%
    pct = {s["key"]: s["pct"] for s in agg.stats}
    assert pct["haste"] == 10.0 and pct["crit"] == 8.0
    assert pct["mastery"] == 10.0 and pct["vers"] == 5.0
    # absteigend sortiert
    assert [s["pct"] for s in agg.stats] == sorted((s["pct"] for s in agg.stats), reverse=True)


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
