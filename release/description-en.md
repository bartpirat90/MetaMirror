# MetaMirror

**Stat targets, gear and trinket tiers, right beside your character sheet.**

MetaMirror builds stat, gear and trinket recommendations for *your* spec from public simulation data and tells you where each item actually comes from. No browser tabs, no spreadsheets: open your character sheet and the list is right there next to it.

Data is built from **bloodmallet.com** (secondary stat distributions and trinket sim DPS) and **SimulationCraft** reference profiles (gear, gems, enchants), with item sources from **Wowhead**. Your spec is auto-detected - nothing to configure.

---

## Features

### 📊 Stat targets from bloodmallet's best distribution
Secondary stat targets per spec, taken from bloodmallet.com's best-performing secondary stat distribution: one target for Raid (single-target sim), three for Mythic+ (multi-target sim). Your own live stats are compared against them.

### 🛡️ Gear set from the season's SimulationCraft profile
A full recommended gear set per spec - items, gems and enchants - taken from the current season's SimulationCraft reference profile.

### 💎 Trinket tier list - split by content
Simulated DPS tiers from bloodmallet.com for your spec. Mythic+ and Raid are ranked separately, so the list actually differs between them instead of showing the same order twice.

### ⬆️ Upgrades in one place
Enchants, gems and consumables for your spec on a single page, each with its source.

### 🔔 BiS-drop alert
When a boss in your group drops an item matching your spec's gear or trinket recommendation, MetaMirror flags it - whether you or a group member wins the roll.

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
