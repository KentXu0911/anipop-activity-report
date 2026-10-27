return {
  ubfItemStaticConfig = {
    {
      itemType = 'layeredtilematch',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_4105',
    version = 1,
    __treeId = '3251',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '190',
        displayPriority = 10013,
        appearInContent = {
          5,
          9,
          2,
        },
        touchTipText = '在【开心农家乐】活动中使用',
        iconTopLabelTypes = {
          10,
        },
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
            plist = 'tempFunctionResInLevel/LayeredTileMatch/InLevel.plist',
            frameName = 'happyfarmhouse/collection',
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
            refreshScoreDrop = '0',
            topDrop = '1',
            calcRecallUser = false,
            fsllLevelDrop = '2',
            startLevel = '211',
            endLevel = 'top-90',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '2',
            refreshScoreDrop = '0',
            topDrop = '2',
            calcRecallUser = false,
            fsllLevelDrop = '2',
            startLevel = 'top-89',
            endLevel = 'top-45',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '2',
            refreshScoreDrop = '0',
            topDrop = '2',
            calcRecallUser = false,
            fsllLevelDrop = '2',
            startLevel = 'top-44',
            endLevel = 'top',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '2',
            refreshScoreDrop = '0',
            calcRecallUser = false,
            fsllLevelDrop = '2',
            startLevel = '1',
            endLevel = '210',
          },
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '190',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  collectBarConfig = {
    {
      iconID = '190',
      canClick = true,
      index = -99,
      isNeedCustom = true,
      emphasize = true,
      alwaysShow = true,
      isStable = false,
    },
  },
  casVersion = 'a67ff8424af0f06aa59ef53ebd2f8675',
  modifyVersion = 2,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 245,
  version = 2,
  baseConfig = {
    ActivityCHName = '开心农家乐',
    ActivityName = 'layeredtilematch',
    isUseBTreeLogicRule = false,
    collectionIds = {
      '190',
    },
    isLimitColourStarMode = true,
    isOpenExceedHightestStarMode = true,
    actMainManager = 'LayeredTileMatchManager',
    unifiedAct = true,
    isOpenRefreshScoreStrictMode = true,
    featureId = '4105',
    mainMgrName = 'LayeredTileMatchActManager',
  },
}
