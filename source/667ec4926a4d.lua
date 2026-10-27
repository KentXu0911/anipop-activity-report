return {
  ubfItemStaticConfig = {
    {
      itemType = 'WeeklyRace2020',
      actLogicName = 'WeeklyRace2020ActEventLogic',
      isActCore = true,
      priority = 0,
      itemContextName = 'WeeklyRace2020ActContext',
    },
    {
      itemType = 'WeeklyRace2020Chest',
      isActCore = false,
      priority = 0,
      staticConfigPath = 'staticConfigs.WeeklyRace2020Chest',
      itemContextName = 'contexts.UBFItemWeeklyRace2020ChestContext',
      tilePath = 'views.tiles.UBFTileWeeklyRace2020Chest',
    },
    {
      itemType = 'Venom',
      isActCore = false,
      priority = 0,
      isSkin = true,
      res = {
        'WeeklyRace2020Venom'
      },
      tilePath = 'views.tiles.UBFTileWeeklyRace2020Venom',
    },
    {
      itemType = 'DigCloud',
      isActCore = false,
      priority = 0,
      isSkin = true,
      res = {
        'WeeklyRace2020DigCloud'
      },
      tilePath = 'views.tiles.UBFTileWeeklyRace2020DigCloud',
    },
    {
      itemType = 'GemCloud',
      isActCore = false,
      priority = 0,
      isSkin = true,
      res = {
        'WeeklyRace2020GemCloud'
      },
      tilePath = 'views.tiles.UBFTileWeeklyRace2020GemCloud',
    },

  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_8015_ubf',
    trigger = {
      'checkBaseCondition',
    },
    version = 2,
    __treeId = '883',
  },
  releaseVersion = 0,
  modifyVersion = 3,
  constraintVer = 196,
  version = 3,
  baseConfig = {
    needFuuuTargetProgressData = false,
    ActivityCHName = '萌宠周赛',
    ActivityName = 'WeeklyRace2020',
    actMainManager = 'WeeklyRace2020Mgr',
    isOpenRefreshScoreStrictMode = true,
    featureId = '8015',
    mainMgrName = 'WeeklyRace2020ActManager',
  },
}