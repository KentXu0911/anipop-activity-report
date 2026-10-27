local FixBirdNestLog = require 'amf.feature.localactivity.fixbirdnest.FixBirdNestLog'

local TASK_INFO_BEFORE_DEFAULT = {
    progress = 0,
    target = 10,
    reward = {{}},
    showFinished = false,
    rewardConfigType = 0,
}

local FixBirdNestModel = class("FixBirdNestModel", AMFDataRef)

function FixBirdNestModel:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "fix_bird_nest".._G.FixBirdNestConst.ACT_OPEN_VERSION,
    }):as("db")
end

--成员变量声明
function FixBirdNestModel:__declare()
    self._recordData = {}
    self._actTime = {}
    self._localConfig = {}
    self._actData = {}
    self._dataUpdated = false
end

function FixBirdNestModel:saveActData()
    self:setValue("_actData", self._actData, true)
end

function FixBirdNestModel:replaceRewards(rewards)
    local miniGameRewardConvertConfigList = self:getConfigByName("miniGameRewardConvertConfigList")
    
    local function replaceReward(reward)
        for k, v in pairs(miniGameRewardConvertConfigList) do
            if v.beReplaceId == reward.itemId then
                reward.itemId = v.replaceId
                reward.num = v.ratio
                break
            end
        end
    end

    for k, reward in pairs(rewards) do
        replaceReward(reward)
    end

    return rewards
end


function FixBirdNestModel:fromServer(data)
    --FixBirdNestLog:log("getConfigVersion__localConfig__is_empty", self._localConfig)
    FixBirdNestLog:log("FixBirdNestModel:fromServer__data_____", data)
    for k,v in pairs(data) do
        if k == "actTime" then
            self:setValue("_actTime", v, true)
            self._actData.actTime = v
            self:saveActData()
        elseif k == "serverVersionedConfig" then
            local config = v.config
            local serverMd5 = v.serverMd5
            if config and config ~= "" then
                config = table.deserialize(config)
                local localConfig = self:getValue("_localConfig")
                for kk,vv in pairs(config) do
                    localConfig[kk] = vv
                end
                localConfig.configVersion = serverMd5
                self:setValue("_localConfig", localConfig, true)
            end
        else
            self._actData[k] = v
        end
    end
    self._actData._dataUpdated = true
    self:saveActData()
    --FixBirdNestLog:log("_actTime_____", self._actTime)
    FixBirdNestLog:log("_actData_____", self._actData)
    --FixBirdNestLog:log("_localConfig____", self._localConfig)
    --FixBirdNestLog:log("_dataUpdated____", self._dataUpdated)
end

--是否屏蔽礼包
function FixBirdNestModel:getHasGift()
    local hasGift = MaintenanceManager:getInstance():isEnabledInGroup('h5_birdnest_gift', 'ON')
    FixBirdNestLog:log("getHasGift_____", hasGift)
    return hasGift
end

function FixBirdNestModel:isDataReady()
    if table.isEmpty(self._actData) then
        return false
    end
    if not self._actData._dataUpdated then
        return false
    end
    return true
end

function FixBirdNestModel:getMainBeginTime()
    if self._actData.actTime then
        return self._actData.actTime.mainBeginTime
    end
    return 0
end

function FixBirdNestModel:getMainEndTime()
    if self._actData.actTime then
        return self._actData.actTime.mainEndTime
    end
end

function FixBirdNestModel:isInActMainTime( ... )
    if self._actData.actTime then
        local n = TimeKit:timeInSec()
        return n >= tonumber(self._actData.actTime.mainBeginTime) and
                n <= tonumber(self._actData.actTime.mainEndTime)
    end
    return false
end

function FixBirdNestModel:isInAwardTime()
	if self._actData.actTime then
        local n = TimeKit:timeInSec()
        return n >= tonumber(self._actData.actTime.mainEndTime) and
                n <= tonumber(self._actData.actTime.endTime)
	end
end

function FixBirdNestModel:getConfigByName(name)
    return self._localConfig[name]
end

function FixBirdNestModel:getTaskInfoMap( ... )
    if table.isEmpty(self._actData.taskInfoMap) then
        self:setTaskInfoMap({ {} })
    end
    return self._actData.taskInfoMap
end

function FixBirdNestModel:setTaskInfoMap(v)
    self._actData.taskInfoMap = v
    self:setValue("_actData", self._actData)
end

function FixBirdNestModel:getTaskIdBefore()
    if not self._actData.taskIdBefore then
        self:setTaskIdBefore(1)
    end
    return self._actData.taskIdBefore
end

function FixBirdNestModel:setTaskIdBefore( v )
    self._actData.taskIdBefore = v
    self:setValue("_actData", self._actData)
end

function FixBirdNestModel:addTaskIdBefore( v )
    self:setTaskIdBefore(self:getTaskIdBefore() + v)
end

function FixBirdNestModel:getConfigVersion()
    if table.isEmpty(self._localConfig) then
        return 0
    end
    return self._localConfig.configVersion or 0
end

function FixBirdNestModel:getTaskCount()
    return _G.FixBirdNestConst.TASK_COUNT
end

function FixBirdNestModel:getCurTaskInfo()
    local curTask = nil
    local taskMap = self:getTaskInfoMap()
    for k,taskInfo in pairs(taskMap) do
        if taskInfo.progress <= taskInfo.target and not taskInfo.showFinished then
            taskInfo.taskId = tonumber(k)
            if not curTask or taskInfo.taskId < curTask.taskId then
                curTask = taskInfo
            end
        end
    end
    if not curTask then
        local taskCount = self:getTaskCount()
        curTask = taskMap[tostring(taskCount)]
        curTask.taskId = taskCount
    end

    return curTask
end

function FixBirdNestModel:getLifeNum()
    if not self._actData.lifeNum then
        self:setLifeNum(0)
    end
    return self._actData.lifeNum
end

function FixBirdNestModel:setLifeNum(v)
    self._actData.lifeNum = v
    self:saveActData()
end

function FixBirdNestModel:addLifeNum(v)
    self:setLifeNum(self:getLifeNum() + v)
end

function FixBirdNestModel:getLifeNumBefore()
    if not self._actData.lifeNumBefore then
        self:setLifeNumBefore(0)
    end
    return self._actData.lifeNumBefore
end

function FixBirdNestModel:setLifeNumBefore(v)
    self._actData.lifeNumBefore = v
    self:saveActData()
end

function FixBirdNestModel:addLifeNumBefore(v)
    self:setLifeNumBefore(self:getLifeNumBefore() + v)
end

function FixBirdNestModel:getLostLives()
    if not self._actData.lostLives then
        self:setLostLives(0)
    end
    return self._actData.lostLives
end

function FixBirdNestModel:setLostLives( v )
    self._actData.lostLives = v
    self:saveActData()
end

function FixBirdNestModel:addLostLives( v )
    self:setLostLives(self:getLostLives() + v)
end

function FixBirdNestModel:getMaxLife()
    return self:getConfigByName("maxLife")
end

function FixBirdNestModel:getTaskConfigByType( configType )
    configType = tostring(configType)
    local taskConfigs = self:getConfigByName("taskInfo")
    local config = taskConfigs[configType]
    return config
end

function FixBirdNestModel:getTaskRewardList( configType,taskId )
    local config = self:getTaskConfigByType(configType)
    local rewardsMeta = table.find(config,function ( meta )
        return meta.taskId == taskId
    end)
    rewardsMeta.rewards.list = self:replaceRewards(rewardsMeta.rewards.list)
    return rewardsMeta.rewards.list
end

function FixBirdNestModel:trySeeTask()
    local taskCount = self:getTaskCount()
    for i = 1,taskCount do
        local taskInfo = self:getTaskInfoByIndex(i)
        if taskInfo.progress >= taskInfo.target and not taskInfo.showFinished then
            taskInfo.showFinished = true
            self:setLifeNum(self:getMaxLife())
        end
    end
    self:saveActData()
end

function FixBirdNestModel:getTaskInfoByIndex( idx )
    for k, taskInfo in pairs(self:getTaskInfoMap()) do
        taskInfo.taskId = tonumber(k)
        local rewardConfigType = taskInfo.rewardConfigType
        local rewardList = self:getTaskRewardList(rewardConfigType, taskInfo.taskId)
        taskInfo.rewardList = rewardList
        if idx == tonumber(k) then
            return taskInfo
        end
    end
    return nil
end

function FixBirdNestModel:isFinishedTask(idx)
    local taskInfo = self:getTaskInfoByIndex(idx)
    return taskInfo.progress >= taskInfo.target
end

function FixBirdNestModel:isAllTaskFinish()
    local taskInfoMap = self:getTaskInfoMap()
    return table.allF(taskInfoMap,function ( taskInfo )
        return taskInfo.progress >= taskInfo.target
    end)
end

function FixBirdNestModel:setTaskRewarded( idx )
    for i = 1,self:getTaskCount() do
        if idx == i then
            local taskInfo = self:getTaskInfoByIndex(i)
            taskInfo.reward = true
        end
    end
    self:saveActData()
end

function FixBirdNestModel:getMaxFinishTask()
	local ret = 0
	for i = 1,self:getTaskCount() do
		local taskInfo = self:getTaskInfoByIndex(i)
		if taskInfo.progress >= taskInfo.target then
			ret = math.max(ret,i)
		end
	end

	return ret
end

function FixBirdNestModel:getRound()
    if not self._actData.round then
        self:setRound(0)
    end
    return self._actData.round
end

function FixBirdNestModel:setRound( v )
    self._actData.round = v
    self:saveActData()
end

function FixBirdNestModel:addRound( v )
    self:setRound(self:getRound() + v)
end

function FixBirdNestModel:isCanGetGroupReward()
    if not self._actData.canGetGroupReward then
        self:setCanGetGroupReward(false)
    end
    return self._actData.canGetGroupReward
end

function FixBirdNestModel:setCanGetGroupReward(v)
    self._actData.canGetGroupReward = v
    self:saveActData()
end

function FixBirdNestModel:isGotGroupReward()
    local postGroupRewardList = self:getPostGroupRewardList()
    return postGroupRewardList and #postGroupRewardList <= 1
end

function FixBirdNestModel:getPostGroupRewardList()
    if not self._actData.postGroupRewardList then
        self:setPostGroupRewardList({})
    end
    return self:replaceRewards(self._actData.postGroupRewardList)
end

function FixBirdNestModel:setPostGroupRewardList( v )
    self._actData.postGroupRewardList = v
    self:saveActData()
end

function FixBirdNestModel:hasTaskReward()
	local taskCount = self:getTaskCount()
	for i = 1, taskCount do
		local taskInfo = self:getTaskInfoByIndex(i)
		if taskInfo.reward == false and taskInfo.progress >= taskInfo.target then
			return true
		end
	end
end

function FixBirdNestModel:saveRecord(key, value)
    if not key then return end
    local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())

    local saveValue = {
        time = nowTime,
        value = value
    }
    local saveStr = table.serialize(saveValue)
    self._recordData[key] = saveStr
    self:setValue("_recordData", self._recordData, true)
end

-- checkIsSameDay检查是否同一天，如果不是同一天就返回空
function FixBirdNestModel:getRecord(key, checkIsSameDay)
    if not key then return end
    
    local recordData = self:getValue("_recordData")
    local saveJsonStr = recordData[key]
    if saveJsonStr == nil then return end
    if type(saveJsonStr) ~= "string" then return end
    local saveTable = table.deserialize(saveJsonStr)

    local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())
    local bTimeIsOk = true

    -- 需要检查是否同一天 且 时间不同
    if checkIsSameDay and saveTable.time ~= nowTime then
        bTimeIsOk = false
    end

    -- 检查是否同一天 且 不是同一天 返回空
    if checkIsSameDay and not bTimeIsOk then
        return
    else
        return saveTable.value
    end
end

function FixBirdNestModel:getMedalId()
    return self._actData.medalId or 0
end

function FixBirdNestModel:setMedalId( v )
    self._actData.medalId = v
    self:saveActData()
end

function FixBirdNestModel:addMedalId( v )
    self:setMedalId(self:getMedalId() + v)
end

function FixBirdNestModel:getMedalInfo( medalId )
	-- body
	local medalInfoList = self:getConfigByName("medalInfoList")

	return table.find(medalInfoList,function ( medalInfo )
		return medalInfo.medalId == medalId
	end)
end

function FixBirdNestModel:getFinishedTasks( ... )
    if not self._actData.finishedTasks then
        self:setFinishedTasks(0)
    end
    return self._actData.finishedTasks
end

function FixBirdNestModel:setFinishedTasks( v )
    self._actData.finishedTasks = v
    self:saveActData()
end

function FixBirdNestModel:addFinishedTasks( v )
    self:setFinishedTasks(self:getFinishedTasks() + v)
end

function FixBirdNestModel:getScoreBuffExpireTime()
    if not self._actData.scoreBuffExpireTime then
        self:setScoreBuffExpireTime(0)
    end
    return self._actData.scoreBuffExpireTime
end

function FixBirdNestModel:setScoreBuffExpireTime(v)
    self._actData.scoreBuffExpireTime = v
    self:saveActData()
end

function FixBirdNestModel:addScoreBuffExpireTime(v)
    self:setScoreBuffExpireTime(self:getScoreBuffExpireTime() +  v)
end

function FixBirdNestModel:resetTaskBefore()
	local curTask = self:getCurTaskInfo()
    self:setTaskBeforeTarget(curTask.target)
    self:setTaskBeforeProgress(0)
	self:setTaskIdBefore(1)
end

function FixBirdNestModel:getTaskInfoBefore()
    if table.isEmpty(self._actData.taskInfoBefore) then
        self._actData.taskInfoBefore = table.clone(TASK_INFO_BEFORE_DEFAULT)
        self:saveActData()
    end
    return self._actData.taskInfoBefore
end

function FixBirdNestModel:getTaskBeforeProgress()
    local taskBefore = self:getTaskInfoBefore()
    return taskBefore.progress
end

function FixBirdNestModel:setTaskBeforeProgress(v)
    self._actData.taskInfoBefore.progress = v
    self:saveActData()
end

function FixBirdNestModel:addTaskBeforeProgress(v)
    self:setTaskBeforeProgress(self:getTaskBeforeProgress() + v)
end

function FixBirdNestModel:getTaskBeforeTarget()
    local taskBefore = self:getTaskInfoBefore()
    return taskBefore.target
end

function FixBirdNestModel:setTaskBeforeTarget(v)
    self._actData.taskInfoBefore.target = v
    self:saveActData()
end

function FixBirdNestModel:addTaskBeforeTarget(v)
    self:setTaskBeforeTarget(self:getTaskBeforeTarget() + v)
end

function FixBirdNestModel:getTaskBeforeReward()
    local taskBefore = self:getTaskInfoBefore()
    return taskBefore.reward
end

function FixBirdNestModel:setTaskBeforeReward(v)
    local taskBefore = self:getTaskInfoBefore()
    taskBefore.reward = v
    self:saveActData()
end

function FixBirdNestModel:getTaskBeforeShowFinished()
    local taskBefore = self:getTaskInfoBefore()
    return taskBefore.showFinished
end

function FixBirdNestModel:setTaskBeforeShowFinished(v)
    local taskBefore = self:getTaskInfoBefore()
    taskBefore.showFinished = v
    self:saveActData()
end

function FixBirdNestModel:getTaskBeforeRewardConfigType()
    local taskBefore = self:getTaskInfoBefore()
    return taskBefore.rewardConfigType
end

function FixBirdNestModel:setTaskBeforeRewardConfigType(v)
    local taskBefore = self:getTaskInfoBefore()
    taskBefore.rewardConfigType = v
    self:saveActData()
end

function FixBirdNestModel:addTaskBeforeRewardConfigType(v)
    local taskBefore = self:getTaskInfoBefore()
    taskBefore.rewardConfigType = taskBefore.rewardConfigType + v
    self:saveActData()
end

function FixBirdNestModel:getTotalLevelByTaskId(taskId)
	local ret = 0
	local taskInfoMap = self:getTaskInfoMap()
	for k,taskInfo in pairs(taskInfoMap) do
		if tonumber(k) <= taskId then
			ret = ret + taskInfo.target
		end
	end
	return ret
end

function FixBirdNestModel:getGoodsList()
    local payTagId = self:getPayTagId()
	local goodsIdMetaList = self:getConfigByName("goodsIdMetaList")

	local isLowPay = function ( ... )
		return payTagId <= 4
	end

	local goodsIds = {}
	for k,goodsIdMeta in ipairs(goodsIdMetaList) do

		-- printx(16,tts(goodsIdMeta))

		if isLowPay() then
			if goodsIdMeta.payType == 1 then
				local goodsId = goodsIdMeta.goodsIdListHolder.lastGoodsId
				local pos = goodsIdMeta.panelPosition
				goodsIds[pos] = goodsId
			end
		else
			if goodsIdMeta.payType == 2 then
				local goodsId = goodsIdMeta.goodsIdListHolder.lastGoodsId
				local pos = goodsIdMeta.panelPosition
				goodsIds[pos] = goodsId
			end
		end
	end

	return goodsIds
end

function FixBirdNestModel:getPayTagId()
    return self._actData.payTagId or 0
end

function FixBirdNestModel:setDailyBought()
    self._actData.dailyBought = true
    self:saveActData()
end

function FixBirdNestModel:isDailyBought()
    return self._actData.dailyBought
end

function FixBirdNestModel:isFailedBefore()
	if not self._actData.failedBefore then
		self:setFailedBefore(false)
	end
	return self._actData.failedBefore
end

function FixBirdNestModel:setFailedBefore(v)
	self._actData.failedBefore = v
	self:saveActData()
end

function FixBirdNestModel:canShowGiftIcon(  )
    return self:getConfigByName("rewardPackagePayment")
end

function FixBirdNestModel:getRankReward( rank )
	local danRewardsList = self:getConfigByName("danRewardsList")
	for k,v in pairs(danRewardsList) do
		if v.minRange <= rank and v.maxRange >= rank then
            local rewardList = self:replaceRewards(v.rewardList)
			return rewardList
		end
	end
	return {}
end

function FixBirdNestModel:getGuideInfo()
	if not self._actData.guideInfo then
		self:setGuideInfo({0})
	end
	return self._actData.guideInfo
end

function FixBirdNestModel:setGuideInfo(v)
	self._actData.guideInfo = v
    self:saveActData()
end

function FixBirdNestModel:getPostGroupRank()
    if not self._actData.postGroupRank then
        self:setPostGroupRank(0)
    end
    return self._actData.postGroupRank
end

function FixBirdNestModel:setPostGroupRank( v )
    self._actData.postGroupRank = v
    self:saveActData()
end

function FixBirdNestModel:addPostGroupRank( v )
    self:setPostGroupRank(self:getPostGroupRank() + v)
end

function FixBirdNestModel:isMaxLevel()
	if not self._actData.maxLevel then
		self:setMaxLevel(false)
	end
	return self._actData.maxLevel
end

function FixBirdNestModel:setMaxLevel( v )
	self._actData.maxLevel = v
    self:saveActData()
end

function FixBirdNestModel:isMaxColor()
    if not self._actData.maxColor then
        self:setMaxColor(false)
    end
    return self._actData.maxColor
end

function FixBirdNestModel:setMaxColor(v)
    self._actData.maxColor = v
    self:saveActData()
end

function FixBirdNestModel:isMaxLevelBefore()
    if not self._actData.maxLevelBefore then
        self:setMaxLevelBefore(false)
    end
    return self._actData.maxLevelBefore
end

function FixBirdNestModel:setMaxLevelBefore( v )
    self._actData.maxLevelBefore = v
    self:saveActData()
end

function FixBirdNestModel:isMaxColorBefore()
	if not self._actData.maxColorBefore then
		self:setMaxColorBefore(false)
	end
	return self._actData.maxColorBefore
end

function FixBirdNestModel:setMaxColorBefore( v )
	self._actData.maxColorBefore = v
    self:saveActData()
end

-- 更新数据要调用这个，不能判断showFinished和等于的情况，否则更新不了数据
function FixBirdNestModel:getRealCurTaskInfo()
	local curTask = nil
	local taskMap = self:getTaskInfoMap()
	for k,taskInfo in pairs(taskMap) do
		if taskInfo.progress < taskInfo.target then
			taskInfo.taskId = tonumber(k)
			if not curTask or taskInfo.taskId < curTask.taskId then
				curTask = taskInfo
			end
		end
	end
	if not curTask then
		local taskCount = self:getTaskCount()
		curTask = taskMap[tostring(taskCount)]
		curTask.taskId = taskCount
	end

	return curTask
end

function FixBirdNestModel:resetCurTask( taskInfo )
	local taskId = taskInfo.taskId
	local taskMap = self:getTaskInfoMap()
	taskMap[tostring(taskId)] = taskInfo
    self:saveActData()
end

function FixBirdNestModel:getLivenessTagId()
    return self._actData.livenessTagId or 0
end

function FixBirdNestModel:setGotGroupReward(v)
    self:setPostGroupRewardList({})
end

return FixBirdNestModel
