local BaseFeatureModel = require"amf.middleware.activity.base.BaseFeatureModel"

local LOCAL_PATH = 'amf.feature.localactivity.weektask'

local WeekTaskModel = class("WeekTaskModel", BaseFeatureModel)

function WeekTaskModel:_getConstPath()
    return LOCAL_PATH..'.config.WeekTaskConfig'
end

function WeekTaskModel:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "WeekTask_data"
    }):as("db")
end

-- WeekTaskModel
function WeekTaskModel:__declare()
    self:_initLocalData()
    self:_initLocalConfig()
    self:_initLocalKey()
end

function WeekTaskModel:_initLocalData()
    self.updateDataTime = nil
    self.userData = nil
    self.data2 = nil
    self.beginTime = nil
    self.endTime = nil
    self.mainBeginTime = nil
    self.mainEndTime = nil
end

function WeekTaskModel:_initLocalConfig()
    self.config = nil
    self.localConfig = nil
    self.serverVersionedConfig = nil
end

function WeekTaskModel:_initLocalKey()
    self.canyuHadDC = nil
    self.joinHadDC = nil
end

function WeekTaskModel:passDayClear()
    -- 跨天
	
	
end

function WeekTaskModel:clearLocalData()
	self:setValue("updateDataTime", nil)
	self:setValue("userData", nil)
	self:setValue("data2", nil)
	self:setValue("beginTime", nil)
	self:setValue("endTime", nil)
	self:setValue("mainBeginTime", nil)
	self:setValue("mainEndTime", nil)
	self:setValue("config", nil)
	self:setValue("localConfig", nil)
	self:setValue("serverVersionedConfig", nil)
end

function WeekTaskModel:fromLocalChangeEnd()
	--加一个跨天判断 
    local bPassDay = false
    local curTime = TimeKit:timeInSec()
    if self.updateDataTime then
        if getDayStartTimeByTS(curTime) ~= getDayStartTimeByTS(self.updateDataTime) then  
            bPassDay = true
        end
        self:setValue("updateDataTime", curTime)
    else
        self:setValue("updateDataTime", curTime)
    end

    if bPassDay then  
    	self:passDayClear()
    end
end

function WeekTaskModel:fromServer(data, config)
    -- 从活动info 发来的信息拆分出 data 和 localConfig
    -- userData是后端数据，self.data.xxx可以自行添加不会覆盖删除

    if table.isEmpty(data) then
    	--清空数据
	    self:clearLocalData()
    else
	    for k, v in pairs(data) do
	        self:setValue(k, v)
	    end
	end

    if config and not table.isEmpty(config) and config.config ~= '' then
        config.config = table.deserialize(config.config)
        self:setValue("localConfig", config)
    end
    
    -- printx(12,'fromServer',tts(self:getValue("userData")),tts(self:getValue("localConfig")))

    self:flush()
end

function WeekTaskModel:getConfig()
    local localConfig = self:getValue("localConfig")
    if localConfig and localConfig.config then
        return localConfig.config
    end

    return {}
end

-- 获取data 设置data值  数字类型的增加
function WeekTaskModel:getDataByKey(key, default)
    local value = self:getValue(key)
    if value then
        return value
    end

    local userData = self:getValue("userData")
    if userData and userData[key] ~= nil then
        return userData[key]
    end

    return default
end

function WeekTaskModel:setDataByKey(key, value, needSave)
    local userData = self:getValue("userData")

    if userData and userData[key] ~= nil then
        userData[key] = value
        self:setValue("userData", userData, needSave)
    end
end

function WeekTaskModel:addDataByKey(key, value)
    local userData = self:getValue("userData")
    if userData and type(userData[key]) == 'number' then
        userData[key] = userData[key] + value
        self:setValue("userData", userData, true)
    end
end

function WeekTaskModel:setExDataByKey(key, value, needSave)
    self:setValue(key, value, needSave)
end

-- 获取配置
function WeekTaskModel:getConfigByKey(key)
    local config = self:getConfig()
    if config and config[key] then
        return config[key]
    end
end

function WeekTaskModel:getTaskRelatedActMeta(taskType)
    local taskRelatedActMetas = self:getConfigByKey('taskRelatedActMetas') or {}
    for i, v in ipairs(taskRelatedActMetas) do
        if v.taskType == taskType then
            local meta = table.clone(v)
            meta.relatedActMainBeginTs = math.floor((tonumber(meta.relatedActMainBeginTs) or 0) / 1000)
            return true, meta
        end
    end
    return false, {}
end

function WeekTaskModel:isTaskRelatedActType(taskType)
    local bGetSuccess = self:getTaskRelatedActMeta(taskType)
    return bGetSuccess
end

function WeekTaskModel:checkTaskRelatedActOpened(taskType)
    local bGetSuccess, relatedActMeta = self:getTaskRelatedActMeta(taskType)
    if not bGetSuccess then
        return true, relatedActMeta
    end

    local beginTs = relatedActMeta.relatedActMainBeginTs or 0
    if beginTs <= 0 then
        return true, relatedActMeta
    end

    return TimeKit:timeInSec() >= beginTs, relatedActMeta
end

function WeekTaskModel:getGuides()
    -- 引导标记
    return self:getDataByKey('guideIds') or {}
end

function WeekTaskModel:addGuides(index)
    -- 添加引导标记

    local guideInfo = self:getDataByKey('guideIds')
    table.insert(guideInfo, index)
    self:setDataByKey('guideIds', guideInfo, true)

    self:flush()
end

function WeekTaskModel:checkGuide(index)
    -- 检查引导标记
    local guideInfo = self:getDataByKey('guideIds') or {}

    return table.exist(guideInfo, index)
end

function WeekTaskModel:setGuideIndex(index)
    self:addGuides(index)

    local ActCommonHttp = require("amf.middleware.activity.http.ActCommonHttp")
    ActCommonHttp:setActGuideFlag(self:getConst().ACT_ID, index)
end

-------------------------------
-----数据处理
-------------------------------


function WeekTaskModel:getPerDayMap()
	local perDayMap = self:getDataByKey('perDays')
	return perDayMap
end

function WeekTaskModel:getDayInfo( weekDay )
	local perDayMap = self:getPerDayMap()
	return perDayMap[weekDay]
end

function WeekTaskModel:getDayTaskInfo( weekDay, taskId )
	local dayInfo = self:getDayInfo(weekDay)
	if dayInfo then
		for i,v in ipairs(dayInfo.tasks) do
			if v.taskId == taskId then
				return true, table.clone(v)
			end
		end
	end
	return false, {}
end

function WeekTaskModel:checkDayIsUnlock( weekDay )
	local dayInfo = self:getDayInfo(weekDay)
	if dayInfo then
		return dayInfo.unlocked
	end
	return false
end

function WeekTaskModel:checkProgressBoxIsGet( boxId )
	local finishedProgressBoxIds = self:getDataByKey('finishedProgressBoxIds')
	return table.exist( finishedProgressBoxIds, boxId )
end

function WeekTaskModel:setProgressBoxIsGet( finishedProgressBoxIds )
	self:setDataByKey('finishedProgressBoxIds',finishedProgressBoxIds)
end

function WeekTaskModel:getFinishedProgressBoxIds( )
	return self:getDataByKey('finishedProgressBoxIds')
end


function WeekTaskModel:getCollectNum(  )
	local curProgressValue = self:getDataByKey('curProgressValue')
	return curProgressValue
end

function WeekTaskModel:addCollectNum( num )
	local curProgressValue = self:getCollectNum()
	curProgressValue = curProgressValue + num
	self:setDataByKey('curProgressValue', curProgressValue )
end

function WeekTaskModel:setCollectNum( num )
	self:setDataByKey('curProgressValue', num )
end

function WeekTaskModel:getTaskFlag(  )
	local taskFlags = self:getDataByKey('taskFlags')
	if taskFlags == nil then taskFlags = {} end
    if #taskFlags == 0 then taskFlags = {0,0,0,0,0,0,0} end
	return table.clone(taskFlags)
end

function WeekTaskModel:setTaskFlag( taskFlags  )
	self:setDataByKey('taskFlags', taskFlags)
end

function WeekTaskModel:getLastPeriodReward()
	return self:getDataByKey('lastPeriodReward')
end

function WeekTaskModel:setLastPeriodRewardComplete()
	self:setDataByKey('lastPeriodReward', false)
end


-------------------------------
-----配置处理
-------------------------------

function WeekTaskModel:getFinishProgressBoxNum(   )
	--获取完成的进度宝箱数量
	local finishedProgressBoxIds = self:getDataByKey('finishedProgressBoxIds')
	return #finishedProgressBoxIds
end

function WeekTaskModel:getTaskDayConfig( weekDay  )
	--获取任务配置
	local perDayMetas = self:getConfigByKey('perDayMetas')
	for i,v in ipairs(perDayMetas) do
		if v.dayOfWeek == weekDay then
			return true, v
		end
	end
	return false, {}
end

local function findTaskMetaByTaskId(dayMeta, taskId)
	-- replaceTaskMetas.taskId 是实际下发的新任务 ID，replaceTaskId 指向被替换的原任务 ID。
	for _, metaKey in ipairs({'taskMetas', 'replaceTaskMetas'}) do
		for _, taskMeta in ipairs(dayMeta[metaKey] or {}) do
			if tostring(taskMeta.taskId) == tostring(taskId) then
				return taskMeta
			end
		end
	end
end

function WeekTaskModel:getTaskConfig( weekDay, taskId  )
	--获取任务配置
	local perDayMetas = self:getConfigByKey('perDayMetas')
	for _, dayMeta in ipairs(perDayMetas) do
		if dayMeta.dayOfWeek == weekDay then
			local taskMeta = findTaskMetaByTaskId(dayMeta, taskId)
			if taskMeta then
				return true, table.clone(taskMeta)
			end
		end
	end
	return false, {}
end

function WeekTaskModel:getTaskTypeByTaskId(taskId)
	-- 替换提示只给原始任务 ID，需要先从周任务配置还原任务类型，再路由到对应活动 Manager。
	local perDayMetas = self:getConfigByKey('perDayMetas') or {}
	for _, dayMeta in ipairs(perDayMetas) do
		local taskMeta = findTaskMetaByTaskId(dayMeta, taskId)
		if taskMeta then
			return taskMeta.taskType
		end
	end
	return self:getConst().TaskType.INVALID
end

function WeekTaskModel:getTaskConfigByIndex( weekDay, taskIndex  )
	--获取任务配置
	local dayInfo = self:getDayInfo(weekDay)
	local taskInfo = dayInfo and dayInfo.tasks and dayInfo.tasks[taskIndex]
	if taskInfo then
		return self:getTaskConfig(weekDay, taskInfo.taskId)
	end

	local perDayMetas = self:getConfigByKey('perDayMetas')
	for _, dayMeta in ipairs(perDayMetas) do
		if dayMeta.dayOfWeek == weekDay then
			if dayMeta.taskMetas[taskIndex] then
				return true, table.clone(dayMeta.taskMetas[taskIndex])
			end
		end
	end
	return false, {}
end

function WeekTaskModel:checkTaskCanAddAll( taskType )
	--任务是否是可以累计的
	local extendsValueTaskTypes = self:getConfigByKey('extendsValueTaskTypes')
	return table.exist( extendsValueTaskTypes, taskType )
end

function WeekTaskModel:getProgressBoxNum(  )
	--获取进度宝箱数量
	local progressBoxMetas = self:getConfigByKey('progressBoxMetas')
	return #progressBoxMetas
end

function WeekTaskModel:getProgressBoxConfig( boxId )
	--获取进度礼盒配置
	local progressBoxMetas = self:getConfigByKey('progressBoxMetas')
	for i,v in ipairs(progressBoxMetas) do
		if v.progressBoxId == boxId then
			return true, table.clone(v)
		end
	end
	return false, {}
end


-------------------------------
-----逻辑处理
-------------------------------

function WeekTaskModel:getNeedUpdateTaskFlayWeek()
	-- 获取某天可完成任务数量
    local needUpdateInfoList = {}

    for i=1, 7 do
    	local weekDay = i
	    local taskInfos = self:getTaskInfoByDay(weekDay)

	    for _, task in ipairs(taskInfos) do
            if task.curValue < task.target and task.taskType == self:getConst().TaskType.PASS_LEVEL then
	        	local info = {}
	            info.weekDay = weekDay
	            info.taskId = task.taskId
	            table.insert( needUpdateInfoList, info )
	        end
	    end
	end
    
    return needUpdateInfoList
end

function WeekTaskModel:checkWeekDayTaskIsCompleye( inWeekDay, taskType )
	-- 获取某天是否领取某个任务
    for i=1, 7 do
    	local weekDay = i
    	if inWeekDay == weekDay then
		    local taskInfos = self:getTaskInfoByDay(weekDay)

		    for _, task in ipairs(taskInfos) do
		        if task.finished and task.taskType == taskType then
		        	return true
		        end
		    end
		end
	end
    
    return false
end

function WeekTaskModel:checkWeekDayTaskIsFinish( inWeekDay, taskType )
	-- 获取某天是否完成某个任务
    for i=1, 7 do
    	local weekDay = i
    	if inWeekDay == weekDay then
		    local taskInfos = self:getTaskInfoByDay(weekDay)
		    for _, task in ipairs(taskInfos) do
		        if task.taskType == taskType and task.curValue >= task.target then
		        	return true
		        end
		    end
		end
	end
    
    return false
end

function WeekTaskModel:checkIsTaskAllComplete()
	-- 是否任务都完成
    for i=1, 7 do
	    local taskInfos = self:getTaskInfoByDay(i)
	    for _, task in ipairs(taskInfos) do
	        if not task.finished  then
	            return false
	        end
	    end
	end
	return true
end

function WeekTaskModel:getCanCompleteTaskCountByDay(weekDay)
	-- 获取某天可完成任务数量
    local count = 0
    local taskPosList = {}
    local taskInfos = self:getTaskInfoByDay(weekDay)
    
    for index, task in ipairs(taskInfos) do
        if not task.finished and task.curValue >= task.target then
            count = count + 1
            table.insert( taskPosList,  index)
        end
    end
    return count, taskPosList
end

function WeekTaskModel:getCanNotCompleteTaskCountByDay(weekDay)
	-- 获取某天不可完成任务数量
    local count = 0
    local taskPosList = {}
    local taskInfos = self:getTaskInfoByDay(weekDay)

    for index, task in ipairs(taskInfos) do
        if not task.finished and task.curValue < task.target then
            count = count + 1
            table.insert( taskPosList,  index)
        end
    end
    return count, taskPosList
end

function WeekTaskModel:getCurDay()
    --返回今天是活动第几天
    local beginDay = time2day(self.mainBeginTime)
    local toDay = time2day(TimeKit:timeInSec())
    local curDay = toDay - beginDay + 1
    return curDay
end

function WeekTaskModel:getTotalCanCompleteTaskCount()
	-- 获取总可完成任务数量
    local count = 0
    local perDayMap = self:getPerDayMap()
    local curDay =  self:getCurDay()
    local checkDay = curDay
    if checkDay >#perDayMap then checkDay = #perDayMap end

    for weekDay = 1,checkDay do
        count = count + self:getCanCompleteTaskCountByDay(weekDay)
    end

    return count
end

function WeekTaskModel:hasProgressBoxCanGet()
	-- 判断是否有可领取的宝箱
    local curProgress = self:getCollectNum()
    local boxNum = self:getProgressBoxNum()
    
    local openBoxIdList = {}
    for boxId = 1, boxNum do
        -- 宝箱未领取 且 进度满足
        if not self:checkProgressBoxIsGet(boxId) then
            local bSuccess, boxConfig = self:getProgressBoxConfig(boxId)
            if bSuccess and curProgress >= boxConfig.needTotalProgressValue then
                table.insert( openBoxIdList, boxId )
            end
        end
    end

    if #openBoxIdList > 0 then
    	return true, openBoxIdList
    else
    	return false, openBoxIdList
    end
    
end

function WeekTaskModel:getNextProgressBoxCantGet()
	-- 获取下一个未达成的宝箱位置
    local curProgress = self:getCollectNum()
    local boxNum = self:getProgressBoxNum()
    local boxIndex = boxNum

    local boxCanGet, openBoxIdList = self:hasProgressBoxCanGet()
    if boxCanGet then
    	boxIndex = openBoxIdList[#openBoxIdList]
    else
    	for boxId = 1, boxNum do
	        -- 进度为满足
	        local bSuccess, boxConfig = self:getProgressBoxConfig(boxId)
	        if bSuccess and curProgress < boxConfig.needTotalProgressValue then
	            boxIndex = boxId
	            break
	        end
	    end
    end
    
    return boxIndex
end

function WeekTaskModel:checkAllProgressBoxHadGet()
	-- 是否全部进度宝箱都领取完成
	local curProgress = self:getCollectNum()
    local boxNum = self:getProgressBoxNum()
    
    local getNum = 0
    for boxId = 1, boxNum do
        -- 宝箱未领取 且 进度满足
        if self:checkProgressBoxIsGet(boxId) then
            getNum = getNum + 1
        end
    end

    if getNum == boxNum then
    	return true
    end
    return false
end

function WeekTaskModel:getTaskInfoByDay( weekDay  )
	--获取一天的任务数据，数据配置拼起来
	local taskInfos = {}

	local dayInfo = self:getDayInfo(weekDay)
	local tasks = dayInfo.tasks

	for _, taskInfo in ipairs(tasks) do
		local info = table.clone(taskInfo)
		local _, taskMeta = self:getTaskConfig(weekDay, taskInfo.taskId)
		info.weekDay = weekDay
		info.taskType = taskMeta.taskType or self:getConst().TaskType.INVALID
		info.target = taskMeta.target or 0
		info.finishProgressValue = taskMeta.finishProgressValue or 0
		table.insert( taskInfos, info)
	end
	return taskInfos
end

function WeekTaskModel:setTaskComplete( weekDay, taskId  )
	local perDayMap = self:getPerDayMap()
	if perDayMap[weekDay] then
		for i,v in ipairs(perDayMap[weekDay].tasks ) do
			if v.taskId==taskId then
				v.finished = true
				break
			end
		end
	end
	self:setDataByKey( 'perDays', perDayMap )
end

function WeekTaskModel:getTodayLoginBroadInfo()
	--登录任务完成用，强行让推送广播. 找今日之前的第一个已完成的，作为广播
	local curDay =  self:getCurDay()
	for i=curDay, 1, -1 do
		local weekDay = i
		local bGetSucss, taskConfig = self:getTaskConfigByIndex( weekDay, 1 )
		if bGetSucss then
			local bGetTaskInfoSucess, taskInfo = self:getDayTaskInfo(weekDay, taskConfig.taskId)
			if bGetTaskInfoSucess and taskInfo.curValue == taskConfig.target then
				local oldNum = taskInfo.curValue-1
				if oldNum < 0 then oldNum = 0 end
				local info = { weekDay = weekDay, taskId=taskConfig.taskId, taskType = taskConfig.taskType, oldValue = oldNum, newValue = taskInfo.curValue}
				return true, info
			end
		end
	end
	return false, {}
end

function WeekTaskModel:taskAddNum( inTaskType, inAddNum  )
	local addNum = inAddNum or 1

	local completeTaskInfos = {}

	local perDayMap = self:getPerDayMap()
	for i,v in ipairs(perDayMap) do
		if addNum == 0 then
			break
		end

		for j,k in ipairs(v.tasks) do
			if not k.finished then
				local weekDay = i
				local taskId = k.taskId
				local curValue = k.curValue
                local taskType = self:getConst().TaskType.INVALID

				local bGetSucss, taskConfig = self:getTaskConfig( weekDay, taskId )
				if bGetSucss then
					taskType = taskConfig.taskType
				end

				--任务类型相同，并且还未增加过值
				if taskType == inTaskType then
					
					if bGetSucss then
						local target = taskConfig.target
						if k.curValue < target then
							local allNeedNum = target - k.curValue
							local canAddNum = 0
							if addNum < allNeedNum then
								canAddNum = addNum
							else
								canAddNum = allNeedNum
							end
							k.curValue = k.curValue + canAddNum

							--变更值的任务加入记录
							if k.curValue == target then
								if self:getCurDay() >= weekDay then
									local info = { weekDay = weekDay, taskId=taskId, taskType = taskType, oldValue = curValue, newValue = k.curValue}
									table.insert( completeTaskInfos, info )
								end
							end

							if not self:checkTaskCanAddAll(taskType) then
								--不能叠加的，要扣除已用的值
								addNum = addNum - canAddNum
								if addNum == 0 then
									break
								end
							end
						end
					end
				end
			end
		end
	end

	self:setDataByKey('perDays',perDayMap)

	return completeTaskInfos
end

return WeekTaskModel
