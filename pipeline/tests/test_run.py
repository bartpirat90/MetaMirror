import os
from pipeline.models import ParseRecord
from pipeline.run import build_and_write


def _rec(cid, sid, content):
    return ParseRecord(
        class_id=cid, spec_id=sid, content=content,
        stats={"haste": 7000, "crit": 5600, "mastery": 3500, "vers": 3120},
        talent_import="ABC=", talent_sig="A",
        gear=[{"slot": "HEAD", "item_id": 21001, "enchant_id": 0, "gems": []}],
        consumables={"flask": 212283, "food": None, "phial": None,
                     "potion": None, "oil": None, "rune": None},
    )


SEASON = {"RATING_PER_PCT": {"haste": 700.0, "crit": 700.0, "vers": 780.0, "mastery": 700.0},
          "MASTERY_COEFF": {}}


def test_build_and_write_produces_valid_file(tmp_path):
    records = [_rec(1, 71, "raid") for _ in range(20)]
    out = tmp_path / "MetaMirrorData.lua"
    errors = build_and_write(records, season=SEASON, version="v", season_name="s",
                             out_path=str(out), item_name=lambda i: f"item{i}", min_sample=15)
    assert errors == []
    text = out.read_text(encoding="utf-8")
    assert "MetaMirrorData = {" in text and "[71] = {" in text


def test_build_and_write_returns_errors_and_skips_on_bad_data(tmp_path):
    records = [_rec(1, 71, "raid") for _ in range(3)]   # unter min_sample
    out = tmp_path / "MetaMirrorData.lua"
    errors = build_and_write(records, season=SEASON, version="v", season_name="s",
                             out_path=str(out), item_name=lambda i: f"item{i}", min_sample=15)
    assert errors
    assert not out.exists()      # bei rot NICHT schreiben
