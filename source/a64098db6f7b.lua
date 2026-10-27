local DailyLevelConst = {}

DailyLevelConst.ACT_ID = 8077                   -- 活动id
DailyLevelConst.ACT_NAME = "每日夺宝"            -- 活动名
DailyLevelConst.DC_FEATURE = "daily_treasure"
DailyLevelConst.VERSION = 1                     -- 控制版本
DailyLevelConst.GOLD_TICKET_ID = 58181          -- 金奖券id
DailyLevelConst.NORMAL_TICKET_ID = 58182        -- 普通奖券id
DailyLevelConst.COLLECTION_ID = 58183           -- 收集物id
DailyLevelConst.MAIN_INFO_ACT_INVALID_ERROR_CODE = 739186 -- 活动失效错误码

DailyLevelConst.PackageBuyType = {
    TICKET = "TICKET",
    DOUBLE_COLLECT = "DOUBLE_COLLECT",
}

DailyLevelConst.BoxType = {
    NORMAL = 1,
    GRAND_REWARD = 2,
}

DailyLevelConst.GuideId = {
    STAGE2_MAIN_PANEL = 10001,
    WEEKEND_CARNIVAL = 10002,
    FIRST_ENTER_LEVEL = 10003,
    AWARD_TIME_BANNER = 10004,
}

return DailyLevelConst
