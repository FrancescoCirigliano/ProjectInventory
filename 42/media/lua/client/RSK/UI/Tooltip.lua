-- RSK.UI.Tooltip - widget text tooltip (RF-0.1). The item tooltip (D-17) is in M1.
-- Widgets call request(owner, text) while hovered; it disappears when no longer requested.
require "RSK/UI/Widgets"

local T, D, L = RSK.Theme, RSK.UI.Draw, RSK.UI.Logic
local Tip = RSK.UI.Panel:derive("RSK_Tooltip")
RSK.UI.TooltipPanel = Tip
RSK.UI.Tooltip = RSK.UI.Tooltip or {}
local M = RSK.UI.Tooltip

function M.request(owner, text)
    M.owner, M.text = owner, text
    if not M.panel then
        local p = Tip:new(0, 0, 10, 10, { bg = "bg", border = "line" })
        p:initialise(); p:instantiate(); p:addToUIManager(); p:setAlwaysOnTop(true)
        M.panel = p
    end
    M.panel:setVisible(true)
    M.panel:bringToTop()
end

function M.hide()
    M.owner = nil
    if M.panel then M.panel:setVisible(false) end
end

local function lines(text)
    local t = {}
    for l in (tostring(text) .. "\n"):gmatch("(.-)\n") do t[#t + 1] = l end
    return t
end

function Tip:prerender()
    local o = M.owner
    if not o or not o:isVisible() or not o:isMouseOver() then M.hide(); return end
    local pad, maxW = T.px(T.base.space.m), T.px(T.base.w.tooltip)
    local ls, lh, w = lines(M.text), D.lineHeight("body"), 0
    for _, l in ipairs(ls) do w = math.max(w, D.measure("body", l)) end
    w = math.min(maxW, w + pad * 2)
    local h = #ls * lh + pad * 2
    local core = getCore()
    local x = L.clamp(getMouseX() + T.px(16), 0, core:getScreenWidth() - w)
    local y = getMouseY() + T.px(20)
    if y + h > core:getScreenHeight() then y = getMouseY() - h - T.px(4) end
    self:setX(x); self:setY(y); self:setWidth(w); self:setHeight(h)
    RSK.UI.Panel.prerender(self)
    self.lines, self.lh, self.pad = ls, lh, pad
end

function Tip:render()
    if not self.lines then return end
    for i, l in ipairs(self.lines) do
        D.text(self, l, self.pad, self.pad + (i - 1) * self.lh, "body", "text", 1, "left", self.width - self.pad * 2)
    end
end

function Tip:themeChanged() end
