# MetaMirror

**Stat-Ziele, Ausrüstung und Schmuck-Wertung, direkt neben deinem Charakterfenster.**

MetaMirror baut Stat-, Ausrüstungs- und Schmuck-Empfehlungen für deine Spezialisierung aus öffentlichen Simulationsdaten und sagt dir, woher jedes Teil stammt. Keine Browser-Tabs, keine Tabellen: Öffne dein Charakterfenster, und die Liste steht direkt daneben.

Die Daten stammen aus **bloodmallet.com** (Sekundärwert-Verteilungen und Schmuck-Sim-DPS) und **SimulationCraft**-Referenzprofilen (Ausrüstung, Steine, Verzauberungen), Item-Quellen aus **Wowhead**. Deine Spec wird automatisch erkannt — nichts einzustellen.

---

## Funktionen

### 📊 Stat-Ziele aus bloodmallets bester Verteilung
Sekundärwert-Ziele pro Spec, aus bloodmallet.coms bester Sekundärwert-Verteilung: ein Ziel für Raid (Einzelziel-Sim), drei für Mythisch+ (Mehrziel-Sim). Deine eigenen Live-Werte werden direkt dagegen verglichen.

### 🛡️ Ausrüstungsset aus dem SimulationCraft-Referenzprofil der Season
Ein vollständiges Ausrüstungsset pro Spec — Items, Steine und Verzauberungen — aus dem SimulationCraft-Referenzprofil der aktuellen Season.

### 💎 Schmuck-Tierliste — getrennt nach Inhalt
Sim-DPS-Tiers von bloodmallet.com für deine Spec. Mythisch+ und Raid werden getrennt gewertet, sodass sich die Liste tatsächlich unterscheidet, statt zweimal dieselbe Reihenfolge zu zeigen.

### ⬆️ Verbesserungen auf einen Blick
Verzauberungen, Steine und Verbrauchsmaterial für deine Spec auf einer Seite, jeweils mit Quelle.

### 🔔 BiS-Drop-Alarm
Droppt ein Boss in deiner Gruppe ein Item, das der Ausrüstungs- oder Schmuck-Empfehlung deiner Spec entspricht, meldet MetaMirror es — egal ob du oder ein Gruppenmitglied das Los gewinnt.

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
