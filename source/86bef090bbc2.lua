local EnergyFundConst = {}

EnergyFundConst.actId = 8072

EnergyFundConst.maxEnergyItemId = 58096 -- 最大体力值key

EnergyFundConst.infoPrefix = "userInfo" -- 数据keyChain前缀，可以没有，说明你直接存在data里，没再加个表
EnergyFundConst.configPrefix = "localConfig" -- 配置keyChain前缀，同上
EnergyFundConst.timePrefix = "userInfo"

EnergyFundConst.taskType = {
    kLogin = 1,
    kBeginTry = 2, 
    kComplete = 3,
}

EnergyFundConst.showTipType = {
    kShowTipType_Get = 0,
    kShowTipType_Energy = 1,
    kShowTipType_NotFull = 2,
    kShowTipType_Full = 3,
    kShowTipType_Random = 4
}

EnergyFundConst.startLevelType = {
    TopLevel =1,----闯最高关
    LevelLib =2,---关卡库
    UnfinishedStarLevel = 3,-----去补星
}

EnergyFundConst.popGetMuchEnergyTimesOneDay = "popGetMuchEnergyTimesOneDay"

EnergyFundConst.popGetMuchEnergyAllTimes = "popGetMuchEnergyAllTimes"

return EnergyFundConst
