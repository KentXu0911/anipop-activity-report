return {
  ubfItemStaticConfig = {
    {
      res = {
        'MaceOfScore',
        'MaceOfScoreSpine',
      },
      itemType = 'MaceOfScore',
      actLogicName = 'MaceOfScoreUBFEventLogic',
      isActCore = true,
      priority = 0,
      itemContextName = 'MaceOfScoreUBFItemContext',
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_5305',
    trigger = {
      'checkBaseCondition',
      'finishBeforeStartLevel',
    },
    version = 1,
    __treeId = '375',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '退出会失去一次权杖使用机会',
        iconName = '62',
        displayPriority = 10008,
        appearInContent = {
          5,
          9,
        },
        touchTipText = '补星权杖',
        iconTopLabelTypes = {},
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
            plist = 'ui/inLevel/custom/maceOfScore/MaceOfScoreAddFiveIcon.plist',
            frameName = 'maceOfScoreAddFiveIcon',
            type = 'image',
          },
          scene = 'default',
        },
      },
      actItemId = '62',
    },
  },
  modifyVersion = 27,
  constraintVer = 178,
  version = 3,
  baseConfig = {
    needFuuuTargetProgressData = true,
    ActivityCHName = '补星权杖',
    customInLevelManager = '',
    ActivityName = 'MaceOfScore',
    collectionIds = {
      '62',
    },
    actMainManager = 'StarWandBuffManager',
    featureId = '5305',
    mainMgrName = 'ubf.UBFActivity.actFolder.MaceOfScore.MaceOfScoreUBFManager',
  },
}