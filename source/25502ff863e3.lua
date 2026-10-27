return {
  ubfItemStaticConfig = {
    {
      itemType = 'WinningStreakScoreBottle',
      actLogicName = 'WinningStreakScoreBottleEventLogic',
      isActCore = true,
      priority = 0,
      isSkin = false,
      features = {
        treeTriggerRules = { 
            [UBFGameBTreeTriggerType.onBoardInit] = {
                {
                    codeRunner = {
                      luaPath = "ubf.UBFActivity.actFolder.WinningStreakScoreBottle.playFlyScoreBottleAction",
                      func = "doRunFlyScoreBottleAction"
                    },
                    markKey = "WinningStreakScoreBottle",
                    isStatic = false,
                    allowMarkRule = {
                        inBonus = false,
                        maxRunMarkTimes = 1,
                    },
                    priority = 2,
                },
            },
        },
      }
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_9064_miniGame',
    trigger = {
      'checkBaseCondition',
    },
    version = 2,
    __treeId = '1923',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '130',
        displayPriority = 10000,
        appearInContent = {
          2,
          5,
        },
        containCollectionIds = {
          '130',
        },
        touchTipText = '连胜加分瓶',
        iconTopLabelTypes = {
          9,
        },
        bottomText = ' ',
      },
    },
    usePropRewardConfig = {},
    usePropRewardTimesIsShared = true,
  },
  scoreBarConfig = {
    scoreBarColorBlendConfig = {
      autoUpdate = true,
      blendID = 'WSScoreBottle',
      colorBlendData = {
        {
          colorFile = 'WinningStreakScoreBottle/progressMask',
          colorBlendType = 1,
          colorID = 'pink',
          startPercent = 0.3,
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
            plist = 'ubfRes/ui/mod/WinningStreakScoreBottle/inLevelRes.plist',
            frameName = 'WinningStreakScoreBottle/130',
            type = 'image',
          },
          scene = 'default',
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '130',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  modifyVersion = 10,
  supportedLevelScenes = {
    'DEFAULT',
    'RANDOM_CHALLENGE_2023',
  },
  constraintVer = 219,
  version = 3,
  baseConfig = {
    needFuuuTargetProgressData = false,
    ActivityCHName = '连胜加分瓶',
    ActivityName = 'WinningStreakScoreBottle',
    collectionIds = {
      '130',
    },
    actMainManager = 'WinningStreakManager',
    isOpenExceedHightestStarMode = false,
    isOpenRefreshScoreStrictMode = true,
    featureId = '9064',
    mainMgrName = 'WinningStreakScoreBottleActManager',
  },
}