local BaseFeatureModel = require"amf.middleware.activity.base.BaseFeatureModel"
local MusicMasterConfig = require 'amf.feature.localactivity.musicmaster.config.MusicMasterConfig'

local LOCAL_PATH = MusicMasterConfig.LOCAL_PATH

local MusicMasterModel = class("MusicMasterModel", BaseFeatureModel)

function MusicMasterModel:_getConstPath()
    return LOCAL_PATH..'.config.MusicMasterConfig'
end

function MusicMasterModel:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "MusicMasterModel"
    }):as("db")

    self:installPlug(AMFDataPlugsType.SYNC, {
        requests = {
            PerfectPlayerInfo = "amf.feature.localactivity.musicmaster.http.RequestPerfectPlayerInfo",
        }
    })
end

------------------------------------------------------------
-- 协议
------------------------------------------------------------

function MusicMasterModel:getCurConfigMd5()
    local srcConfig = nil
    if self:getValue('localConfig') then
        srcConfig = self:getValue('localConfig')
    end

    local configMd5 = '12345'
    if srcConfig and srcConfig.serverMd5 and not table.isEmpty(srcConfig.config) then
        configMd5 = srcConfig.serverMd5
    end
    return configMd5
end

function MusicMasterModel:getCurConfigTimes()
    local srcConfig = nil
    if self:getValue('localConfig') then
        srcConfig = self:getValue('localConfig')
    end

    local timeInfo = { beginTime = 0, mainBeginTime = 0, mainEndTime = 0, endTime = 0 }
    if srcConfig and srcConfig.serverMd5 and not table.isEmpty(srcConfig.config) then
        timeInfo.beginTime = math.ceil( tonumber(srcConfig.beginTime)/1000 )
        timeInfo.mainBeginTime = math.ceil( tonumber(srcConfig.beginTime)/1000 )
        timeInfo.mainEndTime = math.ceil( tonumber(srcConfig.mainEndTime)/1000 )
        timeInfo.endTime = math.ceil( tonumber(srcConfig.endTime)/1000 )
    end
    return timeInfo
end

function MusicMasterModel:requestPerfectPlayerInfo( bFromLightStart, loading )
    return self.syncPlug:requestPerfectPlayerInfo({active = not bFromLightStart, md5=self:getCurConfigMd5()}, loading)
end

function MusicMasterModel:onResponsePerfectPlayerInfo(response)

    if response:isSuccess() then
        local data = response:getData()

        local saveData = {}
        saveData.userData = table.clone(data.userData)
        saveData.updateDataTime = TimeKit:timeInSec()

        local dataConfig
        if data.serverVersionedConfig.serverMd5 ~= "" then
            dataConfig = table.clone(data.serverVersionedConfig)

            local tempConfig = table.deserialize(dataConfig.config)
            saveData.mainBeginTime = math.ceil( tonumber( tempConfig.beginTime )/1000 )
            saveData.mainEndTime = math.ceil( tonumber( tempConfig.mainEndTime )/1000 )
            saveData.beginTime = math.ceil( tonumber( tempConfig.beginTime )/1000 )
            saveData.endTime = math.ceil( tonumber( tempConfig.endTime )/1000 )
        else
            local timeInfo = self:getCurConfigTimes()
            saveData.mainBeginTime = timeInfo.beginTime
            saveData.mainEndTime = timeInfo.mainEndTime
            saveData.beginTime = timeInfo.beginTime
            saveData.endTime = timeInfo.endTime
        end
        self:fromServer( saveData, dataConfig )
    end
end

-- MusicMasterModel
function MusicMasterModel:__declare()
    self:_initLocalData()
    self:_initLocalConfig()
    self:_initLocalKey()
end

function MusicMasterModel:_initLocalData()
    self.updateDataTime = nil
    self.userData = nil
    self.beginTime = nil
    self.endTime = nil
    self.mainBeginTime = nil
    self.mainEndTime = nil
end

function MusicMasterModel:_initLocalConfig()
    self.localConfig = nil
end

function MusicMasterModel:_initLocalKey()
    self.inLevelCardParticipatedEndTime = nil
    self.progressPreviewFirstShow = nil
    self.lastProfiles = nil
    self.lastProfiles_time = nil
    self.play_level_state = nil
    self.show_new_Icon = nil
    self.new_match_pop_times = nil
    self.musicMasterJoinKey = nil
    self.downPartState = nil
    self.newActivityOneDay = nil
end

function MusicMasterModel:passDayClear()
    -- 跨天
    
end

function MusicMasterModel:clearLocalData()
	self:setValue("updateDataTime", nil)
	self:setValue("userData", nil)
	self:setValue("beginTime", nil)
	self:setValue("endTime", nil)
	self:setValue("mainBeginTime", nil)
	self:setValue("mainEndTime", nil)
	self:setValue("localConfig", nil)
end

function MusicMasterModel:fromLocalChangeEnd()
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

function MusicMasterModel:fromServer(data, config)
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

function MusicMasterModel:getConfig()
    local localConfig = self:getValue("localConfig")
    if localConfig and localConfig.config then
        return localConfig.config
    end

    return {}
end

-- 获取data 设置data值  数字类型的增加
function MusicMasterModel:getDataByKey(key, default)
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

function MusicMasterModel:setDataByKey(key, value, needSave)
    local userData = self:getValue("userData")

    if userData and userData[key] ~= nil then
        userData[key] = value
        self:setValue("userData", userData, needSave)
    end
end

function MusicMasterModel:setDataByKeyIgnoreNil(key, value, needSave)
    local userData = self:getValue("userData")

    if userData then
        userData[key] = value
        self:setValue("userData", userData, needSave)
    end
end

function MusicMasterModel:addDataByKey(key, value)
    local userData = self:getValue("userData")
    if userData and type(userData[key]) == 'number' then
        userData[key] = userData[key] + value
        self:setValue("userData", userData, true)
    end
end

function MusicMasterModel:setExDataByKey(key, value, needSave)
    self:setValue(key, value, needSave)
end

-- 获取配置
function MusicMasterModel:getConfigByKey(key)
    local config = self:getConfig()
    if config and config[key] then
        return config[key]
    end
end

function MusicMasterModel:getGuides()
    -- 引导标记
    return self:getDataByKey('guideFlagSet') or {}
end

function MusicMasterModel:addGuides(index)
    -- 添加引导标记
    local guideInfo = self:getDataByKey('guideFlagSet') or {}
    table.insert(guideInfo, index)
    self:setDataByKey('guideFlagSet', guideInfo, true)
end

function MusicMasterModel:checkGuide(index)
    -- 检查引导标记
    local guideInfo = self:getDataByKey('guideFlagSet') or {}
    return table.exist(guideInfo, index)
end

function MusicMasterModel:setGuideIndex(index)
    self:addGuides(index)

    local ActCommonHttp = require("amf.middleware.activity.http.ActCommonHttp")
    ActCommonHttp:setActGuideFlag( self:getConst().ACT_ID, index)
end


-------------------------------


function MusicMasterModel:getRankMemberOldProgressList()
    return self:getDataByKey("rankMemberOldProgressList" )
end


function MusicMasterModel:updateRaceStartTime()
    self:setDataByKey("raceStartTime", ""..TimeKit:time() )
end

function MusicMasterModel:getRaceStartTime()
    return self:getDataByKey("raceStartTime" )
end

function MusicMasterModel:getInActivityStreakwin()
    return self:getDataByKey("inActivityStreakWin" )
end

function MusicMasterModel:getGlobalStreakWin()
    return self:getDataByKey("globalStreakWin" )
end

function MusicMasterModel:getArenaRound()
    return self:getDataByKey("arenaRound" )
end

function MusicMasterModel:updatgeArenaRound(arenaRound)
    self:setDataByKey("arenaRound", arenaRound )
end

function MusicMasterModel:updatePerRace()
    self:setDataByKey("perRace", false )
end

function MusicMasterModel:getOldWinNum()
    return self:getDataByKey("oldProgress" )
end

function MusicMasterModel:getHadBreakWin()
    return self:getDataByKey("haveBreak" )
end

function MusicMasterModel:setPlayEndResetOldWinInfo()
    self:setDataByKey("oldProgress", 0 )
    self:setDataByKey("haveBreak", false )
end

function MusicMasterModel:getCollectItem()
    return self:getDataByKey("musicNum" )
end

function MusicMasterModel:addCollectItem(num)
    self:addDataByKey("musicNum", num )
end

function MusicMasterModel:updateCollectItem(num)
    self:setDataByKey("musicNum", num )
end

function MusicMasterModel:getRewardedMusicNum()
    return self:getDataByKey("musicNumRewarded" )
end

function MusicMasterModel:updateRewardedMusicNum(num)
    self:setDataByKey("musicNumRewarded", num )
end

function MusicMasterModel:getAreanDuan()
    return self:getDataByKey("arenaDuan" )
end

function MusicMasterModel:updateAreanDuan(num)
    self:setDataByKey("arenaDuan", num )
end

function MusicMasterModel:getPreWinNum()
    return self:getDataByKey("preWinNum" ) 
end

function MusicMasterModel:addPreWinNum(num)
    if num == nil then num = 1 end
    self:addDataByKey("preWinNum", num )
end

function MusicMasterModel:clearPreWinNum()
    self:setDataByKey("preWinNum", 0 )
end

function MusicMasterModel:getRankInfoList()
    local rankMemberInfoList = self:getDataByKey("rankMemberInfoList" )
    return rankMemberInfoList or {}
end

function MusicMasterModel:updateRankInfoList(rankMemberInfoList)
    self:setDataByKey("rankMemberInfoList", rankMemberInfoList )
end

function MusicMasterModel:clearRankInfoList()
    self:setDataByKey("rankMemberInfoList", {} )
end

function MusicMasterModel:getSelfRankScore()
    local rankMemberInfoList = self:getRankInfoList()
    local userMgr = _G.amfBean("UserManager")
    local uid = userMgr:getUid()

    local score = 0 
    for i,v in ipairs(rankMemberInfoList) do
        if tonumber(v.uid) == tonumber(uid) then
            score = v.score
            break
        end
    end
    return score
end

function MusicMasterModel:getSelfRank()
    local rankMemberInfoList = self:getRankInfoListAndSort()
    local userMgr = _G.amfBean("UserManager")
    local uid = userMgr:getUid()
    for i,v in ipairs(rankMemberInfoList) do
        if tonumber(v.uid) == tonumber(uid) then
            return v.rank
        end
    end
    return 0
end

function MusicMasterModel:getRankInfoListAndSort()
    local rankMemberInfoList = self:getRankInfoList{}

    local profile = _G.amfBean("ProfileManager"):getProfile()
    local headUrl = _G.amfBean("ProfileManager"):getHeadUrl()
    local meUid = profile.xxlId

    --找出自己
    for i, v in ipairs(rankMemberInfoList) do
        if v.uid == meUid  or (tonumber(v.uid) == tonumber(profile.uid)) then
            v.isMe = true
            v.avatarUrl = headUrl or "0"
        elseif v.avatarUrl == nil then
            v.avatarUrl = '0'
        end
    end

    --把自己放入第一位，固定位置
    local showRankInfoList = {}
    for i, v in ipairs(rankMemberInfoList) do
        if v.isMe then
            local userInfo = table.clone(v)
            userInfo.showPos = #showRankInfoList+1
            table.insert( showRankInfoList, userInfo)
            break
        end
    end
    for i, v in ipairs(rankMemberInfoList) do
        if not v.isMe then
            local userInfo = table.clone(v)
            userInfo.showPos = #showRankInfoList+1
            table.insert( showRankInfoList, userInfo)
        end
    end

    --加入空玩家
    for i=1, 5 do
        if not rankMemberInfoList[i] then
            local userInfo = {}
            userInfo.showPos = #showRankInfoList+1
            userInfo.isEmpty = true
            userInfo.score = 0
            userInfo.uid = '0'--区分真人 机器人
            userInfo.id = -1 --区分真人 机器人
            userInfo.timeOfArrival = ""..(TimeKit:time()+1000)
            userInfo.avatarUrl = ''
            table.insert( showRankInfoList, userInfo)
        end
    end

    ---拍名次
    local scoreList = {}
    
    --按分数排序
    table.sort( showRankInfoList, function (a, b)
        if a and b and a.score and b.score then
            if a.score==b.score then
                if tonumber(a.timeOfArrival) == tonumber(b.timeOfArrival) then
                    return a.uid > b.uid
                else
                    return tonumber(a.timeOfArrival) < tonumber(b.timeOfArrival)
                end
            else
                return a.score > b.score
            end
        end

        return false
    end)

    --给排名
    for i,v in ipairs(showRankInfoList) do
        v.rank = i
    end

    --重新按顺序排序
    table.sort( showRankInfoList, function(a,b)
        return a.showPos < b.showPos
    end)

    --填入旧分数
    local rankMemberOldProgressList = self:getRankMemberOldProgressList()
    local function getPlayerOldScore( id, uid, score )
        local oldScore = score
        if rankMemberOldProgressList then
            for i,v in ipairs(rankMemberOldProgressList) do
                if tonumber(uid) ~= 0 then
                    if tonumber(v.uid) == uid then
                        oldScore = v.score
                        break
                    end
                else
                    if tonumber(v.id) == id then
                        oldScore = v.score
                        break
                    end
                end
            end
        end
        return oldScore
    end
    for i,v in ipairs(showRankInfoList) do
        local oldScore = getPlayerOldScore( v.id, v.uid, v.score )
        v.oldScore = oldScore
    end

    return showRankInfoList
end

function MusicMasterModel:checkInPre()
    --是否在选拔赛
    local bPre = self:getDataByKey("perRace" )
    if bPre then
        return true
    else
        return false
    end
end

function MusicMasterModel:getPanelShowType()

    local showType = MusicMasterConfig.MainPanelShowType.kNone
    local groupPanelShowType = MusicMasterConfig.GroupPanelShowType.kNone

    if self:checkInPre() then 
        showType = MusicMasterConfig.MainPanelShowType.kPre
    else
        showType = MusicMasterConfig.MainPanelShowType.kGroup

        local rankInfoList = self:getRankInfoList()
        if table.isEmpty(rankInfoList) then
            groupPanelShowType = MusicMasterConfig.GroupPanelShowType.kWaitJoin
        else
            groupPanelShowType = MusicMasterConfig.GroupPanelShowType.kInGroup
        end
    end

    return showType, groupPanelShowType
end


--
function MusicMasterModel:getStreakDoorsillConfig()
    return self:getConfigByKey("streakDoorsill" )
end

function MusicMasterModel:getClientVersionControlConfig()
    return self:getConfigByKey("clientVersionControl" )
end

function MusicMasterModel:getMinClientVersionConfig()
    return self:getConfigByKey("minClientVersion" )
end

function MusicMasterModel:getArenaLadderListConfig()
    return self:getConfigByKey("arenaLadderList" )
end

function MusicMasterModel:getProgressRewardListConfig()
    return self:getConfigByKey("progressRewardList" )
end

function MusicMasterModel:getPreRewardList()
    return self:getConfigByKey("preRaceRewardList" )
end

function MusicMasterModel:getRankRewardListByDuan( duan )
    --获取段位排名表
    local arenaLadderList = self:getArenaLadderListConfig()
    local safeDuan = MusicMasterConfig:getSafeDuan( duan )
    return arenaLadderList[safeDuan+1]
end

function MusicMasterModel:getCollectNumFromRewards( rewards )
    for i,v in ipairs(rewards) do
        if v.itemId == MusicMasterConfig.CollectId then
            return v.num
        end
    end
    return 0
end

function MusicMasterModel:checkCanGetFinalProgressReward( collectNum )
    local progressRewardList = self:getProgressRewardListConfig()

    local finalInfo = progressRewardList[#progressRewardList]
    if collectNum >= finalInfo.threshold then
        return true
    end
    return false
end

function MusicMasterModel:getProgressCurCanGetRewardInfo( )
    --获取进度奖励队列
    local rewardedMusicNum = self:getRewardedMusicNum()
    local musicNum = self:getCollectItem()
    local progressRewardList = self:getProgressRewardListConfig()

    local canGetRewardInfoList = {}
    local bCanStartInset = false

    for i,v in ipairs(progressRewardList) do

        local startNeedNum = 0
        local endNeedNum = v.threshold
        if progressRewardList[i-1] then
            startNeedNum = progressRewardList[i-1].threshold
        end

        if not bCanStartInset and rewardedMusicNum >= startNeedNum and rewardedMusicNum < endNeedNum then
            bCanStartInset = true
        end

        if bCanStartInset then
            local info = table.clone(v)

            local needNum = endNeedNum - startNeedNum
            local startShowNum = rewardedMusicNum - startNeedNum
            if startShowNum < 0 then startShowNum = 0 end

            local endShowNum = musicNum - startNeedNum
            if endShowNum > needNum then endShowNum = needNum end

            local bCanGetReward = false
            if endShowNum >= needNum then
                bCanGetReward = true
            end


            info.progressInfo = {
                needNum = needNum,
                startShowNum = startShowNum,
                endShowNum = endShowNum,
                bFinal = i==#progressRewardList,
                bCanGetReward = bCanGetReward,
                index = i,
            }
            table.insert( canGetRewardInfoList, info )
        end

        if musicNum < endNeedNum then
            break
        end
    end
    return canGetRewardInfoList
end

function MusicMasterModel:checkCanGetPreReward()
    --检测是否可以领选拔赛奖励
    if self:checkInPre() then
        local StreakDoorsill = self:getStreakDoorsillConfig()
        local preWinNum = self:getPreWinNum()
        if preWinNum >= StreakDoorsill then
            return true
        else
            return false
        end
    end
    return false
end


----最后发现要用，挪进来了
function MusicMasterModel:getShowRewardsForRandomGold( rewards, wCoinMax )
    --加入随机金币数据
    local showRewards = table.clone(rewards)
    if wCoinMax > 0 then
        local goldReward = { itemId = UPropId.GOLD, num = 0, wCoinMax = wCoinMax }
        table.insert( showRewards, 1, goldReward )
    end
    return showRewards
end

function MusicMasterModel:getShowRewardsForGroupReward( rewards )
    --删除门票、音符
    local showRewards = table.clone(rewards)
    for i,v in ipairs(showRewards) do
        if v.itemId == MusicMasterConfig.CollectId or v.itemId == MusicMasterConfig.TicketId then
            table.remove( showRewards, i )
        end
    end
    return showRewards
end


------
function MusicMasterModel:checkCanGetGroupReward( bRewardTime )
    --是否可以领小组赛奖励
    if not self:checkInPre() then
       local rankInfoList = self:getRankInfoList()

       if not table.isEmpty(rankInfoList) then
            local curDuan = self:getAreanDuan()
            local showRankInfoList = self:getRankInfoListAndSort()
            local rankRewardList = self:getRankRewardListByDuan(curDuan)
            if showRankInfoList[1].score >= rankRewardList.streakGoal  then
                if bRewardTime then
                    --判断奖励除了音符还需要有其他的
                    local rank = showRankInfoList[1].rank
                    if rankRewardList.rankRewardViews[rank] then
                        local rewards = rankRewardList.rankRewardViews[rank].rewardlist
                        local wCoinMax = rankRewardList.rankRewardViews[rank].wCoinMax

                        local newRewards = self:getShowRewardsForRandomGold( rewards, wCoinMax )
                        newRewards = self:getShowRewardsForGroupReward( newRewards )
                        if #newRewards > 0 then
                            return true
                        end
                    end
                else
                    return true
                end
            end
       end
    end
    return false
end

function MusicMasterModel:checkCanGetProgressReward()
    local progressInfoList =  self:getProgressCurCanGetRewardInfo()
    for i,v in ipairs(progressInfoList) do
        if v.progressInfo.bCanGetReward then
            return true
        end
    end
    return false
end


function MusicMasterModel:changeWinNum( bAdd )
    if self:checkInPre() then
        local streakDoorsill = self:getStreakDoorsillConfig()
        local preWinNum = self:getPreWinNum()
        if preWinNum < streakDoorsill then
            if not bAdd then
                self:clearPreWinNum()
            else
                self:addPreWinNum(1)
            end
        end
    else
        local curDuan = self:getAreanDuan()
        local rankRewardList = self:getRankRewardListByDuan( curDuan )
        local targetWinNum = rankRewardList.streakGoal
        local userMgr = _G.amfBean("UserManager")
        local rankInfoList = self:getRankInfoList()
        local profile = _G.amfBean("ProfileManager"):getProfile()
        local meUid = profile.xxlId
        for i, v in ipairs(rankInfoList) do
            if v.uid == meUid  or (tonumber(v.uid) == tonumber(profile.uid)) then
                if v.score < targetWinNum then
                    if bAdd then
                        v.score = v.score + 1
                        v.timeOfArrival = ""..TimeKit:time()
                    else
                        v.score = 0
                        v.timeOfArrival = ""..TimeKit:time()
                    end
                end
                break
            end
        end
        self:updateRankInfoList(rankInfoList)
    end
end


function MusicMasterModel:getProgressGetNum( )
    --获取领了几个进度礼盒了
    local hadGet = 0

    local hadGetMusicNum = self:getRewardedMusicNum()
    local progressRewardList = self:getProgressRewardListConfig()

    for i,v in ipairs(progressRewardList) do
        if hadGetMusicNum >= v.threshold then
            hadGet = hadGet + 1
        end
    end

    return hadGet
end

function MusicMasterModel:getPassNodeNum()
    local musicNum = self:getCollectItem()
    local rewardList = self:getProgressRewardListConfig()

    for i, rewardData in ipairs(rewardList) do
        if musicNum < rewardData.threshold then
            return i - 1
        end
    end
    return #rewardList
end

function MusicMasterModel:checkProgressIsAllGet( )
    --获取领了几个进度礼盒了
    local hadGet = self:getProgressGetNum()
    local progressRewardList = self:getProgressRewardListConfig()

    if hadGet >= #progressRewardList then
        return true
    end

    return false
end

function MusicMasterModel:checkProgressIsAllCanGet( )
    --是不是都能领了
    local hadGet = self:getPassNodeNum()
    local progressRewardList = self:getProgressRewardListConfig()
    if hadGet >= #progressRewardList then
        return true
    end

    return false
end

return MusicMasterModel
