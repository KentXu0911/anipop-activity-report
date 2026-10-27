require "amf.feature.promotionevent2025.config.PromotionEvent2025Const"
local PromotionEvent2025Group = require "amf.feature.promotionevent2025.config.PromotionEvent2025Group"
local PromotionEvent2025BannerSwitch = require "amf.feature.promotionevent2025.config.PromotionEvent2025BannerSwitch"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"
local PromotionEvent2025DC = require "amf.feature.promotionevent2025.dc.PromotionEvent2025DC"
local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local deferred = require "amf.script.sugar.deferred"
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local TextUtil = require "amf.middleware.ui.util.TextUtil"
local LocationDataConfig = require "amf.middleware.service.location.config.LocationDataConfig"
local PropConst = require "amf.middleware.propfeature.core.config.PropConst"
require "amf.feature.mainscene.module.topbanner.config.SceneTopBannerConst"
require "amf.feature.mainscene.module.topbanner.SceneTopBannerContext"

local PromotionEvent2025Manager = class("PromotionEvent2025Manager")

local ICON_V2_EXPERIMENT_MODULE = "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"
local ICON_V2_ADAPTER_MODULE = "amf.feature.mainscene.module.icon.v2.runtime.PackageIconV2Adapter"
local ADAPTER_CREATE_READY = "ready"
local ADAPTER_CREATE_SAFE_LEGACY = "safe_legacy"
local ADAPTER_CREATE_WAIT_OWNER = "wait_owner"
local ADAPTER_STATE_NONE = "none"
local ADAPTER_STATE_V2 = "v2_mounted"
local ADAPTER_STATE_LEGACY = "legacy_mounted"
local ADAPTER_STATE_CLEANUP = "cleanup_required"
local ADAPTER_STATE_BLOCKED = "blocked"

-- 包装表标记：normalizeOpenParams 是幂等的，否则 openMainAct 已经归一化过的参数
-- 在 showXxxPanel 里会被二次包装，空 jumpInfo 会变成非 nil 表，
-- 关闭面板时被误判成"从关卡跳转"，从而打开最高关开始面板。
local OPEN_PARAMS_TAG = "__normalizedOpenParams"
local function normalizeOpenParams(jumpInfo, fromBanner)
    if type(jumpInfo) == "table"
        and fromBanner == nil
        and (jumpInfo[OPEN_PARAMS_TAG] == true
            or jumpInfo.jumpInfo ~= nil
            or jumpInfo.fromBanner ~= nil
            or jumpInfo.fromGoLook ~= nil)
    then
        return jumpInfo
    end

    return {
        jumpInfo = jumpInfo,
        fromBanner = fromBanner,
        [OPEN_PARAMS_TAG] = true,
    }
end

local function logIconV2Error(message)
    if ALog and type(ALog.strict_log_error) == "function" then
        pcall(ALog.strict_log_error, "[PromotionEvent2025IconV2] " .. tostring(message))
    end
end

local function callAdapterMethod(adapter, methodName, ...)
    local method = adapter and adapter[methodName]
    if type(method) ~= "function" then
        return false, nil, "PROMOTION_EVENT_2025_ICON_V2_ADAPTER_METHOD_REQUIRED:" .. tostring(methodName)
    end
    local ok, result, detail = pcall(method, adapter, ...)
    if not ok then
        return false, nil, result
    end
    return true, result, detail
end

local function resolveAdapterState(adapter)
    if not adapter then
        return ADAPTER_STATE_NONE
    end
    local mountedOk, mounted, mountedError = callAdapterMethod(adapter, "isMounted")
    if not mountedOk then
        return ADAPTER_STATE_BLOCKED, mountedError
    end
    if mounted ~= true then
        return ADAPTER_STATE_CLEANUP
    end
    local activeOk, active, activeError = callAdapterMethod(adapter, "isV2Active")
    if not activeOk then
        return ADAPTER_STATE_BLOCKED, activeError
    end
    return active == true and ADAPTER_STATE_V2 or ADAPTER_STATE_LEGACY
end

local function getAdapterIcon(adapter)
    local called, icon, callError = callAdapterMethod(adapter, "getIcon")
    if not called then
        return nil, callError
    end
    return icon
end

local function disposeAdapter(adapter)
    local called, disposed, disposeError = callAdapterMethod(adapter, "dispose")
    if not called then
        return false, disposeError
    end
    if disposed ~= true then
        return false, disposeError or "PROMOTION_EVENT_2025_ICON_V2_ADAPTER_DISPOSE_FAILED"
    end
    return true
end

local function refreshAdapter(adapter, reason, payload)
    local called, refreshed, refreshError = callAdapterMethod(adapter, "refresh", reason, payload)
    if not called then
        return false, refreshError
    end
    if refreshed == false then
        return false, refreshError
    end
    return refreshed, refreshError
end

local function consumeAdapterNew(adapter, reason)
    local called, consumed, consumeError = callAdapterMethod(adapter, "consumeCurrentCycleNew", reason)
    if not called then
        return false, consumeError
    end
    if consumed == false then
        return false, consumeError
    end
    return consumed, consumeError
end

------------------------------------------- 初始化 ---------------------------------
function PromotionEvent2025Manager:ctor()
    self._assetsUtil = nil
    self._iconManager = nil
    self._autoPopupMgr = nil
    self._userManager = nil
    self._propManager = nil
    self._userStateManager = nil
    self._userManager = nil
    self._profileManager = nil

    self._model = nil
    self._isResLoadReady = false
    self._isResDownloadReady = false
    self._iconTouchLock = false
    self._iconRankBeforePassLevel = 0 --todo 移到model tempdata
    self._iconAdapter = nil
    self._iconDataProvider = nil
    self._iconAdapterRecoveryPending = false
    self._rewardBanner = nil
    -- 关卡内进度快照：过关面板创建时不能重新读取已被自动领奖流程修改的数据。
    self._levelInitTaskData = nil
    self._levelCollectionIconInfo = nil

    self._pendingPromotionCardPackList = {}

    return self
end

function PromotionEvent2025Manager:setProfileManager(profileManager)
    self._profileManager = profileManager
end

function PromotionEvent2025Manager:setUserManager(userManager)
    self._userManager = userManager
end

function PromotionEvent2025Manager:setUserStateManager(mgr)
    self._userStateManager = mgr
end

function PromotionEvent2025Manager:setAutoPopupMgr(autoPopupMgr)
    self._autoPopupMgr = autoPopupMgr
end

function PromotionEvent2025Manager:setPropManager(propManager)
    self._propManager = propManager
end

function PromotionEvent2025Manager:setIconManager(iconManager)
    self._iconManager = iconManager
end

function PromotionEvent2025Manager:setAssetsUtil(assetsUtil)
    self._assetsUtil = assetsUtil
end

function PromotionEvent2025Manager:initialize()
    if not self:isBaseEnabled() then return end

    self:initPlugs()
    self:initModel()
    self:requestGetMainInfo(true)
    self:loadGlobalRes(true, true)
    _G.amfEC:registerFeature(self)
    _G.amfEC:registerSystem(self)

    local InLevelBridgeModule = require "amf.feature.promotionevent2025.module.InLevelBridgeModule"
    self.inLevelBridgeModule = InLevelBridgeModule:create(self)

    IconEventCenter:register(IconEvent.ICON_SYSTEM_READY, function()
        self:updateIcon()
    end, self)

    for i,v in ipairs(PromotionEvent2025Const.PEItemList) do
        local prop = require("amf.feature.promotionevent2025.prop.AMFProp_"..v.itemId)
        self._propManager:registerProp(prop)
    end

    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
    PropEventCenter:register(PropEvent.RESOLVE_ICON, self._onResolveIcon, self)

    ----------------------- 月票兼容 ------------------------
    -- local ActDependencyConfig = require "amf.middleware.activitylinkage.config.ActDependencyConfig"
    -- ActDependencyConfig.sendPropMgrNameMap[tostring(PromotionEvent2025Const.FeatureId)] = "PromotionEvent2025Manager"

    -- function PromotionEvent2025Manager:getActShowName()
    --     return PromotionEvent2025Const.ActShowName
    -- end

    -- function PromotionEvent2025Manager:getMainEndTime()
    --     return self:getPeriodEndTime()
    -- end

    -- function PromotionEvent2025Manager:openActivity(closeCallback, extra, userClick)
    --     self:openMainAct(userClick):next(function()
    --         if closeCallback then closeCallback() end
    --     end, function()
    --         if closeCallback then closeCallback() end
    --     end)
    -- end
    --------------------------------------------------------------------------------------
end

function PromotionEvent2025Manager:initModel()
    self._model = require("amf.feature.promotionevent2025.model.PromotionEvent2025Model"):create()
    self:genModelFunc()
    self._model:setTempData("ActSendPlug",self:_getPlug("ActSend"))
end

-- model开放外部调用的getsetcheck方法
local modelSetGetList = {
    "isPreHeat",
    "isRest",
    "isClose",
    "isOpen",
    "getCurDanRewardByRank",
    "getLastDanRewardByRank",
    "getScore",
    "getRank",
    "addBuffItem",
    "getBuffMap",
    "getCollectionBuffEndTime",
    "getCollectionFactor",
    "getCoinBuffEndTime",
    "getCoinFactor",
    "getScoreBuffEndTime",
    "getScoreFactor",
    "getTaskDataByTaskIndex",
    "getLastPeriod",
    "getGroupRankInfo",
    "getFriendInfo",
    "getUserHistory",
    "needHistoryRankReward",
    "isResultConfirmed",
    "syncShowCollectNum",
    "clearShowCollectNum",
    "getCollectNum",
    "getCanRewardsTaskDataForAll",
    "getAllTaskInfos",
    "getCurTaskInfo",
    "getNormalTaskRewards",
    "getCompleteTaskIndex",
    "getCurTaskIndex",
    "getFinalTaskIndex",
    "isFinishAllTask",
    "getFinalReward",
    "getDan",
    "getLastDanDiff",
    "getPeriodEndTime",
    "getPeriodBeginTime",
    "getPreHeatEndTime",
    "getRestEndTime",
    "getPeriod",
    "getCurPeriodConfig",
    "getMaxRankRewad",
    "getLocation",
    "setLastShareRewardBean",
    "getLastShareRewardBean",
    "getFragmentWelfareInfo",
    "setPreInFlag",
    "getPreInFlag",
    "setLastRankFlag",
    "getLastRankFlag",
    "setMainPanelFlag",
    "getMainPanelFlag",
    "setHandGuideFlag",
    "getHandGuideFlag",
    "setIconTipFlag",
    "getIconTipFlag",
}

function PromotionEvent2025Manager:genModelFunc()
    for k,v in ipairs(modelSetGetList) do
        self[v] = function(context, ...)
            -- 这里可以打log
            return context._model[v](context._model, ...)
        end
    end
end

function PromotionEvent2025Manager:setDataValue(key, value)
    self._model:setValue(key, value)
end

function PromotionEvent2025Manager:getDataValue(key)
    return self._model:getValue(key)
end

function PromotionEvent2025Manager:getConfig(key)
    return self._model:getConfigValue(key)
end

function PromotionEvent2025Manager:setDataTempValue(key, value)
    self._model:setTempData(key, value)
end

function PromotionEvent2025Manager:getDataTempValue(key)
    return self._model:getTempData(key)
end

function PromotionEvent2025Manager:loadGlobalRes(silence, ignoreDownloadAll)
    local resList = PromotionEvent2025Const.GlobalResList
    return self:loadRes(silence, resList, ignoreDownloadAll)
end

-- 加载全局性不卸载资源
function PromotionEvent2025Manager:loadRes(silence, resList, ignoreDownloadAll)
    local d = deferred.new()

    if silence == nil then
        silence = true
    end

    if EnvUtil:isMiniGame() then
        self._assetsUtil:loadMiniFiles(resList, silence):next(function()
            self._isResDownloadReady = true
            self._isResLoadReady = true
            d:resolve()
        end, function()
            d:reject()
        end)
    else
        local function realLoad()
             for i,v in ipairs(resList) do
                if string.find(v, ".plist") then
                    UICreateUtil:loadPlist(v)
                end
            end
            self._isResLoadReady = true
            d:resolve()
        end

        if not self._isResDownloadReady and not ignoreDownloadAll then
            local function _onResReady()
                self._isResDownloadReady = true
                realLoad()
            end

            local failCallback = function()
                d:reject()
            end

            self._assetsUtil:loadDynamicModule("meta/PromotionEvent2025Res.xml", _onResReady, failCallback, failCallback, not silence)
        else
            realLoad()
        end
    end

    return d
end

function PromotionEvent2025Manager:unloadRes(resList)
    if EnvUtil:isMiniGame() then
        self._assetsUtil:unloadRes(resList)
    else
        for i,v in ipairs(resList) do
            if string.find(v, ".plist") then
                UICreateUtil:unloadPlist(v)
            end
        end
    end
end

---------------------- 业务逻辑·判断 ---------------------

function PromotionEvent2025Manager:isBaseEnabled()
    return PromotionEvent2025Group:isFeatureEnabled() and FeatureSwitch:isOpen(FeatureSwitch.Type.PROMOTION_EVENT)
end

function PromotionEvent2025Manager:isDataEnabled()
    return self._model and self._model:isDataEnabled()
end

function PromotionEvent2025Manager:isResEnabled()
    return self._isResLoadReady and self._isResDownloadReady
end

function PromotionEvent2025Manager:isGlobalResEnabled()
    return self._isResLoadReady
end

function PromotionEvent2025Manager:isEnabled()
    return self:isBaseEnabled() and self:isDataEnabled() and self:isGlobalResEnabled() and self:isOpen()
end

function PromotionEvent2025Manager:isPEItem(itemId)
    local item = table.find(PromotionEvent2025Const.PEItemList, function(v)
        return tostring(v.itemId) == tostring(itemId)
    end)

    return item, item and item.isBuff
end

function PromotionEvent2025Manager:canGetReward()
    local curTaskInfo = self:getCurTaskInfo()
    if curTaskInfo then
        local collectNum = self:getCollectNum()
        return collectNum >= curTaskInfo.total
    end

    return false
end

function PromotionEvent2025Manager:isOverPeriod()
    if self:isOpen() then
        local endTime = self:getPeriodEndTime()
        local now = TimeKit:timeInSec()
        if endTime and now > endTime then
            return true
        end
    end
    return false
end

function PromotionEvent2025Manager:canCollectInLevel()
    if not self:isEnabled() then return false end
    return not self:isOverPeriod() and self:isOpen()
end

function PromotionEvent2025Manager:isInWelfare()
    if not self:isEnabled() then return false end

    local welfareInfo = self:getFragmentWelfareInfo()
    if not welfareInfo then
        return false
    else
        return welfareInfo.isInWelfare
    end
end
---------------------- 业务逻辑·流程 ---------------------

-- 打开活动主流程
function PromotionEvent2025Manager:openMainAct(isUserClick, jumpInfo, fromBanner)
    local promise = deferred.new()
    local openParams = normalizeOpenParams(jumpInfo, fromBanner)

    local function resolveOpen()
        if isUserClick ~= true and self:isV2IconActive() then
            local consumed, consumeError = consumeAdapterNew(self._iconAdapter, "auto_popup")
            if consumed == false then
                logIconV2Error("consume auto popup New failed: " .. tostring(consumeError))
            end
        end
        promise:resolve()
    end

    local function rejectOpen()
        promise:reject()
    end

    local function doOpenAct()
        if not self:isEnabled() then
            promise:reject()
            return
        end

        if EnvUtil:isDevelopMode() then
            local periodConfig = self:getCurPeriodConfig()
            local taskType = periodConfig.taskType
            if taskType ~= PromotionEvent2025Const.TaskType.kAnimal and taskType ~= PromotionEvent2025Const.TaskType.kLine then
                CommonTip:showTip("拿不到当前期配置，是不是调时间了！")
                promise:reject()
                return
            end
        end

        if self:isPreHeat() then
            self:showBeforeOpenPanel(isUserClick, PromotionEvent2025Const.BeforeOpenPanelType.kNewOpen):next(resolveOpen, rejectOpen)
        elseif self:isRest() then
            self:showBeforeOpenPanel(isUserClick, PromotionEvent2025Const.BeforeOpenPanelType.kRestTip):next(resolveOpen, rejectOpen)
        elseif not self:isResultConfirmed() then
            self:showLastPeriodRankPanel(openParams):next(resolveOpen, rejectOpen)
        elseif not self:getPreInFlag() then
            if self:getCompleteTaskIndex() <= 0 then
                self:showDanChangePanel(nil, nil, openParams):next(resolveOpen, rejectOpen)
            else
                self:showPreInRankPanel(isUserClick, openParams):next(resolveOpen, rejectOpen)
            end
        elseif self:getCompleteTaskIndex() >= 1 then
            self:showMainPanel(isUserClick, openParams, nil, nil, nil, not self:getMainPanelFlag()):next(resolveOpen, rejectOpen)
        else
            self:showPreInRankPanel(isUserClick, openParams):next(resolveOpen, rejectOpen)
        end
    end

    local completeCount = 0
    local completeProcess = function()
        completeCount = completeCount + 1
        if completeCount >= 2 then
            doOpenAct()
        end
    end

    self:loadGlobalRes(false):next(completeProcess, function()
        promise:reject()
    end)

    self:requestGetMainInfo():next(completeProcess, function()
        promise:reject()
    end)

    return promise
end

-- 自动领奖流程(依次全领)
function PromotionEvent2025Manager:tryToAutoGetRewards()
    self._model:resetAndCalTaskDataForGetReward()

    local playId = "no_play_id"
    local prevSceneMgr = UBFPrevSceneManager:getInstance()
    if prevSceneMgr then
        local levelInfo = prevSceneMgr:getLevelInfo()
        if levelInfo then playId = levelInfo.playId end
    else
        playId = "no_prev_scene"
    end

    local lastTaskProgressInfo = self:getDataTempValue("lastTaskProgressInfo")
    local reward_level = ""
    for i = 1, #lastTaskProgressInfo - 1 do
        local tm = lastTaskProgressInfo[i]
        if i == #lastTaskProgressInfo - 1 then
            reward_level = reward_level .. tm.taskInfo.curTaskIndex
        else
            reward_level = reward_level .. tm.taskInfo.curTaskIndex .. "_"
        end
    end

    local beforeTaskId = self:getCompleteTaskIndex()

    local function autoAcquireRewards()
        local isOverPeriod = self:isOverPeriod()
        local taskInfo = self:getCurTaskInfo()
        local canGetReward = self:canGetReward()
        if not canGetReward or not taskInfo or isOverPeriod then
            PromotionEvent2025DC:reward_progress(
                1,
                #lastTaskProgressInfo - 1,
                reward_level == "" and 0 or reward_level,
                playId
            )
            local curTaskId = self:getCompleteTaskIndex()
            return
        end

        local requestReward = function()
            self:requestGetRewardsAuto(taskInfo, false):next(function()
                self._model:setTaskDataStateByTaskIndex(taskInfo.curTaskIndex, PromotionEvent2025Const.TaskState.kRewarded)
                self._model:makeTaskBaseId(true)
                self:updateMainSceneRewardBanner()
                if taskInfo.curTaskIndex == 1 then
                    self:requestGetCurGroupInfo()
                end
                autoAcquireRewards()
            end, function()
                self._model:setRewardFailFlag(true)
                -- 领奖失败（断网/请求异常）：在本次过关的进度数据上追加 rewardFailed 字段（不动 taskState 语义），
                -- banner 通过已有的 RefreshData 轮询读到后结束等待；超时兜底见 UBFPromotionTopUI:finishRewardWait
                self._model:setTaskRewardFailedByTaskIndex(taskInfo.curTaskIndex, true)
            end)
        end

        requestReward()
    end

    autoAcquireRewards()
end

-- 处理排行榜数据
function PromotionEvent2025Manager:handleRankData(rankData, needCheckMe)
    local ret = table.clone(rankData.rankList or {})

    if needCheckMe then
        local uid = self._userManager:getUid()
        local find = false
        for index, rankInfo in ipairs(ret) do
            rankInfo.rank = index
            if tostring(rankInfo.uid) == tostring(uid) then
                rankInfo.isMe = true
                find = true
            end
        end

        if not find then
            table.insert(ret,{
                rank = self:getRank(),
                score = self:getScore(),
                profile = self._userManager.profile,
                isMe = true,
                updateTime = 0,
                uid = uid
            })
        end
    end

    for index, rankInfo in ipairs(ret) do
		if not rankInfo.profile then
            local profile = table.find(rankData.profiles or {}, function(v)
                return tostring(v.uid) == tostring(rankInfo.uid)
            end)

            if not profile then
                profile = {}
                profile.headUrl = "[Unknown]"
                profile.headFrame = HeadFrameType.kNormal
            end

            rankInfo.profile = profile
		end
	end

    table.sort(ret, function(a, b)
        if a.score > b.score then
            return true
        elseif a.score == b.score then
            if tonumber(a.updateTime) ==  tonumber(b.updateTime ) then
                return tonumber(a.uid ) <  tonumber(b.uid )
            else
                return tonumber(a.updateTime ) < tonumber(b.updateTime )
            end
        else
            return false
        end
    end)

    return ret
end

-- 分享
function PromotionEvent2025Manager:doShareProcess(panelId, typeIndex)
    local promise = deferred.new()

    deferred.success():next(function()
        return self:shareToMini(typeIndex)
    end):next(function()
        PromotionEvent2025DC:share_dc(
            "share_success",
            panelId,
            (typeIndex <= 4) and "newpromotion_settle" or "newpromotion_reward"
        )
    end):next(function()
        local shareRewardBean = self:getLastShareRewardBean()
        if shareRewardBean and not shareRewardBean.reward then
            return self:requestShareReward(shareRewardBean)
        end
    end):next(function(rewardList)
        if rewardList then
            return self:showShareRewardPanel(rewardList)
        end
    end):next(function()
        promise:resolve()
    end, function()
        promise:reject()
    end)

    return promise
end
----------------------- 业务逻辑·面板 ---------------------

function PromotionEvent2025Manager:showBeforeOpenPanel(isUserClick, panelType)
    local promise = deferred.new()

    local MainPanelVM = require "amf.feature.promotionevent2025.view.panelvm.BeforeOpenPanelVM"
    local panelVm = MainPanelVM.Builder.new()
        :setUserClick(isUserClick)
        :setPanelType(panelType)
        :setCloseCallback(function()
            promise:resolve()
        end)
        :setLoadResFailCallback(function()
            promise:reject()
        end)
        :build()

    panelVm:popout()

    return promise
end

function PromotionEvent2025Manager:showMainPanel(isUserClick, jumpInfo, needBehind, panelReadyCallBack, fromGoLook, needAnimIn)
    local promise = deferred.new()
    local openParams = normalizeOpenParams(jumpInfo)
    if fromGoLook == nil then
        fromGoLook = openParams.fromGoLook
    end

    local MainPanelVM = require "amf.feature.promotionevent2025.view.panelvm.MainPanelVM"
    local panelVm = MainPanelVM.Builder.new()
        :setUserClick(isUserClick)
        :setJumpInfo(openParams.jumpInfo)
        :setNeedBehind(needBehind)
        :setFromGoLook(fromGoLook)
        :setFromBanner(openParams.fromBanner)
        :setNeedAnimIn(needAnimIn)
        :setCloseCallback(function()
            promise:resolve()
            -- 面板内会自动补领任务奖励，退出主面板后主场景图标角标需要按最新数据重算
            self:updateIcon("main_panel_close")
        end)
        :setLoadResFailCallback(function()
            promise:reject()
        end)
        :setPanelReadyCallback(panelReadyCallBack)
        :build()

    if needBehind then
        panelVm:popout(nil, true, nil, nil, 0)
    else
        panelVm:popout(UIConst.PanelPopout.NORMAL, true)
    end

    return promise, panelVm
end

function PromotionEvent2025Manager:showPreInRankPanel(isUserClick, jumpInfo, needBehind, panelReadyCallBack)
    local promise = deferred.new()
    local openParams = normalizeOpenParams(jumpInfo)

    local PreInRankPanelVM = require "amf.feature.promotionevent2025.view.panelvm.PreInRankPanelVM"
    local panelVm = PreInRankPanelVM.Builder.new()
        :setUserClick(isUserClick)
        :setJumpInfo(openParams.jumpInfo)
        :setFromBanner(openParams.fromBanner)
        :setNeedBehind(needBehind)
        :setCloseCallback(function()
            promise:resolve()
        end)
        :setLoadResFailCallback(function()
            promise:reject()
        end)
        :setPanelReadyCallback(panelReadyCallBack)
        :build()

    if needBehind then
        panelVm:popout(nil, true, nil, EnvUtil:isMiniGame() and 200 or 1, 0)
    else
        panelVm:popout(UIConst.PanelPopout.NORMAL)
    end

    return promise, panelVm
end

function PromotionEvent2025Manager:showDetailInfoPanel(tabIndex)
    local promise = deferred.new()

    local DetailInfoPanelVM = require "amf.feature.promotionevent2025.view.panelvm.DetailInfoPanelVM"
    local panelVm = DetailInfoPanelVM.Builder.new()
        :setTabIndex(tabIndex)
        :setCloseCallback(function()
            promise:resolve()
        end)
        :setLoadResFailCallback(function()
            promise:reject()
        end)
        :build()

    panelVm:popout()

    return promise
end

function PromotionEvent2025Manager:showHistoryPanel(from, profile)
	local promise = deferred.new()

    self:loadGlobalRes(false, false):next(function()
        self:requestGetHistory(profile.xxlId):next(function(historyInfo)
            local HistoryPanelVM = require "amf.feature.promotionevent2025.view.panelvm.HistoryPanelVM"
            local panel = HistoryPanelVM:create(from, historyInfo, profile)

            panel:setCloseCallback(function()
                promise:resolve()
            end)

            panel:setLoadResFailCallback(function()
                promise:reject()
            end)

            panel:popout()
        end, function()
            promise:reject()
        end)
    end, function()
        promise:reject()
    end)

    return promise
end

function PromotionEvent2025Manager:showProgressBonusPanel()
	local promise = deferred.new()

    local ProgressBonusPanelVM = require "amf.feature.promotionevent2025.view.panelvm.ProgressBonusPanelVM"
    local panel = ProgressBonusPanelVM:create()

    panel:setCloseCallback(function()
        promise:resolve()
    end)

    panel:setLoadResFailCallback(function()
        promise:reject()
    end)

    panel:popout()

    return promise
end

function PromotionEvent2025Manager:showRewardsPanel(exchangeShopData, periodConfig, dan)
    local promise = deferred.new()

    local exchangeShopManager = _G.amfBean("ExchangeShopManager")
    if not exchangeShopData then return promise:reject() end
    exchangeShopData.rewardDirectList = table.filter(exchangeShopData.rewardDirectList, function(v)
        return not exchangeShopManager:isShopItem(v.itemId)
    end)

    local titleNode = self:createTitleNode("恭喜获得", periodConfig, nil, dan):next(function(titleNode)
        exchangeShopManager:showRewardsPanel({
            panelType = 1,
            rewardList = exchangeShopData.rewardList,
            rewardDirectList = exchangeShopData.rewardDirectList,
            repeatList = exchangeShopData.repeatList,
            titleSprite = titleNode,
            buttonText = "收下",
            closeCallback = function()
                local pendingRewards = self._pendingPromotionCardPackList
                self._pendingPromotionCardPackList = {}
                _G.amfTransaction(TransactionEvent.COLLECT_CARD_FLOW, {
                    flowType = _G.COLLECT_CARD_FLOW_TYPE.OPEN_CARD,
                    rewards = pendingRewards,
                    onComplete = function()
                        promise:resolve()
                    end,
                    onError = function()
                        promise:resolve()
                    end
                })
            end
        })
    end, function()
        promise:reject()
    end)

    return promise
end

function PromotionEvent2025Manager:showGoldPanel(rewardNum,startPos,closeCallback)
    self:loadGlobalRes(false, false):next(function()
        local vm = require "amf.feature.promotionevent2025.view.panelvm.BoxRewardPanelVM"
        local panel = vm:create({
            rewardNum = rewardNum or 100,
            closeCallback = closeCallback,
            startPos = startPos
        })
        panel:popout(nil, true)
    end, function()
        if closeCallback then closeCallback() end
    end)
end

function PromotionEvent2025Manager:_collectPromotionCardPacks(rewardList)
    if not rewardList or #rewardList == 0 then return end
    for _, v in ipairs(rewardList) do
        table.insert(self._pendingPromotionCardPackList, table.clone(v))
    end
end

function PromotionEvent2025Manager:_hasPendingPromotionCardPacks()
    return not table.isEmpty(self._pendingPromotionCardPackList)
end

function PromotionEvent2025Manager:tryAutoPopPromotionCardPack()
    if not self:_hasPendingPromotionCardPacks() then return end

    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.PROMOTION_CARD_PACK_POP_STAGE4)
    end


    local creator = function()
        _G.amfBean("CollectCardManager"):skipThisRoundCardPackOpen()
        _G.amfTransaction(TransactionEvent.COLLECT_CARD_FLOW, {
            flowType = _G.COLLECT_CARD_FLOW_TYPE.OPEN_AND_SETTLE,
            rewards = self._pendingPromotionCardPackList,
            openAnimPanelConfig = {title = "晋级赛奖励"},
            onComplete = function()
                self._pendingPromotionCardPackList = {}
                onHandleOver()
            end,
            onError = function()
                self._pendingPromotionCardPackList = {}
                onHandleOver()
            end,
        })
    end

    self._autoPopupMgr:addPopupConfig(PopupCheckPoint.PROMOTION_CARD_PACK_POP_STAGE4, creator)
end

function PromotionEvent2025Manager:showRewardsBoxPanel(exchangeShopData, skinType, periodConfig, dan)
    local promise = deferred.new()

    local exchangeShopManager = _G.amfBean("ExchangeShopManager")
    if not exchangeShopData then return promise:reject() end
    exchangeShopData.rewardDirectList = table.filter(exchangeShopData.rewardDirectList, function(v)
        return not exchangeShopManager:isShopItem(v.itemId)
    end)

    local titleNode = self:createTitleNode("恭喜获得", periodConfig, nil, dan):next(function(titleNode)
        exchangeShopManager:showRewardsPanel({
            panelType = 2,
            boxType = 1,
            skinType = skinType,
            rewardList = exchangeShopData.rewardList,
            rewardDirectList = exchangeShopData.rewardDirectList,
            repeatList = exchangeShopData.repeatList,
            titleSprite = titleNode,
            buttonText = "收下",
            closeCallback = function()
                local pendingRewards = self._pendingPromotionCardPackList
                self._pendingPromotionCardPackList = {}
                _G.amfTransaction(TransactionEvent.COLLECT_CARD_FLOW, {
                    flowType = _G.COLLECT_CARD_FLOW_TYPE.OPEN_CARD,
                    rewards = pendingRewards,
                    onComplete = function()
                        promise:resolve()
                    end,
                    onError = function()
                        promise:resolve()
                    end
                })
            end
        })
    end, function()
        promise:reject()
    end)

    return promise
end

function PromotionEvent2025Manager:showDanChangePanel(oriPos, beforePanelVM, openParams)
    local promise = deferred.new()

    local DanChangePanelVM = require "amf.feature.promotionevent2025.view.panelvm.DanChangePanelVM"
    local panelVm = DanChangePanelVM.Builder.new()
        :setOriPos(oriPos)
        :setBeforePanelVM(beforePanelVM)
        :setOpenParams(openParams)
        :setCloseCallback(function()
            promise:resolve()
        end)
        :setLoadResFailCallback(function()
            promise:reject()
        end)
        :build()

    panelVm:popout(nil, true, nil, 0)

    return promise
end

function PromotionEvent2025Manager:showLastPeriodRankPanel(openParams)
    local promise = deferred.new()
    openParams = normalizeOpenParams(openParams)

    self:requestGetLastRankInfo():next(function(rankData)
        local lastMyInfo = table.find(rankData.rankList, function(v)
            return tostring(v.uid) == tostring(self._userManager:getUid())
        end)
        if lastMyInfo then
            local LastPeriodRankPanelVM = require "amf.feature.promotionevent2025.view.panelvm.LastPeriodRankPanelVM"
            local panelVm = LastPeriodRankPanelVM.Builder.new()
                :setCloseCallback(function()
                    promise:resolve()
                end)
                :setLoadResFailCallback(function()
                    promise:reject()
                end)
                :setLastRankData(rankData)
                :setOpenParams(openParams)
                :build()

            panelVm:popout()
        else
            if EnvUtil:isDevelopMode() then
                CommonTip:showTip("想结算但是榜里没自己，你是调数据了，还是清榜了，还是作弊被ban了？")
            end
            promise:reject()
        end
    end, function()
        promise:reject()
    end)

    return promise
end

function PromotionEvent2025Manager:showHonorRankPanel()
    local promise = deferred.new()

    local PlayerRankPanelVM = require "amf.feature.promotionevent2025.view.rank.PlayerRankPanelVM"
    local RankDataController = require "amf.middleware.ui.kit.panel.rank2026.RankDataController"
    local rankTabConfig = PromotionEvent2025Const.RankTabConfig
    local rType = {
        all = rankTabConfig[1].rankType,
        group = rankTabConfig[2].rankType,
        friend = rankTabConfig[3].rankType,
    }
    local tabRankTypes = {
        [1] = rType.all,
        [2] = rType.group,
        [3] = rType.friend,
    }
    local rankEndIndex = {
        [tabRankTypes[1]] = rankTabConfig[1].endIndex,
        [tabRankTypes[2]] = rankTabConfig[2].endIndex,
        [tabRankTypes[3]] = rankTabConfig[3].endIndex,
    }
    local fillEmptyConfig = {
        [tabRankTypes[1]] = {
            fillEmpty = true,
            maxNum = rankTabConfig[1].endIndex,
        },
        [tabRankTypes[2]] = {
            fillEmpty = true,
            maxNum = rankTabConfig[2].endIndex,
        },
        [tabRankTypes[3]] = {
            maxNum = rankTabConfig[3].endIndex,
        },
    }
    local tabTexts = {
        [1] = rankTabConfig[1].text,
        [2] = rankTabConfig[2].text,
        [3] = rankTabConfig[3].text,
    }

    local controller = RankDataController:create({
        mode = "custom",
        provider = function(rankType, options)
            return self:requestGetCurRankInfo(rankType, rankEndIndex[rankType] or options.endIndex):next(function(data)
                local profilesByUid = {}
                for _, profile in ipairs(data.profiles or {}) do
                    profilesByUid[tostring(profile.uid)] = profile
                end
                for _, rankInfo in ipairs(data.rankList or {}) do
                    local profile = profilesByUid[tostring(rankInfo.uid)]
                    if profile then
                        profile.score = rankInfo.score or 0
                    end
                end

                return data
            end)
        end,
        rType = rType,
        topShowNum = 0,
        getRealTimeSelfInfo = function()
            return {
                score = self:getScore(),
            }
        end,
    })
    controller.tabIndexToRankType = tabRankTypes
    controller.resetConfig = function(context)
        local config = fillEmptyConfig[context.curRankType] or {}
        context.curMaxNum = config.maxNum or 500
        context.fillEmpty = config.fillEmpty
    end

    local rankPanelVM = PlayerRankPanelVM:create(controller, {
        title = "闯关晋级赛排行",
        tabMode = "THREE",
        defaultTab = 1,
        tabTexts = tabTexts,
        regionText = self:getLocationDisplayName(),
        regionTabIndex = 2,
        scoreFullDisplay = true,
        noAwardBox = true,
    })

    rankPanelVM:setScoreIconFactory(function()
        return self:getCollectionIcon()
    end, true)
    rankPanelVM:setAvatarTapCallback(function(profile)
        self:showHistoryPanel(3, profile)
    end)

    rankPanelVM:setCloseCallback(function() promise:resolve() end)
    rankPanelVM:setLoadResFailCallback(function() promise:reject() end)

    rankPanelVM:popout()

    return promise
end

function PromotionEvent2025Manager:getLocationDisplayName()
    local code = self:getLocation()
    local str = TextUtil.UnknownRegionName
    if code and tonumber(code) == 900000 then
        str = "钓鱼岛"
    elseif code and tonumber(code) > 0 then
        local province, city = LocationDataConfig:getAddressByAdCodeShort(code, 10)
        str = tostring(province or "") .. tostring(city or "")
    end
    return str ~= "" and str or TextUtil.UnknownRegionName
end

function PromotionEvent2025Manager:showLocationPanel()
    local promise = deferred.new()

    local LocationPanelVM = require "amf.feature.promotionevent2025.view.panelvm.LocationPanelVM"
    local panelVm = LocationPanelVM.Builder.new()
        :setCloseCallback(function()
            promise:resolve()
        end)
        :setLoadResFailCallback(function()
            promise:reject()
        end)
        :build()

    panelVm:popout()

    return promise
end

function PromotionEvent2025Manager:showDescPanel()
    local promise = deferred.new()

    self:loadRes(true, {"amf/promotionevent2025/ui/descpanel/texture/DescPanel.plist"}):next(function()
        local uiData = require "amf.feature.promotionevent2025.view.uisource.DescPanel_UI"
        local builder = UIBuilder.new(uiData)

        local periodConfig = self:getCurPeriodConfig()
        local animalStr = (periodConfig.taskType == PromotionEvent2025Const.TaskType.kLine) and "chicken" or "fox"

        local prex = "Star"
        if self._userStateManager:isFMJ() then
            prex = "NotFull"
        elseif self._userStateManager:isColorfulStarFull() then
            prex = "Full"
        end

        local page1_prex = animalStr .. prex
        local page2_prex = animalStr .. "2"
        local page1 = builder:createChild(page1_prex)
        local page2 = builder:createChild(page2_prex)

        local IllustrationPanelVM = require "amf.middleware.ui.kit.panel.other.IllustrationPanelVM"

        local vm = IllustrationPanelVM.Builder.new()
            :setTitle("")
            :setPages({page1, page2})
            :setPageAnimNodeNames({
                {
                    -- page1_prex.."_A__shadowTitleEff",
                    page1_prex.."_png_1",
                    page1_prex.."_to1",
                    page1_prex.."_png_2",
                    page1_prex.."_to2",
                    page1_prex.."_png_3"
                },
                {
                    -- page2_prex.."_A__shadowTitleEff",
                    page2_prex.."_png_1",
                    page2_prex.."_to1",
                    page2_prex.."_png_2",
                    page2_prex.."_to2",
                    page2_prex.."_png_3",
                    page2_prex.."_png_4"
                },
            })
            :setAnimTime(0.2)
            :setPageBtnsVisible(true)
            :setCloseCallback(function()
                self:unloadRes({"amf/promotionevent2025/ui/descpanel/texture/DescPanel.plist"})
                promise:resolve()
            end)
            :setPanelReadyCallback(function()
                LayoutUtil:move(page1, -5, 63)
                LayoutUtil:move(page2, 35, 0)
            end)
            :build()

        vm:popout()
    end, function()
        promise:reject()
    end)

    return promise
end

----------------------- 通用.工具 ---------------------

-- 恭喜获得用标题
function PromotionEvent2025Manager:createTitleNode(titleStr, periodConfig, ignoreBadge, dan)
    local promise = deferred.new()

    periodConfig = periodConfig or self:getCurPeriodConfig()
    local taskType = periodConfig.taskType
    local res, outlineColor
    if periodConfig.taskType == PromotionEvent2025Const.TaskType.kAnimal then
        res = "amf/promotionevent2025/common/title_1.png"
        outlineColor = hex2ccc4("AE4435FF")
    elseif periodConfig.taskType == PromotionEvent2025Const.TaskType.kLine then
        res = "amf/promotionevent2025/common/title_2.png"
        outlineColor = hex2ccc4("6858ABFF")
    end

    self:loadRes(true, {res}):next(function()

        local root = Layer:create()

        if not ignoreBadge then
            local dan = dan or self:getDan()
            local danIcon = self:createDanIcon(dan)
            danIcon:setPositionXY(0, 132)
            root:addChild(danIcon)
        end

        local titleNode1 = UICreateUtil:createSpriteFile(res)
        titleNode1:setAnchorPoint(ccp(0,0.5))
        root:addChild(titleNode1)
        local titleNode2 = UICreateUtil:createSpriteFile(res)
        titleNode2:setAnchorPoint(ccp(0,0.5))
        titleNode2:setScaleX(-1)
        root:addChild(titleNode2)

        local titleLabel = TTFLabel:createHKHB(titleStr or "", 70)
        titleLabel:setTextColor(hex2ccc4("FFFFFFFF"))
        titleLabel:setGradientColors(hex2ccc4("FEFB4DFF"), hex2ccc4("FEB615FF"))
        titleLabel:enableOutline(outlineColor, 3)
        titleLabel:enableShadow(outlineColor, ccp(0, -2), 2)
        root:addChild(titleLabel)
        titleLabel:setAnchorPoint(ccp(0.5,0.5))
        titleLabel:setPositionY(24)

        -- root:makeContentSizeContainChildren()
        root:ignoreAnchorPointForPosition(false)
        root:setAnchorPoint(ccp(0.5,0.5))

        promise:resolve(root)
    end, function()
        promise:reject()
    end)

    return promise
end

function PromotionEvent2025Manager:createIcon(reward, needNum, boxIcon)
    local reward = table.clone(reward)
    reward.needNum = needNum
    local icon = nil

    if boxIcon then
        if not self._isResLoadReady then
            icon = Sprite:createEmpty()
        else
            icon = UICreateUtil:createSpriteFile("amf/promotionevent2025/icon/randomBox.png", true)
        end
    elseif reward.isWelfareFragment then --碎片福利期
        icon = _G.GameItemCreator:getPropIcon(reward)

        local labelBg = Scale9Sprite:createWithSpriteFrameName("promotionevent2025/pink_bg", CCRectMake(30, 0, 12, 22))
        labelBg:setContentSize(CCSizeMake(84, 22))
        labelBg:setPositionXY(68, -10)
        labelBg:setAnchorPoint(ccp(0.5, 0.5))
        labelBg:setScale(1.2)
        icon:addChild(labelBg)

        local timeLabel = TTFLabel:createAnimalYH("剩余时间", 14)
        timeLabel:enableOutline(hex2ccc4("C91B79FF"), 2)
        timeLabel:setPositionXY(42, 11)
        timeLabel:setAnchorPoint(ccp(0.5, 0.5))
        labelBg:addChild(timeLabel)

        local welfareInfo = self:getFragmentWelfareInfo()
        TimeUtil:countDownLabel(timeLabel, math.floor(welfareInfo.endTime/1000))
    elseif reward.itemId == AMFPropId.GOLD and reward.num == 100 then
        icon = Layer:create()
        icon:setContentSize(CCSizeMake(126, 126))
        icon:ignoreAnchorPointForPosition(false)
        icon:setAnchorPoint(ccp(0.5, 0.5))

        local realIcon = Sprite:createWithSpriteFrameName("promotionevent2025/gold_box")
        realIcon:setScale(1.2)
        realIcon:setPositionXY(63, 63)
        icon:addChild(realIcon)

        if needNum then
            local numWidget = AMFCompHelper:createPropNum(reward)
            icon:addChild(numWidget)
        end
    else
        icon = _G.GameItemCreator:getPropIcon(reward)
    end

    return icon
end

function PromotionEvent2025Manager:createBuffIcon(itemType)
    local itemId = PromotionEvent2025Const.PEItemList[itemType].itemId
    local icon

    lua_switch(itemType){
        [PromotionEvent2025Const.PEItemType.kCoin50] = function ()
            icon = self:createIcon({itemId = UPropId.COIN, num = 0}, false)
            local sign = AMFCompHelper:createLabelSign(AMFCompHelper.labelSign.kGainSign)
            sign:setNum(50)
            icon:addChild(sign)
            sign:setPositionXY(65, 106)
        end,
        [PromotionEvent2025Const.PEItemType.kScore10] = function ()
            icon = Sprite:createWithSpriteFrameName("promotionevent2025/" .. itemId)
            local sign = AMFCompHelper:createLabelSign(AMFCompHelper.labelSign.kGainSign)
            sign:setNum(10)
            icon:addChild(sign)
            sign:setPositionXY(65, 106)
        end,
        [PromotionEvent2025Const.PEItemType.kCollect100] = function ()
            icon = self:getCollectionIcon()
            local sign = AMFCompHelper:createLabelSign(AMFCompHelper.labelSign.kDoubleSign)
            icon:addChild(sign)
            sign:setPositionXY(90, 100)
            sign:setScale(0.5)
        end,
        [PromotionEvent2025Const.PEItemType.kCoin100] = function ()
            icon = self:createIcon({itemId = UPropId.COIN, num = 0}, false)
            local sign = AMFCompHelper:createLabelSign(AMFCompHelper.labelSign.kDoubleSign)
            icon:addChild(sign)
            sign:setPositionXY(90, 100)
            sign:setScale(0.5)
        end,
    }

    return icon
end

local COLLECTION_ICON_FRAME_NAMES = {
    [PromotionEvent2025Const.TaskType.kLine] = "common/icon_256/icon_xinjinjisai",
    [PromotionEvent2025Const.TaskType.kAnimal] = "common/icon_256/icon_xinjinjisai02",
}

local function getCollectionIconFrameName(periodConfig)
    return COLLECTION_ICON_FRAME_NAMES[periodConfig and periodConfig.taskType]
end

local function createLegacySizedCollectionIcon(frameName)
    local sprite = Sprite:createWithSpriteFrameName(frameName)
    local legacySize = PropConst.IconScale.LEGACY_SIZE
    local size = sprite:getContentSize()
    if not size or size.width <= legacySize then
        return sprite
    end

    local icon = Sprite:createEmpty()
    icon:setContentSize(CCSizeMake(legacySize, legacySize))
    icon:ignoreAnchorPointForPosition(false)
    icon:setAnchorPoint(ccp(0.5, 0.5))

    PropConst.applyIconScale(sprite)
    sprite:setAnchorPoint(ccp(0.5, 0.5))
    sprite:setPosition(ccp(legacySize / 2, legacySize / 2))
    icon:addChild(sprite)
    return icon
end

-- 上一期收集物配置，用于结算等展示上一期数据的面板
-- 优先取服务端 lastPeriodCollectionType，其次按 lastPeriod 反查 periods 配置
function PromotionEvent2025Manager:getLastPeriodConfig()
    local taskType = tonumber(self:getDataValue("lastPeriodCollectionType")) or 0
    if taskType == PromotionEvent2025Const.TaskType.kLine
        or taskType == PromotionEvent2025Const.TaskType.kAnimal then
        return { taskType = taskType }
    end

    local lastPeriod = tonumber(self:getDataValue("lastPeriod")) or 0
    if lastPeriod > 0 then
        local periods = self:getConfig("periods")
        for _, periodConfig in pairs(periods or {}) do
            if tonumber(periodConfig.period) == lastPeriod then
                return periodConfig
            end
        end
    end

    return nil
end

-- 本赛季收集物的icon
function PromotionEvent2025Manager:getCollectionIcon(withBuffTime, periodConfig)
    periodConfig = periodConfig or self:getCurPeriodConfig()
    local frameName = getCollectionIconFrameName(periodConfig) or "other/button/ui_button_bangzhu"
    local icon = createLegacySizedCollectionIcon(frameName)

    if withBuffTime and self:getCollectionBuffEndTime() > TimeKit:timeInSec() then
        local sign = AMFCompHelper:createLabelSign(AMFCompHelper.labelSign.kDoubleSign)
        icon:addChild(sign)
        sign:setPositionXY(90, 100)
        sign:setScale(0.6)

        local expireTime = self:getCollectionBuffEndTime()
        local timePlug
        timePlug = AMFCompHelper:createInfiniteTimeLimitWidget({expireTime = expireTime}, true, true, function()
            if timePlug and not timePlug.isDisposed then
                timePlug:removeFromParentAndCleanup(true)
                timePlug = nil
            end
            if sign and not sign.isDisposed then
                sign:removeFromParentAndCleanup(true)
                sign = nil
            end
        end)
        if timePlug then
            icon:addChild(timePlug)
            timePlug:setPositionXY(63, 15)
        end
    end

    return icon
end

-- 本赛季收集物的icon
function PromotionEvent2025Manager:getCollectionIconInfo(periodConfig)
    periodConfig = periodConfig or self:getCurPeriodConfig()
    local frameName = getCollectionIconFrameName(periodConfig) or "other/button/ui_button_bangzhu"
    local isDouble = false
    local expireTime = nil
    if self:getCollectionBuffEndTime() > TimeKit:timeInSec() then
        local sign = AMFCompHelper:createLabelSign(AMFCompHelper.labelSign.kDoubleSign)
        isDouble = true
        expireTime = self:getCollectionBuffEndTime()
    end

    return frameName,isDouble,expireTime
end

-- 静态的徽章图
function PromotionEvent2025Manager:createDanIcon(dan, size)
    local frameName = "promotionevent2025/LV" .. tonumber(dan)
    local icon = Sprite:createWithSpriteFrameName(frameName)
	if size then icon:setSize(size) end

    return icon
end

function PromotionEvent2025Manager:createDanSign(dan)
    local uiData = require 'amf.feature.promotionevent2025.view.uisource.dan_sign_UI'
    local danSign, signCls = UIBuilder:buildUI(uiData)
    local signNode = signCls["level"..dan.."Sign"]
    signNode:removeFromParentAndCleanup(false)
    danSign:dispose()
    return signNode
end

function PromotionEvent2025Manager:doChain(promise)
    return function() promise:resolve() end, function() promise:reject() end
end

function PromotionEvent2025Manager:getRankDataBetween(beginIndex, endIndex)
    local dataList = {}
	local groupRankData = self:getDataValue("groupRankInfo")
	local rankList = self:handleRankData(groupRankData, true)

	for i,v in ipairs(rankList) do
		v.rank = i
	end

	for i = beginIndex, endIndex do
		if rankList[i] then
			table.insert(dataList,rankList[i])
		else
			break
		end
	end

	return dataList
end

---------------------- 协议封装 ---------------------
function PromotionEvent2025Manager:requestGetMainInfo(isLight)
    local promise = deferred.new()
    local param = {lightStart = isLight, loading = not isLight}

    self._model:requestGetMainInfo(param):next(function(response)
        self:updateIcon()
        self:updateMainSceneRewardBanner()
        local data = response:getData()
        if not isLight and (data.errorCode and data.errorCode ~= "" and tonumber(data.errorCode) ~= 0) then
            CommonTip:showErrorTip(data.errorCode)
            promise:reject()
        else
            promise:resolve()
        end
    end, function(response)
        if not response:isCancel() and not isLight then
            CommonTip:showErrorTip(response)
        end
        promise:reject()
    end)

    return promise
end


function PromotionEvent2025Manager:buildRewardExtra(isUseSpecialRewards, rewardIds)
    local extra = {
        useSpecialRewards = isUseSpecialRewards,
    }

    if rewardIds then
        extra.rewardIds = rewardIds
    end

    return table.serialize(extra)
end

function PromotionEvent2025Manager:requestGetRewardsAuto(curTaskInfo, updateBannerAnimate)
    if not curTaskInfo then return deferred.new():reject() end
    if updateBannerAnimate == nil then
        updateBannerAnimate = true
    end

    local shareRewardKeyIndex = nil
    if curTaskInfo.isLast then
        shareRewardKeyIndex = 1
    end
    local isUseSpecialRewards = curTaskInfo.useSpecialRewards == true
    local params = {
        period = self:getDataValue("curPeriod"),
        rewardType = PromotionEvent2025Const.RewardType.kFinishTask,
        rewardId = tonumber(curTaskInfo.taskBaseId) * 1000 + curTaskInfo.curTaskIndex,
        extra = self:buildRewardExtra(isUseSpecialRewards),
        shareRewardKeyIndex = shareRewardKeyIndex,
    }

    local promise = deferred.new()

    local function packPromise()
        return function(response)
            local data = response:getData()
            _G.amfBean("ExchangeShopManager"):processEvent({
                rewardDirectList = data.rewardList,
                evt = response,
                endCall = function(callData)
                    self:_collectPromotionCardPacks(data.rewardList)
                    promise:resolve(callData)
                end
            })
            self:updateIcon()
            if updateBannerAnimate then
                self:updateMainSceneRewardBanner(true)
            end
        end, function(response)
            if not response:isCancel() then
                CommonTip:showErrorTip(response)
            end
            promise:reject(response)
        end
    end

    if curTaskInfo.online then
        self._model:requestGetRewardsOnline(params, curTaskInfo):next(packPromise())
    else
        self._model:requestGetRewardsOffline(params, curTaskInfo):next(packPromise())
    end

    return promise
end

function PromotionEvent2025Manager:requestGetRewardsAll()
    local taskIdList, leftCollectionNum, dataList, lastIndex = self:getCanRewardsTaskDataForAll()
    local extraStr, getNum = '', 0
    local shareRewardKeyIndex = nil
    for k,v in ipairs(dataList) do
        taskIdList[k] = tonumber(v.taskBaseId) * 1000 + v.curTaskIndex
        extraStr = extraStr .. taskIdList[k]
        getNum = getNum + 1
        if k ~= #dataList then
            extraStr = extraStr .. ','
        end
        if v.curTaskIndex == lastIndex then
            shareRewardKeyIndex = 1
        end
    end

    local firstTaskInfo = dataList[1]
    local isUseSpecialRewards = firstTaskInfo and firstTaskInfo.useSpecialRewards == true
    local params = {
        period = self:getDataValue("curPeriod"),
        rewardType = PromotionEvent2025Const.RewardType.kFinishTasks,
        leftCollectionNum = leftCollectionNum,
        extra = self:buildRewardExtra(isUseSpecialRewards, extraStr),
        shareRewardKeyIndex = shareRewardKeyIndex,
    }

    local promise = deferred.new()

    self._model:requestGetRewardsOnline(params, dataList[#dataList]):next(function(response)
        local data = response:getData()
        _G.amfBean("ExchangeShopManager"):processEvent({
            rewardDirectList = data.rewardList,
            evt = response,
            endCall = function(callData)
                self:_collectPromotionCardPacks(data.rewardList)
                promise:resolve(callData)
            end
        })

        PromotionEvent2025DC:reward_progress(3, getNum, self:getCompleteTaskIndex())
        self:updateMainSceneRewardBanner(true)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        promise:reject(response)
    end)

    return promise
end

function PromotionEvent2025Manager:requestGetRewardsLastRank()
    local params = {
    	period = self._model:getLastPeriod(),
    	rewardType = PromotionEvent2025Const.RewardType.kRankRward,
    }

    local promise = deferred.new()

    self._model:requestGetRewardsOnline(params):next(function(response)
        local data = response:getData()
        _G.amfBean("ExchangeShopManager"):processEvent({
            rewardDirectList = data.rewardList,
            evt = response,
            endCall = function(callData)
                self:_collectPromotionCardPacks(data.rewardList)
                promise:resolve(callData)
            end
        })
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        promise:reject(response)
    end)

    return promise
end

function PromotionEvent2025Manager:requestConfirmResultLastPeriod()
    local params = {
        period = self._model:getLastPeriod(),
    	rewardType = PromotionEvent2025Const.RewardType.kConfirmResult,
    }

    local promise = deferred.new()

    self._model:requestGetRewardsOnline(params):next(function(response)
        self:updateIcon()
        promise:resolve()
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        promise:reject(response)
    end)

    return promise
end

function PromotionEvent2025Manager:requestGetHistory(targetXxlId)
    local params = {
        period = self:getDataValue("curPeriod"),
        targetXxlId = targetXxlId or 0,
    }

    local promise = deferred.new()

    self._model:requestGetHistory(params):next(function(response)
        local data = response:getData()
        promise:resolve(data)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        promise:reject(response)
    end)

    return promise
end

function PromotionEvent2025Manager:requestGetCurGroupInfo()
    local params = {
        period = self:getDataValue("curPeriod"),
        protocolVersion = PromotionEvent2025Const.MainInfoVersion,
    }

    local promise = deferred.new()

    self._model:requestGetCurGroupInfo(params):next(function(response)
        self:updateIcon()
        local data = response:getData()
        promise:resolve(data)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        promise:reject(response)
    end)

    return promise
end

function PromotionEvent2025Manager:requestGetLastRankInfo()
    local params = {
        requestPeriod = self:getDataValue("lastPeriod"),
        rankType = 1,
        startIndex = 1,
        endIndex = 100,
        shareRewardKeyIndex = 0,
    }

    local promise = deferred.new()

    self._model:requestGetRankInfo(params):next(function(response)
        local data = response:getData()
        promise:resolve(data)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        promise:reject(response)
    end)

    return promise
end

function PromotionEvent2025Manager:requestGetCurRankInfo(rankType, endIndex)
    local params = {
        requestPeriod = self:getPeriod(),
        rankType = rankType or 1,
        startIndex = 1,
        endIndex = endIndex or 100,
    }

    local promise = deferred.new()

    self._model:requestGetRankInfo(params):next(function(response)
        self:updateIcon()
        local data = response:getData()
        promise:resolve(data)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        promise:reject(response)
    end)

    return promise
end

function PromotionEvent2025Manager:requestSetLocation(locationId)
    if not locationId then return deferred.error() end

    local params = {
        period = self:getDataValue("curPeriod"),
        rewardType = PromotionEvent2025Const.RewardType.kSetLocation,
        rewardId = tostring(locationId),
    }

    local promise = deferred.new()

    self._model:requestGetRewardsOnline(params):next(function(response)
        local data = response:getData()
        promise:resolve()
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        promise:reject(response)
    end)

    return promise
end

function PromotionEvent2025Manager:requestShareReward(shareRewardBean)
    if not shareRewardBean then return deferred.error() end

    local promise = deferred.new()

    local params = {
        shareRewardKey = shareRewardBean.key,
        day = shareRewardBean.day,
    }

    self._model:requestGetShareRewards(params):next(function(response)
        local data = response:getData()
        promise:resolve(data.shareRewardBean.shareRewardItemList)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        promise:reject(response)
    end)

    return promise
end

function PromotionEvent2025Manager:requestRequestFriend(xxlId)
    local promise = deferred.new()

    local params = {
        inviteCode = xxlId,
        type = FriendConst.addFriendSource.ACTIVITY,
    }

    self._model:requestRequestFriend(params):next(function(response)
        local data = response:getData()
        promise:resolve(data)
    end, function(response)
        if not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        promise:reject(response)
    end)

    return promise
end

----------------------- icon ---------------------
function PromotionEvent2025Manager:isV2IconExperimentEnabled()
    local ok, enabled = pcall(function()
        local experiment = require(ICON_V2_EXPERIMENT_MODULE)
        return experiment:isEnabled()
    end)
    return ok and enabled == true
end

function PromotionEvent2025Manager:createLegacyMainSceneIcon()
    local PromotionEvent2025Icon = require "amf.feature.promotionevent2025.view.icon.PromotionEvent2025Icon"
    return PromotionEvent2025Icon:create()
end

function PromotionEvent2025Manager:createPackageIconAdapter()
    local adapterLoaded, PackageIconV2Adapter = pcall(require, ICON_V2_ADAPTER_MODULE)
    if not adapterLoaded then
        return {
            state = ADAPTER_CREATE_SAFE_LEGACY,
            error = PackageIconV2Adapter,
        }
    end
    if type(PackageIconV2Adapter.create) ~= "function" then
        return {
            state = ADAPTER_CREATE_SAFE_LEGACY,
            error = "PROMOTION_EVENT_2025_ICON_V2_ADAPTER_CREATE_REQUIRED",
        }
    end

    local ownerIconKey = PromotionEvent2025Const.actKey
    local configOk, options, provider = pcall(function()
        local IconV2Config = require "amf.feature.promotionevent2025.icon.IconV2Config"
        local configOptions, configProvider = IconV2Config.create(self, IconEventCenter)
        assert(type(configOptions) == "table", configProvider or "PROMOTION_EVENT_2025_ICON_V2_CONFIG_REQUIRED")
        return configOptions, configProvider
    end)
    if not configOk then
        local configError = options
        options = {
            ownerIconKey = ownerIconKey,
            iconEventCenter = IconEventCenter,
            legacyFactory = function()
                return self:createLegacyMainSceneIcon()
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
        provider = modeOrError == "v2" and provider or nil,
        mode = modeOrError,
    }
end

function PromotionEvent2025Manager:_adoptIconAdapter(adapter, provider, recoveryPending)
    self._iconAdapter = adapter
    local adapterState, stateError = resolveAdapterState(adapter)
    local icon, iconError = getAdapterIcon(adapter)
    self._iconDataProvider = adapterState == ADAPTER_STATE_V2 and provider or nil
    self._iconAdapterRecoveryPending = recoveryPending == true
        or adapterState == ADAPTER_STATE_CLEANUP
        or adapterState == ADAPTER_STATE_BLOCKED
        or iconError ~= nil
    if stateError then
        logIconV2Error("adapter state failed: " .. tostring(stateError))
    end
    if iconError then
        logIconV2Error("adapter icon failed: " .. tostring(iconError))
    end
    return icon, adapterState
end

function PromotionEvent2025Manager:_disposeIconAdapter(reason)
    local adapter = self._iconAdapter
    if not adapter then
        return self._iconAdapterRecoveryPending ~= true
    end
    local disposed, disposeError = disposeAdapter(adapter)
    if not disposed then
        self._iconAdapterRecoveryPending = true
        logIconV2Error(
            "dispose failed reason=" .. tostring(reason) .. " error=" .. tostring(disposeError)
        )
        return false, disposeError
    end
    self._iconAdapter = nil
    self._iconDataProvider = nil
    self._iconAdapterRecoveryPending = false
    return true
end

function PromotionEvent2025Manager:_recoverPendingIconAdapter()
    if not self._iconAdapterRecoveryPending then
        return true, self._iconAdapter ~= nil
    end
    if self._iconAdapter then
        local disposed, disposeError = self:_disposeIconAdapter("recovery")
        return disposed, false, disposeError
    end

    local createResult = self:createPackageIconAdapter()
    local ownerAdapter = createResult.adapter or createResult.cleanupOwner
    if ownerAdapter then
        self:_adoptIconAdapter(
            ownerAdapter,
            createResult.provider,
            createResult.state == ADAPTER_CREATE_WAIT_OWNER
        )
        if createResult.state == ADAPTER_CREATE_READY and not self._iconAdapterRecoveryPending then
            return true, true
        end
        self._iconAdapterRecoveryPending = true
        logIconV2Error("owner recovery pending cleanup: " .. tostring(createResult.error))
        return false, false, createResult.error
    end

    self._iconAdapterRecoveryPending = true
    logIconV2Error("owner recovery still pending: " .. tostring(createResult.error))
    return false, false, createResult.error
end

function PromotionEvent2025Manager:_releaseIconAdapter(reason)
    if self._iconAdapter then
        return self:_disposeIconAdapter(reason)
    end
    if not self._iconAdapterRecoveryPending then
        return true
    end

    local recovered, hasAdapter, recoveryError = self:_recoverPendingIconAdapter()
    if not recovered then
        return false, recoveryError
    end
    if hasAdapter and self._iconAdapter then
        return self:_disposeIconAdapter(reason)
    end
    return true
end

function PromotionEvent2025Manager:_isAdapterIconCurrent()
    local icon, iconError = getAdapterIcon(self._iconAdapter)
    if iconError then
        return nil, iconError, nil, true
    end
    if not icon or icon.isDisposed == true then
        return false, nil, icon
    end
    if not self._iconManager or type(self._iconManager.getIconByIconKey) ~= "function" then
        return nil, "PROMOTION_EVENT_2025_ICON_MANAGER_GET_REQUIRED", icon, false
    end
    local ok, managedIcon = pcall(
        self._iconManager.getIconByIconKey,
        self._iconManager,
        PromotionEvent2025Const.actKey
    )
    if not ok then
        return nil, managedIcon, icon, false
    end
    return managedIcon == icon, nil, icon
end

function PromotionEvent2025Manager:isV2IconActive()
    local adapterState, stateError = resolveAdapterState(self._iconAdapter)
    if adapterState == ADAPTER_STATE_CLEANUP or adapterState == ADAPTER_STATE_BLOCKED then
        self._iconAdapterRecoveryPending = true
    end
    if stateError then
        logIconV2Error("adapter active state failed: " .. tostring(stateError))
    end
    return adapterState == ADAPTER_STATE_V2
end

function PromotionEvent2025Manager:getIconV2Snapshot()
    local phase = "closed"
    local phaseStartTime = 0
    local phaseEndTime = 0
    local phaseText = PromotionEvent2025Const.ActShowName
    local period = tonumber(self:getPeriod()) or 0

    if self:isPreHeat() then
        phase = "preheat"
        phaseEndTime = tonumber(self:getPreHeatEndTime()) or 0
        phaseStartTime = math.max(0, phaseEndTime - 4 * 24 * 3600)
    elseif self:isOpen() then
        phase = "open"
        phaseStartTime = tonumber(self:getPeriodBeginTime()) or 0
        phaseEndTime = tonumber(self:getPeriodEndTime()) or 0
    elseif self:isRest() then
        phase = "rest"
        local previousPeriod = tonumber(self:getDataValue("lastPeriod"))
        if not previousPeriod or previousPeriod <= 0 then
            previousPeriod = tonumber(self:getDataValue("curPeriod"))
        end
        local periods = self:getConfig("periods")
        if type(periods) == "table" then
            for _, periodConfig in pairs(periods) do
                if tonumber(periodConfig.period) == previousPeriod then
                    phaseStartTime = math.floor((tonumber(periodConfig.endTs) or 0) / 1000)
                    break
                end
            end
        end
        phaseEndTime = tonumber(self:getRestEndTime()) or 0
        phaseText = "待结算"
    end

    local rank = phase == "open" and (tonumber(self:getRank()) or 0) or 0
    local cycleIdentity
    local cyclePeriod = phase == "open" and period or 0
    if cyclePeriod <= 0 and phaseEndTime > 0 then
        local periods = self:getConfig("periods") or {}
        for _, periodConfig in pairs(periods) do
            local beginTime = math.floor((tonumber(periodConfig.beginTs) or 0) / 1000)
            if beginTime == phaseEndTime then
                cyclePeriod = tonumber(periodConfig.period) or 0
                break
            end
        end
    end
    if cyclePeriod > 0 then
        cycleIdentity = "period:" .. tostring(cyclePeriod)
    elseif phaseEndTime > 0 then
        cycleIdentity = "begin:" .. tostring(phaseEndTime)
    end

    local hasHistoryRankReward = self:needHistoryRankReward() == true
    local dan = tonumber(self:getDan()) or 1
    if hasHistoryRankReward then
        dan = dan - (tonumber(self:getLastDanDiff()) or 0)
        rank = 0
    end

    local rewardVisible = self:canGetReward() == true or hasHistoryRankReward
    local rewardPresentationKey
    if hasHistoryRankReward then
        rewardPresentationKey = "history-rank:" .. tostring(self:getDataValue("lastPeriod") or 0)
    elseif rewardVisible then
        rewardPresentationKey = "progress:" .. tostring(period)
            .. ":" .. tostring(self:getCompleteTaskIndex() or 0)
    end

    return {
        phase = phase,
        phaseStartTime = phaseStartTime,
        phaseEndTime = phaseEndTime,
        phaseText = phaseText,
        historySettlementPending = hasHistoryRankReward,
        cycleKey = cycleIdentity and ("promotionevent2025:" .. cycleIdentity) or nil,
        dan = dan,
        rank = rank,
        showPromotionArrow = false,
        rewardVisible = rewardVisible,
        rewardPresentationKey = rewardPresentationKey,
    }
end

function PromotionEvent2025Manager:createMainSceneIcon()
    if not self:isDataEnabled() then
        if self._iconAdapter or self._iconAdapterRecoveryPending then
            return self:_releaseIconAdapter("create_data_disabled")
        end
        return
    end

    local function doCreate()
        if not self:isDataEnabled() then
            if self._iconAdapter or self._iconAdapterRecoveryPending then
                return self:_releaseIconAdapter("create_data_disabled_after_load")
            end
            return
        end
        if not self:isIconCanShow() and (self._iconAdapter or self._iconAdapterRecoveryPending) then
            return self:_releaseIconAdapter("create_not_visible_after_load")
        end

        local recovered, _, recoveryError = self:_recoverPendingIconAdapter()
        if not recovered then
            return false, recoveryError
        end

        if self._iconAdapter then
            local adapterState, stateError = resolveAdapterState(self._iconAdapter)
            if adapterState == ADAPTER_STATE_V2 or adapterState == ADAPTER_STATE_LEGACY then
                local current, currentError, _, ownerBlocked = self:_isAdapterIconCurrent()
                if current == true then
                    return true
                end
                if current == nil then
                    if ownerBlocked then
                        self._iconAdapterRecoveryPending = true
                    end
                    logIconV2Error("adapter icon check failed: " .. tostring(currentError))
                    return false, currentError
                end
            elseif stateError then
                logIconV2Error("adapter state failed before recreate: " .. tostring(stateError))
            end
            local disposed, disposeError = self:_disposeIconAdapter("recreate")
            if not disposed then
                return false, disposeError
            end
        end

        local icon = self._iconManager:getIconByIconKey(PromotionEvent2025Const.actKey)
        if icon then return true end

        local useV2Icon = self:isV2IconExperimentEnabled()
        if useV2Icon and not self:isIconCanShow() then
            return
        end
        if useV2Icon then
            local createResult = self:createPackageIconAdapter()
            local ownerAdapter = createResult.adapter or createResult.cleanupOwner
            if ownerAdapter then
                self:_adoptIconAdapter(
                    ownerAdapter,
                    createResult.provider,
                    createResult.state == ADAPTER_CREATE_WAIT_OWNER
                )
            end
            if createResult.state == ADAPTER_CREATE_READY
                and createResult.adapter
                and not self._iconAdapterRecoveryPending then
                PromotionEvent2025DC:feature_enable(self:getDan(), self:getRank())
                return true
            end
            if createResult.state == ADAPTER_CREATE_READY then
                self._iconAdapterRecoveryPending = true
                logIconV2Error("created adapter requires owner recovery")
                return false, "PROMOTION_EVENT_2025_ICON_V2_ADAPTER_RECOVERY_REQUIRED"
            end
            if createResult.state == ADAPTER_CREATE_WAIT_OWNER then
                self._iconAdapterRecoveryPending = true
                logIconV2Error("create waiting for owner recovery: " .. tostring(createResult.error))
                return false, createResult.error
            end
            self._iconAdapterRecoveryPending = false
            logIconV2Error("adapter unavailable, fallback legacy: " .. tostring(createResult.error))
        end

        local icon = self:createLegacyMainSceneIcon()
        IconEventCenter:addIconEvent(icon)

        PromotionEvent2025DC:feature_enable(self:getDan(), self:getRank())
        return true
    end

    if not self:isGlobalResEnabled() then
        self:loadGlobalRes(true, true):next(doCreate)
    else
        doCreate()
    end
end

function PromotionEvent2025Manager:updateIcon(reason)
    if (self._iconAdapter or self._iconAdapterRecoveryPending)
        and (not self:isDataEnabled() or not self:isIconCanShow()) then
        return self:_releaseIconAdapter("activity_not_visible")
    end

    local recovered, _, recoveryError = self:_recoverPendingIconAdapter()
    if not recovered then
        return false, recoveryError
    end

    if self._iconAdapter then
        local adapterState, stateError = resolveAdapterState(self._iconAdapter)
        if adapterState ~= ADAPTER_STATE_V2 and adapterState ~= ADAPTER_STATE_LEGACY then
            self._iconAdapterRecoveryPending = true
            if stateError then
                logIconV2Error("adapter state failed before update: " .. tostring(stateError))
            end
            local cleanupRecovered, _, cleanupError = self:_recoverPendingIconAdapter()
            if not cleanupRecovered then
                return false, cleanupError
            end
            return self:createMainSceneIcon()
        end

        local current, currentError, adapterIcon, ownerBlocked = self:_isAdapterIconCurrent()
        if current == nil then
            if ownerBlocked then
                self._iconAdapterRecoveryPending = true
            end
            logIconV2Error("adapter icon check failed during update: " .. tostring(currentError))
            return false, currentError
        end
        if current == false then
            local disposed, disposeError = self:_disposeIconAdapter("external_remove")
            if not disposed then
                return false, disposeError
            end
            return self:createMainSceneIcon()
        end

        if adapterState == ADAPTER_STATE_V2 then
            local refreshed, refreshError = refreshAdapter(
                self._iconAdapter,
                reason or "promotion_event_2025_update"
            )
            if refreshed == false then
                logIconV2Error("refresh failed: " .. tostring(refreshError))
            end
            return refreshed, refreshError
        end

        if adapterIcon and type(adapterIcon.updateAll) == "function" then
            local updated, updateError = pcall(adapterIcon.updateAll, adapterIcon)
            if not updated then
                logIconV2Error("legacy adapter update failed: " .. tostring(updateError))
                return false, updateError
            end
        end
        return true
    end

    local icon = self._iconManager:getIconByIconKey(PromotionEvent2025Const.actKey)
    if icon then
        icon:updateAll()
    else
        return self:createMainSceneIcon()
    end
end

function PromotionEvent2025Manager:iconOnTouch(options)
    if self._iconTouchLock then return false end

    if not (options and options.skipLegacyNewConsume == true) then
        self:setIconIsShow()
    end

    self._iconTouchLock = true
    self:openMainAct(true):next(function()
        self._iconTouchLock = false
    end, function()
        self._iconTouchLock = false
    end)
    return true
end

function PromotionEvent2025Manager:hasIconRewards()
    return self:canGetReward() or self:needHistoryRankReward()
end

function PromotionEvent2025Manager:isIconCanShow()
    return not self:isClose()
end

function PromotionEvent2025Manager:hasIconIsNew()
    return self._model:getIsNewIcon()
end

function PromotionEvent2025Manager:setIconIsShow()
    self._model:setIconIsShow()
end

----------------------- 接事件 -----------------------
function PromotionEvent2025Manager:onActEnterMainScene(event)
    if not self:isBaseEnabled() then return end
    local data = event:getData() or {}
    if data.firstEnter then
        self:updateMainSceneRewardBanner()
        return
    end

    if not self:isDataEnabled() or self:isClose() or (self:isOpen() and TimeKit:timeInSec() > self:getPeriodEndTime()) then
        self:requestGetMainInfo(true)
        return
    end

    if self._model:getRewardFailFlag() then
        self:requestGetMainInfo(true):next(function()
            self._model:setRewardFailFlag(false)
        end)
    end
    
    self:updateMainSceneRewardBanner(true)

    local icon = self._iconManager:getIconByIconKey(PromotionEvent2025Const.actKey)
    if icon and not self:isV2IconActive() and type(icon.getIconRank) == "function" then
        local iconRank = icon:getIconRank()
        if self._iconRankBeforePassLevel ~= 0 and iconRank < self._iconRankBeforePassLevel then
            icon:playRankUpDownAni(true)
        end
    end
end

function PromotionEvent2025Manager:onSystemEnterForeground()
    if not self:isBaseEnabled() then return end

    if not self:isDataEnabled() or self:isClose() or (self:isOpen() and TimeKit:timeInSec() > self:getPeriodEndTime()) then
        self:requestGetMainInfo(true)
        return
    end

    if self._model:getRewardFailFlag() then
        self:requestGetMainInfo(true):next(function()
            self._model:setRewardFailFlag(false)
        end)
    end
    self:updateMainSceneRewardBanner(true)
end

-- 过关事件
function PromotionEvent2025Manager:onActPlayLevelEnd(evt)
    if not self:isEnabled() then return end

    local curTaskInfo = self._model:getCurTaskInfo()
    if not curTaskInfo or curTaskInfo.curTaskIndex ~= 1 then
        self._iconRankBeforePassLevel = self:getRank() or 0
        self:requestGetCurRankInfo(PromotionEvent2025Const.SpecNoProfileGroupRankType)
    end

    self:updateIcon()
    self:updateMainSceneRewardBanner(true)

    self:tryToAutoGetRewards()
end

-- before过关事件
function PromotionEvent2025Manager:onActBeforePlayLevelEnd(evt)
    if not self:canCollectInLevel() then return end

    self._model:generateInitTaskData()
    local initTask = self._model:getInitTaskData()
    self._levelInitTaskData = initTask and table.clone(initTask, true) or nil
    local frameName,isDouble,expireTime = self:getCollectionIconInfo()
    self._levelCollectionIconInfo = {
        frameName = frameName,
        isDouble = isDouble,
        expireTime = expireTime,
    }
end

function PromotionEvent2025Manager:clearLevelInitTaskData()
    self._levelInitTaskData = nil
    self._levelCollectionIconInfo = nil
end

function PromotionEvent2025Manager:getLevelInitTaskData()
    if self._levelInitTaskData then
        return table.clone(self._levelInitTaskData, true)
    end
    return nil
end

function PromotionEvent2025Manager:onActEnterStage4(data)
	if not self:isEnabled() then return end

    self:tryAutoPopPromotionCardPack()

    local levelId = _G.getTopLevelId()
    if PromotionEvent2025Group:isPopup210Group() and levelId < 210 then return end
    if PromotionEvent2025Group:isPopup300Group() and levelId < 300 then return end

    if self:getCompleteTaskIndex() < 1 or self:getLastRankFlag() then return end
    if not self:needHistoryRankReward() then return end

    local levelUnLockManager = _G.amfBean("LevelUnLockManager")
    if levelUnLockManager:isInNewLevelTime() and levelUnLockManager:isTopNewMainLevel(levelId) then return end

    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.PROMOTION_2025)
    end

    local creator = function ()
        self:openMainAct():next(onHandleOver, onHandleOver)
    end

    self._autoPopupMgr:addPopupConfig(PopupCheckPoint.PROMOTION_2025, creator)
end

----------------------- 分享 ------------------------
function PromotionEvent2025Manager:shareToMini(typeIndex)
    local promise = deferred.new()

    if EnvUtil:isWindows() or EnvUtil:isUnityEditor() then
        CommonTip:showTip("分享成功!")
        promise:resolve()
        return promise
    end

    local feedIndex = math.clamp(typeIndex, 1, 5)

    local imgPath
    if EnvUtil:isMiniGame() then
        imgPath = _G.ccFullShareImgPath("promotionEvent/sharefeed"..feedIndex..".jpg")
    else
        imgPath = CCFileUtils:sharedFileUtils():fullPathForFilename("amf/promotionevent2025/ui/share/sharefeed"..feedIndex..".jpg")
    end

    local texts = {
        "我的段位一路狂飙，这感觉超爽！等你来挑战！",
        "段位晋升，我在开心消消乐等你切磋！",
        "段位跃升，快来开心消消乐和我一较高下！",
        "朋友，我已经荣耀登顶，邀你决战消消乐之巅！",
        "瞅瞅，我这段位蹭蹭上钻石，你能把我这 “钻石王老五” 咋样？",
        "从青铜逆袭成钻石大神，和我一起过过招？",
        "前方发来战报，拿下100风车币！",
        "刚赚了100风车币，咱来比比谁更阔气！",
        "100风车币已到手，进游戏跟你分享暴富秘籍！",
    }

    local randomFeed = math.random(1, 3)
    local prefix = ((typeIndex == 4) and 1) or ((typeIndex == 5) and 2) or 0
    local textIndex = randomFeed + prefix*3
    local text = texts[textIndex]

    local templateIds = {
        "46g4kl54bk84217i64",
        "65onjaqmoqn8e76e2l",
        "36k94krvo716ahh5lc",
        "khe9kkbmc4271bclh7",
        "gb3lendjoji17g0dom"
    }

    local templateId = templateIds[feedIndex]
    local st = (typeIndex <= 4) and OpenShareConst.ShareType.PROMOTION_SETTLE or OpenShareConst.ShareType.PROMOTION_REWARD
    local context = OpenShareContext.new(st, OpenShareConst.ShareTarget.MINI)
        :setActId(PromotionEvent2025Const.FeatureId)
        :setTextParams(text)
        :setMiniParams({
            imageUrl = imgPath,
            templateId = templateId
        })
        :setKVData({
            t5 = textIndex
        })
        :setShareCallback(function()
            CommonTip:showTip("分享成功!")
            promise:resolve()
        end)
    _G.amfTransaction(TransactionEvent.SHARE, context)

    return promise
end

function PromotionEvent2025Manager:showShareRewardPanel(rewardList)
    local promise = deferred.new()

    local ShowRewardsPanel = require "amf.middleware.ui.kit.panel.reward.ShowRewardsPanelVM"
    local panel = ShowRewardsPanel.Builder.new()
        :setRewards(rewardList, function(reward)
            return self:createIcon(reward)
        end)
        :setButtonText("收下")
        :setCloseCallback(function()
            promise:resolve()
        end)
        :setSubTitle("分享成功奖励")
        :setLoadResFailCallback(function()
            promise:reject()
        end)
        :build()

    panel:popout()

    return promise
end

function PromotionEvent2025Manager:isSupportShare()
    if EnvUtil:isUnionMiniGame() then
        return false
    end
    if EnvUtil:isWindows() or EnvUtil:isUnityEditor() then
        return true
    end

    if EnvUtil:isMiniGame() then
        return true
    end

    if EnvUtil:isIOS() then
        return true
    end

	if PlatformConfig:isPlatform(PlatformNameEnum.kHE) or PlatformConfig:isPlatform(PlatformNameEnum.kDouYinLh) then
		return true
	end

    return false
end

----------------------- 关卡内调用 ---------------------
-- 过关更新数据
function PromotionEvent2025Manager:updateServerDataFormLevel(data)
    if not self:isEnabled() then return end
    if data.period == self._model:getPeriod() then
        local beforeCollectNum = tonumber(self._model:getCollectNum()) or 0
        self._model:addCollectNum(data.collectCount or 0)
        self:updateMainSceneRewardBanner(true)

        if data.coinNum > 0 then
            self._model:addRewards({{
                itemId = UPropId.COIN,
                num = data.coinNum,
            }}, "newpromotion", "passLevel")
        end
    end
end

function PromotionEvent2025Manager:clearMainSceneRewardBanner(reason)
    self._rewardBanner = nil
    local context = SceneTopBannerContext.new()
        :setPriority(SceneTopBannerConst.Priority.PROMOTION_EVENT)
        :setRemove(true)
    _G.amfTransaction(TransactionEvent.SCENE_TOP_BANNER, context)
end

function PromotionEvent2025Manager:updateMainSceneRewardBanner(animate)
    local showOnMainScene = PromotionEvent2025BannerSwitch:shouldShowOnMainScene()
    local enabled = self:isEnabled()
    if not showOnMainScene then
        self:clearMainSceneRewardBanner("switch_not_on3")
        return
    end
    if not enabled then
        self:clearMainSceneRewardBanner("activity_disabled")
        return
    end

    local open = self:isOpen()

    if not open then
        self:clearMainSceneRewardBanner("activity_not_open")
        return
    end

    local overPeriod = self:isOverPeriod()


    if overPeriod then
        self:clearMainSceneRewardBanner("period_over")
        return
    end
    
    local finishAllTask = self:isFinishAllTask()


    if not finishAllTask then
        local taskInfo = self:getCurTaskInfo()
        if not taskInfo or not tonumber(taskInfo.total) or tonumber(taskInfo.total) <= 0 then
            self:clearMainSceneRewardBanner("invalid_task_info")
            return
        end
    end

    local context = SceneTopBannerContext.new()
        :setPriority(SceneTopBannerConst.Priority.PROMOTION_EVENT)
        :setBannerCreator(function()
            local Banner = require_debug "amf.feature.promotionevent2025.view.PromotionEvent2026RewardBanner"
            self._rewardBanner = Banner:create({manager = self})
            return self._rewardBanner
        end)
        :setAutoDisappear(false)
        :setCallbacks(function(node)
            if not isSafeCocosObj(node) then return end
            node:setVisible(true)
        end, function(node)
            if not isSafeCocosObj(node) then return end
            node:setVisible(false)
        end)
    _G.amfTransaction(TransactionEvent.SCENE_TOP_BANNER, context)

    if isSafeCocosObj(self._rewardBanner) and self._rewardBanner.refresh then
        self._rewardBanner:refresh(animate)
    end
end

function PromotionEvent2025Manager:playMainSceneRewardAnimation(params, done)
    if type(params) == "function" then
        done = params
        params = nil
    end
    if isSafeCocosObj(self._rewardBanner)
        and self._rewardBanner.playGetRewardAnimation
    then
        self._rewardBanner:playGetRewardAnimation(params, done)
    else
        safeRunCall(done)
    end
end

-- 关卡内初始化顶部banner
-- local params = {
--     levelId = runtime.levelId,
--     levelType = runtime.levelType,
--     levelScene = runtime.levelScene,
--     isAskForHelp = runtime:isAskForHelp(),
--     isFail = isFail,
--     isRetry = isRetry,
--     isPassedLevel = runtime:isPassedLevel() == true,
--     isStartLevelPanel = isSlp,
--     collectEnabled = true,
-- }

function PromotionEvent2025Manager:getScreenTopOffset()
    return -147 
end

function PromotionEvent2025Manager:getTopBannerData(params)
    if not self:isEnabled() then return end
    if not self:isOpen() then return end
    if self:isOverPeriod() then return end

    if PromotionEvent2025BannerSwitch:shouldUseV2Banner() then
        local bannerData
        if params.isStartLevelPanel then
            -- 与老 UBF 分支保持一致：不能收集的关卡不展示顶部 banner
            if not params.collectEnabled then return end

            self._model:generateInitTaskData()
            local initTask = self._model:getInitTaskData()
            self._levelInitTaskData = initTask and table.clone(initTask, true) or nil
            initTask = self:getLevelInitTaskData() or initTask
            local frameName,isDouble,expireTime = self:getCollectionIconInfo()
            bannerData = {
                initTask = initTask and table.clone(initTask, true),
                curTask = initTask and table.clone(initTask, true),
                isEndGame = false,
                finishAllTask = self:isFinishAllTask(),
                collectionIconInfo = {
                    frameName = frameName,
                    isDouble = isDouble,
                    expireTime = expireTime,
                },
            }
        else
            local lastCollectCount = self._model:getLastCollectCount()
            local initTask = self:getLevelInitTaskData()
                or self._model:getInitTaskData()
            if lastCollectCount <= 0 then
                self:clearLevelInitTaskData()
                return
            end

            local passLevelData = self:getTopBannerPassLevelData(
                lastCollectCount,
                initTask
            )
            local passInitTask = passLevelData and passLevelData.initTask
            local passCurTask = passLevelData and passLevelData.curTask
            bannerData = {
                initTask = passInitTask and table.clone(passInitTask, true),
                curTask = passCurTask and table.clone(passCurTask, true),
                isEndGame = true,
                lastCollectCount = lastCollectCount,
                finishAllTask = self:isFinishAllTask(),
                collectionIconInfo = self._levelCollectionIconInfo,
                rewardQueue = passLevelData and passLevelData.rewardQueue,
            }
            self._model:clearLastCollectCount()
            self:clearLevelInitTaskData()
        end

        -- 与老板 UBFPromotionTopUI 一致：banner 需要 isTopPlay / isRetry 才能判定触摸规则。
        local isTopPlay = true
        local levelUnLockManager = _G.amfBean("LevelUnLockManager")
        if levelUnLockManager and params.levelId then
            isTopPlay = not (levelUnLockManager:isInNewLevelTime()
                and levelUnLockManager:isTopNewMainLevel(params.levelId))
        end

        return {
            screenTopOffset = self:getScreenTopOffset(),
            amfCreator = function()
                local Banner = require_debug "amf.feature.promotionevent2025.view.PromotionEvent2026RewardBanner"
                return Banner:create({
                    manager = self,
                    inLevel = true,
                    isStartLevelBanner =  params.isStartLevelPanel,
                    isRetry = params.isRetry,
                    isTopPlay = isTopPlay,
                    initialData = bannerData,
                })
            end
        }
    end

    local slpTopBannerData
    if params.isStartLevelPanel then
        if not params.collectEnabled then return end

        self._model:generateInitTaskData()
        slpTopBannerData = self:getTopBannerNormalData()
    else
        local lastCollectCount = self._model:getLastCollectCount()
        if lastCollectCount <= 0 then return end
        slpTopBannerData = self:getTopBannerPassLevelData(lastCollectCount)
        self._model:clearLastCollectCount()
    end

    if slpTopBannerData then
        local levelUnLockManager = _G.amfBean("LevelUnLockManager")
        slpTopBannerData.levelScene = params.levelScene
        slpTopBannerData.levelId = params.levelId
        slpTopBannerData.isTopPlay = not (levelUnLockManager:isInNewLevelTime() and levelUnLockManager:isTopNewMainLevel(params.levelId))

        local function dealRewardIcon(taskInfo)
            if taskInfo.nextBoxIcon and taskInfo.nextRewards then
                for k,v in ipairs(taskInfo.nextRewards) do
                    v.boxIcon = taskInfo.nextBoxIcon
                end
            end
        end
        if slpTopBannerData.initTask then
            slpTopBannerData.initTask = table.clone(slpTopBannerData.initTask)
            dealRewardIcon(slpTopBannerData.initTask.taskInfo)
        end
        if slpTopBannerData.curTask then
            slpTopBannerData.curTask = table.clone(slpTopBannerData.curTask)
            dealRewardIcon(slpTopBannerData.curTask.taskInfo)
        end
        slpTopBannerData.screenTopOffset = self:getScreenTopOffset()
    end

    return slpTopBannerData
end

function PromotionEvent2025Manager:getTopBannerNormalData()

    local initTask = self._model:getInitTaskData()
    local periodConfig = self:getCurPeriodConfig()

    local data = {
        initTask = initTask,
        curRank = self:getRank(),
        dan = self:getDan(),
        endTime = self:getPeriodEndTime(),
        period = self:getDataValue("curPeriod"),
        rankDiff = self._model:getCurRankDiff(),
        finalTaskIndex = self:getFinalTaskIndex(),
        danCreator = function(dan)
            return self:createDanIcon(dan)
        end,
        collectionIconCreator = function(withBuffTime)
            return self:getCollectionIcon(withBuffTime)
        end,
        rewardCreator = function(reward, needNum, boxIcon)
            return self:createIcon(reward, needNum, boxIcon)
        end,
        getTaskRewards = function ( curTaskIndex )
            return self:getTaskRewards( curTaskIndex )
        end,
        extraBoxCreator = function(rewardList)
            return self:_getPlug("ActSend"):createExtraRewardBox(rewardList)
        end,
        collectLine = periodConfig.taskType == PromotionEvent2025Const.TaskType.kLine,
        -- welfareInfo = self:getFragmentWelfareInfo()
    }
    return data
end

function PromotionEvent2025Manager:getActSendPlug()
    return self:_getPlug("ActSend")
end

function PromotionEvent2025Manager:getTopBannerPassLevelData(lastCollectCount, initTaskOverride)
    self._model:checkAndModInitTask()

    local data = self:getTopBannerNormalData()

    data.isEndGame = true
    if initTaskOverride then
        data.initTask = table.clone(initTaskOverride, true)
    end
    data.curTask = self._model:getCurInitTaskData()
    data.finalTaskIndex = self:getFinalTaskIndex()
    data.lastCollectCount = lastCollectCount
    -- 过关一次可能够领多个奖，把这次要播的整条奖励序列一起给 banner，
    -- 表现按序列播完，不再实时依赖模型推进（后端领奖比动画快，实时等会提前结束）。
    data.rewardQueue = self._model:getRewardProgressList()

    return data
end

function PromotionEvent2025Manager:getTopBannerUpdateData(params)
    local requestTaskIndex = params.taskIndex
    if not requestTaskIndex then return end
    local curTask = self:getTaskDataByTaskIndex(requestTaskIndex)
    if not curTask then return end
    curTask = table.clone(curTask)

    local function dealRewardIcon(taskInfo)
        if taskInfo.nextBoxIcon and taskInfo.nextRewards then
            for k,v in ipairs(taskInfo.nextRewards) do
                v.boxIcon = taskInfo.nextBoxIcon
            end
        end
    end

    -- printx(16,"getTopBannerUpdateData",tts(curTask))

    dealRewardIcon(curTask.taskInfo)

    local data = {
        curTask = curTask,
        curRank = self:getRank(),
        rankDiff = self._model:getCurRankDiff(),
        over = self:isClose(),
    }

    return data
end

--是否为2025新版晋级赛
function PromotionEvent2025Manager:isPromotionEvent2025Version()
    return true
end

function PromotionEvent2025Manager:getMainSceneButtonShowConfig()
    if not self:isEnabled() then return end

    local showConfig = {}

    local collectionBuffEndTime = self:getCollectionBuffEndTime()
    local periodConfig = self:getCurPeriodConfig()

    local type = periodConfig.taskType == PromotionEvent2025Const.TaskType.kLine
        and PromotionEvent2025Const.TaskType.kLine or PromotionEvent2025Const.TaskType.kAnimal
    if collectionBuffEndTime > TimeKit:timeInSec() then
        table.insert(showConfig, {
            uniqueId = "PromotionEvent2025DoubleBuff",
            actId = PromotionEvent2025Const.FeatureId,
            actName = PromotionEvent2025Const.ActShowName,
            itemId = type,
            iconCreator = function()
                return self:getCollectionIcon()
            end,
            endTime = collectionBuffEndTime,
            rate = self:getCollectionFactor() + 1,
        })
    end
    local scoreBuffEndTime = self:getScoreBuffEndTime()
    local scoreBuffRate = self:getScoreFactor()
    if scoreBuffEndTime > TimeKit:timeInSec() then
        table.insert(showConfig, {
            uniqueId = _G.BuffTypeConfig.SCORE_BUFF,
            actId = PromotionEvent2025Const.FeatureId,
            actName = PromotionEvent2025Const.ActShowName,
            showStr = "",
            endTime = scoreBuffEndTime,
            rate = scoreBuffRate + 1,
        })
    end

    return showConfig
end


------------------------------------------- 额外插件 -------------------------------------------
function PromotionEvent2025Manager:getConst()
    return PromotionEvent2025Const
end

function PromotionEvent2025Manager:initPlugs()
    self:_initPlug("ActSend",{
        plugPath = "amf.feature.promotionevent2025.plug.PromotionEventActSendPlug"
    })
end


-- 如果要自己继承插件改的话自己传plugPath, 可以继承调用
-- 如果有自己的插件模块要添加也可以这么整，在自己的活动功能文件夹下整插件加上去。
function PromotionEvent2025Manager:_initPlug(key, data)
    local plugPath
    if data and data.plugPath then
        plugPath = data.plugPath
    end

    local TextUtil = require "amf.middleware.ui.util.TextUtil"
    local holdName = TextUtil:lowercaseFirstLetter(key) .. "Plug"

    self:_installPlug(key, data, plugPath):as(holdName)

    -- 插件函数调用
    self["call" .. key .. "Func"] = function(obj, funcName, ...)
        return obj:callPlug(key, funcName, ...)
    end
end

function PromotionEvent2025Manager:_getPlugContainer()
    if not self.plugContainer then
        local PlugContainer = require "amf.script.pattern.plug.PlugContainer"
        self.plugContainer = PlugContainer:create(self, "amf.feature.promotionevent2025.plug")
    end
    return self.plugContainer
end

function PromotionEvent2025Manager:_installPlug(plugType, installData, scriptPath)
    local plug = self:_getPlugContainer():install(plugType, installData, scriptPath)
    return {
        as = function(_, name)
            if name then
                if self[name] == plug then
                    self[name] = nil
                end
                self[name] = plug
            end
        end
    }
end

function PromotionEvent2025Manager:_uninstallPlug(plugType)
    self:_getPlugContainer():uninstall(plugType)
end

function PromotionEvent2025Manager:_getPlug(plugType)
    return self:_getPlugContainer():getPlug(plugType)
end

function PromotionEvent2025Manager:callPlug(plugType, funcName, ...)
    return self:_getPlugContainer():call(plugType, funcName, ...)
end

function PromotionEvent2025Manager:checkIconTip(config)
    if not self:isDataEnabled() then return end

    local text, typeIndex, key
    if self:needHistoryRankReward() and not self:getIconTipFlag(PromotionEvent2025Const.IconTipType.kReward) then
        text = "有结算奖励可领取哦~"
        typeIndex = 1
        key = PromotionEvent2025Const.IconTipType.kReward
    elseif self:hasIconIsNew() and not self:getIconTipFlag(PromotionEvent2025Const.IconTipType.kNewPeriod) then
        text = "新一期开始啦！"
        typeIndex = 2
        key = PromotionEvent2025Const.IconTipType.kNewPeriod
    end

    if text then
        local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")
        IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, {
            iconKey = PromotionEvent2025Const.actKey,
            iconType = IconTipType.MESSAGE,
            typeIndex = typeIndex,
            creatorDelegate = {
                tipsType = HomeIconTipsType.ONLY_TEXT,
                text = text,
            },
            popFunc = function()
                self:setIconTipFlag(key)
            end,
            config = config,
        })
    end
end

---------------------------------- CUSTOM_GAIN ----------------------------------

function PromotionEvent2025Manager:_onCustomGain(event)
    local reward = event:getData()
    local PEItemList = PromotionEvent2025Const.PEItemList
    for _, cfg in pairs(PEItemList) do
        if cfg.itemId == reward.itemId then
            self:addBuffItem(reward.itemId, reward.num)
            return
        end
    end
end

function PromotionEvent2025Manager:_onResolveIcon(event)
    local data = event:getData()
    if data.itemId ~= PromotionEvent2025Const.PEItemList[PromotionEvent2025Const.PEItemType.kCollect100].itemId then
        return
    end
    -- 收集物 icon: 根据赛季类型选择图集帧（common_icon_256 全局预加载）
    local periodConfig = self:getCurPeriodConfig()
    if not periodConfig then return end
    local frameName = getCollectionIconFrameName(periodConfig)
        or COLLECTION_ICON_FRAME_NAMES[PromotionEvent2025Const.TaskType.kAnimal]
    data.callback({
        Atlas = "",
        Frame = frameName,
        IsPropPng = false,
    })
end


------------------------------- 关卡内 -------------------------------
-- 生成开始面板及进关后共同使用的活动 env 数据。
function PromotionEvent2025Manager:getInLevelEnvData(conditionRuntime)
    local curPeriod = self:getCurPeriodConfig()
    local collectEnabled = UBFActHelper:checkActOpenCondition(conditionRuntime, "173")
    local currentTime = TimeKit:timeInMillis()
    local collectionBuffEndTime = (tonumber(self:getCollectionBuffEndTime()) or 0) * 1000
    local scoreBuffEndTime = (tonumber(self:getScoreBuffEndTime()) or 0) * 1000
    local coinBuffEndTime = (tonumber(self:getCoinBuffEndTime()) or 0) * 1000
    local inLevelEnvData = {
        -- 活动周期
        period = self:getPeriod(),
        -- 是否可以收集
        collectEnabled = collectEnabled,
        -- 收集物类型，1直线元素 max100，2动物元素 max500。来自活动数据
        collectType = curPeriod.taskType,
        -- 收集物颜色，仅动物元素生效，"蓝","绿","棕","紫","红","黄"
        collectColor = curPeriod.colorIndex,
        -- 过关时候可以获得的保底数量，来自配置
        baseCollectCount = collectEnabled and curPeriod.collectionBase or 0,
        -- 收集物基础值上限，来自配置
        maxCollect = curPeriod.collectionMax,
        -- 框架通用buff字段
        hasScoreBuff = scoreBuffEndTime > currentTime,
        scoreBuffRate = self:getScoreFactor(),
        hasTimeLimiteBuff = collectEnabled and collectionBuffEndTime > currentTime,
        buffEndTime = collectionBuffEndTime,
        hasCoinBuff = coinBuffEndTime > currentTime,
        coinBuffRate = self:getCoinFactor(),
    }

    return inLevelEnvData
end

-- TODO @xinliang
function _G.demoCreateOnMainScene()
    if PromotionEvent2025BannerSwitch:shouldUseV2Banner() then return end

    -- 获取晋级赛条的数据，之前是根据进关流程数据生成，现在针对大藤蔓分支需要适配/改造，以下只是演示
    local params = {
        levelId = _G.getTopLevelId(),
        levelScene = UBFLevelSceneType.kMain,
        isStartLevelPanel = true,
        collectEnabled = true,
    }
    local slpTopBannerData = _G.amfBean("PromotionEventManager"):getTopBannerData(params)
    
    -- 构造UI创建数据包
    local opParams = {
        nodeId = UBFPromotionEventNodeId.MAIN_SCENE_PROMOTION_BANNER,
        singleNodeData = {
            logicId = UBFPromotionEventLogicId.PROMOTION_BANNER,
            parentParams = {
                type = "Node",
                nodeParams = {
                    -- 父节点
                    parent = Director:sharedDirector():getRunningScene().topLayer,
                },
            },

            x = 0,
            y = 1280,
            slpTopBannerData = slpTopBannerData,
        }
    }

    -- 执行创建
    UBFGlobal:getLogic(UBFUiLogicId.UI_VIEW_LOGIC_MANAGER)
    :exeOp(UBFUiOpType.CREATE_UI, opParams)
    -- 如有需要
    :next(function(node)
        -- TODO
    end)
end

return PromotionEvent2025Manager
