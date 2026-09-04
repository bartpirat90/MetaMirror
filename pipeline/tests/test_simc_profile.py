"""Tests fuer simc_profile.py (SimulationCraft-Profile -> Verbrauchsgueter/Metadaten).

Kein Netzaufruf: .simc-Fixtures unter pipeline/tests/fixtures/MID2_*.simc (Grammatik aus
docs/research/2026-09-04-data-formats.md Abschnitt B, live-verifiziert); fetch() wird ueber
httpx.MockTransport getestet."""
import os

import httpx
import pytest

from pipeline.simc_profile import (
    SIMC_CLASS_DIR, profile_url, parse_profile, consumable_item_ids, fetch, _words,
)

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


def _read(name):
    with open(os.path.join(FIXTURES, name), encoding="utf-8") as f:
        return f.read()


# ---- Dateinamens-Regel -------------------------------------------------------------

def test_words_camel_to_underscore_keeps_case():
    assert _words("DeathKnight") == "Death_Knight"
    assert _words("DemonHunter") == "Demon_Hunter"
    assert _words("BeastMastery") == "Beast_Mastery"
    assert _words("Mage") == "Mage"


def test_simc_class_dir_matches_real_github_filenames():
    # Live gegen api.github.com/repos/simulationcraft/simc/contents/profiles/MID2?ref=midnight
    # geprueft (2026-09-04): genau diese drei Schreibweisen kommen in echten Dateinamen vor.
    assert SIMC_CLASS_DIR["DeathKnight"] == "Death_Knight"
    assert SIMC_CLASS_DIR["DemonHunter"] == "Demon_Hunter"


def test_profile_url_shape():
    assert profile_url("DeathKnight", "Unholy") == (
        "https://raw.githubusercontent.com/simulationcraft/simc/midnight/profiles/MID2/MID2_Death_Knight_Unholy.simc"
    )
    assert profile_url("Hunter", "BeastMastery") == (
        "https://raw.githubusercontent.com/simulationcraft/simc/midnight/profiles/MID2/MID2_Hunter_Beast_Mastery.simc"
    )
    assert profile_url("Mage", "Frost", tier="MID1") == (
        "https://raw.githubusercontent.com/simulationcraft/simc/midnight/profiles/MID1/MID1_Mage_Frost.simc"
    )


# ---- parse_profile: Consumables / gear_ilvl / set_bonus ----------------------------

def test_parse_profile_mage_frost_consumables_and_metadata():
    parsed = parse_profile(_read("MID2_Mage_Frost.simc"))
    assert parsed["actor"] == "MID2_Mage_Frost_Spellslinger"
    assert parsed["spec"] == "frost"
    assert parsed["consumables"]["flask"] == "flask_of_the_shattered_sun_2"
    assert parsed["consumables"]["potion"] == "potion_of_recklessness_2"
    assert parsed["consumables"]["food"] == "harandar_celebration"
    assert parsed["consumables"]["augmentation"] == "void_touched_augment_rune"
    assert parsed["consumables"]["temporary_enchant"] == {"main_hand": "thalassian_phoenix_oil_2"}
    assert parsed["gear_ilvl"] == 338.00
    assert parsed["set_bonus"] == ["midnight_season_2_2pc=1", "midnight_season_2_4pc=1"]


def test_parse_profile_warrior_arms_gear_ilvl_and_set_bonus():
    parsed = parse_profile(_read("MID2_Warrior_Arms.simc"))
    assert parsed["gear_ilvl"] == 338.93
    assert parsed["set_bonus"] == [
        "midnight_season_2_2pc=1", "midnight_season_2_4pc=1", "bite_of_zuljan_2pc=1",
    ]


def test_parse_profile_dk_unholy_three_set_bonuses():
    parsed = parse_profile(_read("MID2_Death_Knight_Unholy.simc"))
    assert parsed["gear_ilvl"] == 338.93
    assert parsed["set_bonus"] == [
        "midnight_season_2_2pc=1", "midnight_season_2_4pc=1", "bite_of_zuljan_2pc=1",
    ]
    # temporary_enchant=main_hand:thalassian_phoenix_oil_2 ist in dieser Fixture vorhanden
    assert parsed["consumables"]["temporary_enchant"] == {"main_hand": "thalassian_phoenix_oil_2"}


def test_parse_profile_hunter_bm_gear_ilvl():
    parsed = parse_profile(_read("MID2_Hunter_Beast_Mastery.simc"))
    assert parsed["gear_ilvl"] == 338.27
    assert parsed["set_bonus"] == ["midnight_season_2_2pc=1", "midnight_season_2_4pc=1"]


# ---- omnium_talents: numerisch (Mage/Hunter) UND textuell (Warrior/DK) -------------

def test_omnium_talents_numeric_form():
    parsed = parse_profile(_read("MID2_Mage_Frost.simc"))
    assert parsed["omnium_talents"] == "136822:1/136816:1/136817:1/136815:1/136814:1"
    parsed_hunter = parse_profile(_read("MID2_Hunter_Beast_Mastery.simc"))
    assert parsed_hunter["omnium_talents"] == "136822:1/136819:1/136817:1/136818:1/136814:1"


def test_omnium_talents_textual_form():
    parsed = parse_profile(_read("MID2_Death_Knight_Unholy.simc"))
    assert parsed["omnium_talents"] == (
        "rune_of_unleashed_fire/rune_of_lynxlike_reflexes/rune_of_lingering/"
        "rune_of_masterful_cunning/rune_of_overload"
    )
    # Warrior nutzt (anders als DK) ebenfalls die numerische Form -- roh durchgereicht,
    # unabhaengig vom Format der jeweiligen Klasse.
    parsed_warrior = parse_profile(_read("MID2_Warrior_Arms.simc"))
    assert parsed_warrior["omnium_talents"] == "136822:1/136823:1/136817:1/136821:1/136814:1"


# ---- Gear-Zeilen: Slots, fehlender off_hand, ilevel-Override, Doppel-Gem -----------

def test_parse_profile_gear_missing_off_hand_for_two_hander():
    parsed = parse_profile(_read("MID2_Warrior_Arms.simc"))
    assert "off_hand" not in parsed["gear"]
    assert "main_hand" in parsed["gear"]


def test_parse_profile_gear_ilevel_override():
    parsed = parse_profile(_read("MID2_Hunter_Beast_Mastery.simc"))
    assert parsed["gear"]["trinket1"]["ilevel"] == 334
    assert parsed["gear"]["trinket2"]["ilevel"] == 344
    # Mage-Frost-Fixture traegt in KEINER Gear-Zeile ein ilevel-Feld -> Default 0.
    parsed_mage = parse_profile(_read("MID2_Mage_Frost.simc"))
    assert parsed_mage["gear"]["head"]["ilevel"] == 0


def test_parse_profile_gear_double_gem_at_neck():
    parsed = parse_profile(_read("MID2_Death_Knight_Unholy.simc"))
    assert parsed["gear"]["neck"]["gem_id"] == [240898, 240898]


def test_parse_profile_gear_fields_and_ignored_extra_keys():
    parsed = parse_profile(_read("MID2_Death_Knight_Unholy.simc"))
    mh = parsed["gear"]["main_hand"]
    assert mh["id"] == 268213
    assert mh["bonus_id"] == [40, 13335, 13848]
    assert mh["enchant_id"] == 6245
    # neck-Zeile traegt zusaetzlich content_tuning=883 -- wird geparst, aber ignoriert
    # (kein eigenes Feld im Rueckgabewert); id bleibt trotzdem korrekt.
    neck = parsed["gear"]["neck"]
    assert "content_tuning" not in neck
    assert neck["id"] == 268265


# ---- consumable_item_ids: bekannt/unbekannt, Rang-Suffix-Strip ---------------------

def test_consumable_item_ids_known_and_unknown_mage_frost():
    parsed = parse_profile(_read("MID2_Mage_Frost.simc"))
    ids, unknown = consumable_item_ids(parsed["consumables"])
    assert ids == {"flask": 241326, "rune": 259085, "oil": 243733}
    assert set(unknown) == {"potion_of_recklessness_2", "harandar_celebration"}


def test_consumable_item_ids_strips_rank_suffix():
    # 'flask_of_the_shattered_sun_2' (Suffix) und 'void_touched_augment_rune' (kein Suffix)
    # muessen beide auf denselben Tabelleneintrag treffen.
    ids, _ = consumable_item_ids({"flask": "flask_of_the_shattered_sun_2",
                                   "augmentation": "void_touched_augment_rune"})
    assert ids == {"flask": 241326, "rune": 259085}


def test_consumable_item_ids_dk_short_augmentation_slug():
    # DK-Fixture nutzt augmentation="void_touched" (ohne "_augment_rune"-Suffix). Der
    # Kurz-Slug ist in season.SIMC_CONSUMABLE_ITEMS als Alias auf dieselbe Rune gelistet,
    # sonst haetten Todesritter keine Rune-Empfehlung.
    parsed = parse_profile(_read("MID2_Death_Knight_Unholy.simc"))
    ids, unknown = consumable_item_ids(parsed["consumables"])
    assert ids == {"flask": 241325, "oil": 243733, "rune": 259085}
    assert "void_touched" not in unknown


# ---- fetch: 404 -> None, sonst Text -------------------------------------------------

def test_fetch_returns_none_on_404():
    def handler(request):
        return httpx.Response(404)
    client = httpx.Client(transport=httpx.MockTransport(handler))
    assert fetch("Druid", "Balance", client=client) is None


def test_fetch_returns_text_and_uses_correct_url():
    seen = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen["url"] = str(request.url)
        return httpx.Response(200, text="spec=frost\n")

    client = httpx.Client(transport=httpx.MockTransport(handler))
    text = fetch("Mage", "Frost", client=client)
    assert text == "spec=frost\n"
    assert seen["url"] == profile_url("Mage", "Frost")
