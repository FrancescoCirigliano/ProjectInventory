-- P0.4 - snapshots for the mod add/remove test (D-05, Analysis 2.6).
-- Separate mod: stays active even when ProjectInventory is disabled.
-- Writes Zomboid/Lua/RSK_P04_<ms>_<label>.txt: items (ID and type) in the player inventory,
-- in nested bags and in containers within 2 squares; global and player ModData keys;
-- the collectibles found list (RSK_Collect, M4) for CA3.
local P04 = {}
local RADIUS = 2

local function walk(container, path, out)
    if not container then return end
    local items = container:getItems()
    for i = 0, items:size() - 1 do
        local it = items:get(i)
        out[#out + 1] = "ITEM|" .. path .. "|" .. tostring(it:getID()) .. "|" .. it:getFullType()
        if instanceof(it, "InventoryContainer") and it:getInventory() then
            walk(it:getInventory(), path .. ">" .. it:getFullType() .. "#" .. tostring(it:getID()), out)
        end
    end
    out[#out + 1] = string.format("WEIGHT|%s|%.3f", path, container:getCapacityWeight())
end

local function sortedKeys(t)
    local k = {}
    for key in pairs(t) do k[#k + 1] = tostring(key) end
    table.sort(k)
    return k
end

function P04.snapshot(label)
    local p = getSpecificPlayer(0)
    if not p then return end
    local out, head = {}, {}
    local active = false
    pcall(function() active = getActivatedMods():contains("ProjectInventory") end)
    head[#head + 1] = "LABEL|" .. label
    head[#head + 1] = "MOD_ProjectInventory_ATTIVA|" .. tostring(active)
    head[#head + 1] = "RSK_LUA_PRESENTE|" .. tostring(RSK ~= nil)
    walk(p:getInventory(), "PG", out)
    local sq0 = p:getCurrentSquare()
    if sq0 then
        for dx = -RADIUS, RADIUS do
            for dy = -RADIUS, RADIUS do
                local sq = getCell():getGridSquare(sq0:getX() + dx, sq0:getY() + dy, sq0:getZ())
                if sq then
                    local base = "SQ" .. sq:getX() .. "," .. sq:getY() .. "," .. sq:getZ()
                    local objs = sq:getObjects()
                    for o = 0, objs:size() - 1 do
                        local obj = objs:get(o)
                        for c = 0, obj:getContainerCount() - 1 do
                            local cont = obj:getContainerByIndex(c)
                            walk(cont, base .. "/" .. tostring(cont:getType()), out)
                        end
                    end
                    local wobs = sq:getWorldObjects()
                    for w = 0, wobs:size() - 1 do
                        local it = wobs:get(w):getItem()
                        if it then
                            out[#out + 1] = "ITEM|" .. base .. "/floor|" .. tostring(it:getID()) .. "|" .. it:getFullType()
                            if instanceof(it, "InventoryContainer") and it:getInventory() then
                                walk(it:getInventory(), base .. "/floor>" .. it:getFullType() .. "#" .. tostring(it:getID()), out)
                            end
                        end
                    end
                end
            end
        end
    end
    local names = ModData.getTableNames()
    local hasCollect = false
    for i = 0, names:size() - 1 do
        local n = tostring(names:get(i))
        out[#out + 1] = "GMODDATA|" .. n
        if n == "RSK_Collect" then hasCollect = true end
    end
    for _, k in ipairs(sortedKeys(p:getModData())) do out[#out + 1] = "PMODDATA|" .. k end
    -- read without creating the table: with ProjectInventory off it must stay as it was
    if hasCollect then
        local c = ModData.get("RSK_Collect")
        if type(c) == "table" and type(c.found) == "table" then
            for _, k in ipairs(sortedKeys(c.found)) do out[#out + 1] = "COLLECT|" .. k end
        end
    end
    table.sort(out)
    local f = getFileWriter("RSK_P04_" .. tostring(getTimestampMs()) .. "_" .. label .. ".txt", true, false)
    for _, l in ipairs(head) do f:write(l .. "\n") end
    for _, l in ipairs(out) do f:write(l .. "\n") end
    f:close()
    print("[RSK-P04] istantanea " .. label .. ": " .. #out .. " righe, ProjectInventory attiva=" .. tostring(active))
end

-- On load it waits a few ticks: nearby containers must be loaded.
local wait = -1
local function onTick()
    if wait < 0 then return end
    wait = wait - 1
    if wait == 0 then P04.snapshot("load") end
end
Events.OnGameStart.Add(function() wait = 60 end)
Events.OnTick.Add(onTick)
Events.OnPostSave.Add(function() P04.snapshot("save") end)
Events.OnFillWorldObjectContextMenu.Add(function(playerNum, context, worldobjects, test)
    if test then return end
    context:addOption("RSK P0.4: istantanea", nil, function() P04.snapshot("manual") end)
end)
