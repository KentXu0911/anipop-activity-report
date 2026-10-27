local DailyLevelConst = require "amf.feature.localactivity.dailylevel.config.DailyLevelConst"

local MockData = {}

local DAY_MS = 24 * 3600 * 1000
local PACKAGE_PRICE_META_LIST = {
    {packageId = 1001, buyType = "TICKET", minBuyTimes = 2},
    {packageId = 1003, buyType = "TICKET", minBuyTimes = 5},
    {packageId = 1004, buyType = "TICKET", minBuyTimes = -1},
    {packageId = 1002, buyType = "DOUBLE_COLLECT", minBuyTimes = 1},
    {packageId = 1005, buyType = "DOUBLE_COLLECT", minBuyTimes = 4},
    {packageId = 1006, buyType = "DOUBLE_COLLECT", minBuyTimes = -1},
}
local MOCK_COLLECTION_ID = 0 -- 占位

local function getBaseTime()
    local now = TimeKit:timeInMillis()
    return now
end

function MockData.setTestScenario(scenario)
    MockData._testScenario = scenario
    MockData._useNextMainInfo = false
end

function MockData.setEnabled(enabled)
    MockData._enabled = enabled == true
end

function MockData.isEnabled()
    return MockData._enabled == true
end

function MockData.clearTestScenario()
    MockData._testScenario = nil
end

function MockData.getPackagePull()
    local now = TimeKit:timeInMillis()
    local displayablePackages = {}
    local packageMetas = {}
    for index, meta in ipairs(PACKAGE_PRICE_META_LIST) do
        local packageId = meta.packageId
        table.insert(displayablePackages, {
            module = meta.buyType,
            packageId = packageId,
            goodsId = packageId,
            buyType = meta.buyType,
            type = meta.buyType,
            endTs = now + DAY_MS,
            extra = table.serialize({type = meta.buyType, actId = DailyLevelConst.ACT_ID}),
            buyLimitUnits = {{beginTs = -1, endTs = -1, alreadyBuyTimes = 0, totalCanBuyTimes = 99}},
        })
        local price = index * 100
        packageMetas[tostring(packageId)] = {
            packageMeta = table.serialize({
                id = packageId,
                name = "每日夺宝梯度礼包" .. tostring(index),
                items = tostring(MOCK_COLLECTION_ID)..":1",
                priceType = 2,
                priceBase = price,
                priceOriginal = price,
                priceSelling = price,
                beginTs = 0,
                endTs = 0,
                limit = "0",
            }),
        }
    end
    return {
        displayablePackages = displayablePackages,
        packageMetas = packageMetas,
        moduleExtraMap = {},
    }
end

function MockData.getMainInfo(reqParams)
    local now = getBaseTime()
    local packagesPullResponse = nil
    local testScenario = MockData._testScenario or {}
    local phase = reqParams and reqParams.mockPhase or testScenario.phase or "main"
    local mainEndTime = now + 6 * DAY_MS
    local endTime = now + 7 * DAY_MS
    if phase == "award" then
        mainEndTime = now - DAY_MS
        endTime = now + DAY_MS
    end

    if reqParams and reqParams.packagesPullRequest then
        packagesPullResponse = MockData.getPackagePull()
    end

    local dataBean = {
        beginTime = now - DAY_MS,
        canDoubleCollect = false,
        collectNum = 0,
        configVersion = 1,
        endTime = endTime,
        freeCanPlayNum = 0,
        goldTicketNum = 0,
        group = "ON",
        inLevel = false,
        levelCycleStartId = 0,
        logicVersion = DailyLevelConst.VERSION,
        mainEndTime = mainEndTime,
        maxClaimedBoxId = 0,
        maxUnlockedBoxId = 0,
        normalTicketNum = 0,
        payCanPlayNum = 0,
        periodId = 1,
        rewardBlocked = false,
        rewardPeriod = phase == "award",
        startLevelIds = {},
        weekend = false,
        buyPackageMap = {},
    }
    local scenarioDataBean = MockData._useNextMainInfo and testScenario.nextDataBean
        or testScenario.dataBean
    for key, value in pairs(scenarioDataBean or {}) do
        dataBean[key] = value
    end

    local localConfig = {
        packagePriceMetaList = PACKAGE_PRICE_META_LIST,
        boxConfigList = {
            {id = 1, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 14, num = 1}}},
            {id = 2, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 2, num = 1000}}},
            {id = 3, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 10, rewards = {{itemId = DailyLevelConst.NORMAL_TICKET_ID, num = 1}}},
            {id = 4, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 14, num = 1}}},
            {id = 5, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 2, num = 1500}}},
            {id = 6, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 10, rewards = {{itemId = DailyLevelConst.GOLD_TICKET_ID, num = 1}}},
            {id = 7, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 14, num = 2}}},
            {id = 8, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 2, num = 2000}}},
            {id = 9, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 10, rewards = {{itemId = DailyLevelConst.NORMAL_TICKET_ID, num = 2}}},
            {id = 10, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 14, num = 2}}},
            {id = 11, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 2, num = 2500}}},
            {id = 12, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 10, rewards = {{itemId = DailyLevelConst.GOLD_TICKET_ID, num = 1}}},
            {id = 13, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 14, num = 3}}},
            {id = 14, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 2, num = 3000}}},
            {id = 15, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 10, rewards = {{itemId = DailyLevelConst.NORMAL_TICKET_ID, num = 3}}},
            {id = 16, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 14, num = 3}}},
            {id = 17, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 2, num = 3500}}},
            {id = 18, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 10, rewards = {{itemId = DailyLevelConst.GOLD_TICKET_ID, num = 2}}},
            {id = 19, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 14, num = 4}}},
            {id = 20, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 2, num = 4000}}},
            {id = 21, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 10, rewards = {{itemId = DailyLevelConst.NORMAL_TICKET_ID, num = 4}}},
            {id = 22, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 14, num = 4}}},
            {id = 23, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 2, num = 4500}}},
            {id = 24, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 10, rewards = {{itemId = DailyLevelConst.GOLD_TICKET_ID, num = 2}}},
            {id = 25, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 14, num = 5}}},
            {id = 26, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 2, num = 5000}}},
            {id = 27, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 10, rewards = {{itemId = DailyLevelConst.NORMAL_TICKET_ID, num = 5}}},
            {id = 28, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 14, num = 5}}},
            {id = 29, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 2, num = 5500}}},
            {id = 30, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 10, rewards = {{itemId = DailyLevelConst.GOLD_TICKET_ID, num = 3}}},
        },
        boxCycleBeginId = 21,
        configVersion = 1,
        goldRewardPoolPreview = {
            {itemId = 14, num = 3},
            {itemId = 2, num = 10000},
        },
        normalRewardPoolPreview = {
            {itemId = 14, num = 1},
            {itemId = 2, num = 1000},
        },
    }
    for key, value in pairs(testScenario.localConfig or {}) do
        localConfig[key] = value
    end

    return {
        dataBean = dataBean,
        serverVersionedConfig = {
            serverMd5 = "daily_level_mock_v1",
            config = table.serialize(localConfig),
        },
        packagesPullResponse = packagesPullResponse,
    }
end

function MockData.getMainInfoErrorCode()
    local testScenario = MockData._testScenario or {}
    if MockData._useNextMainInfo then
        return testScenario.nextMainInfoErrorCode
    end
    return testScenario.mainInfoErrorCode
end

function MockData.getBoxReward(reqParams)
    local testScenario = MockData._testScenario
    if testScenario and testScenario.boxReward then
        return testScenario.boxReward
    end
    local idList = {11, 12}
    local maxClaimedBoxId = idList[#idList]
    local boxRewardList = {}

    for _, id in ipairs(idList) do
        local rewards = {
            {itemId = DailyLevelConst.GOLD_TICKET_ID, num = 10},
            {itemId = DailyLevelConst.NORMAL_TICKET_ID, num = 12},
            {itemId = 14, num = id},
            {itemId = 2, num = id * 1000},
            {itemId = 14, num = id},
            {itemId = 2, num = id * 1000},
            {itemId = 14, num = id},
            {itemId = 2, num = id * 1000},
            {itemId = 14, num = id},
            {itemId = 2, num = id * 1000},
        }
        table.insert(boxRewardList, {
            id = id,
            rewardList = rewards,
        })
    end

    return {
        boxRewardList = boxRewardList,
        maxClaimedBoxId = maxClaimedBoxId,
    }
end

function MockData.getFinalReward(reqParams)
    local now = TimeKit:timeInMillis()
    local periodId = reqParams and reqParams.periodId or 1
    local testScenario = MockData._testScenario or {}
    MockData._useNextMainInfo = true
    local settledRewardsInfo = testScenario.settledRewardsInfo or {
        {
            originId = DailyLevelConst.GOLD_TICKET_ID,
            rewards = {{itemId = 14, num = 3}},
        },
        {
            originId = DailyLevelConst.NORMAL_TICKET_ID,
            rewards = {{itemId = 2, num = 3000}},
        },
    }
    return {
        lastPeriodSettleData = {
            periodId = periodId,
            beginTime = now - 8 * DAY_MS,
            mainEndTime = now - DAY_MS,
            settledRewardsInfo = settledRewardsInfo,
        },
    }
end

return MockData
