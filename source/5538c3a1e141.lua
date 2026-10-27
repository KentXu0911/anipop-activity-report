local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
require "amf.middleware.autopop.config.AutoPopupConst"
local Event = _G["LayeredTileMatchEvent"] or require "amf.feature.localactivity.layeredtilematch.event.Event"
local EntryTokenState = require "amf.feature.localactivity.layeredtilematch.util.EntryTokenState"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"

local Manager = class("LayeredTileMatchManager", BaseFeatureManager)
local PROP_ATLAS_TEST_FRAME = "LayeredTileMatchProp/challenge_token"

--[[
Manager 职责：
1. 对外提供活动 facade：打开活动、面板托管、引导标记、本地缓存、打点等常用入口。
2. 同步服务端 actInfo 到 Model；核心业务状态仍放 Model。
3. 提供跨天/跨期业务 hook；Act/Notify 使用 BaseFeatureManager 默认 Plug，不在额外 Plug 中重复声明。
]]

-- =============================================================================
-- BaseFeatureManager 配置
-- =============================================================================

function Manager:_getConstPath()
    return "amf.feature.localactivity.layeredtilematch.const.Const"
end

function Manager:_getModelPath()
    return "amf.feature.localactivity.layeredtilematch.model.Model"
end

function Manager:setAutoPopupMgr(autoPopupMgr)
    self.autoPopupMgr = autoPopupMgr
    self:_ensureAutoPopRegistered("注入AutoPopupMgr")
end

function Manager:_ensureAutoPopRegistered(source)
    if not self.autoPopupMgr then
        return false
    end
    if not self.autoPopPlug then
        return false
    end

    self.autoPopPlug:setAutoPopupMgr(self.autoPopupMgr)
    local PCP = _G.PopupCheckPoint
    local giftCheckPoint =
        PCP and PCP.LAYERED_TILE_MATCH_DAILY_GIFT_POP
    local giftRegistered = false
    for _, checkPoint in ipairs(
        self.autoPopPlug.registeredCheckPoints or {}
    ) do
        if checkPoint == giftCheckPoint then
            giftRegistered = true
            break
        end
    end
    if not giftRegistered then
        return false
    end

    return true
end

function Manager:_getExtraPlugsConfigList()
    return {
        {
            key = "Download",
        },
        {
            key = "Panel",
            path = {
                plugPath = "amf.feature.localactivity.layeredtilematch.plug.PanelPlug",
            },
        },
        {
            key = "DC",
            path = {
                plugPath = "amf.feature.localactivity.layeredtilematch.plug.DCPlug",
            },
        },
        {
            key = "Rewards",
        },
        {
            key = "AutoPop",
        },
        {
            key = "ActSend",
            path = {
                plugPath = "amf.feature.localactivity.layeredtilematch.plug.ActSendPlug",
                const = self:_getConstPath(),
            },
        },
        {
            key = "ActSent",
            path = {
                plugPath = "amf.feature.localactivity.layeredtilematch.plug.LayeredTileMatchSentPlug",
                const = self:_getConstPath(),
            },
        },
        {
            key = "Haptics",
            path = {
                plugPath = "amf.feature.localactivity.layeredtilematch.plug.HapticsPlug",
                const = self:_getConstPath(),
                hapticsRoot = "amf.feature.localactivity.layeredtilematch.haptics.",
            },
        },
    }
end

function Manager:_init()
    self.bRegisterItem = false
    self:registerActProps()
    PropEventCenter:register(
        PropEvent.CUSTOM_GAIN,
        self._onCustomGain,
        self
    )
    self:initGiftModule()
    self:_ensureAutoPopRegistered("Manager初始化")
    self:addEventDispatcher()
    self:registerEvents()
    -- 过关收集物事务：Icon V2 的多段进度动画要复用 UBF 建好的收集物 context，
    -- 见 onReceiveTransaction / submitEntryTokenProgressAnimationPlan。
    -- 与 NotifyPlug 的 registerFeature/registerSystem 一样只在初始化注册一次；
    -- Manager 是常驻单例（BaseFeatureManager 没有卸载时机），若将来活动出现卸载流程，
    -- 需要与 _G.amfEC:unregisterTransaction(self) 成对处理。
    _G.amfEC:registerTransaction(self)
    self:getModel():onTimeChanged(function()
        self:_registerCrossPeriodCallbacks()
    end)
    -- 非首次登录：本地缓存已有时间，直接触发注册
    local model = self:getModel()
    if model:getMainBeginTimeInSec() and model:getMainBeginTimeInSec() > 0 then
        self:_registerCrossPeriodCallbacks()
    end
end

function Manager:registerActProps()
    if self.bRegisterItem then return end
    for _, itemId in pairs(self:getConst().ItemId) do
        require(string.format(
            "amf.feature.localactivity.layeredtilematch.prop.AMFProp_%d",
            itemId
        ))
    end
    self.bRegisterItem = true
end

function Manager:initGiftModule()
    local GiftModule =
        require "amf.feature.localactivity.layeredtilematch.module.LayeredTileMatchGiftModule"
    self.giftPart = GiftModule.new(self)
end

function Manager:registerGiftModule()
    if self.giftRegisted or not self.giftPart then return end
    local GiftEventCenter = require "amf.feature.giftpackage.event.GiftEventCenter"
    GiftEventCenter:registerCustomModule(
        self.giftPart,
        GiftPackageConst.StageType.ACTIVITY
    )
    self.giftRegisted = true
end

function Manager:registerEvents()
    self:callActFunc("registerActInfoUpdate", "onActInfosUpdate")
    self:registerGiftModule()
end

-- =============================================================================
-- 基础状态 / Icon
-- =============================================================================

function Manager:getActId()
    return self:getConst().actId
end

function Manager:_ensurePropAtlasLoaded()
    if self.propAtlasLoaded then return true end
    if EnvUtil:isUnity() then
        self.propAtlasLoaded = true
        return true
    end
    if not self.downloadPlug:checkDownloadSuccess() then return false end

    if not _G.FrameLoader then
        require "amf.middleware.resmanagement.load.FrameLoader"
    end
    if not _G.SpriteUtil then
        require "amf.middleware.ui.core.SpriteUtil"
    end

    for _, file in ipairs(self:getConst().needLoadFiles or {}) do
        if type(file) == "string" and string.sub(file, -6) == ".plist" then
            SpriteUtil:removeLoadedPlist(file)
            FrameLoader:loadImageWithPlist(file)
        end
    end

    self.propAtlasLoaded = CCSpriteFrameCache:sharedSpriteFrameCache()
        :spriteFrameByName(PROP_ATLAS_TEST_FRAME) ~= nil
    return self.propAtlasLoaded
end

function Manager:isEnabled()
    local isLogicEnabled = self:getModel():isDataEnabled()
    local isResDownloaded = self.downloadPlug:checkDownloadSuccess()
    if not isResDownloaded and (self:getModel():isInMainTime() or self:getModel():isInRewardTime()) then
        self:callPlug("Download", "startDownload", function()
            self:_ensurePropAtlasLoaded()
        end)
    elseif (self:getModel():isInMainTime() or self:getModel():isInRewardTime()) then 
        self:_ensurePropAtlasLoaded()
    end
    local isResEnabled = isResDownloaded and self:_ensurePropAtlasLoaded()
    return isLogicEnabled and isResEnabled
end

function Manager:getMsgNum()
    if not self:isEnabled() or not self:isInMainTime() then
        return 0
    end
    return self:getEntryTokenState().availableGameCount
end

function Manager:getEntryTokenState()
    local periodConfig =
        self:getConfigByKey("periodConfig", {}) or {}
    return EntryTokenState.calculate(
        self:getChallengeTokenNum(),
        periodConfig.startCostTokenNum
    )
end

-- 当前持有的入口代币数
function Manager:getChallengeTokenNum()
    return math.max(
        0,
        tonumber(self:getDataByKey("challengeTokenNum", 0)) or 0
    )
end

-- Icon V2 图标；旧版 Icon 没有 refreshProvider，不参与 Icon V2 进度动画。
function Manager:getIconV2Icon()
    local icon = self:callActFunc("getActIcon")
    if not icon or icon.isDisposed
        or type(icon.refreshProvider) ~= "function"
    then
        return nil
    end
    return icon
end

-- 入口代币按 startCostTokenNum 分段累计，一次获得较多代币可能跨过多段。
-- 参考 SprintGiftPackageManager:buildPassLevelProgressAnimationPlan，
-- 这里为跨段场景生成"涨满 -> 归零 -> 继续上涨"的多段动画计划；未跨段返回 nil。
function Manager:buildEntryTokenProgressAnimationPlan(
    oldTokenNum,
    newTokenNum
)
    local periodConfig =
        self:getConfigByKey("periodConfig", {}) or {}
    return EntryTokenState.buildProgressAnimationPlan(
        oldTokenNum,
        newTokenNum,
        periodConfig.startCostTokenNum
    )
end

-- 播放完成、被跳过或被丢弃的 context 会被 handler 标记，不能再被复用。
local function _isFlyCollectionContextConsumed(context)
    if not context then return true end
    return context.handled == true or context._finished == true
end

-- 同一 icon 同时挂两个待播 context 时会各建一个图标动画会话，后建会话 settle
-- 前一个会话的瞬间会把 provider 的当前进度直接提交到进度条上，表现为进度条
-- 先被清空、再从 0 涨满、最后又清空。所以多段上涨计划要复用 UBF 过关时已经
-- 送出的收集物 context，不能再补发第二个 context。
-- 事务总线回调：暂存 UBF 为本活动 icon 建好的待播收集物 context。
function Manager:onReceiveTransaction(event)
    if event:getName() ~= TransactionEvent.FLY_ACT_COLLECTIONS then return end

    local context = event:getData()
    if tostring(context.iconKey) ~= tostring(self:getActId()) then return end
    -- 自己补发的计划 context 只负责承载计划，不参与暂存，避免被后续流程复用。
    if context._layeredTileMatchPlanContext then return end
    if _isFlyCollectionContextConsumed(context) then return end

    self._pendingEntryTokenFlyContext = context
end

-- 取出暂存的收集物 context：只消费一次，已播放/过期的对象直接丢弃。
function Manager:takePendingEntryTokenFlyContext()
    local context = self._pendingEntryTokenFlyContext
    self._pendingEntryTokenFlyContext = nil
    if _isFlyCollectionContextConsumed(context) then return nil end
    return context
end

-- 通过过关飞收集物事务把多段进度动画交给 Icon V2 播放。
-- 优先把计划挂到 UBF 已经建好的收集物 context 上，保证一个 icon 只播一个会话；
-- 没有可复用的 context（例如本次过关没有收集物飞行）时，再补发一个只带计划的 context。
function Manager:submitEntryTokenProgressAnimationPlan(plan, pendingContext)
    if not plan then
        return false
    end

    pendingContext = pendingContext or self:takePendingEntryTokenFlyContext()
    if pendingContext then
        pendingContext:setProgressAnimationPlan(plan)
        return true
    end

    local context = FlyActCollectionContext.new(self:getActId())
    context:setProgressAnimationPlan(plan)
    -- 标记为活动自己补发的计划 context，事务总线回调据此跳过暂存。
    context._layeredTileMatchPlanContext = true
    _G.amfTransaction(TransactionEvent.FLY_ACT_COLLECTIONS, context)
    return true
end

-- 过关收集到入口代币后播放进度条多段上涨动画
function Manager:playEntryTokenProgressAnimation(
    oldTokenNum,
    newTokenNum,
    pendingContext
)
    if not self:getIconV2Icon() then
        return false
    end
    local plan = self:buildEntryTokenProgressAnimationPlan(
        oldTokenNum,
        newTokenNum
    )
    return self:submitEntryTokenProgressAnimationPlan(plan, pendingContext)
end

-- 提交 FLY_ACT_COLLECTIONS 事务会开启 icon 显示延迟：provider 状态照常更新，
-- 界面仍停留在旧进度上。因此入账后再补一次 provider 刷新，保证多段动画的目标值
-- 是入账后的新进度，而进度条起点仍是旧进度（否则会先清空、再从 0 涨满）。
-- 时序与 SprintGiftPackageManager 的 submitPassLevelProgressAnimationPlan -> refreshIconV2 一致。
function Manager:refreshEntryTokenProgressIcon()
    local icon = self:getIconV2Icon()
    if not icon then
        return false
    end
    return icon:refreshProvider("layeredTileMatchEntryTokenChanged") ~= false
end

function Manager:hasReward()
    if not self:isEnabled() then return false end
    if self:isInMainTime() then
        return self:hasClaimableBattlePassReward()
            or self:hasClaimableStageReward()
    end
    if self:isInRewardTime() then
        return self:hasRewardInRewardTime()
    end
    return false
end

function Manager:hasRewardInRewardTime()
    if not self:isInRewardTime() then return false end
    return self:getModel():hasRewardPeriodConvertReward()
        or self:hasClaimableBattlePassReward()
        or self:hasClaimableStageReward()
end

function Manager:hasClaimableStageReward()
    return self:getModel():hasClaimableStageReward()
end

function Manager:hasClaimableBattlePassReward()
    local battlePass = self:getBattlePass()
    local value = self:getBattlePassValue()
    local hasVip = self:hasBattlePassVip()
    for _, meta in ipairs(self:getBattlePassMetas()) do
        if value >= (meta.need or 0) then
            if not table.exist(battlePass.freeAlreadyGotIds or {}, meta.id) then
                return true
            end
            if hasVip
                and not table.exist(battlePass.vipAlreadyGotIds or {}, meta.id) then
                return true
            end
        end
    end
    return false
end

function Manager:updateTipView()
    self:callActFunc("updateTipView")
end

function Manager:playIconFlyAnimation(params)
    local IconFlyAnimation = require(
        "amf.feature.localactivity.layeredtilematch.util.IconFlyAnimation"
    )
    return IconFlyAnimation:play(params)
end

-- =============================================================================
-- 打开活动 / 面板托管
-- =============================================================================

function Manager:openActivity(delegate)
    delegate = delegate or {}
    delegate.actId = delegate.actId or self:getActId()

    local function open()
        if not self:_ensurePropAtlasLoaded() then
            safeRunCall(delegate.failCallback)
            return
        end
        self:callActFunc("openActivity", delegate)
    end

    if self:callDownloadFunc("checkDownloadSuccess") then
        open()
        return
    end

    self:callDownloadFunc("startDownload", open)
end

-- 正式期场景4强弹；日次数由 AutoPopupLimit 统一管理。
function Manager:_getAutoPopConfigList()
    local PCP = _G.PopupCheckPoint
    local PopStage = AutoPopupConst.PopStage

    return {
        -- 主面板每日场景4强弹1次。
        {
            checkPoint = PCP.LAYERED_TILE_MATCH_MAIN_POP_STAGE_4,
            manualOpen = self:getActId(),
            stages = { PopStage.STAGE_FOUR },
            check = function()
                return self:checkCanPopMainPanelStage4()
            end,
            creator = function(_, onPopOver)
                return function()
                    self:popMainPanelStage4(onPopOver)
                end
            end,
        },
        -- 闯关流程礼包在活动内累计消耗代币数大于20后，每日场景4强弹1次。
        {
            checkPoint = PCP.LAYERED_TILE_MATCH_DAILY_GIFT_POP,
            stages = { PopStage.STAGE_FOUR },
            check = function()
                return self:checkCanPopDailyGiftStage4()
            end,
            creator = function(_, onPopOver)
                return function()
                    self:popDailyGiftStage4(onPopOver)
                end
            end,
        },
    }
end


function Manager:isEnabledInLevel()
    return self:getModel():isDataEnabled() and self:getModel():isInMainTime()
end


-- 强弹 check 只同步读取活动状态，不触发请求或修改业务数据。
function Manager:checkCanPopMainPanelStage4()
    return self:isEnabled() and self:isInMainTime()
end

-- 所有无法打开的路径都通过 failCallback/endCallback 结束强弹状态机。
function Manager:popMainPanelStage4(onPopOver)
    if not self:checkCanPopMainPanelStage4() then
        safeRunCall(onPopOver)
        return
    end

    self:openActivity({
        failCallback = onPopOver,
        endCallback = onPopOver,
        userClick = false,
        extra = {
            from = "auto_popup_stage4",
        },
    })
end

function Manager:checkCanPopDailyGiftStage4()
    if not self:isEnabled() then
        return false
    end
    if not self:isInMainTime() then
        return false
    end
    if not self.giftPart then
        return false
    end
    return self.giftPart:checkCanPopDailyGiftStage4() == true
end

function Manager:popDailyGiftStage4(onPopOver)
    if not self:checkCanPopDailyGiftStage4() then
        safeRunCall(onPopOver)
        return
    end
    self.giftPart:popDailyGiftStage4(onPopOver)
end

function Manager:managePanelVM(panelVM)
    self:callPanelFunc("managePanelVM", panelVM)
end

function Manager:getPanelVMByName(panelVMName)
    return self:callPanelFunc("getPanelVMByName", panelVMName)
end

function Manager:closeAllPanels()
    local observerNum = self:getObserverNum()

    self:notify(Event.kCloseAllPanel)

    return observerNum > 0
end

-- =============================================================================
-- 服务端 actInfo / 数据 / 配置
-- =============================================================================

function Manager:syncActInfo(actInfo)
    local change = self:getModel():syncActInfo(actInfo) or {}
    if change.periodIdChanged and not change.timeChanged then
        self:_registerCrossPeriodCallbacks()
    end
    if change.periodChanged then
        self:closeAllPanels()
    end
    if change.periodIdChanged or change.timeChanged then
        self:updateTipView()
        self:_rebuildActivityIcon()
    end
    return change
end

function Manager:onActInfosUpdate(event)
    local data = event and event:getData() or {}
    local actInfos = data.actInfos or {}
    local actInfo = actInfos[tostring(self:getActId())]
    if not data.fromServer or not actInfo then
        return
    end

    self:syncActInfo(actInfo)
end

function Manager:getDataByKey(key, default)
    return self:getModel():getDataByKey(key, default)
end

function Manager:setDataByKey(key, value, needSave)
    self:getModel():setDataByKey(key, value, needSave)
end

function Manager:addActItem(reward)
    reward = type(reward) == "table" and reward or {}
    local itemId = tonumber(reward.itemId)
    local itemIds = self:getConst().ItemId
    local countKeyByItemId = {
        [itemIds.CHALLENGE_TOKEN] = "challengeTokenNum",
        [itemIds.UNDO] = "undoItemNum",
        [itemIds.SHUFFLE] = "shuffleItemNum",
        [itemIds.REMOVE] = "removeItemNum",
        [itemIds.COMPLETE] = "completeItemNum",
    }
    local countKey = countKeyByItemId[itemId]
    local gainNum = math.max(0, tonumber(reward.num) or 0)
    if not countKey or gainNum <= 0 then
        return false
    end

    local currentNum = math.max(
        0,
        tonumber(self:getDataByKey(countKey, 0)) or 0
    )
    self:setDataByKey(countKey, currentNum + gainNum, true)
    if itemId == itemIds.CHALLENGE_TOKEN then
        self:updateTipView()
    end
    return true
end

function Manager:_onCustomGain(event)
    local reward = event and event:getData()
    self:addActItem(reward)
end

-- UBF 在组装 passLevel 数据时回调，collectionCount 与服务端本局入账口径一致。
function Manager:updatePassLevelData(
    data,
    collectionCount,
    collectionMap,
    passLevelData
)
    -- UBF 在本流程开头已经送出收集物 context，这里一次性取出：
    -- 无论本次是否真的提交动画计划，都不再跨流程保留这个引用。
    local pendingContext = self:takePendingEntryTokenFlyContext()
    local gainNum = math.max(0, tonumber(collectionCount) or 0)
    local isPassLevel = data and data.settleMentState
    if not isPassLevel or gainNum <= 0 then
        return
    end

    local oldTokenNum = self:getChallengeTokenNum()
    local newTokenNum = oldTokenNum + gainNum
    -- 过关代币可能一次跨过多段，交给 Icon V2 播放多段上涨动画。
    -- 必须先提交计划（开启 icon 显示延迟），再入账并刷新 provider，
    -- 否则入账触发的刷新会把新进度提前刷到界面，动画会从新值起跳。
    local planSubmitted =
        self:playEntryTokenProgressAnimation(
            oldTokenNum,
            newTokenNum,
            pendingContext
        )
    self:addActItem({
        itemId = self:getConst().ItemId.CHALLENGE_TOKEN,
        num = gainNum,
    })
    -- 只有真的提交了计划（显示延迟已开启）才需要补一次刷新；
    -- 未跨段时保持原逻辑，交给 Icon V2 默认单段动画。
    if planSubmitted then
        self:refreshEntryTokenProgressIcon()
    end
end

function Manager:getConfigByKey(key, default)
    return self:getModel():getConfigByKey(key, default)
end

function Manager:getPeriodId()
    return self:getModel():getPeriodId()
end

function Manager:getBeginTime()
    return self:getModel():getBeginTimeInSec()
end

function Manager:getMainBeginTime()
    return self:getModel():getMainBeginTimeInSec()
end

function Manager:getMainEndTime()
    return self:getModel():getMainEndTimeInSec()
end

function Manager:getEndTime()
    return self:getModel():getEndTimeInSec()
end

function Manager:isActBegin(now)
    return self:getModel():isActBegin(now)
end

function Manager:isInPreheatTime(now)
    return self:getModel():isInPreheatTime(now)
end

function Manager:isInMainTime(now)
    return self:getModel():isInMainTime(now)
end

function Manager:isInRewardTime(now)
    return self:getModel():isInRewardTime(now)
end

function Manager:isActEnd(now)
    return self:getModel():isActEnd(now)
end

function Manager:setConfigByKey(key, value, needSave)
    self:getModel():setConfigByKey(key, value, needSave)
end

function Manager:updateData(data)
    self:getModel():updateData(data)
    self:updateTipView()
end

function Manager:getBattlePass()
    return self:getModel():getBattlePass()
end

function Manager:getBattlePassValue()
    return self:getModel():getBattlePassValue()
end

function Manager:hasBattlePassVip()
    return self:getModel():hasBattlePassVip()
end

function Manager:setBattlePassHasVip(hasVip)
    self:getModel():setBattlePassHasVip(hasVip)
    self:updateTipView()
end

function Manager:getBattlePassMetas()
    return self:getModel():getBattlePassMetas()
end

function Manager:getVipGoodsId()
    return self:getFirstPackageIdByGroup(
        self:getConst().PackageGroup.PASS
    )
end

function Manager:getPackageIdsByGroup(group)
    if self.giftPart and self.giftPart.getPackageIdsByGroup then
        return self.giftPart:getPackageIdsByGroup(group)
    end
    return {}
end

function Manager:getFirstPackageIdByGroup(group)
    return self:getPackageIdsByGroup(group)[1]
end

function Manager:getDisplayablePackages()
    return self:getModel():getDisplayablePackages()
end

function Manager:pullGift()
    if not self.giftPart then
        return
    end
    return self.giftPart:pullGift()
end

function Manager:pullTicketRefillGoods()
    return self:pullGift()
end

function Manager:pullPropRefillGoods()
    return self:pullGift()
end

function Manager:pullBattlePassGoods()
    return self:pullGift()
end

function Manager:getGiftPackageExtra(goodsId)
    if not self.giftPart then
        return {}
    end
    return self.giftPart:getPackageExtra(goodsId)
end

function Manager:getGiftPackageBuyLimit(goodsId)
    if not self.giftPart
        or not self.giftPart.getPackageBuyLimit then
        return
    end
    return self.giftPart:getPackageBuyLimit(goodsId)
end

function Manager:getGiftPackageRemainBuyTimes(goodsId)
    if not self.giftPart then
        return
    end
    return self.giftPart:getPackageRemainBuyTimes(goodsId)
end

function Manager:getGiftPackageGroupRemainBuyTimes(group)
    if not self.giftPart
        or not self.giftPart.getPackageGroupRemainBuyTimes then
        return 0
    end
    return self.giftPart:getPackageGroupRemainBuyTimes(group)
end

function Manager:getTicketRefillGoods()
    local group = self:getConst().PackageGroup
    return {
        ticketGoodsId =
            self:getFirstPackageIdByGroup(group.ENTRY_TICKET),
        popGoodsId =
            self:getFirstPackageIdByGroup(group.ENTRY_TICKET_POP),
        offerGoodsId =
            self:getFirstPackageIdByGroup(group.SPECIAL_OFFER),
    }
end

function Manager:getTicketDiscountRemainBuyTimes()
    return self:getGiftPackageGroupRemainBuyTimes(
        self:getConst().PackageGroup.ENTRY_TICKET
    )
end

function Manager:getPropPackageGroup(boosterId)
    local group = self:getConst().PackageGroup
    local propGroupByBooster = {
        undo = group.UNDO_ITEM,
        shuffle = group.SHUFFLE_ITEM,
        remove = group.REMOVE_ITEM,
        complete = group.COMPLETE_ITEM,
    }
    return propGroupByBooster[boosterId] or group.UNDO_ITEM
end

function Manager:getPropRefillGoods(boosterId)
    local group = self:getConst().PackageGroup
    local propGroup = self:getPropPackageGroup(boosterId)
    return {
        propGoodsId = self:getFirstPackageIdByGroup(
            propGroup
        ),
        offerGoodsId = self:getFirstPackageIdByGroup(
            group.ACTIVITY_ITEM_OFFER
        ),
    }
end

function Manager:getPropDiscountRemainBuyTimes(boosterId)
    return self:getGiftPackageGroupRemainBuyTimes(
        self:getPropPackageGroup(boosterId)
    )
end

function Manager:requestBuyTicketGoods(
    goodsId,
    dcSource,
    showId,
    successCallback,
    failCallback,
    cancelCallback
)
    local goods = GoodsManager:getGoods(goodsId)
    if not goods then
        safeRunCall(failCallback)
        return
    end
    local buyContext = BuyContext.new(goodsId, goods:getMoneyType())
        :setOnlineBuy(true)
        :setFeatureAndSource(
            self:getConst().dcFeature,
            dcSource
        )
        :setShowId(showId)
        :setUnifiedBuy(
            true,
            GiftPackageConst.StageType.ACTIVITY,
            self:getConst().moduleName
        )
        :setCallback(
            successCallback,
            failCallback,
            cancelCallback
        )
    _G.amfTransaction(TransactionEvent.PAY, buyContext)
end

function Manager:requestBuyDailyGiftPackage(
    goodsId,
    successCallback,
    failCallback,
    cancelCallback
)
    local goods = GoodsManager:getGoods(goodsId)
    if not goods then
        safeRunCall(failCallback)
        return
    end
    local buyContext = BuyContext.new(goodsId, goods:getMoneyType())
        :setOnlineBuy(true)
        :setFeatureAndSource(
            self:getConst().dcFeature,
            self:getConst().DC.Source.FlowGift
        )
        :setUnifiedBuy(
            true,
            GiftPackageConst.StageType.ACTIVITY,
            self:getConst().moduleName
        )
        :setCallback(
            successCallback,
            failCallback,
            cancelCallback
        )
    _G.amfTransaction(TransactionEvent.PAY, buyContext)
end

function Manager:hasShownTodayTokenShortageGift()
    return self:getFlagFromLocalByKey(
        self:getConst().LocalCacheKey.TodayTokenShortageGiftShown,
        true
    )
end

function Manager:markTodayTokenShortageGiftShown()
    self:setFlagToLocalByKey(
        self:getConst().LocalCacheKey.TodayTokenShortageGiftShown,
        true,
        true
    )
end

function Manager:requestBuyBattlePassVip(
    showId,
    successCallback,
    failCallback,
    cancelCallback
)
    local goodsId = self:getVipGoodsId()
    if not goodsId then
        safeRunCall(failCallback)
        return
    end
    local buyContext = BuyContext.new(goodsId, MoneyType.kRmb)
        :setOnlineBuy(true)
        :setFeatureAndSource(self:getConst().dcFeature, "feedback")
        :setShowId(showId)
        :setUnifiedBuy(
            true,
            GiftPackageConst.StageType.ACTIVITY,
            self:getConst().moduleName
        )
        :setCallback(function(...)
            -- 正式环境以后端购买回调同步为准；本地先刷新 VIP 展示。
            self:setBattlePassHasVip(true)
            safeRunCall(successCallback, ...)
        end, failCallback, cancelCallback)
    _G.amfTransaction(TransactionEvent.PAY, buyContext)
end

function Manager:addRewardsNormal(rewardItems, params)
    if table.isEmpty(rewardItems or {}) then return end
    local dcExtra = table.clone(params or {})
    local extraMap = dcExtra.extraMap
    dcExtra.extraMap = nil
    dcExtra.dcFeature =
        dcExtra.dcFeature or self:getConst().dcFeature
    return self:callPlug("Rewards", "addRewardsNormal", rewardItems, {
        dcExtra = dcExtra,
        extraMap = extraMap,
    })
end

function Manager:playEffect(soundKey, loop)
    local soundPath = self:getConst().Sound[soundKey] or soundKey
    if not soundPath then return end
    local effectId = GamePlayMusicPlayer.getInstance():playEffect(
        soundPath,
        nil,
        loop
    )
    self[soundKey .. "_effect"] = effectId
    return effectId
end

function Manager:playBGM(bgmKey)
    local path = self:getConst().BGM[bgmKey]
    local player = GamePlayMusicPlayer.getInstance()
    if path and player.IsBackgroundMusicOPen then
        player:playOtherBgMusic(path, true)
    end
end

function Manager:resumeWorldBGM()
    local player = GamePlayMusicPlayer.getInstance()
    if player.IsBackgroundMusicOPen then
        player:playWorldSceneBgMusic(nil, true)
    end
end

function Manager:playHaptics(type)
    self:callHapticsFunc("playHaptics", type)
end

local function _extractResponseData(evt)
    if not evt then return {} end
    if evt.getData then return evt:getData() or {} end
    return evt.data or {}
end

function Manager:claimBattlePassReward(id, vip, rewardUniteExtraIds, onOK, onFail)
    local protocol = self:getConst().Protocol.CLAIM_BATTLE_PASS_REWARD
    local params = {
        id = id,
        vip = vip == true,
        rewardUniteExtraIds = rewardUniteExtraIds or {},
    }
    local plug = self:_getPlug("ActSend")
    if plug then
        params = plug:handleRequestParams(protocol, params)
    end

    self:getModel():requestClaimBattlePassReward(params):next(function(evt)
        local data = _extractResponseData(evt)
        if plug then
            plug:handleRewardByProtocol(protocol, data)
        end
        local rewards = data.rewards or {}
        if not table.isEmpty(rewards) then
            self:addRewardsNormal(rewards, {
                dcSource = "feedback_reward",
                extraMap = {
                    pay_type = vip
                        and DcPayType.kRmb
                        or DcPayType.kFree,
                },
            })
        end
        local challengeTokenNum = tonumber(data.challengeTokenNum)
        if challengeTokenNum ~= nil then
            self:setDataByKey(
                "challengeTokenNum",
                math.max(0, challengeTokenNum),
                true
            )
        end
        self:updateTipView()
        safeRunCall(onOK, data)
    end, function(resp)
        safeRunCall(onFail, resp)
    end)
end

-- =============================================================================
-- 本地缓存（保持旧活动常用方法名和签名）
-- =============================================================================

function Manager:getCacheLocalKey(key)
    return "localCache." .. (key or "defaultKey")
end

function Manager:setFlagToLocalByKey(key, needTime, value)
    if not key then return end
    if value == nil then value = true end
    self:getModel():saveFlagToLocalByKey(self:getCacheLocalKey(key), needTime, value, true)
end

function Manager:getFlagFromLocalByKey(key, needTime)
    return self:getModel():getFlagFromLocalByKey(self:getCacheLocalKey(key), needTime, true)
end

function Manager:addIntToLocalByKey(key, needTime, addNum)
    if not key then return end
    if addNum == nil then addNum = 1 end
    local beforeNum = self:getModel():getFlagFromLocalByKeyInt(self:getCacheLocalKey(key), needTime, true) or 0
    self:getModel():saveFlagToLocalByKeyInt(self:getCacheLocalKey(key), needTime, beforeNum + addNum, true)
end

function Manager:setIntFromLocalByKey(key, needTime, setNum)
    if not key then return end
    if setNum == nil then setNum = 0 end
    self:getModel():saveFlagToLocalByKeyInt(self:getCacheLocalKey(key), needTime, setNum, true)
end

function Manager:getIntFromLocalByKey(key, needTime)
    return self:getModel():getFlagFromLocalByKeyInt(self:getCacheLocalKey(key), needTime, true) or 0
end

function Manager:setStringToLocalByKey(key, needTime, value)
    if not key then return end
    if value == nil then value = "" end
    self:getModel():saveFlagToLocalByKeyStr(self:getCacheLocalKey(key), needTime, value, true)
end

function Manager:getStringFromLocalByKey(key, needTime)
    return self:getModel():getFlagFromLocalByKeyStr(self:getCacheLocalKey(key), needTime, true) or ""
end

-- =============================================================================
-- 引导标记
-- =============================================================================

function Manager:hasGuideIndex(index, checkLocalData)
    local hasIndex = self:getModel():hasGuide(index)

    if checkLocalData == nil then checkLocalData = true end
    if checkLocalData then
        local hasLocal = self:getFlagFromLocalByKey("LocalGuideId" .. index, false)
        if hasLocal then
            if not hasIndex then self:addGuideIndex(index, false) end
            hasIndex = true
        end
    end
    return hasIndex
end

function Manager:addGuideIndex(index, needSaveLocal)
    self:getModel():setGuide(index)

    if needSaveLocal == nil then needSaveLocal = true end
    if needSaveLocal then
        self:setFlagToLocalByKey("LocalGuideId" .. index, false, true)
    end

    local ActCommonHttp =
        require "amf.middleware.activity.http.ActCommonHttp"
    ActCommonHttp:setActGuideFlag(self:getActId(), index, true)
end

-- =============================================================================
-- 打点
-- =============================================================================

function Manager:dcAct(subCategory, extraData)
    self:callDCFunc("dcAct", nil, subCategory, extraData)
end

function Manager:dcUserTrack(subCategory, extraData)
    self:callDCFunc("dcUserTrack", nil, subCategory, extraData)
end

function Manager:dcQualify()
    local key = self:getConst().LocalCacheKey.DCQualifyDaily
    self:callDCFunc("dcQualify")
end

function Manager:dcJoin()
    local key = self:getConst().LocalCacheKey.DCJoinDaily

    self:setFlagToLocalByKey(key, true, true)
    self:callDCFunc("dcJoin")
end



-- =============================================================================
-- 跨天 / 跨期
-- =============================================================================

-- 活动时间确认入口
-- Config.lua:setAttributes 从 info.xml 拿到时间后通过 config.getMgr() 调用
-- 多期活动的当期时间由 Model:updateFromExtraData 从 actInfo.extra 自动提取，不经过此处
function Manager:onActivityTimeConfirmed(timeData)
    local model = self:getModel()
    if model:isDataEnabled() and model:getEndTimeInSec() > 0 then
        return false
    end
    return model:updateActivityTime(timeData)
end

function Manager:_rebuildActivityIcon()
    local ActivityEventCenter =
        require "amf.middleware.activity.event.ActivityEventCenter"
    require "amf.middleware.activity.event.ActivityEvent"
    ActivityEventCenter:dispatch(
        _G.ActivityEvent.REBUILD_ACTIVITY_ICON,
        { actId = self:getActId() }
    )
end

function Manager:_removeActivity()
    local ActivityEventCenter =
        require "amf.middleware.activity.event.ActivityEventCenter"
    require "amf.middleware.activity.event.ActivityEvent"
    ActivityEventCenter:dispatch(
        _G.ActivityEvent.REMOVE_ACTIVITY,
        { actId = self:getActId() }
    )
end

function Manager:updateRewardTimeActivityIcon()
    if self:hasRewardInRewardTime() then
        self:_rebuildActivityIcon()
    else
        self:_removeActivity()
    end
end

function Manager:_registerCrossPeriodCallbacks()
    local PassDayTimer = require "amf.script.tool.timer.PassDayTimer"
    local model = self:getModel()

    self:_unregisterCrossPeriodCallbacks()

    local mainBegin = model:getMainBeginTimeInSec()
    local mainEnd = model:getMainEndTimeInSec()
    local actEnd = model:getEndTimeInSec()
    local now = TimeKit:timeInSec()
    local periodId = model:getPeriodId()

    if mainBegin and mainBegin > 0 then
        if mainBegin > now then
            self._cbMainBegin = function()
                if self:getPeriodId() == periodId then
                    self:onActPassMainBegin()
                end
            end
            self._cbMainBeginTime = mainBegin
            PassDayTimer:registerEndTimeCallback(mainBegin + 1, self._cbMainBegin)
        end
        if mainEnd and mainEnd > now and mainEnd ~= mainBegin then
            self._cbMainEnd = function()
                if self:getPeriodId() == periodId then
                    self:onActPassMainEnd()
                end
            end
            self._cbMainEndTime = mainEnd
            PassDayTimer:registerEndTimeCallback(mainEnd + 1, self._cbMainEnd)
        end
        if actEnd and actEnd > now and actEnd ~= mainEnd then
            self._cbActEnd = function()
                if self:getPeriodId() == periodId then
                    self:onActPassActEnd()
                end
            end
            self._cbActEndTime = actEnd
            PassDayTimer:registerEndTimeCallback(actEnd, self._cbActEnd)
        end
    end
end

function Manager:_unregisterCrossPeriodCallbacks()
    local PassDayTimer = require "amf.script.tool.timer.PassDayTimer"
    if self._cbMainBegin then
        PassDayTimer:unregisterEndTimeCallback(self._cbMainBeginTime, self._cbMainBegin)
        self._cbMainBegin = nil
        self._cbMainBeginTime = nil
    end
    if self._cbMainEnd then
        PassDayTimer:unregisterEndTimeCallback(self._cbMainEndTime, self._cbMainEnd)
        self._cbMainEnd = nil
        self._cbMainEndTime = nil
    end
    if self._cbActEnd then
        PassDayTimer:unregisterEndTimeCallback(self._cbActEndTime, self._cbActEnd)
        self._cbActEnd = nil
        self._cbActEndTime = nil
    end
end

-- Base NotifyPlug:onInstall() 会把 Manager 注册到 amfEC feature bus。
-- PassDayTimer 跨天时会发送 FeatureEvent.PASS_DAY，FeatureEventBus 按 onAct 前缀调用到这里。
function Manager:onActPassDay()
    local model = self:getModel()
    BaseFeatureManager.onActPassDay(self)
    model:onPassDay()
    self:updateTipView()
    self:notify(Event.kPassDay)
end

function Manager:onActPassMainBegin()
    self:getModel():onActPassMainBegin()

    local closed = self:closeAllPanels()
    self:updateTipView()

    if closed then
        -- TODO: 按需替换为业务定制提示文案
        CommonTip:showTip(self:getConst().actName .. "活动已正式开启，\n请尝试重进活动~")
    end
end

function Manager:onActPassMainEnd()
    self:getModel():onActPassMainEnd()
    self:updateTipView()
    local mainPanelVM = self:getPanelVMByName(
        "LayeredTileMatchMainPanelVM"
    )
    local hasMainPanelVM =
        mainPanelVM and not mainPanelVM.isDisposed
    -- 主面板需先决定立即关闭，还是延迟到局内结算确认后关闭。
    self:notify(Event.kPassMainEnd)
    if not hasMainPanelVM then
        self:closeAllPanels()
    end
    local mainPanelCloseDeferred =
        hasMainPanelVM
        and mainPanelVM.isMainEndLifecyclePending
        and mainPanelVM:isMainEndLifecyclePending()
    if self:hasRewardInRewardTime()
        or not mainPanelCloseDeferred then
        self:updateRewardTimeActivityIcon()
    end
end

function Manager:onActPassActEnd()
    self:getModel():onActPassActEnd()
    self:closeAllPanels()
    self:_removeActivity()
    self:notify(Event.kPassActEnd)
end

return Manager
