local ItemId = require "amf.feature.localactivity.exploremapgame.const.ExploreMapGameItemId"

local Const = {}

Const.actOpenVersion = 1
Const.actId = 8075
Const.actChName = "秋日拾忆"
Const.actSource = "exploremapgame/Config.lua"
Const.downloadLabels = {'exploremapgame_collection'}

-- 活动配置版本号：产品负责维护在包内，首个版本为 1，活动配置任意变更都需 +1，当期活动开始后不可再修改。
-- mainInfo 请求上报该值；与后端 actInfo 下发的 configVersion 不一致时前端隐藏 icon（见活动侧 Config.isSupport）。
Const.configVersion = 1

Const.moduleName = "mistyClearMap"
Const.gameName = "misty_clear_map"
Const.dcFeature = "misty_clear"

Const.infoPrefix = "userInfo"
Const.configPrefix = "localConfig"
Const.timePrefix = "timeInfo"

Const.localResPath = 'amf/activity/exploremapgame/materials/'
Const.mainLevelCollectionId = 186

Const.ItemId = ItemId

Const.BuffType = {
    SCORE_20 = 1,
    SCORE_50 = 2,
    DOUBLE   = 3,
}

Const.GiftTypeEnum = {
    FLOW = "FLOW",
    RMB_ENERGY = "RMB_ENERGY",
    PROGRESS = "PROGRESS",
    SPRINT = "SPRINT",
    ENDLESS_POWER = "ENDLESS_POWER",
    BATTLE_PASS = "BATTLE_PASS",
    CASH_ENERGY = "CASH_ENERGY", --体力购买面板
}

Const.GiftTitleByGoodsId = {
    [4701] = "超值购买",
    [4702] = "超值购买",
    [4703] = "超值购买",
    [4704] = "超值购买",
    [4705] = "超值购买",
    [4706] = "超值购买",
    [4707] = "超值购买",
    [4708] = "超值购买",
    [4709] = "超值购买",
    [4710] = "超值购买",
    [4711] = "能量多多",
    [4712] = "能量多多",
    [4713] = "能量多多",
    [4714] = "探险专属特惠",
    [4715] = "探险专属特惠",
    [4716] = "探险专属特惠",
    [4717] = "探险专属特惠",
    [4718] = "探险豪礼回馈",
}

function Const.getGiftTitle(goodsId)
    goodsId = tonumber(goodsId)
    return goodsId and Const.GiftTitleByGoodsId[goodsId] or nil
end

Const.FlowGiftJudgeParam = {
    [UsetPaymentTagServer.kNone] = {
        energyNum = 0,
        cashNum = 19,
        passTime = 6,
    },
    [UsetPaymentTagServer.kLow] = {
        energyNum = 5,
        cashNum = 29,
        passTime = 6,
    },
    [UsetPaymentTagServer.kMidLow] = {
        energyNum = 5,
        cashNum = 39,
        passTime = 5,
    },
    [UsetPaymentTagServer.kMidHigh] = {
        energyNum = 5,
        cashNum = 39,
        passTime = 5,
    },
    [UsetPaymentTagServer.kHigh_4] = {
        energyNum = 5,
        cashNum = 59,
        passTime = 4,
    },
    [UsetPaymentTagServer.kHigh_5] = {
        energyNum = 5,
        cashNum = 59,
        passTime = 4,
    },
    [UsetPaymentTagServer.kHigh_6] = {
        energyNum = 5,
        cashNum = 100,
        passTime = 3,
    },
    default = {
        energyNum = 5,
        cashNum = 39,
        passTime = 5,
    },
}

Const.NodeType = {
    OBSTACLE    = "OBSTACLE",
    COLLECT     = "COLLECT",
    STORY       = "STORY",
    -- REWARD_HEAP 是 STORY 的特殊子型（NodeMeta.rewardHeapId > 0 时识别），
    -- 后端仍归 STORY；此处仅供前端区分使用。
    REWARD_HEAP = "REWARD_HEAP",
}

Const.RewardHeapType = {
    NORMAL = "NORMAL",
    STONE  = "STONE",
}

function Const.isStoneRewardHeapType(rewardHeapType)
    return rewardHeapType == Const.RewardHeapType.STONE
end

Const.ExploreTaskActionType = {
    CLEAR_OBSTACLE           = "CLEAR_OBSTACLE",
    FRAGMENT                 = "FRAGMENT",
    COLLECTION               = "COLLECTION",
    REWARD_HEAP_ALL_REWARDED = "REWARD_HEAP_ALL_REWARDED",
    CONSUME_ITEM             = "CONSUME_ITEM",
}

local ObstacleTaskNameByItemId = {
    [Const.ItemId.OBS_THORN_1] = "绿荆棘",
    [Const.ItemId.OBS_HAY] = "草垛",
    [Const.ItemId.OBS_THORN_2] = "黄荆棘",
    [Const.ItemId.OBS_DELIVERY_BOX] = "快递盒",
}

local CollectionTaskNameByItemId = {
    [Const.ItemId.OBS_MUSHROOM_1] = "黄蘑菇",
    [Const.ItemId.OBS_MUSHROOM_2] = "红蘑菇",
}

local function getTaskTargetItemId(taskMeta)
    if type(taskMeta) ~= "table" then return nil end
    return tonumber(taskMeta.targetItemId or taskMeta.itemId)
end

local function getFirstCollectItemId(taskMeta)
    if type(taskMeta) ~= "table" then return nil end
    local collectItems = taskMeta.collectItems or taskMeta.collectItemIds or {}
    local firstItem = collectItems[1]
    if type(firstItem) == "table" then return tonumber(firstItem.itemId) end
    return tonumber(firstItem)
end

local function isItemIdInRange(itemId, minId, maxId)
    return itemId and itemId >= minId and itemId <= maxId
end

function Const.getExploreTaskDesc(actionType, targetCount, taskMeta)
    if type(taskMeta) == "table" and taskMeta.desc and taskMeta.desc ~= "" then
        return taskMeta.desc
    end

    local targetItemId = getTaskTargetItemId(taskMeta)
    local firstCollectItemId = getFirstCollectItemId(taskMeta)

    if actionType == Const.ExploreTaskActionType.CLEAR_OBSTACLE then
        local obstacleName = ObstacleTaskNameByItemId[targetItemId]
        if obstacleName then
            return string.format("清除%d个%s", targetCount or 0, obstacleName)
        end
    elseif actionType == Const.ExploreTaskActionType.COLLECTION then
        local collectionName = CollectionTaskNameByItemId[targetItemId]
        if collectionName then
            return string.format("采集%d次%s", targetCount or 0, collectionName)
        end
        if isItemIdInRange(firstCollectItemId, Const.ItemId.TOOL_1, Const.ItemId.TOOL_5) then
            return string.format("采集%d种探险装备", targetCount or 0)
        elseif isItemIdInRange(firstCollectItemId, Const.ItemId.LEAF_1, Const.ItemId.LEAF_5) then
            return string.format("采集%d种树叶", targetCount or 0)
        elseif isItemIdInRange(firstCollectItemId, Const.ItemId.BUTTERFLY_1, Const.ItemId.BUTTERFLY_5) then
            return string.format("采集%d种蝴蝶标本", targetCount or 0)
        end
    elseif actionType == Const.ExploreTaskActionType.FRAGMENT then
        return "获得照片并修复"
    elseif actionType == Const.ExploreTaskActionType.REWARD_HEAP_ALL_REWARDED then
        return "领取全部石台宝藏奖励"
    elseif actionType == Const.ExploreTaskActionType.CONSUME_ITEM then
        return string.format("扎气球中消耗%d个飞镖", targetCount or 0)
    end

    targetCount = targetCount or 0
    local ActionType = Const.ExploreTaskActionType
    if actionType == ActionType.CLEAR_OBSTACLE then
        return string.format("清除%d个障碍", targetCount)
    elseif actionType == ActionType.FRAGMENT then
        return "获得照片并修复"
    elseif actionType == ActionType.COLLECTION then
        return string.format("采集%d种收集物", targetCount)
    elseif actionType == ActionType.REWARD_HEAP_ALL_REWARDED then
        return "领取全部石台宝藏奖励"
    elseif actionType == ActionType.CONSUME_ITEM then
        return string.format("扎气球中消耗%d个飞镖", targetCount)
    end
    return "完成探索任务"
end

return Const
