return {
  ubfItemStaticConfig = {
    {
      res = {
        'CallbackBoosterThrower',
      },
      itemType = 'CallbackBoosterMod',
      actLogicName = 'CallbackBoosterActEventLogic',
      isActCore = true,
      priority = 0,
      itemContextName = 'CallbackBoosterModContext',
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_9088',
    trigger = {
      'checkBaseCondition',
      'finishBeforeStartLevel',
    },
    version = 2,
    __treeId = '3083',
  },
  releaseVersion = 0,
  casVersion = 'f0ca89bf51d54226480525acd70a3bb3',
  modifyVersion = 31,
  constraintVer = 218,
  version = 4,
  baseConfig = {
    needFuuuTargetProgressData = true,
    ActivityCHName = '回流特效助力',
    customInLevelManager = '',
    ActivityName = 'CallbackBooster',
    actMainManager = 'CallbackBoosterLiteManager',
    featureId = '9088',
    mainMgrName = 'CallbackBoosterActManager',
    isOpenRefreshScoreStrictMode = true,
    isOpenExceedHightestStarMode = false,
  },
}