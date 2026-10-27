return {
  ubfItemStaticConfig = {
    {
      itemType = 'GemMining',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_6057',
    version = 2,
    __treeId = '1010',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '107',
        displayPriority = 10013,
        appearInContent = {
          5,
          9,
          2,
        },
        containCollectionIds = {
          '107',
        },
        touchTipText = '在【挖宝石!】活动中使用',
        iconTopLabelTypes = {
          1,
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
            plist = 'ubfRes/ui/mod/GemMining/inLevelRes.plist',
            frameName = 'GemMining/107',
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
            refreshStarDrop = '3',
            topDrop = '3',
            calcRecallUser = false,
            fsllLevelDrop = '6',
            startLevel = '0',
            endLevel = 'top-90',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '5',
            topDrop = '5',
            calcRecallUser = false,
            fsllLevelDrop = '6',
            startLevel = 'top-89',
            endLevel = 'top',
          },
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '107',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  collectBarConfig = {
    {
      iconID = '107',
      canClick = true,
      index = 0.5,
      isNeedCustom = true,
      containCollectionIds = {
        '107',
      },
      emphasize = true,
      alwaysShow = true,
      isStable = false,
    },
  },
  casVersion = 'b058512d7c8308e249d76175e29b9b96',
  modifyVersion = 36,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 226,
  version = 18,
  baseConfig = {
    ActivityCHName = '挖宝石!',
    ActivityName = 'GemMining',
    collectionIds = {
      '107',
    },
    isLimitColourStarMode = true,
    actMainManager = 'GemMiningManager',
    isOpenExceedHightestStarMode = true,
    isOpenRefreshScoreStrictMode = true,
    featureId = '6057',
    mainMgrName = 'GemMiningActManager',
  },
}