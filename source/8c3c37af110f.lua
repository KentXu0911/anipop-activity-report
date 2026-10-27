local BaseFeatureModel = require "amf.middleware.activity.base.BaseFeatureModel"
local Model = class("UnderTheSinModel", BaseFeatureModel)

function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "UnderTheSinModel"
    }):as("db")
end

function Model:_getConstPath()
	return "amf.feature.localactivity.underthesin.const.UnderTheSinConst"
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
    local const = self:getConst()
    local dayCount = const.DAY_COUNT
    local clueCount = const.CLUE_COUNT

    self._localCache = {}
    self.HealthShow = nil
    self.YinLiuPanelPopCount = nil
    self.MainPanelPanelPopCount = nil
    self.LocalGuideId100 = nil
    -- 上界跟活动天数走：低于天数时 key 没声明，saveFlagToLocalByKey 会被 write 限制拒写、标记存不下来
    for i = 1, dayCount do
        self["NewPageShow"..i] = nil
        self["newClueShare"..i] = nil 
        self["LocalGuideId"..(100 + i)] = nil
    end
    self.AwardTimeShowed = nil

    for i=1, dayCount do
        for j=1, clueCount do
            self["newClueShow" .. tostring(i) .. tostring(j)] = nil
        end
    end
end

function Model:setLocalCache(key, needTime, value)
    self:setLocalValueByKey("_localCache."..key, needTime, value)
end

function Model:getLocalCache(key, needTime)
    return self:getLocalValueByKey("_localCache."..key, needTime)
end

function Model:fromServer( data,skipSaveLocal )
    -- printx(41,"awijoihjoswopwd",tts(data),debug.traceback())
    for k,v in pairs(data) do
		self:setValue(k, v)
	end

	if not skipSaveLocal then
		self:flush()
	end
end

--判断数据是否准备就绪
function Model:isDataEnabled()
    -- printx(41,"d1")
	if not self:getValue("userInfo") then
        return false
    end
    -- printx(41,"d2")
    if table.isEmpty(self:getValue("userInfo")) then
        return false
    end
    -- printx(41,"d3")
    if not self:getValue("localConfig") then
        return false
    end
    -- printx(41,"d4")
    if table.isEmpty(self:getValue("localConfig")) then
        return false
    end
    -- printx(41,"d5")
    return true
end

function Model:getActBeginTime(  )
    return self:getBeginTime()
	-- if self:getDataByKey("actTime") then
	-- 	return self:getDataByKey("actTime").beginTime
	-- end
	-- return 0
end

function Model:getActMainBeginTime(  )
    return self:getMainBeginTime()
	-- if self:getDataByKey("actTime") then
	-- 	return self:getDataByKey("actTime").mainBeginTime
	-- end
	-- return 0
end

function Model:getActMainEndTime(  )
    return self:getMainEndTime()
	-- if self:getDataByKey("actTime") then
	-- 	return self:getDataByKey("actTime").mainEndTime
	-- end
	-- return 0
end

function Model:getActEndTime(  )
    return self:getEndTime()
	-- if self:getDataByKey("actTime") then
	-- 	return self:getDataByKey("actTime").endTime
	-- end
	-- return 0
end

function Model:isActInPre(  )
    return self:isInPreheatTime()
end

function Model:isInMainTime()
    local nowTime = TimeKit:timeInSec()
    -- printx(41,"nowTime",nowTime,TimeKit:tryConvertMsToSec(self:getMainBeginTime()),TimeKit:tryConvertMsToSec(self:getMainEndTime()))
    return nowTime > TimeKit:tryConvertMsToSec(self:getMainBeginTime()) and nowTime <= TimeKit:tryConvertMsToSec(self:getMainEndTime())
end

function Model:isActInMain(  )
    return self:isInMainTime()
end

function Model:isActInReward(  )
    return self:isInRewardTime()
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

function Model:_getLocalKey(key)
    return key
end
    
--------------------- 业务数据处理 ---------------------
function Model:passDayClear()
	--存储
	self:clearData()
end

-- 本地缓存
function Model:setLocalValueByKey(key, needTime, value)
    if not key then return end
    -- if bSkip == nil then bSkip = true end

    local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())
    local actBeginTime = self:getMainBeginTime() or 0

    local saveValue = {
        time = nowTime,
        value = value,
        actBeginTime = actBeginTime,
    }
    local saveStr = table.serialize(saveValue)

    self:setValue(key, saveStr, true)
end

function Model:getLocalValueByKey(key, needTime, needActStartTimeCheck)
    if not key then return end
    local saveJsonStr = self:getValue(key)
    if saveJsonStr == nil then return end
    if type(saveJsonStr) ~= "string" then return end

    local saveTable = table.deserialize(saveJsonStr)

    local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())
    local actBeginTime = self:getMainBeginTime() or 0

    local bTimeIsOk = true
    if needTime then
        if saveTable.time ~= nowTime then
            bTimeIsOk = false
        end
    end

    local versionIsOk = true
    if needActStartTimeCheck then
        if saveTable.actBeginTime ~= actBeginTime then
            versionIsOk = false
        end
    end

    if bTimeIsOk and versionIsOk then
        return saveTable.value
    end
end

-- 本地缓存 bool
function Model:saveFlagToLocalByKey(key, needTime, value, needActStartTimeCheck)
    if value == nil then value = true end
    self:setLocalValueByKey( key, needTime, value, needActStartTimeCheck )
end

function Model:getFlagFromLocalByKey(key, needTime, needActStartTimeCheck)
    local defaultValue = false
    local result = self:getLocalValueByKey(key, needTime, needActStartTimeCheck)
    if result == nil then 
        return defaultValue
    else
        return result
    end
end


-- 本地缓存int
function Model:saveFlagToLocalByKeyInt(key, needTime, value, needActStartTimeCheck)
    if value == nil then value = 0 end
    self:setLocalValueByKey( key, needTime, value, needActStartTimeCheck )
end

-- 添加一个add的方法
function Model:addIntToLocalByKey(key, needTime, addNum, needActStartTimeCheck)
    if not addNum then addNum = 1 end
    local value = self:getFlagFromLocalByKeyInt(key, needTime, needActStartTimeCheck, 0)
    self:setLocalValueByKey( key, needTime, value+addNum, needActStartTimeCheck )
end

function Model:getFlagFromLocalByKeyInt(key, needTime, needActStartTimeCheck, defaultValue)
    if defaultValue == nil then defaultValue = 0 end

    local result = self:getLocalValueByKey(key, needTime, needActStartTimeCheck)
    if result == nil then 
        return defaultValue
    else
        return result
    end
end

return Model
