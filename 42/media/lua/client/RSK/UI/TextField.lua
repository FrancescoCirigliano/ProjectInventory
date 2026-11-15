-- RSK.UI.TextField - text field: vanilla ISTextEntryBox (text drawn by Java, Census B)
-- with themed background and border. Font: UIFont slot remapped to Fira (D-38).
require "ISUI/ISTextEntryBox"
require "RSK/UI/Element"

local T = RSK.Theme
local TF = ISTextEntryBox:derive("RSK_TextField")
RSK.UI.TextField = TF

local function col(tok)
    local r, g, b, a = T.rgba(tok)
    return { r = r, g = g, b = b, a = a }
end

function TF:new(x, y, w, h, text)
    local o = ISTextEntryBox.new(self, text or "", T.px(x), T.px(y), T.px(w), T.px(h or T.base.h.button))
    o.bx, o.by, o.bw, o.bh = x, y, w, h or T.base.h.button
    o.font = UIFont.Medium
    o:applyColors()
    return o
end

function TF:applyColors()
    self.backgroundColor = col("panel2")
    self.borderColor = col("line")
end

function TF:themeChanged()
    self:setX(T.px(self.bx)); self:setY(T.px(self.by))
    self:setWidth(T.px(self.bw)); self:setHeight(T.px(self.bh))
    self:applyColors()
end
