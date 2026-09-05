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
test("StatStatus_nil_unknown", function()
    assertEqual(MetaMirror:StatStatus(nil, 34, 1.5), "unknown", "nil -> unknown")
end)
test("StatStatus_secretlike_unknown", function()
    -- Wert, der bei Arithmetik/Vergleich wirft (simuliert einen secret value)
    local secretlike = setmetatable({}, {
        __sub = function() error("secret") end,
        __lt  = function() error("secret") end,
        __le  = function() error("secret") end,
    })
    assertEqual(MetaMirror:StatStatus(secretlike, 34, 1.5), "unknown", "secret -> unknown")
end)
test("DataFor_present", function()
    local d = MetaMirror:DataFor(1, 71, "mythicplus")
    assertEqual(d ~= nil, true, "arms mplus present")
    -- Stats sind nach Rating sortiert; welcher Key oben steht, haengt von den
    -- Live-Daten ab -> nur Struktur pruefen, keinen konkreten Stat festnageln.
    assertEqual(#d.stats, 4, "vier Sekundärwerte")
    local valid = { haste = true, crit = true, mastery = true, vers = true }
    assertEqual(valid[d.stats[1].key] == true, true, "erster Stat ist gueltiger Key")
    assertEqual(type(d.stats[1].rating), "number", "erster Stat hat Rating")
end)
test("DataFor_missing", function()
    assertEqual(MetaMirror:DataFor(1, 71, "pvp"), nil, "no pvp content")
    assertEqual(MetaMirror:DataFor(99, 99, "raid"), nil, "unknown spec")
end)

test("DataStamp_mplus_label_and_date", function()
    local root = { generated = "2026-09-05",
                   fightStyles = { mythicplus = "castingpatchwerk5", raid = "castingpatchwerk" } }
    local s = MetaMirror:DataStamp("stats", "mythicplus", root, nil)
    assertEqual(s ~= nil and s:find("2026-09-05", 1, true) ~= nil, true, "Datum enthalten")
    assertEqual(s:find(MetaMirror.L.fight_mplus, 1, true) ~= nil, true, "M+-Label enthalten")
    local r = MetaMirror:DataStamp("gear", "raid", root, nil)
    assertEqual(r:find(MetaMirror.L.fight_raid, 1, true) ~= nil, true, "Raid-Label enthalten")
end)
test("DataStamp_maps_legacy_three_target_style", function()
    -- Datendateien von vor dem Wechsel auf fuenf Ziele tragen castingpatchwerk3; die
    -- sollen weiterhin das M+-Label bekommen statt des rohen Stil-Namens.
    local root = { generated = "2026-09-04",
                   fightStyles = { mythicplus = "castingpatchwerk3", raid = "castingpatchwerk" } }
    local s = MetaMirror:DataStamp("stats", "mythicplus", root, nil)
    assertEqual(s:find(MetaMirror.L.fight_mplus, 1, true) ~= nil, true, "Alt-Stil -> M+-Label")
    assertEqual(s:find("castingpatchwerk", 1, true), nil, "roher Stil-Name taucht nicht auf")
end)
test("DataStamp_unknown_style_falls_back_to_raw_name", function()
    local root = { generated = "2026-09-05", fightStyles = { mythicplus = "beastlord" } }
    local s = MetaMirror:DataStamp("stats", "mythicplus", root, nil)
    assertEqual(s:find("beastlord", 1, true) ~= nil, true, "unbekannter Stil bleibt lesbar")
end)
test("DataStamp_schmuck_from_trinket_version", function()
    local troot = { version = "bm-2026-09-01" }
    local s = MetaMirror:DataStamp("schmuck", "mythicplus", { generated = "2026-09-04" }, troot)
    assertEqual(s:find("2026-09-01", 1, true) ~= nil, true, "Trinket-Datum")
    assertEqual(s:find(MetaMirror.L.fight_raid, 1, true) ~= nil, true, "Einzelziel-Label")
end)
test("DataStamp_nil_without_date", function()
    assertEqual(MetaMirror:DataStamp("stats", "raid", {}, nil), nil, "kein generated -> nil")
    assertEqual(MetaMirror:DataStamp("schmuck", "raid", {}, {}), nil, "kein version -> nil")
end)

test("Data_gear_carries_reference_item_level", function()
    -- Regression: die Pipeline hat das ilevel-Feld von bloodmallet verworfen, dadurch
    -- fehlte bei rund der Haelfte der Slots die Referenzstufe und die Ampel verglich
    -- gegen die Basisstufe des Items.
    local root = _G.MetaMirrorData
    local withLevel, total = 0, 0
    for _, specs in pairs((root and root.specs) or {}) do
        for _, contents in pairs(specs) do
            for _, data in pairs(contents) do
                for _, g in ipairs(data.gear or {}) do
                    total = total + 1
                    if (g.itemLevel or 0) > 0 then withLevel = withLevel + 1 end
                end
            end
        end
    end
    assertEqual(total > 0, true, "Gear-Eintraege vorhanden")
    assertEqual(withLevel > 0, true, "mindestens ein Eintrag traegt eine Referenzstufe")
end)

test("ReferenceTrinkets_returns_profile_trinkets", function()
    -- Der Schmuck-Tab markiert damit die Zeilen, die auch im Referenzprofil stecken.
    -- Ohne diese Bruecke wirkt die abweichende Reihenfolge der beiden Sichten wie ein
    -- Widerspruch.
    local root = _G.MetaMirrorData
    local specs = root and root.specs
    local found = false
    for classID, byspec in pairs(specs or {}) do
        for specID, contents in pairs(byspec) do
            for content, data in pairs(contents) do
                local want = {}
                for _, g in ipairs(data.gear or {}) do
                    if g.slot == "TRINKET1" or g.slot == "TRINKET2" then
                        want[#want+1] = g.itemID
                    end
                end
                if #want > 0 then
                    found = true
                    local set = MetaMirror:ReferenceTrinkets(classID, specID, content)
                    for _, id in ipairs(want) do
                        assertEqual(set[id], true, "Trinket " .. tostring(id) .. " markiert")
                    end
                end
            end
        end
    end
    assertEqual(found, true, "mindestens ein Profil traegt Schmuck")
end)
test("ReferenceTrinkets_empty_set_for_unknown_spec", function()
    -- Leeres Set statt nil: die UI indiziert direkt, ohne Nil-Pruefung.
    local set = MetaMirror:ReferenceTrinkets(999, 999, "raid")
    assertEqual(type(set), "table", "Tabelle auch ohne Daten")
    assertEqual(next(set), nil, "leer")
    assertEqual(set[12345], nil, "beliebige itemID nicht markiert")
end)
test("ReferenceTrinkets_excludes_other_slots", function()
    local set = MetaMirror:ReferenceTrinkets(9, 266, "raid")
    local data = MetaMirror:DataFor(9, 266, "raid")
    for _, g in ipairs((data and data.gear) or {}) do
        if g.slot ~= "TRINKET1" and g.slot ~= "TRINKET2" then
            assertEqual(set[g.itemID], nil, "Nicht-Schmuck " .. g.slot .. " nicht markiert")
        end
    end
end)
test("GearStatus_equipped_regardless_of_item_level", function()
    -- Angelegt ist angelegt: die Stufe darf den Zustand nicht mehr beeinflussen,
    -- sonst wird eine Selbstverstaendlichkeit ("hoeher ist besser") eingefaerbt.
    assertEqual(MetaMirror:GearStatus(100, { equipped = { [100] = 350 }, bags = {} }), "equipped", "auf Referenzstufe")
    assertEqual(MetaMirror:GearStatus(100, { equipped = { [100] = 330 }, bags = {} }), "equipped", "niedrigere Stufe")
    assertEqual(MetaMirror:GearStatus(100, { equipped = { [100] = 0 }, bags = {} }), "equipped", "Stufe unbekannt")
end)
test("GearStatus_ignores_extra_arguments", function()
    -- Alte Aufrufer uebergaben eine Referenzstufe als drittes Argument; die darf
    -- nichts mehr bewirken.
    assertEqual(MetaMirror:GearStatus(100, { equipped = { [100] = 330 }, bags = {} }, 350), "equipped", "Reststufe ohne Wirkung")
end)
test("GearStatus_bag", function()
    assertEqual(MetaMirror:GearStatus(100, { equipped = {}, bags = { [100] = true } }), "bag", "im Beutel")
end)
test("GearStatus_missing", function()
    assertEqual(MetaMirror:GearStatus(100, { equipped = {}, bags = {} }), "missing", "fehlt")
    assertEqual(MetaMirror:GearStatus(nil, { equipped = {}, bags = {} }), "missing", "keine itemID")
end)
test("GearStatus_equipped_beats_bag", function()
    local ctx = { equipped = { [100] = 350 }, bags = { [100] = true } }
    assertEqual(MetaMirror:GearStatus(100, ctx), "equipped", "angelegt hat Vorrang")
end)

-- Fake-Daten fuer den Tooltip-Index: Klasse 8 (Magier) mit zwei Specs.
local function ttFixture()
    local root = { specs = { [8] = {
        [64] = { mythicplus = { gear = { { slot = "HEAD", itemID = 500 }, { slot = "BACK", itemID = 501 } } },
                 raid       = { gear = { { slot = "HEAD", itemID = 500 } } } },
        [63] = { mythicplus = { gear = { { slot = "HEAD", itemID = 502 } } },
                 raid       = { gear = { { slot = "HEAD", itemID = 502 } } } },
    } } }
    local troot = { specs = {
        [64] = { singleSource = true, overall = { { itemID = 600, tier = "S" }, { itemID = 601, tier = "A" } } },
        [63] = { raid = { { itemID = 600, tier = "S" } }, dungeon = { { itemID = 601, tier = "S" } } },
    } }
    local specs = { { specID = 64, name = "Frost" }, { specID = 63, name = "Fire" } }
    return root, troot, specs
end
test("TooltipIndex_bis_both_contents", function()
    local root, troot, specs = ttFixture()
    local idx = MetaMirror:BuildTooltipIndex(8, specs, root, troot)
    local e = idx[500][1]
    assertEqual(e.name, "Frost", "Spec-Name")
    assertEqual(e.kind, "bis", "Art")
    assertEqual(e.mplus and e.raid, true, "M+ und Raid")
    assertEqual(idx[501][1].raid, false, "Back nur M+")
    assertEqual(idx[999], nil, "unbekanntes Item")
end)
test("TooltipIndex_strinket_views", function()
    local root, troot, specs = ttFixture()
    local idx = MetaMirror:BuildTooltipIndex(8, specs, root, troot)
    -- 600: Frost singleSource (overall gilt fuer beide) + Fire nur Raid
    local frost, fire
    for _, e in ipairs(idx[600]) do
        if e.name == "Frost" then frost = e elseif e.name == "Fire" then fire = e end
    end
    assertEqual(frost.kind, "strinket", "Frost S-Trinket")
    assertEqual(frost.mplus and frost.raid, true, "Frost beide Sichten")
    assertEqual(fire.mplus, false, "Fire nur Raid")
    assertEqual(fire.raid, true, "Fire Raid")
    -- 601: Frost Tier A -> kein Eintrag; Fire nur Dungeon
    assertEqual(#idx[601], 1, "nur Fire")
    assertEqual(idx[601][1].mplus, true, "Fire M+")
end)
test("TooltipLines_format", function()
    local root, troot, specs = ttFixture()
    local idx = MetaMirror:BuildTooltipIndex(8, specs, root, troot)
    local lines = MetaMirror:TooltipLinesForIndex(idx, 500)
    assertEqual(#lines, 1, "eine Zeile")
    assertEqual(lines[1]:find("Frost", 1, true) ~= nil, true, "Spec im Text")
    assertEqual(lines[1]:find(MetaMirror.L.ctx_mplus, 1, true) ~= nil, true, "M+ im Text")
    assertEqual(lines[1]:find(MetaMirror.L.ctx_raid, 1, true) ~= nil, true, "Raid im Text")
    assertEqual(#MetaMirror:TooltipLinesForIndex(idx, 999), 0, "unbekannt -> leer")
end)
test("TooltipLines_current_spec_first", function()
    local root, troot, _ = ttFixture()
    -- Reihenfolge der specs-Liste = Reihenfolge der Zeilen (Aufrufer sortiert aktuelle Spec nach vorn).
    local idx = MetaMirror:BuildTooltipIndex(8, { { specID = 63, name = "Fire" }, { specID = 64, name = "Frost" } }, root, troot)
    local lines = MetaMirror:TooltipLinesForIndex(idx, 600)
    assertEqual(#lines, 2, "zwei Zeilen")
    assertEqual(lines[1]:find("Fire", 1, true) ~= nil, true, "Fire zuerst")
end)

-- ---------------------------------------------------------------------------
-- /mm dumpench : liest die Enchant-Namen zu unseren permanentEnchant-IDs aus.
-- Einmaliger Season-Schritt, um die feste enchantID->itemID-Tabelle zu bauen.
-- Technik: Tooltip mit vs. ohne injizierter Verzauberung vergleichen -> die
-- neu hinzugekommene (gruene) Zeile ist der Verzauberungsname. Robust gegen
-- andere gruene Zeilen (Equip-Effekte etc.), weil nur die DIFFERENZ zaehlt.
local function scanLines(link)
    local tip = _G.MetaMirrorScanTip
    if not tip then
        tip = CreateFrame("GameTooltip", "MetaMirrorScanTip", nil, "GameTooltipTemplate")
    end
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    local out = {}
    local ok = pcall(function() tip:SetHyperlink(link) end)
    if ok then
        for i = 1, tip:NumLines() do
            local fs = _G["MetaMirrorScanTipTextLeft" .. i]
            local s = fs and fs:GetText()
            if s and s ~= "" then out[#out + 1] = s end
        end
    end
    return out
end

local function cleanName(s)
    s = s:gsub("|A.-|a", ""):gsub("|T.-|t", "")     -- Qualitaets-/Textur-Icons entfernen
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    local rest = s:match("^%a+:%s*(.+)$")            -- "Verzaubert:/Enchanted:"-Prefix abschneiden
    if rest then s = rest:gsub("%s+$", "") end
    return s
end

local function enchantName(gearID, enchantID)
    local base, ench = scanLines("item:" .. gearID), scanLines("item:" .. gearID .. ":" .. enchantID)
    local seen = {}
    for _, s in ipairs(base) do seen[s] = true end
    local fresh = {}
    for _, s in ipairs(ench) do
        if not seen[s] then
            local c = cleanName(s)
            if c ~= "" then return c end             -- erste echte neue Zeile = Verzauberung
            fresh[#fresh + 1] = s
        end
    end
    if #fresh > 0 then return "RAW: " .. table.concat(fresh, " | ") end   -- Diagnose
    return nil
end

local dumpFrame
local function showCopy(text, title)
    if not dumpFrame then
        local f = CreateFrame("Frame", "MetaMirrorDumpFrame", UIParent, "BackdropTemplate")
        -- FULLSCREEN_DIALOG + Toplevel: muss ueber Blizzard-Fenstern liegen, sonst
        -- verschwindet die Diagnose dahinter (haeufig uebersehen).
        f:SetSize(440, 380); f:SetPoint("CENTER"); f:SetFrameStrata("FULLSCREEN_DIALOG")
        f:SetToplevel(true); f:SetFrameLevel(1000)
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                        edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        f:SetBackdropColor(0.06, 0.055, 0.10, 0.98)
        f:SetBackdropBorderColor(0.42, 0.30, 0.70, 1)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMoving)
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.title:SetPoint("TOP", 0, -9)
        local sf = CreateFrame("ScrollFrame", "MetaMirrorDumpScroll", f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 12, -32); sf:SetPoint("BOTTOMRIGHT", -30, 40)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true); eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(380); eb:SetAutoFocus(false)
        -- Escape: Fokus loesen UND Fenster schliessen (Text steht weiter im Frame).
        eb:SetScript("OnEscapePressed", function(s) s:ClearFocus(); f:Hide() end)
        sf:SetScrollChild(eb)
        f.eb = eb
        -- Schliessen-Kreuz NACH dem ScrollFrame anlegen und explizit ueber alles heben:
        -- bei sehr langen Dumps (scansrc) lag es sonst hinter Scroll-Inhalt/Scrollbar und
        -- "verschwand". Zusaetzlich ein Textknopf unten als zweiter Weg.
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
        close:SetFrameLevel(f:GetFrameLevel() + 20)
        close:SetScript("OnClick", function() f:Hide() end)
        local btn = CreateFrame("Button", nil, f, "UIPanelButtonTemplate")
        btn:SetSize(110, 22); btn:SetPoint("BOTTOM", 0, 10)
        btn:SetText(CLOSE or "Schliessen")
        btn:SetFrameLevel(f:GetFrameLevel() + 20)
        btn:SetScript("OnClick", function() f:Hide() end)
        dumpFrame = f
    end
    dumpFrame.title:SetText("MetaMirror \226\128\148 " .. (title or "Enchant-Dump") .. " (Strg+C, dann schicken)")
    dumpFrame:Show()
    dumpFrame.eb:SetText(text)
    dumpFrame.eb:SetFocus(); dumpFrame.eb:HighlightText()
end

-- Oeffentlich, damit andere Dump-Befehle denselben Kopier-Frame nutzen koennen.
function MetaMirror:ShowCopy(text, title)
    showCopy(text, title)
end

function MetaMirror:DumpEnchants()
    local data = MetaMirrorData
    if not (data and data.specs) then
        print("|cffa855f7[MM]|r Keine Daten geladen.")
        return
    end
    local repGear, order = {}, {}   -- enchantID -> repraesentatives Gear-Item (gleicher Slot)
    for _, specs in pairs(data.specs) do
        for _, spec in pairs(specs) do
            for _, content in pairs(spec) do
                if type(content) == "table" and content.enchants and content.gear then
                    local bySlot = {}
                    for _, g in ipairs(content.gear) do bySlot[g.slot] = g.itemID end
                    for _, e in ipairs(content.enchants) do
                        if e.id and not repGear[e.id] and bySlot[e.slot] then
                            repGear[e.id] = bySlot[e.slot]
                            order[#order + 1] = { id = e.id, slot = e.slot }
                        end
                    end
                end
            end
        end
    end
    table.sort(order, function(a, b) return a.id < b.id end)
    if #order == 0 then print("|cffa855f7[MM]|r Keine Verzauberungen in den Daten.") return end

    local pending, results = 0, {}
    local function finish()
        local lines = {}
        for _, o in ipairs(order) do
            lines[#lines + 1] = o.id .. "\t" .. o.slot .. "\t" .. (results[o.id] or "?")
        end
        showCopy(table.concat(lines, "\n"))
        print("|cffa855f7[MM]|r " .. #order .. " Verzauberungen ausgelesen \226\128\148 Fenster offen (Strg+C).")
    end
    for _, o in ipairs(order) do
        pending = pending + 1
        local it = Item:CreateFromItemID(repGear[o.id])
        it:ContinueOnItemLoad(function()
            results[o.id] = enchantName(repGear[o.id], o.id)
            pending = pending - 1
            if pending == 0 then finish() end
        end)
    end
    if pending == 0 then finish() end
end

-- /mm dumpgems : zeigt fuer jeden Stein, WIE er seinen Stat deklariert
-- (GetItemStats-Schluessel + alle Tooltip-Zeilen). Diagnose fuer die
-- Primaer/Sekundaer-Erkennung im Edelstein-Abschnitt.
function MetaMirror:DumpGems()
    local data = MetaMirrorData
    if not (data and data.specs) then
        print("|cffa855f7[MM]|r Keine Daten geladen.")
        return
    end
    local seen, ids = {}, {}
    for _, specs in pairs(data.specs) do
        for _, spec in pairs(specs) do
            for _, content in pairs(spec) do
                if type(content) == "table" and content.gems then
                    for _, g in ipairs(content.gems) do
                        if g.itemID and g.itemID ~= 0 and not seen[g.itemID] then
                            seen[g.itemID] = true
                            ids[#ids + 1] = g.itemID
                        end
                    end
                end
            end
        end
    end
    if #ids == 0 then print("|cffa855f7[MM]|r Keine Edelsteine in den Daten.") return end
    table.sort(ids)

    local pending, blocks = 0, {}
    local function finish()
        local out = {}
        for _, iid in ipairs(ids) do out[#out + 1] = blocks[iid] or (iid .. "\t?") end
        showCopy(table.concat(out, "\n"))
        print("|cffa855f7[MM]|r " .. #ids .. " Edelsteine ausgelesen \226\128\148 Fenster offen (Strg+C).")
    end
    for _, iid in ipairs(ids) do
        pending = pending + 1
        local it = Item:CreateFromItemID(iid)
        it:ContinueOnItemLoad(function()
            local link = it:GetItemLink()
            local name = it:GetItemName() or ("item:" .. iid)
            -- GetItemStats-Schluessel
            local statKeys = {}
            local stats = (C_Item and C_Item.GetItemStats and C_Item.GetItemStats(link))
                          or (GetItemStats and GetItemStats(link))
            if stats then for k in pairs(stats) do statKeys[#statKeys + 1] = k end end
            -- Tooltip-Zeilen
            local lines = scanLines(link)
            blocks[iid] = iid .. "  " .. name
                .. "\n  stats: " .. (next(statKeys) and table.concat(statKeys, ", ") or "(leer)")
                .. "\n  tip: " .. table.concat(lines, " | ")
            pending = pending - 1
            if pending == 0 then finish() end
        end)
    end
    if pending == 0 then finish() end
end

-- /mm dumpq : zeigt fuer die AKTUELL angezeigte Spec, wie Qualitaet/Upgrade im
-- Item-Link kodiert sind. Gear: rohe bonusIDs + Tooltip-Zeilen mit Aufwertung
-- (X/Y). Verzauberungen: Handwerksqualitaet + roher Link. Grundlage, um immer die
-- hoechste Stufe (Mythos 6/6, Tier 3) zu erzwingen, ohne Bonus-IDs zu raten.
function MetaMirror:DumpQuality()
    local classID, specID = self:CurrentSpecKey()
    local d = classID and specID and self:DataFor(classID, specID, MetaMirrorDB.content)
    if not d then print("|cffa855f7[MM]|r Keine Daten für aktuelle Spec.") return end
    local lines, pending = {}, 0
    local function finishMaybe()
        if pending == 0 then
            showCopy(table.concat(lines, "\n"))
            print("|cffa855f7[MM]|r Qualitäts-Dump fertig \226\128\148 Fenster offen (Strg+C).")
        end
    end
    -- GEAR
    local gear = {}
    for _, g in ipairs(d.gear or {}) do gear[#gear + 1] = g end
    table.sort(gear, function(a, b) return (a.slot or "") < (b.slot or "") end)
    for _, g in ipairs(gear) do
        local bonus = table.concat(g.bonusIDs or {}, ":")
        local core = string.format("item:%d:0:0:0:0:0:0:0:0:0:0:0:%d:%s",
            g.itemID, #(g.bonusIDs or {}), bonus)
        pending = pending + 1
        local item = Item:CreateFromItemLink(core)
        item:ContinueOnItemLoad(function()
            local upg = {}
            for _, s in ipairs(scanLines(core)) do
                if s:find("%d+/%d+") then upg[#upg + 1] = s end
            end
            lines[#lines + 1] = string.format("GEAR %s  %d  ilvl=%d\n  bonus={%s}\n  upg=[%s]",
                g.slot or "?", g.itemID, g.itemLevel or 0, bonus, table.concat(upg, " | "))
            pending = pending - 1
            finishMaybe()
        end)
    end
    -- VERZAUBERUNGEN (Handwerksqualitaet)
    local ench = {}
    for _, e in ipairs(d.enchants or {}) do
        if e.itemID and e.itemID ~= 0 then ench[#ench + 1] = e end
    end
    for _, e in ipairs(ench) do
        pending = pending + 1
        local item = Item:CreateFromItemID(e.itemID)
        item:ContinueOnItemLoad(function()
            local q
            if C_TradeSkillUI and C_TradeSkillUI.GetItemCraftedQualityByItemInfo then
                local ok, r = pcall(C_TradeSkillUI.GetItemCraftedQualityByItemInfo, e.itemID)
                if ok then q = r end
            end
            local link = item:GetItemLink()
            lines[#lines + 1] = string.format("ENCH %s  %d  q=%s\n  %s",
                e.slot or "?", e.itemID, tostring(q), link and link:gsub("|", "||") or "?")
            pending = pending - 1
            finishMaybe()
        end)
    end
    finishMaybe()
end

-- Diagnose + Reparatur: /mm scansrc -> Abenteuerfuehrer-Index synchron neu aufbauen,
-- je Tier/Instanz/Boss protokollieren (Fehler, Bosse ohne Loot) und danach alle Trinkets
-- der aktuellen Spec auflisten, die weder Journal- noch Pipeline-Quelle haben.
function MetaMirror:ScanSourceDiag()
    local report = {}
    local t0 = debugprofilestop and debugprofilestop() or 0
    local n = self:RescanSourcesSync(report)
    local ms = debugprofilestop and (debugprofilestop() - t0) or 0
    local lines = { string.format("Quellen-Rescan: %d Items indiziert in %.0f ms", n, ms) }
    for _, l in ipairs(report) do lines[#lines + 1] = l end
    -- Trinkets ohne jede Quelle (aktuelle Spec)
    local classID, specID = self:CurrentSpecKey()
    local ids, seen = {}, {}
    local function add(list)
        for _, e in ipairs(list or {}) do
            if e.itemID and not seen[e.itemID] then seen[e.itemID] = true; ids[#ids + 1] = e.itemID end
        end
    end
    local bm = _G.MetaMirrorTrinkets and _G.MetaMirrorTrinkets.specs and _G.MetaMirrorTrinkets.specs[specID]
    if bm then add(bm.overall); add(bm.raid); add(bm.dungeon) end
    local ps = _G.MetaMirrorItemSources and _G.MetaMirrorItemSources.items or {}
    lines[#lines + 1] = "Trinkets ohne Quelle (Spec " .. tostring(specID) .. "):"
    local missing = 0
    for _, id in ipairs(ids) do
        if not self:GetItemSource(id) and not ps[id] then
            missing = missing + 1
            local name = C_Item.GetItemInfo and select(1, C_Item.GetItemInfo(id)) or nil
            lines[#lines + 1] = string.format("  %d  %s", id, name or "(Name nicht geladen)")
        end
    end
    if missing == 0 then lines[#lines + 1] = "  keine" end
    showCopy(table.concat(lines, "\n"))
    print(string.format("|cffa855f7[MM]|r Quellen-Rescan fertig: %d Items, %d Trinkets ohne Quelle \226\128\148 Fenster offen (Strg+C).", n, missing))
end

-- Diagnose: /mm dumpsrc  -> je Gear-Item Slot/itemID/Name, Equip-Location und die
-- vom Abenteuerfuehrer-Index gefundene Quelle (oder "—" = nicht im Journal).
function MetaMirror:DumpSource()
    local classID, specID = self:CurrentSpecKey()
    local d = classID and specID and self:DataFor(classID, specID, MetaMirrorDB.content)
    if not d then print("|cffa855f7[MM]|r Keine Daten für aktuelle Spec.") return end
    local lines, pending = {}, 0
    lines[#lines + 1] = "Quelle-Dump (Content=" .. tostring(MetaMirrorDB.content) .. ")"
    local function finishMaybe()
        if pending == 0 then
            showCopy(table.concat(lines, "\n"))
            print("|cffa855f7[MM]|r Quelle-Dump fertig \226\128\148 Fenster offen (Strg+C).")
        end
    end
    local gear = {}
    for _, g in ipairs(d.gear or {}) do gear[#gear + 1] = g end
    table.sort(gear, function(a, b) return (a.slot or "") < (b.slot or "") end)
    for _, g in ipairs(gear) do
        pending = pending + 1
        local item = Item:CreateFromItemID(g.itemID)
        item:ContinueOnItemLoad(function()
            local src = MetaMirror:GetItemSource(g.itemID)
            local name = item:GetItemName() or "?"
            local loc = select(4, C_Item.GetItemInfoInstant(g.itemID))
            local s = src and string.format("%s [inst=%s enc=%s diff=%s]",
                src.text, tostring(src.instanceID), tostring(src.encounterID), tostring(src.difficultyID)) or "\226\128\148"
            lines[#lines + 1] = string.format("%s  %d  %s\n  loc=%s  src=%s",
                g.slot or "?", g.itemID, name, tostring(loc), s)
            pending = pending - 1
            finishMaybe()
        end)
    end
    finishMaybe()
end

-- /mm ilvl : misst, welche Gegenstandsstufe ein Referenz-Item im Spiel tatsaechlich
-- bekommt. Vier Spalten je Slot: Stufe aus den Sim-Daten, Stufe des Links so wie das
-- Addon ihn baut, und Stufe desselben Links mit angehaengtem Mythos-6/6-Bonus (12854,
-- per /mm dumpq verifiziert). Damit laesst sich mit Messwerten statt Vermutungen
-- entscheiden, ob sich die Referenzstufe ueberhaupt in einen Item-Link kodieren laesst.
function MetaMirror:DumpItemLevels()
    local classID, specID = self:CurrentSpecKey()
    local d = classID and specID and self:DataFor(classID, specID, MetaMirrorDB.content)
    if not d then print("|cffa855f7[MM]|r Keine Daten für aktuelle Spec.") return end
    local MYTH = 12854
    local lines = { "Slot | itemID | Daten | Link | Link+Mythos6/6 | bonusIDs" }
    local gear = {}
    for _, g in ipairs(d.gear or {}) do gear[#gear + 1] = g end
    table.sort(gear, function(a, b) return (a.slot or "") < (b.slot or "") end)

    local pending = #gear
    local function finishMaybe()
        if pending > 0 then return end
        table.sort(lines, function(a, b) return a < b end)
        showCopy(table.concat(lines, "\n"))
        print("|cffa855f7[MM]|r Ilvl-Dump fertig \226\128\148 Fenster offen (Strg+C).")
    end
    if pending == 0 then finishMaybe() return end

    local function ilvlOf(link)
        if not (C_Item and C_Item.GetDetailedItemLevelInfo) then return 0 end
        local ok, v = pcall(C_Item.GetDetailedItemLevelInfo, link)
        return (ok and type(v) == "number") and v or 0
    end

    for _, g in ipairs(gear) do
        local ids = g.bonusIDs or {}
        local hasMyth = false
        for _, id in ipairs(ids) do if id == MYTH then hasMyth = true end end
        local function core(extra)
            local list = {}
            for _, id in ipairs(ids) do list[#list + 1] = id end
            if extra and not hasMyth then list[#list + 1] = extra end
            return string.format("item:%d:0:0:0:0:0:0:0:0:0:0:0:%d:%s",
                g.itemID, #list, table.concat(list, ":"))
        end
        local plain, boosted = core(nil), core(MYTH)
        local item = Item:CreateFromItemLink(plain)
        item:ContinueOnItemLoad(function()
            local a = ilvlOf(plain)
            local it2 = Item:CreateFromItemLink(boosted)
            it2:ContinueOnItemLoad(function()
                lines[#lines + 1] = string.format("%s | %d | %d | %d | %d | %s",
                    g.slot or "?", g.itemID or 0, g.itemLevel or 0, a, ilvlOf(boosted),
                    table.concat(ids, "/"))
                pending = pending - 1
                finishMaybe()
            end)
        end)
    end
end
