local deferred = require "amf.script.sugar.deferred"
require "amf.feature.fruittree.act.collectword.config.CollectWordConst"
local FruitTreeEventCenter = require "amf.feature.fruittree.event.FruitTreeEventCenter"
local Res = require "amf.feature.fruittree.act.collectword.config.Res"
local MarkEventCenter = require "amf.feature.dailyreward.mark.event.MarkEventCenter"
local SaveTool = require "amf.feature.fruittree.act.collectword.util.SaveTool"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local CollectWordManager = class("CollectWordManager")

local function getPropEventCenter()
    return require "amf.middleware.prop.event.PropEventCenter"
end

local function hasPropCustomEvents()
    return PropEvent
        and PropEvent.CUSTOM_GAIN
        and PropEvent.CUSTOM_CONSUME
        and PropEvent.RESOLVE_ICON
end

function CollectWordManager:ctor()
    self.model = nil

    self._fruitTreeManager = nil
    self._activityMgr = nil
    self._assetsUtil = nil
    self._autoPopupMgr = nil
    self._profileManager = nil
    self._isSupportShare = false
    self._isWeiboInstalled = false
    self._isWeixinInstalled = false
end

function CollectWordManager:refreshShareState()
    self._isSupportShare, self._isWeiboInstalled, self._isWeixinInstalled = ShareCenterUtil:checkShareState()
    -- TEST
    -- self._isSupportShare = true
    -- self._isWeiboInstalled = true
    -- self._isWeixinInstalled = true
end

function CollectWordManager:getShareState()
    return {
        isSupportShare = self._isSupportShare,
        isWeiboInstalled = self._isWeiboInstalled,
        isWeixinInstalled = self._isWeixinInstalled,
    }
end

function CollectWordManager:setProfileManager(mgr)
    self._profileManager = mgr
end

function CollectWordManager:setAutoPopupMgr(mgr)
    self._autoPopupMgr = mgr
end

function CollectWordManager:setAssetsUtil(assetsUtil)
    self._assetsUtil = assetsUtil
end

function CollectWordManager:setActivityMgr(mgr)
    self._activityMgr = mgr
end

function CollectWordManager:setFruitTreeManager(mgr)
    self._fruitTreeManager = mgr
end

function CollectWordManager:addToMgr(vm, param)
    if not vm then return end
    self._vmMap = self._vmMap or {}
    self._vmMap[vm] = param or true
end

function CollectWordManager:hasPanel()
    for k, v in pairs(self._vmMap or {}) do
        if k and isSafeCocosObj(k) then
            return true
        end
    end
    return false
end

function CollectWordManager:closeAll(fromPassDay)
    -- 关闭所有界面
    for vm, _ in pairs(self._vmMap or {}) do
        if vm and not vm.isDisposed then
            vm:close()
        end
    end
    self._vmMap = {}
    -- 关闭主界面
    if self._mainVM and not self._mainVM.isDisposed then
        self._mainVM:close()
        if fromPassDay then
            local tip = self:consumeCloseTip(fromPassDay)
            if tip then
                CommonTip:showTip(tip)
            end
        end
    end
end

function CollectWordManager:isFeatureEnabled()
    if _G.__CollectWordTestMode == true then return true end
    return FeatureSwitch:isOpen(FeatureSwitch.Type.FRUITTREE_COLLECT_WORD)
end

function CollectWordManager:initialize()
    if not self:isFeatureEnabled() then return end
    self:registerProps()
    self.model = require("amf.feature.fruittree.act.collectword.model.Model"):create()
    self.actInfo = require("amf.feature.fruittree.act.collectword.model.ActInfo"):create()
    self._vmMap = {}
    self:registerEvent()
    -- 分享
    require("amf.feature.fruittree.act.collectword.share.ResponseAskWordShareHandler"):create()
    require("amf.feature.fruittree.act.collectword.share.ResponseSendWordShareHandler"):create()
    require ("amf.feature.fruittree.act.collectword.share.ResponseSpeedShareHandler"):create()
end

function CollectWordManager:onActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local actInfo = actInfos[tostring(CollectWordConst.ACT_ID)]
    if not actInfo then
        return
    end
    self:updateActInfo():next(function()
    end, function()
        self.model:reset()
    end)
end

-- 到后台添加本地推送
function CollectWordManager:onSystemEnterBackground()
    if not self:isEnabled() then return end
    local LocalPush = require "amf.feature.fruittree.act.collectword.localpush.LocalPush"
    LocalPush:checkLocalPush()
end

function CollectWordManager:setMainVM(bValue)
    self._mainVM = bValue
end

function CollectWordManager:tryStartUpdateIcon()
    if self.timerId then return end
    self.timerId = TimerUtil.addAlarm(function()
        self:_updateIconInfo()
    end, 1, 0)
end

function CollectWordManager:isActEnabled()
    return self.actInfo and self.actInfo:isEnabled(self:hasRealProps())
end

function CollectWordManager:isActEnd()
    return self.actInfo and self.actInfo:isActEnd()
end

function CollectWordManager:_updateIconInfo()
    if self.actInfo:isActEnd() then
        if self.timerId then
            TimerUtil.removeAlarm(self.timerId)
            self.timerId = nil
        end
        self:resetActInfo()
        -- 刷新icon显示
        FruitTreeEventCenter:dispatch(FruitTreeEvent.ACT_DATA_CHANGE)
        FruitTreeEventCenter:dispatch(FruitTreeEvent.ICON_SHOWTIP, {
            clearTip = true
        })
        self:closeAll()
        self:unregisterEvent()
        self:unloadAllFiles()
        return
    end
    if self.actInfo:isNotOpen() then
        return
    end

    local lastTipTime = self._lastTipTime or 0
    local curTime = TimeKit:timeInMillis()
    if self._mainVM and not self._mainVM.isDisposed then
        self._lastTipTime = curTime
        return
    end

    if curTime - lastTipTime >= CollectWordConst.TIP_INTERVAL_TIME or self._forceShowTip then
        self._forceShowTip = false
        self._lastTipTime = curTime
        local tipText
        local key = self.actInfo:getValue("mainBeginTime") .. "_hasEnterCollectWordAct"
        if self:getActValue("hasReceiveWord") then
            tipText = CollectWordConst.Desc.ICON_TIP_RECEIVE_WORD
        elseif not LocalDB:getBool(key) then
            tipText = CollectWordConst.Desc.ICON_TIP_NOT_ENTER_FRUIT
            LocalDB:setBool(key, true)
            FruitTreeEventCenter:dispatch(FruitTreeEvent.ICON_SHOW_GUIDE_HAND)
        end
        if tipText then
            FruitTreeEventCenter:dispatch(FruitTreeEvent.ICON_SHOWTIP, {
                text = tipText
            })
        end
    end
end

function CollectWordManager:registerProps()
    local PropRegister = require "amf.feature.fruittree.act.collectword.prop.PropRegister"
    PropRegister:register()
end

function CollectWordManager:isPlatformSupport()
    if EnvUtil:isOhos() then return false end
    return true
end

function CollectWordManager:isLocalEnabled()
    if not self:isFeatureEnabled() then
        return false, "feature_switch_disable"
    end
    if not self:isPlatformSupport() then
        return false, "platform_disable"
    end
    if not self._fruitTreeManager:isEnabled() then
        return false, "fruittree_disable"
    end
    return true
end

function CollectWordManager:isEnabled()
    if not self:isLocalEnabled() then
        return false, "localEnabled"
    end
    if not self.actInfo then
        return false, "act_enable"
    end
    if not self:isActEnabled() then
        return false, "act_enable", self.actInfo:getValue("mainBeginTime"), self.actInfo:getValue("mainEndTime")
    end
    if not self.model or not self.model:isEnabled() then
        return false, "model_enabled"
    end
    return true, ""
end

function CollectWordManager:isLevelSupport()
    return self.actInfo and self.actInfo:isLevelSupport()
end

function CollectWordManager:hasRealProps()
    return self:getDataValue("havaRealProps") == true
end

function CollectWordManager:isInRewardTime()
    return self.actInfo and self.actInfo:isInRewardTime()
end

local _spines = {
    Res.Spine.GOLD_FRUIT,
    Res.Spine.ACT_FRUIT,
    Res.Spine.ACT_FRUIT_BELOW,
    Res.Spine.ACT_FRUIT_FRONT,
    Res.Spine.RIPEN_FX,
    Res.Spine.GET_WORD,
    Res.Spine.FEI,
    Res.Spine.BUBBLE,
}

local _plists = {
    Res.Plist.MAIN,
    Res.Plist.PUB_FRAME,
}

local _files = {
    Res.File.SHOWOFF_LIGHT,
    Res.File.SHOWOFF_TREE,
    Res.File.DACHE,
}
_files = table.union(_files, Res.Materials)

function CollectWordManager:getResList()
    local list = table.union(_spines, _plists)
    list = table.union(list, _files)
    return list
end

function CollectWordManager:isResReady()
    return self._isResReady
end

function CollectWordManager:loadRes()
    local d = deferred.new()
    if EnvUtil:isUnity() then
        local list = self:getResList()
        self._assetsUtil:loadMiniFiles(list, false):next(function()
            if not self._isResReady then
                -- 创建的时候先load一次
                self:loadAllFiles()
                self._isResReady = true
            end
            d:resolve()
        end)
    else
        if not self._isResReady then
            -- 创建的时候先load一次
            self:loadAllFiles()
            self._isResReady = true
        end
        d:resolve()
    end
    return d
end

function CollectWordManager:isMainScene()
    local scene = Director:sharedDirector():getRunningSceneLua()
    return scene and scene:isScene("MainScene")
end

function CollectWordManager:registerEvent()
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActInfoUpdate, self)
    FruitTreeEventCenter:registerSystem(self)
    FruitTreeEventCenter:registerFeature(self)
    FruitTreeEventCenter:register(FruitTreeEvent.PRE_OPEN_CHECK, self.onFruitTreePreOpenCheck, self)
    FruitTreeEventCenter:register(FruitTreeEvent.ICON_REWARD_CHECK, self.onIconRewardCheck, self)
    -- 沿用旧版 FruitTreeActCollectWord 策略：新字也统一算作“奖”红点，不单独走 new act 检查。
    -- FruitTreeEventCenter:register(FruitTreeEvent.ICON_NEW_CHECK, self.onIconNewCheck, self)
    MarkEventCenter:register(MarkEvent.MARK_PREOPEN_CHECK, self.onMarkPreOpenEvent, self)
    local PropEventCenter = getPropEventCenter()
    if PropEventCenter and hasPropCustomEvents() then
        PropEventCenter:register(PropEvent.CUSTOM_GAIN, self.onCustomGain, self)
        PropEventCenter:register(PropEvent.CUSTOM_CONSUME, self.onCustomConsume, self)
        PropEventCenter:register(PropEvent.RESOLVE_ICON, self.onResolveIcon, self)
    end
end

function CollectWordManager:unregisterEvent()
    ActivityEventCenter:unregister(ActivityEvent.ACT_INFOS_UPDATE, self.onActInfoUpdate)
    FruitTreeEventCenter:unregisterSystem(self)
    FruitTreeEventCenter:unregisterFeature(self)
    FruitTreeEventCenter:unregister(FruitTreeEvent.PRE_OPEN_CHECK, self.onFruitTreePreOpenCheck)
    FruitTreeEventCenter:unregister(FruitTreeEvent.ICON_REWARD_CHECK, self.onIconRewardCheck)
    -- 沿用旧版 FruitTreeActCollectWord 策略：新字也统一算作“奖”红点，不单独走 new act 检查。
    -- FruitTreeEventCenter:unregister(FruitTreeEvent.ICON_NEW_CHECK, self.onIconNewCheck)
    MarkEventCenter:unregister(MarkEvent.MARK_PREOPEN_CHECK, self.onMarkPreOpenEvent, self)
    local PropEventCenter = getPropEventCenter()
    if PropEventCenter and hasPropCustomEvents() then
        PropEventCenter:unregister(PropEvent.CUSTOM_GAIN, self.onCustomGain)
        PropEventCenter:unregister(PropEvent.CUSTOM_CONSUME, self.onCustomConsume)
        PropEventCenter:unregister(PropEvent.RESOLVE_ICON, self.onResolveIcon)
    end
end

function CollectWordManager:isMarkBannerEnabled()
    return self:isLocalEnabled() and self.actInfo and self.actInfo:isInActTime()
end

function CollectWordManager:onMarkPreOpenEvent(evt)
    if not self:isMarkBannerEnabled() then return end
    local contextList = evt:getData()
    local context = MarkPreOpenContext.new()
        :setPriority(ActFestivalConst.Priority.COLLECT_WORD)
        :setExtLoadFiles({
            "amf/dailyreward/mark/extend/collectword/banner.png"
        })
        :setEnabledCheckFunc(function()
            return self:isMarkBannerEnabled()
        end)
        :setPreOpenFunc(function(callback)
            -- TODO 不用请求数据了吧，没有就没有吧
            safeRunCall(callback)
        end)
        :setBannerCreator(function()
            local banner = Sprite:create("amf/dailyreward/mark/extend/collectword/banner.png")
            local UIButton = require "amf.middleware.ui.kit.component.button.UIButton"
            local btn = UIButton:createButton({
                scaleMode = UIButtonConfig.BtnScales.k50,
                str = "点击查看",
            })
            banner:addChild(btn)
            local saveKey = "mark_has_show_reward_"..(self.actInfo:getValue("mainBeginTime") or "")
            if not self:hasGuideIndex(CollectWordConst.GuideIds.GUIDE1) and not SaveTool:getValue(saveKey) then
                SaveTool:setValue(saveKey, true)
                btn:setRedDot("奖")
            end

            btn:setPositionXY(521,50)
            btn:setCallback(function()
                -- 如果是强弹，给他中断了
                self._autoPopupMgr:resetPopup()
                MarkEventCenter:dispatch(MarkEvent.MARK_CLOSE)
                self._fruitTreeManager:openFruitTreePanel({
                    t1 = "sign_in"
                })
            end)
            return banner
        end, ccp(305, 91))
    table.insert(contextList, context)
end

function CollectWordManager:onActPassDay()
    self:closeAll(true)
end

function CollectWordManager:getPassDayCloseTip()
    if not self.actInfo then
        return CollectWordConst.Desc.TIP_PASS_DAY
    end

    if self.actInfo:isActEnd() then
        return CollectWordConst.Desc.TIP_ACT_END
    end

    if not self.actInfo:isEnabled(self:hasRealProps()) and self.actInfo:isInRewardTime() then
        return CollectWordConst.Desc.TIP_ACT_END
    end

    return CollectWordConst.Desc.TIP_PASS_DAY
end

function CollectWordManager:consumeCloseTip(fromPassDay)
    if fromPassDay then
        return self:getPassDayCloseTip()
    end

    if self:isActEnd() then
        return CollectWordConst.Desc.TIP_ACT_END
    end

    return nil
end

-- 收到字界面
function CollectWordManager:showGetWordPanel(delegate)
    delegate = delegate or {}
    local receiveWordInfoListA = delegate.rewards or {}
    local shareType = delegate.shareType
    local tempData = table.clone(receiveWordInfoListA)

    local rewardMap = {}
    local personMap = {}
    local rewardList = {}
    local personList = {}
    for _, v in pairs(tempData) do
        if not personMap[tostring(v.xxlId)] then
            personMap[tostring(v.xxlId)] = 1
        end
    end

    local personNum = table.size(personMap)

    for _, v in pairs(tempData) do
        table.insert(personList, v)
    end

    table.sort(personList, function(a, b)
        return tonumber(a.time or 0) < tonumber(b.time or 0)
    end)

    local shareTime = personList[1].shareTime or 0

    local personName = cutNameByteSensitive(personList[1].name, 12, nil, true)
    if personNum > 1 then
        personName = personName.."等"
    end

    for _, v in pairs(tempData) do
        if rewardMap[tostring(v.itemId)] then
            rewardMap[tostring(v.itemId)] = rewardMap[tostring(v.itemId)] + 1
        else
            rewardMap[tostring(v.itemId)] = 1
        end
    end
    for k, v in pairs(rewardMap) do
        local t = {
            itemId = tonumber(k),
            num = v,
            dontFly = delegate.dontFly
        }
        safeRunCall(delegate.fillFlyFunc, tonumber(k), function(flyFunc)
            t.flyFunc = flyFunc
        end)
        table.insert(rewardList, t)
    end

    for _, v in pairs(rewardList) do
        if self:getWordIsNew(v.itemId) then
            v.newSign = true
        end
    end

    local NameLabel = require "amf.middleware.ui.kit.component.namelabel.NameLabel"
    local nameText = NameLabel:create(personName, 26, nil, kCCTextAlignmentCenter, kCCVerticalTextAlignmentTop)
    nameText:setTextColor(hex2ccc4("b17149FF"))
    nameText.ignorePack = true


    local DrainagePanelVM = require "amf.middleware.ui.kit.panel.second.DrainagePanelVM"
    local builder = DrainagePanelVM.Builder.new()
    if shareType == CollectWordConst.ShareType.ASKWORD_BEHELP then
        builder:setTitle("索要成功")
    else
        builder:setTitle("收下赠礼")
    end
    builder:setNumButton('收下', nil)
    if shareType == CollectWordConst.ShareType.ASKWORD_BEHELP then
        local ts = math.floor(tonumber(shareTime) / 1000)
        local year = tonumber( os.date( "%y" , ts ) )
        local month =  tonumber( os.date( "%m" , ts ) )
        local day =  tonumber( os.date( "%d" , ts ) )
        local text1 = tostring(month).."月"..tostring(day).."日"
        builder:pushDesc(nameText)
        builder:pushDesc('接受您'..text1..'发出的索要申请，送来了活动果，快收下吧~')
    else
        builder:pushDesc('好友')
        builder:pushDesc(nameText)
        builder:pushDesc('给您送来了以下文字果，快快收下吧~')
    end

    builder:pushBlock(rewardList, '请收下')
    builder:setCloseCallback(delegate.closeCallback)
    builder:setFly(true)
    local vm = builder:build()
    vm:popout()
    self:addToMgr(vm)
end

function CollectWordManager:onActEnterStage4()
    if not self:isEnabled() then return end

    local function showGotoGet(hasReward, onPopout)
        local function onHandleOver()
            AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.COLLECT_WORD)
        end

        local function creator()
            if not self:isEnabled() then
                onHandleOver()
                return
            end
            self:loadRes():next(function()
                if not self:isEnabled() then
                    onHandleOver()
                    return
                end
                safeRunCall(onPopout)
                self:showBackflowPanel({
                    hasReward = hasReward,
                    closeCallback = onHandleOver
                })
            end, function()
                onHandleOver()
            end)
        end

        self._autoPopupMgr:addPopupConfig(PopupCheckPoint.COLLECT_WORD, creator)
    end

    local todayCount = SaveTool:getTodayPopPanelCount("todayPopPanelCount") or 0
    local function markTodayPopout()
        SaveTool:setTodayPopPanelCount("todayPopPanelCount", todayCount + 1)
    end

    if todayCount < 3 then
        if self:hasRipenFruit() and self:hasGuideIndex(CollectWordConst.GuideIds.GUIDE1) then
            showGotoGet(true, markTodayPopout)
        elseif not SaveTool:getTodayPopFlowPanel("hasPopout_flowPanel")
            and not self:hasActived() then
            showGotoGet(false, function()
                SaveTool:setTodayPopFlowPanel("hasPopout_flowPanel", true)
                markTodayPopout()
            end)
        end
    end
end

-- 引导界面
function CollectWordManager:showBackflowPanel(param)
    local BackflowPanelVM = require "amf.feature.fruittree.act.collectword.view.BackFlowPanelVM"
    local vm = BackflowPanelVM:create(param)
    vm:setLoadResFailCallback(function()
        safeRunCall(param.closeCallback)
    end)
    vm:popout()
    self:addToMgr(vm)
end

function CollectWordManager:loadAllFiles()
    self._hasLoadFiles = true
    for _, v in ipairs(_plists) do
        UICreateUtil:loadPlist(v)
    end

    for _, v in ipairs(_spines) do
        UICreateUtil:loadSpineRes(v)
    end
end

function CollectWordManager:unloadAllFiles()
    if not self._hasLoadFiles then return end
    for _, v in ipairs(_plists) do
        UICreateUtil:unloadPlist(v)
    end

    for _, v in ipairs(_spines) do
        UICreateUtil:unloadSpineRes(v)
    end

    for i, v in ipairs(_files) do
        CCTextureCache:sharedTextureCache():removeTextureForKey(
            _G.ccFullPath(SpriteUtil:getRealResourceName(v), true)
        )
    end
end

-- 红点检查
-- function CollectWordManager:onIconNumCheck(evt)
--     if not self:isEnabled() then return end
--     local contextList = evt:getData()
--     local context = ActIconNumContext.new()
--         :setPriority(FruitTreeConst.ActPriority.COLLECT_WORLD)
--         :setMsgNum()
--     table.insert(contextList, context)
-- end

-- 奖字检查
function CollectWordManager:onIconRewardCheck(evt)
    if not self:isLocalEnabled() then
        return
    end
    if not self.actInfo then return end
    local contextList = evt:getData()
    local hasReward = self:getActValue("hasReward")
    local hasNewWord = self:getActValue("hasNewWord")
    local hasReceiveWord = self:getActValue("hasReceiveWord")
    if self.actInfo:isInRewardTime() then
        hasNewWord = false
        hasReceiveWord = false
    end

    local context = ActIconRewardContext.new()
        :setPriority(FruitTreeConst.ActPriority.COLLECT_WORLD)
        :setHasReward(hasReward or hasNewWord or hasReceiveWord)
    table.insert(contextList, context)
end

-- 新字检查
-- function CollectWordManager:onIconNewCheck(evt)
--     if not self:isLocalEnabled() then
--         return
--     end
--     if not self.actInfo then return end
--     local hasReward = self:getActValue("hasReward")
--     local hasNewWord = self:getActValue("hasNewWord")
--     local contextList = evt:getData()
--     local context = ActIconNewContext.new()
--         :setPriority(FruitTreeConst.ActPriority.COLLECT_WORLD)
--         :setNew(not hasReward and hasNewWord)
--     table.insert(contextList, context)
-- end

-- 打开金银果树前检查
function CollectWordManager:onFruitTreePreOpenCheck(evt)
    if not self:isLocalEnabled() then
        return
    end
    if not self.actInfo:isInActTime() and not self.actInfo:isInRewardTime() then
        return false
    end
    local preOpenList = evt:getData()
    local actPreOpenContext = ActFruitTreePreOpenContext.new()
        :setPriority(FruitTreeConst.ActPriority.COLLECT_WORLD)
        :setPanelVM(require "amf.feature.fruittree.act.collectword.view.FruitTreeMainPanel_CollectWordVM")
        :setFunction(function(callback)
            local Condition = require "amf.script.sugar.Condition"
            local cond = Condition.new(function()
                safeRunCall(callback)
            end, 2)
            self:loadRes():next(function()
                cond:notify()
            end, function()
                cond:notify()
            end)
            self:requestMainInfo():next(function()
                cond:notify()
            end, function()
                cond:notify()
            end)
        end)
        :setEnabledFunc(function()
            return self:isEnabled()
        end)
    table.insert(preOpenList, actPreOpenContext)
end

-- 关闭界面后需要重置一下
function CollectWordManager:resetActInfo()
    if not self.actInfo then return end
    self:setActValue("hasNewWord", false)
    self:setActValue("hasReceiveWord", false)
    if self.actInfo:isInActTime() and self:isEnabled() then
        local hasTaskReward = self:hasTaskCanReward()
        local canLotter = self:canLotter()
        local hasRippen = self:hasRipenFruit()
        local canActive = self:isCanActive()
        self:setActValue("hasReward", hasTaskReward or canLotter or hasRippen or canActive)
    elseif self:isInRewardTime() then
        self:setActValue("hasReward", self:hasRealProps() and not self:getDataValue("contact"))
    else
        self:setActValue("hasReward", false)
    end
end

-- actInfo
function CollectWordManager:updateActInfo()
    if not self:isLocalEnabled() then return deferred.error() end
    local actInfo = self._activityMgr:getActInfo(CollectWordConst.ACT_ID)
    if actInfo and actInfo.extra and actInfo.extra ~= "" then
        local tb = table.deserialize(actInfo.extra)
        if type(tb) ~= "table" then
            return deferred.error()
        end
        self.actInfo:parseData(tb)
        if not self:isActEnabled() then
            return deferred.error()
        end

        if not self._hasRequestLightMainInfo then
            self._hasRequestLightMainInfo = true
            self:requestMainInfo(nil, nil, true)
        end

        -- 通知刷新icon
        FruitTreeEventCenter:dispatch(FruitTreeEvent.ACT_DATA_CHANGE)
        -- 刷新icon的特效
        local hasReward = self:getActValue("hasReward")
        local hasNewWord = self:getActValue("hasNewWord")
        if hasReward or hasNewWord then
            FruitTreeEventCenter:dispatch(FruitTreeEvent.ICON_SHOW_NEWANIM)
        else
            FruitTreeEventCenter:dispatch(FruitTreeEvent.ICON_HIDE_NEWANIM)
        end
        self:tryStartUpdateIcon()
        return deferred.success()
    end
    return deferred.error()
end

-- 主info
function CollectWordManager:requestMainInfo(param, loading, light)
    param = param or {}
    param.configMd5 = self:getConfigValue("configMd5") or ""
    if not light then
        param.active = true
    end
    local d = deferred.new()
    self._isRequestingMain = true
    self.model:requestMainInfo(param, loading):next(function(response)
        local data = response:getData()
        local info = data.info or {}
        -- 把别人送的字列表和别人点链接，给我的奖励赋给info
        info.receiveWordInfoList = data.receiveWordInfoList or {}
        -- showBeHelpRewardList 对应旧版“别人点击我分享链接后的奖励”。
        -- 当前活动该奖励已下线，保留旧逻辑注释但不再入账/弹奖/打点。
        -- info.showBeHelpRewardList = data.showBeHelpRewardList or {}

        -- if not table.isEmpty(data.showBeHelpRewardList) then
        --     -- 这里应该加上奖励
        --     GainPropData:create()
        --         :setFeature(CollectWordConst.DC_FEATURE)
        --         :setSource(CollectWordConst.DC_SOURCE.."_share")
        --         :setProps(info.showBeHelpRewardList)
        --         :execute()

        --     self:dc("beclick", "share")
        -- end
        local config = data.extra
        if config and config ~= "" then
            config = table.deserialize(config)
            if type(config) == "table" then
                self.model:parseConfig(config)
            end
        end
        self.model:parseData(info)
        -- 如果有收到的字，那么先减去，后边播动画再加上
        if param.active and self:hasReceivedWords() then
            local receiveList = self:getReceivedWordInfoList()

            local reciveList = self:getReceiveWordsList(CollectWordConst.ShareType.SENDWORD_RECEIVE_OTHER)
            local askList = self:getReceiveWordsList(CollectWordConst.ShareType.ASKWORD_BEHELP)
            local dcRewards = {}
            local dcRewards2 = {}
            for i, v in ipairs(askList) do
                table.insert(dcRewards, {itemId = v.itemId, num = 1})
            end
            for i, v in ipairs(reciveList) do
                table.insert(dcRewards2, {itemId = v.itemId, num = 1})
            end

            -- 只打获得点
            -- 被别人帮助成功获得的字
            for i, v in ipairs(dcRewards) do
                DcDataCommon:create()
                    :setFeature(CollectWordConst.DC_FEATURE)
                    :setSource(CollectWordConst.DC_SOURCE.."_demand")
                    :setActId(CollectWordConst.ACT_ID)
                    :setGainProp(v)
                    :execute()
            end

            -- 好友通过游戏内赠送的字
            for i, v in ipairs(dcRewards2) do
                DcDataCommon:create()
                :setFeature(CollectWordConst.DC_FEATURE)
                :setSource(CollectWordConst.DC_SOURCE.."_reward")
                :setActId(CollectWordConst.ACT_ID)
                :setGainProp(v)
                :execute()
            end

            for _, v in ipairs(receiveList) do
                self:addWordNum(v.itemId, -1)
            end
        end
        d:resolve()
    end, function(response)
        if not response:isCancel() and loading and not light then
            CommonTip:showErrorTip(response)
        end
        d:reject()
    end)
    return d
end

-- 摘果子
function CollectWordManager:requestPick(param)
    local d = deferred.new()
    self.model:requestPick(param):next(function(response)
        local data = response:getData()
        local rewardList = data.rewardList or {}
        -- 剔除寄语id
        local tempList = {}
        for _, v in ipairs(rewardList) do
            if v.itemId ~= CollectWordConst.PROP_ID_WORD_JY then
                table.insert(tempList, v)
            end
        end
        if not table.isEmpty(tempList) then
            GainPropData:create()
                :setFeature(CollectWordConst.DC_FEATURE)
                :setSource(CollectWordConst.DC_SOURCE.."_main")
                :setProps(tempList)
                :execute()
        end
        -- 修改fruitData
        local fruitData = data.fruitData
        if fruitData then
            self:setDataValue("fruitData", fruitData)
        end
        -- 增加任务进度
        self:addTaskProgressByType(CollectWordConst.TaskType.PICK_TOTAL)
        self:addTaskProgressByType(CollectWordConst.TaskType.PICK_CONTINUE)
        d:resolve(tempList)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        d:reject()
    end)
    return d
end

-- 激活
function CollectWordManager:requestActivate(param)
    param = param or {}
    local d = deferred.new()
    self.model:requestActivate(param):next(function(response)
        local data = response:getData()
        local rewardList = data.rewardList or {}
        -- 加奖励
        GainPropData:create()
            :setFeature(CollectWordConst.DC_FEATURE)
            :setSource(CollectWordConst.DC_SOURCE.."_main")
            :setProps(rewardList)
            :execute()
        -- 减字
        self:onWordActive()
        -- 先不设置，播完动画再设置
        -- self:setDataValue("luckyFruitId", luckyFruitId or 0)
        d:resolve(data)
    end,function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        d:reject()
    end)
    return d
end

-- 请求赠送文字果
function CollectWordManager:requestSendWord(param)
    local d = deferred.new()
    param = param or {}
    param.shareType = CollectWordConst.ShareType.SEND_WORD
    self:requestShareKey(param):next(function(shareKey)
        self:requestShareSuccess({
            shareKey = shareKey
        }):next(function()
            -- 成功
            _G.ConsumePropData:create()
                :setFeature(CollectWordConst.DC_FEATURE)
                :setSource(param.dcSource or CollectWordConst.DC_SOURCE.."_vx")
                :setProp({itemId = param.itemId, num = 1})
                :execute()
            self:addTaskProgressByType(CollectWordConst.TaskType.SEND_WORD)
            d:resolve(shareKey)
        end, function()
            d:reject()
        end)
    end, function()
        d:reject()
    end)
    return d
end

-- 赠送字给游戏内好友
function CollectWordManager:requestSendWordToFriend(param)
    local d = deferred.new()
    self.model:requestSendToFriend(param):next(function(response)
        ConsumePropData:create()
            :setFeature(CollectWordConst.DC_FEATURE)
            :setSource(CollectWordConst.DC_SOURCE.."_friend")
            :setProp({itemId = param.itemId, num = 1})
            :execute()
        self:addTaskProgressByType(CollectWordConst.TaskType.SEND_WORD)
        d:resolve()
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        d:reject()
    end)
    return d
end

-- 分享key
function CollectWordManager:requestShareKey(param)
    param = param or {}
    param.id = CollectWordConst.SHARE_ID
    param.targetCount = param.shareType
    param.timestamp = param.itemId or param.shareType
    local d = deferred.new()
    self.model:requestShareKey(param):next(function(response)
        local data = response:getData()
        local shareKey = data.shareKey or ""
        if shareKey == "" then
            d:reject(response)
            return
        end
        d:resolve(shareKey)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        d:reject()
    end)
    return d
end

-- 通知后端分享成功
function CollectWordManager:requestShareSuccess(param, extParam)
    extParam = extParam or {}
    param = param or {}
    param.id = CollectWordConst.SHARE_ID
    local d = deferred.new()
    self.model:requestShareSuccess(param):next(function(response)
        local data = response:getData()
        local rewardList = data.rewardList or {}

        if not table.isEmpty(rewardList) then
            GainPropData:create()
                :setFeature(CollectWordConst.DC_FEATURE)
                :setSource(extParam.source or CollectWordConst.DC_SOURCE.."_main")
                :setProps(rewardList)
                :execute()
        end

        d:resolve(rewardList)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        d:reject()
    end)
    return d
end

-- 任务奖励领取
function CollectWordManager:requestTaskReward(param)
    local d = deferred.new()
    self.model:requestTaskReward(param):next(function(response)
        local data = response:getData()
        local s = CollectWordConst.DC_SOURCE.."_task"
        if param.taskId == 0 then
            s = CollectWordConst.DC_SOURCE.."_draw"
        end
        -- 加奖励
        GainPropData:create()
            :setFeature(CollectWordConst.DC_FEATURE)
            :setSource(s)
            :setProps(data.rewardList)
            :execute()
        local taskId = param.taskId
        -- 设置任务领取状态
        self:setTaskRewarded(taskId)
        if taskId == 0 then
            self:setDataValue("activateItemList", data.rewardList or {})
        end
        d:resolve(data.rewardList)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        d:reject()
    end)
    return d
end

-- 获取帮助记录
function CollectWordManager:requestRecord(param)
    local d = deferred.new()
    self.model:requestRecord(param):next(function(response)
        local data = response:getData()
        d:resolve(data)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        d:reject(response)
    end)
    return d
end

-- 获取实物中奖记录
function CollectWordManager:requestRealRecord(param)
    local d = deferred.new()
    self.model:requestRealRecord(param or {}):next(function(response)
        local data = response:getData()
        d:resolve(data)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        d:reject(response)
    end)
    return d
end

-- 设置引导标记
function CollectWordManager:addGuideIndex(index)
    if self:hasGuideIndex(index) then return end
    local guideIdSet = self:getDataValue("guideIdSet") or {}
    table.insert(guideIdSet, index)
    self:setDataValue("guideIdSet", guideIdSet)
    -- 引导标记
    local SetActGuidFlag = require "amf.middleware.activity.http.SetActGuidFlag"
    SetActGuidFlag:post({
        actId = CollectWordConst.ACT_ID,
        index = index
    })
end

function CollectWordManager:hasGuideIndex(index)
    local guideIdSet = self:getDataValue("guideIdSet") or {}
    return table.exist(guideIdSet, index)
end

-- 设置任务已经领取了
function CollectWordManager:setTaskRewarded(taskId)
    if taskId == 0 then
        self:setDataValue("taskProgressReward", true)
    else
        self:addTaskRewardSet(taskId)
    end
end

function CollectWordManager:addTaskRewardSet(taskId)
    local taskRewardSet = self:getDataValue("taskRewardSet") or {}
    table.insert(taskRewardSet, taskId)
    self:setDataValue("taskRewardSet", taskRewardSet)
end

-- 增加任务进度
function CollectWordManager:addTaskProgressByType(taskType, num)
    -- 点链接可能会走到，这时没有请求数据
    if not self:getDataValue("hasInit") then return end
    num = num or 1
    if taskType == CollectWordConst.TaskType.PICK_CONTINUE then
        -- 给今天加数据
        self:addTodayPickNum(num)
        -- 计算连续摘取的天数,这个比较特殊不能走下边的接口
        self:updateTaskContiDays()
    elseif taskType == CollectWordConst.TaskType.PICK_TOTAL then
        self:addPickFruitNum()
        self:addTaskTargetPro(taskType, num)
    else
        self:addTaskTargetPro(taskType, num)
    end
end

-- 增加任务进度
function CollectWordManager:addTaskTargetPro(taskType, num)
    num = num or 1
    local taskTargetMap = self:getDataValue("taskTargetMap") or {}
    if not taskTargetMap[tostring(taskType)] then
        taskTargetMap[tostring(taskType)] = 0
    end
    taskTargetMap[tostring(taskType)] = taskTargetMap[tostring(taskType)] + num
    self:setDataValue("taskTargetMap", taskTargetMap)
end

function CollectWordManager:addPickFruitNum(num)
    num = num or 1
    local pickFruitNum = self:getDataValue("pickFruitNum") or 0
    pickFruitNum = pickFruitNum + num
    self:setDataValue("pickFruitNum", pickFruitNum)
end

-- 更新任务类型为连续摘取天数
function CollectWordManager:updateTaskContiDays()
    local todayNum = self:getTodayNum()
    local count = 0
    for i = todayNum, 1, -1 do
        local dayData = self:getDayData(i)
        if dayData and dayData.pickFruitNum > 0 then
            count = count + 1
        else
            break
        end
    end
    self:setTaskTargetData(CollectWordConst.TaskType.PICK_CONTINUE, count)
end

-- 设置任务进度数据
function CollectWordManager:setTaskTargetData(taskType, value)
    local taskTargetMap = self:getDataValue("taskTargetMap") or {}
    taskTargetMap[tostring(taskType)] = value
    self:setDataValue("taskTargetMap", taskTargetMap)
end

-- 获得任务进度
function CollectWordManager:getTaskProgressByType(taskType)
    local taskTargetMap = self:getDataValue("taskTargetMap") or {}
    return taskTargetMap[tostring(taskType)] or 0
end

-- 获得传入天数的数据
function CollectWordManager:getDayData(dayNum)
    local todayNum = tostring(dayNum)
    local perDayMap = self:getDataValue("perDayMap") or {}
    local todayData = perDayMap[todayNum]
    return todayData
end

-- 给今天加摘取次数
function CollectWordManager:addTodayPickNum(num)
    num = num or 1
    local todayData = self:getTodayData()
    if not todayData then
        todayData = self:addTodayDefaultData()
    end
    todayData.pickFruitNum = todayData.pickFruitNum + num
    self:setDayData(todayData)
end

function CollectWordManager:addTodayDefaultData()
    local todayNum = self:getTodayNum()
    local todayData = {
        pickFruitNum = 0,  -- 这天摘取次数
        speedUpSet = {}, -- 加速id列表，帮助列表，可以拿到今天帮助了几次
        askforSucc = false,  -- 是否索要成功
    }
    local perDayMap = self:getDataValue("perDayMap") or {}
    perDayMap[tostring(todayNum)] = todayData
    self:setDataValue("perDayMap", perDayMap)
    return todayData
end

function CollectWordManager:getTodayData()
    local todayNum = self:getTodayNum()
    local perDayMap = self:getDataValue("perDayMap") or {}
    local todayData = perDayMap[tostring(todayNum)]
    return todayData
end

-- 获取今天第几天
function CollectWordManager:getTodayNum()
    local sec = TimeKit:timeInSec()
    local todayNum = time2day(sec)
    return todayNum
end

-- 设置有实物了
function CollectWordManager:setHasRealProp(value)
    self:setDataValue("havaRealProps", value)
end

function CollectWordManager:isRealProp(itemId)
    return CollectWordConst.MaterialCfg[tostring(itemId)]
end

function CollectWordManager:isWordProp(itemId)
    itemId = tonumber(itemId)
    for _, wordId in pairs(CollectWordConst.Words) do
        if tonumber(wordId) == itemId then
            return true
        end
    end
    return false
end

function CollectWordManager:getWordIndexByItemId(itemId)
    itemId = tonumber(itemId)
    local count = table.count(CollectWordConst.Words)
    for i = 1, count, 1 do
        if tonumber(CollectWordConst.Words["WORD_"..i]) == itemId then
            return i
        end
    end
    return nil
end

function CollectWordManager:onCustomGain(event)
    local reward = event and event:getData()
    if not reward then return end
    local itemId = tonumber(reward.itemId)
    local num = reward.num or 0
    if self:isWordProp(itemId) then
        self:addWordNum(itemId, num)
    elseif self:isRealProp(itemId) then
        self:setHasRealProp(true)
    end
end

function CollectWordManager:onCustomConsume(event)
    local reward = event and event:getData()
    if not reward then return end
    local itemId = tonumber(reward.itemId)
    if self:isWordProp(itemId) then
        self:addWordNum(itemId, -(reward.num or 0))
    end
end

function CollectWordManager:onResolveIcon(event)
    local data = event and event:getData()
    if not data or not data.callback then return end
    local itemId = tonumber(data.itemId)
    local wordIndex = self:getWordIndexByItemId(itemId)
    if wordIndex then
        data.callback({
            Atlas = Res.Plist.PUB_FRAME,
            Frame = "JinYinGuoShu_2023/ActCollectWordFrame/"..wordIndex.."_n",
            IsPropPng = false,
        })
        return
    end
    if self:isRealProp(itemId) then
        data.callback({
            Atlas = "",
            Frame = Res:getMaterialPath(itemId),
            IsPropPng = true,
        })
    end
end

-- 激活修改数据
function CollectWordManager:onWordActive()
    self:setDataValue("activate", true)
    -- 减字
    for _, v in pairs(CollectWordConst.Words) do
        self:addWordNum(v, -1)
    end
end

-- 加字
function CollectWordManager:addWordNum(itemId, num)
    -- 点链接可能会走到，这时没有请求数据
    if not self:getDataValue("hasInit") then return end
    local wordMap = self:getDataValue("wordMap") or {}
    local key = tostring(itemId)
    local preCount = wordMap[key] or 0
    wordMap[key] = preCount + num
    self:setDataValue("wordMap", wordMap)

    self:addWordNumTotal(itemId, num)
    self:setActValue("wordInfo", wordMap)
end

function CollectWordManager:addWordNumTotal(itemId, num)
    local strKey = tostring(itemId)
    local wordMapTotal = self:getDataValue("wordMapTotal", strKey)
    local preCount = wordMapTotal[strKey] or 0
    wordMapTotal[strKey] = preCount + num
    self:setDataValue("wordMapTotal", wordMapTotal)
end

-- 是否有收到的字
function CollectWordManager:hasReceivedWords()
    local receiveList = self:getReceivedWordInfoList()
    return table.count(receiveList) > 0
end

-- 收到的字果信息列表
function CollectWordManager:getReceivedWordInfoList()
    return self:getDataValue("receiveWordInfoList") or {}
end

-- 获得别人赠送字列表
function CollectWordManager:getReceiveWordsList(type)
    local list = self:getReceivedWordInfoList()
    local tempList = {}
    for i, v in ipairs(list ) do
        if v.shareType == type then
            table.insert(tempList, v)
        end
    end
    return tempList
end

-- 打点109
function CollectWordManager:dc(category, subCategory, extraData)
    local params = {
        game_type = "stage",
        game_name = CollectWordConst.GAME_NAME,
        category = category,
        sub_category = subCategory,
    }

    for i, v in pairs(extraData or {}) do
        params[i] = v
    end
    -- print("CollectWordManager:dc ---", tts(params))
    DcUtil:activity(params)
end

function CollectWordManager:setDayData(todayData, dayNum)
    dayNum = dayNum or self:getTodayNum()
    local perDayMap = self:getDataValue("perDayMap") or {}
    perDayMap[tostring(dayNum)] = todayData
    self:setDataValue("perDayMap", perDayMap)
end

function CollectWordManager:getDataValue(key)
    return self.model:getValue(key)
end

function CollectWordManager:getConfigValue(key)
    return self.model:getValue(key)
end

function CollectWordManager:setDataValue(key, value)
    self.model:setValue(key, value)
end

function CollectWordManager:setConfigValue(key, value)
    self.model:setValue(key, value)
end

function CollectWordManager:getActValue(key)
    return self.actInfo:getValue(key)
end

function CollectWordManager:setActValue(key, value)
    self.actInfo:setValue(key, value)
end

-- 6级风车币果
function CollectWordManager:createGoldFruitIcon()
    local layer = Layer:create()
    layer:setContentSize(CCSizeMake(100, 100))
    layer:setAnchorPoint(ccp(0.5, 0))

    local spine = UICreateUtil:createSpine(Res.Spine.GOLD_FRUIT)
    spine:playByName("idle", true)
    spine:setScale(0.8)
    spine:setPositionXY(layer:getContentSize().width/2-4, 10)
    layer:addChild(spine)
    return layer
end

function CollectWordManager:createActFruit(withEff, withStar, noCountDown)
    local ActCollectFruitNode = require "amf.feature.fruittree.act.collectword.view.ActCollectFruitNode"
    local node = ActCollectFruitNode:create({
        noCountDown = noCountDown,
    })
    if withEff then
        node:playEffect()
    end
    if withStar then
        node:playStarAnim()
    end
    return node
end

-- 今日摘取次数
function CollectWordManager:getTodayPickNum()
    local todayData = self:getTodayData()
    if not todayData then return 0 end
    return todayData.pickFruitNum
end

-- 获得剩余摘取次数
function CollectWordManager:getLeftPickNum()
    local todayPick = self:getTodayPickNum()
    local perDayPickNum = self:getConfigValue("perDayPickMaxNum") or 3
    return perDayPickNum - todayPick
end

-- 获得初始化成熟时间戳
function CollectWordManager:getOriginRipeTime()
    local fruitData = self:getDataValue("fruitData")
    if not fruitData then return 0 end
    return tonumber(fruitData.ripeTime) or 0
end

-- 获得被帮助的时间
function CollectWordManager:getHelpSpeedTime()
    local fruitData = self:getDataValue("fruitData")
    if not fruitData then return 0 end
    return tonumber(fruitData.helpSpeedTime) or 0
end

-- 果实id
function CollectWordManager:getFruitId()
    local fruitData = self:getDataValue("fruitData")
    if not fruitData then return 0 end
    return fruitData.id or 0
end

-- 果子成熟倒计时时间
function CollectWordManager:getRipenCountDownTime()
    local ripenTime = self:getRipenTime()
    local curTime = TimeKit:timeInMillis()
    return ripenTime - curTime
end

-- 获得真正的成熟时间
function CollectWordManager:getRipenTime()
    local originRipenTime = self:getOriginRipeTime()
    local helpSpeedTime = self:getHelpSpeedTime()
    return originRipenTime - helpSpeedTime
end

-- 获得本次要播的减少时间
function CollectWordManager:getReduceTime()
    local fruitData = self:getDataValue("fruitData")
    if not fruitData then return 0 end
    return tonumber(fruitData.thisOpenHelpSpeedTime) or 0
end

-- 设置本次减少时间
function CollectWordManager:setReduceTime(value)
    local fruitData = self:getDataValue("fruitData")
    if not fruitData then return end
    fruitData.thisOpenHelpSpeedTime = value
    -- 这个字段没什么用
    fruitData.beSpeed = value ~= 0
    self:setDataValue("fruitData", fruitData)
end

-- 别人点链接给我的奖励
function CollectWordManager:getShowBeHelpRewardList()
    return self:getDataValue("showBeHelpRewardList") or {}
end

-- 获得有多少个字
function CollectWordManager:getWordCountById(wordId)
    local wordMap = self:getDataValue("wordMap") or {}
    local strKey = tostring(wordId)
    return wordMap[strKey] or 0
end

-- 是否是字
function CollectWordManager:isWordItem(itemId)
    for _, v in pairs(CollectWordConst.Words) do
        if itemId == v then
            return true
        end
    end
    return false
end

-- 判断获得的字是否是第一次获得
function CollectWordManager:getWordIsNew(itemId)
    if not self:isEnabled() then return false end
    local wordMapTotal = self:getDataValue("wordMapTotal") or {}
    return wordMapTotal[tostring(itemId)] and wordMapTotal[tostring(itemId)] == 1
end

-- 是否已经激活了
function CollectWordManager:hasActived()
    return self:getDataValue("activate")
end

-- 是否可以激活
function CollectWordManager:isCanActive()
    if self:hasActived() then return false end
    local wordMap = self:getDataValue("wordMap")
    if not wordMap then return false end
    for _, v in pairs(CollectWordConst.Words) do
        if not wordMap[tostring(v)] or wordMap[tostring(v)] == 0 then
            return false
        end
    end
    return true
end

function CollectWordManager:getCanAskWordList()
    local list = {}
    local wordMap = self:getDataValue("wordMap") or {}
    for _, v in pairs(CollectWordConst.Words) do
        local strKey = tostring(v)
        if not wordMap[strKey] or wordMap[strKey] == 0 then
            table.insert(list, {itemId = v, num = 1})
        end
    end
    table.sort(list, function(a, b)
        return a.itemId < b.itemId
    end)
    return list
end

function CollectWordManager:isCanAskWord()
    return not self:getTodayHasAskFor()
end

-- 获得可以赠送的字的列表
function CollectWordManager:getCanSendWordList()
    local list = {}
    local wordMap = self:getDataValue("wordMap") or {}
    for _, v in pairs(CollectWordConst.Words) do
        local strKey = tostring(v)
        if wordMap[strKey] and wordMap[strKey] > 0 then
            table.insert(list, {itemId = v, num = wordMap[strKey]})
        end
    end
    table.sort(list, function(a, b)
        return a.itemId < b.itemId
    end)
    return list
end

-- 今天是否已经索要成功了
function CollectWordManager:getTodayHasAskFor()
    local todayData = self:getTodayData()
    if not todayData then return false end
    return todayData.askforSucc
end

-- 是否可以赠送
function CollectWordManager:isCanSendWord()
    local wordMap = self:getDataValue("wordMap") or {}
    for _, v in pairs(CollectWordConst.Words) do
        local strKey = tostring(v)
        if wordMap[strKey] and wordMap[strKey] > 0 then
            return true
        end
    end
    return false
end

-- 果子是否成熟了
function CollectWordManager:hasRipenFruit()
    return self:getRipenTime() <= TimeKit:timeInMillis()
end

-- 摘果子提示
function CollectWordManager:getPickFruitTip()
    local needPro = self:getConfigValue("taskProgress") or {}
    local taskMetaList = self:getConfigValue("gatherWordTaskMetaList") or {}
    for i, v in ipairs(taskMetaList) do
        if v.taskType == CollectWordConst.TaskType.PICK_TOTAL then
            local pro = self:getTaskProgressByType(v.taskType)
            if pro <= v.taskTarget then
                return "果实任务进度：成功摘取"..pro.."/"..v.taskTarget.."次活动果"
            end
        end
    end
    return nil
end

-- 炫耀奖励已经领取了
function CollectWordManager:setShowRewarded()
    self:setDataValue("showReward", true)
end

-- 获得微信炫耀奖励
function CollectWordManager:getWxShowOffReward()
    local isFullLevel = self:getDataValue("fullLevel")
    local rewardList = {}
    if isFullLevel then
        rewardList = self:getConfigValue("showRewardItemFullLevelList") or {}
    else
        rewardList = self:getConfigValue("showRewardItemList") or {}
    end
    return rewardList[1]
end

-- 任务配置
function CollectWordManager:getTaskMetaById(taskId)
    local taskMetaList = self:getConfigValue("gatherWordTaskMetaList") or {}
    for i, v in ipairs(taskMetaList) do
        if v.taskId == taskId then
            return v
        end
    end
    return nil
end

-- 根据任务id判断是否已经领取了
function CollectWordManager:getTaskHasRewarded(taskId)
    if taskId == 0 then
        return self:getDataValue("taskProgressReward")
    end
    local taskRewardSet = self:getDataValue("taskRewardSet") or {}
    return table.exist(taskRewardSet, taskId)
end

-- 任务奖励是否可以领取
function CollectWordManager:isTaskCanRewardById(taskId)
    local taskMeta = self:getTaskMetaById(taskId)
    if not taskMeta then return false end
    if not self:getTaskHasRewarded(taskMeta.taskId) then
        local pro = self:getTaskProgressByType(taskMeta.taskType)
        if pro >= taskMeta.taskTarget then
            return true
        end
    end
    return false
end

function CollectWordManager:handleTipDispose(tip)
    self._hasAutoTip = true
    self._autoTip = tip
    local oldDis = tip.dispose
    tip.dispose = function(this)
        oldDis(this)
        self._hasAutoTip = false
        self._autoTip = nil
        if self._mainVM then
            self._mainVM:resetAutoPopTime()
        end
    end
end

function CollectWordManager:clearTip()
    if self._hasAutoTip and (self._autoTip and not self._autoTip.isDisposed) then
        self._autoTip:close()
    end
end

function CollectWordManager:hasAutoTipInScreen()
    return self._hasAutoTip
end

-- 获得马上就要完成的任务
function CollectWordManager:getUnRechTaskByType(taskType)
    local taskMetaList = self:getConfigValue("gatherWordTaskMetaList") or {}
    for i, v in ipairs(taskMetaList) do
        if v.taskType == taskType then
            local pro = self:getTaskProgressByType(v.taskType)
            if pro < v.taskTarget then
                return pro, v.taskTarget
            end
        end
    end
    return nil,nil
end

-- 是否可以抽奖
function CollectWordManager:canLotter()
    local needPro = tonumber(self:getConfigValue("taskProgress")) or 0
    local count = 0
    local taskMetaList = self:getConfigValue("gatherWordTaskMetaList") or {}
    for i, v in ipairs(taskMetaList) do
        local pro = self:getTaskProgressByType(v.taskType)
        if pro >= v.taskTarget and self:getTaskHasRewarded(v.taskId) then
            count = count + 1
        end
    end
    if needPro <= 0 then
        return false, count, 0
    end
    return count >= needPro and (not self:getTaskHasRewarded(0)), count, needPro
end

-- 是否有任务可以领奖
function CollectWordManager:hasTaskCanReward()
    local taskMetaList = self:getConfigValue("gatherWordTaskMetaList") or {}
    for i, v in ipairs(taskMetaList) do
        if not self:getTaskHasRewarded(v.taskId) then
            local pro = self:getTaskProgressByType(v.taskType)
            if pro >= v.taskTarget then
                return true
            end
        end
    end
    return false
end

-- 发送求加速给好友
function CollectWordManager:sendAskspeedUpToFriend()
    local d = deferred.new()
    local askHelpParam = {
        shareType = CollectWordConst.ShareType.RIPEN_FRUIT,
        itemId = self:getFruitId()
    }
    self:requestShareKey(askHelpParam):next(function(shareKey)
        local context = OpenShareContext.new(OpenShareConst.ShareType.WORD_SPEED, OpenShareConst.ShareTarget.MINI)
            :setActId(CollectWordConst.ACT_ID)
            :setTextParams("o(╥﹏╥)o帮帮我，你也可以领奖励！")
            :setMiniParams({
                imageUrl = _G.ccFullShareImgPath("fruittree/act/collectword/askSpeed.jpg")
            })
            :setAskHelpParams(shareKey, askHelpParam, CollectWordConst.SHARE_ID)
        _G.amfTransaction(TransactionEvent.SHARE, context)
        d:resolve()
    end, function()
        d:reject()
    end)
    return d
end

function CollectWordManager:getLotterResultReward()
    local activateItemList = self:getDataValue("activateItemList") or {}
    return activateItemList and activateItemList[1] or {itemId = CollectWordConst.TASK_SHOW_REAL_ID, num = 1}
end


return CollectWordManager
