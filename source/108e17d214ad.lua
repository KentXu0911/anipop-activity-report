local testData = {}

testData.userData = {
	musicNum = 48,
	musicNumRewarded = 21,
	arenaDuan = 1,
	perRace = false,
	preWinNum = 3,
	rankMemberInfoList = {
		{
			id = 1,
			uid = 83000,
			avatarUrl = "",
			headFrame = HeadFrameType.kNormal,	
			encryptedName = "消消乐玩家",
			score = 11,
			timeOfArrival = 0,
			namePatternList = {},
		},
		{
			id = 1,
			uid = 79200,
			avatarUrl = "",
			headFrame = HeadFrameType.kNormal,
			encryptedName = "消消乐玩家",
			score = 10,
			timeOfArrival = '1000',
			namePatternList = {},
		}
	},
	guideFlagSet = {1,2,3},

	oldProgress = 0,
	haveBreak = false,
}

local config = {
	configVersion = 1,

	beginTime = Localhost:time(),
	mainEndTime = Localhost:time() + 100000,
	endTime = Localhost:time() + 100000,
	streakDoorsill = 3,
	clientVersionControl = 1,
	minClientVersion = "1.151",
	arenaLadderList = {
		{
			streakGoal = 11,
			upDuanRanl = 1,
			rankRewardViews = {
				{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				}
			}
		},
		{
			streakGoal = 11,
			upDuanRanl = 1,
			rankRewardViews = {
				{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				}
			}
		},
		{
			streakGoal = 11,
			upDuanRanl = 1,
			rankRewardViews = {
				{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				}
			}
		},
		{
			streakGoal = 11,
			upDuanRanl = 1,
			rankRewardViews = {
				{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				}
			}
		},
		{
			streakGoal = 11,
			upDuanRanl = 1,
			rankRewardViews = {
				{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				},{
					rewardlist = { {itemId = 2, num=100} },
					wCoinMax = 20
				}
			}
		}
	},
	progressRewardList = {
		{
			threshold = 10,
			wCoinMax = 10,
			rewardlist = { {itemId = 2, num=1} },
		},
		{
			threshold = 20,
			wCoinMax = 10,
			rewardlist = { {itemId = 2, num=2} },
		},
		{
			threshold = 30,
			wCoinMax = 10,
			rewardlist = { {itemId = 2, num=3} },
		},
		{
			threshold = 40,
			wCoinMax = 10,
			rewardlist = { {itemId = 2, num=100} },
		},
		{
			threshold = 60,
			wCoinMax = 10,
			rewardlist = { {itemId = 2, num=100} },
		},
		{
			threshold = 80,
			wCoinMax = 10,
			rewardlist = { {itemId = 2, num=100} },
		},
		{
			threshold = 100,
			wCoinMax = 10,
			rewardlist = { {itemId = 2, num=100} },
		},
		{
			threshold = 130,
			wCoinMax = 10,
			rewardlist = { {itemId = 2, num=100} },
		},
		{
			threshold = 150,
			wCoinMax = 10,
			rewardlist = { {itemId = 2, num=5}, {itemId = 14, num = 3} },
		},
		{
			threshold = 200,
			wCoinMax = 10,
			rewardlist = { 
				{itemId = 14, num=100},  {itemId = 2, num=100},  {itemId = 2, num=100},  {itemId = 2, num=100},   {itemId = 2, num=100},  
				{itemId = 2, num=100},  {itemId = 2, num=100},  {itemId = 2, num=100},  {itemId = 2, num=100},  {itemId = 2, num=100},  
			},
		}
	},
	preRaceRewardList =  { {itemId = 56023, num=1}, {itemId = 2, num=100} },

}

local serverVersionedConfig = {
	serverMd5 = 'asdasdas22423',
	config = table.serialize(config)
}
testData.serverVersionedConfig = serverVersionedConfig


return testData