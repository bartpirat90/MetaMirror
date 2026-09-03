import os
from pipeline.models import ParseRecord
from pipeline.run import build_and_write


def _rec(cid, sid, content):
    return ParseRecord(
        class_id=cid, spec_id=sid, content=content,
        stats={"haste": 7000, "crit": 5600, "mastery": 3500, "vers": 3120},
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


def _rec_trinkets(t1, il1, b1, t2, il2, b2):
    r = _rec(1, 71, "raid")
    r.gear = [
        {"slot": "TRINKET1", "item_id": t1, "item_level": il1, "enchant_id": 0, "gems": [],
         "bonus_ids": b1},
        {"slot": "TRINKET2", "item_id": t2, "item_level": il2, "enchant_id": 0, "gems": [],
         "bonus_ids": b2},
    ]
    return r


def test_build_and_write_uses_constant_floor_and_filters_prev_season(tmp_path):
    # 900/901 = aktuelle Season, 700 = Vorsaison-Rest (298, Marker 13654),
    # 800 = aktuelles Item auf Hero 5/6 (318, UNTER dem Floor 320) mit Track-Bonus 12845:
    # bleibt ueber den Bonus-Positivbeweis, obwohl der Ilvl-Pfad es verwerfen wuerde.
    records = ([_rec_trinkets(900, 321, [12846], 901, 334, [12854]) for _ in range(14)]
               + [_rec_trinkets(900, 311, [12843], 800, 318, [12845]) for _ in range(2)]
               + [_rec_trinkets(900, 315, [12844], 901, 324, [12851]) for _ in range(2)]
               + [_rec_trinkets(900, 328, [12852], 901, 334, [12854]) for _ in range(1)]
               + [_rec_trinkets(900, 318, [12845], 901, 331, [12853]) for _ in range(2)]
               + [_rec_trinkets(900, 308, [], 700, 298, [13654]) for _ in range(3)])
    logs = []
    out = tmp_path / "MetaMirrorData.lua"
    errors = build_and_write(records, season=SEASON, version="v", season_name="s",
                             out_path=str(out), item_name=lambda i: f"item{i}",
                             min_sample=15, log=logs.append)
    assert errors == []
    assert any("Trinket-Floor (WCL-Pfad): 320" in m for m in logs), logs
    assert not any("WARNUNG" in m for m in logs), logs
    text = out.read_text(encoding="utf-8")
    assert "itemID = 900" in text and "itemID = 800" in text
    assert "itemID = 700" not in text


def test_build_and_write_warns_on_season_change(tmp_path):
    # Die Konstanten kennen 12846 als Track-Bonus; in den Daten haengt er nur noch am
    # isolierten Unter-Cluster -> Season-Wechsel-Warnung im Log (kein Abbruch).
    records = ([_rec_trinkets(900, 351, [14001], 901, 361, [14012]) for _ in range(18)]
               + [_rec_trinkets(900, 354, [14003], 901, 357, [14005]) for _ in range(4)]
               + [_rec_trinkets(900, 351, [14001], 700, 344, [12846]) for _ in range(5)])
    logs = []
    out = tmp_path / "MetaMirrorData.lua"
    season = dict(SEASON, TRINKET_CURRENT_TRACK_BONUS={12846}, TRINKET_PREV_SEASON_BONUS={13654})
    errors = build_and_write(records, season=season, version="v", season_name="s",
                             out_path=str(out), item_name=lambda i: f"item{i}",
                             min_sample=15, log=logs.append)
    assert errors == []
    assert any("Season-Wechsel" in m for m in logs), logs


def test_records_roundtrip_json(tmp_path):
    from pipeline.run import save_records, load_records
    recs = [_rec_trinkets(900, 321, [12846], 700, 298, [13654]), _rec(1, 71, "mythicplus")]
    path = tmp_path / "cache" / "records.json"
    save_records(recs, str(path))
    back = load_records(str(path))
    assert back == recs


def test_build_and_write_returns_errors_and_skips_on_bad_data(tmp_path):
    records = [_rec(1, 71, "raid") for _ in range(3)]   # unter min_sample
    out = tmp_path / "MetaMirrorData.lua"
    errors = build_and_write(records, season=SEASON, version="v", season_name="s",
                             out_path=str(out), item_name=lambda i: f"item{i}", min_sample=15)
    assert errors
    assert not out.exists()      # bei rot NICHT schreiben


class _Spec:
    def __init__(self, class_name, spec_name, spec_id):
        self.class_name, self.spec_name, self.spec_id = class_name, spec_name, spec_id


def _fake_collect_spec(fail_on, calls):
    def fake(client, spec, content, season, sample, log):
        key = f"{spec.class_name}/{spec.spec_name}/{content}"
        calls.append(key)
        if key in fail_on:
            raise RuntimeError("WCL down")
        return [_rec(1, spec.spec_id, content)]
    return fake


def test_collect_records_resumes_from_checkpoint(tmp_path, monkeypatch):
    import pipeline.run as run
    specs = [_Spec("Warrior", "Arms", 71), _Spec("Warrior", "Fury", 72)]
    cp = str(tmp_path / "cache" / "checkpoint.json")

    # Lauf 1: zweite Kombination scheitert -> zaehlt NICHT als fertig.
    calls1 = []
    monkeypatch.setattr(run, "_collect_spec", _fake_collect_spec({"Warrior/Fury/raid"}, calls1))
    recs1 = run.collect_records(None, specs, ["raid"], {}, checkpoint=cp, log=lambda *_: None)
    assert [r.spec_id for r in recs1] == [71]
    done, saved = run.load_checkpoint(cp)
    assert done == {"Warrior/Arms/raid"} and len(saved) == 1

    # Lauf 2 mit resume: nur die offene Kombination wird abgerufen, Ergebnis vollstaendig.
    calls2, logs = [], []
    monkeypatch.setattr(run, "_collect_spec", _fake_collect_spec(set(), calls2))
    recs2 = run.collect_records(None, specs, ["raid"], {}, checkpoint=cp, resume=True,
                                log=logs.append)
    assert calls2 == ["Warrior/Fury/raid"]
    assert sorted(r.spec_id for r in recs2) == [71, 72]
    assert any("Fortsetzung: 1 Kombinationen" in m for m in logs)

    # Ohne resume wird der Zwischenstand ignoriert (frischer Lauf, alles neu).
    calls3 = []
    monkeypatch.setattr(run, "_collect_spec", _fake_collect_spec(set(), calls3))
    run.collect_records(None, specs, ["raid"], {}, checkpoint=cp, log=lambda *_: None)
    assert len(calls3) == 2
    assert not os.path.exists(cp + ".tmp")
