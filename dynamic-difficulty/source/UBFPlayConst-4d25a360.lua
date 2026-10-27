--确保所有地方的颜色枚举一致UBFConst.GameItemColorType
_G.UBFAnimalColorType = {
    kRandom = 0 ,
    kBlue = 1 ,   
    kGreen= 2 , 
    kOrange = 3 ,
    kPurple = 4 ,
    kRed = 5 , 
    kYellow = 6 ,
    kManual = -1,   -- 手动，某些状态需要保持置灰，区别于随机
}

_G.UBFAnimalColorTypeNameMap = {
    [_G.UBFAnimalColorType.kBlue] = "蓝",
    [_G.UBFAnimalColorType.kGreen] = "绿",
    [_G.UBFAnimalColorType.kOrange] = "棕",
    [_G.UBFAnimalColorType.kPurple] = "紫",
    [_G.UBFAnimalColorType.kRed] = "红",
    [_G.UBFAnimalColorType.kYellow] = "黄",
}

--格子上下文模式，对应坐标的d
_G.GridContextDimension = {
    kNormal = 0,
    kVertex = 1,
}
_G.UBFAnimalSpecialType = {
    kNone = 0 ,   --无特效
    kRandom = 1 , --随机特效
    kLineH = 2 ,  --横线特效
    kLineV = 3 , --竖线特效
    kBomb = 4 , --爆炸特效
    kRandomHV = 10, --随机横竖
}
_G.UBFSwapResultType = {
    kTryMatch = 1 ,
    kLineLineSwap = 2 ,
    kLineBoomSwap = 3 ,
    kBoomBoomSwap = 4 ,
    kBridlikeItemSwap = 5 ,     -- 鸟 + 非鸟/非特效动物/非普通小动物
    kBridlikeLineSwap = 6 ,
    kBridlikeBoomSwap = 7 ,
    kBridlikeBridlikeSwap = 8 ,
    kBridlikeCommonAnimalSwap = 9,     -- 鸟 + 普通小动物
    kBTreeCustomSwap = 99 ,
}


_G.UBF_MATCH_STATISTIC_CLASSIFY = -1
_G.UBFMatchMixResult = {
    kDefault = 0 ,   --缺省值，表示尚未经过合成计算
    kNormalMatch = 1 , --普通匹配三消，不合成特效
    kLineH = 2 ,  --横线特效
    kLineV = 3 , --竖线特效
    kBomb = 4 , --爆炸特效
    kBird = 5 , --魔力鸟特效
}

--什么行为产生了攻击
_G.AttackSource = { 
    kMatch = 1 ,        --普通匹配消除（特指可匹配消除的物体）
    kMix = 2 ,          --匹配合成（当前格子参与了匹配合成，对当前格子产生的额外攻击）
    kEffect = 3 ,       --特效击打
    kFeature = 4 ,      --障碍的特殊放招击打
    kProp = 5 ,         --道具击打
    kExtraAtk = 6 ,     --Item（通常是小动物）被销毁时触发的攻击
    kFunctionality = 7, --功能性打击，比如魔力鸟要替换小动物，先要打击，这种打击不会触发额外攻击
    kCrush = 8,          --碾格子！ 
    Virtual = 9,        --这个是rust中的占位，因为虚拟攻击是后做的，简单补了个额外字段，但其实是可以合并的
}

_G.AttackGroupFlagType = { 
    kDefault = "",           --默认
    kTwoBirdsCasting = "birdbird",      --双鸟放招打全屏
    kBirdAttackColor = "birdattack",    --魔力鸟与颜色item交换或被打，攻击所有同色item
    kActiveStarJarAttack = "activestarjarattack",   --星星瓶和颜色item换
    kSnowMonsterSuperCasting = "snowMonsterSuperCasting",   --双雪怪全屏放招
}

--攻击类型(grid,around)
_G.AttackType = { 
    kGrid = 1 ,   --本格内单格攻击
    kAround= 2 ,  --旁消攻击
}

_G.GridFallingState = {
	kNormal = 1 ,
	kFalling = 2 , 
	kJustArrive = 3 ,
    kHalfStable = 4 ,
}

--默认方向是顺时针的，和重力方向判断略有不同
_G.UBFDirection = {
    kUp = 0,
    kRightUp = 5,
    kRight = 10,
    kRightDown = 15,
    kDown = 20,
    kLeftDown = 25,
    kLeft = 30,
    kLeftUp = 35,
    clockwise = function(dir, rotation)
        while rotation < 0 do rotation = rotation + 360 end
        return (dir + rotation * 20 / 180 ) % 40
    end,
    toRoatation = function(dir)
        return dir * 90 / 10
    end,
    isLine = function(dir1 , dir2)
        return (dir1 - dir2) % 20 == 0
    end,
    isAxis = function(dir)
        return dir % 10 == 0
    end,
    isObtuse = function(dir1, dir2)
        dir2 = dir2 + 20
        local lower = (dir1 - 5) % 40
        local upper = (dir1 + 5) % 40
        if lower > upper then upper = upper + 40 end
        if dir2 <= upper and dir2 >= lower then return true end
        return dir2 <= upper + 40 and dir2 >= lower + 40
    end,
    from = function(key)
        if _G.type(key) == "number" then return key end
        return _G.UBFDirectionKeyMap[string.lower(key)] or _G.UBFDirection.kUp
    end
}

UBFDynamicExpression.DefaultField.Direction = UBFDirection

_G.UBFDirectionFourLink = {
    [UBFDirection.kUp] = {UBFDirection.kLeft,UBFDirection.kRight},
    [UBFDirection.kRight] = {UBFDirection.kUp,UBFDirection.kDown},
    [UBFDirection.kDown] = {UBFDirection.kLeft,UBFDirection.kRight},
    [UBFDirection.kLeft] = {UBFDirection.kUp,UBFDirection.kDown},
}

_G.UBFDirectionEightLink = {
    [UBFDirection.kUp] = {UBFDirection.kLeftUp,UBFDirection.kRightUp},
    [UBFDirection.kRightUp] = {UBFDirection.kUp,UBFDirection.kRight},
    [UBFDirection.kRight] = {UBFDirection.kRightUp,UBFDirection.kRightDown},
    [UBFDirection.kRightDown] = {UBFDirection.kRight,UBFDirection.kDown},
    [UBFDirection.kDown] = {UBFDirection.kLeftDown,UBFDirection.kRightDown},
    [UBFDirection.kLeftDown] = {UBFDirection.kLeft,UBFDirection.kDown},
    [UBFDirection.kLeft] = {UBFDirection.kLeftUp,UBFDirection.kLeftDown},
    [UBFDirection.kLeftUp] = {UBFDirection.kLeft,UBFDirection.kUp},
}

_G.UBFDirectionVecMap = {
    [_G.UBFDirection.kUp] = { r = -1 , c = 0 },
    [_G.UBFDirection.kDown] = { r = 1 , c = 0 },
    [_G.UBFDirection.kLeft] = { r = 0 , c = -1 },
    [_G.UBFDirection.kRight] = { r = 0 , c = 1 },
    [_G.UBFDirection.kLeftUp] = { r = -1 , c = -1 },
    [_G.UBFDirection.kLeftDown] = { r = 1 , c = -1 },
    [_G.UBFDirection.kRightUp] = { r = -1 , c = 1 },
    [_G.UBFDirection.kRightDown] = { r = 1 , c = 1 },
} 

_G.UBFDirectionPartMap = {
    [UBFDirection.kLeftUp] = { UBFDirection.kLeft, UBFDirection.kUp },
    [UBFDirection.kLeftDown] = { UBFDirection.kLeft, UBFDirection.kDown },
    [UBFDirection.kRightUp] = { UBFDirection.kRight, UBFDirection.kUp },
    [UBFDirection.kRightDown] = { UBFDirection.kRight, UBFDirection.kDown },
}

-- Direction的反方向
_G.UBFCounterDirection = {
    [UBFDirection.kUp] = UBFDirection.kDown,
    [UBFDirection.kDown] = UBFDirection.kUp,
    [UBFDirection.kLeft] = UBFDirection.kRight,
    [UBFDirection.kRight] = UBFDirection.kLeft,
    [UBFDirection.kLeftUp] = UBFDirection.kRightDown,
    [UBFDirection.kLeftDown] = UBFDirection.kLeftDown,
    [UBFDirection.kRightUp] = UBFDirection.kRightUp,
    [UBFDirection.kRightDown] = UBFDirection.kLeftUp,
}

_G.UBFDirectionKeyMap = {
    ["right"] = UBFDirection.kRight,
    ["left"] = UBFDirection.kLeft,
    ["up"] = UBFDirection.kUp,
    ["down"] = UBFDirection.kDown,
}


_G.UBFDirection.baseMap = {
    [UBFDirection.kUp] = true,
	[UBFDirection.kRight] = true,
	[UBFDirection.kDown] = true,
	[UBFDirection.kLeft] = true,
}
_G.UBFDirection.baseList = { UBFDirection.kUp , UBFDirection.kRight , UBFDirection.kDown , UBFDirection.kLeft }
_G.UBFDirection.baseVecList = { 
    UBFDirectionVecMap[UBFDirection.kUp], 
    UBFDirectionVecMap[UBFDirection.kRight], 
    UBFDirectionVecMap[UBFDirection.kDown],
    UBFDirectionVecMap[UBFDirection.kLeft], 
}

_G.UBFDirection.list = { 
    UBFDirection.kUp, 
    UBFDirection.kRightUp, 
    UBFDirection.kRight, 
    UBFDirection.kRightDown, 
    UBFDirection.kDown, 
    UBFDirection.kLeftDown, 
    UBFDirection.kLeft,
    UBFDirection.kLeftUp, 
}

UBFGameFallingSpdMap = { 7, 3, 2, 2, 1 }

--根据旧的写的，视图用
_G.UBFGameFallingConfig = {
    SPEED_ADD = 16,
    SPEED_MAX = 340,
    SPEED_START = 20,
    SPEED_PORTAL_START = 80,
    UNIT_GRID = 700,
}
_G.UBFGameFallingChangeType = {
	kNew = 1,
}
_G.UBFGameFallingType = {
	kPortal = 1,
	kStraight = 3,
	kCannon = 5,
	kAfterSide = 7,
	kSide = 8,
	kStop = 9,
}
_G.GravityDirection = {
	kUp = 1 ,
	kDown = 2 , 
	kLeft = 3 ,
	kRight = 4 ,
}

_G.GravityDirectionVecMap = {
    [_G.GravityDirection.kUp] = { r = -1 , c = 0 },
    [_G.GravityDirection.kDown] = { r = 1 , c = 0 },
    [_G.GravityDirection.kLeft] = { r = 0 , c = -1 },
    [_G.GravityDirection.kRight] = { r = 0 , c = 1 }
} 

_G.GravityDirectionToDirection = {
    [GravityDirection.kDown] = UBFDirection.kDown,
    [GravityDirection.kUp] = UBFDirection.kUp,
    [GravityDirection.kLeft] = UBFDirection.kLeft,
    [GravityDirection.kRight] = UBFDirection.kRight,
}

_G.UBFDirectionToGravityDirection = {
    [UBFDirection.kDown] = GravityDirection.kDown,
    [UBFDirection.kUp] = GravityDirection.kUp,
    [UBFDirection.kLeft] = GravityDirection.kLeft,
    [UBFDirection.kRight] = GravityDirection.kRight,
}

--生成口更新触发时机枚举
_G.UBFProduceTriggerEvent = {
    kInit = 1,
    kMoveStep = 2,
    kUseProp = 3,
    kEnterAlmostWin = 4,
}

--筛选器相关操作状态枚举
_G.UBFBoardFilterConst = { 

    kValue = 1,
    kRange = 2,
    kAny = 3,
    kSubItem = 4,
    kNoDeathing = 5,

    kAroundExist = 21,
    kNonCoexistence = 22,
    kCoexistence = 23,

    --和UBFGamePlayConstraint里面的stateCond保持同步
    -- kNoLocked = "noLocked", 
    kRequireFollowMaster = "requireFollowMaster",
    kCheckBySelector = "checkBySelector",
}


--棋盘各种状态key枚举
_G.UBFBoardStateKey = {
    kSMKey = "SMKey" ,      --状态机当前状态的key
    kCanSwap = "Swap",      --是否可交换的flag
    kPlayState = "PlayState"--当前游戏状态
}

_G.UBFOperationType = {
    kInit = 0,      --开局操作，初始化各种buff
    kSwap = 1,      --交换操作
    kProp = 2,      --使用道具操作，这包括前置道具后置推荐
    kMod = 3,       --模块
    kAbandon = 4,   --放弃游戏操作
    kUseBuff = 5,   --追加buff操作，比如前置道具推荐！
    kDestiny = 6,   --?
}

--
--
--
--


_G.UBFDestinyDisturber = {
    kHell = 13,
    kForward = 6,
}

_G.UBFOperationAbandonType = {
    kGiveUp = 1,    --放弃，不继续加步数了
    kDropout = 2,   --中途退出
    kRetry = 3,     --重玩
}

--用于标记section的类型，决定是给谁用，并不是代表section的本质内容有差距
_G.UBFSectionType = {
    kStep = 1,
    kFast = 2,
    kKeyPoint = 3,
}

_G.UBFResumeType = {
    kComplete = 1,
    kBackStep = 2,
    kDestiny = 3,
}

_G.UBFGamePlayState = {
    kRun = 1,
    kFail = 2,
    kWin = 3,
    kAlmostFail = 4,
    kAlmostWin = 5,
}

_G.UBFGameViewAtionClassify = {
    kStatus = 1,
    kStatusEffect = 2,
    kEffect = -1,
}

_G.UBFAutoCollectMode = {
    kNone = 0,          --没有
    kDestroy = 1,       --销毁（默认）
    kRelegate = 2,      --降级
}

_G.UBFGameFailReason = {
    kUnknown = "unknown",
    kNoLife = "nolife",         --没有生命了，步数模式就是没有步数了
    kDeadBoard = "deadBoard",   --死棋盘，刷新后仍然无可交换
    kDropout = "dropout",       --玩家退出
    kRetry = "retry",           --玩家重试了
    kStarLack = "starLack",     --虽然胜利了，但星级不足1星
}

--分数源枚举
_G.UBFScoreSourceType = {
    kOwnerless = "ownerless",
    kItem = "item",
    kMix = "mix",
    kSwap = "swap",
}


_G.UBFGameReplayEndType = {
    kNormal = "normal",
    kQuit = "quit",             --主动退出
}


--通用的错误码
UBFCommonErrorCode = {
    kUnknown = -2,
    kCrash = -1,
}
--回放的错误码，原则上是继承UBFCommonErrorCode的
UBFReplayErrorCode = {
    kUnknown = UBFCommonErrorCode.kUnknown,
    kCrash = UBFCommonErrorCode.kCrash,
    kFrameErorr = 1,
    kABTickLeading = 2,
    kABTickLagging = 3,
    kHalfway = 4,   --中途而非
    kVoidProp = 5,  --无效道具
    kGoldenFinger = 6,   --魔法操作(交换)
}
UBFFightErrorCode = {
    kUnknown = UBFCommonErrorCode.kUnknown,
    kCrash = UBFCommonErrorCode.kCrash,
    kBadIdea = 1,       --不合理的交换
    kHugeStep = 2,      --大掉落
    kStableMatch = 3,   --棋盘稳定有匹配
}


UBFBorderAttackMode = {
    kNone = 0,
    kAournd = 1,
    kLine = 2,
    kAdjacent = 3,
    kDir = 4,
    kFixDir = 5,
}

UBFCalcColorOccasion = {
    kManual = -1,
    kInit = 0,
    kCommonRefresh = 1,
}

--------------------------------****** *↓* ******--------------------------------
--				                    Feature枚举
--------------------------------****** *↑* ******--------------------------------

UBFDesireReturnType = {
    GRID_POS = 1,
    GRID_POS_LIST = 2,
    ITEM = 3,
    ITEM_LIST = 4,
    MASTER = 5,
    MASTER_LIST = 6,
    BOOLEAN = 7,
}

UBFDesireReturnTypeDefaultValueMap = {
    [UBFDesireReturnType.GRID_POS] = nil,
    [UBFDesireReturnType.GRID_POS_LIST] = {},
    [UBFDesireReturnType.ITEM] = nil,
    [UBFDesireReturnType.ITEM_LIST] = {},
    [UBFDesireReturnType.MASTER] = nil,
    [UBFDesireReturnType.MASTER_LIST] = {},
    [UBFDesireReturnType.BOOLEAN] = false,
}

UBFDesireTypeIsListMap = {
    [UBFDesireReturnType.GRID_POS_LIST] = true,
    [UBFDesireReturnType.ITEM_LIST] = true,
    [UBFDesireReturnType.MASTER_LIST] = true,
}

UBFAttackReturnMode = {
    --返还剩余的
    RETURN_LEFT = 1,
    --返还原始的
    RETURN_ORIGIN = 2,
    --返还0
    RETURN_ZERO = 3,
    --返还特定值
    RETURN_VALUE = 4,
}

UBFLevelChangeMode = {
    --根据攻击力减少，使用不超过当前level的攻击力
    REDUCE_BY_ATTACK = 1,
    --减少1，使用全部可使用的攻击力
    REDUCE_ONE = 2,
    --到0，使用全部可使用的攻击力
    TO_ZERO = 3,
    --减少固定值
    REDUCE_FIXED_VALUE = 4,
    --根据攻击力增加
    INCREASE_BY_ATTACK = 5,
}

UBFFieldChangeMode = {
    -- 设置固定值
    SET_TO = 1,
    -- 0 -> 1  |  1 -> 0
    SWITCH = 2, 
    -- 追加
    INCREASE_ONE = 3, 
    -- 减少
    DECREASE_ONE = 4,
}


UBFScoreCollectMode = {
    --减层时收集
    ON_REDUCE_LEVEL = 1,
    --被摧毁时收集
    ON_DESTROYED = 2, 
}

UBFTargetCollectMode = {
    --减层时收集
    ON_REDUCE_LEVEL = 1,  
    --被摧毁时收集
    ON_DESTROYED = 2,
    --当state变化
    ON_STAGE_CHANGR = 3,
}

UBFTargetType = {
    --收集目标
    NORMAL = 1,  
    --影子目标
    SHADOW = 2,
    -- 连带收集
    COLLAB = 3,
}

UBFInteractiveSelectFlag = {
    FORBIDDEN = 0,
    VERY_LOW = 1,
    LOW = 2,
    NORMAL = 3,
    HIGH = 4,
    VERY_HIGH = 5,
}

UBFInteractiveSelectorRangeMode = {
    --活动区域内
    IN_BORDER = 1,
    --全部
    ALL = 2,
}

-- UBFInteractiveSelectPrinciple = {
--     --默认原则，选就选，不选拉到
--     NORMAL = 1,
--     --沉船原则，如果被选上，整个格子包括自身全不能被选
--     WRECK = 2,
--     --领导原则，如果没被选上，整个格子全不能被选（不支持）
--     LEADER = 3,
-- }

UBFInteractiveSelectUpgradeMode = {
    --重力沿线
    GRAVITY_LINE = 1,
    --自身属性
    SEFL_ATTR = 2,
    --棋盘r坐标
    AXIS_FRONT = 3
}

UBFInteractiveOrderMode = {
    --不进行特殊排序
    NONE = 1, 
    --随机
    RANDOM = 2, 
    --坐标从左到右 从上到下
    COORDINATE = 3,
    --表盘，顺时针，逆时针
    DIAL = 4,
}

UBFTargetInitCountMode = {
    -- 使用关卡配置中的静态值
    USE_LEVEL_CONFIG = 1,
    -- 统计棋盘特定ItemType的数量
    COUNT_BY_ITEM_TYPE = 2,
    -- 统计棋盘特定ItemType每个level之合数量
    COUNT_BY_ITEM_TYPE_TIMES_LEVEL = 3,
}

UBFScoreAdditionMode = {
    --当创建
    ON_CREATE = 1,
}


UBFShadawTargetActionMode = {
    NUM_CHANGE = 1,             --数字变化 需要自定义数字
    FIELD_DIFF = 2,             --字段变化
    CUR_LEVEL = 3,              --取当前等级
    PATH_POS = 4,               --取在路径上的位置
    INIT_PATH_LEN = 6,          --路径消失的长度
    PATH_POS_TO_END = 7,        -- 当前距离路径终点的距离
}


-- 难度调节模式
ProductItemDiffChangeMode = {
	kNone = 0 ,
	kDropEff = 1 ,
	kDropEffAndBird = 2 ,
	kAddColor = 3 , -- 颜色干预
	kAIAddColor = 4 , -- FUUU颜色调节。产品管7~9叫 FUUU2
	kNewFUUU = 5, -- Fuuu3
	kDecreaseColor = 6, -- 负向干预
	kAIDecreaseColor = 7,
	kAIADColor = 8,
	kAld2023 = 9,
	-- AI组外部干预
	kAIDiff = 10,
	kUBFuuu = 11,
}


-- 连胜玩法的逻辑类型
UBFWinningStreakLogicType = {
	kAddScore = "addScore" ,                                          --加分
	kAddEffectOnBoard = "addEffectOnBoard" ,                          --往棋盘扔特效、障碍
	kAddPropToBar = "addPropToBar" ,                                  --往道具栏扔临时道具
	kAddRewardBoxArfterPassLevel = "addRewardBoxArfterPassLevel" ,    --过关后获得额外奖励（形式不限，比如攒搜集物开宝箱） 
}

UBInitRuleScene = {
    PREV_BUILD = 0, --最前面，再颜色等初始化的前面
    BUILD = 1, --正常的障碍首次出现的构建，再颜色初始化后面
    RUNTIME = 2, --运行时，当这个障碍有新的出现的时候，需要刷新构建状态
}


-- UBFuuu调节的活动篡改模式
-----------------------------------

_G.UBFuuuConfigNameId = {
    ["ubfuuu_ds_avg_map"] = 1,
    ["ubfuuu_activity_index_map"] = 2,
    ["ubfuuu_payment_index_map"] = 3,
    ["ubfuuu_diff_index_map"] = 4,
    ["ubfuuu_final_diff_map"] = 5,
    ["ubfuuu_player_ability_map"] = 6,
    ["ubfuuu_baodi_count_map"] = 7,
    ["ubfuuu_player_ability_fixvalue_map"] = 8,
    ---------------------------
    ["ubfuuu_payment_area_fix_by_return_user"] = "CA3",
    ["ubfuuu_activity_index_limit_by_return_user"] = "CA4",
    ["ubfuuu_super_magic_bird_charge_diff"] = "CA5",
    ["ubfuuu_activity_index_fix_rule"] = "CA6",
    ["ubfuuu_callback_level_new_diff"] = "CA7",
    ["ubfuuu_activity_index_map_by_28activeday_playcount_v202604"] = "CA8",
    ["ubfuuu_diff_index_map_nohardmark"] = "CA9",
    ["ubfuuu_activity_index_map_by_returnday_playcount"] = "CA10",
    ["pet_wing_mapping"] = "CA11",
}

_G.UBFuuuFixType = {
    kActivityIndex = "activityIndex",                                   --篡改 活跃指数
    kPaymentIndex = "paymentIndex",                                     --篡改 付费指数
    kDiffIndex = "diffIndex",                                           --篡改 难度指数
    kDesiredDiffAvgBeforeBaodi = "desiredDiffAvgBeforeBaodi",           --篡改 保底前生效预期难度
    kFixedDesiredDiffAvg = "fixedDesiredDiffAvg",                       --篡改 生效预期难度
    kDiffFix = "diffFix",                                               --篡改 难度偏移档位 DiffFix
    kAddStepFix = "addStepFix",                                         --篡改 加步数时的干预逻辑
    kPreAddStepIntervalFix = "preAddStepIntervalFix",                   --篡改 前置加三步区间的干预逻辑
    kPostAddStepIntervalFix = "postAddStepIntervalFix",                 --篡改 后置加步数区间的干预逻辑
    kSelfFeedbackEnableFlag = "selfFeedbackEnableFlag",                 --强行设置 自反馈的采集状态
    kSelfFeedbackPoolkey = "selfFeedbackPoolkey",                       --设置 自反馈的采集池的key（按key单独开一个统计池）
    kDesiredStep = "desiredStep",                                       --篡改 期望步数
    kStepFix = "stepFix",                                               --篡改 步数偏移档位 stepFix
    kReplaceUBFuuuConfigFile = "replaceUBFuuuConfigFile_v2",               --替换 UBFuuu的配置文件
}

require("ubf.UBFPlay.declares.SelfFeedbackPoolkey")

_G.SelfFeedbackPoolType = {
    kOnSelect = "select", 
    kOnCollect = "collect", 
    kOnSelectAndCollect = "select_and_collect"
}

_G.UBFuuuFixMode = {
    kSetVaule = "setValue",                               --直接设值
    kaddVaule = "addValue",                               --在原值上加上value
    kMultiplyVaule = "multiplyValue",                     --在原值上乘以value
    kMapping = "mapping",                                 --此模式下，value为配置表的key，使用对应的配置表进行查表操作，传入原值，获取并使用返回值
    kMappingAddVaule = "mappingAddValue",                 --此模式下，value为配置表的key，使用对应的配置表进行查表操作，传入原值，获取返回值，并将返回值加到原值上
    kMappingMultiplyValue = "mappingMultiplyValue",       --此模式下，value为配置表的key，使用对应的配置表进行查表操作，传入原值，获取返回值，并将返回值乘到原值上
}

_G.UBFuuuAddStepAdjustMode = {
    kDoNothing = "doNothing",                             --什么也不做，即不干预
    kLockLastDs = "lockLastDs",                           --锁定为之前的强度，一直保持这个强度干预，即强度不再计算更新
    kAddMaxDiffMoveByStep = "addMaxDiffMoveByStep",       --每多走一步，MaxDiffMove就加1
    kAddMaxDiffMoveByFixedValue = "addMaxDiffMoveByFixedValue", --将 MaxDiffMove 增加固定值
    kLockMaxDiffMove = "lockMaxDiffMove",                 --将 MaxDiffMove 锁定到固定目标值
}
------------------------------------

--充能模式
_G.UBFChargeMode ={
    BY_STEP = 1,    --按步数充能
    COLLECT_TARGET = 2,  --按收集计数充能
}

--格子标记类型
_G.UBFGridFlagType = {
    kEffect="Prop:Effect",
    kMagicBird="Prop:MagicBird",
    kFirecracker="Prop:Firecracker",
    kSuperMagicBird="SuperMagicBird",
}

--玩家操作类型
_G.UBFPlayerOperateType = {
    kAll = 0,
    kSwap = 1,
    kProp = 2,
}

--FUUU进度判断模式
_G.UBFuuuProgressJudgmentMode = {
    --落后
    kBehind = 1,
    --领先
    kAhead = 2,
}

--创建itembuilder的模式
_G.UBFItemBuilderCreateMode = {
    FromStandardConfig = 1,   --从标准配置创建
    FromActivityConfig = 2,   --从活动配置创建
}

--选位置模式
_G.UBFSelectPosMode = {
    ByGridScore = 1,    --根据格子分数选位置
}

--评分排序模式
_G.UBFScoreSortMode = {
    Descending = 0,     --降序
    Ascending = 1,      --升序
}


_G.UBFFastUseEnum = {
    operationDataKey = "oDatas",
    operationLogsKey = "oLogs",
    gameEnvKey = "gEnv",
    runtimeLogKey = "rtl",
    debugInfoKey = "debugInfo",
    playLogsKey = "playLogs",
    dcDataKey = "dcData",
    adjustDataKey = "adjustData",
}

-- _G.MACRO_POS_STRIDE = 10000 -- 不要删，这个注释为了方便搜索宏定义
--相对坐标会出现负数，所以坐标在不同象限的取值范围在[1,5000)
_G["MACRO_" .."POS_" .. "STRIDE"] = 10000
_G["MACRO_" .."POS_" .. "DIMENSION"] = _G["MACRO_" .."POS_" .. "STRIDE"] * 10000
-- int 最大 2147483647 ，目前因为dimension只有1，所以不会被撑爆