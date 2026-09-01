-- Talent-Loadout-Serialisierer (Blizzard C_Traits Export-Format).
-- Portiert aus pipeline/talent_string.py; dort per Round-Trip gegen einen echten
-- In-Game-String bit-genau verifiziert. Zweck: aus einer Knotenauswahl (spaeter dem
-- Meta-Build) einen Import-String bauen, den der Spieler im Talent-UI einfuegen kann.
--
-- Format: Standard-Base64-Charset, Bitstrom LSB-first.
--   Kopf: version(8)=2 + specID(16) + treeHash(16 Bytes)
--   je Knoten in C_Traits.GetTreeNodes(treeID)-Reihenfolge (exakt wie Blizzards
--   WriteLoadoutContent): selected(1); wenn selected: purchased(1); wenn purchased:
--   partiallyRanked(1)[+rank(6)], choiceNode(1)[+entryIndex-1(2)]. Padding auf x6.
MetaMirror = MetaMirror or {}

local B64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local B64IDX = {}
for i = 1, #B64 do B64IDX[B64:sub(i, i)] = i - 1 end

-- ===== Bit-Writer / Base64 (LSB-first, wie ExportUtil) =====
local function writeValue(bits, value, nbits)
    for i = 0, nbits - 1 do
        bits[#bits + 1] = bit.band(bit.rshift(value, i), 1)
    end
end

local function encodeBits(bits)
    while (#bits % 6) ~= 0 do bits[#bits + 1] = 0 end   -- Null-Padding auf Vielfaches von 6
    local out = {}
    for i = 1, #bits, 6 do
        local v = 0
        for b = 0, 5 do v = bit.bor(v, bit.lshift(bits[i + b] or 0, b)) end
        out[#out + 1] = B64:sub(v + 1, v + 1)
    end
    return table.concat(out)
end

local function decodeBits(str)
    local bits = {}
    for i = 1, #str do
        local v = B64IDX[str:sub(i, i)] or 0
        for b = 0, 5 do bits[#bits + 1] = bit.band(bit.rshift(v, b), 1) end
    end
    return bits
end

-- Enum.TraitNodeType.Selection = Choice-Node (2 Entries); Fallback 2, falls Enum fehlt.
local SELECTION = (Enum and Enum.TraitNodeType and Enum.TraitNodeType.Selection) or 2

-- 1-basierter Index der aktiven Entry innerhalb node.entryIDs (Blizzard speichert idx-1).
local function activeEntryIndex(node)
    if node.activeEntry and node.entryIDs then
        for i, entryID in ipairs(node.entryIDs) do
            if entryID == node.activeEntry.entryID then return i end
        end
    end
    return 1
end

-- Serialisiert den Knoten-Teil (ohne Kopf) fuer die AKTUELLE Belegung der configID.
-- Exakt Blizzards WriteLoadoutContent nachgebaut, damit der String bit-identisch wird.
local function writeLoadoutContent(bits, configID, treeID)
    local nodes = C_Traits.GetTreeNodes(treeID)
    for _, nodeID in ipairs(nodes) do
        local node = C_Traits.GetNodeInfo(configID, nodeID)
        local ranks = node.ranksPurchased or 0
        local activeRank = node.activeRank or 0
        local isPurchased = ranks > 0
        local isGranted = (activeRank - ranks) > 0
        local isSelected = isPurchased or isGranted
        writeValue(bits, isSelected and 1 or 0, 1)
        if isSelected then
            writeValue(bits, isPurchased and 1 or 0, 1)
            if isPurchased then
                local isPartial = ranks ~= (node.maxRanks or ranks)
                writeValue(bits, isPartial and 1 or 0, 1)
                if isPartial then writeValue(bits, ranks, 6) end
                local isChoice = (node.type == SELECTION)
                writeValue(bits, isChoice and 1 or 0, 1)
                if isChoice then writeValue(bits, activeEntryIndex(node) - 1, 2) end
            end
        end
    end
end

-- Baut einen Import-String fuer die AKTUELLE Belegung: Kopf (version/specID/treeHash)
-- wird 1:1 aus dem nativen GenerateImportString uebernommen (garantiert korrekter Hash),
-- der Knotenteil selbst serialisiert. So ist kein Tree-Hash-Nachbau noetig.
function MetaMirror:BuildOwnLoadoutString()
    if not (C_ClassTalents and C_Traits) then return nil, "C_Traits API fehlt" end
    local configID = C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not configID then return nil, "keine aktive configID" end
    local native = C_Traits.GenerateImportString and C_Traits.GenerateImportString(configID)
    if not native or native == "" then return nil, "GenerateImportString leer" end
    local info = C_Traits.GetConfigInfo(configID)
    local treeID = info and info.treeIDs and info.treeIDs[1]
    if not treeID then return nil, "keine treeID" end

    -- Kopf = erste 152 Bit des nativen Strings (8 version + 16 specID + 128 treeHash).
    local nbits = decodeBits(native)
    local bits = {}
    for i = 1, 152 do bits[i] = nbits[i] or 0 end
    writeLoadoutContent(bits, configID, treeID)
    return encodeBits(bits), nil, native
end

-- /mm testtalent: baut den eigenen Build nach und vergleicht bit-genau mit dem nativen
-- String. PASS beweist den Serialisierer in-game; bei FAIL zeigt es das erste Diff-Bit
-- und beide Strings im Kopier-Frame zum Zuschicken.
function MetaMirror:TestTalentString()
    local mine, err, native = self:BuildOwnLoadoutString()
    if not mine then
        print("|cffdf5a3f[MM] TestTalent FAIL|r - " .. tostring(err))
        return
    end
    if mine == native then
        print("|cff30d15a[MM] TestTalent PASS|r - Round-Trip bit-genau (" .. #mine .. " Zeichen)")
        return
    end
    print("|cffdf5a3f[MM] TestTalent FAIL|r - Laenge nativ=" .. #native .. " meins=" .. #mine)
    local mb, nb = decodeBits(mine), decodeBits(native)
    local diff
    for i = 1, math.max(#mb, #nb) do
        if (mb[i] or -1) ~= (nb[i] or -1) then diff = i; break end
    end
    print("erstes abweichendes Bit: " .. tostring(diff))
    self:ShowCopy("NATIV:\n" .. native .. "\n\nMEINS:\n" .. mine, "TestTalent")
end
