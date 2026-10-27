return {
  ubfItemStaticConfig = {
    {
      itemType = 'FixBirdNest2',
      actLogicName = 'FixBirdNestActEventLogic',
      isActCore = true,
      priority = 0,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_5053_ubf',
    trigger = {
      'checkBaseCondition',
    },
    version = 3,
    __treeId = '442',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '就差1关！离开会失去修鸟窝奖励，不要放弃呀',
        iconName = '64',
        displayPriority = 10099,
        appearInContent = {
          8,
        },
        touchTipText = '【修鸟窝！】活动，鸟窝修复成功奖励',
        iconTopLabelTypes = {},
      },
    },
    secondConfirmMessage = '离开会失去修鸟窝奖励，不要放弃呀！',
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
            plist = 'tempFunctionResInLevel/FixBirdNest/json/InLevel.plist',
            frameName = 'fixBirdNest/xunzhang0000',
            type = 'image',
          },
          scene = 'default',
        },
      },
      actItemId = '64',
    },
  },
  modifyVersion = 10,
  constraintVer = 178,
  version = 3,
  baseConfig = {
    needFuuuTargetProgressData = false,
    ActivityCHName = '修鸟窝',
    ActivityName = 'FixBirdNest2',
    actIconRawData = {},
    collectionIds = {
      '64',
    },
    actMainManager = 'FixBirdNestManager',
    featureId = '5053',
    mainMgrName = 'FixBirdNestActManager',
  },
}