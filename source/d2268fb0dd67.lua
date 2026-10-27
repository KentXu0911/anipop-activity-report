
local FunctionHandler = class("FunctionHandler")

function FunctionHandler:create(autoPopupMgr)
	local handler = FunctionHandler.new()
	handler:init(autoPopupMgr)
	return handler
end

function FunctionHandler:init(autoPopupMgr)
	self._autoPopupMgr = autoPopupMgr
	AutoPopEventCenter:register(AutoPopEvent.FUNCTION, self.onHandlePopup, self)
end

function FunctionHandler:onHandlePopup(evt)
	local data = evt:getData()
	local popupCheckPoint = data.popupCheckPoint
	local params = data.params

    lua_switch(popupCheckPoint){
		[PopupCheckPoint.SCROLL_TO_CURRENT_LEVEL] = function ()
			self:handleScrollToCurrentLevel(params)
		end,

		default = function ()
			assert(false, "FunctionHandler invalid popupCheckPoint : " .. tostring(popupCheckPoint))
		end
	}
end

--小游戏进大藤蔓后从第一关滚动到当前关并震动两次
function FunctionHandler:handleScrollToCurrentLevel(params)
    if EnvUtil:isMiniGame() and EnvUtil:isDevelopMode() then
        local datas = {
            udid = MetaInfo:getInstance():getUdid(),
            deviceModel = MetaInfo:getInstance():getDeviceModel(),
            gameVersion = _G.bundleVersion,
        }
        CS.CallJS.CallS("globalThis.sendQADcData", table.serialize(datas))
    end

	local function isVibrateEnabled()
		return true
	end

	local function vibrateShort(count, callback)
		if count > 0 then
			TimerUtil.addAlarm(function()
				local vibrateType = "light"
				if count == 1 then
					vibrateType = "heavy"
				elseif count == 2 then
					vibrateType = "medium"
				end
				local config = {
					miniGame = {
						level = vibrateType
					}
				}
				_G.HapticsContext.new()
					:setConfig(config)
					:execute()
				vibrateShort(count - 1)
			end, 0.20)
		else
			if callback then callback() end
		end
	end

	--先只震动不滚动，刚进大藤蔓性能有问题
	do
		if isVibrateEnabled() then
			setTimeOut(function()
				vibrateShort(2)
			end, 0.3)
		end
		return
	end

	local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.SCROLL_TO_CURRENT_LEVEL)
	end

	local function creator()
		--UWarning("DEVICE_BENCHMARK_LEVEL", DEVICE_BENCHMARK_LEVEL)
		setTimeOut(function()
			local topLevelId = getTopLevelId(true)
			local dt = math.clamp(0.5 + topLevelId / 10000, 0.5, 1.0)
			if topLevelId < 10 then
				dt = 0.1
			end
			local MainSceneEventCenter = require 'amf.feature.mainscene.core.event.MainSceneEventCenter'
	
            MainSceneEventCenter:dispatch(MainSceneEvent.Trunk.MOVE_TRUNK_TO, {
				levelId = topLevelId,
                levelScene = UBFLevelSceneType.kMain,
				duration = 0.5,
				callback = onHandleOver
			})
			if isVibrateEnabled() then
				vibrateShort(math.ceil(dt / 0.25))
			end
		end, 0.8)
	end
	self._autoPopupMgr:addPopupConfig(PopupCheckPoint.SCROLL_TO_CURRENT_LEVEL, creator)
end

return FunctionHandler