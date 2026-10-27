return {
  collectItemGlobal = {
    additionKeyEnum = {
      {
        desc = '限时加成',
        value = 'timeLimit',
      },
      {
        desc = '首次闯关',
        value = 'firstPlay',
      },
      {
        desc = '活动关',
        value = 'actLevel',
      },
      {
        desc = '连胜加成',
        value = 'winningStreak',
      },
      {
        desc = '主线难关',
        value = 'main_diffcult',
      },
      {
        desc = '主线超难关',
        value = 'main_exceedinglyDifficult',
      },
      {
        desc = 'top关过关',
        value = 'top_passLevel',
      },
      {
        desc = 'top关三星',
        value = 'top_threeStar',
      },
      {
        desc = 'top关彩星',
        value = 'top_colourStar',
      },
      {
        desc = '补星成功',
        value = 'refreshStar',
      },
      {
        desc = '补三星',
        value = 'refreshThreeStar',
      },
      {
        desc = '补彩星',
        value = 'refreshColourStar',
      },
      {
        desc = '刷分成功',
        value = 'refreshScoreSuccess',
      },
      {
        desc = '刷分失败',
        value = 'refreshScoreFail',
      },
      {
        desc = '关卡库',
        value = 'fsllPassLevel',
      },
      {
        desc = '关卡库难关',
        value = 'fsll_diffcult',
      },
    },
    additionRuleList = {
      {
        ruleKey = 'Top',
        enableRules = {
          commonConditionRules = {
            levelModeTypes = {
              1,
            },
          },
        },
        calculateRules = {
          additionKeys = {
            {
              additionKeys = {
                'timeLimit',
                'firstPlay',
                'winningStreak',
              },
              op = 'Multiplication',
            },
            {
              additionKeys = {
                'main_diffcult',
                'main_exceedinglyDifficult',
              },
              op = 'MutualExclusion',
            },
            {
              additionKeys = {
                'top_passLevel',
                'top_threeStar',
                'top_colourStar',
              },
              op = 'Max',
            },
          },
          op = 'Multiplication',
        },
        otherAdditionCalculateOp = 'Multiplication',
        finalAdditionCalculateOp = 'Multiplication',
      },
      {
        ruleKey = 'FarmStar',
        enableRules = {
          commonConditionRules = {
            levelModeTypes = {
              2,
            },
          },
        },
        calculateRules = {
          additionKeys = {
            {
              additionKeys = {
                'timeLimit',
                'firstPlay',
                'winningStreak',
              },
              op = 'Multiplication',
            },
            {
              additionKeys = {
                'main_diffcult',
                'main_exceedinglyDifficult',
              },
              op = 'MutualExclusion',
            },
            {
              additionKeys = {
                'refreshStar',
                'refreshThreeStar',
                'refreshColourStar',
              },
              op = 'Max',
            },
          },
          op = 'Multiplication',
        },
        otherAdditionCalculateOp = 'Multiplication',
        finalAdditionCalculateOp = 'Multiplication',
      },
      {
        ruleKey = 'FarmScore',
        enableRules = {
          commonConditionRules = {
            levelModeTypes = {
              3,
            },
          },
        },
        calculateRules = {
          additionKeys = {
            {
              additionKeys = {
                'timeLimit',
                'firstPlay',
                'winningStreak',
              },
              op = 'Multiplication',
            },
            {
              additionKeys = {
                'main_diffcult',
                'main_exceedinglyDifficult',
              },
              op = 'MutualExclusion',
            },
            {
              additionKeys = {
                'refreshScoreSuccess',
                'refreshScoreFail',
              },
              op = 'Max',
            },
          },
          op = 'Multiplication',
        },
        otherAdditionCalculateOp = 'Multiplication',
        finalAdditionCalculateOp = 'Multiplication',
      },
      {
        ruleKey = 'FullStarLevelLibrary',
        enableRules = {
          commonConditionRules = {
            levelModeTypes = {
              5,
            },
          },
        },
        calculateRules = {
          additionKeys = {
            {
              additionKeys = {
                'timeLimit',
                'firstPlay',
                'winningStreak',
              },
              op = 'Multiplication',
            },
            {
              additionKeys = {
                'fsllPassLevel',
                'fsll_diffcult',
              },
              op = 'Multiplication',
            },
          },
          op = 'Multiplication',
        },
        otherAdditionCalculateOp = 'Multiplication',
        finalAdditionCalculateOp = 'Multiplication',
      },
      {
        ruleKey = 'ActLevel',
        enableRules = {
          commonConditionRules = {
            levelModeTypes = {
              4,
            },
          },
        },
        calculateRules = {
          additionKeys = {
            {
              additionKeys = {
                'timeLimit',
                'firstPlay',
                'winningStreak',
              },
              op = 'Multiplication',
            },
            {
              additionKeys = {
                'actLevel',
              },
              op = 'Multiplication',
            },
          },
          op = 'Multiplication',
        },
        otherAdditionCalculateOp = 'Multiplication',
        finalAdditionCalculateOp = 'Multiplication',
      },
      {
        ruleKey = 'Default',
        calculateRules = {
          additionKeys = {
            {
              additionKeys = {
                'timeLimit',
                'firstPlay',
                'winningStreak',
              },
              op = 'Multiplication',
            },
            {
              additionKeys = {
                'actLevel',
              },
              op = 'Multiplication',
            },
            {
              additionKeys = {
                'fsllPassLevel',
                'fsll_diffcult',
              },
              op = 'Multiplication',
            },
            {
              additionKeys = {
                'main_diffcult',
                'main_exceedinglyDifficult',
              },
              op = 'MutualExclusion',
            },
            {
              additionKeys = {
                'top_passLevel',
                'top_threeStar',
                'top_colourStar',
              },
              op = 'Max',
            },
            {
              additionKeys = {
                'refreshStar',
                'refreshThreeStar',
                'refreshColourStar',
              },
              op = 'Max',
            },
            {
              additionKeys = {
                'refreshScoreSuccess',
                'refreshScoreFail',
              },
              op = 'Max',
            },
          },
          op = 'Multiplication',
        },
        otherAdditionCalculateOp = 'Multiplication',
        finalAdditionCalculateOp = 'Multiplication',
      },
    },
  },
  ubfAFPriorityGlobal = {
    actPriorityTagConfig = {
      {
        desc = '默认优先级占位',
        priorityKey = 'default',
      },
      {
        desc = '晋级赛',
        priorityKey = 'PromotionEvent',
      },
      {
        desc = '春田合合',
        priorityKey = 'mergeevolution',
      },
      {
        desc = '礼物大放送',
        priorityKey = 'biggiveaway',
      },
      {
        desc = '爆破冠军赛',
        priorityKey = 'boomMatch',
      },
      {
        desc = '露营吧!朋友',
        priorityKey = 'teamBuilding',
      },
      {
        desc = '星光之域',
        priorityKey = 'stellarConvergence',
      },
      {
        desc = '挖宝石',
        priorityKey = 'gemMining',
      },
      {
        desc = '美味合合',
        priorityKey = 'mergeAct2024',
      },
      {
        desc = '方块消消',
        priorityKey = 'blockAct',
      },
      {
        desc = '钓鱼大赢家',
        priorityKey = 'fishingwinner',
      },
      {
        desc = '魔力冲冲冲',
        priorityKey = 'magicRush',
      },
      {
        desc = '礼包_精力不足1',
        priorityKey = 'giftPack_noEnergy_1',
      },
      {
        desc = '礼包_精力不足2',
        priorityKey = 'giftPack_noEnergy_2',
      },
      {
        desc = '礼包_重试多次1',
        priorityKey = 'giftPack_retry_1',
      },
      {
        desc = '礼包_重试多次2',
        priorityKey = 'giftPack_retry_2',
      },
      {
        desc = '礼包_难关1',
        priorityKey = 'giftPack_hardLevel_1',
      },
      {
        desc = '礼包_难关2',
        priorityKey = 'giftPack_hardLevel_2',
      },
      {
        desc = '未参与',
        priorityKey = 'notJoined',
      },
      {
        desc = '礼包_回归礼包基础',
        priorityKey = 'returnPack_base_1',
      },
    },
    slpTagPriority = {
      'default',
    },
    collectionBarPriority = {
      'PromotionEvent',
      'magicRush',
      'teamBuilding',
      'mergeevolution',
      'biggiveaway',
      'mergeAct2024',
      'boomMatch',
      'stellarConvergence',
      'gemMining',
      'blockAct',
      'fishingwinner',
      'default',
    },
    addFivestepPanelPriority = {},
    slpBottomPanelPriorityConfig = {
      giftPriorityGroup = {
        {
          sourceId = 'GiftPack',
          entryTag = 'returnPack_base_1',
        },
      },
      activeActPriorityGroup = {
        {
          sourceId = '4062',
          entryTag = 'default',
        },
        {
          sourceId = '4042',
          entryTag = 'default',
        },
        {
          sourceId = '9084',
          entryTag = 'default',
        },
        {
          sourceId = '9079',
          entryTag = 'default',
        },
      },
      passiveActPriorityGroup = {
        {
          sourceId = '4046',
          entryTag = 'default',
        },
      },
      systemPriorityGroup = {
        {
          sourceId = '-2',
          entryTag = 'default',
        },
      },
    },
    plpBottomPanelPriorityConfig = {
      giftPriorityGroup = {},
      activeActPriorityGroup = {
        {
          sourceId = '4062',
          entryTag = 'default',
        },
        {
          sourceId = '4042',
          entryTag = 'default',
        },
        {
          sourceId = '9084',
          entryTag = 'default',
        },
        {
          sourceId = '9079',
          entryTag = 'default',
        },
      },
      passiveActPriorityGroup = {
        {
          sourceId = '4046',
          entryTag = 'default',
        },
      },
      systemPriorityGroup = {
        {
          sourceId = '-2',
          entryTag = 'default',
        },
      },
    },
    modEventPriority = {
      defaultPriority = {
        '10178',
        '5312',
        '10179',
        'DefaultMod',
        '9088',
        '8068',
        'guide',
        'ModCondition',
        'DiffAdjustModMgr',
        'SuperMagicBirdBaodiFix',
        'SuperMagicBirdThrower',
      },
      eventPriorities = {
        {
          eventName = 'PrepareSlp',
          entries = {
            {
              sourceId = 'PreProp',
            },
            {
              sourceId = 'GiftPack',
              funcName = 'onPrepareSlp',
            },
            {
              sourceId = 'LevelMilestone',
              funcName = 'onPrepareSlp',
            },
            {
              sourceId = '5312',
              funcName = 'onPrepareSlp',
            },
            {
              sourceId = '8068',
              funcName = 'onPrepareSlp',
            },
            {
              sourceId = '8079',
              funcName = 'onPrepareSlp',
            },
            {
              sourceId = '8055',
              funcName = 'onPrepareSlp',
            },
            {
              sourceId = '3052',
              funcName = 'onPrepareSlp',
            },
            {
              sourceId = 'CommonMod',
              funcName = 'onPrepareSlp',
            },
            {
              sourceId = 'LevelRank',
              funcName = 'onPrepareSlp',
            },
            {
              sourceId = 'StarBottle',
              funcName = 'onPrepareSlp',
            },
          },
        },
        {
          eventName = 'PrepareSlpBottom',
          entries = {
            {
              sourceId = '9084',
              funcName = 'onPrepareSlpBottom_HighPriority',
              groupId = 'Act',
            },
            {
              sourceId = '9079',
              funcName = 'onPrepareSlpBottom_HighPriority',
              groupId = 'Act',
            },
            {
              sourceId = '9075',
              funcName = 'onPrepareSlpBottom_HighPriority',
              groupId = 'Act',
            },
            {
              sourceId = 'GiftPack',
              funcName = 'onPrepareSlpBottom',
              groupId = 'Act',
            },
            {
              sourceId = '4062',
              funcName = 'onPrepareSlpBottom_HighPriority',
              groupId = 'Act',
            },
            {
              sourceId = '4042',
              funcName = 'onPrepareSlpBottom',
              groupId = 'Act',
            },
            {
              sourceId = '9084',
              funcName = 'onPrepareSlpBottom_LowPriority',
              groupId = 'Act',
            },
            {
              sourceId = '-2',
              funcName = 'onPrepareSlpBottom_Trophy_High',
              groupId = 'Act',
            },
            {
              sourceId = '9075',
              funcName = 'onPrepareSlpBottom_LowPriority',
              groupId = 'Act',
            },
            {
              sourceId = '9079',
              funcName = 'onPrepareSlpBottom_LowPriority',
              groupId = 'Act',
            },
            {
              sourceId = '4062',
              funcName = 'onPrepareSlpBottom_LowPriority',
              groupId = 'Act',
            },
            {
              sourceId = '-2',
              funcName = 'onPrepareSlpBottom_Trophy',
              groupId = 'Act',
            },
            {
              sourceId = 'LevelRank',
              funcName = 'onPrepareSlpBottom_LevelRank',
              groupId = 'Act',
            },
            {
              sourceId = 'LevelMilestone',
              funcName = 'onPrepareSlpBottom',
            },
          },
        },
        {
          eventName = 'PrepareSlpTop',
          entries = {
            {
              sourceId = '3052',
              funcName = 'onPrepareSlpTop_PromotionTop',
            },
          },
        },
        {
          eventName = 'PrepareSlpTag',
          entries = {
            {
              sourceId = 'CommonMod',
              funcName = 'onPrepareSlpTag',
            },
            {
              isDefaultPlaceholder = true,
            },
            {
              sourceId = '5312',
              funcName = 'onPrepareSlpTag',
            },
            {
              sourceId = 'ScoreBuff',
              funcName = 'onPrepareSlpTag',
            },
          },
        },
        {
          eventName = 'PrepareSlpRightUpper',
          entries = {
            {
              sourceId = '8068',
              funcName = 'onPrepareSlpRightUpper',
            },
          },
        },
        {
          eventName = 'PrepareSlpLeftBottom',
          entries = {
            {
              sourceId = '5053',
              funcName = 'onPrepareSlpLeftBottomHigh',
              groupId = 'Act',
            },
            {
              sourceId = 'JumpLevel',
              funcName = 'onPrepareSlpLeftBottom',
              groupId = 'Act',
            },
            {
              sourceId = '5053',
              funcName = 'onPrepareSlpLeftBottomNormal',
              groupId = 'Act',
            },
            {
              sourceId = '9502',
              funcName = 'onPrepareSlpLeftBottom',
              groupId = 'Act',
            },
            {
              sourceId = '4042',
              funcName = 'onPrepareSlpLeftBottom',
              groupId = 'Act',
            },
          },
        },
        {
          eventName = 'PrepareSlpSubtitle',
          entries = {
            {
              sourceId = 'JumpLevel',
              funcName = 'onPrepareSlpSubtitle',
              groupId = 'Act',
            },
            {
              sourceId = '8055',
              funcName = 'onPrepareSlpSubtitle',
              groupId = 'Act',
            },
            {
              sourceId = '5305',
              funcName = 'onPrepareSlpSubtitle',
              groupId = 'Act',
            },
          },
        },
        {
          eventName = 'PrepareSlpRightBottom',
          entries = {
            {
              sourceId = 'StarBottle',
              funcName = 'onPrepareSlpRightBottom',
              groupId = 'Act',
            },
            {
              sourceId = '5301',
              funcName = 'onPrepareSlpRightBottom',
              groupId = 'Act',
            },
          },
        },
        {
          eventName = 'PrepareSlpEnterActions',
          entries = {
            {
              sourceId = '8068',
              funcName = 'onPrepareSlpEnterActions',
            },
            {
              sourceId = '8079',
              funcName = 'onPrepareSlpEnterActions',
            },
            {
              sourceId = '5312',
              funcName = 'onPrepareSlpEnterActions',
            },
            {
              sourceId = '4042',
              funcName = 'onPrepareSlpEnterActions',
            },
            {
              sourceId = '5311',
              funcName = 'onPrepareSlpEnterActions',
            },
            {
              sourceId = 'JumpLevel',
              funcName = 'onPrepareSlpEnterActions_GuideJumpLevelWithPods',
            },
            {
              sourceId = 'JumpLevel',
              funcName = 'onPrepareSlpEnterActions_GuideJumpLevelAFH',
            },
            {
              sourceId = 'Energy',
              funcName = 'onPrepareSlpEnterActions_GuideEnergyBottle',
            },
            {
              sourceId = 'PreProp',
              funcName = 'onPrepareSlpEnterActions_GuideBoomAndLine',
            },
            {
              sourceId = 'PreProp',
              funcName = 'onPrepareSlpEnterActions_GuideInfinitePreProp',
            },
            {
              sourceId = 'StarBottle',
              funcName = 'onPrepareSlpEnterActions',
            },
          },
        },
        {
          eventName = 'CustomBonusTime',
          entries = {
            {
              sourceId = 'CommonMod',
            },
            {
              isDefaultPlaceholder = true,
            },
          },
        },
        {
          eventName = 'PreparePlCollection',
          entries = {
            {
              sourceId = '5312',
              funcName = 'onPreparePlCollection',
              useInst = true,
            },
          },
        },
        {
          eventName = 'PrepareWinningActsBanner',
          entries = {
            {
              sourceId = '-2',
            },
            {
              sourceId = '4046',
            },
          },
        },
        {
          eventName = 'AfterSendPassLevel',
          entries = {
            {
              isDefaultPlaceholder = true,
            },
          },
        },
        {
          eventName = 'PreparePlp',
          entries = {
            {
              sourceId = '5312',
              funcName = 'onPreparePlp',
              useInst = true,
            },
            {
              sourceId = 'LevelMilestone',
              funcName = 'onPreparePlp',
            },
            {
              sourceId = 'LevelRank',
              funcName = 'onPreparePlp',
            },
            {
              sourceId = 'RecommendLevel',
              funcName = 'onPreparePlp',
              useInst = true,
            },
            {
              sourceId = '5305',
              funcName = 'onPreparePlp',
            },
            {
              sourceId = '8055',
              funcName = 'onPreparePlp',
            },
            {
              sourceId = 'FirstPlay',
              funcName = 'onPreparePlp',
            },
          },
        },
        {
          eventName = 'PreparePlpBottom',
          entries = {
            {
              sourceId = '-2',
              funcName = 'onPreparePlpBottom_Trophy_High',
              groupId = 'Act',
              useInst = true,
            },
            {
              sourceId = '9084',
              funcName = 'onPreparePlpBottom_HighPriority',
              groupId = 'Act',
            },
            {
              sourceId = '4062',
              funcName = 'onPreparePlpBottom',
              groupId = 'Act',
            },
            {
              sourceId = '4046',
              groupId = 'Act',
            },
            {
              sourceId = '4042',
              funcName = 'onPreparePlpBottom',
              groupId = 'Act',
            },
            {
              sourceId = '5053',
              funcName = 'onPreparePlpBottom_FixBirdNest',
              groupId = 'Act',
              useInst = true,
            },
            {
              sourceId = '-2',
              funcName = 'onPreparePlpBottom_Trophy',
              groupId = 'Act',
              useInst = true,
            },
          },
        },
        {
          eventName = 'PreparePlpTop',
          entries = {
            {
              sourceId = '3052',
              funcName = 'onPreparePlpTop_PromotionTop',
            },
          },
        },
        {
          eventName = 'PreparePlpEnterActions',
          entries = {
            {
              sourceId = 'LevelMilestone',
              funcName = 'onPreparePlpEnterActions_Rewards',
            },
            {
              sourceId = 'LevelMilestone',
              funcName = 'onPreparePlpEnterActions_PromoPack',
            },
            {
              sourceId = 'GiftPack',
              funcName = 'onPreparePlpEnterActions',
            },
          },
        },
        {
          eventName = 'PreparePlRank',
          entries = {
            {
              sourceId = 'RecommendLevel',
              funcName = 'onPreparePlRank',
              useInst = true,
            },
            {
              sourceId = '5305',
              funcName = 'onPreparePlRank',
            },
            {
              sourceId = 'LevelMilestone',
              funcName = 'onPreparePlRank',
            },
          },
        },
        {
          eventName = 'get_data_UseBagPropData',
          entries = {
            {
              sourceId = 'PreProp',
            },
            {
              sourceId = 'StarBottle',
              funcName = 'onInsertUseBagPropData',
            },
            {
              sourceId = '5301',
              funcName = 'onInsertUseBagPropData',
            },
          },
        },
        {
          eventName = 'get_data_SelectedItemsData',
          entries = {
            {
              sourceId = 'PreProp',
            },
            {
              sourceId = 'StarBottle',
              funcName = 'onInsertSelectedItemsData',
            },
            {
              sourceId = '5301',
              funcName = 'onInsertSelectedItemsData',
            },
          },
        },
        {
          eventName = 'PrepareSlpBottomCarousel',
          entries = {
            {
              sourceId = 'CommonMod',
              funcName = 'onPrepareSlpBottomCarousel',
            },
            {
              sourceId = 'LevelRank',
              funcName = 'onPrepareSlpBottomCarousel',
            },
            {
              sourceId = 'GiftPack',
              funcName = 'onPrepareSlpBottomCarousel',
            },
          },
        },
        {
          eventName = 'PreparePlpBottomCarousel',
          entries = {
            {
              sourceId = 'CommonMod',
              funcName = 'onPreparePlpBottomCarousel',
            },
          },
        },
        {
          eventName = 'UBFAddFivePanelCheckNPCDialog',
          entries = {
            {
              sourceId = '8068',
              funcName = 'onUBFAddFivePanelCheckNPCDialog',
              groupId = 'Act',
            },
            {
              sourceId = 'Luckydelivery',
              funcName = 'onUBFAddFivePanelCheckNPCDialog',
              groupId = 'Act',
            },
            {
              sourceId = '-2',
              funcName = 'onUBFAddFivePanelCheckNPCDialog',
              groupId = 'Act',
            },
            {
              isDefaultPlaceholder = true,
            },
          },
        },
      },
    },
  },
}