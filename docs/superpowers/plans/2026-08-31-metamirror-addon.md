# MetaMirror Addon Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Das MetaMirror-Addon (Teilsystem 1) bauen — ein an den Charakterbildschirm angedocktes Tab-Panel, das die Top-Spieler-Meta pro Spec zeigt und die eigenen Sekundärwerte live dagegen vergleicht — gegen einen kleinen, von Hand angelegten Beispiel-Datensatz.

**Architecture:** Mehrere fokussierte Lua-Dateien mit klaren Rollen: Lokalisierung, Bootstrap/DB/Events, Beispieldaten, reine Logik + Selbsttest, Live-Spieler-Status, UI. Reine Entscheidungslogik ist von den Live-/UI-Teilen getrennt und per In-Game-Selbsttest geprüft. Das UI liest ausschließlich über die Datenzugriffsschicht — dieselbe Schnittstelle, die später die Pipeline füllt.

**Tech Stack:** WoW-Addon (Lua 5.1, Interface 120100). APIs: `GetSpecialization`/`UnitClass`, Sekundärwerte via `GetHaste`/`GetCritChance`/`GetMasteryEffect`/`GetCombatRatingBonus`/`GetCombatRating`, `CharacterFrame:HookScript`. Keine „secret values", kein Netzwerk.

**Deployment:** Quelle `E:\claude-projekt\MetaMirror\`. Nach jeder Task nach `D:\Battle.net\World of Warcraft\_retail_\Interface\AddOns\MetaMirror\` kopieren, im Spiel `/reload`, prüfen.

**Fallen-Abgleich (aus KeyRoulette/AutoRole):**
- **Secret values:** Nur **eigene** Charakterwerte lesen (unkritisch). Keine fremden Units, kein Combat-Log.
- **Ladereihenfolge:** Jede Datei beginnt mit `MetaMirror = MetaMirror or {}`, damit die Reihenfolge robust ist.
- **Lange DE-Labels:** Panel breit genug; Labels testen.
- **Kein `SendChatMessage`**, nur `print` fürs Feedback.
- **TGA statt PNG**, falls Icons nötig werden (hier zunächst keine).

---

## Dateistruktur

Ladereihenfolge in der TOC:

1. `Localization.lua` — `MetaMirror.L` (EN-Basis + `deDE`-Override).
2. `MetaMirror.lua` — Namespace, Farbpalette `MetaMirror.C`, `MetaMirrorDB`-Init, Event-Frame, Slash `/mm`.
3. `Data/SampleData.lua` — von Hand gepflegter `MetaMirrorData`-Beispieldatensatz (Waffen-Krieger, Frost-Magier; je M+ und Raid).
4. `Logic.lua` — reine Funktionen: `DataFor`, `StatStatus`, `TargetRating`.
5. `Player.lua` — Live: aktuelle Spec/Klasse, eigene Sekundärwerte (Prozent + Wertung).
6. `SelfTest.lua` — Testharness + Tests der reinen Logik.
7. `UI.lua` — Panel, Tabs, Renderer, Andockung an `CharacterFrame`.

Jede Datei ist eigenständig verständlich: Logik kennt keine Frames, Player kennt kein UI, UI liest nur über `DataFor` + `Player`.

---

### Task 1: TOC, Bootstrap, Lokalisierung

**Files:**
- Create: `E:\claude-projekt\MetaMirror\MetaMirror.toc`
- Create: `E:\claude-projekt\MetaMirror\Localization.lua`
- Create: `E:\claude-projekt\MetaMirror\MetaMirror.lua`

- [ ] **Step 1: TOC anlegen**

`MetaMirror.toc`:
```
## Interface: 120100
## Title: MetaMirror
## Notes: Zeigt die Top-Spieler-Meta pro Spec und vergleicht deine Sekundaerwerte live dagegen.
## Author: Franz Petschull
## Version: 0.1
## SavedVariablesPerCharacter: MetaMirrorDB

Localization.lua
MetaMirror.lua
Data\SampleData.lua
Logic.lua
Player.lua
SelfTest.lua
UI.lua
```

- [ ] **Step 2: Lokalisierung anlegen**

`Localization.lua`:
```lua
MetaMirror = MetaMirror or {}
local L = {}

-- Basis: Englisch
L.title        = "MetaMirror"
L.tab_stats    = "Stats"
L.tab_talents  = "Talents"
L.tab_gear     = "Gear"
L.tab_gems     = "Gems/Ench."
L.tab_cons     = "Consumables"
L.ctx_mplus    = "M+"
L.ctx_raid     = "Raid"
L.autodetect   = "auto-detected"
L.no_data      = "No data for this spec yet."
L.target       = "Target"
L.need         = "%d%% short"
L.over         = "%d%% too much"
L.on_target    = "on target"
L.copy_hint    = "Click to select, then Ctrl+C"
L.usage        = "used by %d%% of top players"
L.stat_haste   = "Haste"
L.stat_crit    = "Crit"
L.stat_mastery = "Mastery"
L.stat_vers    = "Versatility"
L.slash_hint   = "MetaMirror: /mm opens or closes the panel."

if GetLocale() == "deDE" then
    L.tab_talents  = "Talente"
    L.tab_cons     = "Verbrauch"
    L.autodetect   = "automatisch erkannt"
    L.no_data      = "Fuer diese Spec liegen noch keine Daten vor."
    L.target       = "Ziel"
    L.need         = "%d%% fehlen"
    L.over         = "%d%% zu viel"
    L.on_target    = "im Ziel"
    L.copy_hint    = "Anklicken, dann Strg+C"
    L.usage        = "von %d%% der Top-Spieler genutzt"
    L.stat_haste   = "Tempo"
    L.stat_crit    = "Krit"
    L.stat_mastery = "Meisterschaft"
    L.stat_vers    = "Vielseitigkeit"
    L.slash_hint   = "MetaMirror: /mm oeffnet oder schliesst das Panel."
end

MetaMirror.L = L
```

- [ ] **Step 3: Bootstrap anlegen (Namespace, Palette, DB, Events, Slash)**

`MetaMirror.lua`:
```lua
MetaMirror = MetaMirror or {}
local ADDON = "MetaMirror"

-- Crystal-Violet-Palette (wie KeyRoulette/AutoRole)
MetaMirror.C = {
    BG_MAIN   = {0.086, 0.078, 0.122, 0.97},
    HEAD      = {0.082, 0.075, 0.153, 1.0},
    PANEL2    = {0.137, 0.125, 0.259, 1.0},
    BORDER    = {0.227, 0.184, 0.420, 1.0},
    VIOLET    = {0.659, 0.333, 0.969, 1.0},
    VIOLET_S  = {0.769, 0.710, 0.992, 1.0},
    SEC       = {0.655, 0.545, 0.980, 1.0},
    TXT       = {0.929, 0.914, 0.996, 1.0},
    DIM       = {0.604, 0.573, 0.753, 1.0},
    GOLD      = {1.0,   0.820, 0.0,   1.0},
    GREEN     = {0.290, 0.871, 0.502, 1.0},
    AMBER     = {0.984, 0.749, 0.141, 1.0},
    BLUE      = {0.376, 0.647, 0.980, 1.0},
    ITEM      = {0.639, 0.816, 1.0,   1.0},
}

function MetaMirror.InitDB()
    MetaMirrorDB = MetaMirrorDB or {}
    local db = MetaMirrorDB
    if db.content == nil then db.content = "mythicplus" end  -- "mythicplus" | "raid"
    if db.tab     == nil then db.tab = "stats" end
    if db.tol     == nil then db.tol = 1.5 end               -- Toleranzband in %-Punkten
    db.pos = db.pos or { point = "TOPLEFT", rel = "TOPRIGHT", x = 4, y = 0 }
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        MetaMirror.InitDB()
    elseif event == "PLAYER_LOGIN" then
        MetaMirror.InitDB()
        if MetaMirror.BuildPanel then MetaMirror:BuildPanel() end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if MetaMirror.Refresh then MetaMirror:Refresh() end
    end
end)

SLASH_METAMIRROR1 = "/mm"
SLASH_METAMIRROR2 = "/metamirror"
SlashCmdList["METAMIRROR"] = function()
    if MetaMirror.Toggle then MetaMirror:Toggle() end
end
```

- [ ] **Step 4: Deployen und prüfen**

WoW-Ordner anlegen und kopieren, dann `/reload`:
```bash
mkdir -p "D:/Battle.net/World of Warcraft/_retail_/Interface/AddOns/MetaMirror/Data"
cp "E:/claude-projekt/MetaMirror/MetaMirror.toc" "E:/claude-projekt/MetaMirror/Localization.lua" "E:/claude-projekt/MetaMirror/MetaMirror.lua" "D:/Battle.net/World of Warcraft/_retail_/Interface/AddOns/MetaMirror/"
```
Run im Spiel: `/run MetaMirror.InitDB(); print(MetaMirrorDB.content, MetaMirrorDB.tol, MetaMirror.L.target)`
Erwartet: `mythicplus  1.5  Ziel` (deDE) bzw. `... Target` (enUS). Keine Ladefehler.

(Hinweis: `Data\SampleData.lua`, `Logic.lua`, `Player.lua`, `SelfTest.lua`, `UI.lua` sind in der TOC gelistet, existieren aber noch nicht — WoW ignoriert fehlende Dateien mit einer Lademeldung. Ab Task 2 sind sie da. Für einen sauberen Ladebildschirm die noch fehlenden Zeilen erst hinzufügen, wenn die Datei existiert — optional.)

- [ ] **Step 5: Commit**
```bash
cd /e/claude-projekt/MetaMirror && git add -A && git commit -m "feat: toc, bootstrap, localization"
```

---

### Task 2: Beispieldaten

**Files:**
- Create: `E:\claude-projekt\MetaMirror\Data\SampleData.lua`

- [ ] **Step 1: Beispieldatensatz anlegen** (Waffen-Krieger `1/71`, Frost-Magier `8/64`; je `mythicplus` und `raid`)

`Data/SampleData.lua`:
```lua
-- Von Hand gepflegter Beispieldatensatz. Struktur = Datenvertrag der Spec.
-- Wird spaeter durch generierte Pipeline-Daten ersetzt.
MetaMirrorData = {
    version = "sample-2026-08-31",
    specs = {
        [1] = { -- Krieger
            [71] = { -- Waffen
                mythicplus = {
                    sampleSize = 100,
                    stats = {
                        { key = "haste",   pct = 34.0 },
                        { key = "crit",    pct = 28.0 },
                        { key = "mastery", pct = 22.0 },
                        { key = "vers",    pct = 16.0 },
                    },
                    talents = { { importString = "SAMPLE-ARMS-MPLUS", usagePct = 68 } },
                    gear = {
                        { slot = "HEAD",     itemID = 0, name = "Helm der Meta" },
                        { slot = "NECK",     itemID = 0, name = "Amulett der Meta" },
                        { slot = "SHOULDER", itemID = 0, name = "Schultern der Meta" },
                        { slot = "CHEST",    itemID = 0, name = "Robe der Meta" },
                        { slot = "MAINHAND", itemID = 0, name = "Klinge der Meta" },
                    },
                    gems     = { { slot = "RING1", itemID = 0, name = "+Tempo" } },
                    enchants = { { slot = "WEAPON", id = 0, name = "Waffe: Tempo" } },
                    consumables = { flask = 0, potion = 0, food = 0, rune = 0 },
                },
                raid = {
                    sampleSize = 100,
                    stats = {
                        { key = "haste",   pct = 30.0 },
                        { key = "crit",    pct = 32.0 },
                        { key = "mastery", pct = 22.0 },
                        { key = "vers",    pct = 16.0 },
                    },
                    talents = { { importString = "SAMPLE-ARMS-RAID", usagePct = 61 } },
                    gear = {
                        { slot = "HEAD", itemID = 0, name = "Raid-Helm" },
                        { slot = "NECK", itemID = 0, name = "Raid-Amulett" },
                    },
                    gems     = { { slot = "RING1", itemID = 0, name = "+Krit" } },
                    enchants = { { slot = "WEAPON", id = 0, name = "Waffe: Krit" } },
                    consumables = { flask = 0, potion = 0, food = 0, rune = 0 },
                },
            },
        },
        [8] = { -- Magier
            [64] = { -- Frost
                mythicplus = {
                    sampleSize = 100,
                    stats = {
                        { key = "haste",   pct = 25.0 },
                        { key = "crit",    pct = 33.0 },
                        { key = "mastery", pct = 20.0 },
                        { key = "vers",    pct = 22.0 },
                    },
                    talents = { { importString = "SAMPLE-FROST-MPLUS", usagePct = 72 } },
                    gear = { { slot = "HEAD", itemID = 0, name = "Frost-Kapuze" } },
                    gems     = { { slot = "RING1", itemID = 0, name = "+Krit" } },
                    enchants = { { slot = "WEAPON", id = 0, name = "Waffe: Intelligenz" } },
                    consumables = { flask = 0, potion = 0, food = 0, rune = 0 },
                },
                raid = {
                    sampleSize = 100,
                    stats = {
                        { key = "haste",   pct = 22.0 },
                        { key = "crit",    pct = 36.0 },
                        { key = "mastery", pct = 20.0 },
                        { key = "vers",    pct = 22.0 },
                    },
                    talents = { { importString = "SAMPLE-FROST-RAID", usagePct = 65 } },
                    gear = { { slot = "HEAD", itemID = 0, name = "Frost-Raidkapuze" } },
                    gems     = { { slot = "RING1", itemID = 0, name = "+Vielseitigkeit" } },
                    enchants = { { slot = "WEAPON", id = 0, name = "Waffe: Intelligenz" } },
                    consumables = { flask = 0, potion = 0, food = 0, rune = 0 },
                },
            },
        },
    },
}
```

- [ ] **Step 2: Deployen und prüfen**
```bash
cp "E:/claude-projekt/MetaMirror/Data/SampleData.lua" "D:/Battle.net/World of Warcraft/_retail_/Interface/AddOns/MetaMirror/Data/"
```
Run: `/run local d=MetaMirrorData.specs[1][71].mythicplus; print(d.stats[1].key, d.stats[1].pct, d.talents[1].usagePct)`
Erwartet: `haste  34  68`.

- [ ] **Step 3: Commit**
```bash
cd /e/claude-projekt/MetaMirror && git add -A && git commit -m "feat: hand-curated sample data (arms warrior, frost mage)"
```

---

### Task 3: Reine Logik

**Files:**
- Create: `E:\claude-projekt\MetaMirror\Logic.lua`

- [ ] **Step 1: Logik-Funktionen anlegen**

`Logic.lua`:
```lua
MetaMirror = MetaMirror or {}

-- Datenzugriff: liefert den <specContent> oder nil.
function MetaMirror:DataFor(classID, specID, content)
    local specs = MetaMirrorData and MetaMirrorData.specs
    local c = specs and specs[classID]
    local s = c and c[specID]
    return s and s[content] or nil
end

-- Status eines Stats: "under" | "on" | "over" anhand Toleranzband (in %-Punkten).
function MetaMirror:StatStatus(currentPct, targetPct, tol)
    tol = tol or 0
    if math.abs(currentPct - targetPct) <= tol then return "on" end
    if currentPct < targetPct then return "under" end
    return "over"
end

-- Ziel-Wertung aus dem aktuellen Verhaeltnis rating/pct hochrechnen.
-- Ohne gueltiges Verhaeltnis (pct <= 0) nicht bestimmbar -> nil.
function MetaMirror:TargetRating(currentRating, currentPct, targetPct)
    if not currentPct or currentPct <= 0 then return nil end
    return math.floor((currentRating / currentPct) * targetPct + 0.5)
end
```

- [ ] **Step 2: Deployen** (Selbsttest folgt in Task 5 zusammen mit der Harness)
```bash
cp "E:/claude-projekt/MetaMirror/Logic.lua" "D:/Battle.net/World of Warcraft/_retail_/Interface/AddOns/MetaMirror/"
```
Run: `/run print(MetaMirror:StatStatus(28,34,1.5), MetaMirror:StatStatus(34,34,1.5), MetaMirror:TargetRating(8420,28,34))`
Erwartet: `under  on  10230`.

- [ ] **Step 3: Commit**
```bash
cd /e/claude-projekt/MetaMirror && git add -A && git commit -m "feat: pure logic (data access, stat status, target rating)"
```

---

### Task 4: Live-Spieler-Status

**Files:**
- Create: `E:\claude-projekt\MetaMirror\Player.lua`

- [ ] **Step 1: Spieler-Layer anlegen**

`Player.lua`:
```lua
MetaMirror = MetaMirror or {}

-- Zuordnung Stat-Key -> (Prozent-Funktion, Wertungs-CR-Konstante, Label-Key)
local STAT_MAP = {
    haste   = { pct = function() return GetHaste() end,
                cr = CR_HASTE_SPELL,               label = "stat_haste" },
    crit    = { pct = function() return GetCritChance() end,
                cr = CR_CRIT_SPELL,                label = "stat_crit" },
    mastery = { pct = function() return GetMasteryEffect() end,
                cr = CR_MASTERY,                   label = "stat_mastery" },
    vers    = { pct = function() return GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) end,
                cr = CR_VERSATILITY_DAMAGE_DONE,   label = "stat_vers" },
}
MetaMirror.STAT_MAP = STAT_MAP

-- Aktuelle Klasse/Spec als IDs; nil, wenn keine Spec gewaehlt.
function MetaMirror:CurrentSpecKey()
    local _, _, classID = UnitClass("player")
    local specIndex = GetSpecialization()
    if not specIndex then return classID, nil end
    local specID = GetSpecializationInfo(specIndex)
    return classID, specID
end

-- Eigener Sekundaerwert eines Keys: { pct = <number>, rating = <number> }.
-- Nur eigene Charakterwerte -> keine secret values.
function MetaMirror:SecondaryFor(key)
    local m = STAT_MAP[key]
    if not m then return { pct = 0, rating = 0 } end
    local ok, pct = pcall(m.pct)
    local rating = GetCombatRating(m.cr) or 0
    return { pct = (ok and pct) or 0, rating = rating }
end
```

- [ ] **Step 2: Deployen und prüfen (auf dem eigenen Charakter)**
```bash
cp "E:/claude-projekt/MetaMirror/Player.lua" "D:/Battle.net/World of Warcraft/_retail_/Interface/AddOns/MetaMirror/"
```
Run: `/run local c,s=MetaMirror:CurrentSpecKey(); local h=MetaMirror:SecondaryFor("haste"); print(c,s, string.format("Haste %.1f%% (%d)", h.pct, h.rating))`
Erwartet: die eigene classID/specID + plausible Haste-Werte (z. B. `8 64 Haste 18.3% (5123)`).

- [ ] **Step 3: Commit**
```bash
cd /e/claude-projekt/MetaMirror && git add -A && git commit -m "feat: live player state (spec + own secondary stats)"
```

---

### Task 5: Selbsttest-Harness + Tests

**Files:**
- Create: `E:\claude-projekt\MetaMirror\SelfTest.lua`

- [ ] **Step 1: Harness + Tests anlegen**

`SelfTest.lua`:
```lua
MetaMirror = MetaMirror or {}
MetaMirror.tests = {}
local function test(name, fn) MetaMirror.tests[#MetaMirror.tests+1] = { name = name, fn = fn } end
local function assertEqual(actual, expected, msg)
    if actual ~= expected then
        error((msg or "assert") .. ": erwartet " .. tostring(expected) .. ", war " .. tostring(actual), 2)
    end
end

function MetaMirror:RunSelfTest()
    local pass, fail = 0, 0
    for _, t in ipairs(self.tests) do
        local ok, err = pcall(t.fn)
        if ok then pass = pass + 1; print("|cff4ade80[MM-TEST]|r " .. t.name .. ": PASS")
        else fail = fail + 1; print("|cffff5555[MM-TEST]|r " .. t.name .. ": FAIL - " .. tostring(err)) end
    end
    print("|cffa855f7[MM-TEST]|r " .. pass .. " PASS, " .. fail .. " FAIL")
end

test("StatStatus_under", function()
    assertEqual(MetaMirror:StatStatus(28, 34, 1.5), "under", "under")
end)
test("StatStatus_on_withinTol", function()
    assertEqual(MetaMirror:StatStatus(33, 34, 1.5), "on", "within tol")
end)
test("StatStatus_over", function()
    assertEqual(MetaMirror:StatStatus(31, 28, 1.5), "over", "over")
end)
test("StatStatus_exact", function()
    assertEqual(MetaMirror:StatStatus(22, 22, 1.5), "on", "exact")
end)
test("TargetRating_scales", function()
    assertEqual(MetaMirror:TargetRating(8420, 28, 34), 10230, "scale up")
end)
test("TargetRating_zeroPct_nil", function()
    assertEqual(MetaMirror:TargetRating(0, 0, 34), nil, "no ratio")
end)
test("DataFor_present", function()
    local d = MetaMirror:DataFor(1, 71, "mythicplus")
    assertEqual(d ~= nil, true, "arms mplus present")
    assertEqual(d.stats[1].key, "haste", "first stat")
end)
test("DataFor_missing", function()
    assertEqual(MetaMirror:DataFor(1, 71, "pvp"), nil, "no pvp content")
    assertEqual(MetaMirror:DataFor(99, 99, "raid"), nil, "unknown spec")
end)
```

- [ ] **Step 2: Deployen und Selbsttest**
```bash
cp "E:/claude-projekt/MetaMirror/SelfTest.lua" "D:/Battle.net/World of Warcraft/_retail_/Interface/AddOns/MetaMirror/"
```
Run: `/reload` dann `/run MetaMirror:RunSelfTest()`
Erwartet: `8 PASS, 0 FAIL`.

- [ ] **Step 3: Commit**
```bash
cd /e/claude-projekt/MetaMirror && git add -A && git commit -m "feat: self-test harness + logic tests"
```

---

### Task 6: UI-Grundgerüst — Panel, Tabs, Kopf, M+/Raid, Andockung, Slash

**Files:**
- Create: `E:\claude-projekt\MetaMirror\UI.lua`

- [ ] **Step 1: Panel-Grundgerüst + Andockung anlegen**

`UI.lua`:
```lua
MetaMirror = MetaMirror or {}
local C, L = MetaMirror.C, MetaMirror.L

local TABS = { "stats", "talents", "gear", "gems", "cons" }
local TAB_LABEL = {
    stats = "tab_stats", talents = "tab_talents", gear = "tab_gear",
    gems = "tab_gems", cons = "tab_cons",
}

local Panel, Tabs, Body, Header, CtxBtns = nil, {}, nil, nil, {}

local function tex(parent, layer, col)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(col[1], col[2], col[3], col[4] or 1)
    return t
end
local function fs(parent, tmpl, col)
    local f = parent:CreateFontString(nil, "OVERLAY", tmpl or "GameFontNormal")
    if col then f:SetTextColor(unpack(col)) end
    return f
end

function MetaMirror:BuildPanel()
    if Panel then return end
    Panel = CreateFrame("Frame", "MetaMirrorPanel", UIParent, "BackdropTemplate")
    Panel:SetSize(360, 460)
    Panel:SetFrameStrata("HIGH")
    Panel:EnableMouse(true)
    Panel:SetMovable(true)
    Panel:RegisterForDrag("LeftButton")
    Panel:SetScript("OnDragStart", Panel.StartMoving)
    Panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- freie Position merken (loest die Andockung, bis Panel neu geoeffnet)
        local p, _, r, x, y = self:GetPoint()
        MetaMirrorDB.pos = { point = p, rel = "custom", x = x, y = y }
    end)
    local bg = tex(Panel, "BACKGROUND", C.BG_MAIN); bg:SetAllPoints()
    Panel:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    Panel:SetBackdropBorderColor(unpack(C.VIOLET))

    -- Kopfzeile
    local head = tex(Panel, "BACKGROUND", C.HEAD)
    head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT"); head:SetHeight(34)
    Header = fs(Panel, "GameFontNormal", C.VIOLET_S)
    Header:SetPoint("TOPLEFT", 12, -10)
    Header:SetText(L.title)

    -- Kontext-Umschalter M+/Raid
    local function ctxButton(key, label, xoff)
        local b = CreateFrame("Button", nil, Panel)
        b:SetSize(46, 18); b:SetPoint("TOPRIGHT", xoff, -8)
        local t = tex(b, "BACKGROUND", C.PANEL2); t:SetAllPoints(); b.bg = t
        local fstr = fs(b, "GameFontHighlightSmall", C.DIM)
        fstr:SetPoint("CENTER"); fstr:SetText(label); b.fstr = fstr
        b:SetScript("OnClick", function()
            MetaMirrorDB.content = key
            MetaMirror:Refresh()
        end)
        CtxBtns[key] = b
        return b
    end
    ctxButton("raid",       L.ctx_raid,  -8)
    ctxButton("mythicplus", L.ctx_mplus, -58)

    -- Tab-Leiste
    local x = 10
    for _, key in ipairs(TABS) do
        local b = CreateFrame("Button", nil, Panel)
        b:SetSize(66, 22); b:SetPoint("TOPLEFT", x, -36)
        local t = tex(b, "BACKGROUND", C.HEAD); t:SetAllPoints(); b.bg = t
        local fstr = fs(b, "GameFontHighlightSmall", C.DIM)
        fstr:SetPoint("CENTER"); fstr:SetText(L[TAB_LABEL[key]]); b.fstr = fstr
        b:SetScript("OnClick", function()
            MetaMirrorDB.tab = key
            MetaMirror:Refresh()
        end)
        Tabs[key] = b
        x = x + 68
    end

    -- Inhaltsbereich
    Body = CreateFrame("Frame", nil, Panel)
    Body:SetPoint("TOPLEFT", 10, -62)
    Body:SetPoint("BOTTOMRIGHT", -10, 10)

    -- Andockung an den Charakter-Rahmen
    MetaMirror:AnchorToCharacter()
    CharacterFrame:HookScript("OnShow", function() MetaMirror:OnCharShow() end)
    CharacterFrame:HookScript("OnHide", function() Panel:Hide() end)

    Panel:Hide()
    MetaMirror:Refresh()
end

function MetaMirror:AnchorToCharacter()
    local p = MetaMirrorDB.pos
    Panel:ClearAllPoints()
    if p and p.rel == "custom" then
        Panel:SetPoint(p.point, UIParent, "BOTTOMLEFT", p.x, p.y)
    else
        Panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 4, 0)
    end
end

function MetaMirror:OnCharShow()
    self:AnchorToCharacter()
    self:Refresh()
    Panel:Show()
end

function MetaMirror:Toggle()
    if not Panel then self:BuildPanel() end
    if Panel:IsShown() then Panel:Hide() else self:AnchorToCharacter(); self:Refresh(); Panel:Show() end
end

-- Kopf/Tabs/Kontext spiegeln + aktiven Tab rendern.
function MetaMirror:Refresh()
    if not Panel then return end
    -- Kontext-Buttons
    for key, b in pairs(CtxBtns) do
        local on = (MetaMirrorDB.content == key)
        b.bg:SetColorTexture(unpack(on and C.VIOLET or C.PANEL2))
        b.fstr:SetTextColor(unpack(on and {1,1,1,1} or C.DIM))
    end
    -- Tab-Buttons
    for key, b in pairs(Tabs) do
        local on = (MetaMirrorDB.tab == key)
        b.bg:SetColorTexture(unpack(on and C.BG_MAIN or C.HEAD))
        b.fstr:SetTextColor(unpack(on and C.VIOLET_S or C.DIM))
    end
    -- Kopf: Spec-Name
    local classID, specID = self:CurrentSpecKey()
    local specName = specID and select(2, GetSpecializationInfoByID(specID)) or "?"
    Header:SetText(specName .. "  |cff9a92c0" .. L.autodetect .. "|r")
    -- Inhalt
    self:RenderBody(classID, specID)
end

-- Platzhalter bis Task 7/8; zeigt vorerst nur den aktiven Tabnamen oder "keine Daten".
function MetaMirror.RenderBody(self, classID, specID)
    if not Body.msg then
        Body.msg = fs(Body, "GameFontHighlight", C.DIM)
        Body.msg:SetPoint("TOPLEFT")
    end
    local data = self:DataFor(classID, specID, MetaMirrorDB.content)
    Body.msg:SetText(data and ("Tab: " .. MetaMirrorDB.tab) or L.no_data)
end
```

- [ ] **Step 2: Deployen und prüfen**
```bash
cp "E:/claude-projekt/MetaMirror/UI.lua" "D:/Battle.net/World of Warcraft/_retail_/Interface/AddOns/MetaMirror/"
```
`/reload`, dann Charakterbildschirm mit **C** öffnen. Erwartet:
- Panel erscheint **rechts neben** dem Charakterfenster; schließt mit ihm.
- Tab-Leiste (Stats/Talente/Gear/Steine/Verbrauch) und M+/Raid oben rechts sind klickbar; aktiver Tab/Kontext hervorgehoben.
- `/mm` öffnet/schließt unabhängig; Panel per Drag verschiebbar.
- Auf einem Krieger/Magier zeigt der Body „Tab: …", sonst „keine Daten".

- [ ] **Step 3: Commit**
```bash
cd /e/claude-projekt/MetaMirror && git add -A && git commit -m "feat: UI shell (panel, tabs, ctx toggle, character-frame attach, slash)"
```

---

### Task 7: Stats-Tab (Vergleichsansicht)

**Files:**
- Modify: `E:\claude-projekt\MetaMirror\UI.lua`

- [ ] **Step 1: Stat-Zeilen-Renderer + Body-Dispatch ergänzen** — die Platzhalter-Funktion `MetaMirror.RenderBody` (aus Task 6) ersetzen durch echten Dispatch + Stats-Renderer:

```lua
-- Zeilen-Pool, damit wir bei jedem Refresh wiederverwenden statt neu erzeugen.
local rows = {}
local function getRow(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Frame", nil, Body)
    r:SetSize(336, 40)
    r.name  = fs(r, "GameFontNormalSmall", C.TXT);  r.name:SetPoint("TOPLEFT", 0, 0)
    r.chip  = fs(r, "GameFontNormalSmall");         r.chip:SetPoint("LEFT", r.name, "RIGHT", 8, 0)
    r.nums  = fs(r, "GameFontHighlightSmall", C.DIM);r.nums:SetPoint("TOPRIGHT", 0, 0)
    r.track = tex(r, "BORDER", C.PANEL2); r.track:SetPoint("TOPLEFT", 0, -20); r.track:SetSize(336, 12)
    r.fill  = r:CreateTexture(nil, "ARTWORK"); r.fill:SetPoint("TOPLEFT", 0, -20); r.fill:SetHeight(12)
    r.mark  = r:CreateTexture(nil, "OVERLAY"); r.mark:SetColorTexture(unpack(C.GOLD)); r.mark:SetSize(2, 18)
    rows[i] = r
    return r
end

local STATUS_COL = { under = "AMBER", over = "BLUE", on = "GREEN" }

local function renderStats(self, data)
    local tol = MetaMirrorDB.tol
    local i = 0
    for _, entry in ipairs(data.stats) do
        i = i + 1
        local r = getRow(i)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -(i-1) * 44)
        local cur = self:SecondaryFor(entry.key)
        local status = self:StatStatus(cur.pct, entry.pct, tol)
        local col = C[STATUS_COL[status]]
        local tRating = self:TargetRating(cur.rating, cur.pct, entry.pct)

        r.name:SetText(L["stat_" .. entry.key])
        -- Chip-Text nach Status
        if status == "under" then
            r.chip:SetText(string.format(L.need, math.floor(entry.pct - cur.pct + 0.5)))
            r.chip:SetTextColor(unpack(C.AMBER))
        elseif status == "over" then
            r.chip:SetText(string.format(L.over, math.floor(cur.pct - entry.pct + 0.5)))
            r.chip:SetTextColor(unpack(C.BLUE))
        else
            r.chip:SetText(L.on_target); r.chip:SetTextColor(unpack(C.GREEN))
        end
        r.nums:SetText(string.format("%.0f%% (%d) \194\183 %s %.0f%% (%s)",
            cur.pct, cur.rating, L.target, entry.pct, tRating and tostring(tRating) or "?"))

        -- Balken: Fuellung = Ist relativ zu einer Skala (max der beiden * 1.4), Marke = Ziel
        local scale = math.max(cur.pct, entry.pct) * 1.4
        if scale <= 0 then scale = 1 end
        r.fill:SetColorTexture(col[1], col[2], col[3], 1)
        r.fill:SetWidth(math.max(1, 336 * (cur.pct / scale)))
        r.mark:ClearAllPoints()
        r.mark:SetPoint("TOP", r.track, "TOPLEFT", 336 * (entry.pct / scale), 3)
        r:Show()
    end
    -- ueberzaehlige Zeilen ausblenden
    for j = i + 1, #rows do rows[j]:Hide() end
end

function MetaMirror.RenderBody(self, classID, specID)
    if not Body.msg then
        Body.msg = fs(Body, "GameFontHighlight", C.DIM)
        Body.msg:SetPoint("TOPLEFT")
    end
    local data = self:DataFor(classID, specID, MetaMirrorDB.content)
    if not data then
        for j = 1, #rows do rows[j]:Hide() end
        Body.msg:Show(); Body.msg:SetText(L.no_data)
        return
    end
    Body.msg:Hide()
    if MetaMirrorDB.tab == "stats" then
        renderStats(self, data)
    else
        for j = 1, #rows do rows[j]:Hide() end
        Body.msg:Show(); Body.msg:SetText("Tab: " .. MetaMirrorDB.tab)  -- Task 8 fuellt Rest
    end
end
```

- [ ] **Step 2: Deployen und prüfen**
```bash
cp "E:/claude-projekt/MetaMirror/UI.lua" "D:/Battle.net/World of Warcraft/_retail_/Interface/AddOns/MetaMirror/"
```
`/reload`, Charakterbildschirm öffnen (auf Krieger-Waffen oder Magier-Frost). Erwartet im **Stats-Tab**:
- Vier Stat-Zeilen mit Balken, **eingefärbt** (grün/gelb/blau) je nach eigenem Wert vs. Ziel, goldene Ziel-Marke, Chip („+X% fehlen"/„X% zu viel"/„im Ziel"), Zahlen als `28% (8420) · Ziel 34% (10230)`.
- M+/Raid-Umschalten ändert die Zielwerte. Ausrüstung wechseln ändert die Balken/Chips.

- [ ] **Step 3: Commit**
```bash
cd /e/claude-projekt/MetaMirror && git add -A && git commit -m "feat: stats tab with live compare (colored bars, target mark, chips)"
```

---

### Task 8: Restliche Tabs + Persistenz + Abschluss

**Files:**
- Modify: `E:\claude-projekt\MetaMirror\UI.lua`
- Modify: `E:\claude-projekt\MetaMirror\MetaMirror.toc:5`

- [ ] **Step 1: Renderer für Talente/Gear/Steine/Verbrauch ergänzen** — die Helfer `renderLines`/`renderTalents`/`hideTalents` **direkt nach `renderStats` (vor `RenderBody`)** einfügen, anschließend den Dispatch in `RenderBody` erweitern (der `else`-Zweig aus Task 7 entfällt):

```lua
-- Einfacher, mehrzeiliger Text-Renderer fuer die Listen-Tabs.
local function renderLines(lines)
    for j = 1, #rows do rows[j]:Hide() end
    if not Body.msg then
        Body.msg = fs(Body, "GameFontHighlight", C.DIM); Body.msg:SetPoint("TOPLEFT")
    end
    Body.msg:Show()
    Body.msg:SetJustifyH("LEFT")
    Body.msg:SetText(table.concat(lines, "\n"))
end

-- Talente: Import-String in selektierbarer EditBox + Nutzungsquote.
local TalentBox
local function renderTalents(data)
    for j = 1, #rows do rows[j]:Hide() end
    if Body.msg then Body.msg:Hide() end
    if not TalentBox then
        TalentBox = CreateFrame("EditBox", nil, Body, "InputBoxTemplate")
        TalentBox:SetAutoFocus(false); TalentBox:SetSize(320, 24)
        TalentBox:SetPoint("TOPLEFT", 4, -30)
        TalentBox:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
        TalentBox.hint = fs(Body, "GameFontHighlightSmall", C.DIM)
        TalentBox.hint:SetPoint("TOPLEFT", 4, -4)
        TalentBox.usage = fs(Body, "GameFontHighlightSmall", C.SEC)
        TalentBox.usage:SetPoint("TOPLEFT", 4, -58)
    end
    local t = data.talents and data.talents[1]
    TalentBox:Show(); TalentBox.hint:Show(); TalentBox.usage:Show()
    TalentBox.hint:SetText(L.copy_hint)
    TalentBox:SetText(t and t.importString or "")
    TalentBox:SetCursorPosition(0)
    TalentBox.usage:SetText(t and string.format(L.usage, t.usagePct) or "")
end
local function hideTalents() if TalentBox then TalentBox:Hide(); TalentBox.hint:Hide(); TalentBox.usage:Hide() end end
```

Und den Dispatch in `RenderBody` (den `if MetaMirrorDB.tab == "stats"`-Block) erweitern:
```lua
    hideTalents()
    if MetaMirrorDB.tab == "stats" then
        renderStats(self, data)
    elseif MetaMirrorDB.tab == "talents" then
        renderTalents(data)
    elseif MetaMirrorDB.tab == "gear" then
        local lines = {}
        for _, g in ipairs(data.gear or {}) do lines[#lines+1] = "|cffa3d0ff" .. g.slot .. "|r  " .. g.name end
        renderLines(#lines > 0 and lines or { L.no_data })
    elseif MetaMirrorDB.tab == "gems" then
        local lines = {}
        for _, g in ipairs(data.gems or {})     do lines[#lines+1] = g.slot .. ": " .. g.name end
        for _, e in ipairs(data.enchants or {}) do lines[#lines+1] = e.slot .. ": " .. e.name end
        renderLines(#lines > 0 and lines or { L.no_data })
    else -- cons
        local c = data.consumables or {}
        renderLines({
            "Flask: "  .. (c.flask  ~= 0 and c.flask  or "-"),
            "Potion: " .. (c.potion ~= 0 and c.potion or "-"),
            "Food: "   .. (c.food   ~= 0 and c.food   or "-"),
        })
    end
```
(Der ursprüngliche `else`-Zweig aus Task 7 entfällt dadurch.)

- [ ] **Step 2: Version-Bump** — `MetaMirror.toc` Zeile 5:
```
## Version: 0.2
```

- [ ] **Step 3: Deployen und Gesamttest**
```bash
cp "E:/claude-projekt/MetaMirror/UI.lua" "E:/claude-projekt/MetaMirror/MetaMirror.toc" "D:/Battle.net/World of Warcraft/_retail_/Interface/AddOns/MetaMirror/"
```
`/reload`, dann:
- `/run MetaMirror:RunSelfTest()` → `8 PASS, 0 FAIL`.
- Charakterbildschirm öffnen: alle fünf Tabs zeigen Inhalt (Talente-EditBox selektierbar; Gear/Steine/Verbrauch als Liste).
- M+/Raid + Tab-Wahl + Panel-Position überstehen `/reload` (aus `MetaMirrorDB`).

- [ ] **Step 4: Commit**
```bash
cd /e/claude-projekt/MetaMirror && git add -A && git commit -m "feat: talents/gear/gems/consumables tabs; bump to 0.2"
```

---

## Hinweise zur Ausführung

- **In-Game statt CI:** Reine Logik hat echte Selbsttests (Task 5). UI/Live wird per `/reload` + Sichtprüfung getestet; Task 4 und 7 brauchen einen Charakter mit passender Spec (Krieger-Waffen oder Magier-Frost), um Beispieldaten zu sehen — andere Specs zeigen bewusst „keine Daten".
- **Sample vs. echte Daten:** Alle `itemID = 0`/`SAMPLE-…` sind Platzhalter des Beispieldatensatzes; die Pipeline (Teilsystem 2, eigener Plan) ersetzt `Data/SampleData.lua` durch generierte, echte Daten mit denselben Feldern.
- **Andockung:** Wenn das Panel per Drag verschoben wurde, merkt es sich die freie Position (`pos.rel = "custom"`) statt anzudocken — erneutes Andocken durch Löschen von `MetaMirrorDB.pos` bzw. später optional per Menü/Reset.
```
