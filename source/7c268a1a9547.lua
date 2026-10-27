local Const = {}

Const.actId = 4101
Const.clientVersionControl = 0
Const.actChName = "开心快递"
Const.gameName = "happy_delivery"

Const.configPrefix = "localConfig"
Const.infoPrefix = "userInfo"
Const.timePrefix = "activityTime"

Const.TipKey = {
    DAILY_EXPOSE = "daily_tip_exposed",
    INIT_ANIM_PLAYED = "daily_init_anim_played",
}

Const.PushKey = {
    DAILY_PUSH_SCHEDULED = "push_daily_scheduled",
}

Const.DCKey = {
    HAS_QUALIFY = "dc_has_qualify",
    HAS_JOIN = "dc_has_join",
}

Const.BoxTier = {
    LEVEL_2 = "level_2",
    LEVEL_1 = "level_1",
}

Const.TaskType = {
    PASS_LEVEL = "pass_level",
    FILL_STAR = "fill_star",
    RANDOM_CHALLENGE = "random_challenge",
}

Const.Sound = {
    PROGRESS_FILL = "progress_fill.mp3",
    PROGRESS_UPDATE = "progress_update.mp3",
}

Const.Haptics = {
    STEP_FINISH = require "amf.feature.localactivity.happydelivery.haptics.StepFinish",
    SWITCH_PROGRESS = require "amf.feature.localactivity.happydelivery.haptics.SwitchProgress",
    GO_IN = require "amf.feature.localactivity.happydelivery.haptics.GoIn",
    UPGRADE1 = require "amf.feature.localactivity.happydelivery.haptics.Upgrade1",
    UPGRADE2 = require "amf.feature.localactivity.happydelivery.haptics.Upgrade2",
    UPGRADE3 = require "amf.feature.localactivity.happydelivery.haptics.Upgrade3",
    BOX_DOWN = require "amf.feature.localactivity.happydelivery.haptics.BoxDown",
    OPEN = require "amf.feature.localactivity.happydelivery.haptics.Open",
}

return Const
