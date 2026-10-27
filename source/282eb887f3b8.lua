local BaseFeatureModel = require "amf.middleware.activity.base.BaseFeatureModel"
local WeekTaskEventCenter = require 'amf.feature.localactivity.weektask.event.WeekTaskEventCenter'
local Model = class("TeamCampingModel", BaseFeatureModel)

function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "TeamCampingModel"
    }):as("db")

    self:installPlug(AMFDataPlugsType.SYNC, {
        requests = {
            getPreInfo = "amf.feature.localactivity.teamcamping.http.TeamCamping2025PreInfo",
        }
    })
end

function Model:requestGetPreInfo(onSuceess,onFail)
    self.syncPlug:requestGetPreInfo():next(onSuceess,onFail)
end

function Model:getDataByKey(key,default)
    local value = BaseFeatureModel.getDataByKey(self,key,default)
    if default == value and self:getConfigByKey(key) then 
        local _tag = styleConsoleText("配置里有数据，data里没有", hex2ccc3("ff3333"))
    end 
    return value 
end

function Model:_getConstPath()
	return "amf.feature.localactivity.teamcamping.const.TeamCampingConst"
end


function Model:__declare()
    self.localConfig = {}
    self.timeInfo = {}
    self._localCache = {}

    self.isFromServer = nil
    self.guideInfo = {}
    self.mainLotteryState = nil
    self.power = nil
    self.serverVersionedConfig = {
        config = {periodId = nil}
    }
    self.haveInvite = nil
    self.actTime = nil
    self.recall = nil
    self.bigReward = nil
    self.mainLotteryPowerTimes = nil
    self.scoreBuff20EndTime = nil
    self.collectBuffList = {}
    self.totalProgress = nil
    self.buildList = nil
    self.payTag = nil

end

function Model:setCache(key, value)
    self:setValue("_localCache."..key, value)
end

function Model:getCache(key,default)
    return self:getValue("_localCache."..key) or default
end


function Model:fromServer(data)
    local configPrefix = self:getConst().configPrefix or ""
    if data[configPrefix] and tonumber(data[configPrefix].period) ~= tonumber(self:getConfigByKey("periodId", 0)) then
        self:clearData()
    end
    for k, v in pairs(data) do
        local value = v 
        if k == "serverVersionedConfig" then 
            value.config = table.deserialize(v.config)
        end 
        self:setValue(k, value)
    end
end

function Model:getConfigByKey(key, default)
    local ret = BaseFeatureModel.getConfigByKey(self, key, default)
    if type(ret) == "table" then 
        return table.clone(ret)
    end 
    return ret
end


function Model:getClientMd5()
    do return ' ' end 
    return self:getValue("serverVersionedConfig.serverMd5") or ""
end

function Model:getPeriodId()
    return self:getConfigByKey("periodId", 0)
end



function Model:isActInMain(  )
    local now = TimeKit:timeInSec()
    local beginTime = self:getMainBeginTime()
    local endTime = self:getMainEndTime()
    if not beginTime or not endTime then return false end 
    return now >= beginTime and now <= endTime
end

function Model:isActInReward(  )
    local now = TimeKit:timeInSec()
    local beginTime = self:getMainEndTime()
    local endTime = self:getEndTime()
    if not beginTime or not endTime then return false end 
    return now >= beginTime and now <= endTime
end




function Model:setGuide( index )
	local guideInfo = self:getDataByKey("guideInfo", {})
	table.insert(guideInfo, index)
	self:setDataByKey("guideInfo", guideInfo)
end

function Model:hasGuide( index )
	local guideInfo = self:getDataByKey("guideInfo", {}, false)
	return table.find(guideInfo, function ( v )
		return v == index
	end)
end


--------------------- 每次需要修改的函数 ---------------------

function Model:isBaseDataEnabled()
	if self:getValue("power") == nil then
        return false
    end
	return true
end

--判断数据是否准备就绪
function Model:isDataEnabled()
	if self:getValue("power") == nil then
        return false
    end

	if not self:isActInMain() then
		return false,3
	end

	if not self:getValue("serverVersionedConfig") or not self:getValue("serverVersionedConfig.config") then
		return false,4
	end

    return true
end


function Model:onPassDay()
end


--------------------- 业务数据处理 ---------------------
function Model:getPayTag()
    return self:getDataByKey("payTag", 0)
end

function Model:getActiveTag()
    if self:getDataByKey("recall", false) then
        return 5
    else
        local tag = _G.amfBean("UserTagManager"):getUserTagBySeries(UserTagNameKeyFullMap.kLiveness)
        if tag >= UserTagValueMap[UserTagNameKeyFullMap.kLiveness].kLowUser then
            return tag - 2
        end
    end
    return 5
end

--获取已经组队的队伍列表
function Model:getTeamGroups()
    local buildList = self:getDataByKey("buildList",{})
	local list = {}
	for k,v in pairs(buildList) do 
		if v.state ~= self:getConst().GroupState.Empty then 
			table.insert(list,v.buildId)
		end 
	end 
	return list
end

function Model:getBuildNowLv(id)
	local value,min,max,isFullLevel = self:getBuildProgress(id)
    local lvMap = self:getLvMap()
	local lv = lvMap[min] or 0 
	return lv 
end

function Model:syncBuildProgress(id,progress)
    local beforeLv = self:getBuildNowLv(id)
    local buildList = self:getDataByKey("buildList",{})
    for k,v in pairs(buildList) do
        if v.buildId == id then
            v.lastRewardProgress = progress or (v.mateProgress + v.selfProgress)
            v.mateLastProgress = v.mateProgress
        end
    end
    self:setDataByKey("buildList",buildList)
    local newLv = self:getBuildNowLv(id)
    if newLv > beforeLv then
        --发个事件
        local upLevel = newLv - beforeLv
        
        WeekTaskEventCenter:dispatch(_G.WeekTaskEvent.ACT_TASK_COMPLETE, { type=_G.WeekTaskType.GROUP_ACT_BUILD_LEVELUP, num=upLevel})
    end
end


function Model:syncBuildMateProgress(id,progress)
    local buildList = self:getDataByKey("buildList",{})
	for k,v in pairs(buildList) do 
		if v.buildId == id then 
			v.mateLastProgress = v.mateProgress
		end 
	end 
	self:setDataByKey("buildList",buildList)
end



function Model:getBuildProgress(id)
    local buildList = self:getDataByKey("buildList",{})
	local lastRewardProgress = 0
	local allProgress = 0
	for k,v in pairs(buildList) do 
		if v.buildId == id then 
			lastRewardProgress = v.lastRewardProgress
			allProgress = v.mateProgress + v.selfProgress
		end 
	end 
	local buildProgressRewards = self:getConfigByKey("buildProgressRewards",{})
	local min = 0	
	local max = 999999999
	for k,v in pairs(buildProgressRewards) do 
		local needNum = tonumber(v.needNum)
		if lastRewardProgress >= needNum then
			min = math.max(min,needNum)
		else
			max = math.min(max,needNum)
		end 
	end
	local isFullLevel = max == 999999999
	return allProgress,min,max ,isFullLevel
	
end


local lvMap
function Model:getLvMap()
	if not lvMap then 
		local buildProgressRewards = self:getConfigByKey("buildProgressRewards",{})
		local needNumList = {}
		for k,v in pairs(buildProgressRewards) do 
			local needNum = tonumber(v.needNum)
			table.insert(needNumList,needNum)
		end 
		table.sort(needNumList,function(a,b) return a < b end)
		lvMap = {}
		for lv,needNum in pairs(needNumList) do 
			lvMap[needNum] = lv
		end 
	end 
	return lvMap
end

function Model:getBuffRateAndTime()
	local collectBuffList = self:getDataByKey("collectBuffList", {})
    local nowTime = TimeKit:timeInSec()
    local nextTime
    local rate = 1
    for i, v in pairs(collectBuffList) do
        local t = math.floor(tonumber(v.endTime) / 1000)
        if t > nowTime then
            if not nextTime then
                nextTime = t
            else
                nextTime = math.min(nextTime, t)
            end

            if self:getConst().buffTimesMap[tonumber(v.itemId)] then
                rate = rate * self:getConst().buffTimesMap[tonumber(v.itemId)]
            end
        end
    end
    return rate, nextTime
end

function Model:add20BuffEndTime( minutes)
	local collectBuffList = self:getDataByKey("collectBuffList", {})
    local nowTime = TimeKit:timeInSec()
    local nextTime
    local rate = 1
	local hasAdd = false 
    for i, v in pairs(collectBuffList) do
		if v.itemId == self:getConst().powerBuffId2 then 
			local t = math.max(v.endTime,TimeKit:timeInMillis())
			v.endTime = t + minutes * 60 * 1000
			hasAdd = true 
		end 
    end
	if not hasAdd then 
		--可能不存在
		table.insert(collectBuffList,{
			itemId = self:getConst().powerBuffId2,
			endTime = TimeKit:timeInMillis() + minutes * 60 * 1000
		})
	end 
	self:setDataByKey("collectBuffList",collectBuffList)
end


function Model:add50BuffEndTime( minutes)
	local collectBuffList = self:getDataByKey("collectBuffList", {})
    local nowTime = TimeKit:timeInSec()
    local nextTime
    local rate = 1
	local hasAdd = false 
    for i, v in pairs(collectBuffList) do
		if v.itemId == self:getConst().powerBuffId1 then 
			local t = math.max(v.endTime,TimeKit:timeInMillis())
			v.endTime = t + minutes * 60 * 1000
			hasAdd = true  
		end 
    end
	if not hasAdd then 
		table.insert(collectBuffList,{
			itemId = self:getConst().powerBuffId1,
			endTime = TimeKit:timeInMillis() + minutes * 60 * 1000
		})
	end 
	self:setDataByKey("collectBuffList",collectBuffList)
end

function Model:addScoreBuffEndTime(minutes)
	local buffTime = tonumber(self:getDataByKey("scoreBuff20EndTime",0))
	buffTime = math.max(buffTime,TimeKit:timeInMillis())
	self:setDataByKey("scoreBuff20EndTime",buffTime + minutes * 60 * 1000)
end


function Model:getCashMinMax(str)
	if not str or type(str) ~= "string" then return 0,0 end 
	local array = string.split(str,"~")
	return tonumber(array[1]),tonumber(array[2])
end

function Model:getTotalProgressRewards()
	return self:getDataByKey("totalProgressRewards", {})
end

function Model:getTotalProgressLoopReward()
	return self:getDataByKey("totalProgressLoopReward", {})
end

function Model:getTotalProgressLoopPeriod()
	return self:getDataByKey("totalProgressLoopPeriod", 3000)
end

function Model:getTotalProgress()
	return self:getDataByKey("totalProgress", 0)
end

function Model:getLastRewardTotalProgress()
    return self:getDataByKey("lastRewardTotalProgress", 0)
end

function Model:setLastRewardTotalProgress(progress)
    progress = progress or self:getTotalProgress()
    self:setDataByKey("lastRewardTotalProgress", progress, true)
end

function Model:getBuildProgressMaxScore()
	local rewardsConfig = self:getConfigByKey("buildProgressRewards", {})
	local len = table.length(rewardsConfig)
	local maxValue = rewardsConfig[len].needNum
	return maxValue or 0
end

function Model:getTurnTableConfig(isSuper, isMain)
    if isMain then
        if isSuper then
            local c = self:getConfigByKey("mainTurntableBigSlotMetaList", {})
            for k, v in ipairs(c) do
                v.type = k % 2 == 0 and 8 or 7
            end
            return c
        else
            return self:getConfigByKey("mainTurntableSlotMetaList", {})
        end
    else
        if isSuper then
            local c = self:getConfigByKey("turntableBigSlotMetaList", {})
            for k, v in ipairs(c) do
                v.type = k % 2 == 0 and 8 or 7
            end
            return c
        else
            return self:getConfigByKey("turntableSlotMetaList", {})
        end
    end
end

function Model:_getProgressRewardIndexByProgress(totalProgress)
    local normalConfig = self:getTotalProgressRewards()
    local lastMeta = normalConfig[table.length(normalConfig)] or {}
    local lastNum = lastMeta.needNum

    if totalProgress < lastNum then
        for k, v in ipairs(normalConfig) do
            if v.needNum > totalProgress then
                return k
            end
        end
    else
        totalProgress = totalProgress - lastNum
        local progressMax = self:getTotalProgressLoopPeriod()
        local index = math.floor(totalProgress / progressMax) + 1
        return index + table.length(normalConfig)
    end
end

function Model:checkHaveInvite()
    return self:getDataByKey("haveInvite", false)
end

function Model:setHaveInvite(b)
    self:setDataByKey("haveInvite", b)
end


return Model
