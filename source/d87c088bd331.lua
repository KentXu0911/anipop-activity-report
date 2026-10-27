---@class LuckyDeliveryCardRewardPanel : AMFBasePanel
local LuckyDeliveryCardRewardPanel = class("LuckyDeliveryCardRewardPanel", AMFBasePanel)

local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local OpenCardAnimConfig = require "amf.feature.localactivity.collectcard.view.opencardanim.OpenCardAnimConfig"
local OpenCardAnimModel = require "amf.feature.localactivity.collectcard.view.opencardanim.OpenCardAnimModel"
local OpenCardUIBuilder = require "amf.feature.localactivity.collectcard.view.opencardanim.OpenCardUIBuilder"
local CardAnimator = require "amf.feature.localactivity.collectcard.view.opencardanim.CardAnimator"
local OpenCardAnimController = require "amf.feature.localactivity.collectcard.view.opencardanim.OpenCardAnimController"

local BASE_CARD_SCALE = 0.5
local MAX_CARD_NUM = 9

local function sortNodesByLayout(nodes)
    table.sort(nodes, function(a, b)
        local ay, by = a:getPositionY(), b:getPositionY()
        if math.abs(ay - by) > 1 then
            return ay > by
        end
        return a:getPositionX() < b:getPositionX()
    end)
end

function LuckyDeliveryCardRewardPanel:getUIInfo()
    return "amf.feature.localactivity.luckydelivery.view.uisource.LuckyDeliveryCardRewardPanel_UI", { "noBubbleNode", "withBubbleNode" }
end

function LuckyDeliveryCardRewardPanel:getAssetsList()
    local resList = {}
    local mgr = _G.amfBean("CollectCardManager")
    local const = mgr:getConst()
    resList = table.union(resList, mgr:getCardUIResource() or {})
    resList = table.union(resList, mgr:getAlbumResource() or {})

    for _, key in ipairs({"NewCardSpine", "StarSpine", "IconFeedbackSpine"}) do
        table.insert(resList, OpenCardAnimConfig.ResPath[key])
    end
    if mgr:isCollectCardSwapEnabled() then
        table.insert(resList, "amf/activity/collectcard/texture/CollectCardMainEntryBar.plist")
    else
        table.insert(resList, OpenCardAnimConfig.ResPath.StarShopBg)
        table.insert(resList, OpenCardAnimConfig.ResPath.StarShopIcon)
    end

    for _, sound in ipairs({
        const.Sound.MOVE_NEW_CARD_1,
        const.Sound.MOVE_REPEAT_CARD,
        const.Sound.CARD_CONVERT,
        const.Sound.STAR_TO_BAG,
        const.Sound.STAR_IN_BAG,
    }) do
        table.insert(resList, const.SoundPath[sound])
    end

    return resList
end

function LuckyDeliveryCardRewardPanel:init()
    self.collectCardManager = _G.amfBean("CollectCardManager")
    self.openCardUIBuilder = OpenCardUIBuilder.new()
    self.settleModel = OpenCardAnimModel.new()
    self.animator = CardAnimator.new(self.settleModel, self.openCardUIBuilder)
    self.settleController = OpenCardAnimController.new(self.settleModel, self.animator, self.openCardUIBuilder)
    self.settleController:setDelegate(self)
    self.shownCardList = {}
    self.extraReward = nil
    self.cardAppearAnimPlaying = false
    self.pendingSettleCallback = nil
    self:setBlockEnabled(false)
    self:bindButtons()
end

function LuckyDeliveryCardRewardPanel:dispose()
    if self.animator then
        self.animator:clearAllStarNodes()
    end
    if self.starShopIcon and not self.starShopIcon.isDisposed then
        self.starShopIcon:removeFromParentAndCleanup(true)
        self.starShopIcon = nil
    end
    if self.settleController then
        self.settleController:dispose()
        self.settleController = nil
    end
    AMFBasePanel.dispose(self)
end

function LuckyDeliveryCardRewardPanel:bindButtons()
    self.receiveBtn:setTouchHandler(function()
        self:sendCommand("onReceiveBtnTapped")
    end)
end

function LuckyDeliveryCardRewardPanel:initRewards(cardRewards, extraReward)
    self.cardRewards = cardRewards or {}
    self.extraReward = extraReward
    self.cardDisplayInfos = self:buildCardDisplayInfos()

    local cardNum = math.min(math.max(#self.cardDisplayInfos, 1), MAX_CARD_NUM)
    local suffix = self.extraReward and 2 or 1
    local layoutNode = self.builder:createChild(string.format("card_%d_%d", cardNum, suffix))
    self.ui:addChild(layoutNode)
    self.cardLayoutNode = layoutNode

    self:initCardRewards()
    self:initExtraReward(cardNum)
end

function LuckyDeliveryCardRewardPanel:initCardRewards()
    local posNodes = {}
    for _, child in ipairs(self.cardLayoutNode:getChildrenSafeList() or {}) do
        if child.getName and string.starts(tostring(child:getName()), "cardPosNode_") then
            table.insert(posNodes, child)
        end
    end
    sortNodesByLayout(posNodes)

    local cardDisplayInfos = self.cardDisplayInfos or self:buildCardDisplayInfos()
    local cardScale = self:getCardScale(#cardDisplayInfos, self.extraReward ~= nil)
    local appearAnimInfos = {}

    for index, reward in ipairs(cardDisplayInfos) do
        local card = self:addCardToPosNode(reward, posNodes[index], cardScale)
        table.insert(appearAnimInfos, {
            card = card,
            posNode = posNodes[index],
            reward = reward,
            scale = cardScale,
        })
    end

    self:playCardAppearAnim(appearAnimInfos)
end

function LuckyDeliveryCardRewardPanel:getCardScale(cardNum, hasExtraReward)
    local displayScale = 1
    if hasExtraReward then
        if cardNum >= 7 then
            displayScale = 0.8
        elseif cardNum >= 3 then
            displayScale = 0.9
        end
    elseif cardNum >= 7 then
        displayScale = 0.9
    end
    return BASE_CARD_SCALE * displayScale
end

function LuckyDeliveryCardRewardPanel:addCardToPosNode(reward, posNode, cardScale)
    local card = self.openCardUIBuilder:createCard(reward.cardData, not reward.isRepeat)
    card:setScale(0)
    card:setPositionXY(0, 0)
    posNode:addChild(card)

    table.insert(self.shownCardList, {
        cardData = reward.cardData,
        node = card,
        isNewCard = reward.isNewCard,
        isRepeat = reward.isRepeat,
        cardScale = cardScale or BASE_CARD_SCALE,
    })

    return card
end

function LuckyDeliveryCardRewardPanel:playCardAppearAnim(appearAnimInfos)
    if table.isEmpty(appearAnimInfos) then return end

    self.cardAppearAnimPlaying = true
    local index = 1
    local playNext
    playNext = function()
        if self.isDisposed then return end
        local animInfo = appearAnimInfos[index]
        if not animInfo then
            self:onCardAppearAnimFinished()
            return
        end
        index = index + 1
        self:playSingleCardAppearAnim(animInfo, 0, playNext)
    end
    playNext()
end

function LuckyDeliveryCardRewardPanel:playSingleCardAppearAnim(animInfo, delay, callback)
    local card = animInfo.card
    local reward = animInfo.reward

    local cardScale = animInfo.scale or BASE_CARD_SCALE
    card:setScale(0)
    card:runAction(ActionUtil:sequence{
        CCDelayTime:create(delay or 0),
        CCCallFunc:create(function()
            if self.isDisposed or card.isDisposed then
                safeRunCall(callback)
                return
            end
            self:playCardAppearEffect(animInfo)
            if reward.isRepeat then
                card:runAction(ActionUtil:sequence{
                    CCScaleTo:create(3 * OpenCardAnimConfig.FRAME_TIME, cardScale * 1.2),
                    CCScaleTo:create(3 * OpenCardAnimConfig.FRAME_TIME, cardScale),
                    CCCallFunc:create(function()
                        safeRunCall(callback)
                    end)
                })
            end
        end),
        CCDelayTime:create(reward.isRepeat and 0 or 15 * OpenCardAnimConfig.FRAME_TIME),
        CCCallFunc:create(function()
            if reward.isRepeat then return end
            if self.isDisposed or card.isDisposed then
                safeRunCall(callback)
                return
            end
            card:setScaleX(0.6 * cardScale)
            card:setScaleY(cardScale)
            card:runAction(ActionUtil:sequence{
                CCEaseSineInOut:create(CCScaleTo:create(2 * OpenCardAnimConfig.FRAME_TIME, cardScale, cardScale)),
                CCCallFunc:create(function()
                    safeRunCall(callback)
                end)
            })
        end)
    })
end

function LuckyDeliveryCardRewardPanel:playCardAppearEffect(animInfo)
    local reward = animInfo.reward
    local Const = self.collectCardManager:getConst()
    if not reward.isRepeat then
        local effectType = Const.Sound.MOVE_NEW_CARD_1
        self.collectCardManager:playEffect(effectType)
        self.collectCardManager:playHaptics(Const.Haptics.NEW_CARD_DROP)
        self:playNewCardLight(animInfo)
    else
        self.collectCardManager:playEffect(Const.Sound.MOVE_REPEAT_CARD)
        self.collectCardManager:playHaptics(Const.Haptics.CARD_DROP)
    end
end

function LuckyDeliveryCardRewardPanel:playNewCardLight(animInfo)
    local reward = animInfo.reward
    local cardData = reward.cardData
    local posNode = animInfo.posNode

    local Const = self.collectCardManager:getConst()
    local cardSp = UICreateUtil:createSpine(OpenCardAnimConfig.ResPath.NewCardSpine)
    local animName = cardData.cardType == Const.CardType.GOLD and "xinka_jin" or "xinka_yin"
    posNode:addChild(cardSp)
    cardSp:setPositionXY(0, 0)
    cardSp:playOnceAndDispose(animName)
    cardSp:setScale(0.6 * ((animInfo.scale or BASE_CARD_SCALE) / BASE_CARD_SCALE))
    local oriScale = cardSp:getScale()
    cardSp:runAction(ActionUtil:sequence{
        CCEaseSineInOut:create(CCScaleTo:create(12 * OpenCardAnimConfig.FRAME_TIME, oriScale * 1.3)),
        CCEaseSineIn:create(CCScaleTo:create(4 * OpenCardAnimConfig.FRAME_TIME, oriScale)),
    })
end

function LuckyDeliveryCardRewardPanel:onCardAppearAnimFinished()
    if self.isDisposed then return end

    self.cardAppearAnimPlaying = false
    if self.pendingSettleCallback then
        local callback = self.pendingSettleCallback
        self.pendingSettleCallback = nil
        self:playSettleAnim(callback)
    end
end

function LuckyDeliveryCardRewardPanel:buildCardDisplayInfos()
    local cardIdList = {}
    local getCardList = {}

    for _, reward in ipairs(self.cardRewards or {}) do
        local cardId = reward.cardId or self.collectCardManager:getCardIdByItemId(reward.itemId)
        local cardData = cardId and self.collectCardManager:getCardDataById(cardId)
        if cardData then
            local num = math.max(math.floor(tonumber(reward.num) or 1), 1)
            local cardIdKey = tostring(cardData.cardId)
            getCardList[cardIdKey] = (getCardList[cardIdKey] or 0) + num
            for _ = 1, num do
                if #cardIdList >= MAX_CARD_NUM then break end
                table.insert(cardIdList, cardData.cardId)
            end
        end
    end

    self.settleModel.getCardList = getCardList
    return self.settleModel:buildCardInfoList(cardIdList)
end

function LuckyDeliveryCardRewardPanel:initExtraReward(cardNum)
    if not self.extraReward then return end

    local rewardItem = self.cardLayoutNode.mbMap["rewardItem_" .. tostring(cardNum)]
    rewardItem:setItem(self.extraReward)
end

function LuckyDeliveryCardRewardPanel:playSettleAnim(callback)
    if self.cardAppearAnimPlaying then
        self.pendingSettleCallback = callback
        return
    end

    if table.isEmpty(self.shownCardList) then
        safeRunCall(callback)
        return
    end

    self.settleModel.localStarNum = self:getLocalStarNumBeforeSettle()
    self.settleController:settleCards(self.shownCardList, nil):next(function()
        safeRunCall(callback)
    end, function()
        safeRunCall(callback)
    end)
end

function LuckyDeliveryCardRewardPanel:getLocalStarNumBeforeSettle()
    local gotStarNum = 0
    for _, cardInfo in ipairs(self.shownCardList or {}) do
        if cardInfo.isRepeat and cardInfo.cardData then
            gotStarNum = gotStarNum + (cardInfo.cardData.starLevel or 0)
        end
    end

    return (self.collectCardManager:getStarNum() or 0) - gotStarNum
end

function LuckyDeliveryCardRewardPanel:getLocalStarNum()
    if self.settleModel then
        return self.settleModel:getLocalStarNum()
    end
    return self:getLocalStarNumBeforeSettle()
end

function LuckyDeliveryCardRewardPanel:getStarShopIcon()
    return self.starShopIcon
end

function LuckyDeliveryCardRewardPanel:setStarShopIcon(icon)
    self.starShopIcon = icon
end

return LuckyDeliveryCardRewardPanel
