MetaMirror = MetaMirror or {}
MetaMirror.tests = {}
local function test(name, fn) MetaMirror.tests[#MetaMirror.tests+1] = { name = name, fn = fn } end
local function assertEqual(actual, expected, msg)
    if actual ~= expected then
        error((msg or "assert") .. ": erwartet " .. tostring(expected) .. ", war " .. tostring(actual), 2)
    end
end

function MetaMirror:RunSelfTest()
    local pass, fail = 0, 0
    for _, t in ipairs(self.tests) do
        local ok, err = pcall(t.fn)
        if ok then pass = pass + 1; print("|cff4ade80[MM-TEST]|r " .. t.name .. ": PASS")
        else fail = fail + 1; print("|cffff5555[MM-TEST]|r " .. t.name .. ": FAIL - " .. tostring(err)) end
    end
    print("|cffa855f7[MM-TEST]|r " .. pass .. " PASS, " .. fail .. " FAIL")
end

test("StatStatus_under", function()
    assertEqual(MetaMirror:StatStatus(28, 34, 1.5), "under", "under")
end)
test("StatStatus_on_withinTol", function()
    assertEqual(MetaMirror:StatStatus(33, 34, 1.5), "on", "within tol")
end)
test("StatStatus_over", function()
    assertEqual(MetaMirror:StatStatus(31, 28, 1.5), "over", "over")
end)
test("StatStatus_exact", function()
    assertEqual(MetaMirror:StatStatus(22, 22, 1.5), "on", "exact")
end)
test("StatStatus_nil_unknown", function()
    assertEqual(MetaMirror:StatStatus(nil, 34, 1.5), "unknown", "nil -> unknown")
end)
test("StatStatus_secretlike_unknown", function()
    -- Wert, der bei Arithmetik/Vergleich wirft (simuliert einen secret value)
    local secretlike = setmetatable({}, {
        __sub = function() error("secret") end,
        __lt  = function() error("secret") end,
        __le  = function() error("secret") end,
    })
    assertEqual(MetaMirror:StatStatus(secretlike, 34, 1.5), "unknown", "secret -> unknown")
end)
test("DataFor_present", function()
    local d = MetaMirror:DataFor(1, 71, "mythicplus")
    assertEqual(d ~= nil, true, "arms mplus present")
    assertEqual(d.stats[1].key, "haste", "first stat")
end)
test("DataFor_missing", function()
    assertEqual(MetaMirror:DataFor(1, 71, "pvp"), nil, "no pvp content")
    assertEqual(MetaMirror:DataFor(99, 99, "raid"), nil, "unknown spec")
end)
