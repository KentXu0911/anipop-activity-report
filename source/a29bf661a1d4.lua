local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local MainSceneButtonEventCenter = require "amf.feature.mainscenebutton.event.MainSceneButtonEventCenter"
local GiftEventCenter = require "amf.feature.giftpackage.event.GiftEventCenter"
local LuckyDeliveryEvent = require "amf.feature.localactivity.luckydelivery.event.LuckyDeliveryEvent"
local LuckyDeliveryEventCenter = require "amf.feature.localactivity.luckydelivery.event.LuckyDeliveryEventCenter"
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local deferred = require "amf.script.sugar.deferred"

local LuckyDeliveryPassManager = class("LuckyDeliveryPassManager", BaseFeatureManager)

local PASS_GIFT_MODULE_NAME = "luckyExpressPass"

function LuckyDeliveryPassManager:_init()
    self:registerEvents()
    self:initActInfo()
end

function LuckyDeliveryPassManager:_getConstPath()
    return "amf.feature.localactivity.luckydeliverypass.config.LuckyDeliveryPassConst"
end

function LuckyDeliveryPassManager:_getModelPath()
    return "amf.feature.localactivity.luckydeliverypass.model.LuckyDeliveryPassModel"
end

function LuckyDeliveryPassManager:_getExtraPlugsConfigList()
    return {
        {
            key = "Panel",
        },
        {
            key = "AutoPop",
        },
        {
            key = "DC",
            path = {
                plugPath = "amf.feature.localactivity.luckydeliverypass.dc.LuckyDeliveryPassDC",
            }
        },
    }
end

function LuckyDeliveryPassManager:dcPlug()
    return self:_getPlug("DC")
end

function LuckyDeliveryPassManager:isEnabled()
    return self:getModel():isDataEnabled() and self:isActValid()
end

function LuckyDeliveryPassManager:isActValid()
    return self:getModel():isInMainTime() or self:getModel():isInRewardTime()
end

function LuckyDeliveryPassManager:registerEvents()
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
    LuckyDeliveryEventCenter:register(LuckyDeliveryEvent.TASK_FINISHED, self.onLuckyDeliveryTaskFinished, self)
end

function LuckyDeliveryPassManager:initActInfo()
    if not self.actPlug then return end

    local actInfo = self.actPlug:getActInfo()
    self:getModel():syncActInfo(actInfo)
end

function LuckyDeliveryPassManager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(self:getConst().ACT_ID)]

    if fromServer and not actInfo then
        self:getModel():reset()
    elseif fromServer and actInfo then
        self:getModel():syncActInfo(actInfo)
        MainSceneButtonEventCenter:dispatch(MainSceneButtonEvent.UPDATE)
    end
end

function LuckyDeliveryPassManager:getLocalCache(key, needTime)
    return self:getModel():getLocalCache(key, needTime)
end

function LuckyDeliveryPassManager:setLocalCache(key, needTime, value)
    self:getModel():setLocalCache(key, needTime, value)
end

function LuckyDeliveryPassManager:tryDcQualify()
    if not self:isEnabled() then return end

    local key = self:getConst().DCKey.QUALIFY_DAILY
    if self:getLocalCache(key, true) then return end
    self:setLocalCache(key, true, true)

    self:dcPlug():dcQualify()
end

function LuckyDeliveryPassManager:tryDcJoin()
    if not self:isEnabled() then return end

    local key = self:getConst().DCKey.JOIN_DAILY
    if self:getLocalCache(key, true) then return end
    self:setLocalCache(key, true, true)

    self:dcPlug():dcJoin()
end

function LuckyDeliveryPassManager:onLuckyDeliveryTaskFinished(event)
    if not self:isEnabled() then return end
    local taskInfo = event:getData()
    local taskIndex = taskInfo and taskInfo.taskId
    self:dcPlug():dcTaskSuccess(taskIndex)
end

function LuckyDeliveryPassManager:onActPassDay()
    if self:getObserverNum() > 0 then
        self:notify("CloseAllPanel")
    end

    BaseFeatureManager.onActPassDay(self)
    MainSceneButtonEventCenter:dispatch(MainSceneButtonEvent.UPDATE)
end

function LuckyDeliveryPassManager:passDayRefreshData()
    if self:hasReward() then
        self:getModel():setDataByKey("hasCompensateReward", true)
    end
end

function LuckyDeliveryPassManager:setAutoPopupMgr(manager)
    self.autoPopupMgr = manager
end

function LuckyDeliveryPassManager:_getAutoPopConfigList()
    local PCP = _G.PopupCheckPoint
    local PopStage = AutoPopupConst.PopStage

    return {
        {
            checkPoint = PCP.LUCKY_DELIVERY_PASS_COMPENSATE,
            stages     = { PopStage.STAGE_TWO, PopStage.STAGE_FOUR },
            check      = function()
                if not _G.amfBean("LuckyDeliveryManager"):isResReady() then
                    return false
                end

                if self:_isCompensateRewardPeriodPopup() then
                    return true
                end

                local dailyKey = self:_getCompensateFormalDailyKey()
                return dailyKey and (self:getModel():getLocalCache(dailyKey, true) or 0) < 1
            end,
            creator    = function(_, onPopOver)
                return function()
                    local rewardPeriodPopup = self:_isCompensateRewardPeriodPopup()
                    local dailyKey = self:_getCompensateFormalDailyKey()
                    if not rewardPeriodPopup and not dailyKey then
                        safeRunCall(onPopOver)
                        return
                    end

                    if dailyKey and (self:getModel():getLocalCache(dailyKey, true) or 0) >= 1 then
                        safeRunCall(onPopOver)
                        return
                    end

                    if dailyKey then
                        self:getModel():setLocalCache(dailyKey, true, 1)
                    end
                    self:openMainPanel(onPopOver)
                end
            end,
        },
    }
end

function LuckyDeliveryPassManager:_isCompensateRewardPeriodPopup()
    return self:hasReward() and self:getModel():isInRewardTime()
end

function LuckyDeliveryPassManager:_getCompensateFormalDailyKey()
    if not self:hasReward() then return end
    if self:getModel():isInRewardTime() then return end
    if not self:isEnabled() then return end
    local compensateKey = self:getConst().CompensateKey
    if self:hasVip() then return compensateKey.HAS_VIP_DAILY end
    return compensateKey.NO_VIP_DAILY
end

function LuckyDeliveryPassManager:openMainPanel(closeCallback, userClick)
    if self._isOpeningMainPanel then
        safeRunCall(closeCallback)
        return
    end

    local isInRewardTime = self:getModel():isInRewardTime()
    if self:hasCompensateReward() then
        self:receiveCompensateReward(function()
            if isInRewardTime then
                safeRunCall(closeCallback)
            else
                self:openMainPanel(closeCallback, userClick)
            end
        end, function()
            CommonTip:showTip("网络异常，请检查网络~")
            safeRunCall(closeCallback)
        end)
        return
    end

    if isInRewardTime then
        safeRunCall(closeCallback)
        return
    end

    if not _G.amfBean("LuckyDeliveryManager"):isResReady() then
        safeRunCall(closeCallback)
        return
    end

    self._isOpeningMainPanel = true
    self:getModel():requestMainInfo():next(function()
        if self:hasVip() then
            self._isOpeningMainPanel = false
            self:_showMainPanel(closeCallback, userClick)
            return
        end

        self:requestPassPackage():next(function()
            self._isOpeningMainPanel = false
            self:_showMainPanel(closeCallback, userClick)
        end, function()
            self._isOpeningMainPanel = false
            CommonTip:showTip("网络异常，请检查网络~")
            safeRunCall(closeCallback)
        end)
    end, function()
        self._isOpeningMainPanel = false
        CommonTip:showTip("网络异常，请检查网络~")
        safeRunCall(closeCallback)
    end)
end

function LuckyDeliveryPassManager:_showMainPanel(closeCallback, userClick)
    local LuckyDeliveryPassMainPanelVM = require_debug "amf.feature.localactivity.luckydeliverypass.view.LuckyDeliveryPassMainPanelVM"
    local vm = LuckyDeliveryPassMainPanelVM:create({
        mgr = self,
        closeCallback = closeCallback,
        userClick = userClick,
        passPackageId = self._passPackageId,
    })
    vm:popout()
    self:callPanelFunc("managePanelVM", vm)
end

function LuckyDeliveryPassManager:dcMainPanelShow(userClick, panelId)
    self:dcPlug():dcMainPanelShow(
        userClick and "vine_icon" or "popoup",
        self:getTaskFinishedCount(),
        self:hasVip() and 1 or 0,
        panelId
    )
end

function LuckyDeliveryPassManager:dcReward(stageInfo, isPayReward, expressOpenResults, panelId)
    self:tryDcJoin()

    local stageId = stageInfo.stageId
    local openResult = expressOpenResults[1]

    local finalLevel = openResult.finalLevel 
    if openResult.splitNum > 1 then
        finalLevel = finalLevel .. "_" .. openResult.splitNum
    end

    local t1
    local t2
    if isPayReward then
        t2 = stageId
    else
        t1 = stageId
    end

    self:dcPlug():dcReward(
        t1,
        t2,
        openResult.initLevel,
        finalLevel,
        panelId
    )
end

function LuckyDeliveryPassManager:_formatRewardTimeRewardDay(day)
    local date = TimeUtil:getYMDByDayCount(day)
    return string.format("%04d%02d%02d", date.year, date.month, date.day)
end

function LuckyDeliveryPassManager:dcRewardTimeReward(expressOpenResults)
    local records = {}
    local rewardDays = {}

    for _, openResult in ipairs(expressOpenResults or {}) do
        local rewardType = openResult.vip and 2 or 1

        local finalLevel = openResult.finalLevel 
        if openResult.splitNum > 1 then
            finalLevel = finalLevel .. "_" .. openResult.splitNum
        end

        local record = table.concat({
            tostring(openResult.initLevel),
            tostring(finalLevel),
            tostring(rewardType),
        }, "~")

        table.insert(records, record)
        table.insert(rewardDays, self:_formatRewardTimeRewardDay(openResult.day))
    end

    self:dcPlug():dcRewardTimeReward(table.concat(records, ";"), table.concat(rewardDays, ";"))
end

function LuckyDeliveryPassManager:requestReward(stageId, vip)
    return self:getModel():requestReward(stageId, vip)
end

function LuckyDeliveryPassManager:requestMainInfo()
    return self:getModel():requestMainInfo()
end

function LuckyDeliveryPassManager:requestCompensateReward()
    return self:getModel():requestCompensateReward()
end

function LuckyDeliveryPassManager:requestPassPackage()
    local callbackPromise = deferred.new()
    local promise = callbackPromise:next(function(packages)
        local package = packages and packages[1]
        self._passPackageId = package and package:getGoodsId()

        if self._passPackageId and self:getPassPackagePrice() then
            return deferred.success()
        end

        return deferred.error()
    end)

    GiftEventCenter:dispatch(GiftEvent.PULL_ACTIVITY_PACKAGE, {
        actId = self:getConst().ACT_ID,
        moduleName = PASS_GIFT_MODULE_NAME,
        callbackPromise = callbackPromise,
        params = {
            moduleVersion = 1,
        },
    })

    return promise
end

function LuckyDeliveryPassManager:getPassPackagePrice()
    if not self._passPackageId then return end

    local goods = GoodsManager:getGoods(self._passPackageId)
    if not goods then return end
    local price = goods:getPrice(MoneyType.kRmb)
    if price and price > 0 then return price end
end

function LuckyDeliveryPassManager:requestBuyPassPackage(successCallback, failCallback, cancelCallback)
    if not self._passPackageId or not self:getPassPackagePrice() then
        safeRunCall(failCallback)
        return
    end

    local buyContext = BuyContext.new(self._passPackageId, MoneyType.kRmb)
        :setFeatureAndSource("lucky_express_permit", "permit")
        :setBuyCount(1)
        :setUnifiedBuy(true, GiftPackageConst.StageType.ACTIVITY, PASS_GIFT_MODULE_NAME)
        :setCallback(successCallback, failCallback, cancelCallback)
    _G.amfTransaction(TransactionEvent.PAY, buyContext)
end

function LuckyDeliveryPassManager:receiveCompensateReward(onComplete, onFail)
    if self._isReceivingCompensateReward then return end
    if not self:hasCompensateReward() then
        safeRunCall(onComplete)
        return
    end

    self._isReceivingCompensateReward = true
    self:requestCompensateReward():next(function(response)
        self._isReceivingCompensateReward = false
        self:refreshMainSceneButton()

        local data = response:getData() or {}
        self:dcRewardTimeReward(data.expressOpenResults)
        self:playExpressOpenResults(data.expressOpenResults, function()
            safeRunCall(onComplete)
        end, "rewardtime_reward")
    end, function(...)
        self._isReceivingCompensateReward = false
        safeRunCall(onFail, ...)
    end)
end

function LuckyDeliveryPassManager:getStageRewards()
    return self:getModel():getStageRewards()
end

function LuckyDeliveryPassManager:hasVip()
    return self:getModel():hasVip()
end

function LuckyDeliveryPassManager:hasCompensateReward()
    return self:getModel():hasCompensateReward()
end

function LuckyDeliveryPassManager:getMsgNum()
    return self:getModel():getMsgNum()
end

function LuckyDeliveryPassManager:hasReward()
    return self:getMsgNum() > 0
end

function LuckyDeliveryPassManager:canShowMainSceneEntry()
    if not self:isEnabled() then return false end
    if self:getModel():isInRewardTime() then return self:hasReward() end
    if not _G.amfBean("LuckyDeliveryManager"):isDayCompleted() then return true end
    return not self:hasVip() or self:hasReward()
end

function LuckyDeliveryPassManager:getTaskFinishedCount()
    return _G.amfBean("LuckyDeliveryManager"):getTaskFinishedCount()
end

function LuckyDeliveryPassManager:getCurrentTask()
    return _G.amfBean("LuckyDeliveryManager"):getCurrentTask()
end

function LuckyDeliveryPassManager:getTaskList()
    return _G.amfBean("LuckyDeliveryManager"):getModel():getTaskList()
end

function LuckyDeliveryPassManager:playExpressOpenResults(expressOpenResults, onComplete, source)
    if table.isEmpty(expressOpenResults) then
        safeRunCall(onComplete)
        return
    end

    source = source or "feedback_reward"

    LuckyDeliveryEventCenter:dispatch(LuckyDeliveryEvent.PLAY_EXPRESS_OPEN_RESULTS, {
        expressOpenResults = expressOpenResults,
        onComplete = onComplete,
        rewardContext = {
            cardRewardDc = {
                feature = "lucky_express_permit",
                source = source,
            },
            extraRewardDc = {
                feature = "lucky_express_permit",
                source = source,
            },
            linkageActId = self:getConst().ACT_ID,
        },
    })
end

function LuckyDeliveryPassManager:refreshMainSceneButton()
    MainSceneButtonEventCenter:dispatch(MainSceneButtonEvent.UPDATE)
end

return LuckyDeliveryPassManager
