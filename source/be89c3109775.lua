-- OpenCardPackFlow单元测试
local OpenCardPackFlowTest = {}

local OpenCardPackFlow = require "amf.feature.localactivity.collectcard.openflow.OpenCardPackFlow"
local OpenCardPackFlowBuilder = require "amf.feature.localactivity.collectcard.openflow.OpenCardPackFlowBuilder"
local CollectCardEventCenter = require "amf.feature.localactivity.collectcard.event.CollectCardEventCenter"

-- ========== 测试工具函数 ==========

-- 创建模拟Promise
function OpenCardPackFlowTest:createMockPromise(successData, errorData)
    local deferred = require "amf.script.sugar.deferred"
    local promise = deferred.new()
    
    if errorData then
        promise:reject(errorData)
    else
        promise:resolve(successData)
    end
    
    return promise
end

-- 创建模拟响应
function OpenCardPackFlowTest:createMockResponse(success, data, error)
    local response = {}
    response.isSuccess = function(self)
        return success
    end
    response.getData = function(self)
        return data
    end
    response.getError = function(self)
        return error
    end
    return response
end

-- ========== 测试用例 ==========

-- 测试1：基本流程执行
function OpenCardPackFlowTest:testBasicFlow()
    print("========== 测试1：基本流程执行 ==========")
    
    local flow = OpenCardPackFlow.new()
    
    -- 设置钩子模拟
    flow:setHook("onFilterCardPacks", function(rewards)
        return {{itemId = 58201, count = 1}}
    end)
    
    flow:setHook("onFilterOtherRewards", function(rewards)
        return {{itemId = 10060, count = 100}}
    end)
    
    flow:setHook("onSendRequest", function(requestParams)
        return self:createMockPromise(true, {cardRewards = {{itemId = 58001, count = 1}}})
    end)
    
    flow:setHook("onResponse", function(response)
        return response.cardRewards or {}
    end)
    
    flow:setHook("shouldShowOpenAnim", function(cardRewards)
        return false  -- 跳过动画
    end)
    
    flow:setHook("shouldShowRewardsPanel", function(allRewards)
        return false  -- 跳过奖励面板
    end)
    
    local rewards = {
        {itemId = 58201, count = 1},
        {itemId = 10060, count = 100},
    }
    
    flow:execute(rewards):next(function(result)
        print("✓ 测试1通过：基本流程执行成功")
        print("  上下文：", result)
    end, function(error)
        print("✗ 测试1失败：", error)
    end)
end

-- 测试2：空奖励列表
function OpenCardPackFlowTest:testEmptyRewards()
    print("========== 测试2：空奖励列表 ==========")
    
    local flow = OpenCardPackFlow.new()
    
    flow:setHook("onFilterCardPacks", function(rewards)
        return {}
    end)
    
    flow:setHook("onFilterOtherRewards", function(rewards)
        return {}
    end)
    
    flow:setHook("shouldShowOpenAnim", function(cardRewards)
        return false
    end)
    
    flow:setHook("shouldShowRewardsPanel", function(allRewards)
        return false
    end)
    
    flow:execute({}):next(function(result)
        print("✓ 测试2通过：空奖励列表处理成功")
    end, function(error)
        print("✗ 测试2失败：", error)
    end)
end

-- 测试3：只有卡包奖励
function OpenCardPackFlowTest:testOnlyCardPacks()
    print("========== 测试3：只有卡包奖励 ==========")
    
    local flow = OpenCardPackFlow.new()
    
    flow:setHook("onFilterCardPacks", function(rewards)
        return {{itemId = 58201, count = 1}}
    end)
    
    flow:setHook("onFilterOtherRewards", function(rewards)
        return {}
    end)
    
    flow:setHook("onSendRequest", function(requestParams)
        print("  发送协议，参数：", requestParams)
        return self:createMockPromise(true, {cardRewards = {{itemId = 58001, count = 1}}})
    end)
    
    flow:setHook("onResponse", function(response)
        return response.cardRewards or {}
    end)
    
    flow:setHook("shouldShowOpenAnim", function(cardRewards)
        return false
    end)
    
    flow:setHook("shouldShowRewardsPanel", function(allRewards)
        return false
    end)
    
    local rewards = {{itemId = 58201, count = 1}}
    
    flow:execute(rewards):next(function(result)
        print("✓ 测试3通过：只有卡包奖励处理成功")
    end, function(error)
        print("✗ 测试3失败：", error)
    end)
end

-- 测试4：只有其他奖励
function OpenCardPackFlowTest:testOnlyOtherRewards()
    print("========== 测试4：只有其他奖励 ==========")
    
    local flow = OpenCardPackFlow.new()
    
    flow:setHook("onFilterCardPacks", function(rewards)
        return {}
    end)
    
    flow:setHook("onFilterOtherRewards", function(rewards)
        return {{itemId = 10060, count = 100}}
    end)
    
    flow:setHook("shouldShowOpenAnim", function(cardRewards)
        return false
    end)
    
    flow:setHook("shouldShowRewardsPanel", function(allRewards)
        return false
    end)
    
    local rewards = {{itemId = 10060, count = 100}}
    
    flow:execute(rewards):next(function(result)
        print("✓ 测试4通过：只有其他奖励处理成功")
    end, function(error)
        print("✗ 测试4失败：", error)
    end)
end

-- 测试5：协议发送失败
function OpenCardPackFlowTest:testRequestFailed()
    print("========== 测试5：协议发送失败 ==========")
    
    local flow = OpenCardPackFlow.new()
    
    flow:setHook("onFilterCardPacks", function(rewards)
        return {{itemId = 58201, count = 1}}
    end)
    
    flow:setHook("onFilterOtherRewards", function(rewards)
        return {}
    end)
    
    flow:setHook("onSendRequest", function(requestParams)
        return self:createMockPromise(nil, "网络错误")
    end)
    
    flow:setHook("shouldShowOpenAnim", function(cardRewards)
        return false
    end)
    
    flow:setHook("shouldShowRewardsPanel", function(allRewards)
        return false
    end)
    
    local rewards = {{itemId = 58201, count = 1}}
    
    flow:execute(rewards):next(function(result)
        print("✗ 测试5失败：应该失败但成功了")
    end, function(error)
        print("✓ 测试5通过：协议发送失败被正确处理")
        print("  错误信息：", error)
    end)
end

-- 测试6：预处理终止流程
function OpenCardPackFlowTest:testPreprocessTerminate()
    print("========== 测试6：预处理终止流程 ==========")
    
    local flow = OpenCardPackFlow.new()
    
    flow:setHook("onPreprocessRewards", function(rewards)
        return nil  -- 返回nil终止流程
    end)
    
    local rewards = {{itemId = 58201, count = 1}}
    
    flow:execute(rewards):next(function(result)
        print("✗ 测试6失败：应该终止但成功了")
    end, function(error)
        print("✓ 测试6通过：预处理终止流程成功")
        print("  错误信息：", error)
    end)
end

-- 测试7：取消发送协议
function OpenCardPackFlowTest:testCancelSendRequest()
    print("========== 测试7：取消发送协议 ==========")
    
    local flow = OpenCardPackFlow.new()
    
    flow:setHook("onFilterCardPacks", function(rewards)
        return {{itemId = 58201, count = 1}}
    end)
    
    flow:setHook("onFilterOtherRewards", function(rewards)
        return {}
    end)
    
    flow:setHook("beforeSendRequest", function(requestParams)
        return false  -- 取消发送
    end)
    
    local rewards = {{itemId = 58201, count = 1}}
    
    flow:execute(rewards):next(function(result)
        print("✗ 测试7失败：应该取消但成功了")
    end, function(error)
        print("✓ 测试7通过：取消发送协议成功")
        print("  错误信息：", error)
    end)
end

-- 测试8：钩子设置和获取
function OpenCardPackFlowTest:testHookSetAndGet()
    print("========== 测试8：钩子设置和获取 ==========")
    
    local flow = OpenCardPackFlow.new()
    
    local testHook = function()
        return "test"
    end
    
    flow:setHook("onPreprocessRewards", testHook)
    
    local retrievedHook = flow:getHook("onPreprocessRewards")
    
    if retrievedHook == testHook then
        print("✓ 测试8通过：钩子设置和获取成功")
    else
        print("✗ 测试8失败：钩子设置和获取失败")
    end
end

-- 测试9：批量设置钩子
function OpenCardPackFlowTest:testBatchSetHooks()
    print("========== 测试9：批量设置钩子 ==========")
    
    local flow = OpenCardPackFlow.new()
    
    local hooks = {
        onPreprocessRewards = function() return "preprocess" end,
        onFilterCardPacks = function() return {} end,
        onFilterOtherRewards = function() return {} end,
    }
    
    flow:setHooks(hooks)
    
    local hook1 = flow:getHook("onPreprocessRewards")
    local hook2 = flow:getHook("onFilterCardPacks")
    local hook3 = flow:getHook("onFilterOtherRewards")
    
    if hook1 and hook2 and hook3 then
        print("✓ 测试9通过：批量设置钩子成功")
    else
        print("✗ 测试9失败：批量设置钩子失败")
    end
end

-- 测试10：Builder模式
function OpenCardPackFlowTest:testBuilderPattern()
    print("========== 测试10：Builder模式 ==========")
    
    local flow = OpenCardPackFlowBuilder.new()
        :setPreprocessRewardsHook(function(rewards) return rewards end)
        :setFilterCardPacksHook(function(rewards) return {} end)
        :setFilterOtherRewardsHook(function(rewards) return {} end)
        :setShouldShowOpenAnimHook(function(cardRewards) return false end)
        :setShouldShowRewardsPanelHook(function(allRewards) return false end)
        :build()
    
    if flow then
        print("✓ 测试10通过：Builder模式成功")
    else
        print("✗ 测试10失败：Builder模式失败")
    end
end

-- 测试11：流程上下文
function OpenCardPackFlowTest:testFlowContext()
    print("========== 测试11：流程上下文 ==========")
    
    local flow = OpenCardPackFlow.new()
    
    flow:setHook("onFilterCardPacks", function(rewards)
        return {{itemId = 58201, count = 1}}
    end)
    
    flow:setHook("onFilterOtherRewards", function(rewards)
        return {{itemId = 10060, count = 100}}
    end)
    
    flow:setHook("onSendRequest", function(requestParams)
        return self:createMockPromise(true, {cardRewards = {{itemId = 58001, count = 1}}})
    end)
    
    flow:setHook("onResponse", function(response)
        return response.cardRewards or {}
    end)
    
    flow:setHook("shouldShowOpenAnim", function(cardRewards)
        return false
    end)
    
    flow:setHook("shouldShowRewardsPanel", function(allRewards)
        return false
    end)
    
    flow:setHook("onFlowComplete", function(result)
        local context = flow:getContext()
        print("  上下文数据：")
        print("    输入奖励：", #context.inputRewards)
        print("    卡包奖励：", #context.cardPackRewards)
        print("    其他奖励：", #context.otherRewards)
        print("    卡片奖励：", #context.cardRewards)
        print("    所有奖励：", #context.allRewards)
    end)
    
    local rewards = {
        {itemId = 58201, count = 1},
        {itemId = 10060, count = 100},
    }
    
    flow:execute(rewards):next(function(result)
        print("✓ 测试11通过：流程上下文正确")
    end, function(error)
        print("✗ 测试11失败：", error)
    end)
end

-- 测试12：事件监听
function OpenCardPackFlowTest:testEventListening()
    print("========== 测试12：事件监听 ==========")
    
    local eventCount = 0
    
    local function onEvent(event)
        eventCount = eventCount + 1
        print("  收到事件：", event:getType())
    end
    
    CollectCardEventCenter:register(CollectCardEvent.CARD_PACK_FLOW_START, onEvent)
    CollectCardEventCenter:register(CollectCardEvent.CARD_PACK_INPUT_PROCESSED, onEvent)
    CollectCardEventCenter:register(CollectCardEvent.CARD_PACK_FLOW_COMPLETE, onEvent)
    
    local flow = OpenCardPackFlow.new()
    
    flow:setHook("onFilterCardPacks", function(rewards)
        return {}
    end)
    
    flow:setHook("onFilterOtherRewards", function(rewards)
        return {}
    end)
    
    flow:setHook("shouldShowOpenAnim", function(cardRewards)
        return false
    end)
    
    flow:setHook("shouldShowRewardsPanel", function(allRewards)
        return false
    end)
    
    flow:execute({}):next(function(result)
        if eventCount >= 3 then
            print("✓ 测试12通过：事件监听成功，收到", eventCount, "个事件")
        else
            print("✗ 测试12失败：事件监听失败，只收到", eventCount, "个事件")
        end
    end, function(error)
        print("✗ 测试12失败：", error)
    end)
end

-- 测试13：流程完成回调
function OpenCardPackFlowTest:testFlowCompleteCallback()
    print("========== 测试13：流程完成回调 ==========")
    
    local completeCalled = false
    local errorCalled = false
    
    local flow = OpenCardPackFlow.new()
    
    flow:setHook("onFilterCardPacks", function(rewards)
        return {}
    end)
    
    flow:setHook("onFilterOtherRewards", function(rewards)
        return {}
    end)
    
    flow:setHook("shouldShowOpenAnim", function(cardRewards)
        return false
    end)
    
    flow:setHook("shouldShowRewardsPanel", function(allRewards)
        return false
    end)
    
    flow:setHook("onFlowComplete", function(result)
        completeCalled = true
    end)
    
    flow:setHook("onFlowError", function(error)
        errorCalled = true
    end)
    
    flow:execute({}):next(function(result)
        if completeCalled and not errorCalled then
            print("✓ 测试13通过：流程完成回调正确")
        else
            print("✗ 测试13失败：流程完成回调错误")
        end
    end, function(error)
        print("✗ 测试13失败：", error)
    end)
end

-- 测试14：流程错误回调
function OpenCardPackFlowTest:testFlowErrorCallback()
    print("========== 测试14：流程错误回调 ==========")
    
    local completeCalled = false
    local errorCalled = false
    
    local flow = OpenCardPackFlow.new()
    
    flow:setHook("onFilterCardPacks", function(rewards)
        return {{itemId = 58201, count = 1}}
    end)
    
    flow:setHook("onFilterOtherRewards", function(rewards)
        return {}
    end)
    
    flow:setHook("onSendRequest", function(requestParams)
        return self:createMockPromise(nil, "测试错误")
    end)
    
    flow:setHook("onFlowComplete", function(result)
        completeCalled = true
    end)
    
    flow:setHook("onFlowError", function(error)
        errorCalled = true
    end)
    
    flow:execute({}):next(function(result)
        print("✗ 测试14失败：应该失败但成功了")
    end, function(error)
        if errorCalled and not completeCalled then
            print("✓ 测试14通过：流程错误回调正确")
        else
            print("✗ 测试14失败：流程错误回调错误")
        end
    end)
end

-- 测试15：合并奖励
function OpenCardPackFlowTest:testMergeRewards()
    print("========== 测试15：合并奖励 ==========")
    
    local flow = OpenCardPackFlow.new()
    
    flow:setHook("onFilterCardPacks", function(rewards)
        return {{itemId = 58201, count = 1}}
    end)
    
    flow:setHook("onFilterOtherRewards", function(rewards)
        return {{itemId = 10060, count = 100}}
    end)
    
    flow:setHook("onSendRequest", function(requestParams)
        return self:createMockPromise(true, {cardRewards = {{itemId = 58001, count = 1}}})
    end)
    
    flow:setHook("onResponse", function(response)
        return response.cardRewards or {}
    end)
    
    flow:setHook("onMergeRewards", function(cardRewards, otherRewards)
        local allRewards = {}
        for _, reward in ipairs(cardRewards or {}) do
            table.insert(allRewards, reward)
        end
        for _, reward in ipairs(otherRewards or {}) do
                       table.insert(allRewards, reward)
        end
        return allRewards
    end)
    
    flow:setHook("shouldShowOpenAnim", function(cardRewards)
        return false
    end)
    
    flow:setHook("shouldShowRewardsPanel", function(allRewards)
        print("  合并后的奖励数量：", #allRewards)
        return false
    end)
    
    local rewards = {
        {itemId = 58201, count = 1},
        {itemId = 10060, count = 100},
    }
    
    flow:execute(rewards):next(function(result)
        print("✓ 测试15通过：合并奖励成功")
    end, function(error)
        print("✗ 测试15失败：", error)
    end)
end

-- ========== 运行所有测试 ==========

function OpenCardPackFlowTest:runAllTests()
    print("\n")
    print("========================================")
    print("  OpenCardPackFlow 单元测试")
    print("========================================")
    print("\n")
    
    self:testBasicFlow()
    self:testEmptyRewards()
    self:testOnlyCardPacks()
    self:testOnlyOtherRewards()
    self:testRequestFailed()
    self:testPreprocessTerminate()
    self:testCancelSendRequest()
    self:testHookSetAndGet()
    self:testBatchSetHooks()
    self:testBuilderPattern()
    self:testFlowContext()
    self:testEventListening()
    self:testFlowCompleteCallback()
    self:testFlowErrorCallback()
    self:testMergeRewards()
    
    print("\n")
    print("========================================")
    print("  所有测试执行完毕")
    print("========================================")
    print("\n")
end

return OpenCardPackFlowTest
