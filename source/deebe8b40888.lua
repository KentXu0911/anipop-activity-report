---@class ShopRewardStoreHeaderView : Node
local Res = require "amf.feature.localactivity.shopreward.const.Res"
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local ShopRewardEventCenter = require "amf.feature.localactivity.shopreward.event.ShopRewardEventCenter"
local StoreEventCenter = require "amf.feature.store.event.StoreEventCenter"

local ShopRewardStoreHeaderView = class("ShopRewardStoreHeaderView", Node)
local bubbleCfg = {
    key = {
        init = {},
        actions = {
            {time = 20/30, scale = 0.94},
            {time = 20/30, scale = 1},
            {time = 20/30, scale = 0.94},
            {time = 20/30, scale = 1},
            {time = 10/30, scale = 1.1},
            {time = 25/30, scale = 1},
            {delay = 10/30, time = 25/30, scale = 1}
        }
    }
}

function ShopRewardStoreHeaderView:create(params)
    local view = self.new(CCNode:create())
    view:init(params)
    return view
end

function ShopRewardStoreHeaderView:init(params)
    self.delayBuild = params and params.delayBuild == true
    self:initData()
    if not self.delayBuild then
        self:ensureBuilt()
    end
end

function ShopRewardStoreHeaderView:ensureBuilt()
    if self.isDisposed or self.isBuilt then return end
    self.isBuilt = true
    self:loadRes()
end

function ShopRewardStoreHeaderView:onResLoaded()
    if self.isDisposed then return end
    self:buildUI()
    self:setActionNodesVisible(false)
    self:initCountDown()
    self:initDesc()
    self:bindClickHandler()
    self:registerEvents()
    self:playBtnAnim()
    if self.pendingStoreGuideAnimCallback then
        local callback = self.pendingStoreGuideAnimCallback
        self.pendingStoreGuideAnimCallback = nil
        self:playStoreGuideAnim(callback)
    end
end

function ShopRewardStoreHeaderView:loadRes()
    if not EnvUtil:isMiniGame() then
        self:onResLoaded()
        return
    end

    _G.amfBean("AssetsUtil"):loadMiniFiles(Res:getStoreHeaderResList(), true):next(function()
        self:onResLoaded()
    end)
end

function ShopRewardStoreHeaderView:playBtnAnim()
    if not self.goBtn then return end
    local ActionCreator = require "amf.middleware.ui.util.ActionCreator"
    ActionCreator.new(bubbleCfg, function(key)
        return self.goBtn
    end):setRepeatForever(true):execute()
end

function ShopRewardStoreHeaderView:playStoreGuideAnim(finishCallback)
    self:ensureBuilt()
    if not self.root or not self.ui then
        self.pendingStoreGuideAnimCallback = finishCallback
        return
    end

    self:setStoreGuideActive(true)

    local cfg = {
        key = {
            init = {
               scale = 1.95,
            },
            actions = {
                {time = 4/30, scale = 2},
                {time = 3/30, scale = 0.91},
                {time = 3/30, scale = 1},
            }
        },
        key2 = {
            init = {
                opacity = 0
            },
            actions = {
                {time = 7/30, opacity = 255}
            }
        }
    }
    local ActionCreator = require "amf.middleware.ui.util.ActionCreator"
    ActionCreator.new(cfg, function(key)
        return self.root
    end):execute()
    setTimeOut(function()
        if self.isDisposed then return end
        local spine = UICreateUtil:createSpine(Res.Spine.HEADER_SAO)
        self.ui:addChild(spine)
        spine:setPositionXY(367, 84)
        spine:playOnceAndDispose("appear")
    end, 7/30)
    setTimeOut(function()
        if self.isDisposed then return end
        safeRunCall(finishCallback)
    end, 0.5)
end

function ShopRewardStoreHeaderView:initData()
    self.mgr = _G.amfBean("ShopRewardManager")
end

function ShopRewardStoreHeaderView:buildUI()
    UICreateUtil:loadPlist(Res.Plist.SHOPHEADER)
    UICreateUtil:loadSpineRes(Res.Spine.HEADER_ANI)
    UICreateUtil:loadSpineRes(Res.Spine.HEADER_SAO)
    local uiData = require "amf.feature.localactivity.shopreward.view.uisource.ShopRewardHeaderNode_UI"
    self.ui = UIBuilder:buildUI(uiData, self)
    self:addChild(self.ui)

    local spine = UICreateUtil:createSpine(Res.Spine.HEADER_ANI)
    LayoutUtil:centerReplaceBy(self.prizeImg, spine)
    LayoutUtil:move(spine, 0, -10)
    spine:playLoop("idle")
end

function ShopRewardStoreHeaderView:initDesc()
    if not self.richText then return end
    local remainBuyCount = self.mgr and self.mgr:getRemainBuyCount() or 0
    local text = string.format("<outline color=#AA1117FF width=3>优惠券礼包加赠风车币！\n共可买<color=#FFF33BFF> %s 款</color>，每款限 1 次", remainBuyCount)
    self.richText:setString(text)
end

function ShopRewardStoreHeaderView:registerEvents()
    ShopRewardEventCenter:register(ShopRewardEvent.BUY_COUNT_REFRESH, self.onBuyCountRefresh, self)
    StoreEventCenter:register(_G.StoreEvent.STORE_SCROLL_SNAPSHOT, self.onStoreScrollSnapshot, self)
end

function ShopRewardStoreHeaderView:onBuyCountRefresh()
    if self.isDisposed then return end
    self:initDesc()
end

function ShopRewardStoreHeaderView:unregisterEvents()
    ShopRewardEventCenter:unregister(ShopRewardEvent.BUY_COUNT_REFRESH, self.onBuyCountRefresh, self)
    StoreEventCenter:unregister(_G.StoreEvent.STORE_SCROLL_SNAPSHOT, self.onStoreScrollSnapshot, self)
end

function ShopRewardStoreHeaderView:onStoreScrollSnapshot(event)
    if self.isDisposed then return end
    if self.isStoreGuideActive then return end

    local data = event and event:getData() or {}
    local visible = self:shouldShowActionNodes(data)
    self:setActionNodesVisible(visible)
end

function ShopRewardStoreHeaderView:applyActionNodesVisible(visible)
    if self.timeNode then
        self.timeNode:setVisible(visible)
    end
    if self.goBtn then
        self.goBtn:setVisible(visible)
    end
end

function ShopRewardStoreHeaderView:setActionNodesVisible(visible)
    if self.actionNodesVisible == visible then return end
    self.actionNodesVisible = visible
    self:applyActionNodesVisible(self.isStoreGuideActive and false or visible)
end

function ShopRewardStoreHeaderView:setStoreGuideActive(isActive)
    self.isStoreGuideActive = isActive == true

    if self.isStoreGuideActive then
        self:applyActionNodesVisible(false)
    else
        self.pendingStoreGuideAnimCallback = nil
        StoreEventCenter:dispatch(_G.StoreEvent.STORE_SCROLL_SNAPSHOT_REQUEST)
    end
end

function ShopRewardStoreHeaderView:shouldShowActionNodes(data)
    local viewportBounds = data and data.viewportBounds
    local packageLayer = data and data.packageLayer
    if not viewportBounds or not packageLayer or packageLayer.isDisposed then
        return true
    end
    if not self:hasTargetStorePackage(packageLayer) then
        return false
    end

    return not self:hasShopRewardGiftInViewportRange(packageLayer, viewportBounds)
end

function ShopRewardStoreHeaderView:hasTargetStorePackage(packageLayer)
    local targetPackageId = self.mgr and self.mgr:getTargetStorePackageId()
    if not targetPackageId then return false end
    if packageLayer.findGiftViewByPackageId then
        local giftView = packageLayer:findGiftViewByPackageId(targetPackageId)
        return self:isVisibleShopRewardGiftView(giftView)
    end
    return true
end

function ShopRewardStoreHeaderView:hasShopRewardGiftInViewportRange(packageLayer, viewportBounds)
    local rangeMinY = viewportBounds:getMinY()
    local rangeMaxY = viewportBounds:getMaxY()

    local giftViews = packageLayer.getGiftViews and packageLayer:getGiftViews() or {}
    for _, giftView in ipairs(giftViews) do
        if self:isVisibleShopRewardGiftView(giftView) then
            local bounds = giftView:getGroupBounds()
            if bounds:getMaxY() < rangeMaxY and bounds:getMinY() > rangeMinY then
                return true
            end
        end
    end
    return false
end

function ShopRewardStoreHeaderView:isVisibleShopRewardGiftView(giftView)
    return giftView
        and giftView.isShopRewardStoreView
        and not giftView.isDisposed
        and giftView:getParent()
        and giftView:isVisible()
end

function ShopRewardStoreHeaderView:initCountDown()
    self:removeCountDownTimer()

    self.countDownTimer = TimerUtil.addAlarm(function()
        if self.isDisposed then return end
        self:updateCountDown()
    end, 1, 0)
    self:updateCountDown()
end

function ShopRewardStoreHeaderView:updateCountDown()
    local mainEndTime = self.mgr:getMainEndTime() or 0
    local ret = TimeUtil:timeFormatVer1({
        endTimeInSec = mainEndTime or 0,
    })
    if ret.retString == "" then
        ret.retString = "已结束"
    end

    if self.timeText then
        self.timeText:setString(ret.retString)
    end

    if ret.isReach then
        self:removeCountDownTimer()
        return
    end
end

function ShopRewardStoreHeaderView:removeCountDownTimer()
    if self.countDownTimer then
        TimerUtil.removeAlarm(self.countDownTimer)
        self.countDownTimer = nil
    end
end

function ShopRewardStoreHeaderView:setClickHandler(handler)
    self.clickHandler = handler
    self:bindClickHandler()
end

function ShopRewardStoreHeaderView:bindClickHandler()
    if not self.ui or not self.goBtn or not self.clickHandler then return end
    if not self.goBtn._hasSetTouch then
        self.goBtn:setTouchHandler(preventContinuousClick(self.clickHandler))
        self.goBtn._hasSetTouch = true
    end
end

function ShopRewardStoreHeaderView:dispose()
    self:unregisterEvents()
    UICreateUtil:unloadPlist(Res.Plist.SHOPHEADER)
    UICreateUtil:unloadSpineRes(Res.Spine.HEADER_ANI)
    UICreateUtil:unloadSpineRes(Res.Spine.HEADER_SAO)
    self:removeCountDownTimer()
    Node.dispose(self)
end

return ShopRewardStoreHeaderView
