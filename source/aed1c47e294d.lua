local PopupNewActMgr = class("PopupNewActMgr")
local MainSceneEventCenter = require 'amf.feature.mainscene.core.event.MainSceneEventCenter'
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local AutoPopupDebugLog = require "amf.middleware.autopop.AutoPopupDebugLog"
local IconV2Experiment = require "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"
local NotificationCoordinator = require "amf.feature.mainscene.module.icon.v2.newactivity.NotificationCoordinator"
local NewActivityRecordStore = require "amf.feature.mainscene.module.icon.v2.newactivity.NewActivityRecordStore"

--处理发现新活动和配置强弹
function PopupNewActMgr:ctor()
	self._autoPopupMgr = nil
    self._activityMgr = nil
    self.pendingNotificationRequests = {}
    self.waitingForPanelsBeforeNotification = false
end

function PopupNewActMgr:setAutoPopupMgr(mgr)
	self._autoPopupMgr = mgr
end

function PopupNewActMgr:setActivityMgr(mgr)
	self._activityMgr = mgr
end

function PopupNewActMgr:initialize()

    local maintenanceName = 'ClearNewActNot_test'
    local bOpenTest = MaintenanceManager:getInstance():isEnabledInGroup(maintenanceName, "ON") 
    self.bOpenTest = bOpenTest
    self.iconV2Enabled = IconV2Experiment:isEnabled()

	--新活动
	self.newAutoPopActs = {}
    -- 包内
    self.newAutoPopPkgActs = {}
    self.dataDrivenCandidateSources = {}
    self.notificationRecordStore = NewActivityRecordStore.new(function()
        return self._autoPopupMgr
    end)
    self.notificationCoordinator = NotificationCoordinator.new({
        records = self.notificationRecordStore,
        presenter = function(candidates, hooks)
            return self:presentDataDrivenNewActivity(candidates, hooks)
        end,
        logger = function(code, data)
            AutoPopupDebugLog:log(
                "IconV2Notification:" .. tostring(code) .. ":" .. tostring(data and data.cycleKey)
            )
        end,
    })
    self.notificationCoordinator:beginFlow({ stage2Expected = false })

    self:registerEvent()
end

function PopupNewActMgr:registerEvent()
    _G.amfEC:registerFeature(self)
end

function PopupNewActMgr:sendPanelManualPopup(uniqueKey)
	if not uniqueKey then return end

	local panelUniqueKey = uniqueKey .. "_panel"
	local curShowNum = self._autoPopupMgr:getPermanentShowNum(panelUniqueKey)
	if curShowNum == 0 then
		self._autoPopupMgr:sendPermanentData(panelUniqueKey)
	end
end

-- 活动发现新活动
function PopupNewActMgr:addNewAutoPopAct(source, tbl)
    if self.bOpenTest or self.iconV2Enabled then return end
	self.newAutoPopActs[source] = tbl
end

function PopupNewActMgr:removeNewAutoPopAct(source)
	self.newAutoPopActs[source] = nil
end

function PopupNewActMgr:addDataDrivenNewActivityCandidate(source, candidate)
    if not self.iconV2Enabled or not self.notificationCoordinator then
        return false
    end
    local registered, reason = self.notificationCoordinator:register(candidate)
    if registered and source ~= nil then
        self.dataDrivenCandidateSources[source] = candidate.cycleKey
    end
    return registered, reason
end

function PopupNewActMgr:removeDataDrivenNewActivityCandidate(source, reason)
    local cycleKey = self.dataDrivenCandidateSources and self.dataDrivenCandidateSources[source]
    if cycleKey == nil then
        return false
    end
    self.dataDrivenCandidateSources[source] = nil
    return self:cancelDataDrivenNewActivity(cycleKey, reason or "source_removed")
end

function PopupNewActMgr:cancelDataDrivenNewActivity(cycleKey, reason)
    if not self.notificationCoordinator or cycleKey == nil then
        return false
    end
    return self.notificationCoordinator:cancelBeforeVisible(cycleKey, reason)
end

function PopupNewActMgr:hasNewAutoPopAct()
    return table.size(self.newAutoPopActs) > 0
end

-- 包内发现新活动
function PopupNewActMgr:addNewAutoPopPkgAct(uniqueKey, iconKey, iconLabel)
    if not self._autoPopupMgr:isEnabled() then return end
    if self.bOpenTest or self.iconV2Enabled then return end

    local panelShowNum = self._autoPopupMgr:getPermanentShowNum(uniqueKey .. "_panel")
    if panelShowNum < 1 then
        self.newAutoPopPkgActs[uniqueKey] = {uniqueKey = uniqueKey, iconKey = iconKey, iconLabel = iconLabel}
    end

    return uniqueKey
end

function PopupNewActMgr:removeNewAutoPopPkgAct(uniqueKey)
    self.newAutoPopPkgActs[uniqueKey] = nil
end

function PopupNewActMgr:hasNewAutoPopPkgAct()
    return table.size(self.newAutoPopPkgActs) > 0
end

function PopupNewActMgr:hasPendingDataDrivenNewActivityCandidate()
    local coordinator = self.notificationCoordinator
    return coordinator
        and type(coordinator.hasPendingCandidates) == "function"
        and coordinator:hasPendingCandidates()
        or false
end

function PopupNewActMgr:getAllNewAutoPopActsInfos()
    local infos = {}

    local function insertInfo(tbl)
        for source,v in pairs(tbl) do
            -- {
            --     iconKey = "",
            --     iconLabel = "",
            --     uniqueKey = "",
            -- }
            if v then
                local info = table.clone(v)
                if not info.iconLabelStr then info.iconLabelStr = "哇新活动" end
                table.insert(infos, info)
            end
        end	
    end
	
	insertInfo(self.newAutoPopActs)
	self.newAutoPopActs = {}
    insertInfo(self.newAutoPopPkgActs)
    self.newAutoPopPkgActs = {}
	
	return infos
end

function PopupNewActMgr:handleNewIconActAutoPopup(needRetrigger)
	local function doAutoPopup()
		AutoPopEventCenter:dispatch(AutoPopEvent.ACTIVITY, {
            popupCheckPoint = PopupCheckPoint.ACT_NEW,
            params = {
                needRetrigger = needRetrigger,
            },
        })
	end

	if self:hasPendingDataDrivenNewActivityCandidate()
        or self:hasNewAutoPopAct()
        or self:hasNewAutoPopPkgAct()
    then
		doAutoPopup()
	end
end

function PopupNewActMgr:popNewActPanel(endCallback)
	local infos = self:getAllNewAutoPopActsInfos()
	local levelId = _G.getTopLevelId()

	if #infos==0 or levelId<100 then
		if endCallback then endCallback() end
		return
	end

	local dcParam = nil
	for i,v in ipairs(infos) do
		assert(v.uniqueKey, "invalid uniqueKey")
		self._autoPopupMgr:sendPermanentData(v.uniqueKey .. "_panel")

		if not dcParam then
			dcParam = v.uniqueKey
		else
			dcParam = dcParam .. "_" .. v.uniqueKey
		end
	end
	-- DcUtil:UserTrack({category = "newactivity", sub_category = "click", t1 = dcParam})

	-- printx(23, "需要发现新活动啦~~~")
	self:setFoundNewActs(infos)
	if endCallback then
		endCallback()
	end
end

function PopupNewActMgr:tryPopupFoundNewActLegacy(callback)
	if self.waitingPopupNewActs and #self.waitingPopupNewActs>0 then
        if EnvUtil:isWindows() then
            local PopupNewActNotice = require "amf.middleware.autopop.module.activity.PopupNewActNotice"
            PopupNewActNotice:create(self.waitingPopupNewActs, callback):start()
            self:setFoundNewActs(nil)
        else
            _G.amfBean("AssetsUtil"):loadMiniLabels({"auto_pop"}, false):next(function()
                local PopupNewActNotice = require "amf.middleware.autopop.module.activity.PopupNewActNotice"
                PopupNewActNotice:create(self.waitingPopupNewActs, callback):start()
                self:setFoundNewActs(nil)
            end,callback)
        end
	else
        if callback then callback() end
    end
end

function PopupNewActMgr:presentDataDrivenNewActivity(candidates, hooks)
    local context = nil
    local cancelled = false
    local control = {}

    function control:cancel(reason)
        cancelled = true
        if context then
            context:cancel(reason)
        end
    end

    function control:skipToFinal(reason)
        if context then
            context:skipToFinal(reason)
        end
    end

    local function startPanel()
        if cancelled then
            return
        end
        local ok, result = pcall(function()
            local NewActBroadCastContext = require "amf.middleware.autopop.module.activity.NewActBroadCastContext"
            context = NewActBroadCastContext:create(candidates, {
                onVisible = hooks.onVisible,
                onComplete = hooks.onComplete,
                onFailure = hooks.onFailure,
                canStart = function()
                    if cancelled then
                        return false
                    end
                    local popoutManager = _G.amfBean("PopoutManager")
                    local hasPanel = popoutManager
                        and popoutManager:hasAMFWindowOnScreen()
                    return not self._autoPopupMgr:isRunnning() and not hasPanel
                end,
            })
            context:build()
            return true
        end)
        if not ok then
            hooks.onFailure("notice_start_error:" .. tostring(result))
        end
    end

    if EnvUtil:isWindows() then
        startPanel()
    else
        local ok, promise = pcall(function()
            return _G.amfBean("AssetsUtil"):loadMiniLabels({"auto_pop"}, false)
        end)
        if not ok or not promise or type(promise.next) ~= "function" then
            hooks.onFailure("asset_load_start_failed")
        else
            promise:next(startPanel, function()
                hooks.onFailure("asset_load_failed")
            end)
        end
    end
    return control
end

function PopupNewActMgr:hasPanelBeforeNotification()
    local popoutManager = _G.amfBean("PopoutManager")
    return popoutManager and popoutManager:hasAMFWindowOnScreen() or false
end

function PopupNewActMgr:clearPanelWaitListener()
    if not self.waitingForPanelsBeforeNotification then
        return
    end
    self.waitingForPanelsBeforeNotification = false
    AutoPopEventCenter:unregisterGlobal(
        NormalEvent.NO_PANEL_ON_SCENE,
        self.onNoPanelBeforeNotification
    )
end

function PopupNewActMgr:requestDataDrivenNotification(stage, callback)
    self.notificationCoordinator:request(stage, function()
        if callback then callback() end
    end)
end

function PopupNewActMgr:onNoPanelBeforeNotification()
    if self:hasPanelBeforeNotification() then
        return
    end
    self:clearPanelWaitListener()
    local requests = self.pendingNotificationRequests
    self.pendingNotificationRequests = {}
    for index = 1, #requests do
        local request = requests[index]
        self:requestDataDrivenNotification(request.stage, request.callback)
    end
end

function PopupNewActMgr:waitForPanelsBeforeNotification(stage, callback)
    table.insert(self.pendingNotificationRequests, {
        stage = stage,
        callback = callback,
    })
    if self.waitingForPanelsBeforeNotification then
        return
    end
    self.waitingForPanelsBeforeNotification = true
    AutoPopEventCenter:registerGlobal(
        NormalEvent.NO_PANEL_ON_SCENE,
        self.onNoPanelBeforeNotification,
        self
    )
    -- Avoid missing a close event between the initial check and registration.
    self:onNoPanelBeforeNotification()
end

function PopupNewActMgr:beginDataDrivenNotificationFlow(stage2Expected)
    if not self.notificationCoordinator then
        return
    end
    self.notificationCoordinator:beginFlow({
        stage2Expected = stage2Expected == true,
    })
end

function PopupNewActMgr:tryPopupFoundNewAct(stage, callback)
    if type(stage) == "function" then
        callback = stage
        stage = AutoPopupConst.PopStage.STAGE_TWO
    end
    stage = stage or AutoPopupConst.PopStage.STAGE_TWO

    if not self.notificationCoordinator then
        if callback then callback() end
        return
    end
    if stage == AutoPopupConst.PopStage.STAGE_FOUR then
        self.notificationCoordinator:markStage2Unavailable("stage4_reached")
    end
    if self:hasPanelBeforeNotification() then
        self:waitForPanelsBeforeNotification(stage, callback)
        return
    end
    self:requestDataDrivenNotification(stage, callback)
end

--发现新活动先存起来，强弹结束再出来 2023版发现新活动
function PopupNewActMgr:setFoundNewActs(infos)
	-- printx(23, infos and "缓存新活动2023~~~" or '清理发现新活动2023缓存')
	self.waitingPopupNewActs = infos
end

function PopupNewActMgr:onActEnterMainScene(data)
	self:beginDataDrivenNotificationFlow(true)
	self:checkStage2And4ActMainPanel(data, "EnterHomeScene")
    self:handleNewIconActAutoPopup()
end

function PopupNewActMgr:onActEnterStage2(evt)
    local data = evt:getData()
    if data and data.isFirstEnter then return end
	self:beginDataDrivenNotificationFlow(true)
	self:checkStage2And4ActMainPanel(data, "EnterForeground")
    self:handleNewIconActAutoPopup()
end

function PopupNewActMgr:onActEnterStage3(data)
	self:beginDataDrivenNotificationFlow(false)
	self:checkStage3ActCustomizedPanel(data, "EnterFromLevel")
end

function PopupNewActMgr:onActEnterStage4(data)
	self:checkStage4ActCustomizedPanel(data, "CheckActOnStage4")
end

--自定义强弹
function PopupNewActMgr:customizedPopFunc(index, popupStage, metaId, actId, levelData, autoPopupConfig)
    AutoPopEventCenter:dispatch(AutoPopEvent.CONDITION, {
        popupCheckPoint = PopupCheckPoint["ACT_CUSTOMIZED_PANEL_STAGE_" .. popupStage .. "_" .. index],
        params = {
            index = index,
            metaId = metaId,
            actId = actId,
            levelData = levelData,
            autoPopupConfig = autoPopupConfig
        },
    })
end

--主面板配置强弹
function PopupNewActMgr:mainPanelFunc(stage, metaId, actId, levelData)
    local checkPoint = stage == AutoPopupConst.PopStageId.STAGE_FOUR and
                            PopupCheckPoint.ACT_MAIN_PANEL_STAGE_4 or PopupCheckPoint.ACT_MAIN_PANEL_STAGE_2
    AutoPopEventCenter:dispatch(AutoPopEvent.TMP_ACT_PANEL, {
        popupCheckPoint = checkPoint,
        params = {
            metaId = metaId,
            actId = actId,
        },
    })
end

--检测是否有配置好的活动主面板需要强弹
function PopupNewActMgr:checkStage2And4ActMainPanel(data, logPrefix)
    AutoPopupDebugLog:log(string.format("%s:checkStage2And4ActMainPanel===start", logPrefix))

    local function deliverStagePopFunc(stage)
        local popData = self._activityMgr:getAutoPopupData({
            popStage = stage,
            isMetaPop = true,
            limitNum = ActivityConst.PopLimit.MAIN_PANEL,
        })
        for k,v in ipairs(popData) do
            self:mainPanelFunc(stage, v.metaId, v.actId, data)
        end
    end

    deliverStagePopFunc(AutoPopupConst.PopStageId.STAGE_TWO)
    deliverStagePopFunc(AutoPopupConst.PopStageId.STAGE_FOUR)
end

-- local _data = {
-- 	levelId = levelId,
-- 	replayMode = self.sourceReplayMode,
-- 	levelPassedInfo = self.levelPassedInfo,
-- 	worldScene = self,
-- }
function PopupNewActMgr:checkStage3ActCustomizedPanel(data, logPrefix)
	AutoPopupDebugLog:log(string.format("%s:checkStage3ActCustomizedPanel===start", logPrefix))

    local popData = self._activityMgr:getAutoPopupData({
        levelData = data,
        popStage = AutoPopupConst.PopStageId.STAGE_THREE,
        limitNum = ActivityConst.PopLimit.CUSTOMIZE_STAGE_3,
    })
    for k,v in ipairs(popData) do
        self:customizedPopFunc(
            k,
            AutoPopupConst.PopStageId.STAGE_THREE,
            v.metaId,
            v.actId,
            v.levelData,
            v.autoPopupConfig
        )
    end
end

-- local _data = {}
function PopupNewActMgr:checkStage4ActCustomizedPanel(data, logPrefix)
	AutoPopupDebugLog:log(string.format("%s:checkStage4ActCustomizedPanel===start", logPrefix))

    local popData = self._activityMgr:getAutoPopupData({
        levelData = data,
        popStage = AutoPopupConst.PopStageId.STAGE_FOUR,
        limitNum = ActivityConst.PopLimit.CUSTOMIZE_STAGE_4,
    })
    for k,v in ipairs(popData) do
        self:customizedPopFunc(
            k,
            AutoPopupConst.PopStageId.STAGE_FOUR,
            v.metaId,
            v.actId,
            v.levelData,
            v.autoPopupConfig
        )
    end
end

return PopupNewActMgr
