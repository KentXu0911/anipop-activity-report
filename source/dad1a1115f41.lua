
local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"
local MusicMasterConfig = require 'amf.feature.localactivity.musicmaster.config.MusicMasterConfig'
local PropRegister = require 'amf.feature.localactivity.musicmaster.props.PropRegister'
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local ProgressBar = require "amf.middleware.ui.kit.component.ProgressBar"
local AsyncRunner = require "amf.script.sugar.AsyncRunner"
local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"

local MusicMasterIconMudule = require 'amf.feature.localactivity.musicmaster.module.MusicMasterIconMudule'
local MusicMasterInLevelModule = require 'amf.feature.localactivity.musicmaster.module.MusicMasterInLevelModule'
local MusicMasterPopMudule = require 'amf.feature.localactivity.musicmaster.module.MusicMasterPopMudule'
local MusicMasterPlaySoundModule = require 'amf.feature.localactivity.musicmaster.module.MusicMasterPlaySoundModule'
local MusicMasterNewActModule = require 'amf.feature.localactivity.musicmaster.module.MusicMasterNewActModule'
local HapticsHelper = require 'amf.feature.localactivity.musicmaster.haptics.HapticsHelper'
local MusicMasterDC = require 'amf.feature.localactivity.musicmaster.dc.MusicMasterDC'
local WeekTaskEventCenter = require 'amf.feature.localactivity.weektask.event.WeekTaskEventCenter'

local MusicMasterManager = class("MusicMasterManager", BaseFeatureManager)

local _instance

function MusicMasterManager:getInstance()
    if not _instance then
        _instance = MusicMasterManager.new()
        _instance:initialize()
    end
    return _instance
end

function MusicMasterManager:_init()

    self.busyNum = 0
    self.leveIsEnabled = false

    self:initModule()

    if self:isEnabled() then
        PropRegister:register(self)
    end

    _G.amfEC:registerSystem(self)
    _G.amfEC:registerFeature(self)
    self:setUserStateManager(_G.amfBean("UserStateManager"))
    self:downLoadRes()
    self:initPlugs()
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
end

function MusicMasterManager:initPlugs()
    self:_initPlug("ActSend",{
        plugPath = "amf.feature.localactivity.musicmaster.plug.MusicMasterSendPlug"
    })
    local MusicMasterConfig = require"amf.feature.localactivity.musicmaster.config.MusicMasterConfig"

    self:_getPlug("ActSend"):setActKey(MusicMasterConfig.ACT_ID)

    IconTipEventCenter:register(IconTipEvent.CHECK_ICON_TIP, self.onActCheckIconTip, self)
end

function MusicMasterManager:setAutoPopupMgr(autoPopupMgr)
    self.autoPopupMgr = autoPopupMgr
    local autoPopPlug = self:_getPlug("AutoPop")
    if autoPopPlug then
        autoPopPlug:setAutoPopupMgr(autoPopupMgr)
    end
end

function MusicMasterManager:testPopIconTip()
    self.musicMasterPopMudule:popProgressTip({popProgressTip={canPop = true,value = 1, max = 3}})
end


function MusicMasterManager:testPopIconTip2()
    self.musicMasterPopMudule:popHasNewMatchTip({popHasNewMatchTip={canPop = true}})
end

function MusicMasterManager:setActivityMgr(v)
    self._activityMgr = v
end

function MusicMasterManager:downLoadRes( )
    if not EnvUtil:isMiniGame() then
        AssetsUtil:loadDynamicModule('meta/musicmaster.xml', function()
            if self.musicMasterIconMudule:checkCanCreateIcon() then
                self.musicMasterIconMudule:createIcon()
            end
        end, function()
        end )
    end
end

function MusicMasterManager:isResReady()
    if not EnvUtil:isMiniGame() then
        local ret = AssetsUtil:isModuleResReady("meta/musicmaster.xml")
        return ret
    else
        return true
    end
end

function MusicMasterManager:initModule()
    self.musicMasterIconMudule = MusicMasterIconMudule:create(self)
    self.musicMasterInLevelModule = MusicMasterInLevelModule:create(self)
    self.musicMasterPopMudule = MusicMasterPopMudule:create(self)
    self.musicMasterPlaySoundModule = MusicMasterPlaySoundModule:create(self)
    self.musicMasterNewActModule = MusicMasterNewActModule:create(self)
    self.hapticsHelper = HapticsHelper:create()

    self.musicMasterDC = MusicMasterDC:create()

    local InLevelBridgeModule = require "amf.feature.localactivity.musicmaster.module.InLevelBridgeModule"
    self.inLevelBridgeModule = InLevelBridgeModule:create(self)
end

function MusicMasterManager:setUserStateManager(userStateManager)
    self._userStateManager = userStateManager
end

function MusicMasterManager:_getExtraPlugsConfigList()
    return {
        {key = "AutoPop"},
        {key = "Panel"},
        {key = "Download"},
        {key = "Rewards"},
    }
end

function MusicMasterManager:_getAutoPopConfigList()
    local PopStage = AutoPopupConst.PopStage
    return {
        {
            checkPoint = PopupCheckPoint.MUSIC_MASTER,
            stages = {PopStage.STAGE_THREE, PopStage.STAGE_FOUR},
            actId = MusicMasterConfig.ACT_ID,
            check = function(stageParams)
                if stageParams.popStage == PopStage.STAGE_THREE then
                    return self.musicMasterPopMudule:checkPopOnStage3(stageParams)
                end
                return self.musicMasterPopMudule:checkCanPopStage4() == true
            end,
            pop = function(stageParams, onPopOver)
                if stageParams.popStage == PopStage.STAGE_THREE then
                    local _, popInfo = self.musicMasterPopMudule:checkPopOnStage3(stageParams)
                    return function()
                        self.musicMasterIconMudule:updateIcon("stage3_tip")
                        self.musicMasterPopMudule:popOnStage3(popInfo, onPopOver)
                    end
                end
                return function()
                    self.musicMasterPopMudule:doPopStage4(onPopOver)
                end
            end,
        },
    }
end

function MusicMasterManager:_getModelPath()
    return MusicMasterConfig.LOCAL_PATH..'.model.MusicMasterModel'
end

function MusicMasterManager:_getConstPath()
    return MusicMasterConfig.LOCAL_PATH..'.config.MusicMasterConfig'
end

function MusicMasterManager:getData()
    return self:getModel()
end

function MusicMasterManager:passDayRefreshData()
    if not self:isEnabled2() then return end

    if self:isEnabled()  then
        self:getData():passDayClear()
    end
end

function MusicMasterManager:onActPassDay()
    --
    BaseFeatureManager._checkAndNotifyPassDayOnInit(self)

    local scene = Director:sharedDirector():getRunningSceneLua()

    if scene and (scene:is(HomeScene) or scene:isScene("MainScene")) then
        --弹tip
        local panelNum = self:getObserverNum()
        local hasPanel = panelNum > 0

        if hasPanel then
            self:notify( self:getBaseEvent().kCloseAllPanel )

            if self:isEnabled() then
                CommonTip:showTip("新的一天开始了，数据已更新，请尝试重进活动~")
            else
                CommonTip:showTip("完美演奏家活动已结束！")
            end
        end
    end
end

function MusicMasterManager:onActReceiveEmergency(evt)
    local eventData = evt:getData()

    if eventData and eventData.endPoint == EmergencyConst.MUSIC_MASTER_EVENT and eventData.data then
        if not self:isEnabled() then return end

        local data = table.clone(eventData.data)

        self:getConst():showLog("onActReceiveEmergency")

        local rankList = data.rankList
        if rankList then
            self:getModel():updateRankInfoList(rankList)
            self.inLevelBridgeModule:tryUpdateElDataServer()
            self.musicMasterIconMudule:refreshV2Icon("emergency_rank", {
                rankList = rankList,
            })
        end
    end
end

function MusicMasterManager:onActActInfoUpdate(actInfo,fromServer)
    -- printx(41,"onActActInfoUpdate")
    -- local data = event:getData()
    -- local actInfos = data.actInfos or {}
    -- local actInfo =
    -- {
    --     extra = [[{
    --         "racing": true,
    --         "preRace": false,
    --         "beginTime": 10000,
    --         "mainEndTime": 10000,
    --         "endTime": 10000,
    --         "clientVersionControl": 1,
    --         "minClientVersion": "1.111"
    --     }]],
    --     maxProgress = 2,
    --     progress = 1,
    --     rank = 1,
    --     reward = true,
    --     actId = 4062,
    -- }
    if fromServer then
        if not actInfo then
            --后端停止活动，清理数据，删icon
            self:getData():reset()
            --删Icon
            self.musicMasterIconMudule:removeIcon()
        else
            -- --有数据，判断是否存在icon，如果不存在创建Icon
            if not self.hasLightStart then
                self.downloadPlug:startDownload()
                self:lightStart(function()
                    if self.musicMasterIconMudule:checkCanCreateIcon() then
                        self.musicMasterIconMudule:createIcon()
                    end
                end,nil)
            end
            if self.musicMasterIconMudule:checkCanCreateIcon() then
                self.musicMasterIconMudule:createIcon()
            else
                self.musicMasterIconMudule:updateIcon("act_info_update")
            end
        end
    else
        if not self.hasLightStart then
            self:lightStart(function()
                printx(41,"音乐主界面启动成功")
                if self.musicMasterIconMudule:checkCanCreateIcon() then
                    self.musicMasterIconMudule:createIcon()
                end
            end,nil)
        end
    end
end

function MusicMasterManager:lightStart(startSucc,startFail)
    self.hasLightStart = true
    self:getInfoAsync(startSucc,startFail,startFail,false,true)
end

function MusicMasterManager:getVersion( version )
    local ver = tonumber(string.split(version, ".")[2])
    return ver
end

function MusicMasterManager:isLimitEnabled()

    --等级
    if not self.leveIsEnabled then
        local levelId = _G.amfBean("LevelAreaManager"):getTopPassedLevel()
        if levelId < self:getConst().openPassLevel then 
            return false 
        else
            self.leveIsEnabled = true
        end
    end

    --actInfo
    local actInfo = self:getActInfo()
    if not actInfo then return false end
    local extra = table.deserialize(actInfo.extra)

    --客户端版本
    if self:getConst().cliendVersion < extra.clientVersionControl then return false end

    --版本
    local limitver = self:getVersion( extra.minClientVersion )
    local clientver = self:getVersion( _G.bundleVersion )
    if clientver < limitver then return false end

    return true
end

function MusicMasterManager:isEnabled()
    if self:isLimitEnabled() and (self:getData():isInMainTime() ) then
        return true
    else
        return false
    end
end

function MusicMasterManager:isEnabledAndResReady()
    return self:isEnabled() and self:isResReady()
end

function MusicMasterManager:isEnabled2()
    if self:isLimitEnabled() and (self:getData():isInMainTime() or self:getData():isInRewardTime() ) then
        return true
    else
        return false
    end
end

function MusicMasterManager:getActInfo()
    if _G.amfBean("WinningStreakManager") then
        return _G.amfBean("WinningStreakManager").model:getActInfo(self:getConst().ACT_ID)
    else
        return nil
    end
    -- if _G.amfBean("ActivityMgr") then
    --     return _G.amfBean("ActivityMgr"):getActInfo(self:getConst().ACT_ID)
    -- end
    -- return nil
    -- return {
    --         extra = [[{
    --             "racing": true,
    --             "preRace": false,
    --             "beginTime": 10000,
    --             "mainEndTime": 10000,
    --             "endTime": 10000,
    --             "clientVersionControl": 1,
    --             "minClientVersion": "1.111"
    --         }]],
    --         maxProgress = 2,
    --         progress = 1,
    --         rank = 1,
    --         reward = true,
    --         actId = 4062,
    --     }
end

function MusicMasterManager:getMainEndTime()
    return self:getModel():getMainEndTime()
end

function MusicMasterManager:fromServer( )
    -- self:getData():fromServer(data,config)
    if self:isEnabled() then
        PropRegister:register(self)
    end
    self.musicMasterIconMudule:updateIcon("from_server")
end

function MusicMasterManager:getInfoAsync(successCall, failCall, cancelCall, userClick, bFromLightStart)
    local noLoading = bFromLightStart or (not userClick)
    self.curIsGetInfoing = true

    self:getModel():requestPerfectPlayerInfo( bFromLightStart, not noLoading):next(function(response)
        self.curIsGetInfoing = false

        self:fromServer()
        if successCall then successCall() end
    end, function(response)
        self.curIsGetInfoing = false
        if response:isCancel() then
            if cancelCall then cancelCall() end
        else
            if not noLoading then
                local errCode = response:getErrorCode()
                CommonTip:showErrorTip(errCode)
            end
            if failCall then failCall() end
        end
    end)
end

function MusicMasterManager:commonCreateIconForPropRegister( itemId )

    --通用创建icon， 为了注册的道具创建
    local icon
    if itemId == self:getConst().CollectId then
        --锤子
        icon = Layer:create()
        icon:setAnchorPoint(ccp(0.5,0.5))
        icon:ignoreAnchorPointForPosition(false)
        icon:setContentSize( CCSizeMake(128,128))

        local itemIcon = UICreateUtil:createSpriteWithPlist("amf/activity/musicmaster/materials/MusicMasterIcons.plist", "MusicMasterIcons/56022.png")
        itemIcon:setPositionXY(64,64)
        itemIcon:setScale(0.5)
        icon:addChild(itemIcon)
    elseif itemId == self:getConst().TicketId then
        --门票
        icon = Layer:create()
        icon:setAnchorPoint(ccp(0.5,0.5))
        icon:ignoreAnchorPointForPosition(false)
        icon:setContentSize( CCSizeMake(128,128))

        local itemIcon = UICreateUtil:createSpriteWithPlist("amf/activity/musicmaster/materials/MusicMasterIcons.plist", "MusicMasterIcons/56023.png")
        itemIcon:setPositionXY(64,64)
        itemIcon:setScale(0.5)
        icon:addChild(itemIcon)
    else
        icon = GameItemCreator:getPropIcon({itemId=itemId,num=0})
    end
    return icon
end

function MusicMasterManager:commonCreateItem( itemInfo, wCoinMax )
    --如果是金币，传入了wCoinMax > 0， 那个创建特殊的金币展示
    local showItemInfo = table.clone(itemInfo)

    local iconLayer = Layer:create()

    local icon
    if showItemInfo.itemId == UPropId.GOLD and wCoinMax then
        showItemInfo.num = nil

        icon = WidgetManager:createWidgetObj("UEPropIcon")
        icon:setItem(showItemInfo)
        iconLayer:addChild(icon)

        local goldBgSp = UICreateUtil:createSpriteWithPlist("amf/activity/musicmaster/materials/MusicMasterIcons.plist", "MusicMasterIcons/goldNumBg.png")
        goldBgSp:setScale(3)
        goldBgSp:setPositionXY(0,-85)
        iconLayer:addChild(goldBgSp)

        local label = TTFLabel:createAnimalYH("最多"..wCoinMax, 16)
        label:setAnchorPoint(ccp(0.5, 0.5))
        label:setPositionXY(82/2, 12)
        label:enableOutline(hex2ccc4("A20B2B66"),2)
        label:setTextColor(hex2ccc4("FFFFFFFF"))
        goldBgSp:addChild(label)
    else
        icon = WidgetManager:createWidgetObj("UEPropIcon")
        icon:setItem(showItemInfo)
        iconLayer:addChild(icon)
    end
    return iconLayer
end

function MusicMasterManager:openDescPanel( bPre, animTime, closeCallback)
    if bPre then
        self:openTryoutsExplanationPanel(animTime, closeCallback)
    else
        self:openRewardsExplanationPanel(animTime, closeCallback)
    end
end

-- 打开选拔赛说明面板
function MusicMasterManager:openTryoutsExplanationPanel(animTime,closeCallback)
    _G.amfBean("AssetsUtil"):loadMiniFiles({
        "amf/activity/musicmaster/texture/TryoutsExplanationPanel.plist"
    }):next(function()
        local UIBuilder = require "amf.middleware.ui.export.UIBuilder"
        local IllustrationPanelVM = require "amf.middleware.ui.kit.panel.other.IllustrationPanelVM"
        local uiData = require(MusicMasterConfig.LOCAL_PATH ..  ".view.uisource.TryoutsExplanationPanel_UI")
        local builder = UIBuilder.new(uiData)
        local page = builder:buildUIWithData(nil, nil, { "node_1", "node_1_1", "node_1_2", "node_1_3", "closeBtn" })

        local node = nil
        if _G.amfBean("UserStateManager"):isFMJ() then
            node = builder:createChild("node_1_1")
        elseif not _G.amfBean("UserStateManager"):isColorfulStarFull() then
            node = builder:createChild("node_1_2")
        else
            node = builder:createChild("node_1_3")
        end
        node:setName("node_1")
        node:setPositionXY(95, 1254)
        page:addChild(node)

        local vm = IllustrationPanelVM.Builder.new()
            :setNeedLoadRes({ "amf/activity/musicmaster/texture/TryoutsExplanationPanel.plist" })
            :setAnimTime(0.2)
            :setTitle("")
            :setPages({ page })
            :setPageAnimNodeNames({ { "title", "node_1", "jump_arrow_1", "node_2", "jump_arrow_2", "node_3" } })
            :setCloseCallback(closeCallback)
            :build()
        vm:popout()
        self.panelPlug:managePanelVM(vm)
    end, function()
        if closeCallback then closeCallback() end
        ALog.error("TryoutsExplanationPanel loadRes failed")
    end)
end

-- 打开小组赛阶段说明面板
function MusicMasterManager:openRewardsExplanationPanel(animTime, closeCallback)
    _G.amfBean("AssetsUtil"):loadMiniFiles({
        "amf/activity/musicmaster/texture/RewardsExplanationPanel.plist"
    }):next(function()
        local UIBuilder = require "amf.middleware.ui.export.UIBuilder"
        local IllustrationPanelVM = require "amf.middleware.ui.kit.panel.other.IllustrationPanelVM"
        local uiData = require(MusicMasterConfig.LOCAL_PATH ..  ".view.uisource.RewardsExplanationPanel_UI")
        local builder = UIBuilder.new(uiData)
        local page1 = builder:createChild("page_1", nil, { "node_1", "node_1_1", "node_1_2", "node_1_3", "closeBtn_1" })
        local page2 = builder:createChild("page_2", nil, { "closeBtn_2" })

        local node = nil
        if _G.amfBean("UserStateManager"):isFMJ() then
            node = builder:createChild("node_1_1")
        elseif not _G.amfBean("UserStateManager"):isColorfulStarFull() then
            node = builder:createChild("node_1_2")
        else
            node = builder:createChild("node_1_3")
        end
        node:setName("node_1")
        node:setPositionXY(95, 1254)
        page1:addChild(node)

        local vm = IllustrationPanelVM.Builder.new()
            :setNeedLoadRes({ "amf/activity/musicmaster/texture/RewardsExplanationPanel.plist" })
            :setAnimTime(0.2)
            :setTitle("")
            :setPages({ page1, page2 })
            :setPageAnimNodeNames({
                { "title_1", "node_1", "jump_arrow_1", "node_2", "jump_arrow_2", "node_3" },
                { "title_2", "node_4", "jump_arrow_3", "node_5", "jump_arrow_4", "node_6" }
            })
            :setCloseCallback(closeCallback)
            :build()
        vm:popout()
        self.panelPlug:managePanelVM(vm)
    end, function()
        if closeCallback then closeCallback() end
        ALog.error("RewardsExplanationPanel loadRes failed")
    end)
end

-- 打开进度预览面板
function MusicMasterManager:openProgressPreviewPanel()
    local rewardList = table.clone(self:getModel():getProgressRewardListConfig() or {})
    local plug = self:_getPlug("ActSend")

    for k,v in ipairs(rewardList) do
        local reward = plug:getProgressReplaceReward(v.rewardlist, k)
        local extraRewards = plug:getProgressExtraReward(k)
        local showRewards = plug:mergeShowRewards(reward, extraRewards)
   
        v.rewardlist = showRewards
    end

    local musicNum = self:getModel():getCollectItem() or 0
    local rewardedMusicNum = self:getModel():getRewardedMusicNum() or 0

    local ProgressPreviewPanelVM = require "amf.feature.localactivity.musicmaster.view.ProgressPreviewPanelVM"
    local vm = ProgressPreviewPanelVM:create(self, rewardList, musicNum, rewardedMusicNum)
    vm:popout()
    self.panelPlug:managePanelVM(vm)
end

function MusicMasterManager:managePanelVM(panel)
    self.panelPlug:managePanelVM(panel)
end

--打开活动主面板
--如果是来自关卡内，不发协议， 使用本地数直接打开。
function MusicMasterManager:openActivity( bFromInLevel, closeCallback, userClick, extra, UBFPopDelegate, failCallback )

    local tempCloseCallback = closeCallback
    closeCallback = function()
        if self:getData():isInMainTime() and self:getData():checkProgressIsAllGet() then
            self.musicMasterIconMudule:removeIcon()
        else
            self.musicMasterIconMudule:updateIcon("panel_close")
        end
        safeRunCall(tempCloseCallback)
        -- tempCloseCallback()
    end

    local function openFailFunc()
        safeRunCall(failCallback)
        safeRunCall(closeCallback)
    end

    if userClick == nil then userClick = false end
    if extra == nil then extra = {} end

    local function openMainPanel()
        local MainPanelVM = require 'amf.feature.localactivity.musicmaster.view.MainPanelVM'
        local mainPanel = MainPanelVM:create( { closeCallback =closeCallback, userClick = userClick, extra = extra, manager = self } )
        if UBFPopDelegate then
            mainPanel:setUBFPopDelegate({ popout = UBFPopDelegate.popoutFunc, removePopout = UBFPopDelegate.removeFunc })
        end
        mainPanel:popout()
        self.panelPlug:managePanelVM(mainPanel)
    end

    if bFromInLevel  then
        if self:isEnabledAndResReady() then
            openMainPanel()
        else
            if not self:isResReady() then
                self:downLoadRes()
            end
            safeRunCall(openFailFunc)
        end
    else
        if self:isEnabledAndResReady() then
            self:getInfoAsync( openMainPanel, openFailFunc, openFailFunc, userClick, false )
        else
            if not self:isResReady() then
                self:downLoadRes()
            end
            safeRunCall(openFailFunc)
        end
    end
end

---打开吊牌
function MusicMasterManager:canOpenRankDownPartStart(levelId,levelScene)
    local showType, groupPanelShowType = self:getModel():getPanelShowType()
    if groupPanelShowType == MusicMasterConfig.GroupPanelShowType.kInGroup then--进组
        local ret = self.musicMasterInLevelModule:getPlayLevelState(levelId, levelScene)
        if ret and ret.canRecord then
            return true
        end
    else
        return false
    end
end

function MusicMasterManager:canOpenRankDownPartEnd(ret)
    local showType, groupPanelShowType = self:getModel():getPanelShowType()
    if groupPanelShowType == MusicMasterConfig.GroupPanelShowType.kInGroup then--进组
        if ret and ret.canRecord then
            return true
        end
    else
        return false
    end
end

function MusicMasterManager:canOpenProgressDownPartStart(levelId,levelScene)
    if self:getModel():checkInPre() then
        local ret = self.musicMasterInLevelModule:getPlayLevelState(levelId,levelScene)
        if ret and ret.canRecord then
            return true
        end
    end
    return false
end

function MusicMasterManager:canOpenProgressDownPartEnd(ret)
    if self:getModel():checkInPre() then
        if ret and ret.canRecord then
            return true
        end
    end
    return false
end

function MusicMasterManager:openProgressDownPart(levelId,levelScene,isEnd,isWin)
    local ProgressDownPart = require "amf.feature.localactivity.musicmaster.view.ProgressDownPart"
    local panel = ProgressDownPart:create(levelId,levelScene,self,isEnd,isWin)
    return panel
end

function MusicMasterManager:openRankDownPart(levelId,levelScene,isEnd)
    local RankDownPart = require "amf.feature.localactivity.musicmaster.view.RankDownPart"
    local panel = RankDownPart:create(levelId,levelScene,self,isEnd)
    return panel
end

-- 在线请求统一入口
-- 强强表示必须一个协议一个Request文件，自己建request去吧
function MusicMasterManager:requestServerData(requestName, reqParams, onSuccess, onFail, onCancel, noLoading)
    if noLoading == nil then
        noLoading = true
    end

    local request = require("amf.feature.localactivity.musicmaster.http.Request" .. requestName)
    request:post(reqParams, nil, not noLoading ):next(onSuccess, function(response)
        if response:isCancel() then
            safeRunCall(onCancel, response)
        else
            safeRunCall(onFail, response)
        end
    end)
end

function MusicMasterManager:requestPerfectPlayerStart( sucessCallBack, failCallBack, noLoading)
    -- 不填时保持默认false值
    if noLoading == nil then
        noLoading = false
    end
    local function onSuccess(response)

        local data = response:getData()
        self:getModel():updateRankInfoList(data.rankMemberInfoList)
        if data.arenaRound then
            self:getModel():updatgeArenaRound(data.arenaRound)
        end
        self:getModel():setValue(
            "inLevelCardParticipatedEndTime", self:getModel():getMainEndTime(), true)

        local iconModule = self.musicMasterIconMudule
        if iconModule and type(iconModule.onRaceStarted) == "function" then
            local continuityOk, continuityError = pcall(iconModule.onRaceStarted, iconModule)
            if not continuityOk and ALog and type(ALog.strict_log_error) == "function" then
                ALog.strict_log_error(
                    "[MusicMasterIconV2] advance race animation generation failed: "
                        .. tostring(continuityError)
                )
            end
        end

        --dc
        local bTodayDCCanyu = self:getModel():getFlagFromLocalByKey( self:getConst().dailyDcJoinKey , true, true)
        if not bTodayDCCanyu then
            self.musicMasterDC:dcCanyu()
            self:getModel():saveFlagToLocalByKey( self:getConst().dailyDcJoinKey , true, true, true)
        end

        safeRunCall(sucessCallBack)
    end

    local function onFail(response)
        local errCode = response:getErrorCode()
        CommonTip:showErrorTip(errCode)
        safeRunCall(failCallBack, errCode)
    end

    local function onCancel()
        safeRunCall(failCallBack)
    end

    self:requestServerData("PerfectPlayerStart", {}, onSuccess, onFail, onCancel, noLoading)
end

function MusicMasterManager:requestPerfectPlayerEndReward(sucessCallBack, failCallBack)
    local plug = self:_getPlug("ActSend")

    local function onSuccess(response)
        local data = response:getData()
        plug:handleRewardByProtocol("PerfectPlayerEndReward", data)
        local rank = data.rank

        local curMusicNum = self:getModel():getCollectItem()
        local startNum = self:getModel():getProgressGetNum()----已经领取的数目
        local musicNum = data.musicNum
        self:getModel():updateCollectItem(musicNum)
        local endNum = self:getModel():getPassNodeNum()

        local rankRewardList = data.rankRewardList
        local hasRankReward = not table.isEmpty(rankRewardList)
        local progressRewardList = data.progressRewardList
        local hasProgressReward = not table.isEmpty(progressRewardList)
        local preRewardList = data.preRewardList
        local hasPreRewardList = not table.isEmpty(preRewardList)

        local getNum = musicNum - curMusicNum
        if getNum > 0 then
            WeekTaskEventCenter:dispatch(_G.WeekTaskEvent.ACT_TASK_COMPLETE, { type=_G.WeekTaskType.MUSIC_MASTER_GET_COLLECT, num=getNum})
        end

        local rewards = table.union(rankRewardList, progressRewardList)
        rewards = table.union(rewards, preRewardList)
        rewards = table.mergeRewards(rewards)

        -- 筛除
        rewards = self:getShowRewardsForEndReward(rewards)

        local function getT2Num(startNum,endNum)
            -- body
            local t2 = {}
            for i = startNum+1,endNum do
                table.insert(t2,i)
            end
            return table.concat(t2,"_") or ""
        end
        local t1Table = {
        }
        table.insert(t1Table,hasRankReward and "3" or nil)
        table.insert(t1Table,hasProgressReward and "2" or nil)
        table.insert(t1Table,hasPreRewardList and "1" or nil)
        local t1 = table.concat(t1Table, "_")
        local dcInfo = {
            panel_id = UICreateUtil:getPanelId("AwardTimePanel"),
            t1 = t1,
            t2 = hasProgressReward and getT2Num(startNum,endNum) or nil,
            t3 = hasRankReward and (self:getModel():getAreanDuan() or 0)+1 or nil,
        }
        self.musicMasterDC:dcGetReward(dcInfo)
        if hasRankReward then
            self:addRewards(rankRewardList,{ dcExtra={ dcFeature="win_musician", dcSource="settlement"} })
        end
        if hasProgressReward then
            self:addRewards(progressRewardList,{ dcExtra={ dcFeature="win_musician", dcSource="node_reward"} })
        end
        if hasPreRewardList then
            self:addRewards(preRewardList,{ dcExtra={ dcFeature="win_musician", dcSource="open_reward"} })
        end
        local shopData = {
            evt = response,
            feature = "win_musician",
            source = "node_reward",
            rewardDirectList = table.clone(rewards),
            endCall = function(callData)
                safeRunCall(sucessCallBack,callData)
            end
        }
        if AMFEventConst.TransactionType.EXCHANGE_SHOP_TASK then
            _G.amfTransaction(_G.AMFEventConst.TransactionType.EXCHANGE_SHOP_TASK, {
                subCmd = "processEvent",
                subData = shopData,
            })
        else
            _G.amfTransaction(AMFEventConst.TransactionType.EXCHANGE_SHOP_PROCESS_EVENT, shopData)
        end
    end
    local function onFail(response)
        local errCode = response:getErrorCode()
        CommonTip:showErrorTip(errCode)
        if errCode == 733283 then
            self.musicMasterIconMudule:removeIcon()
        end
        safeRunCall(failCallBack)
    end

    local function onCancel()
        safeRunCall(failCallBack)
    end

    local params = {}
    params = plug:handleRequestParams("PerfectPlayerEndReward", params)
    self:requestServerData("PerfectPlayerEndReward", params, onSuccess, onFail, onCancel, false)
end

function MusicMasterManager:requestPerfectPlayerReward( sucessCallBack, failCallBack )
    local plug = self:_getPlug("ActSend")
    local function onSuccess(response)
        local data = response:getData()

        local curMusicNum = self:getModel():getCollectItem()

        plug:handleRewardByProtocol("PerfectPlayerReward",data)
        local musicNum = data.musicNum
        local musicNumRewarded = data.musicNumRewarded
        local rewards = data.progressRewardList

        self:getModel():updateCollectItem(musicNum)
        self:getModel():updateRewardedMusicNum(musicNumRewarded)

        local getNum = musicNum - curMusicNum
        if getNum > 0 then
            WeekTaskEventCenter:dispatch(_G.WeekTaskEvent.ACT_TASK_COMPLETE, { type=_G.WeekTaskType.MUSIC_MASTER_GET_COLLECT, num=getNum})
        end

        -- self:addRewards( rewards, { dcExtra={ dcFeature="feature", dcSource="source"} } )
        local bGetFinal = self:getModel():checkCanGetFinalProgressReward(musicNumRewarded)
        local function getRewardEndCall( callData )
            local callData = table.clone(callData)
            local showRewards = table.clone(callData.rewardDirectList)
            safeRunCall(sucessCallBack, showRewards, bGetFinal, callData)
        end
        self:addRewardsForShop(rewards,{ dcFeature="win_musician", dcSource="node_reward" }, getRewardEndCall, response )
    end

    local function onFail(response)
        local errCode = response:getErrorCode()
        CommonTip:showErrorTip(errCode)
        safeRunCall(failCallBack)
    end

    local function onCancel()
        safeRunCall(failCallBack)
    end

    local params = {}
    params = plug:handleRequestParams("PerfectPlayerReward",params)
    self:requestServerData("PerfectPlayerReward", params, onSuccess, onFail, onCancel, false)
end

function MusicMasterManager:requestPerfectPlayerSettle( sucessCallBack, failCallBack )
    local plug = self:_getPlug("ActSend")
    local function onSuccess(response)
        local data = response:getData()

        local curMusicNum = self:getModel():getCollectItem()

        plug:handleRewardByProtocol("PerfectPlayerSettle",data)
        local areanDuan = data.arenaDuan
        local rewards = data.rankRewardList
        local rankMemberInfoList = data.rankMemberInfoList

        self:getModel():updateAreanDuan(areanDuan)
        self:getModel():updateRankInfoList(rankMemberInfoList)
        local rankInfoList = self:getModel():getRankInfoListAndSort() --先用后端的算一波rankList，然后再清掉
        self:getModel():clearRankInfoList()
        self:getModel():setPlayEndResetOldWinInfo()
        self:getModel():updateRaceStartTime()

        self:addRewards( rewards, { dcExtra={ dcFeature="win_musician", dcSource="settlement"} } )

        local newMusicNum = self:getModel():getCollectItem()
        local getNum = newMusicNum - curMusicNum
        if getNum > 0 then
            WeekTaskEventCenter:dispatch(_G.WeekTaskEvent.ACT_TASK_COMPLETE, { type=_G.WeekTaskType.MUSIC_MASTER_GET_COLLECT, num=getNum})
        end


        --去掉空白，排序
        local newRankInfoList = {}
        for i,v in ipairs(rankInfoList) do
            if not v.isEmpty then
                table.insert( newRankInfoList, v )
            end
        end
        local function sortFunc( a, b )
            return a.rank < b.rank
        end
        table.sort( newRankInfoList, sortFunc )

        safeRunCall(sucessCallBack, rewards, newRankInfoList )
    end

    local function onFail(response)
        local errCode = response:getErrorCode()
        CommonTip:showErrorTip(errCode)
        safeRunCall(failCallBack)
    end

    local function onCancel()
        safeRunCall(failCallBack)
    end

    local params = {}
    params = plug:handleRequestParams("PerfectPlayerSettle",params)
    self:requestServerData("PerfectPlayerSettle", params, onSuccess, onFail, onCancel, false)
end

function MusicMasterManager:requestPerfectPlayerPreReward( sucessCallBack, failCallBack )
    local plug = self:_getPlug("ActSend")
    local function onSuccess(response)

        local data = response:getData()
        local areanDuan = data.arenaDuan
        plug:handleRewardByProtocol("PerfectPlayerPreReward", data)
        local rewards = data.rewardList
        self:getModel():updatePerRace()
        self:getModel():updateAreanDuan(areanDuan)
        self:addRewards( rewards, { dcExtra={ dcFeature="win_musician", dcSource="open_reward"} } )
        self:getModel():updateRaceStartTime()

        safeRunCall(sucessCallBack, rewards)
    end

    local function onFail(response)
        local errCode = response:getErrorCode()
        CommonTip:showErrorTip(errCode)
        safeRunCall(failCallBack)
    end

    local function onCancel()
        safeRunCall(failCallBack)
    end

    local params = {}
    params = plug:handleRequestParams("PerfectPlayerPreReward", params)
    self:requestServerData("PerfectPlayerPreReward", params, onSuccess, onFail, onCancel, false)
end


function MusicMasterManager:requestPerfectPlayerNotice( sucessCallBack, failCallBack )
    local function onSuccess(response)
        local data = response:getData()

        self:getModel():setPlayEndResetOldWinInfo()
    end

    local function onFail(response)
        local errCode = response:getErrorCode()
        CommonTip:showErrorTip(errCode)
        safeRunCall(failCallBack)
    end

    local function onCancel()
        safeRunCall(failCallBack)
    end

    self:requestServerData("PerfectPlayerNotice", {}, onSuccess, onFail, onCancel, false)
end

function MusicMasterManager:getMaxSucc()
    local curDuan = self:getModel():getAreanDuan()
    local rankRewardList = self:getModel():getRankRewardListByDuan( curDuan )
    local targetWinNum = rankRewardList.streakGoal
    return targetWinNum
end

--开始面板
function MusicMasterManager:getSlData(params)
    if not self:isEnabled() or not self:isResReady() then
        return {}
    end
    local levelScene = params.levelScene
    local levelId = params.levelId
    local isRetry = params.isRetry
    local downPartPriority = {
        ['rankEmptyPart'] = "topThreeNotTaken",---前三名为空时优先级
        ['rankFillPart'] = "topThreeTaken",---前三名不为空时优先级
        ['progressPart'] = "progresspanel",---进度条优先级
    }
    local downPartCreator = {
        ['rankEmptyPart'] = function()
            local panel = self:openRankDownPart(levelId,levelScene,isRetry)
            panel:setPositionY(1090)
            panel:popout()
            return panel
        end,---前三名为空时优先级
        ['rankFillPart'] = function()
            local panel = self:openRankDownPart(levelId,levelScene,isRetry)
            panel:setPositionY(1090)
            panel:popout()
            return panel
        end,---前三名不为空时优先级
        ['progressPart'] = function()
            local panel = self:openProgressDownPart(levelId,levelScene,isRetry)
            panel:setPositionY(1090)
            panel:popout()
            return panel
        end,---进度条优先级
    }
    local nowDownPart = nil
    if self:canOpenRankDownPartStart(params.levelId,params.levelScene) then
        local ranks = self:getModel():getRankInfoListAndSort()
        local finishCount = 0
        for k, v in pairs(ranks) do
            if v.score >= self:getMaxSucc() then
                finishCount = finishCount + 1
            end
        end
        if (finishCount >= 3) then
            nowDownPart = 'rankFillPart'
        else
            nowDownPart = 'rankEmptyPart'
        end
    elseif self:canOpenProgressDownPartStart(params.levelId,params.levelScene) then
        nowDownPart = 'progressPart'
    end
    --[[ params包含
        levelId
        levelScene
        isRetry 是否是重玩面板
        oldStar 旧星星数
        需要其他参数找@siyang.miao
    ]]
    local slpBottomPriority = nil
    local slpBottomCreator = nil
    if nowDownPart then
        slpBottomPriority = downPartPriority[nowDownPart]
        slpBottomCreator = function()
            local root = Node:create()
            AssetsUtil:loadMiniFiles({
                "amf/activity/musicmaster/texture/RankDownPart.plist",
                "amf/activity/musicmaster/texture/ProgressDownPart.plist",
                "amf/activity/musicmaster/materials/MusicMasterMainPanelIcons.plist",
                "amf/activity/musicmaster/spine/up_down_fx.skel",
                "amf/activity/musicmaster/spine/up_fx2.skel",
                "amf/activity/musicmaster/spine/txt_45.skel",
                "amf/activity/musicmaster/spine/txt_123.skel",
            }):next(function()
                if not root.isDisposed then
                    local panel = downPartCreator[nowDownPart]()
                    root:addChild(panel)
                end
            end)
            return root
        end
    end
    local amfData
	amfData = {
        -- 优先级标记，这里测试随便写个，本业务关卡内外自行商定即可
        slpBottomPriority = slpBottomPriority,
        -- 视图创建函数，必须返回一个节点
        slpBottomCreator = slpBottomCreator

    }
    return amfData
end
--过关面板
function MusicMasterManager:getPlData(params)
    if not self:isEnabled() or not self:isResReady() then
        return {}
    end
    local levelScene = params.levelScene
    local levelId = params.levelId
    local downPartPriority = {
        ['rankPart'] = "passlevel",---前三名为空时优先级
        ['progressPart'] = "passlevel",---前三名不为空时优先级
    }
    local levelInfo = UBFGameSceneManager:getInstance():getLevelInfo()
    if not levelInfo or not levelInfo.outLevelAttachData or not levelInfo.outLevelAttachData['music_master'] then
        return {}
    end
    local levelState = levelInfo.outLevelAttachData['music_master']
    local canPlay = nil
    if levelState.state == "FMJ" and levelState.canRecord then--之前非满级
        canPlay = params.star>0
    elseif levelState.state == "MJMC" and levelState.canRecord then--之前满级满菜
        canPlay = params.star>0
    elseif levelState.state == "MJFMC" and levelState.canRecord then--非满星
        canPlay = params.star == 4 and params.oldStar<4
    end
    local downPartCreator = {
        ['rankPart'] = function()
            local panel = self:openRankDownPart(levelId,levelScene,true)
            panel:setPositionY(1090)
            panel:popout()
            return panel
        end,---前三名为空时优先级
        ['progressPart'] = function()
            local panel = self:openProgressDownPart(levelId,levelScene,true,canPlay)
            panel:setPositionY(1090)
            panel:popout()
            return panel
        end,---进度条优先级
    }
    local nowDownPart = nil
    if self:canOpenRankDownPartEnd(levelState) then
        nowDownPart = 'rankPart'
    end
    if self:canOpenProgressDownPartEnd(levelState) then
        nowDownPart = 'progressPart'
    end
    --[[ params包含
        levelId
        levelScene
        oldStar 旧星星数
        star 新星星数
        需要其他参数找@siyang.miao
    ]]
    local plpBottomCreator = nil
    if nowDownPart then
        plpBottomCreator = function()
            local root = Node:create()
            AssetsUtil:loadMiniFiles({
                "amf/activity/musicmaster/texture/RankDownPart.plist",
                "amf/activity/musicmaster/texture/ProgressDownPart.plist",
                "amf/activity/musicmaster/materials/MusicMasterMainPanelIcons.plist",
                "amf/activity/musicmaster/spine/up_down_fx.skel",
                "amf/activity/musicmaster/spine/up_fx2.skel",
                "amf/activity/musicmaster/spine/txt_45.skel",
                "amf/activity/musicmaster/spine/txt_123.skel",
            }):next(function()
                if not root.isDisposed then
                    local panel = downPartCreator[nowDownPart]()
                    root:addChild(panel)
                end
            end)
            return root
        end
    end
    local amfData
	amfData = {
        -- 视图创建函数，必须返回一个节点
        plpBottomCreator = plpBottomCreator
    }
    return amfData
end

function MusicMasterManager:isInLevelEnabled(params)
    local levelScene = params.levelScene
    local levelId = params.levelId
    if not (UBFLevelSceneFunc:isMainLevel(levelScene) or UBFLevelSceneFunc:isFullLevelLib(levelScene)) then return false end

    -- TODO @debao.sang 关卡内是否需要加5步等展示
    if not self:isEnabled() then
        return false
    end
    local showType,groupPanelShowType = self:getModel():getPanelShowType()
    if self:getModel():checkInPre() or groupPanelShowType == MusicMasterConfig.MainPanelShowType.kGroup then
        local ret = self.musicMasterInLevelModule:getPlayLevelState(levelId, levelScene)
        if ret and ret.canRecord then
            return true
        else
            return false
        end
    end
    return false
end

function MusicMasterManager:getProgress()
    if self:isEnabled() then---数据准备好了
        local showType,groupPanelShowType = self:getModel():getPanelShowType()
        if showType == self:getConst().MainPanelShowType.kPre then
            return self:getModel():getPreWinNum()
        else
            if groupPanelShowType == self:getConst().GroupPanelShowType.kInGroup then
                return self:getModel():getSelfRankScore()
            else
                return 0
            end
        end
    else
        return 0
    end
end

function MusicMasterManager:getRank()
    if self:isEnabled() then---数据准备好了
        return self:getModel():getSelfRank()
    else
        return 0
    end
end

function MusicMasterManager:getInLevelActData(levelId, ubfSLRuntime)
    local inLevelActData = {}

    -- TODO @debao.sang 当前连胜数
    inLevelActData.continuousWin = 0
    local showType,groupPanelShowType = self:getModel():getPanelShowType()
    if self:getModel():checkInPre() then
        inLevelActData.continuousWin = self:getModel():getPreWinNum()
    elseif groupPanelShowType == MusicMasterConfig.MainPanelShowType.kGroup then
        inLevelActData.continuousWin = self:getModel():getSelfRankScore()
    end

    local saichang = self:getModel():getAreanDuan()
    local lun = 0
    if self:getModel():checkInPre() then
        saichang = 0
    else
        saichang = self:getModel():getAreanDuan()+1
    end

    local dc = saichang.."_"..self:getModel():getArenaRound().."_"..self:getProgress().."_"..self:getRank()
    inLevelActData.dcActInfo = dc
    -- printx(41,"获取进度数据",tts(inLevelActData))
    return inLevelActData
end

function MusicMasterManager:hasRewards()
    if self:isEnabled2() then
        if self:getData():isInMainTime() then
            return self:hasRewardsInMainTime()
        elseif self:getData():isInRewardTime() then
            return self:hasRewardsInAwardTime()
        else
            return false
        end
    else
        return false
    end
end

function MusicMasterManager:hasRewardsInMainTime()
    --是否有进度奖
    --是否可以结算小组奖
    local hasPreReward = self:getModel():checkCanGetPreReward()
    local hasGroupReward = self:getModel():checkCanGetGroupReward()
    local canGetProgressReward = self:getModel():checkCanGetProgressReward()
    return hasPreReward or hasGroupReward or canGetProgressReward
end

function MusicMasterManager:hasRewardsInAwardTime()
    local hasPreReward = self:getModel():checkCanGetPreReward()
    local hasGroupReward = self:getModel():checkCanGetGroupReward(true)
    local canGetProgressReward = self:getModel():checkCanGetProgressReward()

    return hasPreReward or hasGroupReward or canGetProgressReward
end

function MusicMasterManager:showRewardsPanel(rewards,closeCall)
    local ShowRewardsPanelCVM = require "amf.middleware.ui.kit.panel.reward.ShowRewardsPanelCVM"
    local vm = ShowRewardsPanelCVM.Builder.new()
    :setTitle("活动已结束")
    :setRewards(rewards)
    :setCloseCallback(closeCall)
    :build()
    vm:popout()
    self.panelPlug:managePanelVM(vm)
end

function MusicMasterManager:addRewards(rewards, params)
    self.rewardsPlug:addRewardsNormal(rewards, params)
end

-- 商城加奖励
function MusicMasterManager:addRewardsForShop(rewardBean,params,endCall,evt)
    self:callPlug("Rewards","addRewardsForShop",rewardBean, {
        dcExtra = params
    },endCall,evt)
end

function MusicMasterManager:getShowRewardsForRandomGold( rewards, wCoinMax )
    --加入随机金币数据
    local showRewards = table.clone(rewards)
    if wCoinMax > 0 then
        local goldReward = { itemId = UPropId.GOLD, num = 0, wCoinMax = wCoinMax }
        table.insert( showRewards, 1, goldReward )
    end
    return showRewards
end

function MusicMasterManager:getShowRewardsForGroupReward( rewards )
    --删除门票
    local showRewards = table.clone(rewards)
    for i,v in ipairs(showRewards) do
        if v.itemId == self:getConst().TicketId then
            table.remove( showRewards, i )
            break
        end
    end
    return showRewards
end

function MusicMasterManager:getShowRewardsForEndReward( rewards )
    local showRewards = table.clone(rewards)
    for i,v in reverse_ipair(showRewards) do
        if v.itemId == self:getConst().TicketId or v.itemId == self:getConst().CollectId then
            table.remove( showRewards, i )
        end
    end
    return showRewards
end

function MusicMasterManager:showRewardsPanelForProgress(rewards, closeCall)
    --恭喜获得
    local ShowRewardsPanelVM = require "amf.middleware.ui.kit.panel.reward.ShowRewardsPanelVM"
    local vm = ShowRewardsPanelVM.Builder.new()
        :setTitle("恭喜获得")
        :setRewards(rewards)
        :setCloseCallback(closeCall)
        :build()
    vm:popout()
    self.panelPlug:managePanelVM(vm)
end

---领奖期领奖
function MusicMasterManager:getAwardTimeReward(endCall)
    self:requestPerfectPlayerEndReward(function(rewards)
        if table.isEmpty(rewards) then
            self.musicMasterIconMudule:removeIcon()
            safeRunCall(endCall)
        else
            self:showShopRewardsPanel(rewards,function()
                self.musicMasterIconMudule:removeIcon()
                safeRunCall(endCall)
            end,"活动已结束")
        end
    end,endCall)
end

function MusicMasterManager:onActBeforeStartLevel(data)
    -- printx(41,"MusicMasterManager:onActUBFBeforeStartLevel",tts(data))
    self.musicMasterInLevelModule:onActBeforeStartLevel(data:getData())
end

function MusicMasterManager:onActBeforePlayLevelEnd(data)
    -- printx(41,"MusicMasterManager:onActSendPassLevelStart")
    self.musicMasterInLevelModule:onActSendPassLevelStart(data:getData())

    self.musicMasterPopMudule:onPassLevelAddEndCall()
    -- printx(41,"dahinwdjd")
end



--------------------
-------场景强弹
--------------------


function MusicMasterManager:onActEnterStage4(evt)
end

function MusicMasterManager:onActEnterStage3(event)
end

function MusicMasterManager:onActCheckIconTip(event)
    local data = event:getData()
    local stage = data.stage
    if stage == "STAGE_TWO" then
        self.musicMasterPopMudule:onActCheckIconTip()
    end
end


--------------------
-------新过关强弹
--------------------
function MusicMasterManager:onActEndlevelProgressPrepare( datas )
    self.musicMasterPopMudule:onActEndlevelProgressPrepare( datas )
end

function MusicMasterManager:onActEndlevelProgressThirdPartStart( datas )
    self.musicMasterPopMudule:onActEndlevelProgressThirdPartStart( datas )
end

function MusicMasterManager:onActEndlevelProgressForceComplete( datas )
    self.musicMasterPopMudule:onActEndlevelProgressForceComplete( datas )
end
--------------------


function MusicMasterManager:clearBusy( )
    --清除busy状态
    self.busyNum = 0
end

function MusicMasterManager:setBusy(b)
    local oldNum = self.busyNum
    if b then
        self.busyNum = self.busyNum + 1
    else
        self.busyNum = self.busyNum - 1
    end
    if self.busyNum <0 then
        self.busyNum = 0
    end
end

function MusicMasterManager:isBusy()
    return self.busyNum > 0
end

function MusicMasterManager:getBusy()
    return self.busyNum > 0
end

-----

function MusicMasterManager:loadRes(delegate)
    local successCallback = delegate.successCallback
    local failCallback = delegate.failCallback
    local resList = delegate.resList
    if EnvUtil and EnvUtil:isMiniGame() then
        _G.amfBean("AssetsUtil"):loadMiniFiles(resList):next(successCallback, failCallback)
    else
        safeRunCall(successCallback)
    end
end

function MusicMasterManager:showShopRewardsPanel( rewardsInfo, closeCall, titleStr, titleOffset  )
    self:loadRes({
        resList = {},
        successCallback = function ()
            self:realShowShopRewardsPanel(rewardsInfo, function()
                _G.amfTransaction(TransactionEvent.COLLECT_CARD_FLOW, {
                    flowType = _G.COLLECT_CARD_FLOW_TYPE.OPEN_CARD,
                    rewards = rewardsInfo.rewardDirectList,
                    onComplete = closeCall,
                    onError = closeCall
                })
            end, titleStr, titleOffset)
        end,
        failCallback = function ()
            safeRunCall(closeCall)
        end
    })
end

function MusicMasterManager:realShowShopRewardsPanel( rewardsInfo, closeCall, titleStr, titleOffset )
    --展示商城奖励界面
    --使用商城统一界面
    local subTitle = ''
    local downTip = ''

    local shopIcon = _G.amfBean("ExchangeShopManager"):getExchangeShopIcon()
    local worldPos = ccp(0,0)
    if shopIcon then
        worldPos = shopIcon:getPositionInWorldSpace()
    end

    local subTitleStrTable
    local title = titleStr
    local buttonUpText
    local doCloseCall = closeCall

    local text = {
        desc = {downTip},
    }
    local delegate = {}

    delegate.rewardList = rewardsInfo.rewardList
    delegate.rewardDirectList = rewardsInfo.rewardDirectList
    delegate.repeatList = rewardsInfo.repeatList
    delegate.yuanBaoList = rewardsInfo.yuanBaoList
    delegate.panelType = 1 --： 1 没箱子的 2 有箱子的 3 特殊箱子
    delegate.skinType = 0 --：panelType为2时生效
    delegate.boxType = 0--：panelType为2时生效
    delegate.subTitle = subTitle
    delegate.title = title
    delegate.titleOffset = titleOffset
    delegate.buttonText = buttonUpText
    delegate.bottomText = text
    delegate.closeCallback = doCloseCall
    if shopIcon then
        delegate.targetWorldPos = worldPos
    end
    _G.amfTransaction(TransactionEvent.EXCHANGE_SHOP_TASK, {
        subCmd = "showReward",
        subData = delegate
    })
end

function MusicMasterManager:onActCrashResumeBeforePopPanelConfirm(evt)
    --强行断连胜
    local data = evt.data
    if not self:isEnabled() then return end

    local actInfos = data.actInfos
    for i,v in ipairs(actInfos) do
        if v.actId == self:getConst().ACT_ID then
            self:getModel():changeWinNum(false)
            break
        end
    end
end

function MusicMasterManager:_onCustomGain(event)
    local reward = event:getData()
    local id = reward.itemId
    if id == MusicMasterConfig.CollectId then
        self:getData():addCollectItem(reward.num)
    end
end

return MusicMasterManager
