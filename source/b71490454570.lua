local IconEventCenter
if _G.MainSceneFloderVersion and _G.MainSceneFloderVersion >= 1.1 then
    IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
elseif not _G.MainSceneFloderVersion then
    IconEventCenter = require "amf.feature.mainscene.icon.event.IconEventCenter"
end

local CollectCardLog = require "amf.feature.localactivity.collectcard.log.CollectCardLog"
local CollectCardEventCenter = require "amf.feature.localactivity.collectcard.event.CollectCardEventCenter"
local deferred = require "amf.script.sugar.deferred"

local IconModule = class("IconModule")
local ICON_V2_EXPERIMENT_MODULE = "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"
local ADAPTER_CREATE_READY = "ready"
local ADAPTER_CREATE_SAFE_LEGACY = "safe_legacy"
local ADAPTER_CREATE_WAIT_OWNER = "wait_owner"

local function logIconV2Error(message)
    if ALog and type(ALog.strict_log_error) == "function" then
        ALog.strict_log_error("[CollectCardGiftIconV2] " .. tostring(message))
    end
end

function IconModule:ctor(manager)
    self.manager = manager
    self.actIcon = nil
    self.giftIcon = nil
    self.giftIconAdapter = nil
    self.giftIconDataProvider = nil
    self._giftIconAdapterRecoveryPending = false
    self._giftIconEventRegistered = false
    self._giftStrongIdle = true
    self._giftIconCreateGeneration = 0
end

function IconModule:onIconSystemReady()
    self._iconSystemReady = true
    self:tryCreateActIcon()
    self:updateGiftIcon()
end

function IconModule:tryCreateActIcon(needShowLockedState, callback)
    if not self._iconSystemReady then return end
    if self.actIcon and not self.actIcon.isDisposed then return end
    if not self:needShowActIcon() then return end
    self:loadActIconRes():next(function()
        if not self:needShowActIcon() then return end
        local actIcon = self:createActIcon(needShowLockedState or not self.manager:isTopLevelSupport())
        if actIcon then
            actIcon:tryPopFoundNewAct()
        end
        safeRunCall(callback)
    end)
end

function IconModule:needShowActIcon()
    return true
end

function IconModule:loadActIconRes()
    local resList = {
        "amf/activity/collectcard/icon/jika_icon2.skel",
        "amf/activity/collectcard/icon/lockedIcon.png",
        "amf/activity/collectcard/icon/jika_icon.skel",
    }
    if EnvUtil:isMiniGame() then
        return _G.amfBean("AssetsUtil"):loadMiniFiles(resList)
    else
        return deferred.success()
    end
end

function IconModule:createActIcon(needShowLockedState)
    printx(33, "IconModule:createActIcon")
    if self.actIcon and self.actIcon.isDisposed then
        self.actIcon = nil
    end
    IconEventCenter:addIconIfNotExist(IconKey.kCollectCardIcon, function()
        local CollectCardIcon = require "amf.feature.localactivity.collectcard.icon.CollectCardIcon"
        self.actIcon = CollectCardIcon:create(needShowLockedState)
        return self.actIcon
    end)
    if not self.actIcon then
        local icon = self:getActivityIcon()
        if icon and not icon.isDisposed then
            self.actIcon = icon
        end
    end
    return self.actIcon
end

function IconModule:removeActIcon()
    if self.actIcon and not self.actIcon.isDisposed then
        IconEventCenter:removeIconEvent(IconKey.kCollectCardIcon)
    end
    self.actIcon = nil
end

function IconModule:isV2IconExperimentEnabled()
    local ok, enabled = pcall(function()
        local experiment = require(ICON_V2_EXPERIMENT_MODULE)
        return experiment:isEnabled()
    end)
    return ok and enabled == true
end

function IconModule:createLegacyGiftIcon()
    local CollectCardGiftIcon = require "amf.feature.localactivity.collectcard.icon.CollectCardGiftIcon"
    return CollectCardGiftIcon:create(self.manager)
end

function IconModule:getGiftIconCycleKey()
    local endTime = tonumber(self.manager:getModel():getGiftEndTime()) or 0
    if endTime <= 0 then return nil end
    return "HasTappedGiftIcon" .. tostring(endTime)
end

function IconModule:getGiftIconV2Snapshot()
    local model = self.manager:getModel()
    return {
        startTime = tonumber(model:getGiftBeginTime()) or 0,
        endTime = tonumber(model:getGiftEndTime()) or 0,
        label = "新卡礼包",
        cycleKey = self:getGiftIconCycleKey(),
        strongIdle = self._giftStrongIdle == true,
        rewardVisible = false,
    }
end

function IconModule:createGiftIconNewActivityRecordStore()
    local manager = self.manager
    return {
        isConsumed = function(_, key)
            return manager:getFlagFromLocalByKey(key) == true
        end,
        get = function(_, key)
            return manager:getFlagFromLocalByKey(key) == true
        end,
        consume = function(_, key)
            manager:setFlagToLocalByKey(key)
            return manager:getFlagFromLocalByKey(key) == true
        end,
    }
end

function IconModule:_registerGiftIconEvent()
    if self._giftIconEventRegistered then return end
    CollectCardEventCenter:register(CollectCardEvent.ON_GIFT_ICON_UPDATE, self.onGiftIconUpdate, self)
    self._giftIconEventRegistered = true
end

function IconModule:_unregisterGiftIconEvent()
    if not self._giftIconEventRegistered then return end
    CollectCardEventCenter:unregister(CollectCardEvent.ON_GIFT_ICON_UPDATE, self.onGiftIconUpdate, self)
    self._giftIconEventRegistered = false
end

function IconModule:onGiftIconUpdate(event)
    local isStrong = event == nil and true or event:getData() == true
    self._giftStrongIdle = isStrong
    self:refreshGiftIconAdapter("gift_animation_update")
end

function IconModule:createGiftPackageIconAdapter()
    local adapterLoaded, PackageIconV2Adapter = pcall(
        require,
        "amf.feature.mainscene.module.icon.v2.runtime.PackageIconV2Adapter"
    )
    if not adapterLoaded or type(PackageIconV2Adapter.create) ~= "function" then
        return {
            state = ADAPTER_CREATE_SAFE_LEGACY,
            error = adapterLoaded and "COLLECT_CARD_GIFT_ICON_V2_ADAPTER_CREATE_REQUIRED"
                or PackageIconV2Adapter,
        }
    end

    local configOk, options, provider = pcall(function()
        local IconV2Config = require "amf.feature.localactivity.collectcard.icon.CollectCardGiftIconV2Config"
        local configOptions, configProvider = IconV2Config.create(self.manager, IconEventCenter)
        assert(type(configOptions) == "table", configProvider or "COLLECT_CARD_GIFT_ICON_V2_CONFIG_REQUIRED")
        return configOptions, configProvider
    end)
    if not configOk then
        local configError = options
        options = {
            ownerIconKey = IconKey.kCollectCardGiftIcon,
            ownerIdentity = self,
            iconEventCenter = IconEventCenter,
            legacyFactory = function()
                return self:createLegacyGiftIcon()
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

function IconModule:_adoptGiftIconAdapter(createResult)
    local adapter = createResult.adapter or createResult.cleanupOwner
    if adapter then
        self.giftIconAdapter = adapter
    end
    if createResult.state ~= ADAPTER_CREATE_READY then
        self.giftIconDataProvider = nil
        self._giftIconAdapterRecoveryPending = true
        logIconV2Error("adapter owner pending: " .. tostring(createResult.error))
        return nil
    end

    local readyOk, ready = pcall(adapter.isReadyForOwnerAdoption, adapter)
    local iconOk, icon = pcall(adapter.getIcon, adapter)
    if not readyOk or ready ~= true or not iconOk or not icon or icon.isDisposed then
        self.giftIconDataProvider = nil
        self._giftIconAdapterRecoveryPending = true
        logIconV2Error("adapter owner not ready for adoption")
        return nil
    end

    self.giftIcon = icon
    self.giftIconDataProvider = createResult.mode == "v2" and createResult.provider or nil
    self._giftIconAdapterRecoveryPending = false
    if createResult.mode == "v2" then
        self:_registerGiftIconEvent()
    else
        self:_unregisterGiftIconEvent()
    end
    if createResult.mode == "v2" then
        if type(adapter.completeOwnerAdoption) ~= "function" then
            self._giftIconAdapterRecoveryPending = true
            logIconV2Error("adapter owner adoption required")
            return nil
        end
        local adoptedOk, adopted, adoptError = pcall(adapter.completeOwnerAdoption, adapter)
        if not adoptedOk or adopted ~= true then
            self._giftIconAdapterRecoveryPending = true
            logIconV2Error(
                "adapter owner adoption failed: " .. tostring(adoptedOk and adoptError or adopted)
            )
            return nil
        end
        if self.giftIconAdapter ~= adapter then
            return nil
        end
    end
    return icon
end

function IconModule:_disposeGiftIconAdapter(reason)
    local adapter = self.giftIconAdapter
    if not adapter then
        self._giftIconAdapterRecoveryPending = false
        self:_unregisterGiftIconEvent()
        return true
    end
    local ok, disposed, disposeError = pcall(adapter.dispose, adapter)
    if not ok or disposed ~= true then
        self._giftIconAdapterRecoveryPending = true
        logIconV2Error(
            "dispose failed reason=" .. tostring(reason)
                .. " error=" .. tostring(ok and disposeError or disposed)
        )
        return false, ok and disposeError or disposed
    end
    self.giftIconAdapter = nil
    self.giftIconDataProvider = nil
    self._giftIconAdapterRecoveryPending = false
    self:_unregisterGiftIconEvent()
    return true
end

function IconModule:_recoverGiftIconAdapter()
    if not self._giftIconAdapterRecoveryPending then
        return true
    end
    local adapter = self.giftIconAdapter
    if not adapter then
        self._giftIconAdapterRecoveryPending = false
        return true
    end
    local cleanupRequired = true
    if type(adapter.needsDisposalRecovery) == "function" then
        local cleanupOk, required = pcall(adapter.needsDisposalRecovery, adapter)
        cleanupRequired = not cleanupOk or required == true
    end
    if not cleanupRequired and type(adapter.completeOwnerAdoption) == "function" then
        local adoptedOk, adopted = pcall(adapter.completeOwnerAdoption, adapter)
        if adoptedOk and adopted == true then
            if self.giftIconAdapter ~= adapter then
                self._giftIconAdapterRecoveryPending = false
                return true
            end
            local mountedOk, mounted = pcall(adapter.isMounted, adapter)
            if mountedOk and mounted == true then
                self._giftIconAdapterRecoveryPending = false
                return true
            end
        end
    end
    local disposed = self:_disposeGiftIconAdapter("recovery")
    if disposed then
        self.giftIcon = nil
    end
    return disposed
end

function IconModule:refreshGiftIconAdapter(reason)
    local adapter = self.giftIconAdapter
    if not adapter then return false end
    local activeOk, active = pcall(adapter.isV2Active, adapter)
    if not activeOk or active ~= true then
        return false
    end
    local ok, refreshed, refreshError = pcall(adapter.refresh, adapter, reason or "collect_card_gift_update")
    if not ok or refreshed == false then
        logIconV2Error("refresh failed: " .. tostring(ok and refreshError or refreshed))
        return false
    end
    return true
end

function IconModule:onGiftPanelExposed()
    local adapter = self.giftIconAdapter
    if not adapter then return true end
    local activeOk, active = pcall(adapter.isV2Active, adapter)
    if not activeOk or active ~= true then return true end
    local ok, consumed, consumeError = pcall(
        adapter.consumeCurrentCycleNew,
        adapter,
        "collect_card_gift_panel_exposed"
    )
    if not ok or consumed == false then
        logIconV2Error("consume new failed: " .. tostring(ok and consumeError or consumed))
        return false, ok and consumeError or consumed
    end
    return true
end


function IconModule:updateGiftIcon()
    printx(33, "IconModule:updateGiftIcon")
    if self:needShowGiftIcon() then
        if not self._iconSystemReady then return end
        if self._giftIconAdapterRecoveryPending and not self:_recoverGiftIconAdapter() then
            return
        end
        if self.giftIconAdapter then
            local activeOk, active = pcall(self.giftIconAdapter.isV2Active, self.giftIconAdapter)
            if activeOk and active == true then
                self:refreshGiftIconAdapter("collect_card_gift_update")
            else
                IconEventCenter:refreshIconEvent(IconKey.kCollectCardGiftIcon)
            end
            return
        end
        self.giftIcon = _G.amfBean("IconManager"):getIconByIconKey(IconKey.kCollectCardGiftIcon)
        if self.giftIcon then
            IconEventCenter:refreshIconEvent(IconKey.kCollectCardGiftIcon)
        else
            self:createGiftIcon()
        end
    else
        self:clearGiftIcon()
    end
end

function IconModule:createGiftIcon()
    if self._isCreatingGiftIcon then
        return
    end
    self._isCreatingGiftIcon = true
    self._giftStrongIdle = true
    self._giftIconCreateGeneration = self._giftIconCreateGeneration + 1
    local generation = self._giftIconCreateGeneration
    local legacyIconPath = "amf/activity/collectcard/icon/jika_icon.skel"
    local iconRes = { legacyIconPath }
    if self:isV2IconExperimentEnabled() then
        local IconV2Config = require
            "amf.feature.localactivity.collectcard.icon.CollectCardGiftIconV2Config"
        iconRes = IconV2Config.getPreloadFiles(legacyIconPath)
    end
    AssetsUtil:loadMiniFiles(iconRes):next(function()
        if generation ~= self._giftIconCreateGeneration then return end
        if not self:needShowGiftIcon() then
            self._isCreatingGiftIcon = false
            return
        end
        if self:isV2IconExperimentEnabled() then
            local createResult = self:createGiftPackageIconAdapter()
            if createResult.state == ADAPTER_CREATE_SAFE_LEGACY then
                IconEventCenter:addIconIfNotExist(IconKey.kCollectCardGiftIcon, function()
                    self.giftIcon = self:createLegacyGiftIcon()
                    return self.giftIcon
                end)
                self.giftIcon = _G.amfBean("IconManager"):getIconByIconKey(IconKey.kCollectCardGiftIcon)
            else
                self:_adoptGiftIconAdapter(createResult)
            end
        else
            IconEventCenter:addIconIfNotExist(IconKey.kCollectCardGiftIcon, function()
                self.giftIcon = self:createLegacyGiftIcon()
                return self.giftIcon
            end)
            self.giftIcon = _G.amfBean("IconManager"):getIconByIconKey(IconKey.kCollectCardGiftIcon)
        end
        self._isCreatingGiftIcon = false
    end, function(loadError)
        if generation ~= self._giftIconCreateGeneration then return end
        logIconV2Error("load asset failed: " .. tostring(loadError))
        self._isCreatingGiftIcon = false
    end)
end

function IconModule:clearGiftIcon()
    self._giftIconCreateGeneration = self._giftIconCreateGeneration + 1
    self._isCreatingGiftIcon = false
    if self.giftIconAdapter then
        local disposed = self:_disposeGiftIconAdapter("gift_icon_removed")
        if disposed then
            self.giftIcon = nil
        end
        return disposed
    end
    IconEventCenter:removeIconEvent(IconKey.kCollectCardGiftIcon)
    self.giftIcon = nil
    self:_unregisterGiftIconEvent()
    return true
end

function IconModule:needShowGiftIcon()
    return self.manager:isActValid() and self.manager:getModel():isInGiftTime()
end

function IconModule:onGiftIconTapped()
    CollectCardLog:log("IconModule:onGiftIconTapped")
end

function IconModule:getActivityIcon()
    return _G.amfBean("IconManager"):getIconByIconKey(IconKey.kCollectCardIcon)
end

function IconModule:updateActIcon()
    local icon = self:getActivityIcon()
    if icon and (not icon.isDisposed) then
        icon:updateState()
    end
end

function IconModule:updateAllIcons()
    self:updateActIcon()
    self:updateGiftIcon()
end

function IconModule:clearAllIcons()
    self:removeActIcon()
    self:clearGiftIcon()
end

function IconModule:canShowActIconUnlockAnim()
    if not self.actIcon or self.actIcon.isDisposed then return false end
    if not self.manager:isTopLevelSupport() then return false end
    if not self.manager:isInActTime() then return false end
    return self.actIcon:isInLockedType()
end

function IconModule:playActIconUnlockAnim(callback)
    if not self.actIcon or self.actIcon.isDisposed then safeRunCall(callback) return end
    self.actIcon:playUnlockAnim(callback)
end

return IconModule
