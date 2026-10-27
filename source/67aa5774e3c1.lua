local ShowRewardsPanelVM = require "amf.middleware.ui.kit.panel.reward.ShowRewardsPanelVM"
local CollectCardEventCenter = require "amf.feature.localactivity.collectcard.event.CollectCardEventCenter"

local OpenCardFlowPanelVM = class("OpenCardFlowPanelVM", ShowRewardsPanelVM)
local Builder = newBuilder(OpenCardFlowPanelVM)
local OpenCardFlowIdSeed = 0


function OpenCardFlowPanelVM:_createPanel(...)
    local OpenCardFlowPanel = require_debug "amf.feature.localactivity.collectcard.view.OpenCardFlowPanel"
    return OpenCardFlowPanel:create(OpenCardFlowPanelVM, ...)
end

function OpenCardFlowPanelVM:init(delegate)
    ShowRewardsPanelVM.init(self, delegate)
    OpenCardFlowIdSeed = OpenCardFlowIdSeed + 1
    self.openCardFlowId = OpenCardFlowIdSeed
    self.totalNum = #self.rewards
    self:registerEvent()
end

function OpenCardFlowPanelVM:isMyOpenCardAnimEvent(event)
    local data = event:getData() or {}
    printx(33, "OpenCardFlowPanelVM:isMyOpenCardAnimEvent, self.openCardFlowId:", self.openCardFlowId, "data.openCardFlowId:", data.openCardFlowId)
    return data.openCardFlowId == self.openCardFlowId
end

function OpenCardFlowPanelVM:registerEvent()
    local onCardPackAnimShowFunc = function(context, ...)
        self.onCardPackAnimShow(context, ...) 
    end
    CollectCardEventCenter:register(CollectCardEvent.CARD_PACK_ANIM_SHOW, onCardPackAnimShowFunc, self)
    self.onCardPackAnimShowFunc = onCardPackAnimShowFunc

    local onCardPackAnimOpenFunc = function(context, ...)
        self.onCardPackAnimOpen(context, ...) 
    end
    CollectCardEventCenter:register(CollectCardEvent.CARD_PACK_ANIM_OPEN, onCardPackAnimOpenFunc, self)
    self.onCardPackAnimOpenFunc = onCardPackAnimOpenFunc

    local onCardPackAnimOpeningFunc = function(context, ...)
        self.onCardPackAnimOpening(context, ...) 
    end
    CollectCardEventCenter:register(CollectCardEvent.CARD_PACK_ANIM_OPENING, onCardPackAnimOpeningFunc, self)
    self.onCardPackAnimOpeningFunc = onCardPackAnimOpeningFunc

    local onCardPackAnimStopAtLastFunc = function(context, ...)
        self.onCardPackAnimStopAtLast(context, ...) 
    end
    CollectCardEventCenter:register(CollectCardEvent.CARD_PACK_ANIM_STOP_AT_LAST, onCardPackAnimStopAtLastFunc, self)
    self.onCardPackAnimStopAtLastFunc = onCardPackAnimStopAtLastFunc

    local onCardPackAnimSkipFunc = function(context, ...)
        self.onCardPackAnimSkip(context, ...) 
    end
    CollectCardEventCenter:register(CollectCardEvent.CARD_PACK_ANIM_SKIP, onCardPackAnimSkipFunc, self)
    self.onCardPackAnimSkipFunc = onCardPackAnimSkipFunc

    local onCardPackAnimFinishFunc = function(context, ...)
        self.onCardPackAnimFinish(context, ...) 
    end
    CollectCardEventCenter:register(CollectCardEvent.CARD_PACK_ANIM_FINISH, onCardPackAnimFinishFunc, self)
    self.onCardPackAnimFinishFunc = onCardPackAnimFinishFunc
end

function OpenCardFlowPanelVM:unRegisterEvent()
    CollectCardEventCenter:unregister(CollectCardEvent.CARD_PACK_ANIM_SHOW, self.onCardPackAnimShowFunc)
    CollectCardEventCenter:unregister(CollectCardEvent.CARD_PACK_ANIM_OPEN, self.onCardPackAnimOpenFunc)
    CollectCardEventCenter:unregister(CollectCardEvent.CARD_PACK_ANIM_OPENING, self.onCardPackAnimOpeningFunc)
    CollectCardEventCenter:unregister(CollectCardEvent.CARD_PACK_ANIM_STOP_AT_LAST, self.onCardPackAnimStopAtLastFunc)
    CollectCardEventCenter:unregister(CollectCardEvent.CARD_PACK_ANIM_SKIP, self.onCardPackAnimSkipFunc)
    CollectCardEventCenter:unregister(CollectCardEvent.CARD_PACK_ANIM_FINISH, self.onCardPackAnimFinishFunc)
end

function OpenCardFlowPanelVM:onCloseBtnTapped()
    -- 先看流程是否已经走完
    CollectCardEventCenter:notifyEnsureCallback(CollectCardEvent.CARD_PACK_FLOW_BACK_CLICKED, {
        openCardFlowId = self.openCardFlowId,
    }, nil, function()
        if self.isDisposed then return end
        local mgr = _G.amfBean("CollectCardManager")
        local Const = mgr:getConst()
        mgr:playEffect(Const.Sound.CLICK_COMMON_01)
        mgr:playHaptics(Const.Haptics.BUTTON_NORMAL)
        ShowRewardsPanelVM.onCloseBtnTapped(self)
    end)
end

function OpenCardFlowPanelVM:close()
    self:_close()
end

function OpenCardFlowPanelVM:recycle()
    self:unRegisterEvent()
    ShowRewardsPanelVM.recycle(self)
end

function OpenCardFlowPanelVM:onEnterPanelRun()
    printx(33, "OpenCardFlowPanelVM:onEnterPanelRun")
    local deferred = require "amf.script.sugar.deferred"
    deferred.success()
    :next(function()
        printx(33, "OpenCardFlowPanelVM:onEnterPanelRun 1")
        if self.isDisposed then return deferred.error() end
        local d = deferred.new()
        self:callViewFuncWithCallback("showBubbleAndLight", function()
            d:resolve()
        end)
        return d
    end)
    :next(function()
        printx(33, "OpenCardFlowPanelVM:onEnterPanelRun 2")
        if self.isDisposed then return deferred.error() end
        local d = deferred.new()
        self:callViewFuncWithCallback("showTitle", function()
            d:resolve()
        end)
        return d
    end)
    :next(function()
        printx(33, "OpenCardFlowPanelVM:onEnterPanelRun 3")
        if self.isDisposed then return deferred.error() end
        local d = deferred.new()
        self:callViewFuncWithCallback("showCloseBtn")
        d:resolve()
        return d
    end)
end

function OpenCardFlowPanelVM:onKeyBackClicked()
    CollectCardEventCenter:notifyEnsureCallback(CollectCardEvent.CARD_PACK_FLOW_BACK_CLICKED, {
        openCardFlowId = self.openCardFlowId,
    }, nil, function()
        if self.isDisposed then return end
        self:close()
    end)
end

function OpenCardFlowPanelVM:onCardPackAnimShow(event)
    if self.isDisposed then return end
    if not self:isMyOpenCardAnimEvent(event) then return end
end

function OpenCardFlowPanelVM:onCardPackAnimOpen(event)
    if self.isDisposed then return end
    if not self:isMyOpenCardAnimEvent(event) then return end
end

function OpenCardFlowPanelVM:onCardPackAnimOpening(event)
    if self.isDisposed then return end
    if not self:isMyOpenCardAnimEvent(event) then return end
    local data = event:getData()
    local openingIdx = data.openingIdx
    local totalNum = self.totalNum
    if totalNum == 1 then
        self:callViewFunc("setSubTitleStr", "恭喜你获得以下卡片")
    else
        self:callViewFunc("setSubTitleStr", string.format("开启第%d/%d个卡包，获得以下卡片", openingIdx, totalNum))
    end
end

function OpenCardFlowPanelVM:onCardPackAnimStopAtLast(event)
    if self.isDisposed then return end
    if not self:isMyOpenCardAnimEvent(event) then return end
end

function OpenCardFlowPanelVM:onCardPackAnimSkip(event)
    if self.isDisposed then return end
    if not self:isMyOpenCardAnimEvent(event) then return end
    local data = event:getData() or {}
    local skippedNum = data.skippedNum or self.totalNum
    self:callViewFunc("setSubTitleStr", string.format("开启了剩余%d个卡包，获得以下卡片", skippedNum))
end

function OpenCardFlowPanelVM:onCardPackAnimFinish(event)
    printx(33, "OpenCardFlowPanelVM:onCardPackAnimFinish", self.isDisposed) --- IGNORE ---
    if self.isDisposed then return end
    if not self:isMyOpenCardAnimEvent(event) then return end
    printx(33, "OpenCardFlowPanelVM:onCardPackAnimFinish 关闭开包界面") --- IGNORE ---
    self:_close()
end

return OpenCardFlowPanelVM
