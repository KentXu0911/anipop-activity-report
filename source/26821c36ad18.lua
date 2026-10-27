local LuckyDeliveryExtraButton = require_debug "amf.feature.localactivity.luckydelivery.view.LuckyDeliveryExtraButton"

local Module = class("LuckyDeliveryExtraButtonModule")

local STAR_WAND_ICON_POS_BY_REQUIRED_WIN_COUNT = {
    [8] = {x = 133, y = 63},
    [9] = {x = 133, y = 63},
}

function Module:create()
    return Module.new()
end

function Module:loadExtraModule()
    return _G.amfBean("AssetsUtil"):loadMiniFiles({
        "amf/activity/luckydelivery/texture/LuckyDeliveryExtraButton.plist",
        "amf/activity/luckydeliverypass/texture/LuckyDeliveryPassExtraButton.plist",
        "amf/activity/luckydelivery/materials/main_scene_button_frame.png",
        "amf/activity/luckydelivery/sound/common_click.mp3",
        "amf/activity/happydelivery/spine/jindu.skel",
        "amf/activity/happydelivery/spine/qiehuan_vfx.skel",
    })
end

function Module:getInited()
    return self.isInited
end

function Module:setInited()
    self.isInited = true
end

function Module:initExtraModule(extraData, mainSceneButton)
    if self:getInited() then return end

    self:setInited()
    self.mainSceneButton = mainSceneButton
    self.mgr = _G.amfBean("LuckyDeliveryManager")
    self.lastTaskIndex = nil
    self.lastRequiredWinCount = nil
    self.lastStepInTask = nil
    self.lastProgressKey = nil
    self.animToken = 0
    self.isTransitioning = false
    self.pendingRefresh = false

    self:refreshExtraModule()
end

function Module:isRefreshable()
    if not self:getInited() then return false end
    if not self.mainSceneButton or self.mainSceneButton.isDisposed then return false end
    return true
end

function Module:getProgressKey(taskInfo, hasReward)
    if not taskInfo then return nil end

    return table.concat({
        tostring(taskInfo.taskId),
        tostring(taskInfo.needStreakWin),
        tostring(taskInfo.progress),
        tostring(taskInfo.finished),
        tostring(hasReward),
    }, "_")
end

function Module:buildTargetState()
    local model = self.mgr and self.mgr:getModel()
    local taskInfo = model and model:getCurrentTask()
    local isCompleted = false
    if not taskInfo and model:isAllTasksFinished() then
        local taskList = model:getTaskList()
        taskInfo = taskList and taskList[#taskList]
        isCompleted = true
    end
    if not taskInfo then return nil end

    local hasReward = self.mgr:canSupplementReward()
    local progressKey = self:getProgressKey(taskInfo, hasReward)
    if progressKey == self.lastProgressKey then return nil end

    if not self.lastTaskIndex and isCompleted and not hasReward then return nil end

    local taskIndex = taskInfo.taskId
    local kind
    if not self.lastTaskIndex then
        kind = "init"
    elseif taskIndex ~= self.lastTaskIndex then
        kind = "switch"
    else
        kind = "step"
    end

    return {
        kind = kind,
        taskIndex = taskIndex,
        requiredWinCount = taskInfo.needStreakWin or 0,
        curStepInTask = math.min(taskInfo.progress or 0, taskInfo.needStreakWin or 0),
        boxTier = self.mgr:getBoxTier(taskInfo),
        taskType = self.mgr:getTaskType(),
        progressKey = progressKey,
        isCompleted = isCompleted,
        hasReward = hasReward,
    }
end

function Module:ensureExtraUI()
    if self.extraUI then return true end
    if not self.mainSceneButton then return false end

    self.frameUI = UICreateUtil:createSpriteFile("amf/activity/luckydelivery/materials/main_scene_button_frame.png", true)
    self.frameUI:setPositionXY(0, 0)
    self.mainSceneButton.decoLayer:addChildAt(self.frameUI, 0)

    self.extraUI = LuckyDeliveryExtraButton:create()
    self.extraUI:setPositionXY(0, 0)
    self.mainSceneButton.decoLayer:addChild(self.extraUI)
    return true
end

function Module:clearOwnExtraUI()
    self.animToken = (self.animToken or 0) + 1
    self.isTransitioning = false
    self.pendingRefresh = false
    self.lastTaskIndex = nil
    self.lastRequiredWinCount = nil
    self.lastStepInTask = nil
    self.lastProgressKey = nil
    if self.extraUI then
        self.extraUI:removeFromParentAndCleanup(true)
        self.extraUI = nil
    end
    if self.frameUI then
        self.frameUI:removeFromParentAndCleanup(true)
        self.frameUI = nil
    end
    self:refreshStarWandIconPos()
end

function Module:refreshStarWandIconPos(requiredWinCount)
    if not self.mainSceneButton then return end

    local pos = STAR_WAND_ICON_POS_BY_REQUIRED_WIN_COUNT[requiredWinCount]
    self.mainSceneButton:setStarWandIconPos(pos)
end

function Module:refreshOwnExtraModule(showOwnExtra)
    if not showOwnExtra then
        self:clearOwnExtraUI()
        return
    end

    local target = self:buildTargetState()
    if not target then return end

    if self.isTransitioning then
        self.pendingRefresh = true
        return
    end

    self:applyTargetState(target)
end

function Module:refreshPassExtraModule(showOwnExtra)
    if self.mgr:canShowPassMainSceneExtra() then
        if self.passExtraModule then
            self.passExtraModule:refreshExtraModule()
        else
            local PassExtraButtonModule = require_debug "amf.feature.localactivity.luckydeliverypass.mainsceneextra.LuckyDeliveryPassExtraButtonModule"
            self.passExtraModule = PassExtraButtonModule:create()
            self.passExtraModule:initExtraModule(nil, self.mainSceneButton)
        end
        if showOwnExtra then
            self.passExtraModule:setPositionXY(-75, 170)
        else
            self.passExtraModule:setPositionXY(-75, 130)
        end
        self:setPassExtraModuleVisible(not self:shouldHidePassExtraModule(showOwnExtra))
    elseif self.passExtraModule then
        self.passExtraModule:dispose()
        self.passExtraModule = nil
    end
end

function Module:shouldHidePassExtraModule(showOwnExtra)
    -- Hide pass only while the own extra is doing its first entry animation.
    return showOwnExtra and self.isTransitioning and not self.lastTaskIndex
end

function Module:setPassExtraModuleVisible(visible)
    if self.passExtraModule then
        self.passExtraModule:setVisible(visible)
    end
end

function Module:startTransition()
    self.isTransitioning = true
    self.pendingRefresh = false
    return self.animToken
end

function Module:finishTransition(target)
    self.lastTaskIndex = target.taskIndex
    self.lastRequiredWinCount = target.requiredWinCount
    self.lastStepInTask = target.curStepInTask
    self.lastProgressKey = target.progressKey
    self.isTransitioning = false

    if self.pendingRefresh then
        self.pendingRefresh = false
        self:refreshExtraModule()
    end
end

function Module:applyTargetState(target)
    if not self:ensureExtraUI() then return end

    self:refreshStarWandIconPos(target.requiredWinCount)

    local token = self:startTransition()

    if target.kind == "init" then
        self.extraUI:update(target)
        local skipAnim = self.mgr:hasInitAnimPlayedToday()
        self.mgr:setInitAnimPlayedToday(true)
        self.extraUI:playInitAnim(skipAnim):next(function()
            if self.animToken ~= token then return end
            return self.extraUI:playBubbleIn(skipAnim)
        end):next(function()
            if self.animToken ~= token then return end
            self:finishTransition(target)
            self:refreshPassExtraModule(true)
        end)
    elseif target.kind == "step" then
        local lastStepInTask = self.lastStepInTask or 0
        if target.curStepInTask > lastStepInTask then
            self.extraUI:update(target, target.curStepInTask - 1)
            self.extraUI:playStepAnim(target.curStepInTask):next(function()
                if self.animToken ~= token then return end
                self:finishTransition(target)
            end)
        elseif target.curStepInTask < lastStepInTask then
            self.extraUI:update(target, lastStepInTask)
            self.extraUI:playRollbackAnim(lastStepInTask, target.curStepInTask):next(function()
                if self.animToken ~= token then return end
                self:finishTransition(target)
            end)
        else
            self.extraUI:update(target)
            self:finishTransition(target)
        end
    elseif target.kind == "switch" then
        self.extraUI:playStepAnim(self.lastRequiredWinCount, true):next(function()
            if self.animToken ~= token then return end
            return self.extraUI:playBubbleOut("vfx")
        end):next(function()
            if self.animToken ~= token then return end
            self.extraUI:update(target)
            return self.extraUI:playBubbleIn()
        end):next(function()
            if self.animToken ~= token then return end
            self:finishTransition(target)
        end)
    end
end

function Module:refreshExtraModule()
    if not self:isRefreshable() then return end

    local showOwnExtra = self.mgr:canShowOwnMainSceneExtra()
    self:refreshOwnExtraModule(showOwnExtra)
    self:refreshPassExtraModule(showOwnExtra)
end

function Module:dispose()
    self:clearOwnExtraUI()
    if self.passExtraModule then
        self.passExtraModule:dispose()
        self.passExtraModule = nil
    end
    self.mgr = nil
    self.mainSceneButton = nil
end

return Module
