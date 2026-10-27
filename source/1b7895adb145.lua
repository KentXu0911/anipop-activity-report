
local SingleIconGiftModule = require "amf.feature.giftpackage.module.singleicon.SingleIconGiftModule"
local GiftEventCenter = require "amf.feature.giftpackage.event.GiftEventCenter"
local PaymentTracer = require 'amf.middleware.purchase.dc.trace.PaymentTracer'

---@class IceBreakingGiftModule : SingleIconGiftModule
local IceBreakingGiftModule = class("IceBreakingGiftModule", SingleIconGiftModule)
IceBreakingGiftModule._isAddEvent = false

function IceBreakingGiftModule:ctor()
    ---@type CommonGiftData
    self.packageData = nil
    self.moduleExtra = nil
    self._iconPath = "amf/icebreaking/materials/icon.png"
end

function IceBreakingGiftModule:awake()
    self.iconKey = IconKey.kIceBreaking
    printx(48, "[gk] iconkey=", self.iconKey)

    if not IceBreakingGiftModule._isAddEvent then
        IceBreakingGiftModule._isAddEvent = true
        _G.amfEC:registerSystem(self)
        if EnvUtil:isDevelopMode() then printx(48, "[gk] registerSystem") end
        GiftEventCenter:registerFeature(self)
    end

    ---@type PaymentTracer
    self._rmbTracer = nil
    self.dcFeature = "time_discounts_break"
    self.dcSource = "gift"
    self._isStage2Check = false
end

function IceBreakingGiftModule:remove()
    SingleIconGiftModule.remove(self)
    GiftEventCenter:unregisterFeature(self)
    _G.amfEC:unregisterSystem(self)
    IceBreakingGiftModule._isAddEvent = false
    releaseSpriteCache(self._iconPath)
end

function IceBreakingGiftModule:getResMap()
    return {
        labels = {
            "gift_layout_gold.label",
            "gift_layout_plugin.label",
        },
        files = {
            "amf/icebreaking/texture/IceBreakingStoreView.plist",
            -- "amf/activity/sprintgiftpackage/spine/sale_anim.skel",
        },
    }
end

function IceBreakingGiftModule:needUpdate()
    -- local ret = true
    -- if self.moduleExtra then
    --     local status = self.moduleExtra.status or 0
    --     ret = status == 1 and not self.packageData
    -- end
    -- return ret
    return self:isEnabled() and not self.packageData
end

function IceBreakingGiftModule:isEnabled()
    local ret = true
    -- 客户端在判断 status == 1 && 当前时间 >= nextCallPullTs
    -- && alreadyPassedLevel >= needPassLevel 时，认为可以尝试请求该礼包模块信息
    if self.moduleExtra then
        local status = self.moduleExtra.status or 0
        local nextCallPullTs = self.moduleExtra.nextCallPullTs or 0
        local alreadyPassedLevel = self.moduleExtra.alreadyPassedLevel or 0
        local needPassLevel = self.moduleExtra.needPassLevel or 0
        if status == 1 and TimeKit:timeInMillis() >= nextCallPullTs and alreadyPassedLevel >= needPassLevel then
            ret = true
        else
            ret = false
        end
    end
    if EnvUtil:isDevelopMode() then printx(48, "IceBreakingGiftModule:isEnable=",ret) end
    return ret
end

function IceBreakingGiftModule:requireExtraParams(stageInfo)
    return SingleIconGiftModule.requireExtraParams(self, stageInfo)
end

function IceBreakingGiftModule:onReceivePackages(packageList)
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

function IceBreakingGiftModule:doCreateGiftView(autoPopup)
    autoPopup = autoPopup or false
    local commonGiftData = self.packageData
    if not commonGiftData then return end
    local view = nil
    --根据场景判断使用view
    if commonGiftData.stageType == GiftPackageConst.StageType.STORE then
        local ViewCls = force_require "amf.feature.giftpackage.module.singleicon.icebreaking.view.IceBreakingStoreView"
        view = ViewCls:create(self, commonGiftData)
    else
        -- CommonTip:showTip("礼包面板")
        local userClick = not autoPopup
        self:_initRmbTracer(userClick)

        local VM = require "amf.feature.giftpackage.module.singleicon.icebreaking.view.IceBreakingGiftViewVM"
        local vm = VM:create(commonGiftData, self, autoPopup)
        return vm
    end

    return view
end

function IceBreakingGiftModule:getIconResMap()
    retainSpriteCache(self._iconPath)
    return {
        --change
        labels = {},
        files = {
            self._iconPath,
        },
    }
end

function IceBreakingGiftModule:createLegacyIcon()
    if not self.packageData then return end
    ---@type BaseIcon
    local icon = require("amf.feature.giftpackage.module.singleicon.icebreaking.view.IceBreakingGiftIcon"):create()
    local discount = self.packageData:getDiscount()
    if discount < 10 then icon:setDiscount(discount) end
    self:setIconTouch(icon)
    -- icon.onTouch = function()
    --     CommonTip:showTip("弹出面板~")
    -- end


    local endTime = self.packageData:getEndTime()
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

function IceBreakingGiftModule:doCreateSingleIcon()
    return self:createLegacyIcon()
end

--region extra data
function IceBreakingGiftModule:getPeriodId()
    if not self.moduleExtra then return 0 end
    local periodId = (self.moduleExtra or {}).periodId
    return periodId or 0
end

function IceBreakingGiftModule:getGiftTriggerTimes()
    if not self.moduleExtra then return 0 end
    local triggerTimes = (self.moduleExtra or {}).triggerTimes
    return triggerTimes or 0
end

function IceBreakingGiftModule:isShowTitle1()
    return not self:isShowDiscount()
end

function IceBreakingGiftModule:isShowDiscount()
    if not self.moduleExtra then return false end
    local ret = false
    local groupName = (self.moduleExtra or {}).groupName
    if groupName and groupName == "title_chaozhi" then ret = true end
    return ret
end

--endregion

-- 创建折扣icon 复用SprintGiftPackageManager
function IceBreakingGiftModule:createDiscountIcon(parentNode, isIdle, posX, posY, scale)
    -- do return false end
    local isShow = self:isShowDiscount()
    if not isShow then return nil end
    ---@type SprintGiftPackageManager
    local mgr = _G.amfBean("SprintGiftPackageManager")
    if not mgr then
        printx(48, "SprintGiftPackageManager is not found!Error!")
        return nil
    end
    scale = scale or 1
    if not self.packageData then return nil end
    local price = self.packageData:getPrice()

    local discountIcon = mgr:createDiscountIcon()
    if posX and posY then discountIcon:setPositionXY(posX, posY) end
    discountIcon:setScale(scale)
    local discountNum = price == 3 and 5000 or 3000
    if isIdle then
        discountIcon:playIdleAnim(discountNum)
    else
        discountIcon:playEnterAnim(discountNum)
    end
    parentNode:addChild(discountIcon)
    return discountIcon
end

--region 强弹



---本地缓存数据
function IceBreakingGiftModule:getFlagFromLocalByKey(key, needTime)
    if needTime then
        local today = time2day(TimeKit:timeInSec())
        key = key .. today
    end

    return LocalDB:getBool(key, false)
end

function IceBreakingGiftModule:setFlagToLocalByKey(key, needTime, value)
    value = value or true
    if needTime then
        local today = time2day(TimeKit:timeInSec())
        key = key .. today
    end
    LocalDB:setBool(key, value, true)
end

function IceBreakingGiftModule:_getLocalOpenedKey()
    if not self.packageData then return "xx" end
    return "IceBreakingOpened" .. tostring(self:getPeriodId()) .. tostring(self:getGiftTriggerTimes())
end

function IceBreakingGiftModule:_isUserNotOpened()
    -- do return true end --debug
    --强弹 玩家是否点击过
    local isUserClicked = self:getFlagFromLocalByKey(self:_getLocalOpenedKey(), false)
    if EnvUtil:isDevelopMode() then printx(48, "IceBreakingGiftModule:isUserClicked=", isUserClicked) end
    return not isUserClicked
end

function IceBreakingGiftModule:setUserOpened()
    self:setFlagToLocalByKey(self:_getLocalOpenedKey(), false, true)
end

function IceBreakingGiftModule:onActEnterStage2()
    -- printx(48, "[gk] onActEnterStage2")
    if not self.packageData then return end

    self._isStage2Check = true
    local canAutoPopup = self:_isUserNotOpened()
    if canAutoPopup then
        -- >6级 强弹，优先级小于签到高于其他
        local userLevel = _G.amfBean("UserManager"):getTopLevelId()
        canAutoPopup = userLevel > 6
    end
    if not canAutoPopup then return end
    self:tryAutoPopup()
end

function IceBreakingGiftModule:onActEnterStage4()
    if not self.packageData then return end
    local canAutoPopup = self:_isUserNotOpened()
    if canAutoPopup then
        -- ==6级 强弹优先级最高
        local userLevel = _G.amfBean("UserManager"):getTopLevelId()
        canAutoPopup = userLevel > 5
    end
    if not canAutoPopup then return end
    self:tryAutoPopup()
end

function IceBreakingGiftModule:tryAutoPopup()
    if not self.packageData then return end
    if self.packageData.stageType == GiftPackageConst.StageType.STORE then
        return
    end

    local popupKey = self:getGiftTriggerTimes() == 2 and PopupCheckPoint.ICE_BREAKING_GIFT_POP_T2 or PopupCheckPoint.ICE_BREAKING_GIFT_POP
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, popupKey)
    end

    local creator = function ()
        if not self:_isUserNotOpened() then
            safeRunCall(onHandleOver)
            return
        end
        ---@type UeAMFBasePanelVM
        local vm = self:doCreateGiftView(true)
        if not vm then
            safeRunCall(onHandleOver)
            return
        end
        if vm.setCloseCallback then
            vm:setCloseCallback(onHandleOver)
        else
            printx(48, "[gk] IceBreakingGiftModule why logcenter vm.setCloseCallback is nil?")
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


function IceBreakingGiftModule:onActPlayLevelEnd(evt)
    --过关
    if not evt then return end
    local data = evt.data
    if data and data.isWin and self.moduleExtra then
        self.moduleExtra.alreadyPassedLevel = (self.moduleExtra.alreadyPassedLevel or 0) + 1
    end
end
--endregion

--region store-购买成功



function IceBreakingGiftModule:onBuySuccess(storeGiftView)
    self:onBuySuccessRemoveView(storeGiftView)
end

--- 判断购买成功是否删除
---@param storeGiftView StoreBaseGiftView
function IceBreakingGiftModule:onBuySuccessRemoveView(storeGiftView)
    if not storeGiftView or not storeGiftView.giftData then return end
    local giftData = storeGiftView.giftData
    if giftData:isLimited() then
        storeGiftView:removeSelf()
        self:removeIcon()
    end
end

--endregion


--region 打点相关

function IceBreakingGiftModule:_initRmbTracer(userClick)
    self._rmbTracer = PaymentTracer.createRMBPayTracer(
        self.dcFeature,
        self.dcSource,
        self.packageData:getGoodsId(),
        userClick and DCPayProgressPayPanelShowType.kUserClick or DCPayProgressPayPanelShowType.kAutoPopout
    )
    return self._rmbTracer
end

function IceBreakingGiftModule:dcShow()
    if not self._rmbTracer then return end
    self._rmbTracer:show()
end

function IceBreakingGiftModule:requestBuy(succCallback, failCallback)
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
        self:removeIcon()
        safeRunCall(succCallback)

        local showRewards = package:getItems()
        local ShowRewardsPanelVM = require "amf.middleware.ui.kit.panel.reward.ShowRewardsPanelVM"
        local vm = ShowRewardsPanelVM.Builder.new()
            :setTitle("恭喜获得")
            :setRewards(showRewards)
            :setCloseCallback(function ()

            end)
            :setButtonText("收下")
            :build()
        vm:popout()
    end

    local function onFail(evt)
        self._rmbTracer:payFail()
        safeRunCall(failCallback)
    end

    local function onCancel()
        self._rmbTracer:payCancel()
        safeRunCall(failCallback)
    end

    self.newGift_stage = "bigVineScene"
    self.moduleName = "discountBreakIce"

    local buyContext = BuyContext.new(goodsId, MoneyType.kRmb)
        :setFeatureAndSource(self.dcFeature, self.dcSource)
        :setBuyCount(1)
        :setCallback(onSuccess, onFail, onCancel)
        :setUnifiedBuy(true, self.newGift_stage, self.moduleName)
    _G.amfTransaction(TransactionEvent.PAY, buyContext)
    self._rmbTracer:click()
end


--endregion


--region 音效

IceBreakingGiftModule.Sound = {
    ENTER_PANEL = 1, --进入面板
    BOTTOMUI = 2, --嗖声音,无折扣不播放
    SMASH = 3, --砸字

}
function IceBreakingGiftModule:playEffect(type)
    local file = string.format("amf/icebreaking/sound/ib_%d.mp3", type)
    GamePlayMusicPlayer.getInstance():playEffect(file, nil, false)
end

--endregion

-- home尝试更新 onSystemEnterForeground
function IceBreakingGiftModule:onSystemEnterForeground()
    -- printx(48, "[gk]IceBreakingGiftModule:onSystemEnterForeground")
    if self:needUpdate() then
        GiftEventCenter:dispatch(GiftEvent.STAGE_UPDATE, {
			stageType = GiftPackageConst.StageType.VINE_SCENE,
		})
    end
end


function IceBreakingGiftModule:parseModuleExtra(value)
    self.moduleExtra = table.deserialize(value or "") or {}
    local status = self.moduleExtra.status or 0
    if EnvUtil:isDevelopMode() then printx(48, "IceBreakingGiftModule:parseModuleExtra status=",status) end
    if status == 0 then
        self:remove()
    end
end

return IceBreakingGiftModule
