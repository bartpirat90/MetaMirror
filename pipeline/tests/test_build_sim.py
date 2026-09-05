"""Tests fuer build_sim.py (Orchestrator: bloodmallet_sd + simc_profile -> Lua-Datenvertrag).

Kein Netzaufruf: fetch_sd/fetch_simc werden mit Funktionen injiziert, die aus den echten
Fixtures (pipeline/tests/fixtures/sd_*.json, MID2_*.simc) lesen -- denselben, gegen die
bloodmallet_sd.py/simc_profile.py bereits getestet sind."""
import json
import os
import shutil
import subprocess

import pytest

from pipeline.build_sim import build, build_spec, write, DEFAULT_MIN_SPECS
from pipeline.specs import SPECS, CONTENTS
from pipeline.season import CURATED_FOOD, CURATED_POTION

FIXTURES = os.path.join(os.path.dirname(__file__), "fixtures")

MAGE_FROST = next(s for s in SPECS if s.class_name == "Mage" and s.spec_name == "Frost")
WARRIOR_ARMS = next(s for s in SPECS if s.class_name == "Warrior" and s.spec_name == "Arms")
DK_UNHOLY = next(s for s in SPECS if s.class_name == "DeathKnight" and s.spec_name == "Unholy")
HUNTER_BM = next(s for s in SPECS if s.class_name == "Hunter" and s.spec_name == "BeastMastery")

_SD_FIXTURE = {
    ("Mage", "Frost"): "sd_mage_frost.json",
    ("Warrior", "Arms"): "sd_warrior_arms.json",
    ("DeathKnight", "Unholy"): "sd_dk_unholy.json",
    ("Hunter", "BeastMastery"): "sd_hunter_bm.json",
}
_SIMC_FIXTURE = {
    ("Mage", "Frost"): "MID2_Mage_Frost.simc",
    ("Warrior", "Arms"): "MID2_Warrior_Arms.simc",
    ("DeathKnight", "Unholy"): "MID2_Death_Knight_Unholy.simc",
    ("Hunter", "BeastMastery"): "MID2_Hunter_Beast_Mastery.simc",
}


def _load_json(name):
    with open(os.path.join(FIXTURES, name), encoding="utf-8") as f:
        return json.load(f)


def _load_text(name):
    with open(os.path.join(FIXTURES, name), encoding="utf-8") as f:
        return f.read()


def _fixture_fetch_sd(known=None, error_for=()):
    """fetch_sd-Ersatz: liefert dieselbe SD-Fixture unabhaengig vom Fight-Style/Content
    (wir haben nur je eine Fixture pro Spec). error_for: Set von (class,spec,content) ->
    Fehler-Payload statt Fixture (fuer den Skip-Test)."""
    known = known or _SD_FIXTURE

    def fetch_sd(class_name, spec_name, fight_style):
        key = (class_name, spec_name)
        content = "raid" if fight_style == "castingpatchwerk" else "mythicplus"
        if (class_name, spec_name, content) in error_for:
            return {"status": "error", "message": "No standard chart with these values found."}
        if key not in known:
            return {"status": "error", "message": "kein Fixture fuer diese Spec"}
        return _load_json(known[key])
    return fetch_sd


def _fixture_fetch_simc(known=None, missing=()):
    known = known or _SIMC_FIXTURE

    def fetch_simc(class_name, spec_name):
        key = (class_name, spec_name)
        if key in missing or key not in known:
            return None
        return _load_text(known[key])
    return fetch_simc


# ---- build_spec: Vertrag pro Spec x Content -----------------------------------------

def test_build_spec_contract_mage_frost():
    payload = _load_json("sd_mage_frost.json")
    simc_text = _load_text("MID2_Mage_Frost.simc")
    agg = build_spec(MAGE_FROST, "raid", payload, simc_text)

    assert agg.sample_size == 1
    assert {s["key"] for s in agg.stats} == {"haste", "crit", "mastery", "vers"}
    ratings = [s["rating"] for s in agg.stats]
    assert ratings == sorted(ratings, reverse=True)

    slots = {g["slot"] for g in agg.gear}
    assert {"HEAD", "CHEST", "MAINHAND", "TRINKET1", "TRINKET2"} <= slots
    for g in agg.gear:
        assert g["itemID"] > 0
        assert g["name"] == f"item:{g['itemID']}"

    # chest enchant_id=7987 -> season.ENCHANT_ITEM_BY_ID (Mark of the Worldsoul, 243977)
    chest_ench = [e for e in agg.enchants if e["slot"] == "CHEST"][0]
    assert chest_ench["id"] == 7987 and chest_ench["itemID"] == 243977

    # Consumables: flask/rune aus dem SimC-Profil, food/potion kuratiert, Oel (Int-Spec).
    assert agg.consumables["flask"] == 241326        # flask_of_the_shattered_sun
    assert agg.consumables["rune"] == 259085          # void_touched_augment_rune
    assert agg.consumables["food"] == CURATED_FOOD
    assert agg.consumables["potion"] == CURATED_POTION
    assert agg.consumables["oil"] == 243733           # Mage = Int-Spec


def test_build_spec_no_oil_for_non_int_spec():
    payload = _load_json("sd_warrior_arms.json")
    simc_text = _load_text("MID2_Warrior_Arms.simc")
    agg = build_spec(WARRIOR_ARMS, "raid", payload, simc_text)
    assert "oil" not in agg.consumables
    assert agg.consumables["food"] == CURATED_FOOD
    assert agg.consumables["potion"] == CURATED_POTION


def test_build_spec_without_simc_profile_uses_only_curated_consumables():
    payload = _load_json("sd_mage_frost.json")
    agg = build_spec(MAGE_FROST, "raid", payload, None)
    assert agg.consumables.get("flask") is None
    assert agg.consumables["food"] == CURATED_FOOD
    assert agg.consumables["potion"] == CURATED_POTION
    assert agg.consumables["oil"] == 243733   # kuratiert, unabhaengig vom SimC-Profil


def test_build_spec_raises_on_error_payload():
    with pytest.raises(ValueError):
        build_spec(MAGE_FROST, "raid", {"status": "error", "message": "nope"}, None)


# ---- build(): Orchestrierung, Skip, Abbruchregel, meta -------------------------------

def test_build_full_contract_with_four_fixture_specs():
    specs = [MAGE_FROST, WARRIOR_ARMS, DK_UNHOLY, HUNTER_BM]
    logs = []
    plain, meta = build(specs, CONTENTS, _fixture_fetch_sd(), _fixture_fetch_simc(),
                        log=logs.append, min_specs=1)

    assert set(plain.keys()) == {MAGE_FROST.class_id, WARRIOR_ARMS.class_id,
                                 DK_UNHOLY.class_id, HUNTER_BM.class_id}
    mage_raid = plain[MAGE_FROST.class_id][MAGE_FROST.spec_id]["raid"]
    mage_mplus = plain[MAGE_FROST.class_id][MAGE_FROST.spec_id]["mythicplus"]
    assert mage_raid.sample_size == 1 and mage_mplus.sample_size == 1

    assert meta["fightStyles"] == {"raid": "castingpatchwerk", "mythicplus": "castingpatchwerk5"}
    assert meta["simcHash"] == "f869791"
    assert meta["bloodmalletTimestamp"] == "2026-09-02"
    assert meta["specsWithData"] == 4
    assert meta["skipped"] == []
    assert meta["generated"]   # heutiges Datum, ISO-Format
    assert not any("uebersprungen" in m for m in logs)


def test_build_skips_error_payload_and_logs():
    specs = [MAGE_FROST, WARRIOR_ARMS]
    error_for = {("Mage", "Frost", "mythicplus")}
    logs = []
    plain, meta = build(specs, CONTENTS, _fixture_fetch_sd(error_for=error_for),
                        _fixture_fetch_simc(), log=logs.append, min_specs=1)

    assert "mythicplus" not in plain[MAGE_FROST.class_id][MAGE_FROST.spec_id]
    assert "raid" in plain[MAGE_FROST.class_id][MAGE_FROST.spec_id]
    assert "Mage/Frost/mythicplus" in meta["skipped"]
    assert any("uebersprungen" in m and "Mage/Frost/mythicplus" in m for m in logs)


def test_build_missing_simc_profile_falls_back_to_curated_only():
    specs = [MAGE_FROST]
    logs = []
    plain, meta = build(specs, CONTENTS, _fixture_fetch_sd(),
                        _fixture_fetch_simc(missing={("Mage", "Frost")}),
                        log=logs.append, min_specs=1)
    agg = plain[MAGE_FROST.class_id][MAGE_FROST.spec_id]["raid"]
    assert agg.consumables["food"] == CURATED_FOOD
    assert "flask" not in agg.consumables or agg.consumables.get("flask") is None
    assert any("kein SimC-Profil" in m for m in logs)


def test_build_abort_below_min_specs():
    # Nur die vier Fixture-Specs liefern Daten; die restlichen ~30 SPECS scheitern
    # (kein Fixture) -> unter dem Default-min_specs=20 -> RuntimeError, nichts geschrieben.
    with pytest.raises(RuntimeError, match=r"< \d+"):
        build(SPECS, CONTENTS, _fixture_fetch_sd(), _fixture_fetch_simc(), log=lambda *_: None)


def test_build_abort_message_lists_skipped_and_respects_custom_min_specs():
    specs = [MAGE_FROST, WARRIOR_ARMS]
    with pytest.raises(RuntimeError):
        build(specs, CONTENTS, _fixture_fetch_sd(), _fixture_fetch_simc(),
             log=lambda *_: None, min_specs=DEFAULT_MIN_SPECS)
    # mit passendem min_specs geht derselbe Aufruf durch
    plain, meta = build(specs, CONTENTS, _fixture_fetch_sd(), _fixture_fetch_simc(),
                        log=lambda *_: None, min_specs=2)
    assert meta["specsWithData"] == 2


# ---- write(): Lua-Ausgabe, Attribution, fightStyles/generated, Syntaxcheck -----------

def test_write_produces_lua_with_attribution_fightstyles_generated(tmp_path):
    specs = [MAGE_FROST, WARRIOR_ARMS, DK_UNHOLY, HUNTER_BM]
    plain, meta = build(specs, CONTENTS, _fixture_fetch_sd(), _fixture_fetch_simc(),
                        log=lambda *_: None, min_specs=1)
    out = tmp_path / "MetaMirrorData.lua"
    write(plain, meta, str(out))

    text = out.read_text(encoding="utf-8")
    assert 'attribution = "Data from bloodmallet.com (SimulationCraft)"' in text
    assert "Warcraft Logs" not in text
    assert 'fightStyles = { mythicplus = "castingpatchwerk5", raid = "castingpatchwerk" }' in text
    assert f'generated = "{meta["generated"]}"' in text
    assert 'simcHash = "f869791"' in text
    assert "\r\n" not in text   # newline="\n"

    luac = shutil.which("luac")
    if luac:
        result = subprocess.run([luac, "-p", str(out)], capture_output=True, text=True)
        assert result.returncode == 0, result.stderr
    else:
        pytest.skip("luac nicht gefunden -- Syntaxcheck uebersprungen")


def test_write_raises_on_validation_error(tmp_path):
    from pipeline.models import AggregatedSpec
    # gear leer -> validate() meldet Fehler
    bad = AggregatedSpec(sample_size=1, stats=[{"key": k, "rating": 1} for k in
                                                ("haste", "crit", "mastery", "vers")],
                         gear=[], gems=[], enchants=[], consumables={})
    plain = {1: {71: {"raid": bad}}}
    meta = {"fightStyles": {}, "generated": "2026-09-04", "simcHash": None,
           "bloodmalletTimestamp": None, "specsWithData": 1, "skipped": []}
    out = tmp_path / "MetaMirrorData.lua"
    with pytest.raises(RuntimeError):
        write(plain, meta, str(out))
    assert not out.exists()
