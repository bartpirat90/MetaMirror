# MetaMirror — Design-Spec

**Datum:** 2026-08-31
**Status:** Design zur Nutzer-Abnahme
**Typ:** Neues WoW-Addon (Retail / Patch 12.1 „Midnight") + begleitende Daten-Pipeline

## Ziel

Ein In-Game-Nachschlagewerk, das pro Spec die **aktuelle Top-Spieler-Meta** zeigt (Sekundärstat-Verteilung, Talent-Builds, BiS-Gear, Steine/Verzauberungen, Verbrauchsgüter) für **Mythisch+ und Raid** — und die **eigenen Sekundärwerte des Charakters live dagegen vergleicht**, sodass man auf einen Blick sieht, wovon man wie viel zu wenig oder zu viel hat. Die Daten stammen aus der **Archon-API** (empirisch, aus Warcraft-Logs aggregiert) und werden über eine Pipeline ins Addon gebündelt (WoW-Addons haben kein Live-Internet).

## Kernentscheidungen (aus dem Brainstorming)

- **Datenstrategie:** Hybrid mit Schwerpunkt **empirische Meta-Daten über die offizielle Archon-API**; kein fragiler HTML-Scrape.
- **Abdeckung:** alle 40 Specs; Inhalte **Mythisch+ und Raid** (kein PvP).
- **Inhalte:** Stat-Verteilung, BiS/Gear, Talent-Builds, Steine & Verzauberungen, Verbrauchsgüter. **Keine** Rotation/Prosa.
- **Alleinstellungsmerkmal:** Live-Vergleich der eigenen Sekundärwerte gegen die Meta-Zielwerte.
- **UI:** Tab-Panel (Layout B), das sich an den Charakter-Rahmen hängt.
- **Name:** MetaMirror (Namespace `MetaMirror`, Ordner `MetaMirror`).

## Architektur: zwei Teilsysteme + Datenvertrag

Bewusst getrennt. Die **Datentabelle ist der Vertrag** zwischen beiden; das Addon wird zuerst gegen einen kleinen Beispiel-Datensatz gebaut, die Pipeline füllt später denselben Vertrag.

### Datenvertrag (generierte Lua-Tabelle)

Die Pipeline erzeugt eine gebündelte Datei (z. B. `Data/MetaMirrorData.lua`) mit genau dieser Struktur, die das Addon liest:

```lua
MetaMirrorData = {
    version = "2026-08-31",              -- Snapshot-Datum der Daten
    specs = {
        [classID] = {                    -- Blizzard classID (1..13)
            [specID] = {                 -- Blizzard specID
                mythicplus = <specContent>,
                raid       = <specContent>,
            },
        },
    },
}

-- <specContent>:
{
    sampleSize  = 100,                   -- Anzahl aggregierter Top-Logs
    stats = {                            -- geordnet; nur Sekundärstats
        { key = "haste",   pct = 34.0 }, -- Zielwert in % (Median Top-Spieler)
        { key = "crit",    pct = 28.0 },
        { key = "mastery", pct = 22.0 },
        { key = "vers",    pct = 16.0 },
    },
    talents = {
        { importString = "…", usagePct = 68 },  -- beliebtestes Loadout (1..n)
    },
    gear = {                             -- meistgetragenes / BiS pro Slot
        { slot = "HEAD", itemID = 0, name = "…" },
        -- … alle relevanten Slots
    },
    gems     = { { slot = "…", itemID = 0, name = "…" } },
    enchants = { { slot = "…", id = 0, name = "…" } },
    consumables = { flask = 0, potion = 0, food = 0, rune = 0 },  -- itemIDs, 0 = keins
}
```

Grundsätze: **Defaults für fehlende Felder** (nie `nil`-Zugriffe im Addon), abwärtskompatibel erweiterbar, alle IDs numerisch.

### Teilsystem 1 — Das Addon (`MetaMirror`, zuerst gebaut)

Gebaut gegen einen kleinen, von Hand angelegten Beispiel-Datensatz (2–3 Specs), damit das UI ohne Pipeline vollständig testbar ist. Ein Ordner, mehrere fokussierte Lua-Dateien:

- **Lokalisierung** — EN-Basis + `deDE`-Override via `GetLocale()` (Muster wie KeyRoulette/AutoRole).
- **Datenzugriff** — dünne Schicht, die `MetaMirrorData` liest und je `class/spec/content` den `<specContent>` liefert; fehlt ein Eintrag → sauberer „keine Daten"-Zustand.
- **Spieler-Status (rein + live getrennt):**
  - Aktuelle Spec/Klasse erkennen (`GetSpecialization`, `UnitClass`).
  - Eigene Sekundärwerte lesen: **Prozent** via `GetHaste()`, `GetCritChance()`, `GetMasteryEffect()`, `GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE)`; **Wertung (absolut)** via `GetCombatRating(CR_HASTE_*/CR_CRIT_*/CR_MASTERY/CR_VERSATILITY_*)`.
  - **Grüne-Zone-Bestätigung:** Das sind ausschließlich **eigene** Charakterwerte — **keine „secret values"** (die betreffen nur *fremde* Einheiten in Instanzen). Kein Combat-Log, keine geschützten Funktionen. Unkritisch unter Patch 12.1.
  - **Reine Vergleichslogik** (testbar, injizierbar): aus Ist-% + Ziel-% den Status je Stat bestimmen (`under` / `on` / `over`, mit Toleranzband) und die **Ziel-Wertung** aus dem Ist-Verhältnis `rating/pct` hochrechnen.
- **UI (Layout B):**
  - Rahmen mit **Tab-Leiste**: Stats · Talente · Gear · Steine/Ench. · Verbrauch.
  - **Spec-Kopf** (auto-erkannt), **M+/Raid-Umschalter**.
  - *Stats-Tab:* je Stat Balken (Füllung = Ist), **eingefärbt nach Status** (grün = im Ziel, gelb = zu wenig, blau = zu viel), goldener Ziel-Strich, Status-Chip (z. B. „+6% fehlen"), Zahlen als **Prozent + Absolutwert** (`28% (8.420) · Ziel 34% (10.230)`).
  - *Talente:* beliebtester Build als **Import-String in einer selektierbaren EditBox** zum Kopieren + Nutzungsquote.
  - *Gear:* BiS-/meistgetragene Liste pro Slot (Item-Namen, Tooltip beim Überfahren).
  - *Steine/Ench.:* Empfehlung pro relevantem Slot. *Verbrauch:* Fläschchen/Kampftrank/Food (+ ggf. Rune).
- **Andocken an den Charakterbildschirm:** `CharacterFrame:HookScript("OnShow", …)`/`OnHide` blendet MetaMirror **automatisch neben dem Blizzard-Fenster** ein/aus (Taste **C**). Position rechts angedockt, per Drag verschiebbar; Ankerwahl in SavedVars.
- **Bedienung zusätzlich:** Slash `/mm` (und `/metamirror`) zum manuellen Öffnen/Schließen. **Kein Minimap-Button** (das Auto-Einblenden ersetzt ihn).
- **SavedVars** (`MetaMirrorDB`, pro Charakter): letzter M+/Raid-Zustand, aktiver Tab, Panel-Position/Anker, Toleranzband.
- **Selbsttest-Harness** (`/run MetaMirror:RunSelfTest()`) für die reine Logik (Statusbestimmung, Ziel-Wertung-Hochrechnung, Datenzugriff mit/ohne Eintrag).

### Teilsystem 2 — Die Daten-Pipeline (danach gebaut)

Läuft außerhalb des Spiels auf **GitHub Actions (Cron)**, kein eigener Server:

1. **Holen** — Archon-API (Client-Credentials-Flow, nur öffentliche Daten) je `spec × content`: Stat-Verteilung, beliebteste Talente, meistgetragenes Gear, Steine/Verzauberungen. Verbrauchsgüter ggf. kleine gepflegte Zuordnung.
2. **Transformieren** — Ergebnis in die Lua-Datentabelle (den Vertrag) schreiben.
3. **Validierungs-Wächter** — vor dem Schreiben prüfen: pro Spec/Content Stat-Summe plausibel, Talent-String nicht leer, Gear-Slots vollständig, Werte in Bereichen. Bei Verletzung: **kein Commit + lauter Fehler** (rote GitHub-Mail). Wandelt stillen Bruch in ein sichtbares Signal → passt zur gewünschten „paar Mal im Monat"-Pflege.
4. **Ausliefern** — Datendatei committen → Addon-Version schnüren → per CurseForge-Upload-API hochladen → Auto-Update beim Nutzer.

„Immer aktuell" bedeutet damit „aktuell zum letzten Release"; bei wöchentlicher (oder häufigerer) Pipeline-Ausführung + Auto-Update praktisch stets frisch.

## Rechtliches Gate (vor öffentlicher Veröffentlichung)

Vor einem **öffentlichen** Release verbindlich die **RPGLogs-/Archon-API-Nutzungsbedingungen** prüfen: Darf man die aggregierten Daten in ein verteiltes Addon **bündeln/cachen**? Ist **Attribution** verpflichtend? Gibt es Limits? Für **Eigengebrauch/Entwicklung** unkritisch. Ergebnis entscheidet, ob/wie veröffentlicht wird; bis dahin bleibt die Pipeline auf privaten Gebrauch beschränkt.

## Bau-Reihenfolge (Decomposition)

1. **Addon gegen Beispiel-Daten** — vollständiges, getestetes UI inkl. Live-Stat-Vergleich, Charakter-Andockung, Lokalisierung. Eigener Spec→Plan→Umsetzung-Zyklus (dieser Spec deckt es ab; Plan zuerst hierfür).
2. **Pipeline** — sobald der Datenvertrag durch das Addon fixiert ist. Eigener Plan; beginnt mit dem ToS-Check als erstem Schritt.

## Testbarkeit

- **Reine Logik (Selbsttest):** Statusbestimmung `under/on/over` inkl. Toleranz; Ziel-Wertung-Hochrechnung; Datenzugriff mit/ohne Eintrag; Lokalisierungs-Fallback.
- **In-Game:** Charakterbildschirm öffnen → Panel erscheint daneben; Spec-Wechsel wird erkannt; Stat-Balken färben korrekt (Werte künstlich verändern via Ausrüstungswechsel); M+/Raid schaltet Datensatz um; Einstellungen überstehen `/reload`.
- **Pipeline:** Validierungs-Wächter mit absichtlich kaputtem API-Beispiel testen (muss abbrechen, nicht committen).

## Bewusst nicht enthalten (YAGNI)

Keine Rotation/Prosa, kein PvP, kein Live-Netzwerk im Spiel, kein Wowhead-/HTML-Scrape, kein Minimap-Button, kein spec-übergreifender Browser im ersten Wurf (aktuelle Spec genügt; optionaler Spec-Wähler später möglich, da die Pipeline ohnehin alle Specs liefert).

## Offene Detailpunkte (in der Umsetzung zu klären)

- Exakte Archon-API-Endpunkte/Felder (Doku hinter Bot-Sperre; beim Pipeline-Bau mit gültigen Credentials verifizieren).
- Form der Talent-Übernahme: selektierbare EditBox zum Kopieren vs. Blizzard-Import-Dialog (Schutzstatus prüfen).
- Genaue Slot-Liste für Gear/Steine/Verzauberungen in 12.1.
- Ableitung der Steine/Verzauberungen aus dem aggregierten Gear vs. separate Quelle.
