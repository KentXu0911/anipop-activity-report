local MagicRushConst = {}

MagicRushConst.actId = 9084

MagicRushConst.infoPrefix = "userInfo" -- 数据keyChain前缀，可以没有，说明你直接存在data里，没再加个表
MagicRushConst.configPrefix = "localConfig" -- 配置keyChain前缀，同上
MagicRushConst.timePrefix = "activityTime"
MagicRushConst.ACT_CH_NAME = "魔力冲冲冲"

-- 累胜奖励间隔
MagicRushConst.ContinueWinInterval = 3

MagicRushConst.PKState = {
    -- 非法状态
    INVALID = -1,
    -- 准备状态
    PREPARE = 0,
    -- 对局中
    INGAME = 1,
    -- 结算中_1 待领取当局奖励
    TO_BE_SETTLED_1 = 2,
    -- 结算中_2 待领取累胜奖励
    TO_BE_SETTLED_2 = 3
}

MagicRushConst.IconState = {
    IDLE = 1,
    INGAME = 2,
    DOUBLE = 3
}

MagicRushConst.MatchState = {
    INVALID = -1,
    DRAW = 0,
    WIN = 1,
    LOSE = 2
}

MagicRushConst.PopReason = {
    BE_INVITED = 1, -- 被邀请
    CONTINUE_REWARD_ROUND = 2, -- 大奖轮
    ENERGY = 3, -- 精力提示
    DOUBLE = 4, -- 翻倍
    COLLECTION = 5 -- 收集物
}

MagicRushConst.TipDesc = {
  CONTINUE_REWARD_ROUND = "本轮胜利赢大奖！",
  ENERGY = "参与立即得精力！",
  DOUBLE = "翻倍状态已开启！",
}

MagicRushConst.TipKey = {
  BE_INVITED = "be_invited",
  CONTINUE_REWARD_ROUND = "continue_reward_round",
  ENERGY = "energy",
  DOUBLE = "double",
  COLLECTION = "collection"
}

return MagicRushConst
