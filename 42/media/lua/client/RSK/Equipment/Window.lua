-- RSK.Equipment.Window - M2, P2.4: equipment and health window (RF-2.1...2.9; D-28...D-35, D-77...D-86).
-- First tab drawn here; Skills, Temperature = moved vanilla panels (D-77); Protection themed (D-147).
-- Treatment always through the vanilla health panel, which stays in its window even when hidden (D-84).
require "ISUI/ISUI3DModel"
require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryItem"
require "XpSystem/ISUI/ISCharacterInfoWindow"
require "XpSystem/ISUI/ISCharacterScreen"
require "XpSystem/ISUI/ISClothingInsPanel"
require "XpSystem/ISUI/ISHealthPanel"
require "RSK/UI/UI"
require "RSK/UI/Mute"
require "RSK/Equipment/Logic"
require "RSK/Equipment/Slot"
require "RSK/Equipment/Exercises"
require "RSK/Equipment/Protection"

local T, D, UI, UL, Mute = RSK.Theme, RSK.UI.Draw, RSK.UI, RSK.UI.Logic, RSK.UI.Mute
local Q = RSK.Equipment
local L = Q.Logic
local Slot = Q.Slot

local WIN = L.WIN
local TITLE, TABS = WIN.TITLE, WIN.TABS
RSK.Config.define("equipment.window", "string", "") -- M2 position and size (D-125)
local PAGE_Y = TITLE + TABS
local GRIP = 14
local BAR_W = 6
local CHECK_MS = 400
local PART_RADIUS = 0.09
local MARK_W, MARK_H = 26, 24
local TIP_W, TIP_PAD, TIP_GAP, TIP_CHIP_H, TIP_CHIP_GAP = 240, 10, 8, 22, 4
local TIP_OPEN_MS, TIP_CLOSE_MS = 140, 90

local function px(n) return T.px(n) end
local function tx(k, ...) return getText("UI_RSK_Eq_" .. k, ...) end

local tex
local function textures()
    if not tex then
        local function get(name) return getTexture("media/ui/RSK/" .. name .. ".png") or nil end
        tex = { tri = get("wound_triangle"), bang = get("wound_bang"), ok = get("wound_ok"), plus = get("wound_plus") }
    end
    return tex
end

-- Marker on the render: triangle with "!" for problems, disc with "+" if the part is only treated (D-35, D-84).
local function drawMark(el, x, y, w, h, tok)
    local t = textures()
    if tok == "ok" then
        local s = math.min(w, h)
        local ox, oy = x + (w - s) / 2, y + (h - s) / 2
        D.texture(el, t.ok, ox, oy, s, s, "ok")
        D.texture(el, t.plus, ox, oy, s, s, "ink")
    else
        D.texture(el, t.tri, x, y, w, h, tok)
        D.texture(el, t.bang, x, y, w, h, "ink")
    end
end

-- Label text: "Laceration (Severe)".
local function lineText(line)
    local text = getText(line.key)
    if line.qual then text = text .. " (" .. getText(line.qual) .. ")" end
    return text
end

-- ---------------------------------------------------------------- render and markers
local Body = RSK.UI.Element:derive("RSK_EquipBody")
Q.Body = Body

function Body:new(x, y, w, h, win)
    local o = RSK.UI.Element.new(self, x, y, w, h)
    o.win = win
    return o
end

function Body:markRect(w)
    local cx, cy = L.partPos(w.partName, self.width, self.height)
    if not cx then return nil end
    local mw, mh = px(MARK_W), px(MARK_H)
    return cx - mw / 2, cy - mh / 2, mw, mh
end

-- Marker under the mouse; if two overlap, the one with the closest centre.
function Body:markUnderMouse()
    local mx, my = self:getMouseX(), self:getMouseY()
    local best, bestD
    for _, w in ipairs(self.win.wounds or {}) do
        local x, y, mw, mh = self:markRect(w)
        if x and mx >= x and mx < x + mw and my >= y and my < y + mh then
            local dx, dy = mx - (x + mw / 2), my - (y + mh / 2)
            local d = dx * dx + dy * dy
            if not bestD or d < bestD then best, bestD = w, d end
        end
    end
    return best
end

function Body:partUnderMouse()
    local mark = self:markUnderMouse()
    if mark then return mark.bp end
    local name = L.partAt(self:getMouseX(), self:getMouseY(), self.width, self.height, PART_RADIUS)
    return name and self.win:bodyPartByName(name) or nil
end

function Body:onMouseDown() self.win:bringToTop(); return true end

function Body:onMouseUp()
    local bp = self:partUnderMouse()
    if ISMouseDrag.dragging then
        local focus = ISMouseDrag.draggingFocus
        if bp then
            self.win:healthView():dropItemsOnBodyPart(bp, ISInventoryPane.getActualItems(ISMouseDrag.dragging))
        end
        ISMouseDrag.dragging, ISMouseDrag.draggingFocus = nil, nil
        if focus then focus:onMouseUp(0, 0) end
        return true
    end
    if bp then self.win:partMenu(bp) end
    return true
end

function Body:onRightMouseUp()
    local bp = self:partUnderMouse()
    if bp then self.win:partMenu(bp) end
    return true
end

function Body:render()
    local mark = self:isMouseOver() and not ISMouseDrag.dragging and self:markUnderMouse() or nil
    for _, w in ipairs(self.win.wounds or {}) do
        local x, y, mw, mh = self:markRect(w)
        if x then
            drawMark(self, x, y, mw, mh, w.tok)
            if w == mark then D.border(self, x - 1, y - 1, mw + 2, mh + 2, "text") end
        end
    end
    self.win:setHoverWound(mark, self)
end

-- ---------------------------------------------------------------- "Equip. & health" page
local Page = UI.Panel:derive("RSK_EquipPage")
Q.Page = Page

function Page:new(x, y, w, h, win)
    local o = UI.Panel.new(self, x, y, w, h, { bg = false, border = false })
    o.win = win
    return o
end

local function drawLook(self, lay, x, role, text)
    local room = px(lay.lookColW - lay.lookBtnW - 8)
    local y = px(lay.lookRowY)
    D.text(self, role, x, y, "label", "muted", 1, "left", room)
    D.text(self, text or "", x, y + D.lineHeight("label") + px(1), "infoText", "text", 1, "left", room)
end

function Page:prerender()
    local win = self.win
    local lay = win.lay
    -- As in vanilla: the model look is read in the draw frame, after the character update.
    win:applyModelIfDirty()
    local w, pad = self.width, px(lay.pad)
    local cy = px(lay.healthH) / 2
    D.textMid(self, tx("Health"), pad, cy, "label", "muted")
    local pct = L.percentText(win.health or 0)
    -- Weight to the right of the bar and the percentage (D-95).
    local right = w - pad
    if win.weightText then
        local weightW = D.textMid(self, win.weightText, right, cy, "infoText", "muted", 1, "right")
        right = right - weightW - px(12)
    end
    local pw = D.textMid(self, pct, right, cy, "number", "text", 1, "right")
    local lw = D.measure("label", tx("Health"))
    local bx, bh = pad + lw + px(12), px(T.base.bar.health)
    local bw = right - pw - px(12) - bx
    if bw > 0 then
        D.fill(self, bx, cy - bh / 2, bw, bh, "panel2")
        local f = UL.clamp((win.health or 0) / 100, 0, 1)
        if f > 0 then D.fill(self, bx, cy - bh / 2, math.max(1, math.floor(bw * f)), bh, UL.barToken("cond", f)) end
    end
    D.fill(self, 0, px(lay.healthH), w, 1, "line")
    D.fill(self, px(lay.centerX), px(lay.gridY), px(lay.centerW), px(lay.centerH), "bg")

    -- Protections (D-30, D-86, D-88): three labels of equal width
    local y, h, cw = px(lay.protY), px(lay.protH), px(lay.chipW)
    for i, c in ipairs(win.chips or {}) do
        local x = pad + (i - 1) * px(lay.chipW + lay.chipGap)
        local vw = D.measure("infoValue", c.value)
        D.fill(self, x, y, cw, h, "panel2")
        D.textMid(self, c.label, x + px(8), y + h / 2, "infoLabel", "muted", 1, "left", cw - vw - px(20))
        D.textMid(self, c.value, x + cw - px(8), y + h / 2, "infoValue", "text", 1, "right")
    end

    -- Kills and survival time, right below health (D-95): the value takes priority over the label
    y, h, cw = px(lay.statsY), px(lay.statsH), px(lay.statW)
    for i, c in ipairs(win.stats or {}) do
        local x = pad + (i - 1) * (cw + px(lay.chipGap))
        local vw = math.min(D.measure("infoValue", c.value), cw - px(40))
        D.fill(self, x, y, cw, h, "panel2")
        D.textMid(self, c.label, x + px(8), y + h / 2, "infoLabel", "muted", 1, "left", cw - vw - px(20))
        D.textMid(self, c.value, x + cw - px(8), y + h / 2, "infoValue", "text", 1, "right", vw + 1)
    end

    -- Hair and beard (D-85)
    D.fill(self, 0, px(lay.lookY), w, 1, "line")
    drawLook(self, lay, pad, getText("IGUI_char_HairStyle"), win.hairText)
    if win.hasBeard then
        drawLook(self, lay, pad + px(lay.lookColW + 12), getText("IGUI_char_BeardStyle"), win.beardText)
    end
end

-- ---------------------------------------------------------------- vanilla tab area (D-88)
-- Clips the active panel to the area and scrolls it if it is larger.
local Scroller = RSK.UI.Element:derive("RSK_EquipScroller")
Q.Scroller = Scroller

function Scroller:new(x, y, w, h)
    local o = RSK.UI.Element.new(self, x, y, w, h)
    o.sx, o.sy = 0, 0
    return o
end

-- Brings the panel to its required size; forgets the request of panels that never shrink by themselves.
function Scroller:fitView(view, forget)
    if not view then return end
    if forget then view.rskWantW, view.rskWantH = nil, nil end
    local w, h = L.viewSize(self.width, self.height, view.rskWantW, view.rskWantH, view.vscroll ~= nil)
    if view:getWidth() ~= w then view:setWidth(w) end
    if view:getHeight() ~= h then view:setHeight(h) end
    if view.vscroll then
        view.vscroll:setX(w - view.vscroll:getWidth())
        view.vscroll:setHeight(h)
    end
    self.sx = UL.clampScroll(self.sx, w, self.width)
    self.sy = UL.clampScroll(self.sy, h, self.height)
    view:setX(-self.sx); view:setY(-self.sy)
    self.view = view
end

function Scroller:onMouseWheel(del)
    local v = self.view
    if not v then return false end
    local step = del * px(48)
    if isShiftKeyDown() then self.sx = self.sx + step
    elseif v.vscroll then return false
    else self.sy = self.sy + step end
    self:fitView(v)
    return true
end

function Scroller:prerender() self:setStencilRect(0, 0, self.width, self.height) end

function Scroller:render()
    self:clearStencilRect()
    local v = self.view
    if not v then return end
    local bar = px(BAR_W)
    local ty, th = UL.scrollThumb(self.sy, v:getHeight(), self.height, px(24))
    if ty then D.fill(self, self.width - bar, ty, bar, th, "line") end
    local tx0, tw = UL.scrollThumb(self.sx, v:getWidth(), self.width, px(24))
    if tx0 then D.fill(self, tx0, self.height - bar, tw, bar, "line") end
end

-- Skills tab header (D-92): occupation, traits, weight, favourite weapon, Literature.
local Profile = RSK.UI.Element:derive("RSK_EquipProfile")
Q.Profile = Profile

function Profile:new(x, y, w, win)
    local o = RSK.UI.Element.new(self, x, y, w, WIN.PROFILE)
    o.win = win
    return o
end

function Profile:createChildren()
    self.literature = UI.add(self, UI.Button:new(self.bw - 16 - 104, (WIN.PROFILE - 26) / 2, 104, 26,
        getText("IGUI_LiteratureUI_Title"), self.win, function(win) win:onLiterature() end))
end

-- Button as wide as its text, never clipped (D-95): UI.Button keeps an 8 margin per side.
function Profile:arrange(w, pad)
    local text = self.literature.text
    local bw = math.ceil(D.measure("button", text) / T.scale()) + 2 * T.base.space.s + 4
    self.literature:setBase(w - pad - bw, (WIN.PROFILE - 26) / 2, bw, 26)
end

function Profile:prerender()
    local win, w, h = self.win, self.width, self.height
    D.fill(self, 0, 0, w, h, "panel2")
    D.fill(self, 0, h - 1, w, 1, "line")
    local p = win.profile
    if not p then return end
    local pad, icon = px(16), px(36)
    local x = pad
    if p.texture then
        local iy = (h - icon) / 2
        D.fill(self, pad, iy, icon, icon, "bg")
        self:drawTextureScaledAspect(p.texture, pad, iy, icon, icon, 1, 1, 1, 1)
        x = pad + icon + px(10)
    end
    local room = self.literature:getX() - x - px(8)
    local nameW = D.text(self, p.name or "", x, px(6), "itemName", "text", 1, "left", room)
    if p.details and room - nameW > px(40) then
        D.textMid(self, " \194\183 " .. p.details, x + nameW, px(6) + D.lineHeight("itemName") / 2, "infoLabel", "muted", 1, "left", room - nameW)
    end

    -- Traits: icons with name and description on hover, below the occupation.
    local s, gap = px(18), px(4)
    local tx0, ty = x, h - s - px(7)
    local mx, my = self:getMouseX(), self:getMouseY()
    local over = self:isMouseOver()
    local hover
    for _, trait in ipairs(p.traits or {}) do
        if tx0 + s > self.literature:getX() - px(8) then break end
        self:drawTextureScaledAspect(trait:getTexture(), tx0, ty, s, s, 1, 1, 1, 1)
        if over and mx >= tx0 and mx < tx0 + s and my >= ty and my < ty + s then hover = trait end
        tx0 = tx0 + s + gap
    end
    if hover then
        self.tooltipText = hover:getLabel() .. "\n" .. hover:getDescription()
        self:updateTooltip()
    elseif UI.Tooltip.owner == self then
        UI.Tooltip.hide()
    end
end

-- Themed buttons of the vanilla panels (D-94): drawing muted, logic unchanged.
local function themedPre(b)
    local on = b.enable ~= false
    local parent = b.parent
    local selected = parent and parent.titleColor ~= nil and b.textColor == parent.titleColor
    local hover = on and b:isMouseOver()
    D.fill(b, 0, 0, b.width, b.height, hover and "sel" or "panel2", on and 1 or T.alpha.disabled)
    D.border(b, 0, 0, b.width, b.height, (selected or hover) and "accent" or "line")
end

local function themedPost(b)
    local a = b.enable == false and T.alpha.disabled or 1
    local title = b.title or ""
    if title == "" and b.image then
        local s = math.min(b.width, b.height) - px(8)
        D.texture(b, b.image, (b.width - s) / 2, (b.height - s) / 2, s, s, "muted", a)
        return
    end
    local parent = b.parent
    local selected = parent and parent.titleColor ~= nil and b.textColor == parent.titleColor
    D.textMid(b, title, b.width / 2, b.height / 2, "rowSmall", selected and "accent" or "text", a, "center", b.width - px(8))
end

local function equipmentOn() return RSK.Core.isActive("Equipment") end

-- Skills tab sections (D-116): the vanilla tree buttons become the title row, as wide as
-- the panel, with no icon; the click stays vanilla (collapseSection). The row covers the vanilla title.
local function sectionIndex(b) return tonumber(tostring(b.internal or ""):match("^COLLAPSE(%d+)$")) end

local function sectionPre(b)
    local v = b.parent
    local w = v and v.width or b.width
    if v and v.vscroll and v.vscroll:getIsVisible() then w = w - v.vscroll:getWidth() end
    if b.x ~= 0 then b:setX(0) end
    if b.width ~= w then b:setWidth(w) end
    D.fill(b, 0, 0, b.width, b.height, "panel")
    if b:isMouseOver() then D.fill(b, 0, 0, b.width, b.height, "hover") end
end

local function sectionPost(b)
    local v, i = b.parent, sectionIndex(b)
    local perk = v and i and v.sorted and v.sorted[i]
    if not perk then return end
    local closed = v.collapse and v.collapse[i]
    D.textMid(b, perk:getName(), px(8), b.height / 2, "label", (closed and not b:isMouseOver()) and "muted" or "text",
        1, "left", b.width - px(16))
end

-- Vanilla draws the section title in its render, after the children: only that text is skipped
-- (text = section name, x = vanilla title column); the rest of the panel stays vanilla.
local function muteSectionTitles(view)
    local titles = {}
    for _, perk in ipairs(view.sorted or {}) do titles[perk:getName()] = true end
    -- as in ISCharacterInfo: UI_BORDER_SPACING (10) * 2 + BUTTON_HGT (UIFont.Small height + 6) + 1
    local titleX = 10 * 2 + getTextManager():getFontHeight(UIFont.Small) + 6 + 1
    view.drawText = function(v, text, x, ...)
        if equipmentOn() and titles[text] and x == titleX then return end
        return ISUIElement.drawText(v, text, x, ...)
    end
    -- vanilla line (SkillBarSeparator) below the title of every open section: removed
    view.drawTexture = function(v, texture, ...)
        if equipmentOn() and texture ~= nil and texture == v.SkillBarSeparator then return end
        return ISUIElement.drawTexture(v, texture, ...)
    end
end

-- ISCharacterInfo section buttons; original widths saved to restore vanilla.
local function skinSections(owner, view)
    muteSectionTitles(view)
    local saved = {}
    for _, b in ipairs(view.buttonList or {}) do
        if sectionIndex(b) then
            saved[b] = { x = b:getX(), w = b:getWidth() }
            Mute.skin(b, sectionPre, sectionPost, equipmentOn)
            owner[b] = true
        end
    end
    return saved
end

local function skinButtons(owner, el)
    for _, c in pairs(el:getChildren() or {}) do
        if c.Type == "ISButton" then
            Mute.skin(c, themedPre, themedPost, equipmentOn)
            owner[c] = true
        elseif c.Type ~= "ISScrollBar" then
            skinButtons(owner, c)
        end
    end
end

-- Temperature (D-90, D-94): vanilla places the "skin temperature" part below the tallest of all
-- views, even the advanced view with a selected part, forcing a scroll. Here it follows the current view.
local ClothingPanel = ISClothingInsPanel:derive("RSK_ClothingPanel")

local function visibleBottom(list, bottom)
    for _, widget in ipairs(list or {}) do
        if widget:getIsVisible() then bottom = math.max(bottom, widget:getBottom()) end
    end
    return bottom
end

function ClothingPanel:reflow()
    if not self.toggleAdvBtn then return end
    local spacing = 10
    local id = self.currentViewID
    local bottom = visibleBottom(self.mainGroup, 0)
    bottom = visibleBottom(self.mainGroupViews[id], bottom)
    bottom = visibleBottom(self.nodeGroup, bottom)
    bottom = visibleBottom(self.nodeGroupViews[id], bottom)
    self.coreRectangleH = bottom
    local tm = getTextManager()
    local btn = tm:getFontHeight(UIFont.Small) + 6
    local y = math.max(320, bottom + spacing * 2 + 1)
    self.labelCurrentView:setY(y)
    y = y + tm:getFontHeight(UIFont.Medium) + 6
    self.labelCurrentViewMid:setY(y); self.labelCurrentViewMin:setY(y); self.labelCurrentViewMax:setY(y)
    y = y + btn
    self.legendBar:setY(y)
    self.toggleAdvBtn:setY(y + spacing * 3)
    self.rskSelection = self.selectedBodyPart
end

function ClothingPanel:setViewStyle(style, force)
    ISClothingInsPanel.setViewStyle(self, style, force)
    self:reflow()
end

-- The selection comes from ISBodyPartPanel, which calls the vanilla function directly.
function ClothingPanel:update()
    if ISClothingInsPanel.update then ISClothingInsPanel.update(self) end
    if self.selectedBodyPart ~= self.rskSelection then self:reflow() end
end

-- Corner grip: child on top of the others, otherwise page and tabs would take the click.
local Grip = RSK.UI.Element:derive("RSK_EquipGrip")
Q.Grip = Grip

function Grip:new(win)
    local o = RSK.UI.Element.new(self, win.bw - GRIP, win.bh - GRIP, GRIP, GRIP)
    o.win = win
    return o
end

function Grip:onMouseDown()
    local win = self.win
    win:bringToTop()
    win.userPlaced = true -- from here on the window no longer snaps to the inventory
    win.resizing = { x = getMouseX(), y = getMouseY(), w = win.width, h = win.height }
    return true
end
function Grip:onMouseMove() UI.Window.onMouseMove(self.win) end
function Grip:onMouseMoveOutside() UI.Window.onMouseMoveOutside(self.win) end
function Grip:onMouseUp()
    local was = self.win.resizing ~= nil
    self.win.resizing = nil
    self.win:arrange() -- at the end of the drag: rebuilds the Temperature panel (D-90)
    if was then self.win:saveGeom() end
    return true
end
function Grip:onMouseUpOutside()
    local was = self.win.resizing ~= nil
    self.win.resizing = nil
    self.win:arrange()
    if was then self.win:saveGeom() end
end

-- ---------------------------------------------------------------- window
local W = UI.Window:derive("RSK_EquipWindow")
Q.Window = W

function W:new(cw, playerNum)
    local player = getSpecificPlayer(playerNum)
    local d = player:getDescriptor()
    local name = d:getForename() .. " " .. d:getSurname()
    local saved = L.parseGeom(RSK.Config.get("equipment.window")) -- D-125
    local w, h = saved and saved.w or WIN.W, saved and saved.h or WIN.H
    local o = UI.Window.new(self, saved and saved.x or 0, saved and saved.y or 0, w, h, name, {
        collapsible = false, resizable = true, minW = WIN.MIN_W, minH = WIN.MIN_H,
    })
    o.lay = L.layout(w, h)
    o.userPlaced = saved ~= nil
    o.cw, o.playerNum, o.tab = cw, playerNum, "equip"
    o.dirty, o.nextCheck, o.modelDirty = true, 0, true
    o.slots, o.tabViews = {}, {}
    return o
end

function W:healthView() return self.cw.healthView end

function W:createChildren()
    UI.Window.createChildren(self)
    local lay = self.lay
    self.scroller = self:addContent(Scroller:new(0, PAGE_Y, lay.w, lay.pageH))
    -- The scrolling panel can end up under the title: the close button stays on top.
    if self.btnClose then
        self:removeChild(self.btnClose)
        self:addChild(self.btnClose)
    end
    local items = { { id = "equip", text = tx("TabEquip") } }
    local view = self.cw.characterView
    if view and view.parent == self.cw.panel then -- tab detached by hand in vanilla: it stays detached
        items[#items + 1] = { id = "skills", text = xpSystemText.skills }
        self:borrow("skills", view)
    end
    items[#items + 1] = { id = "fitness", text = tx("TabFitness") } -- D-95
    items[#items + 1] = { id = "protection", text = xpSystemText.protection } -- own panel (D-147)
    items[#items + 1] = { id = "clothingIns", text = xpSystemText.clothingIns }
    self:buildClothing()
    self.exercises = self:addContent(Q.Exercises:new(0, PAGE_Y, lay.w, lay.pageH, self))
    self.protection = self:addContent(Q.Protection:new(0, PAGE_Y, lay.w, lay.pageH, self))
    self.profile_ = self:addContent(Profile:new(0, PAGE_Y, lay.w, self))
    self.tabsEl = self:addContent(UI.Tabs:new(8, TITLE, lay.w - 16, items, self, W.onTab))

    local page = Page:new(0, PAGE_Y, lay.w, lay.pageH, self)
    self.page = self:addContent(page)

    local model = ISUI3DModel:new(px(lay.centerX), px(lay.gridY), px(lay.centerW), px(lay.modelH))
    model:initialise()
    model:instantiate()
    page:addChild(model)
    model:setOutfitName("Foreman", false, false)
    model:setState("idle")
    model:setDirection(IsoDirections.S)
    model:setIsometric(false)
    self.model = model

    self.body = UI.add(page, Body:new(lay.centerX, lay.gridY, lay.centerW, lay.modelH, self))

    for _, list in ipairs({ L.SLOTS_LEFT, L.SLOTS_RIGHT, L.SLOTS_WEAPON }) do
        for _, id in ipairs(list) do self.slots[id] = UI.add(page, Slot:new(0, 0, self, id)) end
    end

    local change = getText("IGUI_PlayerStats_Change")
    self.hairBtn = UI.add(page, UI.Button:new(0, 0, lay.lookBtnW, lay.lookBtnH, change, self, W.onHair))
    self.beardBtn = UI.add(page, UI.Button:new(0, 0, lay.lookBtnW, lay.lookBtnH, change, self, W.onBeard))
    self.grip = UI.add(self, Grip:new(self))
    self:arrange()
    self:applyTab()
end

-- Lays out the first tab and the vanilla tab area at the current size (D-88).
function W:arrange()
    local lay = L.layout(self.bw, self.bh)
    self.lay = lay
    self.tabsEl:setBase(nil, nil, lay.w - 16, nil)
    self.page:setBase(nil, nil, lay.w, lay.pageH)
    self.exercises:setBase(nil, nil, lay.w, lay.pageH)
    self.exercises:arrange()
    self.protection:setBase(nil, nil, lay.w, lay.pageH)
    self.protection:arrange()
    self.profile_:setBase(nil, nil, lay.w, nil)
    self.profile_:arrange(lay.w, lay.pad)
    self:arrangeArea()
    local m = self.model
    m:setX(px(lay.centerX)); m:setY(px(lay.gridY)); m:setWidth(px(lay.centerW)); m:setHeight(px(lay.modelH))
    self.body:setBase(lay.centerX, lay.gridY, lay.centerW, lay.modelH)
    for i, id in ipairs(L.SLOTS_LEFT) do self.slots[id]:setBase(lay.leftX, lay.gridY + (i - 1) * lay.slotStep) end
    for i, id in ipairs(L.SLOTS_RIGHT) do self.slots[id]:setBase(lay.rightX, lay.gridY + (i - 1) * lay.slotStep) end
    for i, id in ipairs(L.SLOTS_WEAPON) do self.slots[id]:setBase(lay.weaponX + (i - 1) * lay.weaponStep, lay.weaponY) end
    local bx = lay.pad + lay.lookColW - lay.lookBtnW
    self.hairBtn:setBase(bx, lay.lookRowY)
    self.beardBtn:setBase(bx + lay.lookColW + 12, lay.lookRowY)
    self.grip:setBase(lay.w - GRIP, lay.h - GRIP)
    local clothing = self.tabViews.clothingIns
    if clothing and not self.resizing and clothing.builtW ~= self.scroller:getWidth() then self:buildClothing() end
    for _, t in pairs(self.tabViews) do self.scroller:fitView(t.view, true) end
    local active = self.tabViews[self.tab]
    if active then self.scroller:fitView(active.view) end
    self.tabsEl:reveal()
end

-- Vanilla panel area: in the Skills tab it starts below the header (D-92).
function W:arrangeArea()
    local lay = self.lay
    local head = self.tab == "skills" and WIN.PROFILE or 0
    self.scroller:setBase(0, PAGE_Y + head, lay.w, lay.pageH - head)
end

-- Grip drag (UI.Window updates bw and bh).
function W:onResize() self:arrange() end

-- ---------------------------------------------------------------- vanilla tabs (D-77, D-88, D-90)
-- The panel asks for a size: the window does not change, the area uses it to scroll the panel.
local function captureSize(view)
    view.setWidthAndParentWidth = function(v, w) v.rskWantW = w end
    view.setHeightAndParentHeight = function(v, h) v.rskWantH = h end
end

function W:borrow(id, view)
    local panel = self.cw.panel
    local saved = { x = view:getX(), y = view:getY(), w = view:getWidth(), h = view:getHeight() }
    panel:removeChild(view)
    self.scroller:addChild(view)
    view:setX(0); view:setY(0)
    captureSize(view)
    local skinned = {}
    skinButtons(skinned, view)
    local sections = id == "skills" and skinSections(skinned, view) or nil
    view:setVisible(false)
    self.tabViews[id] = { view = view, saved = saved, skinned = skinned, sections = sections }
end

-- Temperature tab (D-90): ISClothingInsPanel fixes its children's sizes on creation, so an instance
-- is built on the area width; selected view and part move to the new one. The vanilla one is untouched.
function W:buildClothing()
    local old = self.tabViews.clothingIns
    local style, index
    if old then
        style, index = old.view.currentViewID, old.view.selectedViewIndex
        self.scroller:removeChild(old.view)
    end
    local w, h = self.scroller:getWidth(), self.scroller:getHeight()
    local view = ClothingPanel:new(getSpecificPlayer(self.playerNum), 0, 0, w, h)
    view:initialise()
    self.scroller:addChild(view)
    captureSize(view)
    skinButtons({}, view)
    view:reflow()
    if style then view:setViewStyle(style, true) end
    if index then view:setViewIndex(index) end
    local active = self.tab == "clothingIns"
    view:setVisible(active)
    self.tabViews.clothingIns = { view = view, own = true, builtW = w }
    if active then self.scroller.view = view end
end

function W:releaseViews()
    local panel = self.cw.panel
    for _, t in pairs(self.tabViews) do
        local v, s = t.view, t.saved
        self.scroller:removeChild(v)
        if not t.own then
            panel:addChild(v)
            for button in pairs(t.skinned or {}) do Mute.unskin(button) end
            for button, g in pairs(t.sections or {}) do button:setX(g.x); button:setWidth(g.w) end
            if t.sections then v.drawText = nil; v.drawTexture = nil end -- class methods come back
            v.setWidthAndParentWidth = nil
            v.setHeightAndParentHeight = nil
            v.rskWantW = nil
            v.rskWantH = nil
            v:setX(s.x); v:setY(s.y); v:setWidth(s.w); v:setHeight(s.h)
            v:setVisible(v == panel:getActiveView())
        end
    end
    self.tabViews = {}
end

-- Vanilla SaveLayout checks view.parent: moved panels still appear in their tab.
function W:withViewsAtHome(fn)
    local panel = self.cw.panel
    for _, t in pairs(self.tabViews) do if not t.own then t.view.parent = panel end end
    local ok, err = pcall(fn)
    for _, t in pairs(self.tabViews) do if not t.own then t.view.parent = self.scroller end end
    if not ok then error(err, 0) end
end

function W:hasTab(id) return id == "equip" or id == "protection" or self.tabViews[id] ~= nil end

function W:applyTab()
    local equip = self.tab == "equip"
    local fitness = self.tab == "fitness"
    local protection = self.tab == "protection"
    self.page:setVisible(equip)
    self.exercises:setVisible(fitness)
    self.protection:setVisible(protection)
    if protection then self.protection:refresh() end
    self.profile_:setVisible(self.tab == "skills")
    self.scroller:setVisible(not equip and not fitness and not protection)
    self:arrangeArea()
    for id, t in pairs(self.tabViews) do t.view:setVisible(id == self.tab) end
    self.tabsEl:select(self.tab, false)
    self.tabsEl:reveal()
    self.scroller.sx, self.scroller.sy = 0, 0
    local active = self.tabViews[self.tab]
    self.scroller.view = active and active.view or nil
    if active then self.scroller:fitView(active.view) end
    self:hideTip()
    self:setHoverWound(nil)
end

function W:onTab(id)
    self.tab = id
    self:applyTab()
end

-- ---------------------------------------------------------------- data
function W:bodyPartByName(name)
    local parts = getSpecificPlayer(self.playerNum):getBodyDamage():getBodyParts()
    for i = 1, parts:size() do
        local bp = parts:get(i - 1)
        if BodyPartType.ToString(bp:getType()) == name then return bp end
    end
    return nil
end

-- Hotbar back slot and its index.
function W:backSlot()
    local hotbar = getPlayerHotbar(self.playerNum)
    if not hotbar or not hotbar.availableSlot then return nil end
    for i, slot in pairs(hotbar.availableSlot) do
        if slot.def and slot.def.name == "Back" and slot.def.attachments then return slot, i end
    end
    return nil
end

function W:refreshSlots(player)
    local entries, worn, ids = {}, player:getWornItems(), {}
    for i = 1, worn:size() do
        local w = worn:get(i - 1)
        local item = w:getItem()
        if item then
            ids[#ids + 1] = tostring(item:getID())
            if not item:isHidden() then entries[#entries + 1] = { item = item, location = w:getLocation() } end
        end
    end
    local groups = L.groupWorn(entries)
    for _, list in ipairs({ L.SLOTS_LEFT, L.SLOTS_RIGHT }) do
        for _, id in ipairs(list) do self.slots[id]:setItems(groups[id] or {}) end
    end
    local primary, secondary = player:getPrimaryHandItem(), player:getSecondaryHandItem()
    self.slots.primary:setItems(primary and { primary } or {})
    self.slots.secondary:setItems(secondary and { secondary } or {})
    local slot, index = self:backSlot()
    local hotbar = getPlayerHotbar(self.playerNum)
    local back = slot and hotbar.attachedItems and hotbar.attachedItems[index]
    self.slots.backWeapon:setItems(back and { back } or {})

    ids[#ids + 1] = primary and tostring(primary:getID()) or "-"
    ids[#ids + 1] = secondary and tostring(secondary:getID()) or "-"
    ids[#ids + 1] = back and tostring(back:getID()) or "-"
    local sig = L.signature(ids)
    if sig ~= self.modelSig then
        self.modelSig = sig
        self.modelDirty = true
    end
end

local function partSnapshot(bp, doctor)
    return {
        doctor = doctor, bitten = bp:bitten(), deep = bp:deepWounded(), deepTime = bp:getDeepWoundTime(),
        fractureTime = bp:getFractureTime(), splint = bp:getSplintFactor(), burnTime = bp:getBurnTime(),
        burnWash = bp:isNeedBurnWash(), bullet = bp:haveBullet(), glass = bp:haveGlass(),
        infected = bp:isInfectedWound(), infectionLevel = bp:getWoundInfectionLevel(), cut = bp:isCut(),
        cutTime = bp:getCutTime(), scratched = bp:scratched(), scratchTime = bp:getScratchTime(),
        bleeding = bp:bleeding(), bandaged = bp:bandaged(), bandageLife = bp:getBandageLife(),
        stitched = bp:stitched(), stitchTime = bp:getStitchTime(), plantain = bp:getPlantainFactor(),
        comfrey = bp:getComfreyFactor(), garlic = bp:getGarlicFactor(),
    }
end

function W:refreshWounds(player)
    local bd = player:getBodyDamage()
    self.health = bd:getHealth()
    local doctor = player:getPerkLevel(Perks.Doctor)
    local wounds, parts = {}, bd:getBodyParts()
    local previous = {}
    for _, old in ipairs(self.wounds or {}) do previous[old.partName] = old end
    for i = 1, parts:size() do
        local bp = parts:get(i - 1)
        local w = L.wound(partSnapshot(bp, doctor))
        if w then
            w.bp = bp
            w.partName = BodyPartType.ToString(bp:getType())
            w.part = BodyPartType.getDisplayName(bp:getType())
            for _, line in ipairs(w.lines) do line.text = lineText(line) end
            wounds[#wounds + 1] = w
            -- The open tooltip follows the new data without restarting the animation.
            if self.tipWound and previous[w.partName] == self.tipWound then self.tipWound = w end
        end
    end
    self.wounds = wounds
end

function W:refreshProtection(player)
    local bite, scratch, ins = {}, {}, {}
    local thermos = player:getBodyDamage():getThermoregulator()
    for i = 0, BodyPartType.ToIndex(BodyPartType.MAX) - 1 do
        bite[#bite + 1] = player:getBodyPartClothingDefense(i, true, false)
        scratch[#scratch + 1] = player:getBodyPartClothingDefense(i, false, false)
        local node = thermos and thermos:getNodeForType(BodyPartType.FromIndex(i))
        if node then ins[#ins + 1] = node:getInsulation() end
    end
    self.chips = {
        { label = getText("UI_RSK_Tip_Bite"), value = L.percentText(L.average(bite)) },
        { label = getText("UI_RSK_Tip_Scratch"), value = L.percentText(L.average(scratch)) },
    }
    if #ins > 0 then
        self.chips[3] = { label = getText("UI_RSK_Tip_Insulation"), value = L.oneDecimal(L.average(ins)) }
    end
end

-- Kills and time (D-92). Time only if the clock shows the date, as in vanilla.
function W:refreshStats(player)
    self.stats = { { label = getText("IGUI_char_Zombies_Killed"), value = tostring(player:getZombieKills()) } }
    local clock = UIManager.getClock()
    if clock and clock:isDateVisible() then
        self.stats[2] = { label = getText("IGUI_char_Survived_For"), value = player:getTimeSurvived() }
    end
    self.weightText = getText("IGUI_char_Weight") .. " " .. tostring(round(player:getNutrition():getWeight(), 0))
end

-- Skills header (D-92): data read from the vanilla Info panel, which stays in its window.
function W:refreshProfile(player)
    local cs = self.cw.charScreen
    if not cs then return end
    cs:loadProfession()
    ISCharacterScreen.loadFavouriteWeapon(cs)
    cs:setDisplayedTraits()
    local details
    if cs.favouriteWeapon then
        details = getText("IGUI_char_Favourite_Weapon") .. " " .. cs.favouriteWeapon
    end
    self.profile = { name = cs.profession, texture = cs.professionTexture, details = details, traits = cs.displayedTraits }
end

-- Same checks as ISCharacterScreen:render for the Change buttons (D-85).
local function setLookButton(btn, level, reason)
    local on = isDebugEnabled() or (level ~= nil and level > 0)
    btn:setEnabled(on)
    btn:setTooltip(not on and reason or nil)
end

function W:refreshLook(player)
    local cs = self.cw.charScreen
    if not cs then return end
    cs:loadBeardAndHairStyle()
    self.hairText, self.beardText = cs.hairStyle, cs.beardStyle
    self.hasBeard = not player:isFemale()
    local hairs = getHairStylesInstance()
    local model = player:getHumanVisual():getHairModel()
    local hair = player:isFemale() and hairs:FindFemaleStyle(model) or hairs:FindMaleStyle(model)
    setLookButton(self.hairBtn, hair and hair:getLevel() or nil, getText("Tooltip_NoHair"))
    self.beardBtn:setVisible(self.hasBeard)
    if self.hasBeard then
        local beard = getBeardStylesInstance():FindStyle(player:getHumanVisual():getBeardModel())
        setLookButton(self.beardBtn, beard and beard:getLevel() or nil, getText("Tooltip_NoBeard"))
    end
end

function W:refresh()
    local player = getSpecificPlayer(self.playerNum)
    if not player or player:isDead() then return end
    self:refreshSlots(player)
    self:refreshWounds(player)
    self:refreshProtection(player)
    self:refreshLook(player)
    self:refreshStats(player)
    if self.tab == "skills" then self:refreshProfile(player) end
    if self.tab == "fitness" then self.exercises:refresh() end
    if self.tab == "protection" then self.protection:refresh() end
    self.dirty = false
end

function W:applyModelIfDirty()
    if not self.modelDirty then return end
    self.modelDirty = false
    self.model:setCharacter(getSpecificPlayer(self.playerNum))
end

-- Clothing and hand events; health and hotbar have no useful events: checked every 400 ms while the window is open.
function W:update()
    if not self:isVisible() then return end
    local now = getTimestampMs()
    local active = self.tabViews[self.tab]
    if active then self.scroller:fitView(active.view) end
    if self.dirty or now >= self.nextCheck then
        self.nextCheck = now + CHECK_MS
        self:refresh()
    end
end

function W:onClothingChanged()
    self.dirty = true
    self.modelDirty = true
end

-- ---------------------------------------------------------------- actions
function W:partMenu(bp)
    self:setHoverWound(nil)
    local hv = self:healthView()
    hv:doBodyPartContextMenu(bp, getMouseX() - hv:getAbsoluteX(), getMouseY() - hv:getAbsoluteY())
end

function W:onHair(btn) self.cw.charScreen:hairMenu(btn) end
function W:onBeard(btn) self.cw.charScreen:beardMenu(btn) end
function W:onLiterature() self.cw.charScreen:onShowLiterature() end

-- ---------------------------------------------------------------- wound tooltip (D-84)
-- State: tipWound = wound shown, tipOpen = opening or open, tipTime = animation start.
function W:setHoverWound(w, body)
    if w then
        if w ~= self.tipWound or not self.tipOpen then
            local reopen = self.tipWound == w
            self.tipWound, self.tipOpen = w, true
            if not reopen then self.tipTime = getTimestampMs() end
        end
        if body then
            local x, y, mw = body:markRect(w)
            self.tipMark = { x = body:getAbsoluteX() + x, y = body:getAbsoluteY() + y, w = mw }
        end
    elseif self.tipOpen then
        self.tipOpen, self.tipTime = false, getTimestampMs()
    end
end

function W:drawWoundTip(layer)
    local w = self.tipWound
    if not w or not self.tipMark then return end
    local now = getTimestampMs()
    local p
    if self.tipOpen then
        p = L.easeOut(now - self.tipTime, TIP_OPEN_MS)
    else
        p = 1 - L.easeOut(now - self.tipTime, TIP_CLOSE_MS)
        if p <= 0 then self.tipWound = nil; return end
    end
    local pad, gap, tw = px(TIP_PAD), px(TIP_GAP), px(TIP_W)
    local widths = {}
    for i, line in ipairs(w.lines) do widths[i] = D.measure("infoValue", line.text) + px(14) end
    local inner = tw - pad * 2
    for i = 1, #widths do if widths[i] > inner then widths[i] = inner end end
    local cg, ch = px(TIP_CHIP_GAP), px(TIP_CHIP_H)
    local pos, rows = L.wrapChips(widths, inner, cg)
    local nameH = D.lineHeight("itemName")
    local th = pad * 2 + nameH + gap + rows * ch + math.max(0, rows - 1) * cg
    local core = getCore()
    local x, y = L.tipPlace(self.tipMark.x, self.tipMark.y, self.tipMark.w, tw, th, px(8), core:getScreenWidth(), core:getScreenHeight())
    x, y = x - layer:getAbsoluteX(), y - layer:getAbsoluteY()
    local slide = math.floor((1 - p) * px(8))
    local a = math.max(0, (p - 0.3) / 0.7)
    local h = math.floor(th * p)
    D.fill(layer, x + slide, y, tw, h, "bg", p)
    D.border(layer, x + slide, y, tw, h, w.tok, p)
    if a <= 0 then return end
    x = x + slide
    D.text(layer, w.part, x + pad, y + pad, "itemName", "text", a, "left", inner)
    local cy = y + pad + nameH + gap
    for i, line in ipairs(w.lines) do
        local cx = x + pad + pos[i].x
        local ry = cy + pos[i].row * (ch + cg)
        D.fill(layer, cx, ry, widths[i], ch, line.tok, 0.18 * a)
        D.border(layer, cx, ry, widths[i], ch, line.tok, a)
        D.textMid(layer, line.text, cx + px(7), ry + ch / 2, "infoValue", line.tok, a, "left", widths[i] - px(14))
    end
end

-- Item dragged from a slot: follows the mouse above every window.
function W:drawDraggedSlot(layer)
    for _, slot in pairs(self.slots) do
        local item = slot.dragItem
        if item then
            local s = px(40)
            ISInventoryItem.renderItemIcon(layer, item, getMouseX() - layer:getAbsoluteX() - s / 2,
                getMouseY() - layer:getAbsoluteY() - s / 2, 1.0, s, s)
        end
    end
end

-- ---------------------------------------------------------------- themed item tooltip (D-70)
function W:showTip(slot, item)
    local n = self.playerNum
    if not self.tip then
        self.tip = ISToolTipInv:new(item)
        self.tip:initialise()
        self.tip:addToUIManager()
        self.tip:setCharacter(getSpecificPlayer(n))
    end
    local tip = self.tip
    if self.tipOwner ~= slot or tip.item ~= item or not tip:getIsVisible() then
        tip:setItem(item)
        tip:setOwner(slot)
        tip.followMouse = true
        tip:setVisible(true)
        tip:addToUIManager()
        tip:bringToTop()
        self.tipOwner = slot
    end
end

function W:hideTip()
    if self.tip and self.tipOwner then
        self.tip:removeFromUIManager()
        self.tip:setVisible(false)
    end
    self.tipOwner = nil
end

-- ---------------------------------------------------------------- open, close, move
function W:isOverMainInventory()
    local page = getPlayerInventory(self.playerNum)
    if not page or not page:isReallyVisible() or page.isCollapsed then return false end
    local pane = page.inventoryPane
    if pane.inventory ~= getSpecificPlayer(self.playerNum):getInventory() then return false end
    local mx, my = getMouseX(), getMouseY()
    local ax, ay = pane:getAbsoluteX(), pane:getAbsoluteY()
    return mx >= ax and mx < ax + pane:getWidth() and my >= ay and my < ay + pane:getHeight()
end

function W:placeBesideInventory()
    if self.userPlaced then return end
    local page = getPlayerInventory(self.playerNum)
    if not page then return end
    local core = getCore()
    local x, y = L.place(page:getX(), page:getY(), page:getWidth(), self.width, self.height, px(8), core:getScreenWidth(), core:getScreenHeight())
    self:setX(x); self:setY(y)
    local s = T.scale()
    self.bx, self.by = x / s, y / s
end

-- True only after the first opening: before that the Java element does not exist yet.
function W:isShown() return self.opened == true and self:isVisible() end

function W:show(tab)
    if not self.opened then
        self.opened = true
        self:open() -- creates the children and moves the vanilla panels: hasTab is valid from here on
    else
        UI.windows[self] = true
        self:setVisible(true)
        self:addToUIManager()
    end
    if tab and self:hasTab(tab) then self.tab = tab end
    self:applyTab()
    self:placeBesideInventory()
    if self.userPlaced then self:keepOnScreen() end
    self:bringToTop()
    self.dirty, self.modelDirty = true, true
end

function W:onMouseDown(x, y)
    if y < self:titleH() then self.userPlaced = true end
    return UI.Window.onMouseDown(self, x, y)
end

-- Position and size remembered across sessions (D-125), at the end of a move or resize.
function W:saveGeom()
    RSK.Config.set("equipment.window", L.geomText(self.bx, self.by, self.bw, self.bh))
end
function W:onMouseUp(x, y)
    local was = self.moving ~= nil or self.resizing ~= nil
    local r = UI.Window.onMouseUp(self, x, y)
    if was then self:saveGeom() end
    return r
end
function W:onMouseUpOutside(x, y)
    local was = self.moving ~= nil or self.resizing ~= nil
    UI.Window.onMouseUpOutside(self, x, y)
    if was then self:saveGeom() end
end

-- Saved position but the screen changed: the window stays inside the screen.
function W:keepOnScreen()
    local core, s = getCore(), T.scale()
    local x, y = L.clampPos(self:getX(), self:getY(), self.width, core:getScreenWidth(), core:getScreenHeight(), self:titleH())
    if x ~= self:getX() or y ~= self:getY() then
        self:setX(x); self:setY(y)
        self.bx, self.by = x / s, y / s
    end
end

function W:close()
    self:hideTip()
    self:setHoverWound(nil)
    UI.Window.close(self)
end

-- With a new scale the whole window is laid out again.
function W:themeChanged()
    UI.Window.themeChanged(self)
    self:arrange()
    self:placeBesideInventory()
end

-- ---------------------------------------------------------------- foreground layer
-- 1x1 off-screen element, always above the windows: does not catch the mouse, draws in absolute coordinates.
local Layer = ISUIElement:derive("RSK_EquipLayer")

function Layer:render()
    for _, win in pairs(Q.windows or {}) do
        if win:isShown() then
            win:drawDraggedSlot(self)
            win:drawWoundTip(self)
        end
    end
end

function Q.showLayer(guard)
    if Q.layer then return end
    local l = Layer:new(-4, -4, 1, 1)
    l:initialise(); l:instantiate(); l:addToUIManager(); l:setAlwaysOnTop(true)
    l.render = guard(Layer.render)
    Q.layer = l
end

function Q.hideLayer()
    if not Q.layer then return end
    Q.layer:removeFromUIManager()
    Q.layer = nil
end

return W
