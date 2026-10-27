local AutoPopupDebugLog = require "amf.middleware.autopop.AutoPopupDebugLog"

local PopupStandByState = class("PopupStandByState")

function PopupStandByState:create(fsm)
	local state = PopupStandByState.new()
	state:init(fsm)
	return state
end

function PopupStandByState:init(fsm)
	self.fsm = fsm
	self._autoPopupMgr = fsm:getAutoPopupMgr()
end

function PopupStandByState:onEnter(lastPopStage)
	AutoPopupDebugLog:log("PopupStandByState:onEnter()")
	self._autoPopupMgr:enableTouch()
	if lastPopStage then
		AutoPopupDebugLog:finishPopupScene("completed")
	end
	self._autoPopupMgr:setPopStage(nil)

	if not lastPopStage then return end
	self._autoPopupMgr:setLastPopStage(lastPopStage)
	local sum = self._autoPopupMgr:getTmpPopTypePopSum() 
	self._autoPopupMgr:setLastPopStagePopSum(sum)

	self._autoPopupMgr:clearTmpPopTypePopNum()

	self._autoPopupMgr:handleStage4AfterStartGameNoPop(lastPopStage)
    
    self._autoPopupMgr:handleAfterPopupEnd(lastPopStage)
end

function PopupStandByState:onExit()
	AutoPopupDebugLog:log("PopupStandByState:onExit()")
	self._autoPopupMgr:disableTouch()
end

function PopupStandByState:reset()
end

return PopupStandByState
