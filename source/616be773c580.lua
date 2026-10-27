return {
  ubfItemStaticConfig = {
    {
      itemType = 'FullStarLevelLibrary',
      isActCore = true,
      priority = 0,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_5312_ubf',
    trigger = {
      'checkBaseCondition',
    },
    version = 5,
    __treeId = '858',
  },
  releaseVersion = 0,
  modifyVersion = 14,
  supportedLevelScenes = {
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 192,
  version = 3,
  baseConfig = {
    needFuuuTargetProgressData = false,
    ActivityCHName = '满星关卡库',
    ActivityName = 'FullStarLevelLibrary',
    actMainManager = 'FullStarLevelLibManager',
    isOpenRefreshScoreStrictMode = false,
    featureId = '5312',
    mainMgrName = 'FullStarLevelLibActManager',
  },
}