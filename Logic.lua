MetaMirror = MetaMirror or {}

-- Datenzugriff: liefert den <specContent> oder nil.
function MetaMirror:DataFor(classID, specID, content)
    local specs = MetaMirrorData and MetaMirrorData.specs
    local c = specs and specs[classID]
    local s = c and c[specID]
    return s and s[content] or nil
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
    local label = (style == "castingpatchwerk" and L.fight_raid)
        or (style == "castingpatchwerk3" and L.fight_mplus)
        or style or ""
    return string.format(L.sim_note, label, root.generated)
end
