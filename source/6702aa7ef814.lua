local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
---@class NewbieGiftNewGiftpackage
local NewbieGiftNewGiftpackage = require "amf.feature.localactivity.newbiegiftoptimize.NewbieGiftNewGiftpackage"

local ICON_V2_EXPERIMENT_MODULE = "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"
local THREE_FOR_ONE_ICON_V2_CONFIG_MODULE =
    "amf.feature.localactivity.newbiegiftoptimize.icon.NewbieGiftChoiceIconV2Config"
local ADAPTER_CREATE_READY = "ready"
local ADAPTER_CREATE_SAFE_LEGACY = "safe_legacy"
local ADAPTER_CREATE_WAIT_OWNER = "wait_owner"


---@class NewbieGiftOptimizeMgr
local Manager = class("NewbieGiftOptimizeMgr")
local log = function ( ... )
    printx(33, "NewbieGiftOptimize:", ...)
end

----------- 可能需要修改start -----------
local ActivityName = "NewbieGiftOptimize"
local HttpRequest = require('amf.feature.localactivity.'..string.lower(ActivityName)..'.http.'..ActivityName..'HttpRequest')
local Model = require('amf.feature.localactivity.'..string.lower(ActivityName)..'.model.'..ActivityName..'Model')
local Meta = require('amf.feature.localactivity.'..string.lower(ActivityName)..'.config.'..ActivityName..'Meta')

Manager.ACT_OPEN_VERSION = 1
--3076新活动id，4056老活动 2025年12月15日 星期一
Manager.ACT_ID = 4056
Manager.DC_ACT_ID = "4056"
Manager.GAME_NAME = "sprog_icebreaking"
Manager.ACT_SOURCE = "emptyact/newbiegiftoptimize/Config.lua"
local resPath = "amf/activity/newbiegiftoptimize/"

-- 礼包类型
Manager.GIFT_TYPE = Meta.GIFT_TYPE

-- 礼包场景类型
Manager.GIFT_SCENE = Meta.GIFT_SCENE

Manager.ACTNAME = Meta.ACTNAME

Manager.ICONNAME = Meta.ICONNAME
-- 版本控制标记
Manager.CLIENTVERSION = Meta.CLIENTVERSION

-- iconKey
Manager.ICONKEY = Meta.ICONKEY

-- icon spine路径
Manager.ICONSPINE = Meta.ICONSPINE

Manager.AUTOPOPTYPE = Meta.AUTOPOPTYPE

Manager.Events = {
    kPassDay = 'PassDay',
    kActEnd = 'ActEnd',
    kCloseAllPanel = 'CloseAllPanel',    --关闭所有界面
    kContactsChange = 'ContactsChange',    --地址变更
}

----------- 可能需要修改end -----------
function Manager:ctor()
    self.activityManager = nil
    self.iconManager = nil

    --设置新老活动id
    ---@type NewbieGiftNewGiftpackage
    self._newbieGiftNewGiftpackage = NewbieGiftNewGiftpackage.new()
    self._newbieGiftNewGiftpackage:isOpenAndSetActId(self)
end

function Manager:setActivityManager(mgr)
    self.activityManager = mgr
end

function Manager:initialize()
    self.localDataServer = Model:create()
    self:registerEvents()

    self._observers = {}
    self.iconList = {}
    self._threeForOneIconAdapter = nil
    self._threeForOneIconDataProvider = nil
    self._threeForOneIconAdapterRecoveryPending = false
end

function Manager:dcQualify()
    if not self:getFlagFromLocalByKey("hasDcQualify", true) then
        self:saveFlagToLocalByKey("hasDcQualify", true)
        self:dc("canyu", "qualify", nil, nil, nil, nil, {actid = Manager.DC_ACT_ID})
    end
end

function Manager:dcJoin()
    if not self:getFlagFromLocalByKey("hasDcJoin", true) then
        self:saveFlagToLocalByKey("hasDcJoin", true)
        self:dc("canyu", "join", nil, nil, nil, nil, {actid = Manager.DC_ACT_ID})
    end
end

function Manager:dcShowPanel(t1, t2, panelId)
    self:dc("show", "main_panel", t1, t2, nil, nil, {panel_id = panelId, actid = Manager.DC_ACT_ID})
end

function Manager:registerEvents()
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)
    _G.amfEC:registerNormal(NormalEvent.PASS_DAY, self.onActPassDay, self)

    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
end

-- 同步所有数据
function Manager:updateData(data, skipSaveLocal, fromServer)
    if not data then return end

    self:getLocalDataServer():fromServer(data,skipSaveLocal)
    self:updateIcon()
end

function Manager:isEnabled()
    local isEnable = self.localDataServer:isDataEnabled()
    -- log("isEnabled", isEnable)
    return isEnable
end

function Manager:checkTypeEnabled(giftType)
    if not self:isEnabled() then return false end
    if self:isCloseByNewGiftSystem(giftType) then
        return false
    end
    local isEnabled = false
    lua_switch(giftType){
        -- [Manager.GIFT_TYPE.ASSIST] = function ( ... )
        --     isEnabled = self:isAssistGiftEnabled()
        -- end,
        -- [Manager.GIFT_TYPE.INFADD5STEP] = function ( ... )
        --     isEnabled = self:isInfAdd5StepEnabled()
        -- end,
        [Manager.GIFT_TYPE.THREEFORONE] = function ( ... )
            isEnabled = self:isThreeForOneEnabled()
        end,
        -- [Manager.GIFT_TYPE.CONTINUEBUY] = function ( ... )
        --     isEnabled = self:isContinueBuyEnabled()
        -- end,
        [Manager.GIFT_TYPE.BUYANDFREE] = function ( ... )
            isEnabled = self:isBuyAndFreeEnabled()
        end
    }
    return isEnabled
end

function Manager:isAssistGiftEnabled()
    if not self:getLocalDataServer():checkTypeDataEnabled(Manager.GIFT_TYPE.ASSIST) then
        return false
    end

    local serverVersion = self:getLocalDataServer():getClientControlVersion(Manager.GIFT_TYPE.ASSIST)
    if serverVersion == 0 or (serverVersion > Manager.CLIENTVERSION[Manager.GIFT_TYPE.ASSIST]) then
        return false
    end
    local endTime = self:getLocalDataServer():getActEndTime(Manager.GIFT_TYPE.ASSIST)
    local now = TimeKit:timeInSec()
    if endTime <= now then
        return false
    end
    return true
end

function Manager:isInfAdd5StepEnabled()
    if not self:getLocalDataServer():checkTypeDataEnabled(Manager.GIFT_TYPE.INFADD5STEP) then
        return false
    end

    local serverVersion = self:getLocalDataServer():getClientControlVersion(Manager.GIFT_TYPE.INFADD5STEP)
    if serverVersion == 0 or (serverVersion > Manager.CLIENTVERSION[Manager.GIFT_TYPE.INFADD5STEP]) then
        return false
    end
    local endTime = self:getLocalDataServer():getActEndTime(Manager.GIFT_TYPE.INFADD5STEP)
    local now = TimeKit:timeInSec()
    if endTime <= now then
        return false
    end
    return true
end

-- 新礼包系统关闭旧礼包 瀑布流单独拆出去了，三选一新旧共用一套代码
function Manager:isCloseByNewGiftSystem(giftType)
    if giftType == Manager.GIFT_TYPE.BUYANDFREE then
        if EnvUtil:isMiniGame() then
            return MaintenanceManager:getInstance():isEnabledInGroup("minigame_GiftPack", "ON_high")
        end
        return MaintenanceManager:getInstance():isEnabledInGroup("Gift_Pack_new", "ON")
    end
    return false
end

function Manager:isThreeForOneEnabled()
    if not self:getLocalDataServer():checkTypeDataEnabled(Manager.GIFT_TYPE.THREEFORONE) then
        return false
    end

    local serverVersion = self:getLocalDataServer():getClientControlVersion(Manager.GIFT_TYPE.THREEFORONE)
    if serverVersion == 0 or (serverVersion > Manager.CLIENTVERSION[Manager.GIFT_TYPE.THREEFORONE]) then
        return false
    end
    local endTime = self:getLocalDataServer():getActEndTime(Manager.GIFT_TYPE.THREEFORONE)
    local now = TimeKit:timeInSec()
    if endTime <= now then
        return false
    end

    if true then     -- if self:isOpenOnNewGiftpackage() then
       return self:getActInfo() ~= nil
    end
    return true
end

function Manager:isContinueBuyEnabled()
    if not self:getLocalDataServer():checkTypeDataEnabled(Manager.GIFT_TYPE.CONTINUEBUY) then
        return false
    end

    local serverVersion = self:getLocalDataServer():getClientControlVersion(Manager.GIFT_TYPE.CONTINUEBUY)
    if serverVersion == 0 or (serverVersion > Manager.CLIENTVERSION[Manager.GIFT_TYPE.CONTINUEBUY]) then
        return false
    end
    local endTime = self:getLocalDataServer():getActEndTime(Manager.GIFT_TYPE.CONTINUEBUY)
    local now = TimeKit:timeInSec()
    if endTime <= now then
        return false
    end
    return true
end

function Manager:isBuyAndFreeEnabled()
    if not self:getLocalDataServer():checkTypeDataEnabled(Manager.GIFT_TYPE.BUYANDFREE) then
        return false
    end

    local serverVersion = self:getLocalDataServer():getClientControlVersion(Manager.GIFT_TYPE.BUYANDFREE)
    if serverVersion == 0 or (serverVersion > Manager.CLIENTVERSION[Manager.GIFT_TYPE.BUYANDFREE]) then
        return false
    end
    local endTime = self:getLocalDataServer():getActEndTime(Manager.GIFT_TYPE.BUYANDFREE)
    local now = TimeKit:timeInSec()
    if endTime <= now then
        return false
    end
    return true
end

----------------------------- 功能函数 -----------------------------

function Manager:getLocalDataServer()
    return self.localDataServer
end

-- 预热期
function Manager:isActInPre(  )
    return self.localDataServer:isActInPre()
end

--是否是主活动期
function Manager:isInMainTime()
    return self.localDataServer:isActInMain()
end

--是否是领奖期
function Manager:isInRewardTime()
    return self.localDataServer:isActInReward()
end

-- 观察者
function Manager:addObserver(ob)
    self._observers[ob] = ob
    if ob.getPanelName and ob:getPanelName() == "MainPanel" then
        self:setMainPanel(ob)
    end
end

function Manager:removeObserver(ob)
    if self._observers[ob] then
        self._observers[ob] = nil
    end
    if ob.getPanelName and ob:getPanelName() == "MainPanel" then
        self:setMainPanel(nil)
    end
end

function Manager:notify(eventName, ...)
    if eventName == self.Events.kCloseAllPanel then
        local mainPanel = self:getMainPanel()
        if mainPanel and mainPanel['on' .. eventName] then
            mainPanel['on' .. eventName](mainPanel, ...)
        end
    end
    for _, ob in pairs(self._observers) do
        if not ob.isDisposed and ob['on' .. eventName] then
            ob['on' .. eventName](ob, ...)
        end
    end
end

function Manager:setActModel(model)
    self.model = model
end

--设置主面板
function Manager:setMainPanel(panel)
    self.mainPanel = panel
end

function Manager:getMainPanel()
    if self.mainPanel and not self.mainPanel.isDisposed then
        return self.mainPanel
    end
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
function Manager:saveFlagToLocalByKey(key, needTime, bool)
    if not key then return end
    if bool == nil then bool = true end
    local keyStr = self:getLocalKey(key, needTime)
    self.localDataServer:setCache(keyStr, bool)
end

function Manager:getFlagFromLocalByKey(key, needTime)
    local keyStr = self:getLocalKey(key, needTime)
    return self.localDataServer:getCache(keyStr) or false
end

-- 本地int缓存
function Manager:addIntToLocalByKey(key, needTime, addNum)
    if not key then return end
    if addNum == nil then addNum = 1 end
    local keyStr = self:getLocalKey(key, needTime)
    local beforeNum = self.localDataServer:getCache(keyStr) or 0
    self.localDataServer:setCache(keyStr, beforeNum + addNum)
end

function Manager:setIntToLocalByKey(key, needTime, setNum)
    if not key then return end
    if setNum == nil then setNum = 0 end
    local keyStr = self:getLocalKey(key, needTime)
    self.localDataServer:setCache(keyStr, setNum)
end

function Manager:getIntFromLocalByKey(key, needTime)
    local keyStr = self:getLocalKey(key, needTime)
    return self.localDataServer:getCache(keyStr) or 0
end

-- 本地string缓存
function Manager:setStringToLocalByKey(key, needTime, str)
    if str == nil then str = "" end
    local keyStr = self:getLocalKey(key, needTime)
    self.localDataServer:setCache(keyStr, str)
end

function Manager:getStringFromLocalByKey(key, needTime)
    local keyStr = self:getLocalKey(key, needTime)
    return self.localDataServer:getCache(keyStr) or ""
end

-- 是否是活动正式期最后一天
function Manager:isLastDay(  )
    local todayStartTime = getDayStartTimeByTS(TimeKit:timeInSec())
    local lastDayStartTime = getDayStartTimeByTS(self.localDataServer:getActMainEndTime())
    return todayStartTime == lastDayStartTime
end

-- 获取服务器时间是活动周期内的第几天
function Manager:getDayFromActOpen( time )
    if not self:isEnabled() then return 0 end
    local startTime = getDayStartTimeByTS(self.localDataServer:getActMainBeginTime())
    local curTime = getDayStartTimeByTS(time or TimeKit:timeInSec())
    return math.floor((curTime-startTime)/86400)+1
end

-- 获取从1970.1.1开始服务器时间是第几天
function Manager:getDayFrom1970( time )
    local curDayStartTime = getDayStartTimeByTS(time or TimeKit:timeInSec())
    return math.ceil(curDayStartTime/86400)
end

-- 检测引导标记
function Manager:hasGuideIndex(index, checkLocalData)
    local hasIndex = self:getLocalData():hasGuide(index)
    return hasIndex
end

-- 设置引导标记
function Manager:addGuideIndex(index, needSaveLocal)
    self:getLocalData():setGuide(index)
end

-- 打点
function Manager:dc(category, subCategory, t1, t2, t3, t4, extraData)
    local params = {
        game_type = "stage",
        game_name = Manager.GAME_NAME,
        category = category,
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

function Manager:openActivity(giftType, extra, userClick, closeCallback)
    self:_requestMainInfo(giftType, function ( data )
        self:openMainPanel(giftType, extra, userClick, closeCallback)
    end, closeCallback, closeCallback, false, userClick)
end

function Manager:getActivityIcon(giftType)
    local iconKey = self.ICONKEY[giftType]
    local icon = self.iconList[iconKey]
    if icon and not icon.isDisposed then
        return icon
    else
        return nil
    end
end

function Manager:isV2IconExperimentEnabled()
    local ok, enabled = pcall(function()
        local experiment = require(ICON_V2_EXPERIMENT_MODULE)
        return experiment:isEnabled()
    end)
    return ok and enabled == true
end

function Manager:shouldUseThreeForOneIconV2(giftType)
    return giftType == self.GIFT_TYPE.THREEFORONE
        and self:isOpenOnNewGiftpackage()
        and self:isV2IconExperimentEnabled()
end

function Manager:createLegacyActivityIcon(giftType, path)
    local NewbieGiftIcon = require "amf.feature.localactivity.newbiegiftoptimize.NewbieGiftIcon"
    local icon = NewbieGiftIcon:create(giftType, path)
    local iconKey = self.ICONKEY[giftType]
    icon:setTouchFunc(function()
        log("icon touch", iconKey)
        self:openActivity(giftType, {}, true)
    end)
    return icon
end

function Manager:createThreeForOnePackageIconAdapter()
    local adapterLoaded, PackageIconV2Adapter = pcall(
        require,
        "amf.feature.mainscene.module.icon.v2.runtime.PackageIconV2Adapter"
    )
    if not adapterLoaded or type(PackageIconV2Adapter.create) ~= "function" then
        return {
            state = ADAPTER_CREATE_SAFE_LEGACY,
            error = adapterLoaded and "NEWBIE_GIFT_CHOICE_ICON_V2_ADAPTER_CREATE_REQUIRED"
                or PackageIconV2Adapter,
        }
    end

    local giftType = self.GIFT_TYPE.THREEFORONE
    local configOk, options, provider = pcall(function()
        local IconV2Config = require(THREE_FOR_ONE_ICON_V2_CONFIG_MODULE)
        local configOptions, configProvider = IconV2Config.create(self, giftType, IconEventCenter)
        assert(type(configOptions) == "table", configProvider or "NEWBIE_GIFT_CHOICE_ICON_V2_CONFIG_REQUIRED")
        return configOptions, configProvider
    end)
    if not configOk then
        local path = self.ICONSPINE[giftType]
        local configError = options
        options = {
            ownerIconKey = self.ICONKEY[giftType],
            ownerIdentity = self,
            iconEventCenter = IconEventCenter,
            legacyFactory = function()
                return self:createLegacyActivityIcon(giftType, path)
            end,
            v2PreflightError = configError,
        }
        provider = nil
    end

    local createOk, adapter, modeOrError, cleanupOwner = pcall(
        PackageIconV2Adapter.create,
        PackageIconV2Adapter,
        options
    )
    if not createOk then
        return {
            state = ADAPTER_CREATE_WAIT_OWNER,
            error = adapter,
        }
    end
    if not adapter then
        return {
            state = ADAPTER_CREATE_WAIT_OWNER,
            error = modeOrError,
            cleanupOwner = cleanupOwner,
        }
    end
    return {
        state = ADAPTER_CREATE_READY,
        adapter = adapter,
        provider = provider,
        mode = modeOrError,
    }
end

function Manager:_disposeThreeForOneIconAdapter(reason)
    local adapter = self._threeForOneIconAdapter
    if not adapter then
        self._threeForOneIconAdapterRecoveryPending = false
        return true
    end
    local ok, disposed, disposeError = pcall(adapter.dispose, adapter)
    if not ok or disposed ~= true then
        self._threeForOneIconAdapterRecoveryPending = true
        log("dispose three-for-one icon adapter failed", reason, ok and disposeError or disposed)
        return false, ok and disposeError or disposed
    end
    self._threeForOneIconAdapter = nil
    self._threeForOneIconDataProvider = nil
    self._threeForOneIconAdapterRecoveryPending = false
    return true
end

function Manager:_recoverThreeForOneIconAdapter()
    if not self._threeForOneIconAdapterRecoveryPending then
        return true
    end
    local adapter = self._threeForOneIconAdapter
    if not adapter then
        self._threeForOneIconAdapterRecoveryPending = false
        return true
    end
    local cleanupRequired = true
    if type(adapter.needsDisposalRecovery) == "function" then
        local cleanupOk, required = pcall(adapter.needsDisposalRecovery, adapter)
        cleanupRequired = not cleanupOk or required == true
    end
    if not cleanupRequired and type(adapter.completeOwnerAdoption) == "function" then
        local adoptedOk, adopted = pcall(adapter.completeOwnerAdoption, adapter)
        if adoptedOk and adopted == true then
            if self._threeForOneIconAdapter ~= adapter then
                self._threeForOneIconAdapterRecoveryPending = false
                return true
            end
            local mountedOk, mounted = pcall(adapter.isMounted, adapter)
            if mountedOk and mounted == true then
                self._threeForOneIconAdapterRecoveryPending = false
                return true
            end
        end
    end
    local disposed = self:_disposeThreeForOneIconAdapter("recovery")
    if disposed then
        self.iconList[self.ICONKEY[self.GIFT_TYPE.THREEFORONE]] = nil
    end
    return disposed
end

function Manager:_adoptThreeForOneIconAdapter(createResult, giftType)
    local adapter = createResult.adapter or createResult.cleanupOwner
    if adapter then
        self._threeForOneIconAdapter = adapter
    end
    if createResult.state ~= ADAPTER_CREATE_READY then
        self._threeForOneIconDataProvider = nil
        self._threeForOneIconAdapterRecoveryPending = true
        log("three-for-one icon adapter owner pending", createResult.error)
        return nil
    end

    local readyOk, ready = pcall(adapter.isReadyForOwnerAdoption, adapter)
    local iconOk, icon = pcall(adapter.getIcon, adapter)
    if not readyOk or ready ~= true or not iconOk or not icon or icon.isDisposed then
        self._threeForOneIconDataProvider = nil
        self._threeForOneIconAdapterRecoveryPending = true
        log("three-for-one icon adapter not ready for owner adoption")
        return nil
    end

    icon.giftType = giftType
    self.iconList[icon.iconKey] = icon
    self._threeForOneIconDataProvider = createResult.mode == "v2" and createResult.provider or nil
    self._threeForOneIconAdapterRecoveryPending = false
    if createResult.mode == "v2" then
        if type(adapter.completeOwnerAdoption) ~= "function" then
            self._threeForOneIconAdapterRecoveryPending = true
            log("three-for-one icon adapter owner adoption required")
            return nil
        end
        local adoptedOk, adopted, adoptError = pcall(adapter.completeOwnerAdoption, adapter)
        if not adoptedOk or adopted ~= true then
            self._threeForOneIconAdapterRecoveryPending = true
            log("three-for-one icon adapter owner adoption failed", adoptedOk and adoptError or adopted)
            return nil
        end
        if self._threeForOneIconAdapter ~= adapter then
            return nil
        end
    end
    self:dcQualify()
    return icon
end

function Manager:refreshActivityIcon(giftType)
    if giftType == self.GIFT_TYPE.THREEFORONE
        and self._threeForOneIconAdapterRecoveryPending
        and not self:_recoverThreeForOneIconAdapter() then
        return false
    end
    local icon = self:getActivityIcon(giftType)
    if not icon then return false end
    if giftType == self.GIFT_TYPE.THREEFORONE and self._threeForOneIconAdapter then
        local activeOk, active = pcall(
            self._threeForOneIconAdapter.isV2Active,
            self._threeForOneIconAdapter
        )
        if activeOk and active == true then
            local ok, refreshed, refreshError = pcall(
                self._threeForOneIconAdapter.refresh,
                self._threeForOneIconAdapter,
                "newbie_gift_update"
            )
            if not ok or refreshed == false then
                log("refresh three-for-one icon adapter failed", ok and refreshError or refreshed)
                return false
            end
            return true
        end
    end
    if type(icon.updateIcon) == "function" then
        icon:updateIcon()
    end
    return true
end

-- 获取指定商品单价
function Manager:getPrice(goodsId)
    if not goodsId or goodsId == 0 then return 0 end
    local goodsObj = GoodsManager:getGoods(goodsId)
    if not goodsObj then return 0 end
    local moneyType = goodsObj:getMoneyType()
    return goodsObj:getPrice(), moneyType == MoneyType.kRmb, goodsObj:getDiscount() / 10, goodsObj:getOriginPrice()
end

---------------------------------- 加道具 ----------------------------------
function Manager:getDcFeatureAndSource(suffix)
    suffix = suffix or 0
    return "activity", "act_" .. Manager.ACT_ID .. "_" .. tostring(suffix)
end

-- 购买专用addRewards
-- 如果没goodsId，别用这个函数
-- 有rewardItems就按rewardItems走，没有就直接取goodsId的items
-- 注意，只有没配items才用rewardItems，否则会有问题
function Manager:addRewardsWhenBought(goodsId, rewardItems, params)
    if not goodsId then
        if EnvUtil:isDevelopMode() then
            CommonTip:showTip("没传goodsId")
        end
        return
    end

    params = params or {}
    params.dontNeedAddNormal = true
    params.fromBought = true

    -- 按约定俗成新规走了，如果配了rmb就是rmb购买，没配就不是
    local goodsObj = GoodsManager:getGoods(goodsId)
    local isRmb = goodsObj:getMoneyType() == MoneyType.kRmb
    local items = goodsObj:getItems()

    --
--
--
--
--


    -- 有 rewardItems，截断
    if rewardItems then
        items = rewardItems
        params.dontNeedAddNormal = false
        self:_addRewards(items, isRmb and DcPayType.kRmb or DcPayType.kGold , params)
        return
    end

    local useRewards = {}
    local addRewards = {}
    for _,v in ipairs(items) do
        if self:_checkIsSpecialItem(v) then
            table.insert(addRewards,v)
        else
            table.insert(useRewards,v)
        end
    end

    self:_addRewards(addRewards, isRmb and DcPayType.kRmb or DcPayType.kGold , params)
end

-- 普通的addRewards,开宝箱之类的
function Manager:addRewardsNormal(rewardItems, params)
    self:_addRewards(rewardItems, nil, params)
end

-- 检测是普通的还是特殊的
function Manager:_checkIsSpecialItem(rewardItem)
    local itemId = rewardItem.itemId
    -- 购买的话，会自动帮你加items里配的普通道具，特殊道具需要自己加（除了10001~19999，2，14都是特殊道具）
    if _G.amfBean("PropManager"):isPropNeedToBeAdd(itemId) then return false end
    if itemId == UPropId.GOLD or itemId == UPropId.COIN then return false end

    return true
end

-- 不要调用，但需要修改业务逻辑相关添加
function Manager:_addRewards(rewardItems, payType, params)
    local dcFeature, dcSource
    if params.dcFeature and params.dcSource then
        dcFeature = params.dcFeature
        dcSource = params.dcSource
    else
        dcFeature, dcSource = self:getDcFeatureAndSource(params and params.DCSourceExt or nil)
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

function Manager:createIcon(reward)
    local icon
    icon = GameItemCreator:getPropIcon(reward)
    return icon
end

--------------------------强弹相关--------------------------
function Manager:onActEnterMainScene(evt)
    if not self:isEnabled() then return end
    local param = evt:getData()
    if param.firstEnter then
        --场景2强弹
        for _, type in pairs(self.GIFT_TYPE) do
            local checkRes = self:checkNeedAutoPopout(type, 2)
            if checkRes ~= false then
                local function onHandleOver()
                    AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.NEWBIEOPTIMIZE_STAGE)
                end
                local creator = function ( ... )
                    printx("33", "kNewbieGiftOptimizeStage2", "popup", type)
                    self:doAutoPopout(type, checkRes, onHandleOver)
                end
                _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.NEWBIEOPTIMIZE_STAGE, creator)
            end
        end
    end
end

function Manager:onActEnterStage3()
    if not self:isEnabled() then return end
    for _, type in pairs(self.GIFT_TYPE) do
        local checkRes = self:checkNeedAutoPopout(type, 3)
        if checkRes ~= false then
            local function onHandleOver()
                AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.NEWBIEOPTIMIZE_STAGE)
            end
            local creator = function ( ... )
                printx("33", "kNewbieGiftOptimizeStage3", "popup", type)
                self:doAutoPopout(type, checkRes, onHandleOver)
            end
            _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.NEWBIEOPTIMIZE_STAGE, creator)
        end
    end
end

function Manager:onActEnterStage4()
    if not self:isEnabled() then return end
    for _, type in pairs(self.GIFT_TYPE) do
        local checkRes = self:checkNeedAutoPopout(type, 4)
        if checkRes ~= false then
            local function onHandleOver()
                AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.NEWBIEOPTIMIZE_STAGE)
            end
            local creator = function ( ... )
                printx("33", "kNewbieGiftOptimizeStage4", "popup", type)
                self:doAutoPopout(type, checkRes, onHandleOver)
            end
            _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.NEWBIEOPTIMIZE_STAGE, creator)
        end
    end
end

function Manager:getIconShowTipText(giftType, lowEnergy)
    local tipList = Meta.IconTipText[giftType]
    if tipList then
        return tipList[lowEnergy and 2 or 1]
    end
end

function Manager:checkIconTip(config)
    if not self:isEnabled() then return end
    local lowEnergy = Meta.checkRemainEnergy(nil, 5)

    local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")
    for _, v in pairs(self.iconList) do
        IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, {
            iconKey = v.iconKey,
            iconType = IconTipType.MESSAGE,
            typeIndex = 1,
            creatorDelegate = {
                tipsType = HomeIconTipsType.ONLY_TEXT,
                text = self:getIconShowTipText(v.giftType, lowEnergy),
            },
            popFunc = function()
            end,
            config = config
        })
    end
end

-- 重玩不算失败
-- function Manager:onActBeforePlayAgainLevel(data)
--     if not self:isEnabled() then return end
--     self:onActFailLevel(data)
-- end

function Manager:onActPlayLevelEnd(evt)
    if not self:isEnabled() then return end
    local param = evt:getData()
    if param.isWin then
        self:resetContinueFailCount()
    else
        self:addContinueFailCount()
    end
end

function Manager:addContinueFailCount()
    -- if not self.continueFailCount then
    --     self.continueFailCount = 0
    -- end
    -- self.continueFailCount = self.continueFailCount + 1
    self:addIntToLocalByKey("ContinueFailCount", false, 1)
end

function Manager:resetContinueFailCount()
    -- self.continueFailCount = 0
    self:setIntToLocalByKey("ContinueFailCount", false, 0)
end

function Manager:getContinueFailCount()
    -- return self.continueFailCount
    return self:getIntFromLocalByKey("ContinueFailCount", false) or 0
end

function Manager:getOpenIdx(giftType)
    return self:getLocalDataServer():getOpenIdx(giftType)
end

function Manager:getLastPopoutTime(giftType)
    local openIdx = self:getOpenIdx(giftType)
    return self:getIntFromLocalByKey("LastPopoutTime"..openIdx..giftType, false)
end

function Manager:setOnPopout(giftType)
    local now = TimeKit:timeInSec()
    local openIdx = self:getOpenIdx(giftType)
    self:setIntToLocalByKey("LastPopoutTime"..openIdx..giftType, false, now)
end

function Manager:checkNeedAutoPopout(giftType, sceneType)
    if not self:checkTypeEnabled(giftType) then return false end
    local config = self:getAutoPopoutConfig(giftType)
    if not config or table.isEmpty(config) then
        log("checkNeedAutoPopout config is empty", giftType)
        return false
    end

    -- 强弹时间
    local autoPopoutCd = config.autoPopoutCd
    local lastPopTime = self:getLastPopoutTime(giftType)
    if (TimeKit:timeInSec()-lastPopTime) < autoPopoutCd*3600 then
        log("checkNeedAutoPopout time in cd", giftType, TimeKit:timeInSec(), lastPopTime, autoPopoutCd)
        return false
    end

    -- 条件
    local conditionList = config.conditionList
    local AutoPopDefinition = Meta.AutoPopDefinition
    local conditionMetaList = config.conditionMetaList
    -- log("checkNeedAutoPopout condition check", giftType, tts(conditionList), sceneType)
    for i, conditionId in ipairs(conditionList) do
        local conditionMeta = conditionMetaList[conditionId] or {}
        local sceneId = conditionMeta.sceneId
        if sceneId == sceneType then
            local value = conditionMeta.conditionValue or 0
            local id = conditionMeta.conditionId
            if AutoPopDefinition[id] then
                local checkFunc = AutoPopDefinition[id]
                local res = checkFunc(giftType, value)
                if res ~= false then
                    log("checkNeedAutoPopout condition check pass", giftType, res)
                    return res
                end
            end
        end
    end
    return false
end

function Manager:doAutoPopout(giftType, autoPopType, callback)
    self:openActivity(giftType, {panel_source = autoPopType}, false, callback)
    self:setOnPopout(giftType)
end

function Manager:getAutoPopoutConfig(giftType)
    local config = {}
    local conditionMetaList = self:getLocalDataServer():getDataByKey(giftType, "strongPushTable", {})
    local autoPopoutCd = self:getLocalDataServer():getDataByKey(giftType, "strongPushCdH", 999)
    local conditionList = self:getLocalDataServer():getDataByKey(giftType, "strongPushConditionList", {})
    config.autoPopoutCd = autoPopoutCd
    config.conditionList = conditionList
    config.conditionMetaList = conditionMetaList
    return config
end

------------------------------------------------------------

function Manager:getActInfo()
    return self.activityManager:getActInfo(Manager.ACT_ID)
end

function Manager:onActActInfoUpdate(evt)
    local data = evt:getData()
    if not data.fromServer then return end
    local actInfo = self:getActInfo()
    if actInfo and actInfo.extra then
        -- printx(33, "onActActInfoUpdate", tts(actInfo))
        local extra = table.deserialize(actInfo.extra)
        if extra then
            self:newGiftpackageActInfoExtra(extra)
            self:getLocalDataServer():syncFromActInfo(extra)
        end
        if not self.lightStartDataValid then
            for _, type in pairs(self.GIFT_TYPE) do
                if self:getLocalDataServer():checkTypeDataEnabled(type) then
                    self:requestLightStart(function()
                        self.lightStartDataValid = true
                        self:updateIcon()
                    end)
                    break
                end
            end
        end
    end
    self:updateIcon()
end

function Manager:onActPassDay()
    local hasPanel = false
    for i, v in pairs(self._observers) do
        if not v.isDisposed then
            hasPanel = true
            break
        end
    end
    local now = TimeKit:timeInSec()
    local isPassActEnd = false
    for i, type in ipairs(self.GIFT_TYPE) do
        if self:checkTypeEnabled(type) then
            local endTime = self:getActEndTime(type)
            -- 跨天的同时也跨期
            if math.abs(endTime - now) <= 2 then
                isPassActEnd = true
                break
            end
        end
    end
    if hasPanel then
        if not isPassActEnd then
            self:notify(self.Events.kCloseAllPanel)
            CommonTip:showTip("新的一天开始了，数据已更新，请尝试重进活动~")
        end
    end
end

-- 有新礼包更新时重新发lightStart协议
function Manager:setHasNewGiftValid()
    self.lightStartDataValid = false
end

function Manager:checkIconUpdating(giftType)
    if not self.updateIconList then
        self.updateIconList = {}
    end
    return self.updateIconList[giftType]
end

function Manager:setIconUpdating(giftType, updating)
    if not self.updateIconList then
        self.updateIconList = {}
    end
    self.updateIconList[giftType] = updating
end

function Manager:shouldCreateActivityIcon(giftType)
    if self:checkTypeEnabled(giftType) ~= true then
        return false
    end
    if giftType == self.GIFT_TYPE.THREEFORONE and self:shouldUseThreeForOneIconV2(giftType) then
        return (tonumber(self:getGiftIconEndTime(giftType)) or 0) > 0
    end
    return true
end

function Manager:updateIcon()
    for k, v in pairs(self.GIFT_TYPE) do
        if self:shouldCreateActivityIcon(v) then
            if not self:getActivityIcon(v) then
                self:createActivityIcon(v)
                local endTime = self:getGiftIconEndTime(v)
                if not self:getFlagFromLocalByKey("dpJoin"..v..endTime) then
                    self:saveFlagToLocalByKey("dpJoin"..v..endTime)
                    self:dc("sprog_icebreaking", "join")
                end
            else
                if v == self.GIFT_TYPE.THREEFORONE then
                    self:refreshActivityIcon(v)
                else
                    self:getActivityIcon(v):updateIcon()
                end
            end
        else
            self:removeActivityIcon(self:getActivityIcon(v), v)
        end
    end
end

function Manager:createActivityIcon(giftType)
    if not self:shouldCreateActivityIcon(giftType) then
        return
    end
    local iconKey = self.ICONKEY[giftType]
    if self._threeForOneIconAdapterRecoveryPending
        and not self:_recoverThreeForOneIconAdapter() then
        return
    end
    if self.iconList[iconKey] then
        return
    end
    if self:checkIconUpdating(giftType) then
        return
    end
    self:setIconUpdating(giftType, true)
    log("createActivityIcon", iconKey)
    local path = self.ICONSPINE[giftType]
    local preloadFiles = { path }
    local useThreeForOneIconV2 = self:shouldUseThreeForOneIconV2(giftType)
    if useThreeForOneIconV2 then
        local configLoaded, IconV2Config = pcall(require, THREE_FOR_ONE_ICON_V2_CONFIG_MODULE)
        if configLoaded and type(IconV2Config.getPreloadFiles) == "function" then
            local preloadOk, v2PreloadFiles = pcall(IconV2Config.getPreloadFiles, path)
            if preloadOk and type(v2PreloadFiles) == "table" and #v2PreloadFiles > 0 then
                preloadFiles = v2PreloadFiles
            end
        end
    end
    local onLoadFailed
    if giftType == self.GIFT_TYPE.THREEFORONE then
        onLoadFailed = function(loadError)
            log("load icon asset failed", iconKey, loadError)
            self:setIconUpdating(giftType, false)
        end
    end
    _G.amfBean("AssetsUtil"):loadMiniFiles(preloadFiles):next(function()
        if not self:shouldCreateActivityIcon(giftType) then
            self:setIconUpdating(giftType, false)
            return
        end
        if useThreeForOneIconV2 then
            local createResult = self:createThreeForOnePackageIconAdapter()
            if createResult.state == ADAPTER_CREATE_SAFE_LEGACY then
                local icon = self:createLegacyActivityIcon(giftType, path)
                IconEventCenter:addIconEvent(icon)
                self.iconList[iconKey] = icon
            else
                self:_adoptThreeForOneIconAdapter(createResult, giftType)
            end
        else
            local icon = self:createLegacyActivityIcon(giftType, path)
            IconEventCenter:addIconEvent(icon)
            self.iconList[iconKey] = icon
        end
        self:setIconUpdating(giftType, false)
    end, onLoadFailed)
end

function Manager:removeActivityIcon(icon, giftType)
    local isThreeForOne = giftType == self.GIFT_TYPE.THREEFORONE
        or (icon and icon.iconKey == self.ICONKEY[self.GIFT_TYPE.THREEFORONE])
    if isThreeForOne and self._threeForOneIconAdapter then
        local disposed = self:_disposeThreeForOneIconAdapter("activity_removed")
        if disposed then
            self.iconList[self.ICONKEY[self.GIFT_TYPE.THREEFORONE]] = nil
        end
        return disposed
    end
    if icon and not icon.isDisposed then
        log("removeIcon", icon.iconKey)
        self.iconList[icon.iconKey] = nil
        IconEventCenter:removeIconEvent(icon.iconKey)
    end
end

function Manager:clearActInfoAndUpdateIcon(giftType)
    self:getLocalDataServer():clearGiftTypeData(giftType)
    self:updateIcon()
end

function Manager:getGiftIconEndTime(giftType)
    return self:getLocalDataServer():getActEndTime(giftType)
end

function Manager:getGiftIconLabelText(giftType)
    if giftType == self.GIFT_TYPE.ASSIST then
        if self:checkNeedShow640() then
            return "新手礼包"
        else
            return self.ICONNAME[giftType] or ""
        end
    else
        return self.ICONNAME[giftType] or ""
    end
end

function Manager:openMainPanel(giftType, extra, userClick, closeCallback)
    local delegate = {
        giftType = giftType,
        panel_source = extra.panel_source,
        userClick = userClick,
        closeCallback = closeCallback,
    }
    if giftType == self.GIFT_TYPE.ASSIST then
        self:openPanel("AssistGiftPanelVM", delegate)
    elseif giftType == self.GIFT_TYPE.INFADD5STEP then
        self:openPanel("AssistGiftPanelVM", delegate)
    elseif giftType == self.GIFT_TYPE.THREEFORONE then
        self:openPanel("ThreeForOnePanelVM", delegate)
    elseif giftType == self.GIFT_TYPE.CONTINUEBUY then
        self:openPanel("ContinueBuyPanelVM", delegate)
    elseif giftType == self.GIFT_TYPE.BUYANDFREE then
        self:openPanel("BuyAndFreePanelVM", delegate)
    end
end

function Manager:openPanel(panelName, delegate)
    local ShowPanelVM = require_debug("amf.feature.localactivity.newbiegiftoptimize.view."..panelName)
    local panel = ShowPanelVM.Builder.new()
    :setCloseCallback(delegate.closeCallback)
    :setGiftType(delegate.giftType)
    :setPanelSource(delegate.panel_source)
    :setUserClick(delegate.userClick)
    :build()
    self:managePanel(panel)
    panel:popout()
end

function Manager:managePanel(panel)
    self:addObserver(panel)
    panel.onCloseAllPanel = function()
        if not panel or panel.isDisposed then return end
        panel:close()
        self:removeObserver(panel)
    end
end

function Manager:requestLightStart(successCallback)
    self:_requestMainInfo(nil, successCallback, nil, nil, true, false)
end

function Manager:_requestMainInfo(giftType, onSuccessCallback, onFailCallback, onCancelCallback, bFromLightStart, userClick)
    --新版礼包系统
    if self:isOpenOnNewGiftpackage() then
        self._newbieGiftNewGiftpackage:requestMainInfo(giftType, onSuccessCallback, onFailCallback, onCancelCallback, bFromLightStart, userClick)
    else
        HttpRequest:requestMainInfo(giftType, onSuccessCallback, onFailCallback, onCancelCallback, bFromLightStart, userClick)
    end
end

-----------------------------礼包相关---------------------------
function Manager:checkGoodsReachLimitBuyTime(giftType, goodsId)
    local goodsLimitTime = self:getGoodsLimitTime(giftType, goodsId)
    if goodsLimitTime == 0 then
        printx(33, "checkGoodsReachLimitBuyTime goods no limit", giftType, goodsId)
        return false
    end
    local goodsBuyTime = self:getGoodsBuyTime(giftType, goodsId)
    printx(33, "checkGoodsReachLimitBuyTime", giftType, goodsId, goodsLimitTime, goodsBuyTime)
    return goodsBuyTime >= goodsLimitTime
end

-- return limitTime, isPermanentLimit
function Manager:getGoodsLimitTime(giftType, goodsId)
    if goodsId == 640 then
        return 1
    end
    local giftPackMetaBeanList = self:getLocalDataServer():getDataByKey(giftType, "giftPackMetaBeanList", {})
    local gotGiftPackTimesMap = self:getLocalDataServer():getDataByKey(giftType, "gotGiftPackTimesMap", {})
    local permanentGotGiftPackTimesMap = self:getLocalDataServer():getDataByKey(giftType, "permanentGotGiftPackTimesMap", {})
    for i, meta in pairs(giftPackMetaBeanList) do
        if goodsId == meta.goodsId then
            local limitBuyTimes = meta.limitBuyTimes
            local permanentLimitBuyTimes = meta.permanentLimitBuyTimes
            if limitBuyTimes == 0 and permanentLimitBuyTimes == 0 then
                return 0, false
            end

            if limitBuyTimes > 0 then
                return limitBuyTimes, false
            end

            if permanentLimitBuyTimes > 0 then
                return permanentLimitBuyTimes, true
            end
        end
    end
    return 0, false
end

function Manager:getGoodsBuyTime(giftType, goodsId)
    if goodsId == 640 then
        return self:checkCanBuy640() and 0 or 1
    end
    local gotGiftPackTimesMap = self:getLocalDataServer():getDataByKey(giftType, "gotGiftPackTimesMap", {})
    local permanentGotGiftPackTimesMap = self:getLocalDataServer():getDataByKey(giftType, "permanentGotGiftPackTimesMap", {})
    if gotGiftPackTimesMap[tostring(goodsId)] and gotGiftPackTimesMap[tostring(goodsId)] > 0 then
        return gotGiftPackTimesMap[tostring(goodsId)]
    end
    if gotGiftPackTimesMap[tostring(goodsId)] and permanentGotGiftPackTimesMap[tostring(goodsId)] > 0 then
        return permanentGotGiftPackTimesMap[tostring(goodsId)]
    end
    return 0
end

function Manager:addGoodsBuyTime(giftType, goodsId)
    if goodsId == 640 then
        self:setHasBuy640()
        return
    end
    local giftPackMetaBeanList = self:getLocalDataServer():getDataByKey(giftType, "giftPackMetaBeanList", {})
    local gotGiftPackTimesMap = self:getLocalDataServer():getDataByKey(giftType, "gotGiftPackTimesMap", {})
    local permanentGotGiftPackTimesMap = self:getLocalDataServer():getDataByKey(giftType, "permanentGotGiftPackTimesMap", {})
    for i, meta in pairs(giftPackMetaBeanList) do
        if goodsId == meta.goodsId then
            local limitBuyTimes = meta.limitBuyTimes
            local permanentLimitBuyTimes = meta.permanentLimitBuyTimes
            if limitBuyTimes == 0 and permanentLimitBuyTimes == 0 then
                return
            end

            if limitBuyTimes > 0 then
                if gotGiftPackTimesMap[tostring(goodsId)] then
                    gotGiftPackTimesMap[tostring(goodsId)] = gotGiftPackTimesMap[tostring(goodsId)] + 1
                else
                    gotGiftPackTimesMap[tostring(goodsId)] = 1
                end
                self:getLocalDataServer():setDataByKey(giftType, "gotGiftPackTimesMap", gotGiftPackTimesMap)
                return
            end

            if permanentLimitBuyTimes > 0 then
                if permanentGotGiftPackTimesMap[tostring(goodsId)] then
                    permanentGotGiftPackTimesMap[tostring(goodsId)] = permanentGotGiftPackTimesMap[tostring(goodsId)] + 1
                else
                    permanentGotGiftPackTimesMap[tostring(goodsId)] = 1
                end
                self:getLocalDataServer():setDataByKey(giftType, "permanentGotGiftPackTimesMap", permanentGotGiftPackTimesMap)
                return
            end
        end
    end
end

-- 购买助力/无限加五步/新手礼包后处理
function Manager:afterBuyGiftProcess(giftType, goodsId, giftScene)
    printx(33, "afterBuyGiftProcess", giftType, goodsId, giftScene)
    if not giftType or not self:checkTypeEnabled(giftType) then return end
    local giftPackMetaBeanList = self:getLocalDataServer():getDataByKey(giftType, "giftPackMetaBeanList", {})
    for i, meta in pairs(giftPackMetaBeanList) do
        if goodsId == meta.goodsId then
            self:addGoodsBuyTime(giftType, goodsId)
        end
    end

    if giftType == self.GIFT_TYPE.ASSIST then
        local anchorGoodsId = self:getAssistAnchorGoodsId()
        if goodsId == 640 then
            self:setHasBuy640()
        end
        if goodsId ~= anchorGoodsId and giftScene ~= self.GIFT_SCENE.STORE then
            _G.Store2021Manager.getInstance():setBuyRookieFromOutside()
        end

        local anchorHasBuy
        if not anchorGoodsId then
            anchorHasBuy = true
        else
            anchorHasBuy = self:checkGoodsReachLimitBuyTime(giftType, anchorGoodsId)
        end

        local mainHasBuy
        if self:checkNeedShow640() then
            mainHasBuy = not self:checkCanBuy640()
        else
            local mainGoodsId = self:getAssistGiftGoodsId()
            mainHasBuy = self:checkGoodsReachLimitBuyTime(giftType, mainGoodsId)
        end

        if anchorHasBuy and mainHasBuy then
            self:clearActInfoAndUpdateIcon(giftType)
        end
    elseif giftType == self.GIFT_TYPE.INFADD5STEP then
        local hasBuy = self:checkGoodsReachLimitBuyTime(giftType, goodsId)
        if hasBuy then
            self:clearActInfoAndUpdateIcon(giftType)
        end
    end
end


---region 新版礼包系统接入 2025年12月15日 星期一

---新礼包系统活动 是否开启
function Manager:isOpenOnNewGiftpackage()
    return self._newbieGiftNewGiftpackage and self._newbieGiftNewGiftpackage:isOpen()
end

function Manager:newGiftpackageActInfoExtra(extra)
    if extra and self:isOpenOnNewGiftpackage() and extra.subInfos and not extra.giftPackActivityList then
        extra.giftPackActivityList = extra.subInfos
        for key, value in pairs(extra.giftPackActivityList) do
            if value and value.module then
                if value.module == "chooseOneFromThree2025" then
                    value.id = self.GIFT_TYPE.THREEFORONE
                else
                    -- printx(0, "新活动3076, 要求客户端自己做moudle和id的映射,", value.module)
                end
            end
        end
    end
end

---endregion



----------------------------------------------------------------
------------------------------- 助力礼包/无限加五步相关 ----------
--暂不移植
----------------------------------------------------------------

return Manager
