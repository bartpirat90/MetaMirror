# MetaMirror

**Stat targets, gear and trinket tiers, right beside your character sheet.**

MetaMirror builds stat, gear and trinket recommendations for *your* spec from public simulation data and tells you where each item actually comes from. No browser tabs, no spreadsheets: open your character sheet and the list is right there next to it.

Data is built from **bloodmallet.com** (secondary stat distributions and trinket sim DPS) and **SimulationCraft** reference profiles (gear, gems, enchants), with item sources from **Wowhead**. Your spec is auto-detected - nothing to configure.

---

## Features

### 📊 Stat targets from bloodmallet's sims
Secondary stat targets per spec from bloodmallet.com: one target for Raid (single-target sim), one for Mythic+ (five-target sim). Rather than picking the single best distribution off the sim's coarse 10% grid, MetaMirror averages every distribution within 0.5% of the best - the gaps up there are within sim noise, and the average gives you a finer, steadier target. Your own live stats are compared against it. Every tab's header carries a data stamp, e.g. "sim reference · 5 targets · 2026-09-05", so you always see how fresh the numbers are.

### 🛡️ Gear set from the season's SimulationCraft profile
A full recommended gear set per spec - items, gems and enchants - taken from the current season's SimulationCraft reference profile. There is one profile per spec, so the same set applies to Mythic+ and Raid - the tab says so instead of pretending the toggle changes something.

### 🚦 Gear traffic light
Each reference item on the Gear tab gets a traffic light: green if you've got it equipped at reference item level, amber if it's equipped but below it (Mythic 6/6), blue if it's sitting in your bags, dimmed red if you don't have it at all. Hover the row for the exact item levels.

### 💎 Trinket tier list
Simulated DPS tiers from bloodmallet.com for your spec, S to D. bloodmallet sims trinkets single-target only, so Mythic+ and Raid share one list - the tab says so instead of pretending otherwise.

### ⬆️ Upgrades in one place
Enchants, gems and consumables for your spec on a single page, each with its source.

### 🔔 Reference-drop alert
When a boss in your group drops an item matching your spec's gear or trinket recommendation, MetaMirror flags it - whether you or a group member wins the roll.

### 🏷️ Tooltip hints
Hover any item - loot window, bags, chat link, vendor - and MetaMirror adds lines to its tooltip, e.g. "MetaMirror: Reference for Frost (M+ · Raid)" or "MetaMirror: S-tier trinket for Fire (Raid)". Covers every spec of your class, current spec first, so off-spec loot is obvious right away. Toggle it with `/mm tooltip`.

### 🔎 Where does it come from?
Every item carries its source: boss and instance read straight from the in-game Adventure Guide, plus crafted, vendor, delve and PvP items filled in from Wowhead.

### 🪟 Right where you need it
The panel docks to your character sheet automatically, or opens anywhere with `/mm`. Nothing is fetched while you play - the data ships with the addon.

---

## Usage

- Open your **character sheet** - MetaMirror docks to the right of it automatically.
- Or type **`/mm`** to toggle the window anywhere.
- Switch between **M+** and **Raid** with the toggle in the header.

## Notes

- Built for **World of Warcraft: Midnight** (Interface 120100).
- Item sources are read from the Adventure Guide the first time you log in after a game patch, then cached - so there is no repeated loading hitch on later logins.
- Data from **bloodmallet.com** and **SimulationCraft**, item sources from **Wowhead**.
