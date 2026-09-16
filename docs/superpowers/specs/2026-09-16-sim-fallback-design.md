# Fallback auf alte Sim-Zahlen mit Altersangabe

**Stand 2026-09-16.** Design abgenommen, Umsetzung noch offen.

## Anlass

Im Wochenlauf vom 2026-09-07 lieferte die Quelle für Fury Warrior und Frost Mage
keine Raid-Daten. Die Pipeline schreibt nur, was sie bekommt, also fielen beide
Einträge weg und das Addon zeigte eine Woche lang „keine Daten" — obwohl die
Zahlen der Vorwoche noch dagestanden hätten. Eine Woche später waren sie zurück.
Siehe `CHANGELOG.md`, 1.0.1.

Die bisherige Regel lautete „lieber kein Wert als ein veralteter". Sie wird
umgekehrt: alte Werte bleiben stehen, aber das Addon sagt, wie alt sie sind.

## Entscheidungen

| Frage | Entscheidung |
| --- | --- |
| Verfall | Nach **28 Tagen**. Danach wieder der „keine Daten"-Hinweis. |
| Hinweis im Spiel | Die vorhandene Kopfzeile trägt das **echte Datum des Eintrags** plus Kennzeichnung. Kein neues UI-Element. |
| Herkunft der alten Werte | Die **bestehende `Data/MetaMirrorData.lua`** wird gelesen. |

Verworfen: ein zusätzlich mitversionierter JSON-Schnappschuss (zwei Kopien
derselben Daten, die auseinanderlaufen können) und ein Fallback über
`SavedVariables` im Addon (hinge davon ab, ob dieser eine Spieler die Version mit
den Daten je installiert hatte — Referenzdaten gehören nicht in den
Charakterspeicher).

Der Roh-Cache unter `pipeline/cache/` scheidet als Quelle aus: er ist gitignored,
und der CI-Runner startet jeden Lauf mit einem frischen Checkout.

## Datenformat

Neues **optionales** Feld je Spec/Content-Eintrag:

```lua
mythicplus = {
    asOf = "2026-09-07",   -- nur bei uebernommenen Eintraegen
    sampleSize = 1,
    stats = { ... },
```

Gesetzt wird es ausschließlich bei übernommenen Einträgen. Fehlt es, stammt der
Eintrag aus dem Lauf selbst und es gilt weiterhin das globale `generated`. Damit
bleiben ältere Datendateien ohne `asOf` unverändert lauffähig — dasselbe Muster,
mit dem schon `castingpatchwerk3` weiterhin ein lesbares Label bekommt
(`Logic.lua`).

## Pipeline

**Neu: `pipeline/read_lua.py`** — liest das von `emit_lua()` erzeugte Format
zurück nach `(specs, meta)`. Das Format ist vollständig selbst erzeugt und
regelmäßig; der Parser deckt nur dieses Format ab, nicht Lua allgemein.

**Geändert: `build()` in `pipeline/build_sim.py`** bekommt einen Parameter
`previous` (Vorgängerstand oder `None`), so wie die Fetch-Funktionen heute schon
injiziert werden. Im Skip-Zweig (`build_sim.py:90`):

1. Gibt es im Vorgängerstand einen Eintrag für diese Spec und diesen Inhalt?
2. Dessen Alter ist sein `asOf`, ersatzweise das `generated` des Vorgängerstands.
3. Alter ≤ `CARRY_OVER_MAX_DAYS` (28) → Eintrag übernehmen und `asOf` auf dieses
   Datum setzen.
4. Sonst → weglassen wie bisher.

Übernahmen werden geloggt (`uebernommen: Warrior/Fury/raid, Stand 2026-09-07,
7 Tage alt`) und in `meta["carriedOver"]` gesammelt. `validate()` prüft
übernommene Einträge wie frische — ein übernommener Eintrag, der die Validierung
nicht besteht, macht den Lauf rot.

Ein übernommener Eintrag zählt **nicht** als „Spec mit Daten" für `min_specs`:
die Abbruchschwelle soll weiter greifen, wenn die Quelle grundsätzlich ausfällt,
statt vom Vorgängerstand aufgefangen zu werden.

## Addon

`MetaMirror:DataStamp(tab, content, root, troot)` bekommt die `specID` dazu. Der
Aufrufer in `UI.lua:340` hat sie zwei Zeilen darüber bereits zur Hand.

- Eintrag hat `asOf` → dessen Datum in der Kopfzeile, dazu die Kennzeichnung.
- Kein `asOf` → unverändert `root.generated`.

Neuer Textbaustein in `Localization.lua`, englisch und deutsch, nach dem Muster
von `L.sim_note`. Die Kennzeichnung benennt den Sachverhalt, statt nur ein Datum
zu zeigen — sonst liest sich die Zeile wie ein normaler, nur älterer Datenstand.

## Tests

**Pipeline** (`pipeline/tests/`):

- Round-Trip: `parse(emit_lua(x)) == x`. Bindet den Parser an den Emitter, sodass
  eine Änderung am Emitter den Parser sichtbar bricht statt still.
- Eintrag fehlt, Vorgänger 7 Tage alt → übernommen, `asOf` gesetzt.
- Eintrag fehlt, Vorgänger 29 Tage alt → nicht übernommen.
- Eintrag fehlt, kein Vorgänger → nicht übernommen.
- Eintrag frisch → kein `asOf`.

**Addon** (`SelfTest.lua`, läuft über `tests/run_harness.lua`):

- `DataStamp` mit `asOf` → altes Datum und Kennzeichnung.
- `DataStamp` ohne `asOf` → unverändertes Verhalten (die bestehenden Tests decken
  das ab und müssen grün bleiben).

## Doku

`CHANGELOG.md`, Abschnitt „Notes on the data", sagt heute: *Specs the source has
no current profile for show an honest note instead of stale data.* Das beschreibt
nach dieser Änderung das Gegenteil und muss mit.

## Nicht in diesem Vorhaben

- **Die Schmuckliste** (`Data/MetaMirrorTrinkets.lua`) hat eine eigene Pipeline
  und wird vom Wochenlauf gar nicht gebaut. Ob sie denselben Fallback bekommt,
  ist eine eigene Entscheidung.
- **Kein Verfall zur Laufzeit im Addon.** Die 28-Tage-Grenze greift beim Bau.
  Wer das Addon monatelang nicht aktualisiert, hat ohnehin durchgehend alte
  Daten — dafür trägt die Kopfzeile seit jeher das Datum.
