local UIEventCenter = require "amf.middleware.ui.event.UIEventCenter"
local deferred = require "amf.script.sugar.deferred"
local CollectCardConst = require "amf.feature.localactivity.collectcard.config.CollectCardConst"
local CollectCardFriendSelectPanelVM = class("CollectCardFriendSelectPanelVM", UeAMFBasePanelVM)

local MAX_ASK_SELECTION = 4

function CollectCardFriendSelectPanelVM.normalizeKeyword(keyword)
    return string.sub(string.gsub(keyword, "%D", ""), 1, 11)
end

function CollectCardFriendSelectPanelVM.formatOnlineText(lastLoginTime, isOnline, now)
    if isOnline then return "在线" end

    local duration = math.max((now or TimeKit:timeInSec()) - (tonumber(lastLoginTime) or 0), 0)
    if duration < 3600 then
        return "1小时前在线"
    elseif duration < 24 * 3600 then
        return string.format("%d小时前登录", math.floor(duration / 3600))
    elseif duration <= 7 * 24 * 3600 then
        local hours = math.floor(duration / 3600)
        return string.format("%d天%d小时前登录", math.floor(hours / 24), hours % 24)
    end
    return "7天以前登录过"
end

function CollectCardFriendSelectPanelVM:_createPanel(...)
    local Panel = require "amf.feature.localactivity.collectcard.view.CollectCardFriendSelectPanel"
    return Panel:create(CollectCardFriendSelectPanelVM, ...)
end

function CollectCardFriendSelectPanelVM:init(delegate)
    local Mode = CollectCardConst.FriendSelectMode
    self.mode = delegate.mode == Mode.ASK and Mode.ASK or Mode.GIVE
    self.cardId = delegate.cardId
    self.sourcePanelId = delegate.sourcePanelId
    self.panelId = UICreateUtil:getPanelId("CollectCardFriendSelectPanelVM")
    self.onContinue = delegate.onContinue or deferred.success
    self.afterSuccessClose = delegate.afterSuccessClose
    if delegate.closeCallback then
        self:setCloseCallback(delegate.closeCallback)
    end
    self._mgr = delegate.manager
    self.cardName = self._mgr:getCardDataById(self.cardId):getCardName()
    self.searchText = ""
    self.selectedUids = {}
    self.selectedUidSet = {}
    self.exchangeEnabled = self.mode == Mode.GIVE
        and self._mgr:getFlagFromLocalByKey(
            CollectCardConst.LocalCacheKey.FRIEND_SELECT_EXCHANGE_ENABLED
        ) == true
        or false

    self:registerKeyboardEvents()
    self:reloadFriends()
end

function CollectCardFriendSelectPanelVM:reloadFriends()
    self.friendRows = {}
    self.friendRowByUid = {}
    for _, friend in ipairs(self._mgr:getAllFriendInfo()) do
        local profile = friend:getProfile()
        local uid = tostring(friend:getUid())
        local lastLoginTime = friend:getLastLoginTime()
        local row = {
            uid = uid,
            profile = profile,
            name = nameDecode(profile.name),
            xxlId = tostring(profile.xxlId),
            lastLoginTime = lastLoginTime,
            topLevel = friend:getTopLevelId(),
            onlineText = self.formatOnlineText(lastLoginTime, friend:isOnline(), TimeKit:timeInSec()),
            selectable = true,
        }
        table.insert(self.friendRows, row)
        self.friendRowByUid[uid] = row
    end
    table.sort(self.friendRows, function(left, right)
        if left.topLevel ~= right.topLevel then
            return left.topLevel > right.topLevel
        end
        return left.uid < right.uid
    end)
    self:refreshFriendRows(false)
end

function CollectCardFriendSelectPanelVM:refreshFriendRows(updateView)
    local keyword = self.searchText
    self.visibleRows = {}
    for _, row in ipairs(self.friendRows) do
        if keyword == "" or row.xxlId == keyword then
            row.selected = self.selectedUidSet[row.uid] == true
            table.insert(self.visibleRows, row)
        end
    end
    if updateView == false then return end
    self:callViewFunc("updateFriendRows", self.visibleRows)
end

function CollectCardFriendSelectPanelVM:onSearchTextChanged(keyword)
    self.searchText = self.normalizeKeyword(keyword)
    if self.searchText == "" then
        self:refreshFriendRows()
    end
    return self.searchText
end

function CollectCardFriendSelectPanelVM:onSearchTapped()
    if #self.searchText < 9 or #self.searchText > 11 then
        CommonTip:showTip("请输入9~11位消消乐号~")
        return
    end
    self:refreshFriendRows()
end

function CollectCardFriendSelectPanelVM:onSearchInputTapped()
    if self.keyboardVM and not self.keyboardVM.isDisposed then return end
    local NumberKeyboardPanelVM = require "amf.middleware.ui.kit.panel.other.NumberKeyboardPanelVM"
    self.keyboardVM = NumberKeyboardPanelVM:create()
    self.keyboardId = self.keyboardVM:getId()
    self.keyboardVM:popout()
end

function CollectCardFriendSelectPanelVM:onKeyboardInput(evt)
    local data = evt and evt.data or {}
    if self.keyboardId ~= data.id then return end
    local text = self.searchText or ""
    if data.key == "BACK" then
        text = string.sub(text, 1, math.max(#text - 1, 0))
    else
        text = self.normalizeKeyword(text .. tostring(data.key or ""))
    end
    self:onSearchTextChanged(text)
    self:callViewFunc("updateSearchText", self.searchText)
end

function CollectCardFriendSelectPanelVM:onKeyboardHide(evt)
    local data = evt and evt.data or {}
    if data.id and self.keyboardId ~= data.id then return end
    self.keyboardVM = nil
    self.keyboardId = nil
    self:callViewFunc("setSearchFocused", false)
end

function CollectCardFriendSelectPanelVM:registerKeyboardEvents()
    UIEventCenter:register(UIEvent.Keyboard.INPUT, self.onKeyboardInput, self)
    UIEventCenter:register(UIEvent.Keyboard.HIDE, self.onKeyboardHide, self)
end

function CollectCardFriendSelectPanelVM:unregisterKeyboardEvents()
    UIEventCenter:unregister(UIEvent.Keyboard.INPUT, self.onKeyboardInput)
    UIEventCenter:unregister(UIEvent.Keyboard.HIDE, self.onKeyboardHide)
end

function CollectCardFriendSelectPanelVM:onFriendTapped(uid)
    local changes = {}

    local function setSelected(changedUid, selected)
        self.selectedUidSet[changedUid] = selected and true or nil
        self.friendRowByUid[changedUid].selected = selected
        table.insert(changes, {uid = changedUid, selected = selected})
    end

    if self.selectedUidSet[uid] then
        setSelected(uid, false)
        for index, selectedUid in ipairs(self.selectedUids) do
            if selectedUid == uid then
                table.remove(self.selectedUids, index)
                break
            end
        end
    elseif self.mode == CollectCardConst.FriendSelectMode.ASK then
        if #self.selectedUids >= MAX_ASK_SELECTION then
            CommonTip:showTip("最多选择4名好友哦~")
            return
        end
        setSelected(uid, true)
        table.insert(self.selectedUids, uid)
    else
        local previousUid = self.selectedUids[1]
        if previousUid then setSelected(previousUid, false) end
        self.selectedUids = {uid}
        setSelected(uid, true)
    end
    self:callViewFunc("updateSelection", changes, #self.selectedUids > 0, #self.selectedUids)
end

function CollectCardFriendSelectPanelVM:onExchangeTapped()
    if self.mode ~= CollectCardConst.FriendSelectMode.GIVE then return end
    self.exchangeEnabled = not self.exchangeEnabled
    self._mgr:setFlagToLocalByKey(
        CollectCardConst.LocalCacheKey.FRIEND_SELECT_EXCHANGE_ENABLED,
        false,
        self.exchangeEnabled
    )
    self:callViewFunc("updateExchangeState", self.exchangeEnabled)
end

function CollectCardFriendSelectPanelVM:onExchangeInfoTapped()
    self:callViewFunc("showExchangeTip")
end

function CollectCardFriendSelectPanelVM:onContinueTapped()
    if #self.selectedUids == 0 or self:isLocked() then return end

    local payload = {
        mode = self.mode,
        cardId = self.cardId,
        panelId = self.panelId,
        sourcePanelId = self.sourcePanelId,
        targetUids = table.simpleClone(self.selectedUids),
        exchangeEnabled = self.mode == CollectCardConst.FriendSelectMode.GIVE and self.exchangeEnabled or false,
    }
    if self.mode == CollectCardConst.FriendSelectMode.GIVE then
        payload.targetProfile = table.simpleClone(self.friendRowByUid[self.selectedUids[1]].profile)
    end

    self:lockWithoutBlock()
    local result = self.onContinue(payload)
    return result:next(function(value)
        self:unlockWithoutBlock()
        if self.isDisposed then return value end

        local afterSuccessClose = self.afterSuccessClose
        self:close()
        safeRunCall(afterSuccessClose, value, payload)
        return value
    end, function(error)
        self:unlockWithoutBlock()
        if not self.isDisposed then CommonTip:showErrorTip(error) end
        return deferred.error(error)
    end)
end

function CollectCardFriendSelectPanelVM:secondLoadCompleted()
    self:callViewFunc("initFriendSelectView", {
        title = self.mode == CollectCardConst.FriendSelectMode.ASK and "求助卡片" or "选择好友",
        exchangeVisible = self.mode == CollectCardConst.FriendSelectMode.GIVE,
        exchangeEnabled = self.exchangeEnabled,
        continueEnabled = #self.selectedUids > 0,
        selectedCount = #self.selectedUids,
        maxSelection = MAX_ASK_SELECTION,
        cardName = self.cardName,
    })
end

function CollectCardFriendSelectPanelVM:onEnterPanelRun()
    self:refreshFriendRows()
    if self.mode == CollectCardConst.FriendSelectMode.ASK then
        self._mgr:dcActPlug():dcFriendHelpShow(self.panelId, #self.friendRows)
    end
    local key = CollectCardConst.LocalCacheKey.FRIEND_SELECT_EXCHANGE_TIP_SHOWN
    if self.mode == CollectCardConst.FriendSelectMode.GIVE and not self._mgr:getFlagFromLocalByKey(key) then
        self._mgr:setFlagToLocalByKey(key, false, true)
        self:callViewFunc("showExchangeTip")
    end
end

function CollectCardFriendSelectPanelVM:onCloseBtnTapped()
    if self.keyboardVM and not self.keyboardVM.isDisposed then
        self.keyboardVM:close()
    end
    self._mgr:playCommonEffectAndHaptic()
    UeAMFBasePanelVM.onCloseBtnTapped(self)
end

function CollectCardFriendSelectPanelVM:recycle()
    self:unregisterKeyboardEvents()
    UeAMFBasePanelVM.recycle(self)
end

return CollectCardFriendSelectPanelVM
