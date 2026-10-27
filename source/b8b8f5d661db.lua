local ProcessGiftPanel =
    class("LayeredTileMatchProcessGiftPanel", UeAMFBasePanel)
require "amf.middleware.ui.kit.component.AMFCompHelper"
local PanelNodeColorConfig =
    require "amf.middleware.ui.kit.commonpanel.utils.PanelNodeColorConfig"

local COIN_ITEM_ID = 14
local MAX_EXTRA_REWARD_KINDS = 4
local PANEL_TITLE = "超值购买"
local PANEL_SUB_TITLE = "超值特惠为你助力守护之旅~"

local function getDCPlug()
    local manager = _G.amfBean("LayeredTileMatchManager")
    return manager
        and manager._getPlug
        and manager:_getPlug("DC")
end

local GiftPosCfg = {
    [1] = {
        ccp(216, 150),
    },
    [2] = {
        ccp(206, 150),
        ccp(358, 150),
    },
    [3] = {
        ccp(131, 150),
        ccp(283, 150),
        ccp(435, 150),
    },
    [4] = {
        ccp(64, 150),
        ccp(216, 150),
        ccp(349, 150),
        ccp(483, 150),
    },
}
local NoCoinGiftPosCfg = {
    [1] = {
        ccp(284, 150),
    },
    [2] = {
        ccp(208, 150),
        ccp(360, 150),
    },
    [3] = {
        ccp(132, 150),
        ccp(284, 150),
        ccp(436, 150),
    },
    [4] = {
        ccp(56, 150),
        ccp(208, 150),
        ccp(360, 150),
        ccp(512, 150),
    },
}
local GIFT_ROOT_POSITION = ccp(76.222, 559)

function ProcessGiftPanel:getUIInfo()
    return "amf.feature.localactivity.mergeevolution.view.uisource.ProcessGiftPanel_UI"
end

function ProcessGiftPanel:initData(delegate)
    self.goodsId = delegate.goodsId
    self.goodsObj = GoodsManager:getGoods(self.goodsId)
    self.buyHandler = delegate.buyHandler
    self.panelId = UICreateUtil:getPanelId(
        "LayeredTileMatchProcessGiftPanel"
    )
    self.items = table.clone(self.goodsObj:getItems() or {})
    self.displayItems = {}

    local displayedItemIds = {}
    for _, item in ipairs(self.items) do
        if item.itemId == COIN_ITEM_ID then
            self.coinNum = item.num
        elseif not displayedItemIds[item.itemId]
            and #self.displayItems < MAX_EXTRA_REWARD_KINDS then
            displayedItemIds[item.itemId] = true
            table.insert(self.displayItems, item)
        end
    end

end

function ProcessGiftPanel:dcPaymentShow()
    local dc = getDCPlug()
    if not dc or not dc.dcPaymentShow then return end
    local const = dc:getDCConst()
    dc:dcPaymentShow(
        const.Category.PaymentRmb,
        const.Source.FlowGift,
        self.panelId,
        self.goodsId,
        self.goodsObj:getPrice(),
        1,
        2
    )
end

function ProcessGiftPanel:dcPaymentClick()
    self.hasPaymentClick = true
    self.paymentAttemptResult = nil
    local dc = getDCPlug()
    if not dc or not dc.dcPaymentClick then return end
    local const = dc:getDCConst()
    dc:dcPaymentClick(
        const.Category.PaymentRmb,
        const.Source.FlowGift,
        self.panelId,
        self.goodsId,
        self.goodsObj:getPrice(),
        1,
        2
    )
end

function ProcessGiftPanel:dcPaymentResult(result)
    if result == 4 and self.hasPaymentClick then return end
    if self.paymentAttemptResult then return end
    self.paymentAttemptResult = result
    local dc = getDCPlug()
    if not dc or not dc.dcPaymentResult then return end
    local const = dc:getDCConst()
    dc:dcPaymentResult(
        const.Category.PaymentRmb,
        const.Source.FlowGift,
        self.panelId,
        self.goodsId,
        self.goodsObj:getPrice(),
        1,
        2,
        result
    )
end

function ProcessGiftPanel:setBuyText()
    if self.goodsObj:getMoneyType() == MoneyType.kGold then
        self.mainButton:setContent({
            {
                Atlas = "ui/common/common_item_icon256.plist",
                atlas = "ui/common/common_item_icon256.plist",
                frameName = "other/iconV2/icon_jinbi_01_v2",
            },
            {
                text = tostring(self.goodsObj:getPrice()),
            },
            {
                text = "购买",
            },
        })
    else
        self.mainButton:setRmbPrice(self.goodsObj:getPrice())
    end

    local discount = tonumber(self.goodsObj:getDiscount())
    if discount and discount < 10 then
        local discountOwner = Node:create()
        local buttonSize = self.mainButton:getContentSize()
        if buttonSize.width <= 0 or buttonSize.height <= 0 then
            buttonSize = CCSizeMake(300, 100)
        end
        discountOwner:setContentSize(buttonSize)
        discountOwner:setPositionXY(
            -buttonSize.width / 2,
            -buttonSize.height / 2
        )
        self.mainButton:addChild(discountOwner, 100)
        AMFCompHelper:createDiscountPlug(discountOwner, discount)
    end
end

function ProcessGiftPanel:initButtons()
    self.closeBtn:setTouchHandler(function()
        self:dcPaymentResult(4)
        self:sendCommand("close")
    end)
    self.mainButton:setTouchHandler(function()
        if self.isDisposed or self.buying then return end
        self.buying = true
        self:dcPaymentClick()
        safeRunCall(
            self.buyHandler,
            function()
                self:dcPaymentResult(1)
                if self.isDisposed then return end
                self:sendCommand("close")
            end,
            function()
                self:dcPaymentResult(2)
                self.buying = false
            end,
            function()
                self:dcPaymentResult(3)
                self.buying = false
            end
        )
    end)
    self:setBuyText()
end

function ProcessGiftPanel:initRewards()
    self.title:setString(PANEL_TITLE)
    self.titleBg:setString(PANEL_TITLE)
    if self.mainText then
        self.mainText:setString(PANEL_SUB_TITLE)
    end
    local coinNum = tonumber(self.coinNum) or 0
    local hasCoin = coinNum > 0
    if self.coin then
        self.coin:setVisible(hasCoin)
    end
    if hasCoin then
        self.coinText:setString(tostring(coinNum))
    end

    self.rightRoot:setPositionXY(
        GIFT_ROOT_POSITION.x,
        GIFT_ROOT_POSITION.y
    )
    local positionConfig = hasCoin
        and GiftPosCfg
        or NoCoinGiftPosCfg
    local positions = positionConfig[#self.displayItems] or {}
    for index, item in ipairs(self.displayItems) do
        item.needNum = true
        local icon = WidgetManager:createWidgetObj("UEPropIcon")
        icon:setItem(item)
        icon:setScale(0.5)
        self.rightRoot:addChild(icon)
        local position = positions[index]
        if position then
            icon:setPositionXY(position.x, position.y)
        end
    end
end

function ProcessGiftPanel:initSkinColor()
    PanelNodeColorConfig:setPanelColorMode("orange", {
        image = self.bg_gradient_green,
        firstTitle = self.titleBg,
        secondTitle = self.title,
    })
end

function ProcessGiftPanel:init(delegate)
    UeAMFBasePanel.init(self, delegate)
    self:initData(delegate)
    self:initButtons()
    self:initRewards()
    self:initSkinColor()
    self:dcPaymentShow()
end

function ProcessGiftPanel:recycle()
    self:dcPaymentResult(4)
    UeAMFBasePanel.recycle(self)
end

return ProcessGiftPanel
