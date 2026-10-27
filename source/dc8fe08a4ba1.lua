local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local MainSceneButtonEventCenter = require "amf.feature.mainscenebutton.event.MainSceneButtonEventCenter"
local LuckyDeliveryEvent = require "amf.feature.localactivity.luckydelivery.event.LuckyDeliveryEvent"
local LuckyDeliveryEventCenter = require "amf.feature.localactivity.luckydelivery.event.LuckyDeliveryEventCenter"
local LocalPush = require "amf.feature.localactivity.luckydelivery.localpush.LocalPush"
local deferred = require "amf.script.sugar.deferred"

local RES_MODULE_CONFIG = "meta/LuckyDeliveryRes.xml"

local BOX_ANIM_RES_FILES = {
    "amf/activity/luckydelivery/texture/LuckyDeliveryBoxAnim.plist",
    "amf/activity/luckydelivery/spine/hezi.skel",
    "amf/activity/luckydelivery/spine/tx.skel",
    "amf/activity/luckydelivery/spine/bj.skel",
    "amf/activity/luckydelivery/spine/reward_vfx.skel",
    "amf/activity/luckydelivery/sound/goin.mp3",
    "amf/activity/luckydelivery/sound/upgrade1.mp3",
    "amf/activity/luckydelivery/sound/upgrade2.mp3",
    "amf/activity/luckydelivery/sound/upgrade3.mp3",
    "amf/activity/luckydelivery/sound/boxdown.mp3",
    "amf/activity/luckydelivery/sound/open1.mp3",
    "amf/activity/luckydelivery/sound/open2.mp3",
    "amf/activity/luckydelivery/sound/idle.mp3",
}

local BoxAnimResType = {
    OTHER = 0,
    PLIST = 1,
    SPINE = 2,
}

local LuckyDeliveryManager = class("LuckyDeliveryManager", BaseFeatureManager)

function LuckyDeliveryManager:_init()
    self._isDownloadingRes = false
    self._isResReady = false
    self:registerEvents()
    self:initActInfo()
    if not EnvUtil:isMiniGame() then
        self:tryDownLoadRes():next(function()
            MainSceneButtonEventCenter:dispatch(MainSceneButtonEvent.UPDATE)
        end)
    end
end

function LuckyDeliveryManager:setMainSceneButtonManager(manager)
    self.mainSceneButtonManager = manager
end

function LuckyDeliveryManager:setAutoPopupMgr(manager)
    self.autoPopupMgr = manager
end

function LuckyDeliveryManager:setUserStateManager(manager)
    self.userStateManager = manager
end

function LuckyDeliveryManager:setLevelUnLockManager(manager)
    self.levelUnLockManager = manager
end

function LuckyDeliveryManager:_getConstPath()
    return "amf.feature.localactivity.luckydelivery.config.LuckyDeliveryConst"
end

function LuckyDeliveryManager:_getModelPath()
    return "amf.feature.localactivity.luckydelivery.model.LuckyDeliveryModel"
end

function LuckyDeliveryManager:_getExtraPlugsConfigList()
    return {
        {
            key = "Panel",
        },
        {
            key = "AutoPop",
        },
        {
            key = "DC",
            path = {
                plugPath = "amf.feature.localactivity.luckydelivery.dc.LuckyDeliveryDC",
            }
        },
    }
end

function LuckyDeliveryManager:dcPlug()
    return self:_getPlug("DC")
end

function LuckyDeliveryManager:isEnabled()
    return self:getModel():isDataEnabled() and self:isActValid()
end

function LuckyDeliveryManager:isActValid()
    return self:isCollectCardEnabled() and self:getModel():isInMainTime()
end

function LuckyDeliveryManager:isCollectCardEnabled()
    local collectCardManager = _G.amfBean and _G.amfBean("CollectCardManager")
    return collectCardManager and collectCardManager:isEnabled()
end

function LuckyDeliveryManager:canSupplementReward()
    return self:getModel():hasRewardableTask() or self:getModel():getDataByKey("canSupplementReward")
end

function LuckyDeliveryManager:canPopStage3BoxAnim()
    if not self:canSupplementReward() then return false end
    if self.levelUnLockManager:isInNewLevelTime() then return false end
    return true
end

function LuckyDeliveryManager:registerEvents()
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)
    _G.amfEC:registerNormal(NormalEvent.GLOBAL_WINNING_STREAK_INCREASED, self.onGlobalWinningStreakIncreased, self)
    _G.amfEC:registerNormal(NormalEvent.GLOBAL_WINNING_STREAK_BROKEN, self.onGlobalWinningStreakBroken, self)
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
    LuckyDeliveryEventCenter:register(LuckyDeliveryEvent.PLAY_EXPRESS_OPEN_RESULTS, self.onPlayExpressOpenResults, self)

    self:registerActEndTimer()
end

function LuckyDeliveryManager:registerActEndTimer()
    if self.__passActMainNextTimer then
        TimerUtil.removeAlarm(self.__passActMainNextTimer)
        self.__passActMainNextTimer = nil
    end

    local mainEndTime = self:getModel():getMainEndTime()
    if not mainEndTime or mainEndTime <= 0 then return end

    local nowTime = TimeKit:timeInSec()
    if nowTime >= mainEndTime then return end

    self.__passActMainNextTimer = TimerUtil.addAlarm(function()
        self.__passActMainNextTimer = nil
        self:onPassActMainNext()
    end, mainEndTime - nowTime, 1)
end

function LuckyDeliveryManager:initActInfo()
    if not self.actPlug then return end
    local actInfo = self.actPlug:getActInfo()
    self:getModel():syncActInfo(actInfo)
    self:tryDcQualify()
end

function LuckyDeliveryManager:onActPassDay()
    if self:getObserverNum() > 0 then
        self:notify("CloseAllPanel")
    end

    BaseFeatureManager.onActPassDay(self)
    MainSceneButtonEventCenter:dispatch(MainSceneButtonEvent.UPDATE)
end

function LuckyDeliveryManager:onPassActMainNext()
    if self:getObserverNum() > 0 then
        self:notify("CloseAllPanel")
        CommonTip:showTip('幸运快递活动已结束！')
    end

    MainSceneButtonEventCenter:dispatch(MainSceneButtonEvent.UPDATE)
end

function LuckyDeliveryManager:passDayRefreshData()
    self:getModel():setLocalCache("taskList", true, {})
end

function LuckyDeliveryManager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(self:getConst().ACT_ID)]

    if fromServer and not actInfo then
        self:getModel():reset()
    elseif fromServer and actInfo then
        self:getModel():syncActInfo(actInfo)
        self:tryDcQualify()
        if self.mainSceneButtonManager and self.mainSceneButtonManager:isButtonCreated() then
            MainSceneButtonEventCenter:dispatch(MainSceneButtonEvent.UPDATE)
        end
    end
end

function LuckyDeliveryManager:onSystemEnterBackground(event)
    if not self:isEnabled() or self:isDayCompleted() then
        LocalPush:removeLocalPush()
        return
    end

    self:tryScheduleDailyPush()
end

function LuckyDeliveryManager:onGlobalWinningStreakIncreased(event)
    if not self:isEnabled() then return end

    local finishedTaskInfo = self:getModel():addCurrentTaskProgress(1)
    if finishedTaskInfo then
        LuckyDeliveryEventCenter:dispatch(LuckyDeliveryEvent.TASK_FINISHED, finishedTaskInfo)
    end
    MainSceneButtonEventCenter:dispatch(MainSceneButtonEvent.UPDATE)
end

function LuckyDeliveryManager:onGlobalWinningStreakBroken(event)
    if not self:isEnabled() then return end

    self:getModel():clearCurrentTaskProgress()
    MainSceneButtonEventCenter:dispatch(MainSceneButtonEvent.UPDATE)
end

function LuckyDeliveryManager:getLocalCache(key, needTime)
    return self:getModel():getLocalCache(key, needTime)
end

function LuckyDeliveryManager:setLocalCache(key, needTime, value)
    self:getModel():setLocalCache(key, needTime, value)
end

function LuckyDeliveryManager:tryDcQualify()
    if not self:isEnabled() then return end

    local key = self:getConst().DCKey.QUALIFY_DAILY
    if self:getLocalCache(key, true) then return end
    self:setLocalCache(key, true, true)

    self:dcPlug():dcQualify()
end

function LuckyDeliveryManager:tryDcJoin()
    if not self:isEnabled() then return end

    local key = self:getConst().DCKey.JOIN_DAILY
    if self:getLocalCache(key, true) then return end
    self:setLocalCache(key, true, true)

    self:dcPlug():dcJoin()
end

function LuckyDeliveryManager:dcOpenBox(taskIndex, boxData, panelId)
    local finalLevel = boxData.finalLevel
    if boxData.splitNum > 1 then
        finalLevel = finalLevel .. "_" .. boxData.splitNum
    end

    local collectCardManager = _G.amfBean("CollectCardManager")
    local Const = collectCardManager:getConst()
    local cardInfoList = {}
    for _, reward in ipairs(boxData.expressRewards or {}) do
        local itemId = reward.itemId
        local cardData = itemId and collectCardManager:getCardDataByItemId(itemId)
        if cardData then
            local cardLevel = cardData.cardType == Const.CardType.GOLD and 6 or cardData.starLevel
            local cardInfo = string.format("%s_%s_%s", cardData.cardId, cardLevel, cardData.albumId)
            table.insert(cardInfoList, cardInfo)
        end
    end

    self:dcPlug():dcOpenBox(
        taskIndex,
        finalLevel,
        table.concat(cardInfoList, ";"),
        collectCardManager:getModel():getRoundId(),
        panelId
    )
end

function LuckyDeliveryManager:getTaskFinishedCount()
    local count = 0
    for _, taskInfo in ipairs(self:getModel():getTaskList()) do
        if taskInfo.finished then
            count = count + 1
        end
    end
    return count
end

function LuckyDeliveryManager:setTipExposedToday(flag, userClick)
    self:setLocalCache(self:getConst().TipKey.DAILY_EXPOSE, true, flag)
    if userClick then
        _G.amfBean("AutoPopupMgr"):increaseCheckPointPopNum(_G.PopupCheckPoint.LUCKY_DELIVERY_TIP)
    end
end

function LuckyDeliveryManager:hasTipExposedToday()
    return self:getLocalCache(self:getConst().TipKey.DAILY_EXPOSE, true)
end

function LuckyDeliveryManager:setInitAnimPlayedToday(flag)
    self:setLocalCache(self:getConst().TipKey.INIT_ANIM_PLAYED, true, flag)
end

function LuckyDeliveryManager:hasInitAnimPlayedToday()
    return self:getLocalCache(self:getConst().TipKey.INIT_ANIM_PLAYED, true)
end

function LuckyDeliveryManager:tryScheduleDailyPush()
    if EnvUtil:isMiniGame() then return end
    if self:getLocalCache(self:getConst().PushKey.DAILY_PUSH_SCHEDULED, true) then return end

    local loginTime = TimeKit:timeInSec()
    self:setLocalCache(self:getConst().PushKey.DAILY_PUSH_SCHEDULED, true, true)

    LocalPush:scheduleDay2Push(loginTime)
end

function LuckyDeliveryManager:isDayCompleted()
    return self:getModel():isAllTasksFinished()
end

function LuckyDeliveryManager:canShowOwnMainSceneExtra()
    return self:isEnabled() and (not self:isDayCompleted() or self:canSupplementReward())
end

function LuckyDeliveryManager:canShowPassMainSceneExtra()
    return self:isEnabled() and _G.amfBean("LuckyDeliveryPassManager"):canShowMainSceneEntry()
end

function LuckyDeliveryManager:canPopDailyTip()
    return self:isEnabled() and not self:isDayCompleted()
end

function LuckyDeliveryManager:_getAutoPopConfigList()
    local PCP = _G.PopupCheckPoint
    local PopStage = AutoPopupConst.PopStage

    return {
        {
            checkPoint = PCP.LUCKY_DELIVERY_TIP,
            stages     = { PopStage.STAGE_TWO, PopStage.STAGE_FOUR },
            check      = function()
                return self:isResReady() and self:canPopDailyTip()
            end,
            creator    = function(_, onPopOver)
                return function()
                    if not self:canPopDailyTip() then
                        safeRunCall(onPopOver)
                        return
                    end
                    self:showLuckyDeliveryTip(onPopOver, false)
                end
            end,
        },
        {
            checkPoint = PCP.LUCKY_DELIVERY_STAGE3,
            stages     = { PopStage.STAGE_THREE },
            check      = function()
                return self:isResReady() and self:canPopStage3BoxAnim()
            end,
            creator    = function(_, onPopOver)
                return function()
                    if not self:canPopStage3BoxAnim() then
                        safeRunCall(onPopOver)
                        return
                    end
                    self:requestAndPlayExpressOpenResults(onPopOver)
                end
            end,
        },
    }
end

function LuckyDeliveryManager:getCurrentTaskIndex()
    return self:getModel():getCurrentTaskIndex()
end

function LuckyDeliveryManager:getCurrentTask()
    return self:getModel():getCurrentTask()
end

function LuckyDeliveryManager:getBoxTier(boxInfo)
    local BoxTier = self:getConst().BoxTier
    local tierByLevel = {
        [1] = BoxTier.LEVEL_1,
        [2] = BoxTier.LEVEL_2,
        [3] = BoxTier.LEVEL_3,
    }
    return tierByLevel[tonumber(boxInfo.expressLevel)]
end

function LuckyDeliveryManager:getMainSceneButtonModuleConfig()
    local showOwnExtra = self:canShowOwnMainSceneExtra()
    local showPassExtra = self:canShowPassMainSceneExtra()
    if not showOwnExtra and not showPassExtra then return end

    if not EnvUtil:isMiniGame() and not self._isResReady then
        self:tryDownLoadRes():next(function()
            MainSceneButtonEventCenter:dispatch(MainSceneButtonEvent.UPDATE)
        end)
        return
    end

    return {
        uniqueId = "LuckyDeliveryShow",
        actId = self:getConst().ACT_ID,
        endTime = self:getModel():getMainEndTime(),
        extraModule = "amf.feature.localactivity.luckydelivery.mainsceneextra.LuckyDeliveryExtraButtonModule",
    }
end

function LuckyDeliveryManager:tryDownLoadRes(showLoading)
    if EnvUtil:isMiniGame() or self._isResReady then
        return deferred.success()
    end

    if AssetsUtil:isModuleResReady(RES_MODULE_CONFIG) then
        self._isResReady = true
        return deferred.success()
    end

    if self._resLoadingPromise then
        return self._resLoadingPromise
    end

    local d = deferred.new()
    self._resLoadingPromise = d
    self._isDownloadingRes = true

    local onLoadSuccess = function()
        self._isDownloadingRes = false
        self._isResReady = true
        self._resLoadingPromise = nil
        d:resolve()
    end

    local onLoadFail = function()
        if showLoading then
            CommonTip:showTip("活动加载失败，请重试")
        end
        self._isDownloadingRes = false
        self._resLoadingPromise = nil
        d:reject()
    end

    local onCancel = function()
        self._isDownloadingRes = false
        self._resLoadingPromise = nil
        d:reject()
    end

    AssetsUtil:loadDynamicModule(RES_MODULE_CONFIG, onLoadSuccess, onLoadFail, onCancel, showLoading)
    return d
end

function LuckyDeliveryManager:isResReady()
    return EnvUtil:isMiniGame() or self._isResReady
end

function LuckyDeliveryManager:showLuckyDeliveryTip(onHandleOver, userClick)
    local pos = self.mainSceneButtonManager and self.mainSceneButtonManager:getButtonPosition()
    if not pos then
        safeRunCall(onHandleOver)
        return
    end

    self:tryDownLoadRes(true):next(function()
        return _G.amfBean("AssetsUtil"):loadMiniFiles({
            "amf/activity/luckydelivery/texture/LuckyDeliveryTip.plist",
            "amf/activity/luckydelivery/sound/common_click.mp3",
        })
    end):next(function()
        self:setTipExposedToday(true, userClick)
        self:dcPlug():dcMainPanelShow(
            userClick and "vine_icon" or "popoup",
            self:getTaskFinishedCount()
        )

        local LuckyDeliveryTip = require_debug "amf.feature.localactivity.luckydelivery.view.LuckyDeliveryTip"
        local tip = LuckyDeliveryTip:create(self:getModel():getTaskList(), self:getCurrentTaskIndex(), self:getTaskType(), onHandleOver)

        Director:sharedDirector():getRunningSceneLua():addChild(tip, SceneLayerShowKey.POP_OUT_LAYER)
        tip:setPositionXY(pos.x - 235, pos.y + 110)
        self:callPanelFunc("managePanelVM", tip)
    end, function()
        safeRunCall(onHandleOver)
    end)
end

function LuckyDeliveryManager:onLuckyDeliveryEntryTapped(onHandleOver, userClick)
    if self:canSupplementReward() then
        self:requestAndPlayExpressOpenResults(onHandleOver)
        return
    end

    if not self:canPopDailyTip() then
        safeRunCall(onHandleOver)
        return
    end

    self:showLuckyDeliveryTip(onHandleOver, userClick)
end

function LuckyDeliveryManager:playEffect(type, loop)
    local path = self:getConst().SoundPath .. type
    self[type .. "_effect"] = GamePlayMusicPlayer.getInstance():playEffect(path, nil, loop)
end

function LuckyDeliveryManager:playHaptics(haptics)
    HapticsManager:playInActScene(haptics)
end

function LuckyDeliveryManager:requestAndPlayExpressOpenResults(onHandleOver)
    self:getModel():requestLuckyExpressReward():next(function(response)
        local data = response:getData() or {}
        self:playExpressOpenResults(data.expressOpenResults, function()
            MainSceneButtonEventCenter:dispatch(MainSceneButtonEvent.UPDATE)
            safeRunCall(onHandleOver)
        end, {
            linkageActId = self:getConst().ACT_ID,
        })
    end, function()
        safeRunCall(onHandleOver)
    end)
end

function LuckyDeliveryManager:_loadBoxAnimResources(onSuccess, onFail)
    self:tryDownLoadRes(true):next(function()
        return _G.amfBean("AssetsUtil"):loadMiniFiles(BOX_ANIM_RES_FILES)
    end):next(onSuccess, onFail)
end

function LuckyDeliveryManager:_autoRetainBoxAnimResOnce(files)
    if not files then return end
    if not self._boxAnimAutoReferenceMap then
        self._boxAnimAutoReferenceMap = {}
    end
    for _, file in ipairs(files) do
        if not self._boxAnimAutoReferenceMap[file] then
            if file:ends(".plist") then
                UICreateUtil:loadPlist(file)
                self._boxAnimAutoReferenceMap[file] = BoxAnimResType.PLIST
            elseif file:ends(".skel") then
                UICreateUtil:loadSpineRes(file)
                self._boxAnimAutoReferenceMap[file] = BoxAnimResType.SPINE
            else
                self._boxAnimAutoReferenceMap[file] = BoxAnimResType.OTHER
            end
        end
    end
end

function LuckyDeliveryManager:_releaseBoxAnimAutoRes()
    if not self._boxAnimAutoReferenceMap then return end
    for file, resType in pairs(self._boxAnimAutoReferenceMap) do
        if resType == BoxAnimResType.PLIST then
            UICreateUtil:unloadPlist(file)
        elseif resType == BoxAnimResType.SPINE then
            UICreateUtil:unloadSpineRes(file, true)
        elseif resType == BoxAnimResType.OTHER then
            _G.amfBean("AssetsUtil"):unloadRes({ file }, nil)
        end
    end
    self._boxAnimAutoReferenceMap = nil
end

function LuckyDeliveryManager:_showExpressBoxAnimView(boxData, onOpenBoxAnimDone)
    local LuckyDeliveryBoxAnimView = require_debug "amf.feature.localactivity.luckydelivery.view.LuckyDeliveryBoxAnimView"

    local animView
    animView = LuckyDeliveryBoxAnimView:create(boxData, function()
        if animView then
            animView:dispose()
            animView = nil
        end
        safeRunCall(onOpenBoxAnimDone)
    end, self)
end

function LuckyDeliveryManager:playExpressOpenResults(expressOpenResults, onComplete, rewardContext)
    if table.isEmpty(expressOpenResults or {}) then
        safeRunCall(onComplete)
        return
    end

    local boxDataList = {}
    for _, openResult in ipairs(expressOpenResults) do
        table.insert(boxDataList, {
            taskId = openResult.taskId,
            initLevel = openResult.initLevel or 1,
            finalLevel = openResult.finalLevel or 1,
            splitNum = openResult.splitNum or 1,
            vip = openResult.vip or false,
            openBoxLevelList = openResult.openBoxLevelList or {},
            expressRewards = openResult.expressRewards or {},
            operationLinkRewardResults = openResult.operationLinkRewardResults or {},
        })
    end

    local boxAnimResLoaded = false
    local finished = false
    local function finish()
        if finished then return end
        finished = true
        if boxAnimResLoaded then
            self:_releaseBoxAnimAutoRes()
        end
        safeRunCall(onComplete)
    end

    self:_loadBoxAnimResources(function()
        boxAnimResLoaded = true
        self:_autoRetainBoxAnimResOnce(BOX_ANIM_RES_FILES)
        self:_playExpressOpenResultsQueue(boxDataList, finish, rewardContext)
    end, function()
        finish()
    end)
end

function LuckyDeliveryManager:_playExpressOpenResultsQueue(boxDataList, onComplete, rewardContext)
    local index = 1

    local function playNext()
        local boxData = boxDataList[index]
        if not boxData then
            safeRunCall(onComplete)
            return
        end

        index = index + 1
        local extraRewards = self:_buildExtraRewards(boxData.operationLinkRewardResults)
        local rewardPanel = self:_createExpressOpenRewardsPanel(boxData, extraRewards, playNext)
        local payType = boxData.vip and DcPayType.kRmb or DcPayType.kFree
        self:_showExpressBoxAnimView(boxData, function()
            self:_applyExpressOpenRewards(
                boxData.expressRewards,
                extraRewards,
                boxData.operationLinkRewardResults,
                rewardContext,
                payType
            )

            rewardPanel:popout()
        end)
    end

    playNext()
end

function LuckyDeliveryManager:_createExpressOpenRewardsPanel(boxData, extraRewards, onHandleOver)
    local LuckyDeliveryCardRewardPanelVM = require "amf.feature.localactivity.luckydelivery.view.LuckyDeliveryCardRewardPanelVM"
    return LuckyDeliveryCardRewardPanelVM.Builder.new()
        :setCardRewards(boxData.expressRewards)
        :setExtraReward(extraRewards and extraRewards[1])
        :setCloseCallback(function()
            _G.amfTransaction(TransactionEvent.COLLECT_CARD_FLOW, {
                flowType = _G.COLLECT_CARD_FLOW_TYPE.SETTLE,
                onComplete = onHandleOver,
                onError = onHandleOver,
                notOpenMainPanel = true,
            })
        end)
        :build()
end

function LuckyDeliveryManager:onPlayExpressOpenResults(event)
    local data = event:getData() or {}
    self:playExpressOpenResults(data.expressOpenResults, data.onComplete, data.rewardContext)
end

function LuckyDeliveryManager:_buildExtraRewards(operationLinkRewards)
    local rewardMap = {}
    local extraRewards = {}

    for _, result in ipairs(operationLinkRewards or {}) do
        for _, rewardInfo in ipairs(result.rewardItems or {}) do
            local rewardItem = rewardInfo.rewardItem
            if rewardItem then
                local key = tostring(rewardItem.itemId)
                local extraReward = rewardMap[key]
                if extraReward then
                    extraReward.num = extraReward.num + rewardItem.num
                else
                    extraReward = table.clone(rewardItem)
                    rewardMap[key] = extraReward
                    table.insert(extraRewards, extraReward)
                end
            end
        end
    end

    if table.isEmpty(extraRewards) then return end
    return extraRewards
end

function LuckyDeliveryManager:_applyExpressOpenRewards(cardRewards, extraRewards, operationLinkRewardResults, context, payType)
    context = context or {}
    local cardRewardDc = context.cardRewardDc or {}
    local extraRewardDc = context.extraRewardDc or {}
    local cardRewardFeature = cardRewardDc.feature or "lucky_express"
    local extraRewardFeature = extraRewardDc.feature or "lucky_express"
    local cardRewardSource = cardRewardDc.source or "open_box"
    local extraRewardSource = extraRewardDc.source or "stage3_open_box"
    local extraMap = { pay_type = payType }
    local linkageActId = context.linkageActId

    local collectCardManager = _G.amfBean("CollectCardManager")
    for _, reward in ipairs(cardRewards or {}) do
        local cardId = reward.cardId or collectCardManager:getCardIdByItemId(reward.itemId)
        collectCardManager:onGetCard(cardId, reward.num)
        _G.DcDataCommon:create()
            :setFeature(cardRewardFeature)
            :setSource(cardRewardSource)
            :setGainProp({ itemId = reward.itemId, num = reward.num })
            :setExtraMap(extraMap)
            :execute()
    end

    if not table.isEmpty(extraRewards) then
        -- 通过 reward 字段透传本次来源，避免改动 GainPropData 公共参数链路。
        for _, reward in ipairs(extraRewards) do
            reward._fromLuckyExpress = true
        end
        for _, result in ipairs(operationLinkRewardResults or {}) do
            for _, rewardInfo in ipairs(result.rewardItems or {}) do
                self:dcPlug():dcLinkageCollection(rewardInfo, linkageActId)
            end
        end
        _G.GainPropData:create()
            :setFeature(extraRewardFeature)
            :setSource(extraRewardSource)
            :setProps(extraRewards)
            :setExtraMap(extraMap)
            :execute()
    end
end

function LuckyDeliveryManager:getTaskType()
    local TaskType = self:getConst().TaskType
    if self.userStateManager and self.userStateManager:isFMJ() then
        return TaskType.PASS_LEVEL
    elseif self.userStateManager and not self.userStateManager:isColorfulStarFull() then
        return TaskType.FILL_STAR
    else
        return TaskType.RANDOM_CHALLENGE
    end
end

-- 本次打关是否需要开启活动(主要是用来判断+5步是否可以展示主题)
-- TODO 条件：1.当前存在未完成的幸运快递阶段任务 2.当前玩家打的这关可累计任务 3.当前阶段连胜进度 ≥ 1
function LuckyDeliveryManager:isEnableInLevel(runtime)
    if not self:isEnabled() then return false end
    if not _G.amfBean("WinningStreakManager"):isGlobalLevelSupport(runtime) then return false end

    local currentTask = self:getModel():getCurrentTask()
    if not currentTask then return false end
    if currentTask.progress < 1 then return false end

    return true
end

function LuckyDeliveryManager:getInLevelActData(runtime)
    local currentTask = self:getModel():getCurrentTask()
    if not currentTask then return end
    return {
        -- 当前阶段连胜总进度
        curTaskTotalProgress = currentTask.needStreakWin,
        -- 当前阶段连胜进度
        curWinProgress = currentTask.progress,
        -- 当前阶段连胜奖励Id，用来显示不同的快递箱子，目前只有1, 2, 3种等级
        rewardId = currentTask.expressLevel,
    }
end

return LuckyDeliveryManager
