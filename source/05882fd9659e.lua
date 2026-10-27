local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local CompetitionTipConfig = require "amf.feature.competition.config.CompetitionTipConfig"

local CompetitionTransferManager = class("CompetitionTransferManager", BaseFeatureManager)
local targetPackageMode = "contest"

CompetitionTransferManager.EntryType = {
    AUDITIONS = "auditions",
    OFFLINE_MATCH = "offline_match",
}

local function compactLaunchParams(params)
    if type(params) ~= "table" then
        return "paramsType=" .. tostring(type(params))
    end

    local keys = {
        "method",
        "type",
        "entryType",
        "competitionType",
        "levelId",
        "matchId",
        "roundId",
        "sessionId",
    }
    local parts = {}
    for _, key in ipairs(keys) do
        if params[key] ~= nil and params[key] ~= "" then
            table.insert(parts, key .. "=" .. tostring(params[key]))
        end
    end
    return table.concat(parts, ",")
end

local function logAuditionsEntry(reason, params, extra)
    printx(29, "[CompetitionTransfer][auditionsEntry] reason=" .. tostring(reason), compactLaunchParams(params), tostring(extra or ""))
end

function CompetitionTransferManager:ctor()
    self._hasFilledAuditionsInfo = false
    self._auditionsInfo = nil
    self._offlineMatchInfo = nil
end

function CompetitionTransferManager:_init()
    printx(29, "[CompetitionTransfer] init")
    _G.amfEC:registerFeature(self)

    local OpenShareEventCenter = require "amf.middleware.share.openshare.event.OpenShareEventCenter"
    OpenShareEventCenter:register(OpenShareEvent.PARSE_URL_TABLE, function(evt)
        self:onOpenShareParseUrlTable(evt)
    end)
    OpenShareEventCenter:register(OpenShareEvent.RESPONSE_HELP, function(evt)
        self:onOpenShareResponseHelp(evt)
    end)
end

function CompetitionTransferManager:onActEnterStage2(event)
    local data = event and event.getData and event:getData() or {}
    printx(29, "[CompetitionTransfer] enter stage2", tostring(data.isFirstEnter))

    self:tryHandleLaunchEntry("stage2")
end

function CompetitionTransferManager:onActEnterStage4(event)
    local data = event and event.getData and event:getData() or {}
    printx(29, "[CompetitionTransfer] enter stage4", tostring(data.levelId), tostring(data.levelScene))

    self:tryHandleLaunchEntry("stage4", true)
end

function CompetitionTransferManager:onOpenShareParseUrlTable(event)
    if not self:isEnabled() then
        logAuditionsEntry("parse_url_disabled", nil, self:getDisabledReason())
        return
    end

    local data = event and event.getData and event:getData()
    if not data then
        logAuditionsEntry("parse_url_no_event_data")
        return
    end

    local query, reason = self:normalizeLaunchEntryParams(data.query, data.method)
    if not query then
        logAuditionsEntry(reason or "parse_url_ignored", data.query, "method=" .. tostring(data.method))
        return
    end

    logAuditionsEntry("parse_url_handled", query)
    if data.callback then
        data.callback(query)
    end
end

function CompetitionTransferManager:onOpenShareResponseHelp(event)
    if not self:isEnabled() then
        logAuditionsEntry("open_share_response_disabled", nil, self:getDisabledReason())
        return
    end

    local query = event and event.getData and event:getData()
    self:tryAddLaunchEntryPopup(query, "open_share_response")
end

function CompetitionTransferManager:isEnabled()
    return self:getDisabledReason() == nil
end

function CompetitionTransferManager:getDisabledReason()
    if EnvUtil and EnvUtil.isMiniGame and EnvUtil:isMiniGame() then
        return "mini_game_not_supported"
    end

    if EnvUtil and EnvUtil.isApp and EnvUtil:isApp() then
        return nil
    end

    if self:isLocalContestPackageAllowed() then
        return nil
    end

    return "not_app_or_allowed_local"
end

function CompetitionTransferManager:getPackageMode()
    local startupConfig = StartupConfig and StartupConfig.getInstance and StartupConfig:getInstance()
    if startupConfig and startupConfig.getPackageMode then
        return startupConfig:getPackageMode()
    end
    return _G.packageMode or ""
end

function CompetitionTransferManager:isAppContestPackage()
    if EnvUtil and EnvUtil.isMiniGame and EnvUtil:isMiniGame() then return false end
    if not self:isContestPackage() then return false end
    if EnvUtil and EnvUtil.isApp and EnvUtil:isApp() then return true end
    return self:isLocalContestPackageAllowed()
end

function CompetitionTransferManager:isOfflineMatchEnabled()
    return self:isEnabled() and self:isAppContestPackage()
end

function CompetitionTransferManager:isLocalContestPackageAllowed()
    if __WIN32 or _G.__UNITY_EDITOR__  then
        return true
    end

    if EnvUtil then
        if EnvUtil.isWindows and EnvUtil:isWindows() then return true end
        if EnvUtil.isUnityEditor and EnvUtil:isUnityEditor() then return true end
        -- if EnvUtil.isDevelopMode and EnvUtil:isDevelopMode() then return true end
    end

    return false
end

function CompetitionTransferManager:isContestPackage()
    return self:getPackageMode() == targetPackageMode or self:isLocalContestPackageAllowed()
end

function CompetitionTransferManager:onActTestButtonReady()
    if not self:isEnabled() then return end

    addGlobalTestButton("[竞赛] 模拟扫码海选二维码", function()
        local params = {
            type = CompetitionTransferManager.EntryType.AUDITIONS,
            levelId = "1",
            matchId = "test_match",
            roundId = "test_round",
        }

        local handled = self:tryAddLaunchEntryPopup(params)
        if handled then
            local autoPopupMgr = _G.amfBean("AutoPopupMgr")
            if autoPopupMgr then
                autoPopupMgr:triggerStage2AutoPopup(true)
            end
        end
        CommonTip:showTip(CompetitionTipConfig:getText("testAuditionsScan", CompetitionTipConfig:getText(handled and "testTriggered" or "testNotTriggered")))
        return nil, true
    end, { TestButtonConst.Tags.DEVELOP })

    addGlobalTestButton("[竞赛] 打开参赛入口面板", function()
        self:showOfflineMatchEntryPanel()
        return nil, true
    end, { TestButtonConst.Tags.DEVELOP })

    addGlobalTestButton("[竞赛] 模拟成绩上报", function()
        self:reportOfflineMatchScore({
            playerNo = "test_player",
            sessionId = "test_session",
            levelScene = "main",
            levelId = 1,
            passed = true,
            score = 12345,
            gemCount = 8,
            duration = 120,
        }, function()
            CommonTip:showTip(CompetitionTipConfig:getText("testReportScoreSuccess"), "positive")
        end, function()
            CommonTip:showTip(CompetitionTipConfig:getText("testReportScoreFailed"))
        end)
        return nil, true
    end, { TestButtonConst.Tags.DEVELOP })
end

function CompetitionTransferManager:onActPlayLevelEnd(event)
    if not self:isEnabled() then return end

    local data = event and event.getData and event:getData() or {}
    local runtime = data.runtimeRefer and data.runtimeRefer.value
    local competitionInfo = runtime and runtime:getAllExtras()
    -- local competitionInfo = data.competitionInfo or data.competition or data.extraData

    if not competitionInfo or competitionInfo.isCompetitionLevel ~= true then return end

    self:reportOfflineMatchScore({
        playerNo = competitionInfo.playerNo,
        sessionId = competitionInfo.sessionId or competitionInfo.roundId,
        levelId = data.levelId or competitionInfo.levelId,
        levelScene = data.levelScene or competitionInfo.levelScene,
        passed = data.isWin,
        score = data.score,
        gemCount = data.gemCount or competitionInfo.gemCount or competitionInfo.collectCount,
        duration = data.duration or competitionInfo.duration or competitionInfo.finishTime,
        matchStartTime = competitionInfo.matchStartTime,
    })
end

function CompetitionTransferManager:handleLaunchOptions()
    return self:tryHandleLaunchEntry("launch_options")
end

function CompetitionTransferManager:tryHandleLaunchEntry(source, openDirect)
    if not self:isEnabled() then
        logAuditionsEntry("disabled", nil, tostring(source) .. "," .. tostring(self:getDisabledReason()))
        return false
    end

    local query = self:getLaunchQuery()
    if not query then
        logAuditionsEntry("no_launch_query", nil, source)
        return false
    end

    local handled
    if openDirect then
        handled = self:tryOpenLaunchEntry(query, source)
    else
        handled = self:tryAddLaunchEntryPopup(query, source)
    end
    if handled then
        self:clearAppLaunchQuery()
    end
    return handled
end

function CompetitionTransferManager:tryAddLaunchEntryPopup(params, source)
    if not self:isEnabled() then
        logAuditionsEntry("add_popup_disabled", params, tostring(source) .. "," .. tostring(self:getDisabledReason()))
        return false
    end

    local rawParams = params
    local reason
    params, reason = self:normalizeLaunchEntryParams(params)
    if not params then
        logAuditionsEntry(reason or "invalid_launch_params", rawParams, source)
        return false
    end

    local entryType = self:getEntryType(params)
    if entryType == CompetitionTransferManager.EntryType.AUDITIONS then
        logAuditionsEntry("add_popup", params, source)
        self:addAuditionsEntryPopup(params)
        return true
    end

    logAuditionsEntry("entry_type_not_auditions", params, "entryType=" .. tostring(entryType))
    return false
end

function CompetitionTransferManager:tryOpenLaunchEntry(params, source)
    if not self:isEnabled() then
        logAuditionsEntry("open_direct_disabled", params, tostring(source) .. "," .. tostring(self:getDisabledReason()))
        return false
    end

    local rawParams = params
    local reason
    params, reason = self:normalizeLaunchEntryParams(params)
    if not params then
        logAuditionsEntry(reason or "invalid_direct_open_params", rawParams, source)
        return false
    end

    local entryType = self:getEntryType(params)
    if entryType == CompetitionTransferManager.EntryType.AUDITIONS then
        logAuditionsEntry("open_direct", params, source)
        self:openAuditionsEntry(params)
        return true
    end

    logAuditionsEntry("direct_open_entry_type_not_auditions", params, "entryType=" .. tostring(entryType))
    return false
end

function CompetitionTransferManager:handleLaunchQuery(params)
    if not self:isEnabled() then
        logAuditionsEntry("handle_query_disabled", params, self:getDisabledReason())
        return false
    end

    local rawParams = params
    local reason
    params, reason = self:normalizeLaunchEntryParams(params)
    if not params then
        logAuditionsEntry(reason or "handle_query_invalid", rawParams)
        return false
    end

    local entryType = self:getEntryType(params)
    if entryType == CompetitionTransferManager.EntryType.AUDITIONS then
        logAuditionsEntry("handle_query_open_direct", params)
        self:openAuditionsEntry(params)
        return true
    end

    logAuditionsEntry("handle_query_entry_type_not_auditions", params, "entryType=" .. tostring(entryType))
    return false
end

function CompetitionTransferManager:getEntryType(params)
    params = params or {}
    return tostring(params.type or params.entryType or params.competitionType or "")
end

function CompetitionTransferManager:normalizeLaunchEntryParams(params, method)
    if type(params) ~= "table" then
        return nil, "invalid_params_type:" .. tostring(type(params))
    end

    local entryType = self:getEntryType(params)
    method = tostring(method or params.method or params.m or params.action or "")

    if entryType == "" then
        entryType = self:getEntryTypeByLaunchMethod(method)
    end

    if entryType == "" then
        return nil, "missing_entry_type:method=" .. tostring(method)
    end

    entryType = self:normalizeEntryType(entryType)
    if entryType ~= CompetitionTransferManager.EntryType.AUDITIONS then
        return nil, "unsupported_entry_type:" .. tostring(entryType)
    end

    local normalized = table.clone(params)
    normalized.type = entryType
    normalized.entryType = normalized.entryType or entryType
    normalized.competitionType = normalized.competitionType or entryType
    normalized.levelId = normalized.levelId or normalized.levelid or normalized.level or normalized.lid
    normalized.matchId = normalized.matchId or normalized.matchid or normalized.matchNo or normalized.mid
    normalized.roundId = normalized.roundId or normalized.roundid or normalized.roundNo or normalized.rid
    normalized.playerNo = normalized.playerNo or normalized.playerno or normalized.participantNo or normalized.participantno or normalized.pno
    normalized.sessionId = normalized.sessionId or normalized.roundId

    return normalized
end

function CompetitionTransferManager:getEntryTypeByLaunchMethod(method)
    method = tostring(method or "")
    if method == "competition_auditions"
        or method == "competitionAuditions"
        or method == "auditions"
        or method == "offline_match_haixuan"
        or method == "offlineMatchHaixuan"
        or method == "offline_match_2026_auditions" then
        return CompetitionTransferManager.EntryType.AUDITIONS
    end

    if method == "competition"
        or method == "competition_transfer"
        or method == "offline_match_2026" then
        return CompetitionTransferManager.EntryType.AUDITIONS
    end

    return ""
end

function CompetitionTransferManager:normalizeEntryType(entryType)
    entryType = tostring(entryType or "")
    if entryType == "haixuan"
        or entryType == "audition"
        or entryType == "auditions"
        or entryType == "qualify"
        or entryType == "qualification" then
        return CompetitionTransferManager.EntryType.AUDITIONS
    end
    return entryType
end

function CompetitionTransferManager:getLaunchQuery()
    if not self:isEnabled() then
        logAuditionsEntry("get_launch_query_disabled", nil, self:getDisabledReason())
        return nil
    end
    return self:getAppLaunchQuery()
end

function CompetitionTransferManager:getAppLaunchQuery()
    if not LaunchUrlManager then
        logAuditionsEntry("no_launch_url_manager")
        return nil
    end

    local launchManager = LaunchUrlManager:getInstance()
    local launchUrl = launchManager:getParsedLaunchUrl()
    if type(launchUrl) ~= "table" or type(launchUrl.para) ~= "table" then
        local rawUrl = launchManager:getTempOpenUrl()
        local source = "temp_url"
        if not rawUrl or rawUrl == "" then
            rawUrl = launchManager:getCurrentUrl()
            source = "current_url"
        end
        if (not rawUrl or rawUrl == "") and launchManager.getLaunchUrlFromUnityEnterOptions then
            rawUrl = launchManager:getLaunchUrlFromUnityEnterOptions()
            source = "unity_url"
        end
        if rawUrl and rawUrl ~= "" then
            logAuditionsEntry("parse_launch_url", nil, source)
            launchManager:handleUrl(rawUrl)
            launchUrl = launchManager:getParsedLaunchUrl()
        end
    end

    if type(launchUrl) ~= "table" or type(launchUrl.para) ~= "table" then
        if launchManager.getLaunchQueryFromUnityEnterOptions then
            local query = launchManager:getLaunchQueryFromUnityEnterOptions()
            if type(query) == "table" then
                logAuditionsEntry("use_unity_query", query)
                return query
            end
        end
        logAuditionsEntry("no_valid_launch_query")
        return nil
    end

    local query = table.clone(launchUrl.para)
    query.method = launchUrl.method
    logAuditionsEntry("use_parsed_launch_url", query)
    return query
end

function CompetitionTransferManager:clearAppLaunchQuery()
    if LaunchUrlManager and LaunchUrlManager.getInstance then
        logAuditionsEntry("clear_launch_query")
        local launchManager = LaunchUrlManager:getInstance()
        launchManager:clearLaunchUrl()
        launchManager:clearTempOpenUrl()
    end
end

function CompetitionTransferManager:buildCompetitionLevelExtraData(competitionType, params)
    params = params or {}
    local extraData = {
        isCompetitionLevel = true,
        competitionType = competitionType,
        levelId = params.levelId,
        matchId = params.matchId,
        roundId = params.roundId,
        playerNo = params.playerNo or params.participantNo,
        sessionId = params.sessionId or params.roundId,
        matchStartTime = TimeKit and TimeKit:timeInSec() or os.time(),
    }

    if competitionType == CompetitionTransferManager.EntryType.OFFLINE_MATCH then
        extraData.offlineMatchContext = self:buildOfflineMatchContext(params)
    end

    return extraData
end

function CompetitionTransferManager:getAuditionsEntryPopupCheckPoint()
    return PopupCheckPoint and PopupCheckPoint.COMPETITION_AUDITIONS_ENTRY
end

function CompetitionTransferManager:addAuditionsEntryPopup(params)
    local autoPopupMgr = _G.amfBean("AutoPopupMgr")
    local popupCheckPoint = self:getAuditionsEntryPopupCheckPoint()
    if not autoPopupMgr or not popupCheckPoint then
        logAuditionsEntry("open_direct_no_autopop", params, "popupCheckPoint=" .. tostring(popupCheckPoint))
        self:openAuditionsEntry(params)
        return
    end

    local function onHandleOver()
        logAuditionsEntry("popup_over", params)
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, popupCheckPoint)
    end

    local function creator()
        logAuditionsEntry("popup_create", params)
        self:openAuditionsEntry(params, onHandleOver)
    end

    autoPopupMgr:addPopupConfig(popupCheckPoint, creator)
    logAuditionsEntry("queue_popup", params, "popupCheckPoint=" .. tostring(popupCheckPoint))
end

function CompetitionTransferManager:openAuditionsEntry(params, onHandleOver)
    if not self:isEnabled() then
        logAuditionsEntry("open_entry_disabled", params, self:getDisabledReason())
        return
    end

    if self:hasFilledAuditionsInfo() then
        logAuditionsEntry("skip_info_panel_already_filled_open_level", params)
        self:openAuditionsLevel(params)
        safeRunCall(onHandleOver)
        return
    end

    logAuditionsEntry("open_info_panel", params)
    self:openCompetitionInfoPanel(CompetitionTransferManager.EntryType.AUDITIONS, params, function(info)
        logAuditionsEntry("info_filled_open_level", params)
        self:markAuditionsInfoFilled(info)
        self:openAuditionsLevel(self:buildAuditionsLevelParams(params))
    end, onHandleOver)
end

function CompetitionTransferManager:hasFilledAuditionsInfo()
    return self._hasFilledAuditionsInfo == true
end

function CompetitionTransferManager:getAuditionsInfo()
    return self._auditionsInfo or {}
end

function CompetitionTransferManager:markAuditionsInfoFilled(info)
    self._auditionsInfo = self:normalizeCompetitionInfo(info)
    self._hasFilledAuditionsInfo = true
end

function CompetitionTransferManager:buildAuditionsLevelParams(params)
    params = table.clone(params or {})
    local info = self:getAuditionsInfo()
    params.playerNo = params.playerNo or info.playerNo
    params.sessionId = params.sessionId or params.roundId or info.sessionId
    return params
end

function CompetitionTransferManager:openCompetitionInfoPanel(competitionType, params, onFilled, closeCallback)
    if not self:isEnabled() then return end
    if competitionType == CompetitionTransferManager.EntryType.OFFLINE_MATCH and not self:isOfflineMatchEnabled() then return end

    local CompetitionInfoPanelVM = require_debug "amf.feature.competition.view.CompetitionInfoPanelVM"
    local vm = CompetitionInfoPanelVM.Builder.new()
        :setCompetitionType(competitionType)
        :setParams(params)
        :setOnFilled(onFilled)
        :setSubmitHandler(function(info, done, fail)
            self:submitCompetitionInfo(competitionType, params, info, done, fail)
        end)
        :setCloseCallback(closeCallback)
        :build()
    vm:popout()
end

function CompetitionTransferManager:showOfflineMatchEntryPanel(delegate)
    if not self:isOfflineMatchEnabled() then return end

    local OfflineMatchEntryPanelVM = require_debug "amf.feature.competition.view.OfflineMatchEntryPanelVM"
    local vm = OfflineMatchEntryPanelVM.Builder.new()
        :setDelegate(delegate or {})
        :build()
    vm:popout()
end

function CompetitionTransferManager:openOfflineMatchLevel(levelId)
    if not self:isOfflineMatchEnabled() then return false end

    levelId = tonumber(levelId)
    if not levelId or levelId <= 0 then return false end
    if not self:hasFilledOfflineMatchInfo() then
        self:openCompetitionInfoPanel(CompetitionTransferManager.EntryType.OFFLINE_MATCH, {
            levelId = levelId,
        }, function(info)
            self:markOfflineMatchInfoFilled(info)
            self:openOfflineMatchLevel(levelId)
        end)
        return true
    end

    require "amf.feature.mainscene.world.logic.playlevel.PlayLevelContext"
    local playLevelContext = PlayLevelContext.new(levelId, PlayLevelContext.PlayType.OPEN_SL_PANEL)
    if playLevelContext.setLevelScene then
        local levelScene = (LevelScene and LevelScene.kMain) or (UBFLevelSceneType and UBFLevelSceneType.kMain)
        playLevelContext:setLevelScene(levelScene)
    end
    local info = self:getOfflineMatchInfo()
    local levelScene = playLevelContext.levelScene
    local contextData = self:buildCompetitionLevelExtraData(CompetitionTransferManager.EntryType.OFFLINE_MATCH, {
        levelId = levelId,
        levelScene = levelScene,
        playerNo = info.playerNo,
        sessionId = info.sessionId,
        nickName = info.nickName,
        phone = info.phone,
        deviceNo = info.deviceNo,
    })
    playLevelContext:setExtraData(contextData)
    _G.amfTransaction(TransactionEvent.PLAY_LEVEL, playLevelContext)
    return true
end

function CompetitionTransferManager:openAuditionsLevel(params)
    if not self:isEnabled() then return end
    params = self:buildAuditionsLevelParams(params)
    local extraData = self:buildCompetitionLevelExtraData(CompetitionTransferManager.EntryType.AUDITIONS, params)
    logAuditionsEntry("open_auditions_level", params)
    UBFProcessManager:launch(UBFGameProcessEnum.NORMAL_START, {
        levelId = 26,
        levelScene = UBFLevelSceneType.kOfflineMatchHaixuan,
        extra = extraData,
    })
end

function CompetitionTransferManager:reportOfflineMatchScore(params, successCallback, failCallback, cancelCallback)
    if not self:isEnabled() then
        safeRunCall(failCallback)
        return nil
    end

    params = params or {}
    local reqParams = self:buildOfflineMatchScoreParams(params)
    if not reqParams then
        safeRunCall(failCallback)
        return nil
    end

    local Request = require "amf.feature.competition.http.OfflineMatch2026ReportScore"
    local loading = params.loading
    if loading == nil then loading = false end

    return Request:post(reqParams, loading):next(function(evt)
        safeRunCall(successCallback, evt and evt.data or {})
    end, function(response)
        if response and response.isCancel and response:isCancel() then
            safeRunCall(cancelCallback)
        else
            safeRunCall(failCallback, response)
        end
    end)
end

function CompetitionTransferManager:buildOfflineMatchScoreParams(params)
    if not self:isEnabled() then return nil end
    if not params then return nil end

    local context = self:getOfflineMatchContext()
    local levelId = params.levelId or params.levelid
    if levelId == nil then
        ALog.error("CompetitionTransferManager:reportOfflineMatchScore levelId is nil")
        return nil
    end

    local now = TimeKit and TimeKit:timeInSec() or os.time()
    local startTime = tonumber(context.matchStartTime or params.matchStartTime) or now
    local reqParams = {
        playerNo = params.playerNo or context.playerNo,
        sessionId = params.sessionId or context.sessionId,
        levelScene = params.levelScene or context.levelScene,
        levelId = levelId,
        gemCount = tonumber(params.gemCount or context.gemCount) or 0,
        score = params.score or params.passScore or params.levelScore,
        passed = self:normalizeBoolValue(params.passed),
        duration = tonumber(params.duration or context.duration) or math.max(now - startTime, 0),
    }
    if not reqParams.playerNo or reqParams.playerNo == "" then
        ALog.error("CompetitionTransferManager:reportOfflineMatchScore playerNo is nil")
        return nil
    end

    return reqParams
end

function CompetitionTransferManager:submitCompetitionInfo(competitionType, params, info, successCallback, failCallback)
    if competitionType == CompetitionTransferManager.EntryType.OFFLINE_MATCH then
        return self:registerOfflineMatchStage(info, successCallback, failCallback)
    elseif competitionType == CompetitionTransferManager.EntryType.AUDITIONS then
        return self:registerOfflineMatchQualify(info, successCallback, failCallback)
    end

    safeRunCall(successCallback)
end

function CompetitionTransferManager:normalizeCompetitionInfo(info)
    info = info or {}
    return {
        playerNo = info.playerNo or info.participantNo,
        sessionId = info.sessionId or info.roundNo,
        nickName = info.nickName or info.nickname,
        phone = info.phone,
        deviceNo = info.deviceNo or info.officialDeviceNo,
    }
end

function CompetitionTransferManager:registerOfflineMatchQualify(info, successCallback, failCallback)
    local normalized = self:normalizeCompetitionInfo(info)
    local Request = require "amf.feature.competition.http.OfflineMatch2026RegisterQualify"
    return Request:post({
        playerNo = normalized.playerNo,
    }, true):next(function(evt)
        safeRunCall(successCallback, evt and evt.data or {})
    end, function(response)
        self:showCompetitionRequestError(response)
        safeRunCall(failCallback, response)
    end)
end

function CompetitionTransferManager:registerOfflineMatchStage(info, successCallback, failCallback)
    local normalized = self:normalizeCompetitionInfo(info)
    local Request = require "amf.feature.competition.http.OfflineMatch2026RegisterStage"
    return Request:post({
        playerNo = normalized.playerNo,
        sessionId = normalized.sessionId,
        nickName = normalized.nickName,
        phone = normalized.phone,
        deviceNo = normalized.deviceNo,
    }, true):next(function(evt)
        self:markOfflineMatchInfoFilled(normalized)
        safeRunCall(successCallback, evt and evt.data or {})
    end, function(response)
        self:showCompetitionRequestError(response)
        safeRunCall(failCallback, response)
    end)
end

function CompetitionTransferManager:showCompetitionRequestError(response)
    local errorCode = response and response.getErrorCode and response:getErrorCode()
    if errorCode and Localization and Localization.getInstance then
        CommonTip:showTip(Localization:getInstance():getText("error.tip." .. tostring(errorCode)))
    else
        CommonTip:showTip(CompetitionTipConfig:getText("requestFailed"))
    end
end

function CompetitionTransferManager:hasFilledOfflineMatchInfo()
    return self._offlineMatchInfo ~= nil
end

function CompetitionTransferManager:getOfflineMatchInfo()
    return self._offlineMatchInfo or {}
end

function CompetitionTransferManager:markOfflineMatchInfoFilled(info)
    self._offlineMatchInfo = self:normalizeCompetitionInfo(info)
end

function CompetitionTransferManager:buildOfflineMatchContext(params)
    params = params or {}
    return {
        isCompetitionLevel = true,
        competitionType = CompetitionTransferManager.EntryType.OFFLINE_MATCH,
        levelId = params.levelId,
        levelScene = params.levelScene,
        playerNo = params.playerNo,
        sessionId = params.sessionId,
        nickName = params.nickName,
        phone = params.phone,
        deviceNo = params.deviceNo,
        matchStartTime = TimeKit and TimeKit:timeInSec() or os.time(),
    }
end

function CompetitionTransferManager:getOfflineMatchContext()
    local info = self:getOfflineMatchInfo()
    return self:buildOfflineMatchContext({
        playerNo = info.playerNo,
        sessionId = info.sessionId,
        nickName = info.nickName,
        phone = info.phone,
        deviceNo = info.deviceNo,
    })
end

function CompetitionTransferManager:normalizeBoolValue(value)
    if value == nil then return nil end
    if type(value) == "boolean" then
        return value
    end
    if type(value) == "number" then
        return value ~= 0
    end
    if type(value) == "string" then
        return value == "true" or value == "1"
    end
    return false
end

return CompetitionTransferManager
