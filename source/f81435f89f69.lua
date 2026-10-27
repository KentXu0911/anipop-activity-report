local WaterfallMarketingPanelVM = class("WaterfallMarketingPanelVM", UeAMFBasePanelVM)

function WaterfallMarketingPanelVM:_createPanel(...)
    local panel = force_require 'amf.feature.localactivity.waterfallgift.view.WaterfallMarketingPanel'
    return panel:create(WaterfallMarketingPanelVM, ...)
end

function WaterfallMarketingPanelVM:init(delegate)
    delegate = delegate or {}
    self.dyOfferInfo = delegate.dyOfferInfo
    self.nextCallback = delegate.nextCallback
end

function WaterfallMarketingPanelVM:firstLoadCompleted()
    self:callViewFunc("updateByDyOfferInfo", self.dyOfferInfo)
end

function WaterfallMarketingPanelVM:onConfirmTapped()
    _G.amfBean("WaterfallGiftManager"):onTouchIcon(5, self.nextCallback)
    self.nextCallback = nil
    self:onCloseBtnTapped()
end

function WaterfallMarketingPanelVM:onCloseBtnTapped()
    UeAMFBasePanelVM.onCloseBtnTapped(self)
    if self.nextCallback then
        self.nextCallback()
    end
end

function WaterfallMarketingPanelVM:test()
    WaterfallMarketingPanelVM:create({}):popout()
end

return WaterfallMarketingPanelVM