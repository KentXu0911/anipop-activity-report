local Const = require "amf.feature.localactivity.collectcard.config.CollectCardConst"
local AskShareLogic = require "amf.feature.localactivity.collectcard.share.CollectCardAskShareLogic"
local CollectCardEventCenter = require "amf.feature.localactivity.collectcard.event.CollectCardEventCenter"
local deferred = require "amf.script.sugar.deferred"

local CardDisplayPanelVM = class("CardDisplayPanelVM", AMFBasePanelVM)

local Builder = newBuilder(CardDisplayPanelVM)

function Builder:setCardData(cardData)
    self.cardData = cardData
    return self
end

function Builder:setWorldPos(worldPos)
    self.worldPos = worldPos
    return self
end

function Builder:setIsNew(isNew)
    self.isNew = isNew
    return self
end

function Builder:setCollectCardManager(collectCardManager)
    self.collectCardManager = collectCardManager
    return self
end

function CardDisplayPanelVM:_createPanel(...)
    local CardDisplayPanel = require "amf.feature.localactivity.collectcard.view.CardDisplayPanel"
    return CardDisplayPanel:create(CardDisplayPanelVM, ...)
end

function CardDisplayPanelVM:init(delegate)
    self.cardData = delegate.cardData
    self.worldPos = delegate.worldPos
    self.isNew = delegate.isNew
    self.collectCardManager = delegate.collectCardManager
    self.panelId = UICreateUtil:getPanelId("CardDisplayPanelVM")
    self.swapEnabled = self.collectCardManager:isCollectCardSwapEnabled()
    if self.swapEnabled then
        CollectCardEventCenter:register(CollectCardEvent.CARD_NUM_UPDATE, self.onCardNumUpdate, self)
    end
end

function CardDisplayPanelVM:onCardNumUpdate()
    if self.isDisposed or not self.swapEnabled then return end
    self:callViewFunc("updateCard", self.cardData)
    self:refreshState()
end

function CardDisplayPanelVM:getCardState(helpRemain)
    local State = Const.CardDisplayState
    local gotNum = self.cardData:getGotNum()
    local isGold = self.cardData:getCardType() == Const.CardType.GOLD
    if isGold then
        return State.UNGIFTABLE
    end
    if gotNum <= 0 then
        return helpRemain > 0 and State.SEEK_HELP or State.COOLDOWN
    end
    return State.GIFTABLE
end

function CardDisplayPanelVM:getGiftDisabledTip(sendRemain)
    if sendRemain <= 0 then
        return "今日次数已用完～"
    end
    if self.cardData:getGotNum() <= 1 then
        return "只有重复的卡片才可以赠送哦~"
    end
end

function CardDisplayPanelVM:refreshState()
    local model = self.collectCardManager:getModel()
    local state = self:getCardState(model:getHelpRemain())
    local stateData = {}
    self.giftDisabledTip = nil
    if state == Const.CardDisplayState.COOLDOWN then
        local cooldownLeftTime = model:getCdHelpEndTime() / 1000 - TimeKit:timeInSec()
        if cooldownLeftTime <= 0 then
            self:onHelpCooldownEnd()
            return
        end
        stateData.cooldownLeftTime = cooldownLeftTime
    end
    if state == Const.CardDisplayState.GIFTABLE then
        stateData.sendRemain = model:getSendRemain()
        stateData.sendDailyLimit = model:getSendDailyLimit()
        self.giftDisabledTip = self:getGiftDisabledTip(stateData.sendRemain)
        stateData.giftEnabled = self.giftDisabledTip == nil
    elseif state == Const.CardDisplayState.UNGIFTABLE then
        stateData.ungiftableText = self.cardData:getGotNum() <= 0
            and "金卡不能求助哦~" or "金卡不能赠送~"
    elseif state == Const.CardDisplayState.SEEK_HELP then
        self.askChannelState = AskShareLogic:getAskChannelState()
        stateData = self.askChannelState
        if self.askChannelState.showWechatFriend
            and not self.hasAskShareShowDc
        then
            self.hasAskShareShowDc = true
            self.collectCardManager:dcActPlug():dcAskShareShow(
                self.panelId,
                self.collectCardManager.ACT_ID,
                self.cardData:getCardId()
            )
        end
    end

    self:callViewFunc("updateState", state, stateData)
end

function CardDisplayPanelVM:onCloseBtnTapped()
    self.collectCardManager:playEffect(Const.Sound.CLICK_COMMON_01)
    self.collectCardManager:playHaptics(Const.Haptics.BUTTON_NORMAL)

    AMFBasePanelVM.onCloseBtnTapped(self)
end

function CardDisplayPanelVM:onGiftBtnTapped()
    if self.giftDisabledTip then
        CommonTip:showTip(self.giftDisabledTip)
        return
    end
    self.collectCardManager:dcActPlug():dcCardClick(self.panelId, self.cardData:getCardId())
    self:openFriendSelectPanel(Const.FriendSelectMode.GIVE)
end

function CardDisplayPanelVM:onCommunityTapped()
    self.collectCardManager:dcActPlug():dcAskSharePanelClick(
        self.panelId,
        self.collectCardManager.ACT_ID,
        self.cardData:getCardId()
    )
end

function CardDisplayPanelVM:onSeekHelpFriendBtnTapped()
    self:openFriendSelectPanel(Const.FriendSelectMode.ASK)
end

function CardDisplayPanelVM:openFriendSelectPanel(mode)
    if #self.collectCardManager:getAllFriendInfo() == 0 then
        CommonTip:showTip("您还没有好友，快去小伙伴们加好友吧！")
        return
    end
    self.collectCardManager:openFriendSelectPanel({
        mode = mode,
        cardId = self.cardData:getCardId(),
        sourcePanelId = self.panelId,
        onContinue = function(context)
            return self:onFriendSelected(context)
        end,
        afterSuccessClose = function(_, context)
            if self.isDisposed then return end
            if context.mode == Const.FriendSelectMode.ASK then
                self:close()
                self.collectCardManager:openTransferResultPanel(
                    "请求已发送",
                    "您的好友有 24 小时的时间回应您的请求~"
                )
            else
                self:openTransferConfirmPanel(context)
            end
        end,
    })
end

function CardDisplayPanelVM:openTransferConfirmPanel(context)
    local mode = context.exchangeEnabled
        and Const.TransferConfirmMode.EXCHANGE_REQUEST
        or Const.TransferConfirmMode.GIFT
    self.collectCardManager:openTransferConfirmPanel({
        mode = mode,
        panelId = context.sourcePanelId,
        sourceCardId = context.cardId,
        targetUids = context.targetUids,
        targetProfile = context.targetProfile,
        onCreateSuccess = function()
            if not self.isDisposed then self:close() end
        end,
    })
end

function CardDisplayPanelVM:onFriendSelected(context)
    if context.mode == Const.FriendSelectMode.ASK then
        return self:submitHelp(context)
    end

    return deferred.success()
end

function CardDisplayPanelVM:submitHelp(context)
    return self.collectCardManager:createSwapMessage({
        type = Const.SwapCreateType.HELP,
        targetUids = context.targetUids,
        cardId = context.cardId,
    }):next(function(response)
        self.collectCardManager:dcActPlug():dcFriendHelpResult(
            context.panelId,
            #context.targetUids,
            1
        )
        if not self.isDisposed then self:refreshState() end
        return response
    end, function(error)
        self.collectCardManager:dcActPlug():dcFriendHelpResult(
            context.panelId,
            #context.targetUids,
            2,
            error:getErrorCode()
        )
        return deferred.error(error)
    end)
end

function CardDisplayPanelVM:onSeekHelpWechatBtnTapped()
    if self.isWechatSharePending then return end
    if not _G.amfBean("NetworkStatusManager"):isNetworkEnabled() then
        CommonTip:showTip("网络异常，请检查网络~")
        return
    end

    local channelState = self.askChannelState
    if channelState.wechatInstalled == false then
        CommonTip:showTip("没有检测到微信，请先安装~")
        return
    end

    self.collectCardManager:dcActPlug():dcAskShareClick(
        self.panelId,
        self.collectCardManager.ACT_ID,
        self.cardData:getCardId()
    )

    self.isWechatSharePending = true

    local function finishShare(imageUrl)
        if self.isDisposed then return end
        if imageUrl and imageUrl ~= "" then
            AskShareLogic:startWechatAsk(
                self.cardData:getCardName(),
                imageUrl,
                self.cardData:getCardId(),
                self.panelId
            )
        else
            CommonTip:showTip("分享图片生成失败，请稍后重试")
        end
        self.isWechatSharePending = false
    end

    if channelState.imageMode == Const.ShareImageMode.DYNAMIC then
        self:callViewFunc("captureAskShareImage", self.cardData, finishShare)
    else
        finishShare(AskShareLogic:getFixedShareImageUrl())
    end
end

function CardDisplayPanelVM:onHelpCooldownEnd()
    local model = self.collectCardManager:getModel()
    model:setDataByKey("helpRemain", 1)
    model:setDataByKey("cdHelpEndTime", 0)
    self:refreshState()
end

function CardDisplayPanelVM:onEnterPanelRun()
    self:callViewFunc("initCard", self.cardData, self.worldPos, self.isNew)
    if not self.swapEnabled then
        self.collectCardManager:dcActPlug():dcCardDisplay(self.cardData:getCardId(), self.panelId)
        return
    end
    self:refreshState()
    local gotNum = self.cardData:getGotNum()
    local cardState
    if self.cardData:getCardType() == Const.CardType.GOLD then
        cardState = 3
    elseif gotNum > 1 then
        cardState = 1
    elseif gotNum == 1 then
        cardState = 2
    end
    self.collectCardManager:dcActPlug():dcCardDisplay(
        self.cardData:getCardId(),
        cardState,
        self.collectCardManager:getModel():getSendRemain(),
        self.panelId
    )
end

function CardDisplayPanelVM:recycle()
    AMFBasePanelVM.recycle(self)
    if self.swapEnabled then
        CollectCardEventCenter:unregister(CollectCardEvent.CARD_NUM_UPDATE, self.onCardNumUpdate, self)
    end
end

return CardDisplayPanelVM
