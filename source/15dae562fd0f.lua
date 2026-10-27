return {
  ubfItemStaticConfig = {
    {
      itemType = 'TeamCamping',
      actLogicName = 'TeamCampingActEventLogic',
      isActCore = true,
      priority = 0,
      isSkin = false,
      features = {
        treeTriggerRules = { 
            [UBFGameBTreeTriggerType.onBoardStable] = {
                { 
                    codeRunner = {
                      luaPath = "ubf.UBFActivity.actFolder.TeamCamping.TeamCampingAction",
                      func = "doRunFlyRateAction"
                    },
                    markKey = "TeamCamping",
                    isStatic = false,
                    allowMarkRule = {
                        inBonus = false,
                        maxRunMarkTimes = 1,
                    },
                    priority = -100,
                },
            },
        },
      }
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_5071',
    version = 2,
    __treeId = '2267',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '167',
        displayPriority = 10000,
        appearInContent = {
          5,
          9,
          2,
        },
        touchTipText = '用于【去雨林！朋友】活动领奖',
        iconTopLabelTypes = {
          1,
          4,
          9,
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
            plist = 'tempFunctionResInLevel/TeamCamping/inLevelRes.plist',
            frameName = 'TeamCamping/167',
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
          value = 5,
          group = 'DiffcultRateGroup',
        },
        {
          type = 12,
          value = 1,
          group = 'RefreshStarRateGroup',
        },
        {
          type = 14,
          value = 2,
          group = 'RefreshStarRateGroup',
        },
        {
          type = 2,
          value = 5,
          group = 'LevelBaseRateGroup',
        },
        {
          type = 15,
          value = 1,
          group = 'RefreshScoreRateGroup',
        },
      },
      baseDropRule = {
        collectionBaseCountConfig = {
          {
            recallUserDrop = 0,
            refreshStarDrop = '10',
            topDrop = '10',
            refreshScoreDrop = '10',
            calcRecallUser = false,
            fsllLevelDrop = '10',
            startLevel = '1',
            endLevel = 'top',
          },
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '167',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  collectBarConfig = {
    {
      iconID = '167',
      canClick = true,
      index = -51,
      isNeedCustom = true,
      emphasize = true,
      alwaysShow = true,
      isStable = false,
    },
  },
  casVersion = 'e7cff73b4f2f620e8e02d6514fa56a43',
  modifyVersion = 30,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 226,
  version = 2,
  baseConfig = {
    ActivityCHName = '去雨林！朋友',
    ActivityName = 'TeamCamping',
    collectionIds = {
      '167',
    },
    isOpenExceedHightestStarMode = false,
    actMainManager = 'TeamCampingManager',
    isOpenRefreshScoreStrictMode = true,
    featureId = '5071',
    mainMgrName = 'TeamCampingActManager',
  },
}