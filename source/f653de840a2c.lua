return {
  ubfItemStaticConfig = {
    {
      itemType = 'CallbackPreAddStep',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_9502',
    trigger = {
      'checkBaseCondition',
      'finishBeforeStartLevel',
    },
    version = 2,
    __treeId = '3136',
  },
  releaseVersion = 0,
  casVersion = '2644791ce47ecaa27f5780b50552d102',
  modifyVersion = 36,
  supportedLevelScenes = {
    'MAIN',
    'HIDE',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 245,
  version = 3,
  baseConfig = {
    needFuuuTargetProgressData = true,
    ActivityCHName = '回流加步buff',
    customInLevelManager = '',
    ActivityName = 'CallbackPreAddStep',
    isUseBTreeLogicRule = false,
    actMainManager = 'CallbackPreAddStepLiteManager',
    isOpenExceedHightestStarMode = false,
    unifiedAct = false,
    isOpenRefreshScoreStrictMode = false,
    featureId = '9502',
    mainMgrName = 'CallbackPreAddStepActManager',
  },
}