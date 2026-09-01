from pipeline.models import ParseRecord
from pipeline.aggregate import trinket_view, build_trinket_table


def _rec(spec_id, content, t1, t2):
    gear = [
        {"slot": "TRINKET1", "item_id": t1, "item_level": 300, "enchant_id": 0, "gems": [], "bonus_ids": []},
        {"slot": "TRINKET2", "item_id": t2, "item_level": 300, "enchant_id": 0, "gems": [], "bonus_ids": []},
    ]
    return ParseRecord(class_id=9, spec_id=spec_id, content=content, stats={},
                       talent_import="", talent_sig="A", gear=gear,
                       consumables={})


def _name(i):
    return f"item:{i}"


def test_trinket_view_pools_both_slots_and_tiers_by_usage():
    # 900 taucht in fast jedem Loadout auf (Top), 901 haeufig, 999 einmalig.
    recs = [
        _rec(266, "raid", 900, 901),
        _rec(266, "raid", 900, 901),
        _rec(266, "raid", 900, 999),
    ]
    view = trinket_view(recs, _name)
    by_id = {e["itemID"]: e["tier"] for e in view}
    # Counts: 900:3 (Top -> S), 901:2 (0.66 -> A), 999:1 (0.33 -> B)
    assert by_id[900] == "S"
    assert by_id[901] == "A"
    assert by_id[999] == "B"
    # nach Haeufigkeit sortiert
    assert view[0]["itemID"] == 900
    assert view[0]["name"] == "item:900"


def test_trinket_view_empty_without_trinkets():
    assert trinket_view([], _name) == []


def test_build_trinket_table_splits_content_and_overall():
    recs = [
        _rec(266, "raid", 900, 901),
        _rec(266, "raid", 900, 901),
        _rec(266, "mythicplus", 800, 801),
        _rec(266, "mythicplus", 800, 802),
        _rec(71, "raid", 500, 501),
    ]
    table = build_trinket_table(recs, _name)
    demo = table[266]
    raid_ids = {e["itemID"] for e in demo["raid"]}
    dung_ids = {e["itemID"] for e in demo["dungeon"]}
    overall_ids = {e["itemID"] for e in demo["overall"]}
    assert raid_ids == {900, 901}
    assert dung_ids == {800, 801, 802}
    assert overall_ids == {900, 901, 800, 801, 802}   # gepoolt
    assert 71 in table


def test_build_trinket_table_respects_only_specs():
    recs = [_rec(266, "raid", 900, 901), _rec(71, "raid", 500, 501)]
    table = build_trinket_table(recs, _name, only_specs={266})
    assert set(table.keys()) == {266}
