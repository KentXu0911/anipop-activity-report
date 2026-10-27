local FeedContext = require("amf.middleware.feed.FeedContext")
local VsmSwitch = require "ubf.UBFPlay.views.vsm.VsmSwitch"

local UBFELSendPassLevelProcess = class2("UBFELSendPassLevelProcess", UBFProcessNode)

function UBFELSendPassLevelProcess:doProcess()
    self:passLevel()
end

function UBFELSendPassLevelProcess:isFailByGiveUp()
    local runtime = self:get("runtime")
	local win = runtime:isWin()
	if not win then
		local failReason = runtime:getLevelFailReason()
		return failReason == _G.UBFGameFailReason.kDropout
	end

	return false
end

function UBFELSendPassLevelProcess:isNeedRetry( ... )
	local runtime = self:get("runtime")
	local win = runtime:isWin()
	if not win then
		local failReason = runtime:getLevelFailReason()
		return failReason == _G.UBFGameFailReason.kRetry
	end

	return false
end


function UBFELSendPassLevelProcess:genBaseRequest()
    local runtime = self:get("runtime")
    local prevSceneMgr = runtime:getPrevSceneManager()
	local coin = prevSceneMgr:getLevelCoinCount()
	local league = runtime:getLeague()
	local costMove = league.moveCountWithRevert

    local levelId = runtime:getLevelId()
	local levelScene = runtime:getLevelScene() or UBFLevelSceneType.kMain
	local star = runtime:getStar()
	local score = runtime:getTotalScore()

	local stageTime = runtime:getStageTime()
	local targetCount = runtime:getTargetCount()
	local opLog = runtime:getReplayLog()
	local levelType = runtime:getLevelType()
	local leftMoves = runtime:getLeftMove()
	local seed = runtime:getSeed()
	local oldScore = runtime:getOldScore()
	local oldStar = runtime:getOldStar()
	local playLevelMode = runtime:getPlayLevelMode()
	local staticSteps = runtime:getStaticMove()
	local playInfo = prevSceneMgr:getPlayInfoDCObj()
	local extraData = {}
	extraData.playInfo = playInfo
	extraData.leftMoves = leftMoves
	extraData.costMove = costMove
	extraData.realCostMove = league.moveCount
	extraData.moveCountWithoutExtraMove = league.moveCountWithoutExtraMove

	local hadPassed = runtime:getLevelHasAlreadyPassed()
	local guideLevel = runtime:isGuideLevel()
	
	-- replayModeWhenStart
	local replayModeWhenStart = 0
    if runtime:isWonderfulReplayMode() then replayModeWhenStart = ReplayMode and ReplayMode.kReview or 13 end

	-- 道具
	local usedProps = {}
	local usePropList = runtime:getUsePropList()
	local usePropMap = {}
	for i, propData in ipairs(usePropList) do
        local itemId = propData.propId
		if itemId then 
			usePropMap[itemId] = (usePropMap[itemId] or 0) + 1
		end
    end
	for itemId, num in pairs(usePropMap) do 
		table.insert(usedProps, {itemId = itemId, num = num})
	end

	local hasUsedProp = false
	if #usedProps > 0 then hasUsedProp = true end
	local hasRealUseProp = 3

	-- 不知道是啥
	local extraStr = "0"
	if costMove >= 5 or star > 0 then
		extraStr = "1"
	end

	local farmingType = runtime:getLevelFarmingType()
	local clientStreakWinScene
	if levelScene == UBFLevelSceneType.kFullLevelLibrary then
		clientStreakWinScene = "FLFSLL"
	elseif levelScene == UBFLevelSceneType.kMain then
		if farmingType == UBFLevelFarmingType.NORMAL then
			clientStreakWinScene = "MLT"
		elseif farmingType == UBFLevelFarmingType.FARM_STAR then
			--满级补星
			local userStateManager = _G.amfBean("UserStateManager")
			if userStateManager and not userStateManager:isFMJ() then
				clientStreakWinScene = "FLCCS"
			end
		end
	end

	--生成request
	local request = {
		method = UBFGameMethodType.kPassLevel,
		tip = false,
		body = {
			levelId = levelId,
			score = score,
			star = star,
			oldStar = oldStar,
			stageTime = stageTime,
			coin = coin,
			targetCount = targetCount,
			levelType = levelType,
			step = costMove,
			realStep = league.moveCount,
			staticSteps = staticSteps,
			sfFlag = 0,
			seed = seed or 0,
			opLog = opLog,
			levelLeftMoves = leftMoves,
			levelScene = levelScene,
			usedProps = usedProps,
			hasUsedProp = hasUsedProp,
			hasRealUseProp = hasRealUseProp,
			requestTime = Localhost:time(),
			extraData = extraData,
			extraRewards = {},
			clientStreakWinScene = clientStreakWinScene,
			extra = extraStr,
			guideLevel = guideLevel,
			giveUp = false,
			logicalFail = false,
			lastEnterTime = runtime:getStartLevelStartTime() or runtime:getStageStartTime() or 0,
			version = _G.bundleVersion,
			curMd5 = ResourceLoader.getCurVersion(),
			levelUniqueKey = UBFGamePlayBridgeInvoker:getCurrLevelUniqueKey(),
			-- metaConfig = UBFGamePlayBridgeInvoker:getCurrUBFLevelGroupInfo(levelId),
			replayModeWhenStart = replayModeWhenStart,
			useSmallRes = _G.__use_small_res, --也不知道干啥用的，补上
		},
	}

	UBFGamePlayBridgeInvoker:injectUBFLevelGroupData(request.body, levelId, levelScene)

	-- fuuu 数据
	local UBFEndLevelData = require 'ubf.UBFPlay.data.UBFEndLevelData'
	local endLevelData = UBFEndLevelData.new()
	endLevelData:fromLua(runtime:getEndLevelData())
	local ubfuuu = endLevelData:getUBFuuuDcData()
	if ubfuuu then 
		local dataEx = { diffFix = ubfuuu.diffFix, endData = endLevelData }
		dataEx.diffFix = ubfuuu.diffFix
		dataEx.preAddSteps = ubfuuu.preAddSteps
		dataEx.addSteps = ubfuuu.addSteps
		dataEx.payTag = ubfuuu.payTag
		dataEx.activityTag = ubfuuu.activityTag
		dataEx.useOtherPreProp = ubfuuu.useOtherPreProp
		dataEx.selfFeedbackCollect = ubfuuu.selfFeedbackCollect
		dataEx.passCollectByUseProp = ubfuuu.passCollectByUseProp
		self:_injectFuuu(request.body, levelId, dataEx, levelScene) 
	end

	return request
end


function UBFELSendPassLevelProcess:beforeSend(request)
	self:_beforeSendAMF(request)
	return
end

function UBFELSendPassLevelProcess:_beforeSendAMF(request)
	local opLog = request.body.opLog

	local runtime = self:get("runtime")
	self:dispatchModEvent(UBFGameModEventEnum.kBeforeSendPassLevel, {
		body = request.body,
		jsonTable = request.body.jsonTable,
		overData = runtime:getEndLevelData(),
	})
	if type(opLog) == "table" then
		xpcall(function() request.body.opLog = table.serialize(opLog) end,
	    function(err)
	        if _G.isLocalDevelopMode then
		        local traceback = debug.traceback("", 2)
		        print(table.tostring(opLog))
		        print(err,traceback)
		    end
			local str = ""
			pcall(function() str = tts(opLog) end)
			he_log_error("passLevel oplog serialize fail." .. tostring(err) .. " - " .. tostring(str))
		end)
	end
	local jsonTableNew = {}
	for k, v in pairs(request.body.jsonTable or {} ) do
		jsonTableNew[tostring(k)] = v
	end
	request.body.json = table.serialize(jsonTableNew)
end

function UBFELSendPassLevelProcess:passLevel()
    if FeedContext.shouldPlayTrialLevel() then -- 体验关不需要真实过关流程
        self:success()
        return
    end

    local runtime = self:get("runtime")
	local win = runtime:isWin()

	--云游戏失败成功不发请求，重玩退出发
	if _G.isYunGame then
		local giveUp = self:isFailByGiveUp()
		local needRetry = self:isNeedRetry()
		if giveUp then
			self:passLevelGiveUp()
		elseif needRetry then
			self:passLevelRetry()
		else
			self:success()
		end
	else
		if win then
			self:passLevelWin()
		else
			local giveUp = self:isFailByGiveUp()
			local needRetry = self:isNeedRetry()
			-- printx(16,giveUp,needRetry,"-----------------------")
			if giveUp then
				self:passLevelGiveUp()
			elseif needRetry then
				self:passLevelRetry()
			else
				self:passLevelFail()
			end
		end
	end
end



function UBFELSendPassLevelProcess:passLevelWin()
    local runtime = self:get("runtime")
	local request = self:genBaseRequest()
	-- 过关记录写入进关时冻结的视图模式，而不是下局调试开关。
	request.body.viewmode = VsmSwitch:getViewMode()
	request.body.logicalWin = false
	local opLog = request.body.opLog
	local result = opLog and opLog.result
	if result then
		request.body.logicalWin = opLog.result.logicalWin
	end
	request.body.logicalFail = false
	request.body.giveUp = false

	local netMgr = runtime:getNetworkMgr()

	--发送事件
	netMgr:dispatch(request)

	--生成标识
	request.body.cacheCode = self:calcSig(request.body)

	--发送！
	self:_dumpPassLevelToFile(request)
	self:beforeSend(request)
	netMgr:send(request):next(function(reponse)		
		if reponse.err then
			self:dispatchGlobalEvent(UBFProcessEventEnum.AFTER_REQUEST_SEND, reponse)
			local levelId = runtime:getLevelId()
			UBFError("levelId=" .. tostring(levelId) .. " onPassLevelMsgFailed:" .. table.tostring(reponse.errMsg))
			if _G.isLocalDevelopMode then CommonTip:showTip("过关请求返回失败！！这不应该走到！！ 是不是没有配关卡奖励？？！！") end
			self:abort("pass level http fail")
			return
		else
			self:afterSendMessage(runtime, reponse)
			self:success()
		end
	end)
end

function UBFELSendPassLevelProcess:calcSig(body)
	local params = {}
	params.levelId = body.levelId
	params.score = body.score
	params.star = body.star
	params.coin = body.coin
	params.targetCount = body.targetCount
	params.requestTime = body.requestTime
	params.opLog = body.opLog and true or false
	params.version = body.version
	params.curMd5 = body.curMd5
	params.curConfigMd5 = body.curConfigMd5
	params.udid = MetaInfo:getInstance():getUdid()

    local paramKeys = {}
    for k, v in pairs(params) do
        table.insert(paramKeys, k)
    end
    table.sort(paramKeys)
    local md5Src = ""
    for _, v in pairs(paramKeys) do
        md5Src = md5Src..tostring(params[v])
    end
    local secret = "q6kkSK1ZTdXRE8XuSnXDAvpgQNU!CcaH"
    return HeMathUtils:md5(md5Src .. secret)
end

function UBFELSendPassLevelProcess:_dumpPassLevelToFile(request)
	if not EnvUtil:isCoderDevice() then return end
	pcall(function()
		local runtime = self:get("runtime")
		local outputData = {
			playId = runtime:getPlayId(),
			time = os.date("%Y-%m-%d %H:%M:%S"),
			data = request.body,
		}
		local content = table.serialize(outputData)
		local path = CCFileUtils:sharedFileUtils():getWritablePath() .. "pass_level_data.json"
		local f = io.open(path, "w")
		if f then
			f:write(content)
			f:close()
		end
	end)
end

function UBFELSendPassLevelProcess:passLevelGiveUp( )
    local runtime = self:get("runtime")
	local request = self:genBaseRequest()
	local levelScene = runtime:getLevelScene()
	request.body.giveUp = true
	request.body.star = 0
	request.body.score = 0
	request.body.coin = 0
	request.body.targetCount = 0
	if not UBFLevelSceneFunc:isPassLevelGiveUpForceSendOpLog(levelScene) then 
		request.body.opLog = nil
	end

	local step = request.body.step
	local staticSteps = request.body.staticSteps
	if staticSteps and staticSteps > 0 and step / staticSteps >= 0.5 then
		request.body.logicalFail = true
	end

	local netMgr = runtime:getNetworkMgr()

	--发送事件
	netMgr:dispatch(request)

	--生成标识
	request.body.cacheCode = self:calcSig(request.body)

	--发送！
	self:_dumpPassLevelToFile(request)
	self:beforeSend(request)
	netMgr:send(request):next(function(reponse)		
		if reponse.err then
			self:dispatchGlobalEvent(UBFProcessEventEnum.AFTER_REQUEST_SEND, reponse)
			local levelId = runtime:getLevelId()
			UBFError("levelId=" .. tostring(levelId) .. " onPassLevelMsgFailed:" .. tostring(reponse.body))
			if _G.isLocalDevelopMode then CommonTip:showTip("过关请求返回失败！！这不应该走到！！ 是不是没有配关卡奖励？？！！") end
			self:abort("pass level http fail")
			return
		else
			self:afterSendMessage(runtime, reponse)
			self:success()
		end
	end)

end


function UBFELSendPassLevelProcess:passLevelRetry()
    local runtime = self:get("runtime")
	local request = self:genBaseRequest()
	request.body.giveUp = true
	request.body.star = 0
	request.body.score = 0
	request.body.coin = 0
	request.body.targetCount = 0
	request.body.opLog = nil


	local step = request.body.step
	local staticSteps = request.body.staticSteps
	if staticSteps and staticSteps > 0 and step / staticSteps >= 0.5 then
		request.body.logicalFail = true
	end

	local netMgr = runtime:getNetworkMgr()

	--发送事件
	netMgr:dispatch(request)

	--生成标识
	request.body.cacheCode = self:calcSig(request.body)

	--发送！
	self:_dumpPassLevelToFile(request)
	self:beforeSend(request)
	netMgr:send(request):next(function(reponse)		
		if reponse.err then
			self:dispatchGlobalEvent(UBFProcessEventEnum.AFTER_REQUEST_SEND, reponse)
			local levelId = runtime:getLevelId()
			UBFError("levelId=" .. tostring(levelId) .. " onPassLevelMsgFailed:" .. tostring(reponse.body))
			if _G.isLocalDevelopMode then CommonTip:showTip("过关请求返回失败！！这不应该走到！！ 是不是没有配关卡奖励？？！！") end
			self:abort("pass level http fail")
			return
		else
			self:afterSendMessage(runtime, reponse)
			self:success()
		end
	end)

end

function UBFELSendPassLevelProcess:passLevelFail()
    local runtime = self:get("runtime")
	local request = self:genBaseRequest()
	request.body.giveUp = false
	request.body.logicalFail = true
	request.body.star = 0


	local netMgr = runtime:getNetworkMgr()
	--发送事件
	netMgr:dispatch(request)

	--生成标识
	request.body.cacheCode = self:calcSig(request.body)

	--发送！
	self:_dumpPassLevelToFile(request)
	self:beforeSend(request)
	netMgr:send(request):next(function(reponse)		
		if reponse.err then
			self:dispatchGlobalEvent(UBFProcessEventEnum.AFTER_REQUEST_SEND, reponse)
			local levelId = runtime:getLevelId()
			UBFError("levelId=" .. tostring(levelId) .. " onPassLevelMsgFailed:" .. tostring(reponse.body))
			if _G.isLocalDevelopMode then CommonTip:showTip("过关请求返回失败！！这不应该走到！！ 是不是没有配关卡奖励？？！！") end
			self:abort("pass level http fail")
			return
		else
			self:afterSendMessage(runtime, reponse)
			self:success()
		end
	end)
end

function UBFELSendPassLevelProcess:afterSendMessage(runtime, reponse)
	xpcall(function() UBFSectionResumeHelper:removeSavedSection() end, debug.traceback)
	if not reponse then
		self:abort("no pass level reponse")
	else			
		runtime:setPassLevelReponse(reponse)
		self:dispatchModEvent(UBFGameModEventEnum.REQUEST_SEND_SUCCESS, reponse)
		self:dispatchGlobalEvent(UBFProcessEventEnum.AFTER_REQUEST_SEND, reponse)
	end	
end

function UBFELSendPassLevelProcess:doRevert()
	
end

function UBFELSendPassLevelProcess:_injectFuuu(cacheHttp, levelId, DataEx, levelScene)
	if DataEx then

		local adjustFixInfo = nil
		local ubfuuCheckResult = nil

		if DataEx.endData then
			ubfuuCheckResult = DataEx.endData:getUBFuuCheckResult()
			if ubfuuCheckResult then
				adjustFixInfo = ubfuuCheckResult.adjustFixInfo
			end
		end

		local _needCollect = nil
		local _hasExplicitCollectFlag = false
		if adjustFixInfo and adjustFixInfo[UBFuuuFixType.kSelfFeedbackEnableFlag] then
			_needCollect = adjustFixInfo[UBFuuuFixType.kSelfFeedbackEnableFlag]
			_hasExplicitCollectFlag = true
		end

		if not _needCollect then
			_needCollect = {}
			_needCollect.enableFlag = ( DataEx.selfFeedbackCollect and DataEx.selfFeedbackCollect > 0 ) and not( DataEx.useOtherPreProp or DataEx.passCollectByUseProp )
		end 

		if not _hasExplicitCollectFlag and ubfuuCheckResult and ubfuuCheckResult.stepFixEnable then
			_needCollect.enableFlag = true
		end

		if _needCollect.enableFlag then
			
			if DataEx.diffFix then
				local _ubfdata = {}
				-- _ubfdata.preAddSteps = DataEx.preAddSteps
				_ubfdata.preAddSteps = 0 --临时线上测试

				_ubfdata.addSteps = DataEx.addSteps
				_ubfdata.diffFix = DataEx.diffFix
				_ubfdata.payTag = DataEx.payTag
				_ubfdata.actTag = DataEx.activityTag

				if ubfuuCheckResult then
					_ubfdata.stepFixEnable = ubfuuCheckResult.stepFixEnable
					_ubfdata.stepFixCollect = _ubfdata.stepFixEnable
					_ubfdata.desiredStep = ubfuuCheckResult.desiredStep
					_ubfdata.stepFix = ubfuuCheckResult.stepFix
				end

				if DataEx.endData then
					_ubfdata.moveCount = DataEx.endData:getMoveCount()
					_ubfdata.staticMoveCount = DataEx.endData:getStaticMoveCount()

					local fuuuData = DataEx.endData:getUBFuuuDcData()

					if fuuuData then
						_ubfdata.stepMoveN0 = fuuuData.maxDiffMoveOnStepN0
						_ubfdata.stepMoveN3 = fuuuData.maxDiffMoveOnStepN3

						if _ubfdata.stepMoveN0 then _ubfdata.stepMoveN0 = _ubfdata.stepMoveN0 * -1 end
						if _ubfdata.stepMoveN3 then _ubfdata.stepMoveN3 = _ubfdata.stepMoveN3 * -1 end
					end
				end

				-- local levelGroup = UBFPlaySwitch:getLevelGroup(levelId)
				-- local ret, meetGroup, uuid = UBFLevelConfigManager:traversalDefault(levelGroup, levelId)
				local levelKeyData = UBFLevelIdUtil:createLevelKeyDataWithAutoLevelGroup(levelId, levelScene)
				local ret, meetGroup, uuid = levelKeyData:fallback()
				local _arr = string.split(meetGroup, ":")

				local UBFuuuAdjustManager = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuAdjustManager"

				local _ver = UBFuuuAdjustManager:getSelfFeedbackVer() or 1 --todo 读取env数据更好
				local _usePreProp = 0
				if _ubfdata.preAddSteps > 0 then _usePreProp = 1 end

				local _poolKey = nil
				if adjustFixInfo and adjustFixInfo[UBFuuuFixType.kSelfFeedbackPoolkey] then
					_poolKey = adjustFixInfo[UBFuuuFixType.kSelfFeedbackPoolkey].collectKey
				end

				_ubfdata.levelKey = UBFuuuAdjustManager:createLevelKey(
					tostring(levelId),
					_arr[1] or "default",
					_arr[2] or "default",
					_usePreProp,
					_ver,
					{poolkey = _poolKey},
					levelScene
				)


				cacheHttp.ubFuuuCollectMeta = _ubfdata	
				--
--
--
--

			end
		end

		if ubfuuCheckResult then
			local _data = nil
			if ubfuuCheckResult.calculateDiffIndexResult and (not ubfuuCheckResult.stepFixEnable) then
				_data = table.clone(ubfuuCheckResult.calculateDiffIndexResult)
	
				if _data.desiredDiffAvgFix1 then _data.desiredDiffAvgFix1 = ubfuuCheckResult.desiredDiffAvgFix1 * 1000 end
				if _data.desiredDiffAvgFix2 then _data.desiredDiffAvgFix2 = ubfuuCheckResult.desiredDiffAvgFix2 * 1000 end
				_data.desiredDiffAvgFix = ubfuuCheckResult.desiredDiffAvgFix * 1000
				_data.fixedDesiredDiffAvg = ubfuuCheckResult.fixedDesiredDiffAvg * 1000
				_data.desiredDiffAvg = ubfuuCheckResult.desiredDiffAvg * 1000
				_data.ubfuuuAdjustSelectEnable = ubfuuCheckResult.ubfuuuAdjustSelectEnable
				_data.diffFix = DataEx.diffFix
				_data.adjustFixInfo = adjustFixInfo
				_data.realDiffAvgByDiffFix = ubfuuCheckResult.realDiffAvgByDiffFix

				local UBFuuuSelfFeedback = require("ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuSelfFeedback")
				if UBFuuuSelfFeedback and UBFuuuSelfFeedback.getDiffAvgByDiffFix then
					_data.diffAvgByDiffFix = UBFuuuSelfFeedback:getDiffAvgByDiffFix(
						levelId, 
						DataEx.diffFix, 
						{poolkey = _G.SelfFeedbackPoolkey.kSuperBird}, 
						levelScene
					)
				end
			end
			
			cacheHttp.ubfuuCheckResult = _data
			--
--
--
--

	
		end
	end
	
end

return UBFELSendPassLevelProcess
