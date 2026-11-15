-- M2 logic unit tests (P2.4, D-78, D-81): RSK.Equipment.Logic. Scenario T-22.
local L = RSK.Equipment.Logic

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

-- Every vanilla body location from NPCs/BodyLocations.lua (42.x), without the hidden ones.
local VANILLA = "BELT_EXTRA BELT MASK MASK_EYES MASK_FULL UNDERWEAR_BOTTOM UNDERWEAR_TOP UNDERWEAR UNDERWEAR_EXTRA1 "
    .. "UNDERWEAR_EXTRA2 HAT FULL_HAT EARS EAR_TOP NOSE TORSO1 TORSO1LEGS1 TANK_TOP TSHIRT SHORT_SLEEVE_SHIRT LEFT_WRIST "
    .. "RIGHT_WRIST SHIRT RIGHT_ARM LEFT_ARM NECK NECK_TEXTURE NECKLACE NECKLACE_LONG RIGHT_MIDDLE_FINGER LEFT_MIDDLE_FINGER "
    .. "LEFT_RING_FINGER RIGHT_RING_FINGER HANDS HANDS_LEFT HANDS_RIGHT CALF_LEFT_TEXTURE CALF_RIGHT_TEXTURE SOCKS LEGS1 SHOES "
    .. "CODPIECE SHORTS_SHORT SHORT_PANTS PANTS_SKINNY GAITER_RIGHT GAITER_LEFT PANTS SKIRT DRESS LEGS5 FORE_ARM_LEFT "
    .. "FORE_ARM_RIGHT LONG_SKIRT LONG_DRESS VEST_TEXTURE BODY_COSTUME SPORT_SHOULDERPAD GORGET JERSEY SWEATER SWEATER_HAT "
    .. "PANTS_EXTRA JACKET JACKET_DOWN JACKET_BULKY JACKET_HAT JACKET_HAT_BULKY JACKET_SUIT FULL_SUIT BOILERSUIT FULL_SUIT_HEAD "
    .. "FULL_SUIT_HEAD_SCBA KNEE_LEFT KNEE_RIGHT CALF_LEFT CALF_RIGHT THIGH_LEFT THIGH_RIGHT SPORT_SHOULDERPAD_ON_TOP "
    .. "SHOULDERPAD_RIGHT SHOULDERPAD_LEFT ELBOW_LEFT ELBOW_RIGHT FULL_TOP BATH_ROBE FANNY_PACK_FRONT FANNY_PACK_BACK WEBBING "
    .. "SCBA SCBANOTANK AMMO_STRAP SATCHEL SHOULDER_HOLSTER ANKLE_HOLSTER TORSO_EXTRA TORSO_EXTRA_VEST TORSO_EXTRA_VEST_BULLET "
    .. "CUIRASS TAIL FULL_ROBE BACK LEFT_EYE RIGHT_EYE EYES SCARF"

test("T-22a", "slotFor: formati del nome e casi del mockup", function()
    eq(L.normalize("base:full_hat"), "FULLHAT"); eq(L.normalize("FULL_HAT"), "FULLHAT"); eq(L.normalize("FullHat"), "FULLHAT")
    eq(L.slotFor("base:hat"), "head"); eq(L.slotFor("EYES"), "head", "occhiali in Testa")
    eq(L.slotFor("JACKET"), "torso", "giacca"); eq(L.slotFor("TSHIRT"), "torso", "maglia"); eq(L.slotFor("SWEATER"), "torso", "maglione")
    eq(L.slotFor("FORE_ARM_LEFT"), "arms"); eq(L.slotFor("Hands"), "hands"); eq(L.slotFor("LEFT_WRIST"), "hands", "orologio")
    eq(L.slotFor("PANTS"), "legs"); eq(L.slotFor("BACK"), "back"); eq(L.slotFor("FANNY_PACK_FRONT"), "belt")
    eq(L.slotFor("SOCKS"), "feet", "calze con le scarpe"); eq(L.slotFor("SHOES"), "feet")
    eq(#L.SLOTS_LEFT + #L.SLOTS_RIGHT, 8, "macro aree (D-83)")
end)

test("T-22b", "slotFor: ogni location vanilla ha una voce esplicita", function()
    local known = {}
    for _, group in ipairs({ L.SLOTS_LEFT, L.SLOTS_RIGHT }) do
        for _, id in ipairs(group) do known[id] = true end
    end
    for name in string.gmatch(VANILLA, "%S+") do
        local s = L.MAP[L.normalize(name)]
        if not known[s] then error("nessuna voce esplicita per " .. name .. ": " .. tostring(s)) end
        eq(L.slotFor(name), s, name)
    end
end)

test("T-22c", "slotFor: nascoste, vuote, mod con parole chiave, ripiego Torso", function()
    eq(L.slotFor("BANDAGE"), nil); eq(L.slotFor("WOUND"), nil); eq(L.slotFor("ZED_DMG"), nil)
    eq(L.slotFor("MAKE_UP_LIPS"), nil); eq(L.slotFor(""), nil); eq(L.slotFor(nil), nil)
    eq(L.slotFor("MyMod:LeftBoot"), "feet"); eq(L.slotFor("TacticalGlove"), "hands")
    eq(L.slotFor("ChestArmor"), "torso", "ARMOR prima di ARM"); eq(L.slotFor("Backpack2"), "back")
    eq(L.slotFor("LeftArmGuard"), "arms"); eq(L.slotFor("ModShirt"), "torso")
    eq(L.slotFor("Qualcosa"), "torso", "ripiego")
end)

test("T-22d", "groupWorn, keepIndex, cycle, indexText, condition", function()
    local g = L.groupWorn({ { item = "a", location = "JACKET" }, { item = "b", location = "SWEATER" },
        { item = "c", location = "WOUND" }, { item = "d", location = "SHOES" } })
    eq(#g.torso, 2); eq(g.torso[2], "b"); eq(#g.feet, 1); eq(g.head, nil)
    eq(L.keepIndex({ "a", "b" }, 1, "b"), 2, "stesso oggetto"); eq(L.keepIndex({ "a", "b" }, 5, "z"), 2, "oltre la fine")
    eq(L.keepIndex({}, 3, "a"), 0, "vuoto"); eq(L.keepIndex({ "a" }, 0, nil), 1, "primo")
    eq(L.cycle(1, 3, -1), 3); eq(L.cycle(3, 3, 1), 1); eq(L.cycle(1, 1, 1), 1); eq(L.cycle(0, 0, 1), 0)
    eq(L.indexText(2, 3), "2/3"); eq(L.indexText(0, 0), "0/0")
    eq(L.condition(5, 10), 0.5); eq(L.condition(5, 0), nil); eq(L.condition(nil, 10), nil); eq(L.condition(20, 10), 1)
end)

test("T-22e", "wound: niente da mostrare, dolore e rigidita' esclusi", function()
    eq(L.wound({ doctor = 0 }), nil)
    eq(L.wound({ doctor = 0, pain = 80, stiffness = 50 }), nil)
end)

test("T-22f", "wound: colori del segno e delle etichette (D-81, D-84)", function()
    local w = L.wound({ scratched = true })
    eq(w.tok, "warn"); eq(w.lines[1].key, "IGUI_health_Scratched"); eq(w.lines[1].tok, "warn")
    w = L.wound({ cut = true, bleeding = true })
    eq(w.tok, "danger", "sanguina"); eq(w.lines[1].tok, "warn"); eq(w.lines[2].key, "IGUI_health_Bleeding"); eq(w.lines[2].tok, "danger")
    eq(L.wound({ bitten = true }).tok, "danger"); eq(L.wound({ deep = true }).tok, "danger")
    eq(L.wound({ fractureTime = 30 }).tok, "danger"); eq(L.wound({ burnTime = 5 }).tok, "danger"); eq(L.wound({ glass = true }).tok, "danger")
    w = L.wound({ fractureTime = 30, splint = 2 }); eq(w.tok, "ok", "con stecca: curata"); eq(w.lines[1].key, "IGUI_health_Splinted")
    w = L.wound({ scratched = true, bandaged = true, bandageLife = 1 })
    eq(w.tok, "warn", "ferita lieve bendata"); eq(w.lines[2].key, "IGUI_health_Bandaged"); eq(w.lines[2].tok, "ok")
    eq(L.wound({ bandaged = true, bandageLife = 1 }).tok, "ok", "solo benda pulita")
    w = L.wound({ bandaged = true, bandageLife = 0 }); eq(w.tok, "warn"); eq(w.lines[1].key, "IGUI_health_DirtyBandage")
    eq(L.wound({ stitched = true }).tok, "ok"); eq(L.wound({ plantain = 1 }).lines[1].tok, "ok")
end)

test("T-22g", "wound: benda nasconde come il vanilla, regole sul livello di Medicina", function()
    local w = L.wound({ burnTime = 5, bullet = true, glass = true, infected = true, infectionLevel = 1, bandaged = true, bandageLife = 1 })
    eq(#w.lines, 1); eq(w.lines[1].key, "IGUI_health_Bandaged"); eq(w.tok, "ok")
    eq(L.wound({ infected = true, infectionLevel = 0.1, doctor = 0 }), nil, "infezione non riconosciuta")
    eq(L.wound({ infected = true, infectionLevel = 0.3, doctor = 0 }).lines[1].key, "IGUI_health_Infected")
    eq(L.wound({ infected = true, infectionLevel = 0, doctor = 9 }).tok, "danger", "medico esperto")
    eq(L.wound({ scratched = true, scratchTime = 20, doctor = 2 }).lines[1].qual, nil)
    eq(L.wound({ scratched = true, scratchTime = 20, doctor = 3 }).lines[1].qual, "IGUI_health_Severe")
    eq(L.wound({ deep = true, deepTime = 9, doctor = 5 }).lines[1].qual, "IGUI_health_Moderate")
    eq(L.wound({ stitched = true, stitchTime = 50, doctor = 7 }).lines[1].qual, "IGUI_health_Good")
    eq(L.wound({ stitched = true, stitchTime = 10, doctor = 7 }).lines[1].qual, "IGUI_health_NeedTime")
end)

test("T-22h", "partAt, media, testi, posizione della finestra", function()
    local px, py = L.partPos("Head", 308, 396)
    eq(px, 154, "testa al centro"); eq(math.floor(py + 0.5), 36)
    local lx = L.partPos("Hand_L", 232, 300)
    local rx = L.partPos("Hand_R", 232, 300)
    eq(lx > 116 and rx < 116, true, "sinistra del PG a destra")
    eq(math.floor(lx - rx + 0.5), math.floor(0.38 * (308 / 396) * 300 + 0.5), "scarto dall'altezza, non dalla larghezza")
    eq(L.partPos("Inesistente", 100, 100), nil)
    eq(L.partAt(154, 36, 308, 396, 0.09), "Head"); eq(L.partAt(px, 0.26 * 396, 308, 396, 0.09), "Torso_Upper")
    eq(L.partAt(0, 0, 308, 396, 0.09), nil, "fuori dal corpo")
    eq(L.average({ 10, 20 }), 15); eq(L.average({}), 0)
    eq(L.percentText(17.6), "18%"); eq(L.oneDecimal(1.26), "1.3")
    local x, y = L.place(600, 40, 500, 424, 660, 8, 1920, 1080)
    eq(x, 168, "a sinistra"); eq(y, 40)
    x = L.place(100, 40, 500, 424, 660, 8, 1920, 1080); eq(x, 608, "a destra se a sinistra non c'e' spazio")
    x = L.place(100, 40, 1700, 424, 660, 8, 1920, 1080); eq(x, 0, "nessuno spazio: bordo sinistro")
    x, y = L.place(600, 600, 500, 424, 660, 8, 1920, 1080); eq(y, 420, "bordo inferiore")
end)

test("T-22j", "layout e misure della finestra (D-87, D-88)", function()
    local W = L.WIN
    local a = L.layout(W.W, W.H)
    eq(a.centerH, 399, "riquadro alla misura predefinita")
    eq(a.slotStep >= L.SLOT_H, true, "slot sovrapposti")
    eq(a.weaponX >= a.centerX, true, "armi fuori dal riquadro")
    eq(a.weaponY + L.SLOT_H_WEAPON, a.gridY + a.centerH, "armi in fondo al riquadro")
    eq(a.lookRowY + 44 + 16, a.pageH, "riga capelli in fondo alla pagina")
    local m = L.layout(W.MIN_W, W.MIN_H)
    eq(m.slotStep >= L.SLOT_H, true, "alla misura minima gli slot non si sovrappongono")
    eq(m.weaponX >= m.centerX, true, "alla misura minima le armi stanno nel riquadro")
    eq(m.weaponStep >= 64, true, "alla misura minima le armi non si sovrappongono")
    eq(m.modelH > 0, true)
    local b = L.layout(800, 1000)
    eq(b.centerW > a.centerW and b.centerH > a.centerH, true, "il render cresce")
    eq(b.leftX, a.leftX, "colonna sinistra fissa"); eq(b.rightX, 800 - 16 - 70 + 3, "colonna destra sul bordo")
    eq(a.statsY, a.healthH + 6, "uccisioni e tempo subito sotto la salute")
    eq(a.statsY + a.statsH < a.gridY, true, "uccisioni e tempo sopra il riquadro")
    eq(a.statW * 2 + 6, W.W - 32, "due etichette di pari larghezza")
    local ix, iw, lx, lw = L.defaultLayout(1920, 60, 424, 8, 300, 560)
    eq(ix, 492, "inventario dopo barra e M2"); eq(iw, 560, "massimo"); eq(lx, 1060, "loot accanto"); eq(lw, 560)
    eq(ix - 8 - 424, 60, "M2 tra barra e inventario")
    eq(lx + lw <= 1920, true, "dentro lo schermo a 1080p")
    ix, iw, lx, lw = L.defaultLayout(1280, 60, 424, 8, 300, 560)
    eq(iw, 386, "schermo stretto: si dividono lo spazio"); eq(lx + lw <= 1280, true, "dentro lo schermo a 720p")
    ix, iw = L.defaultLayout(800, 60, 424, 8, 300, 560); eq(iw, 300, "minimo")
    eq(L.layoutDone("", "1920x1080"), false); eq(L.layoutDone(nil, "1920x1080"), false)
    eq(L.layoutMark("", "1920x1080"), "1920x1080")
    local both = L.layoutMark("1920x1080", "2560x1440")
    eq(both, "1920x1080;2560x1440"); eq(L.layoutDone(both, "2560x1440"), true); eq(L.layoutDone(both, "920x1080"), false, "corrispondenza intera")
    eq(L.layoutMark(both, "1920x1080"), both, "nessun duplicato")
    local w, h = L.viewSize(400, 500, nil, nil, false); eq(w, 400); eq(h, 500)
    w, h = L.viewSize(400, 500, 200, 300, false); eq(w, 400, "piccolo: riempie"); eq(h, 500)
    w, h = L.viewSize(400, 500, 600, 800, false); eq(w, 600, "grande: scorre"); eq(h, 800)
    w, h = L.viewSize(400, 500, 300, 800, true); eq(h, 500, "scorrimento proprio")
end)

test("T-22i", "tooltip: animazione, etichette a capo, posizione, larghezza schede", function()
    eq(L.easeOut(-5, 100), 0); eq(L.easeOut(100, 100), 1); eq(L.easeOut(50, 100), 0.75); eq(L.easeOut(10, 0), 1)
    local pos, rows = L.wrapChips({ 100, 100, 100 }, 210, 4)
    eq(rows, 2); eq(pos[1].x, 0); eq(pos[2].x, 104); eq(pos[2].row, 0); eq(pos[3].x, 0); eq(pos[3].row, 1)
    local _, none = L.wrapChips({}, 210, 4); eq(none, 0)
    local one = L.wrapChips({ 500 }, 210, 4); eq(one[1].row, 0, "etichetta piu' larga: resta in prima riga")
    local x, y = L.tipPlace(100, 200, 26, 240, 80, 8, 1920, 1080); eq(x, 134); eq(y, 200)
    x = L.tipPlace(1800, 200, 26, 240, 80, 8, 1920, 1080); eq(x, 1552, "a sinistra del segno")
    x, y = L.tipPlace(100, 1050, 26, 240, 80, 8, 1920, 1080); eq(y, 1000, "dentro lo schermo")
    eq(L.signature({ "1", "2", "-" }), "1,2,-")
end)

test("T-22k", "esercizi: blocchi come il vanilla, durata, regolarita' (D-93)", function()
    eq(L.fitnessBlock({}), nil, "nessun blocco")
    eq(L.fitnessBlock({ endurance = 2, enduranceMax = 2 }), nil, "alla soglia si puo'")
    eq(L.fitnessBlock({ endurance = 3, enduranceMax = 2 }), "Tooltip_TooExhaustedFitness")
    eq(L.fitnessBlock({ heavyLoad = 3 }), "Tooltip_TooHeavyFitness")
    eq(L.fitnessBlock({ sitting = true }), "Tooltip_StandStillFitness")
    eq(L.fitnessBlock({ inVehicle = true }), "Tooltip_CantDriveAndFitness")
    eq(L.fitnessBlock({ pain = 4 }), "Tooltip_TooMuchPainFitness")
    eq(L.fitnessBlock({ missingItem = true }), "IGUI_FitnessNeedItem")
    eq(L.fitnessBlock({ climbing = true }) ~= nil, true, "arrampicata")
    eq(L.fitnessBlock({ heavyLoad = 3, pain = 4 }), "Tooltip_TooMuchPainFitness", "vale l'ultimo")
    eq(L.fitnessTime(10, -1), 10); eq(L.fitnessTime(10, 1), 20); eq(L.fitnessTime(60, 1), 60); eq(L.fitnessTime(60, -1), 50)
    eq(L.regularity(50), 0.5); eq(L.regularity(150), 1); eq(L.regularity(-1), 0); eq(L.regularity(nil), 0)
end)

test("T-22l", "avviso ferite: solo ferite nuove, gravita', animazione e durata (D-117)", function()
    local f = L.injuryFlags({ scratched = true, fractureTime = 0, burnTime = 3 })
    eq(f.scratched, true); eq(f.burn, true); eq(f.fracture, nil); eq(f.bitten, nil)
    local parts = { "Hand_L", "ForeArm_R" }
    local prev = { Hand_L = { scratched = true } }
    local cur = { Hand_L = { scratched = true, bleeding = true }, ForeArm_R = { cut = true } }
    local n = L.newInjuries(prev, cur, parts)
    eq(#n, 2); eq(n[1].part, "Hand_L"); eq(#n[1].lines, 1, "il graffio c'era gia'"); eq(n[1].lines[1].key, "IGUI_health_Bleeding")
    eq(n[1].tok, "danger"); eq(n[2].tok, "warn")
    eq(#L.newInjuries(cur, cur, parts), 0, "nessuna novita'")
    eq(#L.newInjuries(cur, { Hand_L = {} }, parts), 0, "ferite guarite: nessun avviso")
    local A = L.ALERT
    local a, dx, life, done = L.alertState(0)
    eq(a, 0); eq(dx, -A.SLIDE); eq(life, 1); eq(done, false)
    a, dx = L.alertState(A.IN_MS); eq(a, 1); eq(dx, 0)
    a, dx, life, done = L.alertState(A.LIFE_MS + A.OUT_MS / 2); eq(a, 0.5); eq(life, 0); eq(done, false)
    a, dx, life, done = L.alertState(A.LIFE_MS + A.OUT_MS); eq(done, true)
    a, dx, life, done = L.alertState(1000 + A.OUT_MS, 1000); eq(done, true, "chiusa con la X")
end)

test("T-22m", "posizione e misura di M2 salvate: testo, minimi, dentro lo schermo (D-125)", function()
    local L = RSK.Equipment.Logic
    eq(L.geomText(10.4, 20.6, 424, 688), "10,21,424,688")
    local g = L.parseGeom("10,21,424,688"); eq(g.x, 10); eq(g.y, 21); eq(g.w, 424); eq(g.h, 688)
    g = L.parseGeom("-5,0,100,100"); eq(g.x, -5); eq(g.w, 400, "minimo"); eq(g.h, 678)
    eq(L.parseGeom(""), nil); eq(L.parseGeom("a,b,c,d"), nil); eq(L.parseGeom(nil), nil)
    local x, y = L.clampPos(1800, 1070, 424, 1920, 1080, 44); eq(x, 1496); eq(y, 1036)
    x, y = L.clampPos(-30, -5, 424, 1920, 1080, 44); eq(x, 0); eq(y, 0)
end)

return results
