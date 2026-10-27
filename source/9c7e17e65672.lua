return {
  ubfItemStaticConfig = {
    {
      itemType = 'SprintGiftPackage',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_8074',
    trigger = {
      'checkBaseCondition',
      'finishBeforeStartLevel',
    },
    version = 6,
    __treeId = '3073',
  },
  releaseVersion = 0,
  casVersion = '530451e88592d7f133f20db910bd6f09',
  modifyVersion = 51,
  constraintVer = 245,
  version = 6,
  baseConfig = {
    needFuuuTargetProgressData = true,
    ActivityCHName = '冲关回馈礼包',
    customInLevelManager = '',
    ActivityName = 'SprintGiftPackage',
    actMainManager = 'SprintGiftPackageManager',
    isOpenRefreshScoreStrictMode = false,
    featureId = '8074',
    mainMgrName = 'SprintGiftPackageUBFManager',
    unifiedAct = false,
    isOpenExceedHightestStarMode = false,
    isUseBTreeLogicRule = false,
  },
  supportedLevelScenes = {
    'MAIN',
    'RANDOM_CHALLENGE_2023',
  },
}