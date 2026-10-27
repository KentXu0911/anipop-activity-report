local CollectCardEventCenter = require "amf.feature.localactivity.collectcard.event.CollectCardEventCenter"

---@class CC_MainPanelVM : UeAMFBasePanelVM
local MainPanelVM = class("MainPanelVM", UeAMFBasePanelVM)

--region Builder

local Builder = newBuilder(MainPanelVM)

function Builder:ctor()
    self.userClick = false

end

function Builder:setUserClick(userClick)
    self.userClick = userClick
    return self
end



--endregion


function MainPanelVM:_createPanel(...)
    local panel = force_require 'amf.feature.localactivity.collectcard.view.MainPanel'
    return panel:create(MainPanelVM, ...)
end

function MainPanelVM:init(delegate)
    -- self.allowBackKeyTap = false
    self.userClick = delegate.userClick
    ---@type CollectCardManager
    self._mgr = _G.amfBean("CollectCardManager")
end

function MainPanelVM:onEnterPanelRun()
    UeAMFBasePanelVM.onEnterPanelRun(self)
    self:registerEvent()
    local t1 = self.userClick and "vine_icon" or "popoup"
    self.panelId = UICreateUtil:getPanelId("MainPanelVM")
    self._mgr:dcActPlug():dcMainPanelShow(t1, self.panelId)

    --新手引导
    local isNewGuide = self._mgr:isMainPanelGuide()
    -- isNewGuide = true
    if isNewGuide then
        self:lock()
        self.allowBackKeyTap = false
        self:callViewFunc("onPlayNewGuide", function ()
            self:unlock()
            self.allowBackKeyTap = true

        end)
    end
end

function MainPanelVM:onCloseBtnTapped()
    self._mgr:playCommonEffectAndHaptic()
    UeAMFBasePanelVM.onCloseBtnTapped(self)

end

function MainPanelVM:recycle()
    self:unregisterEvent()
    UeAMFBasePanelVM.recycle(self)

end


function MainPanelVM:registerEvent()
    CollectCardEventCenter:register(CollectCardEvent.ON_UPDATE_MAIN_PANEL, self.onUpdateTableView, self)
    CollectCardEventCenter:register(CollectCardEvent.CARD_NUM_UPDATE, self.onCardNumUpdate, self)
    CollectCardEventCenter:register(CollectCardEvent.SWAP_DATA_UPDATED, self.onUpdateSwapData, self)
    CollectCardEventCenter:register(CollectCardEvent.ON_STARNUM_REDPOINT, self.onUpdateStarRedPoint, self)
    CollectCardEventCenter:register(CollectCardEvent.SETTLE_END_SWITCH_ROUND, self.onUpdateSelfUI, self)
    -- _G.amfEC:registerNormal(NormalEvent.PASS_DAY, self.onPassDay, self)

end

function MainPanelVM:unregisterEvent()
    CollectCardEventCenter:unregister(CollectCardEvent.ON_UPDATE_MAIN_PANEL, self.onUpdateTableView, self)
    CollectCardEventCenter:unregister(CollectCardEvent.CARD_NUM_UPDATE, self.onCardNumUpdate, self)
    CollectCardEventCenter:unregister(CollectCardEvent.SWAP_DATA_UPDATED, self.onUpdateSwapData, self)
    CollectCardEventCenter:unregister(CollectCardEvent.ON_STARNUM_REDPOINT, self.onUpdateStarRedPoint, self)
    CollectCardEventCenter:unregister(CollectCardEvent.SETTLE_END_SWITCH_ROUND, self.onUpdateSelfUI, self)
    -- _G.amfEC:unregisterNormal(NormalEvent.PASS_DAY, self.onPassDay)
end


function MainPanelVM:onUpdateTableView()
    if self.isDisposed then return end
    printx(48, "更新数量")
    self:callViewFunc("onUpdateTableView")

end

function MainPanelVM:onCardNumUpdate()
    if self.isDisposed then return end
    self:callViewFunc("onCardNumUpdate")
end

function MainPanelVM:onUpdateSwapData()
    if self.isDisposed then return end
    self:callViewFunc("updateStarNum")
end

function MainPanelVM:onUpdateStarRedPoint()
    if self.isDisposed then return end
    self:callViewFunc("onUpdateStarRedPoint")
end

function MainPanelVM:onUpdateSelfUI()
    if self.isDisposed then return end
    self:callViewFunc("onUpdateSelfUI")
end

-- function MainPanelVM:onPassDay(evt)
--     CommonTip:showTip("新的一天开始了，数据已更新，请尝试重进活动~")
--     self:close()
-- end

function MainPanelVM:test()
    MainPanelVM:create({}):popout()
end


return MainPanelVM
