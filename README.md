<img src="release/branding/logo-horizontal.png" alt="MetaMirror" width="420">

**Top-player meta, mirrored to your character.** A World of Warcraft addon for
*Midnight* (Interface 120100).

MetaMirror shows what the best players of *your* spec are running and holds it up
against your own character, live. No browser tabs, no spreadsheets: open your
character sheet and the meta is right there next to it. Your spec is auto-detected,
there is nothing to configure.

![MetaMirror next to the character sheet](release/gallery/00-hero.png)

---

## What it does

| Tab | What you get |
| --- | --- |
| **Stats** | Every secondary stat against the top-player target: fill bar, target marker, your live rating. Swap a piece of gear and the bars move instantly. |
| **Gear** | The meta piece per slot with **where it drops**, read from the in-game Adventure Guide, plus how many top players use it and what you already own. |
| **Trinkets** | Sim tiers from bloodmallet.com, re-ordered by real top-player usage. Mythic+ and Raid are ranked separately. |
| **Upgrades** | The exact enchants, gems and consumables the top players run. |

On top of that, a **BiS-drop alert**: when a top-tier item drops for someone in your
group, MetaMirror flags it and offers a one-click polite whisper to ask for it.

Type `/mm` to toggle the window, or just open your character sheet.

## Install

Grab it from CurseForge, or copy the addon files into
`World of Warcraft/_retail_/Interface/AddOns/MetaMirror/`. Only the files listed in
`MetaMirror.toc` plus `Icon.tga` and `bar-mask.tga` belong there; everything else in
this repository is build tooling.

---

## How the data is made

The addon ships with a pre-built data file. It is not fetched at runtime, so the
addon never talks to the network while you play.

```
Warcraft Logs API  ─┐
bloodmallet.com    ─┼─►  pipeline/  ─►  Data/MetaMirrorData.lua
Wowhead            ─┘                   Data/MetaMirrorSources.lua
```

- **Warcraft Logs** supplies the top parses per spec and content type. The pipeline
  reads each player's gear, stats and consumables and aggregates what the field
  actually runs, 50 parses per spec and content type.
- **bloodmallet.com** supplies trinket sim DPS, which is then re-ranked by real usage.
- **Wowhead** fills in item sources the Adventure Guide does not carry, such as
  crafted, vendor, delve and PvP trinkets.

A season filter keeps last season's items out. It works on gear track bonus IDs
rather than item level, because item level alone stops separating seasons once the
sample gets large.

Run it yourself:

```bash
pip install -r pipeline/requirements.txt
python -m pipeline.run --out Data/MetaMirrorData.lua
```

A run takes a good two hours and pauses on its own when the Warcraft Logs point
budget runs out. If it is interrupted, `python -m pipeline.run --resume` continues
from the last finished spec instead of starting over. Credentials go into
`pipeline/local_secrets.json`, which is excluded from version control.

## Automation

`.github/workflows/update-data.yml` refreshes the data every Monday. It runs the
test suite, rebuilds both data files, checks their Lua syntax, and commits only when
something actually changed. On a real change it also bumps the patch version so each
CurseForge upload gets a unique file name. Publishing stays off until the repository
variable `CF_PUBLISH` is set to `true`. See [pipeline/CURSEFORGE.md](pipeline/CURSEFORGE.md).

## Development

```bash
python -m pytest pipeline/ -q
```

In-game diagnostics live behind `/mm`: `status` for panel state, `scansrc` to rebuild
and inspect the item-source index, `dumpsrc`, `dumpench`, `dumpgems` for raw dumps.

---

Data from [Warcraft Logs](https://www.warcraftlogs.com/) and
[bloodmallet.com](https://bloodmallet.com/). Item sources from
[Wowhead](https://www.wowhead.com/). Not affiliated with Blizzard Entertainment.
