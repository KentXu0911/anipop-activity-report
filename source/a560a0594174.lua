local test = require "amf.debug.unittest.suite"
local assert = require "amf.debug.unittest.assert"
local mock = require "amf.debug.unittest.mock"

local FLOW_MODULE = "amf.feature.localactivity.collectcard.openflow.OpenCardPackFlow"
local HOOKS_MODULE = "amf.feature.localactivity.collectcard.openflow.OpenCardPackFlowHooks"
local EVENT_CENTER_MODULE = "amf.feature.localactivity.collectcard.event.CollectCardEventCenter"
local LOG_MODULE = "amf.feature.localactivity.collectcard.log.CollectCardLog"
local DEFERRED_MODULE = "amf.script.sugar.deferred"

local function installClass()
    mock.global("class", function()
        local cls = {}
        cls.__index = cls
        function cls.new(...)
            local instance = setmetatable({}, cls)
            if instance.ctor then
                instance:ctor(...)
            end
            return instance
        end
        return cls
    end)
end

local function installDependencies()
    installClass()
    mock.module(HOOKS_MODULE, {
        createDefaultHooks = function()
            return {}
        end,
    })
    mock.module(EVENT_CENTER_MODULE, {
        dispatch = function() end,
    })
    mock.module(LOG_MODULE, {
        logWarning = function() end,
    })
    mock.module(DEFERRED_MODULE, {
        new = function()
            local promise = {
                resolved = false,
                value = nil,
            }
            function promise:resolve(value)
                self.resolved = true
                self.value = value
            end
            return promise
        end,
    })
end

local function createRuntime(options)
    options = options or {}
    local permanentCount = options.permanentCount or 0
    local sentCount = 0
    local requestedConfigKey

    local model = {
        getRoundId = function()
            return options.roundId or 1
        end,
        getPeriodId = function()
            return options.periodId or 7
        end,
    }
    local manager = {
        getModel = function()
            return model
        end,
        getConfigByKey = function(_, key, defaultValue)
            requestedConfigKey = key
            if options.configuredLimit == nil then
                return defaultValue
            end
            return options.configuredLimit
        end,
    }
    local autoPopupManager = {
        getPermanentShowNum = function(_, key)
            assert.equals(key, "CollectCardOverProcessTip")
            return permanentCount
        end,
        sendPermanentData = function(_, key)
            assert.equals(key, "CollectCardOverProcessTip")
            permanentCount = permanentCount + 1
            sentCount = sentCount + 1
        end,
    }

    mock.bean("CollectCardManager", manager)
    mock.bean("AutoPopupMgr", autoPopupManager)

    return {
        getPermanentCount = function()
            return permanentCount
        end,
        getSentCount = function()
            return sentCount
        end,
        getRequestedConfigKey = function()
            return requestedConfigKey
        end,
    }
end

local function createFlow(onShow)
    mock.unload(FLOW_MODULE)
    local OpenCardPackFlow = require(FLOW_MODULE)
    local flow = OpenCardPackFlow.new()
    flow.context = {
        overProcess = true,
    }
    flow:setHook("onShowNextRoundPreview", onShow)
    return flow
end

test.describe("CollectCard over-process tip lifetime limit", function()
    test.beforeEach(function()
        mock.unload(FLOW_MODULE)
        installDependencies()
    end)

    test.it("shows once by default and records before the panel closes", function()
        local runtime = createRuntime()
        local showCount = 0
        local closePanel
        local flow = createFlow(function(_, closeCallback)
            showCount = showCount + 1
            closePanel = closeCallback
        end)

        local promise = flow:showNextRoundPreview()

        assert.equals(showCount, 1)
        assert.equals(runtime.getPermanentCount(), 1)
        assert.equals(runtime.getSentCount(), 1)
        assert.equals(runtime.getRequestedConfigKey(), "overProcessTipPopLimit")
        assert.falsy(promise.resolved)

        closePanel()
        assert.truthy(promise.resolved)

        local secondShowCount = 0
        local secondFlow = createFlow(function()
            secondShowCount = secondShowCount + 1
        end)
        local secondPromise = secondFlow:showNextRoundPreview()

        assert.equals(secondShowCount, 0)
        assert.equals(runtime.getSentCount(), 1)
        assert.truthy(secondPromise.resolved)
    end)

    test.it("honors a configured lifetime limit", function()
        local runtime = createRuntime({
            permanentCount = 1,
            configuredLimit = "2",
        })
        local showCount = 0
        local flow = createFlow(function(_, closeCallback)
            showCount = showCount + 1
            closeCallback()
        end)

        local promise = flow:showNextRoundPreview()

        assert.equals(showCount, 1)
        assert.equals(runtime.getPermanentCount(), 2)
        assert.equals(runtime.getSentCount(), 1)
        assert.truthy(promise.resolved)
    end)

    test.it("allows zero to disable the tip", function()
        local runtime = createRuntime({
            configuredLimit = 0,
        })
        local showCount = 0
        local flow = createFlow(function()
            showCount = showCount + 1
        end)

        local promise = flow:showNextRoundPreview()

        assert.equals(showCount, 0)
        assert.equals(runtime.getSentCount(), 0)
        assert.truthy(promise.resolved)
    end)

    test.it("does not record when the over-process condition is false", function()
        local runtime = createRuntime()
        local showCount = 0
        local flow = createFlow(function()
            showCount = showCount + 1
        end)
        flow.context.overProcess = false

        local promise = flow:showNextRoundPreview()

        assert.equals(showCount, 0)
        assert.equals(runtime.getSentCount(), 0)
        assert.truthy(promise.resolved)
    end)
end)
