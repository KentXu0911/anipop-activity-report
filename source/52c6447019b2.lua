local WeekTaskBroadCastContext = require 'amf.feature.localactivity.weektask.broadcast.WeekTaskBroadCastContext'

local WeekTaskBanner = class('WeekTaskBanner')

function WeekTaskBanner:create()
	local instance = WeekTaskBanner.new()
	instance:init()
	return instance
end

function WeekTaskBanner:init()
	--记录刚刚完成的任务信息
	self.completeTaskInfos = {}
end

function WeekTaskBanner:addActCompleteInfos( completeTaskInfos )

	if EnvUtil:isMiniGame() then return end
	if not completeTaskInfos then return end

	--local info = { weekDay = weekDay, taskId=taskId, taskType = taskType, oldValue = curValue, newValue = k.curValue}

	local function checkCurHasSameInfo( info )
		for i,v in ipairs(self.completeTaskInfos) do
			if v.weekDay == info.weekDay and v.taskId == info.taskId and v.taskType == info.taskType and v.oldValue == info.oldValue and v.newValue == info.newValue then
				return true
			end
		end
		return false
	end

	for i,v in ipairs(completeTaskInfos) do
		if not checkCurHasSameInfo(v) then
			table.insert( self.completeTaskInfos, v )
		end
	end
end

function WeekTaskBanner:checkCanPopStage3()
	--关卡任务、关卡收集强弹检测
	return #self.completeTaskInfos > 0
end

function WeekTaskBanner:doPopBanner()
	--执行弹出banner
	if #self.completeTaskInfos > 2 then
		local priority = _G.BroadCastConst.Priority.CUSTOM
		local context = WeekTaskBroadCastContext:create(priority)
		context:setPopInfo({moreComplete=true}) 
		_G.amfTransaction(TransactionEvent.BROADCAST, context)
	else
		for i,v in ipairs(self.completeTaskInfos) do
			local priority = _G.BroadCastConst.Priority.CUSTOM
			local context = WeekTaskBroadCastContext:create(priority)
			context:setPopInfo(table.clone(v)) 
			_G.amfTransaction(TransactionEvent.BROADCAST, context)
		end
	end
	--清空队列
	self.completeTaskInfos = {}
end

return WeekTaskBanner