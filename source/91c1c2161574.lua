local LocalPush = {}
local pushType = 42
function LocalPush:removeLocalPush()
	_G.amfTransaction(TransactionEvent.LOCALPUSH, {
		action = "remove",
		type = pushType,
		groupKey = PromoteDailyConst.ACT_ID
	})
end

function LocalPush:addLocalPush(medalId)
    local cfg = _G.amfBean("PromoteDailyMgr"):getKeyDayMedalCfgById(medalId)
    if not cfg then return end
    local timeStamp = getDayStartTimeByTS(cfg.beginTime) + 12 * 3600

    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
		action = "add",
		type = pushType,
		timeStamp = timeStamp,
		groupKey = PromoteDailyConst.ACT_ID
	})
end

function LocalPush:addDailyPush()
	local timeStamp = getDayStartTimeByTS(TimeKit:timeInSec())
	timeStamp = timeStamp + 3600 * 20 + 1800 -- 30分钟
	_G.amfTransaction(TransactionEvent.LOCALPUSH, {
		action = "add",
		type = pushType,
		timeStamp = timeStamp,
		groupKey = PromoteDailyConst.ACT_ID
	})
end

function LocalPush:addActPush(pushList)
	for i, v in ipairs(pushList) do
		_G.amfTransaction(TransactionEvent.LOCALPUSH, {
			action = "add",
			timeStamp = v.time,
			title = v.title,
			message = v.content,
			groupKey = PromoteDailyConst.ACT_ID,
			type = v.typeId
		})
	end
end

return LocalPush