return {
  ubfItemStaticConfig = {
    {
      itemType = 'MagicRush',
      actLogicName = 'MagicRushActEventLogic',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_9084',
    version = 2,
    __treeId = '2547',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '177',
        displayPriority = 10000,
        appearInContent = {
          2,
          5,
          9,
        },
        touchTipText = '用于【魔力冲冲冲】活动领奖',
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
  collectBarConfig = {
    {
      iconID = '177',
      canClick = true,
      index = -99,
      isNeedCustom = false,
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
            plist = 'ubfRes/ui/mod/MagicRush/inLevelRes.plist',
            frameName = 'MagicRush/177',
            type = 'image',
          },
          scene = 'default',
        },
      },
      additionTypes = {
        {
          type = 1,
          value = 5,
          group = 'LevelBaseRateGroup',
        },
        {
          type = 6,
          value = 5,
          group = 'LevelBaseRateGroup',
        },
        {
          type = 2,
          value = 2,
          group = 'LevelBaseRateGroup',
        },
        {
          type = 14,
          value = 5,
          group = 'RefreshStarRateGroup',
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '177',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  casVersion = '468b405cda73043ba79526863ccd81d5',
  modifyVersion = 22,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 242,
  version = 19,
  baseConfig = {
    ActivityCHName = '魔力冲冲冲',
    ActivityName = 'MagicRush',
    collectionIds = {
      '177',
    },
    isUseBTreeLogicRule = false,
    actMainManager = 'MagicRushManager',
    isOpenExceedHightestStarMode = true,
    unifiedAct = true,
    isOpenRefreshScoreStrictMode = true,
    featureId = '9084',
    mainMgrName = 'MagicRushActManager',
  },
}