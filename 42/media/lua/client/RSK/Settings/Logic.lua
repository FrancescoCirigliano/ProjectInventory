-- RSK.Settings.Logic - Settings window calculations with no engine dependencies (testable, T-24).
RSK = RSK or {}
RSK.Settings = RSK.Settings or {}
RSK.Settings.Logic = RSK.Settings.Logic or {}
local L = RSK.Settings.Logic

-- Modules shown in the Modules tab (D-125), in window order.
L.MODULES = { "Inventory", "Nested", "Search", "Equipment", "Collect", "ContextMenu", "Tooltip", "Hotbar" }
-- Internal keys left alone by "Reset to defaults" (they are not user settings).
L.RESET_SKIP = { ["equipment.layoutSaved"] = true }
L.CONFIRM_MS = 3000
L.SCALE_MIN, L.SCALE_MAX, L.SCALE_STEP = 0.75, 1.5, 0.05

-- Status shown below the toggle: "on" | "off" | "failed" | "requires" (+ list of missing modules).
-- state = Core state (on, off, disabled, blocked, failed); requires = required ids; isActive(id) -> bool.
function L.moduleStatus(state, requires, isActive)
    if state == "on" then return "on" end
    if state == "failed" then return "failed" end
    local missing = {}
    for _, r in ipairs(requires or {}) do
        if not isActive(r) then missing[#missing + 1] = r end
    end
    if state == "blocked" or (#missing > 0 and state ~= "disabled") then return "requires", missing end
    return "off"
end

-- Keys to reset: every defined key except the internal ones, in definition order.
function L.resetKeys(order)
    local out = {}
    for _, k in ipairs(order or {}) do
        if not L.RESET_SKIP[k] then out[#out + 1] = k end
    end
    return out
end

-- Two-click reset: the second counts only within CONFIRM_MS of the first.
function L.confirmed(armedAt, now)
    return armedAt ~= nil and now - armedAt <= L.CONFIRM_MS
end
