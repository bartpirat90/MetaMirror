MetaMirror = MetaMirror or {}
local C, L = MetaMirror.C, MetaMirror.L

local TABS = { "stats", "talents", "gear", "gems", "cons" }
local TAB_LABEL = {
    stats = "tab_stats", talents = "tab_talents", gear = "tab_gear",
    gems = "tab_gems", cons = "tab_cons",
}

local Panel, Tabs, Body, Header, CtxBtns = nil, {}, nil, nil, {}

local function tex(parent, layer, col)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(col[1], col[2], col[3], col[4] or 1)
    return t
end
local function fs(parent, tmpl, col)
    local f = parent:CreateFontString(nil, "OVERLAY", tmpl or "GameFontNormal")
    if col then f:SetTextColor(unpack(col)) end
    return f
end

function MetaMirror:BuildPanel()
    if Panel then return end
    Panel = CreateFrame("Frame", "MetaMirrorPanel", UIParent, "BackdropTemplate")
    Panel:SetSize(360, 460)
    Panel:SetFrameStrata("HIGH")
    Panel:EnableMouse(true)
    Panel:SetMovable(true)
    Panel:SetClampedToScreen(true)   -- kann nie ganz aus dem Bild rutschen
    Panel:RegisterForDrag("LeftButton")
    Panel:SetScript("OnDragStart", Panel.StartMoving)
    Panel:SetScript("OnDragStop", function(self)
        self:StopMovingOrSizing()
        -- freie Position in UIParent-Koordinaten merken (skalensicher), dann sauber neu ankern
        local es, ues = self:GetEffectiveScale(), UIParent:GetEffectiveScale()
        local x = self:GetLeft() * es / ues
        local y = self:GetBottom() * es / ues
        self:ClearAllPoints()
        self:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", x, y)
        MetaMirrorDB.pos = { custom = true, x = x, y = y }
    end)
    local bg = tex(Panel, "BACKGROUND", C.BG_MAIN); bg:SetAllPoints()
    Panel:SetBackdrop({ edgeFile = "Interface\\Buttons\\WHITE8x8", edgeSize = 1 })
    Panel:SetBackdropBorderColor(unpack(C.VIOLET))

    -- Kopfzeile
    local head = tex(Panel, "BACKGROUND", C.HEAD)
    head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT"); head:SetHeight(34)
    Header = fs(Panel, "GameFontNormal", C.VIOLET_S)
    Header:SetPoint("TOPLEFT", 12, -10)
    Header:SetText(L.title)

    -- Kontext-Umschalter M+/Raid
    local function ctxButton(key, label, xoff)
        local b = CreateFrame("Button", nil, Panel)
        b:SetSize(46, 18); b:SetPoint("TOPRIGHT", xoff, -8)
        local t = tex(b, "BACKGROUND", C.PANEL2); t:SetAllPoints(); b.bg = t
        local fstr = fs(b, "GameFontHighlightSmall", C.DIM)
        fstr:SetPoint("CENTER"); fstr:SetText(label); b.fstr = fstr
        b:SetScript("OnClick", function()
            MetaMirrorDB.content = key
            MetaMirror:Refresh()
        end)
        CtxBtns[key] = b
        return b
    end
    ctxButton("raid",       L.ctx_raid,  -8)
    ctxButton("mythicplus", L.ctx_mplus, -58)

    -- Tab-Leiste
    local x = 10
    for _, key in ipairs(TABS) do
        local b = CreateFrame("Button", nil, Panel)
        b:SetSize(66, 22); b:SetPoint("TOPLEFT", x, -36)
        local t = tex(b, "BACKGROUND", C.HEAD); t:SetAllPoints(); b.bg = t
        local fstr = fs(b, "GameFontHighlightSmall", C.DIM)
        fstr:SetPoint("CENTER"); fstr:SetText(L[TAB_LABEL[key]]); b.fstr = fstr
        b:SetScript("OnClick", function()
            MetaMirrorDB.tab = key
            MetaMirror:Refresh()
        end)
        Tabs[key] = b
        x = x + 68
    end

    -- Inhaltsbereich
    Body = CreateFrame("Frame", nil, Panel)
    Body:SetPoint("TOPLEFT", 10, -62)
    Body:SetPoint("BOTTOMRIGHT", -10, 10)

    -- Andockung an den Charakter-Rahmen
    MetaMirror:AnchorToCharacter()
    CharacterFrame:HookScript("OnShow", function() MetaMirror:OnCharShow() end)
    CharacterFrame:HookScript("OnHide", function() Panel:Hide() end)

    Panel:Hide()
    MetaMirror:Refresh()
end

function MetaMirror:AnchorToCharacter()
    local p = MetaMirrorDB.pos
    Panel:ClearAllPoints()
    if p and p.custom then
        -- vom Nutzer frei platziert (UIParent-Koordinaten)
        Panel:SetPoint("BOTTOMLEFT", UIParent, "BOTTOMLEFT", p.x, p.y)
    elseif CharacterFrame and CharacterFrame:IsShown() then
        -- an das offene Charakterfenster andocken
        Panel:SetPoint("TOPLEFT", CharacterFrame, "TOPRIGHT", 4, 0)
    else
        -- eigenstaendig (z.B. via /mm) -> sicher mittig auf den Schirm
        Panel:SetPoint("CENTER", UIParent, "CENTER", 220, 0)
    end
end

local function safeRefresh()
    local ok, err = pcall(function() MetaMirror:Refresh() end)
    if not ok then print("|cffff5555[MM] Refresh-Fehler:|r " .. tostring(err)) end
end

function MetaMirror:OnCharShow()
    self:AnchorToCharacter()
    Panel:Show()          -- zuerst zeigen: ein Render-Fehler darf das Fenster nicht verschlucken
    safeRefresh()
end

function MetaMirror:Toggle()
    if not Panel then self:BuildPanel() end
    if Panel:IsShown() then
        Panel:Hide()
    else
        self:AnchorToCharacter()
        Panel:Show()
        safeRefresh()
    end
end

-- Diagnose: /mm status
function MetaMirror:Status()
    if not Panel then
        print("|cffa855f7[MM]|r Panel = nil  ->  BuildPanel lief nicht (UI.lua-Ladefehler?)")
        return
    end
    print(string.format("|cffa855f7[MM]|r shown=%s visible=%s alpha=%.2f scale=%.2f",
        tostring(Panel:IsShown()), tostring(Panel:IsVisible()), Panel:GetAlpha(), Panel:GetEffectiveScale()))
    local l, b = Panel:GetLeft(), Panel:GetBottom()
    print(string.format("|cffa855f7[MM]|r left=%s bottom=%s w=%s h=%s  (Bildschirm ~%dx%d)",
        tostring(l and math.floor(l)), tostring(b and math.floor(b)),
        math.floor(Panel:GetWidth()), math.floor(Panel:GetHeight()),
        math.floor(UIParent:GetWidth()), math.floor(UIParent:GetHeight())))
    print("|cffa855f7[MM]|r CharacterFrame=" .. tostring(CharacterFrame ~= nil)
        .. "  strata=" .. tostring(Panel:GetFrameStrata()))
end

-- Kopf/Tabs/Kontext spiegeln + aktiven Tab rendern.
function MetaMirror:Refresh()
    if not Panel then return end
    -- Kontext-Buttons
    for key, b in pairs(CtxBtns) do
        local on = (MetaMirrorDB.content == key)
        b.bg:SetColorTexture(unpack(on and C.VIOLET or C.PANEL2))
        b.fstr:SetTextColor(unpack(on and {1,1,1,1} or C.DIM))
    end
    -- Tab-Buttons
    for key, b in pairs(Tabs) do
        local on = (MetaMirrorDB.tab == key)
        b.bg:SetColorTexture(unpack(on and C.BG_MAIN or C.HEAD))
        b.fstr:SetTextColor(unpack(on and C.VIOLET_S or C.DIM))
    end
    -- Kopf: Spec-Name
    local classID, specID = self:CurrentSpecKey()
    local specName = specID and select(2, GetSpecializationInfoByID(specID)) or "?"
    Header:SetText(specName .. "  |cff9a92c0" .. L.autodetect .. "|r")
    -- Inhalt
    self:RenderBody(classID, specID)
end

-- Platzhalter bis Task 7/8; zeigt vorerst nur den aktiven Tabnamen oder "keine Daten".
function MetaMirror.RenderBody(self, classID, specID)
    if not Body.msg then
        Body.msg = fs(Body, "GameFontHighlight", C.DIM)
        Body.msg:SetPoint("TOPLEFT")
    end
    local data = self:DataFor(classID, specID, MetaMirrorDB.content)
    Body.msg:SetText(data and ("Tab: " .. MetaMirrorDB.tab) or L.no_data)
end
