from pipeline.models import AggregatedSpec
from pipeline.emit_lua import emit_lua


def _agg():
    return AggregatedSpec(
        sample_size=42,
        stats=[{"key": "haste", "rating": 961}, {"key": "crit", "rating": 1371}],
        gear=[{"slot": "HEAD", "itemID": 21001, "itemLevel": 311,
               "bonusIDs": [6652, 12843], "name": "Helm"}],
        gems=[{"slot": "RING1", "itemID": 90001, "name": "+Haste"}],
        enchants=[{"slot": "MAINHAND", "id": 7001, "itemID": 243971, "name": "enchant:7001"}],
        consumables={"flask": 212283, "food": 222},
    )


def test_emit_structure_and_values():
    data = {1: {71: {"mythicplus": _agg(), "raid": _agg()}}}
    out = emit_lua(data, version="sim-2026-08-31", season="TWW-S1")
    assert "MetaMirrorData = {" in out
    assert 'version = "sim-2026-08-31"' in out
    assert 'attribution = "Data from bloodmallet.com (SimulationCraft)"' in out
    assert "[1] = {" in out and "[71] = {" in out
    assert "mythicplus = {" in out and "raid = {" in out
    assert 'sampleSize = 42' in out
    assert '{ key = "haste", rating = 961 }' in out
    assert 'talents' not in out
    assert 'itemID = 21001' in out
    assert 'itemLevel = 311' in out
    assert 'bonusIDs = { 6652, 12843 }' in out
    assert 'flask = 212283' in out
    # balancierte Klammern
    assert out.count("{") == out.count("}")


def test_emit_is_deterministic():
    data = {1: {71: {"raid": _agg()}}}
    a = emit_lua(data, version="v", season="s")
    b = emit_lua(data, version="v", season="s")
    assert a == b


def test_emit_attribution_override():
    data = {1: {71: {"raid": _agg()}}}
    out = emit_lua(data, version="v", season="s", attribution="Custom attribution")
    assert 'attribution = "Custom attribution"' in out
    assert "Warcraft Logs" not in out


def test_emit_extra_fields_flat_and_nested_sorted_after_season():
    data = {1: {71: {"raid": _agg()}}}
    extra = {
        "generated": "2026-09-04",
        "simcHash": "f869791",
        "fightStyles": {"raid": "castingpatchwerk", "mythicplus": "castingpatchwerk3"},
    }
    out = emit_lua(data, version="v", season="s", extra=extra)
    assert 'generated = "2026-09-04"' in out
    assert 'simcHash = "f869791"' in out
    assert 'fightStyles = { mythicplus = "castingpatchwerk3", raid = "castingpatchwerk" }' in out
    # deterministisch nach Key sortiert: fightStyles < generated < simcHash
    season_pos = out.index('season = "s"')
    fs_pos = out.index("fightStyles =")
    gen_pos = out.index("generated =")
    hash_pos = out.index("simcHash =")
    attr_pos = out.index("attribution =")
    assert season_pos < fs_pos < gen_pos < hash_pos < attr_pos


def test_emit_extra_none_omits_no_extra_lines():
    data = {1: {71: {"raid": _agg()}}}
    out = emit_lua(data, version="v", season="s", extra=None)
    lines_between = out.split('season = "s",')[1].split("attribution =")[0]
    assert lines_between.strip() == ""
