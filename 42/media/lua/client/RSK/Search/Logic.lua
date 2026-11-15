-- RSK.Search.Logic - search filter with no engine dependencies (testable, T-20; D-74).
-- Accents as escape sequences: the same source works in Kahlua and in the tests (like IL.qtyText).
RSK = RSK or {}
RSK.Search = RSK.Search or {}
RSK.Search.Logic = RSK.Search.Logic or {}
local L = RSK.Search.Logic

local FOLD = {
    { "\195\160", "a" }, { "\195\161", "a" }, { "\195\162", "a" }, { "\195\163", "a" }, { "\195\164", "a" }, { "\195\165", "a" },
    { "\195\128", "a" }, { "\195\129", "a" }, { "\195\130", "a" }, { "\195\131", "a" }, { "\195\132", "a" }, { "\195\133", "a" },
    { "\195\167", "c" }, { "\195\135", "c" },
    { "\195\168", "e" }, { "\195\169", "e" }, { "\195\170", "e" }, { "\195\171", "e" },
    { "\195\136", "e" }, { "\195\137", "e" }, { "\195\138", "e" }, { "\195\139", "e" },
    { "\195\172", "i" }, { "\195\173", "i" }, { "\195\174", "i" }, { "\195\175", "i" },
    { "\195\140", "i" }, { "\195\141", "i" }, { "\195\142", "i" }, { "\195\143", "i" },
    { "\195\177", "n" }, { "\195\145", "n" },
    { "\195\178", "o" }, { "\195\179", "o" }, { "\195\180", "o" }, { "\195\181", "o" }, { "\195\182", "o" },
    { "\195\146", "o" }, { "\195\147", "o" }, { "\195\148", "o" }, { "\195\149", "o" }, { "\195\150", "o" },
    { "\195\185", "u" }, { "\195\186", "u" }, { "\195\187", "u" }, { "\195\188", "u" },
    { "\195\153", "u" }, { "\195\154", "u" }, { "\195\155", "u" }, { "\195\156", "u" },
}

local CACHE_MAX = 4000
local cache, cacheN = {}, 0

-- Lowercase and without accents (RF-6.3). Results cached: names repeat on every list update.
function L.fold(s)
    s = tostring(s or "")
    local f = cache[s]
    if f then return f end
    f = s
    for i = 1, #FOLD do f = string.gsub(f, FOLD[i][1], FOLD[i][2]) end
    f = string.lower(f) -- after the accents: depending on the locale, lower may alter non-ASCII bytes
    if cacheN >= CACHE_MAX then cache, cacheN = {}, 0 end
    cache[s], cacheN = f, cacheN + 1
    return f
end

-- Search words; empty or whitespace-only text -> no words (no filter).
function L.terms(query)
    local out = {}
    for t in string.gmatch(L.fold(query), "%S+") do out[#out + 1] = t end
    return out
end

-- Every word must appear in the name or the category (D-74). Literal search, no patterns.
function L.matches(terms, name, category)
    if #terms == 0 then return true end
    local hay = L.fold(name) .. " " .. L.fold(category)
    for i = 1, #terms do
        if not string.find(hay, terms[i], 1, true) then return false end
    end
    return true
end

-- Filters in place the vanilla itemslist stacks. entry.count = items + 1 (see refreshContainer);
-- textOf(entry) -> name, category. Returns visible items and the total (D-74: items, not stacks).
function L.filter(list, terms, textOf)
    local n, w, shown, total = #list, 0, 0, 0
    for r = 1, n do
        local e = list[r]
        local c = (e.count or 1) - 1
        total = total + c
        local keep = #terms == 0
        if not keep then
            local name, category = textOf(e)
            keep = L.matches(terms, name, category)
        end
        if keep then
            w = w + 1
            list[w] = e
            shown = shown + c
        end
    end
    for i = w + 1, n do list[i] = nil end
    return shown, total
end

-- Matching items only (D-75: Loot all / Transfer all). textOf(item) -> name, category.
function L.visibleItems(items, terms, textOf)
    local out = {}
    for i = 1, #items do
        local name, category = textOf(items[i])
        if L.matches(terms, name, category) then out[#out + 1] = items[i] end
    end
    return out
end
