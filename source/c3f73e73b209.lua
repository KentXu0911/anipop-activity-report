local ActivityTestUtils = require "amf.middleware.activity.util.ActivityTestUtils"
local DailyLevelConst = require "amf.feature.localactivity.dailylevel.config.DailyLevelConst"
local ActInfo = require "amf.feature.localactivity.dailylevel.model.ActInfo"
local MockData = require "amf.feature.localactivity.dailylevel.http.MockData"

local TestUtils = class("DailyLevelTestUtils", ActivityTestUtils)

local DAY_MS = 24 * 3600 * 1000
local TEST_PRIZE_REWARD_IDS = {10244, 10245, 10246, 10247, 10248}
local TEST_BOX_CONFIG = {
    {id = 1, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 14, num = 1}}},
    {id = 2, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 2, num = 1000}}},
    {id = 3, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 10, rewards = {{itemId = DailyLevelConst.NORMAL_TICKET_ID, num = 1}}},
    {id = 4, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 14, num = 2}}},
    {id = 5, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 2, num = 2000}}},
    {id = 6, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 10, rewards = {{itemId = DailyLevelConst.GOLD_TICKET_ID, num = 1}}},
    {id = 7, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 14, num = 3}}},
    {id = 8, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 2, num = 3000}}},
    {id = 9, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 10, rewards = {{itemId = DailyLevelConst.NORMAL_TICKET_ID, num = 2}}},
    {id = 10, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 10, rewards = {{itemId = DailyLevelConst.GOLD_TICKET_ID, num = 2}}},
    {id = 11, type = DailyLevelConst.BoxType.NORMAL, target = 5, rewards = {{itemId = 14, num = 1}}},
    {id = 12, type = DailyLevelConst.BoxType.NORMAL, target = 10, rewards = {{itemId = 2, num = 1000}}},
    {id = 13, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 15, rewards = {{itemId = DailyLevelConst.NORMAL_TICKET_ID, num = 1}}},
    {id = 14, type = DailyLevelConst.BoxType.NORMAL, target = 20, rewards = {{itemId = 14, num = 2}}},
    {id = 15, type = DailyLevelConst.BoxType.NORMAL, target = 25, rewards = {{itemId = 2, num = 2000}}},
    {id = 16, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 30, rewards = {{itemId = DailyLevelConst.GOLD_TICKET_ID, num = 1}}},
    {id = 17, type = DailyLevelConst.BoxType.NORMAL, target = 35, rewards = {{itemId = 14, num = 3}}},
    {id = 18, type = DailyLevelConst.BoxType.NORMAL, target = 40, rewards = {{itemId = 2, num = 3000}}},
    {id = 19, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 45, rewards = {{itemId = DailyLevelConst.NORMAL_TICKET_ID, num = 2}}},
    {id = 20, type = DailyLevelConst.BoxType.GRAND_REWARD, target = 50, rewards = {{itemId = DailyLevelConst.GOLD_TICKET_ID, num = 2}}},
}

local function valueOrDefault(value, default)
    if value == nil then return default end
    return value
end

local function getClaimableBoxIdForTest(collectNum)
    local remainCollectNum = math.max(tonumber(collectNum) or 0, 0)
    local maxBoxId = 0
    for boxId = 1, 10 do
        remainCollectNum = remainCollectNum - TEST_BOX_CONFIG[boxId].target
        if remainCollectNum < 0 then return maxBoxId end
        maxBoxId = boxId
    end
    local cycleIndex = 11
    while true do
        local configIndex = 11 + (cycleIndex - 11) % 10
        remainCollectNum = remainCollectNum - TEST_BOX_CONFIG[configIndex].target
        if remainCollectNum < 0 then return maxBoxId end
        maxBoxId = cycleIndex
        cycleIndex = cycleIndex + 1
    end
end

local function getBoxConfigForTest(boxId)
    if boxId <= 10 then return TEST_BOX_CONFIG[boxId] end
    return TEST_BOX_CONFIG[11 + (boxId - 11) % 10]
end

function TestUtils:init()
    ActivityTestUtils.init(self)
    self._mgr = _G.amfBean("DailyLevelMgr")
end

function TestUtils:getMainPanelVM()
    return self.mainPanel and self.mainPanel:getViewModel()
end

function TestUtils:applyScenario(config)
    local vm = self:getMainPanelVM()
    if not vm or vm.isDisposed or vm:isLocked() then
        CommonTip:showTip("当前流程未结束，请稍后重试")
        return nil
    end

    local now = TimeKit:timeInMillis()
    local isAward = config.phase == "award"
    local dataBean = {
        logicVersion = DailyLevelConst.VERSION,
        configVersion = 1,
        periodId = config.periodId or 10001,
        group = "ON",
        beginTime = config.beginTime or now - 7 * DAY_MS,
        mainEndTime = config.mainEndTime or (isAward and now - DAY_MS or now + DAY_MS),
        endTime = config.endTime or now + 2 * DAY_MS,
        canDoubleCollect = false, -- 当前客户端未使用
        collectNum = valueOrDefault(config.collectNum, 0),
        inLevel = false, -- 当前客户端未使用
        levelCycleStartId = 0, -- 当前客户端未使用
        maxClaimedBoxId = valueOrDefault(config.maxClaimedBoxId, 0),
        maxUnlockedBoxId = 0, -- 当前客户端未使用
        goldTicketNum = valueOrDefault(config.goldTicketNum, 2),
        normalTicketNum = valueOrDefault(config.normalTicketNum, 3),
        freeCanPlayNum = valueOrDefault(config.freeCanPlayNum, self._mgr:getDataValue("freeCanPlayNum", 0)),
        payCanPlayNum = valueOrDefault(config.payCanPlayNum, self._mgr:getDataValue("payCanPlayNum", 0)),
        rewardBlocked = false, -- 当前客户端未使用
        rewardPeriod = isAward, -- 当前客户端暂时仍根据活动时间判断阶段
        startLevelIds = {}, -- 当前客户端未使用
        weekend = false, -- 当前客户端未使用
        buyPackageMap = table.clone(config.buyPackageMap or {}),
        fromServer = true, -- 客户端本地标记，非主 info 字段
    }
    local localConfig = {
        boxConfigList = TEST_BOX_CONFIG,
        boxCycleBeginId = 11,
        configVersion = 1,
        goldRewardPoolPreview = {{itemId = 14, num = 10}},
        normalRewardPoolPreview = {{itemId = 14, num = 1}},
        packagePriceMetaList = {
            {packageId = 1001, buyType = "TICKET", minBuyTimes = 2},
            {packageId = 1003, buyType = "TICKET", minBuyTimes = -1},
            {packageId = 1002, buyType = "DOUBLE_COLLECT", minBuyTimes = 1},
            {packageId = 1004, buyType = "DOUBLE_COLLECT", minBuyTimes = -1},
        },
    }
    local rewardList = config.rewardList or {
        {itemId = DailyLevelConst.GOLD_TICKET_ID, num = 8},
        {itemId = DailyLevelConst.NORMAL_TICKET_ID, num = 7},
        {itemId = 14, num = 1},
    }
    local boxRewardList = {}
    for boxId = dataBean.maxClaimedBoxId + 1, tonumber(config.nextClaimedBoxId) or dataBean.maxClaimedBoxId do
        table.insert(boxRewardList, {
            id = boxId,
            rewardList = table.clone(rewardList),
        })
    end

    local mockScenario = {
        boxReward = {
            boxRewardList = boxRewardList,
            maxClaimedBoxId = config.nextClaimedBoxId,
        },
        settledRewardsInfo = config.settledRewardsInfo,
    }
    if config.nextMainInfoDataBean then
        mockScenario.phase = "main"
        mockScenario.dataBean = config.nextMainInfoDataBean
        mockScenario.localConfig = localConfig
    end
    MockData.setTestScenario(mockScenario)
    ActInfo:syncMainInfo(dataBean)
    self._mgr._model:setValue("data", dataBean)
    self._mgr._model:setValue("localConfig", localConfig)
    vm.curLevelCollectNum = math.max(tonumber(config.curLevelCollectNum) or 0, 0)
    vm:refreshAllView(config.usePreviousProgress == true)
    return vm
end

function TestUtils:setWeekendForTest(isWeekendValue)
    if not self.realIsWeekend then
        self.realIsWeekend = _G.isWeekend
    end
    _G.isWeekend = function()
        return isWeekendValue == true
    end
end

function TestUtils:createNextPeriodData(periodId)
    local now = TimeKit:timeInMillis()
    return {
        logicVersion = DailyLevelConst.VERSION,
        configVersion = 1,
        periodId = periodId,
        group = "ON",
        beginTime = now - DAY_MS,
        mainEndTime = now + 6 * DAY_MS,
        endTime = now + 7 * DAY_MS,
        canDoubleCollect = false,
        collectNum = 0,
        inLevel = false,
        levelCycleStartId = 0,
        maxClaimedBoxId = 0,
        maxUnlockedBoxId = 0,
        goldTicketNum = 0,
        normalTicketNum = 0,
        freeCanPlayNum = 1,
        payCanPlayNum = 0,
        rewardBlocked = false,
        rewardPeriod = false,
        startLevelIds = {},
        weekend = false,
        buyPackageMap = {},
    }
end

function TestUtils:buildFlowScenario(config)
    local periodId = config.periodId
    local hasTicket = config.hasTicket == true
    local hasBox = config.hasBox == true
    local settledRewardsInfo = {}
    if hasTicket then
        settledRewardsInfo = {
            {originId = DailyLevelConst.GOLD_TICKET_ID, rewards = {{itemId = 14, num = 3}}},
            {originId = DailyLevelConst.NORMAL_TICKET_ID, rewards = {{itemId = 2, num = 3000}}},
        }
    end
    local now = TimeKit:timeInMillis()
    local isAward = config.phase == "award"
    local dataBean = self:createNextPeriodData(periodId)
    dataBean.beginTime = now - 7 * DAY_MS
    dataBean.mainEndTime = isAward and now - DAY_MS or now + DAY_MS
    dataBean.endTime = now + 2 * DAY_MS
    dataBean.rewardPeriod = isAward
    dataBean.collectNum = config.claimAllFixedBoxes and 650 or (hasBox and 105 or 100)
    dataBean.maxClaimedBoxId = config.claimAllFixedBoxes and 0 or 10
    dataBean.goldTicketNum = hasTicket and 2 or 0
    dataBean.normalTicketNum = hasTicket and 3 or 0
    local boxRewardList = {}
    if config.claimAllFixedBoxes then
        local maxClaimableBoxId = getClaimableBoxIdForTest(dataBean.collectNum)
        for boxId = 1, maxClaimableBoxId do
            local boxConfig = getBoxConfigForTest(boxId)
            table.insert(boxRewardList, {
                id = boxId,
                rewardList = table.clone(boxConfig.rewards),
            })
        end
    elseif hasBox then
        table.insert(boxRewardList, {
            id = 11,
            rewardList = {{itemId = 14, num = 1}},
        })
    end
    return {
        phase = config.phase,
        dataBean = dataBean,
        settledRewardsInfo = settledRewardsInfo,
        nextDataBean = self:createNextPeriodData(periodId + 1),
        nextMainInfoErrorCode = config.nextMainInfoErrorCode,
        localConfig = {
            boxConfigList = TEST_BOX_CONFIG,
            boxCycleBeginId = 11,
            configVersion = 1,
            packagePriceMetaList = {
                {packageId = 1001, buyType = "TICKET", minBuyTimes = -1},
                {packageId = 1002, buyType = "DOUBLE_COLLECT", minBuyTimes = -1},
            },
        },
        boxReward = {
            boxRewardList = boxRewardList,
            maxClaimedBoxId = config.claimAllFixedBoxes and getClaimableBoxIdForTest(dataBean.collectNum)
                or (hasBox and 11 or 10),
        },
    }
end

function TestUtils:getFlowCases()
    local cases = {
        {name = "正式期-非周末", phase = "main", weekend = false},
        {name = "正式期-周末", phase = "main", weekend = true},
        {
            name = "正式期-领取全部固定宝箱",
            phase = "main",
            weekend = false,
            claimAllFixedBoxes = true,
        },
        {
            name = "领奖期-有券-下一期无活动",
            phase = "award",
            weekend = false,
            hasTicket = true,
            nextMainInfoErrorCode = DailyLevelConst.MAIN_INFO_ACT_INVALID_ERROR_CODE,
        },
        {
            name = "强弹-无奖励-无下一期",
            phase = "award",
            weekend = false,
            autoPopupAfterClose = true,
            nextMainInfoErrorCode = DailyLevelConst.MAIN_INFO_ACT_INVALID_ERROR_CODE,
        },
    }
    local awardCases = {
        {"领奖期-非周末-无券-无箱", false, false, false},
        {"领奖期-非周末-有券-无箱", false, true, false},
        {"领奖期-非周末-无券-有箱", false, false, true},
        {"领奖期-非周末-有券-有箱", false, true, true},
        {"领奖期-周末-无券-无箱", true, false, false},
        {"领奖期-周末-有券-无箱", true, true, false},
        {"领奖期-周末-无券-有箱", true, false, true},
        {"领奖期-周末-有券-有箱", true, true, true},
    }
    for _, data in ipairs(awardCases) do
        table.insert(cases, {
            name = data[1],
            phase = "award",
            weekend = data[2],
            hasTicket = data[3],
            hasBox = data[4],
        })
    end
    return cases
end

function TestUtils:restoreFlowTestEnvironment()
    MockData.setEnabled(false)
    MockData.clearTestScenario()
    _G.__DailyLevelFlowTestRunning = nil
    if self.realIsWeekend then
        _G.isWeekend = self.realIsWeekend
        self.realIsWeekend = nil
    end
    self._mgr:requestMainInfo(false, true)
end

function TestUtils:runFlowCase(caseData, index)
    if isSafeCocosObj(self.flowCaseListLayer) then
        self.flowCaseListLayer:setVisible(false)
    end
    self:setWeekendForTest(caseData.weekend)
    MockData.setEnabled(true)
    MockData.setTestScenario(self:buildFlowScenario({
        phase = caseData.phase,
        periodId = 1000 + index * 2,
        hasTicket = caseData.hasTicket,
        hasBox = caseData.hasBox,
        claimAllFixedBoxes = caseData.claimAllFixedBoxes,
        nextMainInfoErrorCode = caseData.nextMainInfoErrorCode,
    }))
    _G.__DailyLevelFlowTestRunning = true
    local function closeCallback()
        self:restoreFlowTestEnvironment()
        if isSafeCocosObj(self.flowCaseListLayer) then
            self.flowCaseListLayer:setVisible(true)
        end
    end
    if caseData.autoPopupAfterClose then
        self._mgr:closeAllPanelVM()
        setTimeOut(function()
            self._mgr:openMainPanel({
                loading = true,
                autoPopup = true,
                autoPopupCheck = function()
                    return self._mgr:canPopStage2()
                end,
                closeCallback = closeCallback,
            })
        end, 2)
        return
    end
    self._mgr:requestMainInfo(false, true, false):next(function()
        local DailyLevelMainPanelVM = require "amf.feature.localactivity.dailylevel.view.DailyLevelMainPanelVM"
        local vm = DailyLevelMainPanelVM:create({
            userClick = true,
            closeCallback = closeCallback,
        })
        vm:setLoadResFailCallback(closeCallback)
        vm:popout()
        self._mgr:managePanelVM(vm)
    end, closeCallback)
end

function TestUtils:closeFlowCaseList()
    if isSafeCocosObj(self.flowCaseListLayer) then
        self.flowCaseListLayer:removeFromParentAndCleanup(true)
    end
    self.flowCaseListLayer = nil
end

function TestUtils:showFlowCaseList()
    self:closeFlowCaseList()
    local visibleSize = Director:sharedDirector():getVisibleSize()
    local layer = LayerColor:createWithColor(ccc4(0, 0, 0, 210))
    layer:setContentSize(visibleSize)
    layer:setTouchEnabled(true, 0, true)
    Director:sharedDirector():run():addChild(layer, "topLayer")
    self.flowCaseListLayer = layer

    local panelWidth, panelHeight = 620, 920
    local panel = LayerColor:createWithColor(ccc4(45, 53, 67, 255))
    panel:setContentSize(CCSizeMake(panelWidth, panelHeight))
    panel:setPositionXY((visibleSize.width - panelWidth) / 2, (visibleSize.height - panelHeight) / 2)
    layer:addChild(panel)

    local title = TextField:create("每日夺宝主界面流程", nil, 36)
    title:setAnchorPoint(ccp(0.5, 0.5))
    title:setPositionXY(panelWidth / 2, panelHeight - 55)
    panel:addChild(title)

    local closeBtn = self:_createTestButton("X", ccc3(160, 55, 55), 32, 64, 64)
    closeBtn:setPositionXY(panelWidth - 76, panelHeight - 87)
    closeBtn:addEventListener(DisplayEvents.kTouchTap, function()
        self:closeFlowCaseList()
    end)
    panel:addChild(closeBtn)

    local VerticalScrollable = require "amf.middleware.ui.kit.component.old.VerticalScrollable"
    local scroll = VerticalScrollable:create(panelWidth - 60, panelHeight - 150, true, true)
    scroll:setPositionXY(30, panelHeight - 115)
    panel:addChild(scroll)

    local cases = self:getFlowCases()
    local itemHeight = 76
    local content = Layer:create()
    content:setContentSize(CCSizeMake(panelWidth - 60, #cases * itemHeight))
    for index, caseData in ipairs(cases) do
        local item = self:_createTestButton(caseData.name, ccc3(67, 92, 112), 26, panelWidth - 90, 62)
        item:setPositionXY(15, (index - 1) * itemHeight + 7)
        item:addEventListener(DisplayEvents.kTouchTap, function()
            self:runFlowCase(caseData, index)
        end)
        content:addChild(item)
    end
    scroll:setContent(content)
    content:setPositionY(-content:getContentSize().height)
    scroll:scrollToTop(0)
end

function TestUtils:showPrizeTicketPanel(ticketCount)
    local settledRewardsInfo = {}
    for index = 1, ticketCount do
        local rewardItemId = ticketCount == #TEST_PRIZE_REWARD_IDS
            and TEST_PRIZE_REWARD_IDS[index]
            or (index % 2 == 0 and 2 or 14)
        table.insert(settledRewardsInfo, {
            originId = index % 3 == 0 and DailyLevelConst.GOLD_TICKET_ID or DailyLevelConst.NORMAL_TICKET_ID,
            rewards = {{
                itemId = rewardItemId,
                num = index % 2 == 0 and index * 100 or index,
            }},
        })
    end
    local PrizeTicketPanelVM = require "amf.feature.localactivity.dailylevel.view.PrizeTicketPanelVM"
    local vm = PrizeTicketPanelVM:create({settledRewardsInfo = settledRewardsInfo})
    vm:popout()
    self._mgr:managePanelVM(vm)
end

function TestUtils:showDoubleCollectPanel()
    local GemBoomShowPanelVM = require "amf.feature.localactivity.dailylevel.view.GemBoomShowPanelVM"
    local vm = GemBoomShowPanelVM:create({
        mgr = self._mgr,
        collectNum = 1000,
        collectionItemId = DailyLevelConst.COLLECTION_ID,
        packageId = self._mgr:getPackageIdByBuyType(DailyLevelConst.PackageBuyType.DOUBLE_COLLECT),
    })
    vm:popout()
    self._mgr:managePanelVM(vm)
end

function TestUtils:showWeekendCarnivalPanel(isWeekendValue)
    local WeekendCarnivalPanelVM = require "amf.feature.localactivity.dailylevel.view.WeekendCarnivalPanelVM"
    local vm = WeekendCarnivalPanelVM:create({testIsWeekend = isWeekendValue})
    vm:popout()
    self._mgr:managePanelVM(vm)
end

function TestUtils:showBoxRewardPanel()
    local vm = self:getMainPanelVM()
    if not vm or vm.isDisposed or vm:isLocked() then
        CommonTip:showTip("当前流程未结束，请稍后重试")
        return
    end
    vm:lock()
    vm:showNormalReward({
        {itemId = 14, num = 2},
        {itemId = DailyLevelConst.NORMAL_TICKET_ID, num = 1},
        {itemId = DailyLevelConst.GOLD_TICKET_ID, num = 1},
    }, 5):next(function(displayData)
        if vm.isDisposed or not isSafeCocosObj(vm.view) then return deferred.success() end
        displayData = displayData or {}
        return vm:callViewFunc("playTicketFlyAnimation", displayData.ticketFlyData or {})
    end):next(function()
        if not vm.isDisposed then vm:unlock() end
    end, function()
        if not vm.isDisposed then vm:unlock() end
    end)
end

function TestUtils:showNormalRewardCase(specialCount, normalCount)
    local vm = self:getMainPanelVM()
    if not vm or vm.isDisposed or vm:isLocked() then
        CommonTip:showTip("当前流程未结束，请稍后重试")
        return
    end
    if isSafeCocosObj(self.normalRewardCaseLayer) then
        self.normalRewardCaseLayer:setVisible(false)
    end

    local normalRewards = {
        {itemId = 14, num = 2},
        {itemId = 2, num = 3000},
        {itemId = 4, num = 2},
        {itemId = 10001, num = 2},
        {itemId = 10010, num = 1},
        {itemId = 10011, num = 1},
        {itemId = 10012, num = 1},
        {itemId = 10013, num = 1},
        {itemId = 10014, num = 1},
        {itemId = 10015, num = 1},
    }
    local rewardList = {}
    for index = 1, normalCount do
        table.insert(rewardList, normalRewards[index])
    end
    table.insert(rewardList, {itemId = DailyLevelConst.NORMAL_TICKET_ID, num = 1})
    if specialCount == 2 then
        table.insert(rewardList, {itemId = DailyLevelConst.GOLD_TICKET_ID, num = 1})
    end

    local function finish()
        if not vm.isDisposed then vm:unlock() end
        if isSafeCocosObj(self.normalRewardCaseLayer) then
            self.normalRewardCaseLayer:setVisible(true)
        end
    end
    vm:lock()
    vm:showNormalReward(rewardList, 5):next(function(displayData)
        if vm.isDisposed or not isSafeCocosObj(vm.view) then return deferred.success() end
        displayData = displayData or {}
        return vm:callViewFunc("playTicketFlyAnimation", displayData.ticketFlyData or {})
    end):next(finish, finish)
end

function TestUtils:closeNormalRewardCaseList()
    if isSafeCocosObj(self.normalRewardCaseLayer) then
        self.normalRewardCaseLayer:removeFromParentAndCleanup(true)
    end
    self.normalRewardCaseLayer = nil
end

function TestUtils:showNormalRewardCaseList()
    self:closeNormalRewardCaseList()
    local visibleSize = Director:sharedDirector():getVisibleSize()
    local layer = LayerColor:createWithColor(ccc4(0, 0, 0, 210))
    layer:setContentSize(visibleSize)
    layer:setTouchEnabled(true, 0, true)
    Director:sharedDirector():run():addChild(layer, "topLayer")
    self.normalRewardCaseLayer = layer

    local panelWidth, panelHeight = 620, 920
    local panel = LayerColor:createWithColor(ccc4(45, 53, 67, 255))
    panel:setContentSize(CCSizeMake(panelWidth, panelHeight))
    panel:setPositionXY((visibleSize.width - panelWidth) / 2, (visibleSize.height - panelHeight) / 2)
    layer:addChild(panel)

    local title = TextField:create("宝箱特殊奖励排列测试", nil, 36)
    title:setAnchorPoint(ccp(0.5, 0.5))
    title:setPositionXY(panelWidth / 2, panelHeight - 55)
    panel:addChild(title)

    local closeBtn = self:_createTestButton("X", ccc3(160, 55, 55), 32, 64, 64)
    closeBtn:setPositionXY(panelWidth - 76, panelHeight - 87)
    closeBtn:addEventListener(DisplayEvents.kTouchTap, function()
        self:closeNormalRewardCaseList()
    end)
    panel:addChild(closeBtn)

    local cases = {}
    local normalCounts = {1, 2, 3, 4, 5, 10}
    for specialCount = 1, 2 do
        for _, normalCount in ipairs(normalCounts) do
            table.insert(cases, {
                name = string.format("Special %d 个 / 下方奖励 %d 个", specialCount, normalCount),
                specialCount = specialCount,
                normalCount = normalCount,
            })
        end
    end
    local VerticalScrollable = require "amf.middleware.ui.kit.component.old.VerticalScrollable"
    local scroll = VerticalScrollable:create(panelWidth - 60, panelHeight - 150, true, true)
    scroll:setPositionXY(30, panelHeight - 115)
    panel:addChild(scroll)

    local itemHeight = 76
    local content = Layer:create()
    content:setContentSize(CCSizeMake(panelWidth - 60, #cases * itemHeight))
    for index, caseData in ipairs(cases) do
        local item = self:_createTestButton(caseData.name, ccc3(67, 92, 112), 25, panelWidth - 90, 62)
        item:setPositionXY(15, (index - 1) * itemHeight + 7)
        item:addEventListener(DisplayEvents.kTouchTap, function()
            self:showNormalRewardCase(caseData.specialCount, caseData.normalCount)
        end)
        content:addChild(item)
    end
    scroll:setContent(content)
    content:setPositionY(-content:getContentSize().height)
    scroll:scrollToTop(0)
end

function TestUtils:showRewardTemplateCase(templateType, hasBox, useBgFade)
    if isSafeCocosObj(self.rewardTemplateCaseLayer) then
        self.rewardTemplateCaseLayer:setVisible(false)
    end

    local rewards = {
        {itemId = 14, num = 3},
        {itemId = 2, num = 3000},
        {itemId = 4, num = 2},
        {itemId = 10001, num = 2},
        {itemId = 10010, num = 1},
        {itemId = 10011, num = 1},
        {itemId = 10012, num = 1},
        {itemId = 10013, num = 1},
        {itemId = DailyLevelConst.NORMAL_TICKET_ID, num = 2},
        {itemId = DailyLevelConst.GOLD_TICKET_ID, num = 1},
    }
    local function restoreCaseLayer()
        if isSafeCocosObj(self.rewardTemplateCaseLayer) then
            self.rewardTemplateCaseLayer:setVisible(true)
        end
    end
    local vm
    if templateType == "special" then
        local SpecialShowRewardPanelVM = require "amf.middleware.ui.kit.templates.showrewardpanels.specialshowrewardpanel.vm.SpecialShowRewardPanelVM"
        vm = SpecialShowRewardPanelVM.Builder.new()
            :setTitle("恭喜获得")
            :setSubTitle(string.format("Special %s / %s", hasBox and "有宝箱" or "无宝箱", useBgFade and "背景模糊" or "无背景模糊"))
            :setExtraDesc(hasBox and "点击界面或按返回键测试跳过动画" or "Special 多奖励无宝箱展示")
            :setRewards(rewards)
            :setSpecialRewardId({DailyLevelConst.NORMAL_TICKET_ID, DailyLevelConst.GOLD_TICKET_ID})
            :setSpecialRewardText("特殊奖励")
            :setShowSpecialRewardCount(true)
            :setShowBoxAnim(hasBox)
            :setShowBoxFlyAnim(true)
            :setTapToSkipBoxAnim(hasBox)
            :setSkinType(5)
            :setBgFadeOutDuration(useBgFade and 0.1 or nil)
            :setCloseCallback(restoreCaseLayer)
            :build()
    else
        local CommonShowRewrdPanelVM = require "amf.middleware.ui.kit.templates.showrewardpanels.commonshowrewardpanel.vm.CommonShowRewrdPanelVM"
        vm = CommonShowRewrdPanelVM.Builder.new()
            :setTitle("恭喜获得")
            :setSubTitle(string.format("Common %s / %s", hasBox and "有宝箱" or "无宝箱", useBgFade and "背景模糊" or "无背景模糊"))
            :setExtraDesc(hasBox and "点击界面或按返回键测试跳过动画" or "Common 多奖励无宝箱展示")
            :setRewards(rewards)
            :setNotNeedBox(not hasBox)
            :setShowBoxFlyAnim(true)
            :setTapToSkipBoxAnim(hasBox)
            :setSkinType(5)
            :setBgFadeOutDuration(useBgFade and 0.1 or nil)
            :setCloseCallback(restoreCaseLayer)
            :build()
    end
    vm:setLoadResFailCallback(restoreCaseLayer)
    local popoutEnum = useBgFade and _G.UIConst.PanelPopout.FADEIN or nil
    vm:popout(popoutEnum, true)
    self._mgr:managePanelVM(vm)
end

function TestUtils:closeRewardTemplateCaseList()
    if isSafeCocosObj(self.rewardTemplateCaseLayer) then
        self.rewardTemplateCaseLayer:removeFromParentAndCleanup(true)
    end
    self.rewardTemplateCaseLayer = nil
end

function TestUtils:showRewardTemplateCaseList()
    self:closeRewardTemplateCaseList()
    local visibleSize = Director:sharedDirector():getVisibleSize()
    local layer = LayerColor:createWithColor(ccc4(0, 0, 0, 210))
    layer:setContentSize(visibleSize)
    layer:setTouchEnabled(true, 0, true)
    Director:sharedDirector():run():addChild(layer, "topLayer")
    self.rewardTemplateCaseLayer = layer

    local panelWidth, panelHeight = 620, 920
    local panel = LayerColor:createWithColor(ccc4(45, 53, 67, 255))
    panel:setContentSize(CCSizeMake(panelWidth, panelHeight))
    panel:setPositionXY((visibleSize.width - panelWidth) / 2, (visibleSize.height - panelHeight) / 2)
    layer:addChild(panel)

    local title = TextField:create("恭喜获得模板测试", nil, 36)
    title:setAnchorPoint(ccp(0.5, 0.5))
    title:setPositionXY(panelWidth / 2, panelHeight - 60)
    panel:addChild(title)

    local closeBtn = self:_createTestButton("X", ccc3(160, 55, 55), 32, 64, 64)
    closeBtn:setPositionXY(panelWidth - 76, panelHeight - 92)
    closeBtn:addEventListener(DisplayEvents.kTouchTap, function()
        self:closeRewardTemplateCaseList()
    end)
    panel:addChild(closeBtn)

    local cases = {
        {name = "Common-有宝箱-背景模糊", templateType = "common", hasBox = true, useBgFade = true},
        {name = "Common-有宝箱-无背景模糊", templateType = "common", hasBox = true, useBgFade = false},
        {name = "Common-无宝箱-背景模糊", templateType = "common", hasBox = false, useBgFade = true},
        {name = "Common-无宝箱-无背景模糊", templateType = "common", hasBox = false, useBgFade = false},
        {name = "Special-有宝箱-背景模糊", templateType = "special", hasBox = true, useBgFade = true},
        {name = "Special-有宝箱-无背景模糊", templateType = "special", hasBox = true, useBgFade = false},
        {name = "Special-无宝箱-背景模糊", templateType = "special", hasBox = false, useBgFade = true},
        {name = "Special-无宝箱-无背景模糊", templateType = "special", hasBox = false, useBgFade = false},
    }

    local VerticalScrollable = require "amf.middleware.ui.kit.component.old.VerticalScrollable"
    local scroll = VerticalScrollable:create(panelWidth - 60, panelHeight - 150, true, true)
    scroll:setPositionXY(30, panelHeight - 115)
    panel:addChild(scroll)

    local itemHeight = 100
    local content = Layer:create()
    content:setContentSize(CCSizeMake(panelWidth - 60, #cases * itemHeight))
    for index, caseData in ipairs(cases) do
        local item = self:_createTestButton(caseData.name, ccc3(67, 92, 112), 25, panelWidth - 90, 80)
        item:setPositionXY(15, (index - 1) * itemHeight + 10)
        item:addEventListener(DisplayEvents.kTouchTap, function()
            self:showRewardTemplateCase(caseData.templateType, caseData.hasBox, caseData.useBgFade)
        end)
        content:addChild(item)
    end
    scroll:setContent(content)
    content:setPositionY(-content:getContentSize().height)
    scroll:scrollToTop(0)
end

function TestUtils:playRandomTicketNumAnimation()
    local panel = self.mainPanel
    local treasureBoxNode = panel and panel.treasureBoxNode
    if not panel or panel.isDisposed or not isSafeCocosObj(treasureBoxNode) then
        CommonTip:showTip("主界面宝箱不可用")
        return
    end

    local goldNum = math.random(1, 99)
    local normalNum = math.random(1, 99)
    local originalGoldNum = self._mgr:getDataValue("goldTicketNum", 0)
    local originalNormalNum = self._mgr:getDataValue("normalTicketNum", 0)
    self._ticketNumAnimationTestVersion = (self._ticketNumAnimationTestVersion or 0) + 1
    local version = self._ticketNumAnimationTestVersion
    treasureBoxNode:playTicketNumAnimation({
        {itemId = DailyLevelConst.GOLD_TICKET_ID, num = goldNum},
        {itemId = DailyLevelConst.NORMAL_TICKET_ID, num = normalNum},
    })
    CommonTip:showTip(string.format("金券 +%d，银券 +%d", goldNum, normalNum))
    setTimeOut(function()
        if version ~= self._ticketNumAnimationTestVersion then return end
        local currentPanel = self.mainPanel
        local currentTreasureBoxNode = currentPanel and currentPanel.treasureBoxNode
        if currentPanel and not currentPanel.isDisposed and isSafeCocosObj(currentTreasureBoxNode) then
            currentTreasureBoxNode:updateTicketNum(originalGoldNum, originalNormalNum)
        end
    end, 3)
end

function TestUtils:playProgressTicketTipAnimation()
    local progressNode = self.mainPanel and self.mainPanel.dailyLevelProcessNode
    local process = progressNode and progressNode.process
    if not progressNode or progressNode.isDisposed or not process then
        CommonTip:showTip("进度条不可用")
        return
    end

    local candidates = {process.fixedItemNode}
    for _, node in pairs(process.itemNodeMap or {}) do
        table.insert(candidates, node)
    end
    for _, node in ipairs(candidates) do
        if isSafeCocosObj(node) and isSafeCocosObj(node.ticketIcon) then
            node:playTicketTipAnimation()
            return
        end
    end
    CommonTip:showTip("当前可见宝箱中没有奖券")
end

function TestUtils:playCollectionGemFlyAnimation()
    local progressNode = self.mainPanel and self.mainPanel.dailyLevelProcessNode
    local collectionNode = progressNode and progressNode.collectionNode
    if not progressNode or progressNode.isDisposed or not isSafeCocosObj(collectionNode) then
        CommonTip:showTip("进度条收集物不可用")
        return
    end

    local DailyLevelCollectionFlyAnimation = require "amf.feature.localactivity.dailylevel.view.node.DailyLevelCollectionFlyAnimation"
    local animation = DailyLevelCollectionFlyAnimation:create({
        itemNum = 15,
        startWorldPos = ccp(360, 640),
        targetWorldPos = collectionNode:getPositionInWorldSpace(),
    })
    animation:play(function()
        CommonTip:showTip("飞宝石动画播放完成")
    end)
end

function TestUtils:playGoldToGoButtonAnimation()
    local panel = self.mainPanel
    if not panel or panel.isDisposed or not isSafeCocosObj(panel.goBtn) then
        CommonTip:showTip("进入按钮不可用")
        return
    end
    panel:playGoldToGoButtonAnimation(function()
        CommonTip:showTip("风车币飞按钮动画播放完成")
    end)
end

function TestUtils:testProgressModeChange(fromCycleMode, toCycleMode)
    local vm = self:getMainPanelVM()
    local panel = self.mainPanel
    if not vm or vm.isDisposed or vm:isLocked() or not panel or panel.isDisposed then
        CommonTip:showTip("当前流程未结束，请稍后重试")
        return
    end

    local fixedConfigList = {}
    local totalTarget = 0
    for index = 1, 10 do
        local config = TEST_BOX_CONFIG[index]
        totalTarget = totalTarget + config.target
        table.insert(fixedConfigList, {
            id = config.id,
            type = config.type,
            target = totalTarget,
            rewardList = config.rewards,
        })
    end
    local cycleConfig = TEST_BOX_CONFIG[11]
    local cycleConfigList = {{
        id = cycleConfig.id,
        type = cycleConfig.type,
        target = cycleConfig.target,
        displayTarget = cycleConfig.target,
        rewardList = cycleConfig.rewards,
    }}
    local modeData = {
        [false] = {
            curId = 4,
            cangetId = 5,
            collectNum = 50,
            boxConfigList = fixedConfigList,
        },
        [true] = {
            curId = 10,
            cangetId = 10,
            collectNum = 4,
            boxConfigList = cycleConfigList,
        },
    }
    local fromData = modeData[fromCycleMode]
    local toData = modeData[toCycleMode]
    panel:initProgressNode(
        fromData.curId,
        fromData.cangetId,
        fromData.collectNum,
        fromData.boxConfigList,
        fromCycleMode
    )
    panel:playProgressModeChange(
        toData.curId,
        toData.cangetId,
        toData.collectNum,
        toData.boxConfigList,
        toCycleMode
    )
end

function TestUtils:testPackageTierPurchase()
    local oldPackageMetaList = self._mgr:getConfigValue("packagePriceMetaList", {})
    local oldBuyPackageMap = self._mgr:getDataValue("buyPackageMap", {})
    local packageMetaList = {
        {packageId = 1003, buyType = "TICKET", minBuyTimes = -1},
        {packageId = 1002, buyType = "TICKET", minBuyTimes = 5},
        {packageId = 1001, buyType = "TICKET", minBuyTimes = 2},
        {packageId = 2002, buyType = "DOUBLE_COLLECT", minBuyTimes = -1},
        {packageId = 2001, buyType = "DOUBLE_COLLECT", minBuyTimes = 1},
    }
    local cases = {
        {name = "门票0次", buyType = "TICKET", buyPackageMap = {}, expected = 1001},
        {name = "门票边界2次", buyType = "TICKET", buyPackageMap = {['1001'] = 2}, expected = 1001},
        {name = "门票3次", buyType = "TICKET", buyPackageMap = {['1001'] = 3}, expected = 1002},
        {name = "门票汇总6次", buyType = "TICKET", buyPackageMap = {['1001'] = 2, ['1002'] = 4}, expected = 1003},
        {name = "翻倍0次", buyType = "DOUBLE_COLLECT", buyPackageMap = {}, expected = 2001},
        {name = "翻倍2次", buyType = "DOUBLE_COLLECT", buyPackageMap = {['2001'] = 2}, expected = 2002},
    }

    self._mgr._model:setValue("localConfig.packagePriceMetaList", packageMetaList)
    local failedCases = {}
    for _, caseData in ipairs(cases) do
        self._mgr:setDataValue("buyPackageMap", caseData.buyPackageMap)
        local packageId = self._mgr:getPackageIdByBuyType(caseData.buyType)
        if packageId ~= caseData.expected then
            table.insert(failedCases, string.format("%s:%s", caseData.name, tostring(packageId)))
        end
    end

    self._mgr:setDataValue("buyPackageMap", {})
    self._mgr:addPackageBuyTimes(1001)
    local incrementMap = self._mgr:getDataValue("buyPackageMap", {}) or {}
    local incrementPassed = incrementMap["1001"] == 1
    self._mgr._model:setValue("localConfig.packagePriceMetaList", oldPackageMetaList)
    self._mgr:setDataValue("buyPackageMap", oldBuyPackageMap)

    if #failedCases == 0 and incrementPassed then
        CommonTip:showTip("梯度购买测试通过：7/7")
    else
        if not incrementPassed then table.insert(failedCases, "购买次数本地累加失败") end
        CommonTip:showTip("梯度购买测试失败：" .. table.concat(failedCases, ","))
    end
end

function TestUtils:initTestBtns()
    self:addTestButton("遮罩周中", function()
        self._maskTestVersion = (self._maskTestVersion or 0) + 1
        local version = self._maskTestVersion
        self._mgr:showEnterLevelMask()
        setTimeOut(function()
            if version ~= self._maskTestVersion then return end
            self._mgr:hideLevelMask()
        end, 5)
    end)

    self:addTestButton("遮罩周末", function()
        self._maskTestVersion = (self._maskTestVersion or 0) + 1
        local version = self._maskTestVersion
        self._mgr:showExitLevelMask(true)
        setTimeOut(function()
            if version ~= self._maskTestVersion then return end
            self._mgr:hideLevelMask()
        end, 5)
    end)

    self:addTestButton("测试新一轮Banner", function()
        local vm = self:getMainPanelVM()
        if not vm or vm.isDisposed or vm:isLocked() then
            CommonTip:showTip("当前流程未结束，请稍后重试")
            return
        end
        vm:lock()
        vm:showBanner():next(function()
            if not vm.isDisposed then vm:unlock() end
        end, function()
            if not vm.isDisposed then vm:unlock() end
        end)
    end)
    self:addTestButton("宝箱循环转固定", function()
        self:testProgressModeChange(true, false)
    end)

    self:addTestButton("宝箱固定转循环", function()
        self:testProgressModeChange(false, true)
    end)

    self:addTestButton("测试周末狂欢切换", function()
        local vm = self:getMainPanelVM()
        if not vm or vm.isDisposed or vm:isLocked() then
            CommonTip:showTip("当前流程未结束，请稍后重试")
            return
        end
        vm:lock()
        vm:playWeekendCarnivalAnimation(true):next(function()
            if not vm.isDisposed then vm:unlock() end
        end, function()
            if not vm.isDisposed then vm:unlock() end
        end)
    end)

    self:addTestButton("狂欢介绍-周中", function()
        self:showWeekendCarnivalPanel(false)
    end)

    self:addTestButton("狂欢介绍-周末", function()
        self:showWeekendCarnivalPanel(true)
    end)

    self:addTestButton("Icon强切周末", function()
        local icon = _G.amfBean("IconManager"):getIconByIconKey(IconKey.kDailyLevel, true)
        if not icon or not icon.updateWeekendSpine then
            CommonTip:showTip("每日夺宝 Icon 不可用")
            return
        end
        icon:updateWeekendSpine(true, true)
        CommonTip:showTip("每日夺宝 Icon 已切换为周末状态")
    end)

    self:addTestButton("Icon还原正常", function()
        local icon = _G.amfBean("IconManager"):getIconByIconKey(IconKey.kDailyLevel, true)
        if not icon or not icon.updateWeekendSpine then
            CommonTip:showTip("每日夺宝 Icon 不可用")
            return
        end
        icon:updateWeekendSpine(true)
        CommonTip:showTip("每日夺宝 Icon 已还原为当前日期状态")
    end)

    self:addTestButton("测试翻倍界面", function()
        self:showDoubleCollectPanel()
    end)

    self:addTestButton("梯度购买选档测试", function()
        self:testPackageTierPurchase()
    end)

    self:addTestButton("宝箱奖励及飞奖券", function()
        self:showBoxRewardPanel()
    end)

    self:addTestButton("宝箱特殊奖励排列", function()
        self:showNormalRewardCaseList()
    end)

    self:addTestButton("恭喜获得模板", function()
        self:showRewardTemplateCaseList()
    end)

    self:addTestButton("金银奖券随机数字动画", function()
        self:playRandomTicketNumAnimation()
    end)

    self:addTestButton("进度宝箱奖券动画", function()
        self:playProgressTicketTipAnimation()
    end)

    self:addTestButton("飞宝石动画", function()
        self:playCollectionGemFlyAnimation()
    end)

    self:addTestButton("风车币飞按钮动画", function()
        self:playGoldToGoButtonAnimation()
    end)

    for count = 1, 15 do
        local ticketCount = count
        self:addTestButton("奖券领奖-" .. ticketCount .. "个", function()
            self:showPrizeTicketPanel(ticketCount)
        end)
    end
    self:addTestButton("奖券领奖-17个", function()
        self:showPrizeTicketPanel(17)
    end)

    self:addTestButton("主界面流程用例", function()
        self:showFlowCaseList()
    end)

    self:addTestButton("推送-周末有次数", function()
        local now = TimeKit:timeInMillis()
        local vm = self:applyScenario({
            phase = "main",
            beginTime = now - DAY_MS,
            mainEndTime = now + 8 * DAY_MS,
            endTime = now + 10 * DAY_MS,
            collectNum = 0,
            maxClaimedBoxId = 0,
            goldTicketNum = 0,
            normalTicketNum = 0,
            freeCanPlayNum = 1,
            payCanPlayNum = 0,
        })
        if vm then self._mgr:onSystemEnterBackground() end
        _G.amfBean("LocalPushManager"):onSystemEnterBackground()
    end)

    self:addTestButton("推送-当天次数用完", function()
        local now = TimeKit:timeInMillis()
        local vm = self:applyScenario({
            phase = "main",
            beginTime = now - DAY_MS,
            mainEndTime = now + 8 * DAY_MS,
            endTime = now + 10 * DAY_MS,
            collectNum = 0,
            maxClaimedBoxId = 0,
            goldTicketNum = 0,
            normalTicketNum = 0,
            freeCanPlayNum = 0,
            payCanPlayNum = 0,
        })
        if vm then self._mgr:onSystemEnterBackground() end
        _G.amfBean("LocalPushManager"):onSystemEnterBackground()
    end)

    self:addTestButton("推送-周六次数用完", function()
        local now = TimeKit:timeInMillis()
        local vm = self:applyScenario({
            phase = "main",
            beginTime = now - DAY_MS,
            mainEndTime = now + 8 * DAY_MS,
            endTime = now + 10 * DAY_MS,
            collectNum = 0,
            maxClaimedBoxId = 0,
            goldTicketNum = 0,
            normalTicketNum = 0,
            freeCanPlayNum = 0,
            payCanPlayNum = 0,
        })
        if not vm then return end

        local realTimeInSec = TimeKit.timeInSec
        local nowSec = realTimeInSec(TimeKit)
        local todayStart = TimeKit:getDayStartTimeByTS(nowSec)
        local weekDay = tonumber(os.date("!%w", todayStart + 8 * 3600)) or 0
        local daysUntilSaturday = (6 - weekDay + 7) % 7
        local fakeSaturday = todayStart + daysUntilSaturday * 24 * 3600 + 10 * 3600
        TimeKit.timeInSec = function()
            return fakeSaturday
        end
        self._mgr:onSystemEnterBackground()
        _G.amfBean("LocalPushManager"):onSystemEnterBackground()
        TimeKit.timeInSec = realTimeInSec
    end)

    self:addTestButton("推送-领奖期有奖励", function()
        local now = TimeKit:timeInMillis()
        local vm = self:applyScenario({
            phase = "main",
            beginTime = now - DAY_MS,
            mainEndTime = now + DAY_MS,
            endTime = now + 4 * DAY_MS,
            collectNum = 0,
            maxClaimedBoxId = 0,
            goldTicketNum = 1,
            normalTicketNum = 1,
            freeCanPlayNum = 0,
            payCanPlayNum = 0,
        })
        if vm then self._mgr:onSystemEnterBackground() end
        _G.amfBean("LocalPushManager"):onSystemEnterBackground()
    end)

    self:addTestButton("推送-领奖期无奖励", function()
        local now = TimeKit:timeInMillis()
        local vm = self:applyScenario({
            phase = "main",
            beginTime = now - DAY_MS,
            mainEndTime = now + DAY_MS,
            endTime = now + 4 * DAY_MS,
            collectNum = 0,
            maxClaimedBoxId = 0,
            goldTicketNum = 0,
            normalTicketNum = 0,
            freeCanPlayNum = 0,
            payCanPlayNum = 0,
        })
        if vm then self._mgr:onSystemEnterBackground() end
        _G.amfBean("LocalPushManager"):onSystemEnterBackground()
    end)
end

function TestUtils:close()
    self._maskTestVersion = (self._maskTestVersion or 0) + 1
    self._ticketNumAnimationTestVersion = (self._ticketNumAnimationTestVersion or 0) + 1
    self._mgr:clearLevelMask()
    self:closeFlowCaseList()
    self:closeRewardTemplateCaseList()
    if not _G.__DailyLevelFlowTestRunning then
        self:restoreFlowTestEnvironment()
    end
    ActivityTestUtils.close(self)
end

return TestUtils
