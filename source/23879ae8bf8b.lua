
--@ref 强弹框架: 场景3检测及触发

local Stage3Handler = class("Stage3Handler")
local MainSceneEventCenter = require "amf.feature.mainscene.core.event.MainSceneEventCenter"
local AutoPopupDebugLog = require "amf.middleware.autopop.AutoPopupDebugLog"

function Stage3Handler:create(data, autoPopupMgr)
	local handler = Stage3Handler.new()
	handler:init(data, autoPopupMgr)
	return handler
end

function Stage3Handler:init(data, autoPopupMgr)
	self._autoPopupMgr = autoPopupMgr

	self.levelPlayInfo = data
	self.levelId = data.levelId
	self.levelType = data.levelType
	self.levelScene = data.levelScene
	self.isLevelPassed = data.isWin
	self.isFirstPassed = data.isFirstPassLevel
	self.isMainOrHideLevel = UBFLevelSceneFunc:isMainOrHiddenLevel(self.levelScene)
end

function Stage3Handler:isFullStarLevelLibPassed()
	return UBFLevelSceneFunc:isFullLevelLib(self.levelScene) and self.isLevelPassed
end

function Stage3Handler:isMainOrHideLevelPassed()
	return self.isMainOrHideLevel and self.isLevelPassed
end

function Stage3Handler:isMainOrHideLevelFirstPassed()
	return self.isMainOrHideLevel and self.isFirstPassed
end

function Stage3Handler:handleAutoPopup()
	AutoPopupDebugLog:beginPopupScene(AutoPopupConst.PopStage.STAGE_THREE, self._autoPopupMgr)
	self.nextLevelModeData = table.clone(InLevelBridge:getNextLevelMode())
	-- CONDITION
	self:checkPlayLevelBack()
	self:checkExitLevelJump()
	self:checkAddFiveStepPopup()
	self:checkActivityPopup()
	self._autoPopupMgr:prepareInterruptibleEntries(
		PopupCheckPoint.PLAY_LEVEL_BACK, self.levelPlayInfo
	)
	self._autoPopupMgr:triggerStage3AutoPopup()
end

function Stage3Handler:checkPlayLevelBack()
	if self:isMainOrHideLevelPassed() or self:isFullStarLevelLibPassed() then
		AutoPopEventCenter:dispatch(AutoPopEvent.CONDITION, {popupCheckPoint = PopupCheckPoint.PLAY_LEVEL_BACK, params = self.levelPlayInfo})
	else
		MainSceneEventCenter:dispatch(MainSceneEvent.Play.LEVEL_BACK_FINISHED, self.levelPlayInfo)
	end
end

function Stage3Handler:checkExitLevelJump()
	local nextLevelModeData = InLevelBridge:getNextLevelMode()
	InLevelBridge:setNextLevelMode()

    if nextLevelModeData.autoPlayNextLevel then
		_G.amfBean("AutoPopupMgr"):setStage3PopupState(AutoPopupConst.Stage3PopupState.START_LEVEL_POP, self.levelId)
		AutoPopEventCenter:dispatch(AutoPopEvent.CONDITION, {popupCheckPoint = PopupCheckPoint.EXIT_LEVEL_JUMP, params = nextLevelModeData})
	else
		_G.amfBean("AutoPopupMgr"):setStage3PopupState(AutoPopupConst.Stage3PopupState.START_LEVEL_NO_POP, self.levelId)
	end
end

--抛出事件给各个活动去监听，在各自manager去添加强弹
function Stage3Handler:checkActivityPopup()
	_G.amfEC:notifyFeature(FeatureEvent.ENTER_STAGE3, {
		isLevelPassed = self.isLevelPassed,
		levelId = self.levelId,
		nextLevelModeData = self.nextLevelModeData,
		levelScene = self.levelScene
	})
	self.nextLevelModeData = nil
end

--长尾步数 地鼠强弹
function Stage3Handler:checkAddFiveStepPopup()
	local params = {
		levelID = self.levelId,
		levelScene = self.levelScene,
		isWin = self.isLevelPassed,
	}
	_G.amfBean("AddFiveUpgradeManager"):checkAddFiveStepPopup(params)
end

return Stage3Handler
