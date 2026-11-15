-- RSK.Equipment - M2, P2.4: the vanilla character window gives way to the M2 window (RF-2.8, D-77).
-- Tutorial and multiplayer stay vanilla (D-42). Module off or failed: transparent hooks,
-- panels handed back to the vanilla window (D-44). Nothing saved in ModData.
require "ISUI/ISEquippedItem"
require "ISUI/ISLayoutManager"
require "XpSystem/ISUI/ISCharacterInfoWindow"
require "RSK/Core/Bootstrap"
require "RSK/Inventory/Inventory"
require "RSK/Equipment/Window"
require "RSK/Equipment/WoundAlert"

local K = RSK.Core
local Q = RSK.Equipment
Q.ID = "Equipment"
Q.windows = Q.windows or {}

function Q.isOn() return K.isActive(Q.ID) end
local function G(fn) return K.guard(Q.ID, fn) end

-- Errors in methods called by the engine: module off and back to vanilla (D-44).
local function guardMethods(cls, names)
    for _, name in ipairs(names) do cls[name] = G(cls[name]) end
end
if not Q.guarded then
    Q.guarded = true
    guardMethods(Q.Slot, { "update", "render", "onMouseDown", "onMouseUp", "onMouseUpOutside",
        "onMouseMove", "onMouseMoveOutside", "onRightMouseUp" })
    guardMethods(Q.Window, { "update", "prerender", "render", "onMouseDown", "onResize" })
    guardMethods(Q.Page, { "prerender" })
    guardMethods(Q.Scroller, { "prerender", "render", "onMouseWheel" })
    guardMethods(Q.Profile, { "prerender" })
    guardMethods(Q.Exercises, { "prerender", "onStep", "onStart", "onStop", "onSelect" })
    guardMethods(Q.Grip, { "onMouseDown", "onMouseMove", "onMouseMoveOutside", "onMouseUp", "onMouseUpOutside" })
    guardMethods(Q.Body, { "render", "onMouseDown", "onMouseUp", "onRightMouseUp" })
    guardMethods(Q.WoundAlert.Card, { "update", "render", "onMouseDown", "onMouseUp" })
end

-- The M2 window applies only outside tutorial and multiplayer.
local function applies()
    return Q.isOn() and getCore():getGameMode() ~= "Tutorial" and not isClient()
end

local function tabOf(viewName)
    if viewName == xpSystemText.health or viewName == xpSystemText.info then return "equip" end -- Info removed (D-92)
    if viewName == xpSystemText.skills then return "skills" end
    if viewName == xpSystemText.protection then return "protection" end
    if viewName == xpSystemText.clothingIns then return "clothingIns" end
    return nil
end

function Q.destroy(n)
    local w = Q.windows[n]
    if not w then return end
    Q.windows[n] = nil
    pcall(function() if w:isShown() then w:close() end end)
    local ok, err = pcall(w.releaseViews, w)
    if not ok then K.log("Equipment: restituzione pannelli non riuscita: " .. tostring(err)) end
end

function Q.destroyAll()
    local list = {}
    for n in pairs(Q.windows) do list[#list + 1] = n end
    for _, n in ipairs(list) do Q.destroy(n) end
end

-- Player window; recreated if the vanilla window is new (new character).
function Q.get(cw)
    local n = cw.playerNum
    local w = Q.windows[n]
    if w and w.cw ~= cw then
        Q.destroy(n)
        w = nil
    end
    if not w then
        w = Q.Window:new(cw, n)
        Q.windows[n] = w
    end
    return w
end

function Q.isOpen(n)
    local w = Q.windows[n]
    return w ~= nil and w:isShown()
end

-- Default widths so M2 sits left of the inventory (D-89, D-118): once per resolution, then
-- the user's positions stay. The game writes layout.ini only when saving: until there is a save
-- the resolution is not recorded, otherwise the next launch would restore the old layout with no correction.
RSK.Config.define("equipment.layoutSaved", "string", "")

local function setPageWidth(page, x, w)
    local grip = ISLayoutManager.FindResizeWidget(page)
    if grip then grip:resize(w - page:getWidth(), 0) else page:setWidth(w) end
    page:setX(x) -- after: resizing may bring the window back on screen
end

local function applyDefaultLayout()
    if Q.layoutPending then return end
    local core = getCore()
    if core:getGameMode() == "Tutorial" or isClient() then return end
    local inv, loot = getPlayerInventory(0), getPlayerLoot(0)
    if not inv or not loot then return end
    local sw = core:getScreenWidth()
    -- "2:" = D-118 layout: redone once even where the D-89 one was applied
    local key = "2:" .. tostring(sw) .. "x" .. tostring(core:getScreenHeight())
    if Q.Logic.layoutDone(RSK.Config.get("equipment.layoutSaved"), key) then return end
    local T = RSK.Theme
    -- D-118: M2's space starts at the screen edge; M2 opens over the vanilla sidebar
    local invX, invW, lootX, lootW = Q.Logic.defaultLayout(sw, 0, T.px(Q.Logic.WIN.W), T.px(8),
        math.max(inv.minimumWidth or 0, T.px(300)), T.px(560))
    setPageWidth(inv, invX, invW)
    setPageWidth(loot, lootX, lootW)
    for _, page in ipairs({ inv, loot }) do
        if page.rskStyled then RSK.Inventory.Page.layout(page) end
    end
    Q.layoutPending = key
    K.log("Equipment: larghezze predefinite " .. key .. ": inventario x=" .. tostring(invX) .. " w=" .. tostring(invW)
        .. ", loot x=" .. tostring(lootX) .. " w=" .. tostring(lootW))
end

-- After ISLayoutManager.OnPostSave, registered earlier: widths are already in layout.ini.
local function onPostSave()
    local key = Q.layoutPending
    if not key then return end
    Q.layoutPending = nil
    RSK.Config.set("equipment.layoutSaved", Q.Logic.layoutMark(RSK.Config.get("equipment.layoutSaved"), key))
end

-- Same logic as toggleView: the same tab already visible closes, another one activates.
local gToggle = G(function(cw, tab)
    applyDefaultLayout() -- if the windows did not exist yet when the module started
    if cw:getIsVisible() then cw:close() end -- restored as visible from the saved layout
    local w = Q.get(cw)
    if w:isShown() and w.tab == tab then
        w:close()
    else
        w:show(tab)
    end
    return true
end)

local gIsActive = G(function(cw, tab)
    local w = Q.windows[cw.playerNum]
    return w ~= nil and w:isShown() and w.tab == tab
end)

-- ---------------------------------------------------------------- button in the player inventory (D-91)
local personTex
local function personIcon()
    if personTex == nil then personTex = getTexture("media/ui/RSK/ui_person.png") or false end
    return personTex or nil
end

local function personPre(b)
    local T, D = RSK.Theme, RSK.UI.Draw
    if Q.isOpen(b.parent.player) then D.fill(b, 0, 0, b.width, b.height, "bg")
    elseif b:isMouseOver() then D.fill(b, 0, 0, b.width, b.height, "hover") end
end

local function personPost(b)
    local T, D = RSK.Theme, RSK.UI.Draw
    if not b.image then return end
    local s = T.px(T.base.inv.titleIcon)
    local tok = Q.isOpen(b.parent.player) and "accent" or (b:isMouseOver() and "text" or "muted")
    D.texture(b, b.image, (b.width - s) / 2, (b.height - s) / 2, s, s, tok)
end

local function onPersonClick(page)
    if not applies() then return end
    local cw = getPlayerInfoPanel(page.player)
    if cw then cw:toggleView(xpSystemText.health) end
end

local function attachPerson(page)
    local T = RSK.Theme
    local size = T.px(T.base.inv.titleBtn)
    local b = ISButton:new(0, 0, size, size, "", page, onPersonClick)
    b:initialise()
    b.borderColor.a, b.backgroundColor.a, b.backgroundColorMouseOver.a = 0, 0, 0
    b:setImage(personIcon())
    b:setTooltip(getText("UI_RSK_Eq_OpenWindow"))
    page:addChild(b)
    page.rskEquipBtn = b
    RSK.Inventory.Page.skinTitleButton(page, b, G(personPre), G(personPost))
end

local function detachPersons()
    for page in pairs(RSK.Inventory.pages or {}) do
        local b = page.rskEquipBtn
        if b then
            pcall(function()
                RSK.Inventory.Page.unskinTitleButton(page, b)
                page:removeChild(b)
            end)
            page.rskEquipBtn = nil
        end
    end
end

local gAttachPerson = G(attachPerson)

-- ---------------------------------------------------------------- vanilla hooks (once only)
if not Q.hooked then
    Q.hooked = true
    local o = {
        toggleView = ISCharacterInfoWindow.toggleView,
        isActive = ISCharacterInfoWindow.isActive,
        saveLayout = ISCharacterInfoWindow.SaveLayout,
        sidebarPre = ISEquippedItem.prerender,
        pageUpdate = ISInventoryPage.update,
    }
    Q.orig = o

    function ISInventoryPage:update(...)
        o.pageUpdate(self, ...)
        if self.onCharacter and self.rskStyled and not self.rskEquipBtn and applies() then gAttachPerson(self) end
    end

    function ISCharacterInfoWindow:toggleView(viewName)
        local tab = applies() and tabOf(viewName)
        if tab and gToggle(self, tab) then return end
        return o.toggleView(self, viewName)
    end

    function ISCharacterInfoWindow:isActive(viewName)
        local tab = applies() and tabOf(viewName)
        if tab then return gIsActive(self, tab) end
        return o.isActive(self, viewName)
    end

    -- The saved layout must not record moved panels as detached tabs (clean saves, §2.6).
    function ISCharacterInfoWindow:SaveLayout(name, layout)
        local w = Q.windows[self.playerNum]
        if w and w.cw == self then
            w:withViewsAtHome(function() o.saveLayout(self, name, layout) end)
            return
        end
        return o.saveLayout(self, name, layout)
    end

    -- The sidebar heart disappears (D-96): M2 opens from the inventory (D-91) or with the vanilla key.
    -- The buttons below move up into its place; with the module off, in the tutorial and in MP everything is restored.
    local gHideHeart = G(function(bar)
        local heart = bar.healthBtn
        local below = bar.craftingBtn
        local dy = below and (below:getY() - heart:getY()) or 0
        local saved = { height = bar:getHeight(), ys = {} }
        for _, child in pairs(bar:getChildren()) do
            if child ~= heart and child:getY() > heart:getY() then
                saved.ys[child] = child:getY()
                child:setY(child:getY() - dy)
            end
        end
        bar:setHeight(saved.height - dy)
        heart:setVisible(false)
        bar.rskHeart = saved
    end)

    local function showHeart(bar)
        local saved = bar.rskHeart
        bar.rskHeart = nil
        for child, y in pairs(saved.ys) do child:setY(y) end
        bar:setHeight(saved.height)
        bar.healthBtn:setVisible(true)
    end

    function ISEquippedItem:prerender(...)
        local r = o.sidebarPre(self, ...)
        if self.healthBtn then
            local hide = applies()
            if hide and not self.rskHeart then gHideHeart(self)
            elseif not hide and self.rskHeart then showHeart(self) end
        end
        return r
    end

    local function markDirty(chr)
        if not chr or not instanceof(chr, "IsoPlayer") or not chr:isLocalPlayer() then return end
        local w = Q.windows[chr:getPlayerNum()]
        if w then w:onClothingChanged() end
    end
    local gDirty = G(markDirty)
    Events.OnClothingUpdated.Add(function(chr) gDirty(chr) end)
    Events.OnEquipPrimary.Add(function(chr) gDirty(chr) end)
    Events.OnEquipSecondary.Add(function(chr) gDirty(chr) end)
    Events.OnPostSave.Add(function() onPostSave() end)
    -- After an exercise vanilla puts back what it removed: even with the window closed (D-93).
    local gReequip = G(function()
        for _, w in pairs(Q.windows) do
            if w.exercises then w.exercises:reequip() end
        end
    end)
    Events.EveryOneMinute.Add(function() if Q.isOn() then gReequip() end end)
    Events.OnPlayerDeath.Add(function(chr)
        if instanceof(chr, "IsoPlayer") and chr:isLocalPlayer() then
            Q.destroy(chr:getPlayerNum())
            if chr:getPlayerNum() == 0 then Q.WoundAlert.stop() end
        end
    end)
    -- Wound warning (D-117): main character only; a new character starts with no warnings.
    local gDamage = G(function(chr) Q.WoundAlert.onDamage(chr) end)
    Events.OnPlayerGetDamage.Add(function(chr)
        if applies() and instanceof(chr, "IsoPlayer") and chr:isLocalPlayer() and chr:getPlayerNum() == 0 then gDamage(chr) end
    end)
    local gReset = G(function(chr) Q.WoundAlert.reset(chr) end)
    Events.OnCreatePlayer.Add(function(n, chr) if n == 0 and Q.isOn() then gReset(chr) end end)
end

-- ---------------------------------------------------------------- module
Q.moduleDef = K.register{
    id = Q.ID, when = "game", requires = { "Inventory" },
    start = function(m)
        -- Settings reset (D-125): M2 goes back to its default position the next time it opens.
        RSK.Bus.on("ConfigChanged", function(key, v)
            if key ~= "equipment.window" or (v ~= nil and v ~= "") then return end
            for _, w in pairs(Q.windows) do w.userPlaced = false end
        end, m.id)
        Q.showLayer(G)
        applyDefaultLayout()
        Q.WoundAlert.reset(getSpecificPlayer(0))
    end,
    stop = function()
        Q.WoundAlert.stop()
        Q.hideLayer()
        detachPersons()
        Q.destroyAll()
    end,
}
