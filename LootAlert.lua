-- Referenz-/S-Tier-Drop-Alarm: horcht auf ENCOUNTER_LOOT_RECEIVED (Boss-Loot in Gruppe),
-- gleicht die itemID gegen die Meta-Empfehlung der EIGENEN Spec ab und meldet Treffer:
--   * bekommt man es selbst -> Glueckwunsch-Banner
--   * bekommt es ein anderer (nur in Gruppe) -> Popup mit Knopf, der den Gewinner
--     freundlich anwhispert ("May I have <Link> please? :)"). NUR auf Klick, nie automatisch.
-- Aktiv nur in M+ und Raid (Instanztyp party/raid). Event-Signatur (warcraft.wiki.gg):
--   ENCOUNTER_LOOT_RECEIVED: encounterID, itemID, itemLink, quantity, playerName, classFileName
MetaMirror = MetaMirror or {}

-- ===== Meta-Ziel-Set der aktuellen Spec (itemID -> "ref" | "S") =====
-- Gear-Content + Trinket-Sicht aus dem Instanztyp: Raid -> raid, sonst Dungeon/M+.
local function targetSet()
    local classID, specID = MetaMirror:CurrentSpecKey()
    if not specID then return nil end
    local _, itype = IsInInstance()
    local set = {}

    -- Referenz-Gear (das empfohlene Item je Slot) fuer den passenden Inhalt.
    local gearContent = (itype == "raid") and "raid" or "mythicplus"
    local data = MetaMirror:DataFor(classID, specID, gearContent)
    if data and data.gear then
        for _, g in ipairs(data.gear) do
            if g.itemID then set[g.itemID] = "ref" end
        end
    end

    -- S-Tier-Schmuck (Bloodmallet) der passenden Sicht; bei singleSource nur "overall".
    local troot = _G.MetaMirrorTrinkets
    local tspec = troot and troot.specs and troot.specs[specID]
    if tspec then
        local view = (itype == "raid") and "raid" or "dungeon"
        if tspec.singleSource or not tspec[view] then view = "overall" end
        for _, e in ipairs(tspec[view] or {}) do
            if e.itemID and e.tier == "S" and not set[e.itemID] then set[e.itemID] = "S" end
        end
    end
    return set
end

-- Ist playerName (evtl. "Name-Realm") der Spieler selbst? Event laesst den Realm bei
-- gleichem Realm weg; bei fremdem Realm haengt es ihn an -> dann Realm mitvergleichen.
local function isSelf(playerName)
    if not playerName or playerName == "" then return false end
    local pName, pRealm = strsplit("-", playerName)
    if pName ~= UnitName("player") then return false end
    if not pRealm or pRealm == "" then return true end   -- ohne Realm = eigener Realm
    local myRealm = GetNormalizedRealmName and GetNormalizedRealmName()
    return not myRealm or (pRealm:gsub("%s+", "") == myRealm)
end

-- ===== UI: Glueckwunsch-Banner (eigener Drop) + Bitte-Popup (fremder Drop) =====
local C = MetaMirror.C
local alertFrame

local function ensureFrame()
    if alertFrame then return alertFrame end
    local L = MetaMirror.L
    local f = CreateFrame("Frame", "MetaMirrorLootAlert", UIParent, "BackdropTemplate")
    f:SetSize(340, 96); f:SetPoint("TOP", 0, -160)
    f:SetFrameStrata("DIALOG"); f:SetToplevel(true)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8x8",
                    edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    f:SetBackdropColor(0.086, 0.078, 0.122, 0.98)
    f:EnableMouse(true); f:SetMovable(true); f:RegisterForDrag("LeftButton")
    f:SetScript("OnDragStart", f.StartMoving); f:SetScript("OnDragStop", f.StopMoving)

    f.edge = f:CreateTexture(nil, "BORDER")     -- farbiger Akzentstreifen links
    f.edge:SetPoint("TOPLEFT"); f.edge:SetPoint("BOTTOMLEFT"); f.edge:SetWidth(4)

    f.title = f:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    f.title:SetPoint("TOPLEFT", 14, -12); f.title:SetPoint("TOPRIGHT", -30, -12)
    f.title:SetJustifyH("LEFT")

    f.item = f:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    f.item:SetPoint("TOPLEFT", 14, -38); f.item:SetPoint("TOPRIGHT", -14, -38)
    f.item:SetJustifyH("LEFT")

    local close = CreateFrame("Button", nil, f, "UIPanelCloseButton")
    close:SetPoint("TOPRIGHT", 2, 2)
    close:SetScript("OnClick", function() f:Hide() end)

    -- Aufgepeppter Bitte-Knopf: violett gefuellt, Sprechblasen-Icon links + wandernder
    -- Licht-Streifen (Sheen) als Blickfang. Eigene Optik statt UIPanelButtonTemplate, damit
    -- Icon/Fuellung/Sheen/Zustaende frei steuerbar sind. Whisper NUR auf Klick.
    local ask = CreateFrame("Button", nil, f)
    ask:SetSize(168, 28); ask:SetPoint("BOTTOMRIGHT", -12, 10)
    ask:RegisterForClicks("AnyUp")

    ask.bg = ask:CreateTexture(nil, "BACKGROUND")
    ask.bg:SetAllPoints(); ask.bg:SetColorTexture(unpack(C.VIOLET))

    ask.border = CreateFrame("Frame", nil, ask, "BackdropTemplate")
    ask.border:SetAllPoints()
    ask.border:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    ask.border:SetBackdropBorderColor(unpack(C.VIOLET_S))

    ask.icon = ask:CreateTexture(nil, "ARTWORK")
    ask.icon:SetSize(15, 15); ask.icon:SetPoint("LEFT", 9, 0)
    ask.icon:SetTexture("Interface\\GossipFrame\\ChatBubbleGossipIcon")

    ask.txt = ask:CreateFontString(nil, "OVERLAY", "GameFontNormal")

    -- Sheen: schmale additive Textur, wandert im Knopf von links nach rechts (bleibt
    -- innerhalb der Raender -> kein Clipping noetig). Hoehe fest ~ Knopfhoehe.
    ask.sheen = ask:CreateTexture(nil, "OVERLAY")
    ask.sheen:SetColorTexture(1, 1, 1, 0.5)
    ask.sheen:SetBlendMode("ADD")
    ask.sheen:SetSize(16, 26)
    ask.sheen:Hide()

    -- Zustand umschalten: bereit (violett + Icon + Sheen) <-> angefragt (grau, aus).
    function ask:SetAsked(asked)
        self.asked = asked
        if asked then
            self.bg:SetColorTexture(0.22, 0.20, 0.28, 1)
            self.border:SetBackdropBorderColor(0.40, 0.38, 0.50, 1)
            self.txt:SetTextColor(unpack(C.DIM))
            self.txt:SetText(L.loot_asked or "Requested")
            self.txt:ClearAllPoints(); self.txt:SetPoint("CENTER")
            self.icon:Hide(); self.sheen:Hide()
        else
            self.bg:SetColorTexture(unpack(C.VIOLET))
            self.border:SetBackdropBorderColor(unpack(C.VIOLET_S))
            self.txt:SetTextColor(unpack(C.TXT))
            self.txt:SetText(L.loot_ask or "Ask for it")
            self.txt:ClearAllPoints(); self.txt:SetPoint("LEFT", self.icon, "RIGHT", 5, 0)
            self.icon:Show()
        end
    end

    ask:SetScript("OnEnter", function(self)
        if self.asked then return end
        self.bg:SetColorTexture(0.74, 0.45, 1.0, 1)   -- heller violett beim Hover
    end)
    ask:SetScript("OnLeave", function(self)
        if self.asked then return end
        self.bg:SetColorTexture(unpack(C.VIOLET))
    end)

    ask:SetScript("OnClick", function(self)
        if self.asked then return end
        if self.target and self.link then
            -- Text bewusst immer Englisch (internationale Gruppen).
            SendChatMessage("May I have " .. self.link .. " please? :)", "WHISPER", nil, self.target)
            self:SetAsked(true)
        end
    end)

    -- Sheen-Animation: kurzer Durchlauf, dann Pause, wiederholt.
    local SHEEN_W, SWEEP_T, PAUSE_T = 16, 0.7, 1.7
    ask.phase, ask.t = "pause", 0
    ask:SetScript("OnUpdate", function(self, elapsed)
        if self.asked or not self:IsShown() then return end
        self.t = self.t + elapsed
        if self.phase == "sweep" then
            local p = self.t / SWEEP_T
            if p >= 1 then
                self.phase, self.t = "pause", 0
                self.sheen:Hide()
            else
                self.sheen:Show()
                self.sheen:ClearAllPoints()
                self.sheen:SetPoint("LEFT", self, "LEFT", 1 + p * (self:GetWidth() - SHEEN_W - 2), 0)
            end
        elseif self.t >= PAUSE_T then
            self.phase, self.t = "sweep", 0
        end
    end)

    ask:SetAsked(false)
    f.ask = ask

    alertFrame = f
    return f
end

local hideTimer
local function autoHide(seconds)
    if hideTimer then hideTimer:Cancel() end
    hideTimer = C_Timer.NewTimer(seconds, function()
        if alertFrame then alertFrame:Hide() end
    end)
end

-- Eigener Drop -> Banner (kein Whisper-Knopf).
local function showBanner(itemLink, tier)
    local L = MetaMirror.L
    local f = ensureFrame()
    f.edge:SetColorTexture(unpack(C.GREEN))
    f.title:SetTextColor(unpack(C.GREEN))
    f.title:SetText(L.loot_grats or "Congratulations! A reference item dropped!")
    f.item:SetText((itemLink or "") .. "  |cff9a8fbf(" .. (tier or L.tier_ref or "reference") .. ")|r")
    f.ask:Hide()
    f:SetHeight(72)
    f:Show()
    if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.UI_EPICLOOT_TOAST) end
    autoHide(10)
end

-- Fremder Drop (in Gruppe) -> Popup mit Bitte-Knopf.
local function showRequest(itemLink, playerName, tier)
    local L = MetaMirror.L
    local f = ensureFrame()
    local who = (strsplit("-", playerName)) or playerName
    f.edge:SetColorTexture(unpack(C.VIOLET))
    f.title:SetTextColor(unpack(C.VIOLET_S))
    f.title:SetText(string.format(L.loot_drop_title or "%s dropped for %s",
                                  tier or L.tier_ref or "reference", who))
    f.item:SetText(itemLink or "")
    f.ask.target = playerName
    f.ask.link = itemLink
    f.ask:SetAsked(false); f.ask:Show()
    f:SetHeight(96)
    f:Show()
    if PlaySound and SOUNDKIT then pcall(PlaySound, SOUNDKIT.UI_EPICLOOT_TOAST) end
    autoHide(25)
end

-- Kern: einen Loot-Empfang bewerten und ggf. Banner/Popup zeigen.
function MetaMirror:HandleLoot(itemID, itemLink, playerName)
    if not (itemID and itemLink and playerName) then return end
    local inInst, itype = IsInInstance()
    if not (inInst and (itype == "party" or itype == "raid")) then return end
    local set = targetSet()
    local tier = set and set[itemID]
    if not tier then return end
    local L = MetaMirror.L
    local tierLabel = (tier == "S") and "S-Tier" or (L.tier_ref or "reference")
    if isSelf(playerName) then
        showBanner(itemLink, tierLabel)
    elseif IsInGroup() then
        showRequest(itemLink, playerName, tierLabel)
    end
end

local listener = CreateFrame("Frame")
listener:RegisterEvent("ENCOUNTER_LOOT_RECEIVED")
listener:SetScript("OnEvent", function(_, _, _, itemID, itemLink, _, playerName)
    MetaMirror:HandleLoot(itemID, itemLink, playerName)
end)

-- /mm testloot : simuliert einen Drop mit dem ersten Referenz-Item der eigenen Spec, damit
-- die UI ohne echten Boss-Kill pruefbar ist (Banner = selbst, Popup = fremd).
function MetaMirror:TestLootAlert()
    local classID, specID = self:CurrentSpecKey()
    local data = specID and self:DataFor(classID, specID, "mythicplus")
    local first = data and data.gear and data.gear[1]
    if not first then
        print("|cffdf5a3f[MM]|r Kein Gear in den Daten für diese Spec - Test nicht möglich.")
        return
    end
    local link = select(2, C_Item.GetItemInfo(first.itemID)) or ("item:" .. first.itemID)
    local L = MetaMirror.L
    print("|cffa855f7[MM]|r LootAlert-Test: erst Glückwunsch-Banner, dann Bitte-Popup.")
    showBanner(link, L.tier_ref or "reference")
    C_Timer.After(3, function()
        showRequest(link, "Testspieler-Testrealm", L.tier_ref or "reference")
    end)
end
