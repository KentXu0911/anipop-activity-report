local LoginEventCenter = require "amf.feature.login.event.LoginEventCenter"
local Model = require "amf.feature.localactivity.cloudmusictask.model.CloudMusicTaskReport2026Model"
local Const = require "amf.feature.localactivity.cloudmusictask.const.CloudMusicTaskReport2026Const"

local Manager = class("CloudMusicTaskReportManager")

local function validUid(uid)
    return type(uid) == "string" and uid ~= ""
end

function Manager:ctor()
    self.foreground = true
    self.elapsed = 0
end

function Manager:initialize()
    self.model = Model:create()
    LoginEventCenter:register(LoginEvent.Login.COMMON_LOGIN_SUCCESS, self.onLoginSuccess, self)
    _G.amfEC:registerSystem(self)
end

function Manager:onSystemOpenUrl(event)
    local data = event:getData()
    local launch
    if data.source == "app" then
        launch = self:parseLaunchParams(data.payload)
    elseif data.source == "mini_game" then
        launch = self:parseMiniGameLaunchParams(data.payload)
    end
    if not launch then return end
    if not self.launch or self.launch.encryptUid ~= launch.encryptUid then self.elapsed = 0 end
    self.launch = launch
    if _G.kUserLogin then self:requestCloudMusicTaskReport2026(Const.REPORT_TYPE_LOGIN) end
    self:syncTimer()
end

function Manager:onLoginSuccess()
    if self.launch then self:requestCloudMusicTaskReport2026(Const.REPORT_TYPE_LOGIN) end
end

function Manager:onSystemEnterBackground()
    self.foreground = false
    self:syncTimer()
end

function Manager:onSystemEnterForeground()
    self.foreground = true
    self:syncTimer()
end

function Manager:parseLaunchParams(parsed)
    return self:parseParams(parsed.method, parsed.para)
end

function Manager:parseMiniGameLaunchParams(options)
    local query = options.query
    if type(query) ~= "table" then return nil end
    return self:parseParams(query and query.scene, query)
end

function Manager:parseParams(method, params)
    if method ~= Const.METHOD or type(params) ~= "table" then return nil end
    local uid = params.encryptUid
    return validUid(uid) and { encryptUid = uid } or nil
end

function Manager:requestCloudMusicTaskReport2026(reportType)
    return self.model:requestCloudMusicTaskReport2026(self.launch and self.launch.encryptUid, reportType)
end

function Manager:syncTimer()
    local shouldRun = self.launch and self.foreground and self.elapsed < Const.ONLINE_SECONDS
    if shouldRun and not self.timerId then
        self.timerId = TimerUtil.addAlarm(function()
            self.elapsed = self.elapsed + 1
            if self.elapsed >= Const.ONLINE_SECONDS then
                self:requestCloudMusicTaskReport2026(Const.REPORT_TYPE_ONLINE)
                self:syncTimer()
            end
        end, 1, 0)
    elseif not shouldRun and self.timerId then
        TimerUtil.removeAlarm(self.timerId)
        self.timerId = nil
    end
end

return Manager
