MetaMirror = MetaMirror or {}

-- Datenzugriff: liefert den <specContent> oder nil.
function MetaMirror:DataFor(classID, specID, content)
    local specs = MetaMirrorData and MetaMirrorData.specs
    local c = specs and specs[classID]
    local s = c and c[specID]
    return s and s[content] or nil
end

-- ItemIDs der beiden Schmuckstuecke aus dem Referenzprofil, als Set.
-- Der Schmuck-Tab zeigt eine ANDERE Quelle: eine Einzelziel-Rangliste, in der jedes
-- Trinket allein gegen dasselbe Basisprofil simuliert wird. Das Referenzprofil dagegen
-- ist ein fertig gebauter Charakter (Set-Boni, Stat-Verteilung, Fight Style). Beide
-- Reihenfolgen weichen deshalb regelmaessig voneinander ab -- das ist kein Fehler,
-- aber ohne Markierung wirkt es wie einer.
-- Leeres Set statt nil: die Aufrufer sollen nur EINEN Fall pruefen muessen.
function MetaMirror:ReferenceTrinkets(classID, specID, content)
    local set = {}
    local data = self:DataFor(classID, specID, content)
    for _, g in ipairs(data and data.gear or {}) do
        if (g.slot == "TRINKET1" or g.slot == "TRINKET2")
           and g.itemID and g.itemID ~= 0 then
            set[g.itemID] = true
        end
    end
    return set
end

-- Status eines Stats: "under" | "on" | "over" | "unknown".
-- Vergleicht Ratings (eigenes vs. Meta-Ziel). "unknown", wenn der eigene Wert
-- nil oder ein secret value ist (Kampf/Instanz). tol = Rating-Toleranzband.
function MetaMirror:StatStatus(current, target, tol)
    tol = tol or 0
    if current == nil then return "unknown" end
    local ok, res = pcall(function()
        if math.abs(current - target) <= tol then return "on" end
        if current < target then return "under" end
        return "over"
    end)
    return ok and res or "unknown"
end

-- Datenstand fuer die Kopfzeile: "Sim-Referenz . <Fight-Style> . <Datum>" (L.sim_note).
-- Schmuck-Tab: Trinket-Datensatz (Einzelziel-Sim; Datum aus `generated` oder aus der
-- version "bm-YYYY-MM-DD"). Andere Tabs: Sim-Datensatz mit Fight-Style des Kontexts.
-- root/troot nur fuer Tests uebergeben (Default: die geladenen Datentabellen).
-- nil, wenn kein Datum bekannt ist -> Aufrufer zeigt dann keine Zeile.
function MetaMirror:DataStamp(tab, content, root, troot)
    local L = self.L
    if tab == "schmuck" then
        troot = troot or _G.MetaMirrorTrinkets
        local date = troot and (troot.generated
            or (type(troot.version) == "string" and troot.version:match("%d%d%d%d%-%d%d%-%d%d")))
        if not date then return nil end
        return string.format(L.sim_note, L.fight_raid, date)
    end
    root = root or _G.MetaMirrorData
    if not (root and root.generated) then return nil end
    local style = root.fightStyles and root.fightStyles[content]
    -- castingpatchwerk3 bleibt gemappt, damit aeltere Datendateien (vor dem Wechsel
    -- auf fuenf Ziele) weiterhin ein lesbares Label bekommen statt des rohen Stils.
    local label = (style == "castingpatchwerk" and L.fight_raid)
        or ((style == "castingpatchwerk5" or style == "castingpatchwerk3") and L.fight_mplus)
        or style or ""
    return string.format(L.sim_note, label, root.generated)
end

-- Quellentext einer Gear-/Schmuck-Zeile, soweit er ohne Spiel-APIs feststeht:
-- zuerst die kuratierte Quelle aus Data/MetaMirrorSources.lua (Handwerk, Haendler,
-- Tiefen, PvP -- genauer, weil sie den Haendler benennt), danach der Handwerksmarker
-- aus dem Sim-Profil. Der Marker stammt aus crafted_stats im bloodmallet-Profil:
-- Handwerksitems kommen dort ohne Bonus-IDs, weshalb im Itemlink das
-- Handwerksqualitaets-Icon fehlt, an dem die UI sie sonst erkennt.
-- Der Abenteuerfuehrer hat weiter Vorrang -- der wird in der UI vorher geprueft.
-- root nur fuer Tests uebergeben (Default: die geladene Quellentabelle).
function MetaMirror:StaticSourceText(itemID, crafted, root)
    local L = self.L
    root = root or _G.MetaMirrorItemSources
    local ps = root and root.items and root.items[itemID]
    if ps then
        if ps.kind == "crafted" then return L.src_crafted end
        if ps.kind == "delve" then return L.src_delve end
        if ps.kind == "pvp" then return L.src_pvp end
        if ps.kind == "vendor" then
            local n = ps.name or {}
            return string.format(L.src_vendor, n[GetLocale()] or n.enUS or "?")
        end
    end
    if crafted then return L.src_crafted end
    return nil
end

-- Loescht eine frei gewaehlte Fensterposition, damit das Panel wieder am
-- Charakterfenster andocken kann. Notwendig, weil eine custom-Position an UIParent
-- haengt: das Panel folgt dem Charakterfenster dann nicht mehr und steht im Weg,
-- sobald Blizzard es fuer ein anderes Fenster verschiebt.
-- db nur fuer Tests uebergeben (Default: die gespeicherten Variablen).
function MetaMirror:ClearCustomPosition(db)
    db = db or MetaMirrorDB
    if db and db.pos then db.pos.custom = nil end
end

-- Bonus-ID-Saetze desselben Items aus ANDEREN Spec-Profilen, als Messkandidaten fuer
-- die Referenzstufe.
-- Hintergrund: Die Quelle liefert die Stufe mal in den Bonus-IDs, mal nur im Feld
-- itemLevel. Im zweiten Fall zeigt der Itemlink die unaufgewertete Basisstufe -- mit
-- /mm ilvl gemessen: Ruecken 268253 kommt auf 219 statt 344. Dasselbe Item steht in
-- anderen Spec-Profilen desselben Builds mit vollstaendigen Bonus-IDs; das sind belegte
-- Quellendaten, keine geratenen IDs. Die UI misst jeden Kandidaten im Spiel und
-- uebernimmt ihn nur, wenn die Stufe die Referenz EXAKT trifft.
--
-- Handwerksitems sind ausgenommen. Bei ihnen kodieren die Bonus-IDs zusaetzlich die
-- gewaehlten Sekundaerwerte, und die unterscheiden sich je Spec: Nebenhand 237840 hat
-- im Vengeance-Profil crafted_stats=36/40, im Havoc-Profil 49/36. Ein geliehener Satz
-- traefe die Stufe, wuerde aber fremde Werte anzeigen -- eine erfundene Angabe an
-- anderer Stelle statt an dieser.
--
-- Sortiert, weil pairs keine feste Reihenfolge hat: sonst entscheidet der Zufall,
-- welcher von mehreren gleichwertigen Saetzen genommen wird.
-- root/limit nur fuer Tests uebergeben (Default: die geladenen Daten, hoechstens 6
-- Kandidaten -- jeder kostet im Spiel ein asynchrones Item-Laden).
function MetaMirror:BorrowableBonusSets(itemID, ownIDs, crafted, root, limit)
    root = root or MetaMirrorData
    local specs = root and root.specs
    if not (itemID and specs) or crafted then return {} end
    local own = table.concat(ownIDs or {}, ":")
    local byKey, keys = {}, {}
    for _, byClass in pairs(specs) do
        for _, bySpec in pairs(byClass) do
            for _, entry in pairs(bySpec) do
                for _, g in ipairs(entry.gear or {}) do
                    if g.itemID == itemID and g.bonusIDs and #g.bonusIDs > 0 then
                        local key = table.concat(g.bonusIDs, ":")
                        -- Der eigene Satz wurde vom Aufrufer schon gemessen.
                        if key ~= own and not byKey[key] then
                            byKey[key] = g.bonusIDs
                            keys[#keys + 1] = key
                        end
                    end
                end
            end
        end
    end
    table.sort(keys)
    local out = {}
    for i = 1, math.min(#keys, limit or 6) do out[i] = byKey[keys[i]] end
    return out
end
