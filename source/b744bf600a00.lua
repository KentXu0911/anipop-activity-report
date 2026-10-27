local StoreGoodsGiftView = force_require "amf.feature.giftpackage.common.view.store.StoreGoodsGiftView"
local Res = require "amf.feature.localactivity.shopreward.const.Res"
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local ActionCreator = require "amf.middleware.ui.util.ActionCreator"
local ShopRewardEventCenter = require "amf.feature.localactivity.shopreward.event.ShopRewardEventCenter"

---@class ShopRewardStoreView : StoreGoodsGiftView
local ShopRewardStoreView = class("ShopRewardStoreView", StoreGoodsGiftView)

local GUIDE_STEP_DURATION = 10 / 30
local DEFAULT_STEP_DURATION = 3 / 30

local oriLabelCfg = {
    goldBg = {
        init = {},
        actions = {
            {time = 3/30, scale = 1.49},
            {time = 2/30, scale = 1.45},
            {delay = 8/30, time = 5/30, scale = 0.95},
            {time = 3/30, scale = 1}
        }
    },
    goldLabel = {
        init = {},
        actions = {
            {time = 3/30, scale = 1.49},
            {time = 2/30, scale = 1.45},
            {delay = 8/30, time = 5/30, scale = 0.95},
            {time = 3/30, scale = 1}
        }
    },
    line = {
        init = {
            scale = {x = 0, y = 1}
        },
        actions = {
            {delay = 3/30, time = 5/30, scale = {x = 1, y = 1}}
        }
    },
    lineLayer = {
        init = {},
        actions = {
            {time = 3/30, scale = 1.49},
            {time = 2/30, scale = 1.45},
            {delay = 8/30, time = 5/30, scale = 0.95},
            {time = 3/30, scale = 1}
        }
    }
}

function ShopRewardStoreView:initCustomUI()
    StoreGoodsGiftView.initCustomUI(self)
    UICreateUtil:loadPlist(Res.Plist.NUMFRAME)
    UICreateUtil:loadSpineRes(Res.Spine.ZHAN)
    self.isShopRewardStoreView = true
    self:updateGoldIconNum()
    self:registerGuideLineAnimEvent()
end

function ShopRewardStoreView:setSpecialTag()
    local sTag = self.giftData and self.giftData:getExtraValue("tagText")
    if sTag then
        self.layout:setCornerText(sTag, 1.33)
    end
end

function ShopRewardStoreView:registerGuideLineAnimEvent()
    if self.guideLineAnimListener then return end

    self.guideLineAnimListener = function(event)
        self:onGuideLineAnimPlay(event)
    end
    ShopRewardEventCenter:register(ShopRewardEvent.GUIDE_LINE_ANIM_PLAY, self.guideLineAnimListener)
end

function ShopRewardStoreView:unregisterGuideLineAnimEvent()
    if not self.guideLineAnimListener then return end

    ShopRewardEventCenter:unregister(ShopRewardEvent.GUIDE_LINE_ANIM_PLAY, self.guideLineAnimListener)
    self.guideLineAnimListener = nil
end

function ShopRewardStoreView:onGuideLineAnimPlay(event)
    if self.isDisposed then return end

    self.shopRewardGuideLineAnimTriggered = true
    self:playShopRewardAnimWithDelay(self:getShopRewardGuideAnimDelay(), true)
end

function ShopRewardStoreView:playShopRewardAnimWithDelay(delay, forcePlay)
    setTimeOut(function()
        if self.isDisposed then return end
        if self.shopRewardAnimPlayed then return end
        if not forcePlay and self.shopRewardGuideLineAnimTriggered then return end
        if not forcePlay and self:shouldWaitStoreGuideLineAnim() then
            self.shopRewardAnimTimerStarted = false
            self:startShopRewardAnimDelayTimer()
            return
        end

        self.shopRewardAnimPlayed = true
        self:playOriginGoldAnim()
        self:replaceStoreTextWithShopRewardPriceNode()
        self:playShopRewardPriceAnim()
        self:setWaitingStoreGuideLineAnim(false)
    end, delay or self:getShopRewardAnimDelay())
end

function ShopRewardStoreView:setPayProgressInfo(info)
    StoreGoodsGiftView.setPayProgressInfo(self, info)
    self.storeGiftIndex = info and info.showPos
    self:startShopRewardAnimDelayTimer()
end

function ShopRewardStoreView:startShopRewardAnimDelayTimer()
    if self.shopRewardAnimTimerStarted then return end
    self.shopRewardAnimTimerStarted = true

    self:playShopRewardAnimWithDelay(self:getShopRewardAnimDelay())
end

function ShopRewardStoreView:shouldWaitStoreGuideLineAnim()
    local manager = _G.amfBean("ShopRewardManager")
    return manager and manager.shouldWaitStoreGuideLineAnim and manager:shouldWaitStoreGuideLineAnim()
end

function ShopRewardStoreView:setWaitingStoreGuideLineAnim(isWaiting)
    local manager = _G.amfBean("ShopRewardManager")
    if not manager or not manager.setWaitingStoreGuideLineAnim then return end

    manager:setWaitingStoreGuideLineAnim(isWaiting)
end

function ShopRewardStoreView:getShopRewardAnimDelay()
    return 0.5 + self:getShopRewardDefaultAnimDelay()
end

function ShopRewardStoreView:getShopRewardGuideAnimDelay()
    local index = tonumber(self.storeGiftIndex) or 1
    return math.max(index - 1, 0) * GUIDE_STEP_DURATION
end

function ShopRewardStoreView:getShopRewardDefaultAnimDelay()
    local index = tonumber(self.storeGiftIndex) or 1
    return math.max(index - 1, 0) * DEFAULT_STEP_DURATION
end

function ShopRewardStoreView:replaceStoreTextWithShopRewardPriceNode()
    if self.isDisposed then return end
    if self.shopRewardPriceNode then return end
    local layout = self.layout
    if not layout or not layout.storeNode then return end

    local uiData = require "amf.feature.localactivity.shopreward.view.uisource.ShopRewardPriceNode_UI"
    local priceNode = UIBuilder:buildUI(uiData, self)
    priceNode:setPositionXY(0, -211)
    layout.storeNode:addChild(priceNode)

    self.shopRewardPriceNode = priceNode

    -- 节点
    self.priceText:setString(tostring(self:getActivityPackageGoldNum()))

end

function ShopRewardStoreView:playShopRewardPriceAnim()
    if self.isDisposed then return end

    local spine = UICreateUtil:createSpine(Res.Spine.ZHAN)
    local spine2 = UICreateUtil:createSpine(Res.Spine.ZHAN)
    self.shopRewardPriceNode:addChildAt(spine, 0)
    spine:playOnce("b")
    self.shopRewardPriceNode:addChildAt(spine2, 3)
    spine2:playOnce("a", function()
        setTimeOut(function()
        if self.isDisposed then return end
            if not isSafeCocosObj(spine2) then return end
            spine2:playLoop("c")
        end, 3)
    end)

    spine:setPositionXY(147, 65)
    spine2:setPositionXY(147, 65)

    local cfg = {
        price = {
            init = {
                opacity = 0,
                scale = 1
            },
            actions ={
                {delay = 18/30, time = 3/30, scale = 1.25, opacity = 255},
                {delay = 5/30, time = 2/30, scale = 0.98},
                {time = 5/30, scale = 1}
            }
        },
        timeNode = {
            init = {
                opacity = 0,
            },
            actions = {
                {delay = 29/30, time = 6/30, opacity = 255}
            }
        }
    }
    ActionCreator.new(cfg, function(key)
        if key == "price" then
            return self.priceText
        elseif key == "timeNode" then
            return self.timeNode
        end
    end):execute()
end

function ShopRewardStoreView:getActivityPackageGoldNum()
    local packageId = self.giftData and self.giftData.getGoodsId and self.giftData:getGoodsId()
    if not packageId then return 0 end

    local manager = _G.amfBean("ShopRewardManager")
    return manager and manager:getPackageGoldNum(packageId) or 0
end

function ShopRewardStoreView:getOriginPackageGoldNum()
    local packageId = self.giftData and self.giftData.getGoodsId and self.giftData:getGoodsId()
    if not packageId then return 0 end

    local manager = _G.amfBean("ShopRewardManager")
    if not manager then return 0 end

    local originPackageId = manager:getOriginPackageIdByActivityPackageId(packageId)
    if not originPackageId then return 0 end

    return manager:getPackageGoldNum(originPackageId) or 0
end

function ShopRewardStoreView:updateGoldIconNum()
    if not self.layout or not self.layout.operateAllPropItem then return end

    local goldNum = self:getOriginPackageGoldNum()
    self.layout:operateAllPropItem(function(propItem)
        if propItem.itemId ~= AMFPropId.GOLD then return end

        propItem.num = goldNum
        if propItem.setGoldLabel then
            propItem:setGoldLabel(goldNum)
        elseif propItem.goldNumText then
            propItem.goldNumText:setString(tostring(goldNum))
        elseif propItem.goldLabel then
            propItem.goldLabel:setString(tostring(goldNum))
        elseif propItem.numWidget then
            propItem.numWidget:setString(tostring(goldNum))
        end
    end, true)
end

function ShopRewardStoreView:playOriginGoldAnim()
    if not self.layout or not self.layout.operateAllPropItem then
        return
    end

    self.layout:operateAllPropItem(function(propItem)
        if propItem.itemId ~= AMFPropId.GOLD then return end

        local bg = propItem.getGoldNumBg and propItem:getGoldNumBg()
        local label = propItem.getGoldLabel and propItem:getGoldLabel()
        local lineLayer = Layer:create()
        lineLayer:ignoreAnchorPointForPosition(false)
        local line = LayerColor:create()
        line:setColor(hex2ccc4("8A111AFF"))
        line:setOpacity(255)
        line:setContentSize(CCSizeMake(170, 4))
        line:setAnchorPoint(ccp(0, 0.5))
        lineLayer:addChild(line)
        line:setPositionXY(-line:getContentSize().width/2, -line:getContentSize().height/2)
        lineLayer:setRotation(-4)
        if label then
            local labelParent = label:getParent()
            if labelParent then
                lineLayer:setPositionXY(label:getPositionX(), label:getPositionY())
                labelParent:addChildAfter(lineLayer, label)
            else
                LayoutUtil:centerAdd(label, lineLayer)
            end
        else
            propItem:addChild(lineLayer)
        end
        ActionCreator.new(oriLabelCfg, function(key)
            if key == "goldBg" then
                return bg
            elseif key == "goldLabel" then
                return label
            elseif key == "line" then
                return line
            elseif key == "lineLayer" then
                return lineLayer
            end
        end):execute()
        return true
    end, true)
end

function ShopRewardStoreView:updateByTime(remainTime)
    if remainTime < 0 then return end
    if not self.timeText then return end

    local ret = TimeUtil:timeFormatVer1({
        endTimeInSec = TimeKit:timeInSec() + remainTime,
    })
    self.timeText:setString(ret.retString)
end

function ShopRewardStoreView:initTimeLimit()
    local endTime = self.giftData:getEndTime()
    if endTime and endTime > 0 then
        local remain = endTime - TimeKit:timeInSec()
        if remain > 0 then
            self._tickId = TimerUtil.addAlarm(function()
                if self.isDisposed then
                    self:removeTimeLimitTimer()
                    return
                end
                remain = endTime - TimeKit:timeInSec()
                self:updateByTime(remain)
                if remain <= 0 then
                    self:removeTimeLimitTimer()
                    self:onCountDownEnd()
                end
            end, 1, 0)
            self:updateByTime(remain)
        else
            self:updateByTime(0)
            self:onCountDownEnd()
        end
    end
end

function ShopRewardStoreView:removeTimeLimitTimer()
    if self._tickId then
        TimerUtil.removeAlarm(self._tickId)
        self._tickId = nil
    end
end

function ShopRewardStoreView:dispose()
    self:removeTimeLimitTimer()
    UICreateUtil:unloadPlist(Res.Plist.NUMFRAME)
    UICreateUtil:unloadSpineRes(Res.Spine.ZHAN)
    self:unregisterGuideLineAnimEvent()
    StoreGoodsGiftView.dispose(self)
end

return ShopRewardStoreView
