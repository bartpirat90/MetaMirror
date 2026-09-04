# Datenformat-Dokumentation: bloodmallet Secondary Distributions & SimulationCraft-Profile (Branch `midnight`)

Stand der Recherche: 2026-09-04. Alle Beispiele live gegen `bloodmallet.com` bzw. `raw.githubusercontent.com/simulationcraft/simc` (Branch `midnight`) abgerufen. Rohdateien liegen unter `fixtures/` im selben Ordner wie dieser Bericht.

---

## A) bloodmallet — `secondary_distributions`

### A.1 URL-Muster

```
https://bloodmallet.com/chart/get/secondary_distributions/<fight_style>/<class_slug>/<spec_slug>
```

- `class_slug`/`spec_slug` sind snake_case (`death_knight`, `beast_mastery`, `frost`, `arms`, …).
- Antwort ist rohes JSON, `Content-Type` unabhängig vom Accept-Header immer JSON.
- Getestete `fight_style`-Werte für `mage/frost`:

| fight_style | HTTP | Ergebnis |
|---|---|---|
| `castingpatchwerk` | 200 | Volle Daten (Baseline-Fight-Style, keine Bewegung, kein AoE) |
| `castingpatchwerk3` | 200 | Volle Daten — identische Struktur, andere DPS-Werte (3-Ziel-Variante von Patchwerk) |
| `castingpatchwerk5` | 200 | Volle Daten — 5-Ziel-Variante |
| `hecticaddcleave` | 200 | **Kein Standard-Chart**: `{"status": "error", "message": "No standard chart with these values found."}` (76 Bytes) — dieser Fight-Style wird für `secondary_distributions` nicht vorgehalten (nur bestimmte fight styles werden von bloodytools für diesen Chart-Typ generiert) |

Wichtig für die Pipeline: **HTTP-Status ist immer 200**, auch bei "keine Daten". Fehler/Leerfall muss über den Body erkannt werden: `body.get("status") == "error"` bzw. Prüfen, ob `"data"` als Key fehlt.

### A.2 Top-Level-Keys (identisch in allen vier Beispielen)

```
class_id, data, data_profile_overrides, data_type, metadata,
profile, secondary_sum, simc_settings, sorted_data_keys,
spec_id, subtitle, timestamp, title, translations
```

| Key | Typ | Bedeutung |
|---|---|---|
| `class_id` | int | WoW-internes Klassen-ID (Mage=8) |
| `spec_id` | int | WoW-internes Spec-ID |
| `data_type` | string | `"secondary_distributions"` |
| `data` | object | Kern-Nutzdaten, siehe A.3 |
| `sorted_data_keys` | object | Pro Tier/Variante eine Liste der Verteilungs-Keys, **absteigend nach DPS sortiert** (siehe A.4) |
| `data_profile_overrides` | object | Talent-String(s) je Datenreihe (siehe A.5) |
| `secondary_sum` | int | Summe aller Sekundär-Ratings (Crit+Haste+Mastery+Vers) aus dem Gear des Profils; Basis für die Umrechnung Prozent→Rating (siehe A.4) |
| `profile` | object | Das simulierte Charakterprofil: `character` (Klasse/Level/Rasse/Rolle/Spec/Talente) + `items` (Gear) + `metadata.base_dps` |
| `simc_settings` | object | `fight_style`, `iterations`, `ptr`, `simc_hash`, `target_error`, `tier` |
| `metadata` | object | `SimulationCraft`-Commit-Hash, `bloodytools`-Commit-Hash, Erzeugungs-`timestamp` (UTC, Sekundenauflösung) |
| `timestamp` | string | Kurzform `"UTC 2026-09-02 02:42"` |
| `subtitle` | string | HTML-Snippet mit Link auf den SimC-Commit |
| `title` | string | Menschlich lesbarer Titel, z. B. `"Secondary Distributions | Frost Mage | Castingpatchwerk"` |
| `translations` | object | In allen Beispielen leer `{}` |

### A.3 Struktur von `data`

```
data[tier_key][distribution_key] = dps (int)
```

- `tier_key` ist in allen vier Beispielen **`"MID2"`** — das entspricht `simc_settings.tier`. Es ist **nicht** wörtlich ein "Itemization-Tier"-Label im Sinne einer festen Enumeration, sondern der **`human_name` der verwendeten Talent/Profil-Variante** aus `bloodytools` (siehe Quellcode A.6) — hier zufällig identisch mit dem Gear-Tier-Namen, weil bloodytools aktuell `data_profile_overrides = {"MID2": [talents_string]}` als einzige Variante fährt. Bei anderen Chart-Läufen könnten hier mehrere Keys stehen (z. B. mehrere Talentbauten). Für die aktuelle Datenlage (Midnight-Beta, Tier MID2) reicht `list(data.keys())[0]` bzw. Iteration über alle Keys.
- `distribution_key` hat das Format `"<crit>_<haste>_<mastery>_<versatility>"`, vier Ganzzahlen in **Prozent, in exakt dieser Reihenfolge: Crit, Haste, Mastery, Versatility**. Belegt durch den bloodytools-Quellcode (`bloodytools/simulations/secondary_distribution_simulator.py`, Zeile mit `for crit, haste, mastery, vers in distribution_multipliers` und `name="...{}_{}_{}_{}".format(..., crit, haste, mastery, vers)"`).
- Wertebereich je Stat: 10–70 in 10er-Schritten (`step_size` Standard = 10), Summe der vier Zahlen ist immer 100. Daraus ergeben sich 84 Kombinationen (bestätigt: alle 4 Beispiele haben genau 84 Einträge).
- **Umrechnung in tatsächliches Rating**: `rating_stat = int(secondary_sum * (percent / 100))`, angewendet als `gear_crit_rating=`, `gear_haste_rating=`, `gear_mastery_rating=`, `gear_versatility_rating=` SimC-Overrides — d. h. die Simulation ersetzt das reale Gear-Rating durch diese künstliche Verteilung, behält aber Primärstat/Ilvl/Set-Boni etc. bei.
- Der DPS-Wert ist ein **gerundeter Integer** (kein Float, keine Fehlerangabe/Stddev im Chart-JSON).

### A.4 `sorted_data_keys` und Baseline-/Top-Erkennung

```
sorted_data_keys[tier_key] = [distribution_key, ...]  # absteigend nach DPS
```

- **Top-Ergebnis** = `sorted_data_keys[tier_key][0]` (höchste DPS). Beispiel Mage/Frost: `"40_10_40_10"` mit 205517 DPS = 40 % Crit, 10 % Haste, 40 % Mastery, 10 % Versatility.
- Es gibt **keinen separaten "Baseline"-Marker** im Sinne des tatsächlichen Ist-Gears. `profile.metadata.base_dps` (z. B. `179624.914...` bei Mage/Frost) ist der Referenzwert der 1-Iterations-Stat-Extraktions-Simulation und stimmt (gerundet) mit `data["MID2"]["10_10_10_70"]` überein — das ist aber kein ausgezeichneter "Baseline"-Key, sondern zufällig der erste iterierte Kombinationswert (10/10/10/70 ist der lexikographisch erste `itertools.product`-Treffer mit Summe 100, nicht das reale Gear). Praktisch: Für "wie gut ist reales Gear" muss man `secondary_sum` und die realen Gear-Ratings selbst gegen die nächstliegende 10er-Rasterkombination matchen; einen exakten 1:1-Punkt für das echte Gear liefert der Chart nicht.
- Reihenfolge ist strikt absteigend; letzter Eintrag = schlechteste Kombination (bei Mage/Frost `"10_70_10_10"`, 179317 DPS).

### A.5 `profile` / `data_profile_overrides` / `simc_settings` im Detail

`profile.character` (Beispiel Mage/Frost):
```json
{
  "# source": "simulationcraft",
  "class": "mage", "level": "90", "position": "ranged_back",
  "race": "tauren", "role": "spell", "spec": "frost",
  "talents": "CAEAAAAAAAAAAAAAAAAAAAAAAYGGLzMzsMmZmYmZGjZMziZmZmZMDEAAYmZmllZm2AAAAAAgNA2WGzMzAbzYmZYBAAgZ2AmBGwADD"
}
```
`profile.items`: pro Slot ein Objekt mit `id` (Item-ID), optional `bonus_id` (mit `/` getrennte Liste), `gem_id`, `enchant_id`, `crafted_stats`. Slotnamen: `head, neck, shoulders, back, chest, wrists, hands, waist, legs, feet, finger1, finger2, trinket1, trinket2, main_hand, off_hand` — **kein** separater `weapon`-Key, Zweihand/Einhand wird über `main_hand`/`off_hand` abgebildet wie im SimC-Profil selbst. `profile.metadata.base_dps` = float, s. o.

`data_profile_overrides`: `{ "<human_name>": ["talents=<Talentstring>"] }` — der Talentstring, der für die jeweilige `data`-Variante verwendet wurde (identisch zu `profile.character.talents`, da hier nur eine Variante existiert).

`simc_settings`:
```json
{"fight_style":"castingpatchwerk","iterations":"60000","ptr":"0","simc_hash":"f869791","target_error":"0.1","tier":"MID2"}
```
`simc_hash` = SimulationCraft-Commit (siehe auch `metadata.SimulationCraft`), `iterations`/`target_error` = Sim-Genauigkeit, `ptr` = "0"/"1" (Live vs. PTR-Build), `tier` = Gear-Tier-Kürzel, identisch zum `data`-Top-Key.

Es gibt **keine separaten `item_ids`/`spell_ids`-Arrays** auf Top-Level — Item-IDs stecken ausschließlich in `profile.items.*.id`.

### A.6 Quellcode-Beleg (bloodytools, nicht bloodmallet-Frontend)

Der Chart wird von `bloodytools` erzeugt (`Bloodmallet/bloodytools`, Datei `bloodytools/simulations/secondary_distribution_simulator.py`, Kopie liegt unter `scratchpad/secondary_distribution_simulator.py`). Relevanter Ausschnitt:

```python
rating_names = ["crit_rating", "haste_rating", "mastery_rating", "versatility_rating"]
...
step_combinations = itertools.product(possible_steps, repeat=4)
distribution_multipliers = [c for c in step_combinations if sum(c) == 100]
...
for crit, haste, mastery, vers in distribution_multipliers:
    s_o = Simulation_Data(
        name="{}{}{}_{}_{}_{}".format(human_name, sep, crit, haste, mastery, vers),
        simc_arguments=[..., 
            "gear_crit_rating={}".format(int(secondaries * (crit / 100))),
            "gear_haste_rating={}".format(int(secondaries * (haste / 100))),
            "gear_mastery_rating={}".format(int(secondaries * (mastery / 100))),
            "gear_versatility_rating={}".format(int(secondaries * (vers / 100))),
        ],
    )
...
data_dict["sorted_data_keys"][talent_combination] = [d for d, _ in sorted(tmp_list, key=lambda i: i[1], reverse=True)]
```

Das bestätigt zweifelsfrei: Reihenfolge **Crit → Haste → Mastery → Versatility**, absteigende Sortierung nach DPS, `secondary_sum` = Divisor/Multiplikator-Basis.

### A.7 Gekürzte JSON-Proben (erste Zeilen)

**mage/frost** (`fixtures/sd_mage_frost.json`):
```json
{"class_id": 8, "data": {"MID2": {"10_10_10_70": 179624, "10_10_20_60": 185976, "10_10_30_50": 190713, "10_10_40_40": 193768, "10_10_50_30": 195412, "10_10_60_20": 195131, "10_10_70_10": 193218, "10_20_10_60": 183041, ... }}, "data_profile_overrides": {"MID2": ["talents=CAEAAAAAAAAAAAAAAAAAAAAAAYGGLzMzsMmZmYmZGjZMziZmZmZMDEAAYmZmllZm2AAAAAAgNA2WGzMzAbzYmZYBAAgZ2AmBGwADD"]}, "data_type": "secondary_distributions", "metadata": {"SimulationCraft": "f869791", "bloodytools": "46e3351585a451857513383c763204768c9a23b9", "timestamp": "2026-09-02 02:42:00.976615"}, "profile": {"character": {"# source": "simulationcraft", "class": "mage", "level": "90", "position": "ranged_back", "race": "tauren", "role": "spell", "spec": "frost", "talents": "CAEAAAAAAAAAAAAAAAAAAAAAAYGGLzMzsMmZmYmZGjZMziZmZmZMDEAAYmZmllZm2AAAAAAgNA2WGzMzAbzYmZYBAAgZ2AmBGwADD"}, "items": {"back": {"bonus_id": "13662/13848", "id": "268253"}, "chest": {"bonus_id": "4786/4800/12854/13690/13698", "enchant_id": "7987", "id": "271567"}, ... }, "metadata": {"base_dps": 179624.91428323297}}, "secondary_sum": 3040, "simc_settings": {"fight_style": "castingpatchwerk", "iterations": "60000", "ptr": "0", "simc_hash": "f869791", "target_error": "0.1", "tier": "MID2"}, "sorted_data_keys": {"MID2": ["40_10_40_10", "50_10_30_10", "40_20_30_10", ...]}, "spec_id": 64, "subtitle": "UTC 2026-09-02 02:42 | SimC build: <a href=\"...\">f869791</a>", "timestamp": "UTC 2026-09-02 02:42", "title": "Secondary Distributions | Frost Mage | Castingpatchwerk", "translations": {}}
```
Top-DPS: `40_10_40_10` = 205517.

**warrior/arms** (`fixtures/sd_warrior_arms.json`): gleiche Struktur; `secondary_sum: 3051`; Top: `40_40_10_10` (Haste/Crit-lastig).
**death_knight/unholy** (`fixtures/sd_dk_unholy.json`): `secondary_sum: 3051`; Top: `50_10_30_10`.
**hunter/beast_mastery** (`fixtures/sd_hunter_bm.json`): `secondary_sum: 2902`; Top: `10_40_40_10` (Haste/Mastery-lastig).

Vollständige Rohdateien in `fixtures/sd_*.json`.

### A.8 Weitere `chart/get/`-Typen (Probe gegen `mage/frost`, `castingpatchwerk`)

| type | HTTP | Größe | Ergebnis |
|---|---|---|---|
| `races` | 200 | 11.8 KB | Daten vorhanden — `data[<Race-Name>] = dps` (flach, keine Sub-Tiers) |
| `trinkets` | 200 | 45.4 KB | Daten vorhanden — `data[<Trinket-Name>][<ilvl-string>] = dps` |
| `secondary_distributions` | 200 | 5.7 KB | Daten vorhanden (siehe oben) |
| `talent_target_scaling` | 200 | 2.5 KB | Daten vorhanden — `data["MID2"][<Zielanzahl-string>] = dps` (z. B. `"1".."15"` Ziele) |
| `phials` | 200 | 2.9 KB | Daten vorhanden — `data[<Phiolen-Name>][<Rank 1/2>] = dps` |
| `potions` | 200 | 3.2 KB | Daten vorhanden — analog zu phials |
| `tier_set` | 200 | 76 B | **Fehler**: `{"status":"error","message":"No standard chart with these values found."}` — auch bei `warrior/arms` |
| `weapon_enchantments` | 200 | 3.1 KB | Daten vorhanden — `data[<Enchant-Name>][<Rank>] = dps` |
| `power_infusion` | 200 | 76 B | **Fehler** (auch bei `warrior/arms`) |
| `windfury_totem` | 200 | 76 B | **Fehler** (auch bei `warrior/arms`, `hunter/beast_mastery`) |

Alle Fehlerantworten sind identisch (76 Byte JSON), unabhängig von Klasse/Spec — `tier_set`, `power_infusion` und `windfury_totem` scheinen für den aktuellen Midnight-Beta-Datenstand (Tier MID2, keine Set-Boni-Simulation, keine externe-Buff-Charts) generell (noch) nicht generiert zu werden, nicht spec-spezifisch leer. Für die Pipeline: **immer auf `status == "error"` prüfen**, nie nur auf HTTP-Code.

Aus dem bloodytools-Quellverzeichnis (`bloodytools/simulations/`) zusätzlich vorhandene Simulator-Module, die potenziell weitere Chart-Typen liefern (nicht einzeln getestet, aber als Namensraum bestätigt): `consumable_simulator.py` (deckt vermutlich `potions`/`phials`/`weapon_enchantments` ab), `talent_add_simulator.py`, `talent_removal_simulator.py`, `talent_simulator.py`, `talent_target_scaling_simulator.py`, `trinket_simulator.py`.

---

## B) SimulationCraft-Profile — Branch `midnight`

### B.1 Verzeichnisstruktur (`profiles/`, Branch `midnight`)

```
profiles/
├── CI.simc
├── MID1_Raid.simc          (Sammel-Datei: listet alle MID1-Profile per Include)
├── MID2_Raid.simc          (Sammel-Datei: listet alle MID2-Profile per Include)
├── PR_Raid.simc
├── MID1/   (50 Dateien, siehe unten)
├── MID2/   (44 Dateien, siehe unten)
├── PreRaids/  (1 Datei: PR_Priest_Shadow.simc)
├── generators/
└── tests/
```

`MID2_Raid.simc` (Kopf, s. `curl`-Abruf) ist keine eigene Profildatei, sondern eine **Include-Liste** für Batch-Runs:
```
optimal_raid=1
default_actions=1
single_actor_batch=1

MID2_Death_Knight_Blood.simc
MID2_Death_Knight_Blood_Deathbringer.simc
...
# MID2_Death_Knight_Frost_Deathbringer.simc   <- auskommentierte Zeilen = (noch) deaktivierte Varianten
```

**Alle 44 Dateinamen in `profiles/MID2/`:**
```
MID2_Death_Knight_Blood.simc              MID2_Monk_Brewmaster.simc
MID2_Death_Knight_Blood_Deathbringer.simc MID2_Monk_Windwalker.simc
MID2_Death_Knight_Frost.simc              MID2_Monk_Windwalker_Conduit.simc
MID2_Death_Knight_Frost_Rider.simc        MID2_Paladin_Protection.simc
MID2_Death_Knight_Unholy.simc             MID2_Paladin_Protection_Lightsmith.simc
MID2_Death_Knight_Unholy_San'layn.simc    MID2_Paladin_Retribution.simc
MID2_Demon_Hunter_Devourer.simc           MID2_Paladin_Retribution_Templar.simc
MID2_Demon_Hunter_Havoc.simc              MID2_Priest_Shadow.simc
MID2_Demon_Hunter_Havoc_Aldrachi_Reaver.simc  MID2_Priest_Shadow_Archon.simc
MID2_Demon_Hunter_Vengeance.simc          MID2_Rogue_Assassination.simc
MID2_Hunter_Beast_Mastery.simc            MID2_Rogue_Assassination_Fatebound.simc
MID2_Hunter_Marksmanship.simc             MID2_Rogue_Outlaw.simc
MID2_Hunter_Survival.simc                 MID2_Rogue_Subtlety.simc
MID2_Mage_Arcane.simc                     MID2_Shaman_Elemental.simc
MID2_Mage_Arcane_Sunfury.simc             MID2_Shaman_Elemental_Stormbringer.simc
MID2_Mage_Fire.simc                       MID2_Shaman_Enhancement.simc
MID2_Mage_Fire_Frostfire.simc             MID2_Shaman_Enhancement_Totemic.simc
MID2_Mage_Frost.simc                      MID2_Warlock_Affliction.simc
MID2_Mage_Frost_Frostfire.simc            MID2_Warlock_Affliction_Hellcaller.simc
MID2_Monk_Windwalker_Conduit.simc         MID2_Warlock_Demonology.simc
                                           MID2_Warlock_Destruction.simc
                                           MID2_Warlock_Destruction_Diabolist.simc
                                           MID2_Warrior_Arms.simc
                                           MID2_Warrior_Fury.simc
                                           MID2_Warrior_Protection.simc
```
(Druid und Evoker fehlen komplett in MID2 — noch nicht aktualisiert für diesen Tier; in MID1 sind sie vorhanden.)

**`profiles/MID1/` (50 Dateien)** — analoges Muster, zusätzlich `Druid_Balance/Feral/Guardian`, `Evoker_Devastation(_FS)`; sonst gleiche Hero-Talent-Suffixe (teils mit anderen Hero-Talent-Namen als in MID2, z. B. `MID1_Paladin_Retribution_Herald.simc` vs. `MID2_Paladin_Retribution_Templar.simc` — Hero-Talent-Zuordnung ändert sich offenbar zwischen den Tiers/Beta-Ständen).

**`profiles/PreRaids/` (1 Datei):** nur `PR_Priest_Shadow.simc` — aktuell kein vollständiger PreRaid-Satz für alle Specs vorhanden (Midnight ist Alpha/Beta-Stand).

**Kein M+/Dungeon-Ordner, keine `_DungeonSlice`/`hecticaddcleave`-Dateien.** Die Profile im `simc`-Repo sind ausschließlich raid-orientiert (Fight-Style wird beim Simc-Aufruf separat gesetzt, z. B. `castingpatchwerk`/`hecticaddcleave`; die Fight-Styles selbst liegen in `profiles/TargetErrorScan` bzw. sind Presets im SimC-Core, nicht in eigenen Profildateien pro Spec).

### B.2 Zeilen-Grammatik einer `MID2_<Class>_<Spec>[_<Hero>].simc`-Datei

Beispiel vollständig: `fixtures/MID2_Mage_Frost.simc` (145 Zeilen). Aufbau in Abschnitten:

**1. Kopfzeile / Actor-Definition**
```
mage="MID2_Mage_Frost_Spellslinger"
```
- Syntax: `<simc_class_name>="<Actor-Anzeigename>"`. `simc_class_name` ist der SimC-interne Klassenname (`mage`, `warrior`, `deathknight`, `hunter`, `paladin`, `priest`, `rogue`, `shaman`, `warlock`, `monk`, `demonhunter`, `druid`, `evoker`) — **nicht** identisch mit dem Dateinamen-Schema (`deathknight` statt `death_knight`).
- Der Anzeigename trägt oft **mehr Information als der Dateiname**: `MID2_Mage_Frost.simc` enthält den Actor `"MID2_Mage_Frost_Spellslinger"` (nicht bloß `"MID2_Mage_Frost"`), während `MID2_Death_Knight_Unholy.simc` den Actor `"MID2_Death_Knight_Unholy_Rider"` enthält. D. h. **Hero-Talent-Build wird im Actor-Namen kodiert, nicht notwendigerweise im Dateinamen** — die separate Datei `MID2_Mage_Frost_Frostfire.simc` enthält vermutlich den Gegenbau (Frostfire statt Spellslinger). Für eine Pipeline: den Hero-Talent-Namen aus dem Actor-String parsen, nicht aus dem Dateinamen verlassen.

**2. Basis-Metadaten**
```
source=default
spec=frost
level=90
race=tauren
role=spell
position=ranged_back
```
- `source=default` — Herkunftsmarker (immer `default` in diesen generierten Dateien, kein Armory-Import).
- `spec=` snake_case Spec-Name.
- `level=90` — aktuelles Max-Level im Midnight-Beta-Build (nicht mehr 80).
- `race=` Rassenname (klein, ohne Leerzeichen: `tauren`, `dwarf`, `troll`, …) — pro Spec unterschiedlich gewählt (vermutlich beste verfügbare Racial-Kombo).
- `role=` SimC-Rolle (`spell`, `attack`, `tank`, `heal`…) — steuert u. a. Buff-Zuweisung.
- `position=` SimC-Positionsflag (`ranged_back`, `back`, `front`…) — beeinflusst z. B. Splash-/AoE-Verhalten in manchen Fight-Styles.

**3. Talente**
```
talents=CAEAAAAAAAAAAAAAAAAAAAAAAYGGLzMzsMmZmYmZGjZMziZmZmZMDEAAYmZmllZm2AAAAAAgNA2WGzMzAbzYmZYBAAgZ2AmBGwADD
omnium_talents=136822:1/136816:1/136817:1/136815:1/136814:1
```
- `talents=` ist der klassische Base64-artige SimC-Export-Talentstring (Talent-Baum-Loadout inkl. Klassen-, Spec- und Hero-Talent-Bäume in einem String).
- `omnium_talents=` ist **neu für Midnight** ("Omnium"-System, ein zusätzlicher Talent-/Progressionslayer außerhalb des klassischen Talentbaums). Format: entweder `<spell_id>:<rank>` Paare getrennt durch `/` (z. B. Mage: `136822:1/136816:1/136817:1/136815:1/136814:1`) **oder** bei manchen Klassen textuelle Rune-Namen getrennt durch `/` (z. B. Death Knight: `rune_of_unleashed_fire/rune_of_lynxlike_reflexes/rune_of_lingering/rune_of_masterful_cunning/rune_of_overload`, ohne `:1`-Rang-Suffix). Die Pipeline sollte beide Formen tolerieren (Regex `\w+(:\d+)?` je `/`-Segment).

**4. Consumables**
```
potion=potion_of_recklessness_2
flask=flask_of_the_shattered_sun_2
food=harandar_celebration
augmentation=void_touched_augment_rune
temporary_enchant=main_hand:thalassian_phoenix_oil_2
```
- `potion=`, `flask=`, `food=`, `augmentation=` jeweils ein SimC-Item-Slug, meist mit `_2`-Suffix (Rang/Qualitätsstufe des Midnight-Consumables).
- `temporary_enchant=<slot>:<enchant_slug>` — Slot-präfixiert (hier `main_hand:`), erlaubt mehrere Slots durch weitere `temporary_enchant=`-Zeilen oder `/`-Trennung bei mehreren Enchants am selben Slot (in den vier Beispielen nur je 1 Zeile).

**5. Action Priority List (APL)** — mehrzeilig, `actions[.<listname>][+]=<action>,<param>=<value>,...`, mit auto-generiertem Erklärkommentar-Block davor. Nicht Teil der "Datenformat"-Frage im engeren Sinn, aber relevant, falls die Pipeline auch APLs parsen soll: Struktur ist `actions=`, `actions.precombat=`, `actions.cds=`, `actions.<phase>=` usw., `+=` hängt an, reine `=` überschreibt/initialisiert die genannte Liste.

**6. Gear-Zeilen** (ein Slot pro Zeile)
```
head=crown_of_the_primal_leywarden,id=271564,bonus_id=13692/13698/13750/13846/13848,gem_id=240967,redirected_base_stats=271874
waist=martyrs_waistwrap,id=239649,bonus_id=8960/12384/13750/13751/13836/9627,gem_id=240890,crafted_stats=32/49
main_hand=janthrazet_the_soul_fang,id=271092,bonus_id=13662/13848,enchant_id=8689
```
Syntax: `<slot>=<item_slug>,<key>=<value>,...` (Item-Slug ist Pflichtfeld direkt nach `=`, danach beliebig viele `,key=value`-Paare).

**Vorkommende Slot-Namen** (bestätigt über die vier Beispieldateien): `head, neck, shoulders, back, chest, wrists, hands, waist, legs, feet, finger1, finger2, trinket1, trinket2, main_hand, off_hand`. Bestätigt identisch zur vom Nutzer vorgegebenen Liste; `off_hand` fehlt bei zweihändigen Builds (z. B. Warrior Arms und Hunter BM in den Beispielen haben keine `off_hand=`-Zeile, weil Zweihandwaffe/Bogen).

**Vorkommende Item-Attribute** (Vereinigung aller vier Dateien):

| Attribut | Bedeutung |
|---|---|
| `id=` | Numerische Item-ID (Wowhead/DBC) |
| `bonus_id=` | `/`-getrennte Liste von Bonus-IDs (Ilvl-Upgrade-Track, Sockel-Freischaltung, Versatile-Itemization-Varianten, Crafted-Qualitätsstufe etc.) |
| `gem_id=` | `/`-getrennte Liste von Sockelstein-IDs (Doppelsockel z. B. bei Hals: `240898/240898`) |
| `enchant_id=` | Verzauberungs-ID |
| `crafted_stats=` | Zwei `/`-getrennte Zahlen — die vom Crafter frei wählbaren sekundären Stat-Allokationen bei Player-Crafted-Gear (z. B. Schmiedekunst/Schneiderei mit Stat-Wahl); Reihenfolge/Bedeutung der beiden Zahlen nicht aus dem Profil selbst ableitbar, vermutlich `[primary_choice_amount, secondary_choice_amount]` oder Rating-Split zwischen zwei wählbaren Stats. |
| `redirected_base_stats=` | Item-ID, von der die Basis-Stats "umgeleitet" übernommen werden (Midnight-Mechanik für Set-/Recolor-Items, die Stats eines anderen Items erben — z. B. saisonale Recolors) |
| `ilevel=` | Explizites Override des Itemlevels (nur vereinzelt gesetzt, z. B. bei Hunter-BM-Trinkets/Rüstung: `ilevel=334`, `ilevel=344` — überschreibt das aus `id`+`bonus_id` abgeleitete Ilvl) |
| `content_tuning=` | Nur in der DK-Datei beobachtet — ID einer Content-Tuning-Tabelle (Skalierung nach Content-Typ, z. B. M+/Raid-Skalierungskurve) |

`ilevel=` kommt also **vor**, ist aber nicht in jeder Zeile gesetzt — nur dort, wo das abgeleitete Ilvl vom gewünschten Ziel-Ilvl abweicht bzw. bei bestimmten Slot-/Bonus-ID-Kombinationen ohne eindeutige Ilvl-Ableitung.

**7. `# Gear Summary`-Block** (Kommentarzeilen am Dateiende)
```
# Gear Summary
# gear_ilvl=338.00
# gear_stamina=40269
# gear_intellect=2393
# gear_crit_rating=1219
# gear_haste_rating=713
# gear_mastery_rating=1304
# gear_versatility_rating=123
# gear_armor=733
# set_bonus=midnight_season_2_2pc=1
# set_bonus=midnight_season_2_4pc=1
```
- Alles mit `#` auskommentiert → **von SimC nicht geparst**, reine von-SimC-nach-Sim-Lauf generierte Doku (SimC schreibt diese Zusammenfassung beim Speichern/Export selbst in die Datei).
- `gear_ilvl=` float mit zwei Nachkommastellen — durchschnittliches/effektives Itemlevel des gesamten Gearsets (**das** ist die Ilvl-Angabe der Datei; es gibt kein separates Top-Level-`ilevel=` fürs Gesamtprofil).
- `gear_<stat>=` Summen der jeweiligen Sekundär-/Primärstats aus allen Items (unverzaubert vs. verzaubert nicht unterscheidbar — post-enchant/-gem Summen).
- **`set_bonus=<name>_<n>pc=1`** ist die Art, wie Klassenset-Boni erkannt werden: eine Kommentarzeile pro aktivem Set-Bonus-Schwellenwert. Beispiele: `set_bonus=midnight_season_2_2pc=1`, `set_bonus=midnight_season_2_4pc=1` (Klassenset), zusätzlich bei Warrior/DK `set_bonus=bite_of_zuljan_2pc=1` (ein weiteres, Waffen-/Trinket-getriebenes Set außerhalb des klassischen Rüstungssets). Das eigentliche SimC-Set-Erkennungsverfahren selbst läuft über die `bonus_id`s der Gear-Zeilen (SimC matched intern gegen die DBC-Settabellen); der Kommentarblock ist nur die **von SimC exportierte Bestätigung**, welche Set-Boni aktiv sind — für eine Pipeline reicht es, diese Kommentarzeilen zu parsen, statt die Set-Zuordnung selbst aus `bonus_id` zu rekonstruieren.

**8. Mehrere Varianten pro Datei / `copy=`**
In allen vier abgerufenen Dateien **kein `copy=`** gefunden (`grep -rn "copy=" *.simc` → leer). Varianten (z. B. Spellslinger vs. Frostfire bei Mage, San'layn vs. Rider bei DK) liegen in **separaten Dateien** (`MID2_Mage_Frost.simc` vs. `MID2_Mage_Frost_Frostfire.simc`), nicht als `copy=`-Mehrfachprofile innerhalb einer Datei. Das SimC-`copy=`-Feature (mehrere Actors in einer Datei, zweiter Actor kopiert Basis und überschreibt Teile) wird in diesem Profil-Set demnach **nicht genutzt** — eine Pipeline, die pro Datei genau 1 Profil erwartet, ist für dieses Repo korrekt; ein generischer SimC-Parser sollte `copy=` trotzdem unterstützen, falls andere Quellen (Custom-Profile) es nutzen.

### B.3 Kein separates M+/Dungeon-Profilset

Weder `_DungeonSlice` noch `hecticaddcleave` noch ein `MythicPlus`/`M+`-Unterordner existiert im `profiles`-Baum. Alle Profile sind raid-fokussiert (`optimal_raid=1` in der `_Raid.simc`-Sammeldatei). Fight-Style-Variationen (inkl. `hecticaddcleave`, das bloodmallet für andere Charts nutzt) werden bei Bedarf **beim Simc-Aufruf** über `fight_style=` gesetzt, nicht über eigene Profildateien.

### B.4 Lizenz

- Root-`LICENSE` des Repos: **GNU GPL v3**. Es gibt keine gesonderte `LICENSE`-Datei unter `profiles/` (404 bei `profiles/LICENSE`) — die Profile fallen damit unter dieselbe Repo-weite GPLv3 wie der Code, sofern nichts anderes vermerkt ist.
- Weitere `LICENSE.*`-Dateien im Root (`LICENSE.BOOST`, `LICENSE.BSD`, `LICENSE.BSD2`, `LICENSE.LGPL`, `LICENSE.MIT`, `LICENSE.UNLICENSE`) betreffen laut `README.md` ausschließlich gebündelte Drittbibliotheken (z. B. `dbc_extract3`, `fmtlib`, einzelne Utility-Header) — **nicht** die `profiles/`-Verzeichnisse.
- **Keine explizite Aussage im Repo gefunden**, dass die Profildateien als "Daten" (nicht Code) gesondert lizenziert/ausgenommen wären. Für die Pipeline bedeutet das: konservativ von GPLv3-Copyleft für die Profildateien ausgehen, falls diese redistribuiert (nicht nur intern konsumiert) werden sollen — ggf. Rücksprache mit den SimC-Maintainern falls das für den Anwendungsfall relevant wird.

---

## Zusammenfassung für die Pipeline-Implementierung

1. **bloodmallet-Client**: HTTP 200 ist kein Erfolgsindikator — immer `body.status != "error"` bzw. Vorhandensein von `"data"` prüfen. Distribution-Key strikt als `crit_haste_mastery_versatility` parsen (`re.match(r"(\d+)_(\d+)_(\d+)_(\d+)", key)`). Top-Ergebnis über `sorted_data_keys[tier][0]`, nicht über Max-Suche im `data`-Dict (spart O(n log n), Reihenfolge ist bereits fertig). `secondary_sum` mitziehen, falls reale Rating-Werte zurückgerechnet werden sollen.
2. **SimC-Profil-Parser**: zeilenweises `key=value[,subkey=value...]`-Format, Slotnamen fix enumerierbar (16 Slots, `off_hand` optional bei 2H). Set-Boni am einfachsten aus dem `# set_bonus=...=1`-Kommentarblock am Dateiende extrahieren statt aus `bonus_id`-Matching selbst zu rekonstruieren. Hero-Talent-/Build-Namen aus dem Actor-Anzeigenamen (`<class>="..."`-Zeile) lesen, nicht aus dem Dateinamen. `omnium_talents=` Format ist klassenabhängig (numerisch mit `:rank` oder textuelle Rune-Namen) — beide Formen im Parser vorsehen.

---

## Anhang: gespeicherte Rohdateien (`fixtures/`)

- `sd_mage_frost.json`, `sd_warrior_arms.json`, `sd_dk_unholy.json`, `sd_hunter_bm.json` — die vier `secondary_distributions`-Charts, `castingpatchwerk`.
- `MID2_Mage_Frost.simc`, `MID2_Warrior_Arms.simc`, `MID2_Death_Knight_Unholy.simc`, `MID2_Hunter_Beast_Mastery.simc` — die vier angeforderten SimC-Profile.
- (im übergeordneten Scratchpad-Ordner zusätzlich: `secondary_distribution_simulator.py` — bloodytools-Quelltext, als Beleg für die Feldreihenfolge, kein Fixture im engeren Sinn.)
