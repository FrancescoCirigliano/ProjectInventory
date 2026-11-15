-- Inventory reskin logic unit tests (P2.1): RSK.Inventory.Logic. Scenario T-17 (docs/Test.md).
local IL = RSK.Inventory.Logic

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

test("T-17a", "barra di carico: frazione, colore oltre l'80%, superamento (D-22, D-32)", function()
    local li = IL.loadInfo(6, 12); eq(li.frac, 0.5); eq(li.tok, "accent"); eq(li.load, "6.00"); eq(li.cap, "12.00")
    li = IL.loadInfo(9.6, 12); eq(li.tok, "accent", "80% esatto")
    li = IL.loadInfo(9.7, 12); eq(li.tok, "danger")
    li = IL.loadInfo(20, 12); eq(li.frac, 1, "barra piena"); eq(li.load, "20.00", "il numero resta"); eq(li.tok, "danger")
end)
test("T-17b", "barra di carico: capacita' assente o nulla", function()
    local li = IL.loadInfo(3.456, nil); eq(li.frac, 0); eq(li.cap, nil); eq(li.load, "3.46")
    li = IL.loadInfo(1, 0); eq(li.frac, 0); eq(li.cap, "0.00")
end)
test("T-17c", "colonne dal tema (mockup Inventory)", function()
    local c = IL.columns(RSK.Theme.base)
    eq(c.arrowX, nil); eq(c.iconX, 8); eq(c.column2, 50); eq(c.nameX, 58); eq(c.typeMin, 190)
end)
test("T-17d", "righe: pila, pila singola, oggetto di una pila espansa", function()
    local isItem = function(e) return e.isItem == true end
    local it = { isItem = true }
    local r = IL.rowInfo({ items = { it, it, {}, {} }, count = 4 }, isItem)
    eq(r.sub, false); eq(r.count, 3); eq(r.stack, true); eq(r.item, it)
    r = IL.rowInfo({ items = { it, it }, count = 2 }, isItem); eq(r.count, 1); eq(r.stack, false)
    r = IL.rowInfo(it, isItem); eq(r.sub, true); eq(r.item, it)
end)
test("T-17e", "righe visibili con intestazione e scorrimento Java (<= 0)", function()
    local f, l = IL.visibleRows(0, 552, 32, 52, 2000); eq(f, 1); eq(l, 10)
    f, l = IL.visibleRows(-26, 552, 32, 52, 2000); eq(f, 1); eq(l, 11)
    f, l = IL.visibleRows(-520, 552, 32, 52, 2000); eq(f, 11); eq(l, 20)
    f, l = IL.visibleRows(-52 * 1995, 552, 32, 52, 2000); eq(f, 1996); eq(l, 2000)
    f, l = IL.visibleRows(0, 552, 32, 52, 3); eq(f, 1); eq(l, 3)
    f, l = IL.visibleRows(0, 552, 32, 52, 0); eq(f, 1); eq(l, 0)
end)
test("T-17f", "testi: quantita', peso, linea equipaggiati, spazio del nome", function()
    eq(IL.qtyText(1), nil); eq(IL.qtyText(4), "\195\1514"); eq(IL.weightText(1.2), "1.20")
    eq(IL.equipDivider(true, nil), false); eq(IL.equipDivider(true, true), false); eq(IL.equipDivider(false, true), true)
    eq(IL.nameRoom(200, { qty = 20, badge = 0, status = 14 }, 6), 200 - 26 - 20)
    eq(IL.nameRoom(10, { qty = 20 }, 6), 0)
    eq(IL.nameRoom(200, { qty = 20, state = 40 }, 6), 200 - 26 - 46)
end)
test("T-17g", "gruppi di colore dalle categorie vanilla (D-99)", function()
    eq(IL.groupOf("Food"), "food"); eq(IL.groupOf("Water"), "food"); eq(IL.groupOf("Bandage"), "med")
    eq(IL.groupOf("Weapon"), "weapon"); eq(IL.groupOf("Ammo"), "weapon"); eq(IL.groupOf("ToolWeapon"), "tool")
    eq(IL.groupOf("CookingWeapon"), "food"); eq(IL.groupOf("SportsWeapon"), "leisure"); eq(IL.groupOf("Clothing"), "cloth")
    eq(IL.groupOf("SkillBook"), "read"); eq(IL.groupOf("Bag"), "cont"); eq(IL.groupOf("Junk"), "misc")
    eq(IL.groupOf("Junk", true), "misc", "categoria nota vince"); eq(IL.groupOf(nil), nil); eq(IL.groupOf(nil, true), "cont")
    eq(IL.groupOf("Fishing"), "animal"); eq(IL.groupOf("Raccoon"), "animal"); eq(IL.groupOf("Instrument"), "leisure")
    eq(IL.groupOf("AlarmClock"), "cloth"); eq(IL.groupOf("CategoriaDiUnaMod"), "misc", "D-114"); eq(IL.groupOf("ZedDmg"), nil)
    for _, g in ipairs(IL.GROUP_ORDER) do assert(RSK.Theme.GROUP_HEX[g], "colore per " .. g) end
    local m = IL.mix({ r = 0, g = 0, b = 0 }, { r = 1, g = 0.5, b = 0 }, 0.35)
    eq(m.r, 0.35); eq(m.g, 0.175); eq(m.b, 0)
end)
test("T-17h", "stati tra parentesi: nome vanilla, ordine, extra (D-102)", function()
    local b, w = IL.splitName("Mela (Marcio)"); eq(b, "Mela"); eq(#w, 1); eq(w[1], "Marcio")
    b, w = IL.splitName("Felpa (Bagnato, Sporco)"); eq(b, "Felpa"); eq(#w, 2); eq(w[2], "Sporco")
    b, w = IL.splitName("Martello"); eq(b, "Martello"); eq(#w, 0)
    b, w = IL.splitName("(Strano)"); eq(b, "(Strano)"); eq(#w, 0)
    local known = { Marcio = "rotten", Bagnato = "wet", Fresco = false }
    local k, ex = IL.stateKeys({ frozen = true, broken = true }, { "Marcio", "Fresco", "Sporco" }, known)
    eq(table.concat(k, ","), "broken,rotten,frozen"); eq(#ex, 1); eq(ex[1], "Sporco")
    local S = { broken = "rotto", rotten = "marcio", frozen = "congelato" }
    eq(IL.stateText(k, ex, function(x) return S[x] end), "(rotto, marcio, congelato, sporco)")
    eq(IL.stateText({}, {}, tostring), nil)
end)
test("T-17i", "barra sulla riga: pieno/integro nascosto, colori (D-101)", function()
    eq(IL.rowBar("qty", 1), nil); eq(IL.rowBar("cond", 1), nil); eq(IL.rowBar(nil, 0.5), nil)
    local f, t = IL.rowBar("qty", 0.6); eq(f, 0.6); eq(t, "muted")
    f, t = IL.rowBar("cond", 0.12); eq(t, "danger"); f, t = IL.rowBar("cond", 0.45); eq(t, "accent")
    f, t = IL.rowBar("cond", 0.7); eq(t, "ok"); f, t = IL.rowBar("danger", 1.4); eq(f, 1); eq(t, "danger")
    f, t = IL.rowBar("cond", 1, true); eq(f, 1, "armi integre: sempre (D-115)"); eq(t, "ok")
end)
test("T-17j", "gruppo Equipaggiati: unione in fondo con formato vanilla (D-103)", function()
    local a, b1, b2, c = {}, {}, {}, {}
    local list = {
        { items = { a, a }, count = 2, weight = 1, name = "A" },
        { items = { b1, b1 }, count = 2, weight = 0.7, equipped = true, name = "equipped:F" },
        { items = { c, c }, count = 2, weight = 2, name = "C" },
        { items = { b2, b2 }, count = 2, weight = 1.5, equipped = true, name = "equipped:M" },
    }
    local g = IL.mergeEquipped(list, "rsk:equipped")
    eq(#list, 3); eq(list[1].name, "A"); eq(list[2].name, "C"); eq(list[3], g)
    eq(#g.items, 3); eq(g.items[1], b1); eq(g.items[2], b1); eq(g.items[3], b2)
    eq(g.count, 3); eq(g.weight, 2.2); eq(g.equipped, true); eq(g.name, "rsk:equipped")
    local l2 = { { items = { a, a }, count = 2, name = "A" } }
    eq(IL.mergeEquipped(l2, "x"), nil); eq(#l2, 1)
end)
test("T-17k", "dimensione icone: misure per Piccole/Medie/Grandi, colonne (D-125)", function()
    local base = RSK.Theme.base
    local m = IL.rowDims(base, "medium")
    eq(m.row, 52); eq(m.item, 42); eq(m.iconInner, 32); eq(m.cardL, 42); eq(m.cardIcon, 32); eq(m.cardInner, 21); eq(m.badge, 12)
    local s = IL.rowDims(base, "small"); eq(s.row, 40); eq(s.item, 32); eq(s.iconInner, 24); eq(s.cardL, 32); eq(s.cardInner, 16)
    local l = IL.rowDims(base, "large"); eq(l.row, 64); eq(l.item, 52); eq(l.iconInner, 40); eq(l.cardIcon, 40); eq(l.badge, 15)
    eq(IL.rowDims(base, "enorme").id, "medium", "valore sconosciuto")
    eq(IL.columns(base, s).column2, 40); eq(IL.columns(base, l).column2, 60); eq(IL.columns(base).column2, 50)
end)
test("T-17m", "cursore della barra di scorrimento: corsa piena, minimo, estremi", function()
    local y, h = IL.scrollThumb(400, 400, 1600, 0, 24); eq(y, 0); eq(h, 100)
    y, h = IL.scrollThumb(400, 400, 1600, 1, 24); eq(y, 300, "in fondo tocca il bordo"); eq(h, 100)
    y, h = IL.scrollThumb(400, 400, 1600, 0.5, 24); eq(y, 150)
    y, h = IL.scrollThumb(400, 400, 100000, 1, 24); eq(h, 24, "minimo"); eq(y, 376)
    y, h = IL.scrollThumb(400, 400, 300, 0, 24); eq(h, 400, "contenuto piu' corto")
    y, h = IL.scrollThumb(0, 400, 1600, 0, 24); eq(h, 0)
end)
test("T-17l", "equipaggiati nascosti: tolti sul posto, ordine conservato (D-125)", function()
    local list = { { name = "A" }, { name = "E1", equipped = true }, { name = "B" }, { name = "E2", equipped = true } }
    eq(IL.dropEquipped(list), 2); eq(#list, 2); eq(list[1].name, "A"); eq(list[2].name, "B")
    eq(IL.dropEquipped(list), 0, "gia' tolti"); eq(#list, 2)
end)

return results
