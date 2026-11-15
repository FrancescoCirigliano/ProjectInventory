-- RSK.Nested - M3, P2.2: nested container windows (RF-3.1...3.12, D-73).
-- Double click (or "Open" in the menu) on a container -> RSK_NestedPage window; other items -> vanilla (RF-3.11).
-- Module off or failed: transparent hooks and windows closed (D-44).
require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryPaneContextMenu"
require "RSK/Core/Bootstrap"
require "RSK/Inventory/Inventory"
require "RSK/Nested/Logic"
require "RSK/Nested/Page"

local K, T = RSK.Core, RSK.Theme
local N = RSK.Nested
local L = N.Logic
N.ID = "Nested"
N.windows = N.windows or {}

function N.isOn() return K.isActive(N.ID) end

local function realItem(e)
    if e == nil then return nil end
    if instanceof(e, "InventoryItem") then return e end
    return e.items and e.items[1] or nil
end

function N.isContainerItem(item)
    return item ~= nil and instanceof(item, "InventoryContainer") and item:getInventory() ~= nil
end

local function label(playerObj, c)
    if c == playerObj:getInventory() then return getText("UI_RSK_Nested_Inventory") end
    local ci = c:getContainingItem()
    if ci then return ci:getName() end
    local t = c:getType()
    return getTextOrNull("IGUI_ContainerTitle_" .. t) or t
end

function N.title(playerObj, item)
    return L.path(item, function(c) return label(playerObj, c) end, getText("UI_RSK_Nested_PathSep"))
end

-- RF-3.7: reachable = in the player inventory, on the floor nearby (same level, < 2 squares) or in a
-- loot container. The loot "floor" container is unique: for floor items the distance counts.
function N.reachable(playerObj, item)
    if not playerObj or playerObj:isDead() or not N.isContainerItem(item) then return false end
    local top = L.outermost(item)
    local wi = top:getWorldItem()
    if wi then
        local sq, ps = wi:getSquare(), playerObj:getCurrentSquare()
        return sq ~= nil and ps ~= nil and sq:getZ() == ps:getZ() and sq:DistToProper(ps) < 2
    end
    local c = top:getContainer()
    if not c or c:getType() == "floor" then return false end
    if c:isInCharacterInventory(playerObj) then return true end
    local list = ISInventoryPaneContextMenu.getContainers(playerObj)
    return list ~= nil and list:contains(c)
end

-- RF-3.8: one window per container; a second double click brings it to the front.
function N.open(playerObj, item)
    if not N.isOn() or not N.reachable(playerObj, item) then return nil end
    local id = item:getID()
    local w = N.windows[id]
    if w then
        w:setVisible(true)
        if w.isCollapsed then w.isCollapsed = false; w:clearMaxDrawHeight() end
        w:bringToTop()
        return w
    end
    local n = 0
    for _ in pairs(N.windows) do n = n + 1 end
    local core = getCore()
    local ww, wh = T.px(380), T.px(420)
    local x, y = L.place(n, ww, wh, core:getScreenWidth(), core:getScreenHeight(), T.px(24))
    w = N.PageClass:new(playerObj, item, x, y, ww, wh)
    w:initialise()
    w:addToUIManager()
    N.windows[id] = w
    return w
end

function N.forget(page)
    local id = page.rskItem and page.rskItem:getID()
    if id and N.windows[id] == page then N.windows[id] = nil end
end

function N.closeAll()
    for _, w in pairs(N.windows) do w:close() end
    N.windows = {}
end

-- ---------------------------------------------------------------- vanilla hooks (once only)
-- RF-3.11: double click on a container -> window; other items and the stack icon -> vanilla.
local gDouble = K.guard(N.ID, function(pane, x, y)
    if pane.vscroll and pane:isMouseOverScrollBar() then return false end
    if not (pane.items and pane.mouseOverOption and pane.previousMouseUp == pane.mouseOverOption) then return false end
    local entry = pane.items[pane.mouseOverOption]
    if entry ~= nil and not instanceof(entry, "InventoryItem") and x < pane.column2 then return false end
    local item = realItem(entry)
    if not N.isContainerItem(item) then return false end
    pane.previousMouseUp = nil
    N.open(getSpecificPlayer(pane.player), item)
    return true
end)

-- RF-3.2: "Open" entry at the top of the context menu.
local gMenu = K.guard(N.ID, function(playerNum, context, items)
    if #items ~= 1 then return end
    local item = realItem(items[1])
    if N.isContainerItem(item) then
        context:addOptionOnTop(getText("UI_RSK_Nested_Open"), getSpecificPlayer(playerNum), N.open, item)
    end
end)

if not N.hooked then
    N.hooked = true
    local orig = ISInventoryPane.onMouseDoubleClick
    N.origDoubleClick = orig
    function ISInventoryPane:onMouseDoubleClick(x, y)
        if N.isOn() and gDouble(self, x, y) then return end
        return orig(self, x, y)
    end
    Events.OnFillInventoryObjectContextMenu.Add(function(...) if N.isOn() then gMenu(...) end end)
    Events.OnContainerUpdate.Add(function() for _, w in pairs(N.windows) do w.rskDirty = true end end)
    Events.OnPlayerDeath.Add(function() N.closeAll() end)
end

-- ---------------------------------------------------------------- module
N.moduleDef = K.register{
    id = N.ID, when = "game", requires = { "Inventory" },
    start = function() end,
    stop = function() N.closeAll() end,
}
