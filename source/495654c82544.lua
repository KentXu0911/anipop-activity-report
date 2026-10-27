local ShopRewardLocalPushLogic = class("ShopRewardLocalPushLogic")

function ShopRewardLocalPushLogic:create(manager)
    local logic = ShopRewardLocalPushLogic.new()
    logic:init(manager)
    return logic
end

function ShopRewardLocalPushLogic:init(manager)
    self.manager = manager
end

function ShopRewardLocalPushLogic:getGroupKey()
    return self.manager:getConst().LocalPushGroupKey
end

function ShopRewardLocalPushLogic:cancelPush()
    if not LocalPushConst then return end

    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
        action = "remove",
        groupKey = self:getGroupKey(),
    })
end

function ShopRewardLocalPushLogic:getNextPushTime(now)
    now = now or TimeKit:timeInSec()

    local const = self.manager:getConst()
    local todayStart = TimeKit:getDayStartTimeByTS(now)
    local secondsPerHour = 60 * 60
    local secondsPerDay = 24 * secondsPerHour
    local cutoff = const.LocalPushCutoffSeconds or 0
    local hours = const.LocalPushHours or {}

    for dayOffset = 0, 1 do
        local dayStart = todayStart + dayOffset * secondsPerDay
        for _, hour in ipairs(hours) do
            local pushTime = dayStart + hour * secondsPerHour
            if pushTime > now and pushTime - now >= cutoff then
                return pushTime
            end
        end
    end
end

function ShopRewardLocalPushLogic:tryRegisterPush()
    if EnvUtil:isMiniGame() then return end
    if not LocalPushConst then return end

    self:cancelPush()

    if not self.manager:isEnabled() then return end

    local now = TimeKit:timeInSec()
    local mainEndTime = self.manager:getMainEndTime() or 0
    if mainEndTime <= now then return end

    local pushTime = self:getNextPushTime(now)
    if not pushTime then return end
    if pushTime >= mainEndTime then return end

    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
        action = "add",
        type = self.manager:getConst().LocalPushType,
        timeStamp = pushTime,
        groupKey = self:getGroupKey(),
    })
end

return ShopRewardLocalPushLogic
