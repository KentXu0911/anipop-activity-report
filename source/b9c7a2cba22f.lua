---auto create by ui_editor
---@class ReturnGift2Panel : UeAMFBasePanel
---field start
---@field propIcon_1_1 UEPropIcon
---@field propIcon_2_1 UEPropIcon
---@field propIcon_3_1 UEPropIcon
---@field propIcon_4_1 UEPropIcon
---@field bigAwardIcon UEPropIcon
---@field buyBtn UEButton
---@field propIcon_1 UEPropIcon
---@field propIcon_2 UEPropIcon
---@field propIcon_3 UEPropIcon
---@field propIcon_4 UEPropIcon
---@field propIcon_5 UEPropIcon
---@field propIcon_1 UEPropIcon
---@field propIcon_2 UEPropIcon
---@field propIcon_3 UEPropIcon
---@field propIcon_4 UEPropIcon
---@field propIcon_5 UEPropIcon
---field end
local ReturnGift2Panel = class("ReturnGift2Panel",UeAMFBasePanel)
---auto create end don't delete

local Extra = require "amf.feature.localactivity.returngift.model.ReturnGiftExtra"
local Const = require "amf.feature.localactivity.returngift.config.ReturnGiftConst"
local PluginHelper = require "amf.middleware.ui.export.ueeditor.extendplugin.PluginHelper"
local ReturnGift2AwardItemNode = require "amf.feature.localactivity.returngift.view.ReturnGift2AwardItemNode"
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local ReturnGiftAssets = require "amf.feature.localactivity.returngift.util.ReturnGiftAssets"
local GiftEventCenter = require "amf.feature.giftpackage.event.GiftEventCenter"

local GOLD_ITEM_ID = 14
local GIFT_CAR_SPINE_PATH = "amf/activity/returngift/spine/gift_car_all.skel"
local GOLD_ICON_FX_SPINE_PATH = "amf/activity/returngift/spine/icon_fx.skel"
local TWO_REWARD_FIRST_OFFSET_Y = 60

local function formatOriginPrice(originPrice)
    return tostring(math.floor((tonumber(originPrice) or 0) + 0.5))
end

local function formatOriginPriceRichText(originPrice)
    local priceText = formatOriginPrice(originPrice)
    if #priceText > 3 then
        return string.format("<outline color=#813125FF width=3><shadow color=#7D2F23FF dist=0><size=30>%s<size=23>元", priceText)
    end
    return string.format("<outline color=#813125FF width=3><shadow color=#7D2F23FF dist=0>%s<size=23>元", priceText)
end

function ReturnGift2Panel:getUIInfo( )
    return "amf.feature.localactivity.returngift.view.uisource.ReturnGift2Panel_UI"
end

function ReturnGift2Panel:getAssetsList()
    return ReturnGiftAssets.getPackage2PanelAssets()
end

function ReturnGift2Panel:initData(commonGiftData, moduleDelegate)
    self.commonGiftData = commonGiftData
    self.moduleDelegate = moduleDelegate
    self.moduleExtra = moduleDelegate and moduleDelegate.moduleExtra or {}
end

function ReturnGift2Panel:initButtons(  )
    if self.closeBtn then
        self.closeBtn:setTouchHandler(function()
            self:sendCommand("close")
        end)
    end
    if self.buyBtn then
        self.buyBtn:setTouchHandler(function()
            self:sendCommand("onBuyClick")
        end)
    end
end

function ReturnGift2Panel:init(commonGiftData, moduleDelegate)
    UeAMFBasePanel.init(self, commonGiftData)
    self:initData(commonGiftData, moduleDelegate)
    self:initAwardItemNodes()
    self:initButtons(  )
    self:registerRewardingExtraUpdateEvent()
    self:refresh()
    self.discountNode:setVisible(false)
    local playAppearAnim = self:shouldPlayGiftCarAppearAnim()
    self:initGiftCarAnim(playAppearAnim, function()
        if playAppearAnim then
            self:initDiscountIcon(true)
        end
    end)
    if not playAppearAnim then
        self:initDiscountIcon(false)
    end
    self:initTestUtils()
end

function ReturnGift2Panel:initTestUtils()
    if not EnvUtil:isDevelopMode() or self.testUtils then return end
    local TestUtils = require "amf.feature.localactivity.returngift.view.TestUtils"
    self.testUtils = TestUtils.new()
    self.testUtils:showTest(self)
    if self.testUtils.testButtonCtrl and self.testUtils.testButtonCtrl.onTapped then
        self.testUtils.testButtonCtrl.onTapped()
    end
end

function ReturnGift2Panel:cleanupTestUtils()
    if not self.testUtils then return end
    self.testUtils:close()
    self.testUtils = nil
end

function ReturnGift2Panel:recycle()
    self:unregisterRewardingExtraUpdateEvent()
    self:cleanupTestUtils()
    self:cleanupBigAwardFx()
    UeAMFBasePanel.recycle(self)
end

function ReturnGift2Panel:testBuy()
    self.moduleExtra = self.moduleExtra or {}
    self.moduleExtra.status = Const.Status.REWARDING
    self.moduleExtra.state = Const.State.PACKAGE_2_REWARDING
    self.moduleExtra.packageType = Const.PackageType.PACKAGE_2
    if self.moduleDelegate then
        self.moduleDelegate.moduleExtra = self.moduleExtra
    end
    if self.commonGiftData and self.commonGiftData.addBuyCount then
        self.commonGiftData:addBuyCount()
    end
    -- CommonTip:showTip("已模拟购买，进入领奖阶段")
    self:playBuySuccessFlyToBag(function()
        self:playBuySuccessUnlockAnim()
    end)
end

function ReturnGift2Panel:testResetUnbuy()
    self.moduleExtra = self.moduleExtra or {}
    self.moduleExtra.status = Const.Status.CAN_PULL
    self.moduleExtra.state = Const.State.PACKAGE_2_BUYING
    self.moduleExtra.packageType = Const.PackageType.PACKAGE_2
    if self.moduleDelegate then
        self.moduleDelegate.moduleExtra = self.moduleExtra
    end
    if self.commonGiftData then
        self.commonGiftData.alreadyBuyTimes = 0
        if self.commonGiftData.limitRules and self.commonGiftData.limitRules._limitRules then
            for _, rule in ipairs(self.commonGiftData.limitRules._limitRules) do
                rule._alreadyBuyTimes = 0
            end
        end
    end
    CommonTip:showTip("已重置为未购买")
    self:refresh()
end

function ReturnGift2Panel:testClaimReward(index)
    index = tonumber(index) or 1
    local rewardNodes = Extra.getRewardNodes(self.moduleExtra)
    local rewardNode = rewardNodes[index]
    if not rewardNode or not rewardNode.rewards or #rewardNode.rewards == 0 then
        CommonTip:showTip("没有可领取奖励" .. tostring(index))
        return
    end

    self:playClaimRewardFlyToBag(rewardNode.rewards, index, function()
        CommonTip:showTip("已模拟领取奖励 23" .. tostring(index))
    end)
end

function ReturnGift2Panel:playBuySuccessFlyToBag(finishCallback)
    local flyItems = self:getBuySuccessFlyItems()
    self:runFlyItemsAnim(flyItems, finishCallback)
end

function ReturnGift2Panel:runFlyItemsAnim(flyItems, finishCallback)
    if not flyItems or #flyItems == 0 then
        safeRunCall(finishCallback)
        return
    end

    --小游戏飞动画特殊处理
    if EnvUtil:isMiniGame() then
        local flyNum = #flyItems
        for index, value in ipairs(flyItems) do
            setTimeOut(function()
                if self.isDisposed then return end
                local flyItem = table.clone(value)
                local flyContext = FlyItemContext.new(flyItem, ccp(360, 720))
                if index == flyNum then
                    flyContext:setFinishCallback(function()
                        safeRunCall(finishCallback)
                    end)
                end
                _G.amfTransaction(TransactionEvent.FLY_ITEMS, flyContext)
            end, (index - 1) * Const.FlyItemDealy)
        end
        return
    end

    local flyContext = FlyItemContext.new(flyItems, ccp(360, 720))
    flyContext:setFinishCallback(function()
        safeRunCall(finishCallback)
    end)
    _G.amfTransaction(TransactionEvent.FLY_ITEMS, flyContext)

end

function ReturnGift2Panel:getBuySuccessFlyItems()
    local giftData = self.commonGiftData
    if not giftData then return {} end

    local goldItem, propItems = self:splitGoodsItems(giftData:getItems() or {})
    local flyItems = {}
    if goldItem then
        table.insert(flyItems, self:createFlyItem(goldItem, self.bigAwardGoldAnim or self.bigAwardIcon, 0))
    end

    local iconList = { self.propIcon_1_1, self.propIcon_2_1, self.propIcon_3_1, self.propIcon_4_1 }
    for index, icon in ipairs(iconList) do
        local item = propItems[index]
        if item then
            table.insert(flyItems, self:createFlyItem(item, icon))
        end
    end
    return flyItems
end

function ReturnGift2Panel:createFlyItem(item, node)
    local flyItem = table.clone(item)
    flyItem.fromPos = self:getFlyNodeCenterWorldPos(node) or self:getFlyNodeCenterWorldPos(self.awardGroupNode or self.awardNode_3)
    flyItem.shandowNum = Const.FlyItemShandowNum
    -- if delay and delay > 0 then flyItem.delay = delay end
    if EnvUtil:isDevelopMode() then printx(48, "[gk] 领奖动画 createFlyItem itemid=", flyItem.itemId, "；delay=", delay) end
    return flyItem
end

function ReturnGift2Panel:getFlyNodeCenterWorldPos(node)
    if not node or not node.getGroupBounds then return nil end
    local bounds = node:getGroupBounds()
    if not bounds then return nil end
    return ccp(bounds.origin.x + bounds.size.width / 2, bounds.origin.y + bounds.size.height / 2)
end

function ReturnGift2Panel:testPassDay()
    if Extra.isRewarding(self.moduleExtra) then
        self.moduleExtra.rewardEndTs = TimeKit:timeInSec() + 1
    elseif self.commonGiftData and self.commonGiftData.setEndTime then
        self.commonGiftData:setEndTime(TimeKit:timeInSec() + 1)
    end
    self:initLeftTime()
    CommonTip:showTip("已设置1秒后跨天")
end



function ReturnGift2Panel:initAwardItemNodes()
    self.awardItemNodes = {}
    local len = self:getAwardNodeCount()
    local nodeName = len == 2 and "awardItemHighNode" or "awardItemNode"
    for index = 1, len do
        local nodeParent = self["nodeAward" .. tostring(index)]
        if nodeParent then
            local node = self.builder:createChild(nodeName)
            node:setPosition(ccp(0, 0))
            nodeParent:addChild(node)
            local itemNode = ReturnGift2AwardItemNode.new(node, self)
            local tapHandler = function()
                itemNode:onTapped(index)
            end
            -- itemNode.typeNode2:setTouchHandler(tapHandler)
            if itemNode.typeNode1 and itemNode.typeNode1.setTouchHandler then itemNode.typeNode1:setTouchHandler(tapHandler) end
            if itemNode.typeNode2 and itemNode.typeNode2.setTouchHandler then itemNode.typeNode2:setTouchHandler(tapHandler) end
            self.awardItemNodes[index] = itemNode
        end
    end
end

function ReturnGift2Panel:getAwardNodeCount()
    local count = #(Extra.getRewardNodes(self.moduleExtra) or {})
    if count == 2 then return 2 end
    return 3
end

function ReturnGift2Panel:refresh()
    self.moduleExtra = self.moduleDelegate and self.moduleDelegate.moduleExtra or self.moduleExtra or {}
    self:initLeftTime()
    self:initGoods()
    self:initRewardNodes()
end

function ReturnGift2Panel:initLeftTime()
    if not self.timeText_1 then return end

    local endTime = Extra.isRewarding(self.moduleExtra) and Extra.getRewardEndTime(self.moduleExtra) or 0
    if endTime <= 0 and self.commonGiftData then
        endTime = self.commonGiftData:getEndTime()
    end

    local leftTime = math.max(endTime - TimeKit:timeInSec(), 0)
    local plugin = PluginHelper:getPlugin(self.timeText_1, "TimeCountDown")
    if not plugin then return end

    plugin:setStopCallback(function()
        if self.isDisposed then return end
        local name = self.commonGiftData:getGoodsName()
        CommonTip:showTip(string.format(Const.Tip.EXPIRED, name))
        self:close()
    end)
    plugin:setLeftTime(leftTime)
end

function ReturnGift2Panel:mergeRewardingExtra(target, source)
    if not target or not source then return end
    local packageType = tonumber(source.packageType) or Extra.getPackageType(source)
    local status = tonumber(source.status) or 0
    local state = tonumber(source.state) or 0
    if packageType ~= Const.PackageType.PACKAGE_2
        and status ~= Const.Status.REWARDING
        and state ~= Const.State.PACKAGE_2_REWARDING then
        return
    end

    if source.rewardEndTs then target.rewardEndTs = source.rewardEndTs end
    if source.rewardNodes then target.rewardNodes = source.rewardNodes end
end

function ReturnGift2Panel:registerRewardingExtraUpdateEvent()
    if self._returnGiftRewardingExtraEvent then return end
    self._returnGiftRewardingExtraEvent = function(event)
        self:onRewardingExtraUpdate(event)
    end
    GiftEventCenter:register(GiftEvent.RETURN_GIFT_REWARDING_EXTRA_UPDATE, self._returnGiftRewardingExtraEvent)
end

function ReturnGift2Panel:unregisterRewardingExtraUpdateEvent()
    if not self._returnGiftRewardingExtraEvent then return end
    GiftEventCenter:unregister(GiftEvent.RETURN_GIFT_REWARDING_EXTRA_UPDATE, self._returnGiftRewardingExtraEvent)
    self._returnGiftRewardingExtraEvent = nil
end

function ReturnGift2Panel:onRewardingExtraUpdate(event)
    if self.isDisposed then return end
    local data = event and event:getData() or {}
    self:mergeRewardingExtra(self.moduleExtra, data.moduleExtra)
    if self.moduleDelegate then self.moduleDelegate.moduleExtra = self.moduleExtra end
    self:initLeftTime()
    self:initRewardNodes()
end

function ReturnGift2Panel:initGoods()
    local giftData = self.commonGiftData
    if not giftData then return end

    if self.buyBtn then
        local price = giftData:getPrice()
        if self.buyBtn.setRmbPrice then
            self.buyBtn:setRmbPrice(price)
        elseif self.buyBtn.setContent then
            self.buyBtn:setContent({ { text = "¥" .. tostring(price) } })
        end
    end

    local goldItem, propItems = self:splitGoodsItems(giftData:getItems() or {})
    self:initGoldItem(goldItem)
    self:initPropIconList({ self.propIcon_1_1, self.propIcon_2_1, self.propIcon_3_1, self.propIcon_4_1 }, propItems)
end

function ReturnGift2Panel:splitGoodsItems(items)
    local goldItem
    local propItems = {}
    for _, item in ipairs(items) do
        local itemId = tonumber(item.itemId or item.id)
        if itemId == GOLD_ITEM_ID then
            goldItem = item
        else
            table.insert(propItems, item)
        end
    end
    return goldItem, propItems
end

function ReturnGift2Panel:initGoldItem(item)
    if self.bigAwardNode and self.bigAwardNode.setVisible then self.bigAwardNode:setVisible(item ~= nil) end
    self:initBigAwardFx(item)
    if not item then return end

    local numText = self.numText or (self.bigAwardNode and self.bigAwardNode.numText)
    if numText and numText.setString then
        numText:setString(tostring(item.num or 0))
    end
end

function ReturnGift2Panel:initBigAwardFx(item)
    self:cleanupBigAwardFx()
    if not item or not self.bigAwardIcon or not UICreateUtil then return end

    local parent = self.bigAwardIcon:getParent()
    if not parent then return end

    self.bigAwardIcon:setVisible(false)
    local anim = UICreateUtil:createSpineManuallyRelease(GOLD_ICON_FX_SPINE_PATH)
    if not anim then return end

    anim:setPositionXY(self.bigAwardIcon:getPositionX(), self.bigAwardIcon:getPositionY())
    if anim.setScaleX and self.bigAwardIcon.getScaleX then anim:setScaleX(self.bigAwardIcon:getScaleX()) end
    if anim.setScaleY and self.bigAwardIcon.getScaleY then anim:setScaleY(self.bigAwardIcon:getScaleY()) end
    parent:addChildAt(anim, 0)
    anim:playLoop(self:getBigAwardFxAnimName(item))
    self.bigAwardGoldAnim = anim
end

function ReturnGift2Panel:cleanupBigAwardFx()
    if isSafeCocosObj(self.bigAwardGoldAnim) then
        self.bigAwardGoldAnim:removeFromParentAndCleanup(true)
    end
    self.bigAwardGoldAnim = nil
    if self.bigAwardIcon and not self.bigAwardIcon.isDisposed then
        self.bigAwardIcon:setVisible(true)
    end
end

function ReturnGift2Panel:getBigAwardFxAnimName(item)
    -- do return "lv_4" end --debug
    local goldNum = tonumber(item and (item.num or item.count)) or 0
    if goldNum >= 1000 then
        return "lv_4"
    elseif goldNum >= 200 then
        return "lv_3"
    end
    return "lv_2"
end

function ReturnGift2Panel:initRewardNodes()
    local rewarding = Extra.isRewarding(self.moduleExtra)
    if self.unpurchasedNode then self.unpurchasedNode:setVisible(not rewarding) end
    if self.subTitleImg_1 then self.subTitleImg_1:setVisible(not rewarding) end
    if self.subTitleImg_2 then self.subTitleImg_2:setVisible(rewarding) end

    local rewardNodes = Extra.getRewardNodes(self.moduleExtra)
    if #rewardNodes == 0 then
        rewardNodes = self:getDefaultRewardNodes()
    end
    self:updateRewardingAwardLayout(rewarding, #rewardNodes)
    for index, awardItemNode in ipairs(self.awardItemNodes or {}) do
        awardItemNode:refresh(rewardNodes[index], rewarding)
    end
end

function ReturnGift2Panel:updateRewardingAwardLayout(rewarding, rewardCount)
    self:cacheAwardNodeOriginPos()

    if rewardCount == 2 then
        self:setAwardNodeVisible(1, true)
        self:setAwardNodeVisible(2, true)
        self:setAwardNodeVisible(3, false)
        local pos1 = self.awardNodeOriginPos and self.awardNodeOriginPos[1]
        local pos2 = self.awardNodeOriginPos and self.awardNodeOriginPos[2]
        local pos3 = self.awardNodeOriginPos and self.awardNodeOriginPos[3]
        if pos1 and pos2 and pos3 then
            local gap = pos1.y - pos2.y
            local centerY = (pos1.y + pos3.y) / 2
            self:setAwardNodePosition(1, pos1.x, centerY + gap / 2 + TWO_REWARD_FIRST_OFFSET_Y)
            self:setAwardNodePosition(2, pos2.x, centerY - gap / 2)
        end
    else
        self:restoreAwardNodeOriginPos()
        for index = 1, 3 do
            self:setAwardNodeVisible(index, index <= rewardCount)
        end
    end

    for index = 1, 3 do
        local addImg = self["addImg_" .. tostring(index)]
        if addImg then addImg:setVisible(not rewarding and index <= rewardCount) end
    end
end

function ReturnGift2Panel:cacheAwardNodeOriginPos()
    if self.awardNodeOriginPos then return end
    self.awardNodeOriginPos = {}
    for index = 1, 3 do
        local node = self["nodeAward" .. tostring(index)]
        if node and node.getPositionX and node.getPositionY then
            self.awardNodeOriginPos[index] = { x = node:getPositionX(), y = node:getPositionY() }
        end
    end
end

function ReturnGift2Panel:restoreAwardNodeOriginPos()
    for index, pos in pairs(self.awardNodeOriginPos or {}) do
        self:setAwardNodePosition(index, pos.x, pos.y)
    end
end

function ReturnGift2Panel:setAwardNodePosition(index, x, y)
    local node = self["nodeAward" .. tostring(index)]
    if not node or not x or not y then return end
    if node.setPositionXY then
        node:setPositionXY(x, y)
    else
        node:setPosition(ccp(x, y))
    end
end

function ReturnGift2Panel:setAwardNodeVisible(index, visible)
    local node = self["nodeAward" .. tostring(index)]
    if node then node:setVisible(visible) end
end

function ReturnGift2Panel:getDefaultRewardNodes()
    return {
        { index = 0, alreadyGot = false, rewards = { { itemId = 10098, num = 10 } } },
        { index = 1, alreadyGot = false, rewards = { { itemId = 10004, num = 1 } } },
        { index = 2, alreadyGot = false, rewards = { { itemId = 10010, num = 1 } } },
    }
end

function ReturnGift2Panel:initPropIconList(iconList, items)
    items = items or {}
    self:layoutPropIconList(iconList, #items)
    for index, icon in ipairs(iconList or {}) do
        local item = items[index]
        if icon then
            icon:setVisible(item ~= nil)
            if item then
                self:setIconItem(icon, item)
            end
        end
    end
end

function ReturnGift2Panel:layoutPropIconList(iconList, itemCount)
    if not iconList or #iconList == 0 then return end
    self:cachePropIconOriginPos(iconList)

    if itemCount == 3 and #iconList >= 4 then
        local icon1 = iconList[1]
        local icon2 = iconList[2]
        local icon3 = iconList[3]
        local topPos = self.propIconOriginPos[icon1]
        local bottomPos = self.propIconOriginPos[iconList[4]]
        if icon1 and icon2 and icon3 and topPos and bottomPos then
            self:setPropIconPosition(icon1, topPos.x, topPos.y)
            self:setPropIconPosition(icon2, topPos.x, (topPos.y + bottomPos.y) / 2)
            self:setPropIconPosition(icon3, topPos.x, bottomPos.y)
            return
        end
    end

    for _, icon in ipairs(iconList) do
        local pos = icon and self.propIconOriginPos[icon]
        if pos then
            self:setPropIconPosition(icon, pos.x, pos.y)
        end
    end
end

function ReturnGift2Panel:cachePropIconOriginPos(iconList)
    self.propIconOriginPos = self.propIconOriginPos or {}
    for _, icon in ipairs(iconList or {}) do
        if icon and not self.propIconOriginPos[icon] and icon.getPositionX and icon.getPositionY then
            self.propIconOriginPos[icon] = { x = icon:getPositionX(), y = icon:getPositionY() }
        end
    end
end

function ReturnGift2Panel:setPropIconPosition(icon, x, y)
    if not icon or not x or not y then return end
    if icon.setPositionXY then
        icon:setPositionXY(x, y)
    elseif icon.setPosition then
        icon:setPosition(ccp(x, y))
    end
end

function ReturnGift2Panel:setIconItem(icon, item)
    if not icon or not icon.setItem then return end
    --不支持了，使用seTouchHandler
    -- item.callback = function()
    --     self:showItemNameTip(icon, item)
    -- end
    icon:setItem(item)
end

function ReturnGift2Panel:onRewardNodeTapped(index)
    local rewardNodes = Extra.getRewardNodes(self.moduleExtra)
    local rewardNode = rewardNodes[index]
    if not Extra.isRewarding(self.moduleExtra) then return end

    if not rewardNode or rewardNode.alreadyGot then return end
    if not rewardNode.rewards or #rewardNode.rewards == 0 then return end

    local rewardIndex = tonumber(rewardNode.index)
    if rewardIndex == nil then rewardIndex = index - 1 end
    self:sendCommand("onRewardClick", rewardIndex, index)
end

function ReturnGift2Panel:playClaimRewardFlyToBag(rewards, awardIndex, finishCallback)
    local flyItems = self:getClaimRewardFlyItems(rewards, awardIndex)
    self:runFlyItemsAnim(flyItems, finishCallback)
end

function ReturnGift2Panel:getClaimRewardFlyItems(rewards, awardIndex)
    local flyItems = {}
    local awardItemNode = self.awardItemNodes and self.awardItemNodes[awardIndex]
    for index, item in ipairs(rewards or {}) do
        local icon = awardItemNode and awardItemNode.propIcons and awardItemNode.propIcons[index]
        local flyItem = self:createFlyItem(item, icon or (awardItemNode and awardItemNode.awardGroupNode))
        table.insert(flyItems, flyItem)
    end
    return flyItems
end

function ReturnGift2Panel:showItemNameTip(target, item)
    local propManager = _G.amfBean("PropManager")
    if not propManager then return end

    local itemName = propManager:getPropName(item)
    if itemName and itemName ~= "" then
        UITip.Builder.new()
            :setTitle(itemName)
            :setTarget(target)
            :setAutoCloseTime(3)
            :build()
    end
end


--region 进入动画

function ReturnGift2Panel:initGiftCarAnim(playAppearAnim, enterAnimFinishCallback)
    local frameImg = self.frameImg
    if not frameImg or not UICreateUtil then return end

    local parent = frameImg:getParent()
    if not parent or not parent.getChildIndex or not parent.addChildAt then return end

    if isSafeCocosObj(self.giftCarBackAnim) then
        self.giftCarBackAnim:removeFromParentAndCleanup(true)
        self.giftCarBackAnim = nil
    end
    if isSafeCocosObj(self.giftCarFontAnim) then
        self.giftCarFontAnim:removeFromParentAndCleanup(true)
        self.giftCarFontAnim = nil
    end

    local index = parent:getChildIndex(frameImg)
    if playAppearAnim == nil then playAppearAnim = self:shouldPlayGiftCarAppearAnim() end
    self:prepareContentNodeEnterAnim(playAppearAnim)
    local backAnimName = playAppearAnim and "appear_back2" or "idle_back2"
    local frontAnimName = playAppearAnim and "appear_front2" or "idle_front2"
    local backAnim = self:createGiftCarAnim(backAnimName, not playAppearAnim)
    local fontAnim = self:createGiftCarAnim(frontAnimName, not playAppearAnim, function()
    end)
    setTimeOut(function ()
        if self.isDisposed then return end
        self:playContentNodeEnterAnim(enterAnimFinishCallback)
    end, 1)
    if not backAnim or not fontAnim then
        if playAppearAnim then safeRunCall(enterAnimFinishCallback) end
        return
    end

    backAnim:setPositionXY(360, -780)
    fontAnim:setPositionXY(360, -780)
    parent:addChildAt(backAnim, 0)
    parent:addChildAt(fontAnim, index + 2)

    self.giftCarBackAnim = backAnim
    self.giftCarFontAnim = fontAnim
end

---重置进入动画节点
function ReturnGift2Panel:prepareContentNodeEnterAnim(playAppearAnim)
    if not playAppearAnim or not self.contentNode then return end

    self.contentNodeOriginX = self.contentNode:getPositionX()
    self.contentNodeOriginY = self.contentNode:getPositionY()
    self.contentNode:setVisible(false)
    self.contentNode:setPositionY(-1350)

    self.unpurchasedNode:setScale(0.01)

    --加号+item
    for index, awardItemNode in ipairs(self.awardItemNodes or {}) do
        if awardItemNode and awardItemNode.prepareEnterAnim then
            awardItemNode:prepareEnterAnim()
        end

        local addImg = self["addImg_" .. tostring(index)]
        if addImg then
            addImg:setVisible(false)
            if addImg.setOpacity then addImg:setOpacity(0) end
        end
    end

    --未购买标题
    self.subTitleImg_1:setOpacity(0)
end

function ReturnGift2Panel:playContentNodeEnterAnim(finishCallback)
    if self.isDisposed or not self.contentNode then return end
    if not self.contentNodeOriginX or not self.contentNodeOriginY then
        safeRunCall(finishCallback)
        return
    end

    self.contentNode:stopAllActions()
    self.contentNode:setVisible(true)
    self.contentNode:runAction(CCSequence:createWithTwoActions(
        CCMoveTo:create(7/30, ccp(self.contentNodeOriginX, self.contentNodeOriginY+10)),
        CCMoveTo:create(5/30, ccp(self.contentNodeOriginX, self.contentNodeOriginY))
    ))
    self:playRewardItemsEnterAnim()
    self:playUnpurchasedNodeEnterAnim()
    --延迟20帧
    setTimeOut(function ()
        if self.isDisposed then return end
            safeRunCall(finishCallback)
    end, 0.67)
end


function ReturnGift2Panel:playRewardItemsEnterAnim()
    if self.isDisposed then return end
    for i = 1, #self.awardItemNodes, 1 do
        local awardItemNode = self.awardItemNodes and self.awardItemNodes[i]
        local delay = 5 + 3*(i-1)
        if awardItemNode.playEnterAnim then
            awardItemNode:playEnterAnim(delay)
        end

        local addImg = self["addImg_" .. tostring(i)]
        if addImg then
            addImg:stopAllActions()
            addImg:setVisible(true)
            if addImg.setOpacity then
                addImg:setOpacity(0)
                local action = ActionUtil:sequence({
                    CCDelayTime:create((delay)/30),
                    CCEaseSineOut:create(CCFadeIn:create(5/30)),
                })
                addImg:runAction(action)
            end
        end
    end

    local action = ActionUtil:sequence({
        CCDelayTime:create(8/30),
        CCEaseSineOut:create(CCFadeIn:create(8/30)),
    })
    self.subTitleImg_1:runAction(action)

end

function ReturnGift2Panel:playUnpurchasedNodeEnterAnim()
    local node = self.unpurchasedNode
    if self.isDisposed or not node or not node.getScaleX or not node.getScaleY then return end

    node:stopAllActions()

    local action = ActionUtil:sequence{
        CCDelayTime:create(3/30),
        CCScaleTo:create(4/30, 1.02),
        CCScaleTo:create(5/30, 1),
    }
    node:runAction(action)
end

---是否可以播放动画
function ReturnGift2Panel:shouldPlayGiftCarAppearAnim()
    -- do return false end --debug
    if Extra.isRewarding(self.moduleExtra) then return false end
    if self.moduleDelegate and self.moduleDelegate.shouldPlayGiftCarAppearAnim ~= nil then
        return self.moduleDelegate.shouldPlayGiftCarAppearAnim
    end
    if self.moduleExtra and self.moduleExtra.shouldPlayGiftCarAppearAnim ~= nil then
        return self.moduleExtra.shouldPlayGiftCarAppearAnim
    end
    return self:checkAndMarkGiftCarAppearAnim()
end

function ReturnGift2Panel:checkAndMarkGiftCarAppearAnim()
    local key = self:getGiftCarAppearAnimKey()
    if not key then return true end
    if LocalDB:getBool(key, false) then return false end
    LocalDB:setBool(key, true, true)
    return true
end

function ReturnGift2Panel:getGiftCarAppearAnimKey()
    local packageType = Extra.getPackageType(self.moduleExtra)
    if packageType == Const.PackageType.NONE and self.commonGiftData and self.commonGiftData.getExtraValue then
        packageType = tonumber(self.commonGiftData:getExtraValue("packageType")) or Const.PackageType.NONE
    end
    if packageType == Const.PackageType.NONE then return nil end

    local goodsId = self.commonGiftData and self.commonGiftData.getGoodsId and self.commonGiftData:getGoodsId() or 0
    return string.format("ReturnGiftGiftCarAppear_%s_%s_%s", tostring(Const.ActId), tostring(packageType), tostring(goodsId))
end

function ReturnGift2Panel:createGiftCarAnim(animName, loop, finishCallback)
    local anim = UICreateUtil:createSpineManuallyRelease(GIFT_CAR_SPINE_PATH)
    if not anim then return nil end

    if loop then
        anim:playByName(animName, true)
    elseif anim.playOnce then
        anim:playOnce(animName, finishCallback)
    else
        anim:playByName(animName, false)
    end
    return anim
end

function ReturnGift2Panel:initDiscountIcon(isEnterAnim)
    if not self.discountNode or not AMFCompHelper then return end

    self.discountNode:setVisible(true)
    if self.discountBg then self.discountBg:setVisible(false) end
    -- if self.priceRichText then self.priceRichText:setVisible(false) end

    local oldDiscountIcon = self.discountNodeChild
    if oldDiscountIcon then
        oldDiscountIcon:setPositionXY(0, 0)
        oldDiscountIcon:removeFromParentAndCleanup(false)
    end

    local discountIcon = self.discountIcon
    if not discountIcon  then
        discountIcon = AMFCompHelper:createDiscountNormal()
        if not discountIcon then return end

        local price, originPrice = self.commonGiftData:getPrice()
        discountIcon:setPositionXY(75, 78)
        -- discountIcon:setScale(0.8)

        -- originPrice = 1968 --debug
        self.priceRichText:setString(string.format("<outline color=#813125FF width=3><shadow color=#7D2F23FF dist=0>%s<size=23>元", formatOriginPrice(originPrice) ))

        self.discountNode:addChildAt(discountIcon, 0)
        self.discountIcon = discountIcon
    end

    if isEnterAnim then
        -- setTimeOut(function ()
            -- if self.isDisposed then return end
            discountIcon:playEnterAnimUseNode(oldDiscountIcon)
        -- end, 0.1)
    else
        discountIcon:playIdleAnimUseNode(oldDiscountIcon)
    end

end

function ReturnGift2Panel:getCurrentRewardNodeCount()
    local rewardNodes = Extra.getRewardNodes(self.moduleExtra)
    if #rewardNodes == 0 then
        rewardNodes = self:getDefaultRewardNodes()
    end
    return #rewardNodes
end



function ReturnGift2Panel:enterAnim()

end

function ReturnGift2Panel:createEnterAnimRegistry()
    local Registry = require "amf.middleware.ui.kit.templates.tools.Registry"
    local registry = Registry.new()

    local function register(name, getter)
        registry:register(name, getter)
    end

    register("contentNode", function() return self.contentNode end)
    register("unpurchasedNode", function() return self.unpurchasedNode end)
    register("addImg_1", function() return self.addImg_1 end)
    register("addImg_2", function() return self.addImg_2 end)
    register("addImg_3", function() return self.addImg_3 end)
    register("subTitleImg_1", function() return self.subTitleImg_1 end)
    register("subTitleImg_2", function() return self.subTitleImg_2 end)
    register("typeNode_1_1", function()
        return self.awardItemNodes and self.awardItemNodes[1] and self.awardItemNodes[1].typeNode2
    end)
    -- register("typeNode_1_2", function()
    --     return self.awardItemNodes and self.awardItemNodes[2] and self.awardItemNodes[2].typeNode2
    -- end)

    return registry
end

--endregion

--region 解锁动画


function ReturnGift2Panel:playBuySuccessUnlockAnim()
    if self.isDisposed then return end
    self.moduleExtra = self.moduleDelegate and self.moduleDelegate.moduleExtra or self.moduleExtra or {}

    self:prepareBuySuccessUnlockAnim()
    self:runBuySuccessUnlockAnim()
end

function ReturnGift2Panel:prepareBuySuccessUnlockAnim()
    if self.subTitleImg_2 then
        self.subTitleImg_2:stopAllActions()
        self.subTitleImg_2:setVisible(true)
        self.subTitleImg_2:setScale(0)
        if self.subTitleImg_2.setOpacity then self.subTitleImg_2:setOpacity(0) end
    end

end

---解锁anim
function ReturnGift2Panel:runBuySuccessUnlockAnim()
    --左边道具条
    local action = ActionUtil:sequence({
        CCDelayTime:create(11/30),
        CCEaseSineInOut:create(CCScaleTo:create(9/30, 1.02896)),
        ActionUtil:spawn({
            CCEaseSineInOut:create(CCScaleTo:create(4/30, 0)),
            CCEaseSineOut:create(CCFadeOut:create(3/30)),
        }),
    })
    self.unpurchasedNode:runAction(action)

    local action = ActionUtil:sequence({
        CCDelayTime:create(18/30),
        CCFadeOut:create(5/30),
    })
    self.subTitleImg_1:runAction(action)

    local action = ActionUtil:sequence({
        CCDelayTime:create(24/30),
        ActionUtil:spawn({
            CCEaseSineInOut:create(CCScaleTo:create(3/30, 1.04304)),
            CCEaseSineOut:create(CCFadeIn:create(5/30)),
        }),
        CCScaleTo:create(2/30, 1),
    })
    self.subTitleImg_2:runAction(action)

    for i = 1, #self.awardItemNodes, 1 do
        local awardItemNode = self.awardItemNodes and self.awardItemNodes[i]
        --item解锁动画
        setTimeOut(function ()
            if self.isDisposed then return end
            awardItemNode:playUnlockAnim()
        end, (i-1)*2/30)

        local addImg = self["addImg_" .. tostring(i)]
        local action = ActionUtil:sequence({
            CCDelayTime:create(16/30),
            CCFadeOut:create(7/30),
        })
        addImg:runAction(action)
    end

    setTimeOut(function ()
        if self.isDisposed then return end
        self:refresh()
    end, 2.1)
end


--endregion







function ReturnGift2Panel:isFullScreenPanel()
    return false
end
return ReturnGift2Panel
