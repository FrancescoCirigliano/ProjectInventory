-- RSK.Search - M6, P2.3: search local to the window, first level only (RF-6.1...6.5, RF-6.8, D-74, D-75).
-- Magnifier in the title of inventory, loot and nested windows; the field sits in a row below the load bar.
-- The filter removes stacks from itemslist right before restoreSelection: vanilla rows, selection and clicks
-- stay consistent and hidden items cannot be selected. Module off or failed: transparent hooks (D-44).
require "ISUI/ISInventoryPage"
require "ISUI/ISInventoryPane"
require "ISUI/ISButton"
require "RSK/Core/Bootstrap"
require "RSK/UI/UI"
require "RSK/UI/TextField"
require "RSK/Inventory/Inventory"
require "RSK/Search/Logic"

local K, B, T, D = RSK.Core, RSK.Bus, RSK.Theme, RSK.UI.Draw
local I = RSK.Inventory
local S = RSK.Search
local L = S.Logic
S.ID = "Search"

function S.isOn() return K.isActive(S.ID) end
local function G(fn) return K.guard(S.ID, fn) end
local function px(n) return T.px(n) end
local function tx(k, ...) return getText("UI_RSK_Search_" .. k, ...) end

local iconTex
local function icon()
    if iconTex == nil then iconTex = getTexture("media/ui/RSK/ui_search.png") or false end
    return iconTex or nil
end

local function color(tok, alpha)
    local r, g, b, a = T.rgba(tok)
    return { r = r, g = g, b = b, a = alpha or a }
end

local function resetScroll(pane)
    pane.smoothScrollTargetY = nil
    pane:setYScroll(0)
end

-- ---------------------------------------------------------------- button and colours
local function btnPre(b)
    local s = b.parent and b.parent.rskSearch
    if s and s.open then D.fill(b, 0, 0, b.width, b.height, "bg")
    elseif b:isMouseOver() then D.fill(b, 0, 0, b.width, b.height, "hover") end
end

local function btnPost(b)
    if not b.image then return end
    local s = b.parent and b.parent.rskSearch
    local size = px(T.base.inv.titleIcon)
    local tok = (s and s.open) and "accent" or (b:isMouseOver() and "text" or "muted")
    D.texture(b, b.image, (b.width - size) / 2, (b.height - size) / 2, size, size, tok)
end

-- Border with alpha < 1: with alpha 1 ISTextEntryBox draws it grey (it only uses red).
local function paint(s)
    local f = s.field
    f.backgroundColor = color("bg")
    f.borderColor = color("accent", 0.99)
    local r, g, b = T.rgba("text")
    f:setTextRGBA(r, g, b, 1)
    r, g, b = T.rgba("muted")
    f:setPlaceholderTextRGBA(r, g, b, 1)
end

-- ---------------------------------------------------------------- layout
-- Same steps as ISInventoryPage:update, with the search row above the list and the container column.
function S.layout(page, s)
    local inv = T.base.inv
    local head, rowH = I.Page.headH(), px(inv.searchRow)
    local pane, panel = page.inventoryPane, page.containerButtonPanel
    local y = s.open and (head + rowH) or head
    local controls = page.controlsUI and page.controlsUI.height or 0
    local h = page.height - y - page.resizeWidget.height - controls
    pane:setY(y); pane:setHeight(h)
    panel:setY(y); panel:setHeight(h)
    if not s.open then return end
    local f, pad, fh = s.field, px(inv.searchPad), px(inv.searchField)
    local fw = math.max(px(60), page.width - 2 * pad - D.measure("rowSmall", s.count) - px(inv.gap))
    f:setX(pad); f:setY(head + math.floor((rowH - fh) / 2))
    if f:getWidth() ~= fw then f:setWidth(fw) end
    if f:getHeight() ~= fh then f:setHeight(fh) end
end

-- ---------------------------------------------------------------- opening and text
function S.setQuery(page, query)
    local s = page.rskSearch
    if not s or not s.open or query == s.query then return end
    s.query, s.terms = query, L.terms(query)
    local pane = page.inventoryPane
    pane:refreshContainer()
    resetScroll(pane)
end

function S.setOpen(page, open)
    local s = page.rskSearch
    if not s or s.open == open then return end
    local pane, f = page.inventoryPane, s.field
    s.open, s.query, s.terms, s.inv = open, "", {}, pane.inventory
    f:setText("")
    f:setVisible(open)
    if open then
        s.title = page.title
        f:setPlaceholderText(tx("Placeholder", page.title or ""))
        f:focus()
    else
        f:unfocus()
    end
    pane:refreshContainer() -- when open it also updates the counter used by the layout
    S.layout(page, s)
    resetScroll(pane)
end

local gToggle = G(function(page) S.setOpen(page, not page.rskSearch.open) end)
local gClose = G(function(page) S.setOpen(page, false) end)
local gText = G(function(page, field) S.setQuery(page, field:getInternalText()) end)

local function onButton(page) if S.isOn() and page.rskSearch then gToggle(page) end end

local function attach(page)
    local inv = T.base.inv
    local s = { open = false, query = "", terms = {}, shown = 0, total = 0, count = "" }
    local size = px(inv.titleBtn)
    local b = ISButton:new(0, 0, size, size, "", page, onButton)
    b:initialise()
    b.borderColor.a, b.backgroundColor.a, b.backgroundColorMouseOver.a = 0, 0, 0
    b:setImage(icon())
    b:setTooltip(tx("Button"))
    page:addChild(b)
    page.rskSearchBtn = b
    I.Page.skinTitleButton(page, b, G(btnPre), G(btnPost))

    local f = RSK.UI.TextField:new(0, 0, 100, inv.searchField, "")
    f:initialise()
    f:instantiate()
    f.target = page
    f.onTextChangeFunction = gText
    f.onCommandEntered = function(self) self:unfocus() end
    f.onOtherKey = function(_, key)
        if key == Keyboard.KEY_ESCAPE then gClose(page) end
    end
    page:addChild(f)
    f:setVisible(false)
    s.field = f
    page.rskSearch = s
    paint(s)
end

local function detach(page)
    local s = page.rskSearch
    if not s then return end
    local wasOpen = s.open
    s.open = false
    s.field:unfocus()
    page:removeChild(s.field)
    I.Page.unskinTitleButton(page, page.rskSearchBtn)
    page:removeChild(page.rskSearchBtn)
    page.rskSearchBtn = nil
    if wasOpen then S.layout(page, s) end
    page.rskSearch = nil
    if wasOpen then page.inventoryPane:refreshContainer() end
end

local function detachAll()
    for page in pairs(I.pages) do
        local ok, err = pcall(detach, page)
        if not ok then K.log("Search: rimozione non riuscita: " .. tostring(err)) end
    end
end

-- ---------------------------------------------------------------- filter (RF-6.3...6.5)
local function textOfGroup(player)
    return function(e)
        local it = e.items[1]
        return it:getName(player), I.Pane.categoryText(it)
    end
end

local function textOfItem(player)
    return function(it) return it:getName(player), I.Pane.categoryText(it) end
end

local function searchOf(pane)
    local page = rawget(pane, "inventoryPage")
    return page and page.rskSearch or nil
end

-- Active filter: search open with at least one word.
local function activeFilter(pane)
    local s = searchOf(pane)
    if s and s.open and #s.terms > 0 then return s end
    return nil
end

local gFilter = G(function(pane)
    local s = searchOf(pane)
    if not s or not s.open then return end
    if s.inv ~= pane.inventory then -- RF-6.5: container change
        s.inv, s.query, s.terms = pane.inventory, "", {}
        s.field:setText("")
        resetScroll(pane)
    end
    -- Hidden equipped items (D-125): left out of the counter, removed before the filter (the group would remove them later).
    if I.Pane.hidesEquipped(pane) then I.Logic.dropEquipped(pane.itemslist) end
    local player = getSpecificPlayer(pane.player)
    s.shown, s.total = L.filter(pane.itemslist, s.terms, textOfGroup(player))
    s.count = tx("Count", s.shown, s.total)
end)

local gVisible = G(function(pane, items)
    local s = activeFilter(pane)
    if not s then return items end
    return L.visibleItems(items, s.terms, textOfItem(getSpecificPlayer(pane.player)))
end)

-- ---------------------------------------------------------------- window update and drawing
local gUpdate = G(function(page)
    if not page.rskSearch then attach(page); return end
    local s = page.rskSearch
    if not s.open then return end
    local f = s.field
    local show = not page.isCollapsed
    if f:getIsVisible() ~= show then f:setVisible(show) end
    if not show and f:isFocused() then f:unfocus() end -- the keyboard is never captured by a hidden field
    if s.title ~= page.title then
        s.title = page.title
        f:setPlaceholderText(tx("Placeholder", page.title or ""))
    end
    S.layout(page, s)
end)

local gDraw = G(function(page)
    local s = page.rskSearch
    if not s.open or page.isCollapsed then return end
    local inv = T.base.inv
    local head, rowH = I.Page.headH(), px(inv.searchRow)
    D.fill(page, 0, head + rowH - 1, page.width, 1, "line")
    D.textMid(page, s.count, page.width - px(inv.searchPad), head + rowH / 2, "rowSmall", "muted", 1, "right")
end)

-- ---------------------------------------------------------------- vanilla hooks (once only)
if not S.hooked then
    S.hooked = true
    local o = {
        pageUpdate = ISInventoryPage.update, pagePre = ISInventoryPage.prerender,
        pageClose = ISInventoryPage.close, collapseNow = ISInventoryPage.collapseNow,
        restore = ISInventoryPane.restoreSelection, lootAll = ISInventoryPane.lootAll,
        transferAll = ISInventoryPane.transferAll, byWeight = ISInventoryPane.transferItemsByWeight,
    }
    S.orig = o

    function ISInventoryPage:update(...)
        o.pageUpdate(self, ...)
        if S.isOn() and self.rskStyled then gUpdate(self) end
    end

    function ISInventoryPage:prerender(...)
        o.pagePre(self, ...)
        if S.isOn() and self.rskStyled and self.rskSearch then gDraw(self) end
    end

    function ISInventoryPage:close(...)
        if S.isOn() and self.rskSearch then gClose(self) end
        return o.pageClose(self, ...)
    end

    -- The window does not collapse while typing (D-74).
    function ISInventoryPage:collapseNow(...)
        local s = S.isOn() and self.rskSearch
        if s and s.open and s.field:isFocused() then
            self.collapseCounter = 0
            return
        end
        return o.collapseNow(self, ...)
    end

    function ISInventoryPane:restoreSelection(selected)
        if S.isOn() then gFilter(self) end
        return o.restore(self, selected)
    end

    -- D-75: with an active filter only visible items are moved. Nothing visible -> no action
    -- (also the vanilla "single heavy item" case, which would equip it).
    local function onlyVisible(pane, fn, ...)
        local s = S.isOn() and activeFilter(pane)
        if not s then return fn(pane, ...) end
        if s.shown == 0 then return end
        pane.rskOnlyVisible = true
        local ok, err = pcall(fn, pane, ...)
        pane.rskOnlyVisible = nil
        if not ok then error(err, 0) end
    end

    function ISInventoryPane:lootAll(...) return onlyVisible(self, o.lootAll, ...) end
    function ISInventoryPane:transferAll(...) return onlyVisible(self, o.transferAll, ...) end

    function ISInventoryPane:transferItemsByWeight(items, container)
        if self.rskOnlyVisible then
            items = gVisible(self, items)
            if not items then return end -- filter error: better no move than moving everything
        end
        return o.byWeight(self, items, container)
    end
end

-- ---------------------------------------------------------------- module
local function onTheme()
    for page in pairs(I.pages) do
        local s = page.rskSearch
        if s then
            paint(s)
            S.layout(page, s)
        end
    end
end

S.moduleDef = K.register{
    id = S.ID, when = "game", requires = { "Inventory" },
    start = function(m) B.on("ThemeChanged", onTheme, m.id) end,
    stop = detachAll,
}
