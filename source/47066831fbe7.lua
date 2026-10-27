local Group = {}

local _groupList = {    
    ["StarPalace_h5"] = {
        defaultGroup = "old",
        currentGroup = nil,
    }
}

function Group:getModuleName(modules)
	if not modules or #modules == 0 then return end
	
	local moduleName = modules[1]
	local currIndex = 2
	
	while modules[currIndex] do
		moduleName = moduleName .. "_" .. modules[currIndex]
		currIndex = currIndex + 1
	end

	return moduleName
end

function Group:getGroupByKey(key)
    if not _groupList[key] then return end

    if _groupList[key].currentGroup == nil then
		local groups = MaintenanceManager:getInstance():getGroupChildRangeMap(key)
		local currentGroup = _groupList[key].defaultGroup

		for _ , group in ipairs(groups or {}) do
			local moduleKey = group.modules and self:getModuleName(group.modules)
			if moduleKey and MaintenanceManager:getInstance():isEnabledInGroup(key, moduleKey) then
				currentGroup = moduleKey
				break
			end
		end

		_groupList[key].currentGroup = currentGroup
	end

	return _groupList[key].currentGroup
end

function Group:getUITestGroup()
    return self:getGroupByKey("StarPalace_h5")
end

function Group:isFeatureEnabled()
	if EnvUtil:isMiniGame() then
		return self:getUITestGroup() == "ON"
	end

	return true
end

return Group