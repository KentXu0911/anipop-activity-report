local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")
local deferred = require "amf.script.sugar.deferred"
local CircularTitle = require "amf.middleware.ui.kit.component.CircularTitle"
local WeekTaskEventCenter = require 'amf.feature.localactivity.weektask.event.WeekTaskEventCenter'

local Manager = class("MagicRushManager", BaseFeatureManager)
local ICON_V2_QUERY_RETRY_DELAY = 1
local ICON_V2_QUERY_MAX_RETRY_COUNT = 3
local ICON_V2_PHASE_PREHEAT = "preheat"
local ICON_V2_PHASE_MAIN = "main"
local ICON_V2_PHASE_REWARD = "reward"
local ICON_V2_NORMAL_PRIORITY = 207999
local ICON_V2_TOMORROW_PRIORITY = 200001
local ICON_V2_TOMORROW_PRIORITY_DEMOTION_ENABLED = false

local function toSeconds(value)
    local numberValue = tonumber(value) or 0
    if numberValue > 10000000000 then
        numberValue = numberValue / 1000
    end
    return math.floor(numberValue)
end

local function removeTimer(timer)
    if timer and TimerUtil and type(TimerUtil.removeAlarm) == "function" then
        pcall(TimerUtil.removeAlarm, timer)
    end
end

-- 获取需要启动的额外功能列表
function Manager:_getExtraPlugsConfigList()
    return {{
        key = "AutoPop"
    }, {
        key = "Download"
    }, {
        key = "Panel"
    }, {
        key = "Rewards"
    },{
        key = "ActSend",
        path = {
            plugPath = "amf.feature.localactivity.magicrush.plug.MagicRushActSendPlug",
            const = self:_getConstPath()
        },
    }}
end

function Manager:_getConstPath() return "amf.feature.localactivity.magicrush.const.MagicRushConst" end

function Manager:_getModelPath() return "amf.feature.localactivity.magicrush.model.MagicRushModel" end

function Manager:_getDCPath() return "amf.feature.localactivity.magicrush.dc.MagicRushDC" end

function Manager:_init()
    self._dc = require(self:_getDCPath())

    local InLevelBridgeModule = require "amf.feature.localactivity.magicrush.module.InLevelBridgeModule"
    self.inLevelBridgeModule = InLevelBridgeModule:create(self)
    self._iconV2QueryGeneration = 0
    self._iconV2QueryRetryCount = 0
    
    self:registerEvents()
end

function Manager:initActInfo()
    self:getModel():assignActInfo(self.actPlug:getActInfo())
end

function Manager:setAutoPopupMgr(mgr)
    self._autoPopupMgr = mgr
    self:_registerAutoPopups()
end

function Manager:shouldReduceAutoPopup()
    return not self:hasEnteredCurrentPeriod()
        and _G.amfBean("ActivityParticipationMgr"):shouldReduceAutoPopup(self:getConst().actId)
end

function Manager:_registerAutoPopups()
    if self._autoPopRegistered or not self._autoPopupMgr then return end
    -- 仅等待模型初始化；数据使能、活动时间窗等运行时条件统一在 check 中判断。
    if not self:getModel() then return end

    if self.isVersionNew == nil then
        self.isVersionNew = MaintenanceManager:getInstance():isEnabledInGroup("magic_1v1_v2", "ON2")
    end
    local isNewVersion = self:isNewVersion() == true
    local rule = isNewVersion and "R3"
        or (MaintenanceManager:getInstance():isEnabledInGroup("magic_1v1_pop", "ON2") and "R1" or "R2")
    self._autoPopupMgr:registerPopup({
        checkPoint = PopupCheckPoint.MAGIC_RUSH_STAGE4_POP,
        actId = self:getConst().actId,
        stages = {AutoPopupConst.PopStage.STAGE_FOUR},
        check = function()
            -- isEnabled 已包含 isDataEnabled 与活动时间窗（主时间/领奖期）。
            if not self:isActivitySupported(self:getConst().actId) then return false end
            if not self:isEnabled() then return false end
            if _G.getTopLevelId() < 101 then return false end
            -- R1/R2/R3 分组互斥（由 isNewVersion 与 magic_1v1_pop 开关决定）。
            -- R1：每日最多弹出 1 次；R2：不限制；R3：新版本流程。
            if rule == "R1" then
                return not self:getDailyPopupFlag()
                    and self:isInPrepare()
                    and not self:shouldReduceAutoPopup()
            end
            if rule == "R3" then
                -- 每日主面板未弹过则弹；已弹过仅展示获胜结算。
                if not self:getDailyPopupFlag() then
                    return not self:shouldReduceAutoPopup()
                end
                if self:isToBeSettledNormal() then
                    local myScore, enemyScore = self:getMatchScore()
                    return self:checkWinState(myScore, enemyScore) == self:getConst().MatchState.WIN
                end
                return false
            end
            -- R2：不限制次数
            return self:isInPrepare() and not self:shouldReduceAutoPopup()
        end,
        pop = function(_, onPopOver)
            return function()
                -- R1 弹出即落当日标记，供 check 拦截同日再次弹出。
                if rule == "R1" then
                    self:setDailyPopupFlag()
                end
                self:openActivity({
                    failCallback = onPopOver,
                    endCallback = onPopOver,
                })
            end
        end,
    })
    self._autoPopRegistered = true
end

function Manager:hasEnteredCurrentPeriod()
    local mainEndTime = self:getMainEndTime()
    return (tonumber(mainEndTime) or 0) > 0
        and self:getModel():getValue("inLevelCardParticipatedEndTime") == mainEndTime
end

function Manager:setPopoutManager(mgr)
    self._popoutManager = mgr
end

function Manager:setPlayLevelFlowMgr(mgr)
	self._playLevelFlowMgr = mgr
end

function Manager:registerEvents()
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
    IconTipEventCenter:register(IconTipEvent.CHECK_ICON_TIP, self.onActCheckIconTip, self)
    if EnvUtil:isMiniGame() then
        _G.amfEC:registerNormal(NormalEvent.NO_PANEL_ON_SCENE, self.onActNoPanelOnScene, self)
    end
end

function Manager:updateData(data) self:getModel():assignData(data) end

function Manager:onActPassDay()
    BaseFeatureManager.onActPassDay(self)
    self:updateIcon()
end

function Manager:passDayRefreshData()
    if not self:isEnabled() then return end
    self:getModel():resetTodayJoinCount()
    self:setMainPanelOpenedToday(false)
    self:setTodayBeInvitedAndNotOpen(false)
    self:setMainPanelPopRewardTip(false)
    self:setStartDownPartHignPriorityShowedToday(false)
    self:setDcDayOnceFlag("qualify", false)
    self:setDcDayOnceFlag("join", false)

    local tipKey = self:getConst().TipKey
    for k,v in pairs(tipKey) do
        self:setLocalCache(v, 0)
    end
end

function Manager:sendDcDayOnce(subCategory, ...)
    if self:getDcDayOnceFlag(subCategory) then return end
    self:getDC():sendDC(subCategory, ...)
    self:setDcDayOnceFlag(subCategory, true)
end

----------------------------------------------功能-------------------------------------------------------
function Manager:hasReward()
    if not self:isEnabled() then return end
    if self._iconV2SettlementPending then return false end
    return self:isToBeSettledAndHasReward()
end

function Manager:getMsgNum()
    if not self:isInPrepare() then return 0 end
    return self:getTodayLeftTimes()
end

function Manager:isNewVersion()
    --todo判断开关
    return self.isVersionNew
end

-- 更新icon
function Manager:refreshIconView(reason, payload)
    local icon = self.actPlug:getActIcon()
    if not icon or icon.isDisposed then
        return
    end
    if type(icon.refreshProvider) == "function" then
        self:syncIconV2QuerySchedule(icon)
        return icon:refreshProvider(reason or "magicRushStateChanged", payload)
    end
    if type(icon.updateState) == "function" then
        icon:updateState()
    end
end

function Manager:_cancelIconV2EndTimer()
    removeTimer(self._iconV2QueryEndTimer)
    self._iconV2QueryEndTimer = nil
    self._iconV2ScheduledEndTime = nil
end

function Manager:_getMountedIconV2()
    local icon = self.actPlug:getActIcon()
    if not icon or icon.isDisposed or type(icon.refreshProvider) ~= "function" then
        return nil
    end
    return icon
end

function Manager:_cancelIconV2RetryTimer()
    removeTimer(self._iconV2QueryRetryTimer)
    self._iconV2QueryRetryTimer = nil
end

function Manager:_clearIconV2SettlementPending()
    self._iconV2SettlementPending = false
    self._iconV2PendingPKState = nil
    self._iconV2PendingMatchEndTime = nil
end

function Manager:_beginIconV2SettlementPending(matchEndTime, pkState)
    local pkStateConst = self:getConst().PKState
    if pkState ~= pkStateConst.TO_BE_SETTLED_1 and pkState ~= pkStateConst.TO_BE_SETTLED_2 then
        pkState = pkStateConst.TO_BE_SETTLED_1
    end
    self._iconV2SettlementPending = true
    self._iconV2PendingPKState = pkState
    self._iconV2PendingMatchEndTime = matchEndTime
end

function Manager:_advanceIconV2QueryGeneration(matchEndTime)
    self._iconV2QueryGeneration = (tonumber(self._iconV2QueryGeneration) or 0) + 1
    self._iconV2ActiveMatchEndTime = matchEndTime
    self._iconV2QueryInFlightGeneration = nil
    return self._iconV2QueryGeneration
end

function Manager:_isCurrentIconV2Query(generation, matchEndTime)
    return generation ~= nil
        and matchEndTime ~= nil
        and self._iconV2QueryGeneration == generation
        and self._iconV2ActiveMatchEndTime == matchEndTime
end

function Manager:_getIconV2ActivityPhase(now)
    local model = self:getModel()
    if not model:isIconV2ActivityInfoReady() then
        return nil
    end

    local beginTime = toSeconds(model:getBeginTime())
    local mainBeginTime = toSeconds(model:getMainBeginTime())
    local mainEndTime = toSeconds(model:getMainEndTime())
    local endTime = toSeconds(model:getEndTime())
    now = toSeconds(now or TimeKit:timeInSec())
    if now < beginTime or now > endTime then
        return nil
    end
    if now < mainBeginTime then
        return ICON_V2_PHASE_PREHEAT
    end
    if now <= mainEndTime then
        return ICON_V2_PHASE_MAIN
    end
    return ICON_V2_PHASE_REWARD
end

function Manager:_resetIconV2QueryFlow()
    self:_advanceIconV2QueryGeneration(nil)
    self:_cancelIconV2EndTimer()
    self:_cancelIconV2RetryTimer()
    self._iconV2QueryRetryCount = 0
    self._iconV2QueryExhaustedEndTime = nil
    self:_clearIconV2SettlementPending()
end

function Manager:_activateIconV2QueryFlow(matchEndTime)
    local generation = self:_advanceIconV2QueryGeneration(matchEndTime)
    self:_cancelIconV2EndTimer()
    self:_cancelIconV2RetryTimer()
    self._iconV2QueryRetryCount = 0
    self._iconV2QueryExhaustedEndTime = nil
    self:_clearIconV2SettlementPending()
    return generation
end

function Manager:_scheduleIconV2QueryRetry(failureResponse, generation, matchEndTime)
    if not self:_isCurrentIconV2Query(generation, matchEndTime) then
        return false
    end

    local retryCount = tonumber(self._iconV2QueryRetryCount) or 0
    if retryCount >= ICON_V2_QUERY_MAX_RETRY_COUNT then
        self._iconV2QueryExhaustedEndTime = matchEndTime
        self:refreshIconView("magicRushQueryExhausted", {
            actId = self:getConst().actId,
            matchEndTime = matchEndTime,
        })
        if failureResponse then
            CommonTip:showErrorTip(failureResponse)
        else
            CommonTip:showTip(localize("error.tip.-2"))
        end
        return false
    end

    self._iconV2QueryRetryCount = retryCount + 1
    self:_cancelIconV2RetryTimer()
    local retryTimer
    retryTimer = TimerUtil.addAlarm(function()
        if not self:_isCurrentIconV2Query(generation, matchEndTime)
            or self._iconV2QueryRetryTimer ~= retryTimer then
            return
        end
        self._iconV2QueryRetryTimer = nil
        self:refreshIconView("magicRushQueryRetry", {
            actId = self:getConst().actId,
            matchEndTime = matchEndTime,
            retryCount = self._iconV2QueryRetryCount,
        })
        self:_requestIconV2Query(generation, matchEndTime)
    end, ICON_V2_QUERY_RETRY_DELAY, 1)
    self._iconV2QueryRetryTimer = retryTimer
    return true
end

function Manager:_sendIconV2Query(generation, matchEndTime)
    local Request = require "amf.feature.localactivity.magicrush.http.RequestMagic1v1Query"
    local manager = self
    local model = self:getModel()
    local responseHost = {}

    function responseHost:onResponseMagic1v1Query(response, params)
        if manager:_isCurrentIconV2Query(generation, matchEndTime) then
            model:onResponseMagic1v1Query(response, params)
        end
    end

    return Request:post({}, responseHost)
end

function Manager:_isIconV2ServerNotSettled(event)
    local data = event and type(event.getData) == "function" and event:getData() or {}
    local pkStatusInfo = data and data.pkStatusInfo or {}
    return pkStatusInfo.pkStatus == self:getConst().PKState.INGAME
end

function Manager:_requestIconV2Query(generation, matchEndTime)
    generation = generation or self._iconV2QueryGeneration
    matchEndTime = matchEndTime or self._iconV2ActiveMatchEndTime
    if not self:_isCurrentIconV2Query(generation, matchEndTime) then
        return false
    end
    if self._iconV2QueryInFlightGeneration == generation then
        return false
    end
    if not self:_getMountedIconV2() then
        self:_resetIconV2QueryFlow()
        return false
    end
    self._iconV2QueryInFlightGeneration = generation
    self:_sendIconV2Query(generation, matchEndTime):next(function(event)
        if not self:_isCurrentIconV2Query(generation, matchEndTime)
            or self._iconV2QueryInFlightGeneration ~= generation then
            return
        end
        self._iconV2QueryInFlightGeneration = nil
        if self:_isIconV2ServerNotSettled(event) then
            self:refreshIconView("magicRushQueryNotSettled", {
                actId = self:getConst().actId,
                matchEndTime = matchEndTime,
            })
            self:_scheduleIconV2QueryRetry(nil, generation, matchEndTime)
            return
        end

        self:_resetIconV2QueryFlow()
        self.actPlug:updateTipView()
    end, function(response)
        if not self:_isCurrentIconV2Query(generation, matchEndTime)
            or self._iconV2QueryInFlightGeneration ~= generation then
            return
        end
        self._iconV2QueryInFlightGeneration = nil
        self._iconV2QueryExhaustedEndTime = matchEndTime
        if response then
            CommonTip:showErrorTip(response)
        else
            CommonTip:showTip(localize("error.tip.-2"))
        end
        self:refreshIconView("magicRushQueryFailed", {
            actId = self:getConst().actId,
            matchEndTime = matchEndTime,
            retryCount = self._iconV2QueryRetryCount,
        })
    end)
    return true
end

function Manager:_onIconV2MatchEnded(matchEndTime, generation)
    generation = generation or self._iconV2QueryGeneration
    if not self:_isCurrentIconV2Query(generation, matchEndTime) then
        return
    end
    self._iconV2QueryEndTimer = nil
    self._iconV2ScheduledEndTime = nil
    if not self:_getMountedIconV2() then
        self:_resetIconV2QueryFlow()
        return
    end
    local pendingPKState = self:getModel():getAndRefreshPKState()
    self:_beginIconV2SettlementPending(matchEndTime, pendingPKState)
    self:refreshIconView("magicRushMatchEnded", {
        actId = self:getConst().actId,
        matchEndTime = matchEndTime,
    })
    self:_requestIconV2Query(generation, matchEndTime)
end

function Manager:syncIconV2QuerySchedule(icon)
    if not icon or icon.isDisposed or type(icon.refreshProvider) ~= "function" then
        return
    end

    local phase = self:_getIconV2ActivityPhase()
    if not phase or phase == ICON_V2_PHASE_PREHEAT then
        self:_resetIconV2QueryFlow()
        return
    end

    local model = self:getModel()
    if not model:isIconV2PKDataReady() then
        self:_resetIconV2QueryFlow()
        return
    end

    local pkState = model:getPKStateSnapshot()
    local pkStateConst = self:getConst().PKState
    local matchEndTime = toSeconds(self:getDataByKey("matchRefBean.matchInfo.endTime")) + 1
    if self._iconV2SettlementPending then
        local sameMatch = self._iconV2PendingMatchEndTime == matchEndTime
        local pendingState = pkState == pkStateConst.INGAME
            or pkState == pkStateConst.TO_BE_SETTLED_1
            or pkState == pkStateConst.TO_BE_SETTLED_2
        if sameMatch and pendingState then
            return
        end
        self:_resetIconV2QueryFlow()
    end
    if phase ~= ICON_V2_PHASE_MAIN and phase ~= ICON_V2_PHASE_REWARD then
        self:_resetIconV2QueryFlow()
        return
    end
    if pkState ~= pkStateConst.INGAME then
        self:_resetIconV2QueryFlow()
        return
    end

    if matchEndTime <= 1 then
        return
    end
    if self._iconV2ActiveMatchEndTime ~= matchEndTime then
        self:_activateIconV2QueryFlow(matchEndTime)
    end
    local generation = self._iconV2QueryGeneration
    if self._iconV2QueryExhaustedEndTime == matchEndTime
        or self._iconV2QueryInFlightGeneration == generation
        or self._iconV2QueryRetryTimer then
        return
    end
    if self._iconV2QueryEndTimer and self._iconV2ScheduledEndTime == matchEndTime then
        return
    end

    self:_cancelIconV2EndTimer()
    self._iconV2QueryRetryCount = 0
    self._iconV2ScheduledEndTime = matchEndTime
    self._iconV2QueryEndTimer = TimerUtil.addAlarm(function()
        self:_onIconV2MatchEnded(matchEndTime, generation)
    end, math.max(0, matchEndTime - TimeKit:timeInSec()), 1)
end

function Manager:onIconV2Mounted()
    self:syncIconV2QuerySchedule(self.actPlug:getActIcon())
end

function Manager:updateIcon()
    local icon = self.actPlug:getActIcon()
    if icon and (not icon.isDisposed) then
        if type(icon.refreshProvider) == "function" then
            self:syncIconV2QuerySchedule(icon)
        else
            icon:updateState()
        end
        self.actPlug:updateTipView()
    end
end

-- 待结算且有奖励
function Manager:isToBeSettledAndHasReward() return self:getModel():isToBeSettledAndHasReward() end

function Manager:loadActIntroPanelRes(successCallback, failCallback)
    _G.amfBean("AssetsUtil"):loadMiniFiles({"amf/activity/magicrush/texture/DescPanel.plist"}):next(successCallback,
                                                                                             failCallback)
end

-- 说明面板
function Manager:createDescPanel(closeCallback, page, createCallback)
    self:loadActIntroPanelRes(function()
        page = page or 1
        local illustrationPanelVM = require 'amf.middleware.ui.kit.panel.other.IllustrationPanelVM'

        local path = "amf.feature.localactivity.magicrush.view.uisource.DescPanel_UI"
        local uiData = require(path)
        local builder = UIBuilder.new(uiData)
        local page1 = builder:createChild("page1")
        local page2 = builder:createChild("page2")
        local i
        if _G.amfBean("UserStateManager"):isFMJ() then
            i = 1
        elseif _G.amfBean("UserStateManager"):isColorfulStarFull() then
            i = 3
        else
            i = 2
        end

        local canGet = false
        page1.mbMap.A1:setScale(canGet and 1 or 0)
        page1.mbMap.page1_step1_A2:setScale((not canGet) and 1 or 0)
        if not canGet then
            page1.mbMap.desc_label18:setString("与其他玩家对战")
        end

        if self:isWinningStreakGroup() then i = i + 3 end
        page1.mbMap.ruleCard:changeDisplayByFrameName("XinDuanChuJin1V12025/DescPanel/满级非满级" .. i)

        local nodeName = {}
        local periodId = self:getDataByKey("periodId") or 0
        if not self:getLocalCache("thisPeriodPoped" .. periodId) then
            nodeName = {
                {"page1_step1", "page1_step2", "page1_step3", "page1_step4", "page1_step5", "step6"},
                {"page2_step1", "page2_step2", "page2_step3", "page2_step4", "page2_step5"},
            }
        end

        self:setLocalCache("thisPeriodPoped" .. periodId, true)
        local vm
        vm = illustrationPanelVM.Builder.new()
            :setTitle("")
            :setAnimLimit(1)
            :setPages({page1, page2})
            :setPageAnimNodeNames(nodeName)
            :setNeedLoadRes({
                "amf/activity/magicrush/texture/DescPanel.plist",
            })
            :setPanelReadyCallback(function()
                safeRunCall(createCallback, vm)
            end)
            :setCloseCallback(closeCallback):build()
        vm:popout()
    end, closeCallback)
end

-- 我的tip信息数据
function Manager:getMyTipInfo()
    local pkRound = self:getDataByKey("myInfo.pkRound") or 0
    local pkWinNum = self:getDataByKey("myInfo.pkWinNum") or 0
    local profile = _G.amfBean("ProfileManager"):getProfile()
    local winRate = pkRound == 0 and 0 or (string.format("%.3f", pkWinNum / pkRound))
    winRate = winRate * 100
    winRate = string.gsub(winRate, "%.0$", "")
    local info = {
        name = nameDecode(profile.name),
        winNum = pkWinNum,
        winRate = winRate .. "%"
    }
    return info
end

-- 对手tip信息数据
function Manager:getEnemyTipInfo()
    local enemyInfo = self:getDataByKey("matchRefBean.enemyInfo")
    local enemyProfile = self:getDataByKey("matchRefBean.enemyProfile")
    local pkRound = enemyInfo.pkRound
    local pkWinNum = enemyInfo.pkWinNum
    local winRate = pkRound == 0 and 0 or (string.format("%.3f", pkWinNum / pkRound))
    winRate = winRate * 100
    winRate = string.gsub(winRate, "%.0$", "")
    local info = {
        name = nameDecode(enemyProfile.name),
        winNum = pkWinNum,
        winRate = winRate .. "%"
    }
    return info
end

function Manager:createMyTip(target, callback)
    return self:createRecordTip(target, self:getMyTipInfo(), callback)
end

function Manager:createEnemyTip(target, callback)
    return self:createRecordTip(target, self:getEnemyTipInfo(), callback)
end

function Manager:createEnemyTipByUE(targetBounds)
    local tip = self:createRecordTip(nil, self:getEnemyTipInfo(), nil, targetBounds, 2.5)
    return tip
end

function Manager:createRecordTip(target, info, callback, targetBounds, disappearSec)
    local NameLabel = require "amf.middleware.ui.kit.component.namelabel.NameLabel"
    local name = info.name
    local winRate = info.winRate
    local winNum = info.winNum
    local uiData = require("amf.feature.localactivity.magicrush.view.uisource.recordTip_UI")
    local tipContent, instance = UIBuilder:buildUI(uiData)
    tipContent:setPositionXY(0, 0)
    instance.totalWinCountLabel:setString(winNum)
    instance.totalWinRateLabel:setString(winRate)
    local nameNode = NameLabel:create(name, 26)
    nameNode:setTextColor(hex2ccc4('B2714AFF'))
    nameNode:setAnchorPoint(ccp(0, 0.5))
    nameNode:ignoreAnchorPointForPosition(true)
    LayoutUtil:replaceBy(instance.nameLabel, nameNode)
    LayoutUtil:move(nameNode, -5, EnvUtil:isApp() and -15 or 0)
    instance.nameLabel = nameNode
    tipContent:makeContentSizeContainChildren()
    tipContent:setAnchorPoint(ccp(0.5, 1))

    if type(targetBounds) == "table" then
        targetBounds = CCRectMake(targetBounds.x, targetBounds.y, targetBounds.width, targetBounds.height)
    end

    local tipBuilder = UITip.Builder.new()
        :setContent(tipContent)
        :setCloseCallback(callback)
        :setAutoCloseTime(disappearSec or 31111)

    if targetBounds then
        tipBuilder:setTargetBounds(targetBounds)
    elseif target then
        tipBuilder:setTarget(target)
    end

    local tip = tipBuilder:build()
 
    return tip
end

-- 大藤蔓按钮数据
function Manager:getMainSceneButtonModuleConfig()
    if self:isRacing() then
        local endTime = self:getMatchEndTime()
        return {
            uniqueId = "MagicRushShow",
            actId = self:getConst().actId,
            endTime = endTime + 1,
            play_button_click = 5,
            extraModule = "amf.feature.localactivity.magicrush.mainsceneextra.MainSceneButtonExtraModule",
        }
    end
end

function Manager:getMainSceneButtonShowConfig()
    if not self:isEnabled() then return end
    if not self:isRacing() then return end

    local startTime = math.floor(tonumber(self:getDoubleStartTime())/1000)
    if startTime > TimeKit:timeInSec() then return end
    local endTime = math.floor(tonumber(self:getDoubleEndTime())/1000)

    return {
        uniqueId = "MagicRushShow",
        actId = self:getConst().actId,
        actName = self:getConst().ACT_CH_NAME,
        showStr = "",
        iconCreator = function()
            local label = TTFLabel:createAnimalYH(YH_REF_MAP.noEarClock_t, 25)
            label:setAnchorPoint(ccp(0.5, 0.5))
            label:setTextColor(hex2ccc4("B2560DFF"))
            return label
        end,
        iconPos = ccp(27, 23.5),
        iconScale = 1,
        endTime = endTime + 1,
        rate = 1,
    }
end

----------------------------------------------强弹-------------------------------------------------------
function Manager:ignoreTopPlayer()
    if self.nowLevelId and self.nowLevelScene then
        if _G.amfBean("AutoPopupMgr"):ignoreForTopLevelPlayer(self.nowLevelId, self.nowLevelScene) then
            return true
        end
    end
end

function Manager:isPassLevelFail()
    return self._passLevelFail
end

function Manager:onActCheckIconTip(event)
    printx(44, "magicrushonActCheckIconTip")
    self:refreshIconView("iconTipCheck")
    local data = event:getData()
    local stage = data.stage
    local reason, params = self:checkTipShow(stage)
    if not reason then return end
    self:popIconTip(reason, params)
end

function Manager:onActNoPanelOnScene()

    if not self._autoPopupMgr:isInMainScene() then return end
    -- 强弹中就等强弹
    -- printx(36, "IconTipManager:onPanelRemove 3")
    if self._autoPopupMgr:isRunnning() then return end
    -- printx(36, "IconTipManager:onPanelRemove 4")
    if self._popoutManager:haveWindowOnScreenWithoutCommonTip() then return end
    -- printx(36, "IconTipManager:onPanelRemove 5")
    if self._playLevelFlowMgr:isInLevelFlow() then return end

    printx(44, "magicrushonActNoPanelOnScene")
    self:refreshIconView("noPanelOnScene")
end


function Manager:checkTipShow(stage)
    if not self:isEnabled() then return false end

    local PopReason = self:getConst().PopReason
    local state = self:getAndRefreshPKState()
    local TipKey = self:getConst().TipKey

    local pkState = self:getConst().PKState

    -- 对战中
    if state == pkState.INGAME then
        if stage == "STAGE_TWO" then
            local lastMyScore, lastEnemyScore = self:getModel():getLastScore()
            local myScore, enemyScore = self:getMatchScore()

            if myScore ~= lastMyScore or enemyScore ~= lastEnemyScore then
                self:getModel():setLastScore(myScore, enemyScore)
                return PopReason.COLLECTION, {
                    myScore = myScore,
                    enemyScore = enemyScore
                }
            end
        end
        if stage == "STAGE_THREE" then
            -- 过关失败
            local popValue1 = self:getLocalCache(TipKey.CONTINUE_REWARD_ROUND) or 0
            local popValue2 = self:getLocalCache(TipKey.DOUBLE) or 0
            if self:checkIsContinueRewardRound() and self:isPassLevelFail() and popValue1 < 2 then
                return PopReason.CONTINUE_REWARD_ROUND, {
                    key = TipKey.CONTINUE_REWARD_ROUND
                }
            elseif self:isInDoubleState() and popValue2 < 1 then
                return PopReason.DOUBLE, {
                    key = TipKey.DOUBLE
                }
            end
        end
        -- 准备阶段
    elseif state == pkState.PREPARE and stage == "STAGE_THREE" then
        local canBeInvited = self:getModel():checkCanBeInvited()
        local popValue1 = self:getLocalCache(TipKey.BE_INVITED) or 0

        if canBeInvited and popValue1 < 2 then
            return PopReason.BE_INVITED, {
                key = TipKey.BE_INVITED,
                needTime = true
            }
        end

        local popValue1 = self:getLocalCache(TipKey.CONTINUE_REWARD_ROUND) or 0
        if self:checkIsContinueRewardRound() and self:checkHasLeftTimes() and popValue1 < 2 then
            return PopReason.CONTINUE_REWARD_ROUND, {
                key = TipKey.CONTINUE_REWARD_ROUND
            }
        end

        local popValue2 = self:getLocalCache(TipKey.ENERGY) or 0
        -- 参与立刻得精力！
        if self:checkGetExtraPower() and popValue2 < 2 then
            return PopReason.ENERGY, {
                key = TipKey.ENERGY
            } -- 不需要key，满足条件一直弹出
        end
    elseif state == pkState.PREPARE and stage == "STAGE_ONE" then
        local popValue = self:getLocalCache(TipKey.ENERGY) or 0
        -- 参与立刻得精力！
        if self:checkGetExtraPower() and popValue < 2 then
            return PopReason.ENERGY, {
                key = TipKey.ENERGY
            } -- 不需要key，满足条件一直弹出
        end
    end

    return false
end

-- function Manager:onActAfterAutoPopupEnd(event)
--     local data = event:getData()
--     local lastPopStage = data.lastPopStage

--     -- 不是场景2和4 return
--     if lastPopStage ~= AutoPopupConst.PopStage.STAGE_FOUR and (lastPopStage ~= AutoPopupConst.PopStage.STAGE_TWO) then
--         return
--     end

--     local scene = Director:sharedDirector():run()
--     if scene == nil or not scene:isScene("MainScene") then return end
--     if _G.amfBean("PopoutManager"):haveWindowOnScreenWithoutCommonTip() then return end

--     if self.isPopTipSafe and self.isPopTipSafe() then
--         -- 前一个tip还在，不能给顶掉
--         return
--     end

--     local reason
--     local params
--     -- 场景2过来的
--     if lastPopStage == AutoPopupConst.PopStage.STAGE_TWO then
--         reason, params = self:checkTipShow(2)
--     else
--         reason, params = self:checkTipShow(4)
--     end
--     if not reason then return end
--     -- 出下一个tip，如果前后端切换速度过快，尝试清除前一个tip
--     safeRunCall(self.removeTip)
--     self:popIconTip(reason, params)
-- end

-- 收集物飞行动画结束
function Manager:onCollectionAnimEnd()
    if self:ignoreTopPlayer() then return end

    local icon = self.actPlug:getActIcon()
    if not icon then return end

    if type(icon.refreshProvider) == "function" then
        icon:refreshProvider("collectionAnimationEnded")
    elseif type(icon.refreshIconAnimState) == "function" then
        icon:refreshIconAnimState()
    end
end

function Manager:getPopBeInvitedTipAndReset()
    local tip = self.popBeInvitedTip
    self.popBeInvitedTip = false
    return tip
end

-- 被邀请
function Manager:setPopBeInvitedTip(b)
    self.popBeInvitedTip = b
    if b then setTimeOut(function()
        if self.popBeInvitedTip then
            self:setTodayBeInvitedAndNotOpen(true)
            self:refreshIconView("magicRushInvitationTipClosed", {
                actId = self:getConst().actId,
            })
        end
        self.popBeInvitedTip = false
    end, 10) end
end

-- 今天被邀请但没开主面板
function Manager:setTodayBeInvitedAndNotOpen(flag)
    self:setLocalCache("todayBeInvitedAndNotOpen", flag)
end

function Manager:getTodayBeInvitedAndNotOpen()
    return self:getLocalCache("todayBeInvitedAndNotOpen")
end

-- 已经进过结算面板（为二次进入失败结算，做特殊处理）
function Manager:getHadEnterSettle()
    local flag = self:getLocalCache("thisRoundHadEnterSettle")
    return flag
end

function Manager:setHadEnterSettle(flag)
    self:setLocalCache("thisRoundHadEnterSettle", flag)
end

-- 看到过匹配对手
function Manager:getWatchedOpponent()
    local flag = self:getLocalCache("thisRoundWatchedOpponent")
    return flag
end

function Manager:setWatchedOpponent(flag)
    self:setLocalCache("thisRoundWatchedOpponent", flag)
end

-- 主面板弹奖励tip
function Manager:getMainPanelPopRewardTip()
    local flag = self:getLocalCache("thisRoundRewardPoped")
    return flag
end

function Manager:setMainPanelPopRewardTip(flag)
    self:setLocalCache("thisRoundRewardPoped", flag)
end

-- 大奖轮动画
function Manager:setBigPrizeAnimPlayed(flag)
    self:setLocalCache("bigPrizeAnimPlayed", flag)
end

function Manager:getBigPrizeAnimPlayed()
    return self:getLocalCache("bigPrizeAnimPlayed")
end

function Manager:setStartDownPartHignPriorityShowedToday(flag)
    self:setLocalCache("startDownPartHignPriorityShowedToday", flag)
end

function Manager:getStartDownPartHignPriorityShowedToday()
    return self:getLocalCache("startDownPartHignPriorityShowedToday")
end

--- 参与性打点，一天一次
---@param flag boolean 是否标记
function Manager:setDcDayOnceFlag(subCategory, flag)
    self:setLocalCache("dcDayOnce_"..subCategory, flag)
end

function Manager:updateAnimLabelFlag()
    self:setLocalCache("animLabelFlag", self:getDataByKey("myHistoryInfo.pkRound"))
end

function Manager:getAnimLabelFlag()
    return self:getLocalCache("animLabelFlag") or 0
end

function Manager:shouldPlayShowUpLabelAnim()
    local pkState = self:getAndRefreshPKState()
    if pkState ~= self:getConst().PKState.TO_BE_SETTLED_1 then return false end
    printx(44, "animlabelupdateflag:", self:getDataByKey("myHistoryInfo.pkRound"), self:getAnimLabelFlag())
    return self:getDataByKey("myHistoryInfo.pkRound") > self:getAnimLabelFlag()
end

---@param subCategory string 子分类
---@return boolean 是否标记
function Manager:getDcDayOnceFlag(subCategory)
    return self:getLocalCache("dcDayOnce_"..subCategory)
end

function Manager:getExtraReward(winCount)
    local extraData = self:getActInfoExtraData() or {}
    local periodType = extraData.actType or 0
    
    winCount = math.min(winCount, 5)
    local function checkFunc(index1, index2)
        return (winCount * 3 == index1 and periodType == index2)
    end
    local rewardPoint = 2
    local plug = self:_getPlug("ActSend")
    local pointRuleList = plug:getExtraRewardsConfig(rewardPoint)
    local linkageExtraRewards = {}
    for _, pointRule in ipairs(pointRuleList) do
        if checkFunc(pointRule.index1, pointRule.index2) then
            table.insert(linkageExtraRewards, pointRule.rewards[1])
            break
        end
    end
    
    return linkageExtraRewards
end

--
function Manager:popIconTip(reason, params)
    local callback = params and params.callback or doNothing
    local delegate = {}
    local data = {}

    local PopReason = self:getConst().PopReason
    local TipDesc = self:getConst().TipDesc

    local iconKey = tostring(self:getConst().actId)
    delegate.iconKey = iconKey
    delegate.iconType = IconTipType.MESSAGE
    delegate.priority = "S"

    self:setPopBeInvitedTip(false)
    local function hideTip()
        IconTipEventCenter:dispatch(IconTipEvent.HIDE_ICON_TIP, {
            iconKey = iconKey
        })
    end

    local tip

    if reason == PopReason.COLLECTION then
        data.tipsType = HomeIconTipsType.PK_PROGRESS
        data.myScore = params.myScore or 0
        data.enemyScore = params.enemyScore or 0
        data.win = params.myScore >= params.enemyScore and params.myScore > 0
    elseif reason == PopReason.BE_INVITED then
        self:setPopBeInvitedTip(true)
        data.tipsType = HomeIconTipsType.NORMAL_CIRCLE
        data.targetValue = 0
        data.value = 99.9
        data.progressChangeTime = 10
        data.text = "收到比赛邀请！"
        data.iconOffset = ccp(0, -2)
        if not self:isNewVersion() then
            data.redPointCreate = function()
                local node = Sprite:createEmpty()
                local redDot = AMFCompHelper:createRedDot(node)
                redDot:setScale(0.8)
                return node
            end
        end
        data.iconCreate = function()
            local iconLayer = Layer:create()
            local iconSpine = UICreateUtil:createSpine("amf/icontip/spine/common_tips_export.skel")
            iconSpine:playByName("telphone", true)
            iconLayer:addChild(iconSpine)
            return iconLayer
        end
        data.iconTouchCallback = function()
            self.actPlug:openActivity({
                userClick = true,
            })
            hideTip()
            safeRunCall(callback)
        end
    else
        data.tipsType = HomeIconTipsType.NORMAL_CIRCLE

        if reason == PopReason.CONTINUE_REWARD_ROUND then
            data.text = TipDesc.CONTINUE_REWARD_ROUND
            data.iconCreate = function()
                local roundTotalRewards = self:getDataByKey("roundTotalRewards") or {}
                local plug = self:_getPlug("ActSend")
                roundTotalRewards = plug:replaceRewardsList(roundTotalRewards, 2)
                local pkWinNum = self:getModel():getDataByKey("myInfo.pkWinNum") or 0
                local extraRewards = self:getExtraReward((pkWinNum + 1) / 3.0 )
                roundTotalRewards = plug:mergeShowRewards(roundTotalRewards, extraRewards)
                if table.isEmpty(roundTotalRewards) then return Sprite:createEmpty() end
                local icon = GameItemCreator:getPropIcon(roundTotalRewards[1])
                icon:setScale(0.5)
                return icon
            end
            data.iconTouchCallback = function()
                self.actPlug:openActivity({
                    userClick = true,
                })
                hideTip()
            end
        elseif reason == PopReason.ENERGY then
            data.text = TipDesc.ENERGY
            data.iconCreate = function()
                local joinRewards = self:getModel():getJoinRewards()
                if table.isEmpty(joinRewards) then return Sprite:createEmpty() end
                local icon = GameItemCreator:getPropIcon(joinRewards[1])
                icon:setScale(0.5)
                return icon
            end
            data.iconTouchCallback = function()
                self.actPlug:openActivity({
                    userClick = true,
                })
                hideTip()
            end
        elseif reason == PopReason.DOUBLE then
            data.text = TipDesc.DOUBLE
            data.iconCreate = function()
                local icon = self:createCollectIcon()
                icon:setScale(0.5)
                return icon
            end
        end
    end

    delegate.creatorDelegate = data

    IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, delegate)

    if params and params.key then self:setLocalCache(params.key, (self:getLocalCache(params.key) or 0) + 1) end
end

----------------------------------------------协议-------------------------------------------------------
-- 匹配协议
function Manager:requestJoin(successCallback, failCallback, matchType, loading)
    -- 不在正式期了，不能调用
    if not self:isInMainTime() then
        safeRunCall(failCallback, {errorCode = 730581})
        return
    end

    self:sendDcDayOnce("join", {
        category = "canyu",
        actId = self:getConst().actId,
    })

    self:getModel():requestJoin({
        matchType = matchType
    }, loading):next(function(event)
        local data = event:getData()
        self:getModel():setValue("inLevelCardParticipatedEndTime", self:getMainEndTime(), true)
        if data.joinRewards and (not table.isEmpty(data.joinRewards)) then
            self.rewardsPlug:addRewardsNormal(data.joinRewards, {
                dcExtra = {
                    dcFeature = "magic1v1",
                    dcSource = "open_click"
                }
            })
        end
        self:setWatchedOpponent(false)
        safeRunCall(successCallback, event)
    end, function(event)
        if event:isCancel() then
            CommonTip:showTip(localize("error.tip.-2"))
        else
            CommonTip:showErrorTip(event)
        end
        safeRunCall(failCallback, event)
    end)
end

-- 结算
function Manager:requestSettle(successCallback, failCallback, panelId, rewardUniteExtraIds)
    local myScore, enemyScore = self:getMatchScore()
    local winState = self:checkWinState(myScore, enemyScore)
    local plug = self:_getPlug("ActSend")
    local param = {panelId = panelId}
    param = plug:handleRequestParams("magic1v1Settle",param)

    self:getDC():sendDC("reward_show", {
        panel_id = panelId,
        t1 = self:getPkRound(),
        t3 = self:checkIsContinueRewardRound() and 1 or 0,
        t4 = self:getDataByKey("myInfo.pkWinNum")
    })
    self:getModel():requestSettle({
        type = 1,
        panelId = panelId,
        rewardUniteExtraIds = param.rewardUniteExtraIds
    }):next(function(event)
        local data = event:getData()
        plug:handleRewardByProtocol("magic1v1Settle",data)
        if winState == self:getConst().MatchState.WIN then
            self:setMainPanelPopRewardTip(false)

            WeekTaskEventCenter:dispatch(_G.WeekTaskEvent.ACT_TASK_COMPLETE, { type=_G.WeekTaskType.MAGIC_RUSH_WIN_NUM, num=1})
        end
        local TipKey = self:getConst().TipKey
        self:setLocalCache(TipKey.DOUBLE, 0)
        _G.amfTransaction(TransactionEvent.EXCHANGE_SHOP_TASK, {
            subCmd = "processEvent",
            subData = {
                evt = event,
                rewardDirectList = data.rewards,
                feature = self:getDC().DCFeature,
                source = "reward_show",
                endCall = function(callData)
                    local notCardRewardList = callData.notCardRewardList or {}
                    if not table.isEmpty(notCardRewardList) then
                        self.rewardsPlug:addRewardsNormal(notCardRewardList, {
                            dcExtra = {
                                dcFeature = "magic1v1",
                                dcSource = "reward_show"
                            }
                        })
                    end
                    self:setWatchedOpponent(true)
                    self:setHadEnterSettle(false)
                    safeRunCall(successCallback, callData)
                end
            }
        })
    end, failCallback)
end

function Manager:requestContinueRewards(successCallback, failCallback, panelId)
    self:getDC():sendDC("reward_show", {
        panel_id = panelId,
        t1 = self:getPkRound(),
        t3 = 1,
        t4 = self:getDataByKey("myInfo.pkWinNum")
    })
    local param = {panelId = panelId}
    local plug = self:_getPlug("ActSend")
    param = plug:handleRequestParams("magic1v1Settle",param)
    self:getModel():requestSettle({
        type = 2,
        panelId = panelId,
        rewardUniteExtraIds = param.rewardUniteExtraIds
    }):next(function(event)
        local data = event:getData()
        plug:handleRewardByProtocol("magic1v1Settle",data)
        self.rewardsPlug:addRewardsNormal(data.rewards, {
            dcExtra = {
                dcFeature = "magic1v1",
                dcSource = "reward_show"
            }
        })
        safeRunCall(successCallback, event)
    end, failCallback)
end

-- 查分
function Manager:requestQuery(successCallback, failCallback)
    self:getModel():requestQuery():next(function(event)
        local data = event:getData()
        local pkStatusInfo = data.pkStatusInfo
        local serverNotSettleYet = false
        if pkStatusInfo.pkStatus == self:getConst().PKState.INGAME then
            serverNotSettleYet = true
        end
        safeRunCall(successCallback, event, serverNotSettleYet)
    end, failCallback)
end

----------------------------------------------事件-------------------------------------------------------
function Manager:onSystemEnterForeground()
    self:updateIcon()
end

function Manager:onActPlayLevelEnd(event)
    local data = event:getData()
    local levelId = data.levelId
    local levelScene = data.levelScene
    self.nowLevelId = levelId
    self.nowLevelScene = levelScene
end

function Manager:onActEnterMainScene(event)
    local data = event:getData()
    if data.firstEnter then
        self:initActInfo()
        self.isVersionNew = MaintenanceManager:getInstance():isEnabledInGroup("magic_1v1_v2", "ON2")
        self:_registerAutoPopups()
    end
end

function Manager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(self:getConst().actId)]

    if fromServer and not actInfo then
        self:getModel():reset()
        return
    end

    if actInfo and fromServer then
        self:getModel():assignActInfo(actInfo)
        self:_registerAutoPopups()
    end
end

function Manager:onActReceiveEmergency(evt)
    local eventData = evt:getData()

    if eventData and eventData.endPoint == EmergencyConst.MAGIC_1V1_EVENT_BEAN and eventData.data then
        local cacheData = table.clone(eventData.data)
        local score = cacheData.enemyScore

        if score then
            self:getModel():setEnemyScore(score)
            -- 更新Icon
            self:updateIcon()
            self.inLevelBridgeModule:tryUpdateElData()
        end
    end
end

----------------------------------------------接口-------------------------------------------------------
function Manager:getBeginTime() return self:getModel():getBeginTime() end

function Manager:getEndTime() return self:getModel():getEndTime() end

function Manager:getMainBeginTime() return self:getModel():getMainBeginTime() end

function Manager:getMainEndTime() return self:getModel():getMainEndTime() end

function Manager:isInMainTime() return self:getModel():isInMainTime() end

function Manager:isInRewardTime() return self:getModel():isInRewardTime() end

function Manager:getMatchEndTime()
    if not self:isRacing() then return 0 end
    return self:getModel():getMatchEndTime()
end

function Manager:isLastDay() return self:getModel():isLastDay() end

function Manager:getDataByKey(key) return self:getModel():getDataByKey(key) end

function Manager:getConfigByKey(key) return self:getModel():getConfigByKey(key) end

function Manager:getLocalCache(key, defaultValue) return self:getModel():getLocalCache(key, defaultValue) end

function Manager:setLocalCache(key, value) return self:getModel():setLocalCache(key, value) end

function Manager:getAllJoinCount() return self:getModel():getAllJoinCount() end

--第n次参与活动
function Manager:getPkRound()
    if not self:isEnabled() then return -1 end
    local myInfo = self:getDataByKey("myInfo",{})
    local pkState = self:getAndRefreshPKState()
    local pkRound = myInfo.pkRound + 1
    if pkState == self:getConst().PKState.TO_BE_SETTLED_1 or pkState == self:getConst().PKState.TO_BE_SETTLED_2 then
        pkRound = myInfo.pkRound
    end
    return pkRound
end

function Manager:canShowIcon()
    return (not self:isInPrepare()) or self:isInMainTime()
end

function Manager:isEnabled()
    return self:getModel():isDataEnabled() and (self:isInMainTime() or self:isInRewardTime())
end

function Manager:getDC() return self._dc end

-- pk状态获取和刷新
function Manager:getAndRefreshPKState()
    if not self:isEnabled() then return self:getConst().PKState.INVALID end
    return self:getModel():getAndRefreshPKState()
end

function Manager:isInPrepare()
    local state = self:getAndRefreshPKState()
    return state == self:getConst().PKState.PREPARE
end

function Manager:isRacing()
    local state = self:getAndRefreshPKState()
    return state == self:getConst().PKState.INGAME
end

function Manager:isToBeSettledNormal()
    local state = self:getAndRefreshPKState()
    return state == self:getConst().PKState.TO_BE_SETTLED_1
end

function Manager:isToBeSettledVictoryAccumulated()
    local state = self:getAndRefreshPKState()
    return state == self:getConst().PKState.TO_BE_SETTLED_2
end

-- 有未结算的奖励
function Manager:hasUnclaimedReward()
    local state = self:getAndRefreshPKState()
    return state == self:getConst().PKState.TO_BE_SETTLED_1 or state == self:getConst().PKState.TO_BE_SETTLED_2
end

-- 是否有剩余次数
function Manager:checkHasLeftTimes()
    if not self:isEnabled() then return false end

    return self:getModel():checkHasLeftTimes()
end

-- 今日剩余次数
function Manager:getTodayLeftTimes() return self:getModel():getTodayLeftTimes() end

-- 今日限定次数
function Manager:getTodayLimitNum() return self:getModel():getTodayLimitNum() end

function Manager:getDoubleStartTime()
    return self:getModel():getDoubleStartTime()
end

function Manager:getDoubleEndTime()
    return self:getModel():getDoubleEndTime()
end

function Manager:isInDoubleState()
    if not self:isEnabled() then return false end

    return self:getModel():isInDoubleState()
end

-- icon展示状态（比赛中的）
function Manager:getIconShowState()
    local state = self:getAndRefreshPKState()
    local iconState = self:getConst().IconState

    if state == self:getConst().PKState.INGAME then
        if self:isInDoubleState() then
            return iconState.DOUBLE
        else
            return iconState.INGAME
        end
    else
        return iconState.IDLE
    end
end

function Manager:checkWinState(myScore, enemyScore)
    local matchState = self:getConst().MatchState
    if myScore == enemyScore and myScore == 0 then return matchState.LOSE end
    return myScore >= enemyScore and matchState.WIN or matchState.LOSE
end

-- 获取对局状态
function Manager:getMatchState()
    if not self:isEnabled() then return self:getConst().MatchState.INVALID end

    if self:getAndRefreshPKState() ~= self:getConst().PKState.PREPARE then
        local myScore, enemyScore = self:getMatchScore()
        if myScore > enemyScore then
            return self:getConst().MatchState.WIN
        elseif myScore < enemyScore then
            return self:getConst().MatchState.LOSE
        elseif myScore == enemyScore then
            return self:getConst().MatchState.DRAW
        end
    end

    return self:getConst().MatchState.INVALID
end

function Manager:getMatchScore()
    local myScore = self:getDataByKey("matchRefBean.matchInfo.me.score") or 0
    local enemyScore = self:getDataByKey("matchRefBean.matchInfo.enemy.score") or 0
    return myScore, enemyScore
end

function Manager:_isIconV2TomorrowPriorityDemotionEnabled()
    return ICON_V2_TOMORROW_PRIORITY_DEMOTION_ENABLED
end

function Manager:getIconV2Snapshot()
    local model = self:getModel()
    local pkStateConst = self:getConst().PKState
    local matchStateConst = self:getConst().MatchState
    local iconStateConst = self:getConst().IconState
    local activityReady = model:isIconV2ActivityInfoReady()
    local phase = activityReady and self:_getIconV2ActivityPhase() or nil
    local pkDataReady = model:isIconV2PKDataReady()
    local pkState = pkStateConst.INVALID
    if pkDataReady and phase ~= ICON_V2_PHASE_PREHEAT and phase ~= nil then
        pkState = model:getPKStateSnapshot()
        if pkState == nil then
            pkDataReady = false
            pkState = pkStateConst.INVALID
        end
    end
    local stateEnabled = pkDataReady and phase ~= ICON_V2_PHASE_PREHEAT and phase ~= nil
    local currentMatchEndTime = toSeconds(self:getDataByKey("matchRefBean.matchInfo.endTime")) + 1
    local settlementPending = self._iconV2SettlementPending == true
        and self._iconV2PendingMatchEndTime == currentMatchEndTime
        and (phase == ICON_V2_PHASE_MAIN or phase == ICON_V2_PHASE_REWARD)
    if settlementPending then
        pkState = self._iconV2PendingPKState or pkStateConst.TO_BE_SETTLED_1
    elseif pkState == nil then
        pkState = pkStateConst.INVALID
    end

    local myScore, enemyScore = self:getMatchScore()
    myScore = tonumber(myScore) or 0
    enemyScore = tonumber(enemyScore) or 0

    local matchState
    local isSettlementState = pkState == pkStateConst.TO_BE_SETTLED_1
        or pkState == pkStateConst.TO_BE_SETTLED_2
    local settlementConfirmed = isSettlementState and not settlementPending
    if (pkState == pkStateConst.INGAME or settlementConfirmed)
        and myScore ~= enemyScore
    then
        matchState = self:checkWinState(myScore, enemyScore)
    end

    local hasReward = settlementConfirmed and (
        (pkState == pkStateConst.TO_BE_SETTLED_1 and matchState == matchStateConst.WIN)
            or pkState == pkStateConst.TO_BE_SETTLED_2
    )
    local hasLeftTimes = stateEnabled and model:checkHasLeftTimes() or false
    local leftTimes = stateEnabled and model:getTodayLeftTimes() or 0
    local canShowIcon = activityReady and (phase == ICON_V2_PHASE_PREHEAT
        or phase == ICON_V2_PHASE_MAIN
        or (phase == ICON_V2_PHASE_REWARD
            and (pkState == pkStateConst.INGAME or isSettlementState)))
    local invitationPending = pkState == pkStateConst.PREPARE
        and self:getTodayBeInvitedAndNotOpen() == true
    local priority = ICON_V2_NORMAL_PRIORITY
    if self:_isIconV2TomorrowPriorityDemotionEnabled()
        and stateEnabled
        and pkState == pkStateConst.PREPARE
        and not hasLeftTimes
    then
        priority = ICON_V2_TOMORROW_PRIORITY
    end

    local nowInMillis = TimeKit:timeInMillis()
    local iconAnimation = iconStateConst.IDLE
    if pkState == pkStateConst.INGAME then
        local doubleStartTime = tonumber(model:getDoubleStartTime()) or 0
        local doubleEndTime = tonumber(model:getDoubleEndTime()) or 0
        if nowInMillis >= doubleStartTime and nowInMillis < doubleEndTime then
            iconAnimation = iconStateConst.DOUBLE
        else
            iconAnimation = iconStateConst.INGAME
        end
    end

    local beginTime = tonumber(model:getBeginTime()) or 0
    local mainBeginTime = tonumber(model:getMainBeginTime()) or 0
    local mainEndTime = tonumber(model:getMainEndTime()) or 0
    local endTime = tonumber(model:getEndTime()) or 0
    local phaseStartTime = mainBeginTime
    local phaseEndTime = mainEndTime
    if phase == ICON_V2_PHASE_PREHEAT then
        phaseStartTime = beginTime
        phaseEndTime = mainBeginTime
    elseif phase == ICON_V2_PHASE_REWARD then
        phaseStartTime = mainEndTime
        phaseEndTime = endTime
    end

    return {
        dataReady = activityReady,
        activityReady = activityReady,
        pkDataReady = pkDataReady,
        enabled = canShowIcon,
        periodKey = self:getDataByKey("periodId") or mainEndTime,
        phase = phase,
        pkState = pkState,
        matchState = matchState,
        settlementPending = settlementPending,
        settlementConfirmed = settlementConfirmed,
        matchStartTime = toSeconds(self:getDataByKey("matchRefBean.matchInfo.startTime")),
        matchEndTime = currentMatchEndTime,
        phaseStartTime = phaseStartTime,
        phaseEndTime = phaseEndTime,
        myScore = myScore,
        enemyScore = enemyScore,
        leftTimes = leftTimes,
        hasReward = hasReward,
        invitationPending = invitationPending,
        isLastDay = model:isLastDay(),
        priority = priority,
        iconAnimation = iconAnimation,
    }
end

-- 收集物icon
function Manager:createCollectIcon()
    local icon = UICreateUtil:createSpriteFile("amf/activity/magicrush/materials/collectIcon.png", true)
    return icon
end

function Manager:checkIsContinueRewardRound() return self:getModel():checkIsContinueRewardRound() end

-- 获取额外精力
function Manager:checkGetExtraPower()
    local joinRewards = self:getDataByKey("joinRewards") or {}
    return (not table.isEmpty(joinRewards)) and self:isInPrepare() and self:checkHasLeftTimes()
end

-- 主面板展示分数
function Manager:getOldShowScore()
    local myScore, enemyScore = self:getModel():getLastScoreMainPanel()
    if not myScore or not enemyScore then
        local myScore, enemyScore = 0, 0
        return {
            myScore = myScore,
            enemyScore = enemyScore,
        }
    else
        return {
            myScore = myScore,
            enemyScore = enemyScore,
        }
    end
end

function Manager:setOldShowScore(showScore)
    if not showScore then return end
    self:getModel():setLastScoreMainPanel(showScore.myScore, showScore.enemyScore)
end

function Manager:setMainPanelOpenedThisPeriod(flag)
    local period = self:getDataByKey("periodId") or 0
    self:setLocalCache("MainPanelOpenedThisPeriod" .. period, flag)
end

function Manager:getMainPanelOpenedThisPeriod()
    local period = self:getDataByKey("periodId") or 0
    return self:getLocalCache("MainPanelOpenedThisPeriod" .. period)
end

-- 今天开过主面板
function Manager:setMainPanelOpenedToday(flag)
    self:getModel():setLocalCache("mainPanelOpenedToday", flag)
    if flag and self:getTodayBeInvitedAndNotOpen() then
        self:setTodayBeInvitedAndNotOpen(false)
        self:refreshIconView("magicRushInvitationOpened", {
            actId = self:getConst().actId,
        })
    end
end

function Manager:isMainPanelOpenedToday()
    return self:getModel():getLocalCache("mainPanelOpenedToday")
end

function Manager:getScoreRate()
    local myScore, enemyScore = self:getMatchScore()
    local rate =  myScore / (myScore + enemyScore)
    return rate
end

-- 计算胜利状态（获胜是险胜还是完胜）
function Manager:isNarrowVictory()
    if self:isNewVersion() then
        local myScore, enemyScore = self:getMatchScore()
        if myScore - enemyScore >= 15000 or myScore >= enemyScore * 1.5 then
            return false
        else
            return true
        end
    else
        local rate = self:getScoreRate()
        return rate >= 0.5 and rate < 0.6
    end
end

-- 完胜
function Manager:isCompleteVictory()
    local rate = self:getScoreRate()
    return rate >= 0.6
end

function Manager:addGuideIndex(index)
    local guideSet = self:getDataByKey("guideSet") or {}
    table.insert(guideSet, index)

    local ActCommonHttp = require "amf.middleware.activity.http.ActCommonHttp"
    ActCommonHttp:setActGuideFlag(self:getConst().actId, index, true)
end

function Manager:hasGuideIndex(index)
    local guideSet = self:getDataByKey("guideSet") or {}
    for _, v in ipairs(guideSet) do
        if v == index then
            return true
        end
    end
    return false
end

----------------------------------------------关卡内-------------------------------------------------------
-- 关卡内触发条件
function Manager:isEnabledInLevel(data)
    self:setLastPassLevelData(nil)
    if not self:isEnabled() then return false end
    if self:hasUnclaimedReward() then return false end
    local extraData = data.extraData
    if extraData and extraData.isCheckSlpBottom then
        return true
    end
    -- 未进组
    if self:isInPrepare() then return false end

    return true
end

-- 是否为首闯实验组
function Manager:isFirstPlayGroup()
    local group = self:getDataByKey("group")
    return group == "ON1"
end

-- 是否为连胜实验组
function Manager:isWinningStreakGroup()
    local group = self:getDataByKey("group")
    return group == "ON2"
end

-- 连胜次数
function Manager:getWinningStreakCount()
    if not self:isRacing() then return 0 end
    return self:getDataByKey("matchRefBean.matchInfo.continueWin") or 0
end

-- 是否有连胜收集物加成
function Manager:hasWinningStreakCollectRate()
    local isWinningStreakGroup = self:isWinningStreakGroup()
    if not isWinningStreakGroup then return false end
    local winningStreakCount = self:getWinningStreakCount()

    return winningStreakCount >= 3
end

function Manager:getEnemyProfile()
    if not self:isEnabled() then return end
    return self:getDataByKey("matchRefBean.enemyProfile") or {}
end

-- 最后15min收集物加成结束时间
function Manager:getTimeLimitRateEndTime()
    if not self:isInDoubleState() then return 0 end
    return self:getDoubleEndTime()
end

function Manager:checkFirstMatch()
    local show = self:getLocalCache("firstMatchShow")
    if not show then
        self:setLocalCache("firstMatchShow", true)
    end
    return not show
end

-- 是否为对局进入后15min后，首次进入开始面板
function Manager:checkFirstMatchDouble(strKey)
    if not strKey then strKey = "" end
    local isInDoubleState = self:isInDoubleState()
    if not isInDoubleState then return false end

    local show = self:getLocalCache("firstMatchShowDouble"..strKey)
    if not show then
        self:setLocalCache("firstMatchShowDouble"..strKey, true)
    end
    return not show
end

-- 屏蔽新关top30（关卡内调用版本）
function Manager:ignoreTopPlayerInLevel(levelId, levelScene)
    if not levelId then
        return
    end

	return _G.amfBean("AutoPopupMgr"):ignoreForTopLevelPlayer(levelId, levelScene)
end

-- 关卡内活动启动数据
function Manager:getInLevelActData(levelId, runtime)
    local myScore, enemyScore = self:getMatchScore()
    local buffEndTime = self:getTimeLimitRateEndTime()
    local matchEndTime = self:getMatchEndTime()
    if matchEndTime > 0  and matchEndTime < 10000000000 then
        -- 认为是秒数，转成毫秒
        matchEndTime = matchEndTime * 1000
    end
    local inLevelActData = {
        --新关期间，屏蔽进场动画
        banMatchAnim = self:ignoreTopPlayerInLevel(levelId, runtime:getLevelScene()),
        -- 过关时候可以获得的保底数量，来自配置
        baseCollectCount = self:getConfigByKey("baseCollectCount") or 0,
        -- 收集物最大基础值
        maxCollect = self:getConfigByKey("maxCollect") or 0,
        -- 是否有连胜加成
        hasWinningStreakRate = self:hasWinningStreakCollectRate(),
        isWinningStreakGroup = self:isWinningStreakGroup(),
        -- 是否有限时buff
        hasTimeLimiteBuff = self:isInDoubleState(),
        -- 限时buff结束时间
        buffEndTime = tonumber(buffEndTime),
        isFirstMatch = self:checkFirstMatch(),
        matchEndTime = matchEndTime,
        enemyScore = enemyScore,
        myScore = myScore,
        -- 当前是第几轮
        pkRound = self:getPkRound(),
        -- 是否为大奖轮
        isGrandPrizeRound = self:checkIsContinueRewardRound(),
        myWinningStreakCount = self:getDataByKey("myHistoryInfo.pkContinueWinNum") or 0,
        enemyWinningStreakCount = self:getDataByKey("matchRefBean.enemyInfo.pkContinueWinNum") or 0,
    }

    if LevelSceneFunc:isFullLevelLib(runtime.levelScene) then
        inLevelActData.isFirstPlay = UBFActHelper:checkIsFsllFirstPlay(levelId, runtime.levelScene)
    end

    return inLevelActData
end

-- 打关结束时更新数据
function Manager:updatePassLevelData(data, collectionCount, collectionMap)
    self._passLevelFail = false
    if data.settleMentState then
        if self:isRacing() then
            local tireCount = collectionCount or 0
            self:addCollectionCount(tireCount)
            if tireCount > 0 and _G.WeekTaskType and _G.WeekTaskType.MAGIC_RUSH_COLLECT_TIRE then
                WeekTaskEventCenter:dispatch(_G.WeekTaskEvent.ACT_TASK_COMPLETE, {
                    type = _G.WeekTaskType.MAGIC_RUSH_COLLECT_TIRE,
                    num = tireCount,
                })
            end
            self:addMyPKContinueWinNum()
            local modEnvData = data.modEnvData
            self:setLastPassLevelData({
                enemyOldScore = modEnvData.enemyScore or 0,
                myOldScore = modEnvData.myScore or 0,
            })
            self.inLevelBridgeModule:tryUpdateElData()
        end
    else
        self:resetMyPKContinueWinNum()
        self._passLevelFail = true
    end
end

-- 增加收集物
function Manager:addCollectionCount(collectionCount)
    self:getModel():addMyScore(collectionCount)
end

-- 增加连胜
function Manager:addMyPKContinueWinNum()
    self:getModel():addMyPKContinueWinNum()
end

-- 重置连胜
function Manager:resetMyPKContinueWinNum()
    self:getModel():resetMyPKContinueWinNum()
end

function Manager:setDailyPopupFlag()
    self:getModel():saveFlagToLocalByKey("magicRushDailyPopupFlag", true)
end

function Manager:getDailyPopupFlag()
    return self:getModel():getFlagFromLocalByKey("magicRushDailyPopupFlag", true)
end

--累胜tip自动弹出标记
function Manager:setWinCountPopFlag()
    self:getModel():saveFlagToLocalByKey("magicRushWinCountPopFlag", false)
end

function Manager:getWinCountPopFlag()
    return self:getModel():getFlagFromLocalByKey("magicRushWinCountPopFlag", false, true)
end

-- 开始面板吊牌是否处于最高优先级
function Manager:isStartGamePanelHighPriority()
    if (self:getTodayBeInvitedAndNotOpen() or EnvUtil:isMiniGame())
        and self:isMainPanelOpenedToday()
        and self:getMainPanelOpenedThisPeriod()
        and self:getTodayLeftTimes() == self:getTodayLimitNum()
        and self:isInPrepare()
        and not self:getStartDownPartHignPriorityShowedToday() then
            return true
    end
    return false
end

-- 开始面板吊牌是否可以展示匹配按钮
function Manager:isCanShowMatchButton()
    return self:isInPrepare() and self:checkHasLeftTimes()
end

-- 开始面板的优先级
function Manager:getStartGamePanelPriority()
    local isHighPriority = self:isStartGamePanelHighPriority()
    local isLowPriority = self:isRacing()
    if isHighPriority then
        return "High"
    elseif isLowPriority then
        return "Low"
    end
end

function Manager:getPassLevelPanelPriority()
    return "High"
end

-- 开始面板下方吊牌数据
function Manager:getSlpBottomData(params)
    local isPlp = params.isPlp
    local level_bank, matchEndTime
    local canShowMatchButton = self:isCanShowMatchButton() and not isPlp
    local myScore, enemyScore = self:getMatchScore()
    local isRetry = params.isRetry
    local lastPassLevelData = self:getLastPassLevelData()
    if isPlp and not lastPassLevelData then
        return
    end

    if UBFLevelSceneFunc:isFullLevelLib(params.levelScene) then
        level_bank = params.fsllInfo and params.fsllInfo.levelIndex or 0
    end
    if not canShowMatchButton then
        matchEndTime = self:getMatchEndTime()
        if matchEndTime > 0  and matchEndTime < 10000000000 then
            -- 认为是秒数，转成毫秒
            matchEndTime = matchEndTime * 1000
        end
    end

    local slpBottomData = {
        canShowMatchButton = canShowMatchButton,
        matchEndTime = matchEndTime,
        enemyScore = enemyScore,
        myScore = myScore,
        isPlp = params.isPlp,
        lastPassLevelData = lastPassLevelData,
        isFirstPlay = UBFActHelper:ubfCheckIsFirstPlay(params.levelId, params.topLevelFailCount, params.levelScene),
        levelSupportType = UBFActHelper:getPlayLevelModeType(params.levelId, nil, params.levelScene),
        isInDoubleState = self:isInDoubleState(),
        isGrandPrizeRound = self:checkIsContinueRewardRound(),
        isDoubleTimeFirstEnterSlp = self:checkFirstMatchDouble() and not isPlp,
        isWinningStreakGroup = self:isWinningStreakGroup(),
        winningStreakCount = isRetry and 0 or self:getWinningStreakCount(),
        enemyProfile = self:getEnemyProfile(),
        difficultyFlag = params.difficultyFlag,
        myProfile = _G.amfBean("ProfileManager"):getProfile(),
        onClickViewDetails = function ()
            self:createDescPanel()
        end,
        showRecordTip = function (target, callback)
            return self:createEnemyTip(target, callback)
        end,
        requestJoin = function (successCallback, failCallback)
            self:requestJoin(successCallback, failCallback, 2)
        end,
        enterViewCallBack = function ()
            if canShowMatchButton then
                self:setStartDownPartHignPriorityShowedToday(true)
            end
        end,
        -- 打点相关数据
        dcParams = {
            start_show = {
                t6 = params.sourceId,
                level_bank = level_bank
            },
        }
    }
    if LevelSceneFunc:isFullLevelLib(params.levelScene) then
        slpBottomData.isFirstPlay = UBFActHelper:checkIsFsllFirstPlay(params.levelId, params.levelScene)
    end

    return slpBottomData
end

function Manager:onActBeforeStartLevel(event)
    if not self:isEnabled() then return end
    local data = event:getData()
    local sourceId = UBFActivityIdConst.kMagicRush
    local oldStar, oldScore = UBFActHelper:getOldStarAndScore(data.levelId)
    local runtime = {
        sourceId = sourceId,
        levelId = data.levelId,
        levelType = data.levelType,
        startLevelType = UBFStartLevelType.kCommon,
        oldScore = oldScore,
        oldStar = oldStar,
        levelScene = data.levelScene or LevelScene.kDefault,
    }
    if not UBFActHelper:checkActOpenCondition(runtime) then return end
    data.jsonTable[tostring(sourceId)] = {isMagic1v1Stage = true}
end

function Manager:onActCrashResumeFailed(event)
    local data = event:getData()
    if not data or not data.resumeData or not data.levelId then return end
    if not self:isEnabled() then return end
    local resumeData = data.resumeData
    if resumeData:hasGameMod(UBFActivityIdConst.kMagicRush) then
        if data.json then
            data.json[tostring(UBFActivityIdConst.kMagicRush)] = {isMagic1v1Stage = true}
        end
    end
end

function Manager:openActivity(delegate)
    self.actPlug:openActivity(delegate)
end

function Manager:getActShowName()
    local const = require(self:_getConstPath())
    return const.ACT_CH_NAME
end

function Manager:isOpen()
    return self:isEnabled()
end

function Manager:createActIconNode()
    local node = UICreateUtil:createSpriteFile("amf/activity/magicrush/materials/collectIcon.png")
    return node
end

function Manager:getActInfoExtraData()
    return self.actPlug:getActInfoExtraData()
end

function Manager:setLastPassLevelData(data)
    if MaintenanceManager:getInstance():isEnabledInGroup("magic_1v1_v2", "ON2") then
        self.lastPassLevelData = data
    end
end

function Manager:getLastPassLevelData()
    if MaintenanceManager:getInstance():isEnabledInGroup("magic_1v1_v2", "ON2") then
        return self.lastPassLevelData
    end
end

return Manager
