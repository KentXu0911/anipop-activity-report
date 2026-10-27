local ActInfoStateOverride = {}

local function normalizeNonNegativeInteger(value)
    value = tonumber(value)
    if not value then
        return 0
    end
    return math.max(0, math.floor(value))
end

local function applyProviderReminderState(provider, writer, actInfo, context)
    local apply = type(provider) == "table"
        and provider.applyActInfoReminderState
        or nil
    if apply == nil then
        return {}
    end
    if type(apply) ~= "function" then
        error("ICON_V2_ACT_INFO_REMINDER_STATE_FUNCTION_REQUIRED", 3)
    end
    local consumed = apply(provider, writer, actInfo, context)
    if consumed == nil then
        return {}
    end
    if type(consumed) ~= "table" then
        error("ICON_V2_ACT_INFO_REMINDER_STATE_RESULT_TABLE_REQUIRED", 3)
    end
    return consumed
end

function ActInfoStateOverride.apply(writer, actInfo, context, provider)
    if type(actInfo) ~= "table" then
        return false
    end
    local consumed = applyProviderReminderState(provider, writer, actInfo, context)

    local applied = false
    if not consumed.reward and rawget(actInfo, "reward") ~= nil then
        writer:setRewardVisible(actInfo.reward == true)
        applied = true
    end
    if not consumed.msgNum and rawget(actInfo, "msgNum") ~= nil then
        writer:setRedDotCount(normalizeNonNegativeInteger(actInfo.msgNum))
        applied = true
    end

    return applied or next(consumed) ~= nil
end

return ActInfoStateOverride
