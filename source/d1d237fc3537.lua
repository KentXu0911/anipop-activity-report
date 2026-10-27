return {
  ubfItemStaticConfig = {
    {
      itemType = 'UserCallback2022zimi',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_10159',
    trigger = {
      'checkBaseCondition',
    },
    version = 2,
    __treeId = '197',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去紫咪加分的分数加成',
        iconName = '47',
        displayPriority = 10000,
        appearInContent = {
          5,
          9,
        },
        containCollectionIds = {
          '47',
        },
        touchTipText = '紫咪加分',
        iconTopLabelTypes = {
          9,
        },
        bottomText = '+%d%%',
      },
    },
    needSecondConfirm = false,
    usePropRewardConfig = {},
    usePropRewardTimesIsShared = true,
  },
  scoreBarConfig = {
    scoreBarColorBlendConfig = {
      autoUpdate = true,
      blendID = 'UserCallback2022zimi',
      colorBlendData = {
        {
          colorFile = 'UserCallback2022zimi/t_progressMask_yellow',
          colorBlendType = 2,
          fixPos = {x = 2,y = 0},
          colorID = 'yellow',
          startPercent = '0',
          endPercent = '0',
        },
        {
          colorFile = 'UserCallback2022zimi/t_progressMask_pink',
          colorBlendType = 2,
          fixPos = {x = 2,y = 0},
          colorID = 'pink',
          startPercent = '0',
          colorWidth = 0.2,
          endPercent = '0',
        },
      },
    },
  },
  releaseVersion = 0,
  actItemConfig = {
    {
      iconConfig = {
        {
          rawData = {
            plist = 'ubfRes/ui/mod/UserCallback2022zimi/InLevel.plist',
            frameName = 'zimi22/collect0000',
            type = 'image',
          },
          scene = 'default',
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '47',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  modifyVersion = 16,
  constraintVer = 224,
  version = 3,
  baseConfig = {
    needFuuuTargetProgressData = false,
    ActivityCHName = '紫咪回流',
    ActivityName = 'UserCallback2022zimi',
    collectionIds = {
      '47',
    },
    actMainManager = 'RecallZimiManager',
    isOpenExceedHightestStarMode = false,
    isOpenRefreshScoreStrictMode = true,
    featureId = '10168',
    mainMgrName = 'UserCallbackZimiActManager',
  },
}