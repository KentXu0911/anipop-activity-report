
local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"
local Meta = require 'amf.feature.localactivity.merge.config.MergeConfig'
local BoardMeta = require 'amf.feature.localactivity.merge.config.BoardMeta'
local GiftMeta = require 'amf.feature.localactivity.merge.gift.GiftMeta'
-- local ServerData = require 'amf.feature.localactivity.merge.data.ServerData'
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"

local ACT_NAME = "merge"
local LOCAL_PATH = 'amf.feature.localactivity.'..string.lower( ACT_NAME )
local POWER_MULTIPLIER_UPGRADE_COUNT = {
    [1] = 0,
    [2] = 1,
    [4] = 2,
    [8] = 3,
}

local MergeManager = class("MergeManager", BaseFeatureManager)

MergeManager.ACT_OPEN_VERSION = 1  --如果此活动复用 此值应递增 以区分本地存储值

-- 主线
MergeManager.ACT_ID = 6074
MergeManager.ACT_SOURCE = "merge2025/Config.lua"
MergeManager.DCFeature = "happy_merge"
MergeManager.DCSource = "act_"..MergeManager.ACT_ID
MergeManager.ACT_CH_NAME = "美味合合"

function MergeManager:setAutoPopupMgr(autoPopupMgr)
    self.autoPopupMgr = autoPopupMgr
end

function MergeManager:_init()
    self.actId = MergeManager.ACT_ID

    self:initSubFunction()

    local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")
    IconTipEventCenter:register(IconTipEvent.CHECK_ICON_TIP, self.checkIconTip, self)

    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
    PropEventCenter:register(PropEvent.RESOLVE_ICON, self._onResolveIcon, self)
end

function MergeManager:_getExtraPlugsConfigList()
    return {
        {key = "AutoPop"},
        {key = "Panel"},
        {key = "Download"},
        {
            key = "ActSent",
            path = {
                plugPath = "amf.feature.localactivity.merge.plug.MergeSentPlug",
                const = self:_getConstPath()
            },
        },
        {
            key = "ActSend",
            path = {
                plugPath = "amf.feature.localactivity.merge.plug.MergeSendPlug",
                const = self:_getConstPath()
            },
        },
        {
            key = "ActExchangeReceiver",
            path = {
                plugPath = "amf.feature.localactivity.merge.plug.MergeExchangeReceiver",
            }
        },
        {
            key = "InciteReward",
            path = {
                plugPath = "amf.feature.localactivity.merge.plug.MergeInciteRewardPlug",
            }
        },
    }
end

function MergeManager:_getAutoPopConfigList()
    return {
        {
            checkPoint = PopupCheckPoint.MERGE_STAGE4_MAIN,
            actId = self.ACT_ID,
            stages = {AutoPopupConst.PopStage.STAGE_FOUR},
            check = function()
                if not self:isActivitySupported(self.ACT_ID) then return false end
                return not EnvUtil:isMiniGame()
                    and not self:ignoreForTopLevelPlayer()
                    and self:canPopInScene4()
            end,
            pop = function(_, onPopOver)
                return function()
                    self:popInScene4(onPopOver)
                end
            end,
        },
        {
            checkPoint = PopupCheckPoint.MERGE_MAIN_STAGE2,
            actId = self.ACT_ID,
            stages = {
                AutoPopupConst.PopStage.STAGE_TWO,
                AutoPopupConst.PopStage.STAGE_FOUR,
            },
            check = function()
                if not self:isActivitySupported(self.ACT_ID) then return false end
                return self:isEnabled()
            end,
            pop = function(_, onPopOver)
                return function()
                    self:openActivity(onPopOver, nil, false)
                end
            end,
        },
        {
            checkPoint = PopupCheckPoint.MERGE_DAILY_REWARD,
            actId = self.ACT_ID,
            stages = {AutoPopupConst.PopStage.STAGE_THREE},
            check = function()
                if not self:isActivitySupported(self.ACT_ID) then return false end
                return self:isEnabled()
                    and not self:ignoreForTopLevelPlayer()
                    and self:checkCanPopDailyGetRewardPanel() == true
            end,
            pop = function(_, onPopOver)
                return function()
                    if self:isEnabled() and self:checkCanPopDailyGetRewardPanel() then
                        self:tryPopDailyGetRewardPanel(onPopOver)
                    else
                        safeRunCall(onPopOver)
                    end
                end
            end,
        },
        {
            checkPoint = PopupCheckPoint.MERGE_STAGE4_SECONDARY,
            actId = self.ACT_ID,
            stages = {AutoPopupConst.PopStage.STAGE_FOUR},
            check = function()
                if not self:isActivitySupported(self.ACT_ID) then return false end
                return not self:ignoreForTopLevelPlayer() and self:canPopInScene5()
            end,
            pop = function(_, onPopOver)
                return function()
                    self:popInScene5(onPopOver)
                end
            end,
        },
    }
end

function MergeManager:_getModelPath()
    return LOCAL_PATH..'.model.MergeModel'
end

function MergeManager:_getConstPath()
    return LOCAL_PATH..'.config.MergeConfig'
end

function MergeManager:getData()
    return self:getModel()
end

function MergeManager:supportFrozenItem()
    -- 二期能力标记：Cocos 侧通过这个方法判断包内是否已支持冰冻棋子。
    return true
end

function MergeManager:supportPraiseFeedback()
    -- 二期能力标记：Cocos 侧通过这个方法判断包内是否已支持好评回馈。
    return true
end

-- 按当前倍率判定幸运产出，命中且目标棋子图鉴已开放时返回等级和棋子 ID。
function MergeManager:getLuckyLaunchLevel(powerMultiplier, itemId)
    if not itemId then return nil end

    local upgradeCount = POWER_MULTIPLIER_UPGRADE_COUNT[tonumber(powerMultiplier)]
    if upgradeCount == nil then return nil end

    local luckyLaunchConfig = self:getData():getLuckyLaunchConfig(upgradeCount + 1)
    if not luckyLaunchConfig then return nil end

    local showLuckRate = tonumber(luckyLaunchConfig.showLuckRate) or 0
    local luckRandomNum = math.random(1, 100)
    local launchCount = tonumber(self:getData():getLaunchCount()) or 0
    local showSuperCount = tonumber(self:getData():getShowSuperCount()) or 0
    if launchCount - showSuperCount <= self:getConst().LUCKY_LAUNCH_CD or luckRandomNum > showLuckRate then
        return nil
    end

    local weightedLevels = {}
    local totalWeight = 0
    for level, weight in pairs(luckyLaunchConfig.luckyFoodLevelWeights or {}) do
        local normalizedLevel = tonumber(level)
        local normalizedWeight = math.max(tonumber(weight) or 0, 0)
        if normalizedLevel and normalizedLevel >= 1 and normalizedWeight > 0 then
            table.insert(weightedLevels, {
                level = normalizedLevel,
                weight = normalizedWeight,
            })
            totalWeight = totalWeight + normalizedWeight
        end
    end
    if totalWeight <= 0 then return nil end
    table.sort(weightedLevels, function(left, right)
        return left.level < right.level
    end)

    local levelRandomNum = math.random() * totalWeight
    local accumulatedWeight = 0
    local findLevel
    for _, weightedLevel in ipairs(weightedLevels) do
        accumulatedWeight = accumulatedWeight + weightedLevel.weight
        if levelRandomNum < accumulatedWeight then
            findLevel = weightedLevel.level
            break
        end
    end
    if not findLevel then return nil end

    local superMakeId = BoardMeta:getItemLevelIdByItemId(itemId, findLevel)
    if not superMakeId then return nil end

    local bOpen = self:getData():checkChartInfo(superMakeId)
    if not bOpen then return nil end

    return findLevel, superMakeId
end

-- 按倍率沿合成链提升产物，1/2/4/8 倍分别前进 0/1/2/3 级。
function MergeManager:getMultiplierLaunchItemId(powerMultiplier, itemId)
    local upgradeCount = POWER_MULTIPLIER_UPGRADE_COUNT[powerMultiplier]
    if upgradeCount == nil or not itemId then return itemId end

    local resultItemId = itemId
    for _ = 1, upgradeCount do
        local itemData = BoardMeta:getItemDataByItemId(resultItemId)
        if not itemData or not itemData.nextId then break end
        resultItemId = itemData.nextId
    end
    return resultItemId
end

-- 保存并读取当前活动期内玩家上次选择的倍率（1/2/4/8）。
function MergeManager:getLocalPowerMultiplier()
    local powerMultiplier = tonumber(self:getFlagFromLocalByKeyInt(
        self:getConst().POWER_MULTIPLIER_LOCAL_KEY,
        false,
        true,
        0
    ))
    return POWER_MULTIPLIER_UPGRADE_COUNT[powerMultiplier] ~= nil and powerMultiplier or nil
end

function MergeManager:setLocalPowerMultiplier(powerMultiplier)
    powerMultiplier = tonumber(powerMultiplier)
    if POWER_MULTIPLIER_UPGRADE_COUNT[powerMultiplier] == nil then return false end

    self:saveFlagToLocalByKeyInt(
        self:getConst().POWER_MULTIPLIER_LOCAL_KEY,
        false,
        powerMultiplier,
        true
    )
    return true
end

-- 构建一次发射查询共用的同链信息和实时盘面数量，不生成逐格棋盘快照。
function MergeManager:buildLaunchItemQueryContext(itemId, boardItemSource)
    local targetItemId = tonumber(itemId)
    if not targetItemId or targetItemId <= 0 then return nil end
    if type(boardItemSource) ~= "table"
        or type(boardItemSource.forEachUsableNormalItem) ~= "function" then
        return nil
    end

    local targetItemData = BoardMeta:getItemDataByItemId(targetItemId)
    local targetLevel = targetItemData and tonumber(targetItemData.level)
    if not targetLevel or targetLevel < 1 then return nil end

    local orderedItemIds = {}
    local itemIdToLevelMap = {}
    local boardCountByItemId = {}
    local visitedItemIdSet = {}
    local currentItemId = targetItemId

    for level = targetLevel, 1, -1 do
        local key = tostring(currentItemId)
        if visitedItemIdSet[key] then return nil end
        visitedItemIdSet[key] = true

        local itemData = BoardMeta:getItemDataByItemId(currentItemId)
        if not itemData or not next(itemData) or tonumber(itemData.level) ~= level then
            return nil
        end

        orderedItemIds[level] = currentItemId
        itemIdToLevelMap[key] = level
        boardCountByItemId[key] = 0

        if level > 1 then
            local previousItemId = tonumber(itemData.preId)
            if not previousItemId or previousItemId <= 0 then return nil end

            local previousItemData = BoardMeta:getItemDataByItemId(previousItemId)
            if not previousItemData or not next(previousItemData)
                or tonumber(previousItemData.level) ~= level - 1
                or tonumber(previousItemData.nextId) ~= currentItemId then
                return nil
            end
            currentItemId = previousItemId
        end
    end

    boardItemSource:forEachUsableNormalItem(function(boardItemId)
        local normalizedId = tonumber(boardItemId)
        local key = normalizedId and tostring(normalizedId)
        if key and itemIdToLevelMap[key] then
            boardCountByItemId[key] = boardCountByItemId[key] + 1
        end
    end)

    return {
        targetItemId = targetItemId,
        targetLevel = targetLevel,
        orderedItemIds = orderedItemIds,
        itemIdToLevelMap = itemIdToLevelMap,
        boardCountByItemId = boardCountByItemId,
    }
end

local function addRequiredOrderItem(itemCountMap, itemIdToLevelMap, itemId, count, targetItemId, includeTargetItem)
    local normalizedId = tonumber(itemId)
    local normalizedCount = tonumber(count) or 1
    if not normalizedId or normalizedId <= 0 or normalizedCount <= 0 then return end
    if not includeTargetItem and normalizedId == targetItemId then return end

    local key = tostring(normalizedId)
    if itemIdToLevelMap[key] then
        itemCountMap[key] = (itemCountMap[key] or 0) + normalizedCount
    end
end

-- 返回同链低级棋子中第一个未被实时盘面库存满足的订单目标；默认不包含目标等级自身。
function MergeManager:getActiveOrderNeededItemId(queryContext, includeTargetItem)
    if type(queryContext) ~= "table" then return nil end
    includeTargetItem = includeTargetItem == true

    local orderedItemIds = queryContext.orderedItemIds
    local itemIdToLevelMap = queryContext.itemIdToLevelMap
    local boardCountByItemId = queryContext.boardCountByItemId
    local targetItemId = tonumber(queryContext.targetItemId)
    local targetLevel = tonumber(queryContext.targetLevel)
    if type(orderedItemIds) ~= "table"
        or type(itemIdToLevelMap) ~= "table"
        or type(boardCountByItemId) ~= "table"
        or not targetItemId or not targetLevel then
        return nil
    end

    local itemCountMap = {}
    local maxLevel = includeTargetItem and targetLevel or targetLevel - 1
    if maxLevel < 1 then return nil end
    for level = 1, maxLevel do
        itemCountMap[tostring(orderedItemIds[level])] = 0
    end

    local function addItem(itemId, count)
        addRequiredOrderItem(
            itemCountMap,
            itemIdToLevelMap,
            itemId,
            count,
            targetItemId,
            includeTargetItem
        )
    end

    local data = self:getData()

    -- 普通订单（包含机器订单）
    local orderSize = tonumber(data:getOrderSize()) or 0
    local foodOrders = data:getFoodOrders() or {}
    for orderIndex = 1, orderSize do
        local orderInfo = foodOrders[orderIndex]
        local orderMeta = orderInfo and data:getOrderMetaByOrderId(orderInfo.orderId)
        if orderMeta then
            local needItemList = orderMeta.randomTopFood
                and {orderInfo.randomNeedFoodId}
                or (orderMeta.needItemList or {})
            if orderIndex == 2 then
                local machineOrderInfo = data:getMachineOrderInfo()
                local orderStatus = machineOrderInfo and machineOrderInfo.orderStatus or {}
                for index, currentItemId in ipairs(needItemList) do
                    if not orderStatus[index] then
                        addItem(currentItemId)
                    end
                end
            else
                for _, currentItemId in ipairs(needItemList) do
                    addItem(currentItemId)
                end
            end
        end
    end

    -- 旅行小鸡：只统计已解锁且尚未填入的需求槽位。
    local chickenIsUnlocked = data:checkChickIsUnlock()
    local travelChick = chickenIsUnlocked and data:getTravelChick()
    local travelNeedItemIds = travelChick and travelChick.needItemIds or {}
    local travelItemStatus = travelChick and travelChick.status or {}
    for index, currentItemId in ipairs(travelNeedItemIds) do
        if travelItemStatus[index] == false then
            addItem(currentItemId)
        end
    end

    -- 年货订单（当前轮次的菜品和饺子）
    if data:limitOrderIsUnlock() then
        local limitOrderInfo = data:getLimitOrderInfo() or {}
        local currentIndex = (tonumber(limitOrderInfo.finishIndex) or -1) + 2
        local orderIds = limitOrderInfo.orderIds or {}
        local orderId = currentIndex >= 1 and currentIndex <= #orderIds and orderIds[currentIndex]
        local orderMeta = orderId and data:getYearOrderMetaByOrderId(orderId)
        for _, currentItemId in ipairs(orderMeta and orderMeta.needItemList or {}) do
            addItem(currentItemId)
        end
        addItem(limitOrderInfo.specialItemIds and limitOrderInfo.specialItemIds[currentIndex])
    end

    -- 甄嬛订单
    if self:canShowQueenOrder() then
        for _, currentItemId in ipairs(data:getQueenOrderItemList() or {}) do
            addItem(currentItemId)
        end
    end

    -- 皇帝订单
    if self:canShowKingOrder() then
        for _, currentItemId in ipairs(data:getKingOrderItemList() or {}) do
            addItem(currentItemId)
        end
    end

    -- 订单 5（顶级菜品清理订单）
    if self:canShowTopFoodCleanOrder() then
        for _, currentItemId in ipairs(data:getTopFoodCleanOrderItemList() or {}) do
            addItem(currentItemId)
        end
    end

    -- 好评回馈订单 6
    if self:canShowPraiseFeedbackOrder6() then
        for _, currentItemId in ipairs(data:getPraiseFeedbackOrder6ItemList() or {}) do
            addItem(currentItemId)
        end
    end

    -- 好礼连连订单。有效态只由服务端 orderIndex 和当前订单数据决定，不在这里猜 endTime 单位。
    if self:canShowGoodGiftOrder() then
        for _, currentItemId in ipairs(data:getGoodGiftOrderItemList() or {}) do
            addItem(currentItemId)
        end
    end

    -- 旧限时订单已废弃，不参与统计。

    for level = 1, maxLevel do
        local currentItemId = orderedItemIds[level]
        local key = tostring(currentItemId)
        local remainingCount = itemCountMap[key] - (tonumber(boardCountByItemId[key]) or 0)
        if remainingCount > 0 then
            return currentItemId
        end
    end
    return nil
end

-- 模拟同链低级棋子两两合成，返回未凑整的最低等级棋子。
function MergeManager:getSmartLevelRemainingItemId(queryContext)
    if type(queryContext) ~= "table" then return nil end

    local targetLevel = tonumber(queryContext.targetLevel)
    local orderedItemIds = queryContext.orderedItemIds
    local boardCountByItemId = queryContext.boardCountByItemId
    if not targetLevel or targetLevel <= 1
        or type(orderedItemIds) ~= "table"
        or type(boardCountByItemId) ~= "table" then
        return nil
    end

    local levelCountMap = {}
    for level = 1, targetLevel - 1 do
        levelCountMap[level] = tonumber(boardCountByItemId[tostring(orderedItemIds[level])]) or 0
    end

    for level = 1, targetLevel - 1 do
        local currentCount = levelCountMap[level]
        local upgradeCount = math.floor(currentCount / 2)
        levelCountMap[level] = currentCount % 2
        if level + 1 < targetLevel then
            levelCountMap[level + 1] = levelCountMap[level + 1] + upgradeCount
        end
    end

    for level = 1, targetLevel - 1 do
        if levelCountMap[level] > 0 then
            return orderedItemIds[level]
        end
    end
    return nil
end

-- 非引导饺子生成；powerCost 为本次主产物实际体力消耗。
function MergeManager:getJiaoziLaunchResult(powerCost, makeExtraItem)
    if not makeExtraItem or not makeExtraItem.id then
        return nil, false
    end

    local data = self:getData()
    local curWeek = data:getCurWeek()
    local limitOrderInfo = data:getLimitOrderInfo() or {}
    local orderIndex = (tonumber(limitOrderInfo.finishIndex) or -1) + 2
    local specialItemId = limitOrderInfo.specialItemIds and limitOrderInfo.specialItemIds[orderIndex]
    local specialItemData = specialItemId and BoardMeta:getItemDataByItemId(specialItemId)
    local specialItemLevel = specialItemData and tonumber(specialItemData.level)
    local bInPk = (tonumber(limitOrderInfo.pkRound) or 0) > 0
    local specialConfig
    if data:isInLimitOrderTime() and specialItemLevel then
        local powerLevel = self:getConst().POWER_LEVEL_BY_MULTIPLIER[tonumber(powerCost)]
        if powerLevel then
            specialItemLevel = math.min(specialItemLevel, powerLevel)
        end
        specialConfig = data:getJiaoziSpecialLaunchConfig(powerLevel, specialItemLevel, bInPk)
    end

    if specialConfig then
        local makeLevel = tonumber(specialConfig.makeLevel)
        local percent = tonumber(specialConfig.percent)
        local levelItemList = makeLevel and BoardMeta.jiaoziLevelList[makeLevel]
        local jiaoziId = levelItemList and (levelItemList[curWeek] or levelItemList[1])
        if percent and jiaoziId then
            percent = math.max(0, math.min(percent, 100))
            if math.random(1, 100) <= percent then
                return jiaoziId, true
            end
            return nil, true
        end
    end

    local makePercent = tonumber(makeExtraItem.percent) or 0
    if bInPk then
        makePercent = tonumber(makeExtraItem.pkPercent) or makePercent
    end
    makePercent = math.max(0, math.min(makePercent, 100))
    if math.random(1, 100) > makePercent then
        return nil, false
    end

    local jiaoziId = BoardMeta:getJiaoziIdByWeek(curWeek, makeExtraItem.id)
    return jiaoziId, false
end

function MergeManager:passDayRefreshData()
    if not self:isEnabled() then return end
    self:getData():passDayClear()
    self:notify( self:getBaseEvent().kCloseAllPanel )
end

function MergeManager:onActPassDay()
    self:_checkAndNotifyPassDayOnInit()
end

function MergeManager:onActActInfoUpdate(event)

    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(MergeManager.ACT_ID)]

    if not actInfo and fromServer then
        -- self:getData():reset()
        local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
        ActivityEventCenter:dispatch(ActivityEvent.REMOVE_ACTIVITY,{actId = MergeManager.ACT_ID})
        return
    end

    if actInfo and fromServer then
        self:registerGiftModule()
    end
end

function MergeManager:initSubFunction()
    local MergeGiftModule = require 'amf.feature.localactivity.merge.module.MergeGiftModule'
    self.giftPart = MergeGiftModule.new(self)

    local MergeManager_http = require 'amf.feature.localactivity.merge.MergeManager_http'
    self.httpPart = MergeManager_http:create(self)
    self.httpPart:initLaunchAndMergeList()

    local MergeManager_orderPop = require 'amf.feature.localactivity.merge.MergeManager_orderPop'
    self.orderPopPart = MergeManager_orderPop:create(self)
    self.orderPopPart:initOrderCompleteInfo()
end

--  注册礼包module
function MergeManager:registerGiftModule()
    if not self.giftRegisted then
        local GiftEventCenter = require "amf.feature.giftpackage.event.GiftEventCenter"
        GiftEventCenter:registerCustomModule(self.giftPart, GiftPackageConst.StageType.ACTIVITY)
        self.giftRegisted = true
    end
end

function MergeManager:isEnabled()
    if (self:getData():isInMainTime() ) then
        return true
    else
        return false
    end
end

function MergeManager:isEnabledOnlyTime()
    if (self:getData():isInMainTime() or self:getData():isInRewardTime())then
        return true
    else
        return false
    end
end

function MergeManager:isEnabled2()
    if (self:getData():isInMainTime() or self:getData():isInRewardTime() )  then
        return true
    else
        return false
    end
end

function MergeManager:getActInfo()
	local actInfo = _G.amfBean("ActivityMgr"):getActInfo(self.ACT_ID)
    return actInfo
end

function MergeManager:fromServer(data, config )

    if not self.downloadPlug:checkDownloadSuccess() then
        self.downloadPlug:startDownload(function()
            UICreateUtil:loadPlist(BoardMeta.BoardItemsPlistPath)
        end)
    end

    self:getData():fromServer(data,config)
end

function MergeManager:commonCreateIcon( reward, needNum, scale, noDoubleFlag, bUseScale60 )
    --通用创建icon
    local allBoardItemList = BoardMeta:getAllItemList()
    local otherItemList = {Meta.CollectionId,Meta.MoneyId, Meta.hammerId, Meta.DoubleBuffId}

    if noDoubleFlag == nil then noDoubleFlag = false end

    local icon

    if ( table.exist( allBoardItemList, reward.itemId )) and bUseScale60 then
        --棋盘道具
        --棋盘道具不参与整体缩放，要自己控制
        icon = Layer:create()
        icon:ignoreAnchorPointForPosition(false)
        icon:setAnchorPoint(ccp(0.5,0.5))
        icon:setContentSize(CCSizeMake(126,126))

        local spName = BoardMeta:getMergeItemSpNameByScale( reward.itemId, bUseScale60, self:getData():getCurWeek() )
        local item = UICreateUtil:createSpriteWithPlist(BoardMeta.BoardItemsPlistPath, spName)
        local itemData = BoardMeta:getItemDataByItemId( reward.itemId )
        item:setScale(0.9)
        item.innerScale = 1
        item:setPositionXY(126/2,126/2)
        icon.item = item
        icon:addChild(item)

        if needNum then
            local numWidget = AMFCompHelper:createPropNum( reward )
            icon:addChild(numWidget)
            icon.numWidget = numWidget
        end
    elseif reward.itemId == Meta.DoubleBuffId and noDoubleFlag then
        --加分buff
        icon = Layer:create()
        icon:ignoreAnchorPointForPosition(false)
        icon:setAnchorPoint(ccp(0.5,0.5))
        icon:setContentSize(CCSizeMake(126,126))

        local item = UICreateUtil:createSpriteWithPlist(BoardMeta.BoardItemsPlistPath, "mergeItems/collect.png")
        item:setScale( 0.9 )
        item:setPositionXY(126/2,126/2)
        icon.item = item
        icon:addChild(item)

        local p = AMFCompHelper:createInfiniteTimeLimitWidget(reward,false,true)
        icon:addChild(p)
        item.timeFlag = p

    else
        local r = table.clone(reward)
        r.needNum = needNum
        icon = GameItemCreator:getPropIcon(r)
    end

    if scale then
        icon:setScale(scale)
    end

    return icon
end

function MergeManager:addRewardsForShop( newRewards, source, dateAddEndCall, evt )
    local subData = {
        evt = evt,
        feature = MergeManager.DCFeature,
        source = source or 'act_'..MergeManager.ACT_ID,
        rewardDirectList = table.clone(newRewards),
        endCall = function(callData)
            self:addRewards( callData.rewardDirectList, source )
            safeRunCall(dateAddEndCall, callData)
        end
    }
    _G.amfTransaction(TransactionEvent.EXCHANGE_SHOP_TASK, {
        subCmd = "processEvent",
        subData = subData,
    })
end

function MergeManager:addRewards( rewards, source, extraMap )

    local dcFeature = MergeManager.DCFeature
    local dcSource = source or 'act_'..MergeManager.ACT_ID
    if extraMap == nil then extraMap = {} end

    _G.GainPropData:create():setFeature(dcFeature):setSource(dcSource):setProps(rewards):setExtraMap(extraMap):execute()
end

function MergeManager:hasReward()
    return self:hasRewards()
end

function MergeManager:canGetDailyRestaurantRatingReward()
    return self:getData():checkCanGetRestaurantRatingReward()
end

function MergeManager:canShowDailyRestaurantRatingIcon()
    if not self:isEnabled() then return false end
    return self:getData():canShowRestaurantRatingIcon()
end

function MergeManager:canGetPraiseFeedbackReward()
    -- 好评回馈奖字入口。具体可领判断在 MergeModel 内，Manager 只负责接入外层 hasRewards。
    if not self:supportPraiseFeedback() then return false end
    return self:getData():checkCanGetPraiseFeedbackReward()
end

function MergeManager:getRestaurantPraiseData()
    -- 好评回馈主数据桥接，供活动侧跨包读取 restaurantPraiseData。
    return self:getData():getRestaurantPraiseData()
end

function MergeManager:getFrozenFoodBuyPowerGoodsIdSet()
    -- 冰冻棋子购买体力 goodsId 集合可能不下发，统一由模型返回空表兜底。
    return self:getData():getFrozenFoodBuyPowerGoodsIdSet()
end

function MergeManager:canShowPraiseFeedbackIcon()
    -- 倒计时旁好评回馈入口是否展示。活动未开启或二期能力未启用时不展示。
    if not self:isEnabled() or not self:supportPraiseFeedback() then return false end
    return self:getData():canShowPraiseFeedbackIcon()
end

function MergeManager:getPraiseFeedbackOrderLikeInfo(orderType, orderIndex, orderData)
    -- 订单小手信息桥接。具体只认订单数据上的 praiseNum，旧字段不在包内推导。
    return self:getData():getPraiseFeedbackOrderLikeInfo(orderType, orderIndex, orderData)
end

function MergeManager:getPraiseFeedbackOrder6Data()
    -- 好评回馈专属订单 6 数据桥接，不复用订单 5 数据源。
    return self:getData():getPraiseFeedbackOrder6Data()
end

function MergeManager:canShowPraiseFeedbackOrder6()
    -- 订单 6 展示判断桥接。数据缺失或订单已完成时由 Model 返回 false。
    if not self:supportPraiseFeedback() then return false end
    return self:getData():canShowPraiseFeedbackOrder6()
end

function MergeManager:hasRewards()
    if not self:isEnabled2() then return false end

    if self:getData():isInMainTime() then
        -- 有实物且没填地址
        local bHasNationRewards = self:getData():checkHasGetRealItem()
        local bFillAddress = self:getData():getContact()

        --进度奖励未领取
        local bHasProgressReward = self:getData():checkHasProgressReward()
        --体力比拼
        local pkCanGetReward = self:getData():checkHasEnergyPKRankReward() or self:getData():checkHasEnergyPKCostReward()
        --每日订单完成奖励
        local limitCanGetReward = self:getData():checkCanGetLimitOrderReward()
        --图鉴体力，头像框
        local canShowBook = self:canShowBook()
        local bChartCanGetReward = canShowBook and self:getData():checkChartCanGetReward()
        local bCanGetChartAllReward = canShowBook and self:getData():checkCanGetHeadFrameReward()
        --商店每日免费
        local bCanGetDailyReward = self:canShowShop() and self:getData():checkFreeItemCanGet()
        --旅行小鸡
        local bCanGetTravalReward = self:getData():checkCanGetTravalReward()
        -- 厨神
        local bCanGetMatchReward = self:getData():checkCanGetMatchReward()

        -- pk必须非同日且没结算pkReward
        local pkReward = (not self:isCurLimitOrderSameDay()) and self:getData():checkLimitOrderPKReward()
        local bContinueWinReward = self:getData():checkPKContinueWinReward()
        local bOpenEggFinalReward = self:getData():checkOpenEggBigReward()
        local bOpenEggFreeGift = self:getData():canGetOpenEggDataFreeGiftCnt() > 0
        local bCanGetDailyRestaurantRatingReward = self:canGetDailyRestaurantRatingReward()
        local bCanGetPraiseFeedbackReward = self:canGetPraiseFeedbackReward()

        return (bHasNationRewards and not bFillAddress) or bHasProgressReward or pkCanGetReward or limitCanGetReward or bChartCanGetReward or bCanGetDailyReward or bCanGetChartAllReward
            or bCanGetTravalReward or bContinueWinReward or bOpenEggFinalReward or bOpenEggFreeGift or pkReward or bCanGetMatchReward
            or bCanGetDailyRestaurantRatingReward or bCanGetPraiseFeedbackReward
    end

    if self:getData():isInRewardTime() then
        -- 有实物且没填地址
        local bHasNationRewards = self:getData():checkHasGetRealItem()
        local bFillAddress = self:getData():getContact()
        -- 小组榜奖励且钱够
        local groupRank = self:getData():getCurGroupRank()
        local moneyNum = self:getData():getMoney()
        local bHasGetGroupReward = self:getData():checkHasGetGroupRankReward()
        local bHasGroupReward = false--not bHasGetGroupReward and groupRank > 0 and groupRank <= 7 and moneyNum > 1500
        -- 进度奖励
        local bHasProgressReward = self:getData():checkHasProgressReward()
        -- 体力比拼奖励
        local pkCanGetReward = false--self:getData():checkHasEnergyPKRankReward()
        -- 头像框奖励
        local bCanGetChartAllReward = self:getData():checkCanGetHeadFrameReward()
        -- 体力折算奖励
        local energy = self:getData():getPowerTotal()
        local canConvert = energy > 0 and not self:getData():getHasConvert()
        -- 厨神领奖期不结算
        local bCanGetMatchReward = false -- self:getData():checkCanGetMatchReward()

        return (bHasNationRewards and not bFillAddress) or bHasGroupReward or bHasProgressReward or pkCanGetReward
            or bCanGetChartAllReward or canConvert or bCanGetMatchReward
    end

    return false
end

function MergeManager:getMsgNum()
    return self:getShowMsgNum()
end

function MergeManager:getShowMsgNum()
    if not self:isEnabled2() then return 0 end

    if self:getData():isInMainTime() then
        local msgNum = self:getData():getPowerTotal()
        -- if msgNum > 999 then msgNum = 999 end
        return msgNum
    end

    return 0
end

function MergeManager:getDcFeatureAndSource( suffix )
    return MergeManager.DCFeature, suffix
end

function MergeManager:setFlyFunc( rewards, collectWorldPos )
    for _,reward in ipairs(rewards) do
        local endWorldPos
        local createFakeIcon

        if reward.itemId == Meta.CollectionId or reward.itemId == Meta.DoubleBuffId then
            -- endWorldPos = collectWorldPos
            --也不飞了
        elseif reward.itemId == Meta.ScoreBuff20Id or reward.itemId == Meta.ScoreBuff50Id then
            --不飞
        end

        if endWorldPos then
            reward.flyFunc = function (reward,worldPos,scale,callBack)
                local saveScale = scale
                local saveCallBack = callBack

                if type(saveScale) == 'function' then
                    callBack = saveScale
                end

                if type(saveCallBack) == 'number' then
                    scale = saveCallBack
                end

                local iconCreator = function()
                    return self:commonCreateIcon(reward)
                end
                local RewardFlyHelper = require 'amf.feature.localactivity.processgiftautopopup.RewardFlyHelper.lua'
                RewardFlyHelper:rewardFlyFunc(true,reward,worldPos,ccpAdd(endWorldPos,ccp(0,-0)),iconCreator,callBack,CCSizeMake(30,30),createFakeIcon,scale)
            end
        end
    end
end

--孙文
function MergeManager:createMScrollView(delegate)
    local MScrollView = require 'amf.feature.localactivity.merge.gift.MScrollView'
    local ret = MScrollView:create(delegate)
    return ret
end


----------------------关卡内-----------------------------

--收集物双倍BUff结束时间
function MergeManager:getTimeLimitRateEndTime()
    local buffEndTime = self:getData():getMoneyBuffEndTime()
    return buffEndTime or 0
end

--关卡内活动启动数据
function MergeManager:getInLevelActData(levelId, runtime)
    local inLevelActData = {}
    local buffEndTime = self:getTimeLimitRateEndTime()
    --是否有限时buff
    inLevelActData.hasTimeLimiteBuff = buffEndTime > TimeKit:timeInMillis()
    --限时buff结束时间
    inLevelActData.buffEndTime = buffEndTime

    inLevelActData.isFirstPlay = false
    local isFullLevelLibrary = runtime.levelScene == LevelScene.kFullLevelLibrary
    if isFullLevelLibrary then
        inLevelActData.isFirstPlay = self:isFullStarLevelLibFirstPlay()
    end
    -- printx(15,"mergeact2024",tts(inLevelActData))
    return inLevelActData
end

function MergeManager:getScoreBuffRate()
    local buffRate = 0
    if self:getData():checkIsHaveScoreBuff20() then
        buffRate = buffRate + 0.2
    end

    if self:getData():checkIsHaveScoreBuff50() then
        buffRate = buffRate + 0.5
    end
    -- printx(15,"buffRate",buffRate)
    return buffRate
end

function MergeManager:getScoreBuffEndTime()
    local buff20EndTime = self:getData():getScoreBuff20EndTime() or 0
    local buff50EndTime = self:getData():getScoreBuff50EndTime() or 0

    buff20EndTime = buff20EndTime > TimeKit:timeInMillis() and buff20EndTime or 0
    buff50EndTime = buff50EndTime > TimeKit:timeInMillis() and buff50EndTime or 0
    -- printx(15,"buff20EndTime,buff50EndTime",buff20EndTime,buff50EndTime)
    if buff50EndTime > 0 and buff20EndTime > 0 then
        return math.min(buff20EndTime, buff50EndTime)
    else
        return math.max(buff20EndTime, buff50EndTime)
    end

    return 0
end

--------------------关卡内over---------------------------


---------------------zonghao------------------------------------

-- 检查活动是否过了最后一周
-- 根据目前设计，最后一周后，领奖期前有10个小时无小活动时间
function MergeManager:checkTimeExceedLastWeek()
    local ret = TimeUtil:isSameDay(self:getEndTime(), TimeKit:timeInSec())
    return ret
end

-- 拿第几个实物，这里realCntPerWeek一周两种实物
function MergeManager:getCurWeekRealItemInfo(idx, realCntPerWeek)
    if not realCntPerWeek then
        realCntPerWeek = 2
    end
    -- 第三周后，领奖期前的10个小时
    local weekNum = self:getData():getCurWeek()
    local isAwardDay = self:checkTimeExceedLastWeek()
    if isAwardDay then
        weekNum = 3
    end

    local itemIndex = (weekNum-1)*realCntPerWeek + idx
    local itemId = Meta.RealItemIds[itemIndex]
    local itemInfo = Meta.RealItemInfo[itemId]
    return itemId, itemInfo
end

function MergeManager:saveValueToLocalByKey(outerKey, innnerKey, needTime, value)
    if not outerKey then return end
    if not innnerKey then return end

    local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())

    local saveValue = {
        time = nowTime,
        value = value
    }

    local saveRecordTableStr = self:getData():getValue(outerKey) or "{}"
    local saveRecordTable = table.deserialize(saveRecordTableStr)
    saveRecordTable[innnerKey] = saveValue
    saveRecordTableStr = table.serialize(saveRecordTable)

    self:getData():setValue(outerKey, saveRecordTableStr, true)
end

function MergeManager:getValueFromLocalByKey(outerKey, innnerKey, needTime)
    if not outerKey then return end
    if not innnerKey then return end

    local saveRecordTableStr = self:getData():getValue(outerKey) or "{}"
    local saveRecordTable = table.deserialize(saveRecordTableStr)

    local saveValue = saveRecordTable[innnerKey]
    if saveValue == nil then return end

    local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())
    local bTimeIsOk = true

    -- 需要检查是否同一天 且 时间不同
    if needTime and saveValue.time ~= nowTime then
        bTimeIsOk = false
    end

    -- 检查是否同一天 且 不是同一天 返回空
    if needTime and not bTimeIsOk then
        return
    else
        return saveValue.value
    end
end

-- 在新关开启的指定时间内（暂定4小时），玩家主线关满星前，闯头部新关不触发关卡内结算面板点叉的场景4强弹
function MergeManager:ignoreForTopLevelPlayer()
    local userState = _G.amfBean("UserStateManager"):getUserSegmentState()
    if userState == _G.UserStateConst.UserLevelState.MHZC then
        return false
    end

    local topLevelId = _G.getTopLevelId()
    if not _G.amfBean("LevelUnLockManager"):isTopNewMainLevel(topLevelId) then
        return false
    end

    if not _G.amfBean("LevelUnLockManager"):isInNewLevelTime() then
        return false
    end

    return true
end

function MergeManager:isCurLimitOrderSameDay(limitOrderData)
    if not limitOrderData then
        limitOrderData = self:getData():getLimitOrderInfo()
    end
    if not limitOrderData or (not next(limitOrderData)) then
        return false
    end
    local curOrderDay = TimeUtil:getDayIdxSince1970(math.floor(limitOrderData.createTime/1000))
    local todayIdx = TimeUtil:getDayIdxSince1970(TimeKit:timeInSec())
    return todayIdx == curOrderDay
end

function MergeManager:todayTryOpenPreheatGetReward()
    return self:getFlagFromLocalByKey("todayTryOpenPreheatGetReward", true, true, false)
end

function MergeManager:setTodayTryOpenPreheatGetReward()
    self:saveFlagToLocalByKey("todayTryOpenPreheatGetReward", true, true, true)
end

function MergeManager:getPreHeatSaoGuang()
    return self:getFlagFromLocalByKey("saoGuangFlag", true, true, false)
end

function MergeManager:setPreHeatSaoGuang()
    self:saveFlagToLocalByKey("saoGuangFlag", true, true, true)
end

function MergeManager:getSaoGuangIndex()
    local cnt = self:getFlagFromLocalByKeyInt("saoGuangCnt", true, true, 0)
    return cnt
end

function MergeManager:setSaoGuangIndex(index)
    self:saveFlagToLocalByKeyInt("saoGuangCnt", true, index, true)
end

function MergeManager:isFullStarLevelLibFirstPlay()
    local fullStarLevelLibManager
    if EnvUtil:isAMFEnabled() then
        -- AMF
        fullStarLevelLibManager = _G.amfBean("FullStarLevelLibManager"):getModel()
    else
        -- 老app
        if FullStarLevelLibManager then
            fullStarLevelLibManager = FullStarLevelLibManager:getInstance()
        end
    end
    if not fullStarLevelLibManager then return nil end
    return fullStarLevelLibManager:getContinuousLose() == 0
end

-- 得到打关体力收集物数量
function MergeManager:getCollectItemCnt()
    local UserStateManager = _G.amfBean("UserStateManager")
    -- 满级满彩星
    if UserStateManager and (not UserStateManager:isFMJ()) and UserStateManager:isColorfulStarFull() then
        local cnt = Meta.PowerCollectItemConfig.firstlevelLib

        local isFirstPlay = self:isFullStarLevelLibFirstPlay()
        -- 非首闯10个
        if not isFirstPlay then
            cnt = Meta.PowerCollectItemConfig.levelLib
        end

        -- printx(42, "关卡库cnt", cnt)
        return cnt
    end
    local configTopLevel = _G.amfBean("LevelUnLockManager"):getLocalTopLevel(true)
    local userTopLevel = _G.amfBean("LevelAreaManager"):getTopPassedMainLevelId() + 1
    if userTopLevel > configTopLevel-45 then
        return Meta.PowerCollectItemConfig.undertop
    elseif userTopLevel > configTopLevel - 90 and userTopLevel <= configTopLevel-45 then
        return Meta.PowerCollectItemConfig.under30
    else
        return Meta.PowerCollectItemConfig.under60
    end
end

--主面板打开次数
function MergeManager:addEnterMainPanelTimes()
    local cnt = self:getEnterMainPanelTimes()
    self:saveFlagToLocalByKeyInt("MainPanelOpenTimes",true, cnt+1)
end

--获取主面板打开次数
function MergeManager:getEnterMainPanelTimes()
    return self:getFlagFromLocalByKeyInt("MainPanelOpenTimes", true)
end

-- 获取玩家全国排名
function MergeManager:getCurCountryRank()
    return self:getData():getCurCountryRank()
end

-- 获取玩家小组排名
function MergeManager:getCurGroupRank()
    return self:getData():getCurGroupRank()
end

function MergeManager:getActivityIcon()
    return self.actPlug:getActIcon()
end

function MergeManager:showIconAwardBar(callback)
    self:showIconTip({
        tipsType = HomeIconTipsType.NORMAL_CIRCLE,
        text = "点击领取奖励！",
        grayDi = true,
        iconCreate = function()
            local iconLayer = Layer:create()
            local iconSpine = UICreateUtil:createSpriteFile("amf/activity/merge/materials/chikenBackIcon.png")
            iconSpine:setAnchorPoint(ccp(0.5,0.5))
            iconLayer:addChild(iconSpine)
            return iconLayer
        end,
        iconTouchCallback = function()
            self:openMainActivity(callback, {from = "choutiao"}, true)
        end
    })

    -- if EnvUtil:isCocos() then
    --     local icon=self:getActivityIcon()
    --     if not icon then
    --         safeRunCall(callback)
    --         return
    --     end

    --     local tip

    --     local data = {}
    --     data.tipsType = HomeIconTipsType.normalCircle
    --     data.targetIcon =  icon
    --     data.text = "点击领取奖励！"
    --     data.iconOffset = ccp(0,0)
    --     data.grayDi = true
    --     data.iconCreate = function()
    --         local iconLayer = Layer:create()
    --         local iconSpine = UIHelper:createSpriteFile("amf/activity/merge/materials/chikenBackIcon.png")
    --         iconSpine:setAnchorPoint(ccp(0.5,0.5))
    --         iconLayer:addChild(iconSpine)
    --         return iconLayer
    --     end
    --     data.iconTouchCallback = function()
    --         if tip and tip.remove then
    --             tip:remove()
    --         end
    --         self:openMainActivity(callback, {from = "choutiao"}, nil, true)
    --     end
    --     tip = HomeIconTipsFactory:createTipsByDelegate(data)
    -- else
    --     safeRunCall(callback)
    -- end
end

function MergeManager:canPopInScene4()
    --礼包
    if not self:isEnabled() then return false end
    return self:checkPopState4Gift()
end

function MergeManager:canPopInScene5()
    --引流
    if not self:isEnabled() then return false end
    return self:checkCanPopYinliu()
end

function MergeManager:checkCanPopYinliu()
    if not self:isEnabled() then return false end
    local data = self:getData()
    local energy = data:getPowerTotal()
    local hasUseEnergy = data:checkChartInfo(BoardMeta.ItemLanMei)
    local popTime = self:getFlagFromLocalByKeyInt("yinLiuPopCnt", true, true)
    return energy > 100 and hasUseEnergy and popTime < 2
end

function MergeManager:popInScene4(onHandleOver)
    if not self:isEnabled() then safeRunCall(onHandleOver) return end

    local canPopGift = self:checkPopState4Gift()
    if not canPopGift then
        safeRunCall(onHandleOver)
        return
    end

    local getGoodsIdFunc = function(goodsId, checkBox)
        if not goodsId then
            safeRunCall(onHandleOver)
            return
        end
        self:addPopStage4GiftTime(1)
        self:saveTodayPopedGiftList(goodsId)
        self.giftPart:clearPassLevelTimeTody()
        self:popGiftPanel({
            goodsId = goodsId,
            closeCall = onHandleOver,
            checkBox = checkBox,
        })
    end

    -- 请求服务器礼包，成功后走打开面板，失败继续强弹流程
    self.giftPart:_popStage4GoodsIdGet(getGoodsIdFunc)
end

function MergeManager:popInScene5(onHandleOver)
    if not self:isEnabled() then safeRunCall(onHandleOver) return end

    if self:checkCanPopYinliu() then
        local popTime = self:getFlagFromLocalByKeyInt("yinLiuPopCnt", true, true)
        self:saveFlagToLocalByKeyInt("yinLiuPopCnt", true, popTime + 1, true)
        self:showMergeActYinLiuPanel({
            closeCallback = onHandleOver
        })
    else
        safeRunCall(onHandleOver)
    end
end

function MergeManager:canPopInScene6()
    local popCnt = self:getFlagFromLocalByKeyInt("Merge_power_full_pop_tip", true, true)
    if popCnt < 3 and self:getData():getPowerTotal() >= Meta.MaxPowerConfig then
        return true
    end
    return false
end

function MergeManager:popInScene6(onHandleOver)
    if not self:isEnabled() then safeRunCall(onHandleOver) return end

    if self:canPopInScene6() then
        self:showIconTip({
            text = "体力已达上限！"
        }, {
            popFunc = function()
                local popCnt = self:getFlagFromLocalByKeyInt("Merge_power_full_pop_tip", true, true)
                self:saveFlagToLocalByKeyInt("Merge_power_full_pop_tip", true, popCnt + 1, true)
            end,
        })
    end
    -- setTimeOut(onHandleOver, 3)
end

-- function MergeManager:onActAfterAutoPopupEnd(params)
--     if EnvUtil:isCocos() then
--         local lastPopStage = nil
--         if params and params:getData() then
--             lastPopStage = params:getData().lastPopStage
--         end
--         if not self:isEnabled() then return false end
--         -- 不是场景2，4就返回
--         if lastPopStage ~= AutoPopupConst.PopStage.kEnterFromOutside
--             and lastPopStage ~= AutoPopupConst.PopStage.kEnterFromLevel2nd then
--                 return
--         end
--         local scene = Director:sharedDirector():run()
--         if scene == nil or not scene:is(HomeScene) then return end
--         if self:ignoreForTopLevelPlayer() then return end
--         if PopoutManager:sharedInstance():haveWindowOnScreenWithoutCommonTip() then return end

--         local stageNum = 4
--         if lastPopStage == AutoPopupConst.PopStage.kEnterFromOutside then
--             stageNum = 2
--         end

--         self:popIconTipFunc(nil, stageNum)
--     else
--     end

-- end

-- 料理机完成菜品
function MergeManager:canShowLiaoli()
    local mOrderInfo = self:getData():getMachineOrderInfo()
    if mOrderInfo and mOrderInfo.bCanGetReward then
        local history = self:getFlagFromLocalByKeyStr("MergetAct_orderHistory", true)
        local hisTb
        if #history > 0 then
            hisTb = table.deserialize(history)
        else
            hisTb = {}
        end
        if not table.exist(hisTb, mOrderInfo.showItemId) then
            table.insert(hisTb, mOrderInfo.showItemId)
            self:saveFlagToLocalByKeyStr("MergetAct_orderHistory", true, table.serialize(hisTb))
            local itemData = BoardMeta:getItemDataByItemId(mOrderInfo.showItemId)
            local str0 = BoardMeta:getCaiPinNameByType(itemData.itemType)
            local str = str0 .. "完成，提交订单吧！"
            return str
        end
    end
    return nil
end

-- 满精力
function MergeManager:canShowEnergyFull()
    local power = self:getData():getPowerTotal()
    if power >= self:getData():getAutoAddMaxPowerConfig()  then
        local powerHis = self:getFlagFromLocalByKeyInt("Merge_powerTotal")
        if powerHis < self:getData():getPowerTipPowerConfig() then
            self:saveFlagToLocalByKeyInt("Merge_powerTotal", false, power)
            local str = "体力已满，快来合成吧！"
            return str
        end
    end
    return nil
end

-- 皇帝订单是否可以展示
function MergeManager:canShowKingTip()
    if not self:isEnabled() then return false end
    local kingData = self:getData():getActiveKingOrderInfo()
    if table.isEmpty(kingData) then return false end
    local leftTime = kingData.endTime - TimeKit:timeInMillis()
    local ret = false
    local min = 0
    -- 第三个订单是否完成
    local thirdOver = kingData.orderIndex == Meta.KING_ORDER_TIP_THIRD_ORDER_INDEX
    local key = nil
    -- 小于30分钟
    if leftTime < 30 * 60 * 1000 then
        -- 第一个订单是否完成
        local firstOver =  kingData.orderIndex == 1
        if firstOver and not thirdOver then
            ret = true
            min = 30
            key = "iconTipKing_30"
        end
    elseif leftTime < 60 * 60 * 1000 then
        -- 小于60分钟
        if not thirdOver then
            ret = true
            min = 60
            key = "iconTipKing_60"
        end
    end
    local popCnt = 1
    if key then
        popCnt = self:getFlagFromLocalByKeyInt(key, true, nil, 0)
    end
    if ret and popCnt < 1 then
        return ret, min, key
    end
    return false, 0
end

function MergeManager:checkIconTip(evt)
    if not self:isEnabled() then return end
    local data = evt:getData()

    -- 场景3 弹体力满了
    -- 场景3
    if data.stage == "STAGE_TWO" then
        if self:canPopInScene6() then
            self:popInScene6()
        end
        return
    end
    -- 场景2和4 STAGE_ONE  STAGE_THREE STAGE_FOUR
    -- 1. 皇帝订单
    local canShowKing, leftMin, key = self:canShowKingTip()
    if canShowKing then
        self:showIconTip({
            text = "订单不足"..leftMin.."分钟",
            tipsType = HomeIconTipsType.NORMAL_CIRCLE,
            iconCreate = function()
                local icon = AMFCompHelper:createBoxZi(false, true)
                icon:setScale(0.5)
                return icon
            end,
        }, {
            popFunc = function()
                self:saveFlagToLocalByKeyInt(key, true, 1)
            end,
        })
        return
    end
    -- 2 优先小鸡
    local canGetReward = self:getData():checkCanGetTravalReward()
    local travelFinish = self:getData():checkChickenIsTravalAndFinish()
    local popChick = canGetReward or travelFinish
    -- printx(42, "强弹423 chick travel reward", canGetReward, " or ", travelFinish)
    if popChick then
        self:showIconAwardBar()
        return
    end
    -- printx(42, "强弹499")
    -- 料理机
    local mOrderInfo = self:getData():getMachineOrderInfo()
    if mOrderInfo and mOrderInfo.bCanGetReward then
        local history = self:getFlagFromLocalByKeyStr("MergetAct_orderHistory", true)
        local hisTb
        if #history > 0 then
            hisTb = table.deserialize(history)
        else
            hisTb = {}
        end
        if not table.exist(hisTb, mOrderInfo.showItemId) then
            table.insert(hisTb, mOrderInfo.showItemId)
            self:saveFlagToLocalByKeyStr("MergetAct_orderHistory", true, table.serialize(hisTb))
            local itemData = BoardMeta:getItemDataByItemId(mOrderInfo.showItemId)
            local str0 = BoardMeta:getCaiPinNameByType(itemData.itemType)
            local str = str0 .. "已完成！"
            self:showIconTip({
                text = str
            })
            return
        end
    end

    -- printx(42, "强弹531")
    -- 体力从30以下达到60
    local power = self:getData():getPowerTotal()
    if power >= self:getData():getAutoAddMaxPowerConfig() then
        local powerHis = self:getFlagFromLocalByKeyInt("Merge_powerTotal")
        if powerHis < self:getData():getPowerTipPowerConfig() then
            local str = "体力已满，快来合成吧"
            self:showIconTip({
                text = str
            }, {
                popFunc = function()
                    self:saveFlagToLocalByKeyInt("Merge_powerTotal", false, power)
                end
            })
            return
        end
    end
end

-- function MergeManager:popIconTipFunc(callback, stageNum)
    -- do
    --     safeRunCall(callback)
    --     return
    -- end

    -- if EnvUtil:isCocos() then
    --     if not self:isEnabled() then
    --         safeRunCall(callback)
    --         return false
    --     end

    --     if stageNum == 4 then
    --         -- 场景4首先判体力上限
    --         if self:canPopInScene6() then
    --             self:popInScene6(callback)
    --             return
    --         end
    --     end

    --     -- 优先小鸡
    --     local canGetReward = self:getData():checkCanGetTravalReward()
    --     local travelFinish = self:getData():checkChickenIsTravalAndFinish()
    --     local popChick = canGetReward or travelFinish
    --     -- printx(42, "强弹423 chick travel reward", canGetReward, " or ", travelFinish)
    --     if popChick then
    --         self:showIconAwardBar(callback)
    --         return
    --     end

    --     printx(42, "强弹499")
    --     local mOrderInfo = self:getData():getMachineOrderInfo()
    --     if mOrderInfo and mOrderInfo.bCanGetReward then
    --         local history = self:getFlagFromLocalByKeyStr("MergetAct_orderHistory", true)
    --         local hisTb
    --         if #history > 0 then
    --             hisTb = table.deserialize(history)
    --         else
    --             hisTb = {}
    --         end
    --         if not table.exist(hisTb, mOrderInfo.showItemId) then
    --             table.insert(hisTb, mOrderInfo.showItemId)
    --             self:saveFlagToLocalByKeyStr("MergetAct_orderHistory", true, table.serialize(hisTb))
    --             local itemData = BoardMeta:getItemDataByItemId(mOrderInfo.showItemId)
    --             local str0 = BoardMeta:getCaiPinNameByType(itemData.itemType)
    --             local str = str0 .. "完成，提交订单吧！"
    --             self:showIconTip(str)
    --             setTimeOut(function()
    --                 safeRunCall(callback)
    --             end, 2)
    --             return
    --         end

    --     end

    --     printx(42, "强弹531")
    --     -- 体力从30以下达到60
    --     local power = self:getData():getPowerTotal()
    --     if power >= self:getData():getAutoAddMaxPowerConfig()  then
    --         local powerHis = self:getFlagFromLocalByKeyInt("Merge_powerTotal")
    --         if powerHis < self:getData():getPowerTipPowerConfig() then
    --             self:saveFlagToLocalByKeyInt("Merge_powerTotal", false, power)
    --             local str = "体力已满，快来合成吧！"
    --             self:showIconTip(str)
    --             setTimeOut(function()
    --                 safeRunCall(callback)
    --             end, 2)
    --             return
    --         end
    --     end

    --     -- 都不符合条件
    --     printx(42, "强弹548")
    --     safeRunCall(callback)
    -- else
    --     safeRunCall(callback)
    -- end
-- end

function MergeManager:showIconTip(param, outParam)
    -- if EnvUtil:isApp() then
    --     local icon = self:getActivityIcon()
    --     if not icon then
    --         return
    --     end

    --     local tip
    --     local data = {}
    --     data.targetIcon =  icon
    --     data.tipsType = HomeIconTipsType.onlyText
    --     data.text = str
    --     tip = HomeIconTipsFactory:createTipsByDelegate(data)
    -- else
    --     local icon = _G.amfBean("IconManager"):getIconByIconKey(tostring(self.ACT_ID))
    --     if icon then
    --         icon:justShowTip(str)
    --     end
    -- end
    local dele = self:_createTipParam(param, outParam)
    local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")
    IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, dele)
end

function MergeManager:_createTipParam(creatorDelegate, outParam)
    local delegate = {}
    delegate.iconKey = tostring(MergeManager.ACT_ID)
    delegate.iconType = IconTipType.MESSAGE
    delegate.creatorDelegate = {
        iconOffset = ccp(-1, -1),
        tipsType = HomeIconTipsType.ONLY_TEXT,
    }
    for k, v in pairs(creatorDelegate or {}) do
        delegate.creatorDelegate[k] = v
    end
    delegate.priority = "S"
    delegate.duration = 5
    for k, v in pairs(outParam or {}) do
        delegate[k] = v
    end
    return delegate
end

function MergeManager:dc(category, subCategory, t1, t2, t3, t4, extraData)
    local params = {
        game_type = "stage",
        category = category,
        sub_category = subCategory,
        t1 = t1,
        t2 = t2,
        t3 = t3,
        t4 = t4,
    }

    -- printx(42, "Manager:dc", tts(params))

    for i, v in pairs(extraData or {}) do
        params[i] = v
    end
    DcUtil:dcForUserTrack(params)
end

function MergeManager:showMergeActYinLiuPanel(delegate)
    if not delegate then
        delegate = {}
    end
    if not self:isEnabled() then
        safeRunCall(delegate.closeCallback)
        return
     end

    local MergeActYinLiuPanelVM = require 'amf.feature.localactivity.merge.view.yinliupanel.MergeActYinLiuPanelVM'
    if not delegate.endTime then
        delegate.endTime = math.floor(self:getData():getMainEndTime())
    end
    delegate.mgr = self
    local yinLiuPanel = MergeActYinLiuPanelVM:create(delegate)
    yinLiuPanel:popout()

    -- 引流面板曝光打点
    self:dc("happy_merge", "attract_panel_show")
end

function MergeManager:updatePassLevelData(actData, mainCollectionCount, collectionMap, passLevelData)
    if not self:isEnabled() then
        -- printx(42, "updatePassLevel not enable")
        return
    end

    if mainCollectionCount then
        self:getData():addOrCostPower(mainCollectionCount)

        if mainCollectionCount > 0 then
            self.giftPart:addPassLevelTimeTody()
        end
    end
end

function MergeManager:updateDeputyPassLevelData(collectionCount)
    if not self:isEnabled() then
        -- printx(42, "updatePassLevel not enable")
        return
    end

    if collectionCount then
        self:getData():addOrCostPower(collectionCount)

        if collectionCount > 0 then
            self.giftPart:addPassLevelTimeTody()
        end
    end
end
---------------------zonghao------------------------------------

--------------------- zitong -----------------------------------

function MergeManager:setIgnoredGiftToday(checked)
    local key = 'ignoreGiftPanel'
    self:saveFlagToLocalByKey(key, true, checked, true)
end

function MergeManager:getIgnoredGiftToday()
    -- 先看actInfo，再看本地
    if self.giftPart:checkTimeToday("latestFlowTodayNotShowTs") then return true end
    local key = 'ignoreGiftPanel'
    return self:getFlagFromLocalByKey(key, true, true)
end

function MergeManager:setIgnoredEnergyNotEnoughGiftToday(checked)
    local key = 'ignoreEnergyNotEnoughGiftPanel'
    self:saveFlagToLocalByKey(key, true, checked, true)
end

function MergeManager:getIgnoredEnergyNotEnoughGiftToday()
    -- 先看actInfo，再看本地
    if self.giftPart:checkTimeToday("latestEnergyOrBuffNotShowTs") then return true end
    local key = 'ignoreEnergyNotEnoughGiftPanel'
    return self:getFlagFromLocalByKey(key, true, true)
end

function MergeManager:addUserEnergy(addNum)
    addNum = addNum or 1
    local key = 'userEnergy'
    local num = self:getFlagFromLocalByKeyInt(key, false, true)
    self:saveFlagToLocalByKeyInt(key, false, num + addNum, true)
end

function MergeManager:getUserEnergy()
    local key = 'userEnergy'
    return self:getFlagFromLocalByKeyInt(key, false, true)
end

function MergeManager:addPopStage4GiftTime(addNum)
    addNum = addNum or 1
    local key = 'popStage4GiftTime'
    local num = self:getFlagFromLocalByKeyInt(key, true, true)
    self:saveFlagToLocalByKeyInt(key, true, num + addNum, true)
end

function MergeManager:getPopStage4GiftTime()
    local key = 'popStage4GiftTime'
    return self:getFlagFromLocalByKeyInt(key, true, true)
end

function MergeManager:addPopMainGiftTime(addNum)
    addNum = addNum or 1
    local key = 'popMainGiftTime'
    local num = self:getFlagFromLocalByKeyInt(key, true, true)
    self:saveFlagToLocalByKeyInt(key, true, num + addNum, true)
end

function MergeManager:getPopMainGiftTime()
    local key = 'popMainGiftTime'
    return self:getFlagFromLocalByKeyInt(key, true, true)
end

function MergeManager:getTodayPopedGiftList()
    local key = 'popedGiftListnew'
    local str = self:getFlagFromLocalByKeyStr(key, true, true)
    if str == '' then return {} end
    local t = table.deserialize(str) or {}
    local ret = {}
    for _, v in pairs(t) do
        ret[tonumber(v)] = true
    end
    return ret
end

function MergeManager:saveTodayPopedGiftList(goodsId)
    local key = 'popedGiftListnew'
    local str = self:getFlagFromLocalByKeyStr(key, true, true)
    local t
    if str == '' then
        t = {}
    else
        t = table.deserialize(str)
    end
    table.insert(t, goodsId)
    str = table.serialize(t)
    self:saveFlagToLocalByKeyStr(key, true, str, true)
end

function MergeManager:checkPopState4Gift()
    return self.giftPart:_checkPopStage4Gift()
end

-- 先出energy后出buff
-- 获取体力为0时需要pull的礼包类型
function MergeManager:checkPopMainGift()
    if self:getPopMainGiftTime() >= 4 then return end
    if self:getIgnoredEnergyNotEnoughGiftToday() then return end

    local goodsIds = {}
    local energyGoodList = self:getData():getConfigByKey("energyGoodIds") or {}
    for k, v in pairs(energyGoodList) do
        table.insert(goodsIds, {goodsId = v, type=Meta.GiftTypeEnum.ENERGY})
    end
    -- local buffGoodList = self:getData():getConfigByKey("buffGoodIds") or {}
    -- for k, v in pairs(buffGoodList) do
    --     table.insert(goodsIds, {goodsId = v, type=Meta.GiftTypeEnum.BUFF})
    -- end
    if table.length(goodsIds) <= 0 then return end

    -- 剩余礼包
    local notBuyGoodsMap = {}
    local buyCnt = 0
    for k, v in pairs(goodsIds) do
        if not (self:getData():getBuyGoodsCount(v.goodsId) > 0) then
            -- 没买的
            table.insert(notBuyGoodsMap, v)
        end
    end
    -- 卖完了
    local leftCnt = table.length(notBuyGoodsMap)
    if leftCnt <= 0 then
        return
    elseif leftCnt == 1 then
        return notBuyGoodsMap[1].type
    end

    local popRound = self:getFlagFromLocalByKeyInt( Meta.Keys.POP_BUY_ENERGY_GIFT_ROUND, true)
    local index = (popRound%leftCnt)+1

    self:saveFlagToLocalByKeyInt( Meta.Keys.POP_BUY_ENERGY_GIFT_ROUND, true, popRound + 1)
    return notBuyGoodsMap[index].type
end

function MergeManager:pullGiftByNames(tb)
    return self.giftPart:pullGiftByNames(tb)
end

function MergeManager:getPrice(goodsId)
    return self.giftPart:getPrice(goodsId)
end

function MergeManager:createBuyButton(data)
    return self.giftPart:createBuyButton(data)
end

function MergeManager:popGiftPanel(delegate)
    local GiftPanelVM = require("amf.feature.localactivity.merge.gift.GiftPanelVM")
    local builder = GiftPanelVM.Builder.new()
    delegate.mgr = self
    builder:setCloseCallback(delegate.closeCall)
    :setData(delegate)

    local vm = builder:build()
    vm:popout()
    self.panelPlug:managePanelVM(vm)
end

function MergeManager:canShowShop()
    local checkList = {
        "59358", "59359", "59360",
        "59350", "59351", "59352",
        "59341", "59342", "59343",
        "59367", "59368", "59369",
        "59373", "59374", "59375"
    }

    local map = self:getData():getChartMap()
    for _, v in ipairs(checkList)do
        if map[v] == nil then return false end
    end
    return true
end

function MergeManager:canShowBook()
    local finishOrderNum = self:getData():getFinishOrderNum()
    return finishOrderNum > 0
end

function MergeManager:buySurePanel( goldNum, buyCallback, closeCall )

    local itemId = 14

    local ThreeTipsPanelVM = require 'amf.middleware.ui.kit.commonpanel.view.ThreeTipsPanelVM'
    local vm
    vm = ThreeTipsPanelVM.Builder.new()
        :setRichText("<color=#9d4d12>是否花费</color><itemId=" .. itemId .. "><size=26><color=#f45600>×" .. goldNum .. "</color></size><color=#9d4d12>购买</color>")
        :setClickBtn({
            touchHandler = function()
                if vm.isDisposed then return end
                safeRunCall(buyCallback)
                vm:close()
            end,
            colorMode = _G.UEButton_ColorMode.Green,
            string = "确定"
        })
        :setCloseCallback(function()
            safeRunCall(closeCall)
        end)
        :setBgColorMaintain(Meta.ThreeTipsPanelColrtType)
        :build()
    vm:popout()
    self.panelPlug:managePanelVM(vm)
end

function MergeManager:openSecondConfirmPanel(callback, nowEnergyNum, buyEnergyNum, bFree)

    local clickBtnSucess = false

    local buyStr = "购买"
    if bFree then
        buyStr = "领取"
    end

    local showStr = string.format("当前体力%d，%s%d体力后达上限%d，溢出的体力将会丢失，确定%s吗？", nowEnergyNum, buyStr, buyEnergyNum, Meta.MaxPowerConfig, buyStr)

    local ThreeTipsPanelVM = require 'amf.middleware.ui.kit.commonpanel.view.ThreeTipsPanelVM'
    local vm
    vm = ThreeTipsPanelVM.Builder.new()
        :setRichText("<color=#B2714A>"..showStr.."</color>")
        :setClickBtn({
            touchHandler = function()
                if vm.isDisposed then return end
                clickBtnSucess = true
                vm:close(true)
            end,
            colorMode = _G.UEButton_ColorMode.Green,
            string = "确定"
        })
        :setCloseCallback(function()
            safeRunCall(callback, clickBtnSucess)
        end)
        :setBgColorMaintain(Meta.ThreeTipsPanelColrtType)
        :build()
    vm:popout()
    self.panelPlug:managePanelVM(vm)
end
--------------------- zitong end -------------------------------


function MergeManager:checkCanPopDailyGetRewardPanel( )
    return self:getData():canGetSurpriseDailyReward()
end

function MergeManager:tryPopDailyGetRewardPanel( done )
    if self:getData():canGetSurpriseDailyReward() then

        local function onSuccess(evt)

            local rewards = evt.data.rewardList
            self:addRewards( rewards, 'double_energy' )
            self:dc('happy_merge','double_energy')

            self:showpDailyGetRewardPanel(done)

            self:getData():setSurpriseGetSucess()
        end

        local function onFail(evt)
            safeRunCall(done)
        end

        local RequestSpring2025MainBReward = require 'amf.feature.localactivity.merge.http.RequestSpring2025MainBReward'
        RequestSpring2025MainBReward:post({rewardType=15}):next(onSuccess, onFail)
    else
        safeRunCall(done)
    end
end

function MergeManager:showpDailyGetRewardPanel( done )

    local endTime = self:getData():getEndTime()
    local curTime = TimeKit:timeInSec()
    local haveTime = endTime - curTime

    local ONE_HOUR = 60 * 60
    local ONE_DAY = 60 * 60 * 24
    local dayNum = math.floor(haveTime/ONE_DAY)
    local hourNum = math.ceil2(haveTime/ONE_HOUR)

    local timeStr = ''
    if dayNum > 0 then
        timeStr = dayNum..'天'
    else
        timeStr = hourNum..'小时'
    end

    -- 展示获得界面
    local vm
    local panelVMClass = require "amf.middleware.ui.kit.panel.second.SecondPanelGVM"
    local builder = panelVMClass.Builder.new()
    builder:setNeedLoadRes({"amf/activity/merge/materials/mergeItems.plist"},{"amf/activity/merge/materials/mergeItems.plist"})
    builder:setLoadResFailCallback(done)
    builder:setColorType(Meta.colorType)
    builder:setTitle("惊喜助力")
    builder:setTopText("距离【美味合合】结束仅剩"..timeStr.."，送你双倍体力道具，快去闯关吧！")
    builder:setRewards({{itemId=Meta.DoubleBuffId,num=10, hideNum= true}}, function( reward )
        return self:commonCreateIcon(reward)
    end)
    builder:setButtonsConfig({
        {
            str = "收下",
            widthMode = UIButtonConfig.Widths.kShort,
            scaleMode = UIButtonConfig.BtnScales.k90,
            colorMode = UIButtonConfig.ColorMode.green,
            touchFunc = function()
                if vm.isDisposed then return end
                vm:onCloseBtnTapped()
            end
        }
    })
    builder:setCloseCallback( function()
        safeRunCall(done)
    end)

    vm = builder:build()
    vm:popout()
    self.panelPlug:managePanelVM(vm)
end

-- 是否可以展示甄嬛订单
function MergeManager:canShowQueenOrder()
	local queenOrderData = self:getData():getQueenOrder()
	return not table.isEmpty(queenOrderData)
end

-- 是否可以展示订单5
function MergeManager:canShowTopFoodCleanOrder()
    local orderData = self:getData():getTopFoodCleanOrder()
    return not table.isEmpty(orderData)
end

-- 是否可以展示皇帝订单
function MergeManager:canShowKingOrder()
    local kingOrderData = self:getData():getKingOrderInfo()
	if not kingOrderData then return false end
    local endTime = tonumber(kingOrderData.endTime) or 0
    if TimeKit:timeInMillis() >= endTime then
        return false
    end
    local orderIndex = kingOrderData.orderIndex or 0
    if orderIndex == #kingOrderData.orderDataList and not kingOrderData.cannotClose then
        return false
    end
    local perDayData = self:getData():getTodayPerDayMap() or {}
    local visibleStepTypeNameSet = perDayData.visibleStepTypeNameSet or {}
    return table.exist(visibleStepTypeNameSet, Meta.StepTypes.kKingOrder)
end

-- 判断好礼当前单是否可参与通用订单聚合；旧主包缺少数据接口时按不可用处理。
function MergeManager:canShowGoodGiftOrder()
    local data = self:getData()
    if not data or type(data.getActiveGoodGiftOrderInfo) ~= "function" then
        return false
    end
    return data:getActiveGoodGiftOrderInfo() ~= nil
end

-- 是否可以展示后宫厨神赛
function MergeManager:canShowQueenMatchIcon()
    local isOpen, cfg = self:getData():checkStepIsOpen(Meta.StepTypes.kQueenMatch)
    return isOpen and self:isMatchDataEnabled()
end

function MergeManager:isMatchDataEnabled()
    local matchData = self:getData():getQueenMatchInfo()
    if table.isEmpty(matchData) then return false end
    -- 默认值不能显示fuck
    if matchData.matchLevel == 0 and matchData.matchId == 0
        and (not matchData.hasRankReward and not matchData.hasUpLevelReward and not matchData.hasMatchStatus)
    then
        return false
    end
    return true
end

---------------------
--提供给别的活动使用
---------------------
function MergeManager:createFlyActIcon()
    local icon = UICreateUtil:createSpriteFile('amf/activity/merge/materials/flyIcon.png')
    return icon
end

function MergeManager:createFlyActIconInLevel()
    local icon = UICreateUtil:createSpriteFile('amf/activity/merge/materials/flyIcon.png')
    return icon
end

function MergeManager:addEnergy( addNum, needLinkageDc, senderActId)
    if not self:isEnabled() then return end
    -- 从别的活动直接加进来的，可选是否额外打linkage点
    if needLinkageDc then
        DcUtil:UserTrack({
            category = "linkage_activity",
            sub_category = "collection",
            t1 = senderActId,
            t2 = MergeManager.ACT_ID,
            t3 = Meta.CollectionId,
            t4 = addNum,
        })
    end
    self:getData():addOrCostPower(addNum)
end

-- 大藤蔓按钮用
function MergeManager:getMainSceneButtonShowConfig()

    local showConfig = {}
    local nowTime = TimeKit:timeInSec()

    if self:isEnabled2() then
        local buffRate = self:getScoreBuffRate()
        local endTime = math.floor(tonumber(self:getScoreBuffEndTime()) / 1000)


        if endTime > nowTime then
            table.insert(showConfig,
                {
                    uniqueId =  _G.BuffTypeConfig.SCORE_BUFF,
                    actId = MergeManager.ACT_ID,
                    actName = MergeManager.ACT_CH_NAME,
                    showStr = "",
                    endTime = endTime,
                    rate = buffRate + 1,
                }
            )
        end
    end

    if self:isEnabled() and self.downloadPlug:checkDownloadSuccess() then
        local buffEndTime = math.floor(tonumber(self:getTimeLimitRateEndTime()) / 1000)
        if buffEndTime > nowTime then
            table.insert(showConfig,
                {
                    uniqueId = "MergeDoubleBuff",
                    actId = MergeManager.ACT_ID,
                    actName = MergeManager.ACT_CH_NAME,
                    iconCreator = function()
                        return UICreateUtil:createSpriteWithPlist(BoardMeta.BoardItemsPlistPath, "mergeItems/collect.png")
                    end,
                    endTime = buffEndTime,
                    rate = 2,
                }
            )
        end
    end

    return showConfig
end

function MergeManager:openMainActivity(closeCallback, extra, userClick, duanMianData)
    self.actPlug:openActivity( {
        actId = self.actId,
        endCallback = closeCallback,
        failCallback = closeCallback,
        userClick = userClick,
        extra = extra,
        duanMianData = duanMianData
    } )
end

function MergeManager:saveFlagToLocalByKey(key, needTime, value, needActStartTimeCheck)
    self:getData():saveFlagToLocalByKey(key, needTime, value, needActStartTimeCheck)
end

function MergeManager:getFlagFromLocalByKey(key, needTime, needActStartTimeCheck)
    return self:getData():getFlagFromLocalByKey(key, needTime, needActStartTimeCheck)
end


-- 本地缓存int
function MergeManager:saveFlagToLocalByKeyInt(key, needTime, value, needActStartTimeCheck)
    self:getData():saveFlagToLocalByKeyInt(key, needTime, value, needActStartTimeCheck)
end

function MergeManager:getFlagFromLocalByKeyInt(key, needTime, needActStartTimeCheck, defaultValue)
    return self:getData():getFlagFromLocalByKeyInt(key, needTime, needActStartTimeCheck, defaultValue)
end

-- 本地缓存str
function MergeManager:saveFlagToLocalByKeyStr(key, needTime, value, needActStartTimeCheck)
    self:getData():saveFlagToLocalByKeyStr(key, needTime, value, needActStartTimeCheck)
end

function MergeManager:getFlagFromLocalByKeyStr(key, needTime, needActStartTimeCheck)
    return self:getData():getFlagFromLocalByKeyStr(key, needTime, needActStartTimeCheck)
end

function MergeManager:updateTipView()

    if not self:getData() then return end
    if not self:isEnabled() then return end

    self.actPlug:updateTipView()
end

function MergeManager:getEndTime()
    return self:getData():getEndTime()
end

function MergeManager:getStartTime()
    return self:getData():getMainBeginTime()
end

function MergeManager:getRealBeginTime()
    return self:getData():getBeginTime()
end

function MergeManager:getRealEndTime()
    return self:getData():getEndTime()
end
--是否是主活动期
function MergeManager:isInMainTime()
    return self:getData():isInMainTime()
end

function MergeManager:getActMainEndTime()
    return self:getData():getMainEndTime()
end
--是否是领奖期
function MergeManager:isInRewardTime()
    return self:getData():isInRewardTime()
end

function MergeManager:getNameCN()
    return self.ACT_CH_NAME
end

---------------------

------------------------------------------------------------
-- 活动联动依赖接口, implement IActLinkageSendMgr
------------------------------------------------------------
function MergeManager:getActShowName()
    return self.ACT_CH_NAME
end

function MergeManager:isOpen()
    if self:isEnabled() then
        if not self.downloadPlug:checkDownloadSuccess() then
            self.downloadPlug:startDownload(function()
                UICreateUtil:loadPlist(BoardMeta.BoardItemsPlistPath)
            end)
        end
        return self:isEnabled() and self.downloadPlug:checkDownloadSuccess()
    end
    return false
end

function MergeManager:getMainEndTime()
    return self:getData():getMainEndTime()
end

function MergeManager:createActIconNode()
    local node = UICreateUtil:createSpriteFile("amf/activity/merge/materials/flyIcon.png")
    return node
end

function MergeManager:openActivity(closeCallback, extra, userClick, act_source, DuanMianData)
    self:openMainActivity(closeCallback,extra,userClick,DuanMianData)
end

-- function MergeManager:addActItem( reward )
--     if not self:isEnabled() then return end
--     if reward and reward.num then
--         self:getData():addOrCostPower( reward.num )
--         self:updateTipView()
--     end
-- end

---------------------------------- CUSTOM_GAIN ----------------------------------

function MergeManager:_onResolveIcon(event)
    if not event then return end
    local data = event:getData()
    if not data or not data.callback then return end

    local itemId = tonumber(data.itemId)
    local iconInfo = Meta.StaticItemIconInfo and Meta.StaticItemIconInfo[itemId]
    if iconInfo then
        data.callback({
            Atlas = iconInfo.Atlas or "",
            Frame = iconInfo.Frame,
            IsPropPng = iconInfo.IsPropPng,
        })
        return
    end

    if not table.exist(BoardMeta:getAllItemList(), itemId) then return end

    data.callback({
        Atlas = BoardMeta.BoardItemsPlistPath,
        Frame = BoardMeta:getMergeItemSpNameByScale(itemId, false, self:getData():getCurWeek()),
        IsPropPng = false,
    })
end

function MergeManager:_onCustomGain(event)
    local reward = event:getData()
    local id = reward.itemId
    local allBoardItemList = BoardMeta:getAllItemList()
    if id == Meta.CollectionId then
        self:getData():addOrCostPower(reward.num)
        self:updateTipView()
    elseif id == Meta.MoneyId then
        self:getData():addOrCostMoney(reward.num)
    elseif id == Meta.DoubleBuffId then
        self:getData():addMoneyBuff(reward.num)
    elseif id == Meta.ScoreBuff20Id then
        self:getData():addScoreBuff20(reward.num)
    elseif id == Meta.ScoreBuff50Id then
        self:getData():addScoreBuff50(reward.num)
    elseif id == Meta.hammerId then
        self:getData():addOpenEggHammerCount(reward.num)
    elseif table.exist(allBoardItemList, id) then
        for j = 1, reward.num do
            self:getData():addItemToRewardDeskList(id)
        end
    end
end

return MergeManager
