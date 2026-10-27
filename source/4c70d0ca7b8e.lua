local Meta = {}

Meta.ACT_ROUND = 12 --每期迭代更改
--只更换头像框的情况新增头像框资源和配置后在这里改下即可
--新增菜谱需要在这加下相关配置
Meta.headFrameTypeId = 60000 + HeadFrameType.kCanteen_2025_zhongqiu  --包内引流记得也改下

Meta.clientIdBegin = 9000000
Meta.dianzanRes = "amf/activity/canteen/materials/dianzan.png"
Meta.zanId = -1
Meta.scoreBuff20Id = 52908
Meta.preFrameName = "canteen_"
Meta.foodResPath = "amf/activity/canteen/texture/canteenFoodRes.plist"
Meta.inLevelFoodResPath = "tempFunctionResInLevel/Canteen/json/foodRes.plist"
Meta.downloadLabels = {
    "canteen"
}
Meta.needLoadFiles = {
    Meta.dianzanRes,
}
-- Meta.autoDownload = true
Meta.dcFeature = "chef_god"
Meta.actId = 3068


Meta.guideIds = {
    --常用ID
    kJoinActivity = 1 ,
    SHAREREWARD_1 = 2,


    --图鉴ID 100~1000
    MENU_1 = 101,
    MENU_2 = 102,
    MENU_3 = 103,
    MENU_4 = 104,
    MENU_5 = 105,
    MENU_112 = 112,
    MENU_113 = 113,
    MENU_120 = 120,

    --中秋限时食谱
    MENU_121 = 121,
    MENU_122 = 122,
    --冬至限定食谱
    MENU_123 = 123,

    --100口碑值分享 1000 + ACT_OPEN_VERSION
    SHAREREWARD_2 = 1000,
    --节日限时菜谱分享 2000 + ACT_OPEN_VERSION
    SHAREREWARD_3 = 2000,
}


Meta.specialIds = {
    kSpA = 9,
    kSpB = 10,
}

Meta.limitMenus = {
    111,112,113,114,115,116,117,118,119,120,121,122,123
}

Meta.materialIds = {
    kSpA = tostring(Meta.specialIds.kSpA),--万能食材
    kSpB = tostring(Meta.specialIds.kSpB),
    material_N_1_1 = '1', --鸡蛋
    material_N_1_2 = '2', --油菜
    material_N_1_3 = '3', --面粉
    material_N_1_4 = '4', --蘑菇

    material_N_2_1 = '5', --猪肉
    material_N_2_2 = '6', --鸡肉

    material_N_3_1 = '7', -- 鱼
    material_N_3_2 = '8', --扇贝

    material_EX_A_12 = tostring(Meta.clientIdBegin +  Meta.specialIds.kSpA * 100 + 12), --蒜
    material_EX_A_13 = tostring(Meta.clientIdBegin +  Meta.specialIds.kSpA * 100 + 13), --葱
    material_EX_A_20 = tostring(Meta.clientIdBegin +  Meta.specialIds.kSpA * 100 + 20), --金针菇
    material_EX_A_21_22 = tostring(Meta.clientIdBegin +  Meta.specialIds.kSpA * 100 + 21), --面团

    material_EX_B_12 = tostring(Meta.clientIdBegin +  Meta.specialIds.kSpB * 100 + 12), --虾
    material_EX_B_13 = tostring(Meta.clientIdBegin +  Meta.specialIds.kSpB * 100 + 13), --鸭子
    material_EX_B_20 = tostring(Meta.clientIdBegin +  Meta.specialIds.kSpB * 100 + 20), --肥牛
    material_EX_B_21 = tostring(Meta.clientIdBegin +  Meta.specialIds.kSpB * 100 + 21), --豆沙
    material_EX_B_22 = tostring(Meta.clientIdBegin +  Meta.specialIds.kSpB * 100 + 22), --果仁
    material_EX_B_23 = tostring(Meta.clientIdBegin +  Meta.specialIds.kSpB * 100 + 23), --馅料
}

Meta.itemIds = {
    kSpA = 52906,
    kSpB = 52907,
}

Meta.itemId2MaterialsId = {
    [Meta.itemIds.kSpA] = Meta.materialIds.kSpA,
    [Meta.itemIds.kSpB] = Meta.materialIds.kSpB,
}



Meta.spMenuNeedMaterials = {
    [112] = {A = Meta.materialIds.material_EX_A_12,B = Meta.materialIds.material_EX_B_12},
    [113] = {A = Meta.materialIds.material_EX_A_13,B = Meta.materialIds.material_EX_B_13},
    [120] = {A = Meta.materialIds.material_EX_A_20,B = Meta.materialIds.material_EX_B_20},
    [121] = {A = Meta.materialIds.material_EX_A_21_22,B = Meta.materialIds.material_EX_B_21},
    [122] = {A = Meta.materialIds.material_EX_A_21_22,B = Meta.materialIds.material_EX_B_22},
    [123] = {A = Meta.materialIds.material_EX_A_21_22,B = Meta.materialIds.material_EX_B_23},
}

Meta.materialRes = {
    [Meta.materialIds.material_N_1_1] = 'ingredient_52.png',
    [Meta.materialIds.material_N_1_2] = 'ingredient_53.png',
    [Meta.materialIds.material_N_1_3] = 'ingredient_54.png',
    [Meta.materialIds.material_N_1_4] = 'ingredient_55.png',
    [Meta.materialIds.material_N_2_1] = 'ingredient_56.png',
    [Meta.materialIds.material_N_2_2] = 'ingredient_57.png',
    [Meta.materialIds.material_N_3_1] = 'ingredient_58.png',
    [Meta.materialIds.material_N_3_2] = 'ingredient_59.png',
    [Meta.materialIds.kSpA] = 'ingredient_rand.png',
    [Meta.materialIds.kSpB] = 'ingredient_rand.png',

    [Meta.materialIds.material_EX_A_12] = 'ingredient_sp4.png',
    [Meta.materialIds.material_EX_A_13] = 'ingredient_sp3.png',
    [Meta.materialIds.material_EX_A_20] = 'ingredient_sp2.png',
    [Meta.materialIds.material_EX_B_12] = 'ingredient_sp5.png',
    [Meta.materialIds.material_EX_B_13] = 'ingredient_sp6.png',
    [Meta.materialIds.material_EX_B_20] = 'ingredient_sp1.png',


    [Meta.materialIds.material_EX_A_21_22] = 'ingredient_sp7.png',
    [Meta.materialIds.material_EX_B_21] = 'ingredient_sp8.png',
    [Meta.materialIds.material_EX_B_22] = 'ingredient_sp9.png',
    [Meta.materialIds.material_EX_B_23] = 'ingredient_sp10.png',
}

Meta.menuRes = {
    [0] = 'menu_0.png',
    [1] = 'menu_1.png',
    [2] = 'menu_2.png',
    [3] = 'menu_3.png',
    [4] = 'menu_4.png',
    [5] = 'menu_5.png',
    [112] = 'menu_12.png',
    [113] = 'menu_13.png',
    [120] = 'menu_20.png',
    [121] = 'menu_21.png',
    [122] = 'menu_22.png',
    [123] = 'menu_23.png',
}

Meta.popGiftStage4Key = 'TodayStage4PopoutGift'
Meta.popYinLiuStage4Key = 'TodayStage4PopoutYinliu'
Meta.limitTimePassLevelKey = 'limitTimePassLevel'
Meta.giftPopoutLimit = 3


Meta.materialName = {
    [Meta.materialIds.material_N_1_1] = '鸡蛋',
    [Meta.materialIds.material_N_1_2] = '青菜',
    [Meta.materialIds.material_N_1_3] = '面粉',
    [Meta.materialIds.material_N_1_4] = '蘑菇',
    [Meta.materialIds.material_N_2_1] = '猪肉',
    [Meta.materialIds.material_N_2_2] = '鸡肉',
    [Meta.materialIds.material_N_3_1] = '鱼',
    [Meta.materialIds.material_N_3_2] = '扇贝',
    [Meta.materialIds.kSpA] = '万能食材A',
    [Meta.materialIds.kSpB] = '万能食材B',

    [Meta.materialIds.material_EX_A_12] = '蒜',
    [Meta.materialIds.material_EX_A_13] = '葱',
    [Meta.materialIds.material_EX_A_20] = '金针菇',
    [Meta.materialIds.material_EX_B_12] = '虾',
    [Meta.materialIds.material_EX_B_13] = '鸭子',
    [Meta.materialIds.material_EX_B_20] = '肥牛',


    [Meta.materialIds.material_EX_A_21_22] = '面团',
    [Meta.materialIds.material_EX_B_21] = '豆沙',
    [Meta.materialIds.material_EX_B_22] = '果仁',
    [Meta.materialIds.material_EX_B_23] = '馅料',
}

Meta.materialDesc = {
    [Meta.materialIds.material_N_1_1] = '闯关获得',
    [Meta.materialIds.material_N_1_2] = '闯关获得',
    [Meta.materialIds.material_N_1_3] = '闯关获得',
    [Meta.materialIds.material_N_1_4] = '闯关获得',
    [Meta.materialIds.material_N_2_1] = '三星通关获得',
    [Meta.materialIds.material_N_2_2] = '三星通关获得',
    [Meta.materialIds.material_N_3_1] = '彩星通关获得',
    [Meta.materialIds.material_N_3_2] = '彩星通关获得',
    [Meta.materialIds.kSpA] = '三星或彩星通关获得',
    [Meta.materialIds.kSpB] = '三星或彩星通关获得',

    [Meta.materialIds.material_EX_A_12] = '闯关获得',
    [Meta.materialIds.material_EX_A_13] = '闯关获得',
    [Meta.materialIds.material_EX_A_20] = '闯关获得',
    [Meta.materialIds.material_EX_B_12] = '三星或彩星通关获得',
    [Meta.materialIds.material_EX_B_13] = '三星或彩星通关获得',
    [Meta.materialIds.material_EX_B_20] = '三星或彩星通关获得',

    [Meta.materialIds.material_EX_A_21_22] = '闯关获得',
    [Meta.materialIds.material_EX_B_21] = '三星或彩星通关获得',
    [Meta.materialIds.material_EX_B_22] = '三星或彩星通关获得',
    [Meta.materialIds.material_EX_B_23] = '三星或彩星通关获得',
}

Meta.materialBgRes = {
    [Meta.materialIds.material_N_1_1] = 'level_1.png',
    [Meta.materialIds.material_N_1_2] = 'level_1.png',
    [Meta.materialIds.material_N_1_3] = 'level_1.png',
    [Meta.materialIds.material_N_1_4] = 'level_1.png',
    [Meta.materialIds.material_N_2_1] = 'level_2.png',
    [Meta.materialIds.material_N_2_2] = 'level_2.png',
    [Meta.materialIds.material_N_3_1] = 'level_3.png',
    [Meta.materialIds.material_N_3_2] = 'level_4.png',

    [Meta.materialIds.material_EX_A_12] = 'level_5.png',
    [Meta.materialIds.material_EX_A_13] = 'level_5.png',
    [Meta.materialIds.material_EX_A_20] = 'level_5.png',

    [Meta.materialIds.material_EX_B_12] = 'level_6.png',
    [Meta.materialIds.material_EX_B_13] = 'level_6.png',
    [Meta.materialIds.material_EX_B_20] = 'level_6.png',

    [Meta.materialIds.kSpA] = 'level_6.png',
    [Meta.materialIds.kSpB] = 'level_6.png',

    [Meta.materialIds.material_EX_A_21_22] = 'level_5.png',
    [Meta.materialIds.material_EX_B_21] = 'level_6.png',
    [Meta.materialIds.material_EX_B_22] = 'level_6.png',
    [Meta.materialIds.material_EX_B_23] = 'level_6.png',
}


Meta.menuName = {
    [0] = "",
    [1] = "煎蛋拉面",
    [2] = "小鸡炖蘑菇",
    [3] = "四喜丸子",
    [4] = "糖醋鲤鱼",
    [5] = "佛跳墙",
    [112] = "蒜蓉虾球",
    [113] = "北京烤鸭",
    [120] = "肥牛火锅",
    [121] = "豆沙月饼",
    [122] = "五仁月饼",
    [123] = "温暖水饺",
}

Meta.menuCollectionIdMapping = {
    [1] = "92",
    [2] = "93",
    [3] = "94",
    [4] = "95",
    [5] = "96",
    [112] = "97",
    [113] = "98",
    [120] = "99",
    [121] = "128",
    [122] = "129",
    [123] = "139",
    -- ["93"] = 2,
    -- ["94"] = 3,
    -- ["95"] = 4,
    -- ["96"] = 5,
    -- ["97"] = 112,
    -- ["98"] = 113,
    -- ["99"] = 120,
}

Meta.menuDesc = {
    [0] = "完成限时食谱解锁图鉴",
    [1] = "拉面裹满了鲜美的汤汁，搭配酥香可口的煎蛋，是最简单的食材却有最幸福的味道。",
    [2] = "鸡肉酥烂入味，与蘑菇的鲜香融合，炖出美味浓郁的汤汁，是一道给人满满的温暖感的家常菜。",
    [3] = "肉丸外脆里嫩，搭配浓郁酱汁，美味可口。不多不少的四枚肉丸，寓意着福、禄、寿、喜四大喜事。",
    [4] = "炸制过的鱼肉鲜嫩滑润，浇上特制糖醋汁，制成这道酸甜香脆，口感丰富的美味。",
    [5] = "选用多种食材，以高汤文火煨制而成的名菜。浓郁醇香，荤而不腻，正是：酝启荤香飘四邻，佛闻弃禅跳墙来。",
    [112] = "新鲜多汁的虾仁搭配蒜蓉调味，烹饪而成一道滋味鲜美的佳肴，外型精致色泽诱人，品尝起来回味无穷。",
    [113] = "鸭皮酥脆，鸭肉多汁，搭配上薄饼、酱料、葱丝、黄瓜，入口层次丰富，滋味醇厚，被誉为“天下美味”。",
    [120] = "中华美食的代表之一，火锅把浓厚汤底和新鲜食材完美地结合在一起，让每一位品尝者都能享受自己最爱的风味。",
    [121] = "选用红豆精心制作内馅，甜而不腻，口感绵软顺滑，入口即化。",
    [122] = "经典的中式传统月饼，内馅由五种坚果组成，香脆可口，营养丰富。",
    [123] = "咬一口嫩滑多汁，饱满的滋味在唇齿间蔓延，温暖入心。",
}

Meta.titleText = {
    ["52"] = "普通食材-鸡蛋",
    ["53"] = "普通食材-青菜",
    ["54"] = "普通食材-面粉",
    ["55"] = "普通食材-蘑菇",
    ["56"] = "中级食材-猪肉",
    ["57"] = "中级食材-鸡肉",
    ["58"] = "高级食材-鱼",
    ["59"] = "珍贵食材-扇贝",
    ["60"] = {
        [1] = "限时食材-蒜",
        [2] = "限时食材-葱",
        [3] = "限时食材-金针菇",
        [4] = "限时食材-面团",
        [5] = "限时食材-面团",
        [6] = "限时食材-面团",
    },
    ["61"] = {
        [1] = "高级限时食材-虾",
        [2] = "高级限时食材-鸭子",
        [3] = "高级限时食材-肥牛",
        [4] = "高级限时食材-豆沙",
        [5] = "高级限时食材-果仁",
        [6] = "限时食材-馅料",
    },
    ["106"] = "随机食材",
}

return Meta