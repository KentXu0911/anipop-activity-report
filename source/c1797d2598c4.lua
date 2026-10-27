local Const = {}

Const.actOpenVersion = 1            -- 活动开启周期，如果需要本地数据变更，或者升版本清数据啥的用
Const.actId = 6073                  -- 活动actId，朴实无华 
Const.actChName = "假日乐消消"            -- 活动中文名
Const.actSource = "sh01/Config.lua"  -- 活动路径

Const.dcFeature = "promotion_sh" -- 打点用

Const.infoPrefix = "userInfo.info"       -- 数据keyChain前缀，可以没有，说明你直接存在data里，没再加个表
Const.configPrefix = "localConfig"  -- 配置keyChain前缀，同上
Const.timePrefix = "userInfo"

Const.downloadLabels = {
}

return Const