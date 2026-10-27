local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local MainSceneButtonEventCenter = require "amf.feature.mainscenebutton.event.MainSceneButtonEventCenter"
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local LocalPush = require "amf.feature.localactivity.happydelivery.localpush.LocalPush"
local HappyDeliveryManager = class("HappyDeliveryManager", BaseFeatureManager)

function HappyDeliveryManager:_init()
    self:registerEvents()
    self:initActInfo()
end

function HappyDeliveryManager:setAutoPopupMgr(manager)
    self.autoPopupMgr = manager
end

function HappyDeliveryManager:setMainSceneButtonManager(manager)
    self.mainSceneButtonManager = manager
end

function HappyDeliveryManager:setUserStateManager(manager)
    self.userStateManager = manager
end

function HappyDeliveryManager:_getConstPath()
    return "amf.feature.localactivity.happydelivery.config.HappyDeliveryConst"
end

function HappyDeliveryManager:_getModelPath()
    return "amf.feature.localactivity.happydelivery.model.HappyDeliveryModel"
end

function HappyDeliveryManager:_getExtraPlugsConfigList()
    return {
        {
            key = "Download",
        },
        {
            key = "Panel",
        },
        {
            key = "Rewards",
        },
        {
            key = "DC",
            path = {
                plugPath = "amf.feature.localactivity.happydelivery.dc.HappyDeliveryDC",
            }
        },
    }
end

function HappyDeliveryManager:isEnabled()
    return self:getModel():isDataEnabled() and self:isActValid()
end

function HappyDeliveryManager:isActValid()
    return self:isBundleVersionSupport() and self:isClientVersionSupport() and self:getModel():isInMainTime()
end

function HappyDeliveryManager:isG4Enabled()
    return MaintenanceManager:getInstance():isEnabledInGroup("HappyDelivery", "G4")
end

function HappyDeliveryManager:isClientVersionSupport()
    local serverVersion = self:getDataByKey("clientVersionControl") or 0
    local localVersion = self:getConst().clientVersionControl or 0
    return serverVersion >= localVersion
end

function HappyDeliveryManager:isBundleVersionSupport()
    local ver = tonumber(string.split(_G.bundleVersion, ".")[2])
    local openVersion = self:getDataByKey("openVersion", "1.156")
    local openVer = tonumber(string.split(openVersion, ".")[2])
    return ver >= openVer
end

function HappyDeliveryManager:dcPlug()
    return self:_getPlug("DC")
end

function HappyDeliveryManager:registerEvents()
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)

    self:registerActEndTimer()
end

function HappyDeliveryManager:registerActEndTimer()
    if self.__passActMainNextTimer then
        TimerUtil.removeAlarm(self.__passActMainNextTimer)
        self.__passActMainNextTimer = nil
    end

    local mainEndTime = self:getModel():getMainEndTime()
    if not mainEndTime or mainEndTime <= 0 then return end

    local nowTime = TimeKit:timeInSec()
    if nowTime >= mainEndTime then return end

    self.__passActMainNextTimer = TimerUtil.addAlarm(function()
        self.__passActMainNextTimer = nil
        self:onPassActMainNext()
    end, mainEndTime - nowTime, 1)
end


function HappyDeliveryManager:initActInfo()
    if not self.actPlug then return end
    self:getModel():syncActInfo(self.actPlug:getActInfo())
end

function HappyDeliveryManager:onActPassDay()
    if self:getObserverNum() > 0 then
        self:notify("CloseAllPanel")
    end
    
    BaseFeatureManager.onActPassDay(self)
    MainSceneButtonEventCenter:dispatch(MainSceneButtonEvent.UPDATE)
end

function HappyDeliveryManager:onPassActMainNext()
    if self:getObserverNum() > 0 then
        self:notify("CloseAllPanel")
        CommonTip:showTip('开心快递活动已结束！')
    end
end

function HappyDeliveryManager:onSystemEnterForeground(event)
    if not self:isEnabled() then
        LocalPush:removeLocalPush()
        return
    end
end

function HappyDeliveryManager:onSystemEnterBackground(event)
    if not self:isEnabled() then return end

    self:tryScheduleDailyPush()
end

function HappyDeliveryManager:onActEnterStage2(event)
    if not self:isEnabled() then return end

    self:dcQualify()
end

function HappyDeliveryManager:onActEnterStage4(event)
    if not self:isEnabled() then return end
    if self:isDayCompleted() then return end

    self:tryDailyPopTip()
end

function HappyDeliveryManager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(self:getConst().actId)]

    if fromServer and not actInfo and not self:isEnabled() then
        self:getModel():reset()
    elseif fromServer and actInfo then
        self:getModel():syncActInfo(actInfo)
        if self.mainSceneButtonManager:isButtonCreated() then
            MainSceneButtonEventCenter:dispatch(MainSceneButtonEvent.UPDATE)
        end
    end
end

function HappyDeliveryManager:onActBeforePlayLevelEnd(event)
    if not self:isEnabled() then return end
    if not self.pendingAddPass then return end

    self.pendingAddPass = nil
    self:getModel():addPassCount()

    if self:isDayCompleted() then
        self.playingLastStep = true
    end
end

function HappyDeliveryManager:passDayRefreshData()
    self.pendingAddPass = nil
    self:getModel():passDayRefreshData()
end

function HappyDeliveryManager:tryDailyPopTip()
    if self:hasTipExposedToday() then return end

    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.HAPPY_DELIVERY_TIP_STAGE4)
    end

    local creator = function()
        self:showHappyDeliveryTip(onHandleOver, false)
    end

    self.autoPopupMgr:addPopupConfig(PopupCheckPoint.HAPPY_DELIVERY_TIP_STAGE4, creator)
end

function HappyDeliveryManager:tryScheduleDailyPush()
    if EnvUtil:isMiniGame() then return end
    if self:getLocalCache(self:getConst().PushKey.DAILY_PUSH_SCHEDULED, true) then return end

    local loginTime = TimeKit:timeInSec()
    self:setLocalCache(self:getConst().PushKey.DAILY_PUSH_SCHEDULED, true, true)

    LocalPush:scheduleDay2Push(loginTime)
end

function HappyDeliveryManager:getDataByKey(key)
    return self:getModel():getDataByKey(key)
end

function HappyDeliveryManager:getConfigByKey(key)
    return self:getModel():getConfigByKey(key)
end

function HappyDeliveryManager:getLocalCache(key, needTime)
    return self:getModel():getLocalCache(key, needTime)
end

function HappyDeliveryManager:setLocalCache(key, needTime, value)
    self:getModel():setLocalCache(key, needTime, value)
end

function HappyDeliveryManager:setTipExposedToday(flag)
    self:setLocalCache(self:getConst().TipKey.DAILY_EXPOSE, true, flag)
end

function HappyDeliveryManager:hasTipExposedToday()
    return self:getLocalCache(self:getConst().TipKey.DAILY_EXPOSE, true)
end

function HappyDeliveryManager:setInitAnimPlayedToday(flag)
    self:setLocalCache(self:getConst().TipKey.INIT_ANIM_PLAYED, true, flag)
end

function HappyDeliveryManager:hasInitAnimPlayedToday()
    return self:getLocalCache(self:getConst().TipKey.INIT_ANIM_PLAYED, true)
end

function HappyDeliveryManager:getCurDayInfo()
    return self:getModel():getCurDayInfo()
end

function HappyDeliveryManager:getCurTaskIndex()
    return self:getModel():getCurTaskIndex()
end

function HappyDeliveryManager:getBoxTier(boxInfo)
    local BoxTier = self:getConst().BoxTier
    if boxInfo.baseLevel == 2 then
        return BoxTier.LEVEL_2
    elseif boxInfo.baseLevel == 1 then
        return BoxTier.LEVEL_1
    end
end

function HappyDeliveryManager:isDayCompleted()
    local _, isCompleted = self:getCurTaskIndex()
    return isCompleted
end

function HappyDeliveryManager:getMainSceneButtonModuleConfig()
    if not self:isEnabled() then return end
    if self:isDayCompleted() and not self.playingLastStep then return end

    return {
        uniqueId = "HappyDeliveryShow",
        actId = self:getConst().actId,
        endTime = self:getModel():getMainEndTime(),
        extraModule = "amf.feature.localactivity.happydelivery.mainsceneextra.HappyDeliveryExtraButtonModule",
    }
end

function HappyDeliveryManager:onLastStepFinished()
    self.playingLastStep = false
    MainSceneButtonEventCenter:dispatch(MainSceneButtonEvent.UPDATE)
end

function HappyDeliveryManager:showHappyDeliveryTip(onHandleOver, userClick)
    local pos = self.mainSceneButtonManager:getButtonPosition()
    if not pos then return end

    _G.amfBean("AssetsUtil"):loadMiniFiles({ "amf/activity/happydelivery/texture/HappyDeliveryTip.plist" }):next(function()
        self:setTipExposedToday(true)
        self:dcShowMainPanel(userClick)

        local remaining = TimeUtil:getRemainSeconds(TimeUtil:getTomorrowBegin())
        local dayInfo = self:getCurDayInfo()
        local taskType = self:getTaskType()
        local HappyDeliveryTip = require_debug "amf.feature.localactivity.happydelivery.view.HappyDeliveryTip"
        local tip = HappyDeliveryTip:create(dayInfo, remaining, taskType, onHandleOver)

        Director:sharedDirector():getRunningSceneLua():addChild(tip, SceneLayerShowKey.POP_OUT_LAYER)
        tip:setPositionXY(pos.x, pos.y + 135)
        self:callPanelFunc("managePanelVM", tip)
    end)
end

function HappyDeliveryManager:getTaskType()
    local TaskType = self:getConst().TaskType
    if self.userStateManager:isFMJ() then
        return TaskType.PASS_LEVEL
    elseif not self.userStateManager:isColorfulStarFull() then
        return TaskType.FILL_STAR
    else
        return TaskType.RANDOM_CHALLENGE
    end
end

-- 关卡内在行为树判断通过、passlevel 协议发送前调用，用于快照创建 UI 所需数据
-- 若活动不可用返回 nil
-- 返回结构：
--   taskIndex     int       当前任务是每天第几次任务
--   curProgress   int       单任务当前进度（passlevel 前的值）
--   totalProgress int       单任务总进度要求
--   passCount     int       当天总通关数（passlevel 前的值）
--   boxInfo       table     宝箱配置，对应后端 BoxInfoBean：
--     baseLevel     int       宝箱初始等级（升级动画起点）
--     finalLevel    int       宝箱最终等级（L1~L5 或 S1~S5）
--     splitCount    int       分裂次数（0~5）
--     scriptResult  list<int> 剧本：3次点击升级值序列
--     rewards       list      奖励列表，每项 {rewardId, num}
--     rewarded      bool      奖励是否已领取
function HappyDeliveryManager:getUBFDisplayData()
    if not self:isEnabled() then return nil end

    local taskIndex, isCompleted = self:getCurTaskIndex()
    if isCompleted then return nil end

    local currentDay = self:getDataByKey("currentDay")
    local dayInfo = self:getCurDayInfo()
    local boxCfg = dayInfo.boxInfoList[taskIndex]
    local prevAccumulated = taskIndex > 1 and self:getModel():getAccumulatedRequired(taskIndex - 1) or 0
    local passCount = dayInfo.passCount
    local curProgress = passCount - prevAccumulated

    self.pendingAddPass = true

    return {
        currentDay = currentDay,
        taskIndex = taskIndex,
        curProgress = curProgress,
        totalProgress = boxCfg.passRequired,
        passCount = passCount,
        boxInfo = boxCfg,
    }
end

function HappyDeliveryManager:dcQualify()
    if self:getLocalCache(self:getConst().DCKey.HAS_QUALIFY, true) then return end
    self:setLocalCache(self:getConst().DCKey.HAS_QUALIFY, true, true)

    local dayInfo = self:getCurDayInfo()
    local levelNums = {}
    for _, boxInfo in ipairs(dayInfo.boxInfoList) do
        table.insert(levelNums, tostring(boxInfo.passRequired))
    end
    local t1 = table.concat(levelNums, "_")
    local t2 = self:getDataByKey("userCrowdId")
    self:dcPlug():dcQualify(t1, t2)
end

function HappyDeliveryManager:dcJoin()
    if self:getLocalCache(self:getConst().DCKey.HAS_JOIN, true) then return end
    self:setLocalCache(self:getConst().DCKey.HAS_JOIN, true, true)
    self:dcPlug():dcJoin()
end

function HappyDeliveryManager:dcShowMainPanel(userClick)
    local t1 = userClick and "vine_icon" or "popoup"
    local completedCount = self:getModel():getCompletedCount()
    self:dcPlug():dcShowMainPanel(t1, completedCount)
end

function HappyDeliveryManager:playEffect(type, loop)
    local type = "amf/activity/happydelivery/sound/" .. type
    self[type .. "_effect"] = GamePlayMusicPlayer.getInstance():playEffect(type, nil, loop)
end

function HappyDeliveryManager:playHaptics(haptics)
    HapticsManager:playInActScene(haptics)
end

return HappyDeliveryManager
