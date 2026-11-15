-- RSK.Inventory.Page - themed ISInventoryPage window (D-60, D-61; Stile_UI "Inventory window").
-- Title 36 + load bar 28 (D-64, D-65) (stays visible when collapsed: it is part of titleBarHeight),
-- container column on the right, bottom bar. Vanilla logic unchanged: only sizes and drawing change.
require "ISUI/ISInventoryPage"
require "RSK/Inventory/Pane"

local T, D, IL, Mute = RSK.Theme, RSK.UI.Draw, RSK.Inventory.Logic, RSK.UI.Mute
local I = RSK.Inventory
I.Page = I.Page or {}
I.pages = I.pages or setmetatable({}, { __mode = "k" })
local W = I.Page

local TITLE_KIDS = { "closeButton", "infoButton", "pinButton", "collapseButton", "lootAll" }
-- Title buttons of other modules, right to left: search (M6), character (M2, player inventory only).
local TITLE_ADDONS = { "rskSearchBtn", "rskEquipBtn", "rskSettingsBtn" }

local function px(n) return T.px(n) end
local function isOn() return RSK.Core.isActive("Inventory") end
local function G(fn) return RSK.Core.guard("Inventory", fn) end
-- UI child of the window, only if it exists as an element: in the player window "lootAll" is not a
-- button but the class function ISInventoryPage.lootAll (same name, see the vanilla FIXME).
local function kid(page, k)
    local el = rawget(page, k)
    return type(el) == "table" and el.javaObject ~= nil and el or nil
end

function W.titleH() return px(T.base.inv.titleH) end
function W.headH() return px(T.base.inv.titleH + T.base.inv.loadH) end

-- ISUIElement:drawRect/drawText do not draw when isCollapsed: title and load bar must stay visible.
local function open(page, fn)
    local c = page.isCollapsed
    page.isCollapsed = false
    local ok, err = pcall(fn, c)
    page.isCollapsed = c
    if not ok then error(err, 0) end
end

-- ---------------------------------------------------------------- vanilla children skins
local function skin(page, el, pre, post)
    if not el or rawget(el, "rskSkin") then return end
    page.rskSkins = page.rskSkins or {}
    page.rskSkins[el] = true
    Mute.skin(el, pre and G(pre), post and G(post), isOn)
end

local function iconPre(b) if b:isMouseOver() then D.fill(b, 0, 0, b.width, b.height, "hover") end end
local function iconPost(b)
    if not b.image then return end
    local s = px(T.base.inv.titleIcon)
    D.texture(b, b.image, (b.width - s) / 2, (b.height - s) / 2, s, s, b:isMouseOver() and "text" or "muted")
end

local function textPre(b)
    local on = b:isMouseOver() and b.enable ~= false
    local alt = b.target ~= nil and type(b.target) == "table" and b.target.altColor
    D.fill(b, 0, 0, b.width, b.height, on and "sel" or "panel2")
    D.border(b, 0, 0, b.width, b.height, (on or alt) and "accent" or "line")
end
local function textPost(b)
    local a = b.enable == false and T.alpha.disabled or 1
    local title = b.title or ""
    -- Icon-only buttons (e.g. "Transfer same type"): the vanilla image in its own colours.
    if title == "" and b.image then
        local s = math.min(b.width, b.height) - px(8)
        b:drawTextureScaledAspect(b.image, (b.width - s) / 2, (b.height - s) / 2, s, s, a, 1, 1, 1)
        return
    end
    D.textMid(b, title, b.width / 2, b.height / 2, "label", "text", a, "center", b.width - px(8))
end

local function containerBox(b) return px(T.base.w.colContainers) end
local function containerPre(b)
    local page = b.parent and b.parent.parent
    local box = containerBox(b)
    local bx, by = (b.width - box) / 2, (b.height - box) / 2
    local selected = page ~= nil and page.inventoryPane ~= nil and b.inventory == page.inventoryPane.inventory
    if selected then D.fill(b, bx, by, box, box, "sel")
    elseif b:isMouseOver() then D.fill(b, bx, by, box, box, "hover") end
    if page and page.blinkContainer and b.inventory
        and (not page.blinkContainerType or b.inventory:getType() == page.blinkContainerType) then
        D.fill(b, bx, by, box, box, "danger", page.blinkAlphaContainer or 0.5)
    end
    D.border(b, bx, by, box, box, selected and "accent" or "line")
end
local function containerPost(b)
    local box, s = containerBox(b), px(T.base.inv.containerIcon)
    if b.image then b:drawTextureScaledAspect(b.image, (b.width - s) / 2, (b.height - s) / 2, s, s, 1, 1, 1, 1) end
    if b.textureOverride then
        local o = px(11)
        local e = (b.width + box) / 2
        b:drawTextureScaledAspect(b.textureOverride, e - o - px(2), (b.height + box) / 2 - o - px(2), o, o, 1, 1, 1, 1)
    end
end

function W.skinContainerButton(page, b) skin(page, b, containerPre, containerPost) end

-- Title button added by another module (M6): skin and removal.
function W.skinTitleButton(page, b, pre, post) skin(page, b, pre, post) end
function W.unskinTitleButton(page, b)
    if page.rskSkins then page.rskSkins[b] = nil end
    Mute.unskin(b)
end

function W.skinControls(page, controlsUI)
    for _, c in ipairs(controlsUI.controls or {}) do
        if c.title ~= nil and c.setTitle then skin(page, c, textPre, textPost) end
    end
end

function W.skinChildren(page)
    for _, k in ipairs({ "closeButton", "infoButton", "pinButton", "collapseButton" }) do
        skin(page, kid(page, k), iconPre, iconPost)
    end
    skin(page, kid(page, "lootAll"), textPre, textPost)
    for _, b in ipairs(page.backpacks or {}) do W.skinContainerButton(page, b) end
    for _, b in ipairs(page.buttonPool or {}) do W.skinContainerButton(page, b) end
    if page.controlsUI then W.skinControls(page, page.controlsUI) end
end

-- ---------------------------------------------------------------- layout
-- Same steps as ISInventoryPage:onInventoryContainerSizeChanged, with the Stile_UI column.
function W.relayoutContainers(page)
    local bs = page.buttonSize
    page.inventoryPane:setWidth(page.width - bs)
    page.containerButtonPanel:setWidth(bs)
    page.containerButtonPanel:setX(page.width - bs)
    -- X = 0 as in addContainerButton: buttons are anchored right, so narrowing the column
    -- (setWidth) moves them left by the difference and clips them.
    for _, b in ipairs(page.buttonPool or {}) do b:setX(0); b:setWidth(bs); b:setHeight(bs) end
    local y = -1
    for _, b in ipairs(page.backpacks or {}) do
        b:setX(0); b:setY(y); b:setWidth(bs); b:setHeight(bs)
        y = y + bs
    end
end

-- Self-correcting container column (D-63): vanilla (and other mods) may create or resize buttons
-- at vanilla size after our layout (refreshBackpacks before the first frame, buttonSize reset):
-- every frame the column and button sizes are checked and realigned only if they differ.
function W.ensureContainers(page)
    local bs = px(T.base.inv.containerCol)
    if page.buttonSize ~= bs then W.layout(page); return end
    local panel = page.containerButtonPanel
    local bad = panel:getWidth() ~= bs or panel:getX() ~= page.width - bs
        or page.inventoryPane:getWidth() ~= page.width - bs
    if not bad then
        local y = -1
        for _, b in ipairs(page.backpacks or {}) do
            if b:getX() ~= 0 or b:getWidth() ~= bs or b:getHeight() ~= bs or b:getY() ~= y then bad = true; break end
            y = y + bs
        end
    end
    if bad then W.relayoutContainers(page) end
end

-- Title: [collapse/pin] title ... [Loot all] [character] [search] [info] [close]. Redone every frame (a few setX).
function W.layoutTitle(page)
    local inv = T.base.inv
    local th, bsz, pad, gap = W.titleH(), px(inv.titleBtn), px(inv.titlePad), px(4)
    local y = math.floor((th - bsz) / 2)
    local function place(el, x, w)
        if not el then return end
        el:setX(x); el:setY(y); el:setWidth(w or bsz); el:setHeight(bsz)
    end
    local close, info, loot = kid(page, "closeButton"), kid(page, "infoButton"), kid(page, "lootAll")
    place(kid(page, "pinButton"), pad)
    place(kid(page, "collapseButton"), pad)
    local right = page.width - pad - bsz
    place(close, right)
    if close and not close:isVisible() then right = page.width - pad + gap end
    if info and info:isVisible() then
        right = right - gap - bsz
        place(info, right)
    end
    for _, k in ipairs(TITLE_ADDONS) do
        local b = kid(page, k)
        if b then
            right = right - gap - bsz
            place(b, right)
        end
    end
    if loot and loot:isVisible() then
        local w = D.measure("label", loot.title or "") + px(24)
        right = right - gap - w
        place(loot, right, w)
    end
    page.rskTitleRight = right
end

-- Bottom bar (Transfer all...): vanilla puts it above the grip only when it rearranges the controls;
-- if the window height changes later (resize, D-118 default layout) it stays halfway. Here it is
-- realigned, with the list above it, only when it does not match (a check of a few numbers on each draw).
function W.fixControls(page)
    local cu, rw, pane = page.controlsUI, page.resizeWidget, page.inventoryPane
    if not (cu and rw and pane) or not cu:isVisible() then return end
    local y = page.height - rw:getHeight() - cu:getHeight() -- above the bottom band drawn in drawPost
    if cu:getY() ~= y then cu:setY(y) end
    if cu:getWidth() ~= page.width then cu:setWidth(page.width) end
    local h = y - pane:getY()
    if h > 0 and pane:getHeight() ~= h then
        pane:setHeight(h)
        if page.containerButtonPanel then page.containerButtonPanel:setHeight(h) end
    end
end

function W.layout(page)
    page.buttonSize = px(T.base.inv.containerCol)
    W.relayoutContainers(page)
    W.layoutTitle(page)
    local c = IL.columns(T.base, I.Pane.dims())
    page.minimumWidth = px(c.column2 + 100 + c.typeMin) + page.buttonSize
    -- Collapsed window: the vanilla draw limit equals the header at the scale it was collapsed at;
    -- with a smaller scale the list would end below the limit and show without background.
    if page.isCollapsed then page:setMaxDrawHeight(W.headH()) end
    I.Pane.style(page.inventoryPane)
end

function W.style(page)
    if not page.rskStyled then
        local s = { geoms = {}, minimumWidth = page.minimumWidth }
        for _, k in ipairs(TITLE_KIDS) do
            local el = kid(page, k)
            if el then
                -- right-anchored elements are restored relative to the right edge
                local right = el.anchorRight and not el.anchorLeft
                s.geoms[k] = { x = right and (page.width - el:getX()) or el:getX(), right = right,
                    y = el:getY(), w = el:getWidth(), h = el:getHeight() }
            end
        end
        page.rskSaved = s
        page.rskStyled = true
        I.pages[page] = true
        W.skinChildren(page)
    end
    W.layout(page)
end

function W.unstyle(page)
    if not page.rskStyled then return end
    local s = page.rskSaved
    page.rskStyled = nil
    for el in pairs(page.rskSkins or {}) do Mute.unskin(el) end
    page.rskSkins = nil
    for k, g in pairs(s.geoms) do
        local el = kid(page, k)
        if el then
            el:setX(g.right and (page.width - g.x) or g.x); el:setY(g.y); el:setWidth(g.w); el:setHeight(g.h)
        end
    end
    I.Pane.unstyle(page.inventoryPane)
    page:onInventoryContainerSizeChanged() -- container column and vanilla widths
    page.minimumWidth = s.minimumWidth
    if page.isCollapsed then page:setMaxDrawHeight(page:titleBarHeight()) end
    page.rskSaved = nil
end

-- ---------------------------------------------------------------- drawing
-- Title as in vanilla: container name; for loot also fire fuel and occupied seat.
function W.titleText(page)
    local text = page.title or ""
    if page.onCharacter then return text end
    local inv = page.inventoryPane and page.inventoryPane.inventory
    local fireTile = inv and inv:getParent()
    if fireTile then
        local sq = fireTile:getSquare()
        local campfire = sq and CCampfireSystem and CCampfireSystem.instance
            and CCampfireSystem.instance:getLuaObjectOnSquare(sq)
        if campfire then
            text = text .. ": " .. ISCampingMenu.timeString(luautils.round(campfire.fuelAmt))
        elseif fireTile:isFireInteractionObject() then
            if fireTile:isPropaneBBQ() and not fireTile:hasPropaneTank() then
                text = text .. ": " .. getText("IGUI_BBQ_NeedsPropaneTank")
            else
                text = text .. ": " .. tostring(ISCampingMenu.timeString(fireTile:getFuelAmount()))
            end
        end
    end
    if inv and inv:isOccupiedVehicleSeat() then text = text .. " " .. getText("IGUI_invpage_Occupied") end
    return text
end

-- Load bar (D-22, D-32): capacity as in vanilla (player inventory: getMaxWeight;
-- other containers: effective capacity).
-- Weight: player inventory = getInventoryWeight (real weight; vanilla getCapacityWeight gives 0
-- with debug ghost mode or unlimited carry); other containers = ISInventoryPage.loadWeight.
function W.drawLoad(page, th, hh)
    local inv = T.base.inv
    local playerObj = getSpecificPlayer(page.player)
    local container = page.inventoryPane.inventory
    local cap, weight = page.capacity, container and ISInventoryPage.loadWeight(container) or 0
    if playerObj and container == playerObj:getInventory() then
        cap, weight = playerObj:getMaxWeight(), playerObj:getInventoryWeight()
    end
    local li = IL.loadInfo(weight, cap)
    local pad = px(inv.loadPad)
    local cy = th + (hh - th) / 2
    local right = page.width - pad
    local capText = li.cap and (" / " .. li.cap) or nil
    local capW = capText and D.measure("rowSmall", capText) or 0
    if capText then D.textMid(page, capText, right, cy, "rowSmall", "muted", 1, "right") end
    local loadW = D.textMid(page, li.load, right - capW, cy, "rowSmall", li.tok == "danger" and "danger" or "text", 1, "right")
    local barR = right - capW - loadW - px(12)
    local bh = px(inv.loadBar)
    if barR > pad then
        D.fill(page, pad, cy - bh / 2, barR - pad, bh, "panel2")
        if li.frac > 0 then D.fill(page, pad, cy - bh / 2, math.max(1, math.floor((barR - pad) * li.frac)), bh, li.tok) end
    end
end

-- After the muted vanilla prerender (before the children).
function W.drawPre(page)
    W.ensureContainers(page)
    W.layoutTitle(page)
    open(page, function(collapsed)
        local w, th, hh = page.width, W.titleH(), W.headH()
        local h = collapsed and hh or page.height
        D.fill(page, 0, 0, w, h, "panel")
        D.fill(page, 0, 0, w, th, "panel2")
        if page.blink then D.fill(page, 0, 0, w, th, "accent", (page.blinkAlpha or 1) * 0.6) end
        local inv = T.base.inv
        local tx = px(inv.titlePad) + px(inv.titleBtn) + px(inv.gap)
        local limit = (page.rskTitleRight or w) - px(inv.gap)
        D.textMid(page, W.titleText(page), tx, th / 2, "invTitle", "text", 1, "left", math.max(0, limit - tx))
        W.drawLoad(page, th, hh)
        D.fill(page, 0, hh - 1, w, 1, "line")
        if not collapsed then
            W.fixControls(page)
            local pane = page.inventoryPane
            D.fill(page, w - page.buttonSize, pane:getY(), 1, pane:getHeight(), "line")
            local cu = page.controlsUI
            if cu and cu:isVisible() and cu:getHeight() > 0 then
                D.fill(page, 0, cu:getY(), w, cu:getHeight(), "panel2")
                D.fill(page, 0, cu:getY(), w, 1, "line")
            end
        end
    end)
end

-- After the muted vanilla render (above the children): bottom bar and border.
function W.drawPost(page)
    open(page, function(collapsed)
        local w = page.width
        local h = collapsed and W.headH() or page.height
        if not collapsed then
            local rh = page.resizeWidget and (page.resizeWidget:getHeight() + 1) or px(12)
            D.fill(page, 0, h - rh, w, rh, "panel2")
            D.fill(page, 0, h - rh, w, 1, "line")
            local g = math.max(px(6), rh - px(4))
            D.fill(page, w - g - px(2), h - px(3), g, 1, "muted")
            D.fill(page, w - px(3), h - g - px(2), 1, g, "muted")
        end
        D.border(page, 0, 0, w, h, "line")
    end)
end
