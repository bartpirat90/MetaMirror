"""Tests fuer bloodmallet_sd.py (secondary_distributions -> Stats + Gear-Profil).

Kein Netzaufruf: JSON-Fixtures unter pipeline/tests/fixtures/sd_*.json (aus der Recherche
docs/research/2026-09-04-data-formats.md, live-verifizierte Feldnamen/Werte); fetch() wird
ueber httpx.MockTransport getestet."""
import json
import os

import httpx
import pytest

from pipeline.bloodmallet_sd import (
    BLEND_TOLERANCE, FIGHT_STYLE_BY_CONTENT, endpoint, is_error, parse_distribution,
    stats_from_distribution, gear_from_profile, fetch,
)

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")


def _load(name):
    with open(os.path.join(FIXTURES, name), encoding="utf-8") as f:
        return json.load(f)


def test_fight_style_by_content():
    # mythicplus = Fuenf-Ziel (castingpatchwerk5): naeher an einem M+-Pull als drei Ziele.
    assert FIGHT_STYLE_BY_CONTENT == {"raid": "castingpatchwerk", "mythicplus": "castingpatchwerk5"}


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
    # pct ist der DPS-gewichtete Mittelwert der Spitzengruppe (hier 3 Verteilungen
    # innerhalb 0,5 % der Top-DPS), nicht mehr die Top-Verteilung allein.
    assert parsed["blended"] == 3
    assert parsed["pct"] == pytest.approx(
        {"crit": 43.331165, "haste": 13.326123, "mastery": 33.342713, "vers": 10.0}, abs=1e-4
    )
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
    # 3040 x 43.33 % = 1317 Crit. Die gemittelte Spitzengruppe loest das grobe
    # 10-%-Raster der einzelnen Verteilung auf (vorher glatt 1216/1216/304/304).
    parsed = parse_distribution(_load("sd_mage_frost.json"))
    stats = stats_from_distribution(parsed)
    assert stats == [
        {"key": "crit", "rating": 1317},
        {"key": "mastery", "rating": 1014},
        {"key": "haste", "rating": 405},
        {"key": "vers", "rating": 304},
    ]


def test_stats_from_distribution_sum_matches_secondary_budget():
    # Die vier Ratings duerfen das simulierte Sekundaerwert-Budget nicht sprengen
    # (Rundung je Stat -> hoechstens 2 Punkte Abweichung nach oben).
    parsed = parse_distribution(_load("sd_hunter_bm.json"))
    total = sum(s["rating"] for s in stats_from_distribution(parsed))
    assert abs(total - parsed["secondary_sum"]) <= 2


def test_parse_distribution_blend_pct_sums_to_100():
    for name in ("sd_mage_frost.json", "sd_hunter_bm.json", "sd_warrior_arms.json"):
        parsed = parse_distribution(_load(name))
        assert sum(parsed["pct"].values()) == pytest.approx(100.0, abs=1e-6)


def test_parse_distribution_tolerance_zero_keeps_top_only():
    # tolerance=0 -> nur die Top-Verteilung; pct dann wieder das glatte Raster.
    parsed = parse_distribution(_load("sd_mage_frost.json"), tolerance=0.0)
    assert parsed["blended"] == 1
    assert parsed["pct"] == pytest.approx({"crit": 40.0, "haste": 10.0, "mastery": 40.0, "vers": 10.0})


def test_parse_distribution_blend_ignores_other_tiers():
    # Nur Verteilungen des gewaehlten Tiers duerfen einfliessen: ein zweiter Tier mit
    # hohen DPS-Werten, aber niedrigerer Spitze, darf das Ergebnis nicht veraendern.
    payload = _load("sd_mage_frost.json")
    top_tier_data = payload["data"]["MID2"]
    payload["data"]["MID1"] = {k: v - 1 for k, v in top_tier_data.items()}
    payload["sorted_data_keys"]["MID1"] = list(payload["sorted_data_keys"]["MID2"])
    parsed = parse_distribution(payload)
    assert parsed["tier"] == "MID2"
    assert parsed["blended"] == 3


def test_blend_tolerance_default():
    assert BLEND_TOLERANCE == 0.005


def test_stats_from_distribution_all_four_keys_present():
    parsed = parse_distribution(_load("sd_hunter_bm.json"))
    stats = stats_from_distribution(parsed)
    assert {s["key"] for s in stats} == {"haste", "crit", "mastery", "vers"}
    ratings = [s["rating"] for s in stats]
    assert ratings == sorted(ratings, reverse=True)


def test_gear_from_profile_takes_explicit_ilevel():
    # bloodmallet setzt bei einem Teil der Slots ein explizites 'ilevel' statt einer
    # Upgrade-Bonus-ID. Wird es verworfen, fehlt die Referenzstufe komplett und das
    # Addon zeigt die Basisstufe des Items -- teils drastisch daneben.
    payload = {"profile": {"items": {
        "back":    {"id": "268253", "ilevel": "344"},
        "wrists":  {"id": "239648", "ilevel": "331", "bonus_id": "8790/8960"},
        "chest":   {"id": "271549", "bonus_id": "12854/13690"},
    }}}
    gear, _, _ = gear_from_profile(payload)
    by_slot = {g["slot"]: g for g in gear}
    assert by_slot["BACK"]["itemLevel"] == 344
    assert by_slot["WRIST"]["itemLevel"] == 331
    # Ohne 'ilevel' bleibt 0: die Stufe steckt dann in den Bonus-IDs, der Client
    # rechnet sie selbst aus.
    assert by_slot["CHEST"]["itemLevel"] == 0


def test_gear_from_profile_ignores_unusable_ilevel():
    payload = {"profile": {"items": {
        "back": {"id": "268253", "ilevel": "keine-zahl"},
        "neck": {"id": "268265", "ilevel": "0"},
    }}}
    gear, _, _ = gear_from_profile(payload)
    assert all(g["itemLevel"] == 0 for g in gear)


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
