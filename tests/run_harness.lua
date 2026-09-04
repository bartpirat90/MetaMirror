-- Standalone-Verifikation der secret-sicheren MetaMirror-Logik.
-- Mockt WoW-Globals, laedt die Addon-Logik, faehrt SelfTest + SecondaryFor-Tests.

local DIR = arg[1] or "."

-- ---- WoW-Globals mocken -------------------------------------------------
function GetLocale() return "enUS" end
CR_HASTE_SPELL = 1; CR_CRIT_SPELL = 2; CR_MASTERY = 3; CR_VERSATILITY_DAMAGE_DONE = 4

local HASTE_VAL = 34
function GetHaste() return HASTE_VAL end
function GetCritChance() return 28 end
function GetMasteryEffect() return 22 end
function GetCombatRatingBonus() return 16 end
function GetCombatRating() return 8420 end
function UnitClass() return "Warrior", "WARRIOR", 1 end
function GetSpecialization() return 1 end
function GetSpecializationInfo() return 71 end

-- ---- Addon-Dateien laden ------------------------------------------------
dofile(DIR .. "/Localization.lua")
-- Die Datendatei wird von der Pipeline erzeugt; fehlt sie, laufen die Struktur-
-- tests trotzdem (DataFor_present schlaegt dann erwartungsgemaess fehl).
local okData = pcall(dofile, DIR .. "/Data/MetaMirrorData.lua")
if not okData then print("HINWEIS: Data/MetaMirrorData.lua nicht geladen") end
dofile(DIR .. "/Logic.lua")
dofile(DIR .. "/Player.lua")
dofile(DIR .. "/SelfTest.lua")

-- ---- SelfTest ausfuehren ------------------------------------------------
-- RunSelfTest gibt nichts zurueck, sondern druckt je Test eine Zeile; darum den
-- Ausgabestrom abfangen und jede FAIL-Zeile als Fehlschlag des Harness werten.
print("=== SelfTest ===")
local rawPrint = print
print = function(...)
    local line = table.concat({ ... }, " ")
    -- Nur die Einzelzeilen "<name>: FAIL - ..." zaehlen; die Summenzeile "n FAIL" nicht.
    if line:find(": FAIL", 1, true) then FAILED = true end
    rawPrint(line)
end
MetaMirror:RunSelfTest()
print = rawPrint

-- ---- SecondaryFor: Normalfall + Secret-Fall -----------------------------
print("=== SecondaryFor ===")
local function check(name, cond)
    print((cond and "PASS " or "FAIL ") .. name)
    if not cond then FAILED = true end
end

-- Normalfall: echte Zahl
local n = MetaMirror:SecondaryFor("haste")
check("normal pct==34", n.pct == 34)
check("normal secret==false", n.secret == false)

-- Secret-Fall: GetHaste liefert einen Wert, der bei Arithmetik wirft
HASTE_VAL = setmetatable({}, { __add = function() error("secret") end })
local s = MetaMirror:SecondaryFor("haste")
check("secret pct==nil", s.pct == nil)
check("secret flag==true", s.secret == true)
check("secret rating present (nicht secret)", s.rating == 8420)

if FAILED then
    print("HARNESS: FAIL")
    os.exit(1)
else
    print("HARNESS: ALLE PASS")
end
