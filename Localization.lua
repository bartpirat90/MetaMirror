MetaMirror = MetaMirror or {}
local L = {}

-- Basis: Englisch
L.title        = "MetaMirror"
L.tab_stats    = "Stats"
L.tab_talents  = "Talents"
L.tab_gear     = "Gear"
L.tab_gems     = "Gems/Ench."
L.tab_cons     = "Consumables"
L.ctx_mplus    = "M+"
L.ctx_raid     = "Raid"
L.autodetect   = "auto-detected"
L.no_data      = "No data for this spec yet."
L.target       = "Target"
L.need         = "%d%% short"
L.over         = "%d%% too much"
L.on_target    = "on target"
L.secret_chip  = "protected in combat"
L.copy_hint    = "Click to select, then Ctrl+C"
L.usage        = "used by %d%% of top players"
L.stat_haste   = "Haste"
L.stat_crit    = "Crit"
L.stat_mastery = "Mastery"
L.stat_vers    = "Versatility"
L.slash_hint   = "MetaMirror: /mm opens or closes the panel."

if GetLocale() == "deDE" then
    L.tab_talents  = "Talente"
    L.tab_cons     = "Verbrauch"
    L.autodetect   = "automatisch erkannt"
    L.no_data      = "Fuer diese Spec liegen noch keine Daten vor."
    L.target       = "Ziel"
    L.need         = "%d%% fehlen"
    L.over         = "%d%% zu viel"
    L.on_target    = "im Ziel"
    L.secret_chip  = "im Kampf geschuetzt"
    L.copy_hint    = "Anklicken, dann Strg+C"
    L.usage        = "von %d%% der Top-Spieler genutzt"
    L.stat_haste   = "Tempo"
    L.stat_crit    = "Krit"
    L.stat_mastery = "Meisterschaft"
    L.stat_vers    = "Vielseitigkeit"
    L.slash_hint   = "MetaMirror: /mm oeffnet oder schliesst das Panel."
end

MetaMirror.L = L
