local AutoPopupDebugLog = require "amf.middleware.autopop.AutoPopupDebugLog"

local ServerConfigDefault = require "amf.middleware.autopop.config.ServerConfigDefault"
local ServerConfigMgr = class("ServerConfigMgr")

function ServerConfigMgr:create()
	local mgr = ServerConfigMgr.new()
	mgr:init()
	return mgr
end

function ServerConfigMgr:init()
	self.popTypeNumLimit = {}
	self.popTypeFullPriority = {}
	self.popTypeSubPriority = {}
end

function ServerConfigMgr:update(serverData)
	for stageIndex,config in pairs(serverData) do
		local stageKey = AutoPopupConst.PopStageKeyMapping[tostring(stageIndex)]
		if stageKey then
			self.popTypeNumLimit[stageKey] = {}
			local popTypeNumLimit = config.popTypeNumLimit or {}
			for popTypeServerKey,popTypeKey in pairs(AutoPopupConst.PopTypeKeyMapping) do
				local popNum = popTypeNumLimit[popTypeServerKey] or 0
				if popNum == -1 then popNum = 99 end
				self.popTypeNumLimit[stageKey][popTypeKey] = popNum
			end

			self.popTypeFullPriority[stageKey] = {}
			local popTypeFullPriority = config.popTypeFullPriority or {}
			for i,popTypeServerKey in ipairs(popTypeFullPriority) do
				local popTypeKey = AutoPopupConst.PopTypeKeyMapping[tostring(popTypeServerKey)]
				table.insert(self.popTypeFullPriority[stageKey], popTypeKey)
			end

			self.popTypeSubPriority[stageKey] = {}
			local popTypeSubPriority = config.popTypeSubPriority or {}
			for i,popTypeServerKey in ipairs(popTypeSubPriority) do
				local popTypeKey = AutoPopupConst.PopTypeKeyMapping[tostring(popTypeServerKey)]
				table.insert(self.popTypeSubPriority[stageKey], popTypeKey)
			end
		end
	end

	AutoPopupDebugLog:log("popTypeNumLimit ==>", table.tostring(self.popTypeNumLimit))
	AutoPopupDebugLog:log("popTypeFullPriority ==>", table.tostring(self.popTypeFullPriority))
	AutoPopupDebugLog:log("popTypeSubPriority ==>", table.tostring(self.popTypeSubPriority))
end

function ServerConfigMgr:getPopTypeLimitNum(popStage, popType)
	if self.popTypeNumLimit[popStage] and self.popTypeNumLimit[popStage][popType] then
		return self.popTypeNumLimit[popStage][popType]
	end
	return ServerConfigDefault.PopTypeNumLimit[popStage][popType]
end

function ServerConfigMgr:getPopTypeFullPriority(popStage)
	if self.popTypeFullPriority[popStage] then
		return self.popTypeFullPriority[popStage]
	end
	return ServerConfigDefault.PopTypeFullPriority[popStage]
end

function ServerConfigMgr:getPopTypeSubPriority(popStage)
	if self.popTypeSubPriority[popStage] then
		return self.popTypeSubPriority[popStage]
	end
	return ServerConfigDefault.PopTypeSubPriority[popStage]
end

return ServerConfigMgr