local LocalPush = {}
local groupKey = "lucky_delivery"

local PUSH_CONFIG = {
    {
        title = "📦 您有一个「幸运快递」待签收！",
        message = "好久不见！「幸运快递」全村派送中，进游戏领取！",
    },
    {
        title = "📦 您有一个「幸运快递」待签收！",
        message = "「幸运快递」开业啦！天天拆快递，闯关爆惊喜！",
    },
    {
        title = "🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔",
        message = "在吗？今天的「幸运快递」到了，进游戏签收！",
    },
    {
        title = "莱萌鸡",
        message = "开门开门！你的幸运快递送到了！",
    },
}

function LocalPush:removeLocalPush()
    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
        action = "remove",
        groupKey = groupKey,
    })
end

function LocalPush:scheduleDay2Push(loginTimeStamp)
    if not LocalPushConst then return end

    local config = PUSH_CONFIG[math.random(1, #PUSH_CONFIG)]
    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
        action = "add",
        type = LocalPushConst.LocalPushType.ACTIVITY1,
        timeStamp = loginTimeStamp + 3600 * 23.5,
        title = config.title,
        message = config.message,
        groupKey = groupKey,
    })
end

return LocalPush
