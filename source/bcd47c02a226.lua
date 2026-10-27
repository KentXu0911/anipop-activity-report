local deferred = require "amf.script.sugar.deferred"
local MiniGameEventCenter = require "amf.feature.minihub.event.MiniGameEventCenter"
local FeedContext = require("amf.middleware.feed.FeedContext")
local FeedRevisitConfig = require "amf.feature.minihub.recommendationfeed.FeedRevisitConfig"
local FeedSubscribeGuideRewardRequest = require "amf.feature.minihub.recommendationfeed.http.TiktokFeedSubscribeGuideReward"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local PackageIconV2Host = require "amf.feature.mainscene.module.icon.v2.runtime.PackageIconV2Host"

local RecommendationFeedManager = class("RecommendationFeedManager")
RecommendationFeedManager.FEED_SUBSCRIBE_GUIDE_ACT_ID = 9506
-- IconKey/NGIconConfig 暂未提供，先保持业务 key 独立，后续配置接入时只替换此常量。
RecommendationFeedManager.FEED_SUBSCRIBE_GUIDE_ICON_KEY = "dy_feed_subscribe_guide"
RecommendationFeedManager.FEED_SUBSCRIBE_GUIDE_LEGACY_ICON_PATH = "amf/dyminigame/recommendationfeed/dysubscribeIcon.png"
RecommendationFeedManager.FEED_SUBSCRIBE_GUIDE_ICON_V2_PATH = "amf/dyminigame/recommendationfeed/dysubscribeIconV2.png"
RecommendationFeedManager.FEED_SUBSCRIBE_DEFAULT_TYPE = "play"
local FEED_SUBSCRIBE_STATUS_UNKNOWN = nil

local function isFeedSubscribeRuntimeAvailable()
    return EnvUtil:isDYMiniGame() and not EnvUtil:isMiniGameOhos()
end

local function normalizeBoolean(value)
    if value == true or value == "true" then
        return true
    end
    if value == false or value == "false" then
        return false
    end
    return nil
end

local function deserializeJsResult(result)
    if type(result) == "table" then
        return result
    end
    if type(result) ~= "string" or result == "" then
        return nil
    end
    local parsed = table.deserialize(result)
    return type(parsed) == "table" and parsed or nil
end

local function serializeJsParams(params)
    if type(params) == "string" then
        return params
    end
    if type(params) ~= "table" then
        return nil
    end
    return table.serialize(params)
end

local function isDouyinCoinPayment(data)
    if type(data) ~= "table" or not data.goodsId then
        return false
    end
    local payType = data.payType
    if payType == PurchaseConst.MiniGamePayType.DY_ANDROID then
        return true
    end
    if payType ~= PurchaseConst.MiniGamePayType.DY_IOS then
        return false
    end

    -- iOS 客服会话支付使用 CNY；其余抖音小游戏 iOS 支付使用 DIAMOND。
    local DyIOSIMPayMaintenance = require "amf.middleware.purchase.payment.system.mini.thirdpayway.douyin.DyIOSIMPayMaintenance"
    return not DyIOSIMPayMaintenance:canUseIMPay({ goodsId = data.goodsId })
end

local FEED_PREPLAY_VIDEO_WIDTH = 720
local FEED_PREPLAY_VIDEO_HEIGHT = 1280
local FEED_AUTO_START_LABEL = "feed_auto_start"
local FEED_TOP_LAYER_SPINE_PATH = "ubfRes-mini/ui/mod/FeedAutoStart/yunzhuanchang.skel"
local FEED_TOP_LAYER_SPINE_ANIM = "2"
local FEED_TOP_LAYER_SPINE_DESIGN_HEIGHT = 1280
local FEED_TOP_LAYER_SPINE_CENTER_OFFSET = ccp(-16.325, -660)
local FEED_TOP_LAYER_SPINE_CREATE_DELAY = 1
local FEED_TOP_LAYER_SPINE_PLAY_DELAY = 0.5

local function getDefaultFeedPreplayVideoRect()
    local frameSize = CCDirector:sharedDirector():getOpenGLView():getFrameSize()
    local viewportWidth = frameSize.width
    local viewportHeight = frameSize.height
    local scale = viewportHeight / FEED_PREPLAY_VIDEO_HEIGHT
    local videoWidth = FEED_PREPLAY_VIDEO_WIDTH * scale
    return {
        x = math.floor((viewportWidth - videoWidth) / 2),
        y = 0,
        width = math.ceil(videoWidth),
        height = viewportHeight,
    }
end

local function getFeedTopLayerSpineScale(visibleSize)
    if not visibleSize or not visibleSize.height or visibleSize.height <= 0 then
        return 1
    end

    return visibleSize.height / FEED_TOP_LAYER_SPINE_DESIGN_HEIGHT
end

local function parseFeedPreplayVideoRect(input, defaultRect)
    local nums = {}
    for num in string.gmatch(tostring(input or ""), "[-]?%d+%.?%d*") do
        table.insert(nums, tonumber(num))
    end

    return {
        x = nums[1] or defaultRect.x,
        y = nums[2] or defaultRect.y,
        width = nums[3] or defaultRect.width,
        height = nums[4] or defaultRect.height,
    }
end

local function getFeedTopLayerParent(scene)
    if not scene then
        return nil
    end

    return scene.topLayer or scene.topEffectLayer or scene.popoutLayer or scene
end

function RecommendationFeedManager:ctor()
    self._feedSubscribeStatus = FEED_SUBSCRIBE_STATUS_UNKNOWN
    self._feedSubscribeCanReward = nil
    self._feedSubscribeIconSystemReady = false
    self._feedSubscribeActInfoReady = false
    self._feedSubscribeStatusQueryPending = false
    self._feedSubscribePopupRegistered = false
    self.iconHost = PackageIconV2Host:create({
        owner = self,
        ownerIconKey = self.FEED_SUBSCRIBE_GUIDE_ICON_KEY,
        iconEventCenter = IconEventCenter,
        isEligible = function()
            return self:isFeedSubscribeGuideEligible()
        end,
        isV2Enabled = function()
            return self:isV2IconExperimentEnabled()
        end,
        prepareLegacyAssets = function()
            return _G.amfBean("AssetsUtil"):loadMiniFiles({self.FEED_SUBSCRIBE_GUIDE_LEGACY_ICON_PATH})
        end,
        prepareV2Assets = function()
            return _G.amfBean("AssetsUtil"):loadMiniFiles({self.FEED_SUBSCRIBE_GUIDE_ICON_V2_PATH})
        end,
        createV2Options = function()
            local IconV2Config = require "amf.feature.minihub.recommendationfeed.icon.IconV2Config"
            return IconV2Config.create(self, IconEventCenter)
        end,
        createLegacyIcon = function()
            return self:createLegacyIcon()
        end,
        refreshLegacy = function(icon)
            if icon then
                icon:updateIcon()
            end
            return true
        end,
        logError = function(stage, detail)
            if EnvUtil:isDevelopMode() then
                UWarning("[RecommendationFeed] icon host", stage, detail)
            end
        end,
    })
end

local function parseActInfoExtra(extra)
    if type(extra) == "table" then return extra end
    if type(extra) ~= "string" or extra == "" then return nil end
    local parsed = table.deserialize(extra)
    return type(parsed) == "table" and parsed or nil
end

function RecommendationFeedManager:isV2IconExperimentEnabled()
    local experiment = require "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"
    return experiment:isEnabled() == true
end

function RecommendationFeedManager:getFeedSubscribeActInfo()
    local activityMgr = _G.amfBean("ActivityMgr")
    if not activityMgr then return nil end
    return activityMgr:getActInfo(self.FEED_SUBSCRIBE_GUIDE_ACT_ID)
end

function RecommendationFeedManager:getFeedSubscribeActInfoExtra(actInfo)
    return parseActInfoExtra(actInfo and actInfo.extra)
end

function RecommendationFeedManager:getFeedSubscribeCanReward()
    if self._feedSubscribeCanReward ~= nil then
        return self._feedSubscribeCanReward
    end
    local extra = self:getFeedSubscribeActInfoExtra(self:getFeedSubscribeActInfo())
    return normalizeBoolean(extra and extra.canReward)
end

function RecommendationFeedManager:setFeedSubscribeCanReward(canReward)
    local normalized = normalizeBoolean(canReward)
    if normalized == nil then return false end
    self._feedSubscribeCanReward = normalized
    self:refreshFeedSubscribeGuideIcon("reward_state_updated", {canReward = normalized})
    return true
end

function RecommendationFeedManager:trackFeedSubscribePanelResult(panelId, success)
    if not isFeedSubscribeRuntimeAvailable() then return false end
    DcUtil:UserTrack({
        category = "dy_repetition_visit",
        sub_category = success and "main_panel_success" or "main_panel_refuse",
        panel_id = panelId,
    })
    return true
end

function RecommendationFeedManager:buildFeedSubscribeDcParam(dcParam)
    local result = {}
    if type(dcParam) == "table" then
        for key, value in pairs(dcParam) do
            result[key] = value
        end
    end

    if result.panel_id == nil then
        result.panel_id = UICreateUtil:getPanelId("DySubscribePanel")
    end
    return result
end

function RecommendationFeedManager:trackFeedSubscribeSubscriptionShow(dcParam)
    if not isFeedSubscribeRuntimeAvailable() or type(dcParam) ~= "table" then return false end
    local data = {}
    for key, value in pairs(dcParam) do
        data[key] = value
    end
    data.category = "dy_repetition_visit"
    data.sub_category = "subscription_show"
    DcUtil:UserTrack(data)
    return true
end

function RecommendationFeedManager:onFeedSubscribeRewardClaimed()
    self._feedSubscribeCanReward = false

    ActivityEventCenter:dispatch(
        ActivityEvent.REMOVE_ACTIVITY,
        { actId = self.FEED_SUBSCRIBE_GUIDE_ACT_ID }
    )

    if self.iconHost then
        self.iconHost:dispose("reward_claimed")
    end
    return true
end

function RecommendationFeedManager:requestFeedSubscribeReward()
    if not isFeedSubscribeRuntimeAvailable() then
        return deferred.error()
    end
    return FeedSubscribeGuideRewardRequest:post():next(function(response)
        local data = response:getData() or {}
        self:onFeedSubscribeRewardClaimed()
        local rewards = data.rewards or {}
        if type(rewards) ~= "table" or table.isEmpty(rewards) then
            return deferred.success(rewards)
        end
        _G.GainPropData:create()
            :setFeature("subscription")
            :setSource("subscribe_reward")
            :setProps(rewards)
            :execute()
        return deferred.success(rewards)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        return deferred.error()
    end)
end

function RecommendationFeedManager:isFeedSubscribeGuideEligible(actInfo)
    if not isFeedSubscribeRuntimeAvailable() then return false end
    actInfo = actInfo or self:getFeedSubscribeActInfo()
    return type(actInfo) == "table"
end

function RecommendationFeedManager:getFeedSubscribeRequestParams()
    return {
        allScene = true,
        type = self.FEED_SUBSCRIBE_DEFAULT_TYPE,
    }
end

function RecommendationFeedManager:createLegacyIcon()
    local FeedSubscribeGuideIcon = require "amf.feature.minihub.recommendationfeed.icon.FeedSubscribeGuideIcon"
    return FeedSubscribeGuideIcon:create()
end

function RecommendationFeedManager:openFeedSubscribeGuidePanel()
    local DySubscribePanelVM = require "amf.feature.minihub.recommendationfeed.view.DySubscribePanelVM"
    local t2 = FeedContext.isNewUser() and 3 or 4
    local vm = DySubscribePanelVM:create({
        manager = self,
        params = self:getFeedSubscribeRequestParams(),
        dcParam = { t1 = 1, t2 = t2 },
    })
    vm:popout()
    return true
end

function RecommendationFeedManager:refreshFeedSubscribeGuideIcon(reason, payload)
    local host = self.feedSubscribeGuideIconHost or self.iconHost
    if not host then
        return false, "FEED_SUBSCRIBE_GUIDE_ICON_HOST_UNAVAILABLE"
    end
    local refreshed, detail = host:refresh(reason or "manager_refresh", payload)
    return refreshed ~= false, detail
end

function RecommendationFeedManager:tryAddFeedSubscribeGuideIcon(reason)
    if not self:isFeedSubscribeGuideEligible() then
        return self.iconHost:dispose(reason or "ineligible")
    end
    local mounted, iconOrError = self.iconHost:reconcile(reason or "icon_ready")
    if mounted == false then
        -- Host 自身负责 V2 -> legacy 回退；失败时保留当前已存在的 Icon。
        return false, iconOrError
    end
    return true, iconOrError
end

function RecommendationFeedManager:tryInitializeFeedSubscribeGuide()
    if not self._feedSubscribeIconSystemReady or not self._feedSubscribeActInfoReady then
        return
    end
    if not isFeedSubscribeRuntimeAvailable() or self._feedSubscribeStatusQueryPending then
        return
    end
    if not self:isFeedSubscribeGuideEligible() then
        self.iconHost:dispose("ineligible")
        return
    end

    self._feedSubscribeStatusQueryPending = true
    self:queryFeedSubscribeStatus(function(status)
        self._feedSubscribeStatusQueryPending = false
        if status == nil then
            self.iconHost:dispose("feed_subscribe_status_query_failed")
            return
        end
        self:tryAddFeedSubscribeGuideIcon("icon_and_act_info_ready")
    end, self:getFeedSubscribeRequestParams())
end

function RecommendationFeedManager:onFeedSubscribeIconSystemReady()
    self._feedSubscribeIconSystemReady = true
    self:tryInitializeFeedSubscribeGuide()
end

function RecommendationFeedManager:onFeedSubscribeActInfoUpdate(event)
    local data = event:getData()
    if not data.fromServer then return end

    self._feedSubscribeActInfoReady = true
    self:tryInitializeFeedSubscribeGuide()
end

function RecommendationFeedManager:setAutoPopupMgr(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
    self:registerFeedSubscribePopup()
end

function RecommendationFeedManager:registerFeedSubscribePopup()
    if self._feedSubscribePopupRegistered then return end
    local autoPopupMgr = self._autoPopupMgr
    if not autoPopupMgr then return end

    require "amf.middleware.autopop.config.AutoPopupConst"
    autoPopupMgr:registerPopup({
        checkPoint = PopupCheckPoint.DY_FEED_SUBSCRIBE_GUIDE,
        stages = {AutoPopupConst.PopStage.STAGE_FOUR},
        check = function()
            return self:isFeedSubscribeGuideEligible()
                and self:getFeedSubscribeRequestParams() ~= nil
                and self:getFeedSubscribeStatus() ~= true
        end,
        creator = function(_, onPopOver)
            return function()
                -- 计数由 AutoPopupMgr 在 creator 调用前统一消耗；强弹直接调用抖音订阅接口。
                local params = self:getFeedSubscribeRequestParams()
                if not params then
                    safeRunCall(onPopOver)
                    return
                end

                local t2 = FeedContext.isNewUser() and 3 or 4
                self:requestFeedSubscribe(params, function()
                    safeRunCall(onPopOver)
                end, { t1 = 2, t2 = t2 })
            end
        end,
    })
    self._feedSubscribePopupRegistered = true
end

function RecommendationFeedManager:onFeedSubscribePaymentSuccess(event)
    if not isFeedSubscribeRuntimeAvailable() then return end
    local data = event:getData()
    if not isDouyinCoinPayment(data) then return end

    local params = self:getFeedSubscribeRequestParams()
    if not params then return end

    local autoPopupMgr = _G.amfBean("AutoPopupMgr")
    local checkPoint = PopupCheckPoint.DY_FEED_SUBSCRIBE_GUIDE
    if autoPopupMgr:checkPointLimitedCheck(checkPoint) then
        return
    end
    -- 支付直弹与场景4强弹共用同一检测点的每日次数标记。
    autoPopupMgr:increaseCheckPointPopNum(checkPoint)
    autoPopupMgr:removePopupConfig(checkPoint)

    self:requestFeedSubscribe(params, nil, { t1 = 2, t2 = 5 })
end

function RecommendationFeedManager:loadFeedAutoStartAssets()
    if self.feedAutoStartAssetsLoaded then
        return deferred.success()
    end

    if not self.feedAutoStartLoadDeferred then
        self.feedAutoStartLoadDeferred = _G.amfBean("AssetsUtil"):loadMiniLabels({FEED_AUTO_START_LABEL}, true):next(function()
            return _G.amfBean("AssetsUtil"):loadMiniFiles({FEED_TOP_LAYER_SPINE_PATH}, true)
        end):next(function()
            self.feedAutoStartAssetsLoaded = true
        end, function(err)
            self.feedAutoStartLoadDeferred = nil
            return deferred.error(err)
        end)
    end

    return self.feedAutoStartLoadDeferred
end

local function syncWXFeedState(maskTouched)
    if not EnvUtil:isWXMiniGame() then return end

    FeedContext.setFeedEnterUser(true)
    if maskTouched then
        FeedContext.setWXMaskTouched(true)
    end
end

local function ensureWXFeedTrialLevelId()
    if not EnvUtil:isWXMiniGame() then return end
    if FeedContext.getTrialLevelId() then return end

    FeedContext.setTrialLevelIdBySourceId(FeedContext.getTrialSourceIdFromJS())
end

local function triggerWXFeedTrialAutoPopup()
    if not EnvUtil:isWXMiniGame() then return end
    if not FeedContext.isFeedEnterUser() then return end
    if FeedContext.hasTrialAutoStarted() then return end
    if FeedContext.hasTrialFinished() then return end
    local UBFWXFeedTrialAutoStartLogic = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.WXFeedTrialAutoStart.UBFWXFeedTrialAutoStartLogic"
    if not UBFWXFeedTrialAutoStartLogic then return end
    local logic = UBFWXFeedTrialAutoStartLogic:shareLogic()
    if not logic or not logic:isEnabled() then return end

    ensureWXFeedTrialLevelId()

    local autoPopupMgr = _G.amfBean("AutoPopupMgr")
    if not autoPopupMgr or not autoPopupMgr:isInMainScene() then return end

    setTimeOut(function()
        if not autoPopupMgr:isInMainScene() then return end
        local Logic = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.WXFeedTrialAutoStart.UBFWXFeedTrialAutoStartLogic"
        local logic = Logic and Logic:shareLogic()
        local autoPopParams = logic and logic:checkAutoPopForTrial({
            firstEnter = true,
        })
        if autoPopParams then
            AutoPopEventCenter:dispatch(AutoPopEvent.CRASH_RESUME, autoPopParams)
        end
        autoPopupMgr:triggerStage2AutoPopup(false)
    end, 0)
end

local function setupFeedNewUserTrial()
    if EnvUtil:isWXMiniGame() then
        FeedContext.applyWXFeedNewUserShow()
        syncWXFeedState(false)
        ensureWXFeedTrialLevelId()
        FeedContext.resetTrialProgress()
        return
    end

    FeedContext.setNewUser(true)
    if EnvUtil:isDYMiniGame() then
        local contentId = FeedContext.getTrialSourceIdFromJS()
        local feedFlowType = FeedContext.resolveFeedFlowType(contentId)
        FeedContext.setFeedFlowType(feedFlowType)
        FeedContext.resetTrialProgress()
        if FeedContext.isTrialLevelFlow() or FeedContext.isVideoTrialLevelFlow() then
            local trialLevelId = FeedContext.resolveTrialLevelId(contentId) or 1
            FeedContext.setTrialLevelId(trialLevelId)
        else
            FeedContext.setTrialLevelId(nil)
        end
        FeedContext.setPendingTrialAutoStart(true)
    end
end

function RecommendationFeedManager:initialize()
    _G.amfEC:registerFeature(self)
    IconEventCenter:register(IconEvent.ICON_SYSTEM_READY, self.onFeedSubscribeIconSystemReady, self)
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onFeedSubscribeActInfoUpdate, self)
    -- ActivityEventCenter:registerGlobal(NormalEvent.PAYMENT_SUCCESS, self.onFeedSubscribePaymentSuccess, self)
    self:registerFeedSubscribePopup()
    self.feedPreplayVideoShown = false
    self.feedPreplayVideoPrepared = false
    self.feedSceneReported = false
    self.feedLevelReady = false
    self.feedVideoReady = false
    if EnvUtil:isDYMiniGame() or EnvUtil:isWXMiniGame() then
        FeedContext.setCanRequestEnterGame(true)
        self:initFeedListeners()
    end
    self:registerFeedPreplayVideoTestButton()
end

function RecommendationFeedManager:resetReportSceneState()
    self.feedSceneReported = false
    self.feedLevelReady = false
    self.feedVideoReady = false
end

function RecommendationFeedManager:getFeedPreplayVideoConfig()
    local rect = getDefaultFeedPreplayVideoRect()
    return {
        videoFlow = FeedContext.resolveVideoFlow(FeedContext.getTrialSourceIdFromJS()),
        x = rect.x,
        y = rect.y,
        width = rect.width,
        height = rect.height,
    }
end

function RecommendationFeedManager:prepareFeedPreplayVideo()
    if self.feedPreplayVideoPrepared or not EnvUtil:isDYMiniGame() then
        return
    end
    if not FeedContext.isVideoFlowSupported() then
        return
    end
    if not FeedContext.isVideoGuideLevelFlow() then
        return
    end

    local videoPlayer = _G.amfBean("VideoPlayer")
    if videoPlayer and videoPlayer:isSupport() and videoPlayer.prepare then
        self.feedPreplayVideoPrepared = true
        videoPlayer:prepare(self:getFeedPreplayVideoConfig(), function()
            self:onFeedVideoReady()
        end)
    else
        self:onFeedVideoReady()
    end
end

function RecommendationFeedManager:showFeedPreplayVideo()
    if self.feedPreplayVideoShown or not EnvUtil:isDYMiniGame() then
        return
    end
    if not FeedContext.isVideoFlowSupported() then
        return
    end
    if not FeedContext.isVideoGuideLevelFlow() then
        return
    end

    local videoPlayer = _G.amfBean("VideoPlayer")
    if videoPlayer and videoPlayer:isSupport() then
        self.feedPreplayVideoShown = true
        self:showFeedTopLayerSpineAsyncDelay(FEED_TOP_LAYER_SPINE_CREATE_DELAY)
        videoPlayer:openAndPlay(self:getFeedPreplayVideoConfig(), nil, function()
            self:playFeedTopLayerSpineDelay(FEED_TOP_LAYER_SPINE_PLAY_DELAY)
        end)
    end
end

function RecommendationFeedManager:removeFeedTopLayerSpine()
    if self.feedTopLayerSpineRoot and not self.feedTopLayerSpineRoot.isDisposed then
        self.feedTopLayerSpineRoot:removeFromParentAndCleanup(true)
    end
    self.feedTopLayerSpineRoot = nil
    self.feedTopLayerSpine = nil
end

function RecommendationFeedManager:showFeedTopLayerSpine()
    self:removeFeedTopLayerSpine()

    local curScene = Director:sharedDirector():getRunningScene()
    local parentLayer = getFeedTopLayerParent(curScene)
    if not parentLayer then
        return nil
    end

    local root = Node:create()
    root:setName("feedTopLayerSpineRoot")
    root:setAnchorPoint(ccp(0.5, 0.5))

    local visibleSize = CCDirector:sharedDirector():getVisibleSize()
    root:setPositionXY(visibleSize.width / 2, visibleSize.height / 2)
    root:setScale(getFeedTopLayerSpineScale(visibleSize))

    local spine = UICreateUtil:createSpine(FEED_TOP_LAYER_SPINE_PATH)
    if not spine then
        return nil
    end

    spine:setPosition(FEED_TOP_LAYER_SPINE_CENTER_OFFSET)
    root:addChild(spine)
    parentLayer:addChild(root)
    self.feedTopLayerSpineRoot = root
    self.feedTopLayerSpine = spine
    return spine
end

function RecommendationFeedManager:showFeedTopLayerSpineAsync()
    return self:loadFeedAutoStartAssets():next(function()
        return self:showFeedTopLayerSpine()
    end)
end

function RecommendationFeedManager:showFeedTopLayerSpineAsyncDelay(delayTime)
    local def = deferred.new()
    UError("[RecommendationFeed] schedule create feed top layer spine, delay:", tostring(delayTime))
    setTimeOut(function()
        UError("[RecommendationFeed] start create feed top layer spine")
        self:showFeedTopLayerSpineAsync():next(function(spine)
            UError("[RecommendationFeed] create feed top layer spine finished, spine:", tostring(spine), "disposed:", tostring(spine and spine.isDisposed))
            def:resolve(spine)
        end, function(err)
            UError("[RecommendationFeed] create feed top layer spine failed:", tostring(err))
            def:reject(err)
        end)
    end, delayTime)
    return def
end

function RecommendationFeedManager:playFeedTopLayerSpineDelay(delayTime, animName, loop)
    UError("[RecommendationFeed] schedule play feed top layer spine, delay:", tostring(delayTime), "anim:", tostring(animName or FEED_TOP_LAYER_SPINE_ANIM))
    setTimeOut(function()
        UError("[RecommendationFeed] start play feed top layer spine, spine:", tostring(self.feedTopLayerSpine), "disposed:", tostring(self.feedTopLayerSpine and self.feedTopLayerSpine.isDisposed))
        self:playFeedTopLayerSpine(animName, loop)
    end, delayTime)
end

function RecommendationFeedManager:playFeedTopLayerSpine(animName, loop)
    if not self.feedTopLayerSpine or self.feedTopLayerSpine.isDisposed then
        UError("[RecommendationFeed] feed top layer spine missing before play, recreate async")
        self:showFeedTopLayerSpineAsync():next(function()
            UError("[RecommendationFeed] recreate feed top layer spine finished before play")
            self:playFeedTopLayerSpine(animName, loop)
        end)
        return true
    end
    if not self.feedTopLayerSpine or self.feedTopLayerSpine.isDisposed then
        UError("[RecommendationFeed] feed top layer spine still missing, play failed")
        return false
    end

    UError("[RecommendationFeed] play feed top layer spine anim:", tostring(animName or FEED_TOP_LAYER_SPINE_ANIM), "loop:", tostring(loop or false))
    self.feedTopLayerSpine:playByName(animName or FEED_TOP_LAYER_SPINE_ANIM, loop or false)
    return true
end

function RecommendationFeedManager:onFeedLevelReady()
    self.feedLevelReady = true
    self:tryReportScene()
end

function RecommendationFeedManager:onFeedVideoReady()
    self.feedVideoReady = true
    self:tryReportScene()
end

function RecommendationFeedManager:tryReportScene()
    if self.feedSceneReported then return end
    if EnvUtil:isDYMiniGame() and FeedContext.isVideoFlowSupported() and FeedContext.isVideoGuideLevelFlow() and _G.getTopLevelId() == 1 then
        if not self.feedVideoReady then return end
        self:reportScene()
        return
    end

    if not self.feedLevelReady then return end

    if EnvUtil:isDYMiniGame() and FeedContext.isVideoFlowSupported() and FeedContext.isVideoGuideLevelFlow() and not self.feedVideoReady then
        return
    end

    self:reportScene()
end

function RecommendationFeedManager:registerFeedPreplayVideoTestButton()
    if self.feedPreplayVideoTestButtonRegistered then
        return
    end
    if not EnvUtil:isDevelopMode() then
        return
    end
    if not addGlobalTestButton then
        return
    end

    self.feedPreplayVideoTestButtonRegistered = true

    if EnvUtil:isDYMiniGame() then
        addGlobalTestButton("[抖音小游戏] 视频接口测试", function()
            if not FeedContext.isVideoFlowSupported() then
                CommonTip:showTip("[抖音视频] 当前版本不支持视频流")
                return nil, true
            end

            local videoPlayer = _G.amfBean("VideoPlayer")
            if not videoPlayer or not videoPlayer:isSupport() then
                CommonTip:showTip("[抖音视频] VideoPlayer 不可用")
                return nil, true
            end

            local defaultRect = getDefaultFeedPreplayVideoRect()
            local defaultInput = string.format("%d,%d,%d,%d", defaultRect.x, defaultRect.y, defaultRect.width, defaultRect.height)
            local DebugInputPanel = force_require "amf.debug.testbtn.view.testview.DebugInputPanel"
            DebugInputPanel("[抖音视频] 接口测试", "输入 x,y,width,height", defaultInput, function(input)
                local rect = parseFeedPreplayVideoRect(input, defaultRect)
                CommonTip:showTip(string.format("[抖音视频] 调用 showFeedPreplayVideo\nx=%s y=%s w=%s h=%s", tostring(rect.x), tostring(rect.y), tostring(rect.width), tostring(rect.height)))
                videoPlayer:openAndPlay({
                    videoFlow = FeedContext.DefaultVideoFlow,
                    x = rect.x,
                    y = rect.y,
                    width = rect.width,
                    height = rect.height,
                }, nil, function(result)
                    CommonTip:showTip("[抖音视频] 关闭/回调\n" .. tostring(result))
                end)
            end)
            return nil, true
        end, { TestButtonConst.Tags.DEVELOP })
    end

    addGlobalTestButton("[抖音小游戏] Feed Spine测试", function()
        self:showFeedTopLayerSpineAsync():next(function(spine)
            if not spine then
                CommonTip:showTip("[抖音Feed Spine] 创建失败")
                return
            end

            CommonTip:showTip("[抖音Feed Spine] 已添加到 topLayer，5秒后播放")
            setTimeOut(function()
                self:playFeedTopLayerSpine()
            end, 5)
        end, function()
            CommonTip:showTip("[抖音Feed Spine] 资源加载失败")
        end)
        return nil, true
    end, { TestButtonConst.Tags.DEVELOP })
end

function RecommendationFeedManager:onActTestButtonReady()
    self:registerFeedPreplayVideoTestButton()
end

function RecommendationFeedManager:onActEnterMainScene(evt)
    if EnvUtil:isWXMiniGame() then
        FeedContext.refreshWXLoginNewUserState(_G.getTopLevelId())
    end
end

-- 复访
function RecommendationFeedManager:initFeedRevisitUser()
    local function syncRevisitContext(feedScene, feedChannel)
        if tonumber(feedChannel) ~= 1 then
            FeedContext.clearRevisitContext()
            return false
        end
        if not feedScene then
            he_log_error("syncRevisitContext: feedScene 参数不能为空")
            FeedContext.clearRevisitContext()
            return false
        end

        local feedSceneStr = tostring(feedScene)
        if not FeedContext.isValidSceneStr(feedSceneStr) then
            he_log_error("syncRevisitContext: feedSceneStr 不在预定义的场景类型中: " .. feedSceneStr)
            FeedContext.clearRevisitContext()
            return false
        end

        FeedContext.setFeedEnterUser(true)
        FeedContext.setSceneStr(FeedContext.normalizeSceneStr(feedSceneStr))
        local feedGameExtra = FeedRevisitConfig.isEnabled()
            and FeedContext.queryFeedGameExtraFromJS() or nil
        FeedContext.setFeedGameExtra(feedGameExtra)
        FeedContext.setOpenStartPanel(FeedContext.shouldShowStartPanelForScene(feedSceneStr))
        -- 离线收益场景不开 start panel，改为在 Stage2 直接拉起金银果树面板
        FeedContext.setOpenOfflineRewardPanel(feedSceneStr == FeedContext.SceneType.OFFLINE_REWARD)
        FeedContext.setSkipAutoStartLevel(true)
        return true
    end

    local function showImportantEventFallbackTip()
        if FeedContext.getSceneStr() ~= FeedContext.SceneType.IMPORTANT_EVENT_DROP
            or FeedRevisitConfig.isImportantEventSignIn(FeedContext.getTrialSourceIdFromJS()) then
            return
        end

        local curScene = Director:sharedDirector():getRunningScene()
        local safeArea = _G.fullScreenSizeManager:getSafeArea()
        local visibleSize = safeArea.size
        local originPos = safeArea.origin
        local tip = UITip.Builder.new()
            :setMessage("小村民，活动已就绪，快来参与吧！", "B2714AFF", nil, 30)
            :setDirection(UITip.Direction.DOWN)
            :setSkin(UITip.SkinType.FEED)
            :setAutoCloseTime(0)
            :setMinWidthAndHeight(600, 40)
            :buildSingleTip(true)
        tip:getChildByName("arrowNode"):setVisible(false)
        curScene:addChild(tip, SceneLayerShowKey.TOP_LAYER)
        tip:setPositionXY(360, originPos.y + visibleSize.height - 70)
    end

    local function shouldReportAfterRevisitPanelShown()
        local feedScene = FeedContext.getSceneStr()
        local contentId = FeedContext.getTrialSourceIdFromJS()
        if feedScene == FeedContext.SceneType.IMPORTANT_EVENT_DROP then
            return FeedRevisitConfig.isImportantEventSignIn(contentId)
        end
        if feedScene == FeedContext.SceneType.ENERGY_RECOVER then
            return FeedRevisitConfig.getEnergyRewardKey(contentId, FeedContext.getFeedGameExtra()) ~= nil
        end
        -- 离线收益场景要等金银果树面板真正展示后再上报场景就绪
        if feedScene == FeedContext.SceneType.OFFLINE_REWARD then
            return FeedRevisitConfig.isOfflineReward(contentId)
        end
        return false
    end

    -- 推荐流直出显示
    _G.onRecommendationFeedShow = function(feedScene, feedChannel, scene)
        self:resetReportSceneState()
        if not syncRevisitContext(feedScene, feedChannel) then return end
        showImportantEventFallbackTip()
        if not shouldReportAfterRevisitPanelShown() then
            self:reportScene()
        end
        DcUtil:UserTrack({ category = DcUtil:getMiniGameCategory(), sub_category = 'feed_show', t1 = "pre", t2 = tostring(feedScene), t3 = tostring(feedChannel), t4 = tostring(scene) })
    end
end

-- 获客
function RecommendationFeedManager:initFeedNewUser()
    _G.onRecommendationFeedShowNewUser = function()
        self:resetReportSceneState()
        setupFeedNewUserTrial()
    end
end

function RecommendationFeedManager:initFeedListeners()
    self:initFeedRevisitUser();
    self:initFeedNewUser();

    _G.didRecommendationFeedShow = function(feedScene, feedChannel, scene, source)
        syncWXFeedState(false)
        ensureWXFeedTrialLevelId()
        triggerWXFeedTrialAutoPopup()

        DcUtil:UserTrack({ category = DcUtil:getMiniGameCategory(), sub_category = 'feed_show', t1 = "show", t2 = tostring(feedScene), t3 = tostring(feedChannel), t4 = tostring(scene) })
    end

    _G.onRecommendationFeedShowTouchEnd = function(feedScene, feedChannel, scene)
        syncWXFeedState(true)
        ensureWXFeedTrialLevelId()
        triggerWXFeedTrialAutoPopup()

        DcUtil:dailyUser(true, false)
        DcUtil:logInGame(true)
        DcUtil:UserTrack({ category = DcUtil:getMiniGameCategory(), sub_category = 'feed_show', t1 = "click", t2 = tostring(feedScene), t3 = tostring(feedChannel), t4 = tostring(scene)})

        -- 只在获客版请求一次（FeedUserEnterGame 为抖音独享 PB）
        if EnvUtil:isDYMiniGame() and FeedContext.canRequestEnterGame() and FeedContext.isNewUser() then
            FeedContext.setCanRequestEnterGame(false)
            require("amf.middleware.multiplatform.minigameadaptor.douyin.http.FeedUserEnterGame"):post()
        end
    end

    -- 从推荐流直出进入场景
    _G.onRecommendationFeedEnter = function(feedScene, feedChannel, scene)
        syncWXFeedState(true)
        ensureWXFeedTrialLevelId()
        triggerWXFeedTrialAutoPopup()

        -- 只给新游湖发事件，复访版不需要发这个事件。
        local isNewUser = FeedContext.isNewUser()
        if isNewUser then
            -- 新用户进入
            if EnvUtil:isWXMiniGame() then
                MiniGameEventCenter:dispatch(MiniGameEvent.ON_WX_FEED_NEW_USER)
            elseif EnvUtil:isDYMiniGame() then
                MiniGameEventCenter:dispatch(MiniGameEvent.ON_DY_FEED_NEW_USER)
            end
        end

        if EnvUtil:isWXMiniGame() then
            MiniGameEventCenter:dispatch(MiniGameEvent.ON_WX_FEED_ENTER)
        elseif EnvUtil:isDYMiniGame() then
            MiniGameEventCenter:dispatch(MiniGameEvent.ON_DY_FEED_ENTER)
        end
        DcUtil:UserTrack({ category = DcUtil:getMiniGameCategory(), sub_category = 'feed_show', t1 = "enter", t2 = tostring(feedScene), t3 = tostring(feedChannel), t4 = tostring(scene) })
        DcUtil:dailyUser(false, true)
    end

    -- 推荐流直出退出场景
    _G.onRecommendationFeedExit = function(feedScene, feedChannel, scene)
        if EnvUtil:isWXMiniGame() then
            MiniGameEventCenter:dispatch(MiniGameEvent.ON_WX_FEED_EXIT)
        elseif EnvUtil:isDYMiniGame() then
            MiniGameEventCenter:dispatch(MiniGameEvent.ON_DY_FEED_EXIT)
        end
        DcUtil:UserTrack({ category = DcUtil:getMiniGameCategory(), sub_category = 'feed_show', t1 = "exit", t2 = tostring(feedScene), t3 = tostring(feedChannel), t4 = tostring(scene) })
        self.feedPreplayVideoShown = false
    end
end

function RecommendationFeedManager:reportScene()
    if self.feedSceneReported then return end
    self.feedSceneReported = true
    FeedContext.reportScene()
end

function RecommendationFeedManager:setFeedSubscribeStatus(status)
    local normalized = normalizeBoolean(status)
    if normalized == nil then
        self._feedSubscribeStatus = FEED_SUBSCRIBE_STATUS_UNKNOWN
        return false
    end
    self._feedSubscribeStatus = normalized
    if normalized == false then
        self:tryAddFeedSubscribeGuideIcon("status_updated")
    else
        self:refreshFeedSubscribeGuideIcon("status_updated", {status = normalized})
    end
    return true
end

function RecommendationFeedManager:getFeedSubscribeStatus()
    return self._feedSubscribeStatus
end

function RecommendationFeedManager:onFeedSubscribeGuideIconTapped()
    local result, detail = self:openFeedSubscribeGuidePanel()
    if result == false then
        return false, detail or "FEED_SUBSCRIBE_GUIDE_PANEL_OPEN_FAILED", false
    end
    return true, nil, true
end

function RecommendationFeedManager:queryFeedSubscribeStatus(callback, params)
    if not isFeedSubscribeRuntimeAvailable() then
        safeRunCall(callback, nil, "FEED_SUBSCRIBE_UNAVAILABLE")
        return
    end
    params = params or self:getFeedSubscribeRequestParams()
    if params == nil then
        safeRunCall(callback, nil, "FEED_SUBSCRIBE_PARAMS_REQUIRED")
        return
    end
    local serializedParams = serializeJsParams(params)
    if not serializedParams then
        safeRunCall(callback, nil, "FEED_SUBSCRIBE_PARAMS_INVALID")
        return
    end
    CALL_EASY_JS_ASYNC("globalThis.animalPlugin.sdkManager.checkFeedSubscribeStatus", function(result)
        if not isFeedSubscribeRuntimeAvailable() then
            safeRunCall(callback, nil, "FEED_SUBSCRIBE_UNAVAILABLE")
            return
        end
        local response = deserializeJsResult(result)
        local status = response and response.data and normalizeBoolean(response.data.status)
        if response and response.errCode == 0 and status ~= nil then
            self:setFeedSubscribeStatus(status)
            safeRunCall(callback, status, response)
            return
        end
        safeRunCall(callback, nil, response)
    end, serializedParams)
end

function RecommendationFeedManager:requestFeedSubscribe(params, callback, dcParam)
    if not isFeedSubscribeRuntimeAvailable() then
        safeRunCall(callback, false, "FEED_SUBSCRIBE_UNAVAILABLE")
        return
    end
    if params == nil then
        safeRunCall(callback, false, "FEED_SUBSCRIBE_PARAMS_REQUIRED")
        return
    end
    local serializedParams = serializeJsParams(params)
    if not serializedParams then
        safeRunCall(callback, false, "FEED_SUBSCRIBE_PARAMS_INVALID")
        return
    end
    local normalizedDcParam = self:buildFeedSubscribeDcParam(dcParam)
    self:trackFeedSubscribeSubscriptionShow(normalizedDcParam)
    CALL_EASY_JS_ASYNC("globalThis.animalPlugin.sdkManager.requestFeedSubscribe", function(result)
        if not isFeedSubscribeRuntimeAvailable() then
            safeRunCall(callback, false, "FEED_SUBSCRIBE_UNAVAILABLE")
            return
        end
        local response = deserializeJsResult(result)
        local success = response and response.errCode == 0
            and response.data and normalizeBoolean(response.data.success)
        self:trackFeedSubscribePanelResult(normalizedDcParam.panel_id, success == true)
        if success then
            -- 订阅接口成功后先更新本地状态，保证面板和 Icon 立即进入已订阅状态；
            -- 后续查询用于和服务端状态再次对齐。
            self:setFeedSubscribeStatus(true)
            self:setFeedSubscribeCanReward(true)
            self:queryFeedSubscribeStatus(nil, params)
            safeRunCall(callback, true, response)
            return
        end
        safeRunCall(callback, false, response)
    end, serializedParams)
end

-- 订阅预留 暂未使用 调用示例
function RecommendationFeedManager:feedSubscribeCase(contentIDsList)
    if not isFeedSubscribeRuntimeAvailable() then
        return false, "FEED_SUBSCRIBE_UNAVAILABLE"
    end
    if type(contentIDsList) ~= "table" then
        contentIDsList = { contentIDsList }
    end
    if #contentIDsList == 0 then
        contentIDsList = { "CONTENT12579380482", "CONTENT12546509314" }
    end

    local contentIDsStr = table.concat(contentIDsList, ",")
    local param = table.serialize({
        scene = 1, -- 非全场景下必传
        contentIDsStr = contentIDsStr, -- 非全场景下必传
        allScene = false, -- 是否为全场景订阅
        type = "play" -- 目前只支持传 'play'
    })

    CALL_EASY_JS_ASYNC("globalThis.animalPlugin.sdkManager.requestFeedSubscribe", function(result)
        local r = table.deserialize(result)
        if r and r.errCode == 0 then
            if r.data.success == true or r.data.success == "true" then
                -- 订阅成功
            else
                -- 订阅失败
            end
        else
            -- 处理错误
            local errMsg = r and r.errMsg or "未知错误"
            UError("订阅失败: " .. errMsg)
        end
    end, param)

    CALL_EASY_JS_ASYNC("globalThis.animalPlugin.sdkManager.checkFeedSubscribeStatus", function(result)
        local r = table.deserialize(result)
        if r and r.errCode == 0 then
            if r.data.status == true or r.data.status == "true" then
                -- 已订阅
            else
                -- 未订阅
            end
        else
            local errMsg = r and r.errMsg or "未知错误"
            UError("订阅失败: " .. errMsg)
        end
    end, param)

end

return RecommendationFeedManager
