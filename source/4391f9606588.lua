return {
  ubfItemStaticConfig = {
    {
      itemType = 'StellarConvergence',
      actLogicName = 'StellarConvergenceActEventLogic',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_6051',
    version = 2,
    __treeId = '2478',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '175',
        displayPriority = 10000000,
        appearInContent = {
          2,
          5,
          9,
        },
        touchTipText = '用于【星光之域】的闪耀星光等级排名',
        iconTopLabelTypes = {
          1,
        },
      },
    },
    usePropRewardConfig = {},
    usePropRewardTimesIsShared = true,
  },
  collectBarConfig = {
    {
      iconID = '175',
      canClick = true,
      index = -0.99,
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
            frameName = 'other/iconV2/ui_icon_star_05_v2',
            type = 'image',
          },
          scene = 'default',
        },
      },
      additionTypes = {
        {
          type = 17,
          value = 1,
          group = 'FsllPassLevelRateGroup',
        },
      },
      baseDropRule = {
        collectionBaseCountConfig = {
          {
            recallUserDrop = 0,
            calcRecallUser = false,
            fsllLevelDrop = '1',
            startLevel = '1',
            endLevel = 'top',
          },
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '175',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  casVersion = 'fab3dd942875fa36874003d13545b186',
  modifyVersion = 16,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 242,
  version = 23,
  baseConfig = {
    ActivityCHName = '星光之域',
    ActivityName = 'StellarConvergence',
    isUseBTreeLogicRule = false,
    collectionIds = {
      '175',
    },
    isOpenExceedHightestStarMode = false,
    actMainManager = 'StellarConvergenceManager',
    unifiedAct = true,
    isOpenRefreshScoreStrictMode = true,
    featureId = '6051',
    mainMgrName = 'StellarConvergenceActManager',
  },
}