local BaseFeatureModel = require "amf.middleware.activity.base.BaseFeatureModel"
local Model = class("Recall2025Model", BaseFeatureModel)

function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "Recall2025Model"
    }):as("db")

    self:installPlug(AMFDataPlugsType.SYNC, {
        requests = {
            bonusInfo = "amf.feature.recall.recall2025.http.RequestCallback2025Bonus",
        }
    })
end

function Model:_getConstPath()
	return "amf.feature.recall.recall2025.const.Recall2025Const"
end 

-- Model
function Model:__declare()
    self:_initLocalData()
    self:_initLocalConfig()
    self:_initLocalKey()
end

function Model:isDataEnabled()
    if not self:getDataByKey("periodId") then
        return false
    end
    return true
end

function Model:requestCallback2025Bonus()
    return self.syncPlug:requestBonusInfo({
        day = self:getDayFrom1970(),
    })
end

function Model:onResponseCallback2025Bonus(response)
    if response:isSuccess() then
        local data = response:getData()
        self:setDataByKey("buffStep20EndTs", data.buffStep20EndTs)
        self:setDataByKey("bonusDays", data.bonusDays)
        self:setDataByKey("unlockAreaDays", data.unlockAreaDays)

        self:fillScoreBottle()
    elseif response:getErrorCode() == 739129 then
        self:fillScoreBottle()
    end
end

-- 填满加分瓶
function Model:fillScoreBottle()
    local module = _G.amfBean("WinningStreakManager"):getModule(WSConst.ModuleType.BOTTLE)
    local mgr = module:getMgr()
    mgr:fillWinningNum()
    mgr:setIsFullShow(true)
end

function Model:assignData(data)
    if not data or table.isEmpty(data) then
        return
    end

    local userInfo = {}
    userInfo.periodId = data.periodId
    userInfo.group = data.group
    userInfo.beginTime = math.floor(tonumber(data.triggerTs) / 1000)
    userInfo.mainBeginTime = math.floor(tonumber(data.triggerTs) / 1000)
    userInfo.mainEndTime = math.floor(tonumber(data.mainEndTs) / 1000)
    userInfo.endTime = math.floor(tonumber(data.endTs) / 1000)
    userInfo.buffStep20EndTs = data.buffStep20EndTs
    userInfo.bonusDays = data.bonusDays
    userInfo.unlockAreaDays = data.unlockAreaDays

    local localConfig = {}
    localConfig.maxBonusCount = data.maxBonusCount

    self:setValue("userInfo", userInfo)
    self:setValue("localConfig", localConfig)
end

function Model:_initLocalData()
    self.userInfo = {}
end

function Model:_initLocalConfig()
    self.localConfig = {}
end

function Model:_initLocalKey()
    self._localCache = {}
end

function Model:setLocalCache(key, value)
    self:setValue("_localCache."..key, value)
end

function Model:getLocalCache(key)
    return self:getValue("_localCache."..key)
end

function Model:getActRealEndTime()
    if self:checkCanGetRightsTomorrow() then
        return math.max(self:getMainEndTime(), self:getBuffStep20EndTime())
    else
        if self:isInMainTime() and not self:checkTodayRightsGot() and not self:checkRightsAllGot() then
            return self:getMainEndTime()
        else
            return self:getBuffStep20EndTime()
        end
    end
end

function Model:getDayCount()
    local day = self:getDataByKey("bonusDays", {})
    local nowDay = self:getDayFrom1970()
    if table.exist(day, nowDay) then
        return #day
    else
        return #day + 1
    end
end

-- 权益全领完了
function Model:checkRightsAllGot()
    local bonusDays = self:getDataByKey("bonusDays", {})
    local maxBonusCount = self:getConfigByKey("maxBonusCount", 0)
    return  #bonusDays == maxBonusCount and maxBonusCount > 0 
end

-- 检测今天权益是否领过了
function Model:checkTodayRightsGot()
    local today = self:getDayFrom1970()
    local bonusDays = self:getDataByKey("bonusDays") or {}
    return table.exist(bonusDays, today)
end

function Model:checkCanGetRightsTomorrow()
    if not self:isInMainTime() then return false end
    if self:checkRightsAllGot() then return false end
    local nowTime = TimeKit:timeInSec()
    local endTime = self:getMainEndTime()

    if nowTime + 86400 > endTime then
        return false
    end

    return true
end

-- 检测今天是否用过了免费解锁的权益
function Model:checkTodayUnlockFreeUsed()
    local today = self:getDayFrom1970()
    local unlockAreaDays = self:getDataByKey("unlockAreaDays", {})
    return table.exist(unlockAreaDays, today)
end

function Model:setTodayUnlockFreeUsed()
    local today = self:getDayFrom1970()
    local unlockAreaDays = self:getDataByKey("unlockAreaDays", {})
    table.insert(unlockAreaDays, today)
    self:setDataByKey("unlockAreaDays", unlockAreaDays, true, true)
end

-- 是否可以用+20步
function Model:checkCanUse20Buff()
    local buffStep20EndTs = tonumber(self:getDataByKey("buffStep20EndTs", 0))
    local nowTime = TimeKit:timeInMillis()
    return nowTime < buffStep20EndTs
end

function Model:getBuffStep20EndTime()
    local buffStep20EndTs = tonumber(self:getDataByKey("buffStep20EndTs", 0))
    return math.floor(buffStep20EndTs/1000)
end

return Model