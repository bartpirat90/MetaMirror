MetaMirror = MetaMirror or {}
local C, L = MetaMirror.C, MetaMirror.L

-- "improve" fasst Verzauberungen + Edelsteine + Verbrauchsmaterial auf einer
-- Seite mit einklappbaren Abschnitten zusammen (Class-Codex-"Verbesserungen").
local TABS = { "stats", "gear", "schmuck", "improve" }
local TAB_LABEL = {
    stats = "tab_stats", gear = "tab_gear",
    schmuck = "tab_schmuck", improve = "tab_improve",
}
local VALID_TABS = { stats = true, gear = true,
                     schmuck = true, improve = true }

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
    Panel:SetSize(440, 500)
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

    -- Kopfzeile (zweizeilig: Marken-Zeile oben, Spec-Zeile darunter)
    local head = tex(Panel, "BACKGROUND", C.HEAD)
    head:SetPoint("TOPLEFT"); head:SetPoint("TOPRIGHT"); head:SetHeight(52)
    -- Marken-Symbol + Schriftzug "MetaMirror" (Meta hell, Mirror violett)
    local brand = Panel:CreateTexture(nil, "ARTWORK")
    brand:SetTexture("Interface\\AddOns\\MetaMirror\\Icon")
    brand:SetSize(22, 22); brand:SetPoint("TOPLEFT", 10, -6)
    local title = fs(Panel, "GameFontNormalLarge")
    title:SetPoint("LEFT", brand, "RIGHT", 6, 0)
    title:SetText("|cffede9feMeta|r|cffa855f7Mirror|r")
    -- Spec-Zeile (wird in Refresh mit Spec-Name + "auto-detected" gefuellt)
    Header = fs(Panel, "GameFontNormalSmall", C.DIM)
    Header:SetPoint("TOPLEFT", 12, -33)

    -- Schliessen-Kreuz oben rechts. Eigener schlichter Button statt UIPanelCloseButton:
    -- dessen 32px-Grafik sprengt die 52px-Kopfzeile und stoesst an die Kontext-Schalter.
    local close = CreateFrame("Button", nil, Panel)
    close:SetSize(20, 20); close:SetPoint("TOPRIGHT", -6, -6)
    local closeX = fs(close, "GameFontNormalLarge", C.DIM)
    closeX:SetPoint("CENTER", 0, 1); closeX:SetText("\195\151")   -- Multiplikationszeichen als X
    close:SetScript("OnEnter", function(self)
        closeX:SetTextColor(unpack(C.VIOLET_S))
        GameTooltip:SetOwner(self, "ANCHOR_LEFT")
        GameTooltip:SetText(L.close_hint or "Close", unpack(C.TXT))
        GameTooltip:AddLine(L.close_note or "", C.DIM[1], C.DIM[2], C.DIM[3], true)
        GameTooltip:Show()
    end)
    close:SetScript("OnLeave", function()
        closeX:SetTextColor(unpack(C.DIM))
        GameTooltip:Hide()
    end)
    close:SetScript("OnClick", function()
        MetaMirrorDB.hidden = true    -- bleibt zu, bis /mm es wieder holt
        Panel:Hide()
    end)

    -- Kontext-Umschalter M+/Raid (rechts, aber links neben dem Schliessen-Kreuz)
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
    ctxButton("raid",       L.ctx_raid,  -30)   -- 22px nach links: Platz fuer das Kreuz
    ctxButton("mythicplus", L.ctx_mplus, -80)

    -- Tab-Leiste (4 Tabs -> fuellen die Breite gleichmaessig aus)
    local x = 8
    for _, key in ipairs(TABS) do
        local b = CreateFrame("Button", nil, Panel)
        b:SetSize(84, 22); b:SetPoint("TOPLEFT", x, -56)
        local t = tex(b, "BACKGROUND", C.HEAD); t:SetAllPoints(); b.bg = t
        local fstr = fs(b, "GameFontHighlightSmall", C.DIM)
        fstr:SetPoint("CENTER"); fstr:SetText(L[TAB_LABEL[key]]); b.fstr = fstr
        b:SetScript("OnClick", function()
            MetaMirrorDB.tab = key
            MetaMirror:Refresh()
        end)
        Tabs[key] = b
        x = x + 86
    end

    -- Inhaltsbereich. Unten 22px fuer die Quellen-Fusszeile reservieren, damit kein
    -- Zeileninhalt darueber clippen kann (eigener Platz fuer die Attribution).
    Body = CreateFrame("Frame", nil, Panel)
    Body:SetPoint("TOPLEFT", 10, -82)
    Body:SetPoint("BOTTOMRIGHT", -10, 22)

    -- Andockung an den Charakter-Rahmen
    MetaMirror:AnchorToCharacter()
    CharacterFrame:HookScript("OnShow", function() MetaMirror:OnCharShow() end)
    CharacterFrame:HookScript("OnHide", function() Panel:Hide() end)

    -- Quellen-Attribution. Eigener Fusszeilen-Streifen
    -- mit deckendem Hintergrund unten -> Body endet darueber, nichts clippt hinein.
    local footBar = tex(Panel, "BACKGROUND", C.BG_MAIN)
    footBar:SetPoint("BOTTOMLEFT", 1, 1); footBar:SetPoint("BOTTOMRIGHT", -1, 1)
    footBar:SetHeight(18)
    local attrText = (MetaMirrorData and MetaMirrorData.attribution)
        or (MetaMirrorTrinkets and MetaMirrorTrinkets.source)
        or "Data from bloodmallet.com"
    local footer = fs(Panel, "GameFontDisableSmall", C.DIM)
    footer:SetPoint("BOTTOMRIGHT", -8, 5)
    footer:SetText(attrText)
    -- Autoren-Credit unten links
    local credit = fs(Panel, "GameFontDisableSmall", C.DIM)
    credit:SetPoint("BOTTOMLEFT", 8, 5)
    credit:SetText("by bartpirat")

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
    if MetaMirrorDB and MetaMirrorDB.hidden then return end   -- per X weggeklickt
    self:AnchorToCharacter()
    Panel:Show()          -- zuerst zeigen: ein Render-Fehler darf das Fenster nicht verschlucken
    safeRefresh()
end

function MetaMirror:Toggle()
    if not Panel then self:BuildPanel() end
    if Panel:IsShown() then
        MetaMirrorDB.hidden = true
        Panel:Hide()
    else
        MetaMirrorDB.hidden = false   -- /mm holt das Fenster bewusst zurueck
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
    -- Alte/ungueltige Tab-Auswahl auf die neue Struktur abbilden.
    local t = MetaMirrorDB.tab
    if t == "gems" or t == "ench" or t == "cons" then
        MetaMirrorDB.tab = "improve"
    elseif not VALID_TABS[t] then
        MetaMirrorDB.tab = "stats"
    end
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
    r:SetSize(404, 40)
    -- Class-Codex-Layout: Name links; rechts Prozent + "aktuell / Ziel" + Status-Pfeil.
    r.name  = fs(r, "GameFontNormalSmall", C.TXT);   r.name:SetPoint("TOPLEFT", 0, 0)
    r.arrow = r:CreateTexture(nil, "OVERLAY");        r.arrow:SetSize(12, 12)
    r.arrow:SetPoint("TOPRIGHT", 0, -1)
    r.nums  = fs(r, "GameFontHighlightSmall", C.TXT); r.nums:SetPoint("RIGHT", r.arrow, "LEFT", -6, 0)
    r.track = tex(r, "BORDER", C.PANEL2); r.track:SetPoint("TOPLEFT", 0, -20); r.track:SetSize(404, 13)
    r.fill  = r:CreateTexture(nil, "ARTWORK"); r.fill:SetPoint("TOPLEFT", 0, -20); r.fill:SetHeight(13)
    -- Pillen-Maske: rundet Spur UND Fuellung ab (Fuellung kommt von links, linke Ecke rund,
    -- rechts an der Fuellkante geclippt). Eine Maske ueber der vollen Spur, von beiden genutzt.
    if r.CreateMaskTexture then
        r.barMask = r:CreateMaskTexture()
        r.barMask:SetTexture("Interface\\AddOns\\MetaMirror\\bar-mask",
            "CLAMPTOBLACKADDITIVE", "CLAMPTOBLACKADDITIVE")
        r.barMask:SetAllPoints(r.track)
        r.track:AddMaskTexture(r.barMask)
        r.fill:AddMaskTexture(r.barMask)
    end
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
            r.mark:SetPoint("TOP", r.track, "TOPLEFT", 404 * (target / scale), 2)
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
            r.fill:SetWidth(math.max(1, 404 * (cr / scale)))
            r.mark:ClearAllPoints()
            r.mark:SetPoint("TOP", r.track, "TOPLEFT", 404 * (target / scale), 2)
        end
        r:Show()
    end
    for j = i + 1, #rows do rows[j]:Hide() end

    -- Gedaempfter Sim-Referenz-Hinweis unten im Tab: Fight-Style + Erzeugungsdatum der
    -- Sim-Daten, analog zum trinket_note-Mechanismus im Schmuck-Tab. Nur sichtbar, wenn
    -- MetaMirrorData tatsaechlich ein Erzeugungsdatum mitbringt (neuer Vertrag).
    if not Body.statsNote then
        Body.statsNote = fs(Body, "GameFontDisableSmall", C.DIM)
        Body.statsNote:SetPoint("BOTTOMLEFT", 0, 0); Body.statsNote:SetJustifyH("LEFT")
    end
    local root = _G.MetaMirrorData
    if root and root.generated then
        local style = root.fightStyles and root.fightStyles[MetaMirrorDB.content]
        local styleLabel = (style == "castingpatchwerk" and L.fight_raid)
            or (style == "castingpatchwerk3" and L.fight_mplus)
            or style or ""
        Body.statsNote:SetText(string.format(L.sim_note, styleLabel, root.generated))
        Body.statsNote:Show()
    else
        Body.statsNote:Hide()
    end
end

-- Blendet den Stats-Tab-Hinweis (siehe renderStats) ueberall dort aus, wo auch die
-- Stats-Zeilen (rows) verschwinden -- sonst bliebe er beim Tab-Wechsel sichtbar stehen.
local function hideStatsNote()
    if Body.statsNote then Body.statsNote:Hide() end
end


-- Generische klickbare Item-Zeile (Shift-Klick -> Chat / AH-Suche).
-- Wiederverwendet fuer Verbrauchsgueter, Gear, Steine und Verzauberungen.
local itemRows = {}
local function getItemRow(i)
    if itemRows[i] then return itemRows[i] end
    local b = CreateFrame("Button", nil, Body)
    b:SetSize(404, 26)
    b:RegisterForClicks("AnyUp")
    -- Besitz-Highlight: gruener Schimmer/Fuellung ueber die ganze Zeile (Class-Codex-Optik).
    b.hl = b:CreateTexture(nil, "BACKGROUND")
    b.hl:SetPoint("TOPLEFT", 0, 0); b.hl:SetPoint("BOTTOMRIGHT", 0, 0)
    b.hl:SetColorTexture(0.20, 0.85, 0.35, 0.16)
    b.hl:Hide()
    b.hlEdge = b:CreateTexture(nil, "BORDER")   -- hellerer gruener Akzent links
    b.hlEdge:SetPoint("TOPLEFT", 0, 0); b.hlEdge:SetPoint("BOTTOMLEFT", 0, 0)
    b.hlEdge:SetWidth(2); b.hlEdge:SetColorTexture(0.35, 1.0, 0.45, 0.85)
    b.hlEdge:Hide()
    -- Slotname als feste linke Spalte (Class Codex: Slot | Icon | Name | Quelle).
    b.slot = fs(b, "GameFontHighlightSmall", C.DIM)
    b.slot:SetPoint("LEFT", 6, 0); b.slot:SetWidth(74); b.slot:SetJustifyH("LEFT")
    b.slot:SetWordWrap(false)
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(24, 24)
    b.icon:SetPoint("LEFT", b.slot, "RIGHT", 4, 0)
    -- Quelle rechts (Abenteuerfuehrer-Deeplink); eigener Button -> eigener Klick.
    b.src = CreateFrame("Button", nil, b)
    b.src:SetSize(150, 24); b.src:SetPoint("RIGHT", -2, 0)
    b.src.text = fs(b.src, "GameFontDisableSmall", C.DIM)
    b.src.text:SetPoint("RIGHT"); b.src.text:SetJustifyH("RIGHT")
    b.src.text:SetWordWrap(false)
    b.src:SetScript("OnClick", function(self)
        if self.srcData then MetaMirror:OpenSource(self.srcData) end
    end)
    b.src:SetScript("OnEnter", function(self)
        if not self.srcData then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.srcData.text or "")
        GameTooltip:AddLine(L.src_hint, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b.src:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b.label = fs(b, "GameFontHighlight", C.TXT); b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
    b.label:SetWordWrap(false); b.label:SetJustifyH("LEFT")
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

-- Entfernt das Handwerksqualitaets-Icon (Tier 1/2/3) aus dem Anzeige-Text.
-- Die Tier-Stufe steckt fest in der itemID; ein niedriger Tier wuerde sonst als
-- silberner Stern erscheinen. Der Link selbst (b.link) bleibt unangetastet, damit
-- die AH-Suche/das Tooltip weiter funktioniert -> nur die Anzeige wird bereinigt.
local function stripQualityIcon(s)
    if not s then return s end
    return (s:gsub("|A:Professions%-.-|a%s?", ""))
end

-- label: linke Beschriftung; itemID: klickbares Item (0/nil = nicht klickbar);
-- fallback: Text, wenn kein Item aufloesbar ist; enchantID: optional in den
-- Item-Link injiziert; bonusIDs: Upgrade-/Sockel-Bonusliste -> voller Link mit
-- korrekter Maximalstufe und Sockelplaetzen (sonst rendert der Client die Grundform).
local function setItemRow(b, label, itemID, fallback, enchantID, bonusIDs, suffix)
    -- Leeres/fehlendes Label -> nur der Item-Name (z.B. Edelsteine ohne Slot-Bezug).
    local prefix = (label and label ~= "") and (label .. ": ") or ""
    -- Suffix (z.B. Trinket-Stat-Modus "(Tempo)"): unterscheidet Varianten mit gleicher
    -- itemID, die WoW sonst identisch benennt (Rubinwelpenschale in 4 Modi).
    local suff = (suffix and suffix ~= "") and ("  |cff8b7bb8(" .. suffix .. ")|r") or ""
    if itemID and itemID ~= 0 then
        b.link = nil
        b.icon:SetTexture(134400)   -- Fragezeichen-Platzhalter bis geladen
        b.label:SetText(prefix .. "...")
        if bonusIDs and #bonusIDs > 0 then
            -- Vollen Item-String bauen und als Link-Item laden -> WoW liefert die
            -- korrekte Qualitaetsfarbe (inkl. Upgrade-bedingter Epik-Stufe),
            -- Maximalstufe und Sockelplaetze automatisch (statt selbst gefaerbt).
            local core = string.format("item:%d:%d:0:0:0:0:0:0:0:0:0:0:%d:%s",
                itemID, enchantID or 0, #bonusIDs, table.concat(bonusIDs, ":"))
            local item = Item:CreateFromItemLink(core)
            item:ContinueOnItemLoad(function()
                -- GetItemLink() gibt bei einem blanken item:-String nur den Rohstring
                -- zurueck. GetItemInfo(core) liefert dagegen den fertigen, nach der
                -- effektiven (upgrade-bedingten) Qualitaet gefaerbten Hyperlink.
                local name, fullLink, quality = C_Item.GetItemInfo(core)
                local link = fullLink
                if not link then
                    -- Notfall: farbigen Link selbst bauen (Qualitaet = effektive Stufe).
                    name = name or item:GetItemName() or ("item:" .. itemID)
                    local q = quality or item:GetItemQuality() or 1
                    local col = ITEM_QUALITY_COLORS[q]
                    local hex = (col and col.hex) or "|cffffffff"
                    link = hex .. "|H" .. core .. "|h[" .. name .. "]|h|r"
                end
                b.link = link
                b.icon:SetTexture(item:GetItemIcon())
                b.label:SetText(prefix .. stripQualityIcon(link) .. suff)
            end)
        else
            local item = Item:CreateFromItemID(itemID)
            item:ContinueOnItemLoad(function()
                local name = item:GetItemName() or ("item:" .. itemID)
                local link = item:GetItemLink()
                if enchantID and enchantID ~= 0 and link then
                    -- Enchant-Feld (2. Wert nach der ItemID) im Link setzen.
                    link = link:gsub("(Hitem:%d+):%-?%d*:", "%1:" .. enchantID .. ":", 1)
                end
                b.link = link
                b.icon:SetTexture(item:GetItemIcon())
                -- Vollen Link als Text -> WoW rendert ihn farbig in eckigen Klammern.
                b.label:SetText(prefix .. (stripQualityIcon(link) or ("[" .. name .. "]")) .. suff)
            end)
        end
    else
        b.link = nil
        b.icon:SetTexture(nil)
        b.label:SetText(prefix .. (fallback or "-") .. suff)
    end
    b:Show()
end

local function hideItemRows()
    for j = 1, #itemRows do itemRows[j]:Hide() end
end

-- Upgrade-Stufen-Bonus-IDs (Midnight S2, via /mm dumpq abgeleitet):
-- Held-Track 12841..12846 (1/6..6/6), Mythos-Track 12849..12854 (1/6..6/6).
-- Bestaetigt: 12843=Held 3/6, 12846=Held 6/6, 12854=Mythos 6/6. Im ganzen Dump
-- liegt kein anderer Bonus in diesem Bereich -> sichere Identifikation.
local UPGRADE_LEVEL_BONUS = {}
for id = 12841, 12846 do UPGRADE_LEVEL_BONUS[id] = true end
for id = 12849, 12854 do UPGRADE_LEVEL_BONUS[id] = true end
local MYTH_6_6_BONUS = 12854

-- Ersetzt die Upgrade-Stufe eines Gear-Teils durch Mythos 6/6, damit alle Items
-- einheitlich auf der hoechsten Stufe (ilvl-Maximum) angezeigt werden. Findet das
-- Item keinen bekannten Track-Bonus, bleibt es unveraendert (kein blindes Anheben).
local function normalizeToMyth(bonusIDs)
    if not bonusIDs then return bonusIDs end
    local out, found = {}, false
    for _, id in ipairs(bonusIDs) do
        if UPGRADE_LEVEL_BONUS[id] then found = true
        else out[#out + 1] = id end
    end
    if not found then return bonusIDs end
    out[#out + 1] = MYTH_6_6_BONUS
    return out
end

-- Label-Breite: entweder bis zur Quelle (Name wird davor abgeschnitten) oder voll.
local function boundLabel(b, toSource)
    b.label:ClearAllPoints()
    b.label:SetPoint("LEFT", b.icon, "RIGHT", 8, 0)
    if toSource then b.label:SetPoint("RIGHT", b.src, "LEFT", -6, 0)
    else b.label:SetPoint("RIGHT", b, "RIGHT", -4, 0) end
end

-- Quelle aus der Pipeline-Tabelle (Data/MetaMirrorSources.lua, aus Wowhead): fuer Items,
-- die NICHT im Abenteuerfuehrer stehen (Handwerk, Haendler, Tiefen, PvP) der einzige Weg
-- zu einem Quellentext. Liefert nil fuer unbekannte IDs/Arten -> Zeile bleibt leer.
local function pipelineSourceText(itemID)
    local root = _G.MetaMirrorItemSources
    local ps = root and root.items and root.items[itemID]
    if not ps then return nil end
    if ps.kind == "crafted" then return L.src_crafted end
    if ps.kind == "delve" then return L.src_delve end
    if ps.kind == "pvp" then return L.src_pvp end
    if ps.kind == "vendor" then
        local n = ps.name or {}
        local name = n[GetLocale()] or n.enUS or "?"
        return string.format(L.src_vendor, name)
    end
    return nil
end

-- Quelle einer Gear-/Trinket-Zeile: 1) Boss aus dem Abenteuerfuehrer (klickbar) 2) sonst
-- Pipeline-Quelle (Handwerk/Haendler/Tiefen/PvP aus Data/MetaMirrorSources.lua, unklickbar)
-- 3) sonst Klassenset-Label, falls Item-Set-Teil (setID) 4) sonst "Hergestellt", falls das
-- Item ein Handwerksqualitaets-Icon traegt (|A:Professions- im Link -> zuverlaessig crafted)
-- 5) sonst fallbackText, falls ausdruecklich uebergeben, oder leer. Achtung: KEIN pauschaler
-- "Hergestellt"-Fallback -- das wuerde nicht-craftbare Drops faelschlich als Handwerk labeln.
local function applyRowSource(b, itemID, fallbackText)
    b.src.srcData = nil
    b.src.text:SetText(""); b.src:Hide()
    boundLabel(b, false)
    if not itemID then return end
    local src = MetaMirror:GetItemSource(itemID)
    if src then
        b.src.srcData = src
        b.src.text:SetText(src.text)
        b.src:Show(); boundLabel(b, true)
        return
    end
    -- Pipeline-Quelle hat Vorrang vor einem generischen fallbackText.
    fallbackText = pipelineSourceText(itemID) or fallbackText
    -- Fallback sofort setzen (unklickbar), damit nie eine Leerzeile steht; die async
    -- Pruefung unten (Set / Handwerk) ueberschreibt ihn, sobald sie etwas Genaueres findet.
    if fallbackText and fallbackText ~= "" then
        b.src.text:SetText(fallbackText); b.src:Show(); boundLabel(b, true)
    end
    -- Kein Journal-Loot -> Klassenset (setID) oder Handwerk (Professions-Qualitaetsicon)?
    -- Item muss geladen sein; GetItemInfo liefert dann Link (mit Icon) + setID.
    local item = Item:CreateFromItemID(itemID)
    item:ContinueOnItemLoad(function()
        if b.src.srcData then return end   -- Journal-Quelle hat Vorrang
        local link = select(2, C_Item.GetItemInfo(itemID))
        local setID = select(16, C_Item.GetItemInfo(itemID))
        if setID and setID > 0 then
            b.src.text:SetText(L.src_tier)
            b.src:Show(); boundLabel(b, true)
        elseif link and link:find("|A:Professions", 1, true) then
            b.src.text:SetText(L.src_crafted)
            b.src:Show(); boundLabel(b, true)
        end
    end)
end

-- entries: Liste aus { label, itemID, fallback, enchantID, bonusIDs }.
-- Nur der Gear-Tab nutzt diese Liste -> hier auch Quelle + Besitz-Haken setzen.
local function renderItemList(entries)
    for j = 1, #rows do rows[j]:Hide() end
    hideStatsNote()
    if Body.msg then Body.msg:Hide() end
    local owned = MetaMirror:BuildOwnedSet()
    local i = 0
    for _, e in ipairs(entries) do
        i = i + 1
        local b = getItemRow(i)
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 0, -(i - 1) * 26)
        -- Slotname in die eigene Spalte; der Itemname kommt ohne Praefix (label=nil).
        setItemRow(b, nil, e.itemID, e.fallback, e.enchantID, e.bonusIDs)
        b.slot:SetText(e.label or "")
        -- Besitz-Schimmer (Abgleich nur ueber Basis-itemID -> upgrade-unabhaengig).
        local own = (e.itemID and owned[e.itemID]) or false
        b.hl:SetShown(own); b.hlEdge:SetShown(own)
        applyRowSource(b, e.itemID)
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
        HEAD="Kopf", NECK="Hals", SHOULDER="Schulter", BACK="Rücken", CHEST="Brust",
        WRIST="Handgelenke", HANDS="Hände", WAIST="Gürtel", LEGS="Beine", FEET="Füße",
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
    { key = "potion", label = "Trank"  },
    { key = "food",   label = "Food"   },
    { key = "oil",    label = "Oel"    },
    { key = "rune",   label = "Rune"   },
}

-- ===== "Verbesserungen": Verzauberungen + Edelsteine + Verbrauchsmaterial =====
-- Eine scrollbare Seite mit einklappbaren Abschnitten (Class-Codex-Optik).
local CHILD_W = 396            -- Breite des Scroll-Inhalts (Body 420 - 22 Leiste - Rand)
local IMP_HEADER_H, IMP_ROW_H, IMP_GAP = 26, 26, 6

-- Scrollbereich einmalig erzeugen; gibt das Inhalts-Kind zurueck.
local function ensureScroll()
    if not Body.scroll then
        local sf = CreateFrame("ScrollFrame", "MetaMirrorImpScroll", Body,
                               "UIPanelScrollFrameTemplate")
        sf:SetPoint("TOPLEFT", 0, 0)
        sf:SetPoint("BOTTOMRIGHT", -22, 0)   -- Platz fuer die Scrollleiste rechts
        sf:EnableMouseWheel(true)
        sf:SetScript("OnMouseWheel", function(self, delta)
            local newv = self:GetVerticalScroll() - delta * 24
            newv = math.max(0, math.min(newv, self:GetVerticalScrollRange()))
            self:SetVerticalScroll(newv)
        end)
        local child = CreateFrame("Frame", nil, sf)
        child:SetSize(CHILD_W, 1)
        sf:SetScrollChild(child)
        Body.scroll, Body.impChild = sf, child
    end
    return Body.impChild
end

-- Abschnitts-Kopf (klickbar: klappt den Abschnitt ein/aus).
local impHeaders = {}
local function getImpHeader(parent, i)
    if impHeaders[i] then return impHeaders[i] end
    local h = CreateFrame("Button", nil, parent)
    h:SetSize(CHILD_W - 2, IMP_HEADER_H)
    local bg = h:CreateTexture(nil, "BACKGROUND"); bg:SetAllPoints()
    bg:SetColorTexture(unpack(C.HEAD)); h.bg = bg
    h.title = fs(h, "GameFontNormal", C.VIOLET_S); h.title:SetPoint("LEFT", 6, 0)
    h.ind = h:CreateTexture(nil, "OVERLAY"); h.ind:SetSize(18, 18)
    h.ind:SetPoint("RIGHT", -4, 0)
    h:SetScript("OnClick", function(self)
        MetaMirrorDB.collapsed = MetaMirrorDB.collapsed or {}
        MetaMirrorDB.collapsed[self.key] = not MetaMirrorDB.collapsed[self.key]
        MetaMirror:Refresh()
    end)
    impHeaders[i] = h
    return h
end

-- Item-Zeile im Scroll-Kind (analog getItemRow, aber eigener Pool + Elternframe).
local impRows = {}
local function getImpRow(parent, i)
    if impRows[i] then return impRows[i] end
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(CHILD_W - 12, IMP_ROW_H)
    b:RegisterForClicks("AnyUp")
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(22, 22)
    b.icon:SetPoint("TOPLEFT", 0, 0)
    b.label = fs(b, "GameFontHighlight", C.TXT)
    b.label:SetPoint("LEFT", b.icon, "RIGHT", 6, 0)
    b:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link)
        GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self, button)
        if not self.link then return end
        if not HandleModifiedItemClick(self.link) then
            SetItemRef(self.link, self.link, button, self)
        end
    end)
    impRows[i] = b
    return b
end

local function hideImprovements()
    if Body.scroll then Body.scroll:Hide() end
    for j = 1, #impHeaders do impHeaders[j]:Hide() end
    for j = 1, #impRows do impRows[j]:Hide() end
end

-- Baut die drei Abschnitts-Definitionen aus den Spec-Daten.
local function improvementSections(data)
    local sections = {}
    -- Verzauberungen (itemID 0 -> kein Link, Fallback-Text)
    do
        local list = {}
        for _, e in ipairs(data.enchants or {}) do list[#list+1] = e end
        table.sort(list, bySlot)
        local entries = {}
        for _, e in ipairs(list) do
            local iid = (e.itemID ~= 0) and e.itemID or nil
            entries[#entries+1] = { label = slotLabel(e.slot), itemID = iid,
                                    fallback = L.ench_missing }
        end
        sections[#sections+1] = { key = "ench", title = L.sec_ench, entries = entries }
    end
    -- Edelsteine: einmalig einsetzbar -> je Stein nur 1x, ohne Slot-Bezug
    -- (derselbe Stein steckt oft in mehreren Sockeln; Slot-Angabe wuerde ihn doppeln).
    -- Kategorie (Primaer/Sekundaer) wird beim Laden aus den Statwerten bestimmt.
    do
        local gemIDs, seen = {}, {}
        for _, g in ipairs(data.gems or {}) do
            local iid = g.itemID
            if iid and iid ~= 0 and not seen[iid] then
                seen[iid] = true
                gemIDs[#gemIDs+1] = iid
            end
        end
        sections[#sections+1] = { key = "gems", title = L.sec_gems, gemIDs = gemIDs }
    end
    -- Verbrauchsmaterial
    do
        local c = data.consumables or {}
        local entries = {}
        for _, cat in ipairs(CONS_ORDER) do
            if c[cat.key] ~= nil then
                entries[#entries+1] = { label = cat.label, itemID = c[cat.key] }
            end
        end
        sections[#sections+1] = { key = "cons", title = L.sec_cons, entries = entries }
    end
    return sections
end

local MINUS_TEX = "Interface\\Buttons\\UI-MinusButton-Up"
local PLUS_TEX  = "Interface\\Buttons\\UI-PlusButton-Up"
local DIM_HEX   = "|cff9a92c0"

-- Signalbegriffe fuer die Primaer/Sekundaer-Einstufung eines Steins.
-- Beobachtung (Midnight, via /mm dumpgems): Primaersteine ("Immersangdiamanten")
-- geben "+X Primaerwert" (dt.) bzw. "+X Primary Stat" (en) und tragen "Einzigartig
-- angelegt"; Sekundaersteine nennen zwei Sekundaerwerte. GetItemStats ist bei
-- Edelsteinen leer (Stat kommt als Sockel-Effekt) -> wir scannen den Tooltip-Text.
-- "Primaerwert" wird BYTE-GENAU gematcht (ae = \195\164 in UTF-8), damit es
-- unabhaengig von der Datei-Kodierung sicher greift. Zusaetzlich Laufzeit-Globals
-- (konkrete Primaerstat-Namen, "Einzigartig angelegt") als Sicherheitsnetz.
local PRIMARY_NAMES = { "Prim\195\164rwert", "Primary Stat" }
for _, s in ipairs({ STAT_STRENGTH, STAT_AGILITY, STAT_INTELLECT, ITEM_UNIQUE_EQUIPPABLE }) do
    if s and s ~= "" then PRIMARY_NAMES[#PRIMARY_NAMES+1] = s end
end

-- Hidden-Tooltip-Scanner (gleiche Technik wie /mm dumpgems, liefert zuverlaessig).
local function scanGemLines(link)
    local tip = _G.MetaMirrorGemScanTip
    if not tip then
        tip = CreateFrame("GameTooltip", "MetaMirrorGemScanTip", nil, "GameTooltipTemplate")
    end
    tip:SetOwner(UIParent, "ANCHOR_NONE")
    tip:ClearLines()
    local out = {}
    if pcall(function() tip:SetHyperlink(link) end) then
        for i = 1, tip:NumLines() do
            local fsx = _G["MetaMirrorGemScanTipTextLeft" .. i]
            local s = fsx and fsx:GetText()
            if s and s ~= "" then out[#out+1] = s end
        end
    end
    return out
end

local function gemIsPrimary(link)
    if not link then return false end
    for _, txt in ipairs(scanGemLines(link)) do
        for _, name in ipairs(PRIMARY_NAMES) do
            if txt:find(name, 1, true) then return true end
        end
    end
    return false
end

-- Laedt alle Edelsteine, klassifiziert sie (Primaer/Sekundaer) und befuellt die
-- bereits platzierten Zeilen: Primaersteine zuerst, dann alphabetisch. Das Layout
-- steht synchron (Anzahl bekannt), nur Inhalt + Reihenfolge kommen asynchron nach.
local function fillGemRows(rowList, gemIDs)
    local results, remaining = {}, #gemIDs
    if remaining == 0 then return end
    for _, iid in ipairs(gemIDs) do
        local item = Item:CreateFromItemID(iid)
        item:ContinueOnItemLoad(function()
            local link = item:GetItemLink()
            results[#results+1] = {
                name = item:GetItemName() or ("item:" .. iid),
                icon = item:GetItemIcon(), link = link,
                primary = gemIsPrimary(link),
            }
            remaining = remaining - 1
            if remaining > 0 then return end
            table.sort(results, function(a, b)
                if a.primary ~= b.primary then return a.primary end   -- Primaer zuerst
                return a.name < b.name
            end)
            for i, r in ipairs(results) do
                local b = rowList[i]
                if b then
                    b.link = r.link
                    b.icon:SetTexture(r.icon)
                    local cat = r.primary and L.gem_primary or L.gem_secondary
                    -- Voller Link -> farbig in eckigen Klammern (wie WoW/Class Codex).
                    b.label:SetText(cat .. ": " .. (stripQualityIcon(r.link) or ("[" .. r.name .. "]")))
                    b:Show()
                end
            end
        end)
    end
end

local function renderImprovements(self, data)
    for j = 1, #rows do rows[j]:Hide() end
    hideStatsNote()
    hideItemRows()
    if Body.msg then Body.msg:Hide() end
    MetaMirrorDB.collapsed = MetaMirrorDB.collapsed or {}

    local child = ensureScroll()
    Body.scroll:Show()

    local y, ri, hi = 0, 0, 0
    for _, sec in ipairs(improvementSections(data)) do
        hi = hi + 1
        local h = getImpHeader(child, hi)
        h.key = sec.key
        h:ClearAllPoints(); h:SetPoint("TOPLEFT", 0, -y)
        h.title:SetText(sec.title)
        local collapsed = MetaMirrorDB.collapsed[sec.key]
        h.ind:SetTexture(collapsed and PLUS_TEX or MINUS_TEX)
        h:Show()
        y = y + IMP_HEADER_H + 2

        if not collapsed then
            if sec.gemIDs then
                -- Edelsteine: Zeilen synchron platzieren, Inhalt/Sortierung asynchron.
                if #sec.gemIDs == 0 then
                    ri = ri + 1
                    local b = getImpRow(child, ri)
                    b:ClearAllPoints(); b:SetPoint("TOPLEFT", 8, -y)
                    b.link = nil; b.icon:SetTexture(nil)
                    b.label:SetText(DIM_HEX .. L.no_data .. "|r")
                    b:Show()
                    y = y + IMP_ROW_H
                else
                    local rowList = {}
                    for _ = 1, #sec.gemIDs do
                        ri = ri + 1
                        local b = getImpRow(child, ri)
                        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 8, -y)
                        b.link = nil; b.icon:SetTexture(134400); b.label:SetText("...")
                        b:Show()
                        rowList[#rowList+1] = b
                        y = y + IMP_ROW_H
                    end
                    fillGemRows(rowList, sec.gemIDs)
                end
            elseif #sec.entries == 0 then
                ri = ri + 1
                local b = getImpRow(child, ri)
                b:ClearAllPoints(); b:SetPoint("TOPLEFT", 8, -y)
                b.link = nil; b.icon:SetTexture(nil)
                b.label:SetText(DIM_HEX .. L.no_data .. "|r")
                b:Show()
                y = y + IMP_ROW_H
            else
                for _, e in ipairs(sec.entries) do
                    ri = ri + 1
                    local b = getImpRow(child, ri)
                    b:ClearAllPoints(); b:SetPoint("TOPLEFT", 8, -y)
                    setItemRow(b, e.label, e.itemID, e.fallback, e.enchantID, e.bonusIDs)
                    y = y + IMP_ROW_H
                end
            end
        end
        y = y + IMP_GAP
    end
    child:SetHeight(math.max(1, y))
    for j = hi + 1, #impHeaders do impHeaders[j]:Hide() end
    for j = ri + 1, #impRows do impRows[j]:Hide() end
end

-- ===== "Schmuck": Trinket-Tierliste aus Bloodmallet (Sim-BiS) =====
-- Eigene Datenquelle (Data/MetaMirrorTrinkets.lua), unabhaengig von den WCL-Daten:
-- pro Spec drei Sichten (Gesamt/Raid/Dungeon) als S/A/B/C/D-Rangliste. Umschalter oben.
local TIER_COLOR = {
    S = { 1.00, 0.55, 0.10 },   -- orange-gold
    A = { 0.66, 0.35, 0.95 },   -- violett
    B = { 0.30, 0.55, 1.00 },   -- blau
    C = { 0.30, 0.80, 0.40 },   -- gruen
    D = { 0.60, 0.60, 0.60 },   -- grau
}

-- Stat-Modus eines Trinkets (Bloodmallet-Klammer-Suffix) -> lokalisierte Kurzform.
-- Dieselbe itemID kann in mehreren Modi auftauchen (Rubinwelpenschale 4x); der Modus
-- in Klammern hinter dem Namen sagt, welcher Sekundaerwert welchen Platz belegt.
local deDE = (GetLocale() == "deDE")
local TRINKET_MODE_LABEL = deDE and {
    Crit = "Krit", Haste = "Tempo", Mastery = "Meisterschaft",
    Vers = "Vielseitigkeit", Versatility = "Vielseitigkeit",
    St = "Einzelziel", Aoe = "AoE", Cleave = "Cleave",
} or {
    St = "Single", Aoe = "AoE",
}
local function trinketModeLabel(mode)
    if not mode or mode == "" then return nil end
    return TRINKET_MODE_LABEL[mode] or mode
end

local function trinketData(specID)
    -- Quelle: Bloodmallet-Sim-BiS (Data/MetaMirrorTrinkets.lua), unabhaengig von WCL.
    local root = _G.MetaMirrorTrinkets
    if not (root and root.specs and specID) then return nil end
    return root.specs[specID]
end

-- WCL-Nutzungsdaten (Top-Spieler, getrennt nach Content) fuer den Hybrid-Split.
local function wclTrinkets(specID)
    local root = _G.MetaMirrorData
    if not (root and root.trinkets and specID) then return nil end
    return root.trinkets[specID]
end

-- Tier aus der Rang-Position in der Nutzungsliste (glatte, lueckenlose Verteilung statt
-- harter Nutzungs-Anteil-Cuts: so springt es nie S->B, sondern S->A->B..., auch bei kleinen
-- Stichproben). Die Reihenfolge (=echte Nutzung) bleibt das Signal, der Tier ist nur die
-- visuelle Empfehlungsstaerke.
local function rankTier(pos)
    if pos <= 1 then return "S"
    elseif pos <= 3 then return "A"
    elseif pos <= 6 then return "B"
    elseif pos <= 10 then return "C"
    else return "D" end
end

-- Hybrid-Sicht: vollstaendige Bloodmallet-Sim-Liste (mit Stat-Modi). "overall" bleibt pur
-- (Sim-DPS). "raid"/"dungeon" werden nach der WCL-Nutzung des jeweiligen Contents umsortiert;
-- der Tier kommt rang-basiert aus dieser Nutzung (rankTier) -> echter M+/Raid-Unterschied
-- trotz Einzelziel-Sim. Trinkets ohne WCL-Content-Nutzung stehen (in Sim-Reihenfolge) hinten
-- mit Tier "D". Stat-Modi desselben Trinkets teilen sich Rang/Tier, bleiben untereinander.
local function hybridList(specID, view)
    local bm = trinketData(specID)
    if not bm then return nil end
    local simList = bm.overall or {}
    if view == "overall" then return simList end
    local wcl = wclTrinkets(specID)
    local wview = wcl and wcl[view]
    if not wview or #wview == 0 then return simList end   -- keine WCL-Daten -> Sim-Fallback
    local rank = {}
    for i, e in ipairs(wview) do
        if e.itemID and not rank[e.itemID] then rank[e.itemID] = i end
    end
    local out, seen = {}, {}
    -- 1) Bloodmallet-Liste (mit Stat-Modi), annotiert mit WCL-Rang + rang-basiertem Tier.
    for i, e in ipairs(simList) do
        local pos = rank[e.itemID]
        out[#out + 1] = {
            itemID = e.itemID, mode = e.mode,
            tier = pos and rankTier(pos) or "D",
            _rank = pos or (1000 + i),               -- ungenutzt -> ans Ende, Sim-Reihenfolge
            _sim = i,
        }
        if e.itemID then seen[e.itemID] = true end
    end
    -- 2) Im Content genutzte Trinkets, die Bloodmallet NICHT simuliert (~10%): trotzdem
    --    aufnehmen (rang-basierter Tier, ohne Stat-Modus), damit keine Empfehlung fehlt.
    for _, e in ipairs(wview) do
        if e.itemID and not seen[e.itemID] then
            seen[e.itemID] = true
            out[#out + 1] = { itemID = e.itemID, tier = rankTier(rank[e.itemID]),
                              _rank = rank[e.itemID], _sim = 0 }
        end
    end
    table.sort(out, function(a, b)
        if a._rank ~= b._rank then return a._rank < b._rank end
        return a._sim < b._sim                       -- gleiche itemID (Modi) -> Sim-Ordnung
    end)
    return out
end

-- Trinket-Zeile: [Tier] [Icon] [Name] .......... [Quelle]. Feldnamen (icon/src/label)
-- absichtlich wie in getItemRow -> applyRowSource/boundLabel/setItemRow direkt nutzbar.
local tkRows = {}
local function getTkRow(parent, i)
    if tkRows[i] then return tkRows[i] end
    local b = CreateFrame("Button", nil, parent)
    b:SetSize(CHILD_W - 12, 26)
    b:RegisterForClicks("AnyUp")
    b.tier = fs(b, "GameFontNormalLarge", C.TXT)
    b.tier:SetPoint("LEFT", 2, 0); b.tier:SetWidth(22); b.tier:SetJustifyH("CENTER")
    b.icon = b:CreateTexture(nil, "ARTWORK"); b.icon:SetSize(22, 22)
    b.icon:SetPoint("LEFT", b.tier, "RIGHT", 4, 0)
    b.src = CreateFrame("Button", nil, b)
    b.src:SetSize(140, 24); b.src:SetPoint("RIGHT", -2, 0)
    b.src.text = fs(b.src, "GameFontDisableSmall", C.DIM)
    b.src.text:SetPoint("RIGHT"); b.src.text:SetJustifyH("RIGHT"); b.src.text:SetWordWrap(false)
    b.src:SetScript("OnClick", function(self)
        if self.srcData then MetaMirror:OpenSource(self.srcData) end
    end)
    b.src:SetScript("OnEnter", function(self)
        if not self.srcData then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:AddLine(self.srcData.text or "")
        GameTooltip:AddLine(L.src_hint, 0.6, 0.6, 0.6)
        GameTooltip:Show()
    end)
    b.src:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b.label = fs(b, "GameFontHighlight", C.TXT)
    b.label:SetWordWrap(false); b.label:SetJustifyH("LEFT")
    b:SetScript("OnEnter", function(self)
        if not self.link then return end
        GameTooltip:SetOwner(self, "ANCHOR_RIGHT")
        GameTooltip:SetHyperlink(self.link); GameTooltip:Show()
    end)
    b:SetScript("OnLeave", function() GameTooltip:Hide() end)
    b:SetScript("OnClick", function(self, button)
        if not self.link then return end
        if not HandleModifiedItemClick(self.link) then
            SetItemRef(self.link, self.link, button, self)
        end
    end)
    tkRows[i] = b
    return b
end

-- Metrik-/Credit-Zeile + Scrollbereich, einmalig erzeugt. KEIN eigener M+/Raid-Umschalter
-- mehr: der Schmuck-Tab folgt dem globalen Kontext-Schalter (M+/Raid) oben im Panel, sonst
-- gaebe es zwei konkurrierende Umschalter fuer denselben Zweck (verwirrend).
local function ensureTrinketUI()
    if Body.tkScroll then return Body.tkChild end
    Body.tkNote = fs(Body, "GameFontDisableSmall", C.DIM)
    Body.tkNote:SetPoint("TOPLEFT", 0, -4); Body.tkNote:SetJustifyH("LEFT")
    local sf = CreateFrame("ScrollFrame", "MetaMirrorTkScroll", Body,
                           "UIPanelScrollFrameTemplate")
    sf:SetPoint("TOPLEFT", 0, -22); sf:SetPoint("BOTTOMRIGHT", -22, 0)
    sf:EnableMouseWheel(true)
    sf:SetScript("OnMouseWheel", function(self, delta)
        local newv = self:GetVerticalScroll() - delta * 24
        newv = math.max(0, math.min(newv, self:GetVerticalScrollRange()))
        self:SetVerticalScroll(newv)
    end)
    local child = CreateFrame("Frame", nil, sf); child:SetSize(CHILD_W, 1)
    sf:SetScrollChild(child)
    Body.tkScroll, Body.tkChild = sf, child
    return child
end

local function hideTrinkets()
    if Body.tkScroll then Body.tkScroll:Hide() end
    if Body.tkNote then Body.tkNote:Hide() end
    for j = 1, #tkRows do tkRows[j]:Hide() end
end

local function renderTrinkets(self, specID)
    local child = ensureTrinketUI()
    Body.tkScroll:Show()

    local spec = trinketData(specID)
    if not spec then
        Body.tkNote:Hide()
        for j = 1, #tkRows do tkRows[j]:Hide() end
        local b = getTkRow(child, 1)
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 8, 0)
        b.tier:SetText(""); b.icon:SetTexture(nil); b.link = nil
        b.src.srcData = nil; b.src.text:SetText(""); b.src:Hide()
        boundLabel(b, false)
        -- Ganze Spec ohne Bloodmallet-Daten -> ehrlicher Hinweis; die Liste fuellt sich,
        -- sobald Bloodmallet fuer diese Spec Profile liefert (Nachschub).
        b.label:SetText(DIM_HEX .. L.trinket_no_bm .. "|r")
        b.label:SetWordWrap(true)
        b:Show()
        child:SetHeight(48)
        return
    end
    -- Sicht folgt dem globalen Kontext-Schalter oben (M+/Raid): Raid -> Raid-Nutzung,
    -- M+ -> Dungeon-Nutzung. Fehlt fuer den gewaehlten Inhalt eine WCL-Stichprobe, faellt
    -- die Sicht auf die reine Sim-Rangliste ("overall") zurueck.
    local wcl = wclTrinkets(specID)
    local want = (MetaMirrorDB.content == "raid") and "raid" or "dungeon"
    local hasWant = (wcl and wcl[want] and #wcl[want] > 0) or false
    local view = hasWant and want or "overall"
    -- Metrik-Hinweis: Reihenfolge nach simuliertem Schaden. Die frueher hier genutzte
    -- Umsortierung nach echter Nutzung entfaellt seit dem Wegfall der WCL-Daten;
    -- Sim-Fallback = Sim-DPS-Rangliste (bloodmallet.com), M+/Raid dann identisch.
    local note
    if view == "overall" then
        note = L.trinket_note .. " " .. L.trinket_single
    else
        note = L.trinket_note_use
    end
    Body.tkNote:SetText(DIM_HEX .. note .. "|r"); Body.tkNote:Show()

    local list = hybridList(specID, view) or {}
    local y, i = 0, 0
    for _, e in ipairs(list) do
        i = i + 1
        local b = getTkRow(child, i)
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 8, -y)
        b.label:SetWordWrap(false)
        -- Wie im Gear-Tab auf Maximalstufe anzeigen: Mythos-6/6-Upgrade-Bonus in den
        -- Item-Link injizieren -> Raid-/Dungeon-Drops erscheinen auf hoechster Stufe.
        -- Bei Handwerks-/PvP-Trinkets (nicht auf dem Upgrade-Track) ignoriert der Client
        -- den Bonus und zeigt die Grundform -> kein kaputter Link.
        -- Stat-Modus (falls vorhanden) als "(Tempo)" o.ae. hinter den Namen -> so bleiben
        -- die vier Rubinwelpenschale-Varianten (gleiche itemID) unterscheidbar.
        setItemRow(b, nil, e.itemID, nil, nil, { MYTH_6_6_BONUS }, trinketModeLabel(e.mode))
        b.tier:SetText(e.tier or "")
        b.tier:SetTextColor(unpack(TIER_COLOR[e.tier] or C.DIM))
        -- Quelle rechts genau wie im Gear-Tab: Boss (Abenteuerfuehrer), sonst Klassenset,
        -- sonst "Hergestellt" NUR bei echtem Handwerks-Icon. KEIN pauschaler Fallback --
        -- ein nicht-craftbares Drop-Trinket (auch aus aelteren Seasons) bleibt sonst leer,
        -- statt faelschlich "Hergestellt" zu behaupten.
        applyRowSource(b, e.itemID)
        y = y + 26
    end
    -- Leere Sicht (z.B. Spec ohne Raid- oder M+-Stichprobe) -> Hinweiszeile.
    if i == 0 then
        i = 1
        local b = getTkRow(child, 1)
        b:ClearAllPoints(); b:SetPoint("TOPLEFT", 8, 0)
        b.tier:SetText(""); b.icon:SetTexture(nil); b.link = nil
        b.src.srcData = nil; b.src.text:SetText(""); b.src:Hide()
        boundLabel(b, false)
        b.label:SetText(DIM_HEX .. L.trinket_no_data .. "|r")
        b:Show()
        y = 28
    end
    for j = i + 1, #tkRows do tkRows[j]:Hide() end
    child:SetHeight(math.max(1, y))
end

function MetaMirror.RenderBody(self, classID, specID)
    if not Body.msg then
        Body.msg = fs(Body, "GameFontHighlight", C.DIM)
        Body.msg:SetPoint("TOPLEFT")
    end
    -- Schmuck-Tab hat eine eigene Datenquelle (Bloodmallet) und ist unabhaengig von
    -- den WCL-Daten -> vor dem DataFor-Check behandeln, damit er auch ohne WCL-Datensatz
    -- fuer die Spec rendert.
    if MetaMirrorDB.tab == "schmuck" then
        for j = 1, #rows do rows[j]:Hide() end
        hideStatsNote()
        hideItemRows(); hideImprovements()
        Body.msg:Hide()
        renderTrinkets(self, specID)
        return
    end
    hideTrinkets()
    local data = self:DataFor(classID, specID, MetaMirrorDB.content)
    if not data then
        for j = 1, #rows do rows[j]:Hide() end
        hideStatsNote()
        hideItemRows()
        hideImprovements()
        Body.msg:Show(); Body.msg:SetText(L.no_data)
        return
    end
    Body.msg:Hide()
    hideItemRows()
    -- Scroll-Seite nur beim "Verbesserungen"-Tab zeigen.
    if MetaMirrorDB.tab ~= "improve" then hideImprovements() end
    if MetaMirrorDB.tab == "stats" then
        renderStats(self, data)
    elseif MetaMirrorDB.tab == "gear" then
        -- Gear steht fuer sich: nur das Item, aber mit Maximalstufe + Sockeln (bonusIDs).
        local gear = {}
        for _, g in ipairs(data.gear or {}) do gear[#gear+1] = g end
        table.sort(gear, bySlot)
        -- Waffen-Konsistenz: eine Zweihandwaffe (Stab/2H/Distanz) belegt beide
        -- Waffenslots -> die getrennt aggregierte Nebenhand-Empfehlung ist dann
        -- unmoeglich. Equip-Location kommt direkt vom Client (GetItemInfoInstant,
        -- synchron aus der itemID) -> zuverlaessiger als jede Daten-Heuristik.
        local mainhandID
        for _, g in ipairs(gear) do
            if g.slot == "MAINHAND" then mainhandID = g.itemID break end
        end
        local dropOffhand = false
        if mainhandID then
            local loc = select(4, C_Item.GetItemInfoInstant(mainhandID))
            if loc == "INVTYPE_2HWEAPON" or loc == "INVTYPE_RANGED"
               or loc == "INVTYPE_RANGEDRIGHT" then
                dropOffhand = true
            end
        end
        -- Ausruestung ist einmalig anlegbar: dieselbe itemID kann nicht in zwei
        -- Slots stecken (z.B. RING1==RING2). Dublette (nach Slot sortiert -> erster
        -- Slot gewinnt) ueberspringen, damit keine unmoegliche Kombi erscheint.
        local seen = {}
        local entries = {}
        for _, g in ipairs(gear) do
            local dup = g.itemID and seen[g.itemID]
            if not dup and not (dropOffhand and g.slot == "OFFHAND") then
                if g.itemID then seen[g.itemID] = true end
                entries[#entries+1] = { label = slotLabel(g.slot), itemID = g.itemID,
                                        bonusIDs = normalizeToMyth(g.bonusIDs) }
            end
        end
        if #entries > 0 then renderItemList(entries)
        else Body.msg:Show(); Body.msg:SetText(L.no_data) end
    else -- improve: Verzauberungen + Edelsteine + Verbrauchsmaterial auf einer Seite
        renderImprovements(self, data)
    end
end
