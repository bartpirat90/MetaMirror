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


def test_curated_consumables_overlay_food_potion_and_oil_by_stat():
    # Food + Trank sind universell (Primaerwert); flask/rune bleiben erhalten.
    base = {"flask": 241325, "food": 222781, "rune": 259085}
    # Int-Caster (Warlock Demo) -> bekommt zusaetzlich das Caster-Oel.
    demo = season.apply_curated_consumables(266, base)
    assert demo["food"] == season.CURATED_FOOD == 242275
    assert demo["potion"] == season.CURATED_POTION == 241308
    assert demo["oil"] == season.CURATED_OIL_BY_STAT["int"] == 243733
    assert demo["flask"] == 241325 and demo["rune"] == 259085   # log-abgeleitet unangetastet
    # Melee (Warrior Arms, STR) -> kein Oel.
    arms = season.apply_curated_consumables(71, base)
    assert arms["food"] == 242275 and arms["potion"] == 241308
    assert "oil" not in arms
    # Idempotent: erneutes Anwenden aendert nichts.
    assert season.apply_curated_consumables(266, demo) == demo


def test_patch_consumables_is_idempotent_and_stat_aware():
    from pipeline.patch_consumables import patch_text
    src = (
        "        [9] = {\n"
        "            [266] = {\n"
        "                mythicplus = {\n"
        "                    consumables = { flask = 241326, food = 222781, rune = 259085 },\n"
        "                },\n"
        "            },\n"
        "        },\n"
        "        [1] = {\n"
        "            [71] = {\n"
        "                raid = {\n"
        "                    consumables = { flask = 241326, food = 222781, rune = 259085 },\n"
        "                },\n"
        "            },\n"
        "        },\n"
    )
    once = patch_text(src)
    assert "food = 242275" in once and "potion = 241308" in once
    assert "food = 222781" not in once
    assert "oil = 243733" in once            # Int-Spec 266 bekommt Oel
    assert once.count("oil = 243733") == 1   # STR-Spec 71 nicht
    assert patch_text(once) == once          # idempotent
