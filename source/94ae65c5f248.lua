local SingleIconGiftModule = require "amf.feature.giftpackage.module.singleicon.SingleIconGiftModule"
local DailySpecialDc = require "amf.feature.giftpackage.module.singleicon.dailyspecial.DailySpecialDc"
local GiftEventCenter = require "amf.feature.giftpackage.event.GiftEventCenter"
local DailySpecialAIModule = class("DailySpecialAIModule", SingleIconGiftModule)

local ICON_V2_EXPERIMENT_MODULE = "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"
local ICON_V2_ADAPTER_MODULE = "amf.feature.mainscene.module.icon.v2.runtime.PackageIconV2Adapter"

local function logIconV2Error(message)
    if ALog and type(ALog.strict_log_error) == "function" then
        pcall(ALog.strict_log_error, "[DailySpecialIconV2] " .. tostring(message))
    end
end

function DailySpecialAIModule:ctor()
    self.iconKey = IconKey.kStoreAI
    self._iconV2Adapter = nil
    self._iconV2ExpiryTimer = nil
    self.dc = DailySpecialDc.new()
    GiftEventCenter:register(GiftEvent.COLLECT_DAILY_SPECIAL_AI_INFO, self.onDcInfoCollect, self)
    GiftEventCenter:register(GiftEvent.DAILY_AI_SHOW_IN_STORE, self.onShowInStore, self)
    GiftEventCenter:registerFeature(self)
end

function DailySpecialAIModule:_isIconV2Enabled()
    local ok, experiment = pcall(require, ICON_V2_EXPERIMENT_MODULE)
    if not ok or type(experiment.isEnabled) ~= "function" then
        return false
    end
    local enabledOk, enabled = pcall(experiment.isEnabled, experiment)
    return enabledOk and enabled == true
end

function DailySpecialAIModule:_stopIconV2ExpiryWatch()
    if self._iconV2ExpiryTimer and TimerUtil and type(TimerUtil.removeAlarm) == "function" then
        pcall(TimerUtil.removeAlarm, self._iconV2ExpiryTimer)
    end
    self._iconV2ExpiryTimer = nil
end

function DailySpecialAIModule:_startIconV2ExpiryWatch()
    self:_stopIconV2ExpiryWatch()
    local packageData = self.packageData
    local endTime = packageData and packageData:getEndTime() or 0
    if endTime <= 0 or not TimerUtil or type(TimerUtil.addAlarm) ~= "function" then
        return
    end
    local function onTick()
        if not self._iconV2Adapter then
            self:_stopIconV2ExpiryWatch()
            return
        end
        if TimeKit:timeInSec() >= endTime then
            self:_stopIconV2ExpiryWatch()
            self:onDeprecated()
        end
    end
    self._iconV2ExpiryTimer = TimerUtil.addAlarm(onTick, 1, 0)
    onTick()
end

function DailySpecialAIModule:_disposeIconV2Adapter()
    self:_stopIconV2ExpiryWatch()
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

function DailySpecialAIModule:_createIconV2Adapter()
    local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
    local adapterLoaded, PackageIconV2Adapter = pcall(require, ICON_V2_ADAPTER_MODULE)
    if not adapterLoaded or type(PackageIconV2Adapter.create) ~= "function" then
        logIconV2Error("adapter unavailable: " .. tostring(PackageIconV2Adapter))
        local mountedOk, mounted = pcall(
            IconEventCenter.addIconIfNotExist,
            IconEventCenter,
            self.iconKey,
            function()
                return self:createLegacyIcon()
            end
        )
        return mountedOk and mounted ~= false
    end

    local configOk, options = pcall(function()
        local IconV2Config = require "amf.feature.giftpackage.module.singleicon.dailyspecial.IconV2Config"
        return IconV2Config.create(self, IconEventCenter)
    end)
    if not configOk or type(options) ~= "table" then
        local configError = configOk and "DAILY_SPECIAL_ICON_V2_CONFIG_REQUIRED" or options
        options = {
            ownerIconKey = self.iconKey,
            iconEventCenter = IconEventCenter,
            legacyFactory = function()
                return self:createLegacyIcon()
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
        self:_startIconV2ExpiryWatch()
    end
    return true
end

function DailySpecialAIModule:doCreateIconAsync()
    if not self:_isIconV2Enabled() then
        if self._iconV2Adapter and not self:_disposeIconV2Adapter() then
            return
        end
        return SingleIconGiftModule.doCreateIconAsync(self)
    end

    return self:loadRes(self:getIconResMap()):next(function()
        if not self.packageData then return end
        if self._iconV2Adapter and not self:_disposeIconV2Adapter() then return end
        local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
        IconEventCenter:removeIconEvent(self.iconKey)
        self:_createIconV2Adapter()
    end)
end

function DailySpecialAIModule:getIconResMap()
    return {
        labels = {},
        files = {
            "amf/dailyspecialai/icon/daily_special_bg.png",
            "amf/dailyspecialai/icon/daily_special_icon.png",
        },
    }
end

function DailySpecialAIModule:canAutoPopup(commonGiftData)
    --@haocong.liang新增修改 支付宝无付费档位限制
    if not EnvUtil:isALIPAYMiniGame() then
        local last60Pay = UserTagManager:getLast60DayPayAmount()
        if last60Pay <= 0 then return end
    end

    local endTime = commonGiftData:getEndTime()
    if endTime < TimeKit:timeInSec() - 60 then return false end
    local last_popped_gift_endTime = LocalDB:getString("last_popped_gift_endTime")
    return endTime > (tonumber(last_popped_gift_endTime) or 0)
end

function DailySpecialAIModule:onActEnterStage4()
    if not self.packageData then return end
    if self:canAutoPopup(self.packageData) then
        local function onHandleOver()
            AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.DAILY_SPECIAL_AI_GIFT_PACKAGE)
        end

        local creator = function()
            -- 如果礼包已购买或者已失效，不弹
            if not self.packageData then onHandleOver() return end

            local vm = self:doCreateGiftView(true)
            vm:setCloseCallback(onHandleOver)
            vm:setLoadResFailCallback(onHandleOver)
            vm:popout()

            local endTime = self.packageData:getEndTime()
            LocalDB:setString("last_popped_gift_endTime", tostring(endTime))
        end

        _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.DAILY_SPECIAL_AI_GIFT_PACKAGE, creator)
    end
end


function DailySpecialAIModule:onShowInStore(event)
    local data = event:getData()
    if self.packageData and data and data.goodsId then
        if data.goodsId == self.packageData:getGoodsId() then
            self.packageData:setExtraValue("firstShow", false)
            self.packageData:setExtraValue("showTime", TimeKit:timeInMillis())
        end
    end
end

function DailySpecialAIModule:onDcInfoCollect(event)
    local data = event:getData()
    if self.packageData and data and data.info then
        data.info.daily_discount_package_id = self.packageData:getGoodsId()
        data.info.daily_discount_package_first_show = self.packageData:getExtraValue("firstShow") and "yes" or "no"
        data.info.popping_point_id = self.packageData:getExtraValue("poping")
        data.info.daily_discount_package_duration = self.packageData:getExtraValue("duration")
    end
end

function DailySpecialAIModule:needUpdate()
    return not self.packageData
end

function DailySpecialAIModule:isEnabled()
    ---测试开关
    local testEnabled = (require 'amf.feature.giftpackage.common.PackageSwitch'):isAIGiftPackageEnabled()
    if not testEnabled then
        return false
    end

    local PersonalRecommend = require 'amf.feature.giftpackage.common.PersonalRecommend'
    local recommendEnabled = PersonalRecommend:isEnabled()
    if not recommendEnabled then return end

    if self.__maintenanceEnabled == nil then
        if EnvUtil:isWindows() then
            self.__maintenanceEnabled = true
        elseif EnvUtil:isMiniGame() then
            local closeFeature = MaintenanceManager.getInstance():isEnabledAndInGroup("bigvineAiPackage", true, "OFF")
            self.__maintenanceEnabled = not closeFeature
        else
            self.__maintenanceEnabled = true
        end
    end
    return self.__maintenanceEnabled
end

function DailySpecialAIModule:requireExtraParams()
    return {
        aiParams = self:getAIParams(),
    }
end

function DailySpecialAIModule:getAIParams()
    local ClientRtufBuilder = require("amf.feature.giftpackage.common.ClientRtufBuilder")
    local rtuf = ClientRtufBuilder:build()
    local params = {
        rtuf = rtuf,
    }
    return params
end

function DailySpecialAIModule:doCreateGiftView(autoPopup)
    local VM = require "amf.feature.giftpackage.module.singleicon.dailyspecial.view.DailySpecialAIPanelVM"
    local vm = VM:create(self.packageData, self, autoPopup)
    return vm
end

function DailySpecialAIModule:createLegacyIcon()
    if not self.packageData then return end
    local icon = require("amf.feature.giftpackage.module.singleicon.dailyspecial.view.DailySpecialIcon"):create()
    local discount = self.packageData:getDiscount()
    if discount < 10 then
        icon:setDiscount(discount)
    end
    self:setIconTouch(icon)

    local endTime = self.packageData:getEndTime()
    if endTime > 0 then
        icon:startCountdownVer1({{
             type = "activity",
             endTimeInSec = endTime,
             startTimeInSec = 0,
             reachText = "00:00:00",
             endCallback = function()
                 self:onDeprecated()
             end,
         }})
    end

    return icon
end

function DailySpecialAIModule:doCreateSingleIcon()
    return self:createLegacyIcon()
end

function DailySpecialAIModule:removeIcon(iconKey)
    if self._iconV2Adapter then
        return self:_disposeIconV2Adapter()
    end
    return SingleIconGiftModule.removeIcon(self, iconKey)
end

function DailySpecialAIModule:remove()
    if self._iconV2Adapter and not self:_disposeIconV2Adapter() then
        return false
    end
    return SingleIconGiftModule.remove(self)
end

function DailySpecialAIModule:onShow(commonGiftData, trigger_scene)
    local showTime = commonGiftData:getExtraValue("showTime") or 0
    if showTime <= 0 then
        commonGiftData:setExtraValue("showTime", TimeKit:timeInMillis())
        commonGiftData:setExtraValue("firstShow", true)
        local DailySpecialFirstShowHttp = require "amf.feature.giftpackage.module.singleicon.dailyspecial.http.DailySpecialFirstShowHttp"
        DailySpecialFirstShowHttp:post()
    else
        commonGiftData:setExtraValue("firstShow", false)
    end

    self.dc:dc_item_show(commonGiftData, trigger_scene or "main_scene")
end

function DailySpecialAIModule:onBuyClick(commonGiftData, trigger_scene)
    self.dc:dc_buy_click(commonGiftData, trigger_scene or "main_scene")
end

function DailySpecialAIModule:onBuyResult(result, payInfo, commonGiftData, trigger_scene)
    self.dc:dc_buy_result(result, payInfo, commonGiftData, trigger_scene or "main_scene")
end

function DailySpecialAIModule:onBuySuccess(commonGiftData)
    self:onDeprecated()
end

return DailySpecialAIModule
