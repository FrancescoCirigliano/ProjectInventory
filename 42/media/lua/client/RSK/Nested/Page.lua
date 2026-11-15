-- RSK.Nested.Page - M3, P2.2: nested container window = subclass of vanilla ISInventoryPage (D-73).
-- Shows only the opened container: M1 reskin (D-60) and vanilla interactions (D-61: drag&drop, menus, sorting)
-- are inherited. Only the container column, title, bottom bar, reach check and closing are replaced.
require "ISUI/ISInventoryPage"
require "ISUI/LootWindow/ISLootWindowContainerControls"
require "RSK/Nested/Logic"

local N = RSK.Nested
local NP = ISInventoryPage:derive("RSK_NestedPage")
N.PageClass = NP
local CHECK_MS = 400

function NP:new(playerObj, item, x, y, w, h)
    local o = ISInventoryPage.new(self, x, y, w, h, item:getInventory(), false, 1)
    o.player = playerObj:getPlayerNum()
    o.rskItem = item
    o.rskNextCheck = 0
    return o
end

-- Bottom bar: only the vanilla loot "Loot all" (moves into the open container in the player window).
local ONLY = {}
function NP.arrangeControls(cu, ...)
    local saved = ISLootWindowContainerControls_HandlerList
    ONLY[1] = ISLootWindowObjectControlHandler_TakeAll
    ISLootWindowContainerControls_HandlerList = ONLY
    local ok, err = pcall(ISLootWindowContainerControls.arrange, cu, ...)
    ISLootWindowContainerControls_HandlerList = saved
    if not ok then error(err, 0) end
end

local function patchControls(page)
    local cu = page.controlsUI
    if not cu or page.rskControls then return end
    page.rskControls = true
    cu.getDisplayedObject = function() return page.rskItem end
    cu.arrange = NP.arrangeControls
end

function NP:createChildren()
    ISInventoryPage.createChildren(self)
    self:setPinned() -- stays open until closed
    self.closeButton.onclick = NP.close -- the vanilla button points to ISInventoryPage.close
end

-- Container column with only the opened container (same steps as vanilla).
function NP:refreshBackpacks()
    local item = self.rskItem
    local c = item:getInventory()
    local playerObj = getSpecificPlayer(self.player)
    patchControls(self)
    self.buttonPool = self.buttonPool or {}
    for i, b in ipairs(self.backpacks) do
        self.containerButtonPanel:removeChild(b)
        table.insert(self.buttonPool, i, b)
    end
    table.wipe(self.backpacks)
    self.inventoryPane:hideButtons()
    self:checkExplored(c, playerObj)
    local b = self:addContainerButton(c, item:getTex(), item:getName(), item:getName())
    local vis, ci = item:getVisual(), item:getClothingItem()
    if vis and ci then
        local t = vis:getTint(ci)
        b:setTextureRGBA(t:getRedFloat(), t:getGreenFloat(), t:getBlueFloat(), 1)
    end
    self.selectedButton = b
    self.inventoryPane.inventory = c
    self.inventoryPane.lastinventory = c
    self.inventory = c
    self.capacity = b.capacity
    self.title = N.title(playerObj, item)
    self.inventoryPane:refreshContainer()
    self:refreshWeight()
    self:updateItemCount()
    if self.controlsUI then
        self.controlsUI:arrange()
        self.inventoryPane:setHeight(self.height - self.inventoryPane.y - self.resizeWidget.height - self.controlsUI.height)
    end
    self.containerButtonPanel:setHeight(self.inventoryPane.height)
    self.containerButtonPanel:setY(self.inventoryPane.y)
    self.containerButtonPanel:setScrollHeight(b:getBottom())
end

-- Every 400 ms: reach (RF-3.7), path (the item may change bag) and contents. The container's drawDirty
-- flag is consumed by the first window drawing it: if the same container is also open
-- in the inventory, here it updates through the item count + weight signature.
function NP:update()
    if self.rskClosed then return end
    local now = getTimestampMs()
    if now >= self.rskNextCheck then
        self.rskNextCheck = now + CHECK_MS
        local playerObj = getSpecificPlayer(self.player)
        if not N.isOn() or not N.reachable(playerObj, self.rskItem) then self:close(); return end
        self.title = N.title(playerObj, self.rskItem)
        local c = self.inventory
        local sig = tostring(c:getItems():size()) .. ":" .. tostring(c:getCapacityWeight())
        if self.rskDirty or sig ~= self.rskSig then
            self.rskSig, self.rskDirty = sig, false
            self.inventoryPane:refreshContainer()
            self:updateItemCount()
        end
    end
    ISInventoryPage.update(self)
end

-- Removes the highlight of the floor item (the window no longer goes through updateContainerHighlight).
local function clearHighlight(page)
    local obj = page.coloredInv and page:getContainerParent(page.coloredInv)
    if obj then
        obj:setHighlighted(page.player, false)
        obj:setOutlineHighlight(page.player, false)
        obj:setOutlineHlAttached(page.player, false)
    end
    page.coloredInv = nil
end

function NP:close()
    if self.rskClosed then return end
    self.rskClosed = true
    pcall(ISInventoryPage.close, self)
    pcall(clearHighlight, self)
    self:removeFromUIManager()
    N.forget(self)
end

return NP
