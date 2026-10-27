local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"

local Manager = class("ExploreMapGameManager", BaseFeatureManager)

local function _toSec(ts)
    return math.floor((tonumber(ts) or 0) / 1000)
end

function Manager:_getConstPath()
    return "amf.feature.localactivity.exploremapgame.const.ExploreMapGameConst"
end

function Manager:_getModelPath()
    return "amf.feature.localactivity.exploremapgame.model.ExploreMapGameModel"
end

function Manager:_init()
    self:initGiftModule()
    self:registerEvent()
end

function Manager:setAutoPopupMgr(manager)
    self.autoPopupMgr = manager
    self:_registerAutoPopup()
end

function Manager:initGiftModule()
    local GiftModule = require "amf.feature.localactivity.exploremapgame.module.ExploreMapGameGiftModule"
    self.giftPart = GiftModule.new(self)
end

function Manager:_getExtraPlugsConfigList()
    return {
        {
            key = "Panel",
        },
        {
            key = "Download",
        },
        {
            key = "DC",
            path = {
                plugPath = "amf.feature.localactivity.exploremapgame.dc.ExploreMapGameDc",
            },
        },
        {
            key = "Rewards",
        },
        {
            key = "ActSend",
            path = {
                plugPath = "amf.feature.localactivity.exploremapgame.plug.ExploreMapGameSendPlug",
                const = self:_getConstPath(),
            },
        },
        {
            key = "ActSent",
            path = {
                plugPath = "amf.feature.localactivity.exploremapgame.plug.ExploreMapGameSentPlug",
                const = self:_getConstPath(),
            },
        },
        {
            key = "ActExchangeReceiver",
            path = {
                plugPath = "amf.feature.localactivity.exploremapgame.plug.ActExchangeReceiver",
                const = self:_getConstPath(),
            },
        },
    }
end

function Manager:dcPlug()
    return self:_getPlug("DC")
end

function Manager:getDC()
    return self:dcPlug()
end

function Manager:registerEvent()
    _G.amfEC:registerNormal(NormalEvent.PASS_DAY, self.onActPassDay, self)
    self:callActFunc("registerActInfoUpdate", "onActInfoUpdate")
    -- propfeature 配表驱动发货入口：items_runtime_config.lua 中 customGain=true 的本活动道具会派发 CUSTOM_GAIN。
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
    -- propfeature 动态 icon 入口：58116/58119 的素材由 Manager 返回，避免在 items_runtime_config.lua 写死资源路径。
    PropEventCenter:register(PropEvent.RESOLVE_ICON, self._onResolveIcon, self)
end

function Manager:onActInfoUpdate(evt)
    local data = evt:getData()
    local fromServer = data.fromServer
    if not fromServer then return end
    local actInfos = data.actInfos or {}
    local actInfo = actInfos[tostring(self:getConst().actId)]
    if not actInfo then
        self:clearData()
        return
    end

    self:registerGiftModule()

    local extra = self:callActFunc("getActInfoExtraData")

    if extra then
        local beginTime = extra.beginTime
        local mainEndTime = extra.mainEndTime
        local endTime = extra.endTime
        local time = {
            beginTime     = beginTime,
            mainBeginTime = beginTime,
            mainEndTime   = mainEndTime,
            endTime       = endTime,
        }
        local model = self:getModel()
        local timeChanged = _toSec(beginTime) ~= model:getBeginTime()
            or _toSec(mainEndTime) ~= model:getMainEndTime()
            or _toSec(endTime) ~= model:getEndTime()
        if timeChanged then
            model:clearData()
            model:updateTimeInfo(time)
        end
    end

    if (self:isInMainTime() or self:isInRewardTime()) and not self:isResEnabled() then
        self:callDownloadFunc("startDownload")
    end
end

function Manager:registerGiftModule()
    if not self.giftRegisted and self.giftPart then
        local GiftEventCenter = require "amf.feature.giftpackage.event.GiftEventCenter"
        GiftEventCenter:registerCustomModule(self.giftPart, GiftPackageConst.StageType.ACTIVITY)
        self.giftRegisted = true
    end
end

function Manager:clearData()
    self:getModel():clearData()
end

function Manager:onActPassDay()
    if not self:isEnabled() then return end
    self:notify(self:getBaseEvent().kCloseAllPanel)
end

function Manager:isEnabled()
    local dataEnable = self:getModel():isDataEnabled()
    local timeEnable = self:isInMainTime() or self:isInRewardTime()
    return dataEnable and timeEnable
end

function Manager:isEnabled2()
    local dataEnable = self:getModel():isDataEnabled()
    local timeEnable = self:isInMainTime()
    return dataEnable and timeEnable
end

function Manager:isResEnabled()
    return self:callDownloadFunc("checkDownloadSuccess")
end

function Manager:getActInfo()
    return _G.amfBean("ActivityMgr"):getActInfo(self:getConst().actId)
end

-- 前端本地配置版本：产品维护在包内常量 ExploreMapGameConst.configVersion，与后端配置同值。
-- mainInfo 请求上报该值；与后端 actInfo 下发的 configVersion 不一致时，活动侧 isSupport() 判定不展示 icon。
function Manager:getLocalConfigVersion()
    return tonumber(self:getConst().configVersion) or 0
end

function Manager:isEnabledInLevel(data)
    return self:getModel():isDataEnabled() and self:getModel():isInMainTime() and not self:isGraduated()
end

-- 奖励堆仅在活动内提示，不计入大藤蔓“奖”字。
function Manager:hasReward()
    if not self:isEnabled() then return false end
    if self:isInRewardTime() then
        return self:hasClaimableRewardInEndPeriod()
    end
    return self:hasClaimableRewardInMainTime()
end

function Manager:getMsgNum()
    if not self:isEnabled() then return 0 end
    if self:isGraduated() then return 0 end
    return self:getEnergy()
end

function Manager:hasClaimableRewardInMainTime()
    return self:hasClaimableExploreTaskReward()
        or self:hasUnclaimedAllExploreTaskReward()
        or self:hasClaimableBattlePassReward()
        or self:hasClaimablePineappleReward(true)
end

function Manager:hasClaimableRewardInEndPeriod()
    return self:hasEndExchangeReward()
        or self:hasClaimableExploreTaskReward()
        or self:hasUnclaimedAllExploreTaskReward()
        or self:hasClaimableBattlePassReward()
        or self:hasClaimablePineappleReward(false)
end

function Manager:hasClaimableExploreTaskReward()
    local cfg = self:getLocalConfig()
    for _, meta in ipairs(cfg.exploreTaskMetas or {}) do
        if self:isTaskFinished(meta.id) and not self:isTaskClaimed(meta.id) then
            return true
        end
    end
    return false
end

function Manager:hasUnclaimedAllExploreTaskReward()
    if self:isAllExploreTaskRewardClaimed() then return false end

    local cfg = self:getLocalConfig()
    local metas = cfg.exploreTaskMetas or {}
    if #metas == 0 then return false end

    for _, meta in ipairs(metas) do
        if not self:isTaskClaimed(meta.id) then
            return false
        end
    end
    return true
end

function Manager:hasClaimableBattlePassReward()
    local cfg = self:getLocalConfig()
    local bp = self:getBattlePass()
    local value = self:getBattlePassValue()
    local hasVip = self:hasBattlePassVip()

    for _, meta in ipairs(cfg.battlePassMetas or {}) do
        if value >= meta.need then
            if not table.exist(bp.freeAlreadyGotIds, meta.id) then return true end
            if hasVip and not table.exist(bp.vipAlreadyGotIds, meta.id) then return true end
        end
    end
    return false
end

function Manager:hasClaimablePineappleReward(onlyOpenPeriod)
    local cfg = self:getLocalConfig()
    local progress = self:getBagItemNum(self:getConst().ItemId.PINEAPPLE)
    local nowMs = TimeKit:timeInMillis()

    for _, period in ipairs(cfg.pineappleStationPeriodMetas or {}) do
        if self:getPineappleStationState(period.periodId) == 1
            and ((not onlyOpenPeriod) or (nowMs >= period.beginTime and nowMs <= period.endTime)) then
            for _, node in ipairs(period.nodeMetas) do
                if progress >= node.needPineapple and not self:isPineappleClaimed(period.periodId, node.id) then
                    return true
                end
            end
        end
    end
    return false
end

function Manager:hasUsableRingToss()
    return self:isInMainTime() and self:getBagItemNum(self:getConst().ItemId.RING) > 0
end

function Manager:hasClaimableEndlessPowerReward()
    local cfg = self:getLocalConfig().endlessPowerConfig
    local nowMs = TimeKit:timeInMillis()
    if nowMs < cfg.beginTime or nowMs > cfg.endTime then
        return false
    end

    local endlessPower = self:getEndlessPower()
    local rewardIndex = endlessPower.rewardIndex
    local unlockRound = endlessPower.unlockRound
    return self:isInMainTime()
        and not self:isEndlessPowerNextNodePaid()
        and rewardIndex < unlockRound * 3 + 1
end

function Manager:hasEndExchangeReward()
    return self:isInRewardTime()
        and not self:isEndRewardClaimed()
        and self:getEnergy() > 0
end

function Manager:getCurAvailableBuffAndEndTime(data)
    local Const = self:getConst()
    local now = TimeKit:timeInSec()
    local buffRate = 0
    local buffEndTime = 0

    local score20EndTime = tonumber(self:getBuffExpireTsInSec(Const.BuffType.SCORE_20)) or 0
    if score20EndTime > now then
        buffRate = buffRate + 0.20
        buffEndTime = score20EndTime
    end

    local score50EndTime = tonumber(self:getBuffExpireTsInSec(Const.BuffType.SCORE_50)) or 0
    if score50EndTime > now then
        buffRate = buffRate + 0.50
        buffEndTime = buffEndTime > 0 and math.min(buffEndTime, score50EndTime) or score50EndTime
    end

    return buffRate, buffEndTime
end

function Manager:getTimeLimitRateEndTime()
    return tonumber(self:getBuffExpireTsInSec(self:getConst().BuffType.DOUBLE)) or 0
end

function Manager:getInLevelActData(levelId, data)
    local inLevelActData = {}
    local buffEndTime = self:getTimeLimitRateEndTime()
    inLevelActData.hasTimeLimiteBuff = buffEndTime > TimeKit:timeInSec()
    inLevelActData.buffEndTime = buffEndTime
    return inLevelActData
end

function Manager:isInMainTime()
    return self:getModel():isInMainTime()
end

function Manager:isInRewardTime()
    return self:getModel():isInRewardTime()
end

function Manager:getBeginTime()
    return self:getModel():getBeginTime()
end

function Manager:getMainBeginTime()
    return self:getModel():getMainBeginTime()
end

function Manager:getMainEndTime()
    return self:getModel():getMainEndTime()
end

function Manager:getEndTime()
    return self:getModel():getEndTime()
end

function Manager:openActivity(closeCallback, extra, userClick, duanMianData)
    ActivityEventCenter:dispatch(ActivityEvent.OPEN_ACTIVITY, {
        actId = self:getConst().actId,
        failCallback = closeCallback,
        endCallback = closeCallback,
        userClick = userClick,
        extra = extra,
        duanMianData = duanMianData,
    })
end

function Manager:_registerAutoPopup()
    if not self.autoPopupMgr then return end

    local popupCheckPoint = PopupCheckPoint.EXPLORE_MAP_GAME_DAILY_POP
    self.autoPopupMgr:registerPopup({
        checkPoint = popupCheckPoint,
        stages = { AutoPopupConst.PopStage.STAGE_FOUR },
        check = function()
            return self:isEnabled() and (not self:isGraduated())
        end,
        creator = function(_, onPopOver)
            return function()
                self:openActivity(onPopOver, { from = "popoup" }, false)
            end
        end,
    })

    self.autoPopupMgr:registerPopup({
        checkPoint = PopupCheckPoint.EXPLORE_MAP_GAME_YINLIU_STAGE4_POP,
        stages = { AutoPopupConst.PopStage.STAGE_FOUR },
        check = function()
            return self:checkCanPopYinliuStage4()
        end,
        creator = function(_, onPopOver)
            return function()
                self:showYinliuStage4(onPopOver)
            end
        end,
    })

    self.autoPopupMgr:registerPopup({
        checkPoint = PopupCheckPoint.EXPLORE_MAP_GAME_DAILY_GIFT_POP,
        stages = { AutoPopupConst.PopStage.STAGE_FOUR },
        check = function()
            return self:checkPopState4Gift()
        end,
        creator = function(_, onPopOver)
            return function()
                self:popStage4Gift(onPopOver)
            end
        end,
    })
end

function Manager:addYinliuCollectionNum(num)
    num = tonumber(num) or 0
    if num <= 0 then return end

    local model = self:getModel()
    model:saveFlagToLocalByKeyInt("yinliuTotalCollection", true, model:getYinliuTotalCollection() + num, true)
    model:saveFlagToLocalByKeyInt("yinliuIntervalCollection", true, model:getYinliuIntervalCollection() + num, true)
end

function Manager:updatePassLevelData(data, collectionCount, collectionMap, passLevelData)
    local collectionId = self:getConst().mainLevelCollectionId
    local num = collectionMap and (collectionMap[tostring(collectionId)] or collectionMap[collectionId]) or 0
    self:addEnergy(num)
    self:addYinliuCollectionNum(num)
    if num > 0 then
        self:addPassLevelTimeTody()
    end
end

function Manager:checkCanPopYinliuStage4()
    if not self:isEnabled() then return false end

    local model = self:getModel()
    local popTimes = model:getYinliuPopTimes()
    if popTimes >= 3 then return false end

    local totalCollection = model:getYinliuTotalCollection()
    local remainingCollection = model:getEnergy()
    if popTimes == 0 then
        return totalCollection >= 50
    end
    return remainingCollection >= 50 and model:getYinliuIntervalCollection() >= 30
end

function Manager:getYinliuFinalRewards()
    local cfg = self:getLocalConfig() or {}
    local rewards = {}

    local finalRewards = cfg.finalRewards or cfg.finalRewardList or cfg.finalRewardItemList
    if not table.isEmpty(finalRewards) then
        rewards = finalRewards
    else
        local stageRewards = cfg.stageRewardMetas or {}
        local finalMeta
        for _, meta in ipairs(stageRewards) do
            if not finalMeta then
                finalMeta = meta
            else
                local progress = meta.lastProgressId or meta.progressId or meta.id or 0
                local finalProgress = finalMeta.lastProgressId or finalMeta.progressId or finalMeta.id or 0
                if progress > finalProgress then
                    finalMeta = meta
                end
            end
        end
        rewards = finalMeta and (finalMeta.rewards or finalMeta.rewardList or finalMeta.itemList) or {}
    end

    return rewards
end

function Manager:createYinliuCollectionIcon()
    return UICreateUtil:createSpriteFile(self:getConst().localResPath .. "collectcon.png", true)
end

function Manager:showYinliuStage4(done)
    if not self:isEnabled() then safeRunCall(done) return end
    self:callDownloadFunc("getAssetsUtil"):loadMiniFiles({
        self:getConst().localResPath .. "collectcon.png",
    }):next(function()
        self:doShowYinliuStage4(done)
    end, done)
end

function Manager:doShowYinliuStage4(done)
    if not self:isEnabled() then safeRunCall(done) return end

    local DrainagePanelVM = require "amf.middleware.ui.kit.panel.second.DrainagePanelVM"
    local goCall = function()
        self:openActivity(done, { from = "drainage_collect_obtain" }, true)
    end
    local showRewards = self:getYinliuFinalRewards()
    local num = self:getModel():getEnergy()
    local collectionIcon = self:createYinliuCollectionIcon()

    local vm = DrainagePanelVM.Builder:new()
        :setTitle("秋日拾忆")
        :setColorType(_G.PanelColorConst.ColorType.kWindMatch)
        :setNumButton("去参与", nil, goCall)
        :pushDesc("您已获得了")
        :pushDesc(collectionIcon)
        :pushDesc(_G.YH_REF_MAP.x .. tostring(num) .. "，\n快去秋日拾忆领奖吧！")
        :pushBlock(showRewards, "终极大奖")
        :setCloseCallback(done)
        :build()

    self:callPlug("Panel", "managePanelVM", vm)
    vm:popout()
    self:getModel():onYinliuPopout()
    self:getDC():dcAttractPanelShow(UICreateUtil:getPanelId("ExploreMapGameYinliuStage4"), 1)
end

------------------------------------------------------------------------------
-- Read API (透传给 Cocos 端 Model 调用)
------------------------------------------------------------------------------
function Manager:addEnergy(num)                        return self:getModel():addEnergy(num) end
function Manager:getEnergy()                        return self:getModel():getEnergy() end
function Manager:getBag()                           return self:getModel():getBag() end
function Manager:getBagItemNum(itemId)              return self:getModel():getBagItemNum(itemId) end
function Manager:getNodeDataMap()                   return self:getModel():getNodeDataMap() end
function Manager:getNodeData(nodeId)                return self:getModel():getNodeData(nodeId) end
function Manager:isNodeDone(nodeId)                 return self:getModel():isNodeDone(nodeId) end
function Manager:getNodeFinishedSegments(nodeId)    return self:getModel():getNodeFinishedSegments(nodeId) end
function Manager:getMaxProgressId()                 return self:getModel():getMaxProgressId() end
function Manager:getTaskDataMap()                               return self:getModel():getTaskDataMap() end
function Manager:getTaskData(taskId)                            return self:getModel():getTaskData(taskId) end
function Manager:isTaskFinished(taskId)                         return self:getModel():isTaskFinished(taskId) end
function Manager:isTaskClaimed(taskId)                          return self:getModel():isTaskClaimed(taskId) end
function Manager:getTaskCurrent(taskId)                         return self:getModel():getTaskCurrent(taskId) end
function Manager:getTaskCollections(taskId)                     return self:getModel():getTaskCollections(taskId) end
function Manager:getExploreTaskProgressMap()                    return self:getModel():getExploreTaskProgressMap() end
function Manager:getExploreTaskProgress(taskId)                 return self:getModel():getExploreTaskProgress(taskId) end
function Manager:isExploreTaskClaimed(taskId)                   return self:getModel():isExploreTaskClaimed(taskId) end
function Manager:isAllExploreTaskRewardClaimed()                return self:getModel():isAllExploreTaskRewardClaimed() end
function Manager:getBattlePass()                    return self:getModel():getBattlePass() end
function Manager:getBattlePassValue()               return self:getModel():getBattlePassValue() end
function Manager:hasBattlePassVip()                 return self:getModel():hasBattlePassVip() end
function Manager:isPineappleClaimed(periodId, id)   return self:getModel():isPineappleClaimed(periodId, id) end
function Manager:getPineappleStationState(periodId) return self:getModel():getPineappleStationState(periodId) end
function Manager:getPineappleDisplayedProgress(periodId) return self:getModel():getPineappleDisplayedProgress(periodId) end
function Manager:setPineappleDisplayedProgress(periodId, progress) return self:getModel():setPineappleDisplayedProgress(periodId, progress) end
function Manager:getExploreTaskDisplayedCompletedCount() return self:getModel():getExploreTaskDisplayedCompletedCount() end
function Manager:setExploreTaskDisplayedCompletedCount(count) return self:getModel():setExploreTaskDisplayedCompletedCount(count) end
function Manager:isEndRewardClaimed()               return self:getModel():isEndRewardClaimed() end
function Manager:getBuffExpireTs(buffType)          return self:getModel():getBuffExpireTs(buffType) end
function Manager:getBuffExpireTsInSec(buffType)     return self:getModel():getBuffExpireTsInSec(buffType) end
function Manager:getEndlessPower()                  return self:getModel():getEndlessPower() end
function Manager:getEndlessPowerNextNodeIndex()     return self:getModel():getEndlessPowerNextNodeIndex() end
function Manager:isEndlessPowerNextNodePaid()       return self:getModel():isEndlessPowerNextNodePaid() end
function Manager:getLatestBuyFlowTs()               return self:getModel():getLatestBuyFlowTs() end
function Manager:getLatestFlowTodayNotShowTs()      return self:getModel():getLatestFlowTodayNotShowTs() end
function Manager:getLastOperatedNodeId()            return self:getModel():getLastOperatedNodeId() end
function Manager:hasGuideFlag(index)                return self:getModel():hasGuideFlag(index) end
function Manager:addGuideFlag(index)
    self:getModel():addGuideFlag(index)
    local ActCommonHttp = require "amf.middleware.activity.http.ActCommonHttp"
    ActCommonHttp:setActGuideFlag(self:getConst().actId, index, true)
end
function Manager:hasGuideIndex(index, checkLocalData) return self:hasGuideFlag(index) end
function Manager:addGuideIndex(index, needSaveLocal)  return self:addGuideFlag(index) end
function Manager:getClientMd5()                     return self:getModel():getClientMd5() end
function Manager:getRewardHeapClaimedMap()          return self:getModel():getRewardHeapClaimedMap() end
function Manager:isRewardHeapClaimed(nodeId, rewardIndex) return self:getModel():isRewardHeapClaimed(nodeId, rewardIndex) end
function Manager:consumeAutoPineappleRewards()      return self:getModel():consumeAutoPineappleRewards() end
function Manager:isGraduated()                      return self:getModel():isGraduated() end
function Manager:getRingTossCurrentMapId()          return self:getModel():getRingTossCurrentMapId() end
function Manager:isRingTossSlotRewarded(mapId, slotId) return self:getModel():isRingTossSlotRewarded(mapId, slotId) end
function Manager:getClaimedStageRewardIds()         return self:getModel():getClaimedStageRewardIds() end
function Manager:isStageRewardClaimed(stageId)      return self:getModel():isStageRewardClaimed(stageId) end
function Manager:getActivityLimitPackageIds()       return self:getModel():getActivityLimitPackageIds() end
function Manager:isActivityLimitPackageBought(packageId) return self:getModel():isActivityLimitPackageBought(packageId) end
function Manager:getActShowTimes()                  return self:getModel():getActShowTimes() end
function Manager:getActShowTimesByType(buyType)     return self:getModel():getActShowTimesByType(buyType) end
function Manager:getBuyEnergyTimes(day)             return self:getModel():getBuyEnergyTimes(day) end
function Manager:getBuyPackageTimes(day, packageId) return self:getModel():getBuyPackageTimes(day, packageId) end
function Manager:getPayTagV2Id(day)                 return self:getModel():getPayTagV2Id(day) end
function Manager:getFlowNextShowIndex(day)          return self:getModel():getFlowNextShowIndex(day) end
function Manager:getPackagesPullResponse()          return self:getModel():getPackagesPullResponse() end
function Manager:getLocalConfig()                  return self:getModel():getLocalConfig() end
function Manager:getNodeRuntimeParams(nodeId)       return self:getModel():getNodeRuntimeParams(nodeId) end
function Manager:getFogRuntimeRule(fogId)           return self:getModel():getFogRuntimeRule(fogId) end
function Manager:getStoryRuntimeRule(storyId)       return self:getModel():getStoryRuntimeRule(storyId) end
function Manager:getFragmentRuntimeSource(idx)      return self:getModel():getFragmentRuntimeSource(idx) end
function Manager:getBalloonScreenIndex()            return self:getModel():getBalloonScreenIndex() end
function Manager:getPoppedBalloonIds()              return self:getModel():getPoppedBalloonIds() end
function Manager:isBalloonPopped(screenIndex, balloonId) return self:getModel():isBalloonPopped(screenIndex, balloonId) end
function Manager:getRemainingObstacleCount()        return self:getModel():getRemainingObstacleCount() end
function Manager:isFinalRewardClaimed()             return self:getModel():isFinalRewardClaimed() end
function Manager:checkPopState4Gift()
    return self.giftPart and self.giftPart:_checkPopStage4Gift() 
end
function Manager:pullGiftByNames(tb)                return self.giftPart and self.giftPart:pullGiftByNames(tb) end
function Manager:getPrice(goodsId)                  return self.giftPart and self.giftPart:getPrice(goodsId) or 0 end
function Manager:createBuyButton(data)              return self.giftPart and self.giftPart:createBuyButton(data) end
function Manager:clearPassLevelTimeTody()           if self.giftPart then self.giftPart:clearPassLevelTimeTody() end end
function Manager:addPassLevelTimeTody()             if self.giftPart then self.giftPart:addPassLevelTimeTody() end end
function Manager:popProcessGift(goodsId, multipleGift, multipleCheckBox, panelSource, closeCallback)
    if not goodsId then return end
    local GiftPanelVM = require "amf.feature.localactivity.exploremapgame.view.ProcessGiftPanelVM"
    local vm = GiftPanelVM:create({
        goodsId = goodsId,
        multipleGift = multipleGift,
        multipleCheckBox = multipleCheckBox,
        panelSource = panelSource,
        mgr = self,
    })
    vm:setCloseCallback(closeCallback)
    vm:popout()
    self.panelPlug:managePanelVM(vm)
end
function Manager:popStage4Gift(callback, panelSource)
    if not self.giftPart then safeRunCall(callback) return end
    self.giftPart:_popStage4GoodsIdGet(function(goodsId, multipleGift)
        if goodsId then
            self:popProcessGift(goodsId, multipleGift, function(isCheck)
                if isCheck then self:flowNotShowToday() end
            end, panelSource or 1, function()
                safeRunCall(callback)
            end)
        else
            safeRunCall(callback, goodsId, multipleGift)
        end
    end)
end

------------------------------------------------------------------------------
-- Network API
------------------------------------------------------------------------------
-- Model:onResponseXxx 已经负责把响应数据写入 Model；
-- Manager 仅负责发请求、暴露统一回调签名给 Cocos 端调用方。

local function _extractData(evt)
    if not evt then return {} end
    if evt.getData then return evt:getData() or {} end
    return evt.data or {}
end

local function _isEmpty(list)
    return list == nil or table.isEmpty(list)
end

local function _appendRewards(out, rewards)
    if _isEmpty(rewards) then return end
    for _, reward in ipairs(rewards) do
        table.insert(out, reward)
    end
end

function Manager:_getRewardSource(sourceExt)
    local defaultSource = "act_" .. tostring(self:getConst().actId)
    if sourceExt then
        sourceExt = tostring(sourceExt)
    end
    return {
        dcFeature = self:getConst().dcFeature,
        dcSource = sourceExt or defaultSource,
    }
end

function Manager:addRewardsNormal(rewards, sourceExt, extraMap)
    local normalRewards = self:getNormalRewards(rewards)
    if _isEmpty(normalRewards) or not self.rewardsPlug then return end
    self.rewardsPlug:addRewardsNormal(normalRewards, {
        dcExtra = self:_getRewardSource(sourceExt),
        extraMap = extraMap,
    })
end

function Manager:syncRewardFields(data)
    -- addRewardsNormal 只负责展示/普通奖励入账；之后用协议权威值覆盖 energy / updatedBag，避免重复加。
    local model = self:getModel()
    if model and model.syncRewardFields then
        model:syncRewardFields(data or {})
    end
end

function Manager:getNormalRewards(rewards)
    if _isEmpty(rewards) then return rewards end
    local ret = {}
    for _, reward in ipairs(rewards) do
        if not self:_isExploreMapGameProp(reward.itemId) then
            ret[#ret + 1] = reward
        end
    end
    return ret
end

function Manager:_collectEndPeriodRewards(data)
    local rewards = {}
    _appendRewards(rewards, data and data.pendingRewards)
    _appendRewards(rewards, data and data.rewards)
    return rewards
end

function Manager:_findRewardHeapRewards(nodeId, rewardIndex)
    local cfg = self:getLocalConfig()
    local rewardHeapId = self:getNodeRuntimeParams(nodeId).rewardHeapId
    for _, meta in ipairs(cfg.rewardHeapMetas) do
        if meta.rewardHeapId == rewardHeapId and meta.slotIndex == rewardIndex then
            return meta.rewards
        end
    end
end

function Manager:loadMainInfo(md5, packagesPullRequest, onOK, onFail, light)
    packagesPullRequest = packagesPullRequest or {
        scene = "activity_scene",
        queryParams = {
            [self:getConst().moduleName] = table.serialize({
                moduleVersion = 0,
                wants = {
                    self:getConst().GiftTypeEnum.ENDLESS_POWER,
                    self:getConst().GiftTypeEnum.PROGRESS,
                    self:getConst().GiftTypeEnum.SPRINT,
                    self:getConst().GiftTypeEnum.RMB_ENERGY,
                    self:getConst().GiftTypeEnum.FLOW,
                    self:getConst().GiftTypeEnum.BATTLE_PASS,
                    self:getConst().GiftTypeEnum.CASH_ENERGY,
                },
            }),
        },
    }

    self:getModel():requestMainInfo({
        clientVersionedConfig = {
            clientMd5 = md5 or self:getClientMd5() or "",
        },
        -- §6.6 上报前端本地配置版本；后端 actInfo 下发当前配置版本，前端比对不一致时隐藏 icon
        configVersion = self:getLocalConfigVersion(),
        packagesPullRequest = packagesPullRequest,
        light = light == true,
    })
        :next(function(evt)
            self:refreshPackageMetas()
            safeRunCall(onOK, _extractData(evt))
        end,
              function(resp) safeRunCall(onFail, resp) end)
end

function Manager:refreshPackageMetas()
    local packageInfos = self:getModel():getPackageMetas()
    for k, v in pairs(packageInfos) do
        GoodsManager:registerGoods({
            goodsId = k,
            packageMeta = v.packageMeta,
        })
    end
end

function Manager:getGiftPackages()
    return self:getModel():getGiftPackages()
end

function Manager:getDisplayablePackages()
    return self:getModel():getDisplayablePackages()
end

function Manager:getPackageMetas()
    return self:getModel():getPackageMetas()
end

function Manager:getModuleExtraMap()
    return self:getModel():getModuleExtraMap()
end

function Manager:requestPackagepull(params, successCallback, failCallback)
    self:getModel():requestPackagepull(params)
        :next(successCallback, failCallback)
end

function Manager:requestActivityAction(params, successCallback, failCallback)
    self:getModel():requestActivityAction(params)
        :next(successCallback, failCallback)
end

function Manager:requestBuyGiftPackage(goodsId, buyType, buyCount, successCallback, failCallback, cancelCallback)
    local buyContext = BuyContext.new(goodsId, buyType)
        :setFeatureAndSource(self:getConst().dcFeature, "power_gift")
        :setUnifiedBuy(true, GiftPackageConst.StageType.ACTIVITY, self:getConst().moduleName)
        :setBuyCount(buyCount or 1)
        :setCallback(successCallback, failCallback, cancelCallback)
    _G.amfTransaction(TransactionEvent.PAY, buyContext)
end

function Manager:cleanSelfActRewardFlyFunc(rewards)
    if not rewards then return end
    local energyItemId = self:getConst().ItemId.ENERGY
    for _, reward in ipairs(rewards) do
        if reward and tonumber(reward.itemId) == tonumber(energyItemId) then
            reward.flyFunc = nil
        end
    end
end

function Manager:operateNode(nodeId, segmentIndex, onOK, onFail)
    local protocol = "mistyClearMapOperateNode"
    local params = {
        nodeId       = nodeId,
        segmentIndex = segmentIndex or 1,
    }
    local plug = self:_getPlug("ActSend")
    if plug then
        params = plug:handleRequestParams(protocol, params)
    end
    self:getModel():requestOperateNode(params):next(function(evt)
                local data = _extractData(evt)
                if plug then
                    plug:handleRewardByProtocol(protocol, data)
                end
                self:cleanSelfActRewardFlyFunc(data.stageRewards)
                -- 进度奖励 origin 道具获得点走 addRewardsNormal 统一发奖链路，source 对齐 main_panel_reward。
                self:addRewardsNormal(data.stageRewards, "main_panel_reward")
                self:syncRewardFields(data)
                safeRunCall(onOK, data)
            end,
            function(resp) safeRunCall(onFail, resp) end)
end

function Manager:claimExploreTaskReward(taskId, rewardUniteExtraIds, onOK, onFail)
    local protocol = "mistyClearMapClaimExploreTaskReward"
    local params = {
        taskId = taskId,
        rewardUniteExtraIds = rewardUniteExtraIds or {},
    }
    local plug = self:_getPlug("ActSend")
    if plug then
        params = plug:handleRequestParams(protocol, params)
    end
    self:getModel():requestClaimExploreTaskReward(params)
        :next(function(evt)
            local data = _extractData(evt)
            if plug then
                plug:handleRewardByProtocol(protocol, data)
            end
            self:cleanSelfActRewardFlyFunc(data.rewards)

            self:addRewardsNormal(data.rewards, "expedition_reward")
            self:syncRewardFields(data)

            safeRunCall(onOK, data)
        end,
              function(resp) safeRunCall(onFail, resp) end)
end

function Manager:claimAllExploreTaskReward(onOK, onFail)
    local protocol = "mistyClearMapClaimAllExploreTaskReward"
    local params = { }
    local plug = self:_getPlug("ActSend")
    if plug then
        params = plug:handleRequestParams(protocol, params)
    end
    self:getModel():requestClaimAllExploreTaskReward(params)
        :next(function(evt)
            local data = _extractData(evt)
            if plug then
                plug:handleRewardByProtocol(protocol, data)
            end
            self:cleanSelfActRewardFlyFunc(data.rewards)
            self:addRewardsNormal(data.rewards, "expedition_reward")
            self:syncRewardFields(data)
            safeRunCall(onOK, data)
        end,
              function(resp) safeRunCall(onFail, resp) end)
end

function Manager:claimBattlePassReward(id, vip, rewardUniteExtraIds, onOK, onFail)
    -- 注意：rewardUniteExtraIds 参数 §6.8 联动发奖；调用方可传 nil
    self:getModel():requestClaimBattlePassReward({ id = id, vip = vip == true, rewardUniteExtraIds = rewardUniteExtraIds or {} })
        :next(function(evt)
            local data = _extractData(evt)
            self:addRewardsNormal(data.rewards, "feedback_reward", {
                pay_type = vip and DcPayType.kRmb or DcPayType.kFree,
            })
            self:syncRewardFields(data)
            safeRunCall(onOK, data)
        end,
              function(resp) safeRunCall(onFail, resp) end)
end

function Manager:claimPineappleReward(periodId, nodeIds, rewardUniteExtraIds, onOK, onFail)
    if type(nodeIds) == "number" then nodeIds = { nodeIds } end
    local protocol = "mistyClearMapClaimPineappleReward"
    local params = {
        periodId = periodId,
        nodeIds = nodeIds or {},
        rewardUniteExtraIds = rewardUniteExtraIds or {},
    }
    local plug = self:_getPlug("ActSend")
    if plug then
        params = plug:handleRequestParams(protocol, params)
    end
    self:getModel():requestClaimPineappleReward(params)
        :next(function(evt)
            local data = _extractData(evt)
            if plug then
                plug:handleRewardByProtocol(protocol, data)
            end
            self:addRewardsNormal(data.rewards, "pine_cone_reward")
            self:syncRewardFields(data)
            safeRunCall(onOK, data)
        end,
              function(resp) safeRunCall(onFail, resp) end)
end

function Manager:claimRewardHeap(nodeId, rewardIndex, onOK, onFail)
    self:getModel():requestClaimRewardHeap({ nodeId = nodeId, rewardIndex = rewardIndex })
        :next(function(evt)
            local data = _extractData(evt)
            local rewards = data.rewards
            if _isEmpty(rewards) then
                rewards = self:_findRewardHeapRewards(nodeId, rewardIndex)
                data.rewards = rewards
            end
            self:addRewardsNormal(rewards, "main_panel_reward_pile")
            self:syncRewardFields(data)
            safeRunCall(onOK, data)
        end,
            function(resp) safeRunCall(onFail, resp) end)
end

function Manager:balloonConsume(screenIndex, balloonId, onOK, onFail)
    self:getModel():requestRingTossConsume({ mapId = screenIndex, slotId = balloonId or -1 })
        :next(function(evt)
            local data = _extractData(evt)
            self:addRewardsNormal(data.rewards, "ring_toss")
            self:syncRewardFields(data)
            safeRunCall(onOK, data)
        end,
              function(resp) safeRunCall(onFail, resp) end)
end

function Manager:ringTossConsume(mapId, slotId, onOK, onFail)
    return self:balloonConsume(mapId, slotId, onOK, onFail)
end

function Manager:balloonPop(screenIndex, balloonId, onOK, onFail)
    local balloonIds = type(balloonId) == "table" and balloonId or { balloonId }
    self:getModel():requestBalloonPop({
        screenIndex = screenIndex,
        balloonIds = balloonIds,
    }):next(function(evt)
        local data = _extractData(evt)
        local results = data.results or {}
        local allRewards = {}
        for _, r in ipairs(results) do
            if r.rewards then
                for _, rw in ipairs(r.rewards) do
                    allRewards[#allRewards + 1] = rw
                end
            end
        end
        data.rewards = allRewards
        data.screenIndex = data.balloonScreenIndex or screenIndex
        if #results > 0 then
            local r = results[1]
            if r.miss then
                data.resultType = "EMPTY"
            elseif r.type == 1 then
                data.resultType = "BIG_PRIZE"
                data.bigPrizeHit = true
            elseif r.type == 2 then
                data.resultType = "EGG_DART"
            else
                data.resultType = "POOL_REWARD"
            end
        end
        data.roundFinished = (data.balloonScreenIndex ~= nil and data.balloonScreenIndex ~= screenIndex)
        self:addRewardsNormal(data.rewards, "ferrule_click")
        self:syncRewardFields(data)
        safeRunCall(onOK, data)
    end, function(resp)
        safeRunCall(onFail, resp)
    end)
end

function Manager:rewardEndlessPower(rewardIndex, onOK, onFail)
    self:getModel():requestRewardEndlessPower({ rewardIndex = rewardIndex })
        :next(function(evt)
            local data = _extractData(evt)
            self:addRewardsNormal(data.rewards, "endless_reward")
            safeRunCall(onOK, data)
        end,
              function(resp) safeRunCall(onFail, resp) end)
end

function Manager:claimEndPeriodRewards(rewardUniteExtraIds, onOK, onFail)
    -- 注意：rewardUniteExtraIds 参数 §6.8 联动发奖；调用方可传 nil
    self:getModel():requestClaimEndPeriodRewards({ rewardUniteExtraIds = rewardUniteExtraIds or {} })
        :next(function(evt)
            local data = _extractData(evt)
            self:addRewardsNormal(data and data.exchangeRewards, "due_recycle")
            self:addRewardsNormal(self:_collectEndPeriodRewards(data), "reward_time")
            self:syncRewardFields(data)
            safeRunCall(onOK, data)
        end,
              function(resp) safeRunCall(onFail, resp) end)
end

function Manager:replaceStageRewardFinal(rewardsList, stageIndex)
    local plug = self:_getPlug("ActSend")
    if plug and plug.replaceStageRewardFinal then
        return plug:replaceStageRewardFinal(rewardsList, stageIndex)
    end
    return rewardsList
end

function Manager:replaceExploreTaskRewardFinal(rewardsList, taskId)
    local plug = self:_getPlug("ActSend")
    if plug and plug.replaceExploreTaskRewardFinal then
        return plug:replaceExploreTaskRewardFinal(rewardsList, taskId)
    end
    return rewardsList
end

function Manager:replaceAllExploreTaskRewardFinal(rewardsList)
    local plug = self:_getPlug("ActSend")
    if plug and plug.replaceAllExploreTaskRewardFinal then
        return plug:replaceAllExploreTaskRewardFinal(rewardsList)
    end
    return rewardsList
end


function Manager:flowNotShowToday(onOK, onFail)
    self:getModel():requestActivityAction({
        actId  = self:getConst().actId,
        action = "notShowToday",
        param  = "",
    }):next(function(evt) safeRunCall(onOK, _extractData(evt)) end,
            function(resp) safeRunCall(onFail, resp) end)
end

function Manager:requestBuyFlowGiftPackage(goodsId, buyType, buyCount, successCallback, failCallback, cancelCallback, goldUpdateFunc, source)
    local buyContext = BuyContext.new(goodsId, buyType)
        :setFeatureAndSource(self:getConst().dcFeature, source or "flow_gift")
        :setUnifiedBuy(true, GiftPackageConst.StageType.ACTIVITY, self:getConst().moduleName)
        :setBuyCount(buyCount or 1)
        :setGoldNotEnough(nil, nil, goldUpdateFunc)
        :setCallback(successCallback, failCallback, cancelCallback)
    _G.amfTransaction(TransactionEvent.PAY, buyContext)
end

function Manager:applyPackageDeliverNotify(packageId, buyType, requestTs)
    return self:getModel():applyPackageDeliverNotify(packageId, buyType, requestTs)
end

function Manager:_isExploreMapGameProp(itemId)
    itemId = tonumber(itemId)

    local Const = self:getConst()
    local notInLocalItemList = {
        Const.ItemId.ENERGY, Const.ItemId.BUFF_DOUBLE, Const.ItemId.BUFF_SCORE_20, Const.ItemId.BUFF_SCORE_50
    }

    return itemId ~= nil and itemId >= 58116 and itemId <= 58180 and not table.exist( notInLocalItemList, itemId )
end

function Manager:_onCustomGain(event)
    -- PropEventCenter 派发的是 AMFEvent，必须用 getData() 取原始 reward table。
    local reward = event:getData()
    if not reward then return end

    local Const = self:getConst()
    if reward.itemId == Const.ItemId.ENERGY then
        if self:isGraduated() then return end
        -- 活动体力直接累加到 ExploreMapGameModel.energy，不进入通用 bag。
        self:getModel():addEnergy(reward.num)
    elseif reward.itemId == Const.ItemId.BUFF_DOUBLE then
        -- 收集物翻倍 buff：reward.num 语义为分钟，Model:addBuffTime 内部换算为毫秒并叠加过期时间。
        self:getModel():addBuffTime(Const.BuffType.DOUBLE, reward.num)
    elseif reward.itemId == Const.ItemId.BUFF_SCORE_20 then
        -- 分数 +20% buff：scoreBuff 图标由 items_active_config.lua 的 effectType=14/effectValue=120 驱动。
        self:getModel():addBuffTime(Const.BuffType.SCORE_20, reward.num)
    elseif reward.itemId == Const.ItemId.BUFF_SCORE_50 then
        -- 分数 +50% buff：scoreBuff 图标由 items_active_config.lua 的 effectType=14/effectValue=150 驱动。
        self:getModel():addBuffTime(Const.BuffType.SCORE_50, reward.num)
    end

    local isExploreReward = reward.itemId == Const.ItemId.ENERGY
        or reward.itemId == Const.ItemId.BUFF_DOUBLE
        or reward.itemId == Const.ItemId.BUFF_SCORE_20
        or reward.itemId == Const.ItemId.BUFF_SCORE_50
        or self:_isExploreMapGameProp(reward.itemId)
    if reward._fromLuckyExpress and isExploreReward then
        -- 直接快递发奖不经过活动联动入口，仅在该来源下刷新一次活动提示。
        if not self._luckyExpressTipRefreshPending then
            self._luckyExpressTipRefreshPending = true
            setTimeOut(function()
                self._luckyExpressTipRefreshPending = nil
                self:callPlug("Act", "updateTipView")
            end, 0)
        end
    end
end

function Manager:_onResolveIcon(event)
    -- 动态 icon 只接管需要活动素材的体力和双倍 buff；scoreBuff 交给 propfeature 通用 scoreBuff 逻辑。
    local data = event:getData()

    local Const = self:getConst()
    if data.itemId ~= Const.ItemId.ENERGY and data.itemId ~= Const.ItemId.BUFF_DOUBLE then return end
    -- IsPropPng=true 表示独立 PNG；小游戏端缺图时 CommonDefine.loadPropItem 会异步下载并刷新。
    data.callback({
        Atlas = "",
        Frame = Const.localResPath .. "collectcon.png",
        IsPropPng = true,
    })
end

function Manager:testTopBanner(reward, startWorldPos, onFinish)
    return self:callActSentFunc("testTopBanner", reward, startWorldPos, onFinish)
end

function Manager:loadRes(delegate)
    local successCallback = delegate.successCallback
    local failCallback = delegate.failCallback
    local resList = delegate.resList
    if EnvUtil and EnvUtil:isMiniGame() then
        _G.amfBean("AssetsUtil"):loadMiniFiles(resList):next(successCallback, failCallback)
    else
        safeRunCall(successCallback)
    end
end


return Manager
