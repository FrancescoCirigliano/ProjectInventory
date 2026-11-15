-- RSK.Collect.Logic - collectible rules with no engine dependencies (testable, T-25; D-130, D-138).
-- An item is described by a plain table (built from the engine by RSK.Collect.describe):
--   { fullType, skillBook (bool), recipes (number of script-taught recipes), mdRecipe (string),
--     printMedia (id), printMap (bool: the print media reveals map locations), map (bool), mapId,
--     media (bool), mediaId }
-- Collectible = teaches something or is recorded media (D-130). Boredom/unhappiness reading
-- (literatureTitle, newspapers, comics, plain print media) is not collectible.
RSK = RSK or {}
RSK.Collect = RSK.Collect or {}
RSK.Collect.Logic = RSK.Collect.Logic or {}
local L = RSK.Collect.Logic

L.STORE_VERSION = 1

local function nonEmpty(s) return type(s) == "string" and s ~= "" end

-- Tracking key, or nil if the item is not a collectible. The key identifies what is collected:
-- skill books and recipe magazines by type (one per volume), random-recipe schematics by recipe,
-- print media by id, maps by map id, recorded media by media id (CDs share one item type).
function L.keyOf(d)
    if type(d) ~= "table" then return nil end
    if d.media then return nonEmpty(d.mediaId) and ("media:" .. d.mediaId) or nil end
    if d.skillBook and nonEmpty(d.fullType) then return "book:" .. d.fullType end
    if (tonumber(d.recipes) or 0) > 0 and nonEmpty(d.fullType) then return "recipe:" .. d.fullType end
    if nonEmpty(d.mdRecipe) then return "learn:" .. d.mdRecipe end
    if d.printMap and nonEmpty(d.printMedia) then return "print:" .. d.printMedia end
    if d.map then
        if nonEmpty(d.mapId) then return "map:" .. d.mapId end
        if nonEmpty(d.fullType) then return "map:" .. d.fullType end
    end
    return nil
end

-- World store (ModData RSK_Collect, RF-4.7): { v = 1, found = { [key] = true } }.
-- Repairs a missing or damaged table in place and returns it.
function L.ensureStore(t)
    if type(t) ~= "table" then t = {} end
    if type(t.found) ~= "table" then t.found = {} end
    t.v = t.v or L.STORE_VERSION
    return t
end

function L.isFound(store, key)
    return key ~= nil and store ~= nil and store.found ~= nil and store.found[key] == true
end

-- Marks a key as found; true only the first time.
function L.markFound(store, key)
    if key == nil or store == nil then return false end
    if store.found[key] then return false end
    store.found[key] = true
    return true
end

-- Empties the found list (D-140: character death with "reset on death" on). Returns how many were cleared.
function L.clearFound(store)
    if store == nil or store.found == nil then return 0 end
    local n = L.count(store)
    store.found = {}
    return n
end

function L.count(store)
    local n = 0
    if store and store.found then for _ in pairs(store.found) do n = n + 1 end end
    return n
end

-- Icon state (D-26, D-138): "read" wins (vanilla data of the character, any literature);
-- otherwise collectibles are "found" or "new"; everything else has no icon.
function L.status(key, found, read)
    if read then return "read" end
    if key == nil then return nil end
    return found and "found" or "new"
end

-- Visits every item of a container and of the containers inside it, at any depth (D-138).
-- list(c) -> n, at (at(i) = i-th item, 1-based), inner(item) -> container or nil.
-- A guard on visited containers stops cyclic chains.
function L.walk(root, list, inner, visit)
    local seen, stack = {}, { root }
    while #stack > 0 do
        local c = table.remove(stack)
        if c ~= nil and not seen[c] then
            seen[c] = true
            local n, at = list(c)
            for i = 1, n or 0 do
                local it = at(i)
                visit(it)
                local sub = inner(it)
                if sub ~= nil then stack[#stack + 1] = sub end
            end
        end
    end
end
