-- RSK.Equipment.Slot - one M2 slot (D-33): 64 icon + condition bar + row with arrows and N/M.
-- Vanilla actions only (V-11): wearItem, unequipItem, equipWeapon, hotbar, context menu, themed tooltip.
require "ISUI/ISToolTipInv"
require "ISUI/ISInventoryItem"
require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryPaneContextMenu"
require "RSK/UI/UI"
require "RSK/Equipment/Logic"

local T, D, UL, E = RSK.Theme, RSK.UI.Draw, RSK.UI.Logic, RSK.UI.Element
local Q = RSK.Equipment
local L = Q.Logic
local CM = ISInventoryPaneContextMenu

local Slot = E:derive("RSK_EquipSlot")
Q.Slot = Slot

local BOX, BAR, GAP, ARROW = 64, 5, 3, 20
local INNER = 40
local DRAG_START = 6
local DASH = 6

local function px(n) return T.px(n) end

-- Weapon slots hold one item: icon and bar, no arrow row (D-87).
local function isWeapon(id) return id == "backWeapon" or id == "primary" or id == "secondary" end

local arrowL, arrowR
local function arrows()
    if arrowL == nil then
        arrowL = getTexture("media/ui/RSK/ui_arrow_left.png") or false
        arrowR = getTexture("media/ui/RSK/ui_arrow_right.png") or false
    end
    return arrowL or nil, arrowR or nil
end

-- Holes warning (D-122): same triangle as the wound markers (D-84), smaller.
local HOLE_W, HOLE_H = 16, 15
local triTex, bangTex
local function warnTri()
    if triTex == nil then triTex = getTexture("media/ui/RSK/wound_triangle.png") or false end
    return triTex or nil
end
local function warnBang()
    if bangTex == nil then bangTex = getTexture("media/ui/RSK/wound_bang.png") or false end
    return bangTex or nil
end

-- Holes in a garment (0 if it is not clothing or the method is missing in this build).
function Slot.holes(item)
    if not instanceof(item, "Clothing") then return 0 end
    local n = RSK.Inventory.TipLogic and RSK.Inventory.TipLogic.get(item, "getHolesNumber")
    return type(n) == "number" and n or 0
end

function Slot:new(x, y, win, id)
    local weapon = isWeapon(id)
    local o = E.new(self, x, y, BOX, weapon and L.SLOT_H_WEAPON or L.SLOT_H)
    o.win, o.id, o.items, o.index, o.weapon = win, id, {}, 0, weapon
    o.player = win.playerNum -- read by the themed tooltip
    o.rskStyled = true       -- the themed tooltip applies to this owner (Tip.applies)
    return o
end

function Slot:current() return self.items[self.index] end

function Slot:setItems(items)
    local cur = self:current()
    self.index = L.keepIndex(items, self.index, cur)
    self.items = items
end

function Slot:label() return getText("UI_RSK_Eq_Slot_" .. self.id) end

-- ---------------------------------------------------------------- actions
-- Item dragged onto the slot: only if it belongs there (D-82).
function Slot:accepts(item)
    local player = getSpecificPlayer(self.win.playerNum)
    if self.id == "primary" or self.id == "secondary" then
        return not instanceof(item, "Clothing") and not player:isEquipped(item)
    elseif self.id == "backWeapon" then
        local slot = self.win:backSlot()
        return slot ~= nil and getPlayerHotbar(self.win.playerNum):canBeAttached(slot, item)
    end
    if item:isBroken() or player:isEquipped(item) then return false end
    return L.slotFor(item:getBodyLocation()) == self.id or L.slotFor(item:canBeEquipped()) == self.id
end

function Slot:equip(item)
    local n = self.win.playerNum
    local player = getSpecificPlayer(n)
    if self.id == "primary" or self.id == "secondary" then
        CM.transferIfNeeded(player, item)
        local primary = self.id == "primary"
        CM.equipWeapon(item, primary, primary and item:isTwoHandWeapon() or false, n)
    elseif self.id == "backWeapon" then
        local slot, index = self.win:backSlot()
        local attachment = slot.def.attachments[item:getAttachmentType()]
        getPlayerHotbar(n):attachItem(item, attachment, index, slot.def, true)
    else
        CM.wearItem(item, n)
    end
end

function Slot:remove(item)
    local n = self.win.playerNum
    if self.id == "backWeapon" then getPlayerHotbar(n):removeItem(item, true)
    else CM.unequipItem(item, n) end
end

local function clearDrag()
    local focus = ISMouseDrag.draggingFocus
    ISMouseDrag.dragging, ISMouseDrag.draggingFocus = nil, nil
    return focus
end

-- End of a drag started from this slot: onto the player's main inventory = take off (D-82).
-- Other containers are handled by ISInventoryPane:onMouseUp (vanilla transfer).
function Slot:finishDrag()
    local item = self.dragItem
    self.dragItem, self.downItem = nil, nil
    if ISMouseDrag.draggingFocus == self then clearDrag() end
    if item and self.win:isOverMainInventory() then self:remove(item) end
end

function Slot:startDrag(item)
    self.dragItem = item
    ISMouseDrag.dragging = { item }
    ISMouseDrag.draggingFocus = self
    self.win:hideTip()
end

function Slot:checkDrag()
    if self.downItem and not self.dragItem and not ISMouseDrag.dragging then
        local dx, dy = getMouseX() - self.downX, getMouseY() - self.downY
        local d = px(DRAG_START)
        if dx * dx + dy * dy >= d * d then self:startDrag(self.downItem) end
    end
end

-- ---------------------------------------------------------------- mouse
function Slot:arrowsY()
    if self.weapon then return self.height + 1 end -- no row: the whole slot is icon and bar
    return px(BOX + GAP + BAR + GAP)
end

function Slot:onMouseDown(x, y)
    self.win:bringToTop()
    if y < self:arrowsY() and self:current() then
        self.downItem, self.downX, self.downY = self:current(), getMouseX(), getMouseY()
    end
    return true
end

function Slot:onMouseMove() self:checkDrag() end
function Slot:onMouseMoveOutside() self:checkDrag() end

function Slot:onMouseUp(x, y)
    -- Drop of a drag started elsewhere (inventory or another slot).
    if ISMouseDrag.dragging and ISMouseDrag.draggingFocus ~= self then
        local dragging = ISInventoryPane.getActualItems(ISMouseDrag.dragging)
        for _, item in ipairs(dragging) do
            if self:accepts(item) then self:equip(item); break end
        end
        local focus = clearDrag()
        if focus then focus:onMouseUp(0, 0) end
        return true
    end
    if self.dragItem then self:finishDrag(); return true end
    self.downItem = nil
    local n = #self.items
    if y >= self:arrowsY() and n > 1 then
        local a = px(ARROW)
        if x < a then self.index = L.cycle(self.index, n, -1)
        elseif x >= self.width - a then self.index = L.cycle(self.index, n, 1) end
    end
    return true
end

function Slot:onMouseUpOutside() self.downItem = nil end

function Slot:onRightMouseUp()
    local item = self:current()
    if item then
        CM.createMenu(self.win.playerNum, true, { item }, getMouseX(), getMouseY())
    end
    return true
end

function Slot:update()
    if self.dragItem and not isMouseButtonDown(0) then self:finishDrag() end
    local item = self:current()
    if item and self:isMouseOver() and self:getMouseY() < self:arrowsY() and not ISMouseDrag.dragging then
        self.win:showTip(self, item)
    elseif self.win.tipOwner == self then
        self.win:hideTip()
    end
end

-- ---------------------------------------------------------------- drawing
local function dashes(el, x, y, w, h, tok)
    local d = px(DASH)
    local i = 0
    while i < w do
        local l = math.min(d, w - i)
        D.fill(el, x + i, y, l, 1, tok); D.fill(el, x + i, y + h - 1, l, 1, tok)
        i = i + d * 2
    end
    i = 0
    while i < h do
        local l = math.min(d, h - i)
        D.fill(el, x, y + i, 1, l, tok); D.fill(el, x + w - 1, y + i, 1, l, tok)
        i = i + d * 2
    end
end

local function accepting(self)
    if not ISMouseDrag.dragging or ISMouseDrag.draggingFocus == self or not self:isMouseOver() then return false end
    for _, item in ipairs(ISInventoryPane.getActualItems(ISMouseDrag.dragging)) do
        if self:accepts(item) then return true end
    end
    return false
end

function Slot:render()
    local box, item = px(BOX), self:current()
    local hover = self:isMouseOver() and self:getMouseY() < self:arrowsY()
    if item then
        D.fill(self, 0, 0, box, box, hover and "sel" or "panel2")
        D.border(self, 0, 0, box, box, "line")
        local s = px(INNER)
        if self.dragItem ~= item then
            ISInventoryItem.renderItemIcon(self, item, (box - s) / 2, (box - s) / 2, 1.0, s, s)
        end
    else
        if hover then D.fill(self, 0, 0, box, box, "hover") end
        dashes(self, 0, 0, box, box, "line")
        D.fill(self, (box - px(16)) / 2, box / 2, px(16), 1, "line")
    end
    if accepting(self) then D.border(self, 0, 0, box, box, "accent") end
    -- Area label at the top left, above the icon (D-91).
    local text = self:label()
    local tw = math.min(D.measure("badge", text) + px(6), box)
    local th = D.lineHeight("badge")
    D.fill(self, 0, 0, tw, th, "bg", 0.75)
    D.text(self, text, px(3), 0, "badge", "muted", 1, "left", box - px(6))
    -- Garment with holes: yellow warning in the top right corner of the item (D-122).
    if item and self.dragItem ~= item and Slot.holes(item) > 0 then
        local w, h = px(HOLE_W), px(HOLE_H)
        local x, y = box - w - px(2), px(2)
        D.texture(self, warnTri(), x, y, w, h, "warn")
        D.texture(self, warnBang(), x, y, w, h, "ink")
    end

    local by, bh = box + px(GAP), px(BAR)
    D.fill(self, 0, by, box, bh, "panel2")
    local f = item and L.condition(item:getCondition(), item:getConditionMax())
    if f and f > 0 then D.fill(self, 0, by, math.max(1, math.floor(box * f)), bh, UL.barToken("cond", f)) end
    if self.weapon then return end

    local ay, a, n = self:arrowsY(), px(ARROW), #self.items
    local alpha = n > 1 and 1 or T.alpha.disabled
    local left, right = arrows()
    local is = px(12)
    D.fill(self, 0, ay, a, a, "panel2", alpha)
    D.fill(self, box - a, ay, a, a, "panel2", alpha)
    D.texture(self, left, (a - is) / 2, ay + (a - is) / 2, is, is, "text", alpha)
    D.texture(self, right, box - a + (a - is) / 2, ay + (a - is) / 2, is, is, "text", alpha)
    D.textMid(self, L.indexText(self.index, n), box / 2, ay + a / 2, "infoLabel", "muted", 1, "center")
end

function Slot:prerender() end
