-- Nested container window logic unit tests (P2.2, D-73): RSK.Nested.Logic. Scenario T-19.
local L = RSK.Nested.Logic

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

-- Fake container and item: c.item = item holding it; it.box = container it is in.
local function cont(name, item)
    local c = { name = name, item = item }
    function c:getContainingItem() return self.item end
    return c
end
local function itm(name, box)
    local it = { name = name, box = box }
    function it:getContainer() return self.box end
    function it:getName() return self.name end
    return it
end
local function lbl(c) return c.name end

-- Inventory > Backpack > Bag > Lunchbox
local inv = cont("Inventario")
local pack = itm("Zaino", inv)
local packC = cont("Zaino", pack)
local bag = itm("Borsa", packC)
local bagC = cont("Borsa", bag)
local lunch = itm("Porta-pranzo", bagC)

test("T-19a", "percorso a 3 livelli (RF-3.5)", function()
    eq(L.path(lunch, lbl, " > "), "Inventario > Zaino > Borsa > Porta-pranzo")
end)

test("T-19b", "oggetto senza contenitore (a terra): solo il nome", function()
    eq(L.path(itm("Zaino", nil), lbl, " > "), "Zaino")
end)

test("T-19c", "oggetto piu' esterno della catena", function()
    eq(L.outermost(lunch), pack)
    eq(L.outermost(pack), pack)
end)

test("T-19d", "catena ciclica: si ferma a MAX_DEPTH", function()
    local c = cont("Ciclo")
    local a = itm("A", c)
    c.item = a -- A inside itself
    eq(#L.chain(a), L.MAX_DEPTH, "lunghezza")
    eq(L.outermost(a), a)
end)

test("T-19e", "posizione: centrata, sfalsata, dentro lo schermo", function()
    local x, y = L.place(0, 380, 420, 1920, 1080, 24)
    eq(x, 770); eq(y, 330)
    x, y = L.place(2, 380, 420, 1920, 1080, 24)
    eq(x, 818); eq(y, 378)
    x, y = L.place(40, 380, 420, 1920, 1080, 24)
    eq(x, 1540); eq(y, 660)
    x, y = L.place(0, 2000, 1200, 1920, 1080, 24)
    eq(x, 0); eq(y, 0)
end)

return results
