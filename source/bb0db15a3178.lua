local LocalPush = {}

local pushType = 45

function LocalPush:removeLocalPush()
    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
        type = pushType,
        action = "remove",
    })
end

function LocalPush:checkLocalPush()
    self:removeLocalPush()
    local ripenTime = _G.amfBean("CollectWordManager"):getRipenTime()
    ripenTime = math.floor(ripenTime/1000)
    if ripenTime > TimeKit:timeInSec() then
        _G.amfTransaction(TransactionEvent.LOCALPUSH, {
            action = "add",
            type = pushType,
            timeStamp = ripenTime
        })    
    end
end

return LocalPush