"""Trinket-Ranking aus bloodmallet.com (Sim-BiS) -> Data/MetaMirrorTrinkets.lua.

Getrennte Quelle vom WCL-Datensatz: Bloodmallet ist oeffentlich (kein Login) und liefert
die VOLLSTAENDIGE, simulierte Trinket-Rangliste pro Spec -- inkl. Stat-Modi desselben
Trinkets (z.B. Rubinwelpenschale [Haste]/[Crit]/[St]/[Aoe], alle gleiche itemID). Genau
diese Vollstaendigkeit will der Nutzer; deshalb hier KEIN Cap und KEINE itemID-Dedup, und
der Modus (Klammer-Suffix) wird als eigenes Feld mitgefuehrt, damit die UI ihn als
"(Tempo)" o.ae. anzeigen kann.

Endpunkt: /chart/get/{type}/{fight_style}/{class}/{spec}
JSON: { data:{name:{ilvl:dps}}, item_ids:{name:id}, simulated_steps:[...], ... }

Aufruf:  python -m pipeline.trinkets [--out Data/MetaMirrorTrinkets.lua]
"""
import argparse
import re
import sys

from pipeline.specs import SPECS
from pipeline.season import TRINKET_MIN_ILVL

BASE = "https://bloodmallet.com/chart/get"

# Stand Midnight (MID2) real bespielt ist derzeit nur "castingpatchwerk" (Einzelziel, je
# Spec korrekt); "patchwerk"/"hecticaddcleave" liefern leer. Wir probieren eine Liste durch
# und nehmen den ersten nicht-leeren Style. Sobald M+-Profile kommen, fuellt ein Re-Run die
# Dungeon-Sicht automatisch.
SINGLE_TARGET_STYLES = ["castingpatchwerk", "patchwerk"]
DUNGEON_STYLES = ["hecticaddcleave"]

_MODE_RE = re.compile(r"\[([^\]]+)\]\s*$")   # "Ruby Whelp Shell [Haste]" -> "Haste"


def _is_excluded(name):
    low = name.lower()
    return low == "baseline" or "gladiator" in low   # kein Item / PvP -> raus


def _mode_of(name):
    m = _MODE_RE.search(name)
    return m.group(1) if m else None


def slug(name):
    """CamelCase -> snake_case: 'DeathKnight'->'death_knight', 'BeastMastery'->'beast_mastery'."""
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name).lower()


def endpoint(class_name, spec_name, fight_style):
    return f"{BASE}/trinkets/{fight_style}/{slug(class_name)}/{slug(spec_name)}"


def parse_ranking(payload):
    """Bloodmallet-JSON -> [{itemID, name, mode, dps}] absteigend nach DPS.

    Jedes Trinket bei SEINEM hoechsten simulierten Item-Level (eigenes ilvl-Cap = realer
    BiS-Wert). KEINE Dedup: Stat-Modi desselben Trinkets bleiben getrennte Eintraege."""
    data = payload.get("data") or {}
    item_ids = payload.get("item_ids") or {}
    if not data:
        return []
    out = []
    for name, per_ilvl in data.items():
        iid = item_ids.get(name)
        if not iid or _is_excluded(name):
            continue
        steps = [int(k) for k in per_ilvl.keys() if str(k).isdigit()]
        if not steps:
            continue
        cap = max(steps)                 # hoechstes simuliertes Item-Level = Sim-BiS-Cap
        dps = per_ilvl.get(str(cap))
        if not dps:
            continue
        out.append({"itemID": int(iid), "name": name, "ilvl": cap,
                    "mode": _mode_of(name), "dps": float(dps)})
    out.sort(key=lambda t: t["dps"], reverse=True)
    return out


def drop_prev_seasons(ranking, floor=TRINKET_MIN_ILVL):
    """Entfernt Trinkets unter dem Season-Floor. Bloodmallet simuliert jedes Trinket bei
    SEINEM hoechsten Item-Level; liegt dieses Cap unter dem Floor, ist es Vorsaison oder
    PvP (nicht auf aktuellem Season-Niveau) -> raus. Ein alter Effekt, den Bloodmallet
    selbst auf S2-Ilvl hochskaliert, liegt ueber dem Floor und bleibt. Erwartet
    parse_ranking-Eintraege (Feld 'ilvl')."""
    return [t for t in ranking if t.get("ilvl", 0) >= floor]


# S-Tier NICHT prozentual: Sim-DPS liegen so dicht beieinander (Top-Feld < 1% Spanne),
# dass eine %-Schwelle ein Dutzend S produziert -> unglaubwuerdig. Stattdessen rang-basiert:
# nur die 2 besten sind S (die 3., wenn sie praktisch gleichauf mit #1 liegt), dann feste
# Rang-Buckets. So heben sich die wirklich besten Trinkets sichtbar ab.
_S_TIE_MARGIN = 0.15   # #3 wird nur S, wenn <=0.15% Rueckstand auf #1 (echter Gleichstand)
_A_SIZE, _B_SIZE, _C_SIZE = 5, 8, 12


def with_tiers(ranking):
    """Ergaenzt tier + pct je Eintrag; erwartet DPS-sortiert. VOLLSTAENDIG (kein Cap).
    Tiers rang-basiert: S = Top 2 (Top 3 nur bei Quasi-Gleichstand), dann A/B/C/D-Buckets."""
    if not ranking:
        return []
    top = ranking[0]["dps"] or 1.0
    n = len(ranking)
    s_count = min(2, n)
    if n >= 3 and (top - ranking[2]["dps"]) / top * 100.0 <= _S_TIE_MARGIN:
        s_count = 3
    a_end = s_count + _A_SIZE
    b_end = a_end + _B_SIZE
    c_end = b_end + _C_SIZE
    out = []
    for i, t in enumerate(ranking):
        if i < s_count:
            tier = "S"
        elif i < a_end:
            tier = "A"
        elif i < b_end:
            tier = "B"
        elif i < c_end:
            tier = "C"
        else:
            tier = "D"
        out.append({"itemID": t["itemID"], "tier": tier,
                    "pct": round(t["dps"] / top * 100.0, 1), "mode": t.get("mode")})
    return out


def blend_overall(raid, dungeon):
    """Overall = Mittel der normierten DPS beider Sichten. Schluessel = voller Name (je
    Stat-Modus eindeutig), damit Modi NICHT zusammenfallen. raid/dungeon: rohe Listen."""
    def norm(ranking):
        if not ranking:
            return {}
        top = ranking[0]["dps"] or 1.0
        return {t["name"]: t["dps"] / top for t in ranking}
    nr, nd = norm(raid), norm(dungeon)
    meta = {}
    for t in list(raid) + list(dungeon):
        meta.setdefault(t["name"], {"itemID": t["itemID"], "mode": t.get("mode"), "name": t["name"]})
    scored = []
    for name, info in meta.items():
        vals = [v for v in (nr.get(name), nd.get(name)) if v is not None]
        scored.append({"itemID": info["itemID"], "name": name,
                       "mode": info["mode"], "dps": sum(vals) / len(vals)})
    scored.sort(key=lambda t: t["dps"], reverse=True)
    return scored


def build_spec_views(raid_raw, dungeon_raw):
    """Rohlisten -> {raid, dungeon, overall, singleSource}. Fehlt die Dungeon-Sicht, faellt
    Dungeon+Overall auf Einzelziel zurueck (singleSource=True fuer den UI-Hinweis)."""
    if dungeon_raw:
        return {
            "raid": with_tiers(raid_raw),
            "dungeon": with_tiers(dungeon_raw),
            "overall": with_tiers(blend_overall(raid_raw, dungeon_raw)),
            "singleSource": False,
        }
    tiered = with_tiers(raid_raw)
    return {"raid": tiered, "dungeon": tiered, "overall": tiered, "singleSource": True}


def _lua_view(entries):
    parts = []
    for e in entries:
        mode = f', mode = "{e["mode"]}"' if e.get("mode") else ""
        parts.append(f'{{ itemID = {e["itemID"]}, tier = "{e["tier"]}", pct = {e["pct"]}{mode} }}')
    return "{ " + ", ".join(parts) + " }"


def emit_lua(spec_views, version):
    lines = [
        "-- Generiert aus bloodmallet.com (Sim-BiS Trinkets). NICHT von Hand bearbeiten.",
        "MetaMirrorTrinkets = {",
        f'    version = "{version}",',
        '    source = "Data from bloodmallet.com",',
        "    specs = {",
    ]
    for spec_id in sorted(spec_views):
        v = spec_views[spec_id]
        if not (v["raid"] or v["dungeon"] or v["overall"]):
            continue
        lines.append(f"        [{spec_id}] = {{")
        lines.append(f"            singleSource = {'true' if v.get('singleSource') else 'false'},")
        for key in ("overall", "raid", "dungeon"):
            lines.append(f"            {key} = {_lua_view(v[key])},")
        lines.append("        },")
    lines.append("    },")
    lines.append("}")
    return "\n".join(lines) + "\n"


def fetch_json(client, url):
    r = client.get(url, timeout=60.0)
    if r.status_code != 200:
        return None
    try:
        return r.json()
    except Exception:
        return None


def _first_nonempty(client, class_name, spec_name, styles):
    for style in styles:
        raw = parse_ranking(fetch_json(client, endpoint(class_name, spec_name, style)) or {})
        if raw:
            return raw
    return []


def collect(client, specs, log=print, floor=TRINKET_MIN_ILVL):
    result = {}
    for spec in specs:
        raid_all = _first_nonempty(client, spec.class_name, spec.spec_name, SINGLE_TARGET_STYLES)
        dung_all = _first_nonempty(client, spec.class_name, spec.spec_name, DUNGEON_STYLES)
        # Vorsaison + PvP herausfiltern (nur Trinkets auf aktuellem Season-Ilvl behalten).
        raid_raw = drop_prev_seasons(raid_all, floor)
        dung_raw = drop_prev_seasons(dung_all, floor)
        if not raid_raw and not dung_raw:
            log(f"  keine aktuellen Bloodmallet-Daten: {spec.class_name}/{spec.spec_name}")
            continue
        result[spec.spec_id] = build_spec_views(raid_raw, dung_raw)
        tag = " [nur Einzelziel]" if result[spec.spec_id]["singleSource"] else ""
        dropped = (len(raid_all) - len(raid_raw)) + (len(dung_all) - len(dung_raw))
        log(f"{spec.class_name}/{spec.spec_name}: single={len(raid_raw)} dungeon={len(dung_raw)}"
            f" (Vorsaison/PvP entfernt: {dropped}){tag}")
    return result


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="Data/MetaMirrorTrinkets.lua")
    args = ap.parse_args(argv)

    import httpx
    from datetime import date
    with httpx.Client(headers={"User-Agent": "MetaMirror/0.9"}) as client:
        views = collect(client, SPECS)
    if not views:
        print("Keine Trinket-Daten abgerufen (Bloodmallet nicht erreichbar?)", file=sys.stderr)
        return 1
    lua = emit_lua(views, version=f"bm-{date.today().isoformat()}")
    with open(args.out, "w", encoding="utf-8", newline="\n") as f:
        f.write(lua)
    print(f"OK -> {args.out}  ({len(views)} Specs)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
