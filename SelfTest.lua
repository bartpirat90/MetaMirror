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
local function showCopy(text, title)
    if not dumpFrame then
        local f = CreateFrame("Frame", "MetaMirrorDumpFrame", UIParent, "BackdropTemplate")
        f:SetSize(440, 380); f:SetPoint("CENTER"); f:SetFrameStrata("DIALOG")
        f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                        edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
        f:SetBackdropColor(0.06, 0.055, 0.10, 0.98)
        f:SetBackdropBorderColor(0.42, 0.30, 0.70, 1)
        f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
        f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMoving)
        f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        f.title:SetPoint("TOP", 0, -9)
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
    dumpFrame.title:SetText("MetaMirror \226\128\148 " .. (title or "Enchant-Dump") .. " (Strg+C, dann schicken)")
    dumpFrame:Show()
    dumpFrame.eb:SetText(text)
    dumpFrame.eb:SetFocus(); dumpFrame.eb:HighlightText()
end

-- Oeffentlich, damit andere Module (Talents.lua) denselben Kopier-Frame nutzen koennen.
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
    if not d then print("|cffa855f7[MM]|r Keine Daten fuer aktuelle Spec.") return end
    local lines, pending = {}, 0
    local function finishMaybe()
        if pending == 0 then
            showCopy(table.concat(lines, "\n"))
            print("|cffa855f7[MM]|r Qualitaets-Dump fertig \226\128\148 Fenster offen (Strg+C).")
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

-- Diagnose: /mm dumpsrc  -> je Gear-Item Slot/itemID/Name, Equip-Location und die
-- vom Abenteuerfuehrer-Index gefundene Quelle (oder "—" = nicht im Journal).
function MetaMirror:DumpSource()
    local classID, specID = self:CurrentSpecKey()
    local d = classID and specID and self:DataFor(classID, specID, MetaMirrorDB.content)
    if not d then print("|cffa855f7[MM]|r Keine Daten fuer aktuelle Spec.") return end
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

-- /mm dumptalents : Grundlage fuer das Talent-Aktivieren-Feature. Gibt (1) den echten
-- Blizzard-Export-String der aktiv geladenen Talente und (2) die geordnete Baumstruktur
-- (Knoten-Reihenfolge + gewaehlte Eintraege/Raenge) aus. Damit laesst sich die
-- Serialisierung gegen verifizierte Daten nachbauen, statt das Bitformat zu raten.
function MetaMirror:DumpTalents()
    local lines = {}
    local function add(s) lines[#lines + 1] = s end

    local specIdx = GetSpecialization and GetSpecialization()
    local specID = specIdx and GetSpecializationInfo and GetSpecializationInfo(specIdx)
    add("== MetaMirror Talent-Dump ==")
    add("specID = " .. tostring(specID))

    local configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    add("configID = " .. tostring(configID))

    -- (1) Export-String direkt via API (falls vorhanden). Sonst bitte manuell aus dem
    --     Blizzard-Talentfenster ("Export"/"Kopieren") daneben schicken.
    local exportStr
    if C_Traits and C_Traits.GenerateImportString and configID then
        local ok, s = pcall(C_Traits.GenerateImportString, configID)
        if ok and s and s ~= "" then exportStr = s end
    end
    add("exportString = " .. (exportStr or "(API n/a -> bitte manuell aus dem Talentfenster kopieren)"))

    -- (2) Baumstruktur: geordnete Knoten (Serialisierungsreihenfolge) + Auswahl.
    if C_Traits and configID then
        local cfg = C_Traits.GetConfigInfo(configID)
        local treeIDs = (cfg and cfg.treeIDs) or {}
        for _, treeID in ipairs(treeIDs) do
            local nodes = C_Traits.GetTreeNodes(treeID) or {}
            add(string.format("tree %s  nodeCount=%d", tostring(treeID), #nodes))
            for i, nodeID in ipairs(nodes) do
                local n = C_Traits.GetNodeInfo(configID, nodeID)
                if n then
                    local ranks = n.ranksPurchased or n.activeRank or 0
                    local ae = n.activeEntry
                    add(string.format("[%d] node=%d sel=%s rank=%s activeEntry=%s type=%s entries=%s",
                        i, nodeID, tostring(ranks and ranks > 0), tostring(ranks),
                        ae and tostring(ae.entryID) or "-", tostring(n.type),
                        table.concat(n.entryIDs or {}, "/")))
                end
            end
        end
    else
        add("C_Traits/configID nicht verfuegbar (Talentfenster einmal oeffnen?)")
    end

    showCopy(table.concat(lines, "\n"), "Talent-Dump")
    print("|cffa855f7[MM]|r Talent-Dump fertig \226\128\148 Fenster offen (Strg+C). "
        .. "Bitte zusaetzlich den Export-String aus dem Blizzard-Talentfenster schicken, falls oben 'API n/a'.")
end
