local Group = {}

local _groupKey = "minigame_sign_in"
local _currenGroup = nil

function Group:getGroup()
	if EnvUtil:isMiniGame() then
		if _currenGroup == nil then
			local gorups = MaintenanceManager:getInstance():getGroupChildRangeMap( _groupKey )
			local currGroup = "OFF"
			for _ , group in ipairs( gorups or {} ) do
				local key = group.modules and group.modules[1]
				if key and MaintenanceManager:getInstance():isEnabledInGroup( _groupKey , key ) then
					currGroup = key
					break
				end
			end
			_currenGroup = currGroup
		end
	else
		_currenGroup = "ON"
	end
	return _currenGroup
end

function Group:isOff()
    return self:getGroup() == "OFF"
end

return Group