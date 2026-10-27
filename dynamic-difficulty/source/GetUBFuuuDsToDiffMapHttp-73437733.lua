local AMFRequest = require "amf.middleware.interconnection.remote.core.AMFRequest"
local Request = class("GetUBFuuuDsToDiffMapHttp", AMFRequest)

local config = {
    protocol = "ubfuuuGetNext30DiffFixDataV2",
    reqType = AMFSyncConst.RequestType.ONLINE,
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
