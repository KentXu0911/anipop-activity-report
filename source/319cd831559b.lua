local ActivityHandler = class("ActivityHandler")

function ActivityHandler:create(autoPopupMgr)
	local handler = ActivityHandler.new()
	handler:init(autoPopupMgr)
	return handler
end

function ActivityHandler:init(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
	AutoPopEventCenter:register(AutoPopEvent.ACTIVITY, self.onHandlePopup, self)
end

--活动需要加载。加载完，强弹状态机可能已结束当前轮。再按需触发一次
function ActivityHandler:retriggerAutoPopup()
    if self._autoPopupMgr:isInMainScene() then
        self._autoPopupMgr:triggerStage2AutoPopup()
    end
end

function ActivityHandler:onHandlePopup(event)
    local data = event:getData()
    local popupCheckPoint = data.popupCheckPoint
    local params = data.params
	lua_switch(popupCheckPoint){
		[PopupCheckPoint.ACT_NEW] = function ()
			self:handleActivityNew(params)
		end,

        [PopupCheckPoint.SH01_MAIN_POP] = function ()
			self:handleActivitySH01(params)
		end,

		default = function ()
			assert(false, "ActivityHandler invalid popupCheckPoint : " .. tostring(popupCheckPoint))
		end
	}
end

function ActivityHandler:handleActivityNew(params)
    local needRetrigger = params and params.needRetrigger

    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.ACT_NEW)
    end

    local function creator()
        _G.amfBean("PopupNewActMgr"):popNewActPanel(onHandleOver)
    end
    self._autoPopupMgr:addPopupConfig(PopupCheckPoint.ACT_NEW, creator)

    --新活动特殊处理，多触发一次强弹
    if needRetrigger then
        self:retriggerAutoPopup()
    end
end

function ActivityHandler:handleActivitySH01(params)
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.SH01_MAIN_POP)
    end

    local function creator()
        if _G.amfBean("SH01Manager") and _G.amfBean("SH01Manager"):isEnabled() then
            _G.amfBean("SH01Manager"):handleSh01ActivityPop( onHandleOver )
        else
            onHandleOver()
        end
    end

    local function delayCreator()
        setTimeOut(creator,1)
    end

    self._autoPopupMgr:addPopupConfig(PopupCheckPoint.SH01_MAIN_POP, delayCreator)
end

return ActivityHandler
