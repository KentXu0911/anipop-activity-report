local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local Const = require "amf.feature.localactivity.aipopup.config.AIPopupConst"

local Manager = class("AIPopupManager", BaseFeatureManager)

local function normalizeStageId(context)
    if context and context.popStageId ~= nil then
        local stageId = tonumber(context.popStageId)
        if stageId then return stageId end
    end

    local popStage = context and context.popStage
    for stageId, mappedStage in pairs(AutoPopupConst.PopStageKeyMapping) do
        if mappedStage == popStage then
            return tonumber(stageId)
        end
    end
end

function Manager:setAutoPopupMgr(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
end

function Manager:_init()
    self._requestInFlight = false
    self:_registerEvents()
    self:_installResolver()
    -- MainSceneContext 在 USER_LOGIN 通知之后创建，在线登录需要在这里补一次首拉。
    if _G.kUserLogin then
        self:_requestPredictionData("login_init")
    end

    local targetDate = self:_getTargetDate()
    local getPredictions = self:getModel():getPredictions()
    -- printx(33, "AIPopupManager:_init", targetDate, tts(getPredictions))
end

function Manager:_registerEvents()
    if self._eventsRegistered then return end
    _G.amfEC:registerNormal(NormalEvent.USER_LOGIN, self.onUserLogin, self)
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)
    AutoPopEventCenter:register(AutoPopEvent.POPUP_WILL_SHOW, self.onAutoPopupWillShow, self)
    self._eventsRegistered = true
end

function Manager:_installResolver()
    if self._resolverInstalled then
        return
    end

    self._autoPopupMgr:setPopupScheduleResolver(function(candidates, context)
        return self:resolveSchedule(candidates, context)
    end)
    self._resolverInstalled = true
end

function Manager:isEnabled()
    return self:getModel():isDataEnabled()
end

function Manager:isMaintenanceEnabled()
    return MaintenanceManager:getInstance():isEnabledInGroup(
        Const.MAINTENANCE_NAME,
        Const.MAINTENANCE_GROUP
    ) == true
end

function Manager:_getConstPath()
    return "amf.feature.localactivity.aipopup.config.AIPopupConst"
end

function Manager:_getModelPath()
    return "amf.feature.localactivity.aipopup.model.AIPopupModel"
end

function Manager:updatePredictionData(data)
    local model = self:getModel()
    if not model then return false end
    local assigned, changed = model:mergePredictionData(data)
    if changed and self._autoPopupMgr then
        self._autoPopupMgr:invalidatePopupSchedule()
    end
    self:_installResolver()
    return assigned
end

-- 统一处理协议或其他系统送达的标签数据。
function Manager:onGetData(data)
    return self:updatePredictionData(data)
end

function Manager:_shouldFetchToday()
    local model = self:getModel()
    return TimeKit:getDayStartTimeByTS(model:getLastFetchTime()) ~=
        TimeKit:getDayStartTimeByTS(TimeKit:timeInSec())
end

function Manager:_requestPredictionData(source)
    -- printx(33, "AIPopupManager:_requestPredictionData", source, self._requestInFlight, self:_shouldFetchToday())
    if not self:isMaintenanceEnabled() or self._requestInFlight or not self:_shouldFetchToday() then
        return false
    end
    local model = self:getModel()
    self._requestInFlight = true
    local request = model:requestAiAutoPopInfo()
    if not request then
        self._requestInFlight = false
        return false
    end
    request:next(function(response)
        self._requestInFlight = false
        local data = response
        if response then
            data = response:getData() or {}
        end
        if data == nil then
            data = {}
        end
        if self:updatePredictionData(data) then
            model:setLastFetchTime(TimeKit:timeInSec())
        end
    end, function()
        self._requestInFlight = false
    end)
    return true
end

function Manager:onUserLogin(event)
    local data = event and event:getData() or {}
    if data.isOffline then return end
    return self:_requestPredictionData("login")
end

function Manager:onSystemEnterForeground()
    return self:_requestPredictionData("foreground")
end

function Manager:onActEnterMainScene(event)
    local data = event and event:getData() or {}
    if data.firstEnter then return end
    return self:_requestPredictionData("main_scene")
end

function Manager:_getTargetDate()
    local model = self:getModel()
    return model and model:getCurrentTargetDate()
end

function Manager:_getActivityPriority(targetDate, activityId)
    if activityId == nil then
        return false, nil
    end
    local model = self:getModel()
    if not model then
        return false, nil
    end
    local score = model:getActivityPriority(targetDate, activityId)
    if score ~= nil then
        return true, score
    end
    return false, nil
end

function Manager:_trackAIInterveneShow(popupEntry)
    -- 被 AI 干预的凭据由调度写在 popupEntry 上：originalCheckPoint/originalActId
    -- 只有真被挪过顺序位置的强弹才有值；位置没变的强弹即使有 AI 权重也不打点。
    if not popupEntry or not popupEntry.originalCheckPoint or popupEntry.actId == nil then
        return
    end
    -- printx(33, "AIPopupManager:_trackAIInterveneShow", tts(popupEntry),
    --     tostring(popupEntry.originalCheckPoint), tostring(popupEntry.originalActId))

    local targetDate = self:_getTargetDate()
    local aiPopupRecInfo = self:getModel():getAiPopupRecInfoByDate(targetDate)
    if not aiPopupRecInfo then return end

    DcUtil:UserTrack({
        category = "ai_recommend",
        sub_category = "main_panel_show_intervene",
        ai_popuprec_info = mime.b64(table.serialize(aiPopupRecInfo)),
        t1 = popupEntry.actId,
        t2 = popupEntry.originalActId,
    })
end
function Manager:onAutoPopupWillShow(event)
    local data = event and event:getData() or {}
    self:_trackAIInterveneShow(data.popupEntry)
end

--- 只重排带 actId 且有模型权重的候选项。没有 actId 或权重的强弹保留原顺序，
-- 同一活动的多个强弹保持原有顺序。回写顺序由 PopupSchedule 统一完成。
-- 传入的 candidates 已经是静态顺序，被挤掉位置的原候选由 PopupSchedule 记在
-- popupEntry 上，这里只负责给出重排后的顺序。
function Manager:resolveSchedule(candidates, context)
    if not self:isEnabled() then return candidates end
    if type(candidates) ~= "table" or #candidates < 2 then return candidates end

    local stageId = normalizeStageId(context)
    if stageId ~= 3 and stageId ~= 4 then return candidates end

    local targetDate = self:_getTargetDate()
    local ranked = {}
    local rankedIndexes = {}
    for index, candidate in ipairs(candidates) do
        local hasScore, priority = self:_getActivityPriority(targetDate, candidate.actId)
        if hasScore then
            ranked[#ranked + 1] = {
                candidate = candidate,
                index = index,
                priority = priority,
            }
            rankedIndexes[#rankedIndexes + 1] = index
        end
    end

    if #ranked < 2 then return candidates end

    table.sort(ranked, function(left, right)
        if left.priority ~= right.priority then
            return left.priority > right.priority
        end
        return left.index < right.index
    end)

    local result = {}
    for index, candidate in ipairs(candidates) do
        result[index] = candidate.checkPoint
    end
    for index, candidateIndex in ipairs(rankedIndexes) do
        local candidate = ranked[index].candidate
        result[candidateIndex] = candidate.checkPoint
    end
    return result
end

return Manager
