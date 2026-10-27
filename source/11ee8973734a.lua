return {
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_3052',
    trigger = {
      'checkBaseCondition',
    },
    version = 2,
    __treeId = '165',
  },
  scoreBarConfig = {
    scoreBarColorBlendConfig = {
      autoUpdate = true,
      blendID = 'promotion',
      colorBlendData = {
        {
          mixLeft = 0.3,
          colorFile = 'PromotionEvent/progressMask',
          colorBlendType = 2,
          colorID = 'promotion3052',
          startPercent = '0',
          colorWidth = 0.2,
          endPercent = '0',
        },
      },
    },
  },
  releaseVersion = 0,
  actItemConfig = {
    {
      iconConfig = {
        {
          rawData = {
            frameName = 'common/icon_256/icon_xinjinjisai',
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
        {
          type = 12,
          value = 2,
          group = 'RefreshStarRateGroup',
        },
        {
          type = 13,
          value = 3,
          group = 'RefreshStarRateGroup',
        },
        {
          type = 14,
          value = 5,
          group = 'RefreshStarRateGroup',
        },
        {
          type = 17,
          value = 5,
          group = 'FsllPassLevelRateGroup',
        },
        {
          type = 15,
          value = 1,
          group = 'RefreshScoreRateGroup',
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '7',
      notDisplayedStartLevelPanel = false,
    },
    {
      iconConfig = {
        {
          rawData = {
            plist = 'ubfRes/ui/mod/PromotionEvent/InLevel/InLevel.plist',
            frameName = 'Promotion/fox0000',
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
        {
          type = 12,
          value = 2,
          group = 'RefreshStarRateGroup',
        },
        {
          type = 13,
          value = 3,
          group = 'RefreshStarRateGroup',
        },
        {
          type = 14,
          value = 5,
          group = 'RefreshStarRateGroup',
        },
        {
          type = 15,
          value = 1,
          group = 'RefreshScoreRateGroup',
        },
        {
          type = 17,
          value = 5,
          group = 'FsllPassLevelRateGroup',
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '8',
      notDisplayedStartLevelPanel = false,
    },
  },
  casVersion = '1ef8a83ac858ceceec7226ac5556b2a9',
  constraintVer = 193,
  version = 22,
  ubfItemStaticConfig = {
    {
      itemType = 'PromotionEventCtv1',
      isActCore = true,
      priority = 0,
    },
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '7',
        displayPriority = 10014,
        appearInContent = {
          5,
          9,
        },
        containCollectionIds = {
          '7',
        },
        touchTipText = '闯关晋级赛',
        iconTopLabelTypes = {
          1,
          4,
          5,
        },
      },
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '8',
        displayPriority = 10014,
        appearInContent = {
          5,
          9,
        },
        containCollectionIds = {
          '8',
        },
        touchTipText = '闯关晋级赛',
        iconTopLabelTypes = {
          1,
          4,
          5,
        },
      },
    },
    needSecondConfirm = false,
    usePropRewardConfig = {},
    usePropRewardTimesIsShared = true,
  },
  collectBarConfig = {
    {
      iconID = '7',
      canClick = true,
      index = -100,
      isNeedCustom = true,
      emphasize = true,
      containCollectionIds = {
        '7',
      },
      alwaysShow = true,
      value = 0,
      isStable = false,
    },
    {
      iconID = '8',
      canClick = true,
      index = -100,
      isNeedCustom = true,
      emphasize = true,
      containCollectionIds = {
        '8',
      },
      alwaysShow = true,
      value = 0,
      isStable = false,
    },
  },
  modifyVersion = 24,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  baseConfig = {
    needFuuuTargetProgressData = false,
    ActivityCHName = '闯关晋级赛',
    ActivityName = 'PromotionEvent',
    collectionIds = {
      '7',
      '8',
    },
    actMainManager = 'PromotionEventManager',
    isOpenRefreshScoreStrictMode = true,
    featureId = '3052',
    mainMgrName = 'PromotionCtv1ActManager',
  },
}
