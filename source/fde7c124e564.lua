return {
  ubfItemStaticConfig = {
    {
      itemType = 'TeamBuilding',
      actLogicName = 'TeamBuildingEventLogic',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_5318',
    version = 3,
    __treeId = '1790',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '168',
        displayPriority = 10000,
        appearInContent = {
          5,
          9,
          2,
        },
        touchTipText = '用于【露营吧！朋友】活动领奖',
        iconTopLabelTypes = {
          1,
          4,
          9,
        },
      },
    },
    usePropRewardConfig = {},
    usePropRewardTimesIsShared = true,
  },
  releaseVersion = 0,
  actItemConfig = {
    {
      iconConfig = {
        {
          rawData = {
            plist = 'tempFunctionResInLevel/TeamBuilding/inLevel.plist',
            frameName = 'TeamBuilding/inLevel/collection',
            type = 'image',
          },
          scene = 'default',
        },
      },
      additionTypes = {
        {
          type = 7,
          value = 2,
          group = 'DiffcultRateGroup',
        },
        {
          type = 8,
          value = 5,
          group = 'DiffcultRateGroup',
        },
        {
          type = 12,
          value = 1,
          group = 'RefreshStarRateGroup',
        },
        {
          type = 14,
          value = 2,
          group = 'RefreshStarRateGroup',
        },
        {
          type = 2,
          value = 10,
          group = 'LevelBaseRateGroup',
        },
        {
          type = 15,
          value = 1,
          group = 'RefreshScoreRateGroup',
        },
      },
      baseDropRule = {
        collectionBaseCountConfig = {
          {
            recallUserDrop = 0,
            refreshStarDrop = '10',
            topDrop = '10',
            refreshScoreDrop = '10',
            calcRecallUser = false,
            fsllLevelDrop = '10',
            startLevel = '1',
            endLevel = 'top',
          },
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '168',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  collectBarConfig = {
    {
      iconID = '168',
      canClick = true,
      index = -51,
      isNeedCustom = true,
      emphasize = true,
      alwaysShow = true,
      isStable = false,
    },
  },
  casVersion = 'dbc281ad82bb46e10e3fb4eee01407f8',
  modifyVersion = 35,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 226,
  version = 8,
  baseConfig = {
    ActivityCHName = '露营吧！朋友',
    ActivityName = 'TeamBuilding',
    collectionIds = {
      '168',
    },
    isOpenExceedHightestStarMode = false,
    actMainManager = 'TeamCampingManager',
    isOpenRefreshScoreStrictMode = true,
    featureId = '5321',
    mainMgrName = 'TeamBuildingUBFManager',
  },
}
