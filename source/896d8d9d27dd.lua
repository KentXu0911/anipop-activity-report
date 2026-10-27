local ItemId = {
    ENERGY        = 58116,
    BUFF_SCORE_20 = 58117,
    BUFF_SCORE_50 = 58118,
    BUFF_DOUBLE   = 58119,

    DART          = 58120,
    RING          = 58120, -- legacy alias: old design called this ring
    PINEAPPLE     = 58121,
    OBS_DELIVERY_BOX = 58122,

    CLUE_2 = 58124,
    CLUE_3 = 58125,
    CLUE_4 = 58126,
    CLUE_5 = 58127,
    CLUE_6 = 58128,

    -- 图鉴采集类：秋季换皮后为 探险装备 / 树叶 / 蝴蝶
    TOOL_1 = 58129,
    TOOL_2 = 58130,
    TOOL_3 = 58131,
    TOOL_4 = 58132,
    TOOL_5 = 58133,

    LEAF_1 = 58134,
    LEAF_2 = 58135,
    LEAF_3 = 58136,
    LEAF_4 = 58137,
    LEAF_5 = 58138,

    BUTTERFLY_1 = 58139,
    BUTTERFLY_2 = 58140,
    BUTTERFLY_3 = 58141,
    BUTTERFLY_4 = 58142,
    BUTTERFLY_5 = 58143,

    -- 剧情任务道具：名称按秋季版道具id表
    KEY           = 58144, -- 钥匙
    BLUE_FLOWER_2 = 58145, -- 蓝花2
    BROOM         = 58146, -- 扫帚
    KEY_2         = 58148, -- 钥匙2（开笼子用），与 KEY 共用素材
    WOOD          = 58149, -- 木材
    PURPLE_BABY   = 58150, -- 紫宝宝
    ROPE          = 58151, -- 绳子
    BLUE_FLOWER_1 = 58152, -- 蓝花1
    -- 58147 已废弃（新表无此 id，图集中该 frame 与 58150 重叠）

    OBS_BRANCH    = 58153,
    OBS_GRASS     = 58154,
    OBS_STONE     = 58155,
    OBS_BANANA    = 58156,
    OBS_BARREL    = 58157,
    OBS_FENCE     = 58158,
    OBS_SMALL_MIN = 58153,
    OBS_SMALL_MAX = 58158,

    OBS_STUMP      = 58159,
    OBS_BIG_STONE  = 58160,
    OBS_HAY        = 58161,
    OBS_CART       = 58162,
    OBS_THORN_1    = 58163,
    OBS_THORN_2    = 58164,
    OBS_MUSHROOM_1 = 58165,
    OBS_MUSHROOM_2 = 58166,
    OBS_MEDIUM_MIN = 58159,
    OBS_MEDIUM_MAX = 58166,

    CLUE_1     = 58167,
    TASK_STONE = 58168,
    OBS_CAN    = 58169,
    OBS_BONE   = 58170,
    CLUE_7     = 58171,
    CLUE_8     = 58172,
    CLUE_9     = 58173,

    -- 秋季换皮新增的中障碍（materials 图集内已补 frame）
    OBS_BUCKET     = 58174, -- 破水桶
    OBS_IRON_ORE   = 58175, -- 铁矿石
    OBS_COPPER_ORE = 58176, -- 铜矿石
}

return ItemId
