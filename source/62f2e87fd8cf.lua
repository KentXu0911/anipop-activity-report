
local PolicyHandler = class("PolicyHandler")

function PolicyHandler:create(autoPopupMgr)
	local handler = PolicyHandler.new()
	handler:init(autoPopupMgr)
	return handler
end

function PolicyHandler:init(autoPopupMgr)
	self._autoPopupMgr = autoPopupMgr
	AutoPopEventCenter:register(AutoPopEvent.POLICY, self.onHandlePopup, self)
end

function PolicyHandler:onHandlePopup(evt)
	local data = evt:getData()
	local popupCheckPoint = data.popupCheckPoint
	local params = data.params

	lua_switch(popupCheckPoint){
		[PopupCheckPoint.FORBID_PLAYING] = function ()
			self:handleForbidPlaying(params)
		end,
		[PopupCheckPoint.ANTI_ADDICTION] = function ()
			self:handleAntiAddiction(params)
		end,
		[PopupCheckPoint.RECALL_SHIMING] = function ()
			self:handleRecallShiMing(params)
		end,
		[PopupCheckPoint.HW_SHIMING_SYNC_ALERT] = function ()
			self:handleHWShiMingSyncAlert(params)
		end,
		default = function ()
			assert(false, "PolicyHandler invalid popupCheckPoint : " .. tostring(popupCheckPoint))
		end
	}
end

function PolicyHandler:handleForbidPlaying(popType)
	local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.FORBID_PLAYING)
	end

	local function creator()
		local ForbidLoginLogic = require "amf.feature.login.stage.login.ForbidLoginLogic"
		ForbidLoginLogic:doAutoPopup(popType, onHandleOver)
	end

	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.FORBID_PLAYING, creator)
end

function PolicyHandler:handleAntiAddiction(alertType)
	if not alertType then return end
	if alertType ~= ShiMingConst.AntiAddictionType.JUVENILE_CUMULATIVE and
	   alertType ~= ShiMingConst.AntiAddictionType.JUVENILE_PERIOD then
		-- assert(false, "PolicyHandler invalid alertType : " .. tostring(alertType))
		return
	end

	local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.ANTI_ADDICTION)
	end

	local function creator()
		if alertType == ShiMingConst.AntiAddictionType.JUVENILE_CUMULATIVE then
			_G.amfBean("ShiMingManager"):popPanelJuvenileTimeCumulativeLimit()
		elseif alertType == ShiMingConst.AntiAddictionType.JUVENILE_PERIOD then
			_G.amfBean("ShiMingManager"):popPanelJuvenileTimePeriodLimit()
		end
	end

	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.ANTI_ADDICTION, creator)
end

function PolicyHandler:handleRecallShiMing()
	local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.RECALL_SHIMING)
	end

	local function creator()
		_G.amfBean("ShiMingManager"):handleAutoPopupMainPanel(onHandleOver)
	end

	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.RECALL_SHIMING, creator)
end

function PolicyHandler:handleHWShiMingSyncAlert(params)
	local regType = params.regType
	local alertPanelType = params.alertPanelType
	local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.HW_SHIMING_SYNC_ALERT)
	end

	local function creator()
		if alertPanelType == ShiMingConst.PanelId.HW_JUVENILE_ALERT then
			_G.amfBean("ShiMingManager"):popPanelHWJuvenileAlert(regType, onHandleOver)
		elseif alertPanelType == ShiMingConst.PanelId.HW_UNKNOWN_ALERT then
			_G.amfBean("ShiMingManager"):popPanelHWUnknownAlert(regType, onHandleOver)
		else
			assert(false, "PolicyHandler invalid alertPanelType : " .. tostring(alertPanelType))
		end
	end

	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.HW_SHIMING_SYNC_ALERT, creator)
end

return PolicyHandler