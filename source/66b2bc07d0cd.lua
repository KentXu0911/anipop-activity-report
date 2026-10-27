local AutoPopupDebugLog = require "amf.middleware.autopop.AutoPopupDebugLog"
local Stage2EnterSceneHandler = class("Stage2EnterSceneHandler")
local FeedContext = require("amf.middleware.feed.FeedContext")
local FeedRevisitConfig = require "amf.feature.minihub.recommendationfeed.FeedRevisitConfig"
local FeedRevisitRewardService = require "amf.feature.minihub.recommendationfeed.FeedRevisitRewardService"

-- 复访离线收益场景小浣熊提示相对屏幕中线的纵向偏移，需要与美术对齐时只改这里
local FEED_REVISIT_OFFLINE_GUIDE_POS_Y = 100

function Stage2EnterSceneHandler:create(data, autoPopupMgr)
    local handler = Stage2EnterSceneHandler.new()
    handler:init(data, autoPopupMgr)
    return handler
end

function Stage2EnterSceneHandler:init(data, autoPopupMgr)
    self._isFirstEnterMainScene = data.firstEnter
    self._autoPopupMgr = autoPopupMgr
end

function Stage2EnterSceneHandler:handleAutoPopup()
	AutoPopupDebugLog:beginPopupScene(AutoPopupConst.PopStage.STAGE_TWO, self._autoPopupMgr)
    if self:checkWXFeedTrialAutoStart() then return end
    if self:checkFeedAutoStart() then return end

	-- SYSTEM
	--self:tryPopPrivacyPolicy()
	self:checkSLAlert()
	self:checkPkgUpdate()
	self:checkAnnouncement()
	self:checkUserProtocal()
	-- OUTSIDE
	if self._isFirstEnterMainScene then
		-- 首次启动时的，外部的url和copy处理
		local Stage2ForegroundHandler = require "amf.middleware.autopop.module.popstage.Stage2ForegroundHandler"
		local handler = Stage2ForegroundHandler:create({ isFirstEnter = true }, self._autoPopupMgr)
		handler:handleAutoPopup()

        -- 又不连闯无关了
        -- 连闯五关的情况下，不给闪退回复
        local canRecall = self:checkRecall2025()

        if not self:checkAutoStartLevel(canRecall) then
            self:checkCrashResume()
        end

        self:checkScrollToCurrentLevel()

        -- SH01加场景2强弹
        self:checkSh01ActivityPop()
    end
    self:checkDyOpenStartPanel()
end

function Stage2EnterSceneHandler:checkWXFeedTrialAutoStart()
    local UBFWXFeedTrialAutoStartLogic = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.WXFeedTrialAutoStart.UBFWXFeedTrialAutoStartLogic"
    if not UBFWXFeedTrialAutoStartLogic then return false end

    local logic = UBFWXFeedTrialAutoStartLogic:shareLogic()
    if not logic or not logic:isEnabled() then return false end

    if logic:consumeNeedContinueOnMainScene() then
        local firstEnter = logic:consumeContinueFirstEnter()
        setTimeOut(function()
            if not self._autoPopupMgr:isInMainScene() then return end
            local handler = Stage2EnterSceneHandler:create({
                firstEnter = firstEnter,
            }, self._autoPopupMgr)
            handler:handleAutoPopup()
            self._autoPopupMgr:triggerStage2AutoPopup(false)
        end, 0)
        return true
    end

    local autoPopParams = logic:checkAutoPopForTrial({
        firstEnter = self._isFirstEnterMainScene,
    })
    if autoPopParams then
        AutoPopEventCenter:dispatch(AutoPopEvent.CRASH_RESUME, autoPopParams)
        return true
    end

    return logic:shouldBlockAutoPopup()
end

function Stage2EnterSceneHandler:checkSLAlert()
    if not _G.amfBean("HttpErrorManager"):isServerGlobalErrValid(111) then return end
    AutoPopEventCenter:dispatch(AutoPopEvent.POLICY, {
        popupCheckPoint = PopupCheckPoint.SL_ALERT
    })
end

function Stage2EnterSceneHandler:checkPkgUpdate()
	--
--

	if EnvUtil:isIOS() and _G.needOverlayPanel then return end
	local updateMgr = _G.amfBean("VersionUpdateManager")
	if not updateMgr then return end
	if not updateMgr:canPackageUpdate() then return end
	--
	--  非ios用户，针对新安装用户
	-- 游戏最新版本-游戏当前版本<=1，在游戏内不会弹出游戏自身的安装新版本页面
	--
	local function checkCanPopUpdatePanel()
		if updateMgr:isNewInstallOrReInstall() then
			local versionAry = _G.bundleVersion:split(".")
			local packageVersion = tonumber(versionAry[2]) or 0

			local version = updateMgr:getUpdateVersion()
			local versionAry2 = version:split(".")
			local newVersion = tonumber(versionAry2[2]) or 0

			if newVersion > packageVersion and newVersion - packageVersion <= 1 then
				return false
			end
		end
		return true
	end

	if not checkCanPopUpdatePanel() then return end

	if updateMgr:isPackageReady() or not updateMgr:isDownloading() then
		AutoPopEventCenter:dispatch(AutoPopEvent.SYSTEM, {
			popupCheckPoint = PopupCheckPoint.PKG_UPDATE,
		})
	end
end

-- 5级以下玩家首次启动直接进入关卡
function Stage2EnterSceneHandler:checkAutoStartLevelUnder5()
    local UserEnergyManager = _G.amfBean("UserEnergyManager")
    local isInfiniteEnergy = UserEnergyManager:getEnergyState() == UserEnergyState.INFINITE
    local isEnergyEnough = UserEnergyManager:getEnergy() >= 5
    if not isEnergyEnough then return end
    local topLevelId = _G.getTopLevelId()
    if topLevelId < 1 or topLevelId > 5 then return false end

    -- Feed自动进关目前是前5关自动进关的一个子逻辑分支
    if self:checkFeedAutoStart() then return true end

    if _G.noviceContinueFiveAttackEnable == nil then
        --app全开，小游戏读开关
        local on = EnvUtil:isApp() or MaintenanceManager:getInstance():isEnabledInGroup('keepinlevel', 'ON')
        _G.noviceContinueFiveAttackEnable = on and true or false
    end

    if not _G.noviceContinueFiveAttackEnable then return false end


    local costType = StartLevelCostType.kEnergy
    if isInfiniteEnergy then costType = StartLevelCostType.kInfiniteEnergy end

    if topLevelId == 1 and self._isFirstEnterMainScene and FeedContext.isVideoGuideLevelFlow() and FeedContext.isNewUser() then
        local mgr = _G.amfBean("RecommendationFeedManager")
        if mgr and mgr.prepareFeedPreplayVideo then
            mgr:prepareFeedPreplayVideo()
        end
        if mgr and mgr.showFeedPreplayVideo then
            mgr:showFeedPreplayVideo()
        end
    end

    AutoPopEventCenter:dispatch(AutoPopEvent.CRASH_RESUME, {
        popupCheckPoint = PopupCheckPoint.AUTO_START_LEVEL,
        params = {
            levelId = topLevelId,
            costType = costType,
            needAlert = false,
            source = AutoPopupConst.StartLevelSource.LOW_LEVEL
        }
    })
    return true
end

-- TODO: APP 100级以下玩家首次启动直接进入关卡 -先占位 待后续优化 @shihao.zhang
function Stage2EnterSceneHandler:checkAutoStartLevelUnder100()
    -- 回流100级以下不自动进关
    if _G.amfBean("AMFRecallManager"):checkReturnBackState(_G.RecallId.COMMON_SEVEN_DAY) then return end
    -- do return end
    local UserEnergyManager = _G.amfBean("UserEnergyManager")
    local isInfiniteEnergy = UserEnergyManager:getEnergyState() == UserEnergyState.INFINITE
    local isEnergyEnough = UserEnergyManager:getEnergy() >= 5
    if not isInfiniteEnergy and not isEnergyEnough then return end
    local topLevelId = _G.getTopLevelId()
    if topLevelId < 1 or topLevelId > 100 then return false end

    --新增测试，非回流100级以下不自动进关
    if MaintenanceManager:getInstance():isEnabledInGroup("2026AutoInLevelTest", "ON5") then return end

    local costType = StartLevelCostType.kEnergy
    if isInfiniteEnergy then costType = StartLevelCostType.kInfiniteEnergy end

    AutoPopEventCenter:dispatch(AutoPopEvent.CRASH_RESUME, {
        popupCheckPoint = PopupCheckPoint.AUTO_START_LEVEL,
        params = {
            levelId = topLevelId,
            costType = costType,
            needAlert = false,
            source = AutoPopupConst.StartLevelSource.LOW_LEVEL
        }
    })
    return true
end

-- 回流2025
function Stage2EnterSceneHandler:checkRecall2025(canAutoEnter)
    local Manager = _G.amfBean("Recall2025Manager")

    if not Manager then return false end

    if not Manager:isEnabled() then return end

    if Manager:getModel():checkTodayRightsGot() then return end

    AutoPopEventCenter:dispatch(AutoPopEvent.RECALL, {
        popupCheckPoint = PopupCheckPoint.RECALL_2025_STAGE2,
        canEnter = canAutoEnter,
    })

    return true
end

function Stage2EnterSceneHandler:checkAutoStartLevel(canRecall)
    if canRecall then return end
    -- if _G.isYunGame then return end
    if FeedContext.shouldSkipAutoStartLevel() then return false end
    if self:checkAutoStartLevelUnder5() or self:checkAutoStartLevelUnder100() then return true end

    if self:checkBackUserAutoStart() then return true end

    return false
end

function Stage2EnterSceneHandler:checkBackUserAutoStart()
    -- local UBFBackUserAutoStartLogic = require "ubf.UBFGamePlayScene.logics.mess.UBFBackUserAutoStartLogic"
    -- local logic = UBFBackUserAutoStartLogic:shareLogic()

    -- if logic:canAutoPlay() then
    --     local costType = logic:getEnergyType()
    --     if costType then
    --         local topLevelId = _G.getTopLevelId()
    --         AutoPopEventCenter:dispatch(AutoPopEvent.CRASH_RESUME, {
    --             popupCheckPoint = PopupCheckPoint.AUTO_START_LEVEL_BACK_USER,
    --             params = {
    --                 levelId = topLevelId,
    --                 costType = costType,
    --                 needAlert = false,
    --                 source = AutoPopupConst.StartLevelSource.BACK_USER,
    --                 logic = logic
    --             }
    --         })
    --         return true
    --     end
    -- end
    -- return false

    local Manager = _G.amfBean("RecallAutoStartLevelManager")

    if Manager:canAutoEnterLevel() then
        local costType = Manager:getEnergyType()
        if costType then
            local topLevelId = _G.getTopLevelId()
            AutoPopEventCenter:dispatch(AutoPopEvent.CRASH_RESUME, {
                popupCheckPoint = PopupCheckPoint.AUTO_START_LEVEL_BACK_USER,
                params = {
                    levelId = topLevelId,
                    costType = costType,
                    needAlert = false,
                    source = AutoPopupConst.StartLevelSource.BACK_USER,
                }
            })
            return true
        end
    end

    if Manager:isInReturnNoautoON2() and Manager:isBaseEnabled() and Manager:isRule2Enabled() then
        local topLevelId = _G.getTopLevelId()
        AutoPopEventCenter:dispatch(AutoPopEvent.CRASH_RESUME, {
            popupCheckPoint = PopupCheckPoint.RECALL_OPEN_START_PANEL,
            params = {
                levelId = topLevelId,
            }
        })
    end

    return false
end

-- 抖音（或后续其他？）Feed直出获客自动进关
function Stage2EnterSceneHandler:checkFeedAutoStart()
    local UBFFeedAutoStartLogic = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.FeedAutoStart.UBFFeedAutoStartLogic"
    if not UBFFeedAutoStartLogic then return false end
    if not FeedContext.isTrialLevelFlow() and not FeedContext.isVideoTrialLevelFlow() then return false end

    local logic = UBFFeedAutoStartLogic:shareLogic()
    if not logic then return false end

    local inParams = {
        topLevelId = _G.getTopLevelId(),
        firstEnter = self._isFirstEnterMainScene,
    }
    local autoPopParams = logic:checkAutoPopForAutoPlay(inParams)
    if autoPopParams then
        -- UBFLogD(25, "autoPopParams", autoPopParams)
        AutoPopEventCenter:dispatch(AutoPopEvent.CRASH_RESUME, autoPopParams)
        return true
    end
    return false
end

function Stage2EnterSceneHandler:checkCrashResume()

    if _G._YUN_TEST_AUTO_FIGHT_MODE_ then
        setTimeOut(function()
            _G._YUN_TEST_DEBUG_MODE_ = true
            require "ubf.UBFGamePlayScene.views.debugs.MiniGameDebug"
            _G.mini_debug_super_auto_fight()
        end, 2)
        return true
    end


	local bCanRunCrashResumePop = false
	local bGetSucess, otherDevicePlayingContextInfo = _G.amfBean("UserLevelContextManager"):getOtherDevicePlayingContextInfo()

	if bGetSucess then
		bCanRunCrashResumePop = true
	end
	local UBFGameResumeLogic = require "ubf.UBFGamePlayScene.logics.mess.UBFGameResumeLogic"
	local logic = UBFGameResumeLogic:create()
	if logic:hasResumeData() then
		bCanRunCrashResumePop = true
	end

	if bCanRunCrashResumePop then
		AutoPopEventCenter:dispatch(AutoPopEvent.CRASH_RESUME, {popupCheckPoint = PopupCheckPoint.CRASH_RESUME_MAIN, params ={
			bGetOtherContextSucess = bGetSucess,
			otherDevicePlayingContextInfo = otherDevicePlayingContextInfo,
			logic = logic
		}})
	end
	return bCanRunCrashResumePop
end

-- 场景就绪上报：优先走 RecommendationFeedManager（等待面板展示的场景由它统一管理）
function Stage2EnterSceneHandler:reportFeedRevisitScene()
    local manager = _G.amfBean("RecommendationFeedManager")
    if manager and manager.reportScene then
        manager:reportScene()
    else
        FeedContext.reportScene()
    end
end

function Stage2EnterSceneHandler:checkDyOpenStartPanel()
    if self:checkDyOfflineRewardPanel() then return end
    if not FeedContext.consumeOpenStartPanel() then return end

    local function reportScene()
        self:reportFeedRevisitScene()
    end

    local function openStartPanel()
        _G.amfTransaction(TransactionEvent.PLAY_LEVEL, PlayLevelContext.new(nil, PlayLevelContext.PlayType.OPEN_SL_PANEL):setExtraData({
            douyinFeedReturn = true,
        }))
    end

    local feedScene = FeedContext.getSceneStr()
    local contentId = FeedContext.getTrialSourceIdFromJS()

    if feedScene == FeedContext.SceneType.IMPORTANT_EVENT_DROP
        and FeedRevisitConfig.isImportantEventSignIn(contentId) then
        local function creator()
            local popupOver = false
            local function finishPopup()
                if popupOver then return end
                popupOver = true
                FeedContext.clearRevisitContext()
                self._autoPopupMgr:resetPopup()
                openStartPanel()
                reportScene()
            end

            local markManager = _G.amfBean("MarkManager")
            if not markManager or not markManager:isEnabled() then
                finishPopup()
                return
            end

            markManager:showMainPanel({
                closeCallback = finishPopup,
                dcLocation = 1,
                isClick = false,
                forceRequest = true,
                skipIfTodayMarked = true,
                autoCloseAfterSignIn = true,
                signInRequest = FeedRevisitRewardService.requestImportantEventSignIn,
                panelShownCallback = reportScene,
            })
        end
        self._autoPopupMgr:addPopupConfig(PopupCheckPoint.DY_MINI_OPEN_START_PANEL, creator)
        return
    end

    local energyRewardConfig = feedScene == FeedContext.SceneType.ENERGY_RECOVER
        and FeedRevisitConfig.getEnergyRewardConfig(contentId) or nil
    local feedGameExtra = FeedContext.getFeedGameExtra()
    local rewardKey = FeedRevisitConfig.getEnergyRewardKey(contentId, feedGameExtra)
    --
--
--
--
--
--
--
--
--

    if energyRewardConfig and rewardKey then
        local function creator()
            local popupOver = false
            local function finishPopup()
                if popupOver then return end
                popupOver = true
                FeedContext.clearRevisitContext()
                self._autoPopupMgr:resetPopup()
                openStartPanel()
                reportScene()
            end

            local PanelVM = require "amf.feature.minihub.recommendationfeed.FeedRevisitEnergyRewardPanelVM"
            local vm = PanelVM:create({
                contentId = contentId,
                visualPath = energyRewardConfig.visualPath,
                rewardKey = rewardKey,
                claimHandler = FeedRevisitRewardService.requestEnergyReward,
                closeCallback = finishPopup,
                panelShownCallback = reportScene,
            })
            vm:setLoadResFailCallback(finishPopup)
            vm:popout()
        end
        self._autoPopupMgr:addPopupConfig(PopupCheckPoint.DY_MINI_OPEN_START_PANEL, creator)
        return
    end

    local function showFeedTip()
        local curScene = Director:sharedDirector():getRunningScene()
        local safeArea = _G.fullScreenSizeManager:getSafeArea()
        local visibleSize = safeArea.size
        local originPos = safeArea.origin

        local function showTipScene2()
            local baseX = originPos.x + 220
            local baseY = originPos.y + visibleSize.height - 70

            local desc = "亲爱的小村民，精力已恢复，\n快来继续游戏吧！"
            local tip = UITip.Builder.new():setMessage(desc, "B2714AFF", nil, 26):setDirection(UITip.Direction.DOWN)
                :setSkin(UITip.SkinType.FEED):setAutoCloseTime(0):buildSingleTip(true)
            tip:moveArrow(-116, 0)
            curScene:addChild(tip, SceneLayerShowKey.TOP_LAYER)
            tip:setPositionXY(baseX, baseY)
        end

        if feedScene == FeedContext.SceneType.ENERGY_RECOVER then
            showTipScene2()
        end
    end

    local function creator()
        self._autoPopupMgr:resetPopup()
        openStartPanel()
        --UBFProcessManager:launch(UBFGameProcessEnum.NORMAL_START, {
        --	levelId = _G.getTopLevelId(),
        --	levelScene = UBFLevelSceneType.kMain,
        --})
        local userStateManager = _G.amfBean("UserStateManager")
        if userStateManager:isFMJ() or userStateManager:isColorfulStarFull() then
            showFeedTip()
        end
    end
    self._autoPopupMgr:addPopupConfig(PopupCheckPoint.DY_MINI_OPEN_START_PANEL, creator)
end

-- 复访版离线收益场景：直玩进入后不进入战斗/大厅，直接展示金银果树面板，
-- 并在面板上叠加通用引导（小浣熊提示），引导玩家摘取成熟果实。
function Stage2EnterSceneHandler:checkDyOfflineRewardPanel()
    if not FeedContext.consumeOpenOfflineRewardPanel() then return false end

    local contentId = FeedContext.getTrialSourceIdFromJS()
    --
--
--
--
--
--


    if not FeedRevisitConfig.isOfflineReward(contentId) then
        -- 未命中本次投放方案，交回默认复访流程
        return false
    end

    local fruitTreeManager = _G.amfBean("FruitTreeManager")
    if not fruitTreeManager or not fruitTreeManager:isEnabled() then
        -- 果树未开放（未过 FruitTreeConst.OPAN_PASSLEVEL）等异常数据：不展示果树面板，
        -- 补一次兜底上报（保持本轮场景上报不丢），再交回默认复访流程
        self:reportFeedRevisitScene()
        return false
    end

    local guide

    local function hideGuide()
        local guideNode = guide
        guide = nil
        if guideNode and not guideNode.isDisposed then
            guideNode:removeGuide()
        end
    end

    local function showGuide()
        hideGuide()
        local HeGuide = require "amf.middleware.ui.kit.component.HeGuide"
        guide = HeGuide:create(nil, true, nil, nil, true)
        guide:setEndCall(function()
            hideGuide()
        end)
        guide:showNpc2({
            { ttf = FeedRevisitConfig.OfflineRewardTipText },
        }, FEED_REVISIT_OFFLINE_GUIDE_POS_Y)
        guide:setMaskOpacity(0)
    end

    local function creator()
        local popupOver = false
        local function finishPopup()
            if popupOver then return end
            popupOver = true
            hideGuide()
            FeedContext.clearRevisitContext()
            self._autoPopupMgr:resetPopup()
            -- 关闭果树面板后的去向：当前保持主场景，不额外拉起开始面板（待产品确认）
        end

        fruitTreeManager:openFruitTreePanel({
            t1 = "feed_revisit_offline",
            onOpened = function()
                showGuide()
                self:reportFeedRevisitScene()
            end,
            onClosed = finishPopup,
            onLoadFailed = finishPopup,
        })
    end
    self._autoPopupMgr:addPopupConfig(PopupCheckPoint.DY_MINI_OPEN_START_PANEL, creator)
    return true
end

function Stage2EnterSceneHandler:checkAnnouncement()
    local userTopLevel = _G.amfBean("UserManager"):getTopLevelId()
    if userTopLevel <= 1 then return end
    if not _G.amfBean("AnnouncementMgr"):isSatisfyCD(AnnouncementPosType.MAIN) then return end
    AutoPopEventCenter:dispatch(AutoPopEvent.SYSTEM, {
        popupCheckPoint = PopupCheckPoint.ANNOUNCEMENT
    })
end

function Stage2EnterSceneHandler:checkUserProtocal()
    -- 原华为快游戏用户协议弹窗
    -- AutoPopEventCenter:dispatch(AutoPopEvent.SYSTEM, {popupCheckPoint = PopupCheckPoint.USER_PROTOCAL})
end

function Stage2EnterSceneHandler:checkScrollToCurrentLevel()
    if not EnvUtil:isMiniGame() then return end
    AutoPopEventCenter:dispatch(AutoPopEvent.FUNCTION, {
        popupCheckPoint = PopupCheckPoint.SCROLL_TO_CURRENT_LEVEL
    })
end

-- 尝试弹出小游戏隐私政策
function Stage2EnterSceneHandler:tryPopPrivacyPolicy()

    -- if EnvUtil:isHuaweiMiniGame() then
    -- 	if self._processingPrivacyAuthorize then return end
    -- 	if _G.getTopLevelId() < 1500 then return end
    -- 	self._processingPrivacyAuthorize = true
    -- 	--小游戏本身有缓存，所以这里无脑弹出即可
    -- 	local huawei_mini_support = require 'amf.middleware.huawei_mini_support'
    -- 	huawei_mini_support.RequirePrivacyAuthorize({
    -- 		success = function() end,
    -- 		fail = function() end,
    -- 		complete = function() self._processingPrivacyAuthorize = false end
    -- 	})
    -- 	return ;
    -- end

    if not EnvUtil:isWXMiniGame() then return end
    if self._processingPrivacyAuthorize then return end
    if _G.getTopLevelId() < 1500 then return end
    self._processingPrivacyAuthorize = true
    -- 小游戏本身有缓存，所以这里无脑弹出即可
    WeChatAPI.RequirePrivacyAuthorize({
        success = function() end,
        fail = function() end,
        complete = function() self._processingPrivacyAuthorize = false end
    })
end

function Stage2EnterSceneHandler:checkSh01ActivityPop()
	if not _G.amfBean("SH01Manager") then
		return
	end

    _G.amfBean("SH01Manager"):checkSh01ActivityPop()
end

return Stage2EnterSceneHandler
