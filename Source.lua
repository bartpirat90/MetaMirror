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

local index          -- itemID -> { text, instanceID, encounterID, difficultyID }
local built = false
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

local function build()
    index = {}
    if not ensureEJ() then built = true; return end
    -- Klassen-/Spec-Filter fuer den Scan bestimmen (fuer die Tier-Set-Teile noetig).
    local _, _, classID = UnitClass("player")
    local specIndex = GetSpecialization and GetSpecialization()
    local specID = specIndex and GetSpecializationInfo and GetSpecializationInfo(specIndex)
    filterClassID, filterSpecID = classID, specID
    applyLootFilter()
    local curTier = EJ_GetCurrentTier and EJ_GetCurrentTier()
    local numTiers = EJ_GetNumTiers() or 0
    for tier = 1, numTiers do
        pcall(function()
            EJ_SelectTier(tier)
            for _, isRaid in ipairs({ false, true }) do
                local idx = 1
                while true do
                    local instanceID = EJ_GetInstanceByIndex(idx, isRaid)
                    if not instanceID then break end
                    indexInstance(instanceID, isRaid)
                    idx = idx + 1
                end
            end
        end)
    end
    if curTier and EJ_SelectTier then pcall(EJ_SelectTier, curTier) end  -- UI-Zustand wiederherstellen
    built = true
end

-- Liefert { text, instanceID, encounterID, difficultyID } oder nil (Handwerk/unbekannt).
function MetaMirror:GetItemSource(itemID)
    if not itemID then return nil end
    if not built then
        local ok = pcall(build)
        if not ok then index = index or {}; built = true end
    end
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
