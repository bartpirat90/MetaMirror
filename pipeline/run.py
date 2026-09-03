import argparse
import json
import os
import sys
from collections import defaultdict

from pipeline import season as season_mod
from pipeline.specs import SPECS, CONTENTS
from pipeline.aggregate import aggregate, build_trinket_table
from pipeline.emit_lua import emit_lua
from pipeline.validate import validate


def build_and_write(records, season, version, season_name, out_path, item_name,
                    min_sample=15, log=print):
    """records -> aggregieren -> duenne Specs droppen -> validieren -> nur bei gruen schreiben.
    Gibt Fehlerliste zurueck (leer = geschrieben)."""
    grouped = defaultdict(list)
    for r in records:
        grouped[(r.class_id, r.spec_id, r.content)].append(r)

    data = defaultdict(lambda: defaultdict(dict))
    for (cid, sid, content), recs in grouped.items():
        agg = aggregate(recs, spec_id=sid, season=season, item_name=item_name)
        if agg.sample_size < min_sample:
            log(f"  uebersprungen (zu wenig Daten): {cid}/{sid}/{content} n={agg.sample_size}")
            continue
        data[cid][sid][content] = agg

    plain = {cid: {sid: dict(c) for sid, c in specs.items() if c} for cid, specs in data.items()}
    plain = {cid: specs for cid, specs in plain.items() if specs}
    if not plain:
        return ["keine Spec hat genug Daten (min_sample zu hoch oder API leer)"]

    errors = validate(plain, min_sample=min_sample)
    if errors:
        return errors

    # Trinket-Floor fuer den WCL-Pfad = handgepflegte Konstante (ein aus dem Ilvl-Cluster
    # abgeleiteter Floor scheiterte bei breiter Stichprobe, siehe season_markers.py).
    # Die Bonus-ID-Konstanten werden gegen die Daten geprueft (Season-Wechsel-Waechter);
    # bei Widerspruch nur WARNUNG im Log, kein Abbruch.
    from pipeline.season_markers import entries_from_records, check_markers
    entries = entries_from_records(records)
    floor = season.get("TRINKET_MIN_ILVL", season_mod.TRINKET_MIN_ILVL)
    log(f"Trinket-Floor (WCL-Pfad): {floor}  [{len(entries)} Gear-Eintraege]")
    check_markers(entries,
                  season.get("TRINKET_CURRENT_TRACK_BONUS", season_mod.TRINKET_CURRENT_TRACK_BONUS),
                  season.get("TRINKET_PREV_SEASON_BONUS", season_mod.TRINKET_PREV_SEASON_BONUS),
                  floor=floor, log=log)

    # Trinket-Tierlisten nur fuer Specs, die es in den Datensatz geschafft haben.
    kept = {sid for cid in plain for sid in plain[cid]}
    trinkets = build_trinket_table(records, item_name, only_specs=kept, floor=floor)

    lua = emit_lua(plain, version=version, season=season_name, trinkets=trinkets)
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


def _combo_key(spec, content):
    return f"{spec.class_name}/{spec.spec_name}/{content}"


def load_checkpoint(path):
    """Zwischenstand eines abgebrochenen Laufs: (fertige Kombinationen, bisherige Records)."""
    if not path or not os.path.exists(path):
        return set(), []
    from pipeline.models import ParseRecord
    with open(path, encoding="utf-8") as f:
        d = json.load(f)
    return set(d.get("done", [])), [ParseRecord(**r) for r in d.get("records", [])]


def save_checkpoint(path, done, records):
    """Atomar schreiben (tmp + replace), damit ein Abbruch waehrend des Schreibens den
    Zwischenstand nicht zerstoert."""
    from dataclasses import asdict
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    tmp = path + ".tmp"
    with open(tmp, "w", encoding="utf-8") as f:
        json.dump({"done": sorted(done), "records": [asdict(r) for r in records]}, f)
    os.replace(tmp, path)


def collect_records(client, specs, contents, season, sample=50, log=print,
                    checkpoint=None, resume=False):
    """Live-Abruf ueber die WCL-API: Rankings -> CombatantInfo -> ParseRecords.

    checkpoint: Pfad, an dem nach JEDER fertigen Kombination der Zwischenstand gesichert
    wird (ein Lauf kostet ~2-3 h und ~10.000 WCL-Punkte; ohne Zwischenstand kostet ein
    Abbruch alles). resume=True laedt den Zwischenstand und ueberspringt fertige
    Kombinationen; fehlgeschlagene Kombinationen zaehlen nicht als fertig und werden
    beim Fortsetzen erneut versucht."""
    done, records = (set(), [])
    if checkpoint and resume:
        done, records = load_checkpoint(checkpoint)
        if done:
            log(f"Fortsetzung: {len(done)} Kombinationen ({len(records)} Records) aus {checkpoint}")
    for spec in specs:
        for content in contents:
            key = _combo_key(spec, content)
            if key in done:
                continue
            try:
                recs = _collect_spec(client, spec, content, season, sample, log)
                records.extend(recs)
                done.add(key)
                log(f"{key}: {len(recs)} Parses")
                if checkpoint:
                    save_checkpoint(checkpoint, done, records)
            except Exception as e:
                log(f"FEHLER {key}: {e}")
    return records


def save_records(records, path):
    """Rohdaten (ParseRecords) als JSON sichern: ein WCL-Lauf kostet Stunden und Kontingent,
    die Aggregation danach Sekunden -> mit --from-records laesst sie sich offline wiederholen."""
    from dataclasses import asdict
    os.makedirs(os.path.dirname(path) or ".", exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump([asdict(r) for r in records], f)


def load_records(path):
    from pipeline.models import ParseRecord
    with open(path, encoding="utf-8") as f:
        return [ParseRecord(**d) for d in json.load(f)]


def item_name_stub(item_id):
    # Item-Namen werden zur Laufzeit im Addon aufgeloest; hier nur Fallback-Text.
    return f"item:{item_id}"


def build_season(mod):
    """Baut das Season-Dict (fuer Abruf + Aggregation) aus dem season-Modul."""
    return {
        "RATING_PER_PCT": mod.RATING_PER_PCT,
        "MASTERY_COEFF": mod.MASTERY_COEFF,
        "CONSUMABLE_SPELL_TO_ITEM": mod.CONSUMABLE_SPELL_TO_ITEM,
        "CURATE_CONSUMABLES": getattr(mod, "apply_curated_consumables", None),
        "ENCHANT_ITEM_BY_ID": getattr(mod, "ENCHANT_ITEM_BY_ID", {}),
        "RAID_ENCOUNTER_IDS": mod.RAID_ENCOUNTER_IDS,
        "RAID_DIFFICULTY": mod.RAID_DIFFICULTY,
        "MPLUS_ENCOUNTER_IDS": mod.MPLUS_ENCOUNTER_IDS,
        "MPLUS_DIFFICULTY": mod.MPLUS_DIFFICULTY,
        "SAMPLE_TARGET": mod.SAMPLE_TARGET,
        "TRINKET_MIN_ILVL": mod.TRINKET_MIN_ILVL,
        "TRINKET_CURRENT_TRACK_BONUS": mod.TRINKET_CURRENT_TRACK_BONUS,
        "TRINKET_PREV_SEASON_BONUS": mod.TRINKET_PREV_SEASON_BONUS,
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
    ap.add_argument("--dump-records", default="pipeline/cache/records.json",
                    help="Rohdaten nach dem WCL-Abruf hier sichern (gitignored)")
    ap.add_argument("--from-records", default=None,
                    help="statt WCL-Abruf gesicherte Rohdaten laden (offline neu aggregieren)")
    ap.add_argument("--checkpoint", default="pipeline/cache/checkpoint.json",
                    help="Zwischenstand je fertiger Kombination (gitignored); '' = aus")
    ap.add_argument("--resume", action="store_true",
                    help="abgebrochenen Lauf aus --checkpoint fortsetzen (fertige Kombinationen ueberspringen)")
    args = ap.parse_args(argv)

    season = build_season(season_mod)
    if args.from_records:
        records = load_records(args.from_records)
        print(f"{len(records)} Records aus {args.from_records} geladen (kein WCL-Abruf)")
    else:
        client_id, client_secret = load_credentials()
        if not client_id or not client_secret:
            print("WCL-Zugangsdaten fehlen (Umgebungsvariablen oder pipeline/local_secrets.json)",
                  file=sys.stderr)
            return 2

        from pipeline.wcl import WclClient
        client = WclClient(client_id, client_secret)
        records = collect_records(client, SPECS, CONTENTS, season,
                                  sample=season_mod.SAMPLE_TARGET,
                                  checkpoint=args.checkpoint or None, resume=args.resume)
        if args.dump_records:
            save_records(records, args.dump_records)
            print(f"Rohdaten gesichert -> {args.dump_records}")

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
