local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local ActivityName = "CoinPromotions"
local Manager = class(ActivityName.."Mgr", BaseFeatureManager)

----------- 可能需要修改start -----------
Manager.ACT_OPEN_VERSION = 6
Manager.ACT_ID = 5066
Manager.ACT_SOURCE = "coinpromotions/Config.lua"
Manager.ACT_CH_NAME = "金币狂欢日"
Manager.ACT_NAME = ActivityName
-- Manager.DCSource = "act_"..Manager.ACT_ID .. "_main"
Manager.GAME_NAME = "happycoin_carnival"

function Manager:log(...)
    if EnvUtil:isDevelopMode() then
        printx(42, "----------金币狂欢日--------------", ...)
    end
end

-- 获取常量路径
function Manager:_getConstPath()
    return "amf.feature.localactivity.coinpromotions.config.CoinPromotionsConst"
end

-- 获取model路径
function Manager:_getModelPath()
    return "amf.feature.localactivity.coinpromotions.model.CoinPromotionsModel"
end

-- 如果有自己需要初始化的内容，覆写这个
function Manager:_init()
    self:registerActProps()
    self:registerNotify()

end

function Manager:registerNotify()
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)

    if EnvUtil:isAMFEnabled() then
        self.__userCashChange = function(event)
            local data = event:getData()
            if not data then return end
            if not data.key then return end
            if data.key ~= "cash" then return end
            if not data.oldValue then return end
            if not data.newValue then return end

            local changeNum = data.newValue - data.oldValue
            if changeNum and changeNum < 0 and self:isInConsumePhase()  then
                self:getData():addConsumeNum(-changeNum)
            end
        end
        _G.amfEC:registerNormal(NormalEvent.USER_ASSET_CHANGE, self.__userCashChange)
    else
        -- cocos APP内还没接入，用老的
        self.__userCashChange = function(event)
            local changeNum = event.data.changeCash
            if changeNum and changeNum < 0 and self:isInConsumePhase()  then
                self:getData():addConsumeNum(-changeNum)
                if self:isInCanOpenTime() then
                    self.isCostCash = true
                end
            end
        end
        GlobalEventDispatcher:getInstance():addEventListener(kGlobalEvents.kUserCashChange,self.__userCashChange)
    end
end

function Manager:passDayRefreshData()
    -- self:onPassDay()
end

-- 获取需要启动的额外功能列表
function Manager:_getExtraPlugsConfigList()
    return {
        {
            key = "Rewards",
        },
        {
            key = "Panel",
        },
        {
            key = "ActSend",
            path = {
                plugPath = "amf.feature.localactivity.coinpromotions.plug.CoinPromotionsActSendPlug",
                const = self:_getConstPath()
            },
        }
    }
end

-- 注册活动道具
function Manager:registerActProps()

end

function Manager:isEnabled()
    return self:getModel():isDataEnabled() and self:isInMainTime()
end

function Manager:isEnabled2()
    return self:getModel():isDataEnabled()
end

-- 预热期
function Manager:isInPreTime(  )
    return self:getModel():isInPreheatTime()
end

--是否是主活动期
function Manager:isInMainTime()
    return self:getModel():isInMainTime()
end

--是否是领奖期
function Manager:isInRewardTime()
    return self:getModel():isInRewardTime()
end

-- 同步所有数据
function Manager:updateData(data, skipSaveLocal, fromServer)
    if not data then return end

    self:getModel():fromServer(data,skipSaveLocal)

    if fromServer == true then
        self.hasGetDataFromServer = true
    end
end

-- 是否是活动正式期最后一天
function Manager:isLastDay(  )
    local todayStartTime = getDayStartTimeByTS(TimeKit:timeInSec())
    local lastDayStartTime = getDayStartTimeByTS(self:getModel():getActMainEndTime())
    return todayStartTime == lastDayStartTime
end

-- 获取服务器时间是活动周期内的第几天
function Manager:getDayFromActOpen( time )
    if not self:isEnabled() then return 0 end
    local startTime = getDayStartTimeByTS(self:getModel():getActMainBeginTime())
    local curTime = getDayStartTimeByTS(time or TimeKit:timeInSec())
    return math.floor((curTime-startTime)/86400)+1
end

function Manager:getDayFrom1970( time )
    local curDayStartTime = getDayStartTimeByTS(time or TimeKit:timeInSec())
    return math.ceil(curDayStartTime/86400)
end

-- 检测引导标记
function Manager:hasGuideIndex(index, checkLocalData)
    local hasIndex = self:getModel():hasGuide(index)

    if checkLocalData == nil then checkLocalData = true end
    if checkLocalData then
        local hasLocal = self:getModel():getFlagFromLocalByKey("LocalGuideId"..index, false)
        if hasLocal then
            if not hasIndex then self:addGuideIndex(index) end
            hasIndex = true
        end
    end
    return hasIndex
end

-- 设置引导标记
function Manager:addGuideIndex(index, needSaveLocal)
    self:getModel():setGuide(index)

    if needSaveLocal == nil then needSaveLocal = true end
    if needSaveLocal then
        self:getModel():saveFlagToLocalByKey("LocalGuideId"..index, false, true)
    end

    local ActCommonHttp = require 'amf.middleware.activity.http.ActCommonHttp'
    ActCommonHttp:setActGuideFlag(Manager.ACT_ID, index)
end

function Manager:onPassDay()
    -- if not self:isEnabled() then return end
    -- self:getModel():passDayClear()
end

function Manager:openActivity(closeCallback,extra,userClick)
    -- openActivity(nil, {from = "YinLiu1"}, true)
    self:callPlug("Act","openActivity",{
        actId = self.ACT_ID,
        extra = extra,
        failCallback = closeCallback,
        endCallback = closeCallback,
        userClick = userClick,
    })
end

-- 场景值填2
function Manager:addIconTip(from, to, onHandlerOver, config)
    if (not EnvUtil:isAMFEnabled()) or EnvUtil:isMiniGame() then
        safeRunCall(onHandlerOver)
        return
    end

    local nextPoint = self:getData():getPointNeed(self:getData():getNextProgressPoint(from))
    local nowProgress = to
    local befP = self:getData():getBefProgressPoint(from)
    local befPoint = 0
    if befP == 0 then
        befPoint=self:getData():getPointNeed(befP)
    end
    local delegate = {
        value = from ,
        targetValue = math.min(nextPoint,nowProgress) ,
        max = nextPoint,
        min = befPoint,
        endCallback = onHandlerOver,
        textMode = 0,
        customTextCall = function(progressBar, curVal,totalNum)
            if progressBar.isDisposed then return end
            progressBar.label:setString(curVal + befPoint.."/".. nextPoint)
        end,
        progressChangeTime = 0.3,
    }

    local path = "amf.feature.localactivity.coinpromotions.views.uisource.IconAwardProgressTip_UI"
    local uiData = require(path)
    local uiList = {}
    UIBuilder:buildUI( uiData , uiList,"moveSprite_label_group")
    -- UIBuilder:buildUI( uiData , uiList,"group_6838")
    uiList.moveSprite_label_group:removeFromParentAndCleanup(false)
    uiList.moveSprite_label_group:setScale(0.7)
    local cutConfig = {
        {
            per = 1,
            closeIcon = uiList.moveSprite_label_group,
            offset = ccp(-25,-5),
        }
    }
    delegate.cutConfig = cutConfig
    delegate.cutChangeCallback = function() end
    delegate.iconDiCreator = function()
        local sprite = Sprite:createWithSpriteFrameName( "ChouTiao_2024/HomeIconTips/已消费  拷贝") ---抽条的纹理
        return sprite
        --uiList.group_6838:removeFromParentAndCleanup(false)
        --return uiList.group_6838
    end
    delegate.tipsType = HomeIconTipsType.PROGRESS

    local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")
    IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, {
        iconKey = tostring(self:getConst().actId),
        iconType = IconTipType.MESSAGE,
        creatorDelegate = delegate,
        typeIndex = 1,
        -- popFunc = function()  end,
        config = config,
    })

end

function Manager:createScoreBuffIcon(reward)
    local str = {
        [self:getConst().score20BuffId] = "120",
    }

    local item = Sprite:createWithSpriteFrameName("other/iconV2/ui_icon_star_02_v2")

    local scoreTitleLabel = TTFLabel:createAnimalYH( '分数', 18 )
    scoreTitleLabel:setTextColor(hex2ccc4('e6830cff'))
    scoreTitleLabel:setPositionXY(45,85)
    item:addChild(scoreTitleLabel)

    local scoreLabel = TTFLabel:createAnimalYH( 'x' .. str[reward.itemId] .. '%', 18 )
    scoreLabel:setPositionXY(27,63)
    scoreLabel:setTextColor(hex2ccc4('e6830cff'))
    scoreLabel:enableOutline(hex2ccc4('ffffffff'),2)
    item:addChild(scoreLabel)

    if reward.endTime then
        local numSp = AMFCompHelper:createInfiniteTimeLimitWidget({itemId = 10098, expireTime = reward.endTime}, true)
        item:addChild(numSp)
    elseif reward.num then
        local numSp = AMFCompHelper:createInfiniteTimeLimitWidget({itemId = 10098, num = reward.num})
        item:addChild(numSp)
    end

    return item
end

function Manager:addRewardsWhenBought(goodsId, rewardItems, params)
    self:callPlug("Rewards","addRewardsWhenBought", goodsId, rewardItems, params)
end

-- 普通的addRewards,开宝箱之类的
function Manager:addRewardsNormal(rewardItems, params)
    self:callPlug("Rewards","addRewardsNormal", rewardItems, params)
end

-- 商城加奖励
function Manager:addRewardsForShop(rewardBean,params)
    self:callPlug("Rewards","addRewardsForShop", rewardBean,params)
end


function Manager:getLocalDataServer()
    return self:getModel()
end

function Manager:getData()
    return self:getModel()
end

-- function Manager:getFuncId()
--    return CoinPromotionsMgr.FUNC_ID
-- end

function Manager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(self:getConst().actId)]
    -- not 服务器发来且有actInfo，就返回
    if not (fromServer and actInfo) then return end

    if self:getActInfo() and not self:getActivityIcon() then
        if EnvUtil:isAMFEnabled() then
            ActivityEventCenter:dispatch(ActivityEvent.UPDATE_SINGLE_ACTIVITY,{actId = self.ACT_ID})
        else
            HomeScene:sharedInstance():buildActivityButton()
        end
    end
end

function Manager:hasReward()
    if not self:isEnabled() then return end
    if self:isInConsumePhase() or self:isInConsumeRewardPhase()  then
        local rewardStatus = self:getData():getRewardStatus()
        local nowPoint = self:getData():getProgressPoint()
        if rewardStatus then
            for id = 1 , nowPoint do
                if not rewardStatus[id] then return true end
            end
        end
    end
    if self:isInSignState() then
        local signRewards = self:getData():getSignStatus()
        local nowDay = math.min(3,self:getData():getSignDay())
        if signRewards then
            for id = 1 , nowDay do
                if not signRewards[id] then return true end
            end
        end
    end
    return false
end

function Manager:hasRewards()
    return self:hasReward()
end

function Manager:getShowMsgNum()
    if not self:isEnabled() then return 0 end
end

--解析活动数据
function Manager:parseData(data)
    if data then
        self:getData():fromServer(data,nil )
    end
    if not self.hasServerData then
        self:updateTipView()
        self.hasServerData = true
    end
end

function Manager:getDcFeatureAndSource( suffix )
    return self:callPlug("Rewards","_getDCFeatureAndSource", suffix)
end

function Manager:getActivityIcon()
    return self:callPlug("Act", "getActIcon", self.ACT_ID)
end

function Manager:isInSignState()
    local actInfo = self:getActInfo()
    if actInfo and actInfo.extra then
        local extra = table.deserialize(actInfo.extra)
        local stTime = tonumber(extra.signPhaseStartTime or 0 ) / 1000
        local endTime = tonumber(extra.signPhaseEndTime or 0) / 1000
        local nTime = TimeKit:timeInSec()
        return stTime <= nTime and endTime > nTime
    end
    return false
end

function Manager:createIcon(reward,needNum)
    if not reward or table.isEmpty(reward) then
        if EnvUtil:isDevelopMode() then CommonTip:showTip("什么玩意咋没给道具还要创呢？") end
        return Sprite:createEmpty()
    end
    local reward = table.clone(reward)
    reward.needNum = needNum
    local icon
    if reward.itemId == self:getConst().score20BuffId then
        icon = self:createScoreBuffIcon(reward)
    else
        icon = GameItemCreator:getPropIcon(reward)
    end
    return icon
end

-- 第一天场景3弹出判断
function Manager:checkFirstDayCanPop()
    local actInfo = self:getActInfo()
    if actInfo and actInfo.extra then
        local extra = table.deserialize(actInfo.extra)
        local startTime = tonumber(extra.actStartTime or 0) / 1000
        return TimeUtil:isSameDay(startTime, TimeKit:timeInSec()) and (not self:hasMainPanelShow())
    end
    return false
end

function Manager:checkStage3CanPop()
    if self:ignoreForTopLevelPlayer() then return false end
    if self:checkFirstDayCanPop() then return true end
    if self:isInSignState() then return false end
    local oldPoint = self:getData():getOldPoint()
    local newPoint = self:getData():getProgressPoint()
    -- 每个区间只会弹出一次，比如35-80区间
    -- 当币消耗45时，判断消耗(45-35) < 45*2/3，所以能弹出
    -- 此时记录35-80弹出过，后面该区间就不会弹出主面板了
    if newPoint <= oldPoint or newPoint >= 3 then
        self:log("新旧区间一致，或超出最后节点，不弹出主面板",newPoint,oldPoint)
        return false
    end
    local lastNeed = math.max(0,self:getData():getPointNeed( newPoint ))
    local nextNeed = math.max(0,self:getData():getPointNeed( newPoint + 1 ))
	local nowValue = self:getData():getNowConsume() or 0
    self:log("检测区间风车币消耗量",nowValue - lastNeed,2/3*(nextNeed - lastNeed))
    if nowValue - lastNeed <= 0 then return false end
    -- 进入新区间时消耗不到该区间的2/3就能弹出
    local canPopMainPanel = (nowValue - lastNeed) <= 2/3*(nextNeed - lastNeed)
    return canPopMainPanel
end

function Manager:checkCanPopProgressAnim()
    if not self:isEnabled() then return false end
    if self:isInSignState() then return false end

    local icon = self:getActivityIcon()
    if not icon then return false end
    if self:getData():getNextProgressPoint(self:getLastProgress()) == 0  then return false end--全满了
    -- 本地记录的上次进度比现在消耗的小
    return self:getLastProgress() < self:getData():getNowConsume()
end

function Manager:checkIconTip(config)
    self.tipPop = false
    if not self:checkCanPopProgressAnim() then return end
    self.tipPop = true
    self:addIconTip(self:getLastProgress(), self:getData():getNowConsume(), function() self:setLastProgress() end, config)
end

function Manager:setLastProgress()
    local lastProgress = self:getLastProgress()
    self:getData():saveFlagToLocalByKeyInt("lastProgress", nil, math.max( lastProgress,self:getData():getNowConsume() ) or 0)
end

function Manager:getLastProgress()
    return self:getData():getFlagFromLocalByKeyInt("lastProgress")
end

function Manager:doMainPanelShow()
    self:getData():saveFlagToLocalByKey("showMainPanel", nil, true)
end

function Manager:hasMainPanelShow()
    return self:getData():getFlagFromLocalByKey("showMainPanel")
end

function Manager:onStage3Popout(onHandlerOver)
    if not self:checkCanPopProgressAnim() and (not self.tipPop) then
	    local t2 = self:hasMainPanelShow() and 2 or 1
        self:openActivity(function()
            self:getData():setLocalPoint()
            safeRunCall(onHandlerOver)
        end,{t2 = t2},false)
    else
        safeRunCall(onHandlerOver)
    end
end

function Manager:checkStage4CanPop()
    if not self:isInSignState() then return false end
    if self:ignoreForTopLevelPlayer() then return false end
    if self:getData():getFlagFromLocalByKey("mainPanel_stage4",true) then return false end
    return self:getData():hasSignChance()


end

function Manager:onStage4Popout(onHandlerOver)
    self:openActivity(onHandlerOver,{t2 = 3},false)
    self:getData():saveFlagToLocalByKey("mainPanel_stage4",true,true)
end

-- 在新关开启的指定时间内（暂定4小时），玩家主线关满星前，闯头部新关不触发关卡内结算面板点叉的场景4强弹
function Manager:ignoreForTopLevelPlayer()
	local userState = _G.amfBean("UserStateManager"):getUserSegmentState()
    if userState == _G.UserStateConst.UserSegmentState.MHZC  then
        return false
    end

    if not _G.amfBean("LevelUnLockManager"):isInNewLevelTime() then
        return false
    end

    return true
end
---------------------------------- 关卡内 begin--------------------------------
function Manager:syncActTime(startTime,endTime)
    self.actStartTime = startTime
    self.actEndTime = endTime
end

function Manager:isInCanOpenTime()
    if not self.actStartTime or not self.actEndTime then return false end
    return TimeKit:timeInSec() > self.actStartTime and self.actEndTime > TimeKit:timeInSec()
end

--关卡内触发条件
function Manager:isEnabledInLevel(data)
    if not self:isEnabled() then return false end
    -- if not self:isInCanOpenTime() then return false end

    -- 活动当前处于任务阶段正式期且进度不为满
    local isInTaskMainTime = self:isInConsumePhase()
    if not isInTaskMainTime then return false end
    local point = self:getData():getProgressPoint()
    if point >= 3 then return false end

    return true
end

--关卡内活动启动数据
function Manager:getInLevelActData(levelId)
    local inLevelActData = {
        roundId = self:getData():getCurrRoundId()
    }

    return inLevelActData
end

--获取分数BUFF加成值跟buff结束时间
function Manager:getCurAvailableBuffAndEndTime(data)
    local buffRate = 0.2
    local buffEndTime =  self:getData():getBuffEndTime()
    buffEndTime = buffEndTime * 1000

    return buffRate, buffEndTime
end

function Manager:getActInfo()
    return _G.amfBean("ActivityMgr"):getActInfo(Manager.ACT_ID)
end

function Manager:isInConsumePhase(lastTime)
    if self:isInSignState() then return false end --这个时间可能冲突
    lastTime = lastTime or 0
    local actInfo = self:getActInfo()
    if actInfo and actInfo.extra then
        local extra = table.deserialize(actInfo.extra)
        local stTime = tonumber(extra.actStartTime or 0) / 1000
        local endTime = tonumber(extra.taskPhaseEndTime or 0) / 1000 - lastTime
        local nTime = TimeKit:timeInSec()
        return stTime <= nTime and endTime > nTime
    end
    return false
end

function Manager:canSeeAct()
    local actInfo = self:getActInfo()
    return actInfo and actInfo.see
end

function Manager:isInConsumeRewardPhase(lastTime)
    if self:isInSignState() then return false end --这个时间可能冲突
    lastTime = lastTime or 0
    local actInfo = self:getActInfo()
    if actInfo and actInfo.extra then
        local extra = table.deserialize(actInfo.extra)
        local stTime = tonumber(extra.taskPhaseEndTime or 0 ) / 1000
        local endTime = tonumber(extra.taskRewardPhaseEndTime or 0) / 1000
        local nTime = TimeKit:timeInSec()
        return stTime <= nTime and endTime > nTime
    end
    return false
end

function Manager:onActReceiveEmergency(evt)
    local eventData = evt:getData()
    -- 出关时获得的数据，看如果有活动id，就强行设置可在场景3弹出
    if eventData and eventData.endPoint == EmergencyConst.ACT_EVENT and eventData.data then
        local cacheData = table.clone(eventData.data)
        if cacheData and type(cacheData) == "table" and cacheData.actId == self:getConst().actId then
            self.canPopMainPanelInStage3 = true
        end
    end
end

function Manager:onActEnterStage3()
    if not self.canPopMainPanelInStage3 then return end
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.COIN_PROMOTIONS_POP)
    end

    local creator = function ( ... )
        self.canPopMainPanelInStage3 = false
        setTimeOut(function()
            local t2 = self:hasMainPanelShow() and 2 or 1
            local hasPop =  self:hasMainPanelShow()
            local canSee = self:canSeeAct()

            if canSee and not hasPop then
                self:openActivity(function()
                    safeRunCall(onHandleOver)
                end,{t2 = t2})
            else
                safeRunCall(onHandleOver)
            end
        end,0.5)
    end

    if self.canPopMainPanelInStage3  then
        _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.COIN_PROMOTIONS_POP, creator, 5066)
    end
end

-- 1.距离活动结束时间至少还有10分钟才可以 2.当前页面+5步的价格大于等于完成下一档任务所需风车币
function Manager:isCanShowAddFiveBtnTipView(currPrice)
    if not MaintenanceManager:getInstance():isEnabledInGroup("coinback", "ON3")
    and not MaintenanceManager:getInstance():isEnabledInGroup("coinback", "ON4") then
		return false
	end
    if not self:getActInfo() then
        return false
    end
    if not self:getData():getConfigByKey("gearList") then
        return false --没数据不走
    end

    --6gao不走
    local payTag = UserTagManager:getUserPaymentTag2()
    if payTag == UserPaymentTag.kHigh6 then return false end

    local viewData
    local cashbackCount = 0
    local isInTime = self:isInConsumePhase(10 * 60)
    local oldPoint = self:getData():getProgressPoint()
    local newPoint = self:getData():getProgressPoint(currPrice + self:getData():getNowConsume())
    if isInTime then
        viewData = {
            cashbackCount = cashbackCount,
            isFormalPeriod = true
        }
        if newPoint > oldPoint then
            for p = oldPoint + 1 ,newPoint do
                local l,r = self:getData():getPointGoldNum(p)
                cashbackCount = cashbackCount +  l
            end
            viewData.cashbackCount = cashbackCount
            viewData.isRandom = newPoint == 3
            viewData.isFormalPeriod = false
        end
    end

    return viewData
end
---------------------------------- 关卡内 end----------------------------------

return Manager
