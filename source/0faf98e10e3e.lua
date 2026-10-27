local LocalPush = {}

local pushType = 20

function LocalPush:removeLocalPush()
    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
        action = "remove",
        type = pushType,
    })
end

-- 检查添加推送
function LocalPush:checkLocalPush(enablePush)
    if not LocalPushConst then return end
    self:removeLocalPush()
    if not enablePush then return end
    local fullEnergyTimeOff = _G.amfBean("UserEnergyManager"):computeFullEnergyTime()
    if fullEnergyTimeOff > 0 then
		local targetTime = TimeKit:timeInSec() + fullEnergyTimeOff
        _G.amfTransaction(TransactionEvent.LOCALPUSH, {
            action = "add",
            type = pushType,
            timeStamp = targetTime,
        })
    end
end

return LocalPush