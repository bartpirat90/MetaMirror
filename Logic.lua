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
