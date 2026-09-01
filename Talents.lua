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

-- Choice-Nodes schreiben ein Auswahl-Bit + 2-Bit-Entry-Index. Das sind ZWEI Typen:
-- Selection (normale Entweder-oder-Talente) UND SubTreeSelection (Hero-Talent-Baumwahl).
-- Beide muessen als Choice gelten, sonst verschiebt sich der Bitstrom ab dem Hero-Knoten.
local SELECTION = (Enum and Enum.TraitNodeType and Enum.TraitNodeType.Selection) or 2
local SUBTREE_SEL = (Enum and Enum.TraitNodeType and Enum.TraitNodeType.SubTreeSelection) or 3
local function isChoiceNode(node)
    return node.type == SELECTION or node.type == SUBTREE_SEL
end

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
                local isChoice = isChoiceNode(node)
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

-- Parst einen Loadout-String (nach dem 152-Bit-Kopf) in Knoten-Records -- generisch aus
-- dem Bitstrom, also die WAHRHEIT je Knoten (unabhaengig von meiner Ableitung).
local function parseLoadout(str)
    local bits = decodeBits(str)
    local pos = 152
    local function rd(n)
        local v = 0
        for i = 0, n - 1 do v = bit.bor(v, bit.lshift(bits[pos + 1 + i] or 0, i)) end
        pos = pos + n; return v
    end
    local recs = {}
    while pos < #bits do
        local r = { sel = rd(1) }
        if r.sel == 1 then
            r.pur = rd(1)
            if r.pur == 1 then
                r.part = rd(1)
                if r.part == 1 then r.rank = rd(6) end
                r.choice = rd(1)
                if r.choice == 1 then r.entry = rd(2) end
            end
        end
        recs[#recs + 1] = r
    end
    return recs
end

-- Meine Ableitung eines Knoten-Records aus GetNodeInfo (dieselbe Logik wie der Writer).
local function deriveRecord(node)
    local ranks = node.ranksPurchased or 0
    local activeRank = node.activeRank or 0
    local isPur = ranks > 0
    local isGranted = (activeRank - ranks) > 0
    local r = { sel = (isPur or isGranted) and 1 or 0 }
    if r.sel == 1 then
        r.pur = isPur and 1 or 0
        if isPur then
            local part = ranks ~= (node.maxRanks or ranks)
            r.part = part and 1 or 0
            if part then r.rank = ranks end
            local isChoice = isChoiceNode(node)
            r.choice = isChoice and 1 or 0
            if isChoice then r.entry = activeEntryIndex(node) - 1 end
        end
    end
    return r
end

local function recStr(r)
    if not r then return "nil" end
    local s = "sel=" .. tostring(r.sel)
    if r.pur ~= nil then s = s .. " pur=" .. r.pur end
    if r.part ~= nil then s = s .. " part=" .. r.part end
    if r.rank ~= nil then s = s .. " rank=" .. r.rank end
    if r.choice ~= nil then s = s .. " choice=" .. r.choice end
    if r.entry ~= nil then s = s .. " entry=" .. r.entry end
    return s
end

-- /mm difftalent: zeigt je Baum-Knoten, wo meine Ableitung von Blizzards eigenem String
-- abweicht, samt type/entryIDs/ranks -> daraus leite ich die exakte Choice-Regel ab.
function MetaMirror:DiffTalentString()
    local configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not configID then print("|cffdf5a3f[MM]|r keine configID"); return end
    local native = C_Traits.GenerateImportString(configID)
    local info = C_Traits.GetConfigInfo(configID)
    local treeID = info and info.treeIDs and info.treeIDs[1]
    local truth = parseLoadout(native)
    local nodes = C_Traits.GetTreeNodes(treeID)
    local lines = { "Knoten=" .. #nodes .. "  native-Records=" .. #truth,
                    "SELECTION-Enum=" .. tostring(SELECTION),
                    "Enum.TraitNodeType=" .. (Enum and Enum.TraitNodeType and
                        ("Single=" .. tostring(Enum.TraitNodeType.Single) ..
                         " Tiered=" .. tostring(Enum.TraitNodeType.Tiered) ..
                         " Selection=" .. tostring(Enum.TraitNodeType.Selection) ..
                         " SubTreeSel=" .. tostring(Enum.TraitNodeType.SubTreeSelection)) or "?"),
                    "--- Abweichungen (i: nodeID) ---" }
    local diffs = 0
    for i, nodeID in ipairs(nodes) do
        local node = C_Traits.GetNodeInfo(configID, nodeID)
        local mine = deriveRecord(node)
        local t = truth[i]
        local same = t and mine.sel == t.sel and mine.pur == t.pur and mine.part == t.part
            and mine.rank == t.rank and mine.choice == t.choice and mine.entry == t.entry
        if not same then
            diffs = diffs + 1
            if diffs <= 25 then
                local ne = node.entryIDs and #node.entryIDs or 0
                lines[#lines + 1] = string.format(
                    "%d: id=%d type=%s #entry=%d ranks=%s/%s active=%s",
                    i, nodeID, tostring(node.type), ne,
                    tostring(node.ranksPurchased), tostring(node.maxRanks),
                    tostring(node.activeRank))
                lines[#lines + 1] = "    NATIV: " .. recStr(t)
                lines[#lines + 1] = "    MEINS: " .. recStr(mine)
            end
        end
    end
    lines[#lines + 1] = "Abweichungen gesamt: " .. diffs
    print("|cffa855f7[MM]|r DiffTalent: " .. diffs .. " Abweichungen -> Kopier-Frame")
    self:ShowCopy(table.concat(lines, "\n"), "DiffTalent")
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
