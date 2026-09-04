"""SimulationCraft-Profile (simulationcraft/simc, Branch midnight) -> Verbrauchsgueter.

Ergaenzt bloodmallet_sd.py: bloodmallet liefert Stats + Gear, aber KEINE Verbrauchsgueter
(Flask/Trank/Rune/Oel stehen nicht im secondary_distributions-Chart). Die offiziellen SimC-
Profildateien (GPLv3, oeffentlich) tun das. Wir nutzen hier NUR die Consumables/Metadaten
dieser Dateien -- Gear/Stats kommen aus bloodmallet_sd.py, um Ueberschneidungen und zwei
leicht unterschiedliche Gear-Repraesentationen zu vermeiden.

Format (live gegen MID2_Mage_Frost/_Warrior_Arms/_Death_Knight_Unholy/_Hunter_Beast_Mastery
verifiziert, siehe docs/research/2026-09-04-data-formats.md Abschnitt B):
  Kopfzeile <simc_class>="<Anzeigename>", danach zeilenweise key=value[,key=value...].
  Gear-Zeilen: <slot>=<item_slug>,id=..,bonus_id=a/b/c,gem_id=a/b,enchant_id=..[,ilevel=..].
  Verbrauchsgueter: potion=, flask=, food=, augmentation=, temporary_enchant=<slot>:<slug>.
  Kommentarblock am Ende: NUR '# gear_ilvl=' und '# set_bonus=<name>_<n>pc=1' sind fuer uns
  relevant, alle anderen '#'-Zeilen (APL-Erklaerungen, gear_<stat>=, ...) werden ignoriert.
"""
import re

import httpx

from pipeline.specs import SPECS
from pipeline import season

RAW_BASE = "https://raw.githubusercontent.com/simulationcraft/simc/midnight/profiles"

# simc-Gear-Slotnamen (16 Stueck; off_hand fehlt in der Datei bei Zweihand-Specs).
GEAR_SLOTS = {
    "head", "neck", "shoulders", "back", "chest", "wrists", "hands", "waist",
    "legs", "feet", "finger1", "finger2", "trinket1", "trinket2",
    "main_hand", "off_hand",
}

_CONSUMABLE_FIELDS = ("potion", "flask", "food", "augmentation")


def _words(name):
    """CamelCase -> 'Death_Knight' (Unterstrich vor jedem Grossbuchstaben ausser dem
    ersten, Teile bleiben GROSS -- gleiche Regel wie trinkets.slug(), nur ohne .lower()).
    Live gegen die GitHub-Dateiliste (api.github.com/.../contents/profiles/MID2?ref=midnight,
    2026-09-04) verifiziert: 'Death_Knight', 'Demon_Hunter', 'Beast_Mastery' treffen exakt
    die realen Dateinamen (MID2_Death_Knight_Unholy.simc, MID2_Demon_Hunter_Havoc.simc,
    MID2_Hunter_Beast_Mastery.simc, ...). Basis-Dateien ohne Hero-Talent-Suffix existieren
    fuer jede in pipeline/specs.py gelistete Spec ausser Druid/Evoker (in MID2 noch nicht
    aktualisiert) und den Heiler-Specs (Holy Paladin/Priest, Disc, Mistweaver -- fehlen
    komplett in MID2; das betrifft aber Task 2, nicht diesen Parser)."""
    return re.sub(r"(?<!^)(?=[A-Z])", "_", name)


# class_name (wie in pipeline/specs.py, z.B. "DeathKnight") -> Verzeichnis-/Dateiname-Teil.
SIMC_CLASS_DIR = {s.class_name: _words(s.class_name) for s in SPECS}


def profile_url(class_name, spec_name, tier="MID2"):
    cls = SIMC_CLASS_DIR.get(class_name, _words(class_name))
    spec = _words(spec_name)
    return f"{RAW_BASE}/{tier}/{tier}_{cls}_{spec}.simc"


def _parse_gear_line(value):
    """'<item_slug>,id=..,bonus_id=a/b,gem_id=a/b,enchant_id=..[,ilevel=..][,...]' ->
    {"id","bonus_id"[int],"gem_id"[int],"enchant_id","ilevel"}. Unbekannte Zusatz-Keys
    (crafted_stats, redirected_base_stats, content_tuning, ...) werden ignoriert -- fuer
    den Addon-Datenvertrag (nur Consumables aus diesem Modul) nicht gebraucht."""
    parts = value.split(",")
    out = {"id": 0, "bonus_id": [], "gem_id": [], "enchant_id": 0, "ilevel": 0}
    for part in parts[1:]:          # parts[0] ist der Item-Slug, kein key=value-Paar
        if "=" not in part:
            continue
        k, v = part.split("=", 1)
        k, v = k.strip(), v.strip()
        if k == "id" and v.isdigit():
            out["id"] = int(v)
        elif k == "bonus_id":
            out["bonus_id"] = [int(x) for x in v.split("/") if x.isdigit()]
        elif k == "gem_id":
            # 0 = leerer Socket (kommt bei bloodmallet-Profilen so vor, hier zur Sicherheit
            # ebenso gefiltert); echte Doppel-Gemme (z.B. Hals) bleibt als 2 Eintraege erhalten.
            out["gem_id"] = [int(x) for x in v.split("/") if x.isdigit() and int(x) != 0]
        elif k == "enchant_id" and v.isdigit():
            out["enchant_id"] = int(v)
        elif k == "ilevel" and v.isdigit():
            out["ilevel"] = int(v)
    return out


def parse_profile(text):
    """SimC-Profiltext -> dict: actor, spec, talents, omnium_talents, consumables{flask,
    potion,food,augmentation,temporary_enchant{slot:slug}}, gear{simc_slot:{...}},
    gear_ilvl, set_bonus[list]. Kommentarzeilen ausser '# gear_ilvl=' / '# set_bonus='
    ignoriert; ebenso alle sonstigen Metadaten-Zeilen (level=, race=, role=, position=,
    APL-Zeilen actions*=...) -- fuer den Addon-Datenvertrag nicht gebraucht."""
    parsed = {
        "actor": None, "spec": None, "talents": None, "omnium_talents": None,
        "consumables": {"temporary_enchant": {}},
        "gear": {}, "gear_ilvl": None, "set_bonus": [],
    }
    for raw_line in text.splitlines():
        line = raw_line.strip()
        if not line:
            continue
        if line.startswith("#"):
            body = line[1:].strip()
            if body.startswith("gear_ilvl="):
                try:
                    parsed["gear_ilvl"] = float(body.split("=", 1)[1])
                except ValueError:
                    pass
            elif body.startswith("set_bonus="):
                parsed["set_bonus"].append(body.split("=", 1)[1])
            continue                # alle anderen Kommentarzeilen ignorieren
        if "=" not in line:
            continue
        key, value = line.split("=", 1)
        key, value = key.strip(), value.strip()
        if key in GEAR_SLOTS:
            parsed["gear"][key] = _parse_gear_line(value)
        elif key == "temporary_enchant":
            if ":" in value:
                slot, slug = value.split(":", 1)
                parsed["consumables"]["temporary_enchant"][slot.strip()] = slug.strip()
        elif key in _CONSUMABLE_FIELDS:
            parsed["consumables"][key] = value
        elif key == "spec":
            parsed["spec"] = value
        elif key == "talents":
            parsed["talents"] = value
        elif key == "omnium_talents":
            # Midnight-Zusatz-Layer; Format klassenabhaengig numerisch ("spell_id:rang",
            # '/'-getrennt) oder textuell (Runen-Name, ohne Rang). Nur roh durchgereicht --
            # kein Downstream-Verbrauch in dieser Pipeline (weder Stats noch Gear).
            parsed["omnium_talents"] = value
        elif parsed["actor"] is None and value.startswith('"') and value.endswith('"'):
            # Kopfzeile '<simc_class>="<Anzeigename>"' -- einzige Zeile mit Anfuehrungszeichen.
            parsed["actor"] = value[1:-1]
        # alles andere (level=, race=, role=, position=, source=, actions*=...) irrelevant.
    return parsed


_RANK_SUFFIX_RE = re.compile(r"_\d+$")


def _strip_rank(slug):
    """'flask_of_the_shattered_sun_2' -> 'flask_of_the_shattered_sun' (Rang-/Qualitaets-
    suffix der Midnight-Consumables). Slugs ohne Suffix bleiben unveraendert."""
    return _RANK_SUFFIX_RE.sub("", slug)


def consumable_item_ids(parsed_consumables):
    """SimC-Verbrauchsguet-Slugs -> {"flask": itemID, "rune": itemID, "oil": itemID, ...}
    ueber season.SIMC_CONSUMABLE_ITEMS. Die Kategorie kommt aus der Tabelle, NICHT aus dem
    SimC-Feldnamen: 'augmentation' liefert z.B. Kategorie 'rune', 'temporary_enchant'
    liefert 'oil' -- der Feldname ist nur die Fundstelle im Profil. Rang-Suffix wird vor
    dem Lookup abgeschnitten. Rueckgabe (ids, unknown_slugs): unknown_slugs fuers Log --
    typischerweise potion/food, die ohnehin von apply_curated_consumables ueberschrieben
    werden (season.py: nicht aus dem Pull-Snapshot ableitbar)."""
    table = season.SIMC_CONSUMABLE_ITEMS
    slugs = [parsed_consumables[f] for f in _CONSUMABLE_FIELDS if parsed_consumables.get(f)]
    slugs.extend((parsed_consumables.get("temporary_enchant") or {}).values())

    ids, unknown = {}, []
    for slug in slugs:
        entry = table.get(_strip_rank(slug))
        if entry:
            cat, item_id = entry
            ids[cat] = item_id
        else:
            unknown.append(slug)
    return ids, unknown


def fetch(class_name, spec_name, tier="MID2", client=None):
    """Profiltext von GitHub Raw holen; 404 -> None (Aufrufer versucht dann MID1). Andere
    HTTP-Fehler werden hochgereicht (raise_for_status)."""
    url = profile_url(class_name, spec_name, tier)
    owns_client = client is None
    c = client or httpx.Client()
    try:
        r = c.get(url, headers={"User-Agent": "MetaMirror/0.9"}, timeout=30.0)
        if r.status_code == 404:
            return None
        r.raise_for_status()
        return r.text
    finally:
        if owns_client:
            c.close()
