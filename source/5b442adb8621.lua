local FruitTreeManager = class("FruitTreeManager")
local deferred = require "amf.script.sugar.deferred"
local FruitTreeEventCenter = require "amf.feature.fruittree.event.FruitTreeEventCenter"
require "amf.feature.fruittree.config.FruitTreeConst"
local GoodsUtil = require "amf.middleware.purchase.util.GoodsUtil"
local FruitTreeUtil = require "amf.feature.fruittree.util.FruitTreeUtil"
local Res = require "amf.feature.fruittree.config.Res"

_G.ActFruitTreePreOpenContext = require "amf.feature.fruittree.actcontext.ActFruitTreePreOpenContext"
_G.ActIconRewardContext = require "amf.feature.fruittree.actcontext.ActIconRewardContext"
_G.ActIconNumContext = require "amf.feature.fruittree.actcontext.ActIconNumContext"
_G.ActIconNewContext = require "amf.feature.fruittree.actcontext.ActIconNewContext"

function FruitTreeManager:ctor()
    self._optionalDataManager = nil
    self._metaManager = nil
    self._dailyDataManager = nil
    self._propManager = nil
    self._userPropsManager = nil
    self._userManager = nil
    self._accountManager = nil
    self._profileManager = nil
    self._iconManager = nil
    self._achievementManager = nil
    self._inciteMgr = nil
end

function FruitTreeManager:setInciteMgr(mgr)
    self._inciteMgr = mgr
end

function FruitTreeManager:setIconManager(iconManager)
    self._iconManager = iconManager
end

function FruitTreeManager:setProfileManager(profileManager)
    self._profileManager = profileManager
end

function FruitTreeManager:setAccountManager(mgr)
    self._accountManager = mgr
end

function FruitTreeManager:setUserManager(userManager)
    self._userManager = userManager
end

function FruitTreeManager:setUserPropsManager(userPropsManager)
    self._userPropsManager = userPropsManager
end

function FruitTreeManager:setPropManager(propManager)
    self._propManager = propManager
end

function FruitTreeManager:setDailyDataManager(dailyDataManager)
    self._dailyDataManager = dailyDataManager
end

function FruitTreeManager:setMetaManager(metaManager)
    self._metaManager = metaManager
end

function FruitTreeManager:setOptionalDataManager(optionalDataManager)
    self._optionalDataManager = optionalDataManager
end

function FruitTreeManager:setAchievementManager(achievementManager)
    self._achievementManager = achievementManager
end

function FruitTreeManager:setMainVM(vm)
    self._mainVm = vm
end

function FruitTreeManager:registerEvent()
    -- 事件
    FruitTreeEventCenter:registerFeature(self)
end

function FruitTreeManager:initData()

    self.model = require("amf.feature.fruittree.model.Model"):create()
    -- user中就有这些数据
    -- 金银果树等级
    local fruitTreeLevel = self._optionalDataManager:getTempOptionalDataValue("fruitTreeLevel") or 1
    self:setFruitValue("fruitTreeLevel", fruitTreeLevel)
    -- 果子数据
    local fruitInfos = self._optionalDataManager:getTempOptionalDataValue("fruitInfos")
    self:setFruitValue("fruitInfos", fruitInfos)

    self:addFruitIcon()
end

function FruitTreeManager:addFruitIcon()
    if not FeatureSwitch:isOpen(FeatureSwitch.Type.FRUIT_TREE) then return end
    local icon = self._iconManager:getIconByIconKey(IconKey.kFruitTree)
    if icon then
        return
    end
    local IconMeta = require "amf.feature.mainscene.module.icon.config.IconMeta"
    self._iconManager:addIconClass(IconMeta.PoolType.kBottom, require "amf.feature.fruittree.view.FruitTreeIcon")
end

function FruitTreeManager:initialize()
    if not self:isGroupEnable() then return end
    self:registerEvent()
    if not self:isLevelEnabled() then
        if self._iconManager:useUIBottomBarTest() then
            self:addFruitIcon()
        end
        self._waitLevelEnabled = true
        return
    end
    -- 避免在初始化时取mgr
    TimerUtil.addAlarm(function()
        self:initData()
    end, 1/30)
    -- 进来先下载一次资源
    self:tryloadRes()
end

function FruitTreeManager:tryloadRes(loading)
    local d = deferred.new()
    if self._isResReady then
        return d:resolve()
    end
    self:log("loadRes start ====", TimeKit:timeInMillis())
    AssetsUtil:loadDynamicModule("meta/FruitTree.xml", function()
        self._isResReady = true
        self:log("loadRes ready ====", TimeKit:timeInMillis())
        d:resolve()
    end, nil, nil, loading)
    return d
end

function FruitTreeManager:isResReady()
    return self._isResReady
end

function FruitTreeManager:onActPlayLevelEnd(evt)
    local param = evt:getData()
    if param.levelType ~= GameLevelType.kMainLevel then return end
    if not param.isWin then return end
    if not self._waitLevelEnabled then return end
    if self:isLevelEnabled() then
        self._waitLevelEnabled = false
        self._waitStage4Guide = true
        self:initData()
    end
end

function FruitTreeManager:onActPassDay()
    FruitTreeEventCenter:dispatch(FruitTreeEvent.CLOSE_ALL_PANEL)
end

function FruitTreeManager:onActEnterStage4(evt)
    if not self._waitStage4Guide then return end
    local serverCacheManager = _G.amfBean("ServerCacheManager")
    if serverCacheManager:hasGuideFlag(_G.GuideFlagConst.kFruitTreeIconUnlockGuide) then
        local icon = self._iconManager:getIconByIconKey(IconKey.kFruitTree)
        if icon then
            icon:updateIconSprite() --刷新下解锁状态
        end
        return
    end

    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.FEATURE_UNLOCK_GUIDE)
    end

    local creator = function ()
        local icon = self._iconManager:getIconByIconKey(IconKey.kFruitTree)
        if icon then
            icon:playUnlock(function()
                icon:showFirstGuide(onHandleOver)
            end) --刷新下解锁状态
        else
            safeRunCall(onHandleOver)
        end
    end
     _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.FEATURE_UNLOCK_GUIDE, creator)
end

function FruitTreeManager:isGroupEnable()
    local Group = require "amf.feature.fruittree.Group"
    return not Group:isOff()
end

function FruitTreeManager:isLevelEnabled()
    return _G.getTopPassedLevelId() >= FruitTreeConst.OPAN_PASSLEVEL
end

function FruitTreeManager:isEnabled()
    if not self:isGroupEnable() then
        return false
    end
    if not self:isLevelEnabled() then
        return false
    end
    return true
end

--这里定义为生长次数大于配置的次数
function FruitTreeManager:getRealCanGetFruit()
	-- body
	local ret = 0
	local crowCount = self:getCrowCountNum() or 5
    local fruitInfos = self:getFruitValue("fruitInfos")
	if not fruitInfos then return ret end
	for _, info in pairs(fruitInfos) do
		if info.level <= 0 then
		else
			if info.growCount >= crowCount then
				ret = ret + 1
			end
		end
	end
	return ret
end

-- 生长周期
function FruitTreeManager:getFruitGrowCycle()
    return self._metaManager:getFruitGrowCycle()
end

function FruitTreeManager:isAllMature()
    local fruitInfos = self:getFruitValue("fruitInfos") or {}
    for k, v in pairs(fruitInfos) do
		if self:getGrowCount(v.id) < 5 then
            return false
        end
	end
	return true
end

function FruitTreeManager:getImmatureFruitIds()
    local ids = {}
    local fruitInfos = self:getFruitValue("fruitInfos") or {}
    for k, v in pairs(fruitInfos) do
		if self:getGrowCount(v.id) < 5 then
            table.insert(ids, v.id)
        end
	end
    return ids
end

function FruitTreeManager:useIncite(type)
    local ver = self._inciteMgr:getSceneUIVersion(InciteConst.EntranceType.kTree)
    if EnvUtil:isWindows() then return true end
    -- 目前都是1，所有没有double
    -- if ver >= 2 then
    --     return type == FruitTreeConst.InciteType.DOUBLE
    -- end
    return type == FruitTreeConst.InciteType.MATURE
end

function FruitTreeManager:getGrowCount(id)
    local info = self:getFruitDataById(id)
    return info and info.growCount or 0
end

-- 配置的次数
function FruitTreeManager:getCrowCountNum()
    return self._metaManager:getCrowCountNum() or 5
end

-- 获得果树对应等级限制摘取次数
function FruitTreeManager:getFruitTreeCanPickCount(level)
    local meta = self:getFruitTreeUpgradeMeta()
    local limit
	for k, v in ipairs(meta) do
		if v.level == level then
			limit = v.pickCount
			break
		end
	end
    return limit
end

-- 果树升级配置
function FruitTreeManager:getFruitTreeUpgradeMeta()
    if not self._fruitTreeUpdateMeta then
        local FruitsUpgradeMetaRef = require "amf.feature.fruittree.model.FruitsUpgradeMetaRef"
        self._fruitTreeUpdateMeta = self._metaManager:parseOrderedList("fruits_upgrade", FruitsUpgradeMetaRef)
    end
    return self._fruitTreeUpdateMeta
end

-- 根据treeLevel获得升级配置信息
function FruitTreeManager:getFruitTreeUpgradeMetaByLevel(level)
    level = level or self:getFruitValue("fruitTreeLevel")
    level = tostring(level)
    local fMeta = self:getFruitTreeUpgradeMeta()
    for i, v in ipairs(fMeta) do
        if tostring(v.level) == level then
            return v
        end
    end
    return nil
end

-- 获得果树升级字段
function FruitTreeManager:getFruitTreeUpgradeValue(level, key)
    local meta = self:getFruitTreeUpgradeMetaByLevel(level)
    if not meta then return 0 end
    return meta[key]
end

-- 果子等级配置
function FruitTreeManager:getFruitsMeta()
    if not self._fruitsMeta then
        local FruitsMetaRef = require "amf.feature.fruittree.model.FruitsMetaRef"
        self._fruitsMeta = self._metaManager:parseOrderedList("fruits", FruitsMetaRef)
    end
    return self._fruitsMeta
end

-- 果子配置
function FruitTreeManager:getFruitsMetaByLevel(level)
    level = tostring(level) or "0"
    local fruitMeta = self:getFruitsMeta()
    for i, v in ipairs(fruitMeta) do
        if tostring(v.level) == level then
            return v
        end
    end
    return nil
end

function FruitTreeManager:openFruitTreePanel(param)
    param = param or {}
    _G.__CollectWordTestMode = param.__collectWordTestMode == true
    -- 各个活动监听，在这里把需要的各种方法设置到金银果树中
    local preOpenContextList = {}
    FruitTreeEventCenter:dispatch(FruitTreeEvent.PRE_OPEN_CHECK, preOpenContextList)
    table.sort(preOpenContextList, function(a,b)
        return a:getPriority() > b:getPriority()
    end)
    local context = preOpenContextList[1]

    local function openMainPanel()
        local function _realOpen()
            if self._mainVm and not self._mainVm.isDisposed then
                print("已经打开金银果树了")
                return
            end
            local panelVM
            if context and context:getPanelVM() and context:isEnabled() then
                panelVM = context:getPanelVM()
            else
                panelVM = require_debug "amf.feature.fruittree.view.FruitTreeMainPanelVM"
            end

            local vm = panelVM:create(param)
            -- 复访等外部流程需要感知面板“真正展示/关闭”的时机：钩子由 AMFBasePanelVM 提供，
            -- 活动替换面板（如集字活动）继承同一套基类，无需单独适配。
            if param.onOpened then
                vm:setPanelReadyCallback(function()
                    safeRunCall(param.onOpened)
                end)
            end
            if param.onClosed then
                vm:setCloseCallback(function(isClickCloseBtn)
                    safeRunCall(param.onClosed, isClickCloseBtn)
                end)
            end
            vm:setLoadResFailCallback(function()
                safeRunCall(param.onLoadFailed)
                safeRunCall(param.closeCallback)
            end)
            vm:popout(nil, true)
            self:setMainVM(vm)
        end
        if context then
            context:callFunction(function()
                _realOpen()
            end)
        else
            _realOpen()
        end
    end
    self:tryloadRes(true):next(function()
        openMainPanel()
    end, function()
        CommonTip:showTip("资源下载失败~")
    end)

end

-- 更新本日摘取信息
function FruitTreeManager:_updatePickFruitCount()
    local level = self:getFruitValue("fruitTreeLevel")
    local limitCount = self:getFruitTreeCanPickCount(level)
    if not limitCount then return end

    limitCount = limitCount + self._achievementManager:getExtraCount(AchievementConst.AchiRightType.FRUIT)
    local picked = self._dailyDataManager:getDailyDataValue("pickFruitCount")
    if picked >= limitCount then
        self._dailyDataManager:setDailyDataValue("pickFruitCount", limitCount)
        return
    end
    self._dailyDataManager:setDailyDataValue("pickFruitCount", picked+1)
end

-- 请求领取video喷壶
function FruitTreeManager:requestVideoSDKFruit(param, loading)
    local d = deferred.new()
    self.model:requestVideoSDKFruit(param, loading):next(function(response)
        local data = response:getData()
        self._inciteMgr:subCount(InciteConst.EntranceType.kTree, data.nextRewardTime)

        -- 打点
        local reward_type = ""
        local reward_level = ""
        local fruitIds = self:getImmatureFruitIds() or {}
        for i, v in ipairs(fruitIds) do
            local fruitInfo = self:getFruitDataById(v) or {}
            if reward_type == "" then
                reward_type = tostring(fruitInfo.type)
            else
                reward_type = reward_type .. "_" .. tostring(fruitInfo.type)
            end
            if reward_level == "" then
                reward_level = tostring(fruitInfo.level)
            else
                reward_level = reward_level .. "_" .. tostring(fruitInfo.level)
            end
        end
        -- 更新数据
        if data.fruitInfos then
            self:setFruitValue("fruitInfos", data.fruitInfos)
        end
        _G.amfTransaction(_G.TransactionEvent.AD, {
            type = "dc",
            action = _G.InciteEvent.tree_reward_success,
            info = {
                reward_num = #fruitIds,
                reward_type = reward_type,
                reward_level = reward_level,
            }
        })
        d:resolve()
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        self._inciteMgr:subCount(InciteConst.EntranceType.kTree)
        _G.amfTransaction(_G.TransactionEvent.AD, {
            action = _G.InciteEvent.tree_reward_exception,
        })
        d:reject(response:isCancel())
    end)

    return d
end

-- 请求重生
function FruitTreeManager:requestReborn(info)
    local d = deferred.new()
    local param = {
        id = info.id,
        type = 1,
        version = 0,
    }
    -- 打点
    local fruitType = self:getFruitValueById(param.id, "type")
    local fruitLevel = self:getFruitValueById(param.id, "level")
    local treeLevel = self:getFruitValue("fruitTreeLevel")
    self.model:requestPickFruit(param):next(function(response)
        local data = response:getData()
        DcUtil:fruitRegenerate(fruitType, fruitLevel, treeLevel)

        _G.amfTransaction(_G.TransactionEvent.AD, {
            type = "dc",
            action = _G.InciteEvent.tree_fruit_reborn,
            info = {
                fruitType = fruitType,
            	fruitLevel = fruitLevel,
            }
        })
        -- 更新对应id果子信息

        self:updateFruitInfo(param.id, data.fruit)
        self:clearShowOffLevel6(param.id)
        -- 更新icon信息
        FruitTreeEventCenter:dispatch(FruitTreeEvent.REBORN_FRUIT_SUCCESS)
        d:resolve({
            id = param.id,
        })
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        d:reject(response:isCancel())
    end)
    return d
end

-- 果子加速
function FruitTreeManager:requestSpeedUp(info)
    local d = deferred.new()
    local enough, needNum = self:isEnoughSpeedPropNumber(info.id)
    if enough == nil then
        CommonTip:showErrorTip(0)
        return d:reject()
    end
    if enough then
        _G.ConsumePropData:create()
            :setFeature(DcFeatureType.kFruitTree)
            :setSource(DcSourceType.kFruitSpeedUp)
            :setProp({itemId=AMFPropId.HOURGLASS,num = needNum})
            :setLevelId(0)
            :setParam(info.id)
            :execute()
        -- 打点
        local fruitType = self:getFruitValueById(info.id, "type")
        local fruitLevel = self:getFruitValueById(info.id, "level")
        local treeLevel = self:getFruitValue("fruitTreeLevel")
        DcUtil:fruitSpeed(needNum, fruitType, fruitLevel, treeLevel)
        self:requestFruitsInfo(nil, true):next(function()
            d:resolve({
                id = info.id,
            })
        end, function()
            d:reject()
        end)
    else
        d:reject({
            notEnough = true
        })
    end
    return d
end

-- 请求果子信息
function FruitTreeManager:requestFruitsInfo(param, loading, customParam)
    param = param or {}
    param.version = _G.FruitTreeConst.VERSION
    local d = deferred.new()
    self.model:requestFruitsInfo(param, loading):next(function(response)
        local data = response:getData()
        -- 新增字段，再同步一下子，不然不重启没有时机同步，如果升级的时候后端成功前端失败了的情况，2026.01.07
        if data.fruitTreeLevel then
            self:setFruitValue("fruitTreeLevel", data.fruitTreeLevel)
        end
        self:setFruitValue("fruitInfos", data.fruitInfos)
        FruitTreeEventCenter:dispatch(FruitTreeEvent.GET_FRUIT_INFO_SUCCESS)
        d:resolve()
    end, function()
        d:reject()
    end)
    return d
end

-- 摘果子/重生
function FruitTreeManager:requestPickFruit(param)
    local d = deferred.new()
    param = param or {}
    if not param.type then
        param.type = 0
    end
    param.version = 0
    -- 打点
    local fruitType = self:getFruitValueById(param.id, "type")
    local fruitLevel = self:getFruitValueById(param.id, "level")
    local treeLevel = self:getFruitValue("fruitTreeLevel")
    self.model:requestPickFruit(param):next(function(response)
        local data = response:getData()
        -- 摘取  0或2
        self:_updatePickFruitCount()
        -- 如果是精力，精力满时是不会发reward字段的
        if not table.isEmpty(data.reward) then
            GainPropData:create()
                :setFeature(DcFeatureType.kFruitTree)
                :setSource(DcSourceType.kFruitTreeReward)

                :setProps(data.reward)
                :execute()
        end

        FruitTreeEventCenter:dispatch(FruitTreeEvent.GET_FRUIT_SUCCESS, 1)
        -- _G.questEvtDp:dp(_G.QuestEvent.new(_G.QuestEventType.kAfterPickFruit))
        --更新到下一次的时间
        -- if isDouble and evt.data.nextRewardTime then
        --     InciteManager:subCount( EntranceType.kTree , evt.data.nextRewardTime)
        -- end

        -- if PPTask2021Notify then
        --     PPTask2021Notify:dispatch(PPTask2021Events.kFruitTreeTask, {pickFruit = true})
        -- end
        DcUtil:fruitPick(fruitType, fruitLevel, treeLevel)
        _G.amfTransaction(_G.TransactionEvent.AD, {
            type = "dc",
            action = _G.InciteEvent.tree_fruit_pick,
            info = {
                fruitType = fruitType,
            	fruitLevel = fruitLevel,
            }
        })
        -- 更新对应id果子信息
        self:updateFruitInfo(param.id, data.fruit)
        self:clearShowOffLevel6(param.id)
        FruitTreeEventCenter:dispatch(FruitTreeEvent.GET_FRUIT_SUCCESS_AFTERDATA)
        d:resolve(data)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        d:reject(response:isCancel())
    end)
    return d
end

-- 升级果树银币
function FruitTreeManager:requestUpgradeFruitTreeByCoin(param)
    param = param or {}
    param.fruitsVersion = 1
    local d = deferred.new()
    self.model:requestUpgradeFruitTree(param):next(function(response)
        local fruitTreeLevel = self:getFruitValue("fruitTreeLevel")
        self:setFruitValue("fruitTreeLevel", fruitTreeLevel + 1)
        -- 消耗银币
        local costCoin = self:getFruitTreeUpgradeValue(fruitTreeLevel + 1, "coin")
        ConsumeCurrencyData:create()
            :setFeature(DcFeatureType.kFruitTree)
            :setSource(DcSourceType.kFruitTreeUpdate)
            :setCurrencyType(DcDataCurrencyType.kCoin)
            :setCost(costCoin)
            :execute()
        DcUtil:fruitTreeUpgrade(fruitTreeLevel)
        FruitTreeEventCenter:dispatch(FruitTreeEvent.UP_LEVEL_SUCCESS, {
            costCoin = costCoin,
            costGold = 0,
        })
        -- 刷新icon角标，有可能变了
        FruitTreeEventCenter:dispatch(FruitTreeEvent.ACT_DATA_CHANGE)
        d:resolve()
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        d:reject(response:isCancel())
    end)
    return d
end

-- 升级果树金币
function FruitTreeManager:requestUpgradeFruitTreeByGold(goodsId)
    local d = deferred.new()
    self:requestBuy(goodsId, 1, DcSourceType.kFruitTreeUpdate):next(function()
        local fruitTreeLevel = self:getFruitValue("fruitTreeLevel")
        self:setFruitValue("fruitTreeLevel", fruitTreeLevel + 1)
        -- 打点
        local price = GoodsUtil:getCashPrice(goodsId)
        DcUtil:fruitTreeUpgrade(fruitTreeLevel, 1, price)
        FruitTreeEventCenter:dispatch(FruitTreeEvent.UP_LEVEL_SUCCESS, {
            costCoin = 0,
            costGold = price,
        })
        -- 刷新icon角标，有可能变了
        FruitTreeEventCenter:dispatch(FruitTreeEvent.ACT_DATA_CHANGE)
        d:resolve()
    end, function()
        d:reject()
    end)
    return d
end

function FruitTreeManager:initBuyPropPayTracer(goodsId, source)
    local PaymentTracer = require 'amf.middleware.purchase.dc.trace.PaymentTracer'
    self._buyPropTracer = PaymentTracer.createWMBPayTracer(
        DcFeatureType.kFruitTree,
        source or DcSourceType.kFruitSpeedUp,
        goodsId,
        DCPayProgressPayPanelShowType.kUserClick
    )
end

function FruitTreeManager:doTracer(funcName)
    if self._buyPropTracer then
        self._buyPropTracer[funcName](self._buyPropTracer)
    end
end

-- 购买
function FruitTreeManager:requestBuy(goodsId, num, source)
    local d = deferred.new()
    local function onSuccess()
        CommonTip:showTip("购买成功")
        self:doTracer("paySuccess")
        d:resolve()
    end
    local function onFail(errorCode, errorMsg, payInfo)
        self:doTracer("payFail")
        d:reject(errorCode)
    end
    local function onCancel(payInfo)
        self:doTracer("payCancel")
        d:reject(nil, true)
    end
    -- 开始购买
    local buyContext = BuyContext.new(goodsId, MoneyType.kGold)
        :setFeatureAndSource(DcFeatureType.kFruitTree, source or DcSourceType.kFruitSpeedUp)
        :setBuyCount(num)
        :setCallback(onSuccess, onFail, onCancel)
    _G.amfTransaction(TransactionEvent.PAY, buyContext)
    return d
end

-- 沙漏是否够数量
function FruitTreeManager:isEnoughSpeedPropNumber(id)
	local info = self:getFruitDataById(id)
    if not info then return nil end
    local growCycle = self:getFruitGrowCycle()
	if info.growCount >= self:getCrowCountNum() then return nil end
	local elapse = info.updateTime + growCycle - TimeKit:timeInMillis()
	if elapse > growCycle then elapse = growCycle end
	local minute = self._propManager:getPropEffectValue(AMFPropId.HOURGLASS)
	if minute <= 0 then return nil end
	local need = math.ceil(elapse / (minute * 60000))
	local have = self._userPropsManager:getUserPropNumber(AMFPropId.HOURGLASS)
	if need > have then return false, need end
	return true, need
end

function FruitTreeManager:getFruitDataById(id)
    local fruitInfos = self:getFruitValue("fruitInfos") or {}
    for _, v in ipairs(fruitInfos) do
        if v.id == id then
            return v
        end
    end
    return nil
end

function FruitTreeManager:setFruitValue(key, value)
    self.model:setValue(key, value)
end

function FruitTreeManager:getFruitValue(key)
    if key == "fruitInfos" then
        local list = {}
        local infos = self.model:getValue(key) or {}
        for i, v in ipairs(infos) do
            if v.id ~= -1 then
                table.insert(list, v)
            end
        end
        return list
    end
    return self.model:getValue(key)
end

-- 更新果子
function FruitTreeManager:updateFruitInfo(id, info)
    if not id or not info then return end
    local fruitInfos = self:getFruitValue("fruitInfos") or {}
    for i, v in ipairs(fruitInfos) do
        if v.id == id then
            fruitInfos[i] = info
            self:setFruitValue("fruitInfos", fruitInfos)
            return
        end
    end
end

-- 获得果子的数据
function FruitTreeManager:getFruitValueById(id, key, default)
    local fruitInfos = self:getFruitValue("fruitInfos") or {}
    for i, v in ipairs(fruitInfos) do
        if v.id == id then
            return v[key]
        end
    end
    return default
end

-- 创建果实图片
function FruitTreeManager:createFruitSp(type, level, withStar)
    UICreateUtil:loadPlist(Res.Main.Plist.PUB_FRAME)
    local frame = level == 0 and "XiaoChengXu/FruitTreeFruitFrames/fruit" or "XiaoChengXu/FruitTreeFruitFrames/fruit_"..tostring(type).."_"..tostring(level)
    local icon  = Sprite:createWithSpriteFrameName(frame)
    icon:setAnchorPoint(ccp(0.5, 0))
    if withStar then
        local rand = math.random(1, 2)
        local pos1 = ccp(icon:getContentSize().width * 0.7, icon:getContentSize().height*0.4)
        local pos2 = ccp(icon:getContentSize().width*0.1, icon:getContentSize().height*0.7)
        if rand == 2 then
            pos1 = ccp(icon:getContentSize().width * 0.7, icon:getContentSize().height*0.7)
            pos2 = ccp(icon:getContentSize().width*0.1, icon:getContentSize().height*0.4)
        end
        local star1 = self:createStar(0.2, 0.6, 1, Res.Main.Frame.STAR)
        star1:setPosition(pos1)
        icon:addChild(star1)

        local star2 = self:createStar(0.5, 0.3, 0.6, Res.Main.Frame.STAR)
        star2:setPosition(pos2)
        icon:addChild(star2)
    end
    UICreateUtil:unloadPlist(Res.Main.Plist.PUB_FRAME)
    return icon
end

function FruitTreeManager:createStar(para1, para2, scale, frameName)
    UICreateUtil:loadPlist(Res.Main.Plist.PUB_FRAME)
    frameName = frameName or Res.Main.Frame.STAR
    local star = FruitTreeUtil:createStar(para1, para2, scale, frameName)
    UICreateUtil:unloadPlist(Res.Main.Plist.PUB_FRAME)
    return star
end

-- 摘取是否到了上线
function FruitTreeManager:isFruitPickLimit()
    local level = self:getFruitValue("fruitTreeLevel")
    local limitCount = self:getFruitTreeCanPickCount(level)
    if not limitCount then
        return true
    end

    limitCount = limitCount + self._achievementManager:getExtraCount(AchievementConst.AchiRightType.FRUIT)
    local picked = self._dailyDataManager:getDailyDataValue("pickFruitCount")
    return picked >= limitCount
end

function FruitTreeManager:getFruitCanPickAllCount()
    local level = self:getFruitValue("fruitTreeLevel")
    local limit = self:getFruitTreeCanPickCount(level) or 0
    return limit + self._achievementManager:getExtraCount(AchievementConst.AchiRightType.FRUIT)
end

function FruitTreeManager:getRewardItemIdById(id)
    local info = self:getFruitDataById(id)
    if not info then return nil end
    if info.type == FruitTreeConst.FruitType.COIN then
        return AMFPropId.COIN
    elseif info.type == FruitTreeConst.FruitType.ENERGY then
        return AMFPropId.ENERGY_LIGHTNING
    elseif info.type == FruitTreeConst.FruitType.GOLD then
        return AMFPropId.GOLD
    end
end

-- 获得还剩几次摘取次数
function FruitTreeManager:getLeftPickCount()
    local level = self:getFruitValue("fruitTreeLevel")
    local limitCount = self:getFruitTreeCanPickCount(level)
    if not limitCount then
        return 0
    end
    limitCount = limitCount + self._achievementManager:getExtraCount(AchievementConst.AchiRightType.FRUIT)
    local picked = self._dailyDataManager:getDailyDataValue("pickFruitCount")
    return limitCount - picked
end

-- 是否可以重生
function FruitTreeManager:canReborn(id)
    local info = self:getFruitDataById(id)
    if not info then return false end
    if info.level <= 0 then return false end
    return true
end

-- 是否可以摘取
function FruitTreeManager:canPick(id)
    local info = self:getFruitDataById(id)
    -- 没有数据
    if not info then return false end
    -- 等级小于等于0不能摘
    if info.level <= 0 then return false end
    -- 摘取到上限了
    if self:isFruitPickLimit() then return false end
    return true
end

-- 是否可以加速
function FruitTreeManager:canSpeedUp(id)
    local info = self:getFruitDataById(id)
    -- 没有数据
    if not info then return false end
    -- 等级>=5 或者生长次数>=5,不能加速
    if info.level >= 5 or info.growCount >= self:getCrowCountNum() then
        return false
    end
    return true
end

-- 获取加速时沙漏需要几个
function FruitTreeManager:getAccelerateNeededCount(id)
	local minute = self._propManager:getPropEffectValue(10029)
	if minute <= 0 then return 0 end
    local info = self:getFruitDataById(id)
	if not info then return 0 end
	local timeStamp = info.updateTime
	local time = TimeKit:timeInMillis()
	local remain = math.floor(self:getFruitGrowCycle() - time + timeStamp)
	local neededCount = math.ceil(remain / (minute * 60000))
	if neededCount >= 3 then neededCount = 3 end
	return neededCount
end

-- 获得需要再购买几个沙漏
function FruitTreeManager:getAccelerateNeededAdditionCount(id)
    local needCount = self:getAccelerateNeededCount(id)
    local hasCount = self._userPropsManager:getUserPropNumber(AMFPropId.HOURGLASS)
    return needCount - hasCount
end

-- 重生按钮是否有动画
function FruitTreeManager:getRebornShowAnim(id)
	if id == -1 then return false end
    local info = self:getFruitDataById(id)
	if not info then return false end
	return info.growCount >= 3 and info.level == 1
end

-- 是否要展示星星动画
function FruitTreeManager:canStartBlinkAnim(id)
    local info = self:getFruitDataById(id)
    return info and info.growCount == 5
end

-- 获得果子的奖励
function FruitTreeManager:getRewardById(id)
    local info = self:getFruitDataById(id)
    if not info then return {} end
    if info.level == 0 then return {} end
    local cfg = self:getFruitTreeUpgradeMetaByLevel()
    local buff = 1
    if cfg.plus then
        buff = (cfg.plus + 100)/100
    end
    -- 只有银币才有加成
    if info.type ~= FruitTreeConst.FruitType.COIN then
        buff = 1
    end
    local fruitMeta = self:getFruitsMetaByLevel(info.level)
    if not fruitMeta then return {} end
    local itemId = self:getRewardItemIdById(info.id)
    if not itemId then return {} end
    for _, v in ipairs(fruitMeta.reward) do
        if v.itemId == itemId then
            return {itemId = itemId, num = v.num * buff}
        end
    end
    return {}
end

-- 获得当前果树加成
function FruitTreeManager:getPlus(level)
    local cfg = self:getFruitTreeUpgradeMetaByLevel(level)
    return cfg.plus or 0
end

function FruitTreeManager:getUpgradeLocked(level)
	local cfg = self:getFruitTreeUpgradeMetaByLevel(level)
    if not cfg then
        -- 没有就返回锁了，不能升级
        return true
    end
    return cfg.lock
end

-- 果树升级条件
function FruitTreeManager:getUpgredeCondition(level)
    local cfg = self:getFruitTreeUpgradeMetaByLevel(level)
    return cfg and cfg.upgradeCondition
end

-- 果子是否需要刷新，倒计时到了
function FruitTreeManager:isFruitNeedUpdate(id)
	local info = self:getFruitDataById(id)
    if not info then return false end
	if info.growCount >= self:getCrowCountNum() then return false end
	if info.updateTime + self:getFruitGrowCycle() - TimeKit:timeInMillis() <= 0 then
		return true
	end
	return false
end

-- 获得fruit当前生长进度
function FruitTreeManager:getFruitProgress(id) -- return value, max
	local info = self:getFruitDataById(id)
    if not info then return nil end
	if info.growCount >= self:getCrowCountNum() then return nil end
	local timeStamp = info.updateTime
	local time = TimeKit:timeInMillis()
	return time - timeStamp
end

function FruitTreeManager:getUpdateTimerString(id)
	local info = self:getFruitDataById(id)
    if not info then return "" end
	if info.growCount >= self:getCrowCountNum() then return "" end
	local elapse = info.updateTime + self:getFruitGrowCycle() - TimeKit:timeInMillis()
	local timestr = ""
	local minute = math.floor(math.floor(elapse / 1000) / 60)
	if elapse > 60000 then timestr = timestr..tostring(minute)..':' end
	timestr = timestr..tostring(math.floor((elapse - minute * 60000) / 1000))
	return timestr
end

-- 升级条件是否满足
function FruitTreeManager:getFinishUpgradeCondition(level)
	level = level or self:getFruitValue("fruitTreeLevel")
    local upgradeCondition = self:getUpgredeCondition(level)
	if not upgradeCondition then return 0, false, 0, 0 end
	local condition = upgradeCondition[1]
	if type(condition) ~= "table" then return 0, false, 0, 0 end
	if condition.itemId == FruitTreeConst.TreeUpgradeCondition.STAR then
		local star = self._userManager:getStar()
		local finish = (star >= condition.num)
		return condition.itemId, finish, star, condition.num
	elseif condition.itemId == FruitTreeConst.TreeUpgradeCondition.PASSLEVEL then
		local level = _G.getTopPassedLevelId()
		return condition.itemId, level >= condition.num, level, condition.num
	elseif condition.itemId == FruitTreeConst.TreeUpgradeCondition.BIND then --绑定sns账号qq&手机
		local finish = false
        local bindCfg = _G.amfBean("SnsBindLogic"):getFruitTreeLevelUpNodeCfg()
		return condition.itemId,bindCfg.hasBind,0,condition.num
	elseif condition.itemId == FruitTreeConst.TreeUpgradeCondition.INVALID then --没有这个条件
		return condition.itemId, true, 0, 0
	else
		return condition.itemId, false, 0, condition.num
	end
end

function FruitTreeManager:getFinishUpgradeCoin(level)
	level = level or self:getFruitValue("fruitTreeLevel")
	local finish, upgradeCoin = true, 99999999
    upgradeCoin = self:getFruitTreeUpgradeValue(level, "coin") or 0
	local coin = self._userManager:getCoin()
	if coin < upgradeCoin then finish = false end
	return finish, coin, upgradeCoin
end

-- 果树是否可以升级
function FruitTreeManager:isFruitTreeCanUpgrade()
    local treeLevel = self:getFruitValue("fruitTreeLevel")
    local itemId, conditionFinish = self:getFinishUpgradeCondition(treeLevel+1)
    local coinFinish = self:getFinishUpgradeCoin(treeLevel + 1)
    local canUpgrade = false --可以升级
	local bindCanUpgrade = false --绑定账号后可以升级
	if coinFinish then
		if conditionFinish then
			canUpgrade = true
		elseif itemId == FruitTreeConst.TreeUpgradeCondition.BIND then
			bindCanUpgrade = true
		end
	end
    return canUpgrade or bindCanUpgrade
end

function FruitTreeManager:hasShowOffLevel6(id)
    if not id then return true end
    return LocalDB:getBool("FruitTree_ShowOffLevel6_"..tostring(id))
end

function FruitTreeManager:setShowOffLevel6(id)
    if not id then return end
    LocalDB:setBool("FruitTree_ShowOffLevel6_"..tostring(id), true)
end

function FruitTreeManager:clearShowOffLevel6(id)
    if not id then return end
    LocalDB:setBool("FruitTree_ShowOffLevel6_"..tostring(id), false)
end

function FruitTreeManager:startBindSns(authorizeType, callback)
    local AccountBindMeta = require "amf.middleware.multiplatform.account.config.Meta"
    local AccountBindEventCenter = require "amf.feature.accountbind.event.AccountBindEventCenter"
    if authorizeType == PlatformAuthEnum.kPhone then
        FruitTreeEventCenter:dispatch(FruitTreeEvent.BIND_PHONE_NUMBER, {
            callback = callback,
        })

        --AccountBindEventCenter:dispatch(_G.AccountBindEvent.START_BIND_PHONE, {
        --    isRebind = false,
        --    source = AccountBindMeta.AccountBindingSource.FRUIT_TREE,
        --    successCallback = function()
        --        safeRunCall(callback, true)
        --    end,
        --    failCallback = function()
        --        safeRunCall(callback, false)
        --    end
        --})
    else
        AccountBindEventCenter:dispatch(_G.AccountBindEvent.START_BIND_SNS, {
            authorizeType = authorizeType,
            source = AccountBindMeta.AccountBindingSource.FRUIT_TREE,
            successCallback = function()
                safeRunCall(callback, true)
            end,
            failCallback = function()
                safeRunCall(callback, false)
            end
        })
    end

end

function FruitTreeManager:log(...)
    if EnvUtil:isDevelopMode() then
        printx(27, "FruitTreeLog: ", ...)
    end
end

return FruitTreeManager
