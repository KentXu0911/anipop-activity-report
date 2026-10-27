return {
  ubfItemStaticConfig = {
    {
      itemType = 'musicmerge',
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
        iconName = '185',
        displayPriority = 10013,
        appearInContent = {
          5,
          8,
          2,
          9,
        },
        touchTipText = '在【妙音合合】活动中使用',
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
      actItemId = '185',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  collectBarConfig = {
    {
      iconID = '185',
      canClick = true,
      index = -10,
      isNeedCustom = true,
      emphasize = true,
      alwaysShow = true,
      isStable = false,
    },
  },
  casVersion = 'f6691f87fba174ecc28597f7c961630c',
  modifyVersion = 78,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 236,
  version = 9,
  baseConfig = {
    ActivityCHName = '妙音合合',
    ActivityName = 'musicmerge',
    collectionIds = {
      '185',
    },
    isUseBTreeLogicRule = false,
    isOpenExceedHightestStarMode = true,
    actMainManager = 'MusicMergeManager',
    isOpenRefreshScoreStrictMode = true,
    featureId = '3080',
    mainMgrName = 'MusicMergeActManager',
  },
}