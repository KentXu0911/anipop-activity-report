local deferred = require "amf.script.sugar.deferred"
local Result = require "amf.script.datastruct.Result"
local ActivityConfigLoader = {}

-- 下载activity_config
local function requestActivityConfig(configName, successCallback, failCallback, tryCount)
    tryCount = tryCount or 1
    local url = AMFNetworkConfig:getMaintenanceURL()
    local uid = _G.amfBean("UserManager"):getUid()

    local deviceIdParam = ""
    if EnvUtil:isDevelopMode() then
        deviceIdParam = "&deviceid=" .. tostring(MetaInfo.getInstance():getUdid())
    end
    local params = string.format("?name=%s&uid=%s&_v=%s%s", configName, uid, _G.bundleVersion, deviceIdParam)
    url = url .. params

    local function onCallback(response) -- 整个Activity的大配置文件加载完毕
        if response.httpCode ~= 200 then
            tryCount = tryCount - 1
            if tryCount > 0 then
                requestActivityConfig(configName, successCallback, failCallback, tryCount)
                return
            else
                safeRunCall(failCallback)
            end
        else
            safeRunCall(successCallback, response.body)
        end
    end
    AMFSimpleRequest.new(url, onCallback):setTimeoutMs(30 * 1000):setConnectionTimeoutMs(2000):setGet(true):execute()
end

function ActivityConfigLoader:parseConfig(xmlData)
    local d = deferred.new()
    local activitiesXML
    pcall(function()
        local activityXML = xml.eval(xmlData)
        activitiesXML = xml.find(activityXML, "activitys")
    end)
    if not activitiesXML then
        d:reject(Result.error(ActivityConst.ConfigError.PARSE_ERROR), "parse activity_config error")
        return d
    end

    local ret = {}
    for _, v in pairs(activitiesXML) do
        if type(v) == "table" then
            v[0] = nil
            table.insert(ret, v)
        end
    end
    
    d:resolve(Result.success({
        activities = ret,
        rootUrl = activitiesXML.url_root or "",
    }))
    return d
end

function ActivityConfigLoader:loadRemote(configName, successCallback, failCallback, tryCount)
    ALog.log("activity", "load remote config")
    requestActivityConfig(configName, successCallback, failCallback, tryCount)
end

function ActivityConfigLoader:getConfig(configName)
    local d = deferred.new()
    if self._isGetting then
        d:reject()
        return d
    end
    self._isGetting = true
    local function successCallback(xmlData)
        self._isGetting = false
        d:resolve(Result.success(xmlData))
    end

    local function failCallback()
        self._isGetting = false
        d:reject(Result.error(ActivityConst.ConfigError.DOWNLOAD_ERROR), "download activity_config fail")
    end

    self:loadRemote(configName, successCallback, failCallback, 1)

    return d
end

function ActivityConfigLoader:load(configName)
    return self:getConfig(configName):next(function(res)
        return self:parseConfig(res.data)
    end)
end

return ActivityConfigLoader
