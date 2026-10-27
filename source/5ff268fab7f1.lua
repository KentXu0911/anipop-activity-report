
local CrashResumeHandler = class("CrashResumeHandler")

function CrashResumeHandler:create(autoPopupMgr)
	local handler = CrashResumeHandler.new()
	handler:init(autoPopupMgr)
	return handler
end

function CrashResumeHandler:init(autoPopupMgr)
	self._autoPopupMgr = autoPopupMgr
	AutoPopEventCenter:register(AutoPopEvent.CRASH_RESUME, self.onHandlePopup, self)
end

function CrashResumeHandler:clearOthers(popupCheckPoint)
	local popType = self._autoPopupMgr:getPopType(popupCheckPoint)
	self._autoPopupMgr:clearPopupQueueByPopType(popType)
end

function CrashResumeHandler:onHandlePopup(evt)
	local data = evt:getData()
	local popupCheckPoint = data.popupCheckPoint
	local params = data.params
	lua_switch(popupCheckPoint){
		[PopupCheckPoint.CRASH_RESUME_MAIN] = function ()
			self:handleMainAndHide(params)
		end,
		[PopupCheckPoint.AUTO_START_LEVEL] = function ()
			self:handleAutoStartLevel(params)
		end,
		[PopupCheckPoint.AUTO_START_LEVEL_BACK_USER] = function ()
			self:handleBackUserAutoStartLevel(params)
		end,
		[PopupCheckPoint.AUTO_START_LEVEL_DY_FEED] = function ()
			self:handleDouyinFeedAutoStartLevel(params)
		end,
		[PopupCheckPoint.AUTO_START_LEVEL_WX_FEED_TRIAL] = function ()
			self:handleWXFeedTrialAutoStartLevel(params)
		end,
		[PopupCheckPoint.RECALL_OPEN_START_PANEL] = function ()
			self:handleRecallOpenStartPanel(params)
		end,
		default = function ()
			assert(false, "CrashResumeHandler invalid popupCheckPoint : " .. tostring(popupCheckPoint))
		end
	}
end

function CrashResumeHandler:handleMainAndHide(params)
	local crashResumeLogic = params.logic
	if not crashResumeLogic then return end

	local bGetOtherContextSucess = params.bGetOtherContextSucess
	local otherDevicePlayingContextInfo = params.otherDevicePlayingContextInfo

	local function onHandleOver()
		self:clearOthers(PopupCheckPoint.CRASH_RESUME_MAIN)
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER , PopupCheckPoint.CRASH_RESUME_MAIN)
    end

    local function creator()
    	local AsyncRunner = require "amf.script.sugar.AsyncRunner"

		local function onResp(canResume, errCode)
			local cantResumeParams
			if not canResume then
				cantResumeParams = crashResumeLogic:getLastResumeFailData()
			end

			local asyncRunner = AsyncRunner:create()

			asyncRunner:add(function (done)
				if _G.amfBean("ActivityMgr"):checkActInfoInited() then
					safeRunCall(done)
				else
					--等1秒，活动信息回来
					setTimeOut( done, 1 )
				end
			end)

			if bGetOtherContextSucess then
				asyncRunner:add(function (done)
					--处理别的设备打关弹板
					self:handleBeforeMainAndHide( otherDevicePlayingContextInfo, done )
				end)
			end

			if canResume then
				asyncRunner:add(function (done)
					--闪退恢复
					crashResumeLogic:handleMiniGameResume():next(function (resumed)
						if resumed then
							self._autoPopupMgr:resetPopup()
						else
							safeRunCall(done)
						end
					end)
				end)
			else
				asyncRunner:add(function (done)
					--闪退不能恢复
					--尝试弹出连胜不能恢复面板
					if cantResumeParams and errCode and errCode == UBFGameResumeFailReason.kCrashOver1Hour then
						self:handleMainAndHideFail({_data = cantResumeParams}, done)
					else
						safeRunCall(done)
					end
				end)
			end

			asyncRunner:add(function (done)
				safeRunCall(onHandleOver)
			end)

			asyncRunner:run()
		end
		crashResumeLogic:checkCanResume(onResp)

    end
    self._autoPopupMgr:addPopupConfig(PopupCheckPoint.CRASH_RESUME_MAIN, creator)
end

function CrashResumeHandler:handleBeforeMainAndHide( otherDevicePlayingContextInfo, done )

	local bShowLog = true
	local function showLog( ... )
		if EnvUtil:isDevelopMode() and bShowLog then
			printx(12,"***断鸟弹板检测***", ...)
			-- UError(12,"***断鸟弹板检测***", ...)
		end
	end

	-- local actInfos = {}
	-- local _popData = {
	-- 	actInfos = actInfos,
	-- 	activeActIds = otherDevicePlayingContextInfo.activeActIds or {}
	-- }
	-- if _G.UBF_AMF_ENABLED_FLAG then
	-- 	_G.amfEC:notifyFeature(FeatureEvent.CRASH_RESUME_BEFORE_POP, _popData)
	-- else
	-- 	LocalActCoreModel:getOrCreateInstance():notify(ActInterface.kCrashResumeBeforePopPanel, _popData)
	-- end

	local bInON2Group = MaintenanceManager:getInstance():isEnabledInGroup( "superBird_crashRecovery", "ON2" )

	-- showLog( "后端返回参数",tts(otherDevicePlayingContextInfo) )
	-- showLog( "活动参数",tts(actInfos) )
	-- showLog( "分组信息", bInON2Group  )

	local actInfos = {}

	if otherDevicePlayingContextInfo.activeStreakMap then
		for i,v in pairs(otherDevicePlayingContextInfo.activeStreakMap) do
			local info = {}
			info.actId = tonumber(i)
			info.winNum = tonumber(v)
			table.insert(actInfos,info)
		end
	end

	-- printx(12,"handleBeforeMainAndHide",tts(actInfos),tts(params) )
	if #actInfos > 0 then
    	if bInON2Group then
    		-- showLog( "可以弹面板" )
    		self:createResumeBeforepanel( otherDevicePlayingContextInfo, actInfos, done )
	    else
	    	-- showLog( "只打点" )

	    	--不能弹板，打点
			local dcT1 = ""
			local dcT3 = ""

			for i,v in ipairs(actInfos) do
				if i== 1 then
					dcT1 = dcT1 .. v.actId
					dcT3 = dcT3 .. v.actId.."_"..v.winNum
				else
					dcT1 = dcT1 .. "_" .. v.actId
					dcT3 = dcT3 .. ";" .. v.actId.."_"..v.winNum
				end
			end
			--dc
		    local params = {
		    	category = "crash_resume",
		        sub_category = "switch_device_show",
		        t1 = dcT1,
		        t2 = otherDevicePlayingContextInfo.levelId,
		        t3 = dcT1,
		    }
		    DcUtil:dcForUserTrack(params)

		    --清打关信息
			_G.amfBean("UserLevelContextManager"):clearOtherDevicePlayingContext()

		    safeRunCall(done)
	    end
	else
		safeRunCall(done)
	end
end

function CrashResumeHandler:handleMainAndHideFail( params, done )
	local _data = params._data

	--弹出超鸟断的面板
	local showPanelParams = {
		levelId = _data.levelId,
		json = _data.json,
	}

	local function getPanelNeedParams()
		local breakWinNames = {}
		local actIds = {}
		local _popData = {
			json = showPanelParams.json or {},
			breakWinNames = breakWinNames,
			actIds = actIds,
		}

		if _G.UBF_AMF_ENABLED_FLAG then
			_G.amfEC:notifyFeature(FeatureEvent.CRASH_RESUME_FAILED_POP, _popData)
		else
			LocalActCoreModel:getOrCreateInstance():notify(ActInterface.kCrashResumeFailedPopPanel, _popData)
		end

		local panelParams = {}
		panelParams.levelId = showPanelParams.levelId
		panelParams.breakWinNames = breakWinNames
		panelParams.actIds = actIds

		return panelParams
	end

	local panelParams = getPanelNeedParams()
	if #panelParams.breakWinNames > 0 then
		self:createResumeFailpanel( panelParams, done)
	else
		safeRunCall(done)
	end
end

function CrashResumeHandler:createResumeFailpanel(panerlParams, onHandleOver)
	local levelId = panerlParams.levelId

	local panelId = UICreateUtil:getPanelId("createResumeFailpanel")

	local FourthPanelAVM = require "amf.middleware.ui.kit.panel.fourth.FourthPanelAVM"

	local dcT1 = ""
	for i,v in ipairs(panerlParams.actIds) do
		if i== 1 then
			dcT1 = dcT1 .. v
		else
			dcT1 = dcT1 .. "_".. v
		end
	end

	local TimeUtil = require 'amf/middleware/ui/util/TimeUtil.lua'
	local timeSecStr = TimeUtil:formatDuration_dh_hm_ms(UBFSectionResumeHelper.TIME_OUT, 2)
	local timeStr = "数据恢复有效期为"..timeSecStr
	local text = "检测到你上次意外退出关卡，未在数据恢复有效期（"..timeSecStr.."）内恢复进度，导致"

	local bHasSuperMagicBird = false
	for i,v in ipairs(panerlParams.actIds) do
		if v == 8068 then
			bHasSuperMagicBird = true
			break
		end
	end

	if bHasSuperMagicBird then
		text = text.."超级魔力鸟中断。"
	else
		text = text.."连胜中断。"
	end

	local vm
	vm = FourthPanelAVM.Builder.new()
        :setText(text)
        :setButtonsConfig({
			{
				str = "确认",
				widthMode = UIButtonConfig.Widths.kShort,
				colorMode = UIButtonConfig.ColorMode.green,
				touchFunc = function(btn)
					--dc
				    local params = {
				    	category = "crash_resume",
				        sub_category = "vine_notice_click",
				        panel_id = panelId,
				        t1 = dcT1,
				    }
				    DcUtil:dcForUserTrack(params)
					vm:onCloseBtnTapped()

					-- local mgr = _G.amfBean("SuperMagicBird2024Manager")
					-- if mgr then
					-- 	mgr:refreshIconProgress()
					-- end
				end
			},
    	})
		:setCloseCallback(function()
			safeRunCall(onHandleOver)
		end)
		:build()
	vm:popout()

	--dc
    local params = {
    	category = "crash_resume",
        sub_category = "vine_notice_show",
        panel_id = panelId,
        t1 = dcT1,
    }
    DcUtil:dcForUserTrack(params)
end

local AMFRequest = require "amf.middleware.interconnection.remote.core.AMFRequest"
local Request = class("closePlayingContext", AMFRequest)
local config = {
    protocol = "closePlayingContext",
    reqType = AMFSyncConst.RequestType.OFFLINE,
    loading = false,
    useMockData = false
}

function Request:post(params, hostObj)
    return Request:run(config, params, hostObj)
end

function CrashResumeHandler:createResumeBeforepanel(otherDevicePlayingContextInfo, actInfos, onHandleOver)
	local levelId = otherDevicePlayingContextInfo.levelId

	local panelId = UICreateUtil:getPanelId("createResumeBeforepanel")

	local curAppName = "app"
	local otherAppName = otherDevicePlayingContextInfo.miniGame and "mini" or "app"
	if EnvUtil:isMiniGame() then
		curAppName = "mini"
	end

	local deviceStr = "其他设备"
	if curAppName ~= otherAppName then
		if otherAppName == "app" then
			deviceStr = "APP"
		elseif otherAppName == "mini" then
			deviceStr = "小游戏"
		end
	end

	local dcT1 = ""
	local dcT3 = ""
	local text = "检测到你上次在"..deviceStr.."的第"..levelId.."关意外退出关卡，请尽快回到上一个设备继续。如果使用当前设备闯关，将会中断"
	local btnText = ""
	local bHasSuperMagicBird = false
	for i,v in ipairs(actInfos) do
		if v.actId == 8068 then
			bHasSuperMagicBird = true
			break
		end
	end

	if bHasSuperMagicBird then
		text = text.."超级魔力鸟。"
		btnText = "中断超级魔力鸟"
	else
		text = text.."连胜。"
		btnText = "中断连胜"
	end

	for i,v in ipairs(actInfos) do
		if i== 1 then
			dcT1 = dcT1 .. v.actId
			dcT3 = dcT3 .. v.actId.."_"..v.winNum
		else
			dcT1 = dcT1 .. "_" .. v.actId
			dcT3 = dcT3 .. ";" .. v.actId.."_"..v.winNum
		end
	end

	local FourthPanelAVM = require "amf.middleware.ui.kit.panel.fourth.FourthPanelAVM"

	local _Data = {
		actInfos = actInfos,
		createPanelFuncList = {},
	}

	local vm
	vm = FourthPanelAVM.Builder.new()
        :setText(text)
        :setButtonsConfig({
            {
				str = btnText,
				widthMode = UIButtonConfig.Widths.kShort,
				colorMode = UIButtonConfig.ColorMode.red,
				touchFunc = function(btn)
					--发协议

					local udid = MetaInfo:getInstance():getUdid()
					Request:post({deviceUdid=udid,extra=otherDevicePlayingContextInfo.extra})
					_G.amfBean("HttpManager"):syncLite()

					--断连胜
					_G.amfEC:notifyFeature(FeatureEvent.CRASH_RESUME_BEFORE_POP_CONFIRM, _Data)

					--清打关信息
					_G.amfBean("UserLevelContextManager"):clearOtherDevicePlayingContext()

					--关面板
					vm:onCloseBtnTapped()

					--dc
				    local params = {
				    	category = "crash_resume",
				        sub_category = "switch_device_click",
				        panel_id = panelId,
				        t1 = dcT1,
				        t2 = 1
				    }
				    DcUtil:dcForUserTrack(params)
				end
			},
			{
				str = "退出游戏",
				widthMode = UIButtonConfig.Widths.kShort,
				colorMode = UIButtonConfig.ColorMode.green,
				touchFunc = function(btn)
					--dc
				    local params = {
				    	category = "crash_resume",
				        sub_category = "switch_device_click",
				        panel_id = panelId,
				        t1 = dcT1,
				        t2 = 2
				    }
				    DcUtil:dcForUserTrack(params)

				    setTimeOut( function()
				    	if vm.isDisposed then return end
				    	vm:onCloseBtnTapped()
						Director.sharedDirector():exitGame()
					end, 0.1)

				end
			},
    	})
		:setCloseCallback(function()
			local AsyncRunner = require "amf.script.sugar.AsyncRunner"
			local asyncRunner = AsyncRunner:create()

			for i,v in ipairs(_Data.createPanelFuncList) do
				asyncRunner:add(function (done)
			        v(done)
			    end)
			end

			asyncRunner:add(function (done)
		        safeRunCall(onHandleOver)
		    end)

			asyncRunner:run()
		end)
		:setCloseBtnVisible(false)
		:build()
	vm:popout()

	--dc
    local params = {
    	category = "crash_resume",
        sub_category = "switch_device_show",
        panel_id = panelId,
        t1 = dcT1,
        t2 = levelId,
        t3 = dcT3,
    }
    DcUtil:dcForUserTrack(params)
end

function CrashResumeHandler:handleAutoStartLevel(params)
	local levelId = params.levelId
	local costType = params.costType
	local source = params.source

	local function onHandleOver()
		self:clearOthers(PopupCheckPoint.AUTO_START_LEVEL)
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER , PopupCheckPoint.AUTO_START_LEVEL)
    end

	local function creator()
		-- AP 模式下跳过闪退恢复自动进关：闪退恢复路径没有注入 SuperPlayer，无法捕获逻辑线程上报的 snap，导致关卡内无法决策。
		-- TODO: 未来改为前端在 kWating 时直接从逻辑层取 snap，不再依赖逻辑层主动上报， 届时可去掉此 guard，闪退恢复与正常进关对 AP 透明。
		if _G.AutoPlayEnv then
			onHandleOver()
			return
		end
		require ("ubf.UBF.utils.UBFCommonRequire")("*")

		-- local itemList, usePropList = {}, {}
		-- DcUtil:log(AcType.kExpire30Days, {
		-- 	category = "start_level",
		-- 	sub_category = "auto_start_level",
		-- 	levelId = levelId,
		-- 	itemList = ttsd(itemList),
		-- 	usePropList = ttsd(usePropList),
		-- 	costType = costType,
		-- 	source = source
		-- })

		local angry = UBFGameLoadingController:apply({
			source = UBFGameLoadingSourceEnum.ORDINARY,
			levelId = levelId,
			toleratedTime = 0,
		}):retain()

		local process = UBFProcessManager:launch(UBFGameProcessEnum.MANUAL_START, {
			levelId = levelId,
		})
		process:operate(UBFProcessNodeEnum.WAIT_MANUAL, {
			energyCostType = costType,
			finish = true,
		})
		process:afterEnd():next(function()
			angry:release()
			self._autoPopupMgr:resetPopup()
		end)
		process:afterAbort():next(function()
			angry:release()
			onHandleOver()
		end)
	end

	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.AUTO_START_LEVEL, creator)
end


function CrashResumeHandler:handleBackUserAutoStartLevel(params)
	local levelId = params.levelId
	local costType = params.costType
	local logic = params.logic

	local function onHandleOver()
		self:clearOthers(PopupCheckPoint.AUTO_START_LEVEL_BACK_USER)
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER , PopupCheckPoint.AUTO_START_LEVEL_BACK_USER)
    end

	local function creator()

		local function realPopFunc()
			require ("ubf.UBF.utils.UBFCommonRequire")("*")

			local angry = UBFGameLoadingController:apply({
				source = UBFGameLoadingSourceEnum.ORDINARY,
				levelId = levelId,
				toleratedTime = 0,
			}):retain()
			local process = UBFProcessManager:launch(UBFGameProcessEnum.MANUAL_START, {
				levelId = levelId,
				continuePlayMode = true,
			})

			process:operate(UBFProcessNodeEnum.WAIT_MANUAL, {
				energyCostType = costType,
				finish = true,
			})
			process:afterEnd():next(function()
				angry:release()
				self._autoPopupMgr:resetPopup()
			end)

			process:afterAbort():next(function()
				angry:release()
				onHandleOver()
			end)
			if logic then logic:setAutoEntered() end
		end

		local function notifyAutoStartLevelBackUser()
			local eventData = {
				callback = realPopFunc,
			}
			_G.amfEC:notifyFeature(FeatureEvent.AUTO_START_LEVEL_BACK_USER, eventData)
			if not eventData.handled then
				realPopFunc()
			end
		end

		if _G.amfBean("ActivityMgr"):checkActInfoInited() then
			notifyAutoStartLevelBackUser()
		else
			--给1秒延迟，等actInfo返回。 超鸟回流进关修改
			setTimeOut(notifyAutoStartLevelBackUser, 1)
		end
	end
	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.AUTO_START_LEVEL_BACK_USER, creator)
end

function CrashResumeHandler:handleDouyinFeedAutoStartLevel(params)
	self:handleFeedTrialAutoStartLevel(params)
end

function CrashResumeHandler:_interceptFeedTrialEnd(onLevelDone)
	local origLaunchEndLevel = UBFProcessManager._launchEndLevelProcess
	local hookActive = true
	local hookFn
	hookFn = function(mgr, processType, runtime)
		if not hookActive then
			return origLaunchEndLevel(mgr, processType, runtime)
		end
		hookActive = false
		UBFProcessManager._launchEndLevelProcess = origLaunchEndLevel

		local endProcess = origLaunchEndLevel(mgr, processType, runtime)
		endProcess:afterEnd():next(function()
			safeRunCall(onLevelDone, {
				reason = "end_level_ended",
				processType = processType,
			})
		end)
		endProcess:afterAbort():next(function()
			safeRunCall(onLevelDone, {
				reason = "end_level_aborted",
				processType = processType,
			})
		end)
		return endProcess
	end
	UBFProcessManager._launchEndLevelProcess = hookFn

	return function()
		if hookActive then
			hookActive = false
			UBFProcessManager._launchEndLevelProcess = origLaunchEndLevel
		end
	end
end

function CrashResumeHandler:handleWXFeedTrialAutoStartLevel(params)
	params = params or {}
	self:handleFeedTrialAutoStartLevel(params)
end

function CrashResumeHandler:handleFeedTrialAutoStartLevel(params)
	params = params or {}
	local popupCheckPoint = params.popupCheckPoint or PopupCheckPoint.AUTO_START_LEVEL_DY_FEED

	local function onHandleOver()
		self:clearOthers(popupCheckPoint)
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, popupCheckPoint)
	end

	local function creator()
		self:startFeedTrialLevel(params, onHandleOver)
	end

	self._autoPopupMgr:addPopupConfig(popupCheckPoint, creator)
end

function CrashResumeHandler:startFeedTrialLevel(params, onTrialFinished)
	params = params or {}
	local popupCheckPoint = params.popupCheckPoint or PopupCheckPoint.AUTO_START_LEVEL_DY_FEED
	local levelId = params.levelId
	local levelScene = params.levelScene or UBFLevelSceneType.kTrial
	local costType = params.costType or StartLevelCostType.kInfiniteEnergy
	local logic = params.logic
	local runtimeExtra = params.runtimeExtra or {}
	local isTrialLevelScene = levelScene == UBFLevelSceneType.kTrial

	require ("ubf.UBF.utils.UBFCommonRequire")("*")

	local angry = UBFGameLoadingController:apply({
		source = UBFGameLoadingSourceEnum.ORDINARY,
		levelId = levelId,
		levelScene = levelScene,
		toleratedTime = 0,
	}):retain()

	local angryReleased = false
	local function releaseAngry()
		if angryReleased then return end
		angryReleased = true
		angry:release()
	end

	local handled = false
	local restoreEndLevelHook
	local function finishTrial(result)
		if handled then return end
		handled = true
		if restoreEndLevelHook then restoreEndLevelHook() end
		if isTrialLevelScene and logic and logic.onTrialFinished then
			logic:onTrialFinished(result)
		end
		safeRunCall(onTrialFinished, result)
	end

	local started = false
	local function startTrialLevel()
		if started then return end
		started = true

		if isTrialLevelScene then
			restoreEndLevelHook = self:_interceptFeedTrialEnd(finishTrial)
		end

		if isTrialLevelScene and logic and logic.onTrialAutoStart then
			logic:onTrialAutoStart(params)
		elseif logic and logic.onFeedAutoStart then
			logic:onFeedAutoStart(params)
		end

		runtimeExtra.feedNewUserType = params.feedNewUserType
		local process = UBFProcessManager:launch(UBFGameProcessEnum.MANUAL_START, {
			levelId = levelId,
			levelScene = levelScene,
			source = params.processSource,
			extra = runtimeExtra,
		})
		process:operate(UBFProcessNodeEnum.WAIT_MANUAL, {
			energyCostType = costType,
			finish = true,
		})
		process:afterEnd():next(function()
			releaseAngry()
			if not isTrialLevelScene then
				self._autoPopupMgr:resetPopup()
			end
		end)
		process:afterAbort():next(function()
			releaseAngry()
			finishTrial({
				reason = "start_level_aborted",
			})
		end)
	end
	startTrialLevel()

	return true
end


function CrashResumeHandler:handleRecallOpenStartPanel(params)
	local levelId = params.levelId

	local function onHandleOver()
		self:clearOthers(PopupCheckPoint.RECALL_OPEN_START_PANEL)
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.RECALL_OPEN_START_PANEL)
	end

	local function creator()
		require ("ubf.UBF.utils.UBFCommonRequire")("*")

		local process = UBFProcessManager:launch(UBFGameProcessEnum.NORMAL_START, {
			levelId = levelId,
			extra = {
				recallGuideHand = true,
			},
		})
		process:afterEnd():next(function()
			self._autoPopupMgr:resetPopup()
		end)
		process:afterAbort():next(function()
			onHandleOver()
		end)
	end

	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.RECALL_OPEN_START_PANEL, creator)
end

return CrashResumeHandler
