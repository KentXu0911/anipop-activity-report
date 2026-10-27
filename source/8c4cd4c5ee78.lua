local deferred = require "amf.script.sugar.deferred"
local OpenUrlUtil = require "amf.middleware.multiplatform.util.OpenUrlUtil"
local PurchaseEvent = require "amf.middleware.purchase.event.PurchaseEvent"
local PurchaseEventCenter = require "amf.middleware.purchase.event.PurchaseEventCenter"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local MarkEventCenter = require "amf.feature.dailyreward.mark.event.MarkEventCenter"
local StoreConfig = require "amf.feature.store.config.StoreConfig"
local Const = require "amf.feature.localactivity.recruithighpay.RecruitHighPayExpandConst"
require "amf.middleware.data.storage.LocalDB"
require "amf.feature.dailyreward.mark.extend.act.MarkPreOpenContext"
require "amf.feature.dailyreward.mark.extend.act.ActFestivalConst"

local RecruitHighPayExpandManager = class("RecruitHighPayExpandManager")

function RecruitHighPayExpandManager:ctor()
    self._delegate = nil
    self._markManager = nil
    self._fileObj = nil
    self._loginPeriodKey = nil
    self._paymentShownThisLogin = false
    self._paymentPopupScheduled = false
    self._paymentPanelVM = nil
    self._openingLink = false
    self._endTimer = nil
    self._activityEndTime = 0
    self._energyNodes = setmetatable({}, {__mode = "k"})
    self._signInGuideVisible = nil
end

function RecruitHighPayExpandManager:setMarkManager(markManager)
    self._markManager = markManager
end

function RecruitHighPayExpandManager:initialize()
    if self._initialized then return end
    self._initialized = true
    self._fileObj = LocalDB:createFileObject(Const.DB_FILE)

    PurchaseEventCenter:register(PurchaseEvent.RMB_ORDER_CANCELLED, self.onRmbOrderCancelled, self)
    MarkEventCenter:register(MarkEvent.MARK_PREOPEN_CHECK, self.onMarkPreOpenEvent, self)
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActivityInfoUpdate, self)
end

function RecruitHighPayExpandManager:install(delegate)
    assert(type(delegate) == "table", "RecruitHighPayExpandManager delegate is required")
    assert(delegate.actId == Const.ACT_ID, "RecruitHighPayExpandManager actId mismatch")
    self._delegate = delegate
    self:_refreshActivityEndTime(true)

    local periodKey = self:_getPeriodKey()
    if self._loginPeriodKey ~= periodKey then
        self._loginPeriodKey = periodKey
        self._paymentShownThisLogin = false
    end

    self:_scheduleActivityEnd()
    self:_refreshSurfaces(true, self:_isActivityExpired())
end

function RecruitHighPayExpandManager:_callDelegate(methodName, ...)
    local method = self._delegate and self._delegate[methodName]
    if type(method) ~= "function" then return nil end

    local ok, result = pcall(method, ...)
    if not ok then
        ALog.error("RecruitHighPayExpandManager", methodName .. ": " .. tostring(result))
        return nil
    end
    return result
end

function RecruitHighPayExpandManager:isEnabled()
    return self:_callDelegate("isEnabled") == true
end

function RecruitHighPayExpandManager:_getPeriodKey()
    local periodKey = self:_callDelegate("getPeriodKey")
    return tostring(periodKey or "unknown")
end

function RecruitHighPayExpandManager:_getStateKey(key)
    return tostring(Const.ACT_ID) .. ":" .. self:_getPeriodKey() .. ":" .. key
end

function RecruitHighPayExpandManager:_getState(key, defaultValue)
    local value = self._fileObj:getValue(self:_getStateKey(key))
    if value == nil then return defaultValue end
    return value
end

function RecruitHighPayExpandManager:_setStates(values)
    for key, value in pairs(values) do
        self._fileObj:setValue(self:_getStateKey(key), value)
    end
    self._fileObj:save()
end

function RecruitHighPayExpandManager:canShowEnergyGuide()
    return self:isEnabled()
end

function RecruitHighPayExpandManager:canShowSignInGuide()
    return self:isEnabled()
end

function RecruitHighPayExpandManager:canShowPaymentGuide()
    if not self:isEnabled() then return false end
    if self:_getState(Const.StateKey.PAYMENT_STOPPED, false) then return false end
    if self._paymentShownThisLogin then return false end
    if self._paymentPopupScheduled then return false end
    if self._paymentPanelVM and not self._paymentPanelVM.isDisposed then return false end

    local totalCount = tonumber(self:_getState(Const.StateKey.PAYMENT_COUNT, 0)) or 0
    if totalCount >= Const.PAYMENT_PERIOD_LIMIT then return false end

    local today = TimeKit:getTodayStart()
    local storedDay = tonumber(self:_getState(Const.StateKey.PAYMENT_DAY, 0)) or 0
    local dayCount = tonumber(self:_getState(Const.StateKey.PAYMENT_DAY_COUNT, 0)) or 0
    if storedDay == today and dayCount >= Const.PAYMENT_DAY_LIMIT then return false end
    return true
end

function RecruitHighPayExpandManager:_recordPaymentGuideShow()
    local today = TimeKit:getTodayStart()
    local storedDay = tonumber(self:_getState(Const.StateKey.PAYMENT_DAY, 0)) or 0
    local dayCount = tonumber(self:_getState(Const.StateKey.PAYMENT_DAY_COUNT, 0)) or 0
    if storedDay ~= today then dayCount = 0 end

    local totalCount = tonumber(self:_getState(Const.StateKey.PAYMENT_COUNT, 0)) or 0
    self:_setStates({
        [Const.StateKey.PAYMENT_COUNT] = totalCount + 1,
        [Const.StateKey.PAYMENT_DAY] = today,
        [Const.StateKey.PAYMENT_DAY_COUNT] = dayCount + 1,
    })
    self._paymentShownThisLogin = true
end

function RecruitHighPayExpandManager:_isManualHomeStoreCancel(eventData)
    if type(eventData) ~= "table" then return false end

    local scene = Director:sharedDirector():getRunningScene()
    if scene and scene:is(UBFGamePlayScene) then return false end

    local from = eventData.storeFrom
    local source = eventData.storeSource
    return (from == StoreConfig.fromFlag.kHomeSceneTop
            and source == StoreConfig.AccurateSource.Click_HS_Top)
        or (from == StoreConfig.fromFlag.kHomeSceneBottom
            and source == StoreConfig.AccurateSource.Click_HS_Bottom)
end

function RecruitHighPayExpandManager:onRmbOrderCancelled(evt)
    local eventData = evt and evt:getData() or nil
    if not self:_isManualHomeStoreCancel(eventData) then return end
    if self._paymentPopupScheduled then return end
    self._paymentPopupScheduled = true

    setTimeOut(function()
        self._paymentPopupScheduled = false
        if not self:_isManualHomeStoreCancel(eventData) then return end
        if not self:canShowPaymentGuide() then return end
        self:_showPaymentGuide(eventData)
    end, Const.PAYMENT_POPUP_DELAY)
end

function RecruitHighPayExpandManager:_showPaymentGuide(eventData)
    local factory = self._delegate and self._delegate.createPaymentGuidePanelVM
    if type(factory) ~= "function" then return end

    local vm
    local ok, result = pcall(factory, {
        payment = eventData,
        onTap = function()
            return self:openRecruitLink(Const.Scene.PAYMENT_CANCEL)
        end,
        onClosed = function(closedVM)
            if self._paymentPanelVM == closedVM then
                self._paymentPanelVM = nil
            end
        end,
    })
    if not ok then
        ALog.error("RecruitHighPayExpandManager", "create payment panel: " .. tostring(result))
        return
    end
    vm = result
    if not vm then return end

    self._paymentPanelVM = vm
    local popoutOk, popoutError = pcall(function()
        vm:popout()
    end)
    if not popoutOk then
        self._paymentPanelVM = nil
        if vm.view and vm.view.realRelease then
            safeRunCall(vm.view.realRelease, vm.view)
        elseif vm.recycle then
            safeRunCall(vm.recycle, vm)
        end
        ALog.error("RecruitHighPayExpandManager", "popout payment panel: " .. tostring(popoutError))
        return
    end
    self:_recordPaymentGuideShow()
end

function RecruitHighPayExpandManager:onMarkPreOpenEvent(evt)
    if not self:canShowSignInGuide() then return end
    local contextList = evt:getData()
    if type(contextList) ~= "table" then return end

    local resourcePath = self._delegate.signInResourcePath
    local context = MarkPreOpenContext.new()
        :setPriority(ActFestivalConst.Priority.RECRUIT_HIGH_PAY)
        :setExtLoadFiles({resourcePath})
        :setEnabledCheckFunc(function()
            return self:canShowSignInGuide()
        end)
        :setPreOpenFunc(function(callback)
            safeRunCall(callback)
        end)
        :setBannerCreator(function()
            if not self:canShowSignInGuide() then return nil end
            return self:_callDelegate("createSignInBannerNode", {
                onTap = function()
                    return self:openRecruitLink(Const.Scene.SIGN_IN)
                end,
            })
        end, ccp(0,0))
    table.insert(contextList, context)
end

function RecruitHighPayExpandManager:createEnergyGuideNode(options)
    if not self:canShowEnergyGuide() then return nil end
    options = options or {}
    local node = self:_callDelegate("createEnergyGuideNode", {
        promoteNode = options.promoteNode,
        showPromoteFirst = options.showPromoteFirst,
        createPromoteNode = options.createPromoteNode,
        onHeightChanged = options.onHeightChanged,
        onTap = function()
            return self:openRecruitLink(Const.Scene.ENERGY)
        end,
        onDispose = function(disposedNode)
            self._energyNodes[disposedNode] = nil
        end,
    })
    if node then self._energyNodes[node] = true end
    return node
end

function RecruitHighPayExpandManager:_makeRejectedDeferred()
    local result = deferred.new()
    result:reject()
    return result
end

function RecruitHighPayExpandManager:_showOpenFailedTip()
    CommonTip:showTip("跳转失败，请稍后重试", "negative")
end

function RecruitHighPayExpandManager:_showActivityEndedTip()
    CommonTip:showTip("活动已结束~", "negative")
end

function RecruitHighPayExpandManager:_refreshActivityEndTime(force)
    local endTime = tonumber(self:_callDelegate("getEndTime")) or 0
    if endTime <= 0 then return end

    -- ActivityMgr may drop expired actInfo, whose delegate fallback is a later
    -- package end time. Keep the last reliable expand end time in that case.
    local isReliable = force
        or endTime <= TimeKit:timeInSec()
        or self:isEnabled()
    if isReliable then self._activityEndTime = endTime end
end

function RecruitHighPayExpandManager:_isActivityExpired()
    local endTime = tonumber(self._activityEndTime) or 0
    if endTime <= 0 then
        endTime = tonumber(self:_callDelegate("getEndTime")) or 0
    end
    if endTime <= 0 then return false end
    return TimeKit:timeInSec() >= endTime
end

function RecruitHighPayExpandManager:_isPad()
    if not EnvUtil:isIOS() then return false end
    local deviceType = MetaInfo:getInstance():getMachineType() or ""
    return string.find(deviceType, "iPad", 1, true) ~= nil
end

function RecruitHighPayExpandManager:_isValidUrl(url)
    return type(url) == "string"
        and string.starts(url, "https://")
        and string.find(url, "%s") == nil
end

function RecruitHighPayExpandManager:openRecruitLink(scene)
    if self._openingLink then return self:_makeRejectedDeferred() end
    if self:_isActivityExpired() then
        self:_showActivityEndedTip()
        return self:_makeRejectedDeferred()
    end
    if not self:isEnabled() then
        self:_showOpenFailedTip()
        return self:_makeRejectedDeferred()
    end

    local url = self:_callDelegate("getUrl")
    if not self:_isValidUrl(url) then
        self:_showOpenFailedTip()
        return self:_makeRejectedDeferred()
    end

    local isPad = self:_isPad()
    if not isPad then
        local canOpenOk, canOpen = pcall(function()
            return OpenUrlUtil:canOpenUrl("weixin://")
        end)
        if not canOpenOk then
            self:_showOpenFailedTip()
            return self:_makeRejectedDeferred()
        end
        if not canOpen then
            CommonTip:showTip("当前未安装微信，请先安装微信~", "negative")
            return self:_makeRejectedDeferred()
        end
    end

    local result = deferred.new()
    local settled = false
    self._openingLink = true
    local timeoutId

    local function finish(success)
        if settled then return end
        settled = true
        self._openingLink = false
        cancelTimeOut(timeoutId)
        if success then
            self:_onOpenUrlSuccess(scene)
            result:resolve()
        else
            self:_showOpenFailedTip()
            result:reject()
        end
    end

    timeoutId = setTimeOut(function()
        finish(false)
    end, Const.OPEN_URL_TIMEOUT)

    local openOk, openResult = pcall(function()
        return OpenUrlUtil:openUrl(url, isPad)
    end)
    if not openOk or not openResult or type(openResult.next) ~= "function" then
        finish(false)
        return result
    end
    openResult:next(function()
        finish(true)
    end, function()
        finish(false)
    end)
    return result
end

function RecruitHighPayExpandManager:_onOpenUrlSuccess(scene)
    if scene == Const.Scene.PAYMENT_CANCEL then
        self:_setStates({[Const.StateKey.PAYMENT_STOPPED] = true})
    end
end

function RecruitHighPayExpandManager:_refreshSignInBanner()
    if not self._markManager then return end
    self._markManager:initMarkActContext()
    local mainPanelVM = self._markManager.mainPanelVM
    if mainPanelVM and not mainPanelVM.isDisposed then
        mainPanelVM:updateUITopPart(true)
    end
end

function RecruitHighPayExpandManager:_refreshSignInBannerIfChanged(force)
    local visible = self:canShowSignInGuide()
    if not force and self._signInGuideVisible == visible then return end
    self._signInGuideVisible = visible
    self:_refreshSignInBanner()
end

function RecruitHighPayExpandManager:_refreshEnergyNodes(deferRemoval)
    if deferRemoval then return end
    if self:canShowEnergyGuide() then return end
    for node in pairs(self._energyNodes) do
        if isSafeCocosObj(node) and node.onActivityDisabled then
            node:onActivityDisabled()
        end
    end
end

function RecruitHighPayExpandManager:_refreshSurfaces(forceSignInRefresh, deferEnergyRemoval)
    self:_refreshEnergyNodes(deferEnergyRemoval)
    self:_refreshSignInBannerIfChanged(forceSignInRefresh)
    if self:isEnabled() then return end
    if self._paymentPanelVM and not self._paymentPanelVM.isDisposed then
        self._paymentPanelVM:close()
    end
end

function RecruitHighPayExpandManager:onActivityInfoUpdate(evt)
    if not self._delegate then return end
    local data = evt and evt:getData() or nil
    local actInfos = data and data.actInfos or nil
    if actInfos and not data.fromServer and actInfos[tostring(Const.ACT_ID)] == nil then return end
    self:_refreshActivityEndTime()
    self:_refreshSurfaces(nil, self:_isActivityExpired())
    self:_scheduleActivityEnd()
end

function RecruitHighPayExpandManager:_scheduleActivityEnd()
    if self._endTimer then
        TimerUtil.removeAlarm(self._endTimer)
        self._endTimer = nil
    end
    local endTime = tonumber(self._activityEndTime) or 0
    local delay = endTime - TimeKit:timeInSec()
    if delay <= 0 then return end
    self._endTimer = TimerUtil.addAlarm(function()
        self._endTimer = nil
        self:_refreshSurfaces(nil, true)
    end, delay, 1)
end

return RecruitHighPayExpandManager
