-- RSK.UI.Element - widget base (D-52). Coordinates and sizes in 1080p units (D-49):
-- the widget converts them to px and resizes itself on every ThemeChanged.
require "ISUI/ISUIElement"
require "RSK/UI/Draw"

local T = RSK.Theme
local E = ISUIElement:derive("RSK_Element")
RSK.UI.Element = E

function E:new(x, y, w, h)
    local o = ISUIElement.new(self, T.px(x), T.px(y), T.px(w), T.px(h))
    o.bx, o.by, o.bw, o.bh = x, y, w, h
    o.enabled = true
    o.anchorLeft, o.anchorTop = true, true
    return o
end

function E:layout()
    self:setX(T.px(self.bx)); self:setY(T.px(self.by))
    self:setWidth(T.px(self.bw)); self:setHeight(T.px(self.bh))
end

-- Reapplies the theme to itself and its children.
function E:themeChanged()
    if self.layout then self:layout() end
    for _, c in pairs(self.children or {}) do
        if c.themeChanged then c:themeChanged() end
    end
end

function E:setBase(x, y, w, h)
    self.bx, self.by = x or self.bx, y or self.by
    self.bw, self.bh = w or self.bw, h or self.bh
    self:layout()
end

function E:setEnabled(on) self.enabled = on and true or false end
function E:isHover() return self.enabled and self:isVisible() and self:isMouseOver() end
function E:alpha() return self.enabled and 1 or T.alpha.disabled end

function E:setTooltip(text) self.tooltipText = text end
function E:updateTooltip()
    if self.tooltipText and self:isMouseOver() and RSK.UI.Tooltip then RSK.UI.Tooltip.request(self, self.tooltipText) end
end

-- Adds an already created child and instantiates it.
function RSK.UI.add(parent, child)
    child:initialise()
    if not child.javaObject then child:instantiate() end
    parent:addChild(child)
    return child
end
