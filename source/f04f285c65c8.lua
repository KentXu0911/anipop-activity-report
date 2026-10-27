return {
  ubfItemStaticConfig = {
    {
      itemType = 'mergeevolution',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_3077',
    version = 2,
    __treeId = '2939',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '182',
        displayPriority = 10013,
        appearInContent = {
          5,
          8,
          2,
          9,
        },
        touchTipText = '在【迷你合合】活动中使用',
        iconTopLabelTypes = {
          1,
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
            plist = 'ubfRes/ui/mod/mergeevolution/inLevelRes.plist',
            frameName = 'mergeevolution/182',
            type = 'image',
          },
          scene = 'default',
        },
      },
      baseDropRule = {
        collectionBaseCountConfig = {
          {
            recallUserDrop = 0,
            refreshStarDrop = '10',
            topDrop = '4',
            calcRecallUser = false,
            fsllLevelDrop = '10',
            startLevel = '1',
            endLevel = 'top-90',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '10',
            topDrop = '10',
            calcRecallUser = false,
            fsllLevelDrop = '10',
            startLevel = 'top-89',
            endLevel = 'top',
          },
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '182',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  collectBarConfig = {
    {
      iconID = '182',
      canClick = true,
      index = -10,
      isNeedCustom = true,
      emphasize = true,
      alwaysShow = true,
      isStable = false,
    },
  },
  casVersion = '46af8cd4e1cc6e8441332ad6519865dd',
  modifyVersion = 76,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 236,
  version = 17,
  baseConfig = {
    ActivityCHName = '迷你合合',
    ActivityName = 'mergeevolution',
    collectionIds = {
      '182',
    },
    isUseBTreeLogicRule = false,
    isOpenExceedHightestStarMode = true,
    actMainManager = 'MergeEvolutionManager',
    isOpenRefreshScoreStrictMode = true,
    featureId = '3077',
    mainMgrName = 'MergeEvolutionActManager',
  },
}