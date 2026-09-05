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
| **Stats** | Secondary stat targets from bloodmallet.com's sims per spec: one target for Raid (single-target), one for Mythic+ (five targets), compared live against your own gear. The target averages every distribution within 0.5% of the best one, so it is finer than the sim's own 10% grid. |
| **Gear** | A full recommended gear set per spec - items, gems and enchants - taken from the current season's SimulationCraft reference profile. There is one profile per spec, so the set is the same for Mythic+ and Raid; the tab says so. |
| **Trinkets** | Simulated DPS tiers from bloodmallet.com (single-target sim, so Mythic+ and Raid share one list), each entry with its source: boss, craft, vendor, delve or PvP. Rows in gold are the two trinkets the reference profile actually wears - the tier list sims each trinket on its own, the profile is a finished character, so the two orders differ. |
| **Upgrades** | Enchants, gems and consumables for your spec on one page, each with its source. |

Every tab's header shows a data stamp - the sim's fight style and the date the data
was generated, e.g. "sim reference · 5 targets · 2026-09-05" - so you always know how
fresh the numbers are.

The Gear tab marks each reference item with a traffic light: green if you have it
equipped, blue if it's sitting in your bags, dimmed red if you don't have it at all. The
upgrade track deliberately plays no part - owning the item is what the colour answers.
Hovering a row names the reference item level, as information rather than a verdict.

There is also a **reference-drop alert**: when a boss in your group drops an item
matching the gear or trinket recommendation for your spec, MetaMirror flags it, whether
you or a group member wins the roll.

Hovering any item - loot window, bags, chat link, vendor - adds MetaMirror lines to its
tooltip, e.g. "MetaMirror: Reference for Frost (M+ · Raid)", for every spec of your class
with your current spec listed first, so off-spec loot is obvious at a glance. Toggle it
with `/mm tooltip`.

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
  content type, and each spec's secondary-stat distributions (single-target for
  Raid, five-target for Mythic+), which become the Stats-tab target. The sim
  rasters distributions in 10% steps and the gaps at the top are within sim noise,
  so the target is the DPS-weighted average of every distribution within 0.5% of
  the best one rather than the single winner.
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
