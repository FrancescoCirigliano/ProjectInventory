-- RSK.Pause.Logic - pause menu entries, texts and bottom bar layout (P3.4, D-148) with no engine
-- dependencies (testable, T-35). Sizes in 1080p units.
RSK = RSK or {}
RSK.Pause = RSK.Pause or {}
RSK.Pause.Logic = RSK.Pause.Logic or {}
local L = RSK.Pause.Logic

L.GEO = {
    titleX = 72, titleY = 56, subGap = 6, cardY = 170, cardW = 340, cardPad = 14, cardGap = 12, portrait = 72,
    statH = 52, statGap = 8, barH = 100, barPad = 40, barGap = 24, verW = 140, btnH = 52, btnPad = 22,
    btnPadMin = 8, btnGap = 8, quitW = 200, quitIcon = 18, fadeMs = 150,
}

L.RETURN, L.QUIT, L.EXIT = "RETURN", "QUIT_TO_DESKTOP", "EXIT"

-- Bar entries from the vanilla menu items: { internal, text, y, visible } (other mods included).
-- Visible ones in vanilla order (top to bottom, then insertion order); "Quit to desktop" apart on the right.
-- Returns center, quit; each entry gets primary (Return), the source index and the source item.
function L.entries(items)
    local list = {}
    for i, it in ipairs(items) do
        if it.visible and it.text and it.text ~= "" then
            list[#list + 1] = { internal = it.internal, text = it.text, y = it.y or 0, idx = i, item = it }
        end
    end
    table.sort(list, function(a, b)
        if a.y ~= b.y then return a.y < b.y end
        return a.idx < b.idx
    end)
    local center, quit = {}, nil
    for _, e in ipairs(list) do
        e.primary = e.internal == L.RETURN
        if e.internal == L.QUIT and not quit then quit = e else center[#center + 1] = e end
    end
    return center, quit
end

-- Exit entries are greyed during the vanilla quit cooldown.
function L.enabled(internal, cooldown)
    if internal == L.EXIT or internal == L.QUIT then return not cooldown end
    return true
end

-- Bottom bar: buttons centred in the space between the version column (verW, at least GEO.verW)
-- and the quit button.
-- widths = text widths (units). Padding shrinks to btnPadMin; beyond that every text gets the same
-- maximum width (ellipsized by the caller). Returns { x, w, textW } per entry plus the area.
function L.bar(screenW, widths, hasQuit, verW)
    local g = L.GEO
    local left = g.barPad + math.max(g.verW, math.ceil(verW or 0)) + g.barGap
    local right = screenW - g.barPad - (hasQuit and (g.quitW + g.barGap) or 0)
    local avail = right - left
    local n = #widths
    local gaps = math.max(0, n - 1) * g.btnGap
    local textSum = 0
    for _, w in ipairs(widths) do textSum = textSum + w end
    local pad = g.btnPad
    if n > 0 and textSum + gaps + 2 * pad * n > avail then
        pad = math.max(g.btnPadMin, math.floor((avail - gaps - textSum) / (2 * n)))
    end
    local maxText
    if n > 0 and textSum + gaps + 2 * pad * n > avail then
        maxText = math.max(0, math.floor((avail - gaps) / n - 2 * pad))
    end
    local out, total = {}, 0
    for i, w in ipairs(widths) do
        local tw = maxText and math.min(w, maxText) or w
        out[i] = { w = tw + 2 * pad, textW = tw }
        total = total + out[i].w
    end
    total = total + gaps
    local x = left + math.floor((avail - total) / 2)
    for i, b in ipairs(out) do
        b.x = x
        x = x + b.w + g.btnGap
    end
    return { buttons = out, left = left, right = right, pad = pad, clipped = maxText ~= nil }
end

-- "13g 6h" from hours survived; fmt has {1} days and {2} hours (not %1: getText would format it).
function L.survivedText(hours, fmt)
    local h = math.max(0, math.floor(tonumber(hours) or 0))
    local s = fmt or "{1}d {2}h"
    s = string.gsub(s, "{1}", tostring(math.floor(h / 24)))
    return (string.gsub(s, "{2}", tostring(h % 24)))
end

-- Game date: day 1-based, translated month name, time of day in hours (float). fmt has {1} day,
-- {2} month, {3} time ("{1} {2}, {3}" -> "14 luglio, 13:20"); lower = month in lower case.
function L.dateText(day, monthName, timeOfDay, fmt, lower)
    local t = tonumber(timeOfDay) or 0
    local hh = math.floor(t) % 24
    local mm = math.floor((t - math.floor(t)) * 60 + 0.0001)
    local month = tostring(monthName or "")
    if lower then month = string.lower(month) end
    local s = fmt or "{1} {2}, {3}"
    s = string.gsub(s, "{1}", tostring(day))
    s = string.gsub(s, "{2}", (string.gsub(month, "%%", "%%%%")))
    return (string.gsub(s, "{3}", string.format("%02d:%02d", hh, mm)))
end

-- City from the save map list ("Muldraugh, KY;Other"): first folder, without the state.
function L.cityText(mapName)
    local first = string.match(tostring(mapName or ""), "^([^;]+)") or ""
    first = string.gsub(first, "^%s+", "")
    return (string.gsub(first, ",.*$", ""))
end

-- Entry and exit motion: entry eases out (fade, bar up from below, title and card in from the left);
-- exit runs it backwards, faster. closing = ms since the menu closed (nil while open).
-- Returns alpha, bar offset down, left column offset (units), done.
L.MOTION = { inMs = 180, outMs = 140, barDy = 24, leftDx = 24 }
function L.motion(elapsed, closing)
    local m = L.MOTION
    local t
    if closing then
        local c = math.max(0, tonumber(closing) or 0)
        if c >= m.outMs then return 0, m.barDy, -m.leftDx, true end
        local k = c / m.outMs
        t = 1 - k * k -- ease in
    else
        local e = math.max(0, tonumber(elapsed) or 0)
        local k = math.min(1, e / m.inMs)
        t = 1 - (1 - k) * (1 - k) * (1 - k) -- ease out
    end
    return t, (1 - t) * m.barDy, -(1 - t) * m.leftDx, false
end

-- Opening fade: alpha from the time since the menu was shown.
function L.fade(elapsed)
    local e = tonumber(elapsed) or 0
    if e <= 0 then return 0 end
    if e >= L.GEO.fadeMs then return 1 end
    return e / L.GEO.fadeMs
end

-- ---------------------------------------------------------------- mod list panel (D-162)
L.MODS = { w = 320, maxH = 420, head = 30, row = 32, gap = 8, pad = 10, numW = 24 }

-- Rows from the active mods in load order: { id, name, found, available, bugged }.
-- state: ok | errors | missing | unavailable (same checks as ISPauseModListUI). Returns rows, errors count.
function L.modRows(list)
    local rows, errors = {}, 0
    for i, m in ipairs(list) do
        local state = "ok"
        if not m.found then state = "missing"
        elseif not m.available then state = "unavailable"
        elseif m.bugged then state = "errors"; errors = errors + 1 end
        rows[i] = { n = i, name = (m.found and m.name) or m.id, state = state }
    end
    return rows, errors
end

-- Panel above the bar, right edge aligned with the Mod button (inside the screen).
-- Returns x, y, w, h and the scrolling height of the list (0 = everything fits).
function L.modPanel(btnX, btnW, screenW, barTop, n)
    local M = L.MODS
    local listH = n * M.row
    local h = math.min(M.maxH, M.head + listH)
    local x = math.max(0, math.min(btnX + btnW - M.w, screenW - M.w))
    local y = barTop - M.gap - h
    return x, y, M.w, h, math.max(0, listH - (h - M.head))
end

-- ---------------------------------------------------------------- quit to desktop confirmation (D-164)
L.CONFIRM = { w = 380, pad = 20, titleH = 28, gap = 8, textH = 18, btnGap = 20, btnH = 40, hintGap = 8, hintH = 16,
    btnSpace = 8, btnPad = 16, icon = 22, dim = 0.55, inMs = 120, outMs = 100, dy = 12 }

-- Box centred on the screen; buttons at the bottom right (widths = text widths). Units.
function L.confirmBox(screenW, screenH, cancelW, okW, iconW)
    local C = L.CONFIRM
    local h = C.pad + C.titleH + C.gap + C.textH + C.btnGap + C.btnH + C.hintGap + C.hintH + C.pad
    local x = math.floor((screenW - C.w) / 2)
    local y = math.floor((screenH - h) / 2)
    local by = y + C.pad + C.titleH + C.gap + C.textH + C.btnGap
    local okB = (okW or 0) + 2 * C.btnPad + (iconW or 0)
    local cancelB = (cancelW or 0) + 2 * C.btnPad
    local right = x + C.w - C.pad
    return {
        x = x, y = y, w = C.w, h = h,
        ok = { x = right - okB, y = by, w = okB, h = C.btnH },
        cancel = { x = right - okB - C.btnSpace - cancelB, y = by, w = cancelB, h = C.btnH },
        hintY = by + C.btnH + C.hintGap,
    }
end

-- Confirmation motion: alpha, offset down, done.
function L.confirmMotion(elapsed, closing)
    local C = L.CONFIRM
    if closing then
        local k = math.min(1, math.max(0, tonumber(closing) or 0) / C.outMs)
        local t = 1 - k * k
        return t, (1 - t) * C.dy, k >= 1
    end
    local k = math.min(1, math.max(0, tonumber(elapsed) or 0) / C.inMs)
    local t = 1 - (1 - k) * (1 - k) * (1 - k)
    return t, (1 - t) * C.dy, false
end
