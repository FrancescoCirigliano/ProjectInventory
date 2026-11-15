-- RSK.Inventory.Pane - themed drawing of the vanilla ISInventoryPane list (D-60, D-61).
-- The vanilla prerender/render runs muted (RSK.UI.Mute): it rebuilds self.items, updates
-- age/wetness, dragging and highlights. Here only the visible rows are drawn, reading
-- vanilla data; row height and columns go through vanilla fields (itemHgt, headerHgt, column2, column3),
-- so clicks, selection and drag&drop computed by vanilla match the drawing.
require "ISUI/ISInventoryPane"
require "ISUI/ISInventoryItem"
require "ISUI/ISScrollBar"
require "RSK/UI/UI"
require "RSK/UI/Mute"
require "RSK/Inventory/Logic"
require "RSK/Inventory/TipLogic"

local T, D, IL, Mute = RSK.Theme, RSK.UI.Draw, RSK.Inventory.Logic, RSK.UI.Mute
local I = RSK.Inventory
I.Pane = I.Pane or {}
local P = I.Pane

local HEADER_KIDS = { "expandAll", "collapseAll", "filterMenu", "nameHeader", "typeHeader" }
local MAX_DRAGGED_DRAWN = 40

local function px(n) return T.px(n) end
local function isItem(e) return instanceof(e, "InventoryItem") end
local function isOn() return RSK.Core.isActive("Inventory") end
local function G(fn) return RSK.Core.guard("Inventory", fn) end
local function fillStatic(el, x, y, w, h, tok, a) D.fill(el, x, y - el:getYScroll(), w, h, tok, a) end
-- UI child of the pane, only if it exists as an element (expandAll/collapseAll are also class functions).
local function kid(el, k)
    local c = rawget(el, k)
    return type(c) == "table" and c.javaObject ~= nil and c or nil
end
local function tx(k, ...) return getText("UI_RSK_Inv_" .. k, ...) end

-- Status icons (D-26): white masks tinted by the theme.
local statusTex = {}
local function stex(name)
    local t = statusTex[name]
    if t == nil then t = getTexture("media/ui/RSK/status_" .. name .. ".png") or false; statusTex[name] = t end
    return t or nil
end

local function geom(el) return { x = el:getX(), y = el:getY(), w = el:getWidth(), h = el:getHeight() } end
local function setGeom(el, g) el:setX(g.x); el:setY(g.y); el:setWidth(g.w); el:setHeight(g.h) end

-- Inventory settings (D-125), read from RSK_config.txt.
RSK.Config.define("inventory.iconSize", "enum", "medium", { values = IL.ICON_ORDER })
RSK.Config.define("inventory.equipped", "enum", "group", { values = { "group", "hide" } })

-- Row sizes for the current icon size (1080p units), recomputed only when it changes.
local dimsCache
function P.dims()
    local id = RSK.Config.get("inventory.iconSize")
    if not dimsCache or dimsCache.id ~= id then dimsCache = IL.rowDims(T.base, id) end
    return dimsCache
end

-- Hidden equipped items: only in the themed player inventory (D-125).
function P.hidesEquipped(pane)
    local page = pane.parent
    return pane.rskStyled == true and page ~= nil and page.onCharacter == true
        and RSK.Config.get("inventory.equipped") == "hide"
end

-- ---------------------------------------------------------------- layout (vanilla fields only)
function P.layout(pane)
    local b = T.base
    local d = P.dims()
    local c = IL.columns(b, d)
    local hh = px(b.inv.header)
    pane.itemHgt = px(d.row)
    pane.headerHgt = hh
    pane.column2 = px(c.column2)
    local typeMin, nameMin = px(c.typeMin), px(100)
    local m = px(4)
    for i, k in ipairs({ "expandAll", "collapseAll" }) do
        local el = pane[k]
        el:setX(m); el:setY(0); el:setWidth(hh); el:setHeight(hh)
    end
    pane.filterMenu:setX(m + hh + m); pane.filterMenu:setY(0)
    pane.filterMenu:setWidth(hh); pane.filterMenu:setHeight(hh)
    pane.nameHeader.minimumWidth, pane.typeHeader.minimumWidth = nameMin, typeMin
    pane.column3 = math.max(pane.column2 + nameMin, pane.width - typeMin + 1)
    pane.nameHeader:setX(pane.column2); pane.nameHeader:setY(0)
    pane.nameHeader:setWidth(pane.column3 - pane.column2); pane.nameHeader:setHeight(hh)
    pane.typeHeader:setX(pane.column3 - 1); pane.typeHeader:setY(0)
    pane.typeHeader:setWidth(pane.width - pane.column3 + 1); pane.typeHeader:setHeight(hh)
    for k = 1, 3 do
        local cb = pane["contextButton" .. k]
        if cb then cb:setHeight(pane.itemHgt) end
    end
end

function P.style(pane)
    if not pane.rskStyled then
        local s = { headerHgt = pane.headerHgt, column2 = pane.column2, column3 = pane.column3,
            nameMin = pane.nameHeader.minimumWidth, typeMin = pane.typeHeader.minimumWidth, geoms = {} }
        for _, k in ipairs(HEADER_KIDS) do local c = kid(pane, k); if c then s.geoms[k] = geom(c) end end
        pane.rskSaved = s
        pane.rskStyled = true
        P.skinChildren(pane)
    end
    P.layout(pane)
    P.hideHeaderIcons(pane)
end

function P.unstyle(pane)
    if not pane.rskStyled then return end
    local s = pane.rskSaved
    pane.rskStyled = nil
    for el in pairs(pane.rskSkins or {}) do Mute.unskin(el) end
    pane.rskSkins = nil
    P.unskinScroll(pane)
    pane.headerHgt, pane.column2, pane.column3 = s.headerHgt, s.column2, s.column3
    pane.nameHeader.minimumWidth, pane.typeHeader.minimumWidth = s.nameMin, s.typeMin
    for k, g in pairs(s.geoms) do local c = kid(pane, k); if c then setGeom(c, g) end end
    pane:onInventoryFontChanged() -- itemHgt and context buttons as in vanilla
    local fm = kid(pane, "filterMenu")
    if fm then fm:setVisible(true) end
    pane.rskSaved = nil
    pane:refreshContainer() -- expand/collapse all become visible again as vanilla decides
end

-- ---------------------------------------------------------------- vanilla children skins
local function skin(pane, el, pre, post)
    if not el then return end
    pane.rskSkins = pane.rskSkins or {}
    pane.rskSkins[el] = true
    Mute.skin(el, pre and G(pre), post and G(post), isOn)
end

local function iconPre(b) if b:isMouseOver() then D.fill(b, 0, 0, b.width, b.height, "hover") end end
local function iconPost(b)
    if not b.image then return end
    local s = px(16)
    D.texture(b, b.image, (b.width - s) / 2, (b.height - s) / 2, s, s, b:isMouseOver() and "text" or "muted")
end

local function headerPre(b) if b:isMouseOver() then D.fill(b, 0, 0, b.width, b.height, "hover") end end
local function namePost(b)
    D.textMid(b, tx("Name"), px(T.base.inv.gap), b.height / 2, "label", "muted", 1, "left", b.width - px(16))
end
local function typePost(b)
    local pane = b.parent
    local sw = (pane and pane:isVScrollBarVisible()) and pane.vscroll:getWidth() or 0
    local g = px(T.base.inv.gap)
    D.fill(b, 0, px(8), 1, b.height - px(16), "line")
    D.textMid(b, tx("Category"), g + 1, b.height / 2, "label", "muted", 1, "left", px(T.base.w.colCategory))
    D.textMid(b, tx("Weight"), b.width - px(T.base.inv.padR) - sw, b.height / 2, "label", "muted", 1, "right")
end

local function ctxPre(b)
    D.fill(b, 0, 0, b.width, b.height, b:isMouseOver() and "sel" or "panel2")
    D.border(b, 0, 0, b.width, b.height, b:isMouseOver() and "accent" or "line")
end
local function ctxPost(b)
    D.textMid(b, b.title or "", b.width / 2, b.height / 2, "rowSmall", "text", 1, "center", b.width - px(8))
end

-- Scrollbar: below the header, no arrows. The thumb uses the full travel; drawing, clicks and
-- dragging share the same geometry (IL.scrollThumb), not the 16/20 px of the vanilla arrows.
local function thumb(sb)
    local p = sb.parent
    local sh = p:getScrollHeight()
    local view = p:getScrollAreaHeight() - (p.headerHgt or 0)
    return IL.scrollThumb(sb:getHeight(), view, sh - (p.headerHgt or 0), sb.pos or 0, px(24))
end

local function scrollPost(sb)
    local p = sb.parent
    if not p or p:getScrollHeight() <= p:getScrollAreaHeight() then
        sb.barwidth, sb.barheight = 0, 0
        return
    end
    local y, h = thumb(sb)
    local w = px(6)
    sb.barx, sb.bary, sb.barwidth, sb.barheight = sb.width - w - px(4), y, w + px(4), h
    D.fill(sb, sb.width - w - px(2), y, w, h, (sb.scrolling or sb:isMouseOver()) and "muted" or "line")
end

-- Thumb methods replaced on the instance while the list is themed (restored in unstyle).
local SCROLL_METHODS = { "hitTest", "onMouseMove" }
local scrollFns = {
    hitTest = function(sb, x, y)
        if not isOn() or not sb.parent.rskStyled then return ISScrollBar.hitTest(sb, x, y) end
        if not sb:isPointOver(sb:getAbsoluteX() + x, sb:getAbsoluteY() + y) then return nil end
        if not sb.barheight or sb.barheight == 0 then return nil end
        if y >= sb.bary and y <= sb.bary + sb.barheight then return "thumb" end
        return y < sb.bary and "trackUp" or "trackDown"
    end,
    onMouseMove = function(sb, dx, dy)
        if not isOn() or not sb.parent.rskStyled then return ISScrollBar.onMouseMove(sb, dx, dy) end
        if not sb.scrolling then return end
        local p = sb.parent
        local y, h = thumb(sb)
        local run = sb:getHeight() - h
        local sh, area = p:getScrollHeight(), p:getScrollAreaHeight()
        if run <= 0 or sh <= area then return end
        sb.pos = math.max(0, math.min(1, (sb.pos or 0) + dy / run))
        p:setYScroll(-(sb.pos * (sh - area)))
    end,
}

function P.skinScroll(pane)
    local sb = kid(pane, "vscroll")
    if not sb or pane.rskScrollSaved then return end
    local saved = {}
    for _, k in ipairs(SCROLL_METHODS) do saved[k] = rawget(sb, k) or false; sb[k] = scrollFns[k] end
    pane.rskScrollSaved = saved
end

function P.unskinScroll(pane)
    local sb, saved = kid(pane, "vscroll"), pane.rskScrollSaved
    if not sb or not saved then return end
    for _, k in ipairs(SCROLL_METHODS) do sb[k] = saved[k] or nil end
    pane.rskScrollSaved = nil
    sb:setY(0); sb:setHeight(pane.height)
end

-- After the vanilla prerender (which restores the full height): bar below the header.
local function placeScroll(pane)
    local sb = kid(pane, "vscroll")
    if not sb then return end
    local y, h = pane.headerHgt, pane.height - pane.headerHgt
    if sb:getY() ~= y then sb:setY(y) end
    if sb:getHeight() ~= h then sb:setHeight(h) end
end

function P.skinChildren(pane)
    skin(pane, kid(pane, "expandAll"), iconPre, iconPost)
    skin(pane, kid(pane, "collapseAll"), iconPre, iconPost)
    skin(pane, kid(pane, "filterMenu"), iconPre, iconPost)
    skin(pane, pane.nameHeader, headerPre, namePost)
    skin(pane, pane.typeHeader, headerPre, typePost)
    for k = 1, 3 do skin(pane, kid(pane, "contextButton" .. k), ctxPre, ctxPost) end
    skin(pane, kid(pane, "vscroll"), nil, scrollPost)
    P.skinScroll(pane)
end

-- ---------------------------------------------------------------- row data (same checks as vanilla)
local function heatTint(item)
    local fd = instanceof(item, "Food") or instanceof(item, "DrainableComboItem")
    local h1 = fd and item:getHeat() or 1
    local h2 = item:getItemHeat()
    if h1 == 1 and h2 == 1 then return nil end
    return (h1 > 1 or h2 > 1) and "danger" or "muted", math.abs(item:getInvHeat())
end

local get = RSK.Inventory.TipLogic and RSK.Inventory.TipLogic.get

-- Row bar (D-121): container fill only, always visible (even empty or full):
-- liquids (amount / capacity) and bags (contents weight / capacity). No condition or anything else.
function P.rowBar(item)
    local fc = get(item, "getFluidContainer")
    if fc then
        local cap = get(fc, "getCapacity")
        if type(cap) == "number" and cap > 0 then return IL.rowBar("qty", (get(fc, "getAmount") or 0) / cap, true) end
    end
    if instanceof(item, "InventoryContainer") then
        local cap = get(item, "getCapacity")
        local w = get(get(item, "getInventory"), "getCapacityWeight")
        if type(cap) == "number" and cap > 0 and type(w) == "number" then return IL.rowBar("qty", w / cap, true) end
    end
    return nil
end
-- Item colour group (D-99) as { r, g, b }, nil = no colour.
local groupRGB = {}
function P.groupColor(item)
    local g = IL.groupOf(item:getDisplayCategory() or item:getCategory(), instanceof(item, "InventoryContainer"))
    if not g then return nil end
    local c = groupRGB[g]
    if c == nil then c = T.hex(T.GROUP_HEX[g]) or false; groupRGB[g] = c end
    return c or nil
end

-- State words of vanilla names (IGUI_FoodNaming, IGUI_ClothingNaming) -> D-102 keys.
local knownWords
local function known()
    if knownWords then return knownWords end
    knownWords = {}
    local function put(key, v) local t = getText(key); if t and t ~= key then knownWords[t] = v end end
    put("Tooltip_food_Rotten", "rotten"); put("Tooltip_food_Burnt", "burnt"); put("Tooltip_food_Stale", "stale")
    put("Tooltip_food_Frozen", "frozen"); put("Tooltip_food_Cooked", "cooked")
    put("IGUI_ClothingName_Wet", "wet"); put("IGUI_ClothingName_Soaked", "wet")
    put("Tooltip_food_Fresh", false)
    return knownWords
end

-- Name without the vanilla brackets and states text "(broken, rotten, ...)" (D-102).
-- Only food and clothing put states in the name; other names stay whole (titles with brackets).
function P.nameAndState(item, player)
    local name = item:getName(player)
    local words
    local food, cloth = instanceof(item, "Food"), instanceof(item, "Clothing")
    if food or cloth then name, words = IL.splitName(name) end
    local flags = { broken = item:isBroken() }
    if food then
        flags.rotten, flags.burnt, flags.frozen = item:isRotten(), item:isBurnt(), item:isFrozen()
        flags.cooked = item:isCooked() and not item:isBurnt()
    end
    local keys, extras = IL.stateKeys(flags, words, known())
    return name, IL.stateText(keys, extras, function(k) return tx("St_" .. k) end)
end

-- Per-item row data, recomputed at most every ROW_MS (visible rows are redrawn every frame).
local ROW_MS = 400
local rowCache = setmetatable({}, { __mode = "k" })
local function rowModel(item, player)
    local now = getTimestampMs()
    local m = rowCache[item]
    if m and now - m.t < ROW_MS and m.preset == T.presetId() then return m end
    m = m or {}
    m.t, m.preset = now, T.presetId()
    m.name, m.state = P.nameAndState(item, player)
    m.frac, m.tok = P.rowBar(item)
    m.gc = P.groupColor(item)
    rowCache[item] = m
    return m
end

-- Reading state (D-26, D-27, D-138): "read" from the character's vanilla data, like the vanilla
-- tick; with the Collect module on, collectibles not read yet are "found" or "new".
function P.readState(pane, player, item)
    local read = pane:isLiteratureRead(player, item) or item:hasBeenSeen(player) or item:hasBeenHeard(player)
        or player:hasReadMap(item)
    local st = RSK.Collect and RSK.Collect.guardedStatus and RSK.Collect.guardedStatus(item, read)
    if st then return st ~= "none" and st or nil end
    return read and "read" or nil
end

local function drawStatus(g, status, x, cy, s)
    local y = cy - s / 2
    if status == "new" then
        D.texture(g, stex("disc"), x, y, s, s, "danger")
        D.texture(g, stex("bang"), x, y, s, s, "ink")
    elseif status == "found" then
        D.texture(g, stex("eye"), x, y, s, s, "text")
    else
        D.texture(g, stex("read"), x, y, s, s, "ok")
    end
end

local function nestedCount(item)
    if not instanceof(item, "InventoryContainer") then return nil end
    local inv = item:getInventory()
    if not inv then return nil end
    local n = inv:getItems():size()
    return n == 1 and tx("Item1") or tx("Items", n)
end

local function isPoison(item, player)
    local tainted = getSandboxOptions():getOptionByName("EnableTaintedWaterText"):getValue()
    if instanceof(item, "Food") and item:isTainted() and tainted then return true end
    if player:isKnownPoison(item) then return true end
    local fc = item:getFluidContainer() or (item:getWorldItem() and item:getWorldItem():getFluidContainer())
    return fc ~= nil and not fc:isEmpty() and (fc:contains(Fluid.Bleach)
        or (fc:contains(Fluid.TaintedWater) and fc:getPoisonRatio() > 0.1 and tainted))
end

-- Vanilla badges on the icon (vanilla textures in their colours until the P4.1 icons exist).
local function badges(pane, g, item, ix, iy, ib, player)
    local s = px(P.dims().badge)
    local function at(tex, x, y) if tex then g:drawTextureScaledAspect(tex, x, y, s, s, 1, 1, 1, 1) end end
    local r, btm = ix + ib - s, iy + ib - s
    if player:isEquipped(item) then
        at(pane.equippedItemIcon, r, btm)
    else
        pane.hotbar = pane.hotbar or getPlayerHotbar(pane.player)
        if pane.hotbar and pane.hotbar:isInHotbar(item) then at(pane.equippedInHotbar, r, btm) end
    end
    -- broken and frozen: now among the states after the name (D-102)
    if isPoison(item, player) then at(pane.poisonIcon, ix + s, btm) end
    if item:isFavorite() then at(pane.favoriteStar, ix, iy)
    elseif item:isNoRecipes(player) then at(pane.noFavoriteRecipeInputStar, ix, iy)
    elseif item:isFavouriteRecipeInput(player) then at(pane.favoriteRecipeInputStar, ix, iy) end
end

local function categoryText(item)
    return getText("IGUI_ItemCat_" .. (item:getDisplayCategory() or item:getCategory()))
end
P.categoryText = categoryText

-- ---------------------------------------------------------------- row
local teeTex
local function tee()
    if teeTex == nil then teeTex = getTexture("media/ui/RSK/ui_tee.png") or false end
    return teeTex or nil
end

local GA = T.groupAlpha

-- 3 px bar at the bottom of a box (D-101): track text 8%, fill in the bar colour.
local function bottomBar(g, x, y, w, h, frac, tok)
    local bh = px(T.base.inv.rowBar)
    local by = y + h - bh
    D.fill(g, x, by, w, bh, "text", GA.track)
    if frac > 0 then D.fill(g, x, by, math.max(1, math.floor(w * frac + 0.5)), bh, tok) end
end

-- ctx: player, W (usable width), dragged, checkDrop, divider
function P.drawRow(pane, i, xoff, yoff, ctx)
    local entry = pane.items[i]
    if entry == nil then return end
    local info = IL.rowInfo(entry, isItem)
    local item = info.item
    if not item then return end
    local b, inv = T.base, T.base.inv
    local d = P.dims()
    local player, W = ctx.player, ctx.W
    local g = ctx.g or pane   -- element drawn on (the pane, or the drag layer)
    local rh = pane.itemHgt
    local top = pane.headerHgt + (i - 1) * rh + yoff
    local x0 = xoff
    local sel = pane.selected[i] ~= nil
    local hover = not ctx.dragged and pane.mouseOverOption == i
    local isEquipGroup = info.group ~= nil and info.group.rskGroup == "equipped"
    local collapsedGroup = info.group ~= nil and pane.collapsed[info.group.name] == true
    local isParent = isEquipGroup or info.stack
    local m = rowModel(item, player)
    local gc = (not isEquipGroup) and m.gc or nil

    -- Row box: full width for stacks and items; indented card for children (D-103).
    local bx, by, bw, bhh = x0, top, W, rh
    local first, last = true, true
    if info.sub then
        local prv, nxt = pane.items[i - 1], pane.items[i + 1]
        first = not (prv ~= nil and isItem(prv))
        last = not (nxt ~= nil and isItem(nxt))
        local ins = px(inv.cardInset)
        bx = x0 + px(d.cardL)
        bw = W - px(d.cardL) - px(inv.cardR)
        by = top + (first and ins or 0)
        bhh = rh - (first and ins or 0) - (last and ins or 0)
    end

    -- background: group tint (D-100), children cards on panel2 if there is no group
    if info.sub then
        if gc then D.fillC(g, bx, by, bw, bhh, gc, sel and GA.sel or GA.child)
        else D.fill(g, bx, by, bw, bhh, "panel2") end
        if sel and not gc then D.fill(g, bx, by, bw, bhh, "sel") end
    elseif gc then
        D.fillC(g, bx, by, bw, bhh, gc, sel and GA.sel or GA.row)
    elseif sel then
        D.fill(g, bx, by, bw, bhh, "sel")
    end
    local tint, ta = heatTint(item)
    if tint then D.fill(g, bx, by, bw, bhh, tint, 0.15 + 0.25 * math.min(1, ta)) end
    if sel then
        if ctx.checkDrop then
            local bad
            if collapsedGroup then bad = pane.draggedItems:cannotDropAnyItem()
            else bad = pane.draggedItems:cannotDropItem(item) end
            if bad then D.fill(g, bx, by, bw, bhh, "danger", 0.3) end
        end
    end
    if pane.itemsToHighlight and pane.itemsToHighlight[item] then D.fill(g, bx, by, bw, bhh, "accent", 0.2) end
    if pane.highlightItem and pane.highlightItem == item:getType() then
        D.fill(g, bx, by, bw, bhh, "accent", pane.blinkAlpha or 0.5)
    end
    local job = item:getJobDelta()
    local showJob = job > 0 and (info.sub or collapsedGroup)
    if showJob then D.fill(g, bx, by, math.floor(bw * math.min(1, job)), bhh, "accent", 0.3) end
    if info.sub and not last then D.fill(g, bx, by + bhh - 1, bw, 1, "text", GA.childSep) end
    if ctx.divider then D.fill(g, x0, top, W, 1, "line") end

    -- tree line (D-66): from the centre of the parent icon to each card; the last one closes with "└"
    local ib = px(d.item)
    if not ctx.dragged then
        local lx = x0 + pane.column2 - math.floor(ib / 2)
        if info.sub then
            local cy = top + math.floor(rh / 2)
            D.fill(g, lx, top, 1, (last and (cy - top) or rh), "line")
            if bx > lx then D.fill(g, lx, cy, bx - lx, 1, "line") end
        elseif isParent and not collapsedGroup then
            local ly = top + math.floor((rh + ib) / 2)
            D.fill(g, lx, ly, 1, top + rh - ly, "line")
        end
    end

    -- icon
    local box, inner, ix
    if info.sub then
        box, inner = px(d.cardIcon), px(d.cardInner)
        ix = bx + px(inv.cardPadL)
    else
        box, inner = ib, px(d.iconInner)
        ix = x0 + pane.column2 - ib
        D.fill(g, ix, top + (rh - box) / 2, box, box, "bg", isEquipGroup and 1 or GA.well)
    end
    local iy = top + (rh - box) / 2
    if isEquipGroup then
        D.texture(g, tee(), ix + (box - inner) / 2, iy + (box - inner) / 2, inner, inner, "text")
    else
        ISInventoryItem.renderItemIcon(g, item, ix + (box - inner) / 2, iy + (box - inner) / 2, 1.0, inner, inner)
        if not info.sub then badges(pane, g, item, ix, iy, box, player) end
    end

    -- name, quantity, container badge, states, reading state
    local g6 = px(6)
    local cy = top + rh / 2
    local nameX = ix + box + px(inv.gap)
    local catX = x0 + pane.column3 + px(inv.gap)
    local wR = (info.sub and (bx + bw - px(inv.cardPadR)) or (x0 + W - px(inv.padR)))
    local unwanted = (not isEquipGroup) and item:isUnwanted(player)
    local nameTok = unwanted and "muted" or "text"
    local name, qty, badge, state, status
    if isEquipGroup then
        name = tx("Equipped")
        qty = info.count == 1 and tx("Item1") or tx("Items", info.count)
    else
        name, state = m.name, m.state
        qty = (not info.sub) and IL.qtyText(info.count) or nil
        badge = nestedCount(item)
        status = P.readState(pane, player, item)
    end
    local nameRole = info.sub and "rowCard" or "row"
    local w = {
        qty = qty and D.measure("qty", qty) or 0,
        badge = badge and (D.measure("badge", badge) + px(12)) or 0,
        state = state and D.measure("rowSmall", state) or 0,
        status = status and px(inv.status) or 0,
    }
    local avail = (ctx.dragged and (wR - nameX) or (catX - px(inv.gap) - nameX))
    local room = IL.nameRoom(avail, w, g6)
    local x = nameX + D.textMid(g, name, nameX, cy, nameRole, nameTok, unwanted and 0.65 or 1, "left", room)
    if qty then
        x = x + g6
        D.textMid(g, qty, x, cy, "qty", "muted")
        x = x + w.qty
    end
    if badge then
        x = x + g6
        local bh = px(inv.badgeH)
        D.border(g, x, cy - bh / 2, w.badge, bh, "line")
        D.textMid(g, badge, x + g6, cy, "badge", "accent")
        x = x + w.badge
    end
    if state then
        x = x + g6
        D.textMid(g, state, x, cy, "rowSmall", "muted")
        x = x + w.state
    end
    if status then
        x = x + g6
        drawStatus(g, status, x, cy, px(inv.status))
    end

    -- bar at the bottom of the row or card (D-101); parents have none
    if not isParent and m.frac then bottomBar(g, bx, by, bw, bhh, m.frac, m.tok) end
    -- selection: accent border; under the mouse: yellow border (warn), no fill (D-119)
    -- inset by 1 px: on the left edge of the list the first pixel is not visible
    if sel then D.border(g, bx + 1, by, bw - 1, bhh, "accent")
    elseif hover then D.border(g, bx + 1, by, bw - 1, bhh, "warn") end
    if ctx.dragged then return end

    -- category (or job in progress) and weight
    local catW = wR - px(b.w.colWeight) - px(inv.gap) - catX
    if showJob then
        D.textMid(g, tostring(item:getJobType() or ""), catX, cy, "rowSmall", "muted", 1, "left", catW)
    elseif not isEquipGroup then
        D.textMid(g, categoryText(item), catX, cy, "rowSmall", "muted", 1, "left", catW)
    end
    local wt = info.sub and item:getUnequippedWeight() or (info.group.weight or 0)
    D.textMid(g, IL.weightText(wt), wR, cy, "rowSmall", "text", 1, "right")
end

-- ---------------------------------------------------------------- "Equipped" group (D-103)
P.EQUIP_KEY = "rsk:equipped"
function P.groupEquipped(pane)
    if not pane.itemslist or not pane.collapsed then return end
    if P.hidesEquipped(pane) then IL.dropEquipped(pane.itemslist); return end -- D-125
    local grp = IL.mergeEquipped(pane.itemslist, P.EQUIP_KEY)
    -- collapsed the first time (D-111); nil would mean expanded for vanilla
    if grp and pane.collapsed[P.EQUIP_KEY] == nil then pane.collapsed[P.EQUIP_KEY] = true end
end

local function groupRow(pane)
    local e = pane.items and pane.mouseOverOption and pane.items[pane.mouseOverOption]
    return e ~= nil and not isItem(e) and e.rskGroup == "equipped"
end

-- Double click on the group row: no vanilla action (the two clicks already expanded and collapsed it).
function P.isGroupClick(pane, x) return groupRow(pane) end

-- Click on the group row (icon or name, without Shift/Ctrl): expands/collapses like a stack (D-111).
function P.toggleGroup(pane)
    if not groupRow(pane) or isShiftKeyDown() or isCtrlKeyDown() then return false end
    pane.collapsed[P.EQUIP_KEY] = not pane.collapsed[P.EQUIP_KEY]
    pane:refreshContainer()
    pane.selected = {}
    return true
end

-- Vanilla header icons (expand/collapse all, sort/filter menu) hidden (D-112).
-- Vanilla shows them again on every refreshContainer: hidden again afterwards (hook on restoreSelection).
local HEADER_ICONS = { "expandAll", "collapseAll", "filterMenu" }
function P.hideHeaderIcons(pane)
    for _, k in ipairs(HEADER_ICONS) do
        local c = kid(pane, k)
        if c and c:getIsVisible() then c:setVisible(false) end
    end
end

local function ctxFor(pane)
    local sw = pane:isVScrollBarVisible() and pane.vscroll:getWidth() or 0
    return { player = getSpecificPlayer(pane.player), W = pane.width - sw }
end

-- "Equipped" state of the stack before row first (for the separator line).
local function prevEquipped(pane, first)
    for j = first - 1, 1, -1 do
        local e = pane.items[j]
        if e ~= nil and not isItem(e) then return e.equipped and true or false end
    end
    return nil
end

-- After the muted vanilla prerender: visible rows and fixed header.
function P.draw(pane)
    placeScroll(pane)
    local ctx = ctxFor(pane)
    local n = #pane.items
    local first, last = IL.visibleRows(pane:getYScroll(), pane.height, pane.headerHgt, pane.itemHgt, n)
    local dragging = pane.dragging ~= nil and pane.dragStarted
    local prev = prevEquipped(pane, first)
    for i = first, last do
        local e = pane.items[i]
        if isItem(e) then
            ctx.divider = false
        else
            local eq = e.equipped and true or false
            ctx.divider = IL.equipDivider(eq, prev)
            prev = eq
        end
        if not (dragging and pane.selected[i]) then P.drawRow(pane, i, 0, 0, ctx) end
    end
    fillStatic(pane, 0, 0, pane.width, pane.headerHgt, "panel")
    fillStatic(pane, 0, pane.headerHgt - 1, pane.width, 1, "line")
    if pane.draggingMarquis then
        D.border(pane, pane.draggingMarquisX, pane.draggingMarquisY,
            pane:getMouseX() - pane.draggingMarquisX, pane:getMouseY() - pane.draggingMarquisY, "accent")
    end
end

-- After the muted vanilla render: dragged items and column resize line.
-- Dragged items: drawn by the always-on-top layer (P.DragLayer), so they follow the mouse
-- outside the window and above other rows (vanilla suspends the stencil; here a separate layer is enough).
function P.drawDragged(pane, g)
    local ctx = ctxFor(pane)
    ctx.dragged, ctx.checkDrop, ctx.g = true, true, g
    local xoff = pane:getAbsoluteX() - g:getAbsoluteX() + pane:getMouseX() - pane.draggingX
    local yoff = pane:getAbsoluteY() + pane:getYScroll() - g:getAbsoluteY() + pane:getMouseY() - pane.draggingY
    local n = 0
    for i in pairs(pane.selected) do
        if type(i) == "number" then
            P.drawRow(pane, i, xoff, yoff, ctx)
            n = n + 1
            if n >= MAX_DRAGGED_DRAWN then break end
        end
    end
end

local Layer = ISUIElement:derive("RSK_DragLayer")
function Layer:render()
    if not isOn() then return end
    for page in pairs(I.pages or {}) do
        local pane = page.rskStyled and page.inventoryPane
        if pane and pane.dragging ~= nil and pane.dragStarted and pane.selected and pane:isReallyVisible() then
            P.drawDragged(pane, self)
        end
    end
end

-- 1x1 off-screen element, always on top: does not catch the mouse, draws in absolute coordinates.
function P.showDragLayer()
    if P.dragLayer then return end
    local l = Layer:new(-4, -4, 1, 1)
    l:initialise(); l:instantiate(); l:addToUIManager(); l:setAlwaysOnTop(true)
    l.render = G(Layer.render)
    P.dragLayer = l
end

function P.hideDragLayer()
    if not P.dragLayer then return end
    P.dragLayer:removeFromUIManager()
    P.dragLayer = nil
end

function P.drawOverlay(pane)
    local nh, th = pane.nameHeader, pane.typeHeader
    if nh.resizing or nh.mouseOverResize or th.resizing or th.mouseOverResize then
        fillStatic(pane, nh:getRight() - 1, nh:getY(), 2, pane.height, "accent", 0.7)
    end
end
