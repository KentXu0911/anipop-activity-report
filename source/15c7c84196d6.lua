local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local SecondRewardPanelVM = require("amf.middleware.ui.kit.commonpanel.view.SecondRewardPanelVM")
local ICON_V2_EXPERIMENT_MODULE = "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"
local ActivityName = "SprintGiftPackage"
---@class SprintGiftPackageManager : BaseFeatureManager
local Manager = class(ActivityName.."Manager", BaseFeatureManager)

----------- 可能需要修改start -----------

function Manager:log(...)
    printx(42, "***** SprintGiftPackage *****  ", ...)
end

-- 获取常量路径
function Manager:_getConstPath()
    return "amf.feature.localactivity.sprintgiftpackage.config.SprintGiftPackageConst"
end

-- 获取model路径
function Manager:_getModelPath()
    return "amf.feature.localactivity.sprintgiftpackage.model.SprintGiftPackageModel"
end

-- 如果有自己需要初始化的内容，覆写这个
function Manager:_init()
    self.bRegisterItem = false
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)

    self:initGiftModule()
    self:initHapticModule()
end

function Manager:initHapticModule()
    local SprintGiftHapticsModule = require 'amf.feature.localactivity.sprintgiftpackage.module.SprintGiftHapticsModule'
    self.hapticModule = SprintGiftHapticsModule:create(self)
end

function Manager:playHaptic(type)
    if self.hapticModule then
        self.hapticModule:playHaptics(type)
    end
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
    }
end

-- 注册活动道具
function Manager:registerActProps()
    -- 注册一下实物的AMFProp

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
    self:refreshIconV2("dataUpdated")
end

-- 打点
function Manager:dc(category, subCategory, panel_id, t1, t2, t3, t4, extraData)
    local params = {
        game_type = "stage",
        game_name = self:getConst().GAME_NAME,
        category = category,
        sub_category = subCategory,
        panel_id = panel_id,
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

function Manager:onPassDay()
    if not self:isEnabled() then return end
    self:getModel():passDayClear()
end

-- 普通的addRewards,开宝箱之类的
function Manager:addRewardsNormal(rewardItems, params)
    self:callPlug("Rewards","addRewardsNormal",
    rewardItems,
    params)
end

function Manager:addRewardsRMB(rewardItems, params)
    local dcFeature = "play_feedback"
    if params and params.dcExtra and params.dcExtra.dcFeature then
        dcFeature = params.dcExtra.dcFeature
    end
    local dcSource = ""
    if params and params.dcExtra and params.dcExtra.dcSource then
        dcSource = params.dcExtra.dcSource
    end
    _G.GainPropData:create()
        :setFeature(dcFeature)
        :setSource(dcSource)
        :setProps(rewardItems)
        :setExtraMap({
            pay_type = DcPayType.kRmb,
        })
        :execute()
end

function Manager:addActItem(reward)
end

------------------------------- 关卡外 -------------------------------

function Manager:updateTipView()
end

function Manager:getActInfo()
    return _G.amfBean("ActivityMgr"):getActInfo(self:getConst().actId)
end

-- 主icon数字
function Manager:getShowMsgNum()
    return 0
end

function Manager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(self:getConst().actId)]
    
    if actInfo and fromServer then
        local shouldSyncCurrent = self:isEnabled()
            or (self:isV2IconExperimentEnabled() and self:isInRewardTime() and self:isEnabled2())
        if actInfo and actInfo.extra and shouldSyncCurrent then
            local extraTable = table.deserialize(actInfo.extra)
            local serverCurrent = extraTable.current
            if serverCurrent then
                self:getModel():setDataByKey("current", serverCurrent)
            end
        end
        self:registerGiftModule()
        self:refreshIconV2("actInfoUpdated")
    end
end

function Manager:isV2IconExperimentEnabled()
    local ok, enabled = pcall(function()
        local experiment = require(ICON_V2_EXPERIMENT_MODULE)
        return experiment:isEnabled()
    end)
    return ok and enabled == true
end

function Manager:getIconV2Icon()
    if not self.actPlug or type(self.actPlug.getActIcon) ~= "function" then
        return nil
    end
    local icon = self.actPlug:getActIcon()
    if not icon or icon.isDisposed or type(icon.refreshProvider) ~= "function" then
        return nil
    end
    return icon
end

function Manager:refreshIconV2(reason, payload, refreshMode)
    if not self:isV2IconExperimentEnabled() then
        return false, "legacyMode"
    end
    local icon = self:getIconV2Icon()
    if not icon then
        return false, "iconUnavailable"
    end
    local refreshMethod = icon.refreshProvider
    if refreshMode == "deferDisplay" then
        refreshMethod = icon.deferProviderRefresh
    elseif refreshMode == "forceDisplay" then
        refreshMethod = icon.forceRefreshProvider
    end
    if type(refreshMethod) ~= "function" then
        return false, "refreshModeUnavailable"
    end
    local success, refreshed, detail = pcall(
        refreshMethod,
        icon,
        reason or "sprintGiftPackageStateChanged",
        payload
    )
    if not success then
        return false, refreshed
    end
    return refreshed, detail
end

function Manager:onIconV2Mounted()
    self:refreshIconV2("mounted")
end

-- 创建图标icon
function Manager:createIcon( reward )
    return GameItemCreator:getPropIcon(reward)
end

-- 创建带数字的金币物品，level代表金币物品等级，scale只与非字背景有关，字位置自己调
function Manager:createGoldIconWithNum(num, level, scale, fontSize, outlineNum, shadowNum, redBgScale)
    if not num then num = 0 end
    if not level then level = 1 end
    if not scale then scale = 1 end
    if not fontSize then fontSize = 24 end
    if not outlineNum then outlineNum = 2 end
    if not shadowNum then shadowNum = -1 end
    if not redBgScale then redBgScale = 1 end
    local node = Node:create()
    local nodeBg = Node:create()
    node:addChild(nodeBg)
    local goldIcon = UICreateUtil:createSpine("amf/activity/sprintgiftpackage/spine/icon_fx.skel")
    goldIcon:playByName("lv_"..tostring(level), true)
    goldIcon:setScale(1)
    nodeBg:addChild(goldIcon)
    local redBg = Sprite:create("amf/activity/sprintgiftpackage/materials/redBg.png")
    redBg:setScale(1.1*redBgScale)
    nodeBg:addChild(redBg)
    redBg:setPositionY(-60)
    nodeBg:setScale(scale)

    local label = TTFLabel:createAnimalYH(tostring(num), fontSize)
    label:enableOutline(hex2ccc4("994628FF"), outlineNum)
    label:enableShadow(hex2ccc4('994527FF'),ccp(0,shadowNum))
    label:setAnchorPoint(ccp(0.5, 0.5))
    node:addChild(label)

    node.nodeBg = nodeBg
    node.goldIcon = goldIcon
    node.redBg = redBg
    node.numLabel = label
    node.level = level
    node.oldNum = num

    local mgrContext = self
    node.showBuyAnim = function(node, endLevel, startNum, endNum)
        if not isSafeCocosObj(node) then return end
        if not mgrContext then return end
        if not endLevel then endLevel = 1 end
        if not startNum then startNum = node.oldNum or 0 end
        if not endNum then endNum = 0 end

        local upSpine = UICreateUtil:createSpine("amf/activity/sprintgiftpackage/spine/icon_fx.skel")
        upSpine:playOnceAndDispose("lv_up")
        upSpine:setScale(1.3)
        node:addChild(upSpine)

        local iconScaleAction = mgrContext:_getIconScaleAction(node.goldIcon, endLevel, 1)
        node.goldIcon:runAction(iconScaleAction)
        local bgAction1 = mgrContext:_getIconLabelBgAction(1.1)
        node.redBg:runAction(bgAction1)
        local bgAction2 = mgrContext:_getIconLabelBgAction(1.1)
        node.numLabel:runAction(bgAction2)

        local labelAction = mgrContext:_getLabelRunNumAction(startNum, endNum, node.numLabel)
        node.nodeBg:runAction(labelAction)
    end

    node.showHardChange = function(node, level, num)
        if not level then level = 1 end
        if not num then num = 0 end

        node.goldIcon:playByName("lv_"..tostring(level), true)
        node.numLabel:setString(tostring(math.floor(num)))
    end

    return node
end

function Manager:_getIconScaleAction(iconSpine, level, baseScale)
    if not level then level = 1 end
    local callFunc1 = CCCallFunc:create(function()
        -- 重复的回调逻辑
        if not isSafeCocosObj(iconSpine) then return end
        iconSpine:playByName("lv_"..tostring(level), true)
    end)

    local arr = CCArray:create()
    arr:addObject(CCScaleTo:create(3/30, 0.85*baseScale))
    arr:addObject(CCScaleTo:create(3/30, 1.3*baseScale))
    arr:addObject(CCDelayTime:create(14/30))
    arr:addObject(callFunc1)
    arr:addObject(CCDelayTime:create(1/30))
    arr:addObject(CCScaleTo:create(2/30, 1.45*baseScale))
    arr:addObject(CCScaleTo:create(4/30, 1*baseScale))
    return CCSequence:create(arr)
end

function Manager:_getLabelRunNumAction(startNum, endNum, label)
    if not startNum then startNum = 0 end
    if not endNum then endNum = 0 end
    local callTime = 1
    local callFunc1 = CCCallFunc:create(function()
        -- 重复的回调逻辑
        if not isSafeCocosObj(label) then return end
        label:setString(tostring(math.floor(startNum+(endNum-startNum)*callTime/15)))
        callTime = callTime+1
    end)

    local callFunc2 = CCCallFunc:create(function()
        -- 插入的回调逻辑
        if not isSafeCocosObj(label) then return end
        label:setString(tostring(endNum))
    end)

    local repeatUnit = CCSequence:createWithTwoActions(
        CCDelayTime:create(1/30),
        callFunc1
    )

    local arr = CCArray:create()
    arr:addObject(CCDelayTime:create(6/30))
    arr:addObject(CCRepeat:create(repeatUnit, 15))
    arr:addObject(callFunc2)
    return CCSequence:create(arr)
end

function Manager:_getIconLabelBgAction(baseScale)
    local arr = CCArray:create()
    arr:addObject(CCDelayTime:create(14/30))
    arr:addObject(CCScaleTo:create(3/30, 0.85*baseScale))
    arr:addObject(CCScaleTo:create(2/30, 1.4*baseScale))
    arr:addObject(CCScaleTo:create(3/30, 1.5*baseScale))
    arr:addObject(CCScaleTo:create(6/30, 0.95*baseScale))
    arr:addObject(CCScaleTo:create(4/30, 1*baseScale))
    return CCSequence:create(arr)
end

-- 获取上次打开主面板数据进度
function Manager:getHistoryProgressValue()
    return self:getModel():getFlagFromLocalByKeyInt("historyProgress", nil, true, 0)
end

function Manager:setHistoryProgressValue()
    local curValue = self:getProgressValue()
    self:getModel():saveFlagToLocalByKeyInt("historyProgress", nil, curValue)
    self:refreshIconV2("historyProgressUpdated")
end

-- 获取当前数据进度
function Manager:getProgressValue()
    return self:getModel():getDataByKey("current") or 0
end

function Manager:getIconV2Snapshot(now)
    local actInfo = self:getActInfo()
    local actInfoReward = type(actInfo) == "table" and rawget(actInfo, "reward") or nil
    local options = actInfoReward ~= nil and {actInfoReward = actInfoReward} or nil
    return self:getModel():getIconV2Snapshot(now, options)
end

-- 获得任务配置 total为完成目标需要的数量 hasReward是否已领奖
function Manager:getTaskConfig()
    return self:getModel():getDataByKey("tasks") or {}
end

-- 获取任务配置最多闯多少关
function Manager:getTaskMaxTarget()
    local taskConfig = self:getTaskConfig()
    local maxTask = taskConfig[#taskConfig]
    if maxTask then
        return maxTask.total
    end
    return 100
end

function Manager:buildPassLevelProgressAnimationPlan(oldProgress, newProgress, oldTaskId, newTaskId)
    oldProgress = tonumber(oldProgress)
    newProgress = tonumber(newProgress)
    oldTaskId = tonumber(oldTaskId)
    newTaskId = tonumber(newTaskId)
    if not oldProgress or not newProgress or newProgress <= oldProgress
        or not oldTaskId or not newTaskId or newTaskId < oldTaskId
    then
        return nil
    end

    local finalTotal = tonumber(self:getTaskTotalByIndex(newTaskId))
    if not finalTotal or finalTotal <= 0 then return nil end
    local steps = {}
    for taskId = oldTaskId, newTaskId - 1 do
        local completedTotal = tonumber(self:getTaskTotalByIndex(taskId))
        local nextTotal = tonumber(self:getTaskTotalByIndex(taskId + 1))
        if not completedTotal or completedTotal <= 0
            or not nextTotal or nextTotal <= completedTotal
        then
            return nil
        end
        table.insert(steps, {
            type = "animate",
            current = completedTotal,
            total = completedTotal,
        })
        table.insert(steps, {
            type = "reset",
            current = 0,
            total = nextTotal,
        })
    end
    table.insert(steps, {
        type = "animate",
        current = newProgress,
        total = finalTotal,
    })
    return {
        final = {current = newProgress, total = finalTotal},
        steps = steps,
    }
end

function Manager:submitPassLevelProgressAnimationPlan(plan)
    if not plan or type(_G.amfTransaction) ~= "function" then return false end
    local contextClass = rawget(_G, "FlyActCollectionContext")
    if not contextClass then
        local ok = pcall(require, "amf.feature.mainscene.module.icon.transaction.FlyActCollectionContext")
        if ok then contextClass = rawget(_G, "FlyActCollectionContext") end
    end
    if not contextClass or type(contextClass.new) ~= "function" then return false end
    local context = contextClass.new(self:getConst().actId)
    if type(context.setProgressAnimationPlan) == "function" then
        context:setProgressAnimationPlan(plan)
    else
        context.progressAnimationPlan = plan
    end
    _G.amfTransaction(TransactionEvent.FLY_ACT_COLLECTIONS, context)
    return true
end

-- 是否购买了礼包
function Manager:isGiftBought()
    local giftLevel = self:getModel():getDataByKey("buyPackageId") or 0
    if giftLevel <= 0 then
        return false
    else
        return true
    end
end

function Manager:setGiftBought(goodsId)
    if not goodsId then goodsId = 1 end
    self:getModel():setDataByKey("buyPackageId", goodsId)
end

-- 创建折扣icon
function Manager:createDiscountIcon(level)
    local nopay = self:checkNoPay()
    local icon
    if nopay then
        icon = AMFCompHelper:createDiscountNoPay()
    elseif level == 3 then
        icon = AMFCompHelper:createDiscountFire()
    else
        icon = AMFCompHelper:createDiscountNormal()
    end
    return icon
end

-- 检查是否是无付费用户
function Manager:checkNoPay()
    return self:getModel():getDataByKey("neverPay") or false
end

function Manager:hasEnteredPanel()
    local index = self:getModel():getDataByKey("periodId") or 1
    if self:getModel():hasGuide(index) then
        return true
    else
        return false
    end
end

function Manager:setEnterPanel()
    local index = self:getModel():getDataByKey("periodId") or 1
    self:getModel():setGuideIndex(index)
    self:refreshIconV2("panelEntered")
end

function Manager:checkShowNoTimeTip()
    local index = self:getModel():getDataByKey("periodId") or 1
    local indexStart = 10000+index*3
    local indexTb = {
        indexStart,indexStart+1,indexStart+2
    }
    
    for i,v in ipairs(indexTb) do
        if not self:getModel():hasGuide(v) then
            return true
        end    
    end
    return false
end

function Manager:setShowNoTimeTip()
    local index = self:getModel():getDataByKey("periodId") or 1
    local indexStart = 10000+index*3
    local indexTb = {
        indexStart,indexStart+1,indexStart+2
    }
    
    for i,v in ipairs(indexTb) do
        if not self:getModel():hasGuide(v) then
            self:getModel():setGuideIndex(v)
            return
        end    
    end
end

------------------------------- 关卡内 begin-------------------------------
-- 关卡内功能开启的判断条件入口
function Manager:isActValid(data)
    if not self:isEnabled() then 
        return false 
    end

    --[[
    -- 不需要判断关卡类型了，后端只要活动开放就接受数据
    local levelID = data.levelId
    local levelScene = data.levelScene

    local UserStateManager = _G.amfBean("UserStateManager")
    local userState = UserStateManager and UserStateManager:getUserLevelState()
    if userState and (userState == _G.UserStateConst.UserLevelState.TOP_STAR) then
        -- 满级满星闯关卡库
        if LevelSceneFunc:isFullLevelLib(levelScene) then
            return true
        end
    else
        if UBFLevelSceneFunc:isMainOrHiddenLevel(levelScene) then
            -- 根据玩家的topLevel判定类型
            local topPassedLevelID = _G.getTopPassedLevelId()
            local serverTopLevel = UBFLevelRangeUtil:getUserMaxLevelId()
            local ceilLevelRange = 60

            if topPassedLevelID >= 15 then
                -- 都可以闯top关
                if UBFLevelSceneFunc:isMainLevel(levelScene) and (levelID > topPassedLevelID) then
                    return true
                end

                -- 顶部玩家，可以刷星
                if topPassedLevelID > (serverTopLevel - ceilLevelRange) then
                    local LevelAreaManager = _G.amfBean("LevelAreaManager")
                    local scoreNode = LevelAreaManager and LevelAreaManager:getUserScore(levelID, levelScene)
                    local currStar = scoreNode.star or 0

                    local fullStar = 3
                    if LevelConfigBridge then
                        if LevelConfigBridge:isColorfulLevel(levelID, levelScene) then
                            fullStar = 4
                        end
                    else
                        local levelMeta = LevelMapCompatible:getInstance():getMeta(levelID, levelScene)
                        if levelMeta and levelMeta:isColorfulLevel() then fullStar = 4 end
                    end

                    if currStar < fullStar then
                        return true
                    end
                end
            end
        end
    end
    --]]

    return true
end

function Manager:getLevelModContextData()
    if not self:isEnabled() then return end

    -- 没什么数据要传递的，随便写一个吧
    local contextData = {
        valid = true
    }
    return contextData
end

--打关结束时更新数据
function Manager:updatePassLevelData(data, collectionCount, collectionMap, passLevelData)
    if not self:isEnabled() then return end

    local levelId = data and data.levelInfo and data.levelInfo.levelId
    local originPassedLevelId = _G.getTopPassedLevelId()
    if not originPassedLevelId then return end
    -- 过关应该+1
    local topPassedLevelId = originPassedLevelId+1
    -- 限制不能超过topLevel
    local topLevelId =  _G.getTopLevelId()
    local levelStatus = self:getLocalLevelStatus(topLevelId)

    --当前能打关卡库，判断最简单，直接判是否关卡库
    if (levelStatus == 3) and data and data.levelInfo then
        if LevelSceneFunc:isFullLevelLib(data.levelInfo.levelScene) then
            -- printx(42, "随机挑战成功")
            self:refreshLocalActInfo()
        end
        return
    end
    -- 下一主线关等于当前打关id，过主线成功
    -- 不用处理top这一关，因为top全满的时候打最高关是top，topPassLevelId=top+1
    if levelId == topPassedLevelId then
        -- printx(42, "通过了topLevel关! levelId:", levelId)
        self:refreshLocalActInfo()
        return
    end

    -- 补星，判主线且补星成功
    if (levelStatus == 2) and data and data.levelInfo then
        local oldStar = data.levelInfo.oldStar or 0
        local newStar = data.curStar or 0
        local bRefreshStarSucess = newStar > oldStar
        -- printx(42, "补星成功", bRefreshStarSucess)
        if bRefreshStarSucess and LevelSceneFunc:isMainLevel(data.levelInfo.levelScene) then
            self:refreshLocalActInfo()
        end
    end
end

function Manager:refreshLocalActInfo()
    local maxTarget = self:getTaskMaxTarget()
    local oldProgress = self:getProgressValue()
    -- 进度已经超过最大目标，直接返回
    if oldProgress >= maxTarget then return end

    local oldTaskId = self:getCurrentTaskId()
    local current = oldProgress+1
    self:getModel():setDataByKey("current", current)
    if self:isV2IconExperimentEnabled() then
        local newTaskId = self:getCurrentTaskId()
        local plan = self:buildPassLevelProgressAnimationPlan(
            oldProgress,
            current,
            oldTaskId,
            newTaskId
        )
        self:submitPassLevelProgressAnimationPlan(plan)
        self:refreshIconV2("scene3ProgressChanged", {
            previous = oldProgress,
            current = current,
            total = tonumber(self:getTaskTotalByIndex(oldTaskId)) or maxTarget,
        })
    end
    local newTaskId = self:getCurrentTaskId()

    --  新旧taskId不同 或者 旧进度小于最大，新进度大于等于最大
    if (oldTaskId < newTaskId) or (oldProgress < maxTarget and current >= maxTarget) then
        self:dc("play_feedback", "main_panel_success", nil, oldTaskId)
    end

    -- 有网时不刷新actInfo
    local netStatus = _G.amfBean("NetworkStatusManager"):getNetworkStatus()
    if EnvUtil:isDevelopMode() then
        printx(42, "net status 527", netStatus)
    end
    if netStatus ~= _G.NetworkConst.NetworkStatusDes.NONETWORK then
        return
    end
    local actInfo = _G.amfBean("ActivityMgr"):getActInfo(self:getConst().actId)
    if actInfo and actInfo.extra then
        local extraConfig = table.deserialize(actInfo.extra)
        local id = self:getCurrentTaskId()
        extraConfig.currentRewards = {{
            itemId=14,num=self:getConfigGoldNumByIndex(id)
        }}
        extraConfig.current = current
        if extraConfig.currentTask then
            extraConfig.currentTask.total = self:getTaskTotalByIndex(id)
        end
        actInfo.extra = table.serialize(extraConfig)
        self:callPlug("Act","setActInfo",actInfo)
    end
end

function Manager:getTaskTotalByIndex(index)
    if not index then index = self:getCurrentTaskId() end
    local tasks = self:getTaskConfig()
    local task = tasks[index]
    if not task then return 0 end
    return task.total
end

------------------------------- 关卡内 end-------------------------------

-- 获取礼包等级，未购买默认1， 购买后根据数据可能返回1 2 3
function Manager:getGiftLevel()
    local level = self:getModel():getDataByKey("buyPackageTier") or 0
    if level <= 0 then level = 1 end
    return level
end

function Manager:setGiftLevel(level)
    self:getModel():setDataByKey("buyPackageTier", level)
    -- 改造actInfo
    local actInfo = _G.amfBean("ActivityMgr"):getActInfo(self:getConst().actId)
    if actInfo and actInfo.extra then
        local extraConfig = table.deserialize(actInfo.extra)
        extraConfig.buyPackageTier = level
        local id = self:getCurrentTaskId()
        extraConfig.currentRewards = {{
            itemId=14,num=self:getConfigGoldNumByIndex(id)
        }}
        actInfo.extra = table.serialize(extraConfig)
        self:callPlug("Act","setActInfo",actInfo)
    end

    -- 刷新taskId
    self:refreshTaskId(level)
end

function Manager:refreshTaskId(giftLevel)
    local tasks = self:getTaskConfig()

    for k,v in ipairs(tasks or {}) do
        local taskId = self:getConfigTaskIdByIndex(k)
        v.id = taskId
    end
    self:getModel():setDataByKey("tasks", tasks)
end

--  注册礼包module
function Manager:registerGiftModule()
    if not self.giftRegisted then
        local GiftEventCenter = require "amf.feature.giftpackage.event.GiftEventCenter"
        GiftEventCenter:registerCustomModule(self.giftShopPart, GiftPackageConst.StageType.STORE)
        GiftEventCenter:registerCustomModule(self.giftAddFivePart, GiftPackageConst.StageType.ADD_STEP)
        GiftEventCenter:registerCustomModule(self.giftPartFake, GiftPackageConst.StageType.ADD_STEP)

        GiftEventCenter:register(GiftEvent.STORE_PANEL_DC_FAKE_GIFT, function(event)
            self:handleStoreShowDC(event)
        end)
        self.giftRegisted = true
    end
end

function Manager:handleStoreShowDC(event)
    if not self:isEnabled() then return end
    local data = event:getData()
    if data and data.dcParam and not self:isGiftBought() then
        data.dcParam.actid = tostring(self:getConst().actId)
    end
end

function Manager:initGiftModule()
    local GiftModule = require 'amf.feature.localactivity.sprintgiftpackage.module.SprintGiftAddFiveModule'
    self.giftAddFivePart = GiftModule.new(self)

    local GiftShopModule = require 'amf.feature.localactivity.sprintgiftpackage.module.SprintGiftShopModule'
    self.giftShopPart = GiftShopModule.new(self)

    local GiftFakeModule = require 'amf.feature.localactivity.sprintgiftpackage.module.SprintGiftFakeModule'
    self.giftPartFake = GiftFakeModule.new(self)
    self.giftPartFake:setJustOccupied()
end

-- 检查是否三选一分组
-- 这个接口只有MainPanelVM在用，并且购买后threeone判断的地方都会优先判断isBought，threeone就没用了，返回false也没问题
function Manager:checkThreeOne()
    if not self:isEnabled2() then return end
    -- local group = self:getModel():getDataByKey("group")
    -- if group and (group == "ON2" or group == "ON3") then
    --     return true
    -- end
    -- return false
    local packageBean = self:getModel():getDataByKey("packagesPullResponseBean")
    if not packageBean then return false end
    if not packageBean.displayablePackages then return false end
    local packageCnt = table.length(packageBean.displayablePackages)
    return packageCnt == 3
end

function Manager:getGiftPrice(level)
    if not level then level = 1 end
    local packageBean = self:getModel():getDataByKey("packagesPullResponseBean")
    if not packageBean then return 0 end
    -- printx(42, "packagesPullResponseBean", tts(packageBean))
    if not packageBean.displayablePackages then return 0 end
    if not packageBean.displayablePackages[level] then return 0 end
    local packageId = packageBean.displayablePackages[level].packageId
    if not packageBean.packageMetas then return 0 end
    local giftMeta = packageBean.packageMetas[tostring(packageId)]
    if not giftMeta then return 0 end
    local metaTable = table.deserialize(giftMeta.packageMeta)
    if metaTable then
        return metaTable.priceSelling/100
    end
    return 0
end

function Manager:getGoodsIdByLevel(level)
    if not level then level = 1 end
    local packageBean = self:getModel():getDataByKey("packagesPullResponseBean")
    if not packageBean then return 0 end
    if not packageBean.displayablePackages then return 0 end
    if not packageBean.displayablePackages[level] then return 0 end
    local packageId = packageBean.displayablePackages[level].packageId
    return packageId or 0
end

-- 按照任务配置index获取风车币
function Manager:getConfigGoldNumByIndex(index)
    local taskMetas = self:getModel():getConfigByKey("taskRecMetas")
    if not taskMetas then return 0 end
    local level = self:getGiftLevel()
    local levelTaskMeta = table.find(taskMetas or {}, function(v)
        return v.packageTierId == level
    end)
    if not levelTaskMeta then return 0 end
    local goldConfig = levelTaskMeta.taskMetas[index]
    if not goldConfig then return 0 end
    return goldConfig.rewards[1].num
end

function Manager:getConfigTaskIdByIndex(index)
    local taskMetas = self:getModel():getConfigByKey("taskRecMetas")
    if not taskMetas then return 0 end
    local level = self:getGiftLevel()
    local levelTaskMeta = table.find(taskMetas or {}, function(v)
        return v.packageTierId == level
    end)
    if not levelTaskMeta then return 0 end
    local goldConfig = levelTaskMeta.taskMetas[index]
    -- printx(42, "giftlevel", level, tts(goldConfig))
    if not goldConfig then return 0 end
    return goldConfig.id
end

-- 得到活动中从初始开始到结束能获得多少风车币
function Manager:getTotalGoldNum(customLevel)
    local taskMetas = self:getModel():getConfigByKey("taskRecMetas")
    if not taskMetas then return 0 end
    local level
    if customLevel then
        level = customLevel
    else
        level = self:getGiftLevel()
    end
    local levelTaskMeta = table.find(taskMetas or {}, function(v)
        return v.packageTierId == level
    end)

    if not levelTaskMeta then return 0 end
    -- printx(42, "levelTaskMeta", tts(levelTaskMeta))
    local ret = 0
    for k, v in pairs(levelTaskMeta.taskMetas or {}) do
        ret = ret + v.rewards[1].num
    end
    return ret
end

-- discount数值展示多少
function Manager:getDiscountNum(level)
    local taskMetas = self:getModel():getConfigByKey("taskRecMetas")
    if not taskMetas then return 0 end
    if not level then level = self:getGiftLevel() end
    local levelTaskMeta = table.find(taskMetas or {}, function(v)
        return v.packageTierId == level
    end)
    if not levelTaskMeta then return 0 end
    return levelTaskMeta.discount or 0
end

function Manager:openActivity(closeCallback,extra,userClick, saveIndex)
    if not extra then extra = {} end

    self:savePopFlag(saveIndex)

    self:callPlug("Act","openActivity",{
        actId = self:getConst().actId,
        extra = {
            from = extra.from,
        },
        failCallback = closeCallback,
        endCallback = closeCallback,
        userClick = userClick,
    })
end

function Manager:savePopFlag(saveIndex)
    local saveStr = self:getConst()['popTip'..tostring(saveIndex)]
    if saveIndex and saveStr then
        self:getModel():saveFlagToLocalByKey(saveStr, nil, true)
    end
end

function Manager:getActMainEndTimeStr()
    local ret = TimeUtil:timeFormatVer1({endTimeInSec = self:getModel():getMainEndTimeInSec()})
    local timeStr = ""
    if ret then
        timeStr = ret.retString or ""
    end
    return timeStr
end

function Manager:checkCanGetAnyReward()
    if not self:isGiftBought() then return false end
    local canGetNum = self:getCurrentCanRewardGoldNum()
    return canGetNum > 0
end

function Manager:setGiftRewardGet(index)
    local tasks = self:getTaskConfig()
    if index then
        local task = table.find(tasks, function(v)
            return v.id == index
        end)
        -- printx(42, "task----", tts(task), index)
        if not task then return end
        task.hasReward = true
    else
        local current = self:getProgressValue()
        for k,v in ipairs(tasks) do
            if current >= v.total then
                v.hasReward = true
            end
        end
    end
    self:getModel():setDataByKey("tasks", tasks)
end

function Manager:checkIconTip(config)
    if not self:isEnabled2() then return end
    if self:isInMainTime() then
        local show, callback, levelCnt = self:checkShowProgressTip()
        if show then
            self:addIconTip(string.format("还差%d关就能领奖！", levelCnt), config, callback)
            return
        end

        if self:checkShowTimeOutTip() then
            local callback = function()
                self:getModel():saveFlagToLocalByKey("timeOutTip", nil, true)
            end
            self:addIconTip("记得还有任务哦！", config, callback)
        end
    else
        if self:checkShowBoughtNeedClaimTip() then
            local callback = function()
                self:getModel():saveFlagToLocalByKey("rewardTimeTip", nil, true)
            end
            self:addIconTip("最后领奖机会！", config, callback)
        end
    end
end

function Manager:addIconTip(text, config, callback)
    if not text then return end
    local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")
    IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, {
        iconKey = tostring(self:getConst().actId),
        iconType = IconTipType.MESSAGE,
        creatorDelegate = {
            tipsType = HomeIconTipsType.ONLY_TEXT,
            text = text,
        },
        typeIndex = 1,
        popFunc = callback,
        config = config,
    })
end

-- 判断是否能弹出任务进度tip；返回能否弹出的bool值，以及n（还差n关就能领奖），不能弹出时n无意义
function Manager:checkShowProgressTip()
    if not self:isEnabled2() then return end
    if not self:isGiftBought() then return end
    if not self:isInMainTime() then return end

    local tasks = self:getTaskConfig()
    local targetTask
    local current = self:getProgressValue()
    for k, v in ipairs(tasks) do
        if current < v.total then
            targetTask = v
            break
        end
    end
    if not targetTask then return end
    local leftLevel = targetTask.total-current
    if leftLevel > 5 then return end
    local periodId = self:getModel():getDataByKey("periodId") or 1
    local innerKey = tostring(periodId).."_" .. tostring(targetTask.id)
    local flag = self:getValueFromLocalByKey("taskTip", innerKey)
    if flag then return end

    local callback = function()
        self:saveValueToLocalByKey("taskTip", innerKey, false, true)
    end

    return true, callback, leftLevel
end

-- 判断正式期即将结束已购买却还有未完成任务tip
function Manager:checkShowTimeOutTip()
    if not self:isEnabled2() then return end
    if not self:isGiftBought() then return end
    if not self:isInMainTime() then return end
    local current = self:getProgressValue()
    local maxTarget = self:getTaskMaxTarget()
    if current >= maxTarget then
        -- 全完成了
        return false
    end
    local time1 = self:getConst().timeOutTipMinTime or 30*60
    local time2 = self:getConst().timeOutTipMaxTime or 60*60*24
    local leftTime = self:getModel():getMainEndTimeInSec()-TimeKit:timeInSec()
    if leftTime >= time1 and leftTime < time2 then
        local flag = self:getModel():getFlagFromLocalByKey("timeOutTip", nil, true, false)
        return not flag
    end
end

-- 判断领奖期内已购买还有未领取的奖励tip
function Manager:checkShowBoughtNeedClaimTip()
    if not self:isEnabled2() then return end
    if not self:isGiftBought() then return end
    if not self:isInRewardTime() then return end
    if self:checkCanGetAnyReward() then
        local flag = self:getModel():getFlagFromLocalByKey("rewardTimeTip", nil, true, false)
        return not flag
    end
end

function Manager:saveValueToLocalByKey(outerKey, innnerKey, needTime, value)
    if not outerKey then return end
    if not innnerKey then return end

    local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())

    local saveValue = {
        time = nowTime,
        value = value
    }

    local saveRecordTableStr = self:getModel():getValue(outerKey) or "{}"
    local saveRecordTable = table.deserialize(saveRecordTableStr)
    saveRecordTable[innnerKey] = saveValue
    saveRecordTableStr = table.serialize(saveRecordTable)

    self:getModel():setValue(outerKey, saveRecordTableStr, true)
end

function Manager:getValueFromLocalByKey(outerKey, innnerKey, needTime)
    if not outerKey then return end
    if not innnerKey then return end

    local saveRecordTableStr = self:getModel():getValue(outerKey) or "{}"
    local saveRecordTable = table.deserialize(saveRecordTableStr)

    local saveValue = saveRecordTable[innnerKey]
    if saveValue == nil then return end

    local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())
    local bTimeIsOk = true

    -- 需要检查是否同一天 且 时间不同
    if needTime and saveValue.time ~= nowTime then
        bTimeIsOk = false
    end

    -- 检查是否同一天 且 不是同一天 返回空
    if needTime and not bTimeIsOk then
        return
    else
        return saveValue.value
    end
end

-- 返回1，2，3，对应三种文案
function Manager:getLocalLevelStatus(passLevel)
    local userState = _G.amfBean("UserStateManager"):getUserSegmentState()
    -- 非满紫或者全满符合关卡库条件
    if (userState == _G.UserStateConst.UserSegmentState.FMZ) or (userState == _G.UserStateConst.UserSegmentState.MHZC)  then
        return 3
    end

    if not passLevel then
        passLevel = getTopPassedLevelId()
    end
    local configMaxLevel = amfBean("UnlockManager"):getUserMaxLevelId()
    local configLevel = self:getModel():getConfigByKey("fullLevelMinPasslevel") or -90
    configLevel = math.floor(math.abs(configLevel))
    -- printx(42, "vocnfig level", configLevel)
    if configMaxLevel-passLevel>=configLevel then
        return 1
    else
        return 2
    end
end

function Manager:saveLocalLevelStatus(value)
    self:getModel():saveFlagToLocalByKeyInt("historyLevelStatus", nil, value)
end

function Manager:getHistoryLocalLevelStatus()
    return self:getModel():getFlagFromLocalByKeyInt("historyLevelStatus", nil, true, 0)
end

function Manager:checkAddStepGroup()
    local enabledScenes = self:getModel():getDataByKey("enabledScenes") or {}
    return table.exist(enabledScenes, self:getConst().addFiveSteps)
end

function Manager:checkShopGroup()
    local enabledScenes = self:getModel():getDataByKey("enabledScenes") or {}
    return table.exist(enabledScenes, self:getConst().shopPanel)
end

function Manager:checkCurPeriodPop()
    if not self:isEnabled2() then return end
    return not self:hasEnteredPanel()
end

function Manager:checkMainTimeAllTaskDonePop()
    if not self:isEnabled2() then return end
    if self:isInMainTime() then
        local current = self:getProgressValue()
        local maxTarget = self:getTaskMaxTarget()
        local allClear = current>=maxTarget
        if not allClear then return false end
        local popFlag = self:getModel():getFlagFromLocalByKey(self:getConst().popTip2,nil, true, false)
        if popFlag then return false end
        return true
    end
end

function Manager:checkRewardTimeNeedBuyPop()
    if not self:isEnabled2() then return end
    if self:isInRewardTime() then
        local current = self:getProgressValue()
        local maxTarget = self:getTaskMaxTarget()
        local allClear = current>=maxTarget
        if not allClear then return false end
        local popFlag = self:getModel():getFlagFromLocalByKey(self:getConst().popTip3,nil, true, false)
        if popFlag then return false end
        return true
    end
end

function Manager:checkRewardTimeBoughtNeedClaimPop()
    if not self:isEnabled2() then return end
    if self:isInRewardTime() then
        local canGet = self:checkCanGetAnyReward()
        if not canGet then return false end
        local popFlag = self:getModel():getFlagFromLocalByKey(self:getConst().popTip4,nil, true, false)
        if popFlag then return false end
        return true
    end
end

-- 在新关开启的指定时间内（暂定4小时），玩家主线关满星前，闯头部新关不触发关卡内结算面板点叉的场景4强弹
function Manager:ignoreForTopLevelPlayer()
    local userState = _G.amfBean("UserStateManager"):getUserSegmentState()
    if userState == _G.UserStateConst.UserLevelState.MHZC then
        return false
    end

    local topLevelId = _G.getTopLevelId()
    if not _G.amfBean("LevelUnLockManager"):isTopNewMainLevel(topLevelId) then
        return false
    end

    if not _G.amfBean("LevelUnLockManager"):isInNewLevelTime() then
        return false
    end

    return true
end

function Manager:onActEnterStage2(evt)
    if not self:isEnabled2() then
        return
    end
    if self:ignoreForTopLevelPlayer() then
        return
    end

    local saveIndex = 0
    if self:isInMainTime() then
        if self:checkCurPeriodPop() then
            saveIndex = 1
        elseif self:checkMainTimeAllTaskDonePop() then
            saveIndex = 2
        else
            return
        end
    else
        if self:checkRewardTimeNeedBuyPop() then
            saveIndex = 3
        elseif self:checkRewardTimeBoughtNeedClaimPop() then
            saveIndex = 4
        else
            return
        end
    end

    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.SPRINT_GIFT_CHECK_STAGE_2)
    end
    local creator = function ( ... )
        if not self:isEnabled2() then
            safeRunCall(onHandleOver)
            return
        end
        self:openActivity(onHandleOver, nil, false, saveIndex)
    end
    _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.SPRINT_GIFT_CHECK_STAGE_2, creator)
end

-- 没买时返回false，买了查看是否有能领的
function Manager:hasReward()
    if not self:isGiftBought() then return false end
    return self:checkCanGetAnyReward()
end

-- 当前所能领取的所有金币数量，不管买没买
function Manager:getCurrentCanRewardGoldNum()
    local tasks = self:getTaskConfig()
    local current = self:getProgressValue()
    local ret = 0
    for k,v in ipairs(tasks or {}) do
        if (not v.hasReward) and current >= v.total then
            local goldNum = self:getConfigGoldNumByIndex(k)
            ret = ret + goldNum
        end
    end
    return ret
end

-- 当前任务id，从1开始，全部完成返回最后一个id
function Manager:getCurrentTaskId()
    local tasks = self:getTaskConfig()
    local current = self:getProgressValue()
    local ret = 1
    for k,v in ipairs(tasks or {}) do
        ret = k
        if current < v.total then
            break
        end
    end
    return ret
end

function Manager:saveTodayTriggerAct()
    self:getModel():saveFlagToLocalByKey("todayTriggerAct", true, true)
end

function Manager:getTodayTriggerAct()
    return self:getModel():getFlagFromLocalByKey("todayTriggerAct", true)
end

function Manager:saveTodayJoinAct()
    self:getModel():saveFlagToLocalByKey("todayJoinAct", true, true)
end

function Manager:getTodayJoinAct()
    return self:getModel():getFlagFromLocalByKey("todayJoinAct", true)
end

function Manager:getActSkinType()
    return self:getModel():getConfigByKey("uiType") or self:getConst().NormalSkin
end

return Manager
