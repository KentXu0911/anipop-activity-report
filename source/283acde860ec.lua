-- 处理UBF加五步面板，长尾步数升级活动-地鼠buff 相关的Util
UBFAddFiveUpgradeBuffUtil = {}

local _selfLogOpened = false
local function logSwitchOpened()
	if _G.debugSwitch and _G.debugSwitch.addFiveStepUpgradeUBFLogForceOpened or _selfLogOpened then
		return true
	end
	return false
end

function UBFAddFiveUpgradeBuffUtil:log(...)
	if _G.debugSwitch and _G.debugSwitch.addFiveStepUpgradeUBFLogForceOpened then
		printx(11, "A5U-BUFF", ...)
		return
	end

	--
--
--
--
--
--
--


	if _G.isLocalDevelopMode and logSwitchOpened() then
		printx(11, "A5U-BUFF", ...)
	end
end

-----------------------------------------------------------------------------------------------
--										Local Data
-----------------------------------------------------------------------------------------------
------------------------------------ 纯本地文件，不受后端数据影响 --------------------------------------
-- 本地数据，文件中用Key区分不同的模块数据
local LocalBuffDataKey = table.const{
	kTriggerRecord = "triggerRecord",					-- 触发记录（成功或失败都会记录，用于标记是否尝试触发过）
	kCurrTriggeredBuffData = "currTriggeredBuffData",	-- 当前触发的buff数据（根据打关结果更新次数据， 生命周期：触发buff -> 打关成功后且领奖完毕/打关失败/错过领奖在下一次触发buff时强制清零）

}

function UBFAddFiveUpgradeBuffUtil:getLocalBuffDataKey()
	return LocalBuffDataKey
end

function UBFAddFiveUpgradeBuffUtil:_getCustomLocalDataFileName()
	local path = UBFGameHelper:getUserFileRoot().."ubfAddFiveStepUpgradeBuffCustomData"
	return path
end

function UBFAddFiveUpgradeBuffUtil:setCustomLocalData(customData, localDataKey)
	if logSwitchOpened() then self:log("=== _setCustomLocalData!!! ", tts(customData), localDataKey) end
	local pathName = UBFAddFiveUpgradeBuffUtil:_getCustomLocalDataFileName()

	-- 有Key的时候，只修改Key的部分
	if localDataKey then
		local fullData = UBFAddFiveUpgradeBuffUtil:getCustomLocalData()
		if customData then
			if not fullData then fullData = {} end
			fullData[localDataKey] = customData
		else
			if fullData then
				fullData[localDataKey] = nil
			end
		end
		customData = fullData
	end

	if customData then
		UBFCachedFile:writeTable(pathName, customData)
	else
		UBFCachedFile:delete(pathName)
	end
end

function UBFAddFiveUpgradeBuffUtil:getCustomLocalData(localDataKey)
	local pathName = UBFAddFiveUpgradeBuffUtil:_getCustomLocalDataFileName()
	local customData = UBFCachedFile:readTable(pathName)
	-- if logSwitchOpened() then self:log("=== _getCustomLocalData:", tts(customData)) end

	if localDataKey and customData then
		return customData[localDataKey]
	else
		return customData
	end
	return nil
end

-----------------------------------------------------------------------------------------------
--											Data
-----------------------------------------------------------------------------------------------
-- 记录触发结果
function UBFAddFiveUpgradeBuffUtil:_recordTriggerList(actData, localData, contextData, triggerSucceed)
	if not actData then actData = UBFAddFiveUpgradeDataUtil:getValidActData() end
	local levelID = contextData.levelID
	if not actData or not levelID then return end
	
	local triggerRecordList = localData[LocalBuffDataKey.kTriggerRecord]
	if not triggerRecordList then
		triggerRecordList = {}
	else
		-- 如果当前 levelID 向前推进了，清理老旧触发列表
		-- List 里的应该都是同一关的触发记录，挑一个检测即可
		local recordData = triggerRecordList[1]
		if recordData and recordData.levelID then
			if levelID > recordData.levelID then
				triggerRecordList = {}
			end
		end
	end

	-- 太长的话，清理一下
	if #triggerRecordList > 20 then
		local trimmedList = {}
		local lastRecord
		for _, record in pairs(triggerRecordList) do
			-- 因为要算CD，所以可以只保留成功触发的
			if record.triggerFlag then
				table.insert(trimmedList, record)
			end
			if not lastRecord or (record.failTimes > lastRecord.failTimes) then
				lastRecord = record
			end
		end
		-- 最后一条记录是触发失败的，也保留
		if lastRecord and not lastRecord.triggerFlag then
			table.insert(trimmedList, lastRecord)
		end
		triggerRecordList = trimmedList
	end

	local triggerFlag = false
	if triggerSucceed then triggerFlag = true end

	local recordData = {
		levelID = levelID,
		failTimes = actData.failTimes or 0,
		triggerFlag = triggerFlag,
		timeStamp = TimeKit:timeInSec(),
	}
	table.insert(triggerRecordList, recordData)
	if logSwitchOpened() then self:log("=== _recordTriggerList:", tts(recordData)) end

	localData[LocalBuffDataKey.kTriggerRecord] = triggerRecordList
	UBFAddFiveUpgradeBuffUtil:setCustomLocalData(localData)
end

-- 删除当前触发的数据
function UBFAddFiveUpgradeBuffUtil:_clearCurrTriggerData()
	if logSwitchOpened() then self:log("=== --- _clearCurrTriggerData --- ===") end
	UBFAddFiveUpgradeBuffUtil:setCustomLocalData(nil, LocalBuffDataKey.kCurrTriggeredBuffData)
end

-- 更新当前触发的数据
function UBFAddFiveUpgradeBuffUtil:_updateCurrTriggerData(triggeredBuffData, updateKey, updateVal)
	if logSwitchOpened() then self:log("=== --- _updateCurrTriggerData --- ===", updateKey, updateVal, tts(triggeredBuffData)) end
	-- 没有传入的话，就取本地的最新值，否则，用传入的更新
	if not triggeredBuffData then
		triggeredBuffData = UBFAddFiveUpgradeBuffUtil:getCustomLocalData(LocalBuffDataKey.kCurrTriggeredBuffData)
	end
	if not triggeredBuffData then return end
	-- 可选择性更新其中的某个值
	if updateKey and updateVal then
		triggeredBuffData[updateKey] = updateVal
	end
	-- 写入数据
	UBFAddFiveUpgradeBuffUtil:setCustomLocalData(triggeredBuffData, LocalBuffDataKey.kCurrTriggeredBuffData)
end

-- 过关更新buff数据
function UBFAddFiveUpgradeBuffUtil:updateBuffDataOnPassLevel(endData)
	local currBuffData = UBFAddFiveUpgradeBuffUtil:getCustomLocalData(LocalBuffDataKey.kCurrTriggeredBuffData)
	if logSwitchOpened() then self:log(">=> updateBuffDataOnPassLevel, currBuffData:", tts(currBuffData)) end
	if currBuffData then
		local triggeredLevelID = currBuffData.levelID
		local triggeredFailTimes = currBuffData.failTimes
		local triggeredPlayID = currBuffData.playID

		local resultIsWin = endData.win
		local resultPlayID
		if endData and endData.replayLog and endData.replayLog.gEnv then
			resultPlayID = endData.replayLog.gEnv.playId
		end
		if logSwitchOpened() then self:log("endData:", resultIsWin, resultPlayID) end
		if resultPlayID and (resultPlayID == triggeredPlayID) then
			if resultIsWin then
				UBFAddFiveUpgradeBuffUtil:_updateCurrTriggerData(currBuffData, "result", 1)
			else
				UBFAddFiveUpgradeBuffUtil:_updateCurrTriggerData(currBuffData, "result", 0)
			end
		end
	end
end

-----------------------------------------------------------------------------------------------
--											Valid
-----------------------------------------------------------------------------------------------
-- 判断了活动的有效性和素材的加载
function UBFAddFiveUpgradeBuffUtil:isEnabled()
	local actData = UBFAddFiveUpgradeDataUtil:getValidActData()
	if actData then
		local outSideManager = _G.amfBean("AddFiveUpgradeManager")
		if outSideManager and outSideManager.isResReady then
			if outSideManager:isResReady() then
				return true
			else
				if logSwitchOpened() then self:log("xxx not isEnabled: res not ready") end
			end
		end
	end
	return false
end

-- V2判断了领奖期的时间
function UBFAddFiveUpgradeBuffUtil:isEnabled2()
	local actData = UBFAddFiveUpgradeDataUtil:getValidActDataV2()
	if actData then 
		local outSideManager = _G.amfBean("AddFiveUpgradeManager")
		if outSideManager and outSideManager.isResReady then
			if outSideManager:isResReady() then
				return true
			else
				if logSwitchOpened() then self:log("xxx not isEnabled2: res not ready") end
			end
		end
	end
	return false
end

-----------------------------------------------------------------------------------------------
--											Trigger
-----------------------------------------------------------------------------------------------
-- 检测是否能触发buff
function UBFAddFiveUpgradeBuffUtil:tryTriggerBuff(contextData)
	if logSwitchOpened() then self:log("=== --- tryTriggerBuff --- ===") end
	local actData = UBFAddFiveUpgradeDataUtil:getValidActData()
	local localData = UBFAddFiveUpgradeBuffUtil:getCustomLocalData() or {}
	if not actData then return end

	-- 被触发记录限制触发：每关的每个失败次数一次、CD期内限制次数
	if UBFAddFiveUpgradeBuffUtil:_triggerBannedByTriggerRecord(actData, localData, contextData) then
		return
	end
	-- 被领奖CD限制触发
	if UBFAddFiveUpgradeBuffUtil:_triggerBannedByRewardCD(actData) then
		return
	end

	-- 检测触发
	local triggerResult = UBFAddFiveUpgradeBuffUtil:_executeTriggerLogic(actData, localData, contextData)
	if triggerResult then
		UBFAddFiveUpgradeBuffUtil:_recordTriggerList(actData, localData, contextData, true)

		-- 初始化触发的内容
		UBFAddFiveUpgradeBuffUtil:_initTriggerData(actData, localData, contextData)
	else
		UBFAddFiveUpgradeBuffUtil:_recordTriggerList(actData, localData, contextData, false)
	end
	if logSwitchOpened() then self:log("=== triggerResult", triggerResult) end
	return triggerResult
end

-- 被触发记录限制触发：每关的每个失败次数一次、CD期内限制次数
function UBFAddFiveUpgradeBuffUtil:_triggerBannedByTriggerRecord(actData, localData, contextData)
	if logSwitchOpened() then self:log("+++ check _triggerBannedByTriggerRecord:") end
	local levelID = contextData.levelID
	local currFailTimes = actData.failTimes or 0	-- 在onBeforeSendPassLevel和闪退不恢复时已更新数值

	local triggerRecord = localData[LocalBuffDataKey.kTriggerRecord]
	if triggerRecord and (#triggerRecord > 0) then
		-- CD：24h最多可触发2次
		local triggerCount = 0
		local CDDuration = 24 * 3600
		local currTime = TimeKit:timeInSec()
		
		for _, record in pairs (triggerRecord) do
			local recordLevel = record.levelID or -1
			local recordFailTimes = record.failTimes or 0
			-- 每关的每个失败次数只检测一次触发，无论检测结果是否成功
			if (recordLevel == levelID) and (recordFailTimes == currFailTimes) then
				if logSwitchOpened() then self:log("=== xxx === Trigger Banned By:", "Level has trigger data:", tts(record)) end
				return true
			else
				-- 计算CD内成功触发的次数
				if record.triggerFlag then
					local recordTs = record.timeStamp
					if currTime < recordTs + CDDuration then
						triggerCount = triggerCount + 1
					end
				end
			end
		end

		if triggerCount >= 2 then
			if logSwitchOpened() then self:log("=== xxx === Trigger Banned By:", "Trigger-CD", triggerCount, tts(triggerRecord)) end
			return true
		end
	end
	return false
end

-- 被领奖CD限制触发
function UBFAddFiveUpgradeBuffUtil:_triggerBannedByRewardCD(actData)
	if logSwitchOpened() then self:log("+++ check _triggerBannedByRewardCD:") end
	
	if actData.lastGetPromoteRewardTime then
		local lastGetPromoteRewardTime = math.floor(tonumber(actData.lastGetPromoteRewardTime) / 1000)
		local promoteRewardCdHours = actData.promoteRewardCdHours

		local currTime = TimeKit:timeInSec()
		local cdEndTime = lastGetPromoteRewardTime + promoteRewardCdHours * 3600
		if logSwitchOpened() then self:log("currTime, cdEndTime", currTime, cdEndTime) end
		if currTime <= cdEndTime then
			if logSwitchOpened() then self:log("=== xxx === Trigger Banned By:", "GetReward-CD") end
			return true
		end
	end
	return false
end

-- 执行触发逻辑
function UBFAddFiveUpgradeBuffUtil:_executeTriggerLogic(actData, localData, contextData)
	if logSwitchOpened() then self:log(">>> _executeTriggerLogic:") end

	local levelID = contextData.levelID
	local currFailTimes = actData.failTimes or 0	-- 在onBeforeSendPassLevel和闪退不恢复时已更新数值
	local currPayTag = UserTagManager:getUserPaymentTag2ServerVersion()
	if logSwitchOpened() then self:log("levelID, currFailTimes, currPayTag", levelID, currFailTimes, currPayTag) end

	-- 本关上次成功触发时的失败次数
	local function getFailTimesOfLastTrigger()
		local lastFailTimes = 0
		local triggerRecord = localData[LocalBuffDataKey.kTriggerRecord]
		if triggerRecord and (#triggerRecord > 0) then
			for _, record in pairs (triggerRecord) do
				-- 只考虑成功触发的情况
				if record.triggerFlag then
					local recordLevel = record.levelID or -1
					if recordLevel == levelID then
						local failTimes = record.failTimes or 0
						if failTimes > lastFailTimes then
							lastFailTimes = failTimes
						end
					end
				end
			end
		end
		-- 因为失败次数是进关时的，是滞后的，当次打关若失败，数值上需要 +1 才是那次的实际失败次数
		if lastFailTimes > 0 then
			lastFailTimes = lastFailTimes + 1
		end
		return lastFailTimes
	end

	local function getCurrTriggerPercentage()
		if currPayTag >= UsetPaymentTagServer.kNone and currPayTag <= UsetPaymentTagServer.kHigh_4 then
			if logSwitchOpened() then self:log("=== getCurrTriggerPercentage, payment group 1:") end

			-- 新分组（App: buff / 小程序: ONstepV2）使用新数值 startTriggerFailNum=3
			local useNewBuffValue = false
			if EnvUtil:isMiniGame() then
				useNewBuffValue = MaintenanceManager:getInstance():isEnabledInGroup("mini_step_v2", "ONstepV2")
			else
				useNewBuffValue = MaintenanceManager:getInstance():isEnabledInGroup("plus_five_0210", "buff")
			end
			local startTriggerFailNum = useNewBuffValue and 3 or 5	-- 新分组用3，其他用5
			local triggerGap = 5 			-- 将来走配置
			local lastTriggerFailNum = getFailTimesOfLastTrigger()
			local gapNum = triggerGap
			if lastTriggerFailNum == 0 then
				gapNum = startTriggerFailNum
			end
			local triggerN = currFailTimes - lastTriggerFailNum - gapNum
			local resultPercentage = math.max(20 + triggerN * 20, 0)
			if logSwitchOpened() then self:log("=== lastTriggerFailNum, triggerGap, triggerN, resultPercentage:", startTriggerFailNum, triggerGap, lastTriggerFailNum, triggerN, resultPercentage) end
			return resultPercentage

		elseif currPayTag >= UsetPaymentTagServer.kHigh_5 and currPayTag <= UsetPaymentTagServer.kHigh_6 then
			if logSwitchOpened() then self:log("=== getCurrTriggerPercentage, payment group 2:") end
			-- 关卡难度限制：难关/超难关
			local MetaManager = _G.amfBean("MetaManager")
			local difficultyFlag = (MetaManager and MetaManager:getLevelDifficultFlag_ForStartPanel(levelID)) or LevelDiffcultFlag.kNormal
			if not (difficultyFlag == LevelDiffcultFlag.kDiffcult or difficultyFlag == LevelDiffcultFlag.kExceedinglyDifficult) then
				if logSwitchOpened() then self:log("=== xxx === Trigger Failed By:", "Difficulty", difficultyFlag) end
				return 0
			end

			-- 每关只能成功触发一次
			local triggerRecord = localData[LocalBuffDataKey.kTriggerRecord]
			if triggerRecord and (#triggerRecord > 0) then
				for _, record in pairs (triggerRecord) do
					-- 只限制成功触发的情况
					if record.triggerFlag then
						local recordLevel = record.levelID or -1
						if recordLevel == levelID then
							if logSwitchOpened() then self:log("=== xxx === Trigger Failed By:", "Level Triggered", levelID) end
							return 0
						end
					end
				end
			end

			if (currFailTimes < 1) or (currFailTimes > 2) then
				if logSwitchOpened() then self:log("=== xxx === Trigger Failed By:", "currFailTimes", currFailTimes) end
				return 0
			end

			return 50
		end
	end
	local triggerPercentage = getCurrTriggerPercentage()
	if logSwitchOpened() then self:log("curr triggerPercentage", triggerPercentage) end
	
	if triggerPercentage and triggerPercentage > 0 then
		local randVal = math.random(0, 100)
		if logSwitchOpened() then self:log("randVal, triggerPercentage", randVal, triggerPercentage) end
		if randVal <= triggerPercentage then
			if logSwitchOpened() then self:log("=== trigger SUCCEED !") end
			return true
		end
		if logSwitchOpened() then self:log("=== trigger FAILED...") end
		return false
	end
	if logSwitchOpened() then self:log("=== trigger FAILED...") end
	return false
end

----------------------------------------- Trigger Content -------------------------------------------
local RewardGroupType = table.const{
	kNone = 0,
	kGroupType1 = 1,
	kGroupType2 = 2,
	kGroupType3 = 3,
	kGroupType4 = 4, --满精力新奖励
	kGroupType5 = 5, --未满精力新奖励
}
-- 初始化一次触发的数据
function UBFAddFiveUpgradeBuffUtil:_initTriggerData(actData, localData, contextData)
	if logSwitchOpened() then self:log(">>> _initTriggerData:") end

	local UserEnergyManager = _G.amfBean("UserEnergyManager")
	local energyNum = UserEnergyManager and UserEnergyManager:getEnergy()
	local isInfiniteEnergy = UserEnergyManager and (UserEnergyManager:getEnergyState() == UserEnergyState.INFINITE)
	local currPayTag = UserTagManager:getUserPaymentTag2ServerVersion()
	if logSwitchOpened() then self:log("energyNum, isInfiniteEnergy, currPayTag", energyNum, isInfiniteEnergy, currPayTag) end

	local function getRewardsFromStr(rewardsStr)
		local rewardStrList = string.split(rewardsStr, ',')
		local rewards = {}
		for i,v in ipairs(rewardStrList) do
			local rewardStr = string.split(v, ':')
			local reward = {itemId = tonumber(rewardStr[1]), num = tonumber(rewardStr[2])}
			table.insert(rewards, reward)
		end
		return rewards
	end

	local function getRewardsAndGroupTypeByConfig(energyConfig, fullEnergyGroup)
		local rewardGroupType = RewardGroupType.kNone
		local rewards = {}

		local index
		for i, v in ipairs(energyConfig) do
			if table.exist(v.tags, currPayTag) then 
				index = i
				rewards = table.clone(getRewardsFromStr(v.rewards))
				break
			end
		end

		if fullEnergyGroup then
			if index == 1 then
				rewardGroupType = RewardGroupType.kGroupType2
			elseif index == 2 then
				rewardGroupType = RewardGroupType.kGroupType4
			end
		else
			if index == 1 then
				rewardGroupType = RewardGroupType.kGroupType2
			elseif index == 2 then
				rewardGroupType = RewardGroupType.kGroupType3
			elseif index == 3 then
				rewardGroupType = RewardGroupType.kGroupType5
			end
		end

		return rewards, rewardGroupType
	end

	local rewards = {}
	local rewardGroupType = RewardGroupType.kNone
	if energyNum > 5 or isInfiniteEnergy then
		local fullEnergyRewardsByTagsConfig = actData and actData.fullEnergyRewardsByTagsConfig or {}
		rewards, rewardGroupType = getRewardsAndGroupTypeByConfig(fullEnergyRewardsByTagsConfig, true)
	else
		local notFullEnergyRewardsByTagsConfig = actData and actData.notFullEnergyRewardsByTagsConfig or {}
		rewards, rewardGroupType = getRewardsAndGroupTypeByConfig(notFullEnergyRewardsByTagsConfig, false)

	end
	if logSwitchOpened() then self:log("rewardGroupType, reward", rewardGroupType, tts(rewards)) end

	-- 确实随机到了buff内容
	if rewardGroupType ~= RewardGroupType.kNone then
		-- 关卡外面板要用的参数包
		local panelParams = { 
			levelId = contextData.levelID, 
			failNum = actData.failTimes or 0, 
			curPayTag = currPayTag, 
			rewards = rewards, 
			rewardGroupType = rewardGroupType,
			energyNum = energyNum,
			isInfiniteEnergy = isInfiniteEnergy,
			playId = contextData.playID or '',
		}
		-- 当前触发的buff数据
		local currBuffData = {
			levelID = contextData.levelID, 
			failTimes = actData.failTimes or 0, 
			playID = contextData.playID or '',

			panelParams = panelParams,
		}
		UBFAddFiveUpgradeBuffUtil:setCustomLocalData(currBuffData, LocalBuffDataKey.kCurrTriggeredBuffData)

		return true
	end
end

-----------------------------------------------------------------------------------------------
--										Start level 
-----------------------------------------------------------------------------------------------
-- 尝试检测 开始面板/重玩面板/失败面板 上的buff弹出
function UBFAddFiveUpgradeBuffUtil:onStartLevelPanelPopout(data, outsideManagerData)
	if logSwitchOpened() then self:log(">>> === onStartLevelPanelPopout!", tts(data)) end
	-- 开始面板，playID 每次点开都会生成一个新的
	-- 失败面板，prePlayID 是之前打关时的，playID 是新生成的
	-- 主动点开的重玩面板，因为当前的打关其实没有结束，所以 playID 是当前正在打的关的
    local levelID = data.levelId
    local levelScene = data.levelScene
	local startLevelType = data.startLevelType	
	local playID = data.playId
	local prePlayID = data.gameBoardPlayId or playID	
	local byFailPanel = data.byFailPanel

	local modContext = data.modContext
	local endCall = data.onEnd

	local function onEnd()
		safeRunCall(endCall)
	end

	-- 一些基础判断
	if not levelID or not UBFLevelSceneFunc:isMainLevel(levelScene) then
		if logSwitchOpened() then self:log("--- skip!", "not main level") end
		onEnd()
        return
    end
	-- 代打skip
	if startLevelType == UBFStartLevelType.kAskForHelp then
		if logSwitchOpened() then self:log("--- skip!", "ask for help") end
		onEnd()
        return
	end
	-- 跳关skip
	local hasSkippedLevel = _G.amfBean("LevelAreaManager") and _G.amfBean("LevelAreaManager"):hasPassedByTrick(levelID)
	if hasSkippedLevel then
		if logSwitchOpened() then self:log("--- skip!", "jump level") end
		onEnd()
        return
	end
	-- 刚开新关一段时间内，打新关不弹
	if UBFAddFiveUpgradeBuffUtil:_forbidPopForTopLevelPlayer() then
		if logSwitchOpened() then self:log("--- skip!", "forbid pop for top level player") end
		onEnd()
        return
	end

	-- 没有长尾活动数据skip
	if not modContext then
		if logSwitchOpened() then self:log("--- skip!", "no modContext data") end
		onEnd()
        return
	end
	-- 当前不是长尾目标关卡(在初始化 modContext 时就已经判断了 actData 随最高关的重置)
	if not modContext.levelID or (levelID ~= modContext.levelID) then
		if logSwitchOpened() then self:log("--- skip!", "not target level") end
		onEnd()
        return
	end

	local currFailTimes = -1
	if modContext.failTimes then
		currFailTimes = modContext.failTimes
	end

	---- 当前已经有触发好的，判断是否直接显示结果面板（成功、失败）
	-- 本地的当前的触发数据记录
	local currBuffData = UBFAddFiveUpgradeBuffUtil:getCustomLocalData(LocalBuffDataKey.kCurrTriggeredBuffData)
	if currBuffData then
		if logSwitchOpened() then self:log(">=> CurrTriggeredBuffData:", tts(currBuffData)) end
		local triggeredLevelID = currBuffData.levelID
		local triggeredFailTimes = currBuffData.failTimes
		local triggeredPlayID = currBuffData.playID

		-- 首先，要是同一关……
		if triggeredLevelID == levelID then
			-- 失败重玩面板，尝试展示获得buff失败面板
			if byFailPanel then
				if logSwitchOpened() then self:log("=== check pop fail panel") end
				-- 领奖有效性
				if UBFAddFiveUpgradeBuffUtil:isEnabled2() then 
					if logSwitchOpened() then self:log("=== enabled for get reward", prePlayID, triggeredPlayID, currBuffData.result) end
					-- 是同一关，并且有打关结果，记录为失败，弹buff失败面板
					if (prePlayID == triggeredPlayID) and currBuffData.result and (currBuffData.result == 0) then
						if logSwitchOpened() then self:log("=== can pop fail panel") end
						if outsideManagerData and outsideManagerData.popoutBuffFailPanel and currBuffData.panelParams then
							if logSwitchOpened() then self:log("=== popoutBuffFailPanel !!") end
							safeRunCall(outsideManagerData.popoutBuffFailPanel({
								panelParam = currBuffData.panelParams,
								endCallback = onEnd,
							}))

							-- 清除触发数据
							UBFAddFiveUpgradeBuffUtil:_clearCurrTriggerData()
							return
						end
					end
				end
			else
				-- 非失败面板，尝试展示已触发的buff
				if logSwitchOpened() then self:log("=== check pop old trigger panel") end
				-- 活动有效性
				if UBFAddFiveUpgradeBuffUtil:isEnabled() then 
					if logSwitchOpened() then self:log("=== act enabled", triggeredFailTimes, currFailTimes, currBuffData.result) end
					-- 是同一关，失败次数一致，没有打关结果，可以显示老的触发内容
					if (triggeredFailTimes == currFailTimes) and (not currBuffData.result) then
						if logSwitchOpened() then self:log("=== can pop old trigger panel") end
						if outsideManagerData and outsideManagerData.popoutTriggerBuffPanel and currBuffData.panelParams then
							if logSwitchOpened() then self:log("=== popoutTriggerBuffPanel !!") end
							safeRunCall(outsideManagerData.popoutTriggerBuffPanel({
								panelParam = currBuffData.panelParams,
								endCallback = onEnd,
							}))

							-- playID可能是新生成的，更新一下本地数据中的playID
							currBuffData["playID"] = playID
							if currBuffData.panelParams then
								currBuffData.panelParams["playId"] = playID
							end
							UBFAddFiveUpgradeBuffUtil:_updateCurrTriggerData(currBuffData)
							return
						end
					end
				end
			end
		else
			if logSwitchOpened() then self:log("not the same level...") end
		end
	end

	---- 没有触发好的，检测触发
	-- 活动有效性
	if not UBFAddFiveUpgradeBuffUtil:isEnabled() then 
		if logSwitchOpened() then self:log("--- skip!", "act not enabled") end
		onEnd()
		return 
	end

	local checkTriggerContext = {
		levelID = levelID,
		playID = playID,
	}
	local triggerResult = UBFAddFiveUpgradeBuffUtil:tryTriggerBuff(checkTriggerContext)
	if triggerResult then
		-- 触发成功了！
		local currBuffData = UBFAddFiveUpgradeBuffUtil:getCustomLocalData(LocalBuffDataKey.kCurrTriggeredBuffData)
		if currBuffData and currBuffData.panelParams and outsideManagerData and outsideManagerData.popoutTriggerBuffPanel then
			if logSwitchOpened() then self:log("=== popoutTriggerBuffPanel, new triggered buff !!") end
			safeRunCall(outsideManagerData.popoutTriggerBuffPanel({
				panelParam = currBuffData.panelParams,
				endCallback = onEnd,
			}))
			return
		end
	end

	onEnd()
end

-- 刚开新关一段时间内不弹
function UBFAddFiveUpgradeBuffUtil:_forbidPopForTopLevelPlayer()
	if logSwitchOpened() then self:log("+++ check _forbidPopForTopLevelPlayer:") end

	-- 满星玩家不管
    local userState = _G.amfBean("UserStateManager"):getUserSegmentState()
    if userState == _G.UserStateConst.UserLevelState.MHZC then
		if logSwitchOpened() then self:log("--- nevermind:", "UserLevelState.MHZC") end
        return false
    end
	-- 不是新关区域不管
    local topLevelId = _G.getTopLevelId()
    if not _G.amfBean("LevelUnLockManager"):isTopNewMainLevel(topLevelId) then 
		if logSwitchOpened() then self:log("--- nevermind:", "not top new MainLevel area") end
        return false
    end
	-- 不是刚开新关的时间不管
    if not _G.amfBean("LevelUnLockManager"):isInNewLevelTime() then 
		if logSwitchOpened() then self:log("--- nevermind:", "not isInNewLevelTime") end
        return false
    end
    
	if logSwitchOpened() then self:log("xxx banned by:", "forbidPopForTopLevelPlayer") end
    return true
end

-----------------------------------------------------------------------------------------------
--										Pass Level
-----------------------------------------------------------------------------------------------
function UBFAddFiveUpgradeBuffUtil:checkAddBuffProcessNodeOnPlp(runtime)
	if logSwitchOpened() then self:log("+++ check checkAddBuffProcessNodeOnPlp") end
	if not runtime then return end
	if UBFAddFiveUpgradeBuffUtil:canPopBuffRewardPanelOnPassLevel(runtime, true) then
		if logSwitchOpened() then self:log("=== add process node!!") end
		runtime:setEnabledProcessNodes(UBFActivityIdConst.kAddFiveStepUpgrade, {
	        [UBFProcessNodeEnum.ADDFIVE_UPGRADE_HAMSTER] = {
	            -- 流程节点是否可以启动
	            isProcessEnabled = true
	        },
	    })
	end
end

-- 成功过关面板上可以弹buff领奖面板
function UBFAddFiveUpgradeBuffUtil:canPopBuffRewardPanelOnPassLevel(runtime, initCheck)
    local levelID = runtime and runtime:getLevelId()
    local playID = runtime and runtime:getPlayId()
    local isWin = runtime and runtime:isWin()
	if logSwitchOpened() then self:log("+++ check canPopBuffRewardPanelOnPassLevel:", levelID, playID, isWin, initCheck) end
    if not isWin then 
		if logSwitchOpened() then self:log("xxx nah:", "play failed") end
		return false 
	end

	local currBuffData = UBFAddFiveUpgradeBuffUtil:getCustomLocalData(LocalBuffDataKey.kCurrTriggeredBuffData)
	if logSwitchOpened() then self:log("+++ check canPopBuffRewardPanelOnPassLevel, currBuffData:", tts(currBuffData)) end
	if not currBuffData then 
		if logSwitchOpened() then self:log("xxx nah:", "no currBuffData") end
		return false
	end

	-- 领奖有效性
	if not UBFAddFiveUpgradeBuffUtil:isEnabled2() then
		if logSwitchOpened() then self:log("xxx nah:", "not enabled for get reward") end
		return false
	end
	-- 刚开新关一段时间内，打新关不弹
	if UBFAddFiveUpgradeBuffUtil:_forbidPopForTopLevelPlayer() then
		if logSwitchOpened() then self:log("xxx nah:", "forbid pop for top level player") end
		return false
	end

	-- 一个程序用于排查弹面板的打点，近似还原下原关卡外的关注的内容吧
	if initCheck then
		if levelID then
			if UBFAddFiveStepUpgradeUtil then
				UBFAddFiveStepUpgradeUtil:sendDC('long_tail','passPanelShowCheck', {
					t1 = currBuffData.levelID, 
					t2 = currBuffData.playID, 
					t3 = levelID,
					t4 = playID,
					result = currBuffData.result,
					gotten = currBuffData.rewardGotten,
				})
			end
		end
	end

	if levelID and playID and levelID == currBuffData.levelID and playID == currBuffData.playID then
		if UBFAddFiveUpgradeBuffUtil:_wantPopBuffRewardPanel(currBuffData) then	
			if logSwitchOpened() then self:log("=== can pop panel!") end
			return true
		end
	end
	if logSwitchOpened() then self:log("xxx nah:", "data not matched") end
	return false
end

-- 检测场景3是否可以强弹
-- 场景3的强弹不考虑领奖数据是否与打关的匹配，有自己的一套允许逻辑
function UBFAddFiveUpgradeBuffUtil:canPopBuffRewardPanelOnScene3(params)
	if logSwitchOpened() then self:log("+++ check canPopBuffRewardPanelOnScene3:", tts(params)) end

	local levelID = params and params.levelID
	local levelScene = params and params.levelScene
	local isWin = params and params.isWin
	-- 不是成功过关不弹
	if not levelID or not isWin then
		if logSwitchOpened() then self:log("xxx nah:", "not from win") end
		return false
	end
	-- 必须主线关
	if not UBFLevelSceneFunc:isMainLevel(levelScene) then
		if logSwitchOpened() then self:log("--- skip!", "not main level") end
		return false
    end
	-- 刚开新关一段时间内，打新关不弹
	if UBFAddFiveUpgradeBuffUtil:_forbidPopForTopLevelPlayer() then
		if logSwitchOpened() then self:log("xxx nah:", "forbid pop for top level player") end
		return false
	end

	-- 需要有领奖数据
	local currBuffData = UBFAddFiveUpgradeBuffUtil:getCustomLocalData(LocalBuffDataKey.kCurrTriggeredBuffData)
	if logSwitchOpened() then self:log("currBuffData:", tts(currBuffData)) end
	if not currBuffData then 
		if logSwitchOpened() then self:log("xxx nah:", "no currBuffData") end
		return false
	end
	-- 领奖有效性
	if not UBFAddFiveUpgradeBuffUtil:isEnabled2() then
		if logSwitchOpened() then self:log("xxx nah:", "not enabled for get reward") end
		return false
	end
	
	-- 长离线状态不补弹
	local bOffline = _G.amfBean("SyncPassLevelMgr"):isOfflinePassLevel()
	if logSwitchOpened() then self:log("isOfflinePassLevel", bOffline) end
	if bOffline then
		if logSwitchOpened() then self:log("xxx nah:", "isOfflinePassLevel") end
        return false
    end

	-- 有可领且没领的奖
	if UBFAddFiveUpgradeBuffUtil:_wantPopBuffRewardPanel(currBuffData) then	
		if logSwitchOpened() then self:log("=== can pop panel!") end
		return true
	end
	if logSwitchOpened() then self:log("xxx nah:", "data not matched") end
	return false
end

-- 当前是否想要弹领奖面板
function UBFAddFiveUpgradeBuffUtil:_wantPopBuffRewardPanel(currBuffData)
	if logSwitchOpened() then self:log("+++ check _wantPopBuffRewardPanel:") end
	if currBuffData then
		-- if currBuffData.result and (currBuffData.result == 1) and not currBuffData.rewardGotten and (currBuffData.passLevelType == AddFiveStepConfig.passLevelType.kPassLevel) then
		if currBuffData.result and (currBuffData.result == 1) and not currBuffData.rewardGotten then
			if logSwitchOpened() then self:log("=== Yup") end
			return true
		end
	end
	if logSwitchOpened() then self:log("=== Nah") end
	return false
end

-- 过关面板弹buff领奖面板
function UBFAddFiveUpgradeBuffUtil:popBuffRewardPanelOnPassLevel(closeCallback, popoutCallback, removeCallback)
	local currBuffData = UBFAddFiveUpgradeBuffUtil:getCustomLocalData(LocalBuffDataKey.kCurrTriggeredBuffData)
	if logSwitchOpened() then self:log(">>> popBuffRewardPanelOnPassLevel:", tts(currBuffData)) end
	if not currBuffData or not currBuffData.panelParams then 
		safeRunCall(closeCallback)
		return 
	end

	-- local selfActIDStr = tostring(UBFAddFiveUpgradeDataUtil:getActID())
	-- local sceneManager = UBFGameSceneManager:getInstance()
	-- local modMgr = sceneManager and sceneManager:callGameModule(UBFGameLogics.kGameMod, "getModMgrBySourceId", selfActIDStr)
	-- if modMgr then
	-- 	local modContextData = modMgr:getModEnvData()
	-- 	local outsideManagerData = modContextData and modContextData["outsideManagerPack"]
	-- 	local popRewardPanelFunc = outsideManagerData and outsideManagerData.popoutBuffRewardPanel

	-- 	if popRewardPanelFunc then
	-- 		if logSwitchOpened() then self:log("=== popoutBuffRewardPanel !!") end
	-- 		safeRunCall(popRewardPanelFunc({
	-- 			panelParam = currBuffData.panelParams,
	-- 			endCallback = closeCallback,
	-- 			popoutCallback = popoutCallback,
	-- 			removeCallback = removeCallback,
	-- 		}))
	-- 	end
	-- end

	local outerManager = _G.amfBean("AddFiveUpgradeManager")
	if not outerManager or not outerManager.popoutMainPanelUBF then 
		if logSwitchOpened() then self:log("xxx, no outerManager") end
		safeRunCall(closeCallback)
		return 
	end

	if logSwitchOpened() then self:log("=== popoutBuffRewardPanel !!") end
	local delegate = {
		showPanelType = 2, --AddFiveStepConfig.ShowPanelType.kWin,
		saveParam = table.clone(currBuffData.panelParams),
		popoutFunc = popoutCallback,
		removeFunc = removeCallback,
	}
	outerManager:popoutMainPanelUBF(delegate, closeCallback)
end

-----------------------------------------------------------------------------------------------
--										Add Five Step
-----------------------------------------------------------------------------------------------
function UBFAddFiveUpgradeBuffUtil:getAddFiveStepPanelNPCPopContent(levelID, playID)
	if logSwitchOpened() then self:log(">>> getAddFiveStepPanelNPCPopContent:", levelID, playID) end

	-- 活动有效性
	if not UBFAddFiveUpgradeBuffUtil:isEnabled() then 
		if logSwitchOpened() then self:log("xxx no dialog pop:", "act not enabled") end
		return 
	end

	local currBuffData = UBFAddFiveUpgradeBuffUtil:getCustomLocalData(LocalBuffDataKey.kCurrTriggeredBuffData)
	if logSwitchOpened() then self:log("currBuffData:", tts(currBuffData)) end
	if not levelID or not currBuffData then
		if logSwitchOpened() then self:log("xxx no dialog pop:", "no currBuffData") end
		return 
	end

	if levelID and playID and levelID == currBuffData.levelID and playID == currBuffData.playID then
		local rewardGroupType
		if currBuffData.panelParams then
			rewardGroupType = currBuffData.panelParams.rewardGroupType
		end
		if logSwitchOpened() then self:log("rewardGroupType:", rewardGroupType) end
		if rewardGroupType then
			local resultData = { buffType = rewardGroupType }
			if logSwitchOpened() then self:log("=== has dialog pop, resultData:", tts(resultData)) end
			return resultData
		end
	end
	if logSwitchOpened() then self:log("xxx no dialog pop") end
	return nil
end

-----------------------------------------------------------------------------------------------
--										Res Preload
-----------------------------------------------------------------------------------------------
function UBFAddFiveUpgradeBuffUtil:checkAddPreloadRes(plistList, spineList)
	local currBuffData = UBFAddFiveUpgradeBuffUtil:getCustomLocalData(LocalBuffDataKey.kCurrTriggeredBuffData)
	-- 有可能领取buff奖励时，再加载
	if currBuffData and not currBuffData.rewardGotten then
		if not currBuffData.result or (currBuffData.result == 1) then
			if logSwitchOpened() then self:log("=== add buff reward panel preload!") end
			table.insert(spineList, "amf/activity/addfiveupgrade/spine/mouse_1-3.skel")
			table.insert(spineList, "amf/activity/addfiveupgrade/spine/firework_cartoon.skel")
			table.insert(spineList, "amf/activity/addfiveupgrade/spine/star_1-2.skel")
		end
	end
end
