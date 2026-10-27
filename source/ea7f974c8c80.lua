local mgr = _G.NewbieGiftOptimizeMgr:getInstance()
local mainInfo = {}

-- 助力礼包
local assistInfo = {
    id = mgr.GIFT_TYPE.ASSIST,
    endTime = TimeKit:timeInMillis() + 1000000,
    strongPushCdH = 6,
    strongPushConditionList = {2,3,4},


    giftPackMetaBeanList = {
        {
            goodsId = 3233,
            limitBuyTimes = 1,
            specialValue1 = "true", -- 是否是特殊包装
            specialValue2 = "assist",-- 礼包类型
        },
        {
            goodsId = 3234,
            limitBuyTimes = 1,
            specialValue1 = "false",
            specialValue2 = "anchor",
        },

    },
    gotGiftPackTimesMap = {},
}

-- 无限加五步礼包
local add5StepInfo = {
    id = mgr.GIFT_TYPE.INFADD5STEP,
    endTime = TimeKit:timeInMillis() + 1000000,
    strongPushCdH = 6,
    strongPushConditionList = {2,3,4},

    giftPackMetaBeanList = {
        {
            goodsId = 3235,
            limitBuyTimes = 1,
            specialValue1 = "true", -- 是否是特殊包装
            specialValue2 = "",
        },

    },
    gotGiftPackTimesMap = {},
}

-- 三选一礼包
local threeForOneInfo = {
    id = mgr.GIFT_TYPE.THREEFORONE,
    endTime = TimeKit:timeInMillis() + 1000000,
    strongPushCdH = 6,
    strongPushConditionList = {2,3,4},


    giftPackMetaBeanList = {
        {
            goodsId = 3236,
            limitBuyTimes = 1,
            specialValue1 = "超换算", -- 礼包属性
            specialValue2 = "",
        },
        {
            goodsId = 3237,
            limitBuyTimes = 1,
            specialValue1 = "一般", -- 礼包属性
            specialValue2 = "",
        },
        {
            goodsId = 3238,
            limitBuyTimes = 1,
            specialValue1 = "有点一般", -- 礼包属性
            specialValue2 = "",
        },
        {
            goodsId = 3239,
            limitBuyTimes = 1,
            specialValue1 = "", -- 礼包属性
            specialValue2 = "",
        },

    },
    gotGiftPackTimesMap = {},
}

-- 越买越香礼包
local continueBuyInfo = {
    id = mgr.GIFT_TYPE.CONTINUEBUY,
    endTime = TimeKit:timeInMillis() + 1000000,
    strongPushCdH = 6,
    strongPushConditionList = {2,3,4},


    giftPackMetaBeanList = {
        {
            goodsId = 3240,
            limitBuyTimes = 1,
            specialValue1 = "超换算", -- 折扣标签
            specialValue2 = "",
        },
        {
            goodsId = 3241,
            limitBuyTimes = 1,
            specialValue1 = "一般",
            specialValue2 = "",
        },
        {
            goodsId = 3242,
            limitBuyTimes = 1,
            specialValue1 = "有点一般",
            specialValue2 = "",
        },

    },
    gotGiftPackTimesMap = {},
}

local buyAndFreeInfo = {
    id = mgr.GIFT_TYPE.BUYANDFREE,
    endTime = TimeKit:timeInMillis() + 1000000,
    strongPushCdH = 6,
    strongPushConditionList = {2,3,4},

    fixRewardNodeList = {
        {
            freeNode = true,
            rewardList = {
				{itemId = 14, num = 1},
			},
			goodsId = 0,
        },
        {
            freeNode = true,
			rewardList = {
				{itemId = 10098, num = 2},
				{itemId = 10098, num = 2},
				{itemId = 10098, num = 2},
                {itemId = 10098, num = 2},
			},
			goodsId = 0,
        },
        {
            freeNode = false,
			rewardList = {
				{itemId = 10098, num = 3},
				{itemId = 10098, num = 3},
			},
			goodsId = 640,
        },
    },

    loopRewardNodeList = {
        -- {
		-- 	freeNode = true,
		-- 	rewardList = {
		-- 		{itemId = 10098, num = 4},
		-- 	},
		-- 	goodsId = 0,
		-- },
		-- {
		-- 	freeNode = true,
		-- 	rewardList = {
		-- 		{itemId = 2, num = 5},
		-- 		{itemId = 10098, num = 5},
		-- 		{itemId = 10098, num = 5},
		-- 	},
		-- 	goodsId = 0,
		-- },
		-- {
		-- 	freeNode = true,
		-- 	rewardList = {
		-- 		{itemId = 14, num = 6},
		-- 		{itemId = 10098, num = 6},
		-- 		{itemId = 10098, num = 6},
		-- 	},
		-- 	goodsId = 0,
		-- },
        -- {
		-- 	freeNode = true,
		-- 	rewardList = {
		-- 		{itemId = 10004, num = 7},
		-- 		{itemId = 10098, num = 7},
		-- 		{itemId = 10098, num = 7},
		-- 	},
		-- 	goodsId = 0,
		-- },
    },

    gotRewardNodeIndex = 0,
}

local giftPackActivityInfoList = {}
table.insert(giftPackActivityInfoList, assistInfo)
table.insert(giftPackActivityInfoList, add5StepInfo)
table.insert(giftPackActivityInfoList, threeForOneInfo)
table.insert(giftPackActivityInfoList, continueBuyInfo)
table.insert(giftPackActivityInfoList, buyAndFreeInfo)

local config = {
    strongPushTable = {
        {
            conditionId = 1,
            conditionValue = 1,
            sceneId = 2,
            priority = 0,
        },
        {
            conditionId = 2,
            conditionValue = 1,
            sceneId = 2,
            priority = 0,
        },
        {
            conditionId = 3,
            conditionValue = 1,
            sceneId = 2,
            priority = 0,
        },
        {
            conditionId = 4,
            conditionValue = 1,
            sceneId = 2,
            priority = 0,
        },
    }
}

mainInfo = {
    giftPackActivityInfoList = giftPackActivityInfoList,
    serverVersionedConfig = {
        serverMd5 = "123456",
        config = table.serialize(config)
    }
}
return mainInfo