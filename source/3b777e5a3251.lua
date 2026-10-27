local Const = {}

Const.actId = 4105
Const.actName = "LayeredTileMatch"
Const.actChName = "开心农家乐"
Const.gameName = "layeredtilematch"
Const.moduleName = "happy_farmhouse"
Const.dcFeature = "happy_farm"
Const.dcSource = "act_4105"
Const.openLevel = 210

Const.infoPrefix = "userInfo"
Const.configPrefix = "localConfig"
Const.timePrefix = "activityTime"

Const.downloadLabels = {
    "layeredtilematch",
}

Const.ItemId = {
    CHALLENGE_TOKEN = 56024,
    HARVEST_VALUE = 56025,
    UNDO = 56026,
    SHUFFLE = 56027,
    REMOVE = 56028,
    COMPLETE = 56029,
}

Const.needLoadFiles = {
    "amf/activity/layeredtilematch/texture/LayeredTileMatchProp.plist",
}

Const.eventPrefix = "onAct"

Const.PackageGroup = {
    ENTRY_TICKET = "ENTRY_TICKET",
    ENTRY_TICKET_POP = "ENTRY_TICKET_POP",
    PASS = "PASS",
    UNDO_ITEM = "UNDO_ITEM",
    SHUFFLE_ITEM = "SHUFFLE_ITEM",
    REMOVE_ITEM = "REMOVE_ITEM",
    COMPLETE_ITEM = "COMPLETE_ITEM",
    ACTIVITY_ITEM_OFFER = "ACTIVITY_ITEM_OFFER",
    SPECIAL_OFFER = "SPECIAL_OFFER",
}

Const.Protocol = {
    -- TODO: 后端协议确定后只修改这里和对应 Request 的 pbProto。
    CLAIM_BATTLE_PASS_REWARD = "layeredTileMatchClaimBattlePassReward",
    CLAIM_PROGRESS_REWARD = "happyFarmhouseReward",
}

-- TODO: 按真实业务定义本地缓存 key，示例 key 可按需删除
Const.LocalCacheKey = {
    GuidePrefix = "Guide_",
    TodayFirstOpen = "TodayFirstOpen",
    TodayTokenShortageGiftShown = "TodayTokenShortageGiftShown",
    DCQualifyDaily = "DCQualifyDaily",
    DCJoinDaily = "DCJoinDaily",
}

Const.Guide = {
    FirstLevelOpening = {
        1,
        2,
    },
    SpecialCardCongratulation = 3,
}

Const.DC = {
    Category = {
        Participate = "canyu",
        Show = "show",
        Activity = "happy_farm",
        PaymentRmb = "payment_rmb",
        PaymentCoin = "payment_coin",
    },
    SubCategory = {
        Qualify = "qualify",
        Join = "join",
        MainPanel = "main_panel",
        MainPanelReward = "main_panel_reward",
        BattleStart = "battle_start",
        BattlePropUse = "battle_prop_use",
        BattleResult = "battle_result",
        BattleContinueClick = "battle_continue_click",
        StageRewardShow = "stage_reward_show",
        FeedbackShow = "feedback_show",
        FeedbackReward = "feedback_reward",
        PowerReplenishShow = "power_replenish_show",
        PowerReplenishClick = "power_replenish_click",
        RewardTimeReward = "rewardtime_reward",
        PayShow = "pay_show",
        PayClick = "pay_click",
        PayResult = "pay_result",
    },
    Source = {
        Feedback = "feedback",
        FlowGift = "flow_gift",
        PowerGift = "power_gift",
        PropGift = "prop_gift",
    },
}

Const.Sound = {
    CLICK_COMMON = "activity/layeredtilematch/res/audio/se_ui_click.mp3",
    STAGE_TRANSITION = "activity/layeredtilematch/res/audio/stage_transition.mp3",
    TILE_CLICK = "activity/layeredtilematch/res/audio/tile_click.mp3",
    TILE_FLY = "activity/layeredtilematch/res/audio/tile_fly.mp3",
    MATCH_SUCCESS = "activity/layeredtilematch/res/audio/match_success.mp3",
    COMBO_HIT = "activity/layeredtilematch/res/audio/combo_hit.mp3",
    HARVEST_ICON_APPEAR = "activity/layeredtilematch/res/audio/harvest_icon_appear.mp3",
    SCORE_FLY = "activity/layeredtilematch/res/audio/score_fly.mp3",
    PROGRESS_INCREASE = "activity/layeredtilematch/res/audio/progress_increase.mp3",
    GOLD_UNLOCK = "activity/layeredtilematch/res/audio/gold_unlock.mp3",
    BOOSTER_UNDO = "activity/layeredtilematch/res/audio/booster_undo.mp3",
    BOOSTER_REMOVE = "activity/layeredtilematch/res/audio/booster_remove.mp3",
    BOOSTER_SHUFFLE = "activity/layeredtilematch/res/audio/booster_shuffle.mp3",
    OPERATION_ERROR = "activity/layeredtilematch/res/audio/operation_error.mp3",
    WIN_RESULT = "activity/layeredtilematch/res/audio/win_result.mp3",
    WIN_FIREWORKS = "activity/layeredtilematch/res/audio/win_fireworks.mp3",
    LOSE_RESULT = "activity/layeredtilematch/res/audio/lose_result.mp3",
    FINAL_REWARD = "activity/layeredtilematch/res/audio/final_reward.mp3",
    REWARD_LOCKED = "activity/layeredtilematch/res/audio/reward_locked.mp3",
    BP_CLAIM = "activity/layeredtilematch/res/audio/bp_claim.mp3",
    VIP_UNLOCK = "activity/layeredtilematch/res/audio/vip_unlock.mp3",
}

Const.BGM = {
    MAIN = "activity/layeredtilematch/res/audio/bgm_main.mp3",
}

Const.Haptics = {
    NORMAL = "Normal",
}

return Const
