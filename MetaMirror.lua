MetaMirror = MetaMirror or {}
local ADDON = "MetaMirror"

-- Palette und Tiefen-Bausteine stehen in Style.lua -- derselben Datei in jedem
-- Addon dieser Reihe. Sie setzt MetaMirror.C und MetaMirror.Style und laedt
-- laut .toc direkt nach dieser Datei, also vor jedem Nutzer.

function MetaMirror.InitDB()
    MetaMirrorDB = MetaMirrorDB or {}
    local db = MetaMirrorDB
    if db.content == nil then db.content = "mythicplus" end  -- "mythicplus" | "raid"
    if db.tab     == nil then db.tab = "stats" end
    if db.tol     == nil then db.tol = 1.5 end               -- Toleranzband in %-Punkten
    -- Vom Nutzer per X geschlossen: das Panel bleibt dann auch beim Oeffnen des
    -- Charakterrahmens zu, bis es per /mm wieder geholt wird.
    if db.hidden  == nil then db.hidden = false end
    if db.tooltip == nil then db.tooltip = true end   -- Referenz-Zeilen im Item-Tooltip
    -- Nur eine frei gezogene Position (custom=true) ist gueltig; altes/kaputtes Format verwerfen.
    if db.pos and db.pos.custom ~= true then db.pos = nil end
end

local f = CreateFrame("Frame")
f:RegisterEvent("ADDON_LOADED")
f:RegisterEvent("PLAYER_LOGIN")
f:RegisterEvent("PLAYER_SPECIALIZATION_CHANGED")
f:SetScript("OnEvent", function(_, event, arg1)
    if event == "ADDON_LOADED" and arg1 == ADDON then
        MetaMirror.InitDB()
    elseif event == "PLAYER_LOGIN" then
        MetaMirror.InitDB()
        if MetaMirror.BuildPanel then MetaMirror:BuildPanel() end
        -- Item-Quellen-Index (Abenteuerfuehrer) im Hintergrund vorwaermen, damit der
        -- erste Gear-/Schmuck-Tab keinen Scan-Hang mehr ausloest. Verzoegert, damit der
        -- Login-Sturm vorbei ist; der Aufbau selbst ist asynchron (Zeitbudget je Frame).
        if MetaMirror.PrimeItemSources and C_Timer and C_Timer.After then
            C_Timer.After(3, function() MetaMirror:PrimeItemSources() end)
        end
    elseif event == "PLAYER_SPECIALIZATION_CHANGED" then
        if MetaMirror.Refresh then MetaMirror:Refresh() end
    end
end)

SLASH_METAMIRROR1 = "/mm"
SLASH_METAMIRROR2 = "/metamirror"
SlashCmdList["METAMIRROR"] = function(msg)
    msg = (msg or ""):lower():gsub("^%s+", ""):gsub("%s+$", "")
    if msg == "status" or msg == "debug" then
        if MetaMirror.Status then MetaMirror:Status() end
    elseif msg == "dumpench" or msg == "dump" then
        if MetaMirror.DumpEnchants then MetaMirror:DumpEnchants() end
    elseif msg == "dumpgems" then
        if MetaMirror.DumpGems then MetaMirror:DumpGems() end
    elseif msg == "dumpq" then
        if MetaMirror.DumpQuality then MetaMirror:DumpQuality() end
    elseif msg == "ilvl" then
        if MetaMirror.DumpItemLevels then MetaMirror:DumpItemLevels() end
    elseif msg == "dumpsrc" then
        if MetaMirror.DumpSource then MetaMirror:DumpSource() end
    elseif msg == "scansrc" then
        if MetaMirror.ScanSourceDiag then MetaMirror:ScanSourceDiag() end
    elseif msg == "testloot" then
        if MetaMirror.TestLootAlert then MetaMirror:TestLootAlert() end
    elseif msg == "tooltip" then
        MetaMirrorDB.tooltip = not MetaMirrorDB.tooltip
        print("|cffa855f7[MM]|r " .. (MetaMirrorDB.tooltip and MetaMirror.L.tt_on or MetaMirror.L.tt_off))
    elseif msg == "reset" then
        MetaMirrorDB.pos = nil
        print("|cffa855f7[MM]|r Position zurückgesetzt.")
        if MetaMirror.AnchorToCharacter and MetaMirrorPanel then MetaMirror:AnchorToCharacter() end
    else
        if MetaMirror.Toggle then MetaMirror:Toggle() end
    end
end
