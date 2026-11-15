-- RSK.UI.Window - themed window (Stile_UI): 44 px title bar on panel2, collapse on the left,
-- close on the right, drag from the title, optional resize from the corner.
-- opts: closable, collapsible, resizable, accent (accent border, e.g. nested bags),
--       headerH (height below the title that stays visible when collapsed, e.g. load bar),
--       minW, minH, onClose(win)
-- Usage: win = Window:new(...):open(), then win:addContent(el) (el.rskHeader = true: stays visible when collapsed).
-- Content is added with win:addContent(el): coordinates relative to the window, y >= win:contentY().
require "RSK/UI/Widgets"

local T, D, L, UI = RSK.Theme, RSK.UI.Draw, RSK.UI.Logic, RSK.UI
local W = UI.Panel:derive("RSK_Window")
UI.Window = W
UI.windows = UI.windows or {}

local GRIP = 12
local BTN = 32

function W:new(x, y, w, h, title, opts)
    opts = opts or {}
    local o = UI.Panel.new(self, x, y, w, h, { bg = "panel", border = opts.accent and "accent" or "line" })
    o.title = title or ""
    o.closable = opts.closable ~= false
    o.collapsible = opts.collapsible ~= false
    o.resizable = opts.resizable == true
    o.headerH = opts.headerH or 0
    o.minW, o.minH = opts.minW or 200, opts.minH or 120
    o.onClose = opts.onClose
    o.content, o.collapsed = {}, false
    o.expandedH = h
    return o
end

function W:titleH() return T.px(T.base.h.title) end
function W:contentY() return T.base.h.title + self.headerH end

function W:createChildren()
    local th = T.base.h.title
    local pad = (th - BTN) / 2
    if self.collapsible then
        self.btnCollapse = UI.add(self, UI.Button:new(pad, pad, BTN, BTN, "", self, W.toggleCollapse, { style = "icon", icon = "expanded" }))
    end
    if self.closable then
        self.btnClose = UI.add(self, UI.Button:new(self.bw - pad - BTN, pad, BTN, BTN, "", self, W.close, { style = "icon", icon = "close" }))
    end
end

function W:layout()
    UI.Panel.layout(self)
    if self.btnClose then self.btnClose.bx = self.bw - (T.base.h.title - BTN) / 2 - BTN end
end

function W:addContent(el)
    UI.add(self, el)
    self.content[#self.content + 1] = el
    if self.collapsed then el:setVisible(false) end
    return el
end

function W:setTitle(t) self.title = t or "" end

function W:toggleCollapse()
    self.collapsed = not self.collapsed
    for _, el in ipairs(self.content) do
        if not el.rskHeader then
            if self.collapsed then el.rskWasVisible = el:isVisible(); el:setVisible(false)
            else el:setVisible(el.rskWasVisible ~= false) end
        end
    end
    if self.collapsed then
        self.expandedH = self.bh
        self.bh = T.base.h.title + self.headerH
    else
        self.bh = self.expandedH
    end
    if self.btnCollapse then self.btnCollapse.icon = self.collapsed and "collapsed" or "expanded" end
    self:layout()
end

function W:open()
    self:initialise()
    self:addToUIManager()
    UI.windows[self] = true
    return self
end

function W:close()
    UI.windows[self] = nil
    self:setVisible(false)
    self:removeFromUIManager()
    if self.onClose then self.onClose(self) end
end

-- ---------------------------------------------------------------- dragging and resizing
local function inGrip(self, x, y)
    local g = T.px(GRIP)
    return self.resizable and not self.collapsed and x >= self.width - g and y >= self.height - g
end

function W:onMouseDown(x, y)
    self:bringToTop()
    if inGrip(self, x, y) then
        self.resizing = { x = getMouseX(), y = getMouseY(), w = self.width, h = self.height }
    elseif y < self:titleH() then
        self.moving = { x = getMouseX() - self:getX(), y = getMouseY() - self:getY() }
    end
    return true
end

local function drag(self)
    local s = T.scale()
    local core = getCore()
    if self.moving then
        local nx = L.clamp(getMouseX() - self.moving.x, 0, core:getScreenWidth() - self.width)
        local ny = L.clamp(getMouseY() - self.moving.y, 0, core:getScreenHeight() - self:titleH())
        self:setX(nx); self:setY(ny)
        self.bx, self.by = nx / s, ny / s
    elseif self.resizing then
        local r = self.resizing
        local nw = math.max(T.px(self.minW), r.w + getMouseX() - r.x)
        local nh = math.max(T.px(self.minH), r.h + getMouseY() - r.y)
        self.bw, self.bh = nw / s, nh / s
        self.expandedH = self.bh
        self:layout()
        for _, c in pairs(self.children or {}) do if c.themeChanged then c:themeChanged() end end
        if self.onResize then self:onResize() end
    end
end
function W:onMouseMove() drag(self) end
function W:onMouseMoveOutside() drag(self) end
local function stop(self) self.moving, self.resizing = nil, nil end
function W:onMouseUp() stop(self); return true end
function W:onMouseUpOutside() stop(self) end

-- ---------------------------------------------------------------- drawing
function W:prerender()
    local th = self:titleH()
    D.fill(self, 0, 0, self.width, self.height, "panel")
    D.fill(self, 0, 0, self.width, th, "panel2")
    D.fill(self, 0, th - 1, self.width, 1, "line")
    local left = self.collapsible and T.px(T.base.h.title) or T.px(T.base.space.l)
    local right = self.closable and T.px(T.base.h.title) or T.px(T.base.space.l)
    D.textMid(self, self.title, left, th / 2, "windowTitle", "text", 1, "left", self.width - left - right)
end

function W:render()
    D.border(self, 0, 0, self.width, self.height, self.borderTok)
    if self.resizable and not self.collapsed then
        local g = T.px(GRIP)
        D.fill(self, self.width - g + T.px(4), self.height - T.px(3), g - T.px(5), T.px(1), "muted")
        D.fill(self, self.width - T.px(3), self.height - g + T.px(4), T.px(1), g - T.px(5), "muted")
    end
end
