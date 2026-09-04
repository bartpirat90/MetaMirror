<img src="release/branding/logo-horizontal.png" alt="MetaMirror" width="420">

**Trinket tiers and item sources, right beside your character sheet.** A World of
Warcraft addon for *Midnight* (Interface 120100).

MetaMirror ranks trinkets for *your* spec from public simulation data and tells you
where each item actually comes from. No browser tabs: open your character sheet and
the list is right there next to it. Your spec is auto-detected, there is nothing to
configure.

---

## What it does

| Tab | What you get |
| --- | --- |
| **Trinkets** | Simulated DPS tiers from bloodmallet.com, ranked separately for Mythic+ and Raid, each entry with its source: boss, craft, vendor, delve or PvP. |

Type `/mm` to toggle the window, or just open your character sheet.

> **Stats, Gear and Upgrades are empty right now, and the BiS-drop alert is off.**
> Those parts were fed by an aggregate built from the Warcraft Logs API, which had
> to be removed (see *About Warcraft Logs* below). Until a different data source is
> in place, they show "No data for this spec yet."

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
bloodmallet.com  ─┬─►  pipeline/  ─►  Data/MetaMirrorTrinkets.lua
Wowhead          ─┘                   Data/MetaMirrorSources.lua
```

- **bloodmallet.com** supplies simulated trinket DPS per spec and content type.
- **Wowhead** fills in item sources the Adventure Guide does not carry, such as
  crafted, vendor, delve and PvP trinkets.

### About Warcraft Logs

Earlier versions of this addon shipped an aggregate built from the Warcraft Logs
API — what top parses actually wear and use. **That data has been removed.**

On 2026-09-04 RPGLogs confirmed in writing that their Terms of Service do not
permit views of data from their sites to be redistributed through other channels,
and that addons are specifically named as a channel they do not allow. The weekly
refresh has been switched off, the generated file is gone from this repository and
its history, and the addon no longer loads or displays it. Please do not send pull
requests that reintroduce it.

## Development

```bash
python -m pytest pipeline/ -q
```

In-game diagnostics live behind `/mm`: `status` for panel state, `scansrc` to rebuild
and inspect the item-source index, `dumpsrc`, `dumpench`, `dumpgems` for raw dumps.

---

Data from [bloodmallet.com](https://bloodmallet.com/). Item sources from
[Wowhead](https://www.wowhead.com/). Not affiliated with Blizzard Entertainment.
