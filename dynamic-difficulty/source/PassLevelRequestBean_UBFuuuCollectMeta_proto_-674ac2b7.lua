return {
    schema = [[
message PassLevelRequestBean_UBFuuuCollectMeta {  
  int32 preAddSteps = 1;
  int32 addSteps = 2;
  int32 moveCount = 3;
  int32 staticMoveCount = 4;
  int32 diffFix = 5;
  int32 payTag = 6;
  int32 actTag = 7;
  string levelKey = 8;
  int32 stepFix = 9;
  bool stepFixCollect = 10;
  int32 diffMoveN0 = 11;
  int32 diffMoveN3 = 12;
  double stepMoveN0 = 13;
  double stepMoveN3 = 14;
}
    ]],
    libs = {}
}