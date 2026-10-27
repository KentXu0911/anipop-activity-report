local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local deferred = require "amf.script.sugar.deferred"
local EventCenter = require "amf.feature.desktopwidget.event.DesktopWidgetEventCenter"
local DesktopWidgetManager = class("DesktopWidgetManager", BaseFeatureManager)

function DesktopWidgetManager:ctor()
    self._activityMgr = nil
    self._levelUnLockManager = nil
    self._autoPopupMgr = nil
    self._profileManager = nil
    self._popoutManager = nil
    self._retryGetTime = 0
end

function DesktopWidgetManager:setActivityMgr(mgr)
    self._activityMgr = mgr
end

function DesktopWidgetManager:setLevelUnLockManager(mgr)
    self._levelUnLockManager = mgr
end

function DesktopWidgetManager:setAutoPopupMgr(mgr)
    self._autoPopupMgr = mgr
end

function DesktopWidgetManager:setProfileManager(mgr)
    self._profileManager = mgr
end

function DesktopWidgetManager:setPopoutManager(mgr)
	self._popoutManager = mgr
end

function DesktopWidgetManager:printLog(...)
    -- if EnvUtil:isDevelopMode() then
    --     printx(36,"DesktopWidgetManager:", ...)
    -- end
end

-- 获取常量路径
function DesktopWidgetManager:_getConstPath()
    return "amf.feature.desktopwidget.config.DesktopWidgetConst"
end

-- 获取model路径
function DesktopWidgetManager:_getModelPath()
    return "amf.feature.desktopwidget.model.DesktopWidgetModel"
end

function DesktopWidgetManager:_getExtraPlugsConfigList()
    return {
        {
            key = "Panel",
        },
		{
			key = "Rewards",
		},
    }
end

function DesktopWidgetManager:_init()
    self:initDelegate()
    if not self.delegate then
        self:printLog("WidgetUtilsBridge is nil")
        return
    end

    self:registerPromoteDailyEvent()
    self:registerOpenShareLogic()
end

-- 实际接入delegate
function DesktopWidgetManager:initDelegate()
end

function DesktopWidgetManager:registerPromoteDailyEvent()
    local PromoteDailyEventCenter = require "amf.feature.dailyreward.promotedaily.event.PromoteDailyEventCenter"
    PromoteDailyEventCenter:register(PromoteDailyEvent.ADD_PASS_COUNT_BY_LEVEL, function(...)
        self:onPromoteDailyUpdate(...)
    end)
end

function DesktopWidgetManager:registerOpenShareLogic()
    local OpenShareEventCenter = require "amf.middleware.share.openshare.event.OpenShareEventCenter"
    OpenShareEventCenter:register(OpenShareEvent.PARSE_URL_TABLE, function(...)
        self:onOpenShareParseUrl(...)
    end)
end

function DesktopWidgetManager:onOpenShareParseUrl(evt)
    local data = evt:getData()
    if not data then return end
    local method = data.method
    if not method or method ~= "launchapp" then return end
    local para = data.query or {}
	if not para.from or not string.find(para.from, "widget") then return end

    self:onEnterGameFromWidget()
    _G.amfEC:notifyFeature(FeatureEvent.ENTER_FROM_WIDGET, {
        from = para.from,
        activity = para.activity,
    })

    -- 不走默认解析
    safeRunCall(data.callback, {})
end

function DesktopWidgetManager:onActPlayLevelEnd(event)
    if not self:isEnabled() then return end
    local today = time2day(TimeKit:timeInSec())
    local key = self:getConst().GuideKey.PASS_LEVEL
    if not self:getModel():checkGuide(key, today) then
        self:getModel():addGuide(key, today)
        self:reloadWidget(true, 3)
    end

end

function DesktopWidgetManager:onPromoteDailyUpdate()
    if not self:isEnabled() then return end
    local promoteDailyMgr = _G.amfBean("PromoteDailyMgr")
    local key = self:getConst().GuideKey.DAILY_SIGN
    local today = time2day(TimeKit:timeInSec())
    if promoteDailyMgr:getTodaySignState() == PromoteDailyConst.SignState.SIGN
        and not self:getModel():checkGuide(key, today) then
            self:getModel():addGuide(key, today)
            self:reloadWidget(true, 3)
    end
end

function DesktopWidgetManager:callDelegate(funcName, ...)
    self:printLog("callDelegate", funcName, ...)
    if not self.delegate or not self.delegate[funcName] then return end
    local ret = self.delegate[funcName](self.delegate, ...)
    -- printx(36, "callDelegate", funcName, tts(ret))
    return ret
end

function DesktopWidgetManager:syncWidgetData()
    if not self:isEnabled() then return end
    self:updateXxlId()

    local dynamicHost = AMFNetworkConfig:getDynamicHost()
    if dynamicHost then
        -- 如果dynamicHost以http:开头，则替换成https:
        if string.starts(dynamicHost, "http:") then
            dynamicHost = string.gsub(dynamicHost, "http:", "https:")
        end
        self:setDynamicHost(dynamicHost)
    end
end

function DesktopWidgetManager:setDynamicHost(url)
    if not self:isEnabled() then return end
    self:callDelegate("setString", self:getConst().WidgetSharedDataKey.DYNAMIC_HOST, url)
end

function DesktopWidgetManager:updateXxlId()
    local key = self:getModel():getWidgetEncryptionKey()
    if key ~= "" then
        local xxlId = self._profileManager:getXxlId()
        key = string.format("_____%s_", xxlId) .. key
        self:setXxlId(key)
        -- printx(36, "DesktopWidgetManager:syncWidgetData key=", key, "xxlId=", xxlId)
    end
end

function DesktopWidgetManager:reloadWidget(bLevel, delay)
    if bLevel then
        local nowTime = TimeKit:timeInSec()
        if self._lastReloadTime and nowTime - self._lastReloadTime < 5 then return end
        self._lastReloadTime = nowTime
    end

    TimerUtil.addAlarm(function()
        self:callDelegate("reloadWidget")
    end, delay or 0)
end

-- 是否安装
function DesktopWidgetManager:isWidgetInstall()
    if not self:isEnabled() then return end
    return self:callDelegate("getBool", self:getConst().WidgetSharedDataKey.WIDGET_INSTALL)
end


-- 清除安装记录
function DesktopWidgetManager:clearWidgetInstallRecords()
    if not self:isEnabled() then return end
    return self:callDelegate("removeValue", self:getConst().WidgetSharedDataKey.WIDGET_INSTALL)
end


-- 是否安装打点
function DesktopWidgetManager:isWidgetInstallDcReported()
    if not self:isEnabled() then return end
    local uid = _G.amfBean("UserManager"):getUid()
    return self:callDelegate("getBool", self:getConst().WidgetSharedDataKey.INSTALL_DC .. uid)
end

-- 清除安装打点
function DesktopWidgetManager:clearWidgetInstallDcRecords()
    if not self:isEnabled() then return end
    return self:callDelegate("removeValue", self:getConst().WidgetSharedDataKey.INSTALL_DC)
end

-- 安装打点时候，修改打点状态
function DesktopWidgetManager:onWidgetInstallDcReported()
    if not self:isEnabled() then return end
    local uid = _G.amfBean("UserManager"):getUid()
    self:callDelegate("setBool", self:getConst().WidgetSharedDataKey.INSTALL_DC .. uid, true)
    self:dc("dcInstallSuccess")
end

-- 是否支持Widget
function DesktopWidgetManager:isWidgetSupported()
    if self._widgetSupported == nil then
        self._widgetSupported = self:callDelegate("isWidgetSupported")
    end
    return self._widgetSupported
end

function DesktopWidgetManager:setXxlId(id)
    if not self:isEnabled() then return end
    self:callDelegate("setString", self:getConst().WidgetSharedDataKey.KXXXL_ID, id)
end

function DesktopWidgetManager:isActEnabled()
    if not self:isEnabled() then return end
    if not self._activityMgr then
        self:setActivityMgr(_G.amfBean("ActivityMgr"))
    end
    if not self._activityMgr:getActInfo(self:getConst().actId) then return end
    if not self:getModel():isActDataEnabled() then return end
    if not self:getModel():isInActivityTime() then return end

    return true
end

function DesktopWidgetManager:requestInstallActMainRequest(params, noLoading)
    local bFirst = not self:getModel():getTempData("_fromServer")
    local trigger = self:checkTrigger()
    local bFromWidget = self._launchFromWidget
    self._launchFromWidget = nil

    local request = self:getModel():requestInstallActMainRequest({
        installWidget = self:isWidgetInstall(),
        loginFromWidget = bFromWidget,
        trigger = params.trigger,
    }, noLoading)

    request:next(function()
        if bFirst or (not trigger and params.trigger) then
            self:updateIconTime()
        end

        if bFromWidget then
            EventCenter:dispatch(_G.DesktopWidgetEvent.ENTER_FROM_WIDGET)
        end
    end)

    return request
end

function DesktopWidgetManager:onEnterGameFromWidget()
    self:dc("dcGameEnter")

    if not self:checkMainPanelVM() then
        self._launchFromWidget = true
    else
        self:getModel():requestInstallActMainRequest({
            loginFromWidget = true,
            installWidget = true,
            trigger = false,
        }):next(function()
            self:updateIconTime()
            EventCenter:dispatch(_G.DesktopWidgetEvent.ENTER_FROM_WIDGET)
        end)
    end
end

function DesktopWidgetManager:setMainPanelVM(bool)
    self._showMainPanel = bool
end

function DesktopWidgetManager:checkMainPanelVM()
    return self._showMainPanel
end

function DesktopWidgetManager:requestInstallActGetReward(params, noLoading)
    if not self:isActEnabled() then return deferred.error() end
    local d = deferred.new()
    self:getModel():requestInstallActGetReward(params, noLoading)
    :next(function(resp)
        local data = resp:getData()
        local rewards = data.rewards
        if rewards then
            self:callPlug("Rewards", "addRewardsNormal", rewards, params)
        end
        self:dcAct("dcReward", params.index)
        self:updateIconTime()
        d:resolve(rewards)
    end, function(resp)
        if not resp:isCancel() then
            CommonTip:showErrorTip(resp)
        end
        d:reject()
    end)
    return d
end

function DesktopWidgetManager:isEnabled()
    return self:isWidgetSupported()
end

function DesktopWidgetManager:hasReward()
    if not self:isActEnabled() then return false end
    if not self:checkTrigger() then return false end

    local bReward = false
    if self:getModel():getCanGetRewardNum() > table.length(self:getModel():getHasGetRewardList())
        or (self._launchFromWidget and not self:checkHaveEnterFromWidget()) then
        bReward = true
    end
    return bReward
end

function DesktopWidgetManager:setActTime(timeConfig)
    self:getModel():setActTime(timeConfig)
end

function DesktopWidgetManager:isGetAllReward()
    return self:getModel():isGetAllReward()
end

function DesktopWidgetManager:showGuidePanel(params)
    params = params or {}
    local d = deferred.new()

    local VM = require "amf.feature.desktopwidget.view.WidgetGuidePanelVM"
    local vm = VM:create(params)
    vm:setCloseCallback(function()
        d:resolve()
    end)
    vm:popout()
    self:callPlug("Panel","managePanelVM", vm)

    return d
end

function DesktopWidgetManager:checkHaveEnterFromWidget(day)
    if not self:isActEnabled() then return false end
    day = day or time2day(TimeKit:timeInSec())
    return self:getModel():checkHaveEnterFromWidget(day)
end

-- 场景2
function DesktopWidgetManager:onActEnterStage2(evt)
    self:tryDcInstall()
    self:tryRequestGetWidgetEncryptionKey():next(function()
        self:syncWidgetData()
        self:reloadWidget(false, 1)
    end)

    local data = evt and evt:getData()
    local today = time2day(TimeKit:timeInSec())
    if data and data.isFirstEnter then
        self:updateXxlId()
        self:trySync(today)
    end

    if self._levelUnLockManager:isInNewLevelTime() then
        return
    end

    if not self._autoPopupMgr:isInMainScene() then
        return
    end

    if self._popoutManager:haveWindowOnScreenWithoutCommonTip() then
        return
    end

	self:checkPopAct(today)
end

function DesktopWidgetManager:tryDcInstall()
    if self:isWidgetInstall() and not self:isWidgetInstallDcReported() then
        self:onWidgetInstallDcReported()
    end
end

function DesktopWidgetManager:trySync(today)
    if not self:isEnabled() then return end

    local key = self:getConst().GuideKey.SYNC
    if not self:getModel():checkGuide(key, today) then
        self:getModel():addGuide(key, today)
        self:reloadWidget(false, 10)
    end
end

function DesktopWidgetManager:checkPopAct(today)
    if not self:isActEnabled() or self:checkMainPanelVM() then return end
    today = today or time2day(TimeKit:timeInSec())
    local model = self:getModel()

    local guideKey = self:getConst().GuideKey
    local guideId = self:getConst().GuideId

    local canPop
    if not self:hasGuideIndex(guideId.TRIGGER)then
        local trigger = self:checkTrigger()
        if trigger then
            self:addGuideIndex(guideId.TRIGGER)
        else
            canPop = guideId.TRIGGER
        end
    end

    -- 第二、三天未安装且未点击，强弹
    if not canPop and not self:isWidgetInstall()
        and not model:checkGuide(guideKey.DAILY_PANEL_OPEN, today) then
        local triggerDay = time2day(model:getTriggerTime())
        local delta = today - triggerDay
        if delta == 1 or delta == 2 and not self:hasGuideIndex(delta + 1) then
            canPop = delta + 1
        end
    end

    -- 当日有奖
    if not canPop and not model:checkGuide(guideKey.DAILY_PANEL_REWARD, today) then
        local todayIndex = self:checkHaveEnterFromWidget()
        if not todayIndex then
            todayIndex = self._launchFromWidget and (model:getLoginTimeListFromWidgetLength() + 1)
        end
        if todayIndex and not table.indexOf(self:getModel():getHasGetRewardList(), todayIndex)
            and not self:hasGuideIndex(todayIndex + 10) then
            canPop = todayIndex + 10
        end
    end
    if not canPop then return end

    local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.WIDGET_REWARD_ACT)
	end

	local function creator()
        self:addGuideIndex(canPop)

        self:callActFunc("openActivity", {
            failCallback = onHandleOver,
            endCallback = onHandleOver,
            extra = {
                from = 3
            },
            userClick = true,
        })
	end
    self._autoPopupMgr:addPopupConfig(PopupCheckPoint.WIDGET_REWARD_ACT, creator)
    return true
end

function DesktopWidgetManager:onActEnterStage4(evt)
    self:checkPopAct()
end

function DesktopWidgetManager:checkTrigger()
    local triggerTime = self:getModel():getTriggerTime()
    return triggerTime > 0
end

function DesktopWidgetManager:getTriggerEndTime()
    return self:getModel():getTriggerEndTime()
end

function DesktopWidgetManager:dcAct(funcName, ...)
    if not self._dcAct then
        self._dcAct = require("amf.feature.desktopwidget.dc.WidgetRewardDC")
    end

    self._dcAct[funcName](self._dcAct, ...)
end

function DesktopWidgetManager:dc(funcName, ...)
    if not self._dc then
        self._dc = require("amf.feature.desktopwidget.dc.DesktopWidgetDC")
    end

    self._dc[funcName](self._dc, ...)
end

function DesktopWidgetManager:tryRequestGetWidgetEncryptionKey()
    if not self:isEnabled() or self._retryGetTime > 2 then return deferred.error() end
    if self._getEncryptionKeySuccess then return deferred.error() end
    self._retryGetTime = self._retryGetTime + 1
    local d = deferred.new()
    self:getModel():requestGetWidgetEncryptionKey():next(function()
        self._getEncryptionKeySuccess = true
        d:resolve()
    end, function()
        d:reject()
    end)
    return d
end

-- 检测引导标记
function DesktopWidgetManager:hasGuideIndex(index)
    return self:getModel():hasGuide(index)
end

-- 设置引导标记
function DesktopWidgetManager:addGuideIndex(index)
    self:getModel():setGuide(index)

    local ActCommonHttp = require 'amf.middleware.activity.http.ActCommonHttp'
    ActCommonHttp:setActGuideFlag(self:getConst().actId, index)
end

function DesktopWidgetManager:updateIconTime()
    if not self:isActEnabled() then return end
    self:callPlug("Act", "updateTipView")
    local icon = self:callPlug("Act", "getActIcon")
    if isSafeCocosObj(icon) and type(icon.refreshProvider) ~= "function" then
        icon:updateTime()
    end
end

return DesktopWidgetManager
