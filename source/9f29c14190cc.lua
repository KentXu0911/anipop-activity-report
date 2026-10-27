-- @ref 强弹框架: 声明式注册中心
-- checkPoint 是唯一身份：一个 checkPoint 对应一个注册实例、一个调度槽位、一条规则。
-- 不再有 registrationId / candidateId / ruleKey / assignedSlotKey 等分离身份字段。

local AutoPopupDebugLog = require "amf.middleware.autopop.AutoPopupDebugLog"
local LogReason = AutoPopupDebugLog.Reason
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
require "amf.middleware.autopop.config.AutoPopupConst"
require "amf.middleware.interconnection.eventcenter.FeatureEvent"

local PopupRegistration = class("PopupRegistration")

local _featureToPopStage = {
    [FeatureEvent.ENTER_STAGE2] = AutoPopupConst.PopStage.STAGE_TWO,
    [FeatureEvent.ENTER_STAGE3] = AutoPopupConst.PopStage.STAGE_THREE,
    [FeatureEvent.ENTER_STAGE4] = AutoPopupConst.PopStage.STAGE_FOUR,
}

local function getMappedPopStage(stage)
    return AutoPopupConst.PopStageKeyMapping[tostring(stage)] or stage
end

local function getSceneLogIdentity(entry, options)
    options = options or {}
    return {
        -- 一元身份：checkPoint 即候选身份、业务规则和调度槽位。
        checkPoint = entry.checkPoint,
        source = "registered",
        actId = entry.config.actId,
        popType = options.popType or entry.config.popType,
        checkRequired = type(entry.config.check) == "function",
    }
end

local function addToSetIndex(index, key, value)
    if key == nil then return end
    key = tostring(key)
    index[key] = index[key] or {}
    index[key][value] = true
end

local function removeFromSetIndex(index, key, value)
    if key == nil then return end
    key = tostring(key)
    local values = index[key]
    if not values then return end
    values[value] = nil
    if not next(values) then
        index[key] = nil
    end
end

local function sortCandidatesBySchedule(autoPopupMgr, popStage, candidates)
    local indexed = {}
    for index, candidate in ipairs(candidates) do
        indexed[candidate] = index
        candidate._scheduleRank = autoPopupMgr:getPopupScheduleRank(popStage, candidate.checkPoint)
    end
    table.sort(candidates, function(left, right)
        local leftRank = left._scheduleRank or math.huge
        local rightRank = right._scheduleRank or math.huge
        if leftRank ~= rightRank then return leftRank < rightRank end
        return indexed[left] < indexed[right]
    end)
    return candidates
end

function PopupRegistration:create(autoPopupMgr)
    local inst = PopupRegistration.new()
    inst:init(autoPopupMgr)
    return inst
end

function PopupRegistration:init(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
    self._entries = {}
    self._stageIndex = {}
    self._manualOpenIndex = {}

    _G.amfEC:registerFeature(self)
    ActivityEventCenter:register(ActivityEvent.ACTIVITY_POPUP_OVER, self._onActivityPopupOver, self)
end

function PopupRegistration:onActEnterStage2(data)
    self:_onStageEnter(FeatureEvent.ENTER_STAGE2, data)
end

function PopupRegistration:onActEnterStage3(data)
    self:_onStageEnter(FeatureEvent.ENTER_STAGE3, data)
end

function PopupRegistration:onActEnterStage4(data)
    self:_onStageEnter(FeatureEvent.ENTER_STAGE4, data)
end

--- 注册声明式强弹。
-- 每个注册项必须声明自己的业务 checkpoint、场景和弹出函数。
-- checkpoint 的 PopType/组内优先级由 AutoPopupCheckPoints 统一反查，
-- 每日次数上限由 AutoPopupLimit 静态定义。
-- @param config table: { checkPoint, stages, check?, pop?, actId?, manualOpen?, popType? }
--   checkPoint 即唯一身份；同一 checkPoint 重复注册视为覆盖。
function PopupRegistration:register(config)
    local checkPoint = config.checkPoint
    assert(checkPoint, "PopupRegistration:register requires checkPoint")
    assert(config.stages and #config.stages > 0, "PopupRegistration:register requires stages")
    local pop = config.pop or config.creator
    assert(pop, "PopupRegistration:register requires pop/creator")

    local oldEntry = self._entries[checkPoint]
    if oldEntry then
        self:_removeEntryIndexes(oldEntry)
        AutoPopupDebugLog:log("PopupRegistration:register overwrite", checkPoint)
    end

    local entry = {
        checkPoint = checkPoint,
        config = config,
    }

    self._entries[checkPoint] = entry
    self:_addEntryIndexes(entry)
    if config.actId ~= nil then
        self._autoPopupMgr:removeConfiguredPopupsForActivity(config.actId)
    end
    -- 候选集合变化后，场景调度需要重新解析。
    self._autoPopupMgr:invalidatePopupSchedule()
    AutoPopupDebugLog:log("PopupRegistration:register", checkPoint)
    return checkPoint
end

function PopupRegistration:unregister(checkPoint)
    local entry = self._entries[checkPoint]
    if not entry then return end

    self:_removeEntryIndexes(entry)
    self._entries[checkPoint] = nil
    -- 队列槽位即 checkPoint，卸载时按 checkPoint 清理已入队弹窗。
    self._autoPopupMgr:removePopupConfig(checkPoint)
    self._autoPopupMgr:invalidatePopupSchedule()
    AutoPopupDebugLog:log("PopupRegistration:unregister", checkPoint)
end

function PopupRegistration:_addEntryIndexes(entry)
    local checkPoint = entry.checkPoint
    local config = entry.config
    for _, popStage in ipairs(config.stages) do
        local list = self._stageIndex[popStage]
        if not list then
            list = {}
            self._stageIndex[popStage] = list
        end
        table.insert(list, checkPoint)
    end

    addToSetIndex(self._manualOpenIndex, config.manualOpen, checkPoint)
end

function PopupRegistration:_removeEntryIndexes(entry)
    local checkPoint = entry.checkPoint
    local config = entry.config
    for _, popStage in ipairs(config.stages) do
        local list = self._stageIndex[popStage]
        if list then
            for i = #list, 1, -1 do
                if list[i] == checkPoint then
                    table.remove(list, i)
                end
            end
        end
    end

    removeFromSetIndex(self._manualOpenIndex, config.manualOpen, checkPoint)
end

function PopupRegistration:_onActivityPopupOver(event)
    if not self._autoPopupMgr:isEnabled() then return end

    local data = event and event:getData() or {}
    local checkPoints = {}
    local function collect(values)
        for checkPoint in pairs(values or {}) do
            checkPoints[checkPoint] = true
        end
    end

    if data.actId ~= nil then
        collect(self._manualOpenIndex[tostring(data.actId)])
    end

    for checkPoint in pairs(checkPoints) do
        local entry = self._entries[checkPoint]
        if entry then
            self:_markPopupHandled(checkPoint)
        end
    end
end

function PopupRegistration:_markPopupHandled(checkPoint)
    local limitNum = self._autoPopupMgr:getCheckPointLimitNum(checkPoint)
    local currentNum = self._autoPopupMgr:getCheckPointPopNum(checkPoint)
    if limitNum == -1 or currentNum < limitNum then
        AutoPopupDebugLog:log("PopupRegistration:_markPopupHandled", checkPoint)
        self._autoPopupMgr:increaseCheckPointPopNum(checkPoint)
    end
    self._autoPopupMgr:removePopupConfig(checkPoint)
end

function PopupRegistration:isRegistered(checkPoint)
    return self._entries[checkPoint] ~= nil
end

function PopupRegistration:hasRegisteredPopupForActivity(actId)
    if actId == nil then return false end
    local activityId = tostring(actId)
    for checkPoint, entry in pairs(self._entries) do
        if tostring(entry.config.actId) == activityId then
            return true
        end
    end
    return false
end

function PopupRegistration:hasRegisteredPopupForCheckpoint(checkPoint)
    return self._entries[checkPoint] ~= nil
end

function PopupRegistration:_onStageEnter(featureEvent, stageParams)
    local popStage = _featureToPopStage[featureEvent]
    if not popStage then return end

    local checkPoints = self._stageIndex[popStage]
    if not checkPoints or #checkPoints == 0 then return end

    local candidates = {}
    for _, checkPoint in ipairs(checkPoints) do
        local entry = self._entries[checkPoint]
        if entry then
            local params = table.clone(stageParams or {})
            params.popStage = popStage
            local candidate = {
                checkPoint = checkPoint,
                actId = entry.config.actId,
                metaId = entry.config.metaId,
                popType = entry.config.popType,
                entry = entry,
                stageParams = params,
            }
            candidates[#candidates + 1] = candidate
        end
    end

    local function checkCandidate(candidate)
        local entry = candidate.entry
        local sceneLogIdentity = getSceneLogIdentity(entry, {
            popType = entry.config.popType,
        })
        local passed = true
        local checkReason
        local checkResult = "success"
        if entry.config.check then
            AutoPopupDebugLog:recordPopupCheckStarted(sceneLogIdentity)
            local ok, result, reason = pcall(entry.config.check, candidate.stageParams)
            passed = ok and not not result
            if not ok then
                checkResult = "fail"
                checkReason = LogReason.Check.ERROR
                AutoPopupDebugLog:log("PopupRegistration:check error", candidate.checkPoint, tostring(result))
            elseif not passed then
                checkResult = "fail"
                checkReason = reason
            end
        else
            checkResult = "none"
        end
        if checkResult == "none" then
            AutoPopupDebugLog:recordPopupCheckNotRequired(sceneLogIdentity)
        else
            AutoPopupDebugLog:recordPopupCheck(sceneLogIdentity, checkResult, checkReason)
        end
        return passed
    end

    sortCandidatesBySchedule(self._autoPopupMgr, popStage, candidates)
    for _, candidate in ipairs(candidates) do
        if checkCandidate(candidate) then self:_enqueueRegisteredPopup(candidate) end
    end
end

function PopupRegistration:_enqueueRegisteredPopup(candidate)
    local entry = candidate.entry
    local config = entry.config
    local checkPoint = entry.checkPoint
	local function onPopOver()
		AutoPopEventCenter:dispatch(
			AutoPopEvent.SINGLE_POP_OVER,
			checkPoint
		)
    end

    local pop = config.pop or config.creator
    local ok, creator = pcall(pop, candidate.stageParams, onPopOver)
    if not ok or type(creator) ~= "function" then
        AutoPopupDebugLog:log("PopupRegistration:creator error", entry.checkPoint, tostring(creator))
        AutoPopupDebugLog:recordPopupEnqueue({
            checkPoint = checkPoint,
            actId = config.actId,
            source = "registered",
        }, "fail", LogReason.Enqueue.CREATOR_ERROR, checkPoint)
        return
    end

    local enqueued = self._autoPopupMgr:addPopupConfig(
        checkPoint, creator, config.actId, "registered"
    )
    if enqueued and candidate.stageParams then
        local popupQueue = self._autoPopupMgr:getPopupQueueByCheckPoint(checkPoint)
        local popupEntry = popupQueue and popupQueue[checkPoint]
        if popupEntry then
            popupEntry.popupStageId = candidate.stageParams.popStage
        end
    end
    return enqueued
end

function PopupRegistration:onPassDay()
end

function PopupRegistration:getSceneLogDefinitions(popStage)
    local result = {}
    local stageKey = getMappedPopStage(popStage)
    local checkPoints = self._stageIndex[stageKey] or self._stageIndex[popStage] or {}
    for _, checkPoint in ipairs(checkPoints) do
        local entry = self._entries[checkPoint]
        if entry then
            result[#result + 1] = getSceneLogIdentity(entry, {
                popType = entry.config.popType,
            })
        end
    end
    return result
end

return PopupRegistration
