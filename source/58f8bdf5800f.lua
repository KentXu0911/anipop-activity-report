local Meta = {}
Meta.actId = 6077
-- 板子换色
Meta.CustomColorCfg = {
    bgColor = "519be0ff",
    titleColor = "206384ff",
}

Meta.haptics = {
    FISHING = "fishing",
    LONGTAPLIGHT = "longTapLight",
    LONGTAPMID = "longTapMid",
    LONGTAPHEAVY = "longTapHeavy",
}

Meta.infoPrefix = "userInfo" -- 数据keyChain前缀，可以没有，说明你直接存在data里，没再加个表
Meta.configPrefix = "localConfig" -- 配置keyChain前缀，同上
Meta.timePrefix = "actTime"
Meta.needLoadFiles = {
    "amf/activity/fishingwinner/materials/goldHook.png",
    "amf/activity/fishingwinner/materials/goldHook_bait.png",
    "amf/activity/fishingwinner/materials/normalHook_bait.png",
    "amf/activity/fishingwinner/materials/normalHook.png",
    "amf/activity/fishingwinner/materials/score.png",
}

-- 引导标记 10以前的为永久标记
Meta.Guide = {
    NewUser1 = 1,
    NewUser2 = 2,
    NewUser3 = 3,
    PopGuidePanel = 4,
    BigFishGuide = 5,    -- 大鱼来袭面板

    FreeNewerCollection = 11, -- 新手免费送收集物的动画
    NewFishInt = 12,    -- 保存新鱼列表
    PopHandBook = 14,    -- 图鉴强弹
    PopSkipFishingConfirmPanel = 15, -- 本期已弹出跳过钓鱼流程确认面板
    SkipFishingProcess = 16, -- 本期已选择跳过钓鱼流程
}

Meta.scoreItemId = 50000
Meta.normalHookItemId = 57466
Meta.goldHookItemId = 57467
Meta.scoreBuff20ItemId = 57468
Meta.scoreBuff50ItemId = 57469
Meta.doubleBuffItemId = 57470
-- Meta.baitItemId = 50003
-- Meta.kissFishBuffItemId = 50004

--关卡内鱼钩CollectionId
Meta.normalHookCollectionId = 178

Meta.fishIdToSpine = {
    [4] = {
        name = "a_1_3",
        slot = "a_1_1",
        pic = "a_1_1a",
    },
    [5] = {
        name = "a_1_3",
        slot = "a_1_1",
        pic = "a_1_1b",
    },
    [6] = {
        name = "a_1_3",
        slot = "a_1_1",
        pic = "a_1_1c",
    },
    [3] = {
        name = "a_2_3",
        slot = "a_2_1",
        pic = "a_2_1a",
    },
    [2] = {
        name = "a_2_3",
        slot = "a_2_1",
        pic = "a_2_1b",
    },
    [1] = {
        name = "a_2_3",
        slot = "a_2_1",
        pic = "a_2_1c",
    },
    [10] = {
        name  = "b_1_3",
        slot = "b_1_1",
        pic = "b_1_1a",
    },
    [11] = {
        name  = "b_1_3",
        slot = "b_1_1",
        pic = "b_1_1b",
    },
    [12] = {
        name  = "b_1_3",
        slot = "b_1_1",
        pic = "b_1_1c",
    },
    [7] = {
        name  = "b_2_3",
        slot = "b_2_1",
        pic = "b_2_1a",
    },
    [8] = {
        name  = "b_2_3",
        slot = "b_2_1",
        pic = "b_2_1b",
    },
    [9] = {
        name  = "b_2_3",
        slot = "b_2_1",
        pic = "b_2_1c",
    },
    [13] = {
        name  = "b_3_3",
        slot = "b_3_1",
        pic = "b_3_1a",
    },
    [14] = {
        name  = "b_3_3",
        slot = "b_3_1",
        pic = "b_3_1b",
    },
    [15] = {
        name  = "b_3_3",
        slot = "b_3_1",
        pic = "b_3_1c",
    },
    [18] = {
        name  = "c_1_2",
        slot = {
            "c_1_1",
            "c_1_3",
            "c_1_2"
        },
        pic = {
            "c_1_1a",
            "c_1_3a",
            "c_1_2a"
        }
    },
    [19] = {
        name  = "c_1_2",
        slot = {
            "c_1_1",
            "c_1_3",
            "c_1_2"
        },
        pic = {
            "c_1_1b",
            "c_1_3b",
            "c_1_2b"
        }
    },
    [16] = {
        name  = "c_2_2",
        slot = "c_2_1",
        pic = "c_2_1a",
    },
    [17] = {
        name  = "c_2_2",
        slot = "c_2_1",
        pic = "c_2_1b",
    },
    [20] = {
        name = "d_1_2",
        slot = "d_1_1",
        pic = "d_1_1a",
    },
    [21] = {
        name = "d_1_2",
        slot = "d_1_1",
        pic = "d_1_1b",
    },
    [22] = {
        name = "d_2_2",
        slot = {
            "d_2_1",
            "d_2_3",
            "d_2_2"
        },
        pic = {
            "d_2_1a",
            "d_2_3a",
            "d_2_2a"
        }
    },
    [23] = {
        name = "d_2_2",
        slot = {
            "d_2_1",
            "d_2_3",
            "d_2_2"
        },
        pic = {
            "d_2_1b",
            "d_2_3b",
            "d_2_2b"
        }
    },
    [24] = {
        name = "e_1_0",
    },
    [26] = {
        name = "e_2_0",
    },
    [28] = {
        name = "e_3_2",
        slot = "e_3_1",
        pic = "e_3_1a",
    },
    [31] = {
        name = "e_3_2",
        slot = "e_3_1",
        pic = "e_3_1b",
    },
    [27] = {
        name = "e_4_0",
    },
    [29] = {
        name = "e_5_0",
    },
    [25] = {
        name = "e_6_0",
    },
    [30] = {
        name = "fox_all",
    },
    [32] = {
        name = "animal_shark",
    }
}
Meta.BigFishId = 32
Meta.MeMeFoxFishId = 30
Meta.KissFishId = 24
-- 普通鱼出水贝塞尔曲线
Meta.FishOutWaterCurveConfig = {
    {
        targetOffset = ccp(-267.38256835938, 281.87921142578),
        cp1 = ccp(-0.04, 0.5),
        cp2 = ccp(0.2, 1.1),
    },
    {
        targetOffset = ccp(-254.49664306641, 362.41613769531),
        cp1 = ccp(-0.04, 0.4),
        cp2 = ccp(0.1, 1),
    },
    {
        targetOffset = ccp(-243.22148132324, 196.51007080078),
        cp1 = ccp(-0.05, 0.5),
        cp2 = ccp(0.2, 1),
    }
}
-- 么么狐出水贝塞尔曲线
Meta.MeMeFoxOutWaterCurveConfig = {
    targetOffset = ccp(-81.147552490234, 210.98364257813),
    cp1 = ccp(-1.05, 0.3),
    cp2 = ccp(-0.4, 1),
}

Meta.ChickenDialogue = {
    "别戳我啦，让我再睡一会~",
    "zzzZZZZ",
    "等鱼上钩了再叫我吧~"
}

Meta.BearDialogue = {
    "准备准备，要钓鱼喽~",
    "天气晴朗，今天宜钓鱼~",
    "这次会钓上来什么鱼呢？",
    "大鱼会来吗？"
}

Meta.FishType = {
    LOW = "LOW",
    MID = "MID",
    HIGH = "HIGH",
    HIGH_KISS = "HIGH_KISS",
    HIGH_FOX = "HIGH_FOX",
    HIGH_BIG = "HIGH_BIG"
}

return Meta