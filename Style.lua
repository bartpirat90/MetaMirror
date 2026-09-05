-- ============================================================
-- MetaMirror - Style.lua
-- Gemeinsame Optik aller Addons dieser Reihe. Referenz ist KeyRoulette:
-- neutraler, fast schwarzer Grund, Violett AUSSCHLIESSLICH als Akzent,
-- Tiefe durch senkrechte Verlaeufe, eine Lichtkante oben und einen
-- Schlagschatten ums Fenster.
--
-- Diese Datei ist in jedem Addon Zeile fuer Zeile identisch -- bis auf die
-- eine Namensraum-Zeile direkt unter diesem Kopf. Aenderungen an der Optik
-- gehoeren hierher und werden dann in die anderen Addons kopiert, NICHT in
-- die einzelnen UI-Dateien gestreut.
--
-- Die Datei ist rein deklarativ: sie erzeugt beim Laden keine Frames und
-- ruft keine WoW-API auf. Alles passiert erst in den Funktionen.
-- ============================================================
MetaMirror = MetaMirror or {}
local NS = MetaMirror                     -- <<< einzige addon-spezifische Zeile

-- ------------------------------------------------------------
-- Palette (RGBA 0.0-1.0)
-- ------------------------------------------------------------
local C = {
    -- Flaechen
    BG_MAIN      = {0.059, 0.059, 0.071, 0.97}, -- #0f0f12 Fensterflaeche
    BG_HDR       = {0.082, 0.082, 0.102, 1.0},  -- #15151a Kopf-/Fusszeile
    BG_STRIP     = {0.071, 0.071, 0.086, 1.0},  -- #121216 Infoleiste, Tab-Leiste
    BG_ROW_ALT   = {0.075, 0.075, 0.094, 1.0},  -- #131318 jede zweite Tabellenzeile
    BG_CARD      = {0.118, 0.118, 0.145, 1.0},  -- #1e1e25 Karten, Spuren, Icons
    BG_CARD_WIN  = {0.165, 0.122, 0.239, 1.0},  -- #2a1f3d hervorgehobene Karte

    -- Kanten
    BORDER       = {0.165, 0.165, 0.200, 1.0},  -- #2a2a33 Fensterrahmen, Trennlinien
    BORDER_LIGHT = {0.200, 0.200, 0.243, 1.0},  -- #33333e Knopfrahmen
    BORDER_DASH  = {0.298, 0.114, 0.584, 1.0},  -- #4c1d95 gestrichelte Karten
    HILITE       = {1.0,   1.0,   1.0,   0.06}, -- Lichtkante oben auf erhabenen Flaechen
    SHADOW       = {0.0,   0.0,   0.0,   0.45}, -- Fensterschatten, innerer Endpunkt

    -- Akzent
    ACCENT       = {0.659, 0.333, 0.969, 1.0},  -- #a855f7 aktiver Tab, Hauptknopf
    ACCENT_LIGHT = {0.753, 0.518, 0.988, 1.0},  -- #c084fc Akzenttext, Hover

    -- Text
    TXT_TITLE    = {1.0,   1.0,   1.0,   1.0},  -- #ffffff Titel
    TXT_PRI      = {0.902, 0.902, 0.918, 1.0},  -- #e6e6ea Haupttext
    TXT_SEC      = {0.541, 0.541, 0.588, 1.0},  -- #8a8a96 Nebentext
    TXT_DIM      = {0.290, 0.290, 0.333, 1.0},  -- #4a4a55 abgeschaltet, "keine Daten"
    TXT_HDR      = {0.384, 0.353, 0.439, 1.0},  -- #625a70 Spaltenkoepfe
    TXT_PLAYER   = {0.984, 0.573, 0.235, 1.0},  -- #fb923c eigener Charakter

    -- Verlaufsendpunkte. Namensschema *_TOP/*_BOT = oberer/unterer Endpunkt
    -- eines senkrechten Verlaufs.
    BG_HDR_TOP   = {0.114, 0.114, 0.149, 1.0},  -- #1d1d26 Kopfzeile oben
    BG_HDR_BOT   = {0.078, 0.078, 0.098, 1.0},  -- #141419 Kopfzeile unten
    BG_TAB_TOP   = {0.090, 0.090, 0.114, 1.0},  -- #17171d inaktiver Tab oben
    BG_TAB_BOT   = {0.075, 0.075, 0.094, 1.0},  -- #131318 inaktiver Tab unten
    BG_TABON_TOP = {0.145, 0.145, 0.184, 1.0},  -- #25252f aktiver Tab oben
    BG_TABON_BOT = {0.106, 0.106, 0.137, 1.0},  -- #1b1b23 aktiver Tab unten
    BG_BTN_TOP   = {0.149, 0.149, 0.184, 1.0},  -- #26262f Knopf oben
    BG_BTN_BOT   = {0.102, 0.102, 0.129, 1.0},  -- #1a1a21 Knopf unten
    BG_ACC_TOP   = {0.741, 0.482, 0.976, 1.0},  -- #bd7bf9 Akzentknopf oben
    BG_ACC_BOT   = {0.545, 0.247, 0.839, 1.0},  -- #8b3fd6 Akzentknopf unten

    -- Zustandsfarben. Bewusst gesaettigt und NICHT violett: sie sollen als
    -- Aussage lesbar sein, nicht als Teil der Markenfarbe.
    GREEN        = {0.290, 0.871, 0.502, 1.0},  -- angelegt / im Ziel
    AMBER        = {0.984, 0.749, 0.141, 1.0},  -- Hinweis, Favoritenstern
    CORAL        = {0.874, 0.353, 0.247, 1.0},  -- fehlt / unter Ziel
    BLUE         = {0.376, 0.647, 0.980, 1.0},  -- im Beutel
    ITEM         = {0.639, 0.816, 1.0,   1.0},  -- Itemnamen ohne Qualitaetsfarbe
}

-- Altnamen der einzelnen Addons zeigen auf dieselben Tabellen. Dadurch behaelt
-- jedes Addon sein gewachsenes Vokabular, ohne dass es zwei Wahrheiten gibt.
C.HEAD         = C.BG_HDR
C.HDR_BG       = C.BG_HDR
C.PANEL2       = C.BG_CARD
C.VIOLET       = C.ACCENT
C.VIOLET_S     = C.ACCENT_LIGHT
C.SEC          = C.ACCENT_LIGHT
C.STAR         = C.AMBER
C.TXT          = C.TXT_PRI
C.DIM          = C.TXT_SEC
C.GOLD         = C.AMBER
C.TXT_LEVEL    = C.ACCENT_LIGHT
C.BORDER_ACT   = C.ACCENT
C.BORDER_INACT = C.TXT_DIM

NS.C = C

-- Hex-Kurzformen fuer Inline-Faerbung in Texten (|cff...). Dieselben Werte wie
-- oben; wer sie von Hand hinschreibt, laeuft beim naechsten Palettenwechsel
-- unweigerlich auseinander.
NS.HEX = {
    TITLE  = "|cffffffff",
    PRI    = "|cffe6e6ea",
    SEC    = "|cff8a8a96",
    DIM    = "|cff4a4a55",
    ACCENT = "|cffa855f7",
    LIGHT  = "|cffc084fc",
}

-- ------------------------------------------------------------
-- Tiefen-Bausteine
-- ------------------------------------------------------------
local S = {}
NS.Style = S

-- Einfarbige Flaeche.
function S.Tex(parent, layer, col)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(col[1], col[2], col[3], col[4] or 1)
    return t
end

-- Faerbt eine VORHANDENE Textur zum Verlauf um.
--
-- minColor liegt bei "VERTICAL" unten und bei "HORIZONTAL" links -- das ist
-- Blizzards Reihenfolge, nicht unsere. Stehen die Verlaeufe im Spiel auf dem
-- Kopf, werden hier die beiden CreateColor-Zeilen getauscht: eine Stelle statt
-- einem Dutzend Aufrufer.
function S.SetGradient(t, orientation, minColor, maxColor)
    local ok = pcall(function()
        t:SetGradient(orientation,
            CreateColor(minColor[1], minColor[2], minColor[3], minColor[4] or 1),
            CreateColor(maxColor[1], maxColor[2], maxColor[3], maxColor[4] or 1))
    end)
    if not ok then
        -- Ohne Verlauf lieber eine saubere einfarbige Flaeche als der weisse
        -- Traeger. Flacher als gedacht, aber nie kaputt.
        t:SetColorTexture(maxColor[1], maxColor[2], maxColor[3], maxColor[4] or 1)
    end
    return ok
end

-- SetGradient faerbt eine vorhandene Textur ein, es erzeugt keine: der weisse
-- Traeger muss zuerst da sein.
function S.Gradient(parent, layer, orientation, minColor, maxColor)
    local t = parent:CreateTexture(nil, layer)
    t:SetColorTexture(1, 1, 1, 1)
    S.SetGradient(t, orientation, minColor, maxColor)
    return t
end

-- 1 px Weiss mit sehr wenig Alpha an der Oberkante. Der billigste und
-- wirksamste Griff fuer "erhaben": eine Flaeche wirkt plastisch, sobald oben
-- Licht auf ihr liegt.
function S.TopHighlight(parent, anchor, layer)
    anchor = anchor or parent
    local t = parent:CreateTexture(nil, layer or "OVERLAY")
    t:SetColorTexture(C.HILITE[1], C.HILITE[2], C.HILITE[3], C.HILITE[4])
    t:SetPoint("TOPLEFT",  anchor, "TOPLEFT",  0, 0)
    t:SetPoint("TOPRIGHT", anchor, "TOPRIGHT", 0, 0)
    t:SetHeight(1)
    return t
end

function S.Lighten(c, f)
    return { math.min(1, c[1] + f), math.min(1, c[2] + f), math.min(1, c[3] + f), c[4] or 1 }
end

-- Schlagschatten: vier Verlaufsstreifen ausserhalb des Rahmens. Bewusst ohne
-- Texturdatei -- SetColorTexture plus SetGradient reicht, und so muss kein
-- Blizzard-Pfad geraten werden.
--
-- Die Ecken bleiben frei: ein linearer Verlauf kann keinen diagonalen Abfall,
-- und vier Eckquadrate wuerden dort einen sichtbaren dunklen Klecks erzeugen.
-- Bei 8 px faellt die Luecke nicht auf. Oben schwaecher als unten, wie bei
-- Licht von vorne oben.
local SHADOW_W    = 8
local SHADOW_NONE = {0, 0, 0, 0}
local SHADOW_SOFT = {0, 0, 0, 0.18}

function S.Shadow(frame)
    local function strip(orientation, minColor, maxColor)
        local t = S.Gradient(frame, "BACKGROUND", orientation, minColor, maxColor)
        t:SetDrawLayer("BACKGROUND", -8)
        return t
    end
    local top = strip("VERTICAL", SHADOW_SOFT, SHADOW_NONE)
    top:SetPoint("BOTTOMLEFT",  frame, "TOPLEFT",  0, 0)
    top:SetPoint("BOTTOMRIGHT", frame, "TOPRIGHT", 0, 0)
    top:SetHeight(SHADOW_W)

    local bot = strip("VERTICAL", SHADOW_NONE, C.SHADOW)
    bot:SetPoint("TOPLEFT",  frame, "BOTTOMLEFT",  0, 0)
    bot:SetPoint("TOPRIGHT", frame, "BOTTOMRIGHT", 0, 0)
    bot:SetHeight(SHADOW_W)

    local left = strip("HORIZONTAL", SHADOW_NONE, C.SHADOW)
    left:SetPoint("TOPRIGHT",    frame, "TOPLEFT",    0, 0)
    left:SetPoint("BOTTOMRIGHT", frame, "BOTTOMLEFT", 0, 0)
    left:SetWidth(SHADOW_W)

    local right = strip("HORIZONTAL", C.SHADOW, SHADOW_NONE)
    right:SetPoint("TOPLEFT",    frame, "TOPRIGHT",    0, 0)
    right:SetPoint("BOTTOMLEFT", frame, "BOTTOMRIGHT", 0, 0)
    right:SetWidth(SHADOW_W)
end

-- 1 px Rahmen um einen Frame. Eigener Kind-Frame statt SetBackdrop auf dem
-- Frame selbst: nicht jeder Frame traegt BackdropTemplate, und ein Kind laesst
-- sich unabhaengig umfaerben.
function S.Border(frame, col)
    local f = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    f:SetAllPoints()
    f:SetBackdrop({ edgeFile = "Interface/Tooltips/UI-Tooltip-Border", edgeSize = 1 })
    f:SetBackdropBorderColor(unpack(col or C.BORDER))
    return f
end

-- Gibt einem Knopf Verlauf, Rahmen, Lichtkante und drei Zustaende. Haengt
-- btn.StyleSetColors(top, bot) und btn.StyleSetLocked(bool) an; ueberfahren und
-- gedrueckt regelt der Knopf selbst.
--
-- OnEnter/OnLeave werden gehookt, nicht gesetzt: mehrere Knoepfe tragen dort
-- bereits Tooltips, die ein SetScript stillschweigend entfernen wuerde.
--
-- btn.label muss vorhanden sein, bevor diese Funktion laeuft -- sie versetzt die
-- Beschriftung im gedrueckten Zustand.
function S.Button(btn, topColor, botColor)
    local top, bot = topColor or C.BG_BTN_TOP, botColor or C.BG_BTN_BOT
    local topHot, botHot = S.Lighten(top, 0.05), S.Lighten(bot, 0.05)

    local bg = S.Gradient(btn, "BACKGROUND", "VERTICAL", bot, top)
    bg:SetAllPoints()
    S.Border(btn, C.BORDER_LIGHT)
    local hi = S.TopHighlight(btn, btn, "ARTWORK")

    local locked, pressed, hovered = false, false, false

    local function LabelOffset(down)
        local f = btn.label
        if not f then return end
        f:ClearAllPoints()
        if down then f:SetPoint("CENTER", btn, "CENTER", 1, -1)
        else f:SetAllPoints() end
    end

    local function Apply()
        if pressed or locked then
            -- Verlauf gedreht: dunkel oben liest sich als eingedrueckt
            S.SetGradient(bg, "VERTICAL", top, bot)
            hi:Hide()
            LabelOffset(true)
        elseif hovered then
            S.SetGradient(bg, "VERTICAL", botHot, topHot)
            hi:Show()
            LabelOffset(false)
        else
            S.SetGradient(bg, "VERTICAL", bot, top)
            hi:Show()
            LabelOffset(false)
        end
    end

    btn:HookScript("OnEnter",     function() hovered = true;                   Apply() end)
    btn:HookScript("OnLeave",     function() hovered = false; pressed = false; Apply() end)
    btn:HookScript("OnMouseDown", function() pressed = true;                   Apply() end)
    btn:HookScript("OnMouseUp",   function() pressed = false;                  Apply() end)

    -- Umfaerben nach dem Bau, z.B. beim Umschalten eines Segmentknopfes auf
    -- die Akzentfarbe. Ohne diesen Setter muesste der Aufrufer den Verlauf
    -- selbst kennen -- genau die Streuung, die diese Datei verhindern soll.
    btn.StyleSetColors = function(newTop, newBot)
        top, bot = newTop or C.BG_BTN_TOP, newBot or C.BG_BTN_BOT
        topHot, botHot = S.Lighten(top, 0.05), S.Lighten(bot, 0.05)
        Apply()
    end
    btn.StyleSetLocked = function(on)
        locked = on and true or false
        Apply()
    end

    Apply()
    return btn
end
