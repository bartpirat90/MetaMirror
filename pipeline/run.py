import argparse
import os
import sys
from collections import defaultdict

from pipeline import season as season_mod
from pipeline.specs import SPECS, CONTENTS
from pipeline.aggregate import aggregate
from pipeline.emit_lua import emit_lua
from pipeline.validate import validate


def build_and_write(records, season, version, season_name, out_path, item_name, min_sample=15):
    """records -> aggregieren -> validieren -> nur bei gruen schreiben. Gibt Fehlerliste zurueck."""
    grouped = defaultdict(list)
    for r in records:
        grouped[(r.class_id, r.spec_id, r.content)].append(r)

    data = defaultdict(lambda: defaultdict(dict))
    for (cid, sid, content), recs in grouped.items():
        data[cid][sid][content] = aggregate(recs, spec_id=sid, season=season, item_name=item_name)

    plain = {cid: {sid: dict(c) for sid, c in specs.items()} for cid, specs in data.items()}
    errors = validate(plain, min_sample=min_sample)
    if errors:
        return errors

    lua = emit_lua(plain, version=version, season=season_name)
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(lua)
    return []


_CI_QUERY = ('query($code:String!,$fight:Int!){reportData{report(code:$code){'
             'masterData{actors(type:"Player"){id name}}'
             'events(dataType:CombatantInfo,fightIDs:[$fight],limit:50){data}}}}')


def _fetch_rankings(client, enc, difficulty, spec, metric, page=1):
    q = ("query($enc:Int!,$cls:String!,$spec:String!){"
         "worldData{encounter(id:$enc){"
         f"characterRankings(className:$cls,specName:$spec,difficulty:{int(difficulty)},"
         f"metric:{metric},page:{int(page)})"
         "}}}")
    d = client.query(q, {"enc": enc, "cls": spec.class_name, "spec": spec.spec_name})
    cr = d["worldData"]["encounter"]["characterRankings"]
    return cr.get("rankings", []) if isinstance(cr, dict) else []


def _fetch_combatant(client, code, fight):
    d = client.query(_CI_QUERY, {"code": code, "fight": fight})
    rep = d["reportData"]["report"]
    return rep["masterData"]["actors"], rep["events"]["data"]


def _collect_spec(client, spec, content, season, sample, log):
    from pipeline.specs import ranking_metric
    from pipeline.fetch import parse_combatant_info
    if content == "raid":
        enc, diff = season["RAID_ENCOUNTER_IDS"][0], season["RAID_DIFFICULTY"]
    else:
        enc, diff = season["MPLUS_ENCOUNTER_IDS"][0], season["MPLUS_DIFFICULTY"]
    rankings = _fetch_rankings(client, enc, diff, spec, ranking_metric(spec.spec_id))

    out, seen = [], set()
    for r in rankings:
        if len(out) >= sample:
            break
        rep = r.get("report") or {}
        code, fight, name = rep.get("code"), rep.get("fightID"), r.get("name")
        if not code or fight is None:
            continue
        server = r.get("server")
        server_key = server.get("name") if isinstance(server, dict) else server
        key = (name, server_key)
        if key in seen:
            continue
        seen.add(key)
        try:
            actors, events = _fetch_combatant(client, code, fight)
        except Exception as e:
            log(f"  CombatantInfo {code}#{fight}: {e}")
            continue
        sid = {a["name"]: a["id"] for a in actors}.get(name)
        ev = next((e for e in events if sid is not None and e.get("sourceID") == sid), None)
        if ev is None:
            ev = next((e for e in events if e.get("specID") == spec.spec_id), None)
        if ev is not None:
            out.append(parse_combatant_info(ev, spec.class_id, spec.spec_id, content, season))
    return out


def collect_records(client, specs, contents, season, sample=50, log=print):
    """Live-Abruf ueber die WCL-API: Rankings -> CombatantInfo -> ParseRecords."""
    records = []
    for spec in specs:
        for content in contents:
            try:
                recs = _collect_spec(client, spec, content, season, sample, log)
                records.extend(recs)
                log(f"{spec.class_name}/{spec.spec_name}/{content}: {len(recs)} Parses")
            except Exception as e:
                log(f"FEHLER {spec.class_name}/{spec.spec_name}/{content}: {e}")
    return records


def item_name_stub(item_id):
    # Item-Namen werden zur Laufzeit im Addon aufgeloest; hier nur Fallback-Text.
    return f"item:{item_id}"


def build_season(mod):
    """Baut das Season-Dict (fuer Abruf + Aggregation) aus dem season-Modul."""
    return {
        "RATING_PER_PCT": mod.RATING_PER_PCT,
        "MASTERY_COEFF": mod.MASTERY_COEFF,
        "CONSUMABLE_SPELL_TO_ITEM": mod.CONSUMABLE_SPELL_TO_ITEM,
        "RAID_ENCOUNTER_IDS": mod.RAID_ENCOUNTER_IDS,
        "RAID_DIFFICULTY": mod.RAID_DIFFICULTY,
        "MPLUS_ENCOUNTER_IDS": mod.MPLUS_ENCOUNTER_IDS,
        "MPLUS_DIFFICULTY": mod.MPLUS_DIFFICULTY,
        "SAMPLE_TARGET": mod.SAMPLE_TARGET,
    }


def load_credentials():
    """WCL-Zugangsdaten: zuerst Umgebungsvariablen (CI/GitHub-Secrets),
    sonst die gitignorierte lokale Datei pipeline/local_secrets.json."""
    cid = os.environ.get("WCL_CLIENT_ID")
    secret = os.environ.get("WCL_CLIENT_SECRET")
    if cid and secret:
        return cid, secret
    import json
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "local_secrets.json")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        return data.get("WCL_CLIENT_ID"), data.get("WCL_CLIENT_SECRET")
    return None, None


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="Data/MetaMirrorData.lua")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--min-sample", type=int, default=8)
    args = ap.parse_args(argv)

    client_id, client_secret = load_credentials()
    if not client_id or not client_secret:
        print("WCL-Zugangsdaten fehlen (Umgebungsvariablen oder pipeline/local_secrets.json)",
              file=sys.stderr)
        return 2

    from pipeline.wcl import WclClient
    client = WclClient(client_id, client_secret)
    season = build_season(season_mod)
    records = collect_records(client, SPECS, CONTENTS, season, sample=season_mod.SAMPLE_TARGET)

    from datetime import date
    version = f"wcl-{date.today().isoformat()}"
    out = os.devnull if args.dry_run else args.out
    errors = build_and_write(records, season=season, version=version,
                             season_name=season_mod.SEASON_NAME, out_path=out,
                             item_name=item_name_stub, min_sample=args.min_sample)
    if errors:
        print("VALIDIERUNG ROT — kein Commit:", file=sys.stderr)
        for e in errors:
            print("  " + e, file=sys.stderr)
        return 1
    print(f"OK -> {out}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
