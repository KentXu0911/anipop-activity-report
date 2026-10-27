local Const = {}
Const.PACKAGE_MODULE_VERSION = 1     -- 礼包版本
Const.actOpenVersion = 1
Const.actId = 3080
Const.actChName = "妙音合合"
Const.actSource = "musicmerge/Config.lua"

Const.gameName = "small_merge"            -- 打点用
Const.dcFeature = "small_merge"            -- 打点用

Const.downloadLabels = {
    "mergeevolution_pub",
    "mergeevolution_autopop",
}

Const.needLoadFiles = {
    "amf/activity/mergeevolution/material/collection.png",
}

Const.infoPrefix = "userInfo"
Const.configPrefix = "localConfig"
Const.timePrefix = "timeInfo"

Const.MapStatus = {
    LOCK = 1,           -- 进行中，包括未解锁和解锁未领奖
    FINISHED = 2,       -- 已领地图奖励
    MOSAIC = 3,         -- 已镶嵌宝石
}

Const.haptics = {

}

Const.ActProps = {
    COLLECTION = 52942,
    SCORE_BUFF_20 = 52943,
    SCORE_BUFF_50 = 52944,
}

Const.SkinMap = {
    SPRING_2026_03 = 1
}

function Const:getSkinId(key)
    return self.SkinMap[string.upper(key)] or 0
end

Const.TipText = {
    [1] = "活动开启，来参与吧！",
    [2] = "有奖励可以领取！",
    [3] = "体力充足，来合成吧！",
}

Const.DRAINAGE_ENERGY = 50
Const.DRAINAGE_POP_MAX = 2

return Const