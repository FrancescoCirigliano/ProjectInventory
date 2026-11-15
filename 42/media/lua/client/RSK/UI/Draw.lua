-- RSK.UI.Draw - themed drawing primitives (D-52, D-53: square corners).
require "RSK/Theme/Theme"
require "RSK/UI/Logic"

local T, L = RSK.Theme, RSK.UI.Logic
RSK.UI.Draw = RSK.UI.Draw or {}
local D = RSK.UI.Draw

function D.fill(el, x, y, w, h, tok, alpha)
    local r, g, b, a = T.rgba(tok)
    el:drawRect(x, y, w, h, a * (alpha or 1), r, g, b)
end

-- Fill with an off-theme colour c = { r, g, b } (0..1), e.g. item groups (D-99).
function D.fillC(el, x, y, w, h, c, alpha)
    el:drawRect(x, y, w, h, alpha or 1, c.r, c.g, c.b)
end

function D.border(el, x, y, w, h, tok, alpha)
    local r, g, b, a = T.rgba(tok)
    el:drawRectBorder(x, y, w, h, a * (alpha or 1), r, g, b)
end

local function prep(role, text)
    local f = T.font(role)
    text = tostring(text or "")
    if f.upper then text = string.upper(text) end
    return f, text
end

local function uiFont(f) return UIFont[L.uiFontFor(f.size)] end

-- Fira fonts (D-109): AngelCodeFont, one Java call per string. Metrics valid at once (stable layouts);
-- drawing only once the pages are ready, before that the string uses the vanilla UIFont slot. No atlas: always vanilla.
local function metricsOf(f)
    if not f.ready then return nil end
    return T.fontFor(f.family, f.size, true)
end

local function measureRaw(f, t, o, s)
    if o then return o:getWidth(t) * s end
    return getTextManager():MeasureStringX(uiFont(f), t)
end

function D.measure(role, text)
    local f, t = prep(role, text)
    local o, s = metricsOf(f)
    return measureRaw(f, t, o, s)
end

function D.lineHeight(role)
    local f = T.font(role)
    local o, s = metricsOf(f)
    if o then return o:getLineHeight() * s end
    return getTextManager():getFontHeight(uiFont(f))
end

-- Draws text in local coordinates. align: left | center | right (x = reference point).
-- maxW: clips with "...". Returns the drawn width.
function D.text(el, text, x, y, role, tok, alpha, align, maxW)
    local f, t = prep(role, text)
    local o, s = metricsOf(f)
    if maxW then t = L.ellipsize(t, maxW, function(str) return measureRaw(f, str, o, s) end) end
    local w = measureRaw(f, t, o, s)
    if align == "center" then x = x - w / 2 elseif align == "right" then x = x - w end
    local r, g, b, a = T.rgba(tok or "text")
    a = a * (alpha or 1)
    if o and T.fontFor(f.family, f.size) then
        -- Absolute coordinates: in scrolling panels the scroll is added, like the Java primitives.
        -- Whole pixels and always an explicit scale (AngelCodeFont's static scale belongs to the last drawn text).
        local sx = el.getXScroll and el:getXScroll() or 0
        local sy = el.getYScroll and el:getYScroll() or 0
        local ax = math.floor(el:getAbsoluteX() + x + sx + 0.5)
        local ay = math.floor(el:getAbsoluteY() + y + sy + 0.5)
        o:drawString(ax, ay, s, t, r, g, b, a)
    else
        el:drawText(t, x, y, r, g, b, a, uiFont(f))
    end
    return w
end
-- Text vertically centred on cy.
function D.textMid(el, text, x, cy, role, tok, alpha, align, maxW)
    return D.text(el, text, x, math.floor(cy - D.lineHeight(role) / 2), role, tok, alpha, align, maxW)
end

function D.texture(el, tex, x, y, w, h, tok, alpha)
    if not tex then return end
    local r, g, b, a = T.rgba(tok or "text")
    el:drawTextureScaled(tex, x, y, w, h, a * (alpha or 1), r, g, b)
end

-- Placeholder icons: tinted vanilla textures, until the PNGs from SVG exist (P4.1).
D.ICON_PATHS = {
    close = "media/ui/Dialog_Titlebar_CloseIcon.png",
    expanded = "media/ui/TreeExpanded.png",
    collapsed = "media/ui/TreeCollapsed.png",
}
D.iconCache = D.iconCache or {}
function D.icon(name)
    local c = D.iconCache[name]
    if c == nil then
        c = D.ICON_PATHS[name] and getTexture(D.ICON_PATHS[name]) or false
        D.iconCache[name] = c
    end
    return c or nil
end

function D.disabledAlpha() return T.alpha.disabled end
