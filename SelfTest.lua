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
    assertEqual(#d.stats, 4, "vier Sekundaerwerte")
    local valid = { haste = true, crit = true, mastery = true, vers = true }
    assertEqual(valid[d.stats[1].key] == true, true, "erster Stat ist gueltiger Key")
    assertEqual(type(d.stats[1].rating), "number", "erster Stat hat Rating")
end)
test("DataFor_missing", function()
    assertEqual(MetaMirror:DataFor(1, 71, "pvp"), nil, "no pvp content")
    assertEqual(MetaMirror:DataFor(99, 99, "raid"), nil, "unknown spec")
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
local function showCopy(text)
    if not dumpFrame then
        local f = CreateFrame("Frame", "MetaMirrorDumpFrame", UIParent, "BackdropTemplate")
        f:SetSize(440, 380); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                        edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        f:SetBackdropColor(0.06, 0.055, 0.10, 0.98)
        f:SetBackdropBorderColor(0.42, 0.30, 0.70, 1)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMoving)
        local title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        title:SetPoint("TOP", 0, -9); title:SetText("MetaMirror \226\128\148 Enchant-Dump (Strg+C, dann schicken)")
        local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
        close:SetPoint("TOPRIGHT", -2, -2)
        local sf = CreateFrame("ScrollFrame", "MetaMirrorDumpScroll", f, "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 12, -32); sf:SetPoint("BOTTOMRIGHT", -30, 12)
        local eb = CreateFrame("EditBox", nil, sf)
        eb:SetMultiLine(true); eb:SetFontObject(ChatFontNormal)
        eb:SetWidth(380); eb:SetAutoFocus(false)
        eb:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
        sf:SetScrollChild(eb)
        f.eb = eb
        dumpFrame = f
    end
    dumpFrame:Show()
    dumpFrame.eb:SetText(text)
    dumpFrame.eb:SetFocus(); dumpFrame.eb:HighlightText()
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
