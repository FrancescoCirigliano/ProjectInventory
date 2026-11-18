-- RSK.Pause - M8, P3.4: themed pause menu (D-148, RF-8.6, RF-8.9). Hooks on the vanilla MainScreen
-- (in-game instance only): Esc, entries, their handlers, sub-screens (options, mod list) stay vanilla.
-- Ours: dimmed world (bg 75%), title, character card, bottom bar built from the vanilla menu items
-- (other mods' items included, vanilla order); a click calls the vanilla handler of that item.
-- The vanilla logo, menu column, version, seed and side buttons are hidden while ours is shown.
-- Module off or in error: vanilla pause menu (D-44).
require "OptionScreens/MainScreen"
require "ISUI/ISUI3DModel"
require "Hotbar/ISHotbar"
require "RSK/Core/Bootstrap"
require "RSK/UI/UI"
require "RSK/Pause/Logic"

RSK = RSK or {}
RSK.Pause = RSK.Pause or {}
local M = RSK.Pause
local L = M.Logic
local K, T = RSK.Core, RSK.Theme
local D = RSK.UI.Draw
local G = L.GEO
M.ID = "Pause"
M.stats = M.stats or { renders = 0, clicks = 0 }

local function px(n) return T.px(n) end

-- In-game pause menu open (any drawing: ours or vanilla).
function M.isShown()
    local ms = MainScreen and MainScreen.instance
    return ms ~= nil and ms.inGame == true and ms:getIsVisible()
end
local function tx(k, ...) return getText("UI_RSK_Pause_" .. k, ...) end
local OFFSCREEN = -100000

-- White masks from tools/icongen (status sizes): the closest size, tinted at draw time.
local ICON_SIZES = { 12, 13, 14, 15, 16, 17, 18, 20, 22, 24, 26, 28, 32 }
local iconCache = {}
local function icon(name, size)
    local best = ICON_SIZES[1]
    for _, s in ipairs(ICON_SIZES) do if math.abs(s - size) < math.abs(best - size) then best = s end end
    local key = name .. "_" .. best
    local t = iconCache[key]
    if t == nil then t = getTexture("media/ui/RSK/status/" .. key .. ".png") or false; iconCache[key] = t end
    return t or nil, best
end

-- Active mods for the panel (same checks as ISPauseModListUI).
local function modList()
    local out = {}
    local list = getActivatedMods()
    for i = 0, list:size() - 1 do
        local id = list:get(i)
        local info = getModInfoByID(id)
        local m = { id = id, found = info ~= nil }
        if info then
            m.available = info:isAvailable()
            m.name = info:getName()
            m.bugged = PauseBuggedModList ~= nil and PauseBuggedModList[m.name] ~= nil
        end
        out[#out + 1] = m
    end
    return out
end

-- ---------------------------------------------------------------- data
-- Menu items: vanilla labels of the bottom panel (and those of other mods), plus the mod list button.
function M.collect(ms)
    local items = {}
    for _, child in pairs(ms.bottomPanel:getChildren()) do
        if child.onMouseDown and (child.Type == "ISLabel" or child.Type == "ISButton") then
            local text = child.Type == "ISLabel" and child.name or child.title
            if child.internal == L.EXIT then text = tx("Exit") end -- says that the game is left (D-148)
            items[#items + 1] = { internal = child.internal, text = text, y = child:getY(),
                visible = child:getIsVisible(), el = child }
        end
    end
    local mods = ms.modListDetail
    if mods then
        items[#items + 1] = { internal = mods.internal, text = mods.title, y = math.huge, visible = true, el = mods, button = true }
    end
    return items
end

-- Click = the vanilla handler of the item.
function M.fire(e)
    M.stats.clicks = M.stats.clicks + 1
    local it = e.item
    local el = it.el
    local ms = MainScreen.instance
    if it.internal == "MODLISTDETAIL" and ms and ms.rskOverlay then -- themed mod list instead (D-162)
        ms.rskOverlay:toggleMods()
        return
    end
    if it.button or el.Type == "ISButton" then
        if el.onclick then el.onclick(el.target, el) end
    else
        el:onMouseDown(0, 0)
    end
end

local function cardData()
    local p = getPlayer()
    if not p then return nil end
    local d = p:getDescriptor()
    local gt = getGameTime()
    local month = getTextOrNull("Sandbox_StartMonth_option" .. (gt:getMonth() + 1)) or tostring(gt:getMonth() + 1)
    local info = getSaveInfo and getSaveInfo(getWorld():getWorld()) or nil
    local mode = getCore():getGameMode()
    local modeText = getTextOrNull("IGUI_Gametime_" .. tostring(mode)) or tostring(mode)
    local city = L.cityText(info and info.mapName or "")
    return {
        name = d:getForename() .. " " .. d:getSurname(),
        place = city ~= "" and (city .. " \194\183 " .. modeText) or modeText,
        date = L.dateText(gt:getDay() + 1, month, gt:getTimeOfDay(), tx("Date"), tx("DateLower") == "1"),
        survived = L.survivedText(p:getHoursSurvived(), tx("Survived")),
        kills = tostring(p:getZombieKills()),
    }
end

-- ---------------------------------------------------------------- overlay
local O = ISUIElement:derive("RSK_PauseOverlay")
M.Overlay = O

-- ghost = exit copy: a 1x1 element at the screen origin, always on top, that does not catch the mouse
-- and draws the whole screen in absolute coordinates while it fades out (the game is already running).
function O:new(ms, ghost)
    local o = ISUIElement.new(self, 0, 0, ghost and 1 or ms.width, ghost and 1 or ms.height)
    o.ms = ms
    o.ghost = ghost
    if not ghost then o.anchorRight, o.anchorBottom = true, true end
    o.hits = {}
    return o
end

-- Drawing area: the screen for the ghost, the element otherwise.
function O:viewW() return self.ghost and getCore():getScreenWidth() or self.width end
function O:viewH() return self.ghost and getCore():getScreenHeight() or self.height end

function O:createChildren()
    if self.ghost then return end
    self:setWantKeyEvents(true) -- Esc / Enter of the quit confirmation (D-164)
    local m = ISUI3DModel:new(0, 0, 10, 10)
    m:initialise()
    m:instantiate()
    m:setState("idle")
    m:setDirection(IsoDirections.S)
    m:setIsometric(false)
    m:setZoom(16)
    m:setYOffset(-0.8)
    self:addChild(m)
    self.model = m
end

-- Called when the menu shows: data and fade restart.
function O:opened()
    self.shownAt = getTimestampMs()
    self.confirm = nil
    self.mods = nil
    self.card = cardData()
    local p = getPlayer()
    if p then self.model:setCharacter(p) end
end

function O:toggleMods()
    if self.mods then self.mods = nil; return end
    local rows, errors = L.modRows(modList())
    self.mods = { rows = rows, errors = errors, scroll = 0 }
end

-- ---------------------------------------------------------------- quit to desktop confirmation (D-164)
function O:openConfirm()
    self.confirm = { shownAt = getTimestampMs() }
    self.hover, self.pressed = nil, nil
end

-- Answer: the vanilla handler with YES / NO; on NO the box fades out over the pause.
function O:answer(yes)
    local c = self.confirm
    if not c or c.closingAt then return end
    M.stats.confirms = (M.stats.confirms or 0) + 1
    if yes then
        self.confirm = nil
        MainScreen.onConfirmQuitToDesktop(self.ms, { internal = "YES" })
        return
    end
    c.closingAt = getTimestampMs()
    MainScreen.onConfirmQuitToDesktop(self.ms, { internal = "NO" })
end

local function isMenuKey(key)
    return key == Keyboard.KEY_ESCAPE or getCore():isKey(KeybindId.MAIN_MENU, key)
end

-- While the confirmation is open Esc cancels it (instead of closing the pause) and Enter confirms.
function O:isKeyConsumed(key)
    local c = self.confirm
    return c ~= nil and not c.closingAt and (isMenuKey(key) or key == Keyboard.KEY_RETURN)
end

function O:onKeyRelease(key)
    local c = self.confirm
    if not c or c.closingAt then return end
    if key == Keyboard.KEY_RETURN then self:answer(true) elseif isMenuKey(key) then self:answer(false) end
end

function O:drawConfirm()
    local c = self.confirm
    if not c then return end
    local now = getTimestampMs()
    local a, dy, done = L.confirmMotion(now - c.shownAt, c.closingAt and (now - c.closingAt) or nil)
    if done then self.confirm = nil; return end
    local C = L.CONFIRM
    local s = T.scale()
    local W, H = self:viewW(), self:viewH()
    D.fill(self, 0, 0, W, H, "bg", C.dim * a)
    self.hits = {} -- the pause behind is inactive
    local cancelT, okT = getText("UI_Cancel"), tx("QuitConfirm")
    local iconU, iconGap = 18, 8
    local b = L.confirmBox(W / s, H / s, D.measure("button", cancelT) / s, D.measure("button", okT) / s, iconU + iconGap)
    local off = px(dy)
    local x, y, w, h = px(b.x), px(b.y) + off, px(b.w), px(b.h)
    D.fill(self, x, y, w, h, "panel", a)
    D.border(self, x, y, w, h, "line", a)
    local pad = px(C.pad)
    local is = px(C.icon)
    local titleMid = y + pad + px(C.titleH) / 2
    local tex = icon("exit", is)
    if tex then D.texture(self, tex, x + pad, titleMid - is / 2, is, is, "danger", a) end
    local tx0 = x + pad + is + px(10)
    D.textMid(self, getText("IGUI_ConfirmQuitToDesktop"), tx0, titleMid, "windowTitle", "text", a, "left", x + w - pad - tx0)
    D.text(self, tx("QuitNote"), x + pad, y + pad + px(C.titleH + C.gap), "tipText", "muted", a, "left", w - 2 * pad)
    local function btn(r, text, kind, yes)
        local bx, by, bw, bh = px(r.x), px(r.y) + off, px(r.w), px(r.h)
        local hit = { el = kind, enabled = true, action = function() self:answer(yes) end, x = bx, y = by, w = bw, h = bh }
        local over = self.hover and self.hover.el == kind
        if kind == "ok" then
            D.fill(self, bx, by, bw, bh, "danger", a)
            if over then D.border(self, bx, by, bw, bh, "text", a) end
            local ii = px(iconU)
            local tw = D.measure("button", text)
            local x0 = bx + math.floor((bw - ii - px(iconGap) - tw) / 2)
            local t2 = icon("exit", ii)
            if t2 then D.texture(self, t2, x0, by + math.floor((bh - ii) / 2), ii, ii, "ink", a) end
            D.textMid(self, text, x0 + ii + px(iconGap), by + bh / 2, "button", "ink", a)
        else
            D.fill(self, bx, by, bw, bh, over and "sel" or "panel2", a)
            D.border(self, bx, by, bw, bh, over and "accent" or "line", a)
            D.textMid(self, text, bx + bw / 2, by + bh / 2, "button", "text", a, "center")
        end
        if not c.closingAt then self.hits[#self.hits + 1] = hit end
    end
    btn(b.cancel, cancelT, "cancel", false)
    btn(b.ok, okT, "ok", true)
    D.text(self, tx("QuitKeys"), x + w - pad, px(b.hintY) + off, "tipSub", "muted", a, "right")
    if self.hover then self.hover = self:hitAt(self:getMouseX(), self:getMouseY()) end
end

function O:onMouseWheel(del)
    local m = self.mods
    if not m or not m.rect then return false end
    local r = m.rect
    local mx, my = self:getMouseX(), self:getMouseY()
    if mx < r.x or mx >= r.x + r.w or my < r.y or my >= r.y + r.h then return false end
    m.scroll = math.max(0, math.min(m.maxScroll or 0, m.scroll + del * L.MODS.row))
    return true
end

function O:hitAt(x, y)
    for _, h in ipairs(self.hits) do
        if x >= h.x and x < h.x + h.w and y >= h.y and y < h.y + h.h then return h end
    end
    return nil
end

function O:onMouseMove()
    local h = self:hitAt(self:getMouseX(), self:getMouseY())
    if h ~= self.hover then
        self.hover = h
        if h and h.enabled then getSoundManager():playUISound("UIHighlightMainMenuItem") end
    end
end
function O:onMouseMoveOutside() self.hover = nil end

function O:onMouseDown(x, y)
    local h = self:hitAt(x, y)
    if h and h.enabled then self.pressed = h end
    return true
end

function O:onMouseUp(x, y)
    local h, p = self:hitAt(x, y), self.pressed
    self.pressed = nil
    if h and p and h.el == p.el and h.enabled then
        if h.action then h.action() else M.fire(h.entry) end
    end
    return true
end

local function button(self, a, x, y, w, h, text, textW, style, hit, iconName)
    local over = (self.hover and self.hover.el == hit.el) or hit.active
    local en = hit.enabled
    local al = a * (en and 1 or T.alpha.disabled)
    local fill, border, ink
    if style == "primary" then
        fill, border, ink = "accent", (over and en) and "text" or "accent", "ink"
    elseif style == "quit" then
        fill, border, ink = nil, (over and en) and "danger" or "line", (over and en) and "danger" or "muted"
        if over and en then D.fill(self, x, y, w, h, "danger", al * 0.12) end
    else
        fill, border, ink = (over and en) and "sel" or "panel2", (over and en) and "accent" or "line", "text"
    end
    if fill then D.fill(self, x, y, w, h, fill, al) end
    D.border(self, x, y, w, h, border, al)
    if iconName then -- icon 18 + gap 8 before the text, centred together (D-162)
        local is, ig = px(18), px(8)
        local tw = math.min(D.measure("menuButton", text), textW - is - ig)
        local x0 = x + math.floor((w - is - ig - tw) / 2)
        local tex = icon(iconName, is)
        if tex then D.texture(self, tex, x0, y + math.floor((h - is) / 2), is, is, ink, al) end
        D.textMid(self, text, x0 + is + ig, y + h / 2, "menuButton", ink, al, "left", tw + 2)
    else
        D.textMid(self, text, x + w / 2, y + h / 2, "menuButton", ink, al, "center", textW + 2)
    end
    hit.x, hit.y, hit.w, hit.h = x, y, w, h
    self.hits[#self.hits + 1] = hit
end

function O:drawCard(a, dx)
    local c = self.card
    if not c then return end
    local x, y, w = px(G.titleX) + dx, px(G.cardY), px(G.cardW)
    local pad, gap, pr = px(G.cardPad), px(G.cardGap), px(G.portrait)
    local h = pad * 2 + pr + gap + px(G.statH)
    D.fill(self, x, y, w, h, "bg", a)
    D.border(self, x, y, w, h, "line", a)
    D.fill(self, x + pad, y + pad, pr, pr, "panel2", a)
    D.border(self, x + pad, y + pad, pr, pr, "line", a)
    local m = self.model
    if m then m:setX(x + pad + 1); m:setY(y + pad + 1); m:setWidth(pr - 2); m:setHeight(pr - 2) end
    local tx0, tw = x + pad + pr + gap, w - pad * 3 - pr
    local lh = D.lineHeight("number")
    local sh = D.lineHeight("tipText")
    local ty = y + pad + math.floor((pr - lh - 2 * sh - px(4)) / 2)
    D.text(self, c.name, tx0, ty, "number", "text", a, "left", tw)
    D.text(self, c.place, tx0, ty + lh + px(2), "tipText", "muted", a, "left", tw)
    D.text(self, c.date, tx0, ty + lh + sh + px(4), "tipText", "muted", a, "left", tw)
    local sy, sg = y + pad + pr + gap, px(G.statGap)
    local cw = math.floor((w - pad * 2 - sg) / 2)
    local stats = { { tx("Survived_Label"), c.survived }, { getText("IGUI_char_Zombies_Killed"), c.kills } }
    for i, s in ipairs(stats) do
        local sx = x + pad + (i - 1) * (cw + sg)
        D.fill(self, sx, sy, cw, px(G.statH), "panel", a)
        local bh, vh = D.lineHeight("badge"), D.lineHeight("invTitle")
        local by = sy + math.floor((px(G.statH) - bh - vh) / 2)
        D.text(self, s[1], sx + px(10), by, "badge", "muted", a, "left", cw - px(20))
        D.text(self, s[2], sx + px(10), by + bh, "invTitle", "text", a, "left", cw - px(20))
    end
end

function O:drawBar(a, dy)
    local ms = self.ms
    local W, H = self:viewW(), self:viewH()
    local barH = px(G.barH)
    self.modsBtn = nil
    local top = H - barH + dy
    D.fill(self, 0, top, W, barH, "bg", a)
    D.fill(self, 0, top, W, 1, "line", a)
    -- version column: vanilla version and seed texts, then the mod version; as wide as its texts
    local lines = {}
    lines[1] = ms.versionBtn and ms.versionBtn.title or ("Build " .. tostring(getCore():getVersion()))
    if ms.seedLabel and ms.seedLabel.name and ms.seedLabel.name ~= "" then lines[#lines + 1] = ms.seedLabel.name end
    lines[#lines + 1] = "RSK " .. tostring(K.VERSION)
    local lh = D.lineHeight("tipSub")
    local vy = top + math.floor((barH - lh * (#lines + 1)) / 2)
    local verW = 0
    for i, s in ipairs(lines) do
        verW = math.max(verW, D.text(self, s, px(G.barPad), vy + (i - 1) * lh, "tipSub", "muted", a))
    end
    -- "Report a bug": vanilla handler (D-162)
    local bugText = tx("ReportBug")
    local is, lx, ly = px(12), px(G.barPad), vy + #lines * lh
    local bugHit = { el = "reportBug", enabled = true, action = function() MainScreen.onClickReportBug(ms) end }
    local bugOver = self.hover and self.hover.el == "reportBug"
    local tok = bugOver and "accent" or "muted"
    local bw = D.text(self, bugText, lx, ly, "tipSub", tok, a)
    local tex = icon("link", is)
    if tex then D.texture(self, tex, lx + bw + px(4), ly + math.floor((lh - is) / 2), is, is, tok, a) end
    if bugOver then D.fill(self, lx, ly + lh - 1, bw, 1, "accent", a) end
    bugHit.x, bugHit.y, bugHit.w, bugHit.h = lx, ly, bw + px(4) + is, lh
    self.hits[#self.hits + 1] = bugHit
    verW = math.max(verW, bw + px(4) + is)
    local center, quit = L.entries(M.collect(ms))
    local cooldown = isQuitCooldown and isQuitCooldown() or false
    local widths = {}
    local s = T.scale()
    for i, e in ipairs(center) do widths[i] = D.measure("menuButton", e.text) / s end
    local lay = L.bar(W / s, widths, quit ~= nil, verW / s)
    local by = top + math.floor((barH - px(G.btnH)) / 2)
    for i, e in ipairs(center) do
        local b = lay.buttons[i]
        local isMods = e.internal == "MODLISTDETAIL"
        button(self, a, px(b.x), by, px(b.w), px(G.btnH), e.text, px(b.textW), e.primary and "primary" or "normal",
            { entry = e, el = e.item.el, enabled = L.enabled(e.internal, cooldown), active = isMods and self.mods ~= nil })
        if isMods then self.modsBtn = { x = px(b.x), w = px(b.w), top = top } end
    end
    if quit then
        local qw = px(G.quitW)
        button(self, a, W - px(G.barPad) - qw, by, qw, px(G.btnH), quit.text, qw - px(16), "quit",
            { entry = quit, el = quit.item.el, enabled = L.enabled(quit.internal, cooldown) }, "exit")
    end
    -- keep the hover on the rebuilt hit list
    if self.hover then self.hover = self:hitAt(self:getMouseX(), self:getMouseY()) end
end

local STATE_KEY = { missing = "ModMissing", unavailable = "ModUnavailable" }

function O:drawMods(a)
    local m, btn = self.mods, self.modsBtn
    if not m or not btn then return end
    local s = T.scale()
    local x, y, w, h, maxScroll = L.modPanel(btn.x / s, btn.w / s, self:viewW() / s, btn.top / s, #m.rows)
    local MS = L.MODS
    x, y, w, h = px(x), px(y), px(w), px(h)
    m.rect = { x = x, y = y, w = w, h = h }
    m.maxScroll = maxScroll
    m.scroll = math.min(m.scroll, maxScroll)
    D.fill(self, x, y, w, h, "panel", a)
    D.border(self, x, y, w, h, "line", a)
    local pad, headH = px(MS.pad), px(MS.head)
    D.textMid(self, tx("Mods", #m.rows), x + pad, y + headH / 2, "label", "muted", a)
    if m.errors > 0 then D.textMid(self, tx("ModErrors", m.errors), x + w - pad, y + headH / 2, "label", "danger", a, "right") end
    D.fill(self, x, y + headH, w, 1, "line", a)
    local listY, rowH = y + headH + 1, px(MS.row)
    self:setStencilRect(x + 1, listY, w - 2, h - headH - 2)
    local mx, my = self:getMouseX(), self:getMouseY()
    for i, r in ipairs(m.rows) do
        local ry = listY + (i - 1) * rowH - px(m.scroll)
        if ry + rowH > listY and ry < y + h then
            if mx >= x and mx < x + w and my >= ry and my < ry + rowH and my >= listY then D.fill(self, x + 1, ry, w - 2, rowH, "sel", a) end
            local cy = ry + rowH / 2
            D.textMid(self, tostring(r.n), x + pad, cy, "tipText", "muted", a)
            local nx, right = x + pad + px(MS.numW), x + w - pad
            if r.state == "errors" then
                local t = getText("UI_RSK_Pause_ModBadge")
                local bw = D.measure("badge", t) + px(12)
                local bh = D.lineHeight("badge") + px(2)
                D.border(self, right - bw, cy - bh / 2, bw, bh, "danger", a)
                D.textMid(self, t, right - bw / 2, cy, "badge", "danger", a, "center")
                right = right - bw - px(8)
            elseif STATE_KEY[r.state] then
                right = right - D.textMid(self, tx(STATE_KEY[r.state]), right, cy, "tipText", "warn", a, "right") - px(8)
            end
            D.textMid(self, r.name, nx, cy, "rowSmall", (r.state == "ok" or r.state == "errors") and "text" or "muted", a, "left", right - nx)
        end
    end
    self:clearStencilRect()
end

function O:prerender()
    M.stats.renders = M.stats.renders + 1
    local now = getTimestampMs()
    local a, dy, dx, done = L.motion(now - (self.shownAt or 0), self.ghost and (now - self.closedAt) or nil)
    if done then
        self.finished = true
        return
    end
    self.hits = {}
    -- open: with the vanilla 50% below = 75%; ghost: the vanilla dim is gone, all 75% here
    D.fill(self, 0, 0, self:viewW(), self:viewH(), "bg", (self.ghost and 0.75 or 0.5) * a)
    dx, dy = px(dx), px(dy)
    local x, y = px(G.titleX) + dx, px(G.titleY)
    D.text(self, tx("Title"), x, y, "menuTitle", "text", a)
    D.text(self, tx("Sub"), x, y + D.lineHeight("menuTitle") + px(G.subGap), "body", "muted", a)
    self:drawCard(a, dx)
    self:drawBar(a, dy)
    self:drawMods(a)
    self:drawConfirm()
end

-- Ghost: removed once faded out.
function O:update()
    if self.finished and self.ghost then
        self:removeFromUIManager()
        if M.ghost == self then M.ghost = nil end
    end
end

-- ---------------------------------------------------------------- vanilla parts hidden while ours is shown
local SIDE = { "versionBtn", "seedLabel", "reportBug", "modListDetail" }

-- ISHotbar:update shows the hotbar again while the moodles are visible, also during the pause.
local function hideHotbar(ms)
    local hb = getPlayerHotbar and getPlayerHotbar(0)
    if hb and hb:getIsVisible() then hb:setVisible(false); ms.rskHotbar = hb end
end

local function showHotbar(ms)
    if ms.rskHotbar then ms.rskHotbar:setVisible(true); ms.rskHotbar = nil end
end
M.showHotbar = showHotbar

local function hideVanilla(ms)
    hideHotbar(ms)
    local bp = ms.bottomPanel
    if bp:getY() ~= OFFSCREEN then
        ms.rskPanelY = bp:getY()
        bp:setY(OFFSCREEN)
    end
    for _, k in ipairs(SIDE) do
        local el = ms[k]
        if el and el:getIsVisible() then el:setVisible(false); ms.rskSide = ms.rskSide or {}; ms.rskSide[k] = true end
    end
end

function M.restore(ms)
    local ov = ms.rskOverlay
    if ov and ov:getIsVisible() then ov:setVisible(false) end
    if ms.rskPanelY then ms.bottomPanel:setY(ms.rskPanelY); ms.rskPanelY = nil end
    if ms.rskSide then
        for k in pairs(ms.rskSide) do if ms[k] then ms[k]:setVisible(true) end end
        ms.rskSide = nil
    end
end

-- Closing the pause: vanilla parts back in place and the hotbar visible again (vanilla restores the rest).
function M.closed(ms)
    local ov = ms.rskOverlay
    local wasShown = ov ~= nil and ov:getIsVisible() and ov.lastFrame ~= nil
    M.restore(ms)
    showHotbar(ms)
    if ov then ov.lastFrame = nil end
    if wasShown and K.isActive(M.ID) then M.fadeOut(ms, ov) end
end

-- Exit effect: a ghost of the menu fades out over the running game (same card, bar and mod panel).
function M.fadeOut(ms, ov)
    if M.ghost then M.ghost:removeFromUIManager(); M.ghost = nil end
    local g = O:new(ms, true)
    g:initialise()
    g:instantiate()
    g.card, g.mods, g.shownAt, g.closedAt = ov.card, ov.mods, 0, getTimestampMs()
    g.prerender = K.guard(M.ID, O.prerender)
    g:addToUIManager()
    g:setAlwaysOnTop(true)
    M.ghost = g
end

function M.apply(ms)
    hideVanilla(ms)
    local ov = ms.rskOverlay
    if not ov then
        ov = O:new(ms)
        ov:initialise()
        ov:instantiate()
        ms:addChild(ov)
        ms.rskOverlay = ov
    end
    if ov.width ~= ms.width or ov.height ~= ms.height then ov:setWidth(ms.width); ov:setHeight(ms.height) end
    local now = getTimestampMs()
    if not ov:getIsVisible() or not ov.lastFrame or now - ov.lastFrame > 250 then
        if M.ghost then M.ghost:removeFromUIManager(); M.ghost = nil end -- reopened while fading out
        ov:setVisible(true)
        ov:opened()
    end
    ov.lastFrame = now
end
local gApply = K.guard(M.ID, M.apply)

-- ---------------------------------------------------------------- hooks
M.orig = M.orig or {}
local OR = M.orig
local W = {}

local function ours(ms)
    return ms.inGame and K.isActive(M.ID) and ms.bottomPanel ~= nil and ms.bottomPanel:getIsVisible()
end

function W.prerender(self)
    if not ours(self) then
        if self.rskOverlay or self.rskPanelY or self.rskSide then M.restore(self) end
        return OR.prerender(self)
    end
    -- vanilla logo fully faded, vanilla dim in our bg colour (the panel background stays off)
    self.warningFade = self.warningFadeMax
    local saved = self.backgroundColor
    local c = T.color("bg")
    self.backgroundColor = { r = c.r, g = c.g, b = c.b, a = 0 }
    local ok, err = pcall(OR.prerender, self)
    self.backgroundColor = saved
    if not ok then error(err, 0) end
    gApply(self)
end

-- "Quit to desktop" asks with our confirmation while our pause is shown (D-164).
-- Vanilla calls it on the class (MainScreen:quitToDesktopFunc()): the instance is MainScreen.instance.
function W.quitToDesktopFunc(self)
    local ms = MainScreen.instance
    local ov = ms and ms.rskOverlay
    if ms and ms.inGame and ours(ms) and ov and ov:getIsVisible() then
        ov:openConfirm()
        return
    end
    return OR.quitToDesktopFunc(self)
end

function W.onReturnToGame(self)
    OR.onReturnToGame(self)
    if self.inGame then pcall(M.closed, self) end
end

-- Vanilla render shows the version button again on every frame.
function W.render(self)
    OR.render(self)
    if ours(self) and self.versionBtn then self.versionBtn:setVisible(false) end
end

-- ISHotbar:update shows the item tooltip of the slot under the mouse even while the hotbar is hidden:
-- under the pause bar it popped up over our buttons. Hidden while the pause is open.
local function hotbarUpdate(self)
    OR.hotbarUpdate(self)
    if self.toolRender and K.isActive(M.ID) and M.isShown() then self.toolRender:setVisible(false) end
end
M.wrapHotbarUpdate = hotbarUpdate

function M.installHook()
    if ISHotbar and rawget(ISHotbar, "update") ~= hotbarUpdate then
        OR.hotbarUpdate = ISHotbar.update
        rawset(ISHotbar, "update", hotbarUpdate)
    end
    if not MainScreen then return false end
    for name, fn in pairs(W) do
        if rawget(MainScreen, name) ~= fn then
            OR[name] = MainScreen[name]
            rawset(MainScreen, name, fn)
        end
    end
    return rawget(MainScreen, "prerender") == W.prerender
end
M.wrapPrerender = W.prerender

M.moduleDef = K.register{
    id = M.ID, when = "game", requires = { "UI" },
    start = function()
        K.log("Pause: menu di pausa a tema, aggancio " .. tostring(M.installHook()))
    end,
    stop = function()
        local ms = MainScreen and MainScreen.instance
        if ms and ms.inGame then pcall(M.restore, ms); pcall(showHotbar, ms) end
    end,
}
