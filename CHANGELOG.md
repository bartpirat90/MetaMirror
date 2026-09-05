# Changelog

All notable changes to MetaMirror are listed here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the project uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The text shipped with a CurseForge upload lives in `release/changelog-<version>.md`;
this file is the running history.

## [Unreleased]

Nothing yet.

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

[Unreleased]: https://github.com/bartpirat90/MetaMirror/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/bartpirat90/MetaMirror/releases/tag/v1.0.0
