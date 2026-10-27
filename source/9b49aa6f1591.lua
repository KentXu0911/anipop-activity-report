-- OpenCardPackFlow 测试使用说明

-- ========== 快速开始 ==========

-- 方式1：运行所有测试（最简单）
require "amf.feature.localactivity.collectcard.test.OpenTestEntry":run()

-- 方式2：使用测试运行器
local TestRunner = require "amf.feature.localactivity.collectcard.test.OpenCardPackFlowTestRunner"
TestRunner:runAllTests()

-- 方式3：运行单个测试
local TestRunner = require "amf.feature.localactivity.collectcard.test.OpenCardPackFlowTestRunner"
TestRunner:runTest("testBasicFlow")

-- 方式4：列出所有测试
local TestRunner = require "amf.feature.localactivity.collectcard.test.OpenCardPackFlowTestRunner"
TestRunner:listTests()

-- ========== 测试用例列表 ==========

-- 1. testBasicFlow - 基本流程执行
-- 2. testEmptyRewards - 空奖励列表
-- 3. testOnlyCardPacks - 只有卡包奖励
-- 4. testOnlyOtherRewards - 只有其他奖励
-- 5. testRequestFailed - 协议发送失败
-- 6. testPreprocessTerminate - 预处理终止流程
-- 7. testCancelSendRequest - 取消发送协议
-- 8. testHookSetAndGet - 钩子设置和获取
-- 9. testBatchSetHooks - 批量设置钩子
-- 10. testBuilderPattern - Builder模式
-- 11. testFlowContext - 流程上下文
-- 12. testEventListening - 事件监听
-- 13. testFlowCompleteCallback - 流程完成回调
-- 14. testFlowErrorCallback - 流程错误回调
-- 15. testMergeRewards - 合并奖励

-- ========== 自定义测试示例 ==========

-- 示例1：测试自定义钩子
local OpenCardPackFlow = require "amf.feature.localactivity.collectcard.openflow.OpenCardPackFlow"

local flow = OpenCardPackFlow.new()

flow:setHook("onFilterCardPacks", function(rewards)
    -- 自定义过滤逻辑
    local cardPacks = {}
    for _, reward in ipairs(rewards or {}) do
        if reward.itemId == 58201 then
            table.insert(cardPacks, reward)
        end
    end
    return cardPacks
end)

flow:setHook("onSendRequest", function(requestParams)
    -- 自定义发送逻辑
    local deferred = require "amf.script.sugar.deferred"
    local promise = deferred.new()
    
    -- 模拟发送
    promise:resolve({cardRewards = {{itemId = 58001, count = 1}}})
    
    return promise
end)

flow:setHook("shouldShowOpenAnim", function(cardRewards)
    return false
end)

flow:setHook("shouldShowRewardsPanel", function(allRewards)
    return false
end)

flow:execute({{itemId = 58201, count = 1}}):next(function(result)
    print("自定义测试成功！")
end, function(error)
    print("自定义测试失败：", error)
end)

-- 示例2：测试Builder模式
local OpenCardPackFlowBuilder = require "amf.feature.localactivity.collectcard.openflow.OpenCardPackFlowBuilder"

local flow = OpenCardPackFlowBuilder.new()
    :setFilterCardPacksHook(function(rewards)
        return rewards or {}
    end)
    :setFilterOtherRewardsHook(function(rewards)
        return {}
    end)
    :setShouldShowOpenAnimHook(function(cardRewards)
        return false
    end)
    :setShouldShowRewardsPanelHook(function(allRewards)
        return false
    end)
    :build()

flow:execute({}):next(function(result)
    print("Builder模式测试成功！")
end)

-- 示例3：测试事件监听
local CollectCardEventCenter = require "amf.feature.localactivity.collectcard.event.CollectCardEventCenter"

-- 注册事件监听
CollectCardEventCenter:register(CollectCardEvent.CARD_PACK_FLOW_START, function(event)
    print("流程开始")
end)

CollectCardEventCenter:register(CollectCardEvent.CARD_PACK_FLOW_COMPLETE, function(event)
    print("流程完成")
end)

-- 运行测试
local OpenCardPackFlow = require "amf.feature.localactivity.collectcard.openflow.OpenCardPackFlow"
local flow = OpenCardPackFlow.new()

flow:setHook("onFilterCardPacks", function(rewards) return {} end)
flow:setHook("onFilterOtherRewards", function(rewards) return {} end)
flow:setHook("shouldShowOpenAnim", function(cardRewards) return false end)
flow:setHook("shouldShowRewardsPanel", function(allRewards) return false end)

flow:execute({}):next(function(result)
    print("事件监听测试成功！")
end)

-- ========== 测试工具函数 ==========

-- 创建模拟Promise
local Test = require "amf.feature.localactivity.collectcard.test.OpenCardPackFlowTest"
local mockPromise = Test:createMockPromise(true, {data = "success"})

-- 创建模拟响应
local mockResponse = Test:createMockResponse(true, {cardRewards = {}}, nil)

-- ========== 注意事项 ==========

-- 1. 所有测试使用模拟数据，不会发送真实网络请求
-- 2. 测试中跳过了开包动画和奖励面板的展示
-- 3. 测试结果会在控制台输出
-- 4. 如需调试单个测试，可以使用 runTest 方法
-- 5. 测试是异步的，使用Promise链处理

-- ========== 常见问题 ==========

-- Q: 如何调试单个测试？
-- A: 使用 TestRunner:runTest("testName") 方法

-- Q: 如何查看所有可用测试？
-- A: 使用 TestRunner:listTests() 方法

-- Q: 测试失败怎么办？
-- A: 查看控制台输出的错误信息，检查钩子设置是否正确

-- Q: 如何添加新测试？
-- A: 在 OpenCardPackFlowTest.lua 中添加 testYourNewTest() 方法

-- Q: 测试会影响真实数据吗？
-- A: 不会，所有测试使用模拟数据
