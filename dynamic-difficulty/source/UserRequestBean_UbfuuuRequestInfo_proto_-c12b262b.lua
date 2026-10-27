return {
    schema = [[
message UserRequestBean_UbfuuuRequestInfo {  
  repeated string diffDsMapKeys = 1;
  map<string, string> configGroup = 2;
  int32 maxLevelId = 3;
  int32 topRangeLength = 4;
  int32 secTopRangeLength = 5;
}
    ]],
    libs = {}
}