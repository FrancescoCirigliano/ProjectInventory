-- Context menu unit tests (P3.3, D-144): RSK.Menu.Logic. Scenario T-29 (docs/Test.md).
local L = RSK.Menu.Logic

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

-- the vanilla ISContextMenu colours (ISContextMenu:new) and the core's bad/good colours
local ctx = { bg = { r = 0.1, g = 0.1, b = 0.1, a = 0.7 }, border = { r = 1, g = 1, b = 1, a = 0.15 },
    bad = { r = 0.9, g = 0.2, b = 0.2 }, good = { r = 0.2, g = 0.8, b = 0.3 } }

test("T-29a", "rettangoli: fondo, colonna icone, riga sotto il mouse, scorrimento, niente separatore, lampeggio", function()
    eq(L.rect(0.7, 0.1, 0.1, 0.1, ctx), "panel")
    eq(L.rect(0.25, 0.1, 0.1, 0.1, ctx), "bg")
    eq(L.rect(0.8, 0.5, 0.5, 0.5, ctx), "sel")
    eq(L.rect(0.1, 0.05, 0.05, 0.05, ctx), "sel", "disabilitata sotto il mouse")
    eq(L.rect(0.8, 0.1, 0.1, 0.1, ctx), "panel2")
    local st, sa = L.rect(0.15, 1, 1, 1, ctx)
    eq(st, "line"); eq(sa, 0, "separatore delle voci predefinite nascosto (D-145)")
    local tok, a = L.rect(0.6, 1, 1, 1, ctx)
    eq(tok, "accent"); eq(math.abs(a - 0.21) < 1e-6, true, "lampeggio attenuato")
    eq(L.rect(1, 0.3, 0.6, 0.9, ctx), nil, "colore di una mod: invariato")
end)
test("T-29b", "bordi e testi: riga sotto il mouse, cornice, non disponibile, buona, disabilitata, normale", function()
    eq(L.border(0.15, 0.9, 0.9, 1, ctx), "accent"); eq(L.border(0.15, 1, 1, 1, ctx), "line")
    eq(L.border(1, 0, 1, 0, ctx), nil)
    eq(L.text(0.9, 0.2, 0.2, 0.85, ctx), "danger"); eq(L.text(0.2, 0.8, 0.3, 0.85, ctx), "ok")
    eq(L.text(0.5, 0.5, 0.5, 0.85, ctx), "muted"); eq(L.text(1, 1, 1, 1, ctx), "text")
    eq(L.text(1, 0.8, 0.8, 0.9, ctx), "text"); eq(L.text(0.1, 0.9, 0.9, 1, ctx), nil)
    eq(L.text(1, 1, 1, 1, nil), "text", "senza contesto")
end)
test("T-29c", "texture: spunta e frecce a tema, icone invariate", function()
    eq(L.texture("tick"), "ok"); eq(L.texture("arrow"), "text"); eq(L.texture(nil), nil)
end)
test("T-29d", "geometria D-145: riga 30, colonna 28, icona 20 centrata, testo a 36", function()
    eq(L.rowHeight(16), 30, "font 16"); eq(L.rowHeight(26), 34, "font alto: riga piu alta")
    eq(L.rowHeight(16, function(n) return n * 2 end), 60, "scala 2")
    local g = L.geometry(30)
    eq(g.vCol, 22); eq(g.col, 28); eq(g.icon, 20); eq(g.text, 36); eq(g.vText, 24); eq(g.shift, 12)
    local x, y, w, h = L.iconRect(2, 106, 18, 18, g, 30) -- vanilla icon of the row at y 100
    eq(x, 4); eq(y, 105); eq(w, 20); eq(h, 20)
    eq(L.iconRect(40, 106, 18, 18, g, 30), nil, "rettangolo di una mod: invariato")
    eq(L.textX(24, g), 36); eq(L.textX(4, g), 4, "freccia < invariata")
    local big = L.geometry(50) -- vanilla geometry already wider than ours: never narrower
    eq(big.col, 42); eq(big.text, 50); eq(big.shift, 6)
end)

return results
