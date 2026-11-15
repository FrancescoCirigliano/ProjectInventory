-- RSK.Equipment.Logic - M2, P2.4: pure slot and wound logic (D-78, D-81). Tests T-22.
-- No game API: data arrives as plain values from Equipment/Window.
RSK = RSK or {}
RSK.Equipment = RSK.Equipment or {}
RSK.Equipment.Logic = RSK.Equipment.Logic or {}
local L = RSK.Equipment.Logic

-- ---------------------------------------------------------------- slot (D-28, D-33, D-34, D-78)
L.SLOTS_LEFT = { "head", "torso", "arms", "hands" }
L.SLOTS_RIGHT = { "back", "belt", "legs", "feet" }
L.SLOTS_WEAPON = { "backWeapon", "primary", "secondary" }

local function list(slot, names, out)
    for name in string.gmatch(names, "%S+") do out[name] = slot end
end

local MAP = {}
list("head", "HAT FULLHAT MASK MASKFULL MASKEYES EYES LEFTEYE RIGHTEYE EARS EARTOP NOSE NECK NECKTEXTURE NECKLACE "
    .. "NECKLACELONG GORGET SCARF", MAP)
list("torso", "JACKET JACKETDOWN JACKETBULKY JACKETHAT JACKETHATBULKY JACKETSUIT SWEATER SWEATERHAT FULLSUIT "
    .. "FULLSUITHEAD FULLSUITHEADSCBA BOILERSUIT BODYCOSTUME BATHROBE FULLROBE FULLTOP JERSEY VESTTEXTURE TORSOEXTRA "
    .. "TORSOEXTRAVEST TORSOEXTRAVESTBULLET CUIRASS SPORTSHOULDERPAD SPORTSHOULDERPADONTOP DRESS LONGDRESS "
    .. "SHIRT SHORTSLEEVESHIRT TSHIRT TANKTOP TORSO1 TORSO1LEGS1 UNDERWEAR UNDERWEARTOP UNDERWEAREXTRA1 UNDERWEAREXTRA2", MAP)
list("arms", "LEFTARM RIGHTARM FOREARMLEFT FOREARMRIGHT ELBOWLEFT ELBOWRIGHT SHOULDERPADLEFT SHOULDERPADRIGHT", MAP)
list("hands", "HANDS HANDSLEFT HANDSRIGHT LEFTWRIST RIGHTWRIST LEFTMIDDLEFINGER RIGHTMIDDLEFINGER LEFTRINGFINGER "
    .. "RIGHTRINGFINGER", MAP)
list("legs", "PANTS PANTSSKINNY PANTSEXTRA SHORTPANTS SHORTSSHORT SKIRT LONGSKIRT LEGS1 LEGS5 UNDERWEARBOTTOM CODPIECE "
    .. "KNEELEFT KNEERIGHT CALFLEFT CALFRIGHT CALFLEFTTEXTURE CALFRIGHTTEXTURE THIGHLEFT THIGHRIGHT GAITERLEFT GAITERRIGHT", MAP)
list("back", "BACK SATCHEL SCBA SCBANOTANK TAIL", MAP)
list("belt", "BELT BELTEXTRA FANNYPACKFRONT FANNYPACKBACK WEBBING AMMOSTRAP SHOULDERHOLSTER ANKLEHOLSTER", MAP)
list("feet", "SOCKS SHOES", MAP)
L.MAP = MAP

local HIDDEN = {}
list(true, "BANDAGE WOUND ZEDDMG BELLYBUTTON", HIDDEN)

-- Mod locations: first keyword found, in this order ("ARMOR" before "ARM").
local KEYWORDS = {
    { "ARMOR", "torso" }, { "SHIRT", "torso" }, { "EYE", "head" }, { "BACK", "back" }, { "BAG", "back" },
    { "BELT", "belt" }, { "HOLSTER", "belt" }, { "POUCH", "belt" }, { "STRAP", "belt" }, { "SOCK", "feet" },
    { "SHOE", "feet" }, { "BOOT", "feet" }, { "FOOT", "feet" }, { "FEET", "feet" }, { "GLOVE", "hands" },
    { "HAND", "hands" }, { "WRIST", "hands" }, { "FINGER", "hands" }, { "ARM", "arms" }, { "ELBOW", "arms" },
    { "SHOULDER", "arms" }, { "LEG", "legs" }, { "PANT", "legs" }, { "SHORT", "legs" }, { "SKIRT", "legs" },
    { "KNEE", "legs" }, { "CALF", "legs" }, { "THIGH", "legs" }, { "HAT", "head" }, { "HEAD", "head" },
    { "MASK", "head" }, { "NECK", "head" }, { "EARRING", "head" }, { "NOSE", "head" },
}

-- "base:full_hat", "FULL_HAT", "FullHat" -> "FULLHAT". Nil or empty -> "".
function L.normalize(location)
    if location == nil then return "" end
    local s = tostring(location)
    local colon = string.find(s, ":", 1, true)
    if colon then s = string.sub(s, colon + 1) end
    return (string.gsub(string.upper(s), "[^A-Z0-9]", ""))
end

-- Slot of a body location; nil = no slot (hidden or empty location).
function L.slotFor(location)
    local n = L.normalize(location)
    if n == "" or n == "NIL" or HIDDEN[n] or string.sub(n, 1, 6) == "MAKEUP" then return nil end
    if MAP[n] then return MAP[n] end
    for i = 1, #KEYWORDS do
        if string.find(n, KEYWORDS[i][1], 1, true) then return KEYWORDS[i][2] end
    end
    return "torso"
end

-- Worn items -> { slot = { items } }, in the order received. entries = { { item, location } }.
function L.groupWorn(entries)
    local out = {}
    for i = 1, #entries do
        local slot = L.slotFor(entries[i].location)
        if slot then
            out[slot] = out[slot] or {}
            local s = out[slot]
            s[#s + 1] = entries[i].item
        end
    end
    return out
end

-- Position in a list after an update: stays on the same item if it is still there.
function L.keepIndex(items, index, current)
    local n = #items
    if n == 0 then return 0 end
    if current ~= nil then
        for i = 1, n do if items[i] == current then return i end end
    end
    if not index or index < 1 then return 1 end
    return math.min(index, n)
end

-- Slot arrows: circular scrolling.
function L.cycle(index, n, dir)
    if n <= 1 then return n == 1 and 1 or 0 end
    return (index - 1 + dir) % n + 1
end

function L.indexText(index, n) return tostring(n == 0 and 0 or index) .. "/" .. tostring(n) end

-- Condition fraction 0..1; nil if the item has no condition.
function L.condition(cond, max)
    cond, max = tonumber(cond), tonumber(max)
    if not cond or not max or max <= 0 then return nil end
    local f = cond / max
    if f < 0 then return 0 elseif f > 1 then return 1 end
    return f
end

-- ---------------------------------------------------------------- wounds (D-30, D-35, D-81)
local function qualTime(doctor, min, t, severe, moderate)
    if doctor > min then
        if t > severe then return "IGUI_health_Severe" end
        if t > moderate then return "IGUI_health_Moderate" end
    end
    return nil
end

-- From a body part snapshot (plain fields, see Window.partSnapshot) to the tooltip labels.
-- Same checks as ISHealthBodyPartListBox:doDrawItem; pain and stiffness excluded (D-81).
-- Returns nil if the part has nothing to show, otherwise { tok, lines = { { key, qual, tok } } }:
-- tok = the most severe label colour: danger, warn, ok (treated only, D-84).
function L.wound(s)
    local doc = s.doctor or 0
    local lines = {}
    local rank = { ok = 1, warn = 2, danger = 3 }
    local top = "ok"
    local function add(key, tok, qual)
        lines[#lines + 1] = { key = key, tok = tok, qual = qual }
        if rank[tok] > rank[top] then top = tok end
    end

    if s.bitten then add("IGUI_health_Bitten", "danger") end
    if s.deep then add("IGUI_health_DeepWound", "danger", qualTime(doc, 4, s.deepTime or 0, 10, 8)) end
    if (s.fractureTime or 0) > 0 and (s.splint or 0) == 0 then
        add("IGUI_health_Fracture", "danger", qualTime(doc, 6, s.fractureTime, 50, 20))
    end
    if (s.burnTime or 0) > 0 and not s.bandaged then
        add("IGUI_health_Burned", "danger", (doc > 4 and s.burnWash) and "IGUI_health_NeedCleaning" or nil)
    end
    if s.bullet and not s.bandaged then add("IGUI_health_LodgedBullet", "danger") end
    if s.glass and not s.bandaged then add("IGUI_health_LodgedGlassShards", "danger") end
    if s.infected and not s.bandaged and (doc > 8 or (s.infectionLevel or 0) * 10 >= 2.5 - doc) then
        add("IGUI_health_Infected", "danger")
    end
    if s.cut then add("IGUI_health_Cut", "warn", qualTime(doc, 2, s.cutTime or 0, 17, 14)) end
    if s.scratched then add("IGUI_health_Scratched", "warn", qualTime(doc, 2, s.scratchTime or 0, 17, 14)) end
    if s.bleeding then add("IGUI_health_Bleeding", "danger") end

    if (s.splint or 0) > 0 then
        local q
        if doc > 4 then
            if s.splint > 4 then q = "IGUI_health_Good"
            elseif (s.fractureTime or 0) > 2 then q = "IGUI_health_Moderate" end
        end
        add("IGUI_health_Splinted", "ok", q)
    end
    if s.bandaged then
        if (s.bandageLife or 0) > 0 then add("IGUI_health_Bandaged", "ok")
        else add("IGUI_health_DirtyBandage", "warn") end
    end
    if s.stitched then
        add("IGUI_health_Stitched", "ok", doc > 6 and ((s.stitchTime or 0) > 40 and "IGUI_health_Good" or "IGUI_health_NeedTime") or nil)
    end
    if (s.plantain or 0) > 0 then add("ContextMenu_PlantainCataplasm", "ok") end
    if (s.comfrey or 0) > 0 then add("ContextMenu_ComfreyCataplasm", "ok") end
    if (s.garlic or 0) > 0 then add("ContextMenu_GarlicCataplasm", "ok") end

    if #lines == 0 then return nil end
    return { tok = top, lines = lines }
end

-- ---------------------------------------------------------------- wound warning (D-117)
-- Wounds that trigger the warning, by severity: key, vanilla label, colour.
L.INJURIES = {
    { "bitten", "IGUI_health_Bitten", "danger" }, { "deep", "IGUI_health_DeepWound", "danger" },
    { "fracture", "IGUI_health_Fracture", "danger" }, { "burn", "IGUI_health_Burned", "danger" },
    { "bullet", "IGUI_health_LodgedBullet", "danger" }, { "glass", "IGUI_health_LodgedGlassShards", "danger" },
    { "bleeding", "IGUI_health_Bleeding", "danger" }, { "cut", "IGUI_health_Cut", "warn" },
    { "scratched", "IGUI_health_Scratched", "warn" },
}
L.ALERT = { W = 260, PAD = 10, GAP = 8, ICON_W = 26, ICON_H = 24, CLOSE = 20, BAR = 2, MAX = 3,
    LIFE_MS = 6000, IN_MS = 160, OUT_MS = 200, SLIDE = 24, CHECK_MS = 500 }

-- Wounds present in a part snapshot (same fields as L.wound): { key = true }.
function L.injuryFlags(s)
    return {
        bitten = s.bitten or nil, deep = s.deep or nil, fracture = (s.fractureTime or 0) > 0 or nil,
        burn = (s.burnTime or 0) > 0 or nil, bullet = s.bullet or nil, glass = s.glass or nil,
        bleeding = s.bleeding or nil, cut = s.cut or nil, scratched = s.scratched or nil,
    }
end

-- Wounds that appeared from prev to cur (tables { part = flags }): list { part, lines = { {key, tok} }, tok }
-- per part, in the order of parts. tok = danger if at least one is severe, otherwise warn.
function L.newInjuries(prev, cur, parts)
    local out = {}
    for _, part in ipairs(parts) do
        local p, c = prev[part] or {}, cur[part] or {}
        local lines, tok = {}, "warn"
        for _, inj in ipairs(L.INJURIES) do
            if c[inj[1]] and not p[inj[1]] then
                lines[#lines + 1] = { key = inj[2], tok = inj[3] }
                if inj[3] == "danger" then tok = "danger" end
            end
        end
        if #lines > 0 then out[#out + 1] = { part = part, lines = lines, tok = tok } end
    end
    return out
end

-- Warning state after elapsed ms (pause excluded): alpha 0..1, entry x offset, remaining life 0..1, done.
function L.alertState(elapsed, closingAt)
    local A = L.ALERT
    local inT = L.easeOut(elapsed, A.IN_MS)
    local alpha, dx = inT, math.floor((1 - inT) * -A.SLIDE + 0.5)
    local endAt = closingAt or A.LIFE_MS
    local life = 1 - math.min(1, math.max(0, elapsed / A.LIFE_MS))
    if elapsed > endAt then
        local o = (elapsed - endAt) / A.OUT_MS
        if o >= 1 then return 0, dx, 0, true end
        alpha = alpha * (1 - o)
    end
    return alpha, dx, life, false
end

-- ---------------------------------------------------------------- wound tooltip (D-84)
-- Progress 0..1 of an animation, with ease-out.
function L.easeOut(elapsed, duration)
    if duration <= 0 or elapsed >= duration then return 1 end
    if elapsed <= 0 then return 0 end
    local t = elapsed / duration
    return 1 - (1 - t) * (1 - t)
end

-- Labels widths[i] wide on rows of at most maxW. Returns { { x, row } } (row from 0) and the row count.
function L.wrapChips(widths, maxW, gap)
    local out, x, row = {}, 0, 0
    for i = 1, #widths do
        if x > 0 and x + widths[i] > maxW then x, row = 0, row + 1 end
        out[i] = { x = x, row = row }
        x = x + widths[i] + gap
    end
    return out, #widths > 0 and row + 1 or 0
end

-- Tooltip position next to the marker (x, y, marker width): right, otherwise left; inside the screen.
function L.tipPlace(markX, markY, markW, tipW, tipH, gap, screenW, screenH)
    local x = markX + markW + gap
    if x + tipW > screenW then x = markX - gap - tipW end
    if x < 0 then x = 0 end
    local y = markY
    if y + tipH > screenH then y = screenH - tipH end
    if y < 0 then y = 0 end
    return x, y
end

-- ---------------------------------------------------------------- window (D-87, D-88)
L.WIN = { W = 424, H = 688, MIN_W = 400, MIN_H = 678, TITLE = 44, TABS = 40, PROFILE = 60 }
L.SLOT_H, L.SLOT_H_WEAPON = 95, 72

-- First tab layout in 1080p units, from the window size: fixed columns, render in the middle.
-- Coordinates relative to the page, which starts below title and tabs.
function L.layout(w, h)
    local pad, col, colGap = 16, 70, 10
    local pageH = h - L.WIN.TITLE - L.WIN.TABS
    local healthH, statsH = 41, 26
    local statsY = healthH + 6
    local gridY = statsY + statsH + 10
    local centerX = pad + col + colGap
    local centerW = w - 2 * centerX
    local protH, lookBtnH = 26, 32
    -- below the frame: 12 + protections 26 + 12 + line/12 + hair row 44 + 16
    local centerH = pageH - gridY - (12 + protH + 12 + 12 + 44 + 16)
    local weaponGap = math.max(0, math.min(12, (centerW - 3 * 64) / 2))
    local weaponsW = 3 * 64 + 2 * weaponGap
    local protY = gridY + centerH + 12
    local lookY = protY + protH + 12
    local inner = w - 2 * pad
    return {
        w = w, h = h, pad = pad, pageH = pageH, gridY = gridY, healthH = healthH, statsH = statsH,
        centerX = centerX, centerW = centerW, centerH = centerH,
        modelH = centerH - L.SLOT_H_WEAPON - 8,
        leftX = pad + 3, rightX = w - pad - col + 3,
        slotStep = (centerH - L.SLOT_H) / 3,
        weaponX = centerX + (centerW - weaponsW) / 2, weaponY = gridY + centerH - L.SLOT_H_WEAPON,
        weaponStep = 64 + weaponGap,
        protY = protY, protH = protH, chipW = (inner - 2 * 6) / 3, chipGap = 6,
        statsY = statsY, statW = (inner - 6) / 2,
        lookY = lookY, lookRowY = lookY + 12, lookColW = (inner - 12) / 2, lookBtnW = 72, lookBtnH = lookBtnH,
    }
end

-- Exercises tab (D-93): same blocks as ISFitnessUI:updateButtons. s = plain fields.
-- Returns the reason key, nil if it can start; same order as vanilla: the last one wins.
function L.fitnessBlock(s)
    local key
    if s.missingItem then key = "IGUI_FitnessNeedItem" end
    if (s.endurance or 0) > (s.enduranceMax or 2) then key = "Tooltip_TooExhaustedFitness" end
    if (s.heavyLoad or 0) > 2 then key = "Tooltip_TooHeavyFitness" end
    if s.sitting then key = "Tooltip_StandStillFitness" end
    if s.inVehicle then key = "Tooltip_CantDriveAndFitness" end
    if (s.pain or 0) > 3 then key = "Tooltip_TooMuchPainFitness" end
    if s.climbing then key = key or "Tooltip_StandStillFitness" end
    return key
end

-- Exercise duration: 10-minute steps between 10 and 60, as in vanilla.
function L.fitnessTime(minutes, dir)
    local m = minutes + 10 * dir
    if m < 10 then return 10 elseif m > 60 then return 60 end
    return m
end

-- Exercise regularity, 0..1 (vanilla shows it out of 100).
function L.regularity(v)
    local f = (tonumber(v) or 0) / 100
    if f < 0 then return 0 elseif f > 1 then return 1 end
    return f
end

-- Default window widths (D-89), in px: sidebar, M2, inventory, loot.
-- Inventory and loot share the remaining space, between minW and maxW. Returns invX, invW, lootX, lootW.
function L.defaultLayout(screenW, left, m2W, gap, minW, maxW)
    local invX = left + m2W + gap
    local w = math.floor((screenW - invX - 2 * gap) / 2)
    if w > maxW then w = maxW end
    if w < minW then w = minW end
    return invX, w, invX + w + gap, w
end

-- Resolutions already handled: text "1920x1080;2560x1440".
function L.layoutDone(done, key)
    return string.find(";" .. (done or "") .. ";", ";" .. key .. ";", 1, true) ~= nil
end
function L.layoutMark(done, key)
    if L.layoutDone(done, key) then return done end
    if not done or done == "" then return key end
    return done .. ";" .. key
end

-- M2 position and size remembered across sessions (D-125): text "x,y,w,h" in 1080p units.
-- parseGeom: nil if missing or invalid; size never below the minimum.
function L.geomText(x, y, w, h)
    return string.format("%d,%d,%d,%d", math.floor(x + 0.5), math.floor(y + 0.5), math.floor(w + 0.5), math.floor(h + 0.5))
end
function L.parseGeom(s)
    local x, y, w, h = tostring(s or ""):match("^(%-?%d+),(%-?%d+),(%d+),(%d+)$")
    if not x then return nil end
    return { x = tonumber(x), y = tonumber(y), w = math.max(L.WIN.MIN_W, tonumber(w)), h = math.max(L.WIN.MIN_H, tonumber(h)) }
end
-- Position inside the screen (same units): the title always stays reachable.
function L.clampPos(x, y, w, screenW, screenH, titleH)
    if x > screenW - w then x = screenW - w end
    if y > screenH - titleH then y = screenH - titleH end
    if x < 0 then x = 0 end
    if y < 0 then y = 0 end
    return x, y
end

-- Vanilla panel in the tab area (D-88): fills the area; scrolls if it needs more.
-- ownScroll = the panel has its own scrolling: it stays as tall as the area.
function L.viewSize(areaW, areaH, wantW, wantH, ownScroll)
    local w = math.max(areaW, wantW or 0)
    local h = ownScroll and areaH or math.max(areaH, wantH or 0)
    return w, h
end

-- ---------------------------------------------------------------- render (D-79)
-- Body parts on the render frame. y = fraction of the height; x = fraction of a
-- 308x396 reference frame: the model follows the height, so the offset from the centre is computed on the height.
-- Character facing us: their left is on the right.
local PART_REF = 308 / 396
L.PARTS = {
    Head = { 0.50, 0.09 }, Neck = { 0.50, 0.16 }, Torso_Upper = { 0.50, 0.26 }, Torso_Lower = { 0.50, 0.38 },
    Groin = { 0.50, 0.50 }, UpperArm_R = { 0.37, 0.29 }, UpperArm_L = { 0.63, 0.29 }, ForeArm_R = { 0.33, 0.41 },
    ForeArm_L = { 0.67, 0.41 }, Hand_R = { 0.31, 0.51 }, Hand_L = { 0.69, 0.51 }, UpperLeg_R = { 0.44, 0.60 },
    UpperLeg_L = { 0.56, 0.60 }, LowerLeg_R = { 0.44, 0.77 }, LowerLeg_L = { 0.56, 0.77 }, Foot_R = { 0.44, 0.93 },
    Foot_L = { 0.56, 0.93 },
}

-- Centre of the part in the w x h frame.
function L.partPos(name, w, h)
    local p = L.PARTS[name]
    if not p then return nil end
    return w / 2 + (p[1] - 0.5) * PART_REF * h, p[2] * h
end

-- Part closest to (x, y) in the w x h frame, within maxDist (fraction of the height); nil if too far.
function L.partAt(x, y, w, h, maxDist)
    local best, bestD
    for name in pairs(L.PARTS) do
        local px, py = L.partPos(name, w, h)
        local dx, dy = x - px, y - py
        local d = dx * dx + dy * dy
        if not bestD or d < bestD or (d == bestD and name < best) then best, bestD = name, d end
    end
    local r = maxDist * h
    if best and bestD <= r * r then return best end
    return nil
end

-- Signature of what is visible on the model: changes when clothes, hands or attached items change.
function L.signature(ids)
    return table.concat(ids, ",")
end

-- Average of a list; empty list -> 0.
function L.average(values)
    local n, sum = #values, 0
    if n == 0 then return 0 end
    for i = 1, n do sum = sum + values[i] end
    return sum / n
end

function L.percentText(v) return tostring(math.floor((tonumber(v) or 0) + 0.5)) .. "%" end
function L.oneDecimal(v) return string.format("%.1f", tonumber(v) or 0) end

-- Window position: left of the inventory (D-28); if there is no room, to the right so it does not cover it
-- (D-88); if there is no room there either, at the left edge. Always inside the screen.
function L.place(invX, invY, invW, w, h, gap, screenW, screenH)
    local x, y = invX - w - gap, invY
    if x < 0 then
        local right = invX + invW + gap
        x = (right + w <= screenW) and right or 0
    end
    if x + w > screenW then x = math.max(0, screenW - w) end
    if y + h > screenH then y = screenH - h end
    if y < 0 then y = 0 end
    return x, y
end
