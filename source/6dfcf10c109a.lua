local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local CollectCardEventCenter = require "amf.feature.localactivity.collectcard.event.CollectCardEventCenter"
local IconEventCenter
if _G.MainSceneFloderVersion and _G.MainSceneFloderVersion >= 1.1 then
    IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
elseif not _G.MainSceneFloderVersion then
    IconEventCenter = require "amf.feature.mainscene.icon.event.IconEventCenter"
end
local CollectCardLog = require "amf.feature.localactivity.collectcard.log.CollectCardLog"
local CardData = require "amf.feature.localactivity.collectcard.model.CardData"
local IconModule = require "amf.feature.localactivity.collectcard.icon.IconModule"
local ExchangeShopEventCenter = require "amf.feature.exchangeshop.event.ExchangeShopEventCenter"
local OpenShareEventCenter = require "amf.middleware.share.openshare.event.OpenShareEventCenter"
local ThreeForOneGiftModule = require "amf.feature.localactivity.collectcard.ThreeForOneGiftModule"

local deferred = require "amf.script.sugar.deferred"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"

local ActivityName = "CollectCard"
---@class CollectCardManager : BaseFeatureManager
local Manager = class(ActivityName.."Mgr",BaseFeatureManager)

function Manager:setAutoPopupMgr(autoPopupMgr)
    self.autoPopupMgr = autoPopupMgr
end
local PROGRESS_TIP_MIN_CARD_COUNT = 7
local PROGRESS_TIP_TIER_ORDER = {"d", "c", "b", "a"}
local PROGRESS_TIP_THRESHOLDS = {
    [12] = {a = 3, b = 5, c = 7, d = 10},
    [15] = {a = 3, b = 5, c = 9, d = 13},
}

----------- 可能需要修改start -----------
Manager.ACT_OPEN_VERSION = 2
Manager.ACT_ID = 9087
Manager.ACT_CH_NAME = "开心卡册"
Manager.customColorType = "collectcard"

_G.COLLECT_CARD_FLOW_TYPE = {
    OPEN_CARD = "openCard",
    SETTLE = "settle",
    OPEN_AND_SETTLE = "openAndSettle",
}

function Manager:_init()
    self._isGetedMainInfo = false
    self.bRegisterItem = false
    self._propRegistered = {}
    self:registerActProps()
    self:registerEvents()
    self:initCustomColorCfg()
    self.iconModule = IconModule.new(self)
    self._isDownloadingRes = false
    self._isResReady = false
    self._isWaitingRefresh = false
    self._progressTipShowed = false
    self._isNewCardPanelOpen = false
    self._pendingCollectCardFlows = {}
    self:tryDownLoadRes(false, true)
end

function Manager:setFriendManager(friendManager)
    self._friendManager = friendManager
end

function Manager:setUserManager(userManager)
    self._userManager = userManager
end

function Manager:setNetworkStatusManager(networkStatusManager)
    self._networkStatusManager = networkStatusManager
end

function Manager:tryDownLoadRes(showLoading, ignoreSound)
    if EnvUtil:isMiniGame() then
        local sourceList = {}
        if not ignoreSound then
            local soundSource = self:getSoundSource()
            sourceList = table.union(sourceList, soundSource)
        end

        local cardPackSource = self:getCardPackResource()
        sourceList = table.union(sourceList, cardPackSource)
        return _G.amfBean("AssetsUtil"):loadMiniFiles(sourceList)
        :next(function()
            self._isResReady = true
            return deferred.success()
        end, function()
            return deferred.error("download resource failed")
        end)
    end
    if AssetsUtil:isModuleResReady("meta/CollectCardRes.xml") then
        self._isResReady = true
        return deferred.success()
    end
    local d = deferred.new()
    self._isDownloadingRes = true
    local onLoadSuccess = function()
        self._isDownloadingRes = false
        self._isResReady = true
        d:resolve()
        printx(33, "CollectCardManager:DownLoadRes success")
    end
    local onLoadFail = function()
        if showLoading then
            CommonTip:showTip("活动加载失败，请重试")
        end
        self._isDownloadingRes = false
        d:reject()
        printx(33, "CollectCardManager:DownLoadRes failed")
    end
    local onCancel = function()
        self._isDownloadingRes = false
        d:reject()
        printx(33, "CollectCardManager:DownLoadRes canceled")
    end
    AssetsUtil:loadDynamicModule('meta/CollectCardRes.xml', onLoadSuccess, onLoadFail, onCancel, showLoading)
    return d
end

function Manager:registerActEvent()
    if self._hasRegisterActEvent then return end
    local now = TimeKit:timeInSec()
    local mainBeginTime = self:getModel():getMainBeginTime()
    local mainEndTime = self:getModel():getMainEndTime()
    local endTime = self:getModel():getEndTime()

    if now < mainBeginTime then
        local function onPassMainBeginTime()
            self:onActPassMainBeginTime()
        end
        TimerUtil.addAlarm(onPassMainBeginTime, mainBeginTime - now, 1)
    end
    if now < mainEndTime then
        local function onPassMainEndTime()
            self:onActPassMainEndTime()
        end
        TimerUtil.addAlarm(onPassMainEndTime, mainEndTime - now, 1)
    end
    if endTime ~= mainEndTime and now < endTime then
        local function onPassEndTime()
            self:onActPassEndTime()
        end
        TimerUtil.addAlarm(onPassEndTime, endTime - now, 1)
    end
end

function Manager:registerActProps()
    if self:isInActTime() and not self.bRegisterItem then
        self.bRegisterItem = true
        require "amf.feature.localactivity.collectcard.prop.AMFProp_CardPack1"
        require "amf.feature.localactivity.collectcard.prop.AMFProp_CardPack2"
        require "amf.feature.localactivity.collectcard.prop.AMFProp_CardPack3"
        require "amf.feature.localactivity.collectcard.prop.AMFProp_CardPack4"
        require "amf.feature.localactivity.collectcard.prop.AMFProp_CardPack5"
    end
end

function Manager:_getConstPath()
    return "amf.feature.localactivity.collectcard.config.CollectCardConst"
end

function Manager:_getModelPath()
    return "amf.feature.localactivity.collectcard.model.CollectCardModel"
end

function Manager:initCustomColorCfg()
    local PanelColorConfig = require "amf.middleware.ui.config.PanelColorConfig"
    local defaultCfg = PanelColorConfig:getConfig("green")
    local customColorCfg = self:getConst().CustomColorCfg
    local newColorConfig = {
        bgColor = customColorCfg.bgColor and self:hex2Vec4(customColorCfg.bgColor) or defaultCfg.bgColor,
        bgInnerColor = customColorCfg.bgInnerColor and self:hex2Vec4(customColorCfg.bgInnerColor) or defaultCfg.bgInnerColor,
        bgInnerColor2 = customColorCfg.bgInnerColor2 and self:hex2Vec4(customColorCfg.bgInnerColor2) or defaultCfg.bgInnerColor2,
        bg10Color = customColorCfg.bg10Color and self:hex2Vec4(customColorCfg.bg10Color) or defaultCfg.bg10Color,

        tabNormalColor = customColorCfg.tabNormalColor and self:hex2Vec4(customColorCfg.tabNormalColor) or defaultCfg.tabNormalColor,
        tabNormalLabelColor = customColorCfg.tabNormalLabelColor and hex2ccc4(customColorCfg.tabNormalLabelColor) or defaultCfg.tabNormalLabelColor,

        tabSelectedColor = customColorCfg.tabSelectedColor and self:hex2Vec4(customColorCfg.tabSelectedColor) or defaultCfg.tabSelectedColor,
        tabSelectedLabelColor = customColorCfg.tabSelectedLabelColor and hex2ccc4(customColorCfg.tabSelectedLabelColor) or defaultCfg.tabSelectedLabelColor,

        closeBtnColor = customColorCfg.closeBtnColor and self:hex2Vec4(customColorCfg.closeBtnColor) or defaultCfg.closeBtnColor,

        titleColor = customColorCfg.titleColor and hex2ccc4(customColorCfg.titleColor) or defaultCfg.titleColor,

        lineColor = customColorCfg.lineColor and self:hex2Vec4(customColorCfg.lineColor) or defaultCfg.lineColor,
    }
    PanelColorConfig:addConfig(self.customColorType, newColorConfig)
end

function Manager:_getExtraPlugsConfigList()
    return {
        {
            key = "AutoPop",
        },
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
                plugPath = "amf.feature.localactivity.collectcard.dc.CollectCardDC",
            }
        },
        {
            key = "ActSent",
            path = {
                plugPath = "amf.feature.localactivity.collectcard.plug.CollectCardSentPlug",
                const = self:_getConstPath()
            },
        },
        {
            key = "ActExchangeReceiver",
            path = {
                plugPath = "amf.feature.localactivity.collectcard.plug.ActExchangeReceiver",
            }
        },
    }
end

function Manager:requestSwapCreate(params)
    return self:getModel():requestSwapCreate(params)
end

function Manager:createSwapMessage(params)
    local model = self:getModel()
    return model:requestSwapCreate(params):next(function(response)
        local data = response:getData() or {}
        model:applySwapCreateSuccess(params, data)
        if params.type == model:getConst().SwapCreateType.HELP then self:updateActIcon() end
        return response
    end)
end

function Manager:requestSwapOperate(params)
    local model = self:getModel()
    return model:requestSwapOperate(params):next(nil, function(error)
        local errorCode = tonumber(error:getErrorCode())
        if model:getConst().SwapAcceptDisabledErrorCodes[errorCode] then
            model:setSwapAcceptDisabled(params.messageId, true)
        elseif model:getConst().SwapTerminalErrorCodes[errorCode] then
            model:removeSwapMessage(params.messageId)
        end
        return deferred.error(error)
    end)
end

function Manager:applySwapOperateSuccess(data, params, context)
    local model = self:getModel()
    local Const = model:getConst()
    local gainCardId
    local receiveData
    if context.type == Const.SwapCreateType.GIFT
        and context.direction == Const.SwapMessageDirection.RECEIVED
        and params.op == Const.SwapOperateType.ACCEPT
    then
        gainCardId = context.cardId
        receiveData = {type = context.type, profile = context.profile}
    elseif context.type == Const.SwapCreateType.EXCHANGE then
        if context.direction == Const.SwapMessageDirection.RECEIVED
            and context.state == Const.SwapMessageState.WAIT_CREATOR_CONFIRM
            and params.op == Const.SwapOperateType.CANCEL
        then
            gainCardId = context.selectedCardId or params.selectedCardId
        elseif context.direction == Const.SwapMessageDirection.SENT
            and context.state == Const.SwapMessageState.WAIT_RECEIVER
            and params.op == Const.SwapOperateType.CANCEL
        then
            gainCardId = context.cardId
        elseif context.direction == Const.SwapMessageDirection.SENT
            and context.state == Const.SwapMessageState.WAIT_CREATOR_CONFIRM
        then
            if params.op == Const.SwapOperateType.ACCEPT then
                gainCardId = context.selectedCardId or params.selectedCardId
                receiveData = {type = context.type, profile = context.profile}
            elseif params.op == Const.SwapOperateType.REJECT then
                gainCardId = context.cardId
            end
        end
    end
    if gainCardId then
        if receiveData then
            local cardData = model:getCardDataById(gainCardId)
            local wasNew = cardData:getGotNum() <= 0
            self:onGetCard(gainCardId, 1)
            self:addRewardsNormal({{
                itemId = cardData:getItemId(),
                num = 1,
            }}, {
                dcFeature = "collect_card",
                dcSource = "friend_card_receive",
            })
            local repeatStarNum
            if not wasNew then repeatStarNum = cardData:getStarLevel() end
            self:dcActPlug():dcCardReceiveReward(
                string.format(
                    "%s_%s_%s",
                    cardData:getCardId(),
                    cardData:getStarLevel(),
                    cardData:getAlbumId()
                ),
                receiveData.profile.xxlId,
                receiveData.type == Const.SwapCreateType.EXCHANGE and 2 or 1,
                wasNew and 1 or 2,
                repeatStarNum
            )
        else
            self:onGetCard(gainCardId, 1)
        end
    end
    model:applySwapOperateSuccess(data, params, context)
end

function Manager:requestSwapMessageList(params)
    return self:getModel():requestSwapMessageList(params)
end

function Manager:refreshSwapData()
    return self:requestGetMainInfo(false):next(function()
        return self:requestSwapMessageList()
    end)
end

function Manager:_getAutoPopConfigList()
    local PopStage = AutoPopupConst.PopStage
    local configs = {
        {
            checkPoint = PopupCheckPoint.COLLECT_CARD_FLOW_POP_STAGE2,
            stages = {PopStage.STAGE_TWO},
            actId = self.ACT_ID,
            check = function(stageParams)
                -- 注册式强弹的 check/pop 收到的是场景事件对象，事件数据经 getData 取。
                local stageData = stageParams:getData() or {}
                -- 仅本次启动首次进入主场景时补开卡包
                return self:isActValid()
                    and stageData.isFirstEnter == true
                    and self:_tryAutoPopOpenCardPackFlowCond()
            end,
            pop = function(_, onPopOver)
                return self:createOpenCardPackFlowCreator(onPopOver)
            end,
        },
        {
            checkPoint = PopupCheckPoint.COLLECT_CARD_FLOW_POP_STAGE4,
            stages = {PopStage.STAGE_FOUR},
            actId = self.ACT_ID,
            check = function()
                return self:isActValid()
                    and self:_tryAutoPopOpenCardPackFlowCond()
            end,
            pop = function(_, onPopOver)
                return self:createOpenCardPackFlowCreator(onPopOver)
            end,
        },
        {
            checkPoint = PopupCheckPoint.COLLECT_CARD_DAILY_GIFT_POP,
            stages = {PopStage.STAGE_FOUR},
            actId = self.ACT_ID,
            check = function()
                return self:isActValid()
                    and self:_tryDailyPopGiftPaenlCond()
            end,
            pop = function(_, onPopOver)
                return function()
                    local isOpenedGiftPanel = false
                    local function closePanelCallback()
                        self:getGiftModule():setAutoPopup()
                        safeRunCall(onPopOver)
                    end
                    local function openedCallback(ret)
                        isOpenedGiftPanel = ret
                        if not isOpenedGiftPanel then
                            closePanelCallback()
                        end
                    end
                    self:tryDownLoadRes(true):next(function()
                        if self._isCreaingNewCardPanel then
                            closePanelCallback()
                            return
                        end
                        self:openNewCardPanel(closePanelCallback, {}, false, openedCallback)
                    end, function()
                        closePanelCallback()
                    end)
                end
            end,
        },
        {
            checkPoint = PopupCheckPoint.COLLECT_CARD_PROGRESS_TIP,
            stages = {PopStage.STAGE_FOUR},
            -- actId = self.ACT_ID, -- 不看做活动强弹，此tip按理说应该是受icon tip管理
            check = function()
                return self:isActValid()
                    and self:_tryProgressTipPopCond()
            end,
            pop = function(_, onPopOver)
                return function()
                    local currentInfo = self:getProgressTipInfo()
                    if not currentInfo or not currentInfo.tier then
                        safeRunCall(onPopOver)
                        return
                    end

                    local icon = self.iconModule:getActivityIcon()
                    local shown = false
                    if icon and icon.showProgressTip and not icon.isDisposed then
                        shown = icon:showProgressTip(currentInfo) == true
                    end
                    if shown then
                        local currentPopKey = self:_getProgressTipPopLocalKey(currentInfo.tier)
                        self:setFlagToLocalByKey(currentPopKey, false, true)
                        self._progressTipShowed = true
                    end
                    safeRunCall(onPopOver)
                end
            end,
        },
    }

    -- 集卡三选一礼包（4100）自身没有 Manager，强弹注册放到 ThreeForOneGiftModule，
    -- 跟随开心卡册的 AutoPop plug 一起注册/注销。
    for _, config in ipairs(self:getThreeForOneGiftModule():getAutoPopConfigList()) do
        table.insert(configs, config)
    end
    return configs
end

-- 集卡三选一礼包强弹模块：AutoPop plug 在 _init 之前就会读取强弹配置，所以这里按需创建。
function Manager:getThreeForOneGiftModule()
    if not self._threeForOneGiftModule then
        self._threeForOneGiftModule = ThreeForOneGiftModule.new(self)
    end
    return self._threeForOneGiftModule
end

function Manager:hex2Vec4(hex)
    local ccc4 = hex2ccc4(hex)
    return Vec4(ccc4.r/255, ccc4.g/255, ccc4.b/255, ccc4.a/255)
end

function Manager:registerEvents()
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
    CollectCardEventCenter:registerTransaction(self)
    CollectCardEventCenter:registerFeature(self)
    IconEventCenter:register(IconEvent.ICON_SYSTEM_READY, function()
        self.iconModule:onIconSystemReady()
    end)
    self:addEventDispatcher()
    self:registerActEvent()
    ExchangeShopEventCenter:register(ExchangeShopEvent.EXCHANGE_SHOP_OFFLINE_ICON_REMOVE, self.onExchangeShopRemove, self)
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
    OpenShareEventCenter:register(OpenShareEvent.DC_ASK_PANEL, self.onOpenShareDcAskPanel, self)
    OpenShareEventCenter:register(OpenShareEvent.DC_SHARE_ENTERGAME, self.onOpenShareDcEnterGame, self)
end

function Manager:onOpenShareDcAskPanel(event)
    local data = event:getData() or {}
    local query = data.query or {}
    if tostring(query.shareType) ~= tostring(self:getConst().PlatformShare.SHARE_TYPE)
        or query.category ~= "vx_help"
        or query.subCategory ~= "main_panel_show"
    then
        return
    end

    local params = data.dcParam or {}
    params.t2 = 4
    params.card_id = data.context and data.context.collectCardId
end

function Manager:onOpenShareDcEnterGame(event)
    local data = event:getData() or {}
    local query = data.query or {}
    if tostring(query.shareType) ~= tostring(self:getConst().PlatformShare.SHARE_TYPE) then return end

    local params = data.dcParam or {}
    params.t4 = "card_help"
end

function Manager:onExchangeShopRemove()
    printx(33, "CollectCardManager:onExchangeShopRemove")
    self.iconModule:tryCreateActIcon(true, function()
        printx(33, "CollectCardManager:onExchangeShopRemove tryCreateActIcon callback")
        if not self.iconModule:canShowActIconUnlockAnim() then return end
        self.iconModule:playActIconUnlockAnim()
    end)
end

--[[
    flowType : "openCard" | "settle" | "openAndSettle" (默认)
    rewards : 包含卡包的奖励列表，仅 openCard/openAndSettle 类型使用，如果不传则开当前已有的所有卡包
    openAnimPanelConfig : 开包动画面板配置，如新手引导时的 subTitle
    fromAutoPop : 是否来自强弹流程，强弹流程内网络请求使用较短超时时间
    onComplete : 流程完成回调
    onError : 流程错误回调
]]
function Manager:onReceiveTransaction(event)
    local eventName = event:getName()
    local data = event:getData()
    if eventName == TransactionEvent.COLLECT_CARD_FLOW then
        self:startCollectCardFlow(data)
    end
end

function Manager:startCollectCardFlow(data)
    if self._isCreaingNewCardPanel or self._isNewCardPanelOpen then
        if EnvUtil:isDevelopMode() then
            CommonTip:showTip("新卡大礼包与开包流程同时触发")
        end
        table.insert(self._pendingCollectCardFlows, data)
        return
    end

    local flowType = data.flowType or _G.COLLECT_CARD_FLOW_TYPE.OPEN_AND_SETTLE

    if flowType == _G.COLLECT_CARD_FLOW_TYPE.OPEN_CARD then
        return self:_executeOpenCardFlow(data)
            :next(function(context)
                CollectCardLog:log("OpenCardPackFlow complete")
                if data.onComplete then data.onComplete(context) end
            end, function(error)
                CollectCardLog:log("OpenCardPackFlow error", error)
                if data.onError then data.onError(error) end
                return deferred.error(error)
            end)

    elseif flowType == _G.COLLECT_CARD_FLOW_TYPE.SETTLE then
        return self:_executeSettleCardRewardFlow(data)
            :next(function(context)
                CollectCardLog:log("SettleCardRewardFlow complete")
                if data.onComplete then data.onComplete(context) end
            end, function(error)
                CollectCardLog:log("SettleCardRewardFlow error", error)
                if data.onError then data.onError(error) end
                return deferred.error(error)
            end)

    elseif flowType == _G.COLLECT_CARD_FLOW_TYPE.OPEN_AND_SETTLE then
        return self:_executeOpenCardFlow(data)
            :next(function(context)
                data.cardPackRewards = context.cardPackRewards
                return self:_executeSettleCardRewardFlow(data)
            end, function(error)
                data.cardPackRewards = {}
                return self:_executeSettleCardRewardFlow(data)
            end)
            :next(function(context)
                CollectCardLog:log("OpenAndSettleFlow complete")
                if data.onComplete then data.onComplete(context) end
            end, function(error)
                CollectCardLog:log("OpenAndSettleFlow error", error)
                if data.onError then data.onError(error) end
                return deferred.error(error)
            end)
    else
        if data.onError then data.onError() end
        return deferred.error()
    end
end

function Manager:_startPendingCollectCardFlow()
    if self._isCreaingNewCardPanel or self._isNewCardPanelOpen then return end

    local data = table.remove(self._pendingCollectCardFlows, 1)
    if data then self:startCollectCardFlow(data) end
end

function Manager:_executeOpenCardFlow(data)
    local OpenCardPackFlowBuilder = require_debug "amf.feature.localactivity.collectcard.openflow.OpenCardPackFlowBuilder"
    local flowBuilder = OpenCardPackFlowBuilder.new()

    if data.fromAutoPop then
        flowBuilder:setSendRequestHook(function(requestParams)
            return self:requestOpenCardPack(requestParams, true)
        end)
    end

    if data.openAnimPanelConfig then
        flowBuilder:setOpenCardPackPanelConfig(data.openAnimPanelConfig)
    end
    local rewards = data.rewards
    if not rewards then
        rewards = self:generateCardPackRewardList()
    end

    return deferred.success()
        :next(function()
            return self:tryDownLoadRes(true)
        end)
        :next(function()
            return flowBuilder:build():execute(rewards)
        end, function()
            return deferred.error("download resource failed")
        end)
end

function Manager:generateCardPackRewardList()
    local pendingPacks = self:getDataByKey("pendingPacks") or {}
    local cardPackDataMap = self:getModel():getCardPackDataMap()
    local CardPackReward = require "amf.feature.localactivity.collectcard.CardPackReward"
    local rewardList = {}
    for _, cardPackId in ipairs(pendingPacks) do
        local cardPackData = cardPackDataMap[cardPackId]
        if cardPackData then
            local cardPackReward = CardPackReward.new({itemId = cardPackData.itemId})
            table.insert(rewardList, cardPackReward)
        end
    end
    return rewardList
end

function Manager:_executeSettleCardRewardFlow(data)
    local SettleCardRewardFlowBuilder = require_debug "amf.feature.localactivity.collectcard.openflow.SettleCardRewardFlowBuilder"
    local flowBuilder = SettleCardRewardFlowBuilder.new()
        :setManager(self)
        :setNotOpenMainPanel(data.notOpenMainPanel)

    return flowBuilder:build():execute(data)
end

function Manager:requestOpenCardPack(params, fromAutoPop)
    local request = fromAutoPop and self:getModel():requestOpenCardPackOnAutoPopout(params) or self:getModel():requestOpenCardPack(params)
    return request
    :next(function(response)
        self:dcActPlug():dcJoin()
        local data = response:getData() or {}
        local errorCode = data.errorCode
        if data.errorCode and data.errorCode == 0 then
            local oldRoundId = self:getModel():getRoundId()
            self:setDataByKey("round", data.roundId)
            response.oldRoundId = oldRoundId
            return deferred.success(response)
        else
            local pendingPacks = data.pendingPacks
            if pendingPacks then
                self:setDataByKey("pendingPacks", pendingPacks)
            end
            if errorCode then
                CommonTip:showErrorTip(tonumber(errorCode))
            end
            return deferred.error(response)
        end
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        return deferred.error(response)
    end)
end

function Manager:requestSettleCardReward(fromAutoPop)
    local request = fromAutoPop and self:getModel():requestSettleCardRewardOnAutoPopout() or self:getModel():requestSettleCardReward()
    return request
    :next(function(response)
        local data = response:getData() or {}
        local roundInfoMap = data.roundInfoMap or {}
        local roundRank = data.roundRank or 0
        self:setDataByKey("roundRank", roundRank)
        local newRoundId = self:getModel():getRoundId()
        self:setDataByKey("rewardRound", newRoundId)

        for roundId, roundInfo in pairs(roundInfoMap) do
            local roundRewards = roundInfo.roundRewards or {}
            if not table.isEmpty(roundRewards) then
                self:addRewardsNormal(roundRewards, {dcFeature = "collect_card", dcSource = "collect_reward"})
            end

            local albumResult = roundInfo.albumResult or {}
            for i, result in ipairs(albumResult) do
                local rewards = result.rewards or {}
                if not table.isEmpty(rewards) then
                    self:addRewardsNormal(rewards, {dcFeature = "collect_card", dcSource = "book_reward"})
                    self:dc("collect_card", "book_reward", {
                        t1 = result.albumId,
                        t2 = roundId,
                    })
                end
                local albumId = result.albumId
                local albumData = self:getAlbumDataById(albumId)
                albumData.hasGotReward = true
            end
        end
        self:setDataByKey("haveCardDoneReward", false)
        self:dcActPlug():dcJoin()
        return deferred.success(response)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        return deferred.error(response)
    end)
end

function Manager:updateData(data)
    if not data then return end
    self:getModel():syncMainInfo(data)
    self:registerActProps()
end

function Manager:requestShareReward(feature)
    return self:getModel():requestShareReward()
        :next(function(response)
            local data = response:getData() or {}
            local rewards = data.rewards or {}
            self:addRewardsNormal(rewards, { dcFeature = feature, dcSource = "share_success" })
            self:getModel():setDataByKey("shareRewardFlag", true)
            return rewards
        end)
end

function Manager:isTopLevelSupport()
    local topLevel = _G.getTopPassedLevelId()
    return topLevel >= self:getConst().MinTopPassedLevel
end

function Manager:isInActTime()
    local mainBeginTime = self:getModel():getMainBeginTime()
    local mainEndTime = self:getModel():getMainEndTime()
    local now = TimeKit:timeInSec()
    return (now >= mainBeginTime and now < mainEndTime)
end

function Manager:isLocalVersionSupport()
    local clientVersion = self:getDataByKey("clientVersion", 0)
    return (clientVersion ~= 0 and clientVersion <= self:getConst().ClientVersion)
end

function Manager:isBundleVersionSupport()
    local ver = tonumber(string.split(_G.bundleVersion, ".")[2])
    local openVersion = self:getDataByKey("openVersion", "1.155")
    local openVer = tonumber(string.split(openVersion, ".")[2])
    return ver >= openVer
end

function Manager:isActValid()
    local isInActTime = self:isInActTime()
    local isLocalVersionSupport = self:isLocalVersionSupport()
    local isTopLevelSupport = self:isTopLevelSupport()
    local isBundleVersionSupport = self:isBundleVersionSupport()
    -- CollectCardLog:log("CollectCardManager:isActValid", "isInActTime=", isInActTime, "isLocalVersionSupport=", isLocalVersionSupport, "isTopLevelSupport=", isTopLevelSupport, "isBundleVersionSupport=", isBundleVersionSupport)
    return isInActTime and isLocalVersionSupport and isTopLevelSupport and isBundleVersionSupport
end

function Manager:isEnabled()
    if not self._isResReady then
        self:tryDownLoadRes(false, true)
        return false
    end
    return self:isActValid() and self:getModel():isDataEnabled()
end

function Manager:isOpen()
    return self:isEnabled()
end

function Manager:loadActivity()
    if not self:isEnabled() and self:isActValid()  then
        return self:tryDownLoadRes()
        :next(function()
            return  self:requestGetMainInfo(false, true)
        end)
    else
        return deferred.success()
    end
end
---所有卡册plist
function Manager:getAlbumResource()
    local periodId = self:getModel():getPeriodId()
    local PeriodMeta = self:getConst().getPeriodMeta(periodId)
    local resPathList = {}
    for i, v in ipairs(PeriodMeta.AlbumMeta) do
        local plistPath = v.plistPath
        table.insert(resPathList, plistPath)
    end
    -- return _G.amfBean("AssetsUtil"):loadMiniFiles(plistPathList)
    return resPathList
end

---所有小卡册icon 路径 以及 AlbumCellUI图集
function Manager:getAlbumUIResource()
    local periodId = self:getModel():getPeriodId()
    local PeriodMeta = self:getConst().getPeriodMeta(periodId)
    local resPathList = {}
    for i, v in ipairs(PeriodMeta.AlbumMeta) do
        local albumIcon = v.albumIcon or tostring(i)
        local albumPath = string.format("amf/activity/collectcard/materials/album_icon/%s.png", albumIcon)
        table.insert(resPathList, albumPath)
    end
    table.insert(resPathList, "amf/activity/collectcard/texture/CollectProgress.plist")
    table.insert(resPathList, "amf/activity/collectcard/spine/finishalbum/duigou_tx.skel")
    table.insert(resPathList, "amf/activity/collectcard/spine/mantishi_fx.skel")
    return resPathList
end

---卡包icon
function Manager:getCardPackResource()
    local list = {}
    for i = 1, 5, 1 do
        table.insert(list, string.format("amf/activity/collectcard/materials/pack%d.png", i))
    end
    return list
end

function Manager:getSoundSource()
    local Const = self:getConst()
    local list = {}
    for i, v in pairs(Const.SoundPath) do
        table.insert(list, v)
    end
    return list
end

-- Card.lua 需要的资源
function Manager:getCardUIResource()
    local list = {
        "amf/activity/collectcard/texture/Card.plist",
        "amf/activity/collectcard/spine/opencardflow/kasaoguang.skel",
        "amf/activity/collectcard/materials/card_selected_outline_mask.png",
    }
    return list
end

function Manager:getPersonalCenterRecordResFiles()
    local files = {}
    local seen = {}

    local function insertFile(path)
        if type(path) == "string" and path ~= "" and not seen[path] then
            seen[path] = true
            table.insert(files, path)
        end
    end

    insertFile("amf/activity/collectcard/materials/recordRes/collectCardIcon.png")

    local const = self:getConst()
    local periodMeta = const and const.periodMeta
    if type(periodMeta) ~= "table" then
        return files
    end

    for _, meta in pairs(periodMeta) do
        local recordRes = meta and meta.PersonalCenterRecordRes
        if type(recordRes) == "table" then
            for _, path in pairs(recordRes) do
                insertFile(path)
            end
        end
    end

    return files
end

function Manager:isEnabledInLevel()
    return
end

function Manager:getDataByKey(key, defaultValue) return self:getModel():getDataByKey(key, defaultValue) end
function Manager:setDataByKey(key, value) return self:getModel():setDataByKey(key, value, true) end
function Manager:getConfigByKey(key, defaultValue) return self:getModel():getConfigByKey(key, defaultValue) end

function Manager:getCacheLocalKey(key)
    return "localCache."..(key or "defaultKey")
end

function Manager:setFlagToLocalByKey(key, needTime, value)
    if not key then return end
    if value == nil then value = true end
    self:getModel():saveFlagToLocalByKey(self:getCacheLocalKey(key), needTime, value, true)
end

function Manager:isSwapAcceptDisabled(messageId)
    return self:getModel():isSwapAcceptDisabled(messageId)
end

function Manager:setSwapAcceptDisabled(messageId, disabled)
    return self:getModel():setSwapAcceptDisabled(messageId, disabled)
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

function Manager:isLastDay(  )
    return self:getModel():isLastDay()
end

function Manager:getDayFromActOpen( time )
    return self:getModel():getDayFromActOpen(time)
end

function Manager:getDayFrom1970( time )
    return self:getModel():getDayFrom1970(time)
end

function Manager:hasGuideIndex(index)
    local hasIndex = self:getModel():hasGuide(index)
    return hasIndex
end

function Manager:addGuideIndex(index)
    self:getModel():setGuide(index)
    local ActCommonHttp = require "amf.middleware.activity.http.ActCommonHttp"
    ActCommonHttp:setActGuideFlag(Manager.ACT_ID, index, true)
end

function Manager:dc(category, subCategory, extraData)
    local params = {
        category = category,
        sub_category = subCategory,
    }

    for i, v in pairs(extraData or {}) do
        params[i] = v
    end
    DcUtil:UserTrack(params)
end

---sugar - self:callDCFunc("funName", ...)
---@return CollectCardDC
function Manager:dcActPlug()
    local dcActPlug = self:_getPlug("DC")
    return dcActPlug
end

function Manager:getActInfo()
    return _G.amfBean("ActivityMgr"):getActInfo(Manager.ACT_ID)
end

function Manager:isInMainTime()
    return self:getModel():isInMainTime()
end

function Manager:isInGamePlayScene()
    local isInGamePlayScene = UBFPlaySceneLauncher and UBFPlaySceneLauncher:isInGamePlayScene()
    if isInGamePlayScene then
        printx(48, "CollectCardManager: 关内调用了集卡面板??", debug.traceback())
        if EnvUtil:isDevelopMode() then
            CommonTip:showTip("关内调用了集卡面板??")
        end
    end
    return isInGamePlayScene
end

function Manager:openActivity(closeCallback, extra, userClick)
    if self:isInGamePlayScene() then
        safeRunCall(closeCallback)
        return
    end
    if self.isRequestingMain then safeRunCall(closeCallback) return end
    self.isRequestingMain = true
    self:notify(CollectCardEvent.CLOSE_ALL_PANEL)

    local openFail = false

    deferred.success()
    :next(function()
        return self:tryDownLoadRes(userClick)
    end)
    :next(function()
        return self:requestGetMainInfo(userClick)
    end)
    :next(function()
        self._isGetedMainInfo = true
        self.isRequestingMain = false
        printx(33, "CollectCardManager:openActivity success")
        if self:getModel():isInMainTime() then
            self:openMainPanel(closeCallback, extra, userClick)
        elseif self:getModel():isInRewardTime() then
            openFail = true
            safeRunCall(closeCallback,nil,openFail)
        else
            -- 无预热期
            openFail = true
            safeRunCall(closeCallback,nil,openFail)
        end
    end, function()
        self.isRequestingMain = false
        openFail = true
        safeRunCall(closeCallback,nil,openFail)
    end)
end

function Manager:openMainPanel(closeCallback, extra, userClick)
    if self:isInGamePlayScene() then
        safeRunCall(closeCallback)
        return
    end
    --1.是否新的一期预热 开启面板
    --2.是否是新手，开启新手卡包，否则是否有新一轮卡包，之前补开队列冗余卡包
        -- 前端只关心 newRoundGiftRewards(后端会根据round==1设置不同的值)
        -- 如果为空，检查之前补开队列冗余卡包
    local isNewRound = self:isCanOpenPreheatPanel(true)
    local hasOpenedMainPanelByFlow = false
    deferred.success():next(function ()
        local d = deferred.new()
        if isNewRound then
            local function closeCallBack()
                d:resolve()
            end
            self:openCardAllRewardsPanel(true, closeCallBack)
        else
            d:resolve()
        end
        return d
    end):next(function ()
        local d = deferred.new()
        local rewards = self:getDataByKey("newRoundGiftRewards")
        if rewards and not table.isEmpty(rewards) then
            --测试开卡流程
            _G.amfTransaction(TransactionEvent.COLLECT_CARD_FLOW, {
                flowType = _G.COLLECT_CARD_FLOW_TYPE.OPEN_CARD,
                rewards = rewards,
                -- openAnimPanelConfig = {
                --     subTitle = "送你一个新的卡包"
                -- },
                onComplete = function(context)
                    self:setDataByKey("newRoundGiftRewards", {})
                    d:resolve()
                end,
                onError = function()
                    d:resolve()
                end,
            })
            local isGuide = self:isMainPanelGuide()
            local type = isGuide and 1 or 2
            self:dcActPlug():dcGainCardPack(type, rewards)
        else
            d:resolve()
        end
        return d
    end):next(function()
        -- 尝试领奖
        local d = deferred.new()
        _G.amfTransaction(TransactionEvent.COLLECT_CARD_FLOW, {
            flowType = _G.COLLECT_CARD_FLOW_TYPE.OPEN_AND_SETTLE,
            onComplete = function(data)
                if data.hasOpenedMainPanel then
                    hasOpenedMainPanelByFlow = true
                end
                d:resolve()
            end,
            onError = function()
                d:resolve()
            end,
        })
        return d
    end):next(function ()
        -- 在前面的结算流程中已经打开过主面板了，这里就不再打开
        if hasOpenedMainPanelByFlow then
            safeRunCall(closeCallback)
            return deferred.success()
        end
        local PanelVM = require "amf.feature.localactivity.collectcard.view.MainPanelVM"
        local vm = PanelVM.Builder.new()
            :setCloseCallback(closeCallback)
            :setUserClick(userClick)
            :build()
        vm:popout()
        self:callPanelFunc("managePanelVM", vm)
        return deferred.success()
    end, function ()
        safeRunCall(closeCallback)
        return deferred.error()
    end)

end

function Manager:updateActIcon()
    self.iconModule:updateActIcon()
end

function Manager:updateGiftIcon()
    self.iconModule:updateGiftIcon()
end

function Manager:getCollectCardGiftIconV2Snapshot()
    return self.iconModule:getGiftIconV2Snapshot()
end

function Manager:createCollectCardGiftIconNewActivityRecordStore()
    return self.iconModule:createGiftIconNewActivityRecordStore()
end

function Manager:getActivityIcon()
    return self.iconModule:getActivityIcon()
end

function Manager:onGiftIconTapped()
    deferred.success()
    :next(function()
        return self:tryDownLoadRes(true)
    end)
    :next(function()
        self:openNewCardPanel(nil, nil, true)
    end)
end

function Manager:onActTestButtonReady()
    if not EnvUtil:isDevelopMode() then return end
    require "amf.feature.localactivity.collectcard.test.CollectCardTestBtns"
end

function Manager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local actInfo = actInfos[tostring(self.ACT_ID)]
    local fromServer = data.fromServer
    if actInfo and fromServer then
        self:getModel():syncActInfo(actInfo)
        self:updateActIcon()
        self:registerActEvent()
        self.iconModule:updateGiftIcon()
        if self:isActValid() then
            self:tryLightStart()
        end
    end
    if fromServer then
        if self.iconModule:needShowActIcon() then
            self.iconModule:tryCreateActIcon()
        else
            self.iconModule:removeActIcon()
        end
    end
end

function Manager:tryLightStart()
    if not self._hasDoneLightStart then
        self:requestGetMainInfo(false, true)
        self._hasDoneLightStart = true
    end
end

function Manager:onActPlayLevelEnd(evt)
    if EnvUtil:isDevelopMode() then printx(48, "onActPlayLevelEnd=",tts(evt.data)) end
    self:getGiftModule():onActPlayLevelEnd()

end

function Manager:onActEnterStage4(evt)
    if not self:isActValid() then return end
    self:tryPlayActIconUnlockAnimInStage4()
end

-- icon解锁动画
function Manager:tryPlayActIconUnlockAnimInStage4()
    if not _G.amfBean("IconManager"):useUIBottomBarTest() then return end
    if not self.iconModule:canShowActIconUnlockAnim() then return end
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.FEATURE_UNLOCK_GUIDE)
    end

    local creator = function ()
        self.iconModule:playActIconUnlockAnim(onHandleOver)
    end
     _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.FEATURE_UNLOCK_GUIDE, creator)
end

function Manager:skipThisRoundCardPackOpen()
    self._skipCardPackOpenThisRound = true
end

-- 强弹开包（场景2/场景4 的注册式强弹共用，onPopOver 由强弹框架注入）
function Manager:createOpenCardPackFlowCreator(onPopOver)
    return function ()
        if self._skipCardPackOpenThisRound then
            self._skipCardPackOpenThisRound = false
            safeRunCall(onPopOver)
            return
        end
        CollectCardLog:log("tryAutoPopOpenCardPackFlow start")
        _G.amfTransaction(TransactionEvent.COLLECT_CARD_FLOW, {
            flowType = _G.COLLECT_CARD_FLOW_TYPE.OPEN_AND_SETTLE,
            fromAutoPop = true,
            onComplete = onPopOver,
            onError = onPopOver,
        })
    end
end

function Manager:_tryAutoPopOpenCardPackFlowCond()
    if not self:getModel():isDataEnabled() then return false end
    local haveCardDoneReward = self:getDataByKey("haveCardDoneReward", false)
    local pendingPacksNum = self:getDataByKey("pendingPacksNum", 0)
    if not haveCardDoneReward and pendingPacksNum == 0 then return false end
    return true
end

function Manager:_tryDailyPopGiftPaenlCond()
    local canPopup = self:getGiftModule():canAutoPopup()
    return canPopup
end


---是否有强弹面板
function Manager:isCanAtuoPopAnyPanel()
    local ret = self:_tryAutoPopOpenCardPackFlowCond()
    if not ret then ret = self:_tryDailyPopGiftPaenlCond() end
    if not ret then ret = self:_tryProgressTipPopCond() end
    return ret
end


function Manager:_tryProgressTipPopCond()
    if not self:getModel():isDataEnabled() then return false end
    local progressInfo = self:getProgressTipInfo()
    if not progressInfo then return false end
    local popKey = self:_getProgressTipPopLocalKey(progressInfo.tier)
    if self:getFlagFromLocalByKey(popKey, false) then return false end
    return progressInfo
end

---计算场景4进度提示信息：统计已收集>=7张的卡册，并要求其中至少一套未集满。
function Manager:getProgressTipInfo()
    -- do return {incompleteAlbumNum=5, nearlyCompleteAlbumNum=15, threshold=13, tier="c", totalAlbumNum=15} end --debug
    local nearlyCompleteAlbumNum = 0
    local incompleteAlbumNum = 0
    local hasIncompleteQualifiedAlbum = false
    self:getModel():foreachAlbumData(function(albumData)
        local collectedCount = albumData:getCollectedCount()
        local isComplete = albumData:isAlbumComplete()
        if not isComplete then
            incompleteAlbumNum = incompleteAlbumNum + 1
        end
        if collectedCount >= PROGRESS_TIP_MIN_CARD_COUNT then
            nearlyCompleteAlbumNum = nearlyCompleteAlbumNum + 1
            if not isComplete then
                hasIncompleteQualifiedAlbum = true
            end
        end
    end)

    if not hasIncompleteQualifiedAlbum then return nil end

    local totalAlbumNum = tonumber(self:getModel():getTotalAlbumCount()) or 0
    local thresholds = PROGRESS_TIP_THRESHOLDS[totalAlbumNum] or PROGRESS_TIP_THRESHOLDS[15]

    local tier
    for _, tierName in ipairs(PROGRESS_TIP_TIER_ORDER) do
        if nearlyCompleteAlbumNum >= thresholds[tierName] then
            tier = tierName
            break
        end
    end
    if not tier then return nil end

    return {
        tier = tier,
        nearlyCompleteAlbumNum = nearlyCompleteAlbumNum,
        incompleteAlbumNum = incompleteAlbumNum,
        threshold = thresholds[tier],
        totalAlbumNum = totalAlbumNum,
    }
end

---返回已收集达到7张的卡册数量；是否存在未集满卡册由getProgressTipInfo判断。
function Manager:getNearlyCompleteAlbumNum()
    local count = 0
    self:getModel():foreachAlbumData(function(albumData)
        if albumData:getCollectedCount() >= PROGRESS_TIP_MIN_CARD_COUNT then
            count = count + 1
        end
    end)
    return count
end

---返回已收集达到7张的卡册ID。
function Manager:getNearlyCompleteAlbumIds()
    local ids = {}
    self:getModel():foreachAlbumData(function(albumData)
        if albumData:getCollectedCount() >= PROGRESS_TIP_MIN_CARD_COUNT then
            table.insert(ids, albumData:getAlbumId())
        end
    end)
    return ids
end

--- 主界面使用，设置needPlaySweepLight
function Manager:getAlbumListFromMainPanel()
    local albumDataList = self:getModel():getAlbumDataList()
    if self:isProgressTipShowed() then
        for index, albumData in ipairs(albumDataList) do
            local collectedCount = albumData:getCollectedCount()
            albumData.needPlaySweepLight = collectedCount >= PROGRESS_TIP_MIN_CARD_COUNT
                and not albumData:isAlbumComplete()
        end
    end
    -- if EnvUtil:isDevelopMode() then --debug 测试特效
    --     albumDataList[1].needPlaySweepLight = true
    --     albumDataList[3].needPlaySweepLight = true
    --     albumDataList[4].needPlaySweepLight = true
    --     albumDataList[15].needPlaySweepLight = true
    -- end
    return albumDataList
end

---本次进入主界面是否需要播放进度提示关联的扫光效果
function Manager:isProgressTipShowed()
    return self._progressTipShowed == true
end

---设置进度提示气泡已强弹标记
function Manager:setProgressTipShowed(value)
    self._progressTipShowed = value
end

---本地存储key：按活动期+档位记录，确保每档单期只弹一次。
function Manager:_getProgressTipPopLocalKey(tier)
    local periodId = self:getModel():getPeriodId()
    return string.format("progressTipPop_%s_%s", tostring(periodId), tostring(tier))
end

function Manager:onActPassBeginTime()
    CollectCardEventCenter:dispatch(CollectCardEvent.CARD_NUM_UPDATE)
end

function Manager:onActPassMainBeginTime()
    local observerNum = self:getObserverNum()
    if observerNum > 0 then
        self:notify(CollectCardEvent.CLOSE_ALL_PANEL)
        CommonTip:showTip('开心卡册活动已正式开启，\n请尝试重进活动~')
    end
end

function Manager:onActPassMainEndTime()
    local observerNum = self:getObserverNum()
    if observerNum > 0 then
        self:notify(CollectCardEvent.CLOSE_ALL_PANEL)
        CommonTip:showTip('开心卡册活动已结束！')
    end
    self:getModel():clearAct()
end

function Manager:onActPassEndTime()
    local observerNum = self:getObserverNum()
    if observerNum > 0 then
        self:notify(CollectCardEvent.CLOSE_ALL_PANEL)
        CommonTip:showTip('开心卡册活动已结束！')
    end
    self:getModel():clearAct()
end

function Manager:onActPassDay()
    printx(33, "CollectCardManager:onActPassDay")
    BaseFeatureManager.onActPassDay(self)
    local observerNum = self:getObserverNum()
    if observerNum > 0 then
        self:notify(CollectCardEvent.CLOSE_ALL_PANEL)
        CommonTip:showTip('新的一天开始了，数据已更新，\n请尝试重进活动~')
    end
end

function Manager:onPassActMainNext()
    BaseFeatureManager.onPassActMainNext(self)
end

function Manager:onSystemEnterForeground()
    if self.returnBackCallback and self.returnBackCallbackValid == true then
        safeRunCall(self.returnBackCallback)
        self.returnBackCallback = nil
        self.returnBackCallbackValid = false
    end
end

function Manager:onSystemEnterBackground()

end

function Manager:addRewardsNormal(rewardItems, params)
    self:_addRewards(rewardItems, nil, params)
end

function Manager:_addRewards(rewardItems, payType, params)
    local dcFeature, dcSource
    if params and params.dcFeature and params.dcSource then
        dcFeature, dcSource = params.dcFeature, params.dcSource
    end

    _G.GainPropData:create()
        :setFeature(dcFeature)
        :setSource(dcSource)
        :setProps(rewardItems)
        :execute()
end

function Manager:addActItem(reward)
    if self:isCardPack(reward.itemId) then
        local pendingPacks = self:getDataByKey("pendingPacks", {})
        local level = self:getCardPackLevel(reward.itemId)
        local addNum = reward.num or 1
        for i = 1, addNum do
            table.insert(pendingPacks, level)
        end
        self:setDataByKey("pendingPacks", pendingPacks)
        local pendingPacksNum = self:getDataByKey("pendingPacksNum", 0)
        self:setDataByKey("pendingPacksNum", #pendingPacks)
    end
end

function Manager:createCard(cardData, isDefault)
    local Card = require "amf.feature.localactivity.collectcard.view.Card"
    local card = Card:create(cardData, isDefault)
    return card
end

function Manager:createCardIcon(albumId, posId)
    local cardData = self:getModel():getCardDataByPosId(albumId, posId)
    if cardData then
        local itemId = cardData:getItemId()
        return self:createCardIconByItemId(itemId)
    else
        return Sprite:createEmpty()
    end
end

function Manager:createCardIconByItemId(itemId)
    local icon = GameItemCreator:getPropIcon({itemId = itemId})
    return icon
end

function Manager:getAlbumDataById(id)
    return self:getModel():getAlbumDataById(id)
end

function Manager:hasReward()
    return false
end

function Manager:getMsgNum()
    if not self:isActValid() then return 0 end
    return math.max(0, tonumber(self:getModel():getUnSeeMessageCount()) or 0)
end

function Manager:isCardPack(itemId)
    local const = self:getConst()
    return itemId == const.CardPack_1_itemId
        or itemId == const.CardPack_2_itemId
        or itemId == const.CardPack_3_itemId
        or itemId == const.CardPack_4_itemId
        or itemId == const.CardPack_5_itemId
end

function Manager:isCardItem(itemId)
    local cardData = self:getModel():getCardDataByItemId(itemId)
    return cardData ~= nil
end

function Manager:getCardPackLevel(itemId)
    return self:getConst().CardPackLevel[itemId] or 1
end

function Manager:getCardDataById(id)
    return self:getModel():getCardDataById(id)
end

function Manager:getCardDataByItemId(itemId)
    return self:getModel():getCardDataByItemId(itemId)
end

function Manager:getCardIdByItemId(itemId)
    local cardData = self:getModel():getCardDataByItemId(itemId)
    return cardData and cardData.cardId or nil
end

function Manager:getCardItemIdById(id)
    local cardData = self:getModel():getCardDataById(id)
    return cardData and cardData.itemId or nil
end

function Manager:onGetCard(id, num)
    self:getModel():addCard(id, num)
    self:refreshCardNumDelay()
end

-- 延迟刷新，减少重复调用
function Manager:refreshCardNumDelay()
    if self._isWaitingRefresh then return end
    self._isWaitingRefresh = true
    setTimeOut(function()
        local cardCount = self:getModel():getHasCardCount(true)
        local unlockCardNum = self:getDataByKey("unlockCardNum", 0)
        printx(33, "refreshCardNumDelay cardCount:", cardCount, "unlockCardNum:", unlockCardNum)
        self:setDataByKey("unlockCardNum", cardCount)
        self:getModel():updateNeedSettleFlag()
        self:updateStarExchangeRedPoint()
        CollectCardEventCenter:dispatch(CollectCardEvent.CARD_NUM_UPDATE)

        self._isWaitingRefresh = false
    end, 0)
end

function Manager:getCardViewed(cardId)
    local viewedCards = self:getModel():getValue("viewedCards", {})
    return viewedCards[tostring(cardId)]
end

function Manager:setCardViewed(cardId, isViewed)
    local viewedCards = self:getModel():getValue("viewedCards", {})
    viewedCards[tostring(cardId)] = isViewed
    self:getModel():setValue("viewedCards", viewedCards)
    self:updateActIcon()
end

-- 注册卡片道具id
function Manager:tryRegisterCardReward()
    local albumDataList = self:getModel():getAlbumDataList()
    for i, albumData in ipairs(albumDataList) do
        local cardIds = albumData:getCardIds()
        for j, cardId in ipairs(cardIds) do
            local cardData = self:getModel():getCardDataById(tonumber(cardId))
            if cardData then
                local itemId = tostring(cardData.itemId)
                if not self._propRegistered[itemId] then
                    self._propRegistered[itemId] = true
                    -- local cardData = self:getValue("userInfo.CardDataMap." .. itemId)
                    self:registerCardReward(cardData)
                end
            end
        end
    end
end

function Manager:registerCardReward(cardData)
    -- 这里注册貌似暂时没有什么用？暂时先不注册道具了
    -- printx(33, "registerCardReward, itemId:", cardData.itemId)
    -- local albumId = cardData.albumId
    -- local cardId = cardData.cardId
    -- local itemId = cardData.itemId
    -- local frameName = cardData.frameName
    -- local albumData = self:getModel():getAlbumDataById(albumId)
    -- local plistPath = albumData.plistPath
    -- AMFPropBuilder.create(itemId)
    -- :setCategory(AMFPropConst.Category.ACTIVITY)
    -- :setMergable(false)

    -- -- icon
    -- :startComponent(AMFPropConst.ComponentId.ICON)
    -- :setCreator(function()
    --     local icon = UICreateUtil:createSpriteWithPlist(plistPath, frameName, true)
    --     return icon
    -- end)
    -- :endComponent()

    -- -- 自定义添加
    -- :startComponent(AMFPropConst.ComponentId.PROPCHANGE_LOGIC)
    -- :setPropGainFunction(function(reward)
    --     self:addActItem(reward)

    --     local deferred = require "amf.script.sugar.deferred"
    --     return deferred.success()
    -- end)
    -- :setPropConsumeFunction(function()
    --     local deferred = require "amf.script.sugar.deferred"
    --     return deferred.success()
    -- end)
    -- :setNeedUsePropHttp(false)
    -- :buildAndRegister()
end

function Manager:requestGetMainInfo(userClick, fromLightStart)
    local params = {
        clientVersionedConfig = {
            clientMd5 = self:getDataByKey("clientMd5")
        },
        light = fromLightStart,
        periodVersion = self:getModel():getPeriodId(),
        clientVersion = self:getConst().ClientVersion,
    }
    -- params.clientVersionedConfig.clientMd5 = "" --debug

    local request
    if fromLightStart then
        request = self:getModel():requestGetMainInfoOnLightStart(params)
    elseif userClick == false then
        request = self:getModel():requestGetMainInfoOnAutoPopout(params)
    else
        request = self:getModel():requestGetMainInfo(params)
    end

    return request
    :next(function(response)
        local data = response.data
        self:updateData(data)
        self:updateActIcon()
        return deferred.success(response)
    end, function(response)
        if not response:isCancel() and not fromLightStart then
            CommonTip:showErrorTip(response)
        end
        return deferred.error(response)
    end)
end

--- 找出满足 >= target 的最小组合
---@param target number 目标值
---@return number 实际消耗总值
---@return table 实际消耗对应的卡牌组合
function Manager:pickBestCardCombo(target)
    if not target or target <= 0 then return 0, {} end

    local cards = self:getModel():getCards()
    local starGroups = {} -- 按星级分组的卡牌
    for i = 1, 5 do starGroups[i] = {} end

    for i, cardData in ipairs(cards) do
        if cardData:getGotNum() > 1 then
            local starLevel = cardData:getStarLevel()
            table.insert(starGroups[starLevel], cardData)
        end
    end

    for star = 1, 5 do
        table.sort(starGroups[star], function(left, right)
            local leftAvailable = left:getGotNum() - 1
            local rightAvailable = right:getGotNum() - 1
            if leftAvailable ~= rightAvailable then
                return leftAvailable > rightAvailable
            end
            return tonumber(left:getCardId()) < tonumber(right:getCardId())
        end)
    end

    local availableCounts = {}
    for star = 1, 5 do
        availableCounts[star] = 0
        for i, cardData in ipairs(starGroups[star]) do
            -- 需要保留一张卡片
            availableCounts[star] = availableCounts[star] + cardData:getGotNum() - 1
        end
    end

    local priorityFiveCount = math.min(math.floor(target / 5), availableCounts[5])
    availableCounts[5] = availableCounts[5] - priorityFiveCount
    local remainingTarget = target - priorityFiveCount * 5

    local maxCapacity = remainingTarget + 4
    local dp = {}
    local choice = {}
    for sum = 0, maxCapacity do dp[sum] = false end
    dp[0] = true

    for star = 1, 5 do
        local count = availableCounts[star]
        if count > 0 then
            local usedCount = {}
            for sum = 0, maxCapacity do usedCount[sum] = 0 end
            for sum = star, maxCapacity do
                if not dp[sum] and dp[sum - star] and usedCount[sum - star] < count then
                    dp[sum] = true
                    usedCount[sum] = usedCount[sum - star] + 1
                    choice[sum] = star
                end
            end
        end
    end

    local best_sum
    for sum = remainingTarget, maxCapacity do
        if dp[sum] then
            best_sum = sum
            break
        end
    end
    if not best_sum then return 0, {} end

    local needCounts = { [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = priorityFiveCount }
    local currentSum = best_sum
    while currentSum > 0 do
        local usedStar = choice[currentSum]
        needCounts[usedStar] = needCounts[usedStar] + 1
        currentSum = currentSum - usedStar
    end

    -- 提取卡牌实体
    local combo = {}
    for star = 1, 5 do
        local need = needCounts[star]
        if need > 0 then
            local group = starGroups[star]
            -- 从该星级池中取出 need 张卡
            for _, cardData in ipairs(group) do
                if need <= 0 then break end
                local costNum = math.min(cardData:getGotNum() - 1, need)
                -- 记录使用了哪些卡和数量
                table.insert(combo, {
                    cardId = cardData:getCardId(),
                    costNum = costNum,
                })
                need = need - costNum
            end
        end
    end

    if EnvUtil:isDevelopMode() then
        printx(48, "[CollectCard]pickBestCardCombo best_sum=",best_sum, ";combo=", tts(combo))
    end

    return priorityFiveCount * 5 + best_sum, combo
end

function Manager:pickBestCardComboLegacy(target)
    if not target or target <= 0 then return 0, {} end

    local cards = self:getModel():getCards()
    local starGroups = {} -- 按星级分组的卡牌
    for i = 1, 5 do starGroups[i] = {} end

    for i, cardData in ipairs(cards) do
        if cardData:getGotNum() > 1 then
            local starLevel = cardData:getStarLevel()
            table.insert(starGroups[starLevel], cardData)
        end
    end

    local availableCounts = {}
    for star = 1, 5 do
        availableCounts[star] = 0
        for i, cardData in ipairs(starGroups[star]) do
            -- 需要保留一张卡片
            availableCounts[star] = availableCounts[star] + cardData:getGotNum() - 1
        end
    end

    local dp = {}     -- 是否能凑出总和 j
    local choice = {} -- 记录凑出 j 时，最后一步加了哪种星级的卡

    -- 因为最大的卡星级是5，所以最大组合数为 target + 4
    local maxCapacity = target + 4
    for j = 0, maxCapacity do
        dp[j] = false
    end
    dp[0] = true

    for star = 1, 5 do
        local count = availableCounts[star]
        if count > 0 then
            -- usedCount[j] 记录对于当前星级 star，凑成体积 j 时已经使用了几张
            local usedCount = {}
            for j = 0, maxCapacity do usedCount[j] = 0 end

            for j = star, maxCapacity do
                if not dp[j] and dp[j - star] and usedCount[j - star] < count then
                    dp[j] = true
                    usedCount[j] = usedCount[j - star] + 1
                    choice[j] = star  -- 达到体积 j 时，最后加的是一张 star 星级的卡
                end
            end
        end
    end

    -- 找到 >= target 的最小值
    local best_sum = -1
    for j = target, maxCapacity do
        if dp[j] then
            best_sum = j
            break
        end
    end

    if best_sum == -1 then return 0, {} end

    -- 用了哪些星级各几张
    local needCounts = { [1] = 0, [2] = 0, [3] = 0, [4] = 0, [5] = 0 }
    local current_sum = best_sum
    while current_sum > 0 do
        local usedStar = choice[current_sum]
        needCounts[usedStar] = needCounts[usedStar] + 1
        current_sum = current_sum - usedStar
    end

    -- 提取卡牌实体
    local combo = {}
    for star = 1, 5 do
        local need = needCounts[star]
        if need > 0 then
            local group = starGroups[star]
            -- 从该星级池中取出 need 张卡
            for _, cardData in ipairs(group) do
                if need <= 0 then break end
                local costNum = math.min(cardData:getGotNum() - 1, need)
                -- 记录使用了哪些卡和数量
                table.insert(combo, {
                    cardId = cardData:getCardId(),
                    costNum = costNum,
                })
                need = need - costNum
            end
        end
    end

    if EnvUtil:isDevelopMode() then
        printx(48, "[CollectCard]pickBestCardCombo best_sum=",best_sum, ";combo=", tts(combo))
    end

    return best_sum, combo
end

-- 打开活动说明面板
function Manager:openExplanationPanel(animTime, closeCallback)

    local pStr = string.format("amf/activity/collectcard/texture/CollectCardExplanationPanel%s.plist", self:getUINameSuffix())
    _G.amfBean("AssetsUtil"):loadMiniFiles({
        pStr,
    }):next(function()
        local UIBuilder = require "amf.middleware.ui.export.UIBuilder"
        local IllustrationPanelVM = require "amf.middleware.ui.kit.panel.other.IllustrationPanelVM"
        local path = "amf.feature.localactivity.collectcard.view.uisource.CollectCardExplanationPanel%s_UI"
        local str = string.format(path, self:getUINameSuffix())
        local uiData = require(str)
        local builder = UIBuilder.new(uiData)
        local page1 = builder:createChild("page_1")
        local page2 = builder:createChild("page_2")

        if not EnvUtil:isMiniGame() then
            page2.mbMap.touch_layer:setTouchHandler(function()
                local url = self:getPeriodConfigByKey("SheQuUrl")
                        or "https://ff.happyelements.com/mobile/page/topic.html?tid=7315384&app=1001&ct=1562664000&gohome=1"
                FAQ:openSheQuUrl(url)
            end)
        else
            page2.mbMap.description:setString("详细概率公示，请前往官网查看")
            page2.mbMap.shape_1:setVisible(false)
        end

        local vm = IllustrationPanelVM.Builder.new()
            :setNeedLoadRes({ "amf/activity/collectcard/texture/CollectCardExplanationPanel.plist" })
            :setAnimTime(animTime or 0.2)
            :setTitle("")
            :setPages({ page1, page2 })
            :setPageAnimNodeNames({
                { "title_1", "node_1", "arrow_1", "node_2", "arrow_2", "node_3" }
            })
            :setChangePageCall(function(beforeIndex, pageIndex)
                if beforeIndex and beforeIndex ~= pageIndex then
                    self:playEffect(self:getConst().Sound.TURN_PAGE)
                    self:playHaptics(self:getConst().Haptics.BUTTON_NORMAL)
                end
            end)
            :setCloseCallback(function()
                self:playEffect(self:getConst().Sound.CLICK_COMMON_01)
                self:playHaptics(self:getConst().Haptics.BUTTON_NORMAL)
                safeRunCall(closeCallback)
            end)
            :build()
        vm:popout()

        self:callPanelFunc("managePanelVM", vm)
    end, function()
        if closeCallback then closeCallback() end
        ALog.error("RewardsExplanationPanel loadRes failed")
    end)
end

-- 打开小卡册面板
function Manager:openAlbumPanel(albumId, closeCallback)
    local albumDataList = self:getModel():getAlbumDataList()
    local AlbumPanelVM = require_debug "amf.feature.localactivity.collectcard.view.AlbumPanelVM"
    local vm = AlbumPanelVM.Builder.new()
        :setAlbumDataList(albumDataList)
        :setAlbumId(albumId)
        :setCloseCallback(closeCallback)
        :setManager(self)
        :build()
    vm:popout()
    self:callPanelFunc("managePanelVM", vm)
end

function Manager:openBattleReportPanel(roundId, percent, roundTimes, shareRewardFlag, closeCallback)
    local BattleReportPanelVM = require "amf.feature.localactivity.collectcard.view.BattleReportPanelVM"
    local vm = BattleReportPanelVM.Builder.new()
        :setRoundId(roundId)
        :setPercent(percent)
        :setRoundTimes(roundTimes)
        :setShareRewardFlag(shareRewardFlag)
        :setCloseCallback(closeCallback)
        :build()
    vm:popout()

    self:callPanelFunc("managePanelVM", vm)
end

function Manager:openFriendSelectPanel(delegate)
    delegate.manager = self
    local PanelVM = require "amf.feature.localactivity.collectcard.view.CollectCardFriendSelectPanelVM"
    local vm = PanelVM:create(delegate)
    vm:popout()
    self:callPanelFunc("managePanelVM", vm)
    return vm
end

function Manager:openFriendMessagePanel(delegate)
    delegate = delegate or {}
    local model = self:getModel()
    local currentUid = self._userManager:getUid()
    local typeCounts = {0, 0, 0, 0}
    for _, message in ipairs(model:getSwapMessages()) do
        local sent = tostring(message.creatorUid) == tostring(currentUid)
        if tonumber(message.type) == self:getConst().SwapCreateType.HELP then
            typeCounts[sent and 3 or 1] = typeCounts[sent and 3 or 1] + 1
        elseif tonumber(message.type) == self:getConst().SwapCreateType.EXCHANGE then
            typeCounts[sent and 4 or 2] = typeCounts[sent and 4 or 2] + 1
        end
    end
    local typeCountParts = {}
    for typeId, count in ipairs(typeCounts) do
        if count > 0 then table.insert(typeCountParts, string.format("%d_%d", typeId, count)) end
    end
    delegate.dcData = {
        t1 = model:getUnSeeMessageCount(),
        t2 = model:getSwapMessageCount(),
        t3 = table.concat(typeCountParts, ";"),
    }
    model:clearUnseenSwapMessageCount()
    self:updateActIcon()
    delegate.manager = self
    delegate.currentUid = currentUid
    local PanelVM = require "amf.feature.localactivity.collectcard.view.CollectCardFriendMessagePanelVM"
    local vm = PanelVM:create(delegate)
    vm:popout()
    self:callPanelFunc("managePanelVM", vm)
    return vm
end

function Manager:openExchangeSelectPanel(delegate)
    delegate = delegate or {}
    delegate.manager = self
    local PanelVM = require "amf.feature.localactivity.collectcard.view.CollectCardExchangeSelectPanelVM"
    local vm = PanelVM:create(delegate)
    vm:popout()
    self:callPanelFunc("managePanelVM", vm)
    return vm
end

function Manager:openReceiveCardPanel(receiveData, closeCallback, loadResFailCallback)
    local PanelVM = require "amf.feature.localactivity.collectcard.view.CollectCardReceiveCardPanelVM"
    local vm = PanelVM.Builder.new()
        :setManager(self)
        :setReceiveData(receiveData)
        :setCloseCallback(closeCallback)
        :setLoadResFailCallback(loadResFailCallback)
        :build()
    vm:popout()
    self:callPanelFunc("managePanelVM", vm)
    return vm
end

function Manager:openReceiveCardQueue(receiveCardList, closeCallback, shouldAddCard)
    receiveCardList = receiveCardList or {}
    local index = 1
    local seenCardIds = {}
    local hasReceiveCard = #receiveCardList > 0
    local completed = false

    local function complete()
        if completed then return end
        completed = true
        safeRunCall(closeCallback)
    end

    local function settleAfterQueue()
        if not hasReceiveCard then
            complete()
            return
        end
        _G.amfTransaction(TransactionEvent.COLLECT_CARD_FLOW, {
            flowType = _G.COLLECT_CARD_FLOW_TYPE.SETTLE,
            onComplete = complete,
            onError = complete,
        })
    end

    local function showNext()
        if not self:isActValid() then
            complete()
            return
        end
        local receiveData = receiveCardList[index]
        if not receiveData then
            settleAfterQueue()
            return
        end
        index = index + 1

        local cardId = tonumber(receiveData.cardId)
        if shouldAddCard and cardId then
            local cardData = self:getModel():getCardDataById(cardId)
            local wasNew = cardData:getGotNum() <= 0
            self:onGetCard(cardId, 1)
            self:addRewardsNormal({{
                itemId = cardData:getItemId(),
                num = 1,
            }}, {
                dcFeature = "collect_card",
                dcSource = "friend_card_receive",
            })
            local repeatStarNum
            if not wasNew then repeatStarNum = cardData:getStarLevel() end
            self:dcActPlug():dcCardReceiveReward(
                string.format(
                    "%s_%s_%s",
                    cardData:getCardId(),
                    cardData:getStarLevel(),
                    cardData:getAlbumId()
                ),
                receiveData.profile.xxlId,
                receiveData.type == self:getConst().SwapCreateType.EXCHANGE and 2 or 1,
                wasNew and 1 or 2,
                repeatStarNum
            )
        end
        local cardKey = tostring(cardId)
        local displayData = {
            type = receiveData.type,
            cardId = cardId,
            profile = receiveData.profile,
            isNew = cardId ~= nil and self:isNewCard(cardId) and not seenCardIds[cardKey],
        }
        seenCardIds[cardKey] = true

        local advanced = false
        local function advance()
            if advanced then return end
            advanced = true
            showNext()
        end
        self:openReceiveCardPanel(displayData, advance, advance)
    end

    showNext()
end

function Manager:openFriendMessageFlow(delegate)
    if not self._networkStatusManager:isNetworkEnabled() then
        CommonTip:showTip("网络异常，请检查网络~")
        return
    end
    if self._isOpeningFriendMessageFlow then return end
    self._isOpeningFriendMessageFlow = true
    return self:requestSwapMessageList():next(function(response)
        local data = response:getData() or {}
        local refundCardList = data.refundCardList or {}
        local receiveCardList = data.receiveCardList or {}
        if not self:isActValid() then
            self._isOpeningFriendMessageFlow = false
            return response
        end
        for _, refundCardId in ipairs(refundCardList) do
            local cardId = tonumber(refundCardId)
            if cardId then self:onGetCard(cardId, 1) end
        end
        self:openReceiveCardQueue(receiveCardList, function()
            self._isOpeningFriendMessageFlow = false
            if self:isActValid() then self:openFriendMessagePanel(delegate) end
        end, true)
        return response
    end, function(error)
        self._isOpeningFriendMessageFlow = false
        return deferred.error(error)
    end)
end

function Manager:openTransferConfirmPanel(delegate)
    delegate.manager = self
    local PanelVM = require "amf.feature.localactivity.collectcard.view.CollectCardTransferConfirmPanelVM"
    local vm = PanelVM:create(delegate)
    vm:popout()
    self:callPanelFunc("managePanelVM", vm)
    return vm
end

function Manager:openTransferResultPanel(title, description)
    local ThreeTipsPanelVM = require "amf.middleware.ui.kit.commonpanel.view.ThreeTipsPanelVM"
    local vm
    vm = ThreeTipsPanelVM.Builder.new()
        :setTitle(title)
        :setRichText(description)
        :setClickBtn({
            string = "确定",
            colorMode = _G.UEButton_ColorMode.Green,
            touchHandler = function()
                vm:close()
            end,
        })
        :build()
    vm:popout()
    self:callPanelFunc("managePanelVM", vm)
    return vm
end

function Manager:getAllFriendInfo()
    return self._friendManager:getAllFriendInfo()
end

function Manager:getThemeConfig(albumId)
    local themeConfig = self:getThemeConfigAll()
    return themeConfig[albumId]
end

function Manager:isNewCard(cardId)
    local cardData = self:getCardDataById(cardId)
    return cardData and cardData.gotNum > 0 and not self:getCardViewed(cardId)
end

function Manager:playEffect(type, loop)
    local file = self:getConst().SoundPath[type]
    self[type .. "_effect"] = GamePlayMusicPlayer.getInstance():playEffect(file, nil, loop)
end

function Manager:stopEffect(type)
    local file = self:getConst().SoundPath[type]
    if self[type .. "_effect"] then
        GamePlayMusicPlayer.getInstance():stopEffect(self[type .. "_effect"], file)
    end
end

function Manager:playHaptics(haptics)
    HapticsManager:playInActScene(haptics)
end

--region gk

function Manager:isMainPanelGuide()
    local gId = self:getConst().Guide.ID_1
    local ret = self:hasGuideIndex(gId)
    if ret then
        return ret ~= gId
    end
    return true
end

function Manager:setMainPanelGuideOver()
    self:addGuideIndex(self:getConst().Guide.ID_1)
end

---根据缓存判断是否新的一轮
function Manager:isCanOpenPreheatPanel(autoSet)
    local periodId = self:getModel():getPeriodId()
    local roundId = self:getModel():getRoundId()
    local curRoundStr = string.format("preheat_%s_%s", tostring(periodId), tostring(roundId))
    local lastRoundId = self:getDataByKey("lastRoundId", -1)
    local ret = lastRoundId ~= curRoundStr
    if ret and autoSet then
        self:setDataByKey("lastRoundId", curRoundStr)
    end
    return ret
end

---星星数量 包含上轮历史的
function Manager:getStarNum()
    local starNum = self:getModel():getStarNum() or 0
    return starNum
end

function Manager:getStarNumStr()
    local starNum = self:getStarNum()
    if starNum >= 100000 then return "99999+" end
    return tostring(starNum)
end

function Manager:getHistoryRoundStarNum()
    return self:getModel():getHistoryRoundStarNum()
end

function Manager:addStarNumAndHistoryNum(addStarNum, addHistoryNum)
    if addStarNum ~= 0 then
        local starNum = self:getStarNum() + addStarNum
        if starNum < 0 then starNum = 0 end
        self:setDataByKey("starNum", starNum)
    end

    if addHistoryNum ~= 0 then
        local historyStarNum = self:getHistoryRoundStarNum() + addHistoryNum
        if historyStarNum < 0 then historyStarNum = 0 end
        self:setDataByKey("historyRoundStarNum", historyStarNum)
    end
    --evert?

end

---星星兑换是否显示红点, 获得卡后更新，可监听 CollectCardEvent.ON_STARNUM_REDPOINT
function Manager:isStarExchangeRedPoint()
    local lastRp = self:getFlagFromLocalByKey("starExchangeRP", false)
    return lastRp
end

function Manager:_setStarExchangeRedPoint(show)
    local lastRp = self:isStarExchangeRedPoint()
    if lastRp == show then return end
    self:setFlagToLocalByKey("starExchangeRP", false, show)
    CollectCardEventCenter:dispatch(CollectCardEvent.ON_STARNUM_REDPOINT)
end

function Manager:updateStarExchangeRedPoint()
    local lastRp = self:isStarExchangeRedPoint()
    if lastRp == true then return end
    if lastRp == nil then
        self:_setStarExchangeRedPoint(true)
    else
        local starNum = self:getStarNum()

        local boxCfgList = self:getConfigByKey("starBoxConfigList")
        local needShow = false
        if starNum > 0 and boxCfgList then
            for index, value in ipairs(boxCfgList) do
                local needNum = tonumber(value.needStarNum)
                if starNum >= needNum then
                    needShow = true
                    break
                end
            end
        end
        self:_setStarExchangeRedPoint(needShow)
    end
end

function Manager:openMainHelpPanel()
    -- CommonTip:showTip("main 说明")
    self:openExplanationPanel()
    -- self:openJuebanPanel()
end

function Manager:openCardAllRewardsPanel(firstOpen, closeCallback)
    local roundId
    local middleString
    local endTime
    local rewards
    roundId = self:getModel():getRoundId()
    middleString = firstOpen and "参与全新集卡活动可获得丰富奖励~" or "本轮卡册一共可获得以下全部奖励\n快来集卡吧~"
    endTime = self:getModel():getMainEndTime()
    local rewards = table.clone(self:getDataByKey("preHeatShowRewards", {}))
    self:openJiKaLocalRewardsPanel({
        roundId = roundId,
        rewards = rewards,
        middleString = middleString,
        endTime = endTime,
        callback = closeCallback,
        isFromMainTime = true,
        isRoundFirstOpen = firstOpen,
    })
    self:dc("collect_card", firstOpen and "start_show" or "award_show")
end

---星星兑换商店
function Manager:openStarExchangePanel()
    self:_setStarExchangeRedPoint(false)
    local PanelVM = require "amf.feature.localactivity.collectcard.view.StartExchangePanelVM"
    local vm = PanelVM:create()
    vm:popout()
    self:callPanelFunc("managePanelVM", vm)
end

function Manager:openStarExchangeHelpPanel()
    local PanelVM = require "amf.feature.localactivity.collectcard.view.StarExchangeHelpPanelVM"
    local vm = PanelVM:create()
    vm:popout()
    self:callPanelFunc("managePanelVM", vm)
end

function Manager:openStarExchangeSelectCardPanel(boxConfig)
    local PanelVM = require "amf.feature.localactivity.collectcard.view.StarExchangeSelectCardPanelVM"
    local vm = PanelVM:create({manager = self, boxConfig = boxConfig})
    vm:popout()
    self:callPanelFunc("managePanelVM", vm)
    return vm
end

function Manager:requestStarExchange(dataSource)
    if not _G.amfBean("NetworkStatusManager"):isNetworkEnabled() then
        CommonTip:showTip("网络异常，请检查网络~")
        return deferred.error()
    end

    self:dcActPlug():dcJoin()
    local useHistoryStarNum = self:getDataByKey("historyRoundStarNum")
    local useCardIds = {}
    local useCardMaxStarNum = 0
    if useHistoryStarNum < dataSource.needStarNum then
        useCardMaxStarNum, useCardIds = self:pickBestCardComboLegacy(dataSource.needStarNum - useHistoryStarNum)
        useCardMaxStarNum = dataSource.needStarNum - useHistoryStarNum
    else
        useHistoryStarNum = dataSource.needStarNum
    end

    local cardTmpIds = {}
    local cardTmpNums = {}
    for _, value in pairs(useCardIds) do
        table.insert(cardTmpIds, value.cardId)
        table.insert(cardTmpNums, value.costNum)
    end
    if EnvUtil:isDevelopMode() then
        printx(48, "使用的卡=", tts(cardTmpIds), tts(cardTmpNums), ";useHistoryStarNum=", useHistoryStarNum)
    end

    local params = {
        boxId = dataSource.boxId,
        useCardIds = cardTmpIds,
        useCardNums = cardTmpNums,
        useHistoryStarNum = useHistoryStarNum,
    }
    local costStarNum = useHistoryStarNum + useCardMaxStarNum
    local panelId = UICreateUtil:getPanelId("StartExchangePanelVM")
    self:dcActPlug():dcExchangeShopPanelReward(costStarNum, panelId)

    return self:getModel():requestStarExchange(params)
        :next(function(response)
            local data = response:getData()
            local function onReqExchangeSucc(rewards)
                for _, value in pairs(useCardIds) do
                    local cardData = self:getCardDataById(value.cardId)
                    if cardData then
                        local num = cardData:getGotNum() - value.costNum
                        if num < 1 then num = 1 end
                        cardData:setGotNum(num)
                    end
                end
                self:addStarNumAndHistoryNum(-(useCardMaxStarNum + useHistoryStarNum), -useHistoryStarNum)
                self:addRewardsNormal(rewards, {dcFeature = "collect_card", dcSource = "exchange_reward"})
                self:dcActPlug():dcGainCardPack(3, rewards)

                local boxStr = "5"
                local boxSkin
                if dataSource.boxId == 1 then
                    boxStr = "123"
                    boxSkin = "b"
                elseif dataSource.boxId == 2 then
                    boxStr = "4"
                end
                local boxAnim = UICreateUtil:createSpineManuallyRelease("amf/uikit/spine/boxAnim/xinbaoxiang" .. boxStr .. "ji.skel")
                if boxSkin then boxAnim:changeSkin(boxSkin) end
                boxAnim:setScale(0.7)
                boxAnim.playAnim = function(animName, done) boxAnim:playOnce(animName, done) end
                boxAnim.playShowAnim = function(done)
                    boxAnim.playAnim("in", function()
                        if boxAnim.isDisposed then return end
                        boxAnim.playAnim("kaixiang", done)
                    end)
                end
                boxAnim.playDisappearAnim = function(done) boxAnim.playAnim("xiaoshi", done) end
                boxAnim.playIdleAnim = function(done) boxAnim:playByName("idle", true) end

                local ShowRewardsPanelCVM = require "amf.middleware.ui.kit.panel.reward.ShowRewardsPanelCVM"
                local vm = ShowRewardsPanelCVM.Builder.new()
                    :setTitle("恭喜获得")
                    :setButtonText("收下")
                    :setRewards(rewards)
                    :setBoxAnim(boxAnim)
                    :setCloseCallback(function()
                        _G.amfTransaction(TransactionEvent.COLLECT_CARD_FLOW, {
                            flowType = _G.COLLECT_CARD_FLOW_TYPE.OPEN_AND_SETTLE,
                            onComplete = function()
                                CollectCardEventCenter:dispatch(CollectCardEvent.SETTLE_END_SWITCH_ROUND)
                            end,
                            onError = function() end,
                        })
                    end)
                    :build()
                vm:popout()
                CollectCardEventCenter:dispatch(CollectCardEvent.CARD_NUM_UPDATE)
            end
            onReqExchangeSucc(data.rewards)
            return deferred.success(response)
        end, function(response)
            CommonTip:showErrorTip(response)
            return deferred.error(response)
        end)
end

function Manager:requestStarExchangeWithSelectedCards(context)
    if not _G.amfBean("NetworkStatusManager"):isNetworkEnabled() then
        CommonTip:showTip("网络异常，请检查网络~")
        return deferred.error()
    end

    self:dcActPlug():dcJoin()
    local boxId = context.boxId
    local needStarNum = context.needStarNum
    local useCardIds = context.useCardIds
    local useCardNums = context.useCardNums
    local useHistoryStarNum = context.useHistoryStarNum

    local selectedStarNum = 0
    local usedCardProps = {}
    local usedCardParts = {}
    for index, cardId in ipairs(useCardIds) do
        local cardData = self:getCardDataById(cardId)
        if cardData then
            selectedStarNum = selectedStarNum + useCardNums[index] * cardData:getStarLevel()
            table.insert(usedCardProps, {
                itemId = cardData:getItemId(),
                num = useCardNums[index],
            })
            table.insert(usedCardParts, string.format(
                "%s_%s",
                cardData:getItemId(),
                useCardNums[index]
            ))
        end
    end
    if EnvUtil:isDevelopMode() then
        printx(48, "使用的卡=", tts(useCardIds), tts(useCardNums), ";useHistoryStarNum=", useHistoryStarNum)
    end

    local params = {
        boxId = boxId,
        useCardIds = useCardIds,
        useCardNums = useCardNums,
        useHistoryStarNum = useHistoryStarNum,
    }

    return self:getModel():requestStarExchange(params)
    :next(function(response)
        local data = response:getData()
        local function onReqExchangeSucc(rewards)
            for index, cardId in ipairs(useCardIds) do
                local cardData = self:getCardDataById(cardId)
                if cardData then
                    local num = cardData:getGotNum() - useCardNums[index]
                    if num < 1 then num = 1 end
                    cardData:setGotNum(num)
                end

            end
            local overflowStarNum = math.max(
                0,
                useHistoryStarNum + selectedStarNum - needStarNum
            )
            self:addStarNumAndHistoryNum(
                -needStarNum,
                overflowStarNum - useHistoryStarNum
            )
            -- local rewards = self.dataSource.showRewards
            --check feature
            self:addRewardsNormal(rewards, {dcFeature = "collect_card", dcSource = "exchange_reward"})
            for _, prop in ipairs(usedCardProps) do
                self:dcActPlug():dcExchangeRewardCardConsume(prop.itemId, prop.num)
            end
            self:dcActPlug():dcExchangeShopPanelReward(
                needStarNum,
                table.concat(usedCardParts, ";"),
                context.autoSelectEnabled and 1 or 0,
                context.panelId
            )
            self:dcActPlug():dcGainCardPack(3, rewards)
            -- local itemRewards = {}
            -- for index, value in ipairs(rewards) do
            --     if not self:isCardPack(rewards.itemId) then
            --         table.insert(itemRewards, value)
            --     end
            -- end

            local boxStr = "5"
            local boxSkin = nil
            if boxId == 1 then
                boxStr = "123"
                boxSkin = "b"
            elseif boxId == 2 then
                boxStr = "4"
            end
            local boxAnim = UICreateUtil:createSpineManuallyRelease("amf/uikit/spine/boxAnim/xinbaoxiang" ..boxStr.. "ji.skel")
            if boxSkin then boxAnim:changeSkin(boxSkin) end
            boxAnim:setScale(0.7)
            boxAnim.playAnim = function(animName, done)
                boxAnim:playOnce(animName, done)
            end
            boxAnim.playShowAnim = function(done)
                boxAnim.playAnim('in', function()
                    if boxAnim.isDisposed then return end
                    boxAnim.playAnim('kaixiang', done)
                end)
            end
            boxAnim.playDisappearAnim = function(done)
                boxAnim.playAnim('xiaoshi', done)
            end

            boxAnim.playIdleAnim = function(done)
                boxAnim:playByName("idle", true)
            end

	        local ShowRewardsPanelCVM = require "amf.middleware.ui.kit.panel.reward.ShowRewardsPanelCVM"
            local vm = ShowRewardsPanelCVM.Builder.new()
            :setTitle("恭喜获得")
            :setButtonText("收下")
            :setRewards(rewards)
            :setBoxAnim(boxAnim)
            :setCloseCallback(function()
                -- d:resolve()
                _G.amfTransaction(TransactionEvent.COLLECT_CARD_FLOW, {
                    flowType = _G.COLLECT_CARD_FLOW_TYPE.OPEN_AND_SETTLE,
                    onComplete = function(data)
                        CollectCardEventCenter:dispatch(CollectCardEvent.SETTLE_END_SWITCH_ROUND)
                    end,
                    onError = function()
                    end,
                })

            end)
            :build()
            vm:popout()

            CollectCardEventCenter:dispatch(CollectCardEvent.CARD_NUM_UPDATE)
        end
        onReqExchangeSucc(data.rewards)
        return deferred.success(response)
    end, function(response)
        CommonTip:showErrorTip(response)
        return deferred.error(response)
    end)
end

function Manager:openJuebanPanel()
    local PanelVM = require "amf.feature.localactivity.collectcard.view.JueBanPanelVM"
    local vm = PanelVM:create()
    vm:popout()
    self:callPanelFunc("managePanelVM", vm)
end

---打开礼包 必出新卡礼包
---@param openCallback function callback(isOpened)
function Manager:openNewCardPanel(closeCallback, extra, userClick, openCallback)
    if self._isCreaingNewCardPanel or self._isNewCardPanelOpen then
        return
    end
    self._isCreaingNewCardPanel = true
    local function _openNewCardPanel()
        self:requestGiftData(function (ret)
            self._isCreaingNewCardPanel = false
            safeRunCall(openCallback, ret)
            if ret then
                if not self:getModel():isInGiftTime() then
                    self:_startPendingCollectCardFlow()
                    safeRunCall(closeCallback)
                    -- printx(48, "得到数据但不在礼包时间内")
                    return
                end

                local PanelVM = require "amf.feature.localactivity.collectcard.view.NewCardPanelVM"
                local function onClose(...)
                    self._isNewCardPanelOpen = false
                    self:getGiftModule():onPanelClose()
                    self:_startPendingCollectCardFlow()
                    safeRunCall(closeCallback, ...)
                end
                local vm = PanelVM.Builder.new()
                :setCloseCallback(onClose)
                :build()
                self._isNewCardPanelOpen = true
                vm:popout()
                self.iconModule:onGiftPanelExposed()
                self:callPanelFunc("managePanelVM", vm)
            else
                self:_startPendingCollectCardFlow()
            end
        end, userClick)
    end
    if not self._isGetedMainInfo then
        self:requestGetMainInfo(userClick)
        :next(function()
            _openNewCardPanel()
        end, function ()
            self._isCreaingNewCardPanel = false
            self:_startPendingCollectCardFlow()
            safeRunCall(openCallback, false)
        end)
    else
        _openNewCardPanel()
    end
end


function Manager:createAlbumCellUI(albumData)
    local cellUI = require "amf.feature.localactivity.collectcard.view.AlbumCellUI"
    local childUI =  cellUI:create()
    if albumData then childUI:updateSelfUI(albumData) end
    return childUI
end

---卡册颜色配置
function Manager:getAlbumCellColorCfg(albumId)
    local cfgList = self:getAlbumCellColorConfig()
    if not cfgList then return nil end
    local cfg = cfgList[albumId]
    if not cfg then
        printx(48, "not found AlbumCellColorConfig id="..albumId)
    end
    return cfg
end


--region 礼包相关

function Manager:getGiftModule()
    if not self._giftModule then
        local ModuleCls = require "amf.feature.localactivity.collectcard.model.CollectCardGiftModel"
        ---@type CollectCardGiftModel
        self._giftModule = ModuleCls.new()
    end
    return self._giftModule
end


function Manager:getGiftPackCD()
    local time = self:getDataByKey("giftEndTime") - TimeKit:timeInSec()
    return time > 0 and time or 0
end

---@param callback function callback(ret)
---@param userClick boolean
function Manager:requestGiftData(callback, userClick)
    self:getGiftModule():requestGiftData(function (ret, packages)
        printx(48, "gift data ret=", ret)
        safeRunCall(callback, ret)
    end, userClick)

end
--endregion

function Manager:playCommonEffectAndHaptic()
    --播放点击音效
    self:playEffect(self:getConst().Sound.CLICK_COMMON_01 )
    --增加震动
    self:playHaptics(self:getConst().Haptics.BUTTON_NORMAL)
end

--endregion

function Manager:cloneAlbumData(albumId)
    return self:getModel():cloneAlbumData(albumId)
end

function Manager:openJiKaLocalRewardsPanel(delegate)
    local rewards = delegate.rewards or {}
    local roundId = delegate.roundId or 1
    local endTime = delegate.endTime or 0
    local callback = delegate.callback
    local isFromMainTime = delegate.isFromMainTime or false
    local isRoundFirstOpen = delegate.isRoundFirstOpen or false
    local middleString = delegate.middleString

    --06-30新增一个预热板子
    local vm = nil
    if isRoundFirstOpen and self:getPeriodConfigByKey("PREHEAT_FIRSTSHOW_V2") then
        local JiKaLocalRewardsPanelVM = require_debug "amf.feature.localactivity.collectcard.view.JiKaLocalShortRewardsVM"
        vm = JiKaLocalRewardsPanelVM.Builder.new()
        :setRoundId(roundId)
        :setEndTime(endTime)
        :setCloseCallback(callback)
        :setMiddleString(middleString)
        :setIsRoundFirstOpen(isRoundFirstOpen)
        :build()
    else
        local JiKaLocalRewardsPanelVM = require_debug "amf.feature.localactivity.collectcard.view.JiKaLocalRewardsPanelVM"
        vm = JiKaLocalRewardsPanelVM.Builder.new()
        :setRewards(rewards)
        :setRoundId(roundId)
        :setEndTime(endTime)
        :setIsFromMainTime(isFromMainTime)
        :setCloseCallback(callback)
        :setMiddleString(middleString)
        :setIsRoundFirstOpen(isRoundFirstOpen)
        :build()
    end
    if not vm then return end
    vm:popout()
    self:callPanelFunc("managePanelVM", vm)
end

---------------------------------- CUSTOM_GAIN ----------------------------------

function Manager:_onCustomGain(event)
    local reward = event:getData()
    local Meta = self:getConst()
    local id = reward.itemId
    if id == Meta.CardPack_1_itemId
        or id == Meta.CardPack_2_itemId
        or id == Meta.CardPack_3_itemId
        or id == Meta.CardPack_4_itemId
        or id == Meta.CardPack_5_itemId then
        self:addActItem(reward)
    end
end

function Manager:createPersonalCardRecordSprNode(delegate)
    delegate = delegate or {}
    local periodId = delegate.periodId or 1
    local finishRoundNum = delegate.finishRoundNum or 0
    -- titleImagePath = "amf/activity/collectcard/materials/recordRes/res1/title.png",
    -- twoTagImagePath = "amf/activity/collectcard/materials/recordRes/res1/two.png",
    -- threeTagImagePath = "amf/activity/collectcard/materials/recordRes/res1/three.png",
    -- fourTagImagePath = "amf/activity/collectcard/materials/recordRes/res1/four.png",
    local sprite = nil
    if self:hasPeriodMeta(periodId) then
        local meta = self:getConst().getPeriodMeta(periodId)
        local personalCenterRecordRes = meta.PersonalCenterRecordRes
        sprite = Sprite:createEmpty()
        local title = UICreateUtil:createSpriteFile(personalCenterRecordRes.titleImagePath)
        sprite:addChild(title)
        sprite:setScale(0.27)
        -- local tag = nil
        -- if finishRoundNum == 2 then
        --     tag = UICreateUtil:createSpriteFile(personalCenterRecordRes.twoTagImagePath)
        -- elseif finishRoundNum == 3 then
        -- elseif finishRoundNum >= 4 then
        --     tag = UICreateUtil:createSpriteFile(personalCenterRecordRes.fourTagImagePath)
        -- end
        -- if tag then
        --     sprite:addChild(tag)
        --     tag:setPositionXY(169, 16)
        -- end
    else
        sprite = UICreateUtil:createSpriteFile("amf/activity/collectcard/materials/recordRes/collectCardIcon.png")
    end
    return sprite
end

function Manager:hasPeriodMeta(periodId)
    return self:getConst().hasPeriodMeta(periodId)
end

--region 颜色配置相关

function Manager:getPeriodConfigByKey(key)
    local periodId = self:getModel():getPeriodId()
    local meta = self:getConst().getPeriodMeta(periodId)
    if EnvUtil:isDevelopMode() and self.debug_config_id then
        meta = self:getConst().getPeriodMeta(self.debug_config_id)
    end
    if meta and meta[key] then
        return meta[key]
    end
    return nil
end

function Manager:isCollectCardSwapEnabled()
    return self:getPeriodConfigByKey("COLLECT_CARD_SWAP_ENABLED") == true
end

function Manager:getMainThemeBgPrefix()
    local cfg = self:getPeriodConfigByKey("MAIN_THEME_PREFIX")
    if cfg then return cfg end

    return "amf/activity/collectcard/materials/mainpanel/beijing"
end

function Manager:getMainPanelColorConfig()
    local cfg = self:getPeriodConfigByKey("MainPanelColorConfig")
    if cfg then return cfg end

    local ret = require "amf.feature.localactivity.collectcard.config.ZhuMianBanShangFangColorConfig"
    return ret
end

function Manager:getAlbumCellColorConfig()
    local cfg = self:getPeriodConfigByKey("AlbumCellColorConfig")
    if cfg then return cfg end

    local ret = require "amf.feature.localactivity.collectcard.config.AlbumCellColorConfig"
    return ret
end

function Manager:getThemeConfigAll()
    local cfg = self:getPeriodConfigByKey("ThemeConfig")
    if cfg then return cfg end

    local ret = require "amf.feature.localactivity.collectcard.config.ThemeConfig"
    return ret
end

function Manager:getUINameSuffix()
    local cfg = self:getPeriodConfigByKey("UI_NAME_SUFFIX")
    if cfg then return cfg end

    return ""
end

--endregion

return Manager
