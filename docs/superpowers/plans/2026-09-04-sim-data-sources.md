# Sim-Datenquellen (bloodmallet + SimulationCraft) — Implementierungsplan

**Ziel:** Stats-, Ausrüstungs- und Verbesserungen-Tab sowie BiS-Drop-Alarm wieder mit Daten füllen — aus erlaubten Quellen (bloodmallet `secondary_distributions`, SimulationCraft-Profile), ohne den Lua-Datenvertrag zu ändern.

**Architektur:** Zwei neue Quellmodule (`bloodmallet_sd.py`, `simc_profile.py`) liefern je Spec Stats/Gear/Gems/Enchants bzw. Verbrauchsgüter. Ein Orchestrator (`build_sim.py`) baut daraus `AggregatedSpec`-Objekte (sample_size = 1), validiert und schreibt über den bestehenden `emit_lua` nach `Data/MetaMirrorData.lua`. Das Addon liest den unveränderten Vertrag; nur Beschriftung/Attribution ändern sich.

**Stack:** Python 3.12, httpx, pytest; WoW-Lua 5.1 (lokal `luac -p`).

**Quellenbefund (Recherche 2026-09-04):**
- `https://bloodmallet.com/chart/get/secondary_distributions/<fight_style>/<class_slug>/<spec_slug>` — HTTP immer 200, Fehler nur im Body (`{"status":"error",...}`). `data[tier][key]` mit `key = "<crit>_<haste>_<mastery>_<vers>"` (Prozent), `sorted_data_keys[tier][0]` = beste Verteilung, `secondary_sum` = Sekundärbudget des Profils (Rating). `profile.items[slot] = {id, bonus_id "a/b", gem_id "a/b", enchant_id, crafted_stats}`. Fight-Styles mit Daten: `castingpatchwerk`, `castingpatchwerk3`, `castingpatchwerk5`; `hecticaddcleave` → Fehler. bloodmallet-FAQ: „All data is free to use for everyone."
- SimC-Profile: `https://raw.githubusercontent.com/simulationcraft/simc/midnight/profiles/MID2/MID2_<Class>_<Spec>.simc` (GPLv3). Zeilen `flask=`, `potion=`, `food=`, `augmentation=`, `temporary_enchant=main_hand:<slug>`, Gear-Zeilen `<slot>=<slug>,id=..,bonus_id=a/b,gem_id=a/b,enchant_id=..`, Kommentarblock `# gear_ilvl=`, `# set_bonus=<name>_<n>pc=1`. Druid/Evoker fehlen in MID2 (in MID1 vorhanden).
- Fixtures: `pipeline/tests/fixtures/sd_*.json`, `MID2_*.simc`.

**Slot-Mapping (simc → Addon, Namen exakt wie `pipeline/fetch.py` GEAR_SLOT_BY_INDEX / `UI.lua` SLOT_ORDER):**
head→HEAD, neck→NECK, shoulders→SHOULDER, back→BACK, chest→CHEST, wrists→WRIST, hands→HANDS, waist→WAIST, legs→LEGS, feet→FEET, finger1→RING1, finger2→RING2, trinket1→TRINKET1, trinket2→TRINKET2, main_hand→MAINHAND, off_hand→OFFHAND. (Implementierer: Namen gegen die beiden Stellen prüfen, nicht raten.)

**Rating-Ziel je Stat:** `rating = int(secondary_sum * pct / 100)`; Ausgabe absteigend nach Rating sortiert, Keys `haste|crit|mastery|vers` (STAT_KEYS).

**Fight-Style je Content:** `raid = castingpatchwerk`, `mythicplus = castingpatchwerk3` (Konstante `FIGHT_STYLE_BY_CONTENT`; Gear kommt aus dem Profil des jeweiligen Payloads).

**Verbrauchsgüter:** Slug aus dem SimC-Profil → itemID über `season.SIMC_CONSUMABLE_ITEMS` (Rang-Suffix `_<n>` vor dem Lookup abschneiden). Nur bereits in `season.py` verifizierte IDs verwenden; unbekannte Slugs → Warnung, kein Eintrag. Danach `apply_curated_consumables` wie bisher (food/potion/oil kuratiert).

---

## Task 1 — Quellmodule + Tests (pipeline)

Dateien: `pipeline/bloodmallet_sd.py` (neu), `pipeline/simc_profile.py` (neu), `pipeline/season.py` (nur `SIMC_CONSUMABLE_ITEMS` ergänzen), `pipeline/tests/test_bloodmallet_sd.py`, `pipeline/tests/test_simc_profile.py`.

`bloodmallet_sd.py`:
- `FIGHT_STYLE_BY_CONTENT = {"raid": "castingpatchwerk", "mythicplus": "castingpatchwerk3"}`
- `endpoint(class_name, spec_name, fight_style)` (nutzt `trinkets.slug`)
- `is_error(payload) -> bool`
- `parse_distribution(payload) -> dict` mit `tier, top_key, pct{crit,haste,mastery,vers}, secondary_sum, dps, timestamp, simc_hash`; `ValueError` bei Fehler-Payload / fehlenden Keys.
- `stats_from_distribution(parsed) -> [{"key","rating"}]` (sortiert, alle vier Keys)
- `gear_from_profile(payload) -> (gear, gems, enchants)` im AggregatedSpec-Format; `enchants[].itemID` über `season.ENCHANT_ITEM_BY_ID`, unbekannt → 0; `name = "item:<id>"`; `itemLevel = 0`; `bonusIDs` als int-Liste.
- `fetch(class_name, spec_name, fight_style, client=None) -> payload` (httpx, UA-Header, Timeout 30 s).

`simc_profile.py`:
- `SIMC_CLASS_DIR = {"DeathKnight": "Death_Knight", "DemonHunter": "Demon_Hunter", ...}` — Dateiname `MID2_<Class>_<Spec>.simc`; `spec_name` CamelCase → `Beast_Mastery` (Regel wie `slug`, aber Teile groß).
- `profile_url(class_name, spec_name, tier="MID2")`
- `parse_profile(text) -> dict`: `actor, spec, talents, consumables{flask,potion,food,augmentation,temporary_enchant{slot:slug}}, gear{simc_slot:{id,bonus_id[int],gem_id[int],enchant_id,ilevel}}, gear_ilvl, set_bonus[list]`. Kommentarzeilen außer `# gear_ilvl` / `# set_bonus` ignorieren.
- `consumable_item_ids(parsed_consumables) -> {"flask": id, "rune": id, "oil": id, ...}` über `season.SIMC_CONSUMABLE_ITEMS`; Rangsuffix `_\d+` strippen; unbekannt → nicht enthalten (+ Rückgabe der unbekannten Slugs für das Log).
- `fetch(class_name, spec_name, tier="MID2", client=None) -> text|None` (404 → None; Aufrufer versucht MID1).

`season.py` ergänzen:
```python
SIMC_CONSUMABLE_ITEMS = {
    "flask_of_the_shattered_sun": ("flask", 241326),
    "flask_of_the_magisters": ("flask", 241322),
    "flask_of_the_blood_knights": ("flask", 241325),
    "void_touched_augment_rune": ("rune", 259085),
    "ethereal_augment_rune": ("rune", 243191),
    "thalassian_phoenix_oil": ("oil", 243733),
}
```
(IDs bereits oben in derselben Datei verifiziert; keine weiteren erfinden.)

Tests (TDD, Fixtures aus `pipeline/tests/fixtures/`): Stat-Reihenfolge Crit/Haste/Mastery/Vers, Rating-Rechnung (Mage/Frost: 3040 × 0.40 = 1216 Crit), Fehler-Payload, Gear-Slot-Mapping inkl. fehlendem `off_hand`, Doppel-Gem am Hals, Enchant-Mapping bekannt/unbekannt, SimC-Parser für alle vier Fixtures (Consumables, gear_ilvl, set_bonus, omnium numerisch UND textuell), Slug-Suffix-Strip, Dateinamens-Regel (`Death_Knight`, `Beast_Mastery`).

## Task 2 — Orchestrator + Emitter (pipeline)

Dateien: `pipeline/build_sim.py` (neu), `pipeline/emit_lua.py` (Attribution/Extras parametrisieren), `pipeline/tests/test_build_sim.py`, `pipeline/tests/test_emit_lua.py` (anpassen).

- `emit_lua(data, version, season, trinkets=None, attribution="Data from bloodmallet.com (SimulationCraft)", extra=None)`; `extra` = dict aus String/Number/verschachtelten Dicts, ausgegeben als Top-Level-Felder (z. B. `fightStyles = { raid = "castingpatchwerk", mythicplus = "castingpatchwerk3" }`, `simcHash = "..."`, `generated = "2026-09-04"`). Kein „Warcraft Logs" mehr im Emitter.
- `build_sim.build(specs, contents, fetch_sd, fetch_simc, log) -> (data, meta)`; pro Spec: SD je Content (Fehler → Spec/Content überspringen, loggen), SimC-Profil MID2 → MID1 → None; `AggregatedSpec(sample_size=1, ...)`; consumables = `apply_curated_consumables(spec_id, ids_aus_simc)`.
- Abbruchregel: < 20 Specs mit Daten → Fehler, nichts schreiben.
- `validate(plain, min_sample=1)`, dann `emit_lua(...)` → `--out` (Default `Data/MetaMirrorData.lua`), `newline="\n"`.
- Cache: Rohantworten unter `pipeline/cache/sim/` (gitignored); `--offline` liest nur Cache. Höflichkeit: 0.3 s Pause zwischen Requests.
- CLI: `python -m pipeline.build_sim [--out] [--offline] [--only mage/frost]`.
- Tests mit injizierten Fetch-Funktionen (Fixtures), keine Netzaufrufe; Emitter-Test prüft neue Attribution und `extra`.

## Task 3 — Addon, Texte, Workflow

Dateien: `MetaMirror.toc`, `Localization.lua`, `UI.lua` (nur Fußzeile/Hinweis), `README.md`, `release/description-*.md`, `release/summary-en.txt`, `.github/workflows/sim-data.yml`, `.github/workflows/tests.yml`.

- TOC: `Data\MetaMirrorData.lua` wieder laden (vor `Data\MetaMirrorTrinkets.lua`); `## Notes:` englisch + `## Notes-deDE:` — Formulierung „sim reference", nicht „top players".
- Localization: `L.usage` entfernen; neu `L.sim_note = "sim reference \194\183 %s \194\183 %s"`, `L.fight_raid = "single target"`, `L.fight_mplus = "3 targets"` (+ deDE).
- UI: Fußzeile bevorzugt `MetaMirrorData.attribution`, sonst `MetaMirrorTrinkets.source`. Auf dem Stats-Tab eine gedämpfte Hinweiszeile nach dem Muster von `trinket_note` (Fight-Style laut `MetaMirrorData.fightStyles[content]`, Datum `MetaMirrorData.generated`). Keine weiteren UI-Umbauten.
- Texte: Feature-Tabellen wiederherstellen, ehrlich beschriftet (Sim-Referenz statt Top-Spieler); Abschnitt „Currently unavailable" entfernen; „About Warcraft Logs" kürzen, aber behalten.
- Workflows: `tests.yml` (push/PR → pytest, `luac -p` mit apt `lua5.1`), `sim-data.yml` (Montag 06:00 UTC + manuell → pytest, `python -m pipeline.build_sim`, `luac5.1 -p Data/MetaMirrorData.lua`, commit+push nur bei Diff; `contents: write`). **Kein CurseForge-Upload, `CF_PUBLISH` bleibt aus, keine Secrets nötig.**

## Task 4 — Echter Lauf + Abnahme (Orchestrator selbst)

`python -m pipeline.build_sim` → `Data/MetaMirrorData.lua`; `luac -p`; Headless-Harness (`tests/run_harness.lua`, aus dem Scratchpad übernommen) mit SelfTest; Stichprobe: Mage/Frost Stats = Crit 1216 / Mastery 1216 / Haste 304 / Vers 304.

## Stufe 2 (separat, nicht in diesem Plan): Battle.net-Pfad

Siehe `docs/research/2026-09-04-battlenet-feasibility.md`. Eigene Pipeline `pipeline/bnet/`, Kandidaten aus M+-Leaderboards (Blizzard) bzw. Raider.IO (Raid), Gear/Statistics je Charakter, namenloses Aggregat, Wochen-Cron, Secrets `BNET_CLIENT_ID/SECRET`.
