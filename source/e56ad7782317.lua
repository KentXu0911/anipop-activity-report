local BaseFeatureModel = require "amf.middleware.activity.base.BaseFeatureModel"
local Model = class("SprintGiftPackageModel", BaseFeatureModel)

local function toSeconds(value)
    return TimeKit:tryConvertMsToSec(tonumber(value) or 0) or 0
end

local function getCompletedTarget(tasks, progress)
    local completedTarget = 0
    for _, task in ipairs(tasks or {}) do
        local target = tonumber(task.total) or 0
        if progress >= target then
            completedTarget = math.max(completedTarget, target)
        end
    end
    return completedTarget
end

local function getCurrentTaskTarget(tasks, progress)
    local currentTarget = 0
    for _, task in ipairs(tasks or {}) do
        local target = tonumber(task.total) or 0
        currentTarget = target
        if progress < target then
            break
        end
    end
    return currentTarget
end

function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "SprintGiftPackageModel"
    }):as("db")
end

function Model:_getConstPath()
	return "amf.feature.localactivity.sprintgiftpackage.config.SprintGiftPackageConst"
end 

-- Model
function Model:__declare()
    self:_initLocalData()
    self:_initLocalConfig()
    self:_initLocalKey()
end

function Model:_initLocalData()
    self.userInfo = {}
end

function Model:_initLocalConfig()
    self.localConfig = {}
end

function Model:_initLocalKey()
    self._localCache = {}
    self.historyProgress = 0
    self.taskTip = nil
    self.timeOutTip = nil
    self.rewardTimeTip = nil
    self.mainTimeAllTaskDonePop = nil
    self.rewardTimeNeedBuyPop = nil
    self.rewardTimeBoughtNeedClaimPop = nil
    self.addFiveShowTime = 0
    self.historyLevelStatus = nil
    self.taskDoneMaxTotal = nil

    self.todayTriggerAct = nil
    self.todayJoinAct = nil
end

function Model:setLocalCache(key, value)
    self:setValue("_localCache."..key, value)
end

function Model:getLocalCache(key)
    return self:getValue("_localCache."..key)
end

function Model:fromServer( data,skipSaveLocal )
    for k,v in pairs(data) do
		self:setValue(k, v)
	end

	if not skipSaveLocal then
		self:flush()
	end
end

--判断数据是否准备就绪
function Model:isDataEnabled()
	if not self:getValue("userInfo") then
        return false
    end
    if table.isEmpty(self:getValue("userInfo")) then
        return false
    end
    if not self:getValue("localConfig") then
        return false
    end
    if table.isEmpty(self:getValue("localConfig")) then
        return false
    end
    return true
end

function Model:getMainEndTimeInSec()
    return TimeKit:tryConvertMsToSec(self:getMainEndTime())
end

function Model:setGuide( index )
	local guideInfo = self:getDataByKey("guideIds", {})
	table.insert(guideInfo, index)
	self:setDataByKey("guideIds", guideInfo, true)
end

function Model:hasGuide( index )
	local guideInfo = self:getDataByKey("guideIds", {}, false)
	return table.find(guideInfo, function ( v )
		return v == index
	end)
end

function Model:setGuideIndex(index)
    self:setGuide(index)

    local ActCommonHttp = require("amf.middleware.activity.http.ActCommonHttp")
    ActCommonHttp:setActGuideFlag( self:getConst().actId, index)
end

function Model:_getLocalKey(key)
    return key
end
    
--------------------- 业务数据处理 ---------------------
function Model:passDayClear()
	--存储
	self:clearData()
end

-- 添加一个add的方法
function Model:addIntToLocalByKey(key, needTime, addNum, needActStartTimeCheck)
    if not addNum then addNum = 1 end
    local value = self:getFlagFromLocalByKeyInt(key, needTime, needActStartTimeCheck, 0)
    self:setLocalValueByKey( key, needTime, value+addNum, needActStartTimeCheck )
end

function Model:getIconV2Snapshot(now, options)
    options = options or {}
    now = tonumber(now) or TimeKit:timeInSec()

    local mainBeginTime = toSeconds(self:getMainBeginTime())
    local mainEndTime = toSeconds(self:getMainEndTime())
    local endTime = toSeconds(self:getEndTime())
    local phase = "hidden"
    if now >= mainBeginTime and now < mainEndTime then
        phase = "main"
    elseif now >= mainEndTime and now < endTime then
        phase = "reward"
    end

    local current = tonumber(options.progressOverride)
        or tonumber(self:getDataByKey("current", 0))
        or 0
    local tasks = self:getDataByKey("tasks", {})
    local maxTotal = #tasks > 0 and (tonumber(tasks[#tasks].total) or 0) or 0
    local currentTaskTotal = tonumber(options.progressTargetOverride)
        or getCurrentTaskTarget(tasks, current)

    local periodId = tonumber(self:getDataByKey("periodId", 1)) or 1
    local seen = self:hasGuide(periodId) == true
    local bought = (tonumber(self:getDataByKey("buyPackageId", 0)) or 0) > 0
    local historyProgress = self:getFlagFromLocalByKeyInt(
        "historyProgress",
        nil,
        true,
        0
    )
    local taskDoneMaxTotal = self:getFlagFromLocalByKeyInt(
        "taskDoneMaxTotal",
        nil,
        true,
        0
    )
    local completedTarget = getCompletedTarget(tasks, current)
    local historyCompletedTarget = getCompletedTarget(tasks, historyProgress)
    local unclaimedRewardCount = 0
    for _, task in ipairs(tasks) do
        if current >= (tonumber(task.total) or 0) and task.hasReward ~= true then
            unclaimedRewardCount = unclaimedRewardCount + 1
        end
    end

    local allTasksComplete = maxTotal > 0 and current >= maxTotal
    local hasUnclaimedReward = bought and (
        unclaimedRewardCount > 0 or options.actInfoReward == true
    )
    local redDotVisible = not bought and completedTarget > taskDoneMaxTotal
    local rewardCase
    if phase == "reward" then
        if not bought and allTasksComplete then
            rewardCase = "unboughtComplete"
        elseif hasUnclaimedReward then
            rewardCase = "boughtUnclaimed"
        end
    end

    local dataEnabled = self:isDataEnabled()
    local enabled = dataEnabled and (phase == "main" or rewardCase ~= nil)
    local absenceReason
    if endTime > 0 and now >= endTime then
        absenceReason = "activityEnded"
    elseif dataEnabled and phase == "reward" and rewardCase == nil then
        absenceReason = "rewardNotEligible"
    end
    local progressVisible = phase == "main"
        and current > 0
        and currentTaskTotal > 0
        and (options.forceProgressVisible == true or not allTasksComplete)
    local rewardDynamic = hasUnclaimedReward and (
        phase == "reward" or completedTarget > historyCompletedTarget
    )
    local presentationKey = table.concat({
        "sprintgiftpackage",
        tostring(periodId),
        tostring(mainBeginTime),
        tostring(endTime),
    }, ":")

    return {
        enabled = enabled,
        absenceReason = absenceReason,
        phase = phase,
        periodId = periodId,
        seen = seen,
        progress = {
            current = math.max(0, current),
            total = math.max(0, currentTaskTotal),
            visible = progressVisible,
            completedTarget = completedTarget,
            allTasksComplete = allTasksComplete,
        },
        purchase = {
            bought = bought,
        },
        reward = {
            case = rewardCase,
            hasUnclaimed = hasUnclaimedReward,
            unclaimedCount = unclaimedRewardCount,
            redDotVisible = redDotVisible,
            dynamic = rewardDynamic,
            presentationKey = presentationKey,
        },
        time = {
            now = now,
            mainBeginTime = mainBeginTime,
            mainEndTime = mainEndTime,
            endTime = endTime,
        },
        assetAnimation = self:getConfigByKey("uiType") == "Special" and "2_1" or "1_1",
    }
end

return Model
