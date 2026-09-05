"""Orchestrator: bloodmallet secondary_distributions + SimC-Profile -> Data/MetaMirrorData.lua.

Einziger Datenpfad des Addons (der fruehere Warcraft-Logs-Pfad ist entfernt): statt
Top-Parses zu aggregieren, wird
je Spec x Content GENAU EIN Sim-Profil verwendet (sample_size=1). Stats + Gear kommen aus
bloodmallet_sd.py (ein Payload pro Fight-Style deckt Stats UND Gear ab), Verbrauchsgueter
zusaetzlich aus simc_profile.py (SimC-Profile fuehren Flask/Trank/Rune/Oel, bloodmallet nicht).

Aufruf:  python -m pipeline.build_sim [--out Data/MetaMirrorData.lua] [--offline]
                                       [--only mage/frost] [--min-specs 20]
"""
import argparse
import json
import os
import sys
import time
from collections import defaultdict
from datetime import date

from pipeline.bloodmallet_sd import (
    FIGHT_STYLE_BY_CONTENT, parse_distribution, stats_from_distribution, gear_from_profile,
)
from pipeline import bloodmallet_sd, simc_profile
from pipeline.simc_profile import parse_profile, consumable_item_ids
from pipeline.season import apply_curated_consumables, SEASON_NAME
from pipeline.specs import SPECS, CONTENTS
from pipeline.models import AggregatedSpec
from pipeline.emit_lua import emit_lua
from pipeline.validate import validate
from pipeline.trinkets import slug as _slug

CACHE_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "cache", "sim")
REQUEST_PAUSE = 0.3   # Hoeflichkeitspause zwischen Netzaufrufen (Sekunden)
DEFAULT_MIN_SPECS = 20


def build_spec(spec, content, sd_payload, simc_text):
    """Ein bloodmallet-Payload (+ optionaler SimC-Profiltext) -> AggregatedSpec (sample_size=1).
    sd_payload wird ueber parse_distribution() gelesen -- wirft ValueError bei Fehler-Payload
    (Aufrufer faengt das ab und ueberspringt die Kombination). simc_text=None (kein Profil in
    MID2/MID1 gefunden) -> Consumables nur kuratiert (food/potion/ggf. Oel), kein flask/rune."""
    parsed = parse_distribution(sd_payload)
    stats = stats_from_distribution(parsed)
    gear, gems, enchants = gear_from_profile(sd_payload)

    ids = {}
    if simc_text:
        profile = parse_profile(simc_text)
        ids, _unknown = consumable_item_ids(profile["consumables"])
    consumables = apply_curated_consumables(spec.spec_id, ids)

    return AggregatedSpec(sample_size=1, stats=stats, gear=gear, gems=gems,
                          enchants=enchants, consumables=consumables)


def build(specs, contents, fetch_sd, fetch_simc, log=print, min_specs=DEFAULT_MIN_SPECS):
    """specs durchgehen, je Spec ein SimC-Profil (fetch_simc: MID2->MID1->None-Fallback
    steckt in der injizierten Funktion selbst), je Content ein bloodmallet-Payload
    (fetch_sd). Fehler/Fehler-Payload je Spec x Content -> ueberspringen + loggen.

    Rueckgabe: (plain_data, meta). plain_data: {classID: {specID: {content: AggregatedSpec}}}.
    meta: fightStyles, simcHash (aus dem ersten erfolgreichen Payload), generated (heutiges
    Datum ISO), bloodmalletTimestamp, specsWithData, skipped (Liste uebersprungener
    'Class/Spec/Content'-Kombinationen).

    Abbruchregel: weniger als min_specs Specs mit mindestens einem Content -> RuntimeError,
    nichts geschrieben (Aufrufer ruft write() dann gar nicht erst auf)."""
    data = defaultdict(lambda: defaultdict(dict))
    skipped = []
    specs_with_data = set()
    simc_hash = None
    bloodmallet_timestamp = None

    for spec in specs:
        try:
            simc_text = fetch_simc(spec.class_name, spec.spec_name)
        except Exception as e:
            log(f"SimC-Profil {spec.class_name}/{spec.spec_name}: {e}")
            simc_text = None
        if simc_text is None:
            log(f"{spec.class_name}/{spec.spec_name}: kein SimC-Profil (MID2/MID1) "
                "-> Consumables nur kuratiert")

        for content in contents:
            fight_style = FIGHT_STYLE_BY_CONTENT[content]
            combo = f"{spec.class_name}/{spec.spec_name}/{content}"
            try:
                payload = fetch_sd(spec.class_name, spec.spec_name, fight_style)
                agg = build_spec(spec, content, payload, simc_text)
            except Exception as e:
                log(f"uebersprungen: {combo}: {e}")
                skipped.append(combo)
                continue

            data[spec.class_id][spec.spec_id][content] = agg
            specs_with_data.add((spec.class_id, spec.spec_id))
            if simc_hash is None:
                try:
                    meta_parsed = parse_distribution(payload)
                    simc_hash = meta_parsed.get("simc_hash")
                    bloodmallet_timestamp = meta_parsed.get("timestamp")
                except ValueError:
                    pass

    if len(specs_with_data) < min_specs:
        raise RuntimeError(
            f"nur {len(specs_with_data)} Specs mit Daten (< {min_specs}) -- Abbruch, "
            f"nichts geschrieben. Uebersprungen: {skipped}"
        )

    plain = {cid: {sid: dict(c) for sid, c in specs_.items()} for cid, specs_ in data.items()}
    meta = {
        "fightStyles": dict(FIGHT_STYLE_BY_CONTENT),
        "simcHash": simc_hash,
        "generated": date.today().isoformat(),
        "bloodmalletTimestamp": bloodmallet_timestamp,
        "specsWithData": len(specs_with_data),
        "skipped": skipped,
    }
    return plain, meta


def write(plain, meta, out_path):
    """validate() (min_sample=1, sample_size ist bei Sim-Daten immer 1) -> bei Fehlern
    RuntimeError mit Liste, nichts geschrieben. Sonst emit_lua() -> Datei mit newline='\n'."""
    errors = validate(plain, min_sample=1)
    if errors:
        raise RuntimeError("Validierung fehlgeschlagen:\n" + "\n".join(errors))

    extra = {
        "fightStyles": meta["fightStyles"],
        "generated": meta["generated"],
        "simcHash": meta.get("simcHash"),
        "sources": {
            "stats": "bloodmallet.com secondary distributions",
            "gear": "SimulationCraft MID2 profiles",
        },
    }
    lua = emit_lua(plain, version=f"sim-{meta['generated']}", season=SEASON_NAME, extra=extra)
    os.makedirs(os.path.dirname(out_path) or ".", exist_ok=True)
    with open(out_path, "w", encoding="utf-8", newline="\n") as f:
        f.write(lua)


# ---- Cache + Live-Fetcher (fuer den echten Lauf; Tests injizieren eigene Fetch-Funktionen) --

def _sd_cache_path(cache_dir, class_name, spec_name, fight_style):
    return os.path.join(cache_dir, f"{_slug(class_name)}_{_slug(spec_name)}_{fight_style}.json")


def _simc_cache_path(cache_dir, class_name, spec_name):
    return os.path.join(cache_dir, f"{_slug(class_name)}_{_slug(spec_name)}.simc")


def make_fetchers(cache_dir=CACHE_DIR, offline=False, log=print):
    """Liefert (fetch_sd, fetch_simc) fuer build(). Online: ruft die echten fetch()-Funktionen
    aus bloodmallet_sd/simc_profile auf, cacht die Rohantwort, pausiert REQUEST_PAUSE zwischen
    Aufrufen. Offline (--offline): liest AUSSCHLIESSLICH aus dem Cache, keine Netzaufrufe."""
    os.makedirs(cache_dir, exist_ok=True)

    def fetch_sd(class_name, spec_name, fight_style):
        path = _sd_cache_path(cache_dir, class_name, spec_name, fight_style)
        if offline:
            if not os.path.exists(path):
                raise FileNotFoundError(f"--offline: kein Cache fuer {path}")
            with open(path, encoding="utf-8") as f:
                return json.load(f)
        payload = bloodmallet_sd.fetch(class_name, spec_name, fight_style)
        with open(path, "w", encoding="utf-8") as f:
            json.dump(payload, f)
        time.sleep(REQUEST_PAUSE)
        return payload

    def fetch_simc(class_name, spec_name):
        path = _simc_cache_path(cache_dir, class_name, spec_name)
        if offline:
            if not os.path.exists(path):
                log(f"--offline: kein SimC-Cache fuer {class_name}/{spec_name}")
                return None
            with open(path, encoding="utf-8") as f:
                text = f.read()
            return text or None   # leere Datei = "geprueft, kein Profil in MID2/MID1"
        for tier in ("MID2", "MID1"):
            text = simc_profile.fetch(class_name, spec_name, tier)
            time.sleep(REQUEST_PAUSE)
            if text:
                with open(path, "w", encoding="utf-8") as f:
                    f.write(text)
                return text
        with open(path, "w", encoding="utf-8") as f:
            f.write("")   # kein Profil in MID2 noch MID1 -> als geprueft markieren
        return None

    return fetch_sd, fetch_simc


def _matches_only(spec, wanted):
    key = f"{_slug(spec.class_name)}/{_slug(spec.spec_name)}"
    return key in wanted


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="Data/MetaMirrorData.lua")
    ap.add_argument("--offline", action="store_true",
                    help="nur aus pipeline/cache/sim/ lesen, keine Netzaufrufe")
    ap.add_argument("--only", action="append", default=[],
                    help="Slug-Filter 'class/spec' (z.B. mage/frost), mehrfach angebbar")
    ap.add_argument("--min-specs", type=int, default=DEFAULT_MIN_SPECS)
    args = ap.parse_args(argv)

    specs = SPECS
    if args.only:
        wanted = {o.strip().lower() for o in args.only}
        specs = [s for s in SPECS if _matches_only(s, wanted)]
        if not specs:
            print("Kein Spec passt zu --only", file=sys.stderr)
            return 2

    fetch_sd, fetch_simc = make_fetchers(offline=args.offline, log=print)

    try:
        plain, meta = build(specs, CONTENTS, fetch_sd, fetch_simc, log=print,
                            min_specs=args.min_specs)
    except RuntimeError as e:
        print(f"ABBRUCH: {e}", file=sys.stderr)
        return 1

    try:
        write(plain, meta, args.out)
    except RuntimeError as e:
        print(f"VALIDIERUNG ROT — kein Commit: {e}", file=sys.stderr)
        return 1

    print(f"OK -> {args.out}  ({meta['specsWithData']} Specs mit Daten, "
          f"{len(meta['skipped'])} uebersprungen)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
