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

-- Eigener Sekundaerwert eines Keys: { pct = <number>, rating = <number> }.
-- Nur eigene Charakterwerte -> keine secret values.
function MetaMirror:SecondaryFor(key)
    local m = STAT_MAP[key]
    if not m then return { pct = 0, rating = 0 } end
    local ok, pct = pcall(m.pct)
    local rating = GetCombatRating(m.cr) or 0
    return { pct = (ok and pct) or 0, rating = rating }
end
