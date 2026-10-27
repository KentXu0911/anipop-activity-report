return {
  ubfItemStaticConfig = {
    {
      itemType = 'GamePlayStatistic',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = true,
  releaseVersion = 0,
  modifyVersion = 3,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 212,
  baseConfig = {
    ActivityCHName = '游戏统计打点',
    ActivityName = 'GamePlayStatistic',
    isUseBTreeLogicRule = false,
    isOpenExceedHightestStarMode = false,
    isOpenRefreshScoreStrictMode = true,
    featureId = '10178',
    mainMgrName = 'GamePlayStatisticActManager',
  },
}