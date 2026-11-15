-- Collectibles unit tests (P3.1, D-130, D-138): RSK.Collect.Logic. Scenario T-25 (docs/Test.md).
local L = RSK.Collect.Logic

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

test("T-25a", "chiavi: libri di abilita' per volume, riviste di ricette per tipo, schemi per ricetta", function()
    eq(L.keyOf({ fullType = "Base.BookCarpentry1", skillBook = true }), "book:Base.BookCarpentry1")
    eq(L.keyOf({ fullType = "Base.BookCarpentry2", skillBook = true }), "book:Base.BookCarpentry2")
    eq(L.keyOf({ fullType = "Base.CookingMag1", recipes = 3 }), "recipe:Base.CookingMag1")
    eq(L.keyOf({ fullType = "Base.MetalworkSchematic", mdRecipe = "Make Metal Wall" }), "learn:Make Metal Wall")
end)
test("T-25b", "chiavi: volantini con luoghi, mappe, media per id", function()
    eq(L.keyOf({ fullType = "Base.Flier", printMedia = "Flier_42", printMap = true }), "print:Flier_42")
    eq(L.keyOf({ fullType = "Base.Map", map = true, mapId = "MuldraughMap" }), "map:MuldraughMap")
    eq(L.keyOf({ fullType = "Base.LouisvilleMap1", map = true }), "map:Base.LouisvilleMap1", "senza id: tipo")
    eq(L.keyOf({ fullType = "Base.Disc_Retail", media = true, mediaId = "abc-1" }), "media:abc-1")
    eq(L.keyOf({ fullType = "Base.Disc_Retail", media = true, mediaId = "abc-2" }), "media:abc-2", "stesso tipo, media diverso")
end)
test("T-25c", "esclusi: letture contro noia, giornali, volantini senza luoghi, media vuoti, oggetti comuni", function()
    eq(L.keyOf({ fullType = "Base.Book", recipes = 0 }), nil, "libro con titolo")
    eq(L.keyOf({ fullType = "Base.Newspaper", printMedia = "News_1", printMap = false }), nil, "giornale")
    eq(L.keyOf({ fullType = "Base.Disc_Retail", media = true }), nil, "media senza dati")
    eq(L.keyOf({ fullType = "Base.Disc_Retail", media = true, mediaId = "" }), nil, "id vuoto")
    eq(L.keyOf({ fullType = "Base.Axe" }), nil)
    eq(L.keyOf(nil), nil)
end)
test("T-25d", "archivio: riparato se assente o rotto, trovato una sola volta, conteggio", function()
    local s = L.ensureStore(nil)
    eq(type(s.found), "table"); eq(s.v, L.STORE_VERSION)
    local broken = L.ensureStore({ found = "x", v = 1 })
    eq(type(broken.found), "table")
    eq(L.isFound(s, "book:A"), false)
    eq(L.markFound(s, "book:A"), true); eq(L.markFound(s, "book:A"), false, "seconda volta")
    eq(L.markFound(s, nil), false, "chiave nil")
    eq(L.isFound(s, "book:A"), true); eq(L.isFound(s, nil), false)
    eq(L.count(s), 1)
end)
test("T-25e", "icona: letto vince, poi trovato/non trovato solo sui collezionabili", function()
    eq(L.status("book:A", false, false), "new")
    eq(L.status("book:A", true, false), "found")
    eq(L.status("book:A", true, true), "read")
    eq(L.status("book:A", false, true), "read", "letto dal PG anche se mai trovato")
    eq(L.status(nil, false, true), "read", "lettura comune gia' letta: spunta vanilla")
    eq(L.status(nil, false, false), nil)
end)
test("T-25f", "visita: borse annidate a ogni livello, catena ciclica fermata", function()
    -- containers as tables: { items = {...} }; an item with .inv is a bag
    local deep = { items = { { id = "d1" } } }
    local mid = { items = { { id = "m1" }, { id = "bag2", inv = deep } } }
    local root = { items = { { id = "r1" }, { id = "bag1", inv = mid } } }
    deep.items[2] = { id = "loop", inv = root } -- cycle back to the root
    local seen = {}
    L.walk(root, function(c) return #c.items, function(i) return c.items[i] end end,
        function(it) return it.inv end, function(it) seen[#seen + 1] = it.id end)
    table.sort(seen)
    eq(table.concat(seen, ","), "bag1,bag2,d1,loop,m1,r1")
end)
test("T-25g", "morte del PG: elenco svuotato, conteggio, archivio vuoto o assente", function()
    local s = L.ensureStore(nil)
    L.markFound(s, "book:A"); L.markFound(s, "media:x")
    eq(L.clearFound(s), 2); eq(L.count(s), 0); eq(L.isFound(s, "book:A"), false)
    eq(L.markFound(s, "book:A"), true, "di nuovo trovabile")
    eq(L.clearFound(L.ensureStore(nil)), 0); eq(L.clearFound(nil), 0)
end)

return results
