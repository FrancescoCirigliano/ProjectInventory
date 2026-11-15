-- RSK.Collect - M4, P3.1: vanilla collectibles (D-130, D-138, D-139). No catalog screen:
-- the module only records which collectibles have been "found" in this world and gives the
-- inventory its status icon (D-26). Found = the item entered the player inventory, nested bags
-- and equipped containers included, at any depth. "Read/heard/seen" always comes from the
-- vanilla data of the character and is never stored (RF-4.2, RF-4.3).
-- Storage: global world ModData "RSK_Collect" (RF-4.7, V-13): a new game starts empty, the
-- tracker is emptied when the character dies unless the user turns that off (RF-4.9, D-140);
-- without the mod the table is just ignored.
require "RSK/Core/Bootstrap"
require "RSK/Collect/Logic"

RSK = RSK or {}
RSK.Collect = RSK.Collect or {}
local Co = RSK.Collect
local L = Co.Logic
local K, B, C = RSK.Core, RSK.Bus, RSK.Config
Co.ID = "Collect"
Co.MODDATA = "RSK_Collect"
Co.RESET_KEY = "collect.resetOnDeath"
C.define(Co.RESET_KEY, "bool", true) -- D-140: default = the next character starts from zero
local NEG_MS = 2000 -- literature/maps with no key are checked again after this (mod data set late)

-- ---------------------------------------------------------------- items -> description -> key
local function str(v) if v == nil then return nil end return tostring(v) end

-- Engine item -> plain description for L.keyOf (see Logic.lua).
function Co.describe(item)
    local d = { fullType = item:getFullType() }
    if item:isRecordedMedia() then
        local md = item:getMediaData()
        d.media, d.mediaId = true, md and str(md:getId()) or nil
        return d
    end
    if item:IsMap() then
        d.map = true
        if item.getMapID then d.mapId = str(item:getMapID()) end
    end
    if item:IsLiterature() then
        local st = item:getSkillTrained()
        d.skillBook = st ~= nil and SkillBook ~= nil and SkillBook[st] ~= nil
        local lr = item:getLearnedRecipes()
        d.recipes = lr and lr:size() or 0
        if item:hasModData() then
            local md = item:getModData()
            d.mdRecipe = str(md.learnedRecipe)
            local pm = md.printMedia
            if type(pm) == "table" and pm.id ~= nil then
                d.printMedia = str(pm.id)
                local det = PrintMediaDefinitions and PrintMediaDefinitions.MiscDetails
                    and PrintMediaDefinitions.MiscDetails[pm.id]
                d.printMap = det ~= nil and det.location1 ~= nil
            end
        end
    end
    return d
end

-- Key cache: weak on the item. Plain items never change (false forever); literature and maps
-- without a key are checked again after NEG_MS, in case their mod data arrives later.
local cache = setmetatable({}, { __mode = "k" })
local warned = false
function Co.keyOf(item)
    if item == nil then return nil end
    local c = cache[item]
    if c ~= nil then
        if c.key then return c.key end
        if c.final or getTimestampMs() - c.t < NEG_MS then return nil end
    end
    local ok, key, final = pcall(function()
        local plain = not item:isRecordedMedia() and not item:IsLiterature() and not item:IsMap()
        if plain then return nil, true end
        return L.keyOf(Co.describe(item)), false
    end)
    if not ok then
        if not warned then warned = true; K.log("Collect: oggetto non riconosciuto (" .. tostring(key) .. ")") end
        key, final = nil, true
    end
    cache[item] = { key = key, final = final, t = getTimestampMs() }
    return key
end

-- ---------------------------------------------------------------- world store
function Co.store()
    if Co.data then return Co.data end
    if not ModData then return nil end
    Co.data = L.ensureStore(ModData.getOrCreate(Co.MODDATA))
    return Co.data
end

function Co.isFound(item)
    local key = Co.keyOf(item)
    return key ~= nil and L.isFound(Co.store(), key)
end

-- Icon state for the inventory (D-26): "read" | "found" | "new" | nil. read = vanilla check.
function Co.statusOf(item, read)
    local key = Co.keyOf(item)
    return L.status(key, key ~= nil and L.isFound(Co.store(), key), read)
end

-- For other modules (Inventory pane): an error turns off only Collect (D-44).
-- Returns false when Collect is off or failed, "none" when there is no icon.
Co.guardedStatus = K.guard(Co.ID, function(item, read) return Co.statusOf(item, read) or "none" end)

-- ---------------------------------------------------------------- tracking
local function list(c)
    local items = c:getItems()
    return items:size(), function(i) return items:get(i - 1) end
end
local function inner(it)
    if instanceof(it, "InventoryContainer") then return it:getInventory() end
    return nil
end

-- Marks everything the player carries (D-138). Returns the number of new keys.
function Co.scanPlayer(player)
    local store = Co.store()
    if not store or not player then return 0 end
    local n = 0
    L.walk(player:getInventory(), list, inner, function(it)
        if L.markFound(store, Co.keyOf(it)) then n = n + 1 end
    end)
    return n
end

function Co.scanAll()
    local n = 0
    for i = 0, getNumActivePlayers() - 1 do
        local p = getSpecificPlayer(i)
        if p and not p:isDead() then n = n + Co.scanPlayer(p) end
    end
    return n
end

-- Mod added to a game in progress (RF-4.8): what the character already read counts as found.
-- Skill books and recipe magazines from the read-books list, schematics from known recipes.
-- Print media, maps and media have no vanilla list: they count once carried.
function Co.seedFromVanilla(player)
    local store = Co.store()
    if not store or not player then return 0 end
    local n = 0
    local read = player:getAlreadyReadBook()
    for i = 0, (read and read:size() or 0) - 1 do
        -- a temporary item (never added to a container) gives the same description as a real one
        local ok, d = pcall(function()
            local it = instanceItem(read:get(i))
            if not it or not it:IsLiterature() then return nil end
            local x = Co.describe(it)
            x.mdRecipe, x.printMedia, x.printMap = nil, nil, nil -- random per instance: not from the type
            return x
        end)
        if ok and d and L.markFound(store, L.keyOf(d)) then n = n + 1 end
    end
    local known = player:getKnownRecipes()
    for i = 0, (known and known:size() or 0) - 1 do
        if L.markFound(store, L.keyOf({ mdRecipe = tostring(known:get(i)) })) then n = n + 1 end
    end
    return n
end

local function onInventoryChanged() Co.scanAll() end

-- Character death (D-140): with the setting on, the world's found list starts again from zero
-- for the next character; with it off, the list is kept.
function Co.onPlayerDeath()
    if not C.get(Co.RESET_KEY) then return end
    local n = L.clearFound(Co.store())
    K.log("Collect: PG morto, azzerati " .. n .. " trovati (" .. Co.RESET_KEY .. ")")
end

-- Item moved by a transfer or grab action: marked at once if it lands in the character inventory
-- (nested bags included), with the contents of a bag moved in. Transfers do not fire
-- OnContainerUpdate, so without this the icon waited for the next unrelated update.
function Co.onTransfer(action, it)
    local dest, chr = action.destContainer, action.character
    if not dest or not chr or not it or not dest:isInCharacterInventory(chr) then return end
    local store = Co.store()
    if not store then return end
    L.markFound(store, Co.keyOf(it))
    local sub = inner(it)
    if sub then L.walk(sub, list, inner, function(x) L.markFound(store, Co.keyOf(x)) end) end
end
local gTransfer = K.guard(Co.ID, Co.onTransfer)

-- Wrappers installed when the module starts in game, not when this file loads: RSK/ loads before
-- the vanilla TimedActions/ files, which recreate the action classes and would drop the hook.
-- Installing again is harmless (a class already wrapped is left alone).
function Co.wrapTransfer(self, item, ...)
    local r = Co.origTransfer(self, item, ...)
    gTransfer(self, self.item)
    return r
end
-- Picking up from the floor: self.item is the world item, the inventory item is read before.
function Co.wrapGrab(self, item, ...)
    local wi = self.item
    local it = wi and wi.getItem and wi:getItem() or nil
    local r = Co.origGrab(self, item, ...)
    gTransfer(self, it)
    return r
end

function Co.installHooks()
    local TA, GA = ISInventoryTransferAction, ISGrabItemAction
    if TA and TA.transferItem and TA.transferItem ~= Co.wrapTransfer then
        Co.origTransfer, TA.transferItem = TA.transferItem, Co.wrapTransfer
    end
    if GA and GA.transferItem and GA.transferItem ~= Co.wrapGrab then
        Co.origGrab, GA.transferItem = GA.transferItem, Co.wrapGrab
    end
    return TA ~= nil and TA.transferItem == Co.wrapTransfer, GA ~= nil and GA.transferItem == Co.wrapGrab
end

-- ---------------------------------------------------------------- module
Co.moduleDef = K.register{
    id = Co.ID, when = "game",
    start = function(m)
        Co.data = nil
        local seeded = 0
        for i = 0, getNumActivePlayers() - 1 do
            local p = getSpecificPlayer(i)
            if p and not p:isDead() then seeded = seeded + Co.seedFromVanilla(p) end
        end
        local carried = Co.scanAll()
        local hT, hG = Co.installHooks()
        K.log("Collect: trovati " .. L.count(Co.store()) .. " (nuovi da dati vanilla " .. seeded .. ", addosso " .. carried
            .. "); aggancio trasferimento " .. tostring(hT) .. ", raccolta " .. tostring(hG))
        B.on("InventoryChanged", onInventoryChanged, m.id)
        B.on("PlayerDeath", Co.onPlayerDeath, m.id)
    end,
    stop = function()
        Co.data = nil
    end,
}
