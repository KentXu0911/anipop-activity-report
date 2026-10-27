local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local deferred = require "amf.script.sugar.deferred"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"
local CircularTitle = require "amf.middleware.ui.kit.component.CircularTitle"
local ProgressBar = require "amf.middleware.ui.kit.component.ProgressBar"
local AsyncRunner = require "amf.script.sugar.AsyncRunner"
local Manager = class("EnergyFundManager", BaseFeatureManager)

-- 获取需要启动的额外功能列表
function Manager:_getExtraPlugsConfigList()
    return {{
        key = "Download"
    }, {
        key = "Panel"
    }, {
        key = "Rewards"
    }}
end

function Manager:_getConstPath() return "amf.feature.localactivity.energyfund.const.EnergyFundConst" end
function Manager:_getModelPath() return "amf.feature.localactivity.energyfund.model.EnergyFundModel" end
function Manager:_getDCPath() return "amf.feature.localactivity.energyfund.dc.EnergyFundDC" end

function Manager:_init()
    self._dc = require(self:_getDCPath())
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)
    self:registerEvents()
    self:registerActProps()
end

function Manager:setLevelAreaManager(levelAreaManager)
    self._levelAreaManager = levelAreaManager
end

function Manager:setUserEnergyManager(userEnergyManager)
    self._userEnergyManager = userEnergyManager
end

function Manager:setIconManager(iconManager)
    self._iconManager = iconManager
end

function Manager:registerActProps()
    require("amf.feature.localactivity.energyfund.prop.AMFProp_58096")
end

function Manager:getDC() return self._dc end

function Manager:registerEvents()
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
end

function Manager:updateData(data) 
    self:getModel():assignData(data) 
    self:refreshEnergy()
end

function Manager:passDayRefreshData()
    if not self:isEnabled() then return end
    --todo
end
----------------------------------------------功能-------------------------------------------------------

function Manager:getPeriod()
    if not self:isEnabled() then return 0 end
    return self:getModel():getPeriod()
end

function Manager:getIsInSpecialLevel()
    if not self:isEnabled() then return false end
    local passedTopLevel = self._levelAreaManager:getTopPassedLevel()
    local specialLevel = self:getModel():getSpecialLevel()
    return passedTopLevel >= specialLevel
end

function Manager:refreshEnergy()
    self._userEnergyManager:refreshEnergy()
    if UserLocalLogic then
        UserLocalLogic:refreshEnergy()
    end

    local energyButton
    if HomeScene then
        energyButton = HomeScene:sharedInstance().energyButton
    else
        local iconLayer = self._iconManager:getIconLayer()
        energyButton = iconLayer and iconLayer.topButtonLayout and iconLayer.topButtonLayout.energyButton
    end
    
    if energyButton then
        energyButton:updateView()
    end
end

function Manager:setTodayCheckFirstPage()
    self:setFlagToLocalByKey("todayCheckFirstPage", true, true)
end

function Manager:getTodayCheckFirstPage()
    return self:getFlagFromLocalByKey("todayCheckFirstPage", true)
end

function Manager:hasRewardInDayIndex(dayIndex)
    if not self:isEnabled() then return end
    local tasks = self:getModel():getAllTaskInfo()
    if not tasks then
        return false
    end
    for k, v in pairs(tasks) do
        if v.day == dayIndex then
            if self:getModel():getTaskCanGetReward(v.id) then
                return true
            end
        end
    end
    return false
end

function Manager:hasRewardInMainTime()
    if not self:isEnabled() then return end
    for k = 1,7 do
        if self:hasRewardInDayIndex(k) then
            return true
        end
    end
    return false
end

function Manager:getExtraMaxEnergy()
    return self:getModel():getExtraMaxEnergy()
end

function Manager:hasBuyVip()
    if not self:isEnabled() then return false end
    return self:getModel():hasBuyVip()
end

function Manager:getDayFromActOpen()
    if not self:isEnabled() then return 0 end
    return self:getModel():getDayFromActOpen()
end

----领奖期间是否有奖励
function Manager:hasRewardInAwardTime()
    if not self:isEnabled() then return end
    if not self:isInRewardTime() then
        return false
    end
    local hasRewards = self:getDataByKey("canPostReward")
    if self:getDataByKey("exchangeRewardGot") then ---已经领过奖了
        return false
    elseif hasRewards then ---领奖期间有奖励
        return true
    else
        return false
    end
end

function Manager:setHasGetRewardInAwardTime()
    if not self:isEnabled() then return end
    self:getModel():setDataByKey("exchangeRewardGot",true)
end

function Manager:getAllTaskInfo()
    return self:getModel():getAllTaskInfo()
end

function Manager:getTaskInfo(taskId)
    return self:getModel():getTaskInfo(taskId)
end

function Manager:setTaskInfo(taskId, data)
    self:getModel():setTaskInfo(taskId, data)
end

function Manager:showIconTip(delegate,done)
    
    if not _G.HomeIconTipsFactory then
        safeRunCall(done)
        return
    end

    local icon = self.actPlug:getActIcon()
    if icon then
        if delegate.type == self:getConst().showTipType.kShowTipType_Get then
            _G.HomeIconTipsFactory:createTextTips(icon,"有可领取的奖励哦!",{
                duration = 3,
                endCallback = done})
        elseif delegate.type == self:getConst().showTipType.kShowTipType_Energy then
            _G.HomeIconTipsFactory:createTextTips(icon,"过关可领大量精力!",{duration = 3,
                endCallback = done})
        elseif delegate.type == self:getConst().showTipType.kShowTipType_NotFull then
            _G.HomeIconTipsFactory:createProgressTips(icon,{
                min = 0,
                max = delegate.max,
                targetValue = delegate.max,
                value = delegate.value,
                labelPrefixes = self:getIsInSpecialLevel() and "完成关卡:" or "闯最高关:",
                progressChangeTime = 1,
                textMode = ProgressBar.TextMode.kFrection,
                endCallback = done
            })
        elseif delegate.type == self:getConst().showTipType.kShowTipType_Full then
            _G.HomeIconTipsFactory:createProgressTips(icon,{
                min = 0,
                max = delegate.max,
                targetValue = delegate.max,
                value = delegate.value,
                labelPrefixes = "补彩星:",
                progressChangeTime = 1,
                textMode = ProgressBar.TextMode.kFrection,
                endCallback = done
            })
        elseif delegate.type == self:getConst().showTipType.kShowTipType_Random then
            _G.HomeIconTipsFactory:createProgressTips(icon,{
                min = 0,
                max = delegate.max,
                targetValue = delegate.max,
                value = delegate.value,
                labelPrefixes = "随机挑战:",
                progressChangeTime = 1,
                textMode = ProgressBar.TextMode.kFrection,
                endCallback = done
            })
        else
            safeRunCall(done)
        end
    else
        safeRunCall(done)
    end
end

----------------------------------------------事件-------------------------------------------------------
function Manager:onActPassDay()
    BaseFeatureManager.onActPassDay(self)
    self:updateIcon()
    self:refreshEnergy()
end

function Manager:checkAndRunEnterStage2()
    if self:canPopOnStage2() then
        self:popOnStage2()
    end
end

function Manager:onActEnterStage2(evt)
    if not self:isEnabled2() then
        return
    end

    self:updateIcon()
    self:checkAndRunEnterStage2()
end

function Manager:onActEnterMainScene(event)
    local data = event:getData()
    if data.firstEnter then
        local maxEnergy = self._userEnergyManager:getMaxEnergy()
        self:getDC():dcLogin(maxEnergy)
    end
end

function Manager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(self:getConst().actId)]

    if actInfo and fromServer then 
        self:getModel():assignActInfo(actInfo) 
        self:refreshEnergy()
    end
end

function Manager:onActBeforePlayLevelEnd(event)
    if not self:isEnabled2() then return end

    local data = event:getData()
    local sourceId = self:getConst().actId
    data.jsonTable[tostring(sourceId)] = {fullLevel = self:getIsInSpecialLevel()}
end

function Manager:onActPlayLevelEnd(event)
    if not self:isEnabled2() then return end

    local data = event:getData()
    self:getModel():setTempData("nowLevelIsPassed", data.isWin)

    local startLevelType = self:getModel():getTempData("startLevelType") 
    if not startLevelType or not data.isWin then return end
    if startLevelType == self:getConst().startLevelType.UnfinishedStarLevel and data.star ~= 4 then return end

    local taskList = self:getModel():getAllTaskInfo()
    for k, v in pairs(taskList) do
        if v.taskType == self:getConst().taskType.kComplete
            and v.current < v.total 
        then
            v.current = v.current + 1
        end
    end
    self:getModel():setAllTaskInfo(taskList)
end

function Manager:onActBeforeStartLevel(event)
    if not self:isEnabled2() then return end

    local data = event:getData()
    local levelId = data.levelId
    local levelScene = data.levelScene

    self:getModel():setTempData("startLevelType", nil)

    if not UBFLevelSceneFunc:isMainLevel(levelScene) and not UBFLevelSceneFunc:isFullLevelLib(levelScene) then
        return
    end

    local topLevelId = self._levelAreaManager:getTopPassedLevel()
    if topLevelId + 1 == levelId then---没有满级且闯关和最高关相同：最高关
        self:getModel():setTempData("startLevelType", self:getConst().startLevelType.TopLevel)
    elseif self:getIsInSpecialLevel() then
        if UBFLevelSceneFunc:isFullLevelLib(levelScene) then---是关卡库
            self:getModel():setTempData("startLevelType", self:getConst().startLevelType.LevelLib)
        elseif not self._levelAreaManager:isMainLevelFullColor(levelId) then----去补星
            self:getModel():setTempData("startLevelType", self:getConst().startLevelType.UnfinishedStarLevel)
        end
    end

    if self:getModel():getTempData("startLevelType") then
        local taskList = self:getModel():getAllTaskInfo()
        for k, v in pairs(taskList) do
            if v.taskType == self:getConst().taskType.kBeginTry 
                and v.current < v.total 
            then
                v.current = v.current + 1
            end
        end
        self:getModel():setAllTaskInfo(taskList)
    end
    
    local sourceId = self:getConst().actId
    data.jsonTable[tostring(sourceId)] = {fullLevel = self:getIsInSpecialLevel()}
end

function Manager:onActCrashResumeFailed(event)
    -- if not self:isEnabled() then return end
    
end

function Manager:onActReceiveEmergency(evt)
    -- local eventData = evt:getData()

    -- if eventData and eventData.endPoint == EmergencyConst.MAGIC_1V1_EVENT_BEAN and eventData.data then
    --     local cacheData = table.clone(eventData.data)
    --     local score = cacheData.enemyScore

    --     if score then
    --         self:getModel():setEnemyScore(score)
    --         -- 更新Icon
    --         self:updateIcon()
    --     end
    -- end
end

----------------------------------------------通用-------------------------------------------------------
function Manager:isEnabled() 
    return self:getModel():isDataEnabled() and (self:isInMainTime() or self:isInRewardTime())
end

function Manager:isEnabled2()
    return self:getModel():isDataEnabled() and self:isInMainTime()
end

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
function Manager:setDataByKey(key, value) return self:getModel():setDataByKey(key, value, true) end

function Manager:getConfigByKey(key) return self:getModel():getConfigByKey(key) end

function Manager:getLocalCache(key, defaultValue) return self:getModel():getLocalCache(key, defaultValue) end

function Manager:setLocalCache(key, value) return self:getModel():setLocalCache(key, value) end

function Manager:getLocalKey(key,needTime)
    if needTime then 
        return key .. tostring(TimeKit:getDayStartTimeByTS(TimeKit:timeInSec()))
    else
        return key 
    end 
end

function Manager:setFlagToLocalByKey(key, needTime, value)
    if not key then return end
    if value == nil then value = true end
    local keyStr = self:getLocalKey(key,needTime)
    self:getModel():setLocalCache(keyStr, value)
end

function Manager:getFlagFromLocalByKey(key, needTime)
    local keyStr = self:getLocalKey(key,needTime)
    return self:getModel():getLocalCache(keyStr)
end

function Manager:addIntToLocalByKey(key, needTime, addNum)
    if not key then return end
    if addNum == nil then addNum = 1 end
    local keyStr = self:getLocalKey(key, needTime)
    local beforeNum = self:getModel():getLocalCache(keyStr) or 0
    self:getModel():setLocalCache(keyStr, beforeNum + addNum)
end

function Manager:setIntFromLocalByKey(key, needTime, setNum)
    if not key then return end
    if setNum == nil then setNum = 0 end
    local keyStr = self:getLocalKey(key,needTime)
    self:getModel():setLocalCache(keyStr, setNum)
end

function Manager:getIntFromLocalByKey(key, needTime)
    local keyStr = self:getLocalKey(key,needTime)
    return self:getModel():getLocalCache(keyStr) or 0
end
------引导标记
function Manager:addGuideIndex(index)
    local guideSet = self:getDataByKey("guideIds") or {}
    table.insert(guideSet, index)
    self:setDataByKey("guideIds", guideSet)
    local ActCommonHttp = require "amf.middleware.activity.http.ActCommonHttp"
    ActCommonHttp:setActGuideFlag(self:getConst().actId, index, true)
end

function Manager:hasGuideIndex(index)
    local guideSet = self:getDataByKey("guideIds") or {}
    for _, v in ipairs(guideSet) do
        if v == index then
            return true
        end
    end
    return false
end

function Manager:hasReward()
    --todo
    if not self:isEnabled() then return end
    if self:isInMainTime() then
        return self:hasRewardInMainTime()
    elseif self:isInRewardTime() then
        return self:hasRewardInAwardTime()
    else
        return false
    end
end

function Manager:getMsgNum() 
    return 0
end

-- 更新icon
function Manager:updateIcon()
    local icon = self.actPlug:getActIcon()
    if icon and (not icon.isDisposed) then 
        icon:updateState() 
        self.actPlug:updateTipView()
    end
end
----------------------------------------------领奖-------------------------------------------------------
function Manager:addEnergyMaxItem(num)
    local curMaxNum = self:getDataByKey("plusMaxEnergyNums") or 0
    self:setDataByKey("plusMaxEnergyNums", curMaxNum + num or 0)
    self:setDataByKey("energyMax10EndTs", self:getMainEndTime() * 1000)
    self:refreshEnergy()
end

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
------解锁的任务中有未完成的任务
function Manager:hasUnfinishedTaskUnLocked()
    local tasks = self:getModel():getUnLockTasks()
    for k, v in pairs(tasks) do
        if not self:getModel():getTaskFinished(v.id) then
            return true
        end
    end
    return false
end

------完成的总任务数
function Manager:getFinishedTaskNum()
    local tasks = self:getModel():getAllTaskInfo()
    local sum = 0
    for _, v in pairs(tasks) do
        if self:getModel():getTaskFinished(v.id) then
            sum = sum + 1
        end
    end
    return sum
end

function Manager:getAllTaskNum()
    return table.count(self:getModel():getAllTaskInfo())
end

----------------------------------------------强弹-------------------------------------------------------

function Manager:setMainPanelOpened()
    self:setLocalCache("mainPanelOpened", true)
end

function Manager:getMainPanelOpened()
    return self:getLocalCache("mainPanelOpened") or false
end

function Manager:setMainPopStage4FromType(type)
    self:setLocalCache("mainPopStage4FromType"..type, true)
end

function Manager:getMainPopStage4FromType(type)
    return self:getLocalCache("mainPopStage4FromType"..type) or false
end

function Manager:canPopMainPanelStage4(needSave)
    local ret = false

    if self:getModel():getCanPopMainPanelGroup() 
        and not self:getMainPanelOpened() 
        and not self:getMainPopStage4FromType(1) 
    then
        ret = true
        self:getModel():setTempData("popMainType",1)
        if needSave then self:setMainPopStage4FromType(1) end
    end

    if self._userEnergyManager:getEnergy() < 5 
        and not self:hasBuyVip()
        and not self:getMainPopStage4FromType(2) 
    then
        ret = true
        self:getModel():setTempData("popMainType",2)
        if needSave then self:setMainPopStage4FromType(2) end
    end

    return ret
end

----检查是否可领取大量精力
function Manager:canPopGetMuchEnergy(popInfos)
    local popOneDay = self:getFlagFromLocalByKey(self:getConst().popGetMuchEnergyTimesOneDay,true)
    local popAll = self:getFlagFromLocalByKey(self:getConst().popGetMuchEnergyAllTimes) or 0
    if popOneDay or popAll>=3 then---今天有弹出精力提醒
        return false
    else--没弹
        if self:hasUnfinishedTaskUnLocked() and self:getFinishedTaskNum() <= self:getAllTaskNum()/2 then
            popInfos.popMuchEnergy = true
            return true
        else
            return false
        end
    end
end

function Manager:checkCurTimeCanPop()
    local topLv = _G.amfBean("LevelUnLockManager"):getLocalTopLevel(false)
    local myTopLv = _G.getTopPassedLevelId()
    if topLv - myTopLv <= 45 then
        local lastOpenTime = _G.amfBean("LevelUnLockManager"):getLastOpenNewLevelTime()
        if lastOpenTime then
            local diffTime = TimeKit:timeInSec() - lastOpenTime
            if diffTime >= 0 and diffTime < 4 * 3600 then
                return false
            end
        end
    end
    return true
end

------获取一系列已经显示过的页签
function Manager:hasShowTask(id)
    local showTasks = self:getLocalCache("showTasks") or {}
    return table.exist(showTasks, id)
end

function Manager:setShowTask(id)
    local showTasks = self:getLocalCache("showTasks") or {}
    table.insert(showTasks, id)
    self:setLocalCache("showTasks", showTasks)
end

------检测是否推送过任务
function Manager:hasPopedTasks(id)
    return self:hasGuideIndex(id)
end

function Manager:setHasPoped(popInfos)
    for k, v in pairs(popInfos) do
        self:addGuideIndex(v.id)
    end
end

----检查有可领取的奖励哦
function Manager:canPopHasRewardEnergy2(ret)
    local unGetFreeRewars = self:getModel():getUnLockTasks()
    -- local hasShowTab = self:getHasShowTab()
    table.sort(unGetFreeRewars, function(a, b)
        return a.id > b.id  -- a 应该排在 b 前面时返回 true
    end)
    local popInfos = {}
    for k, v in ipairs(unGetFreeRewars) do
        if v.id ~= 1 then
            if not self:hasShowTask(v.id) and not self:hasPopedTasks(v.id) and self:getModel():getTaskCanGetReward(v.id) then---如果没有显示过Tab且没有推送过
                table.insert(popInfos, v)
            end
        end
    end
    if not table.isEmpty(popInfos) then
        ret.popHasRewardEnergy2 = popInfos
    end
end

function Manager:canPopHasRewardEnergy34(ret)
    local unGetFreeRewars = self:getModel():getUnLockTasks()
    -- local hasShowTab = self:getHasShowTab()
    table.sort(unGetFreeRewars, function(a, b)
        return a.id > b.id  -- a 应该排在 b 前面时返回 true
    end)
    local popInfos = {}
    for k, v in ipairs(unGetFreeRewars) do
        if v.id ~= 1 then
            if not self:hasShowTask(v.id) and not self:hasPopedTasks(v.id) and self:getModel():getTaskCanGetReward(v.id) then---如果没有显示过Tab且没有推送过
                table.insert(popInfos, v)
            end
        end
    end
    if not table.isEmpty(popInfos) then
        ret.popHasRewardEnergy34 = popInfos
    end
end

function Manager:canPopOnStage4()
    self.popInfos4 = {}
    if not self:isInMainTime() then
        return false
    end
    if not self:checkCurTimeCanPop() then
        return false
    end
    if self:canPopMainPanelStage4() then
        return true
    end
    self:canPopGetMuchEnergy(self.popInfos4)
    self:canPopHasRewardEnergy34(self.popInfos4)
    return not table.isEmpty(self.popInfos4)
end

function Manager:popOnStage4(callback)

    if self:canPopMainPanelStage4(true) then
        self.actPlug:openActivity({
            actId = self:getConst().actId,
            endCallback = callback,
            failCallback = callback,
            userClick = false,
            extra = {popType = self:getModel():getTempData("popMainType")}
        })
        return
    end

    if self.popInfos4 then
        local asyncRunner = AsyncRunner:create()
        if self.popInfos4.popMuchEnergy then
            asyncRunner:add(function(done)
                self:setFlagToLocalByKey(self:getConst().popGetMuchEnergyTimesOneDay,true,true)
                self:addIntToLocalByKey(self:getConst().popGetMuchEnergyAllTimes,false, 1)
                self:showIconTip({
                    type = self:getConst().showTipType.kShowTipType_Energy,
                },done)
            end)
        end
        if self.popInfos4.popHasRewardEnergy34 and not table.isEmpty(self.popInfos4.popHasRewardEnergy34) then
            asyncRunner:add(function(done)
                local nowLevelIsPassed = self:getModel():getTempData("nowLevelIsPassed")
                if nowLevelIsPassed then--过关了
                    self:showIconTip({
                        type = self:getIconTipType(),
                        max = self.popInfos4.popHasRewardEnergy34[1].total,
                        value = self.popInfos4.popHasRewardEnergy34[1].total-1,
                    },done)
                else---没过关
                    self:showIconTip({
                        type = self:getConst().showTipType.kShowTipType_Get,
                    },done)
                end
                self:setHasPoped(self.popInfos4.popHasRewardEnergy34)
            end)
        end
        asyncRunner:add(function(done)
            safeRunCall(callback)
            done()
        end)
        asyncRunner:run()
    else
        safeRunCall(callback)
    end
end

function Manager:canPopOnStage2()
    self.popInfos2 = {}
    if not self:isInMainTime() then
        return false
    end
    if not self:checkCurTimeCanPop() then
        return false
    end
    self:canPopGetMuchEnergy(self.popInfos2)
    self:canPopHasRewardEnergy2(self.popInfos2)
    return not table.isEmpty(self.popInfos2)
end

function Manager:popOnStage2(callback)
    if self.popInfos2 then
        local asyncRunner = AsyncRunner:create()
        if self.popInfos2.popMuchEnergy then
            asyncRunner:add(function(done)
                self:setFlagToLocalByKey(self:getConst().popGetMuchEnergyTimesOneDay,true,true)
                self:addIntToLocalByKey(self:getConst().popGetMuchEnergyAllTimes,false, 1)
                self:showIconTip({
                    type = self:getConst().showTipType.kShowTipType_Energy,
                },done)
            end)
        end
        if self.popInfos2.popHasRewardEnergy2 and not table.isEmpty(self.popInfos2.popHasRewardEnergy2) then
            asyncRunner:add(function(done)
                self:showIconTip({
                    type = self:getConst().showTipType.kShowTipType_Get,
                    max = self.popInfos2.popHasRewardEnergy2[1].total,
                    value = self.popInfos2.popHasRewardEnergy2[1].total-1,
                },done)
                self:setHasPoped(self.popInfos2.popHasRewardEnergy2)
            end)
        end
        asyncRunner:add(function(done)
            safeRunCall(callback)
            done()
        end)
        asyncRunner:run()
    else
        safeRunCall(callback)
    end
end

function Manager:canPopOnStage3()
    self.popInfos3 = {}
    if not self:isInMainTime() then
        return false
    end
    if not self:checkCurTimeCanPop() then
        return false
    end
    self:canPopHasRewardEnergy34(self.popInfos3)
    return not table.isEmpty(self.popInfos3)
end

function Manager:getIconTipType()
    local startLevelType = self:getModel():getTempData("startLevelType")
    if startLevelType == self:getConst().startLevelType.TopLevel then--最高关
        return self:getConst().showTipType.kShowTipType_NotFull
    elseif startLevelType == self:getConst().startLevelType.LevelLib then
        return self:getConst().showTipType.kShowTipType_Random
    else
        return self:getConst().showTipType.kShowTipType_Full
    end
end

function Manager:popOnStage3(callback)
    if self.popInfos3 then
        local asyncRunner = AsyncRunner:create()
        if self.popInfos3.popHasRewardEnergy34 and not table.isEmpty(self.popInfos3.popHasRewardEnergy34) then
            asyncRunner:add(function(done)
                local nowLevelIsPassed = self:getModel():getTempData("nowLevelIsPassed")
                if nowLevelIsPassed then--过关了
                    self:showIconTip({
                        type = self:getIconTipType(),
                        max = self.popInfos3.popHasRewardEnergy34[1].total,
                        value = self.popInfos3.popHasRewardEnergy34[1].total-1,
                    },done)
                else---没过关
                    self:showIconTip({
                        type = self:getConst().showTipType.kShowTipType_Get,
                    },done)
                end
                self:setHasPoped(self.popInfos3.popHasRewardEnergy34)
            end)
        end
        asyncRunner:add(function(done)
            safeRunCall(callback)
            done()
        end)
        asyncRunner:run()
    else
        safeRunCall(callback)
    end
end

---------------------------------- CUSTOM_GAIN ----------------------------------

function Manager:_onCustomGain(event)
    local reward = event:getData()
    if reward.itemId == self:getConst().maxEnergyItemId then
        self:addEnergyMaxItem(reward.num)
    end
end

return Manager
