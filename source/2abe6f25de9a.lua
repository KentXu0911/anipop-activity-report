
local SingleIconGiftModule = require "amf.feature.giftpackage.module.singleicon.SingleIconGiftModule"
local GiftEventCenter = require "amf.feature.giftpackage.event.GiftEventCenter"
local PaymentTracer = require 'amf.middleware.purchase.dc.trace.PaymentTracer'
local Const = require "amf.feature.localactivity.returngift.config.ReturnGiftConst"
local Extra = require "amf.feature.localactivity.returngift.model.ReturnGiftExtra"
local ReturnGiftDC = require "amf.feature.localactivity.returngift.util.ReturnGiftDC"
local ReturnGiftActInfo = require "amf.feature.localactivity.returngift.util.ReturnGiftActInfo"
local ReturnGiftAssets = require "amf.feature.localactivity.returngift.util.ReturnGiftAssets"
local Mixin = require "amf.feature.localactivity.returngift.giftmodule.ReturnGiftModule_Mixin"

---@class ReturnGiftModule_Vine : SingleIconGiftModule
local ReturnGiftModule_Vine = class("ReturnGiftModule_Vine", SingleIconGiftModule)
ReturnGiftModule_Vine._isAddEvent = false

function ReturnGiftModule_Vine:ctor()
    ---@type CommonGiftData
    self.packageData = nil
    self.moduleExtra = nil
    self._iconPath = "amf/activity/returngift/materials/icon.png"

end

function ReturnGiftModule_Vine:awake()
    self.iconKey = IconKey.KReturnGift
    printx(48, "[gk] iconkey=", self.iconKey)

    if not ReturnGiftModule_Vine._isAddEvent then
        ReturnGiftModule_Vine._isAddEvent = true
        _G.amfEC:registerSystem(self)
        if EnvUtil:isDevelopMode() then printx(48, "[gk] registerSystem") end
        GiftEventCenter:registerFeature(self)
    end

    ---@type PaymentTracer
    self._rmbTracer = nil
    self.dcFeature = "return_package"
    self.dcSource = "gift"
    self._isStage2Check = false
end

function ReturnGiftModule_Vine:remove()
    SingleIconGiftModule.remove(self)
    GiftEventCenter:unregisterFeature(self)
    _G.amfEC:unregisterSystem(self)
    ReturnGiftModule_Vine._isAddEvent = false
    releaseSpriteCache(self._iconPath)
end

function ReturnGiftModule_Vine:getResMap()
    return ReturnGiftAssets.getVineResMap()
end

function ReturnGiftModule_Vine:needUpdate()
    -- local ret = true
    -- if self.moduleExtra then
    --     local status = self.moduleExtra.status or 0
    --     ret = status == 1 and not self.packageData
    -- end
    -- return ret
    if Extra.isRewarding(self.moduleExtra) then
        return true
    end
    return self:isEnabled() and not self.packageData
end

function ReturnGiftModule_Vine:isEnabled()
    -- if not MaintenanceManager.getInstance():isEnabledAndInGroup("return_package2026", true, "main") then return end
    if EnvUtil:isDevelopMode() then printx(48, "ReturnGiftModule_Vine:isEnable") end
    return Mixin.isEnabled(self, "main")
end

function ReturnGiftModule_Vine:isActInfoEnabled()
    return ReturnGiftActInfo:isActInfoEnabled()
end

function ReturnGiftModule_Vine:requireExtraParams(stageInfo)
    return SingleIconGiftModule.requireExtraParams(self, stageInfo)
end

function ReturnGiftModule_Vine:onReceivePackages(packageList)
    if not packageList then return end
    if packageList[1] then
        SingleIconGiftModule.onReceivePackages(self, packageList)
    else
        self.packageList = packageList or {}
        self.packageData = self.packageList
    end
    if self.packageData then
       self:parseModuleExtra(self.packageData:getExtraValue("moduleExtra"))
    end
    if not self._isStage2Check then self:onActEnterStage2() end
end

function ReturnGiftModule_Vine:doCreateGiftView(autoPopup)
    autoPopup = autoPopup or false
    local commonGiftData = self.packageData
    if not commonGiftData then return end

    -- CommonTip:showTip("礼包面板")
    local userClick = not autoPopup
    self:_initRmbTracer(userClick)

    local packageType = self:getCurrentPackageType(commonGiftData)
    local vmPath = "amf.feature.localactivity.returngift.view.ReturnGift1PanelVM"
    if packageType == Const.PackageType.PACKAGE_2 then
        vmPath = "amf.feature.localactivity.returngift.view.ReturnGift2PanelVM"
    end
    local VM = require(vmPath)
    local vm = VM:create(commonGiftData, self, autoPopup)
    self:_markAutoPopuped()
    return vm

end

function ReturnGiftModule_Vine:getCurrentPackageType(commonGiftData)
    local packageType = Extra.getPackageType(self.moduleExtra)
    if packageType and packageType ~= Const.PackageType.NONE then
        return packageType
    end

    if commonGiftData and commonGiftData.getExtraValue then
        packageType = tonumber(commonGiftData:getExtraValue("packageType"))
        if packageType then return packageType end
    end

    return Const.PackageType.PACKAGE_1
end

function ReturnGiftModule_Vine:getIconResMap()
    retainSpriteCache(self._iconPath)
    return {
        --change
        labels = {},
        files = {
            self._iconPath,
        },
    }
end

function ReturnGiftModule_Vine:doCreateSingleIcon()
    if not self.packageData then return end
    ---@type BaseIcon
    local packageType = self:getCurrentPackageType(self.packageData)
    local icon = require("amf.feature.localactivity.returngift.view.ReturnGiftIcon"):create(Extra.isRewarding(self.moduleExtra), packageType, self:_isIconOpened())
    -- self:setIconTouch(icon)
    icon.onTouch = function()
        if not _G.amfBean("NetworkStatusManager"):isNetworkEnabled() then
            CommonTip:showTip("网络异常，请检查网络~")
            return
        end
        self:doCreateGiftViewAsync():next(function(panelVm)
            panelVm:popout(nil, true)
        end)
    end


    local endTime = self.packageData:getEndTime()
    if Extra.isRewarding(self.moduleExtra) then
        local rewardEndTime = Extra.getRewardEndTime(self.moduleExtra)
        if rewardEndTime > 0 then
            endTime = rewardEndTime
        end
    end
    if endTime > 0 then
        icon:startCountdownVer1({{
            type = "activity",
            endTimeInSec = endTime,
            startTimeInSec = 0,
            reachText = "00:00:00",
            endCallback = function ()
                self:onDeprecated()
            end
        }})
    end
    return icon

end

function ReturnGiftModule_Vine:isShowTitle1()
    return not self:isShowDiscount()
end

function ReturnGiftModule_Vine:isShowDiscount()
    if not self.moduleExtra then return false end
    local ret = false
    local groupName = (self.moduleExtra or {}).groupName
    if groupName and groupName == "title_chaozhi" then ret = true end
    return ret
end

--endregion


--region 强弹



---本地缓存数据
function ReturnGiftModule_Vine:getFlagFromLocalByKey(key, needTime)
    if needTime then
        local today = time2day(TimeKit:timeInSec())
        key = key .. today
    end

    return LocalDB:getBool(key, false)
end

function ReturnGiftModule_Vine:setFlagToLocalByKey(key, needTime, value)
    value = value or true
    if needTime then
        local today = time2day(TimeKit:timeInSec())
        key = key .. today
    end
    LocalDB:setBool(key, value, true)
end


function ReturnGiftModule_Vine:_getIconOpenedKey()
    if not self.packageData then return "ReturnGiftIconOpened" .. tostring(Const.ActId) end
    local goodsId = self.packageData.getGoodsId and self.packageData:getGoodsId() or 0
    return "ReturnGiftIconOpened" .. tostring(Const.ActId) .. "_" .. tostring(self:getCurrentPackageType(self.packageData)) .. "_" .. tostring(goodsId)
end

function ReturnGiftModule_Vine:_isIconOpened()
    local opened = self:getFlagFromLocalByKey(self:_getIconOpenedKey(), false)
    if EnvUtil:isDevelopMode() then printx(48, "ReturnGiftModule_Vine:iconOpened=", opened) end
    return opened
end

function ReturnGiftModule_Vine:_getPopupKey()
    local packageType = self:getCurrentPackageType(self.packageData)
    if Extra.isRewarding(self.moduleExtra) then
        return "ReturnGiftRewardPopup" .. tostring(packageType)
    end
    return "ReturnGiftBuyPopup" .. tostring(packageType)
end


function ReturnGiftModule_Vine:_hasAutoPopuped()
    local popuped = self:getFlagFromLocalByKey(self:_getPopupKey(), false)
    if EnvUtil:isDevelopMode() then printx(48, "ReturnGiftModule_Vine:hasAutoPopuped=", popuped) end
    return popuped
end

function ReturnGiftModule_Vine:_markAutoPopuped()
    self:setFlagToLocalByKey(self:_getPopupKey(), false, true)
end

function ReturnGiftModule_Vine:_canAutoPopup()
    -- do return true end --debug
    if self:_hasAutoPopuped() then return false end
    if Extra.isRewarding(self.moduleExtra) then
        local rewardEndTime = Extra.getRewardEndTime(self.moduleExtra)
        return rewardEndTime <= 0 or rewardEndTime > TimeKit:timeInSec()
    end
    return true
end

function ReturnGiftModule_Vine:setUserOpened(autoPopup)
    self:setFlagToLocalByKey(self:_getIconOpenedKey(), false, true)

    local IconManager = _G.amfBean and _G.amfBean("IconManager")
    local icon = IconManager and IconManager.getIconByIconKey and IconManager:getIconByIconKey(IconKey.KReturnGift, true)
    if icon and icon.setOpenedFlag then
        icon:setOpenedFlag(true)
    end
end

function ReturnGiftModule_Vine:onActEnterStage2()
    -- printx(48, "[gk] onActEnterStage2")
    if not self.packageData then return end

    self._isStage2Check = true
    local canAutoPopup = self:_canAutoPopup()
    if not canAutoPopup then return end
    self:tryAutoPopup()
end

function ReturnGiftModule_Vine:onActEnterStage4()
    if not self.packageData then return end
    local canAutoPopup = self:_canAutoPopup()
    if not canAutoPopup then return end
    self:tryAutoPopup()
end

function ReturnGiftModule_Vine:tryAutoPopup()
    if not self.packageData then return end
    if self.packageData.stageType == GiftPackageConst.StageType.STORE then
        return
    end

    local popupKey = PopupCheckPoint.RETURN_GIFT_POP or PopupCheckPoint.ICE_BREAKING_GIFT_POP
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, popupKey)
    end

    local creator = function ()
        if not self:_canAutoPopup() then
            safeRunCall(onHandleOver)
            return
        end
        self:_markAutoPopuped()
        ---@type UeAMFBasePanelVM
        local vm = self:doCreateGiftView(true)
        if not vm then
            safeRunCall(onHandleOver)
            return
        end
        if vm.setCloseCallback then
            vm:setCloseCallback(onHandleOver)
        else
            printx(48, "[gk] ReturnGiftModule_Vine why logcenter vm.setCloseCallback is nil?")
            safeRunCall(onHandleOver)
        end

        if vm.setLoadResFailCallback then vm:setLoadResFailCallback(onHandleOver) end
        vm:popout()
    end

    -- _G.amfBean("AutoPopupMgr"):addPopupConfig(popupKey, creator)
    local autoPopupMgr = _G.amfBean("AutoPopupMgr")
    autoPopupMgr:addPopupConfig(popupKey, creator)
    if not autoPopupMgr:isRunnning() then
        autoPopupMgr:triggerStage2AutoPopup()
    end
end


function ReturnGiftModule_Vine:onActPlayLevelEnd(evt)
    --过关
    if not evt then return end
    local data = evt.data
    if data and data.isWin and self.moduleExtra then
        self.moduleExtra.alreadyPassedLevel = (self.moduleExtra.alreadyPassedLevel or 0) + 1
    end
end
--endregion

--region store-购买成功



function ReturnGiftModule_Vine:onBuySuccess(storeGiftView)
    self:onBuySuccessRemoveView(storeGiftView)
end

--- 判断购买成功是否删除
---@param storeGiftView StoreBaseGiftView
function ReturnGiftModule_Vine:onBuySuccessRemoveView(storeGiftView)
    if not storeGiftView or not storeGiftView.giftData then return end
    local giftData = storeGiftView.giftData
    if giftData:isLimited() then
        storeGiftView:removeSelf()
        self:onDeprecated()
    end
end

function ReturnGiftModule_Vine:handleBuySuccessIcon()
    local packageType = self:getCurrentPackageType(self.packageData)
    if packageType == Const.PackageType.PACKAGE_2 then
        self:refreshIconToRewarding()
    else
        self:onDeprecated()
    end
end

function ReturnGiftModule_Vine:refreshIconToRewarding()
    local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
    IconEventCenter:refreshIconEvent(self.iconKey)

    local IconManager = _G.amfBean and _G.amfBean("IconManager")
    local icon = IconManager and IconManager.getIconByIconKey and IconManager:getIconByIconKey(IconKey.KReturnGift, true)
    if not icon then return end

    if icon.setPackageType then icon:setPackageType(Const.PackageType.PACKAGE_2) end
    if icon.setRewardFlag then icon:setRewardFlag(true) end
    if not icon.startCountdownVer1 then return end

    local endTime = Extra.getRewardEndTime(self.moduleExtra)
    if endTime <= 0 then return end

    if icon.stopCountdown then icon:stopCountdown() end
    icon:startCountdownVer1({{
        type = "activity",
        endTimeInSec = endTime,
        startTimeInSec = 0,
        reachText = "00:00:00",
        endCallback = function ()
            self:onDeprecated()
        end,
    }})
end

--endregion


--region 打点相关

function ReturnGiftModule_Vine:_initRmbTracer(userClick)
    self._returnGiftPanelId = ReturnGiftDC:getPanelId()
    self._returnGiftAutoPopup = not userClick
    self._rmbTracer = PaymentTracer.createRMBPayTracer(
        self.dcFeature,
        self.dcSource,
        self.packageData:getGoodsId(),
        userClick and DCPayProgressPayPanelShowType.kUserClick or DCPayProgressPayPanelShowType.kAutoPopout,
        { showId = self._returnGiftPanelId }
    )
    return self._rmbTracer
end

function ReturnGiftModule_Vine:dcShow()
    if not self._rmbTracer then return end
    self._rmbTracer:show()
    ReturnGiftDC:dcMainPanelShow(self._returnGiftPanelId, self._returnGiftAutoPopup and "popoup" or "vine_icon", 1)
end

function ReturnGiftModule_Vine:dcJoin()
    ReturnGiftDC:dcJoinOnce()
end

function ReturnGiftModule_Vine:requestBuy(succCallback, failCallback, suppressRewardPanel)
    if not _G.amfBean("NetworkStatusManager"):isNetworkEnabled() then
        CommonTip:showTip("网络异常，请检查网络~")
        safeRunCall(failCallback)
        return
    end
    local package = self.packageData
    if not package then
        safeRunCall(failCallback)
        return
    end

    local goodsId = package:getGoodsId()

    local function onSuccess(evt)
        self._rmbTracer:paySuccess()
        self:dcJoin()
        self:handleBuySuccessIcon()
        Mixin.clearPanelPackageData()
        safeRunCall(succCallback)
    end

    local function onFail(evt)
        self._rmbTracer:payFail()
        safeRunCall(failCallback)
    end

    local function onCancel()
        self._rmbTracer:payCancel()
        safeRunCall(failCallback)
    end

    self.newGift_stage = GiftPackageConst.StageType.VINE_SCENE
    self.moduleName = Const.ModuleName

    local buyContext = BuyContext.new(goodsId, MoneyType.kRmb)
        :setFeatureAndSource(self.dcFeature, self.dcSource)
        :setBuyCount(1)
        :setCallback(onSuccess, onFail, onCancel)
        :setUnifiedBuy(true, self.newGift_stage, self.moduleName)
    _G.amfTransaction(TransactionEvent.PAY, buyContext)
    self._rmbTracer:click()
end

function ReturnGiftModule_Vine:claimReward(rewardIndex, succCallback, failCallback)
    return Mixin.claimReward(self, rewardIndex, succCallback, failCallback)
end

function ReturnGiftModule_Vine:onAllRewardsClaimed(giftView)
    Mixin.clearPanelPackageData()
    self:onDeprecated()
    if giftView and giftView.removeSelf then giftView:removeSelf() end
end

function ReturnGiftModule_Vine:tryShowRewardPanel(rewards)
    return Mixin.tryShowRewardPanel(self, rewards)
end


--endregion


--region 音效

ReturnGiftModule_Vine.Sound = {
    ENTER_PANEL = 1, --进入面板
    BOTTOMUI = 2, --嗖声音,无折扣不播放
    SMASH = 3, --砸字

}
function ReturnGiftModule_Vine:playEffect(type)
    local file = string.format("amf/icebreaking/sound/ib_%d.mp3", type)
    GamePlayMusicPlayer.getInstance():playEffect(file, nil, false)
end

--endregion

-- home尝试更新 onSystemEnterForeground
function ReturnGiftModule_Vine:onSystemEnterForeground()
    -- printx(48, "[gk]ReturnGiftModule_Vine:onSystemEnterForeground")
    if self:needUpdate() then
        GiftEventCenter:dispatch(GiftEvent.STAGE_UPDATE, {
			stageType = GiftPackageConst.StageType.VINE_SCENE,
		})
    end
end


function ReturnGiftModule_Vine:parseModuleExtra(value)
    self.moduleExtra = Extra.parse(value)
    local status = self.moduleExtra.status or 0
    if EnvUtil:isDevelopMode() then printx(48, "ReturnGiftModule_Vine:parseModuleExtra status=",status) end
    if Extra.getRewardEndTime(self.moduleExtra) > 0 then
        GiftEventCenter:dispatch(GiftEvent.RETURN_GIFT_REWARDING_EXTRA_UPDATE, {
            moduleExtra = self.moduleExtra,
        })
    end
    if status == 7 then
        self:remove()
    else
        ReturnGiftDC:dcQualify(self.moduleExtra)
    end
end

return ReturnGiftModule_Vine
