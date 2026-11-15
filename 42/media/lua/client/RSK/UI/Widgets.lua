-- RSK.UI: base widgets (D-55). Panel, label, button, toggle, slider, tabs, bar.
require "RSK/UI/Element"

local T, D, L, E = RSK.Theme, RSK.UI.Draw, RSK.UI.Logic, RSK.UI.Element
local UI = RSK.UI

-- ---------------------------------------------------------------- Panel
-- opts: bg (token or false), border (token or false), alpha
local Panel = E:derive("RSK_Panel")
UI.Panel = Panel
function Panel:new(x, y, w, h, opts)
    local o = E.new(self, x, y, w, h)
    opts = opts or {}
    o.bg = opts.bg == nil and "panel" or opts.bg
    o.borderTok = opts.border == nil and "line" or opts.border
    o.bgAlpha = opts.alpha
    return o
end
function Panel:prerender()
    if self.bg then D.fill(self, 0, 0, self.width, self.height, self.bg, self.bgAlpha) end
    if self.borderTok then D.border(self, 0, 0, self.width, self.height, self.borderTok) end
end

-- ---------------------------------------------------------------- Label
-- Height = line height of the role. opts: align, tok
local Label = E:derive("RSK_Label")
UI.Label = Label
function Label:new(x, y, w, text, role, opts)
    opts = opts or {}
    local o = E.new(self, x, y, w, 20)
    o.text, o.role, o.tok, o.align = text or "", role or "body", opts.tok or "text", opts.align or "left"
    return o
end
function Label:layout()
    self:setX(T.px(self.bx)); self:setY(T.px(self.by)); self:setWidth(T.px(self.bw))
    self:setHeight(D.lineHeight(self.role))
end
function Label:initialise() E.initialise(self); self:layout() end
function Label:setText(t) self.text = t or "" end
function Label:render()
    local x = self.align == "center" and self.width / 2 or (self.align == "right" and self.width or 0)
    D.text(self, self.text, x, 0, self.role, self.tok, self:alpha(), self.align, self.width)
    self:updateTooltip()
end

-- ---------------------------------------------------------------- Button
-- style: primary | secondary | danger | icon. onClick(target, button, arg)
local Button = E:derive("RSK_Button")
UI.Button = Button
function Button:new(x, y, w, h, text, target, onClick, opts)
    opts = opts or {}
    local o = E.new(self, x, y, w, h)
    o.text, o.target, o.onClick = text or "", target, onClick
    o.style, o.icon, o.arg = opts.style or "secondary", opts.icon, opts.arg
    o.iconSize = opts.iconSize or T.base.icon.button
    return o
end
function Button:onMouseDown()
    if not self.enabled then return true end
    self.pressed = true
    return true
end
function Button:onMouseUp()
    if self.pressed and self.enabled then
        self.pressed = false
        if self.onClick then self.onClick(self.target, self, self.arg) end
    end
    self.pressed = false
    return true
end
function Button:onMouseUpOutside() self.pressed = false end

local STYLE = {
    primary   = { bg = "accent", border = nil,      text = "ink" },
    secondary = { bg = "panel2", border = "line",   text = "text" },
    danger    = { bg = "panel2", border = "danger", text = "danger" },
    icon      = { bg = nil,      border = nil,      text = "muted" },
}
function Button:prerender()
    local s, a, w, h = STYLE[self.style] or STYLE.secondary, self:alpha(), self.width, self.height
    local hover = self:isHover()
    if s.bg then D.fill(self, 0, 0, w, h, s.bg, a) end
    if hover then D.fill(self, 0, 0, w, h, "hover", a) end
    local border = self.pressed and "accent" or s.border
    if border then D.border(self, 0, 0, w, h, border, a) end
end
function Button:render()
    local s, a = STYLE[self.style] or STYLE.secondary, self:alpha()
    local tok = (self.style == "icon" and self:isHover()) and "text" or s.text
    if self.icon then
        local sz = T.px(self.iconSize)
        local tex = type(self.icon) == "string" and D.icon(self.icon) or self.icon
        if tex then D.texture(self, tex, (self.width - sz) / 2, (self.height - sz) / 2, sz, sz, tok, a)
        elseif self.text == "" then D.textMid(self, "x", self.width / 2, self.height / 2, "button", tok, a, "center") end
    end
    if self.text ~= "" then
        D.textMid(self, self.text, self.width / 2, self.height / 2, "button", tok, a, "center", self.width - T.px(T.base.space.s) * 2)
    end
    self:updateTooltip()
end
function Button:setText(t) self.text = t or "" end

-- ---------------------------------------------------------------- Toggle
-- Switch 36x20 + text. onChange(target, value, toggle)
local Toggle = E:derive("RSK_Toggle")
UI.Toggle = Toggle
function Toggle:new(x, y, w, text, value, target, onChange)
    local o = E.new(self, x, y, w, 24)
    o.text, o.value, o.target, o.onChange = text or "", value and true or false, target, onChange
    return o
end
function Toggle:onMouseUp()
    if not self.enabled then return true end
    self:setValue(not self.value, true)
    return true
end
function Toggle:setValue(v, notify)
    v = v and true or false
    if v == self.value then return end
    self.value = v
    if notify and self.onChange then self.onChange(self.target, v, self) end
end
function Toggle:render()
    local a, h = self:alpha(), self.height
    local tw, th = T.px(36), T.px(20)
    local ty = math.floor((h - th) / 2)
    local knob = th - T.px(6)
    if self.value then
        D.fill(self, 0, ty, tw, th, "accent", a)
        D.fill(self, tw - knob - T.px(3), ty + T.px(3), knob, knob, "ink", a)
    else
        D.fill(self, 0, ty, tw, th, "panel2", a)
        D.border(self, 0, ty, tw, th, "line", a)
        D.fill(self, T.px(3), ty + T.px(3), knob, knob, "muted", a)
    end
    if self:isHover() then D.border(self, 0, ty, tw, th, "text", a * 0.5) end
    local x = tw + T.px(T.base.space.s)
    D.textMid(self, self.text, x, h / 2, "body", "text", a, "left", self.width - x)
    self:updateTooltip()
end

-- ---------------------------------------------------------------- Slider
-- opts: step, format(v) -> text on the right, onRelease (applies only on release)
-- onChange(target, value, slider)
local Slider = E:derive("RSK_Slider")
UI.Slider = Slider
function Slider:new(x, y, w, min, max, value, target, onChange, opts)
    opts = opts or {}
    local o = E.new(self, x, y, w, 24)
    o.min, o.max, o.step = min, max, opts.step
    o.value = L.clamp(value or min, min, max)
    o.target, o.onChange, o.format, o.onRelease = target, onChange, opts.format, opts.onRelease
    o.valueW = opts.format and (opts.valueW or 56) or 0
    return o
end
function Slider:trackW() return self.width - T.px(self.valueW) - T.px(14) end
function Slider:setValue(v, notify)
    v = L.clamp(v, self.min, self.max)
    if v == self.value then return end
    self.value = v
    if notify and not self.onRelease and self.onChange then self.onChange(self.target, v, self) end
end
function Slider:fromMouse()
    local knob = T.px(14)
    self:setValue(L.sliderValue(self:getMouseX() - knob / 2, self:trackW(), self.min, self.max, self.step), true)
end
function Slider:onMouseDown()
    if not self.enabled then return true end
    self.dragging = true
    self:fromMouse()
    return true
end
function Slider:onMouseMove() if self.dragging then self:fromMouse() end end
function Slider:onMouseMoveOutside() if self.dragging then self:fromMouse() end end
function Slider:release()
    if not self.dragging then return end
    self.dragging = false
    if self.onRelease and self.onChange then self.onChange(self.target, self.value, self) end
end
function Slider:onMouseUp() self:release(); return true end
function Slider:onMouseUpOutside() self:release() end
function Slider:onMouseWheel(del)
    if not self.enabled then return false end
    local step = self.step or (self.max - self.min) / 20
    self:setValue(self.value - del * step, true)
    if self.onRelease and self.onChange then self.onChange(self.target, self.value, self) end
    return true
end
function Slider:render()
    local a, h, knob = self:alpha(), self.height, T.px(14)
    local tw = self:trackW()
    local th = T.px(4)
    local cy = math.floor(h / 2)
    local kx = L.sliderPos(self.value, tw, self.min, self.max)
    D.fill(self, knob / 2, cy - th / 2, tw, th, "panel2", a)
    D.fill(self, knob / 2, cy - th / 2, kx, th, "accent", a)
    D.fill(self, kx, cy - knob / 2, knob, knob, (self.dragging or self:isHover()) and "text" or "accent", a)
    if self.format then
        D.textMid(self, self.format(self.value), self.width, h / 2, "body", "muted", a, "right")
    end
    self:updateTooltip()
end

-- ---------------------------------------------------------------- Tabs
-- items: { { id, text }, ... }. onSelect(target, id, tabs)
local Tabs = E:derive("RSK_Tabs")
UI.Tabs = Tabs
function Tabs:new(x, y, w, items, target, onSelect)
    local o = E.new(self, x, y, w, T.base.h.tab)
    o.items, o.target, o.onSelect = items or {}, target, onSelect
    o.selected = o.items[1] and o.items[1].id
    o.scroll = 0
    return o
end
-- Scrolling that brings the active tab into view; called on tab and width change (D-86).
function Tabs:reveal()
    local rects, index = self:tabRects(), nil
    for i, r in ipairs(rects) do if r.id == self.selected then index = i end end
    self.scroll = L.tabScroll(rects, index, self.width, self.scroll, T.px(T.base.space.xl))
    self.revealedW = self.width
end
function Tabs:onMouseWheel(del)
    local rects = self:tabRects()
    self.scroll = L.tabScroll(rects, nil, self.width, self.scroll + del * T.px(T.base.space.xl * 2), 0)
    return true
end
function Tabs:tabRects()
    local rects, x, pad = {}, 0, T.px(T.base.space.l)
    for i, it in ipairs(self.items) do
        local w = D.measure("button", it.text) + pad * 2
        rects[i] = { x = x, w = w, id = it.id, text = it.text }
        x = x + w
    end
    return rects
end
function Tabs:select(id, notify)
    if id == self.selected then return end
    self.selected = id
    self:reveal()
    if notify and self.onSelect then self.onSelect(self.target, id, self) end
end
function Tabs:onMouseUp(x)
    if not self.enabled then return true end
    local cx = x + self.scroll
    for _, r in ipairs(self:tabRects()) do
        if cx >= r.x and cx < r.x + r.w then self:select(r.id, true) end
    end
    return true
end
function Tabs:render()
    if self.revealedW ~= self.width then self:reveal() end
    local a, h = self:alpha(), self.height
    local line = T.px(T.base.bar.tabLine)
    D.fill(self, 0, h - 1, self.width, 1, "line", a)
    local off = self.scroll
    local mx = self:isMouseOver() and self:getMouseX() + off or -1
    self:setStencilRect(0, 0, self.width, self.height)
    for _, r in ipairs(self:tabRects()) do
        local sel = r.id == self.selected
        local hover = mx >= r.x and mx < r.x + r.w
        local x = r.x - off
        if x + r.w > 0 and x < self.width then
            D.textMid(self, r.text, x + r.w / 2, (h - line) / 2, "button", (sel or hover) and "text" or "muted", a, "center")
            if sel then D.fill(self, x, h - line, r.w, line, "accent", a) end
        end
    end
    self:clearStencilRect()
end

-- ---------------------------------------------------------------- Bar
-- opts: mode = cond | load (colour from thresholds, Stile_UI/D-32) or fixed tok
local Bar = E:derive("RSK_Bar")
UI.Bar = Bar
function Bar:new(x, y, w, h, value, opts)
    opts = opts or {}
    local o = E.new(self, x, y, w, h or T.base.bar.cond)
    o.value, o.mode, o.tok = value or 0, opts.mode, opts.tok
    return o
end
function Bar:setValue(v) self.value = v or 0 end
function Bar:render()
    local a = self:alpha()
    local v = L.clamp(self.value, 0, 1)
    D.fill(self, 0, 0, self.width, self.height, "panel2", a)
    D.fill(self, 0, 0, math.floor(self.width * v + 0.5), self.height, self.tok or L.barToken(self.mode, self.value), a)
    self:updateTooltip()
end
