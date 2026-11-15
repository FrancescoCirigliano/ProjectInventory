-- RSK.Inventory - M1, P2.1: in-place reskin of the vanilla inventory and loot windows (D-60...D-62).
-- Vanilla logic unchanged (D-61): vanilla methods stay the same objects and run in full;
-- prerender/render run muted (RSK.UI.Mute) and the mod redraws, themed, only what is visible.
-- The wrappers stay installed but become transparent when the module is off or failed (D-44):
-- on stop every window goes back to vanilla sizes and drawing.
require "ISUI/ISInventoryPage"
require "ISUI/ISInventoryPane"
require "ISUI/InventoryWindow/ISInventoryWindowContainerControls"
require "ISUI/LootWindow/ISLootWindowContainerControls"
require "RSK/Core/Bootstrap"
require "RSK/UI/UI"
require "RSK/Inventory/Page"
require "RSK/Inventory/Tip"

local K, B = RSK.Core, RSK.Bus
local Mute = RSK.UI.Mute
local I = RSK.Inventory
I.ID = "Inventory"
I.pages = I.pages or setmetatable({}, { __mode = "k" })

function I.isOn() return K.isActive(I.ID) end
local function G(fn) return K.guard(I.ID, fn) end
local function styled(el) return el.rskStyled == true and I.isOn() end

local gStyle = G(function(page) I.Page.style(page); return true end)
local gPagePre, gPagePost = G(I.Page.drawPre), G(I.Page.drawPost)
local gPanePre, gPanePost = G(I.Pane.draw), G(I.Pane.drawOverlay)
local gLayout = G(I.Page.layout)
local gPaneLayout = G(I.Pane.layout)
local gSkinButton = G(I.Page.skinContainerButton)
local gSkinControls = G(I.Page.skinControls)
local gEnsure = G(I.Page.ensureContainers)
local gGroup = G(I.Pane.groupEquipped)
local gIsGroupClick = G(I.Pane.isGroupClick)
local gToggleGroup = G(I.Pane.toggleGroup)
local gHideIcons = G(I.Pane.hideHeaderIcons)

function I.relayoutAll()
    for page in pairs(I.pages) do
        if page.rskStyled then I.Page.layout(page) end
    end
end

function I.unstyleAll()
    for page in pairs(I.pages) do
        local ok, err = pcall(I.Page.unstyle, page)
        if not ok then K.log("Inventory: ripristino vanilla non riuscito: " .. tostring(err)) end
    end
end

-- ---------------------------------------------------------------- hooking (once only)
if not I.hooked then
    I.hooked = true
    local o = {
        pagePre = ISInventoryPage.prerender, pageRender = ISInventoryPage.render,
        titleBarHeight = ISInventoryPage.titleBarHeight,
        sizeChanged = ISInventoryPage.onInventoryContainerSizeChanged,
        addButton = ISInventoryPage.addContainerButton,
        refreshBackpacks = ISInventoryPage.refreshBackpacks,
        panePre = ISInventoryPane.prerender, paneRender = ISInventoryPane.render,
        fontChanged = ISInventoryPane.onInventoryFontChanged,
        restore = ISInventoryPane.restoreSelection, dblClick = ISInventoryPane.onMouseDoubleClick,
        mouseDown = ISInventoryPane.onMouseDown,
        invArrange = ISInventoryWindowContainerControls.arrange,
        lootArrange = ISLootWindowContainerControls.arrange,
    }
    I.orig = o

    function ISInventoryPage:prerender()
        if not self.rskStyled and I.isOn() then gStyle(self) end
        if not styled(self) then return o.pagePre(self) end
        Mute.call(self, o.pagePre)
        gPagePre(self)
    end

    function ISInventoryPage:render()
        if not styled(self) then return o.pageRender(self) end
        Mute.call(self, o.pageRender)
        gPagePost(self)
    end

    -- Title + load bar: the collapsed window (setMaxDrawHeight) also shows the load (D-22).
    function ISInventoryPage:titleBarHeight(...)
        if styled(self) then return I.Page.headH() end
        return o.titleBarHeight(self, ...)
    end

    function ISInventoryPage:onInventoryContainerSizeChanged(...)
        o.sizeChanged(self, ...)
        if styled(self) then gLayout(self) end
    end

    -- After every rebuild of the column: buttons at RSK size (D-63).
    function ISInventoryPage:refreshBackpacks(...)
        local r = o.refreshBackpacks(self, ...)
        if styled(self) then gEnsure(self) end
        return r
    end

    function ISInventoryPage:addContainerButton(...)
        local b = o.addButton(self, ...)
        if b and styled(self) then gSkinButton(self, b) end
        return b
    end

    function ISInventoryPane:prerender()
        if not styled(self) then return o.panePre(self) end
        Mute.call(self, o.panePre)
        gPanePre(self)
    end

    function ISInventoryPane:render()
        if not styled(self) then return o.paneRender(self) end
        Mute.call(self, o.paneRender)
        gPanePost(self)
    end

    function ISInventoryPane:onInventoryFontChanged(...)
        o.fontChanged(self, ...)
        if styled(self) then gPaneLayout(self) end
    end

    -- "Equipped" group (D-103): merges the equipped stacks of itemslist before vanilla
    -- rebuilds the selection; rows, clicks and dragging stay vanilla (D-61).
    -- Search (M6) wraps this method: it filters first, then groups.
    function ISInventoryPane:restoreSelection(selected)
        if styled(self) then
            gHideIcons(self)
            if self.parent and self.parent.onCharacter then gGroup(self) end
        end
        return o.restore(self, selected)
    end

    -- Click on the "Equipped" group row: expands/collapses (D-111); the rest as in vanilla.
    function ISInventoryPane:onMouseDown(x, y)
        if styled(self) and gToggleGroup(self) then return true end
        return o.mouseDown(self, x, y)
    end

    -- Double click on the group name: no action (vanilla would act on the first equipped item).
    function ISInventoryPane:onMouseDoubleClick(x, y)
        if styled(self) and gIsGroupClick(self, x) then
            self.previousMouseUp = nil
            return
        end
        return o.dblClick(self, x, y)
    end

    function ISInventoryWindowContainerControls:arrange(...)
        o.invArrange(self, ...)
        local page = self.inventoryWindow
        if page and styled(page) then gSkinControls(page, self) end
    end

    function ISLootWindowContainerControls:arrange(...)
        o.lootArrange(self, ...)
        local page = self.lootWindow
        if page and styled(page) then gSkinControls(page, self) end
    end
end

-- Live settings (D-125): icon size = new row sizes; equipped = list rebuilt.
function I.onConfig(key)
    if key ~= "inventory.iconSize" and key ~= "inventory.equipped" then return end
    for page in pairs(I.pages) do
        if page.rskStyled then
            if key == "inventory.iconSize" then I.Page.layout(page) end
            page.inventoryPane:refreshContainer()
        end
    end
end

-- ---------------------------------------------------------------- module
-- Windows adapt on the first frame after start (prerender); on stop they go back to vanilla.
I.moduleDef = K.register{
    id = I.ID, when = "game", requires = { "UI" },
    start = function(m)
        B.on("ThemeChanged", I.relayoutAll, m.id)
        B.on("ConfigChanged", I.onConfig, m.id)
        I.Pane.showDragLayer()
    end,
    stop = function()
        I.Pane.hideDragLayer()
        I.unstyleAll()
    end,
}
