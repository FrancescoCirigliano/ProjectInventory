-- RSK.Equipment.Protection - M2, P3.4: themed Protection tab (D-147, RF-2.8). Tests T-34, T-44.
-- Same data as ISCharacterProtection (getBodyPartClothingDefense), vanilla ISBodyPartPanel silhouette textures
-- tinted with the theme. The vanilla panel stays untouched in its window.
require "RSK/UI/UI"
require "RSK/Equipment/Logic"

local T, D, UI = RSK.Theme, RSK.UI.Draw, RSK.UI
local Q = RSK.Equipment
local L = Q.Logic
local P = L.PROT

local function px(n) return T.px(n) end

local Pr = UI.Panel:derive("RSK_EquipProtection")
Q.Protection = Pr

function Pr:new(x, y, w, h, win)
    local o = UI.Panel.new(self, x, y, w, h, { bg = false, border = false })
    o.win = win
    o.rows = {}
    return o
end

-- Textures and hit boxes as ISBodyPartPanel (texture offsets, z of chest, abdomen, groin).
function Pr:loadBody()
    local player = getSpecificPlayer(self.win.playerNum)
    local female = player:isFemale()
    local sex = female and "female" or "male"
    self.female = female
    self.baseTex = getTexture("media/ui/BodyParts/" .. sex .. "_base_white")
    self.outlineTex = getTexture("media/ui/BodyParts/bps_" .. sex .. "_outlines")
    self.partTex, self.boxes = {}, {}
    for _, p in ipairs(L.PROT_PARTS) do
        local tex = getTexture("media/ui/BodyParts/bps_" .. sex .. "_" .. p[2])
        self.partTex[p[1]] = tex
        if tex then
            self.boxes[#self.boxes + 1] = { id = p[1], x = tex:getOffsetX(), y = tex:getOffsetY(),
                w = tex:getWidth(), h = tex:getHeight(), z = p[3] }
        end
    end
end

-- Columns sized on the headers and on "100%" (in units).
function Pr:measureCols()
    local s = T.scale()
    local num = D.measure("infoText", "100%")
    self.biteNeed = math.max(D.measure("label", getText("IGUI_health_Bite")), num) / s
    self.scrNeed = math.max(D.measure("label", getText("IGUI_health_Scratch")), num) / s
end

function Pr:arrange()
    self:measureCols()
    self.lay = L.protLayout(self.bw, self.bh, #L.PROT_PARTS, self.biteNeed, self.scrNeed)
end

function Pr:refresh()
    local player = getSpecificPlayer(self.win.playerNum)
    if not player then return end
    if self.female ~= player:isFemale() or not self.boxes then self:loadBody() end
    local raw = {}
    for i, p in ipairs(L.PROT_PARTS) do
        local idx = i - 1
        raw[i] = { id = p[1], name = BodyPartType.getDisplayName(BodyPartType.FromIndex(idx)),
            bite = player:getBodyPartClothingDefense(idx, true, false),
            scratch = player:getBodyPartClothingDefense(idx, false, false) }
    end
    self.rows = L.protRows(raw)
end

-- Hovered part: from the table row or from the silhouette (both ways, D-147).
function Pr:hoverId()
    if not self:isMouseOver() or not self.lay then return nil end
    local s = T.scale()
    local mx, my = self:getMouseX() / s, self:getMouseY() / s
    local lay = self.lay
    local i = L.protRowAt(lay, #self.rows, mx, my)
    if i then return self.rows[i].id end
    local bx, by = mx - lay.bodyX, my - lay.bodyY
    if bx < 0 or by < 0 or bx > lay.bodyW or by > lay.bodyH then return nil end
    return L.protPartAt(self.boxes or {}, bx * P.BODY_W / lay.bodyW, by * P.BODY_H / lay.bodyH)
end

-- Colour of a fill token at alpha over panel, as opaque rgb: overlapping antialiased edges of two
-- parts would otherwise add up into darker seams.
local function mixed(tok, alpha)
    local c, bg = T.color(tok), T.color("panel")
    local a = alpha or 1
    return { r = bg.r + (c.r - bg.r) * a, g = bg.g + (c.g - bg.g) * a, b = bg.b + (c.b - bg.b) * a }
end

-- The bps_* textures are trimmed: drawTextureScaled would stretch the trimmed area over the whole frame.
-- Each one is drawn at its offset and real size, scaled from the 123x302 frame to w x h, on whole pixels.
local function tint(el, tex, x, y, w, h, c)
    if not tex then return end
    local kx, ky = w / P.BODY_W, h / P.BODY_H
    local x0 = math.floor(x + tex:getOffsetX() * kx + 0.5)
    local y0 = math.floor(y + tex:getOffsetY() * ky + 0.5)
    el:drawTextureScaled(tex, x0, y0, math.floor(tex:getWidth() * kx + 0.5), math.floor(tex:getHeight() * ky + 0.5),
        1, c.r, c.g, c.b)
end

function Pr:drawBody(hover)
    local lay = self.lay
    local x, y, w, h = px(lay.bodyX), px(lay.bodyY), px(lay.bodyW), px(lay.bodyH)
    tint(self, self.baseTex, x, y, w, h, T.color("panel2"))
    local hoverRow
    for _, r in ipairs(self.rows) do
        if r.id == hover then hoverRow = r
        else tint(self, self.partTex[r.id], x, y, w, h, mixed(r.fill, r.fillAlpha)) end
    end
    tint(self, self.outlineTex, x, y, w, h, T.color("panel"))
    if hoverRow then
        -- Accent outline: copies shifted by 1 px in 8 directions, then the part on top.
        local tex, o = self.partTex[hoverRow.id], math.max(1, px(P.OUTLINE))
        local accent = T.color("accent")
        for dx = -o, o do
            for dy = -o, o do
                if (dx ~= 0 or dy ~= 0) and dx * dx + dy * dy <= o * o + 1 then tint(self, tex, x + dx, y + dy, w, h, accent) end
            end
        end
        tint(self, tex, x, y, w, h, mixed(hoverRow.fill, hoverRow.fillAlpha))
    end
end

function Pr:drawTable(hover)
    local lay = self.lay
    local tx0, tw = px(lay.tableX), px(lay.tableW)
    local headMid = px(lay.headY + P.HEAD / 2)
    D.textMid(self, getText("IGUI_health_Part"), px(lay.nameX), headMid, "label", "muted", 1, "left", px(lay.nameW))
    D.textMid(self, getText("IGUI_health_Bite"), px(lay.biteRight), headMid, "label", "muted", 1, "right")
    D.textMid(self, getText("IGUI_health_Scratch"), px(lay.scrRight), headMid, "label", "muted", 1, "right")
    D.fill(self, tx0, px(lay.rowY) - 1, tw, 1, "line")
    for i, r in ipairs(self.rows) do
        local y = px(lay.rowY + (i - 1) * P.ROW)
        local rh = px(lay.rowY + i * P.ROW) - y
        if r.id == hover then
            D.fill(self, tx0, y, tw, rh, "sel")
            D.border(self, tx0, y, tw, rh, "accent")
        end
        local cy = y + rh / 2
        D.textMid(self, r.name, px(lay.nameX), cy, "rowSmall", "text", 1, "left", px(lay.nameW))
        D.textMid(self, r.biteText, px(lay.biteRight), cy, "infoText", r.biteTok, 1, "right")
        D.textMid(self, r.scrText, px(lay.scrRight), cy, "infoText", r.scrTok, 1, "right")
    end
end

function Pr:drawLegend()
    local lay = self.lay
    D.fill(self, 0, px(lay.legendY), self.width, 1, "line")
    local x, cy, sq = px(16), px(lay.legendMid), px(12)
    for _, b in ipairs(L.PROT_LEGEND) do
        local text = b[2] or getText("UI_RSK_Eq_ProtNone")
        D.fill(self, x, cy - sq / 2, sq, sq, b[1])
        x = x + sq + px(6)
        x = x + D.textMid(self, text, x, cy, "tipText", "muted") + px(14)
    end
end

function Pr:prerender()
    if not self.lay then return end
    local hover = self:hoverId()
    self:drawBody(hover)
    self:drawTable(hover)
    self:drawLegend()
end

return Pr
