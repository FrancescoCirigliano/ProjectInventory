-- RSK.UI.Mute - runs vanilla code with drawing calls disabled (D-61).
-- Vanilla logic runs unchanged (state, lists, scrolling, stencil); only the ISUIElement draw* methods
-- become empty for that element during the call. Then the mod draws themed.
-- Global drawing functions (e.g. Render3DItem) are not touched.
require "ISUI/ISUIElement"

RSK = RSK or {}
RSK.UI = RSK.UI or {}
RSK.UI.Mute = RSK.UI.Mute or {}
local M = RSK.UI.Mute
local unpack = unpack or table.unpack
local function pack(...) return { n = select("#", ...), ... } end
local function noop() end

local names
function M.names()
    if names then return names end
    names = {}
    for k, v in pairs(ISUIElement) do
        if type(v) == "function" and type(k) == "string" and k:sub(1, 4) == "draw" then names[#names + 1] = k end
    end
    table.sort(names)
    return names
end

-- fn(el, ...) with el's drawing disabled. Errors of the vanilla function propagate unchanged.
function M.call(el, fn, ...)
    local list, saved = M.names(), {}
    for i = 1, #list do
        local k = list[i]
        saved[k] = rawget(el, k)
        el[k] = noop
    end
    local r = pack(pcall(fn, el, ...))
    for i = 1, #list do el[list[i]] = saved[list[i]] end
    if not r[1] then error(r[2], 0) end
    return unpack(r, 2, r.n)
end

-- Skin of a vanilla element: original prerender/render muted, then themed pre(el)/post(el).
-- active() -> false: vanilla drawing comes back (module off or failed).
function M.skin(el, pre, post, active)
    local s = rawget(el, "rskSkin")
    if s then s.pre, s.post, s.active = pre, post, active; return el end
    s = { pre = pre, post = post, active = active,
        savedPre = rawget(el, "prerender"), savedRender = rawget(el, "render") }
    local origPre, origRender = el.prerender, el.render
    el.rskSkin = s
    el.prerender = function(self)
        if not s.active() then return origPre(self) end
        M.call(self, origPre)
        if s.pre then s.pre(self) end
    end
    el.render = function(self)
        if not s.active() then return origRender(self) end
        M.call(self, origRender)
        if s.post then s.post(self) end
    end
    return el
end

function M.unskin(el)
    local s = rawget(el, "rskSkin")
    if not s then return end
    el.prerender, el.render = s.savedPre, s.savedRender
    el.rskSkin = nil
end
