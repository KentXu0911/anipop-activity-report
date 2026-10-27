local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"
local ProgressBar = require "amf.middleware.ui.kit.component.ProgressBar"
local Manager = class("BigGiveAwayManager",BaseFeatureManager)

function Manager:setAutoPopupMgr(autoPopupMgr)
    self.autoPopupMgr = autoPopupMgr
end

function Manager:isAutoPopupSupported()
    return self:isActivitySupported(self:getConst().actId) and self:isEnabled()
end

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
        key = "ActExchange",
        path = {
            plugPath ="amf.feature.localactivity.biggiveaway.plug.ActExchangerPlug",
            const = self:_getConstPath()
        }
    }}
end

function Manager:_getAutoPopConfigList()
    return {
        {
            checkPoint = PopupCheckPoint.BIG_GIVEAWAY_STAGE4_POP,
            actId = self:getConst().actId,
            stages = {AutoPopupConst.PopStage.STAGE_FOUR},
            check = function()
                return self:isAutoPopupSupported()
            end,
            pop = function(_, onPopOver)
                return function()
                    self:callActFunc("openActivity", {
                        failCallback = onPopOver,
                        endCallback = onPopOver,
                        userClick = false,
                    })
                end
            end,
        },
    }
end

function Manager:_getConstPath()
    return "amf.feature.localactivity.biggiveaway.const.BigGiveAwayConst"
end

function Manager:_getModelPath()
    return "amf.feature.localactivity.biggiveaway.model.BigGiveAwayModel"
end

function Manager:_getDCPath()
    return "amf.feature.localactivity.biggiveaway.dc.BigGiveAwayDC"
end

function Manager:_getActPropsPath()
    return "amf.feature.localactivity.biggiveaway.props.PropRegister"
end

function Manager:_init()
    self._dc = require(self:_getDCPath())
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)
    self:registerEvents()
    self:registerActProps()
end

function Manager:getDC() return self._dc end

function Manager:dcJoin()
    if not self:getFlagFromLocalByKey("dcJoin", true) then
        self:saveFlagToLocalByKey("dcJoin", true, true)
        self:getDC():dcJoin(self:getConst().actId, self:getCoordinateActId())
    end
end

function Manager:dcQualify()
    if not self:getFlagFromLocalByKey("dcQualify", true) then
        self:saveFlagToLocalByKey("dcQualify", true, true)
        self:getDC():dcQualify(self:getConst().actId, self:getCoordinateActId())
    end
end

function Manager:dcMainShow(panelId, source, hasGet, nowGet)
    self:getDC():dcMainShow(self:getConst().actId, self:getCoordinateActId(), panelId, source, hasGet, nowGet)
end

function Manager:dcGetReward(num)
    self:getDC():dcGetReward(num, self:getCoordinateActId())
end

function Manager:dcGetBigReward()
    self:getDC():dcGetBigReward()
end

function Manager:dcGetRewardPx()
    self:getDC():dcGetRewardPx(self:getCoordinateActId())
end

function Manager:dcRewardTimeReward()
    self:getDC():dcRewardTimeReward(self:getCoordinateActId())
end

function Manager:getCoordinateActId()
    local linkIds = self:callPlug("ActExchange", "getLinkIds") or {}
    return linkIds[1]
end

function Manager:registerEvents()
    IconTipEventCenter:register(IconTipEvent.CHECK_ICON_TIP, self.onActCheckIconTip, self)
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
end

function Manager:registerActProps()
    require(self:_getActPropsPath())
end

function Manager:isPassLevelSupport()
    local levelId = _G.amfBean("LevelAreaManager"):getTopPassedLevel()
    return (not self:getConst().passLevelId) or (levelId>=self:getConst().passLevelId)
end

function Manager:isEnabled() 
    return self:isPassLevelSupport() and self:getModel():isDataEnabled() and (self:isInMainTime() or self:isInRewardTime())
end

function Manager:isEnabled2()
    return self:isPassLevelSupport() and self:getModel():isDataEnabled() and self:isInMainTime()
end

function Manager:saveFlagToLocalByKey(key, needTime, value, needActStartTimeCheck)
    if needActStartTimeCheck == nil then needActStartTimeCheck = true end
    self:getModel():saveFlagToLocalByKey(key, needTime, value, needActStartTimeCheck)
end

function Manager:getFlagFromLocalByKey(key, needTime, needActStartTimeCheck)
    if needActStartTimeCheck == nil then needActStartTimeCheck = true end
    return self:getModel():getFlagFromLocalByKey(key, needTime, needActStartTimeCheck)
end

function Manager:getBeginTime() return self:getModel():getBeginTime() end

function Manager:getEndTime() return self:getModel():getEndTime() end

function Manager:getMainBeginTime() return self:getModel():getMainBeginTime() end

function Manager:getMainEndTime() return self:getModel():getMainEndTime() end

function Manager:isInMainTime() return self:getModel():isInMainTime() end

function Manager:isInRewardTime() return self:getModel():isInRewardTime() end

function Manager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(self:getConst().actId)]
    if not actInfo and fromServer then
        if self:isEnabled() then
            self:reset()
        end
    end
end

function Manager:reset()
    -- printx(41,"dauhdaijowdj",debug.traceback())
    self:getModel():reset()
end

function Manager:updateData(data)
    self:getModel():updateData(data)
end

function Manager:hasReward()
    return self:hasRewards()
end

function Manager:hasRewards()
    -- printx(41,"hasRewards1")
    if not self:isEnabled() then return end
    -- printx(41,"hasReward",self:remainTask(),self:getModel():alreadyGotFinalReward())
    if self:remainTask() then--剩余任务
        return self:getModel():getNeedCoin(self:getModel():nextBoxId()) <= self:getModel():getLeftCoin()
    else
        return not self:getModel():alreadyGotFinalReward()
    end
end

function Manager:remainTask()
    return self:getModel():nextBoxId() <= self:getModel():getBoxSum()
end

function Manager:setHasGetRewardInAwardTime()
    self:getModel():setAlreadyGotFinalReward()
    self:getModel():setNextBoxId(self:getModel():getBoxSum()+1)
end

function Manager:addRewardsNormal(rewardItems, params)
    params = params or {}
    params.dcFeature = self:getDC().DCFeature
    self:callPlug("Rewards", "addRewardsNormal", rewardItems, {
        dcExtra = params,
    })
end

function Manager:addRewards(rewardItems, params)
    local collectCardMgr = _G.amfBean and _G.amfBean("CollectCardManager")
    if collectCardMgr then
        local normalRewards = {}
        local linkRewards = {}
        for _, v in ipairs(rewardItems) do
            if collectCardMgr:isCardPack(v.itemId) then
                table.insert(normalRewards, v)
            else
                table.insert(linkRewards, v)
            end
        end
        if #normalRewards > 0 then
            self:addRewardsNormal(normalRewards, params)
        end
        if #linkRewards > 0 then
            self:callPlug("ActExchange", "addLinkRewards", linkRewards, params)
        end
    else
        self:callPlug("ActExchange", "addLinkRewards", rewardItems, params)
    end
end

---------------------------------- 关卡内 begin--------------------------------
--关卡内触发条件
function Manager:isEnabledInLevel(data)
    -- printx(41,"关卡内触发条件",tts(data))
    -- local levelScene = data.levelScene
    -- local levelId = data.levelId
    -- local star = data.oldStar
    if not self:isEnabled2() then return false end
    -- local startLevelState =  _G.amfBean("UserStateManager"):getUserSegmentState()
    -- if startLevelState == _G.UserStateConst.UserSegmentState.FMJ then--非满级
    --     local passLevel = _G.amfBean("LevelAreaManager"):getTopPassedLevel()
    --     if levelScene == "MAIN" and levelId > passLevel then
    --         return true
    --     end
    -- elseif startLevelState == _G.UserStateConst.UserSegmentState.MHZC or startLevelState == _G.UserStateConst.UserSegmentState.FMZ then--满级满菜
    --     if levelScene == "RANDOM_CHALLENGE_2023" then
    --         return true
    --     end
    -- else--满级非满菜
    --     if star < 4 then
    --         return true
    --     end
    -- end
    return self:remainTask()
end

--获取分数BUFF加成值跟buff结束时间
function Manager:getCurAvailableBuffAndEndTime(data)
    local buffRate = 0
    local buffEndTime = 0 -- 毫秒哦
   
    return buffRate, buffEndTime
end

--关卡内活动启动数据
function Manager:getInLevelActData(levelId, runtime)
    local inLevelActData = {}
    if LevelSceneFunc:isFullLevelLib(runtime.levelScene) then
        inLevelActData.isFirstPlay = UBFActHelper:checkIsFsllFirstPlay(levelId, runtime.levelScene)
    end
    return inLevelActData
end

--打关结束时更新数据
function Manager:updatePassLevelData(data, collectionCount)
   --结算失败时不给收集物
    if data.settleMentState and collectionCount and collectionCount > 0 then
        if self:isEnabled2() then
            self:getModel():addLeftCoin(collectionCount)
            self:callPlug("Act", "updateTipView")
        end
    end
end

function Manager:getEnterLevelCollectBaseCount(levelId, levelScene, payTag)
    local baseDropCount = 0
    local collectionConfig = UBFActHelper:getSpecificCollectionIdConfig(3078, "183")
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
        local levelSupportType = self:getPlayLevelModeType(levelId, nil, levelScene)
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

function Manager:getPlayLevelModeType(levelId, actLevelType, levelScene)
    if _G.editorMode then return LevelSupportModeType.kNormal end
    if LevelSceneFunc:isFullLevelLib(levelScene) then
        return LevelSupportModeType.kNormal
    end
    local levelType = UBFLevelConfigManager:userConfig():getLevelType(levelId, levelScene)
    if actLevelType and levelType == actLevelType then
        return LevelSupportModeType.kNormal
    end
    if UBFLevelSceneFunc:isActLevelScene(levelScene) then
        return LevelSupportModeType.kNormal
    end
    local isFMJState, isTopLevel
    if EnvUtil:isAMFEnabled() then
        local userState = _G.amfBean("UserStateManager"):getUserLevelState()
        isFMJState = userState == _G.UserStateConst.UserLevelState.NORMAL
        local levelAreaMgr = _G.amfBean("LevelAreaManager")
        local topLevelId = _G.getTopLevelId(true)
        if levelAreaMgr:isAreaBlocked(topLevelId) then
            isTopLevel = levelId >= _G.getTopLevelId() and not _G.amfBean("LevelAreaManager"):hasPassedLevelEx(levelId, levelScene)
        else
            isTopLevel = levelId == _G.getTopLevelId() and not _G.amfBean("LevelAreaManager"):hasPassedLevelEx(levelId, levelScene)
        end
    else
        isFMJState = ActUserStateManager:getInstance():isFMJ()
        isTopLevel = levelId == UserManager:getInstance().user:getTopLevelId() and not UserManager:getInstance():hasPassedLevelEx(levelId, levelScene)
    end
    if not UBFLevelSceneFunc:isMainLevel(levelScene) then isTopLevel = false end
    if isFMJState then
        if isTopLevel then
            return LevelSupportModeType.kNormal
        else
            if not UBFActHelper:isFullStar(levelId, levelScene) then
                return LevelSupportModeType.kExceedStar
            end
        end
    else
        if UBFActHelper:isFullStar(levelId, levelScene) then
            --由活动开启行为树去判断刷分是否需要打推荐关还是任意关，此处不在判断了
            return LevelSupportModeType.kExceedScore
        else
            return LevelSupportModeType.kExceedStar
        end
    end
end
---------------------- 关卡内 end----------------------------------

function Manager:onActCheckIconTip(event)
    local data = event:getData()
    -- printx(41,"onActCheckIconTip",tts(data))
    local stage = data.stage
    local reason, params = self:checkTipShow(stage)
    if not reason then return end
    self:popIconTip(reason, params)
end

function Manager:checkTipShow(stage)
    -- printx(41,"dd1",stage)
    if stage ~= "STAGE_TWO" then return false end
    -- printx(41,"dd2")
    if not self:isEnabled2() then return false end
    -- printx(41,"dd3")
    local hasReward = self:hasRewards()----是否有奖励
    local befTaskId = self:getBefTask()
    printx(41,"dd1",hasReward,befTaskId,self:remainTask())
    if self:remainTask() and hasReward and self:getModel():getNeedCoin(befTaskId) then
        return true
    end
    return false
end

function Manager:getMaxClaimableTaskId()
    if not self:remainTask() then return nil end
    local nextId = self:getModel():nextBoxId()
    local leftCoin = self:getModel():getLeftCoin()
    local maxId = nil
    for id = nextId, self:getModel():getBoxSum() do
        local needCoin = self:getModel():getNeedCoin(id)
        if needCoin and needCoin <= leftCoin then
            maxId = id
        else
            break
        end
    end
    return maxId
end

function Manager:getBefLeftCoin()
    return self:getFlagFromLocalByKey("befLeftCoin",false) or 0
end

function Manager:getBefTask()
    return self:getFlagFromLocalByKey("befNextTask",false) or self:getModel():nextBoxId()
end

function Manager:popIconTip(reason, params)
    local icon = self:callPlug("Act", "getActIcon")
    if isSafeCocosObj(icon) and type(icon.refreshProvider) == "function" then
        return
    end

    local delegate = {}
    local data = {}
    local befTaskId = self:getBefTask()
    local maxClaimableId = self:getMaxClaimableTaskId() or befTaskId
    delegate.iconKey = tostring(self:getConst().actId)
    delegate.iconType = IconTipType.MESSAGE
    delegate.priority = "S"
    data.tipsType = HomeIconTipsType.PROGRESS
    data.value = (maxClaimableId == befTaskId) and (self:getBefLeftCoin() or 0) or 0
    data.min = 0
    data.max = self:getModel():getNeedCoin(maxClaimableId) or 0
    data.targetValue = self:getModel():getNeedCoin(maxClaimableId) or 0
    data.textMode = ProgressBar.TextMode.kFrection
    data.iconCreate = function()
        local rewards = self:getBoxRewards(maxClaimableId)
        local item = rewards and rewards[1]
        if not item then return Node:create() end
        local node = Node:create()
        local icon = GameItemCreator:getPropIcon({itemId = item.itemId, num = 1})
        icon:setScale(0.5)
        node:addChild(icon)
        return node
    end
    delegate.creatorDelegate = data
    delegate.ignoreNewLevel = true
    -- printx(41,"popIconTip",tts(delegate))
    IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, delegate)
end

function Manager:canExchangeRewards()
    if self:_getPlug("ActExchange") then
        return self:_getPlug("ActExchange"):canSendRewards()
    end
    return false
end

function Manager:getBoxRewards(i)
    if self:_getPlug("ActExchange") then
        local origin = self:getModel():getBoxOriginRewards(i)
        local replaced = self:getModel():getBoxExchangeRewards(i)
        return self:_getPlug("ActExchange"):getReward(origin,replaced)
    end
    return {
        {
            itemId = 2,
            num = 1,
        }
    }
end

function Manager:getFinalRewards()
    if self:_getPlug("ActExchange") then
        local origin = self:getModel():getFinalOriginRewardsInfo()
        local replaced = self:getModel():getFinalExchangedRewardsInfo()
        return self:_getPlug("ActExchange"):getReward(origin,replaced)
    end
    return {
        {
            itemId = 2,
            num = 1,
        }
    }
end

---------------------------------- CUSTOM_GAIN ----------------------------------

function Manager:_onCustomGain(event)
    local reward = event:getData()
    local Const = self:getConst()
    if reward.itemId == Const.Coin then
        self:addRewardsNormal(reward)
    end
end

return Manager
