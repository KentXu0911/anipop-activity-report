local ActivityName = "Gladiator"
local Meta = require('amf.feature.localactivity.'..string.lower(ActivityName)..'.'..ActivityName..'Meta')
local LocalServer = class(ActivityName .. "LocalServer", AMFDataRef)

function LocalServer:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = ActivityName .. "LocalServer",
    }):as("db")
end

function LocalServer:__declare()
    self.matchInfo = nil
    self.enemyProfile = nil
    self.myInfo = nil
    self.enemyInfo = nil
    self.pkStatusInfo = nil
    self.shortTermData = nil
    self.matchRecords = nil
    self.todayJoinPkCount = nil
    self.lastPkEndTime = nil
    self.guideSet = nil
    self.dayDataMap = nil
    self.showPoolList = nil
    self.notLuckyRewardNumStr = nil
    self.luckyRewardNumStr = nil
    self.shortTermActConfig = nil
    self.beginTime = nil
    self.mainBeginTime = nil
    self.mainEndTime = nil
    self.endTime = nil
    self.lastStartPanelAndTipScoreData = nil
    self.lastRecordScoreData = nil
    self.specialRewardWinCount = nil
    self.clientMd5 = nil
    self.bigCashPro = nil
    self.needRefreshGroup = nil
    self.group = nil
    self.debugStr = nil

    self.firstMatchShow = nil

    self.todayDC = nil
    self.todayDCPopoutTime = nil

    self.openMainPanelTodayKey = nil
    self.openMainPanelTodayKeyPopoutTime = nil

    self.openJoinPanelTodayKey = nil
    self.openJoinPanelTodayKeyPopoutTime = nil

    self.dayPointFlag = nil
    self.dayPointFlagPopoutTime = nil

    self.nowRoundSuperLuckyTouched = nil

    self.savedPkRound = nil

    self.periodId = nil
    self.inLevelCardParticipatedEndTime = nil
    self.lastStartPanelAndTipScoreData = nil
end

function LocalServer:fromServer( serverData,skipSaveLocal,fromMainInfo )
	for k,v in pairs(serverData) do
		self:setValue(k, v)
	end

    if fromMainInfo then
        --如果没有对手信息，就主动清掉
        if not serverData.enemyInfo then
            self:setValue("enemyInfo", nil)
        end

        if not serverData.enemyProfile then
            self:setValue("enemyProfile", nil)
        end

        if not serverData.matchInfo then
            self:setValue("matchInfo", nil)
        end
    end

	if not skipSaveLocal then
		self:flush()
	end
end

function LocalServer:getActBeginTime(  )
	return self:getValue("beginTime") or 0
end

function LocalServer:getActMainBeginTime(  )
	return self:getValue("mainBeginTime") or 0
end

function LocalServer:getActMainEndTime(  )
	return self:getValue("mainEndTime") or 0
end

function LocalServer:getActEndTime(  )
	return self:getValue("endTime") or 0
end

function LocalServer:isActInPre(  )
    local now = TimeKit:timeInSec()
    local beginTime = self:getActBeginTime()
    local endTime = self:getActMainBeginTime()
    return now >= beginTime and now < endTime
end

function LocalServer:isActInMain(  )
    local now = TimeKit:timeInSec()
    local beginTime = self:getActMainBeginTime()
    local endTime = self:getActMainEndTime()
    return now >= beginTime and now < endTime
end

function LocalServer:isActInReward(  )
    local now = TimeKit:timeInSec()
    local beginTime = self:getActMainEndTime()
    local endTime = self:getActEndTime()
    return now >= beginTime and now < endTime
end

--------------------- 每次需要修改的函数 ---------------------
function LocalServer:setGuide( index )
	local guideInfo = self:getDataByKey("guideInfo", {})
	table.insert(guideInfo, index)
	self:setDataByKey("guideInfo", guideInfo, true)
end

function LocalServer:hasGuide( index )
	local guideInfo = self:getDataByKey("guideInfo", {}, false)
	return table.find(guideInfo, function ( v )
		return v == index
	end)
end

--通过key获取data
function LocalServer:getDataByKey(key,defaultValue)
    return self:getValue(key) or defaultValue
end

--清数据
function LocalServer:clearData()
    self:reset()
end

function LocalServer:clearDataByKey(key,needSave)
    self:setDataByKey(key,nil,needSave)
end

--更新单个数据
function LocalServer:setDataByKey(key,value,needSave,isNewkey)
    if not key then
        return
    end

    self:setValue(key,value,needSave)
end

--判断数据是否准备就绪
function LocalServer:isDataEnabled()
    if (not self:getDataByKey("myInfo")) 
        or (not self:getDataByKey("showPoolList")) then
        return false
    end
    return true
end

--------------------- 业务数据处理 ---------------------
--加分
function LocalServer:addScore(num)
    if not num then return end
    local matchInfo = self:getDataByKey("matchInfo",{})
    --本地没数据
    if table.isEmpty(matchInfo) then
        return
    end

    local myUid = getSafeUid()
    for k,v in ipairs(matchInfo.members) do
        if v.uid == myUid then
            v.score = v.score + num
        end
    end

    self:setDataByKey("matchInfo",matchInfo,true)
end

--更新对手分
function LocalServer:setEnemyScore(num)
    if not num then return end
    local matchInfo = self:getDataByKey("matchInfo",{})
    --本地没数据
    if table.isEmpty(matchInfo) then
        return
    end

    local myUid = _G.amfBean("UserManager"):getUid()
    for k,v in ipairs(matchInfo.members) do
        if v.uid ~= myUid then
            v.score = num
            break
        end
    end

    self:setDataByKey("matchInfo",matchInfo,true)
end

--更新对手的数据
function LocalServer:updateEnemyInfoAndProfile(enemyInfo,enemyProfile)
    if (not enemyInfo) or (not enemyProfile) then return end
    self:setDataByKey("enemyInfo",enemyInfo,nil,true)
    self:setDataByKey("enemyProfile",enemyInfo,true,true)
end

function LocalServer:getAndRefreshPKState()
    local pkStatusInfo = self:getDataByKey("pkStatusInfo",{})
    local status = pkStatusInfo.pkStatus
    --1转移到2
    if status == Meta.PKState.kInGame then
        local matchInfo = self:getDataByKey("matchInfo",{})
        local endTime = tonumber(matchInfo.endTime)
        local nowTime = TimeKit:timeInMillis()
        if nowTime > endTime then
            pkStatusInfo.pkStatus = Meta.PKState.kToBeSettled 
            self:setDataByKey("pkStatusInfo",pkStatusInfo,true)
            status = Meta.PKState.kToBeSettled
        end
    end

    return status
end

--获取分数状态
function LocalServer:getScoreData(matchInfo)
    local matchInfo = matchInfo or self:getDataByKey("matchInfo")
    if not matchInfo then
        return {
            myScore = 0,
            enemyScore = 0,
        }
    end

    local members = matchInfo.members
    local myScore,enemyScore = 0,0
    local myUid = _G.amfBean("UserManager"):getUid()
    for k,v in ipairs(members) do
        if v.uid == myUid then
            myScore = v.score
        else
            enemyScore = v.score
        end
    end

    return {
        myScore = myScore or 0,
        enemyScore = enemyScore or 0
    }
end

--胜负状态
function LocalServer:getWinState(matchInfo)
    local matchInfo = matchInfo or self:getDataByKey("matchInfo",{})
    if table.isEmpty(matchInfo) then
        return Meta.MatchState.kInvalid
    end

    local members = matchInfo.members
    local myScore,enemyScore = 0,0
    local myUid =  _G.amfBean("UserManager"):getUid()
    for k,v in ipairs(members) do
        if v.uid == myUid then
            myScore = v.score
        else
            enemyScore = v.score
        end
    end

    return self:checkWinState(myScore,enemyScore)
end

function LocalServer:checkWinState(myScore,enemyScore)
    if myScore == enemyScore then
        if myScore == 0 then
            return Meta.MatchState.kLose
        else
            return Meta.MatchState.kWin
        end
    elseif myScore > enemyScore then
        return Meta.MatchState.kWin
    else
        return Meta.MatchState.kLose
    end
end

--跨天刷新
function LocalServer:passDayRefreshData()
    --跨天清每日次数
    self:setDataByKey("todayJoinPkCount",0,true)
end

--上局数据清除
function LocalServer:clearLastMatchInfo()
    self:clearDataByKey("matchInfo")
    self:clearDataByKey("enemyInfo")
    self:clearDataByKey("enemyProfile")

    self:clearDataByKey("lastStartPanelAndTipScoreData")

    self:flush()
end

function LocalServer:getRewardLightValueMap()
    local rewardLightValue = {}
    local value = self:getDataByKey("showPoolList", {})
    for k, v in pairs(value) do
        rewardLightValue[tostring(v.reward.list[1].itemId)] = v.value
    end

    return rewardLightValue
end

-- 当前pk剩余时间
function LocalServer:getNowPKEndTime()
    local matchInfo = self:getDataByKey("matchInfo",{})
    --本地没数据
    if table.isEmpty(matchInfo) then
        return 0
    end

    return math.floor(tonumber(matchInfo.endTime)/1000)
end

--奖励配置
function LocalServer:getRewardsConfig()
    local showPoolList = self:getDataByKey("showPoolList",{})
    local retTable = {}
    for k,v in ipairs(showPoolList) do
        table.insert(retTable,v.reward.list[1])
    end

    return retTable
end

--取缓存分数数据
function LocalServer:getLastRecordScoreData()
    local nowScoreData = self:getScoreData()
    return self:getDataByKey("lastRecordScoreData",nowScoreData)
end

--存缓存分数数据
function LocalServer:saveLastRecordScoreData(scoreData)
    self:setDataByKey("lastStartPanelAndTipScoreData", scoreData, nil, true)
    self:setDataByKey("lastRecordScoreData",scoreData,true,true)
end

-- 获取服务器时间是活动周期内的第几天
function LocalServer:getDayFromActOpen( time )
    if not self:isDataEnabled() then return 1 end
    local startTime = getDayStartTimeByTS(self:getActMainBeginTime())
    local curTime = getDayStartTimeByTS(time or TimeKit:timeInSec())
    return math.floor((curTime-startTime)/86400)+1
end

--是否lucky
function LocalServer:getMatchLucky()
    if not self:isDataEnabled() then return false end
    local state = self:getAndRefreshPKState()
    if state == Meta.PKState.kInGame then
        local matchInfo = self:getDataByKey("matchInfo")
        if matchInfo then
            return matchInfo.lucky
        end
    end
    return false
end

--是否有enemy信息
function LocalServer:checkHasEnemyInfo()
    if not self:isDataEnabled() then return false end
    local state = self:getAndRefreshPKState()
    if state == Meta.PKState.kInGame then
        local enemyInfo = self:getDataByKey("enemyInfo")
        if enemyInfo then
            return true
        end
    end
    return false
end

--头像url
function LocalServer:getEnemyHeadUrl()
    if not self:isDataEnabled() then return nil end
    local state = self:getAndRefreshPKState()
    if state == Meta.PKState.kInGame then
        local enemyProfile = self:getDataByKey("enemyProfile")
        if enemyProfile then
            return enemyProfile.headUrl
        end
    end
    return nil
end

function LocalServer:checkCanBeInvited()
    local limit = self:getBeInvitedCount()
    local attendCount = self:getLastTargetDayAttendCount()

    local canJoin = self:checkHasLeftTimes()

    return attendCount <= limit and canJoin
end

-- 邀请判定次数
function LocalServer:getBeInvitedCount()
    return self:getDataByKey("shortTermActConfig", {}).inviteXValue or 2
end

-- 主动参与次数
function LocalServer:getLastTargetDayAttendCount()
    local map = self:getDataByKey("dayDataMap", {})
    local total = 0
    local days = 1

    local curDayStartTime = getDayStartTimeByTS(TimeKit:timeInSec())
    local todayIndex = math.ceil(curDayStartTime/86400)

    for k, v in pairs(map) do
        if (todayIndex - tonumber(k)) < days then
            total = total + v.joinPkCount
        end
    end
    return total
end
----------------------------------------------短期专用-------------------------------------------------
--今天是否还有剩余次数，短期专用
function LocalServer:checkHasLeftTimes()
    local joinCountLimit = self:getTodayLimitNum()
    local todayJoinPkCount = self:getDataByKey("todayJoinPkCount",0)
    return todayJoinPkCount < joinCountLimit
end

--今日限定次数
function LocalServer:getTodayLimitNum()
    local dayJoinLimitStr = self:getDataByKey("shortTermActConfig",{}).dayJoinLimitStr
    local ret = string.split(dayJoinLimitStr,',')
    local day = self:getDayFromActOpen()
    return tonumber(ret[day]) or 0
end

--今日剩余次数
function LocalServer:getTodayLeftTimes()
    local limitTime = self:getTodayLimitNum()
    local todayJoinPkCount = self:getDataByKey("todayJoinPkCount",0)
    return limitTime - todayJoinPkCount
end

-- 总剩余次数
function LocalServer:getTotalLeftTimes()
    local dayJoinLimitStr = self:getDataByKey("shortTermActConfig",{}).dayJoinLimitStr
    local ret = string.split(dayJoinLimitStr, ',')
    local today = self:getDayFromActOpen()
    local time = 0
    for k, v in pairs(ret) do
        if k >= today then time = time + tonumber(v) end
    end
    local todayJoinPkCount = self:getDataByKey("todayJoinPkCount",0)
    return time - todayJoinPkCount
end

return LocalServer
