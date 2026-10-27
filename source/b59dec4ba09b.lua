local ActivityParticipationMgr = class("ActivityParticipationMgr")

local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local LOG_TAG = "ActivityParticipationMgr"
local ACTIVE_LOW_INTENT_SWITCH = "active_low_intent"
local ACTIVE_LOW_INTENT_GROUP_L2 = "ON1"
local ACTIVE_LOW_INTENT_GROUP_L2_L3 = "ON2"
local CONFIGURED_MAIN_PANEL_MANAGERS = {
    [6077] = "FishingWinnerManager",
}

local function logAutoPopupDecision(actId, dataReady, level, group, shouldReduce, reason)
    if not EnvUtil:isDevelopMode() then
        return
    end

    local outcome = "allowed"
    if shouldReduce then
        outcome = "blocked"
    end

    local message = string.format(
        "[active_low_intent] auto popup %s actId=%s dataReady=%s level=%s group=%s reason=%s",
        outcome,
        tostring(actId),
        tostring(dataReady),
        tostring(level),
        tostring(group),
        reason)
    if EnvUtil:isMiniGame() then
        UError(message)
        return
    end
    printx(22, message)
end

function ActivityParticipationMgr:ctor()
    self._activityMgr = nil
    self._participationMap = {}
    self._dataReady = false
end

function ActivityParticipationMgr:setActivityMgr(activityMgr)
    self._activityMgr = activityMgr
end

function ActivityParticipationMgr:initialize()
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActInfosUpdate, self)
    self:_parse(self._activityMgr:getActivityParticipationTags())
end

function ActivityParticipationMgr:onActInfosUpdate(event)
    local data = event:getData()
    if data and data.fromServer and data.activityParticipationTags ~= nil then
        self:_parse(data.activityParticipationTags)
    end
end

function ActivityParticipationMgr:_parse(rawValue)
    local participationMap = {}

    if rawValue == nil or rawValue == "" then
        self._participationMap = participationMap
        self._dataReady = rawValue == ""
        return
    end

    if type(rawValue) ~= "string" then
        ALog.error(LOG_TAG, "activityParticipationTags must be a string")
        self._participationMap = participationMap
        self._dataReady = false
        return
    end

    for item in string.gmatch(rawValue, "([^;]+)") do
        local actIdValue, levelValue, depthValue = string.match(item, "^(%d+)_L([1-4])_(.*)$")
        local actId = tonumber(actIdValue)
        local level = tonumber(levelValue)
        local depth
        local valid = actId ~= nil and actId > 0

        if valid and level == 4 then
            depth = tonumber(depthValue)
            valid = depth ~= nil and depth >= 0 and depth <= 1
        elseif valid then
            valid = depthValue == ""
        end

        if not valid then
            ALog.error(LOG_TAG, "invalid participation item: " .. tostring(item))
        elseif participationMap[actId] then
            ALog.error(LOG_TAG, "duplicate activity id: " .. tostring(actId))
        else
            participationMap[actId] = {
                actId = actId,
                level = level,
                depth = depth,
            }
        end
    end

    self._participationMap = participationMap
    self._dataReady = true
end

function ActivityParticipationMgr:isDataReady()
    return self._dataReady
end

function ActivityParticipationMgr:shouldShowActivityCardByTag(actId)
    actId = tonumber(actId)
    if not actId or not self._dataReady then
        return true
    end
    local level = self:getLevel(actId)
    return level ~= nil and level >= 3
end

function ActivityParticipationMgr:shouldReduceAutoPopup(actId)
    if not self._dataReady then
        logAutoPopupDecision(actId, false, nil, nil, false, "data_not_ready")
        return false
    end

    local level = self:getLevel(actId)
    if level == nil then
        logAutoPopupDecision(actId, true, nil, nil, false, "activity_tag_missing")
        return false
    end

    local maintenance = MaintenanceManager:getInstance()
    local group
    if maintenance:isEnabledInGroup(ACTIVE_LOW_INTENT_SWITCH, ACTIVE_LOW_INTENT_GROUP_L2) then
        group = ACTIVE_LOW_INTENT_GROUP_L2
    elseif maintenance:isEnabledInGroup(ACTIVE_LOW_INTENT_SWITCH, ACTIVE_LOW_INTENT_GROUP_L2_L3) then
        group = ACTIVE_LOW_INTENT_GROUP_L2_L3
    end

    local shouldReduce = false
    if group == ACTIVE_LOW_INTENT_GROUP_L2 then
        shouldReduce = level == 2
    elseif group == ACTIVE_LOW_INTENT_GROUP_L2_L3 then
        shouldReduce = level == 2 or level == 3
    end

    local reason
    if shouldReduce then
        reason = "group_level_matched"
    elseif group == nil then
        reason = "group_not_matched"
    else
        reason = "level_not_reduced_by_group"
    end
    logAutoPopupDecision(actId, true, level, group, shouldReduce, reason)
    return shouldReduce
end

function ActivityParticipationMgr:shouldReduceConfiguredMainPanelAutoPopup(actId)
    local managerName = CONFIGURED_MAIN_PANEL_MANAGERS[tonumber(actId)]
    if not managerName then
        return false
    end

    local manager = _G.amfBean(managerName)
    if manager:hasEnteredCurrentPeriod() then
        return false
    end
    return self:shouldReduceAutoPopup(actId)
end

function ActivityParticipationMgr:getParticipation(actId)
    local participation = self._participationMap[tonumber(actId)]
    return participation and table.clone(participation) or nil
end

function ActivityParticipationMgr:getLevel(actId)
    local participation = self._participationMap[tonumber(actId)]
    return participation and participation.level or nil
end

function ActivityParticipationMgr:getDepth(actId)
    local participation = self._participationMap[tonumber(actId)]
    return participation and participation.depth or nil
end

function ActivityParticipationMgr:hasTag(actId)
    return self._participationMap[tonumber(actId)] ~= nil
end

function ActivityParticipationMgr:isEligible(actId)
    return self:hasTag(actId)
end

function ActivityParticipationMgr:isExposed(actId)
    local level = self:getLevel(actId)
    return level ~= nil and level >= 2
end

function ActivityParticipationMgr:hasRealParticipation(actId)
    return self:getLevel(actId) == 4
end

function ActivityParticipationMgr:getAllParticipations()
    local participations = {}
    for _, participation in pairs(self._participationMap) do
        table.insert(participations, table.clone(participation))
    end
    table.sort(participations, function(a, b)
        return a.actId < b.actId
    end)
    return participations
end

return ActivityParticipationMgr
