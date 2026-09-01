MetaMirror = MetaMirror or {}
local ADDON = "MetaMirror"

-- Crystal-Violet-Palette (wie KeyRoulette/AutoRole)
MetaMirror.C = {
    BG_MAIN   = {0.086, 0.078, 0.122, 0.97},
    HEAD      = {0.082, 0.075, 0.153, 1.0},
    PANEL2    = {0.137, 0.125, 0.259, 1.0},
    BORDER    = {0.227, 0.184, 0.420, 1.0},
    VIOLET    = {0.659, 0.333, 0.969, 1.0},
    VIOLET_S  = {0.769, 0.710, 0.992, 1.0},
    SEC       = {0.655, 0.545, 0.980, 1.0},
    TXT       = {0.929, 0.914, 0.996, 1.0},
    DIM       = {0.604, 0.573, 0.753, 1.0},
    GOLD      = {1.0,   0.820, 0.0,   1.0},
    GREEN     = {0.290, 0.871, 0.502, 1.0},
    AMBER     = {0.984, 0.749, 0.141, 1.0},
    CORAL     = {0.874, 0.353, 0.247, 1.0},   -- "unter Ziel" (Class-Codex-Rot)
    BLUE      = {0.376, 0.647, 0.980, 1.0},
    ITEM      = {0.639, 0.816, 1.0,   1.0},
}

function MetaMirror.InitDB()
    MetaMirrorDB = MetaMirrorDB or {}
    local db = MetaMirrorDB
    if db.content == nil then db.content = "mythicplus" end  -- "mythicplus" | "raid"
    if db.tab     == nil then db.tab = "stats" end
    if db.tol     == nil then db.tol = 1.5 end               -- Toleranzband in %-Punkten
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
    elseif msg == "dumpsrc" then
        if MetaMirror.DumpSource then MetaMirror:DumpSource() end
    elseif msg == "dumptalents" then
        if MetaMirror.DumpTalents then MetaMirror:DumpTalents() end
    elseif msg == "testtalent" then
        if MetaMirror.TestTalentString then MetaMirror:TestTalentString() end
    elseif msg == "difftalent" then
        if MetaMirror.DiffTalentString then MetaMirror:DiffTalentString() end
    elseif msg == "testmetatalent" then
        if MetaMirror.TestMetaTalentString then MetaMirror:TestMetaTalentString() end
    elseif msg == "reset" then
        MetaMirrorDB.pos = nil
        print("|cffa855f7[MM]|r Position zurueckgesetzt.")
        if MetaMirror.AnchorToCharacter and MetaMirrorPanel then MetaMirror:AnchorToCharacter() end
    else
        if MetaMirror.Toggle then MetaMirror:Toggle() end
    end
end
