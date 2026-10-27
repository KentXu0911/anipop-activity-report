local Const = {}
Const.score20BuffId = 55041


Const.actOpenVersion = 6            -- 活动开启周期，如果需要本地数据变更，或者升版本清数据啥的用
Const.actId = 5066                  -- 活动actId，朴实无华 
Const.actChName = "金币狂欢日"            -- 活动中文名
Const.actSource = "coinpromotions/Config.lua"  -- 活动路径

Const.dcFeature = "0" -- 打点用

Const.infoPrefix = "userInfo"       -- 数据keyChain前缀，可以没有，说明你直接存在data里，没再加个表
Const.configPrefix = "localConfig"  -- 配置keyChain前缀，同上
Const.timePrefix = "userInfo"

Const.downloadLabels = {
    -- "coinpromotions",
}
Const.actColorType = _G.PanelColorConst.ColorType.kCoinPromotions

return Const