--! 这里面的，要不然是要删的，要不然是关卡外业务

--[[
	迁移等价标~
    GamePlayContext:getInstance().levelInfo.playType = runtime:migrateGet("levelGameMode")
	GamePlayContext:getInstance().levelInfo.levelType = runtime:getLevelType()
	GamePlayContext:getInstance():getTotalEndLevelCount() = runtime:migrateGet("totalEndLevelCount")
    ResourceLoader.getCurVersion = runtime:getGameCurrMd5()
]]

local UBFELMigrator = {}

do 
	local after = {}
	local before = {}
	UBFELMigrator.passNormal = {}
	UBFELMigrator.passNormal.after = after
	UBFELMigrator.passNormal.before = before

	after[UBFProcessNodeEnum.PLAY_DATA_REPORT] = function(runtime)
		if runtime:isPlayerStateSandbox() then return end

		local prevSceneMgr = runtime:getPrevSceneManager()

		xpcall(function()
            if not StageInfoLocalLogic then return end
			local stageInfo = StageInfoLocalLogic:getStageInfo(runtime:getUid())
			if stageInfo then stageInfo.stepProgressDataList = prevSceneMgr:getFormatedStepProgressDataList() end
		end, debug.traceback)

		pcall(function()
			local sceneMgr = prevSceneMgr:getLastSceneManager()
			local endLevelData = prevSceneMgr:getEndLevelData()
			
			PlayRecord:onGameDefiniteFinish(endLevelData.win, {
				getModelLevel = function() return runtime:getLevelId() end
			})
		end)

		pcall(function()
            if not GamePlayContext then return end
			local gamePlayContext = GamePlayContext:getInstance()
			local playInfo = gamePlayContext:getPlayInfo()
			local infoMap = prevSceneMgr:getFormatedMatchStatisticalInfo()
			for k, v in pairs(infoMap) do 
				playInfo[k] = v
			end
		end)
	end
end

do 
	local after = {}
	local before = {}
	UBFELMigrator.failNormal = {}
	UBFELMigrator.failNormal.after = after
	UBFELMigrator.failNormal.before = before

	after[UBFProcessNodeEnum.PLAY_DATA_REPORT] = UBFELMigrator.passNormal.after[UBFProcessNodeEnum.PLAY_DATA_REPORT]
end

local getter = {}
UBFELMigrator.getter = getter

getter.levelGameMode = function(runtime) 
	local baseInfo = UBFLevelConfigManager:userConfig():getLevelBaseInfo(runtime:getLevelId(), runtime:getLevelScene())
	return baseInfo and baseInfo[UBFLevelBaseInfoKey.GAME_MODE_ID] or 0
end
getter.totalEndLevelCount = function(runtime) 
	return UBFPrevSceneManager:getTotalEndLevelCount(runtime:getLevelId())
end

local gListener = {}
UBFELMigrator.gListener = gListener

gListener[UBFProcessEventEnum.BEFORE_DC_EVENT] = function(event, datas)
	-- 已全切AMF分支，不需要了
end

gListener[UBFProcessEventEnum.BEFORE_REQUEST_SEND] = function(event, datas)
	local runtime = datas.runtime
	local body = datas.body
	if datas.method ~= UBFGameMethodType.kPassLevel then return end

end

gListener[UBFProcessEventEnum.AFTER_REQUEST_SEND] = function(event, datas)
end

local modListener = {}
UBFELMigrator.modListener = modListener

modListener[UBFGameModEventEnum.MODIFY_DC_DATA] = function(runtime, data)
    local dcDatas = data.dcDatas
    if data.isEndStage then 
        local prevSceneMgr = runtime:getPrevSceneManager()
        local levelInfo = prevSceneMgr:getLevelInfo() or {}
        local sceneData = prevSceneMgr:getSceneData() or {}
        local currentStage = dcDatas.current_stage
        local endLevelData = runtime:getEndLevelData()
        -- local star_buffGetNum = 0

        -- if StarBuffYEManager and StarBuffYEManager.getInstance():isBuffEffectiveForPassLevel() then
        --     local oldStarForCollectStar = dcDatas.old_star
        --     local star = endLevelData.star
        --     star_buffGetNum = StarBuffYEManager.getInstance():getPassLevelCanGetBuffNum(oldStarForCollectStar , star)
        --     star_buffGetNum = star_buffGetNum or 0
        -- end

        -- dcDatas.star_buff = star_buffGetNum

		dcDatas.use_score_buff = 0

		for _, mod in ipairs(levelInfo.modList or {}) do 
			if mod.mType == UBFPlayModBuilder.BuffBuilderEnum.kImproveBuff and mod.buildData then 
				for _, info in ipairs(mod.buildData.buffInfo or {}) do 
					if info.btt == UBFGameItemType.kBuffStarBottle then dcDatas.use_score_buff = 1 end
				end
			end
		end

        -- 连胜 
        if winRepeatedlyManager then 
            dcDatas.win_num = winRepeatedlyManager:getInstance():getWinNum() 
        end

        --下面是 LevelDifficultyAdjustManager mod 应该处理的部分
		local adjustData = levelInfo.adjustData

		-- ☆ 调节相关参数
		if adjustData then
			dcDatas.adjust_mode = adjustData.mode
			dcDatas.adjust_ds = adjustData.ds
			dcDatas.adjust_gap = adjustData.gap and table.serialize(adjustData.gap)
			dcDatas.adjust_front_half = adjustData.frontHalf and table.serialize(adjustData.frontHalf)
		end

		if LevelDifficultyAdjustManager then
			local colorFuuuResult = false
			local b1 = false
			local b2 = false
			if adjustData and adjustData.mode == ProductItemDiffChangeMode.kAIAddColor then
				b2 = true
			end
			if b1 or b2 then
				colorFuuuResult = true
			end
			-- local strategyID = LevelDifficultyAdjustManager:getStrategyIDListByDCString()
			-- local strategyReason = adjustData and adjustData.reason
			local userInterference = false
			-- if (strategyID and strategyID ~= "") then userInterference = true end
			
			-- todo 没数据>> 没见过的数据
			local fuuuOverView = "none"
			local fuuuAverageValue = -1
			-- todo 不知道啥玩意，LevelDifficultyAdjustManager是关卡内增再用的东西，迁移到mod

			-- todo 难度调整相关上下文数据 迁移mod
  
			dcDatas.top_wins = UserManager:getInstance().userExtend.topLevelWinCount or 0
			dcDatas.top_wins_logical = UserManager:getInstance().userExtend:getTopLevelLogicalWinCount()

			-- dcDatas.top_logical_fails = levelDiffCtx.failCount--todo reast
			-- dcDatas.top3_continue_fails = levelDiffCtx.top3LevelContinueFails--todo reast
			dcDatas.colorFuuuResult = colorFuuuResult
			dcDatas.user_interference = userInterference
			dcDatas.fuuu_overview = fuuuOverView
			dcDatas.fuuu_average = fuuuAverageValue
			-- dcDatas.diff_adjust_algorithm_id = diffV2AlgorithmId

			dcDatas.strategyUnactivateReason = LevelDifficultyAdjustManager:getLastUnactivateReason()
			dcDatas.strategyFuuuUnactivateReason = LevelDifficultyAdjustManager:getLastFuuuUnactivateReason()
			dcDatas.intervene_seq_rec = LevelDifficultyAdjustManager:getDcAIColorProbsRec()
			dcDatas.diff_adjust_exp_tag = LevelDifficultyAdjustManager:getExpName()
			dcDatas.play_id_create_time = runtime:getStartLevelStartTime()
		end
      
		-- local failCount1, failCount2 = PlayRecord:getLevelFailNumBeforeFirstPass(currentStage)
		local failCount2 = runtime:getTopLevelFailCount()
		local levelId = runtime:getLevelId()
		local topLevelId = runtime:getTopLevelId()
		if topLevelId ~= levelId or not UBFLevelSceneFunc:isMainLevel(levelInfo.levelScene) then
			failCount2 = 0
		else
			if runtime:isWin() then
				failCount2 = math.max(0,failCount2-1)
			end
		end

		dcDatas.sum2 = failCount2 -- 这个字段是仅前端维护的首次过关前失败次数，每一关都有值
		dcDatas.cont_fail_count = PlayRecord:getLevelContinuousFailNum(currentStage)--开发中，要改为前后端一起维护
		dcDatas.start_level_total_count = PlayRecord:getLevelTotalPlayed(currentStage) --开发中，要改为前后端一起维护
		dcDatas.end_level_total_count = runtime:migrateGet("totalEndLevelCount") or 0
		-- if FUUUTopLevelAdjustLogic then FUUUTopLevelAdjustLogic:dcStageEnd(dcDatas) end
        local passLevelData = {
            levelId = runtime:getLevelId(),
            levelScene = runtime:getLevelScene(),
            star = runtime:getStar(),
            hadPassed = runtime:getLevelHasAlreadyPassed(),
        }
        local _ = LocalActCoreModel and LocalActCoreModel.getInstance():notify(ActInterface.kPassLevelBeforeDcStageEnd, passLevelData)

    end
end

modListener[UBFGameModEventEnum.BEFORE_PASS_LEVEL] = function(runtime, data)
    local levelId = data.levelId
    local levelType = data.levelType
    local score = data.score
    local oldScore = data.oldScore
    local levelScene = data.levelScene
    local star = data.star
    --暂时放在这里 todo
    local _ = LocalActCoreModel and LocalActCoreModel:getOrCreateInstance():notify(ActInterface.kBeforePassLevel, data)
    -- ActInLevelManagerHelper.getInstance():notify(ActInLevelInterface.kBeforePassLevel, data)
    if levelType == GameLevelType.kMainLevel and PrePropImproveLogic then 
        PrePropImproveLogic:onLevelEnd(true,levelId)
    end
    --满级满星刷分
	if FullLevelScoringManager then 
		FullLevelScoringManager:getInstance():onPassLevel(levelId, levelType, score, oldScore, levelScene)
	end

    local checkScoreAndCompleteAchievement = function ( score )
        local oldScore = UserManager:getInstance():getUserScore(levelId, levelScene)
        local maxTopLevel
        -- TODO @siyang app要不要？
        maxTopLevel = _G.amfBean("LevelUnLockManager"):getMaxNormalLevelByLevelArea()
        local topLevelId = UserManager:getInstance():getUserRef():getTopLevelId()
        local function onCompleteSuccess(evt)
            -- local num = 10000
            -- if evt.data and evt.data.passNum  then
            --  num = evt.data.passNum
            -- end
            -- setTimeOut(function()
            --      if not self.isDisposed then 
            --          --ShareManager:setShareData(ShareManager.ConditionType.PASS_NUM, num)
            --          --ShareManager:shareWithID(ShareManager.HIGHEST_LEVEL)
            --       end
            --  end, 1 / 60)
        end
        local function onRankSuccess(evt)
            local share = false
            if evt.data and evt.data.share then
                share = evt.data.share
            end
            setTimeOut(function()
                Notify:dispatch("AchiEventDataUpdate", AchiDataType.kOverSelfRank, share)
            end, 1 / 60)
        end
        local completeRequest = levelId == maxTopLevel and 
            levelId == topLevelId and UBFLevelSceneFunc:isMainLevel(levelScene) and
            (not oldScore or not oldScore.score)
        local rankRequest = not oldScore or not oldScore.score or oldScore.score < score
        if completeRequest and rankRequest then ConnectionManager:block() end
        if completeRequest then
            local completeHttp = GetPassNumHttp.new()
            completeHttp:addEventListener(Events.kComplete, onCompleteSuccess)
            completeHttp:load(levelId, levelScene)
        else
            onCompleteSuccess({})
        end
        if completeRequest and rankRequest then ConnectionManager:flush() end
    end
	
end


modListener[UBFGameModEventEnum.AFTER_PASS_LEVEL] = function (runtime, data)
	-- 已全切AMF分支，不需要了
end

local function old_pass_level_update_star(levelId, star, levelScene)
	if star >= 3 then
		local isNewFullStarArea = nil
		-- Record full star area
		local score = UserManager:getInstance():getUserScore(levelId, levelScene)
		if not score or score.star < 3 then
			local _,numFullStarArea = UserManager:getInstance():getAreaStarInfo()
			local oldStar = nil
			if score then
				oldStar = score.star
				score.star = star
			else
				local newLevelScore = ScoreRef and ScoreRef.new() or {}
				newLevelScore.levelId = levelId
				newLevelScore.star = star
                newLevelScore.levelScene = levelScene
				UserManager:getInstance():addUserScore(newLevelScore)
			end
			local _,numFullStarAreaNew = UserManager:getInstance():getAreaStarInfo()
			if oldStar then
				score.star = oldStar
			else
				UserManager:getInstance():removeUserScore(levelId, levelScene)
			end
			isNewFullStarArea = numFullStarAreaNew>numFullStarArea
		end
		return isNewFullStarArea
	end
end

modListener[UBFGameModEventEnum.BEFORE_REQUEST_SEND] = function(runtime, data)
	-- local runtime = data.runtime
	local body = data.body
	if data.method == UBFGameMethodType.kPassLevel then
    	local prevSceneMgr = runtime:getPrevSceneManager()
    	local playInfo = prevSceneMgr:getFormatedMatchStatisticalInfo()
		local sceneData = prevSceneMgr:getSceneData()
		local levelInfo = prevSceneMgr:getLevelInfo()
		local birdDestroyCount = prevSceneMgr:getBirdDestroyCount()
		local opLog = body.opLog
		local uid = body.uid
		local levelId = body.levelId
    	local levelType = body.levelType
    	local star = body.star
    	local isGiveUp = body.isGiveUp
    	local extraData = body.extraData
    	local levelScene = body.levelScene
    	local logicalFail = body.logicalFail
    	local score = body.score
    	local stageTime = body.stageTime
    	local costMove = body.step
    	local isWin = runtime:isWin()

    	-- printx(16,tts(playInfo))

		local levelDifficultyFlag

		-- 部分需求有要知晓关卡难度设定的需求，难度标签
		local MetaManager = UBFHelper:getGlobalLogic("MetaManager")
		local difficultyFlag = MetaManager:getLevelDifficultFlag(levelId, levelScene)
		if difficultyFlag then levelDifficultyFlag = difficultyFlag end
		body.levelDifficultyFlag = levelDifficultyFlag
		if levelDifficultyFlag then body["difficultyFlag"] = levelDifficultyFlag end

		-- 星？
		if star < 1  then body.targetCount = 0 end
		
		-- local cv12 , cv13 = UpdatePassLevelHttpRPData(76, levelId, opLog)
		-- RandomFactoryDebugHelper:sendPassLevelStart( { opLog = opLog } )

		--旧分数
		local oldStarForCollectStar = 0 
		local oldScoreForCollectStar = 0 
		local oldLevelPassed = UserManager:getInstance():hasPassedLevelEx(levelId, levelScene)
		local scoreNode = UserManager:getInstance():getUserScore(levelId, levelScene)
		if scoreNode then
			oldStarForCollectStar = scoreNode.star or 0
			oldScoreForCollectStar = scoreNode.score or 0
		end

		-- ! 不知道是啥，看上去旧逻辑在这里更新了星级，实在有些坑人坑人坑人坑人
		local isNewFullStarArea = false
		local isFullLevelMode = LevelSceneFunc and LevelSceneFunc:isFullLevelLib(levelScene)
		if not isFullLevelMode then isNewFullStarArea = old_pass_level_update_star(levelId, star, levelScene) end

		--也不知是啥数据
		local levelModeType = runtime:getLevelGameMode()
		local extraStr = "0"
		if costMove >= 5 or star > 0 then extraStr = "1" end

		--活动！
		local jsonTable = {}

        if _G.__FarmStarRanking_FLAG then
        	local uid = UserManager.getInstance().uid or "12345"
		    local open = MaintenanceManager:getInstance():isEnabledInGroup("farmStarRank" , "ON" , uid)
		    if open then jsonTable["7006"] = "" end 
        end

        local _data = {
			levelId = levelId,
			levelType = levelType,
			star = star,
			score = score,
			isGiveUp = isGiveUp,
			usedProps = body.usedProps,
			jsonTable = jsonTable,
			oldStarForCollectStar = oldStarForCollectStar,
			oldScoreForCollectStar = oldScoreForCollectStar,
			extra = extraData,
			opLog = opLog,
			levelScene = levelScene,
			isWin = isWin,
		}

		local _ = LocalActCoreModel and	LocalActCoreModel.getOrCreateInstance():notify(ActInterface.kSendPassLevelStart, _data)
		-- ActInLevelManagerHelper.getInstance():notify(ActInLevelInterface.kSendPassLevelStart, _data)

        if not isGiveUp then
        	if WeeklyRace2020Mgr and WeeklyRace2020Mgr.getInstance():passLevelCanAddProgress() then
        		jsonTable['8015'] = { matched = true }
        	end
        end


        if levelType == GameLevelType.kWeeklyRace2020 then
	    	local extraData2 = WeeklyRace2020Logic:getWeeklyRace2020PasslevelExtraData(star)
	    	jsonTable["8015"] = extraData2
	    end


	   	jsonTable["-9999"] = {
			color1 = playInfo.killed_animal_1,
			color2 = playInfo.killed_animal_2,
			color3 = playInfo.killed_animal_3,
			color4 = playInfo.killed_animal_4,
			color5 = playInfo.killed_animal_5,
			color6 = playInfo.killed_animal_6,
			magicBird = birdDestroyCount,
			--todo 代打点
			-- line = gamePlayContext:getPlayInfoKilledLine(),
			-- wrap = gamePlayContext:getPlayInfoKilledWrap(),
			-- bird = gamePlayContext:getPlayInfoKilledBird(),
		}
		jsonTable["3017"] = table.clone(jsonTable["-9999"], true)

		if StarBuffYEManager and StarBuffYEManager.getInstance():isBuffEffectiveForPassLevel() then
			if StarBuffManager.getInstance():isMaintenanceOn() then
				if not StarBuffYEManager.getInstance():getUnfulllevelStarBuffEnable() or StarBuffManager.getInstance():isFullLevel() then
					jsonTable[ ""..StarBuffYEManager.UseBuffOffLineID ] = "true"
					StarBuffYEManager.getInstance():doAutoAddBuff(oldStarForCollectStar , star)
				end
			end
		end

		if StarBuffYEManager and StarBuffYEManager.getInstance():isBuffStateForPassLevel(levelId, levelScene) then
			if StarBuffYEManager.getInstance().curUsePropId ~= 0 and StarBuffYEManager.getInstance().curUsePropId == UPropId.INFINITE_STARBUFF_THIRTY_MINUTE then
				StarBuffYEManager.getInstance():addConsumeBuffStateTime(Localhost:timeInSec() - (StarBuffYEManager.getInstance().lastEnterLevelTime or 0))
			end
		end

		-- todo 新棋盘没这个数据了
		local levelMd5 = ""
		local initAdjustData = nil
		-- initAdjustData = gameBoardLogic:getBoardModel().initAdjustData

		local shouldCalcPrebuff = false
		if PreBuffLogic then shouldCalcPrebuff = PreBuffLogic:isActOn() end

		-- 序列化oplog
		if opLog then
			if _G.isLocalDevelopMode then  opLog.passLevelJsonData = jsonTable end	
			opLog.hasUsedProp = body.hasUsedProp
			-- 	xpcall(function()
			-- 		opLog = table.serialize(opLog)
			--     end,
			--     function(err)
			--         if _G.isLocalDevelopMode then
			--             local traceback = debug.traceback("", 2)
			--             print(table.tostring(opLog))
			--             print(err,traceback)
			--         end
			-- 		local str = ""
			-- 		pcall(function() str = tts(opLog) end)
			-- 		he_log_error("passLevel oplog serialize fail." .. tostring(err) .. " - " .. tostring(str))
			--     end)
		end

		--
--


		local hideLevelVersion = 0
		local staticLevelMoves = runtime:getStaticMove()

		body.activityFlag = levelType
		body.extraStr = extraStr
		-- body.curConfigMd5 = LevelMapNoCompatible.getInstance():getLevelUpdateVersion() --没有关卡调整了
		body.levelMd5 = levelMd5
		body.levelVersion = GamePlayClientVersion -- 新分组应该早就不用了
		body.guideLevel = (not shouldCalcPrebuff)
        -- TODO @siyang app要不要？
        if EnvUtil:isMiniGame() then
		    body.isNewFullStarArea = isNewFullStarArea
        else
		    body.newFullStarArea = isNewFullStarArea
        end
		body.jsonTable = jsonTable
		body.orderIds = levelInfo.paymentOrderIds or {}
		body.hideLevelVersion = 0
		body.extraData = table.serialize(body.extraData)
		body.protocolVersion = CollectionProtocolVersion
		runtime.__jsonTable__ = jsonTable
		if IngamePropGuideManager then 
			body.propGuideItem = IngamePropGuideManager:getInstance():getPassLevelParamAndClear() or 0
		end

		-- todo 成就部分，关卡外
		if AchiId then 
			local achiInfo = {
				[AchiId.kTotalLineEffectCount] = playInfo.line_create,
				[AchiId.kTotalBombEffectCount] = playInfo.wrap_create,
				[AchiId.kTotalMagicBirdCount] = playInfo.bird_create,
				[AchiId.kTotalChangeEffectCount] = playInfo.line_line_swap 
													+ playInfo.line_wrap_swap 
													+ playInfo.wrap_wrap_swap 
													+ playInfo.bird_line_swap 
													+ playInfo.bird_wrap_swap
													+ playInfo.bird_bird_swap,
			}
			local achievementValues = {}
			for id,count in pairs(achiInfo) do
				table.insert(achievementValues, {first = id, second = count})
			end

			body.achievementValues = achievementValues

			for id,count in pairs(achiInfo) do
				local _ = Notify and Notify:dispatch("AchiEventDataUpdate", id, count)
			end
		end

		-- dev oplog 回放flag
		if EnvUtil:isDevelopMode() then
			_G.needCheckReplayOplog = 1
			if _G._hasCheatedInLevel then
				_G._hasCheatedInLevel = nil
				_G.needCheckReplayOplog = 0
			end
			if EnvUtil:isUnityEditor() or __WIN32 then
				_G.needCheckReplayOplog = 0
			end
			--失败不发
			if star <= 0 then
				-- 检查是否有活动想强行校验，不清除标记
				local keepFlag = UBFLevelSceneFunc:isPassLevelGiveUpForceSendOpLog(levelScene)
				if not keepFlag then
					_G.needCheckReplayOplog = nil
				end
			end
		end
		if _G.forceCheckReplayOplog then
			_G.needCheckReplayOplog = 1
			_G.forceCheckReplayOplog = nil
		end
		body.oplogFlag = _G.needCheckReplayOplog
		_G.needCheckReplayOplog = 0

		-- 难度相关
		if LevelDifficultyAdjustManager then 
			body.eventId = LevelDifficultyAdjustManager:getAIEventID()

			body.strategy = LevelDifficultyAdjustManager:getCurrStrategyID() or 0
			body.strategyReason = LevelDifficultyAdjustManager:getStrategyDataListByDCString()

			LevelDifficultyAdjustManager:onBeforeSendPassLevel(levelId, score, star, logicalFail)
			LevelDifficultyAdjustManager:clearCurrStrategyID()

		end

		local beforeSendPassLevelEventData = {
			ubfELRuntime = runtime,
		}
		UBFGlobalEventBus:dispatch( UBFGlobalEventEnum.kBeforeSendPassLevelMsg , beforeSendPassLevelEventData )

		local topLevelId = UserService:getInstance().user:getTopLevelId()
		if logicalFail and topLevelId == levelId and UBFLevelSceneFunc:isMainLevel(levelScene) and UserTagManager then
			local c1 = UserTagManager:getTopLevelLogicalFailCounts() or 0
			UserTagManager:updateTopLevelLogicalFailCounts( c1 + 1 )
		end

	elseif data.method == UBFGameMethodType.kSubsPassLevel then
    	-- local prevSceneMgr = runtime:getPrevSceneManager()
    	-- local playInfo = prevSceneMgr:getFormatedMatchStatisticalInfo()

		-- local opLog = body.opLog
		-- local uid = body.uid
		-- local levelId = body.levelId
    	-- local levelType = body.levelType
    	-- local star = body.star
    	-- local isGiveUp = body.isGiveUp
    	-- local extraData = body.extraData
    	-- local levelScene = body.levelScene
    	-- local logicalFail = body.logicalFail
    	-- local score = body.score
    	-- local stageTime = body.stageTime
    	-- local costMove = body.step

		-- local levelModeType = runtime:getLevelGameMode()

		-- if AchiId then
		-- 	local achiInfo = {
		-- 		[AchiId.kTotalLineEffectCount] = playInfo.line_create,
		-- 		[AchiId.kTotalBombEffectCount] = playInfo.wrap_create,
		-- 		[AchiId.kTotalMagicBirdCount] = playInfo.bird_create,
		-- 		[AchiId.kTotalChangeEffectCount] = playInfo.line_line_swap
		-- 											+ playInfo.line_wrap_swap
		-- 											+ playInfo.wrap_wrap_swap
		-- 											+ playInfo.bird_line_swap
		-- 											+ playInfo.bird_wrap_swap
		-- 											+ playInfo.bird_bird_swap,
		-- 	}
		-- 	local achievementValues = {}
		-- 	for id,count in pairs(achiInfo) do
		-- 		table.insert(achievementValues, {first = id, second = count})
		-- 	end
		-- 	body.achievementValues = achievementValues
		-- 	for id,count in pairs(achiInfo) do
		-- 		Notify:dispatch("AchiEventDataUpdate", id, count)
		-- 	end
		-- end

	
		-- local levelDifficultyFlag
		-- -- 部分需求有要知晓关卡难度设定的需求
		-- if MetaManager and MetaManager.getInstance() then
		-- 	local difficultyFlag = MetaManager.getInstance():getLevelDifficultFlag(levelId, levelScene)
		-- 	if difficultyFlag then
		-- 		levelDifficultyFlag = difficultyFlag
		-- 	end
		-- end
		-- body["difficultyFlag"] = levelDifficultyFlag

		-- local extraStr = "0"
		-- if costMove >= 5 or star > 0 or (levelModeType == GameModeType.CLASSIC and stageTime >= 30) then
		-- 	extraStr = "1"
		-- end
		-- body.extra = extraStr

		-- local usedProps = {}
		-- local stageInfo = StageInfoLocalLogic:getStageInfo( UserManager:getInstance().uid )
		-- if stageInfo and stageInfo.propsUsedInLevel then
		-- 	for itemId, num in pairs(stageInfo.propsUsedInLevel) do
		-- 		table.insert(usedProps, {itemId = itemId, num = num})
		-- 	end
		-- end
		-- body.usedProps = usedProps
		-- local jsonTable = {}
		-- jsonTable["-9999"] = {
		-- 	color1 = playInfo.killed_animal_1,
		-- 	color2 = playInfo.killed_animal_2,
		-- 	color3 = playInfo.killed_animal_3,
		-- 	color4 = playInfo.killed_animal_4,
		-- 	color5 = playInfo.killed_animal_5,
		-- 	color6 = playInfo.killed_animal_6,
		-- 	-- line = gamePlayContext:getPlayInfoKilledLine(),
		-- 	-- wrap = gamePlayContext:getPlayInfoKilledWrap(),
		-- 	-- bird = gamePlayContext:getPlayInfoKilledBird(),
		-- }
		-- jsonTable["3017"] = table.clone(jsonTable["-9999"], true)
		-- body.cacheCode = AFHPassLevelHttp:calcSig(body)
		-- UBFGamePlayBridgeInvoker:injectUBFLevelGroupData(body, levelId)
	end
end

modListener[UBFGameModEventEnum.BEFORE_FAIL_LEVEL] = function (runtime,data)
	local levelId = runtime:getLevelId()
	local levelScene = runtime:getLevelScene()
	local score = runtime:getTotalScore()
	local star = runtime:getStar()
	local coin = runtime:getLevelCoin()
	local targetCount = runtime:getTargetCount()
	local uid = runtime:getUid()
	local currStrategyID = LevelDifficultyAdjustManagerv and LevelDifficultyAdjustManager:getCurrStrategyID()
	local costMove = runtime:getMoveCount()
	local stageTime = runtime:getStageTime()
	local guideLevel = runtime:isGuideLevel()
	local opLog = runtime:getReplayLog()
	local failReason = runtime:getLevelFailReason()


	local beforeFailLevelData = {
		levelId = levelId,
		levelScene = levelScene,
		score = score,
		star = star,
		coin = coin,
		targetCount = targetCount,
	}
	local _ = LocalActCoreModel and LocalActCoreModel:getOrCreateInstance():notify(ActInterface.kBeforeFailLevel, beforeFailLevelData)
	-- ActInLevelManagerHelper.getInstance():notify(ActInLevelInterface.kBeforeFailLevel, beforeFailLevelData)


	if PrePropImproveLogic then 
		PrePropImproveLogic:onLevelEnd(false,levelId)
	end
	-- if LevelStrategyManager then 
	-- 	LevelStrategyManager.getInstance():setLevelFail(levelId)
	-- end
end

modListener[UBFGameModEventEnum.AFTER_FAIL_LEVEL] = function (runtime,data)
end


modListener[UBFGameModEventEnum.BEFORE_QUIT_LEVEL] = function (runtime,data)
	local levelId = runtime:getLevelId()
	local levelScene = runtime:getLevelScene()

	if not LevelSceneFunc:isFullLevelLib(levelScene) then
		UserService.getInstance():onQuitLevel(levelId, levelScene)
	end
end


modListener[UBFGameModEventEnum.AFTER_QUIT_LEVEL] = function (runtime,data)
	local levelId = runtime:getLevelId()
	local levelType = runtime:getLevelType()
	local levelScene = runtime:getLevelScene()
	local realCostMove = runtime:getTotalCostMove()
	local staticMove = runtime:getStaticMove()
	local playLevelMode = runtime:getPlayLevelMode()
	local score = runtime:getTotalScore()
	local star = runtime:getStar()

	if InciteManager then 
		InciteManager:onPassLevel()
	end

	if ProductItemDiffChangeLogic then 
		ProductItemDiffChangeLogic:endLevel()
	end

	if GameInitDiffChangeLogic then 
		GameInitDiffChangeLogic:endLevel()
	end

	local data = {
		levelId = levelId,
		levelType = levelType,
		strategyID = LevelDifficultyAdjustManager and LevelDifficultyAdjustManager:getCurrStrategyID(),

		realCostMove = realCostMove,
		staticLevelMoves = staticMove,
		levelScene = levelScene,
		playLevelMode = playLevelMode,

		score = score,
		star = star,
		isQuit = true,
	}

end

modListener[UBFGameModEventEnum.BEFORE_RETRY_LEVEL] = function (runtime,data)
	
	printx(16,"BEFORE_RETRY_LEVEL")
	local levelId = runtime:getLevelId()
	local levelType = runtime:getLevelType()
	local costMove = runtime:getTotalCostMove()
	local staticMove = runtime:getStaticMove()
	local levelScene = runtime:getLevelScene()
	local playLevelMode = runtime:getPlayLevelMode()

	if not LevelSceneFunc:isFullLevelLib(levelScene) then
		UserService.getInstance():onQuitLevel(levelId, levelScene)
	end

	local beforeTryAgain = {
		levelId = levelId,
		levelType = levelType,
		strategyID = LevelDifficultyAdjustManager and LevelDifficultyAdjustManager:getCurrStrategyID(),
		realCostMove = costMove,
		staticLevelMoves = staticMove,
		levelScene = levelScene,
		playLevelMode = playLevelMode,
	}

	local _ = LocalActCoreModel and LocalActCoreModel.getInstance():notify(ActInterface.kBeforePlayAgainLevel, beforeTryAgain)
	-- ActInLevelManagerHelper.getInstance():notify(ActInLevelInterface.kBeforePlayAgainLevel, beforeTryAgain)

end


modListener[UBFGameModEventEnum.AFTER_RETRY_LEVEL] = function (runtime,data)
end

modListener[UBFGameModEventEnum.BEFORE_YUNGAME_LEVEL] = function ( runtime,data )
	-- local forceQuit = false
	if runtime:isWin() then
		GlobalEventDispatcher:getInstance():dispatchEvent(Event.new("yungame_passlevel", {success = true}))
	else
		local failReason = runtime:getLevelFailReason()
		if failReason == _G.UBFGameFailReason.kRetry then
			safeRunCall(modListener[UBFGameModEventEnum.BEFORE_RETRY_LEVEL],runtime,data)
		elseif failReason == _G.UBFGameFailReason.kDropout then
			safeRunCall(modListener[UBFGameModEventEnum.BEFORE_QUIT_LEVEL],runtime,data)
		else
			GlobalEventDispatcher:getInstance():dispatchEvent(Event.new("yungame_passlevel", {success = false}))
		end
	end
end

modListener[UBFGameModEventEnum.AFTER_YUNGAME_LEVEL] = function (runtime,data)
	-- printx(16,"?????????????????????????")
	local forceQuit = function ()
		setNextFrame(function ( ... )
			-- Director:sharedDirector():popScene()
			GlobalEventDispatcher:getInstance():dispatchEvent(Event.new(kGlobalEvents.kExceptionReturnFromGamePlay))
		end)
	end

	if runtime:isWin() then
		forceQuit()
	else
		local failReason = runtime:getLevelFailReason()
		-- printx(16,failReason,"*----------------------------")
		if failReason == _G.UBFGameFailReason.kRetry then
			safeRunCall(modListener[UBFGameModEventEnum.AFTER_RETRY_LEVEL],runtime,data)
		elseif failReason == _G.UBFGameFailReason.kDropout then
			safeRunCall(modListener[UBFGameModEventEnum.AFTER_QUIT_LEVEL],runtime,data)
		else
			forceQuit()
		end
	end
end


modListener[UBFGameModEventEnum.WONDERFUL_END_LEVEL] = function (runtime,data)
	local sceneMgr = UBFGameSceneManager:getInstance()
	if not sceneMgr then return end
	local levelId = runtime:getLevelId()
	local endPromise = sceneMgr:callGameModule( UBFGameLogics.kWonderfulReplay , "onGameEnd" )
	local wonderfulReplayEndType = runtime:getWonderfulReplayEndType() 
	wonderfulReplayEndType = wonderfulReplayEndType or _G.UBFGameReplayEndType.kNormal
	lua_switch(wonderfulReplayEndType){
		[_G.UBFGameReplayEndType.kNormal] = function ( ... )
			local delegate = {
				onMenuCommand = function ( _,_, cmd )
					lua_switch(cmd){
						["replayAgain"] = function (  )
							--todo
							Director:sharedDirector():popScene()
							local UserReviewLogic = require 'ubf.old.gamePlay.review.UserReviewLogic'
							UserReviewLogic:test(nil,levelId)
						end,
						["quitReplay"] = function ( ... )
							--todo
							Director:sharedDirector():popScene()
						end,
					}
				end
			}

			local UserReviewEndPanel = require 'ubf.old.gamePlay.review.UserReviewEndPanel'
			local panel = UserReviewEndPanel:create(  )
			panel:setDelegate(delegate)
			panel:popout()

			if endPromise then 
				endPromise:next(function( data )
					if data.isRecord then 
						if panel.isDisposed then return end
						panel:setSavedPath( data.savedPath )
					end
				end)
			end
		end,

		[_G.UBFGameReplayEndType.kQuit] = function ( ... )
			--todo
			Director:sharedDirector():popScene()
		end
	}
end

return UBFELMigrator
