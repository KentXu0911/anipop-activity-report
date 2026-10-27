local Model = class("PromotionEvent2025Model", AMFDataRef)

function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "promotion_event_2025_model",
    }):as("db")

    self:installPlug(AMFDataPlugsType.SYNC, {
        requests = {
            getMainInfo = "amf.feature.promotionevent2025.http.RequestPromotionEventMainInfo",
            getRewardsOnline = "amf.feature.promotionevent2025.http.RequestRewardsOnline",
            getRewardsOffline = "amf.feature.promotionevent2025.http.RequestRewardsOffline",
            getHistory = "amf.feature.promotionevent2025.http.RequestGetHistory",
            getCurGroupInfo = "amf.feature.promotionevent2025.http.RequestGetCurGroupInfo",
            getRankInfo = "amf.feature.promotionevent2025.http.RequestGetRankInfo",
            getShareRewards = "amf.feature.promotionevent2025.http.RequestGetShareRewards",
            requestFriend = "amf.feature.promotionevent2025.http.RequestPromotionEventRequestFriend",
        }
    })
end


--成员变量声明
function Model:__declare()
    self.serverVersionedConfig = {}

    self.state = 0
    self.openVersion = 0

    self.buffMap = {}
    self.collectionNum = 0
    self.curGroup = {}
    self.curPeriod = 0
    -- self.guideIdSet = {}
    self.lastDanDiff = 0
    self.lastPeriod = 0
    self.needGetHistoryRankReward = false
    self.resultConfirmed = true
    self.taskIndex = 0
    self.location = -1
    self.finishRewardPeopleCount = 0
    self.joinGroupPeopleCount = 0
    self.lastPeriodCollectionType = 0
    self.subPeriodIdInWeek = 0 --本意是记录本周的子周期id，但和产品预期的上下半周无关，故现在无使用

    self.groupRankInfo = {} -- light不发
    self.friendList = {} -- light不发
    self.userHistory = {} -- light不发

    -- 本地字段
    self.isFromServer = false
    self.taskBaseId = 0
    self.taskBaseIdPeriod = 0
    self.showCollectNum = 0
    self.newIconFlags = {}
    self.showPreInFlags = {}
    self.showLastRankFlags = {}
    self.showMainPanelFlags = {}
    self.iconTipFlags = {}
    self.handGuideFlag = false
    self.lastIndex = 0
    self.lastShow = {}

    -- 临时字段，不参与初始化和储存
    -- self.initTaskData = nil
    -- self.rewardFailFlag = false
    -- self.lastTaskProgressInfo = {}
    -- self.lastCollectCount = 0
    -- self.lastShareRewardBean = nil
end

function Model:requestGetMainInfo(param)
    local period = self:getValue("curPeriod") or 0
    local clientMd5 = (self:getValue("serverVersionedConfig") or {}).serverMd5
    local protocolVersion = PromotionEvent2025Const.MainInfoVersion

    local param = param or {}
    param.protocolVersion = protocolVersion
    param.period = period
    param.clientVersionedConfig = {clientMd5 = clientMd5}
    param.taskWithoutLevel = true
    param.withFriend = not param.lightStart
    param.withHistory = not param.lightStart

    return self.syncPlug:requestGetMainInfo(param)
end

function Model:requestGetRewardsOnline(param, taskInfo)
    param.taskInfo = taskInfo

-----------------------------月赛兼容-----------------------------

    local plug = self:getTempData("ActSendPlug")
    local param = plug:handleRequestParams( "levelPromotionV2Reward2024",param)

-- -------------------------------------------------------------------------

    return self.syncPlug:requestGetRewardsOnline(param or {})
end

function Model:requestGetRewardsOffline(param, taskInfo)
    param.taskInfo = taskInfo
    return self.syncPlug:requestGetRewardsOffline(param or {})
end

function Model:requestGetHistory(param)
    return self.syncPlug:requestGetHistory(param or {})
end

function Model:requestGetCurGroupInfo(param)
    return self.syncPlug:requestGetCurGroupInfo(param or {})
end

function Model:requestRequestFriend(param)
    return self.syncPlug:requestRequestFriend(param)
end

function Model:requestGetRankInfo(param)
    return self.syncPlug:requestGetRankInfo(param or {})
end

function Model:requestGetShareRewards(param)
    return self.syncPlug:requestGetShareRewards(param or {})
end

-- 主info
function Model:onResponseLevelPromotionV2GetInfo2024(response, reqParam)
    if response:isSuccess() then
        local data = response:getData()
        if (not data.openVersion or data.openVersion == 0) or ((data.errorCode and data.errorCode ~= "" and tonumber(data.errorCode) ~= 0)) then
            self:setValue("isFromServer", false)
            return
        else
            self:setValue("openVersion", data.openVersion)
        end

        self:setValue("state", data.state or 0)

        if data.serverVersionedConfig and data.serverVersionedConfig.config and data.serverVersionedConfig.config ~= "" then
            local serverVersionedConfig = {
                serverMd5 = data.serverVersionedConfig.serverMd5,
                config = table.deserialize(data.serverVersionedConfig.config),
            }
            self:setValue("serverVersionedConfig", serverVersionedConfig)
        end

        if data.userBean then
            self:setValue("buffMap", data.userBean.buffMap or {})
            self:setValue("collectionNum", data.userBean.collectionNum or 0)
            self:setValue("curGroup", data.userBean.curGroup or {})
            self:setValue("curPeriod", data.userBean.curPeriod or 0)
            -- self:setValue("guideIdSet", data.userBean.guideIdSet or {})
            self:setValue("lastDanDiff", data.userBean.lastDanDiff or 0)
            self:setValue("lastPeriod", data.userBean.lastPeriod or 0)
            self:setValue("needGetHistoryRankReward", data.userBean.needGetHistoryRankReward or false)
            self:setValue("taskIndex", data.userBean.taskIndex or 0)
            self:setValue("location", data.userBean.location or -1)
            self:setValue("lastPeriodCollectionType", data.userBean.lastPeriodCollectionType or 0)
            self:setValue("subPeriodIdInWeek", data.userBean.subPeriodIdInWeek or 0)

            if data.userBean.resultConfirmed ~= nil then
                self:setValue("resultConfirmed", data.userBean.resultConfirmed)
            end
        end

        if data.finishRewardPeopleCount and data.joinGroupPeopleCount then
            self:setValue("finishRewardPeopleCount", data.finishRewardPeopleCount or 0)
            self:setValue("joinGroupPeopleCount", data.joinGroupPeopleCount or 0)
        end

        if data.groupRankInfo then
            if data.groupRankInfo.rankList then
                table.sort(data.groupRankInfo.rankList, function(a, b)
                    if a.score > b.score then
                        return true
                    elseif a.score == b.score then
                        if tonumber(a.updateTime) ==  tonumber(b.updateTime) then
                            return tonumber(a.uid) <  tonumber(b.uid)
                        else
                            return tonumber(a.updateTime) < tonumber(b.updateTime)
                        end
                    else
                        return false
                    end
                end)

                for i, v in ipairs(data.groupRankInfo.rankList) do
                    v.rank = i
                end
            end

            self:setValue("groupRankInfo", data.groupRankInfo)

            local myUid = _G.amfBean("ProfileManager"):getUid()
            local v, k = table.find(data.groupRankInfo.rankList or {}, function(v)
                return tonumber(v.uid) == tonumber(myUid)
            end)

            local curGroup = self:getValue("curGroup") or {}

            self:setValue("curGroup", {
                curDan = curGroup.curDan or 0,
                danDiff = curGroup.danDiff or 0,
                score = (v and v.score) or curGroup.score or 0,
                rank = (v and v.rank) or curGroup.rank or 0,
            })
        end

        if data.friendList then
            self:setValue("friendList", data.friendList)
        end

        if data.userHistory then
            self:setValue("userHistory", data.userHistory)
        end

        self:setValue("isFromServer", true)

        self:makeTaskBaseId()
    end
end

-- 在线/离线领奖
function Model:onResponseLevelPromotionV2Reward2024(response, reqParam)
    if response:isSuccess() then
        local data = response:getData()
        local taskInfo = reqParam.taskInfo
        local rewardType = reqParam.rewardType
        local leftCollectionNum = reqParam.leftCollectionNum
        local dcSource = "questrewards"
        local plug = self:getTempData("ActSendPlug")
        plug:handleRewardByProtocol("levelPromotionV2Reward2024",data)
        if rewardType == PromotionEvent2025Const.RewardType.kFinishTask and not taskInfo.online then
            data = {rewardList = table.clone(taskInfo.rewards)}
        end

        if rewardType == PromotionEvent2025Const.RewardType.kFinishTask or rewardType == PromotionEvent2025Const.RewardType.kFinishTasks then
            local collectionNum = self:getCollectNum()
            self:setValue("collectionNum", leftCollectionNum or (collectionNum - taskInfo.total))
            self:setValue("taskIndex", taskInfo.curTaskIndex or 0)
        end

        if rewardType == PromotionEvent2025Const.RewardType.kRankRward then
            self:setValue("needGetHistoryRankReward", false)
            dcSource = "rankingrewards"
        end

        if rewardType == PromotionEvent2025Const.RewardType.kSetLocation then
            self:setValue("location", reqParam.rewardId)
        end

        if data.shareRewardBean then
            self:setLastShareRewardBean(data.shareRewardBean)
        end

        if data.finishRewardPeopleCount and tonumber(data.finishRewardPeopleCount) > 0 then
            self:setValue("finishRewardPeopleCount", data.finishRewardPeopleCount)
        end

        if data.groupRankInfo then
            if data.groupRankInfo.rankList then
                table.sort(data.groupRankInfo.rankList, function(a, b)
                    if a.score > b.score then
                        return true
                    elseif a.score == b.score then
                        if tonumber(a.updateTime) ==  tonumber(b.updateTime) then
                            return tonumber(a.uid) <  tonumber(b.uid)
                        else
                            return tonumber(a.updateTime) < tonumber(b.updateTime)
                        end
                    else
                        return false
                    end
                end)

                for i, v in ipairs(data.groupRankInfo.rankList) do
                    v.rank = i
                end
            end

            self:setValue("groupRankInfo", data.groupRankInfo)

            local myUid = _G.amfBean("ProfileManager"):getUid()
            local v, k = table.find(data.groupRankInfo.rankList or {}, function(v)
                return tonumber(v.uid) == tonumber(myUid)
            end)

            local curGroup = self:getValue("curGroup") or {}

            self:setValue("curGroup", {
                curDan = curGroup.curDan or 0,
                danDiff = curGroup.danDiff or 0,
                score = (v and v.score) or curGroup.score or 0,
                rank = (v and v.rank) or curGroup.rank or 0,
            })
        end

        _G.amfTransaction(_G.AMFEventConst.TransactionType.EXCHANGE_SHOP_TASK, {
            subCmd = "processEvent",
            subData = {
                rewardDirectList = data.rewardList,
                evt = response,
                feature = "newpromotion",
                source = dcSource,
                endCall = function(callData)
                    if not table.isEmpty(callData.rewardDirectList) then
                        self:addRewards(callData.rewardDirectList, "newpromotion", dcSource)
                    end
                end
            }
        })

        -- 如果有就覆盖buff
        self:setValue("buffMap", data.buffMap or self.buffMap)
    end
end

function Model:onResponseLevelPromotionV2GetCurGroup(response, reqParam)
    if response:isSuccess() then
        local data = response:getData()
        local curGroup = data.curGroup or {}
        self:setValue("curGroup", curGroup)
    end
end

function Model:onResponseLevelPromotionV2Rank(response, reqParam)
    if response:isSuccess() then
        local data = response:getData()
        if data.shareRewardBean then
            self:setLastShareRewardBean(data.shareRewardBean)
        end

        if reqParam.requestPeriod == self:getPeriod() then
            table.sort(data.rankList or {}, function(a, b)
                if a.score > b.score then
                    return true
                elseif a.score == b.score then
                    if tonumber(a.updateTime) ==  tonumber(b.updateTime) then
                        return tonumber(a.uid) <  tonumber(b.uid)
                    else
                        return tonumber(a.updateTime) < tonumber(b.updateTime)
                    end
                else
                    return false
                end
            end)

            for i, v in ipairs(data.rankList or {}) do
                v.rank = i
            end

            if reqParam.rankType == 1 or reqParam.rankType == PromotionEvent2025Const.SpecNoProfileGroupRankType then
                self:setValue("groupRankInfo", {
                    rankList = data.rankList or {},
                    profiles = data.profiles or {},
                    rankRewardAcquired = data.rankRewardAcquired or false,
                    groupSize = data.groupSize or 0,
                    rewards = data.rewards or {},
                })

                local myUid = _G.amfBean("ProfileManager"):getUid()
                local v, k = table.find(data.rankList or {}, function(v)
                    return tonumber(v.uid) == tonumber(myUid)
                end)

                local curGroup = self:getValue("curGroup") or {}

                self:setValue("curGroup", {
                    curDan = curGroup.curDan or 0,
                    danDiff = curGroup.danDiff or 0,
                    score = (v and v.score) or curGroup.score or 0,
                    rank = (v and v.rank) or curGroup.rank or 0,
                })
            end
        end
    end
end

function Model:onResponseShareShow2024Reward(response, reqParam)
    if response:isSuccess() then
        local data = response:getData()
        if data.shareRewardBean and data.shareRewardBean.shareRewardItemList then
            self:addRewards(data.shareRewardBean.shareRewardItemList, "app_share_vx", "share_success")
            self:setLastShareRewardBean(data.shareRewardBean)
        end
    end
end

--------------------------------- 业务相关 ---------------------------------

-- 记得注册特殊道具
function Model:addRewards(rewardList, feature, source)
    if rewardList and #rewardList > 0 then
        GainPropData:create()
            :setFeature(feature)
            :setSource(source)
            :setProps(rewardList)
            :execute()
    end
end

function Model:isDataEnabled()
    return self:getValue("isFromServer") and self:isCurVersion()
end

function Model:getConfigValue(key)
    return self:getValue("serverVersionedConfig.config."..key)
end

function Model:isCurVersion()
    return self:getValue("openVersion") == PromotionEvent2025Const.OpenVersion.kNew
end

function Model:isClose()
    return self:getValue("state") == PromotionEvent2025Const.State.kClose
end

function Model:isPreHeat()
    return self:getValue("state") == PromotionEvent2025Const.State.kPreheat
end

function Model:isRest()
    return self:getValue("state") == PromotionEvent2025Const.State.kRest
end

function Model:isOpen()
    return self:getValue("state") == PromotionEvent2025Const.State.kOpen
end

function Model:getCollectNum()
    return self:getValue("collectionNum")
end

function Model:addCollectNum(num)
    self:setValue("collectionNum", self:getCollectNum() + num)
    self:setTempData("lastCollectCount", num)
end

function Model:clearLastCollectCount()
    self:setTempData("lastCollectCount", 0)
end

function Model:getLastCollectCount()
    return self:getTempData("lastCollectCount") or 0
end

function Model:getShowCollectNum()
    return self:getValue("showCollectNum")
end

function Model:syncShowCollectNum()
    self:setValue("showCollectNum", self.collectionNum)
end

function Model:clearShowCollectNum()
    self:setValue("showCollectNum", 0)
end

function Model:isResultConfirmed()
    return self:getValue("resultConfirmed") or self:getValue("lastPeriod") <= 0
end

function Model:needHistoryRankReward()
    return self:getValue("needGetHistoryRankReward") and self:getValue("lastPeriod") > 0
end

function Model:getLastPeriod()
    return self:getValue("lastPeriod")
end

function Model:getGroupRankInfo()
    return self:getValue("groupRankInfo")
end

function Model:getFriendInfo()
    return self:getValue("friendList")
end

function Model:getUserHistory()
    return self:getValue("userHistory")
end

function Model:getCompleteTaskIndex()
    return self:getValue("taskIndex")
end

function Model:getCurTaskIndex()
    return self:getCompleteTaskIndex() + 1
end

function Model:getFinalTaskIndex()
	local finalTask = self:getConfigValue("finalTask")
	return finalTask.taskIndex
end

function Model:isFinishAllTask()
    local cureTaskIndex = self:getCurTaskIndex()
    local finalTaskIndex = self:getFinalTaskIndex()
    return cureTaskIndex > finalTaskIndex
end

function Model:getCurPeriodConfig()
	local periods = self:getConfigValue("periods")
    local curPeriod = self:getValue("curPeriod") or 0
	for k,v in pairs(periods) do
		if v.period == curPeriod then
			return v
		end
	end

	return {}
end

--本期结束时间 只能在开放期间取值否则会出问题
function Model:getPeriodEndTime()
    if self:getValue("curPeriod") <= 0 then return 0 end

	local curConfig = self:getCurPeriodConfig()
    if not curConfig.endTs then return 0 end

	return math.floor(tonumber(curConfig.endTs) / 1000)
end

--本期开始时间 只能在开放期间取值否则会出问题
function Model:getPeriodBeginTime()
	if self:getValue("curPeriod") <= 0 then return 0 end

	local curConfig = self:getCurPeriodConfig()
    if not curConfig.beginTs then return 0 end

	return math.floor(tonumber(curConfig.beginTs) / 1000)
end

--只能在预热期调用
function Model:getPreHeatEndTime()
    local periods = self:getConfigValue("periods")

	if periods[1] then
		return math.floor(tonumber(periods[1].beginTs)/1000)
	end

	return 0
end

--只能休赛期调用
function Model:getRestEndTime()
	local periods = self:getConfigValue("periods")

	if periods[1] then
		return math.floor(tonumber(periods[1].beginTs)/1000)
	end

	return 0
end

function Model:getMaxRankRewad()
	local curDanReward = self:getConfigValue("curDanReward")
	local maxRank = 0
	for k,v in pairs(curDanReward) do
		maxRank = math.max(maxRank,v.high)
	end
	return maxRank
end

--段位
function Model:getDan()
    local curGroup = self:getValue("curGroup") or {}
    if not curGroup.curDan or curGroup.curDan == 0 then
        return 1
    else
        return curGroup.curDan
    end
end

function Model:getLastDanDiff()
    return self:getValue("lastDanDiff") or 0
end

function Model:getPeriod()
    return self:getValue("curPeriod") or 0
end

--终极大奖 不管这个人什么等级产品保证最终奖励都一样
function Model:getFinalReward()
	local finalTask = self:getConfigValue("finalTask")
	return finalTask.rewards.list[1]
end

function Model:isFullLevelAndFullStar()
    return _G.amfBean("UserStateManager"):getUserLevelState() == _G.UserStateConst.UserLevelState.TOP_STAR
end

function Model:shouldUseSpecialRewards(taskBaseId)
    return tonumber(taskBaseId) == 99 and self:isFullLevelAndFullStar()
end

function Model:getTaskBaseRewards(taskConfig, taskBaseId)
    if self:shouldUseSpecialRewards(taskBaseId) and not table.isEmpty(taskConfig.specialRewards and taskConfig.specialRewards.list) then
        return taskConfig.specialRewards.list, true
    end

    return taskConfig.rewards.list, false
end

-- 获取全任务奖励，包含额外奖励
function Model:getAllTaskInfos()
    local curTaskIndex = self:getCurTaskIndex()
	local tasks = self:getConfigValue("tasks")
    local taskBaseId = self:getTaskBaseId()--self:getValue("taskBaseId")
    local taskAreaConfig = tasks[tostring(taskBaseId)]
    local ret = {}

    for i,v in pairs(taskAreaConfig) do
        local normalRewards = self:getTaskBaseRewards(v, taskBaseId)
        normalRewards = self:getReplaceRewards(normalRewards,v.taskIndex)
        local extraReward = self:getExtraRewards({
            total = v.target,
            taskBaseId = taskBaseId,
            rewards = normalRewards,
            taskIndex = v.taskIndex,
        })


        ret[i] = {
            boxIcon = v.boxIcon and (v.boxIcon ~= ""),
            rewards = normalRewards,
            extraReward = extraReward,
            target = v.target,
            taskIndex = v.taskIndex,
        }
    end
    local curTaskInfo = self:getCurTaskInfo()
    if curTaskInfo then
        ret[curTaskInfo.curTaskIndex] = {
            boxIcon = curTaskInfo.curBoxIcon,
            rewards = curTaskInfo.replaceRewards,
            extraReward = curTaskInfo.extraReward,
            target = curTaskInfo.total,
            taskIndex = curTaskInfo.curTaskIndex,
        }
    end

    return ret
end

--当前任务信息
function Model:getCurTaskInfo()
	local curTaskIndex = self:getCurTaskIndex()
	local tasks = self:getConfigValue("tasks")

	self:makeTaskBaseId()

    local taskBaseId = self:getValue("taskBaseId")
    local taskAreaConfig = tasks[tostring(taskBaseId)]

    for k,v in pairs(taskAreaConfig) do
        if curTaskIndex == v.taskIndex then
            local normalRewards, useSpecialRewards = self:getTaskBaseRewards(v, taskBaseId)
            local oriRewards = table.clone(normalRewards)
            normalRewards = self:getReplaceRewards(normalRewards,v.taskIndex)
            local replaceRewards = table.clone(normalRewards)
            local extraReward = self:getExtraRewards({
                total = v.target,
                taskBaseId = taskBaseId,
                rewards = normalRewards,
                taskIndex = v.taskIndex,
            })
            local rewards = table.union(normalRewards, extraReward)

            return {
                total = v.target,
                rewards = rewards,
                online = v.forceConnect,
                curTaskIndex = curTaskIndex,
                taskBaseId = taskBaseId,
                isLast = curTaskIndex == #taskAreaConfig,
                curBoxIcon = (v.boxIcon ~= "") and v.boxIcon,
                extraReward = extraReward,
                replaceRewards = replaceRewards,
                oriRewards = oriRewards,
                useSpecialRewards = useSpecialRewards,
            }
        end
    end
end

function Model:getCanRewardsTaskDataForAll()
    local taskIndex = self:getCompleteTaskIndex()
	local curTaskIndex = self:getCurTaskIndex()

    self:makeTaskBaseId()

    local tasks = self:getConfigValue("tasks")
	local collectionNum = self:getCollectNum()
    local list = {}
    local dataList = {}

    local taskBaseId = self:getValue("taskBaseId")
	local taskAreaConfig = tasks[tostring(taskBaseId)]

    for kk,vv in pairs(taskAreaConfig) do
        if curTaskIndex == vv.taskIndex then
            if collectionNum >= vv.target then
                collectionNum = collectionNum - vv.target
                table.insert(list, curTaskIndex)
                local normalRewards, useSpecialRewards = self:getTaskBaseRewards(vv, taskBaseId)
                table.insert(dataList,{
                    total = vv.target,
                    rewards = normalRewards,
                    online = vv.forceConnect,
                    curTaskIndex = curTaskIndex,
                    taskBaseId = taskBaseId,
                    useSpecialRewards = useSpecialRewards,
                })
                curTaskIndex = curTaskIndex + 1
            else
                break
            end
        end
    end

    return list, collectionNum, dataList, #taskAreaConfig
end

-- 获取指定taskIndex的全等级段任务的奖励，多个等级段任务奖励如果不同，会都塞进去
function Model:getNormalTaskRewards(taskIndex)
    local tasks = self:getConfigValue("tasks")
    local ret = {}
    for k, v in pairs(tasks) do
        local normalRewards = self:getTaskBaseRewards(v[taskIndex], k)
        local reward = table.clone(normalRewards[1])
        local needInsert = true
        for no, rewardV in pairs(ret) do
            if reward.itemId == rewardV.itemId and reward.num == rewardV.num then
                needInsert = false
                break
            end
        end
        if needInsert then
            table.insert(ret,reward)
        end
    end
    local periodConfig = self:getCurPeriodConfig()
    local taskType = periodConfig.taskType
    local plug = self:getTempData("ActSendPlug")
    ret = plug:replaceProgressReward(ret,taskType,taskIndex)
    return ret
end

-- 仅当单领奖协议回调时或全领奖协议（补领）开始时force置为true，目的是缓存当前次已显示的奖励，从下次开始才算新的奖励区间
function Model:makeTaskBaseId(force)
	if force or self:getValue("taskBaseIdPeriod") ~= self:getValue("curPeriod") or self:getValue("taskBaseId") == 0 then
		self:setValue("taskBaseId", self:getTaskBaseId())
        self:setValue("taskBaseIdPeriod", self:getValue("curPeriod"))
    end

    -- 2025.5.15 新增分组后，极少新分组用户的baseTaskId和tasks中的key对不上, 打log，强行重算一次
    local tasks = self:getConfigValue("tasks")
    local taskBaseId = self:getValue("taskBaseId")
	local taskAreaConfig = tasks[tostring(taskBaseId)]
    if not taskAreaConfig then
        local keys = table.keys(tasks)
        local newTaskBaseId = self:getTaskBaseId()
        if newTaskBaseId == taskBaseId then
            he_log_error("promotionevent2025 makeTaskBaseId -- taskAreaConfig is nil, current taskBaseId = " .. taskBaseId .. ", judge baseTaskId now == taskBaseId, tasks keys = " .. tts(keys))
            self:setValue("taskBaseId", 1)
        else
            he_log_error("promotionevent2025 makeTaskBaseId -- taskAreaConfig is nil, current taskBaseId = " .. taskBaseId .. ", judge baseTaskId now = "..newTaskBaseId..", tasks keys = " .. tts(keys))
            self:setValue("taskBaseId", newTaskBaseId)
        end
    end
end

-- 获取任务基于等级段的id前缀
function Model:getTaskBaseId()
	local taskUserLevelV2 = self:getConfigValue("taskUserLevelV2")
    local serverMaxLevel = self:getConfigValue("maxLevel") or 0
    local localMaxLevel = _G.amfBean("LevelAreaManager"):getGlobalMaxLevel(true)
    local maxLevel = math.max(serverMaxLevel, localMaxLevel)
	local levelId = _G.amfBean("LevelAreaManager"):getTopPassedLevel() or 0

	for k,v in pairs(taskUserLevelV2 or {}) do
        local beginLv, endLv = v.beginLv, v.endLv
        if beginLv <= 0 then beginLv = maxLevel + beginLv end
        if endLv <= 0 then endLv = maxLevel + endLv end

		if beginLv <= levelId and endLv >= levelId then
			return tonumber(k)
		end
	end

	return 1
end

--当前排行榜奖励
function Model:getCurDanRewardByRank(rank)
	local curDanReward = self:getConfigValue("curDanReward")
	for k,v in pairs(curDanReward) do
		if v.high >= rank and rank >= v.low then
			return table.clone(v)
		end
	end
end

--结算期排行榜奖励
function Model:getLastDanRewardByRank(rank)
	local lastDanReward = self:getConfigValue("lastDanReward")
	for k,v in pairs(lastDanReward) do
		if v.high >= rank and rank >= v.low then
			return table.clone(v)
		end
	end
end

function Model:getReplaceRewards(normalRewards,taskIndex)
    local periodConfig = self:getCurPeriodConfig()
    local taskType = periodConfig.taskType
    local plug = self:getTempData("ActSendPlug")
    return plug:replaceProgressReward(normalRewards,taskType,taskIndex)
end

--获取额外要展示的奖励，包括月票和碎片福利期
function Model:getExtraRewards(taskInfo)

    local periodConfig = self:getCurPeriodConfig()
    local taskType = periodConfig.taskType
    local taskIndex = taskInfo.taskIndex
    local oriRewards = taskInfo.rewards or {}

    local strConditionCache = nil
    local extra
    local exchangeShopExtraRewards = {}


    local plug = self:getTempData("ActSendPlug")
    local linkageExtraRewards = plug:getProgresssExtraReward(taskType,taskIndex)

    return table.union(exchangeShopExtraRewards, linkageExtraRewards)
end

function Model:CalTaskDataForGetReward()

    local taskIndex = self:getCompleteTaskIndex()
    local curTaskIndex = self:getCurTaskIndex()

    local tasks = self:getConfigValue("tasks")
    local collectionNum = self:getCollectNum()
    local retList = {}

    -- 先不刷新塞当前的进去
    self:makeTaskBaseId()

    local taskBaseId = self:getValue("taskBaseId")

    local taskAreaConfig = tasks[tostring(taskBaseId)]
    if not taskAreaConfig then return end -- 所有任务已经完成了
    local taskConfig = taskAreaConfig[tonumber(curTaskIndex)]
    if not taskConfig then return end -- 所有任务已经完成了

    local taskState = PromotionEvent2025Const.TaskState.kUnfinish
    if collectionNum >= taskConfig.target then
        taskState = PromotionEvent2025Const.TaskState.kFinished
    end


    local normalRewards, useSpecialRewards = self:getTaskBaseRewards(taskConfig, taskBaseId)
    normalRewards = self:getReplaceRewards(normalRewards,taskConfig.taskIndex)
    local extraReward = self:getExtraRewards({
        total = taskConfig.target,
        taskBaseId = taskBaseId,
        rewards = normalRewards,
        taskIndex = taskConfig.taskIndex,
    })


    local rewards = table.union(normalRewards, extraReward)

    table.insert(retList, {
        taskInfo ={
            total = taskConfig.target,
            rewards = rewards,
            online = taskConfig.forceConnect,
            curTaskIndex = curTaskIndex,
            taskBaseId = taskBaseId,
            isLast = curTaskIndex == #taskAreaConfig,
            curBoxIcon = (taskConfig.boxIcon ~= "") and taskConfig.boxIcon,
            useSpecialRewards = useSpecialRewards,
        },
        taskState = taskState,
        collectionNum = collectionNum,
    })
    curTaskIndex = curTaskIndex + 1
    if collectionNum >= taskConfig.target then
        collectionNum = collectionNum - taskConfig.target
    end

    -- 如果还有再塞剩下的，注意从下一个开始要算等级跃迁，要先刷新
    -- 2025.5.12 修改，不能无脑重置，当前奖也没有时会把当前也刷掉。
    -- 当前之后的奖励应当永远是现算的
    local newTaskBaseId = self:getTaskBaseId()
    local taskAreaConfig = tasks[tostring(newTaskBaseId)]
    local totalNum = #taskAreaConfig

    for k,v in pairs(taskAreaConfig) do
        if curTaskIndex == v.taskIndex then

            local normalRewards, useSpecialRewards = self:getTaskBaseRewards(v, newTaskBaseId)
            normalRewards = self:getReplaceRewards(normalRewards,v.taskIndex)

            local extraReward = self:getExtraRewards({
                total = v.target,
                taskBaseId = taskBaseId,
                rewards = normalRewards,
                taskIndex = v.taskIndex,
            })

            local rewards = table.union(normalRewards, extraReward)

            local taskInfo = {
                total = v.target,
                rewards = rewards,
                online = v.forceConnect,
                curTaskIndex = curTaskIndex,
                taskBaseId = newTaskBaseId,
                isLast = curTaskIndex == totalNum,
                curBoxIcon = (v.boxIcon ~= "") and v.boxIcon,
                useSpecialRewards = useSpecialRewards,
            }

            local taskState = PromotionEvent2025Const.TaskState.kUnfinish
            if collectionNum >= v.target then
                taskState = PromotionEvent2025Const.TaskState.kFinished
            end

            table.insert(retList, {
                taskInfo = taskInfo,
                taskState = taskState,
                collectionNum = collectionNum,
            })

            if collectionNum >= v.target then
                collectionNum = collectionNum - v.target
                curTaskIndex = curTaskIndex + 1
            else
                break
            end
        end
    end

    return retList
end

function Model:resetAndCalTaskDataForGetReward()
    local dataList = self:CalTaskDataForGetReward()
    self:setTempData("lastTaskProgressInfo", dataList or {})
end

function Model:setTaskDataStateByTaskIndex(taskIndex, state)
    local lastTaskProgressInfo = self:getTempData("lastTaskProgressInfo")
    for k,v in pairs(lastTaskProgressInfo) do
        if taskIndex == v.taskInfo.curTaskIndex then
            v.taskState = state
            break
        end
    end

    self:setTempData("lastTaskProgressInfo", lastTaskProgressInfo)
end

-- 领奖失败标记（追加字段，不改 taskState 语义）：
-- 写进本次过关的进度数据后，banner 通过已有的 RefreshData 轮询就能读到，旧逻辑不受影响。
function Model:setTaskRewardFailedByTaskIndex(taskIndex, failed)
    local lastTaskProgressInfo = self:getTempData("lastTaskProgressInfo")
    if not lastTaskProgressInfo then return end
    for k,v in pairs(lastTaskProgressInfo) do
        if taskIndex == v.taskInfo.curTaskIndex then
            v.rewardFailed = failed == true
            break
        end
    end

    self:setTempData("lastTaskProgressInfo", lastTaskProgressInfo)
end

function Model:getTaskDataByTaskIndex(taskIndex)
    local lastTaskProgressInfo = self:getTempData("lastTaskProgressInfo")
    for k,v in pairs(lastTaskProgressInfo) do
        if taskIndex == v.taskInfo.curTaskIndex then
            return v
        end
    end
end

function Model:setRewardFailFlag(flag)
    self:setTempData("rewardFailFlag", flag)
end

function Model:getRewardFailFlag()
    return self:getTempData("rewardFailFlag")
end

function Model:addBuffItem(itemId, num)
	local endTime = self:getBuffTimeByItemId(itemId)

	if endTime < TimeKit:timeInMillis() then
        endTime = TimeKit:timeInMillis() + num * 60 * 1000
	else
        endTime = endTime + num * 60 * 1000
	end

    local buffMap = self:getValue("buffMap")
    buffMap[tostring(itemId)] = tostring(endTime)
    self:setValue("buffMap", buffMap)
end

function Model:getBuffMap()
    return self:getValue("buffMap")
end

function Model:getBuffTimeByItemId(itemId)
    local buffMap = self:getBuffMap()
    if not buffMap[tostring(itemId)] then
        return 0
    else
        return tonumber(buffMap[tostring(itemId)])
    end
end

function Model:getBuffTimeByItemType(itemType)
    local itemId = PromotionEvent2025Const.PEItemList[itemType].itemId
    return self:getBuffTimeByItemId(itemId)
end

--收集物buff结束时间
function Model:getCollectionBuffEndTime()
    local rawTime = self:getBuffTimeByItemType(PromotionEvent2025Const.PEItemType.kCollect100)
	return math.floor(rawTime/1000)
end

--收集物buff ！额外！ 加成因子
function Model:getCollectionFactor()
	return 1
end

--银币buff结束时间
function Model:getCoinBuffEndTime()
    local rawTime50 = self:getBuffTimeByItemType(PromotionEvent2025Const.PEItemType.kCoin50)
    local rawTime100 = self:getBuffTimeByItemType(PromotionEvent2025Const.PEItemType.kCoin100)
    return math.floor(math.max(rawTime50, rawTime100)/1000)
end

--银币buff额外的加成
function Model:getCoinFactor()
	local rawTime50 = self:getBuffTimeByItemType(PromotionEvent2025Const.PEItemType.kCoin50)
	local rawTime100 = self:getBuffTimeByItemType(PromotionEvent2025Const.PEItemType.kCoin100)

	if rawTime50 > rawTime100 then
		return 0.5
	elseif rawTime50 <= rawTime100 then
		return 1
	else
		return 0
	end
end

--分数buff结束时间
function Model:getScoreBuffEndTime()
    local rawTime = self:getBuffTimeByItemType(PromotionEvent2025Const.PEItemType.kScore10)
	return math.floor(rawTime/1000)
end

--分数buff额外的加成
function Model:getScoreFactor()
	return 0.1
end

function Model:generateInitTaskData()
    local curTaskInfo = self:getCurTaskInfo()
    if not curTaskInfo then
        self:setTempData("initTaskData", nil)
        return
    end
    local collectionNum = self:getCollectNum()
    local taskState = collectionNum >= curTaskInfo.total and PromotionEvent2025Const.TaskState.kFinished or PromotionEvent2025Const.TaskState.kUnfinish
    local initTaskData = {
        taskState = taskState,
        taskInfo = curTaskInfo,
        collectionNum = collectionNum,
    }
    self:setTempData("initTaskData", initTaskData)
end

-- 碎片福利期和月票有可能过期， 所以要展示前单独校验
function Model:checkAndModInitTask()
    local initTaskData = self:getInitTaskData()
    if not initTaskData then return end

    local taskInfo = initTaskData.taskInfo
    local rewards  = taskInfo.rewards
    local extrarewards = taskInfo.extr

    local normalRewards = self:getReplaceRewards(taskInfo.oriRewards, taskInfo.curTaskIndex)
    local extraReward = self:getExtraRewards({
        total = taskInfo.total,
        taskBaseId = taskInfo.taskBaseId,
        rewards = normalRewards,
        taskIndex = taskInfo.curTaskIndex,
    })

    taskInfo.rewards = table.union(normalRewards, extraReward)
    self:setTempData("initTaskData", initTaskData)
end

function Model:getCurInitTaskData()
    local lastTaskProgressInfo = self:getTempData("lastTaskProgressInfo")
    if not lastTaskProgressInfo or #lastTaskProgressInfo == 0 then
        return nil
    else
        return lastTaskProgressInfo[1]
    end
end

-- 本次过关可领取的完整奖励序列（按领取顺序），供 banner 连续领奖表现使用。
-- 每项含 taskInfo 与该步时点的剩余进度 collectionNum。
function Model:getRewardProgressList()
    local lastTaskProgressInfo = self:getTempData("lastTaskProgressInfo")
    if not lastTaskProgressInfo or #lastTaskProgressInfo == 0 then
        return nil
    end
    return table.clone(lastTaskProgressInfo, true)
end

function Model:getInitTaskData()
    return self:getTempData("initTaskData")
end

--排行
function Model:getRank()
	local curGroup = self:getValue("curGroup") or {}
	return curGroup.rank or 0
end

function Model:getIconV2ProgressState()
    local current = tonumber(self:getValue("collectionNum")) or 0
    local currentTaskIndex = (tonumber(self:getValue("taskIndex")) or 0) + 1
    local taskBaseId = self:getValue("taskBaseId")
    local taskBaseIdPeriod = self:getValue("taskBaseIdPeriod")
    local currentPeriod = self:getValue("curPeriod")
    if tonumber(taskBaseId) == nil or tonumber(taskBaseId) == 0 or taskBaseIdPeriod ~= currentPeriod then
        local resolved, resolvedTaskBaseId = pcall(self.getTaskBaseId, self)
        if resolved then
            taskBaseId = resolvedTaskBaseId
        end
    end
    local tasks = self:getConfigValue("tasks")
    local taskAreaConfig = type(tasks) == "table" and tasks[tostring(taskBaseId)] or nil
    if type(taskAreaConfig) ~= "table" then
        return current, 0
    end
    for _, taskConfig in pairs(taskAreaConfig) do
        if tonumber(taskConfig.taskIndex) == currentTaskIndex then
            return current, tonumber(taskConfig.target) or 0
        end
    end
    return current, 0
end

--分数
function Model:getScore()
	local curGroup = self:getValue("curGroup") or {}
	return curGroup.score or 0
end

function Model:getIsNewIcon()
    local curPeriod = self:getPeriod()
    local newIconFlags = self:getValue("newIconFlags") or {}
    return not newIconFlags[tostring(curPeriod)]
end

function Model:setIconIsShow()
    local curPeriod = self:getPeriod()
    local newIconFlags = self:getValue("newIconFlags") or {}
    newIconFlags[tostring(curPeriod)] = true
    self:setValue("newIconFlags", newIconFlags)
end

function Model:getLocation()
    local location = self:getValue("location")
    return tonumber(location)
end

function Model:setLocation(location)
    self:setValue("location", location)
end

-- 分享用信息
function Model:setLastShareRewardBean(shareRewardBean)
    self:setTempData("lastShareRewardBean", shareRewardBean)
end

function Model:getLastShareRewardBean()
    local lastShareRewardBean = self:getTempData("lastShareRewardBean")
    return lastShareRewardBean
end

function Model:getFragmentWelfareInfo()
    local fragmentWelfarePeriodMetaList = self:getConfigValue("fragmentWelfarePeriodMetaList")
    if not fragmentWelfarePeriodMetaList then return end

    local curTime = TimeKit:timeInMillis()
    for _, v in pairs(fragmentWelfarePeriodMetaList) do
        if tonumber(v.actId) == PromotionEvent2025Const.FeatureId then
            if curTime < v.endTime and curTime > v.beginTime then
                return {
                    isInWelfare = true,
                    welfareRate = v.welfareRate,
                    endTime = v.endTime,
                }
            end
        end
    end
end

function Model:setPreInFlag(period)
    period = period or self:getPeriod()
    local showPreInFlags = self:getValue("showPreInFlags") or {}
    showPreInFlags[tostring(period)] = true
    self:setValue("showPreInFlags", showPreInFlags)
end

function Model:getPreInFlag(period)
    period = period or self:getPeriod()
    local showPreInFlags = self:getValue("showPreInFlags") or {}
    return showPreInFlags[tostring(period)]
end

function Model:setLastRankFlag(period)
    period = period or self:getPeriod()
    local showLastRankFlags = self:getValue("showLastRankFlags") or {}
    showLastRankFlags[tostring(period)] = true
    self:setValue("showLastRankFlags", showLastRankFlags)
end

function Model:getLastRankFlag(period)
    period = period or self:getPeriod()
    local showLastRankFlags = self:getValue("showLastRankFlags") or {}
    return showLastRankFlags[tostring(period)]
end

function Model:setMainPanelFlag(period)
    period = period or self:getPeriod()
    local showMainPanelFlags = self:getValue("showMainPanelFlags") or {}
    showMainPanelFlags[tostring(period)] = true
    self:setValue("showMainPanelFlags", showMainPanelFlags)
end

function Model:getMainPanelFlag(period)
    period = period or self:getPeriod()
    local showMainPanelFlags = self:getValue("showMainPanelFlags") or {}
    return showMainPanelFlags[tostring(period)]
end

function Model:getHandGuideFlag()
    local handGuideFlag = self:getValue("handGuideFlag")
    return handGuideFlag
end

function Model:setHandGuideFlag()
    self:setValue("handGuideFlag", true)
end

function Model:getCurRankDiff()
    local curGroupInfo = self:getGroupRankInfo()

    local rankDiff = 0
    local myUid = _G.amfBean("ProfileManager"):getUid()
    if curGroupInfo and curGroupInfo.rankList then
        local v, k = table.find(curGroupInfo.rankList, function(v)
            return tonumber(v.uid) == tonumber(myUid)
        end)

        if v and k then
            if k == 1 and curGroupInfo.rankList[2] then
                rankDiff = v.score - curGroupInfo.rankList[2].score
            elseif k ~= 1 and curGroupInfo.rankList[k - 1] then
                rankDiff = v.score - curGroupInfo.rankList[k - 1].score
            end
        end
    end

    return rankDiff
end

function Model:getIconTipFlag(type)
    local curPeriod = self:getPeriod()
    local iconTipFlags = self:getValue("iconTipFlags") or {}
    if not iconTipFlags[tostring(curPeriod)] then
        iconTipFlags[tostring(curPeriod)] = {}
    end
    return iconTipFlags[tostring(curPeriod)][tostring(type)]
end

function Model:setIconTipFlag(type)
    local curPeriod = self:getPeriod()
    local iconTipFlags = self:getValue("iconTipFlags") or {}
    if not iconTipFlags[tostring(curPeriod)] then
        iconTipFlags[tostring(curPeriod)] = {}
    end
    iconTipFlags[tostring(curPeriod)][tostring(type)] = true
    self:setValue("iconTipFlags", iconTipFlags)
end


return Model
