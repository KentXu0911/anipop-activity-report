-- TODO @shihao 待查levelId区分
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local Tween = require "amf.middleware.ui.util.Tween"
local NumberUtil = require "amf.middleware.ui.util.NumberUtil"
local PropRegister = require 'amf.feature.localactivity.addfivestepupgrade.props.PropRegister'
local AddFiveStepModel = require 'amf.feature.localactivity.addfivestepupgrade.model.AddFiveStepModel'

local Manager = class("AddFiveUpgradeManager")

local AddFiveStepConfig = require 'amf.feature.localactivity.addfivestepupgrade.config.AddFiveStepConfig'

-- require 'amf.feature.localactivity.addfivestepupgrade.AddFiveUpgradeManager_http'

-- 主线
Manager.ACT_ID = 5311
-- Manager.DCGameName = "long_tail"
-- Manager.DCFeature = "long_tail"
-- Manager.DCSource = "act_"..Manager.ACT_ID

local printChannel = 11
local selfLogOpened = false
local oldPrintx = printx
local function printx( ... ) 
	if EnvUtil:isDevelopMode() then 
		if selfLogOpened then
			oldPrintx(...)
			UWarning("长尾：",...)
		end
	end
end

function Manager:initialize()
    PropRegister:register()
    self:registerEvents()

    self.serverData = AddFiveStepModel:create("AddFiveUpgradeManager")

    self._isResReady = false

	-- self.canShowMainPanel = false 
	-- -- self.canShowAddFiveGift = false 
	-- -- self.bIsOriginGroup = false
	-- -- self.bIsEnergtGroup = false
	-- -- self.bUseNewEnergyReward = false

	-- if EnvUtil:isMiniGame() then
	-- 	local MaintenanceName = "minigame_plusstep"
	-- 	if MaintenanceManager:getInstance():isEnabledInGroup(MaintenanceName, "Buff") then
	-- 		self.canShowMainPanel = true 
	-- 	end

	-- 	-- if MaintenanceManager:getInstance():isEnabledInGroup(MaintenanceName, "Pack") then
	-- 	-- 	self.canShowAddFiveGift = true 
	-- 	-- end
	-- else
	-- 	self.canShowMainPanel = self:canOpenMainPanelForNewGroup()
	-- 	-- self.canShowAddFiveGift = self:canOpenGiftForNewGroup()
	-- end

	-- self.bIsEnergtGroup = true
	-- self.bUseNewEnergyReward = true

	-- self:initSaveStartPanelParam()
	-- -- self:initSaveGiftParam()
	-- self:initSaveStartPanelShowInfoParam()
	-- self:initSaveStartPanelInGameInfoParam()
	-- self:initSaveStartPanelProbability()
	-- self:initSaveStartPanelShowHistory()
	-- self:initSaveActiveInfoForPopRewardPanel()
	-- self:registerGiftEvents()

	self:onPreDownLoadRes()

	--[[
	-- 这是个前端用来查问题的点，不需要的话不打也可以
	UBFGlobal:getLogic(UBFUiLogicId.UI_VIEW_LOGIC_MANAGER):registerUiEventListener(UBFUiEventType.NODE_ENTER, function(eventData)
        local nodeId = eventData.nodeId
        if nodeId == UBFPlpNodeId.ROOT then
            -- 通知给关卡外的一些数据
            local levelId, levelScene, playId
			local sceneMgr = UBFGameSceneManager and UBFGameSceneManager:getInstance()
			if sceneMgr then
			    local levelInfo = sceneMgr:getLevelInfo()
			    levelId = levelInfo.levelId
			    levelScene = levelInfo.levelScene
			    playId = levelInfo.playId
			    self:passLevelPanelDC(levelId, playId)
			end
        end
    end)
	--]]
end

function Manager:onPreDownLoadRes()
    _G.amfBean("AssetsUtil"):preloadMiniLabels({"addfivestepupgrade"}, false):next(function()
        self._isResReady = true
    end, function()
    end)
end

function Manager:isResReady()
	return self._isResReady
end

function Manager:registerEvents()
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)
end

-- function Manager:registerGiftEvents()
-- end

--[[
function Manager:isEnabled()
	if selfLogOpened then printx(printChannel,"AddFiveUpgradeManager:isEnabled 1111111111") end
	local actData = UBFAddFiveUpgradeDataUtil:getValidActData()

	if selfLogOpened then printx(printChannel,"AddFiveUpgradeManager:isEnabled 22222222", tts(actData)) end
	if actData then 
		return true and self._isResReady
	end
	return false
end

function Manager:isEnabled2()
	if selfLogOpened then printx(printChannel,"AddFiveUpgradeManager:isEnabled2 1111111111") end
	local actData = UBFAddFiveUpgradeDataUtil:getValidActDataV2()

	if selfLogOpened then printx(printChannel,"AddFiveUpgradeManager:isEnabled2 22222222",tts(actData)) end
	if actData then 
		return true and self._isResReady
	end
	return false
end

function Manager:canOpenMainPanelForNewGroup()
	-- 测试废弃了
	-- local bCanOpenNewGroup = UBFAddFiveUpgradeDataUtil:_isActNewGroupEnable()

	-- if bCanOpenNewGroup then
	-- 	local MaintenanceName = "plus_five_test"
	-- 	local canOpenMainPanel = false
	-- 	if MaintenanceManager:getInstance():isEnabledInGroup( MaintenanceName , "G1") or 
	-- 		MaintenanceManager:getInstance():isEnabledInGroup( MaintenanceName , "G2") then
	-- 		canOpenMainPanel = true
	-- 	end
	-- 	return canOpenMainPanel
	-- else
		--等级没满足新开关走老的
		local MaintenanceName = "plusfive_double"
		local bInOnGroup = MaintenanceManager:getInstance():isEnabledInGroup( MaintenanceName , "ON" )
		return bInOnGroup
	-- end
end

function Manager:canOpenGiftForNewGroup()
	-- 测试废弃了
	-- local bCanOpenNewGroup = UBFAddFiveUpgradeDataUtil:_isActNewGroupEnable()

	-- if bCanOpenNewGroup then
	-- 	local MaintenanceName = "plus_five_test"
	-- 	local canOpenGift = false
	-- 	if MaintenanceManager:getInstance():isEnabledInGroup( MaintenanceName , "G1") or 
	-- 		MaintenanceManager:getInstance():isEnabledInGroup( MaintenanceName , "G3") then
	-- 		canOpenGift = true
	-- 	end
	-- 	return canOpenGift
	-- else
		--等级没满足新开关走老的
		local MaintenanceName = "plusfive_double"
		local bInOnGroup = MaintenanceManager:getInstance():isEnabledInGroup( MaintenanceName , "ON" )
		return bInOnGroup
	-- end
end
--]]

function Manager:getActInfo()
	return _G.amfBean("ActivityMgr"):getActInfo( Manager.ACT_ID )
end

--[[
function Manager:onActEnterMainScene(evt)
	if selfLogOpened then printx(printChannel,"AddFiveUpgradeManager:onActEnterMainScene") end
	--回到homeScene，清除进关前存的数据
	local data = evt:getData()
    if data.firstEnter then return end

	self:saveStartPanelParam({})
end
--]]

--[[
function Manager:startLevelDataChange(levelId)

	if selfLogOpened then printx(printChannel,"AddFiveUpgradeManager:startLevelDataChange 000000", levelId ) end

	if not self:isEnabled() then return end 

	if selfLogOpened then printx(printChannel,"AddFiveUpgradeManager:startLevelDataChange 11111", levelId ) end

	local saveShowInfo = self:getSaveStartPanelShowInfoParam()
	if not table.isEmpty(saveShowInfo) and saveShowInfo.levelId and saveShowInfo.levelId == levelId then
	    self:saveSaveStartPanelShowHistory( saveShowInfo.levelId, saveShowInfo.failNum )
	    self:clearSaveStartPanelShowInfoParam()

	    if selfLogOpened then printx(printChannel,"AddFiveUpgradeManager:startLevelDataChange 222222", tts(saveShowInfo) ) end
	end
	self:addStartPanelInGameInfoParam(levelId)
	
	local startParam = self:getSaveStartPanelParam()

	if selfLogOpened then printx(printChannel,"AddFiveUpgradeManager:startLevelDataChange 3333", tts(startParam) ) end

	--记录激活 成功等信息
	if not table.isEmpty(startParam) then
		self:saveSaveActiveInfoForPopRewardPanel(startParam)
	end

	self:saveStartPanelParam({})
end

function Manager:onActBeforeStartLevel(evt)
	if not self:isEnabled() then return end 
	local data = evt.data
    if not data then return end

    if selfLogOpened then printx(printChannel,"onActBeforeStartLevel", tts(data)) end

    self:startLevelDataChange(data.levelId)
end
--]]

----------开始面板弹出
--[[
function Manager:ignoreForTopLevelPlayer()
    local userState = _G.amfBean("UserStateManager"):getUserSegmentState()
    if userState == _G.UserStateConst.UserLevelState.MHZC then
        return false
    end

    local topLevelId = _G.getTopLevelId()
    if not _G.amfBean("LevelUnLockManager"):isTopNewMainLevel(topLevelId) then 
        return false
    end

    if not _G.amfBean("LevelUnLockManager"):isInNewLevelTime() then 
        return false
    end
    
    return true
end

function Manager:checkCurTimeCanPop()
	return not self:ignoreForTopLevelPlayer()
end

function Manager:checkCanPopOnStartPanel(levelId, playId)
	--是否可以弹在开始面板上
	--1,是否有actInfo
	--2，是不是在可展示时间
	--3，失败次数是否够了
	-- do 
	-- 	self:saveStartPanelParam( {levleId=levelId,failNum = 3,curPayTag=0} )
	-- 	return true 
	-- end 
	self.canShowMainPanel = self:canOpenMainPanelForNewGroup()
		
	if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 检测开始面板强弹开始") end

	if not self.canShowMainPanel then return end 

	if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 校验开关通过") end
	if not self:isEnabled() then return end 
	if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 校验活动时间") end
	if not self:checkCurTimeCanPop() then return end 

	if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 校验强弹时机通过，不在新关时间内") end

	local actData = UBFAddFiveUpgradeDataUtil:getValidActData()
	if not actData then return end 
	if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 校验数据通过，有后端发来的数据", actData.levelID, levelId ) end
	if actData.levelID ~= levelId then return end

	if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 校验levelId通过，当前打的关与记录失败的关卡一致") end
	local topLevelId = _G.getTopLevelId()
	if topLevelId ~= levelId then return end 

	if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 校验levelId通过，当前打的是top关") end
	local topLevelHasPassed = _G.amfBean("LevelAreaManager"):hasPassedLevelEx(topLevelId)
	if topLevelHasPassed then return end 

	if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 校验levelId通过，当前关卡是首次打关") end

	--1111111 判断曝光限制
	--22222222判断cd期
	--333333333先判断有没有保存好的当前关的触发信息
	--44444444如果没有再重新判断，并保存起来

	-- local curTime = TimeKit:timeInSec()
	local curTime = TimeKit:timeInSec()
	local oneHourSec = 60*60
	local oneDayTime = oneHourSec*24

	--曝光次数 所有玩家24h最多可触发2次地鼠buff
	local startPanelInGameInfoList = self:getSaveStartPanelInGameInfoParam() --{ {time=11},{time=11} }
	local in24HourActiveNum = 0
	for i,v in ipairs(startPanelInGameInfoList) do
		local activeTime = v.time
		if curTime < activeTime + oneDayTime then
			in24HourActiveNum = in24HourActiveNum + 1
		end
	end

	if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 曝光次数判断，当前24小时曝光次数", in24HourActiveNum) end

	if in24HourActiveNum >= 2 then
		return
	end

	if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 曝光次数判断，当前24小时曝光次数校验通过") end
	
	--判断是否在cd期
	local lastGetPromoteRewardTime = math.floor( tonumber(actData.lastGetPromoteRewardTime)/1000 )
	local promoteRewardCdHours = actData.promoteRewardCdHours

	local cdEndTime = lastGetPromoteRewardTime+promoteRewardCdHours*oneHourSec
	if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 校验cd时间", curTime, cdEndTime ) end
	if curTime < cdEndTime then return end

	if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 校验cd时间通过" ) end

	--判断是否使用存起来的数据
	local curPayTag = UserTagManager:getUserPaymentTag2ServerVersion()
	local saveShowInfo = self:getSaveStartPanelShowInfoParam()

	local bCanInitInfo = true
	if table.isEmpty(saveShowInfo) then
		bCanInitInfo = true
	else
		if saveShowInfo.levelId == levelId and saveShowInfo.failNum == actData.failTimes then
			--一致性判断
			bCanInitInfo = false
		end
	end

	if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 判断使用已保存的随机数据还是重新随机", tts(saveShowInfo) ) end

	if bCanInitInfo then
		if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 重新随机" ) end

		local failNum = actData.failTimes
		local canActivePercent = 0

		if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 权重判断信息 付费类型", curPayTag ) end
		if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 权重判断信息 失败次数", failNum ) end

		if curPayTag >= UsetPaymentTagServer.kNone and curPayTag <= UsetPaymentTagServer.kHigh_4 then


			if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 中低付费判断 开始"  ) end
			local canActive = true
			local saveStartPanelShowHistoryKey = self:getSaveStartPanelShowHistory()

			
			if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 输出历史触发信息", tts(saveStartPanelShowHistoryKey)  ) end
			local lastActiveFailNum = 0
			if not table.isEmpty(saveStartPanelShowHistoryKey) then
				--差距5关才能再次触发
				if saveStartPanelShowHistoryKey.levelId == levelId then
					lastActiveFailNum = saveStartPanelShowHistoryKey.failNum
				end
				if saveStartPanelShowHistoryKey.levelId == levelId and failNum - saveStartPanelShowHistoryKey.failNum <= 5 then
					if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 中低付费判断 找到了上一次触发的数据，并且上一次到现在间隔没有5次，不能触发", failNum, saveStartPanelShowHistoryKey.failNum  ) end
					canActive = false
				else
					if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 中低付费判断 记录的关卡与本关不一致，不判断间隔5次了") end
				end
			else
				if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 中低付费判断 未找到上一次触发的数据，不判断间隔5次了") end
			end

			if failNum >= 5 and canActive then
				--lastActiveFailNum +1 是因为 间隔5次计算n=0的时候，应该时当前失败减去 last+1. 要不然就直接从1开始算了。
				--比如上次触发10次  当前16次应该是20概率， 如果16-10-5 n=1了，概率会成为40，而不是20
				local subLastFailNum = lastActiveFailNum
				if lastActiveFailNum > 0 then
					subLastFailNum = lastActiveFailNum + 1
				end
				
				local checkFailNum = failNum - subLastFailNum - 5
				canActivePercent = 20 + checkFailNum*20
				if canActivePercent < 0 then
					canActivePercent = 0
				end
			end

		elseif curPayTag >= UsetPaymentTagServer.kHigh_5 and curPayTag <= UsetPaymentTagServer.kHigh_6 then
			-- local levelFlag ,isFirst = MetaManager:getInstance():getLevelDifficultFlag_ForStartPanel( levelId )
			local levelFlag = _G.amfBean("MetaManager"):getLevelDifficultFlag_ForStartPanel(levelId)
			if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 判断难关超难关 ", levelFlag) end

			local curLevelHadActive = false
			for i,v in ipairs(startPanelInGameInfoList) do
				local activeLevelId = v.levelId or 0
				if levelId == activeLevelId then
					curLevelHadActive = true
				end
			end

			if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 判断本关是否触发过了", curLevelHadActive) end

			local canActive = false
			if levelFlag == LevelDiffcultFlag.kDiffcult or levelFlag == LevelDiffcultFlag.kExceedinglyDifficult then
				canActive = true
			end

			if not curLevelHadActive and canActive and failNum >= 1 and failNum <= 2 then
				canActivePercent = 50
			end
		end

		if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 权重判断信息 计算的权重", canActivePercent ) end

		local bHasProbability, probability = self:getSaveProbabilityInfo( levelId, failNum )

		if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 权重判断信息 检测是否有保存的随机概率值", bHasProbability, probability ) end

		local randomNum = math.random( 1, 100 )
		if bHasProbability then
			randomNum = probability
			if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 权重判断信息 使用保存的随机概率值", randomNum ) end
		else
			self:addStartPanelProbability( levelId, failNum, randomNum )
			if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 权重判断信息 存储新的概率随机值", randomNum ) end
		end

		if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 权重判断信息 随机权重结果", randomNum ) end

		if randomNum <= canActivePercent then
			if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 随机在权重内可以触发" ) end
			-- if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 分组找奖励 bIsOriginGroup", self.bIsOriginGroup ) end
			-- if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 分组找奖励 bIsEnergtGroup", self.bIsEnergtGroup ) end

			local function getRewardsFromStr( rewardsStr )
				local rewardStrList = string.split( rewardsStr, ',')
				local rewards = {}
				for i,v in ipairs(rewardStrList) do
					local rewardStr = string.split( v, ':')
					local reward = { itemId = tonumber( rewardStr[1]), num = tonumber( rewardStr[2]) }
					table.insert( rewards, reward )
				end
				return rewards
			end

			local energyNum = _G.amfBean("UserEnergyManager"):getEnergy()
			local isInfiniteEnergy = _G.amfBean("UserEnergyManager"):getEnergyState() == UserEnergyState.INFINITE

			local rewards = {}
			local rewardGroupType = AddFiveStepConfig.RewardGroupType.kNone
			-- if self.bIsOriginGroup then
			-- 	rewardGroupType = AddFiveStepConfig.RewardGroupType.kGroupType1
			-- 	rewards = getRewardsFromStr( actData.promoteOriginReward )

			-- 	if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 选到了奖励类型1" ) end
			-- elseif self.bIsEnergtGroup then

				-- if self.bUseNewEnergyReward then		-- 分支测试废弃了，全开这个
					local function getRewardsAndGroupTypeByConfig( energyConfig, bFullEnergy )
						local rewardGroupType = AddFiveStepConfig.RewardGroupType.kNone
						local rewards = {}

						local index
						for i,v in ipairs(energyConfig) do
							if table.exist( v.tags, curPayTag ) then 
								index = i
								rewards = table.clone( getRewardsFromStr(v.rewards)  )
								break
							end
						end

						if bFullEnergy then
							if index ==1 then
								rewardGroupType = AddFiveStepConfig.RewardGroupType.kGroupType2
							elseif index ==2 then
								rewardGroupType = AddFiveStepConfig.RewardGroupType.kGroupType4
							end
						else
							if index ==1 then
								rewardGroupType = AddFiveStepConfig.RewardGroupType.kGroupType2
							elseif index ==2 then
								rewardGroupType = AddFiveStepConfig.RewardGroupType.kGroupType3
							elseif index == 3 then
								rewardGroupType = AddFiveStepConfig.RewardGroupType.kGroupType5
							end
						end

						return rewards, rewardGroupType
					end

					if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 进入新分组"  ) end

					if energyNum > 5 or isInfiniteEnergy then
						local fullEnergyRewardsByTagsConfig = actData.fullEnergyRewardsByTagsConfig or {}
						rewards, rewardGroupType = getRewardsAndGroupTypeByConfig(fullEnergyRewardsByTagsConfig, true)

						if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 选到了奖励类型",rewardGroupType  ) end
					else
						local notFullEnergyRewardsByTagsConfig = actData.notFullEnergyRewardsByTagsConfig or {}
						rewards, rewardGroupType = getRewardsAndGroupTypeByConfig(notFullEnergyRewardsByTagsConfig, false)

						if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 选到了奖励类型",rewardGroupType ) end
					end
				-- else
				-- 	if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 进入老分组"  ) end

				-- 	if energyNum > 5 or isInfiniteEnergy then
				-- 		rewardGroupType = AddFiveStepConfig.RewardGroupType.kGroupType2
				-- 		rewards = getRewardsFromStr(actData.promoteEnergyFullReward)

				-- 		if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 选到了奖励类型2" ) end
				-- 	else
				-- 		rewardGroupType = AddFiveStepConfig.RewardGroupType.kGroupType3
				-- 		rewards = getRewardsFromStr( actData.promoteEnergyNotFullReward )

				-- 		if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 选到了奖励类型3" ) end
				-- 	end
				-- end
			-- end

			if rewardGroupType ~= AddFiveStepConfig.RewardGroupType.kNone then
				local params = { levelId = levelId, failNum = failNum, curPayTag = curPayTag, rewards = rewards, rewardGroupType = rewardGroupType, 
					 energyNum = energyNum, isInfiniteEnergy = isInfiniteEnergy, playId = playId or '' }
				self:saveStartPanelParam( params )
				self:saveStartPanelShowInfoParam( params )

				if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 随机好了奖励", tts(params)) end
				if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 检测开始面板强弹结束") end
				return true
			end
		else
			if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 随机在权重外不可以触发" ) end
		end
	else
		if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 使用保存的随机结果" ) end

		local params = { levelId = saveShowInfo.levelId, failNum = saveShowInfo.failNum, 
			curPayTag = saveShowInfo.curPayTag, rewards = saveShowInfo.rewards,
			rewardGroupType = saveShowInfo.rewardGroupType,
			energyNum = saveShowInfo.energyNum,
			isInfiniteEnergy = saveShowInfo.isInfiniteEnergy,
			playId = playId or '' }
		self:saveStartPanelParam( params )

		if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 使用随即好的信息进行弹出", tts(saveShowInfo)) end
		if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 检测开始面板强弹结束") end
		return true
	end

	if selfLogOpened then printx(printChannel,"checkCanPopOnStartPanel 检测开始面板强弹结束") end
end
--]]

--[[
function Manager:initSaveStartPanelProbability()
	local saveStr = self:getFlagFromLocalByKeyStr( AddFiveStepConfig.saveStartPanelProbabilityKey, false )
	if saveStr == '' then
		self.startPanelProbability = {}
	else
		self.startPanelProbability = table.deserialize(saveStr)
	end
end

function Manager:getSaveStartPanelProbability()
	--获取开始面板计算完的数据 -- { levelId = levelId, failNum = failNum, curPayTag = curPayTag, rewards={} }
	return self.startPanelProbability
end

function Manager:saveStartPanelProbability(data)
	if selfLogOpened then printx(printChannel,"saveStartPanelProbability ",tts(data)) end
	self.startPanelProbability = table.clone(data)

	local saveStr = table.serialize(self.startPanelProbability)
	self:saveFlagToLocalByKeyStr( AddFiveStepConfig.saveStartPanelProbabilityKey, false, saveStr )
end

function Manager:getSaveProbabilityInfo( levelId, failNum )
	--获取记录的概率
	local probability = 0
	local bCurHaveProbability = false

	if selfLogOpened then printx(printChannel,"获取历史概率记录 ",tts(self.startPanelProbability)) end
	for i,v in ipairs(self.startPanelProbability) do
		if v.levelId == levelId and v.failNum == failNum then
			bCurHaveProbability = true
			probability = v.probability
			break
		end
	end

	return bCurHaveProbability, probability
end

function Manager:addStartPanelProbability( levelId, failNum, probability )
	--添加触发活动
	local saveInfos = table.clone( self:getSaveStartPanelProbability() )
	if selfLogOpened then printx(printChannel,"addStartPanelProbability 增加概率数据", tts(saveInfos), levelId, failNum, probability ) end

	local bCurHaveProbability = false
	if not table.isEmpty(saveInfos) then 
		for i,v in ipairs(saveInfos) do
			if v.levelId == levelId and v.failNum == failNum then
				bCurHaveProbability = true
				break
			end
		end
	end

	if selfLogOpened then printx(printChannel,"addStartPanelProbability 找出当前关卡是否有记录的概率信息", bCurHaveProbability ) end

	if bCurHaveProbability == false then
		local info = { levelId = levelId, failNum = failNum, probability = probability }
		table.insert( saveInfos, info )
	end

	--多的去掉,防止无限扩展
	local newSaveInfos = table.clone( saveInfos )
	if #self.startPanelInGameInfoParam > 20 then
		newSaveInfos = {}
		for i = #saveInfos-10, #saveInfos do
			table.insert( newSaveInfos, table.clone(saveInfos[i]) )
		end
	end
	self:saveStartPanelProbability( newSaveInfos )
end

function Manager:initSaveStartPanelInGameInfoParam()
	--记录带着buff进关的时间信息  用来判断24小时能出几次
	local saveStr = self:getFlagFromLocalByKeyStr( AddFiveStepConfig.saveStartPanelInGameInfoKey, false )
	if saveStr == '' then
		self.startPanelInGameInfoParam = {}
	else
		self.startPanelInGameInfoParam = table.deserialize(saveStr)
	end
end

function Manager:getSaveStartPanelInGameInfoParam()
	return self.startPanelInGameInfoParam
end

function Manager:addStartPanelInGameInfoParam( levelId )
	--添加触发活动
	local saveParam = self:getSaveStartPanelParam()

	if selfLogOpened then printx(printChannel,"addStartPanelInGameInfoParam 增加激活长尾次数 检测", tts(saveParam), levelId ) end
	if not table.isEmpty(saveParam) and saveParam.levelId == levelId then 

		if selfLogOpened then printx(printChannel,"addStartPanelInGameInfoParam 增加激活长尾次数", tts(self.startPanelInGameInfoParam)) end

		-- local info = { time = TimeKit:timeInSec(), levelId = levelId }
		local info = { time = TimeKit:timeInSec(), levelId = levelId }
		table.insert( self.startPanelInGameInfoParam, info )

		local saveInfo = table.clone(self.startPanelInGameInfoParam )
		if #self.startPanelInGameInfoParam > 5 then
			saveInfo = {}
			for i= #self.startPanelInGameInfoParam-3, #self.startPanelInGameInfoParam do
				table.insert( saveInfo, table.clone(self.startPanelInGameInfoParam[i]) )
			end
		end

		if selfLogOpened then printx(printChannel,"addStartPanelInGameInfoParam 增加激活长尾次数结果", tts(saveInfo)) end

		self:saveStartPanelInGameInfoParam( saveInfo )
	end
end

function Manager:saveStartPanelInGameInfoParam(data)
	if selfLogOpened then printx(printChannel,"saveStartPanelInGameInfoParam",tts(data)) end
	self.startPanelInGameInfoParam = table.clone(data)

	local saveStr = table.serialize(self.startPanelInGameInfoParam)
	self:saveFlagToLocalByKeyStr( AddFiveStepConfig.saveStartPanelInGameInfoKey, false, saveStr )
end

function Manager:initSaveStartPanelShowInfoParam()
	local saveStr = self:getFlagFromLocalByKeyStr( AddFiveStepConfig.saveStartPanelShowInfoKey, false )
	if saveStr == '' then
		self.startPanelShowInfoParam = {}
	else
		self.startPanelShowInfoParam = table.deserialize(saveStr)
	end
end

function Manager:getSaveStartPanelShowInfoParam()
	--获取开始面板计算完的数据 -- { levelId = levelId, failNum = failNum, curPayTag = curPayTag, rewards={} }
	return self.startPanelShowInfoParam
end

function Manager:saveStartPanelShowInfoParam(data)
	if selfLogOpened then printx(printChannel,"saveStartPanelShowInfoParam ",tts(data)) end
	self.startPanelShowInfoParam = table.clone(data)

	local saveStr = table.serialize(self.startPanelShowInfoParam)
	self:saveFlagToLocalByKeyStr( AddFiveStepConfig.saveStartPanelShowInfoKey, false, saveStr )
end

function Manager:clearSaveStartPanelShowInfoParam()
	self.startPanelShowInfoParam = {}
	local saveStr = table.serialize(self.startPanelShowInfoParam)
	self:saveFlagToLocalByKeyStr( AddFiveStepConfig.saveStartPanelShowInfoKey, false, saveStr )
end

function Manager:initSaveStartPanelParam()
	local saveStr = self:getFlagFromLocalByKeyStr( AddFiveStepConfig.saveStartPanelParamKey, false )
	if saveStr == '' then  
		self.startPanelParam = {}
	else
		self.startPanelParam = table.deserialize(saveStr)
	end
	
end

function Manager:saveStartPanelParam(data)
	if selfLogOpened then printx(printChannel,"saveStartPanelParam ",tts(data)) end
	self.startPanelParam = table.clone(data)

	local saveStr = table.serialize(self.startPanelParam)
	self:saveFlagToLocalByKeyStr( AddFiveStepConfig.saveStartPanelParamKey, false, saveStr )
end

function Manager:getSaveStartPanelParam()
	if selfLogOpened then printx(printChannel,"getSaveStartPanelParam ",tts(self.startPanelParam)) end
	return self.startPanelParam
end
--]]

--[[
-- 新礼包系统用不到这个了
function Manager:initSaveGiftParam()
	local saveStr = self:getFlagFromLocalByKeyStr( AddFiveStepConfig.saveGiftParamKey, false )
	if saveStr == '' then  
		self.giftParam = {}
	else
		self.giftParam = table.deserialize(saveStr)
	end
end

function Manager:saveGiftParam(data)
	if selfLogOpened then printx(printChannel,"saveGiftParam ",tts(data)) end
	self.giftParam = data

	local saveStr = table.serialize(self.giftParam)
	self:saveFlagToLocalByKeyStr( AddFiveStepConfig.saveGiftParamKey, false, saveStr )
end

function Manager:getSaveGiftParam()
	if selfLogOpened then printx(printChannel,"getSaveGiftParam ",tts(self.giftParam)) end
	return self.giftParam
end
--]]

--[[
function Manager:initSaveStartPanelShowHistory()
	--保存历史触发信息
	local saveStr = self:getFlagFromLocalByKeyStr( AddFiveStepConfig.saveStartPanelShowHistoryKey, false )
	if saveStr == '' then
		self.startPanelShowHistory = {}
	else
		self.startPanelShowHistory = table.deserialize(saveStr)
	end
end

function Manager:getSaveStartPanelShowHistory()
	return self.startPanelShowHistory
end

function Manager:saveSaveStartPanelShowHistory(levelId, failNum)
	if selfLogOpened then printx(printChannel,"addSaveStartPanelShowHistory 保存历史触发数据", levelId, failNum ) end
	-- self.startPanelShowHistory = { time = TimeKit:timeInSec(), levelId = levelId, failNum = failNum }
	self.startPanelShowHistory = { time = TimeKit:timeInSec(), levelId = levelId, failNum = failNum }

	local saveStr = table.serialize(self.startPanelShowHistory)
	self:saveFlagToLocalByKeyStr( AddFiveStepConfig.saveStartPanelShowHistoryKey, false, saveStr )
end

-------------
function Manager:initSaveActiveInfoForPopRewardPanel()
	--保存历史触发信息
	local saveStr = self:getFlagFromLocalByKeyStr( AddFiveStepConfig.saveActiveInfoForPopRewardPanel, false )

	if selfLogOpened then printx(printChannel,"initSaveActiveInfoForPopRewardPanel 读取任务信息", saveStr ) end

	if saveStr == '' then
		self.saveActiveInfoForPopRewardPanelInfo = {}
	else
		self.saveActiveInfoForPopRewardPanelInfo = table.deserialize(saveStr)
	end

	if selfLogOpened then printx(printChannel,"initSaveActiveInfoForPopRewardPanel 读取任务信息结果", tts(self.saveActiveInfoForPopRewardPanelInfo) ) end
end

function Manager:getSaveActiveInfoForPopRewardPanel()
	return self.saveActiveInfoForPopRewardPanelInfo
end

function Manager:saveSaveActiveInfoForPopRewardPanel( info )
	if selfLogOpened then printx(printChannel,"saveSaveActiveInfoForPopRewardPanel 激活的任务信息保存", tts(info) ) end
	self.saveActiveInfoForPopRewardPanelInfo = table.clone(info)

	--添加完成 领奖信息
	self.saveActiveInfoForPopRewardPanelInfo.missionIsComplete = false --是否完成，成功失败都应该设置完成
	self.saveActiveInfoForPopRewardPanelInfo.passLevelType = AddFiveStepConfig.passLevelType.kNone --成功失败标签
	self.saveActiveInfoForPopRewardPanelInfo.missionIsGetReward = false --是否领奖

	local saveStr = table.serialize(self.saveActiveInfoForPopRewardPanelInfo)

	if selfLogOpened then printx(printChannel,"saveSaveActiveInfoForPopRewardPanel 激活的任务信息保存结果", saveStr ) end

	self:saveFlagToLocalByKeyStr( AddFiveStepConfig.saveActiveInfoForPopRewardPanel, false, saveStr )
end
--]]

--[[
function Manager:setSaveActiveInfoForPopRewardPanelPassLevel()

	if selfLogOpened then printx(printChannel,"setSaveActiveInfoForPopRewardPanelPassLevel 过关清空存的任务信息") end

	if table.isEmpty(self.saveActiveInfoForPopRewardPanelInfo) then return end

	self.saveActiveInfoForPopRewardPanelInfo.missionIsComplete = true
	self.saveActiveInfoForPopRewardPanelInfo.passLevelType = AddFiveStepConfig.passLevelType.kPassLevel

	local saveStr = table.serialize(self.saveActiveInfoForPopRewardPanelInfo)
	self:saveFlagToLocalByKeyStr( AddFiveStepConfig.saveActiveInfoForPopRewardPanel, false, saveStr )
end

function Manager:setSaveActiveInfoForPopRewardPanelFailLevel()

	if table.isEmpty(self.saveActiveInfoForPopRewardPanelInfo) then return end

	self.saveActiveInfoForPopRewardPanelInfo.missionIsComplete = true
	self.saveActiveInfoForPopRewardPanelInfo.passLevelType = AddFiveStepConfig.passLevelType.kFailLevel
	
	local saveStr = table.serialize(self.saveActiveInfoForPopRewardPanelInfo)
	self:saveFlagToLocalByKeyStr( AddFiveStepConfig.saveActiveInfoForPopRewardPanel, false, saveStr )
end

function Manager:setSaveActiveInfoForPopRewardPanelGetReward()

	if table.isEmpty(self.saveActiveInfoForPopRewardPanelInfo) then return end

	self.saveActiveInfoForPopRewardPanelInfo.missionIsGetReward = true

	local saveStr = table.serialize(self.saveActiveInfoForPopRewardPanelInfo)
	self:saveFlagToLocalByKeyStr( AddFiveStepConfig.saveActiveInfoForPopRewardPanel, false, saveStr )
end
--]]
---------

--[[
--闪退恢复失败
function Manager:onActCrashResumeFailed(data)
	if selfLogOpened then printx(printChannel,"onActCrashResumeFailed",tts(data)) end

	if not data then return false end
    if not self:isEnabled() then return false end

    --中断连胜
    self:saveStartPanelParam( {} )

	return true
end
--]]

--[[
function Manager:getInGamePlayId()
	local playId = ''
	local ubfPlayId = UBFGamePlayBridgeInvoker and UBFGamePlayBridgeInvoker:getPlayId(true)
	if ubfPlayId then
		playId = ubfPlayId
	end
	if selfLogOpened then printx(printChannel,"getInGamePlayId",playId) end
	return playId		
end
--]]

function Manager:popoutMainPanel( delegate, closeCallback )
	local panelVM = require_debug "amf.feature.localactivity.addfivestepupgrade.view.vm.MainPanelVM"
	local panel = panelVM:create(delegate)
	panel:setCloseCallback(closeCallback)
	panel:popout()
end

function Manager:popoutMainPanelUBF( delegate, closeCallback )
	local panelVM = require_debug "amf.feature.localactivity.addfivestepupgrade.view.vm.MainPanelVM"
	local panel = panelVM:create(delegate)
	panel:setCloseCallback(closeCallback)
	panel:setUBFPopDelegate( { popout = delegate.popoutFunc, removePopout = delegate.removeFunc } )
    panel:popout()
end

-- 提供关卡内需要的方法数据包
function Manager:getInLevelParams()
	local param = {}

	-- 弹出触发面板
	param.popoutTriggerBuffPanel = function(data)
		local delegate = {
			showPanelType = AddFiveStepConfig.ShowPanelType.kStart,
			saveParam = table.clone(data.panelParam),
		}
		self:popoutMainPanel(delegate, data.endCallback)
	end

	-- 弹出领奖面板
	-- 场景3自己调用，不走这里
	param.popoutBuffRewardPanel = function(data)
		-- local delegate = {
		-- 	showPanelType = AddFiveStepConfig.ShowPanelType.kWin,
		-- 	saveParam = table.clone(data.panelParam),
		-- }
		-- self:popoutMainPanel(delegate, data.endCallback)

		local delegate = {
			showPanelType = AddFiveStepConfig.ShowPanelType.kWin,
			saveParam = table.clone(data.panelParam),
			popoutFunc = data.popoutCallback,
			removeFunc = data.removeCallback,
		}
		self:popoutMainPanelUBF(delegate, data.endCallback)
	end

	-- 弹出失败面板
	param.popoutBuffFailPanel = function(data)
		local delegate = {
			showPanelType = AddFiveStepConfig.ShowPanelType.kEnd,
			saveParam = table.clone(data.panelParam),
		}
		self:popoutMainPanel(delegate, data.endCallback)
	end

	return param
end

--[[
----------开始面板弹出
function Manager:getStartParams()
	local param = {}
	param.startPanelPopoutRewards = function(data) 
		self:startPanelPopoutRewards(data)
	end
	return param
end

function Manager:startPanelPopoutRewards(data)
	if selfLogOpened then printx(printChannel, "************ startPanelPopoutRewards 1111111",tts(data)) end

	--开始面板，playId levelId这些都是新的。
	--如果是重玩面板 playId不是关卡内的也是新生成的（要用打关的的话使用oldPlayId）

    local levelId = data.levelId
    local levelScene = data.levelScene
	local startLevelType = data.startLevelType	-- panelLogic.startLevelType
	local playId = data.playId					-- panelLogic.PreContext:getPlayId()
	local byFailPanel = data.byFailPanel			-- panelLogic:curLevelSourceIsFailLevel()
	local endCall = data.onEnd

	local preLevelId = data.levelId
	local preLevelScene = data.levelScene
	local preStartLevelType = data.startLevelType
	local prePlayId = data.gameBoardPlayId or playId

	local function onEnd()
		safeRunCall(endCall)
	end

	if not levelId then 
		onEnd()
		return 
	end

    if not UBFLevelSceneFunc:isMainLevel(levelScene) then
		onEnd()
        return
    end

	if selfLogOpened then printx(printChannel, "************ startPanelPopoutRewards 22222222") end

	local function popStartPanel(done)
		if selfLogOpened then printx(printChannel, "************ startPanelPopoutRewards 5555555555555") end

		if startLevelType == UBFStartLevelType.kAskForHelp then
			safeRunCall(done)
			return
		end

		if selfLogOpened then printx(printChannel, "************ startPanelPopoutRewards 66666666666666666") end
		if not self:checkCanPopOnStartPanel(levelId, playId) then 
			self:saveStartPanelParam( {} )
			safeRunCall(done)
			return 
		end

		if selfLogOpened then printx(printChannel, "************ startPanelPopoutRewards 777777777777777") end
		local saveParam = self:getSaveStartPanelParam()
		local delegate = {
			showPanelType = AddFiveStepConfig.ShowPanelType.kStart,
			saveParam = saveParam,
		}
		self:popoutMainPanel( delegate, done )

		--弹出开始的时候，就清空未结算的信息
		self:saveSaveActiveInfoForPopRewardPanel({})
	end

	if byFailPanel then  
		if selfLogOpened then  printx(printChannel, "************ startPanelPopoutRewards 333333333333") end

		--失败面板弹出
		if not self:isEnabled2() then 
			safeRunCall(onEnd)
			return 
		end

		local saveParam = self:getSaveActiveInfoForPopRewardPanel()
		if selfLogOpened then printx(printChannel, 'onActStartPanelPopoutRewards saveParam', levelId, preLevelId, playId, prePlayId, tts(saveParam)) end
		if table.isEmpty(saveParam) then 
			--如果没有记录，尝试弹出开始面板
			popStartPanel(onEnd)
		else
			if selfLogOpened then printx(printChannel, "preLevelId == saveParam.levelId", preLevelId == saveParam.levelId) end
			if selfLogOpened then printx(printChannel, "prePlayId == saveParam.playId", prePlayId == saveParam.playId) end

			if preLevelId == saveParam.levelId and prePlayId == saveParam.playId and saveParam.missionIsComplete and saveParam.passLevelType == AddFiveStepConfig.passLevelType.kFailLevel then 
				--弹出失败面板
				local delegate = {
					showPanelType = AddFiveStepConfig.ShowPanelType.kEnd,
					saveParam = table.clone(saveParam),
				}
				self:popoutMainPanel( delegate, onEnd )

				--失败清任务
				self:saveSaveActiveInfoForPopRewardPanel({})
			else
				popStartPanel(onEnd)
			end
		end
	else
		--开始面板弹出
		--代打不能算
		if selfLogOpened then  printx(printChannel, "************ startPanelPopoutRewards 4444444444") end
		popStartPanel(onEnd)
	end
end
--]]

----------过关面板弹出
--[[
function Manager:passLevelPanelDC(levelId,playId)
	if not self:isEnabled2() then 
    	return 
    end 

	local saveParam = self:getSaveActiveInfoForPopRewardPanel()

	if table.isEmpty(saveParam) then return end
	if not saveParam.levelId then return end

	local t5 = false
	local t6 = false
	if saveParam.missionIsGetReward then
		t5 = true
	end
	if saveParam.missionIsComplete then
		t6 = true
	end

	if UBFAddFiveStepUpgradeUtil then
		UBFAddFiveStepUpgradeUtil:sendDC('long_tail','passPanelShow', {
			t1 = saveParam.levelId, 
			t2 = saveParam.playId, 
			t3 = levelId,
			t4 = playId,
			t5 = t5,
			t6 = t6,
		})
	end
end
--]]

--[[
function Manager:onActBeforePlayLevelEnd(evt)
	-- printx(printChannel, "onActBeforePlayLevelEnd",tts(evt))
	local data = evt.data
	if data.isWin then
		self:onPassLevel(data)
	else
		self:onFailLevel(data)
	end
end

function Manager:onFailLevel(data)

	if selfLogOpened then printx(printChannel,"onActFailLevel 111111111") end

	if not data then return end
    if not data.levelId then return end
    if not data.playId then return end
    
    if not self:isEnabled() then return false end

    --取出当前存的信息，判断levelId playId 是否一致， 如果一致执行成功失败判断，更改数据
    local saveActiveInfoForPopRewardPanelInfo = self:getSaveActiveInfoForPopRewardPanel()

    if selfLogOpened then printx(printChannel,"onActFailLevel 2222222",tts(saveActiveInfoForPopRewardPanelInfo)) end
    if saveActiveInfoForPopRewardPanelInfo.levelId == data.levelId and saveActiveInfoForPopRewardPanelInfo.playId == data.playId then
		self:setSaveActiveInfoForPopRewardPanelFailLevel()
    end

    self:saveStartPanelParam( {} )
end

function Manager:onPassLevel(data)
end

function Manager:passLevelSetData(data)

	if selfLogOpened then printx(printChannel,"onActPassLevel 111111111") end
    if not data then return end
    if not data.levelId then return end
    if not data.playId then return end
    
    if not self:isEnabled() then return false end

    --取出当前存的信息，判断levelId playId 是否一致， 如果一致执行成功失败判断，更改数据
    local saveActiveInfoForPopRewardPanelInfo = self:getSaveActiveInfoForPopRewardPanel()

    if selfLogOpened then printx(printChannel,"onActPassLevel 2222222",tts(saveActiveInfoForPopRewardPanelInfo)) end
    if saveActiveInfoForPopRewardPanelInfo.levelId == data.levelId and saveActiveInfoForPopRewardPanelInfo.playId == data.playId then
		self:setSaveActiveInfoForPopRewardPanelPassLevel()
    end

    self:saveStartPanelParam( {} )
end
--]]

------------------------------- 加五步面板 -----------------------------
--[[
-- 加五步面板检测本关是否有地鼠奖励NPC对话泡
-- todo:change
function Manager:onActUBFAddFivePanelCheckNPCDialog(param)
	local data = param and param.data
	if not data then return end
	local levelID
	if data.panelContextData then
		levelID = data.panelContextData.levelID
	end

	if selfLogOpened then printx(printChannel, 'onActUBFAddFivePanelCheckNPCDialog data', tts(data)) end

	if not levelID then return end

	local popContent = self:_getAddFiveStepPanelNPCPopContent(levelID)
	if popContent then
		data.hasAddFiveUpgradeNPCPop = true
		data.buffType = popContent.buffType
	end
end

function Manager:_getAddFiveStepPanelNPCPopContent(levelID)

	if selfLogOpened then printx(printChannel,"_getAddFiveStepPanelNPCPopContent 获取Npc说话内容 开始", levelID) end

	if self:isEnabled() then

		local saveParam = self:getSaveActiveInfoForPopRewardPanel()

		local playId = self:getInGamePlayId()
		-- if selfLogOpened then printx(printChannel, "_getAddFiveStepPanelNPCPopContent playId", playId) end

		if selfLogOpened then printx(printChannel,"_getAddFiveStepPanelNPCPopContent 获取Npc说话内容 条件检测", playId, tts(saveParam)) end

		if saveParam and saveParam.levelId and saveParam.playId and saveParam.levelId == levelID and saveParam.playId == playId then 
			if saveParam.rewardGroupType then
				local buffType = saveParam.rewardGroupType

				if selfLogOpened then printx(printChannel,"_getAddFiveStepPanelNPCPopContent 获取Npc说话内容成功", levelID, buffType) end
				return {buffType = buffType}
			end 
		end
	end 

	if selfLogOpened then printx(printChannel,"_getAddFiveStepPanelNPCPopContent 获取Npc说话内容失败", levelID) end
	return nil
end
--]]

------------------礼包 
-- 礼包数据
--[[
function Manager:getPromotionInfo( levelId )

	self.canShowAddFiveGift = self:canOpenGiftForNewGroup()
	
	if selfLogOpened then printx(printChannel,"getPromotionInfo 礼包弹出检测开始") end
	if not self.canShowAddFiveGift then return end 

	if not self:isEnabled() then return end

	if selfLogOpened then printx(printChannel,"getPromotionInfo 数据Enable检测通过") end

	local topLevelId = _G.getTopLevelId()
	local topLevelHasPassed = _G.amfBean("LevelAreaManager"):hasPassedLevelEx(levelId)

	--top关已过关不出
	if selfLogOpened then printx(printChannel,"getPromotionInfo 关卡判断",levelId, topLevelId, topLevelHasPassed) end
	if topLevelHasPassed then return end 

	if selfLogOpened then printx(printChannel,"getPromotionInfo 关卡判断通过") end

	local actData = UBFAddFiveUpgradeDataUtil:getValidActData()

	if not actData then return end 
	--top关跟记录的关不一致不出
	if actData.levelID ~= topLevelId then return end
	if topLevelId ~= levelId then return end

	if selfLogOpened then printx(printChannel,"getPromotionInfo topLevel校验通过" ) end

	local saveParam = self:getSaveGiftParam()

	local playId = self:getInGamePlayId()
	if playId == '' then return end 

	if selfLogOpened then printx(printChannel,"getPromotionInfo 记录的礼包数据校验，是否已购买判断",playId, tts(saveParam) ) end
    if saveParam  then 
    	if saveParam.playId == playId then
    		if saveParam.bHadBuyGift then
    			if selfLogOpened then printx(printChannel,"getPromotionInfo 已经买过了 不弹了"  ) end
    			if selfLogOpened then printx(printChannel,"getPromotionInfo 礼包弹出检测结束") end
    			return
    		else
    			if selfLogOpened then printx(printChannel,"getPromotionInfo 使用已保存的上次拿到的数据 继续展示"  ) end
    			if selfLogOpened then printx(printChannel,"getPromotionInfo 礼包弹出检测结束") end
    			return { goodsId = saveParam.goodsId, endTime = actData.actEndTs, playId = playId }
    		end
    	end
    end 

	local failNum = actData.failTimes
	-- todo:check
	local curPayTag = UserTagManager:getUserPaymentTag2ServerVersion()
	local last60DayPayAmount = UserTagManager:getLast60DayPayAmount()
	

	-- local curTime = TimeKit:timeInSec()
	local curTime = TimeKit:timeInSec()
	local lastBuyBreakIceTime = math.floor( tonumber(actData.lastBuyBreakIceTime)/1000 )
	local breakIceCdHours = actData.breakIceCdHours
	local oneHourSec = 60*60

	--判断是否在cd期
	local cdEndTime = lastBuyBreakIceTime + breakIceCdHours*oneHourSec
	if selfLogOpened then printx(printChannel,"getPromotionInfo 开始校验是否在cd期", curTime, cdEndTime  ) end
	if curTime < cdEndTime then return end

	if selfLogOpened then printx(printChannel,"getPromotionInfo cd期判断通过，开始找出要展示的goods", last60DayPayAmount, tts(actData.breakIceGiftMetaList) ) end
	--根据配置找出要买的goods
	for i,v in ipairs(actData.breakIceGiftMetaList) do
		local pay60Range = v.pay60Range
		local rangeList = string.split(pay60Range,'~')
		local startPayTag = tonumber(rangeList[1])
		local endPayTag = tonumber(rangeList[2])

		if selfLogOpened then printx(printChannel,"getPromotionInfo 需要的付费 start end",startPayTag, endPayTag) end

		if last60DayPayAmount >= startPayTag and last60DayPayAmount < endPayTag then  
			local goodsId = v.goodsId
			local needLoseNum = v.needFailTimes
			-- local num = UserManager:getInstance():getDailyBoughtGoodsNumById(goodsId)
			local num = _G.amfBean("DailyDataManager"):getDailyBoughtGoodsNumById(goodsId)

			if selfLogOpened then printx(printChannel,"getPromotionInfo 失败次数 每日购买是否满足",failNum, needLoseNum, num) end

			if num == 0 and failNum >= needLoseNum then 
	    		if selfLogOpened then printx(printChannel,"getPromotionInfo 根据参数找出结果goodsId",goodsId,num,failNum,needLoseNum, i ) end
	    		if selfLogOpened then printx(printChannel,"getPromotionInfo 礼包弹出检测结束") end

				local params = { bHadBuyGift = false, playId = playId, goodsId = goodsId }
				self:saveGiftParam( params )

				return { goodsId = goodsId, endTime = actData.actEndTs, playId = playId }
			end
		end
	end
end
--]]

-- 加五步礼包
-- todo:change
-- function Manager:onActAdd5StepPeripheryNeed(data)
--     local function isValid(  )
--         return data.type and data.type == "package" and data.packageModuleList and #data.packageModuleList > 0
--     end

--     if isValid() and self:isEnabled() then
--         local AddFiveUpgradePackage = require 'amf.feature.localactivity.addfivestepupgrade.gift.AddFiveUpgradePackage'
--         table.insert(data.packageModuleList, 1, AddFiveUpgradePackage.new())
--     end
-- end

--打点
--[[
-- todo:change
function Manager.sendDC(category, subCategory, ...)
    Manager.sendDCWithGameName(Manager.DCGameName, category, subCategory, ...)
end

function Manager.sendDCWithGameName(gameName, category, subCategory, ...)
    local params = {
        game_type = "stage",
        game_name = gameName,
        category = category,
        sub_category = subCategory,
    }

    for i, v in pairs{...} do
        if v then
            if i == 1 and type(v) == 'table' then
                for k, v2 in pairs(v) do
                    params[k] = v2
                end
                break
            else
                params['t'..tostring(i)] = v
            end
        end
    end

    if EnvUtil:isDevelopMode() then 
	    if selfLogOpened then printx(printChannel,"sendDCWithGameName params",table.tostring(params)) end
	end
    DcUtil:UserTrack(params)
end
--]]

-- -- 本地缓存
-- function Manager:saveFlagToLocalByKeyStr(key, needTime, str)
--     if not key then return end
--     if str == nil then str = "" end
--     local keyStr = 'CommonMgrBaseV2_Int_'..Manager.ACT_ID..'_'.. key

--     if needTime then
-- 		local curTime = TimeKit:timeInSec()
-- 		local dayStartTime = TimeKit:getDayStartTimeByTS(curTime)
--         keyStr = keyStr .. ':' .. dayStartTime
--     end
--     CCUserDefault:sharedUserDefault():setStringForKey(keyStr, str)
-- 	if selfLogOpened then printx(printChannel, "AddFiveUpgradeManager: CCUserDefault, setStringForKey", keyStr, str) end
-- end

-- function Manager:getFlagFromLocalByKeyStr(key, needTime)
--     local keyStr = 'CommonMgrBaseV2_Int_'..Manager.ACT_ID..'_'.. key

--     if needTime then
-- 		local curTime = TimeKit:timeInSec()
-- 		local dayStartTime = TimeKit:getDayStartTimeByTS(curTime)
--         keyStr = keyStr .. ':' .. dayStartTime
--     end
-- 	local flagResult = CCUserDefault:sharedUserDefault():getStringForKey(keyStr, '')
-- 	if selfLogOpened then printx(printChannel, "AddFiveUpgradeManager: CCUserDefault, getStringForKey", keyStr, flagResult) end
--     return flagResult
-- end

--------------------
function Manager:getData()
    return self.serverData
end

--[[
-- 本地缓存
function Manager:setLocalValueByKey(key, needTime, value)
    if not key then return end
    if bSkip == nil then bSkip = true end

    local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())

    local saveValue = {
    	time = nowTime,
    	value = value,
    	actBeginTime = actBeginTime,
    }
    local saveStr = table.serialize(saveValue)

    self:getData():setValue(key, saveStr, true)
end

-- tocheck: --[[]]
function Manager:getLocalValueByKey(key, needTime)
    if not key then return end
    local saveJsonStr = self:getData():getValue(key)
    if saveJsonStr == nil then return end
    if type(saveJsonStr) ~= "string" then return end

    local saveTable = table.deserialize(saveJsonStr)

    local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())

    local bTimeIsOk = true
    if needTime then
    	if saveTable.time ~= nowTime then
    		bTimeIsOk = false
    	end
    end

    local versionIsOk = true

    if bTimeIsOk and versionIsOk then
    	return saveTable.value
    end
end

-- 本地缓存str
function Manager:saveFlagToLocalByKeyStr(key, needTime, value)
    if value == nil then value = "" end
    self:setLocalValueByKey( key, needTime, value )
end

function Manager:getFlagFromLocalByKeyStr(key, needTime)
    local defaultValue = ""

    local result = self:getLocalValueByKey(key, needTime)
    if result == nil then 
        return defaultValue
    else
        return result
    end
end
--]]
--------------------------------

-- todo:change, call:function EnterFromLevel1stHandler:checkAddFiveStepPopup()
---场景3强弹
function Manager:checkAddFiveStepPopup(params)
	if UBFAddFiveUpgradeBuffUtil:canPopBuffRewardPanelOnScene3(params) then
		local LocalBuffDataKey = UBFAddFiveUpgradeBuffUtil:getLocalBuffDataKey()
		local currBuffData = UBFAddFiveUpgradeBuffUtil:getCustomLocalData(LocalBuffDataKey.kCurrTriggeredBuffData)
		if currBuffData and currBuffData.panelParams then
			self:doAddFiveStepPopup(currBuffData.panelParams)
		end
	end
end
--[[
function Manager:checkAddFiveStepPopup()
	if selfLogOpened then printx(printChannel,"checkAddFiveStepPopup 1111111111") end
	if not self:isEnabled() then return end 

	local bOffline = _G.amfBean("SyncPassLevelMgr"):isOfflinePassLevel()
	if selfLogOpened then printx(printChannel,"checkAddFiveStepPopup bOffline", bOffline ) end
	if bOffline then
        return
    end

    if not self:checkCurTimeCanPop() then return end

	local saveParam = self:getSaveActiveInfoForPopRewardPanel()

	if selfLogOpened then printx(printChannel,"checkAddFiveStepPopup 33333333", tts(saveParam)) end
	if table.isEmpty(saveParam) then 
		--如果没有记录，尝试弹出开始面板
		return
	else
		if saveParam.missionIsComplete and saveParam.passLevelType == AddFiveStepConfig.passLevelType.kPassLevel and not saveParam.missionIsGetReward then
			self:doAddFiveStepPopup(saveParam)
		end
	end
end
--]]

function Manager:doAddFiveStepPopup(saveParam)
	local function onHandleOver()
		if selfLogOpened then UWarning(12,"doAddFiveStepPopup  onHandleOver") end
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.ADD_FIVE_STEP)
	end

	local function creator()
		local delegate = {
			showPanelType = AddFiveStepConfig.ShowPanelType.kWin,
			saveParam = saveParam,
		}
		self:popoutMainPanel( delegate, onHandleOver )
	end

	_G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.ADD_FIVE_STEP, creator)
end

------------------------------------------------ AddFiveUpgradeManager_http
----------领奖
function Manager:addRewards( rewards, feature, source )
    local buffList = {}
    local normalList = {}
    for _, v in pairs(rewards) do
        if v.itemId == AddFiveStepConfig.add150SoreBuffID then
            table.insert(buffList, table.clone(v))
        else
            table.insert(normalList, table.clone(v))
        end
    end

	_G.GainPropData:create()
		:setFeature(feature)
		:setSource(source)
		:setProps(normalList)
		:execute()
end

--领取奖励
function Manager:getReward( failNum, payTag, rewardList, successCallback, failCallback, cancelCallback, noLoading)
	local function onSuccess(evt)
        local data = evt.data or {}
        local bSucess = data.success

        if bSucess then
            local rewards = table.clone(rewardList)
            self:addRewards( rewards, 'long_tail', "treasure_reward" )

            local scoreBuff150EndTime = tonumber( data.scoreBuff150EndTime or '0' )
            UBFAddFiveUpgradeDataUtil:setScoreBuff150EndTime( scoreBuff150EndTime )
            
            --刷新获取时间数据
            UBFAddFiveUpgradeDataUtil:setGetMainPanelRewardSucess()

            -- self:setSaveActiveInfoForPopRewardPanelGetReward()
			-- UBFAddFiveUpgradeBuffUtil:_updateCurrTriggerData(nil, "rewardGotten", true)
			UBFAddFiveUpgradeBuffUtil:_clearCurrTriggerData()
            
            safeRunCall(successCallback,data)
        else
            local failCode = data.failCode or 0
            if failCode == 1 then 
                CommonTip:showTip("活动已结束~")
            elseif failCode == 2 then
                CommonTip:showTip("数据异常，请稍后再次尝试~")
            elseif failCode == 3 then
                CommonTip:showTip("数据异常，请稍后再次尝试~")
            elseif failCode == 4 then
                CommonTip:showTip("数据异常，奖励无法领取，请稍后再次尝试~")
            elseif failCode == 5 then
                CommonTip:showTip("数据异常，请稍后再次尝试~")
            end
            -- self:setSaveActiveInfoForPopRewardPanelGetReward()
            
            safeRunCall(failCallback, failCode)
        end
    end

    local function onFail(evt)
    	local errorCode = evt.errorCode
        CommonTip:showErrorTip(evt)
        safeRunCall(failCallback, errorCode)
    end

	local paramData = {
		lastFailTimes = failNum, 
		payTag = payTag, 
		rewardList = rewardList
	}
	local Request = require "amf.feature.localactivity.addfivestepupgrade.http.RequestAddFiveStepUpgrade2023PromoteReward"
    Request:post(paramData):next(onSuccess, onFail)
end

--[[
function Manager:checkPassLevelCanPopMainPanel( levelId, levelScene, playId, bCheck )
	--检测过关是否可以弹成功面板
	if not levelId then return end
	if not playId then return end
    if not self:isEnabled2() then return end 

    local saveParam = self:getSaveActiveInfoForPopRewardPanel()

	printx(printChannel,"onActPassLevelPopoutRewards 检测过关面板弹出 记录的数据校验", levelId, playId, tts(saveParam))

    if table.isEmpty(saveParam) then 
		return 
	end

	if bCheck then
		if saveParam.levelId then
			local t5 = false
			local t6 = false
			if saveParam.missionIsGetReward then
				t5 = true
			end
			if saveParam.missionIsComplete then
				t6 = true
			end

			if UBFAddFiveStepUpgradeUtil then
				UBFAddFiveStepUpgradeUtil:sendDC('long_tail','passPanelShowCheck', {
					t1 = saveParam.levelId, 
					t2 = saveParam.playId, 
					t3 = levelId,
					t4 = playId,
					t5 = t5,
					t6 = t6,
				})
			end
		end
	end


	if levelId == saveParam.levelId and playId == saveParam.playId and 
		saveParam.missionIsComplete and saveParam.passLevelType == AddFiveStepConfig.passLevelType.kPassLevel and
		not saveParam.missionIsGetReward then 
		printx(printChannel,"onActPassLevelPopoutRewards 检测过关面板弹出结束 可弹")
		return true, saveParam
	else
		printx(printChannel,"onActPassLevelPopoutRewards 检测过关面板弹出结束 不可弹")
	end
end

---------新的过关强弹
function Manager:onActEndlevelProgressPrepare( evt )
	
	local data = evt:getData()


	local runtime = data.runtime
    local levelId = runtime:getLevelId()
    local levelScene = runtime:getLevelScene()
    local playId = runtime:getPlayId()
    local isPassedLevel = runtime:isWin()

    -- UError(12,"onActEndlevelProgressPrepare levelId",levelId)
    -- UError(12,"onActEndlevelProgressPrepare levelScene",levelScene)
    -- UError(12,"onActEndlevelProgressPrepare playId",playId)
    -- UError(12,"onActEndlevelProgressPrepare isPassedLevel",isPassedLevel)

    if not isPassedLevel then return end

    self:passLevelSetData( { levelId=levelId, playId = playId })

    local bCanPop, saveParam = self:checkPassLevelCanPopMainPanel(levelId, levelScene, playId, true )

    -- UError(12,"onActEndlevelProgressPrepare bCanPop 1111",bCanPop, tts(saveParam))
	if bCanPop then 
		-- UError(12,"onActEndlevelProgressPrepare bCanPop 2222",bCanPop, tts(saveParam))
		runtime:setEnabledProcessNodes(UBFActivityIdConst.kAddFiveStepUpgrade, {
	        [UBFProcessNodeEnum.ADDFIVE_UPGRADE_HAMSTER] = {
	            -- 流程节点是否可以启动
	            isProcessEnabled = true
	        },
	    })
	end
end

function Manager:onActEndlevelProgressThirdPartStart( evt )

	local data = evt:getData()
	local runtime = data.runtime
    local levelId = runtime:getLevelId()
    local levelScene = runtime:getLevelScene()
    local playId = runtime:getPlayId()

    local processNodeKey = data.processNodeKey

    -- UError(12,"onActEndlevelProgressThirdPartStart levelId",levelId)
    -- UError(12,"onActEndlevelProgressThirdPartStart levelScene",levelScene)
    -- UError(12,"onActEndlevelProgressThirdPartStart playId",playId)
    -- UError(12,"onActEndlevelProgressThirdPartStart processNodeKey",processNodeKey)

    if processNodeKey == UBFProcessNodeEnum.ADDFIVE_UPGRADE_HAMSTER then
    	local bCanPop, saveParam = self:checkPassLevelCanPopMainPanel(levelId, levelScene, playId, false )
    	if bCanPop then

    		local function closeCallback()
    			data:finishProcessCallBack()
    		end

    		local function popoutFunc( panel )
		        data:popoutView(panel, UBFProcessNodePopLayerType.POPOUT)
		    end

		    local function removeFunc(panel)
		        data:removeView(panel)
		    end

		    -- UError(12,"onActEndlevelProgressThirdPartStart 111")

    		local delegate = {
				showPanelType = AddFiveStepConfig.ShowPanelType.kWin,
				saveParam = saveParam,
				popoutFunc = popoutFunc,
				removeFunc = removeFunc,
			}
			self:popoutMainPanelUBF( delegate, closeCallback )
	    else
	    	data:finishProcessCallBack()
	    end
    end
end

function Manager:onActEndlevelProgressForceComplete( evt )
	local data = evt:getData()
	local processNodeKey = data.processNodeKey

	if processNodeKey == UBFProcessNodeEnum.ADDFIVE_UPGRADE_HAMSTER then
		--do nothing
		--地鼠没有要处理的数据，等待补弹。
	end
end
--]]

return Manager