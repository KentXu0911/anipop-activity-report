local AddStepGiftView = require "amf.feature.giftpackage.common.view.addstep.AddStepGiftView"
local BottomPlugGiftView = require "amf.feature.giftpackage.common.view.BottomPlugGiftView"
local Res = require "amf.feature.localactivity.shopreward.const.Res"
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local ShopRewardEventCenter = require "amf.feature.localactivity.shopreward.event.ShopRewardEventCenter"

local ShopRewardAddStepView = class("ShopRewardAddStepView", AddStepGiftView)

local NODE_HEIGHT = 327
function ShopRewardAddStepView:create(delegate, giftData)
    local view = self.new()
    view:init(delegate, giftData)
    return view
end

function ShopRewardAddStepView:initData(delegate, giftData)
    self.delegate = delegate or {}
    self:setGiftData(giftData)
end

function ShopRewardAddStepView:initUI()
    self:initBaseUI()
    self:initCustomUI()
    self:buildShopRewardNode()
end

function ShopRewardAddStepView:initCustomUI()
    BottomPlugGiftView.initCustomUI(self)
    if self.layout then
        self.layout:setVisible(false)
    end
end

function ShopRewardAddStepView:buildShopRewardNode()
    UICreateUtil:loadPlist(Res.Plist.ADDSTEPNODE)
    UICreateUtil:loadPlist(Res.Plist.NUMFRAME)
    UICreateUtil:loadSpineRes(Res.Spine.ADD_ANI)

    local uiData = require "amf.feature.localactivity.shopreward.view.uisource.ShopRewardAddStepNode_UI"
    local node = UIBuilder:buildUI(uiData, self)
    node:setPositionXY(0, NODE_HEIGHT + 95)
    self.ui:addChild(node)
    self.shopRewardNode = node

    self:initGoShopBtn()
    self:refreshExtraGoldNum()
    self:updateByTime(self:getRemainTime())

    local spine = UICreateUtil:createSpine(Res.Spine.ADD_ANI)
    spine:setPositionXY(301, 198)
    self.shopRewardNode:addChildAt(spine, 4)
    spine:playLoop("idle")

    self:registerActivityEndedEvent()
end

function ShopRewardAddStepView:registerActivityEndedEvent()
    if self._onShopRewardActivityEnded then return end

    self._onShopRewardActivityEnded = function()
        if self.isDisposed then return end
        self:updateByTime(0)
    end
    ShopRewardEventCenter:register(ShopRewardEvent.ACT_MAIN_ENDED, self._onShopRewardActivityEnded)
end

function ShopRewardAddStepView:unregisterActivityEndedEvent()
    if not self._onShopRewardActivityEnded then return end

    ShopRewardEventCenter:unregister(ShopRewardEvent.ACT_MAIN_ENDED, self._onShopRewardActivityEnded)
    self._onShopRewardActivityEnded = nil
end

function ShopRewardAddStepView:initGoShopBtn()
    if not self.goShopBtn then return end

    self.goShopBtn:setTouchHandler(preventContinuousClick(function()
        self:onGoBtnTapped()
    end))
end

function ShopRewardAddStepView:getExtraGoldNum()
    local manager = _G.amfBean("ShopRewardManager")
    return manager and manager:getMaxExtraGoldNum(GiftPackageConst.StageType.ADD_STEP) or 0
end

function ShopRewardAddStepView:refreshExtraGoldNum()
    if not isSafeCocosObj(self.HorizontalContainer) then return end

    local extraGoldNum = math.max(tonumber(self:getExtraGoldNum()) or 0, 0)
    if self._extraGoldNum == extraGoldNum then return end
    self._extraGoldNum = extraGoldNum

    self.HorizontalContainer:removeChildren(true)
    local numStr = tostring(extraGoldNum)
    for i = 1, string.len(numStr) do
        local digit = string.sub(numStr, i, i)
        local sprite = Sprite:createWithSpriteFrameName(Res.DigitFramePrefix .. digit)
        if sprite then
            sprite:setScale(0.61)
            sprite:setAnchorPoint(ccp(0.5, 0.5))
            local zOrderIndex = i
            sprite.getZOrderIndex = function()
                return zOrderIndex
            end
            sprite:setPositionY(34)
            self.HorizontalContainer:addChild(sprite)
        end
    end
end

function ShopRewardAddStepView:getRemainTime()
    local manager = _G.amfBean("ShopRewardManager")
    if not manager or not manager:isEnabled() then return 0 end

    return math.max((manager and manager:getMainEndTime() or 0) - TimeKit:timeInSec(), 0)
end

function ShopRewardAddStepView:initTimeLimit()
    self:removeTimeLimitTimer()
    self._tickId = TimerUtil.addAlarm(function()
        if self.isDisposed then return end
        self:updateByTime(self:getRemainTime())
    end, 1, 0)
    self:updateByTime(self:getRemainTime())
end

function ShopRewardAddStepView:removeTimeLimitTimer()
    if not self._tickId then return end

    TimerUtil.removeAlarm(self._tickId)
    self._tickId = nil
end

function ShopRewardAddStepView:updateByTime(remainTime)
    if not isSafeCocosObj(self.timeText) then return end

    self:refreshExtraGoldNum()

    if remainTime <= 0 then
        self:removeTimeLimitTimer()
        self:removeSelf()
    else
        local ret = TimeUtil:timeFormatVer1({
            endTimeInSec = TimeKit:timeInSec() + remainTime,
        })
        self.timeText:setString(ret.retString)
    end
end

function ShopRewardAddStepView:dispose()
    self:removeTimeLimitTimer()
    self:unregisterActivityEndedEvent()
    UICreateUtil:unloadPlist(Res.Plist.ADDSTEPNODE)
    UICreateUtil:unloadPlist(Res.Plist.NUMFRAME)
    UICreateUtil:unloadSpineRes(Res.Spine.ADD_ANI)
    AddStepGiftView.dispose(self)
end

function ShopRewardAddStepView:onGoBtnTapped()
    if self.delegate and self.delegate.onGoStoreTapped then
        self.delegate:onGoStoreTapped()
    end
end

function ShopRewardAddStepView:getActId()
    local manager = _G.amfBean("ShopRewardManager")
    return manager and manager:getConst().actId
end

return ShopRewardAddStepView
