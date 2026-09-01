from pipeline import season
from pipeline.fetch import parse_combatant_info
from pipeline.run import build_season

VALID_CATS = {"flask", "phial", "potion", "food", "oil", "rune"}


def test_consumable_whitelist_is_wellformed():
    wl = season.CONSUMABLE_SPELL_TO_ITEM
    assert wl, "Whitelist darf nicht leer sein"
    for spell_id, info in wl.items():
        assert isinstance(spell_id, int) and spell_id > 0
        assert info["cat"] in VALID_CATS
        assert isinstance(info["item"], int) and info["item"] > 0


def test_whitelist_covers_observed_flask_food_rune_buffs():
    wl = season.CONSUMABLE_SPELL_TO_ITEM
    # in echten Top-Parses beobachtete Buffs (2026-08-31)
    assert wl[1235108]["cat"] == "flask"   # Flask of the Magisters
    assert wl[1285644]["cat"] == "food"    # Hearty Well Fed
    assert wl[1264426]["cat"] == "rune"    # Void-Touched Augment Rune


def test_parse_resolves_real_whitelist():
    s = build_season(season)
    event = {
        "gear": [],
        "talentTree": [],
        "auras": [
            {"ability": 1235110, "name": "Flask of the Blood Knights"},
            {"ability": 1285644, "name": "Hearty Well Fed"},
            {"ability": 1264426, "name": "Void-Touched"},
            {"ability": 6673, "name": "Battle Shout"},   # Klassen-Buff, kein Consumable
        ],
    }
    rec = parse_combatant_info(event, class_id=6, spec_id=251, content="raid", season=s)
    assert rec.consumables["flask"] == 241325
    assert rec.consumables["food"] == 222781
    assert rec.consumables["rune"] == 259085
    assert rec.consumables["potion"] is None
    assert rec.consumables["phial"] is None
    assert rec.consumables["oil"] is None
