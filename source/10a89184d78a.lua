local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"
local ProgressCalculator = require "amf.feature.localactivity.happymatch.model.HappyMatchProgressCalculator"
local SecondRewardPanelVM = require "amf.middleware.ui.kit.commonpanel.view.SecondRewardPanelVM"
require "amf.middleware.autopop.config.AutoPopupConst"
require "amf.middleware.ui.kit.component.uitip.UITip"

local LOTTERY_CHANCE = {
    MIN = 0,
    CONSUME_COUNT = 1,
}

local SHARE_TEXT_INDEX = {
    DEFAULT = 1,
}

local SHARE_WB_PARAM = {
    LINK_TYPE = 1,
    PIC_TYPE = 2,
}

local NUMBER_VALUE = {
    ZERO = 0,
    ONE = 1,
    TWO = 2,
}

local HAPPY_MATCH_WEIBO = {
    TOPIC = "#碰出蒸好运##开心消消乐#",
    SUPER_GROUP_NAME = "开心消消乐",
    SECOND_NAME = "对对碰",
}

local SHARE_TEXT_META_TYPE = {
    WX_TOKEN = 1,
    WEIBO = 2,
    MINI_CARD = 3,
}

local OPEN_WECHAT_DELAY = 0.5

local YIN_LIU_CONFIG = {
    DAILY_POP_LIMIT = 3,
    NEXT_POP_PASS_LEVEL_COUNT = 3,
    DRAW_TICKET_COST = 10,
    REAL_REWARD_ITEM_ID = 80282,
    PANEL_TITLE = "开心对对碰",
    PANEL_1_SUB_TITLE = "参与开心对对碰活动参与盲盒对碰，抽取\n实物奖励",
    PANEL_2_SUB_TITLE = "前往活动领取奖励，参与抽奖还有机会获\n得实物奖励",
    PANEL_1_BUTTON_TEXT = "去看看",
    PANEL_2_BUTTON_TEXT = "去领奖",
    PANEL_2_BUTTON_RED_DOT_TEXT = "奖",
    PANEL_1_FROM = "happy_match_yinliu_1",
    PANEL_2_FROM = "happy_match_yinliu_2",
    PANEL_COLOR_TYPE = _G.PanelColorConst.ColorType.kBlue,
    TEXT_ALIGN_LEFT = 0,
    POP_COUNT_CACHE_KEY = "yinLiuPopCount",
    LAST_POP_LEVEL_CACHE_KEY = "yinLiuLastPopLevelId",
    REWARD_TIP_AUTO_CLOSE_TIME = 3,
    REWARD_TIP_FALLBACK_TEXT = "奖励",
}

local MAIN_PANEL_SCENE4_POP_CONFIG = {
    CACHE_KEY = "mainPanelScene4Pop",
    FROM = "happy_match_scene4_main_panel",
}

local DC_TASK_SUCCESS_CACHE_KEY = "dcTaskSuccessMap"

local ATTRACT_PANEL_DC_ENTRY = {
    [YIN_LIU_CONFIG.PANEL_1_FROM] = "drainage_collect_coin",
    [YIN_LIU_CONFIG.PANEL_2_FROM] = "drainage_node_reward",
}

local function getYinLiuCheckPoint()
    return _G.PopupCheckPoint and _G.PopupCheckPoint.HAPPY_MATCH_YINLIU_STAGE4 or "pcp_happy_match_yinliu_stage4"
end

local function addYinLiuSureBtnRedDot(vm, redDotText)
    if not redDotText or not vm or not vm.view or not vm.view.sureBtn then return end

    local sureBtn = vm.view.sureBtn
    if type(sureBtn.addRedDot) == "function" then
        sureBtn:addRedDot(redDotText)
    end
end

local TASK_TYPE = {
    HELP_FRIEND = 1,
    GET_TICKET = 2,
    LOTTERY = 3,
}

local TASK_PROGRESS_FIELD_BY_TYPE = {
    [TASK_TYPE.HELP_FRIEND] = "helpFriendNum",
    [TASK_TYPE.GET_TICKET] = "gainTicketByHelpNum",
    [TASK_TYPE.LOTTERY] = "lotteryNum",
}

local TASK_PROGRESS_REWARD = {
    itemId = _G.FlowerSkinType.kHappyMatch2026,
    num = NUMBER_VALUE.ONE,
}

local SHARE_HELP_RESULT_TYPE = {
    SUCCESS = NUMBER_VALUE.ONE,
    FAIL = NUMBER_VALUE.TWO,
}

local function toNumberOrNil(value)
    if value == nil then return nil end
    return tonumber(value)
end

local function unwrapYinLiuStageParams(stageParams)
    if stageParams and type(stageParams.getData) == "function" then
        return stageParams:getData()
    end
    return stageParams
end

local Manager = class("HappyMatchManager", BaseFeatureManager)

function Manager:_getConstPath()
    return "amf.feature.localactivity.happymatch.config.HappyMatchConst"
end

function Manager:_getModelPath()
    return "amf.feature.localactivity.happymatch.model.HappyMatchModel"
end

function Manager:_getExtraPlugsConfigList()
    return {
        {
            key = "DC",
            path = {
                plugPath = "amf.middleware.activity.base.plug.DCPlug",
            },
        },
        {
            key = "Rewards",
        },
    }
end

function Manager:_init()
    self._yinLiuLoginExemptUsed = false
    self._dc = require("amf.feature.localactivity.happymatch.dc.HappyMatchDC")
    self._dc:init(self)
    self:addEventDispatcher("onAct")
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
    self._responseHelpHandler = require("amf.feature.localactivity.happymatch.share.ResponseHappyMatchHelpShareHandler"):create()
end

function Manager:dcPlug()
    return self:_getPlug("DC")
end

function Manager:getDC()
    return self._dc
end

function Manager:setAutoPopupMgr(autoPopupMgr)
    self.autoPopupMgr = autoPopupMgr
    self:_registerYinLiuAutoPopup()
end

-- 同步所有数据
function Manager:updateData(data, fromServer)
    if not data then return end
    self:getModel():syncMainInfo(data)
end

function Manager:getDataByKey(key, default)
    return self:getModel():getDataByKey(key, default)
end

function Manager:setDataByKey(key, value, needSave)
    return self:getModel():setDataByKey(key, value, needSave)
end

function Manager:getConfigByKey(key, default)
    return self:getModel():getConfigByKey(key, default)
end

function Manager:setLocalCache(key, needTime, value)
    return self:getModel():setLocalCache(key, needTime, value)
end

function Manager:getLocalCache(key, needTime)
    return self:getModel():getLocalCache(key, needTime)
end

function Manager:getClientMd5()
    return self:getModel():getClientMd5()
end

function Manager:getContact()
    return self:getModel():getContact()
end

function Manager:setContact(contact, needSave)
    return self:getModel():setContact(contact, needSave)
end

function Manager:getRealRewardList()
    return self:getModel():getRealRewardList()
end

function Manager:setRealRewardList(realRewardList, needSave)
    return self:getModel():setRealRewardList(realRewardList, needSave)
end

function Manager:addRealRewardItemId(itemId, needSave)
    return self:getModel():addRealRewardItemId(itemId, needSave)
end

function Manager:hasRealRewardItem(itemId)
    return self:getModel():hasRealRewardItem(itemId)
end

function Manager:hasRealReward()
    return self:getModel():hasRealReward()
end

function Manager:getGuideIdSet()
    return self:getModel():getGuideIdSet()
end

function Manager:setGuideIdSet(guideIdSet, needSave)
    return self:getModel():setGuideIdSet(guideIdSet, needSave)
end

function Manager:hasGuideIndex(index)
    return self:getModel():hasGuideIndex(index)
end

function Manager:addGuideIndex(index, needSaveLocal)
    local hasAdded = self:getModel():addGuideIndex(index, needSaveLocal)
    if hasAdded then
        local ActCommonHttp = require "amf.middleware.activity.http.ActCommonHttp"
        ActCommonHttp:setActGuideFlag(self:getConst().actId, index)
    end
    return hasAdded
end

function Manager:getTaskMetaList()
    return self:getModel():getTaskMetaList()
end

function Manager:getTaskProgressData()
    return self:getModel():getTaskProgressData()
end

function Manager:setTaskProgressData(taskProgressData, needSave)
    return self:getModel():setTaskProgressData(taskProgressData, needSave)
end

function Manager:getTaskMap()
    return self:getModel():getTaskMap()
end

function Manager:setTaskMap(taskMap, needSave)
    return self:getModel():setTaskMap(taskMap, needSave)
end

function Manager:isTaskProgressRewardReceived()
    return self:getModel():isTaskProgressRewardReceived()
end

function Manager:setTaskProgressRewardReceived(received, needSave)
    return self:getModel():setTaskProgressRewardReceived(received, needSave)
end

function Manager:getGeneratedAnimalCount(default)
    return self:getModel():getGeneratedAnimalCount(default)
end

function Manager:setGeneratedAnimalCount(generatedAnimalCount, needSave)
    return self:getModel():setGeneratedAnimalCount(generatedAnimalCount, needSave)
end

function Manager:getTotalGeneratedAnimalCount(default)
    return self:getModel():getTotalGeneratedAnimalCount(default)
end

function Manager:setTotalGeneratedAnimalCount(totalGeneratedAnimalCount, needSave)
    return self:getModel():setTotalGeneratedAnimalCount(totalGeneratedAnimalCount, needSave)
end

function Manager:recordGeneratedAnimalCount(generatedAnimalCount, needSave)
    return self:getModel():recordGeneratedAnimalCount(generatedAnimalCount, needSave)
end

function Manager:getShareHelpDayDataMap()
    return self:getModel():getShareHelpDayDataMap()
end

function Manager:isTaskTypeSupported(taskType)
    return self:getModel():isTaskTypeSupported(taskType)
end

function Manager:getTaskProgressByType(taskType)
    return self:getModel():getTaskProgressByType(taskType)
end

function Manager:isTaskRewardReceived(taskId)
    return self:getModel():isTaskRewardReceived(taskId)
end

function Manager:_getDcTaskSuccessMap()
    local successMap = self:getLocalCache(DC_TASK_SUCCESS_CACHE_KEY)
    if type(successMap) ~= "table" then
        successMap = {}
    end
    return successMap
end

function Manager:_markDcTaskSuccess(taskId, successMap)
    if taskId == nil then return end

    successMap = type(successMap) == "table" and successMap or self:_getDcTaskSuccessMap()
    successMap[tostring(taskId)] = true
    self:setLocalCache(DC_TASK_SUCCESS_CACHE_KEY, nil, successMap)
end

function Manager:_hasDcTaskSuccess(taskId, successMap)
    if taskId == nil then return true end

    successMap = type(successMap) == "table" and successMap or self:_getDcTaskSuccessMap()
    return successMap[tostring(taskId)] == true
end

function Manager:checkAndDcTaskPanelSuccess()
    local taskMetaList = self:getTaskMetaList() or {}
    if type(taskMetaList) ~= "table" then return end

    local dc = self:getDC()
    if not dc or type(dc.dcTaskPanelSuccess) ~= "function" then return end

    local successMap = self:_getDcTaskSuccessMap()
    for _, taskMeta in ipairs(taskMetaList) do
        if self:_isTaskMetaCompleted(taskMeta) then
            local taskId = type(taskMeta) == "table" and (toNumberOrNil(taskMeta.taskId) or taskMeta.taskId) or nil
            if taskId ~= nil and not self:_hasDcTaskSuccess(taskId, successMap) then
                if dc:dcTaskPanelSuccess(taskId) then
                    self:_markDcTaskSuccess(taskId, successMap)
                end
            end
        end
    end
end

function Manager:getTicketHelpReceivedCountByDay(dayIndex)
    return self:getModel():getTicketHelpReceivedCountByDay(dayIndex)
end

function Manager:getPendingTicketHelpSuccessSummary()
    return self:getModel():getPendingTicketHelpSuccessSummary()
end

function Manager:markTicketHelpSuccessShown(summary)
    return self:getModel():markTicketHelpSuccessShown(summary)
end

function Manager:_getActivityTime()
    local const = self:getConst() or {}
    return self:getModel():getValue(const.timePrefix or "activityTime") or {}
end

function Manager:_isMainTime()
    local activityTime = self:_getActivityTime()
    local nowTime = TimeKit:timeInSec()
    local mainBeginTime = toNumberOrNil(activityTime.mainBeginTime) or NUMBER_VALUE.ZERO
    local mainEndTime = toNumberOrNil(activityTime.mainEndTime) or NUMBER_VALUE.ZERO
    return nowTime >= mainBeginTime and nowTime <= mainEndTime
end

function Manager:_isAwardTime()
    local activityTime = self:_getActivityTime()
    local nowTime = TimeKit:timeInSec()
    local mainEndTime = toNumberOrNil(activityTime.mainEndTime) or NUMBER_VALUE.ZERO
    local endTime = toNumberOrNil(activityTime.endTime) or NUMBER_VALUE.ZERO
    return nowTime > mainEndTime and nowTime <= endTime
end

function Manager:_isTaskMetaCompleted(taskMeta)
    if type(taskMeta) ~= "table" then return false end

    local taskType = toNumberOrNil(taskMeta.taskType)
    if not self:isTaskTypeSupported(taskType) then return false end

    local target = toNumberOrNil(taskMeta.taskTarget)
    if not target then return false end

    local current = toNumberOrNil(self:getTaskProgressByType(taskType)) or NUMBER_VALUE.ZERO
    return current >= target
end

function Manager:hasUnclaimedTaskReward()
    local taskMetaList = self:getTaskMetaList() or {}
    for _, taskMeta in ipairs(taskMetaList) do
        local taskId = type(taskMeta) == "table" and (toNumberOrNil(taskMeta.taskId) or taskMeta.taskId) or nil
        if taskId ~= nil and self:_isTaskMetaCompleted(taskMeta) and not self:isTaskRewardReceived(taskId) then
            return true
        end
    end
    return false
end

function Manager:_getTaskRewardReceivedProgress()
    local taskMetaList = self:getTaskMetaList() or {}
    local totalTaskCount = NUMBER_VALUE.ZERO
    local receivedTaskCount = NUMBER_VALUE.ZERO
    for _, taskMeta in ipairs(taskMetaList) do
        if type(taskMeta) == "table" then
            local taskId = toNumberOrNil(taskMeta.taskId) or taskMeta.taskId
            if taskId ~= nil and self:isTaskTypeSupported(toNumberOrNil(taskMeta.taskType)) then
                totalTaskCount = totalTaskCount + NUMBER_VALUE.ONE
                if self:isTaskRewardReceived(taskId) then
                    receivedTaskCount = receivedTaskCount + NUMBER_VALUE.ONE
                end
            end
        end
    end
    return receivedTaskCount, totalTaskCount
end

function Manager:hasUnclaimedTaskProgressReward()
    local receivedTaskCount, totalTaskCount = self:_getTaskRewardReceivedProgress()
    return totalTaskCount > NUMBER_VALUE.ZERO
        and receivedTaskCount >= totalTaskCount
        and not self:isTaskProgressRewardReceived()
end

function Manager:hasPendingTicketHelpSuccess()
    local summary = self:getPendingTicketHelpSuccessSummary()
    return type(summary) == "table" and (toNumberOrNil(summary.helpCount) or NUMBER_VALUE.ZERO) > NUMBER_VALUE.ZERO
end

function Manager:hasRealLotteryReward()
    return self:getRealLotteryChance() > LOTTERY_CHANCE.MIN
end

function Manager:getMsgNum()
    if not self:_isMainTime() then
        return LOTTERY_CHANCE.MIN
    end

    return tonumber(self:getTicketNum(LOTTERY_CHANCE.MIN)) or LOTTERY_CHANCE.MIN
end

function Manager:hasMainTimeReward()
    return self:hasUnclaimedTaskReward()
        or self:hasUnclaimedTaskProgressReward()
        or self:hasPendingTicketHelpSuccess()
        or self:hasRealLotteryReward()
        or (self:hasRealReward() and not self:getContact())
end

function Manager:hasAwardTimeReward()
    return self:hasUnclaimedTaskReward()
        or self:hasUnclaimedTaskProgressReward()
        or (self:hasRealReward() and not self:getContact())
end

function Manager:hasReward()
    if self:_isMainTime() then
        return self:hasMainTimeReward()
    end
    if self:_isAwardTime() then
        return self:hasAwardTimeReward()
    end
    return false
end

function Manager:getShareTextMetaList()
    return self:getModel():getShareTextMetaList()
end

function Manager:getTicketHelpWXTokenTextList()
    return self:_getShareTextListByMetaType(SHARE_TEXT_META_TYPE.WX_TOKEN)
end

function Manager:getTicketHelpWeiboTextList()
    return self:_getShareTextListByMetaType(SHARE_TEXT_META_TYPE.WEIBO)
end

function Manager:getTicketHelpMiniCardTextList()
    return self:_getShareTextListByMetaType(SHARE_TEXT_META_TYPE.MINI_CARD)
end

function Manager:_getShareTextListByMetaType(metaType)
    local shareTextMetaList = self:getShareTextMetaList()
    local textList = {}
    for _, meta in ipairs(shareTextMetaList) do
        if type(meta) == "table" and tonumber(meta.type) == metaType and type(meta.text) == "string" and meta.text ~= "" then
            table.insert(textList, meta.text)
        end
    end
    return textList
end

function Manager:isSupportShare()
    if not ShareCenterUtil:isSupportShare() then
        return false
    end
    if EnvUtil:isOhos() then
        return false
    end
    if EnvUtil:isMiniGame() then
        return EnvUtil:isWXMiniGame() or EnvUtil:isDYMiniGame()
    end
    return true
end

function Manager:_getShareText(textList)
    if type(textList) ~= "table" or table.isEmpty(textList) then
        return "", SHARE_TEXT_INDEX.DEFAULT
    end

    local textIndex = math.random(SHARE_TEXT_INDEX.DEFAULT, #textList)
    return textList[textIndex], textIndex
end

function Manager:_getTicketHelpKVData(textIndex, panelId)
    return {
        t5 = textIndex,
        --panel_id = panelId,
        xxlId = _G.amfBean("ProfileManager"):getXxlId(),
    }
end

function Manager:_showTicketHelpFailTip(shareConfig)
    shareConfig = shareConfig or {}
    CommonTip:showTip(shareConfig.shareFailTip or "")
end

function Manager:_makeTicketHelpShareCallback(needOpenWechat, shareConfig)
    shareConfig = shareConfig or {}
    local onSuccess = function()
        CommonTip:showTip(shareConfig.shareSuccessTip or "")
        if needOpenWechat then
            TimerUtil.addAlarm(function()
                self:openWechatForTicketHelp()
            end, OPEN_WECHAT_DELAY)
        end
    end
    local onFail = function()
        self:_showTicketHelpFailTip(shareConfig)
    end
    return onSuccess, onFail, onFail
end

function Manager:_dcShareHelpResultVx()
    local dc = self:getDC()
    if dc and type(dc.dcShareHelpResultVx) == "function" then
        dc:dcShareHelpResultVx()
    end
end

function Manager:_dcShareHelpResultVb(result)
    local dc = self:getDC()
    if dc and type(dc.dcShareHelpResultVb) == "function" then
        dc:dcShareHelpResultVb(result)
    end
end

function Manager:_dcShareHelpResultDy(result)
    local dc = self:getDC()
    if dc and type(dc.dcShareHelpResultDy) == "function" then
        dc:dcShareHelpResultDy(result)
    end
end

function Manager:_checkCanShareTicketHelp(shareConfig)
    if self:isEnabled() then return true end

    self:_showTicketHelpFailTip(shareConfig)
    return false
end

function Manager:doShareTicketHelpByMini(panelId, shareConfig)
    shareConfig = shareConfig or {}
    if not self:_checkCanShareTicketHelp(shareConfig) then return end

    local const = self:getConst()
    local text, textIndex = self:_getShareText(self:getTicketHelpMiniCardTextList())
    local onSuccess, onFail, onCancel = self:_makeTicketHelpShareCallback(false, shareConfig)
    local originOnSuccess = onSuccess
    local originOnFail = onFail
    onSuccess = function(...)
        safeRunCall(originOnSuccess, ...)
        if shareConfig.needDcShareHelpResultVx == true then
            self:_dcShareHelpResultVx()
        end
        if shareConfig.needDcShareHelpResultDy == true then
            self:_dcShareHelpResultDy(SHARE_HELP_RESULT_TYPE.SUCCESS)
        end
    end
    onFail = function(...)
        safeRunCall(originOnFail, ...)
        if shareConfig.needDcShareHelpResultDy == true then
            self:_dcShareHelpResultDy(SHARE_HELP_RESULT_TYPE.FAIL)
        end
    end
    local context = OpenShareContext.new(OpenShareConst.ShareType.HELP_ACTIVITY, OpenShareConst.ShareTarget.MINI)
        :setActId(const.actId)
        :setTextParams(text)
        :setMiniParams({
            imageUrl = shareConfig.miniImageUrl,
            templateId = shareConfig.dyTemplateId,
        })
        :setAskHelpParams(nil, {}, const.SHARE_ID)
        :setKVData(self:_getTicketHelpKVData(textIndex, panelId))
        :setShareCallback(onSuccess, onFail, onCancel)

    if EnvUtil:isWXMiniGame() and not EnvUtil:isEntryFromQQ() then
        local askHelpPanelVM = require "amf.feature.localactivity.happymatch.view.HappyMatchAskHelpPanelVM"
        context:setAskPanelParams(OpenShareConst.FriendType.WECHAT, nil, nil, nil, askHelpPanelVM)
    end

    _G.amfTransaction(TransactionEvent.SHARE, context)
end

function Manager:doShareTicketHelpByWeibo(panelId, shareConfig)
    shareConfig = shareConfig or {}
    if not self:_checkCanShareTicketHelp(shareConfig) then return end

    local const = self:getConst()
    local text, textIndex = self:_getShareText(self:getTicketHelpWeiboTextList())
    local imagePath = shareConfig.wbImagePath
    local onSuccess, onFail, onCancel = self:_makeTicketHelpShareCallback(false, shareConfig)
    local originOnSuccess = onSuccess
    local originOnFail = onFail
    local originOnCancel = onCancel
    onSuccess = function(...)
        safeRunCall(originOnSuccess, ...)
        self:_dcShareHelpResultVb(SHARE_HELP_RESULT_TYPE.SUCCESS)
    end
    onFail = function(...)
        safeRunCall(originOnFail, ...)
        self:_dcShareHelpResultVb(SHARE_HELP_RESULT_TYPE.FAIL)
    end
    onCancel = function(...)
        safeRunCall(originOnCancel, ...)
        self:_dcShareHelpResultVb(SHARE_HELP_RESULT_TYPE.FAIL)
    end
    local context = OpenShareContext.new(OpenShareConst.ShareType.HELP_ACTIVITY, OpenShareConst.ShareTarget.WB)
        :setActId(const.actId)
        :setWBParams(HAPPY_MATCH_WEIBO.SUPER_GROUP_NAME, HAPPY_MATCH_WEIBO.SECOND_NAME)
        :setTextParams("", HAPPY_MATCH_WEIBO.TOPIC .. text)
        :setAskHelpParams(nil, {}, const.SHARE_ID)
        :setImgParams(imagePath, imagePath)
        :setWbUrlParam(shareConfig.wbUrl, {
            page_type = OpenShareConst.ShareType.HELP_ACTIVITY,
            link_type = SHARE_WB_PARAM.LINK_TYPE,
            pic_type = SHARE_WB_PARAM.PIC_TYPE,
            title_id = textIndex,
            actId = const.actId,
            xxlId = _G.amfBean("ProfileManager"):getXxlId(),
            index = 1,
        })
        :setKVData(self:_getTicketHelpKVData(textIndex, panelId))
        :setShareCallback(onSuccess, onFail, onCancel)
    _G.amfTransaction(TransactionEvent.SHARE, context)
end

function Manager:doShareTicketHelpByWXToken(panelId, shareConfig)
    shareConfig = shareConfig or {}
    if not self:_checkCanShareTicketHelp(shareConfig) then return end

    local const = self:getConst()
    local textList = self:getTicketHelpWXTokenTextList()
    local text, textIndex = self:_getShareText(textList)
    local _, onFail, onCancel = self:_makeTicketHelpShareCallback(true, shareConfig)
    local context = OpenShareContext.new(OpenShareConst.ShareType.HELP_ACTIVITY, OpenShareConst.ShareTarget.WXToken)
        :setActId(const.actId)
        :setTextParams("", text)
        :setAskHelpParams(nil, {}, const.SHARE_ID)
        :setKVData(self:_getTicketHelpKVData(textIndex, panelId))
        :setShareCallback(function()
            CommonTip:showTip(shareConfig.copySuccessTip or "")
            self:_dcShareHelpResultVx()
            TimerUtil.addAlarm(function()
                self:openWechatForTicketHelp()
            end, OPEN_WECHAT_DELAY)
        end, onFail, onCancel)
    _G.amfTransaction(TransactionEvent.SHARE, context)
end

function Manager:openWechatForTicketHelp()
    if EnvUtil:isWindows() then
        CommonTip:showTip("跳转微信")
        return
    end

    local OpenUrlUtil = require "amf.middleware.multiplatform.util.OpenUrlUtil"
    if OpenUrlUtil:canOpenUrl("weixin://") then
        OpenUrlUtil:openUrl("weixin://")
    end
end

function Manager:showTicketHelpRecord(panelId, shareConfig)
    shareConfig = shareConfig or {}
    CommonTip:showTip(shareConfig.recordFallbackTip or "")
end

function Manager:isEnabled()
    local model = self:getModel()
    return model and model:isDataEnabled() and self:isSupportShare()
end

function Manager:isYinLiuEnabled()
    local model = self:getModel()
    return model and model:isDataEnabled() and model:isInMainTime()
end

function Manager:getTicketNum(default)
    local ticketNum = tonumber(self:getDataByKey("ticketNum", default))
    if ticketNum == nil then
        return default
    end
    return ticketNum
end

function Manager:setTicketNum(ticketNum, needSave)
    local oldTicketNum = self:getTicketNum(0)
    ticketNum = tonumber(ticketNum)
    if ticketNum == nil then return self:getTicketNum() end

    self:setDataByKey("ticketNum", ticketNum, needSave)
    if ticketNum ~= oldTicketNum then
        self:notify("RefreshTicketNum", ticketNum, ticketNum - oldTicketNum)
    end
    return ticketNum
end

function Manager:addTicketNum(delta, needSave)
    delta = tonumber(delta)
    if delta == nil then return self:getTicketNum() end

    return self:setTicketNum(self:getTicketNum(0) + delta, needSave)
end

function Manager:getProgressId()
    return tonumber(self:getDataByKey("progressId", LOTTERY_CHANCE.MIN)) or LOTTERY_CHANCE.MIN
end

function Manager:setProgressId(progressId, needSave)
    progressId = tonumber(progressId) or LOTTERY_CHANCE.MIN
    return self:setDataByKey("progressId", progressId, needSave)
end

function Manager:getFinishedProgressCountByValue(totalGeneratedAnimalCount)
    local metaList = self:getConfigByKey("progressRewardMetaList", {})
    return ProgressCalculator.getFinishedProgressCount(totalGeneratedAnimalCount, metaList)
end

function Manager:getFinishedProgressCount()
    local totalGeneratedAnimalCount = self:getTotalGeneratedAnimalCount(LOTTERY_CHANCE.MIN)
    return self:getFinishedProgressCountByValue(totalGeneratedAnimalCount)
end

function Manager:getRealLotteryChanceByValue(totalGeneratedAnimalCount)
    local chance = self:getFinishedProgressCountByValue(totalGeneratedAnimalCount) - self:getProgressId()
    return math.max(chance, LOTTERY_CHANCE.MIN)
end

function Manager:getRealLotteryChance()
    local totalGeneratedAnimalCount = self:getTotalGeneratedAnimalCount(LOTTERY_CHANCE.MIN)
    return self:getRealLotteryChanceByValue(totalGeneratedAnimalCount)
end

function Manager:tryUpdateProgressIdByRewardResponse(response, needSave)
    local data = response and response.data or {}
    local progressId = data.progressId
    if progressId == nil and data.userInfo then
        progressId = data.userInfo.progressId
    end
    if progressId == nil then
        progressId = self:getProgressId() + LOTTERY_CHANCE.CONSUME_COUNT
    end

    self:setProgressId(progressId, needSave)
    return progressId
end

function Manager:_registerYinLiuAutoPopup()
    if not self.autoPopupMgr or not self.autoPopupMgr.registerPopup then return end

    self.autoPopupMgr:registerPopup({
        checkPoint = getYinLiuCheckPoint(),
        stages = { AutoPopupConst.PopStage.STAGE_FOUR },
        check = function(stageParams)
            local params = unwrapYinLiuStageParams(stageParams)
            return self:canPopMainPanelInScene4(params) or self:canPopYinLiu2(params) or self:canPopYinLiu1(params)
        end,
        creator = function(stageParams, onPopOver)
            local params = unwrapYinLiuStageParams(stageParams)
            return function()
                if self:canPopMainPanelInScene4(params) then
                    self:_markMainPanelScene4PopSuccess()
                    self:openActivity(onPopOver, {
                        from = MAIN_PANEL_SCENE4_POP_CONFIG.FROM,
                    }, false)
                    return
                end
                if self:canPopYinLiu2(params) then
                    self:popYinLiu2(onPopOver)
                    return
                end
                if self:canPopYinLiu1(params) then
                    self:popYinLiu1(onPopOver)
                    return
                end
                safeRunCall(onPopOver)
            end
        end,
    })
end

function Manager:_getRawDataByKey(key)
    local dataKeyChainPrefix = self:getConst().infoPrefix or ""
    return self:getModel():getValue(dataKeyChainPrefix .. "." .. key)
end

function Manager:_getRawConfigByKey(key)
    local configKeyChainPrefix = self:getConst().configPrefix or ""
    return self:getModel():getValue(configKeyChainPrefix .. "." .. key)
end

function Manager:_normalizeTaskProgressReward(value)
    if value == true then return true end
    if value == false then return false end
    local numValue = toNumberOrNil(value)
    if numValue == NUMBER_VALUE.ONE then return true end
    if numValue == NUMBER_VALUE.ZERO then return false end
    if type(value) == "string" then
        return string.lower(value) == "true"
    end
    return nil
end

function Manager:_getYinLiuTaskData()
    local taskMetaList = self:_getRawConfigByKey("happyMatchTaskMetaList")
    if type(taskMetaList) ~= "table" or table.isEmpty(taskMetaList) then
        return nil
    end
    for _, taskMeta in ipairs(taskMetaList) do
        if type(taskMeta) ~= "table" then
            return nil
        end
        if not TASK_PROGRESS_FIELD_BY_TYPE[toNumberOrNil(taskMeta.taskType)] then
            return nil
        end
        if taskMeta.taskId == nil then
            return nil
        end
        if toNumberOrNil(taskMeta.taskTarget) == nil then
            return nil
        end
        if type(taskMeta.taskRewardList) ~= "table" or type(taskMeta.taskRewardList[NUMBER_VALUE.ONE]) ~= "table" then
            return nil
        end
    end

    local taskProgressData = self:_getRawDataByKey("taskProgressData")
    if type(taskProgressData) ~= "table" then
        return nil
    end
    for _, fieldName in pairs(TASK_PROGRESS_FIELD_BY_TYPE) do
        if toNumberOrNil(taskProgressData[fieldName]) == nil then
            return nil
        end
    end

    local taskMap = self:_getRawDataByKey("taskMap")
    if type(taskMap) ~= "table" then
        return nil
    end

    local taskProgressReward = self:_normalizeTaskProgressReward(self:_getRawDataByKey("taskProgressReward"))
    if taskProgressReward == nil then
        return nil
    end

    return {
        taskMetaList = taskMetaList,
        taskProgressData = taskProgressData,
        taskMap = taskMap,
        taskProgressReward = taskProgressReward,
    }
end

function Manager:_getYinLiuTicketNum()
    local ticketNum = self:_getRawDataByKey("ticketNum")
    if ticketNum == nil then return nil end
    return toNumberOrNil(ticketNum)
end

function Manager:_getMainTopPassedLevel()
    local levelAreaManager = _G.amfBean("LevelAreaManager")
    local topPassedLevel = levelAreaManager and levelAreaManager.getTopPassedLevel and levelAreaManager:getTopPassedLevel()
    if topPassedLevel == nil and _G.getTopLevelId then
        topPassedLevel = _G.getTopLevelId()
    end
    return toNumberOrNil(topPassedLevel)
end

function Manager:_getYinLiuPopCount()
    return toNumberOrNil(self:getLocalCache(YIN_LIU_CONFIG.POP_COUNT_CACHE_KEY, true)) or NUMBER_VALUE.ZERO
end

function Manager:_getYinLiuLastPopLevelId()
    return toNumberOrNil(self:getLocalCache(YIN_LIU_CONFIG.LAST_POP_LEVEL_CACHE_KEY, true))
end

function Manager:_isYinLiuDailyCountAvailable()
    return self:_getYinLiuPopCount() < YIN_LIU_CONFIG.DAILY_POP_LIMIT
end

function Manager:_isYinLiuAfterMainLevelPassed(stageParams)
    if type(stageParams) ~= "table" then return false end
    if stageParams.isLevelPassed ~= true then return false end
    return UBFLevelSceneFunc and UBFLevelSceneFunc:isMainLevel(stageParams.levelScene)
end

function Manager:_shouldIgnoreYinLiuForTopLevelPlayer(stageParams)
    if not self.autoPopupMgr or not self.autoPopupMgr.ignoreForTopLevelPlayer then return false end
    stageParams = stageParams or {}
    return self.autoPopupMgr:ignoreForTopLevelPlayer(stageParams.levelId, stageParams.levelScene) == true
end

function Manager:_isYinLiuRhythmAvailable(currentLevelId)
    local lastPopLevelId = self:_getYinLiuLastPopLevelId()
    if not lastPopLevelId then return true end
    if not currentLevelId then return false end
    if currentLevelId - lastPopLevelId >= YIN_LIU_CONFIG.NEXT_POP_PASS_LEVEL_COUNT then return true end
    return self._yinLiuLoginExemptUsed ~= true
end

function Manager:_hasMainPanelScene4PoppedToday()
    return self:getLocalCache(MAIN_PANEL_SCENE4_POP_CONFIG.CACHE_KEY, true) == true
end

function Manager:_markMainPanelScene4PopSuccess()
    self:setLocalCache(MAIN_PANEL_SCENE4_POP_CONFIG.CACHE_KEY, true, true)
end

function Manager:markMainPanelScene4PopupHandled()
    if self:_hasMainPanelScene4PoppedToday() then return end
    self:_markMainPanelScene4PopSuccess()
end

function Manager:canPopMainPanelInScene4(stageParams)
    if not self:isYinLiuEnabled() then return false end
    if not self:_isYinLiuAfterMainLevelPassed(stageParams) then return false end
    if self:_shouldIgnoreYinLiuForTopLevelPlayer(stageParams) then return false end
    return not self:_hasMainPanelScene4PoppedToday()
end

function Manager:_getYinLiuBaseCheckResult(stageParams, options)
    options = options or {}
    if not self:isYinLiuEnabled() then
        return nil
    end
    if not self:_isYinLiuAfterMainLevelPassed(stageParams) then
        return nil
    end
    if self:_shouldIgnoreYinLiuForTopLevelPlayer(stageParams) then
        return nil
    end
    if not self:_isYinLiuDailyCountAvailable() then
        return nil
    end

    local ticketNum = self:_getYinLiuTicketNum()
    if options.needTicketCheck ~= false then
        if not ticketNum or ticketNum < YIN_LIU_CONFIG.DRAW_TICKET_COST then
            return nil
        end
    end

    local taskData = self:_getYinLiuTaskData()
    if not taskData then
        return nil
    end

    local currentLevelId = self:_getMainTopPassedLevel()
    if not self:_isYinLiuRhythmAvailable(currentLevelId) then
        return nil
    end

    return {
        taskData = taskData,
        ticketNum = ticketNum,
        currentLevelId = currentLevelId,
        stageParams = stageParams,
    }
end

function Manager:_isYinLiuTaskRewardReceived(taskMap, taskId)
    if type(taskMap) ~= "table" then return false end
    if taskId == nil then return false end
    return taskMap[taskId] ~= nil or taskMap[tostring(taskId)] ~= nil
end

function Manager:_buildYinLiuTaskRewardList(taskMeta)
    local taskRewardList = {}
    local rewardList = type(taskMeta) == "table" and taskMeta.taskRewardList or nil
    if type(rewardList) ~= "table" then return taskRewardList end

    for _, reward in ipairs(rewardList) do
        if type(reward) == "table" then
            table.insert(taskRewardList, table.clone(reward) or reward)
        end
    end
    return taskRewardList
end

function Manager:_getClaimableYinLiuRewards(taskData)
    taskData = taskData or self:_getYinLiuTaskData()
    if not taskData then
        return nil
    end
    if type(taskData.taskMetaList) ~= "table" then
        return nil
    end
    if type(taskData.taskProgressData) ~= "table" then
        return nil
    end
    if type(taskData.taskMap) ~= "table" then
        return nil
    end

    local rewards = {}
    local totalTaskCount = NUMBER_VALUE.ZERO
    local receivedTaskCount = NUMBER_VALUE.ZERO
    for _, taskMeta in ipairs(taskData.taskMetaList) do
        if type(taskMeta) == "table" then
            local taskType = toNumberOrNil(taskMeta.taskType)
            local fieldName = TASK_PROGRESS_FIELD_BY_TYPE[taskType]
            local taskId = toNumberOrNil(taskMeta.taskId) or taskMeta.taskId
            local target = toNumberOrNil(taskMeta.taskTarget)
            if fieldName and taskId ~= nil and target ~= nil then
                totalTaskCount = totalTaskCount + NUMBER_VALUE.ONE
                local current = toNumberOrNil(taskData.taskProgressData[fieldName]) or NUMBER_VALUE.ZERO
                local received = self:_isYinLiuTaskRewardReceived(taskData.taskMap, taskId)
                if received then
                    receivedTaskCount = receivedTaskCount + NUMBER_VALUE.ONE
                elseif current >= target then
                    local taskRewardList = self:_buildYinLiuTaskRewardList(taskMeta)
                    for _, reward in ipairs(taskRewardList) do
                        table.insert(rewards, reward)
                    end
                end
            end
        end
    end

    if totalTaskCount > NUMBER_VALUE.ZERO and receivedTaskCount >= totalTaskCount and taskData.taskProgressReward ~= true then
        table.insert(rewards, table.clone(TASK_PROGRESS_REWARD) or TASK_PROGRESS_REWARD)
    end

    return rewards
end

function Manager:_hasClaimableYinLiuReward(taskData)
    local rewards = self:_getClaimableYinLiuRewards(taskData)
    return type(rewards) == "table" and not table.isEmpty(rewards), rewards
end

function Manager:canPopYinLiu2(stageParams)
    local baseResult = self:_getYinLiuBaseCheckResult(stageParams, {
        needTicketCheck = false,
    })
    if not baseResult then
        return false
    end

    return self:_hasClaimableYinLiuReward(baseResult.taskData)
end

function Manager:canPopYinLiu1(stageParams)
    local baseResult = self:_getYinLiuBaseCheckResult(stageParams)
    if not baseResult then return false end

    local hasClaimableReward = self:_hasClaimableYinLiuReward(baseResult.taskData)
    return not hasClaimableReward
end

function Manager:_markYinLiuPopSuccess()
    self:setLocalCache(YIN_LIU_CONFIG.POP_COUNT_CACHE_KEY, true, self:_getYinLiuPopCount() + NUMBER_VALUE.ONE)
    local currentLevelId = self:_getMainTopPassedLevel()
    if currentLevelId then
        self:setLocalCache(YIN_LIU_CONFIG.LAST_POP_LEVEL_CACHE_KEY, true, currentLevelId)
    end
    self._yinLiuLoginExemptUsed = true
end

function Manager:_dcAttractPanelShow(from)
    local entry = ATTRACT_PANEL_DC_ENTRY[from]
    if not entry then return end

    local dc = self:getDC()
    if dc and type(dc.dcAttractPanelShow) == "function" then
        dc:dcAttractPanelShow(entry)
    end
end

function Manager:openActivity(closeCallback, extra, userClick)
    self:callActFunc("openActivity", {
        failCallback = closeCallback,
        endCallback = closeCallback,
        userClick = userClick,
        extra = extra,
    })
end

function Manager:_openActivityFromYinLiu(vm, closeCallback, from)
    if vm then
        vm:setCloseCallback(nil)
    end
    if vm and not vm.isDisposed then
        vm:close()
    end
    self:openActivity(closeCallback, {
        from = from,
    }, true)
end

function Manager:_getYinLiuRewardTipText(reward)
    local propManager = _G.amfBean("PropManager")
    local propName = propManager and propManager.getPropName and propManager:getPropName(reward)
    if propName and propName ~= "" then return propName end
    return YIN_LIU_CONFIG.REWARD_TIP_FALLBACK_TEXT
end

function Manager:_showYinLiuRewardTip(vm, rewardIndex, reward)
    if not vm or vm.isDisposed then return end

    local view = vm.view
    if not view or view.isDisposed then return end

    local rewardNode = view["reward_" .. tostring(rewardIndex)]
    if not rewardNode or rewardNode.isDisposed then return end

    UITip.Builder.new()
        :setTarget(rewardNode)
        :setTitle(self:_getYinLiuRewardTipText(reward))
        :setAutoCloseTime(YIN_LIU_CONFIG.REWARD_TIP_AUTO_CLOSE_TIME)
        :build()
end

function Manager:_buildYinLiuRewardDelegate(reward, rewardIndex, getPanelVM)
    return {
        item = reward,
        ignoreSwallows = true,
        touchHandler = function()
            local panelVM = type(getPanelVM) == "function" and getPanelVM() or nil
            self:_showYinLiuRewardTip(panelVM, rewardIndex, reward)
        end,
    }
end

function Manager:_popYinLiuCommon(params, closeCallback)
    params = params or {}
    local rewards = params.rewards
    if type(rewards) ~= "table" or table.isEmpty(rewards) then
        safeRunCall(closeCallback)
        return nil
    end

    local vm
    local hasFinished = false
    local function finish()
        if hasFinished then return end
        hasFinished = true
        safeRunCall(closeCallback)
    end
    local delegate = {
        title = YIN_LIU_CONFIG.PANEL_TITLE,
        colorType = YIN_LIU_CONFIG.PANEL_COLOR_TYPE,
        text = {
            string = params.subTitle,
            horizontalAlignment = YIN_LIU_CONFIG.TEXT_ALIGN_LEFT,
        },
        rewards = rewards,
        closeCallback = finish,
        loadResFailCallback = finish,
        sureBtn = {
            touchHandler = function()
                self:_openActivityFromYinLiu(vm, finish, params.from)
            end,
            Content = {
                { text = params.buttonText },
            },
        },
    }
    for i, reward in ipairs(rewards) do
        delegate["reward_" .. tostring(i)] = self:_buildYinLiuRewardDelegate(reward, i, function()
            return vm
        end)
    end

    local function createPanel()
        return SecondRewardPanelVM:create(delegate)
    end
    local ok, result = xpcall(createPanel, debug.traceback)
    if ok then
        vm = result
    else
        UEErrorLog("HappyMatchManager:_popYinLiuCommon create panel failed ", result)
    end
    if not vm then
        finish()
        return nil
    end
    vm:popout()
    self:callPlug("Panel", "managePanelVM", vm)
    addYinLiuSureBtnRedDot(vm, params.buttonRedDotText)
    self:_dcAttractPanelShow(params.from)
    self:_markYinLiuPopSuccess()
    return vm
end

function Manager:popYinLiu1(closeCallback)
    return self:_popYinLiuCommon({
        subTitle = YIN_LIU_CONFIG.PANEL_1_SUB_TITLE,
        rewards = {
            {
                itemId = YIN_LIU_CONFIG.REAL_REWARD_ITEM_ID,
                num = NUMBER_VALUE.ONE,
            },
        },
        buttonText = YIN_LIU_CONFIG.PANEL_1_BUTTON_TEXT,
        from = YIN_LIU_CONFIG.PANEL_1_FROM,
    }, closeCallback)
end

function Manager:popYinLiu2(closeCallback)
    local rewards = self:_getClaimableYinLiuRewards()
    return self:_popYinLiuCommon({
        subTitle = YIN_LIU_CONFIG.PANEL_2_SUB_TITLE,
        rewards = rewards,
        buttonText = YIN_LIU_CONFIG.PANEL_2_BUTTON_TEXT,
        buttonRedDotText = YIN_LIU_CONFIG.PANEL_2_BUTTON_RED_DOT_TEXT,
        from = YIN_LIU_CONFIG.PANEL_2_FROM,
    }, closeCallback)
end

function Manager:addRewardsNormal(rewardItems, params)
    self:callPlug("Rewards", "addRewardsNormal", rewardItems, {
        dcExtra = params,
    })
end

function Manager:_onCustomGain(event)
end

function Manager:onActTestButtonReady()
    addGlobalTestButton("开心对对碰", function()

    end, {
        TestButtonConst.Tags.ACTIVITY,
    })
end

return Manager
