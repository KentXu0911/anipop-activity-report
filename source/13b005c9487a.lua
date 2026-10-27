---auto create by ui_editor
---@class WaterfallMarketingPanel : UeAMFBasePanel
---field start
---@field btnConfirm UEButton
---field end
local WaterfallMarketingPanel = class("WaterfallMarketingPanel", UeAMFBasePanel)
---auto create end don't delete
function WaterfallMarketingPanel:getUIInfo( )
    return "amf.feature.localactivity.waterfallgift.view.uisource.WaterfallMarketingPanel_UI"
end

function WaterfallMarketingPanel:initButtons(  )
    self.closeBtn:setTouchHandler(function()
		self:sendCommand("onCloseBtnTapped")
	end)

	self.btnConfirm:setTouchHandler(function() self:sendCommand("onConfirmTapped") end)
    self.btnConfirm:setContent({ text = "去看看" })
end

function WaterfallMarketingPanel:init(delegate)
    UeAMFBasePanel.init(self, delegate)
    self:initButtons()

	local str = "支付优惠提醒"
    self.lblTitle:setString(str)
    self.lblTitleBg:setString(str)
end

function WaterfallMarketingPanel:updateByDyOfferInfo(dyOfferInfo)
    local discountText
    if dyOfferInfo.discount then
        discountText = dyOfferInfo.discount
        if dyOfferInfo.finalPrice and dyOfferInfo.finalPrice == 0.01 then
            self.lblSubTitle:setString("抖音支付1分购，立减")
        else
            self.lblSubTitle:setString("抖音支付，立减")
        end
        self.lblDiscount:setString("立减")

        local limitTipText = TTFLabel:createAnimalYH("限敢买敢送活动", 30)
        self.lblSubTitle:getParent():addChild(limitTipText)
        limitTipText:setTextColor(hex2ccc4("B58751FF"))
        limitTipText:setAnchorPoint(ccp(0.5, 0.5))
        limitTipText:setPositionXY(180, -32)

        self.top_bg_yellow_dark_1:setPreferredSize(CCSizeMake(564, 403))
        LayoutUtil:move(self.top_bg_yellow_dark_1, 0, -40)
        LayoutUtil:move(self.node_1133, 0, -20)
    else
        discountText = "20"
        self.lblSubTitle:setString("使用抖音支付，最高立减")
        self.lblDiscount:setString("最高立减")
    end
    local discountLabel1 = TTFLabel:createAnimalYH(tostring(discountText), 36)
    local discountLabel2 = TTFLabel:createAnimalYH(tostring(discountText), 36)
    local discountLabel3 = TTFLabel:createAnimalYH("元", 30)
    local discountLabel4 = TTFLabel:createAnimalYH("元", 30)
    discountLabel1:setTextColor(ccc4(157, 77, 18, 255))
    discountLabel3:setTextColor(ccc4(157, 77, 18, 255))
    discountLabel2:setTextColor(ccc4(194, 77, 0, 255))
    discountLabel4:setTextColor(ccc4(194, 77, 0, 255))
    discountLabel1:setAnchorPoint(ccp(0, 0))
    discountLabel2:setAnchorPoint(ccp(0, 0))
    discountLabel3:setAnchorPoint(ccp(0, 0))
    discountLabel4:setAnchorPoint(ccp(0, 0))

    self.lblSubTitle:addChild(discountLabel1)
    self.lblSubTitle:addChild(discountLabel3)
    self.lblDiscount:addChild(discountLabel2)
    self.lblDiscount:addChild(discountLabel4)

    local allWidth = self.lblSubTitle:getContentSize().width
    discountLabel1:setPositionXY(allWidth + 1, -2)
    allWidth = allWidth +  discountLabel1:getContentSize().width
    discountLabel3:setPositionXY(allWidth + 2, 0)

    local allWidth2 = self.lblDiscount:getContentSize().width
    discountLabel2:setPositionXY(allWidth2 + 1, -2)
    allWidth2 = allWidth2 +  discountLabel2:getContentSize().width
    discountLabel4:setPositionXY(allWidth2 + 2, 0)

    LayoutUtil:move(self.lblSubTitle, -(discountLabel1:getContentSize().width + discountLabel3:getContentSize().width + 2) / 2)
    LayoutUtil:move(self.lblDiscount, -(discountLabel2:getContentSize().width + discountLabel4:getContentSize().width + 2) / 2)
end

return WaterfallMarketingPanel
