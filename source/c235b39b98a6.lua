local test = require "amf.debug.unittest.suite"
local assert = require "amf.debug.unittest.assert"
local mock = require "amf.debug.unittest.mock"
local spy = require "amf.debug.unittest.spy"

local MANAGER_MODULE = "amf.feature.localactivity.gemmining.GemMiningManager"
local LOCAL_SERVER_MODULE = "amf.feature.localactivity.gemmining.GemMiningLocalServer"
local META_MODULE = "amf.feature.localactivity.gemmining.meta.Meta"
local CLASS_UTILS_MODULE = "amf.script.tool.clazz.ClassUtils"
local PAYMENT_TRACER_MODULE = "amf.middleware.purchase.dc.trace.PaymentTracer"
local EVENT_CENTER_MODULE = "amf.middleware.activity.event.ActivityEventCenter"

local function installClass()
    mock.global("class", function()
        local cls = {}
        cls.__index = cls
        function cls.new()
            return setmetatable({}, cls)
        end
        return cls
    end)
end

local function cloneTable(source)
    local result = {}
    for key, value in pairs(source) do
        result[key] = type(value) == "table" and cloneTable(value) or value
    end
    return result
end

local function createLocalData()
    local data = {
        cachedActInfo = {
            actId = 6057,
            marker = "cached",
        },
    }

    data.getCachedActInfo = function(self)
        return self.cachedActInfo
    end
    data.setCachedActInfo = spy.fn(function(self, actInfo)
        self.cachedActInfo = cloneTable(actInfo)
    end)
    data.clearCachedActInfo = spy.fn(function(self)
        self.cachedActInfo = nil
    end)
    return data
end

local function createEvent(actInfo, fromServer)
    return {
        getData = function()
            return {
                actInfos = actInfo and {
                    ["6057"] = actInfo,
                } or {},
                fromServer = fromServer,
            }
        end,
    }
end

local function loadManager(localData, activityMgr, dispatch)
    installClass()
    mock.module(LOCAL_SERVER_MODULE, {
        create = function()
            return localData
        end,
    })
    mock.module(CLASS_UTILS_MODULE, {
        makeSingleton = function() end,
    })
    mock.module(PAYMENT_TRACER_MODULE, {})
    mock.module(EVENT_CENTER_MODULE, {
        dispatch = dispatch,
    })
    mock.global("ActivityEvent", {
        REMOVE_ACTIVITY = "remove_activity",
    })
    mock.bean("ActivityMgr", activityMgr)
    mock.unload(MANAGER_MODULE)

    local Manager = require(MANAGER_MODULE)
    local manager = Manager.new()
    manager.localDataServer = localData
    manager.hasSyncedActInfoOnline = false
    manager.notify = spy.fn()
    return manager
end

test.describe("GemMining actInfo cache", function()
    test.beforeEach(function()
        mock.unload(MANAGER_MODULE)
        mock.unload(LOCAL_SERVER_MODULE)
    end)

    test.it("reads cached actInfo before the online list is synchronized", function()
        local localData = createLocalData()
        local manager = loadManager(localData, {
            getActInfo = function()
                return nil
            end,
        }, spy.fn())

        assert.equals(manager:getActInfo().marker, "cached")
        assert.truthy(manager:isActInfoEnabled())
    end)

    test.it("uses runtime local actInfo before online sync without persisting it", function()
        local localData = createLocalData()
        local runtimeActInfo = {
            actId = 6057,
            marker = "local",
        }
        local manager = loadManager(localData, {
            getActInfo = function()
                return runtimeActInfo
            end,
        }, spy.fn())

        manager:onActActInfoUpdate(createEvent(runtimeActInfo, false))

        assert.equals(manager:getActInfo().marker, "local")
        assert.falsy(manager.hasSyncedActInfoOnline)
        assert.notCalled(localData.setCachedActInfo)
        assert.notCalled(localData.clearCachedActInfo)
    end)

    test.it("uses online actInfo and refreshes the persistent cache", function()
        local localData = createLocalData()
        local onlineActInfo = {
            actId = 6057,
            marker = "online",
        }
        local manager = loadManager(localData, {
            getActInfo = function()
                return onlineActInfo
            end,
        }, spy.fn())

        manager:onActActInfoUpdate(createEvent(onlineActInfo, true))

        assert.truthy(manager.hasSyncedActInfoOnline)
        assert.equals(manager:getActInfo().marker, "online")
        assert.calledWith(localData.setCachedActInfo, localData, onlineActInfo)
    end)

    test.it("clears cache and closes the activity after an explicit online miss", function()
        local localData = createLocalData()
        local dispatch = spy.fn()
        local manager = loadManager(localData, {
            getActInfo = function()
                return nil
            end,
        }, dispatch)

        manager:onActActInfoUpdate(createEvent(nil, true))

        assert.truthy(manager.hasSyncedActInfoOnline)
        assert.nilValue(manager:getActInfo())
        assert.falsy(manager:isActInfoEnabled())
        assert.calledWith(localData.clearCachedActInfo, localData)
        assert.calledWith(manager.notify, manager, "CloseAllPanel")
        assert.calledWith(dispatch, assert.anyTable(), "remove_activity", {
            actId = 6057,
        })
    end)

    test.it("ignores local actInfo mutations when deciding online sync state", function()
        local localData = createLocalData()
        local manager = loadManager(localData, {
            getActInfo = function()
                return nil
            end,
        }, spy.fn())

        manager:onActActInfoUpdate(createEvent({
            actId = 6057,
        }, false))

        assert.falsy(manager.hasSyncedActInfoOnline)
        assert.notCalled(localData.setCachedActInfo)
        assert.notCalled(localData.clearCachedActInfo)
    end)

    test.it("persists and clears a defensive copy in LocalServer", function()
        installClass()
        mock.global("AMFDataRef", {})
        mock.global("table", setmetatable({
            clone = cloneTable,
        }, {
            __index = table,
        }))
        mock.module(META_MODULE, {})
        mock.unload(LOCAL_SERVER_MODULE)

        local LocalServer = require(LOCAL_SERVER_MODULE)
        local storage = {}
        local localServer = setmetatable({
            getDataByKey = function(_, key)
                return storage[key] and cloneTable(storage[key]) or nil
            end,
            setDataByKey = function(_, key, value)
                storage[key] = value
            end,
            clearDataByKey = function(_, key)
                storage[key] = nil
            end,
        }, {
            __index = LocalServer,
        })
        local actInfo = {
            actId = 6057,
            nested = {
                value = 1,
            },
        }

        assert.truthy(localServer:setCachedActInfo(actInfo))
        actInfo.nested.value = 2
        assert.equals(localServer:getCachedActInfo().nested.value, 1)

        localServer:clearCachedActInfo()
        assert.nilValue(localServer:getCachedActInfo())
    end)
end)
