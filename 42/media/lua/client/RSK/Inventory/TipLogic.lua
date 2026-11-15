-- RSK.Inventory.TipLogic - item tooltip model (RF-1.6, D-17, P2.1b) with no engine dependencies
-- (testable, T-18). Reads the item only through protected calls: a method missing in the build or a Java
-- error drops the field instead of breaking the tooltip. Labels are UI_RSK_Tip_<key> keys.
require "RSK/UI/Logic"

RSK = RSK or {}
RSK.Inventory = RSK.Inventory or {}
RSK.Inventory.TipLogic = RSK.Inventory.TipLogic or {}
local TL = RSK.Inventory.TipLogic
local L = RSK.UI.Logic

-- Protected call o:m(...): nil if o is nil, the method is missing or it errors.
-- The method is looked up before calling: Kahlua logs every exception to the console, even inside pcall,
-- so a method missing in the build (e.g. getCategories in B42) must never reach the call.
function TL.get(o, m, ...)
    if o == nil then return nil end
    local okf, f = pcall(function() return o[m] end)
    if not okf or f == nil then return nil end
    local args = { ... }
    local ok, v = pcall(function() return f(o, unpack(args)) end)
    if ok then return v end
    return nil
end
local get = TL.get
local function num(v) return type(v) == "number" and v or nil end

function TL.fmt1(v) return string.format("%.1f", v) end
function TL.fmt2(v) return string.format("%.2f", v) end
function TL.pct(f) return string.format("%d%%", math.floor(f * 100 + 0.5)) end
function TL.range(a, b)
    if math.abs(a - b) < 0.05 then return TL.fmt1(a) end
    return TL.fmt1(a) .. " \226\128\147 " .. TL.fmt1(b) -- "a – b"
end

local function bar(out, label, frac, val, tok)
    frac = L.clamp(frac, 0, 1)
    out[#out + 1] = { kind = "bar", label = label, frac = frac, val = val, tok = tok or L.barToken("cond", frac) }
end
local function kv(out, label, val, keys)
    out[#out + 1] = { kind = "kv", label = label, val = val, keys = keys }
end

local function condition(item, out)
    local c, m = num(get(item, "getCondition")), num(get(item, "getConditionMax"))
    if c and m and m > 0 then bar(out, "Condition", c / m, string.format("%d/%d", c, m)) end
end

local function weapon(item, out)
    condition(item, out)
    if get(item, "hasSharpness") then
        local s, ms = num(get(item, "getSharpness")), num(get(item, "getMaxSharpness"))
        if s then
            local f = (ms and ms > 0) and s / ms or s
            bar(out, "Sharpness", f, TL.pct(L.clamp(f, 0, 1)))
        end
    end
    local a, b = num(get(item, "getMinDamage")), num(get(item, "getMaxDamage"))
    if a and b then kv(out, "Damage", TL.range(a, b)) end
    local r = num(get(item, "getMaxRange"))
    if r then kv(out, "Range", TL.fmt1(r)) end
    if get(item, "isRanged") then
        local n, m = num(get(item, "getCurrentAmmoCount")), num(get(item, "getMaxAmmo"))
        if n and m and m > 0 then kv(out, "Ammo", string.format("%d/%d", n, m)) end
    end
end

local function clothing(item, out)
    condition(item, out)
    -- Holes (D-124): number in yellow, like the marker on the M2 slots (D-122)
    local holes = num(get(item, "getHolesNumber"))
    if holes and holes > 0 then
        kv(out, "Holes", string.format("%d", holes))
        out[#out].tok = "warn"
    end
    local bite, scratch = num(get(item, "getBiteDefense")), num(get(item, "getScratchDefense"))
    -- Protection and insulation: value only, no percentage (insulation 0..1 -> 0..100)
    if bite and bite > 0 then kv(out, "Bite", string.format("%d", math.floor(bite + 0.5))) end
    if scratch and scratch > 0 then kv(out, "Scratch", string.format("%d", math.floor(scratch + 0.5))) end
    local ins = num(get(item, "getInsulation"))
    if ins and ins > 0 then kv(out, "Insulation", string.format("%d", math.floor(ins * 100 + 0.5))) end
    local wet = num(get(item, "getWetness"))
    if wet and wet > 0 then kv(out, "Wetness", string.format("%d%%", math.floor(wet + 0.5))) end
end

-- Food state: rotten / stale / fresh (perishables only), raw / cooked / burnt (cookables only), frozen.
function TL.foodState(item)
    local s = {}
    local perishable = (num(get(item, "getOffAgeMax")) or 1e9) < 1e8
    if get(item, "isRotten") then s[#s + 1] = "Rotten"
    elseif perishable and get(item, "isFresh") == false then s[#s + 1] = "Stale"
    elseif perishable then s[#s + 1] = "Fresh" end
    if get(item, "isIsCookable") then
        if get(item, "isBurnt") then s[#s + 1] = "Burnt"
        elseif get(item, "isCooked") then s[#s + 1] = "Cooked"
        else s[#s + 1] = "Raw" end
    end
    if get(item, "isFrozen") then s[#s + 1] = "Frozen" end
    return s
end

local function food(item, out)
    local h = num(get(item, "getHungerChange"))
    if h and h ~= 0 then kv(out, "Hunger", string.format("%d", math.floor(-h * 100 + 0.5))) end
    local cal = num(get(item, "getCalories"))
    if cal and cal > 0 then kv(out, "Calories", string.format("%d", math.floor(cal + 0.5))) end
    local st = TL.foodState(item)
    if #st > 0 then kv(out, "State", nil, st) end
end

local function drainable(item, out, hideTag)
    if hideTag ~= nil and get(item, "hasTag", hideTag) then return end
    local u = num(get(item, "getCurrentUsesFloat"))
    if u then bar(out, "Remaining", u, TL.pct(L.clamp(u, 0, 1)), "accent") end
end

local function fluid(item, out)
    local fc = get(item, "getFluidContainer")
    if not fc then return end
    local amt, cap = num(get(fc, "getAmount")), num(get(fc, "getCapacity"))
    if not (amt and cap and cap > 0) then return end
    bar(out, "Fluid", amt / cap, string.format("%.2f / %.2f L", amt, cap), "accent")
    if amt > 0 then
        local name = get(get(fc, "getPrimaryFluid"), "getTranslatedName")
        if type(name) == "string" and name ~= "" then kv(out, "FluidType", name) end
    end
end

local function container(item, out)
    local cap = num(get(item, "getCapacity"))
    local w = num(get(get(item, "getInventory"), "getCapacityWeight"))
    if cap and cap > 0 and w then
        local f = w / cap
        bar(out, "Capacity", f, TL.fmt2(w) .. " / " .. TL.fmt2(cap), L.barToken("load", f))
    end
    local wr = num(get(item, "getWeightReduction"))
    if wr and wr > 0 then kv(out, "WeightRed", string.format("%d%%", math.floor(wr + 0.5))) end
end

local function literature(item, out, chr)
    local n = num(get(item, "getNumberOfPages"))
    if n and n > 0 then
        local read = num(get(chr, "getAlreadyReadPages", get(item, "getFullType"))) or 0
        bar(out, "Pages", read / n, string.format("%d/%d", read, n), "accent")
    end
    local lvl, maxl = num(get(item, "getLvlSkillTrained")), num(get(item, "getMaxLevelTrained"))
    if lvl and lvl >= 0 and maxl then kv(out, "Levels", string.format("%d \226\128\147 %d", lvl, maxl)) end
end

-- First weapon type other than "Improvised" (e.g. SmallBlade): subtype in the header.
-- From the item or its script; if the build does not expose them the subtype is omitted.
local function weaponCat(item)
    local cats = get(item, "getCategories") or get(get(item, "getScriptItem"), "getCategories")
    local n = num(get(cats, "size")) or 0
    for i = 0, n - 1 do
        local c = get(cats, "get", i)
        if type(c) == "string" and c ~= "Improvised" then return c end
    end
    return nil
end

-- Tooltip model. chr: character (pages read); ws: stack weight from vanilla (0 = missing);
-- opts.hideTag: "hide remaining" tag (ItemTag.HIDE_REMAINING) if available.
function TL.build(item, chr, ws, opts)
    opts = opts or {}
    local out = {}
    local isWeapon, isClothing = get(item, "IsWeapon"), get(item, "IsClothing")
    local isFood, isDrain = get(item, "IsFood"), get(item, "IsDrainable")
    if isWeapon then weapon(item, out)
    elseif isClothing then clothing(item, out) end
    if isFood then food(item, out)
    elseif isDrain then drainable(item, out, opts.hideTag) end
    fluid(item, out)
    if get(item, "IsInventoryContainer") then container(item, out) end
    if get(item, "IsLiterature") then literature(item, out, chr) end

    local w = num(get(item, "getUnequippedWeight")) or num(get(item, "getActualWeight")) or 0
    ws = num(ws) or 0
    if ws > w + 0.005 then kv(out, "StackWeight", TL.fmt2(ws)) end
    local cat = get(item, "getDisplayCategory") or get(item, "getCategory")
    return {
        name = tostring(get(item, "getName") or get(item, "getDisplayName") or "?"),
        cat = cat,
        weaponCat = isWeapon and weaponCat(item) or nil,
        weight = TL.fmt2(w),
        fields = out,
    }
end

-- Tooltip height in px. m = { pad, gap, icon, sep, rowH, rowGap }; with no fields, header only.
-- The item script description is not shown (D-71).
function TL.height(m, nFields)
    local h = m.pad + m.icon
    if nFields > 0 then h = h + m.gap + m.sep + m.gap + nFields * m.rowH + (nFields - 1) * m.rowGap end
    return h + m.pad
end

-- Bar columns on usable width inner: the value always stays whole (column = widest value,
-- at least minVal); the label takes what it needs up to maxLabel; the bar the rest, at least minBar.
-- If that is not enough the label is shortened (clipped by the drawing code). labelWs/valWs: measured widths.
function TL.barColumns(inner, gap, labelWs, valWs, maxLabel, minVal, minBar)
    local lw, vw = 0, minVal
    for _, w in ipairs(labelWs) do if w > lw then lw = w end end
    for _, w in ipairs(valWs) do if w > vw then vw = w end end
    if lw > maxLabel then lw = maxLabel end
    local bw = inner - lw - vw - gap * 2
    if bw < minBar then
        lw = math.max(0, lw - (minBar - bw))
        bw = inner - lw - vw - gap * 2
    end
    return lw, math.max(0, bw), vw
end

-- Position: below-right of the mouse (offset off), inside the screen; if it does not fit below it goes above the mouse.
function TL.place(mx, my, w, h, sw, sh, off)
    local x = L.clamp(mx + off, 0, math.max(0, sw - w))
    local y = my + off
    if y + h > sh then y = my - h - math.floor(off / 4) end
    y = L.clamp(y, 0, math.max(0, sh - h))
    return x, y
end
