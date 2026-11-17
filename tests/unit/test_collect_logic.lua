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
test("T-25h", "mod: register, chiave mod:<id>:, sostituzione, prima corrispondenza", function()
    local saved = L.providers
    L.providers = {}
    eq(RSK.Collect.register({ id = "A", match = function(_, ft) return ft == "A.x" and "x" or nil end }), true)
    eq(L.register({ id = "", match = function() end }), false, "id vuoto")
    eq(L.register({ id = "B" }), false, "senza match")
    L.register({ id = "B", match = function(_, ft) return "b-" .. ft end })
    eq(L.modKey(nil, "A.x"), "mod:A:x")
    eq(L.modKey(nil, "Z.z"), "mod:B:b-Z.z", "il secondo risponde")
    L.register({ id = "A", match = function() return nil end })
    eq(#L.providers, 2, "stesso id sostituito")
    eq(L.modKey(nil, "A.x"), "mod:B:b-A.x")
    L.providers = saved
end)
test("T-25i", "mod: fornitore in errore tolto e segnalato, gli altri continuano", function()
    local saved = L.providers
    L.providers = {}
    L.register({ id = "Bad", match = function() error("boom") end })
    L.register({ id = "Ok", match = function() return "k" end })
    local told
    eq(L.modKey(nil, "X.y", function(id) told = id end), "mod:Ok:k")
    eq(told, "Bad"); eq(#L.providers, 1)
    L.providers = saved
end)
test("T-25j", "file dati: elenco = un collezionabile per tipo, mappa = gruppi; voci non valide ignorate", function()
    local saved = L.providers
    L.providers = {}
    eq(L.loadData({ { id = "L", items = { "M.a", "M.b" } }, { id = "G", items = { ["M.c1"] = "c", ["M.c2"] = "c" } },
        { id = "", items = {} }, { items = { "M.z" } }, "x" }), 2)
    eq(L.modKey(nil, "M.a"), "mod:L:M.a"); eq(L.modKey(nil, "M.c2"), "mod:G:c")
    eq(L.modKey(nil, "M.c1"), L.modKey(nil, "M.c2"), "stesso gruppo"); eq(L.modKey(nil, "M.z"), nil)
    eq(L.loadData(nil), 0)
    L.providers = saved
end)
test("T-25k", "NewMusic: album da ogni supporto e lato, custodia vuota esclusa, ripiego per lati, vanilla escluso", function()
    local NM = RSK.Collect.NewMusic
    local env = {
        NMNMGreatestHitsAlbum_GreatestHits1 = { module = "NMGreatestHits", id = "GreatestHits1", media = {
            cassette = { items = { a = "GH1CassetteA", b = "GH1CassetteB", containerEmpty = "GH1CaseEmpty", containerFull = "GH1CaseFull" } },
            cd = { items = { full = "GH1CD", containerEmpty = "GH1CDCoverEmpty" } } } },
        NotAnAlbum = { id = "x" }, Num = 3,
    }
    local idx = NM.buildIndex(env)
    local album = "album:NMGreatestHits:GreatestHits1"
    eq(NM.key(idx, "NMGreatestHits.GH1CassetteA"), album); eq(NM.key(idx, "NMGreatestHits.GH1CassetteB"), album)
    eq(NM.key(idx, "NMGreatestHits.GH1CD"), album); eq(NM.key(idx, "NMGreatestHits.GH1CaseFull"), album, "custodia piena")
    eq(NM.key(idx, "NMGreatestHits.GH1CaseEmpty"), nil, "custodia vuota")
    local api = { tracks = function(ft) return ft:find("OST") and { tracks = { 1 } } or nil end,
        canonical = function(ft) return (ft:gsub("B$", "A")) end }
    eq(NM.key(idx, "NewMusic.CassettePZOSTB", api), "media:NewMusic.CassettePZOSTA", "fuori indice: per coppia di lati")
    eq(NM.key(idx, "NewMusic.BoomboxGrey", api), nil, "non e' un media")
    eq(NM.key(idx, "Base.Disc_Retail", api), nil, "vanilla alle regole vanilla")
end)

return results
