-- RSK.Menu - M8, P3.3: themed context menu (D-144, RF-8.1, RF-8.9).
-- Identical to the vanilla menu: the vanilla ISContextMenu:render() still builds and draws every
-- row (layout, states, sub-menus, scrolling, tooltips, options added by other mods). While it runs,
-- the draw methods of the ISContextMenu class translate its fixed colours into theme tokens
-- (RSK.Menu.Logic). The font is already the mod's (D-109).
-- Module off or in error: the plain vanilla render (D-44).
require "ISUI/ISContextMenu"
require "RSK/Core/Bootstrap"
require "RSK/UI/UI"
require "RSK/Menu/Logic"

RSK = RSK or {}
RSK.Menu = RSK.Menu or {}
local M = RSK.Menu
local L = M.Logic
local K, T = RSK.Core, RSK.Theme
M.ID = "ContextMenu"

local function rgbaOf(tok, alpha)
    local r, g, b, a = T.rgba(tok)
    return r, g, b, a * (alpha or 1)
end

-- Draw methods installed once on the ISContextMenu class (only context menus have it). They
-- translate colours only while self.rskCtx is set, i.e. during M.themedRender; otherwise they call
-- the inherited method unchanged. Nothing but rskCtx is ever written on a menu instance.
M.origDraw = M.origDraw or {}
local O = M.origDraw
local P = {}
function P.drawRect(self, x, y, w, h, a, r, g, b)
    if self.rskCtx then
        local tok, al = L.rect(a, r, g, b, self.rskCtx)
        if tok then r, g, b, a = rgbaOf(tok, al) end
    end
    return O.drawRect(self, x, y, w, h, a, r, g, b)
end
function P.drawRectBorder(self, x, y, w, h, a, r, g, b)
    if self.rskCtx then
        local tok, al = L.border(a, r, g, b, self.rskCtx)
        if tok then r, g, b, a = rgbaOf(tok, al) end
    end
    return O.drawRectBorder(self, x, y, w, h, a, r, g, b)
end
function P.drawRectBorderStatic(self, x, y, w, h, a, r, g, b)
    if self.rskCtx then
        local tok, al = L.border(a, r, g, b, self.rskCtx)
        if tok then r, g, b, a = rgbaOf(tok, al) end
    end
    return O.drawRectBorderStatic(self, x, y, w, h, a, r, g, b)
end
local function textArgs(self, r, g, b, a)
    if type(a) ~= "number" then a = 1 end -- vanilla passes the font as alpha in one call
    local tok, al = L.text(r, g, b, a, self.rskCtx)
    if tok then
        local tr, tg, tb, ta = rgbaOf(tok, al)
        return tr, tg, tb, ta
    end
    return r, g, b, a
end
function P.drawText(self, str, x, y, r, g, b, a, font)
    if self.rskCtx then r, g, b, a = textArgs(self, r, g, b, a) end
    return O.drawText(self, str, x, y, r, g, b, a, font)
end
function P.drawTextRight(self, str, x, y, r, g, b, a, font)
    if self.rskCtx then r, g, b, a = textArgs(self, r, g, b, a) end
    return O.drawTextRight(self, str, x, y, r, g, b, a, font)
end
local function which(self, tex)
    if tex == nil or not self.rskCtx then return nil end
    if tex == self.tickTexture then return "tick" end
    if tex == self.arrowUp or tex == self.arrowDown then return "arrow" end
    return nil
end
function P.drawTexture(self, tex, x, y, a, r, g, b)
    local tok, al = L.texture(which(self, tex))
    if tok then r, g, b, a = rgbaOf(tok, al) end
    return O.drawTexture(self, tex, x, y, a, r, g, b)
end
function P.drawTextureScaledAspect(self, tex, x, y, w, h, a, r, g, b)
    local tok, al = L.texture(which(self, tex))
    if tok then r, g, b, a = rgbaOf(tok, al) end
    return O.drawTextureScaledAspect(self, tex, x, y, w, h, a, r, g, b)
end

local function colour(c) return c and { r = c:getR(), g = c:getG(), b = c:getB() } or nil end

-- Counters for T-30: themed renders, renders that left rskCtx on the menu (must stay 0), menus that
-- carry their own draw functions (another mod: they would hide ours, so they are logged once).
M.stats = M.stats or { renders = 0, leftovers = 0, shadowed = 0 }
local shadowLogged = false

-- Runs the vanilla render with the colours of this frame; rskCtx is always removed, even on error.
function M.themedRender(menu)
    local core = getCore()
    -- Kahlua's rawget also returns inherited fields: our own class methods are not "own" functions
    for name, fn in pairs(P) do
        local own = rawget(menu, name)
        if own ~= nil and own ~= fn then
            M.stats.shadowed = M.stats.shadowed + 1
            if not shadowLogged then
                shadowLogged = true
                K.log("Menu: il menu ha una sua " .. name .. " (" .. tostring(own) .. "): un'altra mod disegna al posto nostro")
            end
            break
        end
    end
    menu.rskCtx = { bg = menu.backgroundColor, border = menu.borderColor,
        bad = colour(core:getBadHighlitedColor()), good = colour(core:getGoodHighlitedColor()) }
    local ok, err = pcall(M.origRender, menu)
    menu.rskCtx = nil
    M.stats.renders = M.stats.renders + 1
    if rawget(menu, "rskCtx") ~= nil then M.stats.leftovers = M.stats.leftovers + 1 end
    if not ok then error(err) end
    return true
end
local gThemed = K.guard(M.ID, M.themedRender)

function M.wrapRender(self)
    -- on: themed; if it fails the guard turns the module off and vanilla is back from the next frame
    if K.isActive(M.ID) then gThemed(self); return end
    return M.origRender(self)
end

-- Installed when the module starts (all vanilla files loaded); a class already wrapped is left alone.
function M.installHook()
    if not ISContextMenu then return false end
    if ISContextMenu.render ~= M.wrapRender then
        M.origRender, ISContextMenu.render = ISContextMenu.render, M.wrapRender
    end
    for name, fn in pairs(P) do
        if rawget(ISContextMenu, name) ~= fn then
            O[name] = ISContextMenu[name] -- inherited from ISUIElement (or a class override)
            rawset(ISContextMenu, name, fn)
        end
    end
    return ISContextMenu.render == M.wrapRender and rawget(ISContextMenu, "drawRect") == P.drawRect
end

M.moduleDef = K.register{
    id = M.ID, when = "game", requires = { "UI" },
    start = function()
        K.log("Menu: menu contestuale a tema, aggancio " .. tostring(M.installHook()))
    end,
    stop = function() end, -- the wrapper falls back to vanilla while the module is off
}
