local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local PackageIconV2Host = require "amf.feature.mainscene.module.icon.v2.runtime.PackageIconV2Host"
local AliPayDesktopShortcutModel = require "amf.feature.minihub.alipaydesktopshortcut.model.AliPayDesktopShortcutModel"
local AliPayDesktopShortcutDC = require "amf.feature.minihub.alipaydesktopshortcut.dc.AliPayDesktopShortcutDC"

local AliPayDesktopShortcutManager = class("AliPayDesktopShortcutManager")

AliPayDesktopShortcutManager.FEATURE_NAME = "alipay_desktop_shortcut"
AliPayDesktopShortcutManager.ICON_KEY = "alipay_desktop_shortcut"
AliPayDesktopShortcutManager.ICON_LABEL = "桌面有礼"
AliPayDesktopShortcutManager.ICON_RES_PATH = "amf/alipaydesktopshortcut/icon/icon.png"
AliPayDesktopShortcutManager.ICON_V2_RES_PATH = "amf/alipaydesktopshortcut/icon/icon_v2.png"
AliPayDesktopShortcutManager.MAINTENANCE_KEY = "alipay_add_desk"
-- 支付宝小游戏桌面有礼：首次登录强弹标记
AliPayDesktopShortcutManager.FIRST_LOGIN_AUTO_POP_CACHE_KEY = "firstLoginAutoPopupDone"
-- 支付宝小游戏桌面有礼：断连胜强弹标记
AliPayDesktopShortcutManager.STREAK_BREAK_AUTO_POP_CACHE_KEY = "streakBreakAutoPopupDone"
AliPayDesktopShortcutManager.ICON_EXPOSE_DAY_CACHE_KEY = "iconExposeDay"
AliPayDesktopShortcutManager.ADD_SHORTCUT_TIMEOUT_SECONDS = 8
AliPayDesktopShortcutManager.OPEN_PANEL_TIMEOUT_SECONDS = 10
AliPayDesktopShortcutManager.CLIENT_VERSION = 1
AliPayDesktopShortcutManager.TEST_FORCE_SHOW_ON_NON_ALIPAY = false
-- 临时关闭 SDK 接口能力与版本拦截，确保支付宝端均可展示入口。
AliPayDesktopShortcutManager.DISABLE_SDK_INTERFACE_GUARD = true
local REPORT_CUSTOM_EVENT_METHOD = "globalThis.animalPlugin.sdkManager.reportCustomEvent"
local ICON_V2_EXPERIMENT_MODULE = "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"

AliPayDesktopShortcutManager.MAIN_INFO_SHUTDOWN_ERROR_CODES = {
    [739462] = true,
    [739466] = true,
}

local DisableReason = {
    NOT_MINI_GAME = "not_mini_game",
    NOT_ALIPAY = "not_alipay",
    SWITCH_OFF = "switch_off",
    LOW_VERSION = "low_version",
    SHUTDOWN = "shutdown",
}

local ErrorCode = {
    NOT_READY = "not_ready",
    NOT_CAN_REWARD = "not_can_reward",
    ADD_SHORTCUT_BUSY = "add_shortcut_busy",
    UNSUPPORTED = "unsupported",
    REQUEST_UNAVAILABLE = "request_unavailable",
    MAIN_INFO_ERROR = "main_info_error",
    OPEN_PANEL_TIMEOUT = "panel_open_timeout",
}

local MainInfoReason = {
    ICON_OPEN = "icon_open",
    ASYNC_SYNC = "async_sync",
}

local OpenPanelFailTip = {
    [DisableReason.NOT_MINI_GAME] = "当前环境暂不支持该活动",
    [DisableReason.NOT_ALIPAY] = "请在支付宝小游戏内参与活动",
    [DisableReason.SWITCH_OFF] = "活动暂未开启，请稍后再试",
    [DisableReason.LOW_VERSION] = "支付宝版本过低，请先升级支付宝哦",
    [DisableReason.SHUTDOWN] = "活动暂未开启，请稍后再试",
    [ErrorCode.NOT_READY] = "活动数据加载中，请稍后再试",
    [ErrorCode.REQUEST_UNAVAILABLE] = "网络连接失败，请稍后重试",
    panel_create_failed = "活动面板加载失败，请稍后再试",
    panel_popout_failed = "活动面板打开失败，请稍后再试",
    panel_res_load_failed = "资源加载失败，请稍后重试",
    [ErrorCode.OPEN_PANEL_TIMEOUT] = "活动面板打开超时，请稍后重试",
    panel_factory_empty = "活动面板加载失败，请稍后再试",
    default = "活动暂时无法打开，请稍后再试",
}

local function callIfExists(target, funcName, ...)
    if target and target[funcName] then
        return target[funcName](target, ...)
    end
end

local function asTimeInSec(value, defaultValue)
    local time = tonumber(value)
    if not time then
        return defaultValue
    end
    if TimeKit and TimeKit.tryConvertMsToSec then
        return TimeKit:tryConvertMsToSec(time) or defaultValue
    end
    if time > 1e11 then
        return math.floor(time / 1000)
    end
    return time
end

local function getCurrentTime()
    if TimeKit and TimeKit.timeInSec then
        return TimeKit:timeInSec()
    end
    return os.time()
end

local function getCurrentDayStartTime()
    local currentTime = getCurrentTime()
    if TimeKit and TimeKit.getDayStartTimeByTS then
        return TimeKit:getDayStartTimeByTS(currentTime)
    end

    local date = os.date("*t", currentTime)
    if not date then
        return 0
    end
    date.hour = 0
    date.min = 0
    date.sec = 0
    return os.time(date)
end

local function getLaunchSourceTime(source)
    if type(source) == "table" then
        return asTimeInSec(source.launchTime or source.time or source.timestamp or source.ts or source.serverTime, getCurrentTime())
    end
    return asTimeInSec(source, getCurrentTime())
end

function AliPayDesktopShortcutManager:ctor()
    self.iconHost = PackageIconV2Host:create({
        owner = self,
        ownerIconKey = self.ICON_KEY,
        iconEventCenter = IconEventCenter,
        isEligible = function()
            return self:getIconState().visible == true
        end,
        isV2Enabled = function()
            return self:isV2IconExperimentEnabled()
        end,
        prepareLegacyAssets = function()
            return _G.amfBean("AssetsUtil"):loadMiniFiles({self.ICON_RES_PATH})
        end,
        prepareV2Assets = function()
            return _G.amfBean("AssetsUtil"):loadMiniFiles({self.ICON_V2_RES_PATH})
        end,
        createV2Options = function()
            local IconV2Config = require "amf.feature.minihub.alipaydesktopshortcut.icon.IconV2Config"
            return IconV2Config:create(self, IconEventCenter)
        end,
        createLegacyIcon = function()
            return self:createLegacyIcon()
        end,
        refreshLegacy = function(icon, reason)
            icon:updateState(reason)
            return true
        end,
        onActivated = function()
            self:sendIconExposeOncePerDay()
        end,
        preflightErrorPrefix = "ALIPAY_DESKTOP_SHORTCUT_V2_ASSET_LOAD_FAILED:",
        logError = function(stage, detail)
            if ALog and type(ALog.strict_log_error) == "function" then
                ALog.strict_log_error(
                    "[AliPayDesktopShortcutIconV2] " .. tostring(stage) .. ":" .. tostring(detail)
                )
            end
        end,
    })
end

function AliPayDesktopShortcutManager:initialize()
    if not self._platformProxy then
        self._platformProxy = self:_createPlatformProxy()
    end

    local supportState = self:checkPlatformSupport()
    self._platformUnsupported = supportState.supported ~= true
        and not (self:isSdkInterfaceGuardDisabled() and supportState.isAlipayMiniGame == true)
        and not self:isTestForceShowOnNonAlipay()
    if self._platformUnsupported then
        return false
    end

    if not self._model then
        self._model = AliPayDesktopShortcutModel:create(AliPayDesktopShortcutManager.FEATURE_NAME)
    end
    if not self._dc then
        self._dc = AliPayDesktopShortcutDC:create(self)
    end
    callIfExists(self._platformProxy, "initialize")
    self._isDesktopShortcutEntry = false
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)
    self._initialized = true
    self:_registerAutoPopup()
    return true
end

function AliPayDesktopShortcutManager:setAutoPopupMgr(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
    if self._initialized then
        self:_registerAutoPopup()
    end
end

function AliPayDesktopShortcutManager:setModel(model)
    self._model = model
end

function AliPayDesktopShortcutManager:setPlatformProxy(platformProxy)
    self._platformProxy = platformProxy
end

function AliPayDesktopShortcutManager:setPanelFactory(panelFactory)
    self._panelFactory = panelFactory
end

function AliPayDesktopShortcutManager:getFeatureName()
    return AliPayDesktopShortcutManager.FEATURE_NAME
end

function AliPayDesktopShortcutManager:getModel()
    return self._model
end

function AliPayDesktopShortcutManager:getPlatformProxy()
    return self._platformProxy
end

function AliPayDesktopShortcutManager:getDC()
    if not self._dc then
        self._dc = AliPayDesktopShortcutDC:create(self)
    end
    return self._dc
end

function AliPayDesktopShortcutManager:sendDC(methodName, payload)
    local dc = self:getDC()
    if dc and methodName and dc[methodName] then
        return dc[methodName](dc, payload)
    end
    return false
end

function AliPayDesktopShortcutManager:reportAlipayCustomEvent(eventName)
    if not _G.isBundleVersionGreaterOrEqual("1.161.2") then return end
    if not eventName
        or not self:isAlipayMiniGame()
        or type(CALL_EASY_JS) ~= "function"
    then
        return false
    end

    local ok = pcall(CALL_EASY_JS, REPORT_CUSTOM_EVENT_METHOD, eventName)
    -- if ok and CommonTip and CommonTip.showTip then
    --     CommonTip:showTip("CustomEvent: " .. tostring(eventName))
    -- end
    return ok == true
end

function AliPayDesktopShortcutManager:getIconResPath()
    return AliPayDesktopShortcutManager.ICON_RES_PATH
end

function AliPayDesktopShortcutManager:isV2IconExperimentEnabled()
    if EnvUtil:isUnityEditor() then
        return true
    end
    local experiment = require(ICON_V2_EXPERIMENT_MODULE)
    return experiment:isEnabled()
end

function AliPayDesktopShortcutManager:checkPlatformSupport()
    local supportState = callIfExists(self._platformProxy, "getSupportState")
    if supportState then
        return supportState
    end
    return {
        supported = false,
        lowVersion = false,
        apiAvailable = false,
        isAlipayMiniGame = false,
        reason = ErrorCode.UNSUPPORTED,
    }
end

function AliPayDesktopShortcutManager:getSupportState()
    return self:checkPlatformSupport()
end

function AliPayDesktopShortcutManager:addShortcut(callback)
    if self._addingShortcut then
        safeRunCall(callback, {
            ok = false,
            reason = ErrorCode.ADD_SHORTCUT_BUSY,
            code = ErrorCode.ADD_SHORTCUT_BUSY,
            supportState = self:checkPlatformSupport(),
        })
        return
    end

    self._addingShortcut = true
    local callbackDone = false
    local function finish(result)
        if callbackDone then
            return
        end
        callbackDone = true
        self._addingShortcut = false
        result = self:_normalizeAddShortcutResult(result)
        if result.action == "auth_guide" then
            self:notifyPanelRefresh(result.ok and "shortcut_auth_guide_ok" or "shortcut_auth_guide_fail")
        else
            self:notifyPanelRefresh(result.ok and "add_shortcut_ok" or "add_shortcut_fail")
        end
        safeRunCall(callback, result)
    end

    if setTimeOut then
        setTimeOut(function()
            finish({
                ok = false,
                reason = "timeout",
                code = "timeout",
                supportState = self:checkPlatformSupport(),
            })
        end, AliPayDesktopShortcutManager.ADD_SHORTCUT_TIMEOUT_SECONDS)
    end

    local proxy = self:getPlatformProxy()
    if proxy and proxy.addShortcut then
        proxy:addShortcut(finish)
    else
        finish({
            ok = false,
            reason = ErrorCode.UNSUPPORTED,
            code = ErrorCode.UNSUPPORTED,
            supportState = self:checkPlatformSupport(),
        })
    end
end

function AliPayDesktopShortcutManager:isAlipayMiniGame()
    return EnvUtil:isMiniGame()
        and EnvUtil:isALIPAYMiniGame()
end

function AliPayDesktopShortcutManager:setTestForceShowOnNonAlipay(enabled)
    AliPayDesktopShortcutManager.TEST_FORCE_SHOW_ON_NON_ALIPAY = enabled == true
    if self._initialized then
        if self:isTestForceShowOnNonAlipay() then
            self:requestAsyncMainInfo("test_force_show_switch")
        else
            self:shutdownFeature(DisableReason.NOT_ALIPAY)
        end
    end
end

function AliPayDesktopShortcutManager:isTestForceShowOnNonAlipay()
    return AliPayDesktopShortcutManager.TEST_FORCE_SHOW_ON_NON_ALIPAY == true
end

function AliPayDesktopShortcutManager:isSdkInterfaceGuardDisabled()
    return AliPayDesktopShortcutManager.DISABLE_SDK_INTERFACE_GUARD == true
end

function AliPayDesktopShortcutManager:isLowVersion()

    if not _G.isBundleVersionGreaterOrEqual("1.159.4") then
        return true
    end
    if self:isSdkInterfaceGuardDisabled() then
        return false
    end
    local lowVersion = callIfExists(self._platformProxy, "isLowVersion")
    if lowVersion ~= nil then
        return lowVersion == true
    end
    return false
end

function AliPayDesktopShortcutManager:isDataReady()
    local dataReady = callIfExists(self._model, "isDataReady")
    if dataReady ~= nil then
        return dataReady == true
    end
    return self._model ~= nil
end

function AliPayDesktopShortcutManager:isShutdown()
    if self._mainInfoShutdownErrorCode ~= nil then
        return true
    end
    local shutdown = callIfExists(self._platformProxy, "isShutdown")
    return shutdown == true
end

function AliPayDesktopShortcutManager:isEnabled()
    local result = self:canShowEntry()
    return result.enabled == true
end

function AliPayDesktopShortcutManager:isMaintenanceEnabled()
    return MaintenanceManager:getInstance():isEnabledInGroup(
        AliPayDesktopShortcutManager.MAINTENANCE_KEY,
        "ON"
    )
end

function AliPayDesktopShortcutManager:canShowEntry()
    if self._platformUnsupported then
        return { enabled = false, reason = ErrorCode.UNSUPPORTED }
    end
    if not self:isMaintenanceEnabled() then
        return { enabled = false, reason = DisableReason.SWITCH_OFF }
    end
    if self:isShutdown() then
        return { enabled = false, reason = DisableReason.SHUTDOWN }
    end
    if not EnvUtil:isMiniGame() then
        return { enabled = false, reason = DisableReason.NOT_MINI_GAME }
    end
    if not self:_canShowInCurrentPlatform() then
        return { enabled = false, reason = DisableReason.NOT_ALIPAY }
    end
    if self:isLowVersion() then
        return { enabled = false, reason = DisableReason.LOW_VERSION }
    end
    return { enabled = true }
end

function AliPayDesktopShortcutManager:onActEnterMainScene()
    if not self:_canShowInCurrentPlatform() then
        self:shutdownFeature(DisableReason.NOT_ALIPAY)
        return
    end
    self:requestAsyncMainInfo("enter_main_scene", function()
        self:refreshIcon("enter_main_scene")
        self:notifyPanelRefresh("enter_main_scene")
    end, function()
        self:refreshIcon("enter_main_scene_fail")
    end, {
        failOnUnavailable = true,
        hideOnMainInfoError = true,
    })
end

function AliPayDesktopShortcutManager:onSystemEnterForeground()
    if not self:_canShowInCurrentPlatform() then
        return
    end
    self:requestAsyncMainInfo()
end

function AliPayDesktopShortcutManager:_createAutoPopupCreator(onPopOver, cacheKey, checkPoint, requireStreakBreak)
    return function()
        local canPopup = self:_getAutoPopupState(cacheKey, requireStreakBreak)
        if not canPopup then
            onPopOver()
            return
        end
        self:markAutoPopupDone(cacheKey)
        self:openPanel("autopop", function()
            onPopOver()
        end)
    end
end

function AliPayDesktopShortcutManager:_registerFirstLoginAutoPopup(popStage)
    local firstLoginCheckPoint = PopupCheckPoint.ALIPAY_DESKTOP_SHORTCUT_FIRST_LOGIN
    self._autoPopupMgr:registerPopup({
        checkPoint = firstLoginCheckPoint,
        stages = { popStage.STAGE_TWO, popStage.STAGE_FOUR },
        check = function()
            local canPopup = self:_getAutoPopupState(
                AliPayDesktopShortcutManager.FIRST_LOGIN_AUTO_POP_CACHE_KEY,
                false
            )
            return canPopup
        end,
        creator = function(_, onPopOver)
            return self:_createAutoPopupCreator(
                onPopOver,
                AliPayDesktopShortcutManager.FIRST_LOGIN_AUTO_POP_CACHE_KEY,
                firstLoginCheckPoint,
                false
            )
        end,
    })
    return firstLoginCheckPoint
end

function AliPayDesktopShortcutManager:_registerStreakBreakAutoPopup(popStage)
    local streakBreakCheckPoint = PopupCheckPoint.ALIPAY_DESKTOP_SHORTCUT_STREAK_BREAK
    self._autoPopupMgr:registerPopup({
        checkPoint = streakBreakCheckPoint,
        stages = { popStage.STAGE_TWO, popStage.STAGE_FOUR },
        check = function()
            local canPopup = self:_getAutoPopupState(
                AliPayDesktopShortcutManager.STREAK_BREAK_AUTO_POP_CACHE_KEY,
                true
            )
            local firstLoginCanPopup = self:_getAutoPopupState(
                AliPayDesktopShortcutManager.FIRST_LOGIN_AUTO_POP_CACHE_KEY,
                false
            )
            local inCountdown = callIfExists(self._model, "isDeskTopVisitStreakBreak") == true
            canPopup = canPopup and not firstLoginCanPopup and inCountdown
            return canPopup
        end,
        creator = function(_, onPopOver)
            return self:_createAutoPopupCreator(
                onPopOver,
                AliPayDesktopShortcutManager.STREAK_BREAK_AUTO_POP_CACHE_KEY,
                streakBreakCheckPoint,
                true
            )
        end,
    })
    return streakBreakCheckPoint
end

function AliPayDesktopShortcutManager:_registerAutoPopup()
    if not self._autoPopupMgr then
        return
    end
    if not self._autoPopupMgr.registerPopup then
        return
    end
    if not PopupCheckPoint
        or not PopupCheckPoint.ALIPAY_DESKTOP_SHORTCUT_FIRST_LOGIN
        or not PopupCheckPoint.ALIPAY_DESKTOP_SHORTCUT_STREAK_BREAK
    then
        return
    end

    local popStage = AutoPopupConst.PopStage
    self:_registerFirstLoginAutoPopup(popStage)
    self:_registerStreakBreakAutoPopup(popStage)
end

function AliPayDesktopShortcutManager:onLaunchFromShortcut(source, successCallback, failCallback)
    if not source then
        safeRunCall(failCallback, {
            errorCode = ErrorCode.NOT_READY,
            errorMsg = ErrorCode.NOT_READY,
            needRefresh = false,
        })
        return
    end
    return self:_requestMainInfoFromDesktopSource(source, "launch_source", successCallback, failCallback)
end

function AliPayDesktopShortcutManager:requestAsyncMainInfo(reason, successCallback, failCallback, options)
    reason = reason or MainInfoReason.ASYNC_SYNC
    options = type(options) == "table" and options or {}
    local source = self:consumeLaunchSource()
    local requestOptions = table.clone(options)
    requestOptions.loading = false
    requestOptions.syncFrom = reason
    if source then
        return self:_requestMainInfoFromDesktopSource(source, reason, successCallback, failCallback, requestOptions)
    end

    local proxy = self:getPlatformProxy()
    if proxy and proxy.refreshLaunchSource then
        proxy:refreshLaunchSource(function(refreshSource)
            if refreshSource then
                self:_requestMainInfoFromDesktopSource(refreshSource, reason, successCallback, failCallback, requestOptions)
                return
            end
            self:_setDesktopShortcutEntry(nil)
            self:notifyPanelRefresh("desktop_entry_changed")
            self:requestMainInfo(reason, successCallback, failCallback, requestOptions)
        end, reason == "enter_main_scene")
        return nil
    end
    self:_setDesktopShortcutEntry(nil)
    self:notifyPanelRefresh("desktop_entry_changed")
    return self:requestMainInfo(reason, successCallback, failCallback, requestOptions)
end

function AliPayDesktopShortcutManager:_requestMainInfoFromDesktopSource(source, reason, successCallback, failCallback, options)
    options = type(options) == "table" and options or {}
    reason = reason or MainInfoReason.ASYNC_SYNC
    self:_markEnteredFromDesktopShortcut(source)
    self:notifyPanelRefresh("desktop_entry_changed")
    return self:requestMainInfo(reason, successCallback, failCallback, {
        loading = false,
        fromDesktop = true,
        launchSource = source,
        syncFrom = options.syncFrom or reason,
        failOnUnavailable = options.failOnUnavailable == true,
        hideOnMainInfoError = options.hideOnMainInfoError == true,
    })
end

function AliPayDesktopShortcutManager:onActPassDay()
    self:resetDailyState()
    self:closePanel("pass_day")
    CommonTip:showTip('新的一天开始了，数据已更新，\n请尝试重进活动~')
end

function AliPayDesktopShortcutManager:requestMainInfo(reason, successCallback, failCallback, options)
    options = type(options) == "table" and options or {}
    options.clientVersion = AliPayDesktopShortcutManager.CLIENT_VERSION
    if self._model and self._model.requestMainInfo then
        local request = self._model:requestMainInfo(reason, options)
        if request and request.next then
            request:next(function(response)
                self._mainInfoError = nil
                self:clearUnavailableState(reason)
                self:refreshIcon(reason)
                self:notifyPanelRefresh(reason)
                safeRunCall(successCallback, response)
            end, function(response)
                self:handleMainInfoError(response, reason)
                safeRunCall(failCallback, response)
            end)
            return request
        end
    end

    if options.failOnUnavailable then
        local errorResult = {
            errorCode = ErrorCode.REQUEST_UNAVAILABLE,
            errorMsg = ErrorCode.REQUEST_UNAVAILABLE,
            needRefresh = true,
        }
        if options.hideOnMainInfoError then
            self:handleMainInfoError(errorResult, reason)
        else
            self:refreshIcon(reason)
            self:notifyPanelRefresh(reason)
        end
        safeRunCall(failCallback, errorResult)
        return nil
    end
    self:refreshIcon(reason)
    self:notifyPanelRefresh(reason)
    safeRunCall(successCallback)
    return nil
end

function AliPayDesktopShortcutManager:markVisitFromShortcut(launchSource, successCallback, failCallback, syncFrom)
    if not launchSource then
        safeRunCall(failCallback, {
            errorCode = ErrorCode.NOT_READY,
            errorMsg = ErrorCode.NOT_READY,
            needRefresh = false,
        })
        return nil
    end

    return self:_requestMainInfoFromDesktopSource(launchSource, syncFrom or "icon_open", successCallback, failCallback, {
        failOnUnavailable = true,
    })
end

function AliPayDesktopShortcutManager:requestReward(params, successCallback, failCallback)
    if not self._model or not self._model.requestReward then
        local response = {
            errorCode = ErrorCode.NOT_READY,
            errorMsg = ErrorCode.NOT_READY,
            needRefresh = false,
        }
        safeRunCall(failCallback, response)
        return nil
    end

    local rewardItem = callIfExists(self._model, "getClaimableRewardItem", params)
    if not rewardItem then
        local response = {
            errorCode = ErrorCode.NOT_CAN_REWARD,
            errorMsg = ErrorCode.NOT_CAN_REWARD,
            needRefresh = false,
        }
        safeRunCall(failCallback, response)
        return nil
    end

    local request = self._model:requestReward(rewardItem)
    if request and request.next then
        request:next(function(response)
            local result = self:_buildRewardResult(response, rewardItem)
            callIfExists(self._model, "setRewardClaimed", rewardItem)
            self:_showReward(result.rewards)
            self:refreshIcon("request_reward")
            self:notifyPanelRefresh("request_reward")
            safeRunCall(successCallback, result)
        end, function(response)
            safeRunCall(failCallback, self:_buildErrorResult(response, true))
        end)
    else
        safeRunCall(failCallback, {
            errorCode = ErrorCode.REQUEST_UNAVAILABLE,
            errorMsg = ErrorCode.REQUEST_UNAVAILABLE,
            needRefresh = false,
        })
    end
    return request
end

function AliPayDesktopShortcutManager:consumeLaunchSource()
    return callIfExists(self._platformProxy, "consumeLaunchSource")
end

function AliPayDesktopShortcutManager:resetDailyState()
    callIfExists(self._model, "resetDailyState")
    callIfExists(self._platformProxy, "resetDailyState")
end

function AliPayDesktopShortcutManager:markAutoPopupDone(cacheKey)
    callIfExists(self._model, "setLocalCache", cacheKey, true, true)
end

function AliPayDesktopShortcutManager:shouldBlockStage2ForNewLevels()
    local userStateMgr = _G.amfBean("UserStateManager")
    local unlockMgr = _G.amfBean("LevelUnLockManager")

    -- 满级满星玩家不屏蔽
    if userStateMgr:getUserLevelState()
        == _G.UserStateConst.UserLevelState.TOP_STAR then
        return false
    end

    -- 当前最高可打关必须属于本次新发的30/45关
    local levelId = _G.getTopLevelId()
    if not unlockMgr:isTopNewMainLevel(levelId) then
        return false
    end

    -- 默认新关开放后的4小时
    return unlockMgr:isInNewLevelTime()
end

function AliPayDesktopShortcutManager:hasAutoPopupDone(cacheKey)
    return callIfExists(self._model, "getLocalCache", cacheKey) == true
end

function AliPayDesktopShortcutManager:sendIconExposeOncePerDay()
    local dayStartTime = getCurrentDayStartTime()
    if dayStartTime <= 0 then
        return false
    end

    local cacheKey = AliPayDesktopShortcutManager.ICON_EXPOSE_DAY_CACHE_KEY
    if tonumber(callIfExists(self._model, "getLocalCache", cacheKey)) == dayStartTime then
        return false
    end
    if self:sendDC("sendIconExpose") ~= true then
        return false
    end

    callIfExists(self._model, "setLocalCache", cacheKey, dayStartTime, true)
    return true
end

function AliPayDesktopShortcutManager:_getAutoPopupState(cacheKey, requireStreakBreak)
    requireStreakBreak = requireStreakBreak == true
    local gate = self:canShowEntry()
    local model = self:getModel()
    local newLevelBlock = self:shouldBlockStage2ForNewLevels()
    local state = {
        cacheKey = cacheKey,
        entryEnabled = gate.enabled == true,
        entryDisabledReason = gate.reason,
        mainInfoError = self._mainInfoError ~= nil and self._mainInfoError or false,
        popupDone = self:hasAutoPopupDone(cacheKey),
        hasModel = model ~= nil,
        streakBreak = model and model.isDeskTopVisitStreakBreak
            and model:isDeskTopVisitStreakBreak() == true or false,
        panelOpened = self._mainPanelVM ~= nil and not self._mainPanelVM.isDisposed,
        requireStreakBreak = requireStreakBreak,
    }
    state.canPopup = state.entryEnabled
        and not state.popupDone
        and state.hasModel
        and (not requireStreakBreak or state.streakBreak)
        and not state.panelOpened
        and not newLevelBlock
    return state.canPopup, state
end

function AliPayDesktopShortcutManager:getMissionState()
    local state = callIfExists(self._model, "getMissionState")
    if state then
        state = table.clone(state)
        state.fromDesktopEntry = self:isDesktopShortcutEntry()
        return state
    end
    return {
        todayRewardIndex = 0,
        displayState = "unavailable",
        fromDesktopEntry = false,
        canReward = false,
        periodEndTime = 0,
        errorCode = ErrorCode.NOT_READY,
    }
end

function AliPayDesktopShortcutManager:_setDesktopShortcutEntry(source)
    self._isDesktopShortcutEntry = source ~= nil
    self._desktopLaunchSource = type(source) == "table" and table.clone(source) or source
end

function AliPayDesktopShortcutManager:_markEnteredFromDesktopShortcut(source)
    self:_setDesktopShortcutEntry(source)
    if source then
        callIfExists(self._model, "markDeskTopVisit", getLaunchSourceTime(source))
    end
end

function AliPayDesktopShortcutManager:isDesktopShortcutEntry()
    return self._isDesktopShortcutEntry == true
end

function AliPayDesktopShortcutManager:getRewardList()
    return callIfExists(self._model, "getRewardList") or {}
end

function AliPayDesktopShortcutManager:getDesktopEntryDayIndex(time)
    return callIfExists(self._model, "getDesktopEntryDayIndex", time) or 0
end

function AliPayDesktopShortcutManager:hasHint()
    local hint = callIfExists(self._model, "hasHint")
    return hint == true
end

function AliPayDesktopShortcutManager:hasReward()
    local reward = callIfExists(self._model, "hasReward")
    return reward == true
end

function AliPayDesktopShortcutManager:markMainPanelEntered()
    local changed = callIfExists(self._model, "markMainPanelEntered")
    if changed == true then
        self:refreshIcon("main_panel_enter")
    end
    return changed == true
end

function AliPayDesktopShortcutManager:getIconState()
    local gate = self:canShowEntry()
    return {
        visible = gate.enabled == true,
        removeReason = gate.reason,
        hasHint = gate.enabled == true and self:hasHint(),
        hasReward = gate.enabled == true and self:hasReward(),
        label = AliPayDesktopShortcutManager.ICON_LABEL,
        missionState = self:getMissionState(),
    }
end

function AliPayDesktopShortcutManager:openPanel(source, closeCallback)
    if self._mainPanelVM and not self._mainPanelVM.isDisposed then
        if self._mainPanelReady then
            return self._mainPanelVM
        end
        local pendingVM = self._mainPanelVM
        self:unbindPanelVM(pendingVM)
        self:_releasePanelVM(pendingVM, "reopen_pending")
    end

    return self:requestMainInfo(MainInfoReason.ICON_OPEN, function()
        self:_openPanelWithoutResourceCheck(source, closeCallback)
    end, function(response)
        if response and response.isCancel and response:isCancel() then
            safeRunCall(closeCallback, response)
            return
        end
        self:_showOpenPanelFailTip(response)
        safeRunCall(closeCallback, response)
    end, {
        loading = true,
        fromDesktop = self:isDesktopShortcutEntry(),
        syncFrom = source or MainInfoReason.ICON_OPEN,
        failOnUnavailable = true,
    })
end

function AliPayDesktopShortcutManager:_openPanelWithoutResourceCheck(source, closeCallback)
    local gate = self:canShowEntry()
    if not gate.enabled then
        self:_showOpenPanelFailTip(gate.reason)
        safeRunCall(closeCallback, gate.reason)
        return nil, gate.reason
    end
    if self._mainPanelVM and not self._mainPanelVM.isDisposed then
        return self._mainPanelVM
    end

    local delegate = { manager = self, source = source, closeCallback = closeCallback }
    local ok, vm = pcall(function()
        if self._panelFactory then
            local injectedVM = self._panelFactory:create(delegate)
            if injectedVM then
                return injectedVM
            end
        end

        local GiftOnTheDeskPanelVM = require "amf.feature.minihub.alipaydesktopshortcut.view.GiftOnTheDeskPanelVM"
        return GiftOnTheDeskPanelVM:create(delegate)
    end)
    if not ok then
        self:_showOpenPanelFailTip("panel_create_failed", vm)
        safeRunCall(closeCallback, vm or "panel_create_failed")
        return nil, "panel_create_failed"
    end
    if not vm then
        self:_showOpenPanelFailTip("panel_factory_empty")
        safeRunCall(closeCallback, "panel_factory_empty")
        return nil, "panel_factory_empty"
    end

    self._mainPanelVM = vm
    self._mainPanelReady = false
    local openFinished = false
    local openTimerId
    local function cancelOpenTimer()
        if openTimerId and cancelTimeOut then
            cancelTimeOut(openTimerId)
        end
        openTimerId = nil
        vm._alipayDesktopShortcutAbortOpen = nil
    end
    local function abortOpen()
        if openFinished then
            return
        end
        openFinished = true
        cancelOpenTimer()
    end
    local function finishOpen(ok, reason, detail)
        if openFinished then
            return
        end
        openFinished = true
        cancelOpenTimer()
        if ok then
            self._mainPanelReady = true
            return
        end
        self:unbindPanelVM(vm)
        self:_releasePanelVM(vm, reason)
        self:_showOpenPanelFailTip(reason, detail)
        safeRunCall(closeCallback, detail or reason)
    end

    self:bindPanelVM(vm, source)
    if vm.setPanelReadyCallback then
        vm:setPanelReadyCallback(function()
            finishOpen(true)
        end)
    end
    if vm.setLoadResFailCallback then
        vm:setLoadResFailCallback(function(error)
            finishOpen(false, "panel_res_load_failed", error)
        end)
    end
    if setTimeOut then
        openTimerId = setTimeOut(function()
            finishOpen(false, ErrorCode.OPEN_PANEL_TIMEOUT)
        end, AliPayDesktopShortcutManager.OPEN_PANEL_TIMEOUT_SECONDS)
        vm._alipayDesktopShortcutAbortOpen = abortOpen
    end

    if vm.popout then
        local popoutOk, popoutError = pcall(function()
            vm:popout()
        end)
        if not popoutOk then
            finishOpen(false, "panel_popout_failed", popoutError)
            return nil, "panel_popout_failed"
        end
    else
        finishOpen(false, "panel_popout_failed")
        return nil, "panel_popout_failed"
    end
    return vm
end

function AliPayDesktopShortcutManager:closePanel(reason)
    if self._mainPanelVM and not self._mainPanelVM.isDisposed then
        self:_closePanelVM(self._mainPanelVM, reason)
    end
    self._mainPanelVM = nil
    self:refreshIcon(reason or "close_panel")
end

function AliPayDesktopShortcutManager:bindPanelVM(panelVM, source)
    if not panelVM or panelVM.isDisposed then
        return
    end
    if panelVM._alipayDesktopShortcutManagerBound then
        return
    end
    panelVM._alipayDesktopShortcutManagerBound = true
    panelVM.alipayDesktopShortcutSource = source

    local this = self
    local originRecycle = panelVM.recycle
    panelVM.recycle = function(obj)
        safeRunCall(obj._alipayDesktopShortcutAbortOpen)
        obj._alipayDesktopShortcutAbortOpen = nil
        this:unbindPanelVM(obj)
        safeRunCall(originRecycle, obj)
    end

    local originCloseAll = panelVM.onCloseAllPanel
    panelVM.onCloseAllPanel = function(obj, reason)
        safeRunCall(originCloseAll, obj, reason)
        if obj.isDisposed then
            return
        end
        this:_closePanelVM(obj, reason)
    end
end

function AliPayDesktopShortcutManager:unbindPanelVM(panelVM)
    if not panelVM then
        return
    end
    if self._mainPanelVM == panelVM then
        self._mainPanelVM = nil
        self._mainPanelReady = false
    end
end

function AliPayDesktopShortcutManager:notifyPanelRefresh(reason)
    local panelVM = self._mainPanelVM
    if panelVM and not panelVM.isDisposed and panelVM.onManagerRefresh then
        panelVM:onManagerRefresh(reason)
    end
end

function AliPayDesktopShortcutManager:refreshIcon(reason)
    return self.iconHost:reconcile(reason or "refresh")
end

function AliPayDesktopShortcutManager:registerIcon(reason)
    return self.iconHost:reconcile(reason or "register")
end

function AliPayDesktopShortcutManager:createLegacyIcon()
    local AliPayDesktopShortcutIcon = require "amf.feature.minihub.alipaydesktopshortcut.AliPayDesktopShortcutIcon"
    return AliPayDesktopShortcutIcon:create(self)
end

function AliPayDesktopShortcutManager:getIcon()
    return self.iconHost:getIcon()
end

function AliPayDesktopShortcutManager:removeIcon()
    return self.iconHost:dispose("manager_remove")
end

function AliPayDesktopShortcutManager:onIconTapped()
    self:sendDC("sendIconClick")
    self:markAutoPopupDone(AliPayDesktopShortcutManager.FIRST_LOGIN_AUTO_POP_CACHE_KEY)
    self:markAutoPopupDone(AliPayDesktopShortcutManager.STREAK_BREAK_AUTO_POP_CACHE_KEY)
    self:openPanel("icon")
end

function AliPayDesktopShortcutManager:shutdownFeature(reason)
    self:clearVisibleState(reason or DisableReason.SHUTDOWN)
end

function AliPayDesktopShortcutManager:clearUnavailableState(reason)
    if self:isShutdown() or self:isLowVersion() then
        self:clearVisibleState(reason or DisableReason.SHUTDOWN)
    end
end

function AliPayDesktopShortcutManager:handleMainInfoError(response, reason)
    self._mainInfoError = response or {
        errorCode = ErrorCode.REQUEST_UNAVAILABLE,
        errorMsg = ErrorCode.REQUEST_UNAVAILABLE,
    }
    local errorCode = self:_resolveOpenPanelFailCode(self._mainInfoError)
    errorCode = tonumber(errorCode)
    if errorCode and AliPayDesktopShortcutManager.MAIN_INFO_SHUTDOWN_ERROR_CODES[errorCode] then
        self._mainInfoShutdownErrorCode = errorCode
        self:shutdownFeature(reason or ErrorCode.MAIN_INFO_ERROR)
        return
    end
    self:closePanel(reason or ErrorCode.MAIN_INFO_ERROR)
    self:refreshIcon(reason or ErrorCode.MAIN_INFO_ERROR)
end

function AliPayDesktopShortcutManager:clearVisibleState(reason)
    self:removeIcon()
    self:closePanel(reason or DisableReason.SHUTDOWN)
end

function AliPayDesktopShortcutManager:_closePanelVM(panelVM, reason)
    if not panelVM or panelVM.isDisposed then
        return
    end
    safeRunCall(panelVM._alipayDesktopShortcutAbortOpen)
    panelVM._alipayDesktopShortcutAbortOpen = nil
    if panelVM.close then
        panelVM:close(reason)
    elseif panelVM._close then
        panelVM:_close()
    end
end

function AliPayDesktopShortcutManager:_releasePanelVM(panelVM, reason)
    if not panelVM then
        return
    end
    safeRunCall(panelVM._alipayDesktopShortcutAbortOpen)
    panelVM._alipayDesktopShortcutAbortOpen = nil
    if panelVM.isDisposed then
        return
    end
    if panelVM.view and panelVM.view.isRunning and not panelVM.view:isRunning() and panelVM.view.realRelease then
        panelVM.view:realRelease()
    elseif panelVM.close then
        panelVM:close(reason)
    elseif panelVM.view and panelVM.view.realRelease then
        panelVM.view:realRelease()
    elseif panelVM.recycle then
        panelVM:recycle()
    end
end

function AliPayDesktopShortcutManager:_buildRewardResult(response, rewardItem)
    rewardItem = type(rewardItem) == "table" and rewardItem or {}
    return {
        rewards = rewardItem.rewards or {},
        rewardItem = rewardItem,
        missionState = self:getMissionState(),
        response = response,
    }
end

function AliPayDesktopShortcutManager:_buildErrorResult(response, needRefresh)
    return {
        errorCode = response and response.getErrorCode and response:getErrorCode() or ErrorCode.NOT_READY,
        errorMsg = response and response.errorMsg or nil,
        needRefresh = needRefresh == true,
        response = response,
    }
end

function AliPayDesktopShortcutManager:_resolveOpenPanelFailCode(reason)
    if type(reason) ~= "table" then
        return reason
    end

    if reason.getErrorCode then
        local ok, errorCode = pcall(function()
            return reason:getErrorCode()
        end)
        if ok and errorCode ~= nil then
            return errorCode
        end
    end

    return reason.errorCode
        or reason.reason
        or reason.code
        or reason.errorMsg
end

function AliPayDesktopShortcutManager:_showOpenPanelFailTip(reason, detail)
    if not CommonTip then
        return
    end

    local failCode = self:_resolveOpenPanelFailCode(reason)
    local tip = OpenPanelFailTip[failCode]
    if tip and CommonTip.showTip then
        CommonTip:showTip(tip)
        return
    end

    if type(reason) == "table" and CommonTip.showErrorTip then
        CommonTip:showErrorTip(reason)
        return
    end

    if CommonTip.showTip then
        CommonTip:showTip(OpenPanelFailTip.default)
    end
end

function AliPayDesktopShortcutManager:_createPlatformProxy()
    if self:isAlipayMiniGame() then
        local MiniPlatformProxy = require "amf.feature.minihub.alipaydesktopshortcut.system.mini.AliPayDesktopShortcutProxy"
        return MiniPlatformProxy.new()
    end
    local CommonPlatformProxy = require "amf.feature.minihub.alipaydesktopshortcut.system.common.AliPayDesktopShortcutProxy"
    return CommonPlatformProxy.new()
end

function AliPayDesktopShortcutManager:_canShowInCurrentPlatform()
    if not _G.isBundleVersionGreaterOrEqual("1.159.4") then
        return false
    end
    return EnvUtil:isALIPAYMiniGame()
        or self:isTestForceShowOnNonAlipay()
end

function AliPayDesktopShortcutManager:_normalizeAddShortcutResult(result)
    result = type(result) == "table" and table.clone(result) or {
        ok = false,
        reason = ErrorCode.UNSUPPORTED,
        code = ErrorCode.UNSUPPORTED,
        rawData = result,
    }
    result.ok = result.ok == true
    result.supportState = result.supportState or self:checkPlatformSupport()
    return result
end

function AliPayDesktopShortcutManager:_showReward(rewards)
    if type(rewards) ~= "table" or next(rewards) == nil then
        return
    end

    local dc = self:getDC()
    local feature = dc and dc:getRewardFeature() or AliPayDesktopShortcutManager.FEATURE_NAME
    local source = dc and dc:getRewardSource() or "desktop_reward"

    GainPropData:create()
        :setFeature(feature)
        :setSource(source)
        :setProps(rewards)
        :execute()

    self:_showRewardPanel(rewards)
end

function AliPayDesktopShortcutManager:_showRewardPanel(rewards)
    if type(rewards) ~= "table" or next(rewards) == nil then
        return
    end

    local CommonShowRewrdPanelVM = require "amf.middleware.ui.kit.templates.showrewardpanels.commonshowrewardpanel.vm.CommonShowRewrdPanelVM"
    CommonShowRewrdPanelVM.Builder.new()
        :setNotNeedBox(true)
        :setRewards(table.clone(rewards))
        :setTitle("恭喜获得")
        :setSubTitle("桌面奖励")
        :build()
        :popout()
end

return AliPayDesktopShortcutManager
