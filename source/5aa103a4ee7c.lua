require "amf.feature.accountbind.phonebind.module.phonebindact.config.PhoneBindActConst"
local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local PhoneBindActModel =  require "amf.feature.accountbind.phonebind.module.phonebindact.model.PhoneBindActModel"
local PhoneBindDC = require "amf.feature.accountbind.phonebind.dc.PhoneBindDC"
local ExitGameEventCenter = require "amf.middleware.exit.event.ExitGameEventCenter"
local FruitTreeEventCenter = require "amf.feature.fruittree.event.FruitTreeEventCenter"
local PhoneBindActManager = class("PhoneBindActManager")

local ICON_V2_EXPERIMENT_MODULE = "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"
local ICON_V2_ASSET_PATH = "amf/accountbind/icon/phone_bind_app_v2.png"
local ADAPTER_CREATE_READY = "ready"
local ADAPTER_CREATE_SAFE_LEGACY = "safe_legacy"
local ADAPTER_CREATE_WAIT_OWNER = "wait_owner"
local ADAPTER_STATE_NONE = "none"
local ADAPTER_STATE_V2 = "v2_mounted"
local ADAPTER_STATE_LEGACY = "legacy_mounted"
local ADAPTER_STATE_CLEANUP = "cleanup_required"
local ADAPTER_STATE_BLOCKED = "blocked"

local function isIconAlive(icon)
    if not icon or icon.isDisposed then
        return false
    end
    if type(isSafeCocosObj) == "function" then
        return isSafeCocosObj(icon)
    end
    return true
end

local function logIconV2Error(message)
    if ALog and type(ALog.strict_log_error) == "function" then
        ALog.strict_log_error("[PhoneBindAppIconV2] " .. tostring(message))
    end
end

local function callAdapterMethod(adapter, methodName, ...)
    local method = adapter and adapter[methodName]
    if type(method) ~= "function" then
        return false, nil, "PHONE_BIND_APP_ICON_ADAPTER_METHOD_REQUIRED:" .. tostring(methodName)
    end
    local ok, result, detail = pcall(method, adapter, ...)
    if not ok then
        return false, nil, result
    end
    return true, result, detail
end

local function resolveAdapterState(adapter)
    if not adapter then
        return ADAPTER_STATE_NONE
    end
    local mountedOk, mounted, mountedError = callAdapterMethod(adapter, "isMounted")
    if not mountedOk then
        return ADAPTER_STATE_BLOCKED, mountedError
    end
    if mounted ~= true then
        return ADAPTER_STATE_CLEANUP
    end
    local activeOk, active, activeError = callAdapterMethod(adapter, "isV2Active")
    if not activeOk then
        return ADAPTER_STATE_BLOCKED, activeError
    end
    return active == true and ADAPTER_STATE_V2 or ADAPTER_STATE_LEGACY
end

local function getAdapterIcon(adapter)
    local called, icon, callError = callAdapterMethod(adapter, "getIcon")
    if not called then
        return nil, callError
    end
    return icon
end

local function disposeAdapter(adapter)
    local called, disposed, disposeError = callAdapterMethod(adapter, "dispose")
    if not called then
        return false, disposeError
    end
    if disposed ~= true then
        return false, disposeError or "PHONE_BIND_APP_ICON_ADAPTER_DISPOSE_FAILED"
    end
    return true
end

local function refreshAdapter(adapter, reason, payload)
    local called, refreshed, refreshError = callAdapterMethod(adapter, "refresh", reason, payload)
    if not called then
        return false, refreshError
    end
    if refreshed == false then
        return false, refreshError
    end
    return refreshed, refreshError
end

function PhoneBindActManager:initialize(phoneBindManager)
    self._phoneBindManager = phoneBindManager
    self._model = PhoneBindActModel:create()
    self._iconAdapterRecoveryPending = false
    self._iconV2AssetReady = false
    self._iconV2AssetLoading = false
    self:tryRegisterEvent()
end

function PhoneBindActManager:reset()
    self:tryRemoveEvent()
    if self.iconAdapter then
        self:removeIconIfExist()
    end
end

function PhoneBindActManager:_loadV2IconAsset()
    if self._iconV2AssetReady then return self:addIconIfNotExist() end
    if self._iconV2AssetLoading then return end

    self._iconV2AssetLoading = true
    _G.amfBean("AssetsUtil"):loadMiniFiles({ICON_V2_ASSET_PATH}, true):next(function()
        self._iconV2AssetLoading = false
        self._iconV2AssetReady = true
        if self._phoneBindManager and self._phoneBindManager:checkPhoneBindEnabled() then
            self:addIconIfNotExist()
        end
    end, function(loadError)
        self._iconV2AssetLoading = false
        logIconV2Error("asset load failed: " .. tostring(loadError))
    end)
end

function PhoneBindActManager:tryRegisterEvent()
    self:tryRemoveEvent()
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)

    FruitTreeEventCenter:register(FruitTreeEvent.BIND_PHONE_NUMBER, self.onBindPhoneNumberByFruitTree, self)
    ExitGameEventCenter:register(ExitGameEvent.SHOW_EXIT_GAME_PANEL, self.showExitGameBindPanel, self, ExitGameEventPriority.ExitGame.SHOW_EXIT_GAME_BIND_PANEL)
    IconEventCenter:register(IconEvent.ICON_SYSTEM_READY, self.onIconSystemReady, self)
end

function PhoneBindActManager:tryRemoveEvent()
    _G.amfEC:unregisterFeature(self)
    _G.amfEC:unregisterSystem(self)
    FruitTreeEventCenter:unregister(FruitTreeEvent.BIND_PHONE_NUMBER, self.onBindPhoneNumberByFruitTree)
    ExitGameEventCenter:unregister(ExitGameEvent.SHOW_EXIT_GAME_PANEL, self.showExitGameBindPanel)
    IconEventCenter:unregister(IconEvent.ICON_SYSTEM_READY, self.onIconSystemReady)
end

function PhoneBindActManager:onIconSystemReady()
    self:tryUpdateIcon()
end

function PhoneBindActManager:onSystemEnterForeground()
    self:tryUpdateIcon()
end

function PhoneBindActManager:tryUpdateIcon()
    if not self._phoneBindManager or
            not self._phoneBindManager:checkPhoneBindEnabled() then
        self:removeIconIfExist()
        return
    end
    if self._iconAdapterRecoveryPending then
        return self:addIconIfNotExist()
    end
    if self.iconAdapter then
        local adapterState = resolveAdapterState(self.iconAdapter)
        if adapterState == ADAPTER_STATE_V2 then
            local refreshed, refreshError = refreshAdapter(self.iconAdapter, "eligibility_update")
            if refreshed == false then
                logIconV2Error("refresh failed: " .. tostring(refreshError))
            end
            return refreshed, refreshError
        end
        if adapterState == ADAPTER_STATE_LEGACY then
            return self.icon
        end
        return self:addIconIfNotExist()
    end
    return self:addIconIfNotExist()
end

function PhoneBindActManager:isV2IconExperimentEnabled()
    local ok, enabled = pcall(function()
        local experiment = require(ICON_V2_EXPERIMENT_MODULE)
        return experiment:isEnabled()
    end)
    return ok and enabled == true
end

function PhoneBindActManager:createLegacyIcon()
    local PhoneBindingIcon = require "amf.feature.accountbind.phonebind.module.phonebindact.view.PhoneBindingIcon"
    return PhoneBindingIcon:create()
end

function PhoneBindActManager:createPackageIconAdapter()
    local adapterLoaded, PackageIconV2Adapter = pcall(
        require,
        "amf.feature.mainscene.module.icon.v2.runtime.PackageIconV2Adapter"
    )
    if not adapterLoaded then
        return {
            state = ADAPTER_CREATE_SAFE_LEGACY,
            error = PackageIconV2Adapter,
        }
    end
    if type(PackageIconV2Adapter.create) ~= "function" then
        return {
            state = ADAPTER_CREATE_SAFE_LEGACY,
            error = "PHONE_BIND_APP_ICON_V2_ADAPTER_CREATE_REQUIRED",
        }
    end

    local ownerIconKey = IconKey.kPhoneBind
    local configOk, options, provider = pcall(function()
        local IconV2Config = require "amf.feature.accountbind.phonebind.module.phonebindact.icon.IconV2Config"
        local configOptions, configProvider = IconV2Config.create(self, IconEventCenter)
        assert(type(configOptions) == "table", configProvider or "PHONE_BIND_APP_ICON_V2_CONFIG_REQUIRED")
        return configOptions, configProvider
    end)
    if not configOk then
        local configError = options
        options = {
            ownerIconKey = ownerIconKey,
            iconEventCenter = IconEventCenter,
            legacyFactory = function()
                return self:createLegacyIcon()
            end,
            v2PreflightError = configError,
        }
        provider = nil
    end

    local createOk, adapter, modeOrError, cleanupOwner = pcall(
        PackageIconV2Adapter.create,
        PackageIconV2Adapter,
        options
    )
    if not createOk then
        return {
            state = ADAPTER_CREATE_WAIT_OWNER,
            error = adapter,
        }
    end
    if not adapter then
        return {
            state = ADAPTER_CREATE_WAIT_OWNER,
            error = modeOrError,
            cleanupOwner = cleanupOwner,
        }
    end
    return {
        state = ADAPTER_CREATE_READY,
        adapter = adapter,
        provider = provider,
        mode = modeOrError,
    }
end

function PhoneBindActManager:_adoptIconAdapter(adapter, provider, recoveryPending)
    self.iconAdapter = adapter
    local adapterState, stateError = resolveAdapterState(adapter)
    local icon, iconError = getAdapterIcon(adapter)
    self.icon = icon
    self.iconDataProvider = adapterState == ADAPTER_STATE_V2 and provider or nil
    self._iconAdapterRecoveryPending = recoveryPending == true
        or adapterState == ADAPTER_STATE_CLEANUP
        or adapterState == ADAPTER_STATE_BLOCKED
        or iconError ~= nil
    if stateError then
        logIconV2Error("adapter state failed: " .. tostring(stateError))
    end
    if iconError then
        logIconV2Error("adapter icon failed: " .. tostring(iconError))
    end
end

function PhoneBindActManager:_disposeIconAdapter()
    local adapter = self.iconAdapter
    if not adapter then
        return true
    end
    local disposed, disposeError = disposeAdapter(adapter)
    if not disposed then
        local icon, iconError = getAdapterIcon(adapter)
        if not iconError then
            self.icon = icon
        end
        self._iconAdapterRecoveryPending = true
        logIconV2Error("dispose failed: " .. tostring(disposeError or iconError))
        return false, disposeError or iconError
    end
    self.iconAdapter = nil
    self.iconDataProvider = nil
    self.icon = nil
    self._iconAdapterRecoveryPending = false
    return true
end

function PhoneBindActManager:_recoverPendingIconAdapter()
    if not self._iconAdapterRecoveryPending or not self.iconAdapter then
        return true
    end
    return self:_disposeIconAdapter()
end

function PhoneBindActManager:addIconIfNotExist()
    local recovered = self:_recoverPendingIconAdapter()
    if recovered == false then
        return self.icon
    end
    if self.iconAdapter then
        local adapterState, stateError = resolveAdapterState(self.iconAdapter)
        if adapterState == ADAPTER_STATE_V2 or adapterState == ADAPTER_STATE_LEGACY then
            local icon, iconError = getAdapterIcon(self.iconAdapter)
            if iconError then
                self._iconAdapterRecoveryPending = true
                logIconV2Error("mounted adapter icon failed: " .. tostring(iconError))
                return self.icon
            end
            self.icon = icon
            self._iconAdapterRecoveryPending = false
            return self.icon
        end
        if stateError then
            logIconV2Error("adapter state failed before recovery: " .. tostring(stateError))
        end
        local disposed = self:_disposeIconAdapter()
        if disposed == false then
            return self.icon
        end
    end
    if isIconAlive(self.icon) then return self.icon end

    if self:isV2IconExperimentEnabled() or self._iconAdapterRecoveryPending then
        if not self._iconV2AssetReady and EnvUtil:isUnity() then
            return self:_loadV2IconAsset()
        end
        local createResult = self:createPackageIconAdapter()
        local ownerAdapter = createResult.adapter or createResult.cleanupOwner
        if ownerAdapter then
            self:_adoptIconAdapter(
                ownerAdapter,
                createResult.provider,
                createResult.state == ADAPTER_CREATE_WAIT_OWNER
            )
            if not createResult.adapter then
                logIconV2Error("create pending cleanup: " .. tostring(createResult.error))
            end
            return self.icon
        end
        if createResult.state ~= ADAPTER_CREATE_SAFE_LEGACY then
            self._iconAdapterRecoveryPending = true
            logIconV2Error("create waiting for owner recovery: " .. tostring(createResult.error))
            return nil
        end
        self._iconAdapterRecoveryPending = false
        logIconV2Error("adapter unavailable, fallback legacy: " .. tostring(createResult.error))
    end

    self._iconAdapterRecoveryPending = false
    self.icon = self:createLegacyIcon()
    IconEventCenter:addIconEvent(self.icon)
    return self.icon
end

function PhoneBindActManager:removeIconIfExist()
    if self.iconAdapter then
        return self:_disposeIconAdapter()
    end

    if isIconAlive(self.icon) then
        IconEventCenter:removeIconEvent(IconKey.kPhoneBind)
    end
    self.icon = nil
    self._iconAdapterRecoveryPending = false
    return true
end

function PhoneBindActManager:popEnabledInStage4()
    if not self._phoneBindManager or
            not self._phoneBindManager:checkPhoneBindEnabled() then
        return false
    end
    if PlatformConfig:isPlatform(PlatformNameEnum.kOppo) then
        return false
    end
    if self._model:getStage4PopFlag() then
        return false
    end
    return true
end


function PhoneBindActManager:popBindPhonePanel(delegate)
    local onBindSuccess = delegate.onBindSuccess
    local onBindFail = delegate.onBindFail
    local closeCallback = delegate.closeCallback
    local source = delegate.source
    local ignorePopTime = delegate.ignorePopTime
    if ignorePopTime == nil then
        ignorePopTime = false
    end
    if not self._phoneBindManager:popTimeUpdate() and not ignorePopTime then
        safeRunCall(closeCallback)
        return false
    end
    local tbl = self._phoneBindManager:getRewardsChoice()
    if table.isEmpty(tbl) or table.isEmpty(tbl[1].rewards) or table.isEmpty(tbl[1].rewards.list) then
        safeRunCall(closeCallback)
        return false
    end
    local reward = tbl[1].rewards.list[1]
    if self._phoneBindManager:hasGotBindPhoneReward() then
        reward = {}
    end
    self._phoneBindManager:showPhoneBindPanel(reward, function()
        self:removeIconIfExist()
        safeRunCall(onBindSuccess)
    end, onBindFail, closeCallback)
    PhoneBindDC:dc("phone2021", "phone2021_pop", source, 3)
    return true
end

function PhoneBindActManager:onActEnterStage4(evt)
    if not self:popEnabledInStage4() then
        return
    end
    local autoPopupMgr = _G.amfBean("AutoPopupMgr")

    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.BIND_PHONE)
    end

    local creator = function ()
        if not self:popEnabledInStage4() then
            safeRunCall(onHandleOver)
            return
        end
        self:popBindPhonePanel({
            source = _G.PhoneBindActConst.Source.STAGE_4_POP,
            closeCallback = onHandleOver,
        })
        self._model:setStage4PopFlag()
    end
    autoPopupMgr:addPopupConfig(PopupCheckPoint.BIND_PHONE, creator)
end

function PhoneBindActManager:showExitGameBindPanel(event)
    local choice = self._phoneBindManager:getRewardsChoice()
    if self._phoneBindManager:checkPhoneBindEnabled() and
            not table.isEmpty(choice) and
            self._phoneBindManager:popTimeUpdate() then
        local reward = choice[1].rewards.list[1]
        local context = event:getData() or {}
        local onExit = context.onExit
        local onCancelExit = context.onCancelExit
        local vm = require "amf.feature.accountbind.phonebind.module.phonebindact.view.ExitGameBindPanelVM"
                :create(reward, onExit)
        vm:setCloseCallback(function()
            if onCancelExit then onCancelExit() end
        end)
        vm:popout()
    else
        event:redeliver()
    end
end

function PhoneBindActManager:onBindPhoneNumberByFruitTree(event)
    local data = event:getData()
    local callback = data.callback
    local closeCallback = data.closeCallback
    self:popBindPhonePanel({
        source = _G.PhoneBindActConst.Source.FRUIT_TREE,
        ignorePopTime = true,
        onBindSuccess = function()
            safeRunCall(callback, true)
        end,
        onBindFail = function()
            safeRunCall(callback, false)
        end,
        closeCallback = function()
            safeRunCall(closeCallback)
        end
    })
end

return PhoneBindActManager
