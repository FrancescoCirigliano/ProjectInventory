-- RSK.TransferRules unit tests (D-39). Scenarios T-01...T-07 (see docs/Test.md).
local M = require("mocks")
local R = RSK.TransferRules

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

local function many(factory, n, into)
    local list = {}
    for i = 1, n do list[i] = into:add(factory()) end
    return list
end

local function reasons(plan)
    local s = {}
    for _, r in ipairs(plan.refused) do s[#s + 1] = r.reason end
    return table.concat(s, ",")
end

-- ------------------------------------------------------------------ T-01
test("T-01a", "inventario -> borsa annidata a 2 livelli", function()
    local p = M.player()
    local bag = p:getInventory():add(M.real.Schoolbag())
    local kit = bag:getInventory():add(M.real.FirstAidKit())
    local b = p:getInventory():add(M.real.Bandage())
    local plan = R.plan(p, { b }, kit:getInventory())
    eq(#plan.accepted, 1, "accettati")
end)

test("T-01b", "inventario -> borsa annidata a 3 livelli", function()
    local p = M.player()
    local a = p:getInventory():add(M.real.Schoolbag())
    local b = a:getInventory():add(M.real.Schoolbag())
    local kit = b:getInventory():add(M.real.FirstAidKit())
    local x = p:getInventory():add(M.real.Bandage())
    eq(#R.plan(p, { x }, kit:getInventory()).accepted, 1, "accettati")
end)

-- ------------------------------------------------------------------ T-02
test("T-02a", "il kit esterno (4) ferma quello interno", function()
    local p = M.player()
    local outer = p:getInventory():add(M.real.FirstAidKit())
    local inner = outer:getInventory():add(M.real.FirstAidKit())
    many(M.real.Bandage, 29, inner:getInventory())          -- outer: 1.0 + 2.9 = 3.9
    local src = many(M.real.Bandage, 2, p:getInventory())
    local plan = R.plan(p, src, inner:getInventory())
    eq(#plan.accepted, 1, "accettati")
    eq(reasons(plan), "noRoom", "motivi")
    eq(plan.refused[1].container, outer:getInventory(), "contenitore pieno")
end)

test("T-02b", "kit annidato in inventario PG: limite solo del kit", function()
    local p = M.player()
    local kit = p:getInventory():add(M.real.FirstAidKit())
    many(M.real.Bandage, 39, kit:getInventory())             -- 3.9 / 4
    local src = many(M.real.Bandage, 2, p:getInventory())
    local plan = R.plan(p, src, kit:getInventory())
    eq(#plan.accepted, 1, "accettati")
    eq(plan.refused[1].container, kit:getInventory(), "contenitore pieno")
end)

-- ------------------------------------------------------------------ T-03
test("T-03a", "MaxItemSize: rottame di metallo nel kit da cucito", function()
    local p = M.player()
    local sew = p:getInventory():add(M.real.SewingKit())
    local s = p:getInventory():add(M.real.ScrapMetal())
    eq(reasons(R.plan(p, { s }, sew:getInventory())), "tooBig", "motivo")
end)

test("T-03b", "MaxItemSize: kit pieno troppo grande, kit vuoto entra", function()
    local p = M.player()
    local dest = p:getInventory():add(M.real.FirstAidKit())
    local empty = p:getInventory():add(M.real.FirstAidKit())   -- 1.0 = threshold: fits
    local full = p:getInventory():add(M.real.FirstAidKit())
    full:getInventory():add(M.real.Bandage())                  -- 1.1 > 1.0
    local plan = R.plan(p, { empty, full }, dest:getInventory())
    eq(#plan.accepted, 1, "accettati")
    eq(plan.accepted[1], empty, "accettato")
    eq(reasons(plan), "tooBig", "motivo")
end)

test("T-03c", "oggetto leggero nel kit da cucito", function()
    local p = M.player()
    local sew = p:getInventory():add(M.real.SewingKit())
    local b = p:getInventory():add(M.real.Bandage())
    eq(#R.plan(p, { b }, sew:getInventory()).accepted, 1, "accettati")
end)

-- ------------------------------------------------------------------ T-04
test("T-04a", "multiplo: si accoda solo cio' che entra, nessuno perso", function()
    local p = M.player()
    local sew = p:getInventory():add(M.real.SewingKit())         -- capacity 2
    local src = many(M.real.Bandage, 25, p:getInventory())
    local plan = R.plan(p, src, sew:getInventory())
    eq(#plan.accepted, 20, "accettati")
    eq(#plan.refused, 5, "rifiutati")
    eq(#plan.accepted + #plan.refused, #src, "conservazione")
end)

test("T-04b", "spostamento dentro la stessa catena (esterno pieno)", function()
    local p = M.player()
    local outer = p:getInventory():add(M.real.FirstAidKit())
    local inner = outer:getInventory():add(M.real.FirstAidKit())
    many(M.real.Bandage, 20, inner:getInventory())              -- inner 3.0
    local loose = many(M.real.Bandage, 10, outer:getInventory()) -- outer 4.0 / 4
    local five = { loose[1], loose[2], loose[3], loose[4], loose[5] }
    eq(#R.plan(p, five, inner:getInventory()).accepted, 5, "accettati")
end)

-- ------------------------------------------------------------------ T-05
test("T-05a", "stesso contenitore e contenitore dentro se stesso", function()
    local p = M.player()
    local bag = p:getInventory():add(M.real.Schoolbag())
    local innerBag = bag:getInventory():add(M.real.Schoolbag())
    local b = bag:getInventory():add(M.real.Bandage())
    eq(reasons(R.plan(p, { b, bag }, bag:getInventory())), "same,inside", "motivi")
    eq(reasons(R.plan(p, { bag }, innerBag:getInventory())), "inside", "motivi annidato")
end)

test("T-05b", "preferito: vietato verso il mondo, ammesso nelle borse del PG", function()
    local p = M.player()
    local crate = M.container({ type = "crate", capacity = 50 })
    local bag = p:getInventory():add(M.real.Schoolbag())
    local fav = p:getInventory():add(M.item({ name = "fav", weight = 0.2, favorite = true }))
    eq(reasons(R.plan(p, { fav }, crate)), "favorite", "verso il mondo")
    eq(#R.plan(p, { fav }, bag:getInventory()).accepted, 1, "verso borsa del PG")
end)

test("T-05c", "AcceptItemFunction: portachiavi", function()
    local p = M.player()
    local ring = p:getInventory():add(M.real.KeyRing())
    local s = p:getInventory():add(M.real.ScrapMetal())
    local k = p:getInventory():add(M.real.Key())
    local plan = R.plan(p, { s, k }, ring:getInventory())
    eq(reasons(plan), "notAllowed", "motivo")
    eq(plan.accepted[1], k, "chiave accettata")
end)

test("T-05d", "firstShown ignora i motivi non mostrati", function()
    local p = M.player()
    local sew = p:getInventory():add(M.real.SewingKit())
    local inside = sew:getInventory():add(M.real.Bandage())
    local s = p:getInventory():add(M.real.ScrapMetal())
    local plan = R.plan(p, { inside, s }, sew:getInventory())
    eq(R.firstShown(plan.refused).reason, "tooBig", "primo mostrato")
end)

-- ------------------------------------------------------------------ T-06
test("T-06a", "inventario PG pieno: non si prende dal mondo", function()
    local p = M.player({ capacity = 12 })
    many(M.real.ScrapMetal, 12, p:getInventory())
    local crate = M.container({ type = "crate", capacity = 50 })
    local s = crate:add(M.real.ScrapMetal())
    local plan = R.plan(p, { s }, p:getInventory())
    eq(reasons(plan), "noRoom", "motivo")
    eq(plan.refused[1].container, p:getInventory(), "contenitore pieno")
end)

test("T-06d", "inventario PG oltre capienza (D-32): borsa non indossata nell'inventario accetta", function()
    local p = M.player({ capacity = 12 })
    many(M.real.ScrapMetal, 14, p:getInventory())
    local bag = p:getInventory():add(M.real.Schoolbag())
    local crate = M.container({ type = "crate", capacity = 50 })
    local b = crate:add(M.real.Bandage())
    eq(#R.plan(p, { b }, bag:getInventory()).accepted, 1, "accettati")
end)

test("T-06e", "zaino indossato: limite dell'inventario PG solo per oggetti da fuori", function()
    local p = M.player({ capacity = 12 })
    many(M.real.ScrapMetal, 11, p:getInventory())
    local pack = p:getInventory():add(M.real.Schoolbag()):wornBy(p)   -- inventory 12.0 / 12
    local crate = M.container({ type = "crate", capacity = 50 })
    local fromWorld = crate:add(M.real.Bandage())
    local fromInv = p:getInventory():add(M.real.Bandage())
    local plan = R.plan(p, { fromWorld, fromInv }, pack:getInventory())
    eq(#plan.accepted, 1, "accettati")
    eq(plan.accepted[1], fromInv, "accettato")
    eq(plan.refused[1].container, p:getInventory(), "contenitore pieno")
end)

test("T-06b", "Organizzato: capienza intera max(4*1.3, 5) = 5", function()
    local function run(traits)
        local p = M.player({ traits = traits })
        local crate = M.container({ type = "crate", capacity = 50 })
        local kit = crate:add(M.real.FirstAidKit())
        many(M.real.Bandage, 48, kit:getInventory())             -- 4.8
        local b = p:getInventory():add(M.real.Bandage())
        return #R.plan(p, { b }, kit:getInventory()).accepted
    end
    eq(run({ ORGANIZED = true }), 1, "organizzato")
    eq(run({}), 0, "senza tratto")
end)

test("T-06c", "Disorganizzato: capienza intera floor(4*0.7) = 2", function()
    local p = M.player({ traits = { DISORGANIZED = true } })
    local crate = M.container({ type = "crate", capacity = 50 })
    local kit = crate:add(M.real.FirstAidKit())
    many(M.real.Bandage, 19, kit:getInventory())                 -- 1.9
    local src = many(M.real.Bandage, 2, p:getInventory())
    eq(#R.plan(p, src, kit:getInventory()).accepted, 1, "accettati")
end)

-- ------------------------------------------------------------------ T-07
test("T-07a", "borsa a terra: il pavimento non limita la catena", function()
    local p = M.player()
    local floor = M.container({ type = "floor", capacity = 0 })
    many(M.real.ScrapMetal, 60, floor)
    local bag = floor:add(M.real.Schoolbag())
    local b = p:getInventory():add(M.real.Bandage())
    eq(#R.plan(p, { b }, bag:getInventory()).accepted, 1, "accettati")
end)

test("T-07b", "borsa in un mobile pieno: il mobile limita la borsa", function()
    local p = M.player()
    local crate = M.container({ type = "crate", capacity = 5 })
    local bag = crate:add(M.real.Schoolbag())                     -- 1.0
    many(M.real.ScrapMetal, 4, crate)                               -- mobile 5.0 / 5
    local b = p:getInventory():add(M.real.Bandage())
    local plan = R.plan(p, { b }, bag:getInventory())
    eq(reasons(plan), "noRoom", "motivo")
    eq(plan.refused[1].container, crate, "contenitore pieno")
end)

return results
