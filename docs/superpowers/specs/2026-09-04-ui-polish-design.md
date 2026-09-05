# UI-Politur nach dem Sim-Umstieg — Design

**Stand:** 2026-09-04, Branch `feature/ui-polish`, Basis `main` (`3da6768`).

## Ziel

Drei kleine, sichtbare Verbesserungen, die mit den vorhandenen Sim-Referenzdaten
(`Data/MetaMirrorData.lua`, `Data/MetaMirrorTrinkets.lua`) auskommen — kein neuer
Datenvertrag, keine Laufzeit-Netzzugriffe:

1. **Datenstand in allen Tabs.** Die Zeile „Sim-Referenz · 3 Ziele · 2026-09-04" steht
   bisher nur im Stats-Tab (unten im Body). Sie wandert in die Kopfzeile rechts neben die
   Spec-Zeile, direkt unter den M+/Raid-Schalter — dort ist sie in jedem Tab sichtbar und
   steht semantisch beim Schalter, der den Fight-Style bestimmt. Im Schmuck-Tab zeigt sie
   den Trinket-Datensatz (Einzelziel, Datum aus `MetaMirrorTrinkets.version`).
2. **Ampel im Ausrüstungs-Tab.** Statt nur „grün = im Besitz": vier Zustände je Zeile —
   grün *angelegt* (auf Referenzstufe), gelb *angelegt, aber schwächer* (niedrigere
   Gegenstandsstufe als die Referenz auf Mythos 6/6), blau *im Beutel*, rot (gedämpft)
   *fehlt*. Farbstreifen links + Schimmer wie bisher; der Klartext steht im Tooltip der
   Zeile. Nebenbei: Panel 24 px höher, damit 16 Gear-Zeilen nicht mehr in die Fußzeile
   ragen.
3. **BiS-Hinweis im Item-Tooltip.** Beim Hovern über ein Item — Loot-Fenster, Beutel,
   Chat-Link, Händler — hängt das Addon Zeilen an: „MetaMirror: BiS für Frost (M+ · Raid)",
   „MetaMirror: S-Tier-Schmuck für Feuer (Raid)". Für **alle Specs der eigenen Klasse**
   (Offspec-Loot!), aktuelle Spec zuerst. `/mm tooltip` schaltet es ab/an.

Dazu Aufräumen: die toten WCL-Reste im Schmuck-Tab (`wclTrinkets`, `rankTier`,
`hybridList`) fliegen raus — `MetaMirrorData.trinkets` existiert nicht mehr, die Sicht ist
immer die Sim-Rangliste.

## Architektur

- Reine Logik in testbaren Funktionen ohne WoW-Frames: `MetaMirror:DataStamp(...)`
  (Logic.lua), `MetaMirror:GearStatus(...)` (neu: GearStatus.lua),
  `MetaMirror:BuildTooltipIndex(...)` + `MetaMirror:TooltipLinesForIndex(...)`
  (neu: Tooltip.lua). Alle nehmen ihre Daten als Parameter (Default = Globals), damit
  SelfTest.lua sie mit Fake-Tabellen prüft — headless über `tests/run_harness.lua`
  **und** ingame über `/mm`-SelfTest.
- UI.lua bindet nur an: Kopfzeilen-FontString, Farbzustand der Gear-Zeilen,
  Tooltip-Zeile im Row-OnEnter. `TooltipDataProcessor.AddTooltipPostCall` (10.0.2+)
  hängt die BiS-Zeilen an jedes Item-Tooltip.
- Secret values (Patch 12.0): Gegenstandsstufen der eigenen Ausrüstung werden per
  `pcall` + Arithmetik-Test gelesen; im Zweifel „0 = unbekannt" → nie „schwächer".

## Nicht-Ziele

Keine Ampel im Verbesserungen-Tab (Verzauberung angelegt?), keine Legende im Body,
keine Battle.net-Daten, keine Versionserhöhung (kommt beim Release).

## Tests

- `tests/run_harness.lua` lädt zusätzlich GearStatus.lua und Tooltip.lua; Ergebnis muss
  `HARNESS: ALLE PASS` bleiben.
- Neue SelfTests: DataStamp (3), GearStatus (6), Tooltip-Index/-Zeilen (4).
- `luac -p` auf allen Lua-Dateien.
- Ingame-Abnahme durch den Nutzer: Kopfzeile in allen vier Tabs, Gear-Ampel mit einem
  angelegten BiS-Teil, Tooltip an einem Beutel-Item und einem Chat-Link.
