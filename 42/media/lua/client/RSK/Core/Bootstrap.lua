-- RSK.Core - module registry and startup (D-44, RNF-04, RF-5.7).
-- A module: RSK.Core.register{ id, when = "boot"|"game", requires = {...}, start = fn(m), stop = fn(m), core }
--   core = true: Core service (e.g. Theme), always on, no module.<id> key.
--   start: hooks UI and listeners (RSK.Bus.on(..., m.id)); stop: removes everything and restores the vanilla UI.
-- An error in start, stop, a listener or a guarded function turns off
-- only that module (and the ones requiring it): the vanilla UI comes back.
require "RSK/Core/EventBus"
require "RSK/Core/Config"

RSK = RSK or {}
RSK.Core = RSK.Core or { modules = {}, order = {}, phase = "load" }
local K = RSK.Core
local B, C = RSK.Bus, RSK.Config
local unpack = unpack or table.unpack
local function pack(...) return { n = select("#", ...), ... } end
K.VERSION = "0.2.0-dev" -- D-132: keep modversion in 42/mod.info and CHANGELOG.md in sync on every release
local PHASE = { load = 0, boot = 1, game = 2 }

function K.log(msg) print("[RSK] " .. tostring(msg)) end

function K.register(def)
    assert(type(def) == "table" and def.id, "RSK.Core.register: id mancante")
    if K.modules[def.id] then error("RSK.Core.register: modulo gia' registrato: " .. def.id) end
    def.when = def.when or "game"
    def.requires = def.requires or {}
    def.state = "off"   -- off | on | disabled | blocked | failed
    K.modules[def.id] = def
    K.order[#K.order + 1] = def.id
    if not def.core then C.define("module." .. def.id, "bool", def.default ~= false) end
    if PHASE[K.phase] >= PHASE[def.when] then K.startModule(def.id) end
    return def
end

function K.isActive(id)
    local m = K.modules[id]
    return m ~= nil and m.state == "on"
end

function K.startModule(id)
    local m = K.modules[id]
    if not m or m.state == "on" or m.state == "failed" then return false end
    if PHASE[K.phase] < PHASE[m.when] then return false end
    if not m.core and not C.get("module." .. id) then m.state = "disabled"; return false end
    for _, r in ipairs(m.requires) do
        if not K.isActive(r) then m.state = "blocked"; K.log(id .. " non avviato: richiede " .. r); return false end
    end
    m.state = "on"
    local ok, err = true, nil
    if m.start then ok, err = pcall(m.start, m) end
    if not ok then K.fail(id, err); return false end
    B.emit("ModuleStarted", id)
    return true
end

-- Stops a module, after first stopping the ones that require it.
function K.stopModule(id, newState)
    local m = K.modules[id]
    if not m or m.state ~= "on" then return end
    m.state = "stopping"
    for _, oid in ipairs(K.order) do
        local o = K.modules[oid]
        if o.state == "on" then
            for _, r in ipairs(o.requires) do
                if r == id then K.stopModule(oid, "blocked"); break end
            end
        end
    end
    B.offOwner(id)
    if m.stop then
        local ok, err = pcall(m.stop, m)
        if not ok then K.log("ERRORE nello stop di " .. id .. ": " .. tostring(err)) end
    end
    m.state = newState or "off"
    B.emit("ModuleStopped", id)
end

function K.fail(id, err)
    local m = K.modules[id]
    if not m or m.state == "failed" then return end
    K.log("ERRORE nel modulo " .. id .. ", torna la UI vanilla: " .. tostring(err))
    m.lastError = tostring(err)
    if m.state == "on" then K.stopModule(id, "failed") else m.state = "failed" end
    B.emit("ModuleFailed", id, m.lastError)
end

-- Wraps a module function (hook, render, UI callback): returns false if the module is not
-- active; on error it stops the module. Callers use false to fall back to vanilla.
function K.guard(id, fn)
    return function(...)
        if not K.isActive(id) then return false end
        local r = pack(pcall(fn, ...))
        if r[1] then return unpack(r, 2, r.n) end
        K.fail(id, r[2])
        return false
    end
end

-- Restarts modules stopped for a missing dependency (e.g. Search after Inventory is active again).
function K.restartBlocked()
    for _, oid in ipairs(K.order) do
        if K.modules[oid].state == "blocked" then K.startModule(oid) end
    end
end

-- Live enable/disable (RF-5.7). A failed module can only be re-enabled from here.
function K.setEnabled(id, on)
    local m = K.modules[id]
    if not m or m.core then return false end
    C.set("module." .. id, on and true or false)
    if on then
        if m.state ~= "on" then
            m.state = "off"
            local ok = K.startModule(id)
            if ok then K.restartBlocked() end
            return ok
        end
    else
        K.stopModule(id, "disabled")
        m.state = "disabled"
    end
    return true
end

local function enterPhase(phase)
    if PHASE[K.phase] >= PHASE[phase] then return end
    if not C.loaded then C.load() end
    K.phase = phase
    for _, id in ipairs(K.order) do K.startModule(id) end
end

function K.boot()
    if K.phase ~= "load" then return end
    enterPhase("boot")
    local n = 0
    for _ in pairs(C.extra) do n = n + 1 end
    K.log("Core " .. K.VERSION .. " avviato (moduli registrati: " .. #K.order .. ", chiavi config sconosciute: " .. n .. ")")
end

function K.gameStart()
    K.boot()
    enterPhase("game")
    local s = {}
    for _, id in ipairs(K.order) do s[#s + 1] = id .. "=" .. K.modules[id].state end
    K.log("moduli in partita: " .. (#s > 0 and table.concat(s, ", ") or "nessuno"))
end

B.onError = function(owner, name, err)
    if owner and K.modules[owner] then K.fail(owner, err)
    else K.log("errore in " .. tostring(name) .. ": " .. tostring(err)) end
end

if Events then
    B.bridgeVanilla()
    Events.OnGameBoot.Add(K.boot)
    Events.OnMainMenuEnter.Add(K.boot)
    Events.OnGameStart.Add(K.gameStart)
end
