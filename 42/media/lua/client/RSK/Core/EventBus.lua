-- RSK.Bus - internal event bus (RF-0.4, D-45). No per-frame polling (RNF-01).
-- emit: immediate dispatch. post: batched dispatch, at most one per (event, key) each tick.
-- Every listener has an owner (module id): an error turns off only that module (D-44).
RSK = RSK or {}
RSK.Bus = RSK.Bus or {}
local B = RSK.Bus
local unpack = unpack or table.unpack

B.listeners = B.listeners or {}   -- name -> { {fn, owner}, ... }
B.pending = B.pending or {}       -- queue of { name, args }
B.pendingIndex = B.pendingIndex or {}
B.onError = B.onError             -- function(owner, name, err), set by the Core

function B.on(name, fn, owner)
    local l = B.listeners[name]
    if not l then l = {}; B.listeners[name] = l end
    l[#l + 1] = { fn = fn, owner = owner }
    return fn
end

local function removeWhere(l, pred)
    for i = #l, 1, -1 do
        if pred(l[i]) then l[i].dead = true; table.remove(l, i) end
    end
end

function B.off(name, fn)
    local l = B.listeners[name]
    if l then removeWhere(l, function(e) return e.fn == fn end) end
end

-- Removes all listeners of a module (shutdown or error).
function B.offOwner(owner)
    for _, l in pairs(B.listeners) do
        removeWhere(l, function(e) return e.owner == owner end)
    end
end

function B.has(name)
    local l = B.listeners[name]
    return l ~= nil and #l > 0
end

-- Returns the number of listeners run without errors.
function B.emit(name, ...)
    local l = B.listeners[name]
    if not l or #l == 0 then return 0 end
    local snap = {}
    for i = 1, #l do snap[i] = l[i] end
    local n = 0
    for i = 1, #snap do
        local e = snap[i]
        if not e.dead then
            local ok, err = pcall(e.fn, ...)
            if ok then
                n = n + 1
            elseif B.onError then
                B.onError(e.owner, name, err)
            else
                print("[RSK] errore in " .. tostring(name) .. ": " .. tostring(err))
            end
        end
    end
    return n
end

-- Dispatch deferred to the next tick; for the same (event, key) the last one wins.
-- Queues nothing when there are no listeners.
function B.post(name, key, ...)
    if not B.has(name) then return end
    local id = name .. "|" .. tostring(key)
    local args = { n = select("#", ...), ... }
    local e = B.pendingIndex[id]
    if e then e.args = args; return end
    e = { name = name, args = args }
    B.pendingIndex[id] = e
    B.pending[#B.pending + 1] = e
end

function B.flush()
    if #B.pending == 0 then return 0 end
    local list = B.pending
    B.pending, B.pendingIndex = {}, {}
    for i = 1, #list do
        local e = list[i]
        B.emit(e.name, unpack(e.args, 1, e.args.n))
    end
    return #list
end

-- Health signature: changes with overall health, wounds, bandages, bleeding.
function B.healthSignature(player)
    local ok, sig = pcall(function()
        local bd = player:getBodyDamage()
        local s = { math.floor(bd:getOverallBodyHealth() * 10) }
        local parts = bd:getBodyParts()
        for i = 0, parts:size() - 1 do
            local p = parts:get(i)
            s[#s + 1] = (p:HasInjury() and "i" or "-") .. (p:bandaged() and "b" or "-") .. (p:bleeding() and "s" or "-")
        end
        return table.concat(s, ",")
    end)
    return ok and sig or nil
end

-- Bridge vanilla events -> RSK events. RSK events (arguments):
--   InventoryChanged ()                 EquipChanged (player)
--   HealthChanged (player)              VehicleEnter (player) / VehicleExit (player)
--   PlayerDeath (player)                ConfigChanged (key, value)
--   ModuleStarted (id) / ModuleStopped (id) / ModuleFailed (id, err)
local function localPlayer(chr)
    return chr and instanceof(chr, "IsoPlayer") and chr:isLocalPlayer()
end

function B.bridgeVanilla()
    if B.bridged or not Events then return end
    B.bridged = true
    Events.OnTickEvenPaused.Add(B.flush)
    Events.OnContainerUpdate.Add(function() B.post("InventoryChanged", "all") end)
    local function equip(chr) if localPlayer(chr) then B.post("EquipChanged", chr:getPlayerNum(), chr) end end
    Events.OnClothingUpdated.Add(equip)
    Events.OnEquipPrimary.Add(equip)
    Events.OnEquipSecondary.Add(equip)
    local last = {}
    local function health(chr)
        if not localPlayer(chr) then return end
        local n = chr:getPlayerNum()
        last[n] = B.healthSignature(chr)
        B.post("HealthChanged", n, chr)
    end
    Events.OnPlayerGetDamage.Add(health)
    -- Treatments and bandages have no event: checked once per game minute, only when needed.
    Events.EveryOneMinute.Add(function()
        if not B.has("HealthChanged") then return end
        for n = 0, getNumActivePlayers() - 1 do
            local p = getSpecificPlayer(n)
            if p and not p:isDead() then
                local sig = B.healthSignature(p)
                if sig ~= last[n] then last[n] = sig; B.post("HealthChanged", n, p) end
            end
        end
    end)
    Events.OnEnterVehicle.Add(function(chr) if localPlayer(chr) then B.post("VehicleEnter", chr:getPlayerNum(), chr) end end)
    Events.OnExitVehicle.Add(function(chr) if localPlayer(chr) then B.post("VehicleExit", chr:getPlayerNum(), chr) end end)
    Events.OnPlayerDeath.Add(function(chr) if localPlayer(chr) then B.emit("PlayerDeath", chr) end end)
end
