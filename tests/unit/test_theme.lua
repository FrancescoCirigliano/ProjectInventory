-- Theme unit tests (D-46): RSK.Theme. Scenario T-15 (see docs/Test.md).
local T, C, B, K = RSK.Theme, RSK.Config, RSK.Bus, RSK.Core

local results = { pass = 0, fail = 0, lines = {} }
local function test(id, name, fn)
    local ok, err = pcall(fn)
    if ok then
        results.pass = results.pass + 1
        results.lines[#results.lines + 1] = "PASS " .. id .. " " .. name
    else
        results.fail = results.fail + 1
        results.lines[#results.lines + 1] = "FAIL " .. id .. " " .. name .. ": " .. tostring(err)
    end
end
local function eq(a, b, msg)
    if a ~= b then error((msg or "valore") .. ": atteso " .. tostring(b) .. ", ottenuto " .. tostring(a), 2) end
end
local function near(a, b, msg)
    if math.abs(a - b) > 0.002 then error((msg or "valore") .. ": atteso " .. tostring(b) .. ", ottenuto " .. tostring(a), 2) end
end

local file
local function reset()
    B.listeners, B.pending, B.pendingIndex = {}, {}, {}
    C.schema, C.order, C.values, C.extra, C.loaded = {}, {}, {}, {}, false
    file = nil
    C.io = { read = function() return file end, write = function(_, l) file = l; return true end }
    K.modules, K.order, K.phase = {}, {}, "load"
    K.log = function() end
    T.state = nil
    T.defineConfig()
    K.register(T.moduleDef)
end

test("T-15a", "hex: conversione e valori non validi", function()
    local c = T.hex("#ff8000")
    near(c.r, 1); near(c.g, 128 / 255); near(c.b, 0); eq(c.a, 1)
    eq(T.hex("#fff"), nil); eq(T.hex("rosso"), nil); eq(T.hex(nil), nil)
end)
test("T-15b", "preset completi e validi", function()
    for _, id in ipairs(T.PRESET_ORDER) do
        for _, tok in ipairs(T.COLOR_TOKENS) do
            if not T.hex(T.presets[id][tok]) then error(id .. "." .. tok .. " non valido") end
        end
    end
end)
test("T-15c", "scala dal livello font del gioco a crescita dimezzata; atlas a taglia esatta (D-108)", function()
    near(T.levelScale(1), 1); near(T.levelScale(2), 1 + (19 / 16 - 1) / 2); near(T.levelScale(3), 1 + (26 / 16 - 1) / 2)
    near(T.levelScale(5), 1 + (38 / 16 - 1) / 2); near(T.levelScale(nil), 1); near(T.levelScale(9), 1)
    near(T.build("ruggine", nil, 4, 1.5).scale, (1 + (33 / 16 - 1) / 2) * 1.5)
    local S = { 13, 14, 16, 17, 29 }
    local a, s = T.pickSize(S, 16); eq(a, 16); eq(s, 1)
    a, s = T.pickSize(S, 16.4); eq(a, 16); eq(s, 1, "arrotondata alla taglia esatta")
    a, s = T.pickSize(S, 15); eq(a, 16); near(s, 15 / 16, "mancante: ridotta dalla successiva")
    a, s = T.pickSize(S, 40); eq(a, 29); near(s, 40 / 29, "oltre l'ultima")
    for fam in pairs(T.FONT_FILES) do assert(T.FONT_SIZES[fam] and #T.FONT_SIZES[fam] > 0, "taglie per " .. fam) end
end)
test("T-15d", "build: preset, sovrascritture, hover (D-50, D-51)", function()
    local s = T.build("notte", { accent = "#ff0000" }, 2, 1)
    eq(s.preset, "notte"); eq(s.hexes.bg, "#0c1013"); eq(s.hexes.accent, "#ff0000"); near(s.colors.accent.r, 1)
    near(s.colors.hover.r, s.colors.sel.r); eq(s.colors.hover.a, 0.6)
    eq(T.build("ignoto", nil, 2, 1).preset, "ruggine")
    eq(T.build("ruggine", { ok = "sbagliato" }, 2, 1).hexes.ok, "sbagliato", "hex grezzo")
    near(T.build("ruggine", { ok = "sbagliato" }, 2, 1).colors.ok.r, 0x93 / 255, "ripiego sul default")
end)
test("T-15e", "avvio: tema di default Ruggine", function()
    reset(); K.boot()
    eq(T.presetId(), "ruggine"); eq(K.isActive("Theme"), true); eq(C.schema["module.Theme"], nil, "nessuna chiave module")
    local r, g, b, a = T.rgba("accent", 0.5); near(r, 0xd4 / 255); eq(a, 0.5)
end)
test("T-15f", "cambio preset e colore a caldo -> ThemeChanged", function()
    reset(); K.boot()
    local n = 0
    B.on("ThemeChanged", function() n = n + 1 end)
    eq(T.setPreset("militare"), true); eq(n, 1); near(T.color("accent").r, 0xbc / 255)
    eq(T.setPreset("viola"), false); eq(n, 1)
    T.setColor("accent", "#FF0000"); eq(n, 2); near(T.color("accent").g, 0)
    T.setColor("accent", ""); eq(n, 3); near(T.color("accent").r, 0xbc / 255, "torna al preset")
end)
test("T-15g", "colori sovrascritti salvati e riletti; vuoto = preset", function()
    reset(); K.boot()
    T.setColor("ok", "#00ff00"); T.setPreset("notte")
    local saved = file
    local found
    for _, l in ipairs(saved) do if l == "theme.color.danger = " then found = true end end
    eq(found, true, "chiave vuota scritta")
    reset(); file = saved; K.boot()
    eq(T.presetId(), "notte"); eq(T.state.hexes.ok, "#00ff00"); eq(T.state.hexes.danger, "#e5764f")
    T.resetColors(); eq(T.state.hexes.ok, "#7cb87d")
end)
test("T-15h", "misure e font scalati con ui.scale", function()
    reset(); K.boot()
    eq(T.size("h", "row"), 52); eq(T.size("border"), 1)
    C.set("ui.scale", 1.5)
    eq(T.px(52), 78); eq(T.size("icon", "item"), 63); eq(T.font("label").size, 20); eq(T.font("label").upper, true)
    eq(T.font("ignoto").family, "regular"); eq(T.font("row").ready, false, "senza atlas (fuori dal gioco)")
end)
test("T-15i", "Theme non disattivabile", function()
    reset(); K.boot()
    eq(K.setEnabled("Theme", false), false); eq(K.isActive("Theme"), true)
end)

return results
