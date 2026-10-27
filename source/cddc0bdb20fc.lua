---@class BaseFeatureModel : AMFDataRef
local BaseFeatureModel = class("BaseFeatureModel", AMFDataRef)
-- 子类实现一下

function BaseFeatureModel:ctor()
    self:declare("lastSavedTime")
end

function BaseFeatureModel:_getConstPath()
end

function BaseFeatureModel:_initConst()
    local path = self:_getConstPath()
    if not path then
        return
    end

    local const = require(path)
    self:setTempData("_const", const)
    return const
end


function BaseFeatureModel:getConst()
    local const = self:getTempData("_const")
    if not const then
        const = self:_initConst()
    end
    return const
end


function BaseFeatureModel:isLastDay()
    local todayStartTime = TimeKit:getTodayStart()
    local lastDayStartTime = TimeKit:getDayStartTimeByTS(TimeKit:tryConvertMsToSec(self:getMainEndTime()))
    return todayStartTime == lastDayStartTime
end

-- 获取服务器时间是活动周期内的第几天
function BaseFeatureModel:getDayFromActOpen( time )
    local startTime = TimeKit:getDayStartTimeByTS(TimeKit:tryConvertMsToSec(self:getMainBeginTime()))
    local curTime = TimeKit:getDayStartTimeByTS(TimeKit:tryConvertMsToSec(time) or TimeKit:timeInSec())
    return math.floor((curTime-startTime)/86400)+1
end

-- 获取从1970.1.1开始服务器时间是第几天
function BaseFeatureModel:getDayFrom1970( time )
    local curDayStartTime = TimeKit:getDayStartTimeByTS(TimeKit:tryConvertMsToSec(time) or TimeKit:timeInSec())
    return math.ceil(curDayStartTime/86400)
end

function BaseFeatureModel:setDataByKey(key, value, needSave)
    local dataKeyChainPrefix = self:_getDataKeyChainPrefix()
    if dataKeyChainPrefix then
        key = dataKeyChainPrefix .. "." ..key
    end
    self:setValue(key, value, needSave)
end

function BaseFeatureModel:getDataByKey(key, default)
    local dataKeyChainPrefix = self:_getDataKeyChainPrefix()
    if dataKeyChainPrefix then
        key = dataKeyChainPrefix .. "." ..key
    end

    return self:getValue(key) or default
end

function BaseFeatureModel:setConfigByKey(key, value, needSave)
    local configKeyChainPrefix = self:_getConfigKeyChainPrefix()
    if configKeyChainPrefix then
        key = configKeyChainPrefix .. "." ..key
    end
    self:setValue(key, value, needSave)
end

function BaseFeatureModel:getConfigByKey(key, default)
    local configKeyChainPrefix = self:_getConfigKeyChainPrefix()
    if configKeyChainPrefix then
        key = configKeyChainPrefix .. "." ..key
    end

    return self:getValue(key) or default
end

-- 本地缓存
function BaseFeatureModel:setLocalValueByKey(key, needTime, value)
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

function BaseFeatureModel:getLocalValueByKey(key, needTime, needActStartTimeCheck)
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
function BaseFeatureModel:saveFlagToLocalByKey(key, needTime, value, needActStartTimeCheck)
    if value == nil then value = true end
    self:setLocalValueByKey( key, needTime, value, needActStartTimeCheck )
end

function BaseFeatureModel:getFlagFromLocalByKey(key, needTime, needActStartTimeCheck)
    local defaultValue = false
    local result = self:getLocalValueByKey(key, needTime, needActStartTimeCheck)
    if result == nil then
        return defaultValue
    else
        return result
    end
end


-- 本地缓存int
function BaseFeatureModel:saveFlagToLocalByKeyInt(key, needTime, value, needActStartTimeCheck)
    if value == nil then value = 0 end
    self:setLocalValueByKey( key, needTime, value, needActStartTimeCheck )
end

function BaseFeatureModel:getFlagFromLocalByKeyInt(key, needTime, needActStartTimeCheck, defaultValue)
    if defaultValue == nil then defaultValue = 0 end

    local result = self:getLocalValueByKey(key, needTime, needActStartTimeCheck)
    if result == nil then
        return defaultValue
    else
        return result
    end
end

-- 本地缓存str
function BaseFeatureModel:saveFlagToLocalByKeyStr(key, needTime, value, needActStartTimeCheck)
    if value == nil then value = "" end
    self:setLocalValueByKey( key, needTime, value, needActStartTimeCheck )
end

function BaseFeatureModel:getFlagFromLocalByKeyStr(key, needTime, needActStartTimeCheck)
    local defaultValue = ""

    local result = self:getLocalValueByKey(key, needTime, needActStartTimeCheck)
    if result == nil then
        return defaultValue
    else
        return result
    end
end

function BaseFeatureModel:clearData()
    self:reset()
end

function BaseFeatureModel:isInPreheatTime()
    local nowTime = TimeKit:timeInSec()
    return nowTime > TimeKit:tryConvertMsToSec(self:getBeginTime()) and nowTime <= TimeKit:tryConvertMsToSec(self:getMainBeginTime())
end

function BaseFeatureModel:isInMainTime()
    local nowTime = TimeKit:timeInSec()
    return nowTime > TimeKit:tryConvertMsToSec(self:getMainBeginTime()) and nowTime <= TimeKit:tryConvertMsToSec(self:getMainEndTime())
end

function BaseFeatureModel:isInRewardTime()
    local nowTime = TimeKit:timeInSec()
    return nowTime > TimeKit:tryConvertMsToSec(self:getMainEndTime()) and nowTime <= TimeKit:tryConvertMsToSec(self:getEndTime())
end

function BaseFeatureModel:getBeginTime()
    local key = self:_getTimeKey("beginTime")
    return self:getValue(key) or 0
end

function BaseFeatureModel:getMainBeginTime()
    local key = self:_getTimeKey("mainBeginTime")
    return self:getValue(key) or 0
end

function BaseFeatureModel:getEndTime()
    local key = self:_getTimeKey("endTime")
    return self:getValue(key) or 0
end

function BaseFeatureModel:getMainEndTime()
    local key = self:_getTimeKey("mainEndTime")
    return self:getValue(key) or 0
end

function BaseFeatureModel:_getTimeKey(key)
    local keyPrefix = self:getConst().timePrefix or ""
    return keyPrefix .. "." .. key
end

function BaseFeatureModel:_getDataKeyChainPrefix()
    return self:getConst().infoPrefix or ""
end

function BaseFeatureModel:_getConfigKeyChainPrefix()
    return self:getConst().configPrefix or ""
end

function BaseFeatureModel:_getLocalSaveKey(key)
    local name = self:getClassName()
    local str = string.format("%s_%s_%s", name, self:getConst().actOpenVersion, key)

    local localConfigKey = self:getConst().localConfigKey
    str = localConfigKey .. "." .. str
    return str
end

return BaseFeatureModel