local AutoPopupDebugLog = require "amf.middleware.autopop.AutoPopupDebugLog"

local PopupDoPopState = class("PopupDoPopState")

function PopupDoPopState:create(fsm)
	local state = PopupDoPopState.new()
	state:init(fsm)
	return state
end

function PopupDoPopState:init(fsm)
	self.fsm = fsm
	self._autoPopupMgr = fsm:getAutoPopupMgr()
end

function PopupDoPopState:onEnter(context)
	assert(context and context.checkPoint and context.popupEntry,
		"invalid popup dispatch context")
	local popupCheckPoint = context.checkPoint
	local popupEntry = self._autoPopupMgr:popPopupEntry(popupCheckPoint, context.popupEntry)
	if popupEntry then
		local popupCreator = popupEntry.creator
		AutoPopupDebugLog:log("PopupDoPopState:doPop ==>", popupCheckPoint)
		AutoPopupDebugLog:setLastPopupCheckPoint(popupCheckPoint)
		self._autoPopupMgr:logCurrentPopup()
		self._autoPopupMgr:clearCheckPointLimitedStages(popupCheckPoint)
		self._autoPopupMgr:increaseCheckPointPopNum(popupCheckPoint)

		-- popupCheckPoint 同时是身份、规则和槽位；限流归属其 PopType。
		local popType = self._autoPopupMgr:getPopType(popupCheckPoint)
		self._autoPopupMgr:increaseTmpPopTypePopNum(popType)
		self._autoPopupMgr:increaseDailyPopTypePopNum(popType)

		self.fsm:changeState(self.fsm.checkCloseState, {
			popupEntry = popupEntry,
			checkPoint = popupCheckPoint,
		})

		local dcPopStage = AutoPopupDC:getDcPopStage()		--放到popupCreator调用之前，因为popupCreator可能会停掉强弹，导致打点时的场景为空
		AutoPopupDC:sendPop(popupCheckPoint, dcPopStage)
		-- 通知业务侧“强弹即将展示”；具体业务打点由监听方决定，不能阻断强弹流程。
		AutoPopEventCenter:dispatch(AutoPopEvent.POPUP_WILL_SHOW, {
			popupEntry = popupEntry,
			checkPoint = popupCheckPoint,
			popStage = dcPopStage,
		})

		-- 放在最后，不然可能会有入栈出栈顺序带来的隐患
		AutoPopupDebugLog:recordPopupStarted(popupEntry, popupCheckPoint)
		popupCreator()
	else
		self.fsm:changeState(self.fsm.checkPopState)
	end
end

function PopupDoPopState:onExit()
	AutoPopupDebugLog:log("PopupDoPopState:onExit()")
end

function PopupDoPopState:reset()
end

return PopupDoPopState
