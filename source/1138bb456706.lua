-- 活动id
local ACT_ID = 6057
-- 活动名称
local ACT_NAME = "GemMining"
-- 活动中文名称
local ACT_CH_NAME = "挖宝石!"
-- 活动config
local ACT_SOURCE = string.lower( ACT_NAME )..'/Config.lua'
-- 功能版本号，活动类重开应该自增,只做逻辑版本号，活动周期清理放在拉数据的时候
local FEATURE_VERSION = 2
-- 功能目录
local LOCAL_PATH = 'amf.feature.localactivity.'..string.lower( ACT_NAME )
local LocalServer = require('amf.feature.localactivity.' .. string.lower( ACT_NAME ) .. '.' .. ACT_NAME .. 'LocalServer')
local BaseFeatureManager =
    require "amf.middleware.activity.base.BaseFeatureManager"
require "amf.middleware.autopop.config.AutoPopupConst"

local Manager = class("GemMiningManager", BaseFeatureManager)
Manager.ACT_NAME = ACT_NAME
Manager.ACT_CH_NAME = ACT_CH_NAME
Manager.ACT_ID = ACT_ID     -- 活动id
Manager.SHARE_ID = 201      -- 分享id
Manager.FUNC_ID = ACT_ID
Manager.FEATURE_VERSION = FEATURE_VERSION
Manager.GAME_NAME = "handle_low_strategy"
-- Manager.panelColorType = _G.PanelColorTypeConfig.kDecade2024
Manager.Events = {
    kCloseAllPanel = 'CloseAllPanel',    --关闭所有界面
}

local Const = {
    actKey = tostring(ACT_ID),
    Haptics = {
        DIG_GRID = "Normal",
    },
}

local ClassUtils = require('amf.script.tool.clazz.ClassUtils')
ClassUtils:makeSingleton(Manager, true) --单例

function Manager:setAutoPopupMgr(autoPopupMgr)
    self.autoPopupMgr = autoPopupMgr
    if self.autoPopPlug then
        self.autoPopPlug:setAutoPopupMgr(autoPopupMgr)
    end
end

function Manager.dcUserTrack(subCategory, extraData)
    local params = {
        category = Manager.GAME_NAME,
        sub_category = subCategory,
    }
    for k,v in pairs(extraData or {}) do
        params[k] = v
    end

    DcUtil:UserTrack(params)
end

function Manager:closeAll()
    self:notify(Manager.Events.kCloseAllPanel)
end


local PaymentTracer = require"amf.middleware.purchase.dc.trace.PaymentTracer"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"

function Manager:log(...)
    ALog.log(ACT_CH_NAME, ...)
end


function Manager:initialize()
    self.meta = require('amf.feature.localactivity.'..string.lower(ACT_NAME)..'.meta.Meta.lua')
    self.localDataServer = LocalServer:create()
    self:initPlugs()
    self.hasSyncedActInfoOnline = false
    self.localDataServer:tryPassDay()
    self:registerNotify()
    self:initModules()
    self:registerShare()
    self:loadRes()
end

function Manager:loadRes()
    if self.isResLoading then return end
    if self.resEnabled then return end
    _G.amfBean("AssetsUtil"):loadMiniFiles({"amf/activity/gemmining/collection.png"}):next(function()
        self.resEnabled = true
        self.isResLoading = false
    end, function()
        self.isResLoading = false
    end)
end

function Manager:checkResEnabled()
    return self.resEnabled
end

-- 分享注册
function Manager:registerShare()
end

function Manager:registerNotify()
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self.onCustomPropGain, self)
    PropEventCenter:register(PropEvent.CUSTOM_CONSUME, self.onCustomPropConsume, self)
end

function Manager:onCustomPropGain(event)
    local reward = event and event:getData()
    if not reward or tonumber(reward.itemId) ~= self.meta.collectItemId then
        return
    end
    self:getData():addCollectNum(tonumber(reward.num) or 0)
    self:updateTipView()
end

function Manager:onCustomPropConsume(event)
    local reward = event and event:getData()
    if not reward or tonumber(reward.itemId) ~= self.meta.collectItemId then
        return
    end
    self:getData():addCollectNum(-(tonumber(reward.num) or 0))
    self:updateTipView()
end


function Manager:createIcon(reward, isRewardsPanel)
    if not reward or table.isEmpty(reward) then
        if EnvUtil:isWindows() then CommonTip:showTip("什么玩意咋没给道具还要创呢？") end
        return Sprite:createEmpty()
    end
    return GameItemCreator:getPropIcon(reward)
end

function Manager:hasGetAllMap()
    return self:getData():hasClaimedAllMapRewards()
end

function Manager:getNowMapGemNum()
    local nowId = self:getData():getNowMapId()
    if nowId >= 0 then 
        return self:getData():getMapGemNum(nowId)
    else 
        return 0,0
    end 
end

function Manager:getNowMapId()
    local nowId = self:getData():getNowMapId()
    return nowId
end


local DIContainer = class("DIContainer")

function DIContainer:ctor()
    self.dependencies = {}
end
    
function DIContainer:register(name, dependency)
    self.dependencies[name] = dependency
end

function DIContainer:resolve(name)
    return self.dependencies[name]
end

function Manager:initModules()
    local container = DIContainer.new()
    container:register("mgr" , self)
    container:register("data" , self:getData())
    container:register("meta" , self.meta)
    container:register("GAME_NAME" , self.GAME_NAME)
    container:register("ACT_ID" , self.ACT_ID)
    local RewardModule = require"amf.feature.localactivity.gemmining.modules.RewardModule"
    self.rewardModule = RewardModule.new(container)
end

function Manager:addRewardsWhenBought(goodsId, rewardItems, params)
    return self.rewardModule:addRewardsWhenBought(goodsId, rewardItems, params)
end

-- 普通的addRewards,开宝箱之类的
function Manager:addRewardsNormal(rewardItems, params)
    return self.rewardModule:addRewardsNormal(rewardItems, params)
end

-- 商城加奖励
function Manager:addRewardsForShop(rewardBean,params)
    return self.rewardModule:addRewardsForShop(rewardBean,params)
end


function Manager:getLocalDataServer()
    return self.localDataServer
end

function Manager:getData()
    return self:getLocalDataServer()
end

function Manager:getFuncId()
   return self.FUNC_ID
end

function Manager:getActInfo()
    local activityMgr = _G.amfBean("ActivityMgr")
    local runtimeActInfo = activityMgr and activityMgr:getActInfo(self.ACT_ID) or nil

    if self.hasSyncedActInfoOnline then
        return runtimeActInfo
    end

    return runtimeActInfo or self:getData():getCachedActInfo()
end

function Manager:updateTipView()
    if not self:isEnabled() then
        return
    end


    local actInfo = self:getActInfo()

    local function setIconInfo(  hasReward, msgNum )
        if not actInfo then return end
        actInfo.reward = hasReward
        actInfo.msgNum = msgNum
        actInfo.fromLocal = true
        ActivityEventCenter:dispatch(ActivityEvent.SET_ACT_INFO, actInfo)
    end
    
    local hasReward = self:hasRewards()
    local msgNum = self:getShowMsgNum()
    setIconInfo(hasReward, msgNum)


    local icon = self:getActivityIcon()
    if icon and type(icon.updateIconShow) == "function" then
        icon:updateIconShow()
    end 

end

function Manager:hasRewards()
    if not self.localDataServer:isBaseDataEnabled() then 
        local actInfo = self:getActInfo()
        return actInfo.reward
    end 

    local data = self:getData()
    local nowCollectNum = tonumber(data:getDataByKey("nowCollectNum", 0)) or 0

    if nowCollectNum > 0
        and (self:hasGetAllMap() or data:isActInReward()) then
        return true
    end
    local nowMapId = data:getNowMapId()
    local nowMap = data:getMapBeanById(nowMapId)

    if nowMap and not nowMap.progressReward then
        local openNum, allNum = data:getMapGemNum(nowMapId)
        if allNum > 0 and openNum >= allNum then
            return true
        end
    end

    return false
end


function Manager:getShowMsgNum()
    if not self.localDataServer:isBaseDataEnabled() then 
        local actInfo = self:getActInfo()
        return actInfo.msgNum
    end 
    if self:hasGetAllMap() then return 0 end 
    return self:getData():getDataByKey("nowCollectNum") or 0 
end

function Manager:onActEnterMainScene(event)
    if not self:isEnabled() then return end
    self:loadRes()
end

function Manager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local actInfo = actInfos[tostring(Manager.ACT_ID)]
    local fromServer = data.fromServer
    if not fromServer then
        return
    end

    self.hasSyncedActInfoOnline = true
    if actInfo then
        self:getData():setCachedActInfo(actInfo)
        return
    end

    self:getData():clearCachedActInfo()
    self:closeAll()
    ActivityEventCenter:dispatch(ActivityEvent.REMOVE_ACTIVITY, {
        actId = Manager.ACT_ID,
    })
end

function Manager:isActInfoEnabled()
    return self:getActInfo() ~= nil
end

function Manager:isEnabled()
    if not self:isActInfoEnabled() then return false end 
    local ret,reason = self.localDataServer:isDataEnabled() 
    return ret,reason
end

--解析活动数据
function Manager:parseData(data)
    if not data then return end

    local localActPeriodId = self:getData():getDataByKey("periodId")
    local serverActPeriodId = data.periodId
    local hasLocalPeriod = localActPeriodId ~= nil and tostring(localActPeriodId) ~= "0"
    local hasServerPeriod = serverActPeriodId ~= nil and tostring(serverActPeriodId) ~= "0"
    local periodChanged = hasLocalPeriod and hasServerPeriod
        and tostring(localActPeriodId) ~= tostring(serverActPeriodId)

    if periodChanged then
        local localConfig = self:getData():getDataByKey("localConfig")
        self:getData():resetForNewPeriod()
        if not data.extra and localConfig and not table.isEmpty(localConfig) then
            data.extra = table.serialize(localConfig)
        end
    end

    self:getData():fromServer(data,nil)
    if serverActPeriodId ~= nil then
        self:getData():setDataByKey("periodId", serverActPeriodId, true, true)
    end
    if not self.hasServerData then
        self:updateTipView()
        self.hasServerData = true
    end
end


function Manager:onActPassDay()
    self:getData():onPassDay()
end


-- -- 打点
-- function Manager:dc(category, subCategory, t1, t2, t3, t4, extraData)
--     local params = {
--         game_type = "stage",
--         game_name = Manager.GAME_NAME,
--         category = category,
--         sub_category = subCategory,
--         t1 = t1,
--         t2 = t2,
--         t3 = t3,
--         t4 = t4,
--     }

--     if extraData and not extraData.panel_id and extraData.panelId then 
--         extraData.panel_id = extraData.panelId
--         extraData.panelId = nil
--     end 


--     for i, v in pairs(extraData or {}) do
--         params[i] = v
--     end
--     -- self:log("---- dc ----", tts(params))
--     DcUtil:activity(params)
-- end
--------------业务逻辑-----------


function Manager:getDcFeatureAndSource( suffix )
    return self.rewardModule:getDcFeatureAndSource(suffix)
end

function Manager:getActivityIcon()
    return _G.amfBean("IconManager"):getIconByIconKey(tostring(Manager.ACT_ID))
end


function Manager:getShareType()
    if not self:isSupportShare() then return -1 end
    local isWeChat = self:isWechatInstalled()
    local isWeibo = self:isWeiboInstalled()

    if isWeChat and isWeibo then
        return 3
    elseif isWeibo then
        return 2
    elseif isWeChat then
        return 1
    else
        return 0
    end
end

--是否可分享，精品包
function Manager:isSupportShare()
    return true
end

-- 是否已安装微信
function Manager:isWechatInstalled()
    return OpenUrlUtil:canOpenUrl("weixin://")
end

-- 是否已安装微博
function Manager:isWeiboInstalled()
    return OpenUrlUtil:canOpenUrl("sinaweibo://userinfo?uid=3653487227")
end


function Manager:setShareTipStart()
    self.shareTip = true 
end

function Manager:setShareTipOver()
    safeRunCall(self.shareTipOverCall)
    self.shareTipOverCall = nil 
    self.shareTip = false 
end

function Manager:setShareTipOverCall(call)
    self.shareTipOverCall = call
end


function Manager:hasShareTip()
    return self.shareTip  
end


-- 分享到微信朋友圈
function Manager:shareToWechatMoments(params)
    params = params or {}
    local successCallback = params.successCallback
    local failCallback = params.failCallback
    local title = params.title
    local message = params.message
    local thumbPath = params.thumbPath
    local imagePath = params.imagePath

    local shareCallback = {
        onSuccess = function(result)
            self:setShareTipStart()
            safeRunCall(successCallback)
            setTimeOut(function()
                CommonTip:showTip("分享成功",nil,function()
                    self:setShareTipOver()
                end)
            end)
        end,
        onError = function(errCode, errMsg)
            CommonTip:showTip("分享失败")
            safeRunCall(failCallback)
        end,
        onCancel = function()
            CommonTip:showTip("分享失败")
            safeRunCall(failCallback)
        end,
    }

    if EnvUtil:isWindows() then
        safeRunCall(shareCallback.onSuccess)
        return
    end

    if not self:isWechatInstalled() then
        CommonTip:showTip("暂未安装微信", "negative")
        safeRunCall(failCallback)
        return
    end

    local shareType
    if EnvUtil:isAndroid() then
        shareType = PlatformShareEnum.kSYS_WECHAT
    else
        shareType = ShareCenterUtil:getShareType()
    end
    -- TODO 微信朋友圈分享
    -- local context = OpenShareContext.new(OpenShareConst.ShareType.xxx, OpenShareConst.ShareTarget.WXMoment)
    --     :setTextParams(title, message)
    --     :setImgParams(thumbPath, imagePath)
    --     :setShareCallback(shareCallback.onSuccess, shareCallback.onError, shareCallback.onCancel)
    -- _G.amfTransaction(TransactionEvent.SHARE, context)
end

-- 分享到微博超话，小游戏去掉
function Manager:shareToWeiboSuperTopic(params)
    params = params or {}
    safeRunCall(params.onSuccess)
end

---------------------------------- 关卡内 begin--------------------------------
--关卡内触发条件
function Manager:isEnabledInLevel(data)
    if not self:isEnabled() then return false end
    if self:hasGetAllMap() then return false end 
    return true
end

--获取分数BUFF加成值跟buff结束时间
function Manager:getCurAvailableBuffAndEndTime(data)
    local buffRate = 0
    local buffEndTime = 0
    local levelId = data.levelId
    local levelScene = data.levelScene
    -- local isMainLevel = UBFLevelSceneFunc:isMainLevel(levelScene)
    -- if isMainLevel and not _G.amfBean("UserStateManager"):isFMJ() then
        -- local isTopLevel = levelId == _G.getTopLevelId() and not _G.amfBean("LevelAreaManager"):hasPassedLevelEx(levelId, UBFLevelSceneType.kMain)
        -- if not isTopLevel and not UBFActHelper:isFullStar(levelId, levelScene) then
            local curTime = TimeKit:timeInSec()
            local score20BuffEndTime = self:getData():get20BuffEndTime()
            local score50BuffEndTime = self:getData():get50BuffEndTime()
            if curTime < score20BuffEndTime then
                buffRate = 0.20
                buffEndTime = score20BuffEndTime
            end
        
            if curTime < score50BuffEndTime then
                buffRate = buffRate + 0.50
                if buffEndTime > 0 then
                    buffEndTime = math.min(buffEndTime, score50BuffEndTime)
                else
                    buffEndTime = score50BuffEndTime
                end
            end
        -- end
    -- end

    return buffRate, buffEndTime
end


--收集物双倍BUff结束时间
function Manager:getTimeLimitRateEndTime()
    return self:getData():getBuffEndTime() or 0 
end

--关卡内活动启动数据
function Manager:getInLevelActData(levelId)
    local inLevelActData = {}
    local buffEndTime = self:getTimeLimitRateEndTime()
    --是否有限时buff
    inLevelActData.hasTimeLimiteBuff = buffEndTime > TimeKit:timeInSec() 
    --限时buff结束时间
    inLevelActData.buffEndTime = buffEndTime

    return inLevelActData
end

--打关结束时更新数据
function Manager:updatePassLevelData(data, collectionCount, collectionMap, passLevelData)
    if not self:getData():isActInMain() then
        -- 保留关卡内和主场景飞入表现，只移除发给后端的活动收集物。
        local passLevelJson = passLevelData and passLevelData.passLevelJson
        if passLevelJson then
            passLevelJson.collectionInfo = nil
        end
        return
    end

    --结算失败时不给收集物
    if data.settleMentState and collectionCount and collectionCount > 0 then
        self:getData():addCollectNum(collectionCount)
    end
end

function Manager:getMainSceneButtonShowConfig()
    local buffRate, endTime = self:getCurAvailableBuffAndEndTime({
        levelId = _G.getTopLevelId(),
        levelScene = UBFLevelSceneType.kMain,
    })
    local buffEndTime = self:getTimeLimitRateEndTime()

    local showConfig = {}
    local nowTime = TimeKit:timeInSec()
    if endTime > nowTime then
        table.insert(showConfig, 
            {
                uniqueId = _G.BuffTypeConfig.SCORE_BUFF,
                actName = ACT_CH_NAME,
                actId = ACT_ID,
                showStr = "",
                endTime = endTime,
                rate = buffRate + 1,
            }
        )
    end

    if buffEndTime > nowTime and self:checkResEnabled() and self:isEnabled() then
        table.insert(showConfig, 
            {
                uniqueId = "GemMingingDoubleBuff",
                actId = ACT_ID,
                actName = ACT_CH_NAME,
                iconCreator = function()
                    return Sprite:create("amf/activity/gemmining/collection.png")
                end,
                endTime = buffEndTime,
                rate = 2,
            }
        )
    end
    return showConfig
end

------------------------------------------- 额外插件 -------------------------------------------
function Manager:getConst()
    return Const
end

function Manager:getActMainEndTime()
    return self:getLocalDataServer():getActMainEndTime()
end

function Manager:playHaptics(type)
    self:callHapticsFunc("playHaptics", type)
end

-- 主面板每日场景4强弹1次；日次数由 AutoPopupLimit 统一管理。
function Manager:_getAutoPopConfigList()
    local PCP = _G.PopupCheckPoint
    local PopStage = AutoPopupConst.PopStage

    return {
        {
            checkPoint = PCP.GEM_MINING_MAIN_POP_STAGE_4,
            manualOpen = ACT_ID,
            stages = { PopStage.STAGE_FOUR },
            check = function()
                return self:checkCanPopMainPanelStage4()
            end,
            creator = function(_, onPopOver)
                return function()
                    self:popMainPanelStage4(onPopOver)
                end
            end,
        },
    }
end

-- 与开心农家乐一致，仅同步检查活动处于正式期且数据可用。
function Manager:checkCanPopMainPanelStage4()
    return self:isEnabled() and self:getData():isActInMain()
end

-- 所有无法打开的路径都结束当前强弹，避免阻塞后续队列。
function Manager:popMainPanelStage4(onPopOver)
    if not self:checkCanPopMainPanelStage4() then
        safeRunCall(onPopOver)
        return
    end

    self:openActivity(onPopOver, {
        from = "auto_popup_stage4",
    }, false)
end

function Manager:openActivity(closeCallback, extra, userClick, duanMianData)
    ActivityEventCenter:dispatch(ActivityEvent.OPEN_ACTIVITY, {
        actId = ACT_ID,
        failCallback = closeCallback,
        endCallback = closeCallback,
        userClick = userClick == true,
        extra = extra,
        duanMianData = duanMianData,
    })
end

function Manager:initPlugs()
    self:_initPlug("Notify")
    self:addEventDispatcher()
    self:_initPlug("AutoPop")
    self:_initPlug("ActSend", {
        plugPath = "amf.feature.localactivity.gemmining.plug.GemMiningActSendPlug",
    })
    self:_initPlug("Haptics", {
        plugPath = "amf.feature.localactivity.gemmining.plug.HapticsPlug",
        hapticsRoot = "amf.feature.localactivity.gemmining.haptics.",
    })
end

return Manager
