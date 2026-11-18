-- RSK.Tooltip.Logic - generic tooltip colours (P3.4, D-145) with no engine dependencies (testable,
-- T-32). The vanilla ISToolTip keeps doing the layout and the rich text; while it draws, its fixed
-- colours and the rich text colours (<RED>, <GREEN>, <RGB:...>, bad/good highlight) become tokens.
-- Each function returns token, alpha for a recognised colour, or nil to draw it unchanged.
-- ctx = { bad = {r,g,b}, good = {r,g,b} } read from the game core each frame.
RSK = RSK or {}
RSK.Tooltip = RSK.Tooltip or {}
RSK.Tooltip.Logic = RSK.Tooltip.Logic or {}
local L = RSK.Tooltip.Logic

L.EPS = 0.02
L.MARGIN = 10      -- left margin of the title (vanilla 8)
L.VANILLA_NAME_X = 8
L.SEP_DY = 6       -- separator under the title: y = height of the Medium font + 6 (between title and text)

local function near(a, b) return type(a) == "number" and math.abs(a - b) <= L.EPS end
local function rgb(r, g, b, R, G, B) return near(r, R) and near(g, G) and near(b, B) end
local function same(r, g, b, c) return c ~= nil and rgb(r, g, b, c.r, c.g, c.b) end

-- drawRect(x, y, w, h, a, r, g, b) of ISToolTip
function L.rect(a, r, g, b)
    if near(a, 0.7) and rgb(r, g, b, 0.05, 0.05, 0.05) then return "bg", 1 end -- background
    return nil
end

-- drawRectBorder(x, y, w, h, a, r, g, b) of ISToolTip
function L.border(a, r, g, b)
    if near(a, 0.5) and rgb(r, g, b, 0.9, 0.9, 1) then return "line", 1 end -- frame
    return nil
end

-- Text colours of the title, the foot note and the rich text description.
function L.text(r, g, b, ctx)
    ctx = ctx or {}
    if ctx.bad and same(r, g, b, ctx.bad) then return "danger", 1 end
    if ctx.good and same(r, g, b, ctx.good) then return "ok", 1 end
    if rgb(r, g, b, 1, 1, 1) then return "text", 1 end
    if rgb(r, g, b, 1, 0, 0) or rgb(r, g, b, 1, 0.5, 0.5) then return "danger", 1 end -- <RED>, missing
    if rgb(r, g, b, 0, 1, 0) then return "ok", 1 end                                  -- <GREEN>
    if rgb(r, g, b, 0.9, 0.3, 0) or rgb(r, g, b, 1, 1, 0) then return "warn", 1 end   -- <ORANGE>, yellow
    if type(r) == "number" and near(r, g) and near(g, b) and r >= 0.4 and r <= 0.8 then
        return "muted", 1                                                             -- grey notes
    end
    return nil
end

-- Title x: the vanilla title at 8 moves to the margin; anything else stays.
function L.nameX(x, y)
    if x == L.VANILLA_NAME_X and y == 5 then return L.MARGIN end
    return x
end

-- Separator rect under the title, or nil (no title or no text).
function L.separator(width, fontHgtMedium, hasName, hasText)
    if not hasName or not hasText or width <= 2 * L.MARGIN then return nil end
    return L.MARGIN, fontHgtMedium + L.SEP_DY, width - 2 * L.MARGIN, 1
end
