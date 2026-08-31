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


def collect_records(client, specs, contents, season):
    """Live-Abruf ueber die WCL-API. Duenn gehalten; Struktur-Details in fetch.py.
    Muss beim ersten Lauf mit echten Credentials gegen reale Antworten verifiziert werden."""
    from pipeline.fetch import parse_combatant_info
    records = []
    # Pseudo-Ablauf pro Spec x Content:
    #   1) Rankings-Query -> Liste (reportCode, fightID, sourceID, start, end)
    #   2) je Eintrag CombatantInfo-Events -> parse_combatant_info(...)
    # Die konkreten GraphQL-Strings/Feldnamen hier einsetzen, sobald live verifiziert.
    raise NotImplementedError("Live-Abruf: GraphQL-Strings nach Verifikation ergaenzen")


def item_name_stub(item_id):
    # Item-Namen werden zur Laufzeit im Addon aufgeloest; hier nur Fallback-Text.
    return f"item:{item_id}"


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
    ap.add_argument("--min-sample", type=int, default=15)
    args = ap.parse_args(argv)

    client_id, client_secret = load_credentials()
    if not client_id or not client_secret:
        print("WCL-Zugangsdaten fehlen (Umgebungsvariablen oder pipeline/local_secrets.json)",
              file=sys.stderr)
        return 2

    from pipeline.wcl import WclClient
    client = WclClient(client_id, client_secret)
    season = {"RATING_PER_PCT": season_mod.RATING_PER_PCT,
              "MASTERY_COEFF": season_mod.MASTERY_COEFF,
              "CONSUMABLE_SPELL_TO_ITEM": season_mod.CONSUMABLE_SPELL_TO_ITEM}
    records = collect_records(client, SPECS, CONTENTS, season)

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
