local LocalPush = {}
local pushType = 17

function LocalPush:removeLocalPush()
    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
		action = "remove",
        type = pushType,
    })
end

function LocalPush:checkLocalPush()
	if not LocalPushConst then return end
    self:removeLocalPush()
    local configTopLevel = _G.amfBean("LevelUnLockManager"):getLocalTopLevel()
	local userTopLevel = _G.getTopLevelId()

	if userTopLevel >= configTopLevel - 5 then

		local countdownAreaId = _G.amfBean("LevelUnLockManager"):getNextCountdownArea()
		local countdownAreaId_Now = _G.amfBean("LevelUnLockManager"):getCurCountdownArea()
		if countdownAreaId or countdownAreaId_Now then
			local now = TimeKit:timeInSec()
			local endTime = _G.amfBean("LevelUnLockManager"):getCountdownEndTime(countdownAreaId_Now or countdownAreaId)
			if endTime and endTime > 0 and endTime > now then
				local notiTime = endTime - __g_utcDiffSeconds
                _G.amfTransaction(TransactionEvent.LOCALPUSH, {
					action = "add",
                    type = pushType,
                    timeStamp = notiTime,
                })
			end
		end
	end
end

return LocalPush