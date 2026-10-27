local Manager = class("LocalPushManager")

local TimeUtil = require "amf.middleware.ui.util.TimeUtil" 
local StructAddAlarm = require "amf.middleware.notification.localpush.model.StructAddAlarm" 
local LocalPushUtil = require "amf.middleware.notification.localpush.util.LocalPushUtil"
require "amf.middleware.notification.localpush.config.LocalPushConst"
local ExitGameEventCenter = require "amf.middleware.exit.event.ExitGameEventCenter"

function Manager:ctor()
    self._metaManager = nil
end

function Manager:setMetaManager(metaManager)
    self._metaManager = metaManager
end

function Manager:initialize()
    if not FeatureSwitch:isOpen(FeatureSwitch.Type.LOCAL_PUSH) then return end
    -- 鸿蒙不生效，直接关了吧
    if EnvUtil:isOhos() then return end
    -- 推送SDK
    self._localPushSDK = require ("amf.middleware.notification.localpush.LocalPushSDK").new()
    -- 本地推送数据
    self._model = require ("amf.middleware.notification.localpush.model.LocalPushModel"):create()
    self._noLimitPushList = {}
    self._limitPushList = {}
    -- 监听事件
    _G.amfEC:registerTransaction(self)
    _G.amfEC:registerSystem(self, SystemEventPriority.LOCAL_PUSH)
    _G.amfEC:registerFeature(self)
    ExitGameEventCenter:register(ExitGameEvent.CONFIRM_EXIT_GAME, function()
        -- 加推送
        self:onSystemEnterBackground()
    end)
    
    -- 删除记录的已经加过的闹钟
    self:onSystemEnterForeground()
    self._isInit = true
end

function Manager:onActTestButtonReady()
    addGlobalTestButton("本地推送测试", function()
        local TestPanelVM = require "amf.middleware.notification.localpush.test.TestPanelVM"
        TestPanelVM.Builder.new()
                   :setTitle("测试本地推送")
                   :build()
                   :popout()
    end, {
        TestButtonConst.Tags.ACTIVITY,
    })
end

function Manager:isEnabled()
    return self._isInit
end

-- 收到事件
-- 添加闹钟
-- data = {
--     type = type,                 -- 闹钟type
--     timeStamp = timeStamp,   -- 推送时间
--     groupKey = groupKey      -- 选传，定义组，方便删除所有
--     title = title,           -- 选传，自定义文案, 不传就用配置的
--     message = message,       -- 选传，自定义文案, 不传就用配置的
--     params = {},             -- 选传，自定义参数，不传就没有
-- }
-- 删除闹钟
-- data = {
--     type = type,              -- 删除对应type，无法做到删除同一个type，不同时间的推送；需要全部删除，重新添加
--     groupKey = groupKey,      -- 可以单独传，删除自定义组的所有
-- }
function Manager:onReceiveTransaction(evt)
    if not self:isEnabled() then return end
    if evt:getName() ~= TransactionEvent.LOCALPUSH then return end
    local data = evt:getData()
    if data.action == "add" then
        -- 闹钟时间不对
        if not LocalPushUtil:checkAddAlarmTimeValid(data.timeStamp) then return end
        -- 没有配置
        if not self:getNotificationMeta(data.type) then return end
        -- 加闹钟
        self:addNotification(data)
    elseif data.action == "remove" then
        if EnvUtil:isDevelopMode() then
            -- 公用的活动push 类型
            if tonumber(data.type) and table.exist(LocalPushConst.ACT_TYPES, tonumber(data.type)) then
                CommonTip:showTip("删除闹钟有问题，活动用公用类型，删除不要传type，需要传入groupKey")
                ALog.error("删除闹钟有问题，活动用公用类型，删除不要传type，需要传入groupKey")
                return
            end
        end
        -- 删除闹钟
        self:removeNotification(data)
    elseif data.action == "removeAll" then
        -- 删除所有闹钟
        self:removePushedAlarms()
    else
        assert(false, "LocalPushManager:onReceiveTransaction: action is not add or remove")
    end
end

-- 获取推送配置
function Manager:getNotificationMeta(type)
    local allNotificationMeta = self:getAllNotificationMeta()
    for k, v in pairs(allNotificationMeta) do
        if v.type == type then
            return _G.READ_ONLY(v)
        end
    end
    return nil
end

-- 获取所有推送配置
function Manager:getAllNotificationMeta()
    if table.isEmpty(self._localPushMetas) then
        local LocalPushMetaRef = require "amf.middleware.notification.localpush.model.LocalPushMetaRef"
        self._localPushMetas = self._metaManager:parseOrderedList("notification_v2", LocalPushMetaRef)
        -- 删除不可用的和not active的
        for id, v in pairs(self._localPushMetas) do
            if not v.activate or v.pusher ~= LocalPushConst.PushType.CLIENT then
                self._localPushMetas[id] = nil
            end
        end
    end
    return self._localPushMetas
end

-- 添加闹钟
function Manager:addNotification(data, fromRevert)
    local metaCfg = self:getNotificationMeta(data.type)
    local structAddAlarm = StructAddAlarm.new()
        :setType(data.type)
        :setTimeStamp(data.timeStamp)
        :setVoiceId(metaCfg.channel)
        :setLabelType(metaCfg.textId)
        :setGroupKey(data.groupKey)
    -- 修改文案，title，message ...
    structAddAlarm = LocalPushUtil:makeStructRandomMessage(structAddAlarm, metaCfg, data)
    --每天22:00~次日7:00，不会给玩家发送任何推送；如果此时触发时效类推送，改为次日7:00后发
    structAddAlarm = LocalPushUtil:makeStructChangePushTime(structAddAlarm, metaCfg)
    -- 修改推送时间 这里不能修改时间，因为不能确定是要推上午还是下午，有优先级问题
    local function ifHas(list, data)
        local tmpList = list or {}
        for i, v in ipairs(tmpList) do
            if v.type == data.type and v.timeStamp == data.timeStamp then
                return true, i
            end
        end
        return false
    end
    local function ifHasByLimit(list, data)
        local tmpList = list or {}
        for i, v in ipairs(tmpList) do
            local dayIdx = TimeKit:getDayStartTimeByTS(TimeUtil:convertSec(data.timeStamp))
            local vDayIdx = TimeKit:getDayStartTimeByTS(TimeUtil:convertSec(v.timeStamp))
            if v.type == data.type and dayIdx == vDayIdx then
                return true, i
            end
        end
        return false
    end
    -- 加到对应列表中
    if metaCfg.groupId == LocalPushConst.AlarmType.NO_LIMIT then
        local has, index = ifHas(self._noLimitPushList, data)
        if has then
            if not fromRevert then -- 如果是还原操作就不替换原本的，新添进来的和原本的相同就替换
                self._noLimitPushList[index] = structAddAlarm
            -- else
            --     self:log("fromRevert nolimit -- ", tts(data))
            end
        else
            table.insert(self._noLimitPushList, structAddAlarm)
        end
    else
        local has, index = ifHasByLimit(self._limitPushList, data)
        if has then
            if not fromRevert then -- 如果是还原操作就不替换原本的，新添进来的和原本的相同就替换
                self._limitPushList[index] = structAddAlarm
            -- else
            --     self:log("fromRevert limit -- ", tts(data))
            end
        else
            table.insert(self._limitPushList, structAddAlarm)
        end
    end
    -- print("addNotification  ----", tts(self._limitPushList), tts(self._noLimitPushList))
end

-- 删除闹钟
function Manager:removeNotification(data)
    local type = data.type
    local groupKey = data.groupKey
    local timeStamp = data.timeStamp
    -- 删除即时闹钟
    for i = #self._noLimitPushList, 1, -1 do
        if ((type and self._noLimitPushList[i].type == type) 
            and (not timeStamp or (timeStamp and self._noLimitPushList[i].timeStamp == timeStamp)))
            or (groupKey and self._noLimitPushList[i].groupKey == groupKey) then
            table.remove(self._noLimitPushList, i)
        end
    end
    -- 删除限制闹钟
    for i = #self._limitPushList, 1, -1 do
        if (type and self._limitPushList[i].type == type) or (groupKey and self._limitPushList[i].groupKey == groupKey) then
            table.remove(self._limitPushList, i)
        end
    end
    -- print("removeNotification ----", tts(self._limitPushList), tts(self._noLimitPushList))
end

function Manager:removePushedAlarms()
    local pushedList = self._model:getValue("localPushList") or {}
    self._localPushSDK:removeAllAlarm(pushedList or {})
    -- if EnvUtil:isDevelopMode() then
    --     self:log("removeAlarms ---", tts(pushedList))
    -- end
    self._model:setValue("localPushList", {}, true)
end

-- 还原已经添加的闹钟,加到临时列表中
function Manager:revertPushedAlarms()
    -- 先把所有闹钟
    local pushedList = self._model:getValue("localPushList") or {}
    for i, v in ipairs(pushedList) do
        self:addNotification(v, true)
    end
    -- if EnvUtil:isDevelopMode() then
    --     self:log("revertPushedAlarms _limitPushList---", tts(self._limitPushList))
    --     self:log("revertPushedAlarms _NolimitPushList---", tts(self._noLimitPushList))
    -- end
end

-- 到前台事件
function Manager:onSystemEnterForeground()
    if not self:isEnabled() then return end
    -- 先把所有闹钟还原了再删除
    self:revertPushedAlarms()
    -- 删除所有闹钟
    self:removePushedAlarms()
end

-- 到后台事件之后
function Manager:onSystemEnterBackground()
    if not self:isEnabled() then return end
    local list = self:getPushList()

    -- 先删除所有闹钟，再去添加，因为有不知名问题会导致alarm数量到500上限
    self._localPushSDK:removeAllAlarm(list)

    -- 先存
    self._model:setValue("localPushList", list, true)
    -- 添加闹钟
    for _, v in ipairs(list) do
        self._localPushSDK:addAlarm(v)
    end
    if EnvUtil:isDevelopMode() then
        self:log("LocalPush: 添加闹钟列表:结果:", tts(list))
    end
end

function Manager:getLimitPushList()
    local dayMap = {}
    -- 限制推送的
    for i, v in ipairs(self._limitPushList) do
        local day = tostring(TimeKit:getDayStartTimeByTS(TimeUtil:convertSec(v.timeStamp)))
        if dayMap[day] == nil then
            dayMap[day] = {}
        end
        table.insert(dayMap[day], v)
    end
    for k, vList in pairs(dayMap) do
        table.sort(vList, function (a, b)
            local metaCfgA = self:getNotificationMeta(a.type)
            local metaCfgB = self:getNotificationMeta(b.type)
            return metaCfgA.priority < metaCfgB.priority
        end)
    end
    -- 限制推送列表
    local limitList = {}
    for dayStr, vList in pairs(dayMap) do
        local day = tonumber(dayStr)
        for index, v in ipairs(vList) do
            local metaCfg = self:getNotificationMeta(v.type)
            -- 找出上午优先级最高的要推送的
            if metaCfg.groupLimit == LocalPushConst.GroupLimitTime.LIMIT1 or metaCfg.groupLimit == LocalPushConst.GroupLimitTime.LIMIT2 then
                local timeStamp = day + 3600 * 8
                if LocalPushUtil:checkAddAlarmTimeValid(timeStamp) and not LocalPushUtil:isNearOneHour(timeStamp) then
                    v:setTimeStamp(timeStamp)
                    local context = table.remove(vList, index)
                    table.insert(limitList, context)
                    break
                end
            end
        end
        for index, v in ipairs(vList) do
            local metaCfg = self:getNotificationMeta(v.type)
            -- 找出下午优先级最高的要推送的
            if metaCfg.groupLimit == LocalPushConst.GroupLimitTime.LIMIT1 or metaCfg.groupLimit == LocalPushConst.GroupLimitTime.LIMIT3 then
                --换算到指定时间
                local timeStamp = day + 3600*20.5

                if LocalPushUtil:checkAddAlarmTimeValid(timeStamp) and not LocalPushUtil:isNearOneHour(timeStamp) then
                    v:setTimeStamp(timeStamp)
                    local context = table.remove( vList, index )
                    table.insert( limitList, context )
                end
                break
            end
        end
    end
    return limitList
end

function Manager:getNolimitPushList()
    -- 时效性推送的 规则
    local dayMap = {}
    for i, v in ipairs(self._noLimitPushList) do
        local day = tostring(TimeKit:getDayStartTimeByTS(TimeUtil:convertSec(v.timeStamp)))
        if dayMap[day] == nil then
            dayMap[day] = {}
        end
        if LocalPushUtil:checkAddAlarmTimeValid(v.timeStamp) then
            table.insert(dayMap[day], v)
        end
    end
    for k, vList in pairs(dayMap) do
        table.sort(vList, function (a, b)
            local metaCfgA = self:getNotificationMeta(a.type)
            local metaCfgB = self:getNotificationMeta(b.type)
            if metaCfgA.priority ~= metaCfgB.priority then
                return metaCfgA.priority < metaCfgB.priority
            else
                return a.timeStamp < b.timeStamp
            end
        end)
    end
    local noLimitList = {}
    local cacheAddMap = {}
    local notAddMap = {}
    for dayStr, vList in pairs(dayMap) do
        for i, v in ipairs(vList) do
            if not cacheAddMap[dayStr] then
                cacheAddMap[dayStr] = {}
            end
            if not notAddMap[dayStr] then
                notAddMap[dayStr] = {}
            end
            if v.groupKey then
                if LocalPushConst.NO_LIMIT_RULE.GROUPKEY[tostring(v.groupKey)] then
                    table.insert(noLimitList, v)
                else
                    if not cacheAddMap[dayStr][v.groupKey] then
                        table.insert(noLimitList, v)
                        cacheAddMap[dayStr][v.groupKey] = true
                    else
                        table.insert(notAddMap[dayStr], v)
                    end
                end
            else
                if LocalPushConst.NO_LIMIT_RULE.TYPE[tostring(v.type)] then
                    table.insert(noLimitList, v)
                else
                    if not cacheAddMap[dayStr][tostring(v.type)] then
                        table.insert(noLimitList, v)
                        cacheAddMap[dayStr][tostring(v.type)] = true
                    else
                        table.insert(notAddMap[dayStr], v)
                    end
                end
            end
        end
    end
    if EnvUtil:isDevelopMode() then
        self:log("闹钟notAddMap =-====", tts(notAddMap))
    end
    return noLimitList
end

-- 获得要推送的列表
function Manager:getPushList()
    local limitList = self:getLimitPushList()
    local noLimitList = self:getNolimitPushList()
    -- self:log("getPushList : noLimitList ----", tts(noLimitList), " limitList = ", tts(limitList))
    -- 合并要推送的列表
    local list = table.union(noLimitList, limitList)
    return list
end

function Manager:log(...)
    if EnvUtil:isDevelopMode() then
        printx(27, "LocalPushLog: ", ...)
    end
end

return Manager