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


def test_talent_nodes_capture_entry_id():
    # id aus WCL = gewaehlte Entry-ID -> muss pro Node mit nodeID/rank erhalten bleiben,
    # damit das Addon Choice-Nodes korrekt serialisieren kann.
    rec = parse_combatant_info(COMBATANT_INFO, class_id=7, spec_id=262,
                               content="raid", season=SEASON)
    assert rec.talent_nodes == [
        {"nodeID": 80978, "entryID": 101844, "rank": 1},
        {"nodeID": 80981, "entryID": 101850, "rank": 1},
    ]


def test_multi_rank_node_collapsed_to_single_entry():
    # WCL listet einen Tiered-Knoten je Rang-Stufe (gleiche nodeID) -> zu EINEM Eintrag
    # mit Gesamtrang zusammenfassen. entryID = die des hoechstrangigen Teil-Eintrags.
    event = {
        "talentTree": [
            {"nodeID": 500, "id": 900, "rank": 1},
            {"nodeID": 110404, "id": 136980, "rank": 1},
            {"nodeID": 110404, "id": 136979, "rank": 2},
            {"nodeID": 110404, "id": 136978, "rank": 1},
        ],
    }
    rec = parse_combatant_info(event, class_id=9, spec_id=266,
                               content="mythicplus", season=SEASON)
    assert rec.talent_nodes == [
        {"nodeID": 500, "entryID": 900, "rank": 1},
        {"nodeID": 110404, "entryID": 136979, "rank": 4},
    ]
    # Signatur nutzt den Gesamtrang, nicht die Teilstufen.
    assert rec.talent_sig == "110404:4|500:1"
