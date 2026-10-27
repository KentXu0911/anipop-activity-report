return {
    schema = [[
message UserResponseBean_UbfuuuInfo {  
  UBFuuuGetNext30DiffFixDataResponseBean diffDsMap = 1;
  UBFGetLevelStatisticInfoResponseBean statisticInfo = 2;
}
    ]],
    libs = {
		"UBFGetLevelStatisticInfoResponseBean",
		"UBFuuuGetNext30DiffFixDataResponseBean"
	}
}