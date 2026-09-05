## MetaMirror 1.0.0 — first public release

Stat targets, gear and trinket tiers for your spec, docked to your character sheet.

**Where the data comes from.** Secondary stat distributions and trinket DPS tiers are
simulated by [bloodmallet.com](https://bloodmallet.com); gear, gems and enchants come from
the [SimulationCraft](https://www.simulationcraft.org) reference profile for your spec.
Item sources are resolved through the in-game Adventure Guide and Wowhead. No player
rankings, no log data — everything you see is a simulation result, and the panel names its
data date so you always know how fresh it is.

### What it does

- **Stats** — your live secondary values against the simulated target, as a bar with a
  tolerance band and a gold target marker. Mythic+ and Raid are separate targets.
- **Gear** — the reference profile for your spec, item by item, with a traffic light:
  green if you have it equipped, blue if it's in your bags, dimmed red if you don't have
  it. The upgrade track plays no part — owning the item is what the colour answers.
- **Trinkets** — the full simulated tier list, S to D, including the separate stat modes of
  trinkets that have them. Gold rows mark the two trinkets the reference profile actually
  wears.
- **Upgrades** — enchants, gems and consumables for your spec on one page.
- **Item tooltips** — hovering any item anywhere tells you whether it is a reference item
  or a ranked trinket, for every spec of your class, current spec first. Toggle with
  `/mm tooltip`.
- **Loot alerts** — when a boss in your group drops something on your spec's list,
  MetaMirror says so, whether you or a group member wins the roll.

### Notes on the numbers

- Mythic+ targets are simulated against **five** targets, Raid against a single target.
- A stat target is the DPS-weighted average of the top group of simulated distributions,
  not just the single best one — the simulation grid is coarse and noisy, and averaging the
  leaders is closer to the truth than picking one row off it.
- Gear is the same set for Mythic+ and Raid: the source publishes one reference profile per
  spec, and the panel says so rather than pretending there are two.
- Specs the source has no current profiles for show an honest note instead of stale data.

English and German. `/mm` opens the panel, `/mm help` lists the rest.
