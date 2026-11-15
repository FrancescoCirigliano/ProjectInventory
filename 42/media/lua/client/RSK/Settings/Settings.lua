-- RSK.Settings - M5, P2.5: Settings window (D-125, RF-5.8). Opens from the gear button in the title
-- of the player inventory, from RSK.Settings.open() or, with the Inventory module off, from the world context menu
-- (so it can be turned back on). Every change applies live and is saved in RSK_config.txt (D-47); no Mod Options
-- (D-126). Core service: always on, cannot be disabled.
require "ISUI/ISInventoryPage"
require "ISUI/ISButton"
require "RSK/Core/Bootstrap"
require "RSK/UI/UI"
require "RSK/Inventory/Inventory"
require "RSK/Settings/Logic"

local K, B, C, T, D, UI = RSK.Core, RSK.Bus, RSK.Config, RSK.Theme, RSK.UI.Draw, RSK.UI
local S = RSK.Settings
local L = S.Logic
S.ID = "Settings"

local function tx(k, ...) return getText("UI_RSK_Set_" .. k, ...) end
local function G(fn) return K.guard(S.ID, fn) end

local WIN_W, WIN_H, PAD = 520, 560, 16

local function modName(id)
    local key = "UI_RSK_Set_Mod_" .. id
    local t = getText(key)
    return (t and t ~= key) and t or id
end

-- ---------------------------------------------------------------- window
local Win = UI.Window:derive("RSK_SettingsWindow")
S.Window = Win

-- Single-choice button group: the active one is "primary" (Stile_UI, Settings).
local function choiceRow(win, parent, y, values, textOf, current, onPick)
    local n = #values
    local gap = 8
    local w = (WIN_W - 2 * PAD - gap * (n - 1)) / n
    local row = { buttons = {}, current = current }
    for i, v in ipairs(values) do
        local b = UI.add(parent, UI.Button:new(PAD + (i - 1) * (w + gap), y, w, 44, textOf(v), win, function() onPick(v) end))
        row.buttons[v] = b
    end
    function row.update(cur)
        for v, b in pairs(row.buttons) do b.style = (v == cur()) and "primary" or "secondary" end
    end
    row.update(current)
    win.rows[#win.rows + 1] = row
    return row
end

local function caption(parent, y, text)
    return UI.add(parent, UI.Label:new(PAD, y, WIN_W - 2 * PAD, text, "label", { tok = "muted" }))
end

function Win:createChildren()
    UI.Window.createChildren(self)
    self.rows, self.pages, self.modRows = {}, {}, {}
    local y0 = self:contentY()
    local pageY, pageH = y0 + 40, WIN_H - y0 - 40
    local function page(id)
        local p = self:addContent(UI.Panel:new(0, pageY, WIN_W, pageH, { bg = false, border = false }))
        self.pages[id] = p
        return p
    end
    self.tabs = self:addContent(UI.Tabs:new(PAD, y0, WIN_W - 2 * PAD, {
        { id = "look", text = tx("TabLook") }, { id = "inventory", text = tx("TabInventory") },
        { id = "modules", text = tx("TabModules") },
    }, self, function(win, id) win:showPage(id) end))

    -- Appearance: preset and scale tweak
    local p = page("look")
    caption(p, PAD, tx("Preset"))
    choiceRow(self, p, PAD + 28, T.PRESET_ORDER, function(v) return tx("Preset_" .. v) end,
        function() return C.get("theme.preset") end, function(v) T.setPreset(v) end)
    caption(p, PAD + 92, tx("Scale"))
    self.scale = UI.add(p, UI.Slider:new(PAD, PAD + 120, WIN_W - 2 * PAD, L.SCALE_MIN, L.SCALE_MAX, C.get("ui.scale"), nil,
        function(_, v) C.set("ui.scale", math.floor(v * 100 + 0.5) / 100) end,
        { step = L.SCALE_STEP, onRelease = true, format = function(v) return string.format("%.2f", v) end }))

    -- Inventory: equipped items and icon size
    p = page("inventory")
    caption(p, PAD, tx("Equipped"))
    choiceRow(self, p, PAD + 28, { "group", "hide" }, function(v) return tx("Equipped_" .. v) end,
        function() return C.get("inventory.equipped") end, function(v) C.set("inventory.equipped", v) end)
    caption(p, PAD + 92, tx("Icons"))
    choiceRow(self, p, PAD + 120, RSK.Inventory.Logic.ICON_ORDER, function(v) return tx("Icons_" .. v) end,
        function() return C.get("inventory.iconSize") end, function(v) C.set("inventory.iconSize", v) end)
    -- Collectibles: reset the found list when the character dies (D-140)
    caption(p, PAD + 184, tx("Collect"))
    self.resetOnDeath = UI.add(p, UI.Toggle:new(PAD, PAD + 212, WIN_W - 2 * PAD, tx("ResetOnDeath"),
        C.get("collect.resetOnDeath") and true or false, self,
        function(win, v) C.set("collect.resetOnDeath", v and true or false); win:refresh() end))

    -- Modules: toggle + status
    p = page("modules")
    local y = PAD
    for _, id in ipairs(L.MODULES) do
        if K.modules[id] then
            local t = UI.add(p, UI.Toggle:new(PAD, y, WIN_W - 2 * PAD, modName(id), C.get("module." .. id), self,
                function(win, v) K.setEnabled(id, v); win:refresh() end))
            local st = UI.add(p, UI.Label:new(PAD + 44, y + 26, WIN_W - 2 * PAD - 44, "", "label", { tok = "muted" }))
            self.modRows[#self.modRows + 1] = { id = id, toggle = t, status = st }
            y = y + 64
        end
    end

    -- Reset to defaults (RF-5.9): second click within 3 s
    self.reset = self:addContent(UI.Button:new(PAD, WIN_H - PAD - 44, 240, 44, tx("Reset"), self, Win.onReset, { style = "danger" }))
    self:showPage("look")
    self:refresh()
end

function Win:showPage(id)
    for k, pg in pairs(self.pages) do pg:setVisible(k == id) end
end

function Win:refresh()
    for _, row in ipairs(self.rows) do row.update(row.current) end
    if self.resetOnDeath then self.resetOnDeath.value = C.get("collect.resetOnDeath") and true or false end
    if self.scale and not self.scale.dragging then self.scale.value = math.max(L.SCALE_MIN, math.min(L.SCALE_MAX, C.get("ui.scale"))) end
    for _, r in ipairs(self.modRows) do
        local m = K.modules[r.id]
        r.toggle.value = C.get("module." .. r.id) and true or false
        local st, missing = L.moduleStatus(m.state, m.requires, K.isActive)
        local text, tok = nil, "muted"
        if st == "requires" then
            local names = {}
            for _, mid in ipairs(missing) do names[#names + 1] = modName(mid) end
            text = tx("St_requires", table.concat(names, ", "))
        else
            text = tx("St_" .. st) -- "requires" needs the argument: called only above
            if st == "failed" then tok = "danger" end
        end
        r.status:setText(text)
        r.status.tok = tok
    end
end

function Win:onReset()
    local now = getTimestampMs()
    if not L.confirmed(self.armedAt, now) then
        self.armedAt = now
        self.reset:setText(tx("ResetConfirm"))
        return
    end
    self.armedAt = nil
    self.reset:setText(tx("Reset"))
    S.resetAll()
end

function Win:update()
    UI.Window.update(self)
    if self.armedAt and not L.confirmed(self.armedAt, getTimestampMs()) then
        self.armedAt = nil
        self.reset:setText(tx("Reset"))
    end
end

-- ---------------------------------------------------------------- opening and reset
function S.isOpen() return S.win ~= nil end

function S.open()
    if S.win then S.win:bringToTop(); return S.win end
    local s = T.scale()
    local core = getCore()
    local x = math.max(0, (core:getScreenWidth() / s - WIN_W) / 2)
    local y = math.max(0, (core:getScreenHeight() / s - WIN_H) / 2)
    local win = Win:new(x, y, WIN_W, WIN_H, tx("Title"), { collapsible = false, onClose = function() S.win = nil end })
    win.update = G(Win.update)
    win:open()
    S.win = win
    return win
end

function S.close() if S.win then S.win:close() end end
function S.toggle() if S.win then S.close() else S.open() end end

-- Every setting back to default, modules included (on or off as the config says).
function S.resetAll()
    C.reset(L.resetKeys(C.order))
    for _, id in ipairs(K.order) do
        local m = K.modules[id]
        if not m.core then
            local on = C.get("module." .. id) and true or false
            if on ~= K.isActive(id) then K.setEnabled(id, on) end
        end
    end
    if S.win then S.win:refresh() end
end

local function refreshWin() if S.win then S.win:refresh() end end

-- ---------------------------------------------------------------- button in the player inventory title
local gearTex
local function gear()
    if gearTex == nil then gearTex = getTexture("media/ui/RSK/ui_gear.png") or false end
    return gearTex or nil
end

local function gearPre(b)
    if S.isOpen() then D.fill(b, 0, 0, b.width, b.height, "bg")
    elseif b:isMouseOver() then D.fill(b, 0, 0, b.width, b.height, "hover") end
end

local function gearPost(b)
    if not b.image then return end
    local s = T.px(T.base.inv.titleIcon)
    local tok = S.isOpen() and "accent" or (b:isMouseOver() and "text" or "muted")
    D.texture(b, b.image, (b.width - s) / 2, (b.height - s) / 2, s, s, tok)
end

local function onGear() S.toggle() end

local function attach(page)
    local size = T.px(T.base.inv.titleBtn)
    local b = ISButton:new(0, 0, size, size, "", page, G(onGear))
    b:initialise()
    b.borderColor.a, b.backgroundColor.a, b.backgroundColorMouseOver.a = 0, 0, 0
    b:setImage(gear())
    b:setTooltip(tx("Button"))
    page:addChild(b)
    page.rskSettingsBtn = b
    RSK.Inventory.Page.skinTitleButton(page, b, G(gearPre), G(gearPost))
end
local gAttach = G(attach)

local function detachAll()
    for page in pairs(RSK.Inventory.pages or {}) do
        local b = page.rskSettingsBtn
        if b then
            pcall(function()
                RSK.Inventory.Page.unskinTitleButton(page, b)
                page:removeChild(b)
            end)
            page.rskSettingsBtn = nil
        end
    end
end

-- With Inventory off there is no button: world context menu entry to reopen the settings (D-128).
local function onWorldMenu(playerNum, context, worldObjects, test)
    if test or K.isActive("Inventory") then return end
    context:addOption(tx("Menu"), nil, function() S.open() end)
end

if not S.hooked then
    S.hooked = true
    local o = { pageUpdate = ISInventoryPage.update }
    S.orig = o
    function ISInventoryPage:update(...)
        o.pageUpdate(self, ...)
        if self.onCharacter and self.rskStyled and not self.rskSettingsBtn and K.isActive(S.ID)
            and K.isActive("Inventory") then gAttach(self) end
    end
end

-- ---------------------------------------------------------------- module
local function onModule(id)
    if id == "Inventory" and not K.isActive("Inventory") then detachAll() end
    refreshWin()
end

S.moduleDef = K.register{
    id = S.ID, when = "game", core = true, requires = { "UI" },
    start = function(m)
        B.on("ConfigChanged", refreshWin, m.id)
        B.on("ModuleStarted", onModule, m.id)
        B.on("ModuleStopped", onModule, m.id)
        B.on("ModuleFailed", onModule, m.id)
        if Events and Events.OnFillWorldObjectContextMenu then Events.OnFillWorldObjectContextMenu.Add(G(onWorldMenu)) end
    end,
    stop = function()
        detachAll()
        S.close()
    end,
}
