local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")
local ClimbTowerEventCenter = require "amf.feature.localactivity.climbtower.event.ClimbTowerEventCenter"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"
local StoreEventCenter = require "amf.feature.store.event.StoreEventCenter"
local deferred = require "amf.script.sugar.deferred"

local ClimbTowerManager = class("ClimbTowerManager", BaseFeatureManager)

local RES_LABEL = "climbtower"

function ClimbTowerManager:_getConstPath()
    return "amf.feature.localactivity.climbtower.const.ClimbTowerConst"
end

function ClimbTowerManager:_getModelPath()
    return "amf.feature.localactivity.climbtower.model.ClimbTowerModel"
end

function ClimbTowerManager:_getExtraPlugsConfigList()
    return {
        {
            key = "Download",
        },
        {
            key = "Panel",
        },
        {
            key = "Rewards",
        },
        {
            key = "DC",
            path = {
                plugPath = "amf.feature.localactivity.climbtower.dc.ClimbTowerDC",
            }
        },
        {
            key = "LocalPush",
            path = {
                plugPath = "amf.feature.localactivity.climbtower.plug.LocalPush",
                const    = self:_getConstPath(),
            },
        },
    }
end

function ClimbTowerManager:_init()
    self:initActInfo()
    self:registerEvents()
end

function ClimbTowerManager:setAutoPopupMgr(manager)
    self.autoPopupMgr = manager
    self:_registerAutoPopup()
end

function ClimbTowerManager:setStoreManager(manager)
    self.storeManager = manager
end

function ClimbTowerManager:setActivityMgr(activityMgr)
    self.activityMgr = activityMgr
end

function ClimbTowerManager:initActInfo()
    if not self.actPlug then return end
    local actInfo = self.actPlug:getActInfo()
    self:getModel():syncActInfo(actInfo)
    if actInfo then self:loadRes() end
end

function ClimbTowerManager:updateData(data, fromServer)
    if not data then return end
    self:getModel():assignData(data)
    self:updateTipView()
end

function ClimbTowerManager:registerEvents()
    _G.amfEC:registerSystem(self)
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
    IconTipEventCenter:register(IconTipEvent.CHECK_ICON_TIP, self.onActCheckIconTip, self)
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
    StoreEventCenter:register(_G.StoreEvent.STORE_AFTER_BUY, self.onStoreAfterBuy, self)
end

function ClimbTowerManager:_onCustomGain(event)
    local reward = event and event:getData() or {}
    if reward.itemId ~= self:getConst().TicketItemId then return end

    self:addTicket(reward.num or 0)
end

function ClimbTowerManager:onSystemEnterBackground(event)
    self:callLocalPushFunc("tryRegisterPush")
end

function ClimbTowerManager:onSystemEnterForeground(event)
    self:callLocalPushFunc("cancelPush")
end

function ClimbTowerManager:onActActInfoUpdate(event)
    local data = event and event:getData() or {}
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(self:getConst().actId)]

    if fromServer and not actInfo then
        self:getModel():reset()
        self:callLocalPushFunc("cancelPush")
    elseif fromServer and actInfo then
        self:getModel():syncActInfo(actInfo)
        self:loadRes()
    end
end

function ClimbTowerManager:onActCheckIconTip(event)
    local data = event and event:getData() or {}
    local stage = data.stage
    if stage ~= "STAGE_TWO" and stage ~= "STAGE_FOUR" then return end

    self:checkIconTip()
end

function ClimbTowerManager:isEnabled()
    return self:getModel():isDataEnabled()
end

function ClimbTowerManager:getDataByKey(key)
    return self:getModel():getDataByKey(key)
end

function ClimbTowerManager:getConfigByKey(key)
    return self:getModel():getConfigByKey(key)
end

function ClimbTowerManager:getClaimedMap()
    return self:getModel():getClaimedMap()
end

function ClimbTowerManager:getLayerContent(layerId, cellIndex)
    return self:getModel():getLayerContent(layerId, cellIndex)
end

function ClimbTowerManager:getLayerContentMap()
    return self:getConfigByKey("layerContentMap") or {}
end

function ClimbTowerManager:getLocalCache(key, needTime)
    return self:getModel():getLocalCache(key, needTime)
end

function ClimbTowerManager:setLocalCache(key, needTime, value)
    self:getModel():setLocalCache(key, needTime, value)
end

function ClimbTowerManager:addTicket(num)
    if not num or num <= 0 then return end
    if not self:isEnabled() then return end

    local cur = self:getDataByKey("ticket") or 0
    local total = cur + num
    self:getModel():setDataByKey("ticket", total)

    local actInfo = self.activityMgr:getActInfo(self:getConst().actId)
    if actInfo and actInfo.extra then
        local extraData = table.deserialize(actInfo.extra) or {}
        extraData.ticket = total
        actInfo.extra = table.serialize(extraData)
        self:callPlug("Act", "setActInfo", actInfo)
    end

    self:updateTipView()

    ClimbTowerEventCenter:dispatch(ClimbTowerEvent.TICKET_ADDED, {
        addNum = num,
        total  = total,
    })
end

---任意一种奖励领取动作（领奖期/大奖/剩余奖券兑换）成功回包后，把本地 reward 标记。
function ClimbTowerManager:clearReward()
    if not self:isEnabled() then return end

    self:getModel():setDataByKey("reward", false)

    local actInfo = self.activityMgr:getActInfo(self:getConst().actId)
    if actInfo then
        actInfo.reward = false
        self:callPlug("Act", "setActInfo", actInfo)
    end
end

---剩余奖券兑换/领奖期补领奖励成功后，清掉本地奖券数据。
function ClimbTowerManager:clearRecycleTickets()
    if not self:isEnabled() then return end

    self:getModel():assignRecycleData()
end

function ClimbTowerManager:tryDcQualify()
    if not self:isEnabled() then return end

    local key = self:getConst().DCKey.QUALIFY_DAILY
    if (self:getLocalCache(key, true) or 0) >= 1 then return end
    self:setLocalCache(key, true, 1)

    self:callPlug("DC", "dcQualify", self:getConst().actId)
end

function ClimbTowerManager:tryDcJoin()
    if not self:isEnabled() then return end

    local key = self:getConst().DCKey.JOIN_DAILY
    if (self:getLocalCache(key, true) or 0) >= 1 then return end
    self:setLocalCache(key, true, 1)

    self:callPlug("DC", "dcJoin", self:getConst().actId)
end

function ClimbTowerManager:isInMainTime()
    return self:getModel():isInMainTime()
end

function ClimbTowerManager:isInRewardTime()
    return self:getModel():isInRewardTime()
end

function ClimbTowerManager:getMainBeginTime()
    return self:getModel():getMainBeginTime()
end

function ClimbTowerManager:getMainEndTime()
    return self:getModel():getMainEndTime()
end

function ClimbTowerManager:getEndTime()
    return self:getModel():getEndTime()
end

function ClimbTowerManager:getBeginTime()
    return self:getModel():getBeginTime()
end

function ClimbTowerManager:hasGuideIndex(index)
    return self:getModel():hasGuideIndex(index)
end

function ClimbTowerManager:addGuideIndex(index)
    self:getModel():addGuideIndex(index)
end

function ClimbTowerManager:getTicketRefundByPackageId(packageId)
    return self:getModel():getTicketRefundByPackageId(packageId)
end

function ClimbTowerManager:getRefundPackageIdList()
    return self:getModel():getRefundPackageIdList()
end

function ClimbTowerManager:getFirstRefundPackageId()
    return self:getModel():getFirstRefundPackageId()
end

function ClimbTowerManager:hasAnyRefundPackage()
    return self:getFirstRefundPackageId() ~= nil
end

function ClimbTowerManager:getPeriodId()
    return self:getDataByKey("periodId")
end

function ClimbTowerManager:_registerAutoPopup()
    require "amf.middleware.autopop.config.AutoPopupConst"
    local PCP            = _G.PopupCheckPoint
    local autoPopupMgr   = self.autoPopupMgr
    local PopStage       = AutoPopupConst.PopStage

    autoPopupMgr:registerPopup({
        checkPoint = PCP.CLIMB_TOWER_TRIGGER,
        stages     = { PopStage.STAGE_TWO, PopStage.STAGE_FOUR },
        check      = function()
            if not self:isEnabled() then return false end
            -- 正式期和领奖期各弹一次，本地缓存记录（needTime=false 跨日持久），key 拼入 periodId 按期隔离
            local periodId           = tostring(self:getPeriodId() or "")
            local TRIGGER_MAIN_KEY   = "climb_tower_trigger_main_" .. periodId
            local TRIGGER_REWARD_KEY = "climb_tower_trigger_reward_" .. periodId
            -- 正式期：本期正式期内未弹过
            if self:isInMainTime() and self:getTotalTickets() > 0 then
                return (self:getLocalCache(TRIGGER_MAIN_KEY, false) or 0) < 1
            end
            -- 领奖期：本期领奖期内未弹过
            if self:getModel():isInRewardTime() and self:getTotalTickets() > 0 then
                return (self:getLocalCache(TRIGGER_REWARD_KEY, false) or 0) < 1
            end
            return false
        end,
        creator    = function(_, onPopOver)
            return function()
                -- 正式期和领奖期各弹一次，本地缓存记录（needTime=false 跨日持久），key 拼入 periodId 按期隔离
                local periodId           = tostring(self:getPeriodId() or "")
                local TRIGGER_MAIN_KEY   = "climb_tower_trigger_main_" .. periodId
                local TRIGGER_REWARD_KEY = "climb_tower_trigger_reward_" .. periodId
                -- 本地记录本期弹出，防止重复弹
                if self:isInMainTime() then
                    self:setLocalCache(TRIGGER_MAIN_KEY, false, 1)
                else
                    self:setLocalCache(TRIGGER_REWARD_KEY, false, 1)
                end
                self:openActivity(onPopOver)
            end
        end,
    })


end

function ClimbTowerManager:getGrandLayerId()
    return self:getConst().GrandLayerId
end

function ClimbTowerManager:getCurrentLayerId()
    return self:getDataByKey("currentLayerId") or 1
end

function ClimbTowerManager:getLayerDrawCount(layerId)
    layerId = layerId or self:getCurrentLayerId()
    local layerMap = (self:getClaimedMap() or {})[layerId] or {}
    local count = 0
    for _ in pairs(layerMap) do
        count = count + 1
    end
    return count
end

function ClimbTowerManager:getTotalTickets()
    -- nil 防御：活动数据被清后主面板定时器仍可能 tick 一次
    return (self:getDataByKey("ticket") or 0) + (self:getDataByKey("freeTicket") or 0)
end

function ClimbTowerManager:hasFreeTicket()
    return (self:getDataByKey("freeTicket") or 0) > 0
end

function ClimbTowerManager:isGrandPrizeClaimed()
    return self:getDataByKey("gotFinalReward") == true
end

function ClimbTowerManager:isCurrentLayerOnlyLevelUpLeft()
    local model = self:getModel()
    local layerId = self:getCurrentLayerId()
    local list = model:getLayerContentList(layerId)
    local claimedLayerMap = (self:getClaimedMap() or {})[layerId] or {}
    local hasUnclaimedCell = false

    for cellIndex, cell in ipairs(list) do
        local cellId = cell.cellIndex or cellIndex
        if not claimedLayerMap[cellId] then
            if not cell.levelUpReward then
                return false
            end
            hasUnclaimedCell = true
        end
    end

    return hasUnclaimedCell
end

function ClimbTowerManager:hasGrandPrizePending()
    if self:isGrandPrizeClaimed() then return false end
    return self:getCurrentLayerId() >= self:getGrandLayerId()
end

function ClimbTowerManager:hasReward()
    if not self:isEnabled() then return false end
    return self:getDataByKey("reward") or false
end

function ClimbTowerManager:getMsgNum()
    if not self:isEnabled() then return 0 end
    local drawCost = self:getDataByKey("drawNeedTicketNum")
    if not drawCost then return self:getDataByKey("msgNum") end

    return self:getTotalTickets() >= drawCost and 1 or 0
end

function ClimbTowerManager:updateTipView()
    if self.actPlug then
        self.actPlug:updateTipView()
    end
end

function ClimbTowerManager:_incrementTipPopCount(tipKey)
    self:setLocalCache(tipKey, true, (self:getLocalCache(tipKey, true) or 0) + 1)
end

function ClimbTowerManager:_canShowJoinTip()
    local Const = self:getConst()
    local key = Const.TipKey.JOIN
    if (self:getLocalCache(key, true) or 0) >= Const.TipDailyLimit[key] then return false end
    return self:hasFreeTicket()
end

function ClimbTowerManager:_canShowNextLayerTip()
    local Const = self:getConst()
    local key = Const.TipKey.NEXT_LAYER
    if (self:getLocalCache(key, true) or 0) >= Const.TipDailyLimit[key] then return false end
    if self:getCurrentLayerId() >= (self:getGrandLayerId() - 1) then return false end
    return self:isCurrentLayerOnlyLevelUpLeft()
end

function ClimbTowerManager:_canShowGrandPushTip()
    local Const = self:getConst()
    local key = Const.TipKey.GRAND_PUSH
    if (self:getLocalCache(key, true) or 0) >= Const.TipDailyLimit[key] then return false end
    if self:isGrandPrizeClaimed() then return false end
    return self:getCurrentLayerId() >= (self:getGrandLayerId() - 1)
end

function ClimbTowerManager:_pickActiveTipKey()
    local Const = self:getConst()
    if self:_canShowGrandPushTip() then return Const.TipKey.GRAND_PUSH end
    if self:_canShowNextLayerTip() then return Const.TipKey.NEXT_LAYER end
    if self:_canShowJoinTip()      then return Const.TipKey.JOIN       end
    return nil
end

function ClimbTowerManager:checkIconTip(config)
    if not self:isEnabled() then return false end
    if not self:isInMainTime() then return end

    local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")
    local tipKey = self:_pickActiveTipKey()
    if not tipKey then return end

    local Const = self:getConst()

    IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, {
        iconKey   = tostring(self:getConst().actId),
        iconType  = IconTipType.MESSAGE,
        priority  = "A",
        typeIndex = 1,
        creatorDelegate = {
            text     = Const.TipDesc[tipKey] or "",
            tipsType = HomeIconTipsType.ONLY_TEXT,
        },
        popFunc = function()
            self:_incrementTipPopCount(tipKey)
        end,
        config = config,
    })
end

function ClimbTowerManager:loadRes()
    if self.isResLoaded then
        return deferred.success()
    end

    if not self.loadResDeferred then
        self.loadResDeferred = _G.amfBean("AssetsUtil"):loadMiniLabels({ RES_LABEL }):next(function()
            self.isResLoaded = true
        end, function()
            self.loadResDeferred = nil
        end)
    end
    return self.loadResDeferred
end

function ClimbTowerManager:openActivity(closeCallback, extra, userClick, duanMianData)
    ActivityEventCenter:dispatch(ActivityEvent.OPEN_ACTIVITY, {
        actId = self:getConst().actId,
        failCallback = closeCallback,
        endCallback = closeCallback,
        userClick = userClick,
        extra = extra,
        duanMianData = duanMianData
    })
end

--region gift display extension: 商店 banner + 礼包奖券角标 + 商店引导2
function ClimbTowerManager:isShopBannerActive()
    if not self.isResLoaded then return false end
    if not self:isEnabled() then return false end
    if not self:isInMainTime() then return false end
    if not self:hasAnyRefundPackage() then return false end
    if self:isGrandPrizeClaimed() then return false end
    return true
end

function ClimbTowerManager:getStoreHeaderEntry()
    if not self:isShopBannerActive() then return nil end
    return {
        inset  = 190,
        offset = ccp(349, 0),
        createView = function()
            local ClimbTowerShopBanner = require "amf/feature/localactivity/climbtower/view/ClimbTowerShopBanner"
            local banner = ClimbTowerShopBanner:create()
            banner:setMainEndTime(self:getMainEndTime())
            banner:setFlyItemId(self:getConst().TicketItemId)
            banner:setOnClick(function()
                self:openActivity(nil, { dcEntry = "new_store" }, true, nil)
            end)
            return banner
        end,
    }
end

function ClimbTowerManager:getGiftDisplayBubbleItem(giftData)
    if not giftData then return nil end
    if not self:isShopBannerActive() then return nil end

    local num = self:getTicketRefundByPackageId(giftData:getGoodsId()) or 0
    if num <= 0 then return nil end

    return {
        itemId = self:getConst().TicketItemId,
        num = num,
    }
end

function ClimbTowerManager:getStoreGuideEntry(context)
    if not self:isShopBannerActive() then return nil end

    local GuideIndex = self:getConst().GuideIndex
    if self:hasGuideIndex(GuideIndex.STORE_GUIDE_2_IN_STORE) then return nil end

    local source = context and context.source
    if not source then return nil end

    local scene = Director:sharedDirector():getRunningScene()
    if scene and scene:is(UBFGamePlayScene) then return nil end

    local AccurateSource = _G.StoreConfig.AccurateSource
    if source == AccurateSource.Click_GS_AddStepPanel
            or source == AccurateSource.Click_UBF_AddStepPanel_Top_First
            or source == AccurateSource.Click_UBF_AddStepPanel_Top_Second
            or source == AccurateSource.Auto_GS_AddStep5Discount
            or source == AccurateSource.Auto_GS_AddStep5
            or source == AccurateSource.Auto_GS_AddStep2Discount
            or source == AccurateSource.Auto_GS_AddStep2
            or source == AccurateSource.Auto_WR_AddStep
            or source == AccurateSource.Auto_GS_BuyProps then
        return nil
    end
    return {
        showGuide = function(storePanel)
            local ClimbTowerStoreGuide2 = require("amf/feature/localactivity/climbtower/view/ClimbTowerStoreGuide2")
            local guide = ClimbTowerStoreGuide2.new({
                storePanel       = storePanel,
                targetPackageId  = self:getFirstRefundPackageId(),
                ticketItemId     = self:getConst().TicketItemId,
                scrollTime       = 0,
            })
            if guide:show() then
                self:addGuideIndex(GuideIndex.STORE_GUIDE_2_IN_STORE)
            end
            return guide
        end,
    }
end

---商店购买成功事件回调：后端礼包 rewardList **不包含**我们的奖券，前端按配置补发。
---流程：拿 packageId → 查 packageTicketRefund 配置 → 创建奖券道具飞行动画 → 飞行完成后
---调 self:addTicket(num)（addTicket 内部已写 actInfo + dispatch TICKET_ADDED，cocos 主面板
---订阅 TICKET_ADDED 后会自动 pushTickets + pushDrawButtonState）。
---飞行落点优先用 banner 的「去抽奖」按钮（StorePanel:resolveStoreHeaderFlyPos）；如果商店关闭
---或 banner 不在，则跳过飞行直接加券（保证 server-side 状态一致）。
function ClimbTowerManager:onStoreAfterBuy(event)
    if not self:isEnabled() then return end
    if not self:isInMainTime() then return end

    local payload = event and event:getData()
    if not payload then return end

    local giftData   = payload.giftData
    local storePanel = payload.storePanel
    if not giftData or not giftData.getGoodsId then return end

    local packageId = giftData:getGoodsId()
    local num = self:getTicketRefundByPackageId(packageId) or 0
    if num <= 0 then return end

    self:playTicketRefundFly(num, storePanel, function()
        _G.GainPropData:create()
            :setFeature("happy_climb")
            :setSource(tostring(packageId))
            :setProps({ {itemId = self:getConst().TicketItemId, num = num} })
            :setExtraMap({ pay_type = "3" })
            :execute()
    end)
end

---创建奖券道具的飞行动画，飞向 banner「去抽奖」按钮。
---startWorldPos 取屏幕中心（与主面板入场动画一致）；targetWorldPos 走 StorePanel
---:resolveStoreHeaderFlyPos(TicketItemId) —— banner 内 setFlyItemId 已注入 TicketItemId
---只接收奖券飞行，其他 itemId 返回 nil。
---FlyItemContext / TransactionEvent.FLY_ITEMS 自动挂到 scene.topLayer，跨 panel 也能飞。
function ClimbTowerManager:playTicketRefundFly(num, storePanel, callback)
    local TicketItemId = self:getConst().TicketItemId

    local targetWorldPos
    if storePanel and not storePanel.isDisposed and storePanel.resolveStoreHeaderFlyPos then
        targetWorldPos = storePanel:resolveStoreHeaderFlyPos(TicketItemId)
    end

    if not targetWorldPos then
        safeRunCall(callback)
        return
    end

    local visibleArea = _G.fullScreenSizeManager:getVisibleArea()
    local startWorldPos = ccp(
        visibleArea.origin.x + visibleArea.size.width  * 0.5,
        visibleArea.origin.y + visibleArea.size.height * 0.5
    )

    require "amf.middleware.ui.kit.animation.fly.transaction.FlyItemContext"
    local flyContext = FlyItemContext.new({
        {
            itemId     = TicketItemId,
            num        = num,
            targetPos  = ccp(targetWorldPos.x, targetWorldPos.y),
            duration   = 0.5,
            scale      = 1.0,
            shandowNum = 3,
        }
    }, ccp(startWorldPos.x, startWorldPos.y)):setFinishCallback(function()
        self:playEffect(self:getConst().Sound.TICKET_COLLECT)
        safeRunCall(callback)
    end)
    _G.amfTransaction(TransactionEvent.FLY_ITEMS, flyContext)
end

function ClimbTowerManager:playEffect(type, loop)
    local filePath = "amf/activity/climbtower/sound/" .. type
    self[type .. "_effect"] = GamePlayMusicPlayer.getInstance():playEffect(filePath, nil, loop)
end

--endregion

return ClimbTowerManager
