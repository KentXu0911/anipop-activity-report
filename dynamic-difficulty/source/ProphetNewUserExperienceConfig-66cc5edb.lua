local prophet = rawget(_G, "RustProphet")
if not prophet then
    require "ubf.UBFPlay.rust.RustProphet"
    prophet = rawget(_G, "RustProphet")
end

local function stepBudget(maxPositiveSteps, maxNegativeSteps, maxAbsoluteSteps)
    return {
        enabled = true,
        max_positive_steps = maxPositiveSteps,
        max_negative_steps = maxNegativeSteps,
        max_absolute_steps = maxAbsoluteSteps,
        overflow_policy = "RejectCandidate",
    }
end

local function buildConfig(behaviorConfig)
    -- 只保留线上业务需要的两项，性能参数由 Rust 默认配置统一管理。
    if prophet and prophet.makeComposableProgressV2Config then
        return prophet.makeComposableProgressV2Config(behaviorConfig)
    end
    return {
        evaluator_preset_name = "composable_progress_v2",
        behavior_config = behaviorConfig,
    }
end

local function buildBehaviorConfig(tracking, operationPositiveSteps, board)
    return {
        schema_version = 2,
        tracking = {
            enabled = true,
            endpoint_shift_moves = tracking.endpoint_shift_moves,
            fit_algorithm = "Linear",
            require_source_line = true,
            require_all_targets = false,
            default_positive_strength = 10,
            default_negative_strength = tracking.default_negative_strength,
        },
        fixed_adjustment = {
            enabled = true,
            rules = {
                {
                    id = "relative_config_steps",
                    ranges = {
                        {
                            type = "RelativeInterval",
                            start = -5,
                            ["end"] = 0,
                        },
                    },
                    direction = "Positive",
                    strength = 10,
                },
            },
            budget = {
                level = {
                    step = stepBudget(5, 0, 20),
                },
            },
        },
        prop_adjustment = {
            enabled = false,
            direction = "Positive",
            strength = 0,
            max_trigger_count = 0,
            trigger_scope = "CurrentOperationOnly",
        },
        exciting_operation_adjustment = {
            enabled = true,
            max_trigger_count = 10,
            operations = {
                swap_trigger_special = {
                    enabled = true,
                    direction = "Positive",
                    strength = 10,
                    per_operation_step_budget = 3,
                    per_operation_combo_budget = 7,
                },
                double_special_swap = {
                    enabled = true,
                    direction = "Positive",
                    strength = 10,
                    per_operation_step_budget = 3,
                    per_operation_combo_budget = 7,
                },
                magic_bird_animal_swap = {
                    enabled = true,
                    direction = "Positive",
                    strength = 10,
                    per_operation_step_budget = 3,
                    per_operation_combo_budget = 7,
                },
                magic_bird_special_swap = {
                    enabled = true,
                    direction = "Positive",
                    strength = 10,
                    per_operation_step_budget = 5,
                    per_operation_combo_budget = 7,
                },
                magic_bird_magic_bird_swap = {
                    enabled = true,
                    direction = "Positive",
                    strength = 10,
                    per_operation_step_budget = 5,
                    per_operation_combo_budget = 7,
                },
            },
            budget = {
                per_operation = {
                    step = stepBudget(operationPositiveSteps, 1, 40),
                },
            },
        },
        exciting_board_adjustment = board,
    }
end

local ordinaryBoard = {
    enabled = true,
    ranges = {
        {
            type = "RelativeInterval",
            start = -5,
            ["end"] = -4,
        },
    },
    weights = {
        magic_bird_count = 1,
        special_count = 1,
        adjacent_double_magic_bird = 1,
        adjacent_magic_bird_special = 1,
        one_move_special = 1,
        one_move_magic_bird = 3,
        one_move_double_special = 1,
        one_move_magic_bird_special = 3,
    },
}

local smoothBoard = {
    enabled = true,
    ranges = {
        {
            type = "Interval",
            start = 5,
            ["end"] = 8,
        },
    },
    weights = {
        magic_bird_count = 3,
        special_count = 3,
        adjacent_double_magic_bird = 3,
        adjacent_magic_bird_special = 3,
        one_move_special = 3,
        one_move_magic_bird = 5,
        one_move_double_special = 5,
        one_move_magic_bird_special = 8,
    },
    budget = {
        per_operation = {
            step = stepBudget(4, 1, 40),
        },
    },
}

return {
    ordinary = buildConfig(buildBehaviorConfig(
        {
            endpoint_shift_moves = -4,
            default_negative_strength = 4,
        },
        1,
        ordinaryBoard
    )),
    smooth = buildConfig(buildBehaviorConfig(
        {
            endpoint_shift_moves = -12,
            default_negative_strength = 3,
        },
        4,
        smoothBoard
    )),
}
