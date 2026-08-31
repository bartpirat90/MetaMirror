from pipeline.models import AggregatedSpec
from pipeline.emit_lua import emit_lua


def _agg():
    return AggregatedSpec(
        sample_size=42,
        stats=[{"key": "haste", "pct": 34.0}, {"key": "crit", "pct": 28.0}],
        talents=[{"importString": "ABC=", "usagePct": 68}],
        gear=[{"slot": "HEAD", "itemID": 21001, "name": "Helm"}],
        gems=[{"slot": "RING1", "itemID": 90001, "name": "+Haste"}],
        enchants=[{"slot": "MAINHAND", "id": 7001, "name": "enchant:7001"}],
        consumables={"flask": 212283, "food": 222},
    )


def test_emit_structure_and_values():
    data = {1: {71: {"mythicplus": _agg(), "raid": _agg()}}}
    out = emit_lua(data, version="wcl-2026-08-31", season="TWW-S1")
    assert "MetaMirrorData = {" in out
    assert 'version = "wcl-2026-08-31"' in out
    assert 'attribution = "Data from Warcraft Logs"' in out
    assert "[1] = {" in out and "[71] = {" in out
    assert "mythicplus = {" in out and "raid = {" in out
    assert 'sampleSize = 42' in out
    assert '{ key = "haste", pct = 34.0 }' in out
    assert 'importString = "ABC="' in out
    assert 'itemID = 21001' in out
    assert 'flask = 212283' in out
    # balancierte Klammern
    assert out.count("{") == out.count("}")


def test_emit_is_deterministic():
    data = {1: {71: {"raid": _agg()}}}
    a = emit_lua(data, version="v", season="s")
    b = emit_lua(data, version="v", season="s")
    assert a == b
