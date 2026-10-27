ActivityConst = {}

ActivityConst.ActState = {
    INVALID = 0,    --非法/初始状态
    WAITING = 1,    --未到活动开启时间
    RUNNING = 2,    --活动运行中
    EXPIRED = 3,    --活动已过期
}

ActivityConst.ConfigError = {
    OK = 0,
    DOWNLOAD_ERROR = 1,
    PARSE_ERROR = 2,
}

--活动状态
ActivityConst.ActivityPeriod = {
    BEFORE_BEGIN = 1,
    PREHEAT = 2,
    MAIN = 3,
    AWARD = 4,
    END = 5
}

ActivityConst.DownloadType = {
    --下全部
	COMPLETE = "complete",
	--下启动器(代码以及icon资源)  app端只下载Config.lua
    LAUNCHER = "launcher",
    ICON = "icon",
    CODE = "code",
}

--liteStart的状态
ActivityConst.LiteStartState = {
	IGNORE = "ignore",
	NOT_YET = "not_yet",
	HANDLING = "handling",
	DONE = "done",
}

-- 强弹类型
ActivityConst.PopType = {
    MAIN_PANEL = 1,
    CUSTOMIZE = 2,
}

ActivityConst.PopLimit = {
    MAIN_PANEL = 1,
    CUSTOMIZE_STAGE_3 = 3,
    CUSTOMIZE_STAGE_4 = 3,
}

ActivityConst.UnityUseActivityConfigLocal = false

if not EnvUtil:isDevelopMode() then
    ActivityConst.UnityUseActivityConfigLocal = false
end

-- 微信开发者工具固定读取 activity_config_local.lua；人工开关用于其它调试环境强制走同一本地配置。
-- 配置加载和版本选择必须共用该判定，避免本地配置误取 versionTJ* 等平台版本字段。
function ActivityConst.shouldUseLocalActivityConfig()
    return ActivityConst.UnityUseActivityConfigLocal or EnvUtil:isMiniGameDev()
end

ActivityConst.ActivityConfigName = EnvUtil:isMiniGame() and "activity_config_h5" or "activity_config2024"
