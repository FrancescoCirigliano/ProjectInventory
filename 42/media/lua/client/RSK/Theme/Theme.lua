-- RSK.Theme - token-based theme (RF-0.2, RF-0.3). The only place widgets read colours, sizes and fonts from.
-- Preset + colours overridden in config (D-51) + scale (D-49). Live changes -> "ThemeChanged" event.
require "RSK/Core/Bootstrap"
require "RSK/Theme/Presets"
require "RSK/Theme/FontSizes"

local T, C, B, K = RSK.Theme, RSK.Config, RSK.Bus, RSK.Core

function T.defineConfig()
    C.define("theme.preset", "enum", T.DEFAULT_PRESET, { values = T.PRESET_ORDER })
    C.define("ui.scale", "number", 1, { min = 0.5, max = 2 })
    for _, tok in ipairs(T.COLOR_TOKENS) do
        C.define("theme.color." .. tok, "color", nil, { optional = true })
    end
end
T.defineConfig()

-- Scale from the game's "text size" level (D-108): level 1 (16 px) = mockup, grows at half the vanilla rate.
T.LEVEL_SMALL = { 16, 19, 26, 33, 38 }
T.LEVEL_REF = 1
T.LEVEL_GROWTH = 0.5

-- ---------------------------------------------------------------- pure functions
function T.hex(s)
    local r, g, b = tostring(s):match("^#(%x%x)(%x%x)(%x%x)$")
    if not r then return nil end
    return { r = tonumber(r, 16) / 255, g = tonumber(g, 16) / 255, b = tonumber(b, 16) / 255, a = 1 }
end

-- Level 1-5 (out-of-range or missing values -> reference level).
function T.levelScale(level)
    local l = math.floor(tonumber(level) or T.LEVEL_REF)
    if l < 1 or l > #T.LEVEL_SMALL then l = T.LEVEL_REF end
    return 1 + (T.LEVEL_SMALL[l] / T.LEVEL_SMALL[T.LEVEL_REF] - 1) * T.LEVEL_GROWTH
end

-- Atlas for a size (D-108): exact size if generated, otherwise the smallest larger one (scaled down);
-- beyond the last one, the last one. sizes in ascending order. Returns the atlas size and the draw scale.
function T.pickSize(sizes, size)
    local want = math.floor(size + 0.5)
    for _, s in ipairs(sizes) do
        if s >= want then return s, (s == want) and 1 or size / s end
    end
    local s = sizes[#sizes]
    return s, size / s
end

-- Theme state: preset, overrides { token = "#rrggbb" }, game font level, user tweak.
function T.build(presetId, overrides, fontLevel, userScale)
    local preset = T.presets[presetId] or T.presets[T.DEFAULT_PRESET]
    local colors, hexes = {}, {}
    for _, tok in ipairs(T.COLOR_TOKENS) do
        local h = (overrides and overrides[tok]) or preset[tok]
        local c = T.hex(h) or T.hex(T.presets[T.DEFAULT_PRESET][tok])
        hexes[tok], colors[tok] = h, c
    end
    local sel = colors.sel
    colors.hover = { r = sel.r, g = sel.g, b = sel.b, a = T.alpha.hover }
    return {
        preset = T.presets[presetId] and presetId or T.DEFAULT_PRESET,
        colors = colors,
        hexes = hexes,
        scale = T.levelScale(fontLevel) * (tonumber(userScale) or 1),
    }
end

-- ---------------------------------------------------------------- widget API
local function state()
    if not T.state then T.rebuild(true) end
    return T.state
end

-- Shared { r, g, b, a } table: do not modify it.
function T.color(tok) return state().colors[tok] end
function T.rgba(tok, alpha)
    local c = state().colors[tok]
    return c.r, c.g, c.b, alpha or c.a
end
function T.scale() return state().scale end
function T.px(n) return math.floor(n * state().scale + 0.5) end
-- T.size("h", "row") -> scaled px
function T.size(group, name)
    local g = T.base[group]
    local v = type(g) == "table" and g[name] or g
    return v and T.px(v) or nil
end
-- Font of a role: { family, size (scaled), upper, tracking }; ready = atlas loaded.
function T.font(role)
    local f = T.fonts[role] or T.fonts.body
    return { family = f.family, size = T.px(f.size), upper = f.upper, tracking = f.tracking, ready = T.fontReady(f.family) }
end
function T.presetId() return state().preset end

-- ---------------------------------------------------------------- fonts (Fira bitmap atlases from Lua, D-106)
-- Languages with a Latin alphabet: the others (Cyrillic, CJK, Thai...) stay on the vanilla fonts (V-05).
T.LATIN = { EN = true, IT = true, FR = true, DE = true, ES = true, PT = true, PTBR = true, NL = true,
    DA = true, NO = true, FI = true, PL = true, CS = true, HU = true, RO = true, TR = true, ID = true, CA = true }
T.fontState = T.fontState or {}
T.fontObj = T.fontObj or {}

function T.language()
    local ok, l = pcall(function() return tostring(Translator.getLanguage():name()) end)
    return ok and l or "EN"
end

-- Mod atlases through AngelCodeFont (D-109): one Java call per string. The constructor (fnt, png) reads the
-- metrics at once and initialises the glyphs only when the page texture is ready: until then drawString
-- draws glyphs with no image (white). So it draws only when font:isLoading() is false; before that,
-- that string uses the vanilla font. Metrics are valid right away (stable layouts). Fonts created when preloading.
function T.loadFonts()
    T.fontObj, T.fontState = {}, {}
    if not T.LATIN[T.language()] or not T.FONT_SIZES or AngelCodeFont == nil then return false end
    for family in pairs(T.FONT_FILES) do
        if T.FONT_SIZES[family] then T.fontObj[family], T.fontState[family] = {}, true end
    end
    return true
end
function T.fontReady(family) return T.fontState[family] == true end

-- Font of a size: { acf, ready } or false if the file is missing (vanilla fallback for good).
-- (fnt, Texture) is unusable: it opens the .fnt from the game folder and does not load the pages.
local function loadSize(family, s)
    local set = T.fontObj[family]
    local f = set[s]
    if f ~= nil then return f end
    local path = T.FONT_DIR .. T.FONT_FILES[family] .. s
    local ok, o = pcall(function() return AngelCodeFont.new(path .. ".fnt", path .. "_0.png") end)
    if ok and o then
        f = { acf = o, ready = false }
    else
        f = false
        K.log("font non caricato: " .. path .. " (" .. tostring(o) .. ")")
    end
    set[s] = f
    return f
end

-- Pages ready: checked until they are, then no more (glyphs reinitialise by themselves if the
-- game reloads the texture; back at the menu Lua restarts and the fonts are recreated).
local function ready(f)
    if f.ready then return true end
    local acf = f.acf
    local ok, loading = pcall(function() return acf:isLoading() end)
    if ok and loading == false then f.ready = true end
    return f.ready
end

-- AngelCodeFont and draw scale for a family and an already scaled px size.
-- metrics = true: the font is enough (metrics valid even while the texture loads);
-- otherwise nil until the pages are ready -> that string is drawn with the vanilla font.
function T.fontFor(family, size, metrics)
    if not T.fontObj[family] then return nil end
    local s, scale = T.pickSize(T.FONT_SIZES[family], size)
    local f = loadSize(family, s)
    if not f or (not metrics and not ready(f)) then return nil end
    return f.acf, scale
end

-- Preloads the role sizes at the current scale: textures load before they are needed.
function T.preloadFonts()
    if not T.fontObj then return end
    for _, r in pairs(T.fonts) do
        if T.fontObj[r.family] then loadSize(r.family, (T.pickSize(T.FONT_SIZES[r.family], T.px(r.size)))) end
    end
end

-- ---------------------------------------------------------------- state and live changes
local function fontLevel()
    local ok, l = pcall(function() return getCore():getOptionFontSizeReal() end)
    return ok and l or T.LEVEL_REF
end

function T.overrides()
    local o = {}
    for _, tok in ipairs(T.COLOR_TOKENS) do
        local v = C.get("theme.color." .. tok)
        if v then o[tok] = v end
    end
    return o
end

function T.rebuild(silent)
    T.state = T.build(C.get("theme.preset"), T.overrides(), fontLevel(), C.get("ui.scale"))
    if not silent then B.emit("ThemeChanged", T.state) end
    return T.state
end

function T.setPreset(id) return C.set("theme.preset", id) end
-- hex nil or "" = back to the preset value
function T.setColor(tok, hex) return C.set("theme.color." .. tok, hex) end
function T.resetColors()
    for _, tok in ipairs(T.COLOR_TOKENS) do C.set("theme.color." .. tok, nil, true) end
    C.save()
end

function T.onConfig(key)
    if key == "theme.preset" or key == "ui.scale" or key:sub(1, 12) == "theme.color." then T.rebuild() end
    if key == "ui.scale" then T.preloadFonts() end
end
-- Game start: font level re-read (applies after restart) and sizes preloaded; textures freed
-- by the menu are requested again by themselves on first use (usable).
local function onGameStart()
    T.rebuild()
    T.preloadFonts()
end

T.moduleDef = K.register{
    id = "Theme", when = "boot", core = true,
    start = function(m)
        T.loadFonts()
        T.rebuild(true)
        T.preloadFonts()
        K.log(string.format("tema: preset %s, scala %.2f, font Fira %s (lingua %s)", T.state.preset, T.state.scale,
            tostring(T.fontReady("regular") and T.fontReady("semibold")), T.language()))
        B.on("ConfigChanged", T.onConfig, m.id)
        if Events and Events.OnGameStart then Events.OnGameStart.Add(onGameStart) end
    end,
    stop = function()
        if Events and Events.OnGameStart then Events.OnGameStart.Remove(onGameStart) end
    end,
}
