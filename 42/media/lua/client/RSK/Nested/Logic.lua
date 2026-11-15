-- RSK.Nested.Logic - M3, P2.2: pure logic of the nested container windows (D-73). Tests T-19.
-- Only methods of the objects passed in: no global game API.
RSK = RSK or {}
RSK.Nested = RSK.Nested or {}
local L = {}
RSK.Nested.Logic = L
L.MAX_DEPTH = 16

-- Containers enclosing the item, from outside to inside.
function L.chain(item)
    local out, c, n = {}, item:getContainer(), 0
    while c and n < L.MAX_DEPTH do
        table.insert(out, 1, c)
        local ci = c:getContainingItem()
        if not ci then break end
        c, n = ci:getContainer(), n + 1
    end
    return out
end

-- Path for the title (RF-3.5): Inventory > Backpack > Bag > Lunchbox.
function L.path(item, labelOf, sep)
    local parts = {}
    for i, c in ipairs(L.chain(item)) do parts[i] = labelOf(c) end
    parts[#parts + 1] = item:getName()
    return table.concat(parts, sep)
end

-- Outermost item of the chain: the one on the floor, in the inventory or in a world container.
function L.outermost(item)
    local top, n = item, 0
    while n < L.MAX_DEPTH do
        local c = top:getContainer()
        local ci = c and c:getContainingItem()
        if not ci then break end
        top, n = ci, n + 1
    end
    return top
end

-- New window: centre of the screen, offset by `step` for each window already open, always inside the screen.
function L.place(n, w, h, sw, sh, step)
    local x = math.floor(sw / 2 - w / 2 + n * step)
    local y = math.floor(sh / 2 - h / 2 + n * step)
    x = math.max(0, math.min(x, sw - w))
    y = math.max(0, math.min(y, sh - h))
    return x, y
end

return L
