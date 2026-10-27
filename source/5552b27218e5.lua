return {
  ubfItemStaticConfig = {
    {
      itemType = 'BlockAct',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_6076',
    version = 3,
    __treeId = '2534',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '176',
        displayPriority = 10000,
        appearInContent = {
          5,
          9,
          2,
        },
        touchTipText = '在【方块消消】活动中使用',
        iconTopLabelTypes = {},
      },
    },
    usePropRewardConfig = {},
    usePropRewardTimesIsShared = true,
  },
  actItemConfig = {
    {
      iconConfig = {
        {
          rawData = {
            plist = 'tempFunctionResInLevel/BlockAct/InLevel.plist',
            frameName = 'BlockAct/collect',
            type = 'image',
          },
          scene = 'default',
        },
      },
      baseDropRule = {
        collectionBaseCountConfig = {
          {
            recallUserDrop = 0,
            refreshStarDrop = '2',
            calcRecallUser = false,
            fsllLevelDrop = '3',
            startLevel = '1',
            endLevel = '210',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '2',
            topDrop = '2',
            calcRecallUser = false,
            fsllLevelDrop = '3',
            startLevel = '211',
            endLevel = '4000',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '2',
            topDrop = '2',
            calcRecallUser = false,
            fsllLevelDrop = '3',
            startLevel = '4001',
            endLevel = 'top-90',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '2',
            topDrop = '3',
            calcRecallUser = false,
            fsllLevelDrop = '3',
            startLevel = 'top-89',
            endLevel = 'top',
          },
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '176',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  collectBarConfig = {
    {
      iconID = '176',
      canClick = true,
      index = -0.99,
      isNeedCustom = true,
      emphasize = false,
      alwaysShow = true,
      isStable = false,
    },
  },
  casVersion = '6cb66f4753f08cc21e95e46d74b9097f',
  modifyVersion = 8,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 242,
  version = 10,
  baseConfig = {
    ActivityCHName = '方块消消',
    ActivityName = 'BlockAct',
    isUseBTreeLogicRule = false,
    collectionIds = {
      '176',
    },
    isOpenExceedHightestStarMode = true,
    actMainManager = 'BlockManager',
    unifiedAct = true,
    isOpenRefreshScoreStrictMode = false,
    featureId = '6076',
    mainMgrName = 'BlockActManager',
  },
}