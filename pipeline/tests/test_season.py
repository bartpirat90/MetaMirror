from pipeline import season


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
