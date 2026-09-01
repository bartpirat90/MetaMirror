MetaMirror = MetaMirror or {}
local C, L = MetaMirror.C, MetaMirror.L

local TABS = { "stats", "talents", "gear", "gems", "ench", "cons" }
local TAB_LABEL = {
    stats = "tab_stats", talents = "tab_talents", gear = "tab_gear",
    gems = "tab_gems", ench = "ench_short", cons = "tab_cons",
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

    -- Tab-Leiste (6 Tabs -> schmaler, damit sie in 360px passen)
    local x = 8
    for _, key in ipairs(TABS) do
        local b = CreateFrame("Button", nil, Panel)
        b:SetSize(54, 22); b:SetPoint("TOPLEFT", x, -36)
        local t = tex(b, "BACKGROUND", C.HEAD); t:SetAllPoints(); b.bg = t
        local fstr = fs(b, "GameFontHighlightSmall", C.DIM)
        fstr:SetPoint("CENTER"); fstr:SetText(L[TAB_LABEL[key]]); b.fstr = fstr
        b:SetScript("OnClick", function()
            MetaMirrorDB.tab = key
            MetaMirror:Refresh()
        end)
        Tabs[key] = b
        x = x + 56
    end

    -- Inhaltsbereich
    Body = CreateFrame("Frame", nil, Panel)
    Body:SetPoint("TOPLEFT", 10, -62)
    Body:SetPoint("BOTTOMRIGHT", -10, 10)

    -- Andockung an den Charakter-Rahmen
    MetaMirror:AnchorToCharacter()
    CharacterFrame:HookScript("OnShow", function() MetaMirror:OnCharShow() end)
    CharacterFrame:HookScript("OnHide", function() Panel:Hide() end)

    -- Quellen-Attribution (RPGLogs-API-ToS verlangt Nennung)
    local attrText = (MetaMirrorData and MetaMirrorData.attribution) or "Data from Warcraft Logs"
    local footer = fs(Panel, "GameFontDisableSmall", C.DIM)
    footer:SetPoint("BOTTOMRIGHT", -8, 6)
    footer:SetText(attrText)

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

-- Zeilen-Pool fuer den Stats-Tab (Wiederverwendung statt Neuerzeugung bei jedem Refresh).
local rows = {}
local function getRow(i)
    if rows[i] then return rows[i] end
    local r = CreateFrame("Frame", nil, Body)
    r:SetSize(336, 40)
    -- Class-Codex-Layout: Name links; rechts Prozent + "aktuell / Ziel" + Status-Pfeil.
    r.name  = fs(r, "GameFontNormalSmall", C.TXT);   r.name:SetPoint("TOPLEFT", 0, 0)
    r.arrow = r:CreateTexture(nil, "OVERLAY");        r.arrow:SetSize(12, 12)
    r.arrow:SetPoint("TOPRIGHT", 0, -1)
    r.nums  = fs(r, "GameFontHighlightSmall", C.TXT); r.nums:SetPoint("RIGHT", r.arrow, "LEFT", -6, 0)
    r.track = tex(r, "BORDER", C.PANEL2); r.track:SetPoint("TOPLEFT", 0, -20); r.track:SetSize(336, 13)
    r.fill  = r:CreateTexture(nil, "ARTWORK"); r.fill:SetPoint("TOPLEFT", 0, -20); r.fill:SetHeight(13)
    r.mark  = r:CreateTexture(nil, "OVERLAY"); r.mark:SetColorTexture(unpack(C.GOLD)); r.mark:SetSize(2, 17)
    rows[i] = r
    return r
end

local STATUS_COL = { under = "CORAL", over = "BLUE", on = "GREEN", unknown = "DIM" }

-- Blizzard-Texturen fuer den Status (der WoW-Font hat keine Pfeil-/Haken-Glyphen).
-- Pfeile sind graustufig -> per SetVertexColor einfaerbbar; der Haken ist nativ gruen.
local ARROW_TEX = {
    under = "Interface\\Buttons\\Arrow-Down-Up",   -- zeigt nach unten = unter Ziel
    over  = "Interface\\Buttons\\Arrow-Up-Up",     -- zeigt nach oben  = ueber Ziel
    on    = "Interface\\RaidFrame\\ReadyCheck-Ready",
}

-- Farbcode fuer den gedaempften "/ Ziel"-Teil der Zahlenzeile (entspricht C.DIM).
local DIM_CODE = "|cff9a92c0"

local function renderStats(self, data)
    local i = 0
    for _, entry in ipairs(data.stats) do
        i = i + 1
        local r = getRow(i)
        r:ClearAllPoints(); r:SetPoint("TOPLEFT", 0, -(i-1) * 44)
        local cur = self:SecondaryFor(entry.key)
        local target = entry.rating or 0
        local tol = math.max(1, target * 0.05)          -- 5%-Toleranzband (Rating)
        local status = self:StatStatus(cur.rating, target, tol)
        local col = C[STATUS_COL[status]] or C.DIM

        r.name:SetText(L["stat_" .. entry.key])

        if status == "unknown" then
            -- Kampf/Instanz: eigenes Rating ist geschuetzt (secret) -> nur das Ziel zeigen.
            r.arrow:Hide()
            r.nums:SetText(string.format("%s%s / %d|r", DIM_CODE, L.secret_chip, target))
            r.nums:SetTextColor(unpack(C.DIM))
            local scale = target * 1.4
            if scale <= 0 then scale = 1 end
            r.fill:SetColorTexture(col[1], col[2], col[3], 1)
            r.fill:SetWidth(1)
            r.mark:ClearAllPoints()
            r.mark:SetPoint("TOP", r.track, "TOPLEFT", 336 * (target / scale), 2)
        else
            local cr = cur.rating
            -- Status als farbiger Textur-Pfeil rechts (runter=unter, hoch=ueber, Haken=im Ziel).
            if status == "under" then
                r.arrow:SetTexture(ARROW_TEX.under); r.arrow:SetVertexColor(unpack(C.CORAL))
            elseif status == "over" then
                r.arrow:SetTexture(ARROW_TEX.over); r.arrow:SetVertexColor(unpack(C.BLUE))
            else
                r.arrow:SetTexture(ARROW_TEX.on); r.arrow:SetVertexColor(1, 1, 1)
            end
            r.arrow:Show()

            -- Zahlen rechts: eigener Live-Prozent (falls lesbar) + "aktuell / Ziel".
            -- "/ Ziel" gedaempft; pct kann fehlen (secret) -> dann weglassen.
            r.nums:SetTextColor(unpack(C.TXT))
            local pctStr = cur.pct and string.format("%.1f%%  ", cur.pct) or ""
            r.nums:SetText(string.format("%s%d %s/ %d|r", pctStr, cr, DIM_CODE, target))

            -- Balken: Fuellung = eigenes Rating relativ zur Skala (max*1.2), Marke = Ziel.
            local scale = math.max(cr, target) * 1.2
            if scale <= 0 then scale = 1 end
            r.fill:SetColorTexture(col[1], col[2], col[3], 1)
            r.fill:SetWidth(math.max(1, 336 * (cr / scale)))
            r.mark:ClearAllPoints()
            r.mark:SetPoint("TOP", r.track, "TOPLEFT", 336 * (target / scale), 2)
        end
        r:Show()
    end
    for j = i + 1, #rows do rows[j]:Hide() end
end

-- Talente: Import-String in selektierbarer EditBox + Nutzungsquote.
local TalentBox
local function renderTalents(data)
    for j = 1, #rows do rows[j]:Hide() end
    if Body.msg then Body.msg:Hide() end
    if not TalentBox then
        TalentBox = CreateFrame("EditBox", nil, Body, "InputBoxTemplate")
        TalentBox:SetAutoFocus(false); TalentBox:SetSize(320, 24)
        TalentBox:SetPoint("TOPLEFT", 4, -30)
        TalentBox:SetScript("OnEscapePressed", function(s) s:ClearFocus() end)
        TalentBox.hint = fs(Body, "GameFontHighlightSmall", C.DIM)
        TalentBox.hint:SetPoint("TOPLEFT", 4, -4)
        TalentBox.usage = fs(Body, "GameFontHighlightSmall", C.SEC)
        TalentBox.usage:SetPoint("TOPLEFT", 4, -58)
    end
    local t = data.talents and data.talents[1]
    local imp = t and t.importString or ""
    TalentBox.usage:Show()
    TalentBox.usage:SetText(t and string.format(L.usage, t.usagePct) or "")
    if imp ~= "" then
        -- Kopierbarer Import-String (sobald die Datenquelle einen liefert).
        TalentBox:Show(); TalentBox.hint:Show()
        TalentBox.hint:SetText(L.copy_hint)
        TalentBox:SetText(imp)
        TalentBox:SetCursorPosition(0)
    else
        -- WCL liefert (noch) keinen Blizzard-Import-String -> ehrlich benennen.
        TalentBox:Hide()
        TalentBox.hint:Show()
        TalentBox.hint:SetText(L.talent_no_import)
    end
end
local function hideTalents()
    if TalentBox then TalentBox:Hide(); TalentBox.hint:Hide(); TalentBox.usage:Hide() end
end

-- Generische klickbare Item-Zeile (Shift-Klick -> Chat / AH-Suche).
-- Wiederverwendet fuer Verbrauchsgueter, Gear, Steine und Verzauberungen.
local itemRows = {}
local function getItemRow(i)
    if itemRows[i] then return itemRows[i] end
    local b = CreateFrame("Button", nil, Body)
    b:SetSize(320, 20)
    b:RegisterForClicks("AnyUp")
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(18, 18); b.icon:SetPoint("TOPLEFT", 0, 0)
    b.label = fs(b, "GameFontHighlightSmall", C.TXT); b.label:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self, button)
        if not self.link then return end
        -- Blizzard-Standard: Shift -> Chat/AH-Suche; sonst Item-Link-Popup
        if not HandleModifiedItemClick(self.link) then
            SetItemRef(self.link, self.link, button, self)
        end
    end)
    itemRows[i] = b
    return b
end

-- label: linke Beschriftung; itemID: klickbares Item (0/nil = nicht klickbar);
-- fallback: Text, wenn kein Item aufloesbar ist; enchantID: optional in den
-- Item-Link injiziert; bonusIDs: Upgrade-/Sockel-Bonusliste -> voller Link mit
-- korrekter Maximalstufe und Sockelplaetzen (sonst rendert der Client die Grundform).
local function setItemRow(b, label, itemID, fallback, enchantID, bonusIDs)
    if itemID and itemID ~= 0 then
        b.link = nil
        b.icon:SetTexture(134400)   -- Fragezeichen-Platzhalter bis geladen
        b.label:SetText(label .. ": ...")
        local item = Item:CreateFromItemID(itemID)
        item:ContinueOnItemLoad(function()
            local name = item:GetItemName() or ("item:" .. itemID)
            local link
            if bonusIDs and #bonusIDs > 0 then
                -- Vollen Item-Link selbst bauen: item:id:enchant:0*10:numBonus:bonus...
                local _, _, _, hex = GetItemQualityColor(item:GetItemQuality() or 1)
                local core = string.format("item:%d:%d:0:0:0:0:0:0:0:0:0:0:%d:%s",
                    itemID, enchantID or 0, #bonusIDs, table.concat(bonusIDs, ":"))
                link = "|c" .. (hex or "ffffffff") .. "|H" .. core .. "|h[" .. name .. "]|h|r"
            else
                link = item:GetItemLink()
                if enchantID and enchantID ~= 0 and link then
                    -- Enchant-Feld (2. Wert nach der ItemID) im Link setzen.
                    link = link:gsub("(Hitem:%d+):%-?%d*:", "%1:" .. enchantID .. ":", 1)
                end
            end
            b.link = link
            b.icon:SetTexture(item:GetItemIcon())
            b.label:SetText(label .. ": " .. name)
        end)
    else
        b.link = nil
        b.icon:SetTexture(nil)
        b.label:SetText(label .. ": " .. (fallback or "-"))
    end
    b:Show()
end

local function hideItemRows()
    for j = 1, #itemRows do itemRows[j]:Hide() end
end

-- entries: Liste aus { label, itemID, fallback, enchantID, bonusIDs }.
local function renderItemList(entries)
    for j = 1, #rows do rows[j]:Hide() end
    if Body.msg then Body.msg:Hide() end
    local i = 0
    for _, e in ipairs(entries) do
        i = i + 1
        local b = getItemRow(i)
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -(i - 1) * 20)
        setItemRow(b, e.label, e.itemID, e.fallback, e.enchantID, e.bonusIDs)
    end
    for j = i + 1, #itemRows do itemRows[j]:Hide() end
end

-- Slot-Reihenfolge + Anzeigenamen (fuer Gear/Steine/Verzauberungen).
local SLOT_ORDER = {
    "HEAD","NECK","SHOULDER","BACK","CHEST","WRIST","HANDS","WAIST",
    "LEGS","FEET","RING1","RING2","TRINKET1","TRINKET2","MAINHAND","OFFHAND",
}
local SLOT_LABELS = {
    HEAD="Head", NECK="Neck", SHOULDER="Shoulder", BACK="Back", CHEST="Chest",
    WRIST="Wrist", HANDS="Hands", WAIST="Waist", LEGS="Legs", FEET="Feet",
    RING1="Ring 1", RING2="Ring 2", TRINKET1="Trinket 1", TRINKET2="Trinket 2",
    MAINHAND="Main Hand", OFFHAND="Off Hand",
}
if GetLocale() == "deDE" then
    SLOT_LABELS = {
        HEAD="Kopf", NECK="Hals", SHOULDER="Schulter", BACK="Ruecken", CHEST="Brust",
        WRIST="Handgelenke", HANDS="Haende", WAIST="Guertel", LEGS="Beine", FEET="Fuesse",
        RING1="Ring 1", RING2="Ring 2", TRINKET1="Schmuck 1", TRINKET2="Schmuck 2",
        MAINHAND="Waffe", OFFHAND="Nebenhand",
    }
end
local SLOT_RANK = {}
for idx, s in ipairs(SLOT_ORDER) do SLOT_RANK[s] = idx end
local function slotLabel(slot) return SLOT_LABELS[slot] or slot end
local function bySlot(a, b) return (SLOT_RANK[a.slot] or 99) < (SLOT_RANK[b.slot] or 99) end

local CONS_ORDER = {
    { key = "flask",  label = "Flask"  },
    { key = "phial",  label = "Phiole" },
    { key = "potion", label = "Pott"   },
    { key = "food",   label = "Food"   },
    { key = "oil",    label = "Oel"    },
    { key = "rune",   label = "Rune"   },
}

function MetaMirror.RenderBody(self, classID, specID)
    if not Body.msg then
        Body.msg = fs(Body, "GameFontHighlight", C.DIM)
        Body.msg:SetPoint("TOPLEFT")
    end
    local data = self:DataFor(classID, specID, MetaMirrorDB.content)
    if not data then
        for j = 1, #rows do rows[j]:Hide() end
        hideTalents()
        hideItemRows()
        Body.msg:Show(); Body.msg:SetText(L.no_data)
        return
    end
    Body.msg:Hide()
    hideTalents()
    hideItemRows()
    if MetaMirrorDB.tab == "stats" then
        renderStats(self, data)
    elseif MetaMirrorDB.tab == "talents" then
        renderTalents(data)
    elseif MetaMirrorDB.tab == "gear" then
        -- Gear steht fuer sich: nur das Item, aber mit Maximalstufe + Sockeln (bonusIDs).
        local gear = {}
        for _, g in ipairs(data.gear or {}) do gear[#gear+1] = g end
        table.sort(gear, bySlot)
        local entries = {}
        for _, g in ipairs(gear) do
            entries[#entries+1] = { label = slotLabel(g.slot), itemID = g.itemID,
                                    bonusIDs = g.bonusIDs }
        end
        if #entries > 0 then renderItemList(entries)
        else Body.msg:Show(); Body.msg:SetText(L.no_data) end
    elseif MetaMirrorDB.tab == "gems" then
        local gems = {}
        for _, g in ipairs(data.gems or {}) do gems[#gems+1] = g end
        table.sort(gems, bySlot)
        local entries = {}
        for _, g in ipairs(gems) do
            entries[#entries+1] = { label = slotLabel(g.slot), itemID = g.itemID }
        end
        if #entries > 0 then renderItemList(entries)
        else Body.msg:Show(); Body.msg:SetText(L.no_data) end
    elseif MetaMirrorDB.tab == "ench" then
        -- Verzauberung als echtes, AH-suchbares Item (Shift-Klick). itemID = 0 -> kein Link.
        local list = {}
        for _, e in ipairs(data.enchants or {}) do list[#list+1] = e end
        table.sort(list, bySlot)
        local entries = {}
        for _, e in ipairs(list) do
            local iid = (e.itemID ~= 0) and e.itemID or nil
            entries[#entries+1] = { label = slotLabel(e.slot), itemID = iid, fallback = L.ench_missing }
        end
        if #entries > 0 then renderItemList(entries)
        else Body.msg:Show(); Body.msg:SetText(L.no_data) end
    else -- cons
        local c = data.consumables or {}
        local entries = {}
        for _, cat in ipairs(CONS_ORDER) do
            if c[cat.key] ~= nil then
                entries[#entries+1] = { label = cat.label, itemID = c[cat.key] }
            end
        end
        renderItemList(entries)
    end
end
