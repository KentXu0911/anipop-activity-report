return {
  ubfItemStaticConfig = {
    {
      itemType = 'AddFiveStepUpgrade',
      isActCore = true,
      priority = 0,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_5311',
    trigger = {
      'checkBaseCondition',
      'finishBeforeStartLevel',
    },
    version = 2,
    __treeId = '1897',
  },
  releaseVersion = 0,
  modifyVersion = 48,
  constraintVer = 198,
  version = 3,
  baseConfig = {
    needFuuuTargetProgressData = true,
    ActivityCHName = '长尾步数升级',
    customInLevelManager = '',
    ActivityName = 'AddFiveStepUpgrade',
    actMainManager = 'UBFAddFiveStepUpgradeUtil',
    isOpenRefreshScoreStrictMode = false,
    featureId = '5311',
    mainMgrName = 'AddFiveStepUpgradeUBFManager',
  },
}