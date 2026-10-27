local Const = {}

Const.actId = 4106
Const.actName = "SuperMagicBirdRealGift"
Const.gameName = "supermagicbirdrealgift"
Const.dcFeature = "supermagicbirdrealgift"
Const.dcSource = "act_4106"
Const.infoPrefix = "userInfo"
Const.configPrefix = "localConfig"
Const.timePrefix = "activityTime"

Const.downloadLabels = {
    "supermagicbirdrealgift",
}

Const.needLoadFiles = {
    "amf/activity/supermagicbirdrealgift/materials/ticket.png",
}

Const.eventPrefix = "onAct"
Const.baseSuperBirdManagerName = "SuperMagicBird2024Manager"

Const.ActivityPhase = {
    UNAVAILABLE = "unavailable",
    MAIN = "main",
    AWARD_ELIGIBLE = "award_eligible",
    ENDED = "ended",
}

Const.PanelMode = {
    MAIN = "main",
    AWARD = "award",
}

Const.MainInfoField = {
    PROGRESS = "progress",
    TARGET = "target",
    GOT_REAL_REWARD = "gotRealReward",
    ADDRESS_FILLED_TIME = "addressFilledTime",
    TASK_INFO = "taskInfo",
    LOTTERY_TICKET_COUNT = "lotteryTicketCount",
    CUTOFF_TIMES = "cutoffTimes",
    REWARD_POOL = "rewardPool",
    TASK_ROUND = "taskRound",
    REAL_REWARD_LEFT_COUNT = "realRewardLeftCount",
}

Const.mainInfoFields = {
    Const.MainInfoField.PROGRESS,
    Const.MainInfoField.TARGET,
    Const.MainInfoField.GOT_REAL_REWARD,
    Const.MainInfoField.ADDRESS_FILLED_TIME,
    Const.MainInfoField.TASK_INFO,
    Const.MainInfoField.LOTTERY_TICKET_COUNT,
    Const.MainInfoField.CUTOFF_TIMES,
    Const.MainInfoField.REWARD_POOL,
    Const.MainInfoField.TASK_ROUND,
    Const.MainInfoField.REAL_REWARD_LEFT_COUNT,
}

-- TODO: 按真实业务定义本地缓存 key，示例 key 可按需删除
Const.LocalCacheKey = {
    GuidePrefix = "Guide_",
    TodayFirstOpen = "TodayFirstOpen",
    Stage2AutoPop = "Stage2AutoPop",
    TaskProgress = "TaskProgress",
    ShownTipTaskRound = "shownTipTaskRound",
}

Const.Guide = {
    MAIN_PANEL = 1,
}

Const.DC = {
    -- TODO: 按真实打点填写 sub_category，例如 OpenPanel = "open_panel"。
}

return Const
