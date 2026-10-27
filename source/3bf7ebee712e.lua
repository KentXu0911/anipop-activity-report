local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local deferred = require "amf.script.sugar.deferred"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"
local StellarConvergenceDC = require("amf.feature.localactivity.stellarconvergence.dc.StellarConvergenceDC")
local CircularTitle = require "amf.middleware.ui.kit.component.CircularTitle"
local MainSceneEventCenter = require 'amf.feature.mainscene.core.event.MainSceneEventCenter'
local Condition = require "amf.script.sugar.Condition"
local Manager = class("StellarConvergenceManager", BaseFeatureManager)

local __debug = false

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

function Manager:_getConstPath()
    return "amf.feature.localactivity.stellarconvergence.config.StellarConvergenceConst"
end

function Manager:_getModelPath()
    return "amf.feature.localactivity.stellarconvergence.model.StellarConvergenceModel"
end

function Manager:_getGroupPath()
    return "amf.feature.localactivity.stellarconvergence.config.StellarConvergenceGroup"
end

function Manager:_getDCPath()
    return "amf.feature.localactivity.stellarconvergence.dc.StellarConvergenceDC"
end

function Manager:_init()
    self._group = require(self:_getGroupPath())
    self._dc = require(self:_getDCPath())

    self:registerActProps()
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
    
    -- 过关炫耀强弹见 PassLevelShowOffModule 统一处理，不再在此注册
    -- MainSceneEventCenter:register(MainSceneEvent.Play.HANDLE_PASS_LEVEL, self.onHandleChangeLevel, self, MSP.PassLevel.STELLAR_CHANGE_LEVEL)
    
    self:tryloadRes()
    
    -- 校验并修复 curRankType 缓存（防止离线修改星级后缓存值过高）
    self:validateAndFixCurRankType(true)
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
end

-- 注册活动道具
function Manager:registerActProps()
    require("amf.feature.localactivity.stellarconvergence.prop.AMFProp_57248")
end

function Manager:isEnabled()
    if not self._group then
        return false
    end
    return self._group:isFeatureEnabled()
end

function Manager:isDebug()
    return __debug
end

function Manager:tryloadRes(successCallback, failCallback, cancelCallback)
    if self:isFullLevelLocal() then
        self:tryloadNormalRes(function ()
            self:tryloadFullLevelRes(successCallback, failCallback, cancelCallback)
        end, failCallback, cancelCallback)
    else
        self:tryloadNormalRes(successCallback, failCallback, cancelCallback)
    end
end

function Manager:tryloadNormalRes(successCallback, failCallback, cancelCallback)
    if self:isNormalResReady() then 
        safeRunCall(successCallback)
        return 
    end
    local function _onResReady()
        self._isNormalResReady = true
        safeRunCall(successCallback)
    end
    AssetsUtil:loadDynamicModule("meta/StellarConvergenceRes.xml", _onResReady, failCallback, cancelCallback)
end

function Manager:tryloadFullLevelRes(successCallback, failCallback, cancelCallback)
    if self:isFullLevelResReady() then 
        safeRunCall(successCallback)
        return 
    end
    local function _onResReady()
        self._isFullLevelResReady = true
        safeRunCall(successCallback)
    end
    AssetsUtil:loadDynamicModule("meta/StellarConvergenceFullLevelRes.xml", _onResReady, failCallback, cancelCallback)
end

function Manager:isResReady()
    if self:isFullLevelLocal() then
        return self:isNormalResReady() and self:isFullLevelResReady()
    else
        return self:isNormalResReady()
    end
end

function Manager:isNormalResReady()
    return self._isNormalResReady
end

function Manager:isFullLevelResReady()
    return self._isFullLevelResReady
end

function Manager:isDataEnabled()
    return self:isEnabled() and self:getModel():isDataEnabled()
end

function Manager:isPeriodEnabled()
    local period = self:getPeriod()
    if period <= 0 then
        return false
    end

    local curTime = TimeKit:timeInSec()
    local startTime = self:getStartTimeSec()
    local endTime = self:getLastEndTimeSec()
    if startTime <= 0 or endTime <= 0 then
        return false
    end

    return curTime >= startTime and curTime <= endTime
end

function Manager:updateData(data)
    self:getModel():assignData(data)
end

function Manager:getDC()
    return self._dc
end

function Manager:getGroup()
    return self._group
end

-------------------------------------- 封装 ----------------------------------
function Manager:addRewardsForShop(rewardDirectList, param, endCall, resOrEvt)
    self:callPlug("Rewards", "addRewardsForShop", rewardDirectList, param, endCall, resOrEvt)
end

function Manager:addRewardsNormal(rewards, params)
    self:callPlug("Rewards", "addRewardsNormal", rewards, params)
end

function Manager:openActivity(delegate)
    self:callPlug("Act", "openActivity", delegate)
end

function Manager:getActivityIcon()
    return self:callPlug("Act", "getActIcon")
end

function Manager:refreshActivityIcon(reason, icon)
    icon = icon or self:getActivityIcon()
    if not isSafeCocosObj(icon) then
        return false, icon
    end

    if type(icon.refreshProvider) == "function" then
        pcall(icon.refreshProvider, icon, reason)
        return true, icon
    end

    if type(icon.updateIcon) == "function" then
        pcall(icon.updateIcon, icon)
    end
    return false, icon
end

function Manager:updateTipView()
    return self:callPlug("Act", "updateTipView")
end

-------------------------------------- 协议 --------------------------------------
-- 星光宝盒领奖
function Manager:requestStarRewards(areaId, from)
    local promise = deferred.new()

    if areaId < 40000 then
        areaId = areaId + 40000
    end

    self:getModel():requestGetStarRewards({
        areaId = areaId
    }, false):next(function(response)
        local data = response:getData()

        _G.amfTransaction(TransactionEvent.EXCHANGE_SHOP_TASK, {
            subCmd = "addReward",
            subData = {
                rewardList = data.bean.rewardList,
                repeatList = data.bean.repeatList,
                rewardDirectList = data.bean.rewardDirectList,
                yuanBaoList = data.bean.yuanBaoList,
                feature = self:getDC().DCFeature,
                source = from == 'flaunt' and 'flaunt_reward' or "main_panel_reward",
                endCall = function(notCardMap, cardMap)
                    notCardMap = notCardMap or {}
                    if not table.isEmpty(notCardMap) then
                        self:addRewardsNormal(notCardMap, {
                            dcExtra = {
                                dcFeature = self:getDC().DCFeature,
                                dcSource = from == 'flaunt' and 'flaunt_reward' or "main_panel_reward"
                            }
                        })
                    end
                    promise:resolve({
                        callData = {
                            rewardList = data.bean.rewardList,
                            repeatList = data.bean.repeatList,
                            rewardDirectList = data.bean.rewardDirectList,
                            yuanBaoList = data.bean.yuanBaoList
                        }
                    })
                end
            }
        })

        self:updateTipView()
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response.errorCode)
        end
        promise:reject()
    end)

    return promise
end

function Manager:onActPassDay()
    self:_checkAndNotifyPassDayOnInit()
end

function Manager:passDayRefreshData()
    self:clearPositionTimes()
end

function Manager:hasReward()
    return self:getModel():checkCanGetRewardToday()
end

-------------------------------------- 事件 -------------------------------------------
function Manager:onActTestButtonReady(data)
	addGlobalTestButton("星光之域debug", function()
		__debug = not __debug
        CommonTip:showTip(__debug and "开启debug" or "关闭debug")
		return nil, true
	end, {
		TestButtonConst.Tags.ACTIVITY,
	})
end

function Manager:onActActInfoUpdate(event)
    if not self:isEnabled() then return end

    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(self:getConst().actId)]

    if not actInfo or not fromServer or not actInfo.extra then
        return
    end

    local extra = table.deserialize(actInfo.extra)
    if not extra or table.isEmpty(extra) then
        return
    end

    local periodId = extra.periodId
    local rank = extra.rank
    local fullLevel = extra.fullLevel

    self:getModel():setDataByKey("periodId", tonumber(periodId))
    local simpleFullLevelRankBean = self:getModel():getDataByKey("simpleFullLevelRankBean")
    if simpleFullLevelRankBean then
        self:getModel():setDataByKey("simpleFullLevelRankBean.rank", rank)
    end

    if fullLevel and fullLevel > 0 then
        self:getModel():setDataByKey("fullLevel", fullLevel)
    end

    -- 校验并修复 curRankType 缓存（防止离线修改星级后缓存值过高）
    self:validateAndFixCurRankType()

    local icon = self:getActivityIcon()
    if icon then
        self:updateTipView()
        if type(icon.refreshProvider) ~= "function" then
            self:refreshActivityIcon("actInfoUpdate", icon)
        end
    end
end

function Manager:onActOnlineUnlockOver()
    if not self:isEnabled() then
        return
    end

    self:getModel():setDataByKey("periodId", 0)
    local icon = self:getActivityIcon()
    if icon then
        self:updateTipView()
        if type(icon.refreshProvider) ~= "function" then
            self:refreshActivityIcon("onlineUnlockOver", icon)
        end
    end
end

function Manager:setFlyCollectContext()
    if not self:isEnabled() then return end
    if not self:isPeriodEnabled() then return end
    if not self:isFullLevel() then return end

    local lastPassLevelDataForIcon = self:getModel():getTempData("lastPassLevelDataForIcon")
    if not lastPassLevelDataForIcon then return end

    local starSp, starNum = nil, 0
    if UBFLevelSceneFunc:isMainLevel(lastPassLevelDataForIcon.levelScene) and lastPassLevelDataForIcon.star >
        lastPassLevelDataForIcon.oldStar then
        if lastPassLevelDataForIcon.star <= 3 then
            starSp = Sprite:createWithSpriteFrameName("other/iconV2/ui_icon_star_02_v2")
            starNum = lastPassLevelDataForIcon.star - lastPassLevelDataForIcon.oldStar
        else
            starSp = Sprite:createWithSpriteFrameName("other/iconV2/ui_icon_star_01_v2")
            starNum = 3
        end
    elseif UBFLevelSceneFunc:isHideLevel(lastPassLevelDataForIcon.levelScene) and lastPassLevelDataForIcon.star >
        lastPassLevelDataForIcon.oldStar and _G.amfBean("UserManager"):getColorfulStar() == self:getServerMaxLevel() * 3 then
        starSp = Sprite:createWithSpriteFrameName("other/iconV2/ui_icon_star_03_v2")
        starNum = lastPassLevelDataForIcon.star - lastPassLevelDataForIcon.oldStar
    elseif UBFLevelSceneFunc:isFullLevelLib(lastPassLevelDataForIcon.levelScene) and
        _G.amfBean("UserManager"):getHiddenStar() == (self:getServerMaxLevel() / 15 - 1) * 9 and self:isPeriodEnabled() then
        local mgr = _G.amfBean("FullStarLevelLibManager")
        local flag = mgr:getLevelDifficultFlagByLevelId(lastPassLevelDataForIcon.levelId)
        starSp = Sprite:createWithSpriteFrameName("other/iconV2/ui_icon_star_05_v2")
        starNum = mgr:isDifficultLevel(flag) and 3 or 1
    end

    if starSp then
        starSp:setScale(0.8)
        _G.amfTransaction(TransactionEvent.FLY_ACT_COLLECTIONS, FlyActCollectionContext.new(self:getConst().actId, {{
            icon = starSp,
            num = starNum
        }}))
    end

    self:getModel():setTempData("lastPassLevelDataForIcon", nil)
end

-- 过关更新数据
function Manager:onActPlayLevelEnd(event)
    local data = event:getData() or {}

    if not data.isWin then return end

    local saveData = {}
    saveData.levelId = data.levelId
    saveData.levelScene = data.levelScene
    saveData.oldStar = data.oldStar
    saveData.star = data.star
    saveData.areaId = self:getAreaIdByLevelId(data.levelId)

    -- 存储过关数据，用于记录数据变更
    if UBFLevelSceneFunc:isMainLevel(saveData.levelScene) and saveData.star > saveData.oldStar then
        self:getModel():setLocalCache("lastPassLevelData", saveData)
        self:getModel():setTempData("tenAreaStarData", nil)
    end

    self:getModel():setTempData("lastPassLevelDataForIcon", saveData)

    local currentYellowStarNum, currentColorStarNum = _G.amfBean("LevelAreaManager"):getYellowStarAndColorStarNum(
        saveData.areaId)
    local ts = TimeKit:timeInMillis()

    local areaLevelNum = self:getConst().AREA_LEVEL_NUM
    if _G.getTopPassedLevelId() == saveData.levelId and saveData.oldStar == 0 then
        if saveData.star > 0 then
            self:getModel():updateTenAreaPassTime(saveData.areaId, ts)
        end
    end

    if currentYellowStarNum == areaLevelNum * 3 then
        if saveData.oldStar < 3 then
            self:getModel():updateAreaFullYellowTime(saveData.areaId, ts)
        end
    end

    if currentColorStarNum == areaLevelNum * 3 then
        if saveData.oldStar < 4 then
            self:getModel():updateAreaFullColorTime(saveData.areaId, ts)
        end
    end

    self:setFlyCollectContext()

    self:tryloadRes()
end

-------------------------------------- 接口 -------------------------------------------
function Manager:checkHasGotReward(areaId)
    return self:getModel():checkHasGotReward(areaId)
end

function Manager:checkCanGetReward(areaId)
    return self:getModel():checkCanGetReward(areaId)
end

function Manager:getAreaPassTime(areaId)
    return self:getModel():getAreaPassTime(areaId)
end

function Manager:getAreaFullYellowTime(areaId)
    return self:getModel():getAreaFullYellowTime(areaId)
end

function Manager:getAreaFullColorTime(areaId)
    return self:getModel():getAreaFullColorTime(areaId)
end

function Manager:getTenAreaStarData(force, noNetwork)
    return self:getModel():getTenAreaStarData(force, noNetwork)
end

function Manager:getNebulaAreaStarData(force, noNetwork)
    return self:getModel():getNebulaAreaStarData(force, noNetwork)
end

function Manager:getNebulaAreaStarDataById(nebulaId, force, noNetwork)
    local nebulaAreaStarData = self:getModel():getNebulaAreaStarData(force, noNetwork)
    if not nebulaAreaStarData or not nebulaAreaStarData[nebulaId] then return end
    return nebulaAreaStarData[nebulaId]
end

function Manager:getCachedNebulaData()
    return self:getModel():getCachedNebulaData()
end

function Manager:getCachedNebulaDataById(nebulaId)
    local nebulaData = self:getCachedNebulaData()
    if not nebulaData or not nebulaData[nebulaId] then return end
    return nebulaData[nebulaId]
end

function Manager:setCachedNebulaData(data)
    self:getModel():setCachedNebulaData(data)
end

function Manager:setCachedNebulaDataById(data, nebulaId)
    local nebulaData = self:getCachedNebulaData() or {}
    nebulaData[nebulaId] = data
    self:setCachedNebulaData(nebulaData)
end

function Manager:getLastNebulaShowId()
    return self:getModel():getLastNebulaShowId()
end

function Manager:setLastNebulaShowId(showId)
    self:getModel():setLastNebulaShowId(showId)
end

function Manager:getStarState()
    return self:getModel():getStarState()
end

function Manager:setStarState(state)
    self:getModel():setStarState(state)
end

function Manager:getAreaIdByLevelId(levelId)
    return self:getModel():getAreaIdByLevelId(levelId)
end

function Manager:getScoreBuffTime()
    return tonumber(self:getModel():getDataByKey("infoBean.buffEndTime") or 0)
end

function Manager:addScoreBuffItem(num)
    if not self:isDataEnabled() then return end
    
    self:getModel():addScoreBuffItem(num)
    self:refreshStarButton()
end

function Manager:refreshStarButton()
    _G.amfEC:notifyNormal(NormalEvent.USER_ASSET_CHANGE)
end

function Manager:createBuffIcon()
    local item = Sprite:createWithSpriteFrameName("other/iconV2/ui_icon_star_02_v2")

    local scoreTitleLabel = TTFLabel:createAnimalYH('分数', 18)
    scoreTitleLabel:setTextColor(hex2ccc4('e6830cff'))
    scoreTitleLabel:setPositionXY(45, 85)
    item:addChild(scoreTitleLabel)

    local scoreLabel = TTFLabel:createAnimalYH('x130%', 18)
    scoreLabel:setPositionXY(27, 63)
    scoreLabel:setTextColor(hex2ccc4('e6830cff'))
    scoreLabel:enableOutline(hex2ccc4('ffffffff'), 2)
    item:addChild(scoreLabel)

    return item
end

function Manager:getCurrentLevelForIcon()
    local curLevel = self:getModel():getDataByKey("initStarLevel", 0) or 0
    if curLevel > 0 then
        curLevel = math.max(self:getModel():getDataByKey("simpleFullLevelRankBean.nowStarLevel", 0) or 0, curLevel)
    end
    
    -- 校验：实时计算当前星级，如果缓存值比实际值高，说明星级数据被修改了
    -- 只返回正确的图标等级，不更新缓存（缓存在 validateAndFixCurRankType 中统一处理）
    local realLevel = self:calCurRankType()
    if curLevel ~= realLevel then
        printx(50, "[StellarConvergenceManager] getCurrentLevelForIcon: cached level", curLevel, "is different from real level", realLevel, ", return real level for icon")
        curLevel = realLevel
    end
    
    return curLevel
end

-- 校验并修复 curRankType 缓存（在进入游戏时调用，确保缓存值不会比实际值高）
function Manager:validateAndFixCurRankType(forceSync)
    local cachedLevel = self:getCurRankType()
    local realLevel = self:calCurRankType()
    
    if forceSync then
        if cachedLevel ~= realLevel then
            printx(50, "[StellarConvergenceManager] validateAndFixCurRankType: force sync cached level from", cachedLevel, "to", realLevel)
            self:setCurRankType(realLevel)
        end
        return
    end

    if cachedLevel > realLevel then
        printx(50, "[StellarConvergenceManager] validateAndFixCurRankType: cached level", cachedLevel, "is different from real level", realLevel, ", fix cache")
        self:setCurRankType(realLevel)
    end
end

-- 检测引导标记
function Manager:hasGuideIndex(index)
    return self:getModel():hasGuide(index)
end

-- 设置引导标记
function Manager:addGuideIndex(index)
    self:getModel():setGuide(index)

    local ActCommonHttp = require 'amf.middleware.activity.http.ActCommonHttp'
    ActCommonHttp:setActGuideFlag(self:getConst().FeatureId, index)
end

function Manager:getServerMaxLevel()
    return self:getModel():getDataByKey("fullLevel", 0) or 0
end

function Manager:getLastPassLevelData()
    local data = self:getModel():getLocalCache("lastPassLevelData")
    self:clearLastPassLevelData()
    return data
end

function Manager:clearLastPassLevelData()
    self:getModel():setLocalCache("lastPassLevelData", nil)
end

-- 是否满级(本地)
function Manager:isFullLevelLocal()
    return _G.getTopPassedLevelId() == _G.amfBean("LevelUnLockManager"):getCanPlayTopLevel()
end

-- 是否满级
function Manager:isFullLevel()
    return _G.getTopPassedLevelId() == self:getServerMaxLevel()
end

-- 是否top-60
function Manager:isTopMinus60()
    local diff = self:getServerMaxLevel() - _G.getTopPassedLevelId()
    return diff <= 60 and diff > 0
end

-- 定位次数
function Manager:getPositionTimes()
    return self:getModel():getLocalCache("poisitionTimes") or 0
end

function Manager:addPositionTimes()
    local times = self:getPositionTimes()
    self:getModel():setLocalCache("poisitionTimes", times + 1)
end

function Manager:clearPositionTimes()
    self:getModel():setLocalCache("poisitionTimes", 0)
end

function Manager:getStartTimeSec()
    local peroidStatTime = self:getModel():getDataByKey("peroidStatTime", 0) or 0
    return math.floor(tonumber(peroidStatTime) / 1000)
end

function Manager:getLastEndTimeSec()
    local peroidEndTime = self:getModel():getDataByKey("peroidEndTime", 0) or 0
    return math.floor(tonumber(peroidEndTime) / 1000)
end

function Manager:getPeriod()
    local peroidId = self:getModel():getDataByKey("peroidId", -1) or -1
    return tonumber(peroidId)
end

function Manager:getMyRank()
    local rank = self:getModel():getDataByKey("simpleFullLevelRankBean.rank", 0) or 0
    return tonumber(rank)
end

function Manager:getNeedRankForUpAnim()
    local type = tostring(self:getModel():getDataByKey("simpleFullLevelRankBean.nowStarLevel", 0) or 0)
    local rank = self:getModel():getDataByKey("simpleFullLevelRankBean.rank", 0) or 0
    local period = tostring(self:getModel():getDataByKey("periodId", -1) or -1)

    local cacheRankForUpAnim = self:getModel():getLocalCache("cacheRankForUpAnim") or {}
    if cacheRankForUpAnim[period] and cacheRankForUpAnim[period][type] then
        return rank < cacheRankForUpAnim[period][type]
    end

    return false
end

function Manager:setRankForUpAnim()
    local type = tostring(self:getModel():getDataByKey("simpleFullLevelRankBean.nowStarLevel", 0) or 0)
    local rank = self:getModel():getDataByKey("simpleFullLevelRankBean.rank", 0) or 0
    local period = tostring(self:getModel():getDataByKey("periodId", -1) or -1)

    local cacheRankForUpAnim = self:getModel():getLocalCache("cacheRankForUpAnim") or {}
    cacheRankForUpAnim[period] = cacheRankForUpAnim[period] or {}
    cacheRankForUpAnim[period][type] = rank
    self:getModel():setLocalCache("cacheRankForUpAnim", cacheRankForUpAnim)
end

function Manager:resetMyRankAndTypeAndIcon()
    local simpleFullLevelRankBean = self:getModel():getDataByKey("simpleFullLevelRankBean", {}) or {}
    simpleFullLevelRankBean.rank = 0
    simpleFullLevelRankBean.nowStarLevel = 0
    self:getModel():setDataByKey("simpleFullLevelRankBean", simpleFullLevelRankBean)
    self:getModel():setDataByKey("initStarLevel", 0)
    local icon = self:getActivityIcon()
    if icon then
        self:updateTipView()
        if type(icon.refreshProvider) ~= "function" then
            self:refreshActivityIcon("rankReset", icon)
        end
    end
end

function Manager:getNeedCheckRankType()
    local initStarLevel = self:getModel():getDataByKey("initStarLevel", 0) or 0
    return initStarLevel <= 0
end

function Manager:getNeedChangeRankType()
    local initStarLevel = self:getModel():getDataByKey("initStarLevel", 0) or 0
    local curStarLevel = self:getModel():getDataByKey("simpleFullLevelRankBean.nowStarLevel", 0) or 0
    return initStarLevel > 0 and curStarLevel > initStarLevel
end

function Manager:resetInitLevel()
    local curStarLevel = self:getModel():getDataByKey("simpleFullLevelRankBean.nowStarLevel", 0) or 0
    if curStarLevel > 0 then
        self:getModel():setDataByKey("initStarLevel", curStarLevel)
    end
end

function Manager:getPopChangeType(rankType)
    local popChangeList = self:getModel():getTempData("popChangeList") or {}
    return table.exist(popChangeList, rankType)
end

function Manager:setPopChangeType(rankType)
    local popChangeList = self:getModel():getTempData("popChangeList") or {}
    table.insert(popChangeList, rankType)
    self:getModel():setTempData("popChangeList", popChangeList)
end

function Manager:calCurRankType()
    local userManager = _G.amfBean("UserManager")
    local serverMaxLevel = self:getServerMaxLevel()
    
    local userTopLevel = _G.getTopPassedLevelId()
    if userTopLevel < serverMaxLevel then
        return 0
    end

    local curYellow = userManager:getStar()
    local totalYellow = serverMaxLevel * 3

    if curYellow < totalYellow then
        local per = math.floor(curYellow / totalYellow * 100)
        for i = 1, 4 do
            local next = self:getNextPerRatioByRankType(i)
            if per < next then
                return i
            end
        end
    end

    local curColor = userManager:getColorfulStar()
    local totalColor = serverMaxLevel * 3
    if curColor < totalColor then
        return 5
    end

    local curHide = userManager:getHiddenStar()
    local totalHide = (serverMaxLevel / 15 - 1) * 9
    if curHide < totalHide then
        return 6
    end

    return 7
end

function Manager:getCurRankType()
    local curStarLevel = self:getModel():getDataByKey("simpleFullLevelRankBean.nowStarLevel", 0)
    return curStarLevel
end

function Manager:setCurRankType(rankType)
    self:getModel():setDataByKey("simpleFullLevelRankBean.nowStarLevel", rankType)
end

function Manager:getCurRank()
    local curRank = self:getModel():getDataByKey("simpleFullLevelRankBean.rank", 0)
    return curRank
end

function Manager:setCurRank(rank)
    self:getModel():setDataByKey("simpleFullLevelRankBean.rank", rank)
end

function Manager:getStarBottleNum()
    return _G.amfBean("StarBuffManager"):getStarBuffNum(true)
end

function Manager:getStarWandCanShow()
    return _G.amfBean("StarWandBuffManager"):isEnabled()
end

function Manager:getDefaultWeekRankPanelType()
    return self:getModel():getLocalCache("weekRankPanelType") or 1
end

function Manager:setDefaultWeekRankPanelType(value)
    self:getModel():setLocalCache("weekRankPanelType", value)
end

function Manager:getNextPerRatioByRankType(rankType)
    rankType = rankType or self:getCurRankType()
    if rankType <= 3 then
        local starLevelMetaList = self:getModel():getConfigByKey("starLevelMetaList") or {}
        local levelMeta = table.find(starLevelMetaList, function(v)
            return v.level == rankType
        end) or {}
        return levelMeta.ratio or 100
    else
        return 100
    end
end

function Manager:getActIconWorldPos()
    local actIcon = self.actPlug:getActIcon()
    if actIcon then
        return true, actIcon:getPositionInWorldSpace()
    end
    return false, ccp(0, 0)
end

function Manager:flyNodeToActIcon(callback, node, startPos, endPos, duration, endScale, onReachCallback)
    if not endScale then
        endScale = 0.5
    end

    local scene = Director:sharedDirector():getRunningSceneLua()
    if not scene or not scene:isScene("MainScene") then
        safeRunCall(callback)
        return
    end

    local icon = self:getActivityIcon()
    if not isSafeCocosObj(icon) then
        safeRunCall(callback)
        return
    end

    -- 不传endPos默认给飞到icon上，然后触发icon抖动动画
    if not endPos then
        endPos = icon:getPositionInWorldSpace()
    end

    local flyLayer = Layer:create()
    flyLayer:setWorldPositon(startPos)
    flyLayer:addChild(node)
    scene:addChild(flyLayer, SceneLayerShowKey.POP_OUT_LAYER)
    printx(42, "start--------00000000000000000000000")
    if isSafeCocosObj(node) then
        local pos = node:getPositionInWorldSpace()
        printx(42, "node Pos", pos.x, pos.y)

        local updateTime = function()
            if not isSafeCocosObj(flyLayer) then
                printx(42, "flyLayer disposed")
            end

            if isSafeCocosObj(node) then
                local pos2 = node:getPositionInWorldSpace()
                printx(42, "node Pos", pos2.x, pos2.y)
            else
                printx(42, "node is disposed")
            end
        end

        local action = CCRepeatForever:create(CCSequence:createWithTwoActions(CCDelayTime:create(1 / 30),
            CCCallFunc:create(updateTime)))
        node:runAction(action)
    end

    -- 释放layer
    local function callback2()
        if onReachCallback then
            safeRunCall(onReachCallback)
        end
        setTimeOut(function()
            safeRunCall(callback)
        end, 0.167)
        printx(42, "fly End000000000000000000000000000")
        if isSafeCocosObj(icon) then
            -- icon抖动动画
            icon:playCollectAni()
        end
        if isSafeCocosObj(flyLayer) then
            flyLayer:setVisible(false)
            flyLayer:removeFromParentAndCleanup(true)
        end
    end

    local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
    local action = ActionUtil:sequence({CCDelayTime:create(0),
                                        ActionUtil:spawn({ -- CCMoveTo:create(oneFrame*10, nodePos),
    ActionUtil:bezier(startPos, endPos, nil, duration, callback2), CCScaleTo:create(duration, endScale)})})
    flyLayer:runAction(action)
end

-------------------------------------------面板-----------------------------------------------------

function Manager:tryOpenDailyGetBuffPanel(callback)
    _G.amfBean("StarBuffManager"):tryOpenGetStarBuffPanel({
        closeCallback = function()
            local buffNum = _G.amfBean("StarBuffManager"):getStarBuffNum(true)
            safeRunCall(callback, buffNum)
        end,
        popoutSourceTypeId = StarBuffConst.PopoutSourceType.kStellarConvergence
    })
end

function Manager:openStarBottlePanel(updateFunc)
    _G.amfBean("StarBuffManager"):dc("click_icon_buff")
    local ShowStarBuffRemainPanelVM = require("amf.feature.localactivity.stellarconvergence.view.vm.ShowStarBuffRemainPanelVM")
    local vm = ShowStarBuffRemainPanelVM.Builder.new()
        :setTitle("补星瓶")
        :setRefreshFunc(updateFunc)
        :setCloseCallback(function()
            if not EnvUtil:isUnity() then
                -- UICreateUtil:unloadPlist("amf/uikit/image/panel/changeColor/testPicPack.plist")
            end
            if updateFunc then updateFunc() end
        end)
        :setColorType(PanelColorConst.ColorType.kStardustPalace2023Blue)
        :setDCFeatureAndSource("star_region", "repair_star")
        :setFarmStarPanelType(3)
        :build()

    vm:popout()
end

function Manager:openFullLevelScoringPanel(source)
    -- FullLevelOptimizeManager2023:setPanelSource(22)
    _G.amfBean("FarmLevelManager"):openRecommendPanel(nil, source)
    _G.amfBean("StarWandBuffManager"):dcClickIcon(3)
end

-- 领奖二次确认
function Manager:openGetRewardSecondConfirm(confirmCallback, notConfirmCallback)
    local targetTime = self:getModel():getLocalCache("getRewardSecondConfirm")
    local curTime = TimeKit:timeInSec()
    local needShow = (not targetTime) or (targetTime + 7 * 24 * 60 * 60 < curTime)

    if not needShow then
        safeRunCall(confirmCallback)
        return
    end

    local dcFlag = false
    local confirm = false
    local vm
    local CheckBox = require "amf.middleware.ui.kit.component.CheckBox"
    local checkBoxBuilder = CheckBox.Builder.new()
    :setText("七天内不再提醒")
    :setTickVisible(false)
    :setClickCallback(function(isCheck)
        dcFlag = isCheck

        if dcFlag then
            self:getModel():setLocalCache("getRewardSecondConfirm", curTime)
        end
    end)
    local FourthPanelAVM = require "amf.middleware.ui.kit.panel.fourth.FourthPanelAVM"
    local builder = FourthPanelAVM.Builder.new()
    builder:setButtonsConfig({{
        str = "确定",
        widthMode = UIButtonConfig.Widths.kShort,
        colorMode = UIButtonConfig.ColorMode.green,
        touchFunc = function()
            if vm.isDisposed then
                return
            end
            confirm = true
            safeRunCall(confirmCallback)
            vm:onCloseBtnTapped()
            StellarConvergenceDC:sendDC("affirm_click", {
                t1 = 1,
                t2 = dcFlag and 1 or 2
            })
        end
    }})

    local todayOpenCount = self:getModel():getTodayOpenCount()
    local todayMaxCount = self:getModel():getValue("perDayOpenBoxNum") or 2
    local retCount = todayMaxCount - todayOpenCount
    builder:setText({"确定要", "<<c=ea6b34>立刻开启>",
                   "星光宝盒吗？\n（今天还可开启" .. retCount .. "次）"}, kCCTextAlignmentCenter)

    builder:setCheckBoxBuilder(checkBoxBuilder)
    builder:setCloseCallback(function()
        StellarConvergenceDC:sendDC("affirm_click", {
            t1 = 2,
            t2 = dcFlag and 1 or 2
        })
        if not confirm then
            safeRunCall(notConfirmCallback)
        end
    end)

    vm = builder:build()
    vm:popout()
end

function Manager:openExchangeRewardPanel(rewardBean, areaId, done, disableDarkOpacity, extraSpineConfig)
    local str = "恭喜获得"
    local title = CircularTitle:create(str)

    for i, v in ipairs(rewardBean.rewardDirectList) do
        if v.itemId == self:getConst().ScoreBuffId then
            v.flyFunc = function(reward, worldPos, scale, callback)
                local flyContext = FlyItemContext.new({
                    itemId = FlyItemContext.FakeItemId.YELLOW_STAR,
                    num = 1,
                    starsWorldPos = {worldPos},
                })
                flyContext:setFinishCallback(callback)
                _G.amfTransaction(TransactionEvent.FLY_ITEMS, flyContext)
            end
        end
    end
    -- panelC延长animDelay时间，fireworks加个等级6
    local spinePath = "amf/activity/stellarconvergence/spine/xxlihe.skel"
    local showName = "in_open"
    local idleName = "open_idle"
    local disappearName = "out"
    local spineSpeed = 1.2
    local boxAnimDelay = nil
    local delayShowBtnTime = nil
    if extraSpineConfig then
        spinePath = extraSpineConfig.spinePath
        showName = extraSpineConfig.showName
        idleName = extraSpineConfig.idleName
        disappearName = extraSpineConfig.disappearName
        spineSpeed = extraSpineConfig.spineSpeed
        boxAnimDelay = extraSpineConfig.boxAnimDelay
        delayShowBtnTime = extraSpineConfig.delayShowBtnTime
    end

    local todayOpenCount = self:getModel():getTodayOpenCount()
    local todayMaxCount = self:getModel():getValue("perDayOpenBoxNum") or 2

    _G.amfTransaction(AMFEventConst.TransactionType.EXCHANGE_SHOP_TASK, {
        subCmd = "showReward",
        subData = {
            closeCallback = done,
            -- rewards = rewardBean,
            panelType = 3,
            dontNeedRunNumber = true,
            customBoxConfig = {
                path = spinePath,
                showName = showName,
                idleName = idleName,
                disappearName = disappearName,
                fireWorkType = 6,
                skinType = 6,
                speed = spineSpeed
            },
            titleSprite = title,
            subTitle = string.format("区域%d满黄星奖励", areaId),
            bottomText = {
                desc = {string.format("每日限领取%d/%d个 ", todayOpenCount, todayMaxCount), "<<node>>"},
                nodes = {UICreateUtil:createSpriteFile("amf/activity/stellarconvergence/materials/rewardBox.png")},
                outlineSize = 2,
                outlineColor = hex2ccc4("954600FF")
            },
            rewardList = rewardBean.rewardList,
            rewardDirectList = rewardBean.rewardDirectList,
            repeatList = rewardBean.repeatList,
            yuanBaoList = rewardBean.yuanBaoList,
            -- dontPopout = true,
            disableDarkOpacity = disableDarkOpacity,
            boxAnimDelay = boxAnimDelay,
            delayShowBtnTime = delayShowBtnTime,
            buttonUpText = "领取",
        }
    })
end


-- delegate = {
--     isFullColor = true,
--     areaId = 1,
--     closeCallback = nil,
--     isPlayNextLevel = false
-- }
function Manager:showOneAreaFullStarPanel(delegate)
    local todayOpenCount = self:getModel():getTodayOpenCount()
    local todayMaxCount = self:getModel():getValue("perDayOpenBoxNum") or 2
    local hasGotReward = self:checkHasGotReward(delegate.areaId)
    
    delegate.todayOpenCount = todayOpenCount
    delegate.todayMaxCount = todayMaxCount
    delegate.dontShowReward = hasGotReward

    local panelVm
    local panelVMClass = require "amf.feature.localactivity.stellarconvergence.view.vm.OneAreaFullStarPanelVM"
    panelVm = panelVMClass:create(delegate)
    panelVm:popout()
    return panelVm
end

-- delegate = {
--     areaId = 1,--1-10 1是1-150，2是151-300
--     colorStar = true,
--     closeCallback = nil
-- }
function Manager:showTenAreaFullStarPanel(delegate)
    local panelVm

    local panelVMClass = require "amf.feature.localactivity.stellarconvergence.view.vm.TenAreaFullStarPanelVM"
    panelVm = panelVMClass:create(delegate)
    panelVm:popout()

    return panelVm
end

-- 26.01.15 弹出太卡，做资源异步预加载
function Manager:showConstellationFullStarPanel(delegate)
    local function realPop()
        local panelVm
        local panelVMClass = require "amf.feature.localactivity.stellarconvergence.view.vm.ConstellationFullStarPanelVM"
        panelVm = panelVMClass:create(delegate)
        panelVm:setLoadResFailCallback(function()
            if not EnvUtil:isMiniGame() then self:releaseResList() end
            safeRunCall(delegate.closeCallback)
        end)
        panelVm:setCloseCallback(function()
            if not EnvUtil:isMiniGame() then self:releaseResList() end
            safeRunCall(delegate.closeCallback)
        end)
        panelVm:popout()
    end

    if not EnvUtil:isMiniGame() then
        local panel = require "amf.feature.localactivity.stellarconvergence.view.panel.ConstellationFullStarPanel"
        local resList = panel:getAssetsList()
        self:loadResListAndRetainAsync(resList, realPop)
    else
        realPop()
    end
end

-- 26.01.15 弹出太卡，做资源异步预加载
function Manager:showFullStarSharePanel(delegate)
    local function realPop()
        local panelVm
        local panelVMClass = require "amf.feature.localactivity.stellarconvergence.view.vm.FullStarSharePanelVM"
        panelVm = panelVMClass:create(delegate)
        panelVm:setLoadResFailCallback(function()
            if not EnvUtil:isMiniGame() then self:releaseResList() end
            safeRunCall(delegate.closeCallback)
        end)
        panelVm:setCloseCallback(function()
            if not EnvUtil:isMiniGame() then self:releaseResList() end
            safeRunCall(delegate.closeCallback)
        end)
        panelVm:popout()
    end

    if not EnvUtil:isMiniGame() then
        local panel = require "amf.feature.localactivity.stellarconvergence.view.panel.FullStarSharePanel"
        local resList = panel:getAssetsList()
        self:loadResListAndRetainAsync(resList, realPop)
    else
        realPop()
    end
end

function Manager:showStarLevelChangePanel(delegate)
    self:setPopChangeType(delegate.newRankType)
    self:setCurRankType(delegate.newRankType)
    
    local wrappedCallback = function()
        local isIconV2, icon = self:refreshActivityIcon("starLevelChanged")
        if not isIconV2 and isSafeCocosObj(icon) and type(icon.playBoomAni) == "function" then
            pcall(icon.playBoomAni, icon)
        end
        safeRunCall(delegate.callback)
    end
    
    local panelVMClass = require "amf.feature.localactivity.stellarconvergence.view.vm.StarLevelUpgradePanelVM"
    local panelVm = panelVMClass:create({
        oldRankType = delegate.oldRankType,
        rankType = delegate.newRankType,
        closeCallback = wrappedCallback
    })
    panelVm:popout(nil, true, nil, 0)
end

---------------------------------------------------------------------------------


function Manager:getFullColorAndYellowNum()
    return self:getModel():getFullColorAndYellowNum()
end

function Manager:getStarwandLevelNum()
    local lvsMain, lvsHide = self:getModel():getStarWandData()
    if not lvsMain or not lvsHide then
        return 0
    end
    return #lvsMain + #lvsHide
end

function Manager:getStarWandNum()
    return self:getStarwandLevelNum()
end

function Manager:getCanOpenBoxNum()
    return self:getModel():getCanOpenBoxNum()
end

-------------------------------------- 关卡内接口 -------------------------------------------
function Manager:isInLevelEnabled(params)
    if not UBFLevelSceneFunc:isFullLevelLib(params.levelScene) then
        return false
    end
    if not self:isEnabled() then
        return false
    end

    -- 判满紫，关卡库判了黄彩不用再判了
    local serverMaxLevel = self:getServerMaxLevel()
    local cur = _G.amfBean("UserManager"):getHiddenStar()
    local total = (serverMaxLevel / 15 - 1) * 9
    if cur < total then
        return false
    end

    return true
end

function Manager:getInLevelActData(levelId, ubfSLRuntime)
    local inLevelActData = {}

    inLevelActData.actEndTime = self:getLastEndTimeSec() * 1000

    local starBuffMgr = _G.amfBean("StarBuffManager")
    local normalNum = starBuffMgr:getStarBuffNormalNum()
    local limitPropList = starBuffMgr:getStarBuffTimeLimitPerNum(true)
    local infiniteTime = starBuffMgr:getStarBuffInfiniteTime()
    local str = ""
    str = str .. AMFPropId.STARBUFF .. "_" .. normalNum .. ";"
    for k, v in pairs(limitPropList) do
        str = str .. k .. "_" .. v .. ";"
    end
    str = str .. AMFPropId.INFINITE_STARBUFF_ONE_MINUTE .. "_" .. infiniteTime
    inLevelActData.star_stock = str

    return inLevelActData
end

function Manager:getCurAvailableBuffAndEndTime()
    return 0.3, self:getScoreBuffTime()
end

function Manager:getCurAvailableBuffAndEndTimeSec()
    return 0.3, math.floor(self:getScoreBuffTime() / 1000)
end

-------------------------------------- 资源预加载 -------------------------------------------

-- only app
local ResType = {
    PLIST = "plist",
    SPINE = "spine",
    SPRITE = "sprite",
}

function Manager:loadResListAndRetainAsync(resList, onCompleted)
    if not resList or #resList == 0 then
        if onCompleted then
            onCompleted()
        end
        return
    end

    if EnvUtil:isMiniGame() then
        _G.amfBean("AssetsUtil"):loadMiniFiles(resList, true):next(onCompleted)
        return
    end

    if self.allLoadPromise and self.curLoadPromise then
        -- 已经请求加载过了，直接接promise
        self.curLoadPromise = self.curLoadPromise:next(onCompleted)
        return
    end

    local autoReferenceMap = {}
    self.autoReferenceMap = autoReferenceMap
    self.allLoadPromise = deferred.new()
    self.curLoadPromise = self.allLoadPromise:next(onCompleted)

    local cond = Condition.new(function()
        printx(31, "allResLoaded", TimeKit:timeInMillis())
        self.allLoadPromise:resolve()
    end, #resList)

    local function onSingleResLoaded()
        cond:notify()
    end

    printx(31, "start load res list async", TimeKit:timeInMillis())
    for _, file in ipairs(resList) do
        if not autoReferenceMap[file] then
            if file:ends(".plist") then
                UICreateUtil:loadPlistAsync(file, onSingleResLoaded)
                autoReferenceMap[file] = ResType.PLIST
            elseif file:ends(".skel") then
                UICreateUtil:loadSpineResAsync(file, nil, onSingleResLoaded)
                autoReferenceMap[file] = ResType.SPINE
            elseif file:ends(".png") or file:ends(".jpg") then
                UICreateUtil:loadImageAsync(file, onSingleResLoaded)
                autoReferenceMap[file] = ResType.SPRITE
            end
        end
    end
end

function Manager:releaseResList()
    if not self.autoReferenceMap then return end

    if EnvUtil:isMiniGame() then
        local files = table.keys(self.autoReferenceMap)
        _G.amfBean("AssetsUtil"):unloadRes(files)
    else
        for file, resType in pairs(self.autoReferenceMap) do
            if resType == ResType.PLIST then
                UICreateUtil:unloadPlist(file)
            elseif resType == ResType.SPINE then
                UICreateUtil:unloadSpineRes(file, true, true)
            elseif resType == ResType.SPRITE then
                UICreateUtil:unloadImage(file)
            end
        end
    end
    
    self.autoReferenceMap = nil
    self.allLoadPromise = nil
    self.curLoadPromise = nil
end
--------------------------------------------------------------------------------------------

---------------------------------- CUSTOM_GAIN ----------------------------------

function Manager:_onCustomGain(event)
    local reward = event:getData()
    if reward.itemId == self:getConst().ScoreBuffId then
        self:addScoreBuffItem(reward.num)
    end
end

return Manager
