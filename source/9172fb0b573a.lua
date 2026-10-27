return {
  ubfItemStaticConfig = {
    {
      itemType = 'MusicMaster',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_4062',
    version = 6,
    __treeId = '2746',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '过关失败会失去完美演奏家进度~',
        iconName = '179',
        displayPriority = 9990,
        appearInContent = {},
        containCollectionIds = {
          '179',
        },
        touchTipText = '完美演奏家活动',
        bottomText = '%s连胜',
        iconTopLabelTypes = {},
      },
    },
    usePropRewardConfig = {},
    usePropRewardTimesIsShared = true,
  },
  actItemConfig = {
    {
      iconConfig = {
        {
          rawData = {
            plist = 'ubfRes/ui/mod/MusicMaster/MusicMaster.plist',
            frameName = 'MusicMaster/collection_179',
            type = 'image',
          },
          scene = 'default',
        },
      },
      startLevelPanelPriority = 9999,
      actItemId = '179',
      notDisplayedStartLevelPanel = true,
      isStable = false,
    },
  },
  casVersion = 'd873b2b7d3784356c9dfbc35bcde870a',
  modifyVersion = 8,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 242,
  version = 10,
  baseConfig = {
    ActivityCHName = '完美演奏家',
    ActivityName = 'MusicMaster',
    isUseBTreeLogicRule = false,
    actIconRawData = {},
    collectionIds = {
      '179',
    },
    isOpenExceedHightestStarMode = false,
    actMainManager = 'MusicMasterInLevelManager',
    unifiedAct = true,
    isOpenRefreshScoreStrictMode = true,
    featureId = '4062',
    mainMgrName = 'MusicMasterActManager',
  },
}