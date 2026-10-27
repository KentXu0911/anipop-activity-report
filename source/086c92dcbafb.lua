local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")
local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"
local ActivityFakeIconFactory = require "amf.feature.mainscene.module.icon.util.ActivityFakeIconFactory"
local Manager = class("MergeEvolutionManager", BaseFeatureManager)

function Manager:setAutoPopupMgr(autoPopupMgr)
    self.autoPopupMgr = autoPopupMgr
end

-- 功能是否可以启动
function Manager:isEnabled()
    -- printx(41,"MergeEvolutionManagerisEnabled",self:getModel():isDataEnabled(),self:isInMainTime())
    local dataEnable = self:getModel():isDataEnabled()
    local timeEnable = self:isInMainTime()
    local timeEnableInReward = timeEnable or self:isInRewardTime()
    local resEnable = self:isResEnabled()
    --if self:isFinish() then return end
    if dataEnable and timeEnableInReward and not resEnable then
        self:callDownloadFunc("startDownload")
    end
    return dataEnable and timeEnable and resEnable
end

function Manager:isEnabled2()
    local dataEnable = self:getModel():isDataEnabled()
    local timeEnable = self:isInMainTime() or (self:isInRewardTime() and
        (self:canGetRewards() or self:checkNeedSettle()))
    local resEnable = self:isResEnabled()
    if dataEnable and timeEnable and not resEnable then
        self:callDownloadFunc("startDownload")
    end
    return dataEnable and timeEnable and resEnable
end

function Manager:isResEnabled()
    return self:callDownloadFunc("checkDownloadSuccess")
end

function Manager:_init()
    self._dc = require(self:_getDCPath())
    self:registerActProps()
    self:registerEvent()
end

function Manager:registerActProps()
    local const = self:getConst()
    for _, v in pairs(const.ActProps) do
        require("amf.feature.localactivity.mergeevolution.prop.AMFProp_" .. v)
    end
end

function Manager:registerEvent()
    IconTipEventCenter:register(IconTipEvent.CHECK_ICON_TIP, self.onActCheckIconTip, self)
    self:callActFunc("registerActInfoUpdate", "onActInfoUpdate")
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
end

function Manager:addActItem(reward)
    local props = self:getConst().ActProps
    if reward.itemId == props.SCORE_BUFF_20 then
        self:getModel():addScoreBuff(1, reward.num)
    elseif reward.itemId == props.SCORE_BUFF_50 then
        self:getModel():addScoreBuff(2, reward.num)
    elseif reward.itemId == props.COLLECTION then
        self:getModel():addCollectionNum(reward.num)
        self:callActFunc("updateTipView")
    end
end

-- 获取需要启动的额外功能列表
function Manager:_getExtraPlugsConfigList()
    return {
        {
            key = "AutoPop",
        },
        {
            key = "Download",
        },
        {
            key = "Panel",
        },
        {
            key = "Rewards",
            path = {
                plugPath = "amf.feature.localactivity.mergeevolution.plug.RewardsPlug",
            }
        },
        {
            key = "Request",
            path = {
                plugPath = "amf.feature.localactivity.mergeevolution.plug.RequestPlug",
            }
        },
        {
            key = "Haptics",
            path = {
                plugPath = "amf.feature.localactivity.mergeevolution.plug.HapticsPlug",
                const = self:_getConstPath()
            },
        },
        {
            key = "ActExchangeReceiver",
            path = {
                plugPath = "amf.feature.localactivity.mergeevolution.plug.ActExchangeReceiver",
                const = self:_getConstPath()
            }
        },
        {
            key = "ActSent",
            path = {
                plugPath = "amf.feature.localactivity.mergeevolution.plug.ActSentPlug",
                const = self:_getConstPath()
            },
        },
        {
            key = "ActSend",
            path = {
                plugPath = "amf.feature.localactivity.mergeevolution.plug.ActSendPlug",
                const = self:_getConstPath()
            },
        },
        {
            key = "LocalPush",
            path = {
                plugPath = "amf.feature.localactivity.mergeevolution.plug.LocalPush",
                const = self:_getConstPath()
            }
        }
    }
end

function Manager:_getAutoPopConfigList()
    return {
        {
            checkPoint = PopupCheckPoint.MERGE_EVOLUTION_STAGE4_POP,
            actId = self:getConst().actId,
            stages = {AutoPopupConst.PopStage.STAGE_FOUR},
            check = function()
                if not self:isActivitySupported(self:getConst().actId) then return false end
                return self:checkCanPop() == true
            end,
            pop = function(_, onPopOver)
                return function()
                    self:popFunction(onPopOver)
                end
            end,
        },
    }
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

    local extra = self:callActFunc("getActInfoExtraData")
    if extra then
        local beginTime = extra.periodMainBeginTs
        local time = {
            beginTime = beginTime,
            mainBeginTime = beginTime,
            mainEndTime = extra.periodMainEndTs,
            endTime = extra.periodPostEndTs
        }
        local oldMainBeginTime = self:getModel():getMainBeginTime()
        if math.floor(tonumber(beginTime) / 1000) ~= oldMainBeginTime then
            self:getModel():clearData()
            self:getModel():updateTimeInfo(time)
            self:getModel():setPeriodId(extra.periodId)
            local actIcon = self:callActFunc("getActIcon")
            if actIcon and not actIcon.isDisposed then
                actIcon:updateCountDown()
            end
        end

        self:getModel():setTodayCostEnergy(extra.todayCostEnergy)
        if extra.latestFlowcNotShowTodayTs then
            if TimerUtil:isSameDay(TimeKit:timeInSec(),tonumber(extra.latestFlowcNotShowTodayTs)) then
                self:getModel():setNotShowToday(true)
            end
        end
    end


    
end

function Manager:clearData()
    self:getModel():clearData()
end

-- 获取常量路径
function Manager:_getConstPath()
    return "amf.feature.localactivity.mergeevolution.const.MergeEvolutionConst"
end

-- 获取model路径
function Manager:_getModelPath()
    return "amf.feature.localactivity.mergeevolution.model.MergeEvolutionModel"
end

function Manager:_getDCPath()
    return "amf.feature.localactivity.mergeevolution.dc.MergeEvolutionDC"
end

function Manager:getDC() return self._dc end

function Manager:loadRes(delegate)
    delegate = delegate or {}
    if not delegate.resList then
        safeRunCall(delegate.failCallback)
        return
    end
    self:callDownloadFunc("getAssetsUtil"):loadMiniFiles(delegate.resList)
        :next(delegate.successCallback, delegate.failCallback)
end

-- 同步所有数据
function Manager:updateData(data, fromServer)
    if not data then return end
    self:getModel():fromServer(data)
    self:refreshPackageMetas()

    if not self.registerPush then
        self.registerPush = true
        self:callLocalPushFunc("tryRegisterSinglePush")
    end
    
end

function Manager:refreshPackageMetas()
    local packageInfos = self:getModel():getPackageMetas()
    for k, v in pairs(packageInfos) do
        -- local meta = table.deserialize(v.packageMeta)
        GoodsManager:registerGoods({
            goodsId = k,
            packageMeta = v.packageMeta,
        })
    end
end

--------------------- icon ---------------------
function Manager:hasReward()
    if not self:isEnabled2() then return false end
    local hasReward = self:canGetRewards()
    return (self:isInMainTime() and (hasReward or self:hasHandBookReward()))
        or (self:isInRewardTime() and (hasReward or self:checkNeedSettle()))
end

function Manager:getMsgNum()
    if not self:isEnabled() then return 0 end
    if self:isFinish() then return 0 end

    local num = self:getModel():getCollectionNum()
    return num
end

function Manager:checkNeedSettle()
    return self:getModel():getConvert()
end

function Manager:canGetRewards()
    local model = self:getModel()
    return model:hasBattlePassReward() or model:hasMapReward()
end

function Manager:hasHandBookReward()
    return self:getModel():hasHandBookReward()
end

function Manager:onActCheckIconTip(evt)
    if not self:isEnabled() then return end
    local data = evt:getData()
    local stage = data.stage
    if stage == "STAGE_TWO" then return end

    local reason, creatorDelegate = self:canPopTip()
    if not reason then return end
    self:popTip(reason, creatorDelegate)
end

function Manager:canPopTip()
    local reason, text
    if not self:hasGuideIndex(1) and self:getPopTipTime(1) < self:getCanPopTipTime(1) then
        reason = 1
    elseif self:hasReward() and self:getPopTipTime(2) < self:getCanPopTipTime(3) then
        reason = 2
    elseif not self:isFinish() then
        local collectionNum = self:getModel():getCollectionNum()
        local canPopLimit = self:getModel():getCanPopTipLimit()
        if collectionNum > canPopLimit and self:getPopTipTime(3) < self:getCanPopTipTime(3) then
            reason = 3
        end
    end

    return reason, {
        tipsType = HomeIconTipsType.ONLY_TEXT,
        text = reason and self:getConst().TipText[reason],
        duration = reason and reason == 3 and 2 or 5
    }
end

function Manager:popTip(reason, creatorDelegate)
    local delegate = {
        iconKey = tostring(self:getConst().actId),
        iconType = IconTipType.MESSAGE,
        typeIndex = reason,
        creatorDelegate = creatorDelegate,
        popFunc = function()
            self:getModel():addPopTipTime(reason, 1)
        end,
        priority = "S"
    }

    IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, delegate)
end

function Manager:getCanPopTipTime(index)
    return self:getModel():getCanPopTipTime(index)
end

function Manager:getPopTipTime(index)
    return self:getModel():getPopTipTime(index)
end

function Manager:passDayRefreshData()
    self:getModel():passDayRefreshData()
end

-- 协议相关
function Manager:addLaunchInfo(...)
    self:callRequestFunc("addLaunchInfo", ...)
end

function Manager:getCanSendList()
    return self:callRequestFunc("getCanSendList")
end

function Manager:setCanSenListSuccess(...)
    self:callRequestFunc("setCanSenListSuccess", ...)
end

function Manager:setCanSenListSending(...)
    self:callRequestFunc("setCanSenListSending", ...)
end

function Manager:clearLaunchAndMergeList()
    self:callRequestFunc("clearLaunchAndMergeList")
end

-- 震动
function Manager:playHaptics(type)
    self:callHapticsFunc("playHaptics", type)
end
--------------------- 调用接口 ---------------------

function Manager:isGachaBanned()
    return self:getModel():getDataByKey("ban")
end

function Manager:getMainEndTime()
    return self:getModel():getMainEndTime()
end

function Manager:getEndTime()
    return self:getModel():getEndTime()
end

--是否是主活动期
function Manager:isInMainTime()
    return self:getModel():isInMainTime()
end

--是否是领奖期
function Manager:isInRewardTime()
    return self:getModel():isInRewardTime()
end

-- 获取皮肤对应的id
function Manager:getSkinId()
    local skin = self:getModel():getSkin()
    local index = self:getConst():getSkinId(skin)
    return index
end

-- 检测引导标记
function Manager:hasGuideIndex(index)
    if not index then return false end

    return self:getModel():hasGuide(self:getFlagIndexByGuideIndex(index))
end

function Manager:getFlagIndexByGuideIndex(index)
    local onceGuideIndexTable = self:getConst().OnceGuideIndexTable
    for _, v in ipairs(onceGuideIndexTable) do
        if v == index then
            return index
        end
    end

    local periodId = self:getModel():getPeriodId()
    index = periodId * 100 + index
    return index
end

-- 设置引导标记
function Manager:addGuideIndex(index)
    if not index then return false end
    index = self:getFlagIndexByGuideIndex(index)
    self:getModel():setGuide(index)

    local ActCommonHttp = require 'amf.middleware.activity.http.ActCommonHttp'
    ActCommonHttp:setActGuideFlag(self:getConst().actId, index)
end

function Manager:addRewardsWhenBought(goodsId, rewardItems, params)
    self:callPlug("Rewards","addRewardsWhenBought", goodsId, rewardItems, {
        dcExtra = params
    })
end

function Manager:addRewardsNormal(rewardItems, params, extraMap)
    self:callPlug("Rewards", "addRewardsNormal", rewardItems, {
        dcExtra = params,
        extraMap = extraMap,
    })
end

function Manager:getActName()
    return self:getModel():getThemeName()
end

-- 是否已完成所有地图
function Manager:isFinish()
    return self:getModel():isFinish()
end

function Manager:dcJoin()
    self:getDC():dcJoin(self)
end


function Manager:flyCollection(reward, startWorldPos, bubbleScale, innerFlyEndCall)
    if not innerFlyEndCall and type(bubbleScale) == "function" then
        innerFlyEndCall = bubbleScale
        bubbleScale = nil
    end

    if type(innerFlyEndCall) == "number" then
        innerFlyEndCall = nil
    end

    local scene = Director:sharedDirector():getRunningScene()
    if scene and scene:is(UBFGamePlayScene) then
        safeRunCall(innerFlyEndCall)
        return
    end

    local actIcon = self:callActFunc("getActIcon")
    if not isSafeCocosObj(actIcon) then
        safeRunCall(innerFlyEndCall)
        return
    end

    local function createFakeIcon()
        return ActivityFakeIconFactory:create(actIcon)
    end

    local collectEndWorldPos = actIcon:getPositionInWorldSpace()

    local function iconCreator()
        local icon = GameItemCreator:getPropIcon(reward)
        return icon
    end
    local RewardFlyHelper = require "amf.feature.localactivity.processgiftautopopup.RewardFlyHelper"
    RewardFlyHelper:rewardFlyFunc(true, reward, startWorldPos, collectEndWorldPos, iconCreator,
        innerFlyEndCall, CCSizeMake(126, 126), createFakeIcon, 0.7, nil, nil, nil, {finishCallbackStartDelay = 0.4})
end

---------------------  场景强弹 ---------------------
function Manager:checkCanPop()
    if not self:isEnabled() then return end
    if self:getModel():getGotFinalReward() then return end
    printx(44, "checkCanPop1")
    local todayPopMain = self:getModel():getFlagFromLocalByKey("dailyOpenMain", true)
    if not todayPopMain then return true, 1 end
    printx(44, "checkCanPop2")
    local canPopGift = self:checkCanPopGift()
    if canPopGift then return true, 2 end
    printx(44, "checkCanPop3")
    local canPopYinliu = self:canPopYinliu()
    if canPopYinliu then return true, 3 end
    printx(44, "checkCanPop4")
end

function Manager:canPopYinliu()
    if not self:isEnabled() then return end

    local bGuide = self:hasGuideIndex(2)
    if not bGuide then return end

    local model = self:getModel()
    if self:isFinish() then return end

    local const = self:getConst()
    local popTime = model:getFlagFromLocalByKeyInt("yinLiuPopCnt", true)
    -- printx(36, )
    if popTime >= const.DRAINAGE_POP_MAX then return end

    local energy = self:getModel():getCollectionNum()
    if energy < const.DRAINAGE_ENERGY then return end

    return true
end

function Manager:popFunction(onHandlerOver)
    if not self:isEnabled() then safeRunCall(onHandlerOver) return end

    local canPop, reason = self:checkCanPop()
    if not canPop then safeRunCall(onHandlerOver) return end

    if reason == 1 then
        self:callActFunc("openActivity", {
            failCallback = onHandlerOver,
            endCallback = onHandlerOver,
            extra = {
                from = "popoup"
            },
        })
    elseif reason == 2 then
        self:popGiftPanel(onHandlerOver)
    else
        self:popYinliuPanel(onHandlerOver)
    end
end

function Manager:popYinliuPanel(done)
    printx(44, "popYinliuPanel")
    if not self:isEnabled() then safeRunCall(done) return end
    local model = self:getModel()
    local key = "yinLiuPopCnt"
    local popTime = model:getFlagFromLocalByKeyInt(key, true)
    model:saveFlagToLocalByKeyInt(key, true, popTime + 1)
    local stage = model:getMapStage()
    local rewards = self:getStepRewards(stage)
    rewards[#rewards + 1] = {
        itemId = stage,
    }
    local YinliuPanelVM = require'amf.feature.localactivity.mergeevolution.view.YinliuPanelVM'
    local vm = YinliuPanelVM:create({
        rewards = rewards,
        stage = stage,
        energy = model:getCollectionNum(),
        title = self:getActName(),
    })
    vm:setCloseCallback(done)
    self:callPanelFunc("managePanelVM", vm)
    self:getDC():dcAttractPanelShow()
    printx(44, "popYinliuPanel popout")
    vm:popout()
end

function Manager:getStepRewards(step)
    local rewards = self:getModel():getStepRewards(step)
    local plug = self:_getPlug("ActSend")
    rewards = plug:replaceProgressReward(rewards, step)
    local extraRewards = plug:getProgressExtraReward(step)
    rewards = plug:mergeShowRewards(rewards, extraRewards)
    table.insert(rewards, {itemId = step, num = 1, bSpecial = true})
    return rewards
end

---------------------------------- 关卡内 begin--------------------------------
--关卡内触发条件
function Manager:isEnabledInLevel(data)
    if not self:isEnabled() then return false end
    return true
end

--获取分数BUFF加成值跟buff结束时间
function Manager:getCurAvailableBuffAndEndTime()
    local buffExtraRate, buffEndTime = 0, 0 
    if self:getModel():getScoreBuff(1) > TimeKit:timeInSec() then
        buffExtraRate = 0.2
        buffEndTime = self:getModel():getScoreBuff(1)*1000
    end

    if self:getModel():getScoreBuff(2) > TimeKit:timeInSec() then
        buffExtraRate = buffExtraRate + 0.5
        buffEndTime = buffEndTime > 0 and math.min(self:getModel():getScoreBuff(1)*1000, self:getModel():getScoreBuff(2)*1000) or self:getModel():getScoreBuff(2)*1000
    end
    return buffExtraRate, buffEndTime
end

--关卡内活动启动数据
function Manager:getInLevelActData(levelId)
    local inLevelActData = {}

    return inLevelActData
end

--打关结束时更新数据
function Manager:updatePassLevelData(data, collectionCount)
   --结算失败时不给收集物
    if data.settleMentState and collectionCount and collectionCount > 0 then
        self:getModel():addCollectionNum(collectionCount)
    end
end

function Manager:getEnterLevelCollectBaseCount(levelId, levelScene, payTag)
    local baseDropCount = 0
    local collectionConfig = UBFActHelper:getSpecificCollectionIdConfig(3077, "182")
    local collectionBaseCountConfig = collectionConfig['baseDropRule'] and collectionConfig['baseDropRule']['collectionBaseCountConfig']
    if collectionBaseCountConfig then
        local function getCollectBaseCount(config, countConfig, currTravelIndex)
            if not countConfig then return 0 end
            local baseCount = 0
            local configData = string.split(countConfig, ",")
            -- 按照固定值取
            if #configData == 1 then
                baseCount = tonumber(configData[1])
             -- 按照付费标签取       
            elseif #configData == 7 then
                payTag = payTag or 1
                baseCount = tonumber(configData[payTag])
            else
                UBFThrow("收集物基础数量配置格式有误：" .. tts(countConfig))
            end
            return tonumber(baseCount)
        end
        local maxLevelId = _G.amfBean("LevelUnLockManager"):getUserMaxLevelId()
        local levelId = UBFActHelper:getHiddenLevelStartNormalLevel(levelId, levelScene)
        local levelSupportType = UBFActHelper:getPlayLevelModeType(levelId, nil, levelScene)
        for i, config in ipairs(collectionBaseCountConfig or {}) do
            local startLevel = UBFActHelper:getDropConfigLevelId(config.startLevel, maxLevelId)
            local endLevel = UBFActHelper:getDropConfigLevelId(config.endLevel, maxLevelId)
            if levelId >= startLevel and levelId <= endLevel then
                if LevelSceneFunc:isFullLevelLib(levelScene) then
                    baseDropCount = getCollectBaseCount(config, config.fsllLevelDrop)
                elseif levelSupportType == LevelSupportModeType.kNormal then
                   baseDropCount = getCollectBaseCount(config, config.topDrop)
                elseif levelSupportType == LevelSupportModeType.kExceedStar then
                    baseDropCount = getCollectBaseCount(config, config.refreshStarDrop)
                elseif levelSupportType == LevelSupportModeType.kExceedScore then
                    baseDropCount = getCollectBaseCount(config, config.refreshScoreDrop)
                end
            end
        end
    end

    return baseDropCount
end
---------------------------------- 关卡内 end----------------------------------

---------------------------------- 礼包 ---------------------
function Manager:requestPackagepull(params,successCallback, failCallback)
    self:getModel():requestPackagepull(params)
    :next(successCallback,
    failCallback)
end

function Manager:checkCanPopGift()
    local giftId = self:getModel():getPackageIdByType("FLOW")
    -- UError(41,"checkCanPopGift1",giftId,self:getModel():getTodayCostEnergy(),self:getModel():getNotShowToday(),GoodsManager:getGoods(giftId))
    if giftId and self:getModel():getTodayCostEnergy()>30 and not self:getModel():getNotShowToday() and GoodsManager:getGoods(giftId) then---有流程礼包信息
        local nowDayPopGiftStr = self:getModel():getFlagFromLocalByKeyStr("dayPopGift",true) or table.serialize({})
        -- UError(41,"checkCanPopGift2",tts({nowDayPopGiftStr}))
        local nowDayPopGift = table.deserialize(nowDayPopGiftStr) or {}
        if nowDayPopGift[tostring(giftId)] then
            return false
        end
        return true
    else
        return false
    end
end

function Manager:popGiftPanel(done)
    if not self:isEnabled() then safeRunCall(done) return end

    local GiftPanelVM = require'amf.feature.localactivity.mergeevolution.view.ProcessGiftPanelVM'
    local id = self:getModel():getPackageIdByType("FLOW")
    local nowDayPopGiftStr = self:getModel():getFlagFromLocalByKeyStr("dayPopGift",true) or table.serialize({})
    local nowDayPopGift = table.deserialize(nowDayPopGiftStr) or {}
    nowDayPopGift[tostring(id)] = true
    -- printx(41,"popGiftPanel",tts(nowDayPopGift))
    self:getModel():saveFlagToLocalByKeyStr("dayPopGift",true,table.serialize(nowDayPopGift))
    local meta = self:getModel():getExtraOfGoodsById(id)
    -- printx(41,"popGiftPanel",tts(meta))
    local isCheckBox = false
    if not GoodsManager:getGoods(id) then safeRunCall(done) return end
    local panel = GiftPanelVM:create({
        goodsId = id,
        multipleGift = meta.multiple,
        mgr = self,
        multipleCheckBox = function(isCheck)
            isCheckBox = isCheck
        end
    })
    self:requestActivityAction({
        action = "markShow",
        param = id,
        actId = self:getConst().actId,
    })
    panel:setCloseCallback(function()
        -- printx(41,"popGiftPanel",meta.multiple,isCheckBox)
        if meta.multiple and isCheckBox then
            self:getModel():setNotShowToday(true)
            self:requestActivityAction({
                action = "markFlowNotShowToday",
                actId = self:getConst().actId,
            })
        end
        self:requestPackagepull({
            scene = "activity_scene",
            queryParams = {
                little_merge = table.serialize({
                    moduleVersion = self:getConst().PACKAGE_MODULE_VERSION,
                    wants = { "BATTLE_PASS", "CASH_ENERGY", "RMB_ENERGY", "FLOW" },
                    jump = true
                }),
            }
        },function(evt)
            local data = evt:getData()
            -- printx(41,"jioadijadijowad",tts(data))
            self:getModel():setDisplayablePackages(data)
            self:refreshPackageMetas()
        end,function()
            self:getModel():setDisplayablePackagesById(id,nil)
        end)
        safeRunCall(done)
    end)
    panel:popout()
    self:callPanelFunc("managePanelVM", panel)
end

function Manager:requestActivityAction(params,successCallback, failCallback)
    self:getModel():requestActivityAction(params)
    :next(successCallback, failCallback)
end

--获得礼包信息
function Manager:getGiftPackages()
    return self:getModel():getGiftPackages()
end

--现实可见礼包
function Manager:getDisplayablePackages()
    return self:getModel():getDisplayablePackages()
end

function Manager:getPackageMetas()
    return self:getModel():getPackageMetas()
end

function Manager:getModuleExtraMap()
    return self:getModel():getModuleExtraMap()
end

function Manager:requestBuyGiftPackage(goodsId,buyType,buyCount,successCallback,failCallback,cancealCallback)
    local buyContext = BuyContext.new(goodsId, buyType)
    :setFeatureAndSource(self:getConst().dcFeature, "power_gift")
    :setUnifiedBuy(true,GiftPackageConst.StageType.ACTIVITY,"little_merge")
    :setCallback(successCallback,failCallback, failCallback)
    -- :setBuyCount(buyCount)
    _G.amfTransaction(TransactionEvent.PAY, buyContext)
end

function Manager:requestBuyFlowGiftPackage(goodsId,buyType,buyCount,successCallback,failCallback,cancelCallback)
    local buyContext = BuyContext.new(goodsId, buyType)
    :setFeatureAndSource(self:getConst().dcFeature, "flow_gift")
    :setUnifiedBuy(true,GiftPackageConst.StageType.ACTIVITY,"little_merge")
    :setCallback(successCallback,failCallback, cancelCallback)
    -- :setBuyCount(buyCount)
    _G.amfTransaction(TransactionEvent.PAY, buyContext)
end

---------------------------------- CUSTOM_GAIN ----------------------------------

function Manager:_onCustomGain(event)
    local reward = event:getData()
    local Const = self:getConst()
    local id = reward.itemId
    if id == Const.ActProps.COLLECTION
        or id == Const.ActProps.SCORE_BUFF_20
        or id == Const.ActProps.SCORE_BUFF_50 then
        self:addActItem(reward)
    end
end

return Manager
