"""Tests fuer den Bloodmallet-Trinket-Fetcher (pipeline/trinkets.py).

Kernanforderung des Nutzers: VOLLSTAENDIGE Liste (kein Cap), KEINE itemID-Dedup, und
Stat-Modi desselben Trinkets (gleiche itemID) bleiben getrennte, mit Modus markierte
Eintraege (Rubinwelpenschale 4x)."""
from pipeline.trinkets import (
    slug, endpoint, parse_ranking, with_tiers, blend_overall,
    build_spec_views, emit_lua, _mode_of,
)


def test_slug_camel_to_snake():
    assert slug("Warlock") == "warlock"
    assert slug("DeathKnight") == "death_knight"
    assert slug("BeastMastery") == "beast_mastery"
    assert slug("DemonHunter") == "demon_hunter"


def test_endpoint_shape():
    assert endpoint("Warlock", "Demonology", "castingpatchwerk") == (
        "https://bloodmallet.com/chart/get/trinkets/castingpatchwerk/warlock/demonology"
    )


def test_mode_of_extracts_bracket_suffix():
    assert _mode_of("Ruby Whelp Shell [Haste]") == "Haste"
    assert _mode_of("Ruby Whelp Shell [St]") == "St"
    assert _mode_of("Freightrunner's Flask") is None


def _payload():
    # Rubinwelpenschale (gleiche itemID 193757) in vier Stat-Modi + zwei normale Trinkets;
    # 'baseline' und ein Gladiator-Item muessen rausfallen.
    return {
        "data": {
            "Freightrunner's Flask": {"330": 100, "340": 110},
            "Ruby Whelp Shell [Crit]": {"330": 95, "340": 105},
            "Ruby Whelp Shell [Haste]": {"330": 94, "340": 104},
            "Ruby Whelp Shell [St]": {"330": 90, "340": 100},
            "Ruby Whelp Shell [Aoe]": {"330": 88, "340": 98},
            "baseline": {"330": 10},
            "Gladiator's Badge": {"330": 200},
        },
        "item_ids": {
            "Freightrunner's Flask": 250215,
            "Ruby Whelp Shell [Crit]": 193757,
            "Ruby Whelp Shell [Haste]": 193757,
            "Ruby Whelp Shell [St]": 193757,
            "Ruby Whelp Shell [Aoe]": 193757,
            "Gladiator's Badge": 999,
        },
    }


def test_parse_ranking_keeps_all_variants_no_dedup():
    raw = parse_ranking(_payload())
    # 1 normal + 4 Ruby-Whelp-Varianten = 5; baseline + gladiator raus
    assert len(raw) == 5
    ids = [t["itemID"] for t in raw]
    assert ids.count(193757) == 4          # KEINE Dedup: alle vier bleiben
    assert 999 not in ids                  # PvP raus
    # hoechster ilvl-Step gewertet, absteigend sortiert
    assert raw[0]["itemID"] == 250215 and raw[0]["dps"] == 110.0


def test_parse_ranking_carries_mode():
    raw = parse_ranking(_payload())
    modes = {t["mode"] for t in raw if t["itemID"] == 193757}
    assert modes == {"Crit", "Haste", "St", "Aoe"}


def test_with_tiers_full_list_no_cap():
    raw = parse_ranking(_payload())
    tiered = with_tiers(raw)
    assert len(tiered) == len(raw)          # kein Cap: alle Eintraege bleiben
    assert tiered[0]["tier"] == "S" and tiered[0]["pct"] == 100.0
    # Modus wird durchgereicht
    assert any(e.get("mode") == "Haste" for e in tiered)


def test_with_tiers_s_is_rank_capped():
    # Fünf klar gestaffelte Trinkets: nur die Top 2 duerfen S sein (kein %-Schwellen-Wildwuchs).
    ranking = [
        {"itemID": 1, "name": "a", "mode": None, "dps": 100.0},
        {"itemID": 2, "name": "b", "mode": None, "dps": 99.0},
        {"itemID": 3, "name": "c", "mode": None, "dps": 98.0},
        {"itemID": 4, "name": "d", "mode": None, "dps": 97.0},
        {"itemID": 5, "name": "e", "mode": None, "dps": 96.0},
    ]
    tiers = [e["tier"] for e in with_tiers(ranking)]
    assert tiers.count("S") == 2            # nur die beiden besten
    assert tiers[:2] == ["S", "S"] and tiers[2] == "A"


def test_with_tiers_third_s_on_near_tie():
    # #3 praktisch gleichauf mit #1 (<=0.15% Rueckstand) -> dritter S-Platz erlaubt (max 3).
    ranking = [
        {"itemID": 1, "name": "a", "mode": None, "dps": 100.0},
        {"itemID": 2, "name": "b", "mode": None, "dps": 99.95},
        {"itemID": 3, "name": "c", "mode": None, "dps": 99.9},
        {"itemID": 4, "name": "d", "mode": None, "dps": 90.0},
    ]
    tiers = [e["tier"] for e in with_tiers(ranking)]
    assert tiers.count("S") == 3


def test_blend_overall_keeps_modes_separate():
    raid = parse_ranking(_payload())
    # Ohne Dungeon-Liste: alle Namen eindeutig -> 5 Eintraege, Ruby Whelp 4x erhalten
    blended = blend_overall(raid, [])
    assert len(blended) == 5
    assert [t["itemID"] for t in blended].count(193757) == 4


def test_build_spec_views_single_source_flag():
    raw = parse_ranking(_payload())
    views = build_spec_views(raw, [])       # keine Dungeon-Rohliste
    assert views["singleSource"] is True
    assert views["raid"] == views["dungeon"] == views["overall"]


def test_emit_lua_writes_mode_field():
    raw = parse_ranking(_payload())
    lua = emit_lua({266: build_spec_views(raw, [])}, version="bm-test")
    assert "[266] =" in lua
    assert 'mode = "Crit"' in lua
    assert "singleSource = true" in lua
    assert 'source = "Data from bloodmallet.com"' in lua
