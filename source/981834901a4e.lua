return {
  ubfItemStaticConfig = {
    {
      itemType = 'SuperMagicBird2024',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  [''] = 'SuperMagicBird2024',
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_8063',
    version = 1,
    __treeId = '1140',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '132',
        displayPriority = 10000,
        appearInContent = {
          2,
          5,
          9,
        },
        touchTipText = '连胜保持超级魔力鸟',
        bottomText = '连胜保持',
        iconTopLabelTypes = {},
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
            plist = 'tempFunctionResInLevel/SuperMagicBird2024/InLevel.plist',
            frameName = 'superMagicBird2024_bird_icon',
            type = 'image',
          },
          scene = 'default',
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '132',
      notDisplayedStartLevelPanel = true,
      isStable = false,
    },
  },
  casVersion = 'bfb388ed097cff86bc8c32a5c6d58159',
  modifyVersion = 26,
  constraintVer = 224,
  version = 7,
  baseConfig = {
    ActivityCHName = '超级魔力鸟',
    ActivityName = 'SuperMagicBird2024',
    collectionIds = {
      '132',
    },
    isOpenExceedHightestStarMode = false,
    actMainManager = 'SuperMagicBird2024Manager',
    isOpenRefreshScoreStrictMode = true,
    featureId = '8068',
    mainMgrName = 'SuperMagicBird2024ActManager',
  },
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
}