return {
    schema = [[
message UbfuuCheckResult {  
  bool ubfuuuAdjustSelectEnable = 1;
  int32 cfgGroup = 2;
  map<string, string> configGroup = 3;
  map<string, bool> modGroup = 4;
  int32 maxLevelId = 5;
  int32 topRangeLength = 6;
  int32 secTopRangeLength = 7;
  int32 difFix = 8;
  float desiredDiffAvg = 9;
  float fixedDesiredDiffAvg = 10;
  float desiredDiffAvgFix = 11;
  int32 diffIndexV1 = 12;
  int32 diffIndex1V1 = 13;
  int32 diffIndex2V1 = 14;
  int32 diffIndex3V1 = 15;
  int32 topLevelFailCount = 16;
  int32 prevLogicDiffIndex = 17;
  bool toplevelBaoDiFlag = 18;
  int32 baodiDiffAvg = 19;
  int32 todayPassLevelCount = 20;
  int32 playCount3 = 21;
  int32 playCount7 = 22;
  int32 playCount30 = 23;
  int32 todayPlayCount = 24;
  float fixedPlayCount = 25;
  int32 loginDayCount28 = 26;
  int32 activityIndex = 27;
  int32 activityIndex2 = 28;
  int32 activityIndex1 = 29;
  int32 addStep2 = 30;
  int32 addStep5 = 31;
  int32 addStep2Video = 32;
  float fixedAddStepCount = 33;
  int32 paymentIndex = 34;
  int32 playerAbility = 35;
  int64 userCreateTime = 36;
  int32 userCreateDays = 37;
  int32 loginDayCount7 = 38;
  float fixedPlayCount1 = 39;
  UbfuuuAdjustFixInfo adjustFixInfo = 40;
  float desiredDiffAvgFix1 = 41;
  float desiredDiffAvgFix2 = 42;
  float diffIndex = 43;
  float diffIndex1 = 44;
  float diffIndex2 = 45;
  float diffIndex3 = 46;
  float diffAvgByDiffFix = 47;
  int32 activityIndex3 = 48;
  int32 paymentIndex1 = 49;
}
    ]],
    libs = {
		"UbfuuuAdjustFixInfo"
	}
}