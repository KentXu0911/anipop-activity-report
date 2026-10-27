return {
  baseConfig = {
    featureId = '3052',
    ActivityCHName = '闯关晋级赛',
    ActivityName = 'PromotionEvent',
    actMainManager = 'PromotionEventManager',
    mainMgrName = 'PromotionActManager',
  },
  actOpenConditionConfig = {
    commonConditionRules = {
      isHelping = false,
      flagIncluded = {
        sourceId = '3052',
        modDatas = {
          {
            k = 'isInLevelEnabled',
            v = true,
          },
        },
      },
    },
  },
  settleMentConfig = {
    {
      enableRules = {
        commonConditionRules = {
          levelModeTypes = {
            1,
            4,
            5,
          },
        },
      },
      settleMentType = 1,
    },
    {
      enableRules = {
        commonConditionRules = {
          levelModeTypes = {
            2,
          },
        },
      },
      settleMentType = 4,
    },
    {
      enableRules = {
        commonConditionRules = {
          levelModeTypes = {
            3,
          },
        },
      },
      settleMentType = 3,
    },
  },
  collectBarConfig = {
    iconList = {
      {
        actItemIndex = 0,
        enableRules = {
          customConditionGroupReference = {
            0,
          },
        },
        alwaysShow = true,
        emphasize = true,
        canClick = true,
        priorityConfig = {
          {
            priorityKey = 'PromotionEvent',
          },
        },
        viewLabelConfig = {
          {
            enableRules = {
              commonConditionRules = {
                collectRate = {
                  collectionId = '8',
                  minRate = 2,
                },
              },
            },
            bonusText = {
              template = '{rate}倍',
              variables = {
                {
                  fieldKey = 'rate',
                  source = 'actData',
                },
              },
              renderMode = 'plain',
              onMissing = 'empty',
            },
          },
          {
            enableRules = {
              commonConditionRules = {
                levelModeTypes = {
                  2,
                },
                modEnvData = {
                  sourceId = '3052',
                  modDatas = {
                    {
                      k = 'settleMentType',
                      v = 4,
                    },
                  },
                },
              },
            },
            bonusText = {
              template = '补星可得',
              variables = {},
              renderMode = 'plain',
              onMissing = 'empty',
            },
          },
          {
            enableRules = {
              commonConditionRules = {
                levelModeTypes = {
                  2,
                },
                modEnvData = {
                  sourceId = '3052',
                  modDatas = {
                    {
                      k = 'settleMentType',
                      v = 5,
                    },
                  },
                },
              },
            },
            bonusText = {
              template = '补彩星可得',
              variables = {},
              renderMode = 'plain',
              onMissing = 'empty',
            },
          },
        },
        touchTipConfig = {
          {
            mainTitle = '闯关晋级赛',
            type = 'infoFlowTip',
          },
        },
      },
      {
        actItemIndex = 1,
        enableRules = {
          customConditionGroupReference = {
            1,
          },
        },
        alwaysShow = true,
        emphasize = true,
        canClick = true,
        priorityConfig = {
          {
            priorityKey = 'PromotionEvent',
          },
        },
        viewLabelConfig = {
          {
            enableRules = {
              commonConditionRules = {
                collectRate = {
                  collectionId = '7',
                  minRate = 2,
                },
              },
            },
            bonusText = {
              template = '{rate}倍',
              variables = {
                {
                  fieldKey = 'rate',
                  source = 'actData',
                },
              },
              renderMode = 'plain',
              onMissing = 'empty',
            },
          },
          {
            enableRules = {
              commonConditionRules = {
                levelModeTypes = {
                  2,
                },
                modEnvData = {
                  sourceId = '3052',
                  modDatas = {
                    {
                      k = 'settleMentType',
                      v = 4,
                    },
                  },
                },
              },
            },
            bonusText = {
              template = '补星可得',
              variables = {},
              renderMode = 'plain',
              onMissing = 'empty',
            },
          },
          {
            enableRules = {
              commonConditionRules = {
                levelModeTypes = {
                  2,
                },
                modEnvData = {
                  sourceId = '3052',
                  modDatas = {
                    {
                      k = 'settleMentType',
                      v = 5,
                    },
                  },
                },
              },
            },
            bonusText = {
              template = '补彩星可得',
              variables = {},
              renderMode = 'plain',
              onMissing = 'empty',
            },
          },
        },
        touchTipConfig = {
          {
            mainTitle = '闯关晋级赛',
            type = 'infoFlowTip',
          },
        },
      },
    },
  },
  scoreBarConfig = {
    scoreBarColorBlendConfig = {
      enableRules = {
        commonConditionRules = {
          modEnvData = {
            sourceId = '3052',
            modDatas = {
              {
                k = 'hasScoreBuff',
                v = true,
              },
            },
          },
        },
      },
      blendID = 'promotion',
      autoUpdate = true,
      colorBlendData = {
        {
          colorID = 'promotion3052',
          colorFile = 'PromotionEvent/progressMask',
          colorBlendType = 2,
          colorWidth = 0.2,
          mixLeft = 0.3,
        },
      },
    },
  },
  slpPlpViewConfig = {
    tagConfigs = {
      {
        configType = 'collection',
        collectionTagConfig = {
          collectionRef = 0,
          priorityConfig = {
            {
              priorityKey = 'PromotionEvent',
            },
          },
          enableRules = {
            customConditionGroupReference = {
              0,
            },
          },
          displayItems = {
            {
              additionKeys = {
                'timeLimit',
              },
              endTimeField = {
                fieldName = 'env.buffEndTime',
              },
              label = '限时加成',
              useLongBg = false,
            },
            {
              additionKeys = {
                'firstPlay',
                'top_passLevel',
              },
              label = '过关可得',
              useLongBg = false,
            },
            {
              additionKeys = {
                'refreshStar',
                'refreshThreeStar',
                'refreshColourStar',
              },
              label = '补星成功',
              useLongBg = false,
            },
            {
              additionKeys = {
                'refreshScoreSuccess',
              },
              label = '刷分成功',
              useLongBg = false,
            },
            {
              additionKeys = {
                'fsllPassLevel',
              },
              label = '过关可得',
              useLongBg = false,
            },
          },
        },
      },
      {
        configType = 'collection',
        collectionTagConfig = {
          collectionRef = 1,
          priorityConfig = {
            {
              priorityKey = 'PromotionEvent',
            },
          },
          enableRules = {
            customConditionGroupReference = {
              1,
            },
          },
          displayItems = {
            {
              additionKeys = {
                'timeLimit',
              },
              endTimeField = {
                fieldName = 'env.buffEndTime',
              },
              label = '限时加成',
              useLongBg = false,
            },
            {
              additionKeys = {
                'firstPlay',
                'top_passLevel',
              },
              label = '过关可得',
              useLongBg = false,
            },
            {
              additionKeys = {
                'refreshStar',
                'refreshThreeStar',
                'refreshColourStar',
              },
              label = '补星成功',
              useLongBg = false,
            },
            {
              additionKeys = {
                'refreshScoreSuccess',
              },
              label = '刷分成功',
              useLongBg = false,
            },
            {
              additionKeys = {
                'fsllPassLevel',
              },
              label = '过关可得',
              useLongBg = false,
            },
          },
        },
      },
      {
        configType = 'extraReward',
        extraRewardTagConfig = {
          rewardType = 'yinbi',
          endTimeField = {
            fieldName = 'sl.extraReward.coinBuffEndTime',
          },
          rateField = {
            fieldName = 'sl.extraReward.coinFactor',
          },
          priorityConfig = {
            {
              priorityKey = 'PromotionEvent',
            },
          },
        },
      },
      {
        configType = 'extraReward',
        extraRewardTagConfig = {
          rewardType = 'score',
          endTimeField = {
            fieldName = 'sl.extraReward.scoreBuffEndTime',
          },
          rateField = {
            fieldName = 'sl.extraReward.scoreFactor',
          },
          priorityConfig = {
            {
              priorityKey = 'PromotionEvent',
            },
          },
          enableRules = {
            commonConditionRules = {
              levelRange = {
                levelSceneNotIncluded = {
                  'RANDOM_CHALLENGE_2023',
                },
              },
            },
          },
        },
      },
    },
  },
  sharedViewConfigs = {
    {
      desc = '小狐狸',
      materialData = {
        viewType = 'Sprite',
        plist = 'ubfRes/ui/mod/PromotionEvent/InLevel/InLevel.plist',
        frameName = 'Promotion/fox0000',
      },
      animationData = {},
    },
    {
      desc = '横竖消',
      materialData = {
        viewType = 'Sprite',
        frameName = 'common/icon_256/icon_xinjinjisai',
      },
      animationData = {},
    },
    {
      desc = '分数条变色',
      materialData = {
        viewType = 'Sprite',
        plist = 'ubfRes/ui/mod/PromotionEvent/InLevel/progressMask.plist',
        frameName = 'PromotionEvent/progressMask',
      },
      animationData = {},
    },
  },
  actCollectionConfigs = {
    {
      desc = '小狐狸',
      collectionId = '8',
      enableRules = {
        customConditionGroupReference = {
          0,
        },
      },
      additionRules = {
        {
          triggerScene = {
            'StartLevel',
            'EndLevel',
          },
          enableRules = {
            commonConditionRules = {
              isFirstPlayLevel = true,
              passLevelState = {
                'Pass',
              },
            },
          },
          calcMaxRateEnableRules = {
            commonConditionRules = {
              isFirstPlayLevel = true,
            },
          },
          additionKey = 'firstPlay',
          addValue = 2,
        },
        {
          triggerScene = {
            'StartLevel',
            'EndLevel',
          },
          enableRules = {
            commonConditionRules = {
              modEnvData = {
                sourceId = '3052',
                modDatas = {
                  {
                    k = 'hasTimeLimiteBuff',
                    v = true,
                  },
                },
              },
              passLevelState = {
                'Pass',
              },
            },
          },
          calcMaxRateEnableRules = {
            commonConditionRules = {
              modEnvData = {
                sourceId = '3052',
                modDatas = {
                  {
                    k = 'hasTimeLimiteBuff',
                    v = true,
                  },
                },
              },
              passLevelState = {
                'Pass',
              },
            },
          },
          additionKey = 'timeLimit',
          addValue = 2,
        },
        {
          triggerScene = {
            'StartLevel',
            'StarChanged',
            'EndLevel',
          },
          enableRules = {
            commonConditionRules = {
              levelModeTypes = {
                2,
              },
              levelOldStars = {
                0,
                1,
              },
              curLevelStars = {
                2,
              },
              passLevelState = {
                'Pass',
              },
            },
          },
          calcMaxRateEnableRules = {
            commonConditionRules = {
              levelModeTypes = {
                2,
              },
            },
          },
          additionKey = 'refreshStar',
          addValue = 2,
        },
        {
          triggerScene = {
            'StartLevel',
            'StarChanged',
            'EndLevel',
          },
          enableRules = {
            commonConditionRules = {
              levelModeTypes = {
                2,
              },
              levelOldStars = {
                0,
                1,
                2,
              },
              curLevelStars = {
                3,
              },
              passLevelState = {
                'Pass',
              },
            },
          },
          calcMaxRateEnableRules = {
            commonConditionRules = {
              levelModeTypes = {
                2,
              },
              levelOldStars = {
                0,
                1,
                2,
              },
            },
          },
          additionKey = 'refreshThreeStar',
          addValue = 3,
        },
        {
          triggerScene = {
            'StartLevel',
            'StarChanged',
            'EndLevel',
          },
          enableRules = {
            commonConditionRules = {
              levelModeTypes = {
                2,
              },
              levelOldStars = {
                0,
                1,
                2,
                3,
              },
              curLevelStars = {
                4,
              },
              passLevelState = {
                'Pass',
              },
            },
          },
          calcMaxRateEnableRules = {
            commonConditionRules = {
              levelModeTypes = {
                2,
              },
              levelOldStars = {
                0,
                1,
                2,
                3,
              },
            },
          },
          additionKey = 'refreshColourStar',
          addValue = 5,
        },
        {
          triggerScene = {
            'StartLevel',
            'EndLevel',
          },
          enableRules = {
            commonConditionRules = {
              levelModeTypes = {
                5,
              },
            },
          },
          calcMaxRateEnableRules = {
            commonConditionRules = {
              levelModeTypes = {
                5,
              },
            },
          },
          additionKey = 'fsllPassLevel',
          addValue = 5,
        },
      },
      outBoardProductRules = {
        {
          triggerScene = {
            'StartLevel',
          },
          enableRules = {
            customConditionGroupReference = {
              0,
            },
          },
          productCount = {
            fieldName = 'baseCollectCount',
          },
        },
      },
      inBoardProductRules = {
        {
          triggerScene = {
            'ItemDestroy',
          },
          itemType = {
            'Animal',
          },
          itemColorType = {
            5,
          },
          specialType = {},
          productCount = 1,
          productCountMax = {
            fieldName = 'maxCollect',
          },
        },
      },
    },
    {
      desc = '横竖消',
      collectionId = '7',
      enableRules = {
        customConditionGroupReference = {
          1,
        },
      },
      additionRules = {
        {
          triggerScene = {
            'StartLevel',
            'EndLevel',
          },
          enableRules = {
            commonConditionRules = {
              isFirstPlayLevel = true,
              passLevelState = {
                'Pass',
              },
            },
          },
          calcMaxRateEnableRules = {
            commonConditionRules = {
              isFirstPlayLevel = true,
            },
          },
          additionKey = 'firstPlay',
          addValue = 2,
        },
        {
          triggerScene = {
            'StartLevel',
            'EndLevel',
          },
          enableRules = {
            commonConditionRules = {
              modEnvData = {
                sourceId = '3052',
                modDatas = {
                  {
                    k = 'hasTimeLimiteBuff',
                    v = true,
                  },
                },
              },
              passLevelState = {
                'Pass',
              },
            },
          },
          calcMaxRateEnableRules = {
            commonConditionRules = {
              modEnvData = {
                sourceId = '3052',
                modDatas = {
                  {
                    k = 'hasTimeLimiteBuff',
                    v = true,
                  },
                },
              },
              passLevelState = {
                'Pass',
              },
            },
          },
          additionKey = 'timeLimit',
          addValue = 2,
        },
        {
          triggerScene = {
            'StartLevel',
            'StarChanged',
            'EndLevel',
          },
          enableRules = {
            commonConditionRules = {
              levelModeTypes = {
                2,
              },
              levelOldStars = {
                0,
                1,
              },
              curLevelStars = {
                2,
              },
              passLevelState = {
                'Pass',
              },
            },
          },
          calcMaxRateEnableRules = {
            commonConditionRules = {
              levelModeTypes = {
                2,
              },
            },
          },
          additionKey = 'refreshStar',
          addValue = 2,
        },
        {
          triggerScene = {
            'StartLevel',
            'StarChanged',
            'EndLevel',
          },
          enableRules = {
            commonConditionRules = {
              levelModeTypes = {
                2,
              },
              levelOldStars = {
                0,
                1,
                2,
              },
              curLevelStars = {
                3,
              },
              passLevelState = {
                'Pass',
              },
            },
          },
          calcMaxRateEnableRules = {
            commonConditionRules = {
              levelModeTypes = {
                2,
              },
              levelOldStars = {
                0,
                1,
                2,
              },
            },
          },
          additionKey = 'refreshThreeStar',
          addValue = 3,
        },
        {
          triggerScene = {
            'StartLevel',
            'StarChanged',
            'EndLevel',
          },
          enableRules = {
            commonConditionRules = {
              levelModeTypes = {
                2,
              },
              levelOldStars = {
                0,
                1,
                2,
                3,
              },
              curLevelStars = {
                4,
              },
              passLevelState = {
                'Pass',
              },
            },
          },
          calcMaxRateEnableRules = {
            commonConditionRules = {
              levelModeTypes = {
                2,
              },
              levelOldStars = {
                0,
                1,
                2,
                3,
              },
            },
          },
          additionKey = 'refreshColourStar',
          addValue = 5,
        },
        {
          triggerScene = {
            'StartLevel',
            'EndLevel',
          },
          enableRules = {
            commonConditionRules = {
              levelModeTypes = {
                5,
              },
            },
          },
          calcMaxRateEnableRules = {
            commonConditionRules = {
              levelModeTypes = {
                5,
              },
            },
          },
          additionKey = 'fsllPassLevel',
          addValue = 5,
        },
      },
      outBoardProductRules = {
        {
          triggerScene = {
            'StartLevel',
          },
          enableRules = {
            customConditionGroupReference = {
              1,
            },
          },
          productCount = {
            fieldName = 'baseCollectCount',
          },
        },
      },
      inBoardProductRules = {
        {
          triggerScene = {
            'ItemDestroy',
          },
          itemType = {
            'Animal',
          },
          itemColorType = {},
          specialType = {
            2,
            3,
          },
          productCount = 1,
          productCountMax = {
            fieldName = 'maxCollect',
          },
        },
      },
    },
  },
  actItemConfigs = {
    {
      desc = '小狐狸',
      dataSource = 'collection',
      containCollectionIds = {
        0,
      },
      iconViewList = {
        {
          viewConfig = 0,
        },
      },
    },
    {
      desc = '横竖消',
      dataSource = 'collection',
      containCollectionIds = {
        1,
      },
      iconViewList = {
        {
          viewConfig = 1,
        },
      },
    },
  },
  customConditionGroupList = {
    {
      desc = '收集小狐狸条件',
      conditionGroup = {
        op = 'and',
        groups = {
          {
            commonConditionRules = {
              isHelping = false,
              modEnvData = {
                sourceId = '3052',
                modDatas = {
                  {
                    k = 'collectEnabled',
                    v = true,
                  },
                  {
                    k = 'collectType',
                    v = 2,
                  },
                },
              },
            },
          },
        },
      },
    },
    {
      desc = '收集横竖消条件',
      conditionGroup = {
        op = 'and',
        groups = {
          {
            commonConditionRules = {
              isHelping = false,
              modEnvData = {
                sourceId = '3052',
                modDatas = {
                  {
                    k = 'collectEnabled',
                    v = true,
                  },
                  {
                    k = 'collectType',
                    v = 1,
                  },
                },
              },
            },
          },
        },
      },
    },
  },
  ubfItemStaticConfig = {
    {
      itemType = 'PromotionEvent',
      isActCore = true,
      isSkin = false,
      priority = 0,
    },
  },
  addFiveStepConfig = {
    iconConfig = {
      {
        iconName = 0,
        displayPriority = 10014,
        touchTipText = '闯关晋级赛',
        panelText = '现在退出会失去大量收集物',
        appearInContent = {
          5,
          9,
        },
        iconTopLabelTypes = {
          1,
          4,
          5,
        },
      },
      {
        iconName = 1,
        displayPriority = 10014,
        touchTipText = '闯关晋级赛',
        panelText = '现在退出会失去大量收集物',
        appearInContent = {
          5,
          9,
        },
        iconTopLabelTypes = {
          1,
          4,
          5,
        },
      },
    },
  },
}