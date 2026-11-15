-- RSK.UI.Logic - widget calculations with no engine dependencies (testable, D-46).
RSK = RSK or {}
RSK.UI = RSK.UI or {}
RSK.UI.Logic = RSK.UI.Logic or {}
local L = RSK.UI.Logic

function L.clamp(v, a, b)
    if v < a then return a elseif v > b then return b end
    return v
end

-- Clips the text with "..." to fit maxW. measure(s) -> width.
function L.ellipsize(text, maxW, measure, dots)
    dots = dots or "..."
    if measure(text) <= maxW then return text end
    local dw = measure(dots)
    if dw > maxW then return "" end
    local lo, hi = 0, #text
    while lo < hi do
        local mid = math.floor((lo + hi + 1) / 2)
        if measure(text:sub(1, mid)) + dw <= maxW then lo = mid else hi = mid - 1 end
    end
    return text:sub(1, lo) .. dots
end

-- Virtualised list: scrolling in px, fixed-height rows.
function L.clampScroll(scroll, contentH, viewH)
    return L.clamp(scroll, 0, math.max(0, contentH - viewH))
end

-- First and last visible rows (1-based). Empty list -> 1, 0.
function L.visibleRange(scroll, viewH, rowH, n)
    if n <= 0 or rowH <= 0 then return 1, 0 end
    local first = math.floor(scroll / rowH) + 1
    local last = math.min(n, math.floor((scroll + viewH - 1) / rowH) + 1)
    return math.max(1, first), last
end

function L.rowAt(y, scroll, rowH, n)
    if y < 0 then return nil end
    local i = math.floor((y + scroll) / rowH) + 1
    if i < 1 or i > n then return nil end
    return i
end

-- Minimum scroll to make row i visible.
function L.scrollToRow(i, scroll, viewH, rowH)
    local top = (i - 1) * rowH
    if top < scroll then return top end
    if top + rowH > scroll + viewH then return top + rowH - viewH end
    return scroll
end

-- Scrollbar: thumb position and height, nil if not needed.
function L.scrollThumb(scroll, contentH, viewH, minThumb)
    if contentH <= viewH or viewH <= 0 then return nil end
    local h = math.max(minThumb or 16, viewH * viewH / contentH)
    local y = (viewH - h) * scroll / (contentH - viewH)
    return y, h
end

-- Inverse: thumb position -> scroll.
function L.scrollFromThumb(thumbY, contentH, viewH, thumbH)
    local range = viewH - thumbH
    if range <= 0 then return 0 end
    return L.clamp(thumbY / range, 0, 1) * (contentH - viewH)
end

-- Slider: position in px (0..w) <-> value, with step.
function L.sliderValue(pos, w, min, max, step)
    local t = w > 0 and L.clamp(pos / w, 0, 1) or 0
    local v = min + t * (max - min)
    if step and step > 0 then v = min + math.floor((v - min) / step + 0.5) * step end
    v = tonumber(string.format("%.6f", v))
    return L.clamp(v, min, max)
end

function L.sliderPos(v, w, min, max)
    if max <= min then return 0 end
    return L.clamp((v - min) / (max - min), 0, 1) * w
end

-- Bar colour (Stile_UI, D-32): cond = condition/health, load = load.
-- Tabs wider than the view: scrolling that keeps the active one and part of the next visible.
-- rects = { { x, w } }, index = active (1-based), peek = how much to show beyond. Returns the scroll in px.
function L.tabScroll(rects, index, viewW, scroll, peek)
    local n = #rects
    if n == 0 then return 0 end
    local last = rects[n]
    local maxScroll = math.max(0, last.x + last.w - viewW)
    local r = rects[index]
    if not r then return L.clamp(scroll, 0, maxScroll) end
    local left = r.x - (index > 1 and peek or 0)
    local right = r.x + r.w + (index < n and peek or 0)
    if right - scroll > viewW then scroll = right - viewW end
    if left < scroll then scroll = left end
    return L.clamp(scroll, 0, maxScroll)
end

function L.barToken(mode, v)
    local th = RSK.Theme.base.threshold
    if mode == "load" then return v > th.loadDanger and "danger" or "accent" end
    if mode == "cond" then
        if v >= th.condOk then return "ok" elseif v >= th.condMid then return "accent" end
        return "danger"
    end
    return "accent"
end

-- Fallback UIFont slot for a size in px (D-52).
function L.uiFontFor(size)
    if size <= 14 then return "Small" elseif size <= 19 then return "Medium" end
    return "Large"
end

-- Double click: same target within ms milliseconds.
function L.isDoubleClick(last, target, now, ms)
    return last ~= nil and last.target == target and (now - last.time) <= (ms or 400)
end
