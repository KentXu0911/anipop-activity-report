local Meta = {}
Meta.resPath = "amf/activity/newbiegiftoptimize/"
-- 礼包类型
Meta.GIFT_TYPE = {
    ASSIST = 1,            -- 最佳助力
    INFADD5STEP = 2,       -- 无限加五步
    THREEFORONE = 3,       -- 3选1
    CONTINUEBUY = 4,       -- 越买越香
    BUYANDFREE = 5,        -- 瀑布流
}

-- 礼包场景类型
Meta.GIFT_SCENE = {
    MAINPANEL = 1,
    STORE = 2,
    ADDSTEP = 3,
}

Meta.ACTNAME = {
    [Meta.GIFT_TYPE.ASSIST] = "最佳助力礼包",
    [Meta.GIFT_TYPE.INFADD5STEP] = "无限过关礼包",
    [Meta.GIFT_TYPE.THREEFORONE] = "挑选一个",
    [Meta.GIFT_TYPE.CONTINUEBUY] = "越买越香",
    [Meta.GIFT_TYPE.BUYANDFREE] = "敢买敢送",
}

Meta.ICONNAME = {
    [Meta.GIFT_TYPE.ASSIST] = "最佳助力礼包",
    [Meta.GIFT_TYPE.INFADD5STEP] = "无限冲关",
    [Meta.GIFT_TYPE.THREEFORONE] = "挑选一个",
    [Meta.GIFT_TYPE.CONTINUEBUY] = "越买越香",
    [Meta.GIFT_TYPE.BUYANDFREE] = "敢买敢送",
}

-- 版本控制标记
Meta.CLIENTVERSION = {
    [Meta.GIFT_TYPE.ASSIST] = 1,
    [Meta.GIFT_TYPE.INFADD5STEP] = 1,
    [Meta.GIFT_TYPE.THREEFORONE] = 4,
    [Meta.GIFT_TYPE.CONTINUEBUY] = 2,
    [Meta.GIFT_TYPE.BUYANDFREE] = 6,
}

-- iconKey
Meta.ICONKEY = {
    [Meta.GIFT_TYPE.ASSIST] = IconKey.kNewbieGiftAssist,
    [Meta.GIFT_TYPE.INFADD5STEP] = IconKey.kNewbieGiftInfAdd5Step,
    [Meta.GIFT_TYPE.THREEFORONE] = IconKey.kNewbieGiftThreeForOne,    
    [Meta.GIFT_TYPE.CONTINUEBUY] = IconKey.kNewbieGiftContinueBuy,
    [Meta.GIFT_TYPE.BUYANDFREE] = IconKey.kNewbieGiftBuyAndFree,
}

-- icon spine路径
Meta.ICONSPINE = {
    [Meta.GIFT_TYPE.ASSIST] = Meta.resPath .. "spine/zuijiazhuli.skel",
    [Meta.GIFT_TYPE.INFADD5STEP] = Meta.resPath .. "spine/zuijiazhuli.skel",
    [Meta.GIFT_TYPE.THREEFORONE] = Meta.resPath .. "spine/tiaoxuanyige.skel",
    [Meta.GIFT_TYPE.CONTINUEBUY] = Meta.resPath .. "spine/yuemaiyuexiang.skel",
    [Meta.GIFT_TYPE.BUYANDFREE] = Meta.resPath .. "spine/ganmaigansong.skel",
}

Meta.AUTOPOPTYPE = {
    ENERGY = 1,
    CONTINUEFAIL = 2,
    LOGIN = 3,
    WINDCOIN = 4,
}

----------------------------强弹时机检测----------------------------
--风车币余量
function Meta.checkRemainWindCoin(giftType, checkCount)
	
    checkCount = checkCount or 30
    local coinNumber = _G.amfBean("UserManager"):getCash()
	printx(33, "Meta.checkRemainWindCoin", coinNumber, checkCount, coinNumber < checkCount)
    return coinNumber < checkCount and _G.amfBean("NewbieGiftOptimizeMgr").AUTOPOPTYPE.WINDCOIN or false
end
--精力余量
function Meta.checkRemainEnergy(giftType, checkCount)
    checkCount = checkCount or 5
    local energyState = _G.amfBean("UserEnergyManager"):getEnergyState()
    if energyState == UserEnergyState.INFINITE then
		printx(33, "Meta.checkRemainEnergy", "UserEnergyState.INFINITE", false)
        return false
    end
    local curEnergy = _G.amfBean("UserEnergyManager"):getEnergy()
	printx(33, "Meta.checkRemainEnergy", curEnergy, checkCount, curEnergy < checkCount)
    return curEnergy < checkCount and _G.amfBean("NewbieGiftOptimizeMgr").AUTOPOPTYPE.ENERGY or false
end
--连续失败次数
function Meta.checkContinueFailCount(giftType, checkCount)
    checkCount = checkCount or 3
    local failCount = _G.amfBean("NewbieGiftOptimizeMgr"):getContinueFailCount()
	printx(33, "Meta.checkContinueFailCount", failCount, checkCount, failCount >= checkCount)
    return failCount >= checkCount and _G.amfBean("NewbieGiftOptimizeMgr").AUTOPOPTYPE.CONTINUEFAIL or false
end
--场景234强弹
function Meta.checkOnEnterAutoPop(giftType)
	printx(33, "Meta.checkOnEnterAutoPop", giftType)
	return _G.amfBean("NewbieGiftOptimizeMgr").AUTOPOPTYPE.LOGIN
    -- local needPop = _G.amfBean("NewbieGiftOptimizeMgr"):getNeedPopOnEnter(giftType)
	-- printx(33, "Meta.checkAutoPop", needPop)
    -- return needPop
end

-- 强弹时机与场景检测 与数值表中对应
Meta.AutoPopDefinition = {
	Meta.checkRemainWindCoin,
	Meta.checkRemainEnergy,
	Meta.checkOnEnterAutoPop,
	Meta.checkContinueFailCount,
}

Meta.IconTipText = {
	[Meta.GIFT_TYPE.ASSIST] = {
		"最佳助力助你过关！",
		"这里的精力便宜又实惠~"
	},
	[Meta.GIFT_TYPE.INFADD5STEP] = {
		"过关疲惫来一个，有劲！",
		"无限加5步助力畅爽过关~"
	},
	[Meta.GIFT_TYPE.THREEFORONE] = {
		"老板挥泪大甩卖",
		"老板挥泪大甩卖"
	},
	[Meta.GIFT_TYPE.CONTINUEBUY] = {
		"打折的香气扑面而来",
		"买不了吃亏，买不了上当~"
	},
	[Meta.GIFT_TYPE.BUYANDFREE] = {
		"厂家促销敢买敢送！",
		"买的多送的多！"
	},
}
----------------------------------------------------------

Meta.FakeData = {
    -- 瀑布流固定奖励配置
    BuyAndFreeFixedGfit = {
		{
			id = 1,
			isFree = true,
			rewardList = {
				{itemId = 14, num = 1},
			},
			goodsId = 0,
		},
		{
			id = 2,
			isFree = true,
			rewardList = {
				{itemId = 10098, num = 2},
				{itemId = 10098, num = 2},
				{itemId = 10098, num = 2},
                {itemId = 10098, num = 2},
			},
			goodsId = 0,
		},
		{
			id = 3,
			isFree = false,
			rewardList = {
				{itemId = 10098, num = 3},
				{itemId = 10098, num = 3},
			},
			goodsId = 640,
		},
    },
    -- 瀑布流礼包循环奖励配置
    BuyAndFreeLoopGift = {
        {
			id = 1,
			isFree = true,
			rewardList = {
				{itemId = 10098, num = 4},
			},
			goodsId = 0,
		},
		{
			id = 2,
			isFree = true,
			rewardList = {
				{itemId = 2, num = 5},
				{itemId = 10098, num = 5},
				{itemId = 10098, num = 5},
			},
			goodsId = 0,
		},
		{
			id = 3,
			isFree = true,
			rewardList = {
				{itemId = 14, num = 6},
				{itemId = 10098, num = 6},
				{itemId = 10098, num = 6},
			},
			goodsId = 0,
		},
        {
			id = 4,
			isFree = true,
			rewardList = {
				{itemId = 10004, num = 7},
				{itemId = 10098, num = 7},
				{itemId = 10098, num = 7},
			},
			goodsId = 0,
		},
    }
}

return Meta