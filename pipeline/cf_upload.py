# -*- coding: utf-8 -*-
"""CurseForge-Upload fuer MetaMirror.

Baut aus dem Repo ein sauberes Addon-ZIP (nur Runtime-Dateien laut .toc + die
Texturen) und laedt es ueber die CurseForge-Upload-API hoch. Zugangsdaten kommen
aus Umgebungsvariablen (CI/GitHub-Secrets) oder der gitignorierten
pipeline/local_secrets.json:

    CURSEFORGE_TOKEN        persoenliches API-Token (Settings -> My API Tokens)
    CURSEFORGE_PROJECT_ID   Projekt-ID (Zahl, steht auf der CurseForge-Projektseite)

Beispiele:
    python -m pipeline.cf_upload --dry-run
    python -m pipeline.cf_upload --release-type release --changelog "Erstes Release"
    python -m pipeline.cf_upload --append-date --changelog "Woechentlicher Meta-Refresh"

Die Upload-API ist dokumentiert unter:
    https://support.curseforge.com/support/solutions/articles/9000197321-curseforge-upload-api
"""
import argparse
import datetime
import io
import json
import os
import sys
import zipfile

import httpx

BASE = "https://wow.curseforge.com/api"
REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
TOC = os.path.join(REPO, "MetaMirror.toc")
# Nicht-Lua-Assets, die die .toc nicht listet, aber ins Addon gehoeren.
EXTRA_ASSETS = ["Icon.tga", "bar-mask.tga"]


# ---------------------------------------------------------------- Secrets
def load_secret(key):
    """Erst Umgebungsvariable, sonst pipeline/local_secrets.json."""
    v = os.environ.get(key)
    if v:
        return v
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "local_secrets.json")
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            data = json.load(f)
        val = data.get(key)
        if val:
            return str(val)
    return None


# ------------------------------------------------------------- .toc lesen
def parse_toc(path):
    """Liefert (version, interface, [gelistete_dateien]) aus der .toc."""
    version, interface, files = None, None, []
    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.strip()
            if not line:
                continue
            if line.startswith("##"):
                if line[2:].strip().lower().startswith("version:"):
                    version = line.split(":", 1)[1].strip()
                elif line[2:].strip().lower().startswith("interface:"):
                    interface = line.split(":", 1)[1].strip()
                continue
            if line.startswith("#"):
                continue
            files.append(line.replace("\\", "/"))
    return version, interface, files


def iface_to_version(interface):
    """Interface-Nummer XXYYZZ -> 'X.Y.Z' (z.B. 120100 -> '12.1.0')."""
    n = int(interface)
    return "{}.{}.{}".format(n // 10000, (n // 100) % 100, n % 100)


# ------------------------------------------------------------- ZIP bauen
def build_zip():
    """Baut das Addon-ZIP im Speicher (Top-Level-Ordner 'MetaMirror/').
    Enthaelt genau die .toc, die dort gelisteten Lua-Dateien und die Texturen –
    niemals Pipeline, Secrets, Screenshots o.ae."""
    version, interface, listed = parse_toc(TOC)
    members = ["MetaMirror.toc"] + listed + EXTRA_ASSETS
    buf = io.BytesIO()
    missing = []
    with zipfile.ZipFile(buf, "w", zipfile.ZIP_DEFLATED) as z:
        for rel in members:
            src = os.path.join(REPO, rel)
            if not os.path.exists(src):
                missing.append(rel)
                continue
            z.write(src, arcname="MetaMirror/" + rel)
    if missing:
        raise FileNotFoundError("Fehlende Addon-Dateien: " + ", ".join(missing))
    return version, interface, buf.getvalue()


# --------------------------------------------------------- Spielversionen
def resolve_game_version_ids(token, wanted_version, override_ids):
    if override_ids:
        return list(override_ids)
    r = httpx.get(BASE + "/game/versions", headers={"X-Api-Token": token}, timeout=60)
    r.raise_for_status()
    versions = r.json()
    matches = [v for v in versions if v.get("name") == wanted_version]
    if not matches:
        avail = sorted({v.get("name") for v in versions
                        if str(v.get("name", "")).startswith(wanted_version.split(".")[0] + ".")})
        raise SystemExit(
            "Keine CurseForge-Spielversion '{}' gefunden.\n".format(wanted_version)
            + "Verfuegbar (gleiche Erweiterung): {}\n".format(", ".join(avail) or "-")
            + "Setze die passende per --game-version <name> oder --game-version-id <id>.")
    return [v["id"] for v in matches]


# --------------------------------------------------------------- Upload
def upload(token, project_id, filename, zip_bytes, metadata):
    url = "{}/projects/{}/upload-file".format(BASE, project_id)
    files = {"file": (filename, zip_bytes, "application/zip")}
    data = {"metadata": json.dumps(metadata)}
    r = httpx.post(url, headers={"X-Api-Token": token}, data=data, files=files, timeout=180)
    if r.status_code >= 300:
        raise SystemExit("Upload fehlgeschlagen ({}): {}".format(r.status_code, r.text))
    return r.json()


# ----------------------------------------------------------------- main
def main(argv=None):
    ap = argparse.ArgumentParser(description="MetaMirror -> CurseForge-Upload")
    ap.add_argument("--release-type", choices=["release", "beta", "alpha"], default="release")
    ap.add_argument("--changelog", default="Data and fixes update.")
    ap.add_argument("--changelog-file", help="Changelog aus Datei lesen (ueberschreibt --changelog)")
    ap.add_argument("--changelog-type", choices=["text", "html", "markdown"], default="text")
    ap.add_argument("--name", help="Anzeigename (Standard: 'MetaMirror <version>')")
    ap.add_argument("--append-date", action="store_true", help="Datum an den Anzeigenamen haengen")
    ap.add_argument("--game-version", help="Spielversion-Name erzwingen (z.B. 12.1.0)")
    ap.add_argument("--game-version-id", type=int, action="append", help="Version-ID(s) hart setzen")
    ap.add_argument("--dry-run", action="store_true", help="ZIP bauen + Versionen aufloesen, NICHT hochladen")
    args = ap.parse_args(argv)

    token = load_secret("CURSEFORGE_TOKEN")
    project_id = load_secret("CURSEFORGE_PROJECT_ID")
    if not token and not args.dry_run:
        print("CURSEFORGE_TOKEN fehlt (Umgebung oder local_secrets.json).", file=sys.stderr)
        return 2
    if not project_id and not args.dry_run:
        print("CURSEFORGE_PROJECT_ID fehlt (Umgebung oder local_secrets.json).", file=sys.stderr)
        return 2

    version, interface, zip_bytes = build_zip()
    filename = "MetaMirror-{}.zip".format(version or "0.0")
    display = args.name or "MetaMirror {}".format(version or "")
    if args.append_date:
        display = "{} ({})".format(display, datetime.date.today().isoformat())

    changelog = args.changelog
    if args.changelog_file:
        with open(args.changelog_file, encoding="utf-8") as f:
            changelog = f.read()

    wanted = args.game_version or iface_to_version(interface)
    # Versionsauflösung braucht das Token; im Trockenlauf ohne Token einfach überspringen.
    gv_ids = resolve_game_version_ids(token, wanted, args.game_version_id) if token else None

    print("Datei         : {} ({:.1f} KB)".format(filename, len(zip_bytes) / 1024))
    print("Anzeigename   : {}".format(display.strip()))
    print("Spielversion  : {} -> IDs {}".format(wanted, gv_ids if gv_ids is not None else "(kein Token -> uebersprungen)"))
    print("Release-Typ   : {}".format(args.release_type))
    if args.dry_run:
        print("[dry-run] Es wurde NICHT hochgeladen.")
        return 0

    metadata = {
        "changelog": changelog,
        "changelogType": args.changelog_type,
        "displayName": display.strip(),
        "gameVersions": gv_ids,
        "releaseType": args.release_type,
    }
    res = upload(token, project_id, filename, zip_bytes, metadata)
    print("Hochgeladen. Datei-ID: {}".format(res.get("id")))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
