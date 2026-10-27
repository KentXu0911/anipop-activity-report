
local SystemHandler = class("SystemHandler")

function SystemHandler:create(autoPopupMgr)
	local handler = SystemHandler.new()
	handler:init(autoPopupMgr)
	return handler
end

function SystemHandler:init(autoPopupMgr)
	self._autoPopupMgr = autoPopupMgr
	AutoPopEventCenter:register(AutoPopEvent.SYSTEM, self.onHandlePopup, self)
end

function SystemHandler:onHandlePopup(evt)
	local data = evt:getData()
	local popupCheckPoint = data.popupCheckPoint
	local params = data.params

	lua_switch(popupCheckPoint){
		[PopupCheckPoint.SL_ALERT] = function ()
			self:handleSLAlert(params)
		end,
		 [PopupCheckPoint.PKG_UPDATE] = function ()
		 	self:handlePkgUpdate(params)
		 end,
		[PopupCheckPoint.ANNOUNCEMENT] = function ()
			self:handleAnnouncement(params)
		end,
		[PopupCheckPoint.USER_PROTOCAL] = function()
			self:handleUserProtocal(params)
		end,
		default = function ()
			assert(false, "SystemHandler invalid popupCheckPoint : " .. tostring(popupCheckPoint))
		end
	}
end

function SystemHandler:handleSLAlert()
	local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.SL_ALERT)
	end

	local function creator()
		_G.amfBean("HttpErrorManager"):handleError111():next(onHandleOver)
	end

	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.SL_ALERT, creator)
end

function SystemHandler:handleAnnouncement(params)
	--
--
--
--


	local announcementMgr = _G.amfBean("AnnouncementMgr")
	if announcementMgr:isInChecking() then return end

	local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.ANNOUNCEMENT)
	end

	local function creator()
		announcementMgr:showOnMainScene(onHandleOver)
	end

	announcementMgr:setCheckFlag()
	announcementMgr:loadOnMainScene(function(hasImportantAnn)
		self._autoPopupMgr:addPopupConfig(PopupCheckPoint.ANNOUNCEMENT, creator)
		--有重要通知，强制触发一次强弹
		if hasImportantAnn then
			self._autoPopupMgr:triggerStage2AutoPopup()
			announcementMgr:setTriggered()
		end
	end)
end

function SystemHandler:handlePkgUpdate()
	if _G.IOS_Update_Alert_Popped then return end
	
	local updateMgr = _G.amfBean("VersionUpdateManager")
	if not updateMgr then return end
	if updateMgr:needFlushPackage() then return end
	
	local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.PKG_UPDATE)
	end
	
	if _G.amfBean("YYBWashingPackageManager") and _G.amfBean("YYBWashingPackageManager"):canOpenYYBUpdatePanel() then return end

	local function creator()
		updateMgr:openUpdatePanel("auto_pop", onHandleOver)
	end
	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.PKG_UPDATE, creator)
end

function SystemHandler:handleUserProtocal(params)
	--
--
--
--

end

return SystemHandler
