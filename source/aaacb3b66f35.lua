return {
  ubfItemStaticConfig = {
    {
      itemType = 'biggiveaway',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_3078',
    version = 2,
    __treeId = '2940',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '183',
        displayPriority = 10013,
        appearInContent = {
          5,
          8,
          2,
          9,
        },
        touchTipText = '在【礼物大放送】活动中使用',
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
            plist = 'ubfRes/ui/mod/biggiveaway/inLevelRes.plist',
            frameName = 'biggiveaway/183',
            type = 'image',
          },
          scene = 'default',
        },
      },
      additionTypes = {
        {
          type = 1,
          value = 10,
          group = 'LevelBaseRateGroup',
        },
        {
          type = 14,
          value = 10,
          group = 'RefreshStarRateGroup',
        },
      },
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
      actItemId = '183',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  collectBarConfig = {
    {
      iconID = '183',
      canClick = true,
      index = -5,
      isNeedCustom = true,
      emphasize = true,
      alwaysShow = true,
      isStable = false,
    },
  },
  casVersion = 'd92073a85b64e2e1abc757de606900b8',
  modifyVersion = 71,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 236,
  version = 6,
  baseConfig = {
    ActivityCHName = '礼物大放送',
    ActivityName = 'biggiveaway',
    collectionIds = {
      '183',
    },
    isUseBTreeLogicRule = false,
    isOpenExceedHightestStarMode = true,
    actMainManager = 'BigGiveAwayManager',
    isOpenRefreshScoreStrictMode = true,
    featureId = '3078',
    mainMgrName = 'BigGiveAwayActManager',
  },
}