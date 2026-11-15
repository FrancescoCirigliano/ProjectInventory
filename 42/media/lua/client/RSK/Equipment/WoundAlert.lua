-- RSK.Equipment.WoundAlert - M2: warning when the character gets hurt (D-117).
-- OnPlayerGetDamage (at most one check every CHECK_MS) compares wounds with the last snapshot: for each
-- part with new wounds a card appears left of the character inventory, slides in, stays
-- LIFE_MS (paused while hovered), closes with the X; click on the card = M2 window on the first tab.
require "ISUI/ISUIElement"
require "RSK/UI/UI"
require "RSK/Equipment/Logic"

local T, D, UL = RSK.Theme, RSK.UI.Draw, RSK.UI.Logic
local Q = RSK.Equipment
local L = Q.Logic
local A = L.ALERT
Q.WoundAlert = Q.WoundAlert or {}
local WA = Q.WoundAlert
WA.cards = WA.cards or {}

local function px(n) return T.px(n) end

local triTex, bangTex
local function tri()
    if triTex == nil then triTex = getTexture("media/ui/RSK/wound_triangle.png") or false end
    return triTex or nil
end
local function bang()
    if bangTex == nil then bangTex = getTexture("media/ui/RSK/wound_bang.png") or false end
    return bangTex or nil
end

-- ---------------------------------------------------------------- snapshots
local function flagsOf(player)
    local out, parts = {}, {}
    local list = player:getBodyDamage():getBodyParts()
    for i = 1, list:size() do
        local bp = list:get(i - 1)
        local name = BodyPartType.ToString(bp:getType())
        parts[#parts + 1] = name
        out[name] = L.injuryFlags({
            bitten = bp:bitten(), deep = bp:deepWounded(), fractureTime = bp:getFractureTime(),
            burnTime = bp:getBurnTime(), bullet = bp:haveBullet(), glass = bp:haveGlass(),
            bleeding = bp:bleeding(), cut = bp:isCut(), scratched = bp:scratched(),
        })
        out[name].display = BodyPartType.getDisplayName(bp:getType())
    end
    return out, parts
end

-- Starting snapshot with no warnings (wounds already present at startup or on load).
function WA.reset(player)
    WA.snap = nil
    if player then WA.snap = flagsOf(player) end
end

-- ---------------------------------------------------------------- card
local Card = ISUIElement:derive("RSK_WoundAlert")
WA.Card = Card

function Card:new(alert)
    local o = ISUIElement.new(self, 0, 0, px(A.W), 10)
    o.alert = alert
    o.elapsed = 0
    o.last = getTimestampMs()
    return o
end

function Card:layoutHeight()
    local pad = px(A.PAD)
    local inner = D.lineHeight("itemName") + px(2) + D.lineHeight("rowSmall")
    return pad + math.max(px(A.ICON_H), inner) + pad + px(A.BAR)
end

function Card:closeRect()
    local s = px(A.CLOSE)
    return self.width - px(A.PAD) / 2 - s, px(A.PAD) / 2, s
end

function Card:overClose()
    local x, y, s = self:closeRect()
    local mx, my = self:getMouseX(), self:getMouseY()
    return mx >= x and mx <= x + s and my >= y and my <= y + s
end

function Card:update()
    local now = getTimestampMs()
    local dt = now - self.last
    self.last = now
    -- Paused while hovered (after sliding in): the card does not vanish while being read.
    if not (self:isMouseOver() and self.elapsed >= A.IN_MS and not self.closingAt) then self.elapsed = self.elapsed + dt end
    local _, _, _, done = L.alertState(self.elapsed, self.closingAt)
    if done then WA.remove(self) end
end

function Card:render()
    local alpha, dx, life = L.alertState(self.elapsed, self.closingAt)
    if alpha <= 0 then return end
    local a, tok = self.alert, self.alert.tok
    local w, h, pad = self.width, self.height, px(A.PAD)
    D.fill(self, dx, 0, w, h, "panel", alpha)
    D.border(self, dx, 0, w, h, tok, alpha)
    if self:isMouseOver() and not self:overClose() then D.fill(self, dx + 1, 1, w - 2, h - 2, "hover", alpha) end
    -- triangle with exclamation mark, like the markers on the M2 render (D-84)
    local iw, ih = px(A.ICON_W), px(A.ICON_H)
    local iy = pad
    D.texture(self, tri(), dx + pad, iy, iw, ih, tok, alpha)
    D.texture(self, bang(), dx + pad, iy, iw, ih, "ink", alpha)
    -- text: body part and new wounds
    local tx0 = dx + pad + iw + px(A.GAP)
    local cs = px(A.CLOSE)
    local tw = w - (tx0 - dx) - pad - cs
    local nh = D.lineHeight("itemName")
    D.text(self, a.part, tx0, pad, "itemName", "text", alpha, "left", tw)
    D.text(self, a.text, tx0, pad + nh + px(2), "rowSmall", "muted", alpha, "left", tw + cs)
    -- close
    local cx, cy, s = self:closeRect()
    local hoverClose = self:overClose()
    if hoverClose then D.fill(self, dx + cx, cy, s, s, "sel", alpha) end
    local is = px(12)
    D.texture(self, D.icon("close"), dx + cx + (s - is) / 2, cy + (s - is) / 2, is, is, hoverClose and "text" or "muted", alpha)
    -- remaining life
    local bh = px(A.BAR)
    D.fill(self, dx, h - bh, w, bh, "text", 0.08 * alpha)
    if life > 0 then D.fill(self, dx, h - bh, math.floor(w * life + 0.5), bh, tok, alpha) end
end

function Card:onMouseDown() return true end

function Card:onMouseUp()
    if self.closingAt then return true end
    if self:overClose() then
        self.closingAt = self.elapsed
        return true
    end
    -- Opens M2 on the first tab (same path as the inventory button, D-91).
    local cw = getPlayerInfoPanel(0)
    if cw and not Q.isOpen(0) then cw:toggleView(xpSystemText.health) end
    self.closingAt = self.elapsed
    return true
end

-- ---------------------------------------------------------------- card stack
-- Left of the character inventory, from the top; if there is no room on the left, inside the screen.
function WA.arrange()
    local inv = getPlayerInventory(0)
    if not inv then return end
    local gap = px(A.GAP)
    local y = inv:getY()
    for _, c in ipairs(WA.cards) do
        local x = inv:getX() - c.width - gap
        if x < 0 then x = 0 end
        c:setX(x); c:setY(y)
        y = y + c.height + gap
    end
end

function WA.remove(card)
    for i, c in ipairs(WA.cards) do
        if c == card then
            table.remove(WA.cards, i)
            break
        end
    end
    card:removeFromUIManager()
    WA.arrange()
end

function WA.clear()
    for _, c in ipairs(WA.cards) do c:removeFromUIManager() end
    WA.cards = {}
end

local function show(alert)
    -- same part already on screen: updated and restarted
    for _, c in ipairs(WA.cards) do
        if c.alert.partName == alert.partName and not c.closingAt then
            c.alert = alert
            c.elapsed = A.IN_MS
            return
        end
    end
    while #WA.cards >= A.MAX do WA.remove(WA.cards[1]) end
    local c = Card:new(alert)
    c:initialise()
    c:instantiate()
    c:setHeight(c:layoutHeight())
    c:addToUIManager()
    c:setAlwaysOnTop(true)
    WA.cards[#WA.cards + 1] = c
    WA.arrange()
end

-- ---------------------------------------------------------------- check
function WA.check(player)
    local cur, parts = flagsOf(player)
    local prev = WA.snap or cur
    WA.snap = cur
    for _, n in ipairs(L.newInjuries(prev, cur, parts)) do
        local texts = {}
        for i, line in ipairs(n.lines) do texts[i] = getText(line.key) end
        show({ partName = n.part, part = cur[n.part].display, text = table.concat(texts, " \194\183 "), tok = n.tok })
    end
end

-- At most one check every CHECK_MS: damage arriving earlier is checked when it expires (one-off OnTick,
-- removed right after: no per-frame check).
local pendingTick
function WA.onDamage(player)
    local now = getTimestampMs()
    local wait = (WA.lastCheck or 0) + A.CHECK_MS - now
    if wait <= 0 then
        WA.lastCheck = now
        WA.check(player)
        return
    end
    if pendingTick then return end
    pendingTick = function()
        if getTimestampMs() < (WA.lastCheck or 0) + A.CHECK_MS then return end
        Events.OnTick.Remove(pendingTick)
        pendingTick = nil
        WA.lastCheck = getTimestampMs()
        local p = getSpecificPlayer(0)
        if p and not p:isDead() then WA.check(p) end
    end
    Events.OnTick.Add(pendingTick)
end

function WA.stop()
    if pendingTick then
        Events.OnTick.Remove(pendingTick)
        pendingTick = nil
    end
    WA.clear()
    WA.snap = nil
end
