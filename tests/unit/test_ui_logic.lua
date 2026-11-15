-- Widget logic unit tests (D-46): RSK.UI.Logic. Scenario T-16 (see docs/Test.md).
local L = RSK.UI.Logic

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
local function mono(s) return #s * 10 end   -- fake width: 10 px per character

test("T-16a", "ellipsize: entra, tronca, spazio minimo", function()
    eq(L.ellipsize("abc", 30, mono), "abc")
    eq(L.ellipsize("abcdefgh", 60, mono), "abc...")
    eq(L.ellipsize("abcdefgh", 30, mono), "...")
    eq(L.ellipsize("abcdefgh", 20, mono), "")
end)
test("T-16b", "lista: righe visibili", function()
    local f, l = L.visibleRange(0, 520, 52, 2000); eq(f, 1); eq(l, 10)
    f, l = L.visibleRange(26, 520, 52, 2000); eq(f, 1); eq(l, 11)
    f, l = L.visibleRange(0, 520, 52, 3); eq(f, 1); eq(l, 3)
    f, l = L.visibleRange(0, 520, 52, 0); eq(f, 1); eq(l, 0)
end)
test("T-16c", "lista: riga sotto il mouse e limiti di scorrimento", function()
    eq(L.rowAt(10, 0, 52, 5), 1); eq(L.rowAt(60, 52, 52, 5), 3); eq(L.rowAt(300, 0, 52, 5), nil); eq(L.rowAt(-1, 0, 52, 5), nil)
    eq(L.clampScroll(-5, 1000, 500), 0); eq(L.clampScroll(900, 1000, 500), 500); eq(L.clampScroll(100, 300, 500), 0)
end)
test("T-16d", "lista: scorrimento per mostrare una riga", function()
    eq(L.scrollToRow(1, 100, 520, 52), 0)
    eq(L.scrollToRow(20, 0, 520, 52), 20 * 52 - 520)
    eq(L.scrollToRow(5, 0, 520, 52), 0, "gia' visibile")
end)
test("T-16e", "barra di scorrimento: cursore e inverso", function()
    eq(L.scrollThumb(0, 400, 500), nil, "non serve")
    local y, h = L.scrollThumb(0, 1000, 500, 16); eq(y, 0); eq(h, 250)
    y, h = L.scrollThumb(500, 1000, 500, 16); eq(y, 250)
    eq(L.scrollFromThumb(250, 1000, 500, 250), 500); eq(L.scrollFromThumb(-10, 1000, 500, 250), 0)
    local _, hmin = L.scrollThumb(0, 104000, 500, 24); eq(hmin, 24, "altezza minima")
end)
test("T-16f", "slider: valore, passo, limiti, inverso", function()
    eq(L.sliderValue(50, 100, 0, 100, 1), 50); eq(L.sliderValue(-10, 100, 0, 100, 1), 0); eq(L.sliderValue(150, 100, 0, 100, 1), 100)
    eq(L.sliderValue(33, 100, 0.5, 2, 0.05), 1); eq(L.sliderValue(10, 100, 0, 1, 0.1), 0.1, "niente 0.1000001")
    eq(L.sliderPos(1.25, 200, 0.5, 2), 100); eq(L.sliderPos(5, 200, 5, 5), 0)
end)
test("T-16g", "colori delle barre (Stile_UI, D-32)", function()
    eq(L.barToken("cond", 0.6), "ok"); eq(L.barToken("cond", 0.59), "accent"); eq(L.barToken("cond", 0.3), "accent")
    eq(L.barToken("cond", 0.29), "danger"); eq(L.barToken("load", 0.8), "accent"); eq(L.barToken("load", 0.81), "danger")
    eq(L.barToken(nil, 1), "accent")
end)
test("T-16i", "schede scorrevoli: attiva visibile con un pezzo della successiva (D-86)", function()
    local rects = { { x = 0, w = 100 }, { x = 100, w = 100 }, { x = 200, w = 100 }, { x = 300, w = 100 } }
    eq(L.tabScroll(rects, 1, 500, 0, 20), 0, "tutte in vista")
    eq(L.tabScroll(rects, 1, 250, 0, 20), 0, "prima")
    eq(L.tabScroll(rects, 3, 250, 0, 20), 70, "terza con il pezzo della quarta")
    eq(L.tabScroll(rects, 4, 250, 0, 20), 150, "ultima: fine corsa, mai fuori")
    eq(L.tabScroll(rects, 1, 250, 150, 20), 0, "ritorno alla prima")
    eq(L.tabScroll(rects, 2, 250, 150, 20), 80, "seconda con il pezzo della prima")
    eq(L.tabScroll(rects, nil, 250, 999, 0), 150, "rotella: limite destro")
    eq(L.tabScroll(rects, nil, 250, -5, 0), 0, "rotella: limite sinistro")
    eq(L.tabScroll({}, 1, 250, 40, 20), 0, "nessuna scheda")
end)

test("T-16h", "font di ripiego e doppio clic", function()
    eq(L.uiFontFor(13), "Small"); eq(L.uiFontFor(17), "Medium"); eq(L.uiFontFor(21), "Large")
    eq(L.isDoubleClick(nil, 1, 100), false); eq(L.isDoubleClick({ target = 1, time = 0 }, 1, 300), true)
    eq(L.isDoubleClick({ target = 1, time = 0 }, 2, 300), false); eq(L.isDoubleClick({ target = 1, time = 0 }, 1, 500), false)
end)

return results
