local LocalPush = {}

local pushType = 2

function LocalPush:removeLocalPush()
    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
        type = pushType,
        action = "remove",
    })
end

function LocalPush:checkLocalPush(notifyTime)
    self:removeLocalPush()
    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
        type = pushType,
        action = "add",
        timeStamp = notifyTime,
        -- title = localize("unlock.cloud.panel.time.notification"),
        -- message = "查看"
    })
end

return LocalPush