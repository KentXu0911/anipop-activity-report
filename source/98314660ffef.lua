local StellarConvergenceConst = {}

StellarConvergenceConst.FeatureId = 6051
StellarConvergenceConst.actId = 6051

StellarConvergenceConst.ScoreBuffId = 57248

StellarConvergenceConst.infoPrefix = "userInfo"       -- 数据keyChain前缀，可以没有，说明你直接存在data里，没再加个表
StellarConvergenceConst.configPrefix = "localConfig"  -- 配置keyChain前缀，同上

StellarConvergenceConst.MAX_BOX_OPEN_NUM = 2
StellarConvergenceConst.AREA_LEVEL_NUM = 15
StellarConvergenceConst.ONE_SUBSECTION_AREA_NUM = 10
StellarConvergenceConst.NEBULA_SUBSECTION_NUM = 10

StellarConvergenceConst.StarState = {
    YELLOW = "yellow",
    COLOR = "color",
}

StellarConvergenceConst.StarTypes = {
    kDiamond = 1,
    kZi = 2,
    kCai = 3,
    kGold1= 4,
    kGold2 = 5,
    kGold3= 6,
    kNorml = 7,
}

StellarConvergenceConst.StarNames = {
    "闪耀星光",
    "紫芒星光",
    "炫彩星光",
    "黄金星光1",
    "黄金星光2",
    "黄金星光3",
    "新星光"
}

StellarConvergenceConst.StarIconNames = {
    "闪耀星",
    "紫星",
    "彩星",
    "黄星",
    "黄星",
    "黄星",
    "黄星"
}

StellarConvergenceConst.GoldNeedPercent = { 99, 95, 88}

StellarConvergenceConst.StarConditionNames = {
    "满级满黄满彩满紫可达成",
    "满级满黄满彩可达成",
    "满级满黄可达成",
    "满级后获得99%黄星可达成",
    "满级后获得95%黄星可达成",
    "满级后获得88%黄星可达成",
    "满级可达成"
}

StellarConvergenceConst.AnimalName = {
    "莱萌鸡",
    "嘟嘟",
    "爱逗蛙",
    "栗熊",
    "么么狐",
    "紫咪",
    "小浣熊",
    "猫猫",
    "北极熊",
}

StellarConvergenceConst.NebulaName = {
    "ji",
    "hema",
    "qingwa",
    "xiong",
    "mmhu",
    "maotouying",
    "xiaohuanxiong",
    "mao",
    "icebear",
}

StellarConvergenceConst.NebulaSpineFix = {
    5,
    8,
    2,
    1,
    7,
    3,
    6,
    4,
    9,
}

StellarConvergenceConst.NebulaConfig = {}
for i = 1, #StellarConvergenceConst.AnimalName do
    local config = require ("amf.feature.localactivity.stellarconvergence.config.nebulaconfig." .. StellarConvergenceConst.NebulaName[i])
    StellarConvergenceConst.NebulaConfig[i] = config
end

return StellarConvergenceConst