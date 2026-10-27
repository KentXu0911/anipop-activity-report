local BaseFeatureModel = require "amf.middleware.activity.base.BaseFeatureModel"
local Model = class("MagicRushModel", BaseFeatureModel)

local function toSeconds(value)
    local numberValue = tonumber(value) or 0
    if numberValue > 10000000000 then
        numberValue = numberValue / 1000
    end
    return math.floor(numberValue)
end

function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "MagicRushModel"
    }):as("db")

    self:installPlug(AMFDataPlugsType.SYNC, {
        requests = {
            mainInfo = "amf.feature.localactivity.magicrush.http.RequestMagic1v1Info",
            join = "amf.feature.localactivity.magicrush.http.RequestMagic1v1Join",
            settle = "amf.feature.localactivity.magicrush.http.RequestMagic1v1Settle",
            query = "amf.feature.localactivity.magicrush.http.RequestMagic1v1Query",
        }
    })
end

function Model:isDataEnabled()
    return self:getValue("userInfo.myInfo") and self:getValue("activityTime")
end

function Model:isIconV2ActivityInfoReady()
    local periodId = self:getDataByKey("periodId")
    if periodId == nil or periodId == "" then
        return false
    end

    local beginTime = toSeconds(self:getBeginTime())
    local mainBeginTime = toSeconds(self:getMainBeginTime())
    local mainEndTime = toSeconds(self:getMainEndTime())
    local endTime = toSeconds(self:getEndTime())
    return beginTime > 0
        and beginTime <= mainBeginTime
        and mainBeginTime < mainEndTime
        and mainEndTime <= endTime
end

function Model:isIconV2PKDataReady()
    return self:isDataEnabled() and true or false
end

function Model:_getConstPath()
	return "amf.feature.localactivity.magicrush.const.MagicRushConst"
end

-- Model
function Model:__declare()
    self:_initLocalData()
    self:_initLocalConfig()
    self:_initLocalCache()
end

function Model:_initLocalData()
    self.userInfo = {}
    self.activityTime = {}
end

function Model:_initLocalConfig()
    self.localConfig = {}
end

function Model:_initLocalCache()
    self._localCache = {}
    self.magicRushDailyPopupFlag = false
    self.inLevelCardParticipatedEndTime = nil
    self.magicRushWinCountPopFlag = false
end

function Model:setLocalCache(key, value)
    self:setValue("_localCache."..key, value)
end

function Model:getLocalCache(key)
    return self:getValue("_localCache."..key)
end

function Model:requestQuery(params)
    return self.syncPlug:requestQuery(params)
end

function Model:onResponseMagic1v1Query(response)
    if response:isSuccess() then
        local data = response:getData()
        if data then
            self:assignQueryData(data)
        end
    end
end

function Model:requestSettle(params)
    return self.syncPlug:requestSettle(params)
end

function Model:onResponseMagic1v1Settle(response)
    if response:isSuccess() then
        local data = response:getData()
        if data then
            self:assignSettleData(data)
        end
    end
end

function Model:requestJoin(params, loading)
    return self.syncPlug:requestJoin(params, loading)
end

function Model:onResponseMagic1v1Join(response)
    if response:isSuccess() then
        local data = response:getData()
        if data then
            self:setLocalCache("firstMatchShow", false)
            self:setLocalCache("firstMatchShowDouble", false)
            self:assignJoinData(data)
        end
    end
end

function Model:requestMainInfo(params)
    return self.syncPlug:requestMainInfo(params)
end

function Model:onResponseMagic1v1Info(response)
    if response:isSuccess() then
        local data = response:getData()
        if data then
            local localConfig = {}

            if data.extra and data.extra ~= "" then
                if data.extra.config ~= "" then
                    localConfig = table.deserialize(data.extra.config) or {}
                    data.clientMd5 = data.extra.serverMd5
                end
                data.extra = nil
            end

            if data.serverVersionedConfig and data.serverVersionedConfig ~= "" and data.serverVersionedConfig.config then
                localConfig = table.deserialize(data.serverVersionedConfig.config) or {}
                data.clientMd5 = data.serverVersionedConfig.serverMd5
                data.serverVersionedConfig = nil
            end

            local activityTime = {
                beginTime = TimeKit:tryConvertMsToSec(data.beginTime),
                endTime = TimeKit:tryConvertMsToSec(data.endTime),
                mainBeginTime = TimeKit:tryConvertMsToSec(data.mainBeginTime),
                mainEndTime = TimeKit:tryConvertMsToSec(data.mainEndTime),
            }

            data.beginTime = nil
            data.endTime = nil
            data.mainBeginTime = nil
            data.mainEndTime = nil

            local ret = {
                userInfo = data,
                activityTime = activityTime,
                localConfig = localConfig,
            }

            self:assignData(ret)
        end
    end
end

function Model:assignQueryData(data)
    self:setDataByKey("matchRefBean.matchInfo", data.matchRefBean.matchInfo)
    self:setDataByKey("myInfo", data.myInfo)
    self:setDataByKey("myHistoryInfo", data.myHistoryInfo)
    self:setDataByKey("winRecords", data.winRecords)
    self:setDataByKey("pkStatusInfo", data.pkStatusInfo)
end

function Model:assignData(data)
    if not data then return end
    if not data.activityTime or not next(data.activityTime) then return end
    self:setValue("activityTime", data.activityTime)
    self:setValue("userInfo", data.userInfo)
    if data.localConfig and not table.isEmpty(data.localConfig) then
        self:setValue("localConfig", data.localConfig)
    end
end

function Model:assignJoinData(data)
    self:setDataByKey("todayJoinPkCount", data.todayJoinPkCount)
    self:setDataByKey("pkStatusInfo", data.pkStatusInfo)
    self:setDataByKey("matchRefBean", data.matchRefBean)
end

function Model:assignSettleData(data)
    self:setDataByKey("pkStatusInfo", data.pkStatusInfo)
    self:setDataByKey("matchRefBean", data.matchRefBean)
    self:setDataByKey("myInfo", data.myInfo)
    self:setDataByKey("myHistoryInfo", data.myHistoryInfo)

    local state = self:getAndRefreshPKState()
    if state == self:getConst().PKState.PREPARE then
        self:resetShowScore()
    end

    if data.roundFixRewards then
        self:setDataByKey("roundFixRewards", data.roundFixRewards)
    end
    if data.roundCirleRewards then
        self:setDataByKey("roundCirleRewards", data.roundCirleRewards)
    end
    if data.roundTotalRewards then
        self:setDataByKey("roundTotalRewards", data.roundTotalRewards)
    end
end

function Model:assignActInfo(data)
    local extraData
    if data and data.extra and type(data.extra) == "string" then
        extraData = table.deserialize(data.extra)
    end

    if not extraData then
        return
    end

    local oldPeriodId = self:getDataByKey("periodId")
    -- 跨期清数据
    if oldPeriodId and oldPeriodId ~= extraData.periodId then
        self:reset()
    end

    self:setValue("activityTime.beginTime", TimeKit:tryConvertMsToSec(extraData.beginTime))
    self:setValue("activityTime.endTime", TimeKit:tryConvertMsToSec(extraData.endTime))
    self:setValue("activityTime.mainBeginTime", TimeKit:tryConvertMsToSec(extraData.mainBeginTime))
    self:setValue("activityTime.mainEndTime", TimeKit:tryConvertMsToSec(extraData.mainEndTime))
    self:setValue("userInfo.periodId", extraData.periodId)
    self:setValue("userInfo.group", extraData.group)
    self:setValue("userInfo.joinRewards", extraData.joinRewards)
    self:setValue("userInfo.canEnergy", extraData.canEnergy)
    self:setValue("userInfo.actType", extraData.actType)
end

function Model:getActType()
    return self:getValue("userInfo.actType")
end

function Model:addMyPKContinueWinNum()
    local pkContinueWinNum = self:getDataByKey("matchRefBean.matchInfo.continueWin") or 0
    self:setDataByKey("matchRefBean.matchInfo.continueWin", pkContinueWinNum + 1)
end

function Model:resetMyPKContinueWinNum()
    self:setDataByKey("matchRefBean.matchInfo.continueWin", 0)
end

function Model:addMyScore(score)
    if not score then return end
    local myScore = self:getDataByKey("matchRefBean.matchInfo.me.score") or 0
    self:setDataByKey("matchRefBean.matchInfo.me.score", myScore + score)
end

function Model:setEnemyScore(score)
    local pkState = self:getAndRefreshPKState()
    if pkState == self:getConst().PKState.INGAME then
        local matchInfo = self:getDataByKey("matchRefBean.matchInfo") or {}
        matchInfo.enemy.score = score
        self:setDataByKey("matchRefBean.matchInfo", matchInfo)
    end
end

-- 是否可以被邀请
function Model:checkCanBeInvited()
    local canJoin = self:checkHasLeftTimes()
    local pkState = self:getAndRefreshPKState()
    return canJoin and pkState == self:getConst().PKState.PREPARE
end

-- 是否是大奖轮
function Model:checkIsContinueRewardRound()
    local myInfo = self:getDataByKey("myInfo") or {}
    local interval = self:getConst().ContinueWinInterval
    local winNum = myInfo.pkWinNum or 0
    if self:getAndRefreshPKState() == self:getConst().PKState.TO_BE_SETTLED_1
        or self:getAndRefreshPKState() == self:getConst().PKState.TO_BE_SETTLED_2 then
            winNum = winNum - 1
    end
    return winNum % interval == (interval - 1)
end

-- 是否有奖励
-- 1. PK状态为待结算1，且赢了
-- 2. PK状态为待结算2
function Model:isToBeSettledAndHasReward()
    local pkState = self:getAndRefreshPKState()
    if pkState ~= self:getConst().PKState.TO_BE_SETTLED_1 and pkState ~= self:getConst().PKState.TO_BE_SETTLED_2 then
        return false
    end

    local matchInfo = self:getDataByKey("matchRefBean.matchInfo") or {
        me = {score = 0},
        enemy = {score = 0}
    }
    local hasReward = matchInfo.me.score > matchInfo.enemy.score
    return(pkState == self:getConst().PKState.TO_BE_SETTLED_1 and hasReward) or
        pkState == self:getConst().PKState.TO_BE_SETTLED_2
end

-- 获取并刷新PK状态
function Model:getAndRefreshPKState()
    local pkStatusInfo = self:getDataByKey("pkStatusInfo") or {}
    local status = pkStatusInfo.pkStatus
    if status == self:getConst().PKState.INGAME then
        local matchInfo = self:getDataByKey("matchRefBean.matchInfo",{})
        local nowTime = TimeKit:timeInMillis()
        local endTime = tonumber(matchInfo.endTime) or (nowTime + 10)
        if nowTime > endTime then
            status = self:getConst().PKState.TO_BE_SETTLED_1
            pkStatusInfo.pkStatus = status
            self:setDataByKey("pkStatusInfo",pkStatusInfo)
        end
    end

    return status
end

function Model:getPKStateSnapshot()
    local pkStatusInfo = self:getDataByKey("pkStatusInfo") or {}
    return pkStatusInfo.pkStatus
end

function Model:getMatchEndTime()
    return TimeKit:tryConvertMsToSec(self:getDataByKey("matchRefBean.matchInfo.endTime") or 0)
end

--今天是否还有剩余次数
function Model:checkHasLeftTimes()
    local joinCountLimit = self:getTodayLimitNum()
    local todayJoinPkCount = self:getDataByKey("todayJoinPkCount",0)
    return todayJoinPkCount < joinCountLimit
end

function Model:resetTodayJoinCount()
    self:setDataByKey("todayJoinPkCount", 0)
end

function Model:getAllJoinCount()
    local dayJoinLimitStr = self:getConfigByKey("joinStr")
    if not dayJoinLimitStr then
        return 0
    end
    local ret = string.split(dayJoinLimitStr,',')
    local num = 0
    for k,v in pairs(ret) do
        num = num + v
    end
    return num
end

--今日限定次数
function Model:getTodayLimitNum()
    local dayJoinLimitStr = self:getConfigByKey("joinStr")
    if not dayJoinLimitStr then
        return 0
    end
    local ret = string.split(dayJoinLimitStr,',')
    local day = self:getDayFromActOpen()

    return tonumber(ret[day]) or 0
end

--今日剩余次数
function Model:getTodayLeftTimes()
    local limitTime = self:getTodayLimitNum()
    local todayJoinPkCount = self:getDataByKey("todayJoinPkCount") or 0
    return limitTime - todayJoinPkCount
end

function Model:getDoubleStartTime()
    return self:getDataByKey("matchRefBean.matchInfo.doubleBuffStartTime") or 0
end

function Model:getDoubleEndTime()
    return self:getDataByKey("matchRefBean.matchInfo.doubleBuffEndTime") or 0
end

-- 是否双倍
function Model:isInDoubleState()
    local state = self:getAndRefreshPKState()
    if state == self:getConst().PKState.INGAME then
        local matchInfo = self:getDataByKey("matchRefBean.matchInfo") or {}
        local doubleBuffStartTime = tonumber(matchInfo.doubleBuffStartTime) or 0
        local doubleBuffEndTime = tonumber(matchInfo.doubleBuffEndTime) or 0
        local nowTime = TimeKit:timeInMillis()
        return nowTime >= doubleBuffStartTime and nowTime < doubleBuffEndTime
    end

    return false
end

-- 之前的分数状态
function Model:getLastScore()
    local myScore = self:getLocalCache("myScore") or 0
    local enemyScore = self:getLocalCache("enemyScore") or 0
    return myScore, enemyScore
end

function Model:setLastScore(myScore, enemyScore)
    self:setLocalCache("myScore", myScore)
    self:setLocalCache("enemyScore", enemyScore)
end

-- 之前的分数状态
function Model:getLastScoreMainPanel()
    local myScore = self:getLocalCache("myScoreMainPanel")
    local enemyScore = self:getLocalCache("enemyScoreMainPanel")
    return myScore, enemyScore
end

function Model:setLastScoreMainPanel(myScore, enemyScore)
    self:setLocalCache("myScoreMainPanel", myScore)
    self:setLocalCache("enemyScoreMainPanel", enemyScore)
end

function Model:resetShowScore()
    self:setLocalCache("myScore", 0)
    self:setLocalCache("enemyScore", 0)
    self:setLocalCache("myScoreMainPanel", 0)
    self:setLocalCache("enemyScoreMainPanel", 0)
end

function Model:getJoinRewards()
    return self:getDataByKey("joinRewards") or {}
end

return Model
