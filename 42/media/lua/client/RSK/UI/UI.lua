-- RSK.UI - widget library (P1.3, D-52...D-55). Core service: on every ThemeChanged
-- open windows redraw and resize (scale D-49).
require "RSK/UI/Widgets"
require "RSK/UI/List"
require "RSK/UI/TextField"
require "RSK/UI/Tooltip"
require "RSK/UI/Window"

local UI, B, K = RSK.UI, RSK.Bus, RSK.Core

function UI.refreshAll()
    for w in pairs(UI.windows) do w:themeChanged() end
end

UI.moduleDef = K.register{
    id = "UI", when = "boot", core = true, requires = { "Theme" },
    start = function(m) B.on("ThemeChanged", UI.refreshAll, m.id) end,
}
