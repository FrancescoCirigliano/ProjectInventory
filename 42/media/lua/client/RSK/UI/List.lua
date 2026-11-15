-- RSK.UI.List - virtualised list (RF-0.1, RNF-02): draws only the visible rows.
-- opts: rowH (1080p units, default 52), drawRow(list, item, i, x, y, w, h, state), target,
--       onSelect(target, item, i, list), onDoubleClick(target, item, i, list)
require "RSK/UI/Widgets"

local T, D, L, E = RSK.Theme, RSK.UI.Draw, RSK.UI.Logic, RSK.UI.Element
local List = E:derive("RSK_List")
RSK.UI.List = List

local BAR_W = 6

function List:new(x, y, w, h, opts)
    opts = opts or {}
    local o = E.new(self, x, y, w, h)
    o.rowH = opts.rowH or T.base.h.row
    o.drawRow, o.target = opts.drawRow, opts.target
    o.onSelect, o.onDoubleClick = opts.onSelect, opts.onDoubleClick
    o.items, o.scroll, o.selected = {}, 0, nil
    return o
end

function List:rowPx() return T.px(self.rowH) end
function List:contentH() return #self.items * self:rowPx() end

function List:setItems(items)
    self.items = items or {}
    if self.selected and self.selected > #self.items then self.selected = nil end
    self.scroll = L.clampScroll(self.scroll, self:contentH(), self.height)
end

function List:layout()
    E.layout(self)
    self.scroll = L.clampScroll(self.scroll, self:contentH(), self.height)
end

function List:select(i, notify)
    self.selected = i
    if i then self.scroll = L.scrollToRow(i, self.scroll, self.height, self:rowPx()) end
    if notify and i and self.onSelect then self.onSelect(self.target, self.items[i], i, self) end
end

function List:onMouseWheel(del)
    self.scroll = L.clampScroll(self.scroll + del * self:rowPx() * 2, self:contentH(), self.height)
    return true
end

function List:barX() return self.width - T.px(BAR_W) end

function List:onMouseDown(x, y)
    local ty, th = L.scrollThumb(self.scroll, self:contentH(), self.height, T.px(24))
    if ty and x >= self:barX() then
        if y >= ty and y < ty + th then
            self.dragBar = y - ty
        else
            self.dragBar = th / 2
            self.scroll = L.scrollFromThumb(y - th / 2, self:contentH(), self.height, th)
        end
        return true
    end
    local i = L.rowAt(y, self.scroll, self:rowPx(), #self.items)
    if not i then return true end
    local now = getTimestampMs()
    local dbl = L.isDoubleClick(self.lastClick, i, now)
    self.lastClick = { target = i, time = now }
    self:select(i, true)
    if dbl and self.onDoubleClick then
        self.lastClick = nil
        self.onDoubleClick(self.target, self.items[i], i, self)
    end
    return true
end

local function dragTo(self)
    local _, th = L.scrollThumb(self.scroll, self:contentH(), self.height, T.px(24))
    if th then self.scroll = L.scrollFromThumb(self:getMouseY() - self.dragBar, self:contentH(), self.height, th) end
end
function List:onMouseMove() if self.dragBar then dragTo(self) end end
function List:onMouseMoveOutside() if self.dragBar then dragTo(self) end end
function List:onMouseUp() self.dragBar = nil; return true end
function List:onMouseUpOutside() self.dragBar = nil end

function List:defaultRow(item, i, x, y, w, h)
    local text = type(item) == "table" and (item.text or item.name) or item
    D.textMid(self, text, x + T.px(T.base.space.m), y + h / 2, "row", "text", 1, "left", w - T.px(T.base.space.m) * 2)
end

function List:prerender()
    D.fill(self, 0, 0, self.width, self.height, "bg")
    D.border(self, 0, 0, self.width, self.height, "line")
end

function List:render()
    local rh, w = self:rowPx(), self.width - T.px(BAR_W)
    local hover = self:isMouseOver() and self:getMouseX() < self:barX() and L.rowAt(self:getMouseY(), self.scroll, rh, #self.items)
    local first, last = L.visibleRange(self.scroll, self.height, rh, #self.items)
    self:setStencilRect(0, 0, self.width, self.height)
    for i = first, last do
        local y = (i - 1) * rh - self.scroll
        local sel = i == self.selected
        if sel then D.fill(self, 0, y, w, rh, "sel") elseif i == hover then D.fill(self, 0, y, w, rh, "hover") end
        D.fill(self, 0, y + rh - 1, w, 1, "line", 0.5)
        if sel then D.border(self, 0, y, w, rh, "accent") end
        local state = { selected = sel, hover = i == hover }
        if self.drawRow then self.drawRow(self, self.items[i], i, 0, y, w, rh, state)
        else self:defaultRow(self.items[i], i, 0, y, w, rh) end
    end
    self:clearStencilRect()
    local ty, th = L.scrollThumb(self.scroll, self:contentH(), self.height, T.px(24))
    if ty then
        D.fill(self, self:barX(), ty, T.px(BAR_W), th, self.dragBar and "muted" or "line")
    end
end
