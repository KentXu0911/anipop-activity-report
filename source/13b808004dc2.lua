local LocalPush = {}
local pushType = 29
local pushType2 = 23
local groupKey = "mark_localPush"
function LocalPush:removeLocalPush()
	_G.amfTransaction(TransactionEvent.LOCALPUSH, {
		action = "remove",
		groupKey = groupKey
	})
end

function LocalPush:checkLocalPush29()
	-- 1，如果当日已签到，不推
	if not _G.amfBean("MarkManager") or _G.amfBean("MarkManager"):isTodayMarked() then return end
	-- 4，要在 晚6~10点 之间
	-- 计算当前时间+30分钟=time，如果time大于10点，不推。如果time小于6点则等于6点，注册time的闹钟
	local delay = 1800
	local currentTime = TimeKit:timeInSec()
	local nextTime = currentTime+delay
	local date = os.date("*t",nextTime)

	if date.hour>=22 then return end
	if date.hour < 18 then
		date.hour = 18
		date.min = 0
		nextTime = os.time2(date)
	end
	_G.amfTransaction(TransactionEvent.LOCALPUSH, {
		action = "add",
		type = pushType,
		timeStamp = nextTime,
		groupKey = groupKey,
	})
end

function LocalPush:checkLocalPush23()
	local mgr = _G.amfBean("MarkManager")
	if not mgr then return end
	local monthRewardState = mgr:getMarkValue("monthRewardState")
	if monthRewardState > 0 then return end
	local signCount = mgr:getMonthSignCount()
	if signCount < 15 then return end
	local dayStatusList = mgr:getMarkValue("dayStatusList") or {}
    local days = table.count(dayStatusList)
	local todaySigned = mgr:isTodayMarked()
	local curDay = mgr:getCurDay()
	for i = 1,3 do
		local date = {}
	    date.year = mgr:getCurYear()
	    date.month = mgr:getCurMonth()
		date.day = days-i+1

	    if date.day > curDay or (date.day == curDay and not todaySigned) then
			-- 19点推送
			date.hour = 19
			local nextDayTime = os.time2(date)
			_G.amfTransaction(TransactionEvent.LOCALPUSH, {
				action = "add",
				type = pushType2,
				timeStamp = nextDayTime,
				groupKey = groupKey,
			})
		end
	end
end

return LocalPush