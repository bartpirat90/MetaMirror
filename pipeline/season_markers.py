"""Season-Wechsel-Waechter + Pflege-Werkzeug fuer die Bonus-ID-Konstanten in season.py.

Grundlage: Upgrade-Track-Bonus-IDs sind pro Season neu und jede Stufe ist an genau EIN
Item-Level gebunden (Midnight-S2: 12843..12846 Hero, 12849..12854 Myth). Aus den
Gear-Eintraegen der emittierten Datendatei laesst sich damit pruefen, ob die
handgepflegten Konstanten noch zur Live-Season passen -- OHNE Clustering ueber
Item-Level.

GESCHEITERTER ANSATZ (2026-09-02, bewusst entfernt): ein "selbstjustierender" Floor als
Minimum des dominanten Ilvl-Clusters. Bei 15 Top-Parses sah das sauber aus (305-334, S1
isoliert bei 298), bei 50 Parses ueber alle Slots fuellen die Raenge 16-50 aber jede
untere Track-Stufe lueckenlos -> das Cluster rutschte auf 253 und alte BfA-Trinkets
kamen zurueck. Item-Level allein trennt Seasons nicht; der Floor bleibt darum die
Konstante TRINKET_MIN_ILVL, die Bonus-IDs liefern Positiv-/Negativbeweise.

CLI:  python -m pipeline.season_markers [Data/MetaMirrorData.lua | <rohdaten>.json]
      -> Ilvl-Verteilung, Bonus-IDs mit genau einem Ilvl (Track-Stufen-Kandidaten),
         Vorsaison-Kandidaten, Konsistenzpruefung der season.py-Konstanten."""
import json
import re
import sys
from collections import Counter, defaultdict

# Ein Bonus/Ilvl muss so oft vorkommen, bevor er als Signal gilt.
DEFAULT_MIN_N = 5
# Track-Stufen liegen 3-4 Ilvl auseinander; reichen die Daten mehr als STEP ueber die
# hoechste bekannte Track-Stufe hinaus, ist das ein neuer Track (= neue Season).
DEFAULT_STEP = 6


def entries_from_lua(path):
    """Gear-Picks aus einer emittierten MetaMirrorData.lua (nur beste Variante je Slot)."""
    txt = open(path, encoding="utf-8").read()
    pat = re.compile(r'itemLevel\s*=\s*(\d+)[^{}]*?bonusIDs\s*=\s*\{([^}]*)\}')
    return [(int(m.group(1)), [int(x) for x in re.findall(r"\d+", m.group(2))])
            for m in pat.finditer(txt)]


def entries_from_json(path):
    """Rohdaten-Dump [{gear: [{item_id, item_level, bonus_ids}]}] -> Eintraege aller Slots."""
    with open(path, encoding="utf-8") as f:
        data = json.load(f)
    out = []
    for rec in data:
        for g in rec.get("gear", []):
            if g.get("item_id") and (g.get("item_level") or 0) > 0:
                out.append((int(g["item_level"]), list(g.get("bonus_ids") or [])))
    return out


def bonus_levels(entries, min_n=DEFAULT_MIN_N):
    """-> {bonus: Counter({ilvl: n})} nur fuer Bonus-IDs mit insgesamt >= min_n Vorkommen."""
    per = defaultdict(Counter)
    for il, bs in entries:
        for b in bs:
            per[b][il] += 1
    return {b: c for b, c in per.items() if sum(c.values()) >= min_n}


def single_level_bonuses(entries, min_n=DEFAULT_MIN_N):
    """Bonus-IDs, die an genau EIN Ilvl gebunden sind -> {bonus: ilvl}. Das sind die
    Track-Stufen-Kandidaten (plus einige item-spezifische Bonusse; der Mensch waehlt)."""
    return {b: next(iter(c)) for b, c in bonus_levels(entries, min_n).items() if len(c) == 1}


def check_markers(entries, track_bonus, prev_bonus, floor, log=print,
                  min_n=DEFAULT_MIN_N, step=DEFAULT_STEP):
    """Season-Wechsel-Waechter. Loggt WARNUNGen und gibt False zurueck, wenn die
    Konstanten den Daten widersprechen:
      - kein konstanter Track-Bonus kommt (>= min_n) vor            -> Konstanten veraltet
      - Daten reichen > step ueber die hoechste bekannte Track-Stufe  -> neuer Track/Season
      - ein Vorsaison-Marker haengt auf/ueber der niedrigsten Track-Stufe
      - der Floor liegt ueber der hoechsten Track-Stufe (alles wuerde verworfen)
      - der Floor liegt nicht ueber den Vorsaison-Marker-Leveln
    Zu wenig Daten (kein Ilvl >= min_n): keine Aussage, True."""
    hist = Counter(il for il, _ in entries)
    solid = [il for il, n in hist.items() if n >= min_n]
    if not solid:
        return True
    levels = bonus_levels(entries, min_n)
    track_levels = sorted({il for b in track_bonus for il in levels.get(b, {})})
    if not track_levels:
        log("WARNUNG Season-Wechsel vermutet: keiner der Track-Bonusse aus season.py kommt "
            "in den Daten vor. TRINKET_CURRENT_TRACK_BONUS pruefen!")
        return False
    ok = True
    top = max(solid)
    if top > max(track_levels) + step:
        log(f"WARNUNG Season-Wechsel vermutet: Daten reichen bis Ilvl {top}, bekannte "
            f"Track-Stufen enden bei {max(track_levels)}. season.py pruefen!")
        ok = False
    prev_levels = sorted({il for b in prev_bonus for il in levels.get(b, {})})
    if prev_levels and max(prev_levels) >= min(track_levels):
        log(f"WARNUNG Season-Wechsel vermutet: Vorsaison-Marker auf Ilvl {max(prev_levels)} "
            f">= niedrigste Track-Stufe {min(track_levels)}. TRINKET_PREV_SEASON_BONUS pruefen!")
        ok = False
    if floor > max(track_levels):
        log(f"WARNUNG Trinket-Floor {floor} liegt ueber der hoechsten Track-Stufe "
            f"{max(track_levels)}: der Ilvl-Pfad wuerde alles verwerfen.")
        ok = False
    if prev_levels and floor <= max(prev_levels):
        log(f"WARNUNG Trinket-Floor {floor} liegt nicht ueber den Vorsaison-Leveln "
            f"{prev_levels}: Vorsaison-Items wuerden ueber den Ilvl-Pfad behalten.")
        ok = False
    return ok


def main(argv=None):
    argv = list(sys.argv[1:] if argv is None else argv)
    path = argv[0] if argv else "Data/MetaMirrorData.lua"
    entries = entries_from_json(path) if path.endswith(".json") else entries_from_lua(path)
    if not entries:
        print("keine Gear-Eintraege gefunden")
        return 1
    hist = Counter(il for il, _ in entries)
    print(f"Eintraege: {len(entries)}  Ilvl-Verteilung: {dict(sorted(hist.items()))}")
    single = single_level_bonuses(entries)
    print("Bonus-IDs mit genau EINEM Ilvl (Track-Stufen-Kandidaten, nach Ilvl):")
    for b, il in sorted(single.items(), key=lambda kv: (kv[1], kv[0])):
        print(f"  {b:6d} -> {il}")
    try:
        from pipeline import season
    except ImportError:
        return 0
    track = season.TRINKET_CURRENT_TRACK_BONUS
    levels = bonus_levels(entries)
    track_levels = sorted({il for b in track for il in levels.get(b, {})})
    if track_levels:
        lo = min(track_levels)
        prev = sorted(b for b, c in levels.items() if all(il < lo for il in c))
        print(f"bekannte Track-Stufen in den Daten: {track_levels}")
        print(f"Vorsaison-Kandidaten (nur unter {lo}): {prev}")
    ok = check_markers(entries, track, season.TRINKET_PREV_SEASON_BONUS, season.TRINKET_MIN_ILVL)
    print("season.py-Konstanten: " + ("konsistent" if ok else "WIDERSPRUCH (siehe oben)"))
    return 0


if __name__ == "__main__":
    sys.exit(main())
