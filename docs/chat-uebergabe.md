# MetaMirror — Übergabe an einen neuen Chat

**Stand: 2026-09-16.** Alles hier steht so im Repo — Git-Stand, Testläufe und
Dateilisten sind für dieses Dokument nachgesehen worden, nicht aus dem
Gedächtnis abgeschrieben. Wo etwas ungeprüft ist, steht es dabei.

Diese Datei ersetzt den Gesprächsverlauf. Wer sie gelesen hat, kann ohne
Rückfragen weiterarbeiten.

---

## 1. Was MetaMirror ist

Ein eigenständiges WoW-Addon für *Midnight* (Interface 120100), getrennt von
KeyRoulette und AutoRole. Es zeigt pro Spec Sekundärwert-Ziele, ein
Referenz-Ausrüstungsset, eine Schmuck-Rangliste und Verbrauchsgüter — und
vergleicht die eigenen Werte live dagegen. Vier Tabs, Fenster hängt am
Charakterbogen, `/mm` schaltet es um.

**Datenquelle ist ausschließlich Simulation:** bloodmallet.com
(Sekundärwert-Verteilungen, Schmuck-Sims) und die
SimulationCraft-Referenzprofile. Kein Meta-Ranking echter Spieler.

Ausführliche Beschreibung: [README.md](../README.md).

---

## 2. Regeln, die nicht im Code stehen

Diese gelten fort und sind nicht verhandelbar.

**Warcraft Logs / RPGLogs / Archon sind dauerhaft gesperrt** — als Datenquelle,
als Bibliothek, als Zitat, in jeder Form. Der Pfad wurde vollständig
zurückgebaut (Commit `f5737f1`), der Rohdaten-Cache gelöscht. Nicht
wiederbeleben, auch nicht „nur zum Vergleich". Grund: die RPGLogs-API-Terms
untersagen die Weitergabe ihrer Inhalte „including in-game add-ons".

**Keine geratenen Magic-IDs.** Item-IDs, Bonus-IDs, Spell-IDs, Texturpfade:
belegen oder weglassen. Ein Ilvl-Filter, der plausibel aussah, hat schon einmal
BfA-Schmuck zurückgeholt.

**Nie ohne Zustimmung** committen, pushen, deployen, eine Pipeline gegen eine
Live-API laufen lassen oder etwas veröffentlichen. Force-Push bleibt gesperrt.

**Commit-Trailer** ist `Co-Authored-By: Claude <Modellname> <noreply@anthropic.com>`
— eingesetzt wird das Modell, das den Commit tatsächlich geschrieben hat, nicht
eine feste Zeichenkette. Die Historie enthält deshalb `Claude Fable 5.1` (bis
2026-09-15) und `Claude Opus 5` (ab 2026-09-16). Am 2026-09-16 entschieden,
nachdem die alte Fassung den Namen festgeschrieben hatte und damit ein Modell
nannte, das den Commit nicht gemacht hat.

**Zugangsdaten** leben in `pipeline/local_secrets.json` (gitignored) oder in
CI-Secrets. Nie ausgeben, nie committen, nie in den Chat. Nur Schlüssel*namen*
und „gesetzt / nicht gesetzt" dürfen genannt werden. Jedes Addon hat seine
eigene Datei in seinem eigenen Ordner.

**Ein Release-ZIP enthält niemals** `pipeline/`, `docs/`, `.git/`, Screenshots
oder irgendetwas mit „secret" im Namen. Das Upload-Skript prüft das; die Prüfung
nicht entschärfen.

**CurseForge ist der einzige Vertriebsweg.** WoWInterface und Wago wurden am
2026-09-05 abgelehnt, Reddit am 2026-09-06 gestrichen (die WoW-Subreddits
verbieten Addon-Werbung *und* KI, auch im Code). Werbung in fremden
Discord-Servern fällt unter dieselbe Regel. Nicht erneut vorschlagen, keine
Umgehungen anbieten.

**Style.lua ist in allen drei Addons zeilengleich** bis auf drei Zeilen
(Kommentarkopf und der Addon-Name). Wer sie ändert, ändert sie überall oder gar
nicht.

**Bilder** — Mockups, Galerie, Renderings — werden auf Englisch beschriftet.

**E-Mails** nur als Entwurf, nie selbst senden.

### Werkzeug-Fallen auf diesem Rechner

- **Git-Bash-Heredocs zerstören Backslashes und Nicht-ASCII** (Umlaute, `·`,
  Gedankenstriche). Lua-Strings mit Escapes und deutsche Texte deshalb mit
  Write/Edit schreiben oder über eine Python-Datei im Scratchpad — nie per
  `cat <<EOF`.
- **Das Terminal des Nutzers ist PowerShell**, dort gibt es kein `&&`.
- **Das Arbeitsverzeichnis der Bash treibt zurück** nach `E:\claude-projekt`.
  Immer `cd /e/claude-projekt/MetaMirror &&` voranstellen.
- **`DIM_HEX` in `UI.lua`** wird erst ab etwa Zeile 808 lokal deklariert. Code
  darüber, der es benutzt, greift ins Leere. Vor jedem neuen Textstück prüfen,
  welche Locals an der Stelle schon existieren.

---

## 3. Geprüfter Stand am 2026-09-16 (abends)

| | |
| --- | --- |
| Version | 1.0.3 (`MetaMirror.toc`) — der Tag `v1.0.0` zeigt weiter auf den alten Stand |
| Branch | `main` liegt **fünf Commits vor `origin/main`** — bewusst noch nicht gepusht |
| Remote | `github.com/bartpirat90/MetaMirror` — **das Repo ist öffentlich** |
| Daten | `sim-2026-09-16` (Stats/Gear), `bm-2026-09-05` (Schmuck) |
| Addon-Tests | `lua tests/run_harness.lua` → 34 PASS, 0 FAIL (auf den neuen Daten geprüft) |
| Pipeline-Tests | `python -m pytest pipeline/tests -q` → 118 passed |
| Workflows | `.github/workflows/sim-data.yml`, `tests.yml` |
| Im Spiel | 1.0.3 liegt im AddOns-Ordner, per `scripts/deploy.sh` |
| CurseForge | Projekt **1678018 ist öffentlich sichtbar**, dort steht 1.0.0 (5.9.), 35 Downloads |

**Im Spiel abgenommen (2026-09-16):** der Andock-Knopf sitzt richtig, und die
Gegenstandsstufen im Ausrüstungs-Tab stimmen. Beides ließ sich nur im Spiel
prüfen; die Bestätigung kam vom Betreiber des Projekts.

**Wichtig für den nächsten Chat:** Die Vorgängerfassung dieses Dokuments hielt
den Datenstand für elf Tage alt und `main` für synchron. Beides stimmte nicht —
es war nur kein `git fetch` gelaufen. Der Wochenlauf hatte am 7. und 14.9. sauber
durchgezogen, committet und gepusht (Version dabei zweimal gebumpt: 1.0.0 →
1.0.2). **`git fetch` vor jeder Aussage über den Remote-Stand**; `git status`
allein beantwortet die Frage nicht, es vergleicht nur mit dem letzten Abruf.

**Bereinigt und erledigt:** `warcraftlogs secret key.png` ist nicht mehr in der
Git-Historie (filter-repo lief, Sicherung liegt als
`MetaMirror-backup-vor-filter-repo.bundle` neben dem Projekt). Der
`CF_PUBLISH`-Schalter und der CurseForge-Upload aus dem Wochenlauf sind
entfernt. Der tote WCL-Code (`wcl.py`, `run.py`, `aggregate.py`, `fetch.py`) ist
weg — ältere Notizen, die ihn noch erwähnen, sind überholt.

---

## 4. Befehle

```bash
cd /e/claude-projekt/MetaMirror && luac -p *.lua Data/*.lua
cd /e/claude-projekt/MetaMirror && lua tests/run_harness.lua
cd /e/claude-projekt/MetaMirror && python -m pytest pipeline/tests -q
```

Daten neu bauen (greift auf bloodmallet.com zu — **nur mit Zustimmung**):

```bash
cd /e/claude-projekt/MetaMirror && python -m pipeline.build_sim
```

In den Spielordner deployen (seit 2026-09-16, nach dem Vorbild von KeyRoulette):

```bash
cd /e/claude-projekt/MetaMirror && bash scripts/deploy.sh --dry-run
cd /e/claude-projekt/MetaMirror && bash scripts/deploy.sh
```

Das Skript prüft erst die Lua-Syntax, leert dann im Ziel die `*.lua`/`*.toc` und
kopiert `.toc`, die Lua-Dateien der obersten Ebene, `Data/*.lua` und die beiden
TGAs nach
`D:\Battle.net\World of Warcraft\_retail_\Interface\AddOns\MetaMirror`.
`pipeline/`, `docs/`, `tests/` und `release/` bleiben draußen. Fehlt der
AddOns-Ordner, bricht es ab, statt irgendwohin zu kopieren.

CurseForge-Upload und Einrichtung: [pipeline/CURSEFORGE.md](../pipeline/CURSEFORGE.md).

---

## 5. Offen

1. **Fünf Commits sind nicht gepusht.** `d27ae4b` (CHANGELOG 1.0.1/1.0.2),
   `3fc9679` (Handwerksbeschriftung + Andock-Knopf), `75441f2` (Spec für den
   Fallback), `429d6a9` (Daten `sim-2026-09-16`, Version 1.0.3) und `cfd323e`
   (geliehene Bonus-ID-Sätze für die Referenzstufe). Der Betreiber hat das
   Committen freigegeben, das Pushen ausdrücklich noch nicht.
2. **Das Fallback-Design ist beschlossen, aber nicht gebaut.**
   `docs/superpowers/specs/2026-09-16-sim-fallback-design.md`: alte Sim-Zahlen
   werden übernommen, wenn die Quelle nichts liefert, mit Altersangabe im Spiel;
   Grenze vier Wochen, die Kopfzeile trägt das echte Datum.
3. **Ingame-Abnahme** der Fünf-Ziel-Zahlen für Mythisch+ und der Hinweiszeile im
   Ausrüstungs-Tab. Seit dem 2026-09-05 gebaut, nie gezielt im Spiel angesehen.
   Abgenommen sind bisher nur der Andock-Knopf und die Gegenstandsstufen.
4. **CurseForge hinkt hinterher.** Dort steht 1.0.0 vom 5.9., im Repo liegt 1.0.3
   mit Sim-Daten vom 16.9. Am 2026-09-16 bewusst nicht hochgeladen: erst die
   restliche Ingame-Abnahme. Dass das Projekt versteckt sei, stimmt nicht mehr —
   es ist öffentlich und hat 35 Downloads.
5. **Der Wochenlauf frischt die Schmuckdaten nicht mit auf.** `sim-data.yml` baut
   nur `Data/MetaMirrorData.lua`; `MetaMirrorTrinkets.lua` steht deshalb
   unverändert auf `bm-2026-09-05`. Ob das so gewollt ist, wurde nie entschieden.
6. **Tags fehlen weiter.** Der Wochenlauf bumpt die Patch-Version, setzt aber
   keinen Tag: `v1.0.0` ist der einzige Tag, die `.toc` steht auf 1.0.3.
   `CHANGELOG.md` kennt inzwischen 1.0.1 bis 1.0.3; die Verweise dort zeigen
   mangels Tags auf Commit-SHAs.
7. **Handwerksitems behalten ihre Basisstufe im Blizzard-Tooltip** — entschieden,
   kein offener Fehler. Vier Zeilen (Vengeance, Nebenhand 237840 und Handgelenke
   244576, je M+ und Raid) kommen ohne Bonus-IDs und zeigen deshalb Stufe 44
   statt 331. Einen Satz aus einem anderen Spec-Profil zu leihen ist hier
   gesperrt: bei Handwerksitems kodieren die Bonus-IDs auch die gewählten
   Sekundärwerte, und die weichen je Spec ab (237840: Vengeance `36/40`, Havoc
   `49/36`). Eine Ableitung aus `crafted_stats` scheidet aus — in allen
   zwischengespeicherten Profilen gehört keine der 28 Bonus-IDs exklusiv zu einem
   Statpaar. Die Referenzstufe steht stattdessen in der MetaMirror-Zeile.
8. **Das GitHub-Repo ist öffentlich** — daran denken, bevor etwas hineingeschrieben
   wird. Jeder Zugangsschlüssel, der hier je auftauchte, ist als verbrannt zu
   behandeln und beim jeweiligen Anbieter zu widerrufen; das ist mit dem Betreiber
   des Projekts besprochen. Zugangsdaten gehören ausschließlich in
   `pipeline/local_secrets.json` (gitignored) oder in CI-Secrets.

---

## 6. Zum Vergleich: die anderen beiden Addons

KeyRoulette steht auf 5.1.3 und ist auf CurseForge veröffentlicht; dort gibt es
`scripts/deploy.sh`, `scripts/release.ps1` und `pipeline/cf_upload.py`, die als
Vorlage taugen. AutoRole liegt bei 1.1. Beide teilen `Style.lua` mit MetaMirror.
