-- RSK.Hotbar.Logic - hotbar geometry, condition fill and reordering (P3.4, D-145) with no engine
-- dependencies (testable, T-32). Slots stay the vanilla 60 px; margins 8 and spacing 4.
RSK = RSK or {}
RSK.Hotbar = RSK.Hotbar or {}
RSK.Hotbar.Logic = RSK.Hotbar.Logic or {}
local L = RSK.Hotbar.Logic

L.GEO = {
    margin = 8, pad = 4,           -- frame margin and space between slots
    numX = 4, numY = 2,            -- slot number, top left
    icon = 32,                     -- item icon in the centre
    badge = 14, badgeInset = 4,    -- "in hand" badge, bottom right
    labelGap = 16, labelPadX = 8, labelPadY = 3, -- "name · condition" label above the hovered slot
    condLine = 2, condAlpha = 0.28,
    dragAlpha = 0.4, emptyAlpha = 0.25, invalidAlpha = 0.15,
    marker = 2,                    -- drop line while reordering
    dragThreshold = 6,             -- px of mouse movement before a press becomes a reorder drag
}
L.THRESHOLD = { ok = 0.6, mid = 0.3 } -- same as the bars (Stile_UI)

local function clamp01(v)
    if v < 0 then return 0 elseif v > 1 then return 1 end
    return v
end

-- Left x of slot i (1-based).
function L.slotX(i, slotW, g)
    g = g or L.GEO
    return g.margin + (i - 1) * (slotW + g.pad)
end

-- Panel size for n slots.
function L.size(n, slotW, slotH, g)
    g = g or L.GEO
    local w = n * slotW + math.max(n - 1, 0) * g.pad + 2 * g.margin
    return w, slotH + 2 * g.margin
end

-- Fill fraction 0..1 of an item, or nil: fluid containers (canteens, bottles) by their contents,
-- drainables by their uses, everything else by its condition.
-- info = { fluid, fluidCap, drain, cond, condMax }
function L.fraction(info)
    if not info then return nil end
    local cap = tonumber(info.fluidCap)
    if cap and cap > 0 then return clamp01((tonumber(info.fluid) or 0) / cap) end
    local d = tonumber(info.drain)
    if d then return clamp01(d) end
    local c, m = tonumber(info.cond), tonumber(info.condMax)
    if c and m and m > 0 then return clamp01(c / m) end
    return nil
end

function L.condToken(f)
    if f >= L.THRESHOLD.ok then return "ok" elseif f >= L.THRESHOLD.mid then return "accent" end
    return "danger"
end

-- Height of the fill from the bottom of a slot of height h (at least the line when f > 0).
function L.fillHeight(f, h, g)
    g = g or L.GEO
    if not f or f <= 0 then return 0 end
    return math.max(g.condLine, math.floor(h * f + 0.5))
end

function L.percent(f) return tostring(math.floor(f * 100 + 0.5)) .. "%" end

-- "name · 72%", or "name · <empty>" for an empty slot / an item with no fill.
function L.label(name, f, emptyText)
    return tostring(name or "") .. " · " .. (f and L.percent(f) or tostring(emptyText or ""))
end

-- Reordering: insertion point 1..n+1 for the mouse x (left half of a slot = before it).
function L.dropIndex(x, n, slotW, g)
    g = g or L.GEO
    if n <= 0 then return 1 end
    local p = (x - g.margin) / (slotW + g.pad)
    local ins = math.floor(p + 0.5) + 1
    if ins < 1 then ins = 1 elseif ins > n + 1 then ins = n + 1 end
    return ins
end

-- x of the drop line for insertion point ins.
function L.markerX(ins, n, slotW, g)
    g = g or L.GEO
    local half = math.floor(g.pad / 2)
    if ins <= n then return L.slotX(ins, slotW, g) - half - math.floor(g.marker / 2) end
    return L.slotX(n, slotW, g) + slotW + half - math.floor(g.marker / 2)
end

-- New order after moving slot `from` to insertion point `ins`: perm[newIndex] = oldIndex, or nil
-- when nothing moves.
function L.moveOrder(n, from, ins)
    if n < 2 or from < 1 or from > n or ins < 1 or ins > n + 1 then return nil end
    if ins == from or ins == from + 1 then return nil end
    local order = {}
    for i = 1, n do order[i] = i end
    table.remove(order, from)
    local target = ins > from and ins - 1 or ins
    table.insert(order, target, from)
    return order
end

-- New index of each old index (inverse of perm).
function L.inverse(perm)
    local inv = {}
    for ni, oi in ipairs(perm) do inv[oi] = ni end
    return inv
end

-- A press becomes a reorder drag after dragThreshold px; only with no timed actions queued (the
-- attach/detach actions remember a slot index) and at least two slots.
function L.startsDrag(dx, dy, n, queued, g)
    g = g or L.GEO
    if n < 2 or queued then return false end
    return math.abs(dx) > g.dragThreshold or math.abs(dy) > g.dragThreshold
end
