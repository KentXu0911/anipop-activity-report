--[[
	和UBFScene耦合的逻辑模块，scene的逻辑模块
	和scene都能处理视图，但这个类绝不引用视图！（除了scene）
	直接操作scene就可以
]]
UBFGameSceneManager = class2("UBFGameSceneManager", UBFGameSceneModuleManager)
UBFDebug:monitoringClass(UBFGameSceneManager)

require "ubf.UBFGamePlayScene.logics.UBFGameSceneDCMess"
local GameGuideAnims = require "ubf.UBFGamePlayScene.utils.migrator.GameGuideAnims"
local UBFDeferredScenePanelGuard = require "ubf.UBFGamePlayScene.logics.sceneModules.panel.util.UBFDeferredScenePanelGuard"
local ProphetReplayResumeLaunchPolicy = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ProphetReplayResumeLaunchPolicy"
local ThermalStateMonitor = require "amf.middleware.monitor.thermal.ThermalStateMonitor"

local THERMAL_SAMPLE_INTERVAL_SEC = 5
-- 先保留热状态上升后的性能重推入口，等线上策略确定后再启用。
local ENABLE_PROPHET_THERMAL_PERFORMANCE_REPUSH = false

--
--


local function logDeferredScenePanelGuard(action, guard, ...)
	--
--
--
--
--
--
--
--
--

end

if EnvUtil:isUnity() then
	require "amf.debug.util.MetricsCollector"
end

local instance

function UBFGameSceneManager:getInstance()
	return instance
end

function UBFGameSceneManager:_setInstace(inst)
	instance = inst
end

if not _G._UBFGameSceneManager_Event_Inited then
	_G._UBFGameSceneManager_Event_Inited = true

	if Notify then
		Notify:register("StoreShopClosed" , function()
			if instance then instance:onStoreShopClosed() end
		end)
		Notify:register("onAddStepPanelClose" , function()
			if instance then instance:onStoreShopClosed() end
		end)
	end

	-- 应该统一走notifyScreenSized
	-- UBFViewHelper:bindScreenChangeListener(function()
	-- 	pcall(function() if instance then instance:onScreenExpandChanged() end end)
	-- end)

end

--ctrl + s 自动更新HHH
if __WIN32 and _G.__win32SaveReloadFlag then
	local scene = Director:sharedDirector():getRunningScene()
	if scene and scene:is(UBFGamePlayScene) then
		UBFGameSceneManager:_setInstace(scene._sceneLogic)
	end
end

function UBFGameSceneManager:build(buildData)
	if not buildData.scene then UBFThrow "我要代理scene!" end
	self:initPassedTime()
	self:removeAllAgented()
	self:addAgented(buildData.scene)

	self.so_rust = buildData.so_rust
	self.isDebugMode = buildData.scene.isDebugMode
	self._isUbfUi = buildData.scene:isUBFUi()

	self.isAIEnv = buildData.isAIEnv
	self.isViewReplay = buildData.isViewReplay
	self.resumeLevel = buildData.byResume
	self.continuePlayMode = buildData.continuePlayMode
	self.endDataRecvPromise = UBFPromise:create()

	self.onBoardReadyPromise = UBFPromise:create()
	self.onUiReadyPromise = UBFPromise:create()

	self.onBoardAndUiReadyPromise = UBFPromise:segment()
	self.onBoardAndUiReadyPromise:await(self.onBoardReadyPromise)
	self.onBoardAndUiReadyPromise:await(self.onUiReadyPromise)
	self.onBoardAndUiReadyPromise:resolve()

	--时间计时工具
	self.hrcMap = {}

	--时间线
	self._timeline = UBFActionTimeline:create()
	self.tick = 0

	--断面相关
	self._rSectionList = {}
	self._rSectionIndexMap = { lastStep = nil , topStep = nil }

	--基础数据
	self._levelInfo = buildData.levelInfo
	self._levelJsonData = buildData.levelJsonData
	self._oldLevelConfig = buildData.oldLevelConfig
	self._curLevelJsonData = nil

	--状态数据，会存断面
	self._sceneData = buildData.sceneData or {}
	self._sceneData.playState = UBFGamePlayState.kRun
	self._sceneData.combo = 0
	self._sceneData.revivalCount = 0
	self._sceneData.stageStartTime = Localhost:timeInSec()
	self._sceneData.pauseOccupyMS = 0
	self._sceneData.currGameSwitchIndex = 0 --连闯n，每切一关，自动+1，表示次数
	self._sceneData.comboStatistics = {}
	self._sceneData.sectionSizeRecord = {
		clientMax = 0,
		logicMax = 0,
		opLogSize = 0,
	}
	local PropWorthTest = require "ubf.UBFGamePlayScene.logics.mess.PropWorthTest"
	self._sceneData.pworth = PropWorthTest:createMap()
	self._sceneData.diffFix = self._levelInfo.diffFix

	--945
	self._gameSnapshotData = {
		finalScore = 0,
		gameStates = {}
	}

	--一个临时补丁162修复
	-- local featureMap = self._levelJsonData:getLevelFeatureMap()
	-- if featureMap and featureMap[UBFGameItemType.kCactus] then 
	-- 	-- self._levelInfo._is_must_replay_resume = true
	-- end

	--RustHash
	if UBFRustManager.isRustDyGoReady and self.so_rust and not self._levelInfo.so_rust_dy then 
		local hello_rust = CCFileUtils:sharedFileUtils():getFileData("ubf/rust/lib/rust_hash", "rb")
		local hello_rust = hello_rust and string.trim(hello_rust) or nil
		if not hello_rust then he_log_error("go rust_hash is miss") end
		self._levelInfo.so_rust_dy = hello_rust
	end

	-- 先知
	self._prophet_config_ = nil
	self._prophet_config_source_ = nil
	self._thermal_sampling_scheduled = nil
	self._prophet_thermal_performance_repush_done = nil
	if self._levelInfo.so_prophet and not EnvUtil:isMiniGame() then 
		pcall(function()
			local ver = tonumber(string.split(_G.bundleVersion, ".")[2])
			if ver > 159 or (ver == 159 and self._levelInfo.so_rust_dy) then
				self._prophet_config_ = self._levelInfo.so_prophet
			end
		end)
	end
	self._resume_prophet_launch_state = nil
	self._resume_prophet_launch_attempt_count = 0
	self._resume_prophet_launch_retry_scheduled = false
	self._resume_prophet_launch_on_finalized = nil
	self._resume_prophet_launch_released = false

	self._replaySectionData = buildData.replaySectionData

	--创建构建事件
	local buildEvent = UBFSceneModEventMap[UBFGameModEventEnum.kBeforeConfigBuild]:create {
		buildData = buildData,
		gameModules = buildData.gameModules or {},
		section = buildData.sectionData,
		isUBFUi = self._isUbfUi,
	}

	--获取mod的构建数据
	local modModuleData = buildEvent:removeGameModuleData(UBFGameLogics.kGameMod)

	--如果存在
	if modModuleData then
		modModuleData.levelId = self._levelInfo.levelId
		modModuleData.isRust = self:isInRust()
		--优先构建
		self:installGameModuleByCreateData( modModuleData )
		--如果有断面，优先恢复一次
		if buildData.sectionData then
			local moduleData = buildData.sectionData.moduleData
			local modResumeData = nil
			for i , data in ipairs( moduleData ) do
				local moduleId = data.id
				if moduleId == UBFGameLogics.kGameMod then
					modResumeData = table.clone( data.dat )
					break
				end
			end
			if modResumeData then self:callGameModule(UBFGameLogics.kGameMod, "deserializeData", modResumeData, UBFSerializeSource.kNormal) end
		end
		--发送初始化数据
		self:callGameModule(UBFGameLogics.kGameMod, "notifyEvent", buildEvent)
	end

	-- 给道具栏注入关卡信息（关卡场景 + 关卡 id），供新用户道具解锁判定使用
	for _ , moduleData in ipairs( buildData.gameModules or {} ) do
		if moduleData.logicId == UBFGameLogics.kPropBar then
			moduleData.levelId = self._levelInfo.levelId
			moduleData.levelScene = self._levelInfo.levelScene
			break
		end
	end

	--构建其他全部
	UBFGameSceneModuleManager.build(self, buildData)

	--是否要save断面到本地，不是精彩回放
	self._sectionNeedSave = not self:isInReplay() and not _G.NOT_SAVE_SECTION
	if _G.isLocalDevelopMode and _G.UBF_SUPER_SECTION_DEBUG then self._sectionNeedSave = true end

	--运行时动态数据，不会存断面
	self._sceneRuntimeData = {}

	--notifyEvent 模块事件处理
	--不知道谁给 UBFGameSceneModuleManager 加了个 notifyEvent 虽然和预想不一致，但总比直接引用强！
	self.moduleNotifyEventHanlderMap = {}

	--监听器
	self:registerAllListeners()

	--初始化调用
	self:_refreshSectionIndexMap()


	self:setPropUnavailableExternalReason( UBFPropUnitType.kAddStep5, UBFPropUnavailableReason.kCannot)
	self:callGameModule(UBFGameLogics.kPropBar, "setLock", true)
	if self:isInWonderfulReplay() then self:callGameModule( UBFGameLogics.kPropBar , "setOperateLock" , true ) end
	self:callGameModule(UBFGameLogics.kPropBar, "setEmphasizeType", UBFPropUnitType.kAddStep5, true)

	--如果有断面
	if buildData.sectionData then
		self._last_reusme_flag = 1
		self._last_replay_log_record = buildData.sectionData.replay_log_record
		self.resumeLevel = true
		table.insert( self._rSectionList ,  buildData.sectionData )
		self:_refreshSectionIndexMap()
		self:deserializeAllModule(table.clone(buildData.sectionData.moduleData), UBFSerializeSource.kNormal)
		self._pendingResumeBoardViewData = buildData.sectionData.boardViewData
		self._sceneData = buildData.sectionData.sceneData
		self._sceneData.pworth = self._sceneData.pworth or PropWorthTest:createMap()
		self._sceneData.isLevelResumed = true
		self._lastTimeStatisticSection = buildData.sectionData.timeStatistic
		local extraData = buildData.sectionData.extraData
		self._lastSavedSectionExtra = extraData
		if self._sceneData.playState == UBFGamePlayState.kAlmostFail then
			self:addDelayFunc( 10 , function()
				local fuuuProgressData = extraData and extraData.fuuuProgressData or nil
				local fuuuDeviationResult = extraData and extraData.fuuuDeviationResult or nil
				self:popoutScenePanel(UBFGameScenePanels.kAddStep, {
					fuuuProgressData = fuuuProgressData,
					fuuuDeviationResult = fuuuDeviationResult,
					addStepPanelExtra = extraData and extraData.addStepPanelExtra or nil,
					dcData = extraData and extraData.dcData or nil,
				} )
			end)
		elseif self._sceneData.playState == UBFGamePlayState.kAlmostWin then
			self:addDelayFunc( 5 , function()
				local boardViewLogic = self:getBoardViewLogic()
				if boardViewLogic then UBFBTreeVAFLHandler.bonusTime( {} , {} , boardViewLogic ) end
			end)
		end
		if extraData and extraData.addScoreBuff then
			self:addDelayFunc( 5 , function()
				self:callGameModule( UBFGameLogics.kGameMod, "updateAddScoreBuffView", extraData.addScoreBuff )
			end)
		end
		UBFAddStepPanelSectionUtil:readCustomDataFromSection(self, buildData.sectionData)

		self:addDelayFunc(20, function()
			local guideModMgr = self:callGameModule(UBFGameLogics.kGameMod, "getModMgrBySourceId", UBFModSourceIdEnum.kGuide)
			if guideModMgr and guideModMgr.rustContext then
				if self._sceneData.boardState == UBFConst.BoardSMKey.kWating then
					UBFGuideRustLogic:tryGuide(guideModMgr.rustContext, {})
				end
			end
		end)

		--连闯处理，这么写绝对不好，但是旧棋盘就这样，等后面优化
		if self._sceneData.currGameSwitchIndex > 0 then
			local currUUID = self._sceneData.currUUID
			self._updateBoardSectionRebuildFlag = true
		end
	elseif self._replaySectionData then
		self._last_reusme_flag = 2
		local sceneData = self._replaySectionData.sceneData or {}
		self._sceneData.pworth = sceneData.pworth or PropWorthTest:createMap()
		self._last_replay_log_record = self._replaySectionData.replayLog
	end

	-- launch !
	if self._prophet_config_ and (not self._last_reusme_flag or self._last_reusme_flag == 1) then 
		self.onBoardReadyPromise:next(function() self:_try_push_prophet() end)
	end
	self.onBoardReadyPromise:next(function() self:_start_thermal_sampling() end)

	--兼容部分
	self:addDelayFunc(0, function()

		--
--
--
--
--
--
--
--
--
--


		self:runFakeCall(function()

			-- todo 删除
			if StageInfoLocalLogic then
				local stageInfo = StageInfoLocalLogic:getStageInfo( self._levelInfo.uid )
				if not stageInfo then
					StageInfoLocalLogic:clearStageInfo( self._levelInfo.uid )
					StageInfoLocalLogic:initStageInfo( self._levelInfo.uid , self._levelInfo.levelId , {}, self._levelInfo.levelScene)
				end
			end

		end)

		-- 闪退恢复只是重建同一局场景，不能重复累计开局次数
		if not self:isResumeLevel() then
			PlayRecord:onGameStart(self._levelInfo.levelId)
		end
	end )

	-- 【APP】puraX外屏临时优化方案 https://project.feishu.cn/animal-proj/story/detail/6177962466
	-- 相关模块调整参数
	self.widescreenAdaption = UBFWidescreenAdapter:getGameplayAdjustParams()

	--
--

end

function UBFGameSceneManager:_resolve_prophet_config(configSource)
	if type(configSource) == "table" then
		return configSource
	end
	return RustProphet and RustProphet.config and RustProphet.config[configSource]
end

function UBFGameSceneManager:_build_prophet_launch_message(config, thermalState)
	local data = table.clone(config)
	data.mType = UBFGameMessageType.kProphet
	data.enabled = true
	local ProphetRuntimeObserver =
		require "ubf.UBFPlay.views.messages.ProphetRuntimeObserver"
	local fullDebugLog = ProphetRuntimeObserver:shouldEnableDebugLog(true)
	data.debug_log_level = fullDebugLog and "full" or "metrics"
	data.debug_log = fullDebugLog
	if fullDebugLog then ProphetRuntimeObserver:reset() end
	local ProphetLaunchPerformance =
		require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ProphetLaunchPerformance"
	ProphetLaunchPerformance.applyLaunchPerformance(data)
	if thermalState ~= nil then
		ProphetLaunchPerformance.applyThermalDegradation(data, thermalState)
	end
	return data
end

function UBFGameSceneManager:_send_prophet_message(data)
	if type(data) ~= "table" then
		return false
	end
	local msgClient = self:getMessageLogic()
	if not msgClient then
		return false
	end
	msgClient:sendMessage(data)
	return true
end

-- 配置解析、消息构建和发送分开，后续直接重推时不需要借用一次性 pending 字段。
function UBFGameSceneManager:pushProphetConfig(configSource, thermalState)
	local config = self:_resolve_prophet_config(configSource)
	if not config then
		return false, ProphetReplayResumeLaunchPolicy.AttemptOutcome.InvalidConfig
	end
	local data = self:_build_prophet_launch_message(config, thermalState)
	if not self:_send_prophet_message(data) then
		return false, ProphetReplayResumeLaunchPolicy.AttemptOutcome.MessageClientUnavailable
	end
	return true, ProphetReplayResumeLaunchPolicy.AttemptOutcome.Sent
end

function UBFGameSceneManager:_try_push_prophet()
	if not self._prophet_config_ then
		return false, ProphetReplayResumeLaunchPolicy.AttemptOutcome.NoConfig
	end
	local success, outcome = self:pushProphetConfig(self._prophet_config_)
	if not success then
		return false, outcome
	end
	self._prophet_config_source_ = self._prophet_config_
	self._prophet_config_ = nil
	self._levelInfo.prophetLaunched = true
	return true, ProphetReplayResumeLaunchPolicy.AttemptOutcome.Sent
end

local function getThermalStateStats(sceneData)
	local stats = sceneData.thermalStateStats
	if not stats then
		stats = {
			total = 0,
			count = 0,
			max = 0,
		}
		sceneData.thermalStateStats = stats
	end
	return stats
end

function UBFGameSceneManager:_sample_thermal_state()
	if self.isDisposed or self.endLevelData then
		return false
	end

	local thermalState = ThermalStateMonitor:getThermalState()
	if thermalState < 0 then
		return true
	end

	local stats = getThermalStateStats(self:getSceneData())
	local previousMax = tonumber(stats.max) or 0
	stats.total = stats.total + thermalState
	stats.count = stats.count + 1
	if thermalState > previousMax then
		stats.max = thermalState
		self:_on_prophet_thermal_state_max_rise(previousMax, thermalState)
	end
	return true
end

function UBFGameSceneManager:_on_prophet_thermal_state_max_rise(previousMax, currentMax)
	if not ENABLE_PROPHET_THERMAL_PERFORMANCE_REPUSH
		or self._prophet_thermal_performance_repush_done
		or currentMax <= previousMax
	then
		return
	end

	local configSource = self._prophet_config_source_
	if not configSource then
		return
	end

	local success = self:pushProphetConfig(configSource, currentMax)
	if success then
		self._prophet_thermal_performance_repush_done = true
	end
end

function UBFGameSceneManager:_start_thermal_sampling()
	if self._thermal_sampling_scheduled
		or not ThermalStateMonitor:isSupported()
	then
		return
	end
	self._thermal_sampling_scheduled = true

	-- 立即采样一次，避免短关卡没有任何有效热状态数据。
	if not self:_sample_thermal_state() then
		return
	end

	local function sampleLater()
		if not self:_sample_thermal_state() then
			return
		end
		self:addDelayBySecFunc(THERMAL_SAMPLE_INTERVAL_SEC, sampleLater)
	end

	self:addDelayBySecFunc(THERMAL_SAMPLE_INTERVAL_SEC, sampleLater)
end

function UBFGameSceneManager:shouldGateReplayResumeProphetOperation(message)
	if not message then return false end
	return ProphetReplayResumeLaunchPolicy:shouldGateOperation(
		self._resume_prophet_launch_state,
		message.opType,
		UBFOperationType.kSwap,
		UBFOperationType.kProp
	)
end

function UBFGameSceneManager:_releaseReplayResumeAfterProphetLaunch()
	if self.isDisposed or self._resume_prophet_launch_released then return end
	if self._resume_prophet_launch_state == ProphetReplayResumeLaunchPolicy.State.Pending then return end

	self._resume_prophet_launch_released = true
	self._in_resume_repalying = nil
	self:callGameModule(UBFGameLogics.kBgFg, "setPauseButtonLock", false)
	UBFGameSpeedManager:resuleDefaultSpeed()
	if UBFGameSpeedManager:hasAnySpeedSwitchOn() then
		UBFGameSpeedManager:setGameSpeedSwitch(UBFGameSpeedManager:getGameSpeedSwitch())
		UBFGameSpeedManager:changeSpeedForFastPlay()
	end
	local scene = self:getScene()
	if scene and not scene.isDisposed then
		scene:setResumingShow(false)
	end
	self:callGameModule(UBFGameLogics.KInformationFlowDesign, "updateAllBonus")
	self:callGameModule(UBFGameLogics.kPropBar, "setLock", false)

	local onFinalized = self._resume_prophet_launch_on_finalized
	self._resume_prophet_launch_on_finalized = nil
	if onFinalized then onFinalized() end
end

function UBFGameSceneManager:finalizeReplayResumeProphetLaunch(onFinalized)
	if self._resume_prophet_launch_released then
		return self._resume_prophet_launch_state
	end
	if onFinalized and not self._resume_prophet_launch_on_finalized then
		self._resume_prophet_launch_on_finalized = onFinalized
	end

	if self.isDisposed then
		self:disableReplayResumeProphetLaunchOnDispose()
		return ProphetReplayResumeLaunchPolicy.State.Disabled
	end

	local state = self._resume_prophet_launch_state
	if state ~= ProphetReplayResumeLaunchPolicy.State.Pending then
		if not state then
			self._resume_prophet_launch_state = ProphetReplayResumeLaunchPolicy.State.Disabled
		end
		self:_releaseReplayResumeAfterProphetLaunch()
		return self._resume_prophet_launch_state
	end

	local success, outcome = self:_try_push_prophet()
	local nextState, attemptCount, shouldRetry =
		ProphetReplayResumeLaunchPolicy:resolveAttempt(
			state,
			self._resume_prophet_launch_attempt_count,
			success and ProphetReplayResumeLaunchPolicy.AttemptOutcome.Sent or outcome
		)
	self._resume_prophet_launch_state = nextState
	self._resume_prophet_launch_attempt_count = attemptCount

	if shouldRetry then
		if not self._resume_prophet_launch_retry_scheduled then
			self._resume_prophet_launch_retry_scheduled = true
			self:addDelayFunc(1, function()
				self._resume_prophet_launch_retry_scheduled = false
				self:finalizeReplayResumeProphetLaunch()
			end)
		end
		return nextState
	end

	self._resume_prophet_launch_retry_scheduled = false
	if nextState == ProphetReplayResumeLaunchPolicy.State.Disabled then
		if outcome == ProphetReplayResumeLaunchPolicy.AttemptOutcome.MessageClientUnavailable then
			he_log_error("ProphetResumeLaunchUnavailable")
		elseif outcome == ProphetReplayResumeLaunchPolicy.AttemptOutcome.InvalidConfig then
			he_log_error("ProphetResumeLaunchConfigMissing")
		end
		self._prophet_config_ = nil
	end
	self:_releaseReplayResumeAfterProphetLaunch()
	return nextState
end

function UBFGameSceneManager:disableReplayResumeProphetLaunchOnDispose()
	self._resume_prophet_launch_state = ProphetReplayResumeLaunchPolicy.State.Disabled
	self._resume_prophet_launch_retry_scheduled = false
	self._resume_prophet_launch_on_finalized = nil
	self._prophet_config_ = nil
	self._prophet_config_source_ = nil
	self._in_resume_repalying = nil
end

--
--
--
--
--
--
--
--
--
--
--
--
--
--
--


function UBFGameSceneManager:getHrcByKey(key)
	-- body
	if not self.hrcMap[key] then
		self.hrcMap[key] = UBFLuaHelper:hrc()
	end

	return self.hrcMap[key]
end

function UBFGameSceneManager:isInRust()
	return self.so_rust and true or false
end

function UBFGameSceneManager:isResumeLevel( ... )
	return self.resumeLevel
end

function UBFGameSceneManager:initPassedTime( ... )
	self.initTimeMill = Localhost:timeInMillis()
end

function UBFGameSceneManager:getPassedTime( ... )
	if not self.initTimeMill then return 0 end
	local cur = Localhost:timeInMillis()
	return cur - self.initTimeMill
end

function UBFGameSceneManager:onRepeatBtnTap(  )
	local event = UBFSceneModEventMap[UBFGameModEventEnum.kRepeatBtnTap]:create {
		levelId = self._levelInfo.levelId,
	}
	self:notifyModEvent( event )
end

function UBFGameSceneManager:registerAllListeners()
	local propbarModule = self:getGameModule( UBFGameLogics.kPropBar )

	if propbarModule then
		propbarModule:registerListener(UBFGameEvents.kPropSelectSubType , function( event , dat )
			local config = dat.subType == "row" and UBFAnimalSpecialType.kLineH or UBFAnimalSpecialType.kLineV
			--更换操作器
			local boardViewLogic = self:getBoardViewLogic()
			if not boardViewLogic then return end
			local interactor = boardViewLogic:getInteractor()
			if interactor and interactor.convert then
				local newInteractor = UBFBoardOnePointInteractor:create({})
				interactor:convert( newInteractor )
				newInteractor.finishExtraData = { spType = config }
			end
			--更换引导
			local guideMask = self:getScene():getGuideMask()
			if guideMask then
				local action
				if config == UBFAnimalSpecialType.kLineH then action = { panelName = "guide_dialogue_500010402_1_2" }
				else action = { panelName = "guide_dialogue_500010402_1_1" } end
				UBFGamePlaySceneMess:addPropBarTipAnime( guideMask , dat.propUnitType , {
					playIndex = config == UBFAnimalSpecialType.kLineH and 2 or 1,
					action = action ,
				} )
			end
		end)
		propbarModule:registerListener( UBFGameEvents.kPropUseSuccess , function( event , dat )
			UBFGameSceneDCMess:usePropDC( dat.propUnitType , false  , dat.context and dat.context.useParams )
		end )
		propbarModule:registerListener( UBFGameEvents.kPropUseFail , function( event , dat )
			UBFGameSceneDCMess:usePropDC( dat.propUnitType , true )
		end )
	end

	local bgfgModule = self:getGameModule( UBFGameLogics.kBgFg )
	if bgfgModule then
		bgfgModule:registerListener(UBFGameEvents.kBtnClick , function( event , name , isForbidden )
			if isForbidden then return end
			if name == "pause" then
				self:popoutScenePanel( UBFGameScenePanels.kPausePanel )
				self:onPauseBtnTap()
			elseif name == "propHelp" then self:popoutScenePanel( UBFGameScenePanels.kPropHelp ) end
		end)
	end

	local wrModule = self:getGameModule( UBFGameLogics.kWonderfulReplay )
	if wrModule then
		wrModule:registerListener( UBFGameEvents.kClose , function( event , name )
			self:onGameOver({ replay = true, action = "close" })
		end)
		wrModule:registerListener( UBFGameEvents.kWonderfulReplayAction , function( event , action )
			local boardViewLogic = self:getBoardViewLogic()
			if not boardViewLogic then return end
			if action == "start" then self:updatePause( -1 )
			elseif action == "stop" then self:updatePause( 1 )
			elseif action == "recordStop" then self:onGameOver({ replay = true, action = "recordStop" }) end
		end)
	end

	self.moduleNotifyEventHanlderMap["isNeedPlayPreFlowerAnim"] = function( data )
		self:callGameModule( UBFGameLogics.KInformationFlowDesign, "ubfNeedPlayPreFlowerAnim", data)
	end

	self.moduleNotifyEventHanlderMap["starStateChange"] = function( data )
		local curScore , curStar = self:getCurrScoreAndStar()
		self:callGameModule( UBFGameLogics.kScore, "playExceededAnim", curStar, curScore )
		self:callGameModule( UBFGameLogics.KInformationFlowDesign, "onStarStateChange", curStar, curScore )
	end
	self.moduleNotifyEventHanlderMap["surpassHistortyScore"] = function( data )
		local curScore , curStar = self:getCurrScoreAndStar()
		self:callGameModule( UBFGameLogics.kScore, "playExceededAnim", curStar, curScore )
		self:callGameModule( UBFGameLogics.KInformationFlowDesign, "onSurpassHistortyScore", curStar, curScore )
	end
	self.moduleNotifyEventHanlderMap["updateProgress"] = function( data )
		local event = UBFSceneModEventMap[UBFGameModEventEnum.kUpdateProgress]:create(data)
		self:notifyModEvent(event)
	end
	self.moduleNotifyEventHanlderMap["scorePendantAddFinish"] = function( data )
		local event = UBFSceneModEventMap[UBFGameModEventEnum.kScorePendantAddFinish]:create(data)
		self:notifyModEvent(event)
	end
end

function UBFGameSceneManager:setMsgLogic( msgLogic )
	if self._msgLogic then UBFThrow "不允许重复设置消息逻辑" end
	if msgLogic.rustMagicNumber then 
		self._levelInfo.rustMagicNumber = msgLogic.rustMagicNumber 
	end
	self._msgLogic = msgLogic
	self._msgLogic._crashCatcher = function( msg )
		local boardViewLogic = self:getBoardViewLogic()
		if boardViewLogic then
			boardViewLogic:onException(UBFBoardExceptionLevel.kFatal, "消息崩溃了" .. tostring(msg), "msg")
		else
			self:onGameOver({
				isCrash = true,
				crashMsg = tostring( msg ) ,
				source = "msg"
			})
		end
	end
	self._msgLogic.hook:addHook("operation", function(message)
		if self:shouldGateReplayResumeProphetOperation(message) then
			message.abandon = true
			return
		end
		if message.opType == UBFOperationType.kSwap or message.opType == UBFOperationType.kProp then
			local boardViewLogic = self:getBoardViewLogic()
			if boardViewLogic then
				boardViewLogic:getBoardStateMap()[UBFBoardStateKey.kCanSwap] = false
				boardViewLogic:resetInteractor()
			end
		end
	end)
	self._msgLogic:registerListener(UBFGamePlaySceneEvents.kClosure , function() self:onLogicClosure() end)
	self._msgLogic:registerListener(UBFGamePlaySceneEvents.kGameOver , function( evt , endLevelData )
		self:onEndLevelDataRecv( endLevelData )
		-- AI 直接回收场景，不启动依赖完整用户出关链路的 process。
		if not self.isAIEnv then
			self:launchEndLevelProcess(endLevelData)
		end
		if self._replayResumeLevelRuntime then
			-- 回放恢复时，如果关卡收到 endLevelData，直接结束，不再需要进bonus
			local boardViewLogic = self:getBoardViewLogic()
			if boardViewLogic then
				boardViewLogic.isReplay = false
			end
			local endFrameIdx = endLevelData.endFrame
			if boardViewLogic and endFrameIdx then
				boardViewLogic:addRelativeTickCallback( endFrameIdx + 30 , function() self:onGameOverViewCome() end, true)
			else
				self:onGameOverViewCome()
			end
			return
		end

		if not endLevelData.win and endLevelData.failReason == UBFGameFailReason.kDropout
			or endLevelData.failReason == UBFGameFailReason.kRetry
		then
			local scene = self:getScene()
			if scene and endLevelData.failReason == UBFGameFailReason.kRetry then scene.game_retry_flag = true end
			self:onGameOverViewCome()
			return
		end
		local boardViewLogic = self:getBoardViewLogic()
		local endFrameIdx = endLevelData.endFrame
		if boardViewLogic and endFrameIdx then
			if not endLevelData.win then
				boardViewLogic:addRelativeTickCallback( endFrameIdx + 30 , function() self:onGameOverViewCome() end, true)
			else
				boardViewLogic:addRelativeTickCallback( endFrameIdx + 5 , function() self:onGameOverViewCome() end, true)
			end
		else
			self:onGameOverViewCome()
		end
	end)
	self._msgLogic:registerListener(UBFGamePlaySceneEvents.kReplayAction , function( evt , dat )
		local scene = self:getScene()

		if scene and scene._replay_nice_time_line_ then
			local ret = scene:_debugTrusteeshipReplayAction(dat)
			if ret then return end
		end

		local action = dat.action
		if action == UBFGameReplayActionEnum.kError then
			if self.resumeLevel then
				-- resumelevel模式中，后面还会又end
				if dat.msg then
					local Error = UError or UBFError
					Error("replay resume error:" .. dat.msg)
				end
				if self:isInRust() then self:onGameReplayEnd(dat)end
			else
				if self:isInRust() and EnvUtil:isWindows() then 
					CommonTip:showTip("Rust回放失败了，不会自动退关哟~")
				else
					self:onGameOver({ 
						replay = true,
						action = "error",
					})
				end
			end
		elseif action == UBFGameReplayActionEnum.kEnd then
			self:onGameReplayEnd(dat)
		elseif action == UBFGameReplayActionEnum.kBegin then
			self:onGameReplayBegin(dat)
		end
	end )
	self._msgLogic:registerListener(UBFGamePlaySceneEvents.kAddTempProp, function( evt , propList , info )
		self:onAddTempProp( propList , info )
	end )
	self._msgLogic:registerListener(UBFGamePlaySceneEvents.kAskSection , function( evt , datas )
		local mode = datas.mode
		if mode == "take" then

			local removeIds = datas.removeIds
			local id = datas.id
			local stepCount = datas.stepCount

			for k , _id in ipairs(removeIds or {}) do
				self:onRemoveSection( _id )
			end

			self:onTakeSection( id , stepCount )

			if self.isDebugMode then
				local boardViewLogic = self:getBoardViewLogic()
				UBFGamePlaySceneDebug:static_addSectionDebug( self:getMessageLogic() , boardViewLogic , datas.origin )
				UBFGamePlaySceneDebug:static_refreshSectionDebugView()
			end

		elseif mode == "resume" then

			local resumeType = datas.resumeType
			local id = datas.id

			self:onReumeSection( id )

			if self.isDebugMode then
				UBFGamePlaySceneDebug:debugSaySomething(string.format("进行了%s的恢复，断面ID:%s" , tostring(resumeType) , tostring(id)))
				UBFGamePlaySceneDebug:static_refreshSectionDebugView()
			end

		end
	end )
	self._msgLogic:registerListener(UBFGamePlaySceneEvents.kGameStateChange, function( evt , datas )
		if datas.preview then
			if self._replayResumeLevelRuntime then
				self._replayResumeLevelRuntime._lastGameState = datas.datas
			else
				self:onGameStateChange( datas )
			end
		else
			self:onGameStateChange( datas )
		end
	end )
	self._msgLogic:registerListener(UBFGamePlaySceneEvents.kGameSwitch, function(evt, datas)
		self:onGameSwitch(datas)
	end)
	--精彩回放小手处理
	if self:isInWonderfulReplay() then
		self._msgLogic:registerListener(UBFGamePlaySceneEvents.onBeforeReplayOperation, function( evt , datas )
			local promise = self:onBeforeWonderfulReplayOperation(datas.opData)
			datas.waitPromise = promise
		end)
	else
		self._msgLogic:registerListener(UBFGamePlaySceneEvents.onBeforeReplayOperation, function( evt , datas )
			self:onReplayOperation(datas.opData)
		end)
	end

	if self._lastTimeStatisticSection then
		self._msgLogic:deserializeTimeStatistic( self._lastTimeStatisticSection )
		self._lastTimeStatisticSection = nil
	end

	if self._boardViewLogicCacheMap then
		for _, boardViewLogic in pairs(self._boardViewLogicCacheMap) do
			self._msgLogic:addBoardViewLogic(boardViewLogic)
		end
		self._boardViewLogicCacheList = nil
	end

	--
--


end

function UBFGameSceneManager:addBoardViewLogic(boardViewLogic)
	local msgLogic = self:getMessageLogic()
	local boardId = boardViewLogic.boardId or 1

	if not msgLogic then
		self._boardViewLogicCacheMap = self._boardViewLogicCacheMap or {}
		self._boardViewLogicCacheMap[boardId] = boardViewLogic
	else
		msgLogic:addBoardViewLogic(boardViewLogic)
	end

    boardViewLogic:registerListener(UBFGameEvents.kFindInst, function(evt, dat)
		if dat.inst then return end
		if self:is(dat.cls) then dat.inst = self end
		local scene = self:getScene()
		if isSafeCocosObj(scene) and scene:is(dat.cls) then dat.inst = scene end
	end)

	boardViewLogic:registerListener(UBFGamePlaySceneEvents.onSwap, function(evt, data)
		if self:_isOnlyOnceWrite() then self._lastReplaySectionSaved = nil end
		if self._swap_op_lock then return end
		local from = data.from
		local to = data.to
		self._last_swap_data = { from = from, to = to }
		if from and to then self:onCatchStepHook("swapAction",
			{
				x1 = from.c, x2 = to.c,
				y1 = from.r, y2 = to.r,
				boardId = boardId,
			})
		end

		self:onSwapAction(from, to)
	end)

	boardViewLogic:registerListener(UBFGamePlaySceneEvents.onSwapGiveUp, function(evt, data)
		local event = UBFSceneModEventMap[UBFGameModEventEnum.kSwapGiveUp]:create(data)
		self:notifyModEvent(event)
	end)

	boardViewLogic:registerListener(UBFGamePlaySceneEvents.onSwapRefused, function(evt, data)
		local event = UBFSceneModEventMap[UBFGameModEventEnum.kSwapRefused]:create(data)
		self:notifyModEvent(event)
	end)

	boardViewLogic:registerListener(UBFGamePlaySceneEvents.kBoardBeforeInitBuild, function(evt, data)
		if self.switchWaitAnimation then
			local boardViewLogic = self:getBoardViewLogic()
			local viewport = boardViewLogic:getGridViewport()
			local w, h = UBFBigBoardHelper:getWHFromRect(viewport)
			data.startAnimeViewport = {
				top = viewport.top - h,
				bottom = viewport.bottom - h,
				left = viewport.left,
				right = viewport.right
			}
			boardViewLogic:setViewportClipping(true)
			data.needManualUpdateList = true
		end
		if EnvUtil:isUnity() and data.byLaunch then
			data.needManualUpdateList = true
		end
	end)

	boardViewLogic:registerListener(UBFGamePlaySceneEvents.kBoardInitBuild, function(evt, data)
		-- 修复rust回放恢复重新初始化后，因为已经收到endLevelData导致无限卡住的情况
		if self.endLevelData and self._replay_resume_send_launch_refresh then 
			self:onGameOverViewCome()
			return
		end
		
		self:onBoardViewLogicBuild()
		self:_resumeBoardViewSectionByBoard(boardViewLogic, boardId)
        if data.byLaunch then
			data.boardId = boardId
			self:onBoardViewLogicBuildLaunch(data)
		else
			local logicViewport = boardViewLogic:getGridLogicViewport()
            local viewport = boardViewLogic:getGridViewport()
            local w, h = UBFBigBoardHelper:getWHFromRect( viewport )
            boardViewLogic:updateViewport( {
                top = logicViewport.top,
                left = logicViewport.left,
                bottom = logicViewport.top + h - 1,
                right = logicViewport.left + w - 1,
            } )
            boardViewLogic:updateLogicShowViewport()
			self:_doManualUpdateList(data)
		end
	end)

	boardViewLogic:registerListener(UBFGamePlaySceneEvents.onSwapAnimationCome , function( evt , from , to , datas )
		self:onSwapAnimation(from, to, datas)
		local event = UBFSceneModEventMap[UBFGameModEventEnum.kSwapAnimationCome]:create(datas)
		self:notifyModEvent(event)
	end )

	boardViewLogic:registerListener(UBFGamePlaySceneEvents.kBoardStateChange, function(evt, key, oldVal, val)
		self:onBoardStateChange(key, oldVal, val, boardId)
	end )

	boardViewLogic:registerListener(UBFGamePlaySceneEvents.kMainBoardOperable, function()
		if boardId ~= 1 then return end
		local scene = self:getScene()
		if scene then scene:playPostOperableVisualQueue() end
	end)

	boardViewLogic:registerListener(UBFGamePlaySceneEvents.kModRequest, function(evt, data)
		data.boardId = boardId
		self:callGameModule(UBFGameLogics.kGameMod, data.func, data)
	end )

	boardViewLogic:registerListener(UBFGamePlaySceneEvents.kTileSceneCollaborate, function(evt, dat)
		local deliver = dat.deliver
		local itemType = deliver and deliver.from or dat.itemType
		if not itemType then return end
		-- todo
	end)

	boardViewLogic:registerListener(UBFGamePlaySceneEvents.kMagicbirdLine, function(evt, data)
		local event = UBFSceneModEventMap[UBFGameModEventEnum.kMagicbirdLine]:create {
			produceList = data.produceList,
			boardId = boardId,
		}
		self:notifyModEvent(event)
	end )

	boardViewLogic:registerListener(UBFGamePlaySceneEvents.k55EeffectSwap, function( evt , data )
		local event = UBFSceneModEventMap[UBFGameModEventEnum.k55EeffectSwap]:create(data)
		self:notifyModEvent(event)
	end )

	boardViewLogic:registerListener(UBFGamePlaySceneEvents.k54EeffectSwap, function( evt , data )
		local event = UBFSceneModEventMap[UBFGameModEventEnum.k54EeffectSwap]:create(data)
		self:notifyModEvent( event )
	end)

	boardViewLogic:registerListener(UBFGamePlaySceneEvents.kSkipBonus, function ( evt , data )
		self:skipBonus()
	end)

	--非核心棋盘不监听
	if boardId ~= 1 then return end

	--
--

end

function UBFGameSceneManager:skipBonus( )
	--todo 刷新ui到最新状态
	local boardViewLogic = self:getBoardViewLogic()
	boardViewLogic:clearAllViewAction()
	boardViewLogic:clearAllBoardEffect()
	boardViewLogic:clearDelayline()
	boardViewLogic:setPause(true)

	self:onGameOverViewCome()
end

function UBFGameSceneManager:dispose()
	-- 场景销毁是终态，此处只清理，不能恢复任何延迟面板。
	--
--

	self:disableReplayResumeProphetLaunchOnDispose()
	self:clearDeferredScenePanelGuard()
	UBFGameSceneModuleManager.dispose(self)
	self.isDisposed = true
	UBFBehaviorTreeManager:getInstance():reportTreesByRuntimeInst("sceneMgr", self)

	-- msg logic
	local msgLogic = self:getMessageLogic()
	if msgLogic then
		msgLogic:ergodicBoardViewLogic(function( board ) board:dispose() end)
		msgLogic:dispose()
	end

	-- self:runFakeCall(function() OldGameGuideBridge:onExitGame() end)

	-- scene
	self:removeAllAgented()
	-- cache
	self._boardViewLogicCacheMap = nil

	-- speed
	UBFGameSpeedManager:clearLevelEventListeners()
	UBFGameSpeedManager:resuleDefaultSpeed()

	--delete fake
	self:clearAllFake()

	--清理section
	pcall(function() UBFSectionResumeHelper:removeSavedSection() end)

	pcall(function ()
		for k,v in pairs(self.hrcMap) do
			v:close()
		end
		self.hrcMap = nil
	end)

end

--------------------****** *↓* ******--------------------
--						Get多多
--------------------****** *↑* ******--------------------

function UBFGameSceneManager:getMessageLogic()
	return self._msgLogic
end

function UBFGameSceneManager:getBoardViewLogic(boardId)
	return self._msgLogic and self._msgLogic:getBoardViewLogic(boardId) or (self._boardViewLogicCacheMap and self._boardViewLogicCacheMap[boardId or 1])
end

function UBFGameSceneManager:removeBoardViewLogic(boardId)
	if self._msgLogic then self._msgLogic:removeBoardViewLogic(boardId) end
	-- 连续闯关切关，需要把 _boardViewLogicCacheMap 里的索引也清除
	if self._boardViewLogicCacheMap then self._boardViewLogicCacheMap[boardId or 1] = nil end
end

function UBFGameSceneManager:ergodicBoardViewLogic(func)
	return self._msgLogic and self._msgLogic:ergodicBoardViewLogic(func)
end

function UBFGameSceneManager:getScene()
	return self:getMainAgented()
end

function UBFGameSceneManager:getFlyObjectLayer( flyType )
	local scene = self:getScene()
	return scene and scene.effectLayer
end

function UBFGameSceneManager:getSceneData()
	return self._sceneData
end

function UBFGameSceneManager:getCustomSceneDataByKey(key)
	if not self._sceneData.customData then
		self._sceneData.customData = {}
	end
	return self._sceneData.customData[key]
end

function UBFGameSceneManager:setCustomSceneDataByKey(key,val)
	if not self._sceneData.customData then
		self._sceneData.customData = {}
	end
	self._sceneData.customData[key] = val
end


function UBFGameSceneManager:getSceneRuntimeData()
	return self._sceneRuntimeData
end

function UBFGameSceneManager:getLevelInfo()
	return self._levelInfo
end

function UBFGameSceneManager:getPlayId()
	return self._levelInfo.playId
end

--这个函数名字写错了，用下面的
function UBFGameSceneManager:getLeveJsonData( ... )
	return self._levelJsonData
end

function UBFGameSceneManager:getLevelJsonData()
	return self._levelJsonData
end

--切换关卡后的配置
function UBFGameSceneManager:getCurLevelJsonData( ... )
	return self._curLevelJsonData or self._levelJsonData
end

function UBFGameSceneManager:isInWonderfulReplay()
	return self._levelInfo.wonderfulReplay
end

function UBFGameSceneManager:isInReplay()
	local boardViewLogic = self:getBoardViewLogic()
	return self._levelInfo.wonderfulReplay or self._levelInfo.devReplay or (boardViewLogic and boardViewLogic.isReplay)
end

function UBFGameSceneManager:isInDevReplay()
	return self:isInReplay() and not self:isInWonderfulReplay()
end

function UBFGameSceneManager:isGameOver()
	return self.endLevelData or self._msgLogic.isClosure
end

function UBFGameSceneManager:isGameNotStart()
	return not self._msgLogic
end

function UBFGameSceneManager:getCurrScoreAndStar()
	local levelInfo = self:getLevelInfo()
	local tallyUnit = self:callGameModule( UBFGameLogics.kTally , "getTallyUnit", UBFTallyId.kScore )
	local currScore = tallyUnit and tallyUnit:getValue() or 0
	local targets = self:getLeveJsonData():getScoreTargets()
    local star = 0
    for i = 1 , #targets do
        if targets[i] <= currScore then star = i end
    end
    return currScore , star
end

function UBFGameSceneManager:getMoveCount()
	local unit = self:callGameModule( UBFGameLogics.kTally , "getTallyUnit" , UBFTallyId.kMoveStep )
    local moveCount = unit and unit:getValue( UBFTallyValueType.kMoveCount ) or 0
	return moveCount
end

-- 是否是宽屏（当前是为了临时处理 华为puraX外屏）
function UBFGameSceneManager:isWidescreen()
	return UBFWidescreenAdapter:isWidescreen()
end

function UBFGameSceneManager:enableAdaptWidescreen()
	return UBFWidescreenAdapter:isEnabled()
end

--------------------****** *↓* ******--------------------
--						操作多多
--------------------****** *↑* ******--------------------

--高效安全的setTimeout
function UBFGameSceneManager:addDelayFunc( delay  , func )
	self._timeline:add( self.tick + delay , func )
end

function UBFGameSceneManager:addDelayBySecFunc( sec  , func )
	self._timeline:add( self.tick + sec * 60 , func )
end

function UBFGameSceneManager:createDelayPromise( delay , p1 , p2 )
	local promise = UBFPromise:create()
	self._timeline:add( self.tick + delay , function() promise:resolve( p1 , p2 ) end )
	return promise
end

function UBFGameSceneManager:setPropUnavailableExternalReason( propUnitType  , reason, sourceKey )
	local barModule = self:getGameModule( UBFGameLogics.kPropBar )
	if not barModule then return end
	local propBubble = UBFHelper:invoke( barModule , "getPropBubble" , propUnitType )
	if not propBubble then return end
	if sourceKey and propBubble.setUnavailableExternalReasonBySource then
		propBubble:setUnavailableExternalReasonBySource( sourceKey, reason )
	else
		propBubble:setUnavailableExternalReason( reason )
	end
	UBFHelper:invoke( barModule , "updateState" , propUnitType )
end

function UBFGameSceneManager:isAddStepPanelOpening()
	local addStep = self._sceneRuntimeData and self._sceneRuntimeData.addStep
	return addStep ~= nil and addStep.isClose ~= true
end

function UBFGameSceneManager:getAddStepPanelStatus()
	local status = {
		active = false,
		phase = "inactive",
		swapBlocked = false,
		panelReady = false,
		terminalReady = false,
		addFiveReady = false,
		addTwoReady = false,
		closeReady = false,
		dismissReady = false,
	}
	local addStep = self._sceneRuntimeData and self._sceneRuntimeData.addStep
	if not addStep or addStep.isClose == true then return status end

	status.active = true
	status.phase = "opening"
	status.swapBlocked = true

	local logic = addStep.logic
	if not logic then return status end
	if type(logic.getPanelStatus) ~= "function" then
		status.phase = logic.isDisposed and "stale" or "opening"
		status.panelRoot = type(logic.getMainAgented) == "function" and logic:getMainAgented() or nil
		return status
	end

	local ok, panelStatus = pcall(logic.getPanelStatus, logic)
	if not ok or type(panelStatus) ~= "table" then
		status.phase = "stale"
		return status
	end
	for key, value in pairs(panelStatus) do
		status[key] = value
	end
	status.active = true
	status.swapBlocked = true
	return status
end

--[[
	场景级延迟面板门控接口。
	SceneManager 同一时刻只持有一个活跃 guard，具体拦截哪个面板由 scenePanelType 决定。
	业务流程持有 begin 返回的 guard token，并用同一个 token 执行 commit、cancel 或 clear；
	这样即使旧 process 的异步回调晚到，也无法操作后续流程新建的 guard。
]]

-- 开始拦截指定类型的场景面板，并绑定当前 playId。
-- 场景已销毁或已有活跃 guard 时返回 nil，调用方不应继续启动依赖该 guard 的流程。
function UBFGameSceneManager:beginDeferredScenePanelGuard(scenePanelType)
	if self.isDisposed or self._deferredScenePanelGuard then
		logDeferredScenePanelGuard("begin_rejected", self._deferredScenePanelGuard, "panelType", scenePanelType)
		return nil
	end

	-- 返回 token 供生命周期回调校验，避免旧 process 误操作后续新建的 guard。
	local guard = UBFDeferredScenePanelGuard:create(scenePanelType, self:getPlayId())
	self._deferredScenePanelGuard = guard
	logDeferredScenePanelGuard("begin", guard, "panelType", scenePanelType)
	return guard
end

-- 尝试由当前 guard 消费一次面板弹出请求。
-- 返回 true 表示请求已被 guard 处理：pending 状态会暂存最新请求，committed 状态会直接丢弃；
-- 返回 false 表示没有匹配的 guard，调用方应继续执行原有弹出逻辑。
function UBFGameSceneManager:tryDeferScenePanel(scenePanelType, params)
	local guard = self._deferredScenePanelGuard
	if not guard or not guard:tryDefer(scenePanelType, params) then return false end

	local action = guard:getState() == UBFDeferredScenePanelGuard.State.PENDING and "defer" or "drop"
	logDeferredScenePanelGuard(action, guard, "panelType", scenePanelType)
	return true
end

-- 提交高优先级流程，表示玩家已经确认离开旧流程。
-- 只有传入 token 仍是当前活跃 guard 时才生效；提交后继续拦截匹配面板，但不再保存和恢复请求。
function UBFGameSceneManager:commitDeferredScenePanelGuard(guard)
	if not guard or self._deferredScenePanelGuard ~= guard then return false end
	local committed = guard:commit()
	logDeferredScenePanelGuard("commit", guard, "committed", committed)
	return committed
end

-- 取消高优先级流程，并按业务条件尝试恢复 pending 阶段暂存的面板请求。
-- shouldRestore(sceneMgr, request) 只负责业务有效性判断；playId 和 token 一致性由通用层保证。
-- 返回值仅表示本次是否实际调用 popoutScenePanel，不表示 guard 是否曾经存在。
function UBFGameSceneManager:cancelDeferredScenePanelGuard(guard, shouldRestore)
	if not guard or self._deferredScenePanelGuard ~= guard then return false end

	-- 先解除 guard，再恢复面板，避免 popoutScenePanel 被当前 guard 再次拦截。
	self._deferredScenePanelGuard = nil
	local request = guard:cancel(self:getPlayId())
	local restored = false
	if request and not self.isDisposed and (not shouldRestore or shouldRestore(self, request)) then
		self:popoutScenePanel(request.panelType, request.params)
		restored = true
	end
	logDeferredScenePanelGuard("cancel", guard, "restored", restored)
	return restored
end

-- 终态清理，不恢复任何暂存请求，可安全重复调用。
-- 传入 token 时只清理对应 guard；不传时用于场景销毁等确定性终态，直接清理当前活跃 guard。
function UBFGameSceneManager:clearDeferredScenePanelGuard(guard)
	local activeGuard = self._deferredScenePanelGuard
	if not activeGuard or (guard and activeGuard ~= guard) then return false end

	self._deferredScenePanelGuard = nil
	activeGuard:clear()
	logDeferredScenePanelGuard("clear", activeGuard)
	return true
end

-- 加五步面板打开或棋盘离开运行态后，背景道具栏的加步数入口只允许展示，不允许再发起使用。
-- 这里不复用 setPropUnavailableExternalReason，避免把泡泡刷新成不可用或隐藏态。
function UBFGameSceneManager:isAddStepPropBarUseBlocked()
	if self._addStepPanelPropBarUseLocked then return true end
	if self:isAddStepPanelOpening() then return true end

	local sceneData = self:getSceneData()
	local playState = sceneData and sceneData.playState
	return playState ~= nil and playState ~= UBFGamePlayState.kRun
end

-- 只维护加五步道具能力的使用锁，不影响道具栏泡泡展示状态。
function UBFGameSceneManager:setAddStepPanelPropBarLock( isLock )
	self._addStepPanelPropBarUseLocked = isLock == true
end

function UBFGameSceneManager:updatePause( count )
	self.pauseCount = math.max( (self.pauseCount or 0) + count , 0 )
	local boardViewLogic = self:getBoardViewLogic()
	if not boardViewLogic then return end
	boardViewLogic:setPause(self.pauseCount > 0)
	if self.pauseCount <= 0 then
		if self._pauseResumePromise then
			self._pauseResumePromise:resolve()
			self._pauseResumePromise = nil
		end
	end
end

function UBFGameSceneManager:isInPause()
	return self.pauseCount and self.pauseCount > 0
end

function UBFGameSceneManager:addPauseResumeCallback( func )
	if not self._pauseResumePromise then self._pauseResumePromise = UBFPromise:create() end
	self._pauseResumePromise:next(func)
end

--------------------****** *↓* ******--------------------
--						断面多多
--------------------****** *↑* ******--------------------

function UBFGameSceneManager:isRSectionListEmpty( ... )
	if not self._rSectionList then return true end

	if #self._rSectionList == 0 then
		return true
	end

	if #self._rSectionList == 1 then
		local dat = self._rSectionList[1]
		return dat and not dat.byStep
	end

	return false
end

function UBFGameSceneManager:_refreshSectionIndexMap()
	self._rSectionIndexMap.lastStep = nil
	self._rSectionIndexMap.topStep = nil
	local count = 0
	local lastIndex = 1
	for i = #self._rSectionList , 1 , -1 do
		local dat = self._rSectionList[i]
		if dat.byStep then
			count = count + 1
			if count == 1 then
				self._rSectionIndexMap.topStep = i
			elseif count == 2 then
				if dat.passResumed then count = 1
				else
					if dat.resumedTime <= 0 and not dat.blockResumed then
						self._rSectionIndexMap.lastStep = i
					end
					lastIndex = i
					break
				end
			end
		end
	end

	if self._justRevival then
		self:setPropUnavailableExternalReason( UBFPropUnitType.kRevert , UBFPropUnavailableReason.kCannotRevert )
	else
		local hasLastStep = self._rSectionIndexMap.lastStep
		if not hasLastStep then
			local dat = self._rSectionList[lastIndex - 1]
			local isResumed = dat and dat.resumedTime > 0 or false
			self:setPropUnavailableExternalReason( UBFPropUnitType.kRevert,
				isResumed and UBFPropUnavailableReason.kCannotRevertContinuity or UBFPropUnavailableReason.kCannotRevert
			)
		else
			self:setPropUnavailableExternalReason( UBFPropUnitType.kRevert , nil )
		end
	end
end

function UBFGameSceneManager:onRemoveSection( id )
	for k , dat in ipairs( self._rSectionList ) do
		if dat.id == id then
			table.remove( self._rSectionList , k )
			break
		end
	end
	self:_refreshSectionIndexMap()
end

function UBFGameSceneManager:_takeBoardViewSection()
	local section = {}
	local msgClient = self:getMessageLogic()
	msgClient:ergodicBoardViewLogic(function(v, id)
		section[id] = UBFHelper:deepClone(v.tileSaveableCache)
	end)
	return section
end

function UBFGameSceneManager:_resumeBoardViewSection(section)
	if not section then return end
	local msgClient = self:getMessageLogic()
	msgClient:ergodicBoardViewLogic(function(v, id)
		self:_resumeBoardViewSectionByBoard(v, id, section)
	end)
end

function UBFGameSceneManager:_resumeBoardViewSectionByBoard(boardViewLogic, boardId, section)
	local usePendingSection = not section
	section = section or self._pendingResumeBoardViewData
	if not section or not boardViewLogic then return end

	boardId = boardId or 1
	if usePendingSection then
		self._pendingResumeBoardViewDataRestoredMap = self._pendingResumeBoardViewDataRestoredMap or {}
		if self._pendingResumeBoardViewDataRestoredMap[boardId] then return end
	end

	local tab = section[boardId] or section[tostring(boardId)] or {}
	boardViewLogic.tileSaveableCache = UBFHelper:deepClone(tab)
	for id, _ in pairs(tab) do
		boardViewLogic:updateViewState(id)
	end

	if usePendingSection then
		self._pendingResumeBoardViewDataRestoredMap[boardId] = true
	end
end

function UBFGameSceneManager:onTakeSection( id , stepCount )
	local isStepSection = stepCount and true or false

	if self._stepSectionLock then
		if isStepSection then return end
	end

	local dat = {
		id = id,
		byStep = isStepSection, --是否通过走一步的断面
		resumedTime = 0,
		blockResumed = false,
		passResumed = false,
		timeStatistic = self:getMessageLogic():serializeTimeStatistic(),
		boardViewData = self:_takeBoardViewSection(),
	}

	if _G.UBF_NO_SECTION_MODE and self:_isReplayResume() then
		-- 这玩意要作为闪退恢复结算用，不能不要了
		local moduleData = self:serializeAllModule(isStepSection and UBFSerializeSource.kRevert or UBFSerializeSource.kNormal )
		dat.moduleData = UBFHelper:toList(moduleData, function(data)
			if data.id == UBFGameLogics.kGameMod then
				data.dat = UBFHelper:toList(data.dat, function(mod)
					if mod.actData and mod.actData.foresume then
						return mod
					end
				end)
				return data
			end
		end)
	else
		dat.moduleData = self:serializeAllModule(isStepSection and UBFSerializeSource.kRevert or UBFSerializeSource.kNormal )
	end
	dat.sceneData = UBFHelper:deepClone(self._sceneData)

	if isStepSection then
		dat.propRememberList = {}		--记录道具的使用情况，用于后退一步加回来，棋盘逻辑不关心
	end
	table.insert(self._rSectionList, dat)
	self:_refreshSectionIndexMap()

	if self._sectionNeedSave and not self:isInReplay() then
		if self:_isOnlyOnceWrite() then
			if self._lastReplaySectionSaved then return end
			self._lastReplaySectionSaved = true
		end
		self._lastSaveedSectionId = id
		self._lastSavedSectionExtra = {}
		self._lastSavedSectionExtra.id = self._lastSaveedSectionId
		self:getMessageLogic():sendMessage({
			mType = UBFGameMessageType.kSaveSection,
			sectionId = id,
			replayMode = self:_isReplayResume(),
			files = {
				section = "data_caches/" .. UBFSectionResumeHelper.LAST_LOGIC_SECTION_NAME_TMP,
				info = "data_caches/" .. UBFSectionResumeHelper.LAST_SECTION_INFO_NAME_TMP,
			}
		})
	end
end

function UBFGameSceneManager:_isReplayResume()
	return _G.USE_REPLAY_RESUME
		and not self:isInRust()
end

function UBFGameSceneManager:_isOnlyOnceWrite()
	return EnvUtil:isMiniGame()
end

function UBFGameSceneManager:onReumeSection( id )
	local section = self:getSection( id )
	if not section then return end
	section.resumedTime = section.resumedTime + 1
	for i = #self._rSectionList , 1 , -1 do
		local dat = self._rSectionList[i]
		if dat.id == id then break end
		dat.blockResumed = true
	end
	self:_refreshSectionIndexMap()

	local pworth = self._sceneData.pworth
	self._sceneData = UBFHelper:deepClone(section.sceneData)
	self._sceneData.pworth = pworth
	self:_resumeBoardViewSection(section.boardViewData)

	local src = section.byStep and UBFSerializeSource.kRevert or UBFSerializeSource.kNormal

	local stepUnit = self:callGameModule( UBFGameLogics.kTally , "getTallyUnit" ,  UBFTallyId.kMoveStep )
	local moveCountWithRevert = stepUnit and stepUnit:getValue( UBFTallyValueType.kMoveCountWithRevert ) or 0

	self:deserializeAllModule( table.clone(section.moduleData) , src )
	self:onResumed( src )

	if stepUnit then stepUnit:setValue( moveCountWithRevert , UBFTallyValueType.kMoveCountWithRevert ) end

	--恢复道具
	local list = section.propRememberList or {}
	for k , v in ipairs( list ) do
		local usePropType = v.usePropType
		if v.propUnitType ~= UBFPropUnitType.kRevert and v.usePropType ~= UsePropsType.TEMP then
			UBFGamePropbility:_revertItem( v.propId , v.expireTime , v.usePropType  )
			if v.pworth then
				local PropWorthTest = require "ubf.UBFGamePlayScene.logics.mess.PropWorthTest"
				local pworth = self._sceneData.pworth
				self._sceneData.pworth = PropWorthTest:sub(pworth, v.pworth)
			end
			break
		end
	end

	self:callGameModule( UBFGameLogics.kCollectionBar , "revertAllNum" )

	self:call("onRevert")
	UBFGamePlaySceneMess:checkAndSetPropState( self )
end

function UBFGameSceneManager:getSection( id )
	for i = #self._rSectionList , 1 , -1 do
		local dat = self._rSectionList[i]
		if dat.id == id then
			return dat
		end
	end
end

function UBFGameSceneManager:getLastStepSection()
	return self._rSectionIndexMap.lastStep and self._rSectionList[self._rSectionIndexMap.lastStep] or nil
end

function UBFGameSceneManager:getTopStepSection()
	return self._rSectionIndexMap.topStep and self._rSectionList[self._rSectionIndexMap.topStep] or nil
end

function UBFGameSceneManager:onAddTempProp( propList , info )
	local boardViewLogic = self:getBoardViewLogic()

	local source = info.source
	local levelInfo = self:getLevelInfo()
	local scene = self:getScene()

	if not EnvUtil:isMiniGame() then
		if source == "auto_revert" then
	        local tip = CommonTip:showTip("棋盘没有可交换位置，\n即将为您免费后退一步")
			tip.blockTouch = function() return true end
			self:callGameModule( UBFGameLogics.kPropBar , "setLock" , true )
			setNextFrame(
				function()
					self:flushLastSectionExtra( { waitAutoRevert = true } )
				end
			)
			setTimeOut(function()
				local itemId = UBFPropUnitTypeToTempItemIdMap[UBFPropUnitType.kRevert] or PropMappingForOld.PropUnitTypeToPropIdMap[UBFPropUnitType.kRevert]
				self:callGameModule(
					UBFGameLogics.kPropBar , "addTemporaryProp" ,
					UBFPropUnitType.kRevert , itemId ,
					1 , false
				)
				self:callGameModule( UBFGameLogics.kPropBar , "useProp" ,  UBFPropUnitType.kRevert )
				self:callGameModule( UBFGameLogics.kPropBar , "setLock" , false )
			end,2)
			DcUtil:log(AcType.kExpire30Days, {
				category = "in_level",
				sub_category = "auto_revert",
				playid = self:getPlayId(),
			})
	        he_log_error(string.format("auto_revert:levelId=%s,playId=%s",levelInfo.levelId,self:getPlayId()))
			return
		end
	end

	if self:isInWonderfulReplay() then return end
	lua_switch(source){
		--引导
		["Guide"] = function ( ... )
			local event = UBFSceneModEventMap[UBFGameModEventEnum.kFreeProp]:create {
				propList = propList,
				guide = true,
				levelId = levelInfo.levelId,
			}
			self:notifyModEvent(event)
		end,
		--礼盒
		["Gift"] = function ( ... )
			local gridPos = info.gridPos
			local fromAxis = nil
			if gridPos then
				local x,y = boardViewLogic:getGridAxisOffsetInUIWorldPos(gridPos)
				fromAxis = {x = x,y = y}
			end


			for k , v in ipairs( propList ) do
				local itemId = UBFPropUnitTypeToTempItemIdMap[v.propUnitType] or PropMappingForOld.PropUnitTypeToPropIdMap[v.propUnitType]

				-- local http = OpenGiftBlockerHttp.new()
				-- http:addEventListener( Events.kComplete, function()

					self:callGameModule(
						UBFGameLogics.kPropBar , "addTemporaryProp" ,
						v.propUnitType , itemId ,
						v.count , false , { passUpdateState = true }
					)

					scene:flyAddTempProp( v.propUnitType , fromAxis , function()
						self:callGameModule( UBFGameLogics.kPropBar , "updateState" ,  v.propUnitType )
					end )

				-- end )

				-- local itemList = {}
				-- for i = 1 , v.count do table.insert( itemList , itemId ) end
				-- http:load( levelInfo.levelId, itemList, levelInfo.levelScene )
			end

			if UBFPlaySwitch:guideConvered(levelInfo.levelId) then
				local event = UBFSceneModEventMap[UBFGameModEventEnum.kFreeProp]:create {
					propList = propList,
					guide = true,
					onlyTip = true,
					levelId = levelInfo.levelId,
				}
				self:notifyModEvent(event)
			else
				self:runFakeCall(function()
					self:getFakeNewGamePlaySceneUI():onGetItem("gift")
				end)
			end
		end
	}

end

function UBFGameSceneManager:flushLastSectionExtra( data )
	if self:_isReplayResume() then return end
	if self._lastSavedSectionExtra then
		UBFHelper:shallowMerge( self._lastSavedSectionExtra , data )
		UBFSectionResumeHelper:saveClientExtraSection( self._lastSavedSectionExtra )
		--
--

	end
end

--------------------****** *↓* ******--------------------
--						其他当XXXX时
--------------------****** *↑* ******--------------------

function UBFGameSceneManager:onBoardViewLogicBuild()
	self:getScene():doLayoutScene()
	self:getScene():doLayoutBoard()
	self:_refreshOctopusFrozen()


	local event = UBFSceneModEventMap[UBFGameModEventEnum.kAfterBoardViewLogicBuild]:create({})
	self:notifyModEvent(event)

	if MetricsCollector then
		setTimeOut(function ()
			MetricsCollector:getInstance():beginSample(MetricsCollector_Scene.Level)
		end, 1)
	end
end

function UBFGameSceneManager:onBoardViewExtendBuild()
end

function UBFGameSceneManager:onBoardViewExtendBuildFinish()
	self:_refreshOctopusFrozen()
end

function UBFGameSceneManager:onUseOctopusForzen(tile, onEndCallback)
	local boardViewLogic = self:getBoardViewLogic()
	local x , y = boardViewLogic:getGridAxisOffsetInUIWorldPos(tile)

	local fromPos = ccp(0,0)

	local barModel = self:getGameModule( UBFGameLogics.kPropBar )
	if barModel then
		local rect = barModel:call( "getBubbleContainerValueRectInWorld" , UBFPropUnitType.kOctopusFrozen , true )
		if rect then
			fromPos = ccp(rect.x,rect.y)
		end
	end

	local scene = self:getScene()
    local FallingStar = require "ubf.UBFGamePlayScene.views.utils.FallingStar"
	local flyTo = FallingStar:create(fromPos, ccp(x,y), nil, onEndCallback)
	scene.effectLayer:addChild(flyTo)
end

function UBFGameSceneManager:_refreshOctopusFrozen()
	local boardViewLogic = self:getBoardViewLogic()
	local hasOctopusLock = true
	if boardViewLogic then
		local list = boardViewLogic:getTilesListByItemType(UBFGameItemType.kOctopus)
		local hasOctopus = list and #list > 0
		if hasOctopus then
			local viewLogic = boardViewLogic:getTileViewLogic(UBFGameItemType.kOctopus)
			for _, tile in pairs(list) do
				-- local valid = UBFHelper:invoke(viewLogic, "checkOctopusValid", tile)
				local valid = UBFGamePlaySceneMess:checkOctopusValid(boardViewLogic, tile)
				if valid then
					hasOctopusLock = false
					break
				end
			end
		end
	end
	self:setPropUnavailableExternalReason(UBFPropUnitType.kOctopusFrozen, hasOctopusLock and UBFPropUnavailableReason.kHasNotOctopus or nil)
end

function UBFGameSceneManager:_doManualUpdateListByLimit(data, limitFrame)
	local frameIndex = 1
	local frameList = data.manualUpdateList
	local boardViewLogic = self:getBoardViewLogic(data.boardId)
	table.sort(frameList, function(a, b)
        if a.r ~= b.r then return a.r < b.r end
        return a.c < b.c
	end)
	local preCount = math.ceil(#frameList / limitFrame - 0.001)
	self:getScene():addTickFunc(function()
		local maxCount = preCount
		while frameIndex <= #frameList do
			local tile = frameList[frameIndex]
			boardViewLogic:updateViewState(tile.id)
			frameIndex = frameIndex + 1
			maxCount = maxCount - 1
			if maxCount == 0 then
				return true
			end
		end
		return false
	end)
end

function UBFGameSceneManager:_doManualUpdateList(data)
	if data.manualUpdateList then
		local manualUpdateParams = data.manualUpdateParams or {}
		if manualUpdateParams.limitFrame then return self:_doManualUpdateListByLimit(data, manualUpdateParams.limitFrame) end

		local frameIndex = 1
		local frameList = data.manualUpdateList
		local boardViewLogic = self:getBoardViewLogic(data.boardId)
		table.sort(frameList, function(a, b)
            if a.r ~= b.r then return a.r < b.r end
            return a.c < b.c
        end)
		self:getScene():addTickFunc(function()
			local currR
			local currMax = 20
			if EnvUtil:isUnity() then
				local stepCount = math.ceil(#frameList / 3)
				if stepCount < 50 then
					stepCount = 50
				end
				currMax = stepCount
			end

			while frameIndex <= #frameList do
				local tile = frameList[frameIndex]
				boardViewLogic:updateViewState(tile.id)
				frameIndex = frameIndex + 1
				currMax = currMax - 1
				if boardViewLogic:isGridInViewport(tile) and not EnvUtil:isUnity() then
				elseif currR == nil then currR = tile.r
				elseif currR ~= tile.r or currMax <= 0 then
					return true
				end
			end
			if EnvUtil:isUnity() then
				self:getScene():releaseCreateTileLoadingController()
			end
			return false
		end)
	else
		self:getScene():releaseCreateTileLoadingController()
	end
end

function UBFGameSceneManager:onBoardViewLogicBuildLaunch(data)
	self.onBoardReadyPromise:resolve()
	--
--
--
--


	--逐帧加载
	self:_doManualUpdateList(data)

	if EnvUtil:isUnity() and self.switchWaitAnimation then
		local swa = self.switchWaitAnimation
		self:addDelayFunc(10, function() self:_onGameSwitchPlayAnimation(swa) end)
		self.switchWaitAnimation = nil
		return
	end

	local boardViewLogic = self:getBoardViewLogic()

	if self.switchWaitAnimation then
		local swa = self.switchWaitAnimation
		local newBoardViewLogic = swa.newBoardViewLogic
		newBoardViewLogic.sceneLogicView:setVisible(false)
		self:addDelayFunc(10, function()
			newBoardViewLogic.sceneLogicView:setVisible(true)
			self:_onGameSwitchPlayAnimation(swa)
		end)
		self.switchWaitAnimation = nil
		return
	end

    boardViewLogic:updateViewport(UBFHelper:shallowClone(boardViewLogic:getGridLogicViewport()))

	local logicShowViewport = boardViewLogic:getGridLogicShowViewport()
	local viewport = boardViewLogic:getGridViewport()

	if logicShowViewport and (logicShowViewport.left < viewport.left
		or logicShowViewport.right > viewport.right
		or logicShowViewport.top < viewport.top
		or logicShowViewport.bottom > viewport.bottom)
	then
		--只兼容挖地关
		if logicShowViewport.right <= 9 and logicShowViewport.bottom > 3 then

			local width , height = UBFBigBoardHelper:getWHFromRect( viewport )

			local useBottom = logicShowViewport.realBottom or logicShowViewport.bottom
			local startTop = useBottom - height + 1

			local toViewport = {
				left = viewport.left ,
				right = viewport.right,
				top = startTop,
				bottom = startTop + height - 1
			}

			boardViewLogic:updateViewport( toViewport )

			self:getScene():pushStartAnimeHandler( function( done )

				local logicViewport = boardViewLogic:getGridLogicViewport()
				local length = startTop - logicViewport.top

				local tick = 0
				local dTick = 1
				local totalTick = math.max( 10 , length * 10 )
				if not self:getScene() then
					local levelInfo = self:getLevelInfo()
					local levelId = levelInfo and levelInfo.levelId
					if he_log_error then he_log_error("[UBFGameSceneManager] pushStartAnimeHandler error : scene is nil, levelId:"..tostring(levelId)) end
					done()
					return
				end
				local layer = UBFLayer:create()
				self:getScene():addChild( layer )

				layer:setTouchEnabled( true , -99 , true , function()
					dTick = 5
					return true
				end)

				self:getScene():addTickFunc(function()
					tick = math.min( tick + dTick , totalTick )
					local r = tick / totalTick

					local viewport = boardViewLogic:getGridViewport()

					local top = logicViewport.top * r + startTop * (1 - r)

					local toViewport = {
						left = viewport.left ,
						right = viewport.right,
						top = top,
						bottom = top + height - 1,
					}

					boardViewLogic:updateViewport( toViewport )

					if tick >= totalTick then
						layer:removeFromParentAndCleanup( true )
						setNextFrame(function()
							boardViewLogic:setViewBorderToLogicViewport()
							boardViewLogic:cropLogicViewport()
							self:_refreshOctopusFrozen()
							done()
						end)
						return false
					end
					return true
				end)
			end , function() boardViewLogic:cropLogicViewport() end , 10, "updateViewport" )
		else
			boardViewLogic:cropLogicViewport()
		end
	else
		-- 超大棋盘
		if viewport.right > 9 then 
			local height = viewport.right - viewport.left + 1
			local width = viewport.bottom - viewport.top + 1
			if self.widescreenAdaption and self.widescreenAdaption.boardViewScale then 
				self.widescreenAdaption.boardViewScale = 
					self.widescreenAdaption.boardViewScale / math.max(height, width) * 9
			end
			boardViewLogic:updateLogicShowViewport(nil)
			self:getScene()._custom_base_board_size_ = {
				r = height,
				c = width
			}
			self:getScene():refreshGlobalLayoutData()
			self:getScene():doLayoutScene()
			self:getScene():doLayoutBoard()
		end
	end
end

-- function UBFGameSceneManager:onBeforeSwap( from , to )
-- 	--兼容逻辑
-- 	local promise
-- 	self:runFakeCall(function()
-- 		promise = OldGameGuideBridge:onBeforeSwap( self , from , to )
-- 	end)
-- 	return promise
-- end

function UBFGameSceneManager:onSwapAnimation(from, to, datas)
	local levelInfo = self:getLevelInfo()
	local levelId = levelInfo.levelId

	if UBFPlaySwitch:guideConvered(levelId) then
		local event = UBFSceneModEventMap[UBFGameModEventEnum.kItemSwap]:create {
			from = from,
			to = to,
			tileAIds = datas.tileAIds,
			tileBIds = datas.tileBIds,
		}
		self:notifyModEvent( event )
		self:runFakeCall(function ( ... )
			local repeatGuideBtn = self:getFakeNewGamePlaySceneUI().repeatGuideBtn
			if repeatGuideBtn then
				repeatGuideBtn:removeSelf()
			end
		end)
	end

	local boardViewLogic = self:getBoardViewLogic()
	local commonHapticsLogic = boardViewLogic:getExtendLogic(UBFBoardViewExtendLogics.kCommonAnimHaptics )
	if commonHapticsLogic then
		commonHapticsLogic:onSwap(from, to, datas)
	end
end

function UBFGameSceneManager:onSwapAction( from, to )
	local event = UBFSceneModEventMap[UBFGameModEventEnum.kItemSwapAction]:create {
		from = from,
		to = to,
	}
	self:notifyModEvent( event )
end

function UBFGameSceneManager:onBeforeWonderfulReplayOperation( opData )

	if self:isInPause() then
		return self:addPauseResumeCallback(function()
			return self:onBeforeWonderfulReplayOperation(opData)
		end)
	end

	local opType = opData.opType
	local opParams = opData.opParams
	if opType == UBFOperationType.kSwap then
		local from = { r = opParams.r , c = opParams.c }
		local to = { r = opParams.tr , c = opParams.tc }

		local boardViewLogic = self:getBoardViewLogic()

		local fx , fy = boardViewLogic:getGridAxisOffsetInUIWorldPos( from )
		local tx , ty = boardViewLogic:getGridAxisOffsetInUIWorldPos( to )

		local scene = self:getScene()
		local hand
		if _G.editorMode and _G.__ALE_EDITOR_REPLAY__ then
			hand = GameGuideAnims:handslideAnimForAleEditor(ccp(fx,fy), ccp(tx,ty))
		else
			hand = GameGuideAnims:handslideAnim(ccp(fx,fy), ccp(tx,ty))
		end
		hand:runAction(UBFViewHelper:sequence{
			CCDelayTime:create( 4 ),
			CCCallFunc:create(function() hand:removeFromParentAndCleanup(true) end)
		})
		scene.effectLayer:addChild(hand)
		local delay = EnvUtil:isUnity() and 1 or 2.5
		return self:createDelayPromise( 60 * delay )
	elseif opType == UBFOperationType.kProp then
		local propUnitType = opParams.propUnitType
		local points = opParams.points

		local barModel = self:getGameModule( UBFGameLogics.kPropBar )
		if not barModel then return end

		local rect = barModel:call( "getBubbleContainerValueRectInWorld" , propUnitType , true )
		if not rect then return  end

		local defaultOffsetX = EnvUtil:isUnity() and 100 or 0
		local offsetX = self:callGameModule( UBFGameLogics.kPropBar , "locateToBubble" , propUnitType ) or defaultOffsetX
		local centerPos = ccp( rect.x  + offsetX , rect.y )

		local boardViewLogic = self:getBoardViewLogic()
		local function getPos( index )
			if not points then return end
			if not points[index] then return end
			local x , y = boardViewLogic:getGridAxisOffsetInUIWorldPos( points[index] )
			return ccp(x , y)
		end

		local from = getPos( 1 ) or centerPos
		local to = getPos( 2 ) or from or centerPos

		local scene = self:getScene()
		local hand = GameGuideAnims:handUsePropAnim( centerPos , from , to , 1 )
		scene.effectLayer:addChild(hand)
		if EnvUtil:isUnity() then
			local icon = PropMappingForOld.CreatePropUnitTypeDefaultIcon( opParams.propUnitType )
			if icon and hand then
				hand:addChild(icon)
				icon:runAction(UBFViewHelper:sequence{
					CCDelayTime:create(3),
					CCCallFunc:create(function() icon:removeFromParentAndCleanup(true) end)
				})
			end
		end
		local promise = self:createDelayPromise( 60 * 3 )
		promise:next(function()
			local propBubble = self:callGameModule( UBFGameLogics.kPropBar , "getPropBubble" , propUnitType )
			if propBubble then
				propBubble:getPropUnit():useFirstStack()
				self:callGameModule( UBFGameLogics.kPropBar , "updateState" , propUnitType )
			end
		end)

		return promise
	end
end

function UBFGameSceneManager:onReplayOperation(opData)
	if not self:isInReplay() then return end

	local opType = opData.opType
	local opParams = opData.opParams

	if opType == UBFOperationType.kProp then
		local propUnitType = opParams.propUnitType
		local points = opParams.points
		local propBubble = self:callGameModule( UBFGameLogics.kPropBar , "getPropBubble" , propUnitType )
		if propBubble then
			if opParams.propUseType == UBFPropUseType.kTemp then
				propBubble:getPropUnit():useFirstStack()
			else
				propBubble:onUseProp(propBubble:getFirstUseStack())
			end
			self:callGameModule( UBFGameLogics.kPropBar , "updateState" , propUnitType )
		end
		-- 加入 prop 记录，方便后退
		self._lastReplayProp = opParams
	end
end

function UBFGameSceneManager:onPropNeedRefresh( propUnitType )
	local propsDataMap = UBFGamePlaySceneMess:getUBFPropsDataMap( self:getLeveJsonData() , self:isDebugPlayMode(), self.so_rust)
	local props = propsDataMap[propUnitType] and propsDataMap[propUnitType].props
	self:callGameModule( UBFGameLogics.kPropBar , "reloadProps" , propUnitType , props )
end

function UBFGameSceneManager:onStoreShopClosed()
	local propsDataMap = UBFGamePlaySceneMess:getUBFPropsDataMap( self:getLeveJsonData() , self:isDebugPlayMode(), self.so_rust)
	for propUnitType, propsData in pairs( propsDataMap ) do
		self:callGameModule( UBFGameLogics.kPropBar , "reloadProps" , propUnitType , propsData.props )
	end
end

-- function UBFGameSceneManager:onScreenExpandChanged()
-- 	local scene = self:getScene()
-- 	if (not scene) or scene.isDisposed then return end

-- 	scene:refreshGlobalLayoutData()
-- 	scene:doLayoutScene()
-- 	scene:doLayoutBoard()
-- 	local event = UBFSceneModEventMap[UBFGameModEventEnum.kSceneExtend]:create()
-- 	self:notifyModEvent( event )
-- end

function UBFGameSceneManager:getGameSnapshotData()
	return self._gameSnapshotData
end

function UBFGameSceneManager:onCatchStep(stepState)
	local gameSnapshotData = self:getGameSnapshotData()
	if not gameSnapshotData then return end

	table.insert(gameSnapshotData.gameStates, stepState)
	gameSnapshotData.finalScore = stepState.curScore
	gameSnapshotData.realCostMove = stepState.curMoves
end

local function fixVal(val, stepState)
	local swapBorder = stepState.swapBorder
	if swapBorder then
		if val.x1 then val.x1 = val.x1 - swapBorder.left + 1 end
		if val.x2 then val.x2 = val.x2 - swapBorder.left + 1 end
		if val.y1 then val.y1 = val.y1 - swapBorder.top + 1 end
		if val.y2 then val.y2 = val.y2 - swapBorder.top + 1 end
	end
end

function UBFGameSceneManager:onCatchStepHook(key, val)
	local gameSnapshotData = self:getGameSnapshotData()
	if not gameSnapshotData then return end

	local gameStates = gameSnapshotData.gameStates
	local stepState = gameStates[#gameStates]
	if stepState then
		fixVal(val, stepState)
		stepState[key] = val
	end
end

function UBFGameSceneManager:onCatchStepHookList(key, val)
	local gameSnapshotData = self:getGameSnapshotData()
	if not gameSnapshotData then return end

	local gameStates = gameSnapshotData.gameStates
	local stepState = gameStates[#gameStates]
	if stepState then
		if not stepState[key] then stepState[key] = {} end
		table.insert(stepState[key], val)
	end
end

function UBFGameSceneManager:oEnterBonus()
	local gameSnapshotData = self:getGameSnapshotData()
	if not gameSnapshotData then return end
	local boardViewLogic = self:getBoardViewLogic()
	if boardViewLogic then
		boardViewLogic:notifyEvent(UBFGamePlaySceneEvents.kBonusPhase, {
			phase = UBFBonusPhase.kEnter,
			boardId = boardViewLogic.boardId or 1,
		})
	end
	local gameStates = gameSnapshotData.gameStates
	table.remove(gameStates, #gameStates)

	self._isEnterBonus = true
	self:addDelayFunc(30, function() self:rustTryPushClosure() end)
end

function UBFGameSceneManager:notifyEvent( event , data )
	if self.moduleNotifyEventHanlderMap[event] then
		self.moduleNotifyEventHanlderMap[event]( data )
	end
end

function UBFGameSceneManager:notifyModEvent( event , data )
	UBFDebug.game_lag_log("push", "notify_mod_event", event:getEventName())
	self:callGameModule( UBFGameLogics.kGameMod , "notifyEvent" , event )
	self:callGameModule( UBFGameLogics.kBgFg, "notifyEvent" , event )
	self:callGameModule( UBFGameLogics.KInformationFlowDesign , "notifyEvent" , event )
	self:callGameModule( UBFGameLogics.kScore , "notifyEvent" , event )
	UBFDebug.game_lag_log("pop", "notify_mod_event")
end

--当复活
function UBFGameSceneManager:onRevival( datas )
	if self._sceneRuntimeData.addStep then
		local addStep = self._sceneRuntimeData.addStep
		local closePromise = addStep.closePromise
		UBFHelper:invoke( addStep.logic , "forceClose" )
		closePromise:next(function()
			local layer = self:getFlyObjectLayer( UBFGameFlyTypes.kEffect )
			UBFGamePlaySceneMess:flyAddStepProp( layer , addStep.propId , {
				onAnimeFinish = function()
					self:callGameModule( UBFGameLogics.kStep , "updateCurrStepVal" ,  nil )
				end,
				customParams = addStep.usePropParams
			}, datas)
		end)

		local stepCount = datas.stepCount
		if stepCount then
			self:callGameModule( UBFGameLogics.kTally , "setTally" ,  UBFTallyId.kMoveStep , stepCount )
		end
	else
		pcall(function()
			local stepCount = datas.stepCount
			if stepCount then
				self:callGameModule( UBFGameLogics.kTally , "setTally" ,  UBFTallyId.kMoveStep , stepCount )
				self:callGameModule( UBFGameLogics.kStep , "updateCurrStepVal" ,  nil, nil, nil, true )	--不要滚动动画
			end
		end)
	end
end

--当牌面发生变化
function UBFGameSceneManager:onBoardStateChange(stateKey, oldVal, newVal, boardId)
	if stateKey == UBFBoardStateKey.kSMKey then
		UBFDebug.game_lag_log("push", "board_state_change", tostring(oldVal) .. ">" .. tostring(newVal))
		self._justRevival = false
		if newVal == UBFConst.BoardSMKey.kWating then
			self._fuuuInfoCache = nil
		end
		local event = UBFSceneModEventMap[UBFGameModEventEnum.kBoardStateChange]:create {
			oldVal = oldVal,
			newVal = newVal,
			boardId = boardId,
		}
		self:notifyModEvent(event)

		if boardId ~= 1 then
			UBFDebug.game_lag_log("pop", "board_state_change")
			return
		end

		self._boardState = newVal
		self:getSceneData().boardState = newVal
		self:callGameModule( UBFGameLogics.kPropBar , "setLock" , true )
		if newVal == UBFConst.BoardSMKey.kWating then
			self:onBoardEnterWaiting()
		elseif oldVal == UBFConst.BoardSMKey.kInit then
			-- self._fake_from_init_flag_ = true
		end
		UBFDebug.game_lag_log("pop", "board_state_change")
	end
end

function UBFGameSceneManager:getBoardState( ... )
	return self._boardState
end



function UBFGameSceneManager:onBoardEnterWaiting()
	UBFDebug.game_lag_log("push", "board_enter_waiting")
	if not self._replayResumeLevelRuntime 
		and self._prophet_config_ 
	then 
		self:_try_push_prophet()
	end

	UBFDebug.game_lag_log("push", "waiting_collection_bar")
	self:callGameModule( UBFGameLogics.kPropBar , "setLock" , false )
	-- if not self.isCollectionBarFirstUpdate then
	-- 	self.isCollectionBarFirstUpdate = true
	-- 	self:callGameModule(UBFGameLogics.kCollectionBar, "revertAllNum" )
	-- else
		-- 收集栏重构初始化的revert整合到入场里了，只需要在这个分支处理
		local uiMgr = UBFGlobal:getLogic(UBFUiLogicId.UI_VIEW_LOGIC_MANAGER)
		local _ = uiMgr and uiMgr:exeOp(UBFCollectionBarOpType.UPDATE_NUM, {
			showDiff = true
		})
		self:callGameModule(UBFGameLogics.kCollectionBar, "updateAll" )
	-- end
	UBFDebug.game_lag_log("pop", "waiting_collection_bar")

	local sceneData = self:getSceneData()
	local combo = sceneData.combo
	sceneData.combo = 0

	if sceneData.playState == UBFGamePlayState.kRun then
		UBFDebug.game_lag_log("push", "waiting_combo_effect", combo)
		local boardViewLogic = self:getBoardViewLogic()
		if boardViewLogic then
			boardViewLogic:notifyEvent(UBFGamePlaySceneEvents.kComboPhase, {
				phase = UBFComboPhase.kSettle,
				comboCount = combo,
				boardId = boardViewLogic.boardId or 1,
			})
		end

		local scene = self:getScene()
		UBFGamePlaySceneMess:playComboEffect( scene.effectLayer , combo )
		UBFDebug.game_lag_log("pop", "waiting_combo_effect")
	end

	self:_refreshOctopusFrozen()

	UBFDebug.game_lag_log("push", "waiting_feature_notify")
	pcall(function()
		local levelInfo = self:getLevelInfo()
		local sceneData1 = self:getSceneData()
		local tallyUnit = self:callGameModule(UBFGameLogics.kTally, "getTallyUnit", UBFTallyId.kMoveStep)
        local remainStep = tallyUnit and tallyUnit:getValue() or sceneData1.currMoveCount or 0

		_G.amfEC:notifyFeature(FeatureEvent.UBF_STEP_CHANGE, {
			levelType = levelInfo.levelType,
			remainStep = remainStep,
		})
	end)
	UBFDebug.game_lag_log("pop", "waiting_feature_notify")

	-- if EnvUtil:isMiniGame() then
	-- 	local gcFunc = EnvUtil:isMiniGameIOS() and CS.He.Global.TriggerFullGC or CS.He.Global.TriggerGC
	-- 	setTimeOut(function()
	-- 		gcFunc()
	-- 	end, 3/60)
	-- else
	-- 	--低端机型棋盘稳定时gc一次
	-- 	if _G.__isLowDevice then
	-- 		collectgarbage("collect")
	-- 	end
	-- end

	-- debug refresh
	-- pcall(function()

	-- 	local boardViewLogic = self:getBoardViewLogic()
	-- 	local list = boardViewLogic:getTilesListByItemType( UBFGameItemType.kAnimal )

	-- 	for _ , tile in ipairs( list or {} ) do
	-- 		local logicView = boardViewLogic:getBoardElement( tile , "main" )
	-- 		local oldStateTable = logicView and logicView.stateTable or nil
	-- 		if oldStateTable then
	-- 			local tileData = tile.tileData
	-- 			if tileData.color ~= oldStateTable.color then
	-- 				if __WIN32 then
	-- 					UBFError("shit!!!!" .. tile.r .. "_" .. tile.c .. " == " .. tostring(tileData.color) .. "_" .. tostring(oldStateTable.color) )
	-- 				else
	-- 					he_log_error(
	-- 						"why animal color is abnormal ? old color "
	-- 							.. tostring(oldStateTable.color)
	-- 							.. " new color"
	-- 							.. tostring(tileData.color)
	-- 						)
	-- 					boardViewLogic:updateViewState( tile.id )
	-- 				end

	-- 			end
	-- 		end
	-- 	end

	-- end)

	--
--
--
--

	UBFDebug.game_lag_log("pop", "board_enter_waiting")
end


function UBFGameSceneManager:onCombo( count )
	local sceneData = self:getSceneData()
	sceneData.combo = sceneData.combo + 1

	local boardViewLogic = self:getBoardViewLogic()
	if boardViewLogic then
		boardViewLogic:notifyEvent(UBFGamePlaySceneEvents.kComboPhase, {
			phase = UBFComboPhase.kMatch,
			comboCount = count or sceneData.combo,
			boardId = boardViewLogic.boardId or 1,
		})
	end

	local ts = sceneData.combo
	if ts > 8 then ts = 8 end
	UBFAudioManager:playSound(UBFAudioKey["kEliminate_" .. ts])
end

function UBFGameSceneManager:onUseProp(data)

	local levelInfo = self:getLevelInfo()
	if not levelInfo.usePropList then levelInfo.usePropList = {} end
	table.insert(levelInfo.usePropList, data)

	local sceneData = self:getSceneData()
	local PropWorthTest = require "ubf.UBFGamePlayScene.logics.mess.PropWorthTest"
	local pworth = PropWorthTest:calc(data)
	if pworth then
		data.pworth = pworth
		sceneData.pworth = PropWorthTest:add(sceneData.pworth, pworth)
	end

	local tallyUnit = self:callGameModule(UBFGameLogics.kTally, "getTallyUnit", UBFTallyId.kMoveStep)
	data.idx = tallyUnit and tallyUnit:getValue( UBFTallyValueType.kMoveCountWithRevert ) or 0
	data.theCurMoves = tallyUnit and tallyUnit:getValue() or 0

	--前置道具返回
	if data.isPreprop then return end

	if self:_isOnlyOnceWrite() then self._lastReplaySectionSaved = nil end

	if data.usePropType == UsePropsType.NORMAL or data.usePropType == UsePropsType.EXPIRE then
		levelInfo.usePropCount = ( levelInfo.usePropCount or 0 ) + 1
	end

	local sectionDat = self:getTopStepSection()
	if sectionDat then
		table.insert(sectionDat.propRememberList, data)
		if data.isRevival then
			-- sectionDat.passResumed = true
			sectionDat.blockResumed = true
		end
	end
	if data.isRevival and not EnvUtil:isMiniGame() then
		self._justRevival = true
		self:_refreshSectionIndexMap()
	end

	if data.points then
		local datas = { prop = data.propId, pt = data.usePropType }
		for i = 1, #data.points do
			local point = data.points[i]
			datas["y" .. i] = point.r
			datas["x" .. i] = point.c
		end
		self:onCatchStepHook("propAction", datas)
	end

	local event = UBFSceneModEventMap[UBFGameModEventEnum.kPropUseOriginal]:create {
		success = true,
		params = {
			points = data.points,
			checkPropUnitType = data.propUnitType,
			propId = data.propId,
			usePropType = data.usePropType,
		},
	}
	self:notifyModEvent(event)
end

function UBFGameSceneManager:onBuyProp(data)

end

function UBFGameSceneManager:onLogicClosure()
	self:call("onLogicClosure")
	if not self.endLevelData then
		self:onGameOver({
			isCrash = true,
			crashMsg = tostring("logic cloure before game over!!!"),
			source = "msg",
			unexpectedLogicClosure = true,
		})
	end
end

function UBFGameSceneManager:onTick()
	if self.isDisposed then return end
	self.tick = self.tick + 1
	UBFDebug.game_lag_log("push", "scene_modules_tick")
	self:onTickUpdate()
	UBFDebug.game_lag_log("pop", "scene_modules_tick")
	UBFDebug.game_lag_log("push", "scene_logic_timeline")
	self._timeline:ergodicPrevious( self.tick , true , function( func ) func() end)
	UBFDebug.game_lag_log("pop", "scene_logic_timeline")
end

function UBFGameSceneManager:onScoreGet( info )
	local r , c = info.r , info.c
	if not r or not c then return end
	local addScore = info.addScore
	if not addScore then return end
	if r == 0 and c == 0 then return end
	local boardViewLogic = self:getBoardViewLogic()
	local x , y = boardViewLogic:getGridAxisOffsetInUIWorldPos( { r = r , c = c } )
	self:getScene():flyScore( ccp(x,y) , addScore , info )
end

function UBFGameSceneManager:isDailyLevelGameplay()
	local levelInfo = self:getLevelInfo()
	if levelInfo and levelInfo.levelScene == UBFLevelSceneType.kDailyLevelGameplay then return true end
	local levelJsonData = self:getCurLevelJsonData()
	return levelJsonData and levelJsonData.isGameMode and levelJsonData:isGameMode("DailyLevelGameplay")
end

function UBFGameSceneManager:onGameStateChange( datas )
	local newState = datas.state
	self:getSceneData().playState = newState

	if newState == UBFGamePlayState.kAlmostFail then
		self._lastReplaySectionSaved = nil
		if self:isDailyLevelGameplay() then
			if UBFGameSpeedManager:hasAnySpeedSwitchOn() then
				UBFGameSpeedManager:resuleDefaultSpeed()
			end
			self:sendAbandonLevelOperation(UBFOperationAbandonType.kGiveUp)
			return
		end
		if datas.fuuuDeviationResult then
			local deviation = datas.fuuuDeviationResult.deviation
			if deviation == deviation then
			else datas.fuuuDeviationResult = nil end
		end
		-- 更高优先级面板持有交互时暂存本次请求，供高优流程取消后恢复。
		if self:tryDeferScenePanel(UBFGameScenePanels.kAddStep, datas) then return end
		self:popoutScenePanel( UBFGameScenePanels.kAddStep , datas )
	elseif newState == UBFGamePlayState.kRun then
		self:onRevival( datas )
	elseif newState == UBFGamePlayState.kAlmostWin then
		if not datas.skipBonusTime then
			self:oEnterBonus()
		end
		self:callGameModule( UBFGameLogics.kBgFg , "setPauseButtonLock" , true )
    end
end

function UBFGameSceneManager:onAfterBuildBoardView(data)
	if self._updateBoardSectionRebuildFlag then
		self._updateBoardSectionRebuildFlag = nil
		local currUUID = self._sceneData.currUUID
		local levelConfig = UBFLevelConfigManager:getLevelConfigByUUID(currUUID)
		local toLevelJsonData = UBFLevelJsonData:create(table.deserialize(levelConfig))
		if data and data.segment then data.segment:await(self:_onGameSwitchToNewConfig(toLevelJsonData, true))
		else self:_onGameSwitchToNewConfig(toLevelJsonData, true) end
	end
end

function UBFGameSceneManager:onGameSwitch(datas)
	-- printx(16,tts(datas))
	local boardViewLogic = self:getBoardViewLogic()

	local extraData = datas.extraData

	local levelInfo = self:getLevelInfo()
	local levelConfig = UBFLevelConfigManager:getLevelConfigByUUID(datas.toUUID)
	local sceneData = self:getSceneData()
	sceneData.currUUID = datas.toUUID
	sceneData.currGameSwitchIndex = sceneData.currGameSwitchIndex + 1
	local toLevelJsonData = UBFLevelJsonData:create(table.deserialize(levelConfig))

	if extraData and extraData.endTick then
		self:getMessageLogic():holdRecvMessage()
		boardViewLogic:addFunctionToTimeline(extraData.endTick,function ( ... )
			self:_onGameSwitchToNewConfig(toLevelJsonData, false):next(function()
				self:getMessageLogic():releaseHoldRecvMessage()
			end)
		end)
	else
		self:getMessageLogic():holdRecvMessage()
		self:_onGameSwitchToNewConfig(toLevelJsonData, false):next(function()
			self:getMessageLogic():releaseHoldRecvMessage()
		end)
	end

end

function UBFGameSceneManager:resOnSwitch( oldLevelJsonData,newLevelJsonData )
	local UBFResUtils = require 'ubf.UBFPlay.logics.launch.UBFResUtils'
	local oldFeatureMap = oldLevelJsonData:getLevelFeatureMap()
	local newFeatureMap = newLevelJsonData:getLevelFeatureMap()
	local oldResKeys = UBFResUtils:getUnloadResByFeatureMap(oldFeatureMap, oldLevelJsonData)
	local newResKeys = UBFResUtils:getUnloadResByFeatureMap(newFeatureMap, newLevelJsonData)
	local removeResKeys = {}
	local loadResKeys = {}
	for k,v in pairs(oldResKeys) do
		if not newResKeys[k] then
			removeResKeys[k] = true
		end
	end

	for k,v in pairs(newResKeys) do
		if not oldResKeys[k] then
			loadResKeys[k] = true
		end
	end
	return table.keys(removeResKeys),table.keys(loadResKeys)
end


function UBFGameSceneManager:onBeforeSwitchBoard(  )
	local event = UBFSceneModEventMap[UBFGameModEventEnum.kBeforeSwitchBoard]:create({})
	self:notifyModEvent(event)
end

function UBFGameSceneManager:onAfterSwitchBoard(  )
	local event = UBFSceneModEventMap[UBFGameModEventEnum.kAfterSwitchBoard]:create({})
	self:notifyModEvent(event)
end

function UBFGameSceneManager:_onGameSwitchToNewConfig(levelJsonData, isResumed)

	self:onBeforeSwitchBoard()

	local levelInfo = self:getLevelInfo()
	local levelType = levelInfo.levelType
	local levelScene = levelInfo.levelScene
	local skinChangeMap = {}
	self:notifyModEvent(UBFSceneModEventMap[UBFGameModEventEnum.kModifyTileSkinRes]:create({
		skinChangeMap = skinChangeMap,
		levelType = levelType,
		levelScene = levelScene,
	}))
    local prepare = UBFGameSceneResourceMgr:prepareLevelResource(levelJsonData, skinChangeMap)
	local scene = self:getScene()
	local resMgr = scene.resMgr
	resMgr:setMainLevelPrepare(prepare)
	
	local segment = UBFPromise:segment()

	segment:retain()
	prepare:next(function( ... )
		segment:release()
	end)

	local featureManager = UBFBoardViewFeatureManager:create({
		levelJsonData = levelJsonData,
		isRust = self:isInRust(),
	})

	segment:retain()
	featureManager:loadFeaturesAsync():next(function()
		self:notifyModEvent(UBFSceneModEventMap[UBFGameModEventEnum.kModifyFeatureSkinRes]:create({
			featureManager = featureManager,
			levelType = levelType,
			levelScene = levelScene,
		}))
		local refMap = featureManager:calcResRef()
		local featurePrepareContext = resMgr:getMainLevelFeaturePrepareContext()
		refMap:doPrepare(featurePrepareContext)

		featurePrepareContext.primaryContainer:next(function()
			segment:release()
		end)
	end)

	segment:next(function()
		local boardId = 1
		local oldBoardViewLogic = self:getBoardViewLogic(boardId)
		self:removeBoardViewLogic(boardId)
		local scene = self:getScene()
		oldBoardViewLogic:clearAllViewAction()
		oldBoardViewLogic:resetCache()
		oldBoardViewLogic:setInteractor(UBFBoardInvalidInteractor:create())
		local _ = oldBoardViewLogic.toucher and oldBoardViewLogic.toucher:removeFromParent()

		scene:buildBoardView({
			initViewLogic = function(_, newBoardViewLogic)
				if newBoardViewLogic.boardId ~= boardId then return end
				local boardFeatureCreateMap = {}
				local Process = require 'ubf.UBFGamePlayScene.logics.processFlow.flowNode.UBFSLBeforeStartProcess'
				Process:addCreateDataToBoardFeatureCreateMapByFeatureMap(boardFeatureCreateMap, levelJsonData:getLevelFeatureMap(), featureManager)

				local event = UBFSceneModEventMap[UBFGameModEventEnum.kModifyBoardFeature]:create({
					boardFeatureCreateMap = boardFeatureCreateMap,
					levelType = levelType,
					levelScene = levelScene,
				})
				self:notifyModEvent(event)

				for itemType, createData in pairs(boardFeatureCreateMap) do
                    newBoardViewLogic:buildTileViewLogic(itemType, createData)
                end
				for itemType, viewLogic in pairs(oldBoardViewLogic.tileViewLogicMap) do
					if not newBoardViewLogic.tileViewLogicMap[itemType] and viewLogic.isMod then
						newBoardViewLogic:buildTileViewLogic(itemType, { _inst = viewLogic })
					end
				end
			end
		})

		if isResumed then
			oldBoardViewLogic:dispose()
			self:updatePause(-1)
			self:onAfterSwitchBoard()
			self._curLevelJsonData = levelJsonData
			return
		end

		self._rSectionList = {}
		self:_refreshSectionIndexMap()
		self:_refreshOctopusFrozen()

		self.switchGameWaitCallbacks = {
			function ( ... )
				resMgr:discardAllMinorLevelPrepare()
				self:callGameModule( UBFGameLogics.kPropBar , "resetPropUseTimes")
				self._stepSectionLock = false
				self._curLevelJsonData = levelJsonData
				UBFGamePlaySceneMess:checkAndSetPropState( self )
			end

		}
		self.switchWaitAnimation = {
			oldBoardViewLogic = oldBoardViewLogic,
			newBoardViewLogic = self:getBoardViewLogic(boardId)
		}

		self._stepSectionLock = true
	end)

	return segment:resolve()
end

function UBFGameSceneManager:_onGameSwitchPlayAnimation(switchWaitAnimation)
	local oldBoardViewLogic = switchWaitAnimation.oldBoardViewLogic
	local newBoardViewLogic = switchWaitAnimation.newBoardViewLogic

	local viewport = newBoardViewLogic:getGridViewport()
	local oldViewport = oldBoardViewLogic:getGridViewport()


	local w, h = UBFBigBoardHelper:getWHFromRect(viewport)
	local _, oldH = UBFBigBoardHelper:getWHFromRect(oldViewport)

	-- 手动指定一下h，因为新的viewport一定是默认的9x9
	-- 规则：切关不会改变viewport，如果改了这块也需要修改
	h = oldH
	newBoardViewLogic:updateViewBorder()

	newBoardViewLogic:setViewportClipping(true)
	oldBoardViewLogic:setViewportClipping(true)

	local logicViewport = newBoardViewLogic:getGridLogicViewport()


	-- printx(25, "oldViewport top "..oldViewport.top..", bottom "..oldViewport.bottom..", h "..oldH..", gridSize "..oldBoardViewLogic.gridSize)
	-- printx(25, "viewport top "..viewport.top..", bottom "..viewport.bottom..", h "..h..", gridSize "..newBoardViewLogic.gridSize)
	-- printx(25, "logicViewport top "..logicViewport.top)

	local gap = 1 + 8 / oldBoardViewLogic.gridSize.height

	local scrollH = oldH + gap
	local viewportMoveDirection = self:getScene():_dispatchSceneLogicLifecycleUntilHandled("getGameSwitchViewportMoveDirection") or 1
	local oldStartTop = oldViewport.top
	local oldEndTop = oldStartTop + viewportMoveDirection * scrollH

	local newEndTop = logicViewport.top
	local newStartTop = newEndTop - viewportMoveDirection * scrollH
	-- printx(25, "oldStartTop "..oldStartTop)
	-- printx(25, "newStartTop "..newStartTop)

	local tick = 0
	local dTick = 1
	local totalTick = 120
	local function onFinish()
		self:onAfterSwitchBoard()
		oldBoardViewLogic:beforeDispose()
		oldBoardViewLogic:clearAllViewAction()
		oldBoardViewLogic:resetTick(0)
		oldBoardViewLogic:clearAllTile()
		oldBoardViewLogic:clearAllBoardEffect()
		oldBoardViewLogic:dispose()


		newBoardViewLogic:updateLogicViewport()

		self:updatePause(-1)

		for _, func in ipairs(self.switchGameWaitCallbacks or {}) do
			func()
		end
	end

	local function updateViewports()
		tick = math.min( tick + dTick , totalTick )
		local r = tick / totalTick

		local viewport = newBoardViewLogic:getGridViewport()
		local oldViewport = oldBoardViewLogic:getGridViewport()

		local oldT = UBFMath:mix(oldStartTop, oldEndTop, r)
		local oldB = oldT + oldH - 1

		local newT = UBFMath:mix(newStartTop, newEndTop, r)
		local newB = newT + h - 1

		oldBoardViewLogic:updateViewport({
			left = oldViewport.left ,
			right = oldViewport.right,
			top = oldT,
			bottom = oldB,
		})

		newBoardViewLogic:updateViewport({
			left = viewport.left ,
			right = viewport.right,
			top = newT,
			bottom = newB,
		})

		if tick >= totalTick then
			onFinish()
			return false
		end

		return true
	end

	updateViewports()
	self:getScene():addTickFunc(updateViewports)
end

-- 棋盘非稳态屏幕点击计数
function UBFGameSceneManager:onScreenTap()
	local boardViewLogic = self:getBoardViewLogic()
	if boardViewLogic then
		boardViewLogic:dispatch(UBFGamePlaySceneEvents.kScreenTap)
	end

	if self:getBoardState() == UBFConst.BoardSMKey.kFalling
		and self:getSceneData().playState == UBFGamePlayState.kRun
	then
		if not self:isInPause() then
			self:_addInvalidTapCount(1, "onScreenTap")
		end
	end
end

function UBFGameSceneManager:onPauseBtnTap()
	if self:getBoardState() == UBFConst.BoardSMKey.kFalling
		and self:getSceneData().playState == UBFGamePlayState.kRun
	then
		self:_addInvalidTapCount(-1, "onPauseBtnTap")
	end
end

function UBFGameSceneManager:_addInvalidTapCount(count, flag)
	-- 棋盘下落状态，非暂停（未弹出设置弹窗等UI面板），点击次数+1
	-- 先执行onScreenTap（次数+1），再触发设置按钮点击（额外-1）

	local sceneData = self:getSceneData()
	if not sceneData.invalidTapCount then
		sceneData.invalidTapCount = count
	else
		sceneData.invalidTapCount = sceneData.invalidTapCount + count
	end
end

function UBFGameSceneManager:fillDcMoveInfo(dcInfo)
	if not dcInfo or type(dcInfo) ~= "table" then
		return
	end

	dcInfo.total_move = 0				-- 进关时总步数（包含前置加步数道具）
	dcInfo.static_move = 0			-- 进关时静态步数
	dcInfo.left_moves = 0				-- 当前剩余步数
	dcInfo.real_cost_move = 0			-- 当前移动步数
	dcInfo.cost_move_without_back = 0	-- 当前移动步数（包含后退一步）

	local levelJsonData = self:getCurLevelJsonData()
	if levelJsonData then
		dcInfo.static_move = levelJsonData:getStaticMoveCount()
		dcInfo.total_move = dcInfo.static_move
	end

	-- moveStepUnit（UBFTallyUnit）
	local moveStepUnit = self:callGameModule(UBFGameLogics.kTally, "getTallyUnit", UBFTallyId.kMoveStep)
	if moveStepUnit then
		dcInfo.left_moves = moveStepUnit:getValue(UBFTallyValueType.kCurrent)
		dcInfo.real_cost_move = moveStepUnit:getValue(UBFTallyValueType.kMoveCount)
		dcInfo.cost_move_without_back = moveStepUnit:getValue(UBFTallyValueType.kMoveCountWithRevert)
	end

	local levelInfo = self:getLevelInfo()
	if levelInfo and levelInfo.usePropList then
		for _, prop in pairs(levelInfo.usePropList) do
			if prop.propUnitType == UBFPropUnitType.kPreAddStep then
				dcInfo.total_move = dcInfo.total_move + 3
			end
		end
	end

	return dcInfo
end

--------------------****** *↓* ******--------------------
--						Game Over !!!!!
--------------------****** *↑* ******--------------------

function UBFGameSceneManager:isGameOverProcessed()
	return self._isGameOverProcessed
end

function UBFGameSceneManager:onGameCrash(msg, extra)

	if extra then
		self._lastCrashExtra = extra or self._lastCrashExtra
		if extra.errust then msg = "[rust:" .. tostring(extra.errust) .. "] " .. tostring(msg)
		else
			self._lastCrashReplayLog = extra.replayLog
			if extra.trace then msg = tostring(msg) .. "\n logic trace:" .. tostring(extra.trace) end
		end
	end

	local boardViewLogic = self:getBoardViewLogic()
	if boardViewLogic then
		boardViewLogic:onException(UBFBoardExceptionLevel.kFatal, "逻辑崩溃了" .. tostring(msg), "logic", extra)
	else
		self:onGameOver( {
			isCrash = true ,
			crashMsg = tostring(msg),
			source = "logic"
		} )
	end
end

function UBFGameSceneManager:onEndLevelDataRecv( endLevelData )
	self.endLevelData = endLevelData
	self.endDataRecvPromise:resolve(endLevelData)

	if self:isInReplay() then
		if not self:isInRust() then
			self:getMessageLogic():disposeThread()
		end
	else
		--
--
--
--
--

		self:rustTryPushClosure()
	end


end

function UBFGameSceneManager:onGameOverViewCome()
	self:onGameOver( self.endLevelData )
end

function UBFGameSceneManager:getEndLevelData()
	return self.endLevelData or {}
end

function UBFGameSceneManager:onGameReplayBegin(data)
	if not self.resumeLevel then return end
	-- 回放恢复
	self._replayResumeLevelRuntime = {}
	self._in_resume_repalying = true
	self._resume_prophet_launch_state = ProphetReplayResumeLaunchPolicy.State.Pending
	self._resume_prophet_launch_attempt_count = 0
	self._resume_prophet_launch_retry_scheduled = false
	self._resume_prophet_launch_on_finalized = nil
	self._resume_prophet_launch_released = false
	self:callGameModule(UBFGameLogics.kBgFg, "setPauseButtonLock", true)
	self:getScene():setResumingShow(true)
	if EnvUtil:isMiniGame() then
		self:updatePause(1)
		self:addDelayFunc(60, function() self:updatePause(-1) end)
		setTimeOut(function()
			if self.isDisposed then return end
			if not self._in_resume_repalying then return end
			UBFGameSpeedManager:setCurSpeedScale(128)
		end, 0.5)
	else
		UBFGameSpeedManager:setCurSpeedScale(4)
		local needPause = not self:getLevelInfo().waitAutoRervert
		if needPause then
			self._replayResumeLevelRuntime.isPaused = true
			self:updatePause(1)
		end
		self:callGameModule( UBFGameLogics.kCollectionBar , "onAppearance" )
	end

	local opParams = {
		source = UBFCollectionBarSource.kResume,
		collectionBarParent = self:getScene():getLayerByKey(UBFGameplayLayerKey.ITEM2)
	}
	UBFGlobal:callLogic(UBFUiLogicId.UI_VIEW_LOGIC_MANAGER, "exeOp", UBFCollectionBarOpType.OPEN, opParams)
end
function UBFGameSceneManager:onGameReplayEnd(data)
	local replayEndData = { endData = data or {} }
	local replayEndEvent = UBFSceneModEventMap[UBFGameModEventEnum.kReplayEnd]:create(replayEndData)
	self:notifyModEvent(replayEndEvent)

	local replayResumeLevelRuntime = self._replayResumeLevelRuntime
	if self.resumeLevel and replayResumeLevelRuntime and not replayResumeLevelRuntime._isEnding then
		-- 回放结束消息可能重复到达，结束流程只能消费一次 runtime，避免重复减暂停计数
		replayResumeLevelRuntime._isEnding = true
		-- 判断rust 不影响非rust流程，虽然感觉非rust流程也应该有
		if self:isInRust() then  self.resumeLevel = false end

		if not EnvUtil:isMiniGame() then
			local function afterReplayResume()
				-- 禁用后退
				self:setPropUnavailableExternalReason( UBFPropUnitType.kRevert, UBFPropUnavailableReason.kCannotRevert )
				-- 清空缓存
				if self._replayResumeLevelRuntime == replayResumeLevelRuntime then
					self._replayResumeLevelRuntime = nil
				end
				-- 刷新道具栏已用数量，修正可用判断
				local propUsedMap = data.propUsedMap
				if not propUsedMap then
					if self._replaySectionData and self._replaySectionData.replayLog then
						propUsedMap = {}
						local replayLog = self._replaySectionData.replayLog
						for _, logs in ipairs(replayLog.oLogs or {}) do
							local op = UBFOpLogMappingHelper:reflect(logs)
							local params = op.opParams or {}
							if op.opType == UBFOperationType.kProp and
								params.propUseType ~= UBFPropUseType.kTemp then
								local propUnitType = params.propUnitType
								if propUnitType then
									propUsedMap[propUnitType] = (propUsedMap[propUnitType] or 0) + 1
								end
							end
						end
					end
				end
				self:callGameModule( UBFGameLogics.kPropBar ,'refreshUsedCount' , propUsedMap or {})
			end

			local needPause = not self:getLevelInfo().waitAutoRervert
			self:finalizeReplayResumeProphetLaunch(function()
				if replayResumeLevelRuntime.isPaused or needPause then
					-- 后台回放，先完成先知 one-shot，再解除暂停并恢复玩家交互。
					self:updatePause(-1)

					local msgLogic = self:getMessageLogic()
					if msgLogic then
						msgLogic:sendLaunchViewRefresh(true)
						self._replay_resume_send_launch_refresh = true
					end

					self:addDelayFunc(1, function()
						-- 刷新棋盘状态，需要延迟是因为暂停时的时序问题，后续事件无法立即执行成功，需要延迟执行
						if replayResumeLevelRuntime._lastGameState then
							self:onGameStateChange( replayResumeLevelRuntime._lastGameState )
						end
						if data.byError then
							CommonTip:showTip("因关卡版本更新，只能恢复到这啦～")
						end
						afterReplayResume()
					end)
				else
					-- 前台回放
					afterReplayResume()
				end
			end)
		else
			self:finalizeReplayResumeProphetLaunch(function()
				if data.byError then
					CommonTip:showTip("因关卡版本更新，只能恢复到这啦～")
				end
			end)
		end
	end

	--
--
--
--
--
--
--
--
--
--
--
--
--

end

function UBFGameSceneManager:notifyScreenSized()
	if self._isGameOverProcessed then return end
	self:callGameModule( UBFGameLogics.kStep , "notifyScreenSized")
	self:callGameModule( UBFGameLogics.kTargetPad , "notifyScreenSized")
	self:callGameModule( UBFGameLogics.kScore , "notifyScreenSized")
	self:callGameModule( UBFGameLogics.kCollectionBar , "notifyScreenSized")
	self:callGameModule( UBFGameLogics.kPropBar , "notifyScreenSized")
	self:callGameModule( UBFGameLogics.kWonderfulReplay , "notifyScreenSized")
	self:callGameModule( UBFGameLogics.kGameMod , "notifyScreenSized")

	-- 从onScreenExpandChanged搬过来
	local scene = self:getScene()
	if (not scene) or scene.isDisposed then return end

	scene:refreshGlobalLayoutData()
	scene:doLayoutScene()
	scene:doLayoutBoard()
	local event = UBFSceneModEventMap[UBFGameModEventEnum.kSceneExtend]:create()
	self:notifyModEvent( event )
end

function UBFGameSceneManager:rustTryPushClosure()
	if not self:isInRust() then return end
	if not self.endLevelData then return end
	if not self._isEnterBonus then return end

	local msgClient = self:getMessageLogic()
	if not msgClient then return end
	msgClient:sendClosure()
end

-- 启动出关流程
function UBFGameSceneManager:launchEndLevelProcess(endLevelData)
	UBFDebug.game_lag_log("push", "game_over_launch", endLevelData.failReason or (endLevelData.win and "win" or "crash"))
	--
--
--
--
--
--


	local runtime
	local isCrash = endLevelData.isCrash
	if not isCrash and self._myPrevSceneMgr then
		runtime = self._myPrevSceneMgr:getRuntime()
	end

	if not runtime then
		UBFDebug.game_lag_log("push", "game_over_runtime_create")
		local prevSceneMgr = UBFPrevSceneManager.new(self)
		UBFPrevSceneManager:setInstance(prevSceneMgr)
		self._myPrevSceneMgr = prevSceneMgr
		runtime = UBFELRuntime:create({
			prevSceneMgr = prevSceneMgr,
			replayLog = endLevelData.replayLog,
			endLevelData = endLevelData,
		})
		prevSceneMgr:setRuntime(runtime)
		UBFDebug.game_lag_log("pop", "game_over_runtime_create")
	end

	--记录先前的数据
	UBFDebug.game_lag_log("push", "game_over_prev_scene")
	self._myPrevSceneMgr:onGameOver()
	UBFDebug.game_lag_log("pop", "game_over_prev_scene")

	--更新replay
	self:updateReplayData(endLevelData)

	--设置变量
	self._lastGameReplayLog = endLevelData.replayLog
	UBFDebug.game_lag_log("push", "game_over_trace")
	endLevelData._gameoverEnterStack = debug.traceback()
	UBFDebug.game_lag_log("pop", "game_over_trace")

	-- 崩溃时，尝试上传Replaylog
	UBFDebug.game_lag_log("push", "game_over_crash_replay")
	self:dcCrashReplaylog(endLevelData)
	UBFDebug.game_lag_log("pop", "game_over_crash_replay")

	-- 加载modList
	UBFDebug.game_lag_log("push", "game_over_mod_load")
	local defaultWillingList = self._myPrevSceneMgr:getModMgrMap()
	local modMgr = runtime:getModMgr()
	modMgr:loadAllWillingMod(defaultWillingList)
	UBFDebug.game_lag_log("pop", "game_over_mod_load")

	--开始清关流程创建并启动
	UBFDebug.game_lag_log("push", "game_over_process_start")
	runtime.isLaunchEndLevelProcess = true
	local isCrash = endLevelData.isCrash 
	local processType = self:getEndLevelProcessTypeByEndLevelData(runtime, isCrash)
	if processType then
		UBFProcessManager:launch(processType, runtime)
	end
	UBFDebug.game_lag_log("pop", "game_over_process_start")
	UBFDebug.game_lag_log("pop", "game_over_launch")
end

local function mappingRustPlayLog(playLog)
	if not playLog then return nil end
	local stepProgressInfo = playLog.stepProgressInfo or {}
	local newLogs = {}
	for _, v in pairs(stepProgressInfo) do
		local moveCount = v.moveCount or 0
		local moveCountWithRevert = v.moveCountWithRevert or moveCount
		local restMove = v.restMove or 0
		local opType = v.opType or 0
		local score = v.score or 0
		local opId = v.opId or -1
		local progressData = v.progressData or {}
		local progressStrList = {}
		for k, pd in pairs(progressData) do
			table.insert(progressStrList, string.format("[%s:%s-%s]", pd.id, pd.cv, pd.tv))
		end
		local pstr = table.concat(progressStrList, ",")
		table.insert(newLogs,
			string.format(
				"%s[%s:%s]-%s,%s,{%s},%s",
				moveCount, opId, opType, restMove, score, pstr, moveCountWithRevert
			)
		)
	end
	return newLogs
end

--更新replay
function UBFGameSceneManager:updateReplayData(endLevelData)
	UBFDebug.game_lag_log("push", "game_over_replay_update")
	pcall(function()
		if not endLevelData.replayLog then return end
		if type(_G._UBF_GAME_UI_VISUAL_PARAMS) == "table"
			or type(_G._UBF_GAME_UI_VISUAL_CONFIG) == "table" then
			local ok, helper = pcall(require, "ubf.debug.wc.dev.GameUiVisualTuningHelper")
			if ok and helper and helper.attachReplayData then
				pcall(helper.attachReplayData, endLevelData.replayLog)
			end
		end
		endLevelData.replayLog.isUBF = true
		local event = UBFSceneModEventMap[UBFGameModEventEnum.kBeforeReplayLogFinalize]:create({
			endLevelData = endLevelData,
		})
		self:notifyModEvent(event)
		if EnvUtil:isWindows() then printx(21, table.serialize(endLevelData.replayLog)) end
		local levelInfo = self:getLevelInfo()
		local league = endLevelData.league
		local addStepSource = league.addStepSource
		local bySourceMap = addStepSource and addStepSource.bySourceMap or {}
		endLevelData._lastReusmeFlag = self._last_reusme_flag
		if endLevelData.rust then
			endLevelData.replayLog.numagic = self._levelInfo.rustMagicNumber 
			if levelInfo.so_rust_dy then 
				endLevelData.replayLog.rust_hash = levelInfo.so_rust_dy
			end
			if hello_rust_get_hash then
				endLevelData.replayLog.rustHash = hello_rust_get_hash()
			end
			local list = league.addStepSource or {}
			bySourceMap.PreProp = list[1] or 0
			bySourceMap.unknow = 0
			for i = 2, #list do bySourceMap.unknow = bySourceMap.unknow + (list[i] or 0) end
			local dataCollect = endLevelData.dataCollect or {}
			endLevelData.replayLog.stepLog = mappingRustPlayLog(dataCollect.playLog)
			endLevelData.replayLog.failedSwapOpIds = dataCollect.failedSwapOpIds
		end
		if levelInfo.prophet_statistics and UBFVMProphet then 
			local info = UBFVMProphet.toKeyInfo(levelInfo.prophet_statistics, league.moveCount)
			endLevelData.replayLog.whatProphet = info
			local prophetLaunchInfo = levelInfo.prophetLaunchInfo
			if prophetLaunchInfo then info.set_id = prophetLaunchInfo.configKey end
		end
        local prePropIdList = {}
		local levelJsonData = self:getLevelJsonData()
		if endLevelData.rust then
			local list = league.addStepSource or {}
			bySourceMap.PreProp = list[1] or 0
			bySourceMap.unknow = 0
			for i = 2, #list do bySourceMap.unknow = bySourceMap.unknow + (list[i] or 0) end
		end
        if levelInfo.temp and levelInfo.temp.selectedItemsData then
            local list = levelInfo.temp.selectedItemsData
			for i, v in ipairs(list) do
				local node = {}
				node.id = v.id
				if v.isVideoAd then
					node.ad = true
				end
				table.insert(prePropIdList,node)
			end
        end
		local levelJsonData = self:getLevelJsonData()
		endLevelData.replayLog.result = {
			score = endLevelData.totalScore,
			star = endLevelData.star,
			win = endLevelData.win,
			failReason = endLevelData.failReason,

 			--   - 使用步数：oplog.result.useMoves
			useMoves = league.moveCount,
			--   - 静态步数：oplog.result.staticMove
			staticMove = league.staticMoveCount or (levelJsonData and levelJsonData:getStaticMoveCount()) or 0,
			--   - 前置步数：oplog.result.prePropMove
			prePropMove = bySourceMap.PreProp or 0,
			--   - 棋盘增加的额外步数：oplog.result.boardAddMove
			boardAddMove = bySourceMap.unknow or 0,
			-- 前置道具id列表
			preProps = prePropIdList,
		}
		-- 逻辑胜利：使用步数 <=  前置步数 + 静态步数 + 气球额外步数
		local result = endLevelData.replayLog.result
		result.logicalWin = result.win and (result.useMoves <= result.prePropMove + result.staticMove + result.boardAddMove)
		result.topLevelLogicalWinBeforePass =  _G.amfBean("LevelAreaManager"):getTopLevelLogicalWinCount()
		endLevelData.replayLog.bundleVersion = _G.bundleVersion
		endLevelData.replayLog.curMd5 = levelInfo.curMd5 or ResourceLoader.getCurVersion()
		if not endLevelData.replayLog.gEnv.uid then
			endLevelData.replayLog.gEnv.uid = self._levelInfo.uid
		end
		if not endLevelData.replayLog.gEnv.levelGroup then
			local gEnv = endLevelData.replayLog.gEnv
			local levelGroupInfo = levelInfo.levelGroupInfo
			if levelGroupInfo then
				local expGroup = tostring(levelGroupInfo.levelGroup)
				local meetGroup = tostring(levelGroupInfo.meetGroup)
				if expGroup == meetGroup then gEnv.levelGroup = expGroup
				else
					gEnv.levelGroup = expGroup
					gEnv.levelMeetGroup = meetGroup
				end
			end
		end
	end)
	UBFDebug.game_lag_log("pop", "game_over_replay_update")
end

--要求关闭线程（可能之前已经关闭过了）
function UBFGameSceneManager:disposeThread(endLevelData)
	local msgClient = self:getMessageLogic()
	msgClient:disposeThread()
	if msgClient.getExtraLibErr then
		local err = msgClient:getExtraLibErr()
		if err then
			if endLevelData.isCrash then
				local crashMsg = endLevelData.crashMsg
				endLevelData.crashMsg = tostring(crashMsg) .. "\n(lib err)" .. err
			else 
				he_log_error("[RUST] fin suc, but lib err: " .. tostring(err)) 
			end
		end
	end
end

-- 崩溃时，尝试上传Replaylog
function UBFGameSceneManager:dcCrashReplaylog(endLevelData)
	local isCrash = endLevelData.isCrash
	if not isCrash then return end

	xpcall(function()
		self._lastCrashReplayLog = endLevelData.replayLog or self._lastCrashReplayLog or self._last_replay_log_record
		if self._lastCrashExtra then endLevelData.replayLog = self._lastCrashExtra.replayLog end
		endLevelData.replayLog = endLevelData.replayLog or self._lastCrashReplayLog
		if not endLevelData.replayLog and self._replaySectionData then 
			endLevelData.replayLog = self._replaySectionData.replayLog
		end
		local replaySend
		if endLevelData.replayLog then 
			if self._last_swap_data then 
				local swapData = self._last_swap_data
				local from = swapData.from or { }
				local to = swapData.to or { }
				endLevelData.replayLog.lastSwapInfo = string.format(
					"(%s,%s)->(%s,%s)", 
					from.r or -1, from.c or -1, to.r or -1, to.c or -1
				)
			end
			local replayLog_json = table.serialize(endLevelData.replayLog)
			if replayLog_json and replayLog_json ~= "" then 
				local Compress = require "amf.script.encode.Compress"
				local data = Compress.compress(replayLog_json)
				replaySend = data and mime.b64(data) or nil
			end
		end
		DcUtil:logUBFOpLog({
			category = 'crashReplaylog',
			sub_category = 'crash',
			levelId = self._levelInfo.levelId,
			playId = self._levelInfo.playId,
			infoMd5 = self._levelInfo.curMd5,
			isRust = self:isInRust(),
			replayIsResume = self:isResumeLevel(),
			resumeFlag = self._last_reusme_flag or 0,
			replayLog = replaySend or "NoReplayLog",
		})
	end, debug.traceback)
end

--更新一些记录
function UBFGameSceneManager:updateSomeRecords(endLevelData)
	local isCrash = endLevelData.isCrash
	if isCrash then return end

	local sceneData = self:getSceneData()
	local levelInfo = self:getLevelInfo()
	--更新时间统计
	UBFDebug.game_lag_log("push", "game_over_record_stats")
	pcall(function()
		local scene = self:getScene()
		local msgLogic = self:getMessageLogic()
		-- Statistic Timestamp Object
		endLevelData.stsobj = msgLogic:getTimeStatistic(UBFBoardStateKey.kCanSwap)
		local boardViewLogic = self:getBoardViewLogic()
		if isSafeCocosObj(scene) and boardViewLogic then
			endLevelData.stsobj:stateChange(true, boardViewLogic.currTickAbsolute)
			scene:updateStagnateToStatisticsPauseOccupy()
		end
	end)
	UBFDebug.game_lag_log("pop", "game_over_record_stats")

	--更新记录
	UBFDebug.game_lag_log("push", "game_over_oplog_size")
	xpcall(function()
		endLevelData.isWonderfulReplay = self:isInWonderfulReplay()
		sceneData.sectionSizeRecord.opLogSize = #table.serialize(endLevelData.replayLog)
	end, debug.traceback)
	UBFDebug.game_lag_log("pop", "game_over_oplog_size")
end

--游戏结束的核心入口
function UBFGameSceneManager:onGameOver(endLevelData)
	if self._isGameOverProcessed then return end
	self._isGameOverProcessed = true
	local isCrash = endLevelData.isCrash

	--
--


	if not EnvUtil:isUnity() then
		xpcall(function()
			-- Replay completion can enter onGameOver before the asynchronous end-level payload
			-- is attached; keep this diagnostic for live games without flagging normal replay teardown.
			if not self.endLevelData and not endLevelData.isCrash and not self:isInReplay() then
				he_log_error("why onGameOver not endLevelData and not isCrash!")
			end
		end, debug.traceback)
	end

	--异常return时，需要清除出关流程
	local function clearCurrEndProcess()
		UBFProcessManager:clearCurrEndProcess()
	end

	-- 游戏没开始就退出
	if endLevelData.notStartQuit then
		local process = UBFProcessManager:getCurrStartProcess()
		if process then 
			process:abort()
		else 
			Director:sharedDirector():popScene() 
		end
		clearCurrEndProcess()
		return
	end
	
	--顺序异常，正常情况下应该是编辑器才会这样
	local scene = self:getScene()
	local isSceneDisposed = scene and scene.isDisposed
	if isSceneDisposed and isCrash then
		clearCurrEndProcess()
		if not _G.editorMode then 
			he_log_error(string.format("scene disposed before game over! %s", _G.__lastGamePlaySceneDisposeTrace))
		end
		return
	end

	if EnvUtil:isMiniGame() then
		local levelInfo = self:getLevelInfo()
		if levelInfo.isReplay then
			CommonTip:showTip("回放完毕!")
			clearCurrEndProcess()
			return
		end
	end

	if isCrash and EnvUtil:isDevelopMode() then
    	if _G.__autoTestingLevel then
			UBFLogE("Auto test level CRASHED!!! ", endLevelData.crashMsg)
			_G.__autoTestLevelFailed = true
		end
    end
	--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--


	UBFDebug.game_lag_log("push", "game_over_finalize", endLevelData.failReason or (endLevelData.win and "win" or "crash"))
	local endProcess = UBFProcessManager:getCurrEndProcess()
	if not endProcess then
		self:launchEndLevelProcess(endLevelData)
	end

	--关闭线程
	UBFDebug.game_lag_log("push", "game_over_dispose_thread")
	self:disposeThread(endLevelData)
	UBFDebug.game_lag_log("pop", "game_over_dispose_thread")

	--通用结束处理
	UBFDebug.game_lag_log("push", "game_over_common")
	self:_onGameOverCommon(endLevelData)
	UBFDebug.game_lag_log("pop", "game_over_common")

	--恢复速度
	UBFDebug.game_lag_log("push", "game_over_restore_speed")
	UBFGameSpeedManager:resuleDefaultSpeed()
	UBFDebug.game_lag_log("pop", "game_over_restore_speed")

	-- 崩溃时，尝试上传Replaylog
	UBFDebug.game_lag_log("push", "game_over_crash_report")
	self:dcCrashReplaylog(endLevelData)
	UBFDebug.game_lag_log("pop", "game_over_crash_report")
	--更新一些记录
	UBFDebug.game_lag_log("push", "game_over_records")
	self:updateSomeRecords(endLevelData)
	UBFDebug.game_lag_log("pop", "game_over_records")
	--发送场景结束事件
	UBFDebug.game_lag_log("push", "game_over_notify")
	local runtime = self._myPrevSceneMgr and self._myPrevSceneMgr:getRuntime()
	if runtime then
		-- gameover
		local event = UBFSceneModEventMap[UBFGameModEventEnum.kGameOver]:create({ runtime = runtime })
		self:notifyModEvent(event)
	end
	UBFDebug.game_lag_log("pop", "game_over_notify")

	-- 玩家明确退出或重玩时立即放弃恢复；普通失败等待协议成功后清理。
	local failReason = endLevelData.failReason
	if failReason == UBFGameFailReason.kDropout
		or failReason == UBFGameFailReason.kRetry then
		UBFDebug.game_lag_log("push", "game_over_remove_section")
		pcall(function() UBFSectionResumeHelper:removeSavedSection() end)
		UBFDebug.game_lag_log("pop", "game_over_remove_section")
	end

	-- 开始出关流程性能监控
	UBFDebug.game_lag_log("push", "game_over_finish_process")
	local scene = self:getScene()
	if isSafeCocosObj(scene) then 
		UBFDebug.game_lag_log("push", "game_over_monitor_start")
		scene:startMonitor()
		UBFDebug.game_lag_log("pop", "game_over_monitor_start")
	else
		he_log_error(string.format("scene disposed before process finish! isCrash %s  levelId=%s  action=%s failReason=%s Trace %s", 
			isCrash,
			tostring(self._levelInfo and self._levelInfo.levelId or "nil"),
			tostring(endLevelData and endLevelData.action or "nil"),
			tostring(endLevelData and endLevelData.failReason or "nil"),
			_G.__lastGamePlaySceneDisposeTrace or ""))
	end
	-- 继续流转出关流程
	UBFDebug.game_lag_log("push", "game_over_bonus_finish")
	self:finishWaitBonustimeNode()
	UBFDebug.game_lag_log("pop", "game_over_bonus_finish")

	self.gameover = true
	if MetricsCollector then
		UBFDebug.game_lag_log("push", "game_over_metrics_end")
		MetricsCollector:getInstance():endSample(MetricsCollector_Scene.Level, self:getLevelInfo().levelId)
		UBFDebug.game_lag_log("pop", "game_over_metrics_end")
	end
	UBFDebug.game_lag_log("pop", "game_over_finish_process")
	UBFDebug.game_lag_log("pop", "game_over_finalize")
end

-- 继续流转出关流程
function UBFGameSceneManager:finishWaitBonustimeNode()
	local process = UBFProcessManager:getCurrEndProcess()
	if process then
		local operateData = {
			waitViewAnimationFinish = true,
		}
		if rawget(_G, "UBF_LAG_LOG_ENABLED") ~= true then
			process:operate(UBFProcessNodeEnum.EL_WAIT_BONUSTIME, operateData)
			return
		end

		local tokenKey = "_ubfLagGameOverOperateToken"
		local oldToken = rawget(process, tokenKey)
		rawset(process, tokenKey, true)
		local ok, err = xpcall(function()
			process:operate(UBFProcessNodeEnum.EL_WAIT_BONUSTIME, operateData)
		end, debug.traceback)
		rawset(process, tokenKey, oldToken)
		if not ok then error(err, 0) end
	end
end

function UBFGameSceneManager:shouldUseActivityDeputyPassLevelProcess(runtime)
	local levelScene = runtime and runtime:getLevelScene()
	return UBFLevelSceneFunc:isActLevelScene(levelScene) == true
end

function UBFGameSceneManager:getEndLevelProcessTypeByEndLevelData(runtime, isCrash)
    local processType
    if isCrash then
        processType = UBFGameProcessEnum.CRASH
    elseif _G.isYunGame then
        processType = UBFGameProcessEnum.YUNGAME
    else
		local endLevelData = runtime:getEndLevelData()
		local isAskForHelp = runtime:isAskForHelp()
		local isWonderfulReplay = endLevelData.isWonderfulReplay
		local failReason = endLevelData.failReason
		if isWonderfulReplay then
			processType = UBFGameProcessEnum.WONDER_FULREPLAY
		elseif isAskForHelp then
			if endLevelData.win then
				processType = UBFGameProcessEnum.AFH_PASS_LEVEL
			else
				processType = UBFGameProcessEnum.AFH_FAIL_LEVEL
			end
		else
			if endLevelData.win then
				if self:shouldUseActivityDeputyPassLevelProcess(runtime) then
					processType = UBFGameProcessEnum.ACTIVITY_DEPUTY_PASS_LEVEL
				else
					processType = UBFGameProcessEnum.NORMAL_PASS_LEVEL
				end
			else
				lua_switch(failReason){
					[_G.UBFGameFailReason.kNoLife] = function ( ... )
						processType = UBFGameProcessEnum.NORMAL_FAIL_LEVEL
					end,
					[_G.UBFGameFailReason.kDeadBoard] = function ( ... )
						processType = UBFGameProcessEnum.NORMAL_FAIL_LEVEL
					end,
					[_G.UBFGameFailReason.kStarLack] = function ( ... )
						processType = UBFGameProcessEnum.NORMAL_FAIL_LEVEL
					end,
					[_G.UBFGameFailReason.kDropout] = function ( ... )
						processType = UBFGameProcessEnum.QUIT_LEVEL
					end,
					[_G.UBFGameFailReason.kRetry] = function ( ... )
						processType =  UBFGameProcessEnum.RETRY_LEVEL
					end
				}
			end
		end
    end

    return processType
end

function UBFGameSceneManager:_onGameOverCommon(endLevelData)
	--锁一些内容
	UBFDebug.game_lag_log("push", "game_over_ui_cleanup")
	self:callGameModule(UBFGameLogics.kBgFg, "setPauseButtonLock", true)

	--清理速度按钮和交换提示
	xpcall(function()
		if GameSpeedButton then GameSpeedButton.clear() end
		UBFGamePlayTest:ui_onGameOver(endLevelData)
		local boardViewLogic = self:getBoardViewLogic()
		if boardViewLogic then boardViewLogic:setExtendLogic( UBFBoardViewExtendLogics.kMatchAdvice, nil) end
	end,function(err)
		local str = err .. debug.traceback()
		if _G.isLocalDevelopMode then print(str) end
		he_log_error(str )
	end)
	UBFDebug.game_lag_log("pop", "game_over_ui_cleanup")

	--记录oplog到本地，debug回传相关内容
	UBFDebug.game_lag_log("push", "game_over_replay_flush")
	xpcall(function()
		local newReplayLog = UBFHelper:shallowClone(endLevelData.replayLog)
		if not newReplayLog then return end
		newReplayLog.ubfDataKey = tostring(newReplayLog.gEnv.playId) .. "_" .. tostring(#newReplayLog.oLogs)
		newReplayLog.uid = newReplayLog.gEnv.uid
		newReplayLog.level = newReplayLog.gEnv.levelId
		UploadReplayDataManager:flushReplayDataByCache(newReplayLog)
	end, debug.traceback)
	UBFDebug.game_lag_log("pop", "game_over_replay_flush")

	--清除bonus速度点击任意处UI
	if self._sceneRuntimeData.closeSpeedUpClickContinueUIPromise then
		UBFDebug.game_lag_log("push", "game_over_continue_ui")
		self._sceneRuntimeData.closeSpeedUpClickContinueUIPromise:resolve()
		UBFDebug.game_lag_log("pop", "game_over_continue_ui")
	end
end

--------------------****** *↓* ******--------------------
--						面板弹弹弹
--------------------****** *↑* ******--------------------

function UBFGameSceneManager:popoutPropHelpPanel( propId , closeCallback )
	local defaultPropUnitTypes = nil
	local morePropUnitTypes = {}
	if self:callGameModule( UBFGameLogics.kPropBar , "getPropBubble" , UBFPropUnitType.kOctopusFrozen ) then
		table.insert( morePropUnitTypes , UBFPropUnitType.kOctopusFrozen )
	end
	if self:callGameModule( UBFGameLogics.kPropBar , "getPropBubble" , UBFPropUnitType.kAddStep15 ) then
		table.insert( morePropUnitTypes , UBFPropUnitType.kAddStep15 )
	end
	if MaceOfScoreUBFLogic and MaceOfScoreUBFLogic:hasPropBarNPC() then
		table.insert(morePropUnitTypes, UBFPropUnitType.kMaceOfScore)
	end
	local levelInfo = self:getLevelInfo()
	if levelInfo.levelType == GameLevelType.kMoleWeekly2022 then
		defaultPropUnitTypes = {
			UBFPropUnitType.kRefresh,
			UBFPropUnitType.kMagicWand,
			UBFPropUnitType.kSwap,
			UBFPropUnitType.kHammer
		}
	elseif levelInfo.levelType == GameLevelType.kWeeklyRace2020 then
		defaultPropUnitTypes = {
			UBFPropUnitType.kWitchBoom,
			UBFPropUnitType.kRefresh,
			UBFPropUnitType.kSwap,
			UBFPropUnitType.kHammer,
			UBFPropUnitType.kMagicWand,
		}
	end

	local UBFPropDescriptionPanel = require "ubf.UBFGamePlayScene.views.sceneViews.panels.UBFPropDescriptionPanel"
	local node = UBFPropDescriptionPanel:create({
		closeCallback = closeCallback,
		morePropUnitTypes = morePropUnitTypes,
		defaultPropUnitTypes = defaultPropUnitTypes,
		propId = propId,
	})

	node:popout()
end

function UBFGameSceneManager:sendAbandonLevelOperation( mode )
	local msgLogic = self:getMessageLogic()
	--发生什么事了？
	if not msgLogic then
		UBFPlaySceneLauncher:startClearOld(true)
		return
	end

	msgLogic:sendOperation(UBFOperationType.kAbandon, { mode = mode })
end

function UBFGameSceneManager:popoutQuitPanel(params)
	--
--
--
--
--



	local levelInfo = self:getLevelInfo()

	local logic = UBFLogicCreator:createLogic {
		logicId = UBFGameLogics.kQuit
	}

    local unit = self:callGameModule( UBFGameLogics.kTally , "getTallyUnit" , UBFTallyId.kMoveStep )
    local realCostMove = unit and unit:getValue( UBFTallyValueType.kMoveCountWithRevert ) or 0

    local targetMove = unit and unit:getValue( UBFTallyValueType.kTarget ) or 0

    local unit = self:callGameModule( UBFGameLogics.kTally , "getTallyUnit" , UBFTallyId.kScore )
    local score = unit and unit:getValue() or 0


	if logic then
		self:updatePause( 1 )
		local isAskForHelp = levelInfo.isAskForHelp

		local quitMode = NewBoardQuitPanelMode.QUIT_LEVEL
		local isWeeklyRace2020 = (levelInfo.levelType == GameLevelType.kWeeklyRace2020)
		if isWeeklyRace2020 then
			quitMode = NewBoardQuitPanelMode.WEEKLY_RACE_2020
		elseif isAskForHelp then
			quitMode = NewBoardQuitPanelMode.NO_REPLAY
		end

		logic:buildView({
			quitMode = quitMode,
			levelInfo = levelInfo,
			levelJsonData = self:getCurLevelJsonData(),
			realCostMove = realCostMove,
			score = score,
			replayCallback = function ( ... )
				self:sendAbandonLevelOperation( UBFOperationAbandonType.kRetry)
			end,
			quitGameCallback = function()
				if self:isGameNotStart() then
					self:onGameOver({
						notStartQuit = true,
						isQuit = true
					})
					return
				end
				if self:isGameOver() then
					self:updatePause( -1 )
					return
				end
				if isWeeklyRace2020 then
					self:updatePause( -1 )
				end

				self:sendAbandonLevelOperation( UBFOperationAbandonType.kDropout)
				local curScore , curStar = self:getCurrScoreAndStar()

				local _data = {
					levelId = levelInfo.levelId,
					levelType = levelInfo.levelType,
					strategyID = LevelDifficultyAdjustManager and LevelDifficultyAdjustManager:getCurrStrategyID(),

					score = curScore,
					star = curStar,
					oldStar = levelInfo.oldStar,
					realCostMove = realCostMove,
					staticLevelMoves = targetMove,

					isQuit = true,
					levelScene = levelInfo.levelScene,
				}
				if LocalActCoreModel then
					LocalActCoreModel.getInstance():notify(ActInterface.kBeforeQuitLevel, _data)
				end
			end,
			closeCallback = function()
				self:updatePause( -1 )
			end,
			stopBoard = function ( ... )
				self:updatePause( 1 )
			end,
			resumeBoard = function ( ... )
				self:updatePause( -1 )
			end,

		}):popout()

		return
	end
end

function UBFGameSceneManager:popoutBuyPropPanel( propUnitType , callbackData )
	local onBoughtCallback = callbackData and callbackData.onBoughtCallback or doNothing
	local onExitCallbackFail = callbackData and callbackData.onExitCallbackFail or doNothing
	local onExitCallbackCancel = callbackData and callbackData.onExitCallbackCancel or doNothing

	local logic = UBFLogicCreator:createLogic { logicId = UBFGameLogics.kPropBuyPanel }
	local isDebugPlayMode = self:isDebugPlayMode()
	local panel
	panel = logic:buildView( nil , {
	    propUnitType = propUnitType,
	    successCallback = function( context )
			local boughtInfo = context.boughtInfo
			--
--

			onBoughtCallback( boughtInfo.itemId , boughtInfo.num , panel.lastTouchFlyPostion )
	    end,
		failCallback = function( context )
			if context.lastBuyResult == "cancel" or not context.lastBuyResult then onExitCallbackCancel()
			else onExitCallbackFail( context.lastFailCode , context.lastFailMsg ) end
		end,
		onHelpBtnClick = function( propId )
			self:popoutPropHelpPanel( propId )
		end,
		isDebugPlayMode = isDebugPlayMode
	})
	panel:popout()
end

function UBFGameSceneManager:popoutAddStepPanel( params )
	-- 一个log，用于检查面板弹出见的问题
	local aspPopLog = {}
	aspPopLog["stepCount"] = 0
	aspPopLog["logStr"] = ""
	-- 3秒后，没走完弹面板的逻辑的话，打一个Log
	setTimeOut(function()
		if aspPopLog and not aspPopLog.popLogicFinished then
			local logMsg = ("[ASP_POP_2][LOGIC]stepCount:"..aspPopLog.stepCount..",logStr:"..aspPopLog.logStr)
			-- UBFLogE("=== aspPopLog!!!- logic: ", tts(aspPopLog))
			-- UBFLogE("=== aspPopLog!!!- logic: ", logMsg)
			he_log_error(logMsg)
		end
	end, 3)
	-- 7秒后，没执行完弹面板的动画的话，打一个Log
	local aspPopViewLog = {}
	aspPopViewLog["stepCount"] = 0
	aspPopViewLog["logStr"] = ""
	setTimeOut(function()
		if aspPopViewLog and not aspPopViewLog.popViewFinished then
			local logMsg = ("[ASP_POP_2][VIEW]stepCount:"..aspPopViewLog.stepCount..",logStr:"..aspPopViewLog.logStr)
			-- UBFLogE("=== aspPopViewLog!!!- view: ", tts(aspPopViewLog))
			-- UBFLogE("=== aspPopViewLog!!!- logic: ", logMsg)
			he_log_error(logMsg)
		end
	end, 7)

	local function stopASPLog()
		if aspPopLog then aspPopLog.popLogicFinished = true end
		if aspPopViewLog then aspPopViewLog.popViewFinished = true end
	end

	if self.isAIEnv then stopASPLog() return end

	if self:isInReplay() then
		stopASPLog()
		if _G.DEV_REPLAY_FLAG then return end
		return
	end
	UBFAddStepPanelUtil:checkAddPopLog(aspPopLog, "a")--1

	-- 2026.07.08 看上去amf能弹出来了，所以不要这个了
	-- amf 太坑了，+5面板弹出不了，会崩溃，所以这里直接给
	-- --
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--


	if UBFGameSpeedManager:hasAnySpeedSwitchOn() then
		UBFGameSpeedManager:resuleDefaultSpeed()
	end
	UBFAddStepPanelUtil:checkAddPopLog(aspPopLog)--2

	-- todo 假装接入一下

	local closePromise = UBFPromise:create()
	local addStepRuntime = {
		fuuuProgressData = params.fuuuProgressData,
		closePromise = closePromise,
		-- referBoardId = params.referBoardId
	}
	self._sceneRuntimeData.addStep = addStepRuntime
	local sceneData = self:getSceneData()
	local levelInfo = self:getLevelInfo()
	local curLevelJsonData = self:getCurLevelJsonData()
	local currLevelId = curLevelJsonData:getLevelId() or levelInfo.levelId
	local createAddStepStrategy = require 'ubf.old.gamePlay.oldAddStepPanel.createAddStepStrategy'
	sceneData.addStepPopoutCount = (sceneData.addStepPopoutCount or 0) + 1
	local gameParams = {
		levelId = levelInfo.levelId,
		levelType = levelInfo.levelType,
		levelScene = levelInfo.levelScene,
		currLevelId = currLevelId,
		fiveStepPropId = UPropId.ADD_FIVE_STEP,
		usePropList = levelInfo.usePropList,
		onPanelWillPopout = doNothing,
		dcParams = {
			addStepPopoutCount = sceneData.addStepPopoutCount,
		},
		onRealClose = function()
			addStepRuntime.isClose = true
			self:setAddStepPanelPropBarLock(false)
			closePromise:resolve()

			if UBFGameSpeedManager:hasAnySpeedSwitchOn() then
				UBFGameSpeedManager:changeSpeedForFastPlay()
			end
		end,
		onUseBtnTapped = function( usePropId, usePropType, buyAddFiveStep, oldParam1, oldParam2, customParams)
			sceneData.revivalCount = sceneData.revivalCount + 1
			local PropManager = UBFHelper:getGlobalLogic("PropManager")
			local addStepCount = PropManager:getAddStepCount(usePropId)
			-- printx(11, "[A5U-DEBUG] onUseBtnTapped: usePropId=", tostring(usePropId), " PropManager addStepCount=", tostring(addStepCount), " customParams.realAddCount=", customParams and tostring(customParams.realAddCount) or "nil")
			if customParams and customParams.realAddCount then
				addStepCount = customParams.realAddCount
			end
			-- printx(11, "[A5U-DEBUG] onUseBtnTapped: final addStepCount=", tostring(addStepCount))
			addStepRuntime.addStepCount = addStepCount
			local effectPropId
			if customParams and customParams.effectPropId then
				effectPropId = customParams.effectPropId
			end
			addStepRuntime.propId = effectPropId or usePropId
			addStepRuntime.propType = usePropType
			local addStep = self._sceneRuntimeData.addStep
			if addStep then
				addStep.usePropParams = customParams
			end
			local propUseType = UBFPropUseType.kNormal

			self:onUseProp({
				boardId = 1,
				propId = usePropId,
				usePropType = usePropType,
				propUnitType = UBFPropUnitType.kAddStep5,
				isRevival = true,
				useSource = customParams.useSource
			})
			self:getMessageLogic():sendOperation( UBFOperationType.kProp , {
				propUnitType = UBFPropUnitType.kAddStep5,
				addStepCount = addStepCount,
				propId = usePropId,
				effectPropId = effectPropId,
				propUseType = propUseType,
				isRevival = true,
			}, nil, "player" )
		end,
		onCancelBtnTapped =  function()
			self:getMessageLogic():sendOperation(
				UBFOperationType.kAbandon ,
				{ mode = UBFOperationAbandonType.kGiveUp }, nil, "player"
			)
		end,
		onUpdatePropBarDisplay =  function()

		end,
		-- ubfFakeBoardModel = self:getFakeGameBoardModel(),
		sceneMgr = self,
		fuuuDeviationResult = params.fuuuDeviationResult,
		addStepPanelExtra = params.addStepPanelExtra,
	}
	UBFAddStepPanelUtil:checkAddPopLog(aspPopLog)--3

	local levelInfo = self:getLevelInfo()
	for k , dat in ipairs( levelInfo.usePropList or {} ) do
		if dat.propUnitType == UBFPropUnitType.kAddStep5
			or dat.propUnitType == UBFPropUnitType.kAddStep15 then
				gameParams.passAddTwoButton = true
				break
		end
	end

	local newAddStepStrategy = createAddStepStrategy(gameParams)
	local isFuuuState = false

	if newAddStepStrategy.fuuu then
		local fuuuStrategy = newAddStepStrategy.fuuu
		fuuuStrategy.lastGameIsFUUU = false
		fuuuStrategy.fuuuData = {}
		if params.fuuuProgressData then
			isFuuuState = true
			fuuuStrategy.lastGameIsFUUU = true
			for _ , dat in ipairs( params.fuuuProgressData ) do
				local orders = UBFTallyId:tallyIdToOrderKeys(dat.tallyId)
					if orders then
						dat.okey1 = orders[1]
						dat.okey2 = orders[2]
						if type(dat.okey1) == "number" then dat.okey1 = "order" .. dat.okey1 end
						table.insert(fuuuStrategy.fuuuData, dat)
					else
						table.insert(fuuuStrategy.fuuuData, dat)
					end
			end
		end
	end

	-----------修改打点参数
	local uid = self._sceneData.currUUID
	local levelId = levelInfo.levelId
	local levelScene = levelInfo.levelScene
	local stage = self:getDcStage()
	gameParams.dcParams.isFuuuState = isFuuuState
	gameParams.dcParams.stageState = tostring(stage)

	if levelInfo.levelType == GameLevelType.kWeeklyRace2020 then
		UBFAddStepPanelWeeklyRaceUtil:modifyInitParamsForWeeklyRace(gameParams, newAddStepStrategy)
	end
	UBFAddStepPanelUtil:checkAddPopLog(aspPopLog, "b")--4
	gameParams["aspPopLog"] = aspPopLog --临时，之后可删

	local ubfAddStepPanelInitData, illegalLog = UBFAddStepPanelUtil:getUBFAddStepPanelInitData(gameParams, newAddStepStrategy)
	UBFAddStepPanelUtil:checkAddPopLog(aspPopLog, "d")--15
	ubfAddStepPanelInitData["aspPopLog"] = aspPopLog --临时，之后可删
	local ubfAddStepPanelBuildData = UBFAddStepPanelUtil:getUBFAddStepPaneBuildData(ubfAddStepPanelInitData)
	UBFAddStepPanelUtil:checkAddPopLog(aspPopLog, "j")--36/38
	ubfAddStepPanelBuildData.isDebugPlayMode = self:isDebugPlayMode()
	ubfAddStepPanelBuildData["aspPopViewLog"] = aspPopViewLog --临时，之后可删
	local _data = {
		panelContentViewData = ubfAddStepPanelBuildData.panelViewData.viewData.contentData.viewData
	}
	local event = UBFSceneModEventMap[UBFGameModEventEnum.kUBFAddStepPanelBuildData]:create(_data)
	self:notifyModEvent(event)
	local logic = UBFLogicCreator:createLogic(ubfAddStepPanelBuildData, UBFGameLogics.kAddStepPanel)
	local layer = UBFLayerColor:create()
	logic:buildView(layer)
	layer._BasePanel_Mark_ = true
	self:setAddStepPanelPropBarLock(true)
	UBFGlobal:getLogic("PopoutManager"):add(layer, 0)
	logic:showPanelPopoutTransition(aspPopLog)
	addStepRuntime.logic = logic
	UBFAddStepPanelUtil:checkAddPopLog(aspPopLog, "l")--38/40
	aspPopLog.popLogicFinished = true

	UBFAddStepPanelUtil:addPanelPopoutRecord()
	self:addDelayFunc( 2 , function()
		if params.fuuuProgressData then
			self:flushLastSectionExtra( { fuuuProgressData = params.fuuuProgressData } )
		end
		if params.fuuuDeviationResult then
			self:flushLastSectionExtra( { fuuuDeviationResult = params.fuuuDeviationResult } )
		end
		if params.addStepPanelExtra then
			self:flushLastSectionExtra( { addStepPanelExtra = params.addStepPanelExtra } )
		end
	end )
end


--todo 整理到进关的时候
function UBFGameSceneManager:getDcStage()
	local levelInfo = self:getLevelInfo()
	local levelId = levelInfo.levelId
	local levelType = levelInfo.levelType
	local levelScene = levelInfo.levelScene
	local played = levelInfo.scoreRefIsNil
	local stageState = -1
	local passedLevel
	passedLevel = _G.amfBean("LevelAreaManager"):hasPassedLevelEx(levelId, levelScene)
	if UBFLevelSceneFunc:isMainLevel(levelScene) then
        stageState = levelInfo.stageState or -1
	elseif UBFLevelSceneFunc:isHideLevel(levelScene) then
		stageState = 3
		if passedLevel then
			stageState = '3_2'
		elseif played then
			stageState = '3_1'
		else
			stageState = '3_0'
		end
	elseif UBFLevelSceneFunc:isFullLevelLib(levelScene) then
		stageState = 6
    elseif levelInfo.stageState then
        stageState = levelInfo.stageState
    else
        if passedLevel then stageState = "5_2"
        else stageState = "5_1" end
	end
	return stageState
end

--------------------****** *↓* ******--------------------
--						继承方法
--------------------****** *↑* ******--------------------

function UBFGameSceneManager:popoutScenePanel(scenePanelType, params)

	params = params or {}

	if scenePanelType == UBFGameScenePanels.kPropHelp then
		local propId = params.propId
		if params.propUnitType then propId = propId or UBFPropUnitTypeToItemIdMap[params.propUnitType] end
		self:popoutPropHelpPanel( propId )
		return
	elseif scenePanelType == UBFGameScenePanels.kPausePanel then
		self:popoutQuitPanel( params )
		return
	elseif scenePanelType == UBFGameScenePanels.kBuyPropPanel then
		local propUnitType = params.propUnitType
        local propId = PropMappingForOld.PropUnitTypeToPropIdMap[propUnitType]
        if not propId then return end
		if propUnitType == UBFPropUnitType.kAddStep15 then
			local bubbleViewLogic = self:callGameModule(UBFGameLogics.kPropBar , "getBubbleViewLogic", propUnitType)
			local icon = bubbleViewLogic and bubbleViewLogic:getIcon()
			if icon then
				UBFTooltip:showTip( icon , { message = "此道具礼包已购买完成～" , limitInScreen = false, autoHideDelay = 2 })
			else
				CommonTip:showTip("此道具礼包已购买完成～")
			end
			return
		end

		self:updatePause( 1 )
        self:popoutBuyPropPanel( propUnitType , {
			onBoughtCallback = function(propId, propNum, startPos)
				self:updatePause( -1 )
				safeRunCall(params.onSuccess, propId, propNum)
				local scene = self:getScene()
				local endPos = scene:getPropBubblePosition( ItemIdToUBFPropUnitTypeMap[propId] )
				UBFGamePlaySceneMess:flyBuyProp(scene.topEffectLayer, startPos, endPos, propId, propNum)
			end	,
			onExitCallbackFail = function(errCode, errMsg)
				self:updatePause( -1 )
				safeRunCall( params.onFail )
			end,
			onExitCallbackCancel = function()
				self:updatePause( -1 )
				safeRunCall( params.onCancel )
			end
		})
	elseif scenePanelType == UBFGameScenePanels.kAddStep then
		self:popoutAddStepPanel( params )
	end

end

function UBFGameSceneManager:applyGuideMask( params )
	local scene = self:getScene()
	local guideMask = scene:applyGuideMask()

	guideMask.fadeTime = params.fadeTime
	guideMask.fadeAlpha = params.fadeAlpha

	-- printx(16,tts(params),"applyGuideMask")

	if params.allBoard then guideMask:lightBoard()
	elseif params.grids then guideMask:lightGrids(params.grids,params.touchGrids) end


	guideMask:setClickMaskCallback( params.onTouchMask )
	guideMask:playShow()

	if params.id == "propBar" and not params.noShowUpGuide then
		UBFGamePlaySceneMess:addPropBarTipAnime( guideMask , params.propUnitType )
	end

	return guideMask
end

function UBFGameSceneManager:closeGuideMask( parmas )
	local scene = self:getScene()
	scene:closeGuideMask()
end

function UBFGameSceneManager:_doPropUsageBoard( usageData )
	local sceneMgr = self
	local boardViewLogicList = {}

	self:ergodicBoardViewLogic(function(boardViewLogic)
		if boardViewLogic:canInteractor() then
			table.insert(boardViewLogicList, boardViewLogic)
		end
	end)

	if #boardViewLogicList == 0 then return safeRunCall(usageData.onFail, "cannot find view logic can interactor") end

	local usageId = usageData.type
	local boardId = boardViewLogicList[1].boardId or 1

	if usageId == UBFPropbilityUsage.kImmediate then
		local event = UBFSceneModEventMap[UBFGameModEventEnum.kPropUse]:create {
			success = true,
			params = {
				points = nil,
				type = usageData.type,
				checkPropUnitType = usageData.checkPropUnitType,
				boardId = boardId,
			},
		}
		sceneMgr:notifyModEvent(event)
		safeRunCall(usageData.onSuccess, { boardId = boardId })
		return
	end

	local interactorClazz = nil
	if usageId == UBFPropbilityUsage.kOnePoint then
		interactorClazz = UBFBoardOnePointInteractor
	elseif usageId == UBFPropbilityUsage.kMultiPotion then
		interactorClazz = UBFBoardMultiPointInteractor
	elseif usageId == UBFPropbilityUsage.kOnePointOrient then
		interactorClazz = UBFBoardOnePointOrientInteractor
	end

	if not interactorClazz then
		--
--
--
--

		return safeRunCall(usageData.onFail, "error usage")
	end

	local isFinish = false
	local function onFinish(isSuccess, params)
		if isFinish then return end
		isFinish = true

		for _, boardViewLogic in ipairs(boardViewLogicList) do
			boardViewLogic:setInteractor(UBFBoardSwapInteractor:create())
			boardViewLogic:resetInteractor()
		end

		if isSuccess then safeRunCall(usageData.onSuccess, params)
		else safeRunCall(usageData.onFail, params) end
		local event = UBFSceneModEventMap[UBFGameModEventEnum.kPropUse]:create {
			success = isSuccess,
			params = {
				points = params.points,
				type = usageData.type,
				checkPropUnitType = usageData.checkPropUnitType,
				boardId = boardId,
			},
		}
		sceneMgr:notifyModEvent(event)
	end

	local function startInteract(boardViewLogic)
		local interactor = interactorClazz:create(usageData)

		interactor.onFinish = function(self, isSuccess, params)
			self.onFinish = doNothing
			if isSuccess then
				params.boardId = boardViewLogic.boardId
				if self.finishExtraData then
					for k , v in pairs(self.finishExtraData) do params[k] = v end
				end
				onFinish(true, params)
			else onFinish(false, params) end
		end

		local function initInteractor( interactor )
			interactor:registerListener( UBFBoardOperationEvents.onSuccess, function( evt , params )
				interactor:onFinish( true , params )
			end )

			interactor:registerListener( UBFBoardOperationEvents.onFail, function( evt )
				interactor:onFinish(false, "interactor fail")
			end )

			interactor:registerListener( UBFBoardOperationEvents.onForbid, function( evt , gridPos )
				local x , y = boardViewLogic:getGridAxisOffsetInUIWorldPos(gridPos)
				UBFGamePlaySceneMess:createForbid(x, y)
			end )
		end

		interactor.convert = function(self, newInteractor)
			newInteractor:build(usageData)
			newInteractor.onFinish = self.onFinish
			self.onFinish = doNothing
			initInteractor( newInteractor )
			boardViewLogic:setInteractor( newInteractor )
		end

		initInteractor(interactor)
		boardViewLogic:setInteractor(interactor)
		interactor.finishExtraData = self._fakeClickPropExtra
	end

	for _, boardViewLogic in ipairs(boardViewLogicList) do
		startInteract(boardViewLogic)
	end

	if self._fakeClickPropExtra then self._fakeClickPropExtra = nil end
end

function UBFGameSceneManager:cancelPropUsage()
	local boardViewLogic = self:getBoardViewLogic()
	if not boardViewLogic then return end
	if boardViewLogic:canInteractor() then boardViewLogic:setInteractor( UBFBoardSwapInteractor:create() ) end
end

function UBFGameSceneManager:getFuuuInfo()
	if self._fuuuInfoCache then return UBFPromise:create():resolve(self._fuuuInfoCache) end
	local promise = self:getMessageLogic():sendDataRequire(UBFGameRequireDataKey.kFuuuInfo)
	return promise:next(function(data)
		self._fuuuInfoCache = data
	end)
end
--当前处于连闯N关的第几小关(跟currGameSwitchIndex的区别是，对于可暂离的连闯N关下次继续打时这个会更新，上面还是从0开始）
function UBFGameSceneManager:getCurrTravelIndex()
	local eventData = {currTravelIndex = 1 }
	local event = UBFSceneModEventMap[UBFGameModEventEnum.UPDATA_CURRTRAVELINDEX]:create(eventData)
	self:notifyModEvent(event)
	return eventData.currTravelIndex
end

function UBFGameSceneManager:isUBFUi()
	return self._isUbfUi
end

--------------------****** *↓* ******--------------------
--						 兼容
--		   预期目前需要，后面这个部分就会被删除了！
--------------------****** *↑* ******--------------------

--是否弃用向旧兼容逻辑 , 已废弃
function UBFGameSceneManager:isEnableFakeLogic()
	return self._oldLevelConfig
end

function UBFGameSceneManager:runFakeCall( func )
	if self:isEnableFakeLogic() then func() end
end

function UBFGameSceneManager:getGamePlayBridge()
	if self._gamePlayBridge then return self._gamePlayBridge end
	local creator = require "ubf.UBFGamePlayScene.logics.bridge.compatible.FakeGamePlayBridge"
	self._gamePlayBridge = creator(self)
	return self._gamePlayBridge
end

function UBFGameSceneManager:getFakeNewGamePlaySceneUI()
	if self._fakeNewGamePlaySceneUI then return self._fakeNewGamePlaySceneUI end
	local creator = require "ubf.UBFGamePlayScene.logics.bridge.compatible.FakeGameNewGamePlaySceneUI"
	self._fakeNewGamePlaySceneUI = creator(self)
	return self._fakeNewGamePlaySceneUI
end

function UBFGameSceneManager:getFakeGameBoardLogic()
	return self:getFakeNewGamePlaySceneUI().gameBoardLogic
end

function UBFGameSceneManager:getFakeGameBoardModel()
	return self:getFakeGameBoardLogic().gameBoardModel
end

function UBFGameSceneManager:_setFakeBoardView(boardView)
	self:getFakeGameBoardLogic().boardView = boardView
	self:getFakeNewGamePlaySceneUI().gameBoardView = boardView
	boardView.gameBoardLogic = self:getFakeGameBoardLogic()
	boardView.PlayUIDelegate = self:getFakeNewGamePlaySceneUI()
end

function UBFGameSceneManager:clearAllFake()
	self._oldLevelConfig = nil
	self._fakeNewGamePlaySceneUI = nil
	self._gamePlayBridge = nil
end

--------------------****** *↓* ******--------------------
--						Debug
--------------------****** *↑* ******--------------------

function UBFGameSceneManager:isDebugPlayMode()
	local isDebugPlayMode = self:getScene():isDebugPlayMode()
	--
--
--
--
--

	return isDebugPlayMode
end
