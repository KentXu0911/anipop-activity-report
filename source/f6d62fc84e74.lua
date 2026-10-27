local Meta = require "amf.feature.localactivity.merge.config.MergeConfig"
local MBuyLogic = require'amf.feature.localactivity.merge.gift.MBuyLogic'
local GiftMeta = require 'amf.feature.localactivity.merge.gift.GiftMeta'
local RewardFlyHelper = require 'amf.feature.localactivity.processgiftautopopup.RewardFlyHelper.lua'
local BoardMeta = require 'amf.feature.localactivity.merge.config.BoardMeta'

local MGift = class("MGift", Layer)

local Text = {
    NORMAL = "<outline color=#d98545 width=2><color=#fff9df>每日限购1次</color>",
    LIMIT = "<outline color=#d98545 width=2><color=#fff9df>今日已达上限</color>"
}
MGift.Text = Text

function MGift:create(delegate)
    local ret = MGift.new()
    ret:init(delegate)
    return ret
end

function MGift:ctor()
    local uiData = require 'amf.feature.localactivity.merge.view.uisource.Component_UI'
    self.builder = UIBuilder.new( uiData )
    self.bNormal = true
    self.mgr = _G.amfBean("MergeManager")
end

function MGift:init(delegate)
    Layer.initLayer(self)
    self:ignoreAnchorPointForPosition(false)
    self.delegate = delegate
    self.goodsId = self.delegate.goodsId
    self.bLimit = self.delegate.bLimit
    self.buyTime = self.delegate.buyTime
    self.from = self.delegate.from or ""
    self.targetId = self.delegate.targetId
    self.buySuccessFunc = self.delegate.buySuccessFunc
    self.buyPreFunc = self.delegate.buyPreFunc
    self.customFly = self.delegate.customFly
    self.goodsObj = GoodsManager:getGoods(self.goodsId)
    self.hasGoldReward, self.goldReward = self:hasGoldItem()
    self.goodsName = ""
    if self.goodsObj then
        self.goodsName = self.goodsObj:getName()
    end
    self.showId = self.delegate.showId
    self.showRedFlag = self.delegate.showRedFlag

    local isUserClick = true
    if self.delegate.isUserClick ~= nil then
        isUserClick = self.delegate.isUserClick
    end
    self.buyLogic = MBuyLogic:create({
        actId = self.mgr.ACT_ID,
        sourceExt = self.from,
        isUserClick = isUserClick,
    })

    self.tracer = self.buyLogic:createPayTracer(self.goodsId, self.from, nil, self.showId)

    self:initGiftNode()
    self:initBuyButton()
    self:refreshData()
    self:refresh()
end

function MGift:initGiftNode()
    self.giftNode = self.builder:createChild( "giftNode" )
    self:addChild(self.giftNode)
    self:setName("MGift")
    self:makeContentSizeContainChildren()
    self.giftNode:setPositionXY(620, 285/2)

    --超值标签
    if self.giftNode.mbMap.redFlag and (not self.showRedFlag) then
        self.giftNode.mbMap.redFlag:setVisible(false)
    end

    local itemData = {}
    for k, v in pairs(self.goodsObj:getItems()) do
        if v.itemId ~= UPropId.GOLD then
            table.insert(itemData, {
                itemId = v.itemId,
                num = v.num,
                hideNum = true,
            })
        else
            local GiftLayout = require "amf.feature.store.view.gift.layout.GiftLayout"
            local icon = GiftLayout:createGoldIcon(v.num)
            icon:showGoldAni()
            icon:setScale(0.9)
            icon.reward = {itemId = UPropId.GOLD, num = v.num}
            -- local clippingNode = SimpleClippingNode:create(CCSizeMake(170, 136))
            -- clippingNode:setAnchorPoint(ccp(0.5, 0.5))
            -- icon:setPositionXY(85, 68)
            -- clippingNode:addChild(icon)
            if self.bNormal then 
            else
                icon:setPositionY(-10)
            end
            self.goldIcon = icon
            self.giftNode.mbMap.goldNode:addChild(icon)
            -- self.giftNode.mbMap.goldNode:addChild(clippingNode)
            self:addSpineAnimations()
        end
    end
    self.items = {}
    local totalNum = #itemData
    for k, v in pairs(itemData) do
        local srcScale = totalNum > 2 and 0.6 or 0.8
        local scale = BoardMeta:fixSpecialItemScale( v.itemId, srcScale )

        local item = self:createItem(v, scale, totalNum <= 2)
        self.giftNode.mbMap.giftBg2:addChild(item)
        self:setItemPos(item, k, totalNum)
        table.insert(self.items, item)
    end
end

function MGift:setItemPos(item, i, count)
    local size = self.giftNode.mbMap.giftBg2:getPreferredSize()
    local xOff = 0
    local yOff = 0
    if i == 1 or  i == 3 then
        xOff = -91
    elseif i == 2 or i == 4 then
        xOff = 45
    end
    if count <= 2 then
        yOff = 0
    else
        if i == 1 or  i == 2 then
            yOff = 36
        elseif i == 3 or i == 4 then
            yOff = -38
        end
    end

    if isSafeCocosObj(item.mbMap.itemNum) then
        local deltaY = 0
        local deltaX = 0
        if count > 2 then
            deltaY = 5
            deltaX = -3
        else
            deltaY = -5
        end
        UICreateUtil:move(item.mbMap.itemNum, deltaX, deltaY)
    end
    item:setPositionXY(size.width/2 + xOff, size.height/2 + yOff)
end

function MGift:createItem(reward, scale, bTwoItem)
    local itemNode = self.builder:createChild("itemNode")
    itemNode.reward = reward
    local icon = self.mgr:commonCreateIcon(reward, false, scale, nil, true)
    -- icon:setScale(scale)
    LayoutUtil:centerAdd(itemNode, icon)
    local itemNum = itemNode.mbMap.itemNum
    itemNum:removeFromParentAndCleanup(false)
    itemNode:addChild(itemNum)
    itemNode.mbMap.itemNum:setString(YH_REF_MAP.x .. reward.num)
    if _G.amfBean("PropManager"):isMergableProp(reward.itemId) or reward.itemId == Meta.DoubleBuffId then
        itemNode.mbMap.itemNum:setVisible(false)
    end
    -- 验货要求体力数量朝左挪
    if bTwoItem and reward.itemId == Meta.CollectionId then
        UICreateUtil:move(itemNode.mbMap.itemNum, -5, 0)
    end
    return itemNode
end

function MGift:refreshData()
    if self.isDisposed then return end
    self.hasReachLimit = self.bLimit and self.buyTime > 0
end

function MGift:refresh()
    if self.isDisposed then return end
    self.giftNode.mbMap.textLabel1:setString(self.goodsName)

    if self.hasReachLimit then
        self.buyButton:setGray()
        self.buyButton:setString('已购完')
        self.buyButton:hideDiscount()
        self.buyButton:hideOriginPrice()
        self.buyButton:setCallBack(function()
            CommonTip:showTip('礼包已售罄！')
        end )
        self.giftNode.mbMap.limitLabel:setString(self.Text.LIMIT)
    elseif self.bLimit then
        self.giftNode.mbMap.limitLabel:setString(self.Text.NORMAL)
    else
        self.giftNode.mbMap.limitLabel:setVisible(false)
        self.giftNode.mbMap.limitBg:setVisible(false)
        self.giftNode.mbMap.textLabel1:setPositionY(54)
    end
end

function MGift:hasGoldItem()
    for k, v in pairs(self.goodsObj:getItems()) do
        if v.itemId == 14 then
            return true, v
        end
    end
    return false, 0
end

function MGift:flyRewards()
    if self.isDisposed then return end
    local srcWorldPos = self.goldIcon:convertToWorldSpace(ccp(0, 100))
    RewardFlyHelper:rewardFlyFunc(false, self.goldReward, srcWorldPos)

    for k, v in pairs(self.items) do
        local reward = table.clone(v.reward)
        local srcWorldPos = v:convertToWorldSpace(ccp(0, 0))
        if self.customFly then
            self.customFly(reward, srcWorldPos)
        end
    end
end

function MGift:onButton()
    if self.isDisposed then return end
    if self:isLocked() then return end

    self.tracer:click()
    local rewards = {}
    local buyPowerNum = 0
    for _, v in pairs(self.goodsObj:getItems()) do
        if v.itemId == Meta.CollectionId then
            buyPowerNum = v.num
        end
        local r = {itemId = v.itemId, num = v.num}
        rewards[#rewards + 1] = r
    end

    local function successCallback(bBuy)
        if bBuy then
            self:lock()
            local source = self.from
            local goodsId = self.goodsId
            local sucCall = function(...)
                local mgr = _G.amfBean("MergeManager")
                mgr:getData():addBuyGoodsCount(goodsId, 1)

                if self.isDisposed then return end
                self:unlock()
                self.buyTime = self.buyTime + 1
                self:refreshData()
                self:refresh()
                self:flyRewards()
                safeRunCall(self.buySuccessFunc, self.goodsId)
            end

            local failCall = function(...)
                if self.isDisposed then return end
                self:unlock()
            end

            local cancelCall = function(...)
                if self.isDisposed then return end
                self:unlock()
            end

            self.buyLogic:requestBuyWithTracer(sucCall, failCall, cancelCall, self.tracer, self.targetId)
        end
    end

    local totalPower = self.mgr:getData():getPowerTotal()
    if buyPowerNum > 0 and totalPower + buyPowerNum > Meta.MaxPowerConfig then
        self.mgr:openSecondConfirmPanel(successCallback, totalPower, buyPowerNum)
    else
        successCallback(true)
    end
end

function MGift:lock()
    if self.isDisposed then return end
    self.bLock = true
end

function MGift:unlock()
    if self.isDisposed then return end
    self.bLock = false
end

function MGift:isLocked()
    if self.isDisposed then return end
    return self.bLock
end

function MGift:initBuyButton()
    self.buyButton = self.mgr:createBuyButton({
        goodsId = self.goodsId,
        buyNum = 1,
        scaleMode = UIButtonConfig.BtnScales.k60,
        touchFunc = function()
            if self.buyPreFunc then
                self.buyPreFunc(function()
                    self:onButton()
                end)
            else
                self:onButton()
            end
        end
    })
    LayoutUtil:replaceBy(self.giftNode.mbMap.buyBtn, self.buyButton)
end

function MGift:addSpineAnimations()
    if not self.goldIcon then return end

    local topAni = UICreateUtil:createSpine('amf/activity/merge/spine/saoguang_di.skel')
    if topAni then
        self.giftNode:addChild(topAni)
        topAni:setScale(0.9)
        if self.bNormal then
            topAni:setPositionXY(310, 145)
        else
            topAni:setPositionXY(320, -118)
        end
        local array = CCArray:create()
        array:addObject(CCCallFunc:create(function()
            if topAni.isDisposed then return end
            topAni:playByName("idle")
        end))
        array:addObject(CCDelayTime:create(5))
        local sequence = CCSequence:create(array)
        topAni:runAction(CCRepeatForever:create(sequence))
    end
end

function MGift:isSpecialItem(itemId)
    --TODO@孙文   这里要写一下特殊奖励的飞行动画
end

function MGift:dispose()
    self.tracer:close()
    Layer.dispose(self)
end

return MGift
