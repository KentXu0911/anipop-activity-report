-- 本地推送
local LocalPush = {}
local pushType = 54

function LocalPush:removeLocalPush()
    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
        action = "remove",
        -- type = pushType,
        groupKey = "suppermagicbird", -- 用groupKey删除，不然你把别人的54类型都给删了
    })
end

function LocalPush:checkLocalPush()
    self:removeLocalPush()

    local curTime = TimeKit:timeInSec()
    local config = {
        [1] = { time = curTime + 1*3600, text = "检测到您上一关还未结束，请尽快回归，保住超级魔力鸟！" }, 
        [2] = { time = curTime + 24*3600, text = "检测到您上一关意外退出游戏，请尽快回归，保住超级魔力鸟！" }
    }

    for i, v in ipairs(config) do
        _G.amfTransaction(TransactionEvent.LOCALPUSH, {
            type = pushType,
            action = "add",
            timeStamp = v.time,
            title = "超级魔力鸟提醒",
            message = v.text,
            groupKey = "suppermagicbird",
        })
    end
end

return LocalPush