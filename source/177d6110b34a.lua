return {
  ubfItemStaticConfig = {
    {
      itemType = 'WinComboAddFiveUpgrade',
      isActCore = true,
      priority = 0,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_5315',
    trigger = {
      'checkBaseCondition',
      'finishBeforeStartLevel',
    },
    version = 2,
    __treeId = '919',
  },
  releaseVersion = 0,
  modifyVersion = 48,
  constraintVer = 198,
  version = 3,
  baseConfig = {
    needFuuuTargetProgressData = true,
    ActivityCHName = '连胜步数升级',
    customInLevelManager = '',
    ActivityName = 'WinComboAddFiveUpgrade',
    actMainManager = 'WinComboAddFiveUpgradeUtil',
    isOpenRefreshScoreStrictMode = false,
    featureId = '5315',
    mainMgrName = 'WinComboAddFiveUpgradeUBFManager',
  },
}