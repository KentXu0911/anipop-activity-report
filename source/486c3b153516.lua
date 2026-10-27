local LuckyDeliveryPassConst = {}

LuckyDeliveryPassConst.ACT_ID = 9503
LuckyDeliveryPassConst.ACT_NAME = "幸运快递通行证"
LuckyDeliveryPassConst.GAME_NAME = "lucky_delivery_pass"

LuckyDeliveryPassConst.configPrefix = "localConfig"
LuckyDeliveryPassConst.infoPrefix = "userInfo"
LuckyDeliveryPassConst.timePrefix = "activityTime"

LuckyDeliveryPassConst.RewardStatus = {
    LOCKED = 0,
    DOING = 1,
    CAN_RECEIVE = 2,
    RECEIVED = 3,
}

LuckyDeliveryPassConst.DCKey = {
    QUALIFY_DAILY = "qualify_daily",
    JOIN_DAILY = "join_daily",
}

LuckyDeliveryPassConst.CompensateKey = {
    HAS_VIP_DAILY = "lucky_delivery_pass_compensate_daily_has_vip",
    NO_VIP_DAILY = "lucky_delivery_pass_compensate_daily_no_vip",
}

return LuckyDeliveryPassConst
