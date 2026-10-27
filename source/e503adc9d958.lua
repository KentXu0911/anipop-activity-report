local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local StoreEventCenter = require "amf.feature.store.event.StoreEventCenter"
local ShopRewardEventCenter = require "amf.feature.localactivity.shopreward.event.ShopRewardEventCenter"
local GiftEventCenter = require "amf.feature.giftpackage.event.GiftEventCenter"
require "amf.feature.giftpackage.config.GiftPackageConst"
require "amf.feature.store.config.StoreConfig"
local Res = require "amf.feature.localactivity.shopreward.const.Res"

local ShopRewardManager = class("ShopRewardManager", BaseFeatureManager)

local ADD_STEP_NEW_EXPOSURE_END_ADVANCE = 10 * 60
local STORE_SCROLL_TOP_OFFSET = 5
function ShopRewardManager:_getConstPath()
    return "amf.feature.localactivity.shopreward.const.ShopRewardConst"
end

function ShopRewardManager:_getModelPath()
    return "amf.feature.localactivity.shopreward.model.ShopRewardModel"
end

function ShopRewardManager:_init()
    self:initActInfo()
    self:registerEvents()
end

function ShopRewardManager:getGoldTagLogic()
    if not self.goldTagLogic then
        local Logic = require "amf.feature.localactivity.shopreward.logic.ShopRewardGoldTagLogic"
        self.goldTagLogic = Logic:create(self)
    end
    return self.goldTagLogic
end

function ShopRewardManager:getTipLogic()
    if not self.tipLogic then
        local Logic = require "amf.feature.localactivity.shopreward.logic.ShopRewardTipLogic"
        self.tipLogic = Logic:create(self)
    end
    return self.tipLogic
end

function ShopRewardManager:getMainPopupLogic()
    if not self.mainPopupLogic then
        local Logic = require "amf.feature.localactivity.shopreward.logic.ShopRewardMainPopupLogic"
        self.mainPopupLogic = Logic:create(self)
    end
    return self.mainPopupLogic
end

function ShopRewardManager:getLocalPushLogic()
    if not self.localPushLogic then
        local Logic = require "amf.feature.localactivity.shopreward.logic.ShopRewardLocalPushLogic"
        self.localPushLogic = Logic:create(self)
    end
    return self.localPushLogic
end

function ShopRewardManager:getDcLogic()
    if not self.dcLogic then
        local Logic = require "amf.feature.localactivity.shopreward.logic.ShopRewardDcLogic"
        self.dcLogic = Logic:create(self)
    end
    return self.dcLogic
end

function ShopRewardManager:setActivityMgr(activityMgr)
    self.activityMgr = activityMgr
end

function ShopRewardManager:initActInfo()
    if not self.actPlug then return end

    local actInfo = self.actPlug:getActInfo()

    self:getModel():syncActInfo(actInfo)
    self:registerActMainEndTimer()
end

function ShopRewardManager:registerEvents()
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActInfoUpdate, self)
    GiftEventCenter:register(GiftEvent.STAGE_PACKAGES_RECEIVED, self.onStagePackagesReceived, self)
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)
end

function ShopRewardManager:onActEnterStage2()
    self:tryMainPopup()
end

function ShopRewardManager:onActEnterStage4()
    self:tryMainPopup()
end

function ShopRewardManager:onActEnterMainScene()
    self:refreshDisplayByState()
end

function ShopRewardManager:onSystemEnterBackground()
    self:getLocalPushLogic():tryRegisterPush()
end

function ShopRewardManager:onSystemEnterForeground()
    self:getLocalPushLogic():cancelPush()
end

function ShopRewardManager:onActInfoUpdate(event)
    local data = event and event:getData() or {}
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(self:getConst().actId)]

    if fromServer and not actInfo then
        if self:shouldKeepLocalDataWhenServerActInfoMissing() then
            self:refreshStoreExtensions()
            self:refreshDisplayByState()
            return
        end

        self.moduleExtra = nil
        self.packagePullModuleExtra = nil
        self.packagePullSyncedByStage = nil
        self.hiddenStoreGiftDataMap = nil
        self:getModel():resetActInfoData()
        self:removeActMainEndTimer()
        self:removeGoldTag()
        self:getLocalPushLogic():cancelPush()
        self:refreshShopRewardIconModule()
    elseif fromServer and actInfo then
        local actInfoExtraData = self:getSyncActInfoExtraData(actInfo)
        if self:isModuleExtraBuyProgressOutdated(actInfoExtraData) then
            return
        end

        if self.moduleExtra then
            if self:isCachedModuleExtraOlderThanActInfo(actInfo) then
                self.moduleExtra = nil
            elseif self:isModuleExtraBuyProgressOutdated(self.moduleExtra) then
                self.moduleExtra = nil
            else
                actInfo = self:updateActInfoByModuleExtra(self.moduleExtra, actInfo)
                actInfos[tostring(self:getConst().actId)] = actInfo
                return
            end
        end

        self:getModel():syncActInfo(actInfo)
        self:registerActMainEndTimer()
        if self:isEnabled() then
            self:dcQualify()
        end
        self:refreshStoreExtensions()
        self:refreshDisplayByState()
    end
end

function ShopRewardManager:getSyncActInfoExtraData(actInfo)
    if actInfo and actInfo.extra then
        return table.deserialize(actInfo.extra)
    end
end

function ShopRewardManager:shouldKeepLocalDataWhenServerActInfoMissing()
    if self:getPeriodId() <= 0 then return false end
    if self:getModel():getBoughtPackageCount() > 0 then return true end
    if self.moduleExtra then return true end
    if self.packagePullModuleExtra then return true end
    return false
end

function ShopRewardManager:isModuleExtraBuyProgressOutdated(extraData)
    if not extraData then return false end

    local localPeriodId = tonumber(self:getModel():getDataByKey("periodId", 0)) or 0
    local syncPeriodId = tonumber(extraData.periodId or 0) or 0
    if syncPeriodId ~= localPeriodId then return false end

    -- 和剩余次数保持同一口径：只用 boughtPackageIdMap 合计判断购买进度新旧。
    -- periodTotalBuyCount 可能因为支付回调和 actInfo/moduleExtra 乱序到达而重复叠加，不能作为唯一事实来源。
    local localBuyCount = self:getModel():getBoughtPackageCount()
    if localBuyCount <= 0 then return false end

    local syncBuyCount = self:getBoughtPackageCountFromExtra(extraData)
    local outdated = syncBuyCount < localBuyCount
    -- 真实支付回到游戏时，ACT_INFOS_UPDATE 可能晚于 STORE_AFTER_BUY 到达，
    -- 且携带的是购买前的旧 actInfo/moduleExtra。此时如果直接 syncActInfo，
    -- 会把本地已处理的购买次数回滚为 0，导致后续购买无法触发活动结束刷新。
    -- 因此仅在同一期内，待同步购买次数小于本地购买次数时，认为这次同步是旧数据，丢弃等待下一次更新。
    -- 如果 periodId 已经变化，说明进入新一期，必须放行同步，避免上一期内存态阻塞新一期活动。
    return outdated
end

function ShopRewardManager:isCachedModuleExtraOlderThanActInfo(actInfo)
    if not self.moduleExtra then return false end

    local actInfoExtraData = self:getSyncActInfoExtraData(actInfo)
    if not actInfoExtraData then return false end

    local cachedPeriodId = tonumber(self.moduleExtra.periodId or 0) or 0
    local syncPeriodId = tonumber(actInfoExtraData.periodId or 0) or 0
    -- actInfo 已进入新一期时，缓存的 moduleExtra 不能再覆盖本次 actInfo，
    -- 否则会把新一期数据写回旧 periodId，导致新周期被旧内存态阻塞。
    if cachedPeriodId ~= syncPeriodId then return true end

    local cachedBuyCount = self:getBoughtPackageCountFromExtra(self.moduleExtra)
    local syncBuyCount = self:getBoughtPackageCountFromExtra(actInfoExtraData)
    local older = cachedBuyCount < syncBuyCount
    return older
end

function ShopRewardManager:getBoughtPackageCountFromExtra(extraData)
    local boughtPackageIdMap = extraData and extraData.boughtPackageIdMap or {}
    local count = 0
    for _, boughtCount in pairs(boughtPackageIdMap) do
        count = count + math.max(tonumber(boughtCount or 0) or 0, 0)
    end
    return count
end

function ShopRewardManager:isSyncBuyProgressOutdated(actInfo)
    return self:isModuleExtraBuyProgressOutdated(self:getSyncActInfoExtraData(actInfo))
end

function ShopRewardManager:refreshStoreExtensions()
    StoreEventCenter:dispatch(_G.StoreEvent.STORE_EXTENSIONS_REFRESH)
end

function ShopRewardManager:isEnabled()
    return self:getModel():getDataByKey("group", "OFF") ~= "OFF" and self:isInMainTime() and self:getRemainBuyCount() > 0
end

function ShopRewardManager:getActInfo()
    local activityMgr = self.activityMgr or _G.amfBean("ActivityMgr")
    return activityMgr and activityMgr:getActInfo(self:getConst().actId)
end

function ShopRewardManager:getActInfoExtraData()
    local actInfo = self:getActInfo()
    if not actInfo or not actInfo.extra then return end

    return table.deserialize(actInfo.extra)
end

function ShopRewardManager:syncModuleExtra(moduleExtra)
    if not moduleExtra then return end
    if self:isModuleExtraBuyProgressOutdated(moduleExtra) then
        return
    end

    self.moduleExtra = moduleExtra
    self:updateActInfoByModuleExtra(moduleExtra)
end

function ShopRewardManager:syncActInfoFromPackagePull(moduleExtraMap)
    local moduleExtra = moduleExtraMap and moduleExtraMap[GiftPackageConst.ModuleType.SHOP_REWARD]
    if moduleExtra then
        if self.packagePullModuleExtra == moduleExtra then return end

        self.packagePullModuleExtra = moduleExtra
        self:syncModuleExtra(table.deserialize(moduleExtra) or {})
    end
end

function ShopRewardManager:syncPackagesFromPackagePull(stageType, packages)
    if not self:isEnabled() then
        return
    end

    if stageType == GiftPackageConst.StageType.STORE then
        self:cacheHiddenStoreGiftDataByPackages(packages)
    end
end

function ShopRewardManager:cacheHiddenStoreGiftData(giftData)
    if not giftData or not giftData.getGoodsId then return end

    self.hiddenStoreGiftDataMap = self.hiddenStoreGiftDataMap or {}
    self.hiddenStoreGiftDataMap[tostring(giftData:getGoodsId())] = giftData
end

function ShopRewardManager:cacheHiddenStoreGiftDataByPackages(packages)
    self.hiddenStoreGiftDataMap = nil
    if not packages then return end

    local replaces = self:getModel():getDataByKey("replaces", {})
    local originPackageIdMap = {}

    for _, replaceInfo in ipairs(replaces) do
        if replaceInfo.originPackageId then
            originPackageIdMap[tostring(replaceInfo.originPackageId)] = true
        end
    end

    if not next(originPackageIdMap) then return end

    for _, giftData in ipairs(packages) do
        if giftData
            and giftData.getGoodsId
            and giftData.getExtraValue
            and giftData:getExtraValue("hidden")
            and originPackageIdMap[tostring(giftData:getGoodsId())]
        then
            self:cacheHiddenStoreGiftData(giftData)
        end
    end
end

function ShopRewardManager:getHiddenStoreGiftData(packageId)
    if not packageId then return end
    return self.hiddenStoreGiftDataMap and self.hiddenStoreGiftDataMap[tostring(packageId)]
end

function ShopRewardManager:updateActInfoByModuleExtra(moduleExtra, actInfo)
    if not moduleExtra then return end

    actInfo = actInfo or self:getActInfo() or {}
    actInfo.extra = table.serialize(moduleExtra)

    local activityMgr = self.activityMgr or _G.amfBean("ActivityMgr")
    if activityMgr and activityMgr.setActInfo then
        activityMgr:setActInfo(self:getConst().actId, actInfo)
    end

    self:getModel():syncActInfo(actInfo)
    self:registerActMainEndTimer()
    if self:isEnabled() then
        self:dcQualify()
    end
    self:refreshStoreExtensions()
    self:refreshDisplayByState()
    return actInfo
end

function ShopRewardManager:dcQualify()
    return self:getDcLogic():dcQualify()
end

function ShopRewardManager:dcJoin()
    return self:getDcLogic():dcJoin()
end

function ShopRewardManager:dcMainPanelShow(panelId, popupType)
    return self:getDcLogic():dcMainPanelShow(panelId, popupType)
end

function ShopRewardManager:dcMainPanelClick(panelId)
    return self:getDcLogic():dcMainPanelClick(panelId)
end

function ShopRewardManager:dcStoreHeaderClick()
    return self:getDcLogic():dcStoreHeaderClick()
end

function ShopRewardManager:removeActMainEndTimer()
    if self.actMainEndTimer then
        TimerUtil.removeAlarm(self.actMainEndTimer)
        self.actMainEndTimer = nil
    end
end

function ShopRewardManager:registerActMainEndTimer()
    self:removeActMainEndTimer()

    if not self:canRegisterActMainEndTimer() then return end

    local mainEndTime = self:getMainEndTime()
    if not mainEndTime or mainEndTime <= 0 then return end

    local remainTime = mainEndTime - TimeKit:timeInSec()
    if remainTime <= 0 then return end

    self.actMainEndTimer = TimerUtil.addAlarm(function()
        self.actMainEndTimer = nil
        self:onActMainEnded()
    end, remainTime, 1)
end

function ShopRewardManager:canRegisterActMainEndTimer()
    if self:getModel():getDataByKey("group", "OFF") == "OFF" then return false end
    return self:getModel():isDataEnabled()
end

function ShopRewardManager:onActMainEnded()
    self:removeActMainEndTimer()
    self:getLocalPushLogic():cancelPush()
    self:onStoreActivityEnded()
end

function ShopRewardManager:getRemainBuyCount()
    return self:getModel():getRemainBuyCount()
end

function ShopRewardManager:getMainEndTime()
    return self:getModel():getMainEndTime()
end

function ShopRewardManager:getMainBeginTime()
    return self:getModel():getMainBeginTime()
end

function ShopRewardManager:isMainTimeEnded()
    local mainEndTime = self:getModel():getMainEndTime() or 0
    return self:getModel():isDataEnabled() and mainEndTime > 0 and TimeKit:timeInSec() >= mainEndTime
end

function ShopRewardManager:showActivityEndedTip(closeCallback)
    local text = localize("the.activity.has.ended")
    CommonTipWithBtn:showTip({
        tipStr = text,
        okInfo = {
            btnStr = "知道了",
            callback = closeCallback,
        },
        noInfo = {
            callback = closeCallback,
            hide = true,
        }
    }, "negative", nil, nil, nil, true)
end

function ShopRewardManager:getPeriodId()
    return self:getModel():getDataByKey("periodId", 0)
end

function ShopRewardManager:isInMainTime()
    local model = self:getModel()
    local nowTime = TimeKit:timeInSec()
    return model:isDataEnabled()
        and nowTime >= TimeKit:tryConvertMsToSec(model:getMainBeginTime())
        and nowTime < TimeKit:tryConvertMsToSec(model:getMainEndTime())
end

function ShopRewardManager:isGoldTagEnabled()
    return self:getGoldTagLogic():isEnabled()
end

function ShopRewardManager:getGoldButton()
    return self:getGoldTagLogic():getGoldButton()
end

function ShopRewardManager:createGoldTag(goldButton)
    return self:getGoldTagLogic():createGoldTag(goldButton)
end

function ShopRewardManager:removeGoldTag()
    return self:getGoldTagLogic():removeGoldTag()
end

function ShopRewardManager:tryAddGoldTag()
    return self:getGoldTagLogic():tryAddGoldTag()
end

function ShopRewardManager:onStoreActivityEnded()
    self:removeGoldTag()
    self:refreshStoreExtensions()
    ShopRewardEventCenter:dispatch(ShopRewardEvent.ACT_MAIN_ENDED, {
        periodId = self:getPeriodId(),
    })
end

function ShopRewardManager:onStorePanelShow()
    ShopRewardEventCenter:dispatch(ShopRewardEvent.STORE_PANEL_SHOW, {
        manager = self,
    })
end

function ShopRewardManager:getStoreHeaderEntry(context)
    local canShow = self:canShowStoreHeader()
    if not canShow then return nil end
    return self:createStoreHeaderEntry()
end

function ShopRewardManager:getStoreGuideEntry(context)
    return self:createStoreGuideEntry(context)
end

function ShopRewardManager:canShowStoreHeader()
    if not _G.amfBean("NetworkStatusManager"):isNetworkEnabled() then
        return false
    end
    return self:isEnabled()
end

function ShopRewardManager:createStoreHeaderEntry()
    return {
        inset = 150,
        contentTopPadding = 25,
        offset = ccp(349, 0),
        createView = function()
            local HeaderView = require "amf.feature.localactivity.shopreward.view.ShopRewardStoreHeaderView"
            local node = HeaderView:create({
                delayBuild = self:canShowStoreGuide(),
            })
            node:setClickHandler(function()
                self:dcStoreHeaderClick()
                self:scrollToTargetStorePackage()
            end)
            return node
        end,
    }
end

function ShopRewardManager:getStoreGuideLocalKey()
    return "storeGuide_" .. tostring(self:getPeriodId())
end

function ShopRewardManager:hasStoreGuideShown()
    if self:getPeriodId() <= 0 then return true end
    return self:getModel():getLocalCache(self:getStoreGuideLocalKey(), false) or false
end

function ShopRewardManager:markStoreGuideShown()
    if self:getPeriodId() <= 0 then return end
    self:getModel():setLocalCache(self:getStoreGuideLocalKey(), false, true)
    self:getModel():flush()
end

function ShopRewardManager:isStoreGuideBlockedBySource(source)
    if not source then return false end

    local AccurateSource = _G.StoreConfig.AccurateSource
    return source == AccurateSource.Auto_GS_AddStep5Discount
        or source == AccurateSource.Auto_GS_AddStep5
        or source == AccurateSource.Auto_GS_AddStep2Discount
        or source == AccurateSource.Auto_GS_AddStep2
end

function ShopRewardManager:createStoreGuideEntry(context)
    if not self:canShowStoreGuide(context) then return nil end

    return {
        showGuide = function(storePanel)
            local ShopRewardStoreGuide = require "amf.feature.localactivity.shopreward.view.ShopRewardStoreGuide"
            local guide = ShopRewardStoreGuide.new({
                storePanel = storePanel,
                targetPackageId = self:getTargetStorePackageId(),
            })
            if guide:show() then
                self:setWaitingStoreGuideLineAnim(true)
                self:markStoreGuideShown()
                return guide
            else
                self:setWaitingStoreGuideLineAnim(false)
            end
        end,
    }
end

function ShopRewardManager:canShowStoreGuide(context)
    if not self:isEnabled() then return false end
    if self:hasStoreGuideShown() then return false end
    if self:isStoreGuideBlockedBySource(context and context.source) then return false end

    local targetPackageId = self:getTargetStorePackageId()
    if not targetPackageId then return false end

    return true
end

function ShopRewardManager:setWaitingStoreGuideLineAnim(isWaiting)
    self.isWaitingStoreGuideLineAnim = isWaiting == true
end

function ShopRewardManager:shouldWaitStoreGuideLineAnim()
    return self.isWaitingStoreGuideLineAnim == true
end

function ShopRewardManager:scrollToTargetStorePackage()
    local packageId = self:getTargetStorePackageId()
    if not packageId then return end

    StoreEventCenter:dispatch(_G.StoreEvent.STORE_SCROLL_TO_PACKAGE, {
        packageId = packageId,
        duration = 0.2,
        silentExpand = true,
        scrollTopOffset = STORE_SCROLL_TOP_OFFSET,
    })
end

function ShopRewardManager:refreshDisplayByState()
    self:getGoldTagLogic():refreshGoldTagByState()
    self:refreshShopRewardIconModule()
end

function ShopRewardManager:refreshShopRewardIconModule()
    ShopRewardEventCenter:dispatch(ShopRewardEvent.ICON_STATE_REFRESH, {
        manager = self,
    })
end

function ShopRewardManager:isShopRewardSyncStage(stageType)
    return stageType == GiftPackageConst.StageType.STORE
        or stageType == GiftPackageConst.StageType.ADD_STEP
        or stageType == GiftPackageConst.StageType.VINE_SCENE
end

function ShopRewardManager:onStagePackagesReceived(event)
    local data = event and event:getData() or {}
    local stageType = data.stageType
    if not self:isShopRewardSyncStage(stageType) then return end

    self:markPackagePullSynced(stageType)
    self:syncActInfoFromPackagePull(data.moduleExtraMap)
    self:syncPackagesFromPackagePull(stageType, data.packages)
    self:tryMainPopup()
end

function ShopRewardManager:markPackagePullSynced(stageType)
    if not stageType then return end

    self.packagePullSyncedByStage = self.packagePullSyncedByStage or {}
    self.packagePullSyncedByStage[stageType] = self:getPeriodId()
end

function ShopRewardManager:isPackagePullSynced(stageType)
    if not stageType then return false end
    return self.packagePullSyncedByStage and self.packagePullSyncedByStage[stageType] == self:getPeriodId()
end

function ShopRewardManager:isStorePackagePullSynced()
    return self:isPackagePullSynced(GiftPackageConst.StageType.STORE)
        or self:isPackagePullSynced(GiftPackageConst.StageType.VINE_SCENE)
end

function ShopRewardManager:checkIconTip(config)
    return self:getTipLogic():tryShowActivityTip(config)
end

function ShopRewardManager:tryMainPopup()
    return self:getMainPopupLogic():tryMainPopup()
end

function ShopRewardManager:getTargetStorePackageId()
    local packageIds = self:getModel():getDataByKey("uiPriorityPackageIds", {})
    local boughtPackageIdMap = self:getModel():getDataByKey("boughtPackageIdMap", {})

    for _, packageId in ipairs(packageIds) do
        local boughtCount = boughtPackageIdMap[tostring(packageId)] or boughtPackageIdMap[packageId] or 0
        if boughtCount <= 0 then
            return packageId
        end
    end
end

function ShopRewardManager:getOriginPackageIdByActivityPackageId(activityPackageId)
    if not activityPackageId then return end

    local replaces = self:getModel():getDataByKey("replaces", {})
    for _, replaceInfo in pairs(replaces) do
        if (tonumber(replaceInfo.activityPackageId or -1) or -1) == (tonumber(activityPackageId or -2) or -2) then
            return replaceInfo.originPackageId
        end
    end
end

function ShopRewardManager:getAllActivityPackageIds()
    local replaces = self:getModel():getDataByKey("replaces", {})
    local packageIds = {}
    for _, replaceInfo in pairs(replaces) do
        if replaceInfo.activityPackageId then
            table.insert(packageIds, replaceInfo.activityPackageId)
        end
    end
    return packageIds
end

function ShopRewardManager:getPackageGoldNum(packageId)
    if not packageId then return 0 end

    local goods = GoodsManager:getGoods(packageId)
    if not goods or not goods.getItems then return 0 end

    local items = goods:getItems() or {}
    for _, item in ipairs(items) do
        if item.itemId == AMFPropId.GOLD then
            return tonumber(item.num) or 0
        end
    end
    return 0
end

function ShopRewardManager:isActivityPackageMetaReady(replaceInfo, stageType)
    if not replaceInfo then return false end
    local packageSynced = stageType and self:isPackagePullSynced(stageType) or self:isStorePackagePullSynced()
    if not packageSynced then return false end

    local activityPackageId = replaceInfo.activityPackageId
    if not activityPackageId then return false end

    local goods = GoodsManager:getGoods(activityPackageId)
    return goods ~= nil
end

function ShopRewardManager:getReplaceInfoByActivityPackageId(activityPackageId)
    if not activityPackageId then return end

    local packageIdNum = tonumber(activityPackageId or -1) or -1
    local replaces = self:getModel():getDataByKey("replaces", {})
    for _, replaceInfo in pairs(replaces) do
        if (tonumber(replaceInfo.activityPackageId or -2) or -2) == packageIdNum then
            return replaceInfo
        end
    end
end

function ShopRewardManager:isMainPopupGoodsReady()
    local replaces = self:getModel():getDataByKey("replaces", {})
    if table.isEmpty(replaces) then
        return false
    end

    for _, replaceInfo in pairs(replaces) do
        local activityPackageId = replaceInfo.activityPackageId
        local isRemainBuyable = self:isActivityPackageRemainBuyable(activityPackageId)
        local replaceReady = self:isActivityPackageMetaReady(replaceInfo)

        if isRemainBuyable and replaceReady then
            return true
        end
    end

    return false
end

function ShopRewardManager:getExtraGoldNumByActivityPackageId(activityPackageId, stageType)
    local replaceInfo = self:getReplaceInfoByActivityPackageId(activityPackageId)
    if not self:isActivityPackageMetaReady(replaceInfo, stageType) then return 0 end

    local activityGoldNum = self:getPackageGoldNum(activityPackageId)
    local originPackageId = replaceInfo and replaceInfo.originPackageId
    local originGoldNum = self:getPackageGoldNum(originPackageId)
    return math.max(activityGoldNum - originGoldNum, 0)
end

function ShopRewardManager:getMaxExtraGoldNum(stageType)
    local maxExtraGoldNum = 0
    local replaces = self:getModel():getDataByKey("replaces", {})
    for _, replaceInfo in pairs(replaces) do
        local packageId = replaceInfo.activityPackageId
        if self:isActivityPackageRemainBuyable(packageId) and self:isActivityPackageMetaReady(replaceInfo, stageType) then
            maxExtraGoldNum = math.max(maxExtraGoldNum, self:getExtraGoldNumByActivityPackageId(packageId, stageType) or 0)
        end
    end
    return maxExtraGoldNum
end

function ShopRewardManager:isActivityPackageRemainBuyable(packageId)
    if not packageId then return false end

    local boughtPackageIdMap = self:getModel():getDataByKey("boughtPackageIdMap", {})
    local boughtCount = boughtPackageIdMap[tostring(packageId)] or boughtPackageIdMap[packageId] or 0
    return boughtCount <= 0
end

function ShopRewardManager:isAddStepGroupEnabled()
    return self:getModel():getDataByKey("group", "OFF") == "ON3"
end

function ShopRewardManager:canCreateAddStepExposureByEndTime()
    local mainEndTime = self:getMainEndTime() or 0
    if mainEndTime <= 0 then return false end

    return TimeKit:timeInSec() < mainEndTime - ADD_STEP_NEW_EXPOSURE_END_ADVANCE
end

function ShopRewardManager:isAddStepPayTagEnabled()
    -- +5 步曝光付费标签范围，按 payType60Id 判断。
    local payType60Id = tonumber(self:getModel():getDataByKey("payType60Id", 0)) or 0
    return payType60Id >= UsetPaymentTagServer.kHigh_4
end

function ShopRewardManager:getAddStepCandidatePackageIds(addFivePrice)
    addFivePrice = tonumber(addFivePrice or 0) or 0
    if addFivePrice <= 0 then return {} end

    local packageIds = self:getModel():getDataByKey("uiPriorityPackageIds", {})
    local candidates = {}
    for _, packageId in ipairs(packageIds) do
        local replaceInfo = self:getReplaceInfoByActivityPackageId(packageId)
        if self:isActivityPackageRemainBuyable(packageId)
            and self:isActivityPackageMetaReady(replaceInfo, GiftPackageConst.StageType.ADD_STEP)
            and self:getPackageGoldNum(packageId) >= addFivePrice
        then
            table.insert(candidates, packageId)
        end
    end
    return candidates
end

function ShopRewardManager:getAddStepTargetPackageId(addFivePrice)
    local candidatePackageIds = self:getAddStepCandidatePackageIds(addFivePrice)
    return candidatePackageIds[1]
end

function ShopRewardManager:isAddStepPackageDisplayable(giftData, addFivePrice)
    if not giftData or not giftData.getGoodsId then return false end

    local targetPackageId = self:getAddStepTargetPackageId(addFivePrice)
    return targetPackageId and (tonumber(giftData:getGoodsId() or -1) or -1) == (tonumber(targetPackageId or -2) or -2)
end

function ShopRewardManager:canShowAddStepPendant(stageInfo)
    if not self:isEnabled() then return false end
    if not self:isAddStepGroupEnabled() then return false end
    if not self:canCreateAddStepExposureByEndTime() then return false end
    if not self:isAddStepPayTagEnabled() then return false end

    local addFivePrice = stageInfo and stageInfo.addFiveBtnDisplayPrice
    return (tonumber(addFivePrice or 0) or 0) > 0
end

function ShopRewardManager:openActivity(closeCallback, params)
    if not self:isEnabled() then
        if closeCallback then closeCallback() end
        return
    end

    if not _G.amfBean("NetworkStatusManager"):isNetworkEnabled() then
        CommonTip:showTip("网络连接失败，请联网重试！")
        if closeCallback then closeCallback() end
        return
    end

    params = params or {}
    local accurateSource = params.source or _G.StoreConfig.AccurateSource.Click_Act_ShopReward_Icon
    if _G.StoreConfig and _G.StoreConfig.setAccurateSource and accurateSource then
        -- Also sets happyStoreStageShopSource for StoreStage package pull.
        _G.StoreConfig:setAccurateSource(accurateSource)
    end

    local storeManager = _G.amfBean("StoreManager")
    if storeManager and storeManager.showStorePanel then
        storeManager:showStorePanel({
            source = accurateSource,
            scrollPkgId = params.scrollPkgId or self:getTargetStorePackageId(),
            scrollTime = 0,
            scrollTopOffset = STORE_SCROLL_TOP_OFFSET,
        })
    end

    if closeCallback then closeCallback() end
end

return ShopRewardManager
