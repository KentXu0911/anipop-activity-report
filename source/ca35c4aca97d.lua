local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local Event = _G["SuperMagicBirdRealGiftEvent"]
    or require "amf.feature.localactivity.supermagicbirdrealgift.event.Event"

local Manager = class("SuperMagicBirdRealGiftManager", BaseFeatureManager)

local DAY_SECONDS = 24 * 60 * 60
local REAL_REWARD_STOCK_LIMIT = 100

-- 关卡外数据可能在活动信息尚未同步时为空，避免将 nil/非法类型直接传给 tonumber。
local function toNumberOrDefault(value, defaultValue)
    if type(value) == "number" then
        return value
    end
    if type(value) == "string" then
        return tonumber(value) or defaultValue
    end
    return defaultValue
end

--[[
Manager 职责：
1. 对外提供活动 facade：打开活动、面板托管、引导标记、本地缓存、打点等常用入口。
2. 同步服务端 actInfo 到 Model；核心业务状态仍放 Model。
3. 提供跨天业务 hook；Act/Notify 使用 BaseFeatureManager 默认 Plug。
]]

-- =============================================================================
-- BaseFeatureManager 配置
-- =============================================================================

function Manager:_getConstPath()
    return "amf.feature.localactivity.supermagicbirdrealgift.const.Const"
end

function Manager:_getModelPath()
    return "amf.feature.localactivity.supermagicbirdrealgift.model.Model"
end

function Manager:_getExtraPlugsConfigList()
    return {
        {
            key = "Download",
        },
        {
            key = "Panel",
            path = {
                plugPath = "amf.feature.localactivity.supermagicbirdrealgift.plug.PanelPlug",
            },
        },
        {
            key = "DC",
            path = {
                plugPath = "amf.feature.localactivity.supermagicbirdrealgift.plug.DCPlug",
            },
        },
        {
            key = "AutoPop",
            path = {
                plugPath = "amf.feature.localactivity.supermagicbirdrealgift.plug.AutoPopPlug",
            },
        },
    }
end

function Manager:setAutoPopupMgr(autoPopupMgr)
    self.autoPopupMgr = autoPopupMgr
end

function Manager:_getAutoPopConfigList()
    local PopStage = AutoPopupConst.PopStage

    return {
        {
            checkPoint = PopupCheckPoint.SUPER_MAGIC_BIRD_REAL_GIFT_STAGE2,
            stages = { PopStage.STAGE_TWO },
            check = function()
                return self:checkCanPopMainPanelStage2()
            end,
            creator = function(_, onPopOver)
                return function()
                    self:popMainPanelStage2(onPopOver)
                end
            end,
        },
    }
end

function Manager:checkCanPopMainPanelStage2()
    return self:isEnabled()
        and not self:getFlagFromLocalByKey(self:getConst().LocalCacheKey.Stage2AutoPop, false)
end

function Manager:popMainPanelStage2(onPopOver)
    if not self:checkCanPopMainPanelStage2() then
        safeRunCall(onPopOver)
        return
    end

    self:setFlagToLocalByKey(self:getConst().LocalCacheKey.Stage2AutoPop, false, true)

    local opened = self:openActivity({
        endCallback = onPopOver,
        failCallback = onPopOver,
        userClick = false,
        extra = {
            mode = self:getConst().PanelMode.MAIN,
            source = "auto_popup_stage2",
            entryType = 1,
        },
    })
    if not opened then
        safeRunCall(onPopOver)
    end
end

function Manager:canPopOnSuperBirdActivated()
    return self:isEnabled()
end

function Manager:popMainPanelOnSuperBirdActivated(onPopOver)
    if not self:canPopOnSuperBirdActivated() then
        return false
    end

    local opened = self:openActivity({
        endCallback = onPopOver,
        failCallback = onPopOver,
        userClick = false,
        extra = {
            mode = self:getConst().PanelMode.MAIN,
            source = "super_bird_activated",
            entryType = 2,
        },
    })
    return opened == true
end

function Manager:_init()
    self._disposed = false
    self:addEventDispatcher()
    self:registerEvents()
    self:getModel():onTimeChanged(function()
        self:_registerCrossPeriodCallbacks()
    end)
    self:_registerCrossPeriodCallbacks()
end

function Manager:registerEvents()
    self:callActFunc("registerActInfoUpdate", "onActInfosUpdate")
end

-- =============================================================================
-- 基础状态 / Icon
-- =============================================================================

function Manager:getActId()
    return self:getConst().actId
end

function Manager:isEnabled()
    local logicEnabled = self:isActivityDataValid()
        and self:getActivityPhase() == self:getConst().ActivityPhase.MAIN
    local resEnabled = self:isResEnabled()

    if logicEnabled and not resEnabled then
        self:callDownloadFunc("startDownload", function()
            self:updateTipView()
        end)
    end

    return logicEnabled and resEnabled
end

function Manager:isEnabledInLevel()
    local logicEnabled = self:isActivityDataValid()
    local resEnabled = self:isResEnabled()

    if logicEnabled and not resEnabled then
        self:callDownloadFunc("startDownload", function()
            self:updateTipView()
        end)
    end

    return logicEnabled and resEnabled
end


function Manager:isResEnabled()
    local labels = self:getConst().downloadLabels
    if not labels or table.isEmpty(labels) then
        return true
    end
    return self:callDownloadFunc("checkDownloadSuccess") == true
end

function Manager:hasReward()
    if not self:isEnabled() or not self:hasTaskInfo() then return false end

    local progress = tonumber(self:getProgress()) or 0
    local target = tonumber(self:getTarget()) or 0
    return target > 0 and progress >= target
end

function Manager:getMsgNum()
    if not self:isEnabled() then return 0 end
    return self:getModel():getMsgNum()
end

function Manager:updateTipView()
    self:callActFunc("updateTipView")
end

-- =============================================================================
-- 打开活动 / 面板托管
-- =============================================================================

function Manager:openActivity(delegate)
    if not self:isActivityDataValid() then
        return false
    end
    delegate = delegate or {}
    delegate.actId = delegate.actId or self:getActId()
    local extra = delegate.extra or {}
    local clickedReviveCard = extra.clickedReviveCard
    if clickedReviveCard and _G.amfBean("SuperMagicBird2024Manager"):canActivateReviveCard() then
        local closeSlpCallback = extra.closeSlpCallback
        extra.closeSlpCallback = nil
        safeRunCall(closeSlpCallback)
        _G.amfBean("SuperMagicBird2024Manager"):openReviveConfirmPanel({
            isRetryPanel = extra.isRetryPanel == true,
            closeCallback = function(activateSucceeded)
                if activateSucceeded then
                    -- safeRunCall(delegate.closeCallback)
                    local playLevelContext = PlayLevelContext.new(extra.levelId, PlayLevelContext.PlayType.OPEN_SL_PANEL)
                    playLevelContext:setLevelScene(extra.levelScene)
                    _G.amfTransaction(TransactionEvent.PLAY_LEVEL, playLevelContext)
                else
                    self:callActFunc("openActivity", delegate)
                end
            end,
        })
    else
        self:callActFunc("openActivity", delegate)
    end
    return true
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
    self:getModel():syncActInfo(actInfo)
end

function Manager:onActInfosUpdate(event)
    local data = event and event:getData() or {}
    local actInfos = data.actInfos or {}
    if not data.fromServer then
        return
    end

    self:syncActInfo(actInfos[tostring(self:getActId())])
end

function Manager:getDataByKey(key, default)
    return self:getModel():getDataByKey(key, default)
end

function Manager:setDataByKey(key, value, needSave)
    self:getModel():setDataByKey(key, value, needSave)
end

function Manager:getConfigByKey(key, default)
    return self:getModel():getConfigByKey(key, default)
end

function Manager:setConfigByKey(key, value, needSave)
    self:getModel():setConfigByKey(key, value, needSave)
end

function Manager:updateData(data)
    self:getModel():updateData(data)
end

function Manager:installActivityInfo(actInfo, mainInfo)
    self:getModel():installActivityInfo(actInfo, mainInfo)
end

function Manager:installTaskRewardResult(data)
    return self:getModel():installTaskRewardResult(data)
end

function Manager:installGuideFlags(guideIds)
    self:getModel():installGuideFlags(guideIds)
end

function Manager:isActivityDataValid()
    return not self._disposed and self:getModel():isActivityDataValid()
end

function Manager:getActivityPhase()
    local phase = self:getConst().ActivityPhase
    if not self:isActivityDataValid() then
        return phase.UNAVAILABLE
    end

    local timePhase = self:getModel():getTimePhase()
    if timePhase == phase.AWARD_ELIGIBLE and not self:hasRealReward() then
        return phase.ENDED
    end
    return timePhase
end

function Manager:canEnterRealGiftPanel()
    local phaseConst = self:getConst().ActivityPhase
    local phase = self:getActivityPhase()

    if phase == phaseConst.MAIN then
        return { canEnter = true, mode = self:getConst().PanelMode.MAIN }
    end
    if phase == phaseConst.AWARD_ELIGIBLE then
        return { canEnter = true, mode = self:getConst().PanelMode.AWARD }
    end
    return { canEnter = false, mode = nil }
end

function Manager:getProgress()
    if self:getActivityPhase() ~= self:getConst().ActivityPhase.MAIN then return 0 end
    return self:getModel():getMainInfoField(self:getConst().MainInfoField.PROGRESS) or 0
end

function Manager:getTarget()
    if self:getActivityPhase() ~= self:getConst().ActivityPhase.MAIN then return 0 end
    return self:getModel():getMainInfoField(self:getConst().MainInfoField.TARGET) or 0
end

function Manager:getTaskProgress()
    return self:getProgress(), self:getTarget()
end

function Manager:getTaskInfo()
    if self:getActivityPhase() ~= self:getConst().ActivityPhase.MAIN then return nil end
    return self:getModel():getMainInfoField(self:getConst().MainInfoField.TASK_INFO)
end

function Manager:getTaskRound()
    if self:getActivityPhase() ~= self:getConst().ActivityPhase.MAIN then return nil end
    return self:getModel():getMainInfoField(self:getConst().MainInfoField.TASK_ROUND)
end

function Manager:hasTaskInfo()
    return self:getTaskInfo() ~= nil
end

function Manager:getLotteryTicketCount()
    if self:getActivityPhase() ~= self:getConst().ActivityPhase.MAIN then return 0 end
    return self:getModel():getMainInfoField(self:getConst().MainInfoField.LOTTERY_TICKET_COUNT) or 0
end

function Manager:canDrawLottery()
    return self:getActivityPhase() == self:getConst().ActivityPhase.MAIN
        and self:getLotteryTicketCount() > 0
end

function Manager:hasRealReward()
    return self:getModel():getMainInfoField(self:getConst().MainInfoField.GOT_REAL_REWARD) == true
end

function Manager:getAddressFilledTime()
    return self:getModel():getMainInfoField(self:getConst().MainInfoField.ADDRESS_FILLED_TIME) or 0
end

function Manager:getCutoffTimes()
    return self:getModel():getMainInfoField(self:getConst().MainInfoField.CUTOFF_TIMES) or {}
end

---Whether the submitted address has entered its fulfillment batch and can no longer be modified.
function Manager:isContactCutoff()
    local addressFilledTime = tonumber(self:getAddressFilledTime()) or 0
    if addressFilledTime <= 0 then return false end

    local firstCutoffTime = 0
    for _, value in ipairs(self:getCutoffTimes()) do
        firstCutoffTime = tonumber(value) or 0
        if addressFilledTime < firstCutoffTime then
            break
        end
    end

    return TimeKit:timeInMillis() >= firstCutoffTime
end

function Manager:getRewardPool()
    if self:getActivityPhase() ~= self:getConst().ActivityPhase.MAIN then return {} end
    return self:getModel():getMainInfoField(self:getConst().MainInfoField.REWARD_POOL) or {}
end

function Manager:getRealRewardLeftCount()
    local value = self:getModel():getMainInfoField(
        self:getConst().MainInfoField.REAL_REWARD_LEFT_COUNT
    )
    value = tonumber(value)
    if not value or value < 0 then return nil end
    return math.floor(value)
end

function Manager:decreaseRealRewardLeftCount()
    return self:getModel():decreaseRealRewardLeftCount()
end

-- 生成主面板抽奖券提示文案。库存信息优先，缺失时按活动开始时间兜底。
function Manager:getLotteryTicketTip(isInLevel)
    local leftCount = self:getRealRewardLeftCount()
    isInLevel = isInLevel or false
    local inLevelLottery = "快来抽奖!"
    local outLevelLottery = "得券抽奖!"
    local finalLottery = isInLevel and inLevelLottery or outLevelLottery
    if leftCount ~= nil and leftCount < REAL_REWARD_STOCK_LIMIT then
        return string.format("只剩%d个，" .. finalLottery, leftCount)
    end

    local beginTime = self:getModel():getBeginTimeInSec()
    if beginTime <= 0 then
        beginTime = self:getModel():getMainBeginTimeInSec()
    end
    local elapsed = TimeKit:timeInSec() - beginTime
    if beginTime > 0 and elapsed <= 2 * DAY_SECONDS then
        return "精美实物，" .. finalLottery
    end
    if beginTime > 0 and elapsed <= 4 * DAY_SECONDS then
        return "库存有限，" .. finalLottery
    end
    return "库存告急，" .. finalLottery
end

function Manager:canOpenPhysicalReward()
    return self:getActivityPhase() == self:getConst().ActivityPhase.AWARD_ELIGIBLE
end

function Manager:canOpenRecord()
    local phase = self:getActivityPhase()
    return phase == self:getConst().ActivityPhase.MAIN
        or phase == self:getConst().ActivityPhase.AWARD_ELIGIBLE
end

function Manager:getRewardEndTime()
    return self:getModel():getEndTimeInSec()
end

function Manager:getGuideFlags()
    return self:getModel():getGuideFlags()
end

function Manager:hasMainPanelGuideFinished()
    return self:hasGuideIndex(self:getConst().Guide.MAIN_PANEL, false)
end

function Manager:_getBaseSuperBirdManager()
    if not _G.amfBean then return nil end
    return _G.amfBean(self:getConst().baseSuperBirdManagerName)
end

function Manager:getBaseSuperBirdAvailable()
    local manager = self:_getBaseSuperBirdManager()
    return manager and manager:getAvailable() or false
end

function Manager:getBaseSuperBirdPassTopNums()
    local manager = self:_getBaseSuperBirdManager()
    return manager and manager:getPassTopNums() or 0
end

function Manager:getBaseSuperBirdNeedWinNum()
    local manager = self:_getBaseSuperBirdManager()
    return manager and manager:getNeedWinNum() or 0
end

function Manager:getBaseSuperBirdWinStreakNums()
    local manager = self:_getBaseSuperBirdManager()
    return manager and manager:getWinStreakNums() or 0
end

-- =============================================================================
-- 奖励入账
-- =============================================================================

function Manager:addRewardsNormal(rewardItems, params)
    if type(rewardItems) ~= "table" or not next(rewardItems) then return end

    local dcFeature, dcSource
    if params then
        dcFeature = params.dcFeature
        dcSource = params.dcSource
    end

    _G.GainPropData:create()
        :setFeature(dcFeature)
        :setSource(dcSource)
        :setProps(rewardItems)
        :execute()
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

function Manager:setTaskProgressCache(taskRound, taskProgress)
    if taskRound == nil then return false end
    self:getModel():setLocalCache(self:getConst().LocalCacheKey.TaskProgress, {
        taskRound = taskRound,
        taskProgress = math.max(0, tonumber(taskProgress) or 0),
    })
    return true
end

function Manager:getTaskProgressCache()
    local cache = self:getModel():getLocalCache(self:getConst().LocalCacheKey.TaskProgress)
    if type(cache) ~= "table" or cache.taskRound == nil then
        return nil
    end
    return {
        taskRound = cache.taskRound,
        taskProgress = math.max(0, tonumber(cache.taskProgress) or 0),
    }
end

function Manager:getShownTipTaskRound()
    local key = self:getConst().LocalCacheKey.ShownTipTaskRound
    return self:getModel():getFlagFromLocalByKeyInt(
        self:getCacheLocalKey(key),
        false,
        true,
        -1
    )
end

function Manager:shouldShowStartPanelEntryTip()
    local taskRound = toNumberOrDefault(self:getTaskRound())
    if taskRound == nil then return false end

    local shownTipTaskRound = toNumberOrDefault(self:getShownTipTaskRound(), -1)
    return self:hasReward()
        and taskRound > shownTipTaskRound
end

function Manager:recordStartPanelEntryTipTaskRound()
    local taskRound = toNumberOrDefault(self:getTaskRound())
    if taskRound == nil then return false end

    local key = self:getConst().LocalCacheKey.ShownTipTaskRound
    self:getModel():saveFlagToLocalByKeyInt(
        self:getCacheLocalKey(key),
        false,
        taskRound,
        true
    )
    return true
end

-- =============================================================================
-- 引导标记
-- =============================================================================

function Manager:hasGuideIndex(index, checkLocalData)
    if index == self:getConst().Guide.MAIN_PANEL then
        return self:getModel():hasAuthorityGuide(index)
    end

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

    local ActCommonHttp = require "amf.middleware.activity.http.ActCommonHttp"
    ActCommonHttp:setActGuideFlag(self:getActId(), index, true)
end

-- =============================================================================
-- 打点
-- =============================================================================

function Manager:dcAct(subCategory, extraData)
    -- TODO: 按真实打点填入 subCategory，示例来自 Const.DC
    self:callDCFunc("dcAct", nil, subCategory, extraData)
end

function Manager:dcUserTrack(subCategory, extraData)
    -- TODO: 按真实打点填入 subCategory，示例来自 Const.DC
    self:callDCFunc("dcUserTrack", nil, subCategory, extraData)
end

--

-- =============================================================================
-- 活动时间 / 跨天
-- =============================================================================

-- 活动时间确认入口
-- Config.lua:setAttributes 从 info.xml 拿到时间后通过 config.getMgr() 调用
function Manager:onActivityTimeConfirmed(timeData)
    self:getModel():updateActivityTime(timeData)
end

function Manager:_registerCrossPeriodCallbacks()
    local PassDayTimer = require "amf.script.tool.timer.PassDayTimer"
    self:_unregisterCrossPeriodCallbacks()

    local model = self:getModel()
    local mainBegin = model:getMainBeginTimeInSec()
    local mainEnd = model:getMainEndTimeInSec()
    local actEnd = model:getEndTimeInSec()
    local now = TimeKit:timeInSec()

    if mainBegin and mainBegin > now then
        self._cbMainBegin = function() self:onActPassMainBegin() end
        self._cbMainBeginTime = mainBegin
        PassDayTimer:registerEndTimeCallback(mainBegin + 1, self._cbMainBegin)
    end
    if mainEnd and mainEnd > now and mainEnd ~= mainBegin then
        self._cbMainEnd = function() self:onActPassMainEnd() end
        self._cbMainEndTime = mainEnd
        PassDayTimer:registerEndTimeCallback(mainEnd + 1, self._cbMainEnd)
    end
    if actEnd and actEnd > now and actEnd ~= mainEnd then
        self._cbActEnd = function() self:onActPassActEnd() end
        self._cbActEndTime = actEnd
        PassDayTimer:registerEndTimeCallback(actEnd, self._cbActEnd)
    end
end

function Manager:_unregisterCrossPeriodCallbacks()
    local PassDayTimer = require "amf.script.tool.timer.PassDayTimer"
    for _, item in ipairs({
        { "_cbMainBeginTime", "_cbMainBegin" },
        { "_cbMainEndTime", "_cbMainEnd" },
        { "_cbActEndTime", "_cbActEnd" },
    }) do
        local time = self[item[1]]
        local callback = self[item[2]]
        if time and callback then
            PassDayTimer:unregisterEndTimeCallback(time, callback)
        end
        self[item[1]] = nil
        self[item[2]] = nil
    end
end

function Manager:onActPassMainBegin()
    local hadPanel = self:getObserverNum() > 0
    self:closeAllPanels()
    self:updateTipView()
    if hadPanel then
        CommonTip:showTip("活动已正式开启，\n请尝试重进活动~")
    end
end

function Manager:onActPassMainEnd()
    self:closeAllPanels()
    self:updateTipView()
end

function Manager:onActPassActEnd()
    self:closeAllPanels()
    self:updateTipView()
    local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
    require "amf.middleware.activity.event.ActivityEvent"
    ActivityEventCenter:dispatch(ActivityEvent.REMOVE_ACTIVITY, { actId = self:getActId() })
end

-- Base NotifyPlug:onInstall() 会把 Manager 注册到 amfEC feature bus。
-- PassDayTimer 跨天时会发送 FeatureEvent.PASS_DAY，FeatureEventBus 按 onAct 前缀调用到这里。
function Manager:onActPassDay()
    if not self:isActivityDataValid() then
        return
    end
    -- 先记录跨天时是否有活动面板，避免刷新入口或关闭回调移除 observer 后漏弹提示。
    local hasPanel = self:getObserverNum() > 0
    BaseFeatureManager.onActPassDay(self)
    self:getModel():onPassDay()
    self:updateTipView()

    self:closeAllPanels()
    if hasPanel then
        -- TODO: 按需替换为业务定制提示文案
        CommonTip:showTip("新的一天开始了，数据已更新，\n请尝试重进活动~")
    end
end

function Manager:dispose()
    if self._disposed then return end
    self._disposed = true
    self:closeAllPanels()
    self:_unregisterCrossPeriodCallbacks()
    self:getModel():dispose()
    self:_getPlugContainer():uninstallAll()
end

return Manager
