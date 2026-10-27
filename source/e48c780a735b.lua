local BaseIcon
if _G.MainSceneFloderVersion and _G.MainSceneFloderVersion >= 1.1 then
    BaseIcon = require "amf.feature.mainscene.module.icon.view.BaseIcon"
elseif not _G.MainSceneFloderVersion then
    BaseIcon = require "amf.feature.mainscene.icon.view.BaseIcon"
end
local CollectCardEventCenter = require "amf.feature.localactivity.collectcard.event.CollectCardEventCenter"
local CollectCardGiftIcon = class("CollectCardGiftIcon", BaseIcon)


function CollectCardGiftIcon:getAssetsList()
    return {
        "amf/activity/collectcard/icon/jika_icon.skel",

    }
end

function CollectCardGiftIcon:create(mgr)
    local icon = CollectCardGiftIcon.new()
    icon:init(mgr)
    return icon
end

function CollectCardGiftIcon:init(mgr)
    self.mgr = mgr

    BaseIcon.init(self, IconKey.kCollectCardGiftIcon)
    -- self:setPayMode(self.IconPayType.NoDiscount)
    -- self:setProhibitStrongReward(true)

    local endTime = self.mgr:getModel():getGiftEndTime()
    self.endTime = endTime
    self:startCountdownVer1({{
                                 type = "activity",
                                 labelText = "新卡礼包",
                                 endTimeInSec = endTime,
                                 startTimeInSec = 0,
                                 reachText = "00:00:00",
                                 endCallback = function()
                                    self.mgr:updateGiftIcon()
                                 end,
                             }})
    self:registerEvent()

    if EnvUtil:isMiniGame() then
        self:updateRedDot()
    end
end


function CollectCardGiftIcon:onTouch()
    BaseIcon.onTouch(self)
    self.mgr:onGiftIconTapped()
    self.mgr:setFlagToLocalByKey("HasTappedGiftIcon"..self.endTime)
end

function CollectCardGiftIcon:buildIcon()
    self.iconLayer = Layer:create()
    self.iconLayer:setContentSize(CCSizeMake(100, 100))
    self.iconSp = UICreateUtil:createSpine("amf/activity/collectcard/icon/jika_icon.skel")
    self.iconSp:setScale(0.95)
    self.iconSp:setPositionXY(50, 50)
    self.iconLayer:addChild(self.iconSp)

    self._isSpineAnimStrong = false
    self:_playIconAnim(true)
    return self.iconLayer
end

function CollectCardGiftIcon:hasReward()
    --local buyEndTime = self.mgr:getLocalDataServer():getBuyAndFreeBuyEndTime()
    --if TimeKit:timeInSec() >= buyEndTime then
    --    return true
    --end
end

function CollectCardGiftIcon:updateRedDot()
    if self.isDisposed then return end
    if self:isNewAct() then
        self:getRedDot():showNewActDot()
    end
end

function CollectCardGiftIcon:isNewAct()
    return not self.mgr:getFlagFromLocalByKey("HasTappedGiftIcon"..self.endTime)
end

function CollectCardGiftIcon:registerEvent()
    CollectCardEventCenter:register(CollectCardEvent.ON_GIFT_ICON_UPDATE, self.updateAnim, self)
end

function CollectCardGiftIcon:unregisterEvent()
    CollectCardEventCenter:unregister(CollectCardEvent.ON_GIFT_ICON_UPDATE, self.updateAnim, self)
end

function CollectCardGiftIcon:updateAnim(event)
    if self.isDisposed then return end
    local isStrong = event == nil and true or event:getData()
    self:_playIconAnim(isStrong)
end

function CollectCardGiftIcon:_playIconAnim(isStrong)
    if self.isDisposed then return end
    if self._isSpineAnimStrong == isStrong then return end
    self._isSpineAnimStrong = isStrong
    self.iconSp:playLoop(isStrong and "idle_qiang" or "idle")
end

function CollectCardGiftIcon:dispose()
    self:unregisterEvent()
    BaseIcon.dispose(self)
end


return CollectCardGiftIcon
