-- RSK.Menu.Logic - context menu colours (P3.3, D-144) with no engine dependencies (testable, T-29).
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
    if ctx.border and same(r, g, b, ctx.border) and near(a, ctx.border.a) then return "line", 1 end -- separator
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
