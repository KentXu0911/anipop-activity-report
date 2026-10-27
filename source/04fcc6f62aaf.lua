local IconV2Experiment = {}

local EXPERIMENT_NAME = "NewVineicon_v2"
local ENABLED_GROUP = "ON"
local snapshots = {}

local function getCurrentUid()
    local userManager = _G.amfBean("UserManager")
    local uid = userManager and userManager:getUid()
    if uid == nil or tonumber(uid) == 0 or tonumber(uid) == 12345 then
        return nil
    end
    return tostring(uid)
end

local function resolveEnabled()
    local uid = getCurrentUid()
    if not uid then return false end

    local snapshot = snapshots[uid]
    if snapshot ~= nil then
        return snapshot
    end

    local maintenanceManager = MaintenanceManager:getInstance()
    local enabled = maintenanceManager:isEnabledInGroup(EXPERIMENT_NAME, ENABLED_GROUP, uid)
    snapshot = enabled == true
    snapshots[uid] = snapshot
    return snapshot
end

function IconV2Experiment:isEnabled()
    local success, enabled = pcall(resolveEnabled)
    return success and enabled == true
end

function IconV2Experiment:getExpandedVisualScale()
    if not EnvUtil:isMiniGame() then
        return 1
    end
    return self:isEnabled() and 0.9 or 1
end

return IconV2Experiment
