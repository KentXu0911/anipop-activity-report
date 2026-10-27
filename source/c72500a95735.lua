local ILocalPush = require "amf.middleware.notification.localpush.system.ILocalPush"
local LocalPush = class("LocalPush").implement(ILocalPush)

local _notificationUtil = luajava.bindClass("com.happyelements.hellolua.share.NotificationUtil")
local _notificationsUtils = luajava.bindClass("com.happyelements.android.utils.NotificationsUtils")
-- 添加闹钟
function LocalPush:addAlarm(structAlarm)
    if EnvUtil:isAndroidNoNetworkMode() then return end

    pcall(function ()
        local alarmId = self:getAlarmId(structAlarm)
        _notificationUtil:addLocalNotification2(structAlarm.timeOffset, structAlarm.title, structAlarm.message, alarmId, structAlarm.voiceId, structAlarm.labelType)
    end)
end

-- 删除闹钟
function LocalPush:removeAlarm(structAlarm)
    if EnvUtil:isAndroidNoNetworkMode() then return end
    local function cancelLocal()
        local alarmId = self:getAlarmId(structAlarm)
        _notificationUtil:cancelLocalNotification(alarmId)
    end
    pcall(cancelLocal)
end

-- 删除全部闹钟
function LocalPush:removeAllAlarm(structList)
    for _, v in ipairs(structList) do
        self:removeAlarm(v)
    end
end

-- 获得闹钟id
function LocalPush:getAlarmId(structAlarm)
    return tostring(structAlarm.type) .. ":" .. tostring(structAlarm.timeStamp)
end

-- 是否开启了通知
function LocalPush:hasOpenNotification()
    local isNotificationOpened = false
    pcall(function()
        isNotificationOpened = _notificationsUtils:isNotificationEnabled()
    end)
    return isNotificationOpened
end

-- 打开设置
function LocalPush:openNotificationSetting()
    _notificationsUtils:openNotificationSetting()
end

return LocalPush