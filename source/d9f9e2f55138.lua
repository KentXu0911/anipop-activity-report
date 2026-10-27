local AddStepGiftView = force_require "amf.feature.giftpackage.common.view.addstep.AddStepGiftView"

local LongTailGiftView = class("LongTailGiftView", AddStepGiftView)

function LongTailGiftView:create(delegate, giftData)
    local panel = self.new()
    panel:init(delegate, giftData)
    return panel
end

function LongTailGiftView:initData(delegate, giftData)
    AddStepGiftView.initData(self, delegate, giftData)

    self.endTime = giftData:getEndTime()

    local goldNum = 0
    if giftData:getItems()[1] then
        goldNum = giftData:getItems()[1].num
    end
    self.getGoldNum = goldNum
    self.rewards = table.clone(giftData:getItems())

    self.dcFeature = 'long_tail'
    self.dcSource = 'store_promotion_end_game'
end

function LongTailGiftView:initCustomUI()
    local uiData =  require 'amf.feature.localactivity.addfivestepupgrade.gift.AddFiveGiftPanel_UI'
    local node = UIBuilder.new(uiData):buildUIWithData(self)
    self.ui:addChild(node)
    node:setPositionXY(22, 295)

    local price = self.giftData:getPrice()
    local discount = self.giftData:getDiscount()

    self.buyBtn:setString({ '￥'..price })

    if discount and discount > 0 then
        self.buyBtn:setDiscount(tostring(discount))
    end

    self.desc:setString('超值步数补给')
    self.goldNum:setString(''..self.getGoldNum)

    self.buyBtn:setCallBack(function()
        self:onBuyBtn()
    end)
end

function LongTailGiftView:onBuyBtn()
    if self.isDisposed then return end

    local function onSuccess()
        if self.isDisposed then return end

        -- 老礼包系统用的参数，新的不必管了
        --[[
        local mgr = _G.amfBean("AddFiveUpgradeManager")

        local saveParam = mgr:getSaveGiftParam()
        saveParam.bHadBuyGift = true
        mgr:saveGiftParam(saveParam)

        --刷新购买时间数据
        -- 老系统数据作废，不需再更新CD
        UBFAddFiveUpgradeDataUtil:setBuyGiftSucess()
        --]]

        self:onBuySuccess()
        self:onDcPayResult(1)
    end

    local function onFail(evt)
        self:onBuyFail()
        self:onDcPayResult(2)
    end

    local function onCancel(evt)
        self:onBuyCancel()
        self:onDcPayResult(3)
    end

    self:onBuyClick()
    self:onDcPayClick()
    self:unifiedBuy(onSuccess, onFail, onCancel)
end

function LongTailGiftView:getFlyFromPos()
    if self.isDisposed then return end
    local p = self.goldNum and self.goldNum:getPositionInWorldSpace()
    return p or ccp(640, 150)
end

return LongTailGiftView