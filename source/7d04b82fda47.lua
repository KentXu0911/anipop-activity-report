local ClimbTowerConst = {}

ClimbTowerConst.actId = 5073
ClimbTowerConst.clientVersionControl = 0
ClimbTowerConst.actChName = "冲顶夺宝"
ClimbTowerConst.gameName = "climb_tower"

ClimbTowerConst.TicketItemId = 55081
ClimbTowerConst.GrandLayerId = 6

ClimbTowerConst.Sound = {
    TICKET_COLLECT = "ticket_collect.mp3",
}

ClimbTowerConst.infoPrefix = "userInfo"
ClimbTowerConst.configPrefix = "localConfig"
ClimbTowerConst.timePrefix = "activityTime"

ClimbTowerConst.TipKey = {
    JOIN       = "tip_join",        -- 参与 tip
    NEXT_LAYER = "tip_next_layer",  -- 冲下层 tip
    GRAND_PUSH = "tip_grand_push",  -- 冲大奖 tip
}

ClimbTowerConst.TipDailyLimit = {
    [ClimbTowerConst.TipKey.JOIN]       = 1,
    [ClimbTowerConst.TipKey.NEXT_LAYER] = 2,
    [ClimbTowerConst.TipKey.GRAND_PUSH] = 2,
}

ClimbTowerConst.TipDesc = {
    [ClimbTowerConst.TipKey.JOIN]       = "向上冲赢免费大奖！",
    [ClimbTowerConst.TipKey.NEXT_LAYER] = "下抽必升一层！",
    [ClimbTowerConst.TipKey.GRAND_PUSH] = "终极大奖，就差一步！",
}

ClimbTowerConst.DrawButtonState = {
    NORMAL    = 1,  -- 【奖券.jpg n 抽一次】可点
    DRAWING   = 2,  -- 【抽取中】置灰
    GO_STORE  = 3,  -- 【前往商店】（券不足）
    ENDED     = 4,  -- 【已结束】（第5层升级抽完）
}

ClimbTowerConst.DCKey = {
    QUALIFY_DAILY = "dc_qualify_daily",
    JOIN_DAILY    = "dc_join_daily",
}

ClimbTowerConst.GuideIndex = {
    MAIN_PANEL_FIRST_ENTER = 1,  -- 活动主面板首次入场动画
    INFO_PANEL_FIRST_SHOW  = 2,  -- 活动说明首次弹出
    STORE_GUIDE_1_IN_MAIN  = 3,  -- 商店引导1（活动主面板，免费券用完）
    STORE_GUIDE_2_IN_STORE = 4,  -- 商店引导2（商店面板内）
    PURCHASE_OFFER_SHOWN   = 5,  -- ON2 大奖直购机会展示已弹过（一期一次，避免重复打扰）
}

-- 本地推送（仅 App，小游戏不推）
-- 推送 1：当前层仅剩升级奖励且非第 5 层    → 每日 20:00 × 1
-- 推送 2：当前层为第 5 层（解锁大奖未领）  → 每日 10:00 + 20:00 各 × 1
ClimbTowerConst.PushType = {
    NEXT_LAYER = "next_layer",   -- 推送 1
    GRAND      = "grand",        -- 推送 2
}

ClimbTowerConst.PushText = {
    [ClimbTowerConst.PushType.NEXT_LAYER] = {
        title   = "冲顶夺宝，抽奖你最行！",
        message = "下抽必升一层！后面奖励更精彩！",
    },
    [ClimbTowerConst.PushType.GRAND] = {
        title   = "来领免费大奖啦！",
        message = "就差一步，超级大奖免费拿！",
    },
}

-- 推送时间点（小时偏移；UTC+8 当日 0 点起算）
ClimbTowerConst.PushHourOffsets = {
    [ClimbTowerConst.PushType.NEXT_LAYER] = { 20 },       -- 仅 20:00
    [ClimbTowerConst.PushType.GRAND]      = { 10, 20 },   -- 10:00 + 20:00
}

return ClimbTowerConst
