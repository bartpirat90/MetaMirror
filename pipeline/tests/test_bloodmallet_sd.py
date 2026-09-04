"""Tests fuer bloodmallet_sd.py (secondary_distributions -> Stats + Gear-Profil).

Kein Netzaufruf: JSON-Fixtures unter pipeline/tests/fixtures/sd_*.json (aus der Recherche
docs/research/2026-09-04-data-formats.md, live-verifizierte Feldnamen/Werte); fetch() wird
ueber httpx.MockTransport getestet."""
import json
import os

import httpx
import pytest

from pipeline.bloodmallet_sd import (
    FIGHT_STYLE_BY_CONTENT, endpoint, is_error, parse_distribution,
    stats_from_distribution, gear_from_profile, fetch,
)

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


def _load(name):
    with open(os.path.join(FIXTURES, name), encoding="utf-8") as f:
        return json.load(f)


def test_fight_style_by_content():
    assert FIGHT_STYLE_BY_CONTENT == {"raid": "castingpatchwerk", "mythicplus": "castingpatchwerk3"}


def test_endpoint_shape():
    assert endpoint("Hunter", "BeastMastery", "castingpatchwerk") == (
        "https://bloodmallet.com/chart/get/secondary_distributions/castingpatchwerk/hunter/beast_mastery"
    )


def test_is_error_on_error_status():
    assert is_error({"status": "error", "message": "No standard chart with these values found."})


def test_is_error_false_on_real_payload():
    assert is_error(_load("sd_mage_frost.json")) is False


def test_is_error_on_missing_data_key():
    assert is_error({"status": "ok"})


def test_is_error_on_empty_payload():
    assert is_error({}) and is_error(None)


def test_parse_distribution_mage_frost():
    parsed = parse_distribution(_load("sd_mage_frost.json"))
    assert parsed["tier"] == "MID2"
    assert parsed["top_key"] == "40_10_40_10"
    assert parsed["pct"] == {"crit": 40, "haste": 10, "mastery": 40, "vers": 10}
    assert parsed["secondary_sum"] == 3040
    assert parsed["dps"] == 205517
    # timestamp = metadata.timestamp[:10] (echtes metadata.timestamp:
    # "2026-09-02 02:42:00.976615") -- ISO-Datum, kein 'UTC '-Praefix, keine Uhrzeit.
    assert parsed["timestamp"] == "2026-09-02"
    assert parsed["simc_hash"] == "f869791"


def test_parse_distribution_timestamp_fallback_without_metadata():
    # Kein 'metadata'-Feld -> Fallback auf Top-Level 'timestamp', 'UTC '-Praefix entfernt,
    # auf ISO-Datum gekuerzt.
    payload = {
        "data": {"MID2": {"10_10_10_70": 100}},
        "sorted_data_keys": {"MID2": ["10_10_10_70"]},
        "secondary_sum": 1000,
        "timestamp": "UTC 2026-09-02 02:42",
    }
    parsed = parse_distribution(payload)
    assert parsed["timestamp"] == "2026-09-02"


def test_parse_distribution_raises_on_error_payload():
    with pytest.raises(ValueError):
        parse_distribution({"status": "error", "message": "nope"})


def test_parse_distribution_raises_on_missing_fields():
    with pytest.raises(ValueError):
        parse_distribution({"data": {"MID2": {}}})   # sorted_data_keys/secondary_sum fehlen


def test_stats_from_distribution_mage_frost_rating():
    # Plan-Stichprobe: 3040 x 0.40 = 1216 Crit (Task 4: Crit 1216 / Mastery 1216 /
    # Haste 304 / Vers 304, in dieser Reihenfolge nach Rating absteigend sortiert).
    parsed = parse_distribution(_load("sd_mage_frost.json"))
    stats = stats_from_distribution(parsed)
    assert stats == [
        {"key": "crit", "rating": 1216},
        {"key": "mastery", "rating": 1216},
        {"key": "haste", "rating": 304},
        {"key": "vers", "rating": 304},
    ]


def test_stats_from_distribution_all_four_keys_present():
    parsed = parse_distribution(_load("sd_hunter_bm.json"))
    stats = stats_from_distribution(parsed)
    assert {s["key"] for s in stats} == {"haste", "crit", "mastery", "vers"}
    ratings = [s["rating"] for s in stats]
    assert ratings == sorted(ratings, reverse=True)


def test_gear_from_profile_slot_mapping_and_missing_offhand():
    # Warrior Arms (Zweihand): 15 Gear-Slots, kein off_hand-Eintrag im Profil.
    gear, gems, enchants = gear_from_profile(_load("sd_warrior_arms.json"))
    slots = {g["slot"] for g in gear}
    assert "OFFHAND" not in slots
    assert "MAINHAND" in slots and "HEAD" in slots and "TRINKET2" in slots
    mainhand = [g for g in gear if g["slot"] == "MAINHAND"][0]
    assert mainhand["itemID"] == 268213
    assert mainhand["bonusIDs"] == [13335, 13848]
    assert mainhand["itemLevel"] == 0
    assert mainhand["name"] == "item:268213"


def test_gear_from_profile_double_gem_at_neck():
    # Mage/Frost-Fixture: neck.gem_id = "240898/240898" -> zwei Gem-Eintraege, nicht dedupliziert.
    _, gems, _ = gear_from_profile(_load("sd_mage_frost.json"))
    neck_gems = [g for g in gems if g["slot"] == "NECK"]
    assert len(neck_gems) == 2
    assert all(g["itemID"] == 240898 for g in neck_gems)


def test_gear_from_profile_enchant_known_and_unknown():
    # chest enchant_id=7987 ist in season.ENCHANT_ITEM_BY_ID (Mark of the Worldsoul, 243977);
    # name folgt der aggregate.py-Konvention "enchant:<id>".
    _, _, enchants = gear_from_profile(_load("sd_mage_frost.json"))
    chest = [e for e in enchants if e["slot"] == "CHEST"][0]
    assert chest["id"] == 7987 and chest["itemID"] == 243977 and chest["name"] == "enchant:7987"
    # DK main_hand enchant_id=6245 ist NICHT in ENCHANT_ITEM_BY_ID -> itemID 0, Name trotzdem gesetzt.
    _, _, enchants_dk = gear_from_profile(_load("sd_dk_unholy.json"))
    mh = [e for e in enchants_dk if e["slot"] == "MAINHAND"][0]
    assert mh["id"] == 6245 and mh["itemID"] == 0 and mh["name"] == "enchant:6245"


def test_gear_from_profile_skips_empty_slot_entries():
    # Ein Slot ohne 'id' (bloodmallet liesse das Feld theoretisch weg) darf keinen
    # Gear-Eintrag erzeugen.
    payload = {"profile": {"items": {"head": {"bonus_id": "1/2"}}}}
    gear, gems, enchants = gear_from_profile(payload)
    assert gear == [] and gems == [] and enchants == []


def test_fetch_builds_request_with_ua_and_returns_json():
    seen = {}

    def handler(request: httpx.Request) -> httpx.Response:
        seen["url"] = str(request.url)
        seen["ua"] = request.headers.get("user-agent")
        return httpx.Response(200, json={"status": "ok", "data": {}})

    client = httpx.Client(transport=httpx.MockTransport(handler))
    payload = fetch("Mage", "Frost", "castingpatchwerk", client=client)
    assert payload == {"status": "ok", "data": {}}
    assert seen["url"] == endpoint("Mage", "Frost", "castingpatchwerk")
    assert seen["ua"] == "MetaMirror/0.9"
