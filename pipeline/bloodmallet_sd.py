"""Bloodmallet secondary_distributions -> Stats + Gear-Profil je Spec/Fight-Style.

Ersatz fuer die verlorenen Warcraft-Logs-Daten (RPGLogs-Ablehnung, 2026-09-04): bloodmallet
simuliert die optimale Sekundaerwert-Verteilung UND liefert in derselben Antwort das dazu
passende (Sim-BiS-)Gear-Profil. Oeffentlich, kein Login (bloodmallet-FAQ: "All data is free
to use for everyone").

Endpunkt: /chart/get/secondary_distributions/{fight_style}/{class}/{spec}
JSON-Form (live gegen mage/frost, warrior/arms, death_knight/unholy, hunter/beast_mastery
verifiziert, siehe docs/research/2026-09-04-data-formats.md Abschnitt A):
  data[tier][key] = dps (int); key = "<crit>_<haste>_<mastery>_<vers>" in Prozent, Summe 100.
  sorted_data_keys[tier] = [key, ...] absteigend nach dps -> [0] ist die beste Verteilung.
  secondary_sum = Summe der Sekundaerwert-Ratings des simulierten Profils (Rating-Basis).
  profile.items[slot] = {id, bonus_id "a/b/c", gem_id "a/b", enchant_id, crafted_stats, ...}
    (alle Werte als String; id/enchant_id/Bonus-/Gem-Listen muessen selbst int()-gewandelt
    werden). Slotnamen bereits die simc-ueblichen (siehe SLOT_MAP).
  HTTP ist bei bloodmallet IMMER 200 -- Fehler zeigen sich nur im Body
  ({"status": "error", "message": "..."}), daher is_error() statt raise_for_status().
"""
import httpx

from pipeline.trinkets import slug
from pipeline.specs import STAT_KEYS
from pipeline import season

BASE = "https://bloodmallet.com/chart/get"

# raid = Einzelziel (castingpatchwerk, wie in trinkets.py der real bespielte Style),
# mythicplus = 3-Ziel-Variante (castingpatchwerk3). Fuenf-Ziel (castingpatchwerk5) und
# hecticaddcleave existieren als Fight-Styles, liefern fuer diesen Chart-Typ aber teils
# keine Daten (hecticaddcleave -> "No standard chart") -- daher hier nicht verwendet.
FIGHT_STYLE_BY_CONTENT = {"raid": "castingpatchwerk", "mythicplus": "castingpatchwerk3"}

# simc-Slotname -> Addon-Slotname, exakt wie pipeline/fetch.py GEAR_SLOT_BY_INDEX / UI.lua
# SLOT_ORDER (gegengeprueft, siehe Plan-Abschnitt "Slot-Mapping").
SLOT_MAP = {
    "head": "HEAD", "neck": "NECK", "shoulders": "SHOULDER", "back": "BACK",
    "chest": "CHEST", "wrists": "WRIST", "hands": "HANDS", "waist": "WAIST",
    "legs": "LEGS", "feet": "FEET", "finger1": "RING1", "finger2": "RING2",
    "trinket1": "TRINKET1", "trinket2": "TRINKET2",
    "main_hand": "MAINHAND", "off_hand": "OFFHAND",
}


def endpoint(class_name, spec_name, fight_style):
    return f"{BASE}/secondary_distributions/{fight_style}/{slug(class_name)}/{slug(spec_name)}"


def is_error(payload):
    """HTTP ist bei bloodmallet immer 200; Fehler/Leerfall nur am Body erkennbar."""
    return not payload or payload.get("status") == "error" or "data" not in payload


def _split_ids(field):
    """'12345/67890' -> [12345, 67890]; leere/nicht-numerische Teile raus (bloodmallet
    laesst das Feld bei manchen Slots ganz weg -> field kann auch None sein)."""
    if not field:
        return []
    out = []
    for part in str(field).split("/"):
        part = part.strip()
        if part.isdigit() and int(part) != 0:
            out.append(int(part))
    return out


def parse_distribution(payload):
    """Beste Sekundaerwert-Verteilung eines Payloads -> dict mit tier, top_key, pct{...},
    secondary_sum, dps, timestamp, simc_hash. ValueError bei Fehler-Payload oder fehlenden
    Pflichtfeldern.

    bloodmallet liefert aktuell (Midnight, Tier MID2) immer genau einen tier-Key ("MID2");
    fuer den Fall, dass ein Chart doch mehrere Talent-/Profil-Varianten fuehrt, nehmen wir
    die mit der hoechsten Top-DPS -- ein dokumentiertes Tie-Break-Kriterium gibt es nicht,
    andere Kandidaten (z.B. alphabetisch) waeren ebenso willkuerlich."""
    if is_error(payload):
        raise ValueError("bloodmallet: Fehler-Payload (status=error oder data fehlt)")
    data = payload.get("data") or {}
    sorted_keys = payload.get("sorted_data_keys") or {}
    secondary_sum = payload.get("secondary_sum")
    if not data or not sorted_keys or secondary_sum is None:
        raise ValueError("bloodmallet: Payload unvollstaendig (data/sorted_data_keys/secondary_sum)")

    def _top_dps(t):
        keys = sorted_keys.get(t) or []
        return data.get(t, {}).get(keys[0], -1) if keys else -1

    tier = max(data.keys(), key=_top_dps)
    top_keys = sorted_keys.get(tier) or []
    if not top_keys:
        raise ValueError("bloodmallet: sorted_data_keys[tier] leer")
    top_key = top_keys[0]
    dps = data.get(tier, {}).get(top_key)
    if dps is None:
        raise ValueError("bloodmallet: top_key fehlt in data[tier]")
    parts = top_key.split("_")
    if len(parts) != 4:
        raise ValueError(f"bloodmallet: unerwartetes distribution_key-Format: {top_key!r}")
    try:
        crit, haste, mastery, vers = (int(p) for p in parts)
    except ValueError:
        raise ValueError(f"bloodmallet: distribution_key nicht numerisch: {top_key!r}")

    return {
        "tier": tier,
        "top_key": top_key,
        "pct": {"crit": crit, "haste": haste, "mastery": mastery, "vers": vers},
        "secondary_sum": int(secondary_sum),
        "dps": int(dps),
        "timestamp": _timestamp(payload),
        "simc_hash": (payload.get("simc_settings") or {}).get("simc_hash"),
    }


def _timestamp(payload):
    """Auf ein ISO-Datum (YYYY-MM-DD) gekuerzter Zeitstempel. metadata.timestamp
    (z.B. "2026-09-02 02:42:00.976615") ist die primaere Quelle -- die erste 10 Zeichen
    sind bereits das Datum. Fallback: Top-Level 'timestamp' (z.B. "UTC 2026-09-02 02:42"
    oder ohne 'UTC '-Praefix), Praefix entfernt und ebenfalls auf 10 Zeichen gekuerzt."""
    meta_ts = (payload.get("metadata") or {}).get("timestamp")
    if meta_ts:
        return str(meta_ts)[:10]
    top_ts = payload.get("timestamp") or ""
    if top_ts.startswith("UTC "):
        top_ts = top_ts[4:]
    return top_ts[:10] or None


def stats_from_distribution(parsed):
    """parsed (aus parse_distribution) -> [{"key","rating"}], absteigend nach Rating,
    alle vier STAT_KEYS. rating = int(secondary_sum * pct / 100) (Plan: Rating-Ziel)."""
    pct = parsed["pct"]
    total = parsed["secondary_sum"]
    stats = [{"key": key, "rating": int(total * pct[key] / 100)} for key in STAT_KEYS]
    stats.sort(key=lambda s: s["rating"], reverse=True)
    return stats


def gear_from_profile(payload):
    """profile.items -> (gear, gems, enchants) im AggregatedSpec-Format. Da bloodmallet
    genau EIN Profil pro Spec liefert (kein Sample), ist das 1:1 die Ausgabe -- kein
    Median/most_common wie bei aggregate.py noetig. itemLevel bleibt 0: bloodmallet gibt
    kein rohes Ilvl, nur bonus_id-kodierte Upgrade-/Sockel-Stufen (wie bei WCL-Gear auch
    schon ueblich, dort zumindest itemLevel vorhanden -- hier fehlt es in der Quelle)."""
    items = ((payload.get("profile") or {}).get("items")) or {}
    ench_item_map = season.ENCHANT_ITEM_BY_ID

    gear, gems, enchants = [], [], []
    for simc_slot, entry in items.items():
        slot = SLOT_MAP.get(simc_slot)
        if not slot or not entry:
            continue
        item_id = int(entry.get("id") or 0)
        if not item_id:
            continue
        gear.append({
            "slot": slot, "itemID": item_id, "itemLevel": 0,
            "bonusIDs": _split_ids(entry.get("bonus_id")),
            "name": f"item:{item_id}",
        })
        for gem_id in _split_ids(entry.get("gem_id")):
            gems.append({"slot": slot, "itemID": gem_id, "name": f"item:{gem_id}"})
        ench_id = int(entry.get("enchant_id") or 0)
        if ench_id:
            enchants.append({
                "slot": slot, "id": ench_id,
                "itemID": int(ench_item_map.get(ench_id, 0)),
                "name": f"enchant:{ench_id}",
            })
    gear.sort(key=lambda g: g["slot"])
    gems.sort(key=lambda g: g["slot"])
    enchants.sort(key=lambda e: e["slot"])
    return gear, gems, enchants


def fetch(class_name, spec_name, fight_style, client=None):
    """GET den Chart; client optional injizierbar (Tests: httpx.Client(transport=MockTransport)).
    HTTP-Fehler (5xx/Timeout) sollen weiter hochgereicht werden -- nur der bloodmallet-eigene
    Fehlerfall laeuft ueber is_error()/parse_distribution(), nicht ueber den Statuscode."""
    url = endpoint(class_name, spec_name, fight_style)
    headers = {"User-Agent": "MetaMirror/0.9"}
    owns_client = client is None
    c = client or httpx.Client()
    try:
        r = c.get(url, headers=headers, timeout=30.0)
        r.raise_for_status()
        return r.json()
    finally:
        if owns_client:
            c.close()
