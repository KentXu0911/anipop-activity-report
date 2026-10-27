return {
  ubfItemStaticConfig = {
    {
      itemType = 'WinRepeatRank2023',
      actLogicName = 'WinRepeatRank2023ActEventLogic',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_4046_ubf',
    trigger = {
      'checkBaseCondition',
    },
    version = 7,
    __treeId = '764',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '如果现在放弃,你将损失以下所有物品：',
        iconName = '82',
        displayPriority = 10000,
        appearInContent = {
          2,
          5,
          12,
          9,
        },
        touchTipText = '用于【连胜排行榜】活动排名',
        iconTopLabelTypes = {
          1,
          7,
          6,
          5,
        },
      },
    },
    needSecondConfirm = false,
    usePropRewardConfig = {},
    usePropRewardTimesIsShared = true,
  },
  releaseVersion = 0,
  actItemConfig = {
    {
      iconConfig = {
        {
          rawData = {
            plist = 'ubfRes/ui/mod/WinRepeatRank2023/inLevelRes.plist',
            frameName = 'WinRepeatRank2023/82',
            type = 'image',
          },
          scene = 'default',
        },
      },
      additionTypes = {
        {
          type = 14,
          value = 2,
          group = 'RefreshStarRateGroup',
        },
        {
          type = 17,
          value = 4,
          group = 'FsllPassLevelRateGroup',
        },
        {
          type = 15,
          value = 2,
          group = 'RefreshScoreRateGroup',
        },
      },
      additionRule = {
        ruleType = 'AdditionRuleType.kDefalut',
        ruleTreeConfig = {},
      },
      startLevelPanelPriority = 99999,
      actItemId = '82',
      notDisplayedStartLevelPanel = false,
    },
  },
  collectBarConfig = {
    {
      iconID = '82',
      canClick = true,
      index = 1,
      isNeedCustom = true,
      emphasize = true,
      alwaysShow = true,
      isStable = false,
    },
  },
  modifyVersion = 30,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 214,
  version = 3,
  baseConfig = {
    needFuuuTargetProgressData = false,
    ActivityCHName = '连胜排行榜',
    customInLevelManager = 'zoo.localActivity.winRepeatRank.WinRepeatRank2023InLevelMgr',
    ActivityName = 'WinRepeatRank2023',
    collectionIds = {
      '82',
    },
    actMainManager = 'WinRepeatRankManager',
    isOpenExceedHightestStarMode = true,
    isOpenRefreshScoreStrictMode = true,
    featureId = '4046',
    mainMgrName = 'WinRepeatRank2023ActManager',
  },
}