local Meta = require("amf.feature.localactivity.winrepeatrank.meta.WinRepeatRankMeta")

local ServerData = class("WinRepeatRankModel", AMFDataRef)

function ServerData:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "win_repeat_rank_model"
    }):as("db")
end

-- ServerData
function ServerData:__declare()
    self:_initLocalData()
    self:_initLocalConfig()
    self:_initLocalKey()
end

function ServerData:_initLocalData()
    self.updateDataTime = nil
    self.userData = nil
    self.raceType = nil
    self.stageOneBeginTime = nil
    self.stageOneEndTime = nil
    self.stageTwoBeginTime = nil
    self.stageTwoEndTime = nil
    self.beginTime = nil
    self.endTime = nil
    self.mainBeginTime = nil
    self.mainEndTime = nil
    self.clientVersionControl = nil
    self.openStreakWinThreshold = nil
    self.errCode = nil
    self.canyuHadDC = nil
    self.canyuJoinHadDC = nil
end

function ServerData:_initLocalConfig()
    self.config = nil
    self.localConfig = nil
    self.serverVersionedConfig = nil
end

function ServerData:_initLocalKey()
    self.savePopCongraKey = nil
    self.savePopMainPanelKey = nil
    self.saveOldScoreDataKey = nil
    self.saveOldRankScoreKey = nil
    self.saveOldRankKey = nil
    self.actIconProgressFullAnim = nil
    self.historyRankKey4046 = nil
    self.historyRankKey4047 = nil
    self.historyRankKey4048 = nil
    self.descPanelPopkey = nil
    self.autoPopReduceEnteredEndTime = nil
end

function ServerData:passDayClear()
    -- 跨天

end

function ServerData:fromServer(data, config)
    -- 从活动info 发来的信息拆分出 data 和 localConfig
    -- userData是后端数据，self.data.xxx可以自行添加不会覆盖删除
    for k, v in pairs(data) do
        self:setValue(k, v)
    end

    if config and not table.isEmpty(config) then
        config.config = table.deserialize(config.config)
        self:setValue("localConfig", config)
    end

    self:flush()
end

function ServerData:getConfig()
    local localConfig = self:getValue("localConfig")
    if localConfig and localConfig.config then
        return localConfig.config
    end

    return {}
end

-- getDataByKey/setDataByKey 仅管理后端 userData 业务字段
function ServerData:getDataByKey(key, default)
    local userData = self:getValue("userData")
    if userData and userData[key] ~= nil then
        return userData[key]
    end

    return default
end

function ServerData:setDataByKey(key, value, needSave)
    local userData = self:getValue("userData")

    if userData then
        userData[key] = value
        self:setValue("userData", userData, needSave)
    end
end

function ServerData:addDataByKey(key, value)
    local userData = self:getValue("userData")
    if userData and type(userData[key]) == 'number' then
        userData[key] = userData[key] + value
        self:setValue("userData", userData, true)
    end
end

function ServerData:setExDataByKey(key, value, needSave)
    self:setValue(key, value, needSave)
end

function ServerData:getSrcConfig()
    return self:getValue("serverVersionedConfig") or {}
end

-- 获取配置
function ServerData:getConfigByKey(key)
    local config = self:getConfig()
    if config and config[key] then
        return config[key]
    end
end

function ServerData:getGuides()
    -- 引导标记
    return self:getDataByKey('guideSet') or {}
end

function ServerData:addGuides(index)
    -- 添加引导标记

    local guideSet = self:getDataByKey('guideSet')
    table.insert(guideSet, index)
    self:setDataByKey('guideSet', guideSet, true)

    self:flush()
end

function ServerData:checkGuide(index)
    -- 检查引导标记
    local guideSet = self:getDataByKey('guideSet') or {}

    return table.exist(guideSet, index)
end

function ServerData:setGuideIndex(index)
    self:addGuides(index)

    local ActCommonHttp = require("amf.middleware.activity.http.ActCommonHttp")
    ActCommonHttp:setActGuideFlag(Meta.ACT_ID, index)
end

--------------------------时间 -----
function ServerData:getStageOneBeginTime()
    local periodConfig = self:getConfigByKey('periodConfig') or {}
    return tonumber(periodConfig.stageOneBeginTimeLong)
end

function ServerData:getStageOneEndTime()
    local periodConfig = self:getConfigByKey('periodConfig') or {}
    return tonumber(periodConfig.stageOneEndTimeLong)
end

function ServerData:getStageTwoBeginTime()
    local periodConfig = self:getConfigByKey('periodConfig') or {}
    return tonumber(periodConfig.stageTwoBeginTimeLong)
end

function ServerData:getStageTwoEndTime()
    local periodConfig = self:getConfigByKey('periodConfig') or {}
    return tonumber(periodConfig.stageTwoEndTimeLong)
end

-------------------------------------------shihao.zhang----------------------------------------------------
-- 获取奖励
-- type1预选赛2新星赛3精英赛
function ServerData:getRewardsByTypeAndRank(type, rank)
    return self:getRankRewards(type, rank)
end

-- 精英赛第一名奖励
function ServerData:getEliteCompetitionFirstRewards()
    return self:getRankRewards(Meta.mainPanelShowType.kMainPanel3, 1)
end

-- 新星赛第一名奖励
function ServerData:getNewStarCompetitionFirstRewards()
    return self:getRankRewards(Meta.mainPanelShowType.kMainPanel2, 1)
end

-- 非满级到满级奖励
function ServerData:getFMJToMJRewards()
    return {{
        itemId = 10098,
        num = 1
    }}
end

-- 满级到满星奖励
function ServerData:getMJToMXRewards()
    return {{
        itemId = 10098,
        num = 1
    }}
end

function ServerData:getWinningCount()
    return self:getDataByKey('streakNum') or 0
end

function ServerData:clearWinningCount()
    self:setDataByKey('streakNum', 0, true)
end

function ServerData:getAddScore(winCount)
    if not winCount then
        winCount = self:getDataByKey("streakNum") or 0
    end

    if winCount == 0 then
        return 0
    end

    local maxNum = 0
    local streakWinScoreTable = self:getConfigByKey("streakWinScoreTable") or {}
    for k, v in ipairs(streakWinScoreTable) do
        if winCount == v.streakWin then
            return v.score
        end
        maxNum = math.max(maxNum, v.score)
    end

    return maxNum
end

-- 加连胜
function ServerData:addWinningCount(num)
    -- 连胜数量增加
    local winningCount = self:getDataByKey('streakNum') or 0

    winningCount = winningCount + num

    self:setDataByKey('streakNum', winningCount, true)

    self:flush()
end

function ServerData:canGetDoubleScore()
    -- 是否可以多倍获得积分
    local doubleNum = self:getScoreDoubleNum()
    return doubleNum > 1
end

function ServerData:getScoreDoubleNum()
    -- 获取可获得的积分倍数
    local doubleNum = 1
    local userStateManager = _G.amfBean("UserStateManager")
    if not userStateManager:isFMJ() then
        doubleNum = _G.amfBean("FullStarLevelLibManager"):canPlay() and 4 or 2
    end
    return doubleNum
end

--------------------------
----------zhigang
--------------------------

function ServerData:updateDataFromActInfo(actInfo)
    if not actInfo then
        return
    end

    if not actInfo.extra then
        return
    end

    local extra = table.deserialize(actInfo.extra)

    -- 更新小组结算信息
    self:updateGroupRewardInfo(extra.preselectionInfo, extra.risingStarsInfo, extra.eliteInfo)

    -- 更新进组状态
    self:setDataByKey('entryGroup', extra.entryGroup)

    self:flush()
end

function ServerData:updateGroupRewardInfo(preselectionInfo, risingStarsInfo, eliteInfo)
    -- 从actInfo更新最新的领奖数据
    if preselectionInfo then
        self:setDataByKey('preselectionInfo', table.clone(preselectionInfo))
    else
        self:setDataByKey('preselectionInfo', nil)
    end

    if risingStarsInfo then
        self:setDataByKey('risingStarsInfo', table.clone(risingStarsInfo))
    else
        self:setDataByKey('risingStarsInfo', nil)
    end

    if eliteInfo then
        self:setDataByKey('eliteInfo', table.clone(eliteInfo))
    else
        self:setDataByKey('eliteInfo', nil)
    end
end

function ServerData:checkCanGetGroupRewardForIcon()
    -- 是否可以领取小组奖励 ,真的有奖可领
    local preselectionInfo = self:getDataByKey('preselectionInfo')
    local risingStarsInfo = self:getDataByKey('risingStarsInfo')
    local eliteInfo = self:getDataByKey('eliteInfo')

    if preselectionInfo then
        if not preselectionInfo.acquiredReward and preselectionInfo.canReward then
            return true, preselectionInfo
        end
    end

    if risingStarsInfo then
        if not risingStarsInfo.acquiredReward and risingStarsInfo.canReward then
            return true, risingStarsInfo
        end
    end

    if eliteInfo then
        if not eliteInfo.acquiredReward and eliteInfo.canReward then
            return true, eliteInfo
        end
    end

    return false, {}
end

function ServerData:checkCanGetGroupReward()
    -- 是否可以领取小组奖励
    local preselectionInfo = self:getDataByKey('preselectionInfo')
    local risingStarsInfo = self:getDataByKey('risingStarsInfo')
    local eliteInfo = self:getDataByKey('eliteInfo')

    if preselectionInfo then
        if not preselectionInfo.acquiredReward then
            return true, preselectionInfo
        end
    end

    if risingStarsInfo then
        if not risingStarsInfo.acquiredReward then
            return true, risingStarsInfo
        end
    end

    if eliteInfo then
        if not eliteInfo.acquiredReward then
            return true, eliteInfo
        end
    end

    return false, {}
end

function ServerData:setGroupRewardSucess(mainPanelShowType)
    if mainPanelShowType == Meta.mainPanelShowType.kMainPanel1 then
        local preselectionInfo = self:getDataByKey('preselectionInfo')
        if preselectionInfo then
            preselectionInfo.acquiredReward = true
            self:setDataByKey('preselectionInfo', preselectionInfo, true)
        end
    elseif mainPanelShowType == Meta.mainPanelShowType.kMainPanel2 then
        local risingStarsInfo = self:getDataByKey('risingStarsInfo')
        if risingStarsInfo then
            risingStarsInfo.acquiredReward = true
            self:setDataByKey('risingStarsInfo', risingStarsInfo, true)
        end
    elseif mainPanelShowType == Meta.mainPanelShowType.kMainPanel3 then
        local eliteInfo = self:getDataByKey('eliteInfo')
        if eliteInfo then
            eliteInfo.acquiredReward = true
            self:setDataByKey('eliteInfo', eliteInfo, true)
        end
    end
end

function ServerData:getGroupRank(mainPanelShowType)
    if mainPanelShowType == Meta.mainPanelShowType.kMainPanel1 then
        local preselectionInfo = self:getDataByKey('preselectionInfo')
        if preselectionInfo then
            return preselectionInfo.rank
        end

    elseif mainPanelShowType == Meta.mainPanelShowType.kMainPanel2 then
        local risingStarsInfo = self:getDataByKey('risingStarsInfo')
        if risingStarsInfo then
            return risingStarsInfo.rank
        end

    elseif mainPanelShowType == Meta.mainPanelShowType.kMainPanel3 then
        local eliteInfo = self:getDataByKey('eliteInfo')
        if eliteInfo then
            return eliteInfo.rank
        end
    end

    return 0
end

function ServerData:checkCanGetMJReward()
    -- 是否可以领满级奖励
    local userStateManager = _G.amfBean("UserStateManager")
    local bFMJ = userStateManager:isFMJ()
    if not bFMJ and not self:getDataByKey('gotFullLevelReward') then
        return true
    end
    return false
end

function ServerData:checkCanGetMJMXReward()
    -- 是否可以领满级满星奖励
    local userStateManager = _G.amfBean("UserStateManager")
    local bFMJ = userStateManager:isFMJ()
    local bMainStarFull = userStateManager:isMainStarFull()
    local bColorfulStarFull = userStateManager:isColorfulStarFull()
    if not bFMJ and (bMainStarFull and bColorfulStarFull) and not self:getDataByKey('gotFullStarsReward') then
        return true
    end
    return false
end

function ServerData:getCurMainTimeShowType()
    -- 获取当前小组状态
    local raceType = self:getDataByKey('raceType')
    return raceType
end

function ServerData:clearWinNum()
    -- 失败情况连胜
    self:setDataByKey('streakNum', 0, true)
end

function ServerData:checkIsEnterGroup()
    -- 是否进入小组
    return self:getDataByKey('entryGroup')
end

function ServerData:setEnterGroup()
    -- 设置进入小组
    return self:setDataByKey('entryGroup', true, true)
end

function ServerData:setNoEnterGroup()
    -- 设置未进入小组
    return self:setDataByKey('entryGroup', false, true)
end

function ServerData:getRankRewards(mainPanelShowType, rank)
    -- 根据界面 与排名获取奖励 没有返回空table
    local raceConfigTable = self:getConfigByKey("raceConfigTable") or {}
    local configStr = Meta:getConfigStrByMainPanelShowType(mainPanelShowType)

    for i, v in ipairs(raceConfigTable) do
        if v.raceType == configStr then
            return v.rankRewardList[rank] or {}
        end
    end
    return {}
end

function ServerData:getCanGetRankRewardRank(mainPanelShowType)
    -- 前几名可以领奖
    local raceConfigTable = self:getConfigByKey("raceConfigTable") or {}
    local configStr = Meta:getConfigStrByMainPanelShowType(mainPanelShowType)

    for i, v in ipairs(raceConfigTable) do
        if v.raceType == configStr then
            return #v.rankRewardList
        end
    end
    return 0
end

function ServerData:getWinScoreAddNum(winNum)
    -- 根据连胜数获取应该获得的积分
    local streakWinScoreTable = self:getConfigByKey("streakWinScoreTable") or {}
    local maxRewardWinNum = #streakWinScoreTable
    if winNum > maxRewardWinNum then
        winNum = maxRewardWinNum
    end

    for i, v in ipairs(streakWinScoreTable) do
        if v.streakWin == winNum then
            return v.score
        end
    end

    return 0
end

function ServerData:getCurWinScoreAddNum(winNum)
    -- 根据当前连胜数获取加分值
    local curWinNum = winNum or self:getWinningCount()
    local addScoreNum = self:getWinScoreAddNum(curWinNum)
    if self:canGetDoubleScore() then
        addScoreNum = addScoreNum * 2
    end
    return addScoreNum
end

function ServerData:getAddScoreBuffEndTime()
    -- 获取加分buff
    local endTime = math.ceil(tonumber(self:getDataByKey("buffExpireTime", 0)) / 1000)
    local curTime = TimeKit:timeInSec()
    if curTime <= endTime then
        return true, endTime
    end
    return false, 0
end

function ServerData:addScoreBuffTime(addNum)
    -- 加buff
    local endTime = tonumber(self:getDataByKey("buffExpireTime", 0))
    local oneTime = 60 * 1000
    local addTime = addNum * oneTime
    local curTime = TimeKit:timeInSec()

    if curTime <= endTime then
        endTime = endTime + addTime
    else
        endTime = curTime + addTime
    end
    self:setDataByKey('buffExpireTime', endTime, true)
    self:flush()
end
--------------------------

return ServerData
