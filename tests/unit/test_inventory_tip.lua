-- Item tooltip model unit tests (P2.1b, RF-1.6, D-17): RSK.Inventory.TipLogic. Scenario T-18.
local TL = RSK.Inventory.TipLogic

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

-- Fake item: every field v becomes the method m() -> v; functions stay methods.
local function obj(t)
    local o = {}
    for k, v in pairs(t) do
        if type(v) == "function" then o[k] = v else o[k] = function() return v end end
    end
    return o
end
local function field(m, label)
    for _, f in ipairs(m.fields) do if f.label == label then return f end end
    return nil
end
local function labels(m)
    local t = {}
    for i, f in ipairs(m.fields) do t[i] = f.label end
    return table.concat(t, ",")
end

test("T-18a", "arma: condizione, affilatezza, danno, portata (mockup)", function()
    local cats = obj({ size = 2 }); cats.get = function(_, i) return ({ [0] = "Improvised", [1] = "SmallBlade" })[i] end
    local knife = obj({ IsWeapon = true, getName = "Coltello da cucina", getDisplayCategory = "Weapon",
        getUnequippedWeight = 0.3, getCondition = 7, getConditionMax = 10, hasSharpness = true,
        getSharpness = 0.35, getMaxSharpness = 1, getMinDamage = 0.6, getMaxDamage = 1.2, getMaxRange = 0.9,
        getCategories = cats })
    local m = TL.build(knife, nil, 0.3)
    eq(m.name, "Coltello da cucina"); eq(m.cat, "Weapon"); eq(m.weaponCat, "SmallBlade"); eq(m.weight, "0.30")
    eq(labels(m), "Condition,Sharpness,Damage,Range")
    local c = field(m, "Condition"); eq(c.val, "7/10"); eq(c.tok, "ok"); eq(c.frac, 0.7)
    local s = field(m, "Sharpness"); eq(s.val, "35%"); eq(s.tok, "accent")
    eq(field(m, "Damage").val, "0.6 \226\128\147 1.2"); eq(field(m, "Range").val, "0.9")
end)
test("T-18b", "arma da fuoco: munizioni; metodi mancanti o in errore -> campo omesso", function()
    local gun = obj({ IsWeapon = true, getName = "Pistola", getCategory = "Weapon", getUnequippedWeight = 1,
        getCondition = 2, getConditionMax = 10, isRanged = true, getCurrentAmmoCount = 5, getMaxAmmo = 15,
        getMinDamage = 1, getMaxDamage = 1 })
    gun.getMaxRange = function() error("java") end
    local m = TL.build(gun, nil, 0)
    eq(labels(m), "Condition,Damage,Ammo"); eq(field(m, "Condition").tok, "danger")
    eq(field(m, "Damage").val, "1.0", "min = max"); eq(field(m, "Ammo").val, "5/15"); eq(m.cat, "Weapon")
    eq(m.weaponCat, nil, "getCategories assente (B42): sottotipo omesso")
    local cats = obj({ size = 1 }); cats.get = function() return "Pistol" end
    gun.getScriptItem = function() return obj({ getCategories = cats }) end
    eq(TL.build(gun, nil, 0).weaponCat, "Pistol", "tipo dallo script")
    local called = false
    eq(TL.get(setmetatable({}, { __index = function(_, k) if k == "x" then called = true end end }), "x"), nil)
    eq(TL.get(nil, "x"), nil, "oggetto nil")
end)
test("T-18c", "cibo: fame, calorie, stato", function()
    local f = obj({ IsFood = true, getName = "Mela", getUnequippedWeight = 0.2, getHungerChange = -0.15,
        getCalories = 95.4, getOffAgeMax = 5, isFresh = false, isRotten = false, isIsCookable = false, isFrozen = true })
    local m = TL.build(f, nil, 0)
    eq(labels(m), "Hunger,Calories,State"); eq(field(m, "Hunger").val, "15"); eq(field(m, "Calories").val, "95")
    eq(table.concat(field(m, "State").keys, ","), "Stale,Frozen")
    local nonPer = obj({ getOffAgeMax = 1000000000, isFresh = true, isIsCookable = true, isCooked = true })
    eq(table.concat(TL.foodState(nonPer), ","), "Cooked", "non deperibile: niente fresco")
    eq(table.concat(TL.foodState(obj({ isRotten = true, isIsCookable = true, isBurnt = true })), ","), "Rotten,Burnt")
end)
test("T-18d", "abbigliamento e consumabile (rimanente nascosto dal tag)", function()
    local c = obj({ IsClothing = true, getCondition = 10, getConditionMax = 10, getBiteDefense = 25.2,
        getScratchDefense = 0, getInsulation = 0.45, getWetness = 0 })
    eq(labels(TL.build(c, nil, 0)), "Condition,Bite,Insulation")
    eq(field(TL.build(c, nil, 0), "Insulation").val, "45", "senza percentuale")
    eq(field(TL.build(c, nil, 0), "Bite").val, "25", "senza percentuale")
    local h = obj({ IsClothing = true, getCondition = 6, getConditionMax = 10, getHolesNumber = 3 })
    eq(labels(TL.build(h, nil, 0)), "Condition,Holes", "buchi (D-124)")
    eq(field(TL.build(h, nil, 0), "Holes").val, "3"); eq(field(TL.build(h, nil, 0), "Holes").tok, "warn")
    local d = obj({ IsDrainable = true, getCurrentUsesFloat = 0.5 })
    d.hasTag = function(_, t) return t == "HIDE" end
    local m = TL.build(d, nil, 0); eq(field(m, "Remaining").val, "50%"); eq(field(m, "Remaining").tok, "accent")
    eq(labels(TL.build(d, nil, 0, { hideTag = "HIDE" })), "", "tag HIDE_REMAINING")
end)
test("T-18e", "borsa, libro, liquido, peso della pila, descrizione", function()
    local inv = obj({ getCapacityWeight = 10.5 })
    local bag = obj({ IsInventoryContainer = true, getCapacity = 12, getInventory = inv, getWeightReduction = 60,
        getUnequippedWeight = 1 })
    local m = TL.build(bag, nil, 3)
    eq(labels(m), "Capacity,WeightRed,StackWeight"); eq(field(m, "Capacity").val, "10.50 / 12.00")
    eq(field(m, "Capacity").tok, "danger", "oltre l'80%"); eq(field(m, "StackWeight").val, "3.00")
    local chr = { getAlreadyReadPages = function(_, t) return t == "Base.Book" and 50 or 0 end }
    local book = obj({ IsLiterature = true, getNumberOfPages = 200, getFullType = "Base.Book",
        getLvlSkillTrained = 3, getMaxLevelTrained = 4, getTooltip = "Tooltip_Book" })
    m = TL.build(book, chr, 0)
    eq(field(m, "Pages").val, "50/200"); eq(field(m, "Levels").val, "3 \226\128\147 4"); eq(m.desc, nil, "descrizione non mostrata (D-71)")
    local fc = obj({ getAmount = 0.5, getCapacity = 1, getPrimaryFluid = obj({ getTranslatedName = "Acqua" }) })
    m = TL.build(obj({ getFluidContainer = fc }), nil, 0)
    eq(field(m, "Fluid").val, "0.50 / 1.00 L"); eq(field(m, "FluidType").val, "Acqua")
    eq(#TL.build(obj({ getName = "Sasso" }), nil, 0).fields, 0, "oggetto semplice: solo intestazione")
end)
test("T-18f", "altezza e posizione", function()
    local mm = { pad = 12, gap = 10, icon = 64, sep = 1, rowH = 18, rowGap = 6 }
    eq(TL.height(mm, 0), 88); eq(TL.height(mm, 2), 88 + 11 + 10 + 42)
    local x, y = TL.place(100, 100, 300, 200, 1920, 1080, 24); eq(x, 124); eq(y, 124)
    x, y = TL.place(1900, 1000, 300, 200, 1920, 1080, 24); eq(x, 1620); eq(y, 794, "sopra il mouse")
end)

test("T-18g", "colonne delle barre: valore sempre intero, barra e poi etichetta si accorciano (D-72)", function()
    local lw, bw, vw = TL.barColumns(250, 8, { 60, 70 }, { 25, 30 }, 84, 32, 40)
    eq(lw, 70); eq(vw, 32, "minimo"); eq(bw, 250 - 70 - 32 - 16)
    lw, bw, vw = TL.barColumns(250, 8, { 120 }, { 90 }, 84, 32, 40)
    eq(lw, 84, "etichetta al massimo"); eq(vw, 90, "valore intero"); eq(bw, 250 - 84 - 90 - 16)
    lw, bw, vw = TL.barColumns(250, 8, { 84 }, { 150 }, 84, 32, 40)
    eq(vw, 150); eq(bw, 40, "barra minima"); eq(lw, 250 - 150 - 40 - 16, "etichetta accorciata")
end)

return results
