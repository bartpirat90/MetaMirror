# MetaMirror

**Stat-Ziele, Ausrüstung und Schmuck-Wertung, direkt neben deinem Charakterfenster.**

MetaMirror baut Stat-, Ausrüstungs- und Schmuck-Empfehlungen für deine Spezialisierung aus öffentlichen Simulationsdaten und sagt dir, woher jedes Teil stammt. Keine Browser-Tabs, keine Tabellen: Öffne dein Charakterfenster, und die Liste steht direkt daneben.

Die Daten stammen aus **bloodmallet.com** (Sekundärwert-Verteilungen und Schmuck-Sim-DPS) und **SimulationCraft**-Referenzprofilen (Ausrüstung, Steine, Verzauberungen), Item-Quellen aus **Wowhead**. Deine Spec wird automatisch erkannt — nichts einzustellen.

---

## Funktionen

### 📊 Stat-Ziele aus bloodmallets Sims
Sekundärwert-Ziele pro Spec von bloodmallet.com: ein Ziel für Raid (Einzelziel-Sim), eines für Mythisch+ (Fünf-Ziel-Sim). Statt einfach die beste Verteilung aus dem groben 10-%-Raster zu nehmen, mittelt MetaMirror alle Verteilungen, die höchstens 0,5 % darunter liegen — die Abstände an der Spitze liegen im Sim-Rauschen, und der Mittelwert ergibt ein feineres, ruhigeres Ziel. Deine eigenen Live-Werte werden direkt dagegen verglichen. In der Kopfzeile jedes Tabs steht ein Datenstand, z. B. „Sim-Referenz · 5 Ziele · 2026-09-05", damit du immer siehst, wie aktuell die Zahlen sind.

### 🛡️ Ausrüstungsset aus dem SimulationCraft-Referenzprofil der Season
Ein vollständiges Ausrüstungsset pro Spec — Items, Steine und Verzauberungen — aus dem SimulationCraft-Referenzprofil der aktuellen Season. Pro Spec gibt es genau ein Profil, deshalb gilt dasselbe Set für Mythisch+ und Raid — der Tab sagt das auch, statt so zu tun, als würde der Schalter etwas ändern.

### 🚦 Gear-Ampel
Jede Referenz-Zeile im Ausrüstungs-Tab bekommt eine Ampel: grün, wenn du das Teil angelegt hast, blau, wenn es im Beutel liegt, rot (gedämpft), wenn du es nicht besitzt. Der Aufwertungspfad spielt bewusst keine Rolle — dass eine höhere Gegenstandsstufe besser ist, weiß jeder, das einzufärben wäre nur Lärm. Die Referenzstufe steht stattdessen in einer eigenen Spalte, als Information statt als Wertung.

### 💎 Schmuck-Tierliste
Sim-DPS-Tiers von bloodmallet.com für deine Spec, S bis D. bloodmallet simuliert Schmuck nur im Einzelziel, deshalb teilen sich Mythisch+ und Raid eine Liste — der Tab sagt das auch, statt etwas anderes vorzutäuschen.

### ⬆️ Verbesserungen auf einen Blick
Verzauberungen, Steine und Verbrauchsmaterial für deine Spec auf einer Seite, jeweils mit Quelle.

### 🔔 Referenz-Drop-Alarm
Droppt ein Boss in deiner Gruppe ein Item, das der Ausrüstungs- oder Schmuck-Empfehlung deiner Spec entspricht, meldet MetaMirror es — egal ob du oder ein Gruppenmitglied das Los gewinnt.

### 🏷️ Tooltip-Hinweise
Fährst du über ein Item — Beutefenster, Beutel, Chat-Link, Händler —, hängt MetaMirror Zeilen an den Tooltip an, z. B. „MetaMirror: Referenz für Frost (M+ · Raid)" oder „MetaMirror: S-Tier-Schmuck für Feuer (Raid)". Für alle Specs deiner Klasse, deine aktuelle Spec zuerst, sodass Offspec-Loot sofort auffällt. Ein-/ausschaltbar mit `/mm tooltip`.

### 🔎 Woher kommt das Teil?
Zu jedem Item steht die Quelle: Boss und Instanz direkt aus dem Abenteuerführer, dazu hergestellte Teile, Händler, Tiefen und PvP aus Wowhead.

### 🪟 Genau dort, wo du es brauchst
Das Panel dockt automatisch an dein Charakterfenster an oder öffnet sich überall mit `/mm`. Während des Spielens wird nichts nachgeladen — die Daten liegen dem Addon bei.

---

## Bedienung

- Öffne dein **Charakterfenster** — MetaMirror dockt automatisch rechts daneben an.
- Oder tippe **`/mm`**, um das Fenster überall ein-/auszublenden.
- Wechsle über den Schalter in der Kopfzeile zwischen **M+** und **Raid**.

## Hinweise

- Entwickelt für **World of Warcraft: Midnight** (Interface 120100).
- Item-Quellen werden beim ersten Login nach einem Spiel-Patch aus dem Abenteuerführer gelesen und danach zwischengespeichert — daher gibt es bei späteren Logins keinen wiederkehrenden Ladehänger.
- Daten von **bloodmallet.com** und **SimulationCraft**, Item-Quellen von **Wowhead**.
