local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
require "amf.middleware.autopop.config.AutoPopupConst"
require "amf.middleware.ui.UICreateUtil"
local PetConfig = require "amf.feature.localactivity.pet.config.PetConfig"
local PetEvent = require "amf.feature.localactivity.pet.event.PetEvent"
local PetEventCenter = require "amf.feature.localactivity.pet.event.PetEventCenter"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local IconV2Experiment = require "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"
local PetManager = class("PetManager", BaseFeatureManager)

PetManager.IconAction = PetEvent.IconAction
local PETIT_PET_CLICK_COUNT_OP_NAME = "PetitPetClickCount"
local WING_AUTO_POP_MAIN_INFO_WAIT_TIMEOUT = 5
local PetDecoInLevelSkinConfig
local DecoTypeEnterReason = {
    FEATURE_CLOSED = "feature_closed",
    INACTIVE = "inactive",
}

local function getPetDecoInLevelSkinConfig()
    if not PetDecoInLevelSkinConfig then
        PetDecoInLevelSkinConfig = require(PetConfig.LOCAL_PATH .. ".config.PetDecoInLevelSkinConfig")
    end
    return PetDecoInLevelSkinConfig
end
local IconPriority = {
    [PetConfig.IconMode.VineCorner] = 100197,
    [PetConfig.IconMode.LeftSidePool] = 110700,
}

local function isDataDrivenIcon(icon)
    return icon and not icon.isDisposed and type(icon.refreshProvider) == "function"
end

local function normalizeTimestampInSec(value)
    local timestamp = tonumber(value) or 0
    if timestamp >= 100000000000 then
        return timestamp / 1000
    end
    return timestamp
end

local function buildActivityTimeInfo(source)
    source = source or {}
    return {
        beginTime = source.periodBeginTime,
        mainBeginTime = source.periodMainBeginTime,
        mainEndTime = source.periodMainEndTime,
        endTime = source.periodEndTime,
    }
end

function PetManager:_init()
    self:callDownloadFunc("startDownload", function()
        UICreateUtil:loadPlist(PetConfig.petDecoProp.atlas)
    end)
    self._dc = require(self:_getDCPath())
    self._hasSyncedMainInfo = false
    self:callActFunc("registerActInfoUpdate", "onActInfoUpdate")
    self.iconMode = PetConfig.IconMode.LeftSidePool
    self._hasResolvedActIconMode = false
    self._hasSeenHolidayLinkActInfo = false
    self._iconV2NotificationCycle = nil
end

function PetManager:_log(...)
    if not self:_isLogEnabled() then return end
    UBFLogN(11, "[PetitPet-PetMgr]", ...)
end

function PetManager:_isLogEnabled()
    --
--
--

    return _G.debugSwitch and _G.debugSwitch.petitPetLogForceOpened == true
end

function PetManager:_getExtraPlugsConfigList()
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
            key = "AutoPop",
        },
        {
            key = "ActSent",
            path = {
                plugPath = PetConfig.LOCAL_PATH .. ".plug.PetActSentPlug",
                const = self:_getConstPath(),
            },
        },
    }
end

function PetManager:setAutoPopupMgr(manager)
    self.autoPopupMgr = manager
end

function PetManager:getMainPanelAutoPopupKey()
    return PopupCheckPoint.PET_MAIN_POP_STAGE_2
end

function PetManager:_isWingAutoPopAvailable()
    local model = self:getModel()
    local hasAutoPopupMgr = self.autoPopupMgr ~= nil
    local dataEnabled = model:isDataEnabled()
    local activityOpen = model:isOpen()
    local clientVersionMatch = model:isClientVersionMatch()
    local activityEnabled = dataEnabled and activityOpen and clientVersionMatch
    local wingFeatureEnabled = self:isWingFeatureEnabled()
    local available = hasAutoPopupMgr
        and activityEnabled
        and wingFeatureEnabled
    return available
end

function PetManager:_isCurrentWingTransition(fromActivated, toActivated, frequencyContext)
    local transition = frequencyContext.transition
    if type(transition) ~= "table" then return false end
    if tonumber(transition.serverDay) ~= tonumber(frequencyContext.serverDay) then return false end
    return transition.fromActivated == fromActivated and transition.toActivated == toActivated
end

function PetManager:_canPlayWingDailyProgressAnimation(frequencyContext)
    if self:hasConsumedWingDailyProgressAnimation(frequencyContext.serverDay) then return false end

    local progress = self:getWingProgress()
    progress = type(progress) == "table" and progress or {}
    local continuousLoginDays = math.max(0, tonumber(progress.continuousLoginDays) or 0)
    local unlockedDays = math.max(0, tonumber(progress.unlockProgressDays) or 0)
    local remainingDays = math.max(0, tonumber(progress.needUnlockDays) or 0)
    local totalDays = unlockedDays + remainingDays
    local progressAnimationEligible = continuousLoginDays > 0
        and totalDays > 0
        and continuousLoginDays <= totalDays
    if not progressAnimationEligible then return false end

    return not self:isWingActivated() or continuousLoginDays >= totalDays
end

function PetManager:_selectStageTwoWingAutoPop(frequencyContext)
    local model = self:getModel()
    if model:hasShownWingPanel(frequencyContext.serverDay) then return nil end

    local activated = self:isWingActivated()
    local isActivationTransition = activated
        and self:_isCurrentWingTransition(false, true, frequencyContext)
    if activated and not isActivationTransition then return nil end
    if self._hasSyncedMainInfo
        and not isActivationTransition
        and not self:_canPlayWingDailyProgressAnimation(frequencyContext)
    then
        return nil
    end

    if not activated then
        return {
            scene = 2,
            candidate = PetConfig.WingAutoPopCandidate.PENDING_ACTIVATION,
            displayMode = PetConfig.WingDisplayMode.PENDING_ACTIVATION,
        }
    end

    if not self:hasGuideId(PetConfig.WingAutoPop.GUIDE_ID) then
        return {
            scene = 2,
            candidate = PetConfig.WingAutoPopCandidate.FIRST_ACTIVATION_GUIDE,
            displayMode = PetConfig.WingDisplayMode.FIRST_ACTIVATION_GUIDE,
        }
    end

    return {
        scene = 2,
        candidate = PetConfig.WingAutoPopCandidate.ACTIVATION_TRANSITION,
        displayMode = PetConfig.WingDisplayMode.ACTIVATION_TRANSITION,
    }
end

function PetManager:_selectStageFourWingAutoPop(frequencyContext)
    local candidate = self:_selectStageTwoWingAutoPop(frequencyContext)
    if not candidate then return nil end

    candidate.scene = 4
    return candidate
end

function PetManager:selectWingAutoPopCandidate(scene)
    if not self:_isWingAutoPopAvailable() then
        return nil
    end

    local frequencyContext = self:getWingFrequencyContext()
    if type(frequencyContext) ~= "table" then
        return nil
    end
    if scene == 2 then
        return self:_selectStageTwoWingAutoPop(frequencyContext)
    end
    if scene == 4 then
        return self:_selectStageFourWingAutoPop(frequencyContext)
    end
end

function PetManager:_isWingAutoPopCandidateValid(candidate)
    if type(candidate) ~= "table" then return false end
    local currentCandidate = self:selectWingAutoPopCandidate(candidate.scene)
    return currentCandidate ~= nil and currentCandidate.candidate == candidate.candidate
end

function PetManager:_dispatchWingAutoPopResult(candidate, result, reason)
    PetEventCenter:dispatch(PetEvent.WING_AUTOPOP_RESULT, {
        scene = candidate and candidate.scene,
        candidate = candidate and candidate.candidate,
        displayMode = candidate and candidate.displayMode,
        result = result,
        reason = reason,
    })
end

function PetManager:openWingAutoPop(candidate, onPopOver)
    local completed = false
    local shown = false
    local completionReason = "panel_not_shown"

    local function finish()
        if completed then return end
        completed = true
        self:_dispatchWingAutoPopResult(candidate, shown and "shown" or "failed", completionReason)
        safeRunCall(onPopOver, shown)
    end

    local function onWingAutoPopShown(displayMode)
        if completed or shown or displayMode ~= candidate.displayMode then
            if displayMode ~= candidate.displayMode then
                completionReason = "display_mode_mismatch"
            end
            return
        end
        shown = true
        completionReason = "panel_closed"
    end

    local function canOpenPanel()
        if not self:_isWingAutoPopCandidateValid(candidate) then
            completionReason = "candidate_invalid"
            return false
        end
        return true
    end

    local function openPanel()
        local currentCandidate = self:selectWingAutoPopCandidate(candidate.scene)
        if not currentCandidate then
            completionReason = "candidate_invalid"
            finish()
            return
        end
        candidate = currentCandidate
        self:openActivity(finish, {
            targetPanel = PetConfig.WingAutoPop.TARGET_PANEL,
            wingDisplayMode = candidate.displayMode,
            openReason = PetConfig.WingAutoPop.OPEN_REASON,
            onWingAutoPopShown = onWingAutoPopShown,
            mainInfoReady = true,
            canOpen = canOpenPanel,
        }, false)
    end

    if self._hasSyncedMainInfo then
        openPanel()
        return
    end

    local pending = { open = openPanel }
    pending.timeout = TimerUtil.addAlarm(function()
        if self._pendingWingAutoPopOpen ~= pending then return end
        self._pendingWingAutoPopOpen = nil
        completionReason = "main_info_wait_timeout"
        finish()
    end, WING_AUTO_POP_MAIN_INFO_WAIT_TIMEOUT, 1)
    self._pendingWingAutoPopOpen = pending
end

function PetManager:checkPopFunctionStage4()
    return self:selectWingAutoPopCandidate(4) ~= nil or self:_canFallbackToMainPanelAutoPop()
end

function PetManager:popFunctionStage4(onHandleOver)
    local candidate = self:selectWingAutoPopCandidate(4)
    if not candidate then
        self:_fallbackToMainPanelAutoPop(onHandleOver)
        return
    end
    self:openWingAutoPop(candidate, function(shown)
        if shown then
            safeRunCall(onHandleOver)
            return
        end
        self:_fallbackToMainPanelAutoPop(onHandleOver)
    end)
end

function PetManager:_canFallbackToMainPanelAutoPop()
    if not self.autoPopupMgr then return false end
    if self:getEndTime() - TimeKit:timeInSec() <= 60 then return false end

    local frequencyContext = self:getWingFrequencyContext()
    if type(frequencyContext) == "table"
        and self:getModel():hasShownMainPanel(frequencyContext.serverDay)
    then
        return false
    end

    local participationMgr = _G.amfBean("ActivityParticipationMgr")
    if participationMgr and participationMgr.shouldReduceConfiguredMainPanelAutoPopup
        and participationMgr:shouldReduceConfiguredMainPanelAutoPopup(self:getConst().actId)
    then
        return false
    end
    return true
end

function PetManager:_fallbackToMainPanelAutoPop(onHandleOver)
    if not self:_canFallbackToMainPanelAutoPop() then
        safeRunCall(onHandleOver)
        return
    end

    self:openActivity(onHandleOver, nil, false)
    self.autoPopupMgr:resetPopup()
end

function PetManager:_getAutoPopConfigList()
    local PopStage = AutoPopupConst.PopStage
    return {
        {
            checkPoint = self:getMainPanelAutoPopupKey(),
            stages = { PopStage.STAGE_TWO },
            check = function()
                local candidate = self:selectWingAutoPopCandidate(2)
                return candidate ~= nil
            end,
            creator = function(_, onPopOver)
                local candidate = self:selectWingAutoPopCandidate(2)
                return function()
                    self:openWingAutoPop(candidate, onPopOver)
                end
            end,
        },
    }
end

function PetManager:markWingPanelShownToday()
    local frequencyContext = self:getWingFrequencyContext()
    self:getModel():markWingPanelShown(frequencyContext.serverDay)
end

function PetManager:markMainPanelShownToday()
    local frequencyContext = self:getWingFrequencyContext()
    self:getModel():markMainPanelShown(frequencyContext.serverDay)
end

function PetManager:hasConsumedWingDailyProgressAnimation(serverDay)
    return self:getModel():hasConsumedWingDailyProgressAnimation(serverDay)
end

function PetManager:markWingDailyProgressAnimationConsumed(serverDay)
    self:getModel():markWingDailyProgressAnimationConsumed(serverDay)
end

function PetManager:_getModelPath()
    return PetConfig.LOCAL_PATH .. ".model.PetModel"
end

function PetManager:_getConstPath()
    return PetConfig.LOCAL_PATH .. ".config.PetConfig"
end

function PetManager:_getDCPath()
    return PetConfig.LOCAL_PATH .. ".dc.PetDC"
end

function PetManager:getDC()
    return self._dc
end

function PetManager:dcQualify()
    self:getDC():dcQualify(self)
end

function PetManager:_hasPetInLevelSkinTestData()
    --
--
--
--
--
--
--
--
--
--

    local data = _G.__PetInLevelSkinTestData
    if type(data) ~= "table" then
        return false
    end
    if data.petActive ~= nil then
        return true
    end
    return type(data.wearingDecos) == "table" and not table.isEmpty(data.wearingDecos)
end

function PetManager:isEnabled()
    --
--
--
--

    if not self._hasSyncedMainInfo then
        return false
    end
    return self:getModel():isDataEnabled() 
        and self:getModel():isOpen() 
        and self:getModel():isClientVersionMatch()
end


function PetManager:getActIconMode(fromIcon)
    if fromIcon then
        self._lastIconMode = self.iconMode
    end
    return self.iconMode
end

function PetManager:canUseDataDrivenIcon()
    return self._hasResolvedActIconMode == true
        and self:getActIconMode() == PetConfig.IconMode.LeftSidePool
end

function PetManager:getActIconPriority(mode)
    return IconPriority[mode or self:getActIconMode()] or IconPriority[PetConfig.IconMode.LeftSidePool]
end

function PetManager:_hasHolidayLinkAct(actInfos)
    if self._hasSeenHolidayLinkActInfo then
        return true
    end

    local activityMgr = _G.amfBean("ActivityMgr")
    if activityMgr and activityMgr.getActInfo and activityMgr:getActInfo(6073) then
        self._hasSeenHolidayLinkActInfo = true
        return true
    end

    if actInfos and actInfos[tostring(6073)] ~= nil then
        self._hasSeenHolidayLinkActInfo = true
        return true
    end

    return false
end

function PetManager:refreshActIconMode(actInfos)
    if self:_hasHolidayLinkAct(actInfos) then
        self.iconMode = PetConfig.IconMode.LeftSidePool
    else
        self.iconMode = PetConfig.IconMode.VineCorner
    end
    self._hasResolvedActIconMode = true
end

function PetManager:_rebuildIconIfModeChanged()
    local curMode = self:getActIconMode()
    local icon = self:getActivityIcon()
    local iconMode = icon and not icon.isDisposed and (icon.iconInfoMode or icon.iconMode)
    if self._lastIconMode == curMode and iconMode == curMode then return false end
    self._lastIconMode = curMode
    if isDataDrivenIcon(icon) then
        ActivityEventCenter:dispatch(ActivityEvent.REBUILD_ACTIVITY_ICON, {
            actId = self:getConst().actId,
        })
    else
        self:notifyActivityIconChange(PetManager.IconAction.Rebuild)
    end
    return true
end

function PetManager:_getActId()
    return self:getConst().actId
end

function PetManager:notifyActivityIconChange(action, extra)
    local data = extra and table.clone(extra, true) or {}
    data.action = action
    PetEventCenter:dispatch(PetEvent.PET_ICON_CHANGE, data)
end

function PetManager:rebuildActivityIcon()
    self:notifyActivityIconChange(PetManager.IconAction.Rebuild)
end

function PetManager:removeActivityIcon()
    local icon = self:getActivityIcon()
    if isDataDrivenIcon(icon) then
        local removed, removeError = icon:removeFromUI()
        if removed == false then
            return false, removeError
        end
        local disposed, disposeError = icon:dispose()
        if disposed == false then
            return false, disposeError
        end
        self:clearActivityIcon(icon)
        return true
    end
    self:notifyActivityIconChange(PetManager.IconAction.Remove)
end

function PetManager:getCurrentFoodId()
    return self:getConst().defaultFeedItemId
end

function PetManager:getDataByKey(key, default, copyTable)
    return self:getModel():getDataByKey(key, default, copyTable)
end

function PetManager:setDataByKey(key, value)
    if key == PetConfig.DeprecatedDataKey.WEARING_DECOS then
        return self:getModel():updateWearingDecos(value)
    end
    return self:getModel():setDataByKey(key, value)
end

function PetManager:getConfigByKey(key, default, copyTable)
    return self:getModel():getConfigByKey(key, default, copyTable)
end

function PetManager:_refreshOrRetryActivityIcon()
    if self:getActivityIcon() then
        self:updateIconState()
        return
    end
    if not IconV2Experiment:isEnabled() then return end
    if not self:canUseDataDrivenIcon() then return end
    if not self:isEnabled() then return end

    ActivityEventCenter:dispatch(ActivityEvent.REBUILD_ACTIVITY_ICON, {
        actId = self:getConst().actId,
    })
end

function PetManager:updateMainInfo(ret, init)
    self._hasSyncedMainInfo = true
    self:getModel():updateMainInfo(ret, init)
    self:getModel():updateTimeInfo(buildActivityTimeInfo(ret))
    local pending = self._pendingWingAutoPopOpen
    if pending then
        self._pendingWingAutoPopOpen = nil
        if pending.timeout then
            TimerUtil.removeAlarm(pending.timeout)
        end
        setTimeOut(pending.open, 0)
    end

    self:_refreshOrRetryActivityIcon()
end

function PetManager:installServerPayload(source, payload)
    self:getModel():installServerPayload(source, payload)
    if source == PetConfig.ServerPayloadSource.PET_ACTIVITY_INFO then
        self._hasSyncedMainInfo = true
        self:_refreshOrRetryActivityIcon()
    end
end

function PetManager:applyPurchaseOptimisticActivation()
    self:getModel():applyPurchaseOptimisticActivation()
end

function PetManager:getWingFreshness()
    return self:getModel():getFreshness()
end

function PetManager:registerMainInfoRefreshHandler(handler)
    self._mainInfoRefreshHandler = handler
end

function PetManager:unregisterMainInfoRefreshHandler(handler)
    if self._mainInfoRefreshHandler ~= handler then return end
    self._mainInfoRefreshHandler = nil
end

function PetManager:refreshMainInfo(options, callback)
    if not self._mainInfoRefreshHandler then
        safeRunCall(callback, false)
        return
    end
    return self._mainInfoRefreshHandler(options, callback)
end

function PetManager:isWingFeatureEnabled(currentTime)
    return self:getModel():isWingFeatureEnabled(currentTime)
end

function PetManager:getWingFeatureTiming(currentTime)
    return self:getModel():getWingFeatureTiming(currentTime)
end

function PetManager:isWingActivated()
    return self:getModel():isWingActivated()
end

function PetManager:isWingEffective(currentTime)
    return self:getModel():isWingEffective(currentTime)
end

function PetManager:getWingProgress()
    return self:getModel():getWingProgress()
end

function PetManager:getWingPackageData()
    return self:getModel():getPackageData()
end

function PetManager:getEnabledDecoMap()
    return self:getModel():getEnabledDecoMap()
end

function PetManager:canEnterDecoType(partType)
    local realPartType = tonumber(partType) or partType
    if realPartType == PetConfig.DecoPartType.Wing and not self:isWingFeatureEnabled() then
        return false, DecoTypeEnterReason.FEATURE_CLOSED
    end

    local enableDecos = self:getEnabledDecoMap()
    local decoInfo = enableDecos[realPartType] or enableDecos[tostring(realPartType)]
    if type(decoInfo) ~= "table" or decoInfo.enable ~= true then
        return false, DecoTypeEnterReason.INACTIVE
    end
    return true
end

function PetManager:getVisibleDecoMap()
    local result = {}
    for partType, decoInfo in pairs(self:getEnabledDecoMap()) do
        local realPartType = tonumber(partType) or partType
        local itemId = type(decoInfo) == "table" and tonumber(decoInfo.itemId) or nil
        local canEnter = self:canEnterDecoType(realPartType)
        if canEnter and itemId and itemId > 0 then
            result[realPartType] = itemId
        end
    end
    return self:resolveSupportedWearingDecos(result)
end

function PetManager:isPetDecoSupported(itemId)
    return getPetDecoInLevelSkinConfig().isDecoSupported(itemId)
end

function PetManager:resolveSupportedWearingDecos(wearingDecos)
    local resolvedWearingDecos, didFallback = getPetDecoInLevelSkinConfig().resolveWearingDecos(wearingDecos)
    if didFallback then
        return resolvedWearingDecos
    end
    return wearingDecos
end

function PetManager:getWingTransition()
    return self:getModel():getWingTransition()
end

function PetManager:getWingFrequencyContext()
    return self:getModel():getWingFrequencyContext()
end

function PetManager:updateFeedData(data)
    return self:getModel():updateFeedData(data)
end

function PetManager:updateClaimRewardData(data)
    return self:getModel():updateClaimRewardData(data)
end

function PetManager:_updateWearingDecoAndRefreshIconV2(partType, decoId)
    local updated = self:getModel():updateWearingDeco(partType, decoId)
    if updated and isDataDrivenIcon(self:getActivityIcon()) then
        self:updateIconState()
    end
    return updated
end

function PetManager:updateWearingDeco(partType, decoId)
    return self:_updateWearingDecoAndRefreshIconV2(partType, decoId)
end

function PetManager:updateWearDeco(partType, decoId)
    return self:_updateWearingDecoAndRefreshIconV2(partType, decoId)
end

function PetManager:updateChooseDress(partType, decoId)
    return self:_updateWearingDecoAndRefreshIconV2(partType, decoId)
end

function PetManager:updateSetting(key, value)
    return self:getModel():updateSetting(key, value)
end

function PetManager:updateChangeSetting(key, value)
    return self:getModel():updateSetting(key, value)
end

function PetManager:updateGuideData(data)
    return self:getModel():updateGuideData(data)
end

function PetManager:hasGuideId(guideId)
    return self:getModel():hasGuideId(guideId)
end

function PetManager:addGuideId(guideId)
    self:getModel():addGuideId(guideId)

    local ActCommonHttp = require "amf.middleware.activity.http.ActCommonHttp"
    ActCommonHttp:setActGuideFlag(self:getConst().actId, guideId, true)
end

function PetManager:_addRewardsNormal(rewardItems, params, extraMap)
    if table.isEmpty(rewardItems) then return end
    self:callPlug("Rewards", "addRewardsNormal", rewardItems, {
        dcExtra = params,
        extraMap = extraMap,
    })
end

function PetManager:addRewards(rewardItems, params, extraMap)
    if type(rewardItems) ~= "table" then return end

    local normalRewards = {}
    local decoRewards = {}
    for _, reward in ipairs(rewardItems) do
        local target = PetConfig.petDecoProp.isValid(reward and reward.itemId) and decoRewards or normalRewards
        target[#target + 1] = reward
    end

    self:_addRewardsNormal(normalRewards, params, extraMap)
    if not table.isEmpty(decoRewards) then
        self:getModel():addDecoRewards(decoRewards)
        self:getDC():dcGainDeco(decoRewards)
    end
end

function PetManager:addRewardsNormal(rewardItems, params, extraMap)
    return self:addRewards(rewardItems, params, extraMap)
end

function PetManager:markDecoViewed(decoId)
    return self:getModel():markDecoViewed(decoId)
end

function PetManager:getMainEndTime()
    return self:getModel():getMainEndTime()
end

function PetManager:getEndTime()
    return self:getModel():getEndTime()
end

function PetManager:getActivityTimeInfoInSec()
    local model = self:getModel()
    return {
        beginTime = normalizeTimestampInSec(model:getBeginTime()),
        mainBeginTime = normalizeTimestampInSec(model:getMainBeginTime()),
        mainEndTime = normalizeTimestampInSec(model:getMainEndTime()),
        endTime = normalizeTimestampInSec(model:getEndTime()),
    }
end

function PetManager:isInPreheatTime()
    return self:getModel():isInPreheatTime()
end

function PetManager:isInMainTime()
    return self:getModel():isInMainTime()
end

function PetManager:isInRewardTime()
    return self:getModel():isInRewardTime()
end

function PetManager:hasReward()
    return self:getModel():hasReward()
end

function PetManager:getMsgNum()
    return self:getFoodNum() or 0
end

function PetManager:openActivity(closeCallback, extra, userClick)
    self:callActFunc("openActivity", {
        failCallback = closeCallback,
        endCallback = closeCallback,
        extra = extra,
        userClick = userClick ~= false,
    })
end

function PetManager:isFoodNumEnough()
    return self:getModel():isFoodNumEnough()
end

function PetManager:clearData()
    self:getModel():clearLocalData()
    self:getModel():flush()
end

function PetManager:onActInfoUpdate(evt)
    local data = evt:getData()
    local actInfos = data.actInfos or {}
    local actInfo = actInfos[tostring(self:getConst().actId)]
    if not actInfo then
        return
    end
    
    self:refreshActIconMode(actInfos)

    local extra = table.deserialize(actInfo.extra)
    if extra then
        if extra.noHugeBuffData then
            self:updateNoHugeBuffData(extra.noHugeBuffData)
        end

        if extra.noHugeBuffConfig then
            self:setConfigByKey("noHugeBuffConfig", extra.noHugeBuffConfig)
        end
        self:getModel():setClientVersion(extra.clientVersion or 1)
        self:getModel():updateTimeInfo(buildActivityTimeInfo(extra))
        self:installServerPayload(PetConfig.ServerPayloadSource.GET_ACT_INFO, {
            enableDecos = extra.enableDecos,
            wingBeginTs = extra.wingBeginTs,
            wingEndTs = extra.wingEndTs,
        })
    end

    self:updateIconState()
end

function PetManager:getConstClientVersion()
    return self:getConst().clientVersion
end

function PetManager:updateIconState()
    if self:_rebuildIconIfModeChanged() then return end
    local icon = self:getActivityIcon()
    if isDataDrivenIcon(icon) then
        icon:refreshProvider("petStateChanged", {
            actId = self:getConst().actId,
        })
    else
        self:notifyActivityIconChange(PetManager.IconAction.Update)
    end
    if icon and not isDataDrivenIcon(icon) then
        icon:updateState()
    end
end

function PetManager:getActivityIcon()
    if self._activityIcon and not self._activityIcon.isDisposed then
        return self._activityIcon
    end
    return self:callActFunc("getActIcon")
end

function PetManager:setActivityIcon(icon)
    self._activityIcon = icon
end

function PetManager:clearActivityIcon(icon)
    if not icon or self._activityIcon == icon then
        self._activityIcon = nil
    end
end

function PetManager:onIconV2Mounted()
    local icon = self:callActFunc("getActIcon")
    if icon and not icon.isDisposed then
        self:setActivityIcon(icon)
    end
    local dc = self:getDC()
    if dc and type(dc.dcQualify) == "function" then
        dc:dcQualify(self)
    end
end

function PetManager:finalizeIconV2Snapshot(snapshot)
    return snapshot
end

function PetManager:getIconV2Snapshot()
    local model = self:getModel()
    local mode = self:getActIconMode()
    local enabled = self:isEnabled()
    local beginTime = normalizeTimestampInSec(model:getBeginTime())
    local mainBeginTime = normalizeTimestampInSec(model:getMainBeginTime())
    local mainEndTime = normalizeTimestampInSec(model:getMainEndTime())
    local endTime = normalizeTimestampInSec(model:getEndTime())
    local phase = mainEndTime > 0 and TimeKit:timeInSec() >= mainEndTime
        and "reward" or "main"
    local canShowReward = not model:isFinalLevelMaxExpReached()
    local snapshot = {
        enabled = enabled,
        mode = mode,
        priority = self:getActIconPriority(mode),
        periodId = model:getPeriodId(),
        phase = phase,
        beginTime = beginTime,
        mainBeginTime = mainBeginTime,
        mainEndTime = mainEndTime,
        endTime = endTime,
        wearingDecos = table.clone(model:getWearingDecos() or {}, true),
        wingEffective = type(model.isWingEffective) == "function"
            and model:isWingEffective() == true,
        iconLayout = table.clone((self:getConst() or {}).IconLayout or {}, true),
        hasReward = canShowReward and self:hasReward(),
    }
    local finalized = self:finalizeIconV2Snapshot(snapshot)
    assert(type(finalized) == "table", "PET_ICON_V2_FINAL_SNAPSHOT_REQUIRED")
    return finalized
end

function PetManager:getRewardPreviewData()
    return {
        level = self:getModel():getLevel(),
        exp = self:getModel():getExp(),
        levelMetas = self:getModel():getConfigByKey("levelMetas", {}),
        boxMetas = self:getModel():getConfigByKey("boxMetas", {}),
        canRewardLevels = self:getModel():getCanRewardLevels(),
        rewardedLevels = self:getModel():getRewardedLevels(),
    }
end

function PetManager:getDressPanelData()
    return {
        visibleDecoMap = self:getVisibleDecoMap(),
        ownedDecos = self:getModel():getOwnedDecos(),
        newDecos = self:getModel():getNewDecos(),
        decoMetas = self:getModel():getConfigByKey("decoMetas", {}),
    }
end

function PetManager:getSettingsPanelData()
    return {
        showInLevelPet = self:getModel():isShowPetEnabled(),
    }
end

function PetManager:isActivated()
    return self:getModel():isActivated()
end

function PetManager:setSelectedFeedMultiple(multiple)
    self:getModel():setSelectedFeedMultiple(multiple)
end

function PetManager:getInLevelPetNotify()
    return self:getModel():getInLevelPetNotify()
end

function PetManager:getFoodNum(foodItemId)
    return self:getModel():getFoodNum(foodItemId)
end

function PetManager:getFoodMap()
    return self:getModel():getFoodMap()
end

function PetManager:getFoodMetas()
    return self:getModel():getFoodMetas()
end

function PetManager:getFoodMeta(foodItemId)
    return self:getModel():getFoodMeta(foodItemId)
end

function PetManager:getFeedExp(foodItemId)
    return self:getModel():getFeedExp(foodItemId)
end

function PetManager:getFeedItemId()
    return self:getModel():getFeedItemId()
end

function PetManager:getLevel()
    return self:getModel():getLevel()
end

function PetManager:getExp()
    return self:getModel():getExp()
end

function PetManager:getConfig()
    return self:getModel():getConfig()
end

function PetManager:getSettings()
    return self:getModel():getSettings()
end

function PetManager:getCanRewardLevels()
    return self:getModel():getCanRewardLevels()
end

function PetManager:getRewardedLevels()
    return self:getModel():getRewardedLevels()
end

function PetManager:canClaimReward(level)
    return self:getModel():canClaimReward(level)
end

function PetManager:getOwnedDecos()
    return self:getModel():getOwnedDecos()
end

function PetManager:hasOwnedDeco(decoId)
    return self:getModel():hasOwnedDeco(decoId)
end

function PetManager:getWearingDecoByPart(partType)
    return self:getModel():getWearingDecoByPart(partType)
end

function PetManager:setDebugWearingDecos(wearingDecos)
    self._debugWearingDecos = wearingDecos
end

function PetManager:clearDebugWearingDecos()
    self._debugWearingDecos = nil
end

function PetManager:_getGlobalDebugWearingDecos()
    local data = _G.__PetInLevelSkinTestData
    if type(data) == "table" and type(data.wearingDecos) == "table" and not table.isEmpty(data.wearingDecos) then
        return data.wearingDecos
    end
end

function PetManager:_getDebugWearingDecos()
    return self:_getGlobalDebugWearingDecos() or self._debugWearingDecos
end

function PetManager:isShowPetEnabled()
    return self:getModel():isShowPetEnabled()
end

------------------------------- 关卡内 begin -------------------------------
function PetManager:setPetWingTestEnabled(enabled)
    self._petWingTestEnabled = enabled == true
end

function PetManager:isPetWingTestEnabled()
    return self._petWingTestEnabled == true
end

function PetManager:hasPetWingInLevel(wearingDecos)
    --
--
--
--


    if not self:isWingEffective() then
        return false
    end

    wearingDecos = wearingDecos or self:_getDebugWearingDecos() or self:getWearingDecoMapInLevel()
    local wingItemId = type(wearingDecos) == "table"
        and (wearingDecos[tostring(PetConfig.DecoPartType.Wing)] or wearingDecos[PetConfig.DecoPartType.Wing])
    local wingMeta = getPetDecoInLevelSkinConfig().getDecoMeta(wingItemId)
    return wingMeta ~= nil and tonumber(wingMeta.part) == PetConfig.DecoPartType.Wing
end

function PetManager:hasPetWingBuffLevel()
    local leftThrowTimes = self:getModel():getWingDailyLeftThrowTimes()
    return self:isWingActivated()
        and (leftThrowTimes == -1 or (leftThrowTimes ~= nil and leftThrowTimes > 0))
end

-- 关卡内是否可见宠物，有宠物或者盒子返回true，其余情况返回false
function PetManager:_canDisplayPetInLevel()
    if not self:isEnabled() then 
        return false 
    end
    return true
end

-- 关卡内功能开启的判断条件入口
function PetManager:isActValid(data)
    if not self:_canDisplayPetInLevel() then 
        return false 
    end
    return true
end

function PetManager:getWearingDecoMapInLevel()
    local decoMap = self:getModel():getWearingDecoMap()
    return getPetDecoInLevelSkinConfig().resolveWearingDecosForLevel(decoMap)
end

function PetManager:getUBFuuuConfig()
    return self:getModel():getUBFuuuConfig()
end

-- 进关前获取宠物相关数据
function PetManager:getLevelModContextData()
    if not self:_canDisplayPetInLevel() then return end

    local petActive = self:getModel():isActivated()      -- false 代表是盒子状态
    local debugData = _G.__PetInLevelSkinTestData
    if type(debugData) == "table" and debugData.petActive ~= nil then
        petActive = debugData.petActive == true
    end
    local wearingDecos = self:_getDebugWearingDecos() or self:getWearingDecoMapInLevel()
    wearingDecos = getPetDecoInLevelSkinConfig().resolveWearingDecosForLevel(wearingDecos)
    local wingFreshness = self:getWingFreshness()
    if wingFreshness.isFresh ~= true then
        wearingDecos[PetConfig.DecoPartType.Wing] = nil
        wearingDecos[tostring(PetConfig.DecoPartType.Wing)] = nil
    end
    local petData = {
        wearingDecos = type(wearingDecos) == "table" and table.clone(wearingDecos) or {},
        hasWing = petActive and wingFreshness.isFresh == true and self:hasPetWingInLevel(wearingDecos) or false,
        hasWingBuffLevel = self:hasPetWingBuffLevel() == true,
        periodId = self:getModel():getPeriodId(),
    }


    local forbidCollection = self:isFoodNumEnough()      -- 是否禁止打关获取收集物
    local isBanned = self:getDataByKey("ban", false) == true
    local forbidPetCarry = isBanned or not self:isShowPetEnabled()       -- 是否禁止携带宠物
    --
--
--
--


    local contextData = {
        petActive = petActive,
        forbidCollection = forbidCollection,
        forbidPetCarry = forbidPetCarry,
        petData = petData,
    }
    local noHugeBuffInfo = self:getNoHugeBuffInfo()
    contextData.petHugeBuffInfo = type(noHugeBuffInfo) == "table" and table.clone(noHugeBuffInfo, true) or nil

    if self:_isLogEnabled() then 
    --     -- 削减log无效内容
    --     local logContextData = table.clone(contextData)
    --     -- logContextData.petHugeBuffInfo = nil
    --     logContextData.petHugeBuffInfo = {}
    --     logContextData.petHugeBuffInfo.noHugeBuffData = contextData.petHugeBuffInfo and contextData.petHugeBuffInfo.noHugeBuffData
    --     logContextData.petHugeBuffInfo.noHugeBuffConfig = contextData.petHugeBuffInfo and contextData.petHugeBuffInfo.noHugeBuffConfig
    --     self:_log("=== getLevelModContextData ===", tts(logContextData)) 
    end
    return contextData
end

function PetManager:getNoHugeBuffInfo()
    local noHugeBuffData = self:getModel():getNoHugeBuffData() or {}
    local noHugeBuffConfig = self:getModel():getNoHugeBuffConfig() or {}
    local noHugeBuffDaysTs = noHugeBuffData.noHugeBuffDaysTs or 0
    if type(noHugeBuffDaysTs) == "string" then
        noHugeBuffDaysTs = tonumber(noHugeBuffDaysTs) or 0
    end
    local info = {
        noHugeBuffData = noHugeBuffData,
        noHugeBuffConfig = noHugeBuffConfig,
        noHugeBuffFailList = noHugeBuffData.noHugeBuffFailList or {},
        noHugeBuffPassedCount = noHugeBuffData.noHugeBuffPassedCount or 0,
        noHugeBuffDaysCount = noHugeBuffData.noHugeBuffDaysCount or 0,
        noHugeBuffDaysTs = noHugeBuffDaysTs,
        noHugeBuffFailConfig = noHugeBuffConfig.noHugeBuffFailConfig or {},
        noHugeBuffPassedConfig = noHugeBuffConfig.noHugeBuffPassedConfig or {},
        noHugeBuffDaysConfig = noHugeBuffConfig.noHugeBuffDaysConfig or {},
        bigHelpConfigSelectMetas = noHugeBuffConfig.bigHelpConfigSelectMetas or {},
        smallHelpConfigSelectMetas = noHugeBuffConfig.smallHelpConfigSelectMetas or {},
        wingHelpConfigSelectMetas = noHugeBuffConfig.wingHelpConfigSelectMetas or {},
        bigHelpOpen = noHugeBuffConfig.bigHelpOpen or false,
    }
    return info
end

function PetManager:updateNoHugeBuffData(data)
    self:getModel():updateNoHugeBuffData(data)
end

function PetManager:_isMainOrFsllLevel(levelScene)
    return LevelSceneFunc:isMainLevel(levelScene) or LevelSceneFunc:isFullLevelLib(levelScene)
end

function PetManager:_isValidPetHugeBuffCarrier(passLevelJson)
    return passLevelJson and passLevelJson.hasActivePet == true
end

function PetManager:_trimNoHugeBuffFailList(failList, currentLevelId, topLevelId)
    if type(failList) ~= "table" then return {} end

    local count = table.count(failList)
    if count <= 20 then
        return failList
    end

    local deleteLevelId
    local deleteTs
    currentLevelId = tostring(currentLevelId or "")
    topLevelId = tostring(topLevelId or "")
    for levelId, info in pairs(failList) do
        local ts = type(info) == "table" and tonumber(info.ts) or 0
        if tostring(levelId) ~= currentLevelId and tostring(levelId) ~= topLevelId then
            if deleteTs == nil or ts < deleteTs then
                deleteLevelId = levelId
                deleteTs = ts
            end
        end
    end

    if deleteLevelId == nil then
        for levelId, info in pairs(failList) do
            local ts = type(info) == "table" and tonumber(info.ts) or 0
            if tostring(levelId) ~= currentLevelId then
                if deleteTs == nil or ts < deleteTs then
                    deleteLevelId = levelId
                    deleteTs = ts
                end
            end
        end
    end

    if deleteLevelId then
        failList[deleteLevelId] = nil
    end
    return failList
end

function PetManager:_buildNoHugeBuffUpdateByPassLevel(actData, passLevelData)
    local passLevelJson = passLevelData and passLevelData.passLevelJson or {}
    if not self:_isValidPetHugeBuffCarrier(passLevelJson) then
        if self:_isLogEnabled() then
            self:_log("[HUGE-BUFF] skip noHugeBuff local update: invalid carrier", passLevelJson and table.serialize(passLevelJson) or "nil")
        end
        return nil
    end

    local petitPetLevelContext = actData and actData.petitPetPassLevelContext
    local endLevelData = petitPetLevelContext and petitPetLevelContext.endLevelData or actData and actData.endLevelData
    local levelId = endLevelData and endLevelData.levelId
        or petitPetLevelContext and petitPetLevelContext.levelId
    local levelScene = endLevelData and endLevelData.levelScene
        or petitPetLevelContext and petitPetLevelContext.levelScene
    if not levelId or not levelScene or not self:_isMainOrFsllLevel(levelScene) then
        self:_log("[HUGE-BUFF] skip noHugeBuff local update: invalid level scope", levelId, levelScene)
        return nil
    end

    local noHugeBuffInfo = self:getNoHugeBuffInfo()
    local oldData = noHugeBuffInfo.noHugeBuffData or {}
    local failList = table.clone(oldData.noHugeBuffFailList or {}, true)
    local levelIdStr = tostring(levelId)
    local triggerHugeBuffType = tonumber(passLevelJson.triggerHugeBuffType)
    local isPass = endLevelData and endLevelData.win == true
    local isFail = petitPetLevelContext and petitPetLevelContext.isFail == true
    local topLevelId = endLevelData and endLevelData.topLevelId or _G.getTopLevelId()
    local nowTs = HeTimeUtil:getCurrentTimeMillis()

    local canMaintainPassedCount = passLevelJson.validLevelForPassLevelPity == true
    local hasTriggeredHugeBuff = triggerHugeBuffType ~= nil

    local updateData = {}
    if hasTriggeredHugeBuff then
        -- 触发后清除所有数据
        updateData["noHugeBuffFailList"] = {}
        updateData["noHugeBuffPassedCount"] = 0
        updateData["noHugeBuffDaysCount"] = 0
        -- updateData["noHugeBuffDaysTs"] = nowTs --这里前端没有用上，先不设置了，以后有需求和后端对一下他怎么实现的
    else
        -- 维护对应数据
        if isPass then
            failList[levelIdStr] = nil
        elseif isFail then
            local currInfo = type(failList[levelIdStr]) == "table" and failList[levelIdStr] or {}
            failList[levelIdStr] = {
                count = (tonumber(currInfo.count) or 0) + 1,
                ts = nowTs,
            }
            failList = self:_trimNoHugeBuffFailList(failList, levelIdStr, topLevelId)
        end
        updateData["noHugeBuffFailList"] = failList

        if isPass and canMaintainPassedCount then
            updateData["noHugeBuffPassedCount"] = (tonumber(oldData.noHugeBuffPassedCount) or 0) + 1
        end
    end

    if self:_isLogEnabled() then
        self:_log("[HUGE-BUFF] build noHugeBuff local update",
            "levelId=", levelIdStr,
            "levelScene=", levelScene,
            "isPass=", isPass,
            "isFail=", isFail,
            "validLevelForPassLevelPity=", passLevelJson.validLevelForPassLevelPity,
            "hasTriggeredHugeBuff=", hasTriggeredHugeBuff,
            "triggerHugeBuffType=", triggerHugeBuffType,
            "updateData=", table.serialize(updateData))
    end
    return updateData
end

function PetManager:_getPetitPetCrashResumeContext(event)
    local data = event and event:getData()
    if not data or not data.resumeData then return nil, data end

    local petActId = tostring(self:getConst().actId)
    local actData = data.resumeData:getActData(petActId)
    if type(actData) == "table" and next(actData) ~= nil then
        return actData.customActData, data
    end
    return nil, data
end

function PetManager:_hasLegacyPetitPetCallbackBoosterData(resumeData)
    if not resumeData then return false end

    local callbackBoosterItemType = tostring(UBFGameItemType and UBFGameItemType.kCallbackBoosterV2 or "")
    if callbackBoosterItemType == "" then
        return false
    end

    for _, mod in ipairs(resumeData:getModList() or {}) do
        for _, buildData in ipairs(mod and mod.buildData or {}) do
            if tostring(buildData and buildData.itemType) == callbackBoosterItemType then
                return true
            end
        end
    end

    local viewModList = resumeData:getViewModDataList() or {}
    for _, modData in ipairs(viewModList) do
        local actData = modData and modData.actData
        local customActData = actData and actData.customActData
        if customActData and (tostring(customActData.itemType) == callbackBoosterItemType or tostring(customActData.btt) == callbackBoosterItemType) then
            return true
        end
    end

    return false
end

function PetManager:onActJudgeHasCrashResume(event)
    local data = event
    if type(data) ~= "table" then return false end

    local resumeData = data.resumeData
    if not resumeData then return false end

    if self:_hasLegacyPetitPetCallbackBoosterData(resumeData) then
        data.hasCrashResume = false
        data.crashResumeFailReason = UBFGameResumeFailReason and UBFGameResumeFailReason.kActivityRefuse or 28
        self:_log("block crash resume: legacy kCallbackBoosterV2 detected")
        return true
    end

    return false
end

function PetManager:onActCrashResumeFailed(event)
    local customData, data = self:_getPetitPetCrashResumeContext(event)
    if type(customData) ~= "table" then return false end
    local hasTriggeredHugeBuff = self:_hasTriggeredPetitPetHugeBuffInResumeData(data and data.resumeData)

    local passLevelJson = {}
    local petData = customData.petData
    if type(petData) == "table" and petData.periodId ~= nil then
        passLevelJson.periodId = petData.periodId
    end
    if customData.petActive == true then
        passLevelJson.hasActivePet = true
    end
    if hasTriggeredHugeBuff and customData.triggerHugeBuffType ~= nil then
        passLevelJson.triggerHugeBuffType = customData.triggerHugeBuffType
    end

    if next(passLevelJson) ~= nil then
        data.json = data.json or {}
        data.json[tostring(self:getConst().actId)] = passLevelJson
    end

    local updateData
    if passLevelJson.triggerHugeBuffType ~= nil then
        updateData = self:_buildNoHugeBuffUpdateByPassLevel({
            petitPetPassLevelContext = {
                levelId = data.levelId or data.resumeData and data.resumeData:getLevelId(),
                levelScene = data.levelScene or data.resumeData and data.resumeData:getLevelScene(),
            },
        }, {
            passLevelJson = passLevelJson,
        })
        if updateData then
            data.callbacks = data.callbacks or {}
            table.insert(data.callbacks, function()
                self:updateNoHugeBuffData(updateData)
            end)
        end
    end

    if self:_isLogEnabled() then
        self:_log("onActCrashResumeFailed",
            "hasTriggeredHugeBuff=", hasTriggeredHugeBuff,
            "passLevelJson=", next(passLevelJson) ~= nil and table.serialize(passLevelJson) or "nil",
            "updateData=", updateData and table.serialize(updateData) or "nil")
    end
    return true
end

function PetManager:_hasPetitPetClickCountOperation(opLogs)
    if type(opLogs) ~= "table" then return false end

    for _, opLog in ipairs(opLogs) do
        local op = opLog
        if UBFOpLogMappingHelper and UBFOpLogMappingHelper.reflect then
            local ok, reflected = pcall(function()
                return UBFOpLogMappingHelper:reflect(opLog)
            end)
            if ok and reflected then
                op = reflected
            end
        end

        if type(op) == "table" then
            local params = op.params or op.opParams
            if op.opName == PETIT_PET_CLICK_COUNT_OP_NAME
                or (type(params) == "table" and params.opName == PETIT_PET_CLICK_COUNT_OP_NAME)
                or (type(params) == "table" and type(params.data) == "table" and params.data.opName == PETIT_PET_CLICK_COUNT_OP_NAME) then
                return true
            end
        elseif type(op) == "string" and string.find(op, PETIT_PET_CLICK_COUNT_OP_NAME, 1, true) then
            return true
        end
    end

    return false
end

function PetManager:_hasTriggeredPetitPetHugeBuffInResumeData(resumeData)
    local rawData = resumeData and resumeData.data or resumeData
    local replayLog = rawData and (rawData.replay_log_record or rawData.replayLog)
    return self:_hasPetitPetClickCountOperation(replayLog and replayLog.oLogs)
end

-- 打关结束时更新数据
function PetManager:updatePassLevelData(data, collectionCount, collectionMap, passLevelData, hasWingBuffInLevel)
    if hasWingBuffInLevel == true then
        self:getModel():consumeWingDailyThrowTime()
    end

    if not self:isEnabled() then return end
    collectionCount = tonumber(collectionCount) or 0
    if collectionCount > 0 then
        local foodMap = self:getFoodMap()

        local feedItemId = self:getFeedItemId()
        local currentFoodNum = foodMap[tostring(feedItemId)] or foodMap[tonumber(feedItemId)] or 0
        currentFoodNum = currentFoodNum + collectionCount
        foodMap[tostring(feedItemId)] = currentFoodNum
        self:getModel():updateFeedData({foodMap = foodMap})
        
        if self:getActIconMode() == PetConfig.IconMode.VineCorner then
            self:playCollectFlyToIcon(collectionCount, feedItemId)
        end
    end

    local updateData = self:_buildNoHugeBuffUpdateByPassLevel(data, passLevelData)
    if updateData then
        self:updateNoHugeBuffData(updateData)
    end
end

function PetManager:playCollectFlyToIcon(collectionCount, foodItemId)
    if collectionCount <= 0 then
        self:updateIconState()
        return
    end

    local eventData = {
        count = collectionCount,
        itemId = foodItemId,
        foodItemId = foodItemId,
    }

    local icon = self:getActivityIcon()
    if not icon or icon.isDisposed then
        self:notifyActivityIconChange(PetManager.IconAction.PlayCollectFly, eventData)
        self:updateIconState()
        return
    end

    local flyIcon = _G.GameItemCreator:getPropIcon({
        itemId = foodItemId,
        num = 0,
        needNum = false,
    })
    local context = FlyActCollectionContext.new(self:getConst().actId, {{
        icon = flyIcon,
        num = collectionCount,
    }})
    local assetCapability = icon.getCapability and icon:getCapability("Asset")
    if context.setIconAnimationTask
        and assetCapability
        and type(assetCapability.createCollectionFeedbackTask) == "function" then
        context:setIconAnimationTask(assetCapability:createCollectionFeedbackTask(context))
    end
    context:setFinishCallback(function()
        if icon and not icon.isDisposed and not isDataDrivenIcon(icon) and icon.updateState then
            icon:updateState()
        end
        self:callActFunc("updateTipView")
        if not isDataDrivenIcon(icon) then
            self:updateIconState()
        end
    end)
    if not self:playActCollectionFlyAniByIcon(icon, context, "LEFT") then
        context:finish()
        if flyIcon and not flyIcon.isDisposed then
            flyIcon:dispose()
        end
    end
end


function PetManager:playActCollectionFlyAniByIcon(iconBtn, context, jumpDirection)
    if not iconBtn or iconBtn.isDisposed or not context then return false end

    local targetDirection = jumpDirection
    if targetDirection then
        local rawIconBtn = iconBtn
        local iconAdapter = {}
        setmetatable(iconAdapter, {
            __index = function(_, key)
                local value = rawIconBtn[key]
                if type(value) == "function" then
                    return function(_, ...)
                        return value(rawIconBtn, ...)
                    end
                end
                return value
            end
        })

        function iconAdapter:getInfo()
            return {
                getIconKey = function()
                    if rawIconBtn.getInfo and rawIconBtn:getInfo().getIconKey then
                        return rawIconBtn:getInfo():getIconKey()
                    end
                    return context.iconKey
                end,
                getPoolType = function()
                    local IconMeta = require "amf.feature.mainscene.module.icon.config.IconMeta"
                    if targetDirection == "BOTTOM" then
                        return IconMeta.PoolType.kBottom
                    elseif targetDirection == "RIGHT" then
                        return IconMeta.PoolType.kRightSide
                    elseif targetDirection == "LEFT" then
                        return IconMeta.PoolType.kLeftSide
                    elseif rawIconBtn.getInfo and rawIconBtn:getInfo().getPoolType then
                        return rawIconBtn:getInfo():getPoolType()
                    end
                end,
                isPoolType = function(_, poolType)
                    local IconMeta = require "amf.feature.mainscene.module.icon.config.IconMeta"
                    if targetDirection == "BOTTOM" then
                        return poolType == IconMeta.PoolType.kBottom
                    elseif targetDirection == "RIGHT" then
                        return poolType == IconMeta.PoolType.kRightSide
                    elseif targetDirection == "LEFT" then
                        return poolType == IconMeta.PoolType.kLeftSide
                    end
                    return false
                end,
            }
        end
        iconBtn = iconAdapter
    end
    context.iconBtn = iconBtn
    _G.amfTransaction(TransactionEvent.FLY_ACT_COLLECTIONS, context)
    return true
end
------------------------------- 关卡内 end -------------------------------

return PetManager
