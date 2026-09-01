-- Item-Quelle (Abenteuerfuehrer): baut einmalig einen Index itemID -> Boss/Instanz
-- aus dem Encounter Journal auf und liefert daraus Anzeige-Text + Deep-Link.
-- Der Journal-Loot deckt Raid/Dungeon ab; Handwerk/Haendler/Welt stehen dort nicht
-- (-> keine Quelle, kein Link). Der Index ist die Wahrheit des Clients, damit der
-- Deep-Link (EncounterJournal_OpenJournal) garantiert zum richtigen Boss passt.
MetaMirror = MetaMirror or {}

-- Bevorzugte (hoechste) Schwierigkeit je Instanztyp; die erste gueltige gewinnt.
-- Der Boss-/Instanzname ist schwierigkeitsunabhaengig -> eine Stufe pro Instanz genuegt.
local RAID_DIFFS = { 16, 15, 14 }   -- Mythisch, Heroisch, Normal
local DUNG_DIFFS = { 23, 2, 1 }     -- Mythisch, Heroisch, Normal

local index = {}     -- itemID -> { text, instanceID, encounterID, difficultyID }
local state = "idle" -- "idle" | "running" | "done" (asynchroner Index-Aufbau)
local co, ticker     -- Coroutine + C_Timer-Ticker fuer den inkrementellen Scan
local filterClassID, filterSpecID   -- fuer den Klassen-Set-Filter waehrend des Scans

local function applyLootFilter()
    -- Klassen-Set-Teile (Tier) erscheinen im Journal-Loot nur mit KONKRETEM Spec-Filter
    -- (classID + specID); mit specID 0 fehlen sie. Wird pro Instanz neu gesetzt, da
    -- EJ_SelectInstance den Filter zuruecksetzen kann.
    if filterClassID and filterSpecID and EJ_SetLootFilter then
        pcall(EJ_SetLootFilter, filterClassID, filterSpecID)
    end
end

local function ensureEJ()
    -- EJ_-Datenfunktionen brauchen das Blizzard-Journal-Addon geladen.
    local loaded = (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal"))
    if not loaded then
        if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
        elseif UIParentLoadAddOn then UIParentLoadAddOn("Blizzard_EncounterJournal") end
    end
    return EJ_GetNumTiers ~= nil
end

local function firstValidDiff(diffs)
    for _, d in ipairs(diffs) do
        if not EJ_IsValidInstanceDifficulty or EJ_IsValidInstanceDifficulty(d) then
            return d
        end
    end
    return diffs[#diffs]
end

local function indexInstance(instanceID, isRaid)
    EJ_SelectInstance(instanceID)
    applyLootFilter()   -- nach der Instanzwahl (Filter kann dabei zuruecksetzen)
    local diff = firstValidDiff(isRaid and RAID_DIFFS or DUNG_DIFFS)
    if EJ_SetDifficulty then pcall(EJ_SetDifficulty, diff) end
    local e = 1
    while true do
        local name, _, encounterID = EJ_GetEncounterInfoByIndex(e, instanceID)
        if not encounterID then break end
        EJ_SelectEncounter(encounterID)
        local n = (EJ_GetNumLoot and EJ_GetNumLoot()) or 0
        for i = 1, n do
            local info = C_EncounterJournal.GetLootInfoByIndex(i)
            local iid = info and info.itemID
            if iid and not index[iid] then
                index[iid] = { text = name, instanceID = instanceID,
                               encounterID = encounterID, difficultyID = diff }
            end
        end
        e = e + 1
    end
end

-- Der eigentliche Scan als Coroutine: nach JEDER Instanz coroutine.yield(), damit der
-- Ticker die Arbeit ueber mehrere Frames verteilt (kein Sekunden-Hang mehr). WICHTIG
-- (Lua 5.1): yield darf NICHT innerhalb eines pcall stehen -> die EJ-Aufrufe einzeln
-- per pcall schuetzen (indexInstance yieldet nicht), yield nur im Coroutine-Rumpf.
local function buildCoroutine()
    if not ensureEJ() then return end
    -- Klassen-/Spec-Filter fuer den Scan bestimmen (fuer die Tier-Set-Teile noetig).
    local _, _, classID = UnitClass("player")
    local specIndex = GetSpecialization and GetSpecialization()
    local specID = specIndex and GetSpecializationInfo and GetSpecializationInfo(specIndex)
    filterClassID, filterSpecID = classID, specID
    applyLootFilter()
    local curTier = EJ_GetCurrentTier and EJ_GetCurrentTier()
    local numTiers = EJ_GetNumTiers() or 0
    for tier = 1, numTiers do
        if EJ_SelectTier then pcall(EJ_SelectTier, tier) end
        for _, isRaid in ipairs({ false, true }) do
            local idx = 1
            while true do
                local instanceID = EJ_GetInstanceByIndex(idx, isRaid)
                if not instanceID then break end
                pcall(indexInstance, instanceID, isRaid)   -- pcall OHNE yield darin
                idx = idx + 1
                coroutine.yield()                          -- Pause AUSSERHALB jedes pcall
            end
        end
    end
    if curTier and EJ_SelectTier then pcall(EJ_SelectTier, curTier) end  -- UI-Zustand wiederherstellen
end

local function finishBuild()
    state = "done"
    co = nil
    if ticker then ticker:Cancel(); ticker = nil end
    -- Ist das Panel gerade offen (Gear/Schmuck)? -> Quellen nachtragen.
    if MetaMirror.Refresh and MetaMirrorPanel and MetaMirrorPanel.IsShown
        and MetaMirrorPanel:IsShown() then
        MetaMirror:Refresh()
    end
end

-- Ein Ticker-Schritt: die Coroutine so lange fortsetzen, bis ein Zeitbudget je Frame
-- erreicht ist (schnell fertig, aber nie ein spuerbarer Hang). debugprofilestop = ms.
local function tick()
    if not co then if ticker then ticker:Cancel(); ticker = nil end return end
    local budget = (debugprofilestop and (debugprofilestop() + 8)) or nil
    while co do
        local ok = coroutine.resume(co)
        if not ok or coroutine.status(co) == "dead" then finishBuild(); return end
        if budget and debugprofilestop() >= budget then return end
        if not budget then return end   -- ohne Timer-API: ein Schritt pro Frame
    end
end

-- Startet den asynchronen Index-Aufbau (idempotent). Wird beim Login vorgewaermt, kann
-- aber auch beim ersten GetItemSource anlaufen -> blockiert nie den Render-Pfad.
function MetaMirror:PrimeItemSources()
    if state ~= "idle" then return end
    state = "running"
    index = {}
    co = coroutine.create(buildCoroutine)
    if C_Timer and C_Timer.NewTicker then
        ticker = C_Timer.NewTicker(0, tick)
    else
        -- Sehr alter Client ohne C_Timer: einmal synchron durchlaufen (Fallback).
        while co do
            local ok = coroutine.resume(co)
            if not ok or coroutine.status(co) == "dead" then finishBuild(); break end
        end
    end
end

-- Liefert { text, instanceID, encounterID, difficultyID } oder nil (Handwerk/unbekannt).
-- Loest den Aufbau bei Bedarf aus (asynchron), gibt bis zur Fertigstellung ggf. nil.
function MetaMirror:GetItemSource(itemID)
    if not itemID then return nil end
    if state == "idle" then self:PrimeItemSources() end
    return index[itemID]
end

-- Oeffnet den Abenteuerfuehrer direkt beim Boss der Quelle.
function MetaMirror:OpenSource(src)
    if not src or not src.encounterID then return end
    if not (C_AddOns and C_AddOns.IsAddOnLoaded and C_AddOns.IsAddOnLoaded("Blizzard_EncounterJournal")) then
        if C_AddOns and C_AddOns.LoadAddOn then C_AddOns.LoadAddOn("Blizzard_EncounterJournal")
        elseif UIParentLoadAddOn then UIParentLoadAddOn("Blizzard_EncounterJournal") end
    end
    if EncounterJournal_OpenJournal then
        EncounterJournal_OpenJournal(src.difficultyID, src.instanceID, src.encounterID)
    end
end

-- Set der Basis-itemIDs, die der Spieler besitzt (getragen + Taschen), upgrade-
-- unabhaengig (nur itemID, ohne bonusIDs) -> Abgleich egal auf welchem Upgrade-Pfad.
function MetaMirror:BuildOwnedSet()
    local owned = {}
    for slot = 1, 19 do
        local id = GetInventoryItemID("player", slot)
        if id then owned[id] = true end
    end
    for bag = 0, (NUM_TOTAL_EQUIPPED_BAG_SLOTS or 5) do
        local n = (C_Container and C_Container.GetContainerNumSlots(bag)) or 0
        for s = 1, n do
            local id = C_Container.GetContainerItemID(bag, s)
            if id then owned[id] = true end
        end
    end
    return owned
end
