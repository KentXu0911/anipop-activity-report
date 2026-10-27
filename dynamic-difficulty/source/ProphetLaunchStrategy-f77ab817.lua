local ProphetLaunchStrategy = {}

if not RustProphet then
    require "ubf.UBFPlay.rust.RustProphet"
end

local NEW_USER_PROPHET_CONFIGS =
    require "ubf.UBFPlay.rust.ProphetNewUserExperienceConfig"

local NEW_USER_PROPHET_CONFIG_KEYS = {
    ordinary = "newuser_prophet_ordinary",
    smooth = "newuser_prophet_smooth",
}

for configType, configKey in pairs(NEW_USER_PROPHET_CONFIG_KEYS) do
    local config = NEW_USER_PROPHET_CONFIGS[configType]
    if config then
        RustProphet.config[configKey] = config
    end
end

-------------------- 可统一修改的实验配置 --------------------
--
-- 本段（到「实验策略实现」分隔线为止）是先知启动策略的唯一配置入口。产品需求落定后
-- 只允许改本段的这些表：PLATFORM_ACCESS_CONFIG（门禁清单）、USER_LEVEL_CONFIG、
-- DIFFICULTY_CONFIG、BLOCKED_LEVEL_IDS、EXPERIENCE_ROUTING_CONFIG、
-- EXPERIENCE_GROUP_CONFIG、PLATFORM_EXPERIMENT_CONFIG。不要改下面的策略实现。
--
-- 本次测试已明确的两件事：只给安卓、且必须满足 Rust 动更库就绪
-- （UBFRustManager.isRustDyGoReady）。两件事都已经表达成配置项，不再硬编码在判定里。

-- 唯一总开关：改为 false 后不写入任何 Prophet 相关运行时数据，也不修改 diffFix。
local PROPHET_EXPERIMENT_ENABLED = true
local NEW_USER_PROPHET_SWITCH_NAME = "newuser_prophet"
local NEW_USER_PROPHET_SWITCH_GROUP = "ON"
local NEW_USER_MAX_TOP_LEVEL = 200
local NEW_USER_MIN_LEVEL_ID = 1
local NEW_USER_MAX_LEVEL_ID = 200

-- 门禁清单。执行顺序就是数组顺序，命中即返回该条的 reason（不影响是否启动）。
-- 每条门禁支持 enabled（整体开关）和 when（附加前置条件，支持 cond="all"/"any"，
-- 默认 all），便于后续把某条限制收窄到指定平台或指定实验组，而不用改实现。
-- rules 里的 field 是门禁可识别的标量字段：isMiniGame / platform / channel /
-- bundleVersion，以及 runtime 上的同名方法（如 getUserTopLevel）。
local PLATFORM_ACCESS_CONFIG = {
    enabled = true,
    gates = {
        {
            id = "native_platform",
            reason = "platform_not_allowed",
            rules = {
                {
                    field = "isMiniGame",
                    mode = "exclude",
                    anyOf = { true },
                },
                {
                    field = "platform",
                    mode = "allow",
                    anyOf = {
                        "android",
                    },
                },
                {
                    -- HE 是安卓渠道，本次新手期实验先排除；旧体验矩阵仍按自己的旧逻辑运行。
                    field = "channel",
                    mode = "block",
                    blocklist = { "he" },
                },
            },
        },
        {
            id = "bundle_version",
            reason = "rust_lib_not_allowed",
            rules = {
                {
                    -- 最低包版本（含）。旧实现等价于 ver > 159，即 bundle 1.160 及以上。
                    -- 注意：版本门槛必须写成字符串，数字字面量 1.160 会被 tostring 成 "1.16"。
                    field = "bundleVersion",
                    mode = "min",
                    min = "1.160",
                    minStrict = false,
                },
            },
        },
        {
            id = "rust_environment",
            reason = "rust_lib_not_allowed",
            rules = {
                {
                    -- 动更库就绪判定，语义由 requireRustDyGoReadyBelow 控制：
                    --   bundleVersion <= requireRustDyGoReadyBelow -> 必须有 UBFRustManager.isRustDyGoReady；
                    --   bundleVersion >  requireRustDyGoReadyBelow -> 认为直接生效（Rust 会在下一个
                    --   版本随包带上该能力，不再依赖动更）。
                    -- 当前为 nil：所有版本都必须动更就绪，即线上强校验不变。
                    -- 产品确认「随包带上能力」的起始版本后，把这里改成那个版本号（如 "1.160"）即可。
                    field = "isRustDyGoReady",
                    mode = "equals",
                    expected = true,
                    requireRustDyGoReadyBelow = nil,
                },
            },
        },
    },
}

-- 进关档位限制。产品给出准确口径后，把 current 换成下面任意一行即可，不需要改实现：
--   只开放 200 关及以上（线上现状）：{ min = 200, minInclusive = true }
--   只开放 200 关以下：            { max = 200, maxInclusive = false }
--   只开放 1~199 关（显式双端）：   { min = 1, minInclusive = true, max = 200, maxInclusive = false }
--   不限档位：                      { enabled = false }
local USER_LEVEL_PRESETS = {
    atLeast200 = { min = 200, minInclusive = true },
    below200 = { max = 200, maxInclusive = false },
    range1to199 = {
        min = 1,
        minInclusive = true,
        max = 200,
        maxInclusive = false,
    },
    anyLevel = { enabled = false },
    -- current 是当前实际生效的档位口径。改这一行即可切换，上面几个是现成方案。
    current = { min = 200, minInclusive = true },
}

local USER_LEVEL_CONFIG = {
    enabled = true,
    field = "getUserTopLevel",
    -- 取不到有效数值时的处理：true 视为未命中；false 视为不受本条限制。
    missingAsReject = true,
    min = USER_LEVEL_PRESETS.current.min,
    minInclusive = USER_LEVEL_PRESETS.current.minInclusive ~= false,
    max = USER_LEVEL_PRESETS.current.max,
    maxInclusive = USER_LEVEL_PRESETS.current.maxInclusive ~= false,
}

-- 难度限制。1.03 是本次测试的基础条件。
local DIFFICULTY_CONFIG = {
    enabled = true,
    max = 1.03,
    floatEpsilon = 0.0001,
}

-- 临时关卡黑名单（按关卡 id 屏蔽）。后续开关附加信息格式落定后，在这里替换数据来源。
local BLOCKED_LEVEL_IDS = {
    [39] = true, [44] = true, [49] = true, [54] = true,
    [59] = true, [64] = true, [69] = true, [74] = true, [79] = true, [84] = true,
    [89] = true, [94] = true, [99] = true, [104] = true, [109] = true, [114] = true,
    [119] = true, [124] = true, [129] = true, [134] = true, [139] = true, [144] = true, [149] = true,
    [154] = true, [159] = true, [164] = true, [169] = true, [174] = true, [179] = true, [184] = true,
    [189] = true, [194] = true, [199] = true,
}

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

-- 自反馈在 Prophet 启动后是否保持开启。当前产品结论为关闭，避免与先知叠加干预。
local SELF_FEEDBACK_ENABLED_WHEN_PROPHET_LAUNCHED = false

local EXPERIENCE_GROUP_CONFIG

-- 体验路由命中后才允许启动 Prophet；未命中分类直接退出，不回退旧实验。
-- routes 按顺序匹配，越具体的条件越靠前。
local EXPERIENCE_ROUTING_CONFIG = {
    enabled = true,
    routes = {
        {
            id = "hard_no_super_bird",
            conditions = {
                difficultyClass = "hard",
                superBirdActive = false,
            },
            trackingOnlyConfigKey =
                RustProphet.enum.EXPERIENCE_NEAR_PASS_TRACKING_ONLY,
            fullConfigKey = RustProphet.enum.EXPERIENCE_NEAR_PASS,
        },
        {
            id = "hard_with_super_bird",
            conditions = {
                difficultyClass = "hard",
                superBirdActive = true,
            },
            trackingOnlyConfigKey =
                RustProphet.enum.EXPERIENCE_NEAR_PASS_TRACKING_ONLY,
            fullConfigKey = RustProphet.enum.EXPERIENCE_NEAR_PASS,
        },
        {
            id = "normal_no_super_bird_baodi",
            conditions = {
                difficultyClass = "normal",
                superBirdActive = false,
                toplevelBaoDi = true,
            },
            trackingOnlyConfigKey =
                RustProphet.enum.EXPERIENCE_NEAR_PASS_GUARANTEED_TRACKING_ONLY,
            fullConfigKey = RustProphet.enum.EXPERIENCE_NEAR_PASS_GUARANTEED,
        },
        {
            id = "normal_no_super_bird",
            conditions = {
                difficultyClass = "normal",
                superBirdActive = false,
                toplevelBaoDi = false,
            },
            trackingOnlyConfigKey =
                RustProphet.enum.EXPERIENCE_SMOOTH_PASS_TRACKING_ONLY,
            fullConfigKey = RustProphet.enum.EXPERIENCE_SMOOTH_PASS,
        },
        {
            id = "normal_with_super_bird",
            conditions = {
                difficultyClass = "normal",
                superBirdActive = true,
            },
            trackingOnlyConfigKey =
                RustProphet.enum.EXPERIENCE_VERY_SMOOTH_PASS_TRACKING_ONLY,
            fullConfigKey = RustProphet.enum.EXPERIENCE_VERY_SMOOTH_PASS,
        },
    },
}

local EXPERIENCE_GROUP_ORDER = {
    "OFF",
    "ON1",
    "ON2",
    -- ON3 尚无对应的正式预设，命中时保持不启动。
    "ON3",
}

local function makePlatformExperimentConfig(maintenanceName)
    return {
        launchSwitches = {
            {
                id = "experience_matrix_v1",
                enabled = true,
                groupConfigType = "experience",
                maintenanceName = maintenanceName,
                groupOrder = EXPERIENCE_GROUP_ORDER,
            },
        },
    }
end

-- HE 渠道的判定描述，平台条目使用；channel 门禁的取值也走同一份描述。
local HE_CHANNEL_DETECT = {
    kind = "envMethodWithArg",
    method = "isAndroidPlatform",
    argEnumKey = "kHE",
}

-- 平台/渠道 → 维护开关映射。规则：
--   detect 始终生效，是平台与渠道判定的唯一来源；
--   accessId 是门禁 allow 规则里的平台标识，同平台的不同渠道共享（HE 与普通安卓同为 android）；
--   experimentEnabled = false 表示该平台不参与本次实验（解析时跳过，不读维护项、不写决策）。
-- 解析顺序就是数组顺序：越具体的渠道越靠前。
local PLATFORM_EXPERIMENT_CONFIG = {
    entries = {
        {
            id = "ohos",
            accessId = "ohos",
            -- 旧体验矩阵原本支持该平台；新手期实验由独立门禁限制为 Android。
            experimentEnabled = true,
            detect = { kind = "envMethod", method = "isOhos" },
            experimentConfig = makePlatformExperimentConfig("prophet_test_oh"),
        },
        {
            id = "ios",
            accessId = "ios",
            -- 旧体验矩阵原本支持该平台；新手期实验由独立门禁限制为 Android。
            experimentEnabled = true,
            detect = { kind = "envMethod", method = "isIOS" },
            experimentConfig = makePlatformExperimentConfig("prophet_test_ios"),
        },
        {
            -- HE 与普通安卓同属 android 平台，只通过 channel 门禁区分。
            id = "android_he",
            accessId = "android",
            experimentEnabled = true,
            -- kHE 从全局 PlatformNameEnum 取，与旧实现的 EnvUtil:isAndroidPlatform 口径一致。
            detect = HE_CHANNEL_DETECT,
            experimentConfig = makePlatformExperimentConfig("prophet_test_he"),
        },
        {
            id = "android",
            accessId = "android",
            experimentEnabled = true,
            detect = { kind = "envMethod", method = "isAndroid" },
            experimentConfig = makePlatformExperimentConfig(
                "prophet_test_android_nohe"
            ),
        },
    },
}

-- 体验矩阵开关专用配置。ON1 仅追线，ON2 使用完整策略。
EXPERIENCE_GROUP_CONFIG = {
    OFF = {
        enableProphet = false,
        requireToplevelBaoDi = false,
    },
    ON1 = {
        enableProphet = true,
        requireToplevelBaoDi = false,
        experienceMode = "tracking_only",
        experienceRouting = EXPERIENCE_ROUTING_CONFIG,
    },
    ON2 = {
        enableProphet = true,
        requireToplevelBaoDi = false,
        experienceMode = "full",
        experienceRouting = EXPERIENCE_ROUTING_CONFIG,
    },
}

local unpackValues = _G.unpack or table.unpack

-- 通用数值比较符，供 mode = "value" 使用（版本号门槛请改用 min/max）。
local VALUE_COMPARATORS = {
    eq = function(actual, expected)
        return actual == expected
    end,
    lt = function(actual, expected)
        return actual < expected
    end,
    lte = function(actual, expected)
        return actual <= expected
    end,
    gt = function(actual, expected)
        return actual > expected
    end,
    gte = function(actual, expected)
        return actual >= expected
    end,
}


local function safeCall(target, methodName, ...)
    local method = type(target) == "table" and target[methodName] or nil
    if type(method) ~= "function" then
        return false, nil
    end

    local args = { ... }
    local ok, result = pcall(function()
        return method(target, unpackValues(args))
    end)
    if not ok then
        return false, nil
    end
    return true, result
end

-- 版本号按整数段逐段比较，避免字符串比较把 "1.100" 判成小于 "1.99"。
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

local function getRustDyGoReady()
    return UBFRustManager ~= nil
        and UBFRustManager.isRustDyGoReady == true
end

-- 动更就绪是否仍需要检查：低于/等于门槛必须检查；高于门槛认为直接生效（Rust 随包带该能力）。
-- 门槛为 nil 或空串时等于「所有版本都必须动更就绪」。
local function shouldCheckRustDyGoReady(belowVersion)
    if type(belowVersion) ~= "string" or belowVersion == "" then
        return true
    end
    return compareVersion(_G.bundleVersion, belowVersion) <= 0
end

local function getDetectArg(detect)
    if detect.kind ~= "envMethodWithArg" then
        return nil
    end
    -- 与旧实现一致：kHE 等枚举直接从全局 PlatformNameEnum 取。
    local enumTable = PlatformNameEnum
    return enumTable and enumTable[detect.argEnumKey] or nil
end

local function detectPlatform(entry)
    if not EnvUtil or type(entry) ~= "table" then
        return false
    end
    local detect = entry.detect or {}
    local ok, matched = safeCall(EnvUtil, detect.method, getDetectArg(detect))
    return ok and matched == true
end

-- 平台映射与门禁共用同一套取值口径，避免两处判定漂移。
local function getFieldValue(runtime, fieldName)
    if fieldName == "isMiniGame" then
        if not EnvUtil then
            return nil
        end
        local ok, value = safeCall(EnvUtil, "isMiniGame")
        return ok and value or nil
    end

    if fieldName == "bundleVersion" then
        -- 版本号是全局量，旧实现直接读 _G.bundleVersion。
        return _G.bundleVersion
    end

    if fieldName == "isRustDyGoReady" then
        -- 允许用例显式构造 runtime 环境，缺失时回落到线上真实的动更就绪标记。
        local ok, value = safeCall(runtime, fieldName)
        if ok and value ~= nil then
            return value
        end
        return getRustDyGoReady()
    end

    if fieldName == "channel" then
        if not EnvUtil.isAndroidPlatform then
            return nil
        end
        local enumValue = getDetectArg(HE_CHANNEL_DETECT)
        if enumValue == nil then
            return nil
        end
        local ok, matched = safeCall(EnvUtil, "isAndroidPlatform", enumValue)
        return ok and matched == true and "he" or "other"
    end

    if fieldName == "platform" then
        -- 返回门禁 allow 规则使用的平台标识（同平台的不同渠道共享 accessId）。
        for _, entry in ipairs(PLATFORM_EXPERIMENT_CONFIG.entries or {}) do
            if detectPlatform(entry) then
                return entry.accessId or entry.id
            end
        end
        return nil
    end

    local ok, value = safeCall(runtime, fieldName)
    return ok and value or nil
end

local function isRuleEnabled(rule)
    if type(rule) ~= "table" or rule.enabled == false then
        return false
    end

    local mode = rule.mode
    if mode == "allow" or mode == "exclude" then
        return type(rule.anyOf) == "table" and #rule.anyOf > 0
    end
    if mode == "block" then
        return type(rule.blocklist) == "table" and #rule.blocklist > 0
    end
    if mode == "equals" then
        return rule.expected ~= nil
    end
    if mode == "value" then
        return rule.op ~= nil
            and rule.value ~= nil
            and VALUE_COMPARATORS[rule.op] ~= nil
    end
    if mode == "min" or mode == "max" then
        return rule.min ~= nil or rule.max ~= nil
    end
    return false
end

local function isGateEnabled(gate)
    if type(gate) ~= "table" or gate.enabled == false or gate.id == nil then
        return false
    end
    if type(gate.rules) ~= "table" then
        return false
    end
    for _, rule in ipairs(gate.rules) do
        if isRuleEnabled(rule) then
            return true
        end
    end
    return false
end

local function matchAnyOf(actual, anyOf)
    if type(anyOf) ~= "table" then
        return false
    end
    for _, expected in ipairs(anyOf) do
        if actual == expected then
            return true
        end
    end
    return false
end

local function matchRuleValue(rule, actual)
    local mode = rule.mode
    if mode == "equals" then
        -- 动更就绪规则可按版本放宽：高于 requireRustDyGoReadyBelow 的包视为已直接生效。
        if rule.field == "isRustDyGoReady"
            and not shouldCheckRustDyGoReady(rule.requireRustDyGoReadyBelow) then
            return rule.expected == true
        end
        return actual == rule.expected
    end
    if mode == "value" then
        -- 通用数值比较：op = eq/lt/lte/gt/gte，value 为期望值。取不到数值即未通过。
        local comparator = VALUE_COMPARATORS[rule.op]
        local numericActual = tonumber(actual)
        local numericExpected = tonumber(rule.value)
        if not comparator or not numericActual or not numericExpected then
            return false
        end
        return comparator(numericActual, numericExpected)
    end
    if mode == "allow" then
        return matchAnyOf(actual, rule.anyOf)
    end
    if mode == "exclude" then
        return not matchAnyOf(actual, rule.anyOf)
    end
    if mode == "min" or mode == "max" then
        -- min/max 是版本号门槛，阈值必须写成字符串："1.160" 才不会被当成浮点 1.16。
        local threshold = mode == "min" and rule.min or rule.max
        if type(threshold) ~= "string" then
            return false
        end
        local compared = compareVersion(actual, threshold)
        if mode == "min" then
            return compared > 0 or (rule.minStrict ~= true and compared == 0)
        end
        return compared < 0 or (rule.maxStrict ~= true and compared == 0)
    end
    if mode == "block" then
        -- blocklist 是「字段取值黑名单」：字段取不到值时不参与屏蔽。
        if actual == nil or type(rule.blocklist) ~= "table" then
            return true
        end
        return not matchAnyOf(actual, rule.blocklist)
    end
    return false
end

local function matchGateRule(rule, runtime)
    if not isRuleEnabled(rule) then
        return true
    end
    return matchRuleValue(rule, getFieldValue(runtime, rule.field))
end

-- when 只用于把某条门禁收窄到指定平台或指定环境，默认 all。
local function matchGateCondition(condition, runtime)
    if type(condition) ~= "table" then
        return true
    end

    if condition.field == "isRustDyGoReady" then
        -- 带 requireRustDyGoReadyBelow 时，高于门槛的版本视为「已直接生效」。
        local ready = getRustDyGoReady()
        if not shouldCheckRustDyGoReady(condition.requireRustDyGoReadyBelow) then
            ready = true
        end
        return ready == condition.expected
    end

    local actual = getFieldValue(runtime, condition.field)
    if type(condition.expected) == "table" then
        return matchAnyOf(actual, condition.expected)
    end
    return actual == condition.expected
end

local function matchGateWhen(gate, runtime)
    local when = gate.when
    if type(when) ~= "table" then
        return true
    end

    local conditions = when.conditions or when
    local mode = when.cond or when.mode or "all"
    local matchedAny = false

    for _, condition in ipairs(conditions) do
        local matched = matchGateCondition(condition, runtime)
        if mode == "any" then
            if matched then
                matchedAny = true
                break
            end
        elseif not matched then
            return false
        end
    end

    return mode ~= "any" or matchedAny
end

-- 平台映射：experimentEnabled = false 的平台不参与实验，返回 nil（不读维护项、不写决策）。
local function getPlatformExperimentEntry()
    if not EnvUtil then
        return nil
    end

    for _, entry in ipairs(PLATFORM_EXPERIMENT_CONFIG.entries or {}) do
        if entry.experimentEnabled ~= false and detectPlatform(entry) then
            return entry
        end
    end

    return nil
end

-- 按顺序执行门禁清单，返回第一个未通过的 reason。
local function checkAccessGates(runtime)
    local accessConfig = PLATFORM_ACCESS_CONFIG
    if type(accessConfig) ~= "table" or accessConfig.enabled == false then
        return true
    end

    for _, gate in ipairs(accessConfig.gates or {}) do
        if isGateEnabled(gate) and matchGateWhen(gate, runtime) then
            for _, rule in ipairs(gate.rules) do
                if not matchGateRule(rule, runtime) then
                    return false, gate.reason or gate.id
                end
            end
        end
    end

    return true
end

local function getPlatformExperimentConfig()
    local entry = getPlatformExperimentEntry()
    return entry and entry.experimentConfig or nil
end

local function selectExperimentGroup(maintenanceManager, experimentConfig)
    if not maintenanceManager or not experimentConfig then
        return nil
    end

    local launchSwitches = experimentConfig.launchSwitches
    if type(launchSwitches) ~= "table" then
        return nil
    end

    -- 列表顺序就是优先级；单个开关内部顺序仅用于防御异常配置。
    for _, switchConfig in ipairs(launchSwitches) do
        if switchConfig.enabled ~= false
            and switchConfig.maintenanceName
            and type(switchConfig.groupOrder) == "table" then
            for _, groupName in ipairs(switchConfig.groupOrder) do
                if maintenanceManager:isEnabledInGroup(
                    switchConfig.maintenanceName,
                    groupName
                ) then
                    local groupConfigMap = switchConfig.groupConfigMap
                    if not groupConfigMap then
                        groupConfigMap = EXPERIENCE_GROUP_CONFIG
                    end
                    return groupName,
                        groupConfigMap[groupName],
                        experimentConfig,
                        switchConfig
                end
            end
        end
    end

    return nil
end

local function getExperimentGroup()
    if not MaintenanceManager then
        return nil
    end

    local maintenanceManager = MaintenanceManager:getInstance()
    if not maintenanceManager then
        return nil
    end

    local experimentConfig = getPlatformExperimentConfig()
    return selectExperimentGroup(maintenanceManager, experimentConfig)
end

local function isPlatformAllowed()
    -- 这是旧体验矩阵的门禁，保持新手期实验接入前的语义：
    -- 非小游戏、包版本 >= 1.160 即可继续进入旧平台维护开关；
    -- 动更就绪只属于新手期实验，不应反向收紧旧逻辑。
    if not EnvUtil or EnvUtil:isMiniGame() then
        return false, "platform_not_allowed"
    end

    if compareVersion(_G.bundleVersion, "1.160") < 0 then
        return false, "rust_lib_not_allowed"
    end

    return true
end

local function isRuntimeAllowed(runtime)
    if not runtime or not runtime.isInRust or not runtime:isInRust() then
        return false, "not_rust"
    end

    if _G.REPLAY_STAGE then
        return false, "replay"
    end

    if not runtime.getLevelScene
        or not UBFLevelSceneFunc
        or not UBFLevelSceneFunc:isMainLevel(runtime:getLevelScene()) then
        return false, "not_main_level"
    end

    local rawLevelId = runtime.getLevelId and runtime:getLevelId()
    local levelId = tonumber(rawLevelId) or rawLevelId
    if levelId and BLOCKED_LEVEL_IDS[levelId] then
        return false, "blocked_level"
    end

    return true
end

local function getToplevelBaoDiFlag(checkResult)
    local calculateDiffIndexResult = checkResult
        and checkResult.calculateDiffIndexResult

    return calculateDiffIndexResult
        and calculateDiffIndexResult.toplevelBaoDiFlag == true
        or false
end

local function isDifficultyAllowed(checkResult)
    if DIFFICULTY_CONFIG.enabled == false then
        return true
    end

    if type(checkResult) ~= "table" then
        return false, "check_result_missing"
    end

    local fixedDesiredDiffAvg = tonumber(checkResult.fixedDesiredDiffAvg)

    if not fixedDesiredDiffAvg then
        return false, "fixed_desired_diff_missing"
    end

    local epsilon = tonumber(DIFFICULTY_CONFIG.floatEpsilon) or 0
    local maxDifficulty = tonumber(DIFFICULTY_CONFIG.max)

    if maxDifficulty
        and fixedDesiredDiffAvg > maxDifficulty + epsilon then
        return false, "difficulty_above_threshold"
    end

    return true
end

local function isToplevelBaoDiAllowed(checkResult, required)
    if not required then
        return true
    end

    if getToplevelBaoDiFlag(checkResult) ~= true then
        return false, "toplevel_baodi_not_enabled"
    end

    return true
end

local function isUserLevelAllowed(runtime)
    local userLevelConfig = USER_LEVEL_CONFIG
    if type(userLevelConfig) ~= "table" or userLevelConfig.enabled == false then
        return true
    end

    local minimum = tonumber(userLevelConfig.min)
    local maximum = tonumber(userLevelConfig.max)
    if not minimum and not maximum then
        return true
    end

    local rawUserTopLevel = getFieldValue(
        runtime,
        userLevelConfig.field or "getUserTopLevel"
    )
    local userTopLevel = tonumber(rawUserTopLevel)

    -- 取不到有效数值时按配置决定；默认视为未命中，避免口径不明的用户误入实验。
    if not userTopLevel then
        if userLevelConfig.missingAsReject == true then
            return false, "user_top_level_missing", nil
        end
        return true
    end

    if minimum then
        -- 注意不能用 "a and b or c" 表达包含/不包含：false and x or y 会回退到 y。
        local passed
        if userLevelConfig.minInclusive == false then
            passed = userTopLevel > minimum
        else
            passed = userTopLevel >= minimum
        end
        if not passed then
            return false, "user_top_level_below_threshold", userTopLevel
        end
    end

    if maximum then
        local passed
        if userLevelConfig.maxInclusive == false then
            passed = userTopLevel < maximum
        else
            passed = userTopLevel <= maximum
        end
        if not passed then
            return false, "user_top_level_above_threshold", userTopLevel
        end
    end

    return true, nil, userTopLevel
end

local function isProphetConfigAvailable(configKey)
    return configKey
        and RustProphet
        and RustProphet.config
        and RustProphet.config[configKey] ~= nil
end

local function isNewUserProphetSwitchOn()
    if not MaintenanceManager then
        return false
    end

    local maintenanceManager = MaintenanceManager:getInstance()
    return maintenanceManager
        and maintenanceManager:isEnabledInGroup(
            NEW_USER_PROPHET_SWITCH_NAME,
            NEW_USER_PROPHET_SWITCH_GROUP
        ) == true
end

local function isNewUserProphetPlatformAllowed(runtime)
    return checkAccessGates(runtime)
end

local function getNewUserTopLevel(runtime)
    local rawTopLevel = getFieldValue(runtime, "getUserTopLevel")
    return tonumber(rawTopLevel)
end

local function getNewUserLevelId(runtime)
    local rawLevelId = runtime
        and runtime.getLevelId
        and runtime:getLevelId()
    local levelId = tonumber(rawLevelId)
    if not levelId
        or levelId < NEW_USER_MIN_LEVEL_ID
        or levelId > NEW_USER_MAX_LEVEL_ID
    then
        return nil
    end
    return levelId
end

local function getNewUserProphetConfigKey(levelId)
    if NEW_USER_SMOOTH_LEVEL_IDS[levelId] then
        return NEW_USER_PROPHET_CONFIG_KEYS.smooth
    end
    return NEW_USER_PROPHET_CONFIG_KEYS.ordinary
end

local function evaluateNewUserProphet(runtime, resultDatas)
    if not isNewUserProphetSwitchOn() then
        return nil
    end

    local allowed = isNewUserProphetPlatformAllowed(runtime)
    if not allowed then
        return nil
    end

    allowed = isRuntimeAllowed(runtime)
    if not allowed then
        return nil
    end

    local userTopLevel = getNewUserTopLevel(runtime)
    if not userTopLevel or userTopLevel >= NEW_USER_MAX_TOP_LEVEL then
        return nil
    end

    local checkResult = resultDatas and resultDatas.checkResult
    allowed = isDifficultyAllowed(checkResult)
    if not allowed then
        return nil
    end

    local levelId = getNewUserLevelId(runtime)
    if not levelId then
        return nil
    end

    local configKey = getNewUserProphetConfigKey(levelId)
    local decision = {
        available = true,
        enabled = false,
        group = NEW_USER_PROPHET_SWITCH_GROUP,
        maintenanceName = NEW_USER_PROPHET_SWITCH_NAME,
        experimentSwitch = NEW_USER_PROPHET_SWITCH_NAME,
        configKey = configKey,
        removeDiffFix = true,
        originalDiffFix = resultDatas and resultDatas.diffFix,
        fixedDesiredDiffAvg = checkResult and checkResult.fixedDesiredDiffAvg,
        desiredDiffAvg = checkResult and checkResult.desiredDiffAvg,
        diffIndex = checkResult and checkResult.diffIndex,
        requireToplevelBaoDi = false,
        toplevelBaoDiFlag = getToplevelBaoDiFlag(checkResult),
        experienceType = NEW_USER_SMOOTH_LEVEL_IDS[levelId]
            and "new_user_smooth"
            or "new_user_ordinary",
        experienceRouteReason = "new_user_level_route",
        userTopLevel = userTopLevel,
        experienceContext = {
            levelId = levelId,
            userTopLevel = userTopLevel,
            configType = NEW_USER_SMOOTH_LEVEL_IDS[levelId]
                and "smooth"
                or "ordinary",
        },
    }

    if type(runtime.adjustData) ~= "table" then
        decision.reason = "adjust_data_missing"
        return decision
    end

    if not isProphetConfigAvailable(configKey) then
        decision.reason = "new_user_config_missing"
        return decision
    end

    decision.enabled = true
    decision.reason = "enabled"
    return decision
end

local function getLevelDifficultyContext(runtime)
    local levelJsonData = runtime and runtime.levelJsonData
    if not levelJsonData
        and runtime
        and runtime.getLevelJsonData then
        levelJsonData = runtime:getLevelJsonData()
    end

    if not levelJsonData or not levelJsonData.getLevelDifficultFlag then
        return nil, nil
    end

    local difficultyFlag = levelJsonData:getLevelDifficultFlag()
    if difficultyFlag == nil then
        return nil, nil
    end

    local normalFlag = LevelDiffcultFlag and LevelDiffcultFlag.kNormal
    if normalFlag == nil then
        return difficultyFlag, nil
    end

    local difficultyClass = difficultyFlag == normalFlag and "normal" or "hard"
    return difficultyFlag, difficultyClass
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

    -- START_LEVEL 时活动已经把关卡外数据快照到 modContextData，优先使用快照。
    if modMgr.getModContextData then
        local modContextData = modMgr:getModContextData(activityId)
        if type(modContextData) == "table"
            and type(modContextData.smbEffective) == "boolean" then
            return modContextData.smbEffective
        end
    end

    -- 兼容活动环境数据已生成、但 context 尚未完成同步的流程。
    if modMgr.getModData then
        local modDataList = modMgr:getModData(activityId)
        local modData = type(modDataList) == "table" and modDataList[1]
        local env = modData and modData.env
        if type(env) == "table" and type(env.hasSuperPower) == "boolean" then
            return env.hasSuperPower
        end
    end

    -- 活动没有参与当前关卡时，模块状态可能是 nil；按既有 Lua 约定视为 false。
    if modMgr.getModEnabled and modMgr:getModEnabled(activityId) ~= true then
        return false
    end

    -- 活动已参与但数据仍未准备好时，不引入第三种路由状态，按 false 处理。
    return false
end

local function getExperienceContext(runtime, checkResult, userTopLevel)
    local difficultyFlag, difficultyClass = getLevelDifficultyContext(runtime)
    local levelId = runtime
        and runtime.getLevelId
        and runtime:getLevelId()
    local levelScene = runtime
        and runtime.getLevelScene
        and runtime:getLevelScene()

    return {
        levelId = levelId,
        levelScene = levelScene,
        difficultyFlag = difficultyFlag,
        difficultyClass = difficultyClass,
        superBirdActive = getSuperBirdActive(runtime),
        toplevelBaoDi = getToplevelBaoDiFlag(checkResult),
        userTopLevel = userTopLevel,
        fixedDesiredDiffAvg = checkResult
            and tonumber(checkResult.fixedDesiredDiffAvg),
        desiredDiffAvg = checkResult
            and tonumber(checkResult.desiredDiffAvg),
        diffIndex = checkResult and checkResult.diffIndex,
    }
end

local function matchesExpectedValue(actual, expected)
    if type(expected) ~= "table" then
        return actual == expected
    end

    if expected.min ~= nil or expected.max ~= nil then
        local numericActual = tonumber(actual)
        if not numericActual then
            return false
        end
        if expected.min ~= nil and numericActual < expected.min then
            return false
        end
        if expected.max ~= nil and numericActual > expected.max then
            return false
        end
        return true
    end

    if expected[actual] ~= nil then
        return expected[actual] == true
    end

    for _, value in ipairs(expected) do
        if actual == value then
            return true
        end
    end

    return false
end

local function matchesExperienceRoute(context, route)
    local conditions = route and route.conditions
    if type(conditions) ~= "table" then
        return false
    end

    for field, expected in pairs(conditions) do
        if not matchesExpectedValue(context and context[field], expected) then
            return false
        end
    end

    return true
end

local function selectExperienceConfig(context, routingConfig, experienceMode)
    if type(routingConfig) ~= "table"
        or routingConfig.enabled ~= true
        or type(routingConfig.routes) ~= "table" then
        return nil, nil, "experience_routing_disabled"
    end

    for _, route in ipairs(routingConfig.routes) do
        if matchesExperienceRoute(context, route) then
            local configKey = experienceMode == "full"
                and route.fullConfigKey
                or route.trackingOnlyConfigKey
            if not configKey then
                return nil, route.id, "experience_config_not_defined"
            end
            return configKey, route.id, "experience_route_matched"
        end
    end

    return nil, nil, "experience_route_not_matched"
end

function ProphetLaunchStrategy:evaluate(runtime, resultDatas)
    if not PROPHET_EXPERIMENT_ENABLED then
        return nil
    end

    -- 新手期实验独立于旧体验矩阵：开关命中且满足条件时直接使用新配置；
    -- 其他情况继续走原有矩阵，避免新开关改变旧逻辑的门禁和回退行为。
    local newUserDecision = evaluateNewUserProphet(runtime, resultDatas)
    if newUserDecision then
        return newUserDecision
    end

    local groupName, groupConfig, experimentConfig, switchConfig =
        getExperimentGroup()
    if not groupName or not experimentConfig or not switchConfig then
        return nil
    end

    local checkResult = resultDatas and resultDatas.checkResult
    local decision = {
        available = groupConfig and groupConfig.enableProphet == true or false,
        enabled = false,
        group = groupName,
        maintenanceName = switchConfig.maintenanceName,
        experimentSwitch = switchConfig.id,
        configKey = nil,
        -- Prophet 启动后不与旧 diffFix 共存；该字段只用于结果记录和下游打点。
        removeDiffFix = groupConfig and groupConfig.enableProphet == true or false,
        originalDiffFix = resultDatas and resultDatas.diffFix,
        fixedDesiredDiffAvg = checkResult and checkResult.fixedDesiredDiffAvg,
        desiredDiffAvg = checkResult and checkResult.desiredDiffAvg,
        diffIndex = checkResult and checkResult.diffIndex,
        requireToplevelBaoDi =
            groupConfig and groupConfig.requireToplevelBaoDi == true or false,
        toplevelBaoDiFlag = getToplevelBaoDiFlag(checkResult),
        experienceType = "experience",
    }

    if not groupConfig then
        decision.reason = "experience_config_missing"
        return decision
    end

    local allowed, reason = isPlatformAllowed()
    if not allowed then
        decision.reason = reason
        return decision
    end

    allowed, reason = isRuntimeAllowed(runtime)
    if not allowed then
        decision.reason = reason
        return decision
    end

    if not decision.available then
        decision.reason = "control_group"
        return decision
    end

    local userTopLevel
    allowed, reason, userTopLevel = isUserLevelAllowed(runtime)
    decision.userTopLevel = userTopLevel
    if not allowed then
        decision.reason = reason
        return decision
    end

    allowed, reason = isDifficultyAllowed(checkResult)
    if not allowed then
        decision.reason = reason
        return decision
    end

    allowed, reason = isToplevelBaoDiAllowed(checkResult, decision.requireToplevelBaoDi)
    if not allowed then
        decision.reason = reason
        return decision
    end

    local experienceRouting = groupConfig.experienceRouting
    if experienceRouting and experienceRouting.enabled == true then
        decision.experienceContext = getExperienceContext(
            runtime,
            checkResult,
            userTopLevel
        )
        local configKey, experienceType, routeReason = selectExperienceConfig(
            decision.experienceContext,
            experienceRouting,
            groupConfig.experienceMode
        )
        decision.experienceRouteReason = routeReason
        if experienceType then
            decision.experienceType = experienceType
            decision.configKey = configKey
        elseif routeReason == "experience_route_not_matched" then
            decision.reason = routeReason
            return decision
        end
    end

    if decision.removeDiffFix and type(runtime.adjustData) ~= "table" then
        decision.reason = "adjust_data_missing"
        return decision
    end

    if not isProphetConfigAvailable(decision.configKey) then
        decision.reason = "experience_config_missing"
        return decision
    end

    decision.enabled = true
    decision.reason = "enabled"
    return decision
end

-- 供调试和单元测试复用；实际启动仍由 evaluate 统一执行门禁。
function ProphetLaunchStrategy:getExperienceContext(runtime, checkResult, userTopLevel)
    return getExperienceContext(runtime, checkResult, userTopLevel)
end

-- 供配置验证和单元测试复用；routes 的顺序就是匹配优先级。
function ProphetLaunchStrategy:selectExperienceConfig(
    context,
    routingConfig,
    experienceMode
)
    return selectExperienceConfig(context, routingConfig, experienceMode)
end

-- 供配置验证和单元测试复用；switches 的顺序就是开关优先级。
function ProphetLaunchStrategy:selectExperimentGroup(maintenanceManager, experimentConfig)
    return selectExperimentGroup(maintenanceManager, experimentConfig)
end

-- 供配置验证和单元测试复用；修改返回值即可在不改实现的前提下切换门禁与实验配置。
function ProphetLaunchStrategy:getConfig()
    return {
        enabled = PROPHET_EXPERIMENT_ENABLED,
        platformAccess = PLATFORM_ACCESS_CONFIG,
        userLevel = USER_LEVEL_CONFIG,
        userLevelPresets = USER_LEVEL_PRESETS,
        difficulty = DIFFICULTY_CONFIG,
        blockedLevelIds = BLOCKED_LEVEL_IDS,
        platformExperiment = PLATFORM_EXPERIMENT_CONFIG,
        experienceGroup = EXPERIENCE_GROUP_CONFIG,
        experienceRouting = EXPERIENCE_ROUTING_CONFIG,
        experienceGroupOrder = EXPERIENCE_GROUP_ORDER,
        newUserProphet = {
            switchName = NEW_USER_PROPHET_SWITCH_NAME,
            switchGroup = NEW_USER_PROPHET_SWITCH_GROUP,
            maxTopLevel = NEW_USER_MAX_TOP_LEVEL,
            minLevelId = NEW_USER_MIN_LEVEL_ID,
            maxLevelId = NEW_USER_MAX_LEVEL_ID,
            smoothLevelIds = NEW_USER_SMOOTH_LEVEL_IDS,
            configKeys = NEW_USER_PROPHET_CONFIG_KEYS,
        },
        selfFeedbackEnabledWhenLaunched =
            SELF_FEEDBACK_ENABLED_WHEN_PROPHET_LAUNCHED,
    }
end

function ProphetLaunchStrategy:apply(runtime, resultDatas)
    local decision = self:evaluate(runtime, resultDatas)
    if not decision then
        return nil
    end

    runtime.prophetLaunchInfo = decision
    if not decision.enabled then
        return decision
    end

    local adjustLogic = runtime.UBFuuuAdjustLogic
    if not adjustLogic or not adjustLogic.setSelfFeedbackEnableFlag then
        decision.enabled = false
        decision.reason = "self_feedback_control_missing"
        return decision
    end

    local selfFeedbackSourceName = decision.maintenanceName .. "_" .. decision.group
    adjustLogic:setSelfFeedbackEnableFlag(
        selfFeedbackSourceName,
        SELF_FEEDBACK_ENABLED_WHEN_PROPHET_LAUNCHED
    )

    local checkResult = resultDatas and resultDatas.checkResult
    if checkResult and adjustLogic.getUbfuuuAdjustFixInfo then
        checkResult.adjustFixInfo = adjustLogic:getUbfuuuAdjustFixInfo()
    end

    runtime:setProphet(decision.configKey)

    if decision.removeDiffFix and runtime.adjustData then
        runtime.adjustData.diffFix = nil
    end

    return decision
end

function ProphetLaunchStrategy:applySafely(runtime, resultDatas)
    local ok, result = pcall(self.apply, self, runtime, resultDatas)
    if ok then
        return result
    end

    if he_log_error then
        he_log_error("ProphetLaunchStrategy_apply_error_" .. tostring(result))
    elseif printx then
        printx(0, "ProphetLaunchStrategy:applySafely error", tostring(result))
    else
        print("ProphetLaunchStrategy:applySafely error", tostring(result))
    end
    return nil
end

return ProphetLaunchStrategy
