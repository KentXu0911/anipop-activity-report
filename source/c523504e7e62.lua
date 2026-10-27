local PanelShrinkToTargetAnim = require "amf.middleware.ui.util.PanelShrinkToTargetAnim"
local ShopRewardEventCenter = require "amf.feature.localactivity.shopreward.event.ShopRewardEventCenter"
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local ShopRewardMainPanelVM = class("ShopRewardMainPanelVM", AMFBasePanelVM)

local ShrinkAnimConfig = {
    duration = 10 / 30,
    preScaleDuration = 2 / 30,
}
local ShrinkCallbackDelay = ShrinkAnimConfig.duration + ShrinkAnimConfig.preScaleDuration

ShopRewardMainPanelVM.PopupType = {
    FIRST_TRIGGER = "FIRST_TRIGGER",
    REMIND_AFTER_24H = "REMIND_AFTER_24H",
}

function ShopRewardMainPanelVM:_createPanel(...)
    local panel = require "amf.feature.localactivity.shopreward.view.ShopRewardMainPanel"
    return panel:create(ShopRewardMainPanelVM, ...)
end

function ShopRewardMainPanelVM:init(delegate)
    delegate = delegate or {}
    self.popupType = delegate.popupType or ShopRewardMainPanelVM.PopupType.FIRST_TRIGGER
    self.maxExtraGoldNum = delegate.maxExtraGoldNum or 0
    self.mainEndTime = delegate.mainEndTime or 0
    self.closeCallBack = delegate.closeCallBack
    self.mgr = delegate.manager or _G.amfBean("ShopRewardManager")
    self.mainPopupLogic = delegate.mainPopupLogic or self.mgr and self.mgr:getMainPopupLogic()
    self.panelId = UICreateUtil:getPanelId("ShopRewardMainPanel")
    ShopRewardEventCenter:register(ShopRewardEvent.ACT_MAIN_ENDED, self.onActMainEnded, self)
    if self.mgr and self.mgr.dcMainPanelShow then
        self.mgr:dcMainPanelShow(self.panelId, self:getDcPopupType())
    end
end

function ShopRewardMainPanelVM:firstLoadCompleted()
    if self.popupType == ShopRewardMainPanelVM.PopupType.REMIND_AFTER_24H then
        self:callViewFunc("initAfter24", self.maxExtraGoldNum)
    else
        self:callViewFunc("initFirstUI", self.maxExtraGoldNum)
    end
    self:callViewFunc("initButton")
end

function ShopRewardMainPanelVM:onEnterPanelRun()
    self:onPopupAnimationStarted()
    if self.popupType == ShopRewardMainPanelVM.PopupType.REMIND_AFTER_24H then
        self:callViewFunc("playMainPanelAnimation", "in2")
    else
        self:callViewFunc("playMainPanelAnimation", "in")
    end
end

function ShopRewardMainPanelVM:getDcPopupType()
    if self.popupType == ShopRewardMainPanelVM.PopupType.REMIND_AFTER_24H then
        return 2
    end
    return 1
end

function ShopRewardMainPanelVM:onGoBtnTapped()
    if self.mgr and self.mgr.dcMainPanelClick then
        self.mgr:dcMainPanelClick(self.panelId)
    end

    local closeCallBack = self.closeCallBack
    self.closeCallBack = nil

    local afterClose
    if self.mgr and self.mgr.openActivity then
        if self.mainPopupLogic and self.mainPopupLogic.clearRemainingAutoPopupQueue then
            self.mainPopupLogic:clearRemainingAutoPopupQueue()
        end
        afterClose = function()
            self.mgr:openActivity(closeCallBack, {
                source = StoreConfig.AccurateSource.Click_Act_ShopReward_Main,
            })
        end
    elseif closeCallBack then
        afterClose = closeCallBack
    end

    self:closeByPlatform(afterClose)
end

function ShopRewardMainPanelVM:onPopupAnimationStarted()
    self:stopCountdown()
end

function ShopRewardMainPanelVM:onPopupAnimationFinished()
    self:startCountdown()
end

function ShopRewardMainPanelVM:startCountdown()
    self:stopCountdown()
    self:updateCountdownLabel()
    self.countdownTimer = TimerUtil.addAlarm(function()
        self:updateCountdownLabel()
    end, 1, 0)
end

function ShopRewardMainPanelVM:stopCountdown()
    if self.countdownTimer then
        TimerUtil.removeAlarm(self.countdownTimer)
        self.countdownTimer = nil
    end
end

function ShopRewardMainPanelVM:updateCountdownLabel()
    local ret = TimeUtil:timeFormatVer1({
        endTimeInSec = self.mainEndTime or 0,
    })
    if ret.retString == "" then
        ret.retString = "已结束"
    end
    if ret.retString == "已结束" then
        self:handleActMainEndedOnce()
        return
    end
    self:callViewFunc("setCountdownText", ret.retString)
end

function ShopRewardMainPanelVM:onCloseBtnTapped()
    self._clickCloseBtn = true
    local closeCallBack = self.closeCallBack
    self.closeCallBack = nil
    self:closeByPlatform(closeCallBack)
end

function ShopRewardMainPanelVM:onActMainEnded()
    self:handleActMainEndedOnce()
end

function ShopRewardMainPanelVM:handleActMainEndedOnce()
    if self.actMainEndedHandled then return end
    self.actMainEndedHandled = true

    local closeCallBack = self.closeCallBack
    self.closeCallBack = nil
    self:closeByPlatform(function(...)
        safeRunCall(closeCallBack, ...)
        CommonTip:showTip("回馈狂欢活动已结束！")
    end)
end

function ShopRewardMainPanelVM:closeByPlatform(afterClose)
    if EnvUtil:isMiniGame() then
        self:setCloseCallback(nil)
        if not self.isDisposed then
            self:close()
        end
        safeRunCall(afterClose)
        return
    end

    self:closeWithShrinkAnim(afterClose)
end

function ShopRewardMainPanelVM:recycle()
    self:stopCountdown()
    ShopRewardEventCenter:unregister(ShopRewardEvent.ACT_MAIN_ENDED, self.onActMainEnded)
    AMFBasePanelVM.recycle(self)
end

function ShopRewardMainPanelVM:closeWithShrinkAnim(afterClose)
    if self.isClosingWithShrink then return end

    self.isClosingWithShrink = true
    local clickCloseBtn = self._clickCloseBtn

    local target = self:getShrinkTarget()
    if not isSafeCocosObj(target) then
        self:removePanelForShrinkClose()
        safeRunCall(afterClose, clickCloseBtn)
        return
    end

    local sourceNode = self:getShrinkSourceNode()
    if not isSafeCocosObj(sourceNode) then
        self:removePanelForShrinkClose()
        safeRunCall(afterClose, clickCloseBtn)
        return
    end

    local anim = PanelShrinkToTargetAnim.prepare({
        sourceNode = sourceNode,
        targetIcon = target,
        config = ShrinkAnimConfig,
    })
    if not anim then
        self:removePanelForShrinkClose()
        safeRunCall(afterClose, clickCloseBtn)
        return
    end

    self:removePanelForShrinkClose()
    anim:play()
    TimerUtil.addAlarm(function()
        safeRunCall(afterClose, clickCloseBtn)
    end, ShrinkCallbackDelay, 1)
end

function ShopRewardMainPanelVM:getShrinkTarget()
    if self.mainPopupLogic and self.mainPopupLogic.getMainPanelShrinkTarget then
        return self.mainPopupLogic:getMainPanelShrinkTarget()
    end
end

function ShopRewardMainPanelVM:getShrinkSourceNode()
    return self:callViewFunc("getShrinkSourceNode")
end

function ShopRewardMainPanelVM:removePanelForShrinkClose()
    self:setCloseCallback(nil)
    if self.isDisposed then return end

    self:close()
end

return ShopRewardMainPanelVM
