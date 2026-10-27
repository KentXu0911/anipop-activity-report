return {
  ubfItemStaticConfig = {
    {
      itemType = 'BoomMatch',
      actLogicName = 'BoomMatchUBFEventLogic',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_4055',
    version = 2,
    __treeId = '1100',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去以下收集物哦~',
        iconName = '122',
        displayPriority = 10013,
        appearInContent = {
          2,
          5,
          9,
        },
        touchTipText = '用于【爆破冠军赛】活动领奖',
        iconTopLabelTypes = {
          1,
          4,
          5,
        },
      },
    },
    secondConfirmMessage = '现在退出会失去以下收集物哦~',
    needSecondConfirm = true,
    usePropRewardConfig = {},
    usePropRewardTimesIsShared = true,
  },
  releaseVersion = 0,
  actItemConfig = {
    {
      iconConfig = {
        {
          rawData = {
            plist = 'tempFunctionResInLevel/BoomMatch/inLevelRes.plist',
            frameName = 'collection122',
            type = 'image',
          },
          scene = 'default',
        },
      },
      additionTypes = {
        {
          type = 1,
          value = 4,
          group = 'LevelBaseRateGroup',
        },
        {
          type = 12,
          value = 2,
          group = 'RefreshStarRateGroup',
        },
        {
          type = 14,
          value = 4,
          group = 'RefreshStarRateGroup',
        },
        {
          type = 15,
          value = 2,
          group = 'RefreshScoreRateGroup',
        },
        {
          type = 17,
          value = 5,
          group = 'FsllPassLevelRateGroup',
        },
      },
      startLevelPanelPriority = 90002,
      actItemId = '122',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  collectBarConfig = {
    {
      iconID = '122',
      canClick = true,
      index = -0.99,
      isNeedCustom = true,
      emphasize = true,
      alwaysShow = true,
      value = 0,
      isStable = false,
    },
  },
  modifyVersion = 14,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 215,
  baseConfig = {
    ActivityCHName = '爆破冠军赛',
    ActivityName = 'BoomMatch',
    collectionIds = {
      '122',
    },
    isOpenExceedHightestStarMode = false,
    actMainManager = 'BoomMatchMgr',
    isOpenRefreshScoreStrictMode = false,
    featureId = '4055',
    mainMgrName = 'ubf.UBFActivity.actFolder.BoomMatch.BoomMatchUBFManager',
  },
}