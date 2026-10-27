local Const = {}

Const.actId = 8080
-- 玩家可见的活动名：跨期 tips（onActPassMainBegin/MainEnd/ActEnd）和分享框架错误提示
-- （error.tip.736432/736433 的 actName 参数）都取这里，必须和 Config 的 DISPLAY_NAME 一致。
-- 目录/资源标识不是这个，用下面的 gameName。
Const.actName = "鸟卡接力"
-- 本活动的分享类型。框架的"分享进入游戏"打点直接取 query.shareType：
--   app 端 help_frame/game_into 的 t3、小游戏 vx_help/enter_game 的 t4；
-- 所以必须是活动自己的标识，不能沿用通用的 help_activity。
Const.shareType = "bird_share"
Const.gameName = "superbirdshare"
Const.dcFeature = "superbirdshare"
Const.dcSource = "act_8080"

Const.infoPrefix = "userInfo"
Const.configPrefix = "localConfig"
Const.timePrefix = "activityTime"

Const.downloadLabels = {
    -- TODO: 按活动资源配置填写下载标签
    "superbirdshare",
}

Const.needLoadFiles = {
    -- TODO: 仅在必须预加载具体文件时填写。
}

Const.eventPrefix = "onAct"

-- TODO: 按真实业务定义本地缓存 key，示例 key 可按需删除
Const.LocalCacheKey = {
    GuidePrefix = "Guide_",
    TodayFirstOpen = "TodayFirstOpen",
    MainPanelOpened = "MainPanelOpened",
    -- 奖励强弹场景2的每日标记：needTime=true 按自然日失效，跨天自动重置
    RewardMainPanelPoppedToday = "RewardMainPanelPoppedToday",
    -- canyu/qualify、canyu/join 的每日去重标记：needTime=true 按自然日失效，跨天自动重置
    dc_has_qualify = "dc_has_qualify",
    dc_has_join = "dc_has_join",
}

Const.Guide = {
    -- TODO: 按真实引导配置填写，例如 MainPanel = 1。
}

Const.DC = {
    -- TODO: 按真实打点填写 sub_category，例如 OpenPanel = "open_panel"。
}

return Const
