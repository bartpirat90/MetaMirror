-- BiS-Hinweis im Item-Tooltip: beim Hovern (Loot-Fenster, Beutel, Chat-Link, Haendler)
-- haengt das Addon Zeilen an, fuer welche Specs der EIGENEN Klasse das Item Sim-Referenz-
-- BiS ist (M+/Raid) bzw. ein S-Tier-Schmuckstueck. Alle Specs der Klasse (Offspec-Loot),
-- aktuelle Spec zuerst. Der Index wird einmal je Spec-Wechsel gebaut (Daten sind statisch).
-- Hook: TooltipDataProcessor (10.0.2+) -> greift fuer GameTooltip, ItemRefTooltip, Vergleich.
MetaMirror = MetaMirror or {}

local CONTENTS = { "mythicplus", "raid" }

-- Spec-Liste der Klasse { {specID=, name=}, ... }, aktuelle Spec zuerst, sonst nach ID.
local function classSpecs(classID, currentSpecID)
    local out = {}
    local n = (GetNumSpecializationsForClassID and GetNumSpecializationsForClassID(classID)) or 0
    for i = 1, n do
        local id, name = GetSpecializationInfoForClassID(classID, i)
        if id then out[#out + 1] = { specID = id, name = name or tostring(id) } end
    end
    table.sort(out, function(a, b)
        local ac, bc = (a.specID == currentSpecID), (b.specID == currentSpecID)
        if ac ~= bc then return ac end
        return a.specID < b.specID
    end)
    return out
end

-- Index: itemID -> Liste { specID, name, kind = "bis"|"strinket", mplus = bool, raid = bool }.
-- root/troot nur fuer Tests (Default: geladene Datentabellen).
function MetaMirror:BuildTooltipIndex(classID, specs, root, troot)
    root = root or _G.MetaMirrorData
    troot = troot or _G.MetaMirrorTrinkets
    local index = {}
    local function entry(itemID, spec, kind)
        local list = index[itemID]
        if not list then list = {}; index[itemID] = list end
        for _, e in ipairs(list) do
            if e.specID == spec.specID and e.kind == kind then return e end
        end
        local e = { specID = spec.specID, name = spec.name, kind = kind, mplus = false, raid = false }
        list[#list + 1] = e
        return e
    end
    local cls = root and root.specs and root.specs[classID]
    for _, spec in ipairs(specs) do
        -- Gear-BiS je Content.
        local sd = cls and cls[spec.specID]
        for _, content in ipairs(CONTENTS) do
            local d = sd and sd[content]
            for _, g in ipairs(d and d.gear or {}) do
                if g.itemID then
                    local e = entry(g.itemID, spec, "bis")
                    if content == "raid" then e.raid = true else e.mplus = true end
                end
            end
        end
        -- S-Tier-Schmuck je Sicht; singleSource oder fehlende Sicht -> "overall" gilt fuer beide.
        local ts = troot and troot.specs and troot.specs[spec.specID]
        if ts then
            for _, v in ipairs({ { view = "dungeon", flag = "mplus" }, { view = "raid", flag = "raid" } }) do
                local list = (not ts.singleSource) and ts[v.view] or ts.overall
                for _, t in ipairs(list or {}) do
                    if t.itemID and t.tier == "S" then
                        entry(t.itemID, spec, "strinket")[v.flag] = true
                    end
                end
            end
        end
    end
    return index
end

local SEP = " \194\183 "   -- " . " (Mittelpunkt)

-- Tooltip-Zeilen fuer ein Item aus einem Index; leer, wenn nichts bekannt.
function MetaMirror:TooltipLinesForIndex(index, itemID)
    local L = self.L
    local out = {}
    for _, e in ipairs(index[itemID] or {}) do
        local ctx = {}
        if e.mplus then ctx[#ctx + 1] = L.ctx_mplus end
        if e.raid then ctx[#ctx + 1] = L.ctx_raid end
        local fmt = (e.kind == "strinket") and L.tt_strinket or L.tt_bis
        out[#out + 1] = "|cffa855f7MetaMirror:|r " .. string.format(fmt, e.name, table.concat(ctx, SEP))
    end
    return out
end

-- Gecachter Index fuer die eigene Klasse; neu, sobald sich die aktuelle Spec aendert.
local cache = { specID = nil, index = nil }
function MetaMirror:TooltipLinesFor(itemID)
    local classID, specID = self:CurrentSpecKey()
    if not classID then return {} end
    if not cache.index or cache.specID ~= specID then
        cache.index = self:BuildTooltipIndex(classID, classSpecs(classID, specID))
        cache.specID = specID
    end
    return self:TooltipLinesForIndex(cache.index, itemID)
end

local function onItemTooltip(tooltip, data)
    if not tooltip or (tooltip.IsForbidden and tooltip:IsForbidden()) then return end
    if MetaMirrorDB and MetaMirrorDB.tooltip == false then return end
    local itemID = data and data.id
    if not itemID and tooltip.GetItem then
        local _, link = tooltip:GetItem()
        itemID = link and C_Item.GetItemInfoInstant(link)
    end
    if not itemID then return end
    local ok, lines = pcall(MetaMirror.TooltipLinesFor, MetaMirror, itemID)
    if not ok then return end
    for _, s in ipairs(lines) do tooltip:AddLine(s, 0.93, 0.91, 1.0) end
end

if TooltipDataProcessor and TooltipDataProcessor.AddTooltipPostCall
   and Enum and Enum.TooltipDataType and Enum.TooltipDataType.Item then
    TooltipDataProcessor.AddTooltipPostCall(Enum.TooltipDataType.Item, onItemTooltip)
end
