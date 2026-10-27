return {
  ubfItemStaticConfig = {
    {
      itemType = 'FullLevelSlotMachine',
      actLogicName = 'FullLevelSlotMachineEventLogic',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_5065',
    version = 5,
    __treeId = '1053',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '109',
        displayPriority = 19000,
        appearInContent = {
          5,
          9,
        },
        touchTipText = '用于【精英俱乐部】',
        iconTopLabelTypes = {
          1,
        },
      },
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '110',
        displayPriority = 19000,
        appearInContent = {
          5,
          9,
        },
        touchTipText = '用于【满级俱乐部】',
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
            plist = 'tempFunctionResInLevel/FullLevelSlotMachine/InLevel.plist',
            frameName = 'fulllevelslot/c10000',
            type = 'image',
          },
          scene = 'default',
        },
      },
      additionTypes = {
        {
          type = 7,
          value = 2,
          group = 'DiffcultRateGroup',
        },
        {
          type = 8,
          value = 2,
          group = 'DiffcultRateGroup',
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '109',
      notDisplayedStartLevelPanel = false,
    },
    {
      iconConfig = {
        {
          rawData = {
            plist = 'tempFunctionResInLevel/FullLevelSlotMachine/InLevel.plist',
            frameName = 'fulllevelslot/c20000',
            type = 'image',
          },
          scene = 'default',
        },
      },
      additionTypes = {
        {
          type = 7,
          value = 2,
          group = 'DiffcultRateGroup',
        },
        {
          type = 8,
          value = 2,
          group = 'DiffcultRateGroup',
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '110',
      notDisplayedStartLevelPanel = false,
    },
  },
  collectBarConfig = {
    {
      iconID = '109',
      canClick = true,
      index = -0.999,
      isNeedCustom = true,
      emphasize = true,
      alwaysShow = false,
      isStable = false,
    },
    {
      iconID = '110',
      canClick = true,
      index = -0.999,
      isNeedCustom = true,
      emphasize = true,
      alwaysShow = false,
      isStable = false,
    },
  },
  modifyVersion = 10,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 204,
  baseConfig = {
    ActivityCHName = '促满级补星',
    ActivityName = 'FullLevelSlotMachine',
    collectionIds = {
      '109',
      '110',
    },
    isLimitColourStarMode = true,
    actMainManager = 'FullLevelSlotMachineMgr',
    isOpenExceedHightestStarMode = true,
    isOpenRefreshScoreStrictMode = true,
    featureId = '5065',
    mainMgrName = 'FullLevelSlotMachineActManager',
  },
}