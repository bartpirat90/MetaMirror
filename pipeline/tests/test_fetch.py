from pipeline.fetch import parse_combatant_info
from pipeline.tests.fixtures import COMBATANT_INFO


def test_parse_combatant_info_maps_stats_gear_consumables():
    season = {
        "CONSUMABLE_SPELL_TO_ITEM": {431971: {"cat": "flask", "item": 212283}},
        "SLOT_NAME": {0: "HEAD", 15: "MAINHAND"},
    }
    rec = parse_combatant_info(COMBATANT_INFO, class_id=1, spec_id=71,
                               content="mythicplus", season=season)
    assert rec.stats == {"haste": 7000, "crit": 5600, "mastery": 4200, "vers": 3120}
    assert {"slot": "HEAD", "item_id": 21001, "enchant_id": 0, "gems": []} in rec.gear
    assert rec.consumables["flask"] == 212283
    assert rec.consumables.get("food") is None
    assert rec.talent_sig == "111:1|222:2"
    assert rec.class_id == 1 and rec.spec_id == 71 and rec.content == "mythicplus"
