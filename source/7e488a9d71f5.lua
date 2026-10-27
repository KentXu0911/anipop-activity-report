return {
  ubfItemStaticConfig = {
    {
      itemType = 'PengPeng2026',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_8078',
    trigger = {
      'checkBaseCondition',
    },
    version = 1,
    __treeId = '3272',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '191',
        displayPriority = 10000,
        appearInContent = {
          5,
          9,
          2,
        },
        containCollectionIds = {
          '191',
        },
        touchTipText = '在【飞碟弹弹乐】活动中使用',
        iconTopLabelTypes = {
          1,
          10,
          6,
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
            plist = 'ubfRes/ui/mod/PengPeng2026/inLevelRes.plist',
            frameName = 'collectionIcon_191',
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
            refreshStarDrop = '2',
            calcRecallUser = false,
            fsllLevelDrop = '4',
            startLevel = '1',
            endLevel = '210',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '2',
            topDrop = '2',
            calcRecallUser = false,
            fsllLevelDrop = '4',
            startLevel = '211',
            endLevel = '4000',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '2',
            topDrop = '2',
            calcRecallUser = false,
            fsllLevelDrop = '4',
            startLevel = '4001',
            endLevel = 'top-90',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '3',
            topDrop = '3',
            calcRecallUser = false,
            fsllLevelDrop = '4',
            startLevel = 'top-89',
            endLevel = 'top',
          },
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '191',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  collectBarConfig = {
    {
      iconID = '191',
      canClick = true,
      index = -98,
      isNeedCustom = true,
      containCollectionIds = {
        '191',
      },
      emphasize = true,
      alwaysShow = true,
      isStable = false,
    },
  },
  supportedLevelScenes = {
    'MAIN',
    'RANDOM_CHALLENGE_2023',
  },
  baseConfig = {
    ActivityCHName = '飞碟弹弹乐',
    ActivityName = 'PengPeng2026',
    isUseBTreeLogicRule = false,
    collectionIds = {
      '191',
    },
    isOpenExceedHightestStarMode = true,
    actMainManager = 'PengPeng2026Manager',
    unifiedAct = true,
    isOpenRefreshScoreStrictMode = false,
    featureId = '8078',
    mainMgrName = 'PengPeng2026ActManager',
  },
}
