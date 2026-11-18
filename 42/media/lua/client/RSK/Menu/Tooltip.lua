-- RSK.Tooltip - M8, P3.4: themed generic tooltip (ISToolTip: context menu options, buttons, build
-- menus; D-145, RF-8.1). Same approach as the context menu (D-144): the vanilla render keeps doing
-- the layout and the rich text; while it runs, the draw methods of ISToolTip and of its description
-- panel (ISRichTextPanel) translate the fixed colours into theme tokens (RSK.Tooltip.Logic). Title
-- at the 10 px margin, separator `line` under the title. The item tooltip (ISToolTipInv) is M1's.
-- Module off or in error: the plain vanilla render (D-44).
require "ISUI/ISToolTip"
require "ISUI/ISRichTextPanel"
require "RSK/Core/Bootstrap"
require "RSK/UI/UI"
require "RSK/Menu/TooltipLogic"

RSK = RSK or {}
RSK.Tooltip = RSK.Tooltip or {}
local M = RSK.Tooltip
local L = M.Logic
local K, T = RSK.Core, RSK.Theme
M.ID = "Tooltip"

local function rgbaOf(tok, alpha)
    local r, g, b, a = T.rgba(tok)
    return r, g, b, a * (alpha or 1)
end

local function textColour(ctx, r, g, b, a)
    if type(a) ~= "number" then a = 1 end
    local tok, al = L.text(r, g, b, ctx)
    if tok then
        local tr, tg, tb, ta = rgbaOf(tok, al)
        return tr, tg, tb, ta * a
    end
    return r, g, b, a
end

-- Draw methods installed once on the classes; they translate only while self.rskTip is set (during
-- M.themedRender), otherwise they call the inherited method unchanged.
M.orig = M.orig or { tip = {}, rich = {} }
local OT, OR = M.orig.tip, M.orig.rich
local PT, PR = {}, {}

function PT.drawRect(self, x, y, w, h, a, r, g, b)
    if self.rskTip then
        local tok, al = L.rect(a, r, g, b)
        if tok then r, g, b, a = rgbaOf(tok, al) end
    end
    return OT.drawRect(self, x, y, w, h, a, r, g, b)
end
function PT.drawRectBorder(self, x, y, w, h, a, r, g, b)
    if self.rskTip then
        local tok, al = L.border(a, r, g, b)
        if tok then r, g, b, a = rgbaOf(tok, al) end
    end
    return OT.drawRectBorder(self, x, y, w, h, a, r, g, b)
end
function PT.drawText(self, str, x, y, r, g, b, a, font)
    if self.rskTip then
        r, g, b, a = textColour(self.rskTip, r, g, b, a)
        x = L.nameX(x, y)
    end
    return OT.drawText(self, str, x, y, r, g, b, a, font)
end
function PT.drawTextCentre(self, str, x, y, r, g, b, a, font)
    if self.rskTip then -- the foot note ("how to rotate"): a note
        local tr, tg, tb, ta = rgbaOf("muted", 1)
        r, g, b, a = tr, tg, tb, ta * (type(a) == "number" and a or 1)
    end
    return OT.drawTextCentre(self, str, x, y, r, g, b, a, font)
end
function PR.drawText(self, str, x, y, r, g, b, a, font)
    if self.rskTip then r, g, b, a = textColour(self.rskTip, r, g, b, a) end
    return OR.drawText(self, str, x, y, r, g, b, a, font)
end
function PR.drawTextRight(self, str, x, y, r, g, b, a, font)
    if self.rskTip then r, g, b, a = textColour(self.rskTip, r, g, b, a) end
    return OR.drawTextRight(self, str, x, y, r, g, b, a, font)
end

local function colour(c) return c and { r = c:getR(), g = c:getG(), b = c:getB() } or nil end

M.stats = M.stats or { renders = 0, leftovers = 0 }

-- Runs the vanilla render with the colours of this frame; rskTip is always removed, even on error.
function M.themedRender(tip)
    local core = getCore()
    local ctx = { bad = colour(core:getBadHighlitedColor()), good = colour(core:getGoodHighlitedColor()) }
    local panel = tip.descriptionPanel
    tip.rskTip = ctx
    if panel then panel.rskTip = ctx end
    local ok, err = pcall(M.origRender, tip)
    tip.rskTip = nil
    if panel then panel.rskTip = nil end
    M.stats.renders = M.stats.renders + 1
    if rawget(tip, "rskTip") ~= nil or (panel and rawget(panel, "rskTip") ~= nil) then
        M.stats.leftovers = M.stats.leftovers + 1
    end
    if not ok then error(err) end
    local fh = getTextManager():getFontHeight(UIFont.Medium)
    local sx, sy, sw, sh = L.separator(tip.width, fh, tip.name ~= nil, (tip.description or "") ~= "")
    if sx then
        local r, g, b, a = rgbaOf("line", 1)
        OT.drawRect(tip, sx, sy, sw, sh, a, r, g, b)
    end
    return true
end
local gThemed = K.guard(M.ID, M.themedRender)

function M.wrapRender(self)
    if K.isActive(M.ID) then gThemed(self); return end
    return M.origRender(self)
end

local function install(class, P, O)
    for name, fn in pairs(P) do
        if rawget(class, name) ~= fn then
            O[name] = class[name]
            rawset(class, name, fn)
        end
    end
end

function M.installHook()
    if not ISToolTip or not ISRichTextPanel then return false end
    if ISToolTip.render ~= M.wrapRender then
        M.origRender, ISToolTip.render = ISToolTip.render, M.wrapRender
    end
    install(ISToolTip, PT, OT)
    install(ISRichTextPanel, PR, OR)
    return ISToolTip.render == M.wrapRender and rawget(ISRichTextPanel, "drawText") == PR.drawText
end

M.moduleDef = K.register{
    id = M.ID, when = "game", requires = { "UI" },
    start = function()
        K.log("Tooltip: tooltip generico a tema, aggancio " .. tostring(M.installHook()))
    end,
    stop = function() end, -- the wrapper falls back to vanilla while the module is off
}
