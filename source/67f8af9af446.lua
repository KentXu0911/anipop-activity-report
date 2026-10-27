-- @Author: zhijian.li
-- @Date:   2021-05-18 18:17:14
-- @Last Modified by:   zhijian.li
-- @Last Modified time: 2021-12-30 18:16:34

local TempActPanelHandler = class("TempActPanelHandler")
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local AutoPopupDebugLog = require "amf.middleware.autopop.AutoPopupDebugLog"

function TempActPanelHandler:create(autoPopupMgr)
	local handler = TempActPanelHandler.new()
	handler:init(autoPopupMgr)
	return handler
end

function TempActPanelHandler:init(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
	AutoPopEventCenter:register(AutoPopEvent.TMP_ACT_PANEL, self.onHandlePopup, self)
end

function TempActPanelHandler:onHandlePopup(evt)
    local data = evt:getData()
	local popupCheckPoint = data.popupCheckPoint
	local params = data.params
    
	lua_switch(popupCheckPoint){
		[PopupCheckPoint.ACT_MAIN_PANEL_STAGE_2] = function ()
			self:handleActMainPanel(params, popupCheckPoint)
		end,
        [PopupCheckPoint.ACT_MAIN_PANEL_STAGE_4] = function ()
            self:handleActMainPanel(params, popupCheckPoint)
        end,
		default = function ()
			assert(false, "TempActPanelHandler invalid popupCheckPoint : " .. tostring(popupCheckPoint))
		end
	}
end

function TempActPanelHandler:handleActMainPanel(params, popupCheckPoint)
    local metaId = params.metaId
    local actId = params.actId

    local function onHandleOver()
        ActivityEventCenter:dispatch(ActivityEvent.ACTIVITY_POPUP_OVER,{
            metaId = metaId
        })
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, popupCheckPoint)
    end

    local function onStopAutoPopup()
        --停掉强弹
        self._autoPopupMgr:resetPopup()
    end
    
    local function creator()
        local activityMgr = _G.amfBean("ActivityMgr")
        if not activityMgr:checkHasAutoPopupByMetaId(metaId) then
            AutoPopupDebugLog:log(metaId .. "checkHasAutoPopupByMetaId return false, stop auto popup")
            onHandleOver()
            return
        end

        ActivityEventCenter:dispatch(ActivityEvent.OPEN_ACTIVITY,{
            actId = actId,
            userClick = false,
        })

        safeRunCall(onStopAutoPopup)
        ActivityEventCenter:dispatch(ActivityEvent.ACTIVITY_POPUP_OVER,{
            metaId = metaId
        })
    end
    
    AutoPopupDC:setDcExtraParam1(popupCheckPoint, actId)
    self._autoPopupMgr:addPopupConfig(popupCheckPoint, creator, actId)
end

return TempActPanelHandler
