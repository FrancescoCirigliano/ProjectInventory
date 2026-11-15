-- Settings window unit tests (P2.5, D-125): RSK.Settings.Logic. Scenario T-24 (docs/Test.md).
local L = RSK.Settings.Logic

local results = { pass = 0, fail = 0, lines = {} }
local function test(id, name, fn)
    local ok, err = pcall(fn)
    if ok then
        results.pass = results.pass + 1
        results.lines[#results.lines + 1] = "PASS " .. id .. " " .. name
    else
        results.fail = results.fail + 1
        results.lines[#results.lines + 1] = "FAIL " .. id .. " " .. name .. ": " .. tostring(err)
    end
end
local function eq(a, b, msg)
    if a ~= b then error((msg or "valore") .. ": atteso " .. tostring(b) .. ", ottenuto " .. tostring(a), 2) end
end

test("T-24a", "stato del modulo: attivo, spento, in errore, requisito mancante", function()
    local active = { Inventory = true, UI = true }
    local function isActive(id) return active[id] == true end
    eq(L.moduleStatus("on", { "Inventory" }, isActive), "on")
    eq(L.moduleStatus("disabled", { "Inventory" }, isActive), "off")
    eq(L.moduleStatus("failed", {}, isActive), "failed")
    active.Inventory = false
    local st, miss = L.moduleStatus("blocked", { "UI", "Inventory" }, isActive)
    eq(st, "requires"); eq(#miss, 1); eq(miss[1], "Inventory")
    eq(L.moduleStatus("disabled", { "Inventory" }, isActive), "off", "spento dall'utente: niente requisiti")
end)
test("T-24b", "ripristino: chiavi interne escluse, ordine conservato", function()
    local k = L.resetKeys({ "theme.preset", "equipment.layoutSaved", "ui.scale", "module.Search" })
    eq(#k, 3); eq(k[1], "theme.preset"); eq(k[2], "ui.scale"); eq(k[3], "module.Search")
end)
test("T-24c", "ripristino in due clic entro 3 s", function()
    eq(L.confirmed(nil, 1000), false); eq(L.confirmed(1000, 3999), true); eq(L.confirmed(1000, 4001), false)
end)

return results
