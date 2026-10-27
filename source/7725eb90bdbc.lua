local WinRepeatRankManager = class("WinRepeatRankManager")

local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")
local IconCapability = require "amf.feature.mainscene.module.icon.capability.IconCapability"

-- 扩展mgr
local ServerData = require("amf.feature.localactivity.winrepeatrank.model.WinRepeatRankModel")
local Meta = require("amf.feature.localactivity.winrepeatrank.meta.WinRepeatRankMeta")

WinRepeatRankManager.ACT_OPEN_VERSION = 1 -- 如果此活动复用 此值应递增 以区分本地存储值

-- 主线
WinRepeatRankManager.ACT_ID = 4046
WinRepeatRankManager.ACT_SOURCE = "winrepeatrank2024/Config.lua"
WinRepeatRankManager.DCFeature = "WinRepeatRank2023"
WinRepeatRankManager.DCSource = "act_" .. WinRepeatRankManager.ACT_ID
WinRepeatRankManager.ACT_CH_NAME = "连胜排行"
WinRepeatRankManager.POPOUT_OFF_SWITCH = "Winrank_Popout_Off"

function WinRepeatRankManager:getEndTime()
    local data = self.serverData
    local mainEndTime = data:getValue("mainEndTime")
    return mainEndTime
end

function WinRepeatRankManager:getStartTime()
    local data = self.serverData
    local mainBeginTime = data:getValue("mainBeginTime")
    return mainBeginTime
end

function WinRepeatRankManager:getRealEndTime()
    local data = self.serverData
    local endTime = data:getValue("endTime")
    return endTime
end

-- Compatibility for activity versions before Cocos MR !2106.
-- Those versions read Icon V2 state through getIconV2Snapshot. MR !2106 and
-- later read actInfo directly. Delete this block only after MR !2106 is the
-- minimum loadable activity version and the old cache/rollback window ends.
WinRepeatRankManager.IconV2State = {
    UNJOINED = "unjoined",
    IN_PROGRESS = "inProgress",
    PENDING_SETTLEMENT = "pendingSettlement",
}

function WinRepeatRankManager:setAutoPopupMgr(autoPopupMgr)
    self.autoPopupMgr = autoPopupMgr
end

local function firstNumber(...)
    for index = 1, select("#", ...) do
        local selected = select(index, ...)
        local value = tonumber(selected)
        if value then
            return value
        end
    end
end

local function millisToSeconds(value)
    value = tonumber(value)
    if not value then
        return nil
    end
    return math.floor(math.ceil(value / 1000))
end

local function firstBoolean(...)
    for index = 1, select("#", ...) do
        local selected = select(index, ...)
        if type(selected) == "boolean" then
            return selected
        end
    end
    return false
end

local function firstValidRaceType(...)
    for index = 1, select("#", ...) do
        local selected = select(index, ...)
        local raceType = tonumber(selected)
        if raceType == Meta.mainPanelShowType.kMainPanel1
            or raceType == Meta.mainPanelShowType.kMainPanel2
            or raceType == Meta.mainPanelShowType.kMainPanel3 then
            return raceType
        end
    end
end

local function resolvePositiveRank(value)
    value = tonumber(value)
    if not value or value <= 0 then
        return 0
    end
    return math.floor(value)
end

function WinRepeatRankManager:_getIconV2ActExtra(actInfo)
    if type(actInfo) ~= "table" then
        return nil, "WIN_REPEAT_RANK_ICON_V2_ACT_INFO_REQUIRED"
    end
    if type(actInfo.extra) == "table" then
        return actInfo.extra
    end
    if type(actInfo.extra) ~= "string" or actInfo.extra == "" then
        return nil, "WIN_REPEAT_RANK_ICON_V2_EXTRA_REQUIRED"
    end
    local success, extra = pcall(table.deserialize, actInfo.extra)
    if not success or type(extra) ~= "table" then
        return nil, "WIN_REPEAT_RANK_ICON_V2_EXTRA_INVALID"
    end
    return extra
end

function WinRepeatRankManager:_getIconV2PeriodTimes(extra)
    local data = self:getData()
    local stageOneBeginTime = firstNumber(
        millisToSeconds(extra.stageOneBeginTime),
        millisToSeconds(data:getStageOneBeginTime()),
        self:getStartTime()
    )
    local stageOneEndTime = firstNumber(
        millisToSeconds(extra.stageOneEndTime),
        millisToSeconds(data:getStageOneEndTime())
    )
    local stageTwoBeginTime = firstNumber(
        millisToSeconds(extra.stageTwoBeginTime),
        millisToSeconds(data:getStageTwoBeginTime()),
        stageOneEndTime
    )
    local stageTwoEndTime = firstNumber(
        millisToSeconds(extra.stageTwoEndTime),
        millisToSeconds(data:getStageTwoEndTime()),
        self:getEndTime()
    )
    local rewardEndTime = firstNumber(
        millisToSeconds(extra.rewardEndTime),
        self:getRealEndTime()
    )

    if not stageOneBeginTime or not stageOneEndTime
        or not stageTwoBeginTime or not stageTwoEndTime or not rewardEndTime
        or stageOneEndTime <= stageOneBeginTime
        or stageTwoEndTime <= stageTwoBeginTime
        or rewardEndTime < stageTwoEndTime then
        return nil, "WIN_REPEAT_RANK_ICON_V2_PERIOD_INVALID"
    end

    return {
        stageOneBeginTime = stageOneBeginTime,
        stageOneEndTime = stageOneEndTime,
        stageTwoBeginTime = stageTwoBeginTime,
        stageTwoEndTime = stageTwoEndTime,
        rewardEndTime = rewardEndTime,
    }
end

function WinRepeatRankManager:_resolveIconV2DisplayState(now, times, enterGroup)
    if now > times.stageTwoEndTime then
        return self.IconV2State.PENDING_SETTLEMENT
    end
    if not enterGroup then
        return self.IconV2State.UNJOINED
    end
    return self.IconV2State.IN_PROGRESS
end

function WinRepeatRankManager:_resolveIconV2TimedLabel(now, times, state, rankType)
    if state == self.IconV2State.PENDING_SETTLEMENT then
        return "待结算", times.stageTwoEndTime, times.rewardEndTime, "fixedText"
    end
    if state == self.IconV2State.UNJOINED then
        return "连胜排行榜", times.stageOneBeginTime, times.stageTwoEndTime, "auto", "活动已结束"
    end
    if now <= times.stageOneEndTime then
        return "连胜预选赛", times.stageOneBeginTime, times.stageOneEndTime, "auto"
    end
    if rankType == Meta.mainPanelShowType.kMainPanel3 then
        return "连胜精英赛", times.stageTwoBeginTime, times.stageTwoEndTime, "auto", "活动已结束"
    end
    if rankType == Meta.mainPanelShowType.kMainPanel2 then
        return "连胜新星赛", times.stageTwoBeginTime, times.stageTwoEndTime, "auto", "活动已结束"
    end
    return "连胜预选赛", times.stageTwoBeginTime, times.stageTwoEndTime, "auto", "活动已结束"
end

function WinRepeatRankManager:getIconV2Snapshot(now, overrides)
    local actInfo = self:getActInfo()
    local extra, extraError = self:_getIconV2ActExtra(actInfo)
    if not extra then
        return nil, extraError
    end
    local times, periodError = self:_getIconV2PeriodTimes(extra)
    if not times then
        return nil, periodError
    end

    now = tonumber(now) or TimeKit:timeInSec()
    local data = self:getData()
    overrides = type(overrides) == "table" and overrides or nil
    local modelRankType = data:getCurMainTimeShowType()
    local enterGroup = firstBoolean(
        overrides and overrides.enterGroup,
        data:checkIsEnterGroup(),
        extra.entryGroup
    )
    if modelRankType == Meta.mainPanelShowType.kMainPanel0 then
        enterGroup = false
    end
    local rankType = firstValidRaceType(
        overrides and overrides.rankType,
        modelRankType,
        extra.raceType
    ) or Meta.mainPanelShowType.kMainPanel1
    local state = self:_resolveIconV2DisplayState(now, times, enterGroup)
    local label, phaseStartTime, phaseEndTime, timedLabelMode, reachedText =
        self:_resolveIconV2TimedLabel(now, times, state, rankType)
    local available = now >= times.stageOneBeginTime and now <= times.rewardEndTime
    local newActivityPermitted = available
        and state ~= self.IconV2State.PENDING_SETTLEMENT
    local hasReward = self:hasRewards() == true
    local rankValue = actInfo.rank
    if overrides and overrides.rank ~= nil then
        rankValue = overrides.rank
    end
    local rank = enterGroup and resolvePositiveRank(rankValue) or 0
    local assetAnimation = enterGroup
        and rankType == Meta.mainPanelShowType.kMainPanel3
        and "lv2"
        or "lv1"

    return {
        enabled = available,
        newActivityPermitted = newActivityPermitted == true,
        activityState = state,
        periodKey = table.concat({
            "winrepeatrank2024",
            tostring(self.ACT_ID),
            tostring(times.stageOneBeginTime),
            tostring(times.rewardEndTime),
        }, ":"),
        phaseStartTime = phaseStartTime,
        phaseEndTime = phaseEndTime,
        timedLabelMode = timedLabelMode,
        reachedText = reachedText,
        label = label,
        rank = rank,
        rankType = rankType,
        enterGroup = enterGroup,
        hasReward = hasReward,
        assetAnimation = assetAnimation,
    }
end

--------------------------------------------------------------------------------
-- End of Legacy activity IconData compatibility.
--------------------------------------------------------------------------------

local function applyPatch(target, patch)
    if type(patch) ~= "table" then
        return
    end
    for key, value in pairs(patch) do
        target[key] = value
    end
end

local function cloneActInfoExtra(actInfo)
    local rawExtra = actInfo and actInfo.extra
    if type(rawExtra) == "table" then
        return table.clone(rawExtra)
    end
    if type(rawExtra) ~= "string" or rawExtra == "" then
        return nil, "WIN_REPEAT_RANK_ACT_INFO_EXTRA_REQUIRED"
    end
    local extra = table.deserialize(rawExtra)
    if type(extra) ~= "table" then
        return nil, "WIN_REPEAT_RANK_ACT_INFO_EXTRA_INVALID"
    end
    return table.clone(extra)
end

--是否是预热期
function WinRepeatRankManager:isInPreheatTime()
    local data = self.serverData
    local mainBeginTime = data:getValue("mainBeginTime")
    local beginTime = data:getValue("beginTime")
    if not mainBeginTime or not beginTime then return end
    local now = TimeKit:timeInSec()

    return now >= tonumber(beginTime) and now <= tonumber(mainBeginTime)
end

--是否是主活动期
function WinRepeatRankManager:isInMainTime()
    local data = self.serverData
    local mainBeginTime = data:getValue("mainBeginTime")
    local mainEndTime = data:getValue("mainEndTime")
    if not mainBeginTime or not mainEndTime then return end
    local now = TimeKit:timeInSec()

    return now >= tonumber(mainBeginTime) and now <= tonumber(mainEndTime)
end

--是否是领奖期
function WinRepeatRankManager:isInRewardTime()
    local data = self.serverData
    local mainEndTime = data:getValue("mainEndTime")
    local endTime = data:getValue("endTime")
    if not endTime or not mainEndTime then return end
    local now = TimeKit:timeInSec()

    return now >= tonumber(mainEndTime) and now <= tonumber(endTime)
end

-- 本地bool缓存
function WinRepeatRankManager:saveFlagToLocalByKey(key, needTime, bSkip)
    if not key then return end
    if bSkip == nil then bSkip = true end
    if needTime then
        self:getData():setValue(key, getDayStartTimeByTS(TimeKit:timeInSec()), true)
    else
        self:getData():setValue(key, bSkip, true)
    end
end

function WinRepeatRankManager:getFlagFromLocalByKey(key, needTime)
    if needTime then
        local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())
        return self:getData():getValue(key) == nowTime
    else
        return self:getData():getValue(key)
    end
end

function WinRepeatRankManager:isEnabled()
    if (self:isInMainTime() ) and self.serverData:getValue("userData") then
        return true
    else
        return false
    end
end


function WinRepeatRankManager:isEnabled2()
    if (self:isInMainTime() or self:isInRewardTime() ) and self.serverData:getValue("userData") then
        return true
    else
        return false
    end
end

function WinRepeatRankManager:isPopoutDisabled()
    return MaintenanceManager:getInstance():isEnabledInGroup(WinRepeatRankManager.POPOUT_OFF_SWITCH, "ON")
end

function WinRepeatRankManager:initialize()
    self.serverData = ServerData:create("WinRepeatRankManager" .. WinRepeatRankManager.ACT_OPEN_VERSION)

    self.meta = Meta

    self.oldWinNumForIconAnim = 0

    self.isEventDataUpdated = false
    self.eventDataInfo = {}

    self:registerEvents()
    self:initPlugs()

    local InLevelBridgeModule = require "amf.feature.localactivity.winrepeatrank.module.InLevelBridgeModule"
    self.inLevelBridgeModule = InLevelBridgeModule:create(self)
end


------------------------------------------- 额外插件 -------------------------------------------
function WinRepeatRankManager:getConst()
    local WinRepeatRankMeta = require"amf.feature.localactivity.winrepeatrank.meta.WinRepeatRankMeta"
    return WinRepeatRankMeta
end

function WinRepeatRankManager:initPlugs()
    self:_initPlug("AutoPop", {
        plugPath = "amf.middleware.activity.base.plug.AutoPopPlug",
    })
    self:_initPlug("ActSend",{
        plugPath = "amf.feature.localactivity.winrepeatrank.plug.WinRepeatRankSendPlug",
    })
end

local blockedForTopLevelPlayer

local function isAutoPopupLevelEffective()
    return _G.getTopLevelId() >= 75
end

function WinRepeatRankManager:_getAutoPopConfigList()
    return {
        {
            checkPoint = PopupCheckPoint.WIN_REPEAT_RANK_STAGE3_POP,
            actId = self.ACT_ID,
            stages = {AutoPopupConst.PopStage.STAGE_THREE},
            check = function()
                if not _G.amfBean("ActivityMgr"):isActSupported(self.ACT_ID) then return false end
                -- 注册式强弹会在活动数据异步到达前执行 check；此时不能进入
                -- getCurTimeRankRaceType 的时间比较。
                return self:isEnabled() and isAutoPopupLevelEffective()
                    and self:checkCanPopStage3()
            end,
            pop = function(_, onPopOver)
                return function()
                    self:popStage3(onPopOver)
                end
            end,
        },
        {
            checkPoint = PopupCheckPoint.WIN_REPEAT_RANK_STAGE4_POP,
            actId = self.ACT_ID,
            stages = {AutoPopupConst.PopStage.STAGE_FOUR},
            check = function()
                if not _G.amfBean("ActivityMgr"):isActSupported(self.ACT_ID) then return false end
                return self:isEnabled() and isAutoPopupLevelEffective()
                    and not blockedForTopLevelPlayer()
                    and (self:checkCanPopMainPanel()
                        or self:checkCanPopMainPanelForGroupReward())
            end,
            pop = function(_, onPopOver)
                return function()
                    self:popMainPanel(onPopOver, 4)
                end
            end,
        },
    }
end


-- 如果要自己继承插件改的话自己传plugPath, 可以继承调用
-- 如果有自己的插件模块要添加也可以这么整，在自己的活动功能文件夹下整插件加上去。
function WinRepeatRankManager:_initPlug(key, data)
    local plugPath
    if data and data.plugPath then
        plugPath = data.plugPath
    end

    local TextUtil = require "amf.middleware.ui.util.TextUtil"
    local holdName = TextUtil:lowercaseFirstLetter(key) .. "Plug"

    self:_installPlug(key, data, plugPath):as(holdName)

    -- 插件函数调用
    self["call" .. key .. "Func"] = function(obj, funcName, ...)
        return obj:callPlug(key, funcName, ...)
    end
end

function WinRepeatRankManager:_getPlugContainer()
    if not self.plugContainer then
        local PlugContainer = require "amf.script.pattern.plug.PlugContainer"
        self.plugContainer = PlugContainer:create(self, "amf.feature.localactivity.winrepeatrank.plug")
    end
    return self.plugContainer
end

function WinRepeatRankManager:_installPlug(plugType, installData, scriptPath)
    local plug = self:_getPlugContainer():install(plugType, installData, scriptPath)
    return {
        as = function(_, name)
            if name then
                if self[name] == plug then
                    self[name] = nil
                end
                self[name] = plug
            end
        end
    }
end

function WinRepeatRankManager:_uninstallPlug(plugType)
    self:_getPlugContainer():uninstall(plugType)
end

function WinRepeatRankManager:_getPlug(plugType)
    return self:_getPlugContainer():getPlug(plugType)
end

function WinRepeatRankManager:callPlug(plugType, funcName, ...)
    return self:_getPlugContainer():call(plugType, funcName, ...)
end

------------------额外插件over ------------


function WinRepeatRankManager:registerEvents()
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)

    _G.amfEC:registerNormal(NormalEvent.PASS_DAY, self.onActPassDay, self)

    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
    IconTipEventCenter:register(IconTipEvent.CHECK_ICON_TIP, self.onActCheckIconTip, self)
end

function WinRepeatRankManager:onActPassDay()
    if not self:isEnabled() then
        return
    end
    self:getData():passDayClear()
end

function WinRepeatRankManager:getData()
    return self.serverData
end

function WinRepeatRankManager:getMeta()
    return self.meta
end

function WinRepeatRankManager:updateIconActInfo(actInfoPatch, extraPatch)
    local actInfo = self:getActInfo()
    if type(actInfo) ~= "table" then
        return false, "WIN_REPEAT_RANK_ACT_INFO_REQUIRED"
    end

    local nextActInfo = table.clone(actInfo)
    if type(extraPatch) == "table" then
        local extra, extraError = cloneActInfoExtra(actInfo)
        if not extra then
            return false, extraError
        end
        applyPatch(extra, extraPatch)
        nextActInfo.extra = table.serialize(extra)
    end
    applyPatch(nextActInfo, actInfoPatch)
    nextActInfo.fromLocal = true

    ActivityEventCenter:dispatch(ActivityEvent.SET_ACT_INFO, nextActInfo)
    return true
end

-- 更新活动icon(actInfo更新后)
function WinRepeatRankManager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(WinRepeatRankManager.ACT_ID)]

    -- 没有actInfo，且是从服务器发来的，清空数据
    if not actInfo and fromServer then
        self:getData():reset()
        local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
        ActivityEventCenter:dispatch(ActivityEvent.REMOVE_ACTIVITY,{actId = WinRepeatRankManager.ACT_ID})
        return
    end

    if actInfo then
        if self:isEnabled() and (not actInfo.fromLocal) then
            -- 更新最新的领奖数据
            self:getData():updateDataFromActInfo(actInfo)
        end

        local extra = table.deserialize(actInfo.extra or "")
        -- 更新icon
        local enterGroup = extra.entryGroup
        local rankType = extra.raceType
        local rank = actInfo.rank or 0

        self:refreshIcon(rank, rankType, enterGroup)
    end
end

function WinRepeatRankManager:refreshIcon(rank, rankType, enterGroup)
    local icon = self:getActivityIcon()

    if IconCapability:isUsableIcon(icon) then
        if IconCapability:isDataDrivenIcon(icon) then
            return true
        end
        icon:refreshIconData({
            rank = rank,
            rankType = rankType,
            enterGroup = enterGroup
        })
        icon:updateState()
    end
end

function WinRepeatRankManager:hasRewards()
    if not self:isEnabled2() then
        return false
    end

    return self:getData():checkCanGetGroupRewardForIcon()
end

function WinRepeatRankManager:getActInfo()
    return _G.amfBean("ActivityMgr"):getActInfo(WinRepeatRankManager.ACT_ID)
end

function WinRepeatRankManager:setGroupRewardSucess(mainPanelShowType)
    self:getData():setGroupRewardSucess(mainPanelShowType)
end

function WinRepeatRankManager:updateTipView(actInfo)
    local icon = self:getActivityIcon()
    local isDataDrivenIcon = IconCapability:isDataDrivenIcon(icon)
    if not isDataDrivenIcon and not self:isEnabled() then
        return
    end
    if isDataDrivenIcon then
        return self:updateIconActInfo({
            reward = self:hasRewards() == true,
            msgNum = 0,
        })
    end

    local actInfo = actInfo or self:getActInfo(WinRepeatRankManager.ACT_ID)

    local function setIconInfo( source, hasReward, msgNum )
        if not actInfo then return end
        actInfo.reward = hasReward
        actInfo.msgNum = msgNum
        actInfo.fromLocal = true
        ActivityEventCenter:dispatch(ActivityEvent.SET_ACT_INFO, actInfo)
    end

    local hasReward = self:hasRewards()
    setIconInfo(WinRepeatRankManager.ACT_SOURCE, hasReward, 0)

    local rank = 0
    if actInfo then
        rank = actInfo.rank or 0
    end

    local rankType = self:getData():getCurMainTimeShowType()
    local enterGroup = self:getData():checkIsEnterGroup()
    self:refreshIcon(rank, rankType, enterGroup)
end

--闪退恢复失败
function WinRepeatRankManager:onActCrashResumeFailed(event)
    local data = event.data
    if not data or not data.resumeData or not data.levelId then return end
    if not self:isEnabled() then return  end
    local resumeData = data.resumeData
    -- 闪退恢复里有本活动的数据，需要清除连胜
    if resumeData:hasGameMod(UBFActivityIdConst.kWinRepeatRank2023) then
        local oldWinNum = self:getData():getWinningCount()
        self:getData():clearWinningCount()

        -- local RequestOpNotifyOffline = require "amf.middleware.interconnection.remote.http.RequestOpNotifyOffline"
	    -- RequestOpNotifyOffline:post(RequestOpNotifyOffline.OpType.kCloseResumePanel, WinRepeatRankManager.ACT_ID)
        --通知后端清除连胜，不需要额外给后端发协议了，后端现在都统一处理CancelCrashResumePanel这个协议了
        if data.json then
            data.json[tostring(WinRepeatRankManager.ACT_ID)] = {curWinNum = oldWinNum}
        end
    end

    return true
end

function WinRepeatRankManager:checkCanPopMainPanelForGroupReward()
    if self:isPopoutDisabled() or not self:isEnabled() then
        return false
    end

    self:updateMJRewardType()

    local canGetGroupReward = self:getData():checkCanGetGroupReward()
    local canGetMJRewared = self:getData():checkCanGetMJReward()
    local canGetMXRewared = self:getData():checkCanGetMJMXReward()

    return canGetGroupReward or canGetMJRewared or canGetMXRewared
end

function WinRepeatRankManager:checkCanPopMainPanel()
    if self:isPopoutDisabled() or not self:isEnabled() then
        return false
    end

    local mainEndTime = self:getEndTime()
    local hasEntered = (tonumber(mainEndTime) or 0) > 0
        and self:getData():getValue(Meta.AutoPopReduceEnteredEndTimeKey) == mainEndTime
    local raceType = self:getCurTimeRankRaceType()
    local isLowValueRace = raceType == Meta.mainPanelShowType.kMainPanel1
        or raceType == Meta.mainPanelShowType.kMainPanel2
    if isLowValueRace and not hasEntered
        and _G.amfBean("ActivityParticipationMgr"):shouldReduceAutoPopup(self.ACT_ID) then
        return false
    end

    local todayHadPop = self:getFlagFromLocalByKey(Meta.SavePopMainPanelKey, true)
    return not todayHadPop
end

local function shouldReduceAutoPopup(manager)
    local mainEndTime = manager:getEndTime()
    local hasEntered = (tonumber(mainEndTime) or 0) > 0
        and manager:getData():getValue("autoPopReduceEnteredEndTime") == mainEndTime
    return not hasEntered
        and _G.amfBean("ActivityParticipationMgr"):shouldReduceAutoPopup(manager.ACT_ID)
end

blockedForTopLevelPlayer = function()
    local levelUnlockManager = _G.amfBean("LevelUnLockManager")
    local topLevel = levelUnlockManager:getLocalTopLevel(false)
    local myTopLevel = _G.getTopPassedLevelId()
    if topLevel - myTopLevel <= 30 then
        local lastOpenTime = levelUnlockManager:getLastOpenNewLevelTime()
        if lastOpenTime then
            local diffTime = TimeKit:timeInSec() - lastOpenTime
            if diffTime >= 0 and diffTime < 4 * 3600 then
                return true
            end
        end
    end
    return false
end

function WinRepeatRankManager:checkCanPopJoinTip()
    local showType = self.meta.mainPanelShowType.kMainPanel0
    local winNum = self:getData():getWinningCount()
    local raceType = self:getCurTimeRankRaceType()
    if raceType == self.meta.mainPanelShowType.kMainPanel1 then
        if not self:getData():checkGuide(self.meta.GuideIds.kHadPopJoinFirstRank) and winNum > 0 then
            showType = raceType
        end
    elseif raceType == self.meta.mainPanelShowType.kMainPanel2
        or raceType == self.meta.mainPanelShowType.kMainPanel3 then
        if not self:getData():checkGuide(self.meta.GuideIds.kHadPopJoinSecondRank) and winNum > 0 then
            showType = raceType
        end
    end
    return showType ~= self.meta.mainPanelShowType.kMainPanel0, showType
end

function WinRepeatRankManager:checkCanPopStage3()
    if blockedForTopLevelPlayer() then return false end
    local canPopGroupReward = self:checkCanPopMainPanelForGroupReward()
    local canPopJoinTip, showType = self:checkCanPopJoinTip()
    if shouldReduceAutoPopup(self) then
        local preselectionInfo = self:getData():getDataByKey("preselectionInfo")
        if preselectionInfo and not preselectionInfo.acquiredReward then
            canPopGroupReward = false
        end
        if showType == self.meta.mainPanelShowType.kMainPanel1
            or showType == self.meta.mainPanelShowType.kMainPanel2 then
            canPopJoinTip = false
        end
    end
    return canPopGroupReward or canPopJoinTip
end

function WinRepeatRankManager:popStage3(onHandleOver)
    local canPopGroupReward = self:checkCanPopMainPanelForGroupReward()
    local canPopJoinTip, showType = self:checkCanPopJoinTip()
    if shouldReduceAutoPopup(self) then
        local preselectionInfo = self:getData():getDataByKey("preselectionInfo")
        if preselectionInfo and not preselectionInfo.acquiredReward then
            canPopGroupReward = false
        end
        if showType == self.meta.mainPanelShowType.kMainPanel1
            or showType == self.meta.mainPanelShowType.kMainPanel2 then
            canPopJoinTip = false
        end
    end
    if not canPopGroupReward and not canPopJoinTip then
        safeRunCall(onHandleOver)
        return
    end
    if showType == self.meta.mainPanelShowType.kMainPanel1 then
        self:getData():setGuideIndex(self.meta.GuideIds.kHadPopJoinFirstRank)
    elseif showType == self.meta.mainPanelShowType.kMainPanel2
        or showType == self.meta.mainPanelShowType.kMainPanel3 then
        self:getData():setGuideIndex(self.meta.GuideIds.kHadPopJoinSecondRank)
    end
    self:popMainPanel(onHandleOver, 3)
end

function WinRepeatRankManager:openMainActivity(closeCallback, extra, userClick, duanMianData)
    ActivityEventCenter:dispatch(ActivityEvent.OPEN_ACTIVITY, {
        actId = WinRepeatRankManager.ACT_ID,
        endCallback = closeCallback,
        failCallback = closeCallback,
        userClick = userClick,
        extra = extra,
        duanMianData = duanMianData
    })
end

function WinRepeatRankManager:popMainPanel(endCall, popScene)
    if self:isPopoutDisabled() or not self:isEnabled() then
        safeRunCall(endCall)
        return
    end

    if popScene == 3 then
        self:openMainActivity(endCall, {
            needSavePop = true,
            needShowWinNumPanel = true
        }, nil, false)
    else
        self:openMainActivity(endCall, {
            needSavePop = true
        }, nil, false)
    end
end

function WinRepeatRankManager:getActivityIcon()
    return _G.amfBean("IconManager"):getIconByIconKey(tostring(WinRepeatRankManager.ACT_ID))
end

function WinRepeatRankManager:dc(category, subCategory, ...)
    local params = {
        game_type = "stage",
        game_name = WinRepeatRankManager.DCFeature,
        category = category,
        sub_category = subCategory,
    }

    for i, v in pairs({...}) do
        if v then
            if i == 1 and type(v) == 'table' then
                for k, v2 in pairs(v) do
                    params[k] = v2
                end
                break
            else
                params['t'..tostring(i)] = v
            end
        end
    end
    DcUtil:UserTrack(params)
end

---------------------------------- tip --------------------------------
function WinRepeatRankManager:checkCanShowIconTip()
    --判断是否可以弹出排名变化tip
    --历史排名 与 新的排名比较
    --取出后端新发来的排名信息，与本次获得的收集物比较
    if not self:checkEventDataUpdated() then return false, false, 0  end

    local eventDataInfo = self:getEventDataInfo()

    local bCanShowIconTip = false
    local bIsUp = false
    local bOldIsDown = false

    local newRank = eventDataInfo.newRank
    local oldRank = eventDataInfo.oldRank

    local oldShowRank = eventDataInfo.oldShowRank

    if newRank < oldRank then
        --上升
        bCanShowIconTip = true
        bIsUp = true
    end

    if oldShowRank and oldShowRank ~= 0 and not bIsUp and oldShowRank < newRank then
        --下降
        bOldIsDown = true
        bCanShowIconTip = true
    end

    return bCanShowIconTip, bIsUp, newRank, bOldIsDown
end

function WinRepeatRankManager:onActCheckIconTip(event)
    local bCanShowIconTip, bIsUp, newRank, bOldIsDown = self:checkCanShowIconTip()
    if not bCanShowIconTip then return end
    -- local data = event:getData()
    local tipStr = ""
    if bIsUp then
        tipStr = "排名上升至第" .. newRank .. "名"
    elseif bOldIsDown then
        tipStr =  '被超越了，立刻反击！'
    end

    local delegate = self:createTip(tipStr)
    IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, delegate)
    self:setEventDataUpdated(false)
end

function WinRepeatRankManager:createTip(str)
    local delegate = {}
    delegate.iconKey = tostring(WinRepeatRankManager.ACT_ID)
    delegate.iconType = IconTipType.MESSAGE
    delegate.creatorDelegate = {
        tipsType = HomeIconTipsType.ONLY_TEXT,
        text = str,
    }
    delegate.priority = "S"
    delegate.duration = 5
    return delegate
end

---------------------------------- 关卡内 begin--------------------------------
-- 关卡内触发任务条件
function WinRepeatRankManager:isEnabledInLevel(data)
    self.winRepeatRankPassLevelData = nil
    if not self:isEnabled() then
        return false
    end
    -- 判断当前是哪期，在不在期的时间内
    local curRaceType = self:getData():getCurMainTimeShowType()

    local checkStartTime = 0
    local checkEndTime = 0
    if curRaceType == Meta.mainPanelShowType.kMainPanel0 then
        return true
    elseif curRaceType == Meta.mainPanelShowType.kMainPanel1 then
        checkStartTime = math.floor(self:getData():getStageOneBeginTime() / 1000)
        checkEndTime = math.floor(self:getData():getStageOneEndTime() / 1000)
    elseif curRaceType == Meta.mainPanelShowType.kMainPanel2 or curRaceType == Meta.mainPanelShowType.kMainPanel3 then
        checkStartTime = math.floor(self:getData():getStageTwoBeginTime() / 1000)
        checkEndTime = math.floor(self:getData():getStageTwoEndTime() / 1000)
    end

    local curTime = TimeKit:timeInSec()
    if curTime >= checkStartTime and curTime <= checkEndTime then
        return true
    end

    return false
end


function WinRepeatRankManager:isCanUseScoreBuff(data)
    if not data or not data.levelId then
        return false
    end
    if not self:isEnabled2() then
        return false
    end
    local levelScene = data.levelScene or UBFLevelSceneType.kDefault
    local isMainLevel = UBFLevelSceneFunc:isMainLevel(levelScene)
    if not isMainLevel then
        return false
    end

    -- 满级非满星打可补星关
    local userState = _G.amfBean("UserStateManager"):getUserLevelState()
    if userState == _G.UserStateConst.UserLevelState.TOP_LEVEL then
        if not UBFActHelper:isFullStar(data.levelId) then
            return true
        end
    end

    return false
end

-- 获取分数BUFF加成值跟buff结束时间
function WinRepeatRankManager:getCurAvailableBuffAndEndTime(data)
    local scoreBuffRate = Meta.scoreBuffRate
    local hasScoreBuff, scoreAddBuffEndTime = self:getData():getAddScoreBuffEndTime()
    local isLegal = self:isCanUseScoreBuff(data)
    if hasScoreBuff and isLegal then
        return scoreBuffRate, scoreAddBuffEndTime * 1000
    end

    return 0, 0
end

-- 返回关卡内打关所需要的数据
function WinRepeatRankManager:getInLevelActData(levelId)
    local inLevelActData = {}
    inLevelActData.winNum = self:getData():getWinningCount()
    inLevelActData.addScore = self:getData():getAddScore(inLevelActData.winNum + 1)
    return inLevelActData
end

-- 打关结束时更新数据
function WinRepeatRankManager:updatePassLevelData(data, addScore, collectionMap, passLevelData)
    -- 结算失败时不给收集物
    local settleMentState = data.settleMentState
    local levelSupportType = data.modEnvData and data.modEnvData.levelSupportType

    if settleMentState and addScore > 0 then
        self:updateOldWinNum()
        self:getData():addWinningCount(1)
        -- 组织过关面板数据
        local curRaceType = self:getData():getCurMainTimeShowType()
        local isShowClickCloseTip = self:getIsShowClickCloseTip()
        local collectionInfo = passLevelData["passLevelJson"] and passLevelData["passLevelJson"]["collectionInfo"]
        self.winRepeatRankPassLevelData = {
            isQualifier = curRaceType == Meta.mainPanelShowType.kMainPanel3,
            curWinNum = self:getData():getWinningCount(),
            collectionRate = collectionInfo["82"] and collectionInfo["82"]["rate"] or 1,
            addScore = addScore,
            isShowClickCloseTip = isShowClickCloseTip
        }
        if not isShowClickCloseTip then
            CCUserDefault:sharedUserDefault():setBoolForKey("isFirstShowWinRepeatRankPassLevel", false)
            CCUserDefault:sharedUserDefault():flush()
        end
        self.inLevelBridgeModule:tryUpdateElData()
    else
        self:updateOldWinNum()
        self:getData():clearWinningCount()
    end

    self.levelSupportType = levelSupportType
end

function WinRepeatRankManager:updateOldWinNum()
    self.oldWinNumForIconAnim = self:getData():getWinningCount()
end

function WinRepeatRankManager:resetOldWinNum()
    self.oldWinNumForIconAnim = -1
end

function WinRepeatRankManager:getIsShowClickCloseTip()
    local isFirstShowWinRepeatRankPassLevel = CCUserDefault:sharedUserDefault():getBoolForKey("isFirstShowWinRepeatRankPassLevel", true)
    return not isFirstShowWinRepeatRankPassLevel
end

-- 获取连胜过关面板数据
function WinRepeatRankManager:getWinRepeatRankPassLevelData()
    if not self:isEnabled() then return end
    return self.winRepeatRankPassLevelData
end
---------------------------------- 关卡内 end----------------------------------
function WinRepeatRankManager:updateMJRewardType()
    -- 如果打关之前是未满级 当前是满黄满彩 那么直接设置满级奖励已领
    if not self:isEnabled() then
        return
    end

    local levelSupportType = self.levelSupportType
    local preIsFMJ = (levelSupportType == LevelSupportModeType.kNormal)

    local bMainStarFull = _G.amfBean("UserStateManager"):isMainStarFull()
    local bColorfulStarFull = _G.amfBean("UserStateManager"):isColorfulStarFull()

    if preIsFMJ and bMainStarFull and bColorfulStarFull then
        self:getData():setDataByKey('gotFullLevelReward', true, true)
    end
end

----------------------------------------
--------过关面板吊牌
----------------------------------------
-- **开始关卡清空记录的事件数
-- **过关接收事件数据
-- **过关面板加入吊牌
function WinRepeatRankManager:onActBeforeStartLevel(event)
    if not self:isEnabled() or not self:isEnabled2() then
        return
    end
    self:setEventDataUpdated(false)
end

function WinRepeatRankManager:setEventDataUpdated(enabled)
    self.isEventDataUpdated = enabled
end

function WinRepeatRankManager:checkEventDataUpdated()
    return self.isEventDataUpdated
end

function WinRepeatRankManager:getEventDataInfo()
    return self.eventDataInfo
end

function WinRepeatRankManager:onActReceiveEmergency(evt)
    local eventData = evt:getData()
    if not eventData or eventData.endPoint ~= EmergencyConst.STREAK_WINRANK_EVENT then
        return
    end

    if not self:isEnabled() then
        return
    end
    self._rankDataGeneration = (self._rankDataGeneration or 0) + 1
    local newRank = self:processServerRankData(eventData)
    self:updateIconActInfo({
        rank = newRank,
    }, {
        raceType = eventData.data.raceType,
        entryGroup = true,
    })
    self.inLevelBridgeModule:tryUpdateElData()
end

function WinRepeatRankManager:processServerRankData(eventData)
    -- 把数据存起来
    self.eventDataInfo = table.clone(eventData.data)

    local meUid = _G.amfBean("ProfileManager"):getXxlId()

    local newScore = 0
    local oldScore = 0

    local oldShowScore = self:getFlagFromLocalByKey(Meta.SaveOldRankScoreKey) or 0
    local oldShowRank = self:getFlagFromLocalByKey(Meta.SaveOldRankKey) or 0

    -- 把profile整理进去
    local profilesByUid = {}
    local profiles = self.eventDataInfo.activityGroupCommonList.profiles
    local numProfiles = profiles and #profiles or 0

    for i = 1, numProfiles do
        local profileItem = profiles[i]
        profilesByUid[profileItem.uid] = profileItem
    end

    for i, v in ipairs(self.eventDataInfo.activityGroupCommonList.rankList) do
        if v.uid == meUid or (tonumber(v.uid) == tonumber(_G.amfBean("ProfileManager"):getUid())) then
            v.isMe = true
            -- v.score = 100001
        end

        v.profile = v.isMe and _G.amfBean("ProfileManager"):getProfile() or profilesByUid[v.uid]
    end

    -- 插入无人上榜
    local allNum = 15
    if self.eventDataInfo.raceType == Meta.mainPanelShowType.kMainPanel1 or self.eventDataInfo.raceType == Meta.mainPanelShowType.kMainPanel2 then
        allNum = 15
    elseif self.eventDataInfo.raceType == Meta.mainPanelShowType.kMainPanel3 then
        allNum = 5
    end

    local curRankNum = #self.eventDataInfo.activityGroupCommonList.rankList
    if curRankNum < allNum then
        local addNum = allNum - curRankNum
        for i = 1, addNum do
            local info = {}
            info.score = -1
            info.uid = 12345 + i
            info.isEmpty = true
            info.updateTime = 0
            info.profile = {
                uid = info.uid
            }
            table.insert(self.eventDataInfo.activityGroupCommonList.rankList, info)
        end
    end

    -- 排序
    local function sortRankList(rankList)
        -- 按分数排序
        local meRank = 0
        table.sort(rankList, function(a, b)
            if a and b and a.score and b.score then
                if a.score == b.score then
                    if a.updateTime == b.updateTime then
                        return a.uid > b.uid
                    else
                        return tonumber(a.updateTime) < tonumber(b.updateTime)
                    end
                else
                    return a.score > b.score
                end
            end

            return false
        end)

        for i, v in ipairs(rankList) do
            v.rank = i

            if v.isMe then
                meRank = v.rank
            end
        end

        return meRank
    end

    local newRank = sortRankList(self.eventDataInfo.activityGroupCommonList.rankList)

    -- 把本次获得的扣除, 记录下newScore。 使用记录的旧分数
    for i, v in ipairs(self.eventDataInfo.activityGroupCommonList.rankList) do
        if v.isMe then
            newScore = v.score
            v.score = v.score - self.eventDataInfo.addCollections
            oldScore = v.score
            break
        end
    end

    -- 排序2
    local oldRank = sortRankList(self.eventDataInfo.activityGroupCommonList.rankList)

    self.eventDataInfo.newRank = newRank
    self.eventDataInfo.newScore = newScore
    self.eventDataInfo.oldRank = oldRank
    self.eventDataInfo.oldScore = oldScore

    -- 旧的展示排名， 播动画用
    self.eventDataInfo.oldShowScore = oldShowScore
    self.eventDataInfo.oldShowRank = oldShowRank

    self:saveFlagToLocalByKey(Meta.SaveOldRankScoreKey, false, newScore)
    self:saveFlagToLocalByKey(Meta.SaveOldRankKey, false, newRank)

    --
    self:setEventDataUpdated(true)
    return newRank
end

function WinRepeatRankManager:getCurTimeRankRaceType()
    -- 获取当前时间应该所在的rankRace
    local curTime = TimeKit:timeInSec() * 1000
    local oneEndTime = tonumber(self:getData():getStageOneEndTime())
    if not oneEndTime then
        return Meta.mainPanelShowType.kMainPanel0
    end
    local canEliteRace = self:getData():getDataByKey('canEliteRace')
    local raceType = Meta.mainPanelShowType.kMainPanel0
    if curTime < oneEndTime then
        raceType = Meta.mainPanelShowType.kMainPanel1
    else
        raceType = tonumber(self:getData():getDataByKey('raceType')) or 0
        if raceType == 0 then
            -- use Server
            if canEliteRace then
                raceType = Meta.mainPanelShowType.kMainPanel3
            else
                raceType = Meta.mainPanelShowType.kMainPanel2
            end
        end
    end
    return raceType
end

function WinRepeatRankManager:isCanCreatePassLevelPanelDownPart()
    if not self:isEnabled() then return false end
    if not self:checkEventDataUpdated() then return false end
    --rankRace要相同
    local curTimeRankRaceType = self:getCurTimeRankRaceType()
    local eventDataInfo = self:getEventDataInfo()
    if eventDataInfo.raceType ~= curTimeRankRaceType and curTimeRankRaceType ~= Meta.mainPanelShowType.kMainPanel0  then return end
    if eventDataInfo.addCollections <= 0 then
        return false
    end

    return true
end

--过关面板下方挂牌的面板数据
function WinRepeatRankManager:getPlpBottomData(params)
    local _eventDataInfo = self:getEventDataInfo()
    if not table.isEmpty(_eventDataInfo) then
        local eventDataInfo = table.clone(_eventDataInfo)
        local endTime = 0
        local titleName = Meta.rankNameList[1]
        if eventDataInfo.raceType == Meta.mainPanelShowType.kMainPanel1 then
            endTime = self:getData():getStageOneEndTime()
            titleName = Meta.rankNameList[1]
        elseif eventDataInfo.raceType == Meta.mainPanelShowType.kMainPanel2 then
            endTime = self:getData():getStageTwoEndTime()
            titleName = Meta.rankNameList[2]
        elseif eventDataInfo.raceType == Meta.mainPanelShowType.kMainPanel3 then
            endTime = self:getData():getStageTwoEndTime()
            titleName = Meta.rankNameList[3]
        end

        return {
            eventDataInfo =eventDataInfo,
            endTime = endTime,
            titleName = '连胜'..titleName,
            isQualifier = eventDataInfo.raceType == Meta.mainPanelShowType.kMainPanel3,
            dcParams = {
                pass_show = {
                    t1 = WinRepeatRankManager.ACT_ID,
                },
            }
        }
    end
end

function WinRepeatRankManager:onActCrashResumeBeforePopPanelConfirm(evt)
    --强行断连胜
    local data = evt.data
    if not self:isEnabled() then return end

    local actInfos = data.actInfos
    for i,v in ipairs(actInfos) do
        if v.actId == WinRepeatRankManager.ACT_ID then
            self:getData():clearWinningCount()
            break
        end
    end
end

-- 获取过关面板吊牌节点的奖励列表
function WinRepeatRankManager:getPlpBottomCellRewardList(raceType,rank)
    local rewards = self:getData():getRankRewards(raceType,rank)
    local replaceRewards = self:_getPlug("ActSend"):replaceRankReward(rewards, raceType, rank)
    local extraRewards = self:_getPlug("ActSend"):getRankExtraReward(raceType, rank)
    return replaceRewards,extraRewards
end

local function filterRewardFunc(rewardList)
    local newRewardList = {}
    for i, reward in ipairs(rewardList or {}) do
        local newReward = {}
        for k, v in pairs(reward or {}) do
            if type(v) ~= "function" then
                newReward[k] = v
            end
        end
        table.insert(newRewardList, newReward)
    end
    return newRewardList
end

function WinRepeatRankManager:getPlpBottomRankRewardMap()
    local eventDataInfo = self:getEventDataInfo()
    local rankList = eventDataInfo and eventDataInfo.activityGroupCommonList and eventDataInfo.activityGroupCommonList.rankList or {}
    local raceType = eventDataInfo and eventDataInfo.raceType
    local rankRewardMap = {}
    for _, info in ipairs(rankList or {}) do
        local rank = info.rank
        if rank and not rankRewardMap[rank] then
            local rewards, extraRewards = self:getPlpBottomCellRewardList(raceType, rank)
            rankRewardMap[rank] = {
                rewards = filterRewardFunc(rewards),
                extraRewards = filterRewardFunc(extraRewards),
            }
        end
    end

    return rankRewardMap
end

-- 加载服务器排行数据
function WinRepeatRankManager:requestServerRankData(successCallback, failCallback)
    local raceType = self:getData():getCurMainTimeShowType()
    if raceType == Meta.mainPanelShowType.kMainPanel0 then
        safeRunCall(failCallback)
        return
    end
    self._rankDataGeneration = (self._rankDataGeneration or 0) + 1
    local requestGeneration = self._rankDataGeneration
    local function onSuccess(evt)
        local data = evt.data
        local newProfileList = {}
        if data.profiles then
            for i,v in ipairs(data.profiles or {}) do
                local newProfile = {
                    headUrl = v.headUrl,
                    uid = v.uid,
                }
                table.insert(newProfileList, newProfile)
            end
            data.profiles = newProfileList
            data.groupSize = nil
            data.rankRewardAcquired = nil
            data.rewards = nil
        end
        local eventData = {
            activityGroupCommonList = data,
            addCollections = 0,
            raceType = raceType,
        }
        if self._rankDataGeneration == requestGeneration
            and self:getData():getCurMainTimeShowType() == raceType then
            local newRank = self:processServerRankData({data=eventData})
            self:updateIconActInfo({rank = newRank})
        end
        safeRunCall(successCallback)
    end

    local function onFail(evt)
        safeRunCall(failCallback, evt)
    end

    local request = require("amf.feature.localactivity.winrepeatrank.http.RequestRankList")
    local reqParams = {activityId = raceType,}
    request:post(reqParams):next(onSuccess, onFail)
end

-- 获取当前标题
function WinRepeatRankManager:getRankTitleName()
    local raceType = self:getData():getCurMainTimeShowType()
    local titleName = Meta.rankNameList[1]
    if raceType == Meta.mainPanelShowType.kMainPanel1 then
        titleName = Meta.rankNameList[1]
    elseif raceType == Meta.mainPanelShowType.kMainPanel2 then
        titleName = Meta.rankNameList[2]
    elseif raceType == Meta.mainPanelShowType.kMainPanel3 then
        titleName = Meta.rankNameList[3]
    end

    return "连胜"..titleName
end

return WinRepeatRankManager
