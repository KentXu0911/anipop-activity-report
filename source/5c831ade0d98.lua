local SingleIconGiftModule = require "amf.feature.giftpackage.module.singleicon.SingleIconGiftModule"
local Res = require "amf.feature.localactivity.shopreward.const.Res"
local ShopRewardEventCenter = require "amf.feature.localactivity.shopreward.event.ShopRewardEventCenter"
---@class ShopRewardSingleIconModule : SingleIconGiftModule
local ShopRewardSingleIconModule = class("ShopRewardSingleIconModule", SingleIconGiftModule)

local ICON_V2_EXPERIMENT_MODULE = "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"
local ICON_V2_ADAPTER_MODULE = "amf.feature.mainscene.module.icon.v2.runtime.PackageIconV2Adapter"

local function logIconV2Error(message)
    if ALog and type(ALog.strict_log_error) == "function" then
        pcall(ALog.strict_log_error, "[ShopRewardIconV2] " .. tostring(message))
    end
end

function ShopRewardSingleIconModule:ctor(moduleName)
    self._moduleName = moduleName or GiftPackageConst.ModuleType.SHOP_REWARD
    self._version = 1
    self.iconKey = IconKey.kShopReward
    self.packageData = nil
    self.packageList = nil
    self._iconV2Adapter = nil
end

function ShopRewardSingleIconModule:_isIconV2Enabled()
    local ok, experiment = pcall(require, ICON_V2_EXPERIMENT_MODULE)
    if not ok or type(experiment.isEnabled) ~= "function" then
        return false
    end
    local enabledOk, enabled = pcall(experiment.isEnabled, experiment)
    return enabledOk and enabled == true
end

function ShopRewardSingleIconModule:_disposeIconV2Adapter()
    local adapter = self._iconV2Adapter
    if not adapter then
        return true
    end
    local ok, disposed, disposeError = pcall(adapter.dispose, adapter)
    if not ok or disposed ~= true then
        logIconV2Error("dispose failed: " .. tostring(ok and disposeError or disposed))
        return false, ok and disposeError or disposed
    end
    self._iconV2Adapter = nil
    return true
end

function ShopRewardSingleIconModule:_refreshIconV2(reason, payload)
    local adapter = self._iconV2Adapter
    if not adapter or type(adapter.isV2Active) ~= "function" or adapter:isV2Active() ~= true then
        return false
    end
    local ok, refreshed, refreshError = pcall(adapter.refresh, adapter, reason, payload)
    if not ok or refreshed == false then
        logIconV2Error("refresh failed: " .. tostring(ok and refreshError or refreshed))
        return false
    end
    return true
end

function ShopRewardSingleIconModule:_markV2NewShownIfNeeded()
    local adapter = self._iconV2Adapter
    if not adapter or self:getIconNewActShowTime() > 0 then return end
    local ok, icon = pcall(adapter.getIcon, adapter)
    if not ok or not icon or type(icon.isNewAct) ~= "function" or icon:isNewAct() ~= true then
        return
    end
    self:markIconNewActShown()
    self:_refreshIconV2("shop_reward_new_shown")
end

function ShopRewardSingleIconModule:_createIconV2Adapter()
    local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
    local adapterLoaded, PackageIconV2Adapter = pcall(require, ICON_V2_ADAPTER_MODULE)
    if not adapterLoaded or type(PackageIconV2Adapter.create) ~= "function" then
        logIconV2Error("adapter unavailable: " .. tostring(PackageIconV2Adapter))
        local mountedOk, mounted = pcall(
            IconEventCenter.addIconIfNotExist,
            IconEventCenter,
            self.iconKey,
            function()
                return self:createLegacyIcon(true)
            end
        )
        return mountedOk and mounted ~= false
    end

    local configOk, options = pcall(function()
        local IconV2Config = require "amf.feature.giftpackage.module.singleicon.shopreward.IconV2Config"
        return IconV2Config.create(self, IconEventCenter)
    end)
    if not configOk or type(options) ~= "table" then
        local configError = configOk and "SHOP_REWARD_ICON_V2_CONFIG_REQUIRED" or options
        options = {
            ownerIconKey = self.iconKey,
            iconEventCenter = IconEventCenter,
            legacyFactory = function()
                return self:createLegacyIcon(true)
            end,
            v2PreflightError = configError,
        }
    end

    local createOk, adapter, modeOrError, cleanupOwner = pcall(
        PackageIconV2Adapter.create,
        PackageIconV2Adapter,
        options
    )
    if not createOk or not adapter then
        self._iconV2Adapter = cleanupOwner
        logIconV2Error("create failed: " .. tostring(createOk and modeOrError or adapter))
        return false
    end
    self._iconV2Adapter = adapter
    if modeOrError == "v2" then
        self:_markV2NewShownIfNeeded()
    end
    return true
end

function ShopRewardSingleIconModule:getManager()
    return _G.amfBean("ShopRewardManager")
end

function ShopRewardSingleIconModule:awake()
    if self._isAwoken then return end
    self._isAwoken = true

    ShopRewardEventCenter:register(ShopRewardEvent.ICON_STATE_REFRESH, self.onIconStateRefresh, self)
    ShopRewardEventCenter:register(ShopRewardEvent.ACT_MAIN_ENDED, self.onActMainEnded, self)
    ShopRewardEventCenter:register(ShopRewardEvent.STORE_PANEL_SHOW, self.onStorePanelShow, self)
end

function ShopRewardSingleIconModule:isEnabled()
    local manager = self:getManager()
    return manager and manager:isEnabled() or false
end

function ShopRewardSingleIconModule:needUpdate()
    return self:isEnabled() and not self.packageData
end

function ShopRewardSingleIconModule:requireExtraParams()
    return {}
end

function ShopRewardSingleIconModule:getIconResMap()
    local files
    if not self:_isIconV2Enabled() then
        files = {
            Res.Spine.ICON,
        }
    elseif EnvUtil:isMiniGame() then
        files = {
            Res.Texture.ICON_MINIGAME,
            Res.Texture.ICON_V2_BG,
        }
    else
        files = {
            Res.Spine.ICON_V2,
            Res.Texture.ICON_V2_BG,
        }
    end

    return {
        labels = {},
        files = files,
    }
end

function ShopRewardSingleIconModule:onReceivePackages(packageList)
    SingleIconGiftModule.onReceivePackages(self, packageList)
end

function ShopRewardSingleIconModule:doCreateIconAsync()
    if not self:_isIconV2Enabled() then
        if self._iconV2Adapter and not self:_disposeIconV2Adapter() then
            return
        end
        if not self:isIconEnabled() then
            self:removeIcon()
            return
        end

        self:loadRes(self:getIconResMap()):next(function()
            local icon = self:getIcon()
            if icon then
                self:refreshExistingIconByState()
                return
            end

            local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
            IconEventCenter:addIconIfNotExist(self.iconKey, function()
                return self:doCreateSingleIcon()
            end)
        end)
        return
    end

    if not self:isIconEnabled() then
        self:removeIcon()
        return
    end

    self:loadRes(self:getIconResMap()):next(function()
        if self._iconV2Adapter then
            if self:_refreshIconV2("shop_reward_create_refresh") then
                self:_markV2NewShownIfNeeded()
                return
            end
            if not self:_disposeIconV2Adapter() then return end
        end

        local icon = self:getIcon()
        if icon then
            local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
            IconEventCenter:removeIconEvent(self.iconKey)
        end
        self:_createIconV2Adapter()
    end)
end

function ShopRewardSingleIconModule:createLegacyIcon(suppressNewActivity)
    local manager = self:getManager()
    if not manager or not manager:isEnabled() then return end

    local Icon = require "amf.feature.giftpackage.module.singleicon.shopreward.view.ShopRewardIcon"
    local icon = Icon:create(self)
    if icon then
        if manager:isEnabled() then
            self:startCountdown(icon)
        end
        if suppressNewActivity ~= true then
            self:tryAddNewIconActAutoPopup(icon)
        end
    end
    return icon
end

function ShopRewardSingleIconModule:doCreateSingleIcon()
    return self:createLegacyIcon(false)
end

function ShopRewardSingleIconModule:getIcon()
    local iconManager = _G.amfBean("IconManager")
    return iconManager and iconManager:getIconByIconKey(IconKey.kShopReward)
end

function ShopRewardSingleIconModule:isIconEnabled()
    local manager = self:getManager()
    return manager and (manager:isEnabled() or self:canShowActivityEndedIcon()) or false
end

function ShopRewardSingleIconModule:canShowActivityEndedIcon()
    local manager = self:getManager()
    if not manager then return false end
    return manager:getModel():getDataByKey("group") ~= "OFF"
        and manager:isMainTimeEnded()
        and manager:getRemainBuyCount() > 0
end

function ShopRewardSingleIconModule:onIconTapped(activityEndedCallback)
    local manager = self:getManager()
    if not manager then return end

    if self:canShowActivityEndedIcon() then
        manager:showActivityEndedTip(activityEndedCallback)
        return
    end

    manager:openActivity(nil, {
        source = StoreConfig.AccurateSource.Click_Act_ShopReward_Icon,
    })
end

function ShopRewardSingleIconModule:refreshExistingIconByState()
    if self._iconV2Adapter then
        if not self:isIconEnabled() then
            self:removeIcon()
            return
        end
        if self:_refreshIconV2("shop_reward_state_refresh") then
            self:_markV2NewShownIfNeeded()
            return
        end
        local ok, icon = pcall(self._iconV2Adapter.getIcon, self._iconV2Adapter)
        if not ok or not icon then return end
        local manager = self:getManager()
        if manager and manager:isEnabled() then
            self:startCountdown(icon)
        end
        icon:updateState()
        return
    end

    local icon = self:getIcon()
    if not icon then return end

    if self:isIconEnabled() then
        local manager = self:getManager()
        if manager and manager:isEnabled() then
            self:startCountdown(icon)
        end
        icon:updateState()
    else
        self:removeIcon()
    end
end

function ShopRewardSingleIconModule:onIconStateRefresh()
    self:doCreateIconAsync()
end

function ShopRewardSingleIconModule:onActMainEnded()
    if self._iconV2Adapter and self:_refreshIconV2("shop_reward_main_ended") then
        return
    end
    local icon = self:getIcon()
    if icon and not icon.isDisposed and icon.stopCountdown then
        icon:stopCountdown()
    end
    self:refreshExistingIconByState()
end

function ShopRewardSingleIconModule:onStorePanelShow()
    local manager = self:getManager()
    if not manager or not manager:isEnabled() then return end

    self:setNormalHintClearTime(TimeKit:timeInSec())
    self:refreshExistingIconByState()
end

function ShopRewardSingleIconModule:startCountdown(icon)
    local manager = self:getManager()
    if not manager then return end
    if not icon or icon.isDisposed or not icon.startCountdownVer1 then return end

    local endTime = manager:getMainEndTime() or 0
    if endTime <= 0 then return end

    icon:startCountdownVer1({{
        type = "activity",
        endTimeInSec = endTime,
        startTimeInSec = 0,
        reachText = "00:00:00",
        labelText = "回馈狂欢",
        endCallback = function()
            manager:onStoreActivityEnded()
        end,
    }})
end

function ShopRewardSingleIconModule:getIconNewActKey()
    local manager = self:getManager()
    if not manager or manager:getPeriodId() <= 0 then return nil end
    return "shop_reward_icon_new_" .. tostring(manager:getPeriodId())
end

function ShopRewardSingleIconModule:isIconNewActPanelShowed()
    local key = self:getIconNewActKey()
    if not key then return true end
    return _G.amfBean("AutoPopupMgr"):getPermanentShowNum(key .. "_panel") > 0
end

function ShopRewardSingleIconModule:tryAddNewIconActAutoPopup(icon)
    local manager = self:getManager()
    if not icon then return end
    if not manager or not manager:isEnabled() then return end
    if icon.isNewAct and icon:isNewAct() then return end

    local key = self:getIconNewActKey()
    if not key then return end
    if self:isIconNewActPanelShowed() then return end

    icon:playHasNewFlagAni()
    self.actAutoPopUniqueKey = key
    self:markIconNewActShown()
    _G.amfBean("PopupNewActMgr"):addNewAutoPopPkgAct(key, IconKey.kShopReward, "回馈狂欢")
end

function ShopRewardSingleIconModule:getActAutoPopUniqueKey()
    return self.actAutoPopUniqueKey
end

function ShopRewardSingleIconModule:clearActAutoPopUniqueKey()
    self.actAutoPopUniqueKey = nil
end

function ShopRewardSingleIconModule:consumeIconNewAct()
    local key = self:getActAutoPopUniqueKey()
    if not key then return end

    _G.amfBean("PopupNewActMgr"):removeNewAutoPopPkgAct(key)
    _G.amfBean("PopupNewActMgr"):sendPanelManualPopup(key)
    _G.amfBean("AutoPopupMgr"):sendPermanentData(key)
    self:clearActAutoPopUniqueKey()
end

function ShopRewardSingleIconModule:getNormalHintLocalKey()
    local manager = self:getManager()
    return "normalHintClearTime_" .. tostring(manager and manager:getPeriodId() or 0)
end

function ShopRewardSingleIconModule:getNormalHintClearTime()
    local manager = self:getManager()
    if not manager or manager:getPeriodId() <= 0 then return 0 end
    return manager:getModel():getLocalCache(self:getNormalHintLocalKey(), false) or 0
end

function ShopRewardSingleIconModule:setNormalHintClearTime(time)
    local manager = self:getManager()
    if not manager or manager:getPeriodId() <= 0 then return end
    manager:getModel():setLocalCache(self:getNormalHintLocalKey(), false, time)
    manager:getModel():flush()
end

function ShopRewardSingleIconModule:getIconNewActShowTime()
    local manager = self:getManager()
    if not manager or manager:getPeriodId() <= 0 then return 0 end
    local key = "newActShowTime_" .. tostring(manager:getPeriodId())
    return manager:getModel():getLocalCache(key, false) or 0
end

function ShopRewardSingleIconModule:markIconNewActShown()
    local manager = self:getManager()
    if not manager or manager:getPeriodId() <= 0 then return end
    local key = "newActShowTime_" .. tostring(manager:getPeriodId())
    manager:getModel():setLocalCache(key, false, TimeKit:timeInSec())
    manager:getModel():flush()
end

function ShopRewardSingleIconModule:isInNormalHintCooldownAfterNewAct()
    local newActShowTime = self:getIconNewActShowTime()
    return newActShowTime > 0 and TimeKit:timeInSec() - newActShowTime < 24 * 60 * 60
end

function ShopRewardSingleIconModule:shouldShowIconHint()
    local manager = self:getManager()
    if not manager or not manager:isEnabled() then return false end
    if self:getActAutoPopUniqueKey() then return false end
    if self:isInNormalHintCooldownAfterNewAct() then return false end

    local clearTime = self:getNormalHintClearTime()
    return clearTime <= 0 or TimeKit:timeInSec() - clearTime >= 24 * 60 * 60
end

function ShopRewardSingleIconModule:removeIcon(iconKey)
    if self._iconV2Adapter then
        return self:_disposeIconV2Adapter()
    end
    return SingleIconGiftModule.removeIcon(self, iconKey)
end

function ShopRewardSingleIconModule:remove()
    if self._iconV2Adapter and not self:_disposeIconV2Adapter() then
        return false
    end
    return SingleIconGiftModule.remove(self)
end

return ShopRewardSingleIconModule
