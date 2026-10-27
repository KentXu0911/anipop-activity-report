local CollectCardEventCenter = require "amf.feature.localactivity.collectcard.event.CollectCardEventCenter"
local StartExchangePanelVM = class("StartExchangePanelVM", UeAMFBasePanelVM)

function StartExchangePanelVM:_createPanel(...)
    local StartPanel = force_require "amf.feature.localactivity.collectcard.view.StartExchangePanel"
    return StartPanel:create(StartExchangePanelVM, ...)
end


function StartExchangePanelVM:init(...)
    UeAMFBasePanelVM.init(self, ...)
    --printx(48, "同一个实例只会走一次，初始化每次都不会变的数据和响应式结构", ...)
    ---@type CollectCardManager
    self._mgr = _G.amfBean("CollectCardManager")
    -- -- 响应式数据
    -- self.data = _G.shallowReactive(self, {
    --     count = 0
    -- })
end

function StartExchangePanelVM:reuse(...)
    --printx(48, "第一次创建不会走，每次面板从缓存内被重新使用都会走.先调用父类的reuse再处理自己的逻辑", ...)
    AMFBasePanelVM.reuse(self, ...)
end

function StartExchangePanelVM:firstLoadCompleted()
    --printx(48, "第一步资源加载完成，每次面板“创建”都会走")

end

function StartExchangePanelVM:secondLoadCompleted()
    --printx(48, "第二步资源加载完成，每次面板“创建”都会走")
end

function StartExchangePanelVM:onEnterPanelRun()
    --printx(48, "这里是进入主面板流程，走到这里意味着第二步加载完成了")
    self:registerEvent()
    local panelId = UICreateUtil:getPanelId("StartExchangePanelVM")
    self._mgr:dcActPlug():dcExchangeShopPanelShow(panelId)
end

function StartExchangePanelVM:onCloseBtnTapped()
    self._mgr:playCommonEffectAndHaptic()
    UeAMFBasePanelVM.onCloseBtnTapped(self)
end

function StartExchangePanelVM:recycle()
    --printx(48, "每次面板被“释放”时都会调用.先处理自己的逻辑再调用父类的recycle")
    self:unregisterEvent()
    UeAMFBasePanelVM.recycle(self)
end


function StartExchangePanelVM:registerEvent()
    CollectCardEventCenter:register(CollectCardEvent.CARD_NUM_UPDATE, self.onUpdateStarNum, self)
end

function StartExchangePanelVM:unregisterEvent()
    CollectCardEventCenter:unregister(CollectCardEvent.CARD_NUM_UPDATE, self.onUpdateStarNum, self)
end


function StartExchangePanelVM:onUpdateStarNum()
    self:callViewFunc("onUpdateStarNum")

end

function StartExchangePanelVM:test()
    local vm = StartExchangePanelVM:create()
    vm:popout(_G.UIConst.PanelPopout.PUSH, true)
end

return StartExchangePanelVM
