-- RSK.Menu.Logic - context menu colours (P3.3, D-144) and geometry (P3.4, D-145) with no engine
-- dependencies (testable, T-29).
-- The vanilla ISContextMenu:render() keeps doing all the work (layout, sub-menus, tooltips, mod
-- options, RF-8.9); while it draws, its fixed colours are translated into theme tokens.
-- Each function returns token, alpha for a recognised vanilla colour, or nil to draw it unchanged
-- (item icons, colour boxes, anything a mod draws).
-- ctx = { bg = {r,g,b,a}, border = {r,g,b,a}, bad = {r,g,b}, good = {r,g,b} } read from the menu
-- and from the game core each frame.
RSK = RSK or {}
RSK.Menu = RSK.Menu or {}
RSK.Menu.Logic = RSK.Menu.Logic or {}
local L = RSK.Menu.Logic

L.EPS = 0.02

local function near(a, b) return type(a) == "number" and math.abs(a - b) <= L.EPS end
local function rgb(r, g, b, R, G, B) return near(r, R) and near(g, G) and near(b, B) end
local function same(r, g, b, c) return c ~= nil and rgb(r, g, b, c.r, c.g, c.b) end

-- drawRect(x, y, w, h, a, r, g, b)
function L.rect(a, r, g, b, ctx)
    ctx = ctx or {}
    if ctx.bg and same(r, g, b, ctx.bg) and near(a, ctx.bg.a) then return "panel", 0.97 end -- menu background
    if near(a, 0.25) and rgb(r, g, b, 0.1, 0.1, 0.1) then return "bg", 0.6 end            -- icon column
    if near(a, 0.8) and rgb(r, g, b, 0.5, 0.5, 0.5) then return "sel", 1 end              -- row under the mouse
    if near(a, 0.1) and rgb(r, g, b, 0.05, 0.05, 0.05) then return "sel", 0.6 end         -- same, disabled/unavailable
    if near(a, 0.8) and rgb(r, g, b, 0.1, 0.1, 0.1) then return "panel2", 1 end           -- scroll indicator band
    if ctx.border and same(r, g, b, ctx.border) and near(a, ctx.border.a) then return "line", 0 end -- separator: none (D-145)
    if rgb(r, g, b, 1, 1, 1) and type(a) == "number" then return "accent", a * 0.35 end   -- blinking option
    return nil
end

-- drawRectBorder / drawRectBorderStatic(x, y, w, h, a, r, g, b)
function L.border(a, r, g, b, ctx)
    ctx = ctx or {}
    if near(a, 0.15) and rgb(r, g, b, 0.9, 0.9, 1) then return "accent", 1 end -- row under the mouse
    if ctx.border and same(r, g, b, ctx.border) then return "line", 1 end      -- menu frame
    return nil
end

-- drawText / drawTextRight(str, x, y, r, g, b, a, font)
function L.text(r, g, b, a, ctx)
    ctx = ctx or {}
    if ctx.bad and same(r, g, b, ctx.bad) then return "danger", 1 end       -- not available
    if ctx.good and same(r, g, b, ctx.good) then return "ok", 1 end         -- good option
    if rgb(r, g, b, 0.5, 0.5, 0.5) then return "muted", 1 end               -- disabled
    if rgb(r, g, b, 1, 1, 1) or rgb(r, g, b, 1, 0.8, 0.8) then return "text", 1 end -- normal / hovered
    return nil
end

-- Textures: only the menu's own tick and scroll arrows are tinted; icons stay as they are.
-- which = "tick" | "arrow" | nil
function L.texture(which)
    if which == "tick" then return "ok", 1 end
    if which == "arrow" then return "text", 1 end
    return nil
end

-- Geometry (D-145): rows 30, icon column 28, icon 20, text 8 px after the column, at the reference
-- size (px scales them). The vanilla render derives everything from itemHgt: icon column
-- itemHgt - 8, icon itemHgt - 12 at (2, rowY + 6), text at itemHgt - 6. The hooks move what it draws
-- from the vanilla spots to ours.
L.ROW, L.COL, L.ICON, L.TEXT_GAP, L.ROW_PAD = 30, 28, 20, 8, 4

local function id(n) return n end

-- Row height for a font height: 30 at the reference size, taller only if the font needs it.
function L.rowHeight(fontHgt, px)
    px = px or id
    return math.max(px(L.ROW), fontHgt + 2 * px(L.ROW_PAD))
end

function L.geometry(itemHgt, px)
    px = px or id
    local g = { vCol = itemHgt - 8, vIcon = itemHgt - 12, vText = itemHgt - 6, vIconX = 2, vIconDY = 6 }
    g.col = math.max(px(L.COL), g.vCol)
    g.icon = math.min(px(L.ICON), g.col, itemHgt)
    g.text = g.col + px(L.TEXT_GAP)
    g.shift = g.text - g.vText -- extra width of the menu and x shift of the texts
    return g
end

-- Vanilla icon rect (x, y, w, h) -> ours, centred in the icon column and in the row; nil if the
-- rect is not the vanilla icon spot (a mod drawing elsewhere).
function L.iconRect(x, y, w, h, g, itemHgt)
    if x ~= g.vIconX or w ~= g.vIcon or h ~= g.vIcon then return nil end
    local rowY = y - g.vIconDY
    local s = g.icon
    return math.floor((g.col - s) / 2), rowY + math.floor((itemHgt - s) / 2), s, s
end

-- Text x: the vanilla text column moves after our icon column; any other x is left alone.
function L.textX(x, g)
    if x == g.vText then return g.text end
    return x
end
