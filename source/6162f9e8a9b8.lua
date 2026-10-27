local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"

local ActivityName = "FishingWinner"
local Manager = class(ActivityName.."Mgr",BaseFeatureManager)

local function shouldReduceAutoPopup(manager)
    return not manager:hasEnteredCurrentPeriod()
        and _G.amfBean("ActivityParticipationMgr"):shouldReduceAutoPopup(manager.ACT_ID)
end

local function isAutoPopupLevelEffective()
    return _G.getTopLevelId() >= 211
end

----------- 可能需要修改start -----------
Manager.ACT_OPEN_VERSION = 1
Manager.ACT_ID = 6077
Manager.GAME_NAME = "gk_number_one"
Manager.ACT_SOURCE = "fishingwinner/Config.lua"
Manager.ACT_CH_NAME = "钓鱼大赢家"
Manager.customColorType = "fishingwinner"

function Manager:setAutoPopupMgr(autoPopupMgr)
    self.autoPopupMgr = autoPopupMgr
end

function Manager:_init()
    self.bRegisterItem = false
    self:registerActProps()
    self:registerEvents()
    self:initCustomColorCfg()
    self:initPlugs()
end

function Manager:initPlugs()
    self:_initPlug("ActSend",{
        plugPath = "amf.feature.localactivity.fishingwinner.plug.FishingWinnerActSendPlug"
    })
end

function Manager:_getExtraPlugsConfigList()
    return {
        {key = "AutoPop"},
    }
end

function Manager:_getAutoPopConfigList()
    return {
        {
            checkPoint = PopupCheckPoint.FISHING_WINNER_STAGE4_POP,
            actId = Manager.ACT_ID,
            stages = {AutoPopupConst.PopStage.STAGE_FOUR},
            check = function()
                if not self:isActivitySupported(Manager.ACT_ID) then return false end
                return isAutoPopupLevelEffective()
                    and not shouldReduceAutoPopup(self)
                    and self:checkPopFunction4() == true
            end,
            pop = function(_, onPopOver)
                return function()
                    self:popFunction4(onPopOver)
                end
            end,
        },
        {
            checkPoint = PopupCheckPoint.FISHING_WINNER_MAIN_STAGE4,
            actId = Manager.ACT_ID,
            stages = {AutoPopupConst.PopStage.STAGE_FOUR},
            check = function()
                if not self:isActivitySupported(Manager.ACT_ID) then return false end
                return isAutoPopupLevelEffective()
                    and self:isEnabled()
                    and not shouldReduceAutoPopup(self)
            end,
            pop = function(_, onPopOver)
                return function()
                    self:openActivity(onPopOver, nil, false)
                end
            end,
        },
    }
end

function Manager:registerActProps()
    if (self:getModel():isInMainTime() or self:getModel():isInRewardTime()) and not self.bRegisterItem then
        require("amf.feature.localactivity.fishingwinner.prop.AMFProp_fishScore")
        require("amf.feature.localactivity.fishingwinner.prop.AMFProp_fishNormalHook")
        require("amf.feature.localactivity.fishingwinner.prop.AMFProp_fishGoldHook")
        require("amf.feature.localactivity.fishingwinner.prop.AMFProp_fishScoreBuff20")
        require("amf.feature.localactivity.fishingwinner.prop.AMFProp_fishScoreBuff50")
        require("amf.feature.localactivity.fishingwinner.prop.AMFProp_doubleHookBuff")
        self.bRegisterItem = true
    end
end

function Manager:_getConstPath()
    return "amf.feature.localactivity.fishingwinner.config.FishingWinnerConst"
end

function Manager:_getModelPath()
    return "amf.feature.localactivity.fishingwinner.model.FishingWinnerModel"
end

function Manager:initCustomColorCfg()
    local PanelColorConfig = require "amf.middleware.ui.config.PanelColorConfig"
    local defaultCfg = PanelColorConfig:getConfig("green")
    local customColorCfg = self:getConst().CustomColorCfg
    local newColorConfig = {
        bgColor = customColorCfg.bgColor and self:hex2Vec4(customColorCfg.bgColor) or defaultCfg.bgColor,
        bgInnerColor = customColorCfg.bgInnerColor and self:hex2Vec4(customColorCfg.bgInnerColor) or defaultCfg.bgInnerColor,
        bgInnerColor2 = customColorCfg.bgInnerColor2 and self:hex2Vec4(customColorCfg.bgInnerColor2) or defaultCfg.bgInnerColor2,
        bg10Color = customColorCfg.bg10Color and self:hex2Vec4(customColorCfg.bg10Color) or defaultCfg.bg10Color,

        tabNormalColor = customColorCfg.tabNormalColor and self:hex2Vec4(customColorCfg.tabNormalColor) or defaultCfg.tabNormalColor,
        tabNormalLabelColor = customColorCfg.tabNormalLabelColor and hex2ccc4(customColorCfg.tabNormalLabelColor) or defaultCfg.tabNormalLabelColor,

        tabSelectedColor = customColorCfg.tabSelectedColor and self:hex2Vec4(customColorCfg.tabSelectedColor) or defaultCfg.tabSelectedColor,
        tabSelectedLabelColor = customColorCfg.tabSelectedLabelColor and hex2ccc4(customColorCfg.tabSelectedLabelColor) or defaultCfg.tabSelectedLabelColor,

        closeBtnColor = customColorCfg.closeBtnColor and self:hex2Vec4(customColorCfg.closeBtnColor) or defaultCfg.closeBtnColor,

        titleColor = customColorCfg.titleColor and hex2ccc4(customColorCfg.titleColor) or defaultCfg.titleColor,

        lineColor = customColorCfg.lineColor and self:hex2Vec4(customColorCfg.lineColor) or defaultCfg.lineColor,
    }
    PanelColorConfig:addConfig(self.customColorType, newColorConfig)
end

function Manager:hex2Vec4(hex)
    local ccc4 = hex2ccc4(hex)
    return Vec4(ccc4.r/255, ccc4.g/255, ccc4.b/255, ccc4.a/255)
end

function Manager:registerEvents()
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)

    -- 注册活动事件
    self:registerActEvent()
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
end

-- 同步所有数据
function Manager:updateData(data)
    if not data then return end
    self:getModel():syncMainInfo(data)
    self:registerActProps()
end

-- 记得改造一下
function Manager:isEnabled()
    return self:getModel():isDataEnabled() and (self:getModel():isInMainTime() or self:getModel():isInRewardTime())
end

function Manager:isOpen()
    return self:getModel():isDataEnabled() and self:getModel():isInMainTime()
end

function Manager:isEnabledInLevel()
    return self:getModel():isDataEnabled() and self:getModel():isInMainTime() and not self:getModel():getHasCollectionFinalReward()
end

function Manager:getDataByKey(key) return self:getModel():getDataByKey(key) end
function Manager:setDataByKey(key, value) return self:getModel():setDataByKey(key, value, true) end
function Manager:getConfigByKey(key) return self:getModel():getConfigByKey(key) end
----------------------------- 功能函数 -----------------------------
--------------------- 本地缓存相关 ---------------------
function Manager:setFlagToLocalByKey(key, needTime, value)
    if not key then return end
    if value == nil then value = true end
    self:getModel():saveFlagToLocalByKey(key, needTime, value, true)
end

function Manager:getFlagFromLocalByKey(key, needTime)
    return self:getModel():getFlagFromLocalByKey(key, needTime, true)
end

function Manager:hasEnteredCurrentPeriod()
    local mainEndTime = self:getMainEndTime()
    return (tonumber(mainEndTime) or 0) > 0
        and self:getFlagFromLocalByKey("autoPopReduceEnteredEndTime", false) == mainEndTime
end

function Manager:addIntToLocalByKey(key, needTime, addNum)
    if not key then return end
    if addNum == nil then addNum = 1 end
    local beforeNum = self:getModel():getFlagFromLocalByKeyInt(key, needTime, true) or 0
    self:getModel():saveFlagToLocalByKeyInt(key, needTime, beforeNum + addNum, true)
end

function Manager:setIntFromLocalByKey(key, needTime, setNum)
    if not key then return end
    if setNum == nil then setNum = 0 end
    self:getModel():saveFlagToLocalByKeyInt(key, needTime, setNum, true)
end

function Manager:getIntFromLocalByKey(key, needTime)
    return self:getModel():getFlagFromLocalByKeyInt(key, needTime, true) or 0
end

function Manager:setStringToLocalByKey(key, needTime, value)
    if not key then return end
    if value == nil then value = "" end
    self:getModel():saveFlagToLocalByKeyStr(key, needTime, value, true)
end

function Manager:getStringFromLocalByKey(key, needTime)
    return self:getModel():getFlagFromLocalByKeyStr(key, needTime, true) or ""
end
----------------------------- 零散功能 ---------------------------------------
-- 是否是活动正式期最后一天
function Manager:isLastDay(  )
    return self:getModel():isLastDay()
end

-- 获取服务器时间是活动周期内的第几天
function Manager:getDayFromActOpen( time )
    return self:getModel():getDayFromActOpen(time)
end

-- 获取从1970.1.1开始服务器时间是第几天
function Manager:getDayFrom1970( time )
    return self:getModel():getDayFrom1970(time)
end

-- 检测引导标记
function Manager:hasGuideIndex(index)
    local hasIndex = self:getModel():hasGuide(index)
    return hasIndex
end

-- 设置引导标记
function Manager:addGuideIndex(index)
    self:getModel():setGuide(index)
    local ActCommonHttp = require "amf.middleware.activity.http.ActCommonHttp"
    ActCommonHttp:setActGuideFlag(Manager.ACT_ID, index, true)
end

-- 打点
function Manager:dc(category, subCategory, extraData)
    local params = {
        game_type = "stage",
        game_name = Manager.GAME_NAME,
        category = category,
        sub_category = subCategory,
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
    _G.amfBean("IconManager"):getIconByIconKey(tostring(Manager.ACT_ID))
end

--更新icon
function Manager:updateIcon()
    local icon = self:getActivityIcon()
    if icon and (not icon.isDisposed) then
        icon:updateState()
    end
end
----------------------- 响应事件 -----------------------------
function Manager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local actInfo = actInfos[tostring(self.ACT_ID)]
    local fromServer = data.fromServer
    if actInfo and fromServer then
        self:getModel():syncActInfo(actInfo)
    end
end

function Manager:onActPassDay()
    BaseFeatureManager.onActPassDay(self)
    local observerNum = self:getObserverNum()
    if observerNum > 0 then
        self:Command("closeAllPanel")
        CommonTip:showTip('新的一天开始了，数据已更新，\n请尝试重进活动~')
    end
end

function Manager:onPassActMainNext()
    local observerNum = self:getObserverNum()
    if observerNum > 0 then
        self:Command("closeAllPanel")
        CommonTip:showTip('钓鱼大赢家活动已结束！')
    end
end

function Manager:onSystemEnterForeground()
    if self.returnBackCallback and self.returnBackCallbackValid == true then
        safeRunCall(self.returnBackCallback)
        self.returnBackCallback = nil
        self.returnBackCallbackValid = false
    end
end

function Manager:onSystemEnterBackground()

end
----------------------- 加道具 -----------------------------
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

function Manager:addActItem(reward)
    if reward.itemId == self:getConst().scoreBuff20ItemId then
        self:getModel():addScoreBuff20(reward.num)
    elseif reward.itemId == self:getConst().scoreBuff50ItemId then
        self:getModel():addScoreBuff50(reward.num)
    elseif reward.itemId == self:getConst().doubleBuffItemId then
        self:getModel():addDoubleBuff(reward.num)
    elseif reward.itemId == self:getConst().normalHookItemId then
        self:getModel():addNormalHook(reward.num)
    elseif reward.itemId == self:getConst().goldHookItemId then
        self:getModel():addGoldHook(reward.num)
    end
end

----------------------- icon角标逻辑 -----------------------------
function Manager:hasSettleFishReward()
    local perFishResultData = self:getModel():getPerFishResultData()
    if table.isEmpty(perFishResultData) then
        return false
    end
    local hasBoxReawrd = perFishResultData.hasBox and not perFishResultData.boxFinish
    local hasFishReward = not perFishResultData.fishFinish
    local needSettle = hasBoxReawrd or hasFishReward
    return needSettle
end

-- checkAfterFinishAll
-- 活动图鉴集齐以后，二阶段奖励只有在存在额外联动奖励时才提示
function Manager:hasProgressReward(checkAfterFinishAll)
    local curScore = self:getModel():getCurScore()
    local rewardGetId = self:getModel():getRewardGetId()

    local bannerConfig = self:getModel():getBannerConfig()
    for i, v in ipairs(bannerConfig.parse1Config or {}) do
        if curScore >= v.endScore and rewardGetId < v.id then
            return true
        end
    end

    local parse1Len = #(bannerConfig.parse1Config or {})
    local plug = self:_getPlug("ActSend")
    for i, v in ipairs(bannerConfig.parse2Config or {}) do
        if curScore >= v.endScore and rewardGetId < v.id then
            if checkAfterFinishAll then
                -- 图鉴集齐后：只有该节点存在 ActSend 额外奖励时才返回 true
                local boxIndex = parse1Len + i
                local extraRewards = plug:getProgresssExtraReward(boxIndex)
                if extraRewards and #extraRewards > 0 then
                    return true
                end
            else
                return true
            end
        end
    end

    return false
end

function Manager:hasFinalReward()
    return self:getModel():checkGotAllFish() and not self:getModel():getHasCollectionFinalReward()
end

-- 主icon奖字
function Manager:hasReward()
    if not self:isEnabled() then return false end
    local getHasCollectionFinalReward = self:getModel():getHasCollectionFinalReward()
    if self:getModel():isInMainTime() and not getHasCollectionFinalReward then
        return self:hasSettleFishReward() or self:hasProgressReward() or self:hasFinalReward()
    else
        local normalHookNum = self:getModel():getNormalHookNum()
        if normalHookNum > 0 then
            return true
        end
        return self:hasProgressReward(true) or self:hasFinalReward()
    end

    return false
end

-- 主icon数字
function Manager:getMsgNum()
    if not self:isEnabled() then return 0 end
    local normalHookNum = self:getModel():getNormalHookNum()
    return normalHookNum
end

---------------------------------- 业务逻辑,新增函数都写在此后 --------------------------------


function Manager:getMainEndTime()
    return self:getModel():getMainEndTime()
end

function Manager:Command(event)
    if event == "closeAllPanel" then
        self:notify("CloseAllPanel")
    end
end

function Manager:registerActEvent()
    self:addEventDispatcher("onAct")

    local nowTime = TimeKit:timeInSec()
    local config = self:getModel()

    if config:getEndTime() ~= config:getMainEndTime() and nowTime < config:getMainEndTime() then
        self.__passActMainNextListener = function()
            self:onPassActMainNext()
        end
        TimerUtil.addAlarm(self.__passActMainNextListener, config:getMainEndTime() - nowTime, 1)
    end
end

--icon创建
function Manager:createIcon(reward)
    local icon
    if reward.itemId == self:getConst().normalHookItemId then
        if reward.hasBait then
            icon = UICreateUtil:createSpriteFile("amf/activity/fishingwinner/materials/normalHook_bait.png", true)
        else
            icon = GameItemCreator:getPropIcon(reward)
        end
    elseif reward.itemId == self:getConst().goldHookItemId then
        if reward.hasBait then
            icon = UICreateUtil:createSpriteFile("amf/activity/fishingwinner/materials/goldHook_bait.png", true)
        else
            icon = GameItemCreator:getPropIcon(reward)
        end
    else
        icon = GameItemCreator:getPropIcon(reward)
    end

    return icon
end

function Manager:getPropName(itemId, num)
    local name
    if _G.amfBean("PropManager"):isMergableProp(itemId) then
        name = localize('prop.name.' .. itemId,{num = num})
    else
        name = localize('prop.name.' .. itemId)
    end
    return name
end


-- 引流面板
function Manager:checkPopFunction4()
    if not self:isEnabledInLevel() then return false end
    local dailyCount = self:getIntFromLocalByKey("function4DailyCount", true)
    local collectionNum = self:getModel():getNormalHookNum()
    local stage = self:getModel():getCurParse()

    if stage == 3 then
        return false
    end
    if dailyCount >= 3 then
        return false
    end
    if collectionNum < 50 then
        return false
    end

    if(dailyCount < 1)then
        return true
    end

    local lastCollectionNum = self:getIntFromLocalByKey("lastCollectionAddNum", false)
    if(lastCollectionNum >= 20)then
        return true
    end
    return false
end



function Manager:getStageRewards(stage)
    local plug = self:_getPlug("ActSend")
    if stage == 1 then
        local curParse = self:getModel():getCurParse()
        local bannerConfig = self:getModel():getBannerConfig()
        local parseConfig = bannerConfig["parse"..tostring(curParse).."Config"]
        if parseConfig then
            local rewards = parseConfig[#parseConfig].rewardList
            local i 
            if curParse == 1 then
                i = #parseConfig
            else
                i = #bannerConfig["parse1Config"] + #parseConfig
            end
            rewards = plug:replaceProgressReward(rewards, i)
            local extraRewards = plug:getProgresssExtraReward(i)
            rewards = plug:mergeShowRewards(rewards, extraRewards)
            return rewards
        end
    elseif stage == 2 then
        local rewards = self:getModel():getFinalRewardItemList()
        rewards = plug:replaceRewardsList(rewards, 2)
        local extraRewardList = plug:getExtraRewardsByPoint(2)
        rewards = plug:mergeShowRewards(rewards, extraRewardList)
        return rewards
    end
end
function Manager:loadInPackAsset(successCallback, failCallback)
    _G.amfBean("AssetsUtil"):loadMiniLabels({"fishingwinner"}):next(function()
        safeRunCall(successCallback)
    end, function()
        safeRunCall(failCallback)
    end)
end
-- 打开引流面板
function Manager:popFunction4(callback)
    self:loadInPackAsset(function()
        self:onPassFunction4(callback)
    end, function()
        safeRunCall(callback)
    end)
end

function Manager:onPassFunction4(callback)
    local stage = self:getModel():getCurParse()
    local collectionNum = self:getModel():getNormalHookNum()
    local rewards = self:getStageRewards(stage)
    local FishingDrainagePanelVM = require "amf.feature.localactivity.fishingwinner.view.FishingDrainagePanelVM"
    local SecondPanelGVM = require "amf.middleware.ui.kit.panel.second.SecondPanelGVM"

    local vm

    local function onClose()
        self:removeObserver(vm)
        safeRunCall(callback)
    end

    local function onButtonTapped()
        if vm and not vm.isDisposed then
            vm:_close()
        end
        self:openActivity(nil, {fromYinLiu = true}, true)
    end

    local text = {
    desc = {
        "您已获得了",
        "<<node>>",
        "x" .. tostring(collectionNum) .. "，",
        stage == 1
            and "快去领奖吧！"
            or  "图鉴即将集齐，快去钓鱼领奖吧！",
    },

    nodes = {
        UICreateUtil:createSpriteFile(
            "amf/activity/fishingwinner/materials/normalHook.png",
            true
        )
    }
}


    local builder = FishingDrainagePanelVM.Builder.new()
                                     :setTitle("钓鱼大赢家")
                                     :setColorType(Manager.customColorType)
                                     :setCloseCallback(onClose)
                                     :setTopText(text)
                                     :setRewards(rewards)
                                     :setButtonsConfig({{
                                         str = "去参与",
                                         widthMode = UIButtonConfig.Widths.kShort,
                                         colorMode = UIButtonConfig.ColorMode.green,
                                         touchFunc = onButtonTapped
                                     }})

    vm = FishingDrainagePanelVM:create(builder)
    self:addObserver(vm)
    vm:popout()

    self:addIntToLocalByKey("function4DailyCount", true, 1)
    self:setIntFromLocalByKey("lastCollectionAddNum", false, 0)

    -- 添加埋点
    self:dc("fish", "attract_panel_show")
end

function Manager:getNewFishInt()
    local newFishInt = self:getIntFromLocalByKey("newFishInt", false)
    return newFishInt
end

function Manager:setNewFishInt(newFishInt)
    self:setIntFromLocalByKey("newFishInt", false, newFishInt)
end

-- 没有展示过的鱼
function Manager:getShowNewFishList()
    local ret = {}
    local mask = 1
    local newFishInt = self:getNewFishInt()
    for i = 1, 32 do
        if bit.band(mask, newFishInt) == 0 then
            table.insert(ret, i)
        end
        mask = bit.lshift(mask, 1)
    end
    return ret
end

function Manager:setShownNewFish(showList)
    local newFishInt = self:getNewFishInt()
    for i, id in ipairs(showList) do
        local mask = bit.lshift(1, id - 1)
        newFishInt = bit.bor(newFishInt, mask)
    end
    self:setNewFishInt(newFishInt)
end

function Manager:needNewerGuide()
    local Const = self:getConst()
    return not self:hasGuideIndex(Const.Guide.NewUser1)
        or not self:hasGuideIndex(Const.Guide.NewUser2)
        or not self:hasGuideIndex(Const.Guide.NewUser3)
end

function Manager:registerHaptics()
    if self.haptics then return end
    self.haptics = {}
    for k, v in pairs(self:getConst().haptics or {}) do
        local params = require("amf.feature.localactivity.fishingwinner.haptics." .. v)
        self.haptics[v] = params
    end
end

function Manager:playHaptics(type)
    self:registerHaptics()
    if self.haptics and self.haptics[type] then
        HapticsManager:playInActScene(self.haptics[type])
    end
end
-----------------------------------关卡内-------------------------------------------
function Manager:getTimeLimitRateEndTime()
    -- 获取双倍buff结束时间，返回ms
    local buffEndTime = self:getModel():getDoubleBuff()
    return buffEndTime
end

function Manager:getCurAvailableBuffAndEndTime()
    -- 获取分数buff加成和结束时间，返回0-1小数和时间ms
    -- local buffExtraRate, buffEndTime = 0.9, TimeKit:timeInMillis() + 3600000
    local finalBuff = 0
    local finalEndTime = 0
    local addScoreBuff50ET = self:getModel():getScoreBuff50()
    local addScoreBuff20ET = self:getModel():getScoreBuff20()
    if addScoreBuff50ET > TimeKit:timeInMillis() then
        finalBuff = finalBuff + 0.5
        if finalEndTime == 0 then
            finalEndTime = addScoreBuff50ET
        else
            finalEndTime = math.min(finalEndTime, addScoreBuff50ET)
        end
    end
    if addScoreBuff20ET > TimeKit:timeInMillis() then
        finalBuff = finalBuff + 0.2
        if finalEndTime == 0 then
            finalEndTime = addScoreBuff20ET
        else
            finalEndTime = math.min(finalEndTime, addScoreBuff20ET)
        end
    end

    return finalBuff, finalEndTime
end

function Manager:getInLevelActData(levelId, runtime)
    local inLevelActData = {
        buffEndTime = self:getTimeLimitRateEndTime(),
        hasTimeLimiteBuff = self:getTimeLimitRateEndTime() > TimeKit:timeInMillis(),
    }

    return inLevelActData
end

function Manager:updatePassLevelData(data, collectionCount, collectionMap, passLevelData)
    local modEnvData = data.modEnvData
    if modEnvData.isCurActivityDeputyLevel then
        --副本

    else
        --结算失败时不给收集物
        if data.settleMentState then
            local collectionCount = collectionMap[tostring(self:getConst().normalHookCollectionId)] or 0
            self:getModel():addNormalHook(collectionCount)
        end
    end
end
---------------------------------关卡内over-----------------------------------------

---------------------------------- CUSTOM_GAIN ----------------------------------

function Manager:_onCustomGain(event)
    local reward = event:getData()
    local Meta = self:getConst()
    local id = reward.itemId
    if id == Meta.normalHookItemId
        or id == Meta.goldHookItemId
        or id == Meta.scoreBuff20ItemId
        or id == Meta.scoreBuff50ItemId
        or id == Meta.doubleBuffItemId then
        self:addActItem(reward)
    end
end

return Manager
