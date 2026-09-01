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

-- 1-basierter Index einer beliebigen entryID (aus den WCL-Daten) in node.entryIDs.
local function entryIndexOf(node, entryID)
    if entryID and node.entryIDs then
        for i, e in ipairs(node.entryIDs) do
            if e == entryID then return i end
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

-- Baut einen Import-String fuer einen META-BUILD, gegeben als Knoten-Map
--   nodeMap = { [nodeID] = { entryID = <gewaehlte Entry-ID>, rank = <Raenge> } }
-- exakt die Datenform, die die Pipeline aus WCL liefert (nodeID/id/rank). Kopf wird 1:1
-- aus dem eigenen GenerateImportString uebernommen (korrekter treeHash, da MetaMirror die
-- eigene Spec spiegelt). Auto-gewaehrte (granted) Knoten fuellt die Live-Konfig auf, damit
-- der String genau Blizzards Aufbau trifft und der Client ihn akzeptiert.
function MetaMirror:BuildLoadoutFromMap(nodeMap)
    if not (C_ClassTalents and C_Traits) then return nil, "C_Traits API fehlt" end
    local configID = C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not configID then return nil, "keine configID" end
    local native = C_Traits.GenerateImportString and C_Traits.GenerateImportString(configID)
    if not native or native == "" then return nil, "GenerateImportString leer" end
    local info = C_Traits.GetConfigInfo(configID)
    local treeID = info and info.treeIDs and info.treeIDs[1]
    if not treeID then return nil, "keine treeID" end

    local nbits = decodeBits(native)
    local bits = {}
    for i = 1, 152 do bits[i] = nbits[i] or 0 end   -- Kopf 1:1 uebernehmen
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
        local node = C_Traits.GetNodeInfo(configID, nodeID)
        local sel = nodeMap[nodeID]
        if sel then
            writeValue(bits, 1, 1)                  -- selected
            writeValue(bits, 1, 1)                  -- purchased
            local rank = sel.rank or (node.maxRanks or 1)
            local isPartial = rank ~= (node.maxRanks or rank)
            writeValue(bits, isPartial and 1 or 0, 1)
            if isPartial then writeValue(bits, rank, 6) end
            local isChoice = isChoiceNode(node)
            writeValue(bits, isChoice and 1 or 0, 1)
            if isChoice then writeValue(bits, entryIndexOf(node, sel.entryID) - 1, 2) end
        else
            -- Nicht im Meta-Build: auto-gewaehrter (granted) Knoten? -> selected/purchased=0.
            local granted = (node.activeRank or 0) > 0 and (node.ranksPurchased or 0) == 0
            writeValue(bits, granted and 1 or 0, 1)
            if granted then writeValue(bits, 0, 1) end
        end
    end
    return encodeBits(bits), nil, native
end

-- ===== Hero-Baum: Name + aktuell aktive Wahl (fuer die Build-Karten) =====
-- Loest die entryID der Hero-Baum-Wahl (SubTreeSelection) in den lokalisierten Baumnamen
-- auf (z.B. "Diaboliker"/"Seelenernter"). Best-effort: nur fuer die aktive Spec verfuegbar;
-- schlaegt es fehl, liefert die UI einen generischen Fallback ("Held-Baum 1/2").
function MetaMirror:HeroTreeName(heroEntryID)
    if not (heroEntryID and heroEntryID > 0 and C_Traits and C_ClassTalents) then return nil end
    local configID = C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not configID then return nil end
    local ok, entry = pcall(C_Traits.GetEntryInfo, configID, heroEntryID)
    if ok and entry and entry.subTreeID and C_Traits.GetSubTreeInfo then
        local ok2, st = pcall(C_Traits.GetSubTreeInfo, configID, entry.subTreeID)
        if ok2 and st and st.name and st.name ~= "" then return st.name end
    end
    return nil
end

-- Aktuell aktive Hero-Baum-Wahl des Spielers (entryID des SubTreeSelection-Knotens).
-- Damit markiert die UI, welcher der angebotenen Builds gerade laeuft.
function MetaMirror:ActiveHeroEntryID()
    if not (C_ClassTalents and C_Traits) then return nil end
    local configID = C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not configID then return nil end
    local info = C_Traits.GetConfigInfo(configID)
    local treeID = info and info.treeIDs and info.treeIDs[1]
    if not treeID then return nil end
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
        local node = C_Traits.GetNodeInfo(configID, nodeID)
        if node and node.type == SUBTREE_SEL and node.activeEntry then
            return node.activeEntry.entryID
        end
    end
    return nil
end

-- ===== Talente per Klick anwenden (echtes Umskillen, kein Copy-String) =====
-- ImportLoadout-Eintraege aus der nodeMap: genau die Datenform, die Blizzards nativer
-- Import erwartet ({nodeID, ranksPurchased, selectionEntryID}). WCL liefert je Knoten die
-- gewaehlte entryID (auch fuer Nicht-Choice-Knoten deren einzige Entry) -> immer setzen.
local function buildImportEntries(treeID, nodeMap)
    local entries = {}
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
        local sel = nodeMap[nodeID]
        if sel then
            entries[#entries + 1] = {
                nodeID = nodeID,
                ranksGranted = 0,
                ranksPurchased = sel.rank or 1,
                selectionEntryID = sel.entryID,
            }
        end
    end
    return entries
end

-- Hat der Import wirklich in DIESE configID gestaged? (Schutz gegen versehentliches
-- Leer-Commit, falls ImportLoadout intern eine separate Config anlegt.)
local function importDidStage(configID, nodeMap)
    local hits = 0
    for nodeID, sel in pairs(nodeMap) do
        if (sel.rank or 1) > 0 then
            local node = C_Traits.GetNodeInfo(configID, nodeID)
            if node and (node.ranksPurchased or 0) > 0 then
                hits = hits + 1
                if hits >= 3 then return true end
            end
        end
    end
    return hits > 0
end

-- Summe der noch unverteilten Talentpunkte (ueber alle Waehrungen des Baums). 0 = alle
-- Punkte ausgegeben -> ein Commit gilt erst dann als wirklich erfolgreich (CommitConfig
-- allein liefert einen Fehlalarm-true, waehrend der Client "alle Punkte" rot ablehnt).
local function pointsRemaining(configID, treeID)
    local rem = 0
    if C_Traits.GetTreeCurrencyInfo then
        local ok, curr = pcall(C_Traits.GetTreeCurrencyInfo, configID, treeID, false)
        if ok and curr then for _, c in ipairs(curr) do rem = rem + (c.quantity or 0) end end
    end
    return rem
end

-- Manueller Kauf-Loop (Fallback): erst alle Choice-Knoten setzen (v.a. Hero-Baum, sonst
-- sind dessen Talente nicht kaufbar), dann in Durchgaengen kaufen (Gating).
local function manualApply(configID, treeID, nodeMap)
    local nodes = C_Traits.GetTreeNodes(treeID)
    if C_Traits.ResetTree then
        pcall(C_Traits.ResetTree, configID, treeID)
    elseif C_Traits.RefundAllRanks then
        for _, nodeID in ipairs(nodes) do pcall(C_Traits.RefundAllRanks, configID, nodeID) end
    end
    for _, nodeID in ipairs(nodes) do
        local sel = nodeMap[nodeID]
        if sel and sel.entryID then
            local node = C_Traits.GetNodeInfo(configID, nodeID)
            if isChoiceNode(node) then
                local cur = node.activeEntry and node.activeEntry.entryID
                if cur ~= sel.entryID then pcall(C_Traits.SetSelection, configID, nodeID, sel.entryID) end
            end
        end
    end
    for _ = 1, 20 do
        local progressed = false
        for _, nodeID in ipairs(nodes) do
            local sel = nodeMap[nodeID]
            if sel then
                local node = C_Traits.GetNodeInfo(configID, nodeID)
                if isChoiceNode(node) and sel.entryID then
                    local cur = node.activeEntry and node.activeEntry.entryID
                    if cur ~= sel.entryID and pcall(C_Traits.SetSelection, configID, nodeID, sel.entryID) then
                        progressed = true
                    end
                end
                local target = sel.rank or node.maxRanks or 1
                local have = (C_Traits.GetNodeInfo(configID, nodeID).ranksPurchased) or 0
                while have < target do
                    local ok, bought = pcall(C_Traits.PurchaseRank, configID, nodeID)
                    if not (ok and bought) then break end
                    progressed = true; have = have + 1
                end
            end
        end
        if not progressed then break end
    end
end

-- Diagnose bei Commit-Ablehnung: Rest-Punkte je Waehrung + gemappte Knoten, die ihren
-- Zielrang nicht erreicht haben. Unterscheidet "Kauf gescheitert" (Knoten in FEHLT) von
-- "Daten unvollstaendig" (keine FEHLT, aber Waehrung uebrig -> Meta-Build spart Punkte).
local function collectDiag(configID, treeID, nodeMap, method)
    local diag = { "ActivateBuild: Commit abgelehnt (" .. method .. ").",
                   "configID=" .. tostring(configID) .. " treeID=" .. tostring(treeID) }
    local mappedRanks = 0
    for _, sel in pairs(nodeMap) do mappedRanks = mappedRanks + (sel.rank or 1) end
    diag[#diag + 1] = "gemappte Raenge gesamt: " .. mappedRanks
    if C_Traits.GetTreeCurrencyInfo then
        local okc, curr = pcall(C_Traits.GetTreeCurrencyInfo, configID, treeID, false)
        if okc and curr then
            for _, c in ipairs(curr) do
                diag[#diag + 1] = string.format("Waehrung %s: uebrig=%s",
                    tostring(c.traitCurrencyID), tostring(c.quantity))
            end
        end
    end
    local missed = 0
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
        local sel = nodeMap[nodeID]
        if sel then
            local node = C_Traits.GetNodeInfo(configID, nodeID)
            local have = node.ranksPurchased or 0
            local want = sel.rank or 1
            local activeE = node.activeEntry and node.activeEntry.entryID
            local choiceBad = isChoiceNode(node) and sel.entryID and activeE ~= sel.entryID
            if have < want or choiceBad then
                missed = missed + 1
                if missed <= 25 then
                    diag[#diag + 1] = string.format(
                        "  FEHLT id=%d type=%s rank %d/%d choice=%s wantEntry=%s active=%s",
                        nodeID, tostring(node.type), have, want,
                        tostring(isChoiceNode(node)), tostring(sel.entryID), tostring(activeE))
                end
            end
        end
    end
    diag[#diag + 1] = "gescheiterte Knoten gesamt: " .. missed
    return table.concat(diag, "\n"), missed
end

-- Wendet einen Meta-Build (nodeMap = {[nodeID]={entryID,rank}}) auf die aktive Konfig an.
-- Weg 1: nativer ImportLoadout (Blizzard rechnet Gating/Granted/Choice-Index korrekt) ->
-- CommitConfig. Weg 2 (Fallback): manueller Kauf-Loop. Nur ausserhalb Kampf; bei Ablehnung
-- Rollback + Diagnose. Gibt (true) oder (false, grund).
function MetaMirror:ActivateBuild(nodeMap, buildName)
    if not (C_ClassTalents and C_Traits) then return false, "C_Traits API fehlt" end
    if InCombatLockdown() then return false, "im Kampf nicht moeglich" end
    local loadoutName = (buildName and buildName ~= "") and buildName or "MetaMirror"
    local configID = C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not configID then return false, "keine aktive configID" end
    local info = C_Traits.GetConfigInfo(configID)
    local treeID = info and info.treeIDs and info.treeIDs[1]
    if not treeID then return false, "keine treeID" end

    -- Weg 1: nativer Import. NICHT vorher zuruecksetzen -> falls Import in eine separate
    -- Config ginge, bliebe die aktive unveraendert (importDidStage faengt das ab, kein
    -- Leer-Commit). Nur committen, wenn der Import nachweislich hier gestaged hat.
    if C_ClassTalents.ImportLoadout then
        local entries = buildImportEntries(treeID, nodeMap)
        local pok, success = pcall(C_ClassTalents.ImportLoadout, configID, entries, loadoutName)
        if pok and success and importDidStage(configID, nodeMap) then
            local cok, committed = pcall(C_ClassTalents.CommitConfig, configID)
            -- Erfolg NUR, wenn danach keine Punkte offen sind (sonst Fehlalarm-true).
            if cok and committed and pointsRemaining(configID, treeID) == 0 then return true end
        end
        if C_Traits.RollbackConfig then pcall(C_Traits.RollbackConfig, configID) end
    end

    -- Weg 2: manueller Kauf-Loop + Commit.
    manualApply(configID, treeID, nodeMap)
    local ok, committed = pcall(C_ClassTalents.CommitConfig, configID)
    if ok and committed and pointsRemaining(configID, treeID) == 0 then return true end

    -- Beide Wege gescheitert: Diagnose sammeln (vor Rollback), Fenster + Chat zeigen.
    local text, missed = collectDiag(configID, treeID, nodeMap, "Loop")
    if C_Traits.RollbackConfig then pcall(C_Traits.RollbackConfig, configID) end
    if self.ShowCopy then self:ShowCopy(text, "ActivateBuild-Diagnose") end
    -- Kern-Diagnose zusaetzlich in den Chat (falls das Fenster uebersehen wird).
    print("|cffdf5a3f[MM] ActivateBuild fehlgeschlagen|r - " .. missed
        .. " Knoten offen. Diagnose-Fenster (Strg+C) schicken. Erste Zeilen:")
    for line in string.gmatch(text, "[^\n]+") do
        if line:find("Waehrung") or line:find("FEHLT") or line:find("gemappte") then
            print("|cffa855f7[MM]|r " .. line)
        end
    end
    return false, "Commit abgelehnt - Details im Fenster (" .. missed .. " Knoten offen)"
end

-- /mm testapply: READ-ONLY-Pruefung, ob der Meta-Build ueberhaupt anwendbar ist -
-- ohne umzuskillen. Prueft je gemapptem Knoten: existiert er im aktuellen Baum? Ist die
-- WCL-entryID eine GUELTIGE Entry dieses Choice-Knotens? Ist der Rang <= maxRanks?
-- Das beweist/widerlegt "WCL-entryID ungueltig" als Ursache der 4 offenen Punkte.
function MetaMirror:DiagnoseApplyMap(nodeMap)
    if not nodeMap then
        print("|cffdf5a3f[MM]|r Kein Build geladen - erst den Talente-Tab oeffnen."); return
    end
    if not (C_ClassTalents and C_Traits) then print("|cffdf5a3f[MM]|r API fehlt"); return end
    local configID = C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not configID then print("|cffdf5a3f[MM]|r keine configID"); return end
    local info = C_Traits.GetConfigInfo(configID)
    local treeID = info and info.treeIDs and info.treeIDs[1]
    if not treeID then print("|cffdf5a3f[MM]|r keine treeID"); return end
    local inTree = {}
    for _, nid in ipairs(C_Traits.GetTreeNodes(treeID)) do inTree[nid] = true end

    local lines = { "Apply-Diagnose (read-only, kein Umskillen):" }
    local notInTree, badEntry, rankHigh, mapRanks, choiceCount = 0, 0, 0, 0, 0
    for nodeID, sel in pairs(nodeMap) do
        mapRanks = mapRanks + (sel.rank or 1)
        if not inTree[nodeID] then
            notInTree = notInTree + 1
            if notInTree <= 25 then
                lines[#lines + 1] = string.format("  KNOTEN NICHT IM BAUM id=%d entry=%s",
                    nodeID, tostring(sel.entryID))
            end
        else
            local node = C_Traits.GetNodeInfo(configID, nodeID)
            if isChoiceNode(node) then
                choiceCount = choiceCount + 1
                local valid = false
                if node.entryIDs and sel.entryID then
                    for _, e in ipairs(node.entryIDs) do if e == sel.entryID then valid = true; break end end
                end
                if not valid then
                    badEntry = badEntry + 1
                    local avail = node.entryIDs and table.concat(node.entryIDs, "/") or "?"
                    lines[#lines + 1] = string.format("  ENTRY UNGUELTIG id=%d want=%s hat=[%s] type=%s",
                        nodeID, tostring(sel.entryID), avail, tostring(node.type))
                end
            end
            if node.maxRanks and (sel.rank or 1) > node.maxRanks then
                rankHigh = rankHigh + 1
                lines[#lines + 1] = string.format("  RANG ZU HOCH id=%d rank=%d max=%d",
                    nodeID, sel.rank or 1, node.maxRanks)
            end
        end
    end
    lines[#lines + 1] = string.format(
        "Summe: mapRaenge=%d choiceKnoten=%d | nichtImBaum=%d ungueltigeEntry=%d rangZuHoch=%d",
        mapRanks, choiceCount, notInTree, badEntry, rankHigh)

    -- Vergleich mit dem AKTUELL aktiven (vollstaendigen) Build: welche Knoten hat DER
    -- Spieler gekauft, die im Meta-Build fehlen (oder mit weniger Raengen)? -> genau die
    -- von WCL evtl. ausgelassenen Punkte. liveRanks = Punkte eines kompletten Builds.
    local liveRanks, missingVsLive, shownM = 0, 0, 0
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
        local node = C_Traits.GetNodeInfo(configID, nodeID)
        local live = node.ranksPurchased or 0
        liveRanks = liveRanks + live
        local mapped = nodeMap[nodeID]
        local mrank = mapped and (mapped.rank or 1) or 0
        if live > mrank then
            missingVsLive = missingVsLive + (live - mrank)
            shownM = shownM + 1
            if shownM <= 40 then
                lines[#lines + 1] = string.format("  META<LIVE id=%d live=%d meta=%d type=%s",
                    nodeID, live, mrank, tostring(node.type))
            end
        end
    end
    lines[#lines + 1] = string.format(
        "liveRanks=%d mapRaenge=%d -> Meta gibt ~%d Punkte weniger aus als dein Build",
        liveRanks, mapRanks, missingVsLive)

    for _, l in ipairs(lines) do print("|cffa855f7[MM]|r " .. l) end
    if self.ShowCopy then self:ShowCopy(table.concat(lines, "\n"), "Apply-Diagnose") end
end

-- /mm apitalents: listet, welche fuer das Umskillen noetigen API-Funktionen existieren.
-- Damit laesst sich ein Fehlschlag von ActivateBuild in einem Lauf diagnostizieren.
function MetaMirror:DumpTalentAPI()
    local checks = {
        "C_ClassTalents.GetActiveConfigID", "C_ClassTalents.CommitConfig",
        "C_ClassTalents.LoadConfig", "C_ClassTalents.ImportLoadout",
        "C_Traits.GetConfigInfo", "C_Traits.GetTreeNodes", "C_Traits.GetNodeInfo",
        "C_Traits.ResetTree", "C_Traits.RefundAllRanks", "C_Traits.RefundRank",
        "C_Traits.PurchaseRank", "C_Traits.SetSelection", "C_Traits.RollbackConfig",
        "C_Traits.CanPurchaseRank", "C_Traits.GetTreeInfo",
    }
    local lines = { "Talent-API-Check:" }
    for _, path in ipairs(checks) do
        local tbl, fn = path:match("^(.-)%.(.+)$")
        local t = _G[tbl]
        local exists = t and type(t[fn]) == "function"
        lines[#lines + 1] = (exists and "  [x] " or "  [ ] ") .. path
    end
    print("|cffa855f7[MM]|r " .. table.concat(lines, "\n"))
    if self.ShowCopy then self:ShowCopy(table.concat(lines, "\n"), "Talent-API") end
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

-- /mm testmetatalent: beweist den MAP-Weg (BuildLoadoutFromMap) mit genau der Datenform,
-- die die Pipeline liefert. Baut die Map aus dem eigenen Build (gekaufte Knoten ->
-- {entryID, rank}) und vergleicht bit-genau mit dem nativen String.
function MetaMirror:TestMetaTalentString()
    local configID = C_ClassTalents and C_ClassTalents.GetActiveConfigID and C_ClassTalents.GetActiveConfigID()
    if not configID then print("|cffdf5a3f[MM]|r keine configID"); return end
    local info = C_Traits.GetConfigInfo(configID)
    local treeID = info and info.treeIDs and info.treeIDs[1]
    local map = {}
    for _, nodeID in ipairs(C_Traits.GetTreeNodes(treeID)) do
        local n = C_Traits.GetNodeInfo(configID, nodeID)
        if (n.ranksPurchased or 0) > 0 then
            map[nodeID] = {
                entryID = n.activeEntry and n.activeEntry.entryID,
                rank = n.ranksPurchased,
            }
        end
    end
    local mine, err, native = self:BuildLoadoutFromMap(map)
    if not mine then print("|cffdf5a3f[MM] TestMetaTalent FAIL|r - " .. tostring(err)); return end
    if mine == native then
        print("|cff30d15a[MM] TestMetaTalent PASS|r - Map-Serialisierung bit-genau")
        return
    end
    print("|cffdf5a3f[MM] TestMetaTalent FAIL|r - Laenge nativ=" .. #native .. " meins=" .. #mine)
    local mb, nb = decodeBits(mine), decodeBits(native)
    local diff
    for i = 1, math.max(#mb, #nb) do
        if (mb[i] or -1) ~= (nb[i] or -1) then diff = i; break end
    end
    print("erstes abweichendes Bit: " .. tostring(diff))
    self:ShowCopy("NATIV:\n" .. native .. "\n\nMEINS:\n" .. mine, "TestMetaTalent")
end
