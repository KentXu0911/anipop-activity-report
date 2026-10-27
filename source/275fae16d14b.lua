local ShopRewardMainPopupLogic = class("ShopRewardMainPopupLogic")
require "amf.middleware.autopop.event.AutoPopEventCenter"

function ShopRewardMainPopupLogic:create(manager)
    local logic = ShopRewardMainPopupLogic.new()
    logic:init(manager)
    return logic
end

function ShopRewardMainPopupLogic:init(manager)
    self.manager = manager
end

function ShopRewardMainPopupLogic:getFirstMainPopupLocalKey()
    return "firstMainPopup_" .. tostring(self.manager:getPeriodId())
end

function ShopRewardMainPopupLogic:getRemindAfter24hPopupLocalKey()
    return "remindAfter24hPopup_" .. tostring(self.manager:getPeriodId())
end

function ShopRewardMainPopupLogic:hasFirstMainPopuped()
    if self.manager:getPeriodId() <= 0 then return true end
    return self.manager:getModel():getLocalCache(self:getFirstMainPopupLocalKey(), false) or false
end

function ShopRewardMainPopupLogic:markFirstMainPopuped()
    if self.manager:getPeriodId() <= 0 then return end
    self.manager:getModel():setLocalCache(self:getFirstMainPopupLocalKey(), false, true)
    self.manager:getModel():flush()
end

function ShopRewardMainPopupLogic:checkNeedFirstMainPopup()
    return self.manager:isEnabled() and not self:hasFirstMainPopuped()
end

function ShopRewardMainPopupLogic:hasRemindAfter24hPopuped()
    if self.manager:getPeriodId() <= 0 then return true end
    return self.manager:getModel():getLocalCache(self:getRemindAfter24hPopupLocalKey(), false) or false
end

function ShopRewardMainPopupLogic:markRemindAfter24hPopuped()
    if self.manager:getPeriodId() <= 0 then return end
    self.manager:getModel():setLocalCache(self:getRemindAfter24hPopupLocalKey(), false, true)
    self.manager:getModel():flush()
end

function ShopRewardMainPopupLogic:isAfterMainBegin24h()
    local mainBeginTime = self.manager:getModel():getMainBeginTime() or 0
    if mainBeginTime <= 0 then return false end
    return TimeKit:timeInSec() - mainBeginTime >= 24 * 60 * 60
end

function ShopRewardMainPopupLogic:checkNeedRemindAfter24hPopup()
    return self.manager:isEnabled() and self:isAfterMainBegin24h() and not self:hasRemindAfter24hPopuped()
end

function ShopRewardMainPopupLogic:getNextMainPopupType()
    local MainPanelVM = require "amf.feature.localactivity.shopreward.view.ShopRewardMainPanelVM"
    if self:checkNeedFirstMainPopup() then
        return MainPanelVM.PopupType.FIRST_TRIGGER
    elseif self:checkNeedRemindAfter24hPopup() then
        return MainPanelVM.PopupType.REMIND_AFTER_24H
    end
end

function ShopRewardMainPopupLogic:tryMainPopup()
    local popupType = self:getNextMainPopupType()
    if not popupType then return end

    if not self.manager:isMainPopupGoodsReady() then
        return
    end

    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.SHOP_REWARD_MAIN_POP)
    end

    local creator = function()
        self:doMainPopup(popupType, onHandleOver)
    end
    _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.SHOP_REWARD_MAIN_POP, creator)
end

function ShopRewardMainPopupLogic:isMainPopupTypeStillValid(popupType)
    local MainPanelVM = require "amf.feature.localactivity.shopreward.view.ShopRewardMainPanelVM"
    if popupType == MainPanelVM.PopupType.FIRST_TRIGGER then
        return self:checkNeedFirstMainPopup()
    elseif popupType == MainPanelVM.PopupType.REMIND_AFTER_24H then
        return self:checkNeedRemindAfter24hPopup()
    end
    return false
end

function ShopRewardMainPopupLogic:markMainPopuped(popupType)
    local MainPanelVM = require "amf.feature.localactivity.shopreward.view.ShopRewardMainPanelVM"
    if popupType == MainPanelVM.PopupType.FIRST_TRIGGER then
        self:markFirstMainPopuped()
    elseif popupType == MainPanelVM.PopupType.REMIND_AFTER_24H then
        self:markRemindAfter24hPopuped()
    end
end

function ShopRewardMainPopupLogic:doMainPopup(popupType, closeCallback)
    if not self:isMainPopupTypeStillValid(popupType) then
        safeRunCall(closeCallback)
        return
    end
    if not self.manager:isMainPopupGoodsReady() then
        safeRunCall(closeCallback)
        return
    end

    self:markMainPopuped(popupType)
    local MainPanelVM = require "amf.feature.localactivity.shopreward.view.ShopRewardMainPanelVM"
    local vm = MainPanelVM:create({
        popupType = popupType,
        manager = self.manager,
        mainPopupLogic = self,
        closeCallBack = closeCallback,
        maxExtraGoldNum = self:getMaxExtraGoldNum(),
        mainEndTime = self.manager:getMainEndTime(),
    })
    vm:setLoadResFailCallback(closeCallback)
    vm:popout(nil, true)
end

function ShopRewardMainPopupLogic:getMaxExtraGoldNum()
    return self.manager:getMaxExtraGoldNum()
end

function ShopRewardMainPopupLogic:getMainPanelShrinkTarget()
    local iconManager = _G.amfBean("IconManager")
    if not iconManager then return end

    local icon = iconManager:getIconByIconKey(IconKey.kShopReward)
    if isSafeCocosObj(icon) then
        return icon
    end

    local iconLayer = iconManager:getIconLayer()
    if iconLayer and iconLayer.topButtonLayout and isSafeCocosObj(iconLayer.topButtonLayout.goldButton) then
        return iconLayer.topButtonLayout.goldButton
    end
end

function ShopRewardMainPopupLogic:clearRemainingAutoPopupQueue()
    local autoPopupMgr = _G.amfBean("AutoPopupMgr")
    if not autoPopupMgr then return end

    if autoPopupMgr.resetPopup then
        autoPopupMgr:resetPopup()
    end
end

return ShopRewardMainPopupLogic
