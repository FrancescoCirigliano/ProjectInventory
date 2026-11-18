-- Generic tooltip unit tests (P3.4, D-145): RSK.Tooltip.Logic. Scenario T-32 (docs/Test.md).
local L = RSK.Tooltip.Logic

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

local ctx = { bad = { r = 0.9, g = 0.2, b = 0.2 }, good = { r = 0.2, g = 0.8, b = 0.3 } }

test("T-32a", "tooltip: fondo bg, cornice line, colori di una mod invariati", function()
    eq(L.rect(0.7, 0.05, 0.05, 0.05), "bg"); eq(L.rect(0.3, 0, 0, 0), nil)
    eq(L.border(0.5, 0.9, 0.9, 1), "line"); eq(L.border(1, 0.4, 0.4, 0.4), nil)
end)
test("T-32b", "testi: requisiti ok/danger, avvisi warn, note muted", function()
    eq(L.text(1, 1, 1, ctx), "text")
    eq(L.text(0.9, 0.2, 0.2, ctx), "danger", "colore cattivo del gioco")
    eq(L.text(0.2, 0.8, 0.3, ctx), "ok", "colore buono del gioco")
    eq(L.text(1, 0, 0, ctx), "danger", "<RED>"); eq(L.text(1, 0.5, 0.5, ctx), "danger")
    eq(L.text(0, 1, 0, ctx), "ok", "<GREEN>")
    eq(L.text(0.9, 0.3, 0, ctx), "warn", "<ORANGE>"); eq(L.text(1, 1, 0, ctx), "warn")
    eq(L.text(0.6, 0.6, 0.6, ctx), "muted"); eq(L.text(0.2, 0.2, 0.2, ctx), nil)
    eq(L.text(0, 0.635, 0.91, ctx), nil, "tasto in blu: invariato")
    eq(L.text(1, 1, 1, nil), "text", "senza contesto")
end)
test("T-32c", "titolo al margine 10, separatore solo con titolo e testo", function()
    eq(L.nameX(8, 5), 10); eq(L.nameX(8, 40), 8); eq(L.nameX(30, 5), 30)
    local x, y, w, h = L.separator(240, 20, true, true)
    eq(x, 10); eq(y, 26); eq(w, 220); eq(h, 1)
    eq(L.separator(240, 20, false, true), nil); eq(L.separator(240, 20, true, false), nil)
    eq(L.separator(15, 20, true, true), nil, "troppo stretto")
end)

return results
