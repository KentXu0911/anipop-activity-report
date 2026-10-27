local LocalPush = {}

local pushType = {
    USER_LOSE1 		= 30,		-- 用户流失7day
	USER_LOSE2 		= 31, 		-- 用户流失8day
	USER_LOSE3 		= 32, 		-- 用户流失9day
}
function LocalPush:removeLocalPush()
    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
        action = "remove",
        groupKey = "userLose"
    })
end

function LocalPush:checkLocalPush()
    if not LocalPushConst then return end
    self:removeLocalPush()
    local cutTime = os.time()
	local todayStartTime = TimeKit:getDayStartTimeByTS(cutTime)
	local dayTime = 86400

	local notifyTimeList = {}
	notifyTimeList[1] = todayStartTime + dayTime*7
	notifyTimeList[2] = todayStartTime + dayTime*8
	notifyTimeList[3] = todayStartTime + dayTime*9

	for i = 1, 3 do
        _G.amfTransaction(TransactionEvent.LOCALPUSH, {
            action = "add",
            type = pushType["USER_LOSE"..i],
            timeStamp = notifyTimeList[i],
            groupKey = "userLose"
        })
	end
end

return LocalPush