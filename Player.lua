MetaMirror = MetaMirror or {}

-- Zuordnung Stat-Key -> (Prozent-Funktion, Wertungs-CR-Konstante, Label-Key)
local STAT_MAP = {
    haste   = { pct = function() return GetHaste() end,
                cr = CR_HASTE_SPELL,               label = "stat_haste" },
    crit    = { pct = function() return GetCritChance() end,
                cr = CR_CRIT_SPELL,                label = "stat_crit" },
    mastery = { pct = function() return GetMasteryEffect() end,
                cr = CR_MASTERY,                   label = "stat_mastery" },
    vers    = { pct = function() return GetCombatRatingBonus(CR_VERSATILITY_DAMAGE_DONE) end,
                cr = CR_VERSATILITY_DAMAGE_DONE,   label = "stat_vers" },
}
MetaMirror.STAT_MAP = STAT_MAP

-- Aktuelle Klasse/Spec als IDs; nil, wenn keine Spec gewaehlt.
function MetaMirror:CurrentSpecKey()
    local _, _, classID = UnitClass("player")
    local specIndex = GetSpecialization()
    if not specIndex then return classID, nil end
    local specID = GetSpecializationInfo(specIndex)
    return classID, specID
end

-- Eigener Sekundaerwert eines Keys: { pct = <number|nil>, rating = <number|nil>, secret = <bool> }.
-- Ab Patch 12.x sind diese Stat-APIs SecretWhenUnitStatsRestricted: in Kampf/Instanz
-- liefern sie "secret values", auf denen Arithmetik/Vergleich wirft. Wir erkennen das per
-- Arithmetik-Test in pcall und geben dann nil + secret=true zurueck (nie crashen).
function MetaMirror:SecondaryFor(key)
    local m = STAT_MAP[key]
    if not m then return { pct = 0, rating = 0, secret = false } end

    local okPct, pct = pcall(m.pct)
    if not okPct then pct = nil end
    local okRating, rating = pcall(GetCombatRating, m.cr)
    if not okRating then rating = nil end

    -- Secret-Test: Arithmetik auf dem Wert. Schlaegt sie fehl, ist der Wert secret.
    local pctUsable = pct ~= nil and pcall(function() return pct + 0 end)
    local ratingUsable = rating ~= nil and pcall(function() return rating + 0 end)

    return {
        pct = pctUsable and pct or nil,
        rating = ratingUsable and rating or nil,
        secret = (not pctUsable) or (not ratingUsable),
    }
end
