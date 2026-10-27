
-- @ref 强弹框架: 总管理器
require "amf.middleware.autopop.config.AutoPopupConst"
require "amf.middleware.autopop.event.AutoPopEventCenter"
local AutoPopupCheckPoints = require "amf.middleware.autopop.config.AutoPopupCheckPoints"
require "amf.middleware.autopop.dc.AutoPopupDC"
local AutoPopupDebugLog = require "amf.middleware.autopop.AutoPopupDebugLog"
local LogReason = AutoPopupDebugLog.Reason
local AutoPopupLimit = require "amf.middleware.autopop.config.AutoPopupLimit"
local PopupStateMachine = require "amf.middleware.autopop.fsm.PopupStateMachine"
local PopupSchedule = require "amf.middleware.autopop.module.schedule.PopupSchedule"

local AutoPopupMgr = class("AutoPopupMgr")
local privateNS = {}
local debugDisabledKey = "game_console_auto_popup_disabled"
function AutoPopupMgr:ctor()
	self._popoutManager = nil
	self._optionalDataManager = nil
	self._userStateManager = nil
	self._popupSchedule = PopupSchedule:create(self)
	self._interruptibleEntries = {}
end

function AutoPopupMgr:setUserStateManager(mgr)
	self._userStateManager = mgr
end

function AutoPopupMgr:setPopoutManager(mgr)
	self._popoutManager = mgr
end

function AutoPopupMgr:setOptionalDataManager(mgr)
    self._optionalDataManager = mgr
end

function AutoPopupMgr:setPlayLevelFlowMgr(mgr)
	self._playLevelFlowMgr = mgr
end

function AutoPopupMgr:initialize()
	self:initSwitch()
	self:initStaticConfig()
	self:initPopupQueues()
	self:initModel()
	AutoPopupDebugLog:initializeSceneLog()
	self:initPopupRegistration()
	self:initPolicyHandlers()
	self:initStageMachine()
	self:initCheckPointBlockMgr()
	self:registerEvent()
	self:clearTmpPopTypePopNum()
	self:clearCheckPointLimitedStages()
end

function AutoPopupMgr:initCheckPointBlockMgr()
	local CheckPointBlockMgr = require "amf.middleware.autopop.config.CheckPointBlockMgr"
	self._checkPointBlockMgr = CheckPointBlockMgr:create()
end

function AutoPopupMgr:initPopupRegistration()
	local PopupRegistration = require "amf.middleware.autopop.module.registration.PopupRegistration"
	self._popupRegistration = PopupRegistration:create(self)
end

--- 声明式强弹注册（新框架入口）
-- @param config table: { checkPoint, stages, check?, pop?, actId? }
--   checkPoint 即唯一身份；popType/priority 由 AutoPopupCheckPoints.InnerPriority 统一定义，
--   每日次数上限由 AutoPopupLimit 静态定义，注册不支持运行时覆盖。
--   creator 为兼容旧注册项保留，新增注册优先使用 pop。
--   详见 PopupRegistration:register 文档
function AutoPopupMgr:registerPopup(config)
	return self._popupRegistration:register(config)
end

--- 取消声明式强弹注册
-- @param popupCheckPoint string 注册时的 popupCheckPoint
function AutoPopupMgr:unregisterPopup(popupCheckPoint)
	self._popupRegistration:unregister(popupCheckPoint)
end
function AutoPopupMgr:setPopupScheduleResolver(resolver)
	self._popupSchedule:setResolver(resolver)
end

function AutoPopupMgr:initSwitch()
	self._isEnabled = true
	if EnvUtil:isDevelopMode() then
		self._isNumLimitEnabled = false
		local userDefault = CCUserDefault and CCUserDefault:sharedUserDefault()
		if userDefault and userDefault:getBoolForKey(debugDisabledKey, false) then
			self._isEnabled = false
		end
	else
		self._isNumLimitEnabled = true
	end
end

function AutoPopupMgr:isEnabled()
	return self._isEnabled
end

function AutoPopupMgr:setEnabled(bool)
	self._isEnabled = bool
end

function AutoPopupMgr:initStaticConfig()
	self.staticPopType = {}
	self.staticPriority = {}

	for popType, group in pairs(AutoPopupCheckPoints.InnerPriority) do
		for priority, popupCheckPoint in ipairs(group) do
			self.staticPopType[popupCheckPoint] = popType
			self.staticPriority[popupCheckPoint] = priority
		end
	end
end

function AutoPopupMgr:initPopupQueues()
	self.queuePolicy = {}
	self.queueOutside = {}
	self.queueSystem = {}
	self.queueActivity = {}
	self.queueRecall = {}
	self.queueCondition = {}
	self.queueFunction = {}
	self.queueCrashResume = {}
	self.queueGuides = {}
	self.queueGiftPack = {}
	self.queueTempActPanel = {}
	self:resetPopupScheduleOrder()
end

-- 场景调度的状态与算法都在 PopupSchedule 里，这里只保留对外的转发入口。

-- 清除当前场景的排序结果。队列重建或开始新场景时调用。
function AutoPopupMgr:resetPopupScheduleOrder()
	self._popupSchedule:reset()
end

-- 外部排序依据（例如 AI 推荐权重）变化时调用；队列内容不变也需要重新解析。
function AutoPopupMgr:invalidatePopupSchedule()
	self._popupSchedule:invalidate()
end

-- 场景开始时为声明式和运行时候选建立统一调度顺序。候选即使未通过
-- check，也要保留这份顺序，日志才能反映真实调度优先级而不是弹出结果。
function AutoPopupMgr:preparePopupScheduleDefinitions(popStage, definitions)
	return self._popupSchedule:prepareDefinitions(popStage, definitions)
end

-- popupCheckPoint 在统一调度顺序中的排名。
function AutoPopupMgr:getPopupScheduleRank(popStage, popupCheckPoint)
	return self._popupSchedule:getRank(popStage, popupCheckPoint)
end

-- 重发一次当前场景的候选顺序。日志可能在最后一次调度解析之后才登记候选，
-- 场景结束时补发一次，列表才有完整的顺序位置和干预信息。
function AutoPopupMgr:publishPopupScheduleOrder(popStage)
	self._popupSchedule:publishScheduleOrder(popStage)
end

-- 登记一个运行时候选（配置式）。注册式候选由注册中心定义快照提供。
function AutoPopupMgr:_recordDynamicPopupScheduleCandidate(popupEntry)
	self._popupSchedule:recordRuntimeCandidate(popupEntry)
end

-- 队列内容变化后调用；下一次消费前会重新计算顺序。
function AutoPopupMgr:_markPopupScheduleDirty()
	self._popupSchedule:markDirty()
end

-- 限流归属按 popupCheckPoint 对应的 PopType 计算；popupCheckPoint 同时是队列寻址键。
function AutoPopupMgr:getNextPopupEntryAcrossPopTypes(popStage)
	local normalizedPopStage = AutoPopupConst.PopStageKeyMapping[tostring(popStage)] or popStage
	local orderedCheckPoints = self._popupSchedule:getOrderedCheckPoints(normalizedPopStage)
	local checkList = self:getPopupCheckList(normalizedPopStage) or {}
	local listed = {}
	for _, popType in ipairs(checkList) do listed[popType] = true end

	for _, popupCheckPoint in ipairs(orderedCheckPoints) do
		local popType = self:getPopType(popupCheckPoint)
		local allowed = listed[popType] ~= false
		-- popType 级限流命中时，该类型下所有候选都不参与本轮竞争，逐条记录原因。
		local popTypeFailReason
		if allowed then
			if self:isLimitedByStageChange(normalizedPopStage, popType) then
				popTypeFailReason = LogReason.Enqueue.STAGE_CHANGE_LIMIT
			elseif self:isLimitedBySameStage(normalizedPopStage, popType) then
				popTypeFailReason = LogReason.Enqueue.SAME_STAGE_LIMIT
			elseif self:isLimitedByDailyPopType(normalizedPopStage, popType) then
				popTypeFailReason = LogReason.Enqueue.POP_TYPE_DAILY_LIMIT
			elseif self:isLimitedByPopType(normalizedPopStage, popType) then
				popTypeFailReason = LogReason.Enqueue.POP_TYPE_ROUND_LIMIT
			end
		end
		local popupEntry = self:getPopupQueueByPopType(popType)[popupCheckPoint]
		if popTypeFailReason then
			if popupEntry then
				AutoPopupDebugLog:recordPopupEnqueue(
					popupEntry, "fail", popTypeFailReason, popupCheckPoint
				)
			end
		elseif popupEntry then
			local failedReason
			if self:isLimitedBySpecifiedPopStages(popupCheckPoint, normalizedPopStage) then
				failedReason = LogReason.Enqueue.SPECIFIED_POP_STAGES
			elseif self:isLimitedByStageOnly(popupCheckPoint, normalizedPopStage) then
				failedReason = LogReason.Enqueue.STAGE_ONLY
			elseif self:isCheckPointBlockedByRule(popupCheckPoint, normalizedPopStage) then
				failedReason = LogReason.Enqueue.CHECK_POINT_BLOCK_RULE
			end
			if not failedReason then
				AutoPopupDebugLog:recordPopupEnqueue(
					popupEntry, "success", nil, popupCheckPoint
				)
				return {
					checkPoint = popupCheckPoint,
					popupEntry = popupEntry,
				}
			end
			AutoPopupDebugLog:recordPopupEnqueue(
				popupEntry, "fail", failedReason, popupCheckPoint
			)
		end
	end
	return nil
end

-- 准备本场景所有会被 FSM 消费的候选顺序。场景 handler 完成本轮入队后
-- 由 doPopup 调用一次；异步入队或直接调用时也会按需准备。
function AutoPopupMgr:preparePopupSchedule(popStage)
	return self._popupSchedule:prepare(popStage)
end
function AutoPopupMgr:initModel()
	local PopupModel = require "amf.middleware.autopop.model.PopupModel"
	privateNS.model = PopupModel:create()
	AutoPopupDebugLog:setPopupModel(privateNS.model)
	local serverPopupRecord = self._optionalDataManager:getTempOptionalDataValue("clientPopupInfo")
	privateNS.model:syncServerRecord(serverPopupRecord)

	self:initServerConfig()
end

function AutoPopupMgr:initServerConfig()
	local ServerConfigMgr = require "amf.middleware.autopop.config.ServerConfigMgr"
	self._serverConfigMgr = ServerConfigMgr:create()
	self._serverConfigMgr:update(privateNS.model:getServerPopupConfig())
end

function AutoPopupMgr:initPolicyHandlers()
	require ("amf.middleware.autopop.module.poptype.PolicyHandler"):create(self)
	require ("amf.middleware.autopop.module.poptype.SystemHandler"):create(self)
	require ("amf.middleware.autopop.module.poptype.ConditionHandler"):create(self)
	require ("amf.middleware.autopop.module.poptype.ActivityHandler"):create(self)
	require ("amf.middleware.autopop.module.poptype.FunctionHandler"):create(self)
	require ("amf.middleware.autopop.module.poptype.CrashResumeHandler"):create(self)
    require ("amf.middleware.autopop.module.poptype.OutsideHandler"):create(self)
    require ("amf.middleware.autopop.module.poptype.TempActPanelHandler"):create(self)
    require ("amf.middleware.autopop.module.poptype.RecallHandler"):create(self)
end

function AutoPopupMgr:initStageMachine()
	self.fsm = PopupStateMachine:create(self)
end

function AutoPopupMgr:registerEvent()
	AutoPopEventCenter:registerGlobal(NormalEvent.PASS_DAY, self.onPassDay, self)
	if not _G.kUserLogin then
		AutoPopEventCenter:registerGlobal(NormalEvent.USER_LOGIN, self.postInitServerData, self)
	end

	_G.amfEC:registerFeature(self, FeatureEventPriority.AUTO_POPUP)
	_G.amfEC:registerSystem(self)

	AutoPopEventCenter:register(AutoPopEvent.MANUAL_REMOVE_POP, self.removeByManualPopup, self)
end

-- called just before PassDayEvent dispatched
function AutoPopupMgr:onPassDay()
	if not self:isEnabled() then return end

	privateNS.model:resetDailyData()
	self:initPopupQueues()
	self._popupRegistration:onPassDay()
end

function AutoPopupMgr:postInitServerData()
	AutoPopEventCenter:unregisterGlobal(NormalEvent.USER_LOGIN, self.postInitServerData)

	local serverPopupRecord = self._optionalDataManager:getClientPopupInfo()
	privateNS.model:syncServerRecord(serverPopupRecord)

	self._serverConfigMgr:update(privateNS.model:getServerPopupConfig())
end

function AutoPopupMgr:getPopType(popupCheckPoint)
	local popType = self.staticPopType[popupCheckPoint]
	assert(popType, "no popType for popupCheckPoint: " .. tostring(popupCheckPoint))
	return popType
end

function AutoPopupMgr:getPriority(popupCheckPoint)
	local priority = self.staticPriority[popupCheckPoint]
	assert(priority, "no priority for popupCheckPoint: " .. tostring(popupCheckPoint))
	return priority
end

-- 两个 popupCheckPoint 的静态优先级比较：先比当前场景的 PopType 顺序，再比组内优先级。
function AutoPopupMgr:compareCheckPointPriority(popStage, leftCheckPoint, rightCheckPoint)
	return self._popupSchedule:comparePriority(popStage, leftCheckPoint, rightCheckPoint)
end

-- popupCheckPoint 是队列的唯一定位键（身份 = 规则 = 槽位）。
-- 未在 AutoPopupCheckPoints 登记过的 popupCheckPoint 没有队列，返回 nil。
function AutoPopupMgr:getPopupQueueByCheckPoint(popupCheckPoint)
	local popType = self.staticPopType[popupCheckPoint]
	if not popType then return end

	return self:getPopupQueueByPopType(popType)
end
function AutoPopupMgr:getPopupQueueByPopType(popType)
	return lua_switch(popType){
		[AutoPopupConst.PopType.POLICY] = self.queuePolicy,
		[AutoPopupConst.PopType.OUTSIDE] = self.queueOutside,
		[AutoPopupConst.PopType.SYSTEM] = self.queueSystem,
		[AutoPopupConst.PopType.ACTIVITY] = self.queueActivity,
		[AutoPopupConst.PopType.RECALL] = self.queueRecall,
		[AutoPopupConst.PopType.CONDITION] = self.queueCondition,
		[AutoPopupConst.PopType.FUNCTION] = self.queueFunction,
		[AutoPopupConst.PopType.CRASH_RESUME] = self.queueCrashResume,
		[AutoPopupConst.PopType.GUIDE] = self.queueGuides,
		[AutoPopupConst.PopType.GIFT_PACK] = self.queueGiftPack,
		[AutoPopupConst.PopType.TMP_ACT_PANEL] = self.queueTempActPanel,
		default = function ()
			assert(false, "invalid popType : " .. popType)
		end
	}
end

function AutoPopupMgr:clearPopupQueueByPopType(popType)
	lua_switch(popType){
		[AutoPopupConst.PopType.POLICY] = function () self.queuePolicy = {} end,
		[AutoPopupConst.PopType.OUTSIDE] = function () self.queueOutside = {} end,
		[AutoPopupConst.PopType.SYSTEM] = function () self.queueSystem = {} end,
		[AutoPopupConst.PopType.ACTIVITY] = function () self.queueActivity = {} end,
		[AutoPopupConst.PopType.RECALL] = function () self.queueRecall = {} end,
		[AutoPopupConst.PopType.CONDITION] = function () self.queueCondition = {} end,
		[AutoPopupConst.PopType.FUNCTION] = function () self.queueFunction = {} end,
		[AutoPopupConst.PopType.CRASH_RESUME] = function () self.queueCrashResume = {} end,
		[AutoPopupConst.PopType.GUIDE] = function () self.queueGuides = {} end,
		[AutoPopupConst.PopType.GIFT_PACK] = function () self.queueGiftPack = {} end,
		[AutoPopupConst.PopType.TMP_ACT_PANEL] = function () self.queueTempActPanel = {} end,
		default = function ()
			assert(false, "invalid popType : " .. popType)
		end
	}
	self:_markPopupScheduleDirty()
end

function AutoPopupMgr:isCheckPointBlockedByRule(popupCheckPoint, popStage)
	if self._checkPointBlockMgr:isCheckPointBlocked(popupCheckPoint) then
		AutoPopupDebugLog:log("getNextPopupEntry: blocked by rule [checkPoint]",
			popupCheckPoint,
			self._checkPointBlockMgr:getCheckPointBlockReason(popupCheckPoint))
		return true
	end
	if self._checkPointBlockMgr:isCheckPointBlockedInStage(popupCheckPoint, popStage) then
		AutoPopupDebugLog:log("getNextPopupEntry: blocked by rule [checkPoint+stage]",
			popupCheckPoint, popStage,
			self._checkPointBlockMgr:getCheckPointStageBlockReason(popupCheckPoint))
		return true
	end
	return false
end

function AutoPopupMgr:isPopTypeBlockedByRule(popType, popStage)
	if self._checkPointBlockMgr:isPopTypeBlocked(popType) then
		AutoPopupDebugLog:log("getNextPopupEntry: blocked by rule [popType]",
			popType,
			self._checkPointBlockMgr:getPopTypeBlockReason(popType))
		return true
	end
	if self._checkPointBlockMgr:isPopTypeBlockedInStage(popType, popStage) then
		AutoPopupDebugLog:log("getNextPopupEntry: blocked by rule [popType+stage]",
			popType, popStage,
			self._checkPointBlockMgr:getPopTypeStageBlockReason(popType))
		return true
	end
	return false
end

-- 动态指定某个强弹只能弹在特定某场景，目前用于礼包和活动主面板的强弹配置
function AutoPopupMgr:setCheckPointLimitedStages(popupCheckPoint, limitStages)
	local popStages = {}
	for k,v in pairs(limitStages) do
		local popStage = AutoPopupConst.PopStageKeyMapping[tostring(v)]
		if popStage then
			table.insert(popStages, popStage)
		end
	end
	if not table.isEmpty(popStages) then
		self.checkPointLimitedStages[popupCheckPoint] = popStages
	else
		self.checkPointLimitedStages[popupCheckPoint] = nil
	end
end

function AutoPopupMgr:isLimitedBySpecifiedPopStages(popupCheckPoint, popStage)
	if not self.checkPointLimitedStages[popupCheckPoint] then return false end
	if table.includes(self.checkPointLimitedStages[popupCheckPoint], popStage) then
		return false
	else
		AutoPopupDebugLog:log("PopupCheckPopState:onEnter() isLimitedBySpecifiedPopStages ", popupCheckPoint, popStage)
		return true
	end
end

function AutoPopupMgr:clearCheckPointLimitedStages(popupCheckPoint)
	if popupCheckPoint then
		self.checkPointLimitedStages[popupCheckPoint] = nil
	else
		self.checkPointLimitedStages = {}
	end
end

function AutoPopupMgr:setPopStage(popStage)
	self.popStage = popStage
end

function AutoPopupMgr:getPopStage()
	return self.popStage
end

function AutoPopupMgr:getPopupCheckList(popStage)
	return self._serverConfigMgr:getPopTypeFullPriority(popStage)
end

-----------BEGIN 每一次强弹状态机启动后（对应某个强弹场景），次数限制-----------
function AutoPopupMgr:isLimitedByPopType(popStage, popType)
	local limitNum = self:getPopTypeLimitNum(popStage, popType)
	local popedNum = self:getTmpPopTypePopNum(popType)
	if limitNum > popedNum then
		return false
	end

	return true
end

function AutoPopupMgr:getPopTypeLimitNum(popStage, popType)
	return self._serverConfigMgr:getPopTypeLimitNum(popStage, popType)
end

function AutoPopupMgr:getTmpPopTypePopNum(popType)
	if not self.tmpPopTypePopNum[popType] then
		self.tmpPopTypePopNum[popType] = 0
	end
	return self.tmpPopTypePopNum[popType]
end

function AutoPopupMgr:getTmpPopTypePopSum()
	local sum = 0
	for k,popNum in pairs(self.tmpPopTypePopNum) do
		sum = popNum + sum
	end
	return sum
end

function AutoPopupMgr:increaseTmpPopTypePopNum(popType)
	local currentNum = self:getTmpPopTypePopNum(popType)
	self.tmpPopTypePopNum[popType] = currentNum + 1
end

function AutoPopupMgr:clearTmpPopTypePopNum()
	self.tmpPopTypePopNum = {}
end
-----------每一次强弹状态机启动后（对应某个强弹场景），次数限制 END-----------

-----------BEGIN 每天某一类强弹，次数限制-----------
function AutoPopupMgr:isLimitedByDailyPopType(popStage, popType)
	local limitNum = AutoPopupLimit.DailyPopTypeLimit[popType]
	if not limitNum then return false end

	local popedNum = privateNS.model:getDailyPopTypePopNum(popType)
	if limitNum > popedNum then
		return false
	end

	return true
end

function AutoPopupMgr:increaseDailyPopTypePopNum(popType)
	if not AutoPopupLimit.DailyPopTypeLimit[popType] then return false end
	local currentNum = privateNS.model:getDailyPopTypePopNum(popType)
	privateNS.model:setDailyPopTypePopNum(popType, currentNum + 1)
end

-----------每天某一类强弹，次数限制 END-----------

-----------BEGIN 场景4特殊的触发逻辑-----------
-- 场景4的触发，依赖于场景3中开始面板的弹出状况
function AutoPopupMgr:setStage3PopupState(state, levelId, levelScene)
	self.stage3PopupState = state
	self.stage3PopupLevelId = levelId
    self.levelScene = levelScene
end

function AutoPopupMgr:getStage3PopupState()
	return self.stage3PopupState or AutoPopupConst.Stage3PopupState.NONE
end

-- 场景4（开始面板弹出后主动关闭）
function AutoPopupMgr:handleStage4AfterStartGamePopup()
	if self.stage3PopupState ~= AutoPopupConst.Stage3PopupState.START_LEVEL_POP then return end
	AutoPopupDebugLog:log("AutoPopupMgr:handleStage4AfterStartGamePopup")

	self.stage3PopupState = AutoPopupConst.Stage3PopupState.NONE
	if not self:isEnabled() then return end
	if not self:isInMainScene() then return end
	AutoPopupDebugLog:beginPopupScene(AutoPopupConst.PopStage.STAGE_FOUR, self)

	local Stage4Handler = require "amf.middleware.autopop.module.popstage.Stage4Handler"
	local handler = Stage4Handler:create({
        stage3PopupState = AutoPopupConst.Stage3PopupState.START_LEVEL_POP,
		levelPlayInfo = self.__levelPlayInfo,
	}, self)
	handler:handleAutoPopup()
end

-- 场景4（开始面板没有弹出）
function AutoPopupMgr:handleStage4AfterStartGameNoPop(lastPopStage)
	if self.stage3PopupState ~= AutoPopupConst.Stage3PopupState.START_LEVEL_NO_POP then return end
	AutoPopupDebugLog:log("AutoPopupMgr:handleStage4AfterStartGameNoPop")

	self.stage3PopupState = AutoPopupConst.Stage3PopupState.NONE
	if lastPopStage ~= AutoPopupConst.PopStage.STAGE_THREE then return end
	if not self:isEnabled() then return end
	if not self:isInMainScene() then return end
	AutoPopupDebugLog:beginPopupScene(AutoPopupConst.PopStage.STAGE_FOUR, self)

	-- if not self:ignoreStage4Limit() and
	 -- MaintenanceManager.getInstance():isEnabledInGroup("popscene4" , "G1") then return end

	if self:ignoreForTopLevelPlayer() then
		AutoPopupDebugLog:recordAllSceneEnqueueFailed(self, LogReason.Enqueue.IGNORE_FOR_TOP_LEVEL_PLAYER)
		AutoPopupDebugLog:finishPopupScene("skipped", LogReason.Scene.IGNORE_FOR_TOP_LEVEL_PLAYER)
		return
	end

	local Stage4Handler = require "amf.middleware.autopop.module.popstage.Stage4Handler"
	local handler = Stage4Handler:create({
        stage3PopupState = AutoPopupConst.Stage3PopupState.START_LEVEL_NO_POP,
		levelPlayInfo = self.__levelPlayInfo,
    }, self)
	handler:handleAutoPopup()
end

-- 在新关开启的指定时间内（暂定4小时），玩家主线关满星前，闯头部新关不触发关卡内结算面板点叉的场景4强弹
function AutoPopupMgr:ignoreForTopLevelPlayer(levelId, levelScene)
	local judgeLevelId = levelId or self.stage3PopupLevelId
	local judgeLevelScene = levelScene or self.levelScene
	if not judgeLevelId then return end

	local userState = self._userStateManager:getUserLevelState()
	if userState == _G.UserStateConst.UserLevelState.TOP_STAR then
		return false
	end

	if not UBFLevelSceneFunc:isMainLevel(judgeLevelScene) then
		return false
	end

	if not _G.amfBean("LevelUnLockManager"):isTopNewMainOrHideLevel(judgeLevelId, judgeLevelScene) then
		return false
	end
	if not _G.amfBean("LevelUnLockManager"):isInNewLevelTime() then
		return false
	end

	return true
end

function AutoPopupMgr:ignoreStage4Limit()
	if not self.stage3PopupLevelId then return end

	local levelId = _G.getTopLevelId()
	local userState = self._userStateManager:getUserLevelState()
	if userState == _G.UserStateConst.UserLevelState.TOP_LEVEL or userState == _G.UserStateConst.UserLevelState.TOP_STAR then
		if levelId == self.stage3PopupLevelId then
			return true
		else
			return false
		end
	end

	self.stage3PopupLevelId = nil

	return false
end
------------场景4特殊的触发逻辑 END------------

-----------BEGIN 场景3和场景4衔接，次数限制-----------
function AutoPopupMgr:isLimitedByStageChange(popStage, popType)
	if not self._isNumLimitEnabled then return false end
	if popStage ~= AutoPopupConst.PopStage.STAGE_FOUR then return false end
	if not self.lastPopStage then return false end
	if not self.lastPopStagePopSum then return false end
	if self.lastPopStage ~= AutoPopupConst.PopStage.STAGE_THREE then return false end
	local numConfig = self._serverConfigMgr:getPopTypeSubPriority(popStage)
	if table.includes(numConfig, popType) then return false end
	local curStageLimit = AutoPopupLimit.StagePopupNum[popStage]
	local curStagePopSum = self:getTmpPopTypePopSum()
	return curStageLimit - curStagePopSum <= 0
end

function AutoPopupMgr:setLastPopStage(popStage)
	self.lastPopStage = popStage
end

function AutoPopupMgr:setLastPopStagePopSum(sum)
	self.lastPopStagePopSum = sum

	if sum > 0 and self.lastPopStage == AutoPopupConst.PopStage.STAGE_TWO then
		privateNS.model:setStage2LastPopupInfo(TimeKit:timeInSec(), sum)
	end
end
------------场景3和场景4衔接，次数限制 END------------

-----------BEGIN 场景2两次触发之间，次数限制-----------
function AutoPopupMgr:isLimitedBySameStage(popStage, popType)
	if not self._isNumLimitEnabled then return false end
	if popStage ~= AutoPopupConst.PopStage.STAGE_TWO then return end
	local numConfig = self._serverConfigMgr:getPopTypeSubPriority(popStage)
	if table.includes(numConfig, popType) then return false end
	local lastPopupTime = privateNS.model:getStage2LastPopupTime()
	local currentTime = TimeKit:timeInSec()
	local curStageLimit = AutoPopupLimit.StagePopupNum[popStage]
	local curStagePopSum = self:getTmpPopTypePopSum()
	if currentTime - lastPopupTime > AutoPopupLimit.Stage2PopupInterval then
		return curStageLimit - curStagePopSum <= 0
	else
		local lastStage2PopupSum = privateNS.model:getStage2LastPopupSum()
		return curStageLimit - curStagePopSum - lastStage2PopupSum <= 0
	end
end
------------场景2两次触发之间，次数限制 END------------


-----------------BEGIN 每天强弹检测点，次数限制-----------------
function AutoPopupMgr:checkPointLimitedCheck(popupCheckPoint)
	-- 检测点弹出次数限制
	local limitNum = self:getCheckPointLimitNum(popupCheckPoint)
	if limitNum ~= -1 then
		local currentNum = self:getCheckPointPopNum(popupCheckPoint)
		if currentNum >= limitNum then
			return true
		end
	end
	-- 其它限制
	return false
end

function AutoPopupMgr:getCheckPointLimitNum(popupCheckPoint)
	local configured = AutoPopupLimit.CheckPointNumLimit[popupCheckPoint]
	if configured ~= nil then return configured end
	return 1
end

function AutoPopupMgr:getCheckPointPopNum(popupCheckPoint)
	return privateNS.model:getDailyPopupNum(popupCheckPoint)
end

function AutoPopupMgr:increaseCheckPointPopNum(popupCheckPoint)
	local limitNum = self:getCheckPointLimitNum(popupCheckPoint)
	if limitNum ~= -1 then
		privateNS.model:sendDailyData(popupCheckPoint)
	end
end

function AutoPopupMgr:sendDailyData(uniqueKey)
    privateNS.model:sendDailyData(uniqueKey)
end

function AutoPopupMgr:sendPermanentData(uniqueKey)
	privateNS.model:sendPermanentData(uniqueKey)
end

function AutoPopupMgr:getPermanentShowNum(uniqueKey)
    return privateNS.model:getPermanentShowNum(uniqueKey)
end
------------------每天强弹点，次数限制 END------------------


-----------------BEGIN 产品要求某些强弹点，只能在场景4弹出-----------------
function AutoPopupMgr:isLimitedByStageOnly(popupCheckPoint, popStage)
	if popStage ~= AutoPopupConst.PopStage.STAGE_TWO and
		table.includes(AutoPopupLimit.OnlyStage2Limit, popupCheckPoint) then
			return true
	end

	if popStage ~= AutoPopupConst.PopStage.STAGE_FOUR and
		table.includes(AutoPopupLimit.OnlyStage4Limit, popupCheckPoint) then
			return true
	end

	return false
end
------------------产品要求某些强弹点，只能在场景4弹出 END------------------

-----------BEGIN 强弹检测点/类型 动态屏蔽-----------
function AutoPopupMgr:blockCheckPoint(checkPoint, reason, expireTime)
	self._checkPointBlockMgr:block(checkPoint, reason, expireTime)
end

function AutoPopupMgr:blockCheckPoints(checkPoints, reason, expireTime)
	self._checkPointBlockMgr:blockBatch(checkPoints, reason, expireTime)
end

function AutoPopupMgr:unblockCheckPoint(checkPoint)
	self._checkPointBlockMgr:unblock(checkPoint)
end

function AutoPopupMgr:unblockCheckPoints(checkPoints)
	self._checkPointBlockMgr:unblockBatch(checkPoints)
end

function AutoPopupMgr:blockPopType(popType, reason, expireTime)
	self._checkPointBlockMgr:blockPopType(popType, reason, expireTime)
end

function AutoPopupMgr:blockPopTypes(popTypes, reason, expireTime)
	self._checkPointBlockMgr:blockPopTypeBatch(popTypes, reason, expireTime)
end

function AutoPopupMgr:unblockPopType(popType)
	self._checkPointBlockMgr:unblockPopType(popType)
end

function AutoPopupMgr:unblockPopTypes(popTypes)
	self._checkPointBlockMgr:unblockPopTypeBatch(popTypes)
end

function AutoPopupMgr:unblockAllCheckPoints()
	self._checkPointBlockMgr:unblockAllCheckPoints()
end

function AutoPopupMgr:unblockAllPopTypes()
	self._checkPointBlockMgr:unblockAllPopTypes()
end

function AutoPopupMgr:blockCheckPointInStages(checkPoint, stages, reason, expireTime)
	self._checkPointBlockMgr:blockCheckPointInStages(checkPoint, stages, reason, expireTime)
end

function AutoPopupMgr:blockCheckPointInStagesBatch(checkPoints, stages, reason, expireTime)
	self._checkPointBlockMgr:blockCheckPointInStagesBatch(checkPoints, stages, reason, expireTime)
end

function AutoPopupMgr:unblockCheckPointInStages(checkPoint)
	self._checkPointBlockMgr:unblockCheckPointInStages(checkPoint)
end

function AutoPopupMgr:unblockCheckPointInStagesBatch(checkPoints)
	self._checkPointBlockMgr:unblockCheckPointInStagesBatch(checkPoints)
end

function AutoPopupMgr:unblockAllCheckPointStages()
	self._checkPointBlockMgr:unblockAllCheckPointStages()
end

function AutoPopupMgr:blockPopTypeInStages(popType, stages, reason, expireTime)
	self._checkPointBlockMgr:blockPopTypeInStages(popType, stages, reason, expireTime)
end

function AutoPopupMgr:blockPopTypeInStagesBatch(popTypes, stages, reason, expireTime)
	self._checkPointBlockMgr:blockPopTypeInStagesBatch(popTypes, stages, reason, expireTime)
end

function AutoPopupMgr:unblockPopTypeInStages(popType)
	self._checkPointBlockMgr:unblockPopTypeInStages(popType)
end

function AutoPopupMgr:unblockPopTypeInStagesBatch(popTypes)
	self._checkPointBlockMgr:unblockPopTypeInStagesBatch(popTypes)
end

function AutoPopupMgr:unblockAllPopTypeStages()
	self._checkPointBlockMgr:unblockAllPopTypeStages()
end

function AutoPopupMgr:unblockAll()
	self._checkPointBlockMgr:unblockAll()
end
-----------强弹检测点/类型 动态屏蔽 END-----------

local function addPopupEntry(autoPopupMgr, popupCheckPoint, popupCreator, actId, source)
	local popupQueue = autoPopupMgr:getPopupQueueByCheckPoint(popupCheckPoint)
	assert(popupQueue, "unknown popupCheckPoint: " .. tostring(popupCheckPoint))
	local popupEntry = {
		checkPoint = popupCheckPoint,
		creator = popupCreator,
		actId = actId,
		source = source or "config",
	}
	popupQueue[popupCheckPoint] = popupEntry
	autoPopupMgr:_recordDynamicPopupScheduleCandidate(popupEntry)
	AutoPopupDebugLog:recordPopupEnqueue(popupEntry, "success", nil, popupCheckPoint)
end

--- 入队一个强弹候选。
-- popupCheckPoint 同时是身份、业务规则和队列槽位，所以入队只需要一个 key。
-- @param popupCheckPoint see _G.PopupCheckPoint in AutoPopupCheckPoints.lua
--@param popupCreator
-- @param actId 归属活动；用于日志与“注册式优先”判定
-- @param source "config"（配置中心/事件驱动，默认）或 "registered"（声明式注册）
function AutoPopupMgr:addPopupConfig(popupCheckPoint, popupCreator, actId, source)
	source = source or "config"
	-- 配置式候选只要进入本次场景的评估，就要有调度位置：即使随后
	-- 被限流或强弹规则挡在队列外，日志也要按真实调度位置排序。
	self:_recordDynamicPopupScheduleCandidate({
		checkPoint = popupCheckPoint,
		actId = actId,
		source = source,
	})
	local function reject(reason)
		AutoPopupDebugLog:recordPopupEnqueue({
			checkPoint = popupCheckPoint,
			actId = actId,
			source = source,
		}, "fail", reason, popupCheckPoint)
		return false
	end

	if popupCheckPoint == nil then
		return reject(LogReason.Enqueue.REJECTED)
	end
	if not self:isEnabled() then
		return reject(LogReason.Enqueue.SYSTEM_DISABLED)
	end

	if self:checkPointLimitedCheck(popupCheckPoint) then
		AutoPopupDebugLog:log("AutoPopupMgr:addPopupConfig ==> cut off by num limit", popupCheckPoint)
		return reject(LogReason.Enqueue.CHECK_POINT_LIMIT_NUM)
	end

	-- 同一活动一旦拥有声明式强弹，配置中心的同名活动强弹只保留注册式入口。
	if source == "config" then
		local hasRegisteredPopup = actId and self:hasRegisteredPopupForActivity(actId)
		if not hasRegisteredPopup then
			hasRegisteredPopup = self._popupRegistration:hasRegisteredPopupForCheckpoint(popupCheckPoint)
		end
		if hasRegisteredPopup then
			AutoPopupDebugLog:log(
				"AutoPopupMgr:addPopupConfig skipped because registered popup exists",
				actId, popupCheckPoint
			)
			return reject(LogReason.Enqueue.REJECTED)
		end
	end

	AutoPopupDebugLog:log("AutoPopupMgr:addPopupConfig", popupCheckPoint, source)
	addPopupEntry(self, popupCheckPoint, popupCreator, actId, source)
	self:invalidateInterruptibleEntries(popupCheckPoint)
	self:_markPopupScheduleDirty()
	return true
end

function AutoPopupMgr:hasRegisteredPopupForActivity(actId)
	return self._popupRegistration:hasRegisteredPopupForActivity(actId)
end

-- 活动注册声明式强弹时，清除该活动已入队的配置式弹窗。
function AutoPopupMgr:removeConfiguredPopupsForActivity(actId)
	if actId == nil then return end
	local activityId = tostring(actId)
	local removedPopTypes = {}
	for _, popType in pairs(AutoPopupConst.PopType) do
		local popupQueue = self:getPopupQueueByPopType(popType)
		for popupCheckPoint, popupEntry in pairs(popupQueue) do
			if popupEntry.source == "config" and popupEntry.actId ~= nil and
				tostring(popupEntry.actId) == activityId then
				AutoPopupDebugLog:recordPopupRemoved(popupEntry, popupCheckPoint)
				popupQueue[popupCheckPoint] = nil
				removedPopTypes[popType] = true
			end
		end
	end
	for popType in pairs(removedPopTypes) do
		self:_markPopupScheduleDirty(popType)
	end
end
function AutoPopupMgr:popPopupEntry(popupCheckPoint, expectedPopupEntry)
	local popupQueue = self:getPopupQueueByCheckPoint(popupCheckPoint)
	if not popupQueue then return nil end
	local popupEntry = popupQueue[popupCheckPoint]
	if expectedPopupEntry and popupEntry ~= expectedPopupEntry then
		return nil
	end
	popupQueue[popupCheckPoint] = nil
	return popupEntry
end

function AutoPopupMgr:popPopupCreator(popupCheckPoint)
	local popupEntry = self:popPopupEntry(popupCheckPoint)
	return popupEntry and popupEntry.creator
end
function AutoPopupMgr:removeByManualPopup(evt)
	if not self:isEnabled() then return end
	local popupCheckPoint = evt:getData()
	if not popupCheckPoint then return end
	local limitNum = self:getCheckPointLimitNum(popupCheckPoint)
	if limitNum ~= -1 then
		local curPopNum = privateNS.model:getDailyPopupNum(popupCheckPoint)
		if curPopNum < limitNum then
			AutoPopupDebugLog:log("AutoPopupMgr:removeByManualPopup", popupCheckPoint)
			privateNS.model:sendDailyData(popupCheckPoint)
		end
	end
	self:removePopupConfig(popupCheckPoint)
end

-- popupCheckPoint 直接定位到唯一队列，不需要扫描所有 PopType。
function AutoPopupMgr:removePopupConfig(popupCheckPoint)
	if popupCheckPoint == nil then return end
	local popupQueue = self:getPopupQueueByCheckPoint(popupCheckPoint)
	local popupEntry = popupQueue and popupQueue[popupCheckPoint]
	if not popupEntry then return end
	AutoPopupDebugLog:log("AutoPopupMgr:removePopupConfig", popupCheckPoint)
	AutoPopupDebugLog:recordPopupRemoved(popupEntry, popupCheckPoint)
	popupQueue[popupCheckPoint] = nil
	self:_markPopupScheduleDirty()
end
function AutoPopupMgr:handlePopup(popStage)
	if not self.fsm:isOnStandBy() then return end
	AutoPopupDebugLog:beginPopupScene(popStage, self)
	-- 进关流程中，不触发强弹
	if self._playLevelFlowMgr:isInLevelFlow() then
		AutoPopupDebugLog:log("handlePopup:ignore auto popup because in level flow")
		AutoPopupDebugLog:recordAllSceneEnqueueFailed(self, LogReason.Enqueue.IN_LEVEL_FLOW)
		AutoPopupDebugLog:finishPopupScene("skipped", LogReason.Scene.IN_LEVEL_FLOW)
		return
	end

	self:setPopStage(popStage)

	if popStage ~= AutoPopupConst.PopStage.STAGE_TWO then
		return self:doPopup()
	end

	if self._ignoreAutoPopupForAWhile then
		AutoPopupDebugLog:log("handlePopup:ignore auto popup because some icon was clicked")
		AutoPopupDebugLog:recordAllSceneEnqueueFailed(self, LogReason.Enqueue.ICON_CLICK_COOLDOWN)
		AutoPopupDebugLog:finishPopupScene("skipped", LogReason.Scene.ICON_CLICK_COOLDOWN)
		return
	end

	if self.stage1WaitingPanelsClose then
		return 
	end

	if _G.hasHeGuideOnScreen then
		AutoPopupDebugLog:recordAllSceneEnqueueFailed(self, LogReason.Enqueue.GUIDE_ON_SCREEN)
		AutoPopupDebugLog:finishPopupScene("skipped", LogReason.Scene.GUIDE_ON_SCREEN)
		return
	end

	if not self._popoutManager:haveWindowOnScreenWithoutCommonTip() then
		return self:doPopup()
	end

	self.stage1WaitingPanelsClose = true

	AutoPopupDebugLog:log("AutoPopupMgr:handlePopup ==> waiting panels close")
	AutoPopEventCenter:registerGlobal(NormalEvent.NO_PANEL_ON_SCENE, self.onWaitPanelClose, self)
end

function AutoPopupMgr:doPopup()
	if not self.fsm:isOnStandBy() then return end
	if not self:isInMainScene() then
		AutoPopupDebugLog:recordAllSceneEnqueueFailed(self, LogReason.Enqueue.NOT_IN_MAIN_SCENE)
		AutoPopupDebugLog:finishPopupScene("skipped", LogReason.Scene.NOT_IN_MAIN_SCENE)
		return
	end

	-- 各场景 handler 已完成本轮入队；此处统一准备一次槽位顺序，再启动 FSM 消费。
	self:preparePopupSchedule(self:getPopStage())
	self.fsm:launch()
end

function AutoPopupMgr:onWaitPanelClose(evt)
	AutoPopupDebugLog:log("AutoPopupMgr:handlePopup ==> panels all closed, doPopup now")
	self:doPopup()
	self:resetStage1WaitingState()
end

function AutoPopupMgr:resetStage1WaitingState()
	self.stage1WaitingPanelsClose = false
	AutoPopEventCenter:unregisterGlobal(NormalEvent.NO_PANEL_ON_SCENE, self.onWaitPanelClose)
end

-- 注册强弹期间可以抢占的业务入口。业务负责判断是否启用、命中区域和中断行为。
function AutoPopupMgr:registerInterruptibleEntry(name, config)
	assert(type(name) == "string" and name ~= "", "interruptible entry name is required")
	assert(type(config) == "table", "interruptible entry config is required")
	assert(config.popupCheckPoint, "interruptible entry popupCheckPoint is required")
	assert(type(config.isEnabled) == "function", "interruptible entry isEnabled is required")
	assert(type(config.hitTest) == "function", "interruptible entry hitTest is required")
	assert(type(config.onInterrupt) == "function", "interruptible entry onInterrupt is required")

	self._interruptibleEntries[name] = {
		config = config,
		candidate = false,
		window = false,
		requested = false,
	}
end

function AutoPopupMgr:unregisterInterruptibleEntry(name)
	self._interruptibleEntries[name] = nil
end

function AutoPopupMgr:hasPopupConfig(popupCheckPoint)
	local popupQueue = self:getPopupQueueByCheckPoint(popupCheckPoint)
	return popupQueue ~= nil and popupQueue[popupCheckPoint] ~= nil
end

function AutoPopupMgr:getOtherPopupConfig(popupCheckPoint, allowedPopupCheckPoints)
	for popType in pairs(AutoPopupCheckPoints.InnerPriority) do
		local popupQueue = self:getPopupQueueByPopType(popType)
		for queuedCheckPoint in pairs(popupQueue) do
			-- 跳过判定仅针对场景3：排除限定在场景2/4的强弹，避免误判为特殊流程
			if queuedCheckPoint ~= popupCheckPoint
				and not (allowedPopupCheckPoints and allowedPopupCheckPoints[queuedCheckPoint])
				and not self:isLimitedBySpecifiedPopStages(queuedCheckPoint, AutoPopupConst.PopStage.STAGE_THREE)
				and not self:isLimitedByStageOnly(queuedCheckPoint, AutoPopupConst.PopStage.STAGE_THREE) then
				return queuedCheckPoint
			end
		end
	end
	return nil
end

function AutoPopupMgr:getAllowedPopupConfig(allowedPopupCheckPoints)
	for allowedCheckPoint in pairs(allowedPopupCheckPoints or {}) do
		if self:hasPopupConfig(allowedCheckPoint) then
			return allowedCheckPoint
		end
	end
	return nil
end

-- 场景 3 全部强弹登记完成后准备本轮资格。业务可声明允许共存的预期流程。
function AutoPopupMgr:prepareInterruptibleEntries(popupCheckPoint, context)
	local hasPopup = self:hasPopupConfig(popupCheckPoint)
	local hasMatchingEntry = false
	local hasEnabledEntry = false
	local blockedByOtherPopup
	local allowedRegisteredPopup
	for name, entry in pairs(self._interruptibleEntries) do
		local isMatching = entry.config.popupCheckPoint == popupCheckPoint
		local isEnabled = isMatching and entry.config.isEnabled(context)
		local allowedPopupCheckPoint = isMatching
			and self:getAllowedPopupConfig(entry.config.allowedPopupCheckPoints)
		local otherPopupCheckPoint = isMatching
			and self:getOtherPopupConfig(
				popupCheckPoint,
				entry.config.allowedPopupCheckPoints
			)
		local queueExclusive = hasPopup and not otherPopupCheckPoint
		entry.candidate = queueExclusive
			and isMatching
			and isEnabled
		entry.window = false
		entry.requested = false
		if isMatching then
			hasMatchingEntry = true
			blockedByOtherPopup = blockedByOtherPopup or otherPopupCheckPoint
			allowedRegisteredPopup = allowedRegisteredPopup or allowedPopupCheckPoint
		end
		if entry.candidate then hasEnabledEntry = true end
		AutoPopupDebugLog:log(
			"InterruptibleEntry:prepare",
			"name=" .. tostring(name),
			"candidate=" .. tostring(entry.candidate),
			"enabled=" .. tostring(isEnabled),
			"otherPopup=" .. tostring(otherPopupCheckPoint),
			"allowedPopup=" .. tostring(allowedPopupCheckPoint)
		)
	end

	local reason = allowedRegisteredPopup
		and "allowed_popup_registered:" .. tostring(allowedRegisteredPopup)
		or "allowed"
	if not hasPopup then
		reason = "popup_not_registered"
	elseif blockedByOtherPopup then
		reason = "other_popup_registered:" .. tostring(blockedByOtherPopup)
	elseif not hasMatchingEntry then
		reason = "entry_not_registered"
	elseif not hasEnabledEntry then
		reason = "business_disabled"
	end
	AutoPopupDebugLog:log(
		"InterruptibleEntry:queueDecision",
		"popupCheckPoint=" .. tostring(popupCheckPoint),
		"result=" .. tostring(hasEnabledEntry),
		"reason=" .. reason
	)
end

-- 资格准备后又登记其他强弹，说明本轮不再是纯过关动画流程。
function AutoPopupMgr:invalidateInterruptibleEntries(registeredCheckPoint)
	for name, entry in pairs(self._interruptibleEntries) do
		local isAllowedPopup = entry.config.allowedPopupCheckPoints
			and entry.config.allowedPopupCheckPoints[registeredCheckPoint]
		if entry.candidate
			and entry.config.popupCheckPoint ~= registeredCheckPoint
			and not isAllowedPopup
			and not self:isLimitedBySpecifiedPopStages(registeredCheckPoint, AutoPopupConst.PopStage.STAGE_THREE)
			and not self:isLimitedByStageOnly(registeredCheckPoint, AutoPopupConst.PopStage.STAGE_THREE) then
			entry.candidate = false
			entry.window = false
			entry.requested = false
			AutoPopupDebugLog:log(
				"InterruptibleEntry:invalidate",
				"name=" .. tostring(name),
				"reason=other_popup_registered:" .. tostring(registeredCheckPoint)
			)
		elseif entry.candidate and isAllowedPopup then
			AutoPopupDebugLog:log(
				"InterruptibleEntry:allow",
				"name=" .. tostring(name),
				"reason=allowed_popup_registered:" .. tostring(registeredCheckPoint)
			)
		end
	end
end

function AutoPopupMgr:beginInterruptibleWindow()
	for name, entry in pairs(self._interruptibleEntries) do
		entry.window = entry.candidate
		if entry.window then
			AutoPopupDebugLog:log("InterruptibleEntry:windowOpen", "name=" .. tostring(name))
		end
	end
end

function AutoPopupMgr:endInterruptibleWindow()
	for _, entry in pairs(self._interruptibleEntries) do
		entry.window = false
	end
end

function AutoPopupMgr:finishInterruptibleEntries()
	for _, entry in pairs(self._interruptibleEntries) do
		entry.candidate = false
		entry.window = false
		entry.requested = false
	end
end

-- 特殊流程（解锁新区域/满级/满星/皮肤等）触发时调用：本轮禁止跳过
function AutoPopupMgr:blockPassLevelSkip()
	self:finishInterruptibleEntries()
end

function AutoPopupMgr:isInterruptibleWindowRequested()
	for _, entry in pairs(self._interruptibleEntries) do
		if entry.requested then return true end
	end
	return false
end

function AutoPopupMgr:isInterruptibleTouchPassThrough(worldPos)
	for _, entry in pairs(self._interruptibleEntries) do
		if entry.candidate and entry.window and not entry.requested
			and entry.config.hitTest(worldPos) then
			return true
		end
	end
	return false
end

function AutoPopupMgr:requestInterruptibleEntry(name)
	local entry = self._interruptibleEntries[name]
	if not entry then
		AutoPopupDebugLog:log("InterruptibleEntry:requestDenied", "name=" .. tostring(name), "reason=not_registered")
		return false
	end
	if not entry.candidate then
		AutoPopupDebugLog:log("InterruptibleEntry:requestDenied", "name=" .. tostring(name), "reason=not_candidate")
		return false
	end
	if not entry.window then
		AutoPopupDebugLog:log("InterruptibleEntry:requestDenied", "name=" .. tostring(name), "reason=window_closed")
		return false
	end
	if entry.requested then
		AutoPopupDebugLog:log("InterruptibleEntry:requestAccepted", "name=" .. tostring(name), "reason=already_requested")
		return true
	end

	entry.requested = true
	AutoPopupDebugLog:log("InterruptibleEntry:requestAccepted", "name=" .. tostring(name))
	entry.config.onInterrupt()
	return true
end

-- 业务入口点击时中断当前强弹，避免旧 FSM 在开始面板流程中继续推进。
function AutoPopupMgr:abortInterruptibleEntry(name)
	if not self:isEnabled() or not self:isInMainScene() then return false end
	local entry = self._interruptibleEntries[name]
	if entry and entry.candidate and entry.window and not entry.requested then
		-- 手动打开开始面板也应走场景4的“开始面板主动关闭”分支。
		self:setStage3PopupState(
			AutoPopupConst.Stage3PopupState.START_LEVEL_POP,
			self.stage3PopupLevelId,
			self.levelScene
		)
		-- 先清理 FSM 和待执行强弹，再派发跳过事件，避免旧队列重入。
		self:resetPopupForStartGamePanel()
	end
	if not self:requestInterruptibleEntry(name) then return false end

	-- stopForIconClick 只在待机态生效，因此放在 FSM 清理之后。
	self:stopForIconClick()
	return true
end

-- 主动中断强弹0：通用
function AutoPopupMgr:resetPopup(ignoreLog, reason)
	if not self:isEnabled() then return end
	reason = reason or LogReason.Scene.RESET_POPUP

	-- 重置状态机时，需清除部分已添加但未弹出的强弹
	for _, popupCheckPoint in ipairs(AutoPopupLimit.ClearWhenFsmReset) do
		self:removePopupConfig(popupCheckPoint)
	end

	self:resetStage1WaitingState()

	self.stage3PopupState = AutoPopupConst.Stage3PopupState.NONE
	self.stage3PopupLevelId = nil

	if self.fsm:isOnStandBy() then
		AutoPopupDebugLog:finishPopupScene("interrupted", reason)
		return
	end

	if not ignoreLog then
		AutoPopupDebugLog:logWithTraceback("resetPopup !!!")
	end
	AutoPopupDebugLog:finishPopupScene("interrupted", reason)
	self.fsm:reset()
end

-- Debug only: close-all-popups should also drop queued auto popups, otherwise
-- the fsm may continue popping the next queued item after the current panel is removed.
function AutoPopupMgr:debugClearPendingPopups()
	if not self:isEnabled() then return end
	self:initPopupQueues()
	self:clearTmpPopTypePopNum()
	self:clearCheckPointLimitedStages()
	self:resetStage1WaitingState()

	self.stage3PopupState = AutoPopupConst.Stage3PopupState.NONE
	self.stage3PopupLevelId = nil
	self.levelScene = nil
	self.lastPopStage = nil
	self.lastPopStagePopSum = nil
	self._ignoreAutoPopupForAWhile = false
	self:setPopStage(nil)

	if self.fsm and not self.fsm:isOnStandBy() then
		AutoPopupDebugLog:logWithTraceback("debugClearPendingPopups !!!")
		AutoPopupDebugLog:finishPopupScene("interrupted", LogReason.Scene.DEBUG_CLEAR_PENDING)
		self.fsm:reset()
	else
		AutoPopupDebugLog:finishPopupScene("interrupted", LogReason.Scene.DEBUG_CLEAR_PENDING)
	end
end

-- 主动中断强弹1：弹出开始面板时，专用
function AutoPopupMgr:resetPopupForStartGamePanel()
	if not self:isEnabled() then return end
	-- 重置状态机时，需清除部分已添加但未弹出的强弹
	for _, popupCheckPoint in ipairs(AutoPopupLimit.ClearAfterStartGamePanelShow) do
		self:removePopupConfig(popupCheckPoint)
	end

	self:resetStage1WaitingState()

	if self.fsm:isOnStandBy() then
		AutoPopupDebugLog:finishPopupScene("interrupted", LogReason.Scene.START_GAME_PANEL)
		return
	end
	AutoPopupDebugLog:finishPopupScene("interrupted", LogReason.Scene.START_GAME_PANEL)
	self.fsm:reset()
end

-- 强弹期间仅放行已注册且处于窗口期的业务入口。
function AutoPopupMgr:disableTouch()
	if not self:isEnabled() then return end
	if not self:isInMainScene() then return end

	local mainScene = Director:sharedDirector():getRunningScene()
	if not mainScene or not mainScene.autoPopupBlockLayer then return end
	if not self._swallowLayer then
		local layer = Layer:create()
		layer:setTouchEnabled(true, 0, true, function (worldPos)
			return not self:isInterruptibleTouchPassThrough(worldPos)
		end, true, true)
		mainScene.autoPopupBlockLayer:addChild(layer)
		self._swallowLayer = layer
		self:addEscapeBtn(layer)
	end
	self._swallowLayer:setVisible(true)
	self._escapeBtn:setVisible(true)
end

function AutoPopupMgr:enableTouch()
	if not self:isEnabled() then return end
	if not self._swallowLayer then return end
	self._swallowLayer:setVisible(false)
	self._escapeBtn:setVisible(false)
end

-- 防卡死按钮 + error log上传
function AutoPopupMgr:addEscapeBtn(swallowLayer)
	local visibleSize = CCDirector:sharedDirector():getVisibleSize()
	local layerWidth = visibleSize.width
	local layerHeight = 200
	local layer = LayerColor:create()
    layer:changeWidthAndHeight(layerWidth , layerHeight)
    layer:setPositionY(visibleSize.height / 2)

    swallowLayer:getParent():addChild(layer)

    if EnvUtil:isDevelopMode() and not _G.disableAutoPopupHint then
	    local label0 = TextField:create("当前强弹：", nil, 35)
	    label0:setAnchorPoint(ccp(0.5, 0.5))
	    label0:setPositionXY(layerWidth / 2, layerHeight / 2 + 50)
	    layer:addChild(label0)

	    local label = TextField:create("", nil, 35)
	    label:setAnchorPoint(ccp(0.5, 0.5))
	    label:setPositionXY(layerWidth / 2, layerHeight / 2)
	    layer:addChild(label)

	    layer._updateLabel = function ()
	    	if not EnvUtil:isDevelopMode() then return end
			if _G.disableAutoPopupHint then return end
			local _popupCheckPoint = AutoPopupDebugLog:getLastPopupCheckPoint()
			local t1 = AutoPopupDC.dcExtraParma1[_popupCheckPoint]
			local str = _popupCheckPoint .. (t1 and ("\n"..t1) or "")
	    	label:setString(str)
	    end
    	layer:setOpacity(100)
    else
    	layer:setOpacity(0)
    end
    layer:setColor(ccc3(255, 0, 0))
    layer:ignoreAnchorPointForPosition(false)
    layer:setAnchorPoint(ccp(0, 0))

    self._escapeBtn = layer
	layer:setTouchEnabled(true, 0, true, function (worldPos)
		return not self:isInterruptibleTouchPassThrough(worldPos)
	end, true, true)

    local beginTime = nil
    layer:ad(DisplayEvents.kTouchBegin, function ()
    	beginTime = TimeKit:timeInSec()
    end)
   	layer:ad(DisplayEvents.kTouchEnd, function ()
   		if not beginTime then return end
   		local now = TimeKit:timeInSec() - beginTime
   		if now >= 5 then
   			local log = AutoPopupDebugLog:getLastPopupCheckPoint()
   			he_log_error('last_popup_check_point_' .. log)
    		self:resetPopup()
    	end
    end)
end

function AutoPopupMgr:logCurrentPopup()
	if not EnvUtil:isDevelopMode() then return end
	if _G.disableAutoPopupHint then return end
	if not self:isInMainScene() then return end
	if not self._escapeBtn then return end
	self._escapeBtn:_updateLabel()
end

function AutoPopupMgr:showCommonAlert(alertStr, closeCallback)
	local FourthPanelAVM = require "amf.middleware.ui.kit.panel.fourth.FourthPanelAVM"
	local vm
	vm = FourthPanelAVM.Builder.new()
		-- :setTitle("标题")
		:setText(localize(alertStr))
		:setButtonsConfig({
			{
				str = "确定",
				widthMode = UIButtonConfig.Widths.kShort,
				colorMode = UIButtonConfig.ColorMode.green,
				touchFunc = function ()
					vm:close()
					if closeCallback then closeCallback() end
				end
			},
		})
		:build()
	vm:popout()
end

function AutoPopupMgr:isInMainScene()
	return self._isInMainScene
end

function AutoPopupMgr:stopForIconClick()
	if not self.fsm:isOnStandBy() then return end
	if self._ignoreAutoPopupForAWhile then return end

	self._ignoreAutoPopupForAWhile = true
	setTimeOut(function ()
		self._ignoreAutoPopupForAWhile = false
	end, 3)
end

-- -- 当前阶段强弹结束
function AutoPopupMgr:handleAfterPopupEnd(lastPopStage)
	if not self.fsm:isOnStandBy() then return end
	if lastPopStage == AutoPopupConst.PopStage.STAGE_TWO
		or lastPopStage == AutoPopupConst.PopStage.STAGE_FOUR then
		-- 2023版发现新活动需要在强弹结束后触发
		_G.amfBean("PopupNewActMgr"):tryPopupFoundNewAct(lastPopStage, function()
			_G.amfEC:notifyFeature(FeatureEvent.AFTER_AUTOPOP_END, {lastPopStage=lastPopStage})
		end)
	else
		_G.amfEC:notifyFeature(FeatureEvent.AFTER_AUTOPOP_END, {lastPopStage=lastPopStage})
	end
end

------------------------------触发强弹状态机启动------------------------------
-- @param checkLastScene为true时，需要判断上一个场景，如果是GamePlayScene则不触发场景2强弹
function AutoPopupMgr:triggerStage2AutoPopup(checkLastScene)
	if not self:isInMainScene() then return end

	local _lastSceneName = self._lastSceneName
	self._lastSceneName = nil
	if checkLastScene and _lastSceneName and _lastSceneName == "UBFGamePlayScene" then
		AutoPopupDebugLog:log("Warning:Last scene is UBFGamePlayScene, won't trigger stage2 auto popup.")
		return
	end

	self:handlePopup(AutoPopupConst.PopStage.STAGE_TWO)
end

function AutoPopupMgr:triggerStage3AutoPopup()
	self:handlePopup(AutoPopupConst.PopStage.STAGE_THREE)
end

function AutoPopupMgr:triggerStage4AutoPopup()
	self:handlePopup(AutoPopupConst.PopStage.STAGE_FOUR)
end

function AutoPopupMgr:setLastSceneName(name)
	self._lastSceneName = name
end

function AutoPopupMgr:isRunnning()
	if not self:isEnabled()	then return false end
	return not self:isOnStandby()
end

function AutoPopupMgr:isOnStandby()
	if not self:isEnabled()	then return false end
	return self.fsm:isOnStandBy()
end

------------------------------不弹场景3的下一关面板时的一些特殊处理------------------------------
function AutoPopupMgr:openStartGamePanelInStage3(levelId)
end

------------------------------ActInterface------------------------------
-- 场景2（包含第一次进游戏的情况）
-- 场景3
function AutoPopupMgr:onActEnterMainScene(evt)
	-- -- 用一次就删掉
	-- if _G.__isInLevelChangeScene then
	-- 	_G.__isInLevelChangeScene = false
	-- 	return
	-- end
	self._isInMainScene = true
	if self._ignoreAutoPopupForAWhile then
		AutoPopupDebugLog:log("onActEnterMainScene:ignore auto popup because some icon was clicked")
		return
	end
	local data = evt:getData()
	local Stage2EnterSceneHandler = require "amf.middleware.autopop.module.popstage.Stage2EnterSceneHandler"
	local handler = Stage2EnterSceneHandler:create(data, self)
	handler:handleAutoPopup()

	if data.levelPlayInfo then
		local levelScene = data.levelPlayInfo.levelScene
		if levelScene and (UBFLevelSceneFunc:isMainOrHiddenLevel(levelScene) or UBFLevelSceneFunc:isFullLevelLib(levelScene)) then
			self.__levelPlayInfo = data.levelPlayInfo
			local Stage3Handler = require "amf.middleware.autopop.module.popstage.Stage3Handler"
			local handler = Stage3Handler:create(data.levelPlayInfo, self)
			handler:handleAutoPopup()
		end
	else
		self:triggerStage2AutoPopup(true)
	end
end

function AutoPopupMgr:onActExitMainScene(evt)
	self._isInMainScene = false
	self:finishInterruptibleEntries()
	self:resetPopup()
end

-- 场景2
function AutoPopupMgr:onSystemEnterForeground(evt)
	if self._ignoreAutoPopupForAWhile then
		AutoPopupDebugLog:log("onActEnterForeground:ignore auto popup because some icon was clicked")
		return
	end

    local Condition = require "amf.script.sugar.Condition"
    self.stage2Condition = Condition.new(function()
        local data = evt:getData()
        local Stage2ForegroundHandler = require "amf.middleware.autopop.module.popstage.Stage2ForegroundHandler"
        local handler = Stage2ForegroundHandler:create(data, self)
        handler:handleAutoPopup()
    end, 1)

    TimerUtil.addAlarm(function()
        self:_triggerStage2Condition()
    end, 0.02)
end

-- iOS only
function AutoPopupMgr:onActClickOpenUrl(evt)
    self:_triggerStage2Condition()
end

function AutoPopupMgr:_triggerStage2Condition()
    if self.stage2Condition then
        local cond = self.stage2Condition
        self.stage2Condition = nil
        cond:notify()
    end
end

return AutoPopupMgr
