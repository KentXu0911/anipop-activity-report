local AMFRequest = require "amf.middleware.interconnection.remote.core.AMFRequest"
local DesktopShortcutManager = class("DesktopShortcutManager")
local EventCenter = _G.amfEC:createLocalEC()
local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local PackageIconV2Host = require "amf.feature.mainscene.module.icon.v2.runtime.PackageIconV2Host"
local BaseIcon = require "amf.feature.mainscene.module.icon.view.BaseIcon"
local MyIcon = class("MyIcon", BaseIcon)
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local DesktopShortcutConfig = require 'amf.feature.minihub.adddesktopshortcut.DesktopShortcutConfig'
local ICON_V2_EXPERIMENT_MODULE = "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"
local LEGACY_LABEL = "HuaweiMiniMisc"
local ICON_V2_PATH = "amf/adddesktopshortcut/icon/icon_v2.png"
local OWNER_ICON_KEY = IconKey.kMiniHuaweiDesktopIcon
local pendingLaunchEvent = false;
local ServerProxy = {}
local useMock = false;

-- for debug
if EnvUtil:isUnityEditor() then
   -- pendingLaunchEvent = true;
end

-- local Request = class("HMSBuyNotify", AMFRequest)

-- function Request:post(params, hostObj)
--  local config = {
--      protocol = "hMSBuyNotify",
--      loading = true,
--      useMockData = false
--  }
--     return Request:run(config, params, hostObj)
-- end

-- return Request


----------
-- ICON --
----------

function MyIcon:create(manager)
    local icon = MyIcon.new()
    icon:init(manager)
    return icon
end

function MyIcon:init(manager)
    BaseIcon.init(self, OWNER_ICON_KEY)
    self.manager = manager;
    self:updateState()
end

function MyIcon:initData(...)
    BaseIcon.initData(self, ...)
    self.viewData = {}
end


function MyIcon:buildIcon()
    local iconContainer = Node:create()
    iconContainer:setAnchorPoint(ccp(0.5, 0.5))
    iconContainer:setContentSize(CCSizeMake(102, 102))

    local iconRes = UICreateUtil:createSpriteWithPlist("amf/feature/HuaweiMini/misc.plist", "desktop.png")
    -- iconRes:setContentSize(CCSizeMake(16, 16))
    iconRes:setAnchorPoint(ccp(0.5, 0.5))
    iconRes:ignoreAnchorPointForPosition(false)
    -- iconRes:setColor(ccc3(255, 0, 255))
    iconRes:setPositionXY(51, 51)

    iconContainer:addChild(iconRes)
    -- local anim = UICreateUtil:createSpine(Res.Spine.ICON)
    -- iconContainer:addChild(anim)
    -- iconContainer.anim = anim

    return iconContainer
end



function MyIcon:hasReward()
    return self.manager:hasReward()
end

function MyIcon:hasHint()
    return true
end

-- function MyIcon:canShow()
--     return self.manager:canShowIcon()
-- end

-- function MyIcon:todayCanShow()
--     return self:canShow()
-- end

function MyIcon:updateState()
    if self.isDisposed then return end
    BaseIcon.updateState(self)
    self:setLabelStr('添加到桌面')
end

function MyIcon:onTouch(...)
    if self.isDisposed then return end
    BaseIcon.onTouch(self)
    self.manager:clickIcon(function () end, 1)
end



-----------------
-- ServerProxy --
-----------------

function ServerProxy:getRewardsConfig()
    if useMock then
        local deferred = require "amf.script.sugar.deferred"
        local d = deferred.new()
        d:resolve({{itemId = 14, num = 1}})
        return d
    else
        return AMFRequest:run({
            protocol = "getAddToDesktopMainInfo",
            loading = true,
        }, {

        }):next(function(resp)
            local respData = resp:getData()
            return respData.rewards
        end)
    end
end

function ServerProxy:getRewards()
    if useMock then
        local deferred = require "amf.script.sugar.deferred"
        local d = deferred.new()
        d:resolve({{itemId = 14, num = 1}})
        return d
    else
        return AMFRequest:run({
            protocol = "getAddToDesktopRewards",
            loading = true,
        }, {

        }):next(function(resp)
            local respData = resp:getData()
            return respData.rewards
        end)
    end
end


----------------------------------
-- DesktopShortcutManager --
----------------------------------

function DesktopShortcutManager:ctor()
    self.iconHost = PackageIconV2Host:create({
        owner = self,
        ownerIconKey = OWNER_ICON_KEY,
        iconEventCenter = IconEventCenter,
        isEligible = function()
            return self:shouldShowIcon()
        end,
        isV2Enabled = function()
            return self:isV2IconExperimentEnabled()
        end,
        prepareLegacyAssets = function()
            return _G.amfBean("AssetsUtil"):loadMiniLabels({LEGACY_LABEL})
        end,
        prepareV2Assets = function()
            return _G.amfBean("AssetsUtil"):loadMiniFiles({ICON_V2_PATH})
        end,
        createV2Options = function()
            local IconV2Config = require "amf.feature.minihub.adddesktopshortcut.icon.IconV2Config"
            return IconV2Config:create(self, IconEventCenter)
        end,
        createLegacyIcon = function()
            return self:createLegacyIcon()
        end,
        refreshLegacy = function(icon)
            icon:updateState()
            return true
        end,
        preflightErrorPrefix = "DESKTOP_SHORTCUT_V2_ASSET_LOAD_FAILED:",
        logError = function(stage, detail)
            if ALog and type(ALog.strict_log_error) == "function" then
                ALog.strict_log_error(
                    "[DesktopShortcutIconV2] " .. tostring(stage) .. ":" .. tostring(detail)
                )
            end
        end,
    })
end

function DesktopShortcutManager:initialize()
    ULog("DesktopShortcutManager initialize");
    self.proxy = DesktopShortcutConfig:getProxy()
    if self.proxy then self.proxy:initialize() end

    if self:shouldShowIcon() then
        printx(44, "shouldShowIcon")
        self:registerEvent()
    end

end

function DesktopShortcutManager:setAutoPopupMgr(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
end

function DesktopShortcutManager:hasReward()
    return self.proxy and (not self.proxy:isRewardGot()) and self.proxy:isRewardAvailable()
end

function DesktopShortcutManager:shouldShowIcon()
    return self.proxy and (not self.proxy:isRewardGot())
end

function DesktopShortcutManager:isV2IconExperimentEnabled()
    if EnvUtil:isUnityEditor() then
        return true
    end
    local experiment = require(ICON_V2_EXPERIMENT_MODULE)
    return experiment:isEnabled()
end

function DesktopShortcutManager:updateIcon()
    return self.iconHost:reconcile("manager_update")
end

-- function DesktopShortcutManager:canShowIcon()
--  return shouldShowIcon()
-- end

function DesktopShortcutManager:createLegacyIcon()
    return MyIcon:create(self)
end

function DesktopShortcutManager:notifyRewardGot(rewards)
    self.proxy:markRewardGot()
    local dcFeature = DcUtil:getMiniGameCategory()
    local dcSource = 'desktop_reward'
    _G.GainPropData:create():setFeature(dcFeature):setSource(dcSource):setProps(rewards):execute()
    self:updateIcon()

end

function DesktopShortcutManager:clickIcon(done, fromType)
     self._autoPopupMgr:sendPermanentData("DesktopShortcutPop")
    if self:hasReward() then

        ServerProxy:getRewards():next(function(rewards)
            self:notifyRewardGot(rewards)

            DcUtil:UserTrack({ category = DcUtil:getMiniGameCategory(), sub_category = 'desktop_reward',  t1 = fromType})

            local ShowRewardsPanelVM = require "amf.middleware.ui.kit.panel.reward.ShowRewardsPanelVM"
            local vm = ShowRewardsPanelVM.Builder.new()
                :setRewards(rewards)
                :setCloseCallback(done)
                -- :setSubTitle("")
                :build()
                vm:popout()

        end, function(e)
            CommonTip:showErrorTip(e)
            safeRunCall(done)
        end)
    else
        local UIHelper = UBFViewHelper.migrator.UIHelper
        self.proxy:checkShortcutExists(function(result)
            local r2 = result
            local hadAddToDesktop = r2 and r2.errCode == 0 and r2.data
            if hadAddToDesktop  then
                ServerProxy:getRewardsConfig():next(function(rewards)
                    local textStruct = LabelStruct.new()
                        :setText('添加游戏图标到手机桌面，快速进入游戏 获取丰厚奖励！')
                        :setHorizontalAlignment(kCCTextAlignmentCenter)
                        :setFontSize(28)
                        :setLineSpace(14)

                    -- 需要从手机桌面图标进入，才可领取奖励

                    local vm
                    local SecondPanelAVM = require "amf.middleware.ui.kit.panel.second.SecondPanelAVM"
                    vm = SecondPanelAVM.Builder.new()
                        :setTitle("入口有奖")
                        :setTextStruct(textStruct)
                        :setFly(false)
                        :setCloseCallback(done)
                        :setRewards(rewards)
                        :setButtonsConfig({
                            {
                                str = "领取奖励",
                                widthMode = UIButtonConfig.Widths.kShort,
                                colorMode = UIButtonConfig.ColorMode.gray,
                                touchFunc = function()
                                    CommonTip:showTip("需要从手机桌面图标进入，才可领取奖励")
                                end,
                            },
                        })
                        :build()

                    vm:popout()

                    local label = TTFLabel:createAnimalYH("需要从手机桌面图标进入，才可领取奖励", 22)
                    label:setAnchorPoint(ccp(0.5, 0.5))
                    label:setTextColor(hex2ccc4('B2714AFF'))
                    vm.view.ui:addChild(label)
                    UIHelper:move(vm.view.btns[1], 0, 15)
                    label:setPositionXY(307,-669.5)


                    DcUtil:UserTrack({ category = DcUtil:getMiniGameCategory(), sub_category = 'desktop_show',  t1 = fromType})

                end, function(e)
                    safeRunCall(done)
                    CommonTip:showErrorTip(e)
                end)

            else


                ServerProxy:getRewardsConfig():next(function(rewards)
                    local textStruct = LabelStruct.new()
                        :setText('添加游戏图标到手机桌面，快速进入游戏 获取丰厚奖励！')
                        :setHorizontalAlignment(kCCTextAlignmentCenter)
                        :setFontSize(28)
                        :setLineSpace(14)

                    --

                    local vm
                    local SecondPanelAVM = require "amf.middleware.ui.kit.panel.second.SecondPanelAVM"
                    vm = SecondPanelAVM.Builder.new()
                        :setTitle("入口有奖")
                        :setTextStruct(textStruct)
                        :setFly(false)
                        :setRewards(rewards)
                        :setCloseCallback(done)
                        :setButtonsConfig({
                            {
                                str = "添加到桌面",
                                widthMode = UIButtonConfig.Widths.kShort,
                                colorMode = UIButtonConfig.ColorMode.green,
                                touchFunc = function()
                                    vm:close()
                                    self.proxy:installShortcut(function(result)
                                        if result and result.errCode == 0 then
                                            -- self:notifyAddToDesktop()
                                            DcUtil:UserTrack({ category = DcUtil:getMiniGameCategory(), sub_category = 'desktop_success'})
                                        else
                                            if EnvUtil:isUnionMiMiniGame() and result.errCode == -201 and result.errMsg == "User forbidden" then
                                                _G.amfBean("DesktopShortcutManager"):openGuidePanel()
                                            else
                                                CommonTip:showTip("取消添加~")
                                            end
                                        end
                                    end)

                                    DcUtil:UserTrack({ category = DcUtil:getMiniGameCategory(), sub_category = 'desktop_click'})

                                end,
                            },
                        })
                        -- :setCloseBtnCall(tryGetReward)
                        :build()

                    vm:popout()

                    local label = TTFLabel:createAnimalYH("需要从手机桌面图标进入，才可领取奖励", 22)
                    label:setAnchorPoint(ccp(0.5, 0.5))
                    label:setTextColor(hex2ccc4('B2714AFF'))
                    vm.view.ui:addChild(label)
                    UIHelper:move(vm.view.btns[1], 0, 15)
                    label:setPositionXY(307,-669.5)
                    DcUtil:UserTrack({ category = DcUtil:getMiniGameCategory(), sub_category = 'desktop_show'})


                end, function(e)
                    safeRunCall(done)
                    CommonTip:showErrorTip(e)
                end)

                -- vm.view:addChild(layerColor)
            end
        end)
    end
end

function DesktopShortcutManager:checkStage4CanPop()
    if not self:shouldShowIcon() then return false end
    if self._autoPopupMgr:getPermanentShowNum("DesktopShortcutPop") > 0 then return false end
    return true
end

function DesktopShortcutManager:onActEnterStage4()
        printx(44,"onActEnterStage4 desktop")
    if not self:checkStage4CanPop() then
        return
    end
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.KS_DESKTOP_SHORTCUT)
    end

    local function creator()
        self:clickIcon(onHandleOver, 2)
    end

    self._autoPopupMgr:addPopupConfig(PopupCheckPoint.KS_DESKTOP_SHORTCUT, creator)
end



function DesktopShortcutManager:registerEvent()
    EventCenter:registerFeature(self)
    EventCenter:registerSystem(self)
    IconEventCenter:register(IconEvent.ICON_SYSTEM_READY, self.onIconSystemReady, self)
end

function DesktopShortcutManager:onIconSystemReady()
    self:updateIcon()
    self:handlePendingLaunchEvent()
end

function DesktopShortcutManager:handlePendingLaunchEvent()
    if pendingLaunchEvent then
        pendingLaunchEvent = false;
        self:notifyRewardAvailable()
    end
end


function DesktopShortcutManager:notifyRewardAvailable()
    self.proxy:markRewardAvailable()
    self:updateIcon()
end

function DesktopShortcutManager:unRegisterEvent()
    EventCenter:unregisterFeature(self)
    EventCenter:unregisterSystem(self)
end

-- this is a static method
function DesktopShortcutManager:notifyLaunchFromShortcut()
    local mgr = _G.amfBean("DesktopShortcutManager");
    if mgr then
        mgr:notifyRewardAvailable()
    else
        pendingLaunchEvent = true;
    end
end

function DesktopShortcutManager:openGuidePanel()
    ServerProxy:getRewardsConfig():next(function(rewards)
        local panelVM = require "amf.feature.minihub.adddesktopshortcut.view.XiaomiAddShortCutPanelVM"
        local vm = panelVM:create({
            rewards = rewards,
        })
        vm:popout()
    end, function(e)
        CommonTip:showErrorTip(e)
    end)
end

return DesktopShortcutManager
