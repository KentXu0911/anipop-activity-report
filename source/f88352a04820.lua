local Const = {}
Const.HealthItemId = -1

Const.GuideSetId = {
    
}

Const.actOpenVersion = 1            -- 活动开启周期，如果需要本地数据变更，或者升版本清数据啥的用
Const.actId = 22003                  -- 活动actId，朴实无华 
Const.actChName = "拾光成歌"            -- 活动中文名
Const.actSource = "underthesin/Config.lua"  -- 活动路径
Const.DAY_COUNT = 10                 -- 活动天数：本地 key 声明上界（UnderTheSinModel）与活动 Meta 共用这一处配置
Const.CLUE_COUNT = 7                 -- 每日线索数

Const.dcFeature = "activity" -- 打点用

Const.infoPrefix = "userInfo.info"       -- 数据keyChain前缀，可以没有，说明你直接存在data里，没再加个表
Const.configPrefix = "localConfig"  -- 配置keyChain前缀，同上
Const.timePrefix = "userInfo"

Const.downloadLabels = {
    "underthesin",
}
Const.autoDownload = false
Const.actColorType = _G.PanelColorConst.ColorType.kChiefMystery
Const.GAME_NAME = "village_head_sep"

Const.realItemResList = {

}

return Const
