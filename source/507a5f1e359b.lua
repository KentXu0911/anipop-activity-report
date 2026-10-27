local Manager = class("SuperMagicBirdGiftManager")

local PlayerStage = {
    NON_FULL = "NON_FULL",
    FULL_NOT_COLOR = "FULL_NOT_COLOR",
    FULL_COLOR = "FULL_COLOR",
}
local ALL_ACTIVATION_TAG_IDS = { 0, 1, 2, 3, 4, 5 }
local ALL_LIVENESS_TAG_IDS = { 0, 1, 2, 3, 4, 5, 6, 7 }
local ALL_PAY_TAG_IDS = { 1, 2, 3, 4, 5, 6, 7 }

local TestConfig = {
    periodId = "test-period-8079-1",
    collectionId = "192",
    baseCap = 6,
    dailyPassLevelLimit = 5,

    -- 分群规则按配置顺序匹配，命中第一条后停止：
    -- playerStage: 玩家阶段，分别为非满级、满级非满彩、满级满彩。
    -- activationTagIds: 活跃类型白名单，0无、1低活跃、2回流、3新增、4普通活跃、5高活跃。
    -- livenessTagIds: 活跃度白名单，0无、1新用户、2回流、3低、4中低、5中、6中高、7高。
    -- payTagIds: 服务端付费档白名单，1无付费、2低、3中低、4中高、5/6/7高付费4/5/6档。
    -- startLevel/endLevel: 非满级关卡段闭区间，支持数字、top 和 top-N。
    -- minStar/maxStar: 满级非满彩玩家的进关前历史星级闭区间。
    -- countPerBird: 命中规则后，每消除一只真实超鸟获得的基础收集物数量。
    countPerBirdRules = {
        -- 非满级：按关卡段分三档。
        {
            playerStage = PlayerStage.NON_FULL,
            activationTagIds = ALL_ACTIVATION_TAG_IDS,
            livenessTagIds = ALL_LIVENESS_TAG_IDS,
            payTagIds = ALL_PAY_TAG_IDS,
            startLevel = "1",
            endLevel = "4000",
            countPerBird = 1,
        },
        {
            playerStage = PlayerStage.NON_FULL,
            activationTagIds = ALL_ACTIVATION_TAG_IDS,
            livenessTagIds = ALL_LIVENESS_TAG_IDS,
            payTagIds = ALL_PAY_TAG_IDS,
            startLevel = "4001",
            endLevel = "top-90",
            countPerBird = 2,
        },
        {
            playerStage = PlayerStage.NON_FULL,
            activationTagIds = ALL_ACTIVATION_TAG_IDS,
            livenessTagIds = ALL_LIVENESS_TAG_IDS,
            payTagIds = ALL_PAY_TAG_IDS,
            startLevel = "top-89",
            endLevel = "top",
            countPerBird = 3,
        },
        -- 满级非满彩：按进关前历史星级分三档。
        {
            playerStage = PlayerStage.FULL_NOT_COLOR,
            activationTagIds = ALL_ACTIVATION_TAG_IDS,
            livenessTagIds = ALL_LIVENESS_TAG_IDS,
            payTagIds = ALL_PAY_TAG_IDS,
            minStar = 0,
            maxStar = 2,
            countPerBird = 1,
        },
        {
            playerStage = PlayerStage.FULL_NOT_COLOR,
            activationTagIds = ALL_ACTIVATION_TAG_IDS,
            livenessTagIds = ALL_LIVENESS_TAG_IDS,
            payTagIds = ALL_PAY_TAG_IDS,
            minStar = 3,
            maxStar = 3,
            countPerBird = 2,
        },
        {
            playerStage = PlayerStage.FULL_NOT_COLOR,
            activationTagIds = ALL_ACTIVATION_TAG_IDS,
            livenessTagIds = ALL_LIVENESS_TAG_IDS,
            payTagIds = ALL_PAY_TAG_IDS,
            minStar = 4,
            maxStar = 4,
            countPerBird = 3,
        },
        -- 满级满彩：高标签、中标签、其余合法标签依次匹配。
        {
            playerStage = PlayerStage.FULL_COLOR,
            activationTagIds = { 5 },
            livenessTagIds = { 6, 7 },
            payTagIds = { 5, 6, 7 },
            countPerBird = 3,
        },
        {
            playerStage = PlayerStage.FULL_COLOR,
            activationTagIds = { 3, 4, 5 },
            livenessTagIds = { 4, 5, 6, 7 },
            payTagIds = { 3, 4, 5, 6, 7 },
            countPerBird = 2,
        },
        {
            playerStage = PlayerStage.FULL_COLOR,
            activationTagIds = ALL_ACTIVATION_TAG_IDS,
            livenessTagIds = ALL_LIVENESS_TAG_IDS,
            payTagIds = ALL_PAY_TAG_IDS,
            countPerBird = 1,
        },
    },
}

local DAILY_PASS_LEVEL_COUNT_KEY = "superMagicBirdGift_passLevelCount"

local function includes(values, target)
    for _, value in ipairs(values or {}) do
        if value == target then
            return true
        end
    end
    return false
end

local function getPlayerStage()
    local userStateManager = _G.amfBean("UserStateManager")
    if userStateManager:isFMJ() then
        return PlayerStage.NON_FULL
    elseif userStateManager:isColorfulStarFull() then
        return PlayerStage.FULL_COLOR
    end
    return PlayerStage.FULL_NOT_COLOR
end

local function matchesRule(rule, context)
    if rule.playerStage ~= context.playerStage
        or not includes(rule.activationTagIds, context.activationTag)
        or not includes(rule.livenessTagIds, context.livenessTag)
        or not includes(rule.payTagIds, context.payTag) then
        return false
    end

    if context.playerStage == PlayerStage.NON_FULL then
        local startLevel = UBFActHelper:getDropConfigLevelId(rule.startLevel, context.maxLevelId)
        local endLevel = UBFActHelper:getDropConfigLevelId(rule.endLevel, context.maxLevelId)
        return context.levelId >= startLevel and context.levelId <= endLevel
    elseif context.playerStage == PlayerStage.FULL_NOT_COLOR then
        return context.oldStar >= rule.minStar and context.oldStar <= rule.maxStar
    end

    return true
end

local function resolveCountPerBird(levelId, runtime)
    if not levelId or not runtime then return end

    local levelScene = runtime.levelScene
    local context = {
        playerStage = getPlayerStage(),
        activationTag = UserTagManager:getUserTagBySeries(UserTagNameKeyFullMap.kActivation),
        livenessTag = UserTagManager:getUserTagBySeries(UserTagNameKeyFullMap.kBiLivenessTag),
        payTag = UserTagManager:getUserPaymentTag2ServerVersion(),
    }
    if context.playerStage == PlayerStage.NON_FULL then
        context.levelId = UBFActHelper:getHiddenLevelStartNormalLevel(levelId, levelScene)
        context.maxLevelId = _G.amfBean("LevelUnLockManager"):getUserMaxLevelId()
    elseif context.playerStage == PlayerStage.FULL_NOT_COLOR then
        context.oldStar = UBFActHelper:getOldStar(levelId, levelScene)
    end

    local matchedRule
    for _, rule in ipairs(TestConfig.countPerBirdRules) do
        if matchesRule(rule, context) then
            matchedRule = rule
            break
        end
    end

    local countPerBird = matchedRule and matchedRule.countPerBird
    if type(countPerBird) ~= "number" or countPerBird < 0 or countPerBird % 1 ~= 0 then
        return
    end
    return countPerBird
end

local function getDailyPassLevelCount(self)
    return self.dailyDataManager:getLocalDailyData(DAILY_PASS_LEVEL_COUNT_KEY) or 0
end

local function setDailyPassLevelCount(self, count)
    self.dailyDataManager:setLocalDailyData(DAILY_PASS_LEVEL_COUNT_KEY, count)
end

function Manager:initialize()
end

function Manager:setDailyDataManager(dailyDataManager)
    self.dailyDataManager = dailyDataManager
end

function Manager:toggleDebugEnabled()
    self.debugEnabled = self.debugEnabled ~= true
    return self.debugEnabled
end

function Manager:isEnabledInLevel(data)
    if getDailyPassLevelCount(self) >= TestConfig.dailyPassLevelLimit then
        return false
    end
    local superMagicBirdManager = _G.amfBean("SuperMagicBird2024Manager")
    if not superMagicBirdManager
        or not superMagicBirdManager:isEnabledInLevel(data)
        or not superMagicBirdManager:hasSuperPower()
    then
        return false
    end

    if EnvUtil:isDevelopMode() then
        return self.debugEnabled == true
    end

    return false
end

function Manager:getInLevelActData(levelId, runtime)
    if not self:isEnabledInLevel(runtime) then
        return
    end
    local countPerBird = resolveCountPerBird(levelId, runtime)
    if countPerBird == nil then return end

    return {
        periodId = TestConfig.periodId,
        collectionId = TestConfig.collectionId,
        countPerBird = countPerBird,
        baseCap = TestConfig.baseCap,
    }
end

function Manager:updatePassLevelData(data)
    if data and data.settleMentState then
        setDailyPassLevelCount(self, getDailyPassLevelCount(self) + 1)
    end
end

return Manager
