return {
  ubfItemStaticConfig = {
    {
      itemType = 'fishingwinner',
      actLogicName = 'FishingWinnerEventLogic',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_6077',
    version = 2,
    __treeId = '2608',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '178',
        displayPriority = 10000,
        appearInContent = {
          5,
          9,
          2,
        },
        touchTipText = '在【钓鱼大赢家】活动中使用',
        iconTopLabelTypes = {
          1,
          4,
          6,
        },
      },
    },
    usePropRewardConfig = {},
    usePropRewardTimesIsShared = true,
  },
  scoreBarConfig = {
    scorePendantConfig = {
      {
        pendantID = 'fw_1_1',
        pendantType = 'pendantA',
        isNeedYellowTag = true,
        hangTarget = 'star_3',
        autoShowWhenCreated = false,
        touchTipStr = '用于钓鱼大赢家领奖',
        labelStr = '3倍',
        priority = 1,
        conditionConfig = {
          levelModeTypes = {
            1,
          },
          levelOldStars = {
            0,
          },
        },
        collectionId = '178',
        isCustomEnterAnimate = false,
      },
      {
        fixPos = {
          x = 0,
          y = -10,
        },
        pendantID = 'fw_1_2',
        pendantType = 'pendantA',
        isNeedYellowTag = true,
        hangTarget = 'star_4',
        autoShowWhenCreated = false,
        touchTipStr = '用于钓鱼大赢家领奖',
        labelStr = '5倍',
        priority = 1,
        conditionConfig = {
          levelModeTypes = {
            1,
          },
          levelOldStars = {
            0,
          },
        },
        collectionId = '178',
        isCustomEnterAnimate = false,
      },
      {
        pendantID = 'fw_2_1',
        pendantType = 'pendantA',
        isNeedYellowTag = true,
        hangTarget = 'star_3',
        autoShowWhenCreated = false,
        touchTipStr = '用于钓鱼大赢家领奖',
        labelStr = '3倍',
        priority = 1,
        conditionConfig = {
          levelModeTypes = {
            2,
          },
          levelOldStars = {
            0,
            1,
            2,
          },
        },
        collectionId = '178',
        isCustomEnterAnimate = false,
      },
      {
        fixPos = {
          x = 0,
          y = -10,
        },
        pendantID = 'fw_2_2',
        pendantType = 'pendantA',
        isNeedYellowTag = true,
        hangTarget = 'star_4',
        autoShowWhenCreated = false,
        touchTipStr = '用于钓鱼大赢家领奖',
        labelStr = '5倍',
        priority = 1,
        conditionConfig = {
          levelModeTypes = {
            2,
          },
          levelOldStars = {
            0,
            1,
            2,
            3,
          },
        },
        collectionId = '178',
        isCustomEnterAnimate = false,
      },
    },
  },
  actItemConfig = {
    {
      iconConfig = {
        {
          rawData = {
            plist = 'tempFunctionResInLevel/FishingWinner/json/InLevel.plist',
            frameName = 'FishingWinner/collect178',
            type = 'image',
          },
          scene = 'default',
        },
      },
      additionTypes = {
        {
          type = 10,
          value = 3,
          group = 'PassLevelRateGroup',
        },
        {
          type = 11,
          value = 5,
          group = 'PassLevelRateGroup',
        },
        {
          type = 2,
          value = 2,
          group = 'LevelBaseRateGroup',
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
      },
      additionRule = '',
      baseDropRule = {
        collectionBaseCountConfig = {
          {
            recallUserDrop = 0,
            refreshStarDrop = '2',
            topDrop = '1',
            calcRecallUser = false,
            fsllLevelDrop = '2',
            startLevel = '1',
            endLevel = 'top-90',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '2',
            topDrop = '2',
            calcRecallUser = false,
            fsllLevelDrop = '2',
            startLevel = 'top-89',
            endLevel = 'top',
          },
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '178',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  collectBarConfig = {
    {
      iconID = '178',
      canClick = true,
      index = -0.99,
      isNeedCustom = true,
      emphasize = true,
      alwaysShow = true,
      isStable = false,
    },
  },
  casVersion = '824874fc50d8868eeda7ad40570c7a8b',
  modifyVersion = 11,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 242,
  version = 15,
  baseConfig = {
    ActivityCHName = '钓鱼大赢家',
    ActivityName = 'fishingwinner',
    isUseBTreeLogicRule = false,
    collectionIds = {
      '178',
    },
    isOpenExceedHightestStarMode = false,
    actMainManager = 'FishingWinnerManager',
    unifiedAct = true,
    isOpenRefreshScoreStrictMode = false,
    featureId = '6077',
    mainMgrName = 'FishingWinnerActManager',
  },
}