-- RSK.Inventory.Tip - themed item tooltip (RF-1.6, D-17, P2.1b) drawn in Lua instead of DoTooltip (Java).
-- Applies to tooltips of the themed inventory and loot windows (owner = RSK pane); other tooltips
-- (hotbar, context menus, crafting) stay vanilla. Module off or failed -> vanilla render (D-44).
require "ISUI/ISToolTipInv"
require "ISUI/ISInventoryItem"
require "RSK/UI/UI"
require "RSK/Inventory/TipLogic"

local T, D, L, TL = RSK.Theme, RSK.UI.Draw, RSK.UI.Logic, RSK.Inventory.TipLogic
RSK.Inventory.Tip = RSK.Inventory.Tip or {}
local Tip = RSK.Inventory.Tip
local CACHE_MS = 250

local function px(n) return T.px(n) end
local function tx(k, ...) return getText("UI_RSK_Tip_" .. k, ...) end

function Tip.applies(tt)
    local o = tt.owner
    return tt.item ~= nil and o ~= nil and o.rskStyled == true and RSK.Core.isActive("Inventory")
end

local function catText(cat)
    if not cat or cat == "" then return nil end
    local t = getText("IGUI_ItemCat_" .. cat)
    return t
end

-- Skill name of the weapon type; every step is checked before calling (Kahlua logs exceptions).
local function weaponCatText(c)
    if not c or not Perks or not PerkFactory then return nil end
    local perk = Perks.FromString(c)
    if not perk then return nil end
    local p = PerkFactory.getPerk(perk)
    local name = p and p:getName() or nil
    if type(name) ~= "string" or name == "" then return nil end
    return name
end

local function join(parts, sep)
    local t = {}
    for i = 1, #parts do if parts[i] and parts[i] ~= "" then t[#t + 1] = parts[i] end end
    return table.concat(t, sep)
end

-- Model with translated texts and sizes, recomputed at most every CACHE_MS or when item, stack or theme change.
local function model(tt)
    local item = tt.item
    local ws = tt.tooltip and tt.tooltip:getWeightOfStack() or 0
    local now = getTimestampMs()
    local c = tt.rskTip
    if c and c.item == item and c.ws == ws and now - c.t < CACHE_MS
        and c.scale == T.scale() and c.preset == T.presetId() then return c end

    local chr = getSpecificPlayer(tt.owner.player or 0)
    local hide = ItemTag and ItemTag.HIDE_REMAINING or nil
    local m = TL.build(item, chr, ws, { hideTag = hide })
    local b = T.base.tip
    local W = px(T.base.w.tooltip)
    local pad = px(b.pad)

    m.sub = join({ catText(m.cat), weaponCatText(m.weaponCat), m.weight .. " kg" }, " \194\183 ")
    for _, f in ipairs(m.fields) do
        f.text = tx(f.label)
        if f.keys then
            local t = {}
            for i, k in ipairs(f.keys) do t[i] = tx(k) end
            f.val = table.concat(t, " \194\183 ")
        end
    end
    local mm = {
        pad = pad, gap = px(b.gap), icon = px(T.base.icon.tooltip), sep = 1,
        rowH = math.max(D.lineHeight("tipText"), px(b.barH)), rowGap = px(b.rowGap),
    }
    -- Bar columns measured on the texts: values never clipped (D-72)
    local lws, vws = {}, {}
    for _, f in ipairs(m.fields) do
        if f.kind == "bar" then
            lws[#lws + 1] = D.measure("tipText", f.text)
            vws[#vws + 1] = D.measure("tipText", f.val)
        end
    end
    m.lw, m.bw, m.vw = TL.barColumns(W - pad * 2, mm.gap, lws, vws, px(b.barLabel), px(b.barValMin), px(b.barMin))
    m.W, m.m = W, mm
    m.H = TL.height(mm, #m.fields)
    m.item, m.ws, m.t, m.scale, m.preset = item, ws, now, T.scale(), T.presetId()
    tt.rskTip = m
    return m
end

local function position(tt, m)
    local core = getCore()
    local sw, sh = core:getScreenWidth(), core:getScreenHeight()
    local x, y
    if not tt.followMouse and tt.anchorBottomLeft then
        x = L.clamp(tt.anchorBottomLeft.x, 0, math.max(0, sw - m.W))
        y = L.clamp(tt.anchorBottomLeft.y - m.H, 0, math.max(0, sh - m.H))
    else
        x, y = TL.place(getMouseX(), getMouseY(), m.W, m.H, sw, sh, px(T.base.tip.mouse))
    end
    tt:setX(x); tt:setY(y); tt:setWidth(m.W); tt:setHeight(m.H)
end

-- Drawing (true = done). As in vanilla, no tooltip while a context menu is open.
function Tip.render(tt)
    if ISContextMenu.instance and ISContextMenu.instance.visibleCheck then return true end
    local m = model(tt)
    position(tt, m)
    local b, mm, W, H = T.base.tip, m.m, m.W, m.H
    local pad, gap, icon = mm.pad, mm.gap, mm.icon

    D.fill(tt, 0, 0, W, H, "bg")

    -- Title band (D-104): group colour mixed at 35% over the background, opaque; no group = bg.
    -- Takes the separator's place: same total height (TL.height).
    local GA = T.groupAlpha
    local bandH = (#m.fields == 0) and H or (pad + icon + gap + mm.sep)
    local Pn = RSK.Inventory.Pane
    local gc = Pn and Pn.groupColor and Pn.groupColor(m.item)
    if gc then D.fillC(tt, 0, 0, W, bandH, RSK.Inventory.Logic.mix(T.color("bg"), gc, GA.tipBand)) end
    D.border(tt, 0, 0, W, H, "line")

    -- Header: image + name + "category · subtype · weight"
    D.fill(tt, pad, pad, icon, icon, "bg", GA.tipWell)
    local inner = px(b.iconInner)
    ISInventoryItem.renderItemIcon(tt, m.item, pad + (icon - inner) / 2, pad + (icon - inner) / 2, 1.0, inner, inner)
    local tx0 = pad + icon + px(b.headGap)
    local tw = W - tx0 - pad
    local nh, sh2 = D.lineHeight("itemName"), D.lineHeight("tipSub")
    local ty = pad + math.floor((icon - (nh + px(b.nameGap) + sh2)) / 2)
    D.text(tt, m.name, tx0, ty, "itemName", "text", 1, "left", tw)
    D.text(tt, m.sub, tx0, ty + nh + px(b.nameGap), "tipSub", "text", GA.tipSub, "left", tw)

    if #m.fields == 0 then return true end
    local y = bandH + gap

    -- Per-type fields: bars [label][bar][value] and key-value rows
    local lw, bw, bh, inner = m.lw, m.bw, px(b.barH), W - pad * 2
    for i, f in ipairs(m.fields) do
        local cy = y + mm.rowH / 2
        if f.kind == "bar" then
            D.textMid(tt, f.text, pad, cy, "tipText", "muted", 1, "left", lw)
            local bx = pad + lw + gap
            local by = math.floor(cy - bh / 2)
            D.fill(tt, bx, by, bw, bh, "panel2")
            if f.frac > 0 then D.fill(tt, bx, by, math.max(1, math.floor(bw * f.frac + 0.5)), bh, f.tok) end
            D.textMid(tt, f.val, W - pad, cy, "tipText", "text", 1, "right")
        else
            -- The value takes priority: clipped only if wider than 3/4 of the row, then the label
            local val = f.val or ""
            local vwid = math.min(D.measure("tipText", val), math.floor(inner * 0.75))
            D.textMid(tt, f.text, pad, cy, "tipText", "muted", 1, "left", math.max(0, inner - vwid - gap))
            D.textMid(tt, val, W - pad, cy, "tipText", f.tok or "text", 1, "right", vwid + 1)
        end
        y = y + mm.rowH + (i < #m.fields and mm.rowGap or 0)
    end
    return true
end

-- ---------------------------------------------------------------- hooking (once only)
if not Tip.hooked then
    Tip.hooked = true
    local orig = ISToolTipInv.render
    Tip.orig = orig
    local gRender = RSK.Core.guard("Inventory", Tip.render)
    function ISToolTipInv:render()
        if Tip.applies(self) and gRender(self) then return end
        return orig(self)
    end
end
