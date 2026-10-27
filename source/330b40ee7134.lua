local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local MarkEventCenter = require "amf.feature.dailyreward.mark.event.MarkEventCenter"
local MainSceneEventCenter = require "amf.feature.mainscene.core.event.MainSceneEventCenter"
require "amf.feature.mainscene.module.topbanner.config.SceneTopBannerConst"
require "amf.feature.mainscene.module.topbanner.SceneTopBannerContext"
require "amf.feature.personalhub.namecard.userdecotype.UserDecoMgr"
require "amf.feature.personalhub.namecard.decoration.vineskin.logic.VineSkinType"

local ActivityName = "BigVineSkinAct"
local Manager = class(ActivityName .. "Manager", BaseFeatureManager)
local TrialUsingSkinStateCacheKey = "BigVineSkinActTrialUsingSkinState"
local MainPanelTipPopCountCacheKey = "mainPanelTipPopCount"
local RecallInLevelToastShownCacheKeyPrefix = "BigVineSkinActRecallInLevelToastShown_"
local ScheduledDayBroadcastCacheKeyPrefix = "ScheduledDayBroadcast_"
local QualifyDCCacheKey = "BigVineSkinActQualifyDC"
local JoinDCCacheKey = "BigVineSkinActJoinDC"

local function getRecallInLevelToastShownCacheKey(manager)
    return RecallInLevelToastShownCacheKeyPrefix .. tostring(manager:getConst().actOpenVersion)
end

function Manager:log(...)
    printx(42, "***** BigVineSkinAct *****  ", ...)
end

-- 获取常量路径
function Manager:_getConstPath()
    return "amf.feature.localactivity.bigvineskinact.const.BigVineSkinActConst"
end

-- 获取model路径
function Manager:_getModelPath()
    return "amf.feature.localactivity.bigvineskinact.model.BigVineSkinActModel"
end

-- 如果有自己需要初始化的内容，覆写这个
function Manager:_init()
    _G.amfEC:registerFeature(self)
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActActInfoUpdate, self)
    MarkEventCenter:register(MarkEvent.MARK_PREOPEN_CHECK, self.onMarkPreOpenEvent, self)
    MainSceneEventCenter:register(MainSceneEvent.Play.HANDLE_PASS_LEVEL, self.onHandlePassLevelBonusAnim, self, MSP.PassLevel.BIG_VINE_SKIN_BONUS_ANIM)
    -- 注册 求助点回
    require("amf.feature.localactivity.bigvineskinact.share.BigVineSkinHelpHandler"):create()
end

function Manager:setAutoPopupMgr(manager)
    self.autoPopupMgr = manager
end

-- 获取需要启动的额外功能列表
function Manager:_getExtraPlugsConfigList()
    return {
        {
            key = "Download",
        },
        {
            key = "Panel",
        },
        {
            key = "Rewards",
        },
        {
            key = "AutoPop",
        },
    }
end

function Manager:_getAutoPopConfigList()
    local PopStage = AutoPopupConst.PopStage
    return {
        -- 每期玩家触发活动的第1天，在场景2或4弹主活动面板；CheckPoint 位于 WATERFALL_GIFT_DY_OFFER 之后。
        -- 每期一次由强弹框架控制，玩家触发日条件与主面板打开逻辑由业务补齐。
        {
            checkPoint = PopupCheckPoint.BIG_VINE_SKIN_TRIGGER_DAY1,
            stages = { PopStage.STAGE_TWO, PopStage.STAGE_FOUR },
            check = function()
                return self:checkCanPopTriggerDay1MainPanel()
            end,
            creator = function(_, onPopOver)
                return function()
                    self:popTriggerDay1MainPanel(onPopOver)
                end
            end,
        },
		-- 活动第5、8、12天仅在场景4弹主活动面板。
		-- 每个目标日最多一次由强弹框架的 CheckPointNumLimit=1 控制。
        {
            checkPoint = PopupCheckPoint.BIG_VINE_SKIN_SCHEDULED_DAY,
            stages = { PopStage.STAGE_FOUR },
            check = function()
                return self:checkCanPopScheduledDayMainPanel()
            end,
            creator = function(_, onPopOver)
                return function()
                    self:popScheduledDayMainPanel(onPopOver)
                end
            end,
        },
		-- 限时试戴倒计时结束后，返回大藤蔓时在场景2或4弹业务小面板。
		-- 试戴结束待提示状态、重复提示控制和小面板入口均需由业务补齐。
        {
            checkPoint = PopupCheckPoint.BIG_VINE_SKIN_TRIAL_EXPIRED,
            stages = { PopStage.STAGE_TWO, PopStage.STAGE_FOUR },
            check = function()
                return self:checkCanPopTrialExpiredPanel()
            end,
            creator = function(_, onPopOver)
                return function()
                    self:popTrialExpiredPanel(onPopOver)
                end
            end,
        },
		-- 获得试戴卡且满足试戴条件时，仅在场景4弹业务面板。
		-- 试戴卡获得待提示状态、试戴资格判断和面板入口均需由业务补齐。
        {
            checkPoint = PopupCheckPoint.BIG_VINE_SKIN_TRIAL_CARD,
            stages = { PopStage.STAGE_FOUR },
            check = function()
                return self:checkCanPopTrialCardPanel()
            end,
            creator = function(_, onPopOver)
                return function()
                    self:popTrialCardPanel(onPopOver)
                end
            end,
        },
        -- 获得大藤蔓皮肤后仅在场景4弹引导；永久一次由强弹框架控制。
		-- 皮肤获得状态、是否仍需引导和实际引导入口均需由业务补齐。
        {
            checkPoint = PopupCheckPoint.BIG_VINE_SKIN_OWNED_GUIDE,
            stages = { PopStage.STAGE_FOUR },
            check = function()
                return self:checkCanPopOwnedSkinGuide()
            end,
            creator = function(_, onPopOver)
                return function()
                    self:popOwnedSkinGuide(onPopOver)
                end
            end,
        },
    }
end

function Manager:checkCanPopTriggerDay1MainPanel()
    if not self:isEnabled() then return false end
    if self:hasGuideIndex(103, false) then return false end
    return true
end

function Manager:popTriggerDay1MainPanel(onPopOver)
    if not self:checkCanPopTriggerDay1MainPanel() then
        safeRunCall(onPopOver)
        return
    end

    self:openActivity(onPopOver, {from = "popoup", day = 1}, false)
end

function Manager:checkCanPopScheduledDayMainPanel()
    if not self:isEnabled() then return false end

    local day = self:getDayFromActOpen()
    local scheduledDays = self:getConst().scheduledPopMainPanelDays
    return table.exist(scheduledDays, day)
end

function Manager:popScheduledDayMainPanel(onPopOver)
    if not self:checkCanPopScheduledDayMainPanel() then
        safeRunCall(onPopOver)
        return
    end

    self:openActivity(onPopOver, {from = "popoup"}, false)
end

function Manager:getScheduledDayBroadcastInfo()
    if not self:isEnabled() then return end

    local day = self:getDayFromActOpen()
    local scheduledDays = self:getConst().scheduledDayBroadcastDays or {}
    local scheduledTips = self:getConst().scheduledDayBroadcastTips or {}
    local taskIndex
    for index, scheduledDay in ipairs(scheduledDays) do
        if scheduledDay == day then
            taskIndex = index
            break
        end
    end
    if not taskIndex then return end
    if self:getModel():getLocalCache(self:getScheduledDayBroadcastCacheKey(day)) then return end

    local stageInfo = self:getRewardStageProgressList()[taskIndex]
    if stageInfo and tonumber(stageInfo.status) ~= 2 then
        local progress = tonumber(stageInfo.progress) or 0
        local needProgress = tonumber(stageInfo.needProgress) or 0
        if needProgress > 0 then
            return {
                day = day,
                taskId = stageInfo.rewardId or stageInfo.index,
                progress = progress,
                needProgress = needProgress,
                tips = scheduledTips[day],
            }
        end
    end
end

function Manager:checkCanPopScheduledDayBroadcast()
    return self:getScheduledDayBroadcastInfo() ~= nil
end

function Manager:popScheduledDayBroadcast(onPopOver)
    local info = self:getScheduledDayBroadcastInfo()
    if not info then
        safeRunCall(onPopOver)
        return
    end

    local actImgPath = "amf/activity/bigvineskinact/materials/actImg.png"
    local function popBroadcast()
        local UEBroadCastContext = require "amf.middleware.ui.kit.templates.uebroadcast.context.UEBroadCastContext"
        local UEBroadCastConst = require "amf.middleware.ui.kit.templates.uebroadcast.config.UEBroadCastConst"
        UEBroadCastContext.new(UEBroadCastConst.Type.CUSTOM)
            :setViewType(UEBroadCastConst.ViewType.SPECIAL_LONE)
            :setTips(info.tips)
            :setProgress({
                text = tostring(info.progress) .. "/" .. tostring(info.needProgress),
                percent = info.progress / info.needProgress,
            })
            :setCostIcon(nil, function()
                local sprite = UICreateUtil:createSpriteFile(actImgPath, true)
                sprite:setScale(2)
                return sprite
            end)
            :build()

        self:getModel():setLocalCache(self:getScheduledDayBroadcastCacheKey(info.day), true)
        safeRunCall(onPopOver)
    end

    if EnvUtil:isApp() then
        popBroadcast()
        return
    end

    AssetsUtil:loadMiniFiles({actImgPath}):next(popBroadcast, function()
        safeRunCall(onPopOver)
    end)
end

function Manager:getScheduledDayBroadcastCacheKey(day)
    return ScheduledDayBroadcastCacheKeyPrefix .. tostring(day or 0)
end

function Manager:checkIconTip(config)
    -- 抽条要加载资源，防止小游戏走加载资源逻辑
    if EnvUtil:isMiniGame() then return end
    if not self:isEnabled() then return end
    local addProgress = tonumber(self.cacheAddProgress) or 0
    if addProgress <= 0 then return end

    local progressBeforeAdd = tonumber(self.cacheProgressBeforeAdd)
    if not progressBeforeAdd then
        progressBeforeAdd = math.max((tonumber(self:getProgress()) or 0) - addProgress, 0)
    end

    local stageProgressBeforeAdd = 0
    local stageNeedProgress = 0
    local completedProgress = 0
    -- 动画档位由加进度前的位置决定，与奖励是否已领取无关。
    for _, info in ipairs(self:getRewardStageProgressList()) do
        local needProgress = tonumber(info.needProgress) or 0
        if needProgress > 0 and progressBeforeAdd < completedProgress + needProgress then
            stageProgressBeforeAdd = math.max(progressBeforeAdd - completedProgress, 0)
            stageNeedProgress = needProgress
            break
        end
        completedProgress = completedProgress + needProgress
    end
    if stageNeedProgress <= 0 then
        self:clearIconTipProgressCache()
        return
    end

    local targetProgress = stageProgressBeforeAdd + addProgress
    local remain = stageNeedProgress - math.min(targetProgress, stageNeedProgress)
    if remain > 20 then return end

    self:addIconTip(stageProgressBeforeAdd, targetProgress, stageNeedProgress, config)
end

function Manager:clearIconTipProgressCache()
    self.cacheAddProgress = nil
    self.cacheProgressBeforeAdd = nil
end

function Manager:addIconTip(fromProgress, targetProgress, needProgress, config)
    local delegate = {
        tipsType = HomeIconTipsType.PROGRESS,
        min = 0,
        max = needProgress,
        value = fromProgress,
        targetValue = targetProgress,
        progressChangeTime = 0.3,
        textMode = 0,
        iconCreate = function()
            return self:createIconTipLevelIcon()
        end,
        endCallback = function()
            self:clearIconTipProgressCache()
        end,
    }

    self:loadDoubleBuffNodeRes(function()
        local IconTipEventCenter = require("amf.feature.icontip.event.IconTipEventCenter")
        IconTipEventCenter:dispatch(IconTipEvent.ADD_ICON_TIP, {
            iconKey = tostring(self:getConst().actId),
            iconType = IconTipType.MESSAGE,
            creatorDelegate = delegate,
            typeIndex = 1,
            config = config,
        })
    end)
end

function Manager:createIconTipLevelIcon()
    local iconPathByLevelStatus = {
        [1] = "amf/activity/bigvineskinact/materials/fmj.png",
        [2] = "amf/activity/bigvineskinact/materials/fmc.png",
        [3] = "amf/activity/bigvineskinact/materials/mjmc.png",
    }
    local levelStatus = self:getLocalLevelStatus(_G.getTopLevelId())
    local icon = UICreateUtil:createSpriteFile(iconPathByLevelStatus[levelStatus] or iconPathByLevelStatus[1], true)
    if icon then
        icon:setScale(0.38)
        return icon
    end
    return Sprite:createEmpty()
end

function Manager:getRandomShareKey()
    local ret = "♥sharekey复制口令进入开心消消乐aρρ，协助好友，领取奖励！"
    local shareKeyList = self:getModel():getConfigByKey("shareKeyList", {}) or {}
    if table.isEmpty(shareKeyList) then return ret end

    return shareKeyList[math.random(1, #shareKeyList)] or ret
end

function Manager:calNeedPlayHelpAnim()
    local day = self:getDayFromActOpen()
    local beHelpedRemain = tonumber(self:getModel():getDataByKey("dailyInfo.beHelpedRemain", 1)) or 1
    local helpDoubleTimes = tonumber(self:getModel():getConfigByKey("beHelpedDoubleTimes")) or 5
    local doubleRemain = self:getDailyDoubleRemain()
    if not self:hasGuideIndex(day, false) and beHelpedRemain <= 0 and doubleRemain >= helpDoubleTimes then
        self.needPlayHelpAnim = true
    end
end

function Manager:onActAfterAutoPopupEnd(event)
    if not self:isEnabled() then return end
    local data = event:getData()
    local lastPopStage = data and data.lastPopStage
    if lastPopStage == AutoPopupConst.PopStage.STAGE_TWO then
        self:loadDoubleBuffNodeRes(function()
            self:getDoubleBuffNodeShowRemain()
            self:updateDoubleBuffNode(true)
        end)
    end
    if lastPopStage ~= AutoPopupConst.PopStage.STAGE_TWO and lastPopStage ~= AutoPopupConst.PopStage.STAGE_FOUR then
        return
    end

    if self:checkCanPopScheduledDayBroadcast() then
        self:popScheduledDayBroadcast()
    end
end

function Manager:clearTrialUsingSkinState()
	LocalDB:setTable(TrialUsingSkinStateCacheKey, {}, true)
end

function Manager:updateTrialUsingSkinState(skinId)
	skinId = tonumber(skinId)
	local nowMs = TimeKit:timeInMillis()
	if not skinId or skinId == tonumber(VineSkinType.kDefault) then
		self:clearTrialUsingSkinState()
		return
	end

	local vineDecoInfo = UserDeco:getDecoInfo(UserDecoType.kVineSkin)
	for _, deco in ipairs(vineDecoInfo.decos or {}) do
		if tonumber(deco.id) == skinId then
			local expireTime = tonumber(deco.expireTime) or 0
			if expireTime > nowMs then
				LocalDB:setTable(TrialUsingSkinStateCacheKey, {
					skinId = skinId,
					expireTime = expireTime,
				}, true)
				return
			end
		end
	end

	self:clearTrialUsingSkinState()
end

-- function Manager:onActLevelCollectionNewAni(event)
--     self:loadDoubleBuffNodeRes(function()
--         self:getDoubleBuffNodeShowRemain()
--         self:updateDoubleBuffNode(true)
--     end)
-- end

function Manager:getTrialSkinState()
	local trialState = LocalDB:getTable(TrialUsingSkinStateCacheKey, {})
	if type(trialState) ~= "table" then
		return nil
	end

	local skinId = tonumber(trialState.skinId)
	local expireTime = tonumber(trialState.expireTime)
	if not skinId or skinId == tonumber(VineSkinType.kDefault) or not expireTime or expireTime <= 0 then
		return nil
	end

	return {
		skinId = skinId,
		expireTime = expireTime,
	}
end

function Manager:checkCanPopTrialExpiredPanel()
	local trialState = self:getTrialSkinState()
	return trialState and trialState.expireTime <= TimeKit:timeInMillis() or false
end

function Manager:restoreExpiredTrialSkin(trialState)
	if not trialState then return end

	local vineSkinManager = _G.amfBean("VineSkinManager")
	local decoInfo = UserDeco:getDecoInfo(UserDecoType.kVineSkin)
	local usingSkinId = vineSkinManager and tonumber(vineSkinManager:getUsingSkinType())
	local profileUsingSkinId = tonumber(decoInfo.using)
	if usingSkinId ~= trialState.skinId and profileUsingSkinId ~= trialState.skinId then return end

	UserDeco:setDecoUsing(UserDecoType.kVineSkin, VineSkinType.kDefault)
	if vineSkinManager then
		vineSkinManager:setUsingSkinType(VineSkinType.kDefault)
	end

	local personalCenterManager = _G.amfBean("PersonalCenterManager")
	if personalCenterManager then
		personalCenterManager:setUsingDeco(UserDecoType.kVineSkin, VineSkinType.kDefault)
	end
end

function Manager:popTrialExpiredPanel(onPopOver)
	local trialState = self:getTrialSkinState()
	if not trialState then
		safeRunCall(onPopOver)
		return
	end

	local finished = false
	local goToLevel = false
	local function finish(shouldHandleExpired)
		if finished then return end
		finished = true
		if shouldHandleExpired then
			self:restoreExpiredTrialSkin(trialState)
			self:clearTrialUsingSkinState()
			if goToLevel then
				_G.amfTransaction(TransactionEvent.PLAY_LEVEL, PlayLevelContext.new())
			end
		end
		safeRunCall(onPopOver)
	end

	local vineSkinManager = _G.amfBean("VineSkinManager")
	local skinName = vineSkinManager and vineSkinManager:getSkinName(trialState.skinId) or "藤蔓皮肤"
	local panelId = UICreateUtil:getPanelId("BigVineSkinTrialExpiredPanel")
	local FourthPanelAVM = require "amf.middleware.ui.kit.panel.fourth.FourthPanelAVM"
	local vm
	vm = FourthPanelAVM.Builder.new()
		:setText(string.format("您的“%s”试戴结束了～\n加油闯关吧！", skinName))
		:setButtonsConfig({{
			str = "去闯关",
			widthMode = UIButtonConfig.Widths.kShort,
			colorMode = UIButtonConfig.ColorMode.green,
			touchFunc = function()
				if not vm or vm.isDisposed then return end
				self:dc("vine_decorate", "trial_expired_click", panelId)
				goToLevel = true
				vm:close()
			end,
		}})
		:setLoadResFailCallback(function()
			finish(false)
		end)
		:setCloseCallback(function()
			finish(true)
		end)
		:build()

	vm:popout()
	self:dc("vine_decorate", "trial_expired_show", panelId, trialState.skinId)
end

function Manager:checkCanPopTrialCardPanel()
	-- 补充活动与资源就绪、本次获得试戴卡尚未提示及当前满足试戴条件的同步判断。
	-- check 中不要请求后端或修改试戴卡状态。
    return self:checkCanReward()
end

function Manager:popTrialCardPanel(onPopOver)
	-- 打开获得试戴卡后的试戴面板，将 onPopOver 传入关闭、打开失败和异常兜底回调。
	-- 面板确认打开后消费本次试戴卡的待提示状态。
    if not self:checkCanReward() then 
        safeRunCall(onPopOver)
        return
    end
    -- 去掉领奖后个人名片引导
    self:tryOpenGetRewardPanel(onPopOver, onPopOver, false)
end

function Manager:checkCanPopOwnedSkinGuide()
	local autoPopupMgr = self.autoPopupMgr or _G.amfBean("AutoPopupMgr")
	if not autoPopupMgr then return false end
	if not self:isEnabled() then return false end
	if autoPopupMgr:getPermanentShowNum(PopupCheckPoint.BIG_VINE_SKIN_OWNED_GUIDE) > 0 then
		return false
	end

	local decoInfo = UserDeco:getDecoInfo(UserDecoType.kVineSkin)
	return table.find(decoInfo.decos or {}, function(deco)
		local skinId = tonumber(deco.id)
		return skinId and skinId > 0 and skinId ~= tonumber(VineSkinType.kDefault)
	end) ~= nil
end

function Manager:popOwnedSkinGuide(onPopOver)
	local finished = false
	local function finish()
		if finished then return end
		finished = true
		safeRunCall(onPopOver)
	end

	local IconMeta = require "amf.feature.mainscene.module.icon.config.IconMeta"
	local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
	local iconManager = _G.amfBean("IconManager")
	local iconPool = iconManager and iconManager:getPool(IconMeta.PoolType.kRightCorner)
	local target = iconPool and iconPool.cornerButton
	if not target or target.isDisposed then
		finish()
		return
	end

	IconEventCenter:dispatch(IconEvent.OPEN_ICON_POOL, IconMeta.PoolType.kRightCorner)
	setTimeOut(function()
		if iconPool.isDisposed or target.isDisposed then
			finish()
			return
		end

		local autoPopupMgr = self.autoPopupMgr or _G.amfBean("AutoPopupMgr")
		local HeGuide = require "amf.middleware.ui.kit.component.HeGuide"
		local heGuide = HeGuide:create(nil, true, nil, true,true)
		heGuide:addAccurateGuide(target, {iconPool})
		heGuide:setEndCall(finish)
		heGuide:setKeyBackEnabled(Director:sharedDirector():getRunningSceneLua())
		heGuide:showNpc2({
			{ttf = "在“我的名片”可更换\n大藤蔓皮肤哦～", fontSize = 34},
		}, 460, "点击任意处继续", -40)

		if autoPopupMgr then
			autoPopupMgr:sendPermanentData(PopupCheckPoint.BIG_VINE_SKIN_OWNED_GUIDE)
		end
	end, 0.35)
end

function Manager:isEnabled()
    return self:getModel():isDataEnabled() and self:isInMainTime()
end

function Manager:isEnabled2()
    return self:getModel():isDataEnabled()
end

-- 预热期
function Manager:isInPreTime()
    return self:getModel():isInPreheatTime()
end

-- 是否是主活动期
function Manager:isInMainTime()
    return self:getModel():isInMainTime()
end

-- 是否是领奖期
function Manager:isInRewardTime()
    return self:getModel():isInRewardTime()
end

function Manager:isResEnabled()
    if EnvUtil:isCocos() then return true end
    local labels = self:getConst().downloadLabels
    if not labels or table.isEmpty(labels) then return true end
    return self:callDownloadFunc("checkDownloadSuccess")
end

-- 同步所有数据
function Manager:updateData(data, skipSaveLocal, fromServer)
    if not data then return end

    self:getModel():fromServer(data, skipSaveLocal)
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

    for k, v in pairs(extraData or {}) do
        params[k] = v
    end
    DcUtil:UserTrack(params)
end

function Manager:hasQualifyDCToday()
    return self:getModel():getFlagFromLocalByKey(QualifyDCCacheKey, true)
end

function Manager:markQualifyDCToday()
    self:getModel():saveFlagToLocalByKey(QualifyDCCacheKey, true, true)
end

function Manager:tryJoinDC()
    if self:getModel():getFlagFromLocalByKey(JoinDCCacheKey, true) then return end

    self:dc("canyu", "join", nil, nil, nil, nil, nil, {actid = self:getConst().actId})
    self:getModel():saveFlagToLocalByKey(JoinDCCacheKey, true, true)
end

-- 是否是活动正式期最后一天
function Manager:isLastDay()
    local todayStartTime = getDayStartTimeByTS(TimeKit:timeInSec())
    local lastDayStartTime = getDayStartTimeByTS(math.floor(self:getModel():getMainEndTime()/1000))
    return todayStartTime == lastDayStartTime
end

-- 获取服务器时间是活动周期内的第几天
function Manager:getDayFromActOpen(time)
    if not self:isEnabled() then return 0 end
    local startTime = getDayStartTimeByTS(math.floor(self:getModel():getMainBeginTime()/1000))
    local curTime = getDayStartTimeByTS(time or TimeKit:timeInSec())
    return math.floor((curTime - startTime) / 86400) + 1
end

function Manager:getDayFrom1970(time)
    local curDayStartTime = getDayStartTimeByTS(time or TimeKit:timeInSec())
    return math.ceil(curDayStartTime / 86400)
end

-- 检测引导标记
function Manager:hasGuideIndex(index, checkLocalData)
    local hasIndex = self:getModel():hasGuide(index)

    if checkLocalData == nil then checkLocalData = true end
    if checkLocalData then
        local hasLocal = self:getModel():getFlagFromLocalByKey("LocalGuideId" .. index, false)
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
        self:getModel():saveFlagToLocalByKey("LocalGuideId" .. index, false, true)
    end

    local ActCommonHttp = require "amf.middleware.activity.http.ActCommonHttp"
    ActCommonHttp:setActGuideFlag(self:getConst().actId, index)
end

function Manager:onActPassDay()
	if not self:isEnabled2() then return end
    self:clearDoubleBuffNode()
    if not self:isEnabled() then return end
	self:getModel():passDayClear()
end

-- 主icon奖字
function Manager:hasRewards()
    return self:hasReward()
end

function Manager:hasReward()
    if not self:isEnabled2() then return false end
    return self:getMaxCanRewardTaskId() > 0
end

-- 普通的addRewards,开宝箱之类的
function Manager:addRewardsNormal(rewardItems, params)
    self:callPlug("Rewards", "addRewardsNormal", rewardItems, params)
end

function Manager:addActItem(reward)
end

function Manager:getProgress()
    return self:getModel():getDataByKey("periodInfo.progress", 0)
end

function Manager:setProgress(progress)
    progress = tonumber(progress) or 0
    self:getModel():setDataByKey("periodInfo.progress", progress)
end

function Manager:getShareCloseAct()
    return self.shareCloseAct
end

function Manager:setShareCloseAct(value)
    self.shareCloseAct = value
end

function Manager:hasDailyDoubleRemain()
    return self:getDailyDoubleRemain() > 0
end

function Manager:getDailyDoubleRemain()
    return tonumber(self:getModel():getDataByKey("dailyInfo.doubleRemain", 0)) or 0
end

function Manager:consumeDailyDoubleRemain()
    local doubleRemain = tonumber(self:getModel():getDataByKey("dailyInfo.doubleRemain", 0)) or 0
    if doubleRemain <= 0 then
        return false
    end
    self:getModel():setDataByKey("dailyInfo.doubleRemain", doubleRemain - 1)
    return true
end

function Manager:checkBeHelped()
    local beHelpedRemain = tonumber(self:getModel():getDataByKey("dailyInfo.beHelpedRemain", 1)) or 1
    return beHelpedRemain <= 0
end

function Manager:isReturnUser()
    return tonumber(self:getModel():getDataByKey("periodInfo.userType", 1)) == 2
end

function Manager:isTopUser()
    return self:getModel():getDataByKey("topPlayer", false)
end

function Manager:onActBeforeStartLevel()
    if not self:isEnabled() then return end
    self:clearIconTipProgressCache()
    if self:isTopUser() and self.needPlayTopAnim then
        self.needPlayTopAnim = nil
    end
    local beHelpedRemain = tonumber(self:getModel():getDataByKey("dailyInfo.beHelpedRemain", 1)) or 1
    local helpDoubleTimes = tonumber(self:getModel():getConfigByKey("beHelpedDoubleTimes")) or 5
    if beHelpedRemain <= 0 and self:getDailyDoubleRemain() <= helpDoubleTimes and self.needPlayHelpAnim then
        self.needPlayHelpAnim = nil
        local day = self:getDayFromActOpen()
        self:addGuideIndex(day, false)
    end
end

function Manager:shouldShowRecallInLevelToast()
    return not LocalDB:getBool(getRecallInLevelToastShownCacheKey(self), false)
end

function Manager:markRecallInLevelToastShown()
    LocalDB:setBool(getRecallInLevelToastShownCacheKey(self), true, true)
end

function Manager:getMainPanelTipPopCount()
    return self:getModel():getFlagFromLocalByKeyInt(MainPanelTipPopCountCacheKey, false, true, 0)
end

function Manager:addMainPanelTipPopCount()
    local count = self:getMainPanelTipPopCount() + 1
    self:getModel():saveFlagToLocalByKeyInt(MainPanelTipPopCountCacheKey, false, count, true)
end

function Manager:canPopMainPanelTip()
    return self:getMainPanelTipPopCount() <= 2
end

-- 关内在确认本关产生有效进度后、组装 passLevel 数据前调用。
-- 此接口只读取当前翻倍状态，不消费翻倍次数；次数统一在 updatePassLevelData 中消费。
---@param levelId number 本次结算的关卡 ID，预留给按关卡判断翻倍资格的规则。
---@param levelScene string 本次结算的关卡场景，预留给按场景判断翻倍资格的规则。
---@return boolean 本次有效进度是否翻倍。
function Manager:isPassLevelDoubleProgress(levelId, levelScene)
    if not self:isEnabled() then return false end
    if not self:hasDailyDoubleRemain() then return false end

    if LevelSceneFunc:isFullLevelLib(levelScene) then
        return true
    end

    local levelAreaManager = _G.amfBean("LevelAreaManager")
    local scoreNode = levelAreaManager and levelAreaManager:getUserScore(levelId, levelScene) or {}
    local star = tonumber(scoreNode.star) or 0

    if LevelSceneFunc:isHideLevel(levelScene) then
        return star ~= 3
    end

    if LevelSceneFunc:isMainLevel(levelScene) then
        local topPassedLevelId = _G.getTopPassedLevelId()
        if not topPassedLevelId then return false end

        if self:getLocalLevelStatus() == 1 then
            return tonumber(levelId) == topPassedLevelId + 1
        else
            return star ~= 4
        end
    end

    return false
end

function Manager:tryAddTopPlayerExtraDailyDoubleTimes(currentPassLevelId, jump)
    if self:isReturnUser() then return end
    if self:isTopUser() then return end

    if not currentPassLevelId then return end
    local configMaxLevel = amfBean("UnlockManager"):getUserMaxLevelId()
    if not configMaxLevel then return end

    local levelOffset = math.abs(tonumber(self:getModel():getConfigByKey("topPlayerLevelOffset")) or 90)
    local topLevelOffsetId = configMaxLevel - levelOffset
    local oldPassedLabelId = _G.getTopPassedLevelId()
    if oldPassedLabelId == nil then oldPassedLabelId = 1 end
    local oldCheck = (oldPassedLabelId + 1 == currentPassLevelId) or jump
    if not (currentPassLevelId == topLevelOffsetId and oldCheck) then return end

    local extraDoubleTimes = tonumber(self:getModel():getConfigByKey("topPlayerExtraDailyDoubleTimes")) or 0
    if extraDoubleTimes <= 0 then return end

    local doubleTotal = tonumber(self:getModel():getDataByKey("dailyInfo.doubleTotal", 0)) or 0
    local doubleRemain = tonumber(self:getModel():getDataByKey("dailyInfo.doubleRemain", 0)) or 0
    self:getModel():setDataByKey("dailyInfo.doubleTotal", doubleTotal + extraDoubleTimes)
    self:getModel():setDataByKey("dailyInfo.doubleRemain", doubleRemain + extraDoubleTimes)
    self:getModel():setDataByKey("topPlayer", true)
    self.needPlayTopAnim = true
end

-- 当前任务档位，从1开始，全部完成返回最后一个档位
function Manager:getCurrentRewardIndex()
    local rewardStates = self:getModel():getDataByKey("rewardStates", {}) or {}
    local progress = tonumber(self:getProgress()) or 0
    local ret = 1
    for index, rewardState in ipairs(rewardStates) do
        ret = index
        if progress < (tonumber(rewardState.needProgress) or 0) then
            break
        end
    end
    return ret
end

function Manager:getCurrentRewardNeedProgress()
    local rewardStates = self:getModel():getDataByKey("rewardStates", {}) or {}
    local currentIndex = self:getCurrentRewardIndex()
    local rewardState = rewardStates[currentIndex]
    local needProgress = rewardState and (tonumber(rewardState.needProgress) or 0) or 0
    local lastNeedProgress = 0
    if currentIndex > 1 then
        lastNeedProgress = tonumber(rewardStates[currentIndex - 1] and rewardStates[currentIndex - 1].needProgress) or 0
    end
    return math.max(needProgress - lastNeedProgress, 0)
end

function Manager:getCurrentRewardProgress()
    local rewardStates = self:getModel():getDataByKey("rewardStates", {}) or {}
    local currentIndex = self:getCurrentRewardIndex()
    local progress = tonumber(self:getProgress()) or 0
    local lastNeedProgress = 0
    if currentIndex > 1 then
        lastNeedProgress = tonumber(rewardStates[currentIndex - 1] and rewardStates[currentIndex - 1].needProgress) or 0
    end
    return math.max(progress - lastNeedProgress, 0)
end

function Manager:getRewardStageProgressList()
    local rewardStates = self:getModel():getDataByKey("rewardStates", {}) or {}
    local progress = tonumber(self:getProgress()) or 0
    local ret = {}
    local lastNeedProgress = 0

    for index, rewardState in ipairs(rewardStates) do
        local needProgress = tonumber(rewardState.needProgress) or 0
        local stageNeedProgress = math.max(needProgress - lastNeedProgress, 0)
        local stageProgress = math.max(math.min(progress - lastNeedProgress, stageNeedProgress), 0)
        table.insert(ret, {
            index = index,
            rewardId = rewardState.rewardId,
            progress = stageProgress,
            needProgress = stageNeedProgress,
            status = rewardState.status,
        })
        lastNeedProgress = needProgress
    end

    return ret
end

function Manager:getMaxCanRewardTaskId()
    local rewardStates = self:getModel():getDataByKey("rewardStates", {}) or {}
    local taskId = 0
    for index, rewardState in ipairs(rewardStates) do
        if tonumber(rewardState.status) == 1 then
            taskId = math.max(taskId, tonumber(rewardState.rewardId) or index)
        end
    end
    return taskId
end

function Manager:isLastRewardReceived()
    local rewardStates = self:getModel():getDataByKey("rewardStates", {}) or {}
    if table.isEmpty(rewardStates) then return false end

    local lastRewardState = rewardStates[#rewardStates]
    return tonumber(lastRewardState and lastRewardState.status) == 2
end

function Manager:removeActivityIcon()
    local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
    ActivityEventCenter:dispatch(ActivityEvent.REMOVE_ACTIVITY,{actId = self:getConst().actId})
    self:clearDoubleBuffNode()
end

function Manager:getRewardByTaskId(taskId)
    taskId = tonumber(taskId)
    if not taskId then return end

    local rewardMetas = self:getModel():getConfigByKey("rewardMetas", {}) or {}
    for _, rewardMeta in ipairs(rewardMetas) do
        if tonumber(rewardMeta.rewardId) == taskId then
            local reward = rewardMeta.reward or {}
            return {
                itemId = reward.itemId,
                num = reward.num,
            }
        end
    end
end

function Manager:createVineSkinRewardIcon(reward)
    if not reward or not reward.itemId then return end

    local dayNum = tonumber(reward.num) or 0
    local rewardIcon = GameItemCreator:createProp({
        itemId = reward.itemId,
    })
    if rewardIcon and dayNum > 0 then
        rewardIcon:setItemType(UEPropIcon_ItemType.TimeLimit)
        rewardIcon:setLeftTopText(tostring(dayNum) .. "天")
    end
    return rewardIcon
end

function Manager:getRewardCountByTaskId(taskId)
    taskId = tonumber(taskId)
    if not taskId then return 0 end

    local rewardCounts = self:getModel():getValue("userInfo.rewardCounts") or {}
    for _, rewardCount in ipairs(rewardCounts) do
        if tonumber(rewardCount.rewardId) == taskId then
            return tonumber(rewardCount.count) or 0
        end
    end
    return 0
end

function Manager:getRewardCounts()
    return self:getModel():getValue("userInfo.rewardCounts") or {}
end

function Manager:updateRewardStatesByProgress(progress)
    progress = tonumber(progress) or 0
    local rewardStates = self:getModel():getDataByKey("rewardStates", {}) or {}
    local rewardMetas = self:getModel():getConfigByKey("rewardMetas", {}) or {}
    local newRewardStates = {}

    if table.isEmpty(rewardStates) then
        for _, rewardMeta in ipairs(rewardMetas) do
            table.insert(newRewardStates, {
                rewardId = rewardMeta.rewardId,
                needProgress = rewardMeta.needProgress,
                status = progress >= (tonumber(rewardMeta.needProgress) or 0) and 1 or 0,
            })
        end
    else
        for _, rewardState in ipairs(rewardStates) do
            local status = tonumber(rewardState.status) or 0
            if status ~= 2 then
                status = progress >= (tonumber(rewardState.needProgress) or 0) and 1 or 0
            end
            table.insert(newRewardStates, {
                rewardId = rewardState.rewardId,
                needProgress = rewardState.needProgress,
                status = status,
            })
        end
    end

    self:getModel():setDataByKey("rewardStates", newRewardStates)
end

function Manager:getMaxProgress()
    local rewardStates = self:getModel():getDataByKey("rewardStates", {}) or {}
    local maxProgress = 0
    for _, rewardState in ipairs(rewardStates) do
        maxProgress = math.max(maxProgress, tonumber(rewardState.needProgress) or 0)
    end
    return maxProgress
end

-- 打关结束时更新数据
-- 关内通过 passLevelData.progressIncrement 传递本关进度增量：0 不计进度、1 普通进度、2 双倍进度。
-- 该参数的本地数据更新逻辑由关外活动维护方接入。
function Manager:updatePassLevelData(data, collectionCount, collectionMap, passLevelData)
    if not self:isEnabled() then return end
    
    local addProgress = tonumber(passLevelData and passLevelData.progressIncrement) or 0
    local oldDoubleRemain = self:getDailyDoubleRemain()
    if addProgress > 0 then
        local cacheAddProgress = tonumber(self.cacheAddProgress) or 0
        if cacheAddProgress <= 0 then
            self.cacheProgressBeforeAdd = tonumber(self:getProgress()) or 0
        end
        self.cacheAddProgress = cacheAddProgress + addProgress
        self:refreshLocalActInfo(addProgress)
    else
        self:clearIconTipProgressCache()
    end

    if addProgress > 1 then
        self:tryJoinDC()
    end

    self._pendingDoubleBuffNodeDecrease = nil
    if addProgress >= 2 then
        local newDoubleRemain = self:getDailyDoubleRemain()
        if oldDoubleRemain > newDoubleRemain then
            self._pendingDoubleBuffNodeDecrease = {
                from = oldDoubleRemain,
                to = newDoubleRemain,
            }
        end
    end

    if (addProgress > 0) and LevelSceneFunc:isMainLevel(data.levelInfo.levelScene) then
        local levelId = data and data.levelInfo and data.levelInfo.levelId
        self:tryAddTopPlayerExtraDailyDoubleTimes(levelId)
    end
end

function Manager:onActJumpLevelSuccess(evt)
    if not self:isEnabled() then return end

    local data = evt:getData()
    local levelId = data and data.levelId
    if not levelId then return end
    if not LevelSceneFunc:isMainLevel(data.levelScene) then return end
    self:tryAddTopPlayerExtraDailyDoubleTimes(levelId, true)
end

function Manager:refreshLocalActInfo(addProgress)
    if addProgress >= 2 then
        self:consumeDailyDoubleRemain()
    end
    local oldProgress = self:getProgress()
    local maxProgress = self:getMaxProgress()
    if maxProgress > 0 and oldProgress >= maxProgress then return end

    local current = oldProgress + addProgress
    if maxProgress > 0 then
        current = math.min(current, maxProgress)
    end
    self:setProgress(current)
    self:updateRewardStatesByProgress(current)
    self:updateTipView()
end

-- 返回1，2，3，对应普通主线、补星、关卡库
function Manager:getLocalLevelStatus(passLevel)
    local userState = _G.amfBean("UserStateManager"):getUserSegmentState()
    if (userState == _G.UserStateConst.UserSegmentState.FMZ) or (userState == _G.UserStateConst.UserSegmentState.MHZC) then
        return 3
    end

    if userState == _G.UserStateConst.UserSegmentState.FMJ then
        return 1
    else
        return 2
    end
end

------------------------------- 关卡外 -------------------------------

function Manager:updateTipView()
end

function Manager:checkDoubleBuffNodeEnabled()
    return self:isEnabled() and self:hasDailyDoubleRemain() and (not self:isLastRewardReceived())
end

function Manager:loadDoubleBuffNodeRes(callback, failCallback)
    if EnvUtil:isApp() then
        safeRunCall(callback)
        return
    end

    if self._isDoubleBuffNodeResReady then
        safeRunCall(callback)
        return
    end

    local resList = self:getConst().doubleBuffNodeResList or {}
    if table.isEmpty(resList) then
        self._isDoubleBuffNodeResReady = true
        safeRunCall(callback)
        return
    end

    self._doubleBuffNodeResCallbackList = self._doubleBuffNodeResCallbackList or {}
    table.insert(self._doubleBuffNodeResCallbackList, {callback = callback, failCallback = failCallback})

    if self._isDoubleBuffNodeResLoading then return end
    self._isDoubleBuffNodeResLoading = true
    AssetsUtil:loadMiniFiles(resList):next(function()
        self._isDoubleBuffNodeResLoading = nil
        self._isDoubleBuffNodeResReady = true
        local callbackList = self._doubleBuffNodeResCallbackList or {}
        self._doubleBuffNodeResCallbackList = nil
        for _, callbackInfo in ipairs(callbackList) do
            safeRunCall(callbackInfo.callback)
        end
    end, function()
        self._isDoubleBuffNodeResLoading = nil
        local callbackList = self._doubleBuffNodeResCallbackList or {}
        self._doubleBuffNodeResCallbackList = nil
        for _, callbackInfo in ipairs(callbackList) do
            safeRunCall(callbackInfo.failCallback)
        end
    end)
end

function Manager:updateDoubleBuffNode(canPlayAnim, callback)
    local finished = false
    local function finish()
        if finished then return end
        finished = true
        safeRunCall(callback)
    end

    if not SceneTopBannerContext or not SceneTopBannerConst then
        finish()
        return
    end

    local pendingDecrease = self._pendingDoubleBuffNodeDecrease
    if not self:checkDoubleBuffNodeEnabled() and not pendingDecrease then
        self:clearDoubleBuffNode()
        finish()
        return
    end

    local mgrContext = self
    local updateStarted = false
    local updateNodeFunction = function(node)
        updateStarted = true
        if not (isSafeCocosObj(node) and node.updateView) then
            finish()
            return
        end
        local decreaseInfo = mgrContext._pendingDoubleBuffNodeDecrease
        if not decreaseInfo and ((not mgrContext.needPlayTopAnim and not mgrContext.needPlayHelpAnim) or (not canPlayAnim)) then
            mgrContext._pendingDoubleBuffNodeDecrease = nil
            node:updateView()
            finish()
            return
        end

        local AsyncRunner = require "amf.script.sugar.AsyncRunner"
        local asyncRunner = AsyncRunner:create()
        if decreaseInfo then
            asyncRunner:add(function(done)
                if isSafeCocosObj(node) and node.playDoubleRemainDecreaseAnim then
                    node:playDoubleRemainDecreaseAnim(decreaseInfo.from, decreaseInfo.to, done)
                else
                    safeRunCall(done)
                end
            end)

            asyncRunner:add(function(done)
                mgrContext._pendingDoubleBuffNodeDecrease = nil
                safeRunCall(done)
            end)
        end
        if canPlayAnim and mgrContext.needPlayTopAnim then
            asyncRunner:add(function(done)
                if isSafeCocosObj(node) and node.updateView then
                    local playAnimNum = tonumber(self:getModel():getConfigByKey("topPlayerExtraDailyDoubleTimes")) or 5
                    local playAnimStr = string.format("冲顶福利，额外%d关", playAnimNum)
                    node:updateView(playAnimStr, playAnimNum)
                end
                setTimeOut(done, 3)
            end)

            asyncRunner:add(function(done)
                mgrContext.needPlayTopAnim = nil
                safeRunCall(done)
            end)
        end
        if canPlayAnim and mgrContext.needPlayHelpAnim then
            asyncRunner:add(function(done)
                if isSafeCocosObj(node) and node.updateView then
                    local playAnimNum = tonumber(self:getModel():getConfigByKey("beHelpedDoubleTimes")) or 5
                    local playAnimStr = string.format("求助成功，额外%d关", playAnimNum)
                    node:updateView(playAnimStr, playAnimNum)
                end
                setTimeOut(done, 3)
            end)

            asyncRunner:add(function(done)
                mgrContext.needPlayHelpAnim = nil
                local day = mgrContext:getDayFromActOpen()
                mgrContext:addGuideIndex(day, false)
                safeRunCall(done)
            end)
        end
        asyncRunner:add(function(done)
            local currentDoubleRemain = mgrContext:getDailyDoubleRemain()
            if currentDoubleRemain == 0 then
                if isSafeCocosObj(node) and node.playDisappearAnim then
                    node:playDisappearAnim(function()
                        mgrContext:clearDoubleBuffNode()
                        safeRunCall(done)
                    end)
                else
                    mgrContext:clearDoubleBuffNode()
                    safeRunCall(done)
                end
                return
            end

            safeRunCall(done)
        end)
        asyncRunner:add(function(done)
            finish()
            safeRunCall(done)
        end)
        asyncRunner:run()
    end

    local handler = _G.amfBean("SceneTopBannerHandler")
    local node = handler and handler:getShowBanner(SceneTopBannerConst.Priority.BIG_VINE_SKIN)
    if isSafeCocosObj(node) then
        safeRunCall(updateNodeFunction, node)
        return
    end

    local context = SceneTopBannerContext.new()
        :setPriority(SceneTopBannerConst.Priority.BIG_VINE_SKIN)
        :setBannerCreator(function()
            local VineSkinDoubleBuffNode = require "amf.feature.localactivity.bigvineskinact.view.VineSkinDoubleBuffNode"
            return VineSkinDoubleBuffNode:create()
        end)
        :setAutoDisappear(false)
        :setCallbacks(function(node)
            if isSafeCocosObj(node) then
                safeRunCall(updateNodeFunction, node)
            else
                finish()
            end
        end)

    _G.amfTransaction(TransactionEvent.SCENE_TOP_BANNER, context)
    setTimeOut(function()
        if not updateStarted then
            finish()
        end
    end, 1)
    setTimeOut(function()
        if updateStarted then
            finish()
        end
    end, 3)
end

function Manager:clearDoubleBuffNode()
    if not SceneTopBannerContext or not SceneTopBannerConst then return end
    local context = SceneTopBannerContext.new()
        :setPriority(SceneTopBannerConst.Priority.BIG_VINE_SKIN)
        :setRemove(true)
    _G.amfTransaction(TransactionEvent.SCENE_TOP_BANNER, context)
end

function Manager:onMarkPreOpenEvent(evt)
    if not self:checkMarkBannerEnable() then return end

    local contextList = evt:getData() or {}
    local context = MarkPreOpenContext.new()
        :setPriority(ActFestivalConst.Priority.LINK_ACTIVITY)
        :setExtLoadFiles({
            "amf/activity/bigvineskinact/materials/vineBannerBg.png",
        })
        :setEnabledCheckFunc(function()
            return self:checkMarkBannerEnable()
        end)
        :setPreOpenFunc(function(callback)
            safeRunCall(callback)
        end)
        :setBannerCreator(function()
            local uiData = require "amf.feature.localactivity.bigvineskinact.view.uisource.VineSignInBanner_UI"
            local banner, mbsMap = UIBuilder.new(uiData):buildUIWithData()
            banner:setAnchorPoint(ccp(0, 0))
            banner:setPositionXY(0, 0)

            local bannerNode = mbsMap and mbsMap.bannerNode or banner:findChildByName("bannerNode")
            if isSafeCocosObj(bannerNode) then
                local bg = UICreateUtil:createSpriteFile("amf/activity/bigvineskinact/materials/vineBannerBg.png", true)
                if bg then
                    bg:setAnchorPoint(ccp(0.5, 0.5))
                    bannerNode:addChild(bg)
                end
            end

            local timeText = mbsMap and mbsMap.timeText or banner:findChildByName("timeText")
            if isSafeCocosObj(timeText) then
                local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
                TimeUtil:countDownLabel(timeText, TimeKit:tryConvertMsToSec(self:getModel():getMainEndTime()), nil, "已结束", nil, YH_REF_MAP.noEarClock_t)
            end

            local btnPosNode = mbsMap and mbsMap.btnPosNode or banner:findChildByName("btnPosNode")
            if isSafeCocosObj(btnPosNode) then
                local UIButton = require "amf.middleware.ui.kit.component.button.UIButton"
                local btn = UIButton:createButton({
                    scaleMode = UIButtonConfig.BtnScales.k50,
                    str = "去看看",
                    touchFunc = function()
                        if not self:checkMarkBannerEnable() then
                            CommonTip:showTip(self:getConst().actChName .. "活动已结束!")
                            return
                        end
                        _G.amfBean("AutoPopupMgr"):resetPopup()
                        MarkEventCenter:dispatch(MarkEvent.MARK_CLOSE)
                        self:openActivity(nil, {from = "sign_in"}, true)
                    end,
                })
                btnPosNode:addChild(btn)
            end

            return banner
        end, ccp(0, 2))
    table.insert(contextList, context)
end

function Manager:checkMarkBannerEnable()
    return self:isEnabled() and (not self:isLastRewardReceived())
end

function Manager:getActInfo()
    return _G.amfBean("ActivityMgr"):getActInfo(self:getConst().actId)
end

-- 主icon数字
function Manager:getShowMsgNum()
    return self:getMsgNum()
end

function Manager:getMsgNum()
    return 0
end

function Manager:checkCanReward()
    if not self:isEnabled() then return false end
    return self:getMaxCanRewardTaskId() > 0
end

function Manager:tryOpenGetRewardPanel(sucCallback, failCallback, checkSkinGuide)
    local rewardId = self:getMaxCanRewardTaskId()
    if rewardId <= 0 then
        return false
    end

    local callback = sucCallback
    if checkSkinGuide then
        callback = function()
            if self:checkCanPopOwnedSkinGuide() then
                self:popOwnedSkinGuide(sucCallback)
            else
                safeRunCall(sucCallback)
            end
        end
    end

    -- 领奖成功应该设置actInfo没奖状态
    self:requestReward(rewardId, callback, failCallback)
    return true
end

function Manager:getRequestRewardDCRewardIndexString(rewardId)
    rewardId = tonumber(rewardId) or 0
    local rewardStates = self:getModel():getDataByKey("rewardStates", {}) or {}
    local rewardIndexList = {}

    for index, rewardState in ipairs(rewardStates) do
        local stateRewardId = tonumber(rewardState.rewardId) or index
        if stateRewardId <= rewardId and tonumber(rewardState.status) == 1 then
            table.insert(rewardIndexList, tostring(index))
        end
    end

    if table.isEmpty(rewardIndexList) then return end
    return table.concat(rewardIndexList, "_")
end

function Manager:requestReward(rewardId, successCallback, failCallback, closeActCallback)
    self:tryJoinDC()
    local rewardDCIndexString = self:getRequestRewardDCRewardIndexString(rewardId)
    if rewardDCIndexString then
        self:dc("vine_decorate", "main_panel_reward", nil, rewardDCIndexString)
    end

    return self:getModel():requestReward({
        rewardId = rewardId,
    }):next(function(response)
        -- response.data: { rewardItems = { itemId, num, expireTime }, rewardStates = { { rewardId, needProgress, status }, ... } }
        local data = response:getData() or {}
        if data.rewardStates then
            self:getModel():setDataByKey("rewardStates", data.rewardStates)
        end
        self:callPlug("Act", "updateTipView")

        if self:isLastRewardReceived() then
            self:removeActivityIcon()
        end

        local rewardItems = data.rewardItems or {}
        if not table.isEmpty(rewardItems) then
            self:callPlug("Rewards", "addRewardsNormal", rewardItems, {
                dcExtra = {
                    dcFeature = self:getConst().dcFeature,
                    dcSource = "main_panel_reward",
                },
            })

            local trialState = self:getTrialSkinState()
            if trialState then
                for _, reward in ipairs(rewardItems) do
                    if tonumber(reward.itemId) == trialState.skinId then
                        self:updateTrialUsingSkinState(trialState.skinId)
                        break
                    end
                end
            end
        end

        local rewardItem
        if not table.isEmpty(rewardItems) then
            rewardItem = table.clone(rewardItems[#rewardItems])
        end
        self:openGetVineSkinPanel({
            rewardItem = rewardItem,
            rewardId = rewardId,
            closeCallback = successCallback,
            shareCallback = function()
                self:setShareCloseAct(true)
                safeRunCall(closeActCallback)
            end,
            putOnCallback = function()
                self:setShareCloseAct(true)
                safeRunCall(closeActCallback)
            end,
        })
    end, function(response)
        if response and not response:isCancel() then
            CommonTip:showErrorTip(response)
        end
        safeRunCall(failCallback, response)
    end)
end

function Manager:createGetVineSkinPanel(delegate)
    local PanelVM = require "amf.feature.localactivity.bigvineskinact.view.GetVineSkinPanelVM"
    return PanelVM:create(delegate or {})
end

function Manager:openGetVineSkinPanel(delegate)
    local vm = self:createGetVineSkinPanel(delegate)
    vm:popout()
    return vm
end

function Manager:onActActInfoUpdate(event)
    local data = event:getData()
    local actInfos = data.actInfos or {}
    local fromServer = data.fromServer
    local actInfo = actInfos[tostring(self:getConst().actId)]
    if not (fromServer and actInfo) then return end

    if self:isEnabled() and actInfo.extra then
        local extra = type(actInfo.extra) == "string" and table.deserialize(actInfo.extra) or actInfo.extra
        if extra then
            if extra.progress then
                self:setProgress(extra.progress)
            end

            local doubleUsed = tonumber(extra.doubleUsed)
            local doubleTotal = tonumber(extra.doubleTotal)
            if doubleTotal then
                self:getModel():setDataByKey("dailyInfo.doubleTotal", doubleTotal)
            end
            if doubleUsed and doubleTotal then
                self:getModel():setDataByKey("dailyInfo.doubleRemain", math.max(doubleTotal - doubleUsed, 0))
            end

            local actInfoBehelpRemain = extra.beHelpedRemain or 1
            if actInfoBehelpRemain then
                self:getModel():setDataByKey("dailyInfo.beHelpedRemain", actInfoBehelpRemain)
            end
        end
    end

    if self:isEnabled2() and not self:isResEnabled() then
        self:callDownloadFunc("startDownload")
    end

    self:updateTipView()
end

function Manager:onActEnterMainScene(evt)
    if self:isEnabled2() and not self:isResEnabled() then
        self:callDownloadFunc("startDownload")
    end
    self:updateTipView()
end

function Manager:openActivity(closeCallback, extra, userClick)
    extra = extra or {}
    self:callPlug("Act", "openActivity", {
        actId = self:getConst().actId,
        extra = extra,
        failCallback = closeCallback,
        endCallback = closeCallback,
        userClick = userClick,
    })
end

function Manager:putOnNewSkin(itemId, callback, dontQueryFlowerChange)
    local mgr = _G.amfBean("PersonalCenterManager")
    if not mgr then
        safeRunCall(callback)
        return
    end
    mgr:setVineSkinType(itemId, callback, dontQueryFlowerChange)
end

function Manager:getDoubleBuffNodeShowRemain()
    local remain = self:getDailyDoubleRemain()
    self:calNeedPlayHelpAnim()
    if self.needPlayHelpAnim then
        local helpDoubleTimes = tonumber(self:getModel():getConfigByKey("beHelpedDoubleTimes")) or 5
        remain = remain-helpDoubleTimes
    end
    if self.needPlayTopAnim then
        local extraDoubleTimes = tonumber(self:getModel():getConfigByKey("topPlayerExtraDailyDoubleTimes")) or 5
        remain = remain-extraDoubleTimes
    end
    return remain
end

function Manager:checkCanPopBonusAnim()
    if not self:isEnabled() then return false end
    self:calNeedPlayHelpAnim()
    if EnvUtil:isDevelopMode() then
        printx(42, "checkCanPopBonusAnim help, top, doubledecrease", self.needPlayHelpAnim, self.needPlayTopAnim, tts(self._pendingDoubleBuffNodeDecrease))
    end
    return self.needPlayHelpAnim or self.needPlayTopAnim or self._pendingDoubleBuffNodeDecrease
end

function Manager:popBonusAnim(onPopOver)
    if not self:checkCanPopBonusAnim() then
        safeRunCall(onPopOver)
        return
    end

    self:loadDoubleBuffNodeRes(function()
        self:updateDoubleBuffNode(true, onPopOver)
    end, onPopOver)
end

function Manager:onHandlePassLevelBonusAnim(event)
    local function redeliver()
        event:redeliver()
    end

    if not self:checkCanPopBonusAnim() then
        redeliver()
        return
    end

    _G.amfBean("AutoPopupMgr"):blockPassLevelSkip()
    self:popBonusAnim()

    local delayTime = 0
    if self._pendingDoubleBuffNodeDecrease then
        delayTime = delayTime + 1
    end
    if self.needPlayTopAnim then
        delayTime = delayTime + 2
    end
    if self.needPlayHelpAnim then
        delayTime = delayTime + 2
    end

    if delayTime <= 0 then
        redeliver()
        return
    end

    setTimeOut(redeliver, delayTime)
end

return Manager
