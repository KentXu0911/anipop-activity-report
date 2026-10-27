return {
    schema = [[
message PassLevelRequestBean {  
  int32 levelId = 1;
  int32 metaLevelId = 2;
  int32 score = 3;
  int32 star = 4;
  int32 stageTime = 5;
  int32 coin = 6;
  string targetCount = 7;
  string opLog = 8;
  int64 requestTime = 9;
  int64 lastEnterTime = 10;
  int32 activityFlag = 11;
  string curMd5 = 12;
  string curConfigMd5 = 13;
  string extra = 14;
  int32 step = 15;
  int32 staticSteps = 16;
  string version = 17;
  string cacheCode = 18;
  repeated ItemBean usedProps = 19;
  bool useSmallRes = 20;
  double seed = 21;
  bool hasLockedSeed = 22;
  int32 strategy = 23;
  string strategyReason = 24;
  FuuuAdjustContextBean clientFuuuAdjustContext = 25;
  bool hasUsedProp = 26;
  string levelMd5 = 27;
  int32 levelVersion = 28;
  string levelUniqueKey = 29;
  UbfuuCheckResult ubfuuCheckResult = 30;
  int32 levelMarkVersion = 31;
  int32 propGuideItem = 32;
  string virtualMode = 33;
  string strategyInfo = 34;
  repeated RewardBean extraRewards = 35;
  bool guideLevel = 36;
  int32 levelLeftMoves = 37;
  repeated TupleIntIntBean achievementValues = 38;
  bool giveUp = 39;
  string json = 40;
  PassLevelRequestBean_PInfo pinfo = 41;
  bool newFullStarArea = 42;
  repeated string orderIds = 43;
  string eventId = 44;
  bool logicalFail = 45;
  int32 hideLevelVersion = 46;
  int32 hasRealUseProp = 47;
  int32 difficultyFlag = 48;
  int32 oplogFlag = 49;
  string extraData = 50;
  int32 protocolVersion = 51;
  UbfMetaConfigBean metaConfig = 52;
  string levelScene = 53;
  PassLevelRequestBean_UBFuuuCollectMeta ubFuuuCollectMeta = 54;
  string alipayChannel = 55;
  repeated GroupExpLevelRequestBean groupExpLevelRequestList = 56;
  string clientStreakWinScene = 57;
}
    ]],
    libs = {
		"FuuuAdjustContextBean",
		"GroupExpLevelRequestBean",
		"ItemBean",
		"PassLevelRequestBean_PInfo",
		"PassLevelRequestBean_UBFuuuCollectMeta",
		"RewardBean",
		"TupleIntIntBean",
		"UbfMetaConfigBean",
		"UbfuuCheckResult"
	}
}