local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local SecondRewardPanelVM = require("amf.middleware.ui.kit.commonpanel.view.SecondRewardPanelVM")
local ActivityName = "UnderTheSin"
local Manager = class(ActivityName.."Mgr", BaseFeatureManager)

----------- 可能需要修改start -----------
-- Manager.ACT_ID = 22003
-- Manager.SHARE_ID = 302
-- Manager.SHARE_SUB_TYPE = "help_activity"

function Manager:log(...)
    printx(42, "***** UnderTheSin *****  ", ...)
end

-- 获取常量路径
function Manager:_getConstPath()
    return "amf.feature.localactivity.underthesin.const.UnderTheSinConst"
end

-- 获取model路径
function Manager:_getModelPath()
    return "amf.feature.localactivity.underthesin.model.UnderTheSinModel"
end

-- 如果有自己需要初始化的内容，覆写这个
function Manager:_init()
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)

    -- 注册 求助点回
    require("amf.feature.localactivity.underthesin.share.ResponseAskHelpShareHandler"):create()
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
        {
            -- 场景4强弹改为声明式注册（见 _getAutoPopConfigList）
            key = "AutoPop",
        },
    }
end

-- 强弹框架注入入口：只保存引用，不在 setter 中注册强弹或写业务逻辑
function Manager:setAutoPopupMgr(manager)
    self.autoPopupMgr = manager
end

function Manager:setNetworkStatusManager(networkStatusManager)
    self._networkStatusManager = networkStatusManager
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

-- 实物奖励入口与未领取奖字分离：地址已登记后领奖期仍可进入修改地址。
function Manager:hasPhysicalReward()
    if not self:isEnabled2() then return false end
    return self:getModel():getDataByKey("needContact", false) == true
end

-- 同步所有数据
function Manager:updateData(data, skipSaveLocal, fromServer)
    if not data then return end

    self:getModel():fromServer(data,skipSaveLocal)
    if fromServer == true then
        self.hasGetDataFromServer = true
    end
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
    DcUtil:activity(params)
end

-- 每天一次的活动点：本地标记按自然日失效（needTime=true）
function Manager:dcDayOnce(category, subCategory, ...)
    local key = "dcDayOnce_" .. category .. "_" .. subCategory
    if (self:getModel():getLocalCache(key, true) or 0) >= 1 then return end
    self:getModel():setLocalCache(key, true, 1)
    self:dc(category, subCategory, ...)
end

-- 是否是活动正式期最后一天
function Manager:isLastDay(  )
    local todayStartTime = getDayStartTimeByTS(TimeKit:timeInSec())
    local lastDayStartTime = getDayStartTimeByTS(self:getModel():getMainEndTime())
    return todayStartTime == lastDayStartTime
end

-- 获取服务器时间是活动周期内的第几天
function Manager:getDayFromActOpen( time )
    if not self:isEnabled() then return 0 end
    local startTime = getDayStartTimeByTS(self:getModel():getMainBeginTime())
    local curTime = getDayStartTimeByTS(time or TimeKit:timeInSec())
    return math.floor((curTime-startTime)/86400)+1
end

function Manager:getDayFrom1970( time )
    local curDayStartTime = getDayStartTimeByTS(time or TimeKit:timeInSec())
    return math.ceil(curDayStartTime/86400)
end

-- 检测引导标记
function Manager:hasGuideIndex(index, checkLocalData)
    local hasIndex = self:getModel():hasGuide(index)
    
    if checkLocalData == nil then checkLocalData = true end
    if checkLocalData then
        local hasLocal = self:getModel():getFlagFromLocalByKey("LocalGuideId"..index, false)
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
        self:getModel():saveFlagToLocalByKey("LocalGuideId"..index, false, true)
    end

    local ActCommonHttp = require 'amf.middleware.activity.http.ActCommonHttp'
    ActCommonHttp:setActGuideFlag(self:getConst().actId, index)
end

function Manager:onPassDay()
    if not self:isEnabled() then return end
    self:getModel():passDayClear()
end

-- 主icon奖字
function Manager:hasRewards()
    if not self:isEnabled2() then return false end

    if self:isInMainTime() then
        local isFullClue = self:isFullClue()
        local gotLevelFloorReward = self:getModel():getDataByKey("gotLevelFloorReward",false)
        local needContact = self:getModel():getDataByKey("needContact",false)
        local registerContact = self:getModel():getDataByKey("registerContact",false)
        local todayFreeRewards = self:gotTodayFreeReward()
        local beHelpShowLens = self:getHpNum()

        -- printx(42, "hasMainReward", 
        --     self:canGetProgressReward(), 
        --     (isFullClue and not gotLevelFloorReward),
        --     (needContact and not registerContact),
        --     (not todayFreeRewards),
        --     beHelpShowLens)

        return self:canGetProgressReward()
            or (isFullClue and not gotLevelFloorReward)
            or (needContact and not registerContact)
            or (not todayFreeRewards)
            or (beHelpShowLens > 0)
    
    elseif self:isInRewardTime() then
        local isFullClue = self:isFullClue()
        local gotLevelFloorReward = self:getModel():getDataByKey("gotLevelFloorReward",false)
        local needContact = self:getModel():getDataByKey("needContact",false)
        local registerContact = self:getModel():getDataByKey("registerContact",false)

        -- printx(42, "hasRewardReward",
        --     self:canGetProgressReward(),
        --     (isFullClue and not gotLevelFloorReward),
        --     (needContact and not registerContact))

        return self:canGetProgressReward() or (isFullClue and not gotLevelFloorReward) or (needContact and not registerContact)
    end

    return false
end

-- 普通的addRewards,开宝箱之类的
function Manager:addRewardsNormal(rewardItems, params)
    self:callPlug("Rewards","addRewardsNormal",
    rewardItems,
    params)
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
    -- not 服务器发来且有actInfo，就返回
    if not (fromServer and actInfo) then return end
    
    if not self:isEnabled() then return end

    local topPassLevelId = _G.amfBean("LevelAreaManager"):getTopPassedLevel()
    if topPassLevelId == 20 then
        local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
        ActivityEventCenter:dispatch(ActivityEvent.REBUILD_ACTIVITY_ICON,{actId = self:getConst().actId})
    end
end

function Manager:isGetFreeRewards(day)
    if not self:isEnabled() then return false end

    local day = day or getDayStartTimeByTS(TimeKit:timeInSec())
    local freeRewardDays = self:getModel():getDataByKey("freeRewardDays", {})
    return table.includes(freeRewardDays, day)
end

function Manager:getFullClueNum()
    local handbooks = self:getModel():getDataByKey("handbooks", {})
    local ret = 0
    for k,v in pairs(handbooks) do
        if v.gotClueIds and #v.gotClueIds >= 7 then
            ret = ret + 1
        end
    end
    return ret
end

-- 创建图标icon
function Manager:createIcon( reward )
    if reward.itemId == self:getConst().HealthItemId then
        local icon = UICreateUtil:createSpriteFile("amf/activity/underthesin/materials/collection.png", true)
        return icon
    else
        return GameItemCreator:getPropIcon(reward)
    end
end

------------------ 场景4强弹（声明式注册，替代活动配置 autoPopConfigs） ------------------
-- 需求来源：拾光成歌「强弹规则 / 全局弹窗优先级」。
-- 1. 场景4外层仲裁：每次回到场景4只展示一个活动弹窗，优先级 引流1 > 引流2 > 活动主面板每日强弹。
--    所以这里只声明 1 个 checkPoint，三个面板的优先级在 popStage4 内部仲裁；声明成多个 checkPoint 会被框架在同一次回到场景4里依次弹完。
-- 2. 引流1：当日免费奖励待领取时弹；引流2：有新增好友助力生命值待查看时弹。
-- 3. 主面板每日强弹：场景4每日 1 次；当日可收集线索（含当天与之前天数）全部找到时不弹。
-- 4. 领奖期不弹：由 isEnabled() 的正式期判定拦截。
-- 5. 次数限制：框架 CheckPointNumLimit 配置每日 3 次、次日刷新，对应需求「每日最多弹出3次」；
--    主面板分支另有每日 1 次限制，框架无法在同一个 checkPoint 内按分支计数，沿用活动本地缓存（MainPanelPanelPopCount）自控。
function Manager:_getAutoPopConfigList()
    local PCP = _G.PopupCheckPoint
    local PopStage = AutoPopupConst.PopStage

    return {
        -- 场景4强弹（同一次回到场景4只弹这一个）：仅场景4触发；每日 3 次由框架 CheckPointNumLimit 控制。
        -- check：引流1 / 引流2 / 活动主面板每日强弹任一满足；creator：按上面的优先级只弹其中一个。
        {
            checkPoint = PCP.UNDERTHESIN_STAGE4_POP,
            stages = { PopStage.STAGE_FOUR },
            actId = self:getConst().actId,
            check = function()
                return self:checkCanPopStage4()
            end,
            creator = function(_, onPopOver)
                return function()
                    self:popStage4(onPopOver)
                end
            end,
        },
    }
end

-- 场景4强弹可弹条件：正式期，且引流（每日最多 3 次）或主面板每日强弹（每日 1 次）任一满足
function Manager:checkCanPopStage4()
    if not self:isEnabled() then return false end
    return self:checkCanPopYinLiu() or self:checkCanPopMainPanel()
end

-- 场景4强弹弹出：外层仲裁，三个面板只弹一个，优先级 引流1 > 引流2 > 活动主面板每日强弹
function Manager:popStage4(onPopOver)
    local _, canPopYinLiu1, canPopYinLiu2 = self:checkCanPopYinLiu()
    if canPopYinLiu1 then
        self:popYinLiu1Panel(onPopOver)
    elseif canPopYinLiu2 then
        -- 引流面板2 依赖活动文案标签，先加载再弹；加载失败也要结束本次强弹，避免强弹 FSM 卡在 CheckClose
        _G.amfBean("AssetsUtil"):loadMiniLabels({"underthesin"}):next(function()
            self:popYinLiu2Panel(onPopOver)
        end, function()
            safeRunCall(onPopOver)
        end)
    elseif self:checkCanPopMainPanel() then
        self:popMainPanel(onPopOver)
    else
        -- 入队后状态变化（如已领取免费奖励）导致三个面板都不可弹时，结束本次强弹
        safeRunCall(onPopOver)
    end
end

------------------ 场景4强弹相关 ------------------

function Manager:checkCanPopMainPanel()
    if not self:isEnabled() then
        -- printx(41, Manager.ACT_CH_NAME.." 场景4强弹, 活动不可见")
        return false
    end
    -- 超过每日上限1次
    if self:getModel():getFlagFromLocalByKeyInt("MainPanelPanelPopCount", true) >= 1 then
        -- printx(31, Manager.ACT_CH_NAME.." 场景4强弹, 主面板 今日达到上限1次")
        return false
    end

    -- 能找的线索都找了
    local handbooks = self:getModel():getDataByKey("handbooks", {})
    local handbookMetas = self:getModel():getConfigByKey("handbookMetas", {})
    for k,v in pairs(handbooks) do
        local openTs = table.find(handbookMetas, function( vv )
            return vv.id == v.id
        end).openTs

        if (openTs < TimeKit:timeInMillis()) and (#v.gotClueIds < 7) then
            return true
        end
    end

    -- printx(41, Manager.ACT_CH_NAME.." 场景4强弹, 主面板 所有能找的线索已找完")

    return false
end

-- 引流面板是否可以弹出
function Manager:checkCanPopYinLiu()
    if not self:isEnabled() then
        -- printx(41, Manager.ACT_CH_NAME.." 场景4强弹, 活动不可见")
        return false, false, false
    end
    -- 超过每日上限3次
    if self:getModel():getFlagFromLocalByKeyInt("YinLiuPanelPopCount", true) >= 3 then
        -- printx(31, Manager.ACT_CH_NAME.." 场景4强弹, 引流 今日达到上限3次")
        return false, false, false
    end
    
    local canPop1, canPop2 = false, false
    -- 引流1
    canPop1 = not self:gotTodayFreeReward()
    -- printx(41, Manager.ACT_CH_NAME.." 场景4强弹, 引流1", canPop1)

    -- 引流2
    local newHp = self:getHpNum()
    -- printx(41, Manager.ACT_CH_NAME .. " 场景4强弹, 引流2", newHp)
    if newHp ~= 0 then canPop2 = true end

    return canPop1 or canPop2, canPop1, canPop2
end

function Manager:popMainPanel(done)
    self:getModel():addIntToLocalByKey("MainPanelPanelPopCount", true)
    self:openActivity(done, {from = "Stage4"}, false)
end

-- 新增生命值数
function Manager:getHpNum()
    local actInfo = self:getActInfo()
    if (not actInfo) or (not actInfo.extra) then return 0 end
    local extra = table.deserialize(actInfo.extra)
    if type(extra) ~= "table" then return 0 end
    return extra.beHelpShowLens or 0
end

-- 每日免费奖励
function Manager:gotTodayFreeReward()
    local freeRewardDays = self:getModel():getDataByKey("freeRewardDays", {})
    local today = self:getDayFrom1970()
    local hasGot = table.exist(freeRewardDays, tostring(today))
    local todayFreeRewards = self:getModel():getDataByKey("todayFreeRewards", {})
    local todayReward = todayFreeRewards[1] or {itemId = 10098, num = 10}
    -- printx(31, "gotTodayFreeReward", hasGot, tts(todayReward))
    return hasGot, todayReward
end

-- 是否图鉴全满
function Manager:isFullClue()
    local handbooks = self:getModel():getDataByKey("handbooks", {})
    for k,v in pairs(handbooks) do
        if (not v.gotClueIds) or #v.gotClueIds < 7 then
            return false
        end
    end

    return true
end

-- 是否有未领取的进度奖励
function Manager:canGetProgressReward()
    local handbooks = self:getModel():getDataByKey("handbooks", {})
    for k,v in pairs(handbooks) do
        if (#v.gotClueIds >= 7) and (not v.gotProgressReward) then
            return true
        end
    end

    return false
end

function Manager:openActivity(closeCallback,extra,userClick)
    -- openActivity(nil, {from = "YinLiu1"}, true)
    -- 断网时活动主面板打不开（活动资源/actInfo 都在服务端），只给提示，不进框架流程
    if not self._networkStatusManager:isNetworkEnabled() then
        CommonTip:showTip("网络异常，请检查网络~")
        safeRunCall(closeCallback)
        return
    end
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

function Manager:popYinLiu1Panel(callback)
    local SecondPanelG = require("amf.middleware.ui.kit.panel.second.SecondPanelGVM")
    local hasGot, reward = self:gotTodayFreeReward()
    local panel
    local clickBtn = false
    panel = SecondPanelG.Builder.new()
    :setTitle(self:getConst().actChName)
    :setColorType(self:getConst().actColorType)
    :setTopText({
        text = "快去"..self:getConst().actChName.."活动领取奖励吧~",
        fontSize = 26,
        lineSpace = 10
    })
    :setSubTitle("免费奖励")
    :setRewards({reward},function(reward)
        return self:createIcon(reward)
    end)
    :setButtonsConfig({
			{
				str = "去领奖",
                widthMode = UIButtonConfig.Widths.kShort,
                scaleMode = UIButtonConfig.BtnScales.k90,
                colorMode = UIButtonConfig.ColorMode.green,
				touchFunc = function( event )
					if panel.isDisposed then return end
                    _G.amfBean("AutoPopupMgr"):resetPopup()
                    clickBtn = true
                    panel:close()
					self:openActivity(nil, {from = "YinLiu1"}, true)
				end,

			}
		})
    :setCloseCallback(function(  )
        if not clickBtn then
            safeRunCall(callback)
        end
    end):build()
    
    panel:popout()
    self:callPlug("Panel","managePanelVM",panel)

    DcUtil:UserTrack({
        category = "show",
        sub_category = "attract_panel",
        game_type = "stage",
        game_name = self:getConst().GAME_NAME,
        t1 = 1,
    })
    self:getModel():addIntToLocalByKey("YinLiuPanelPopCount", true, 1)
end

function Manager:popYinLiu2Panel(callback)
    local SecondPanelG = require("amf.middleware.ui.kit.panel.second.SecondPanelGVM")
    local hpNum = self:getHpNum()
    local panel
    local clickBtn = false
    panel = SecondPanelG.Builder.new()
    :setNeedLoadRes({
        "amf/activity/underthesin/materials/collection.png",
    })
    :setTitle(self:getConst().actChName)
    :setColorType(self:getConst().actColorType)
    :setTopText({
        text = "有好友成功助力啦！快去看看吧！",
        fontSize = 26,
        lineSpace = 10
    })
    :setSubTitle("免费奖励")
    :setRewards({{itemId = self:getConst().HealthItemId, num = hpNum}},function(reward)
        return self:createIcon(reward)
    end)
    :setButtonsConfig({{
        str = "去领取",
        widthMode = UIButtonConfig.Widths.kShort,
        scaleMode = UIButtonConfig.BtnScales.k90,
        colorMode = UIButtonConfig.ColorMode.green,
        touchFunc = function(event)
            if panel.isDisposed then
                return
            end
            _G.amfBean("AutoPopupMgr"):resetPopup()
            clickBtn = true
            panel:close()
            self:openActivity(nil, {
                from = "YinLiu2"
            }, true)
        end

    }})
    :setCloseCallback(function()
        if not clickBtn then
            safeRunCall(callback)
        end
    end)
    :build()
    panel:popout()
    self:callPlug("Panel","managePanelVM",panel)

    DcUtil:UserTrack({
        category = "show",
        sub_category = "attract_panel",
        game_type = "stage",
        game_name = self:getConst().GAME_NAME,
        t1 = 2,
    })
    
    self:getModel():addIntToLocalByKey("YinLiuPanelPopCount", true, 1)
end


return Manager
