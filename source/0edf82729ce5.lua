local ActivityName = "StarWandBuff"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local MainSceneEventCenter = require 'amf.feature.mainscene.core.event.MainSceneEventCenter'
local FarmLevelEventCenter = require 'amf.feature.mainscene.module.assetsbar.star.event.FarmLevelEventCenter'
local SceneTopBannerEventCenter = require 'amf.feature.mainscene.module.topbanner.event.SceneTopBannerEventCenter'

local Condition = require "amf.script.sugar.Condition"
local deferred = require "amf.script.sugar.deferred"
local AsyncRunner = require "amf.script.sugar.AsyncRunner"
local FlowerConfig = require "amf.feature.mainscene.module.flower.flowernode.config.FlowerConfig"
local MainSceneConfig = require "amf.feature.fulllevel.starwandbuff.mainscene.Config"
local LevelNodePosConfig = require "amf.feature.mainscene.world.config.LevelNodePosConfig"

local LevelRecommendLogic = require("amf.feature.fulllevel.starwandbuff.logic.LevelRecommendLogic")

local Manager = class(ActivityName .. "Manager")
Manager.ACT_OPEN_VERSION = 1
Manager.ACT_ID = 5305
Manager.ACT_CH_NAME = "补星权杖"
Manager.GuideFlag = {
    kFlowerTip = 1001,
    kTapFlower = 1002,
    kButtonCloud = 1003,
    kTabClicked = 1004
}
local Event = {
    CLOSE_ALL_PANEL = 'CloseAllPanel',    --关闭所有界面
}

function Manager:log(...)
    if not EnvUtil:isDevelopMode() then return end
    if EnvUtil:isMiniGame() then
        UWarning("[Star Wand Buff]",...)
    else
        printx(33, "[Star Wand Buff]", ...)
    end
end

function Manager:ctor()
    self._levelAreaManager = nil
    self._userStateManager = nil
    self._profileManager = nil
    self._userManager = nil
    self._activityMgr = nil
    self._propManager = nil
    self._sceneTopBannerHandler = nil
end

function Manager:setSceneTopBannerHandler(sceneTopBannerHandler)
    self._sceneTopBannerHandler = sceneTopBannerHandler
end

function Manager:setLevelAreaManager(levelAreaManager)
    self._levelAreaManager = levelAreaManager
end

function Manager:setUserStateManager(userStateManager)
    self._userStateManager = userStateManager
end

function Manager:setProfileManager(profileManager)
    self._profileManager = profileManager
end

function Manager:setUserManager(userManager)
    self._userManager = userManager
end

function Manager:setActivityMgr(activityMgr)
    self._activityMgr = activityMgr
end

function Manager:setPropManager(propManager)
    self._propManager = propManager
end

function Manager:setAreaCompletionManager(areaCompletionManager)
    self._areaCompletionManager = areaCompletionManager
end

function Manager:setMainSceneButtonManager(mainSceneButtonManager)
    self._mainSceneButtonManager = mainSceneButtonManager
end

local Meta = require('amf.feature.fulllevel.'..string.lower(ActivityName)..'.model.'..ActivityName..'Meta')
local Model = require('amf.feature.fulllevel.'..string.lower(ActivityName)..'.model.'..ActivityName..'Model')
function Manager:initialize()
    self.model = Model:create()
    self.modules = {}
    -- 大藤蔓需要展示的关卡 已推荐&次数未用完
    self.mainSceneLevelMap = {}
    -- 需要清理的关卡，mainSceneLevelMap更新后尝试写入，onCreate时清理，
    self.needRecheckLevelMap = {}
    self:registerModule()
    self:registerEvents()
    self:registerEnterFresh()

    self.sendingLevelsModuleKeys = {}
end

function Manager:getModel()
    return self.model
end

-- 注册需要添加补星权杖的活动
function Manager:registerModule()
    local function addModule(module)
        table.insert(self.modules, module)
    end
    addModule(require("amf.feature.fulllevel.starwandbuff.module.LuckyFarmStarWandModule"))
    addModule(require("amf.feature.fulllevel.starwandbuff.module.MajorStarBuffWandModule"))
    table.sort(self.modules, function(a, b)
        return a:getPriority() > b:getPriority()
    end)
end

function Manager:getAllOpenKey()
    local openList = {}
    for i, v in ipairs(self.modules) do
        if v:isOpen() then
            table.insert(openList, v:getKey())
        end
    end
    return openList
end

function Manager:getModuleByKey(key)
    for i, module in ipairs(self.modules) do
        if tostring(module:getKey()) == tostring(key) then
            return module
        end
    end
    return nil
end

function Manager:registerEvents()
    _G.amfEC:bindEventObserver(self, "onStarWandBuff")
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)

    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
end

-- 大藤蔓加载完成且拉完数据后刷新大藤蔓展示
function Manager:registerEnterFresh()
    self.onEnterCondition = Condition.new(function()
        self.onEnterCondition = nil
        self:updateMainScene()
    end, 2)
end

function Manager:managePanelVM(panelVM)
    if not panelVM or panelVM.isDisposed then
        return
    end
    local this = self

    local oriFunc = panelVM.recycle
    panelVM.recycle = function(obj)
        this:removeObserver(obj)
        safeRunCall(oriFunc, obj)
    end
    local oriFunc = panelVM.onCustomCloseAllPanel
    panelVM.onCustomCloseAllPanel = function(obj)
        safeRunCall(oriFunc, obj)
        if obj.isDisposed then
            return
        end
        if obj.close then
            obj:close(true)
        else
            obj:_close()
        end
    end

    self:addObserver(panelVM)
end

--换色
function Manager:hex2Vec4(hex)
    local ccc4 = hex2ccc4(hex)
    return Vec4(ccc4.r/255, ccc4.g/255, ccc4.b/255, ccc4.a/255)
end

-- 同步所有数据
function Manager:updateData(data, skipSaveLocal)
    if not data then return end

    self:getModel():fromServer(data,skipSaveLocal)
end

-- 功能生效
function Manager:isEnabled()
    if not FeatureSwitch:isOpen(FeatureSwitch.Type.STAR_WAND_BUFF) then return end
    return self:getModel():isDataEnabled() and self:getModel():isInActTime() and self.filesLoaded
end

-- 有权杖buff正在生效
function Manager:isValid()
    if not self:isEnabled() then return false end
    if not self.mainSceneLevelMap or table.isEmpty(self.mainSceneLevelMap) then return end
    local mainLevelMap = self.mainSceneLevelMap[UBFLevelSceneType.kMain] or {}
    local hiddenLevelMap = self.mainSceneLevelMap[UBFLevelSceneType.kHide] or {}
    if #mainLevelMap + #hiddenLevelMap == 0 then
        return false
    end
    return true
end

function Manager:onEnabled()
    self:log("onEnabled")
    MainSceneEventCenter:register(MainSceneEvent.View.FLOWER_CREATE, self.onFlowerCreate, self)
    MainSceneEventCenter:register(MainSceneEvent.Trunk.MOVE_TRUNK_TO_END, self.onMoveTrunkToEnd, self)
    FarmLevelEventCenter:register(FarmLevelEvent.GET_PANEL_ASSE_TLIST, self.onFarmLevelGetPanelAssetList, self)
    FarmLevelEventCenter:register(FarmLevelEvent.PANEL_TAB_CREATE, self.onFarmLevelPanelTabCreate, self)
    FarmLevelEventCenter:register(FarmLevelEvent.PANEL_CHANGE_TAB, self.onFarmLevelPanelChangeTab, self)
    FarmLevelEventCenter:register(FarmLevelEvent.PANEL_CREATE_TOP_UI, self.onFarmLevelPanelCreateTopUI, self)
end

----------------------------- 功能函数 -----------------------------
--------------------- 本地缓存相关 ---------------------
-- 获取本地缓存的完整key
function Manager:getLocalKey(key, needTime)
    if EnvUtil:isDevelopMode() then
        local index = string.find(key, "%.")
        if index ~= nil then
            CommonTip:showTip("dev: key不要有'.', AMFDataRef中依据此判断table层级")
        end
    end
    local str = string.format("%s_%s_%s_%s",self._profileManager:getUid(),ActivityName,Manager.ACT_OPEN_VERSION,key)
    if needTime then
        local curTime = TimeKit:timeInSec()
        local dayStartTime = getDayStartTimeByTS(curTime)
        str = str .. ':' .. dayStartTime
    end    return str
end

function Manager:setFlagToLocalByKey(key, needTime, value)
    if not key then return end
    if value == nil then value = true end
    local keyStr = self:getLocalKey(key, needTime)
    self:getModel():setLocalCache(keyStr, value)
end

function Manager:getFlagFromLocalByKey(key, needTime)
    local keyStr = self:getLocalKey(key, needTime)
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
    local keyStr = self:getLocalKey(key, needTime)
    self:getModel():setLocalCache(keyStr, setNum)
end

function Manager:getIntFromLocalByKey(key, needTime)
    local keyStr = self:getLocalKey(key, needTime)
    return self:getModel():getLocalCache(keyStr) or 0
end

function Manager:setStringToLocalByKey(key, needTime, value)
    if not key then return end
    if value == nil then value = "" end
    local keyStr = self:getLocalKey(key, needTime)
    self:getModel():setLocalCache(keyStr, value)
end

function Manager:getStringFromLocalByKey(key, needTime)
    local keyStr = self:getLocalKey(key, needTime)
    return self:getModel():getLocalCache(keyStr) or ""
end

function Manager:getDataByKey(key, defaultValue, copyTable)
    return self:getModel():getDataByKey(key, defaultValue, copyTable)
end

function Manager:setDataByKey(key, value, needSave)
    self:getModel():setDataByKey(key, value, needSave)
end
------------------------ 其它通用方法 ------------------------
-- 检测引导标记
function Manager:hasGuideIndex(index, checkLocalData)
    local hasIndex = self:getModel():hasGuide(index)

    if checkLocalData == nil then checkLocalData = true end
    if checkLocalData then
        local hasLocal = self:getFlagFromLocalByKey("LocalGuideId"..index, false)
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
        self:setFlagToLocalByKey("LocalGuideId"..index, false, true)
    end

    local ActCommonHttp
    ActCommonHttp = require("amf.middleware.activity.http.ActCommonHttp")
    ActCommonHttp:setActGuideFlag(Manager.ACT_ID, index)
end

-- 打点
function Manager:dc(category, subCategory, extraData)
    if type(extraData) == "number" then return end
    local params = {
        game_type = "stage",
        game_name = "starbuff2022",
        category = category,
        sub_category = subCategory,
    }

    for i, v in pairs(extraData or {}) do
        params[i] = v
    end
    DcUtil:activity(params)
end

function Manager:getActInfo()
    return self._activityMgr:getActInfo(Manager.ACT_ID)
end

function Manager:openActivity(finishCallback, extra, userClick)
    ActivityEventCenter:dispatch(ActivityEvent.OPEN_ACTIVITY, {
        actId = Manager.ACT_ID,
        failCallback = finishCallback,
        endCallback = finishCallback,
        userClick = userClick,
        extra = extra,
    })
end

function Manager:createIcon(reward)
    local icon
    icon = GameItemCreator:getPropIcon(reward)
    return icon
end

function Manager:updateActTimeAndLightStart(actInfo)
    if actInfo and actInfo.extra then
        local extra = table.deserialize(actInfo.extra)
        if extra and extra.beginTime then
            local actTime = {}
            actTime.beginTime = tonumber(extra.beginTime)/1000 or 0
            actTime.endTime = tonumber(extra.endTime)/1000 or 0
            actTime.beginTime = 0
            -- actTime.endTime = TimeKit:timeInSec() + 24 * 3600 * 7 -- 临时测试用
            self:getModel():updateActTime(actTime)
            self:tryLightStart()
        end
    end
end

function Manager:tryInitActInfo()
    local actInfo = self:getActInfo()
    self:updateActTimeAndLightStart(actInfo)
end

----------------------- 响应事件 -----------------------------
function Manager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(Manager.ACT_ID)]
    if fromServer and actInfo then
        self:updateActTimeAndLightStart(actInfo)
    end
end

function Manager:onActUserLevelStateChanged(evt)
    if not self:isEnabled() then return end
    local data = evt:getData()
    local newState = data.segmentState
    -- 从满级变成非满级时 关闭权杖
    if newState == _G.UserStateConst.UserSegmentState.FMJ then
        self:updateLevelMapForMainScene()
        self:updateMainScene()
    end
end

function Manager:onActBeforeStartLevel(evt)
    if not self:isEnabled() then return end
    local data = evt:getData()
    local levelId = data.levelId
    local levelScene = data.levelScene
    -- 是否有次数可用
    if table.isEmpty(self.mainSceneLevelMap) or table.isEmpty(self.mainSceneLevelMap[levelScene]) then return end
    if not table.exist(self.mainSceneLevelMap[levelScene], levelId) then return end
    local startLevelConfig = {
        levelId = levelId,
        levelScene = levelScene,
    }
    for i, module in ipairs(self.modules) do
        module:onBeforeStartLevel(startLevelConfig)
    end

    local bFreeUse = false
    local colorfulStarWinRepeatMgr = _G.amfBean("WinningStreakManager"):getModule("colorful_star_winning_streak").mgr
    if colorfulStarWinRepeatMgr:checkCanFreeStarWandBuff() and colorfulStarWinRepeatMgr:isLevelSupport(levelId) then
        bFreeUse = true
    end

    if not bFreeUse then
        local jsonId = self.ACT_ID
        data.jsonTable[tostring(jsonId)] = {
            useItem = true
        }
        self:getModel():addUseTime(levelId, levelScene)
        self:dc("canyu", "join")
        self:updateLevelMapForMainScene()
        self:updateMainScene()
    end
end

function Manager:onActPlayLevelEnd(evt)
    local data = evt:getData()
    self:updateLevelMapForMainScene()
end

function Manager:onActStartLevelGetBuff(evt)
    local data = evt:getData()
    local levelId = data.levelId
    local levelScene = data.levelScene
    local actId = data.actID
    if tonumber(actId) ~= tonumber(Manager.ACT_ID) then return end
    if LevelSceneFunc:isFullLevelLib(data.levelScene) then
        return
    end
    if not self:isTimeEnabled() or not self:isValid() then return nil end

    local config = self:getBuffConfig()
    local leftNum = 0
    local recommendLevelUseMap = self:getDataByKey("recommendLevelUseMap", {}, false)
    for key, levelTable in pairs(recommendLevelUseMap) do
        if levelTable[levelScene] and levelTable[levelScene][levelId] then
            local module = self:getModuleByKey(key)
            local totalTime = module:getPerLevelTime()
            local usedTime = levelTable[levelScene][levelId]
            leftNum = totalTime - usedTime
            break
        end
    end

    if leftNum > 0 and config then
        local dataPack = {}
        dataPack.maceNum = leftNum
        dataPack.endTime = self:getModel():getActEndTime()
        config.dataPack = dataPack
        table.insert(data.config, config)
    end
end

function Manager:startLevelPanelLevelNodePopoutDataCount(data)
    if self:isTimeEnabled() and self:isValid() and data.levelId and self:isLevelRecommended(data.levelId, data.levelScene) then
        self:dc("click", "click_level", {t1 = 2, t2 = data.levelId})
    end
end

function Manager:isTimeEnabled()
    local model = self:getModel()
    if model and model:isInActTime() then
        return true
    end
    return false
end

function Manager:isLevelRecommended(levelId, levelScene)
    if table.isEmpty(self.mainSceneLevelMap) or table.isEmpty(self.mainSceneLevelMap[levelScene]) then return end
    if not table.exist(self.mainSceneLevelMap[levelScene], levelId) then return end
    return true
end

function Manager:getBuffConfig()
    if self:isEnabled() then
        return self:getModel():getDataByKey("config", {})
    end
    return {}
end

function Manager:onActPassDay()
    if not self:isEnabled() then return end
    self:dcDayResult()
    self:getModel():passDayReset()
    self.hasLightStart = false
    self.isDoingLightStart = false

    -- 还原昨天的关卡花
    local levelNodeNeedReset = {}
    local hideLevelNodeNeedReset = {}
    local beforeList = self.mainSceneLevelMap[UBFLevelSceneType.kMain] or {}
    local hideBeforeList = self.mainSceneLevelMap[UBFLevelSceneType.kHide] or {}
    for _, levelId in ipairs(beforeList) do
        table.insert(levelNodeNeedReset, levelId)
    end
    for _, levelId in ipairs(hideBeforeList) do
        table.insert(levelNodeNeedReset, levelId)
    end
    self.mainSceneLevelMap = {}
    for _, levelId in ipairs(levelNodeNeedReset) do
        MainSceneEventCenter:dispatch(MainSceneEvent.View.RECREATE_LEVEL_NODE, {
            levelId = levelId,
            levelScene = UBFLevelSceneType.kMain,
        })
    end
    for _, levelId in ipairs(hideLevelNodeNeedReset) do
        MainSceneEventCenter:dispatch(MainSceneEvent.View.RECREATE_LEVEL_NODE, {
            levelId = levelId,
            levelScene = UBFLevelSceneType.kHide,
        })
    end

    -- 跨天打散成10min推荐关卡
    local delayTime = 0
    printx(33, "onActPassDay", delayTime)
    self.passDayRequestTimer = setTimeOut(function()
        if not self:isEnabled() then return end
        printx(33, "onActPassDay tryLightStart")
        self:tryLightStart()
    end, delayTime)
end

function Manager:cancelPassDayRequestTimer()
    if self.passDayRequestTimer then
        cancelTimeOut(self.passDayRequestTimer)
        self.passDayRequestTimer = nil
    end
end

function Manager:onActEnterMainScene(evt)
    if not FeatureSwitch:isOpen(FeatureSwitch.Type.STAR_WAND_BUFF) then return end
    local data = evt:getData()
    if data.firstEnter then
        if self.onEnterCondition then
            self.onEnterCondition:notify()
        end
    else
        self:tryLightStart()
        self:updateMainScene(true)
    end
end

function Manager:onActEnterStage2()
    if not self:isEnabled() then return end
    self:tryDoButtonCloudGuide()
end


function Manager:onActEnterStage3()
    if not self:isEnabled() then return end
    self:tryDoButtonCloudGuide()
end

function Manager:onSystemEnterForeground()
    if not self:isEnabled() then return end

end

function Manager:onSystemEnterBackground()
    if not self:isEnabled() then return end

end

function Manager:onFlowerCreate(evt)
    if not self:isEnabled() then return end
    local data = evt:getData()
    local levelId = data.levelId
    local levelScene = data.levelScene
    if UBFLevelSceneFunc:isMainLevel(levelScene) and self._userManager:getTopLevelId() < levelId then return end
    if not levelId or not levelScene then return end
    local levelIdList = self.mainSceneLevelMap[levelScene] or {}
    local levelNeedRecheckList = self.needRecheckLevelMap[levelScene] or {}

    local index = table.indexOf(levelNeedRecheckList, levelId)
    if index then
        table.remove(levelNeedRecheckList, index)
        self.needRecheckLevelMap[levelScene] = levelNeedRecheckList
    end

    if not table.exist(levelIdList, levelId) then
        return false
    end

    -- 非满级满星时 彩星关不展示
    local score = self._levelAreaManager:getUserScore( levelId, levelScene )
    local star = score and score.star or 0
    if self._userStateManager:getUserSegmentState() ~= _G.UserStateConst.UserSegmentState.MHZC and star == 4 then
        return
    end

    table.insert(data.dataList, {
        priority = FlowerConfig.Priority.STAR_WAND_BUFF,
        creator = function()
            -- 主线top关
            if UBFLevelSceneFunc:isMainLevel(levelScene) and self._userManager:getTopLevelId() == levelId and star == 0 then
                local key = "star_wand_top"
                local flower = data.pop(key)
                if not flower then
                    local TopFlower = require "amf.feature.fulllevel.starwandbuff.mainscene.TopFlower"
                    flower = TopFlower:create(levelId, levelScene)
                    flower.resKey = key
                    flower:setName(key)
                    data.add(flower)
                end
                return flower
            else
                -- 主线非top关&&隐藏关
                local key = MainSceneConfig:getFlowerKey(levelId, levelScene)
                local flower = data.pop(key)
                if not flower then
                    local NormalFlower = require "amf.feature.fulllevel.starwandbuff.mainscene.NormalFlower"
                    flower = NormalFlower:create(levelId, levelScene)
                    flower.resKey = key
                    flower:setName(key)
                    data.add(flower)
                end
                return flower
            end
        end
    })
end

function Manager:onMoveTrunkToEnd(event)
    self:updateMainSceneTip({
        forceHide = false,
    })
    self:updateMainSceneTipPos()
end

function Manager:onFarmLevelGetPanelAssetList(evt)
    local assetList = evt:getData()
    if not self:isEnabled() then return end
    self:log("onFarmLevelGetPanelAssetList", assetList)
    local list = {
        "amf/fulllevel/starwandbuff/texture/StarWandView.plist"
    }

    for i, v in ipairs(list) do
        table.insert(assetList, v)
    end

    for i, module in ipairs(self.modules) do
        if module:isOpen() then
            local farmLevelPanelParams = module:getFarmLevelPanelParams()
            local actAssetList = farmLevelPanelParams and farmLevelPanelParams.assetList or {}
            for j, v in ipairs(actAssetList) do
                table.insert(assetList, v)
            end
        end
    end
end

-- 补星/刷分面板插入补星权杖tab
function Manager:onFarmLevelPanelTabCreate(evt)
    local data = evt:getData()
    if not self:isEnabled() then return end
    if not self:isValid() then return end
    if data.type == FarmConst.FarmLevelPanelType.kFarmStar then
        local configList = data.configList
        table.insert(configList, {
            tag = FarmConst.FarmStarTag.STAR_WAND_BUFF,
            tabIdx = 1,
            tabCreator = function()
                self:log("FarmLevelPanelTabCreator")
                local FarmLevelPanelTab = require "amf.feature.fulllevel.starwandbuff.view.FarmLevelPanelTab"
                return FarmLevelPanelTab:getFarmStarPanelTab(FarmConst.FarmStarTag.STAR_WAND_BUFF)
            end,
        })
    elseif data.type == FarmConst.FarmLevelPanelType.kFarmScore then
        local configList = data.configList
        table.insert(configList, {
            tag = FarmConst.FarmScoreTag.STAR_WAND_BUFF,
            tabIdx = 1,
            tabCreator = function()
                self:log("FarmLevelPanelTabCreator")
                local FarmLevelPanelTab = require "amf.feature.fulllevel.starwandbuff.view.FarmLevelPanelTab"
                return FarmLevelPanelTab:getFarmStarPanelTab(FarmConst.FarmScoreTag.STAR_WAND_BUFF)
            end,
        })
    end
end

-- 补星面板切到补星权杖页
function Manager:onFarmLevelPanelChangeTab(evt)
    local data = evt:getData()
    if not self:isEnabled() then return end
    local type = data.type
    local tag = data.tag
    local parentView = data.view
    local needShow = (type == FarmConst.FarmLevelPanelType.kFarmStar and tag == FarmConst.FarmStarTag.STAR_WAND_BUFF)
        or (type == FarmConst.FarmLevelPanelType.kFarmScore and tag == FarmConst.FarmScoreTag.STAR_WAND_BUFF)
    printx(33, "onFarmLevelPanelChangeTab", type, tag, needShow)
    if parentView.blockTabs then
        parentView.blockTabs:setVisible(not needShow)
    end
    if parentView.arrowIcon then
        parentView.arrowIcon:setVisible(not needShow)
    end
    parentView.bg3:setVisible(not needShow)
    parentView.npcNode:setVisible(not needShow)
    if parentView.starWandTopUIBack then
        parentView.starWandTopUIBack:setVisible(needShow)
    end
    if parentView.starWandTopUIFront then
        parentView.starWandTopUIFront:setVisible(needShow)
    end
    if needShow then
        if not self.farmLevelPanelView or self.farmLevelPanelView.isDisposed then
            self.farmLevelPanelView = self:createFarmLevelPanelView(type)
            self.farmLevelPanelView:setPositionXY(13, -136)
            parentView.ui:addChild(self.farmLevelPanelView)
        end
        self.farmLevelPanelView:setVisible(true)
        self.farmLevelPanelView:updateView()
        self:dcClickIcon(3)
    else
        if self.farmLevelPanelView and not self.farmLevelPanelView.isDisposed then
            self.farmLevelPanelView:setVisible(false)
        end
    end
end

function Manager:onFarmLevelPanelCreateTopUI(evt)
    local data = evt:getData()
    if not self:isValid() then return end
    local panel = data.panel
    local uiData = require "amf.feature.fulllevel.starwandbuff.view.uisource.StarWandView_UI"
    local builder = UIBuilder.new(uiData)
	local back = builder:createChild( "backNode" )
	local front = builder:createChild( "frontNode" )
    local posToUi = panel.npcNode:getPosition()
	back:setPosition( ccp( posToUi.x + 11, posToUi.y + 150 ) )
	panel.ui:addChildAt( back, 1)
	back.refCocosObj:setZOrder( -10 )
    if back and back.mbMap and back.mbMap.speak then
        back.mbMap.speak:setScale(0)
    end
	front:setPosition( ccp( posToUi.x + 60, posToUi.y + 22 ) )
	panel.ui:addChild( front )
	panel.starWandTopUIBack = back
	panel.starWandTopUIFront = front
    panel.starWandPanelTipCreator = function(onCountDownStop)
        for _, module in ipairs(self.modules) do
            if module:isOpen() then
                local params = module:getFarmLevelPanelParams()
                if params and params.farmPanelTipCreator then
                    return params.farmPanelTipCreator(onCountDownStop)
                end
            end
        end
    end
end

function Manager:createFarmLevelPanelView(type)
    local FarmLevelPanelView = require "amf.feature.fulllevel.starwandbuff.view.FarmLevelPanelView"
    local farmLevelPanelView = FarmLevelPanelView:create({
        type = type
    })
    return farmLevelPanelView
end

----------------------- 加道具 -----------------------------
function Manager:getDcFeatureAndSource(suffix)
    suffix = suffix or 0
    return "activity", "act_" .. Manager.ACT_ID .. "_" .. tostring(suffix)
end

-- 检测是普通的还是特殊的
function Manager:_checkIsSpecialItem(rewardItem)
    local itemId = rewardItem.itemId
    -- 购买的话，会自动帮你加items里配的普通道具，特殊道具需要自己加（除了10001~19999，2，14都是特殊道具）
    if self._propManager:isPropNeedToBeAdd(itemId) then return false end
    if itemId == UPropId.GOLD or itemId == UPropId.COIN then return false end

    return true
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
    else
        dcFeature, dcSource = self:getDcFeatureAndSource(params and params.DCSourceExt or nil)
    end

    for i, v in ipairs(rewardItems) do
        if self:_checkIsSpecialItem(v) then
            -- todo 加特殊道具
        end
    end

    local fromBought = params and params.fromBought or nil
    if not fromBought then
        _G.GainPropData:create()
            :setFeature(dcFeature)
            :setSource(dcSource)
            :setProps(rewardItems)
            :execute()
    end
end

---------------------------------- 业务逻辑,新增函数都写在此后 ----------------------------------
-- 登录后拉一次
function Manager:tryLightStart()
    self:log("tryLightStart")
    if not self:getModel():isInActTime() then
        self:log("light start not in act time")
        return
    end

    if self._userStateManager:isFMJ() then
        self:log("light start is FMJ")
        return
    end

    if self.hasLightStart then return end
    if self.isDoingLightStart then return end
    self.isDoingLightStart = true
    self:cancelPassDayRequestTimer()
    local function onSuccess()
        self.isDoingLightStart = false
        self.hasLightStart = true
        for _, module in ipairs(self.modules) do
            safeRunCall(module.onStarWandBuffReady, module)
        end
        if self.onEnterCondition then
            self.onEnterCondition:notify()
        end
        self:log("light start success")
    end
    local function onFail()
        self.isDoingLightStart = false
    end
    self:doFetchMainInfo(onSuccess, onFail, true)
end

-- 手动触发的主info获取 包括大藤蔓的按钮 打开补星面板等
function Manager:manualStart(successCallback, failCallback)
    if not self:isEnabled() then
        safeRunCall(failCallback)
        return
    end
    self:cancelPassDayRequestTimer()
    self:doFetchMainInfo(successCallback, failCallback)
end

-- 获取主info 若今天未推荐过新关，同时推荐一下
function Manager:doFetchMainInfo(successCallback, failCallback, fromLightStart)
    local d
    local triggerTime = self:getModel():getDataByKey("triggerTime", 0)
    local ts = TimeKit:timeInSec()
    -- 以下规则停用 非满级的情况下不显示权杖
    -- -- 登录时如果今天已经推荐过 非满级的情况下表示可能是今天开了新关 数据直接读缓存
    -- if fromLightStart and getDayStartTimeByTS(triggerTime) == getDayStartTimeByTS(ts) and self._userStateManager:isFMJ() then
    --     d = deferred.success()
    -- elseif self._userStateManager:isFMJ() then
    --     self:log("light start is FMJ")
    --     d = deferred.error()
    -- else
        d = self:getModel():requestFetchMainInfo({configVersion = self:getModel():getDataByKey("configVersion", 0)})
        :next(function()
                return deferred.success()
            end,
            function(response)
                if not fromLightStart and not response:isCancel() then
                    CommonTip:showErrorTip(response)
                end
                local d = deferred.new()
                d:reject()
                return d
            end)
    -- end
    d:next(function()
        return self:loadRes()
    end)
    :next(function(response)
            local d = deferred.new()
            self:log("doFetchMainInfo success")
            if not self.onFirstEnabled then
                self.onFirstEnabled = true
                self:onEnabled()
            end
            if not self:isEnabled() then return end
            if self:checkTodayHasRecommend() then
                self:log("doFetchMainInfo today has recommend")
                self:updateLevelMapForMainScene()
                self:updateMainScene()
                d:resolve()
                return d
            end
            self:tryRecommendLevels(fromLightStart, function(successAll)
                self:log("doFetchMainInfo recommendLevels success", successAll)
                d:resolve()
            end)
            return d
        end)
    :next(function()
        -- 拉一下后端引导标记
        local ActCommonHttp = require 'amf.middleware.activity.http.ActCommonHttp'
        local d = deferred.new()
        ActCommonHttp:getActGuideFlag(Manager.ACT_ID):next(function(response)
            local data = response:getData()
            local guide = data.guide or {}
            self:getModel():setGuideDataFromServer(guide)
            d:resolve()
        end, function(response)
            d:resolve()
        end)
        return d
    end)
    :next(function()
            safeRunCall(successCallback)
        end, function()
            safeRunCall(failCallback)
        end)
end

function Manager:tryDoButtonCloudGuide()
    printx(33, "StarWandBuffManager:tryDoButtonCloudGuide")
    if self:getGuideFlag(Manager.GuideFlag.kButtonCloud) then
        return
    end
    if _G.amfBean("MainSceneButtonManager"):isFullLevelEnabled() then
        return
    end
	local curScene = Director:sharedDirector():getRunningScene()
	if not curScene or not curScene:isScene("MainScene") then
        return
    end
    if not self.mainSceneCloudBtn or self.mainSceneCloudBtn.isDisposed or not self.mainSceneCloudBtn:isVisible() then
        return
    end
    if not self:checkNeedShowMainSceneCloudBtn() then
        return
    end
    printx(33, "StarWandBuffManager:tryDoButtonCloudGuide do guide")
    local function onHandleOver()
		AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.STARWANDBUFF_GUIDE)
	end
    _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.STARWANDBUFF_GUIDE, function()
        self:playButtonGuide(false, onHandleOver)
    end)
end

function Manager:loadRes()
    local fileList = {
        "amf/fulllevel/starwandbuff/texture/StarWandFlower.plist",
        "amf/fulllevel/starwandbuff/texture/cloudBtnIcon.png",
    }
    local d = deferred.new()
    if EnvUtil:isWindows() then
        self.filesLoaded = true
        d:resolve()
    else
        _G.amfBean("AssetsUtil"):loadMiniFiles(fileList):next(function()
            self.filesLoaded = true
            d:resolve()
        end, function()
            d:reject()
        end)
    end
    return d
end

function Manager:getGuideFlag(flag)
    return self:getModel():getGuideFlag(flag)
end

function Manager:setGuideFlag(flag)
    self:getModel():setGuideFlag(flag)
    local ActCommonHttp = require 'amf.middleware.activity.http.ActCommonHttp'
    ActCommonHttp:setActGuideFlag(Manager.ACT_ID, flag)
end

--缓存所有可用权杖的关卡 useTime或推荐关变化时更新
function Manager:updateLevelMapForMainScene()
    local recommendLevelIdMap = self:getModel():getDataByKey("recommendLevelIdMap", {}, false)
    local recommendLevelUseMap = self:getModel():getDataByKey("recommendLevelUseMap", {}, false)
    -- 非满黄紫彩用户满星关卡不能用补星权杖  满黄紫彩推荐刷分关要显示补星权杖
    --2025.11.14新发现 原APP的逻辑好奇怪，上一行的逻辑在关卡花上不显示，但是关卡内能用
    -- 所以这里筛选出来的实际是还有剩余次数的已推荐关卡，满黄紫彩的用户需要筛选的自己单独去判断吧
    local isMHZC = self._userStateManager:isMainStarFull() and self._userStateManager:isColorfulStarFull() and self._userStateManager:isHideStarFull()
    local canPlayTopLevel = _G.amfBean("LevelUnLockManager"):getCanPlayTopLevel()
    local levelMap = {}
    local function geneLevelMap()
        for key, levelTable in pairs(recommendLevelIdMap) do
            local module = self:getModuleByKey(key)
            -- printx(33, "updateLevelMapForMainScene key:", key, "module:", module and module:isOpen())
            if module and module:isOpen() then
                local totalTime = module:getPerLevelTime()
                local usedTime = recommendLevelUseMap[key] or {}
                for levelScene, levelIds in pairs(levelTable) do
                    for _, levelId in ipairs(levelIds) do
                        if totalTime > (usedTime[levelScene] and usedTime[levelScene][levelId] or 0) then
                            if not levelMap[levelScene] then
                                levelMap[levelScene] = {}
                            end
                            -- if isMHZC then
                                table.insert(levelMap[levelScene], levelId)
                            -- else
                            --     local score = self._levelAreaManager:getUserScore(levelId, levelScene)
                            --     local star = score and score.star or 0
                            --     if (UBFLevelSceneFunc:isMainLevel(levelScene) and star < 4)
                            --     or (UBFLevelSceneFunc:isHideLevel(levelScene) and star < 3) then
                            --         table.insert(levelMap[levelScene], levelId)
                            --     end
                            -- end
                        end
                    end
                end
            end
        end
    end
    if not self._userStateManager:isFMJ() then
        geneLevelMap()
    end


    local scoreCacheList = {
        [UBFLevelSceneType.kMain] = {},
        [UBFLevelSceneType.kHide] = {},
    }
    local needRecheckLevelMap = {}
    local function getLevelScore(levelId, levelScene)
        if not scoreCacheList[levelScene][levelId] then
            local score = self._levelAreaManager:getUserScore(levelId, levelScene)
            local star = score and score.star or 0
            scoreCacheList[levelScene][levelId] = star
        end
        return scoreCacheList[levelScene][levelId]
    end

    local function genList(levelScene)
        table.sort(levelMap[levelScene] or {}, function(a, b)
            local star1 = getLevelScore(a, levelScene)
            local star2 = getLevelScore(b, levelScene)
            if star1 == star2 then
                return a < b
            else
                return star1 < star2
            end
        end)
        local diffList = self.needRecheckLevelMap[levelScene] or {}
        local lastList = self.mainSceneLevelMap[levelScene] or {}
        for index, levelId in ipairs(lastList) do
            if not table.exist(levelMap[levelScene] or {}, levelId) and not table.exist(diffList, levelId) then
                table.insert(diffList, levelId)
            end
        end

        self.needRecheckLevelMap[levelScene] = diffList
    end

    genList(UBFLevelSceneType.kMain)
    genList(UBFLevelSceneType.kHide)

    self.mainSceneLevelMap = levelMap
end

function Manager:checkTodayHasRecommend()
    return self:getModel():getDataByKey("recommended", false)
end

-- 前端尝试推关卡
function Manager:tryRecommendLevels(silent, callback)
    if not self:isEnabled() then
        if callback then callback() end
        return
    end
    local needNum = 0
    local doneNum = 0
    local asyncRunner = AsyncRunner:create()
    for i, module in ipairs(self.modules) do
        if module:isOpen() then
            needNum = needNum + 1
            asyncRunner:add(function(done)
                local recommendLevels = self:getModel():getAllRecommendLevels()
                module:doRecommendLevels(recommendLevels, silent, function(result)
                    doneNum = doneNum + 1
                    self:getModel():updateRecommendLevelByKey(module:getKey(), result, module:getPerLevelTime())
                    self:log("tryRecommendLevels:", module:getKey(), "result", result)
                    done()
                end, done)
            end)
        end
    end
    asyncRunner:add(function(done)
        self:updateLevelMapForMainScene()
        self:updateMainScene()
        self:dcCanyuLevel()
        safeRunCall(callback, doneNum >= needNum)
    end)
    asyncRunner:run()
end

-- 尝试推指定key活动的关卡
function Manager:tryRecommendLevelByKey(key, silent, callback)
    if not key then
        safeRunCall(callback, false)
        return
    end

    key = tostring(key)

    if not self:isEnabled() then
        safeRunCall(callback, false)
        return
    end

    local module = self:getModuleByKey(key)
    if not module then
        safeRunCall(callback, false)
        return
    end

    if self.sendingLevelsModuleKeys[key] then
        safeRunCall(callback, false)
        return
    end

    self.sendingLevelsModuleKeys[key] = true
    local recommendLevels = self:getModel():getAllRecommendLevels()
    module:doRecommendLevels(recommendLevels, silent, function(result)
        self:getModel():updateRecommendLevelByKey(key, result, module:getPerLevelTime())
        self:updateLevelMapForMainScene()
        self:updateMainScene()
        if self.farmLevelPanelView and not self.farmLevelPanelView.isDisposed then
            self.farmLevelPanelView:updateView()
        end
        self.sendingLevelsModuleKeys[key] = false
        safeRunCall(callback, true)
    end, function()
        self.sendingLevelsModuleKeys[key] = false
        safeRunCall(callback, false)
    end)
end

-- 刷新大藤蔓
function Manager:updateMainScene(ignoreAll)
	local curScene = Director:sharedDirector():getRunningScene()
	if not curScene or not curScene:isScene("MainScene") then
        return
    end

    if not ignoreAll then
        local mainLevelList = self.mainSceneLevelMap[UBFLevelSceneType.kMain] or {}
        for _, levelId in ipairs(mainLevelList) do
            MainSceneEventCenter:dispatch(MainSceneEvent.View.RECREATE_LEVEL_NODE, {
                levelId = levelId,
                levelScene = UBFLevelSceneType.kMain,
            })
        end
        local hideLevelList = self.mainSceneLevelMap[UBFLevelSceneType.kHide] or {}
        for _, levelId in ipairs(hideLevelList) do
            MainSceneEventCenter:dispatch(MainSceneEvent.View.RECREATE_LEVEL_NODE, {
                levelId = levelId,
                levelScene = UBFLevelSceneType.kHide,
            })
        end
    end


    for _, levelId in ipairs(self.needRecheckLevelMap[UBFLevelSceneType.kMain] or {}) do
        MainSceneEventCenter:dispatch(MainSceneEvent.View.RECREATE_LEVEL_NODE, {
            levelId = levelId,
            levelScene = UBFLevelSceneType.kMain,
        })
    end
    for _, levelId in ipairs(self.needRecheckLevelMap[UBFLevelSceneType.kHide] or {}) do
        MainSceneEventCenter:dispatch(MainSceneEvent.View.RECREATE_LEVEL_NODE, {
            levelId = levelId,
            levelScene = UBFLevelSceneType.kHide,
        })
    end

    if self:isValid() then
        self:addMainSceneTip()
    else
        self:removeMainSceneTip()
    end

    -- 满级云按钮
    -- _G.amfBean("RecommendLevelManager"):updateMainSceneCloudButton()
    local CloudEventCenter = require"amf.feature.mainscene.module.cloud.event.CloudEventCenter"
    CloudEventCenter:dispatch(CloudEventConst.TOP_DOWN_PART_UDPATE)
    local MainSceneButtonEventCenter = require "amf.feature.mainscenebutton.event.MainSceneButtonEventCenter"
    MainSceneButtonEventCenter:dispatch(MainSceneButtonEvent.UPDATE)
end

-- 补星面板获取权杖关
function Manager:getRecommendLevelsForFarmLevelPanel()
    return self:getModel():getRecommendLevelsForFarmLevelPanel()
end

function Manager:checkNeedShowMainSceneCloudBtn()
    if not self:isEnabled() then return false, self.onFirstEnabled end
    local useMap = self:getCanUseRecommendLevelsCareFullStar() or {}
    local mainRecommend = #(useMap[UBFLevelSceneType.kMain] or {})
    local hideRecommend = #(useMap[UBFLevelSceneType.kHide] or {})
    if mainRecommend + hideRecommend > 0 then
        return true, self.onFirstEnabled
    else
        return false, self.onFirstEnabled
    end
    return false, self.onFirstEnabled
end

function Manager:updateMainSceneCloudBtn(btn, scaleMode)
    if not btn or btn.isDisposed then return end
    local btnStr, btnFunc
    local isMHZC = self._userStateManager:isMainStarFull() and self._userStateManager:isColorfulStarFull() and self._userStateManager:isHideStarFull()
    if isMHZC then
        btnStr = "  去权杖关刷分"
    else
        btnStr = "  去权杖关补星"
    end

    local useMap = self:getCanUseRecommendLevelsCareFullStar() or {}

    local mainRecommend = #(useMap[UBFLevelSceneType.kMain] or {})
    local hideRecommend = #(useMap[UBFLevelSceneType.kHide] or {})
    local totalNum = mainRecommend + hideRecommend
    local function openStartGamePanel(levelId, levelScene)
        local playLevelContext = PlayLevelContext.new(levelId, PlayLevelContext.PlayType.OPEN_SL_PANEL)
        :setLevelScene(levelScene)
        :setTrunkInsight(true)
        _G.amfTransaction(TransactionEvent.PLAY_LEVEL, playLevelContext)
    end
    btn:update({
        str = btnStr,
        scaleMode = UIButtonConfig.BtnScales.k50,
        widthMode = UIButtonConfig.Widths.kLong,
        fontSizeFixed = true,
        touchFunc = function()
            local levelId, levelScene = self:getNextRecommendLevelForBtn()
            printx(33, "main scene cloud btn click", levelId, levelScene)
            if levelId then
                if not self:getGuideFlag(Manager.GuideFlag.kButtonCloud) then
                    self:playButtonGuide(true)
                else
                    openStartGamePanel(levelId, levelScene)
                end
                DcUtil:UserTrack({
                    category = "full_level_optimize",
                    sub_category = "vine_click",
                    t1 = isMHZC and 4 or 1
                })
                self:dcClickIcon(1)
            end
        end,
        redDot = totalNum > 0 and totalNum or nil,
    })
    self.mainSceneCloudBtn = btn
    if not self.hasDcQualify then
        self:dc("canyu", "qualify", 1)
        self.hasDcQualify = true
    end
end

function Manager:getNextRecommendLevelForBtn()
    local mainRecommendLevels = self.mainSceneLevelMap[UBFLevelSceneType.kMain] or {}
    local hideRecommendLevels = self.mainSceneLevelMap[UBFLevelSceneType.kHide] or {}

    local isMHZC = self._userStateManager:getUserSegmentState() == _G.UserStateConst.UserSegmentState.MHZC
    for i, v in ipairs(mainRecommendLevels) do
        local score = self._levelAreaManager:getUserScore( v, UBFLevelSceneType.kMain )
        local star = score and score.star or 0
        if isMHZC then
            return v, UBFLevelSceneType.kMain
        else
            if star < 4 then
                return v, UBFLevelSceneType.kMain
            end
        end
    end
    for i, v in ipairs(hideRecommendLevels) do
        local score = self._levelAreaManager:getUserScore( v, UBFLevelSceneType.kHide )
        local star = score and score.star or 0
        if isMHZC then
            return v, UBFLevelSceneType.kHide
        else
            if star < 3 then
                return v, UBFLevelSceneType.kHide
            end
        end
    end

    -- 保底
    local levelId, levelScene
    if mainRecommendLevels[1] then
        levelId = mainRecommendLevels[1]
        levelScene = UBFLevelSceneType.kMain
    elseif hideRecommendLevels[1] then
        levelId = hideRecommendLevels[1]
        levelScene = UBFLevelSceneType.kHide
    end
    return levelId, levelScene
end
--------------------------- 大藤蔓跳转tip -------------------------
function Manager:getTipCurLevel()
    if self.mainSceneLevelMap and not table.isEmpty(self.mainSceneLevelMap) then
        local visableArea = _G.fullScreenSizeManager:getVisibleArea()
        local minY = visableArea.y
        local maxY = visableArea.y + visableArea.height + 150
        -- 有主线引导主线
        for i, levelId in ipairs(self.mainSceneLevelMap[UBFLevelSceneType.kMain] or {}) do
            local nodePos = LevelNodePosConfig:getFlowerPositionInWorldSpace(levelId)
            if nodePos.y > minY and nodePos.y < maxY then
                -- 在可视区域内不提示
            else
                local score = self._levelAreaManager:getUserScore(levelId, UBFLevelSceneType.kMain)
                local star = score and score.star or 0
                return levelId, UBFLevelSceneType.kMain
            end
        end
        -- 没有主线引导隐藏关
        for i, levelId in ipairs(self.mainSceneLevelMap[UBFLevelSceneType.kHide] or {}) do
            local nodePos = LevelNodePosConfig:getHiddenFlowerPositionInWorldSpace(levelId)
            if nodePos.y > minY and nodePos.y < maxY then
                -- 在可视区域内不提示
            else
                local score = self._levelAreaManager:getUserScore(levelId, UBFLevelSceneType.kHide)
                local star = score and score.star or 0
                return levelId, UBFLevelSceneType.kHide
            end
        end
        -- 都没有引导最低可补星关
    end
end

-- 获取tip展示状态 1:关卡花在当前屏幕上方 0:不显示 -1:在当前屏幕下方
function Manager:getTipState(levelId, levelScene)
    local pos = ccp(0, 0)
    if not levelId or not levelScene then
        return 0, pos
    end
    local visableArea = _G.fullScreenSizeManager:getVisibleArea()
    local minY = visableArea.y
    local maxY = visableArea.y + visableArea.height

    -- 出现满级云时不展示
    local topLevelId = _G.amfBean("LevelUnLockManager"):getCanPlayTopLevel()
    local topPos = LevelNodePosConfig:getFlowerPositionInWorldSpace(topLevelId)
    if topPos.y+300 < maxY then
        return 0, pos
    end

    if levelScene == UBFLevelSceneType.kMain then
        pos = LevelNodePosConfig:getFlowerPositionInWorldSpace(levelId)
    elseif levelScene == UBFLevelSceneType.kHide then
        pos = LevelNodePosConfig:getHiddenFlowerPositionInWorldSpace(levelId)
    end
    if pos.y < minY then
        -- 在下方避让大藤蔓按钮
        if self._mainSceneButtonManager:isEnabled() then
            return 0, pos
        else
            return -1, pos
        end
    elseif pos.y > maxY+150 then
        if self._sceneTopBannerHandler:hasTopBannerShow() then
            -- 在上方时避让区域满级小记
            return 0, pos
        else
            return 1, pos
        end
    else
        return 0, pos
    end
end

function Manager:onMainSceneTipCreate()
    MainSceneEventCenter:addNodeToParallax(self.mainSceneTip, TrunkLayerConst.Layer.UNMOVED_FRONT)
    MainSceneEventCenter:register(MainSceneEvent.ScrollerEvents.VERTICAL_SCROLL_START, self.onMainSceneScorllStart, self)
    MainSceneEventCenter:register(MainSceneEvent.ScrollerEvents.VERTICAL_SCROLL_STOPPED, self.onMainSceneScrollStopped, self)
    MainSceneEventCenter:register(MainSceneEvent.ScrollerEvents.HORIZONTAL_SCROLL_START, self.onMainSceneScrollToHideBranch, self)
    MainSceneEventCenter:register(MainSceneEvent.ScrollerEvents.HORIZONTAL_SCROLL_TO_ORIGIN, self.onMainSceneScrollBackToCenter, self)
    SceneTopBannerEventCenter:register(SceneTopBannerEvent.TOPBANNER_SHOW, self.onAreaStarInfoNodeVisibleUpdate, self)
    SceneTopBannerEventCenter:register(SceneTopBannerEvent.TOPBANNER_HIDE, self.onAreaStarInfoNodeVisibleUpdate, self)
end

function Manager:onMainSceneTipDispose()
    MainSceneEventCenter:unregister(MainSceneEvent.ScrollerEvents.VERTICAL_SCROLL_START, self.onMainSceneScorllStart)
    MainSceneEventCenter:unregister(MainSceneEvent.ScrollerEvents.VERTICAL_SCROLL_STOPPED, self.onMainSceneScrollStopped)
    MainSceneEventCenter:unregister(MainSceneEvent.ScrollerEvents.HORIZONTAL_SCROLL_START, self.onMainSceneScrollToHideBranch)
    MainSceneEventCenter:unregister(MainSceneEvent.ScrollerEvents.HORIZONTAL_SCROLL_TO_ORIGIN, self.onMainSceneScrollBackToCenter)
    SceneTopBannerEventCenter:unregister(SceneTopBannerEvent.TOPBANNER_SHOW, self.onAreaStarInfoNodeVisibleUpdate)
    SceneTopBannerEventCenter:unregister(SceneTopBannerEvent.TOPBANNER_HIDE, self.onAreaStarInfoNodeVisibleUpdate)
end

function Manager:addMainSceneTip()
    if not self.mainSceneTip and not self._isInTipProcess then
        self._isInTipProcess = true
        _G.amfBean("AssetsUtil"):loadMiniFiles({
            "amf/fulllevel/starwandbuff/texture/NewTip.plist"
        }):next(function()
            self._isInTipProcess = false
            local curLevelId, curLevelScene = self:getTipCurLevel()
            local state = self:getTipState(curLevelId, curLevelScene)
            local MainSceneTip = require "amf.feature.fulllevel.starwandbuff.mainscene.MainSceneTip"
            self.mainSceneTip = MainSceneTip:create({
                levelId = curLevelId,
                levelScene = curLevelScene,
                tipType = "StarWand",
                direction = state == 1 and "up" or "down",
            })
            self:updateMainSceneTipPos()
            self:onMainSceneTipCreate()
        end, function()
            self._isInTipProcess = false
        end)
    end
    self:updateMainSceneTipPos()
end

function Manager:onAreaStarInfoNodeVisibleUpdate(evt)
    printx(33, "StarWandBuffManager:onAreaStarInfoNodeVisibleUpdate")
    self:updateMainSceneTipPos()
end

function Manager:onMainSceneScorllStart(evt)
    self:updateMainSceneTip({
        forceHide = true,
    })
    self:updateMainSceneTipPos()
end

function Manager:onMainSceneScrollStopped(evt)
    self:updateMainSceneTip({
        forceHide = false,
    })
    self:updateMainSceneTipPos()
end

function Manager:onMainSceneScrollToHideBranch()
    self:updateMainSceneTip({
        forceHide = true,
    })
    self:updateMainSceneTipPos()
end

function Manager:onMainSceneScrollBackToCenter()
    self:updateMainSceneTip({
        forceHide = false,
    })
    self:updateMainSceneTipPos()
end

function Manager:removeMainSceneTip()
    if self.mainSceneTip and not self.mainSceneTip.isDisposed then
        self.mainSceneTip:removeFromParentAndCleanup(true)
        self.mainSceneTip = nil
    end
    self:onMainSceneTipDispose()
end

function Manager:getTipPositionY(state)
    local visableArea = _G.fullScreenSizeManager:getSafeArea()
    if state == 1 then
        return visableArea.y + visableArea.height - 130
    elseif state == -1 then
        return visableArea.y + 180
    end
end

function Manager:getTipPositionX(x)
    local visableArea = _G.fullScreenSizeManager:getSafeArea()
    return math.max(visableArea.x + 160, math.min(visableArea.x + visableArea.width - 160, x))
end

function Manager:updateMainSceneTipPos()
    if self.mainSceneTip and not self.mainSceneTip.isDisposed then
        local curLevelId, curLevelScene = self:getTipCurLevel()
        local state, pos = self:getTipState(curLevelId, curLevelScene)
        if state == 0 then
            self.mainSceneTip:setVisible(false)
        else
            self.mainSceneTip:setVisible(true)
            local x = self:getTipPositionX(pos.x)
            local y = self:getTipPositionY(state)
            self.mainSceneTip:setPositionXY(x, y)
            self:updateMainSceneTip({
                levelId = curLevelId,
                levelScene = curLevelScene,
                direction = state == 1 and "up" or "down",
            })
        end
    else
        self:removeMainSceneTip()
    end
end

function Manager:updateMainSceneTip(delegate)
    if self.mainSceneTip and not self.mainSceneTip.isDisposed then
        self.mainSceneTip:refreshView(delegate)
        if delegate.forceHide == true then
            self.mainSceneTip:setForceHide(true)
        elseif delegate.forceHide == false then
            self.mainSceneTip:setForceHide(false)
        end
    end
end

function Manager:getAllRecommendLevels()
    return self:getModel():getAllRecommendLevels()
end

function Manager:getAllCanUseRecommendLevels()
    return self.mainSceneLevelMap
end

function Manager:getCanUseRecommendLevelsCareFullStar()
    if self._userStateManager:getUserSegmentState() == _G.UserStateConst.UserSegmentState.MHZC then
        return self:getAllCanUseRecommendLevels()
    end
    local lvsMain = self.mainSceneLevelMap[UBFLevelSceneType.kMain] or {}
    local lvsHide = self.mainSceneLevelMap[UBFLevelSceneType.kHide] or {}

    local canUseLvMain = {}
    local canUseLvHide = {}
    for k,v in ipairs(lvsMain) do
        local userScore = self._levelAreaManager:getUserScore(v, UBFLevelSceneType.kMain)
        if userScore and userScore.star < 4 then
            table.insert(canUseLvMain, v)
        end
    end

    for k,v in ipairs(lvsHide) do
        local userScore = self._levelAreaManager:getUserScore(v, UBFLevelSceneType.kHide)
        if userScore and userScore.star < 3 then
            table.insert(canUseLvHide, v)
        end
    end

    return {
        [UBFLevelSceneType.kMain] = canUseLvMain,
        [UBFLevelSceneType.kHide] = canUseLvHide
    }
end

function Manager:isLevelRecommend(level, levelScene)
    return self:isLevelRecommended(level, levelScene)
end

---------------------播放引导-------------------------------------------
function Manager:playButtonGuide(fromTouch, callback)
    printx(33, "StarWandBuffManager:playButtonGuide", fromTouch)
    if not self:isEnabled() then
        safeRunCall(callback)
        return
    end
	local curScene = Director:sharedDirector():getRunningScene()
	if not curScene or not curScene:isScene("MainScene") then
        safeRunCall(callback)
        return
    end
    if not self.mainSceneCloudBtn or self.mainSceneCloudBtn.isDisposed or not self.mainSceneCloudBtn:isVisible() then
        safeRunCall(callback)
        return
    end
    local configTopLevel = _G.amfBean("LevelUnLockManager"):getLocalTopLevel(false)

    local function startGuide()
        local contentList

        if fromTouch then
            contentList = {{
                ttf = "点击按钮会"
            }, {
                ttf = "直接打开权杖关卡",
                color = "00A5C8FF"
            }, {
                ttf = "哦！"
            }}
        else
            contentList = {{
                ttf = "解锁满级补星玩法！"
            }, {
                ttf = "点击按钮立刻打开",
                color = "00A5C8FF"
            }, {
                ttf = "权杖关卡！"
            }}
        end

        local part = self.mainSceneCloudBtn
        local HeGuide = require "amf.middleware.ui.kit.component.HeGuide"
        local heGuide = HeGuide:create(nil, true, nil, true)
        local function endCall(clickPos)
            if self.isDisposed then
                return
            end
            -- if part:hitTestPoint(clickPos) then
                safeRunCall(self.mainSceneCloudBtn.callback)
                safeRunCall(callback)
            -- else
                -- safeRunCall(callback)
            -- end
        end
        heGuide:setMaskOpacity(200)
        heGuide:setEndCall(endCall)
        local contentList = contentList
        heGuide:addAccurateGuide(heGuide, {part})
        local height = 200
        heGuide:showNpc2(contentList, height)
        heGuide:setKeyBackEnabled(curScene)
        self:setGuideFlag(Manager.GuideFlag.kButtonCloud)
    end
    local pos = self.mainSceneCloudBtn:convertToWorldSpace(ccp(220, 60))
    MainSceneEventCenter:dispatch(MainSceneEvent.Trunk.MOVE_TRUNK_TO, {
        levelId = configTopLevel,
        levelScene = UBFLevelSceneType.kMain,
        duration = 0,
        callback = function()
            startGuide()
        end
    })
end

function Manager:addTipGuide(callback)
	local curScene = Director:sharedDirector():getRunningScene()
	if not curScene or not curScene:isScene("MainScene") then
        safeRunCall(callback)
        return
    end
    if not self.mainSceneTip or self.mainSceneTip.isDisposed then
        safeRunCall(callback)
        return
    end
    local contentList = {{
        ttf = "点击tip可快速定位到补星关卡~"
    }}
    local part = self.mainSceneTip
    local HeGuide = require "amf.middleware.ui.kit.component.HeGuide"
    local heGuide = HeGuide:create(self.container, true, nil, true)
    heGuide:setMaskOpacity(200)
    heGuide:setEndCall(callback)
    local contentList = contentList
    heGuide:addAccurateGuide(heGuide, {part})
    heGuide:showNpc2(contentList, 500)
    heGuide:setKeyBackEnabled(curScene)
    self:setGuideFlag(Manager.GuideFlag.kFlowerTip)
end

function Manager:dcCanyuLevel()
    local recommendLevelIdMap = self:getModel():getDataByKey("recommendLevelIdMap", {}, false)
    local t1, t2, t3, t4
    local majorMainLevel = {}
    local majorHideLevel = {}
    local additionMainLevel = {}
    local additionHideLevel = {}
    for key, levelTable in pairs(recommendLevelIdMap) do
        local module = self:getModuleByKey(key)
        if module and module:isOpen() then
            if key == "MAJOR" then
                majorMainLevel = table.clone(levelTable[UBFLevelSceneType.kMain]) or {}
                majorHideLevel = table.clone(levelTable[UBFLevelSceneType.kHide]) or {}
            else
                for i, v in ipairs(levelTable[UBFLevelSceneType.kMain] or {}) do
                    table.insert(additionMainLevel, v)
                end
                for i, v in ipairs(levelTable[UBFLevelSceneType.kHide] or {}) do
                    table.insert(additionHideLevel, v)
                end
            end
        end
    end
    self:dc("canyu", "level", {
        t1 = table.concat(majorMainLevel, "_"),
        t2 = table.concat(majorHideLevel, "_"),
        t3 = table.concat(additionMainLevel, "_"),
        t4 = table.concat(additionHideLevel, "_"),
    })
end

function Manager:dcClickIcon(source)
    self:dc("click", "click_icon", {
        t1 = source
    })
end

function Manager:dcDayResult()
    local recommendLevelIdMap = self:getModel():getDataByKey("recommendLevelIdMap", {}, false)
    local recommendLevelUseMap = self:getModel():getDataByKey("recommendLevelUseMap", {}, false)
    local t1, t2, t3, t4
    local mainRecommend = #(self.mainSceneLevelMap[UBFLevelSceneType.kMain] or {})
    local hideRecommend = #(self.mainSceneLevelMap[UBFLevelSceneType.kHide] or {})
    t1 = mainRecommend + hideRecommend
    local noFourStarNum = 0
    local noThreeStarNum = 0
    local pairsTable = self.mainSceneLevelMap[UBFLevelSceneType.kMain] or {}
    for idx, levelId in ipairs(pairsTable) do
        local score = self._levelAreaManager:getUserScore(levelId, UBFLevelSceneType.kMain)
        if score then
            local star = score.star or 0
            if star < 4 then
                noFourStarNum = noFourStarNum + 1
            end
            if star < 3 then
                noThreeStarNum = noThreeStarNum + 1
            end
        end
    end
    t2 = noFourStarNum
    t3 = noThreeStarNum
    local date = os.date("*t", TimeKit:timeInSec())
    t4 = string.format("%4d:%02d:%02d", date.year, date.month, date.day)
    self:dc("canyu", "result", {
        t1 = t1,
        t2 = t2,
        t3 = t3,
        t4 = t4,
    })
end

return Manager
