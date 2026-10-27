

RustProphet = {}

local function cloneComposableConfig(value, seen)
    if type(value) ~= "table" then return value end
    seen = seen or {}
    if seen[value] then return seen[value] end
    local result = {}
    seen[value] = result
    for key, item in pairs(value) do
        result[cloneComposableConfig(key, seen)] = cloneComposableConfig(item, seen)
    end
    return result
end

local function omitEmptySequence(parent, key)
    local value = parent and parent[key]
    if type(value) == "table" and next(value) == nil then
        parent[key] = nil
    end
end

local function normalizeDesignatedBoardAliases(normalized)
    local legacy = normalized.exciting_board_adjustment
    local current = normalized.designated_board_adjustment
    if legacy ~= nil and current ~= nil then
        error("behavior_config must not contain both exciting_board_adjustment and designated_board_adjustment")
    end
    if current == nil and legacy ~= nil then
        normalized.designated_board_adjustment = legacy
        normalized.exciting_board_adjustment = nil
    end
    local policy = normalized.conflict_policy
    for index, owner in ipairs((policy and policy.priority) or {}) do
        if owner == "ExcitingBoard" then
            policy.priority[index] = "DesignatedBoard"
        end
    end
end

local function fillDefaults(target, defaults)
    if type(target) ~= "table" or type(defaults) ~= "table" then return target end
    for key, value in pairs(defaults) do
        if target[key] == nil then
            target[key] = cloneComposableConfig(value)
        elseif type(target[key]) == "table" and type(value) == "table" then
            fillDefaults(target[key], value)
        end
    end
    return target
end


RustProphet.enum = {
    STEP_5 = "step-5",
    STEP_10 = "step-10",
    STEP_15 = "step-15",
    PRECISE_FOLLOW_LINE = "precise-follow-line",
    PRECISE_FOLLOW_LINE_EARLY_5 = "precise-follow-line-early-5",
    PRECISE_FOLLOW_LINE_FAIL_80 = "precise-follow-line-fail-80",
    COMPOSABLE_PROGRESS_V1 = "composable-progress-v1",
    COMPOSABLE_PROGRESS_V2 = "composable-progress-v2",
    EXPERIENCE_NEAR_PASS_TRACKING_ONLY = "experience-near-pass-tracking-only",
    EXPERIENCE_NEAR_PASS_GUARANTEED_TRACKING_ONLY = "experience-near-pass-guaranteed-tracking-only",
    EXPERIENCE_SMOOTH_PASS_TRACKING_ONLY = "experience-smooth-pass-tracking-only",
    EXPERIENCE_VERY_SMOOTH_PASS_TRACKING_ONLY = "experience-very-smooth-pass-tracking-only",
    EXPERIENCE_NEAR_PASS = "experience-near-pass",
    EXPERIENCE_NEAR_PASS_GUARANTEED = "experience-near-pass-guaranteed",
    EXPERIENCE_SMOOTH_PASS = "experience-smooth-pass",
    EXPERIENCE_VERY_SMOOTH_PASS = "experience-very-smooth-pass",
}

local function normalizedComposableConfig(behaviorConfig)
    assert(type(behaviorConfig) == "table", "behaviorConfig must be a table")
    local normalized = cloneComposableConfig(behaviorConfig)
    normalizeDesignatedBoardAliases(normalized)
    omitEmptySequence(normalized.tracking, "strength_rules")
    omitEmptySequence(normalized.fixed_adjustment, "rules")
    omitEmptySequence(normalized.exciting_operation_adjustment, "ranges")
    omitEmptySequence(normalized.designated_board_adjustment, "ranges")
    if normalized.fixed_adjustment then
        normalized.fixed_adjustment.on_budget_exhausted = nil
    end
    return normalized
end

function RustProphet.getDefaultExecutionConfig()
    return {
        schema_version = 1,
        executor = {
            worker_threads = 10,
        },
        throttle = {
            yield_after_work_ms = 0,
            yield_sleep_ms = 1,
            level_wall_time_budget_ms = 0,
        },
        falling = {
            max_candidates_per_search = 2000,
            target_inflight = 20,
            max_simulation_ticks = 0,
            max_phase_logic_frames = 10800,
        },
        waiting = {
            max_candidates_per_search = 2000,
            max_candidates_per_swap = 100,
            target_inflight = 10,
            max_inflight_per_swap = 1,
        },
    }
end

function RustProphet.getBusinessEffectiveExecutionConfig()
    local config = RustProphet.getDefaultExecutionConfig()
    config.falling.target_inflight = 2
    config.throttle.yield_after_work_ms = 2
    if EnvUtil and EnvUtil.isIOS and EnvUtil:isIOS() then
        config.waiting.max_candidates_per_swap = 50
    end
    if PlatformConfig and PlatformConfig.isPlatform
        and PlatformConfig:isPlatform(PlatformNameEnum.kHonor)
    then
        config.falling.target_inflight = 1
        config.throttle.yield_after_work_ms = 1
    end
    return config
end

function RustProphet.normalizeExecutionConfig(executionConfig)
    local normalized = type(executionConfig) == "table"
        and cloneComposableConfig(executionConfig)
        or RustProphet.getDefaultExecutionConfig()
    fillDefaults(normalized, RustProphet.getDefaultExecutionConfig())
    normalized.schema_version = 1
    return normalized
end

function RustProphet.normalizeBusinessEffectiveExecutionConfig(executionConfig)
    local normalized = type(executionConfig) == "table"
        and cloneComposableConfig(executionConfig)
        or RustProphet.getBusinessEffectiveExecutionConfig()
    fillDefaults(normalized, RustProphet.getBusinessEffectiveExecutionConfig())
    normalized.schema_version = 1
    return normalized
end

local function buildComposableProgressConfig(preset, behaviorConfig, executionConfig)
    local result = {
        evaluator_preset_name = "composable_progress_v1",
        behavior_config = normalizedComposableConfig(behaviorConfig),
    }
    result.evaluator_preset_name = preset
    if executionConfig ~= nil then
        result.execution_config = RustProphet.normalizeExecutionConfig(executionConfig)
    end
    return result
end

function RustProphet.makeComposableProgressV1Config(behaviorConfig, executionConfig)
    return buildComposableProgressConfig(
        "composable_progress_v1",
        behaviorConfig,
        executionConfig
    )
end

function RustProphet.makeComposableProgressV2Config(behaviorConfig, executionConfig)
    return buildComposableProgressConfig(
        "composable_progress_v2",
        behaviorConfig,
        executionConfig
    )
end

function RustProphet.makeComposableProgressConfig(behaviorConfig, executionConfig)
    if type(behaviorConfig) == "table" and behaviorConfig.schema_version == 2 then
        return RustProphet.makeComposableProgressV2Config(behaviorConfig, executionConfig)
    end
    return RustProphet.makeComposableProgressV1Config(behaviorConfig, executionConfig)
end

local function checkStrength(path, value)
    if type(value) ~= "number" or value < 0 or value > 10 or value % 1 ~= 0 then
        return false, path .. " must be an integer between 0 and 10"
    end
    return true
end

local function checkStepBudget(path, value)
    if type(value) ~= "table" or value.enabled ~= true then return true end
    local hasLimit = false
    for _, key in ipairs({ "max_positive_steps", "max_negative_steps", "max_absolute_steps" }) do
        local limit = value[key]
        if limit ~= nil then
            hasLimit = true
            if type(limit) ~= "number" or limit < 0 or limit > 10000 then
                return false, path .. "." .. key .. " must be between 0 and 10000"
            end
        end
    end
    if not hasLimit then return false, path .. " must define at least one limit when enabled" end
    return true
end

local function checkComboBudget(path, value)
    if type(value) ~= "table" or value.enabled ~= true then return true end
    local limit = value.max_combo_count
    if type(limit) ~= "number" or limit < 0 or limit > 100000 or limit % 1 ~= 0 then
        return false, path .. ".max_combo_count must be an integer between 0 and 100000"
    end
    return true
end

local function checkScopedBudget(path, value)
    value = value or {}
    local level = value.level or {}
    local operation = value.per_operation or {}
    for _, item in ipairs({
        { path .. ".level.step", level.step, checkStepBudget },
        { path .. ".level.combo", level.combo, checkComboBudget },
        { path .. ".per_operation.step", operation.step, checkStepBudget },
        { path .. ".per_operation.combo", operation.combo, checkComboBudget },
    }) do
        local ok, err = item[3](item[1], item[2])
        if not ok then return false, err end
    end
    return true
end

local function checkRange(path, range)
    if type(range) ~= "table" then return false, path .. " must be a table" end
    if range.type == "Single" then
        if type(range.move) ~= "number" or range.move % 1 ~= 0
            or range.move < 1 or range.move > 10000 then
            return false, path .. ".move must be an integer between 1 and 10000"
        end
    elseif range.type == "Interval" then
        if type(range.start) ~= "number" or type(range["end"]) ~= "number"
            or range.start % 1 ~= 0 or range["end"] % 1 ~= 0
            or range.start < 1 or range["end"] > 10000 or range.start > range["end"] then
            return false, path .. " must be a valid absolute interval"
        end
    elseif range.type == "RelativeInterval" then
        if type(range.start) ~= "number" or type(range["end"]) ~= "number"
            or range.start % 1 ~= 0 or range["end"] % 1 ~= 0
            or range.start < -10000 or range["end"] > 10000 or range.start > range["end"] then
            return false, path .. " must be a valid relative interval"
        end
    elseif range.type == "Periodic" then
        if type(range.start) ~= "number" or type(range.gap) ~= "number"
            or range.start % 1 ~= 0 or range.gap % 1 ~= 0
            or range.start < 1 or range.start > 10000 or range.gap < 0 or range.gap > 9999 then
            return false, path .. " must define start 1..10000 and gap 0..9999"
        end
    else
        return false, path .. ".type is unsupported"
    end
    return true
end

local function validateCommon(config)
    local tracking = config.tracking or {}
    if type(tracking.endpoint_shift_moves) ~= "number" or tracking.endpoint_shift_moves < -9999 or tracking.endpoint_shift_moves > 9999 then
        return false, "tracking.endpoint_shift_moves must be between -9999 and 9999"
    end
    for _, item in ipairs({
        { "tracking.default_positive_strength", tracking.default_positive_strength },
        { "tracking.default_negative_strength", tracking.default_negative_strength },
        { "prop_adjustment.strength", config.prop_adjustment and config.prop_adjustment.strength },
    }) do
        local ok, err = checkStrength(item[1], item[2])
        if not ok then return false, err end
    end
    for index, rule in ipairs(tracking.strength_rules or {}) do
        for _, key in ipairs({ "positive_strength", "negative_strength" }) do
            local ok, err = checkStrength("tracking.strength_rules[" .. index .. "]." .. key, rule[key])
            if not ok then return false, err end
        end
    end
    for index, rule in ipairs((config.fixed_adjustment and config.fixed_adjustment.rules) or {}) do
        local ok, err = checkStrength("fixed_adjustment.rules[" .. index .. "].strength", rule.strength)
        if not ok then return false, err end
    end
    for key, operation in pairs((config.exciting_operation_adjustment and config.exciting_operation_adjustment.operations) or {}) do
        local ok, err = checkStrength("exciting_operation_adjustment.operations." .. key .. ".strength", operation.strength)
        if not ok then return false, err end
    end
    local board = config.designated_board_adjustment
    if config.exciting_board_adjustment ~= nil and board ~= nil then
        return false, "behavior_config must not contain both exciting_board_adjustment and designated_board_adjustment"
    end
    if board == nil then board = config.exciting_board_adjustment end
    local minWeight = config.schema_version == 2 and -99 or 0
    for key, weight in pairs((board and board.weights) or {}) do
        if type(weight) ~= "number"
            or weight < minWeight or weight > 99 or weight % 1 ~= 0
        then
            return false, "designated_board_adjustment.weights." .. key
                .. " must be an integer between " .. minWeight .. " and 99"
        end
    end
    return true
end

function RustProphet.validateComposableBehaviorConfigV1(config)
    if type(config) ~= "table" then return false, "behavior_config must be a table" end
    if config.schema_version ~= 1 then return false, "schema_version must be 1" end
    local checks = {
        { "global_budget", config.global_budget },
        { "tracking.budget", config.tracking and config.tracking.budget },
        { "fixed_adjustment.budget", config.fixed_adjustment and config.fixed_adjustment.budget },
        { "prop_adjustment.budget", config.prop_adjustment and config.prop_adjustment.budget },
        { "exciting_operation_adjustment.budget", config.exciting_operation_adjustment and config.exciting_operation_adjustment.budget },
        { "designated_board_adjustment.budget", (config.designated_board_adjustment or config.exciting_board_adjustment)
            and (config.designated_board_adjustment or config.exciting_board_adjustment).budget },
    }
    for _, item in ipairs(checks) do
        local ok, err = checkStepBudget(item[1], item[2])
        if not ok then return false, err end
    end
    return validateCommon(config)
end

function RustProphet.validateComposableBehaviorConfigV2(config)
    if type(config) ~= "table" then return false, "behavior_config must be a table" end
    if config.schema_version ~= 2 then return false, "schema_version must be 2" end
    for _, item in ipairs({
        { "global_budget", config.global_budget },
        { "tracking.budget", config.tracking and config.tracking.budget },
        { "fixed_adjustment.budget", config.fixed_adjustment and config.fixed_adjustment.budget },
        { "prop_adjustment.budget", config.prop_adjustment and config.prop_adjustment.budget },
        { "exciting_operation_adjustment.budget", config.exciting_operation_adjustment and config.exciting_operation_adjustment.budget },
        { "designated_board_adjustment.budget", (config.designated_board_adjustment or config.exciting_board_adjustment)
            and (config.designated_board_adjustment or config.exciting_board_adjustment).budget },
    }) do
        local ok, err = checkScopedBudget(item[1], item[2])
        if not ok then return false, err end
    end
    local exciting = config.exciting_operation_adjustment or {}
    for index, range in ipairs(exciting.ranges or {}) do
        local ok, err = checkRange("exciting_operation_adjustment.ranges[" .. index .. "]", range)
        if not ok then return false, err end
    end
    for key, operation in pairs(exciting.operations or {}) do
        for _, field in ipairs({
            { "per_operation_step_budget", 10000 },
            { "per_operation_combo_budget", 100000 },
            { "max_trigger_count", 1000 },
        }) do
            local value = operation[field[1]]
            if value ~= nil and (type(value) ~= "number" or value < 0
                or value > field[2] or value % 1 ~= 0) then
                return false, "exciting_operation_adjustment.operations." .. key .. "."
                    .. field[1] .. " must be an integer between 0 and " .. field[2]
            end
        end
    end
    return validateCommon(config)
end

function RustProphet.validateComposableBehaviorConfig(config)
    if type(config) == "table" and config.schema_version == 2 then
        return RustProphet.validateComposableBehaviorConfigV2(config)
    end
    return RustProphet.validateComposableBehaviorConfigV1(config)
end

local function checkInteger(path, value, minValue, maxValue)
    if type(value) ~= "number" or value % 1 ~= 0
        or value < minValue or value > maxValue then
        return false, path .. " must be an integer between "
            .. tostring(minValue) .. " and " .. tostring(maxValue)
    end
    return true
end

function RustProphet.validateExecutionConfig(config)
    if type(config) ~= "table" then return false, "execution_config must be a table" end
    if config.schema_version ~= 1 then return false, "execution_config.schema_version must be 1" end
    local normalized = RustProphet.normalizeExecutionConfig(config)
    for _, item in ipairs({
        { "executor.worker_threads", normalized.executor.worker_threads, 1, 64 },
        { "throttle.yield_after_work_ms", normalized.throttle.yield_after_work_ms, 0, 3600000 },
        { "throttle.yield_sleep_ms", normalized.throttle.yield_sleep_ms, 0, 3600000 },
        { "throttle.level_wall_time_budget_ms", normalized.throttle.level_wall_time_budget_ms, 0, 3600000 },
        { "falling.max_candidates_per_search", normalized.falling.max_candidates_per_search, 0, 100000 },
        { "falling.target_inflight", normalized.falling.target_inflight, 1, 1024 },
        { "falling.max_simulation_ticks", normalized.falling.max_simulation_ticks, 0, 4294967295 },
        { "falling.max_phase_logic_frames", normalized.falling.max_phase_logic_frames, 0, 4294967295 },
        { "waiting.max_candidates_per_search", normalized.waiting.max_candidates_per_search, 0, 100000 },
        { "waiting.max_candidates_per_swap", normalized.waiting.max_candidates_per_swap, 0, 100000 },
        { "waiting.target_inflight", normalized.waiting.target_inflight, 1, 1024 },
        { "waiting.max_inflight_per_swap", normalized.waiting.max_inflight_per_swap, 1, 1024 },
    }) do
        local ok, err = checkInteger(item[1], item[2], item[3], item[4])
        if not ok then return false, err end
    end
    return true
end

function RustProphet.makePreciseFollowLineConfig(lineTarget, lineTracking)
    local config = {
        evaluator_preset_name = "precise_follow_line",
        line_target = lineTarget or {
            type = "Original",
        },
    }
    -- 交换动作始终由玩家或 AI 决定；先知只消费实际交换对应的预测并控制后续扰动。
    if lineTracking then
        config.line_tracking = lineTracking
    end
    return config
end

function RustProphet.makePreciseFollowLineEarlyConfig(earlyMoveCount)
    local count = math.max(0, tonumber(earlyMoveCount) or 0)
    return RustProphet.makePreciseFollowLineConfig({
        type = "FinishMoveOffset",
        offset_moves = -count,
    })
end

function RustProphet.makePreciseFollowLineFailConfig(progress)
    local targetProgress = tonumber(progress) or 1
    if targetProgress <= 0 then
        targetProgress = 1
    end
    return RustProphet.makePreciseFollowLineConfig({
        type = "ProgressAtLineEnd",
        progress = targetProgress,
    })
end

local function disabledStepBudget()
    return {
        enabled = false,
        overflow_policy = "RejectCandidate",
    }
end

local function disabledComboBudget()
    return {
        enabled = false,
        overflow_policy = "RejectCandidate",
    }
end

local function scopedExperienceBudget()
    return {
        level = {
            step = disabledStepBudget(),
            combo = disabledComboBudget(),
        },
        per_operation = {
            step = disabledStepBudget(),
            combo = disabledComboBudget(),
        },
    }
end

local function experienceStepBudget(maxPositiveSteps, maxNegativeSteps, maxAbsoluteSteps)
    return {
        enabled = true,
        max_positive_steps = maxPositiveSteps,
        max_negative_steps = maxNegativeSteps,
        max_absolute_steps = maxAbsoluteSteps,
        overflow_policy = "RejectCandidate",
    }
end

local function experienceBaseBehaviorConfig()
    return {
        schema_version = 2,
        global_budget = scopedExperienceBudget(),
        tracking = {
            enabled = false,
            endpoint_shift_moves = 0,
            fit_algorithm = "Linear",
            require_source_line = true,
            require_all_targets = false,
            default_positive_strength = 10,
            default_negative_strength = 5,
            strength_rules = {},
            budget = scopedExperienceBudget(),
        },
        fixed_adjustment = {
            enabled = false,
            rules = {},
            budget = scopedExperienceBudget(),
        },
        prop_adjustment = {
            enabled = false,
            direction = "Positive",
            strength = 0,
            max_trigger_count = 0,
            budget = scopedExperienceBudget(),
            trigger_scope = "CurrentOperationOnly",
        },
        exciting_operation_adjustment = {
            enabled = false,
            max_trigger_count = 0,
            operations = {
                special_create = { enabled = false, direction = "Positive", strength = 0 },
                swap_trigger_special = { enabled = false, direction = "Positive", strength = 0 },
                double_special_swap = { enabled = false, direction = "Positive", strength = 0 },
                magic_bird_create = { enabled = false, direction = "Positive", strength = 0 },
                magic_bird_animal_swap = { enabled = false, direction = "Positive", strength = 0 },
                magic_bird_special_swap = { enabled = false, direction = "Positive", strength = 0 },
                magic_bird_magic_bird_swap = { enabled = false, direction = "Positive", strength = 0 },
                full_star_jar_animal_swap = { enabled = false, direction = "Positive", strength = 0 },
                full_star_jar_full_star_jar_swap = {
                    enabled = false,
                    direction = "Positive",
                    strength = 0,
                },
            },
            budget = scopedExperienceBudget(),
            ranges = {},
        },
        designated_board_adjustment = {
            enabled = false,
            ranges = {},
            weights = {
                magic_bird_count = 0,
                special_count = 0,
                adjacent_double_magic_bird = 0,
                adjacent_magic_bird_special = 0,
                one_move_special = 0,
                one_move_magic_bird = 0,
                one_move_double_special = 0,
                one_move_magic_bird_special = 0,
            },
            budget = scopedExperienceBudget(),
        },
        conflict_policy = {
            mode = "HighestPrioritySingleOwner",
            priority = { "Fixed", "Prop", "ExcitingOperation", "DesignatedBoard", "Tracking" },
        },
    }
end

local function enableExperienceTracking(config, endpointShiftMoves, maxPositiveSteps, maxNegativeSteps)
    config.tracking.enabled = true
    config.tracking.endpoint_shift_moves = endpointShiftMoves
    config.tracking.budget.level.step = experienceStepBudget(
        maxPositiveSteps,
        maxNegativeSteps,
        40
    )
end

local function addFixedExperienceRule(config, id, start, finish, maxPositiveSteps)
    config.fixed_adjustment.enabled = true
    config.fixed_adjustment.rules = {
        {
            id = id,
            ranges = {
                {
                    type = "RelativeInterval",
                    start = start,
                    ["end"] = finish,
                },
            },
            direction = "Positive",
            strength = 10,
        },
    }
    config.fixed_adjustment.budget.level.step = experienceStepBudget(
        maxPositiveSteps,
        nil,
        nil
    )
end

local function addExcitingOperation(config, operationName, strength, stepBudget)
    local operation = config.exciting_operation_adjustment.operations[operationName]
    operation.enabled = true
    operation.direction = "Positive"
    operation.strength = strength
    operation.per_operation_step_budget = stepBudget
    operation.per_operation_combo_budget = 20
end

local function enableExcitingOperations(config, operationSpecs)
    config.exciting_operation_adjustment.enabled = true
    config.exciting_operation_adjustment.max_trigger_count = 20
    for _, spec in ipairs(operationSpecs) do
        addExcitingOperation(config, spec[1], spec[2], spec[3])
    end
end

local function enableExcitingBoard(config, rangeType, rangeStart, rangeEnd)
    config.designated_board_adjustment.enabled = true
    config.designated_board_adjustment.ranges = {
        {
            type = rangeType,
            start = rangeStart,
            ["end"] = rangeEnd,
        },
    }
    config.designated_board_adjustment.weights.one_move_magic_bird = 1
    config.designated_board_adjustment.weights.one_move_magic_bird_special = 1
end

local function makeExperienceBehaviorConfig(
    endpointShiftMoves,
    trackingPositiveSteps,
    trackingNegativeSteps,
    fixedRange,
    excitingOperationSpecs,
    excitingBoardRange
)
    local config = experienceBaseBehaviorConfig()
    enableExperienceTracking(
        config,
        endpointShiftMoves,
        trackingPositiveSteps,
        trackingNegativeSteps
    )
    if fixedRange then
        addFixedExperienceRule(
            config,
            fixedRange[1],
            fixedRange[2],
            fixedRange[3],
            fixedRange[4]
        )
    end
    if excitingOperationSpecs then
        enableExcitingOperations(config, excitingOperationSpecs)
    end
    if excitingBoardRange then
        enableExcitingBoard(
            config,
            excitingBoardRange[1],
            excitingBoardRange[2],
            excitingBoardRange[3]
        )
    end
    return config
end

local function makeExperiencePreset(behaviorConfig)
    return buildComposableProgressConfig(
        "composable_progress_v2",
        behaviorConfig
    )
end

local function makeTrackingOnlyExperiencePreset(
    endpointShiftMoves,
    trackingPositiveSteps,
    trackingNegativeSteps
)
    return makeExperiencePreset(makeExperienceBehaviorConfig(
        endpointShiftMoves,
        trackingPositiveSteps,
        trackingNegativeSteps
    ))
end

local function makeFullExperiencePreset(
    endpointShiftMoves,
    trackingPositiveSteps,
    trackingNegativeSteps,
    fixedRange,
    excitingOperationSpecs,
    excitingBoardRange
)
    return makeExperiencePreset(makeExperienceBehaviorConfig(
        endpointShiftMoves,
        trackingPositiveSteps,
        trackingNegativeSteps,
        fixedRange,
        excitingOperationSpecs,
        excitingBoardRange
    ))
end

local NEAR_PASS_EXCITING_OPERATIONS = {
    { "magic_bird_special_swap", 10, 5 },
    { "magic_bird_magic_bird_swap", 10, 5 },
}

local SMOOTH_PASS_EXCITING_OPERATIONS = {
    { "swap_trigger_special", 10, 3 },
    { "double_special_swap", 10, 3 },
    { "magic_bird_animal_swap", 10, 3 },
    { "magic_bird_special_swap", 10, 5 },
    { "magic_bird_magic_bird_swap", 10, 5 },
}

local VERY_SMOOTH_PASS_EXCITING_OPERATIONS = {
    { "swap_trigger_special", 10, 3 },
    { "double_special_swap", 10, 3 },
    { "magic_bird_animal_swap", 10, 3 },
    { "magic_bird_special_swap", 10, 5 },
    { "magic_bird_magic_bird_swap", 10, 5 },
}

local function relativeBoardRange(start, finish)
    return { "RelativeInterval", start, finish }
end

local function absoluteBoardRange(start, finish)
    return { "Interval", start, finish }
end

-- 10step = _12
RustProphet.config = {
    [RustProphet.enum.STEP_5] = {
        evaluator_preset_name = "easy_full_target_with_step_16",
        max_falling_foresee_frame_diff = 1800,
        -- yield_ms = 2,
        -- foresee_count_once_batch = 4,
    },
    [RustProphet.enum.STEP_10] = {
        evaluator_preset_name = "easy_full_target_with_step_12",
        max_falling_foresee_frame_diff = 1800,
        -- yield_ms = 2,
        -- foresee_count_once_batch = 4,
    },
    [RustProphet.enum.STEP_15] = {
        evaluator_preset_name = "easy_full_target_with_step_14",
        max_falling_foresee_frame_diff = 1800,
        -- yield_ms = 2,
        -- foresee_count_once_batch = 4,
    },
    [RustProphet.enum.PRECISE_FOLLOW_LINE] = RustProphet.makePreciseFollowLineConfig(),
    [RustProphet.enum.PRECISE_FOLLOW_LINE_EARLY_5] =
        RustProphet.makePreciseFollowLineEarlyConfig(5),
    [RustProphet.enum.PRECISE_FOLLOW_LINE_FAIL_80] =
        RustProphet.makePreciseFollowLineFailConfig(0.8),
    [RustProphet.enum.EXPERIENCE_NEAR_PASS_TRACKING_ONLY] =
        makeTrackingOnlyExperiencePreset(-8, 3, 2),
    [RustProphet.enum.EXPERIENCE_NEAR_PASS_GUARANTEED_TRACKING_ONLY] =
        makeTrackingOnlyExperiencePreset(-8, 3, 2),
    [RustProphet.enum.EXPERIENCE_SMOOTH_PASS_TRACKING_ONLY] =
        makeTrackingOnlyExperiencePreset(-10, 3, 2),
    [RustProphet.enum.EXPERIENCE_VERY_SMOOTH_PASS_TRACKING_ONLY] =
        makeTrackingOnlyExperiencePreset(-15, 3, 2),
    [RustProphet.enum.EXPERIENCE_NEAR_PASS] = makeFullExperiencePreset(
        -8,
        3,
        2,
        nil,
        NEAR_PASS_EXCITING_OPERATIONS,
        relativeBoardRange(-5, -4)
    ),
    [RustProphet.enum.EXPERIENCE_NEAR_PASS_GUARANTEED] = makeFullExperiencePreset(
        -8,
        3,
        2,
        { "near_pass_guaranteed", -3, 0, 5 },
        NEAR_PASS_EXCITING_OPERATIONS,
        relativeBoardRange(-6, -4)
    ),
    [RustProphet.enum.EXPERIENCE_SMOOTH_PASS] = makeFullExperiencePreset(
        -10,
        3,
        2,
        { "smooth_pass", -5, 0, 5 },
        SMOOTH_PASS_EXCITING_OPERATIONS,
        absoluteBoardRange(10, 13)
    ),
    [RustProphet.enum.EXPERIENCE_VERY_SMOOTH_PASS] = makeFullExperiencePreset(
        -15,
        3,
        2,
        { "very_smooth_pass", -5, 0, 5 },
        VERY_SMOOTH_PASS_EXCITING_OPERATIONS,
        absoluteBoardRange(5, 8)
    ),
}
