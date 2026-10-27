local Const = {}

Const.actOpenVersion = 1
Const.actId = 6076
Const.actChName = "方块消消"
Const.actSource = "block/Config.lua"

Const.gameName = "11111"            -- 打点用
Const.dcFeature = "block_remove"            -- 打点用
Const.dcSource = "1111"             -- 打点用

Const.autoDownload = false
Const.downloadFiles = {}            -- 需要下载的文件 可选
Const.downloadLabels = {}           -- 需要下载的label 可选
Const.autoDownloadTimes = 1         -- 自动下载次数(失败后重试) 可选

Const.configPrefix = "localConfig"
Const.infoPrefix = "userInfo"
Const.timePrefix = "timeInfo"
Const.maxNormalMapId = 8
Const.ACT_INTRO_KEY = "block_intro"

Const.ActProps = {
    kScoreBuff20 = 59531,
    kScoreBuff50 = 59532,
}

Const.haptics = {
    CLEAR_LIGHT = "ClearLight",
    CLEAR_MID = "ClearMid",
    CLEAR_HEAVY = "ClearHeavy",
    BLOCK_PLACE = "BlockPlace",
}

Const.BoardType = {
    [1] = 6,
    [2] = 7,
    [3] = 8,
}
--收集物CollectionId
Const.mainLevelCollectionId = 176

return Const