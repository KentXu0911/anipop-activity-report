local DailyLevelConst = require "amf.feature.localactivity.dailylevel.config.DailyLevelConst"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local deferred = require "amf.script.sugar.deferred"
local ResLoader = require "amf.feature.localactivity.dailylevel.util.ResLoader"
local Res = require "amf.feature.localactivity.dailylevel.config.Res"
local ActInfo = require "amf.feature.localactivity.dailylevel.model.ActInfo"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"
local DailyLevelLoadingLayer = require "amf.feature.localactivity.dailylevel.view.node.DailyLevelLoadingLayer"
local DailyLevelMgr = class("DailyLevelMgr")
local ICON_V2_EXPERIMENT_MODULE = "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"

local function _handleError(resp, loading, suppressTip)
    if loading and not suppressTip then
        if not resp:isCancel() then
            CommonTip:showErrorTip(resp)
        end
    end
end

function DailyLevelMgr:ctor()
    self._model = nil
    self._activityMgr = nil
    self._iconManager = nil
    self._panelVMMap = {}
    self._hasHandledMainInfoActInvalid = false
    self._levelLoadingResRetained = false
    self._levelLoadingResDeferred = nil
    self._levelLoadingResReleasePending = false
    self._isInDailyLevel = false
    self._iconAdapter = nil
    self._iconDataProvider = nil
    self._iconAdapterRecoveryPending = false
end

function DailyLevelMgr:setActivityMgr(mgr)
    self._activityMgr = mgr
end

function DailyLevelMgr:setIconManager(mgr)
    self._iconManager = mgr
end

function DailyLevelMgr:setNetworkStatusManager(mgr)
    self._networkStatusManager = mgr
end

function DailyLevelMgr:setAutoPopupMgr(mgr)
    self._autoPopupMgr = mgr
    self:_registerAutoPopup()
end

function DailyLevelMgr:initialize()
    self._model = require("amf.feature.localactivity.dailylevel.model.DailyLevelModel"):create()
    self:registerEvent()
    ActInfo:syncActInfo(self:getActInfo())
    if self:isActEnabled() then
        -- 请求一次主info
        self:requestMainInfo(false):next(function()
            self:tryAddIcon()
        end)
    else
        self:tryAddIcon()
    end
end

function DailyLevelMgr:dc(category, subCategory, extraData)
    local params = {
        category = category,
        sub_category = subCategory,
    }
    for key, value in pairs(extraData or {}) do
        params[key] = value
    end
    -- printx(27, "dc ---", tts(params))
    DcUtil:UserTrack(params)
end

function DailyLevelMgr:_dcOnceADay(key, category, subCategory, extraData)
    local dayKey = key .. "_" .. tostring(TimeKit:getTodayStart())
    if self:getLocalValue(dayKey) then return end
    self:setLocalValue(dayKey, true)
    self:dc(category, subCategory, extraData)
end

function DailyLevelMgr:dcQualify()
    self:_dcOnceADay("dcQualify", "canyu", "qualify", {
        actid = DailyLevelConst.ACT_ID,
    })
end

function DailyLevelMgr:dcJoin()
    self:_dcOnceADay("dcJoin", "canyu", "join", {
        actid = DailyLevelConst.ACT_ID,
    })
end

function DailyLevelMgr:registerEvent()
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActInfoUpdate, self)
    local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
    IconEventCenter:register(IconEvent.ICON_SYSTEM_READY, self.onIconSystemReady, self)
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
end

------------------------- 事件相关 start -------------
function DailyLevelMgr:onIconSystemReady()
    self:tryAddIcon()
end

-- 跨天时关闭当前活动相关界面，并刷新正式期每日免费闯关次数。
function DailyLevelMgr:onActPassDay()
    local shouldShowPassDayTip = self:hasAliveMainPanelVM()
    if self._model and self._model:isInMainTime() then
        if (self:getDataValue("freeCanPlayNum", 0) or 0) == 0 then
            self:setDataValue("freeCanPlayNum", 1)
        end
    end
    local icon = self._iconManager:getIconByIconKey(IconKey.kDailyLevel)
    if icon and icon.updateWeekendSpine then
        icon:updateWeekendSpine()
    end
    self:refreshV2Icon("pass_day")
    self:closeAllPanelVM()
    local scene = Director:sharedDirector():getRunningSceneLua()
    if shouldShowPassDayTip and scene and scene:isScene("MainScene") then
        CommonTip:showTip("新的一天开始了，数据已更新，请尝试重进活动~")
    end
end

function DailyLevelMgr:onSystemEnterBackground()
    local LocalPush = require "amf.feature.localactivity.dailylevel.LocalPush"
    if not self:isEnabled() then
        LocalPush:cancel()
        return
    end
    LocalPush:register(self)
end

-- 活动 actInfo 更新入口：同步 logicVersion/time extra，并刷新主 info 与入口 icon。
function DailyLevelMgr:onActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local actInfo = actInfos[tostring(DailyLevelConst.ACT_ID)]
    if not actInfo then
        -- 服务端全量列表中没有本活动才表示活动已下线；其他活动的局部更新与本活动无关。
        if not data.fromServer and not self._isClearingActInfo then return end
        self:closeAllPanelVM()
        ActInfo:syncActInfo(nil)
        self:clearActAutoPopUniqueKey()
        self:removeIcon()
        return
    end
    ActInfo:syncActInfo(actInfo)
    if not self:isIconEnabled() then
        self:removeIcon()
        return
    end
    if not self:isActEnabled() then
        self:tryAddIcon()
        return
    end
    -- 没请求过主info就请求一次
    if data.fromServer and not self:getDataValue("fromServer") then
        self:requestMainInfo(false):next(function()
            self:tryAddIcon()
        end)
    else
        self:tryAddIcon()
    end
end

-- 配表道具 customGain 入口：金奖券/普通奖券/收集物不进默认背包，直接累加到活动数据。
function DailyLevelMgr:_onCustomGain(event)
    local reward = event and event:getData() or {}
    self:updateRuntimeItemNum(reward.itemId, reward.num or 0)
end

-- 按道具 id 修改活动内道具数量，奖券和收集物由 runtime_config 的 customGain 事件驱动。
function DailyLevelMgr:updateRuntimeItemNum(itemId, num)
    if not itemId or not num or num == 0 then return end
    local changed = false
    if itemId == DailyLevelConst.GOLD_TICKET_ID then
        self:setDataValue("goldTicketNum", (self:getDataValue("goldTicketNum", 0) or 0) + num)
        changed = true
    elseif itemId == DailyLevelConst.NORMAL_TICKET_ID then
        self:setDataValue("normalTicketNum", (self:getDataValue("normalTicketNum", 0) or 0) + num)
        changed = true
    elseif itemId == DailyLevelConst.COLLECTION_ID then
        self:setDataValue("collectNum", (self:getDataValue("collectNum", 0) or 0) + num)
        changed = true
    end
    if changed then self:refreshV2Icon("custom_gain", {itemId = itemId, num = num}) end
end

------------------------- 事件相关 end -------------

------------------------- 界面管理 start -------------
-- 判断 VM 是否仍然有效；已 dispose 的 VM 不再参与跨天关闭。
local function _isPanelVMAlive(panelVM)
    return panelVM and not panelVM.isDisposed
end

-- 兼容不同面板 VM 的关闭接口，优先使用活动统一关闭回调。
local function _closePanelVM(panelVM)
    if not _isPanelVMAlive(panelVM) then return false end

    if panelVM.onActCloseAllPanel then
        panelVM:onActCloseAllPanel()
    elseif panelVM.close then
        panelVM:close(true)
    elseif panelVM._close then
        panelVM:_close()
    else
        return false
    end

    return true
end

-- 将活动界面 VM 交给 manager 管理，用于跨天统一关闭。
function DailyLevelMgr:managePanelVM(panelVM)
    if not _isPanelVMAlive(panelVM) then return end
    for managedPanelVM in pairs(self._panelVMMap) do
        if not _isPanelVMAlive(managedPanelVM) then
            self._panelVMMap[managedPanelVM] = nil
        end
    end
    self._panelVMMap[panelVM] = true
end

-- 手动移除 VM 管理关系；当前主要保留给特殊界面主动解绑使用。
function DailyLevelMgr:unmanagePanelVM(panelVM)
    self._panelVMMap[panelVM] = nil
end

function DailyLevelMgr:hasAlivePanelVMExcept(excludedPanelVM)
    for panelVM in pairs(self._panelVMMap) do
        if not _isPanelVMAlive(panelVM) then
            self._panelVMMap[panelVM] = nil
        elseif panelVM ~= excludedPanelVM then
            return true
        end
    end
    return false
end

function DailyLevelMgr:hasAliveMainPanelVM()
    for panelVM in pairs(self._panelVMMap) do
        if not _isPanelVMAlive(panelVM) then
            self._panelVMMap[panelVM] = nil
        elseif panelVM.getClassName and panelVM:getClassName() == "DailyLevelMainPanelVM" then
            return true
        end
    end
    return false
end

-- 关闭所有当前记录的活动 VM，并清空管理表，避免重复关闭或持有旧引用。
function DailyLevelMgr:closeAllPanelVM()
    for panelVM in pairs(self._panelVMMap) do
        _closePanelVM(panelVM)
    end
    self._panelVMMap = {}
end

function DailyLevelMgr:clearInvalidActivity()
    self._isClearingActInfo = true
    self._activityMgr:setActInfo(DailyLevelConst.ACT_ID, nil)
    self._isClearingActInfo = false
end

function DailyLevelMgr:isMainInfoActInvalidError(resp)
    return resp
        and resp.getErrorCode
        and resp:getErrorCode() == DailyLevelConst.MAIN_INFO_ACT_INVALID_ERROR_CODE
end

function DailyLevelMgr:handleMainInfoActInvalidError(suppressTip)
    if self._hasHandledMainInfoActInvalid then return end
    self._hasHandledMainInfoActInvalid = true
    if not suppressTip then
        CommonTip:showTip(DailyLevelConst.ACT_NAME.."活动已结束！")
    end
    self:closeAllPanelVM()
    self:clearActAutoPopUniqueKey()
    self:removeIcon()
    self:clearInvalidActivity()
end

-- 打开主面板前强制拉取主 info，保证界面展示的是最新活动数据。
function DailyLevelMgr:openMainPanel(param)
    param = param or {}
    if self:hasAliveMainPanelVM() then
        if param.fromLevel then
            self:finishExitLevelLoading()
        end
        safeRunCall(param.closeCallback)
        return
    end

    local isAutoPopup = param.autoPopup == true
    local lightStart = param.userClick ~= true
    -- 用户点击或强弹进入领奖期且没有可展示奖励时，在打开主界面前直接结算并刷新下一期。
    -- 其他入口仍由主界面统一处理宝箱、奖券和换期表现。
    local skipAutoFinalReward = param.userClick ~= true and not isAutoPopup
    self:requestMainInfo(param.loading, skipAutoFinalReward, lightStart, isAutoPopup):next(function()
        if param.fromLevel then
            self:finishExitLevelLoading()
        end
        if self:hasAliveMainPanelVM() then
            safeRunCall(param.closeCallback)
            return
        end
        if isAutoPopup and param.autoPopupCheck and not param.autoPopupCheck() then
            safeRunCall(param.closeCallback)
            return
        end
        if not self:isV2IconActive() then
            self:clearNewActFlag()
        end
        self:markOnceGuide(DailyLevelConst.GuideId.STAGE2_MAIN_PANEL)
        self:_markStage4PopupRecord()
        local DailyLevelMainPanelVM = require "amf.feature.localactivity.dailylevel.view.DailyLevelMainPanelVM"
        param.consumeV2NewOnOpen = isAutoPopup and self:isV2IconActive()
        local vm = DailyLevelMainPanelVM:create(param)
        vm:setLoadResFailCallback(function()
            safeRunCall(param.closeCallback)
        end)
        vm:popout()
        self:managePanelVM(vm)
    end, function()
        if param.fromLevel then
            self:finishExitLevelLoading()
        end
        safeRunCall(param and param.closeCallback)
    end)
end

function DailyLevelMgr:prepareLevelLoadingRes()
    if not EnvUtil:isMiniGame() or self._levelLoadingResRetained then
        return deferred.success()
    end
    if self._levelLoadingResDeferred then
        return self._levelLoadingResDeferred
    end

    self._levelLoadingResReleasePending = false
    local loading = deferred.new()
    self._levelLoadingResDeferred = loading
    ResLoader:loadAndRetainRes(Res:getLoadingResList()):next(function()
        if self._levelLoadingResDeferred ~= loading then return end
        self._levelLoadingResDeferred = nil
        self._levelLoadingResRetained = true
        if self._levelLoadingResReleasePending then
            self:releaseLevelLoadingRes()
        end
        loading:resolve()
    end, function(event)
        if self._levelLoadingResDeferred ~= loading then return end
        self._levelLoadingResDeferred = nil
        self._levelLoadingResReleasePending = false
        loading:reject(event)
    end)
    return loading
end

function DailyLevelMgr:releaseLevelLoadingRes()
    if not EnvUtil:isMiniGame() then return end
    if self._levelLoadingResDeferred then
        self._levelLoadingResReleasePending = true
        return
    end
    self._levelLoadingResReleasePending = false
    if not self._levelLoadingResRetained then return end
    self._levelLoadingResRetained = false
    ResLoader:unloadRes(Res:getLoadingResList())
end

function DailyLevelMgr:markEnterDailyLevel()
    self._isInDailyLevel = true
end

function DailyLevelMgr:finishExitLevelLoading()
    self:hideLevelMask()
    self:releaseLevelLoadingRes()
    self._isInDailyLevel = false
end

function DailyLevelMgr:_showLevelMask(mode, forceWeekend)
    self:clearLevelMask()
    local loadId = self._levelMaskLoadId
    local function createMaskLayer()
        if loadId ~= self._levelMaskLoadId then return end
        local scene = Director:sharedDirector():getRunningSceneLua()
        if not scene then return end
        local maskLayer = DailyLevelLoadingLayer:create(mode, forceWeekend)
        scene:addChild(maskLayer, SceneLayerShowKey.TOP_LAYER)
        self._levelMaskLayer = maskLayer
    end

    if EnvUtil:isMiniGame() and self._levelLoadingResRetained then
        createMaskLayer()
    elseif EnvUtil:isMiniGame() then
        self:prepareLevelLoadingRes():next(createMaskLayer)
    else
        UICreateUtil:loadPlist(Res.Texture.LOADING_ATLAS)
        createMaskLayer()
    end
end

function DailyLevelMgr:showEnterLevelMask()
    self:_showLevelMask(DailyLevelLoadingLayer.Mode.ENTER)
end

function DailyLevelMgr:showExitLevelMask(forceWeekend)
    self:_showLevelMask(DailyLevelLoadingLayer.Mode.EXIT, forceWeekend)
end

function DailyLevelMgr:hideLevelMask(callback)
    self:clearLevelMask()
    safeRunCall(callback)
end

function DailyLevelMgr:clearLevelMask()
    self._levelMaskLoadId = (self._levelMaskLoadId or 0) + 1
    if self._levelMaskLayer and not self._levelMaskLayer.isDisposed then
        self._levelMaskLayer:removeFromParentAndCleanup(true)
    end
    self._levelMaskLayer = nil
end
------------------------- 界面管理 end -------------

------------------------- 强弹相关 start -------------

function DailyLevelMgr:_markStage4PopupRecord()
    if self._autoPopupMgr:getCheckPointPopNum(PopupCheckPoint.DAILY_LEVEL_STAGE4) <= 0 then
        self._autoPopupMgr:sendDailyData(PopupCheckPoint.DAILY_LEVEL_STAGE4)
    end
end

function DailyLevelMgr:_registerAutoPopup()
    local PopStage = AutoPopupConst.PopStage

    self._autoPopupMgr:registerPopup({
        checkPoint = PopupCheckPoint.DAILY_LEVEL_STAGE2,
        stages = { PopStage.STAGE_TWO },
        check = function()
            return self:canPopStage2()
        end,
        creator = function(_, onPopOver)
            return function()
                if not self:canPopStage2() then
                    safeRunCall(onPopOver)
                    return
                end
                self:openMainPanel({
                    closeCallback = onPopOver,
                    loading = true,
                    autoPopup = true,
                    autoPopupCheck = function()
                        return self:canPopStage2()
                    end,
                })
            end
        end,
    })

    self._autoPopupMgr:registerPopup({
        checkPoint = PopupCheckPoint.DAILY_LEVEL_STAGE4,
        stages = { PopStage.STAGE_FOUR },
        check = function()
            return self:canPopStage4()
        end,
        creator = function(_, onPopOver)
            return function()
                if not self:canPopStage4() then
                    safeRunCall(onPopOver)
                    return
                end
                self:openMainPanel({
                    closeCallback = onPopOver,
                    loading = false,
                    autoPopup = true,
                    autoPopupCheck = function()
                        return self:canPopStage4()
                    end,
                })
            end
        end,
    })
end

function DailyLevelMgr:onActEnterMainScene(evt)
    local data = evt:getData()
    local isDailyLevelResult = false
    if data.levelPlayInfo then
        local levelScene = data.levelPlayInfo.levelScene
        isDailyLevelResult = levelScene == UBFLevelSceneType.kDailyLevelGameplay
    end
    if not isDailyLevelResult and not self._isInDailyLevel then return false end
    if not self:isNetworkEnabled() then
        self:finishExitLevelLoading()
        return false
    end
    self:showExitLevelMask()
    self:openMainPanel({
        fromLevel = true,
        loading = false,
    })
end

function DailyLevelMgr:canPopStage2()
    if not self:isEnabled() then return false end
    if not self:isNetworkEnabled() then return false end
    local periodId = self:getDataValue("periodId", 0)
    if not periodId or periodId == 0 then return false end
    return not self:hasOnceGuide(DailyLevelConst.GuideId.STAGE2_MAIN_PANEL)
end

function DailyLevelMgr:canPopStage4()
    if not self:isEnabled() then return false end
    if not self:isNetworkEnabled() then return false end
    if self:isInAwardTime() then return self:hasReward() end
    if self:isInMainTime() then return self:getMsgNum() > 0 end
    return false
end

function DailyLevelMgr:isNetworkEnabled()
    return self._networkStatusManager:isNetworkEnabled()
end
------------------------- 强弹相关 end -------------

function DailyLevelMgr:isV2IconExperimentEnabled()
    local ok, enabled = pcall(function()
        local experiment = require(ICON_V2_EXPERIMENT_MODULE)
        return experiment:isEnabled()
    end)
    return ok and enabled == true
end

function DailyLevelMgr:isV2IconActive()
    return self._iconAdapter and self._iconAdapter:isV2Active() or false
end

function DailyLevelMgr:createLegacyIcon()
    local DailyLevelIcon = require "amf.feature.localactivity.dailylevel.view.DailyLevelIcon"
    return DailyLevelIcon:create()
end

function DailyLevelMgr:createPackageIconAdapter()
    local adapterLoaded, PackageIconV2Adapter = pcall(
        require,
        "amf.feature.mainscene.module.icon.v2.runtime.PackageIconV2Adapter"
    )
    if not adapterLoaded or type(PackageIconV2Adapter.create) ~= "function" then
        return nil, adapterLoaded and "DAILY_LEVEL_ICON_V2_ADAPTER_CREATE_REQUIRED" or PackageIconV2Adapter
    end

    local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
    local options
    local provider
    local configOk, configError = pcall(function()
        local IconV2Config = require "amf.feature.localactivity.dailylevel.icon.IconV2Config"
        options, provider = IconV2Config.create(self, IconEventCenter)
    end)
    if not configOk then
        options = {
            ownerIconKey = IconKey.kDailyLevel,
            ownerIdentity = self,
            iconEventCenter = IconEventCenter,
            legacyFactory = function() return self:createLegacyIcon() end,
            v2PreflightError = configError,
        }
        provider = nil
    end

    local createOk, adapter, modeOrError, cleanupOwner = pcall(
        PackageIconV2Adapter.create,
        PackageIconV2Adapter,
        options
    )
    if not createOk then return nil, adapter end
    if not adapter then return nil, modeOrError, cleanupOwner end
    return adapter, nil, nil, modeOrError == "v2" and provider or nil
end

function DailyLevelMgr:_disposeUnpublishedIconAdapter(adapter)
    if not adapter or type(adapter.dispose) ~= "function" then return true end
    local disposeOk, disposed, disposeError = pcall(adapter.dispose, adapter)
    if not disposeOk then
        disposeError = disposed
        disposed = false
    end
    if disposed == false then
        self._iconAdapter = adapter
        self._iconDataProvider = nil
        self._iconAdapterRecoveryPending = true
        return false, disposeError
    end
    return true
end

function DailyLevelMgr:_recoverPendingIconAdapter()
    if not self._iconAdapterRecoveryPending then return true end
    local adapter = self._iconAdapter
    if not adapter or type(adapter.dispose) ~= "function" then
        return false, "DAILY_LEVEL_ICON_V2_CLEANUP_OWNER_REQUIRED"
    end
    local disposeOk, disposed, disposeError = pcall(adapter.dispose, adapter)
    if not disposeOk then
        disposeError = disposed
        disposed = false
    end
    if disposed == false then return false, disposeError end
    self._iconAdapter = nil
    self._iconDataProvider = nil
    self._iconAdapterRecoveryPending = false
    return true
end

function DailyLevelMgr:refreshV2Icon(reason, payload)
    if not self:isV2IconActive() then return false end
    return self._iconAdapter:refresh(reason or "daily_level_refresh", payload)
end

function DailyLevelMgr:consumeCurrentCycleNew(reason)
    if not self:isV2IconActive() then return true end
    return self._iconAdapter:consumeCurrentCycleNew(reason)
end

function DailyLevelMgr:handleV2IconLifecycleBoundary(payload)
    if payload and payload.kind == "main_end" then
        return self:refreshV2Icon("main_end_boundary", payload)
    end
    if not payload or payload.kind ~= "activity_end" then
        return false, "DAILY_LEVEL_ICON_LIFECYCLE_BOUNDARY_INVALID"
    end

    local oldPeriodId = self:getDataValue("periodId", 0)
    local requested, promise = pcall(self.requestNextPeriodMainInfo, self, oldPeriodId, false)
    if not requested or not promise or type(promise.next) ~= "function" then
        self:removeIcon()
        return false, requested and "DAILY_LEVEL_ICON_PERIOD_REFRESH_PROMISE_REQUIRED" or promise
    end
    local chained, chainError = pcall(promise.next, promise, nil, function()
        self:removeIcon()
    end)
    if not chained then
        self:removeIcon()
        return false, chainError
    end
    return true
end

function DailyLevelMgr:_refreshMountedIcon(icon, reason)
    if self:isV2IconActive() then
        return self._iconAdapter:refresh(reason or "try_add")
    end
    if icon and not icon.isDisposed then
        icon:updateState()
        icon:updateCountdown()
        return true
    end
    return false
end

-- 尝试创建或刷新主场景入口 icon；入口判断不受 logicVersion 是否匹配影响。
function DailyLevelMgr:tryAddIcon()
    if not self:isIconEnabled() then return end
    local recovered = self:_recoverPendingIconAdapter()
    if not recovered then return end
    local icon = self._iconManager:getIconByIconKey(IconKey.kDailyLevel)
    if icon then
        self:dcQualify()
        self:_refreshMountedIcon(icon, "try_add_existing")
        return
    end
    if self._isIconLoading then return end
    self._isIconLoading = true
    local useV2 = self:isV2IconExperimentEnabled()
    local function createIcon()
        self._isIconLoading = false
        if not self:isIconEnabled() then return end
        local icon = self._iconManager:getIconByIconKey(IconKey.kDailyLevel)
        if icon then
            self:_refreshMountedIcon(icon, "asset_load_existing")
            return
        end
        local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
        if useV2 then
            local adapter, createError, cleanupOwner, provider = self:createPackageIconAdapter()
            if not adapter then
                local cleaned, cleanupError = self:_disposeUnpublishedIconAdapter(cleanupOwner)
                if ALog and type(ALog.strict_log_error) == "function" then
                    ALog.strict_log_error(
                        "[DailyLevelIconV2] create failed: " .. tostring(createError)
                            .. (cleaned and "" or ("; cleanup=" .. tostring(cleanupError)))
                    )
                end
                if not cleaned then return end
                icon = self:createLegacyIcon()
                IconEventCenter:addIconEvent(icon)
            else
                self._iconAdapter = adapter
                self._iconDataProvider = provider
                self._iconAdapterRecoveryPending = false
                icon = adapter:getIcon()
            end
        else
            icon = self:createLegacyIcon()
            IconEventCenter:addIconEvent(icon)
        end
        if icon then
            self:dcQualify()
            if not self:isV2IconActive() then
                self:tryAddNewIconActAutoPopup()
            end
        end
    end
    local function loadFailed()
        self._isIconLoading = false
        if useV2 then
            useV2 = false
            self._isIconLoading = true
            ResLoader:loadIconRes():next(createIcon, function()
                self._isIconLoading = false
            end)
        end
    end
    local loadPromise = useV2 and ResLoader:loadV2IconRes() or ResLoader:loadIconRes()
    loadPromise:next(createIcon, loadFailed)
end

-- 新活动自动弹出/红点动画的唯一 key，随活动版本变化。
function DailyLevelMgr:getUniqueKey()
    local uniqueKey = "daily_level_act_".. self:getDataValue("version", 0)
    return uniqueKey
end

-- 首次看到新活动时注册自动弹出，并播放入口 icon 的 new 标识动画。
function DailyLevelMgr:tryAddNewIconActAutoPopup()
    if self:isV2IconActive() then return end
    if not self:isActEnabled() then return end
    local iconBtn = _G.amfBean("IconManager"):getIconByIconKey(IconKey.kDailyLevel)
    if not iconBtn then return end
    local uniqueKey = self:getUniqueKey()
    local panelShowNum = _G.amfBean("AutoPopupMgr"):getPermanentShowNum(uniqueKey)
    if panelShowNum < 1 then
        iconBtn:playHasNewFlagAni()
        self.actAutoPopUniqueKey = uniqueKey
        _G.amfBean("PopupNewActMgr"):addNewAutoPopPkgAct(uniqueKey, IconKey.kDailyLevel, DailyLevelConst.ACT_NAME)
    end
end

function DailyLevelMgr:getActAutoPopUniqueKey()
    return self.actAutoPopUniqueKey
end

function DailyLevelMgr:clearActAutoPopUniqueKey()
    self.actAutoPopUniqueKey = nil
end

function DailyLevelMgr:clearNewActFlag()
    if self:isV2IconActive() then
        return self:consumeCurrentCycleNew("main_panel_opened")
    end
    local icon = self._iconManager:getIconByIconKey(IconKey.kDailyLevel)
    if icon then
        icon:stopHasNewFlagAni()
    end

    local uniqueKey = self:getActAutoPopUniqueKey() or self:getUniqueKey()
    if uniqueKey then
        _G.amfBean("PopupNewActMgr"):removeNewAutoPopPkgAct(uniqueKey)
        _G.amfBean("PopupNewActMgr"):sendPanelManualPopup(uniqueKey)
        local autoPopupMgr = _G.amfBean("AutoPopupMgr")
        if autoPopupMgr:getPermanentShowNum(uniqueKey) < 1 then
            autoPopupMgr:sendPermanentData(uniqueKey)
        end
    end
    self:clearActAutoPopUniqueKey()
end

function DailyLevelMgr:isActEnabled()
    return ActInfo:isEnabled()
end

function DailyLevelMgr:isIconEnabled()
    return ActInfo:isIconEnabled()
end

function DailyLevelMgr:getBeginTimeInSec()
    return TimeKit:tryConvertMsToSec(ActInfo:getExtraValue("beginTime", 0)) or 0
end

function DailyLevelMgr:getMainEndTimeInSec()
    return TimeKit:tryConvertMsToSec(ActInfo:getExtraValue("mainEndTime", 0)) or 0
end

function DailyLevelMgr:getEndTimeInSec()
    return TimeKit:tryConvertMsToSec(ActInfo:getExtraValue("endTime", 0)) or 0
end

function DailyLevelMgr:removeIcon()
    if self._iconAdapter then
        local adapter = self._iconAdapter
        local disposed, disposeError = self:_disposeUnpublishedIconAdapter(adapter)
        if disposed == false then return false, disposeError end
        self._iconAdapter = nil
        self._iconDataProvider = nil
        self._iconAdapterRecoveryPending = false
        return true
    end
    local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
    return IconEventCenter:removeIconEvent(IconKey.kDailyLevel)
end

function DailyLevelMgr:refreshIconAfterMainInfo(actTimeChanged)
    local icon = self._iconManager:getIconByIconKey(IconKey.kDailyLevel)
    if not icon then
        self:tryAddIcon()
        return
    end
    if self:isV2IconActive() then
        self:refreshV2Icon(actTimeChanged and "main_info_time_changed" or "main_info")
    else
        icon:updateState()
    end
    if actTimeChanged then
        if not self:isV2IconActive() then icon:updateCountdown() end
    end
    if not self:isIconEnabled() then
        self:removeIcon()
    end
end

-- 活动整体可用性：actInfo logicVersion/time 可用且主 info 已请求成功。
function DailyLevelMgr:isEnabled()
    -- 判断actInfo是否存在
    if not self:isActEnabled() then return false end
    -- 数据可用（时间+请求过）
    if not self._model or not self._model:isEnabled() then return false end
    return true
end

function DailyLevelMgr:hasMainInfoData()
    return self._model ~= nil and self:getDataValue("fromServer", false) == true
end

---------------------- 协议相关 start -----------------------
-- 从 ActivityMgr 读取当前活动的 actInfo 原始数据。
function DailyLevelMgr:getActInfo()
    return self._activityMgr and self._activityMgr:getActInfo(DailyLevelConst.ACT_ID)
end

-- 发起一次主 info 请求并解析返回数据。
function DailyLevelMgr:_requestMainInfo(
    loading,
    lightStart,
    deferActInvalidHandling,
    suppressTip,
    allowStalePeriodForRetry
)
    if lightStart == nil then lightStart = true end
    local d = deferred.new()
    self._model:requestMainInfo({
        lightStart = lightStart,
        logicVersion = ActInfo:getLogicVersion(),
        clientVersionedConfig = {
            clientMd5 = self:getConfigValue("serverMd5") or "",
        },
        packagesPullRequest = self:buildPackagePullParams(),
    }, loading):next(function(resp)
        local data = resp:getData() or {}
        local oldBeginTime = ActInfo:getExtraValue("beginTime")
        local oldMainEndTime = ActInfo:getExtraValue("mainEndTime")
        local oldEndTime = ActInfo:getExtraValue("endTime")
        self._model:parseMainInfo(data)
        self._hasHandledMainInfoActInvalid = false
        local actTimeChanged = tostring(oldBeginTime) ~= tostring(ActInfo:getExtraValue("beginTime"))
            or tostring(oldMainEndTime) ~= tostring(ActInfo:getExtraValue("mainEndTime"))
            or tostring(oldEndTime) ~= tostring(ActInfo:getExtraValue("endTime"))
        self:refreshIconAfterMainInfo(actTimeChanged)
        if not self:isActEnabled() and not allowStalePeriodForRetry then
            if loading and not suppressTip then
                CommonTip:showTip("当前游戏版本过低，请更新后参与活动")
            end
            d:reject(true)
            return
        end

        d:resolve()
    end, function(resp)
        local isActInvalid = self:isMainInfoActInvalidError(resp)
        if isActInvalid and not deferActInvalidHandling then
            self:handleMainInfoActInvalidError(suppressTip)
        end
        if not isActInvalid then
            _handleError(resp, loading, suppressTip)
        end
        d:reject(resp)
    end)
    return d
end

-- 请求主 info；领奖期没有宝箱或奖券可领时，先结算旧期，再拉取结算后生成的新一期数据。
function DailyLevelMgr:requestMainInfo(loading, skipAutoFinalReward, lightStart, suppressTip)
    if lightStart == nil then lightStart = true end
    return self:_requestMainInfo(loading, lightStart, nil, suppressTip):next(function()
        if skipAutoFinalReward or not self:isInAwardTime() or self:hasReward() then
            return deferred.success()
        end
        return self:requestFinalReward(loading, nil, suppressTip):next(function()
            return self:_requestMainInfo(loading, lightStart, nil, suppressTip)
        end)
    end)
end

-- 结算后拉取下一期数据。服务端换期可能存在短暂延迟，旧期数据不作为成功结果。
function DailyLevelMgr:requestNextPeriodMainInfo(oldPeriodId, loading)
    local d = deferred.new()
    local maxRequestCount = 3
    local requestCount = 0

    local function request()
        requestCount = requestCount + 1
        self:_requestMainInfo(loading, true, true, true, true):next(function()
            local periodId = self:getDataValue("periodId", 0)
            if tostring(periodId) ~= tostring(oldPeriodId) then
                d:resolve()
                return
            end
            if requestCount >= maxRequestCount then
                d:reject("daily level next period data is not ready")
                return
            end
            setTimeOut(request, 0.3)
        end, function(resp)
            d:reject(resp)
        end)
    end

    request()
    return d
end

-- 领取宝箱奖励：发放奖励并同步已领取宝箱进度。
function DailyLevelMgr:requestBoxReward(loading, panelId)
    local d = deferred.new()
    self._model:requestBoxReward({
        periodId = self:getDataValue("periodId", 0),
    }, loading):next(function(resp)
        local data = resp:getData() or {}
        local boxRewardList = data.boxRewardList or {}
        local allRewards = {}
        for _, boxReward in ipairs(boxRewardList) do
            for _, reward in ipairs(boxReward.rewardList or {}) do
                table.insert(allRewards, reward)
            end
        end
        self:addRewards(allRewards, DailyLevelConst.DC_FEATURE, "main_panel_reward")
        if data.maxClaimedBoxId then
            self:setDataValue("maxClaimedBoxId", data.maxClaimedBoxId)
        end
        self:refreshIconAfterMainInfo(false)
        local lastBoxId
        for _, boxReward in ipairs(boxRewardList) do
            local boxId = tonumber(boxReward.id)
            if boxId then
                lastBoxId = math.max(lastBoxId or boxId, boxId)
            end
        end
        if lastBoxId then
            local boxCycleBeginId = tonumber(self:getConfigValue("boxCycleBeginId"))
            local boxConfigList = self:getConfigValue("boxConfigList", {}) or {}
            local fixedBoxCount = 0
            local cycleBoxCount = 0
            for _, config in ipairs(boxConfigList) do
                local boxId = tonumber(config.id)
                if boxId then
                    if boxCycleBeginId and boxId >= boxCycleBeginId then
                        cycleBoxCount = cycleBoxCount + 1
                    else
                        fixedBoxCount = math.max(fixedBoxCount, boxId)
                    end
                end
            end
            local totalBoxId = fixedBoxCount
            if boxCycleBeginId and cycleBoxCount > 0 and lastBoxId >= boxCycleBeginId then
                local cycleIndex = math.floor((lastBoxId - boxCycleBeginId) / cycleBoxCount)
                totalBoxId = boxCycleBeginId + (cycleIndex + 1) * cycleBoxCount - 1
            end
            self:dcJoin()
            self:dc("daily_treasure", "main_panel_reward", {
                panel_id = panelId,
                t1 = tostring(lastBoxId) .. "_" .. tostring(totalBoxId),
            })
        end
        d:resolve({
            boxRewardList = boxRewardList,
        })
    end, function(resp)
        _handleError(resp, loading)
        d:reject(resp)
    end)
    return d
end

-- 请求开奖奖励：聚合 settledRewardsInfo 中的奖励发放，但 resolve 保持原 settledRewardsInfo 结构给表现层。
function DailyLevelMgr:requestFinalReward(loading, dcData, suppressTip)
    local d = deferred.new()
    self._model:requestFinalReward({
        periodId = self:getDataValue("periodId", 0),
    }, loading):next(function(resp)
        local data = resp:getData() or {}
        local settledRewardsInfo = ((data.lastPeriodSettleData or {}).settledRewardsInfo) or {}
        local rewardList = {}
        for _, rewardsInfo in ipairs(settledRewardsInfo) do
            for _, reward in ipairs(rewardsInfo.rewards or {}) do
                table.insert(rewardList, reward)
            end
        end
        self:addRewards(rewardList, DailyLevelConst.DC_FEATURE, "main_panel_draw")
        if dcData then
            local hasGoldReward = false
            for _, reward in ipairs(rewardList) do
                if reward.itemId == AMFPropId.GOLD and (tonumber(reward.num) or 0) > 0 then
                    hasGoldReward = true
                    break
                end
            end
            self:dcJoin()
            self:dc("daily_treasure", "main_panel_draw", {
                panel_id = dcData.panelId,
                t1 = dcData.goldTicketNum or 0,
                t2 = dcData.normalTicketNum or 0,
                t3 = hasGoldReward and 1 or 0,
            })
        end
        d:resolve(settledRewardsInfo)
    end, function(resp)
        _handleError(resp, loading, suppressTip)
        d:reject(resp)
    end)
    return d
end

-- 构造 GoodsManager package pull 参数，随主 info 一起请求奖券/翻倍相关商品包。
function DailyLevelMgr:buildPackagePullParams(wants, jump)
    return {
        scene = "activity_scene",
        queryParams = {
            dailyLevelGamePlay = table.serialize({
                moduleVersion = 0,
                wants = wants or {"TICKET", "DOUBLE_COLLECT"},
                jump = jump,
            }),
        },
        commonParams = {
            sceneVersion = "0",
        },
    }
end

---------------------- 协议相关 end -----------------------
function DailyLevelMgr:getPeriodGuideId(guideId)
    local periodId = self:getDataValue("periodId")
    if not periodId or not guideId then return nil end
    return tonumber(tostring(periodId) .. tostring(guideId))
end

function DailyLevelMgr:hasGuide(guideId)
    local periodGuideId = self:getPeriodGuideId(guideId)
    if not periodGuideId then return false end
    for _, recordedGuideId in ipairs(self:getDataValue("guideIds", {}) or {}) do
        if tonumber(recordedGuideId) == periodGuideId then return true end
    end
    return false
end

function DailyLevelMgr:markGuide(guideId)
    local periodGuideId = self:getPeriodGuideId(guideId)
    if not periodGuideId or self:hasGuide(guideId) then return false end

    local guideIds = self:getDataValue("guideIds", {}) or {}
    table.insert(guideIds, periodGuideId)
    self:setDataValue("guideIds", guideIds)

    if not _G.__DailyLevelFlowTestRunning then
        local ActCommonHttp = require "amf.middleware.activity.http.ActCommonHttp"
        ActCommonHttp:setActGuideFlag(DailyLevelConst.ACT_ID, periodGuideId)
    end
    return true
end

function DailyLevelMgr:hasOnceGuide(guideId)
    if not guideId then return false end
    for _, recordedGuideId in ipairs(self:getDataValue("guideIds", {}) or {}) do
        if tonumber(recordedGuideId) == tonumber(guideId) then return true end
    end
    return false
end

function DailyLevelMgr:markOnceGuide(guideId)
    if not guideId or self:hasOnceGuide(guideId) then return false end

    local guideIds = self:getDataValue("guideIds", {}) or {}
    table.insert(guideIds, guideId)
    self:setDataValue("guideIds", guideIds)

    if not _G.__DailyLevelFlowTestRunning then
        local ActCommonHttp = require "amf.middleware.activity.http.ActCommonHttp"
        ActCommonHttp:setActGuideFlag(DailyLevelConst.ACT_ID, guideId)
    end
    return true
end
-- 红点数量：仅活动正式期展示今日可用门票数量，领奖期返回 0。
function DailyLevelMgr:getMsgNum()
    if not self._model or not self._model:isInMainTime() then return 0 end
    return (self:getDataValue("freeCanPlayNum", 0) or 0) + (self:getDataValue("payCanPlayNum", 0) or 0)
end

function DailyLevelMgr:checkIconTip(config)
    if not self:isEnabled() or self:getMsgNum() <= 0 then return end

    local IconTipEventCenter = require "amf.feature.icontip.event.IconTipEventCenter"
    IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, {
        iconKey = IconKey.kDailyLevel,
        iconType = IconTipType.MESSAGE,
        typeIndex = 1,
        creatorDelegate = {
            tipsType = HomeIconTipsType.ONLY_TEXT,
            text = "每日夺宝等你来玩",
        },
        config = config,
    })
end

-- 根据累计收集物计算当前已达到领取条件的最大宝箱 id。
function DailyLevelMgr:getMaxClaimableBoxId()
    return self:getMaxClaimableBoxIdByCollectNum(self:getDataValue("collectNum", 0))
end

function DailyLevelMgr:getMaxClaimableBoxIdByCollectNum(collectNum)
    collectNum = math.max(tonumber(collectNum) or 0, 0)
    local boxConfigList = self:getConfigValue("boxConfigList", {}) or {}
    local boxCycleBeginId = tonumber(self:getConfigValue("boxCycleBeginId"))
    local fixedConfigList = {}
    local cycleConfigList = {}

    for _, config in ipairs(boxConfigList) do
        local id = tonumber(config.id)
        if id then
            local targetList = fixedConfigList
            if boxCycleBeginId and id >= boxCycleBeginId then
                targetList = cycleConfigList
            end
            table.insert(targetList, {
                id = id,
                target = math.max(tonumber(config.target) or 0, 0),
            })
        end
    end

    local function sortById(a, b)
        return a.id < b.id
    end
    table.sort(fixedConfigList, sortById)
    table.sort(cycleConfigList, sortById)

    local usedCollectNum = 0
    local maxId = 0
    for _, config in ipairs(fixedConfigList) do
        usedCollectNum = usedCollectNum + config.target
        if collectNum < usedCollectNum then
            return maxId
        end
        maxId = config.id
    end

    if not boxCycleBeginId or #cycleConfigList == 0 then
        return maxId
    end

    local cycleTarget = 0
    for _, config in ipairs(cycleConfigList) do
        cycleTarget = cycleTarget + config.target
    end
    if cycleTarget <= 0 then
        return maxId
    end

    local remainCollectNum = collectNum - usedCollectNum
    local completedCycleNum = math.floor(remainCollectNum / cycleTarget)
    maxId = boxCycleBeginId - 1 + completedCycleNum * #cycleConfigList
    remainCollectNum = remainCollectNum - completedCycleNum * cycleTarget

    for _, config in ipairs(cycleConfigList) do
        if remainCollectNum < config.target then
            break
        end
        remainCollectNum = remainCollectNum - config.target
        maxId = maxId + 1
    end

    return maxId
end

-- 展开固定和循环宝箱配置，并将单段 target 转成累计目标值。
function DailyLevelMgr:getBoxProgressConfigList(maxId)
    maxId = math.max(tonumber(maxId) or 0, 0)
    local boxConfigList = self:getConfigValue("boxConfigList", {}) or {}
    local boxCycleBeginId = tonumber(self:getConfigValue("boxCycleBeginId"))
    local fixedConfigList = {}
    local cycleConfigList = {}

    for _, config in ipairs(boxConfigList) do
        local id = tonumber(config.id)
        if id then
            local targetList = fixedConfigList
            if boxCycleBeginId and id >= boxCycleBeginId then
                targetList = cycleConfigList
            end
            table.insert(targetList, config)
        end
    end

    local function sortById(a, b)
        return tonumber(a.id) < tonumber(b.id)
    end
    table.sort(fixedConfigList, sortById)
    table.sort(cycleConfigList, sortById)

    local result = {}
    local totalTarget = 0
    local function appendConfig(config, id)
        totalTarget = totalTarget + math.max(tonumber(config.target) or 0, 0)
        table.insert(result, {
            id = id,
            type = tonumber(config.type),
            target = totalTarget,
            rewardList = config.rewardList or config.rewards or {},
        })
    end

    for _, config in ipairs(fixedConfigList) do
        local id = tonumber(config.id)
        if id > maxId then return result end
        appendConfig(config, id)
    end

    if not boxCycleBeginId or #cycleConfigList == 0 then
        return result
    end

    local id = boxCycleBeginId
    while id <= maxId do
        local cycleIndex = (id - boxCycleBeginId) % #cycleConfigList + 1
        appendConfig(cycleConfigList[cycleIndex], id)
        id = id + 1
    end

    return result
end

-- 是否有可领奖内容：宝箱在正式期/领奖期都判断，领奖期额外判断金奖券/普通奖券。
function DailyLevelMgr:hasReward()
    local maxClaimedBoxId = self:getDataValue("maxClaimedBoxId", self:getDataValue("maxClaimedBoxId", 0)) or 0
    if self:getMaxClaimableBoxId() > maxClaimedBoxId then
        return true
    end

    if self._model and self._model:isInAwardTime() then
        return (self:getDataValue("goldTicketNum", 0) or 0) > 0 or (self:getDataValue("normalTicketNum", 0) or 0) > 0
    end

    return false
end

function DailyLevelMgr:canClaimAwardReward()
    local maxClaimedBoxId = self:getDataValue("maxClaimedBoxId", 0) or 0
    if self:getMaxClaimableBoxId() > maxClaimedBoxId then
        return true
    end
    return (self:getDataValue("goldTicketNum", 0) or 0) > 0
        or (self:getDataValue("normalTicketNum", 0) or 0) > 0
end

-- 统一奖励发放入口，走 GainPropData 发货链路。
function DailyLevelMgr:addRewards(rewardList, feature, source)
    if table.isEmpty(rewardList) then return end
    local f = feature or ""
    local s = source or ""
    _G.GainPropData:create()
        :setFeature(f)
        :setSource(s)
        :setProps(rewardList)
        :execute()
end

-- 打关结束更新收集物数量；失败结算不加收集物。
function DailyLevelMgr:updatePassLevelData(data, collectionCount)
   --结算失败时不给收集物
    if data.settleMentState and collectionCount and collectionCount > 0 then
        self:setDataValue("collectNum", (self:getDataValue("collectNum", 0) or 0) + collectionCount)
        self:refreshV2Icon("pass_level_collect", {collectionCount = collectionCount})
    end
end

-- 进关成功后扣闯关次数：优先扣免费次数，再扣购买次数，奖券数量不变。
function DailyLevelMgr:consumePlayCount()
    local freeCanPlayNum = self:getDataValue("freeCanPlayNum", 0) or 0
    local payCanPlayNum = self:getDataValue("payCanPlayNum", 0) or 0
    if freeCanPlayNum > 0 then
        self:setDataValue("freeCanPlayNum", freeCanPlayNum - 1)
    elseif payCanPlayNum > 0 then
        self:setDataValue("payCanPlayNum", payCanPlayNum - 1)
    end
    self:refreshV2Icon("consume_play_count")
end

function DailyLevelMgr:getPackageIdByBuyType(buyType)
    local packageMetaList = self:getConfigValue("packagePriceMetaList", {}) or {}
    local buyPackageMap = self:getDataValue("buyPackageMap", {}) or {}
    local matchedMetaList = {}
    local buyTimes = 0
    for _, meta in ipairs(packageMetaList) do
        if meta.buyType == buyType and meta.packageId then
            table.insert(matchedMetaList, meta)
            buyTimes = buyTimes + (tonumber(buyPackageMap[tostring(meta.packageId)] or buyPackageMap[meta.packageId]) or 0)
        end
    end
    table.sort(matchedMetaList, function(a, b)
        local aMinBuyTimes = tonumber(a.minBuyTimes) or -1
        local bMinBuyTimes = tonumber(b.minBuyTimes) or -1
        if aMinBuyTimes == -1 then return false end
        if bMinBuyTimes == -1 then return true end
        return aMinBuyTimes < bMinBuyTimes
    end)

    for _, meta in ipairs(matchedMetaList) do
        local minBuyTimes = tonumber(meta.minBuyTimes) or -1
        if minBuyTimes == -1 or buyTimes <= minBuyTimes then
            return tonumber(meta.packageId) or meta.packageId
        end
    end
    return nil
end

function DailyLevelMgr:addPackageBuyTimes(packageId)
    if not packageId then return end
    local buyPackageMap = table.clone(self:getDataValue("buyPackageMap", {}) or {})
    local key = tostring(packageId)
    buyPackageMap[key] = (tonumber(buyPackageMap[key] or buyPackageMap[packageId]) or 0) + 1
    if key ~= packageId then buyPackageMap[packageId] = nil end
    self:setDataValue("buyPackageMap", buyPackageMap)
end

function DailyLevelMgr:buyPlayCount(packageId, showId, successCallback, failCallback, cancelCallback)
    local goodsObj = GoodsManager:getGoods(packageId)
    if not goodsObj then
        safeRunCall(failCallback)
        return
    end

    local buyContext = BuyContext.new(packageId, goodsObj:getMoneyType())
        :setShowId(showId)
        :setFeatureAndSource(DailyLevelConst.DC_FEATURE, "play_pay")
        :setActivityId(DailyLevelConst.ACT_ID)
        :setGoldNotEnough(nil, StoreConfig.AccurateSource.Auto_DailyLevel, nil)
        :setUnifiedBuy(true, GiftPackageConst.StageType.ACTIVITY, "dailyLevelGamePlay")
        :setBuyCount(1)
        :setCallback(successCallback, failCallback, cancelCallback)
    _G.amfTransaction(AMFEventConst.TransactionType.PAY, buyContext)
end

function DailyLevelMgr:buyDoubleCollect(packageId, showId, successCallback, failCallback, cancelCallback)
    local goodsObj = GoodsManager:getGoods(packageId)
    if not goodsObj then
        safeRunCall(failCallback)
        return
    end

    local buyContext = BuyContext.new(packageId, goodsObj:getMoneyType())
        :setShowId(showId)
        :setFeatureAndSource(DailyLevelConst.DC_FEATURE, "double_gift")
        :setActivityId(DailyLevelConst.ACT_ID)
        :setGoldNotEnough(nil, StoreConfig.AccurateSource.Auto_DailyLevel, nil)
        :setUnifiedBuy(true, GiftPackageConst.StageType.ACTIVITY, "dailyLevelGamePlay")
        :setBuyCount(1)
        :setCallback(successCallback, failCallback, cancelCallback)
    _G.amfTransaction(AMFEventConst.TransactionType.PAY, buyContext)
end

-- 当前是否处于正式活动期。
function DailyLevelMgr:isInMainTime()
    return self._model and self._model:isInMainTime()
end

-- 当前是否处于领奖期。
function DailyLevelMgr:isInAwardTime()
    return self._model and self._model:isInAwardTime()
end
---------------------- 数据修改获取相关 start ------------------
-- 写活动主数据字段。
function DailyLevelMgr:setDataValue(key, value)
    return self._model and self._model:setValue("data."..key, value)
end

-- 读活动主数据字段。
function DailyLevelMgr:getDataValue(key, default)
    return self._model and self._model:getValue("data."..key) or default
end

-- 读服务端版本配置字段。
function DailyLevelMgr:getConfigValue(key, default)
    return self._model and self._model:getValue("localConfig."..key) or default
end

-- 写本地缓存字段。
function DailyLevelMgr:setLocalValue(key, value)
    return self._model and self._model:setValue("localCache."..key, value)
end

-- 读本地缓存字段。
function DailyLevelMgr:getLocalValue(key, default)
    return self._model and self._model:getValue("localCache."..key) or default
end
---------------------- 数据修改获取相关 end ---------------------

---------------------- 关卡内相关 start----------------------
-- 本次打关是否需要开启活动
function DailyLevelMgr:isEnabledInLevel(runtime)
    if not self:isEnabled() then return false end

    return true
end

-- 根据actInfo数据来判断
function DailyLevelMgr:isCanCrashResume()
    return not ActInfo:isRecoveryBanned()
end

function DailyLevelMgr:onActJudgeHasCrashResume(event)
    local data = event:getData()
    if data.levelScene ~= UBFLevelSceneType.kDailyLevelGameplay then return end
    if not self:isEnabled() then return end
    if not data or not data.resumeData then return end
    local resumeData = data.resumeData
    if resumeData:hasGameMod(DailyLevelConst.ACT_ID) then 
        if not self:isCanCrashResume() then 
            data.hasCrashResume = false
            data.crashResumeFailReason = UBFGameResumeFailReason and UBFGameResumeFailReason.kActivityRefuse or 28
            return true
        end
    end
end

function DailyLevelMgr:onActCreateResumePanel(evt)
    local data = evt:getData()
    if data.levelScene ~= UBFLevelSceneType.kDailyLevelGameplay then return end
    if not data.outData then return end
    local outData = data.outData
    outData.levelNameStr = "【每日夺宝关】"
end

--闪退不恢复
function DailyLevelMgr:onActCrashResumeFailed(event)
    local data = event:getData()
    if not data or not data.resumeData or not data.levelId then return end
    if data.levelScene ~= UBFLevelSceneType.kDailyLevelGameplay then return end

    local resumeData = data.resumeData
    -- 闪退恢复里有本活动的数据
    if resumeData:hasGameMod(UBFActivityIdConst.kDailyLevelGameplay) then
        local actData = resumeData:getActData(DailyLevelConst.ACT_ID)
        -- local actModData = resumeData:getGameMod(DailyLevelConst.ACT_ID)
        if data.json and actData  then
            local jsonTable =  {
                entryLevelIds = actData.entryLevelIds,
                finishLevelIds = actData.finishLevelIds,
            }
            data.json[tostring(DailyLevelConst.ACT_ID)] = jsonTable
        end
    end

    return true
end

--过关强弹
function DailyLevelMgr:onActEndlevelProgressPrepare( evt )
	local data = evt:getData()
	if not data or not data.runtime then
		return
	end
	local runtime = data.runtime
    local levelScene = runtime:getLevelScene()
    if levelScene ~= UBFLevelSceneType.kDailyLevelGameplay then return end

    
    -- 1.判断本次打关是否有效
    local modEndLevelData = runtime:getEndLevelModData(UBFActivityIdConst.kDailyLevelGameplay)
    local passLevelJson = modEndLevelData and modEndLevelData.passLevelJson
    if not passLevelJson or not passLevelJson.collectionInfo then return end
    local collectionInfo = passLevelJson.collectionInfo
    local curLevelCollectNum = collectionInfo["188"] and collectionInfo["188"]["totalCount"]
    self.curLevelCollectNum = curLevelCollectNum
    local bCanPop = self.curLevelCollectNum and self.curLevelCollectNum > 0
	if bCanPop then 
		runtime:setEnabledProcessNodes(UBFActivityIdConst.kDailyLevelGameplay, {
	        [UBFProcessNodeEnum.DAILYLEVEL_GAME_PLAY] = {
	            -- 流程节点是否可以启动
	            isProcessEnabled = true
	        },
	    })
	end
end

function DailyLevelMgr:onActEndlevelProgressThirdPartStart(evt)
	local data = evt:getData()
	if not data then
		return
	end
    local processNodeKey = data.processNodeKey
    if processNodeKey == UBFProcessNodeEnum.DAILYLEVEL_GAME_PLAY then
        if not self.curLevelCollectNum or self.curLevelCollectNum <= 0 then
            data:finishProcessCallBack()
            return
        end

        local finished = false
        local function closeCallback()
            if finished then return end
            finished = true
            self.curLevelCollectNum = nil
            data:finishProcessCallBack()
        end
        local GemBoomShowPanelVM = require "amf.feature.localactivity.dailylevel.view.GemBoomShowPanelVM"
        local packageId = self:getPackageIdByBuyType(DailyLevelConst.PackageBuyType.DOUBLE_COLLECT)
        local panelVM = GemBoomShowPanelVM:create({
            mgr = self,
            collectNum = self.curLevelCollectNum,
            collectionItemId = DailyLevelConst.COLLECTION_ID,
            packageId = packageId,
            closeCallback = closeCallback,
        })
        panelVM:setLoadResFailCallback(function()
            closeCallback()
        end)
        panelVM:setUBFPopDelegate({
            popout = function(panel)
                data:popoutView(panel, UBFProcessNodePopLayerType.POPOUT)
            end,
            removePopout = function(panel)
                data:removeView(panel)
            end,
        })
        panelVM:popout()
        self:managePanelVM(panelVM)
    else
    end
end

function DailyLevelMgr:onActEndlevelProgressForceComplete( evt )
	local data = evt:getData()
	local processNodeKey = data.processNodeKey
	if processNodeKey == UBFProcessNodeEnum.DAILYLEVEL_GAME_PLAY then
		--当前节点被强制流转时，是否需要数据处理，没有处理的逻辑可以不写，随后视图会被强行删除
	end
end

---------------------- 关卡内相关 end----------------------

return DailyLevelMgr
