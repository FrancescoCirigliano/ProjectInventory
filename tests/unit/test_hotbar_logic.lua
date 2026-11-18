-- Hotbar unit tests (P3.4, D-145): RSK.Hotbar.Logic. Scenario T-32 (docs/Test.md).
local L = RSK.Hotbar.Logic

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
local function same(t, u, msg)
    eq(#t, #u, (msg or "lista") .. " (lunghezza)")
    for i = 1, #u do eq(t[i], u[i], (msg or "lista") .. " [" .. i .. "]") end
end

test("T-32d", "geometria: margine 8, spazio 4, slot 60", function()
    eq(L.slotX(1, 60), 8); eq(L.slotX(2, 60), 72); eq(L.slotX(6, 60), 328)
    local w, h = L.size(6, 60, 60); eq(w, 396, "come l'artboard"); eq(h, 76)
    local w1 = L.size(1, 60, 60); eq(w1, 76)
end)
test("T-32e", "riempimento: arma dalla condizione, borraccia dal contenuto, consumabile dagli usi", function()
    eq(L.fraction({ cond = 7, condMax = 10 }), 0.7, "arma")
    eq(L.fraction({ cond = 10, condMax = 10, fluid = 0.3, fluidCap = 1.2 }), 0.25, "borraccia")
    eq(L.fraction({ cond = 10, condMax = 10, drain = 0.4 }), 0.4, "consumabile")
    eq(L.fraction({ cond = 10, condMax = 10, fluid = 0, fluidCap = 0, drain = 0.5 }), 0.5, "capacita' zero")
    eq(L.fraction({ cond = 12, condMax = 10 }), 1, "oltre il massimo")
    eq(L.fraction({ cond = 3, condMax = 0 }), nil); eq(L.fraction(nil), nil)
    eq(L.condToken(0.6), "ok"); eq(L.condToken(0.59), "accent"); eq(L.condToken(0.3), "accent"); eq(L.condToken(0.29), "danger")
    eq(L.fillHeight(0.5, 60), 30); eq(L.fillHeight(0.01, 60), 2, "almeno la linea"); eq(L.fillHeight(0, 60), 0)
    eq(L.label("Ascia", 0.72, "vuoto"), "Ascia · 72%"); eq(L.label("Fondina", nil, "vuoto"), "Fondina · vuoto")
end)
test("T-32f", "riordino: punto di caduta, linea, nuovo ordine, avvio del trascinamento", function()
    eq(L.dropIndex(10, 4, 60), 1, "meta' sinistra del primo"); eq(L.dropIndex(50, 4, 60), 2)
    eq(L.dropIndex(140, 4, 60), 3); eq(L.dropIndex(500, 4, 60), 5, "dopo l'ultimo"); eq(L.dropIndex(-20, 4, 60), 1)
    eq(L.markerX(1, 4, 60), 5); eq(L.markerX(2, 4, 60), 69); eq(L.markerX(5, 4, 60), 261)
    same(L.moveOrder(4, 1, 3), { 2, 1, 3, 4 }, "1 prima del 3")
    same(L.moveOrder(4, 4, 1), { 4, 1, 2, 3 }, "ultimo in testa")
    same(L.moveOrder(4, 2, 5), { 1, 3, 4, 2 }, "in coda")
    eq(L.moveOrder(4, 2, 2), nil, "stessa posizione"); eq(L.moveOrder(4, 2, 3), nil, "subito dopo se stesso")
    eq(L.moveOrder(1, 1, 2), nil, "un solo slot")
    local inv = L.inverse({ 2, 1, 3, 4 }); eq(inv[1], 2); eq(inv[2], 1); eq(inv[4], 4)
    eq(L.startsDrag(7, 0, 3, false), true); eq(L.startsDrag(5, 5, 3, false), false)
    eq(L.startsDrag(20, 0, 3, true), false, "azioni in coda"); eq(L.startsDrag(20, 0, 1, false), false)
end)

return results
