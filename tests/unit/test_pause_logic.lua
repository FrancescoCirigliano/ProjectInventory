-- Pause menu unit tests (P3.4, D-148): RSK.Pause.Logic. Scenario T-35 (docs/Test.md).
local L = RSK.Pause.Logic

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

test("T-35a", "voci: ordine vanilla, voci di altre mod, nascoste escluse, Esci al desktop a parte", function()
    local items = {
        { internal = "RETURN", text = "Riprendi", y = 0, visible = true },
        { internal = "OPTIONS", text = "Opzioni", y = 52, visible = true },
        { internal = "EXIT", text = "Salva ed esci", y = 120, visible = true },
        { internal = "QUIT_TO_DESKTOP", text = "Esci al desktop", y = 180, visible = true },
        { internal = "MODOPT", text = "Opzioni mod", y = 86, visible = true },  -- added by another mod
        { internal = "SCOREBOARD", text = "Classifica", y = 30, visible = false }, -- MP only
        { internal = nil, text = "Altra mod", y = 120, visible = true },          -- same y: insertion order
    }
    local center, quit = L.entries(items)
    local order = {}
    for i, e in ipairs(center) do order[i] = e.text end
    eq(table.concat(order, ","), "Riprendi,Opzioni,Opzioni mod,Salva ed esci,Altra mod")
    eq(center[1].primary, true, "Riprendi primario"); eq(center[2].primary, false)
    eq(quit.internal, "QUIT_TO_DESKTOP"); eq(quit.idx, 4, "indice della voce vanilla"); eq(quit.item, items[4], "voce vanilla collegata")
    local c2, q2 = L.entries({ { internal = "RETURN", text = "", y = 0, visible = true } })
    eq(#c2, 0, "testo vuoto escluso"); eq(q2, nil)
    eq(L.enabled("EXIT", true), false); eq(L.enabled("QUIT_TO_DESKTOP", true), false)
    eq(L.enabled("RETURN", true), true); eq(L.enabled("EXIT", false), true)
end)

test("T-35b", "barra: pulsanti centrati tra versione ed Esci, riduzione del margine e del testo", function()
    local g = L.GEO
    local b = L.bar(1920, { 80, 70, 120 }, true)
    eq(b.left, g.barPad + g.verW + g.barGap); eq(b.right, 1920 - g.barPad - g.quitW - g.barGap)
    eq(b.pad, g.btnPad); eq(b.clipped, false)
    local first, last = b.buttons[1], b.buttons[3]
    eq(first.w, 80 + 2 * g.btnPad); eq(b.buttons[2].x, first.x + first.w + g.btnGap)
    local mid = (first.x + last.x + last.w) / 2
    assert(math.abs(mid - (b.left + b.right) / 2) <= 1, "centrati: " .. mid)
    -- many mod entries at 1280: smaller padding, then same maximum text width
    local many = {}
    for i = 1, 9 do many[i] = 110 end
    local s = L.bar(1280, many, true)
    eq(s.clipped, true, "testi ridotti"); eq(s.pad, g.btnPadMin)
    local lastB = s.buttons[9]
    assert(s.buttons[1].x >= s.left and lastB.x + lastB.w <= s.right, "dentro la barra")
    local f = L.bar(1280, { 100, 100, 100, 100, 100, 100 }, true)
    eq(f.clipped, false); assert(f.pad < g.btnPad, "margine ridotto: " .. f.pad)
    eq(#L.bar(1920, {}, true).buttons, 0)
    eq(L.bar(1920, { 80 }, true, 230).left, g.barPad + 230 + g.barGap, "colonna versione allargata al testo")
    eq(L.bar(1920, { 80 }, true, 60).left, b.left, "minimo 140")
end)

test("T-35c", "card: sopravvissuto, data di gioco, citta', dissolvenza 150 ms", function()
    eq(L.survivedText(318, "{1}g {2}h"), "13g 6h"); eq(L.survivedText(5.9), "0d 5h"); eq(L.survivedText(nil), "0d 0h")
    eq(L.dateText(14, "Luglio", 13.34, "{1} {2}, {3}", true), "14 luglio, 13:20")
    eq(L.dateText(3, "July", 7.0, "{2} {1}, {3}", false), "July 3, 07:00")
    eq(L.cityText("Muldraugh, KY"), "Muldraugh"); eq(L.cityText("Riverside, KY;Rosewood, KY"), "Riverside")
    eq(L.cityText(nil), "")
    eq(L.fade(0), 0); eq(L.fade(75), 0.5); eq(L.fade(150), 1); eq(L.fade(400), 1)
end)

test("T-35d", "pannello Mod: stati come il vanilla, conteggio errori, posizione sopra il pulsante, scorrimento", function()
    local rows, errs = L.modRows({
        { id = "ProjectInventory", name = "Project Inventory", found = true, available = true },
        { id = "NewMusic", name = "NewMusic", found = true, available = true, bugged = true },
        { id = "OldMap", found = false },
        { id = "Locked", name = "Locked mod", found = true, available = false },
    })
    eq(#rows, 4); eq(errs, 1)
    eq(rows[1].state, "ok"); eq(rows[1].name, "Project Inventory"); eq(rows[1].n, 1)
    eq(rows[2].state, "errors"); eq(rows[3].state, "missing"); eq(rows[3].name, "OldMap", "id se non trovata")
    eq(rows[4].state, "unavailable")
    local M = L.MODS
    local x, y, w, h, scroll = L.modPanel(1200, 90, 1920, 980, 6)
    eq(w, M.w); eq(x, 1290 - M.w, "bordo destro sul pulsante"); eq(h, M.head + 6 * M.row); eq(y, 980 - M.gap - h); eq(scroll, 0)
    x, y, w, h, scroll = L.modPanel(1850, 90, 1920, 980, 40)
    eq(x, 1920 - M.w, "dentro lo schermo"); eq(h, M.maxH); eq(scroll, 40 * M.row - (M.maxH - M.head))
end)

test("T-35e", "ingresso e uscita: dissolvenza, barra dal basso, colonna da sinistra, uscita piu' rapida", function()
    local M = L.MOTION
    local a, dy, dx, done = L.motion(0)
    eq(a, 0); eq(dy, M.barDy); eq(dx, -M.leftDx); eq(done, false)
    a, dy, dx = L.motion(M.inMs); eq(a, 1); eq(dy, 0); eq(dx, 0)
    a = L.motion(M.inMs / 2); assert(a > 0.5 and a < 1, "ease out a meta': " .. a)
    a, dy, dx, done = L.motion(nil, 0); eq(a, 1); eq(dy, 0); eq(done, false)
    a = L.motion(nil, M.outMs / 2); assert(a > 0.5 and a < 1, "ease in a meta': " .. a)
    a, dy, dx, done = L.motion(nil, M.outMs); eq(a, 0); eq(done, true); eq(dy, M.barDy)
    assert(M.outMs < M.inMs, "uscita piu' rapida")
end)

test("T-35f", "conferma Torna al desktop: riquadro centrato, pulsanti in basso a destra, movimento", function()
    local C = L.CONFIRM
    local b = L.confirmBox(1920, 1080, 60, 120, 30)
    eq(b.w, C.w); eq(b.x, (1920 - C.w) / 2); eq(b.y, math.floor((1080 - b.h) / 2))
    eq(b.ok.x + b.ok.w, b.x + b.w - C.pad, "Torna al desktop a destra"); eq(b.ok.w, 120 + 2 * C.btnPad + 30)
    eq(b.cancel.x + b.cancel.w + C.btnSpace, b.ok.x, "Annulla a sinistra")
    assert(b.cancel.x >= b.x + C.pad, "dentro il riquadro"); assert(b.hintY + C.hintH <= b.y + b.h, "nota dentro")
    local a, dy, done = L.confirmMotion(0); eq(a, 0); eq(dy, C.dy); eq(done, false)
    a, dy = L.confirmMotion(C.inMs); eq(a, 1); eq(dy, 0)
    a, dy, done = L.confirmMotion(nil, C.outMs); eq(a, 0); eq(done, true)
end)

return results
