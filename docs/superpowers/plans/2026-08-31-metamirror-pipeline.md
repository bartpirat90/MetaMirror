# MetaMirror-Datenpipeline (Teilsystem 2) — Implementierungsplan

> **Für agentische Worker:** ERFORDERLICHES SUB-SKILL: superpowers:subagent-driven-development (empfohlen) oder superpowers:executing-plans, um diesen Plan Task für Task umzusetzen. Schritte nutzen Checkbox-Syntax (`- [ ]`).

**Goal:** Eine Python-Pipeline berechnet aus der offiziellen Warcraft-Logs-v2-API die aktuelle Top-Spieler-Meta pro Spec und schreibt sie als Lua-Tabelle (`Data/MetaMirrorData.lua`) ins Addon; Verbrauchsgüter werden im Addon zu klickbaren Item-Links.

**Architecture:** Klare Grenze `ParseRecord` zwischen API-Abruf (`wcl.py`/`fetch.py`, live-abhängig) und Aggregation (`aggregate.py`/`emit_lua.py`/`validate.py`, reine Logik, voll unit-testbar). Season-abhängige Daten (Rating→Prozent, IDs, Consumable-Whitelist) getrennt in `season.py`. GitHub-Actions-Cron ruft `run.py`; bei grüner Validierung Auto-Commit nach master + (gated) CurseForge-Upload.

**Tech Stack:** Python 3.12, `httpx`, `pytest`. Addon: Lua 5.1, Interface 120100.

**Reihenfolge-Hinweis:** Tasks 1–8 (Pipeline) sind Code + Unit-Tests ohne Live-API; der End-to-End-Lauf braucht die vom Nutzer angelegten WCL-Credentials + GitHub-Repo. **Task 9 (Addon) ist unabhängig und sofort im Spiel testbar** — kann bei Bedarf zuerst gemacht werden.

---

## Dateistruktur

```
pipeline/
  __init__.py
  models.py        # ParseRecord + AggregatedSpec (Dataclasses, der Abruf/Aggregat-Vertrag)
  season.py        # gepflegte Season-Daten: Rating→Prozent, Encounter/Zone-IDs, Consumable-Whitelist
  specs.py         # SPECS: 40 Spec-Definitionen (classID/specID/WCL-Namen); STAT_KEYS, CONTENTS
  wcl.py           # OAuth-Token + GraphQL-Executor (Retry/Backoff)
  fetch.py         # WCL-JSON -> list[ParseRecord]
  aggregate.py     # list[ParseRecord] -> AggregatedSpec (Median/Häufigkeiten)
  emit_lua.py      # {classID:{specID:{content:AggregatedSpec}}} -> Lua-String
  validate.py      # Wächter über die generierte Datenstruktur
  run.py           # Orchestrator + CLI (--specs, --content, --dry-run, --out)
  requirements.txt
  tests/
    __init__.py
    fixtures.py
    test_aggregate.py
    test_emit_lua.py
    test_validate.py
    test_fetch.py
    test_wcl.py
    test_specs.py
.github/workflows/update-data.yml
Data/MetaMirrorData.lua      # umbenannt aus SampleData.lua; von der Pipeline überschrieben
MetaMirror.toc               # Data\SampleData.lua -> Data\MetaMirrorData.lua
UI.lua                       # Verbrauchsgüter als klickbare Links
```

---

## Task 1: Pipeline-Gerüst, Spec-Registry, Modelle

**Files:**
- Create: `pipeline/__init__.py` (leer)
- Create: `pipeline/tests/__init__.py` (leer)
- Create: `pipeline/requirements.txt`
- Create: `pipeline/models.py`
- Create: `pipeline/specs.py`
- Create: `pipeline/season.py`
- Test: `pipeline/tests/test_specs.py`

- [ ] **Step 1: requirements.txt**

Create `pipeline/requirements.txt`:
```
httpx==0.27.2
pytest==8.3.3
```

- [ ] **Step 2: models.py**

Create `pipeline/models.py`:
```python
from dataclasses import dataclass, field
from typing import Optional


@dataclass
class ParseRecord:
    """Eine ausgewertete Top-Parse eines Spielers. Grenze zwischen fetch.py und aggregate.py."""
    class_id: int
    spec_id: int
    content: str                    # "mythicplus" | "raid"
    stats: dict                     # {"haste": rating_int, "crit": .., "mastery": .., "vers": ..}
    talent_import: str              # Blizzard-Export-String, falls vorhanden, sonst ""
    talent_sig: str                 # stabile Signatur der Talentauswahl (Gruppierungsschlüssel)
    gear: list                      # [{"slot": "HEAD", "item_id": int, "enchant_id": int, "gems": [int]}, ..]
    consumables: dict               # {"flask": itemID|None, "phial": .., "potion": .., "food": .., "oil": .., "rune": ..}


@dataclass
class AggregatedSpec:
    """Aggregiertes Ergebnis pro Spec × Content — entspricht 1:1 dem Lua-Datenvertrag."""
    sample_size: int
    stats: list                     # [{"key": "haste", "pct": float}, ..] absteigend nach pct
    talents: list                   # [{"importString": str, "usagePct": int}]
    gear: list                      # [{"slot": str, "itemID": int, "name": str}]
    gems: list                      # [{"slot": str, "itemID": int, "name": str}]
    enchants: list                  # [{"slot": str, "id": int, "name": str}]
    consumables: dict               # {"flask": itemID, ...} (nur belegte Keys)
```

- [ ] **Step 3: specs.py**

Create `pipeline/specs.py`:
```python
from dataclasses import dataclass

STAT_KEYS = ["haste", "crit", "mastery", "vers"]
CONTENTS = ["mythicplus", "raid"]


@dataclass(frozen=True)
class Spec:
    class_id: int
    spec_id: int
    class_name: str   # WCL className (Verwendung als GraphQL-Argument; Schreibweise live prüfen)
    spec_name: str    # WCL specName


SPECS = [
    Spec(1, 71, "Warrior", "Arms"), Spec(1, 72, "Warrior", "Fury"), Spec(1, 73, "Warrior", "Protection"),
    Spec(2, 65, "Paladin", "Holy"), Spec(2, 66, "Paladin", "Protection"), Spec(2, 70, "Paladin", "Retribution"),
    Spec(3, 253, "Hunter", "BeastMastery"), Spec(3, 254, "Hunter", "Marksmanship"), Spec(3, 255, "Hunter", "Survival"),
    Spec(4, 259, "Rogue", "Assassination"), Spec(4, 260, "Rogue", "Outlaw"), Spec(4, 261, "Rogue", "Subtlety"),
    Spec(5, 256, "Priest", "Discipline"), Spec(5, 257, "Priest", "Holy"), Spec(5, 258, "Priest", "Shadow"),
    Spec(6, 250, "DeathKnight", "Blood"), Spec(6, 251, "DeathKnight", "Frost"), Spec(6, 252, "DeathKnight", "Unholy"),
    Spec(7, 262, "Shaman", "Elemental"), Spec(7, 263, "Shaman", "Enhancement"), Spec(7, 264, "Shaman", "Restoration"),
    Spec(8, 62, "Mage", "Arcane"), Spec(8, 63, "Mage", "Fire"), Spec(8, 64, "Mage", "Frost"),
    Spec(9, 265, "Warlock", "Affliction"), Spec(9, 266, "Warlock", "Demonology"), Spec(9, 267, "Warlock", "Destruction"),
    Spec(10, 268, "Monk", "Brewmaster"), Spec(10, 269, "Monk", "Windwalker"), Spec(10, 270, "Monk", "Mistweaver"),
    Spec(11, 102, "Druid", "Balance"), Spec(11, 103, "Druid", "Feral"), Spec(11, 104, "Druid", "Guardian"), Spec(11, 105, "Druid", "Restoration"),
    Spec(12, 577, "DemonHunter", "Havoc"), Spec(12, 581, "DemonHunter", "Vengeance"),
    Spec(13, 1467, "Evoker", "Devastation"), Spec(13, 1468, "Evoker", "Preservation"), Spec(13, 1473, "Evoker", "Augmentation"),
]
```

- [ ] **Step 4: season.py**

Create `pipeline/season.py`. Diese Datei ist **gepflegte Season-Daten** (der Punkt, den der Nutzer „ein paar Mal im Monat" prüft), kein fixer Code. Werte zu Season-Beginn verifizieren.
```python
# Season-abhängige, von Hand gepflegte Daten. Zu jedem Patch/Season prüfen.
SEASON_NAME = "TWW-S-TBD"      # sichtbar in der Datentabelle; zu Season-Start setzen

# Rating pro 1 % auf Maximalstufe. Crit/Haste/Vers teilen sich den Wert.
# Mastery: rating_per_pct["mastery"] = Rating pro 1 Mastery-Punkt; die %-Wirkung
# skaliert zusätzlich mit dem spec-spezifischen Faktor MASTERY_COEFF.
RATING_PER_PCT = {"haste": 700.0, "crit": 700.0, "vers": 780.0, "mastery": 700.0}

# Mastery-%-Faktor je specID (1 Mastery-Punkt => COEFF % Effekt). Zu Season-Start prüfen.
MASTERY_COEFF = {}   # z.B. {71: 1.6, 64: 1.0}; fehlt ein Spec -> Fallback 1.0

# WCL-Konfiguration je Content. Zu Season-Start setzen.
RAID_ENCOUNTER_IDS = []          # Liste der Mythic-Raid-Encounter-IDs der aktuellen Season
RAID_DIFFICULTY = 5              # 5 = Mythic in WCL
MPLUS_ZONE_ID = None             # WCL-Zone-ID für M+ der Season
MPLUS_MIN_KEYSTONE = None        # optionaler Mindest-Keystone-Level-Filter

# Consumable-Aura (Spell-ID) -> Item-ID. Nur diese Auren zählen als Verbrauchsgut.
CONSUMABLE_SPELL_TO_ITEM = {}    # {spellID: {"cat": "flask"|"phial"|"potion"|"food"|"oil"|"rune", "item": itemID}}

SAMPLE_TARGET = 50               # angestrebte Parses pro Spec × Content
```

- [ ] **Step 5: Write the failing test**

Create `pipeline/tests/test_specs.py`:
```python
from pipeline.specs import SPECS, STAT_KEYS, CONTENTS


def test_all_40_specs_unique():
    keys = {(s.class_id, s.spec_id) for s in SPECS}
    assert len(keys) == 40
    assert len(SPECS) == 40


def test_class_ids_in_range():
    assert all(1 <= s.class_id <= 13 for s in SPECS)


def test_stat_and_content_constants():
    assert STAT_KEYS == ["haste", "crit", "mastery", "vers"]
    assert CONTENTS == ["mythicplus", "raid"]
```

- [ ] **Step 6: Run tests**

Run from repo root: `python -m pytest pipeline/tests/test_specs.py -v`
Expected: 3 PASS

- [ ] **Step 7: Commit**
```bash
git add pipeline/ && git commit -m "feat(pipeline): scaffold, spec registry, data models"
```

---

## Task 2: WCL-Client (OAuth + GraphQL)

**Files:**
- Create: `pipeline/wcl.py`
- Test: `pipeline/tests/test_wcl.py`

- [ ] **Step 1: Write the failing test**

Create `pipeline/tests/test_wcl.py`:
```python
import httpx
from pipeline.wcl import WclClient

TOKEN_URL = "https://www.warcraftlogs.com/oauth/token"
API_URL = "https://www.warcraftlogs.com/api/v2/client"


def _transport():
    def handler(request: httpx.Request) -> httpx.Response:
        if request.url.path == "/oauth/token":
            return httpx.Response(200, json={"access_token": "TESTTOKEN", "expires_in": 3600})
        if request.url.path == "/api/v2/client":
            assert request.headers["authorization"] == "Bearer TESTTOKEN"
            return httpx.Response(200, json={"data": {"ok": True}})
        return httpx.Response(404)
    return httpx.MockTransport(handler)


def test_token_and_query():
    c = WclClient("id", "secret", transport=_transport())
    out = c.query("{ ok }", {})
    assert out == {"ok": True}


def test_graphql_errors_raise():
    def handler(request):
        if request.url.path == "/oauth/token":
            return httpx.Response(200, json={"access_token": "T", "expires_in": 3600})
        return httpx.Response(200, json={"errors": [{"message": "bad"}]})
    c = WclClient("id", "secret", transport=httpx.MockTransport(handler))
    try:
        c.query("{ x }", {})
        assert False, "should raise"
    except RuntimeError as e:
        assert "bad" in str(e)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest pipeline/tests/test_wcl.py -v`
Expected: FAIL (no module `pipeline.wcl`)

- [ ] **Step 3: Write wcl.py**

Create `pipeline/wcl.py`:
```python
import time
import httpx

TOKEN_URL = "https://www.warcraftlogs.com/oauth/token"
API_URL = "https://www.warcraftlogs.com/api/v2/client"


class WclClient:
    def __init__(self, client_id, client_secret, transport=None, max_retries=5):
        self._id = client_id
        self._secret = client_secret
        self._max_retries = max_retries
        self._client = httpx.Client(timeout=60.0, transport=transport)
        self._token = None
        self._token_exp = 0.0

    def _ensure_token(self):
        if self._token and time.monotonic() < self._token_exp - 60:
            return
        r = self._client.post(
            TOKEN_URL, data={"grant_type": "client_credentials"},
            auth=(self._id, self._secret),
        )
        r.raise_for_status()
        body = r.json()
        self._token = body["access_token"]
        self._token_exp = time.monotonic() + float(body.get("expires_in", 3600))

    def query(self, gql, variables, _sleep=time.sleep):
        """Führt eine GraphQL-Query aus; wirft RuntimeError bei GraphQL-'errors'."""
        for attempt in range(self._max_retries):
            self._ensure_token()
            r = self._client.post(
                API_URL, headers={"Authorization": f"Bearer {self._token}"},
                json={"query": gql, "variables": variables},
            )
            if r.status_code == 429:
                _sleep(2 ** attempt)
                continue
            r.raise_for_status()
            body = r.json()
            if body.get("errors"):
                raise RuntimeError("; ".join(e.get("message", "?") for e in body["errors"]))
            return body["data"]
        raise RuntimeError("WCL rate limit: retries exhausted")
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest pipeline/tests/test_wcl.py -v`
Expected: 2 PASS

- [ ] **Step 5: Commit**
```bash
git add pipeline/wcl.py pipeline/tests/test_wcl.py && git commit -m "feat(pipeline): WCL OAuth + GraphQL client with backoff"
```

---

## Task 3: Abruf (WCL-JSON → ParseRecord)

**Files:**
- Create: `pipeline/fetch.py`
- Create: `pipeline/tests/fixtures.py`
- Test: `pipeline/tests/test_fetch.py`

**Wichtig (Live-Verifikation):** Die genaue JSON-Struktur der `CombatantInfo`-`data` und der Rankings-Antwort muss beim ersten Lauf mit echten Credentials gegen eine reale Antwort abgeglichen werden. `fetch.py` kapselt **alle** Struktur-Annahmen in den Funktionen `parse_combatant_info` und `parse_rankings`; nur diese sind bei Abweichung anzupassen. Ein Blizzard-Talent-Export-String liegt in WCL i. d. R. **nicht** vor → `talent_import` bleibt dann `""`, und die Gruppierung nutzt `talent_sig` (Node-Signatur). Ein echter Copy-Paste-String ist eine spätere Ausbaustufe (nicht in diesem Plan).

- [ ] **Step 1: fixtures.py**

Create `pipeline/tests/fixtures.py`:
```python
# Minimaler CombatantInfo-'data'-Block, wie fetch.parse_combatant_info ihn erwartet.
COMBATANT_INFO = {
    "specID": 71,
    "stats": {"Haste": {"rating": 7000}, "Crit": {"rating": 5600},
              "Mastery": {"rating": 4200}, "Versatility": {"rating": 3120}},
    "talentTree": [{"id": 111, "rank": 1}, {"id": 222, "rank": 2}],
    "gear": [
        {"slot": 0, "id": 21001, "permanentEnchant": 0, "gems": []},
        {"slot": 15, "id": 21050, "permanentEnchant": 7001, "gems": [90001]},
    ],
    "auras": [{"ability": 431971}, {"ability": 999999}],  # 1. = Flask (Whitelist), 2. = irrelevant
}

SLOT_NAME = {0: "HEAD", 15: "MAINHAND"}
```

- [ ] **Step 2: Write the failing test**

Create `pipeline/tests/test_fetch.py`:
```python
from pipeline.fetch import parse_combatant_info
from pipeline.tests.fixtures import COMBATANT_INFO


def test_parse_combatant_info_maps_stats_gear_consumables():
    season = {
        "CONSUMABLE_SPELL_TO_ITEM": {431971: {"cat": "flask", "item": 212283}},
        "SLOT_NAME": {0: "HEAD", 15: "MAINHAND"},
    }
    rec = parse_combatant_info(COMBATANT_INFO, class_id=1, spec_id=71,
                               content="mythicplus", season=season)
    assert rec.stats == {"haste": 7000, "crit": 5600, "mastery": 4200, "vers": 3120}
    assert {"slot": "HEAD", "item_id": 21001, "enchant_id": 0, "gems": []} in rec.gear
    assert rec.consumables["flask"] == 212283
    assert rec.consumables.get("food") is None
    assert rec.talent_sig == "111:1|222:2"
    assert rec.class_id == 1 and rec.spec_id == 71 and rec.content == "mythicplus"
```

- [ ] **Step 3: Run test to verify it fails**

Run: `python -m pytest pipeline/tests/test_fetch.py -v`
Expected: FAIL (no module `pipeline.fetch`)

- [ ] **Step 4: Write fetch.py**

Create `pipeline/fetch.py`:
```python
from pipeline.models import ParseRecord

_STAT_FIELD = {"haste": "Haste", "crit": "Crit", "mastery": "Mastery", "vers": "Versatility"}
_CONS_CATS = ["flask", "phial", "potion", "food", "oil", "rune"]

# WoW-inventoryType (CombatantInfo gear[].slot) -> Vertrags-Slotname.
DEFAULT_SLOT_NAME = {
    0: "HEAD", 1: "NECK", 2: "SHOULDER", 4: "CHEST", 5: "WAIST", 6: "LEGS",
    7: "FEET", 8: "WRIST", 9: "HANDS", 10: "RING1", 11: "RING2",
    12: "TRINKET1", 13: "TRINKET2", 14: "BACK", 15: "MAINHAND", 16: "OFFHAND",
}


def parse_combatant_info(data, class_id, spec_id, content, season):
    """WCL-CombatantInfo-'data' -> ParseRecord. Kapselt alle Struktur-Annahmen."""
    slot_name = season.get("SLOT_NAME", DEFAULT_SLOT_NAME)
    stats = {}
    src = data.get("stats", {})
    for key, field_name in _STAT_FIELD.items():
        entry = src.get(field_name) or {}
        stats[key] = int(entry.get("rating", 0))

    gear = []
    for g in data.get("gear", []):
        slot = slot_name.get(g.get("slot"))
        if not slot or not g.get("id"):
            continue
        gear.append({
            "slot": slot, "item_id": int(g["id"]),
            "enchant_id": int(g.get("permanentEnchant") or 0),
            "gems": [int(x) for x in (g.get("gems") or []) if x],
        })

    consumables = {c: None for c in _CONS_CATS}
    whitelist = season.get("CONSUMABLE_SPELL_TO_ITEM", {})
    for aura in data.get("auras", []):
        info = whitelist.get(aura.get("ability"))
        if info and consumables.get(info["cat"]) is None:
            consumables[info["cat"]] = info["item"]

    tree = data.get("talentTree") or []
    talent_sig = "|".join(f"{n['id']}:{n.get('rank', 1)}" for n in tree)

    return ParseRecord(
        class_id=class_id, spec_id=spec_id, content=content, stats=stats,
        talent_import=str(data.get("talentImportString", "")),
        talent_sig=talent_sig, gear=gear, consumables=consumables,
    )
```

- [ ] **Step 5: Run test to verify it passes**

Run: `python -m pytest pipeline/tests/test_fetch.py -v`
Expected: PASS

- [ ] **Step 6: Commit**
```bash
git add pipeline/fetch.py pipeline/tests/fixtures.py pipeline/tests/test_fetch.py && git commit -m "feat(pipeline): parse CombatantInfo into ParseRecord"
```

---

## Task 4: Aggregation (ParseRecords → AggregatedSpec)

**Files:**
- Create: `pipeline/aggregate.py`
- Test: `pipeline/tests/test_aggregate.py`

- [ ] **Step 1: Write the failing test**

Create `pipeline/tests/test_aggregate.py`:
```python
from pipeline.models import ParseRecord
from pipeline.aggregate import aggregate, rating_to_pct


def _rec(stats, sig="A", gear=None, cons=None):
    return ParseRecord(
        class_id=1, spec_id=71, content="raid", stats=stats,
        talent_import="", talent_sig=sig,
        gear=gear or [{"slot": "HEAD", "item_id": 100, "enchant_id": 0, "gems": []}],
        consumables=cons or {"flask": 212283, "food": None, "phial": None,
                             "potion": None, "oil": None, "rune": None},
    )


SEASON = {"RATING_PER_PCT": {"haste": 700.0, "crit": 700.0, "vers": 780.0, "mastery": 700.0},
          "MASTERY_COEFF": {71: 2.0}}


def test_rating_to_pct_secondary_and_mastery():
    assert rating_to_pct("haste", 7000, 71, SEASON) == 10.0
    # Mastery: 7000/700 = 10 Punkte * COEFF 2.0 = 20 %
    assert rating_to_pct("mastery", 7000, 71, SEASON) == 20.0


def test_aggregate_medians_and_order():
    recs = [
        _rec({"haste": 7000, "crit": 5600, "mastery": 3500, "vers": 3900}),
        _rec({"haste": 7700, "crit": 4900, "mastery": 3500, "vers": 3900}),
        _rec({"haste": 6300, "crit": 6300, "mastery": 3500, "vers": 3900}),
    ]
    agg = aggregate(recs, spec_id=71, season=SEASON,
                    item_name=lambda i: f"item{i}")
    assert agg.sample_size == 3
    # Median haste = 7000 -> 10%; crit median 5600 -> 8%; mastery 3500/700*2=10%; vers 3900/780=5%
    pct = {s["key"]: s["pct"] for s in agg.stats}
    assert pct["haste"] == 10.0 and pct["crit"] == 8.0
    assert pct["mastery"] == 10.0 and pct["vers"] == 5.0
    # absteigend sortiert
    assert [s["pct"] for s in agg.stats] == sorted((s["pct"] for s in agg.stats), reverse=True)


def test_aggregate_most_common_talent_and_gear_and_consumables():
    recs = [
        _rec({"haste": 7000, "crit": 5600, "mastery": 3500, "vers": 3900}, sig="A"),
        _rec({"haste": 7000, "crit": 5600, "mastery": 3500, "vers": 3900}, sig="A"),
        _rec({"haste": 7000, "crit": 5600, "mastery": 3500, "vers": 3900}, sig="B"),
    ]
    agg = aggregate(recs, spec_id=71, season=SEASON, item_name=lambda i: f"item{i}")
    assert agg.talents[0]["usagePct"] == 67          # 2 von 3
    assert agg.gear[0]["slot"] == "HEAD" and agg.gear[0]["itemID"] == 100
    assert agg.gear[0]["name"] == "item100"
    assert agg.consumables["flask"] == 212283
    assert "food" not in agg.consumables               # None-Kategorien entfallen
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest pipeline/tests/test_aggregate.py -v`
Expected: FAIL (no module `pipeline.aggregate`)

- [ ] **Step 3: Write aggregate.py**

Create `pipeline/aggregate.py`:
```python
from collections import Counter
from statistics import median
from pipeline.models import AggregatedSpec
from pipeline.specs import STAT_KEYS

_CONS_CATS = ["flask", "phial", "potion", "food", "oil", "rune"]


def rating_to_pct(stat, rating, spec_id, season):
    per_pct = season["RATING_PER_PCT"][stat]
    pct = rating / per_pct
    if stat == "mastery":
        pct *= season.get("MASTERY_COEFF", {}).get(spec_id, 1.0)
    return round(pct, 1)


def _most_common(values):
    values = [v for v in values if v]
    if not values:
        return None, 0
    item, count = Counter(values).most_common(1)[0]
    return item, count


def aggregate(records, spec_id, season, item_name):
    """records: list[ParseRecord] eines Spec × Content. item_name: itemID -> Name."""
    n = len(records)

    stats = []
    for key in STAT_KEYS:
        med = median([r.stats.get(key, 0) for r in records])
        stats.append({"key": key, "pct": rating_to_pct(key, med, spec_id, season)})
    stats.sort(key=lambda s: s["pct"], reverse=True)

    sig, cnt = _most_common([r.talent_sig for r in records])
    imports = [r.talent_import for r in records if r.talent_sig == sig and r.talent_import]
    talents = [{"importString": imports[0] if imports else "",
                "usagePct": round(100 * cnt / n) if n else 0}]

    slot_items = {}
    slot_enchant = {}
    slot_gems = {}
    for r in records:
        for g in r.gear:
            slot_items.setdefault(g["slot"], []).append(g["item_id"])
            if g.get("enchant_id"):
                slot_enchant.setdefault(g["slot"], []).append(g["enchant_id"])
            for gem in g.get("gems", []):
                slot_gems.setdefault(g["slot"], []).append(gem)

    gear = []
    for slot, items in slot_items.items():
        item_id, _ = _most_common(items)
        if item_id:
            gear.append({"slot": slot, "itemID": item_id, "name": item_name(item_id)})
    gear.sort(key=lambda g: g["slot"])

    gems = []
    for slot, ids in slot_gems.items():
        gem_id, _ = _most_common(ids)
        if gem_id:
            gems.append({"slot": slot, "itemID": gem_id, "name": item_name(gem_id)})
    gems.sort(key=lambda g: g["slot"])

    enchants = []
    for slot, ids in slot_enchant.items():
        ench_id, _ = _most_common(ids)
        if ench_id:
            enchants.append({"slot": slot, "id": ench_id, "name": f"enchant:{ench_id}"})
    enchants.sort(key=lambda e: e["slot"])

    consumables = {}
    for cat in _CONS_CATS:
        item_id, _ = _most_common([r.consumables.get(cat) for r in records])
        if item_id:
            consumables[cat] = item_id

    return AggregatedSpec(sample_size=n, stats=stats, talents=talents,
                          gear=gear, gems=gems, enchants=enchants, consumables=consumables)
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest pipeline/tests/test_aggregate.py -v`
Expected: 3 PASS

- [ ] **Step 5: Commit**
```bash
git add pipeline/aggregate.py pipeline/tests/test_aggregate.py && git commit -m "feat(pipeline): aggregate ParseRecords into meta (median + most-common)"
```

---

## Task 5: Lua-Serializer

**Files:**
- Create: `pipeline/emit_lua.py`
- Test: `pipeline/tests/test_emit_lua.py`

- [ ] **Step 1: Write the failing test**

Create `pipeline/tests/test_emit_lua.py`:
```python
from pipeline.models import AggregatedSpec
from pipeline.emit_lua import emit_lua


def _agg():
    return AggregatedSpec(
        sample_size=42,
        stats=[{"key": "haste", "pct": 34.0}, {"key": "crit", "pct": 28.0}],
        talents=[{"importString": "ABC=", "usagePct": 68}],
        gear=[{"slot": "HEAD", "itemID": 21001, "name": "Helm"}],
        gems=[{"slot": "RING1", "itemID": 90001, "name": "+Haste"}],
        enchants=[{"slot": "MAINHAND", "id": 7001, "name": "enchant:7001"}],
        consumables={"flask": 212283, "food": 222},
    )


def test_emit_structure_and_values():
    data = {1: {71: {"mythicplus": _agg(), "raid": _agg()}}}
    out = emit_lua(data, version="wcl-2026-08-31", season="TWW-S1")
    assert out.startswith("MetaMirror")
    assert 'version = "wcl-2026-08-31"' in out
    assert 'attribution = "Data from Warcraft Logs"' in out
    assert "[1] = {" in out and "[71] = {" in out
    assert "mythicplus = {" in out and "raid = {" in out
    assert 'sampleSize = 42' in out
    assert '{ key = "haste", pct = 34.0 }' in out
    assert 'importString = "ABC="' in out
    assert 'itemID = 21001' in out
    assert 'flask = 212283' in out
    # balancierte Klammern
    assert out.count("{") == out.count("}")


def test_emit_is_deterministic():
    data = {1: {71: {"raid": _agg()}}}
    a = emit_lua(data, version="v", season="s")
    b = emit_lua(data, version="v", season="s")
    assert a == b
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest pipeline/tests/test_emit_lua.py -v`
Expected: FAIL (no module `pipeline.emit_lua`)

- [ ] **Step 3: Write emit_lua.py**

Create `pipeline/emit_lua.py`:
```python
from pipeline.specs import CONTENTS


def _q(s):
    return '"' + str(s).replace("\\", "\\\\").replace('"', '\\"') + '"'


def _pct(v):
    return f"{float(v):.1f}"


def _spec_block(agg, indent):
    p = " " * indent
    p2 = " " * (indent + 4)
    lines = [f"{p}sampleSize = {agg.sample_size},"]

    lines.append(f"{p}stats = {{")
    for s in agg.stats:
        lines.append(f'{p2}{{ key = {_q(s["key"])}, pct = {_pct(s["pct"])} }},')
    lines.append(f"{p}}},")

    lines.append(f"{p}talents = {{")
    for t in agg.talents:
        lines.append(f'{p2}{{ importString = {_q(t["importString"])}, usagePct = {int(t["usagePct"])} }},')
    lines.append(f"{p}}},")

    lines.append(f"{p}gear = {{")
    for g in agg.gear:
        lines.append(f'{p2}{{ slot = {_q(g["slot"])}, itemID = {int(g["itemID"])}, name = {_q(g["name"])} }},')
    lines.append(f"{p}}},")

    lines.append(f"{p}gems = {{")
    for g in agg.gems:
        lines.append(f'{p2}{{ slot = {_q(g["slot"])}, itemID = {int(g["itemID"])}, name = {_q(g["name"])} }},')
    lines.append(f"{p}}},")

    lines.append(f"{p}enchants = {{")
    for e in agg.enchants:
        lines.append(f'{p2}{{ slot = {_q(e["slot"])}, id = {int(e["id"])}, name = {_q(e["name"])} }},')
    lines.append(f"{p}}},")

    cons = ", ".join(f"{k} = {int(v)}" for k, v in sorted(agg.consumables.items()))
    lines.append(f"{p}consumables = {{ {cons} }},")
    return "\n".join(lines)


def emit_lua(data, version, season):
    """data: {classID: {specID: {content: AggregatedSpec}}} -> Lua-Quelltext."""
    out = ["-- Generiert von der MetaMirror-Pipeline. NICHT von Hand bearbeiten.",
           "MetaMirrorData = {",
           f"    version = {_q(version)},",
           f"    season = {_q(season)},",
           '    attribution = "Data from Warcraft Logs",',
           "    specs = {"]
    for class_id in sorted(data):
        out.append(f"        [{class_id}] = {{")
        for spec_id in sorted(data[class_id]):
            out.append(f"            [{spec_id}] = {{")
            for content in CONTENTS:
                agg = data[class_id][spec_id].get(content)
                if not agg:
                    continue
                out.append(f"                {content} = {{")
                out.append(_spec_block(agg, 20))
                out.append("                },")
            out.append("            },")
        out.append("        },")
    out.append("    },")
    out.append("}")
    return "\n".join(out) + "\n"
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest pipeline/tests/test_emit_lua.py -v`
Expected: 2 PASS

- [ ] **Step 5: Commit**
```bash
git add pipeline/emit_lua.py pipeline/tests/test_emit_lua.py && git commit -m "feat(pipeline): deterministic Lua serializer for the data contract"
```

---

## Task 6: Validierungs-Wächter

**Files:**
- Create: `pipeline/validate.py`
- Test: `pipeline/tests/test_validate.py`

- [ ] **Step 1: Write the failing test**

Create `pipeline/tests/test_validate.py`:
```python
from pipeline.models import AggregatedSpec
from pipeline.validate import validate


def _good():
    return AggregatedSpec(
        sample_size=30,
        stats=[{"key": "haste", "pct": 34.0}, {"key": "crit", "pct": 28.0},
               {"key": "mastery", "pct": 22.0}, {"key": "vers", "pct": 16.0}],
        talents=[{"importString": "ABC=", "usagePct": 68}],
        gear=[{"slot": "HEAD", "itemID": 21001, "name": "Helm"}],
        gems=[], enchants=[], consumables={"flask": 212283},
    )


def test_good_data_has_no_errors():
    assert validate({1: {71: {"raid": _good()}}}, min_sample=15) == []


def test_low_sample_flagged():
    a = _good(); a.sample_size = 5
    errs = validate({1: {71: {"raid": a}}}, min_sample=15)
    assert any("sampleSize" in e for e in errs)


def test_out_of_range_pct_flagged():
    a = _good(); a.stats[0]["pct"] = 150.0
    errs = validate({1: {71: {"raid": a}}}, min_sample=15)
    assert any("pct" in e for e in errs)


def test_empty_gear_flagged():
    a = _good(); a.gear = []
    errs = validate({1: {71: {"raid": a}}}, min_sample=15)
    assert any("gear" in e for e in errs)


def test_zero_itemid_flagged():
    a = _good(); a.gear = [{"slot": "HEAD", "itemID": 0, "name": "x"}]
    errs = validate({1: {71: {"raid": a}}}, min_sample=15)
    assert any("itemID" in e for e in errs)
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest pipeline/tests/test_validate.py -v`
Expected: FAIL (no module `pipeline.validate`)

- [ ] **Step 3: Write validate.py**

Create `pipeline/validate.py`:
```python
from pipeline.specs import STAT_KEYS


def validate(data, min_sample=15):
    """Gibt eine Liste von Fehlermeldungen zurück. Leer = grün."""
    errors = []
    for class_id, specs in data.items():
        for spec_id, contents in specs.items():
            for content, agg in contents.items():
                tag = f"[{class_id}/{spec_id}/{content}]"
                if agg.sample_size < min_sample:
                    errors.append(f"{tag} sampleSize {agg.sample_size} < {min_sample}")
                keys = {s["key"] for s in agg.stats}
                if keys != set(STAT_KEYS):
                    errors.append(f"{tag} stats keys unvollständig: {sorted(keys)}")
                for s in agg.stats:
                    if not (0.0 <= s["pct"] <= 100.0):
                        errors.append(f"{tag} pct außerhalb 0..100: {s['key']}={s['pct']}")
                if not agg.gear:
                    errors.append(f"{tag} gear leer")
                for g in agg.gear:
                    if not g.get("itemID"):
                        errors.append(f"{tag} gear itemID = 0 in {g.get('slot')}")
    return errors
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest pipeline/tests/test_validate.py -v`
Expected: 5 PASS

- [ ] **Step 5: Commit**
```bash
git add pipeline/validate.py pipeline/tests/test_validate.py && git commit -m "feat(pipeline): validation guard over aggregated data"
```

---

## Task 7: Orchestrator + CLI

**Files:**
- Create: `pipeline/run.py`
- Test: `pipeline/tests/test_run.py`

**Hinweis:** `run.py` verdrahtet Abruf → Aggregation → Serialisierung → Validierung. Der Live-Abruf (`collect_records`) ist dünn und wird nicht unit-getestet (braucht die Live-API); getestet wird die reine Pipeline `build_and_write` mit eingespeisten Records.

- [ ] **Step 1: Write the failing test**

Create `pipeline/tests/test_run.py`:
```python
import os
from pipeline.models import ParseRecord
from pipeline.run import build_and_write


def _rec(cid, sid, content):
    return ParseRecord(
        class_id=cid, spec_id=sid, content=content,
        stats={"haste": 7000, "crit": 5600, "mastery": 3500, "vers": 3120},
        talent_import="ABC=", talent_sig="A",
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


def test_build_and_write_returns_errors_and_skips_on_bad_data(tmp_path):
    records = [_rec(1, 71, "raid") for _ in range(3)]   # unter min_sample
    out = tmp_path / "MetaMirrorData.lua"
    errors = build_and_write(records, season=SEASON, version="v", season_name="s",
                             out_path=str(out), item_name=lambda i: f"item{i}", min_sample=15)
    assert errors
    assert not out.exists()      # bei rot NICHT schreiben
```

- [ ] **Step 2: Run test to verify it fails**

Run: `python -m pytest pipeline/tests/test_run.py -v`
Expected: FAIL (no module `pipeline.run`)

- [ ] **Step 3: Write run.py**

Create `pipeline/run.py`:
```python
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
    """records -> aggregieren -> validieren -> nur bei grün schreiben. Gibt Fehlerliste zurück."""
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
    """Live-Abruf über die WCL-API. Dünn gehalten; Struktur-Details in fetch.py.
    Muss beim ersten Lauf mit echten Credentials gegen reale Antworten verifiziert werden."""
    from pipeline.fetch import parse_combatant_info
    records = []
    # Pseudo-Ablauf pro Spec × Content:
    #   1) Rankings-Query -> Liste (reportCode, fightID, sourceID, start, end)
    #   2) je Eintrag CombatantInfo-Events -> parse_combatant_info(...)
    # Die konkreten GraphQL-Strings/Feldnamen hier einsetzen, sobald live verifiziert.
    raise NotImplementedError("Live-Abruf: GraphQL-Strings nach Verifikation ergänzen")


def item_name_stub(item_id):
    # Item-Namen werden zur Laufzeit im Addon aufgelöst; hier nur Fallback-Text.
    return f"item:{item_id}"


def main(argv=None):
    ap = argparse.ArgumentParser()
    ap.add_argument("--out", default="Data/MetaMirrorData.lua")
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--min-sample", type=int, default=15)
    args = ap.parse_args(argv)

    client_id = os.environ.get("WCL_CLIENT_ID")
    client_secret = os.environ.get("WCL_CLIENT_SECRET")
    if not client_id or not client_secret:
        print("WCL_CLIENT_ID / WCL_CLIENT_SECRET fehlen", file=sys.stderr)
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
```

- [ ] **Step 4: Run test to verify it passes**

Run: `python -m pytest pipeline/tests/test_run.py -v`
Expected: 2 PASS

- [ ] **Step 5: Run the full suite**

Run: `python -m pytest pipeline/ -v`
Expected: alle PASS

- [ ] **Step 6: Commit**
```bash
git add pipeline/run.py pipeline/tests/test_run.py && git commit -m "feat(pipeline): orchestrator + CLI (build/validate/write, dry-run)"
```

---

## Task 8: GitHub-Actions-Workflow

**Files:**
- Create: `.github/workflows/update-data.yml`

- [ ] **Step 1: Write the workflow**

Create `.github/workflows/update-data.yml`:
```yaml
name: Update MetaMirror data
on:
  schedule:
    - cron: "0 6 * * 1"      # jeden Montag 06:00 UTC
  workflow_dispatch: {}

permissions:
  contents: write

jobs:
  refresh:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4

      - uses: actions/setup-python@v5
        with:
          python-version: "3.12"

      - name: Install deps
        run: pip install -r pipeline/requirements.txt

      - name: Unit tests
        run: python -m pytest pipeline/ -q

      - name: Generate data
        env:
          WCL_CLIENT_ID: ${{ secrets.WCL_CLIENT_ID }}
          WCL_CLIENT_SECRET: ${{ secrets.WCL_CLIENT_SECRET }}
        run: python -m pipeline.run --out Data/MetaMirrorData.lua

      - name: Lua syntax gate
        run: |
          sudo apt-get update && sudo apt-get install -y lua5.1
          luac5.1 -p Data/MetaMirrorData.lua

      - name: Commit data
        run: |
          git config user.name "metamirror-bot"
          git config user.email "bot@users.noreply.github.com"
          if ! git diff --quiet Data/MetaMirrorData.lua; then
            git add Data/MetaMirrorData.lua
            git commit -m "chore(data): weekly meta refresh $(date -u +%F)"
            git push
          else
            echo "keine Änderung"
          fi

      - name: Publish to CurseForge (gated)
        if: ${{ vars.CF_PUBLISH == 'true' }}
        env:
          CURSEFORGE_TOKEN: ${{ secrets.CURSEFORGE_TOKEN }}
        run: |
          echo "CurseForge-Upload aktiv — erst nach ToS-Klärung + Projekt-ID einschalten."
          # Upload-Schritt (z.B. Zip bauen + CurseForge-Upload-API) hier ergänzen.
```

- [ ] **Step 2: Verify YAML parses**

Run: `python -c "import yaml,sys; yaml.safe_load(open('.github/workflows/update-data.yml')); print('yaml ok')"`
Expected: `yaml ok` (falls PyYAML fehlt: `pip install pyyaml` davor)

- [ ] **Step 3: Commit**
```bash
git add .github/workflows/update-data.yml && git commit -m "ci: weekly WCL data refresh workflow (CurseForge gated by CF_PUBLISH)"
```

---

## Task 9: Addon — Datendatei umbenennen + klickbare Verbrauchsgüter

**Files:**
- Rename: `Data/SampleData.lua` → `Data/MetaMirrorData.lua`
- Modify: `MetaMirror.toc`
- Modify: `UI.lua` (Verbrauchsgüter-Rendering)

Dieser Task ist unabhängig von der Pipeline und **sofort im Spiel testbar**.

- [ ] **Step 1: Datendatei umbenennen und Sample erweitern**

Benenne `Data/SampleData.lua` in `Data/MetaMirrorData.lua` um. Ändere den obersten Kommentar/Version und ergänze in **jedem** `consumables`-Block die Keys `phial` und `oil`; setze bei mindestens einem Spec `flask` auf eine echte itemID zum Live-Test der Links. Beispiel für den ersten Block (Waffen-Krieger, mythicplus):
```lua
                    consumables = { flask = 212283, phial = 0, potion = 0, food = 0, oil = 0, rune = 0 },
```
Setze außerdem oben:
```lua
MetaMirrorData = {
    version = "sample-2026-08-31",
    attribution = "Data from Warcraft Logs",
```
(Die übrigen `consumables`-Blöcke analog um `phial = 0, oil = 0` ergänzen; `flask`/`food`/`potion` dürfen 0 bleiben.)

- [ ] **Step 2: TOC umstellen**

In `MetaMirror.toc` die Zeile `Data\SampleData.lua` ersetzen durch:
```
Data\MetaMirrorData.lua
```

- [ ] **Step 3: Verbrauchsgüter-Render-Block durch klickbare Item-Zeilen ersetzen**

In `UI.lua` den `else -- cons`-Zweig in `RenderBody` (aktuell die `renderLines({...})`-Ausgabe der Flask/Potion/Food-itemIDs) ersetzen durch `renderConsumables(data)`. Füge dazu **vor** `function MetaMirror.RenderBody` folgenden Block ein:
```lua
-- Verbrauchsgueter als klickbare Item-Links (Shift-Klick -> Chat / AH-Suche).
local consRows = {}
local function getConsRow(i)
    if consRows[i] then return consRows[i] end
    local b = CreateFrame("Button", nil, Body)
    b:SetSize(320, 20)
    b:RegisterForClicks("AnyUp")
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(18, 18); b.icon:SetPoint("TOPLEFT", 0, 0)
    b.label = fs(b, "GameFontHighlightSmall", C.TXT); b.label:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self, button)
        if not self.link then return end
        -- Blizzard-Standard: Shift -> Chat/AH-Suche; sonst Item-Link-Popup
        if not HandleModifiedItemClick(self.link) then
            SetItemRef(self.link, self.link, button, self)
        end
    end)
    consRows[i] = b
    return b
end

local function setConsRow(b, label, itemID)
    if itemID and itemID ~= 0 then
        b.link = nil
        b.icon:SetTexture(134400)   -- Fragezeichen-Platzhalter bis geladen
        b.label:SetText(label .. ": ...")
        local item = Item:CreateFromItemID(itemID)
        item:ContinueOnItemLoad(function()
            b.link = item:GetItemLink()
            b.icon:SetTexture(item:GetItemIcon())
            b.label:SetText(label .. ": " .. (item:GetItemName() or ("item:" .. itemID)))
        end)
    else
        b.link = nil
        b.icon:SetTexture(nil)
        b.label:SetText(label .. ": -")
    end
    b:Show()
end

local CONS_ORDER = {
    { key = "flask",  label = "Flask"  },
    { key = "phial",  label = "Phiole" },
    { key = "potion", label = "Pott"   },
    { key = "food",   label = "Food"   },
    { key = "oil",    label = "Oel"    },
    { key = "rune",   label = "Rune"   },
}

local function hideCons()
    for j = 1, #consRows do consRows[j]:Hide() end
end

local function renderConsumables(data)
    for j = 1, #rows do rows[j]:Hide() end
    if Body.msg then Body.msg:Hide() end
    local c = data.consumables or {}
    local i = 0
    for _, cat in ipairs(CONS_ORDER) do
        if c[cat.key] ~= nil then
            i = i + 1
            local b = getConsRow(i)
            b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -(i - 1) * 22)
            setConsRow(b, cat.label, c[cat.key])
        end
    end
    for j = i + 1, #consRows do consRows[j]:Hide() end
end
```

- [ ] **Step 4: RenderBody anpassen — consRows mit ausblenden und cons-Zweig umstellen**

In `MetaMirror.RenderBody`:
- Direkt nach `hideTalents()` (die zwei Stellen: im `if not data`-Zweig und im Normalfall) je ein `hideCons()` ergänzen.
- Den kompletten `else -- cons ... end`-Block ersetzen durch:
```lua
    else -- cons
        renderConsumables(data)
    end
```
Ergebnis (Kontext des Normalfalls):
```lua
    Body.msg:Hide()
    hideTalents()
    hideCons()
    if MetaMirrorDB.tab == "stats" then
        renderStats(self, data)
    elseif MetaMirrorDB.tab == "talents" then
        renderTalents(data)
    elseif MetaMirrorDB.tab == "gear" then
        local lines = {}
        for _, g in ipairs(data.gear or {}) do lines[#lines+1] = "|cffa3d0ff" .. g.slot .. "|r  " .. g.name end
        renderLines(#lines > 0 and lines or { L.no_data })
    elseif MetaMirrorDB.tab == "gems" then
        local lines = {}
        for _, g in ipairs(data.gems or {})     do lines[#lines+1] = g.slot .. ": " .. g.name end
        for _, e in ipairs(data.enchants or {}) do lines[#lines+1] = e.slot .. ": " .. e.name end
        renderLines(#lines > 0 and lines or { L.no_data })
    else -- cons
        renderConsumables(data)
    end
```
Und im `if not data`-Zweig:
```lua
    if not data then
        for j = 1, #rows do rows[j]:Hide() end
        hideTalents()
        hideCons()
        Body.msg:Show(); Body.msg:SetText(L.no_data)
        return
    end
```

- [ ] **Step 5: Attribution-Fußzeile im Panel (ToS-Pflicht)**

In `UI.lua`, in `MetaMirror:BuildPanel()` direkt vor `Panel:Hide()` (am Ende der Funktion) eine kleine Fußzeile ergänzen:
```lua
    -- Quellen-Attribution (RPGLogs-API-ToS verlangt Nennung)
    local attrText = (MetaMirrorData and MetaMirrorData.attribution) or "Data from Warcraft Logs"
    local footer = fs(Panel, "GameFontDisableSmall", C.DIM)
    footer:SetPoint("BOTTOMRIGHT", -8, 6)
    footer:SetText(attrText)
```
Erwartung: unten rechts im Panel steht dezent „Data from Warcraft Logs".

- [ ] **Step 6: Lua-Syntax prüfen (falls luac lokal vorhanden)**

Run (optional, wenn Lua installiert): `luac -p UI.lua Data/MetaMirrorData.lua`
Expected: keine Ausgabe (= ok). Falls kein `luac`: im Spiel verifizieren.

- [ ] **Step 7: Ins WoW-AddOns-Verzeichnis deployen und live testen**

Kopiere den Addon-Ordner nach `D:\Battle.net\World of Warcraft\_retail_\Interface\AddOns\MetaMirror\` und im Spiel `/reload`.
Erwartung: Charakterfenster öffnen (C) → MetaMirror → Tab „Verbrauchsgüter" → Flask-Zeile zeigt Icon + Name; **Hover = Tooltip**, **Shift-Linksklick verlinkt in den Chat**, und bei offenem Auktionshaus landet der Name in der Suchleiste.

- [ ] **Step 8: Commit**
```bash
git add MetaMirror.toc UI.lua Data/ && git commit -m "feat(addon): clickable consumable item links; rename data file to MetaMirrorData.lua"
```

---

## Abschluss

Nach allen Tasks: **ERFORDERLICHES SUB-SKILL** superpowers:finishing-a-development-branch (Tests grün → Optionen zum Mergen/PR).

**Danach durch den Nutzer (zum Ausführen der Pipeline):**
1. WCL-API-Client anlegen (`https://www.warcraftlogs.com/api/clients/`) → `WCL_CLIENT_ID`/`WCL_CLIENT_SECRET`.
2. MetaMirror-Repo auf GitHub pushen, beide Secrets als GitHub-Secrets hinterlegen.
3. `season.py` mit den echten Season-Werten füllen (RATING_PER_PCT, MASTERY_COEFF, Encounter/Zone-IDs, CONSUMABLE_SPELL_TO_ITEM) und `collect_records` in `run.py` mit den live verifizierten GraphQL-Strings vervollständigen.
4. Workflow einmal manuell auslösen (`workflow_dispatch`), reale JSON-Struktur gegen `fetch.py` prüfen.
5. CurseForge-Upload erst nach ToS-Klärung via Repo-Variable `CF_PUBLISH=true` aktivieren.
