# MetaMirror-Datenpipeline (Teilsystem 2) — Design

**Ziel:** Ein automatisierter Job berechnet aus der offiziellen Warcraft-Logs-API die aktuelle Top-Spieler-Meta pro Spec und schreibt sie als Lua-Datentabelle ins Addon — ersetzt den erfundenen `Data/SampleData.lua` durch echte Daten.

**Architektur:** Python-Pipeline auf GitHub Actions (wöchentlicher Cron). Client-Credentials-OAuth gegen die WCL-v2-GraphQL-API. Pro Spec × Content werden Top-Parses gezogen, deren `CombatantInfo` (Gear/Sockel/Verzauberung/Talente/Werte) und Buff-Auren (Verbrauchsgüter) aggregiert, in eine Lua-Tabelle serialisiert, von einem Wächter validiert und — bei grün — automatisch nach master committet und (später, gated) zu CurseForge hochgeladen.

**Tech Stack:** Python 3.12 (`httpx` für GraphQL/HTTP), GitHub Actions, Lua-Serializer (eigen), bestehendes Addon (Lua 5.1, Interface 120100).

---

## 1. Kontext & Abgrenzung

Teilsystem 1 (Addon, v0.2) ist fertig und liest den Datenvertrag `MetaMirrorData.specs[class][spec][content]`. Diese Pipeline erzeugt genau diesen Vertrag aus echten Daten. Das Addon-UI bleibt unverändert — **mit einer Ausnahme** (Abschnitt 9: klickbare Verbrauchsgüter).

**Warum diese Quelle:** Es gibt keinen fertigen Archon-Endpoint für Stat-Verteilungen; Scraping ist per RPGLogs-ToS verboten. Die offizielle WCL-v2-API liefert über `CombatantInfo`-Events die nötigen Rohdaten (Gear, Werte, Talente) legal und wartbar. Wir aggregieren die Meta selbst.

## 2. Datenvertrag (unverändert)

Ausgabe ist `Data/MetaMirrorData.lua` im bestehenden Format:

```
MetaMirrorData.specs[classID][specID][content] = {
    sampleSize = <int>,
    stats       = { {key="haste"|"crit"|"mastery"|"vers", pct=<float>}, ... },
    talents     = { {importString=<string>, usagePct=<int>}, ... },
    gear        = { {slot=<SLOT>, itemID=<int>, name=<string>}, ... },
    gems        = { {slot=<SLOT>, itemID=<int>, name=<string>}, ... },
    enchants    = { {slot=<SLOT>, id=<int>,     name=<string>}, ... },
    consumables = { flask=<itemID>, phial=<itemID>, potion=<itemID>,
                    food=<itemID>, oil=<itemID>, rune=<itemID> },
}
```
- `content` ∈ {`mythicplus`, `raid`}.
- `consumables` speichert **itemIDs** (nicht Spell-IDs/Namen) — Voraussetzung für die klickbaren Links (Abschnitt 9). Schlüssel gegenüber SampleData erweitert um `phial` und `oil`; nicht belegte Slots werden weggelassen.
- Top-Level: `version = "wcl-<ISO-Datum>"`, plus `attribution = "Data from Warcraft Logs"` und `season = <string>`.

## 3. Komponenten (Dateien)

```
pipeline/
  specs.py         # 40 Spec-Definitionen: classID, specID, Klassenname,
                   #   WCL-Encounter/Zone-IDs für Raid + M+-Dungeon-Set der Season
  wcl.py           # OAuth-Token + GraphQL-Client (Rate-Limit-aware, Retry/Backoff)
  fetch.py         # Rankings -> Report/FightIDs -> CombatantInfo + Buff-Auren
  aggregate.py     # Median-Werte, häufigste Talente/Gear/Gems/Enchants/Consumables
  emit_lua.py      # Serialisiert das Vertragsformat nach Data/MetaMirrorData.lua
  validate.py      # Wächter: bricht bei faulen Daten ohne Commit ab
  run.py           # Orchestrator; CLI (--specs, --content, --dry-run)
  requirements.txt
.github/workflows/update-data.yml   # Cron + Secrets + Commit/Upload
Data/MetaMirrorData.lua             # generiert; ersetzt SampleData.lua
```
`SampleData.lua` wird entfernt, `MetaMirror.toc` auf die neue Datei umgestellt.

## 4. Datenfluss

1. **Auth:** `wcl.py` holt via Client-Credentials einen Bearer-Token für `/api/v2/client`.
2. **Rankings:** pro Spec × Content die Top ~50 Parses der höchsten Stufe (M+: höchste Keys der Season; Raid: Mythic) → liefert `reportCode` + `fightID` + `sourceID`.
3. **Detaildaten:** pro Parse `CombatantInfo`-Event des Spielers → Gear (itemIDs, Sockel, Verzauberungen), Talent-Loadout-String, Sekundär-Ratings. Zusätzlich Buff-Auren des Kampfes → getragene Verbrauchsgüter (Flask/Phiole/Food/Pott/Öl/Rune) als itemIDs.
4. **Aggregation:** `aggregate.py` bildet pro Spec × Content die Meta (Abschnitt 6).
5. **Serialisierung:** `emit_lua.py` schreibt `Data/MetaMirrorData.lua`.
6. **Validierung:** `validate.py` prüft die frische Datei; Fehler → Exit ≠ 0, kein Commit.
7. **Auslieferung:** Workflow committet bei grün nach master und (gated) lädt zu CurseForge hoch.

## 5. WCL-API-Abfragen (konkret)

- **Rankings:** `worldData`/`characterRankings` bzw. `encounterRankings(encounterID, difficulty, className, specName, page)` — liefert Report-Code + FightID pro Ranglisten-Eintrag.
- **CombatantInfo:**
  ```graphql
  { reportData { report(code:$code) {
      events(dataType: CombatantInfo, startTime:$s, endTime:$e, sourceID:$src) { data }
  } } }
  ```
  Das `data`-JSON je Spieler enthält `gear[]` (id, itemLevel, gems[], permanentEnchant), `talentTree`/`talents`, und die Sekundär-Ratings.
- **Verbrauchsgüter:** Buff-Auren über eine `Buffs`-Tabelle bzw. `events(dataType: Combatant/Buffs)` des Kampfes; Consumable-Auren werden per Whitelist (Season-Consumable-Spell→itemID-Map in `specs.py`) erkannt.

## 6. Aggregationslogik

Pro Spec × Content:
- **stats:** Median der vier Sekundär-Ratings über alle Parses → in `pct` (analog Addon-Anzeige). Reihenfolge absteigend nach pct.
- **talents:** häufigster Loadout-Import-String + dessen `usagePct` (Anteil der Parses). Optional zweithäufigster.
- **gear:** je Slot das häufigste itemID (+ Name via Item-Auflösung); Slots mit zu dünnem Signal weglassen.
- **gems/enchants:** häufigstes itemID/enchantID je relevantem Slot.
- **consumables:** häufigstes itemID je Kategorie (flask/phial/potion/food/oil/rune).
- **sampleSize:** Zahl tatsächlich verwerteter Parses.

## 7. Validierungs-Wächter (`validate.py`)

Bricht **ohne Commit** ab (Exit ≠ 0), wenn:
- eine erwartete Spec/Content-Kombination fehlt oder `sampleSize` unter Schwelle (z. B. < 15) liegt;
- die vier `stats.pct` nicht plausibel sind (jede 0–100, Summe grob im erwarteten Rahmen);
- `gear`/`gems` itemIDs = 0 oder leer, wo Daten erwartet werden;
- die Datei nicht als valides Lua parst (Syntax-Check via `luac`/Lua-Parser im CI).

## 8. Auslieferung & Governance (voll automatisch)

- Wächter grün → Workflow committet `Data/MetaMirrorData.lua` nach master (`chore(data): weekly meta refresh <Datum>`).
- Danach **CurseForge-Upload** einer neuen Addon-Version. Diese Stufe ist **vollständig implementiert, aber per Repo-Variable `CF_PUBLISH=false` deaktiviert**, bis (a) der ToS-Bündel-Gate geklärt und (b) Projekt-ID + `CURSEFORGE_TOKEN` vorhanden sind. Umlegen der Variable aktiviert den Auto-Release.
- Wächter rot → Job schlägt fehl, master bleibt unberührt, GitHub meldet den fehlgeschlagenen Lauf.

## 9. Addon-Änderung: klickbare Verbrauchsgüter

Im Addon werden Verbrauchsgüter als **interaktive Item-Links** gerendert (bislang Klartext/itemID):
- Aus `itemID` zur Laufzeit Name/Icon/Link auflösen (`C_Item.GetItemInfo`/`GetItemInfoInstant`; asynchron via `Item:CreateFromItemID`+`ContinueOnItemLoad`, da Namen evtl. erst nachladen).
- Hover: `GameTooltip:SetOwner(...)` + `GameTooltip:SetItemByID(itemID)`.
- Klick: `SetItemRef(link, text, button, self)` — repliziert Blizzard-Standard: normaler Klick zeigt den Link, **Shift-Linksklick verlinkt in den aktiven Chat und schreibt bei offenem Auktionshaus den Namen in die AH-Suchleiste**. (`HandleModifiedItemClick(link)` als Fallback für die Modifier-Fälle.)
- Bleibt in der grünen 12.x-Zone: eigene statische Daten, keine secret values.
- Derselbe Mechanismus ist später trivial auf gems/enchants/gear ausweitbar (nicht in diesem Umfang).

## 10. Rate-Limit-Strategie

WCL rechnet in Points/Stunde. Grobschätzung: 40 Specs × 2 Content × ~50 Parses ≈ 4000 Parses, je ~2 Detail-Abfragen. Maßnahmen:
- Rankings-Abfragen batchen (mehrere Einträge pro Query).
- Bei HTTP 429 / Points-Erschöpfung: exponentielles Backoff, Lauf darf lange laufen bzw. pro Lauf nur eine rotierende Teilmenge der Specs auffrischen (Rest aus vorherigem Stand). `run.py --specs` steuert das.
- Ergebnisse pro Spec zwischenspeichern, damit ein abgebrochener Lauf wiederaufnehmbar ist.

## 11. Sicherheit

- `WCL_CLIENT_ID`/`WCL_CLIENT_SECRET` (später `CURSEFORGE_TOKEN`) ausschließlich als GitHub-Secrets. Nie im Repo, nie im Log ausgeben.
- Der Workflow läuft nur im MetaMirror-Repo (nicht in Forks/PRs Dritter → Secrets nicht exponiert).

## 12. Rechtliches (Vor-Release-Gate)

- **Offen:** Dürfen die *abgeleiteten* Aggregatdaten in ein verteiltes Addon gebündelt werden? Vor öffentlichem CurseForge-Release klären (RPGLogs-API-ToS). Blockiert das Bauen/Testen nicht, nur `CF_PUBLISH=true`.
- **Attribution:** ToS verlangt Quellenangabe. „Data from Warcraft Logs" sichtbar im Addon (Panel-Fußzeile) + in der Datentabelle (`attribution`).

## 13. Testing

- Reine Python-Unit-Tests für `aggregate.py` (Median/Häufigkeit auf Fixtures) und `emit_lua.py` (Serializer-Roundtrip → gültiges Lua) und `validate.py` (fängt bekannte Fehlerbilder).
- Fixtures aus anonymisierten CombatantInfo-Beispielen; kein Live-API-Call im Test.
- `luac -p` im CI als Syntax-Gate der generierten Datei.
- Bestehender Addon-Selbsttest (`SelfTest.lua`) bleibt grün gegen das unveränderte Vertragsformat.

## 14. Bewusst NICHT dabei (YAGNI)

- Weitere Quellen (Wowhead etc.) — später via Provider-Muster nachrüstbar.
- Live-API-Abruf im Spiel; PvP; Rotation/Prosa; Spec-Browser.
- Klickbare Links für gems/enchants/gear (nur Verbrauchsgüter in diesem Umfang).

## 15. Offene Punkte / Voraussetzungen

- **Nur der Nutzer:** WCL-API-Client anlegen (`https://www.warcraftlogs.com/api/clients/`) → `client_id`/`client_secret`; MetaMirror-Repo auf GitHub pushen; beide Secrets dort hinterlegen.
- Season-abhängige IDs (Raid-Encounter, M+-Dungeon-Set, Consumable-Whitelist) in `specs.py` pflegen — der Punkt, den du „ein paar Mal im Monat" prüfst.
- CurseForge-Projekt + Token erst nach ToS-Klärung.
