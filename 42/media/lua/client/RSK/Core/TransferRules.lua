-- RSK.TransferRules - transfer rules, with no effect on the world (D-39).
-- Testable outside the game: they only use methods of the objects they receive.
-- Engine rules in 42.20 (ItemContainer.hasRoomFor, InventoryItem.getUnequippedWeight):
--  * weight of an unequipped bag = own weight + contents (no reduction);
--  * effective capacity is an integer (Organized/Disorganized traits);
--  * MaxItemSize > 0: refuses items heavier than the threshold;
--  * player inventory: limit checked only if it is the destination or if the destination
--    is a worn bag (equipParent) and the item is not already in the inventory;
--  * the engine checks only the destination: here the whole chain of bags is checked.
RSK = RSK or {}
RSK.TransferRules = RSK.TransferRules or {}
local R = RSK.TransferRules
R.EPS = 0.001

function R.weightOf(item)
    if item.getUnequippedWeight then return item:getUnequippedWeight() end
    return item:getActualWeight()
end

-- Weight change w inside c, propagated to every container holding it.
function R.addChain(deltas, c, w)
    local guard = 0
    while c and guard < 32 do
        deltas[c] = (deltas[c] or 0) + w
        local ci = c:getContainingItem()
        if not ci then return end
        c, guard = ci:getContainer(), guard + 1
    end
end

-- nil if everything fits, otherwise the first container without room.
-- The player inventory is not checked along the chain (see charTarget), the floor never.
function R.fullContainer(playerObj, deltas)
    local inv = playerObj:getInventory()
    for c, d in pairs(deltas) do
        if d > R.EPS and c ~= inv and c:getType() ~= "floor" then
            if c:getCapacityWeight() + d > c:getEffectiveCapacity(playerObj) + R.EPS then return c end
        end
    end
    return nil
end

function R.tooBig(item, dest)
    local ci = dest:getContainingItem()
    if not ci or not ci.getMaxItemSize then return false end
    local m = ci:getMaxItemSize()
    return m > 0 and R.weightOf(item) > m + R.EPS
end

-- Player inventory limit as in ItemContainer.hasRoomFor: applies if the destination
-- is the inventory itself, or a worn bag whose inventory does not already hold the item.
-- Returns the inventory to check and the character, or nil.
function R.charTarget(playerObj, item, dest)
    local inv = playerObj:getInventory()
    if dest == inv then return inv, playerObj end
    local ci = dest:getContainingItem()
    local ep = ci and ci.getEquipParent and ci:getEquipParent()
    local epInv = ep and ep:getInventory()
    if epInv and not epInv:contains(item) then return epInv, ep end
    return nil
end

-- Checks that do not depend on weight. nil = ok, otherwise the reason.
function R.basicRefusal(playerObj, item, dest)
    local src = item and item:getContainer()
    if not src or not dest then return "noSource" end
    if src == dest then return "same" end
    if dest:isInside(item) then return "inside" end
    if item:isFavorite() and not dest:isInCharacterInventory(playerObj) then return "favorite" end
    if not dest:isItemAllowed(item) then return "notAllowed" end
    return nil
end

-- Transfer plan: accepted items account for those accepted earlier
-- in the same call (in vanilla, if a queued item does not fit, the queue is emptied).
-- Ritorna { accepted = { item, ... }, refused = { { item, reason, container }, ... } }
-- reason: noSource | same | inside | favorite | notAllowed | tooBig | noRoom
function R.plan(playerObj, items, dest)
    local out = { accepted = {}, refused = {} }
    local batch, charAdd = {}, {}
    for _, item in ipairs(items) do
        local reason = R.basicRefusal(playerObj, item, dest)
        if reason then
            out.refused[#out.refused + 1] = { item = item, reason = reason, container = dest }
        elseif R.tooBig(item, dest) then
            out.refused[#out.refused + 1] = { item = item, reason = "tooBig", container = dest }
        else
            local w = R.weightOf(item)
            local trial = {}
            for c, d in pairs(batch) do trial[c] = d end
            R.addChain(trial, item:getContainer(), -w)
            R.addChain(trial, dest, w)
            local full = R.fullContainer(playerObj, trial)
            local ct, chr = R.charTarget(playerObj, item, dest)
            if not full and ct then
                local add = (charAdd[ct] or 0) + w
                if ct:getCapacityWeight() + add > ct:getEffectiveCapacity(chr) + R.EPS then full = ct end
            end
            if full then
                out.refused[#out.refused + 1] = { item = item, reason = "noRoom", container = full }
            else
                batch = trial
                if ct then charAdd[ct] = (charAdd[ct] or 0) + w end
                out.accepted[#out.accepted + 1] = item
            end
        end
    end
    return out
end

-- Reasons shown to the user (the others are obvious or unreachable from the UI)
R.SHOWN = { tooBig = true, noRoom = true, notAllowed = true }

function R.firstShown(refused)
    for _, r in ipairs(refused) do
        if R.SHOWN[r.reason] then return r end
    end
    return nil
end
