local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local Tween = require "amf.middleware.ui.util.Tween"
local NumberUtil = require "amf.middleware.ui.util.NumberUtil"
local ActivityName = "Gladiator"

local function shouldReduceAutoPopup(manager)
    return not manager:hasEnteredCurrentPeriod()
        and _G.amfBean("ActivityParticipationMgr"):shouldReduceAutoPopup(manager.ACT_ID)
end

local Manager = class(ActivityName)

----------- 可能需要修改start -----------
local LocalServer = require('amf.feature.localactivity.'..string.lower( ActivityName )..'.'..ActivityName..'LocalServer')
Manager.ACT_OPEN_VERSION = 1
Manager.ACT_ID = 9079
Manager.GAME_NAME = "social_1v1"
Manager.ACT_SOURCE = "gladiator/Config.lua"
Manager.ACT_CH_NAME = "疯狂对决"

function Manager:setAutoPopupMgr(autoPopupMgr)
    self.autoPopupMgr = autoPopupMgr
end

function Manager:initialize()
    self.meta = require('amf.feature.localactivity.'..string.lower(ActivityName)..'.'..ActivityName..'Meta')
    self.localDataServer = LocalServer:create()

    local InLevelBridgeModule = require "amf.feature.localactivity.gladiator.module.InLevelBridgeModule"
    self.inLevelBridgeModule = InLevelBridgeModule:create(self)

    self:registerEvents()
    self:initPlugs()
end

function Manager:hasEnteredCurrentPeriod()
    local mainEndTime = self:getActMainEndTime()
    return (tonumber(mainEndTime) or 0) > 0
        and self:getLocalDataServer():getDataByKey("inLevelCardParticipatedEndTime") == mainEndTime
end

function Manager:registerEvents()
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)

    _G.amfEC:registerNormal(NormalEvent.PLAY_LEVEL_END, self.onActPassLevel, self)
    _G.amfEC:registerNormal(NormalEvent.PASS_DAY, self.onActPassDay, self)

    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
end

function Manager:joinDC()
    if not self:isEnabled() then return end

    if not self:getFlagFromLocalByKey("todayDC",true) then
        self:saveFlagToLocalByKey("todayDC",true,true)
        self:dc("join", nil, nil, nil, nil, {category="canyu", actid=self.ACT_ID})
    end
end

--第n次参与活动
function Manager:getDcNum()
    if not self:isEnabled() then return end
    local myInfo = self:getLocalDataServer():getDataByKey("myInfo",{})
    local pkState = self:getAndRefreshPKState()
    local pkRound = myInfo.pkRound + 1
    if pkState == self.meta.PKState.kToBeSettled then
        pkRound = myInfo.pkRound
    end
    return pkRound
end

function Manager:onActReceiveEmergency(evt)
    local eventData = evt:getData()

    if eventData and eventData.endPoint == EmergencyConst.SOCIAL_1V1_EVENT_BEAN and eventData.data then
        local cacheData = table.clone(eventData.data)
        local score = cacheData.enemyScore

        if score then
            self:getLocalDataServer():setEnemyScore(score)
            --更新Icon
            self:updateIcon()
            self.inLevelBridgeModule:tryUpdateElData()
        end
    end
end

--尝试查询
function Manager:tryQuery()
    if not self:isEnabled() then return end
    local pkState = self:getAndRefreshPKState()
    if pkState == self.meta.PKState.kInGame then
        local enemyInfo = self:getLocalDataServer():getDataByKey("enemyInfo")
        if not enemyInfo then
            self:requestQueryHTTP()
        end
    end
end

--查询协议
function Manager:requestQueryHTTP(successCallback,failCallback)
    if self.isInQuery then safeRunCall(failCallback) return end
    local function onSuccess(evt)
        local data = evt:getData()
        self:updateData(data)
        self:checkFirstMatch(true)
        self.isInQuery = false
        safeRunCall(successCallback)
    end

    local function onFail()
        self.isInQuery = false
        safeRunCall(failCallback)
    end

    self.isInQuery = true

    local Request = require "amf.feature.localactivity.gladiator.http.RequestSocial1v1Query"
    Request:post():next(onSuccess,onFail)
end

-- join协议 默认不loading
function Manager:requestJoinHTTP(successCallback, failCallback, cancelCallback, robot)
    if robot == nil then
        robot = false
    end
    if self.joinLock then return end
    local function onSuccess(evt)
        local data = evt:getData()
        self:updateData(data)
        self:checkFirstMatch(true)
        self:getLocalDataServer():setDataByKey(
            "inLevelCardParticipatedEndTime", self:getActMainEndTime(), true, true)
        self.joinLock = false
        self:joinDC()
        safeRunCall(successCallback, evt)
    end

    local function onFail(response)
        self.joinLock = false
        if response:isCancel() then
            safeRunCall(cancelCallback)
        else
            safeRunCall(failCallback, response)
        end
    end

    self.joinLock = true

    local reqParams = {
        robot = robot,
        type = self:getLocalDataServer():getDataByKey("actType", 2),
        group = self:getLocalDataServer():getDataByKey("group", "G1")
    }

    local Request = require "amf.feature.localactivity.gladiator.http.RequestSocial1v1JoinH5"
    Request:post(reqParams):next(onSuccess, onFail)
end

-- 同步所有数据
function Manager:updateData(data, skipSaveLocal, fromServer, fromMainInfo)
    if not data then return end

    self:getLocalDataServer():fromServer(data,skipSaveLocal,fromMainInfo)
end

----------------------------- 功能函数 -----------------------------
---------------------------------- 活动时间相关 ----------------------------------
-- 预热期
function Manager:isInPreTime(  )
    return self:getLocalDataServer():isActInPre()
end

--是否是主活动期
function Manager:isInMainTime()
    return self:getLocalDataServer():isActInMain()
end

--是否是领奖期
function Manager:isInRewardTime()
    return self:getLocalDataServer():isActInReward()
end

---------------------------------- 本地缓存相关 ----------------------------------
-- 获取本地缓存的完整key
function Manager:getLocalKey( key, needTime )
    local str = string.format("%s_%s_%s_%s",_G.getSafeUid(),ActivityName,Manager.ACT_OPEN_VERSION,key)
    if needTime then
        local curTime = TimeKit:timeInSec()
        local dayStartTime = getDayStartTimeByTS(curTime)
        str = str .. ':' .. dayStartTime
    end
    return str
end

-- 本地bool缓存
function Manager:saveFlagToLocalByKey(key, needTime, bSkip)
    if not key then return end
    if bSkip == nil then bSkip = true end
    if needTime then
        self:getLocalDataServer():setValue(key, getDayStartTimeByTS(TimeKit:timeInSec()))
    else
        self:getLocalDataServer():setValue(key, bSkip)
    end
end

function Manager:getFlagFromLocalByKey(key, needTime)
    if needTime then
        local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())
        return self:getLocalDataServer():getValue(key) == nowTime
    else
        return self:getLocalDataServer():getValue(key)
    end
end

---------------------------------- 零散功能 ----------------------------------
function Manager:getLocalDataServer()
    return self.localDataServer
end

function Manager:getMeta()
    return self.meta
end

-- 是否是活动正式期最后一天
function Manager:isLastDay(  )
    local todayStartTime = getDayStartTimeByTS(TimeKit:timeInSec())
    local lastDayStartTime = getDayStartTimeByTS(self:getLocalDataServer():getActMainEndTime())
    return todayStartTime == lastDayStartTime
end

-- 获取服务器时间是活动周期内的第几天
function Manager:getDayFromActOpen( time )
    if not self:isEnabled() then return 0 end
    local startTime = getDayStartTimeByTS(self:getLocalDataServer():getActMainBeginTime())
    local curTime = getDayStartTimeByTS(time or TimeKit:timeInSec())
    return math.floor((curTime-startTime)/86400)+1
end

-- 获取从1970.1.1开始服务器时间是第几天
function Manager:getDayFrom1970( time )
    local curDayStartTime = getDayStartTimeByTS(time or TimeKit:timeInSec())
    return math.ceil(curDayStartTime/86400)
end

-- 检测引导标记
function Manager:hasGuideIndex(index)
    local hasIndex = self:getLocalDataServer():hasGuide(index)
    
    return hasIndex
end

-- 设置引导标记
function Manager:addGuideIndex(index, needSaveLocal)
    self:getLocalDataServer():setGuide(index)

    local ActCommonHttp = require("amf.middleware.activity.http.ActCommonHttp")
    ActCommonHttp:setActGuideFlag(Manager.ACT_ID, index)
end

-- 打点
function Manager:dc(subCategory, t1, t2, t3, t4, extraData)
    local params = {
        category = Manager.GAME_NAME,
        sub_category = subCategory,
        t1 = t1,
        t2 = t2,
        t3 = t3,
        t4 = t4,
    }

    for i, v in pairs(extraData or {}) do
        params[i] = v
    end
    DcUtil:UserTrack(params)
end

function Manager:getActInfo()
    return _G.amfBean("ActivityMgr"):getActInfo(Manager.ACT_ID)
end

function Manager:openActivity(closeCallback, extra, userClick, duanMianData)
    ActivityEventCenter:dispatch(ActivityEvent.OPEN_ACTIVITY, {
        actId = Manager.ACT_ID,
        failCallback = closeCallback,
        endCallback = closeCallback,
        userClick = userClick,
        extra = extra,
        duanMianData = duanMianData
    })
end

function Manager:getActivityIcon(source_input)
    return _G.amfBean("IconManager"):getIconByIconKey(tostring(Manager.ACT_ID))
end

--更新icon
function Manager:updateIcon()
    local icon = self:getActivityIcon()
    if icon and (not icon.isDisposed) then
        if type(icon.refreshProvider) == "function" then
            self:updateTipView()
        else
            icon:updateState()
        end
    end
end

----------------------------- 以下是可能会改的内容 -----------------------------
-- home尝试更新对手信息，如果没有的话
function Manager:onSystemEnterForeGround()
    self:tryQuery()
end

--更新数据
function Manager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local actInfo = actInfos[tostring(Manager.ACT_ID)]
    local data = actInfo and actInfo.extra
    if data then
        local useData = table.deserialize(data)
        local checkTable = {
            ["beginTime"] = true,
            ["endTime"] = true,
            ["mainBeginTime"] = true,
            ["mainEndTime"] = true,
        }
        for k,v in pairs(useData) do
            if checkTable[k] then
                useData[k] = math.floor(tonumber(v)/1000)
            end
        end

        local periodId = self:getLocalDataServer():getDataByKey("periodId")
        --变期了，清下本地数据
        if periodId ~= useData.periodId then
            self:getLocalDataServer():clearData()
        end

        self:updateData(useData)
    end
end
---------------------------------- 加道具 ----------------------------------
-- 普通的addRewards,开宝箱之类的
function Manager:addRewardsNormal(rewardItems, params)
    self:_addRewards(rewardItems, nil, params)
end

-- 不要调用，但需要修改业务逻辑相关添加
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

--icon创建
function Manager:createIcon(reward)
    local icon
    if reward.itemId == self.meta.collectId then
        icon = UICreateUtil:createSpriteFile("amf/activity/gladiator/materials/collectIcon.png")
    else
        icon = GameItemCreator:getPropIcon(reward)
    end

    return icon
end

---------------------------------- icon角标逻辑 ----------------------------------
-- 奖字
function Manager:updateTipView()
    local function setIconInfo( source, hasReward, msgNum )
        local actInfo = self:getActInfo()
        if not actInfo then return end
        actInfo.reward = hasReward
        actInfo.msgNum = msgNum
        ActivityEventCenter:dispatch(ActivityEvent.SET_ACT_INFO, actInfo)
    end
    if not self:isEnabled() then return end
    local hasReward = self:hasRewards()
    local msgNum = self:getShowMsgNum()
    setIconInfo(Manager.ACT_SOURCE, hasReward, msgNum)
end

-- 主icon奖字
function Manager:hasRewards()
    if not self:isEnabled() then return false end
    return self:isToBeSettledAndHasReward()
end

--待结算
function Manager:isToBeSettledAndHasReward()
    local pkState = self:getAndRefreshPKState()
    local scoreData = self:getLocalDataServer():getScoreData()
    local hasReward = not (scoreData.myScore == 0 and scoreData.enemyScore == 0)
    return pkState == self.meta.PKState.kToBeSettled and hasReward
end

-- 主icon数字
function Manager:getShowMsgNum()
    if not self:isEnabled() then return 0 end
    local times = 0

    local pkState = self:getAndRefreshPKState()
    if pkState == self.meta.PKState.kPrepare then
        times = self:getLocalDataServer():getTodayLeftTimes()
    end
    return times
end

function Manager:onActPassDay()
    if not self:isEnabled() then return end

    self:getLocalDataServer():passDayRefreshData()
end

-- 记得改造一下
function Manager:isEnabled()
    return self:getLocalDataServer():isDataEnabled() and (self:isInMainTime() or self:isInRewardTime())
end
---------------------------------- 业务逻辑,新增函数都写在此后 --------------------------------
------------------------------- 关卡外 -------------------------------
--检查是否能提前进入领奖期
function Manager:checkCanEnterRewardTime()
    return self:checkShortTermCanEnterRewardTime()
end

--短期提前进领奖期
function Manager:checkShortTermCanEnterRewardTime()
    if not self:isLastDay() then return end
    local pkState = self:getAndRefreshPKState()
    if pkState ~= self.meta.PKState.kPrepare then return end
    return not self:getLocalDataServer():checkHasLeftTimes() 
end

--pk状态获取和刷新
function Manager:getAndRefreshPKState()
    if not self:isEnabled() then
        return self.meta.PKState.kInvalid
    end
    return self:getLocalDataServer():getAndRefreshPKState()
end

function Manager:getAndRefreshBeMatchedNew(beWatchInLevel)
    local state = self:getAndRefreshPKState()

    if state == self.meta.PKState.kInGame then
        if not self:getLocalDataServer():checkHasEnemyInfo() then
            self._beMatchedNew = 1
        elseif self._beMatchedNew == 1 then
            self._beMatchedNew = 2
            self._openedPanel = false
        elseif self._beMatchedNew == 2 and beWatchInLevel then
            self._beMatchedNew = 0
        end
    else
        self._beMatchedNew = 0
    end

    if not self._beMatchedNew then self._beMatchedNew = 0 end
end

--是否有剩余次数
function Manager:checkHasLeftTimes()
    if not self:isEnabled() then
        return false
    end

    return self:getLocalDataServer():checkHasLeftTimes()
end

--icon展示状态（比赛中的）
function Manager:getIconShowState()
    local state = self:getAndRefreshPKState()

    if state == self.meta.PKState.kInGame then
        local scoreData = self:getLocalDataServer():getScoreData()
        local winState = self:getLocalDataServer():getWinState()

        --双0，播idle
        if scoreData.myScore == scoreData.enemyScore and scoreData.myScore == 0 then
            return self.meta.IconState.kIdle
        end
        if winState == self.meta.MatchState.kInvalid then
            return self.meta.IconState.kIdle
        elseif winState == self.meta.MatchState.kWin then
            return self.meta.IconState.kWin
        else
            return self.meta.IconState.kLose
        end
    elseif state == self.meta.PKState.kPrepare and
        not self:getLocalDataServer():checkHasLeftTimes() then
            return self.meta.IconState.kIdle2
    else
        return self.meta.IconState.kIdle
    end
end

function Manager:loadActIntroPanelRes(successCallback, failCallback)
    _G.amfBean("AssetsUtil"):loadMiniFiles({
        "amf/activity/gladiator/texture/ActIntroPanel.plist"
    }):next(successCallback, failCallback)
end

function Manager:openActIntroPanel(closeCallback, page)
    self:loadActIntroPanelRes(function()
        page = page or 1
        local illustrationPanelVM = require 'amf.middleware.ui.kit.panel.other.IllustrationPanelVM'

        local vm = illustrationPanelVM.Builder.new()
            :setTitle("")
            :createWithSource("amf/feature/localactivity/gladiator/view/uisource/ActIntroPanel_UI.lua")
            :setDefaultPage(page)
            :setCloseCallback(closeCallback)
            :build()
        
        vm:popout()
    end, closeCallback)
end

function Manager:loadJoinPanelRes(successCallback, failCallback)
    _G.amfBean("AssetsUtil"):loadMiniFiles({
        "amf/activity/gladiator/texture/join.png"
    }):next(successCallback, failCallback)
end

-- 创建进组面板
function Manager:openJoinPanel(closeCallback)
    self:loadJoinPanelRes(function()
        local vm
        local UIButton = require "amf.middleware.ui.kit.component.button.UIButton"

        local PreheatPanelVM = require "amf.middleware.ui.kit.panel.first.PreheatPanelVM"
        vm = PreheatPanelVM.Builder.new()
            :setTitle(Manager.ACT_CH_NAME)
            :setSpriteBg(UICreateUtil:createSpriteFile("amf/activity/gladiator/texture/join.png"), ccp(0, -20))
            :setTimeLabel(nil, nil, ccp(0, -652))
            :setButtonData({
                str = { "立即参与" },
                touchFunc = function()
                    self:dc("open_click", self:getDcNum(), nil, nil, nil, {panel_id = vm.panelId})
        
                    local from = 4
        
                    vm:onCloseBtnTapped()
                    _G.amfBean("AutoPopupMgr"):resetPopup()
                    self:openActivity(closeCallback, { from = from, fromYinLiu = true }, true)
                end
            })
            :setCloseCallback(closeCallback)
            :build()
        vm:callViewFunc("refreshTimeLabel", "活动时间：" .. YH_REF_MAP.noEarClock .. " 30 分钟")
        self:dc("open_show", self:getDcNum(), nil, nil, nil, {panel_id = vm.panelId})

        self:saveFlagToLocalByKey(self.meta.Key.OPEN_JOIN_PANEL_TODAY, true)

        vm:popout()
    end, closeCallback)
end

-- 包装一下进度条
function Manager:packProgressBar(progressBar, showMax, showMin, fixPosX)
    showMax = showMax or 0.62
    showMin = showMin or 0.38
    fixPosX = fixPosX or 0
    local icon1 = self:createIcon({
        itemId = self.meta.collectId,
        num = 1 
    })
    icon1:setPositionXY(65 + fixPosX,39)
    icon1:setScale(0.4)
    icon1:setAnchorPoint(ccp(0.5,0.5))

    local icon2 = self:createIcon({
        itemId = self.meta.collectId,
        num = 1 
    })
    icon2:setScale(0.4)
    icon2:setAnchorPoint(ccp(0.5,0.5))
    icon2:setPositionXY(429 - fixPosX,39)

    progressBar:addChild(icon1)
    progressBar:addChild(icon2)
    progressBar.icon1 = icon1
    progressBar.icon2 = icon2

    local width = 25
    local label1 = TTFLabel:createAnimalYH("0",30)
    label1:setAnchorPoint(ccp(0,0.5))
    label1:enableOutline(hex2ccc4("00000066"),2)
    local pos1 = icon1:getPosition()
    label1:setPositionXY(pos1.x + width,pos1.y - 1)
    local label2 = TTFLabel:createAnimalYH("0",30)
    local pos2 = icon2:getPosition()
    label2:setAnchorPoint(ccp(1,0.5))
    label2:enableOutline(hex2ccc4("00000066"),2)
    label2:setPositionXY(pos2.x - width,pos2.y - 1)
    progressBar:addChild(label1)
    progressBar:addChild(label2)
    progressBar.label1 = label1
    progressBar.label2 = label2

    progressBar:update({
        min = 0,
        max = 100,
    })
    local oldSetProgress = progressBar.setValue

    progressBar.isInited = true

    local light = UICreateUtil:createSpine("amf/activity/gladiator/spine/zmb_lite.skel")
    progressBar:addChild(light)
    progressBar.fixLight = light
    local context = self

    function progressBar:setValue(scoreData, animationTs, callback, ignoreMinMax)
        local myScore = scoreData.myScore
        local enemyScore = scoreData.enemyScore
        local per
        if myScore == enemyScore then
            per = 0.5
        else
            per = myScore / (myScore + enemyScore)
            if per > 0.5 then
                if #tostring(enemyScore) > 4 then
                    showMax = showMax - 0.05
                end
            elseif per < 0.5 then
                if #tostring(myScore) > 4 then
                    showMin = showMin + 0.05
                end
            end
            if not ignoreMinMax then
                per = math.max(per,showMin)
                per = math.min(per,showMax)
            else
                per = math.max(per,0)
                per = math.min(per,1)
            end
        end

        local value = per * 100
        local nowPercentage = self:getPercentage()

        if math.abs(per - nowPercentage) < 0.003 then
            animationTs = nil
        end

        local lastMyScore,lastEnemyScore

        if not progressBar.lastScoreData then
            progressBar.lastScoreData = scoreData
            lastMyScore = myScore
            lastEnemyScore = enemyScore
        else
            lastMyScore = progressBar.lastScoreData.myScore
            lastEnemyScore = progressBar.lastScoreData.enemyScore
        end

        light:setVisible(true)
        self.label1:setOpacity(255)
        self.label2:setOpacity(255)
        self.icon1:setOpacity(255)
        self.icon2:setOpacity(255)
        
        if animationTs and animationTs > 0 then
            local targetPos = self:getPositionByPercentage(per)

            light:runAction(ActionUtil:sequence({
                CCDelayTime:create(animationTs),
                CCCallFunc:create(function()
                    light:runAction(CCMoveTo:create(0.3,ccp(targetPos.x,targetPos.y - 7)))
                    if nowPercentage > per then
                        light:playByName("jindu_up_L",false)
                    else
                        light:playByName("jindu_up_R",false)
                    end
                end)
            }))

            if lastMyScore ~= myScore and myScore < 100000 then
                ActionUtil:rollingNumber({
                    label = label1,
                    startNumber = lastMyScore,
                    endNumber = myScore,
                    duration = 0.3,
                })
            elseif myScore >= 10000000 then
                label1:setString("999.99万")
            elseif myScore >= 100000 then
                label1:setString(NumberUtil:formatBigNumber(myScore,2,100000))
            end

            if lastEnemyScore ~= enemyScore and enemyScore < 100000 then
                ActionUtil:rollingNumber({
                    label = label2,
                    startNumber = lastEnemyScore,
                    endNumber = enemyScore,
                    duration = 0.3,
                })
            elseif enemyScore >= 10000000 then
                label2:setString("999.99万")
            elseif enemyScore >= 100000 then
                label2:setString(NumberUtil:formatBigNumber(enemyScore,2,100000))
            end
        else
            local function setLabelNum(label,score)
                if score < 100000 then
                    label:setString(score)
                elseif score >= 10000000 then
                    label:setString("999.99万")
                elseif score >= 100000 then
                    label:setString(NumberUtil:formatBigNumber(score,2,100000))
                end
            end
        
            setLabelNum(label1,myScore)
            setLabelNum(label2,enemyScore)
            self.needUpdateLightPos = true
        end

        --忽略的话直接按胜负判定
        if ignoreMinMax then
            local winState = context:getLocalDataServer():checkWinState(scoreData.myScore,scoreData.enemyScore)
            if winState == context.meta.MatchState.kWin then
                value = 100
                Tween.to(self.icon2,0.1,{fAlpha = 0})
                Tween.to(self.label2,0.1,{fAlpha = 0})
            else
                value = 0
                Tween.to(self.icon1,0.1,{fAlpha = 0})
                Tween.to(self.label1,0.1,{fAlpha = 0})
            end
            light:setVisible(false)
        end

        local function playProgressAnim()
            if self.isDisposed then return end
            oldSetProgress(self,value,animationTs,function()
                if light and not light.isDisposed then
                    light:gotoAndStop("jindu_in",1)
                    safeRunCall(callback)
                    if self.needUpdateLightPos then
                        local pos = self:getPositionByPercentage(per)
                        light:setPositionXY(pos.x,pos.y - 7)
                        
                        self.needUpdateLightPos = false
                    end
                end
            end)
        end

        if animationTs and animationTs > 0 then
            self:runAction(ActionUtil:sequence({
                CCDelayTime:create(animationTs),
                CCCallFunc:create(playProgressAnim)
            }))
        else
            safeRunCall(playProgressAnim)
        end
    end

    light:gotoAndStop("jindu_in",1)

    function progressBar:playShowAnim(done)
        progressBar:setVisible(true)
        ActionUtil:setOpacity(self,0)
        ActionUtil:setOpacity(light,255)
        Tween.to(self,8/30,{fAlpha = 1,onComplete = done})
        light:runAction(ActionUtil:sequence({
            CCDelayTime:create(0.1),
            CCCallFunc:create(function()
                if light.isDisposed then return end
                light:playByName("jindu_in",false)
            end)
        }))
    end

    function progressBar:playHideAnim(done)
    end

    function progressBar:getLabel1()
        return progressBar.label1
    end

    function progressBar:getLabel2()
        return progressBar.label2
    end
end

--关卡外部分判断，只要在对局中就可以展示
function Manager:canCreateStartGamePanelDownPart()
    if not self:isEnabled() then return false end

    local bInGame = self:checkLevelCanGetCollect()
    if not bInGame then return false end

    return true
end

function Manager:onMainPanelOpen()
    self:stopIconTip()
    self:saveFlagToLocalByKey(self.meta.Key.OPEN_MAIN_PANEL_TODAY)
    self._openedPanel = true
end

function Manager:checkOpenedMainPanelToday()
    return self:getFlagFromLocalByKey(self.meta.Key.OPEN_MAIN_PANEL_TODAY)
end

-- 判断是否能开介绍板子,从场景4要检查关卡
function Manager:checkCanOpenJoinPanel(bFromStage4)
    -- 无数据
    if not self:isEnabled() then return false end

    if not self:isInMainTime() then return false end

    local state = self:getAndRefreshPKState()
    -- 非未匹配
    if state ~= self.meta.PKState.kPrepare then return false end

    -- 当日开过主面板
    if self:checkOpenedMainPanelToday() then return false end

    if self:getFlagFromLocalByKey(self.meta.Key.OPEN_JOIN_PANEL_TODAY, true) then return false end

    -- -- 发新关top30
    -- if self:ignoreTopPlayer(bFromStage4) then return false end

    return true
end

-- 屏蔽新关top30
function Manager:ignoreTopPlayer(checkLevel)
    if checkLevel and not self.nowPassLevel then return end

	local userState = _G.amfBean("UserStateManager"):getUserLevelState()
	if userState == _G.UserStateConst.UserLevelState.TOP_STAR then
		return false
	end

	if checkLevel and not _G.amfBean("LevelUnLockManager"):isTopNewMainOrHideLevel(self.nowPassLevel, self.nowLevelScene) then
		return false
	end

	if not _G.amfBean("LevelUnLockManager"):isInNewLevelTime() then
		return false
	end

	return true
end

-- 屏蔽新关top30（关卡内调用版本）
function Manager:ignoreTopPlayerInLevel(levelId)
    if not levelId then
        return
    end

	local userState = _G.amfBean("UserStateManager"):getUserLevelState()
	if userState == _G.UserStateConst.UserLevelState.TOP_STAR then
		return false
	end

	if not _G.amfBean("LevelUnLockManager"):isTopNewMainOrHideLevel(levelId, UBFLevelSceneType.kMain) then
		return false
	end

	if not _G.amfBean("LevelUnLockManager"):isInNewLevelTime() then
		return false
	end

	return true
end

-- 过关存下当前关
function Manager:onActPassLevel(event)
    local data = event:getData()
    if not data or not data.levelId then
        self.nowPassLevel = nil
        self.nowLevelScene = nil
    else
        self.nowPassLevel = data.levelId
        self.nowLevelScene = data.levelScene
    end

    --过关时候尝试查询一下数据
    self:tryQuery()
end

function Manager:setGotCollectionNum(num)
    num = num or 0
    self.passLevelGetCollectionNum = num
end
------------------------------- 关卡内 -------------------------------

function Manager:updatePassLevelData(levelContext, mainCollectionCount, collectionMap, passLevelData)
    if levelContext and levelContext.modEnvData then
        self:getLocalDataServer():addScore(mainCollectionCount)
        self:setGotCollectionNum(mainCollectionCount)

        --更新Icon
        self:updateIcon()
        local modEnvData = levelContext.modEnvData
        self:setLastPassLevelData({
                enemyOldScore = modEnvData.enemyScore or 0,
                myOldScore = modEnvData.myScore or 0,
            })
        self.inLevelBridgeModule:tryUpdateElData()
    end
end

--对战中
function Manager:checkLevelCanGetCollect(data)
    self:setLastPassLevelData(nil)
    if not self:isEnabled() then return false end
    local extraData = data and data.extraData
    if extraData and extraData.isCheckSlpBottom then
        return true
    end
    local pkState = self:getAndRefreshPKState()
    return pkState == self.meta.PKState.kInGame
end

function Manager:checkFirstMatch(reset, fromModel)
    if not fromModel then self:getAndRefreshBeMatchedNew(not reset) end

    if reset then
        self:getLocalDataServer():setDataByKey("firstMatchShow", false, true)
    else
        local show = self:getLocalDataServer():getDataByKey("firstMatchShow", false)
        if not show then
            self:getLocalDataServer():setDataByKey("firstMatchShow", true, true, true)
        end
        return not show
    end
end

--当局比赛结束时间
function Manager:getMatchEndTime()
    return self:getLocalDataServer():getNowPKEndTime()
end

--超级幸运
function Manager:checkDouble()
    if not self:isEnabled() then return end
    return self:getLocalDataServer():getMatchLucky()
end

--是否有enemyInfo和enemyProfile
function Manager:checkCanGetHeadFrameInfo()
    if not self:isEnabled() then return end
    return self:getLocalDataServer():checkHasEnemyInfo()
end

function Manager:getEnemyHeadUrl()
    if not self:isEnabled() then return end
    return self:getLocalDataServer():getEnemyHeadUrl()
end

function Manager:getStartGamePanelPriority()
    local endTime = self:getLocalDataServer():getNowPKEndTime()
    local delta = endTime - TimeKit:timeInSec()

    if delta > 0 and delta <= 10 * 60 then
        return "GladiatorHighPriority"
    else
        local lastScore = self:getLastStartPanelAndTipScore()
        local nowScore = self:getLocalDataServer():getScoreData()

        if (lastScore.myScore >= lastScore.enemyScore) and (nowScore.myScore < nowScore.enemyScore) then
            return "GladiatorHighPriority"
        end
    end

    return "GladiatorLowPriority"
end

function Manager:saveLastStartPanelAndTipScore(score)
    self:getLocalDataServer():setDataByKey("lastStartPanelAndTipScoreData", score, true, true)
end

function Manager:getLastStartPanelAndTipScore()
    local nowScoreData = self:getLocalDataServer():getScoreData()
    return self:getLocalDataServer():getDataByKey("lastStartPanelAndTipScoreData", nowScoreData)
end

function Manager:getInLevelActData(levelId, runtime)
    local inLevelActData = {
        isFirstMatch = self:checkFirstMatch(false),
        matchEndTime = self:getMatchEndTime(),
        inDoubleState = self:checkDouble(),
        banMatchAnim = self:ignoreTopPlayerInLevel(levelId),
        -- enemyHeadUrl = self:getEnemyHeadUrl(),   -- 不缓存这个数据
        scoreData = self:getLocalDataServer():getScoreData(),
        dcNum = self:getDcNum() or 0,
    }
    printx(24,"inLevelActData",ttsd(inLevelActData))
    return inLevelActData
end
--开始面板下方挂牌的面板数据
function Manager:getSlpBottomData(params)
    local scoreData = self:getLocalDataServer():getScoreData()
    local profileManager = _G.amfBean("ProfileManager")
    local winState = self:getLocalDataServer():checkWinState(scoreData.myScore, scoreData.enemyScore)
    local downPartData = {
        endTime = self:getMatchEndTime(),
        bWin = winState == self.meta.MatchState.kWin,
        leftProfile = profileManager:getProfile(),
        rightProfile = self:getLocalDataServer():getDataByKey("enemyProfile"),
        scoreData = scoreData,
        showMax = 0.6,
        showMin = 0.4,
        fixPosX = 12,
        onClickViewDetails = function(data)
            self:openActIntroPanel()
        end
    }
    
    self:saveLastStartPanelAndTipScore(scoreData)
    return downPartData
end

-----------活动联动

function Manager:isOpen()
    return self:getLocalDataServer():isDataEnabled() and (self:isInMainTime() )
end

function Manager:getActMainEndTime()
    return self:getLocalDataServer():getActMainEndTime()
end

------------------------------------------- 额外插件 -------------------------------------------
function Manager:getConst()
    return {actKey = tostring(Manager.ACT_ID)}
end

function Manager:initPlugs()
    self:_initPlug("AutoPop", {
        plugPath = "amf.middleware.activity.base.plug.AutoPopPlug",
    })
    self:_initPlug("ActSend",{
        plugPath = "amf.feature.localactivity.gladiator.plug.GladiatorActSendPlug"
    })
end

function Manager:_getAutoPopConfigList()
    return {
        {
            checkPoint = PopupCheckPoint.GLADIATOR_STAGE4_POP,
            actId = Manager.ACT_ID,
            stages = {AutoPopupConst.PopStage.STAGE_FOUR},
            check = function()
                if not _G.amfBean("ActivityMgr"):isActSupported(Manager.ACT_ID) then return false end
                return not shouldReduceAutoPopup(self)
                    and self:checkCanOpenJoinPanel(true) == true
            end,
            pop = function(_, onPopOver)
                return function()
                    if not self:isEnabled() then
                        safeRunCall(onPopOver)
                        return
                    end
                    self:openJoinPanel(onPopOver)
                end
            end,
        },
    }
end


-- 如果要自己继承插件改的话自己传plugPath, 可以继承调用
-- 如果有自己的插件模块要添加也可以这么整，在自己的活动功能文件夹下整插件加上去。
function Manager:_initPlug(key, data)
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

function Manager:_getPlugContainer()
    if not self.plugContainer then
        local PlugContainer = require "amf.script.pattern.plug.PlugContainer"
        self.plugContainer = PlugContainer:create(self, "amf.feature.promotionevent2025.plug")
    end
    return self.plugContainer
end

function Manager:_installPlug(plugType, installData, scriptPath)
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

function Manager:_uninstallPlug(plugType)
    self:_getPlugContainer():uninstall(plugType)
end

function Manager:_getPlug(plugType)
    return self:_getPlugContainer():getPlug(plugType)
end

function Manager:callPlug(plugType, funcName, ...)
    return self:_getPlugContainer():call(plugType, funcName, ...)
end

function Manager:setLastPassLevelData(data)
    self.lastPassLevelData = data
end

function Manager:getLastPassLevelData()
    return self.lastPassLevelData
end

return Manager
