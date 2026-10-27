local MainPanelConfig = require "amf.feature.dailyreward.promotedaily.config.MainPanelConfig"
local PromoteDailyEventCenter = require "amf.feature.dailyreward.promotedaily.event.PromoteDailyEventCenter"
local MedalShowPanelVM = require "amf.feature.dailyreward.promotedaily.view.MedalShowPanelVM"
local deferred = require "amf.script.sugar.deferred"
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local Utils = require "amf.feature.dailyreward.promotedaily.util.Utils"
local ScreenShotEventCenter = require "amf.testtrack.dc.screenshot.event.ScreenShotEventCenter"
local MainPanelVM = class("PromoteDailyMainPanelVM", AMFBasePanelVM)

local EVENT_BINDINGS = {
    {PromoteDailyEvent.OPEN_HELP_PANEL, "openHelpPanel"},
    {PromoteDailyEvent.OPEN_7DAY_PANEL, "open7DayPanel"},
    {PromoteDailyEvent.GET_7DAY_REWARD, "on7DayRewardTapped"},
    {PromoteDailyEvent.OPEN_MONTH_ALLREWARD_PANEL, "openMonthAllRewardPanel"},
    {PromoteDailyEvent.CLICK_TO_RECOVER, "onClickToRecover"},
    {PromoteDailyEvent.CLICK_TO_LEVEL, "onGoToLevel"},
    {PromoteDailyEvent.SHOW_MEDAL_PANEL, "clickToShowMedalPanel"},
    {PromoteDailyEvent.EVENT_SIGN_SUCCESS, "onSignSuccess"},
    {PromoteDailyEvent.CLICK_TO_MAKEUP, "onClickToMakeUp"},
    {PromoteDailyEvent.ADD_OUTCLICK_LAYER, "onAddOutClickLayer"},
    {PromoteDailyEvent.RM_OUTCLICK_LAYER, "onRemoveOutClickLayer"},
    {PromoteDailyEvent.MAIN_CLICK_DC, "onMainClickDC"},
    {PromoteDailyEvent.OPEN_HIGH_LIGHT_PANEL, "onOpenHighLightPanel"},
    {PromoteDailyEvent.OPEN_BUY_SHIELD_PANEL, "openBuyShieldPanel"},
    {PromoteDailyEvent.OPEN_TASK_PREVIEW_PANEL, "openTaskPreviewPanel"},
    {PromoteDailyEvent.OPEN_LITTLETIP_PANEL, "openLittleTipPanel"},
    {PromoteDailyEvent.GET_NEW_TASKREWARD, "on7DayRewardTapped"},
    {PromoteDailyEvent.UPDATE_SHILED_NODE, "onRefreshShieldNode"},
    {PromoteDailyEvent.REPAIR_ACT_UPDATE, "onRepairActUpdate"},
}

function MainPanelVM:_createPanel(delegate)
    local MVVMEmptyPanel = require_debug "amf.feature.dailyreward.promotedaily.view.MainPanel"
    local panel = MVVMEmptyPanel:create(MainPanelVM, delegate)
    return panel
end

function MainPanelVM:init(delegate)
    delegate = delegate or {} 
    self:setCloseCallback(delegate.closeCallback)
    self._promoteDailyMgr = _G.amfBean("PromoteDailyMgr")
    self._subMsgMgr = _G.amfBean("SubMsgManager")
    self._assetsUtil = _G.amfBean("AssetsUtil")
    self._retainResMap = {}
    self._yearResLoadMap = {}
    self._navigationGeneration = 0
    self:resetInfo()
    self:registerEvent()

    -- 点进来就标记已经引导
    if not self._promoteDailyMgr:hasGuideIndex(PromoteDailyConst.GuideId.ID2) then
        self._promoteDailyMgr:addGuideIndex(PromoteDailyConst.GuideId.ID2)
    end

    self.panelId = UICreateUtil:getPanelId("PromoteDailyMain")
    -- 打点
    local t1 = delegate.t1 or 2
    local t2 = self._promoteDailyMgr:getContinousPassDayCount()
    local t3 = 2
    if self._promoteDailyMgr:getTaskCanReward() then
        t3 = 1
    elseif self._promoteDailyMgr:getTaskRewarded() then
        t3 = 3
    end
    local t4 = self._promoteDailyMgr:getTodaySignState() == PromoteDailyConst.SignState.NONE and 2 or 1
    local param = {
        panel_id = self.panelId,
        t1 = t1,
        t2 = t2,
        t3 = t3,
        t4 = t4
    }
    self:handleMainDcParam(param)
    self._promoteDailyMgr:dc(PromoteDailyConst.FEATURE, "main_panel_show", param)

    self:_initCanPlayNewToOldAnim()
    self:_initShiledState()
end

function MainPanelVM:_initShiledState()
    -- 记录被保护的数据列表，动画用
    self._shieldDateList = {}
    local useList = self._promoteDailyMgr:getShieldRecordList(true)
    if #useList > 0 then
        self._shieldDateList = self._promoteDailyMgr:getShiledDateInfoByLimit(#useList > 2 and 2 or #useList)
        -- 获取使用的盾牌最早的获得时间
        local minOwnDayNum
        for i, v in ipairs(useList) do
            local dayNum = TimeUtil:getDayIdxSince1970(v.showTime)
            minOwnDayNum = minOwnDayNum and math.min(minOwnDayNum, dayNum) or dayNum
        end
        -- 如果比获取时间早就丢弃
        for i = #self._shieldDateList, 1, -1 do
            local data = self._shieldDateList[i]
            local dayNum = data.dayNum
            if minOwnDayNum and dayNum < minOwnDayNum then
                table.remove(self._shieldDateList, i)
            end
        end
        -- 这里判断有没有播过
        for i = #self._shieldDateList, 1, -1 do
            local data = self._shieldDateList[i]
            local dayNum = data.dayNum
            if self._promoteDailyMgr:isUseShieldShowed(dayNum) then
                table.remove(self._shieldDateList, i)
            end
        end

        if #self._shieldDateList > 0 then
            self._initAddCount = #self._shieldDateList
            self._promoteDailyMgr:addShieldNum(#self._shieldDateList)
        end
    end
    local ownList = self._promoteDailyMgr:getShieldRecordList(false)
    -- 先把数据改了，后边会再刷回来
    if #ownList > 0 then
        -- 有获得也有使用，直接把第一次赠送标记加上
        if #useList > 0 then
            self._promoteDailyMgr:addGuideIndex(PromoteDailyConst.GuideId.FIRST_OWN_SHIELD)
        end
        self._initMinusCount = #ownList
        -- 如果获得了盾牌,先减去
        self._promoteDailyMgr:addShieldNum(-#ownList)
        self._promoteDailyMgr:setIconTipPopCount(0)
        local title = ""
        for i, v in ipairs(ownList) do
            local dayNum = TimeUtil:getDayIdxSince1970(v.showTime)
            local date = Utils:getYMDByDayCount(dayNum)
            if title == "" then
                title = date.month
            else
                if title ~= date.month then
                    title = title .. "、" .. date.month
                end
            end
        end
        title = title .. "月免费赠送"
        if not self._promoteDailyMgr:hasGuideIndex(PromoteDailyConst.GuideId.FIRST_OWN_SHIELD) then
            self._promoteDailyMgr:addGuideIndex(PromoteDailyConst.GuideId.FIRST_OWN_SHIELD)
            title = "免费赠送"
        end
        self.getShieldTitle = title     
    end
end

function MainPanelVM:_nextNavigationGeneration()
    self._navigationGeneration = self._navigationGeneration + 1
    return self._navigationGeneration
end

function MainPanelVM:_isNavigationCurrent(generation)
    return not self.isDisposed and generation == self._navigationGeneration
end

function MainPanelVM:_finishSupersededNavigation(navigation)
    navigation:resolve({superseded = true})
end

function MainPanelVM:handleMainDcParam(param)
    param.t3 = -1
    if self._promoteDailyMgr:getDataValue("chooseTaskOK") then
        local curTargetData = self._promoteDailyMgr:getCurTaskTargetData() or {}
        param.t3 = curTargetData.target
        local newTaskCanReward = self._promoteDailyMgr:hasTargetTaskCanReward()
        param.t4 = 2
        if newTaskCanReward then
            param.t4 = 1
        end
    end
    param.t5 = self._promoteDailyMgr:getTodaySignState() ~= PromoteDailyConst.SignState.NONE and 1 or 2
    param.t6 = self._promoteDailyMgr:getTotalHandPropNum()
    param.t7 = self._promoteDailyMgr:getShieldNum()
    -- t8：是否处于重燃活动中（1 正常状态 / 2 在重燃活动中）
    param.t8 = self._promoteDailyMgr:isRepairActInProgress() and 2 or 1
end

function MainPanelVM:resetInfo()
    self._year = self._promoteDailyMgr:getYear()
    self._month = self._promoteDailyMgr:getMonth()
    self._day = self._promoteDailyMgr:getDay()
end

function MainPanelVM:firstLoadCompleted()
    local uiContext, contextErr = MainPanelConfig:resolveMonthContext(self._year, self._month)
    assert(uiContext, contextErr)
    self:callViewFunc("initButton")
    self:callViewFunc("initUI", {
        year = self._year,
        month = self._month,
        day = self._day,
        uiContext = uiContext,
    })
    self:callViewFunc("initHangTag")
    self:callViewFunc("initShield")
    local initialYearKey = tostring(self._year)
    local initialYearRes = MainPanelConfig:getYearResList(self._year)
    local transferred = self:callViewFunc("transferAutoYearResOwnership", initialYearRes) or {}
    if #transferred > 0 then
        self._retainResMap[initialYearKey] = transferred
    end
    self._activeResYear = self._year
    self:_updateView()
end

-- function MainPanelVM:secondLoadCompleted()
    
-- end

-- 配置和数据是否可用
function MainPanelVM:_isConfigAndDataEnabled(year, month)
    local cfg = MainPanelConfig:isMonthSupported(year, month)
    local data = self._promoteDailyMgr:getMonthDataByYM(year, month)
    return cfg and data
end

-- 更新箭头
function MainPanelVM:_updateArrow()
    local tarYear, tarMonth = Utils:getLeftYM(self._year, self._month)
    if not self:_isConfigAndDataEnabled(tarYear, tarMonth) then
        self:callViewFunc("setLeftArrowVisible", false)
    else
        self:callViewFunc("setLeftArrowVisible", true)
    end
    tarYear, tarMonth = Utils:getRightYM(self._year, self._month)
    if not self:_isConfigAndDataEnabled(tarYear, tarMonth) then
        self:callViewFunc("setRightArrowVisible", false)
    else
        self:callViewFunc("setRightArrowVisible", true)
    end
end

function MainPanelVM:_updateView(calendarDir)
    if self.isDisposed then return deferred.success() end
    local uiContext, contextErr = MainPanelConfig:resolveMonthContext(self._year, self._month)
    if not uiContext then return deferred.error(contextErr) end
    if self._viewTransition then
        self._viewTransition:reject("promotedaily transition superseded")
        self._viewTransition = nil
    end
    local transition = deferred.new()
    self._viewTransition = transition
    self:_updateArrow()
    local param = {
        year = self._year,
        month = self._month,
        day = self._day,
        uiContext = uiContext,
        direction = calendarDir,
    }
    local retiringYear = self._retiringResYear
    self:callViewFuncWithCallback("updateWithTransition", function()
        if self.isDisposed then return transition:reject("promotedaily main panel disposed") end
        if self._viewTransition ~= transition then
            return transition:reject("promotedaily transition superseded")
        end
        self._viewTransition = nil
        if retiringYear and retiringYear == self._retiringResYear and retiringYear ~= self._activeResYear then
            self:_releaseYearRes(retiringYear)
            self._retiringResYear = nil
        end
        transition:resolve()
    end, param)
    self:_updateBackToCur()
    self:_updateNewRecord()
    self:_updateNewUIs()
    return transition
end

function MainPanelVM:_releaseYearRes(year)
    local yearKey = tostring(year)
    local resList = self._retainResMap[yearKey]
    if not resList then return end
    self._promoteDailyMgr:releaseRes(resList)
    self._retainResMap[yearKey] = nil
end

function MainPanelVM:_releaseUnusedYearRes(year)
    if year == self._activeResYear or year == self._retiringResYear or year == self._pendingNavigationYear then return end
    self:_releaseYearRes(year)
end

function MainPanelVM:_finishPendingYearTransition()
    self:callViewFunc("finishPendingVisualTransition")
    if self._retiringResYear and self._retiringResYear ~= self._activeResYear then
        self:_releaseYearRes(self._retiringResYear)
    end
    self._retiringResYear = nil
end

function MainPanelVM:_activateYearRes(year)
    if self._activeResYear == year then return end
    self:_finishPendingYearTransition()
    self._retiringResYear = self._activeResYear
    self._activeResYear = year
end

function MainPanelVM:_updateNewUIs()
    if self:isUseNewUI() then
        self:callViewFunc("updateNewUIsVisible", true)
        self:callViewFunc("updateHangTag")
        self:callViewFunc("updateShield")
    else
        self:callViewFunc("updateNewUIsVisible", false)
    end
end

function MainPanelVM:_updateBackToCur()
    if self._promoteDailyMgr:getYear() == self._year and self._promoteDailyMgr:getMonth() == self._month then
        self:callViewFunc("setBackToCurBtnVisible", false)
    else
        self:callViewFunc("setBackToCurBtnVisible", true)
    end
end

function MainPanelVM:_updateNewRecord()
    -- 活动期间不展示「新记录」标签
    if self._promoteDailyMgr:isRepairActInProgress() then
        self:callViewFunc("updateBtnRecord", "")
        return
    end
    local newRecord = self._promoteDailyMgr:getNewRecordState()
    local hasNewShow = self._promoteDailyMgr:getLocalValue("btnRecordNewTagShow")
    if newRecord then
        self:callViewFunc("updateBtnRecord", "新记录", 0.8)
    elseif hasNewShow then
        self:callViewFunc("updateBtnRecord", "新", 1)
    else
        self:callViewFunc("updateBtnRecord", "")
    end
end

function MainPanelVM:_tryShowKeyDayMedalPanel()
    -- 如果今天未签到，并且是纪念日，强弹出纪念日界面
    local td = deferred.new()
    local medalCfg, idx = self._promoteDailyMgr:getFutureKeyDayByLimit()
    if not medalCfg then
        return td:resolve()
    end
    -- 不是今天
    if idx > 0 then
        -- 是否弹过
        local hasPop = self._promoteDailyMgr:getLocalValue("mainPopMedalAlarm_"..medalCfg.medalId)
        if hasPop then
            return td:resolve()
        end
        -- 是否添加了推送，添加了就不弹了
        if EnvUtil:isApp() then
            if self._promoteDailyMgr:hasRegPush(medalCfg.medalId) then
                return td:resolve()
            end
        elseif EnvUtil:isMiniGame() then
            if not self._subMsgMgr or not self._subMsgMgr:canShowSubMsgNode(SubMessageConst.SceneType.PROMOTEDAILY) then
                return td:resolve()
            end
        end
        self._promoteDailyMgr:setLocalValue("mainPopMedalAlarm_"..medalCfg.medalId, true)
        PromoteDailyEventCenter:dispatch(PromoteDailyEvent.SHOW_MEDAL_PANEL, {
            medalId = medalCfg.medalId,
            dayNum = self._promoteDailyMgr:getTodayNum() + idx,
            closeCallback = function()
                td:resolve()
            end
        })
    else
        local todaySigned = self._promoteDailyMgr:getTodaySignState() ~= PromoteDailyConst.SignState.NONE
        local keyDayCfg = self._promoteDailyMgr:hasKeyDayMedal(self._promoteDailyMgr:getYear(), self._promoteDailyMgr:getMonth(), self._promoteDailyMgr:getDay())
        -- 今天
        if todaySigned then
            return td:resolve()
        end
        self:_showMedalPanel({
            showType = MedalShowPanelVM.ShowType.LEVEL,
            medalId = keyDayCfg.medalId,
            closeCallback = function()
                td:resolve()
            end
        })
    end      
    return td
end

function MainPanelVM:_tryGetAllRewards()
    local hasReward = false
    local d = deferred.new()
    deferred.success()
    :next(function()
        if self.isDisposed then return d:resolve() end
        local td = deferred.new()
        -- 检查所有可以领取的奖励 包含今天, 奖励存起来
        self._promoteDailyMgr:tryGetAllRewards(true):next(function(randomReward)
            if self.isDisposed then return td:resolve() end
            randomReward = randomReward or {}
            if table.isEmpty(randomReward) then
                return td:resolve()
            end
            hasReward = true
            -- 高光时刻新字
            self._promoteDailyMgr:setLocalValue("btnRecordNewTagShow", true)
            local medalId = Utils:getMedalFromShopRewards(randomReward)
            if medalId and medalId > 0 then
                self:_showMedalPanel({
                    medalId = medalId,
                    showType = MedalShowPanelVM.ShowType.REWARD,
                    closeCallback = function()
                        self:openHighLightPanel({
                            t1 = 2,
                            closeCallback = function()
                                td:resolve()
                            end
                        })
                    end
                })
            else
                self._promoteDailyMgr:showShopRewardsPanel(randomReward):next(function()
                    td:resolve()
                end)
            end
        end)
        return td
    end)
    :next(function()
        if self.isDisposed then return d:resolve() end
        local td = deferred.new()
        self._promoteDailyMgr:tryGetTaskReward():next(function(data)
            if self.isDisposed then return td:resolve() end
            if data and data.rewards then
                hasReward = true
                self._promoteDailyMgr:showArriveDailyPanel({
                    pageIndex = 2,
                    rewards = data.rewards,
                    bOldTask = data.bOldTask,
                    boxWorldPos = self:callViewFunc("getBottomBoxWorldPos"),
                }, function()
                    self._promoteDailyMgr:showSelectTargetPanel():next(function()
                        td:resolve()
                    end)
                end)
            else
                td:resolve()
            end
        end)
        return td
    end)
    :next(function()
        if self.isDisposed then return d:resolve() end
        if hasReward then
            self:callViewFunc("updateBottomNode", {
                forceSelfRefresh = true
            })
            -- 先刷新一下
            local uiContext, contextErr = MainPanelConfig:resolveMonthContext(self._year, self._month)
            assert(uiContext, contextErr)
            self:callViewFunc("updateCalendarNode", {
                year = self._year,
                month = self._month,
                day = self._day,
                uiContext = uiContext,
                isForceUpdate = true
            })
        end
        d:resolve()
    end)
    return d
end

function MainPanelVM:forceCardToUnSigned()
    for i, v in ipairs(self._shieldDateList) do
        self:callViewFunc("setCardUnSigned", v.year, v.month, v.day)
    end
end

function MainPanelVM:_tryGuide()
    local td = deferred.new()
    -- 1. 引导
    -- 第一次开启应该是没有PromoteDailyConst.GuideId.ID1
    if self._promoteDailyMgr:hasGuideIndex(PromoteDailyConst.GuideId.ID1) then
        if not self._promoteDailyMgr:hasGuideIndex(PromoteDailyConst.GuideId.IDNEW_1) then
            -- 记录引导过了
            self._promoteDailyMgr:addGuideIndex(PromoteDailyConst.GuideId.IDNEW_1)
            self:_showGuide1(function()
                self:callViewFuncWithCallback("showGuide2", function()
                    self:callViewFuncWithCallback("showGuide3", function()
                        self:callViewFuncWithCallback("showGuide4", function()
                            td:resolve()
                        end)
                    end)
                end)
            end)
        else
            td:resolve()
        end
    else
        if not self._promoteDailyMgr:hasGuideIndex(PromoteDailyConst.GuideId.IDOLD_1) then
            local contentList = {
                {ttf = "每日一关"},
                {ttf = "～祝你每日开心翻番！"},
            }
            self:callViewFuncWithCallback("showGuide2", function()
                -- 记录引导过了
                self._promoteDailyMgr:addGuideIndex(PromoteDailyConst.GuideId.IDOLD_1)
                self:callViewFuncWithCallback("showGuide3", function()
                    self:callViewFuncWithCallback("showGuide4", function()
                        td:resolve()
                    end)
                end)
            end, contentList)
        else
            td:resolve()
        end
    end
    return td
end

function MainPanelVM:_showGuide1(callback)
    local LevelUpGuidePanelVM = require "amf.feature.dailyreward.promotedaily.view.LevelUpGuidePanelVM"
    local vm = LevelUpGuidePanelVM:create({
        closeCallback = callback
    })
    vm:popout()
    self._promoteDailyMgr:addToMgr(vm)
end

-- 尝试弹说明
function MainPanelVM:_tryPopNewIntro()
    -- 2. 说明
    local td = deferred.new()
    if not self._promoteDailyMgr:hasGuideIndex(PromoteDailyConst.GuideId.INTRO_NEW) then
        -- 记录引导过了
        self._promoteDailyMgr:addGuideIndex(PromoteDailyConst.GuideId.INTRO_NEW)
        self._promoteDailyMgr:showActIntroPanel(1, function()
            td:resolve()
        end)
    else
        td:resolve()
    end
    return td
end

-- 尝试展示获得盾牌
function MainPanelVM:_tryShowGetShiled()
    local td = deferred.new()
    local ownList = self._promoteDailyMgr:getShieldRecordList(false)
    local count = #ownList
    if count == 0 then
        return td:resolve()
    end
    self:callViewFuncWithCallback("getShiledPos", function(targetWorldPos)
        local rewards = {
            {
                itemId = PromoteDailyConst.SHIELD_ID,
                num = count,
                flyFunc = function(reward, worldPos, bubbleScale, myCallback)
                    local rewardCopy = table.clone(reward)
                    rewardCopy.targetPos = ccp(targetWorldPos.x + 50, targetWorldPos.y - 50)
                    safeRunCall(myCallback)
                    local flyContext = FlyItemContext.new({rewardCopy}, worldPos):setFinishCallback(function()
                        -- 刷新shiled
                        self:callViewFunc("updateShield")
                    end)
                    _G.amfTransaction(TransactionEvent.FLY_ITEMS, flyContext)
                end
            }
        }
        
        local param = {
            title = self.getShieldTitle,
            subTitle = "太阳盾牌可保护连过天数！",
            buttonText = "装备"
        }
        -- 修改数量
        self._initMinusCount = 0
        self._promoteDailyMgr:addShieldNum(#ownList)
        self._promoteDailyMgr:showNormalRewardsPanel(rewards, param):next(function()
            td:resolve()
        end)
    end)
    return td
end

-- 尝试使用shiled
function MainPanelVM:_tryShowUseShiled()
    local td = deferred.new()
    if #self._shieldDateList == 0 then
        return td:resolve()
    end
    -- 把card上的日期先干掉
    for i, v in ipairs(self._shieldDateList) do
        self:callViewFunc("setCardLabelVisible", v.year, v.month, v.day, false)
    end
    self._initAddCount = 0
    self._promoteDailyMgr:addShieldNum(-#self._shieldDateList)
    local idx = 0
    local function _start()
        idx = idx + 1
        local data = self._shieldDateList[idx]
        if not data then
            self:callViewFunc("updateShield")
            if self._year == self._promoteDailyMgr:getYear() and self._month == self._promoteDailyMgr:getMonth() then
                td:resolve()
            else
                self:onBackToCurBtnTapped():next(function()
                    td:resolve()
                end, function()
                    td:resolve()
                end)
            end
            return td
        end
        local lastShowYear, lastShowMonth = self._year, self._month
        local lastDayNum = Utils:getDayNumByYMD(lastShowYear, lastShowMonth, 1)
        local nowDayNum = Utils:getDayNumByYMD(data.year, data.month, 1)
        local direction
        if nowDayNum < lastDayNum then
            direction = MainPanelConfig.CalendarAni.RIGHT
        elseif nowDayNum > lastDayNum then
            direction = MainPanelConfig.CalendarAni.LEFT
        end
        local function showShield(duringTransition)
            local function startFly()
                if self.isDisposed then return end
                self:callViewFuncWithCallback("flyShieldTo", function()
                    self:callViewFunc("setCardLabelVisible", data.year, data.month, data.day, true)
                    local nextData = self._shieldDateList[idx + 1]
                    local startNextOnArrival = nextData ~= nil
                    self:callViewFuncWithCallback("onSignSuccess", function()
                        self._promoteDailyMgr:setUseShieldShowed(data.dayNum)
                        if not startNextOnArrival then
                            TimerUtil.addAlarm(function()
                                if self.isDisposed then return end
                                _start()
                            end, 5/30)
                        end
                    end, data.year, data.month, data.day, false)
                    if startNextOnArrival then
                        TimerUtil.addAlarm(function()
                            if self.isDisposed then return end
                            _start()
                        end, 5/30)
                    end
                end, data.year, data.month, data.day, duringTransition)
            end
            if duringTransition then
                startFly()
            else
                TimerUtil.addAlarm(startFly, 1/30)
            end
        end
        if direction then
            self:_navigateTo(data.year, data.month, data.day, direction, function()
                showShield(true)
            end):next(function() end, function()
                td:resolve()
            end)
        else
            self._day = data.day
            showShield()
        end
    end
    self:_showUseShiledPanel(#self._shieldDateList):next(function(retList)
        if self.isDisposed then return td:resolve() end
        self:callViewFuncWithCallback("addShieldSpineToUI", function()
            _start()
        end, retList)
    end, function()
        td:resolve()
    end)
    
    return td
end

function MainPanelVM:_showUseShiledPanel(count)
    local d = deferred.new()
    local UseShiledPanelVM = require "amf.feature.dailyreward.promotedaily.view.UseShiledPanelVM"
    local vm = UseShiledPanelVM:create({
        callback = function(retList)
            d:resolve(retList)
        end,
        shieldCount = count,
    })
    vm:popout(nil, true)
    self._promoteDailyMgr:addToMgr(vm)
    return d
end

function MainPanelVM:_tryPlayRefreshTask()
    local d = deferred.new()
    if not self._promoteDailyMgr:getDataValue("chooseTaskOK") then
        if self.needNewToOldAni then
            self.needNewToOldAni = false
            self:callViewFuncWithCallback("refreshBottomTask", function()
                d:resolve()
            end, true, true)
        else
            self:callViewFunc("updateBottomNode")
            d:resolve()
        end
        return d
    else
        if not self._promoteDailyMgr:getTempValue("needFreshTaskUI") then
            return d:resolve()
        end
        self._promoteDailyMgr:setTempValue("needFreshTaskUI", false)
        local onlyTask = self._promoteDailyMgr:getTempValue("onlyFreshTaskUI")
        self:callViewFuncWithCallback("refreshBottomTask", function()
            d:resolve()
        end, onlyTask)
        self._promoteDailyMgr:setTempValue("onlyFreshTaskUI", false)
    end

    return d
end

function MainPanelVM:_startTalk(param)
    local td = deferred.new()
    self:callViewFuncWithCallback("startTalk", function()
        td:resolve()
    end, param)
    return td
end

function MainPanelVM:onEnterPanelRun()
    self:lock()
    if self.needNewToOldAni then
        self:callViewFunc("updateBottomNode", {
            usePath = "amf.feature.dailyreward.promotedaily.view.comps.nodes.BottomNodeV2",
            forceRefresh = true,
        })
    end
    deferred.success()
    :next(function()
        self:forceCardToUnSigned()
        return deferred.success()
    end)
    :next(function()
        if self.isDisposed then return end
        local td = deferred.new()
        TimerUtil.addAlarm(function()
            if self.isDisposed then return end
            td:resolve()
        end, 1/30)
        return td
    end)
    :next(function()
        if self.isDisposed then return end
        self._promoteDailyMgr:log( "MainPanelV2VM:onEnterPanelRun ----", "guide")
        -- 1. 引导
        return self:_tryGuide()
    end)
    :next(function()
        if self.isDisposed then return end
        self._promoteDailyMgr:log( "MainPanelV2VM:onEnterPanelRun ----", "intro")
        -- 2. 强弹说明
        return self:_tryPopNewIntro()
    end)
    :next(function()
        if self.isDisposed then return end
        -- 5. 盾牌使用（每日首次1次）
        self._promoteDailyMgr:log( "MainPanelV2VM:onEnterPanelRun ----", "useShield")
        return self:_tryShowUseShiled()
    end)
    :next(function()
        if self.isDisposed then return end
        -- 4. 盾牌首次赠送与每月赠送；
        self._promoteDailyMgr:log( "MainPanelV2VM:onEnterPanelRun ----", "getShield")
        return self:_tryShowGetShiled()
    end)
    :next(function()
        if self.isDisposed then return end
        -- 3. 补领奖
        self._promoteDailyMgr:log( "MainPanelV2VM:onEnterPanelRun ----", "allRewards")
        local td = deferred.new()
        self:_tryGetAllRewards():next(function()
            td:resolve()
        end)
        return td
    end)
    :next(function()
        if self.isDisposed then return end
        -- 7. 求助成功补过小手；
        self._promoteDailyMgr:log( "MainPanelV2VM:onEnterPanelRun ----", "helpReward")
        return self._promoteDailyMgr:tryGetHandPropReward()
    end)
    :next(function()
        if self.isDisposed then return end
        -- 9. 目标刷新（中断或闪退选择）
        self._promoteDailyMgr:log( "MainPanelV2VM:onEnterPanelRun ----", "refreshTask")
        return self:_tryPlayRefreshTask()
    end)
    :next(function()
        -- 10. 当日未过关-放大动画（每日首次1次）；
        if self.isDisposed then return end
        -- 今天如果没签到，播一下牌子的放大动画
        self._promoteDailyMgr:log( "MainPanelV2VM:onEnterPanelRun ----", "curDay anim")
        return self:_tryPlayCurDayNotSignAnim()
    end)
    :next(function()
        if self.isDisposed then return end
        -- 6. 纪念日提醒弹窗；
        self._promoteDailyMgr:log( "MainPanelV2VM:onEnterPanelRun ----", "keyDay Notice")
        return self:_tryShowKeyDayMedalPanel()
    end)
    :next(function()
        if self.isDisposed then return end
        local td = deferred.new()
        local key = "popFullSignDate_".. self._year.."_"..self._month
        local isPoped = self._promoteDailyMgr:getLocalValue(key)
        if self._promoteDailyMgr:isFullSign(self._year, self._month) and not isPoped then
            self._promoteDailyMgr:setLocalValue(key, true)
            self._promoteDailyMgr:showFullSignPanel({
                year = self._year,
                month = self._month,
                closeCallback = function()
                    td:resolve()
                end
            })
        else
            td:resolve()
        end
        return td
    end)
    :next(function()
        if self.isDisposed then return end
        -- 12. tips展示；小鸡tip
        self._promoteDailyMgr:log( "MainPanelV2VM:onEnterPanelRun ----", "chicken Tip")
        local useShield = false
        -- 使用了盾，并且shieldNum ~= 0,并且盾的使用是在连过内
        if #self._shieldDateList > 0 and self._promoteDailyMgr:getShieldNum() ~= 0 then
            for i, v in ipairs(self._shieldDateList) do
                if self._promoteDailyMgr:isContinousPassDay(v.year, v.month, v.day) then
                    useShield = true
                    break
                end
            end
        end
        self:_startTalk({
            useShield = useShield
        })
        return deferred.success()
    end)
    :next(function()
        if self.isDisposed then return end
        -- 设置盾牌展示过了
        self._promoteDailyMgr:setShiledRecordListShowed()
        self._shieldDateList = {}
        self:_updateView()
        self:unlock()
    end)
end

-- 别处调用展示勋章界面
function MainPanelVM:clickToShowMedalPanel(evt)
    local data = evt:getData()
    if not data.showType then
        local showType = MedalShowPanelVM.ShowType.OK
        if EnvUtil:isApp() or EnvUtil:isWindows() then
            showType = MedalShowPanelVM.ShowType.ALARM
        elseif self._subMsgMgr and self._subMsgMgr:isEnabled() and data.dayNum then
            local tb = Utils:getYMDByDayCount(data.dayNum)
            local medalCfg = self._promoteDailyMgr:getCurMonthNearestKeyMedal()
            -- 检查是否是最近的纪念日，如果是就去看添加提醒，如果不是就不处理
            if medalCfg and medalCfg.year == tb.year and medalCfg.month == tb.month and medalCfg.day == tb.day then
                showType = MedalShowPanelVM.ShowType.NOTIFY
            end
        end
        data.showType = showType
    end
    self:_showMedalPanel(data)
end

function MainPanelVM:_showMedalPanel(param)
    self._promoteDailyMgr:showMedalShowPanel(param)
end

function MainPanelVM:recycle()
    if self._viewTransition then
        self._viewTransition:reject("promotedaily main panel recycled")
        self._viewTransition = nil
    end
    self:_nextNavigationGeneration()
    PromoteDailyEventCenter:dispatch(PromoteDailyEvent.UPDATE_ICON)
    self:unregisterEvent()
    local UIEventCenter = require "amf.middleware.ui.event.UIEventCenter"
    UIEventCenter:dispatch(UIEvent.Remove.AUTO_TIP)
    -- 万一没播完动画，得还原回去
    if self._initMinusCount and self._initMinusCount > 0 then
        self._promoteDailyMgr:addShieldNum(self._initMinusCount)
        self._initMinusCount = 0
    end
    if self._initAddCount and self._initAddCount > 0 then
        self._promoteDailyMgr:addShieldNum(-self._initAddCount)
        self._initAddCount = 0
    end
    if self._yearResLoadMap then
        local loadingMap = self._yearResLoadMap
        self._yearResLoadMap = {}
        for _, loading in pairs(loadingMap) do
            loading:reject("promotedaily main panel recycled")
        end
    end
    if not table.isEmpty(self._retainResMap) then
        for _, resList in pairs(self._retainResMap) do
            self._promoteDailyMgr:releaseRes(resList)
        end
        self._retainResMap = {}
    end
    AMFBasePanelVM.recycle(self)
end

function MainPanelVM:registerEvent()
    for _, binding in ipairs(EVENT_BINDINGS) do
        PromoteDailyEventCenter:register(binding[1], self[binding[2]], self)
    end
    ScreenShotEventCenter:register(ScreenShotEvent.SCREENSHOT_DC, self.onScreenShotDc, self)
end

function MainPanelVM:unregisterEvent()
    for _, binding in ipairs(EVENT_BINDINGS) do
        PromoteDailyEventCenter:unregister(binding[1], self[binding[2]])
    end
    ScreenShotEventCenter:unregister(ScreenShotEvent.SCREENSHOT_DC, self.onScreenShotDc)
end

function MainPanelVM:onScreenShotDc(evt)
	if self.isDisposed then return end
    local data = evt:getData()
    data.extParam.t1 = 5
end

-- 重燃活动数据刷新（含补拉主信息成功）：吊牌 / 任务区域 / 新记录一起重算
function MainPanelVM:onRepairActUpdate()
    if self.isDisposed then return end
    self:_updateNewUIs()
    self:_updateNewRecord()
    self:callViewFunc("updateBottomNode")
end

-- bubble额外的点击层
function MainPanelVM:onAddOutClickLayer(evt)
    local data = evt:getData()
    self:callViewFunc("addOutClickLayer", data.clickCall, data.hitTestFunc)
end

function MainPanelVM:onRemoveOutClickLayer()
    self:callViewFunc("removeOutClickLayer")
end

-- 主面板点击打点
function MainPanelVM:onMainClickDC(evt)
    local data = evt:getData()
    self._promoteDailyMgr:dc(PromoteDailyConst.FEATURE, "main_panel_click", {
        panel_id = self.panelId,
        t1 = data.t1
    })
end

function MainPanelVM:_initCanPlayNewToOldAnim()
    -- 是否从新的任务刷成老的任务
    local oldState = self._promoteDailyMgr:getLocalValue("lastChooseIsOK")
    -- 上次是不是新的,默认是
    if oldState == nil then 
        oldState = true
    end
    local curOk = self._promoteDailyMgr:getDataValue("chooseTaskOK") -- 当前是不是新的
    local chooseData = self._promoteDailyMgr:getDataValue("chooseProgressTaskData") or {}
    local hasNewTaskData = chooseData.nowProgress ~= nil
    self.needNewToOldAni = false
    if oldState and not curOk and hasNewTaskData then
        self.needNewToOldAni = true
    end
    -- self._promoteDailyMgr:log("self._needNewToOldAnim ----", self.needNewToOldAni, oldState ,curOk, hasNewTaskData)
    self._promoteDailyMgr:setLocalValue("lastChooseIsOK", curOk)
end

function MainPanelVM:isUseNewUI()
    return MainPanelConfig:isNewUI(self._year, self._month)
end

-- 补翻二次确认面板
function MainPanelVM:onClickToMakeUp(evt)
    local data = evt:getData() or {}
    self._promoteDailyMgr:openAskForHandPanel(nil, data)

    if data.from == "cardTip" then
        -- 打点点击去补翻
        self:onMainClickDC(AMFEvent.new("", { t1 = 1 }))
    end
end

-- 翻牌成功了
function MainPanelVM:onSignSuccess(evt)
    local data = evt:getData()
    self:lock()
    deferred.success()
    :next(function()
        local td = deferred.new()
        if data.year and data.month and data.day then
            -- self:callViewFunc("setCardLabelVisible", data.year, data.month, data.day, false)
            self:callViewFuncWithCallback("onSignSuccess", function()
                -- self:callViewFunc("setCardLabelVisible", data.year, data.month, data.day, true)
                self:_updateView()
                td:resolve()
            end, data.year, data.month, data.day)
        else
            td:resolve()
        end
        return td
    end)
    :next(function()
        local td = deferred.new()
        if self._promoteDailyMgr:checkCanRewardMonthMedal(self._year, self._month) then
            local lastDay = self._promoteDailyMgr:getLastDayByYM(self._year, self._month)
            local day = Utils:getDayNumByYMD(self._year, self._month, lastDay)
            self._promoteDailyMgr:requestReward({rewardType = 2, day = day}):next(function(randomReward)
                self._promoteDailyMgr:showShopRewardsPanel(randomReward):next(function()
                    td:resolve()
                end, function()
                    td:resolve()
                end)
            end, function()
                td:resolve()
            end)
        else
            td:resolve()
        end
        return td
    end)
    :next(function()
        local td = deferred.new()
        if self._promoteDailyMgr:isFullSign(self._year, self._month) then
            local key = "popFullSignDate_".. self._year.."_"..self._month
            self._promoteDailyMgr:setLocalValue(key, true)
            self._promoteDailyMgr:showFullSignPanel({
                year = self._year,
                month = self._month,
                closeCallback = function()
                    td:resolve()
                end
            })
        else
            td:resolve()
        end
        return td
    end)
    :next(function()
        self:_updateView()
        self:unlock()
    end)
end

function MainPanelVM:_tryPlayCurDayNotSignAnim()
    local d = deferred.new()
    local todaySigned = self._promoteDailyMgr:getTodaySignState() ~= PromoteDailyConst.SignState.NONE
    if todaySigned then
        return d:resolve()
    end
    self:callViewFunc("playCurDayNotSignAnim")
    TimerUtil.addAlarm(function()
        d:resolve()
    end, 10/30)
    return d
end

-- 去闯关
function MainPanelVM:onGoToLevel(evt)
    PromoteDailyEventCenter:dispatch(PromoteDailyEvent.CLOSE_ALL)
    _G.amfTransaction(TransactionEvent.PLAY_LEVEL, PlayLevelContext.new())
    -- 主面板点击打点
    local data = evt and evt:getData() or {}
    if data.from == "cardTip" then
        self:onMainClickDC(AMFEvent.new("", { t1 = data.t1 }))
    end
end

-- 打开帮助界面
function MainPanelVM:openHelpPanel(evt)
    local data = evt:getData() or {}
    self._promoteDailyMgr:showActIntroPanel(1, data.closeCallback)
end

-- 打开七天奖励界面
function MainPanelVM:open7DayPanel(evt)
    local data = evt:getData() or {}
    data.year = data.year or self._year
    data.month = data.month or self._month
    if table.isEmpty(data.extReward) then
        local NormalRewardPoolPanelVM = require "amf.feature.dailyreward.promotedaily.view.NormalRewardPoolPanelVM"
        local vm = NormalRewardPoolPanelVM:create(data)
        vm:setLoadResFailCallback(function()
        end)
        vm:popout()
        self._promoteDailyMgr:addToMgr(vm)
    else
        local RewardPoolPanelVM = require "amf.feature.dailyreward.promotedaily.view.RewardPoolPanelVM"
        local vm = RewardPoolPanelVM:create(data)
        vm:setLoadResFailCallback(function()
        end)
        vm:popout()
        self._promoteDailyMgr:addToMgr(vm)
    end

    -- 主面板点击打点
    self:onMainClickDC(AMFEvent.new("", { t1 = 4 }))
end

-- 领取七天奖励
function MainPanelVM:on7DayRewardTapped(evt)
    self:lock()
    deferred.success()
    :next(function()
        if self.isDisposed then return end
        local td = deferred.new()
        self._promoteDailyMgr:tryGetTaskReward():next(function(data)
            if data and data.rewards then
                self._promoteDailyMgr:showArriveDailyPanel({
                    pageIndex = 2,
                    rewards = data.rewards,
                    bOldTask = data.bOldTask,
                    boxWorldPos = self:callViewFunc("getBottomBoxWorldPos"),
                }, function()
                    self._promoteDailyMgr:showSelectTargetPanel():next(function()
                        td:resolve()
                    end)
                end)
            else
                td:resolve()
            end
        end)
        return td
    end)
    :next(function()
        return self:_tryPlayRefreshTask()
    end)
    :next(function()
        if self.isDisposed then return end
        self:_updateView()
        self:unlock()
    end)
end

-- 打开月奖励界面
function MainPanelVM:openMonthAllRewardPanel(evt)
    local data = evt:getData()
    local AllRewardPanelVM = require "amf.feature.dailyreward.promotedaily.view.AllRewardPanelVM"
    local vm = AllRewardPanelVM:create(data)
    vm:setLoadResFailCallback(function()
    end)
    vm:popout()
    self._promoteDailyMgr:addToMgr(vm)
end

-- 点击高光记录
function MainPanelVM:onRecordBtnTapped()
    -- 已经点过就不显示新字了
    self._promoteDailyMgr:setLocalValue("btnRecordNewTagShow", false)
    -- 刷新红点
    self:callViewFunc("updateBtnRecord")
    self:openHighLightPanel({t1 = 1})
end

function MainPanelVM:onOpenHighLightPanel(evt)
    local param = evt:getData()
    self:openHighLightPanel(param)
end

function MainPanelVM:openHighLightPanel(param)
    local param = param or {}
    local HighLighPanelVM = require "amf.feature.dailyreward.promotedaily.view.HighLightPanelVM"
    local vm = HighLighPanelVM:create(param)
    vm:setLoadResFailCallback(function()
    end)
    vm:popout()
    self._promoteDailyMgr:addToMgr(vm)
end

-- 点击了去补翻
function MainPanelVM:onClickToRecover(evt)
    local data = evt:getData()
    if data.year and data.month then
        local lastDayNum = Utils:getDayNumByYMD(self._year, self._month, 1)
        local targetDayNum = Utils:getDayNumByYMD(data.year, data.month, 1)
        local direction
        if targetDayNum < lastDayNum then
            direction = MainPanelConfig.CalendarAni.RIGHT
        elseif targetDayNum > lastDayNum then
            direction = MainPanelConfig.CalendarAni.LEFT
        end
        self:lock()
        self:_navigateTo(data.year, data.month, data.day or self._day, direction):next(function()
            self:unlock()
            -- 打点
            if data.from == "monthMedal" or data.from == "headFrame" then
                self._promoteDailyMgr:dc(PromoteDailyConst.FEATURE, "highlight_click", {
                    t1 = data.from == "monthMedal" and 2 or 1,
                    t2 = self._promoteDailyMgr:getHeadFrameId(data.year, data.month)
                })
            end
        end, function()
            self:unlock()
        end)
    end
end

function MainPanelVM:tryLoadYearRes(year)
    local yearKey = tostring(year)
    local yearList = MainPanelConfig:getYearResList(year)
    if #yearList == 0 then
        return deferred.success()
    end
    if self._retainResMap[yearKey] then
        return deferred.success()
    end
    if self._yearResLoadMap[yearKey] then
        return self._yearResLoadMap[yearKey]
    end

    local d = deferred.new()
    self._yearResLoadMap[yearKey] = d
    local function _loadOver()
        if self._yearResLoadMap[yearKey] ~= d then return end
        self._yearResLoadMap[yearKey] = nil
        if self.isDisposed then
            return d:reject("promotedaily main panel disposed")
        end
        if not self._retainResMap[yearKey] then
            self._promoteDailyMgr:retainResOnce(yearList)
            self._retainResMap[yearKey] = yearList
        end
        d:resolve()
    end
    local function _loadFail(err)
        if self._yearResLoadMap[yearKey] ~= d then return end
        self._yearResLoadMap[yearKey] = nil
        d:reject(err)
    end
    if EnvUtil:isMiniGame() then
        self._assetsUtil:loadMiniFiles(yearList, false):next(function()
            _loadOver()
        end, _loadFail)
    else
        _loadOver()
    end
    return d
end

function MainPanelVM:_navigateTo(targetYear, targetMonth, targetDay, direction, transitionStarted)
    if not self:_isConfigAndDataEnabled(targetYear, targetMonth) then
        return deferred.error("promotedaily target month disabled")
    end
    local navigation = deferred.new()
    local generation = self:_nextNavigationGeneration()
    if targetYear ~= self._activeResYear and self._retiringResYear then
        self:_finishPendingYearTransition()
    end
    self._pendingNavigationYear = targetYear
    self._pendingNavigationMonth = targetMonth
    self:tryLoadYearRes(targetYear):next(function()
        if not self:_isNavigationCurrent(generation) then
            self:_releaseUnusedYearRes(targetYear)
            return self:_finishSupersededNavigation(navigation)
        end
        self:_activateYearRes(targetYear)
        self._year = targetYear
        self._month = targetMonth
        self._day = targetDay or self._day
        self._pendingNavigationYear = nil
        self._pendingNavigationMonth = nil
        local viewTransition = self:_updateView(direction)
        safeRunCall(transitionStarted)
        viewTransition:next(function()
            navigation:resolve()
        end, function(err)
            if not self:_isNavigationCurrent(generation) then
                return self:_finishSupersededNavigation(navigation)
            end
            navigation:reject(err)
        end)
    end, function(err)
        self:_releaseUnusedYearRes(targetYear)
        if self:_isNavigationCurrent(generation) then
            self._pendingNavigationYear = nil
            self._pendingNavigationMonth = nil
        end
        navigation:reject(err)
    end)
    return navigation
end

-- 左箭头
function MainPanelVM:onLeftBtnTapped()
    local year = self._pendingNavigationYear or self._year
    local month = self._pendingNavigationMonth or self._month
    local targetYear, targetMonth = Utils:getLeftYM(year, month)
    return self:_navigateTo(targetYear, targetMonth, self._day, MainPanelConfig.CalendarAni.RIGHT)
end

-- 右箭头
function MainPanelVM:onRightBtnTapped()
    local year = self._pendingNavigationYear or self._year
    local month = self._pendingNavigationMonth or self._month
    local targetYear, targetMonth = Utils:getRightYM(year, month)
    return self:_navigateTo(targetYear, targetMonth, self._day, MainPanelConfig.CalendarAni.LEFT)
end

-- 回到当前月份
function MainPanelVM:onBackToCurBtnTapped()
    local targetYear = self._promoteDailyMgr:getYear()
    local targetMonth = self._promoteDailyMgr:getMonth()
    local sourceYear = self._pendingNavigationYear or self._year
    local sourceMonth = self._pendingNavigationMonth or self._month
    local lastDayNum = Utils:getDayNumByYMD(sourceYear, sourceMonth, 1)
    local targetDayNum = Utils:getDayNumByYMD(targetYear, targetMonth, 1)
    local direction
    if targetDayNum < lastDayNum then
        direction = MainPanelConfig.CalendarAni.RIGHT
    elseif targetDayNum > lastDayNum then
        direction = MainPanelConfig.CalendarAni.LEFT
    end
    return self:_navigateTo(targetYear, targetMonth, self._promoteDailyMgr:getDay(), direction)
end

function MainPanelVM:onRefreshShieldNode()
    if self.isDisposed then return end
    self:callViewFunc("updateShield")
end

function MainPanelVM:openBuyShieldPanel()
    self._promoteDailyMgr:openShieldPanel()
end

function MainPanelVM:openTaskPreviewPanel()
    self._promoteDailyMgr:showTargetPanel()
    -- 主面板点击打点
    self:onMainClickDC(AMFEvent.new("", { t1 = 4 }))
end

function MainPanelVM:openLittleTipPanel()
    self._promoteDailyMgr:openProtectTipPanel()
end

function MainPanelVM:test()
    local vm = MainPanelVM:create()
    vm:setLoadResFailCallback(function()
        print("MainPanelVM 下载资源失败")
    end)
    vm:popout()
end

return MainPanelVM
