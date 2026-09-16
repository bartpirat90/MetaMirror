# Changelog

All notable changes to MetaMirror are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The text shipped with a CurseForge upload lives in `release/changelog-<version>.md`;
this file is the running history.

Versions 1.0.1 and 1.0.2 were produced by the weekly `sim-data` workflow, which rebuilds
`Data/MetaMirrorData.lua` from the sources and bumps the patch version. **No addon code
changed in either one** — the only files touched are the data file and the `.toc`. Neither
version is tagged in git, and neither has been uploaded to CurseForge, where 1.0.0 is still
the current file. The trinket tier list is not part of this refresh: the workflow rebuilds
the stat and gear data only, so trinket rankings still carry the `bm-2026-09-05` date in
both versions.

## [Unreleased]

Nothing yet.

## [1.0.2] - 2026-09-14

Weekly data refresh. Built from bloodmallet distributions of 2026-09-14 and
SimulationCraft profiles at `ba72a9d`; 28 of 39 specs now carry data, in 56 spec/content
entries.

### Added

- **Feral Druid** appears for the first time, for both Mythic+ and Raid. It is the 28th
  spec with data.

### Fixed

- **Fury Warrior and Frost Mage have their Raid data back**, after both were missing it in
  1.0.1.

### Changed

- Secondary stat priorities moved for twelve spec/content combinations. The leading stat
  changed for five of them:
  - Windwalker Monk, Mythic+ and Raid: `haste > mastery` became `mastery > haste`
  - Havoc Demon Hunter, Mythic+ and Raid: `mastery > crit` went back to `crit > mastery`,
    reversing the swap 1.0.1 had made
  - Arcane Mage, Mythic+: `crit > vers > haste` became `vers > haste > crit`
- The other seven reshuffled ranks below the top: Arms Warrior (M+), Vengeance Demon Hunter
  (Raid), Protection Paladin (Raid), Retribution Paladin (M+), Shadow Priest (M+),
  Enhancement Shaman (Raid) and Destruction Warlock (M+).
- Thirty further entries kept their order but shifted in the underlying rating numbers.
- Reference gear changed in six entries, 22 slots in total, concentrated in the rings and
  trinkets (four entries each for `RING1`, `RING2` and `TRINKET1`).

## [1.0.1] - 2026-09-07

Weekly data refresh. Built from bloodmallet distributions of 2026-09-07 and
SimulationCraft profiles at `aa9de89`.

### Removed

- **Fury Warrior and Frost Mage lost their Raid entry** — the source returned nothing
  usable for those two in this run, and the pipeline writes only what it actually receives
  rather than carrying old numbers forward. Their tab showed the "no current profile" note
  for a week. Both came back in 1.0.2. Spec coverage dipped from 54 entries to 52.

### Changed

- Secondary stat priorities moved for twelve spec/content combinations. The leading stat
  changed for seven of them:
  - Arms Warrior, Raid: `haste > crit` became `crit > haste`
  - Havoc Demon Hunter, Mythic+ and Raid: `crit > mastery` became `mastery > crit`
  - Retribution Paladin, Raid: `haste > crit > mastery` became `crit > mastery > haste`
  - Beast Mastery Hunter, Raid: `mastery > haste` became `haste > mastery`
  - Arcane Mage, Mythic+: `haste > crit > vers` became `crit > vers > haste`
  - Arcane Mage, Raid: `crit > mastery` became `mastery > crit`
- The other five reshuffled ranks below the top: Protection Warrior (M+ and Raid),
  Vengeance Demon Hunter (M+), Protection Paladin (Raid) and Outlaw Rogue (Raid).
- Thirty-three further entries kept their order but shifted in the underlying rating
  numbers.
- Reference gear changed in a single entry, across three slots.

## [1.0.0] - 2026-09-05

First public release.

### Added

- **Stats tab** — your live secondary values against the simulated target, as a bar with a
  tolerance band and a target marker. Mythic+ and Raid carry separate targets: Mythic+ is
  simulated against five targets, Raid against a single one.
- **Gear tab** — the SimulationCraft reference profile for your spec, item by item, with a
  traffic light: green if you have it equipped, blue if it is in your bags, dimmed red if
  you do not have it. The upgrade track plays no part in the colour.
- **Trinkets tab** — the full simulated tier list from bloodmallet.com, S to D, including
  the separate stat modes of trinkets that have them. Gold rows mark the two trinkets the
  reference profile on the Gear tab actually wears.
- **Upgrades tab** — enchants, gems and consumables for your spec on one page, each with
  its source.
- **Item tooltips** — hovering any item anywhere says whether it is a reference item or a
  ranked trinket, for every spec of your class, current spec first. Toggle with
  `/mm tooltip`.
- **Loot alerts** — when a boss in your group drops something on your spec's list,
  MetaMirror says so, whether you or a group member wins the roll.
- **Item sources** — boss and instance read from the in-game Adventure Guide on the first
  login after a game patch and then cached; crafted, vendor, delve and PvP items filled in
  from Wowhead.
- English and German localisation. `/mm` opens the panel, `/mm help` lists the rest.

### Notes on the data

- Everything shown is a simulation result: secondary distributions and trinket DPS from
  [bloodmallet.com](https://bloodmallet.com), gear/gems/enchants from the
  [SimulationCraft](https://www.simulationcraft.org) reference profile for the spec. No
  player rankings and no log data are used.
- A stat target is the DPS-weighted average of the top group of simulated distributions
  rather than the single best row — the simulation grid is coarse, and averaging the
  leaders sits closer to the truth than picking one row off it.
- Gear is the same set for Mythic+ and Raid, because the source publishes one reference
  profile per spec. The tab says so instead of pretending there are two.
- Specs the source has no current profile for show an honest note instead of stale data.
- Every tab header carries the data date, e.g. `sim reference · 5 targets · 2026-09-05`.

[Unreleased]: https://github.com/bartpirat90/MetaMirror/compare/bdb929c...HEAD
[1.0.2]: https://github.com/bartpirat90/MetaMirror/compare/8bc7be5...bdb929c
[1.0.1]: https://github.com/bartpirat90/MetaMirror/compare/v1.0.0...8bc7be5
[1.0.0]: https://github.com/bartpirat90/MetaMirror/releases/tag/v1.0.0
