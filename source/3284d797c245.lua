local UIUseData = require("amf.feature.winningstreak.module.memefox.view.UIUseData")
local MeMeFoxLog = require "amf.feature.winningstreak.module.memefox.MeMeFoxLog"
local AsyncRunner = require "amf.script.sugar.AsyncRunner"
local MeMeFoxViewHelper = require "amf.feature.winningstreak.module.memefox.view.MeMeFoxViewHelper"
local MeMeFoxUtil = require "amf.feature.winningstreak.module.memefox.MeMeFoxUtil"

local MainPanelVM = class("MainPanelVM", AMFBasePanelVM)

local function logError(message)
    if ALog and ALog.strict_log_error then
        ALog.strict_log_error(message)
    end
end

function MainPanelVM:_createPanel(...)
    local MainPanel = require("amf.feature.winningstreak.module.memefox.view.MainPanel")
    local panel = MainPanel:create(MainPanelVM, ...)
    return panel
end

function MainPanelVM:init(delegate)
    self.canClickContinueClose = true
    self.delegate = delegate or {}
    self.skipResponseOptimizeEligible = false
    self.skipResponseOptimizeClosing = false
end

function MainPanelVM:initUIUseData()
    local winningStreakManager = _G.amfBean("WinningStreakManager")
    local memeFoxModule = winningStreakManager:getModule(WSConst.ModuleType.MEME_FOX)
    self.mgr = memeFoxModule:getMgr()
    local uiUseData = UIUseData:create({
        delegate = self.delegate,
        mgr = self.mgr,
        vm = self,
        view = self.view
    })

    self.mgr:setUIUseData(uiUseData)
    if uiUseData.panelState == _G.MeMeFoxConst.STATUS.NOT_START then
        local isV2IconActive = self.mgr:isV2IconActive()
        if not isV2IconActive then
            self.mgr.model:saveMeMeFoxDotShow()
            if self.mgr.icon then
                self.mgr.icon:setHasRedIcon(false)
            end
        end
    end
end

function MainPanelVM:refreshUIUseData()
    self.mgr.uiUseData:refreshData()
end

function MainPanelVM:firstLoadCompleted()
    self:initUIUseData()
    self:callViewFunc("initUI", self.mgr)
    self:callViewFunc("replaceCloseBtn")
end

function MainPanelVM:secondLoadCompleted()
    local willJoinGroup = false

    if self.mgr.uiUseData.panelState <= _G.MeMeFoxConst.STATUS.NOT_START then
        willJoinGroup = true
    elseif self.mgr.uiUseData.panelState == _G.MeMeFoxConst.STATUS.WAITING_JOIN_GROUP then
        willJoinGroup = true
    end
    self:refreshState(self.mgr.uiUseData.panelState, willJoinGroup)
    self:callViewFunc("initButtons")
    
    -- 检查是否需要弹出新关卡提示
    if self.mgr:shouldShowNewLevelTip() then
        TimerUtil.addAlarm(function()
            if self.isDisposed then return end
            self.mgr:markNewLevelTipShowed()
            CommonTip:showTip("新关开启了，现在闯主线关也计算连胜哦", nil, nil, 5)
        end, 0.5)
    end
end

function MainPanelVM:onEnterPanelRun()
    if self.mgr:isV2IconActive() then
        local consumed, consumeError = self.mgr:onMainPanelActuallyOpened(self.delegate.source)
        if consumed == false then
            logError("consume memefox V2 new activity failed: " .. tostring(consumeError))
        end
    end
end

function MainPanelVM:isPreState()
    if self.mgr.uiUseData.panelState == _G.MeMeFoxConst.STATUS.NOT_START or
            self.mgr.uiUseData.panelState == _G.MeMeFoxConst.STATUS.FAILED_CD or
            self.mgr.uiUseData.panelState == _G.MeMeFoxConst.STATUS.WAITING_JOIN_GROUP then
        return true
    end
    return false
end

function MainPanelVM:isNormalState()
    if self.mgr.uiUseData.panelState == _G.MeMeFoxConst.STATUS.RUNNING or
            self.mgr.uiUseData.panelState == _G.MeMeFoxConst.STATUS.TIMEOUT_FAIL or
            self.mgr.uiUseData.panelState == _G.MeMeFoxConst.STATUS.PASS_FAIL or
            self.mgr.uiUseData.panelState == _G.MeMeFoxConst.STATUS.SUCCESS_NOT_REWARD or
            self.mgr.uiUseData.panelState == _G.MeMeFoxConst.STATUS.END then
        return true
    end
    return false
end

--刷新状态
function MainPanelVM:refreshState(state, hasJoinAnim)
    self.mgr.uiUseData.panelState = state
    self:callViewFunc("resetPanelState")
    if self:isPreState() then
        self.mgr.dc:dcPrepareShow()
        self:callViewFunc("createPreStateNode")
        self:callViewFunc("refreshPreState", hasJoinAnim)
    elseif self:isNormalState() then
        self:callViewFunc("refreshNormalState", hasJoinAnim)
        self.mgr.dc:dcMainPanelShow(self.delegate.source)
    end
end

function MainPanelVM:closePanelFunc()
    safeRunCall(self.delegate.closeCall)
    self.mgr.model:setHasReward()
    if self.mgr and self.mgr.closeAllPanel then
        self.mgr:closeAllPanel()
    end
end

--显示帮助面板
function MainPanelVM:onShowHelpPanel(delegate)
    local animLimit = delegate.animLimit
    local closeCall = delegate.closeCall
    self.mgr:showHelpPanel({
        mode = self.mgr.uiUseData.mode,
        animLimit = animLimit,
        closeCall = closeCall,
    })
end

function MainPanelVM:tryPopJoinGroup()
    if self.isDisposed then return end
    local asyncRunner = AsyncRunner:create()
    local canJoinGroup = false
    local mainEndTime = self.mgr.model:getConfigMainEndTime()
    local mainBeginTime = self.mgr.model:getConfigMainBeginTime()
    local roundInitTime = self.mgr.model:getRoundInitTime()
    local curTime = TimeKit:timeInSec()
    self.mgr:clearNewLevelTipShowed()
    if not mainBeginTime or not mainEndTime or
        getDayStartTimeByTS(curTime) ~= getDayStartTimeByTS(roundInitTime) then
        self:closePanelFunc()
        local removed, removeError = self.mgr:tryRemoveActIcon(true, true)
        if removed == false and removeError ~= nil then
            logError("remove invalid memefox icon failed: " .. tostring(removeError))
        end
        CommonTip:showTip("数据错误，请退出活动重试~")
        return
    end
    if (self.mgr.uiUseData.panelState == _G.MeMeFoxConst.STATUS.WAITING_JOIN_GROUP or
            self.mgr.uiUseData.panelState == _G.MeMeFoxConst.STATUS.NOT_START) then
        if curTime > mainEndTime or curTime < mainBeginTime then
            self:closePanelFunc()
            local removed, removeError = self.mgr:tryRemoveActIcon(true, true)
            if removed == false and removeError ~= nil then
                logError("remove expired memefox icon failed: " .. tostring(removeError))
            end
            CommonTip:showTip("活动已结束~")
            return
        end
        canJoinGroup = true
    end

    if not canJoinGroup then
        return
    end

    local optimizeSkip = self.mgr:isSkipResponseOptimizeEnabled()

    --申请奖励
    asyncRunner:add(function (done)
        if self.isDisposed then return end
        self.mgr.dc:dcJoin()
        self.mgr:requestStreakGoalReward({
                                             successCallback = function(serverData)
                                                 local firstOpen = self.mgr.uiUseData.firstOpen
                                                 self.mgr.model:updateUserData(serverData.userData)
                                                 self.mgr.model:setValue(
                                                     "_inLevelCardParticipatedEndTime",
                                                     self.mgr.model:getActMainEndTime(), true)
                                                 self:refreshUIUseData()
                                                 self.mgr.uiUseData.firstOpen = firstOpen
                                                 self.mgr.uiUseData.isJoinGroup = true
                                                 if optimizeSkip and self.isDisposed then
                                                     self.mgr:refreshActIcon("join_success")
                                                     return
                                                 end
                                                 safeRunCall(done)
                                             end,
                                             failCallback = function()
                                             end,
                                             cancelCallback = function()
                                             end,
                                         })
    end)

    asyncRunner:add(function (done)
        if self.isDisposed then return end
        self.mgr.model:setMeMeFoxStatus(_G.MeMeFoxConst.STATUS.RUNNING)
        self:callViewFunc("resetPanelState")
        self:callViewFunc("refreshNormalState", true)
        self.mgr.dc:dcMainPanelShow(self.delegate.source)
        safeRunCall(done)
    end)

    asyncRunner:run()
end

function MainPanelVM:onOptimizedSkipResponse()
    if self.isDisposed or self.skipResponseOptimizeClosing then return end
    self.skipResponseOptimizeClosing = true
    if self.asyncRunner then
        self.asyncRunner:clean()
    end
    self:callViewFunc("immediateFinishUnderAnim")
    self:callViewFunc("immediateFinishHeadAnim")
    self:onCloseBtnTapped()
end

function MainPanelVM:onShowAnnouncement()
    self.mgr.model:requestStreakGoalAnnouncementInfo({
        successCall = function()
            if self.isDisposed then return end
            self.mgr:showRecordPanel({

            })
        end,
        failCall = function()

        end,
        cancelCall = function()

        end,
        light = false,
    })
end

function MainPanelVM:tryRequestReward(done)
    if self.isDisposed then return end

    local memefoxWinMax = self.mgr.uiUseData.memefoxWinMax
    local curProcess = self.mgr.uiUseData.curProcess
    local panelState = self.mgr.uiUseData.panelState
    local hasMissHelpReward = false
    local missHelpRewardIndex = {}
    self.missHelpRewards = {}
    for i = 1, memefoxWinMax do
        local reward = self.mgr.model:getCanGetHelpGift(i)
        if reward then
            if i < curProcess or
                    (i == curProcess and
                            (panelState == _G.MeMeFoxConst.STATUS.TIMEOUT_FAIL or
                                    panelState == _G.MeMeFoxConst.STATUS.PASS_FAIL)) then
                hasMissHelpReward = true
                table.insert(missHelpRewardIndex, i)
            end
        end
    end
    local hasCurrentHelpReward = false
    local currentHelpRewardIndex = {}
    self.currentHelpRewards = {}
    if panelState ~= _G.MeMeFoxConst.STATUS.TIMEOUT_FAIL and panelState ~= _G.MeMeFoxConst.STATUS.PASS_FAIL then
        local underAnim = self.view:getUnderAnim(curProcess)
        if isSafeCocosObj(underAnim) and underAnim.rewardBubble and underAnim.rewardBubbleInfo then
            hasCurrentHelpReward = true
            table.insert(currentHelpRewardIndex, curProcess)
        end
    end
    local hasFinalReward = false
    self.finalRewardRealGold = nil
    if panelState == _G.MeMeFoxConst.STATUS.SUCCESS_NOT_REWARD then
        hasFinalReward = true
    end
    if hasMissHelpReward or hasCurrentHelpReward or hasFinalReward then
        self.skipResponseOptimizeEligible = false
        self.mgr:requestStreakGoalReward({
            successCallback = function(serverData)
                if serverData and serverData.activityRewards and serverData.activityRewards.helpGiftRewardList then
                    for _, v in pairs(serverData.activityRewards.helpGiftRewardList) do
                        if table.exist(missHelpRewardIndex, tonumber(v.index)) then
                            table.insert(self.missHelpRewards, v.exchangeRewardResult)
                        elseif table.exist(currentHelpRewardIndex, tonumber(v.index)) then
                            table.insert(self.currentHelpRewards, v.exchangeRewardResult)
                        end
                    end
                end
                if serverData and serverData.activityRewards and serverData.activityRewards.windmillCoinReward then
                    self.finalRewardRealGold = serverData.activityRewards.windmillCoinReward
                    if self.finalRewardRealGold and self.finalRewardRealGold.num > 0 then
                        local Meta = require 'amf.feature.localactivity.supermagicbird.config.SuperMagicBirdConst'
                        _G.amfEC:notifyNormal("SuperMagicBirdActGetGold", 
                        {
                            from = Meta.extraRewardLogForm.kMemeHu,
                            gold = self.finalRewardRealGold.num 
                        })
                    end
                end
                self:callViewFunc("addSkipLayer")
                safeRunCall(done)
            end,
            failCallback = function()
                if self.asyncRunner then self.asyncRunner:clean() end
                self:callViewFunc("addSkipLayer")
            end,
            cancelCallback = function()
                if self.asyncRunner then self.asyncRunner:clean() end
                self:callViewFunc("addSkipLayer")
            end,
        })
    else
        self.skipResponseOptimizeEligible = self.mgr:isSkipResponseOptimizeEnabled() and
            panelState == _G.MeMeFoxConst.STATUS.RUNNING and
            self.view.inLevelShowLabel:isVisible()
        self:callViewFunc("setSkipResponseOptimizeEligible", self.skipResponseOptimizeEligible)
        self:callViewFunc("addSkipLayer")
        safeRunCall(done)
    end
end

--处理之前错过的
function MainPanelVM:tryGetMissHelpReward(done)
    if self.isDisposed then return end
    local temp = {
        repeatList = {},
        rewardDirectList = {},
        rewardList = {},
        yuanBaoList = {},
    }
    if self.missHelpRewards and not table.isEmpty(self.missHelpRewards) then
        for _, reward in pairs(self.missHelpRewards) do
            for _, v in pairs(reward.rewardList) do
                table.insert(temp.rewardList, v)
            end
            for _, v in pairs(reward.rewardDirectList) do
                if self.mgr:isBuffItem(v.itemId) then
                    v.hideNum = true
                end
                table.insert(temp.rewardDirectList, v)
            end
            for _, v in pairs(reward.repeatList) do
                table.insert(temp.repeatList, v)
            end
            for _, v in pairs(reward.yuanBaoList) do
                table.insert(temp.yuanBaoList, v)
            end
        end
    else
        safeRunCall(done)
        return
    end

    temp.rewardDirectList = table.mergeRewards(temp.rewardDirectList)
    if (not table.isEmpty(temp.repeatList)) or
            (not table.isEmpty(temp.rewardDirectList)) or
            (not table.isEmpty(temp.rewardList)) or
            (not table.isEmpty(temp.yuanBaoList)) then
        if self.gotMissHelpReward then
            safeRunCall(done)
            return
        end
        self.gotMissHelpReward = true
        MeMeFoxViewHelper:delayTimeCall(self.view.ui, 0.1, function()
            self.mgr:addMultiRewardsExt({
                closeCallback = function ()
                    if self.isDisposed then return end
                    safeRunCall(done)
                end,
                subTitle = "么么狐送上随机奖励，继续加油！",
                rewardList = temp.rewardList,
                repeatList = temp.repeatList,
                rewardDirectList = temp.rewardDirectList,
                yuanBaoList = temp.yuanBaoList,
            })
        end)
    else
        safeRunCall(done)
        return
    end
end

function MainPanelVM:tryGetCurrentHelpReward(done)
    if self.isDisposed then return end
    local curProcess  = self.mgr.uiUseData.curProcess

    local underAnim = self.view:getUnderAnim(curProcess)
    if self.currentHelpRewards and not table.isEmpty(self.currentHelpRewards) then
        local temp = self.currentHelpRewards[1]
        for _ ,v in pairs(temp.rewardDirectList or {}) do
            if self.mgr:isBuffItem(v.itemId) then
                v.hideNum = true
            end
        end
        if self.gotCurrentHelpReward then
            safeRunCall(done)
            return
        end
        self.gotCurrentHelpReward = true
        self.mgr:addMultiRewardsExt({
            closeCallback = function ()
                if self.isDisposed then return end
                if self.view.inLevelShowLabel:isVisible() then
                    safeRunCall(done)
                else
                    if underAnim and underAnim.refCocosObj and underAnim.rewardBubble then
                        underAnim.rewardBubble:setVisible(false)
                    end
                    safeRunCall(done)
                end
            end,
            subTitle = "么么狐送上随机奖励，继续加油！",
            rewardList = temp.rewardList or {},
            repeatList = temp.repeatList or {},
            rewardDirectList = temp.rewardDirectList or {},
            yuanBaoList = temp.yuanBaoList or {},
        })
    else
        safeRunCall(done)
    end
end

function MainPanelVM:popAnimNormal(hasJoinAnim)
    if self.isDisposed then return end
    local removeHeadList = self.view:getJumpToWaterHeadList()
    local remainHeadList = self.view:getJumpToNextHeadList()
    local isJoinGroup = self.mgr.uiUseData.isJoinGroup
    local mode = self.mgr.uiUseData.mode

    self.asyncRunner = AsyncRunner:create()
    MeMeFoxViewHelper:updateZOrder()
    self:callViewFunc("refreshGoBtn")
    --尝试获取助力奖励，开局助力，以及最终大奖信息
    self.canClickContinueClose = false
    TimerUtil.addAlarm(function()
        if self.isDisposed then return end
        self.canClickContinueClose = true
    end, 6)

    self.asyncRunner:add(function (done)
        self:tryRequestReward(function()
            safeRunCall(done)
        end)
    end)

    --处理之前错过的奖励
    self.asyncRunner:add(function (done)
        if self.isDisposed then return end
        self:tryGetMissHelpReward(done)
    end)

    self.asyncRunner:add(function (done)
        if self.isDisposed then return end
        if not hasJoinAnim then
            safeRunCall(done)
            return
        end
        MeMeFoxViewHelper:delayTimeCall(self.view.ui, 1, function()
            safeRunCall(done)
        end)
    end)

    --self.asyncRunner:add(function (done)
    --    if not self.mgr.model:hasGuideIndex(mode) and isJoinGroup then
    --        self.mgr.model:addGuideIndex(mode)
    --        self:onShowHelpPanel({
    --            animLimit = 1,
    --            closeCall = function ()
    --                if self.isDisposed then return end
    --                safeRunCall(done)
    --            end
    --        })
    --    else
    --        safeRunCall(done)
    --    end
    --end)

    self.asyncRunner:add(function (done)
        if self.isDisposed then return end
        if not hasJoinAnim then
            safeRunCall(done)
            return
        end
        self:callViewFunc("scrollToBottom", 1)
        MeMeFoxViewHelper:delayTimeCall(self.view.ui, 1, function()
            safeRunCall(done)
        end)
    end)

    self.asyncRunner:add(function (done)
        if not hasJoinAnim then
            safeRunCall(done)
            return
        end

        self:callViewFuncWithCallback("showJoinAnim",  function()
            if self.isDisposed then return end
            safeRunCall(done)
        end, _G.amfBean("LevelAreaManager"):getTopLevelId())

    end)

    self.asyncRunner:add(function (done)
        MeMeFoxViewHelper:delayTimeCall(self.view.ui, 0.2, function()
            safeRunCall(done)
        end)
    end)

    --播放自己成功跳台子
    self.asyncRunner:add(function (done)
        if self.isDisposed then return end
        self:callViewFuncWithCallback("tryLetMeJumpToNextUnder", done)
    end)

    --播放自己获得助力礼包
    self.asyncRunner:add(function (done)
        if self.isDisposed then return end
        self:tryGetCurrentHelpReward(done)
    end)

    --播放其他人成功跳台子
    self.asyncRunner:add(function (done)
        if self.isDisposed then return end
        local panelState = self.mgr.uiUseData.panelState
        local curProcess = self.mgr.uiUseData.curProcess
        local destIndex = curProcess
        local con1 = false
        if panelState == _G.MeMeFoxConst.STATUS.TIMEOUT_FAIL or
                panelState == _G.MeMeFoxConst.STATUS.PASS_FAIL then
            destIndex = destIndex + 1
            con1 = true
        elseif not table.isEmpty(removeHeadList) then
            con1 = true
        end
        if not table.isEmpty(remainHeadList) and con1 then
            self:callViewFuncWithCallback("tryLetOtherPlayerJumpToNextUnder", done, destIndex)
        else
            safeRunCall(done)
        end
    end)

    --播放跳水动画
    self.asyncRunner:add(function (done)
        if self.isDisposed then return end
        local panelState = self.mgr.uiUseData.panelState
        local curProcess = self.mgr.uiUseData.curProcess
        if panelState == _G.MeMeFoxConst.STATUS.TIMEOUT_FAIL or
                panelState == _G.MeMeFoxConst.STATUS.PASS_FAIL then
            self:callViewFunc("headAnimJumpToWater", {
                destIndex = curProcess,
                headAnim = self.view.myHeadAnim,
                isMe = true,
            })
            self:callViewFuncWithCallback("tryLetOtherPlayerJumpToWater", done, curProcess, 1.5)
        else
            local curProcess = curProcess - 1
            self:callViewFuncWithCallback("tryLetOtherPlayerJumpToWater", done, curProcess, 35/30)
        end
    end)

    --失败面板
    self.asyncRunner:add(function (done)
        self:tryShowFailedPanel(done)
    end)

    --最终大奖
    self.asyncRunner:add(function (done)
        self:tryGetFinalReward(done)
    end)


    self.asyncRunner:add(function (done)
        if self.isDisposed then return end
        self:callViewFunc("removeSkipLayer")
        self:callViewFunc("refreshGoBtn")
        self.canClickContinueClose = true
        safeRunCall(done)
    end)

    self.asyncRunner:run()
end

function MainPanelVM:tryShowFailedPanel(done)
    if self.isDisposed then return end
    local panelState = self.mgr.uiUseData.panelState
    --3 连胜失败 2超时失败
    if panelState ~= _G.MeMeFoxConst.STATUS.TIMEOUT_FAIL and
            panelState ~= _G.MeMeFoxConst.STATUS.PASS_FAIL then
        safeRunCall(done)
        return
    end
    self:callViewFuncWithCallback("tryPopFailedPanel", done)
end

function MainPanelVM:tryGetFinalReward(done)
    if self.isDisposed then return end
    local panelState = self.mgr.uiUseData.panelState
    if panelState == _G.MeMeFoxConst.STATUS.SUCCESS_NOT_REWARD and
            self.finalRewardRealGold then
        if self.gotFinalReward then
            safeRunCall(done)
            return
        end
        self.gotFinalReward = true
        self.mgr.model:setMeMeFoxStatus(_G.MeMeFoxConst.STATUS.END)
        local reward = self.finalRewardRealGold
        self:callViewFuncWithCallback("tryPopFinalReward", function()
            self:onCloseBtnTapped()
            self.mgr:tryRemoveActIcon(nil, true)
        end, reward)
    else
        safeRunCall(done)
    end
end

function MainPanelVM:onGoToLevelBtn()
    local panelState = self.mgr.uiUseData.panelState
    if panelState == _G.MeMeFoxConst.STATUS.SUCCESS_NOT_REWARD then
        return
    end

    local function jumpToLevel()
        local mode = self.mgr.uiUseData.mode
        self:onCloseBtnTapped()
        if mode == _G.MeMeFoxConst.MODE.TOP_LEVEL then
            self.mgr:openPlayLevelPanel()
        elseif mode == _G.MeMeFoxConst.MODE.COLORFUL_STAR then
            self.mgr:openColorFulStarPanel()
        elseif mode == _G.MeMeFoxConst.MODE.FULL_LEVEL_LIB then
            if MeMeFoxUtil:fullStarLevelLibCanPlay() then
                _G.amfBean("FullStarLevelLibManager"):tryOpenStartPanel(true, {
                    panel_source_act = "4042_1",
                })
            else
                self.mgr:openPlayLevelPanel()
            end
        end
    end
    jumpToLevel()
end

function MainPanelVM:onPreBtn()
    if self.isDisposed then return end
    local panelState = self.mgr.uiUseData.panelState
    --正在CD中
    if panelState == _G.MeMeFoxConst.STATUS.FAILED_CD then
        CommonTip:showTip("倒计时结束后即可开始挑战~")
    else
        self.mgr.dc:dcManualClick()
        self:tryPopJoinGroup()
    end
    self.mgr.dc:dcPrepareClick()
end

function MainPanelVM:onBeforeClosePanel()
    local latestStatus = self.mgr.model:getMeMeFoxStatus() --最新的状态
    local panelState = self.mgr.uiUseData.panelState --进入面板时的状态
    local curTime = TimeKit:timeInSec()
    local configEndTime = self.mgr.model:getConfigMainEndTime()

    if panelState == _G.MeMeFoxConst.STATUS.FAILED_CD and
            configEndTime ~= nil and not self._clickCloseBtn then
        local tipText = "你的活动数据已更新，请重新进入活动~"
        if curTime >= configEndTime then
            tipText = "未完成挑战，活动已结束~"
        end
        MeMeFoxViewHelper:delayTimeTip(0.5, tipText)
    end

    if (latestStatus == _G.MeMeFoxConst.STATUS.NOT_START or
            latestStatus == _G.MeMeFoxConst.STATUS.END)
            and configEndTime ~= nil and
            not self._clickCloseBtn then
        local tipText = ""
        if curTime >= configEndTime then
            tipText = "活动已结束~"
        elseif latestStatus == _G.MeMeFoxConst.STATUS.NOT_START then
            tipText ="你的活动数据已更新，请重新进入活动~"
        end
        MeMeFoxViewHelper:delayTimeTip(0.5, tipText)
    end

    if panelState == _G.MeMeFoxConst.STATUS.TIMEOUT_FAIL or
            panelState == _G.MeMeFoxConst.STATUS.PASS_FAIL then
        if configEndTime ~= nil then
            if curTime >= configEndTime then
                MeMeFoxViewHelper:delayTimeTip(0.5, "未完成挑战，活动已结束~")
                self.mgr.model:setMeMeFoxStatus(_G.MeMeFoxConst.STATUS.NOT_START)
            else
                local tipText = "本次挑战失败~"
                if panelState == _G.MeMeFoxConst.STATUS.TIMEOUT_FAIL then
                    tipText = "未在限定时间内完成，本次挑战失败~"
                end
                MeMeFoxViewHelper:delayTimeTip(0.5, tipText)
            end
        end
        self:sendFailedStateChange()
    end

    if latestStatus ~= _G.MeMeFoxConst.STATUS.NOT_START then
        --TODO 这里把所有的奖字都取消
    end

    if panelState == _G.MeMeFoxConst.STATUS.RUNNING then
        self.mgr.model:cleanRobotInfoEliminateList()
    end
end

function MainPanelVM:sendFailedStateChange()
    local roundEndTime = self.mgr.model:getActMainEndTime()
    local function refreshFunc()
        local curTime = TimeKit:time()
        local triggerTime = self.mgr.model:getTriggerTime()
        local lastDayEndTime = self.mgr.model:getConfigMainEndTime()

        local curDay =  TimeKit:getDayStartTimeByTS(curTime/1000)
        local triggerDay =  TimeKit:getDayStartTimeByTS(triggerTime)
        local lastDay =  TimeKit:getDayStartTimeByTS(lastDayEndTime)

        if curDay < lastDay and triggerDay < curDay then
            self.mgr.model:setMeMeFoxStatus(_G.MeMeFoxConst.STATUS.NOT_START)
        else
            self.mgr.model:setActMainEndTime(roundEndTime*1000)
            self.mgr.model:setFailCdTime(tostring(curTime + 30*60*1000))
            self.mgr.model:setMeMeFoxStatus(_G.MeMeFoxConst.STATUS.FAILED_CD)
        end
    end

    local mode = self.mgr.model:getMeMeFoxMode()
    if mode ~= _G.MeMeFoxConst.MODE.UNKNOWN then
        local Request = require "amf.feature.winningstreak.module.memefox.http.StreakGoalInfo"
        Request:post({
            clientState = mode,
            light = false,
            versionControl = 1,
            { clientMd5 = nil }
        }, nil, true):next(function(response)
            local data = response:getData()
            self.mgr.model:cleanRobotInfoEliminateList()
            self.mgr.model:updateServerData(data)
            refreshFunc()
            self.mgr:tryRemoveActIcon()
        end, function()
            refreshFunc()
            self.mgr:tryRemoveActIcon()
        end)
    end
end

function MainPanelVM:immediateSkipAnim()
    if self.isDisposed then return end
    local panelState = self.mgr.uiUseData.panelState
    local isJoinGroup = self.mgr.uiUseData.isJoinGroup
    local removeHeadList = self.view:getJumpToWaterHeadList()
    if self.asyncRunner then
        self.asyncRunner:clean()
    end
    self:callViewFunc("immediateFinishUnderAnim")
    self:callViewFunc("immediateFinishHeadAnim")
    self:callViewFunc("refreshGoBtn")
    if isJoinGroup then
        self:callViewFunc("scrollToBottom")
    end
    local asyncRunner = AsyncRunner:create()
    asyncRunner:add(function (done)
        if self.isDisposed then return end
        self:tryGetMissHelpReward(done)
    end)

    asyncRunner:add(function (done)
        if self.isDisposed then return end
        self:tryGetCurrentHelpReward(done)
    end)

    --失败面板
    asyncRunner:add(function (done)
        if self.isDisposed then return end
        self:tryShowFailedPanel(done)
    end)

    --最终大奖
    asyncRunner:add(function (done)
        if self.isDisposed then return end
        self:tryGetFinalReward(done)
    end)

    --1秒自动关闭
    asyncRunner:add(function (done)
        if self.isDisposed then return end
        if panelState == _G.MeMeFoxConst.STATUS.RUNNING or
                panelState == _G.MeMeFoxConst.STATUS.TIMEOUT_FAIL or
                panelState == _G.MeMeFoxConst.STATUS.PASS_FAIL then
            MeMeFoxViewHelper:delayTimeCall(self.view.ui, 1, function()
                if self.view.inLevelShowLabel:isVisible() then
                    self:onCloseBtnTapped()
                end
            end)
        end
        safeRunCall(done)
    end)

    asyncRunner:add(function (done)
        if self.isDisposed then return end
        self.canClickContinueClose = true
        safeRunCall(done)
    end)

    asyncRunner:run()
end

function MainPanelVM:tryContinueClosePanel()
    if self.isDisposed then return end
    if self.view.inLevelShowLabel:isVisible() then
        if not self.canClickContinueClose then
            return
        end
        self:onCloseBtnTapped()
    end
end

function MainPanelVM:setMeMeFoxCurProgress(progress)
    self.mgr.model:setMeMeFoxCurProgress(progress)
end

function MainPanelVM:setMeMeFoxStatus(status)
    self.mgr.model:setMeMeFoxStatus(status)
end

return MainPanelVM
