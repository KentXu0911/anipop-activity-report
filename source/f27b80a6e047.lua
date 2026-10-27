return {
  ubfItemStaticConfig = {
    {
      itemType = 'DailyLevelGameplay',
      isActCore = true,
      priority = 0,
      isSkin = false,
      eventHandler = {
        eventMap = {
          [UBFGamePlayEventEnum.kBeforeRunMark] = true,
        },
      },
      features = {
        treeTriggerRules = {
          [UBFGameBTreeTriggerType.onBoardStable] = {
            {
              codeRunner = {
                luaPath = 'DailyLevelGameplay.Action',
                func = 'doDailyLevelScroll',
              },
              markKey = 'DailyLevelGameplayScroll',
              isStatic = true,
              priority = 470,
            },
          },
        },
      },
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_8077',
    version = 4,
    __treeId = '3172',
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        panelText = '现在退出会失去大量收集物',
        iconName = '188',
        displayPriority = 10000,
        appearInContent = {
          5,
          8,
        },
        touchTipText = '在【每日夺宝】活动中使用',
        iconTopLabelTypes = {
          6,
        },
      },
    },
    usePropRewardConfig = {},
    usePropRewardTimesIsShared = true,
  },
  deputyLevelConfig = {
    {
      endLevelDisplayName = '每日夺宝',
      levelStartId = 431001,
      levelEndId = 431026,
      levelDisplayName = '每日夺宝',
      decoratePassLevelCall = '',
      levelScene = 'DAILY_LEVEL_GAMEPLAY',
      continueLevel = 1,
    },
  },
  actItemConfig = {
    {
      iconConfig = {
        {
          rawData = {
            plist = 'ubfRes/ui/mod/DailyLevelGameplay/inLevelRes.plist',
            frameName = 'DailyLevelGameplay/188',
            type = 'image',
          },
          scene = 'default',
        },
      },
      startLevelPanelPriority = 99999,
      actItemId = '188',
      notDisplayedStartLevelPanel = false,
      isStable = false,
    },
  },
  casVersion = '71c984b4d0665ca03d0880b9b22e626a',
  modifyVersion = 7,
  constraintVer = 248,
  version = 10,
  baseConfig = {
    ActivityCHName = '每日夺宝',
    ActivityName = 'DailyLevelGameplay',
    isUseBTreeLogicRule = false,
    collectionIds = {
      '188',
    },
    isOpenExceedHightestStarMode = false,
    actMainManager = 'DailyLevelMgr',
    unifiedAct = false,
    isOpenRefreshScoreStrictMode = false,
    featureId = '8077',
    mainMgrName = 'DailyLevelGameplayActManager',
  },
}
