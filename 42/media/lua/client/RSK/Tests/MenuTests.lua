-- RSK main menu tests (D-156, P3.4a): screens that exist before a game is loaded (new game, character
-- creation, options). Active only with -debug. Excluded from the Workshop build (D-41).
-- Run: "RSK: esegui test" button in the main menu (top left), or RSK.MenuTests.run() from the Lua console.
-- Results in console.txt: [RSK-TEST] ... and "RIEPILOGO MENU". No OnTick in the main menu: steps run on OnFETick.
if not isDebugEnabled() then return end

RSK = RSK or {}
RSK.MenuTests = RSK.MenuTests or {}
local M = RSK.MenuTests
local TIMEOUT = 1800 -- FE ticks for one test

local function log(s) print("[RSK-TEST] " .. s) end

M.list = {}
local function add(id, name, fn) M.list[#M.list + 1] = { id = id, name = name, fn = fn } end

-- ------------------------------------------------------------------ assertions (same style as RSK_Tests)
local function stop(kind, msg)
    M.stopKind, M.stopMsg = kind, tostring(msg)
    coroutine.yield()
end
local function fail(msg) stop("fail", msg) end
local function skip(msg) stop("skip", msg) end
local function eq(a, b, msg)
    if a ~= b then fail((msg or "valore") .. ": atteso " .. tostring(b) .. ", ottenuto " .. tostring(a)) end
end
local function waitFE(n) for _ = 1, n do coroutine.yield() end end

-- the vanilla main menu ignores clicks while its start delay runs
local function waitMenuReady()
    local ms = MainScreen and MainScreen.instance
    if not ms then skip("MainScreen assente") end
    local n = 0
    while ms.delay > 0 or ms.checkSavefileModal do
        n = n + 1
        if n > 600 then skip("menu principale non pronto") end
        coroutine.yield()
    end
    return ms
end

-- ------------------------------------------------------------------ feasibility checks
add("MENU-01", "i passi avanzano con OnFETick", function()
    local t0 = M.feTicks
    waitFE(30)
    eq(M.feTicks - t0 >= 30, true, "tick del menu")
end)

add("MENU-02", "Core RSK attivo nel menu principale", function()
    eq(RSK.Core ~= nil and RSK.Core.VERSION ~= nil, true, "RSK.Core")
end)

add("MENU-03", "Opzioni aperte e chiuse da Lua", function()
    local ms = waitMenuReady()
    MainScreen.onMenuItemMouseDownMainMenu(ms.optionsOption, 0, 0)
    waitFE(20)
    local opt = ms.mainOptions
    eq(opt ~= nil and opt:isVisible(), true, "pannello Opzioni visibile")
    opt:setVisible(false)
    ms.bottomPanel:setVisible(true)
    waitFE(10)
    eq(opt:isVisible(), false, "pannello Opzioni chiuso")
end)

-- ------------------------------------------------------------------ runner
function M.finish()
    local r = M.res
    log(string.format("RIEPILOGO MENU: %d ok, %d falliti, %d saltati", r.pass, r.fail, r.skip))
    M.running, M.co, M.cur = false, nil, nil
end

function M.next()
    M.idx = M.idx + 1
    local t = M.list[M.idx]
    if not t then return M.finish() end
    M.cur, M.ticks = t, 0
    M.co = coroutine.create(t.fn)
end

function M.run()
    if M.running then log("test del menu gia' in esecuzione"); return end
    M.running, M.idx = true, 0
    M.res = { pass = 0, fail = 0, skip = 0 }
    log("inizio menu: " .. #M.list .. " test")
    M.next()
end

local function outcome(kind, msg)
    local t = M.cur
    M.res[kind] = M.res[kind] + 1
    log((kind == "pass" and "PASS " or kind == "skip" and "SKIP " or "FAIL ") .. t.id .. " " .. t.name .. (msg and (": " .. msg) or ""))
    M.next()
end

M.feTicks = 0
local function onFETick()
    M.feTicks = M.feTicks + 1
    if not M.running or not M.co then return end
    M.ticks = M.ticks + 1
    if M.ticks > TIMEOUT then return outcome("fail", "tempo scaduto") end
    if coroutine.status(M.co) ~= "suspended" then
        return outcome("fail", "esecuzione interrotta (coroutine " .. coroutine.status(M.co) .. ")")
    end
    local ok, err = coroutine.resume(M.co)
    if ok and M.stopKind then
        local kind, msg = M.stopKind, M.stopMsg
        M.stopKind, M.stopMsg = nil, nil
        outcome(kind, msg)
    elseif not ok then
        outcome("fail", tostring(err))
    elseif coroutine.status(M.co) == "dead" then
        outcome("pass")
    end
end

-- debug-only button in the main menu, added once MainScreen exists
local function addButton()
    local ms = MainScreen and MainScreen.instance
    if not ms or M.button then return end
    local b = ISButton:new(10, 10, 140, 24, "RSK: esegui test", nil, function() M.run() end)
    b:initialise()
    ms:addChild(b)
    M.button = b
end

Events.OnFETick.Add(function()
    if not M.button then pcall(addButton) end
    onFETick()
end)
Events.OnMainMenuEnter.Add(function() M.button = nil end)
