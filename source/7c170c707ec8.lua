return {
  ubfItemStaticConfig = {
    {
      itemType = 'SuperMagicBirdGift',
      actLogicName = 'SuperMagicBirdGiftActEventLogic',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '192',
        displayPriority = 9999,
        appearInContent = {
          5,
          2,
          9,
        },
        touchTipText = '在【超鸟送礼】活动中兑换实物奖励',
        iconTopLabelTypes = {
          1,
        },
      },
    },
    usePropRewardConfig = {},
    usePropRewardTimesIsShared = true,
  },
  actOpenConditionConfig = true,
  collectBarConfig = {
    {
      canClick = true,
      iconID = '192',
      index = -99.5,
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
            plist = 'ubfRes/ui/mod/SuperMagicBirdGift/inLevelRes.plist',
            frameName = 'SuperMagicBirdGift/192',
            type = 'image',
          },
          scene = 'default',
        },
      },
      startLevelPanelPriority = 99998,
      actItemId = '192',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  casVersion = '62d3702ca6b16d9dbe45e56855ce9014',
  modifyVersion = 11,
  supportedLevelScenes = {
    'DEFAULT',
    'MAIN',
    'HIDE',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 248,
  version = 11,
  baseConfig = {
    ActivityCHName = '超鸟送礼',
    ActivityName = 'SuperMagicBirdGift',
    isUseBTreeLogicRule = false,
    collectionIds = {
      '192',
    },
    isOpenExceedHightestStarMode = true,
    actMainManager = 'SuperMagicBirdGiftManager',
    unifiedAct = false,
    isOpenRefreshScoreStrictMode = true,
    featureId = '8079',
    mainMgrName = 'SuperMagicBirdGiftActManager',
  },
}