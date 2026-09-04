# Machbarkeitsstudie: "Top-Spieler-Meta" aus Blizzard Battle.net API + GitHub Actions

Stand der Recherche: 2026-09-04. Die offizielle Doku-Seite `community.developer.battle.net` ist eine JS-SPA und lieferte bei direktem Abruf nur das leere HTML-Gerüst – inhaltliche Aussagen zu Endpoints stammen daher aus Forenbeiträgen, Blizzard-eigenen Zitaten (ToS, die als statische Seite abrufbar war) und etabliertem Community-/Wrapper-Wissen. Wo ich eine Aussage in dieser Session nicht direkt verifizieren konnte, ist sie explizit als **vermutet** markiert.

## 1. Relevante Endpoints

**Mythic-Keystone-Leaderboard** – belegt: Pfadmuster `/data/wow/connected-realm/{connectedRealmId}/mythic-leaderboard/{dungeonId}/period/{period}`, Index unter `/data/wow/connected-realm/{connectedRealmId}/mythic-leaderboard/index`, Namespace `dynamic-<region>` ([Forendiskussion](https://us.forums.blizzard.com/en/blizzard/t/missing-data-mythic-keystone-leaderboard-api/21972), [Ruby-Wrapper-Doku](https://rubydoc.info/gems/blizzard_api_rb_rb/BlizzardApi/Wow/MythicKeystoneLeaderboard)). Wichtige Einschränkung, von Raider.IO selbst bestätigt: "Blizzard's API will show a maximum of 500 runs for a given Realm and Dungeon" – ältere, niedrigere Runs fallen bei Wettbewerb raus ([Raider.IO Support](https://support.raider.io/kb/frequently-asked-questions/how-does-the-mythic-plus-leaderboard-slash-api-capacity-work)). Ob die Member-Objekte pro Run eine `specialization_id` enthalten, konnte ich in dieser Session **nicht verifizieren** – das ist ohne registrierten Client/Live-Call nicht sauber zu klären und sollte vor Implementierungsbeginn mit einem echten Testcall geprüft werden.

**Mythic-Keystone Affix-/Period-/Season-Index** – vermutet (etabliertes, aber nicht live nachgeprüftes Community-Wissen): `/data/wow/keystone-affix/index` (Namespace `static-<region>`), `/data/wow/mythic-keystone/period/index` und `/data/wow/mythic-keystone/season/index` (Namespace `dynamic-<region>`).

**Character Equipment Summary** – Pfad `/profile/wow/character/{realmSlug}/{characterName}/equipment`, Namespace `profile-<region>` (Endpoint-Existenz belegt über [Profile-API-Übersicht](https://community.developer.battle.net/documentation/world-of-warcraft/profile-apis), Feldstruktur **vermutet** aus Trainingswissen, da SPA nicht direkt einsehbar war): pro Item u. a. `bonus_list` (Array numerischer Bonus-IDs, z. B. für Itemlevel-Upgrade-Tracks), `sockets` (Typ + eingesetzter Edelstein als Item-Referenz) und `enchantments` (Enchant-ID + lokalisierter Anzeigetext). D. h. Sockelsteine und Verzauberungen sind grundsätzlich enthalten, aber die Bonus-IDs sind reine Zahlen ohne Klartext-Bedeutung – dafür ist eine separate statische Mapping-Tabelle nötig (z. B. aus Wowhead/SimC-Daten, nicht Teil der Blizzard-API).

**Character Statistics** – Pfad `/profile/wow/character/{realmSlug}/{characterName}/statistics`, Namespace `profile-<region>`. Vermutet: liefert Sekundärwerte als `{rating, rating_bonus/value}`-Paare (Krit, Tempo, Meisterschaft, Vielseitigkeit) – also sowohl Rating als auch bereits umgerechneten Prozentwert. Dieser Endpoint ist **nicht** im Leaderboard enthalten, sondern erfordert einen eigenen Call pro Charakter.

**Character Specializations** – Pfad `/profile/wow/character/{realmSlug}/{characterName}/specializations`, Namespace `profile-<region>`. **Wichtiger belegter Befund:** Das `loadouts`/Talent-Feld fehlt seit Patch 11.2 im Live-Response – ein seit über einem Jahr offener, von Blizzard unkommentierter Bug ("Still no news on this", "Can we not even get a response at all on this?") ([Forenthread](https://us.forums.blizzard.com/en/blizzard/t/wow-112-character-specializations-api-talents-missing/55656)). Dadurch sind Armory, Raidbots-Import und ähnliche Drittanbieter-Tools für Talente funktionsunfähig. In meiner Recherche fand sich **kein** Hinweis auf eine Behebung bis September 2026 – für die Talent-Komponente des Projekts ist das ein Blocker, kein Detail.

**Character Mythic Keystone Profile** – Pfad `/profile/wow/character/{realmSlug}/{characterName}/mythic-keystone-profile` sowie `.../season/{seasonId}`, Namespace `profile-<region>`. Belegt: liefert nur den **besten** Run pro Dungeon und Periode/Saison, keine Liste aller Runs und keine Gruppenzusammensetzung anderer Mitglieder ([Forendiskussion "What does mythic-keystone-profile actually return?"](https://us.forums.blizzard.com/en/blizzard/t/what-does-mythic-keystone-profile-actually-return/17139)).

**PvP-Leaderboards** – Pfad `/data/wow/pvp-season/{season}/pvp-leaderboard/{bracket}`, Namespace `dynamic-<region>`, Brackets u. a. `2v2`, `3v3`, `rbg`, `shuffle-{class}-{spec}` (belegt über Forenthreads zu Migration/Fehlern, z. B. [PvP leaderboard migration](https://us.forums.blizzard.com/en/blizzard/t/pvp-leaderboard-migration/2322)). Ein älterer, nicht datierbar bestätigter Bericht nennt fehlende Class/Spec/Race/Gender-Felder in PvP-Leaderboards ([Forenthread](https://us.forums.blizzard.com/en/blizzard/t/classspecracegender-all-missing-from-pvp-leaderboards/4374)) – Status aktuell ungeklärt, vor Nutzung selbst testen.

**Raid-Leaderboard/Hall of Fame** – Es gibt **keinen** offiziellen Blizzard-API-Endpoint dafür; Hall-of-Fame-Daten existieren nur als Webseite bei Blizzard/Raider.IO ([Raider.IO Hall of Fame Beispiel](https://raider.io/amirdrassil-the-dreams-hope/hall-of-fame/world/mythic)). Das ist belegt durch das Fehlen jeglicher Treffer zu einem entsprechenden Game-Data-Endpoint in Doku, Foren und Wrapper-Bibliotheken.

## 2. Top-Spieler je Spec ermitteln

Ohne bestätigte Spec-ID im Leaderboard-Member-Objekt bräuchte man pro Kandidaten mindestens einen zusätzlichen Call auf `specializations`, um die aktive Spezialisierung zu bestimmen (Talent-Feld selbst ist ja kaputt, aber die aktive Spec sollte weiterhin geliefert werden). Realistischer Ablauf: (a) M+-Leaderboards aller Connected Realms × aktueller Dungeons × aktueller Periode für EU+US ziehen, (b) Top-Läufe nach Zeit/Key-Level sortieren, (c) pro Charakter Equipment+Statistics+Specializations abrufen, (d) nach Spec bucketen, bis genug Samples je Spec vorliegen.

**Call-Schätzung (vermutet/überschlägig, keine offizielle Quelle für exakte Realm-Zahlen in dieser Session geprüft):** EU/US haben je grob 100+ Connected Realms; bei ~8 Dungeons/Saison und nur der aktuellen Periode ergeben sich ca. 800–1.100 Leaderboard-Calls pro Region, also ~1.600–2.200 für beide Regionen. Für 40 Specs × 2 Regionen × z. B. Top-30 Kandidaten (nach Dedublizierung, da Top-Spieler oft mehrfach in verschiedenen Runs auftauchen) ergeben sich überschlägig 1.500–2.500 einzigartige Charaktere × 3 Calls (Equipment/Statistics/Specializations) = **4.500–7.500 Calls**. Zusammen mit dem Leaderboard-Sweep liegt der Gesamtbedarf pro Lauf grob bei **6.000–10.000 Calls** – deutlich unter dem belegten Limit von 36.000/Stunde ([Blizzard Developer API Terms](https://www.blizzard.com/en-us/legal/a2989b50-5f16-43b1-abec-2ae17cc09dd6/blizzard-developer-api-terms-of-use)). Ein zusätzliches Limit von 100 Requests/Sekunde wird in Community-Threads genannt, ist ToS-seitig aber nicht wörtlich als Zahl gefunden worden – als Sicherheitsmarge empfiehlt sich clientseitiges Throttling auf deutlich darunter (z. B. 20–40 req/s), dann dauert der Lauf bei 8.000 Calls ca. 4–7 Minuten reine API-Zeit plus Verarbeitung.

**Raid-Meta ohne Logs:** Da es keinen Blizzard-Raid-Leaderboard-Endpoint gibt, ist die einzige praktikable Annäherung, eine Kandidatenliste von "Charakteren mit hohem Mythic-Raid-Fortschritt" extern zu beziehen (Raider.IO, s. u.) und deren Ausrüstung/Statistiken danach direkt über die Blizzard-Profile-API nachzuladen – die eigentlichen Gear-Daten kämen also weiterhin von Blizzard, nur die "wer ist relevant"-Vorauswahl von Raider.IO.

## 3. Raider.IO als Kandidatenlieferant

Belegt über Community-Wrapper-Dokumentation (offizielle `raider.io/api`-Seite lieferte in dieser Session einen HTTP 403 und war nicht direkt einsehbar, daher hier als **vermutet, aber gut korroboriert** markiert): Der Endpoint `characters/profile` akzeptiert einen `fields`-Parameter mit u. a. `mythic_plus_scores_by_season:current`, `mythic_plus_best_runs`, `mythic_plus_ranks`, `raid_progression` und `gear` (Item-Level-Übersicht) ([Beispielaufruf-Referenz](https://support.raider.io/kb/frequently-asked-questions)). Für Mythic-Plus-Topläufe gibt es zusätzlich `mythic-plus/runs` mit Parametern `season`, `region`, `dungeon`, `page`.

**Rate-Limits/ToS (vermutet aus Suchergebnis-Snippets, nicht direkt aus der Primärquelle gelesen):** 200 Requests/Minute unauthentifiziert, höhere Limits nach Registrierung unter `raider.io/settings/apps`; öffentliche Anwendungen müssen einen Link zurück zu Raider.IO einbinden, dürfen keine "competing services" bauen, keine Daten weiterverkaufen und nicht über die veröffentlichten Endpoints hinaus scrapen.

**Einschätzung (keine Rechtsauskunft):** "Kandidaten von Raider.IO, Gear von Blizzard" erscheint plausibel zulässig, da die tatsächlich veröffentlichten Ausrüstungsdaten aus der Blizzard-API stammen und nicht weiterverkauft/konkurrierend genutzt werden. Sicherheitshalber sollte trotzdem ein Attribution-Link zu Raider.IO im Addon/README stehen, sobald dessen Daten – und sei es nur zur Kandidatenauswahl – im Pipeline-Ergebnis mitwirken.

## 4. ToS-Konformität für dieses Szenario

Alle folgenden Zitate sind wörtlich aus den [Blizzard Developer API Terms of Use](https://www.blizzard.com/en-us/legal/a2989b50-5f16-43b1-abec-2ae17cc09dd6/blizzard-developer-api-terms-of-use) belegt:

- **30-Tage-TTL:** "You must implement a maximum 30-day TTL (time-to-live) policy for all Data obtained through our APIs." Ein wöchentlicher Refresh liegt weit innerhalb dieser Grenze – am saubersten ist es aber, Rohdaten pro Lauf gar nicht zu persistieren, sondern nur das aggregierte Ergebnis zu speichern, dann stellt sich die TTL-Frage für Rohdaten praktisch nicht.
- **Attribution:** "You shall clearly and conspicuously identify Blizzard in Your Application as the source of the Data, and You shall do it in such a way which makes it not appear that Blizzard is endorsing or affiliated with Your Application." → Im Addon (TOC/README/Optionsseite) einen klaren Hinweis "Daten via Blizzard Battle.net API, nicht mit Blizzard verbunden" aufnehmen.
- **Kein Premium:** "'Premium' versions of Applications offering additional for-pay features are not permitted…" → Die Meta-Funktion muss dauerhaft kostenlos bleiben, keine Bezahlschranke.
- **API-Key-Geheimhaltung:** "You shall keep Your API Key confidential, and not share it with any third party." → Client-Secret als GitHub-Actions-Secret ist die richtige Umsetzung, solange das Repo keine Fork-PRs mit Secret-Zugriff zulässt (Standardverhalten von GitHub Actions: Secrets sind für PRs aus Forks nicht verfügbar) – das ist eine **Einschätzung**, keine ToS-Aussage.
- **Redistribution aggregierter/anonymisierter Daten:** In den Terms wurde **keine** explizite Klausel dazu gefunden ("NOT FOUND" bei gezielter Suche nach dieser Klausel) – d. h. es gibt weder ein explizites Verbot noch eine explizite Erlaubnis für aggregierte, namenlose Ableitungen. Empfehlung: keine Spielernamen/Realms in der Ausgabedatei führen (deckt sich mit der Vorgabe "keine Namen!") – das minimiert sowohl Datenschutz- als auch ToS-Risiko, ersetzt aber keine Rechtsberatung.
- **Rate-Limit:** "You are limited to thirty-six thousand (36,000) calls to the Blizzard Developer API per hour…" – belegt, s. o.

## 5. Datenlücken und Workarounds

- **Talente/Loadout-String:** aktuell technisch nicht zuverlässig aus der API abrufbar (Bug seit 11.2, s. Abschnitt 1). Workaround: Talent-Teil vorerst aus kuratierten Community-Presets (z. B. manuell gepflegt oder aus Guides) speisen und im Addon klar als "keine Live-Daten" kennzeichnen, oder Feature zurückstellen, bis Blizzard den Bug behebt.
- **Bonus-IDs ohne Klartext:** Equipment liefert nur numerische `bonus_list`-IDs; die Bedeutung (z. B. welcher Itemlevel-Track) muss über eine extern gepflegte statische Tabelle aufgelöst werden – kein API-Problem, sondern zusätzlicher Datenbestand nötig.
- **Stat-Prozentwerte nur live pro Charakter:** Es gibt keinen Bulk-Endpoint, der Statistics für viele Charaktere gleichzeitig liefert; jeder Kandidat braucht einen eigenen `statistics`-Call.
- **Lokalisierte Enchant-Namen:** Anzeigetexte sind sprachabhängig vom `locale`-Query-Parameter – für ein Lua-Datenfile reicht es, IDs zu speichern und Klartext im Addon selbst zu lokalisieren, statt sich auf die API-Locale zu verlassen.
- **Keine Gruppenmitglieder-Specs im Mythic-Keystone-Profile:** Für "wer lief mit wem" bräuchte man das Leaderboard, nicht das Charakterprofil.

## 6. Architekturempfehlung

**Module:** `auth.py` (Client-Credentials-Flow, Token-Cache) · `leaderboard_harvester.py` (Realm-Index + M+-Leaderboards EU/US) · `raiderio_candidates.py` (optional, Raid-Progress-Kandidaten) · `character_fetcher.py` (async, ratenlimitiert, Equipment/Statistics/Specializations) · `aggregator.py` (Median/Modus je Slot, Stat-Anteile als Prozent der Summe) · `lua_writer.py` (Export) · GitHub-Actions-Workflow (wöchentlicher Cron, Secrets `BNET_CLIENT_ID`/`BNET_CLIENT_SECRET`).

**Call-Budget/Laufzeit:** s. Abschnitt 2, grob 6.000–10.000 Calls pro Lauf, bei moderatem Throttling wenige Minuten reine API-Zeit, gesamter Workflow inkl. Verarbeitung und Commit realistisch unter 30 Minuten GitHub-Actions-Laufzeit.

**Caching:** statische Indizes (Realms, Affixe, Saison/Periode) selten ändern, lang cachen (z. B. im Repo versionieren, wöchentlich revalidieren); Rohdaten pro Charakter nicht persistieren, nur das Aggregat committen – vermeidet TTL-Buchführung komplett.

**Aggregation:** je Spec+Slot Item-ID als Modus, Sockel/Enchant als Modus je Sockeltyp, Sekundärstat-Priorität als Median des Prozentanteils am Gesamt-Sekundärstat-Pool; Mindeststichprobe (z. B. ≥10 Charaktere) vor Veröffentlichung eines Spec-Werts, sonst "keine Daten" statt Rauschen.

**Fehlerfälle:** 401 → Token-Refresh; 404 (Charakter umbenannt/transferiert/inaktiv) → überspringen und zählen; 429 → Backoff; Teilausfall einer Region → alten Datenstand der Vorwoche als Fallback behalten statt leere Datei zu veröffentlichen.

**Aufwandsschätzung (grob, Personentage für eine Einzelperson):**
- App-Registrierung/Auth: 0,5 PT
- Leaderboard-Harvester: 1,5 PT
- Character-Fetcher (async, Rate-Limiting, Retry): 2 PT
- Raider.IO-Integration (optional): 1 PT
- Aggregationslogik Gear/Stats: 2 PT
- Talent-Workaround/Recherche: 1 PT
- Lua-Export + Addon-Anbindung: 1 PT
- GitHub-Actions-Workflow/Secrets: 0,5 PT
- Tests/Fehlerbehandlung/Politur: 1,5 PT
- **Summe: ≈ 11 Personentage** (grobe Schätzung, keine belastbare Quelle, eigene Einschätzung basierend auf Scope)

## Kernaussage

Technisch und lizenzrechtlich ist das Projekt mit vertretbarem Aufwand machbar: Rate-Limits und 30-Tage-TTL sind für einen wöchentlichen Batch-Job unproblematisch (belegt), Registrierung + Client-Secret in GitHub-Actions-Secrets ist der vorgesehene Weg (belegt), und eine namenlose, aggregierte Lua-Datei umgeht die größten ToS-Grauzonen (Einschätzung, nicht explizit geregelt). Der größte reale Blocker ist kein Lizenz-, sondern ein Datenproblem: Das Talent-/Loadout-Feld der Character-Specializations-API ist seit über einem Jahr defekt und unkommentiert von Blizzard (belegt) – die Talent-Komponente der "Top-Meta" ist damit vorerst nicht zuverlässig aus der offiziellen API ableitbar und braucht einen Workaround oder muss zurückgestellt werden. Ein offizieller Raid-Leaderboard-Endpoint existiert nicht; Raid-Meta lässt sich nur über eine externe Kandidatenliste (z. B. Raider.IO) plus Blizzard-Gear-Nachladung annähern.
