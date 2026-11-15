-- RSK.Config - user settings kept outside the save (V-14, RNF-10, D-47).
-- File Zomboid/Lua/RSK_config.txt, lines "key = value", "#" comment.
-- Missing or invalid value -> default. Unknown keys are kept on save.
require "RSK/Core/EventBus"

RSK = RSK or {}
RSK.Config = RSK.Config or {}
local C = RSK.Config
C.FILE = "RSK_config.txt"
C.VERSION = 1
C.schema = C.schema or {}   -- key -> { type, default, min, max, values }
C.order = C.order or {}
C.values = C.values or {}
C.extra = C.extra or {}     -- keys found in the file but not defined

-- type: "bool" | "number" | "string" | "enum" (opts.values) | "color" ("#rrggbb")
function C.define(key, typ, default, opts)
    local def = { key = key, type = typ, default = default }
    for k, v in pairs(opts or {}) do def[k] = v end
    if not C.schema[key] then C.order[#C.order + 1] = key end
    C.schema[key] = def
    return def
end

local function trim(s) return (s:gsub("^%s+", ""):gsub("%s+$", "")) end

-- Returns the converted value, or nil if invalid. Accepts strings (from the file) or Lua values.
function C.validate(def, v)
    if v == nil then return nil end
    local t = def.type
    if t == "bool" then
        if type(v) == "boolean" then return v end
        if v == "true" then return true elseif v == "false" then return false end
        return nil
    elseif t == "number" then
        local n = tonumber(v)
        if not n then return nil end
        if (def.min and n < def.min) or (def.max and n > def.max) then return nil end
        return n
    elseif t == "enum" then
        v = tostring(v)
        for _, x in ipairs(def.values or {}) do if x == v then return v end end
        return nil
    elseif t == "color" then
        v = tostring(v)
        if v:match("^#%x%x%x%x%x%x$") then return v:lower() end
        return nil
    elseif t == "string" then
        v = tostring(v)
        if v:find("[\r\n]") then return nil end
        return v
    end
    return nil
end

function C.get(key)
    local v = C.values[key]
    if v ~= nil then return v end
    local def = C.schema[key]
    return def and def.default
end

-- Returns true if the value is valid. Saves and notifies only when it changes.
-- Optional keys (opts.optional): nil or "" clear the value (back to the default).
function C.set(key, v, noSave)
    local def = C.schema[key]
    if not def then return false end
    local val
    if def.optional and (v == nil or v == "") then
        if C.values[key] == nil then return true end
    else
        val = C.validate(def, v)
        if val == nil then return false end
        if C.get(key) == val then return true end
    end
    C.values[key] = val
    if not noSave then C.save() end
    RSK.Bus.emit("ConfigChanged", key, val)
    return true
end

-- Resets one key, a list of keys or, with no argument, all of them (RF-5.9). Saves once.
function C.reset(key)
    local keys = type(key) == "table" and key or (key and { key } or C.order)
    for _, k in ipairs(keys) do
        if C.schema[k] then C.values[k] = nil; RSK.Bus.emit("ConfigChanged", k, C.get(k)) end
    end
    C.save()
end

-- Pure: lines -> raw table key -> string.
function C.parse(lines)
    local raw = {}
    for _, line in ipairs(lines or {}) do
        local l = trim(line)
        if l ~= "" and l:sub(1, 1) ~= "#" then
            local k, v = l:match("^([^=]-)%s*=%s*(.*)$")
            if k and k ~= "" then raw[trim(k)] = v end
        end
    end
    return raw
end

local function fmt(v)
    if v == nil then return "" end
    if type(v) == "number" and v == math.floor(v) then return string.format("%d", v) end
    return tostring(v)
end

-- Pure: current state -> file lines (every defined key, for hand editing).
function C.serialize()
    local lines = { "# Project Inventory - impostazioni (modificabile a mano; valori non validi -> predefinito)",
        "version = " .. C.VERSION }
    for _, k in ipairs(C.order) do lines[#lines + 1] = k .. " = " .. fmt(C.get(k)) end
    local ex = {}
    for k in pairs(C.extra) do ex[#ex + 1] = k end
    table.sort(ex)
    for _, k in ipairs(ex) do lines[#lines + 1] = k .. " = " .. C.extra[k] end
    return lines
end

function C.apply(raw)
    C.values, C.extra = {}, {}
    for k, v in pairs(raw) do
        local def = C.schema[k]
        if def then
            C.values[k] = C.validate(def, v)
        elseif k ~= "version" then
            C.extra[k] = v
        end
    end
    C.fileVersion = tonumber(raw.version)
end

-- I/O replaceable in tests. Paths relative to Zomboid/Lua/.
C.io = C.io or {
    read = function(name)
        local r = getFileReader(name, false)
        if not r then return nil end
        local lines = {}
        local line = r:readLine()
        while line do lines[#lines + 1] = line; line = r:readLine() end
        r:close()
        return lines
    end,
    write = function(name, lines)
        local w = getFileWriter(name, true, false)
        if not w then return false end
        w:write(table.concat(lines, "\n") .. "\n")
        w:close()
        return true
    end,
}

function C.load()
    local ok, lines = pcall(C.io.read, C.FILE)
    C.apply(C.parse(ok and lines or {}))
    C.loaded = true
end

function C.save()
    local ok, err = pcall(C.io.write, C.FILE, C.serialize())
    if not ok then print("[RSK] impostazioni non salvate: " .. tostring(err)) end
    return ok and err ~= false
end
