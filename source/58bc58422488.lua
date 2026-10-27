local LocalPush = {}
local groupKey = "happy_delivery"

local PUSH_TITLE   =  {
    "📦 您有一个「开心快递」待签收！",
    "📦 您有一个「开心快递」待签收！",
    "🔔🔔🔔🔔🔔🔔🔔🔔🔔🔔",
    "莱萌鸡"
}
local PUSH_MESSAGE = {
    "好久不见！「开心快递」全村派送中，进游戏领取！",
    "「开心快递」开业啦！天天拆快递，闯关爆惊喜！",
    "在吗？今天的「开心快递」到了，进游戏签收！",
    "开门开门！你的开心快递送到了！",
}

function LocalPush:removeLocalPush()
    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
        action   = "remove",
        groupKey = groupKey,
    })
end

function LocalPush:scheduleDay2Push(loginTimeStamp)
    if not LocalPushConst then return end
    local random = math.random(1, 4)
    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
        action    = "add",
        type      = LocalPushConst.LocalPushType.ACTIVITY1,
        timeStamp = loginTimeStamp + 3600 * 23.5,
        title     = PUSH_TITLE[random],
        message   = PUSH_MESSAGE[random],
        groupKey  = groupKey,
    })
end

return LocalPush
