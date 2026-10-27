local Config = {}

Config.actOpenVersion = 1 -- 活动本地存储版本；同一活动复用且本地结构不兼容时递增。
Config.actId = 8078 -- 活动 ID；与活动测 pengpeng2026/Config.lua 和 info.xml 保持一致。
Config.actChName = "飞碟弹弹乐" -- 活动展示名；当前活动测 info.xml 中 actNameCN 为 pengpeng。
Config.actSource = "pengpeng2026/Config.lua" -- 动态活动配置源路径；ActivityMgr 用它定位活动包配置。

Config.gameName = "pengpeng2026" -- 活动打点 game_name 字段。
Config.dcFeature = "pengpeng2026" -- 活动打点 feature/category 前缀；与活动测 dcFeature 对齐。

Config.autoDownload = false
Config.downloadLabels = {"pengpeng2026"}
Config.needLoadFiles = {
    "amf/activity/pengpeng2026/collection.png",
}

Config.collectId = 58184
Config.inLevelCollectionId = 191
Config.percent20Buff = 58185
Config.doubleBuff = 58186

-- 场景4引流弹窗配置；每日弹出次数由强弹框架统一控制。
Config.AttractPanel = {
    MIN_LAUNCH_OPPORTUNITY = 10, -- 当前持有收集物达到该数量时，场景4才允许弹引流面板。
    SUPPRESS_COUNT_KEY = "attractPanelSuppressCount", -- 主面板强弹后剩余过关抑制次数；needTime=true，每日重置。
    SUPPRESS_PASS_COUNT = 3, -- 主面板同轮强弹后，后续三次过关不再强弹引流面板。
    REWARD_SCORE_BUFF_20 = 58185, -- 固定奖励展示：20% 加分 buff 图标。
    REWARD_TIMELIMIT_BRUSH_24H = 10061, -- 固定奖励展示：24h 魔法棒图标。
    REWARD_INFINITE_ENERGY_ONE_HOUR = 10098, -- 固定奖励展示：无限精力图标。
}

Config.MainPanel = {
    MIN_LAUNCH_OPPORTUNITY = 20, -- 当前持有收集物达到该数量时，场景4才允许弹主面板。
}

Config.Sync = {
    maxBatchCount = 10, -- 本地操作累计到该数量后触发一次批量同步。
}

Config.RewardType = {
    NORMAL = 1, -- 普通进度奖励。
    ENDLESS = 2, -- 无尽奖励。
}

Config.OpType = {
    SHOOT = "shoot", -- 发射操作。
    MERGE = "merge", -- 合成操作。
    MAGNET = "magnet", -- 磁铁触发操作；具体合成仍按 merge 独立记录。
    BONUS = "bonus", -- 清屏雨 bonus 操作。
    ORDER = "order", -- 订单提交操作。
    CHECKPOINT = "checkpoint", -- 棋盘快照检查点操作。
}

Config.MagnetReason = {
    MANUAL = "manual", -- 手动使用磁铁，后端扣能量。
    FULL = "full", -- 满额自动触发，不扣能量。
}

Config.MergeReason = {
    COLLISION = "collision", -- 普通碰撞合成。
    MAGNET = "magnet", -- 磁铁强制合成。
}

Config.BonusType = {
    RAIN = "rain", -- 清屏雨。
}

Config.BonusReason = {
    BOARD_NEARLY_EMPTY = "boardNearlyEmpty", -- 棋盘棋子较少。
}

Config.ClearRain = {
    tryCount = 40, -- 每颗清屏雨棋子随机寻找空位的最大尝试次数；找不到位置时本颗减量。
    spacing = 6, -- 清屏雨新增棋子与现有棋子、本批新增棋子之间的额外安全间距。
    mergeProtectTime = 0.12, -- 清屏雨棋子生成后的短暂合成保护时间，避免落地立即触发连锁合成。
}

Config.CheckpointReason = {
    BOARD_STABLE = "boardStable", -- 棋盘稳定。
    PANEL_CLOSE = "panelClose", -- 关闭面板。
}

Config.Haptics = {
    SHOOT = "Shoot", -- 发射轻反馈。
    MERGE_LIGHT = "MergeLight", -- 普通合成反馈。
    MERGE_HEAVY = "MergeHeavy", -- 高等级合成或强反馈。
    ORDER_COMPLETE = "OrderComplete", -- 订单完成反馈。
}

Config.StaticItemIconInfo = {
    [Config.collectId] = {Frame = "amf/activity/pengpeng2026/collection.png", Atlas = "", IsPropPng = true},
    [Config.doubleBuff] = {Frame = "amf/activity/pengpeng2026/collection.png", Atlas = "", IsPropPng = true},
}

return Config
