-- RSK.UI widget gallery (D-54): -debug only. Opens from the "RSK: galleria widget" menu or with RSK.Gallery.open().
-- Visual check of P1.3: styles, states, 2000-row list, live preset and scale change.
require "RSK/UI/UI"

RSK.Gallery = RSK.Gallery or {}
local G, UI, T, C = RSK.Gallery, RSK.UI, RSK.Theme, RSK.Config

local function tx(k, ...) return getText("UI_RSK_Gal_" .. k, ...) end

function G.open()
    if G.win then G.win:bringToTop(); return G.win end
    local W, H = 760, 620
    local win = UI.Window:new(1100, 120, W, H, tx("Title"), { resizable = true, onClose = function() G.win = nil end })
    win:open()
    G.win = win
    local y0 = win:contentY()
    local pages = {}
    local function page(id)
        local p = win:addContent(UI.Panel:new(0, y0 + 40, W, H - y0 - 40, { bg = false, border = false }))
        pages[id] = p
        return p
    end
    local tabs = win:addContent(UI.Tabs:new(16, y0, W - 32, {
        { id = "controls", text = tx("TabControls") }, { id = "list", text = tx("TabList") }, { id = "theme", text = tx("TabTheme") },
    }, nil, function(_, id) for k, p in pairs(pages) do p:setVisible(k == id) end end))

    -- Controls
    local p = page("controls")
    local x, y = 16, 16
    local b1 = UI.add(p, UI.Button:new(x, y, 160, 44, tx("Primary"), nil, nil, { style = "primary" }))
    b1:setTooltip(tx("Tooltip"))
    UI.add(p, UI.Button:new(x + 172, y, 160, 44, tx("Secondary")))
    UI.add(p, UI.Button:new(x + 344, y, 160, 44, tx("Danger"), nil, nil, { style = "danger" }))
    local d = UI.add(p, UI.Button:new(x + 516, y, 160, 44, tx("Disabled"))); d:setEnabled(false)
    y = y + 64
    local status = UI.add(p, UI.Label:new(x, y + 168, W - 32, "", "body", { tok = "muted" }))
    UI.add(p, UI.Toggle:new(x, y, 300, tx("Toggle"), true, nil, function(_, v) status:setText(tx("Toggle") .. ": " .. tostring(v)) end))
    y = y + 40
    local bar = UI.add(p, UI.Bar:new(x + 340, y + 8, 300, 8, 0.5, { mode = "cond" }))
    UI.add(p, UI.Slider:new(x, y, 300, 0, 100, 50, nil, function(_, v)
        bar:setValue(v / 100); status:setText(tx("Slider") .. ": " .. v)
    end, { step = 1, format = function(v) return tostring(v) end }))
    y = y + 44
    UI.add(p, UI.Label:new(x, y, 120, tx("Cond"), "label", { tok = "muted" }))
    for i, v in ipairs({ 0.9, 0.45, 0.15 }) do UI.add(p, UI.Bar:new(x + 130 + (i - 1) * 110, y + 6, 100, 5, v, { mode = "cond" })) end
    UI.add(p, UI.Label:new(x + 480, y, 80, tx("Load"), "label", { tok = "muted" }))
    UI.add(p, UI.Bar:new(x + 560, y + 4, 150, 10, 0.85, { mode = "load" }))
    y = y + 40
    UI.add(p, UI.Label:new(x, y, 360, tx("Long"), "row"))
    y = y + 72
    UI.add(p, UI.TextField:new(x, y, 360, 36, tx("Field")))
    y = y + 56
    UI.add(p, UI.Label:new(x, y, 700, tx("Title"), "screenTitle"))

    -- List
    p = page("list")
    local items = {}
    for i = 1, 2000 do items[i] = { text = tx("Row", i) } end
    local info = UI.add(p, UI.Label:new(16, 16, W - 32, "", "body", { tok = "muted" }))
    local dbl = 0
    local list = UI.add(p, UI.List:new(16, 48, W - 32, H - y0 - 40 - 64, {
        onSelect = function(_, item, i) info:setText(tx("Selected", i, dbl)) end,
        onDoubleClick = function(_, item, i) dbl = dbl + 1; info:setText(tx("Selected", i, dbl)) end,
    }))
    list:setItems(items)
    p:setVisible(false)

    -- Theme (live change, D-51)
    p = page("theme")
    UI.add(p, UI.Label:new(16, 16, 300, tx("Preset"), "label", { tok = "muted" }))
    for i, id in ipairs(T.PRESET_ORDER) do
        UI.add(p, UI.Button:new(16 + (i - 1) * 172, 44, 160, 44, tx("Preset_" .. id), nil, function() T.setPreset(id) end))
    end
    UI.add(p, UI.Button:new(16, 104, 220, 44, tx("Accent"), nil, function() T.setColor("accent", "#d03030") end))
    UI.add(p, UI.Button:new(248, 104, 220, 44, tx("Reset"), nil, function() T.resetColors() end))
    UI.add(p, UI.Label:new(16, 172, 300, tx("Scale"), "label", { tok = "muted" }))
    UI.add(p, UI.Slider:new(16, 200, 400, 0.5, 2, C.get("ui.scale"), nil, function(_, v) C.set("ui.scale", v) end,
        { step = 0.05, onRelease = true, format = function(v) return string.format("%.2f", v) end }))
    p:setVisible(false)
    return win
end
