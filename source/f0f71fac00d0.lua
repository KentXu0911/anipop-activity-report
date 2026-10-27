local MergeConfig = {}

MergeConfig.autoDownload = false
MergeConfig.downloadLabels = {"mergeItems"}--"merge"
MergeConfig.needLoadFiles = {
    "amf/activity/merge/materials/mergeItems.plist"
}

MergeConfig.logicVersion = 2
MergeConfig.LUCKY_LAUNCH_CD = 10
MergeConfig.KING_ORDER_TIP_THIRD_ORDER_INDEX = 5
MergeConfig.POWER_MULTIPLIER_LOCAL_KEY = "Merge_powerMultiplier"
MergeConfig.POWER_LEVEL_BY_MULTIPLIER = {
    [1] = 1,
    [2] = 2,
    [4] = 3,
    [8] = 4,
}
-- 一个风车币对应料理机多长时间
MergeConfig.MACHINE_TIME_PER_GOLD = 60

MergeConfig.ActTimeString = "活动" --”春节“期间，有概率从以下发射器产出
MergeConfig.ActString = "中秋" -- "限定" 角标
MergeConfig.formatActString = function(str)
    return string.format(str, MergeConfig.ActString)
end

MergeConfig.ActChessString = "月饼"
MergeConfig.formatActChessString = function(str)
    return string.format(str, MergeConfig.ActChessString)
end

MergeConfig.ActAndChessString = "限定月饼"
MergeConfig.formatActAndChessString = function(str)
    return string.format(str, MergeConfig.ActAndChessString)
end

MergeConfig.montyName = '钞票'
MergeConfig.hanmerName = '锤子'
MergeConfig.hanmerRewardName = '小鸡'

MergeConfig.SheQuLink = 'https://ff.happyelements.com/mobile/page/topic.html?tid=5099750&app=1001&ct=1562664000&gohome=1'

MergeConfig.oneFrame = 1/30
MergeConfig.colorType = _G.PanelColorConst.ColorType.kWelfare2024 --_G.PanelColorConst.ColorType.kChiefMystery26Red
MergeConfig.colorType2 = _G.PanelColorConst.ColorType.kWelfare2024
MergeConfig.ThreeTipsPanelColrtType = _G.ColorMaintainConfig.bg_gradient_orange

-- 用于全国排行榜引流，按周次和名次顺序排列
MergeConfig.RealItemIds = {80306, 80301, 80272, 80281, 80300, 80254}

MergeConfig.RealItemInfo = {
    [80306] = {
        name = "超级魔力鸟坐姿玩偶",
        link = "https://ff.happyelements.com/mobile/page/topic.html?tid=7132456&app=1001&ct=1667292000&gohome=1",
        minilink = "afAsx_7EqL-NdgDCtTkRs3gASgN6RrMbGMzmZpkp_KPzRmo0kB5LXNSJKR5GtdCi7pkJIUU1XfYBNmmTVTAtOtblsO8i4pdv-tNz7XoxAkll8sVMv11CAjdRiWOZvGEj4qOrw9exoXi-Z2dTVjb5eoSUc9r-N1wiADRWUNdn1zzQo6qcHY1BGZrVn2geeSZiMZSyIE0yBHkzugfqj9xqesmXWPHjUmHjf28cUbPo06oekFmM7OZZISuJXGQ4XI7pQte-JKUonEAswJ--EGPCgVY-cBjBqGL1T6vt842l_hyEqHdO2uvm5lWhIEFedCtSqY2xEdAOc7IqtxnDOfoQWw",
        rangeText = "1-20名"},
    [80301] = {
        name = "菊花嘟嘟趴趴玩偶",
        link = "https://ff.happyelements.com/mobile/page/topic.html?tid=6986242&app=1001&ct=1562664000&gohome=1",
        minilink = "afAsx_7EqL-NdgDCtTkRs0sAMa_tCYD8QLtz-n3dMR0nT899x_AS5rb7gG7twvi2vb52TAaItpDwEj0MQDYs1gdQVt37Qao04ZBPIRiwS6fjF7iVK3TDh0BXriyyEVeQ7ACi4ULewt-wd0FXI6iIj2G_RMc_Z_qq6Wo2oQB79V6qUg95RtJtSOo66serWZ3evVY6Zxt8I3BHk5fHGEPVH7tnYK0VcWNucmdF82XZJcrJYNlLOeuYFAnGobeUIF-K9QBeTJgMXbd7Veausf0Z36UfvoCNnysRumPthbr3eyLuW9AKgIA9fSI6wimkrcB1v2d-Yduz25Uhl0zhpoUr_A",
        rangeText = "21-50名"},
    [80272] = {
        name = "开心消消乐活力定制露营车",
        link = "https://ff.happyelements.com/mobile/page/topic.html?tid=6130260&app=1001&ct=1667292000&gohome=1",
        minilink = "afAsx_7EqL-NdgDCtTkRs7eshVsY3_XixGr5eIYxOXY5_JKXmVg1laei00j66LpH5hKdAb3CtvsDPCatd-YLMIoDvCMYwbHc9PEPLzKnScmW_TSciCfWOkggGi5as3f5lL4SXxnV_owp6Uzi4w7O5q2PIa9kNdOeIRe6t26Uix9ev95dddMwxg3GE2FOXEJ7gTlikycPCVv9nSErQvNJL1xlSXTPdxC5jo7BpQ4U8IHPvMuoQHfEx8xGscEYJHG_J7VwWe0eyBk2D3MPyJC8PdKfmlzfycRwMhMZCxfK4bYjjXR3oSuuKXytPGFJPlvSd9BSTVqsa0IYh8CypYZ5pw",
        rangeText = "1-20名"},
    [80281] = {
        name = "飞机莱萌鸡玩偶",
        link = "https://ff.happyelements.com/mobile/page/topic.html?tid=6627686&app=1001&ct=1754470800&gohome=1",
        minilink = "afAsx_7EqL-NdgDCtTkRs9RjFS6NJxGarcxF4V7VbFZcPZ_LR5onOc1if0QLcW7Y3NXmHVn_ws4NmFHC_qwCleJh6G6S67Bo5ihHy6BUAHvS-oQkQ9kUbaRZIVZRL56lD6ZGl3JiU5KuZH37dLAY3Kwr9bG-K7eBpx2Y-LSQKyekPcTaEnePRTlmvivsvLOAZ5dgY0qEXXo3_D4ep2PWeX_2QNF8jLj4ivZgxaLyexAzpr2MvlI62-A4vWQQCXx8N40my1QjPvcRXwfRL1o3DjxUd7szive61MqsZd7GeaUDgrkrRJZnYuXa73713Qm2ornTLqtHqa8erl9m_5xXzQ",
        rangeText = "21-50名"},
    [80300] = {
        name = "超级莱萌大玩偶",
        link = "https://ff.happyelements.com/mobile/page/topic.html?tid=6986239&app=1001&ct=1562664000&gohome=1",
        minilink = "afAsx_7EqL-NdgDCtTkRs6uLzZy4OSVqtB78aAXMh6BoF20MyMpzSP5992fGdB-FhDR7Vt9lDR9NHiAVAjTpMixQiIMdEhoOBJrQyfy6Cj1WMUcv_zmuRNUIYqizdizarILuL0I56hvpWQKN1lNFq9Y2Q1OZS20QIZ_yPG22wB0GJFrgt-Ygqx7EDoZzk-jurj2WZcIY2s4L7BmTrOyCht4Svs9ou-Q8Ubn5r3_NoM3frcg6NkIZF1wQmaHwjpq39UQ19okzoMeMtEsx_yOwA7XM1SzrjN9J9LJvnvGJbu2yOiidDGoM3LKzUgY-S8QeIAjq9Ji8ZE573z4P5n9iFw",
        rangeText = "1-20名"},
    [80254] = {
        name = "《开心消消乐》栗熊长条抱枕",
        link = "https://ff.happyelements.com/mobile/page/topic.html?tid=5657964&app=1001&ct=1667292000&gohome=1",
        minilink = "afAsx_7EqL-NdgDCtTkRs1Dln68w8_v-0Jgf_zmYN1lyndg2nHkutuqxpMYr0WOgAInzWM8879Ry3AIPN50GlF3PRCYNmfU7qdFxrPbXl52ta3UaRS7SJiifrJHsrA00ajXX4HGtt3m47Z5s6TCOaxqbPkoPCdBr2iK0KRweklkcl-kAm79wDNkzA1PdDZYfXEjwr5HUjcQrjInqCAuKHukm9-kA2-SPrCRuj-riRwr99Voey-r-woIpvHklwT3KkNem0LRQP_-lsTwH7-Nd3y5FIRhrCogaEAQE2R8SJlKOy4-LTYdkk-vBfp2NOS7Ss2tNatM_wJI8uOcaJibNrg",
        rangeText = "21-50名"},
}

--引导标记
MergeConfig.GuideIds = {
	kGuide1 = 1, --引导1
    kGuide2 = 2,
    kGuide3 = 3,
    kGuide4 = 4,
    kGuide5 = 5,
    kGuideBonus = 66,

    kGuideFirstUnlockItemMaker = 6,--第一个解锁的发射器

    kChickenUnlock = 7, --鸡解锁
    kMachineUnlock = 8, --机器解锁

    kDropTableHandAnim = 9 ,--奖励区小手
    -- 领奖期全国榜
    kNationRankReward = 10,

    kFirstUnlockLimitOrder = 11, --第一个解锁的限时订单

    kLengCangFirdtMakeItem = 12, --制冰机第一个产出

    kItemMakerClickTip1 =  13,
    kItemMakerClickTip2 =  14,
    kItemMakerClickTip3 =  15,
    kItemMakerClickTip4 =  16,

    kMagicItemTipGuide1 =  17,
    kMagicItemTipGuide2 =  18,
    kMagicItemTipGuide3 =  19,
    kMagicItemTipGuide4 =  20,

    kFirstChickenComplete = 21, --首次小鸡领奖成功
    kFirstMachineComplete = 22, --首次机器领奖成功
    kHandBook = 23, -- 图鉴

    -- 活动说明标记，需求2.4部分
    kActDesc = 24,

    kGuideLengCangItem = 25, --冷藏箱引导
    KGuideMergePeiGen = 26, --培根合成引导
    kHeadFrame = 27,        -- 图鉴集齐头像框引导

    kGuideDoublePower = 28, --双倍体力道具

    kFistMoveItemToChicken = 29, --首次移动道具到小鸡
    kFistMoveItemToMachine = 30, --首次移动道具到机器

    kFirstUnlockJiaotiao = 31, --首次解锁胶条

    kMagicItemTipGuide5 =  32,

    kGuideZhiBingItem = 33,--制冰机引导

    kHandBookGetEnergyPop = 34, --图鉴领体力强弹

    kMachineGuide2 = 35, --机器的冰块引导

    kChickenGoOutShowTip = 36, --首次出行的咦闹

    kSpringLimitGiftPop = 37, --春节限时礼包

    kSpringOrderGuide = 38, --春节限时订单引导

    kFistClickZiXuanBox = 39, --首次点击自选宝箱

    kOpenEggGuide1 = 40, -- 砸蛋引导
    kOpenEggGuide2 = 41, -- 砸蛋引导
    kOpenEggGuide3 = 42, -- 砸蛋引导
    kOpenEggGuide0 = 43, -- 砸蛋浣熊头引导
    kWeekRealItemRankGuide1 = 44, -- 周榜实物结算引导
    kWeekRealItemRankGuide2 = 45, -- 周榜实物结算引导
    kWeekRealItemRankGuide3 = 46, -- 周榜实物结算引导
    kAnniversaryOrderGuide1 = 47, --周年限时订单引导
    kAnniversaryOrderGuide2 = 48, --周年限时订单引导
    kAnniversaryOrderGuide3 = 49, --周年限时订单引导
    kOpenEggGuide4 = 50, -- 砸蛋引导
    kOpenEggGuide5 = 51, -- 砸蛋引导
    kOpenEggGuide6 = 52, -- 砸蛋引导
    kOpenEggGuide7 = 53, -- 砸蛋引导
    kOpenEggGuide8 = 54, -- 砸蛋引导
    kOpenEggGuide9 = 55, -- 砸蛋引导

    kSkipGuide = 56, --跳过引导

    kGuideShiHeLv1Item = 57,--解锁1级食盒
    kGuideShiHeLv2Item = 58,--解锁2级食盒
    kFirstUnlockKingOrder = 59, --第一个解锁的皇帝订单

    kQueenMatchOpen = 100, -- 后宫厨神赛开启引导
    kGiftBook = 501, -- 图鉴买过
    kGiftProgress1 = 502, -- 进度礼包1买过
    kGiftProgress2 = 503, -- 进度礼包2买过

    kFistMoveItemToMachine2 = 60, --首次移动道具到机器2

    kGuideDeleteItem = 61, --引导删除道具
    kRestaurantRatingUnlockGuide = 62, --每日餐厅评级解锁引导
    kFrozenFoodGuidePhase1 = 68, --冰冻棋子1阶新手引导
    kFrozenFoodGuidePhase2 = 69, --冰冻棋子2阶新手引导
    kPraiseFeedbackOrderGuide = 65, --好评回馈订单小手弱引导
    kPraiseFeedbackRewardGuide = 67, --好评回馈领奖强引导

    kNewYearOrderGuide = 63, --订单大比拼开启

    kDoubleItemGuide = 64, --超级按钮介绍面板
    kBubbleBought = 70, --买过泡泡，如果有这个标记，自动弹出气泡购买tip，没有就不弹
    kPowerBottleGuide = 71, --体力瓶永久引导
    kPowerChestGuide = 72, --体力箱子永久引导
    kPowerMultiplierGuide = 73,

    -- 380 - 403 飘窗

    kQueenMatchEnter1 = 9999, -- 厨神第一次引导
    -- 10000 以后是每期战报的标记
    kMatchReport = 10000,
}

MergeConfig.Keys = {
    STRENGTH_PK_LAST_VALUE = "strength_pk_last_value",
    STRENGTH_PK_LAST_RANK = "strength_pk_last_rank",
    SHOW_NATIONAL_RANK_REWARD = "show_national_rank_reward",
    STRENGTH_PK_LAST_ROUND = "strength_pk_last_round",
    POP_BUY_ENERGY_GIFT_ROUND = "pop_buy_energy_gift_round",
    POP_BUY_TUJIAN_HALF = "pop_buy_tujian_half",
    POP_BUY_JINDU_HALF_GIFT = "pop_buy_jindu_half_gift",
    POP_BUY_JINDU_FULL_GIFT = "pop_buy_jindu_full_gift",
    ORDER_COMPLETE_INFO = 'order_complete_info',
    POP_BUBBLE_DISCOUNT_PANEL = 'pop_bubble_discount_panel',
    END_SOON_TIP_POP = "end_soon_tip_pop",

}

MergeConfig.MaxPowerConfig = 9999
MergeConfig.AutoAddMaxPowerConfig = 50
MergeConfig.BuyPowerCountConfig = 50
MergeConfig.PowerTipPowerConfig = 30
MergeConfig.MaxBuyPowerDiscountTime = 5
MergeConfig.PowerCollectItemConfig = {
	under60 = 4,
	under30 = 8,
	undertop = 8,
	colorStar = 8,
    firstlevelLib = 10,
    levelLib = 5,
}
MergeConfig.AutoAddPowerCDTime = 3600
MergeConfig.OpenEggMoneyLimit = 170

MergeConfig.PowerBarPosConfig = {
    x = 12,
    y = 24,
}

MergeConfig.BuyPowerValueConfig = {
	[1] = {gold = 9, discount = 0.3},
	[2] = {gold = 59, discount = 1.8},
	[3] = {gold = 99, discount = 3},
	[4] = {gold = 159, discount = 5},
	[5] = {gold = 259, discount = 8},
	[6] = {gold = 320, discount = nil},
}

MergeConfig.CollectionId = 59335
MergeConfig.MoneyId = 59336
MergeConfig.DoubleBuffId = 59332
MergeConfig.ScoreBuff20Id = 59330
MergeConfig.ScoreBuff50Id = 59331
-- MergeConfig.HeadFrameId = 66573
MergeConfig.YuanBaoId = 58083
--锤子id
MergeConfig.hammerId = 59422

MergeConfig.Chicken = 59334 --小鸡
MergeConfig.Machine = 59333 --料理机
MergeConfig.StaticItemIconInfo = {
    [MergeConfig.hammerId] = {Frame = "mergeItems/yaoshi.png", Atlas = "amf/activity/merge/materials/mergeItems.plist", IsPropPng = false},
    [MergeConfig.CollectionId] = {Frame = "mergeItems/collect.png", Atlas = "amf/activity/merge/materials/mergeItems.plist", IsPropPng = false},
    [MergeConfig.DoubleBuffId] = {Frame = "mergeItems/collect.png", Atlas = "amf/activity/merge/materials/mergeItems.plist", IsPropPng = false},
    [MergeConfig.MoneyId] = {Frame = "mergeItems/money.png", Atlas = "amf/activity/merge/materials/mergeItems.plist", IsPropPng = false},
    [MergeConfig.YuanBaoId] = {Frame = "amf/activity/merge/materials/collection.png", Atlas = "", IsPropPng = true},

    [MergeConfig.Chicken] = {Frame = "mergeItems/"..MergeConfig.Chicken..".png", Atlas = "amf/activity/merge/materials/mergeItems.plist", IsPropPng = false},
    [MergeConfig.Machine] = {Frame = "mergeItems/"..MergeConfig.Machine..".png", Atlas = "amf/activity/merge/materials/mergeItems.plist", IsPropPng = false},
}

--砸蛋最终奖励需要的鸡的数量
MergeConfig.openEggNeedChickenNum = 12


MergeConfig.HeadFrameIds = {66672,66673,66674}

MergeConfig.unlockOrder2NeedCompleteNum = 4
MergeConfig.unlockOrder3NeedCompleteNum = 5
MergeConfig.unlockLimitOrderNeedCompleteNum = 10
MergeConfig.creteExtraItemNeedCompleteNum = 10

MergeConfig.kFlower20176 = 20207
MergeConfig.kHeadIcon20177 = 21061
MergeConfig.kNameCard20178 = 23015

MergeConfig.shop57054 = 57054

MergeConfig.StepTypes = {
    kDailyPK = "PER_DAY_PK", --pk赛
    kCrushEgg = "CRUSH_EGG", --砸蛋
    KEndlessPower = "ENDLESS_POWER",--无尽体力
    kAnniversaryGiftt = "ANNIVERSARY_GIFT", --周年礼包
    kSurriseAssist = "SURPRISE_ASSIST", --惊喜助力
    kWeekRank = "WEEKLY_RANK",--全国周榜
    kKingOrder = "KING_ORDER", -- 皇帝订单
    kQueenMatch = "COOK_MATCH", -- 后宫厨神赛
    kBubbleDiscount = 'BUBBLE_DISCOUNT', --气泡折扣
    kRestaurantPraise = "RESTAURANT_PRAISE", -- 好评回馈
    kGoodGift = "GOOD_GIFT", -- 好礼连连
}

MergeConfig.GotoPlayLevelDCId = {
    DOUBLEB_BUFF_TIP = 1,
    BUY_POWER_LIST = 2,
    BUY_POWER = 3,
}

MergeConfig.ItemText = {
    ["59337"] = {
        name = "水果篮",
        desc = "点击可以产出神秘水果哦，快来试试吧！",
        desc2 = MergeConfig.formatActChessString("点击可以产出神秘水果和%s哦，快来试试吧！"),
        cdDesc = "花费风车币可让水果篮立刻完成备货"
    },
    ["59338"] = {
        name = "冰箱",
        desc = "点击产出海鲜和冰饮哦，快来试试吧！",
        desc2 = MergeConfig.formatActChessString("点击可以产出海鲜、冰饮和%s哦，快来试试吧！"),
        cdDesc = "花费风车币可让冰箱立刻完成备货"
    },
    ["59340"] = {
        name = "蜂巢",
        desc = "点击产出蜂蜜哦，快来试试吧！",
        desc2 = MergeConfig.formatActChessString("点击产出蜂蜜和%s哦，快来试试吧！"),
        cdDesc = "花费风车币可让蜂巢立刻完成备货"
    },
    ["59339"] = {
        name = "蔬菜篮",
        desc = "点击产出蔬菜哦，快来试试吧！",
        desc2 = MergeConfig.formatActChessString("点击产出蔬菜和%s哦，快来试试吧！"),
        cdDesc = "花费风车币可让蔬菜篮立刻完成备货"
    },
    ["59424"] = {
        name = "竹篮",
        desc = "点击产出面食和醋哦，快来试试吧",
        desc2 = MergeConfig.formatActChessString("点击产出面食、醋和%s哦，快来试试吧"),
        cdDesc = "花费风车币可让竹篮立刻完成备货"
    },
    ["59341"] = {
        name = "樱桃",
        desc = "一口一个，甜里带一丝俏皮的酸。"
    },
    ["59342"] = {
        name = "猕猴桃",
        desc = "外表毛茸茸，内心很细腻，酸甜刚刚好。"
    },
    ["59343"] = {
        name = "橙子",
        desc = "剥开就是清香，满满都是阳光的味道。"
    },
    ["59344"] = {
        name = "苹果",
        desc = "脆爽清甜，一天一个，健康又美味。"
    },
    ["59345"] = {
        name = "牛油果",
        desc = "绵密似乳酪，带着独特的坚果香味。"
    },
    ["59346"] = {
        name = "葡萄",
        desc = "一串串的小快乐，忍不住多吃几颗。"
    },
    ["59347"] = {
        name = "香蕉",
        desc = "自带“打开即食”属性，软糯又治愈。"
    },
    ["59348"] = {
        name = "柚子",
        desc = "剥开厚厚棉袄，瓣瓣果肉清甜。"
    },
    ["59349"] = {
        name = "哈密瓜",
        desc = "甜到心里去，一口就有度假的感觉。"
    },
    ["59350"] = {
        name = "冰棍",
        desc = "简单直接，一口下去，立刻冰爽。",
    },
    ["59351"] = {
        name = "果味冰棍",
        desc = "酸酸甜甜水果派对，吃一口活力满满。",
    },
    ["59352"] = {
        name = "西瓜冰棍",
        desc = "凉爽中带着清甜，满满的夏天的味道。",
    },
    ["59353"] = {
        name = "小雪人雪糕",
        desc = "戴可可帽的雪人，可爱得让人舍不得咬。",
    },
    ["59354"] = {
        name = "巧克力夹心雪糕",
        desc = "香脆巧克力外壳下，藏着丝滑的奶油。",
    },
    ["59355"] = {
        name = "巧克力甜筒",
        desc = "蛋筒酥脆，巧克力香浓，每一口都满足。",
    },
    ["59356"] = {
        name = "巧克力果味甜筒",
        desc = "巧克力打底，果香偷偷加分。",
    },
    ["59357"] = {
        name = "莱萌限定甜筒",
        desc = "造型可爱，美味不减。",
    },
    ["59358"] = {
        name = "扇贝",
        desc = "合上是安静，打开是鲜甜的小惊喜。"
    },
    ["59359"] = {
        name = "海螺",
        desc = "螺肉紧实弹韧，嚼劲里全是海味。"
    },
    ["59360"] = {
        name = "生蚝",
        desc = "入口嫩滑，爆出咸鲜汁水。"
    },
    ["59361"] = {
        name = "对虾",
        desc = "肉质紧实弹牙，鲜甜本味十足。"
    },
    ["59362"] = {
        name = "鱼块",
        desc = "去刺留香，简单烹饪就超美味。"
    },
    ["59363"] = {
        name = "东星斑",
        desc = "名气在外，细嫩入口，确实名不虚传。"
    },
    ["59364"] = {
        name = "大鱿鱼",
        desc = "弹牙脆爽，嚼劲十足。"
    },
    ["59365"] = {
        name = "大龙虾",
        desc = "壳很硬，肉很嫩，一上桌就是主角。"
    },
    ["59366"] = {
        name = "大闸蟹",
        desc = "膏黄丰满流油，蟹肉丝丝清甜。"
    },
    ["59367"] = {
        name = "一勺蜂蜜",
        desc = "亮晶晶的一勺，能拉出长长的蜜丝儿。"
    },
    ["59368"] = {
        name = "一块蜂蜜",
        desc = "金黄剔透，满口留香。"
    },
    ["59369"] = {
        name = "一碟蜂蜜",
        desc = "金灿灿的一碟，蘸什么都好吃。"
    },
    ["59370"] = {
        name = "一碗蜂蜜",
        desc = "甜得很扎实，份量看着就安心。"
    },
    ["59371"] = {
        name = "大碗蜂浆",
        desc = "浓稠饱满，满满都是能量感。"
    },
    ["59372"] = {
        name = "大罐蜂王浆",
        desc = "一大罐蜂王浆，甜蜜加倍。"
    },
    ["59373"] = {
        name = "黄瓜",
        desc = "清脆爽口，咬下去清新水润。"
    },
    ["59374"] = {
        name = "胡萝卜",
        desc = "脆里带甜，越嚼越有味道。"
    },
    ["59375"] = {
        name = "生菜",
        desc = "轻轻一片，让口感更清爽。"
    },
    ["59376"] = {
        name = "菌菇",
        desc = "看着低调，香气却很扎实。"
    },
    ["59377"] = {
        name = "西蓝花",
        desc = "一朵一朵，都是营养担当。"
    },
    ["59378"] = {
        name = "洋葱",
        desc = "切时流泪，吃时真香。"
    },
    ["59379"] = {
        name = "南瓜",
        desc = "软糯香甜，暖胃又暖心。"
    },
    ["59380"] = {
        name = "樱桃果酱",
        desc = "红宝石般剔透，甜中藏一点淘气的酸。"
    },
    ["59381"] = {
        name = "橙子果酱",
        desc = "满满果粒，散发着阳光般的柑橘香气。"
    },
    ["59382"] = {
        name = "牛油果果酱",
        desc = "柔滑绵密，带着淡淡坚果香。",
    },
    ["59383"] = {
        name = "葡萄果酱",
        desc = "紫晶般浓郁，是秋日葡萄园的来信。"
    },
    ["59384"] = {
        name = "香蕉果酱",
        desc = "金黄软糯，散发着温暖馥郁的熟甜气息。",
    },
    ["59385"] = {
        name = "哈密瓜果酱",
        desc = "清甜如蜜，封存了满满一夏的香气。"
    },
    ["59386"] = {
        name = "蒸海蛎",
        desc = "原壳蒸出大海本味，肉质滑嫩汤汁鲜甜。"
    },
    ["59387"] = {
        name = "菌菇烩虾仁",
        desc = "山珍与海味交融，虾嫩菇滑。"
    },
    ["59388"] = {
        name = "香煎三文鱼",
        desc = "鱼肉鲜美，外酥里嫩，肥而不腻。"
    },
    ["59389"] = {
        name = "铁板鱿鱼",
        desc = "滋啦一声，香味立刻满场。"
    },
    ["59390"] = {
        name = "美味虾煲",
        desc = "虾肉饱满，鲜香入味。"
    },
    ["59391"] = {
        name = "豪华蟹煲",
        desc = "蟹肉鲜甜，配菜丰富，满煲皆是精华。"
    },
    ["59392"] = {
        name = "猕猴桃冰淇淋碗",
        desc = "酸甜清爽的猕猴桃片平衡了冰淇淋的甜腻。"
    },
    ["59393"] = {
        name = "橙子冰淇淋碗",
        desc = "柑橘清香融入每一勺冰凉之中。"
    },
    ["59394"] = {
        name = "苹果冰淇淋碗",
        desc = "果香明亮，甜得轻快不腻。"
    },
    ["59395"] = {
        name = "葡萄冰淇淋碗",
        desc = "果味与巧克力交织，层次感拉满。"
    },
    ["59396"] = {
        name = "香蕉冰淇淋碗",
        desc = "软糯香蕉片点缀，享受双倍香浓丝滑。"
    },
    ["59397"] = {
        name = "柚子冰淇淋碗",
        desc = "微苦回甘，清凉得很有个性。"
    },
    ["59398"] = {
        name = "橙子沙拉",
        desc = "橙瓣多汁，酸酸甜甜让人胃口大开。"
    },
    ["59399"] = {
        name = "苹果沙拉",
        desc = "脆甜苹果丁裹上柔滑酱汁，清爽不腻。"
    },
    ["59400"] = {
        name = "葡萄沙拉",
        desc = "葡萄颗颗晶莹，清甜里带点活泼。"
    },
    ["59401"] = {
        name = "香蕉沙拉",
        desc = "软糯香蕉片带来自然甜香，口感温柔绵密。"
    },
    ["59402"] = {
        name = "柚子沙拉",
        desc = "清香微苦，反而更显清爽。"
    },
    ["59403"] = {
        name = "哈密瓜沙拉",
        desc = "清甜瓜瓣水润爽口，每一口都像咬住夏天。"
    },
    ["59404"] = {
        name = "无限体力",
        desc = "连续点击两次可获得20秒的无限体力",
    },
    ["59405"] = {
        name = "剪刀",
        desc = "拖拽到目标食材上，获得两个低一级的食材",
    },
    ["59406"] = {
        name = "秒表",
        desc = "拖拽到备货中的物品上，使时间前进",
    },
    ["59407"] = {
        name = "升级卡",
        desc = "拖拽到目标食材上，获得一个更高一级的食材",
    },
    ["59409"] = {
        name = "一块月饼",
        desc = "酥皮金黄，小小一口甜进心里。",
    },
    ["59410"] = {
        name = "花纹月饼",
        desc = "花纹圆圆，香气悄悄冒出来。",
    },
    ["59411"] = {
        name = "锦垫月饼",
        desc = "月饼摆好啦，团圆味更浓了。",
    },
    ["59412"] = {
        name = "团圆月饼盘",
        desc = "圆月满盘，甜蜜一起分享吧！",
    },
    ["59413"] = {
        name = "一块月饼",
        desc = "酥皮金黄，小小一口甜进心里。",
    },
    ["59414"] = {
        name = "花纹月饼",
        desc = "花纹圆圆，香气悄悄冒出来。",
    },
    ["59415"] = {
        name = "锦垫月饼",
        desc = "月饼摆好啦，团圆味更浓了。",
    },
    ["59416"] = {
        name = "团圆月饼盘",
        desc = "圆月满盘，甜蜜一起分享吧！",
    },
    ["59417"] = {
        name = "一块月饼",
        desc = "酥皮金黄，小小一口甜进心里。",
    },
    ["59418"] = {
        name = "花纹月饼",
        desc = "花纹圆圆，香气悄悄冒出来。",
    },
    ["59419"] = {
        name = "锦垫月饼",
        desc = "月饼摆好啦，团圆味更浓了。",
    },
    ["59420"] = {
        name = "团圆月饼盘",
        desc = "圆月满盘，甜蜜一起分享吧！",
    },
    ["59421"] = {
        name = "食材自选箱",
        desc = "可选择1个想要的食材。",
    },
    ["59425"] = {
        name = "面粉",
        desc = "雪白面粉，揉进日常的香气里。",
    },
    ["59426"] = {
        name = "面糊",
        desc = "搅开柔软面糊，煎烤蒸炸都藏着惊喜。",
    },
    ["59427"] = {
        name = "面团",
        desc = "揉出面团，醒一醒就是家的味道。",
    },
    ["59428"] = {
        name = "莜面",
        desc = "带着谷物清香入口，朴实一口越嚼越香。",
    },
    ["59429"] = {
        name = "面条",
        desc = "根根顺滑有劲道，嗦一口就是踏实满足。",
    },
    ["59430"] = {
        name = "清汤面",
        desc = "汤清味暖，面香淡淡，吃得心里熨帖。",
    },
    ["59431"] = {
        name = "肉酱面",
        desc = "浓香肉酱裹满面条，每一口都扎实过瘾。",
    },
    ["59432"] = {
        name = "牛肉面",
        desc = "牛肉鲜香，面条筋道，一碗暖到胃里。",
    },
    ["59433"] = {
        name = "一碟醋",
        desc = "小小一碟，蘸出滋味。",
    },
    ["59434"] = {
        name = "一碗醋",
        desc = "满满一碗，酸爽开胃。",
    },
    ["59435"] = {
        name = "小瓶醋",
        desc = "小瓶一倒，鲜味就到。",
    },
    ["59436"] = {
        name = "大瓶醋",
        desc = "大瓶在手，醋味常有。",
    },
    ["59437"] = {
        name = "大坛醋",
        desc = "大坛藏香，一勺提鲜。",
    },
    ["59445"] = {
        name = "榴莲",
        desc = "金黄果肉，绵密香甜像奶油在舌尖融化。",
    },
    ["59446"] = {
        name = "小熊臻享甜筒",
        desc = "熊熊臻选，夏日中的甜蜜伴侣。",
    },
    ["59447"] = {
        name = "大桶蜂王浆",
        desc = "一大桶蜂王浆，蜜蜂的辛勤成果！",
    },
    ["59448"] = {
        name = "精美蜂浆",
        desc = "一瓶精美封存好的精华，看着就珍贵。",
    },
    ["59449"] = {
        name = "洋蓟",
        desc = "罕见珍品，层层叠叠散发香气。",
    },
    ["59450"] = {
        name = "体力瓶",
        desc = "可向上合成或双击生成%d体力！",
    },
    ["59451"] = {
        name = "体力瓶",
        desc = "可向上合成或双击生成%d体力！",
    },
    ["59452"] = {
        name = "体力瓶",
        desc = "可向上合成或双击生成%d体力！",
    },
    ["59453"] = {
        name = "体力瓶",
        desc = "可向上合成或双击生成%d体力！",
    },
    ["59454"] = {
        name = "体力瓶",
        desc = "可向上合成或双击生成%d体力！",
    },
    ["59455"] = {
        name = "体力瓶",
        desc = "最高等级体力瓶，双击生成%d体力！",
    },
    ["59456"] = {
        name = "低级体力宝箱",
        desc = "可向上合成或产出体力瓶！",
    },
    ["59457"] = {
        name = "高级体力宝箱",
        desc = "最高等级体力宝箱，可产出大量体力瓶！",
    },
}

MergeConfig.BubbleItemText = {
    [1] = {
        name = "普通气泡",
        desc = "花费风车币可获得气泡中的食材。"
    },
    [2] = {
        name = "高级气泡",
        desc = "花费风车币购买可以获得气泡中的食材，直接完成订单。"
    },
    [3] = {
        name = "折扣气泡",
        desc = "花费风车币购买可以获得气泡中的食材，直接完成订单。"
    },
    [4] = {
        name = "折扣气泡",
        desc = "花费风车币购买可以获得气泡中的食材，直接完成订单。"
    }
}

MergeConfig.ChickText = {
    name = "旅行小鸡",
    desc = "填入旅行小鸡所需要的食材，旅行归来后带回丰厚奖励",
    cdDesc = "花费风车币可让小鸡立刻旅行归来",
}
MergeConfig.MachineText = {
    name = "神奇料理机",
    desc = "拖动食材进入料理机，可做出不同美味",
    cdDesc = "花费风车币可让料理机立刻完成菜品"
}

MergeConfig.LockedText = "暂未解锁，快去合成提交订单吧"

MergeConfig.POP_STAGE_4_GIFT_ENERGY_LIMIT = 30
MergeConfig.POP_STAGE_4_GIFT_TIME_LIMIT = 2
MergeConfig.ENERGY_PK_COST_MAX = 150
MergeConfig.GroupRewardMinMoney = 1500
MergeConfig.ENERGY_PK_TRIGGER_ENERGY = 30
MergeConfig.ENERGY_PK_TRIGGER_MONEY = 650
MergeConfig.ENERGY_PK_MAX_ENERGY = 150
MergeConfig.selectBox = 59421
MergeConfig.highPayTag = 5
MergeConfig.actId = 6074
MergeConfig.actChName = "美味合合"            -- 活动中文名
MergeConfig.actSource = "merge2025/Config.lua"  -- 活动路径

MergeConfig.GiftTypeEnum = {
    FLOW = "FLOW",
    SUPPLY = "SUPPLY",
    ENERGY = "ENERGY",
    BUFF = "BUFF",
    BOOK = "BOOK",
    PROGRESS = "PROGRESS",
    RANK = "RANK",
    DISCOUNT = "DISCOUNT",
    CRUSH = "CRUSH",
}

return MergeConfig
