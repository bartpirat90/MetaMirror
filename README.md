<img src="release/branding/logo-horizontal.png" alt="MetaMirror" width="420">

**Stat targets, gear and trinket tiers, right beside your character sheet.** A World
of Warcraft addon for *Midnight* (Interface 120100).

MetaMirror builds stat, gear and trinket recommendations for *your* spec from public
simulation data and tells you where each item actually comes from. No browser tabs:
open your character sheet and the list is right there next to it. Your spec is
auto-detected, there is nothing to configure.

---

## What it does

| Tab | What you get |
| --- | --- |
| **Stats** | Secondary stat targets from bloodmallet.com's best secondary-stat distribution per spec: one target for Raid (single-target sim), three for Mythic+ (multi-target sim), compared live against your own gear. |
| **Gear** | A full recommended gear set per spec - items, gems and enchants - taken from the current season's SimulationCraft reference profile. |
| **Trinkets** | Simulated DPS tiers from bloodmallet.com (single-target sim, so Mythic+ and Raid share one list), each entry with its source: boss, craft, vendor, delve or PvP. |
| **Upgrades** | Enchants, gems and consumables for your spec on one page, each with its source. |

Every tab's header shows a data stamp - the sim's fight style and the date the data
was generated, e.g. "sim reference · 3 targets · 2026-09-04" - so you always know how
fresh the numbers are.

The Gear tab marks each reference item with a traffic light: green if it's equipped at
reference item level, amber if it's equipped but below it (Mythic 6/6), blue if it's in
your bags, and dimmed red if you don't have it. The tooltip on each row spells out the
exact item levels.

There is also a **BiS-drop alert**: when a boss in your group drops an item matching
the gear or trinket recommendation for your spec, MetaMirror flags it, whether you or
a group member wins the roll.

Hovering any item - loot window, bags, chat link, vendor - adds MetaMirror lines to its
tooltip, e.g. "MetaMirror: BiS for Frost (M+ · Raid)", for every spec of your class with
your current spec listed first, so off-spec loot is obvious at a glance. Toggle it with
`/mm tooltip`.

Type `/mm` to toggle the window, or just open your character sheet.

## Install

Grab it from CurseForge, or copy the addon files into
`World of Warcraft/_retail_/Interface/AddOns/MetaMirror/`. Only the files listed in
`MetaMirror.toc` plus `Icon.tga` and `bar-mask.tga` belong there; everything else in
this repository is build tooling.

---

## How the data is made

The addon ships with pre-built data files. Nothing is fetched at runtime, so the
addon never talks to the network while you play.

```
bloodmallet.com        ─┬─►  pipeline/  ─┬─►  Data/MetaMirrorData.lua
SimulationCraft profiles┘                ├─►  Data/MetaMirrorTrinkets.lua
Wowhead                 ────────────────►┴─►  Data/MetaMirrorSources.lua
```

- **bloodmallet.com** supplies two things: simulated trinket DPS per spec and
  content type, and each spec's best secondary-stat distribution (single-target
  for Raid, three-target for Mythic+), which becomes the Stats-tab target.
- **SimulationCraft reference profiles** (the `simc` project's own per-spec
  profiles for the current season) supply the recommended gear, gems and
  enchants shown on the Gear and Upgrades tabs.
- **Wowhead** fills in item sources the Adventure Guide does not carry, such as
  crafted, vendor, delve and PvP items.

A weekly job re-runs the simulations and reference profiles and commits the
refreshed data; there is no "top players" telemetry involved anywhere in this
pipeline.

### About Warcraft Logs

Earlier versions of this addon shipped an aggregate built from the Warcraft Logs
API. On 2026-09-04 RPGLogs confirmed in writing that their Terms of Service do
not permit that data to be redistributed through other channels, addons
specifically included, so it was removed from the addon and this repository's
history. Please do not send pull requests that reintroduce it.

## Development

```bash
python -m pytest pipeline/ -q
```

In-game diagnostics live behind `/mm`: `status` for panel state, `scansrc` to rebuild
and inspect the item-source index, `dumpsrc`, `dumpench`, `dumpgems` for raw dumps,
`tooltip` to toggle the item-tooltip hints.

---

Data from [bloodmallet.com](https://bloodmallet.com/) and
[SimulationCraft](https://github.com/simulationcraft/simc). Item sources from
[Wowhead](https://www.wowhead.com/). Not affiliated with Blizzard Entertainment.
