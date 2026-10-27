local LuckyDeliveryConst = {}

LuckyDeliveryConst.ACT_ID = 4104
LuckyDeliveryConst.ACT_NAME = "幸运快递"
LuckyDeliveryConst.GAME_NAME = "lucky_delivery"

LuckyDeliveryConst.configPrefix = "localConfig"
LuckyDeliveryConst.infoPrefix = "userInfo"
LuckyDeliveryConst.timePrefix = "activityTime"

LuckyDeliveryConst.TipKey = {
    DAILY_EXPOSE = "daily_tip_exposed",
    INIT_ANIM_PLAYED = "daily_init_anim_played",
}

LuckyDeliveryConst.PushKey = {
    DAILY_PUSH_SCHEDULED = "push_daily_scheduled",
}

LuckyDeliveryConst.DCKey = {
    QUALIFY_DAILY = "qualify_daily",
    JOIN_DAILY = "join_daily",
}

LuckyDeliveryConst.BoxTier = {
    LEVEL_1 = "level_1",
    LEVEL_2 = "level_2",
    LEVEL_3 = "level_3",
}

LuckyDeliveryConst.TaskType = {
    PASS_LEVEL = "pass_level",
    FILL_STAR = "fill_star",
    RANDOM_CHALLENGE = "random_challenge",
}

LuckyDeliveryConst.SoundPath = "amf/activity/luckydelivery/sound/"

LuckyDeliveryConst.Sound = {
    COMMON_CLICK = "common_click.mp3",
    GO_IN = "goin.mp3",
    UPGRADE1 = "upgrade1.mp3",
    UPGRADE2 = "upgrade2.mp3",
    UPGRADE3 = "upgrade3.mp3",
    UPGRADE4 = "upgrade3.mp3",
    BOX_DOWN = "boxdown.mp3",
    OPEN1 = "open1.mp3",
    OPEN2 = "open2.mp3",
    IDLE = "idle.mp3",
}

LuckyDeliveryConst.Haptics = {
    COMMON_CLICK = require "amf.feature.localactivity.luckydelivery.haptics.CommonClick",
    GO_IN = require "amf.feature.localactivity.happydelivery.haptics.GoIn",
    UPGRADE1 = require "amf.feature.localactivity.happydelivery.haptics.Upgrade1",
    UPGRADE2 = require "amf.feature.localactivity.happydelivery.haptics.Upgrade2",
    UPGRADE3 = require "amf.feature.localactivity.happydelivery.haptics.Upgrade3",
    UPGRADE4 = require "amf.feature.localactivity.luckydelivery.haptics.Upgrade4",
    BOX_DOWN = require "amf.feature.localactivity.happydelivery.haptics.BoxDown",
    OPEN = require "amf.feature.localactivity.happydelivery.haptics.Open",
}

return LuckyDeliveryConst
