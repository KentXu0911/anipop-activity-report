require "amf.feature.localactivity.supermagicbird.SmbDebug"

local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"

local SuperMagicBird2024Manager = class("SuperMagicBird2024Manager",BaseFeatureManager)
--扩展mgr
-- local ServerData = require 'amf.feature.localactivity.supermagicbird.model.SuperMagicBirdModel'
local Meta = require "amf.feature.localactivity.supermagicbird.config.SuperMagicBirdConst.lua"

-- local closeAct =require 'amf.feature.localactivity.supermagicbird.SuperMagicBird2024Manager_closeAct'
-- closeAct(SuperMagicBird2024Manager)
local fuuu = require 'amf.feature.localactivity.supermagicbird.SuperMagicBird2024Manager_fuuu'
fuuu(SuperMagicBird2024Manager)
local fuuuv2 = require 'amf.feature.localactivity.supermagicbird.SuperMagicBird2024Manager_fuuuV2'
fuuuv2(SuperMagicBird2024Manager)
local pop = require 'amf.feature.localactivity.supermagicbird.SuperMagicBird2024Manager_pop'
pop(SuperMagicBird2024Manager)
local http = require 'amf.feature.localactivity.supermagicbird.SuperMagicBird2024Manager_http'
http(SuperMagicBird2024Manager)
local inLevel = require 'amf.feature.localactivity.supermagicbird.SuperMagicBird2024Manager_inLevel'
inLevel(SuperMagicBird2024Manager)
local guide = require 'amf.feature.localactivity.supermagicbird.SuperMagicBird2024Manager_guide'
guide(SuperMagicBird2024Manager)
SuperMagicBird2024Manager.ACT_OPEN_VERSION = 3  --如果此活动复用 此值应递增 以区分本地存储值
local ActivityEventCenter = require 'amf.middleware.activity.event.ActivityEventCenter'

-- 主线
SuperMagicBird2024Manager.ACT_ID = 8068
-- SuperMagicBird2024Manager.ACT_SOURCE = "SuperMagicBird2024/Config.lua"
SuperMagicBird2024Manager.GAME_NAME = "bird_win"
SuperMagicBird2024Manager.DCFeature = "supermagicbird"
SuperMagicBird2024Manager.DCSource = "act_"..SuperMagicBird2024Manager.ACT_ID
SuperMagicBird2024Manager.ACT_CH_NAME = "超级魔力鸟" 

local ACT_NAME = "supermagicbird"
local LOCAL_PATH = 'amf.feature.localactivity.'..string.lower( ACT_NAME )
local SECONDS_PER_DAY = 24 * 60 * 60

local log = _G.SmbLog or doNothing

function SuperMagicBird2024Manager:_init()
    self._reviveConfirmAutoPopPending = false

    -- self.__unlockAreaListener = function ()
    --     if not self:isEnabled() then return end
    --     self:tryShowActIcon()
    -- end
    _G.amfEC:registerNormal(NormalEvent.PASS_DAY, self.onActPassDay, self)
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
end

function SuperMagicBird2024Manager:onActPassDay()
    self:notify(self:getBaseEvent().kCloseAllPanel)
    BaseFeatureManager.onActPassDay(self)
end

function SuperMagicBird2024Manager:setActivityMgr(activityMgr)
    self._activityMgr = activityMgr
end

function SuperMagicBird2024Manager:setAutoPopupMgr(autoPopupMgr)
    self.autoPopupMgr = autoPopupMgr
end

function SuperMagicBird2024Manager:_getExtraPlugsConfigList()
    return {
        {key = "Panel"},
        {key = "Download"},
        {key = "AutoPop"},
    }
end

function SuperMagicBird2024Manager:_getAutoPopConfigList()
    local PopStage = AutoPopupConst.PopStage

    return {
        {
            -- 仅场景4；条件触发类最高优先级；玩家带超鸟失败并实际断鸟后的下一次场景4，复活卡可用时弹出激活二次确认面板；次数由一次性断鸟标记控制。
            checkPoint = PopupCheckPoint.SUPER_MAGIC_BIRD_REVIVE_CONFIRM,
            stages = { PopStage.STAGE_FOUR },
            check = function()
                return self:checkCanAutoPopReviveConfirm()
            end,
            creator = function(_, onPopOver)
                return function()
                    self:popReviveConfirmAutoPop(onPopOver)
                end
            end,
        },
        {
            -- 场景2、场景4每天最多弹出一次，活动类优先级仅次于签到面板；未领取时先领取再展示，已领取时直接展示。
            checkPoint = PopupCheckPoint.SUPER_MAGIC_BIRD_REVIVE,
            stages = { PopStage.STAGE_TWO, PopStage.STAGE_FOUR },
            check = function()
                return self:checkCanAutoPop()
            end,
            creator = function(stageParams, onPopOver)
                return function()
                    self:openReviveCardDeliveryAutoPop(onPopOver, stageParams.popStage)
                end
            end,
        },
    }
end

function SuperMagicBird2024Manager:markReviveConfirmAutoPopPending()
    self._reviveConfirmAutoPopPending = true
end

function SuperMagicBird2024Manager:checkCanAutoPopReviveConfirm()
    if self._reviveConfirmAutoPopPending ~= true then
        return false
    end

    return self:canActivateReviveCard()
end

function SuperMagicBird2024Manager:popReviveConfirmAutoPop(onPopOver)
    if not self:canActivateReviveCard() then
        safeRunCall(onPopOver)
        return
    end
    self._reviveConfirmAutoPopPending = false
    self:openReviveConfirmPanel({
        isAutoPop = true,
        closeCallback = function()
            safeRunCall(onPopOver)
            local playLevelContext = PlayLevelContext.new()
            _G.amfTransaction(TransactionEvent.PLAY_LEVEL, playLevelContext)
        end,
    })
end

function SuperMagicBird2024Manager:checkCanAutoPop()
    return self:hasReviveCard() or self:canRewardReviveCardToday()
end

function SuperMagicBird2024Manager:markReviveCardDeliveryAutoPopConsumed()
    local reviveCheckPoint = PopupCheckPoint.SUPER_MAGIC_BIRD_REVIVE
    if self.autoPopupMgr:getCheckPointPopNum(reviveCheckPoint) <= 0 then
        self.autoPopupMgr:increaseCheckPointPopNum(reviveCheckPoint)
    end
end

function SuperMagicBird2024Manager:popReviveCardDeliveryNoticePanel(onPopOver, popStage)
    local showType = self:getReviveCardDeliveryPanelShowType(false, popStage)
    self:popReviveCardDeliveryPanel(
        onPopOver,
        false,
        showType,
        Meta.ReviveCardDeliveryMode.kClickContinue
    )
end

function SuperMagicBird2024Manager:openReviveCardDeliveryAutoPop(onPopOver, popStage)
    if self:hasReviveCard() then
        self:popReviveCardDeliveryNoticePanel(onPopOver, popStage)
        return
    end

    if self:canRewardReviveCardToday() then
        self:openReviveCardDeliveryPanel(
            onPopOver,
            false,
            popStage,
            Meta.ReviveCardDeliveryMode.kClickContinue
        )
        return
    end

    safeRunCall(onPopOver)
end

function SuperMagicBird2024Manager:openReviveCardDeliveryPanel(onPopOver, userClick, popStage, deliveryMode)
    deliveryMode = deliveryMode or Meta.ReviveCardDeliveryMode.kTakeButton
    local todayRewarded = self:hasReviveCard()
    local showType = self:getReviveCardDeliveryPanelShowType(userClick, popStage)
    local panelCloseCallback = onPopOver
    if userClick and todayRewarded then
        panelCloseCallback = nil
    end
    if not self:canRewardReviveCardToday() then
        if userClick then
            self:popReviveCardDeliveryPanel(panelCloseCallback, todayRewarded, showType, deliveryMode)
        else
            safeRunCall(onPopOver)
        end
        return
    end

    local function onSuccess()
        self:popReviveCardDeliveryPanel(panelCloseCallback, todayRewarded, showType, deliveryMode)
    end

    local requestOverCallback = onPopOver
    if userClick then
        requestOverCallback = nil
    end
    self:requestReviveCardReward(onSuccess, requestOverCallback, requestOverCallback)
end

function SuperMagicBird2024Manager:getReviveCardDeliveryPanelShowType(userClick, popStage)
    if userClick then
        return 3
    end

    local PopStage = AutoPopupConst.PopStage
    if popStage == PopStage.STAGE_TWO then
        return 1
    elseif popStage == PopStage.STAGE_FOUR then
        return 2
    end
end

function SuperMagicBird2024Manager:popReviveCardDeliveryPanel(onPopOver, todayRewarded, showType, deliveryMode)
    local panelClass = require("amf.feature.localactivity.supermagicbird.views.ReviveCardDeliveryPanelVM")
    local panel = panelClass:create({
        mgr = self,
        closeCallback = onPopOver,
        todayRewarded = todayRewarded,
        isLastDay = self:isReviveCardLastDay(),
        showType = showType,
        deliveryMode = deliveryMode,
    })
    panel:popout()
    self:markReviveCardDeliveryAutoPopConsumed()
    self.panelPlug:managePanelVM(panel)
end

function SuperMagicBird2024Manager:dcReviveCardDeliveryPanelShow(showType, todayRewarded, panelId)
    self:dc("bird_win_v2", "reborn_show", showType, todayRewarded and 2 or 1, nil, nil, {
        panel_id = panelId,
    })
end

function SuperMagicBird2024Manager:dcReviveCardDeliveryPanelClick(panelId)
    self:dc("bird_win_v2", "reborn_click", nil, nil, nil, nil, {
        panel_id = panelId,
    })
end

-- 获取model路径
function SuperMagicBird2024Manager:_getModelPath()
    return LOCAL_PATH..'.model.SuperMagicBirdModel'
end

function SuperMagicBird2024Manager:_getConstPath()
    return LOCAL_PATH..'.config.SuperMagicBirdConst'
end

function SuperMagicBird2024Manager:getData()
    return self:getModel()
end

function SuperMagicBird2024Manager:getActInfo()
	local actInfo = self._activityMgr:getActInfo(self.ACT_ID)
    return actInfo
end

function SuperMagicBird2024Manager:breakWin()
    if not self:isEnabled() then return end
    self:getData():passLevelFunc( false, self:getNeedWinNum(), false, false, false, Meta.keepWinReason.kNone )
end


-- function SuperMagicBird2024Manager:isSupport()
--     if self:isUnSupportPkg() then return false end
--     if not self:isTopLevelSupport() then return false end
--     local actInfo = self:getActInfo()
--     if not actInfo then return false end
--     return true
-- end

-- function SuperMagicBird2024Manager:isUnSupportPkg()
--     if _G.isPrePackage then
--         return true
--     end
--     return false
-- end

function SuperMagicBird2024Manager:isTopLevelSupport()
    local levelId = _G.amfBean("LevelAreaManager"):getTopPassedLevel()
    if Meta.passLevelId and levelId<(Meta.passLevelId) then
        return false
    end
    return true
end

function SuperMagicBird2024Manager:onActEnterMainScene(evt)
    if EnvUtil:isDevelopMode() then
        addGlobalTestButton("超鸟Log开关", function()
            local logEnabled = _G.switchSmbLogEnabled and _G.switchSmbLogEnabled()
            local msg = logEnabled and "超鸟log已开启\n请查看[-13]通道" or "超鸟log已关闭"
            return msg, false
        end, { TestButtonConst.Tags.DEVELOP })
    end

    -- local data = evt:getData()
    -- if not ( data and data.firstEnter ) then return end
    -- if not self:isSupport() then return end

    -- --发lightStart
    -- self:getInfoAsync(nil,nil,nil,true,false)
end


function SuperMagicBird2024Manager:checkCanUseActInfoData( actInfoExtra )

    log("checkCanUseActInfoData 是否使用后端actInfo数据检测开始", actInfoExtra)

    if not actInfoExtra then return true end

    local extra = actInfoExtra

    local bCanChangeData = false
    if extra.ignoreBreakVersion1 then
        bCanChangeData = true
        log("checkCanUseActInfoData 开关关闭，信任后端")
    else
        if self:isEnabled() then
            log("checkCanUseActInfoData 本地有数据记录，校验本地数据")

            local clientBreakVersion = self:getData():getDataByKey( 'breakVersion1' ) or 0
            local serverBreakVersion = extra.breakVersion1 or 0

            log("checkCanUseActInfoData 客户端断鸟版本 后端断鸟版本", clientBreakVersion, serverBreakVersion )

            if clientBreakVersion <= serverBreakVersion then
                bCanChangeData = true
                log("checkCanUseActInfoData 当前版本小于等于后端，使用后端")
            end
        else
            log("checkCanUseActInfoData 本地无数据记录，跳过校验，直接用后端的")
            bCanChangeData = true
        end
    end

    log("checkCanUseActInfoData 是否使用后端actInfo数据检测结束 bCanChangeData =", bCanChangeData)

    return bCanChangeData
end

function SuperMagicBird2024Manager:onActReceiveEmergency(evt)
    local eventData = evt:getData()

    if eventData and eventData.endPoint == EmergencyConst.SUPERMAGICBIRD and eventData.data then
        local data = table.clone(eventData.data)
        if not self:isEnabled() then return end

        log("onActReceiveEmergency")

        local bCanChangeData = self:checkCanUseActInfoData(data)
    
        if bCanChangeData then
            if data.adjustInfo then
                self:getData():updateAdjustInfo(data.adjustInfo)
            end

            if data.cycleInfo then
                self:getData():updateCycleInfo(data.cycleInfo)
            end

            if data.adjustInfo2025 then
                self:getData():updateCycleInfo2025(data.adjustInfo2025)
            end

            if data.breakVersion1 then
                self:getData():updateBreakVersion1( data.breakVersion1 )
            end
        end
    end
end

-- function SuperMagicBird2024Manager:firstInitActData(actInfo)
--     --从user的actInfo中初始化数据
--     -- if self:isEnabled() then return end

--     if actInfo then
--         if actInfo.extra then

--             local extra = table.deserialize(actInfo.extra)

--             log("firstInitActData")

--             local bCanChangeData = self:checkCanUseActInfoData(extra)

--             if not self:isEnabled() and bCanChangeData and extra.cycleInfo then

--                 local data = {}

--                 data.data = {
--                     adjustInfo = table.clone(extra.adjustInfo),
--                     cycleInfo = table.clone(extra.cycleInfo),
--                     callback = extra.periodInfo.callback,
--                     canFarm = extra.canFarm,
--                     close = extra.periodInfo.close,
--                     group = extra.periodInfo.group,
--                     payTag = extra.payTag,
--                     callBackInfo = table.clone(extra.callBackInfo),
--                     guideIds = table.clone(extra.guideIds),
--                     maxWinStreakNums = extra.maxWinStreakNums,
--                     -- winCombInfo = extra.winCombInfo and table.clone(extra.winCombInfo),
--                     --新增
--                     group2025 = extra.periodInfo.group2025 or "OFF1",
--                     adjustInfo2025 = table.clone(extra.adjustInfo2025 or {}),

--                     breakVersion1 = extra.breakVersion1,
--                 }

--                 data.serverVersionedConfig = {
--                     serverMd5 = "12345",
--                     config = {
--                         peakTopLevelId = extra.peakTopLevelId,
--                         minTopLevelId = extra.minTopLevelId,
--                         minTriggerLevelNums = extra.minTriggerLevelNums,
--                         maxTopLevelId = extra.maxTopLevelId,
--                         keepLimit = extra.keepLimit,
--                         periodInfo = table.clone(extra.periodInfo),
--                         pityValAdjustMetas= table.clone(extra.pityValAdjustMetas),
--                     }
--                 }

--                 data.serverVersionedConfig.config = table.serialize( data.serverVersionedConfig.config )

--                 local toMgrData = {}
--                 toMgrData.userData = table.clone(data.data)
--                 toMgrData.endTime = math.floor(extra.periodInfo.endTs/1000) or 0
--                 toMgrData.mainEndTime = math.floor(extra.periodInfo.mainEndTs/1000) or 0
--                 toMgrData.mainBeginTime = math.floor(extra.periodInfo.mainBeginTs/1000) or 0
--                 toMgrData.beginTime = math.floor(extra.periodInfo.mainBeginTs/1000) or 0
--                 local dataConfig = table.clone(data.serverVersionedConfig)

--                 self:fromServer(toMgrData, dataConfig)
--             end
--         end
--     end
-- end

function SuperMagicBird2024Manager:onActActInfoUpdate(event)
    --同步最新后端内容
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(SuperMagicBird2024Manager.ACT_ID)]

    if fromServer then
        -- if self:isEnabled() then
            if actInfo then
                if actInfo.extra then
                    local extra = table.deserialize(actInfo.extra)

                    log("onActActInfoUpdate")
                    local bCanChangeData = self:checkCanUseActInfoData(extra)

                    if bCanChangeData then

                        if extra.payTag then
                            self:getData():setPayTag( extra.payTag )
                        end
                        
                        if extra.adjustInfo then
                            self:getData():updateAdjustInfo(extra.adjustInfo)
                        end

                        if extra.cycleInfo then
                            self:getData():updateCycleInfo(extra.cycleInfo)
                        end

                        if extra.adjustInfo2025 then
                            self:getData():updateCycleInfo2025(extra.adjustInfo2025)
                        end

                        if extra.maxWinStreakNums then
                            self:getData():setMaxWinStreakNums(extra.maxWinStreakNums)
                        end

                        if extra.breakVersion1 then
                            self:getData():updateBreakVersion1( extra.breakVersion1 )
                        end
                    end
                    self:getData():updateReviveCardInfo(extra.reviveCardInfo)
                end

                if self:isEnabled() and self:curTimeTopLevelIsEnabled() then
                    self:dcQualify()
                end
            end
        -- else
        --     if actInfo then
        --         self:firstInitActData(actInfo)
        --     end
        -- end
    end
end

-- function SuperMagicBird2024Manager:fromServer(data, config)
--     self:getData():fromSever(data, config)
-- end

function SuperMagicBird2024Manager:curTimeTopLevelIsEnabled()

    local isFMJ = _G.amfBean("UserStateManager"):isFMJ()
    if isFMJ then return true end

    --当前时间，头部关是否满足。 当前时间如果大于本地最高关开启时间7天，活动不开
    local newLevelOpenTime, countDownAreaId = _G.amfBean("LevelUnLockManager"):getLastOpenNewLevelTime()
    local diffTime = TimeKit:timeInSec() - newLevelOpenTime

    if EnvUtil:isDevelopMode() then
        log("检测新关解锁时间是否满足7日内", newLevelOpenTime, TimeKit:timeInSec(), diffTime, 60*60*24*7)
    end

    if diffTime >= 60*60*24*7 then
        return false
    end
    return true
end

function SuperMagicBird2024Manager:curTimeIsInNewLevelOpenTimeAndLevelIsNewLevel( levelId, levelScene )
    --当前时间是否在新关开启7日内，并且关卡是新关区间
    if not UBFLevelSceneFunc:isMainLevel(levelScene) then return false end

    local isFMJ = _G.amfBean("UserStateManager"):isFMJ()
    if not isFMJ then return false end

    local deltaTime = 60*60*24*7
    if _G.amfBean("LevelUnLockManager"):isInNewLevelTime(deltaTime) and _G.amfBean("LevelUnLockManager"):isTopNewMainLevel(levelId) then
        return true
    end

    return false
end

function SuperMagicBird2024Manager:getTrueTopLevelId()
    return _G.amfBean("LevelAreaManager"):getTopPassedMainLevelId() + 1
end

function SuperMagicBird2024Manager:getMinTopLevelId()
    if not self:isEnabled() then return Meta.bottomMostLevelConfig end
    -- local value = self:getData():getConfigByKey(Meta.minTopLevelId)
    local value = self:getData():getDataByKey(Meta.minTopLevelId)
    if not value then
        value = Meta.bottomMostLevelConfig
    end
    return value
end

-- 未激活状态下胜利数量
function SuperMagicBird2024Manager:getPassTopNums()
    if not self:isEnabled() then return 0 end
    local value = self:getData():getCycleInfoDataByKey(Meta.passTopNums)
    if not value then
        return 0
    end
    return value
end

-- 配置中激活魔力鸟需要胜利的局数
function SuperMagicBird2024Manager:getNeedWinNum()
    if not self:isEnabled() then return 0 end
    -- local winNum = self:getData():getConfigByKey(Meta.minTriggerLevelNums)
    local winNum = self:getData():getDataByKey(Meta.minTriggerLevelNums)
    if not winNum then
        return 8
    end
    return winNum
end

-- 是否已激活
function SuperMagicBird2024Manager:getAvailable()
    if not self:isEnabled() then return false end
    local type = self:getData():getCycleInfoDataByKey(Meta.type)
    if not type then
        type = 0
    end
    return type > 0
end

function SuperMagicBird2024Manager:hasRewards()
    if not self:isEnabled() then return false end
    return false
end

function SuperMagicBird2024Manager:hasSuperPower()
    if not self:isEnabled() then return false end
    local superPower = self:getAvailable()
    return superPower
end

function SuperMagicBird2024Manager:onActAutoStartLevelBackUser(evt)
    local data = evt:getData() or {}
    local callback = data.callback
    data.handled = true
    self.autoPopupMgr:removePopupConfig(PopupCheckPoint.SUPER_MAGIC_BIRD_REVIVE)
    self:markReviveCardDeliveryAutoPopConsumed()
    if not self:tryGetReviveCardReward(callback, callback, callback) then
        safeRunCall(callback)
    end
end

function SuperMagicBird2024Manager:getReviveCardInfo()
    return self:getData():getReviveCardInfo()
end

function SuperMagicBird2024Manager:isReviveCardFeatureEnabled()
    if not self:isEnabled() then return false end
    local reviveCardInfo = self:getReviveCardInfo()
    if not reviveCardInfo or not reviveCardInfo.beginTs or not reviveCardInfo.endTs then
        return false
    end

    local beginTime = TimeKit:tryConvertMsToSec(reviveCardInfo.beginTs)
    local endTime = TimeKit:tryConvertMsToSec(reviveCardInfo.endTs)
    local now = TimeKit:timeInSec()
    return beginTime ~= nil and endTime ~= nil and now >= beginTime and now < endTime
end

function SuperMagicBird2024Manager:hasTodayTimestamp(timestampList)
    local todayStart = TimeKit:getTodayStart()
    for _, timestamp in pairs(timestampList or {}) do
        local timestampInSec = TimeKit:tryConvertMsToSec(timestamp)
        if timestampInSec and TimeKit:getDayStartTimeByTS(timestampInSec) == todayStart then
            return true
        end
    end
    return false
end

function SuperMagicBird2024Manager:hasReviveCard()
    local reviveCardInfo = self:getReviveCardInfo()
    return reviveCardInfo ~= nil and self:hasTodayTimestamp(reviveCardInfo.rewardMs)
end

function SuperMagicBird2024Manager:hasReviveCardInBag()
    local userPropsManager = _G.amfBean("UserPropsManager")
    local reviveCardNum = tonumber(userPropsManager:getUserPropNumber(AMFPropId.SUPER_BIRD_REVIVE_CARD)) or 0
    return reviveCardNum > 0
end

function SuperMagicBird2024Manager:isReviveCardLastDay()
    local reviveCardInfo = self:getReviveCardInfo()
    if not reviveCardInfo or not reviveCardInfo.endTs then
        return false
    end

    local endTime = TimeKit:tryConvertMsToSec(reviveCardInfo.endTs)
    return TimeKit:getDayStartTimeByTS(endTime) == TimeKit:getTodayStart()
end

function SuperMagicBird2024Manager:canRewardReviveCardToday()
    return self:isReviveCardFeatureEnabled()
        and not self:hasReviveCard()
end

function SuperMagicBird2024Manager:tryGetReviveCardReward(successCallback, failCallback, cancelCallback)
    if not self:canRewardReviveCardToday() then
        return false
    end

    self:requestReviveCardReward(successCallback, failCallback, cancelCallback)
    return true
end

function SuperMagicBird2024Manager:canAccumulateChargeProgress()
    return not self:getAvailable() and self:getPassTopNums() < self:getNeedWinNum()
end

function SuperMagicBird2024Manager:canActivateReviveCard()
    return self:hasReviveCardInBag()
        and self:canAccumulateChargeProgress()
end

function SuperMagicBird2024Manager:getReviveCardSlpState(params)
    params = params or {}
    local reviveCardEnabled = self:isEnabled()
    local canAccumulate = self:canAccumulateChargeProgress()
        and self:isEnabledInLevel(params)
    local hasUsableCard = self:hasReviveCardInBag()
    local cardExpireAt = 0

    if hasUsableCard then
        cardExpireAt = TimeKit:getTodayStart() + SECONDS_PER_DAY
        local reviveCardInfo = self:getReviveCardInfo() or {}
        local activityExpireAt = tonumber(TimeKit:tryConvertMsToSec(reviveCardInfo.endTs)) or 0
        if activityExpireAt > 0 then
            cardExpireAt = math.min(cardExpireAt, activityExpireAt)
        end
        local now = TimeKit:timeInSec()
        if now >= cardExpireAt then
            hasUsableCard = false
            cardExpireAt = 0
        end
    end

    return {
        reviveCardEnabled = reviveCardEnabled,
        canAccumulate = canAccumulate,
        hasUsableCard = hasUsableCard,
        cardExpireAt = cardExpireAt,
        isSuperBirdActive = self:getAvailable() == true,
        currentProgress = self:getPassTopNums() or 0,
        maxProgress = self:getNeedWinNum() or 8,
    }
end

function SuperMagicBird2024Manager:onActDcStageCommon(event)
    if not event then return end

    local dcInfo = event:getData()
    if not dcInfo
        or dcInfo.category ~= "stage"
        or dcInfo.sub_category ~= "start_show"
    then
        return
    end

    local reviveCardState = self:getReviveCardSlpState({
        levelId = dcInfo.levelId or dcInfo.current_stage,
        levelScene = dcInfo.levelScene,
    })
    local entryMaintenanceName = EnvUtil:isMiniGameProject() and "superbird_mini" or "superbird_app"
    local entryEnabled = MaintenanceManager:getInstance():isEnabledInGroup(entryMaintenanceName, "ON")
        and not (dcInfo.t1 == 1 and dcInfo.t2 == 0)
    local hasUsableCard = reviveCardState and reviveCardState.hasUsableCard == true
    local showReviveCard = entryEnabled
        and hasUsableCard
        and reviveCardState.reviveCardEnabled == true
        and reviveCardState.canAccumulate == true
        and reviveCardState.isSuperBirdActive ~= true

    dcInfo.bird_status = showReviveCard and 1 or 0
    dcInfo.bird_reborn_cnt = hasUsableCard and 1 or 0
end

function SuperMagicBird2024Manager:addRewards(rewardItems, dcFeature, dcSource)
    _G.GainPropData:create()
    :setFeature(dcFeature)
    :setSource(dcSource)
    :setProps(rewardItems)
    :execute()
end

-- 激活后连胜数量
function SuperMagicBird2024Manager:getWinStreakNums()
    if self:getAvailable() then
        return self:getData():getCycleInfoDataByKey(Meta.winStreakNums)
    end
    return 0
end

-- 最高连胜数
function SuperMagicBird2024Manager:getMaxWinStreakNums()
    if self:getAvailable() then
        return self:getData():getMaxWinStreakNums()
    end
    return 0
end

function SuperMagicBird2024Manager:getPlugEndTime()
    local chargeConfig = self:getData():getChargeConfig()
    if not chargeConfig then
        return 0
    else
        return chargeConfig.endTs or 0
    end
end

function SuperMagicBird2024Manager:getPlugBeginTime()
    local chargeConfig = self:getData():getChargeConfig()
    if not chargeConfig then
        return 0
    else
        return chargeConfig.beginTs or 0
    end
end

function SuperMagicBird2024Manager:getChargeConfig()
    return self:getData():getChargeConfig()
end

function SuperMagicBird2024Manager:getChargeData()
    return self:getData():getChargeData()
end

function SuperMagicBird2024Manager:getDcFeatureAndSource(actId, suffix )
    return "bird_win", "get_reward"
end

function SuperMagicBird2024Manager:checkCurCanGuideCallbackProp()
    if self:getData():checkGuide( Meta.GuideIds.kGuideProp ) then
        return false
    else
        return self:getData():checkCurTimeCanGuideCallbackProp()
    end
end

function SuperMagicBird2024Manager:setCurGuideCallbackPropSucess()
    self:getData():setGuideIndex( Meta.GuideIds.kGuideProp)
end

-- dc
function SuperMagicBird2024Manager:dc(category, subCategory, t1, t2, t3, t4, extraData)
    local params = {
        game_type = "stage",
        game_name = SuperMagicBird2024Manager.GAME_NAME,
        category = category,
        sub_category = subCategory,
        t1 = t1,
        t2 = t2,
        t3 = t3,
        t4 = t4,
    }

    for i, v in pairs(extraData or {}) do
        params[i] = v
    end
    DcUtil:dcForUserTrack(params)
end

function SuperMagicBird2024Manager:dcCanyuDaily(subCategory, localKey)
    if self:getFlagFromLocalByKey(localKey, true) then return end

    self:saveFlagToLocalByKey(localKey, true)
    self:dc("canyu", subCategory, nil, nil, nil, nil, {
        actid = SuperMagicBird2024Manager.ACT_ID,
    })
end

function SuperMagicBird2024Manager:dcQualify()
    self:dcCanyuDaily("qualify", Meta.dcQualifyDaily)
end

function SuperMagicBird2024Manager:dcJoin()
    self:dcCanyuDaily("join", Meta.dcJoinDaily)
end

function SuperMagicBird2024Manager:JumpFlyToAnimation(config)
	if not config.sprites or #config.sprites <= 0 or not config.duration or config.duration <= 0 then return end
	config.delayTime = config.delayTime or 0
	config.dstPosition = config.dstPosition or ccp(0, 0)
	config.height = config.height or 100
	local counter = #config.sprites
	local time = 0
	for k, v in ipairs(config.sprites) do
		local position = v:getPosition()
		local parent = v:getParent()

		local sequence = CCArray:create()
		if config.easeIn and counter > 1 then
			sequence:addObject(CCDelayTime:create(time))
			time = time + math.cos((k - 1) / (counter - 1) * math.pi / 2) * config.delayTime
		else
			sequence:addObject(CCDelayTime:create(config.delayTime * (k - 1)))
		end
		local function onStart() if config.startCallback then config.startCallback(v) end end
		sequence:addObject(CCCallFunc:create(onStart))
		local spawn = CCArray:create()
		local inPosition = parent:convertToNodeSpace(config.dstPosition)

		spawn:addObject(CCEaseBackIn:create(CCMoveBy:create(config.duration, ccp(0, inPosition.y - position.y))))
		spawn:addObject(CCMoveBy:create(config.duration, ccp(inPosition.x - position.x, 0)))
		if config.dstSize then
			local size = v:getGroupBounds().size
            spawn:addObject(CCScaleBy:create(config.duration, config.dstSize.width / size.width, config.dstSize.height / size.height))
		end
		if config.extendAction then
			local extendActionCopy = config.extendAction:copy()
			spawn:addObject(extendActionCopy) 
			extendActionCopy:release()
		end
		sequence:addObject(CCSpawn:create(spawn))
		local function onReach()
			counter = counter - 1
			if config.reachCallback then config.reachCallback(v) end
			if counter == 0 and config.finishCallback then config.finishCallback() end
		end
		sequence:addObject(CCCallFunc:create(onReach))
		
		v:runAction(CCSequence:create(sequence))
	end
end

function SuperMagicBird2024Manager:flyTo(config)
    self:JumpFlyToAnimation(config)
end

function SuperMagicBird2024Manager:jumpFlyTo(config)
    self:JumpFlyToAnimation(config)
end

function SuperMagicBird2024Manager:isEnabled()
    if not self:getData():isSmbEnabled() then return false end
    return true
end

--- @deprecated
function SuperMagicBird2024Manager:isEnabled2()
    return self:isEnabled()
end

-- function SuperMagicBird2024Manager:getShowMsgNum()
--     return 0
-- end

-- function SuperMagicBird2024Manager:getActivityIcon()
-- end

-- function SuperMagicBird2024Manager:updateTipView(actInfo)
-- end

-- function SuperMagicBird2024Manager:getEndTime()
--     return self:getData():getEndTime()
-- end

-- function SuperMagicBird2024Manager:getStartTime()
--     return self:getData():getMainBeginTime()
-- end

function SuperMagicBird2024Manager:getRealBeginTime()
    local data = self:getData()
    if not data then return 0 end

    return self:getData():getValue('beginTime') or 0
end

-- 本地缓存 bool
function SuperMagicBird2024Manager:saveFlagToLocalByKey(key, needTime, value, needActStartTimeCheck)
    if value == nil then value = true end
    self:setLocalValueByKey( key, needTime, value, needActStartTimeCheck )
end

function SuperMagicBird2024Manager:getFlagFromLocalByKey(key, needTime, needActStartTimeCheck)
	local defaultValue = false
    local result = self:getLocalValueByKey(key, needTime, needActStartTimeCheck)
    if result == nil then 
    	return defaultValue
    else
    	return result
    end
end

-- 本地缓存int
function SuperMagicBird2024Manager:saveFlagToLocalByKeyInt(key, needTime, value, needActStartTimeCheck)
	if value == nil then value = 0 end
    self:setLocalValueByKey( key, needTime, value, needActStartTimeCheck )
end

function SuperMagicBird2024Manager:getFlagFromLocalByKeyInt(key, needTime, needActStartTimeCheck, defaultValue)
	if defaultValue == nil then defaultValue = 0 end

    local result = self:getLocalValueByKey(key, needTime, needActStartTimeCheck)
    if result == nil then 
    	return defaultValue
    else
    	return result
    end
end


function SuperMagicBird2024Manager:setLocalValueByKey(key, needTime, value, needActStartTimeCheck)
    if not key then return end
    -- if bSkip == nil then bSkip = true end

    local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())
    local actBeginTime = self:getRealBeginTime() or 0

    local saveValue = {
    	time = nowTime,
    	value = value,
    	actBeginTime = actBeginTime,
    }
    local saveStr = table.serialize(saveValue)

    self:getData():setValue(key, saveStr, true)
end

function SuperMagicBird2024Manager:getLocalValueByKey(key, needTime, needActStartTimeCheck)
    if not key then return end
    local saveJsonStr = self:getData():getValue(key)
    if saveJsonStr == nil then return end
    if type(saveJsonStr) ~= "string" then return end

    local saveTable = table.deserialize(saveJsonStr)

    local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())
    local actBeginTime = self:getRealBeginTime() or 0

    local bTimeIsOk = true
    if needTime then
    	if saveTable.time ~= nowTime then
    		bTimeIsOk = false
    	end
    end

    local versionIsOk = true
    if needActStartTimeCheck then
    	if saveTable.actBeginTime ~= actBeginTime then
    		versionIsOk = false
    	end
    end

    if bTimeIsOk and versionIsOk then
    	return saveTable.value
    end
end

function SuperMagicBird2024Manager:openMainActivity(closeCallback, extra, userClick, duanMianData)
    local function getActDataSuccess()
        local scene = Director:sharedDirector():run()
        if scene == nil or not scene:isScene("MainScene") then
            return
        end

        if not self:curTimeTopLevelIsEnabled() then
            self:popNeedUpdateLevelTip(closeCallback)
            return
        end

        if not extra then
            extra = {}
        end

        local hasStartPanelContext = type(extra.closeSlpCallback) == "function"
            and extra.levelId ~= nil
            and extra.levelScene ~= nil

        local delegate = {
            closeCallback = closeCallback,
            extra = extra,
            resumeData = duanMianData,
            userClick = userClick,
        }

        if hasStartPanelContext and self:canActivateReviveCard() then
            local closeSlpCallback = extra.closeSlpCallback
            extra.closeSlpCallback = nil
            safeRunCall(closeSlpCallback)
            self:openReviveConfirmPanel({
                isRetryPanel = extra.isRetryPanel == true,
                closeCallback = function(activateSucceeded)
                    if activateSucceeded then
                        safeRunCall(delegate.closeCallback)
                        local playLevelContext = PlayLevelContext.new(extra.levelId, PlayLevelContext.PlayType.OPEN_SL_PANEL)
                        playLevelContext:setLevelScene(extra.levelScene)
                        _G.amfTransaction(TransactionEvent.PLAY_LEVEL, playLevelContext)
                    else
                        self:openMainPanel(delegate)
                    end
                end,
            })
            return
        end

        -- 未激活但是已经进度条满了
        if not extra.closePopOut and not self:getAvailable() and self:getPassTopNums() >= self:getNeedWinNum() then
            local successCallback = function()
                self:openMainPanel(delegate, config)
            end
            local failCallback = function()
                self:openMainPanel(delegate, config)
            end
            self:requestActivate(successCallback, failCallback, failCallback)
            return
        end
        self:openMainPanel(delegate, config)
    end

    getActDataSuccess()
    -- self:getInfoAsync(getActDataSuccess, function() safeRunCall(endCallback) end, function() safeRunCall(endCallback) end, false, userClick)
end

function SuperMagicBird2024Manager:openMainPanel(delegate)
    -- self:refreshIconProgress()

    if not delegate then
        delegate = {}
    end

    local mainPanelClass = require("amf.feature.localactivity.supermagicbird.views.MainPanelVM")
    if not mainPanelClass then
        safeRunCall(delegate.closeCallback)
        return
    end

    if delegate.userClick then
        delegate.t1 = 1
    else
        delegate.t1 = 2
    end
    
    if delegate and delegate.extra and delegate.extra.closePopOut then
        delegate.closePopOut = delegate.extra.closePopOut
    else
        delegate.closePopOut = false
    end

    local mainPanel = mainPanelClass:create(delegate)
    mainPanel:popout()
    self.panelPlug:managePanelVM(mainPanel)
end

function SuperMagicBird2024Manager:openReviveConfirmPanel(delegate)
    local panelClass = require("amf.feature.localactivity.supermagicbird.views.ReviveConfirmPanelVM")
    local panel = panelClass:create(delegate or {})
    panel:popout()
    self.panelPlug:managePanelVM(panel)
end

function SuperMagicBird2024Manager:getPityValAdjustMetas( )
    if not self:isEnabled() then
        return false, {}
    end

    local pityValAdjustMetas = self:getData():getPityValAdjustMetas()
    return true, pityValAdjustMetas
end

return SuperMagicBird2024Manager
