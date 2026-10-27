local ActivityName = "AliPayGameCenter"
local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local PackageIconV2Host = require "amf.feature.mainscene.module.icon.v2.runtime.PackageIconV2Host"

local Manager = class(ActivityName .. "Manager")
Manager.ACT_OPEN_VERSION = 1
Manager.ICON_KEY = "alipay_gamecenter"
local ICON_V2_EXPERIMENT_MODULE = "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"
local LEGACY_RESOURCE_LABEL = "alipay_gamecenter"
local ICON_V2_PATH = "amf/alipaygamecenter/icon/icon_v2.png"
-- Manager.customColorType = "Answer2024"
local Event = {
    CLOSE_ALL_PANEL = 'CloseAllPanel',    --关闭所有界面
    ENTER_FROM_GAME_CENTER = 'EnterFromGameCenter', --从游戏中心进入
    CHECK_ADD_STATUS = 'CheckAddStatus', --检查是否添加到首页结束
}

local PhaseType = {
    UNFINISH = 1,
    FINISH = 2,
    HASGOT = 3,
}

function Manager:log(...)
    if not EnvUtil:isDevelopMode() then return end
    if EnvUtil:isMiniGame() then
        UWarning(...)
    else
        printx(33, ...)
    end
end

local Meta = require('amf.feature.minihub.'..string.lower(ActivityName)..'.model.'..ActivityName..'Meta')
local Model = require('amf.feature.minihub.'..string.lower(ActivityName)..'.model.'..ActivityName..'Model')
function Manager:ctor()
    self.iconHost = PackageIconV2Host:create({
        owner = self,
        ownerIconKey = self.ICON_KEY,
        iconEventCenter = IconEventCenter,
        isEligible = function()
            return self:shouldShowMainIcon()
        end,
        isV2Enabled = function()
            return self:isV2IconExperimentEnabled()
        end,
        prepareLegacyAssets = function()
            return _G.amfBean("AssetsUtil"):loadMiniLabels({LEGACY_RESOURCE_LABEL})
        end,
        prepareV2Assets = function()
            return _G.amfBean("AssetsUtil"):loadMiniFiles({ICON_V2_PATH})
        end,
        createV2Options = function()
            local IconV2Config = require "amf.feature.minihub.alipaygamecenter.icon.IconV2Config"
            return IconV2Config:create(self, IconEventCenter)
        end,
        createLegacyIcon = function()
            return self:createLegacyIcon()
        end,
        refreshLegacy = function(icon)
            icon:updateIcon()
            return true
        end,
        preflightErrorPrefix = "ALIPAY_GAME_CENTER_V2_ASSET_LOAD_FAILED:",
        logError = function(stage, detail)
            self:log("AliPayGameCenter icon host failed", stage, detail)
        end,
    })
end

function Manager:initialize()
    self.model = Model:create()
    self:registerEvents()
    -- self:initCustomColorCfg()
end

function Manager:getModel()
    return self.model
end

function Manager:registerEvents()
    _G.amfEC:bindEventObserver(self, "onCustom")
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)
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

function Manager:initCustomColorCfg()
    local PanelColorConfig = require "amf.middleware.ui.config.PanelColorConfig"
    local defaultCfg = PanelColorConfig:getConfig("green")
    local customColorCfg = self.meta.CustomColorCfg
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

-- 同步所有数据
function Manager:updateData(data, skipSaveLocal)
    if not data then return end

    self:getModel():fromServer(data,skipSaveLocal)
end

-- 记得改造一下
function Manager:isEnabled()
    -- do return true end
    if EnvUtil:isALIPAYMiniGame() and EnvUtil:isMiniGameBrowser() then
        return false
    end
    local serverVersion = tonumber(self:getModel():getDataByKey("version", 999))
    if self.ACT_OPEN_VERSION < serverVersion then
        return false
    end
    return self:getModel():isDataEnabled()
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
    local str = string.format("%s_%s_%s_%s",_G.amfBean("ProfileManager"):getUid(),ActivityName,Manager.ACT_OPEN_VERSION,key)
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
-- 打点
function Manager:dc(category, subCategory, extraData)
    local params = {
        category = category,
        sub_category = subCategory,
    }

    for i, v in pairs(extraData or {}) do
        params[i] = v
    end
    DcUtil:UserTrack(params)
end

function Manager:getActivityIcon()
    return _G.amfBean("IconManager"):getIconByIconKey(tostring(Manager.ACT_ID))
end

function Manager:createIcon(reward)
    local icon
    icon = GameItemCreator:getPropIcon(reward)
    return icon
end

----------------------- 响应事件 -----------------------------
function Manager:getQueryParam()
    local enterScheme = LaunchUrlManager:getInstance():getCurrentUrl()
    -- self:log("getQueryParam", enterScheme)
    if not enterScheme or enterScheme == "" then return end
    local parsedScheme = table.deserialize(enterScheme)
    if not parsedScheme then return end

    --需要反序列化两次
    if type(parsedScheme) == "string" then
        parsedScheme = table.deserialize(parsedScheme)
        if not parsedScheme then return end
    end
    local query = parsedScheme.query
    return query
end

function Manager:onActPassDay()
    if not self:isEnabled() then return end
    self:notify(Event.CLOSE_ALL_PANEL)
end

function Manager:onSystemEnterForeground()
    -- self:log("aliPayGameCenter", "onSystemEnterForeground")
    if not self:isEnabled() then return end
    local missionId, missionPhase = self:getMissionStatus()
    -- 从外面返回后检查是否已添加到首页并刷新面板ui
    if missionId == 0 and missionPhase == PhaseType.UNFINISH then
        self:requestCheckHasAdd(function()
            self:notify(Event.CHECK_ADD_STATUS)
        end)
    elseif missionId ~= 0 and missionPhase == PhaseType.UNFINISH then
        local query = self:getQueryParam()
        -- self:log("aliPayGameCenter", "check has visit", tts(query))
        if not query then return end
        local sourceChannel = query.sourceChannel
        if sourceChannel and sourceChannel == "gamecenter" then
            self:requestSetHasVisit(missionId, function()
                self:notify(Event.ENTER_FROM_GAME_CENTER)
            end)
        end
    end
end

function Manager:onSystemEnterBackground()
    -- if not self:isEnabled() then return end

end

function Manager:onActEnterMainScene(evt)
    if EnvUtil:isALIPAYMiniGame() and EnvUtil:isMiniGameBrowser() then
        return false
    end
    local data = evt:getData()
    if data.firstEnter then
        if EnvUtil:isALIPAYMiniGame() then
            local query = self:getQueryParam()
            -- self:log(33, "aliPayGameCenter", "onActEnterMainScene", tts(query))
            -- 支付宝文档表示 gameCenterBackflow明确为false时表示隐藏设首复访任务
            if query and query.gameCenterBackflow == false then
                return
            end
            self:requestMainInfo()
        end
    end
end

function Manager:onActEnterStage4()
    if not self:isEnabled() then return end
    if _G.getTopLevelId() < 20 then return end
    if not MaintenanceManager:getInstance():isEnabledInGroup("ali_test","ON") then return end
    local missionId, missionPhase = self:getMissionStatus()
    if missionPhase == PhaseType.UNFINISH then
        local popupCheckPoint = missionId == 0 and PopupCheckPoint.ALIPAY_GAMECENTER_FIRST or PopupCheckPoint.ALIPAY_GAMECENTER_REVISIT
        local popNum = _G.amfBean("AutoPopupMgr"):getPermanentShowNum(popupCheckPoint)
        if popNum <= 0 then
            local function onHandleOver()
                AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, popupCheckPoint)
            end
            local creator = function ( ... )
                self:openActivity(false, onHandleOver)
                _G.amfBean("AutoPopupMgr"):sendPermanentData(popupCheckPoint)
            end
            _G.amfBean("AutoPopupMgr"):addPopupConfig(popupCheckPoint, creator)
        end
    end
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
    if _G.amfBean("PropManager"):isPropNeedToBeAdd(itemId) then return false end
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

---------------------------------- icon角标逻辑 ----------------------------------
-- 主icon奖字
function Manager:hasRewards()
    local missionId, missionPhase = self:getMissionStatus()
    return missionPhase == PhaseType.FINISH
end

-- 红点
function Manager:hasHint()
    local missionId, missionPhase = self:getMissionStatus()
    return missionPhase == PhaseType.UNFINISH
end

---------------------------------- 业务逻辑,新增函数都写在此后 ----------------------------------
function Manager:hasFinishAll()
    local missionId, missionPhase = self:getMissionStatus()
    local numOfCanFollowUpDay = self:getModel():getDataByKey("numOfCanFollowUpDay", 0)
    -- self:log(33, "hasFinishAll", missionId, numOfCanFollowUpDay, missionPhase)
    if missionId > numOfCanFollowUpDay then return true end
    return missionPhase == PhaseType.HASGOT and missionId == numOfCanFollowUpDay
end

function Manager:shouldShowMainIcon()
    return self:isEnabled() and not self:hasFinishAll()
end

function Manager:isV2IconExperimentEnabled()
    if EnvUtil:isUnityEditor() then
        return true
    end
    local experiment = require(ICON_V2_EXPERIMENT_MODULE)
    return experiment:isEnabled()
end

function Manager:updateMainIcon()
    return self.iconHost:reconcile("manager_update")
end

function Manager:getMainIcon()
    return self.iconHost:getIcon()
end

function Manager:addMainIcon()
    return self.iconHost:reconcile("manager_add")
end

function Manager:createLegacyIcon()
    local AliPayGameCenterIcon = require "amf.feature.minihub.alipaygamecenter.AliPayGameCenterIcon"
    return AliPayGameCenterIcon:create()
end

function Manager:removeMainIcon()
    return self.iconHost:dispose("manager_remove")
end

function Manager:onMainIconTapped()
    -- self:log(33, "aliPayGameCenter", "onMainIconTapped")
    self:openActivity(true)
end

function Manager:openActivity(userClick, closeCallback)
    local function onRequestSuccess(response)
        local AliPayGameCenterPanelVM = require_debug "amf.feature.minihub.alipaygamecenter.view.AliPayGameCenterPanelVM"
        local rewards = self:getShowRewards()
        local vm = AliPayGameCenterPanelVM.Builder.new()
        :setRewards(rewards)
        :setBubbleClickCall(function(delegate, bubbleSprite)
            local reward = {itemId = delegate.itemId, num = delegate.num}
            UITip.Builder.new()
            :setTarget(bubbleSprite)
            :setTitle(_G.amfBean("PropManager"):getPropName(reward))
            :build()
        end)
        :setNumLabelOutline(hex2ccc4("B2714AFF"), 3)
        :setUserClick(userClick)
        :setCloseCallback(function()
            self:updateMainIcon()
            safeRunCall(closeCallback)
        end)
        :build()
        vm:popout()
        self:managePanelVM(vm)
    end
    local function onRequestFail(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
            local errorCode = response:getErrorCode()
            if tonumber(errorCode) == 739433 then
                self:setDataByKey("open", false)
                self:updateMainIcon()
            end
        end
    end

    self:requestMainInfo(onRequestSuccess, onRequestFail, true)
end

function Manager:requestMainInfo(onRequestSuccess, onRequestFail, fromGame)
    self:getModel():requestMainInfo():next(function(response)
        if not fromGame then
            self:onSystemEnterForeground()
        end
        self:updateMainIcon()
        safeRunCall(onRequestSuccess, response)
    end, function(response)
        safeRunCall(onRequestFail, response)
    end)
end

function Manager:requestGetReward(type, index, successCallback, failCallback, cancelCallback)
    self:getModel():requestGetReward(type, index):next(function(response)
        local data = response:getData()
        local rewards = data.rewards or {}
        self:addRewardsNormal(rewards, {dcFeature = "zfb_login", dcSource = "main_panel_click"}) --todo
        safeRunCall(successCallback, rewards)
    end, function(response)
        if response:isCancel() then
            safeRunCall(cancelCallback)
        else
            CommonTip:showErrorTip(response)
            local errorCode = response:getErrorCode()
            safeRunCall(failCallback, errorCode)
        end
    end)
end

function Manager:requestCheckHasAdd(callback)
    -- self:log(33, "aliPayGameCenter", "requestCheckHasAdd")
    self:getModel():requestCheckHasAdd():next(function(response)
        local data = response:getData()
        local status = data.status or false
        self:updateMainIcon()
        safeRunCall(callback, status)
    end, function()
        local statusOfSetHomePage = self:getModel():getDataByKey("statusOfSetHomePage", false)
        safeRunCall(callback, statusOfSetHomePage)
    end)
end

function Manager:requestSetHasVisit(index, callback)
    self:getModel():requestSetHasVisit(index):next(function(response)
        self:updateMainIcon()
        safeRunCall(callback)
    end, function()
        safeRunCall(callback)
    end)
end

-- 返回值
-- 当前进行中的任务0设首，1~7复访 >=8 已结束
-- 任务状态 1未完成，2已完成 3已领取
function Manager:getMissionStatus()
    local dayOfSetHomePage = tonumber(self:getModel():getDataByKey("dayOfGetSetHomePageReward", 0))
    if dayOfSetHomePage == 0 then
        local statusOfSetHomePage = self:getModel():getDataByKey("statusOfSetHomePage", false)
        return 0, statusOfSetHomePage and PhaseType.FINISH or PhaseType.UNFINISH
    else
        local curDayStartTime = getDayStartTimeByTS(time or TimeKit:timeInSec())
        local numOfCanFollowUpDay = self:getModel():getDataByKey("numOfCanFollowUpDay", 0)
        local today = math.ceil(curDayStartTime/86400)
        local dayIdx = today - dayOfSetHomePage + 1
        if dayIdx > numOfCanFollowUpDay then
            return dayIdx, PhaseType.FINISH
        end
        local indexSetOfFollowedUp = self:getModel():getDataByKey("indexSetOfFollowedUp", {})
        if not table.exist(indexSetOfFollowedUp, dayIdx) then
            return dayIdx, PhaseType.UNFINISH
        end
        local indexSetOfHadReward = self:getModel():getDataByKey("indexSetOfHadReward", {})
        if not table.exist(indexSetOfHadReward, dayIdx) then
            return dayIdx, PhaseType.FINISH
        end
        return dayIdx, PhaseType.HASGOT
    end
end

function Manager:getShowRewards()
    local missionId, missionPhase = self:getMissionStatus()
    if missionId == 0 then
        return self:getModel():getDataByKey("rewardsOfSetHomePage", {})
    else
        return self:getModel():getDataByKey("rewardsOfFollowUp", {})
    end
end

-- 设首任务
function Manager:doAddToHomePage()
    local params = {
        appId = "2021003125685383",
        startParam = {
            chInfo = "gamesetlattice"
        }
    }
    local paramsJson = table.serialize(params)
    -- self:log("doAddToHomePage", paramsJson)
    CALL_EASY_JS_ASYNC("globalThis.animalPlugin.sdkManager.navigateToMiniProgram", function(result)
        local r = table.deserialize(result)
        -- self:log("doAddToHomePage", tts(r))
    end, paramsJson)
end

-- 设首(新链路)
function Manager:doAddToHomePageNew(onSuccess)
    CALL_EASY_JS_ASYNC("globalThis.animalPlugin.sdkManager.addGameCenterToMyApps", function(result)
        local r = table.deserialize(result) or {}
        self:log("doAddToHomePageNew", tts(r))
        if tonumber(r.errCode) == 0 then
            local data = r.data or {}
            if data.addAppToMyApps then
                self:getModel():setDataByKey("statusOfSetHomePage", true)
                safeRunCall(onSuccess)                
            end
        end
    end)
end

-- 复访任务
function Manager:doJumpGameCenter()
    -- local params = {
    --     appId = "2021003125685383",
    --     startParam = {
    --         chInfo = "returnvisit"
    --     }
    -- }
    -- local paramsJson = table.serialize(params)
    -- self:log("doJumpGameCenter", paramsJson)
    -- CALL_EASY_JS_ASYNC("globalThis.animalPlugin.sdkManager.navigateToMiniProgram", function(result)
    --     local r = table.deserialize(result)
    --     self:log("doJumpGameCenter", tts(r))
    -- end, paramsJson)

    local url = "alipays://platformapi/startapp?appId=2060090000285522&url=https%3A%2F%2Frender.alipay.com%2Fp%2Fyuyan%2F180020010001210691%2Findex.html%3FcaprMode%3Dsync&sourceAppId=2021003125685383&sourceUrl=alipays%3A%2F%2Fplatformapi%2Fstartapp%3FappId%3D2021003125685383%26url%3Dhttps%253A%252F%252Frender.alipay.com%252Fp%252Fyuyan%252F180020010001206617%252Findex.html%253FcaprMode%253Dsync%26chInfo%3Dreturnvisit%26sms%3DYES%26appClearTop%3Dfalse"
    if EnvUtil:isMiniGameIOS() then
        url = "alipays://platformapi/startapp?appId=2060090000285522&url=https%3A%2F%2Frender.alipay.com%2Fp%2Fyuyan%2F180020010001210691%2Findex.html%3FcaprMode%3Dsync&sourceAppId=2021003125685383&sourceUrl=alipays%3A%2F%2Fplatformapi%2Fstartapp%3FappId%3D2021003125685383%26url%3Dhttps%253A%252F%252Frender.alipay.com%252Fp%252Fyuyan%252F180020010001206617%252Findex.html%253FcaprMode%253Dsync%26chInfo%3Dreturnvisit%26sms%3DYES%26appClearTop%3Dfalse%26startMultApp%3DYES"
    end
    CALL_EASY_JS_ASYNC("globalThis.animalPlugin.sdkManager.openURL", function(result)
        local r = table.deserialize(result)
        -- self:log("doJumpGameCenter", tts(r))
    end, url)
end

return Manager
