local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local ActivityName = "LuckyBagParty"
local Manager = class(ActivityName.."Mgr")

----------- 可能需要修改start -----------
local LocalServer = require('amf.feature.localactivity.'..string.lower( ActivityName )..'.'..ActivityName..'LocalServer')
Manager.ACT_OPEN_VERSION = 1
Manager.ACT_ID = 6038
Manager.ACT_SOURCE = "luckybagparty/Config.lua"
Manager.ACT_CH_NAME = "福袋派对"
Manager.DCFeature = "activity"
Manager.DCSource = "act_"..Manager.ACT_ID .. "_0"
Manager.moveIcon = true

function Manager:log(...)
    printx(33, "***** luckyBagParty *****  ", ...)
end


function Manager:initialize()
    self.meta = require('amf.feature.localactivity.'..string.lower(ActivityName)..'.'..ActivityName..'Meta')
    self.localDataServer = LocalServer:create()

    self:registerEvents()
    -- self:initCustomColorCfg()
    self._observers = {}
end

function Manager:registerEvents()
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)

    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
end

function Manager:getLocalDataServer()
    return self.localDataServer
end

-- 同步所有数据
function Manager:updateData(data, skipSaveLocal, fromServer)
    if not data then return end

    self.localDataServer:fromServer(data,skipSaveLocal)

    if fromServer == true then
        self.hasGetDataFromServer = true
    end
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

--是否是主活动期
function Manager:isInMainTime()
    return self.localDataServer:isActInMain()
end

--是否是领奖期
function Manager:isInRewardTime()
    return self.localDataServer:isActInReward()
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

function Manager:getActInfo()
    return _G.amfBean("ActivityMgr"):getActInfo(Manager.ACT_ID)
end

-- 获取本地缓存的完整key
function Manager:getLocalKey(key, needTime)
    local str = string.format("%s_%s_%s_%s",_G.amfBean("UserManager"):getUid(),ActivityName,Manager.ACT_OPEN_VERSION,key)
    if needTime then
        local curTime = TimeKit:timeInSec()
        local dayStartTime = getDayStartTimeByTS(curTime)
        str = str .. ':' .. dayStartTime
    end
    return str
end

function Manager:setFlagToLocalByKey(key, needTime, value)
    if not key then return end
    if value == nil then value = true end
    local keyStr = self:getLocalKey(key, needTime)
    self:getLocalDataServer():setDataByKey(keyStr, value)
end

function Manager:getFlagFromLocalByKey(key, needTime)
    local keyStr = self:getLocalKey(key, needTime)
    return self:getLocalDataServer():getDataByKey(keyStr)
end

function Manager:addIntToLocalByKey(key, needTime, addNum)
    if not key then return end
    if addNum == nil then addNum = 1 end
    local keyStr = self:getLocalKey(key, needTime)
    local beforeNum = self:getLocalDataServer():getDataByKey(keyStr) or 0
    self:getLocalDataServer():setDataByKey(keyStr, beforeNum + addNum)
end

function Manager:setIntFromLocalByKey(key, needTime, setNum)
    if not key then return end
    if setNum == nil then setNum = 0 end
    local keyStr = self:getLocalKey(key, needTime)
    self:getLocalDataServer():setDataByKey(keyStr, setNum)
end

function Manager:getIntFromLocalByKey(key, needTime)
    local keyStr = self:getLocalKey(key, needTime)
    return self:getLocalDataServer():getDataByKey(keyStr) or 0
end

function Manager:setStringToLocalByKey(key, needTime, value)
    if not key then return end
    if value == nil then value = "" end
    local keyStr = self:getLocalKey(key, needTime)
    self:getLocalDataServer():setDataByKey(keyStr, value)
end

function Manager:getStringFromLocalByKey(key, needTime)
    local keyStr = self:getLocalKey(key, needTime)
    return self:getLocalDataServer():getDataByKey(keyStr) or ""
end

function Manager:isEnabled()
    local _, _, _, _, isOff = self:getGroup()
    local isEnabled = (not isOff) 
                        and self:getLocalDataServer():isDataEnabled() 
                            and self:isInMainTime()
                                and self:checkActSupport() 
                                    and self:checkVersionSupport() 
    self:log("self:isEnabled:", isEnabled, isOff, self:getLocalDataServer():isDataEnabled(), self:isInMainTime(), self:checkActSupport(), self:checkVersionSupport())
    return isEnabled
end

function Manager:openActivity(closeCallback, extra, userClick, duanMianData)
    ActivityEventCenter:dispatch(ActivityEvent.OPEN_ACTIVITY, {
        actId = Manager.ACT_ID,
        endCallback = closeCallback,
        failCallback = closeCallback,
        userClick = userClick,
        extra = extra,
        duanMianData = duanMianData
    })
end

-- 打点
function Manager:dc(category, subCategory, t1, t2, t3, t4, extraData)
    local params = {
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

function Manager:syncActInfo(actInfo)
    if actInfo == nil then
        self:setConfigSupportPassed(false)
        self:getLocalDataServer():clearAll()
        return        
    end
    local jsonExtra = table.deserialize(actInfo.extra)
    self:updateData(jsonExtra, nil, true)
end

function Manager:setActSupport(ActBeginTime) --本期活动部分校验通过标志
    self:getLocalDataServer():setDataByKey("ActIsSupport", ActBeginTime, true, true)
end

function Manager:checkActSupport()
    local saveTime = self:getLocalDataServer():getDataByKey("ActIsSupport", 0)
    return self.localDataServer:getActMainBeginTime() == saveTime
end

function Manager:checkVersionSupport()  -- 前后端版本校验
    self:log("serverSourceVersion: ", self.localDataServer:getSourceVersion(), "clientSourceVersion: ", self.ACT_OPEN_VERSION)
    return self.localDataServer:getSourceVersion() == self.ACT_OPEN_VERSION
end

-- 记录活动 Config.isSupport 是否完整通过；右下角迁移 icon 只读这个结果，避免直接 require 活动文件。
function Manager:setConfigSupportPassed(passed)
    local oldPassed = self.configSupportPassed == true
    self.configSupportPassed = passed == true
    if not oldPassed and self.configSupportPassed then
        self:refreshMovedIcon()
    end
end

-- 判断活动 Config.isSupport 是否已通过。
function Manager:hasConfigSupportPassed()
    return self.configSupportPassed == true
end

-- Config 首次通过 support 后，通知右下角 born icon 池重新扫描，补上此前因标记未就绪错过的创建机会。
function Manager:refreshMovedIcon()
    pcall(function()
        require "amf.feature.mainscene.module.icon.config.IconKey"
        local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
        local IconMeta = require "amf.feature.mainscene.module.icon.config.IconMeta"
        IconEventCenter:refreshIconPool(IconMeta.PoolType.kRightCorner, IconKey.kLuckyBagParty)
    end)
end

-- 倒计时结束解锁最高关刷新icon
function Manager:onActOnlineUnlockOver()
    if self:isEnabled() then
        self:log("onActOnlineUnlockOvers")
        self:updateActIconVisible()
    end
end

function Manager:onActPassLevel(event)
    if not self:isEnabled() then return end
    local data = event:getData()
    self:log("onActPassLevel")
    if data.levelType ~= GameLevelType.kMainLevel then return end
    if data.oldStar ~= 0 then return end
    if _G.amfBean("UserStateManager"):isFMJ() then return end
    self:log("set fullLevelButNeedShow")
    self.fullLevelButNeedShow = true
end

function Manager:onActActInfoUpdate()
    self:log("onActActInfoUpdate")
    local actInfo = self:getActInfo()
    self:syncActInfo(actInfo)
    self:updateActIconVisible()
end

function Manager:updateActIconVisible()
    if not self:isEnabled() then return end
    local hasNetWork = (_G.amfBean("NetworkStatusManager"):getNetworkStatus() ~= _G.NetworkConst.NetworkStatusDes.NONETWORK)
    local isFMJPlayer = _G.amfBean("UserStateManager"):isFMJ()
    self:log("isIconVisible : isEnabled", self:isEnabled(), "hasNetWork", hasNetWork, "isFMJPlayer", isFMJPlayer, "fullLevelButNeedShow", self.fullLevelButNeedShow)
    local newVisiblity = (self:isEnabled() and hasNetWork and (isFMJPlayer or self.fullLevelButNeedShow)) and true or false
    self:log("newVisiblity: ", newVisiblity)
    if self.isIconVisible ~= newVisiblity then
        self.updateActivities = true
        self.isIconVisible = newVisiblity
        self:tryBuildActivityButtons()
    end
end

function Manager:tryBuildActivityButtons(retryTimes)
    self:log("tryBuildActivityButtons")
    local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
    ActivityEventCenter:dispatch(ActivityEvent.UPDATE_SINGLE_ACTIVITY,{actId = self.ACT_ID})
end

-- 是否显示icon
function Manager:isActIconVisible()
    if self.isIconVisible == nil then
        self.isIconVisible = true
    end
    self:log("isIconVisible: ", self.isIconVisible)
    return self.isIconVisible
end

function Manager:onFullLevelClickBtn()
    self:log("onFullLevelClickBtn")
    self.fullLevelButNeedShow = false
    self:updateActIconVisible()
end

--强弹主面板
function Manager:popMainPanel(endCallback)
    if not self:isEnabled() then 
        safeRunCall(endCallback)
        return 
    end
    self:openActivity(endCallback, nil, false)
end



function Manager:resetDataBeforeInLevel()
    self.coinNum = nil
    self.energyNum = nil
end

function Manager:setExtraRewardNum(coinNum, energyNum)
    self.coinNum = coinNum
    self.energyNum = energyNum
end

-- 获取额外获得的银币与精力
function Manager:getExtraRewardNum()
    return self.coinNum or 0, self.energyNum or 0
end

-- 左下角带福袋的icon，播放消失动画
-- reward {itemId = xxx, num = xxx}
function Manager:createLuckyBagIconAndAnim(reward, delayTime)
    -- todo
    local layer = Layer:create()
    local icon = GameItemCreator:getPropIcon(reward)
    local luckyBagIcon = UICreateUtil:createSpriteFile("tempFunctionRes/LuckyBagParty/luckyBagIcon.png")
    icon:setScale(0.7)
    icon:setPositionXY(0, 0)
    luckyBagIcon:setPositionXY(-20, -12)
    layer:addChild(icon)
    layer:addChild(luckyBagIcon)

    local label = TTFLabel:createAnimalYH("", 26)
    label:setString(" +" .. reward.num)
    label:enableOutline(hex2ccc4("B17149FF"), 4)
    label:setPositionXY(30, 12)
    layer:addChild(label)

    if delayTime == nil then delayTime = 0 end
    layer:runAction(LayoutUtil:sequence{
        CCDelayTime:create(delayTime),
        CCSpawn:createWithTwoActions(
            CCMoveBy:create(1.5, ccp(0, 20)),
            CCSequence:createWithTwoActions(
                CCDelayTime:create(0.5),
                ActionUtil:fadeOutU3D(layer, 1)
            )
        )
    })
    layer:makeContentSizeContainChildren()
    return layer
end

function Manager:getGroup()
    local isFrontGroup = false -- MaintenanceManager:getInstance():isEnabledInGroup('wishbagV2_test2', 'front')
    local isColorGroup = true -- MaintenanceManager:getInstance():isEnabledInGroup('wishbagV2_test2', 'color')
    local isEnergyGroup = false -- MaintenanceManager:getInstance():isEnabledInGroup('wishbagV2_test2', 'energy')
    local isBackGroup = true -- MaintenanceManager:getInstance():isEnabledInGroup('wishbagV2_test2', 'back')
    local isOffGroup = false -- MaintenanceManager:getInstance():isEnabledInGroup('wishbagV2_test2', 'off') or (not isFrontGroup and not isColorGroup and not isEnergyGroup and not isBackGroup) 
    return isFrontGroup, isColorGroup, isEnergyGroup, isBackGroup, isOffGroup
end


return Manager