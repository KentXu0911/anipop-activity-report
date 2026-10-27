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

local function cloneTable(source)
    local result = {}
    for key, value in pairs(source or {}) do
        result[key] = type(value) == "table" and cloneTable(value) or value
    end
    return result
end

local function installGlobals()
    mock.global("class", function()
        local cls = {}
        cls.__index = cls
        function cls.new()
            return setmetatable({}, cls)
        end
        return cls
    end)
    mock.global("AMFDataRef", {})
    mock.global("table", setmetatable({
        clone = cloneTable,
        isEmpty = function(value)
            return type(value) ~= "table" or next(value) == nil
        end,
        serialize = function(value)
            return cloneTable(value)
        end,
    }, {
        __index = table,
    }))
end

local function loadLocalServer(storage)
    installGlobals()
    mock.module(META_MODULE, {})
    mock.unload(LOCAL_SERVER_MODULE)

    local LocalServer = require(LOCAL_SERVER_MODULE)
    return setmetatable({
        getDataByKey = function(_, key, defaultValue)
            local value = storage[key]
            if value == nil then return defaultValue end
            return type(value) == "table" and cloneTable(value) or value
        end,
        setDataByKey = function(_, key, value)
            storage[key] = type(value) == "table" and cloneTable(value) or value
        end,
    }, {
        __index = LocalServer,
    })
end

local function loadManager(localData)
    installGlobals()
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
        dispatch = function() end,
    })
    mock.unload(MANAGER_MODULE)

    local Manager = require(MANAGER_MODULE)
    local manager = Manager.new()
    manager.localDataServer = localData
    manager.updateTipView = spy.fn()
    return manager
end

local function createMapData(mapCount, claimedThrough)
    local mapMetas = {}
    local gemMaps = {}
    for mapId = 0, mapCount - 1 do
        mapMetas[#mapMetas + 1] = {
            mapId = mapId,
        }
        gemMaps[tostring(mapId)] = {
            progressReward = mapId <= claimedThrough,
            pointMap = {},
        }
    end
    return mapMetas, gemMaps
end

test.describe("GemMining map progress", function()
    test.beforeEach(function()
        mock.unload(MANAGER_MODULE)
        mock.unload(LOCAL_SERVER_MODULE)
    end)

    test.it("reads all 20 maps from activity config", function()
        local mapMetas, gemMaps = createMapData(20, 4)
        local localServer = loadLocalServer({
            digGemMapMetaList = mapMetas,
            gemMaps = gemMaps,
        })

        assert.equals(localServer:getMapNum(), 20)
        assert.equals(localServer:getNowMapId(), 5)
        assert.falsy(localServer:hasClaimedAllMapRewards())
    end)

    test.it("uses configured map ids instead of assuming contiguous ids", function()
        local localServer = loadLocalServer({
            digGemMapMetaList = {
                { mapId = 20 },
                { mapId = 2 },
                { mapId = 10 },
            },
            gemMaps = {
                ["2"] = { progressReward = true },
                ["10"] = { progressReward = false },
                ["20"] = { progressReward = false },
            },
        })

        assert.equals(localServer:getMapNum(), 3)
        assert.equals(localServer:getNowMapId(), 10)
    end)

    test.it("does not report graduation when configured map data is missing", function()
        local localServer = loadLocalServer({
            digGemMapMetaList = {
                { mapId = 0 },
                { mapId = 1 },
            },
            gemMaps = {
                ["0"] = { progressReward = true },
            },
        })

        assert.falsy(localServer:hasClaimedAllMapRewards())
    end)

    test.it("reports graduation only after every configured reward is claimed", function()
        local mapMetas, gemMaps = createMapData(20, 19)
        local localServer = loadLocalServer({
            digGemMapMetaList = mapMetas,
            gemMaps = gemMaps,
        })

        assert.equals(localServer:getNowMapId(), -1)
        assert.truthy(localServer:hasClaimedAllMapRewards())
    end)

    test.it("does not reset the same period when id types differ", function()
        local resetForNewPeriod = spy.fn()
        local localData = {
            getDataByKey = function(_, key)
                if key == "periodId" then return "7" end
            end,
            resetForNewPeriod = resetForNewPeriod,
            fromServer = spy.fn(),
            setDataByKey = spy.fn(),
        }
        local manager = loadManager(localData)

        manager:parseData({
            periodId = 7,
        })

        assert.notCalled(resetForNewPeriod)
        assert.called(localData.fromServer)
    end)

    test.it("does not reset before the first server period is stored", function()
        local resetForNewPeriod = spy.fn()
        local localData = {
            getDataByKey = function() end,
            resetForNewPeriod = resetForNewPeriod,
            fromServer = spy.fn(),
            setDataByKey = spy.fn(),
        }
        local manager = loadManager(localData)

        manager:parseData({
            periodId = 1,
        })

        assert.notCalled(resetForNewPeriod)
        assert.called(localData.fromServer)
    end)

    test.it("clears period progress and keeps reusable config on period change", function()
        local resetForNewPeriod = spy.fn()
        local localData = {
            getDataByKey = function(_, key)
                if key == "periodId" then return 7 end
                if key == "localConfig" then
                    return {
                        digGemMapMetaList = {
                            { mapId = 0 },
                        },
                    }
                end
            end,
            resetForNewPeriod = resetForNewPeriod,
            fromServer = spy.fn(),
            setDataByKey = spy.fn(),
        }
        local manager = loadManager(localData)
        local serverData = {
            periodId = 8,
        }

        manager:parseData(serverData)

        assert.called(resetForNewPeriod)
        assert.truthy(serverData.extra)
        assert.called(localData.fromServer)
    end)

    test.it("keeps cached actInfo while clearing period progress", function()
        local storage = {
            cachedActInfo = {
                actId = 6057,
                marker = "online",
            },
            periodId = 7,
            gemMaps = {
                ["0"] = {
                    progressReward = true,
                },
            },
        }
        local localServer = loadLocalServer(storage)
        localServer.reset = function()
            for key in pairs(storage) do
                storage[key] = nil
            end
        end

        localServer:resetForNewPeriod()

        assert.equals(localServer:getCachedActInfo().marker, "online")
        assert.nilValue(storage.periodId)
        assert.nilValue(storage.gemMaps)
    end)

    test.it("treats the main end timestamp as reward phase only", function()
        local now = 199
        mock.global("TimeKit", {
            timeInSec = function()
                return now
            end,
        })
        local localServer = loadLocalServer({})
        localServer.actTime = {
            mainBeginTime = 100,
            mainEndTime = 200,
            endTime = 300,
        }

        assert.truthy(localServer:isActInMain())
        assert.falsy(localServer:isActInReward())

        now = 200

        assert.falsy(localServer:isActInMain())
        assert.truthy(localServer:isActInReward())
    end)

    test.it("adds passed level collections during the main phase", function()
        local addCollectNum = spy.fn()
        local localData = {
            isActInMain = function()
                return true
            end,
            addCollectNum = addCollectNum,
        }
        local manager = loadManager(localData)
        local passLevelJson = {
            collectionInfo = {
                ["6057"] = {
                    totalCount = 5,
                },
            },
        }

        manager:updatePassLevelData({
            settleMentState = true,
        }, 5, nil, {
            passLevelJson = passLevelJson,
        })

        assert.calledWith(addCollectNum, localData, 5)
        assert.truthy(passLevelJson.collectionInfo)
    end)

    test.it("keeps crossed-period display data but removes backend collections", function()
        local addCollectNum = spy.fn()
        local localData = {
            isActInMain = function()
                return false
            end,
            addCollectNum = addCollectNum,
        }
        local manager = loadManager(localData)
        local passLevelJson = {
            collectionInfo = {
                ["6057"] = {
                    totalCount = 5,
                },
            },
            keepField = true,
        }
        local notifyViewData = {
            collectionCount = 5,
        }

        manager:updatePassLevelData({
            settleMentState = true,
        }, 5, nil, {
            passLevelJson = passLevelJson,
            notifyViewData = notifyViewData,
        })

        assert.notCalled(addCollectNum)
        assert.nilValue(passLevelJson.collectionInfo)
        assert.truthy(passLevelJson.keepField)
        assert.equals(notifyViewData.collectionCount, 5)
    end)
end)
