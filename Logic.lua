MetaMirror = MetaMirror or {}

-- Datenzugriff: liefert den <specContent> oder nil.
function MetaMirror:DataFor(classID, specID, content)
    local specs = MetaMirrorData and MetaMirrorData.specs
    local c = specs and specs[classID]
    local s = c and c[specID]
    return s and s[content] or nil
end

-- Status eines Stats: "under" | "on" | "over" | "unknown".
-- "unknown", wenn der eigene Wert nil oder ein secret value ist (Kampf/Instanz).
function MetaMirror:StatStatus(currentPct, targetPct, tol)
    tol = tol or 0
    if currentPct == nil then return "unknown" end
    local ok, res = pcall(function()
        if math.abs(currentPct - targetPct) <= tol then return "on" end
        if currentPct < targetPct then return "under" end
        return "over"
    end)
    return ok and res or "unknown"
end

-- Ziel-Wertung aus dem aktuellen Verhaeltnis rating/pct hochrechnen.
-- Ohne gueltiges Verhaeltnis (pct <= 0, oder nil/secret) nicht bestimmbar -> nil.
function MetaMirror:TargetRating(currentRating, currentPct, targetPct)
    if not currentRating or not currentPct or currentPct <= 0 then return nil end
    local ok, res = pcall(function()
        return math.floor((currentRating / currentPct) * targetPct + 0.5)
    end)
    return ok and res or nil
end
