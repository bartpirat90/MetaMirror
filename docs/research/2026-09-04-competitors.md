# Konkurrenzanalyse: In-Game-Optimierungs-Tools für WoW (Stand 2026-09-04)

## 1. Icy Veins "Class Codex" (in der Icy Veins App / U.GG)

**Datenquelle:** Icy-Veins-Redaktionsguides (Talente, BiS, Stats, Rotation), kuratiert von der Icy-Veins-Redaktion, nicht direkt aus Logs/Sim-Daten der Spieler.

**Funktionsumfang:** Talentempfehlungen, BiS-Ausrüstung, Statprioritäten, Rotationstipps – laut Ankündigung "all within the game". Details zur exakten UI (Tooltip vs. Panel vs. Dock) sind auf der offiziellen Seite nicht spezifiziert, aber Community-Videos zeigen ein andockbares Overlay-Panel, das über die App eingeblendet wird, nicht ein klassisches In-Game-Lua-Addon-Fenster.

**Bedienung/Optik:** Läuft nicht als reines WoW-Addon, sondern über die **Icy Veins App** (baut auf der U.GG-App-Plattform / Overwolf-artiger Client auf), die parallel zum Spiel läuft und Overlays einblendet. Ohne installierte App kein Class Codex – ein reines In-Game-Addon-Interface gibt es laut Recherche nicht.

**Technische Besonderheiten:** App-Bundling (Class Codex ist exklusiv an die Icy-Veins-App gekoppelt, kein separates CurseForge-Addon), laut Icy Veins "komplett ToS-konform"; Modell ist "free & ad-supported", mit angekündigtem werbefreiem Icy-Veins-Premium-Abo.

**Kritik/Schwächen:** Im offiziellen Blizzard-Forumsthread ist die dominante Beschwerde die **App-Exklusivität**: Spieler wollten die Daten als normales Addon, nicht gebunden an eine zusätzliche Desktop-App ("Exclusive to IcyVeins app. What a terrible decision"). Das schafft Reibung ggü. reinen CurseForge-Addons, die ohne Zusatzsoftware laufen.

Quellen: [icy-veins.com/download](https://www.icy-veins.com/download), [Icy Veins App Ankündigung](https://www.icy-veins.com/wow/news/the-icy-veins-app-is-here-and-it-puts-our-guides-inside-the-game/), [Blizzard-Forum](https://us.forums.blizzard.com/en/wow/t/class-codex-addon/2344179), [u.gg/app](https://u.gg/app?game=wow)

## 2. Archon Tooltip-Addon (Warcraft Logs / Archon.gg)

**Datenquelle:** **Warcraft Logs** (Raid-Parses, All-Star-Punkte, World-Rank) – exakt die Datenbasis, die für MetaMirror tabu ist.

**Funktionsumfang:** Zeigt beim Hover über einen Spieler dessen Raid-Fortschritt, Boss-Kills, Durchschnitts-Parse, All-Star-Points und World-Rank direkt im Unit-Tooltip. Parses werden erst ab einer Mindestzahl an Kills angezeigt (Schutz vor Bloßstellung bei wenigen Logs); Normal-Modus wird bewusst ausgeklammert, um nur High-End-Content zu bewerten.

**Bedienung/Optik:** Reines **Tooltip-Overlay** auf Spieler-Frames (Gruppe, Ziel, Charakterauswahl) – kein eigenes Panel, sehr niedrigschwellig.

**Technische Besonderheiten:** Kostenlos mit **wöchentlichem** Daten-Update; Warcraft-Logs-**Patreon-Abonnenten** bekommen **täglichen** Update-Takt sowie Shift-Klick für Encounter-Detailwerte – klassisches Freemium-Modell über eine externe Abo-Plattform, nicht über CurseForge. Spieler können ihr Warcraft-Logs-Profil auf privat stellen, um aus der Anzeige zu verschwinden (mit dem Nachteil schlechterer Gruppeneinladungen).

**Kritik/Schwächen:** Deutliche Community-Kontroverse (Blizzard-Foren EU/US, "Ban Archon Tooltip, please!"-Thread, YouTube "This Addon Will Make LFG More Toxic"): Vorwurf verstärkten **Gatekeepings** ("wird zum Pflicht-Filter für jeden"), Sorge um Einstiegshürde für Neulinge, Kritik an **irreführenden Durchschnittswerten** (ein Boss-Parse sagt nichts über M+-Können) und Informationsungleichheit zwischen Free/Patreon-Nutzern. Gegenargument der Verteidiger: Erfahrene Spieler haben Logs ohnehin manuell gecheckt, das Addon ändert nur die Sichtbarkeit.

**Ausblick:** Archon hat 2024 **Subcreation** (Community-Statistikseite von "alcaras") aufgekauft und dessen Algorithmus in die Archon-Tierlisten integriert; der WarcraftLogs-Uploader wird zur "Archon App" migriert – Hinweis, dass Archon seine Tools zu einer größeren Companion-App bündelt (ähnlich Icy Veins/U.GG).

Quellen: [Patreon-Post](https://www.patreon.com/posts/103795871), [Icy-Veins-News zur Kontroverse](https://www.icy-veins.com/wow/news/new-archon-tooltips-addon-lets-you-see-player-parses-in-game-and-not-everyones-happy/), [Wowhead-News](https://www.wowhead.com/news/warcraft-logs-releases-in-game-tooltip-addon-displaying-player-parses-and-376174), [EU-Forum "Ban Archon Tooltip"](https://eu.forums.blizzard.com/en/wow/t/ban-archon-tooltip-please/568007), [US-Forum-Diskussion](https://us.forums.blizzard.com/en/wow/t/what-do-you-think-about-archons-show-parses-in-tooltips-addon-for-retail/2086476), [Subcreation-Übernahme](https://www.wowhead.com/news/subcreation-acquired-by-warcraft-logs-and-archon-337616), [Uploader-Migration](https://www.wowhead.com/news/warcraftlogs-uploader-transitioning-to-archon-app-on-june-29th-381785)

## 3. Murlok.io (Website + CurseForge-Addons)

**Datenquelle:** Eigene Erhebung aus den **Top-50-Spielern je Spec** via Battle.net-API, alle **8 Stunden** aktualisiert (PvE-Guides) bzw. laufend für PvP (Solo Shuffle, 2v2/3v3, Blitz, Rated BGs).

**Funktionsumfang:** Web-Guides pro Klasse/Spec mit Talenten, BiS-Gear, Stat-Prioritäten (mit konkreten Prozentwerten), Verzauberungen, Gems, Embellishments, Rassen – getrennt nach PvE (Raid/M+) und PvP. Zwei separate CurseForge-Addons: **"Murlok.io Stat Priority"** (Statgewichtung je Klasse/Spec, PvP-Fokus – Alleinstellungsmerkmal ggü. den meisten Konkurrenten) und **"MurlokExport"** (zeigt eigene Murlok.io-Rating-Daten aus M+/PvP im Spiel an).

**Bedienung/Optik:** Website als Hauptprodukt (klassische Guide-Seiten); die Addons zeigen ein **kleines Frame** mit Statprioritäten, kein Vollpanel.

**Technische Besonderheiten:** Datenbasis ist reine **Live-Metagame-Auswertung** (keine Sim-Daten), automatischer Spec-Wechsel-Support, kostenlos.

**Kritik/Schwächen:** Keine dezidierte Kritik in der Recherche gefunden; die Addons sind schlank, aber laut Funktionsumfang deutlich simpler als BiS-Listen-Addons (kein Lootbrowser, kein Tooltip-Integration für Items).

Quellen: [Murlok.io](https://murlok.io/), [Murlok.io Stat Priority (CurseForge)](https://www.curseforge.com/wow/addons/murlok-io-stat-priority), [MurlokExport](https://www.curseforge.com/wow/addons/murlokexport)

## 4. CurseForge-Nischenaddons (Stat/BiS-Familie)

Alle folgenden Addons haben ein gemeinsames Muster: **kleines Frame/Panel**, Datenquelle **Wowhead oder Icy Veins per Scraping/manuellem Redaktionsupdate**, kein Live-API-Anschluss.

- **Stat Priority / Icy Veins Stat Priority / ClassSpecStats** – fast identisches Konzept (kleines Frame über dem Charakterfenster, Daten von Icy Veins), z. T. mehrere konkurrierende Addons mit demselben Feature – Fragmentierung des Marktes. "Stat Priority" hat aktuelle Updates (Aug. 2026), ClassSpecStats dagegen seit 2023 nicht mehr gepflegt (veraltete Datenbasis für aktuelle Season – klares Risiko für Nutzer).
- **Stat Priority Note** – zeigt Wowhead-Statprioritäten oberhalb des Charakterfensters.
- **Stat Priority First** – neu für Midnight (12.0): schwebendes Panel mit Wowhead-Statketten, BiS-Picks **und** einer erklärenden DR-Anleitung (didaktischer Mehrwert ggü. reinen Zahlenlisten).
- **Loon Best In Slot (BIS)** – mit Abstand funktionsreichstes BiS-Addon (7,1 Mio. Downloads): Wowhead-BiS-**Tooltip-Integration** direkt im Item-Tooltip, Lootbrowser mit Filtern (Klasse/Spec/Phase/Slot/Quelle), eigene Custom-Listen, Gems/Enchants-Empfehlungen, Bagnon-Integration. Wichtiger Disclaimer des Autors: "ersetzt kein Sim, nur ein Guide".
- **Midnight BiS List** – reines Panel (kein Tooltip), farbcodierte Statusanzeige (grün=BiS ausgerüstet, gelb=niedrigeres ilvl, blau=im Beutel, rot=fehlt), Klick öffnet Encounter Journal, Datenquelle explizit "nur Wowhead", wöchentlich gepflegt.
- **BloodMalletStats** – kleines Community-Addon (nur ~60 Downloads, kein offizielles Bloodmallet-Projekt), zeigt gemittelte Statgewichte für M+ per Chat-Befehl `/run BloodMalletStats.Show()` – zeigt, dass selbst Nischenanbieter versuchen, Bloodmallet-Simdaten ins Spiel zu holen, aber bisher kaum Reichweite haben.

**Gemeinsame Schwächen:** Marktfragmentierung (5+ Addons lösen dasselbe Problem separat), viele Projekte verwaisen zwischen Season-Wechseln, keines kombiniert Statprioritäten **und** BiS-Gear **und** Verzauberungen/Steine in einem Produkt.

Quellen: [Stat Priority](https://www.curseforge.com/wow/addons/stat-priority), [Icy Veins Stat Priority](https://www.curseforge.com/wow/addons/icy-veins-stat-priority), [ClassSpecStats](https://www.curseforge.com/wow/addons/classspecstats), [Stat Priority Note](https://www.curseforge.com/wow/addons/stat-priority-note), [StatPriorityFirst](https://www.curseforge.com/wow/addons/statpriorityfirst), [Loon Best In Slot](https://www.curseforge.com/wow/addons/loon-best-in-slot), [Midnight BiS List](https://www.curseforge.com/wow/addons/midnight-bis-list), [BloodMalletStats](https://www.curseforge.com/wow/addons/bloodmalletstats)

## 5. Raidbots / Wowhead-Looter / Subcreation

**Raidbots:** kein Addon mit Live-Anzeige, sondern Webseite + **SimulationCraft-Export-Addon** (`/simc`-Befehl kopiert Charakter+Bags+Great-Vault-Optionen in eine Zwischenablage). Nutzer fügt den String manuell auf raidbots.com ein ("Droptimizer", "Top Gear") – Bruch im Workflow (Alt-Tab nötig), dafür sehr präzise Simulationsergebnisse inkl. Great-Vault-Bewertung. Item-/Bonus-ID-Datenbank wird aus EncounterJournal-Daten automatisch gepflegt.

**Wowhead Looter:** Sammelt beim Spielen Item-/Quest-/NPC-Daten und lädt sie zu Wowhead hoch – dient dem **Aufbau der Wowhead-Datenbank**, liefert dem Spieler selbst keine In-Game-Anzeige.

**Subcreation → Archon:** ehemals eigenständige Statistik-Seite (Talente/Gear-Popularität), 2024 von Archon/Warcraft Logs übernommen und in dessen Tierlisten integriert – zeigt Konsolidierungstrend: kleinere Community-Tools werden von den großen Logs-Plattformen aufgekauft statt eigenständig zu bleiben.

Quellen: [Wowhead Raidbots-Guide](https://www.wowhead.com/guide/how-to-use-raidbots-and-run-character-simulations-6050), [SimC-Addon-Anleitung](https://medium.com/raidbots/how-to-install-and-use-the-simulationcraft-addon-5b64d0835a0b), [Droptimizer Dev Journal](https://medium.com/raidbots/dev-journal-droptimizer-afa1f5fca6d2), [Subcreation-Übernahme](https://www.wowhead.com/news/subcreation-acquired-by-warcraft-logs-and-archon-337616)

---

## Ideen für MetaMirror

### Inhaltlich
1. **Kombi-Produkt statt Einzeltool** (machbar) – keiner der Nischenaddons vereint Statprioritäten + BiS-Gear + Verzauberungen/Steine/Verbrauchsgüter in einem Fenster; das ist MetaMirrors größter Whitespace ggü. der fragmentierten CurseForge-Landschaft.
2. **Tooltip-Zeile "BiS für Frost" beim Hovern über Loot** (machbar, Wowhead/bloodmallet-Datenbasis, nach Vorbild Loon BIS) – direktere Kaufentscheidung beim Looten als ein separates Panel.
3. **Didaktische DR-Erklärung neben der reinen Statzahl** (machbar, Vorbild Stat Priority First) – erklärt *warum* eine Prio gilt, nicht nur *was* sie ist.
4. **Explizite "kein Sim-Ersatz"-Kennzeichnung + Link/Export zu SimC-String** (machbar) – Vertrauensaufbau wie bei Loon BIS, plus Anschluss an Raidbots-Workflow ohne selbst zu simulieren.
5. **BiS-Drop-Alarm mit Quelle (Boss/Vendor/Delve) statt nur Itemname** (machbar, Wowhead-Datenbasis, Vorbild Midnight BiS List Farbcodierung grün/gelb/blau/rot für Ausrüstungsstatus).
6. **Schmuck-Tierliste transparent mit "Quelle: bloodmallet-Sim vom [Datum]"** (machbar) – Vertrauensvorsprung ggü. Addons, die undurchsichtig alt sind (ClassSpecStats seit 2023 tot).
7. ~~Parse-/Performance-Vergleich mit Gruppenmitgliedern~~ (NUR mit Warcraft-Logs-Daten möglich – für uns tabu; stattdessen Alternative: reiner **Gear-Score/BiS-Erfüllungsgrad**-Vergleich in der Gruppe, rein itemlevel-/statbasiert, keine Performance-Wertung).
8. **PvP-Statprioritäten als eigener Reiter** (machbar, Murlok.io-Vorbild) – von den meisten Konkurrenten (außer Murlok) ignoriert.

### Optisch
9. **Dock am Charakterfenster statt separatem Popup** (Vorbild Stat Priority Note/ClassSpecStats: kleines Frame direkt über PaperDollFrame) – geringere Klickhürde als ein Minimap-Button-Panel.
10. **Farbcodiertes Ausrüstungs-Ampelsystem** grün/gelb/blau/rot wie Midnight BiS List – sofort verständlich, keine Texterklärung nötig.
11. **Optionaler Tooltip-Modus UND Panel-Modus umschaltbar** – deckt sowohl "schneller Blick beim Looten" (Archon-Stil, Tooltip) als auch "geplante Ausrüstungsplanung" (Loon-Stil, Vollpanel) ab, statt sich wie die Konkurrenz auf eines festzulegen.
12. **Minimap-Button + Slash-Command** als Standard-Zugriffsmuster (Branchenkonvention bei fast allen genannten Addons) – Wiedererkennung für User, die von anderen Addons kommen.

### Technisch
13. **Datenstand-Zeitstempel sichtbar im UI** ("Stand: 04.09.2026, bloodmallet-Sim") – adressiert die verbreitete Schwäche verwaister Season-Daten (ClassSpecStats, kleine Stat-Priority-Klone).
14. **Kein externer App-Zwang** (Gegenposition zu Icy Veins/Archon-App-Bundling) – MetaMirror bleibt reines Lua-Addon ohne Overwolf-artigen Client; das war die Hauptbeschwerde gegen Class Codex im Blizzard-Forum.
15. **Klare Opt-in/Privacy-Kommunikation, falls je Gruppendaten verglichen werden** (Lehre aus der Archon-Kontroverse: Gatekeeping-Vorwürfe entstehen vor allem durch unfreiwillige Sichtbarkeit) – bei MetaMirror aktuell unkritisch, da keine Performance-/Log-Daten verwendet werden, aber als Prinzip für jede künftige "Vergleich mit anderen Spielern"-Funktion beachten.

**Zusammenfassung Datenmachbarkeit:** Alle 15 Ideen sind mit bloodmallet/SimulationCraft, Wowhead-Guides oder der Blizzard-API umsetzbar – keine erfordert Warcraft-Logs-Daten. Einzig ein direkter **Parse-/Performance-Vergleich** (Idee 7 in ihrer ursprünglichen Form) bräuchte Warcraft-Logs-Zugang und bleibt für MetaMirror ausgeschlossen; die vorgeschlagene Alternative (reiner Gear-/BiS-Vergleich) deckt einen ähnlichen Bedarf ohne diese Datenquelle.
