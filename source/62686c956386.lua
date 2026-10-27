
AutoPopupConst = {}

--强弹场景
AutoPopupConst.PopStage = {
	STAGE_ONE = "ps_login_scene",
	STAGE_TWO = "ps_enter_from_outside",
	STAGE_THREE = "ps_enter_from_level_first",
	STAGE_FOUR = "ps_enter_from_level_second",
}

AutoPopupConst.PopStageId = {
	STAGE_ONE = 1,
	STAGE_TWO = 2,
	STAGE_THREE = 3,
	STAGE_FOUR = 4,
}

AutoPopupConst.PopStageKeyMapping = {
	["1"] = AutoPopupConst.PopStage.STAGE_ONE,
	["2"] = AutoPopupConst.PopStage.STAGE_TWO,
	["3"] = AutoPopupConst.PopStage.STAGE_THREE,
	["4"] = AutoPopupConst.PopStage.STAGE_FOUR,
}

--强弹类型
AutoPopupConst.PopType = {
	POLICY = "pt_policy",
	OUTSIDE = "pt_outside",
	SYSTEM = "pt_system",
	ACTIVITY = "pt_activity",
	RECALL = "pt_recall",
	CONDITION = "pt_condition",
	FUNCTION = "pt_function",
	CRASH_RESUME = "pt_crash_resume",
	GUIDE = "pt_guide",
	GIFT_PACK = "pt_gift_pack",
	TMP_ACT_PANEL = "pt_temp_act_panel",
}

AutoPopupConst.PopTypeKeyMapping = {
	A = AutoPopupConst.PopType.POLICY,
	B = AutoPopupConst.PopType.OUTSIDE,
	C = AutoPopupConst.PopType.SYSTEM,
	D = AutoPopupConst.PopType.ACTIVITY,
	E = AutoPopupConst.PopType.RECALL,
	F = AutoPopupConst.PopType.CONDITION,
	G = AutoPopupConst.PopType.FUNCTION,
	H = AutoPopupConst.PopType.CRASH_RESUME,
	I = AutoPopupConst.PopType.GUIDE,
	J = AutoPopupConst.PopType.GIFT_PACK,
	K = AutoPopupConst.PopType.TMP_ACT_PANEL,
}

-- 本地数据版本
AutoPopupConst.CacheVersion = 1

AutoPopupConst.Stage3PopupState = {
	NONE = "s3_none",
	START_LEVEL_POP = "s3_start_level_pop",
	START_LEVEL_NO_POP = "s3_start_level_no_pop",
}

AutoPopupConst.MetaPopupRules = {
	EVERY_DAY = "R1",
	A_LIFE_TIME = "R2",
	EVERY_TIME = "R3",
}

-- 自动进关原因
AutoPopupConst.StartLevelSource = {
	-- 低等级
	LOW_LEVEL = 1,
	BACK_USER = 2,
	DOUYIN_FEED = 3,
	WX_FEED_TRIAL = 4,
}

-- -- 包内功能，在强弹中有特殊引用时，赋予其唯一ID
-- -- 所谓引用包括不限于：icon发现新活动，ai控制强弹等
AutoPopupConst.FunctionID = {
-- 	kStoreAI = 100001,					--AI促销礼包
-- 	kStorePromotion = 100002, 			--商店促销礼包
-- 	kVipPass = 100003, 					--通行证
-- 	kIslandWater = 100004,				--种植岛屿水滴翻倍
-- 	kCloverRaceGroup = 100005,			--晋级赛进组
-- 	-- kGarden = 100006,                --新岛屿
-- 	kRapWinningStreak2022 = 100007, 	--rap连胜功能版
	kPromoteDailyClimb = 100008,        --促每日闯关
-- 	kExchangeShop = 100009,				--常驻兑换商城
}
