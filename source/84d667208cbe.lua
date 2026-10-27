local IceBreakingGiftViewVM = class("IceBreakingGiftViewVM", UeAMFBasePanelVM)

function IceBreakingGiftViewVM:_createPanel(...)
    local panel = require_debug 'amf.feature.giftpackage.module.singleicon.icebreaking.view.IceBreakingGiftView'
    return panel:create(IceBreakingGiftViewVM, ...)
end

function IceBreakingGiftViewVM:init(commonGiftData, delegate, autoPopup)
    self.commonGiftData = commonGiftData
    self.endTime = commonGiftData:getEndTime()
    ---@type IceBreakingGiftModule
    self.delegate = delegate
    self.autoPopup = autoPopup
    _G.amfEC:registerNormal(NormalEvent.PASS_DAY, self.onPassDay, self)
end

function IceBreakingGiftViewVM:recycle()
    _G.amfEC:unregisterNormal(NormalEvent.PASS_DAY, self.onPassDay)
    UeAMFBasePanelVM.recycle(self)
end

function IceBreakingGiftViewVM:onEnterPanelRun()
    UeAMFBasePanelVM.onEnterPanelRun(self)
    self.delegate:dcShow()
    self.delegate:setUserOpened()
    self:callViewFunc("onEnterPanelRun")
end

function IceBreakingGiftViewVM:onBuyClick()
    self:lock()
    self.delegate:requestBuy(function ()
        if self.isDisposed then return end
        self:close()
    end, function ()
        if self.isDisposed then return end
        self:unlock()
    end)

end

function IceBreakingGiftViewVM:onPassDay()
    CommonTip:showTip("新的一天开始了，数据已更新，请尝试重进活动~")
    self:close()
end

function IceBreakingGiftViewVM:test()
    IceBreakingGiftViewVM:create({}):popout()
end


return IceBreakingGiftViewVM