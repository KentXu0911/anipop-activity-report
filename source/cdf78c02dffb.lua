local MeMeFoxManager = class("MeMeFoxManager")

require "amf.feature.winningstreak.module.memefox.model.MeMeFoxConst"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"

local MeMeFoxLog = require "amf.feature.winningstreak.module.memefox.MeMeFoxLog"
local MeMeFoxModel = require "amf.feature.winningstreak.module.memefox.model.MeMeFoxModel"
local MeMeFoxUtil = require "amf.feature.winningstreak.module.memefox.MeMeFoxUtil"
local deferred = require "amf.script.sugar.deferred"
local Icon = require "amf.feature.winningstreak.module.memefox.view.Icon"
local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local MeMeFoxDC = require "amf.feature.winningstreak.module.memefox.dc.MeMeFoxDC"
local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local V2_FAILED_ROUND_END_WINDOW_SECONDS = 30 * 60
local MEMEFOX_ADJUST_GROUP = "memefox_adjust_v1"

local function logError(message)
    if ALog and ALog.strict_log_error then
        ALog.strict_log_error(message)
    end
end

function MeMeFoxManager:isSkipResponseOptimizeEnabled()
    return MaintenanceManager:getInstance():isEnabledInGroup(MEMEFOX_ADJUST_GROUP, "ON")
end

local _instance
function MeMeFoxManager:getInstance()
    if not _instance then
        _instance = MeMeFoxManager.new()
        _instance:init()
    end
    return _instance
end

function MeMeFoxManager:init()
    self.model = MeMeFoxModel:create()
    self._assetsUtil = _G.amfBean("AssetsUtil")
    self._v2IconCreateGeneration = 0
    self._v2IconCreatePending = false
    self.isCreatingIcon = false
    self._removingActIcon = false
    self._v2RoundEntryRemoved = false
    self._v2FailedRoundRemovalPending = false
    self.iconAdapter = nil
    self.iconDataProvider = nil
    self.dc = MeMeFoxDC.new()
    self.dc:setMgr(self)
    self:registerEvent()

    local InLevelBridgeModule = require "amf.feature.winningstreak.module.memefox.module.InLevelBridgeModule"
    self.inLevelBridgeModule = InLevelBridgeModule:create(self)
    self:_registerAutoPopup()
end

function MeMeFoxManager:_registerAutoPopup()
    local autoPopupMgr = _G.amfBean("AutoPopupMgr", true)
    if not autoPopupMgr then return end
    self._autoPopCheckPoint = autoPopupMgr:registerPopup({
        checkPoint = PopupCheckPoint.CONTINUOUS_TARGET_CHECK,
        stages = {AutoPopupConst.PopStage.STAGE_THREE},
        actId = 4042,
        check = function()
            return self:stage3OrInLevelCanPop() == true
        end,
        pop = function(stageParams, onPopOver)
            -- check/pop 收到的是强弹场景事件对象，事件数据要经 getData 取。
            local nextLevelModeData = (stageParams:getData() or {}).nextLevelModeData
            self:cleanPopReason()
            return self:_createStage3PopupCreator({
                source = 3,
                autoPlayNextLevel = nextLevelModeData and nextLevelModeData.autoPlayNextLevel or false,
            }, onPopOver)
        end,
    })
end

function MeMeFoxManager:registerEvent()
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)
    IconEventCenter:register(IconEvent.ICON_SYSTEM_READY, self.onIconSystemReady, self)
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
end

function MeMeFoxManager:unRegisterEvent()
    self:cancelPendingIconCreate()
    local autoPopupMgr = _G.amfBean("AutoPopupMgr", true)
    if autoPopupMgr and self._autoPopCheckPoint then
        autoPopupMgr:unregisterPopup(self._autoPopCheckPoint)
        self._autoPopCheckPoint = nil
    end
    _G.amfEC:unregisterFeature(self)
    _G.amfEC:unregisterSystem(self)
    IconEventCenter:unregister(IconEvent.ICON_SYSTEM_READY, self.onIconSystemReady)
    PropEventCenter:unregister(PropEvent.CUSTOM_GAIN, self._onCustomGain)
end

function MeMeFoxManager:onIconSystemReady()
    self:createActIcon()
end

function MeMeFoxManager:setPassLevelWin(isWin)
    self.isPassLevelWin = isWin
end

function MeMeFoxManager:getPassLevelWin()
    return self.isPassLevelWin
end

function MeMeFoxManager:setAllPassLevelWin(isWin)
	self.isAllPassLevelWin = isWin
end

function MeMeFoxManager:getAllPassLevelWin()
    if self.isAllPassLevelWin == nil then
        self.isAllPassLevelWin = false
    end
	return self.isAllPassLevelWin
end

function MeMeFoxManager:resetPassLevelInfo()
	self:setPassLevelWin(false)
	self:setAllPassLevelWin(false)
	self.mode2SpecialFailed = false
end

function MeMeFoxManager:onActReceiveEmergency(evt)
    self:onProcessEmergency(evt)
end

function MeMeFoxManager:onSystemEnterForeground()
    TimerUtil.addAlarm(function ()
        local winningStreakManager = _G.amfBean("WinningStreakManager")
        local memeFoxModule = winningStreakManager:getModule(WSConst.ModuleType.MEME_FOX)
        memeFoxModule:sendMainInfo(nil, nil, nil, true)
    end, 0.5)
end

function MeMeFoxManager:onActPlayLevelEnd(evt)
    self:resetPassLevelInfo()
    local data = evt.data
    local isWin = data.isWin
    local levelId = data.levelId
    local levelType = data.levelType
    local failReason = data.failReason
    if isWin then
        self:setAllPassLevelWin(true)
    end
    if levelType ~= GameLevelType.kMainLevel then
        return
    end
    if isWin then
        local mode = self.model:getMeMeFoxMode()
        if mode == _G.MeMeFoxConst.MODE.TOP_LEVEL then
            self:onActPassLevelMode1(data)
        elseif mode == _G.MeMeFoxConst.MODE.COLORFUL_STAR then
            self:onActPassLevelMode2(data)
        elseif mode == _G.MeMeFoxConst.MODE.FULL_LEVEL_LIB then
            self:onActPassLevelMode3(data)
        end
        self:addInLevelCount()
        local status = self.model:getMeMeFoxStatus()
        if status == _G.MeMeFoxConst.STATUS.SUCCESS_NOT_REWARD or
                status == _G.MeMeFoxConst.STATUS.WAITING_JOIN_GROUP
        then
            local canPop =   self:stage3OrInLevelCanPop()
            local process = UBFProcessManager and UBFProcessManager:getCurrEndProcess()
            local runtime = process and process:getResult("runtime")
            if runtime then
                runtime:setEnabledProcessNodes(UBFActivityIdConst.kContinuousTarget, {
                    [UBFProcessNodeEnum.CONTINUOUS_TARGET] = {
                        -- 流程节点是否可以启动
                        isProcessEnabled = canPop
                    },
                })
            end
        end
    else
        self:onActPlayerQuit(data)
    end
    self.inLevelBridgeModule:tryUpdateElData()
end

function MeMeFoxManager:onActPlayerQuit(data)
    local status = self.model:getMeMeFoxStatus()
    local mode = self.model:getMeMeFoxMode()
    if status == _G.MeMeFoxConst.STATUS.RUNNING then
        local canClean = false
        if mode == _G.MeMeFoxConst.MODE.TOP_LEVEL then
            local topLevel = _G.amfBean("LevelAreaManager"):getTopLevelId()
            if data.levelId ~= topLevel then
                return
            end
            canClean = true
        elseif mode == _G.MeMeFoxConst.MODE.COLORFUL_STAR then
            if data and data.oldStar and data.oldStar >= 4 then
                return
            end
            canClean = true
        elseif mode == _G.MeMeFoxConst.MODE.FULL_LEVEL_LIB then
            if MeMeFoxUtil:fullStarLevelLibCanPlay() then
                if not LevelSceneFunc:isFullLevelLib(data.levelScene) then
                    return
                end
            else
                local topLevel = _G.amfBean("LevelAreaManager"):getTopLevelId()
                if data.levelId ~= topLevel then
                    return
                end
            end
            canClean = true
        end
        if canClean then
            self.model:setMeMeFoxStatus(_G.MeMeFoxConst.STATUS.PASS_FAIL)
            --假数据
            self.model:setQuitFakeData()
        end
    end
end

function MeMeFoxManager:onActPassLevelMode1(data)
    if data.oldScore > 0 then
        return
    end
    self:setPassLevelWin(true)
    local topPassLevel = _G.amfBean("LevelAreaManager"):getTopPassedLevel()
    local status = self.model:getMeMeFoxStatus()
    local progress = self.model:getMeMeFoxCurProgress()
    local curTime = TimeKit:timeInSec()
    local actMainEndTime = self.model:getActMainEndTime()
    local memeFoxWinMax = self.model:getMeMeFoxWinMax()

    if (status == _G.MeMeFoxConst.STATUS.RUNNING or
            status == _G.MeMeFoxConst.STATUS.WAITING_JOIN_GROUP) and
            curTime > actMainEndTime then
        return
    end
    if status == _G.MeMeFoxConst.STATUS.NOT_START then
        status = _G.MeMeFoxConst.STATUS.WAITING_JOIN_GROUP
    end
    if topPassLevel == data.levelId and progress <= memeFoxWinMax then
        if status == _G.MeMeFoxConst.STATUS.WAITING_JOIN_GROUP or
                status == _G.MeMeFoxConst.STATUS.RUNNING then
            self.model:setMeMeFoxCurProgress(1)
        end
    end
end

function MeMeFoxManager:onActPassLevelMode2(data)
    if not data then return end
    local isFMJ =  _G.amfBean("UserStateManager"):isFMJ()
    if data.oldStar == 0 and isFMJ then
    else
        if data.oldStar >= 4 then
            return
        end
        if data.star < 4 then
            self.mode2SpecialFailed = true
            return
        end
    end
    self:setPassLevelWin(true)
    local status = self.model:getMeMeFoxStatus()
    local progress = self.model:getMeMeFoxCurProgress()
    local curTime = TimeKit:timeInSec()
    local actMainEndTime = self.model:getActMainEndTime()
    local memeFoxWinMax = self.model:getMeMeFoxWinMax()
    if (status == _G.MeMeFoxConst.STATUS.RUNNING or
            status == _G.MeMeFoxConst.STATUS.WAITING_JOIN_GROUP) and
            curTime > actMainEndTime then
        return
    end
    if status == _G.MeMeFoxConst.STATUS.NOT_START then
        status = _G.MeMeFoxConst.STATUS.WAITING_JOIN_GROUP
    end
    if progress <= memeFoxWinMax then
        if status == _G.MeMeFoxConst.STATUS.WAITING_JOIN_GROUP or
                status == _G.MeMeFoxConst.STATUS.RUNNING then
            self.model:setMeMeFoxCurProgress(1)
        end
    end
end

function MeMeFoxManager:onActPassLevelMode3(data)
    if not data then
        return
    end
    local isFMJ =  _G.amfBean("UserStateManager"):isFMJ()
    local canContinue = false
    if LevelSceneFunc:isFullLevelLib(data.levelScene) then
        canContinue = true
    elseif isFMJ and data.oldStar == 0 and 
    UBFLevelSceneFunc:isMainLevel(data.levelScene) then
        canContinue = true
    end
    if not canContinue then return end
    self:setPassLevelWin(true)
    local status = self.model:getMeMeFoxStatus()
    local progress = self.model:getMeMeFoxCurProgress()
    local curTime = TimeKit:timeInSec()
    local actMainEndTime = self.model:getActMainEndTime()
    local memeFoxWinMax = self.model:getMeMeFoxWinMax()

    if (status == _G.MeMeFoxConst.STATUS.RUNNING or
            status == _G.MeMeFoxConst.STATUS.WAITING_JOIN_GROUP) and
            curTime > actMainEndTime then
        return
    end
    if status == _G.MeMeFoxConst.STATUS.NOT_START then
        status = _G.MeMeFoxConst.STATUS.WAITING_JOIN_GROUP
    end
    if progress <= memeFoxWinMax then
        if status == _G.MeMeFoxConst.STATUS.WAITING_JOIN_GROUP or
                status == _G.MeMeFoxConst.STATUS.RUNNING then
            self.model:setMeMeFoxCurProgress(1)
        end
    end
end

function MeMeFoxManager:onProcessEmergency(evt)
    if evt and evt.data and evt.data.endPoint == EmergencyConst.MEME_FOX_EVENT_BEAN then
        local data = table.clone(evt.data.data)
        if data.announcementInfo then
            local announcementInfoList = {}
            for _, v in pairs(data.announcementInfo.announcementInfoListBig) do
                table.insert(announcementInfoList, v)
            end
            for _, v in pairs(data.announcementInfo.announcementInfoListSmall) do
                table.insert(announcementInfoList, v)
            end
            table.sort(announcementInfoList, function(a, b)
                return tonumber(a.time) > tonumber(b.time)
            end)
            self.model:setAnnouncementInfoList(announcementInfoList)
            self.model:updateServerData(data.info, true)
            if self._v2RoundEntryRemoved == true and self:isIconShow() then
                self:createActIcon()
            end
            local canPop =   self:stage3OrInLevelCanPop()
            local process = UBFProcessManager and UBFProcessManager:getCurrEndProcess()
            local runtime = process and process:getResult("runtime")
            if runtime then
                runtime:setEnabledProcessNodes(UBFActivityIdConst.kContinuousTarget, {
                    [UBFProcessNodeEnum.CONTINUOUS_TARGET] = {
                        -- 流程节点是否可以启动
                        isProcessEnabled = canPop
                    },
                })
            end
            -- 尝试刷新过关面板的数据
            self.inLevelBridgeModule:tryUpdateElData()
        end
    end
end

function MeMeFoxManager:getDataModel()
    return self.model
end

function MeMeFoxManager:getInfoAsync(successCall, failCall, cancelCall, userClick, bFromLightStart, multiCallCancel)
    if self.sendRequesting then
        -- 多次请求多出的直接cancel
        if multiCallCancel then
            safeRunCall(cancelCall)
        end
        return
    end
    self.sendRequesting = true
    local noLoading = bFromLightStart or (not userClick)
    self.model:requestStreakGoalInfo({
        light = bFromLightStart,
        noLoading = noLoading,
        userClick = userClick,
        successCall = function()
            self.lastRequestSuccessTime = TimeKit:timeInMillis()
            self.sendRequesting = false
            safeRunCall(successCall)
        end,
        failCall = function()
            self.sendRequesting = false
            safeRunCall(failCall)
        end,
        cancelCall = function()
            self.sendRequesting = false
            safeRunCall(cancelCall)
        end
    })
end

function MeMeFoxManager:setUIUseData(data)
    self.uiUseData = data
end

function MeMeFoxManager:getUIUseData()
    return self.uiUseData
end

--显示帮助面板
function MeMeFoxManager:showHelpPanel(delegate)
    if not self:mainPanelExist() then
        safeRunCall(delegate.closeCall)
        return
    end
    self:loadRes({
        resList = {"amf/memefox/texture/HelpPanel.plist",},
        successCallback = function ()
            if not self:mainPanelExist() then
                safeRunCall(delegate.closeCall)
                return
            end
            local mode = delegate.mode
            local uiData = require("amf/feature/winningstreak/module/memefox/view/uisource/HelpPanel_UI.lua")
            local builder = UIBuilder.new( uiData )
            local page1 = builder:createChild( "content")
            page1:getChildByName("con3"):getChildByName("stateImage1"):setVisible(mode ~= 2)
            page1:getChildByName("con3"):getChildByName("stateImage2"):setVisible(mode == 2)
            local label = page1:getChildByName("con3"):getChildByName("stateText")
            local preText  = "连胜"
            if mode == 2 then
                preText  = "补彩星连胜"
            end
            label:setString(preText..tostring(self.model:getMeMeFoxWinMax()).."关到达终点")
            local goldLabel = page1:getChildByName("con5"):getChildByName("goldNum")
            goldLabel:setString(self.model:getLastGoldReward())
            local animLimit = delegate.animLimit
            if animLimit == nil then
                animLimit = 1
            end

            local IllustrationPanelVM = require "amf.middleware.ui.kit.panel.other.IllustrationPanelVM"

            local vm = IllustrationPanelVM.Builder.new()
                                          :setNeedLoadRes({ "amf/memefox/texture/HelpPanel.plist" })
                                          :setTitle("")
                                          :setAnimTime(0.2)
                                          :setAnimLimit(animLimit)
                                          :setPageBtnsVisible(false)
                                          :setClickBlankSkip(true)
                                          :setClickContinueTextVisible(false)
                                          :setCloseCallback(delegate.closeCall)
                                          :setPages({page1})
                                          :setPageAnimNodeNames({{"customTitle","con1", "con2","con3","con4","con5","con6"}})
                                          :build()

            vm:setPanelReadyCallback(function()
                vm:setCloseBtnPos(ccp(671, -61))
                vm:setTitlePos(ccp(360, -82))
            end)
            vm:popout()
            self:managerPanel(vm.view)
        end,
        failCallback = function ()
            safeRunCall(delegate.closeCall)
        end
    })
end

function MeMeFoxManager:isBuffItem(itemId)
    if not itemId then
        return false
    end
    itemId = tonumber(itemId)
    return table.exist(_G.MeMeFoxConst.BUFF_ITEM_ID, itemId)
end

function MeMeFoxManager:requestStreakGoalReward(delegate)
    local successCallback = delegate.successCallback
    local failCallback = delegate.failCallback
    local cancelCallback = delegate.cancelCallback
    local request = require("amf.feature.winningstreak.module.memefox.http.StreakGoalReward")
    local function onSuccess(response)
        local data = response:getData()
        safeRunCall(successCallback, data)
    end

    local function onFail(response)
        if response:isCancel() then
            safeRunCall(cancelCallback)
        else
            local errCode = response:getErrorCode()
            MeMeFoxUtil:showErrorTip(errCode)
            safeRunCall(failCallback, errCode)
        end
    end

    request:post({
                     manualEnter = true,
                 }, nil, delegate.loading):next(onSuccess, onFail)
end

--前端通用奖励添加
function MeMeFoxManager:addMultiRewards( rewards, feature, source)
    source = source or "help"
    _G.GainPropData:create()
      :setActId(4042)
      :setFeature(feature)
      :setSource(source)
      :setProps(rewards):execute()
end

--显示分享面板
function MeMeFoxManager:showSharePanel(delegate)
    delegate = delegate or {}
    self.model:getShareInfo({
        successCallback = function ()
            local SharePanelVM = require "amf.feature.winningstreak.module.memefox.view.SharePanelVM"
            local vm = SharePanelVM:create(delegate)
            vm:setCloseCallback(delegate.closeCall)
            vm:popout()
        end,
        failCallback = function ()
            safeRunCall(delegate.closeCall)
        end,
        cancelCallback = function ()
            safeRunCall(delegate.closeCall)
        end,
    })
end

function MeMeFoxManager:getBuffName(reward)
	local str = {
		[_G.MeMeFoxConst.BUFF_ITEM_ID[1]] = "拯救么么狐助力奖励 +110%",
		[_G.MeMeFoxConst.BUFF_ITEM_ID[2]] = "拯救么么狐助力奖励 +120%",
		[_G.MeMeFoxConst.BUFF_ITEM_ID[3]] = "拯救么么狐助力奖励 +130%",
	}
	return str[tonumber(reward.itemId)]
end

--显示中奖记录面板
function MeMeFoxManager:showRecordPanel(delegate)
    delegate = delegate or {}
    local RecordPanelVM = require "amf.feature.winningstreak.module.memefox.view.RecordPanelVM"
    local vm = RecordPanelVM:create(delegate)
    vm:popout()
end

--显示最终大奖面板
function MeMeFoxManager:showUltimateRewardPanel(delegate)
    delegate = delegate or {}
    local UltimateRewardPanelVM = require "amf.feature.winningstreak.module.memefox.view.UltimateRewardPanelVM"
    local vm = UltimateRewardPanelVM:create(delegate)
    vm:popout()
end

function MeMeFoxManager:addMultiRewardsExt(delegate)
    local param = {
        rewardList = delegate.rewardList,
        repeatList = delegate.repeatList,
        rewardDirectList = delegate.rewardDirectList,
        yuanBaoList = delegate.yuanBaoList,
        feature = "win_target",
        source = "help",
        endCall = function (notCardMap, cardMap)
            notCardMap = notCardMap or {}
            if not table.isEmpty(notCardMap) then
                self:addMultiRewards(notCardMap or {}, "win_target", "help")
            end

            _G.amfTransaction(TransactionEvent.EXCHANGE_SHOP_TASK, {
                subCmd = "showReward",
                subData = delegate
            })
        end
    }
    _G.amfTransaction(TransactionEvent.EXCHANGE_SHOP_TASK, {
        subCmd = "addReward",
        subData = param
    })
end

function MeMeFoxManager:preloadModuleRes(successCallback, errorCallback , cancelCallback, needTip, timeoutSeconds)
    if needTip == nil then
        needTip = true
    end
    local preloadFinished = false
    local preloadTimeoutId

    local function clearPreloadTimeout()
        if preloadTimeoutId then
            TimerUtil.removeAlarm(preloadTimeoutId)
            preloadTimeoutId = nil
        end
    end

    local function finishPreload(callback)
        if preloadFinished then
            return
        end
        preloadFinished = true
        clearPreloadTimeout()
        safeRunCall(callback)
    end

    local function onLoadTimeout()
        finishPreload(errorCallback)
    end

    local function onLoadSuccess()
        finishPreload(successCallback)
    end

    local function onLoadError()
        if preloadFinished then
            return
        end
        if needTip then
            CommonTip:showTip("该功能需要联网,请检查网络状态")
        end
        finishPreload(errorCallback)
    end

    local function onLoadCancel()
        finishPreload(cancelCallback)
    end

    if timeoutSeconds then
        preloadTimeoutId = TimerUtil.addAlarm(onLoadTimeout, timeoutSeconds)
    end
    AssetsUtil:loadDynamicModule('meta/Memefox.xml', onLoadSuccess, onLoadError, onLoadCancel, needTip)
end

function MeMeFoxManager:showMainPanel(delegate)
    delegate = delegate or {}
    local getVMFunc = delegate.getVMFunc
    local needTip = delegate.needTip
    local preloadModuleResTimeoutSeconds = delegate.preloadModuleResTimeoutSeconds
    if needTip == nil then
        needTip = false
    end
    if self:isV2IconActive() then
        self:refreshActIcon("beforeMainPanelOpen", delegate)
    elseif isSafeCocosObj(self.icon) then
        self.icon:refreshIcon()
    end
    local function popMain()
        local MainPanelVM = require "amf.feature.winningstreak.module.memefox.view.MainPanelVM"
        local vm = MainPanelVM:create(delegate)
        if not self:isInHomeScene() then
            safeRunCall(getVMFunc, vm)
        end
        vm:popout()
    end
    if EnvUtil:isMiniGame() then
        local preloadFinished = false
        local preloadTimeoutId
        local function clearPreloadTimeout()
            if preloadTimeoutId then
                TimerUtil.removeAlarm(preloadTimeoutId)
                preloadTimeoutId = nil
            end
        end
        local function finishPreload(callback)
            if preloadFinished then
                return
            end
            preloadFinished = true
            clearPreloadTimeout()
            safeRunCall(callback)
        end
        if preloadModuleResTimeoutSeconds then
            preloadTimeoutId = TimerUtil.addAlarm(function ()
                finishPreload(delegate.closeCall)
            end, preloadModuleResTimeoutSeconds)
        end
        _G.amfBean("AssetsUtil"):loadMiniLabels({"memefox"}):next(function ()
            finishPreload(popMain)
        end, function()
            if preloadFinished then
                return
            end
            if needTip then
                CommonTip:showTip("该功能需要联网,请检查网络状态")
            end
            finishPreload(delegate.closeCall)
        end)
    else
        self:preloadModuleRes(function()
            popMain()
        end, function()
            safeRunCall(delegate.closeCall)
        end, function()
            safeRunCall(delegate.closeCall)
        end, needTip, preloadModuleResTimeoutSeconds)
    end

end

function MeMeFoxManager:tryShowMainPanel(delegate)
    delegate = delegate or {}
    self:getInfoAsync(function()
        delegate.needTip = true
        self:showMainPanel(delegate)
    end, nil, nil, true, false)
end

function MeMeFoxManager:isInHomeScene()
    local scene = Director:sharedDirector():getRunningSceneLua()
    return scene and scene:isScene("MainScene")
end

-- stage3
function MeMeFoxManager:onActEnterStage3(evt)
    self:cleanPopReason()
end

function MeMeFoxManager:_createStage3PopupCreator(delegate, onHandleOver)
    local autoPlayNextLevel = delegate.autoPlayNextLevel
    local closeCall = function ()
        safeRunCall(onHandleOver)
    end

    local creator = function ()
        if not self:stage3OrInLevelCanPop() then
            safeRunCall(closeCall)
            return
        end
        local preloadModuleResTimeoutSeconds
        if not self:isInHomeScene() then
            preloadModuleResTimeoutSeconds = _G.MeMeFoxConst.PRELOAD_MODULE_RES_TIMEOUT_SECONDS
        end
        self:refreshReason()
        self:showMainPanel({
            closeCall = closeCall,
            userClick = false,
            source = 3,
            autoPlayNextLevel = autoPlayNextLevel,
            preloadModuleResTimeoutSeconds = preloadModuleResTimeoutSeconds,
        })
    end
    return creator
end

function MeMeFoxManager:popMainPanelInStage3OrInLevel(delegate)
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.CONTINUOUS_TARGET_CHECK)
    end
    local creator = self:_createStage3PopupCreator(delegate, onHandleOver)
    creator()
end


--发新关屏蔽
function MeMeFoxManager:checkCurTimeCanPop()
    return not self:ignoreForTopLevelPlayer()
end

function MeMeFoxManager:ignoreForTopLevelPlayer()
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

function MeMeFoxManager:stage3OrInLevelCanPop()
    local mainEndTime = self.model:getActMainEndTime()
    local hasEntered = (tonumber(mainEndTime) or 0) > 0
        and self.model:getValue("_inLevelCardParticipatedEndTime") == mainEndTime
    local participationMgr = _G.amfBean("ActivityParticipationMgr", true)
    if not hasEntered and participationMgr and participationMgr.shouldReduceAutoPopup
        and participationMgr:shouldReduceAutoPopup(UBFActivityIdConst.kContinuousTarget) then
        return false
    end

    local inLevel = not self:isInHomeScene()
    if not self:stage3OrInLevelCanPopBase() then
        return false
    end
    local mode = self.model:getMeMeFoxWinMax()
    local status = self.model:getMeMeFoxStatus()
    local isWin = self:getPassLevelWin()
    local isAllWin = self:getAllPassLevelWin()
    local curTime = TimeKit:timeInSec()
    local actExtraData = self.model:getActExtraData()
    local removeList = self.model:getRobotInfoEliminateList()
    local roundInitTime = self.model:getRoundInitTime()
    local nowTime = TimeKit:timeInSec()
    if (status == _G.MeMeFoxConst.STATUS.TIMEOUT_FAIL or
            status == _G.MeMeFoxConst.STATUS.PASS_FAIL) then
        if table.isEmpty(removeList) then
            return false
        end
        if (mode == _G.MeMeFoxConst.MODE.TOP_LEVEL or
                mode == _G.MeMeFoxConst.MODE.FULL_LEVEL_LIB) and (not isAllWin) then
            return true
        else
            if self.mode2SpecialFailed then
                return true
            else
                if (not isAllWin) then
                    return true
                end
                return false
            end
        end
    end
    if not inLevel then
        return false
    end
    --进组要求强弹
    if status == _G.MeMeFoxConst.STATUS.WAITING_JOIN_GROUP and isAllWin then
        if not actExtraData or table.isEmpty(actExtraData) then
            return false
        end
        if curTime < tonumber(actExtraData.mainBeginTime)/1000 or
                curTime > tonumber(actExtraData.mainEndTime)/1000 then
            return false
        end
        if getDayStartTimeByTS(nowTime) ~= getDayStartTimeByTS(roundInitTime) then
            return false
        end
        local firstEnterGroupPopFlag = self:getFirstEnterGroupPopFlag()
        if firstEnterGroupPopFlag > 0 then
            local superBirdFlag = self:getSuperBirdPopFlag()
            if superBirdFlag > 0 or not self.model:isSuperBirdActive() then
                return false
            else
                local count = self:getCurInLevelCount()
                if (count - firstEnterGroupPopFlag) > 2 then
                    self:setPopReason("superBirdPop")
                    return true
                else
                    return false
                end
            end
        else
            self:setPopReason("firstEnterGroupPop")
            return true
        end
    end

    if status == _G.MeMeFoxConst.STATUS.RUNNING and isWin and (not table.isEmpty(removeList)) then
        return true
    end
    if status == _G.MeMeFoxConst.STATUS.SUCCESS_NOT_REWARD and isAllWin then
        return true
    end
    return false
end

function MeMeFoxManager:stage3OrInLevelCanPopBase()
    if not self.model:isActValid() then
        return false
    end
    if self:mainPanelExist() then
        return false
    end
    if not self:checkCurTimeCanPop() then
        return false
    end
    if not _G.amfBean("NetworkStatusManager"):isNetworkEnabled() then
        return false
    end
    if self:dontPop() then
        return false
    end
    return true
end

function MeMeFoxManager:dontPop()
    if not self.model:isActValid() then
        return false
    end
    
    local actInfo = self.model:getActExtraData()
	local condition1 = actInfo.openStrongBombStrategy
	local topPassLevel = _G.amfBean("LevelAreaManager"):getTopPassedLevel()
    local localTopLevel = _G.amfBean("LevelUnLockManager"):getLocalTopLevel()
    local status = self.model:getMeMeFoxStatus()
    local process = self.model:getMeMeFoxCurProgress(true)
    local memeFoxWinMax = self.model:getMeMeFoxWinMax()
    local liveNessTagId = self.model:getLiveNessTagId()

    local condition2 = false
	if topPassLevel < (localTopLevel - 60) then
		condition2 = true
	end
	local condition3 = false
	if status == _G.MeMeFoxConst.STATUS.RUNNING then
		for i = 1, memeFoxWinMax do
			if self.model:getCanGetHelpGift(i) then
				if process >= i then
					condition3 = true
					break
				end
			end
		end
	else
		condition3 = true
	end

    if liveNessTagId == 3 and
        MaintenanceManager:getInstance():isEnabledInGroup("1di_Fox_2026", "ON2") and
        status == _G.MeMeFoxConst.STATUS.RUNNING and process < memeFoxWinMax then
        return true
    end

	local condition4 = (liveNessTagId == 3)
	if condition1 and condition2 and (not condition3) and condition4 then
		return true
	end
	return false
end

function MeMeFoxManager:tryPopFailLevel(done)
    if not self.model:isActValid() then
        safeRunCall(done)
        return
    end
    if not _G.amfBean("NetworkStatusManager"):isNetworkEnabled() then
        safeRunCall(done)
        return
    end
    local status = self.model:getMeMeFoxStatus()
    local configMainEndTime = self.model:getConfigMainEndTime()
    local condition1 = (status == _G.MeMeFoxConst.STATUS.TIMEOUT_FAIL or
            status == _G.MeMeFoxConst.STATUS.PASS_FAIL)
    local condition2 = configMainEndTime and TimeKit:timeInSec() < configMainEndTime
    local condition3 = self:checkCurTimeCanPop()
    local condition4 = not self:isInHomeScene()
    local removeList = self.model:getRobotInfoEliminateList()
    local condition5 = not table.isEmpty(removeList)
    if condition1 and condition2 and condition3 and condition4 and condition5 then
        self:showMainPanel({
            source = 3,
            closeCall = function ()
                safeRunCall(done)
            end,
            userClick = false,
        })
    else
        safeRunCall(done)
    end
end

-- 打开去闯关面板
function MeMeFoxManager:openPlayLevelPanel()
    -- 非满级，打开topLevel关开始面板
    _G.amfBean("AutoPopupMgr"):resetPopup()
    
    --打开最高关开始面板
    local playLevelContext = PlayLevelContext.new(nil, PlayLevelContext.PlayType.UN_PASSED_MAIN):setAutoUnlock(true)
    _G.amfTransaction(TransactionEvent.PLAY_LEVEL, playLevelContext)
end

function MeMeFoxManager:openColorFulStarPanel()
    _G.amfBean("FarmLevelManager"):tryOpenRecommendPanel(nil, FarmConst.FarmStarPanelSource.MAIN_SCENE_ASSET)
end

function MeMeFoxManager:checkRound()
    local status = self.model:getMeMeFoxStatus()
    --不明白为什么超时失败就比过关失败要高级，他就会单独显示个小红点
    if status == _G.MeMeFoxConst.STATUS.TIMEOUT_FAIL then
        self.icon:setHasRedIcon(true)
        return
    elseif status ~= _G.MeMeFoxConst.STATUS.NOT_START then
        self.icon:setHasRedIcon(false)
        return
    end

    local hasShow = self.model:getMeMeFoxDotShow()
    if not hasShow then
        self.icon:setHasRedIcon(true)
    else
        self.icon:setHasRedIcon(false)
    end
end

function MeMeFoxManager:onActPassDay()
    self:closeAllPanel()
    if not self.model:isActValid() then
        return
    end
    local status = self.model:getMeMeFoxStatus()
    if  status == _G.MeMeFoxConst.STATUS.END or
            status == _G.MeMeFoxConst.STATUS.FAILED_CD then
        self.model:setMeMeFoxStatus(_G.MeMeFoxConst.STATUS.NOT_START)
    end
    local actExtraData = self.model:getActExtraData()
    if self:isV2IconActive() then
        self:refreshActIcon("passDay", {
            actExtraData = actExtraData,
        })
    elseif self._v2RoundEntryRemoved == true and not self.icon and not self.iconAdapter then
        self:createActIcon()
    end
end

function MeMeFoxManager:shouldEndV2FailedRound(now)
    if not self.model or type(self.model.getMeMeFoxStatus) ~= "function"
        or type(self.model.getActMainEndTime) ~= "function"
        or type(self.model.setMeMeFoxStatus) ~= "function" then
        return false
    end
    if self.model:getMeMeFoxStatus() ~= _G.MeMeFoxConst.STATUS.FAILED_CD then
        return false
    end

    now = tonumber(now) or TimeKit:timeInSec()
    local roundEndTime = tonumber(self.model:getActMainEndTime())
    if not roundEndTime or roundEndTime <= 0
        or roundEndTime - now > V2_FAILED_ROUND_END_WINDOW_SECONDS then
        return false
    end

    return true
end

function MeMeFoxManager:commitV2FailedRoundRemoval()
    self.model:setMeMeFoxStatus(_G.MeMeFoxConst.STATUS.END)
    self._v2RoundEntryRemoved = true
    self._v2FailedRoundRemovalPending = false
end

function MeMeFoxManager:advanceTimeDrivenStatus(now)
    if not self:isV2IconActive() then
        return false
    end
    if self.model:getMeMeFoxStatus() ~= _G.MeMeFoxConst.STATUS.FAILED_CD then
        return false
    end

    now = tonumber(now) or TimeKit:timeInSec()
    local reachTime = tonumber(self.model:getFailCdTime())
    local roundEndTime = tonumber(self.model:getActMainEndTime())
    if not reachTime or reachTime <= 0 then
        reachTime = roundEndTime
    elseif roundEndTime and roundEndTime > 0 and reachTime > roundEndTime then
        reachTime = roundEndTime
    end
    local dayEndTime = TimeKit:getDayStartTimeByTS(now) + 24 * 3600
    if reachTime and reachTime > dayEndTime then
        reachTime = dayEndTime
    end
    if not reachTime or now < reachTime then
        return false
    end

    local configEndTime = tonumber(self.model:getConfigMainEndTime())
    if not configEndTime or now >= configEndTime then
        return false
    end
    local levelAreaManager = _G.amfBean("LevelAreaManager")
    if levelAreaManager:getTopPassedLevel() >= self.model:getMaxPassLevel() then
        return false
    end

    self.model:setMeMeFoxStatus(_G.MeMeFoxConst.STATUS.NOT_START)
    return true
end

function MeMeFoxManager:onTick()
    if self:mainPanelExist() then
        return
    end

    if not self:isInHomeScene() then
        return
    end

    if not self.model:isActValid() then
        local mode = self.model:generateMeMeFoxMode()
        if mode == _G.MeMeFoxConst.MODE.UNKNOWN then
            self:tryRemoveActIcon()
        end
        return
    end

    local curTime
    if self:isV2IconActive() then
        curTime = TimeKit:timeInSec()
        local shouldEndFailedRound = self:shouldEndV2FailedRound(curTime)
        if self._v2FailedRoundRemovalPending == true and not shouldEndFailedRound then
            self._v2FailedRoundRemovalPending = false
        end
        if shouldEndFailedRound then
            self._v2FailedRoundRemovalPending = true
            local removed = self:tryRemoveActIcon(false, true)
            if removed == true then
                self:commitV2FailedRoundRemoval()
            end
            return
        end
        self:advanceTimeDrivenStatus(curTime)
        self:refreshActIcon("tick", {
            now = curTime,
        })
    else
        if isSafeCocosObj(self.icon) then
            self:checkRound()
            self.icon:refreshIcon()
        end
        curTime = TimeKit:timeInSec()
    end

    local status = self.model:getMeMeFoxStatus()
    local actMainEndTime = self.model:getActMainEndTime()
    local memeFoxWinMax = self.model:getMeMeFoxWinMax()
    local curProgress = self.model:getMeMeFoxCurProgress()

    if status == _G.MeMeFoxConst.STATUS.RUNNING and
            curTime >= actMainEndTime and
            curProgress < memeFoxWinMax then
        self.model:setMeMeFoxStatus(_G.MeMeFoxConst.STATUS.TIMEOUT_FAIL)
        self:tryRemoveActIcon()
    end
    if status == _G.MeMeFoxConst.STATUS.WAITING_JOIN_GROUP or
            status == _G.MeMeFoxConst.STATUS.UNKNOWN or
            status == _G.MeMeFoxConst.STATUS.NOT_START and curTime >= actMainEndTime then
        self:tryRemoveActIcon()
    end
end

--icon是否显示
function MeMeFoxManager:isIconShow()
    if not self.model:isActValid() then
        return false
    end
    local mode = self.model:getMeMeFoxMode()
    if mode == _G.MeMeFoxConst.MODE.UNKNOWN  then
        return false
    end

    local lastDayEndTime = self.model:getConfigMainEndTime()
    local status = self.model:getMeMeFoxStatus()
    local failCDTime = self.model:getFailCdTime()
    if status == _G.MeMeFoxConst.STATUS.END then
        return false
    elseif status == _G.MeMeFoxConst.STATUS.NOT_START or
            status == _G.MeMeFoxConst.STATUS.FAILED_CD or
            status == _G.MeMeFoxConst.STATUS.WAITING_JOIN_GROUP then
        if not self.model:isActInMain() then
            return false
        end
        if not lastDayEndTime then
            return false
        end
        local time1 = failCDTime - lastDayEndTime
        local deltay = math.abs(time1)
        if status == _G.MeMeFoxConst.STATUS.FAILED_CD and (deltay <= 3 or time1 > 0) then
            return false
        end
    end
    return true
end

function MeMeFoxManager:startActTick()
    if self.actTick then
        return
    end
    self.lastRound = -1
    self.actTick = TimerUtil.addAlarm(function()
        self:onTick()
    end, 1, 0)
    self:onTick()
end

function MeMeFoxManager:stopActTick()
    if self.actTick then
        TimerUtil.removeAlarm(self.actTick)
        self.actTick = nil
    end
end

function MeMeFoxManager:cancelPendingIconCreate()
    if self._v2IconCreatePending ~= true then
        return false
    end
    self._v2IconCreateGeneration = self._v2IconCreateGeneration + 1
    self._v2IconCreatePending = false
    self.isCreatingIcon = false
    return true
end

function MeMeFoxManager:_beginV2IconCreate()
    self._v2IconCreateGeneration = self._v2IconCreateGeneration + 1
    local generation = self._v2IconCreateGeneration
    self._v2IconCreatePending = true
    self.isCreatingIcon = true

    local function isCurrent()
        return self._v2IconCreatePending == true
            and self._v2IconCreateGeneration == generation
    end

    local function finish()
        if not isCurrent() then
            return false
        end
        self._v2IconCreatePending = false
        self.isCreatingIcon = false
        return true
    end

    local IconV2Config = require "amf.feature.winningstreak.module.memefox.view.IconV2Config"
    local loadDelegate = {
        resList = IconV2Config.getPreloadFiles(),
        successCallback = function()
            if not isCurrent() then
                return
            end
            if self:shouldEndV2FailedRound() then
                self:commitV2FailedRoundRemoval()
                finish()
                return
            end
            if not self:isIconShow() then
                finish()
                return
            end

            local adapter, createError, cleanupOwner, provider = self:createPackageIconAdapter()
            local ownerAdapter = adapter or cleanupOwner
            if not isCurrent() then
                if ownerAdapter then
                    local disposeOk, disposed, disposeError = pcall(ownerAdapter.dispose, ownerAdapter)
                    if not disposeOk then
                        disposeError = disposed
                        disposed = false
                    end
                    if disposed == false then
                        self.iconAdapter = ownerAdapter
                        self.icon = ownerAdapter:getIcon()
                        self.iconDataProvider = nil
                        logError("dispose canceled memefox icon failed: " .. tostring(disposeError))
                    end
                end
                return
            end
            finish()
            if not adapter then
                self.iconAdapter = cleanupOwner
                self.icon = nil
                self.iconDataProvider = nil
                logError("create memefox icon failed: " .. tostring(createError))
                return
            end

            self.iconAdapter = adapter
            self.icon = adapter:getIcon()
            self.iconDataProvider = provider
            self._v2RoundEntryRemoved = false
            self.dc:dcCanYu()
            self:startActTick()
            self:onTick()
        end,
        failCallback = function(detail)
            if finish() then
                logError("load memefox icon resource failed: " .. tostring(detail))
            end
        end,
    }
    local ok, result = xpcall(function()
        return self:loadRes(loadDelegate)
    end, debug.traceback)
    if not ok then
        loadDelegate.failCallback(result)
        return deferred.error(result)
    end
    return result
end

function MeMeFoxManager:createActIcon()
    if self.isCreatingIcon or self.icon then
        return deferred.success()
    end
    if self.iconAdapter then
        local cleaned = self:removeActIcon()
        if cleaned ~= true then
            return deferred.success()
        end
    end
    local useV2Icon = self:isV2IconExperimentEnabled()
    if useV2Icon then
        return self:_beginV2IconCreate()
    end

    self.isCreatingIcon = true
    local loadDelegate = {
        resList = _G.MeMeFoxConst.OTHER_RES,
        successCallback = function ()
            if self:isIconShow() then
                self.dc:dcCanYu()
                self:startActTick()
                self.icon = Icon:create()
                IconEventCenter:addIconEvent(self.icon)
                self:onTick()
                self.isCreatingIcon = false
                self:tryDiscoverNewAct()
            else
                self.isCreatingIcon = false
                self:tryRemoveActIcon()
            end
        end,
    }
    return self:loadRes(loadDelegate)
end

function MeMeFoxManager:createLegacyActIcon()
    return Icon:create()
end

function MeMeFoxManager:isV2IconExperimentEnabled()
    local experiment = require "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"
    local ok, enabled = pcall(experiment.isEnabled, experiment)
    if not ok then
        logError("query memefox V2 icon experiment failed: " .. tostring(enabled))
    end
    return ok and enabled == true
end

function MeMeFoxManager:createPackageIconAdapter()
    local PackageIconV2Adapter = require "amf.feature.mainscene.module.icon.v2.runtime.PackageIconV2Adapter"
    local IconV2Config = require "amf.feature.winningstreak.module.memefox.view.IconV2Config"
    local ownerIconKey = _G.MeMeFoxConst.ICON_KEY
    local options, provider, configError = IconV2Config.create(self, IconEventCenter)
    if not options then
        options = {
            ownerIconKey = ownerIconKey,
            iconEventCenter = IconEventCenter,
            legacyFactory = function()
                return self:createLegacyActIcon()
            end,
            v2PreflightError = configError or "MEME_FOX_ICON_V2_CONFIG_REQUIRED",
        }
        provider = nil
    end

    local adapter, modeOrError, cleanupOwner = PackageIconV2Adapter:create(options)
    if not adapter then
        return nil, modeOrError, cleanupOwner
    end
    return adapter, nil, nil, adapter:isV2Active() and provider or nil
end

function MeMeFoxManager:isV2IconActive()
    return self.iconAdapter and self.iconAdapter:isV2Active() or false
end

function MeMeFoxManager:refreshActIcon(reason, payload)
    if not self:isV2IconActive() then
        return false, "MEME_FOX_ICON_V2_NOT_ACTIVE"
    end
    local refreshed, refreshError = self.iconAdapter:refresh(reason, payload)
    if refreshed == false then
        logError("refresh memefox V2 icon failed: " .. tostring(refreshError))
    end
    return refreshed, refreshError
end

function MeMeFoxManager:consumeV2CurrentCycleNew(reason)
    if not self:isV2IconActive() then
        return true
    end
    return self.iconAdapter:consumeCurrentCycleNew(reason)
end

function MeMeFoxManager:onMainPanelActuallyOpened(source)
    if source ~= 3 or not self:isV2IconActive() then
        return true
    end
    return self:consumeV2CurrentCycleNew("scene3_actual_open")
end

function MeMeFoxManager:tryDiscoverNewAct()
    local winningStreakManager = _G.amfBean("WinningStreakManager")
    local memeFoxModule = winningStreakManager:getModule(WSConst.ModuleType.MEME_FOX)
    local uniqueKey = memeFoxModule:getDiscoverNewActKey()
    local iconKey = memeFoxModule:getIconKey()
    local iconLabel = memeFoxModule:getIconLabel()
    _G.amfBean("PopupNewActMgr"):addNewAutoPopPkgAct(uniqueKey, iconKey, iconLabel)
end

function MeMeFoxManager:removeActIcon()
    if self._removingActIcon == true then
        return false, "MEME_FOX_ICON_REMOVE_IN_PROGRESS"
    end
    self._removingActIcon = true
    local ok, result, detail = xpcall(function()
        local pendingCanceled = self:cancelPendingIconCreate()
        if self.iconAdapter then
            self:closeAllPanel()
            local disposed, disposeError = self.iconAdapter:dispose()
            if disposed == false then
                logError("dispose memefox icon failed: " .. tostring(disposeError))
                return false, disposeError
            end
            self:stopActTick()
            self.iconAdapter = nil
            self.icon = nil
            self.iconDataProvider = nil
            return true
        end

        if self.icon then
            self:closeAllPanel()
            IconEventCenter:removeIconEvent(IconKey.kSaveMeMeIcon)
            self.icon = nil
            self:stopActTick()
            return true
        end
        if pendingCanceled then
            return true
        end
        return false
    end, debug.traceback)
    self._removingActIcon = false
    if not ok then
        logError("remove memefox icon failed: " .. tostring(result))
        return false, result
    end
    return result, detail
end

function MeMeFoxManager:tryRemoveActIcon(isCleanModel, isForce)
    if isCleanModel == nil then
        isCleanModel = true
    end
    if isForce == nil then
        isForce = false
    end
    local function shouldRemoveIcon()
        return isForce or not self:isIconShow()
    end
    if self.iconAdapter then
        if not shouldRemoveIcon() then
            return false
        end
        local removed, removeError = self:removeActIcon()
        if removed == true and isCleanModel then
            self.model:cleanMeMeFoxModel()
        end
        return removed, removeError
    end

    if self._v2IconCreatePending == true then
        if not shouldRemoveIcon() then
            return false
        end
        local canceled = self:cancelPendingIconCreate()
        if canceled and isCleanModel then
            self.model:cleanMeMeFoxModel()
        end
        return canceled
    end

    if self.icon ~= nil and shouldRemoveIcon() then
        if isCleanModel then
            self.model:cleanMeMeFoxModel()
        end
        return self:removeActIcon()
    end
    return false
end

function MeMeFoxManager:loadRes(delegate)
    local successCallback = delegate.successCallback
    local failCallback = delegate.failCallback
    local resList = delegate.resList
    if EnvUtil:isMiniGame() then
        AssetsUtil:loadMiniFiles(resList):next(successCallback, failCallback)
    else
        safeRunCall(successCallback)
    end
end

function MeMeFoxManager:hasReward()
    if not self.model:isActValid() then
        return false
    end
    return self.model:hasReward()
end

function MeMeFoxManager:hasPanel(panel)
    self.panels = self.panels or {}
    for _, v in pairs(self.panels) do
        if v == panel then
            return true
        end
    end
    return false
end

function MeMeFoxManager:removePanel(panel)
    self.panels = self.panels or {}
    table.removeIfExist(self.panels, panel)
end

function MeMeFoxManager:managerPanel(panel)
    if self:hasPanel(panel) then
        return
    end
    self.panels = self.panels or {}
    table.insert(self.panels, panel)
    local oriFunc = panel.dispose
    panel.dispose = function(obj)
        self:removePanel(panel)
        safeRunCall(oriFunc, obj)
    end
end

function MeMeFoxManager:closeAllPanel()
    self.panels = self.panels or {}
    for i = #self.panels, 1, -1 do
        local panel = self.panels[i]
        if isSafeCocosObj(panel) and panel.sendCommand then
            panel:sendCommand("onCloseBtnTapped")
        end
    end
    self.panels = {}
end

function MeMeFoxManager:setMainPanel(mainPanel)
    self.mainPanel = mainPanel
end

function MeMeFoxManager:mainPanelExist()
    return self.mainPanel ~= nil
end

function MeMeFoxManager:isSupportShare()
    if not EnvUtil:isAMFEnabled() then
        return false
    end
    if EnvUtil:isWindows() then
        return false
    end
    if EnvUtil:isMiniGame() then
        return true
    else
        if PlatformConfig:isPlatform(PlatformNameEnum.kMiTalk) then
            return false
        end
        if WXJPPackageUtil and WXJPPackageUtil.getInstance():isWXJPPackage() then
            return false
        end
		if (PlatformConfig:isPlatform(PlatformNameEnum.kHE) or
				PlatformConfig:isPlatform(PlatformNameEnum.kDouYinLh) or
				PlatformConfig:isPlatform(PlatformNameEnum.kIOS)) and
				EnvUtil:isWXAppInstalled() then
            return true
        end
    end
    return false
end

function MeMeFoxManager:createSuperBirdTip(param)
    local parent = param.parent
    local w, h = 132, 150
    local layer = Layer:create() --LayerColor:createWithColor(hex2ccc4("aaaaaaFF"), w, h)
    layer:setContentSize(CCSize(w, h))

    local desc = TTFLabel:createAnimalYH("超鸟生效中\n连胜更容易", 22)
    desc:setPositionXY(-52, -50)
    desc:setTextColor(hex2ccc4("B56846FF"))
    layer:addChild(desc)

    local icon = UICreateUtil:createSpriteFile("amf/memefox/texture/superBird.png")
    layer:addChild(icon)

    local tip = UITip.Builder.new()
                     :setContent(layer)
                     :setAutoCloseTime(-1)
                     :setDirection(UITip.Direction.RIGHT)
                     :setDoNotClickClose(true)
                     :buildSingleTip()
    tip:setName("SuperBirdTip")
    parent:addChild(tip)
    tip:setPositionXY(492, -970)
    layer:setPositionXY(132, 100)
    tip:setVisible(false)
    tip:runAction(ActionUtil:sequence{
        CCDelayTime:create(0.3),
        CCCallFunc:create(function()
            if not isSafeCocosObj(tip) then return end
            tip:setVisible(true)
            tip:runAppearAnim()
        end)
    })
    return tip
end

-- 本地缓存
function MeMeFoxManager:saveFlagToLocalByKeyInt(key, needTime, popNum)
    if not key then return end
    if popNum == nil then popNum = 0 end
    local keyStr = 'CommonMgrBaseV2_Int_'.._G.MeMeFoxConst.ACT_ID..'_'.. key
    keyStr = keyStr..'_v'
    if needTime then
        local curTime = TimeKit:timeInSec()
        local dayStartTime = getDayStartTimeByTS(curTime)
        keyStr = keyStr .. ':' .. dayStartTime
    end
    LocalDB:setInt(keyStr, popNum)
end

function MeMeFoxManager:getFlagFromLocalByKeyInt(key, needTime, defaultValue)
    if defaultValue == nil then
        defaultValue = 0
    end
    local keyStr = 'CommonMgrBaseV2_Int_'.._G.MeMeFoxConst.ACT_ID..'_'.. key
    keyStr = keyStr..'_v'
    if needTime then
        local curTime = TimeKit:timeInSec()
        local dayStartTime = getDayStartTimeByTS(curTime)
        keyStr = keyStr .. ':' .. dayStartTime
    end
    return LocalDB:getInt(keyStr, defaultValue)
end

function MeMeFoxManager:addInLevelCount()
    local count = self:getFlagFromLocalByKeyInt("InLevelCount", true, 0)
    self:saveFlagToLocalByKeyInt("InLevelCount", true, count + 1)
end

function MeMeFoxManager:getCurInLevelCount()
    return self:getFlagFromLocalByKeyInt("InLevelCount", true, 0)
end

function MeMeFoxManager:cleanPopReason()
    self.popReason = nil
end

function MeMeFoxManager:setPopReason(reason)
    self.popReason = reason
end

function MeMeFoxManager:getFirstEnterGroupPopFlag()
    local round = self.model:getRound()
    local count = self:getFlagFromLocalByKeyInt("FirstEnterGroupPopFlag"..round, true, 0)
    return count
end

function MeMeFoxManager:setFirstEnterGroupPopFlag()
    local count = self:getCurInLevelCount()
    local round = self.model:getRound()
    self:saveFlagToLocalByKeyInt("FirstEnterGroupPopFlag"..round, true, count)
end

function MeMeFoxManager:getSuperBirdPopFlag()
    local round = self.model:getRound()
    local count = self:getFlagFromLocalByKeyInt("SuperBirdPopFlag"..round, true, 0)
    return count
end

function MeMeFoxManager:setSuperBirdPopFlag()
    local count = self:getCurInLevelCount()
    local round = self.model:getRound()
    self:saveFlagToLocalByKeyInt("SuperBirdPopFlag"..round, true, count)
end

function MeMeFoxManager:refreshReason()
    if self.popReason == "firstEnterGroupPop" then
        self:setFirstEnterGroupPopFlag()
    elseif self.popReason == "superBirdPop" then
        self:setSuperBirdPopFlag()
    end
    self:cleanPopReason()
end

function MeMeFoxManager:onActEndlevelProgressThirdPartStart(evt)
    local data = evt.data
    if table.isEmpty(data) then return end
    local processNodeKey = data.processNodeKey
    local function popEnd()
        if table.isEmpty(data) then return end
        data:finishProcessCallBack()
    end
    local function popoutFunc(panel)
        data:popoutView(panel, UBFProcessNodePopLayerType.POPOUT)
    end
    local function removeFunc(panel)
        data:removeView(panel)
    end
    if processNodeKey == UBFProcessNodeEnum.CONTINUOUS_TARGET then
        local status = self.model:getMeMeFoxStatus()
        if status == _G.MeMeFoxConst.STATUS.FAILED_CD or
                status == _G.MeMeFoxConst.STATUS.TIMEOUT_FAIL or
                status == _G.MeMeFoxConst.STATUS.PASS_FAIL or
                not self:stage3OrInLevelCanPop() then
            popEnd()
            return
        end
        local preloadModuleResTimeoutSeconds
        if not self:isInHomeScene() then
            preloadModuleResTimeoutSeconds = _G.MeMeFoxConst.PRELOAD_MODULE_RES_TIMEOUT_SECONDS
        end
        self:refreshReason()
        self:showMainPanel({
            getVMFunc = function (vm)
                vm:setUBFPopDelegate({ popout = popoutFunc, removePopout = removeFunc })
            end,
            source = 3,
            closeCall = function ()
                popEnd()
            end,
            userClick = false,
            preloadModuleResTimeoutSeconds = preloadModuleResTimeoutSeconds,
        })
    end
end

function MeMeFoxManager:onActCrashResumeBeforePopPanelConfirm(evt)
    if not self.model:isActValid() then
        return
    end
    --强行断连胜
    local data = evt.data
    local actInfos = data.actInfos
    local createPanelFuncList = data.createPanelFuncList
    local needPopMainPanel = false
    for i,v in ipairs(actInfos) do
        if v.actId == _G.MeMeFoxConst.ACT_ID then
            self.model:setMeMeFoxStatus(_G.MeMeFoxConst.STATUS.PASS_FAIL)
            --假数据
            self.model:setQuitFakeData()
            needPopMainPanel = true
            break
        end
    end

    if needPopMainPanel then
        local function createPanelFunc(done)
            if not self.model:isActValid() then
                safeRunCall(done)
                return
            end
            self:showMainPanel({
                closeCall = function()
                    safeRunCall(done)
                end,
                userClick = false,
                source = 3,
            })
        end
        table.insert(createPanelFuncList, createPanelFunc)
    end

end

-- 检查是否已弹出过新关卡提示
function MeMeFoxManager:hasNewLevelTipShowed()
    local showedRound = self.model:getValue("_newLevelTipShowedRound")
    return showedRound ~= nil
end

-- 标记已弹出
function MeMeFoxManager:saveNewLevelTipShowed()
    self.model:setValue("_newLevelTipShowedRound", true)
end

-- 清空记录（进组时调用）
function MeMeFoxManager:clearNewLevelTipShowed()
    self.model:setValue("_newLevelTipShowedRound", nil)
end

-- 检查是否需要弹出新关卡提示
function MeMeFoxManager:shouldShowNewLevelTip()
    -- 1. 补彩星模式
    local mode = self.model:getMeMeFoxMode()
    if mode ~= _G.MeMeFoxConst.MODE.COLORFUL_STAR then
        return false
    end
    
    -- 2. 连胜进行中状态
    local status = self.model:getMeMeFoxStatus()
    if status ~= _G.MeMeFoxConst.STATUS.RUNNING then
        return false
    end
    
    -- 3. 非满级（isFMJ = true 表示非满级）
    local isFMJ = _G.amfBean("UserStateManager"):isFMJ()
    if not isFMJ then
        return false
    end
    
    -- 4. 未弹过
    if self:hasNewLevelTipShowed() then
        return false
    end
    
    return true
end

-- 标记当前轮次已弹出
function MeMeFoxManager:markNewLevelTipShowed()
    self:saveNewLevelTipShowed()
end

---------------------------------- CUSTOM_GAIN ----------------------------------

function MeMeFoxManager:_onCustomGain(event)
    local reward = event:getData()
    local buffIds = _G.MeMeFoxConst.BUFF_ITEM_ID
    local id = reward.itemId
    if id == buffIds[1] or id == buffIds[2] or id == buffIds[3] then
        self.model:addBuff({reward})
    end
end

return MeMeFoxManager
