return {
  ubfItemStaticConfig = {
    {
      itemType = 'FullLevelSlotMachineScoreBottle',
      isActCore = true,
      priority = 0,
      isSkin = false,
    },
  },
  actOpenConditionConfig = {
    path = 'ROOT/Animal/UBFGameScene/enableActivitys/act_10175',
    version = 2,
    __treeId = '1078',
  },
  scoreBarConfig = {
    scoreBarColorBlendConfig = {
      autoUpdate = true,
      blendID = 'fls',
      colorBlendData = {
        {
          mixLeft = 0.3,
          colorFile = 'tempFunctionResInLevel/Promotion/progressMask.png',
          colorBlendType = 2,
          colorID = 'fls5065',
          startPercent = '0',
          colorWidth = 0.3,
          endPercent = '0',
        },
      },
    },
  },
  releaseVersion = 0,
  modifyVersion = 11,
  constraintVer = 204,
  baseConfig = {
    ActivityCHName = '促满级补星加分瓶',
    ActivityName = 'FullLevelSlotMachineScoreBottle',
    isLimitColourStarMode = true,
    actMainManager = 'FullLevelSlotMachineMgr',
    isOpenExceedHightestStarMode = false,
    isOpenRefreshScoreStrictMode = false,
    featureId = '10175',
    mainMgrName = 'FullLevelSlotMachineScoreBottleActManager',
  },
}