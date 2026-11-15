-- Search filter unit tests (P2.3, D-74, D-75): RSK.Search.Logic. Scenario T-20.
local L = RSK.Search.Logic

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

-- Fake stack as in vanilla itemslist: count = items + 1.
local function group(name, cat, n) return { name = name, cat = cat, count = n + 1 } end
local function text(e) return e.name, e.cat end
local function sample()
    return { group("Coltello da cucina", "Arma", 2), group("Caff\195\168", "Cibo", 3), group("Benda", "Medicina", 1) }
end

test("T-20a", "fold: maiuscole e accenti", function()
    eq(L.fold("CAFF\195\136"), "caffe", "maiuscola accentata")
    eq(L.fold("Caff\195\168"), "caffe", "minuscola accentata")
    eq(L.fold("\195\161\195\170\195\173\195\180\195\188\195\177\195\167"), "aeiounc", "accenti vari")
    eq(L.fold(nil), "", "nil")
end)

test("T-20b", "terms: parole, spazi, testo vuoto", function()
    eq(#L.terms(""), 0, "vuoto")
    eq(#L.terms("   "), 0, "soli spazi")
    local t = L.terms("  Colt  CUCINA ")
    eq(#t, 2, "due parole")
    eq(t[1], "colt"); eq(t[2], "cucina")
end)

test("T-20c", "matches: nome, categoria, tutte le parole, niente pattern", function()
    eq(L.matches(L.terms("cucina"), "Coltello da cucina", "Arma"), true, "nome")
    eq(L.matches(L.terms("arma"), "Coltello da cucina", "Arma"), true, "categoria")
    eq(L.matches(L.terms("coltello arma"), "Coltello da cucina", "Arma"), true, "nome + categoria")
    eq(L.matches(L.terms("coltello cibo"), "Coltello da cucina", "Arma"), false, "una parola manca")
    eq(L.matches(L.terms("caffe"), "Caff\195\168", "Cibo"), true, "senza accento")
    eq(L.matches(L.terms("%a+"), "Coltello", "Arma"), false, "pattern letterale")
    eq(L.matches({}, "Coltello", "Arma"), true, "nessuna parola")
end)

test("T-20d", "filter: sul posto, ordine, contatore in oggetti", function()
    local list = sample()
    local shown, total = L.filter(list, L.terms("cibo"), text)
    eq(shown, 3, "visibili"); eq(total, 6, "totale")
    eq(#list, 1, "pile rimaste"); eq(list[1].name, "Caff\195\168")
    list = sample()
    shown, total = L.filter(list, L.terms("e"), text)
    eq(shown, 6, "tutte"); eq(#list, 3, "ordine intatto"); eq(list[3].name, "Benda")
end)

test("T-20e", "filter: nessuna parola, nessun risultato, lista vuota", function()
    local list = sample()
    local called = false
    local shown, total = L.filter(list, {}, function() called = true end)
    eq(shown, 6); eq(total, 6); eq(#list, 3); eq(called, false, "testi letti senza filtro")
    list = sample()
    shown, total = L.filter(list, L.terms("zzz"), text)
    eq(shown, 0); eq(total, 6); eq(#list, 0, "pile rimaste"); eq(list[1], nil)
    shown, total = L.filter({}, L.terms("x"), text)
    eq(shown, 0); eq(total, 0)
end)

test("T-20f", "visibleItems: solo chi corrisponde (D-75), lista originale intatta", function()
    local items = { { name = "Benda", cat = "Medicina" }, { name = "Mela", cat = "Cibo" } }
    local out = L.visibleItems(items, L.terms("mela"), text)
    eq(#out, 1); eq(out[1].name, "Mela"); eq(#items, 2, "originale modificata")
end)

return results
