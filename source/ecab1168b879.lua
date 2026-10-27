return {
  ubfItemStaticConfig = {
    {
      itemType = 'ColorfulStarWinRepeat',
      actLogicName = 'ColorfulStarWinRepeatEventLogic',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_3055',
    trigger = {
      'checkBaseCondition',
    },
    version = 2,
    __treeId = '350',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '退出会失去全部连胜助力',
        iconName = '50',
        displayPriority = 10000,
        appearInContent = {
          2,
          4,
          5,
          9,
        },
        touchTipText = '彩星连胜%d连胜',
        bottomText = '%d连胜',
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
            plist = 'tempFunctionResInLevel/ColorfulStarWinRepeat/InLevel.plist',
            frameName = 'ColorfulStarWinRepeat/win10000',
            type = 'image',
          },
          scene = 'default',
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '50',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  casVersion = 'e78fba79ee5f32a7cd1c468b8450591a',
  modifyVersion = 11,
  constraintVer = 242,
  version = 6,
  baseConfig = {
    needFuuuTargetProgressData = false,
    ActivityCHName = '彩星连胜',
    ActivityName = 'ColorfulStarWinRepeat',
    collectionIds = {
      '50',
    },
    isUseBTreeLogicRule = false,
    actMainManager = 'ColorfulStarWinRepeatManager',
    isOpenExceedHightestStarMode = false,
    unifiedAct = true,
    isOpenRefreshScoreStrictMode = true,
    featureId = '8055',
    mainMgrName = 'ColorfulStarWinRepeatActManager',
  },
}