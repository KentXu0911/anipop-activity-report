local LocalPush = {}

local MAIN_PUSH_TYPE = 71
local AWARD_PUSH_TYPE = 72
local PUSH_HOUR = 18
local SECONDS_PER_HOUR = 3600
local SECONDS_PER_DAY = 86400

-- 注册一条指定时间的本地推送，文案由 notification_v2 配置提供。
local function addPush(pushType, timeStamp)
    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
        action = "add",
        type = pushType,
        timeStamp = timeStamp,
    })
end

-- 两个推送类型由每日夺宝独占，重新计算前先删除旧推送。
function LocalPush:cancel()
    if not LocalPushConst or EnvUtil:isMiniGame() then return end
    for _, pushType in ipairs({MAIN_PUSH_TYPE, AWARD_PUSH_TYPE}) do
        _G.amfTransaction(TransactionEvent.LOCALPUSH, {
            action = "remove",
            type = pushType,
        })
    end
end

function LocalPush:register(mgr)
    if not LocalPushConst or EnvUtil:isMiniGame() then return end
    -- 每次进入后台都以最新活动数据重建，避免保留已经失效或已领取的推送。
    self:cancel()

    -- 活动时间由服务端以毫秒下发，本地推送接口使用秒。
    local now = TimeKit:timeInSec()
    local beginTime = TimeKit:tryConvertMsToSec(mgr:getDataValue("beginTime", 0))
    local mainEndTime = TimeKit:tryConvertMsToSec(mgr:getDataValue("mainEndTime", 0))
    local endTime = TimeKit:tryConvertMsToSec(mgr:getDataValue("endTime", 0))
    if not beginTime or not mainEndTime or not endTime or now >= endTime then return end

    -- 遍历正式期内从今天开始的每一天，只在周六、周日的 18:00 推送。
    local todayStart = TimeKit:getDayStartTimeByTS(now)
    local dayStart = TimeKit:getDayStartTimeByTS(math.max(now, beginTime))
    while dayStart < mainEndTime do
        local pushTime = dayStart + PUSH_HOUR * SECONDS_PER_HOUR
        -- 当天使用当前剩余次数判断；未来日期按跨天会刷新一次免费机会进行预测。
        -- now < beginTime 表示活动尚未开始，此时首日也应按未来日期处理。
        local hasPlayCount = dayStart > todayStart or now < beginTime or mgr:getMsgNum() > 0
        -- 只添加尚未到达、且完整落在正式期内的周末 18:00 推送；18:00 后不补发当天推送。
        if pushTime > now and pushTime >= beginTime and pushTime < mainEndTime
            and isWeekend(pushTime) and hasPlayCount then
            addPush(MAIN_PUSH_TYPE, pushTime)
        end
        dayStart = dayStart + SECONDS_PER_DAY
    end

    -- 不要求当前已经进入领奖期，按现有宝箱和奖券数据预测领奖期是否有奖可领。
    if not mgr:canClaimAwardReward() then return end
    -- 有奖可领时，为领奖期内每一天的 18:00 注册推送，已过 18:00 的当天不再补发。
    dayStart = TimeKit:getDayStartTimeByTS(math.max(now, mainEndTime))
    while dayStart < endTime do
        local pushTime = dayStart + PUSH_HOUR * SECONDS_PER_HOUR
        if pushTime > now and pushTime >= mainEndTime and pushTime < endTime then
            addPush(AWARD_PUSH_TYPE, pushTime)
        end
        dayStart = dayStart + SECONDS_PER_DAY
    end
end

return LocalPush
