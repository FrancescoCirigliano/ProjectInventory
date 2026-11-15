-- RSK.Equipment.Exercises - M2 Exercises tab (D-93): list, description, duration, Start/Stop.
-- Replaces the ISFitnessUI window but reuses its logic and actions (V-11): equipItems and update work on the same
-- fields (player, exeData, itemsToReequip, currentExercice), the exercise stays an ISFitnessAction.
require "ISUI/ISFitnessUI"
require "ISUI/ISRichTextPanel"
require "RSK/UI/UI"
require "RSK/Equipment/Logic"

local T, D, UI, UL = RSK.Theme, RSK.UI.Draw, RSK.UI, RSK.UI.Logic
local Q = RSK.Equipment
local L = Q.Logic

local PAD, ROW_H, ROW_GAP = 16, 52, 8
local TEXT_H, BTN_H, STEP_W, TIME_W, ACTION_W = 96, 36, 36, 72, 120
local BLOCK_H = TEXT_H + ROW_GAP + BTN_H + ROW_GAP + 18

local function px(n) return T.px(n) end
local function tx(k, ...) return getText("UI_RSK_Eq_" .. k, ...) end

local X = UI.Panel:derive("RSK_EquipExercises")
Q.Exercises = X

function X:new(x, y, w, h, win)
    local o = UI.Panel.new(self, x, y, w, h, { bg = false, border = false })
    o.win = win
    o.player = getSpecificPlayer(win.playerNum)
    o.fitness = o.player:getFitness()
    o.itemsToReequip = {}
    o.minutes = 10
    return o
end

-- List sorted by name; FitnessExercises pairs have no order.
function X:loadExercises()
    local list = {}
    for id, data in pairs(FitnessExercises.exercisesType) do
        list[#list + 1] = { id = id, data = data, name = data.name }
    end
    table.sort(list, function(a, b) return tostring(a.name) < tostring(b.name) end)
    return list
end

function X:createChildren()
    self.fitness:init()
    self.exerciseList = self:loadExercises()
    self.list = UI.add(self, UI.List:new(PAD, 12, self.bw - 2 * PAD, 100, {
        rowH = ROW_H, target = self, drawRow = X.drawRow, onSelect = X.onSelect,
    }))
    self.list:setItems(self.exerciseList)

    local rich = ISRichTextPanel:new(px(PAD), 0, px(self.bw - 2 * PAD), px(TEXT_H))
    rich:initialise()
    rich.background = false
    rich.clip = true
    rich.autosetheight = false
    self:addChild(rich)
    self.text = rich

    self.minusBtn = UI.add(self, UI.Button:new(0, 0, STEP_W, BTN_H, "-", self, X.onStep, { arg = -1 }))
    self.plusBtn = UI.add(self, UI.Button:new(0, 0, STEP_W, BTN_H, "+", self, X.onStep, { arg = 1 }))
    self.startBtn = UI.add(self, UI.Button:new(0, 0, ACTION_W, BTN_H, tx("Start"), self, X.onStart, { style = "primary" }))
    self.stopBtn = UI.add(self, UI.Button:new(0, 0, ACTION_W, BTN_H, tx("Stop"), self, X.onStop))
    self.list:select(1, true)
    self:arrange()
end

function X:arrange()
    local w, h = self.bw, self.bh
    local listH = math.max(ROW_H * 2, h - 12 - ROW_GAP - BLOCK_H - PAD)
    self.list:setBase(PAD, 12, w - 2 * PAD, listH)
    local y = 12 + listH + ROW_GAP
    self.text:setX(px(PAD)); self.text:setY(px(y))
    self.text:setWidth(px(w - 2 * PAD)); self.text:setHeight(px(TEXT_H))
    self.text:paginate()
    local by = y + TEXT_H + ROW_GAP + 18
    self.controlsY = by
    self.minusBtn:setBase(PAD, by)
    self.plusBtn:setBase(PAD + STEP_W + TIME_W, by)
    self.stopBtn:setBase(w - PAD - ACTION_W, by)
    self.startBtn:setBase(w - PAD - ACTION_W, by)
end

-- ---------------------------------------------------------------- data and state
function X:missingItem(data)
    return data.item ~= nil and not self.player:getInventory():contains(data.item, true)
end

-- Text as in ISFitnessUI:selectedNewExercise: description and resulting stiffness.
function X:onSelect(entry)
    if not entry then return end
    self.selectedExe = entry.id
    self.exeData = entry.data
    local text = entry.data.tooltip or ""
    if entry.data.stiffness then
        for _, part in ipairs(luautils.split(entry.data.stiffness, ",")) do
            if part == "legs" then text = text .. " <LINE> " .. getText("IGUI_Fitness_LegsStiffness")
            elseif part == "arms" then text = text .. " <LINE> " .. getText("IGUI_Fitness_ArmsStiffness")
            elseif part == "abs" then text = text .. " <LINE> " .. getText("IGUI_Fitness_AbsStiffness") end
        end
    end
    self.text.text = text
    self.text:paginate()
    self:refresh()
end

function X:currentAction()
    local queue = ISTimedActionQueue.getTimedActionQueue(self.player)
    local a = queue and queue.queue and queue.queue[1]
    if a and a.Type == "ISFitnessAction" and a.action then return a end
    return nil
end

function X:refresh()
    if not self.exeData then return end
    local p = self.player
    local moodles = p:getMoodles()
    local running = self:currentAction() ~= nil
    local reason = L.fitnessBlock({
        missingItem = self:missingItem(self.exeData),
        endurance = moodles:getMoodleLevel(MoodleType.ENDURANCE),
        enduranceMax = ISFitnessUI.enduranceLevelThreshold,
        heavyLoad = moodles:getMoodleLevel(MoodleType.HEAVY_LOAD),
        sitting = p:getVariableBoolean("sitonground") or p:isSittingOnFurniture(),
        inVehicle = p:getVehicle() ~= nil,
        pain = moodles:getMoodleLevel(MoodleType.PAIN),
        climbing = p:isClimbing(),
    })
    self.startBtn:setVisible(not running)
    self.stopBtn:setVisible(running)
    self.startBtn:setEnabled(reason == nil)
    if reason == "IGUI_FitnessNeedItem" then
        self.startBtn:setTooltip(getItemDisplayName(self.exeData.item))
    else
        self.startBtn:setTooltip(reason and getText(reason) or nil)
    end
end

-- After the exercise vanilla recreates what it removed (ISFitnessUI:update): even with the tab hidden.
function X:reequip()
    if self.currentExercice then ISFitnessUI.update(self) end
end

-- ---------------------------------------------------------------- actions
function X:onStep(_, dir) self.minutes = L.fitnessTime(self.minutes, dir) end

function X:onStart()
    if not self.exeData or not ISFitnessUI.equipItems(self) then return end
    local action = ISFitnessAction:new(self.player, self.selectedExe, self.minutes, self.exeData, self.exeData.type)
    self.currentExercice = self.exeData.type
    action.fitnessUI = self
    ISTimedActionQueue.addGetUpAndThen(self.player, action)
    self:refresh()
end

function X:onStop()
    self.player:setVariable("ExerciseStarted", false)
    local a = self:currentAction()
    if a then a.action:forceStop() end
    self:refresh()
end

-- ---------------------------------------------------------------- drawing
function X.drawRow(list, entry, i, x, y, w, h)
    local self = list.target
    local pad = px(12)
    local missing = self:missingItem(entry.data)
    local barW = px(110)
    local cy = y + h / 2
    if missing then
        local nh, sh = D.lineHeight("row"), D.lineHeight("tipSub")
        local ty = y + math.floor((h - nh - sh) / 2)
        D.text(list, entry.name, x + pad, ty, "row", "muted", 1, "left", w - barW - pad * 3)
        D.text(list, tx("NeedItem", getItemDisplayName(entry.data.item)), x + pad, ty + nh, "tipSub", "warn", 1, "left", w - barW - pad * 3)
    else
        D.textMid(list, entry.name, x + pad, cy, "row", "text", 1, "left", w - barW - pad * 3)
    end
    local f = L.regularity(self.fitness:getRegularity(entry.id))
    local bx, bh = x + w - pad - barW, px(T.base.bar.cond)
    D.fill(list, bx, cy - bh / 2, barW, bh, "panel2")
    if f > 0 then D.fill(list, bx, cy - bh / 2, math.max(1, math.floor(barW * f)), bh, "accent") end
end

function X:prerender()
    if not self.controlsY then return end
    local y = px(self.controlsY - 18)
    D.text(self, getText("IGUI_FitnessTime"), px(PAD), y, "label", "muted")
    local tx0 = px(PAD + STEP_W)
    D.textMid(self, tostring(self.minutes), tx0 + px(TIME_W) / 2, px(self.controlsY + BTN_H / 2), "number", "text", 1, "center")
end

return X
