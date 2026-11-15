-- Fake objects with the same 42.20 engine methods used by RSK.TransferRules.
-- Formulas copied from the bytecode (ItemContainer, InventoryItem, InventoryContainer).
local M = {}

local Container = {}
Container.__index = Container

local Item = {}
Item.__index = Item

local Player = {}
Player.__index = Player

-- opts: type, capacity, owner (player: player inventory)
function M.container(opts)
    opts = opts or {}
    return setmetatable({
        items = {}, type = opts.type or "none", capacity = opts.capacity or 0,
        owner = opts.owner, accept = opts.accept, containingItem = nil,
    }, Container)
end

function Container:getType() return self.type end
function Container:getContainingItem() return self.containingItem end
function Container:getCapacity() return self.capacity end

function Container:getContentsWeight()
    local w = 0
    for _, it in ipairs(self.items) do w = w + it:getUnequippedWeight() end
    return w
end
Container.getCapacityWeight = Container.getContentsWeight

-- ItemContainer.getEffectiveCapacity: traits apply if the parent is not a character
-- (nor a corpse) and the type is not "floor".
function Container:getEffectiveCapacity(chr)
    local cap = self.capacity
    if chr and not self.owner and self.type ~= "floor" then
        if chr:hasTrait("ORGANIZED") then return math.floor(math.max(cap * 1.3, cap + 1)) end
        if chr:hasTrait("DISORGANIZED") then return math.floor(math.max(cap * 0.7, 1)) end
    end
    return cap
end

function Container:isItemAllowed(item)
    if self.accept then return self.accept(item) end
    return true
end

-- true if this container is inside item (or is its inventory)
function Container:isInside(item)
    local c, guard = self, 0
    while c and guard < 32 do
        local ci = c.containingItem
        if not ci then return false end
        if ci == item then return true end
        c, guard = ci.container, guard + 1
    end
    return false
end

function Container:isInCharacterInventory(chr)
    local c, guard = self, 0
    while c and guard < 32 do
        if c == chr:getInventory() then return true end
        local ci = c.containingItem
        if not ci then return false end
        c, guard = ci.container, guard + 1
    end
    return false
end

-- ItemContainer.contains: first level only
function Container:contains(item)
    for _, it in ipairs(self.items) do if it == item then return true end end
    return false
end

function Container:add(item)
    if item.container then item.container:remove(item) end
    item.container = self
    self.items[#self.items + 1] = item
    return item
end

function Container:remove(item)
    for i, it in ipairs(self.items) do
        if it == item then table.remove(self.items, i); break end
    end
    item.container = nil
end

-- opts: name, weight, favorite, category, bag = { capacity, maxItemSize }
function M.item(opts)
    local it = setmetatable({
        name = opts.name or "item", weight = opts.weight or 0.1,
        favorite = opts.favorite or false, category = opts.category or "Item",
        maxItemSize = 0, container = nil,
    }, Item)
    if opts.bag then
        it.inventory = M.container({ type = opts.name, capacity = opts.bag.capacity or 0, accept = opts.bag.accept })
        it.inventory.containingItem = it
        it.maxItemSize = opts.bag.maxItemSize or 0
    end
    return it
end

function Item:getName() return self.name end
function Item:getContainer() return self.container end
function Item:getInventory() return self.inventory end
function Item:isFavorite() return self.favorite end
function Item:getCategory() return self.category end
function Item:getActualWeight() return self.weight end
function Item:getMaxItemSize() return self.maxItemSize end
function Item:getEquipParent() return self.equippedBy end
-- bag worn by p (stays in p's inventory)
function Item:wornBy(p) self.equippedBy = p; return self end
-- InventoryItem.getUnequippedWeight = own weight + contents (no reduction)
function Item:getUnequippedWeight()
    local w = self.weight
    if self.inventory then w = w + self.inventory:getContentsWeight() end
    return w
end

function M.player(opts)
    opts = opts or {}
    local p = setmetatable({ traits = opts.traits or {} }, Player)
    p.inventory = M.container({ type = "none", capacity = opts.capacity or 12, owner = p })
    return p
end

function Player:getInventory() return self.inventory end
function Player:hasTrait(t) return self.traits[t] == true end

-- Real game items (values from media/scripts/generated/items, 42.20)
M.real = {
    FirstAidKit = function() return M.item({ name = "FirstAidKit", weight = 1.0, bag = { capacity = 4, maxItemSize = 1.0 } }) end,
    SewingKit = function() return M.item({ name = "SewingKit", weight = 1.0, bag = { capacity = 2, maxItemSize = 0.3 } }) end,
    Schoolbag = function() return M.item({ name = "Bag_Schoolbag", weight = 1.0, bag = { capacity = 15 } }) end,
    KeyRing = function()
        return M.item({ name = "KeyRing", weight = 0.05, bag = { capacity = 1, accept = function(i) return i:getCategory() == "Key" end } })
    end,
    ScrapMetal = function() return M.item({ name = "ScrapMetal", weight = 1.0 }) end,
    Bandage = function() return M.item({ name = "Bandage", weight = 0.1 }) end,
    Key = function() return M.item({ name = "Key1", weight = 0.05, category = "Key" }) end,
}

return M
