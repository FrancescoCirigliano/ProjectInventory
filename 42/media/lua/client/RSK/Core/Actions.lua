-- RSK.Actions - the only layer that changes the world (V-10, V-11). Vanilla Timed Actions only. Part of the Core (P1.1).
-- The rules (what fits and what does not) live in RSK.TransferRules (D-39).
require "TimedActions/ISTimedActionQueue"
require "TimedActions/ISInventoryTransferUtil"
require "RSK/Core/TransferRules"

RSK = RSK or {}
RSK.Actions = RSK.Actions or {}
local A = RSK.Actions
local R = RSK.TransferRules

-- luautils.walkToContainer does not walk to a bag inside a world container
-- (nil parent): walk to the outermost container instead.
function A.walkTo(playerObj, container)
    if container:isInCharacterInventory(playerObj) then return true end
    local outer = container:getOutermostContainer() or container
    return luautils.walkToContainer(outer, playerObj:getPlayerNum())
end

-- Readable container name (for messages)
function A.containerName(c)
    local ci = c:getContainingItem()
    if ci then return ci:getName() end
    local t = c:getType()
    return getTextOrNull("IGUI_ContainerTitle_" .. t) or t
end

-- items: list of InventoryItem. Queues only the items accepted by the plan.
-- Returns: queued count, first refusal to show { item, reason, container } or nil.
function A.transfer(playerObj, items, dest)
    local plan = R.plan(playerObj, items, dest)
    local n = 0
    for i, item in ipairs(plan.accepted) do
        local src = item:getContainer()
        if i == 1 then
            local target = src:isInCharacterInventory(playerObj) and dest or src
            if not A.walkTo(playerObj, target) then break end
        end
        ISTimedActionQueue.add(ISInventoryTransferUtil.newInventoryTransferAction(playerObj, item, src, dest))
        n = n + 1
    end
    return n, R.firstShown(plan.refused)
end

-- Refusal text for the UI (Translate, V-19)
function A.refusalText(refused)
    if not refused then return nil end
    local key = ({ tooBig = "UI_RSK_P02_TooBig", noRoom = "UI_RSK_P02_NoRoom", notAllowed = "UI_RSK_P02_NotAllowed" })[refused.reason]
    return getText(key, refused.item:getName(), A.containerName(refused.container))
end
