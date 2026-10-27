local Meta = {}

Meta.bShowLog = true
Meta.autoDownload = false
Meta.downloadLabels = {}
Meta.passTopNums = "passTopNums"
Meta.winStreakNums = "winStreakNums"
Meta.farmStarWinStreakNums = "farmStarWinStreakNums"
Meta.cycleId = "cycleId"
Meta.periodId = "periodId"
Meta.type = "type"
Meta.reward = "reward"
Meta.triggerTs = "triggerTs"
Meta.group = "group"
Meta.groupV2 = "group2025"
Meta.offGroup = "offGroup"
Meta.callback = "callback"
Meta.normalRewardPool = "normalRewardPool"
Meta.unlimitRewardPool = "unlimitRewardPool"
Meta.periodInfo = "periodInfo"
Meta.unlimitRewardInterval = "unlimitRewardInterval"
Meta.minTriggerLevelNums = "minTriggerLevelNums"
Meta.minTopLevelId = "minTopLevelId"
Meta.maxTopLevelId = "maxTopLevelId"
Meta.peakTopLevelId = "peakTopLevelId"
Meta.triggerPassedLevel = "triggerPassedLevel"
Meta.triggerDayFirstEnterTip = "triggerDayFirstEnterTip"
Meta.reviveCardInfo = "reviveCardInfo"

Meta.ReviveCardDeliveryMode = {
	kClickContinue = 1,
	kTakeButton = 2,
}

-- 复活卡确认面板曝光打点 t1：面板来源
Meta.ReviveConfirmEnterType = {
	kStartPanel = 1,
	kAutoPop = 2,
	kRetryPanel = 3,
}

Meta.defaultFuuuConfigVersion = 66
Meta.defaultFuuuConfigVersionV2 = 0

Meta.passLevelId = 300

-- 上次领奖进度条进度值
Meta.lastRewardProgress = "SuperMagicBird2024_lastRewardProgress"
-- 活动期强弹一次主面板
Meta.hasActFirstTimeShowMainPanel = "SuperMagicBird2024_hasActFirstTimeShowMainPanel"
-- 是否第一次显示激活动画
Meta.hasShowBirdActivateAnim = "SuperMagicBird2024Manager_hasShowBirdActivateAnim"
-- 激活后第一次打开主面板显示tip
Meta.firstTimeShowBirdTip = "SuperMagicBird2024Manager_firstTimeShowBirdTip"
Meta.isPassLevelWin = "SuperMagicBird2024Manager_isPassLevelWin"
-- icon进度条上次进度
Meta.lastTimeProgressValue = "SuperMagicBird2024Manager_lastTimeProgressValue"

Meta.todayHasShowBirdTip = "SuperMagicBird2024Manager_todayHasShowBirdTip"
--
Meta.todayHasShowIconTip = "SuperMagicBird2024Manager_todayHasShowIconTip"
Meta.dcQualifyDaily = "SuperMagicBird2024Manager_dcQualifyDaily"
Meta.dcJoinDaily = "SuperMagicBird2024Manager_dcJoinDaily"

--每周弹一次没新关，关活动。
Meta.weekPopTopLevelNotEnoughKey = "SuperMagicBird2024_weekPopTopLevelNotEnoughKey"

Meta.godTip = "恭喜达到最新关卡，【超级魔力鸟】活动结束！继续冲顶吧~"
Meta.godTip2 = "恭喜满级！超级魔力鸟助力结束~"
Meta.godTip3 = "有关卡可更新，快更新到最新版本并联网重进游戏，继续享受超级魔力鸟吧~"

Meta.bottomMostLevelConfig = 1000

Meta.superMagicBirdItemId=10118

------------zhigang -----------
Meta.MagicBirdActiveType = {
	kNormal = 0,
	kActive = 1,
}

Meta.extraRewardLogForm = {
	kNone = 0, --未知
	kMemeHu = 1,--么么狐来源
}

Meta.fuuuTypeList = {
	kNone = -1,
	kV0 = 0, --偏移
	kV1 = 1,--难度
	kV2 = 2,--步数
	kV3 = 3, --偏移新
	kV4 = 4, --偏移新2
}

--难度调整版本
Meta.fuuuVersion = {
	kNone = 0,
	kV1 = 1,
	kV2 = 2,
}

Meta.version = 6 --kV1的难度调整逻辑version
Meta.versionV2 = 6 --kV2的难度调整逻辑version

Meta.LevelStateList = {
	kNone = 0,
	kTopLevel = 1,
	kRefreshStar = 2,
	kLevelLibrary = 3,
}

Meta.keepWinReason = {
	kNone = 1,
	kCallBack = 2,
	kCycleOld = 3,
}

Meta.PeriodPopMainPanel1 = "SuperMagicBird2024Manager_PeriodPopMainPanel1"
Meta.PeriodPopMainPanel2 = "SuperMagicBird2024Manager_PeriodPopMainPanel2"
Meta.PeriodPopMainPanel3 = "SuperMagicBird2024Manager_PeriodPopMainPanel3"


function Meta:getCurWeekLevelNotEnoughKey()
	local timeSec = getWeekStartTimeByTS( TimeKit:timeInSec() )
	return Meta.weekPopTopLevelNotEnoughKey..'_'..timeSec
end

--引导标记
Meta.GuideIds = {
	kGuideProp = 10, --关卡内道具引导
	KPopStartLevelGuide = 11, --主界面引导
}

-- 超鸟目前已常驻化，periodId固定为5
Meta.defaultPeriodId = 5

function Meta:showLog( ... )
	UBFDeprecate("别调了，用_G.SmbLog替代")
	if _G.SmbLog then
		_G.SmbLog("***超鸟连胜fuuu判断V2***", ...)
	end
end


return Meta
