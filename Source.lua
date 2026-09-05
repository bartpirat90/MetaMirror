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

-- Persistenter Cache (SavedVariables, account-weit): der Journal-Scan ist teuer und
-- ruckelt beim ersten Mal. Das Ergebnis haelt bis zum naechsten Client-Patch -> danach
-- laedt der Login den fertigen Index sofort aus dem Cache (kein Scan, kein Journal-Load,
-- kein Ruckeln). Boss-Namen sind lokalisiert -> Locale gehoert in den Cache-Schluessel.
-- SCAN_VERSION erhoehen, sobald buildCoroutine einen anderen Umfang scannt: so wird ein
-- Cache aus einer aelteren Addon-Version (anderer Umfang) verworfen und neu aufgebaut.
local SCAN_VERSION = 4   -- v3: pcall je Boss; v4: zweiter Durchlauf ohne Loot-Filter (Items anderer Specs)
local function clientTag()
    local _, _, _, iface = GetBuildInfo()
    return (tostring(iface or "0")) .. "-" .. (GetLocale() or "enUS") .. "-v" .. SCAN_VERSION
end
local function loadCache()
    local c = MetaMirrorSrcCache
    if c and c.tag == clientTag() and type(c.index) == "table" and next(c.index) then
        return c.index
    end
    return nil
end
local function saveCache()
    if next(index) then   -- nie einen leeren Scan cachen (sonst dauerhaft leer)
        MetaMirrorSrcCache = { tag = clientTag(), index = index }
    end
end

-- Zwei Scan-Durchlaeufe:
--   "spec": Klassen-Set-Teile (Tier) erscheinen im Journal-Loot nur mit KONKRETEM
--           Spec-Filter (classID + specID); mit specID 0 fehlen sie.
--   "all":  Filter zurueckgesetzt -> Trinkets/Items ANDERER Specs, die Bloodmallet trotzdem
--           fuer uns simuliert (z. B. Ula'teks Herz, Goetze des Kriegsloa), fehlten sonst
--           im Index und liefen faelschlich als "ohne Quelle".
-- Wird pro Tier/Instanz neu gesetzt, da EJ_SelectInstance den Filter zuruecksetzen kann.
local filterMode = "spec"
local function applyLootFilter()
    if filterMode == "all" then
        if EJ_ResetLootFilter then pcall(EJ_ResetLootFilter)
        elseif EJ_SetLootFilter then pcall(EJ_SetLootFilter, 0, 0) end
    elseif filterClassID and filterSpecID and EJ_SetLootFilter then
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

-- Loot EINES Bosses in den Index uebernehmen; gibt die Anzahl Loot-Eintraege zurueck.
local function indexEncounter(name, encounterID, instanceID, diff)
    EJ_SelectEncounter(encounterID)
    local n = (EJ_GetNumLoot and EJ_GetNumLoot()) or 0
    local added = 0
    for i = 1, n do
        local info = C_EncounterJournal.GetLootInfoByIndex(i)
        local iid = info and info.itemID
        if iid and not index[iid] then
            index[iid] = { text = name, instanceID = instanceID,
                           encounterID = encounterID, difficultyID = diff }
            added = added + 1
        end
    end
    return n, added
end

-- report (optional, Diagnose): Tabelle, an die je Instanz/Boss Zeilen angehaengt werden.
local function indexInstance(instanceID, isRaid, report)
    EJ_SelectInstance(instanceID)
    applyLootFilter()   -- nach der Instanzwahl (Filter kann dabei zuruecksetzen)
    local diff = firstValidDiff(isRaid and RAID_DIFFS or DUNG_DIFFS)
    if EJ_SetDifficulty then pcall(EJ_SetDifficulty, diff) end
    local instName = (EJ_GetInstanceInfo and EJ_GetInstanceInfo(instanceID)) or "?"
    local e, encounters, items, new = 1, 0, 0, 0
    while true do
        local name, _, encounterID = EJ_GetEncounterInfoByIndex(e, instanceID)
        if not encounterID then break end
        encounters = encounters + 1
        -- pcall JE BOSS: ein Fehler bei einem Boss darf die folgenden Bosse derselben
        -- Instanz nicht ueberspringen (genau das liess frueher Raid-Trinkets ohne Quelle).
        local ok, n, added = pcall(indexEncounter, name, encounterID, instanceID, diff)
        if ok then
            items = items + (n or 0)
            new = new + (added or 0)
            if report and (n or 0) == 0 then
                report[#report + 1] = string.format("    ! %s: 0 Loot-Eintraege", tostring(name))
            end
        elseif report then
            report[#report + 1] = string.format("    ! %s: FEHLER %s", tostring(name), tostring(n))
        end
        e = e + 1
    end
    if report then
        report[#report + 1] = string.format("  %s %s [%d]: %d Bosse, %d Loot, %d neu",
            isRaid and "Raid" or "Dung", tostring(instName), instanceID, encounters, items, new)
    end
end

-- Der eigentliche Scan als Coroutine: nach JEDER Instanz coroutine.yield(), damit der
-- Ticker die Arbeit ueber mehrere Frames verteilt (kein Sekunden-Hang mehr). WICHTIG
-- (Lua 5.1): yield darf NICHT innerhalb eines pcall stehen -> die EJ-Aufrufe einzeln
-- per pcall schuetzen (indexInstance yieldet nicht), yield nur im Coroutine-Rumpf.
local function buildCoroutine(report)
    if not ensureEJ() then
        if report then report[#report + 1] = "! Blizzard_EncounterJournal nicht ladbar" end
        return
    end
    -- Klassen-/Spec-Filter fuer den Scan bestimmen (fuer die Tier-Set-Teile noetig).
    local _, _, classID = UnitClass("player")
    local specIndex = GetSpecialization and GetSpecialization()
    local specID = specIndex and GetSpecializationInfo and GetSpecializationInfo(specIndex)
    filterClassID, filterSpecID = classID, specID
    applyLootFilter()
    -- ALLE Tiers scannen: die Meta-Rangliste enthaelt auch Trinkets aelterer Seasons
    -- (Drops, die weiter mitgenommen werden). Nur der aktuelle Tier liesse sie ohne
    -- Quelle -> sie liefen faelschlich in den Fallback. Der Scan laeuft nur EINMAL pro
    -- Patch (danach Cache) und verteilt sich per Ticker-Budget ueber viele Frames ->
    -- kein Login-Ruck (den verursachten der synchrone Journal-Load + zu grosses Budget,
    -- beides bereits behoben, nicht der verteilte Scan selbst).
    local curTier = EJ_GetCurrentTier and EJ_GetCurrentTier()
    local numTiers = EJ_GetNumTiers() or 0
    for _, mode in ipairs({ "spec", "all" }) do
        filterMode = mode
        if report then
            report[#report + 1] = string.format("=== Durchlauf %s (%s) ===", mode,
                mode == "spec" and "Loot-Filter Klasse+Spec" or "Loot-Filter aus, alle Klassen")
        end
        for tier = 1, numTiers do
            if EJ_SelectTier then pcall(EJ_SelectTier, tier) end
            applyLootFilter()   -- Tierwechsel kann den Loot-Filter zuruecksetzen
            if report then
                report[#report + 1] = string.format("Tier %d: %s", tier,
                    tostring(EJ_GetTierInfo and EJ_GetTierInfo(tier) or "?"))
            end
            for _, isRaid in ipairs({ false, true }) do
                local idx = 1
                while true do
                    local instanceID = EJ_GetInstanceByIndex(idx, isRaid)
                    if not instanceID then break end
                    local ok, err = pcall(indexInstance, instanceID, isRaid, report)   -- pcall OHNE yield darin
                    if not ok and report then
                        report[#report + 1] = string.format("  ! Instanz %d: FEHLER %s", instanceID, tostring(err))
                    end
                    idx = idx + 1
                    coroutine.yield()                          -- Pause AUSSERHALB jedes pcall
                end
            end
        end
    end
    filterMode = "spec"
    applyLootFilter()   -- Journal-UI wieder auf den Spieler-Filter
    if curTier and EJ_SelectTier then pcall(EJ_SelectTier, curTier) end  -- UI-Zustand wiederherstellen
end

-- Diagnose/Reparatur: Index synchron KOMPLETT neu aufbauen (Cache wird ersetzt) und den
-- Verlauf in report protokollieren. Blockiert kurz (Sekunden) -> nur per Slash-Befehl.
function MetaMirror:RescanSourcesSync(report)
    if ticker then ticker:Cancel(); ticker = nil end
    co = nil
    index = {}
    state = "running"
    local c = coroutine.create(function() buildCoroutine(report) end)
    while true do
        local ok, err = coroutine.resume(c)
        if not ok then
            if report then report[#report + 1] = "! Scan abgebrochen: " .. tostring(err) end
            break
        end
        if coroutine.status(c) == "dead" then break end
    end
    state = "done"
    saveCache()
    local n = 0
    for _ in pairs(index) do n = n + 1 end
    if MetaMirror.Refresh and MetaMirrorPanel and MetaMirrorPanel.IsShown
        and MetaMirrorPanel:IsShown() then
        MetaMirror:Refresh()
    end
    return n
end

local function finishBuild()
    state = "done"
    co = nil
    if ticker then ticker:Cancel(); ticker = nil end
    saveCache()   -- Ergebnis fuer folgende Logins persistieren (spart den Scan)
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
    local budget = (debugprofilestop and (debugprofilestop() + 4)) or nil
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
    -- Gueltiger Cache aus einer frueheren Sitzung? -> sofort uebernehmen: kein Scan, kein
    -- synchroner Blizzard_EncounterJournal-Load -> KEIN Login-Ruckeln. Der teure Scan
    -- laeuft nur einmal pro Client-Patch, danach kommt der Index immer aus dem Cache.
    local cached = loadCache()
    if cached then
        index = cached
        state = "done"
        return
    end
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

