return {
  ubfItemStaticConfig = {
    {
      itemType = 'ExploreMapGame',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_8075',
    version = 2,
    __treeId = '3159',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '186',
        displayPriority = 10000,
        appearInContent = {
          2,
          5,
          9,
        },
        touchTipText = '在【秋日拾忆】活动中使用',
        iconTopLabelTypes = {
          1,
          10,
        },
      },
    },
    usePropRewardConfig = {},
    usePropRewardTimesIsShared = true,
  },
  collectBarConfig = {
    {
      iconID = '186',
      canClick = true,
      index = -1,
      isNeedCustom = true,
      emphasize = true,
      alwaysShow = true,
      isStable = false,
    },
  },
  actItemConfig = {
    {
      iconConfig = {
        {
          rawData = {
            plist = 'tempFunctionResInLevel/ExploreMapGame/InLevel.plist',
            frameName = 'ExploreMapGame/collect186',
            type = 'image',
          },
          scene = 'default',
        },
      },
      additionTypes = {
        {
          type = 2,
          value = 2,
          group = 'LevelBaseRateGroup',
        },
      },
      baseDropRule = {
        collectionBaseCountConfig = {
          {
            recallUserDrop = 0,
            refreshStarDrop = '8',
            topDrop = '8',
            calcRecallUser = false,
            fsllLevelDrop = '20',
            startLevel = '211',
            endLevel = '4000',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '10',
            topDrop = '10',
            calcRecallUser = false,
            fsllLevelDrop = '20',
            startLevel = '4001',
            endLevel = 'top-90',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '15',
            topDrop = '15',
            calcRecallUser = false,
            fsllLevelDrop = '20',
            startLevel = 'top-89',
            endLevel = 'top',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '8',
            calcRecallUser = false,
            fsllLevelDrop = '20',
            startLevel = '1',
            endLevel = '210',
          },
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '186',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  casVersion = '31b46cd884c9fbd8426a66f1c372130b',
  modifyVersion = 6,
  supportedLevelScenes = {
    'MAIN',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 246,
  version = 9,
  baseConfig = {
    ActivityCHName = '秋日拾忆',
    ActivityName = 'ExploreMapGame',
    isUseBTreeLogicRule = false,
    collectionIds = {
      '186',
    },
    isOpenExceedHightestStarMode = true,
    actMainManager = 'ExploreMapGameManager',
    unifiedAct = true,
    isOpenRefreshScoreStrictMode = false,
    featureId = '8075',
    mainMgrName = 'ExploreMapGameActManager',
  },
}