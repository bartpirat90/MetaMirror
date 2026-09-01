from pipeline.fetch import parse_combatant_info
from pipeline.tests.fixtures import COMBATANT_INFO


SEASON = {"CONSUMABLE_SPELL_TO_ITEM": {
    1235108: {"cat": "flask", "item": 212283},
    1285644: {"cat": "food", "item": 222222},
}}


def test_stats_are_flat_ratings():
    rec = parse_combatant_info(COMBATANT_INFO, class_id=7, spec_id=262,
                               content="raid", season=SEASON)
    assert rec.stats == {"haste": 734, "crit": 1021, "mastery": 936, "vers": 203}


def test_gear_index_is_slot_and_gems_extracted():
    rec = parse_combatant_info(COMBATANT_INFO, class_id=7, spec_id=262,
                               content="raid", season=SEASON)
    head = [g for g in rec.gear if g["slot"] == "HEAD"][0]
    assert head["item_id"] == 271483 and head["enchant_id"] == 7961 and head["gems"] == []
    assert head["item_level"] == 311 and head["bonus_ids"] == [6652]
    neck = [g for g in rec.gear if g["slot"] == "NECK"][0]
    assert neck["item_id"] == 268265 and neck["gems"] == [240983, 240908]
    assert neck["item_level"] == 308 and neck["bonus_ids"] == [6652, 13668]
    # leeres Gear-Element (id 0) wird uebersprungen
    assert all(g["item_id"] != 0 for g in rec.gear)


def test_consumables_from_auras_via_whitelist():
    rec = parse_combatant_info(COMBATANT_INFO, class_id=7, spec_id=262,
                               content="raid", season=SEASON)
    assert rec.consumables["flask"] == 212283
    assert rec.consumables["food"] == 222222
    assert rec.consumables["potion"] is None   # Battle Shout ist kein Consumable


def test_talent_signature_sorted_by_node():
    rec = parse_combatant_info(COMBATANT_INFO, class_id=7, spec_id=262,
                               content="raid", season=SEASON)
    assert rec.talent_sig == "80978:1|80981:1"
    assert rec.talent_import == ""
