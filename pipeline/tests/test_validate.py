from pipeline.models import AggregatedSpec
from pipeline.validate import validate


def _good():
    return AggregatedSpec(
        sample_size=30,
        stats=[{"key": "haste", "rating": 961}, {"key": "crit", "rating": 1371},
               {"key": "mastery", "rating": 590}, {"key": "vers", "rating": 110}],
        gear=[{"slot": "HEAD", "itemID": 21001, "name": "Helm"}],
        gems=[], enchants=[], consumables={"flask": 212283},
    )


def test_good_data_has_no_errors():
    assert validate({1: {71: {"raid": _good()}}}, min_sample=15) == []


def test_low_sample_flagged():
    a = _good(); a.sample_size = 5
    errs = validate({1: {71: {"raid": a}}}, min_sample=15)
    assert any("sampleSize" in e for e in errs)


def test_negative_rating_flagged():
    a = _good(); a.stats[0]["rating"] = -5
    errs = validate({1: {71: {"raid": a}}}, min_sample=15)
    assert any("rating" in e for e in errs)


def test_empty_gear_flagged():
    a = _good(); a.gear = []
    errs = validate({1: {71: {"raid": a}}}, min_sample=15)
    assert any("gear" in e for e in errs)


def test_zero_itemid_flagged():
    a = _good(); a.gear = [{"slot": "HEAD", "itemID": 0, "name": "x"}]
    errs = validate({1: {71: {"raid": a}}}, min_sample=15)
    assert any("itemID" in e for e in errs)
