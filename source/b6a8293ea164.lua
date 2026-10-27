local Meta = require "amf.feature.localactivity.merge.config.MergeConfig"
local MBuyLogic = require 'amf.feature.localactivity.merge.gift.MBuyLogic'
local RewardFlyHelper = require 'amf.feature.localactivity.processgiftautopopup.RewardFlyHelper.lua'
local AsyncRunner = require "amf.script.sugar.AsyncRunner"
local GiftPanel = class("GiftPanel", AMFBasePanel)

local PanelType = {
    STAGE_4_POP = 1,
    MAIN_POP = 2,
    TUJIAN_HALF = 3,
    MAIN_POP2 = 4,
}

local GiftLayout = {
    HEIGHT = 199,
    WIDTH = 518,
    [1] = { {x = 518 / 2, y = 99.5} },
    [2] = {
        {x = 518 / 2-100, y = 99.5}, {x = 518 / 2 + 100, y = 99.5}
    },
    [4] = {
        {x = 280, y = 139.5}, {x = 384, y = 139.5},
        {x = 280, y = 59.5}, {x = 384, y = 59.5},
    },
}

local GiftLayoutWithGold = {
    HEIGHT = 199,
    WIDTH = 518,
    [1] = { {x = 325, y = 99.5} },
    [2] = {
        {x = 280, y = 99.5}, {x = 384, y = 99.5}
    },
    [4] = {
        {x = 280, y = 139.5}, {x = 384, y = 139.5},
        {x = 280, y = 59.5}, {x = 384, y = 59.5},
    },
}

function GiftPanel:ctor()
end

function GiftPanel:getUIInfo()
    local path = "amf.feature.localactivity.merge.gift.GiftPanel_UI"
    local skipList = {"itemNode"}

    return path, skipList
end

function GiftPanel:getAssetsList()
    return {
		"amf/store/layout/GiftGoldIcon.plist",
		"amf/store/spine/light_down_new.skel",
		"amf/store/spine/light_up.skel",
        "amf/activity/merge/materials/mergeItems.plist",
        "amf/activity/merge/materials/flyIcon.png",
	}
end

function GiftPanel:initUI(panelType, goodsId, title, desc, goodsMetaItems, buyPreFunc, noCheckBox, goodsObj)
    self.panelType = panelType
    self.goodsId = goodsId
    self.title = title
    self.desc = desc
    self.goodsMetaItems = goodsMetaItems
    self.buyPreFunc = buyPreFunc
    self.noCheckBox = noCheckBox
    self.goodsObj = goodsObj

    self:initTitle()
    self:initDesc()
    self:initGift()
    self:initButton()
end

function GiftPanel:initTitle()
    local str = self.title

    self.title1:setString(str)
    self.title2:setString(str)
end

function GiftPanel:initDesc()
    local str = self.desc
    self.strDesc:setString(str)
end

function GiftPanel:initGift()

    local goodsMetaItems = self.goodsMetaItems

    if self.panelType == PanelType.STAGE_4_POP or self.panelType == PanelType.TUJIAN_HALF then
        local itemData = {}
        local hasGold = false
        for _, v in pairs(goodsMetaItems) do
            if v.itemId ~= UPropId.GOLD then
                table.insert(itemData, {
                    itemId = v.itemId,
                    num = v.num,
                    hideNum = true,
                })
            else
                local StoreGiftLayout = require "amf.feature.store.view.gift.layout.GiftLayout"
                local icon = StoreGiftLayout:createGoldIcon(v.num)
                icon:showGoldAni()
                icon:setScale(0.9)
                icon.reward = {itemId = UPropId.GOLD, num = v.num}
                self.goldIcon = icon
                self.goldNode:addChild(icon)
                hasGold = true
            end
        end
        self:createItemLayout(itemData, hasGold and GiftLayoutWithGold or GiftLayout)
    else
        -- 已经支持多种了。 看GiftLayout 这个的配置 124个的展示
        local rewardNum = #goodsMetaItems
        local giftLayoutConfig = GiftLayout[rewardNum] or GiftLayout[1]

        for i,v in ipairs(goodsMetaItems) do
            local reward = table.clone(goodsMetaItems[i])
            reward = {itemId = reward.itemId, num = reward.num}
            if reward.itemId == Meta.DoubleBuffId then
                reward.needNum = false
            else
                reward.needNum = true
            end

            local posconfig = giftLayoutConfig[i] or giftLayoutConfig[1]
            local icon
            self:sendCommand("createIcon", reward, function(ret) icon = ret end)
            icon:setPositionXY(posconfig.x, posconfig.y)

            if reward.needNum then
                local numWidget, diffX, diffY = AMFCompHelper:createPropNum(reward)
                if numWidget then
                    icon:addChild(numWidget)
                    local sz = icon:getContentSize()
                    numWidget:setPositionXY(sz.width+diffX,diffY)
                    icon.numWidget = numWidget
                end
            end
            self.grpGifts:addChild(icon)
        end

        
    end
end

function GiftPanel:createItemLayout(itemData, layoutConfig)
    local rewardNum = #itemData
    layoutConfig = layoutConfig or GiftLayout
    local layout = layoutConfig[rewardNum] or layoutConfig[1]
    self.items = {}
    for k, v in pairs(itemData) do
        local icon = self:createItem(v, rewardNum > 2 and 0.6 or 0.8)
        icon:setPositionXY(layout[k].x, layout[k].y)
        self.grpGifts:addChild(icon)
        table.insert(self.items, icon)
    end
end

function GiftPanel:createItem(reward, scale)
    local itemNode = self.builder:createChild("itemNode")
    itemNode:setScale(scale)
    itemNode.mbMap.itemNum:setScale( 1 / scale )
    if scale == 0.8 then
        UICreateUtil:move(itemNode.mbMap.itemNum, -5, 0)
    end
    itemNode.reward = reward

    local icon
    self:sendCommand("createIcon", reward, function(ret) icon = ret end)
    LayoutUtil:centerAdd(itemNode, icon)
    itemNode.mbMap.itemNum:setString(YH_REF_MAP.x .. reward.num)
    if _G.amfBean("PropManager"):isMergableProp(reward.itemId) or reward.itemId == Meta.DoubleBuffId then
        itemNode.mbMap.itemNum:setVisible(false)
    end
    LayoutUtil:topUI(itemNode.mbMap.itemNum)
    return itemNode
end

function GiftPanel:initButton()
    self.closeBtn:setTouchHandler(function()
        if self.isDisposed then return end
        self:sendCommand("onCloseBtnTapped")
    end)

    local buyPreFunc = self.buyPreFunc
    local buttonData = {
        goodsId = self.goodsId,
        buyNum = 1,
        rmbNeedSuffix = true,
        touchFunc = function()
            if buyPreFunc then
                safeRunCall(buyPreFunc, function()
                    self:sendCommand("onButton")
                end)
            else
                self:sendCommand("onButton")
            end
        end
    }
    local button
    self:sendCommand("createBuyButton", buttonData, function(ret) button = ret end)

    UICreateUtil:replaceBy(self.buyButton, button)
    self.buyButton = button

    local noCheckBox = self.noCheckBox
    if not noCheckBox then

        local CheckBox = require "amf.middleware.ui.kit.component.CheckBox"
        local checkBoxBuilder = CheckBox.Builder.new()
        :setText('今日不再弹出')
        :setTickVisible(false)
        :setClickCallback(function(isCheck)
            if self.panelType == PanelType.MAIN_POP or self.panelType == PanelType.MAIN_POP2 then
                self:sendCommand("setIgnoredEnergyNotEnoughGiftToday", isCheck)
            else
                self:sendCommand("setIgnoredGiftToday", isCheck)
            end
            self.isChecked = isCheck
        end)
        local checkBox = checkBoxBuilder:build()

        self.ui:addChild(checkBox)
        checkBox:setPositionXY(360, -942)
        checkBox:setName("checkBox")
        self.checkBox = checkBox
    end
end

function GiftPanel:flyRewards(callback, customFlyFunc)
    if self.isDisposed then return end

    if customFlyFunc then
        local items = self.goodsObj:getItems()
        local rewardNum = #items
        local giftLayoutConfig = GiftLayout[rewardNum] or GiftLayout[1]

        for i,v in ipairs(items) do
            local flyEndCall = nil
            if i==#items then
                flyEndCall = callback
            end
            local posconfig = giftLayoutConfig[i] or giftLayoutConfig[1]
            local scrPos = self.grpGifts:convertToWorldSpace(ccp(posconfig.x, posconfig.y))
            if v.itemId == Meta.CollectionId  then
                customFlyFunc(scrPos, flyEndCall, v.itemId )
            else
                local reward = table.clone(v)
                RewardFlyHelper:rewardFlyFunc(false, reward, scrPos, nil, nil, flyEndCall)
            end
        end
    else
        local srcWorldPos = self.goldIcon:getPositionInWorldSpace()
        local reward = table.clone(self.goldIcon.reward)
        RewardFlyHelper:rewardFlyFunc(false, reward, srcWorldPos, nil, nil, callback)

        local icon
        self:sendCommand("getActIcon", function(ret) icon = ret end)

        local endWorldPos = icon and icon:getPositionInWorldSpace()
        local function createFakeIcon()
            local icon
            self:sendCommand("getFlyActIcon", function(ret) icon = ret end)
            return icon
        end
        for k, v in pairs(self.items) do
            local reward = table.clone(v.reward)
            local srcWorldPos = v:getPositionInWorldSpace()
            RewardFlyHelper:rewardFlyFunc(true, reward, srcWorldPos, endWorldPos, function()
                local icon
                self:sendCommand("createIcon", reward, function(ret) icon = ret end)
                return icon
            end, nil, CCSizeMake(30, 30), createFakeIcon)
        end
    end
end


return GiftPanel
