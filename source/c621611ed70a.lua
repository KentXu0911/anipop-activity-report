return {
  ubfItemStaticConfig = {
    {
      itemType = 'Gladiator',
      actLogicName = 'GladiatorActEventLogic',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_9079',
    version = 2,
    __treeId = '1165',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '135',
        displayPriority = 10000,
        appearInContent = {
          2,
          5,
          9,
        },
        touchTipText = '用于【疯狂对决】活动领奖',
        iconTopLabelTypes = {
          1,
          4,
          5,
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
            plist = 'ubfRes/ui/mod/Gladiator/inLevelRes.plist',
            frameName = 'Gladiator/135',
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
          type = 12,
          value = 2,
          group = 'RefreshStarRateGroup',
        },
        {
          type = 14,
          value = 5,
          group = 'RefreshStarRateGroup',
        },
        {
          type = 15,
          value = 5,
          group = 'RefreshScoreRateGroup',
        },
        {
          type = 17,
          value = 6,
          group = 'FsllPassLevelRateGroup',
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '135',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  collectBarConfig = {
    {
      iconID = '135',
      canClick = true,
      index = -0.99,
      isNeedCustom = false,
      emphasize = true,
      alwaysShow = true,
      isStable = false,
    },
  },
  modifyVersion = 19,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 215,
  baseConfig = {
    ActivityCHName = '疯狂对决',
    ActivityName = 'Gladiator',
    collectionIds = {
      '135',
    },
    isOpenExceedHightestStarMode = false,
    actMainManager = 'GladiatorMgr',
    isOpenRefreshScoreStrictMode = true,
    featureId = '9079',
    mainMgrName = 'GladiatorActManager',
  },
}