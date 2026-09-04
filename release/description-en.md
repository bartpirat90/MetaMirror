# MetaMirror

**Trinket tiers and item sources, right beside your character sheet.**

MetaMirror ranks trinkets for *your* spec from public simulation data and tells you where each item actually comes from. No browser tabs, no spreadsheets: open your character sheet and the list is right there next to it.

Data is built from **bloodmallet.com** (trinket sim DPS) and **Wowhead** (item sources). Your spec is auto-detected - nothing to configure.

---

## Features

### 💎 Trinket tier list - split by content
Simulated DPS tiers from bloodmallet.com for your spec. Mythic+ and Raid are ranked separately, so the list actually differs between them instead of showing the same order twice.

### 🔎 Where does it come from?
Every trinket carries its source: boss and instance read straight from the in-game Adventure Guide, plus crafted, vendor, delve and PvP items filled in from Wowhead.

### 🪟 Right where you need it
The panel docks to your character sheet automatically, or opens anywhere with `/mm`. Nothing is fetched while you play - the data ships with the addon.

---

## Currently unavailable

The **Stats**, **Gear** and **Upgrades** tabs, and the BiS-drop alert, were fed by an aggregate built from the Warcraft Logs API. On 2026-09-04 RPGLogs confirmed that their Terms of Service do not permit views of data from their sites to be redistributed through other channels, and that addons are specifically named as a channel they do not allow. That data has been removed. Those tabs now show "No data for this spec yet." until a different source is in place.

---

## Usage

- Open your **character sheet** - MetaMirror docks to the right of it automatically.
- Or type **`/mm`** to toggle the window anywhere.
- Switch between **M+** and **Raid** with the toggle in the header.

## Notes

- Built for **World of Warcraft: Midnight** (Interface 120100).
- Item sources are read from the Adventure Guide the first time you log in after a game patch, then cached - so there is no repeated loading hitch on later logins.
- Data from **bloodmallet.com**, item sources from **Wowhead**.
