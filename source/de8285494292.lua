local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local ActivityName = "SH01"
local Manager = class(ActivityName.."Mgr", BaseFeatureManager)

function Manager:log(...)
    if EnvUtil:isDevelopMode() then
        printx(42, "***** sh01 *****  ", ...)
    end
end

-- 获取常量路径
function Manager:_getConstPath()
    return "amf.feature.localactivity.sh01.const.SH01Const"
end

-- 获取model路径
function Manager:_getModelPath()
    return "amf.feature.localactivity.sh01.model.SH01Model"
end

-- 获取需要启动的额外功能列表
function Manager:_getExtraPlugsConfigList()
    return {
        {
            key = "Rewards",
        },
    }
end

-- 如果有自己需要初始化的内容，覆写这个
function Manager:_init()
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
	if not EnvUtil:isAMFEnabled() then
        -- 保证老app的正常
        Notify:register(ActInterface.kAddEnergyPanelPlugin, function(data)
            self:onActAddEnergyPanelPlugin(data)
        end)
    end
end

function Manager:clearData()
    self:getModel():clearData()
end

function Manager:isEnabled()
    return self:getModel():isDataEnabled() and self:getModel():isInMainTime()
end

function Manager:isEnabled2()
    return self:getModel():isDataEnabled()
end

function Manager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(self:getConst().actId)]
    -- not 服务器发来且有actInfo，就返回
    if not (fromServer and actInfo) then return end

	local actInfo = _G.amfBean("ActivityMgr"):getActInfo(self:getConst().actId)
	if actInfo == nil then
		self:clearData()
	end
end

---强弹
function Manager:checkSh01ActivityPop(dontDispatch)
    -- 能拿到actInfo，活动开了，发事件
    local actInfo = _G.amfBean("ActivityMgr"):getActInfo(self:getConst().actId)
    if not actInfo then
        return false
    end

    --回流不弹
    if actInfo.extra and actInfo.extra ~= "" then
        local data = table.deserialize(actInfo.extra) or {}
        if data.livenessTag and tonumber(data.livenessTag) == 2 then
            return false
        end
    end

    local bGetSucess, key = self:getPopMainPanelKey()
    -- 本地数据没准备好不弹
    if not bGetSucess then return end
    local bHadPop = self:getModel():getValueFromLocalByKey(key, tostring(self:getModel():getMainBeginTime()))
    --弹过不弹
    if bHadPop then return end

    if not dontDispatch then
        AutoPopEventCenter:dispatch(AutoPopEvent.ACTIVITY, {
            popupCheckPoint = PopupCheckPoint.SH01_MAIN_POP
        })
    end

    return true
end

function Manager:openActivity(delegate)
    self.actPlug:openActivity(delegate)
end

function Manager:handleSh01ActivityPop( endCall )
    if (not self:isEnabled()) or (not self:checkSh01ActivityPop(true)) then
        safeRunCall(endCall)
        return
    end

    local function closeCall()
        self:setPopMainFinish()
        safeRunCall(endCall)
    end

    self:openActivity({
        actId = self:getConst().actId,
        -- 结束callback设置本地弹出过标记
        endCallback = closeCall,
        -- 失败callback不用标记
        failCallback = endCall,
        userClick = false,
    })
end

function Manager:onActEnterStage2(evt)
    if (not self:isEnabled()) or (not self:checkSh01ActivityPop(true)) then
        return
    end
    
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.SH01_MAIN_POP)
    end

    local creator = function()
        self:handleSh01ActivityPop(onHandleOver)
    end

    _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.SH01_MAIN_POP, creator)
end

function Manager:onActEnterStage4(evt)
    if (not self:isEnabled()) or (not self:checkSh01ActivityPop(true)) then
        return
    end
    
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.SH01_MAIN_POP)
    end

    local creator = function()
        self:handleSh01ActivityPop(onHandleOver)
    end

    _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.SH01_MAIN_POP, creator)
end

function Manager:fruitCanAddBoard( )
	return self:isEnabled()
end

function Manager:processBoard( fruitTreeUI, boardParent )
    local InFruitTreePosition = ccp(0, -173)
    local parent = fruitTreeUI
    if EnvUtil:isAMFEnabled() then
        parent = boardParent or fruitTreeUI
        InFruitTreePosition = ccp(parent:getContentSize().width / 2, 30)
    end
    local AppearTime = 6/30
    local AppearDistanceY = 20

	local uiData = force_require 'amf/feature/localactivity/sh01/view/uisource/FruitTreePlug_UI'
	local fruitTreePlugUI, childList = UIBuilder:builderChildUI(uiData, "panel")
	fruitTreePlugUI:setPositionXY(InFruitTreePosition.x, InFruitTreePosition.y)
	parent:addChild(fruitTreePlugUI)

	local function hideBoard()
		if not fruitTreePlugUI or fruitTreePlugUI.isDisposed then
			return
		end

        local Tween = require "amf.middleware.ui.util.Tween"
		Tween.to(fruitTreePlugUI,AppearTime,{
	        fAlpha = 0
	    })

		local moveBy = CCEaseBackIn:create(CCMoveBy:create(AppearTime, ccp(0, AppearDistanceY)))
		local func = CCCallFunc:create(function ( ... )
			if self.isDisposed then return end
			fruitTreePlugUI:removeFromParentAndCleanup(true)
			fruitTreePlugUI = nil
		end)
		local array = CCArray:create()
		array:addObject(moveBy)
		array:addObject(func)
		local action = CCSequence:create(array)
		fruitTreePlugUI:runAction(action)
	end

	childList.bg:setTouchHandler(function()
		hideBoard()
	end, nil, function() return true end)

	childList.button:setCallBack(  function()
        if not EnvUtil:isAMFEnabled() then
		    Director:sharedDirector():popScene()
        else
            local FruitTreeEventCenter = require "amf.feature.fruittree.event.FruitTreeEventCenter"
            FruitTreeEventCenter:dispatch(FruitTreeEvent.CLOSE_ALL_PANEL)
        end
        local function openActivity()
            self:openActivity({extra={from="fruitTree"}, userClick=true})
        end
        setTimeOut( openActivity, 0.5 )
	end)

	local panelId = UICreateUtil:getPanelId("FruitTreePlug")
	DcUtil:UserTrack({
		category = "promotion_sh",
		sub_category = "fruittree_show",
		panel_id = panelId
	})
end

function Manager:energyPanelCanAddBoard( )
	return self:isEnabled()
end

function Manager:isMainScene()
    local scene = Director:sharedDirector():getRunningSceneLua()
    if scene then
        if scene:is(HomeScene) then return true end
        if scene:isScene("MainScene") then return true end
    end
    return false
end

function Manager:onActAddEnergyPanelPlugin( data )
	if not self:energyPanelCanAddBoard() then return end
	if not self:isMainScene() then return end

	local Plugin_SH01 = require 'amf/feature/localactivity/sh01/view/Plugin_SH01'
	data.pluginNode = Plugin_SH01.create()

	local panelId = UICreateUtil:getPanelId("Plugin_SH01")
	DcUtil:UserTrack({
		category = "promotion_sh",
		sub_category = "energy",
		panel_id = panelId
	})
end

function Manager:getActivityIcon()
    return self.actPlug:getActIcon()
end

-- 同步所有数据
function Manager:updateData(data, skipSaveLocal, fromServer)
    if not data then return end

    self:getModel():fromServer(data,skipSaveLocal)

    if fromServer == true then
        self.hasGetDataFromServer = true
    end
end

-- 普通的addRewards,开宝箱之类的
function Manager:addRewardsNormal(rewardItems, params)
    self:callPlug("Rewards","addRewardsNormal",
    rewardItems,
    params)
end

function Manager:getPopMainPanelKey(  )
    local key = "sh01PopMain_"
    if self:isEnabled() then 
        return true, key
    else
        return false, key
    end
end

function Manager:setPopMainFinish(  )
    local bGetSucess, key = self:getPopMainPanelKey()
    if bGetSucess then
        -- 数据enable了才有 mainBeginTime
        self:getModel():saveValueToLocalByKey(key, tostring(self:getModel():getMainBeginTime()), false, true)
    end
end

return Manager