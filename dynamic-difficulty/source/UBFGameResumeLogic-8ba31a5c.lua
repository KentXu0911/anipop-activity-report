-- UBF 闪退恢复的检查操作逻辑
-- https://rzvo5fieru.feishu.cn/wiki/NOxTwBUqCiFZpjkJbTtcjoYfndc
local UBFGameResumeLogic = class2("UBFGameResumeLogic", UBFBaseLogic)
require "ubf.UBFPlay.logics.launch.UBFResumeData"
require "ubf.UBFPlay.logics.utils.UBFSectionResumeHelper"

local log = nil
--
--
--
--


UBFGameResumeFailReason = {
	-- kLevelRangeIllegal = 1 ,		--不是主线关，隐藏关，周赛关
	kUdidNotExist = 2 ,				--无法获取本机udid
	kUserChanged = 3 ,				--不是当前用户的闪退数据
	kDeviceChanged = 4 ,			--不是当前设备的闪退数据
	kCrashOver1Hour = 5 ,			--闪退时间是1小时以前，实际取UBFSectionResumeHelper.TIME_OUT的值，目前是25小时
	kMd5CheckFail = 6 ,				--Md5校验失败
	-- kUserDataNeedRevert = 7,		--看见了恢复面板，但数据异常
	-- kIsTimeLevel = 10 ,--时间关
	-- kIsUFOLevel = 11 ,--飞碟关
	-- kLevelConfigNotExist = 12 ,		--没有关卡配置
	kRustError = 13 ,				--rust 过期
	-- kWeeklyRaceSwitchOff = 14 ,		--周赛开关未打开
	-- kMainOrHiddenPassDay = 15 ,		--主线关或精英关跨天
	-- kPetSkillPassDay = 16 ,			--宠物技能 跨天
	-- kDoubleEgg2020MainPassDay = 17,--双旦主活动关跨天
	-- kMarchActivity2021PassDay = 18,--三月主线活动关跨天
	-- kSeaOrderActivity = 19, --海洋生物类型活动跨天
	-- kMarchActivity2021PassDay = 20,
	-- kActivityPassDay = 21, 			--和ResumeGamePlayPopoutAction一致…………话说前面不一致真的没问题吗？
	-- kSectionTimestampNotMatch = 22, -- 通过覆盖用户数据文件利用闪退恢复作弊
	-- kNullUserData = 23, 			-- 用户数据为空
	kUpdateVersionChanged = 24, 	-- 跨动更
	kReplayVersionChanged = 25, 	-- replay格式版本已过时
	-- kLevelVersionChanged = 26, 		-- 关卡版本变化
	kFullLevelStarLibraryOff = 27, 	-- 发新关导致关卡库入口关闭
	kActivityRefuse		=	28,		--活动拒绝
	kAskForHelp			= 	29,		--代打拒绝
	kIgnoreFeedAutoStart = 	30,		--Feed自动进关不闪退恢复

	kMainLevelAndGreaterTopLevel = 92 ,--主线关，且要恢复的关卡大于topLevel
	kActivityIsEnd = 93 ,			--跨活动关卡
	kRustAllIn = 94 ,				--rust all in
	-- kCanNotResumeOnSectionLevel = 95,--闪退数据来自上一次恢复打关
	-- kSpringFestival2019OverTime = 96 ,--跨活动关卡
	-- kCanNotResumeOnReplayLevel = 97 ,--闪退数据来自上一次恢复打关
	-- kLaunchGameByUrlLink = 98 ,--由链接启动游戏
	kUserClose = 99 ,--用户主动取消
}

function UBFGameResumeLogic:build(createData)
	pcall(function()
		self.sectionData = UBFSectionResumeHelper:hasAndGetSection()
		if self.sectionData then 
			local section = self.sectionData.section
			self.sectionData.replay_log_record = self.sectionData.replayLog 
			if section then section.replay_log_record = self.sectionData.replayLog end
		end
	end)
end

function UBFGameResumeLogic:hasResumeData()
	return self.sectionData and true or false
end

function UBFGameResumeLogic:getResumeData()
	return self.sectionData
end

function UBFGameResumeLogic:checkCanResume(callback)
	if log then log("checkCanResume") end
	if not self:hasResumeData() then
		--没有数据，本身就没法恢复
		callback(false,nil)
		return
	end

	-- 检查恢复条件失败时的处理逻辑
	local function onCheckFail(errCode)
		if log then log("onCheckFail",errCode) end
		-- 数据处理，断连胜、发协议等
		self:afterNotResume(false,errCode)
		-- 回调，通知强弹框架
		callback(false,errCode)
	end

	-- 检查基础恢复条件
	local function checkBase(nextAction)
		if log then log("checkBase") end

		self._checkResult = self:_checkCanResume()
		if self._checkResult.errCode ~= 0 then
			onCheckFail(self._checkResult.errCode)
			return
		end
		nextAction()
	end

	-- 发送成功回调
	local function sendSuccess()
		if log then log("checkCanResume sendSuccess") end
		callback(true)
	end

	local list = {
		checkBase,
		-- checkResumeTimes,
		sendSuccess
	}
	runSequence(list)
end

function UBFGameResumeLogic:_checkCanResume()
	local function ret(code, extra)
		return {
			errCode = code or 0,
			msg = extra,
		}
	end

	local function log(...)
		if EnvUtil:isUnityEditor() then
			UError(...)
		end
	end

	local Reason = UBFGameResumeFailReason

	--test
	-- do return ret(Reason.kMainLevelAndGreaterTopLevel) end
	--

	local resumeData = UBFResumeData:create(self:getResumeData())
	local levelId = resumeData:getLevelId()
	local levelScene = resumeData:getLevelScene()
	local resumeUid = resumeData:getUid()
	local resumeUdid = resumeData:getUdid()
	local resumeTime = resumeData:getTime()
	local resumeCurMd5 = resumeData:getCurMd5()
	local resumeVersion = resumeData:getResumeVersion()
	local resumeLevelId = resumeData:getLevelId()
	local resumeGroupInfo = resumeData:levelGroupInfo()
	local isAskForHelp = resumeData:isAskForHelp()
	local levelInfo = resumeData:getLevelInfo()
	local beginTime = levelInfo.beginTime

	local uid = UserManager:getInstance():getUID()
	local udid = MetaInfo:getInstance():getUdid() or "hasNoUdid"
	local curTime = Localhost:timeInSec()

	local UBFFeedAutoStartLogic = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.FeedAutoStart.UBFFeedAutoStartLogic"
	local logic = UBFFeedAutoStartLogic and UBFFeedAutoStartLogic:shareLogic()
	if logic and not logic:checkCanResume(resumeData) then
		log("Feed自动进关禁止闪退恢复")
		return ret(Reason.kIgnoreFeedAutoStart)
	end

	if NoviceExperienceOptimizationB and NoviceExperienceOptimizationB:isContinuousPlayMode() then
		return ret(Reason.kActivityRefuse, "NoviceExperienceOptimization")
	end

	if isAskForHelp then
		log("代打不可")
		return ret(Reason.kAskForHelp)
	end

	if udid == "hasNoUdid" then
		log("没有 uid")
		return ret(Reason.kUdidNotExist)
	end

	if tostring(resumeUid) ~= tostring(uid) then
		log("不同的 uid")
		return ret(Reason.kUserChanged, string.format("%s->%s", resumeUid, uid))
	end

	if tostring(resumeUdid) ~= tostring(udid) then
		log("不同的 udid")
		return ret(Reason.kDeviceChanged, string.format("%s->%s", resumeUdid, udid))
	end

	if curTime - resumeTime > UBFSectionResumeHelper.TIME_OUT then
		log("超时")
		return ret(Reason.kCrashOver1Hour, string.format("%s-%s", curTime, resumeTime))
	end

	local time = Localhost:timeInSec()
	-- if isPassDay(time, resumeTime) then
	-- 	log("跨天")
	-- 	return ret(Reason.kMainOrHiddenPassDay, string.format("%s-%s", time, resumeTime))
	-- end

	--
--
--


	if not self:_resumeRersionMD5Check(resumeCurMd5) then
		log("资源版本号 不同")
		local isMainType = table.includes({
			UBFLevelSceneType.kMain,
			UBFLevelSceneType.kHide,
			UBFLevelSceneType.kLib,
		},levelScene)
		local isOK = false
		local replayLog = self:getResumeData().replayLog
		local level,scene,baseInfo
		if isMainType then
			if replayLog then
				level,scene = replayLog.gEnv.levelId, replayLog.gEnv.levelScene
				baseInfo = UBFLevelConfigManager:userConfig():getLevelBaseInfo(level,scene)
				if baseInfo then
					-- 可以尝试录像恢复...
					isOK = true
				end
				-- 关卡配置找不到，不恢复
			end
			-- 没有录像，不恢复
		else
			-- 跨动更，又非主线关，不让恢复
		end
		if not isOK then
			local data = {}
			data.category = "resume"
			data.sub_category = "resume_md5_fail"
			data.old_md5 = resumeCurMd5
			data.rep_data = replayLog ~= nil and 1 or 0
			data.group = resumeGroupInfo.levelGroup
			data.level = levelId
			data.scene = levelScene
			if replayLog then
				data.rep_ver = replayLog.ver

				if replayLog then
					level,scene = replayLog.gEnv.levelId, replayLog.gEnv.levelScene
					baseInfo = UBFLevelConfigManager:userConfig():getLevelBaseInfo(level,scene)
					data.rep_level = level
					data.rep_scene = scene
					data.base_info = baseInfo ~= nil and 1 or 0
				end
			else
				local baseInfo = UBFLevelConfigManager:userConfig():getLevelBaseInfo(levelId,levelScene)
				data.base_info = baseInfo ~= nil and 1 or 0
			end
		    DcUtil:log(AcType.kExpire30Days, data)

			return ret(Reason.kUpdateVersionChanged)
		end
	else
		local levelGroup = UBFLevelConfigManager:userConfig():getLevelGroup(resumeLevelId, levelScene)
		if resumeGroupInfo.levelGroup ~= levelGroup then
			local str = string.format("%s->%s", resumeGroupInfo.levelGroup, levelGroup)
			log("资源版本号 相同,但是不同的 ubf分组:" .. str)
			return ret(Reason.kReplayVersionChanged, str)
		end
	end

	if not self:_resumeRersionCheck(resumeVersion) then
		log("闪退恢复逻辑版本 不同")
		return ret(Reason.kReplayVersionChanged, string.format("%s", resumeVersion))
	end

	if self:_overTopLevel(resumeLevelId, levelScene) then
		log("恢复levelid 大于当前topLevelId")
		return ret(Reason.kMainLevelAndGreaterTopLevel)
	end
	if self:_resumeModCheck(resumeData) then
		log("有过期不开的活动")
		return ret(Reason.kActivityRefuse)
	end

	if levelInfo.so_rust then
		require "ubf.UBFPlay.rust.UBFRustManager"
		UBFRustManager:loadModule()
		-- 这里应该是还原的，所以一定有只要提交一下，很快完成
		if levelInfo.so_rust_dy then UBFRustManager:tryLoadRustGo() end
	else
		if _G.UBF_RUST_ALL_IN then 
			log("rust all in!!")
			return ret(Reason.kRustAllIn)
		end
	end

	-- 最后活动
	local _data = {
		levelScene = levelScene,
		levelId = levelId,
		currTime = beginTime,
		hasCrashResume = true,
		resumeData = resumeData,
	}
	_G.amfEC:notifyFeature(FeatureEvent.JUDGE_HAS_CRASHRESUME, _data)
	if not _data.hasCrashResume then
		log("活动拒绝")
		local resaon = _data.crashResumeFailReason or Reason.kActivityRefuse
		return ret(resaon)
	end

	return ret()
end

-- 检查mod数据是否允许闪退恢复的逻辑
function UBFGameResumeLogic:_resumeModCheck(resumeData)
	local levelInfo = resumeData:getLevelInfo()
	local modList = levelInfo and levelInfo.modList or {}
	for _, v in ipairs(modList) do
		-- 只判断活动
		if tonumber(v.sourceId) and tonumber(v.sourceId) > 0 then
			local isActMod = v.mType and v.mType == UBFPlayModBuilder.BuffBuilderEnum.kMod
			local actConfig = UBFActHelper:getActConfig(v.sourceId)
			if isActMod and not actConfig then
				local resumeCurMd5 = resumeData:getCurMd5()
				local msg = string.format("actConfig has been deleted — game progress recovery not possible. sourceId: %s, beginTime: %s, resumeMd5: %s", v.sourceId, levelInfo.beginTime, resumeCurMd5)
				if EnvUtil:isDevelopMode() then
					UBFLogW(msg)
					CommonTip:showTip(msg)
				else
					he_log_error(msg)
				end
				return true
			end
		end
	end
end

function UBFGameResumeLogic:_resumeRersionMD5Check(replayCurMd5)
	return replayCurMd5 and replayCurMd5 == ResourceLoader.getCurVersion()
end

function UBFGameResumeLogic:_resumeRersionCheck(resumeVersion)
	local ver = UBFResumeMgr and UBFResumeMgr.Version or 0
	return resumeVersion and resumeVersion >= ver
end

function UBFGameResumeLogic:_overTopLevel(resumeLevelId, levelScene)
	local levelType = UBFLevelConfigManager:userConfig():getLevelType(resumeLevelId, levelScene)
	if levelType == GameLevelType.kMainLevel then
		local topLevelId = UserManager:getInstance().user:getTopLevelId()
		return resumeLevelId and resumeLevelId > topLevelId
	end
end

function UBFGameResumeLogic:popoutCrashResumePanel()
	local resumeData = UBFResumeData:create(self:getResumeData())
	local uid = resumeData:getUid()
	local udid = resumeData:getUdid()
	local playId = resumeData:getPlayId()
	local levelId = resumeData:getLevelId()
	local levelScene = resumeData:getLevelScene()
	local levelInfo = resumeData:getLevelInfo()
	local beginTime = levelInfo.beginTime
	local md5str = HeMathUtils:md5(tostring(playId))
	local levelNameStr = "第" .. levelId .. "关"
	local levelType = UBFLevelConfigManager:userConfig():getLevelType(levelId, levelScene)
	lua_switch(levelType){
		[GameLevelType.kMainLevel] = function ( ... )
			levelNameStr = "第" .. levelId .. "关"
		end,
		[GameLevelType.kHiddenLevel] = function ( ... )
			levelNameStr = "+" .. tostring(tonumber(levelId) - 10000) .. "关"
		end,
		[GameLevelType.kWeeklyRace2020] = function ( ... )
			levelNameStr = "周赛关"
		end
	}

	local promise = UBFPromise:create()
	local data = {
		uid = uid,
		udid = udid,
		playId = playId,
		levelId = levelId,
		levelScene = levelScene,
		resumeData = resumeData,
		outData = {
			levelNameStr = levelNameStr,
			appendStr = nil,
			winState = {},
			fullStr = nil
		},
	}

	_G.amfEC:notifyFeature(FeatureEvent.CREATE_RESUME_PANEL, data)

	local winState = data.outData.winState
	for i, v in ipairs(winState) do
		if v.priority == nil then
			v.priority = 999
		end
	end
	local function sortfunction(a,b)
		return a.priority < b.priority
	end
	table.sort( winState, sortfunction )

	if not data.outData.appendStr then
		local str = ""

		for i,v in ipairs(winState) do
			if i==1 then
				str = str .. v.showStr
			else
				str = str .. "，".. v.showStr
			end
		end
		if str ~= "" then
			local TimeUtil = require 'amf/middleware/ui/util/TimeUtil.lua'
			local timeSecStr = TimeUtil:formatDuration_dh_hm_ms(UBFSectionResumeHelper.TIME_OUT, 2)
			local timeStr = "，数据恢复有效期为"..timeSecStr
			data.outData.appendStr = "\n(" .. str .. timeStr..")"
		end
	end

	local dcT2 = ""
	local dcT3 = ""
	for i,v in ipairs(winState) do
		if i== 1 then
			dcT2 = dcT2 .. v.actId
			dcT3 = dcT3 .. v.actId.."_"..v.winNum
		else
			dcT2 = dcT2 .. "_".. v.actId
			dcT3 = dcT3 .. ";" .. v.actId.."_"..v.winNum
		end
	end

	local dcParams = {
		levelId = levelId,
		dataUid = uid,
		dataUdid = udid,
		md5str = md5str,
		panelId = UICreateUtil:getPanelId("crashResumePanel"),
		dcT2 = dcT2,
		dcT3 = dcT3
	}

	self.panelLogic = self:createResumePanel(
			data.outData.levelNameStr,
			data.outData.appendStr,
			function()
				local hasDevOp = false

				pcall(function()
					if not UBFDebug:isEasyDebug() then return end
					local resumeData = self:getResumeData() or {}
					local replayLog = resumeData.replayLog
					if replayLog then
						require("ubf.UBF.utils.UBFCommonRequire")("*")
						local oLogs = replayLog[UBFFastUseEnum.operationLogsKey]
						for _, v in ipairs(oLogs) do
							local obj = UBFOpLogMappingHelper:reflect(v)
							if obj.opType == 666 then
								hasDevOp = true
								break
							end
						end
					end
				end)

				if hasDevOp then
					CommonTip:showTip("检测到您使用了调试操作！请稍等，正在下载调试文件！请不要有任何其他操作，过长时间没有响应就证明失败了，重来吧。")
					require "ubf.UBFGamePlayScene.views.debugs.MiniGameDebug"
					return _G.__mini_game_download_promise:next(function()
						promise:resolve(true)
					end)
				end

				promise:resolve(true)

				self:dcSureResume(dcParams)
			end,
			function()
				self:dcFail(UBFGameResumeFailReason.kUserClose)
				promise:resolve(false)
			end,
			data.outData,
			dcParams
	)
	self.panelLogic:popout()

	self:dcSuccess( dcParams )

	return promise
end

function UBFGameResumeLogic:_closePanel()
	if self.panelLogic then
		self.panelLogic:close()
		self.panelLogic = nil
	end
end

function UBFGameResumeLogic:doResume()
	require("ubf.UBF.utils.UBFCommonRequire")("*")
	local resumeData = UBFResumeData:create(self:getResumeData())
	local uid = resumeData:getUid()
	local playId = resumeData:getPlayId()
	local levelId = resumeData:getLevelId()
	local levelScene = resumeData:getLevelScene()
	local md5str = HeMathUtils:md5(tostring(playId))
	local udid = resumeData:getUdid()
	local ostime = resumeData:getOstime()

	local function onSuccess()
		local levelInfo = resumeData:getLevelInfo()

		self:dcStart()
		if LocalBox then LocalBox:setData("buffOnResumeFlag", false) end
		self:_closePanel()
		self:_onOverByResume()

		local resumeDataVO = UBFResumeData:create(self:getResumeData())
		local resumeCurMd5 = resumeDataVO:getCurMd5()
		local resumeData = resumeDataVO.data

		local function startRustButFail()
			-- todo
		end

		local function startLaunchResume(trySectionResume)
			if levelInfo.so_rust then
				if not UBFRustManager then return end

				-- 回放回复，无所谓版本了，重新定义版本
				if resumeData.replayLog then 
					levelInfo.so_rust_dy = nil 
				end

				-- 强制初始化
				UBFRustManager:init()

				if UBFRustManager:isReady() then
					UBFProcessManager:launch(UBFGameProcessEnum.RESUME, { sectionData = resumeData })
				else
					UBFRustManager:loadModule(function()
						if UBFRustManager:isReady() then
							UBFProcessManager:launch(UBFGameProcessEnum.RESUME, { sectionData = resumeData })
						else
							-- GG 内核坏了？神仙来了也救不了
							startRustButFail()
						end
					end, function()
						-- GG rust下载失败
						startRustButFail()
					end, true)
				end
			else
				UBFProcessManager:launch(UBFGameProcessEnum.RESUME, { sectionData = resumeData })
			end
		end

		if not self:_resumeRersionMD5Check(resumeCurMd5) then
			-- 跨版本，需要更新 oplog
			local replayLog = self:getResumeData().replayLog

			local function doUpdateLevelInfo()
				-- 更新录像的关卡信息、动更号等
				local UBFTestLevelCfg = require 'ubf.UBFPlay.test.UBFTestLevelCfg'
				local levelCfg,levelGroupInfo = UBFTestLevelCfg:getConfigLua( replayLog.gEnv.levelId, replayLog.gEnv.levelScene )
				-- print("levelCfg---",replayLog.gEnv.levelId, replayLog.gEnv.levelScene,tts(levelCfg.levelInfo),tts(replayLog.gEnv))
				if levelCfg then
					local levelInfo = levelCfg.levelInfo
					local g = replayLog.gEnv
					local levelGroup = g.levelMeetGroup or g.levelGroup
					if replayLog.gEnv.levelUUID ~= levelInfo.uuid or replayLog.gEnv.levelUUIDVer ~= levelInfo.uuidVersion or levelGroup ~= levelGroupInfo.meetGroup then
						-- 关卡配置发生变化，强制更新
						g.levelInfoHistory = g.levelInfoHistory or {}
						table.insert(g.levelInfoHistory,{g.curMd5,g.levelUUID,g.levelUUIDVer,g.levelGroup,g.levelMeetGroup})

						resumeData.levelInfo.uuid = levelInfo.uuid

						g.levelUUID = levelInfo.uuid
						g.levelUUIDVer = levelInfo.uuidVersion
						g.levelGroup = tostring(levelGroupInfo.levelGroup)
						g.levelMeetGroup = levelGroupInfo.meetGroup

						local ret, meetGroup, uuid = UBFLevelIdUtil:traversalDefault(g.levelId, g.levelScene, g.expGroup)
						local rule = UBFLevelConfigManager:getLevelGroupRuleByGroupName(meetGroup, g.levelScene)
						g.fuuuGraphV3 = rule and rule.fuuuGraphV3
					end
				end
				replayLog.gEnv.md5History = replayLog.gEnv.md5History or {}
				table.insert(replayLog.gEnv.md5History,replayLog.gEnv.curMd5)
				-- 更新当前动更号，内部前端用
				replayLog.gEnv.curMd5 = ResourceLoader.getCurVersion()
				replayLog.gEnv.bundleVersion = _G.bundleVersion
				-- 外部后端用
				replayLog.curMd5 = replayLog.gEnv.curMd5
				resumeData.levelInfo.curMd5 = replayLog.gEnv.curMd5
			end

			local baseInfo = UBFLevelConfigManager:userConfig():getLevelBaseInfo(replayLog.gEnv.levelId, replayLog.gEnv.levelScene)
			local fileName = baseInfo[UBFLevelBaseInfoKey.FILE]
			local path = string.format("ubf/levelConfig/%s.levelpack", fileName)
			require "ubf.UBFPlay.views.render.loader.UBFResourceLoader"
			-- APLog.i("APPlayGame:preloadRes()path:",path)
			UBFResourceLoader.file:async(path):next(function(status)
				if status == UBResourceLoadStatus.READY then
					doUpdateLevelInfo()
					startLaunchResume()
				end
			end)
		else
			if levelInfo._is_must_replay_resume then
				if not resumeData.replayLog then 
					return startRustButFail()
				end
				-- 强制回放回复
			elseif not EnvUtil:isMiniGame() then
				-- app 时直接断面恢复，移除录像
				if levelInfo.so_rust then 
					-- 如果有动态模式
					if levelInfo.so_rust_dy then 
						-- 检查本地的动态和录像的动态是否一致
						local isOk = false
						xpcall(function()
							local hello_rust = CCFileUtils:sharedFileUtils():getFileData("ubf/rust/lib/rust_hash", "rb")
							local hello_rust = hello_rust and string.trim(hello_rust) or nil
							isOk = hello_rust == levelInfo.so_rust_dy
						end, debug.traceback)
						-- 一致就用断面，否则用录像
						if isOk then
							resumeData.replayLog = nil
						end
					else
						if UBFRustManager.isRustDyGoReady then 
							-- 启动go模式了，所以这里必须用录像了
						else
							resumeData.replayLog = nil
						end
					end
				else
					resumeData.replayLog = nil
				end
			else
				-- 小游戏，仅rust能断面恢复
				if levelInfo.so_rust and resumeData.section then
					resumeData.replayLog = nil
				end
			end
			startLaunchResume()
		end

		UBFSectionResumeHelper:removeSavedSection()
	end

	-- 检查次数条件
	local function checkResumeTimes(nextAction)
		if log then log("checkResumeTimes") end

		local function onSuccess()
			if log then log("checkResumeTimes success") end
			nextAction()
		end
		local function onFail()
			if log then log("checkResumeTimes onFail") end
			self:afterNotResume(false,UBFGameResumeFailReason.kMd5CheckFail)

			self:_closePanel()

			local text = {tip = Localization:getInstance():getText("crash.resume.failed") , yes = "确定"}
			if CommonTipWithBtn then
				CommonTipWithBtn:showTip({
					tipStr = text.tip,
					animalType = CommonTipWithBtn.TopUIType.DUDU,
					okInfo = { btnStr = text.yes, },
					noInfo = { hide = true, },
				})
			else CommonTip:showTip(text.tip) end
		end

		local resumeData = UBFResumeData:create(self:getResumeData())
		local function isResumeTimesValid()
			local resumed = resumeData:isResumed()
			if log then log("checkResumeTimes isResumeTimesValid resumed",resumed,resumeData,resumeData:getResumeCount()) end

			if resumed then
				local resumeCount = resumeData:getResumeCount()
				local usePropCount = resumeData:getUsePropCount()
				if log then log("checkResumeTimes isResumeTimesValid", resumeCount, usePropCount) end
				if resumeCount <= 5 then return true
				elseif usePropCount > 0 then return true end
			end
		end

		if isResumeTimesValid() then
			onSuccess()
		else
			if log then log("checkResumeTimes not valid") end
			local levelId = resumeData:getLevelId()
			local md5str = HeMathUtils:md5(tostring(resumeData:getPlayId()))
			UBFProtocolMethod:send {
				method = UBFGameMethodType.kResumeLevel,
				body = {
					md5 = md5str
				},
			} : next(function(response)
				if log then log("checkResumeTimes not valid response",table.tostring(response)) end

				if response.byCancel then return self:cancelResume() end
				if response.err then return onFail() end
				return onSuccess()
			end)
		end
	end

	checkResumeTimes(onSuccess)
end

function UBFGameResumeLogic:cancelResume()
	self:afterNotResume(true,UBFGameResumeFailReason.kUserClose)
	self:_closePanel()
end

local AMFRequest = require "amf.middleware.interconnection.remote.core.AMFRequest"
local Request = class("CancelCrashResumePanel", AMFRequest)

local config = {
	protocol = "cancelCrashResumePanel",
	reqType = AMFSyncConst.RequestType.OFFLINE,
	loading = false,
	useMockData = false
}

function Request:post(params, hostObj)
	return Request:run(config, params, hostObj)
end

function UBFGameResumeLogic:afterNotResume( bFromCancle, errCode )
	if log then log("afterNotResume",bFromCancle,errCode) end

	if bFromCancle == nil then bFromCancle = false end
	local resumeData = UBFResumeData:create(self:getResumeData())
	local uid = resumeData:getUid()
	local playId = resumeData:getPlayId()
	local levelId = resumeData:getLevelId()
	local levelType = resumeData:getLevelType()
	local levelScene = resumeData:getLevelScene()
	local md5str = HeMathUtils:md5( tostring(playId) )
	local udid = resumeData:getUdid()
	local sceneData = resumeData:getSceneData()

	if PreBuffLogic and PreBuffLogic.isInited then
		PreBuffLogic:onPassLevel( levelId , 0 , GameGuide:isNoPreBuffLevel(levelId) , false , "crash" )
	end

	-- 失败 断连胜
	local topLevelId = UserService:getInstance().user:getTopLevelId()
	if levelId == topLevelId then
		if UserManager:getInstance():isTopNoPassLevel(levelId) then
			UserManager:getInstance().userExtend:resetTopLevelWinCount()
			UserService:getInstance().userExtend:resetTopLevelWinCount()
			UserManager:getInstance().userExtend:resetTopLevelLogicalWinCount()
			UserService:getInstance().userExtend:resetTopLevelLogicalWinCount()
		end
		UserManager:getInstance().userExtend:resetTopLevelContinueWinCount()
		UserService:getInstance().userExtend:resetTopLevelContinueWinCount()
		if BarrageAchievementUtil then
			BarrageAchievementUtil:checkAndUpdatePassDataOnPassLevel(false)
		end
	end

	local logicalFail = false
	local curMoves =  sceneData.moveCount or 0
	local levelInfo = UBFLevelConfigManager:userConfig():getLevelBaseInfo(levelId, levelScene)
	local totalMoves = levelInfo and levelInfo[UBFLevelBaseInfoKey.STATIC_STEP] or 0
	logicalFail = curMoves >= totalMoves * 0.5

	if logicalFail then
		-- 只加逻辑失败，是因为普通失败已经在进关时加过了
		UserManager:getInstance().userExtend:incrTopLevelLogicalFailCount()
		UserService:getInstance().userExtend:incrTopLevelLogicalFailCount()
	end
	-- LocalBox:setData( "buffOnResumeFlag" , false )
	local cancelCrashReason = errCode
	local levelInfo = resumeData:getLevelInfo()
	local usePropList = levelInfo and levelInfo.usePropList or {}
	local usedProps = {}
	for i, v in ipairs(usePropList) do
		local found = false
		for i2, v2 in ipairs(usedProps) do
			if v2.itemId == v.propId then
				found = true
				v2.num = v2.num + 1
				break
			end
		end
		if not found then
			table.insert(usedProps, {itemId = v.propId, num = 1})
		end
	end
	local _data = {
		levelId = levelId,
		levelType = levelType,
		levelScene = levelScene,
		gameData = nil,
		resumeData = resumeData,
		checkFailed = false,
		json = {},
		--下面的CancelCrashResumePanel协议结束时的回调，活动可在此处同步最新的数据（连胜）
		callbacks = {},
		cancelCrashReason = cancelCrashReason,
	}

	self:sendResumeFail(_data, logicalFail, levelScene, playId, usedProps)

	self:_onOverByNotResume()

	-- 打点
	self:dcFail(errCode)
	-- 清除闪退数据
	UBFSectionResumeHelper:removeSavedSection()

	self._lastResumeFailData = _data
end


function UBFGameResumeLogic:getLevelFarmingType(levelInfo)
	local levelId = levelInfo.levelId
	local levelType = levelInfo.levelType
	local topLevelId = levelInfo.topLevelId
	local oldStar = levelInfo.oldStar or 0

	local levelFarmingType = UBFLevelFarmingType.NORMAL
	if levelType == GameLevelType.kMainLevel then
		if oldStar >= 4 then
			levelFarmingType = UBFLevelFarmingType.FARM_SCORE
		elseif oldStar > 0 then
			levelFarmingType = UBFLevelFarmingType.FARM_STAR
		else
			if levelId == topLevelId then
				levelFarmingType = UBFLevelFarmingType.NORMAL
			else
				levelFarmingType = UBFLevelFarmingType.FARM_STAR
			end
		end
	elseif levelType == GameLevelType.kHiddenLevel then
		if oldStar >= 3 then
			levelFarmingType = UBFLevelFarmingType.FARM_SCORE
		elseif oldStar > 0 then
			levelFarmingType = UBFLevelFarmingType.FARM_STAR
		else
			levelFarmingType = UBFLevelFarmingType.NORMAL
		end
	end
	return levelFarmingType
end

function UBFGameResumeLogic:getClientStreakWinScene(levelInfo)
	if not levelInfo then return end
	local levelScene = levelInfo.levelScene
	local clientStreakWinScene
	if levelScene == UBFLevelSceneType.kFullLevelLibrary then
		clientStreakWinScene = "FLFSLL"
	elseif levelScene == UBFLevelSceneType.kMain then
		local farmingType = self:getLevelFarmingType(levelInfo)
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
	return clientStreakWinScene
end

function UBFGameResumeLogic:sendResumeFail( _data, logicalFail, levelScene, playId, usedProps)

	local AsyncRunner = require "amf.script.sugar.AsyncRunner"
	_data.closeActionList = AsyncRunner:create()
	_G.amfEC:notifyFeature(FeatureEvent.CRASH_RESUME_FAILED, _data)

	local levelInfo
	if _data.resumeData and _data.resumeData.data then
		levelInfo = _data.resumeData.data.levelInfo
	end

	local jsonStr
	if _data.json then
		jsonStr = table.serialize(_data.json)
	end

	local function onSuccess()
		_data.closeActionList:run()
		for k, v in pairs(_data.callbacks) do
			safeRunCall(v)
		end
	end
	Request:post({
		levelId = _data.levelId,
		logicalFail = logicalFail,
		levelScene = levelScene,
		json = jsonStr,
		clientStreakWinScene = self:getClientStreakWinScene(levelInfo),
		playId = playId,
		cancelCrashReason = _data.cancelCrashReason,
		usedProps = usedProps,
	}):next(onSuccess)
end

function UBFGameResumeLogic:dcSuccess(dcParams)
	if not DcUtil then return end
	-- local resumeData = UBFResumeData:create(self:getResumeData())
	-- local uid = resumeData:getUid()
	-- local udid = resumeData:getUdid()
	-- local playId = resumeData:getPlayId()
	-- local levelId = resumeData:getLevelId()
	-- local levelScene = resumeData:getLevelScene()
	-- local md5str = HeMathUtils:md5(tostring(playId))
	-- DcUtil:popCrashResumePanel(
	-- 	levelId,
	-- 	UserManager:getInstance():getUID(),
	-- 	MetaInfo:getInstance():getUdid() or "hasNoUdid",
	-- 	uid, udid,
	-- 	md5str
	-- )

	DcUtil:dcForUserTrack({
		category = "crash_resume",
		sub_category = "crash_resume_pop",
		-- meta_level_id = LevelMapManager.getInstance():getMetaLevelId(self.dcParams.levelId),
		panel_id = dcParams.panelId,
		t1 = dcParams.levelId,
		t2 = dcParams.dcT2,
		t3 = dcParams.dcT3,
		t4 = dcParams.dataUid,
		t5 = dcParams.dataUdid,
		t6 = dcParams.md5str,

	})
end

function UBFGameResumeLogic:dcSureResume(dcParams)
	--dc
	local params = {
		category = "crash_resume",
		sub_category = "crash_resume_click",
		panel_id = dcParams.panelId,
		t1 = dcParams.dcT2
	}
	DcUtil:dcForUserTrack(params)
end

function UBFGameResumeLogic:dcFail(reason)
	if self._dcResultDone then return end
	if not DcUtil then return end
	local resumeData = UBFResumeData:create(self:getResumeData())
	local uid = resumeData:getUid()
	local udid = resumeData:getUdid()
	local playId = resumeData:getPlayId()
	local levelId = resumeData:getLevelId()
	local levelScene = resumeData:getLevelScene()
	local md5str = HeMathUtils:md5(tostring(playId))
	DcUtil:crashResumeFailed(
		reason, levelId,
		UserManager:getInstance():getUID(),
		MetaInfo:getInstance():getUdid() or "hasNoUdid",
		uid, udid,
		md5str
	)
	self._dcResultDone = true
end

function UBFGameResumeLogic:dcStart()
	if self._dcResultDone then return end
	if not DcUtil then return end
	local resumeData = UBFResumeData:create(self:getResumeData())
	local uid = resumeData:getUid()
	local udid = resumeData:getUdid()
	local playId = resumeData:getPlayId()
	local levelId = resumeData:getLevelId()
	local levelScene = resumeData:getLevelScene()
	local md5str = HeMathUtils:md5(tostring(playId))
	local totalSteps = 0
	DcUtil:crashResumeStart(
		levelId, totalSteps,
		UserManager:getInstance():getUID(),
		MetaInfo:getInstance():getUdid() or "hasNoUdid",
		uid, udid, md5str
	)
	self._dcResultDone = true
end

function UBFGameResumeLogic:createResumePanel(levelNameStr, appendStr, yesCallback , noCallback, outData, dcParams )
	local logic = self:_createMyResumePanel(levelNameStr, appendStr, yesCallback , noCallback)
	return logic
end

function UBFGameResumeLogic:_createMyResumePanel(levelNameStr, appendStr, yesCallback , noCallback, outData, dcParams)
	local text = Localization:getInstance():getText("crash.resume.tip.start", { level = levelNameStr } )
	local btnStr = Localization:getInstance():getText("crash.resume.btn.start")

	if btnStr == "crash.resume.btn.start" then
		btnStr = "确认恢复"
	end

	if appendStr then text = text .. "\n" .. appendStr end

	local panelId = UICreateUtil:getPanelId("crashResumePanel")


	local FourthPanelAVM = require "amf.middleware.ui.kit.panel.fourth.FourthPanelAVM"
	local vm = FourthPanelAVM.Builder.new()
		:setText(text)
		:setButtonsConfig({
			{
				str = btnStr,
				widthMode = UIButtonConfig.Widths.kShort,
				colorMode = UIButtonConfig.ColorMode.green,
				touchFunc = function(btn)
					safeRunCall(yesCallback)
				end
			},
		})
		:setCloseCallback(function()
			safeRunCall(noCallback)
		end)
		:build()

	if EnvUtil:isDevelopMode() then
		local rect =  UICreateUtil:createRect(600,120,ccc3(255,255,255),240)
		rect:setPositionXY(60,940)
		rect:setAnchorPoint(ccp(0,0))
		rect:ignoreAnchorPointForPosition()
		vm.view:addChild(rect)

		local data = self:getResumeData()
		local str = "当前动更:" .. tostring( ResourceLoader:getCurVersion() )
			.. "\n闪退动更:" .. tostring( data.replayLog and data.replayLog.gEnv.curMd5 )
			.. "\n包含录像:" .. (data.replayLog and "true" or "false")

		local label = TextField:create(str, nil, 20, CCSizeMake(600,0), kCCTextAlignmentLeft, kCCVerticalTextAlignmentTop)
		label:setColor(ccc3(255,50,100))
		label:setPositionXY(30,100)
		label:setAnchorPoint(ccp(0,1))
		rect:addChild(label)
	end

	vm.panelId = panelId
	return vm
end

function UBFGameResumeLogic:_onOverByResume()

end

function UBFGameResumeLogic:_onOverByNotResume()

end

-- called after self:checkCanResume() return true in AutoPopup
function UBFGameResumeLogic:handleMiniGameResume()
	local miniPromise = UBFPromise:create()
	self._onOverByResume = function()
		if UBFPromise.isFin(miniPromise) then return end
		miniPromise:resolve(true)
	end
	self._onOverByNotResume = function()
		if UBFPromise.isFin(miniPromise) then return end
		miniPromise:resolve(false)
	end
	local promise = self:popoutCrashResumePanel()
	promise:next(function(doResume)
		if not doResume then
			self:cancelResume()
		else
			self:doResume()
		end
	end)
	return miniPromise
end

function UBFGameResumeLogic:getLastResumeFailData()
	return self._lastResumeFailData
end

return UBFGameResumeLogic
