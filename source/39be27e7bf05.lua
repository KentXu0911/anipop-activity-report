local CollectCardEventCenter = require "amf.feature.localactivity.collectcard.event.CollectCardEventCenter"

local AlbumPanelVM = class("AlbumPanelVM", AMFBasePanelVM)

local Builder = newBuilder(AlbumPanelVM)

function Builder:setAlbumDataList(albumDataList)
    self.albumDataList = albumDataList
    return self
end

function Builder:setAlbumId(albumId)
    self.albumId = albumId
    return self
end

function Builder:setManager(collectCardManager)
    self.collectCardManager = collectCardManager
    return self
end

function AlbumPanelVM:_createPanel(...)
    local AlbumPanel = require_debug "amf.feature.localactivity.collectcard.view.AlbumPanel"
    return AlbumPanel:create(AlbumPanelVM, ...)
end

function AlbumPanelVM:init(delegate)
    self.albumId = delegate.albumId or 1
    self.albumDataList = delegate.albumDataList
    self.collectCardManager = delegate.collectCardManager
    self.panelId = UICreateUtil:getPanelId("AlbumPanelVM")

    self.maxPage = #self.albumDataList
    CollectCardEventCenter:register(CollectCardEvent.CARD_NUM_UPDATE, self.onCardNumUpdate, self)
end

function AlbumPanelVM:secondLoadCompleted()
    self:callViewFunc("initUI")
    self:refreshCurrentPage()
end

function AlbumPanelVM:playFeedback(isTurnPage)
    local const = self.collectCardManager:getConst()
    self.collectCardManager:playEffect(isTurnPage and const.Sound.TURN_PAGE or const.Sound.CLICK_COMMON_01)
    self.collectCardManager:playHaptics(const.Haptics.BUTTON_NORMAL)
end

function AlbumPanelVM:turnPage(delta)
    local targetAlbumId = self.albumId + delta
    if targetAlbumId >= 1 and targetAlbumId <= self.maxPage then
        self:playFeedback(true)

        self.albumId = targetAlbumId
        self:refreshCurrentPage()

        local currentAlbumData = self.albumDataList[self.albumId]
        self.collectCardManager:dcActPlug():dcAlbumPanelShow(2, self.albumId, currentAlbumData:getCollectedCount(), self.panelId)
    end
end

function AlbumPanelVM:getCardsData(cardIds)
    local cardsData = {}
    for i, cardId in ipairs(cardIds) do
        local cardData = self.collectCardManager:getCardDataById(cardId)
        if cardData then
            table.insert(cardsData, cardData)
        end
    end
    return cardsData
end

function AlbumPanelVM:getCurrentRewardsData(albumId)
    local roundId = self.collectCardManager:getModel():getRoundId()
    local rewardConfigList = self.collectCardManager:getModel():getConfigByKey("cardAlbumRewardConfigList", {})

    for i, cfg in ipairs(rewardConfigList) do
        if cfg.albumId == albumId then
            local min, max = string.match(cfg.roundRange or "", "^(%d+)~(%d+)$")
            if min and max then
                if roundId >= tonumber(min) and roundId <= tonumber(max) then
                    return cfg.rewards or {}
                end
            elseif tonumber(cfg.roundRange) and roundId == tonumber(cfg.roundRange) then
                return cfg.rewards or {}
            end
        end
    end
    return {}
end

function AlbumPanelVM:refreshCurrentPage()
    local currentAlbumData = self.albumDataList[self.albumId]

    local cardsData = self:getCardsData(currentAlbumData:getCardIds())
    local currentRewards = self:getCurrentRewardsData(self.albumId)
    local themeConfig = self.collectCardManager:getThemeConfig(self.albumId)

    self.showIsNewFlags = {}
    for i, cardData in ipairs(cardsData) do
        local isNew = self.collectCardManager:isNewCard(cardData:getCardId())
        if isNew then
            self.showIsNewFlags[cardData:getCardId()] = true
            self.collectCardManager:setCardViewed(cardData:getCardId(), true)
        end
    end

    self:callViewFunc("updatePageInfo", self.albumId, self.maxPage)
    self:callViewFunc("updateThemeColor", themeConfig)
    self:callViewFunc("updateCards", cardsData, self.showIsNewFlags)
    self:callViewFunc("updateRewards", currentRewards, currentAlbumData:getHasGotReward())
    self:callViewFunc("updateAlbumCell", currentAlbumData)
end

function AlbumPanelVM:onCardNumUpdate()
    if self.isDisposed then return end
    self:refreshCurrentPage()
end

function AlbumPanelVM:onCardClicked(cardNode)
    self:playFeedback()

    local cardData = cardNode:getData()
    if not self.collectCardManager:isCollectCardSwapEnabled()
        and cardData:getGotNum() <= 0
    then
        UITip.Builder.new()
            :setTarget(cardNode, CCSizeMake(0, 270))
            :setTitle("你可以从活动奖励中获得这张卡片。")
            :build()
        return
    end

    local worldPos = cardNode:getPositionInWorldSpace()
    local isNew = self.showIsNewFlags[cardData:getCardId()] or false
    if isNew then
        self.showIsNewFlags[cardData:getCardId()] = false
        if cardNode.setNewLabelVisible then cardNode:setNewLabelVisible(false) end
    end

    local CardDisplayPanelVM = require "amf.feature.localactivity.collectcard.view.CardDisplayPanelVM"
    local vm = CardDisplayPanelVM.Builder.new()
        :setCardData(cardData)
        :setWorldPos(worldPos)
        :setIsNew(isNew)
        :setCollectCardManager(self.collectCardManager)
        :build()
    vm:popout()

    self.collectCardManager:callPanelFunc("managePanelVM", vm)
end

function AlbumPanelVM:onRareDecoClicked()
    self:playFeedback()
    self.collectCardManager:openJuebanPanel()
end

function AlbumPanelVM:onEnterPanelRun()
    local currentAlbumData = self.albumDataList[self.albumId]
    self.collectCardManager:dcActPlug():dcAlbumPanelShow(1, self.albumId, currentAlbumData:getCollectedCount(), self.panelId)
end

function AlbumPanelVM:onCloseBtnTapped()
    self:playFeedback()

    AMFBasePanelVM.onCloseBtnTapped(self)
end

function AlbumPanelVM:onRewardClicked(target, index)
    self:playFeedback()

    local rewardsData = self:getCurrentRewardsData(self.albumId)
    UITip.Builder.new()
        :setTarget(target)
        :setTitle(_G.amfBean("PropManager"):getPropName(rewardsData[index]))
        :setAutoCloseTime(3)    
        :build()
end

function AlbumPanelVM:recycle()
    AMFBasePanelVM.recycle(self)
    CollectCardEventCenter:unregister(CollectCardEvent.CARD_NUM_UPDATE, self.onCardNumUpdate, self)
end

return AlbumPanelVM
