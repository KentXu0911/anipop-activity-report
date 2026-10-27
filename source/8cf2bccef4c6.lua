return {
  ubfItemStaticConfig = {
    {
      itemType = 'ContinuousTarget',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_4042',
    trigger = {
      'checkBaseCondition',
    },
    version = 4,
    __treeId = '110',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '退出将会失去瓜分风车币大奖的机会哦，真的要退出吗？',
        iconName = '33',
        displayPriority = 10000,
        appearInContent = {
          5,
          8,
          9,
        },
        containCollectionIds = {
          '33',
        },
        touchTipText = '拯救么么狐 进行中',
        iconTopLabelTypes = {},
        bottomText = '%s关',
      },
    },
    secondConfirmMessage = '退出将会失去瓜分风车币大奖的机会哦，真的要退出吗？',
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
            plist = 'tempFunctionResInLevel/ContinuousTarget/inLevelRes.plist',
            frameName = 'ContinuousTarget/33',
            type = 'image',
          },
          scene = 'default',
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '33',
      notDisplayedStartLevelPanel = false,
    },
  },
  modifyVersion = 25,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 204,
  version = 3,
  baseConfig = {
    needFuuuTargetProgressData = false,
    ActivityCHName = '拯救么么狐',
    ActivityName = 'ContinuousTarget',
    collectionIds = {
      '33',
    },
    actMainManager = 'ContinuousTargetMgr',
    isOpenExceedHightestStarMode = true,
    isOpenRefreshScoreStrictMode = true,
    featureId = '4042',
    mainMgrName = 'ContinuousTargetActManager',
  },
}