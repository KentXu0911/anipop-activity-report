return {
  ubfItemStaticConfig = {
    {
      itemType = 'PetitPetMod',
      actLogicName = 'PetitPetActEventLogic',
      isActCore = true,
      priority = 0,
      isSkin = false,
      itemContextName = 'PetitPetModContext',
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_22009',
    trigger = {
      'checkBaseCondition',
    },
    version = 3,
    __treeId = '3162',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '187',
        displayPriority = 10000,
        appearInContent = {
          5,
          9,
          2,
        },
        containCollectionIds = {
          '187',
        },
        touchTipText = '在【小小萌伴】活动中使用',
        iconTopLabelTypes = {
          1,
          4,
          6,
        },
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
            plist = 'ubfRes/ui/mod/PetitPet/inLevelRes.plist',
            frameName = 'collectionIcon_187',
            type = 'image',
          },
          scene = 'default',
        },
      },
      additionTypes = {
        {
          type = 19,
          value = 1,
          group = 'FailLevelRateGroup',
        },
      },
      baseDropRule = {
        collectionBaseCountConfig = {
          {
            recallUserDrop = 0,
            refreshStarDrop = '3',
            topDrop = '3',
            calcRecallUser = false,
            fsllLevelDrop = '5',
            startLevel = '1',
            endLevel = '4000',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '3',
            topDrop = '3',
            calcRecallUser = false,
            fsllLevelDrop = '5',
            startLevel = '4001',
            endLevel = 'top-90',
          },
          {
            recallUserDrop = 0,
            refreshStarDrop = '3',
            topDrop = '5',
            calcRecallUser = false,
            fsllLevelDrop = '5',
            startLevel = 'top-89',
            endLevel = 'top',
          },
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '187',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  collectBarConfig = {
    {
      iconID = '187',
      canClick = true,
      index = -99,
      isNeedCustom = true,
      emphasize = true,
      containCollectionIds = {
        '187',
      },
      alwaysShow = true,
      value = 0,
      isStable = false,
    },
  },
  casVersion = '03d4df7745a9afad0fbe9f7b0d80f1b5',
  modifyVersion = 42,
  supportedLevelScenes = {
    'MAIN',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 247,
  version = 17,
  baseConfig = {
    needFuuuTargetProgressData = false,
    ActivityCHName = '宠物模块',
    ActivityName = 'PetitPet',
    collectionIds = {
      '187',
    },
    isUseBTreeLogicRule = false,
    actMainManager = 'PetManager',
    isOpenExceedHightestStarMode = false,
    unifiedAct = true,
    isOpenRefreshScoreStrictMode = true,
    featureId = '22009',
    mainMgrName = 'PetitPetActManager',
  },
}
