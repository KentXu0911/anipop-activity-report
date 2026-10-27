-- 候选启动策略：当前生产入口仍使用 ProphetLaunchStrategy。
-- 切换前必须保持新旧黑盒等价测试通过，不允许同时执行两套 apply。
local ProphetLaunchStrategy2 = {}

if not RustProphet then
    require "ubf.UBFPlay.rust.RustProphet"
end

local NEW_USER_PROPHET_CONFIGS =
    require "ubf.UBFPlay.rust.ProphetNewUserExperienceConfig"

local NEW_USER_CONFIG_KEYS = {
    ordinary = "newuser_prophet_ordinary",
    smooth = "newuser_prophet_smooth",
}

for configType, configKey in pairs(NEW_USER_CONFIG_KEYS) do
    local config = NEW_USER_PROPHET_CONFIGS[configType]
    if config then
        RustProphet.config[configKey] = config
    end
end

local NEW_USER_SMOOTH_LEVEL_IDS = {
    [8] = true, [11] = true, [14] = true, [17] = true, [20] = true,
    [23] = true, [26] = true, [29] = true, [32] = true, [35] = true,
    [38] = true, [40] = true, [43] = true, [45] = true, [48] = true,
    [50] = true, [53] = true, [55] = true, [58] = true, [60] = true,
    [63] = true, [65] = true, [68] = true, [70] = true, [73] = true,
    [75] = true, [78] = true, [80] = true, [83] = true, [85] = true,
    [88] = true, [90] = true, [93] = true, [95] = true, [98] = true,
    [100] = true, [103] = true, [105] = true, [108] = true, [110] = true,
    [113] = true, [115] = true, [118] = true, [120] = true, [123] = true,
    [125] = true, [128] = true, [130] = true, [133] = true, [135] = true,
    [138] = true, [140] = true, [143] = true, [145] = true, [148] = true,
    [150] = true, [153] = true, [155] = true, [158] = true, [160] = true,
    [163] = true, [165] = true, [168] = true, [170] = true, [173] = true,
    [175] = true, [178] = true, [180] = true, [183] = true, [185] = true,
    [188] = true, [190] = true, [193] = true, [195] = true, [198] = true,
    [200] = true,
}

local EXPERIENCE_ROUTES = {
    {
        id = "hard_no_super_bird",
        when = {
            { field = "difficultyClass", op = "eq", value = "hard" },
            { field = "superBirdActive", op = "eq", value = false },
        },
        configs = {
            tracking_only = RustProphet.enum.EXPERIENCE_NEAR_PASS_TRACKING_ONLY,
            full = RustProphet.enum.EXPERIENCE_NEAR_PASS,
        },
    },
    {
        id = "hard_with_super_bird",
        when = {
            { field = "difficultyClass", op = "eq", value = "hard" },
            { field = "superBirdActive", op = "eq", value = true },
        },
        configs = {
            tracking_only = RustProphet.enum.EXPERIENCE_NEAR_PASS_TRACKING_ONLY,
            full = RustProphet.enum.EXPERIENCE_NEAR_PASS,
        },
    },
    {
        id = "normal_no_super_bird_baodi",
        when = {
            { field = "difficultyClass", op = "eq", value = "normal" },
            { field = "superBirdActive", op = "eq", value = false },
            { field = "toplevelBaoDi", op = "eq", value = true },
        },
        configs = {
            tracking_only =
                RustProphet.enum.EXPERIENCE_NEAR_PASS_GUARANTEED_TRACKING_ONLY,
            full = RustProphet.enum.EXPERIENCE_NEAR_PASS_GUARANTEED,
        },
    },
    {
        id = "normal_no_super_bird",
        when = {
            { field = "difficultyClass", op = "eq", value = "normal" },
            { field = "superBirdActive", op = "eq", value = false },
            { field = "toplevelBaoDi", op = "eq", value = false },
        },
        configs = {
            tracking_only = RustProphet.enum.EXPERIENCE_SMOOTH_PASS_TRACKING_ONLY,
            full = RustProphet.enum.EXPERIENCE_SMOOTH_PASS,
        },
    },
    {
        id = "normal_with_super_bird",
        when = {
            { field = "difficultyClass", op = "eq", value = "normal" },
            { field = "superBirdActive", op = "eq", value = true },
        },
        configs = {
            tracking_only =
                RustProphet.enum.EXPERIENCE_VERY_SMOOTH_PASS_TRACKING_ONLY,
            full = RustProphet.enum.EXPERIENCE_VERY_SMOOTH_PASS,
        },
    },
}

local EXPERIENCE_GROUPS = {
    OFF = {
        enableProphet = false,
        requireToplevelBaoDi = false,
    },
    ON1 = {
        enableProphet = true,
        requireToplevelBaoDi = false,
        routeMode = "tracking_only",
    },
    ON2 = {
        enableProphet = true,
        requireToplevelBaoDi = false,
        routeMode = "full",
    },
}

local CONFIG = {
    enabled = true,
    blockedLevelIds = {
        [39] = true, [44] = true, [49] = true, [54] = true,
        [59] = true, [64] = true, [69] = true, [74] = true, [79] = true, [84] = true,
        [89] = true, [94] = true, [99] = true, [104] = true, [109] = true, [114] = true,
        [119] = true, [124] = true, [129] = true, [134] = true, [139] = true, [144] = true, [149] = true,
        [154] = true, [159] = true, [164] = true, [169] = true, [174] = true, [179] = true, [184] = true,
        [189] = true, [194] = true, [199] = true,
    },
    selfFeedbackEnabledWhenLaunched = false,
    actions = {
        "record_decision",
        "set_self_feedback",
        "capture_adjust_fix_info",
        "set_prophet",
        "remove_diff_fix",
    },
    experiments = {
        {
            id = "new_user",
            activation = {
                type = "maintenance_group",
                maintenanceName = "newuser_prophet",
                groups = { "ON" },
            },
            -- 新手期规则未完全满足时继续检查旧体验矩阵，保持现有优先级和回退语义。
            rejectPolicy = "continue",
            conditions = {
                {
                    id = "not_mini_game",
                    field = "isMiniGame",
                    op = "eq",
                    value = false,
                    reason = "platform_not_allowed",
                },
                {
                    id = "android_only",
                    field = "platform",
                    op = "eq",
                    value = "android",
                    reason = "platform_not_allowed",
                },
                {
                    id = "exclude_he",
                    field = "channel",
                    op = "not_eq",
                    value = "he",
                    reason = "platform_not_allowed",
                },
                {
                    id = "bundle_version",
                    field = "bundleVersion",
                    op = "version_min",
                    value = "1.160",
                    reason = "rust_lib_not_allowed",
                },
                {
                    id = "rust_dynamic_ready",
                    field = "isRustDyGoReady",
                    op = "eq",
                    value = true,
                    reason = "rust_lib_not_allowed",
                },
                {
                    id = "rust_runtime",
                    field = "isInRust",
                    op = "eq",
                    value = true,
                    reason = "not_rust",
                },
                {
                    id = "not_replay",
                    field = "isReplay",
                    op = "eq",
                    value = false,
                    reason = "replay",
                },
                {
                    id = "main_level",
                    field = "isMainLevel",
                    op = "eq",
                    value = true,
                    reason = "not_main_level",
                },
                {
                    id = "not_blocked",
                    field = "isBlockedLevel",
                    op = "eq",
                    value = false,
                    reason = "blocked_level",
                },
                {
                    id = "new_user_top_level",
                    field = "userTopLevel",
                    op = "number_max",
                    value = 200,
                    inclusive = false,
                    missingReason = "user_top_level_missing",
                    reason = "user_top_level_above_threshold",
                },
                {
                    id = "check_result",
                    field = "checkResultPresent",
                    op = "eq",
                    value = true,
                    reason = "check_result_missing",
                },
                {
                    id = "difficulty",
                    field = "fixedDesiredDiffAvg",
                    op = "number_max",
                    value = 1.03,
                    epsilon = 0.0001,
                    missingReason = "fixed_desired_diff_missing",
                    reason = "difficulty_above_threshold",
                },
                {
                    id = "level_min",
                    field = "numericLevelId",
                    op = "number_min",
                    value = 1,
                    missingReason = "level_id_invalid",
                    reason = "level_id_out_of_range",
                },
                {
                    id = "level_max",
                    field = "numericLevelId",
                    op = "number_max",
                    value = 200,
                    missingReason = "level_id_invalid",
                    reason = "level_id_out_of_range",
                },
            },
            route = {
                type = "ordered",
                routes = {
                    {
                        id = "new_user_smooth",
                        when = {
                            {
                                field = "numericLevelId",
                                op = "in_set",
                                value = NEW_USER_SMOOTH_LEVEL_IDS,
                            },
                        },
                        configKey = NEW_USER_CONFIG_KEYS.smooth,
                        experienceType = "new_user_smooth",
                        context = { configType = "smooth" },
                    },
                    {
                        id = "new_user_ordinary",
                        when = {},
                        configKey = NEW_USER_CONFIG_KEYS.ordinary,
                        experienceType = "new_user_ordinary",
                        context = { configType = "ordinary" },
                    },
                },
            },
        },
        {
            id = "experience_matrix",
            activation = {
                type = "platform_maintenance",
                groupOrder = { "OFF", "ON1", "ON2", "ON3" },
                platformOrder = { "ohos", "ios", "android_he", "android" },
                platforms = {
                    ohos = {
                        detect = "isOhos",
                        accessId = "ohos",
                        maintenanceName = "prophet_test_oh",
                    },
                    ios = {
                        detect = "isIOS",
                        accessId = "ios",
                        maintenanceName = "prophet_test_ios",
                    },
                    android_he = {
                        detect = "isAndroidPlatform",
                        detectArg = "kHE",
                        accessId = "android",
                        maintenanceName = "prophet_test_he",
                    },
                    android = {
                        detect = "isAndroid",
                        accessId = "android",
                        maintenanceName = "prophet_test_android_nohe",
                    },
                },
                groups = EXPERIENCE_GROUPS,
            },
            rejectPolicy = "return",
            conditionStages = {
                beforeAvailability = {
                    {
                        id = "not_mini_game",
                        field = "isMiniGame",
                        op = "eq",
                        value = false,
                        reason = "platform_not_allowed",
                    },
                    {
                        id = "bundle_version",
                        field = "bundleVersion",
                        op = "version_min",
                        value = "1.160",
                        reason = "rust_lib_not_allowed",
                    },
                    {
                        id = "rust_runtime",
                        field = "isInRust",
                        op = "eq",
                        value = true,
                        reason = "not_rust",
                    },
                    {
                        id = "not_replay",
                        field = "isReplay",
                        op = "eq",
                        value = false,
                        reason = "replay",
                    },
                    {
                        id = "main_level",
                        field = "isMainLevel",
                        op = "eq",
                        value = true,
                        reason = "not_main_level",
                    },
                    {
                        id = "not_blocked",
                        field = "isBlockedLevel",
                        op = "eq",
                        value = false,
                        reason = "blocked_level",
                    },
                },
                afterAvailability = {
                    {
                        id = "experienced_user",
                        field = "userTopLevel",
                        op = "number_min",
                        value = 200,
                        missingReason = "user_top_level_missing",
                        reason = "user_top_level_below_threshold",
                    },
                    {
                        id = "check_result",
                        field = "checkResultPresent",
                        op = "eq",
                        value = true,
                        reason = "check_result_missing",
                    },
                    {
                        id = "difficulty",
                        field = "fixedDesiredDiffAvg",
                        op = "number_max",
                        value = 1.03,
                        epsilon = 0.0001,
                        missingReason = "fixed_desired_diff_missing",
                        reason = "difficulty_above_threshold",
                    },
                },
            },
            route = {
                type = "ordered_by_group_mode",
                routes = EXPERIENCE_ROUTES,
                noMatchReason = "experience_route_not_matched",
            },
        },
    },
}

local unpackValues = _G.unpack or table.unpack

local function findExperiment(experimentId)
    for _, experiment in ipairs(CONFIG.experiments or {}) do
        if experiment.id == experimentId then
            return experiment
        end
    end
    return nil
end

local function safeCall(target, methodName, ...)
    local method = type(target) == "table" and target[methodName] or nil
    if type(method) ~= "function" then
        return false, nil
    end
    local args = { ... }
    local ok, result = pcall(function()
        return method(target, unpackValues(args))
    end)
    return ok, result
end

local function compareVersion(left, right)
    local function toParts(value)
        local parts = {}
        for part in tostring(value or ""):gmatch("[^.]+") do
            parts[#parts + 1] = tonumber(part) or 0
        end
        return parts
    end

    local leftParts = toParts(left)
    local rightParts = toParts(right)
    local count = math.max(#leftParts, #rightParts)
    for index = 1, count do
        local leftValue = leftParts[index] or 0
        local rightValue = rightParts[index] or 0
        if leftValue ~= rightValue then
            return leftValue < rightValue and -1 or 1
        end
    end
    return 0
end

local function detectPlatformProfile(activation)
    if not EnvUtil then
        return nil
    end

    for _, platformId in ipairs(activation.platformOrder or {}) do
        local profile = activation.platforms and activation.platforms[platformId]
        if profile then
            local arg
            if profile.detectArg then
                arg = PlatformNameEnum and PlatformNameEnum[profile.detectArg]
            end
            local ok, matched = safeCall(EnvUtil, profile.detect, arg)
            if ok and matched == true then
                return platformId, profile
            end
        end
    end
    return nil
end

local function getSuperBirdActive(runtime)
    local activityId = UBFActivityIdConst
        and UBFActivityIdConst.kSuperMagicBird2024
    local modMgr = runtime
        and runtime.getModMgr
        and runtime:getModMgr()
    if not activityId or not modMgr then
        return false
    end

    if modMgr.getModContextData then
        local context = modMgr:getModContextData(activityId)
        if type(context) == "table"
            and type(context.smbEffective) == "boolean" then
            return context.smbEffective
        end
    end

    if modMgr.getModData then
        local dataList = modMgr:getModData(activityId)
        local data = type(dataList) == "table" and dataList[1]
        local env = data and data.env
        if type(env) == "table" and type(env.hasSuperPower) == "boolean" then
            return env.hasSuperPower
        end
    end

    return false
end

local function getToplevelBaoDiFlag(checkResult)
    local calculation = checkResult and checkResult.calculateDiffIndexResult
    return calculation and calculation.toplevelBaoDiFlag == true or false
end

local function buildContext(runtime, resultDatas)
    local checkResult = resultDatas and resultDatas.checkResult
    local levelId = runtime
        and runtime.getLevelId
        and runtime:getLevelId()
    local numericLevelId = tonumber(levelId)
    local levelScene = runtime
        and runtime.getLevelScene
        and runtime:getLevelScene()
    local levelJsonData = runtime and runtime.levelJsonData
    if not levelJsonData
        and runtime
        and runtime.getLevelJsonData then
        levelJsonData = runtime:getLevelJsonData()
    end

    local difficultyFlag
    if levelJsonData and levelJsonData.getLevelDifficultFlag then
        difficultyFlag = levelJsonData:getLevelDifficultFlag()
    end
    local normalFlag = LevelDiffcultFlag and LevelDiffcultFlag.kNormal
    local difficultyClass
    if difficultyFlag ~= nil and normalFlag ~= nil then
        difficultyClass = difficultyFlag == normalFlag and "normal" or "hard"
    end

    local userTopLevel
    local ok, value = safeCall(runtime, "getUserTopLevel")
    if ok then
        userTopLevel = tonumber(value)
    end

    local isMiniGame
    ok, value = safeCall(EnvUtil, "isMiniGame")
    if ok then
        isMiniGame = value
    end

    local experienceExperiment = findExperiment("experience_matrix")
    local platformId, platformProfile = detectPlatformProfile(
        experienceExperiment and experienceExperiment.activation or {}
    )
    local channel = platformId == "android_he" and "he" or "other"

    local rustReady
    ok, value = safeCall(runtime, "isRustDyGoReady")
    if ok and value ~= nil then
        rustReady = value
    else
        rustReady = UBFRustManager
            and UBFRustManager.isRustDyGoReady == true
            or false
    end

    local isInRust
    ok, value = safeCall(runtime, "isInRust")
    if ok then
        isInRust = value == true
    else
        isInRust = false
    end

    local isMainLevel = UBFLevelSceneFunc
        and UBFLevelSceneFunc.isMainLevel
        and UBFLevelSceneFunc:isMainLevel(levelScene)
        or false

    return {
        runtime = runtime,
        resultDatas = resultDatas,
        checkResult = checkResult,
        isMiniGame = isMiniGame,
        platform = platformProfile and platformProfile.accessId or nil,
        platformId = platformId,
        platformProfile = platformProfile,
        channel = channel,
        bundleVersion = _G.bundleVersion,
        isRustDyGoReady = rustReady,
        isInRust = isInRust,
        isReplay = _G.REPLAY_STAGE and true or false,
        isMainLevel = isMainLevel,
        levelId = levelId,
        numericLevelId = numericLevelId,
        levelScene = levelScene,
        isBlockedLevel = levelId ~= nil
            and CONFIG.blockedLevelIds[numericLevelId or levelId] == true
            or false,
        checkResultPresent = type(checkResult) == "table",
        userTopLevel = userTopLevel,
        fixedDesiredDiffAvg = checkResult
            and tonumber(checkResult.fixedDesiredDiffAvg),
        desiredDiffAvg = checkResult
            and tonumber(checkResult.desiredDiffAvg),
        diffIndex = checkResult and checkResult.diffIndex,
        toplevelBaoDi = getToplevelBaoDiFlag(checkResult),
        difficultyFlag = difficultyFlag,
        difficultyClass = difficultyClass,
        superBirdActive = getSuperBirdActive(runtime),
        adjustDataPresent = runtime and type(runtime.adjustData) == "table",
    }
end

local function valueMatches(actual, condition)
    local op = condition.op
    local expected = condition.value

    if op == "eq" then
        return actual == expected
    end
    if op == "not_eq" then
        return actual ~= expected
    end
    if op == "in_set" then
        return type(expected) == "table" and expected[actual] == true
    end
    if op == "version_min" then
        return compareVersion(actual, expected) >= 0
    end
    if op == "number_min" or op == "number_max" then
        local numericActual = tonumber(actual)
        local numericExpected = tonumber(expected)
        if numericActual == nil or numericExpected == nil then
            return false
        end
        local epsilon = tonumber(condition.epsilon) or 0
        if op == "number_min" then
            if condition.inclusive == false then
                return numericActual > numericExpected - epsilon
            end
            return numericActual >= numericExpected - epsilon
        end
        if condition.inclusive == false then
            return numericActual < numericExpected + epsilon
        end
        return numericActual <= numericExpected + epsilon
    end
    return false
end

local function expectedDescription(condition)
    return {
        op = condition.op,
        value = condition.value,
        inclusive = condition.inclusive ~= false,
        epsilon = condition.epsilon,
    }
end

local function evaluateConditions(context, conditions)
    for _, condition in ipairs(conditions or {}) do
        local actual = context[condition.field]
        if not valueMatches(actual, condition) then
            local missing = actual == nil
            return false, {
                stage = "condition",
                ruleId = condition.id,
                field = condition.field,
                actual = actual,
                expected = expectedDescription(condition),
                reason = missing and condition.missingReason or condition.reason,
            }
        end
    end
    return true
end

local function routeMatches(context, route)
    return evaluateConditions(context, route.when)
end

local function selectRoute(context, routeConfig, routeMode)
    for _, route in ipairs(routeConfig.routes or {}) do
        local matched = routeMatches(context, route)
        if matched then
            local configKey = route.configKey
            if route.configs then
                configKey = route.configs[routeMode]
            end
            return {
                routeId = route.id,
                configKey = configKey,
                experienceType = route.experienceType or route.id,
                context = route.context,
            }
        end
    end
    return nil
end

local function getMaintenanceManager()
    if not MaintenanceManager or not MaintenanceManager.getInstance then
        return nil
    end
    return MaintenanceManager:getInstance()
end

local function activateMaintenanceGroup(activation)
    local manager = getMaintenanceManager()
    if not manager then
        return nil
    end
    for _, groupName in ipairs(activation.groups or {}) do
        if manager:isEnabledInGroup(activation.maintenanceName, groupName) then
            return {
                group = groupName,
                maintenanceName = activation.maintenanceName,
                experimentSwitch = activation.maintenanceName,
            }
        end
    end
    return nil
end

local function activatePlatformMaintenance(activation, context)
    local manager = getMaintenanceManager()
    local profile = context.platformProfile
    if not manager or not profile then
        return nil
    end

    for _, groupName in ipairs(activation.groupOrder or {}) do
        if manager:isEnabledInGroup(profile.maintenanceName, groupName) then
            return {
                group = groupName,
                groupConfig = activation.groups[groupName],
                maintenanceName = profile.maintenanceName,
                experimentSwitch = "experience_matrix_v1",
                platformId = context.platformId,
            }
        end
    end
    return nil
end

local function activateExperiment(experiment, context)
    local activation = experiment.activation or {}
    if activation.type == "maintenance_group" then
        return activateMaintenanceGroup(activation)
    end
    if activation.type == "platform_maintenance" then
        return activatePlatformMaintenance(activation, context)
    end
    return nil
end

local function isProphetConfigAvailable(configKey)
    return configKey
        and RustProphet
        and RustProphet.config
        and RustProphet.config[configKey] ~= nil
end

local function newUserDecision(context, activation, route)
    local routeContext = route.context or {}
    return {
        available = true,
        enabled = false,
        group = activation.group,
        maintenanceName = activation.maintenanceName,
        experimentSwitch = activation.experimentSwitch,
        configKey = route.configKey,
        removeDiffFix = true,
        originalDiffFix = context.resultDatas and context.resultDatas.diffFix,
        fixedDesiredDiffAvg = context.checkResult
            and context.checkResult.fixedDesiredDiffAvg,
        desiredDiffAvg = context.checkResult
            and context.checkResult.desiredDiffAvg,
        diffIndex = context.checkResult and context.checkResult.diffIndex,
        requireToplevelBaoDi = false,
        toplevelBaoDiFlag = context.toplevelBaoDi,
        experienceType = route.experienceType,
        experienceRouteReason = "new_user_level_route",
        userTopLevel = context.userTopLevel,
        experienceContext = {
            levelId = context.numericLevelId,
            userTopLevel = context.userTopLevel,
            configType = routeContext.configType,
        },
    }
end

local function experienceDecision(context, activation)
    local groupConfig = activation.groupConfig
    return {
        available = groupConfig and groupConfig.enableProphet == true or false,
        enabled = false,
        group = activation.group,
        maintenanceName = activation.maintenanceName,
        experimentSwitch = activation.experimentSwitch,
        configKey = nil,
        removeDiffFix = groupConfig and groupConfig.enableProphet == true or false,
        originalDiffFix = context.resultDatas and context.resultDatas.diffFix,
        fixedDesiredDiffAvg = context.checkResult
            and context.checkResult.fixedDesiredDiffAvg,
        desiredDiffAvg = context.checkResult
            and context.checkResult.desiredDiffAvg,
        diffIndex = context.checkResult and context.checkResult.diffIndex,
        requireToplevelBaoDi = groupConfig
            and groupConfig.requireToplevelBaoDi == true
            or false,
        toplevelBaoDiFlag = context.toplevelBaoDi,
        experienceType = "experience",
    }
end

local function appendAttempt(report, experimentId, status, detail)
    report.attempts[#report.attempts + 1] = {
        experimentId = experimentId,
        status = status,
        detail = detail,
    }
end

local function evaluateNewUser(experiment, context, activation, report)
    local passed, rejection = evaluateConditions(context, experiment.conditions)
    if not passed then
        appendAttempt(report, experiment.id, "rejected", rejection)
        return nil, experiment.rejectPolicy == "continue"
    end

    local route = selectRoute(context, experiment.route)
    if not route then
        local decision = newUserDecision(context, activation, {
            routeId = nil,
            configKey = nil,
            experienceType = "new_user",
            context = {},
        })
        decision.reason = "new_user_route_not_matched"
        appendAttempt(report, experiment.id, "selected_but_disabled", {
            stage = "route",
            ruleId = "no_route_matched",
            reason = decision.reason,
        })
        return decision, false
    end
    local decision = newUserDecision(context, activation, route)
    report.selectedExperiment = experiment.id
    report.selectedRoute = route.routeId

    if not context.adjustDataPresent then
        decision.reason = "adjust_data_missing"
        appendAttempt(report, experiment.id, "selected_but_disabled", {
            stage = "pre_action",
            ruleId = "adjust_data_present",
            field = "adjustDataPresent",
            actual = false,
            expected = { op = "eq", value = true },
            reason = decision.reason,
        })
        return decision, false
    end

    if not isProphetConfigAvailable(decision.configKey) then
        decision.reason = "new_user_config_missing"
        appendAttempt(report, experiment.id, "selected_but_disabled", {
            stage = "route",
            ruleId = route.routeId,
            field = "configKey",
            actual = decision.configKey,
            expected = { op = "registered_config" },
            reason = decision.reason,
        })
        return decision, false
    end

    decision.enabled = true
    decision.reason = "enabled"
    appendAttempt(report, experiment.id, "selected", {
        stage = "route",
        ruleId = route.routeId,
        reason = decision.reason,
    })
    return decision, false
end

local function evaluateExperienceMatrix(experiment, context, activation, report)
    local decision = experienceDecision(context, activation)
    report.selectedExperiment = experiment.id

    if not activation.groupConfig then
        decision.reason = "experience_config_missing"
        appendAttempt(report, experiment.id, "selected_but_disabled", {
            stage = "activation",
            ruleId = activation.group,
            field = "groupConfig",
            actual = nil,
            expected = { op = "defined" },
            reason = decision.reason,
        })
        return decision
    end

    local stages = experiment.conditionStages or {}
    local passed, rejection = evaluateConditions(
        context,
        stages.beforeAvailability
    )
    if not passed then
        decision.reason = rejection.reason
        appendAttempt(report, experiment.id, "rejected", rejection)
        return decision
    end

    if not decision.available then
        decision.reason = "control_group"
        appendAttempt(report, experiment.id, "selected_but_disabled", {
            stage = "group",
            ruleId = activation.group,
            field = "enableProphet",
            actual = false,
            expected = { op = "eq", value = true },
            reason = decision.reason,
        })
        return decision
    end

    decision.userTopLevel = context.userTopLevel
    passed, rejection = evaluateConditions(
        context,
        stages.afterAvailability
    )
    if not passed then
        decision.reason = rejection.reason
        appendAttempt(report, experiment.id, "rejected", rejection)
        return decision
    end

    if decision.requireToplevelBaoDi and not context.toplevelBaoDi then
        decision.reason = "toplevel_baodi_not_enabled"
        appendAttempt(report, experiment.id, "rejected", {
            stage = "condition",
            ruleId = "toplevel_baodi",
            field = "toplevelBaoDi",
            actual = context.toplevelBaoDi,
            expected = { op = "eq", value = true },
            reason = decision.reason,
        })
        return decision
    end

    decision.experienceContext = {
        levelId = context.levelId,
        levelScene = context.levelScene,
        difficultyFlag = context.difficultyFlag,
        difficultyClass = context.difficultyClass,
        superBirdActive = context.superBirdActive,
        toplevelBaoDi = context.toplevelBaoDi,
        userTopLevel = context.userTopLevel,
        fixedDesiredDiffAvg = context.fixedDesiredDiffAvg,
        desiredDiffAvg = context.desiredDiffAvg,
        diffIndex = context.diffIndex,
    }

    local route = selectRoute(
        decision.experienceContext,
        experiment.route,
        activation.groupConfig.routeMode
    )
    if not route then
        decision.experienceRouteReason = experiment.route.noMatchReason
        decision.reason = experiment.route.noMatchReason
        appendAttempt(report, experiment.id, "rejected", {
            stage = "route",
            ruleId = "no_route_matched",
            reason = decision.reason,
        })
        return decision
    end

    decision.experienceRouteReason = "experience_route_matched"
    decision.experienceType = route.experienceType
    decision.configKey = route.configKey
    report.selectedRoute = route.routeId

    if decision.removeDiffFix and not context.adjustDataPresent then
        decision.reason = "adjust_data_missing"
        appendAttempt(report, experiment.id, "selected_but_disabled", {
            stage = "pre_action",
            ruleId = "adjust_data_present",
            field = "adjustDataPresent",
            actual = false,
            expected = { op = "eq", value = true },
            reason = decision.reason,
        })
        return decision
    end

    if not isProphetConfigAvailable(decision.configKey) then
        decision.reason = "experience_config_missing"
        appendAttempt(report, experiment.id, "selected_but_disabled", {
            stage = "route",
            ruleId = route.routeId,
            field = "configKey",
            actual = decision.configKey,
            expected = { op = "registered_config" },
            reason = decision.reason,
        })
        return decision
    end

    decision.enabled = true
    decision.reason = "enabled"
    appendAttempt(report, experiment.id, "selected", {
        stage = "route",
        ruleId = route.routeId,
        reason = decision.reason,
    })
    return decision
end

function ProphetLaunchStrategy2:evaluateDetailed(runtime, resultDatas)
    local report = {
        selectedExperiment = nil,
        selectedRoute = nil,
        attempts = {},
    }
    if not CONFIG.enabled then
        report.disabled = true
        return nil, report
    end

    local context = buildContext(runtime, resultDatas)
    for _, experiment in ipairs(CONFIG.experiments) do
        local activation = activateExperiment(experiment, context)
        if not activation then
            appendAttempt(report, experiment.id, "not_activated", {
                stage = "activation",
                ruleId = experiment.activation.type,
                reason = "experiment_not_activated",
            })
        elseif experiment.id == "new_user" then
            local decision, shouldContinue =
                evaluateNewUser(experiment, context, activation, report)
            if decision or not shouldContinue then
                return decision, report
            end
        elseif experiment.id == "experience_matrix" then
            return evaluateExperienceMatrix(
                experiment,
                context,
                activation,
                report
            ), report
        end
    end
    return nil, report
end

function ProphetLaunchStrategy2:evaluate(runtime, resultDatas)
    local decision = self:evaluateDetailed(runtime, resultDatas)
    return decision
end

function ProphetLaunchStrategy2:getExperienceContext(
    runtime,
    checkResult,
    userTopLevel
)
    local context = buildContext(runtime, { checkResult = checkResult })
    return {
        levelId = context.levelId,
        levelScene = context.levelScene,
        difficultyFlag = context.difficultyFlag,
        difficultyClass = context.difficultyClass,
        superBirdActive = context.superBirdActive,
        toplevelBaoDi = context.toplevelBaoDi,
        userTopLevel = userTopLevel,
        fixedDesiredDiffAvg = context.fixedDesiredDiffAvg,
        desiredDiffAvg = context.desiredDiffAvg,
        diffIndex = context.diffIndex,
    }
end

function ProphetLaunchStrategy2:getConfig()
    return CONFIG
end

local ACTION_HANDLERS = {}

function ACTION_HANDLERS.record_decision(runtime, _, decision)
    runtime.prophetLaunchInfo = decision
    return true
end

function ACTION_HANDLERS.set_self_feedback(runtime, _, decision)
    local adjustLogic = runtime.UBFuuuAdjustLogic
    if not adjustLogic or not adjustLogic.setSelfFeedbackEnableFlag then
        decision.enabled = false
        decision.reason = "self_feedback_control_missing"
        return false
    end
    adjustLogic:setSelfFeedbackEnableFlag(
        decision.maintenanceName .. "_" .. decision.group,
        CONFIG.selfFeedbackEnabledWhenLaunched
    )
    return true
end

function ACTION_HANDLERS.capture_adjust_fix_info(runtime, resultDatas)
    local checkResult = resultDatas and resultDatas.checkResult
    local adjustLogic = runtime.UBFuuuAdjustLogic
    if checkResult and adjustLogic.getUbfuuuAdjustFixInfo then
        checkResult.adjustFixInfo = adjustLogic:getUbfuuuAdjustFixInfo()
    end
    return true
end

function ACTION_HANDLERS.set_prophet(runtime, _, decision)
    runtime:setProphet(decision.configKey)
    return true
end

function ACTION_HANDLERS.remove_diff_fix(runtime, _, decision)
    if decision.removeDiffFix and runtime.adjustData then
        runtime.adjustData.diffFix = nil
    end
    return true
end

function ProphetLaunchStrategy2:apply(runtime, resultDatas)
    local decision = self:evaluate(runtime, resultDatas)
    if not decision then
        return nil
    end

    for _, actionName in ipairs(CONFIG.actions) do
        if actionName ~= "record_decision" and not decision.enabled then
            break
        end
        local handler = ACTION_HANDLERS[actionName]
        if handler and handler(runtime, resultDatas, decision) == false then
            break
        end
    end
    return decision
end

function ProphetLaunchStrategy2:applySafely(runtime, resultDatas)
    local ok, result = pcall(self.apply, self, runtime, resultDatas)
    if ok then
        return result
    end

    if he_log_error then
        he_log_error("ProphetLaunchStrategy2_apply_error_" .. tostring(result))
    elseif printx then
        printx(0, "ProphetLaunchStrategy2:applySafely error", tostring(result))
    else
        print("ProphetLaunchStrategy2:applySafely error", tostring(result))
    end
    return nil
end

return ProphetLaunchStrategy2
