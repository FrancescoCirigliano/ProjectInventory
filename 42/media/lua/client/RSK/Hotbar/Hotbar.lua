-- RSK.Hotbar - M8, P3.4: themed hotbar (D-145, RF-8.7). Hooks on the vanilla ISHotbar class: slots,
-- attachments, keys, item drops from the inventory, activation and the item tooltip stay vanilla.
-- Ours: the drawing (frame like the inventory window, slot states, condition filling the slot from
-- the bottom, "name · condition" label, "in hand" badge), margins 8 / spacing 4 (vanilla fields, so
-- the vanilla hit test and size follow) and reordering by dragging a slot: the vanilla slot list and
-- the attached slot index of the items are permuted and saved with the vanilla savePosition, so keys
-- stay bound to positions and the save stays vanilla (the mod can be removed).
-- Module off or in error: vanilla geometry and render (D-44).
require "Hotbar/ISHotbar"
require "ISUI/ISInventoryItem"
require "RSK/Core/Bootstrap"
require "RSK/UI/UI"
require "RSK/Hotbar/Logic"

RSK = RSK or {}
RSK.Hotbar = RSK.Hotbar or {}
local M = RSK.Hotbar
local L = M.Logic
local K, T = RSK.Core, RSK.Theme
local D = RSK.UI.Draw
local G = L.GEO
M.ID = "Hotbar"

local texCache = {}
local function statusTex(name, n)
    local key = name .. "_" .. n
    local t = texCache[key]
    if t == nil then t = getTexture("media/ui/RSK/status/" .. key .. ".png") or false; texCache[key] = t end
    return t or nil
end

local function itemInfo(item)
    local info = { cond = item:getCondition(), condMax = item:getConditionMax() }
    local fc = item.getFluidContainer and item:getFluidContainer() or nil
    if fc then info.fluid, info.fluidCap = fc:getAmount(), fc:getCapacity() end
    if instanceof(item, "DrainableComboItem") then info.drain = item:getCurrentUsesFloat() end
    return info
end
M.itemInfo = itemInfo

local function queued(hb)
    local q = ISTimedActionQueue and ISTimedActionQueue.queues and ISTimedActionQueue.queues[hb.character]
    return q ~= nil and q.queue ~= nil and #q.queue > 0
end

-- Geometry: our margins while active, vanilla values back when off.
local function applyGeometry(hb, on)
    if on then
        if not hb.rskVanilla then
            hb.rskVanilla = { margins = hb.margins, slotPad = hb.slotPad, height = hb.height }
        end
        hb.margins, hb.slotPad = G.margin, G.pad
        local _, h = L.size(#hb.availableSlot, hb.slotWidth, hb.slotHeight)
        if hb.height ~= h then hb:setHeight(h) end
    elseif hb.rskVanilla then
        local v = hb.rskVanilla
        hb.margins, hb.slotPad = v.margins, v.slotPad
        hb:setHeight(v.height)
        hb.rskVanilla = nil
        hb.rskPress, hb.rskDrag = nil, nil
    end
end

local function dashed(hb, x, y, w, h, tok)
    local r, g, b, a = T.rgba(tok)
    local dash, gap = 4, 3
    local i = 0
    while i < w do
        local len = math.min(dash, w - i)
        hb:drawRect(x + i, y, len, 1, a, r, g, b)
        hb:drawRect(x + i, y + h - 1, len, 1, a, r, g, b)
        i = i + dash + gap
    end
    i = 0
    while i < h do
        local len = math.min(dash, h - i)
        hb:drawRect(x, y + i, 1, len, a, r, g, b)
        hb:drawRect(x + w - 1, y + i, 1, len, a, r, g, b)
        i = i + dash + gap
    end
end

local function drawLabel(hb, x, sw, y, text)
    local tw = D.measure("rowSmall", text)
    local lh = D.lineHeight("rowSmall")
    local w, h = tw + 2 * G.labelPadX, lh + 2 * G.labelPadY
    local lx = math.floor(x + (sw - w) / 2)
    local ly = y - G.labelGap - h
    D.fill(hb, lx, ly, w, h, "bg")
    D.border(hb, lx, ly, w, h, "line")
    D.text(hb, text, lx + G.labelPadX, ly + G.labelPadY, "rowSmall", "text")
end

M.stats = M.stats or { renders = 0 }

-- Draws the hotbar; vanilla logic for what is hovered and dropped.
function M.themedRender(hb)
    if (hb.playerNum > 0) or JoypadState.players[hb.playerNum + 1] then
        hb:setVisible(false) -- as vanilla: keep it in the UI so update() still refreshes
    end
    applyGeometry(hb, true)
    local n = #hb.availableSlot
    local sw, sh = hb.slotWidth, hb.slotHeight
    M.stats.renders = M.stats.renders + 1
    D.fill(hb, 0, 0, hb.width, hb.height, "panel")
    D.border(hb, 0, 0, hb.width, hb.height, "line")

    local reorder = hb.rskDrag
    local mouseOver = reorder and -1 or hb:getSlotIndexAt(hb:getMouseX(), hb:getMouseY())
    local draggedItem, invalid = nil, false
    if ISMouseDrag.dragging and mouseOver ~= -1 then
        local dragging = ISInventoryPane.getActualItems(ISMouseDrag.dragging)
        local slot = hb.availableSlot[mouseOver]
        for _, item in ipairs(dragging) do
            if hb:canBeAttached(slot, item) then draggedItem = item; break end
        end
        invalid = draggedItem == nil
    end

    local labelText, labelX
    for i = 1, n do
        local slot = hb.availableSlot[i]
        local x, y = L.slotX(i, sw), G.margin
        local item = hb.attachedItems[i]
        local hover = i == mouseOver
        if hover and draggedItem then item = draggedItem
        elseif item and item == draggedItem then item = nil end
        local alpha = (reorder == i) and G.dragAlpha or 1

        local bgTok, bdTok, bgA = "panel2", "line", 1
        if hover and invalid then bgTok, bdTok, bgA = "danger", "danger", G.invalidAlpha
        elseif hover then bgTok, bdTok = "sel", "accent" end
        D.fill(hb, x, y, sw, sh, bgTok, bgA * alpha)

        local f = nil
        if item then
            f = L.fraction(itemInfo(item))
            if f then
                local fh = L.fillHeight(f, sh)
                local tok = L.condToken(f)
                D.fill(hb, x, y + sh - fh, sw, fh, tok, G.condAlpha * alpha)
                D.fill(hb, x, y + sh - fh, sw, G.condLine, tok, alpha)
            end
        end
        if item or hover then D.border(hb, x, y, sw, sh, bdTok, alpha)
        else dashed(hb, x, y, sw, sh, "line") end

        D.text(hb, tostring(i), x + G.numX, y + G.numY, "label", "muted", alpha)
        local ix, iy = x + math.floor((sw - G.icon) / 2), y + math.floor((sh - G.icon) / 2)
        if item then
            ISInventoryItem.renderItemIcon(hb, item, ix, iy, alpha, G.icon, G.icon)
            if item:isEquipped() then
                local bx, by = x + sw - G.badgeInset - G.badge, y + sh - G.badgeInset - G.badge
                D.texture(hb, statusTex("disc", G.badge), bx, by, G.badge, G.badge, "accent", alpha)
                D.texture(hb, statusTex("check", G.badge), bx, by, G.badge, G.badge, "ink", alpha)
            end
        elseif slot.texture then
            hb:drawTextureScaledAspect(slot.texture, ix, iy, G.icon, G.icon, G.emptyAlpha * alpha, 1, 1, 1)
        end

        if hover then
            local name = item and item:getDisplayName()
                or getTextOrNull("IGUI_HotbarAttachment_" .. tostring(slot.slotType)) or slot.name
            labelText, labelX = L.label(name, f, getText("UI_RSK_Hotbar_Empty")), x
        end
    end

    if reorder then
        local ins = L.dropIndex(hb:getMouseX(), n, sw)
        if L.moveOrder(n, reorder, ins) then
            D.fill(hb, L.markerX(ins, n, sw), G.margin - 1, G.marker, sh + 2, "accent")
        end
    end
    if labelText then drawLabel(hb, labelX, sw, G.margin, labelText) end
    return true
end
local gThemed = K.guard(M.ID, M.themedRender)

-- Moves slot `from` to insertion point `ins`: vanilla slot list, attached slot index of the items,
-- vanilla save of the order (modData "hotbar"). Returns true if something moved.
function M.reorder(hb, from, ins)
    local n = #hb.availableSlot
    local perm = L.moveOrder(n, from, ins)
    if not perm or queued(hb) then return false end
    local inv = L.inverse(perm)
    local slots = {}
    for ni, oi in ipairs(perm) do slots[ni] = hb.availableSlot[oi] end
    for oi, item in pairs(hb.attachedItems) do
        if inv[oi] then item:setAttachedSlot(inv[oi]) end
    end
    hb.availableSlot = slots
    hb:reloadIcons()
    hb:savePosition()
    return true
end

-- ---------------------------------------------------------------- hooks
M.orig = M.orig or {}
local O = M.orig
local W = {}

function W.render(self)
    if K.isActive(M.ID) then gThemed(self); return end
    applyGeometry(self, false)
    return O.render(self)
end

-- The vanilla background (ISPanelJoypad prerender) would show around our frame: not drawn.
function W.prerender(self)
    if K.isActive(M.ID) then return end
    return O.prerender(self)
end

-- Vanilla width has 2 px more than the slots need: our exact size, centred like vanilla.
function W.setSizeAndPosition(self)
    O.setSizeAndPosition(self)
    if not K.isActive(M.ID) then return end
    local w = L.size(#self.availableSlot, self.slotWidth, self.slotHeight)
    if self.width ~= w then
        self:setWidth(w)
        self:setX(getPlayerScreenLeft(self.playerNum) + (getPlayerScreenWidth(self.playerNum) - w) / 2)
    end
end

function W.onMouseDown(self, x, y)
    if K.isActive(M.ID) and not ISMouseDrag.dragging then
        local i = self:getSlotIndexAt(x, y)
        if i ~= -1 then self.rskPress = { i = i, x = x, y = y } end
    end
    return O.onMouseDown(self, x, y)
end

function W.onMouseMove(self, dx, dy)
    local p = self.rskPress
    if p and not self.rskDrag and K.isActive(M.ID) then
        if L.startsDrag(self:getMouseX() - p.x, self:getMouseY() - p.y, #self.availableSlot, queued(self)) then
            self.rskDrag = p.i
        end
    end
    return O.onMouseMove(self, dx, dy)
end

function W.onMouseUp(self, x, y)
    local from = self.rskDrag
    self.rskPress, self.rskDrag = nil, nil
    if from and K.isActive(M.ID) then
        local ok, err = pcall(M.reorder, self, from, L.dropIndex(x, #self.availableSlot, self.slotWidth))
        if not ok then K.log("Hotbar: riordino fallito: " .. tostring(err)) end
        return
    end
    return O.onMouseUp(self, x, y)
end

function W.onMouseUpOutside(self, x, y)
    self.rskPress, self.rskDrag = nil, nil
    return O.onMouseUpOutside(self, x, y)
end

function M.installHook()
    if not ISHotbar then return false end
    for name, fn in pairs(W) do
        if rawget(ISHotbar, name) ~= fn then
            O[name] = ISHotbar[name] -- own vanilla method or inherited from ISPanelJoypad
            rawset(ISHotbar, name, fn)
        end
    end
    return rawget(ISHotbar, "render") == W.render
end
M.wrapRender = W.render

M.moduleDef = K.register{
    id = M.ID, when = "game", requires = { "UI" },
    start = function()
        K.log("Hotbar: hotbar a tema, aggancio " .. tostring(M.installHook()))
    end,
    stop = function() end, -- the hooks fall back to vanilla while the module is off
}
