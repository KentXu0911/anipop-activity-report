
local AutoPopupLimit = {}

-- 每日弹出次数上限 不配置默认为1次 手动点击将消耗弹出次数
AutoPopupLimit.CheckPointNumLimit = {
    [PopupCheckPoint.FORBID_PLAYING] 				 = -1,
    [PopupCheckPoint.ANTI_ADDICTION] 				 = -1,
    [PopupCheckPoint.RECALL_SHIMING] 				 = -1,
    [PopupCheckPoint.HW_SHIMING_SYNC_ALERT] 		 = -1,
    [PopupCheckPoint.SL_ALERT] 						 = -1,
    [PopupCheckPoint.PLAY_LEVEL_BACK] 				 = -1,
    [PopupCheckPoint.EXIT_LEVEL_JUMP] 		         = -1,
    [PopupCheckPoint.CRASH_RESUME_MAIN] 			 = -1,
    [PopupCheckPoint.AUTO_START_LEVEL_DY_FEED]       = -1,
    [PopupCheckPoint.AUTO_START_LEVEL_WX_FEED_TRIAL] = -1,
    [PopupCheckPoint.AUTO_START_LEVEL] 				 = -1,
    -- [PopupCheckPoint.AUTO_START_LEVEL_BACK_USER] 	 = -1,
    [PopupCheckPoint.ANNOUNCEMENT] 					 = -1,
    [PopupCheckPoint.BIND_PHONE] 					 = -1,
    [PopupCheckPoint.SUB_MSG] 						 = -1,
    [PopupCheckPoint.SUB_MSG_STAGE4]   				 = -1,
    [PopupCheckPoint.CLIMB_GIFT] 					 = -1,
    -- [PopupCheckPoint.ICE_BREAKER_GIFT] 		     = -1,
    [PopupCheckPoint.SCROLL_TO_CURRENT_LEVEL] 		 = -1,
    [PopupCheckPoint.ADD_MINE] 						 = -1,
    [PopupCheckPoint.ADD_MINE_STAGE4]   			 = -1,
    [PopupCheckPoint.ACT_NEW]                        = -1,
    [PopupCheckPoint.ACT_MAIN_PANEL_STAGE_2]         = -1,
	[PopupCheckPoint.ACT_MAIN_PANEL_STAGE_4]         = -1,
	[PopupCheckPoint.MID_AUTUMN_NATIONAL_DAY_2026_MAIN_POP_STAGE_2] = 1, -- 2026.09.24-2026.10.07每日最多一次，场景2
    [PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_3_1] = -1,
    [PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_3_2] = -1,
    [PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_3_3] = -1,
    [PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_4_1] = -1,
    [PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_4_2] = -1,
    [PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_4_3] = -1,
    [PopupCheckPoint.LEVEL_POINTS_RACE_STAGE3]       = -1,
    [PopupCheckPoint.COMBO_BOTTLE]                   = -1,
    [PopupCheckPoint.CONTINUOUS_TARGET_CHECK]        = -1,
    [PopupCheckPoint.CONTINUOUS_TARGET_CHECK2]       = -1,
    [PopupCheckPoint.COLLECT_WORD]                   = -1,
    [PopupCheckPoint.COLLECT_WORD_SHARE]             = -1,
    [PopupCheckPoint.PERSONAL_CARD_GUIDE]            = -1,
    [PopupCheckPoint.ADD_FIVE_STEP]                  = -1,
    [PopupCheckPoint.NEWBIEOPTIMIZE_STAGE]           = -1,
    [PopupCheckPoint.WATERFALL_GIFT]                 = -1,
    [PopupCheckPoint.WATERFALL_PROGRESS]             = -1,
    [PopupCheckPoint.FULL_STAR_LEVEL_LIB]            = -1,
    [PopupCheckPoint.USER_PROTOCAL]                  = -1,
    [PopupCheckPoint.EFFECT_MATCH_CHECK_STAGE_2]     = 1,
    [PopupCheckPoint.PROMOTE_DAILY_STAGE3]           = -1,
    [PopupCheckPoint.PROMOTE_DAILY]                  = -1,
    [PopupCheckPoint.PROMOTE_DAILY_REPAIR_STAGE2]    = -1, -- 活动期内1次，由活动本地标记控制
    [PopupCheckPoint.ALIPAY_GAMECENTER_FIRST]        = -1,
    [PopupCheckPoint.ALIPAY_GAMECENTER_REVISIT]      = -1,
    [PopupCheckPoint.PROMOTION_2025]                 = -1,
    [PopupCheckPoint.PEAK_RANK_REWARD]               = -1,
    [PopupCheckPoint.RECALL_2025_STAGE2]             = -1,
    [PopupCheckPoint.RECALL_2025_STAGE4]             = -1,
    [PopupCheckPoint.DY_MINI_OPEN_START_PANEL]       = -1,
    [PopupCheckPoint.DY_FEED_SUBSCRIBE_GUIDE]       = 1,
    [PopupCheckPoint.SH01_MAIN_POP]                  = -1,
    [PopupCheckPoint.STARWANDBUFF_GUIDE]             = -1,
    [PopupCheckPoint.COIN_PROMOTIONS_POP]            = -1,
    [PopupCheckPoint.MUSIC_MASTER]                   = -1,
    [PopupCheckPoint.SPRINGFESTIVAL26_FUBEN_STAGE3]  = -1,
    [PopupCheckPoint.MAIN_SCENE_BUTTON]              = -1,
    [PopupCheckPoint.LUCKY_BAG_PARTY_MOVE_GUIDE]     = -1,
    [PopupCheckPoint.ACTIVITY_CENTER_MOVE_GUIDE]     = -1,
    [PopupCheckPoint.ACTIVITY_CENTER_BANNER]         = -1,
    [PopupCheckPoint.FEATURE_UNLOCK_GUIDE]           = -1,
    [PopupCheckPoint.WIDGET_REWARD_ACT] 			 = -1,
    [PopupCheckPoint.CLICK_LINK_BIND_WECHAT_PAY]     = -1,
    [PopupCheckPoint.COMPETITION_AUDITIONS_ENTRY]    = -1,
    [PopupCheckPoint.CLICK_LINK_WECHAT_FAQ]          = -1,
    [PopupCheckPoint.SPRINT_GIFT_CHECK_STAGE_2]      = -1,
    [PopupCheckPoint.EXPLORE_MAP_GAME_DAILY_POP]     = 1,
    [PopupCheckPoint.EXPLORE_MAP_GAME_YINLIU_STAGE4_POP] = -1,
    [PopupCheckPoint.EXPLORE_MAP_GAME_DAILY_GIFT_POP]= -1,
    [PopupCheckPoint.CLIMB_TOWER_TRIGGER]            = -1, -- 正式期/领奖期各1次，本地缓存自控
    [PopupCheckPoint.BIG_VINE_SKIN_TRIGGER_DAY1]     = 1, -- 每期一次，由强弹框架控制
    [PopupCheckPoint.BIG_VINE_SKIN_SCHEDULED_DAY]    = 1,  -- 活动第5/8/12天，每个目标日最多一次
    [PopupCheckPoint.BIG_VINE_SKIN_TRIAL_EXPIRED]    = -1, -- 由试戴结束待提示状态控制
    [PopupCheckPoint.BIG_VINE_SKIN_TRIAL_CARD]       = -1, -- 由试戴卡获得待提示状态控制
    [PopupCheckPoint.BIG_VINE_SKIN_OWNED_GUIDE]      = -1, -- 永久一次，由强弹框架控制
    [PopupCheckPoint.COLLECT_CARD_FLOW_POP_STAGE2]   = -1,
    [PopupCheckPoint.COLLECT_CARD_FLOW_POP_STAGE4]   = -1,
    [PopupCheckPoint.PROMOTION_CARD_PACK_POP_STAGE4] = -1,
    [PopupCheckPoint.COLLECT_CARD_DAILY_GIFT_POP]    = 2,
    [PopupCheckPoint.COLLECT_CARD_PROGRESS_TIP]      = -1,
    [PopupCheckPoint.COLLECT_CARD_THREE_FOR_ONE_MAIN_POP] = -1, -- 次数由活动包内 24 小时 CD 控制
    [PopupCheckPoint.CLICK_LINK_WECHAT_FAQ]          = -1,
    [PopupCheckPoint.RECALL_OPEN_START_PANEL]        = -1,
    [PopupCheckPoint.HAPPY_DELIVERY_TIP_STAGE4]      = 1,
    [PopupCheckPoint.LUCKY_DELIVERY_TIP]             = 1,
    [PopupCheckPoint.SHOP_REWARD_MAIN_POP]           = -1, -- 每期1次，本地缓存自控
    [PopupCheckPoint.BATTLE_PASS_TRIGGER]            = -1, -- 活动期内1次，由 sendPermanentData 控制
    [PopupCheckPoint.BATTLE_PASS_UNBUY_COMPLETE]     = -1, -- 活动期内1次，由 sendPermanentData 控制
    [PopupCheckPoint.BATTLE_PASS_BUY_COMPLETE]       = -1, -- 活动期内1次，由 sendPermanentData 控制
    [PopupCheckPoint.BATTLE_PASS_REWARD_SETTLE]      = -1, -- 活动期内1次，由 sendPermanentData 控制
    [PopupCheckPoint.LUCKY_DELIVERY_PASS_COMPENSATE] = -1, -- 正式期每日1次由 localCache 控制，领奖期不限制
    [PopupCheckPoint.MERGE_POP_MAIN_STAGE_2]      = 1,
    [PopupCheckPoint.PET_MAIN_POP_STAGE_2]        = -1,
    [PopupCheckPoint.RETURN_GIFT_POP]      = -1,
	[PopupCheckPoint.LUCKY_FARM_STAR_NOTICE] = -1, -- 每期一次，由活动本地缓存控制
    [PopupCheckPoint.SUPER_MAGIC_BIRD_REVIVE] = 1,
    [PopupCheckPoint.SUPER_MAGIC_BIRD_REVIVE_CONFIRM] = -1, -- 每次断鸟触发一次，由活动内一次性标记控制
    [PopupCheckPoint.HAPPY_MATCH_YINLIU_STAGE4]      = -1, -- 开心对对碰引流，本地缓存自控
    [PopupCheckPoint.LUCKY_DELIVERY_STAGE3]      = -1,
    [PopupCheckPoint.ELIMINATE_FESTIVAL_2026_COMIC_STAGE2]  = -1, -- 活动期内1次，由 GuideFlag 控制
    [PopupCheckPoint.ELIMINATE_FESTIVAL_2026_COMIC_STAGE4]  = -1, -- 活动期内1次，由 GuideFlag 控制
    [PopupCheckPoint.ALIPAY_DESKTOP_SHORTCUT_FIRST_LOGIN]  = -1, -- 支付宝小游戏桌面有礼：首次登录强弹
    [PopupCheckPoint.ALIPAY_DESKTOP_SHORTCUT_STREAK_BREAK] = -1, -- 支付宝小游戏桌面有礼：断连胜强弹
    [PopupCheckPoint.PENGPENG2026_MAIN_PANEL_STAGE4]       = 1, -- 飞碟弹弹乐主面板每日场景4强弹1次
    [PopupCheckPoint.PENGPENG2026_ATTRACT_PANEL_STAGE4]    = 1, -- 飞碟弹弹乐引流面板每日场景4强弹1次
    [PopupCheckPoint.LAYERED_TILE_MATCH_MAIN_POP_STAGE_4]  = 1, -- 开心农家乐主面板每日场景4强弹1次
    [PopupCheckPoint.GEM_MINING_MAIN_POP_STAGE_4]          = 1, -- 挖宝石主面板每日场景4强弹1次
    [PopupCheckPoint.LAYERED_TILE_MATCH_DAILY_GIFT_POP]    = 1, -- 开心农家乐闯关流程礼包每日场景4强弹1次
    [PopupCheckPoint.DAILY_LEVEL_STAGE2]         = -1, -- 每期1次，由 GuideFlag 控制
    [PopupCheckPoint.SUPER_MAGIC_BIRD_REAL_GIFT_STAGE2] = -1, -- 活动期1次，由活动本地标记控制
    [PopupCheckPoint.DAILY_LEVEL_STAGE4]         = 1,  -- 限制每天一次
	[PopupCheckPoint.SUPER_BIRD_SHARE_FIRST_STAGE4] = -1, -- 活动期一次，由活动业务条件控制
	[PopupCheckPoint.SUPER_BIRD_SHARE_REWARD] = -1, -- 有活动奖励可领取时不限制每日弹出次数
    [PopupCheckPoint.UNDERTHESIN_STAGE4_POP]               = -1, -- 拾光成歌场景4强弹，主面板一次，引流最多3次

    [PopupCheckPoint.BLOCK_STAGE4_POP]           = -1,
    [PopupCheckPoint.BIG_GIVEAWAY_STAGE4_POP]    = 1,
    [PopupCheckPoint.WEEK_TASK_STAGE4_MAIN]      = 1,
    [PopupCheckPoint.WEEK_TASK_STAGE3_POP]       = -1,
    [PopupCheckPoint.WIN_REPEAT_RANK_STAGE3_POP] = -1,
    [PopupCheckPoint.WIN_REPEAT_RANK_STAGE4_POP] = -1,
    [PopupCheckPoint.GLADIATOR_STAGE4_POP]       = -1,
    [PopupCheckPoint.FISHING_WINNER_STAGE4_POP]  = -1,
    [PopupCheckPoint.FISHING_WINNER_MAIN_STAGE4] = 1,
    [PopupCheckPoint.MERGE_STAGE4_MAIN]          = -1,
    [PopupCheckPoint.MERGE_MAIN_STAGE2]          = 1,
    [PopupCheckPoint.MERGE_DAILY_REWARD]         = -1,
    [PopupCheckPoint.MERGE_STAGE4_SECONDARY]     = -1,
    [PopupCheckPoint.MERGE_EVOLUTION_STAGE4_POP] = -1,
    [PopupCheckPoint.MAGIC_RUSH_STAGE4_POP] = -1, -- 场景4强弹不限制次数；R1 分组每日1次由 MagicRush 的 check 自控
    -- 实验场景2按自然日最多弹出1次；使用独立 checkPoint，不消耗原场景4 PHONE_BIND 的终身一次标记。
	-- 调整数值会直接改变0～30关实验用户的每日触达频率。
	[PopupCheckPoint.DY_PHONE_BIND_STAGE2] = 1,
}

-- 每日每个大组的弹出限制
AutoPopupLimit.DailyPopTypeLimit = {
}

-- 限定只能在场景2强弹的类型
AutoPopupLimit.OnlyStage2Limit = {
	-- 防止该实验检测点被其他场景误加入队列；31～1998关实验用户仍由原 PHONE_BIND 场景4处理。
	PopupCheckPoint.DY_PHONE_BIND_STAGE2,
    PopupCheckPoint.ACT_MAIN_PANEL_STAGE_2,
	PopupCheckPoint.ELIMINATE_FESTIVAL_2026_COMIC_STAGE2,
	PopupCheckPoint.DAILY_LEVEL_STAGE2,
	PopupCheckPoint.MERGE_POP_MAIN_STAGE_2,
    PopupCheckPoint.PET_MAIN_POP_STAGE_2,
	PopupCheckPoint.SUB_MSG,
	PopupCheckPoint.ADD_MINE,
    PopupCheckPoint.RECALL_2025_STAGE2,
    PopupCheckPoint.EFFECT_MATCH_CHECK_STAGE_2,
    PopupCheckPoint.SPRINT_GIFT_CHECK_STAGE_2,
	PopupCheckPoint.COLLECT_CARD_FLOW_POP_STAGE2, -- 集卡补开流程强弹2
}

-- 限定只能在场景4强弹的类型
AutoPopupLimit.OnlyStage4Limit = {
    PopupCheckPoint.SUPER_MAGIC_BIRD_REVIVE_CONFIRM,
    PopupCheckPoint.FULL_STAR_LEVEL_LIB,
    PopupCheckPoint.ELIMINATE_FESTIVAL_2026_COMIC_STAGE4,
    PopupCheckPoint.ACT_MAIN_PANEL_STAGE_4,
    PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_4_1,
	PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_4_2,
	PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_4_3,
	PopupCheckPoint.SUB_MSG_STAGE4,
	PopupCheckPoint.ADD_MINE_STAGE4,
    PopupCheckPoint.PROMOTE_DAILY,
    PopupCheckPoint.PROMOTION_2025,
    PopupCheckPoint.LUCKY_ENERGY_BOTTLE,
    PopupCheckPoint.EXPLORE_MAP_GAME_DAILY_POP,
    PopupCheckPoint.EXPLORE_MAP_GAME_YINLIU_STAGE4_POP,
    PopupCheckPoint.EXPLORE_MAP_GAME_DAILY_GIFT_POP,
    PopupCheckPoint.COLLECT_CARD_FLOW_POP_STAGE4, -- 集卡补开流程强弹4
    PopupCheckPoint.HAPPY_DELIVERY_TIP_STAGE4,
    PopupCheckPoint.PROMOTION_CARD_PACK_POP_STAGE4, -- 晋级赛得卡包开包强弹4
    PopupCheckPoint.COLLECT_CARD_PROGRESS_TIP, --集卡进度提示气泡强弹
    PopupCheckPoint.BATTLE_PASS_UNBUY_COMPLETE,
    PopupCheckPoint.HAPPY_MATCH_YINLIU_STAGE4,
    PopupCheckPoint.DAILY_LEVEL_STAGE4, -- 每日夺宝场景4
    PopupCheckPoint.DY_FEED_SUBSCRIBE_GUIDE, -- 抖音推荐流订阅引导每日场景4一次
}

-- 一些可能已加入队列的强弹，在状态机重置时，已确定失去时效性，就配置在这里
AutoPopupLimit.ClearWhenFsmReset = {
	PopupCheckPoint.EXIT_LEVEL_JUMP,
    PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_3_1,
	PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_3_2,
	PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_3_3,
	PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_4_1,
	PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_4_2,
	PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_4_3,
}

-- 一些可能已加入队列的强弹，在场景3开始面板弹出后，已确定失去时效性，就配置在这里
AutoPopupLimit.ClearAfterStartGamePanelShow = {
	PopupCheckPoint.EXIT_LEVEL_JUMP,
    PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_3_1,
	PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_3_2,
	PopupCheckPoint.ACT_CUSTOMIZED_PANEL_STAGE_3_3,
}

AutoPopupLimit.StagePopupNum = {
	[AutoPopupConst.PopStage.STAGE_TWO] = 4,
	[AutoPopupConst.PopStage.STAGE_FOUR] = 1,
}

-- 场景2强弹间隔时间限制
AutoPopupLimit.Stage2PopupInterval = 300

return AutoPopupLimit
