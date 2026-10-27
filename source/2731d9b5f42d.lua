local NewActivityPolicy = {}

local ValidTypes = {
    A = true,
    B = true,
    C = true,
    none = true,
}

local ReminderByType = {
    A = { kind = "redDot", scale = 1.00 },
    B = { kind = "new", scale = 1.00 },
    C = { kind = "new", scale = 1.00 },
}

local function isNonEmptyString(value)
    return type(value) == "string" and value ~= ""
end

local function copyReminder(reminder)
    if reminder == nil then
        return nil
    end
    return {
        kind = reminder.kind,
        scale = reminder.scale,
    }
end

local function emitDiagnostic(logger, code, data)
    if logger == nil then
        return
    end
    if type(logger) == "function" then
        pcall(logger, code, data)
        return
    end
    if type(logger) ~= "table" then
        return
    end
    local method = logger.warn or logger.log
    if type(method) == "function" then
        pcall(method, logger, code, data)
    end
end

local function resolveCycleKey(config, iconConfig, options)
    if isNonEmptyString(iconConfig.newActivityCycleKey) then
        return iconConfig.newActivityCycleKey
    end
    if isNonEmptyString(options.fallbackCycleKey) then
        return options.fallbackCycleKey
    end
    if type(options.resolveCycleKey) == "function" then
        local ok, value = pcall(options.resolveCycleKey, config)
        if ok and isNonEmptyString(value) then
            return value
        end
    end
end

local function isConsumed(records, key)
    if key == nil or records == nil then
        return false
    end
    local getter = records.isConsumed or records.get
    if type(getter) ~= "function" then
        return false
    end
    local ok, value = pcall(getter, records, key)
    return ok and (value == true or (type(value) == "number" and value > 0))
end

function NewActivityPolicy.resolve(config, options)
    options = options or {}
    local iconConfig = type(config) == "table" and type(config.icon) == "table" and config.icon or {}
    local rawType = iconConfig.newActivityType
    local activityType = rawType
    if not ValidTypes[activityType] then
        activityType = "A"
        emitDiagnostic(options.logger, "ICON_V2_NEW_ACTIVITY_TYPE_INVALID", {
            value = rawType,
            fallback = activityType,
        })
    end

    local rawFirstOpen = iconConfig.firstOpenUseCNotification
    if rawFirstOpen ~= nil and type(rawFirstOpen) ~= "boolean" then
        emitDiagnostic(options.logger, "ICON_V2_FIRST_OPEN_C_FLAG_INVALID", {
            valueType = type(rawFirstOpen),
        })
    end

    local cycleKey = resolveCycleKey(config, iconConfig, options)
    if activityType ~= "none" and not isNonEmptyString(cycleKey) then
        emitDiagnostic(options.logger, "ICON_V2_NEW_ACTIVITY_CYCLE_KEY_MISSING", {
            activityType = activityType,
        })
        cycleKey = nil
    end

    local featureKey = isNonEmptyString(iconConfig.newActivityFeatureKey)
        and iconConfig.newActivityFeatureKey or nil
    local firstOpenUseCNotification = activityType == "B" and rawFirstOpen == true
    if firstOpenUseCNotification and featureKey == nil then
        emitDiagnostic(options.logger, "ICON_V2_NEW_ACTIVITY_FEATURE_KEY_MISSING", {
            activityType = activityType,
        })
        firstOpenUseCNotification = false
    end

    local policy = {
        activityType = activityType,
        enabled = activityType ~= "none",
        reminder = copyReminder(ReminderByType[activityType]),
        cycleKey = cycleKey,
        featureKey = featureKey,
        firstOpenUseCNotification = firstOpenUseCNotification,
    }
    if cycleKey ~= nil then
        policy.newClearedRecordKey = cycleKey
        policy.noticeShownRecordKey = cycleKey .. "_icon_v2_notice_shown"
        policy.legacyPanelShownRecordKey = cycleKey .. "_panel"
    end
    if featureKey ~= nil then
        policy.firstCRecordKey = featureKey .. "_icon_v2_first_c_notification"
    end
    return policy
end

function NewActivityPolicy.evaluate(policy, records)
    assert(type(policy) == "table", "ICON_V2_NEW_ACTIVITY_POLICY_REQUIRED")
    local newVisible = policy.enabled == true
        and policy.newClearedRecordKey ~= nil
        and not isConsumed(records, policy.newClearedRecordKey)
    local noticeShown = isConsumed(records, policy.noticeShownRecordKey)
        or isConsumed(records, policy.legacyPanelShownRecordKey)
    local firstCConsumed = isConsumed(records, policy.firstCRecordKey)
    local temporaryC = policy.activityType == "B"
        and policy.firstOpenUseCNotification == true
        and policy.firstCRecordKey ~= nil
        and not firstCConsumed
    local notificationEligible = newVisible
        and not noticeShown
        and (policy.activityType == "C" or temporaryC)

    return {
        newVisible = newVisible,
        reminder = newVisible and copyReminder(policy.reminder) or nil,
        notificationEligible = notificationEligible,
        temporaryC = temporaryC,
        noticeShown = noticeShown,
        firstCConsumed = firstCConsumed,
    }
end

function NewActivityPolicy.buildNotificationCandidate(policy, records, metadata)
    local evaluation = NewActivityPolicy.evaluate(policy, records)
    if not evaluation.notificationEligible then
        return nil
    end
    local candidate = {}
    for key, value in pairs(metadata or {}) do
        candidate[key] = value
    end
    candidate.activityType = policy.activityType
    candidate.cycleKey = policy.cycleKey
    candidate.featureKey = policy.featureKey
    candidate.newClearedRecordKey = policy.newClearedRecordKey
    candidate.noticeShownRecordKey = policy.noticeShownRecordKey
    candidate.firstCRecordKey = policy.firstCRecordKey
    candidate.temporaryC = evaluation.temporaryC
    return candidate
end

return NewActivityPolicy
