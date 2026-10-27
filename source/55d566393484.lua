
--@ref 强弹框架: 条件类强弹实际执行

local ConditionHandler = class("ConditionHandler")
local AutoPopupDebugLog = require "amf.middleware.autopop.AutoPopupDebugLog"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local MainSceneEventCenter = require "amf.feature.mainscene.core.event.MainSceneEventCenter"

function ConditionHandler:create(autoPopupMgr)
	local handler = ConditionHandler.new()
	handler:init(autoPopupMgr)
	return handler
end

function ConditionHandler:init(autoPopupMgr)
	self._autoPopupMgr = autoPopupMgr
	AutoPopEventCenter:register(AutoPopEvent.CONDITION, self.onHandlePopup, self)
end

function ConditionHandler:onHandlePopup(evt)
	local data = evt:getData()
	local popupCheckPoint = data.popupCheckPoint
	local params = data.params

	lua_switch(popupCheckPoint){
		[PopupCheckPoint.PLAY_LEVEL_BACK] = function ()
			self:handlePlayLevelBack(params)
		end,
		[PopupCheckPoint.EXIT_LEVEL_JUMP] = function ()
			self:handleOpenStartLevelPanel(params)
		end,
        [PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_3_1] = function ()
            self:handleActCustomizedPanelStage3(params)
        end,
        [PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_3_2] = function ()
            self:handleActCustomizedPanelStage3(params)
        end,
        [PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_3_3] = function ()
            self:handleActCustomizedPanelStage3(params)
        end,
        [PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_4_1] = function ()
            self:handleActCustomizedPanelStage4(params)
        end,
        [PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_4_2] = function ()
            self:handleActCustomizedPanelStage4(params)
        end,
        [PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_4_3] = function ()
            self:handleActCustomizedPanelStage4(params)
        end,
		[PopupCheckPoint.CLIMB_GIFT] = function()
			self:handleClimbGift(params)
		end,

		default = function ()
			assert(false, "ConditionHandler invalid popupCheckPoint : " .. tostring(popupCheckPoint))
		end
	}
end


function ConditionHandler:handlePlayLevelBack(params)
	local levelPlayInfo = params
	local function onHandleOver()
		self._autoPopupMgr:finishInterruptibleEntries()
		MainSceneEventCenter:dispatch(MainSceneEvent.Play.LEVEL_BACK_FINISHED, levelPlayInfo)
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.PLAY_LEVEL_BACK)
	end

	local function creator()
		if levelPlayInfo.isWin then
			local PassLevelProcessor = require "amf.feature.mainscene.world.logic.passlevel.PassLevelProcessor"
			local processor = PassLevelProcessor:create(levelPlayInfo)
			processor:process():next(function()
				ALog.log("ConditionHandler", "大藤蔓 处理过关事件结束")
				onHandleOver()
			end)
		else
			-- 闯关失败
			onHandleOver()
		end
	end
	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.PLAY_LEVEL_BACK, creator)
end

function ConditionHandler:handleOpenStartLevelPanel(params)
	local function onHandleOver()
		--如果开始面板、补星推荐弹出 则停掉强弹
		self._autoPopupMgr:resetPopupForStartGamePanel()
	end

	local function creator()
        if LevelSceneFunc:isFullLevelLib(params.levelScene) then
            _G.amfBean("FullStarLevelLibManager"):tryOpenStartPanel(false)
        else
            _G.amfBean("ExitLevelJumpManager"):runJumpLogic(params)
        end
        
		onHandleOver()
	end
	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.EXIT_LEVEL_JUMP, creator)
end

function ConditionHandler:handleActCustomizedPanelStage3(params)
	local index = params.index
	local metaId = params.metaId
    local actId = params.actId
    local levelData = params.levelData
    local autoPopupConfig = params.autoPopupConfig
    local _popupCheckPoint = PopupCheckPoint["ACT_CUSTOMIZED_PANEL_STAGE_3_" .. index]

    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, _popupCheckPoint)
    end

    local function creator()
		if self._autoPopupMgr._popoutManager:haveWindowOnScreenWithoutCommonTip() then
			return onHandleOver()
		end
    	if not autoPopupConfig then
    		AutoPopupDebugLog:log(string.format("ConditionHandler:handleActCustomizedPanelStage3===invalid autoPopupConfig. actId:%s metaId:%s index:%d", nil, nil, index)) 
            return onHandleOver()
        end
        local customizedCreator = autoPopupConfig:getCustomizedCreator()
        if not customizedCreator then
            AutoPopupDebugLog:log(string.format("ConditionHandler:handleActCustomizedPanelStage3===invalid customizedCreator. actId:%s metaId:%s index:%d", nil, nil, index)) 
            return onHandleOver()
        end
		
      	local status = pcall(customizedCreator, levelData, onHandleOver)
		if status then
            ActivityEventCenter:dispatch(ActivityEvent.ACTIVITY_POPUP_OVER,{
                metaId = metaId
            })
		else
			onHandleOver()
		end  
    end
	AutoPopupDC:setDcExtraParam1(_popupCheckPoint, actId)
    self._autoPopupMgr:addPopupConfig(_popupCheckPoint, creator, actId)
end

function ConditionHandler:handleActCustomizedPanelStage4(params)
	local index = params.index
	local metaId = params.metaId
    local actId = params.actId
    local autoPopupConfig = params.autoPopupConfig
    local _popupCheckPoint = PopupCheckPoint["ACT_CUSTOMIZED_PANEL_STAGE_4_" .. index]

    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, _popupCheckPoint)
    end

    local function creator()
		if self._autoPopupMgr._popoutManager:haveWindowOnScreenWithoutCommonTip() then
			return onHandleOver()
		end

    	if not autoPopupConfig then
    		AutoPopupDebugLog:log(string.format("ConditionHandler:handleActCustomizedPanelStage4===invalid autoPopupConfig. actId:%s metaId:%s index:%d", actId, metaId, index)) 
            return onHandleOver()
        end
		
        local customizedCreator = autoPopupConfig:getCustomizedCreator()
        if not customizedCreator then
            AutoPopupDebugLog:log(string.format("ConditionHandler:handleActCustomizedPanelStage4===invalid customizedCreator. actId:%s metaId:%s index:%d", actId, metaId, index)) 
            return onHandleOver()
        end
      	local status = pcall(customizedCreator, {}, onHandleOver)
		if status then
            ActivityEventCenter:dispatch(ActivityEvent.ACTIVITY_POPUP_OVER,{
                metaId = metaId
            })
		else
			onHandleOver()
		end  
    end

	AutoPopupDC:setDcExtraParam1(_popupCheckPoint, actId)
    self._autoPopupMgr:addPopupConfig(_popupCheckPoint, creator, actId)
end

return ConditionHandler
