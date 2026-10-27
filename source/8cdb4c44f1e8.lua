local AddSidebarConfig = require "amf.feature.minihub.addsidebar.AddSidebarConfig"
if not AddSidebarConfig:isPlatformEnable() then
    local AddSidebarManager = class("AddSidebarManager")
    AddSidebarManager.setAutoPopupMgr = function () end
    function AddSidebarManager:initialize()
    end
    return AddSidebarManager
end

local deferred = require "amf.script.sugar.deferred"
local DYMiniGameLog = require "amf.feature.minihub.addsidebar.DYMiniGameLog"
local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local Model = require "amf.feature.minihub.addsidebar.model.Model"
local DYMiniGameIcon = require "amf.feature.mainscene.module.icon.view.iconbutton.DYMiniGameIcon"
local MainPanelVM = require "amf.feature.minihub.addsidebar.view.MainPanelVM"
local InciteEventCenter = require "amf.feature.ad.incite.event.InciteEventCenter"
local AddSidebarDC = require "amf.feature.minihub.addsidebar.dc.AddSidebarDC"
local PackageIconV2Host = require "amf.feature.mainscene.module.icon.v2.runtime.PackageIconV2Host"

local ACT_ID = 4042
local ICON_V2_EXPERIMENT_MODULE = "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"
local LEGACY_ICON_PATH = "amf/dyminigame/texture/icon.png"
local ICON_V2_PATH = "amf/dyminigame/icon/icon_v2.png"
local OWNER_ICON_KEY = IconKey.kDYMiniGame

local AddSidebarManager = class("AddSidebarManager")

function AddSidebarManager:ctor()
    self.iconHost = PackageIconV2Host:create({
        owner = self,
        ownerIconKey = OWNER_ICON_KEY,
        iconEventCenter = IconEventCenter,
        isEligible = function()
            return self:isActValid()
        end,
        isV2Enabled = function()
            return self:isV2IconExperimentEnabled()
        end,
        prepareLegacyAssets = function()
            return self._assetsUtil:loadMiniFiles({LEGACY_ICON_PATH})
        end,
        prepareV2Assets = function()
            return self._assetsUtil:loadMiniFiles({ICON_V2_PATH})
        end,
        createV2Options = function()
            local IconV2Config = require "amf.feature.minihub.addsidebar.icon.IconV2Config"
            return IconV2Config:create(self, IconEventCenter)
        end,
        createLegacyIcon = function()
            return self:createLegacyIcon()
        end,
        refreshLegacy = function(icon)
            icon:updateState()
            return true
        end,
        onActivated = function()
            self:onMainIconActivated()
        end,
        preflightErrorPrefix = "ADD_SIDEBAR_V2_ASSET_LOAD_FAILED:",
        logError = function(stage, detail)
            DYMiniGameLog:log("AddSidebarManager icon host failed", stage, detail)
        end,
    })
end

function AddSidebarManager:initialize()
    _G.amfEC:registerFeature(self)
    InciteEventCenter:registerSystem(self)
    self._assetsUtil = _G.amfBean("AssetsUtil")
    self.addSidebarProxy = AddSidebarConfig:getProxy()
    self.model = Model:create()
end

function AddSidebarManager:setMainPanel(mainPanel)
    self.mainPanel = mainPanel
end

function AddSidebarManager:setAutoPopupMgr(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
end

function AddSidebarManager:getMainPanel()
    return self.mainPanel
end

function AddSidebarManager:isActEnabled()
    return self.addSidebarProxy ~= nil and self.addSidebarProxy:isAvailable()
end

function AddSidebarManager:isActValid()
    if not self:isActEnabled() then
        return false
    end
    if not self.model:isActOpen() then
        return false
    end
    if self.model:isTaskFinished() and
            self.model:getHasGotReward() then
        return false
    end
    return true
end

function AddSidebarManager:onActEnterStage4()
    if not self:checkStage4CanPop() then
        return
    end
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.KS_GAMECENTER_REVISIT)
    end

    local function creator()
        self:showMainPanel(onHandleOver, 2)
    end

    self._autoPopupMgr:addPopupConfig(PopupCheckPoint.KS_GAMECENTER_REVISIT, creator)
end

function AddSidebarManager:checkStage4CanPop()
    if not self:isActValid() then return false end
    if not self.isInit then return false end
    if self._autoPopupMgr:getPermanentShowNum("AddSideBarPop") > 0 then return false end
    return true
end

function AddSidebarManager:hasReward()
    if not self.model:isActOpen() then
        return false
    end
    if self.model:isTaskFinished() and not self.model:getHasGotReward() then
        return true
    end
    return false
end

function AddSidebarManager:isV2IconExperimentEnabled()
    if EnvUtil:isUnityEditor() then
        return true
    end
    local experiment = require(ICON_V2_EXPERIMENT_MODULE)
    return experiment:isEnabled()
end

function AddSidebarManager:createLegacyIcon()
    return DYMiniGameIcon:create()
end

function AddSidebarManager:getMainIcon()
    return self.iconHost:getIcon()
end

function AddSidebarManager:refreshMainIcon(reason, payload)
    return self.iconHost:refresh(reason, payload)
end

function AddSidebarManager:onMainIconActivated()
    self:refreshMainIcon("activated")
    local isFromSidebar = self:isFromSidebar()
    if isFromSidebar == true then
        _G.onSidebarShow()
    end
    self.isInit = true
end

function AddSidebarManager:createIcon()
    return self.iconHost:reconcile("manager_create")
end

function AddSidebarManager:isFromSidebar()
    return self.addSidebarProxy and self.addSidebarProxy:isFromSidebar()
end

function AddSidebarManager:removeIcon()
    local removed, removeError = self.iconHost:dispose("manager_remove")
    if removed then
        self:unloadRes({LEGACY_ICON_PATH, ICON_V2_PATH})
    end
    return removed, removeError
end

function AddSidebarManager:tryUpdateActIcon()
    if not self:isActValid() then
        return self:removeIcon()
    end
    return self.iconHost:reconcile("manager_update")
end

function AddSidebarManager:onMainIconTapped()
    self:showMainPanel(nil, 1)
    self:refreshMainIcon("icon_tapped")
end

function AddSidebarManager:onActEnterMainScene(evt)
    local data = evt:getData()
    if data and data.firstEnter then
        self:queryActInfoHttp({
            successCallback = function()
                self:tryUpdateActIcon()
            end,
        })
    end
end

function AddSidebarManager:addRewards(rewards, feature, source)
    local category = DcUtil:getMiniGameCategory()
    local sub_category = "side_entry_reward"
    DcUtil:UserTrack({category = category, sub_category = sub_category})

    source = source or category
    feature = feature or sub_category
    _G.GainPropData:create()
      :setActId(ACT_ID)
      :setFeature(feature)
      :setSource(source)
      :setProps(rewards):execute()
end

function AddSidebarManager:showMainPanel(closeCallback, fromType)
    if  self:getMainPanel() then return end
    self:queryActInfoHttp({
        noLoading = false,
        successCallback = function()
            if self:isActValid() then
                printx(44, "checkStage4CanPop")
                self._autoPopupMgr:sendPermanentData("AddSideBarPop")
                DcUtil:UserTrack({ category = DcUtil:getMiniGameCategory(), sub_category = 'side_entry_show', t1 = fromType })
                if self:getMainPanel() then safeRunCall(closeCallback) return end
                local vm = MainPanelVM:create()
                vm:setCloseCallback(closeCallback)
                vm:popout()
            else
                safeRunCall(closeCallback)
                self:removeIcon()
            end
        end,
        failCallback = function () safeRunCall(closeCallback) end,
        cancelCallback = function () safeRunCall(closeCallback) end
    })
end


function AddSidebarManager:flyItems(delegate)
    local rewards = delegate.rewards
    local callback = delegate.callback
    for k, v in pairs(rewards) do
        local startWorldPos = v.startWorldPos
        local flyContext = FlyItemContext.new(v, ccp(startWorldPos.x, startWorldPos.y))
                                         :setFinishCallback(function()
            if k == 1 then
                safeRunCall(callback)
            end
        end)
        _G.amfTransaction(TransactionEvent.FLY_ITEMS, flyContext)
    end
end

function AddSidebarManager:loadRes(delegate)
    local successCallback = delegate.successCallback
    local failCallback = delegate.failCallback
    local resList = delegate.resList
    if EnvUtil:isMiniGame() then
        return self._assetsUtil:loadMiniFiles(resList):next(successCallback, failCallback)
    else
        safeRunCall(successCallback)
    end
end

function AddSidebarManager:unloadRes(resList)
    if not EnvUtil:isMiniGame() then
        return
    end
    for k, v in pairs(resList) do
        if string.find(v, ".png") then
            CCTextureCache:sharedTextureCache():removeTextureForKey(
                    CCFileUtils:sharedFileUtils():fullPathForFilename(SpriteUtil:getRealResourceName(v), true)
            )
        elseif string.find(v, ".skel") then
            UICreateUtil:unloadSpineRes(v, true)
        elseif string.find(v, ".plist") then
            UICreateUtil:unloadPlist(v)
        end
    end
end

function AddSidebarManager:launchDY(done)
    self.addSidebarProxy:navigateToScene(function(result)
        local r = table.deserialize(result)
        if r and r.errCode == -1 then
            safeRunCall(done)
        end
    end)
end

_G.onSidebarShow = function()
    local mgr = _G.amfBean("AddSidebarManager")

    --if not mgr or not mgr:isActValid() or not isSafeCocosObj(mgr:getMainPanel()) then
    --    DYMiniGameLog:log("_G.onSidebarShow____1")
    --    return
    --end
    if not mgr then
        return
    end

    if not mgr.model:getHasGotReward() and not mgr.model:isTaskFinished() then
        DYMiniGameLog:log("_G.onSidebarShow____3")
        mgr:finishTaskHttp({
            successCallback = function()
                if mgr:getMainPanel() then
                    mgr:getMainPanel():refreshGetRewardBtnStr(true)
                end
            end,
            failCallback = function()

            end,
            cancelCallback = function()

            end,
        })
    else
        DYMiniGameLog:log("_G.onSidebarShow____2")
    end
end

--,查询；2，完成任务；3，领奖
function AddSidebarManager:sendHttp(delegate)
    local successCallback = delegate.successCallback
    local failCallback = delegate.failCallback
    local cancelCallback = delegate.cancelCallback
    local type = delegate.type or 1
    local noLoading = delegate.noLoading
    local request = require("amf.feature.minihub.addsidebar.http.SidebarMainInfo")
    local function onSuccess(evt)
        local data = evt:getData()
        safeRunCall(successCallback, data)
    end

    local function onFail(response)
        if not response:isCancel() then
            if not noLoading then
                CommonTip:showErrorTip(response)
            end
            safeRunCall(failCallback)
        else
            safeRunCall(cancelCallback)
        end
    end

    local param = {
        type = type,
    }

    request:post(param, noLoading):next(onSuccess, onFail)
end

--协议
function AddSidebarManager:queryActInfoHttp(delegate)
    delegate.type = 1
    if delegate.noLoading == nil then
        delegate.noLoading = true
    end
    local oriSuccessCallback = delegate.successCallback
    local successCallback = function(data)
        DYMiniGameLog:log("queryActInfoHttp", data)
        self.model:setValue("_isActOpen", data.open)
        self.model:setValue("_isTaskFinished", data.finishTask)
        self.model:setValue("_hasGotReward", data.gotRewards)
        if data.rewards then
            self.model:setValue("_rewardConfig",  data.rewards[1])
        end
        safeRunCall(oriSuccessCallback, data)
    end
    delegate.successCallback = successCallback
    self:sendHttp(delegate)
end

function AddSidebarManager:finishTaskHttp(delegate)
    delegate.type = 2
    delegate.noLoading = false
    local oriSuccessCallback = delegate.successCallback
    local successCallback = function(data)
        DYMiniGameLog:log("finishTaskHttp", data)
        self.model:setTaskFinished()
        self:tryUpdateActIcon()
        safeRunCall(oriSuccessCallback, data)
    end
    delegate.successCallback = successCallback
    self:sendHttp(delegate)
end

function AddSidebarManager:getRewardHttp(delegate)
    delegate.type = 3
    delegate.noLoading = false
    local oriSuccessCallback = delegate.successCallback
    local successCallback = function(data)
        DYMiniGameLog:log("getRewardHttp", data)
        self.model:setHasGotReward()
        self:addRewards(data.rewards)
        safeRunCall(oriSuccessCallback, data)
    end
    delegate.successCallback = successCallback
    self:sendHttp(delegate)
end

function AddSidebarManager:onSystemEnterForeground()
    if not self.isInit then return end
    self:queryActInfoHttp({
        successCallback = function()
            local isFromSidebar = self:isFromSidebar()
            if isFromSidebar == true then
                _G.onSidebarShow()
            end
            self:tryUpdateActIcon()
        end,
    })
end

_G.dcFavoriteSuccess = function()
    DcUtil:UserTrack({category = DcUtil:getMiniGameCategory(), sub_category = 'collect_success'})
end

_G.onRealNameAuthenticationComplete = function()
    DcUtil:UserTrack({category = DcUtil:getMiniGameCategory(), sub_category = 'autonym_result', t1 = 1})
end

return AddSidebarManager
