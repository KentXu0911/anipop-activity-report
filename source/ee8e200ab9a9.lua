return {
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_6063',
    version = 11,
    __treeId = '1180',
  },
  deputyLevelConfig = {
    {
      endLevelDisplayName = '',
      levelStartId = 0,
      levelEndId = 0,
      levelType = 116,
      isDeputyActivity = false,
      levelDisplayName = '',
      isUseNormalDeputyLevel = true,
      continueLevel = '',
      levelScene = 'MATCHFESTIVAL_2025_BIG_MAP',
    },
  },
  releaseVersion = 0,
  actItemConfig = {
    {
      iconConfig = {
        {
          rawData = {
            plist = 'tempFunctionResInLevel/MergeAct/InLevel.plist',
            frameName = 'collect136',
            type = 'image',
          },
          scene = 'default',
        },
      },
      additionTypes = {
        {
          type = 1,
          value = 2,
          group = 'LevelBaseRateGroup',
        },
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
            topDrop = '4',
            calcRecallUser = false,
            fsllLevelDrop = '5',
            startLevel = '211',
            endLevel = 'top-90',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '8',
            topDrop = '8',
            calcRecallUser = false,
            fsllLevelDrop = '5',
            startLevel = 'top-89',
            endLevel = 'top',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '8',
            calcRecallUser = false,
            fsllLevelDrop = '5',
            startLevel = '1',
            endLevel = '210',
          },
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '174',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
    {
      iconConfig = {
        {
          rawData = {
            plist = 'tempFunctionResInLevel/MergeAct/InLevel.plist',
            frameName = 'collect136',
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
      startLevelPanelPriority = 99999,
      actItemId = '172',
      notDisplayedStartLevelPanel = true,
      isStable = false,
    },
  },
  casVersion = 'b12df27cc4e59b78039b3e7a79047e66',
  constraintVer = 246,
  version = 20,
  ubfItemStaticConfig = {
    {
      itemType = 'merge2025',
      actLogicName = 'MergeAct2024EventLogic',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '174',
        displayPriority = 10000,
        appearInContent = {
          5,
          9,
          2,
        },
        touchTipText = '在【美味合合】活动中使用',
        iconTopLabelTypes = {
          1,
          10,
        },
      },
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '172',
        displayPriority = 10000,
        appearInContent = {
          5,
          9,
          2,
        },
        touchTipText = '在【美味合合】活动中使用',
        iconTopLabelTypes = {
          1,
          6,
        },
      },
    },
    usePropRewardConfig = {},
    usePropRewardTimesIsShared = true,
  },
  collectBarConfig = {
    {
      iconID = '174',
      canClick = true,
      index = -5,
      isNeedCustom = true,
      emphasize = true,
      alwaysShow = false,
      isStable = false,
    },
    {
      iconID = '172',
      canClick = true,
      index = -0.99,
      isNeedCustom = true,
      emphasize = true,
      alwaysShow = false,
      isStable = false,
    },
  },
  modifyVersion = 37,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  baseConfig = {
    ActivityCHName = '美味合合',
    ActivityName = 'merge2025',
    collectionIds = {
      '174',
      '172',
    },
    isUseBTreeLogicRule = false,
    isOpenExceedHightestStarMode = true,
    actMainManager = 'MergeManager',
    unifiedAct = true,
    isOpenRefreshScoreStrictMode = false,
    featureId = '6074',
    mainMgrName = 'MergeAct2024ActManager',
  },
}