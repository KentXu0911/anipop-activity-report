local AMFRequest = require "amf.middleware.interconnection.remote.core.AMFRequest"
local Request = class("GetUBFuuuStatisticInfoHttp", AMFRequest)

local config = {
    protocol = "ubfGetLevelStatisticInfo",
    reqType = AMFSyncConst.RequestType.IMMEDIATELY,
    loading = false,
    useMockData = false
}

function Request:getMockData()
    local mockData = {
    }
    return mockData, 0
end

function Request:post(params, hostObj)
    return Request:run(config, params, hostObj)
end

return Request
