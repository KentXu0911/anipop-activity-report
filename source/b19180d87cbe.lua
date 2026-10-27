local Const = require "amf.feature.localactivity.collectcard.config.CollectCardConst"

local CollectCardFriendMessagePanelVM = class("CollectCardFriendMessagePanelVM", UeAMFBasePanelVM)

local TYPE = Const.SwapCreateType
local STATE = Const.SwapMessageState
local DIRECTION = Const.SwapMessageDirection

local ACTION_TEXT = {
    accept = "接受",
    reject = "拒绝",
    cancel = "取消",
    ignore = "忽略",
    gift = "赠予",
    selectExchange = "接受",
}

function CollectCardFriendMessagePanelVM.formatRelativeTime(createTime, now)
    createTime = tonumber(createTime)
    if not createTime or createTime <= 0 then return "" end

    local duration = math.max((now or TimeKit:timeInSec()) - createTime / 1000, 0)
    if duration < 60 then
        return string.format("%d秒以前", math.max(1, math.floor(duration)))
    elseif duration < 3600 then
        return string.format("%d分钟以前", math.floor(duration / 60))
    elseif duration < 24 * 3600 then
        return string.format("%d小时以前", math.floor(duration / 3600))
    end
    return string.format("%d天以前", math.floor(duration / (24 * 3600)))
end

function CollectCardFriendMessagePanelVM.formatExpireTime(expireAt, now)
    local leftTime = math.max((tonumber(expireAt) or 0) - (now or TimeKit:timeInSec()), 0)
    local hours = math.floor(leftTime / 3600)
    local minutes = math.floor(leftTime % 3600 / 60)
    return string.format("Ø%02d:%02d后过期", hours, minutes)
end

local function setActions(row, secondaryAction, primaryAction)
    row.secondaryAction = secondaryAction
    row.primaryAction = primaryAction
    row.secondaryText = ACTION_TEXT[secondaryAction]
    row.primaryText = ACTION_TEXT[primaryAction]
end

local function hasDuplicateCard(cardData)
    return cardData and cardData:getGotNum() > 1 or false
end

local function getCardName(manager, cardId)
    local cardData = manager:getCardDataById(cardId)
    return cardData and cardData:getCardName() or "卡片"
end

local function getFriendName(message)
    return nameDecode(message.profile and message.profile.name or "好友")
end

local function fillHelpRow(row, sent, friendName, cardName, cardData)
    if sent then
        row.description = string.format("您已经向%s发送%s卡片的求助消息~", friendName, cardName)
        setActions(row, nil, "cancel")
        return
    end

    row.noCardHelp = not hasDuplicateCard(cardData)
    row.description = string.format("%s向你求助%s卡片~", friendName, cardName)
    if row.noCardHelp then
        row.description = string.format(
            "%s向你求助%s卡片，但您暂时还没有重复的这张卡片",
            friendName,
            cardName
        )
        setActions(row, nil, "ignore")
    else
        setActions(row, "reject", "gift")
    end
end

local function fillGiftRow(row, sent, friendName, cardName)
    if sent then
        row.description = string.format("你向%s赠送了“%s”卡片~", friendName, cardName)
        setActions(row, nil, "cancel")
    else
        row.description = string.format("%s赠送给你“%s”卡片~", friendName, cardName)
        setActions(row, "reject", "accept")
    end
end

local function fillExchangeRow(row, sent, friendName, cardName, manager)
    if row.state == STATE.WAIT_CREATOR_CONFIRM then
        if sent then
            row.description = string.format(
                "是否接受%s用“%s”交换你的“%s”？",
                friendName,
                getCardName(manager, row.selectedCardId),
                cardName
            )
            setActions(row, "reject", "accept")
        else
            row.description = string.format(
                "%s已经收到了您的交换卡请求，需要等待对方回复~",
                friendName
            )
            setActions(row, nil, "cancel")
        end
        return
    end

    if sent then
        row.description = string.format(
            "%s已经收到了您的交换卡片请求，需要等待对方回复~",
            friendName
        )
        setActions(row, nil, "cancel")
    else
        row.description = string.format("%s想要与您交换卡片~", friendName)
        setActions(row, "reject", "selectExchange")
    end
end

local function getResultDescription(messageType, messageState, sent, friendName)
    if messageType == TYPE.HELP and sent
        and (messageState == STATE.REJECTED or messageState == STATE.IGNORED)
    then
        return string.format("很遗憾，%s没有能送出的卡片……", friendName)
    end
    if messageState ~= STATE.REJECTED then return "请求已完成" end
    if messageType == TYPE.EXCHANGE then
        return sent and string.format("%s拒绝了您的换卡请求。", friendName)
            or "我不太想要这张卡片，下次再交换吧~"
    end
    return string.format("%s拒绝了您的请求。", friendName)
end

function CollectCardFriendMessagePanelVM.buildRow(message, currentUid, manager, now, currentProfile)
    local messageType = tonumber(message.type) or 0
    local messageState = tonumber(message.state) or 0
    local sent = tostring(message.creatorUid) == tostring(currentUid)
    local friendProfile = message.profile or {}
    local row = {
        messageId = message.messageId,
        type = messageType,
        state = messageState,
        direction = sent and DIRECTION.SENT or DIRECTION.RECEIVED,
        profile = friendProfile,
        headerProfile = sent and (currentProfile or {}) or friendProfile,
        cardId = tonumber(message.cardId) or 0,
        selectedCardId = tonumber(message.selectedCardId) or 0,
        expireAt = (tonumber(message.expireTime) or 0) / 1000,
        relativeTimeText = CollectCardFriendMessagePanelVM.formatRelativeTime(message.createTime, now),
        contentType = messageType == TYPE.EXCHANGE and "exchange" or "singleCard",
        showExchangeResult = messageType == TYPE.EXCHANGE,
        viewType = (messageState == STATE.REJECTED or messageState == STATE.IGNORED)
            and "result" or "pending",
        acceptDisabled = manager.isSwapAcceptDisabled
            and manager:isSwapAcceptDisabled(message.messageId) or false,
    }
    row.cellHeight = row.viewType == "result" and 268 or 351
    row.expireText = CollectCardFriendMessagePanelVM.formatExpireTime(row.expireAt, now)

    local friendName = getFriendName(message)
    local cardData = manager:getCardDataById(row.cardId)
    local cardName = cardData and cardData:getCardName() or "卡片"

    local validPending = messageState == STATE.WAIT_RECEIVER
        or (messageType == TYPE.EXCHANGE and messageState == STATE.WAIT_CREATOR_CONFIRM)
    if row.viewType == "pending" and not validPending then
        row.viewType = "result"
        row.cellHeight = 268
        row.description = "未知消息状态"
        return row
    end

    if row.viewType == "result" then
        row.description = getResultDescription(messageType, messageState, sent, friendName)
        return row
    end

    if messageType == TYPE.HELP then
        fillHelpRow(row, sent, friendName, cardName, cardData)
    elseif messageType == TYPE.GIFT then
        fillGiftRow(row, sent, friendName, cardName)
    elseif messageType == TYPE.EXCHANGE then
        fillExchangeRow(row, sent, friendName, cardName, manager)
    else
        row.viewType = "result"
        row.cellHeight = 268
        row.description = "未知消息"
    end
    return row
end

function CollectCardFriendMessagePanelVM.buildRows(messages, currentUid, manager, now, currentProfile)
    local rows = {}
    for _, message in ipairs(messages or {}) do
        table.insert(rows, CollectCardFriendMessagePanelVM.buildRow(message, currentUid, manager, now, currentProfile))
    end
    return rows
end

function CollectCardFriendMessagePanelVM:_createPanel(...)
    local Panel = require "amf.feature.localactivity.collectcard.view.CollectCardFriendMessagePanel"
    return Panel:create(CollectCardFriendMessagePanelVM, ...)
end

function CollectCardFriendMessagePanelVM:init(delegate)
    self._mgr = delegate.manager
    self.currentUid = delegate.currentUid
    self.panelId = UICreateUtil:getPanelId("CollectCardFriendMessagePanelVM")
    self.dcData = delegate.dcData
    self.currentProfile = delegate.currentProfile or _G.amfBean("ProfileManager"):getProfile()
    self.eventCenter = require "amf.feature.localactivity.collectcard.event.CollectCardEventCenter"
    self.eventCenter:register(CollectCardEvent.SWAP_DATA_UPDATED, self.onSwapDataUpdated, self)
end

function CollectCardFriendMessagePanelVM:onEnterPanelRun()
    self._mgr:dcActPlug():dcFriendMessageShow(
        self.panelId,
        self.dcData.t1,
        self.dcData.t2,
        self.dcData.t3
    )
end

function CollectCardFriendMessagePanelVM:selectExchangeCard(row)
    self._mgr:openExchangeSelectPanel({
        messageId = row.messageId,
        cardId = row.cardId,
        profile = row.profile,
        onAcceptDisabled = function()
            if self.isDisposed then return end
            row.acceptDisabled = true
            self:callViewFunc("updateMessageRow", row.messageId)
        end,
    })
end

function CollectCardFriendMessagePanelVM:refreshRows(now)
    local model = self._mgr:getModel()
    now = now or TimeKit:timeInSec()
    local rows = self.buildRows(model:getSwapMessages(), self.currentUid, self._mgr, now, self.currentProfile)
    self.rows = {}
    for _, row in ipairs(rows) do
        if row.expireAt <= 0 or row.expireAt > now then table.insert(self.rows, row) end
    end
    self.rowById = {}
    for _, row in ipairs(self.rows) do
        self.rowById[tostring(row.messageId)] = row
    end
    self:callViewFunc("updateMessageRows", self.rows)
    self:scheduleNextExpiry(now)
end

function CollectCardFriendMessagePanelVM:onSwapDataUpdated()
    if self.isDisposed then return end
    self:refreshRows()
end

function CollectCardFriendMessagePanelVM:secondLoadCompleted()
    self:refreshRows()
end

function CollectCardFriendMessagePanelVM:cancelExpiryTimer()
    if not self.expiryTimerId then return end
    self.scheduler:unscheduleScriptEntry(self.expiryTimerId)
    self.expiryTimerId = nil
end

function CollectCardFriendMessagePanelVM:scheduleNextExpiry(now)
    self:cancelExpiryTimer()
    now = now or TimeKit:timeInSec()
    local nextExpireAt
    for _, row in ipairs(self.rows or {}) do
        if row.expireAt > now and (not nextExpireAt or row.expireAt < nextExpireAt) then
            nextExpireAt = row.expireAt
        end
    end
    if not nextExpireAt then return end

    self.scheduler = self.scheduler or CCDirector:sharedDirector():getScheduler()
    local timerId
    timerId = self.scheduler:scheduleScriptFunc(function()
        self.scheduler:unscheduleScriptEntry(timerId)
        if self.expiryTimerId == timerId then self.expiryTimerId = nil end
        if self.isDisposed then return end
        self:removeExpiredRows()
    end, nextExpireAt - now, false)
    self.expiryTimerId = timerId
end

function CollectCardFriendMessagePanelVM:removeExpiredRows(now)
    now = now or TimeKit:timeInSec()
    local remaining = {}
    self.rowById = {}
    for _, row in ipairs(self.rows or {}) do
        if row.expireAt <= 0 or row.expireAt > now then
            table.insert(remaining, row)
            self.rowById[tostring(row.messageId)] = row
        end
    end
    self.rows = remaining
    self:callViewFunc("updateMessageRows", self.rows)
    self:scheduleNextExpiry(now)
end

local ACTION_TO_OP = {
    accept = Const.SwapOperateType.ACCEPT,
    gift = Const.SwapOperateType.ACCEPT,
    reject = Const.SwapOperateType.REJECT,
    cancel = Const.SwapOperateType.CANCEL,
    ignore = Const.SwapOperateType.IGNORE,
}

local function getActionDcType(row, action)
    if row.type == TYPE.HELP and row.direction == DIRECTION.RECEIVED then
        if action == "gift" then return 1 end
        if action == "reject" then return 2 end
        if action == "ignore" then return 3 end
    elseif row.type == TYPE.EXCHANGE and action == "reject" then
        return 4
    elseif row.direction == DIRECTION.SENT and action == "cancel" then
        if row.type == TYPE.HELP then return 5 end
        if row.type == TYPE.EXCHANGE then return 6 end
    end
end

function CollectCardFriendMessagePanelVM:dcOperateResult(row, action, success, error)
    local isExchangeResult = row.type == TYPE.EXCHANGE
        and row.direction == DIRECTION.SENT
        and row.state == STATE.WAIT_CREATOR_CONFIRM
        and action == "accept"
    local actionType = getActionDcType(row, action)
    if not isExchangeResult and not actionType then return end

    local subCategory = isExchangeResult and "exchange_result" or "friend_message_click"
    local errorCode
    if not success then errorCode = error:getErrorCode() end
    local params = {
        panel_id = self.panelId,
        message_id = row.messageId,
        card_id = row.cardId,
        t1 = isExchangeResult and row.cardId or row.profile.xxlId,
        t2 = isExchangeResult and row.profile.xxlId or actionType,
        t3 = success and 1 or 2,
        error_code = errorCode,
    }
    if isExchangeResult then
        local receivedCard = self._mgr:getCardDataById(row.selectedCardId)
        params.card_id = string.format(
            "%s_%s_%s",
            row.selectedCardId,
            receivedCard:getStarLevel(),
            receivedCard:getAlbumId()
        )
    end
    if isExchangeResult then
        self._mgr:dcActPlug():dcExchangeResult(
            params.panel_id,
            params.message_id,
            params.card_id,
            params.t1,
            params.t2,
            params.t3,
            params.error_code
        )
    else
        self._mgr:dcActPlug():dcFriendMessageClick(
            params.panel_id,
            params.card_id,
            params.message_id,
            params.t1,
            params.t2,
            params.t3,
            params.error_code
        )
    end
    if not success then return end

    local consumeItemId
    if isExchangeResult then
        consumeItemId = self._mgr:getCardDataById(row.cardId):getItemId()
    elseif actionType == 1 then
        consumeItemId = self._mgr:getCardDataById(row.cardId):getItemId()
    end
    return consumeItemId, isExchangeResult
end

local function isExchangeFirstAccept(row, action, selectedCardId)
    return row.type == Const.SwapCreateType.EXCHANGE
        and row.state == Const.SwapMessageState.WAIT_RECEIVER
        and row.direction == DIRECTION.RECEIVED
        and action == "accept"
        and (tonumber(selectedCardId) or 0) > 0
end

local function isExchangeRollback(row, action)
    return row.type == Const.SwapCreateType.EXCHANGE
        and row.state == Const.SwapMessageState.WAIT_CREATOR_CONFIRM
        and row.direction == DIRECTION.RECEIVED
        and action == "cancel"
end

function CollectCardFriendMessagePanelVM.buildOperateReceiveData(row, params)
    local isGiftAccept = row.type == Const.SwapCreateType.GIFT
        and row.direction == DIRECTION.RECEIVED
        and params.op == Const.SwapOperateType.ACCEPT
    local isExchangeFinalAccept = row.type == Const.SwapCreateType.EXCHANGE
        and row.direction == DIRECTION.SENT
        and row.state == Const.SwapMessageState.WAIT_CREATOR_CONFIRM
        and params.op == Const.SwapOperateType.ACCEPT
    if not isGiftAccept and not isExchangeFinalAccept then return nil end

    return {
        type = row.type,
        cardId = isGiftAccept and row.cardId or row.selectedCardId,
        profile = row.profile,
    }
end

function CollectCardFriendMessagePanelVM:_operate(row, action, selectedCardId)
    if self:isLocked() then return end

    self:lock()
    local params = {
        messageId = row.messageId,
        op = ACTION_TO_OP[action],
        cardId = row.cardId,
    }
    selectedCardId = selectedCardId or (row.selectedCardId > 0 and row.selectedCardId or nil)
    if selectedCardId ~= nil then params.selectedCardId = selectedCardId end

    self._mgr:requestSwapOperate(params):next(function(result)
        local consumeItemId, isExchangeResult = self:dcOperateResult(row, action, true)
        local applied = false
        local function applyResult()
            if applied then return end
            applied = true
            self._mgr:applySwapOperateSuccess(result:getData() or {}, params, {
                type = row.type,
                direction = row.direction,
                state = row.state,
                cardId = row.cardId,
                selectedCardId = params.selectedCardId,
                profile = row.profile,
            })
            if consumeItemId then
                if isExchangeResult then
                    self._mgr:dcActPlug():dcExchangeResultCardConsume(consumeItemId, 1)
                else
                    self._mgr:dcActPlug():dcFriendMessageClickCardConsume(consumeItemId, 1)
                end
            end
            self:unlock()
            local receiveData = self.buildOperateReceiveData(row, params)
            if receiveData and not self.isDisposed then
                self._mgr:openReceiveCardQueue({receiveData})
            end
        end
        if self.isDisposed
            or isExchangeFirstAccept(row, action, selectedCardId)
            or isExchangeRollback(row, action)
        then
            applyResult()
        else
            self:callViewFunc("playMessageRemoveAnimation", row.messageId, applyResult)
        end
        return result
    end, function(err)
        self:dcOperateResult(row, action, false, err)
        if self._mgr:isSwapAcceptDisabled(row.messageId) then
            row.acceptDisabled = true
            self:callViewFunc("updateMessageRow", row.messageId)
        end
        self:unlock()
        if self.isDisposed then return end
        CommonTip:showErrorTip(err)
        if Const.SwapClosePanelErrorCodes[tonumber(err:getErrorCode())] then self:close() end
    end)
end

function CollectCardFriendMessagePanelVM:onActionTapped(messageId, action)
    local row = self.rowById[tostring(messageId)]
    if not row then return end
    if action == "selectExchange" then
        self:selectExchangeCard(row)
        return
    end
    if ACTION_TO_OP[action] then self:_operate(row, action) end
end

function CollectCardFriendMessagePanelVM:recycle()
    self.eventCenter:unregister(CollectCardEvent.SWAP_DATA_UPDATED, self.onSwapDataUpdated, self)
    self:cancelExpiryTimer()
    UeAMFBasePanelVM.recycle(self)
end

return CollectCardFriendMessagePanelVM
