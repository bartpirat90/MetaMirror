-- Ampel-Logik fuer den Ausruestungs-Tab: vergleicht ein Referenz-Item (SimC-Profil) mit dem
-- eigenen Inventar. Status je Zeile:
--   "equipped" angelegt, auf/ueber Referenzstufe   "weaker" angelegt, aber niedrigere Stufe
--   "bag"      im Beutel (nicht angelegt)          "missing" weder angelegt noch im Beutel
MetaMirror = MetaMirror or {}

-- Liest eine Zahl secret-sicher (Patch 12.0: manche Werte sind in Kampf/Instanz
-- "secret" und werfen bei Arithmetik). Unlesbar -> 0 (= unbekannt).
local function safeNumber(v)
    if type(v) ~= "number" then return 0 end
    local ok = pcall(function() return v + 0 end)
    return ok and v or 0
end

-- Inventar-Kontext: equipped[itemID] = Gegenstandsstufe (0 = unbekannt), bags[itemID] = true.
-- Ringe/Schmuck koennen doppelt angelegt sein -> hoechste Stufe gewinnt.
function MetaMirror:BuildGearContext()
    local ctx = { equipped = {}, bags = {} }
    for slot = 1, 19 do
        local id = GetInventoryItemID("player", slot)
        if id then
            local ilvl = 0
            local link = GetInventoryItemLink("player", slot)
            if link and C_Item and C_Item.GetDetailedItemLevelInfo then
                local ok, v = pcall(C_Item.GetDetailedItemLevelInfo, link)
                if ok then ilvl = safeNumber(v) end
            end
            if not ctx.equipped[id] or ctx.equipped[id] < ilvl then ctx.equipped[id] = ilvl end
        end
    end
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5) do
        local n = (C_Container and C_Container.GetContainerNumSlots(bag)) or 0
        for s = 1, n do
            local id = C_Container.GetContainerItemID(bag, s)
            if id then ctx.bags[id] = true end
        end
    end
    return ctx
end

-- refIlvl: Gegenstandsstufe der Referenz (nil/0 = unbekannt -> nie "weaker").
-- Drei Zustaende, bewusst ohne Stufen-Vergleich: wer das Item traegt, bekommt gruen --
-- egal auf welchem Aufwertungspfad. Dass ein hoeheres Item-Level besser ist, weiss
-- jeder; eine gelbe Zeile dafuer waere nur Laerm. Die Referenzstufe nennt der Tooltip
-- der Zeile, als Information statt als Wertung.
function MetaMirror:GearStatus(itemID, ctx)
    if not itemID then return "missing" end
    if ctx.equipped[itemID] then return "equipped" end
    if ctx.bags[itemID] then return "bag" end
    return "missing"
end
