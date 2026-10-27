local Log = {}

Log.Channel = 12 -- Unity 侧本地调试日志通道。

Log.Module = {
    MANAGER = 1, -- 活动 Manager 生命周期、入口和活动框架回调。
    MODEL = 2, -- 活动 Model 数据接收、配置解析和本地缓存。
    PANEL = 3, -- 面板创建、销毁和基础交互。
    VIEW = 4, -- 视图节点刷新、表现状态和布局。
    BOARD = 5, -- 棋盘运行时状态、棋子增删和棋盘快照。
    PHYSICS = 6, -- 物理移动、碰撞、速度和稳定判断。
    LAUNCHER = 7, -- 发射台、当前杯、下一个杯和发射参数。
    MERGE = 8, -- 合成判定、合成结果和合成反馈。
    REQUEST = 9, -- 协议请求、回包和同步触发。
    GUIDE = 10, -- 引导状态和引导流程。
    ORDER = 11, -- 订单展示、订单完成检测和订单提交。
    BONUS = 12, -- 磁铁、清屏雨等 bonus 道具流程。
    TEST = 99, -- 临时测试入口或一次性验证日志。
}

Log.ModuleName = {
    [Log.Module.MANAGER] = "Manager", -- Manager 模块日志名。
    [Log.Module.MODEL] = "Model", -- Model 模块日志名。
    [Log.Module.PANEL] = "Panel", -- Panel 模块日志名。
    [Log.Module.VIEW] = "View", -- View 模块日志名。
    [Log.Module.BOARD] = "Board", -- Board 模块日志名。
    [Log.Module.PHYSICS] = "Physics", -- Physics 模块日志名。
    [Log.Module.LAUNCHER] = "Launcher", -- Launcher 模块日志名。
    [Log.Module.MERGE] = "Merge", -- Merge 模块日志名。
    [Log.Module.REQUEST] = "Request", -- Request 模块日志名。
    [Log.Module.GUIDE] = "Guide", -- Guide 模块日志名。
    [Log.Module.ORDER] = "Order", -- Order 模块日志名。
    [Log.Module.BONUS] = "Bonus", -- Bonus 模块日志名。
    [Log.Module.TEST] = "Test", -- Test 模块日志名。
}

Log.Config = {
    enabled = true, -- 日常总开关；总开关关闭时只记录内存日志，不即时展示。
    moduleSwitch = {
        [Log.Module.MANAGER] = false, -- Manager 模块是否即时展示。
        [Log.Module.MODEL] = false, -- Model 模块是否即时展示。
        [Log.Module.PANEL] = false, -- Panel 模块是否即时展示。
        [Log.Module.VIEW] = false, -- View 模块是否即时展示。
        [Log.Module.BOARD] = false, -- Board 模块是否即时展示。
        [Log.Module.PHYSICS] = false, -- Physics 模块是否即时展示。
        [Log.Module.LAUNCHER] = false, -- Launcher 模块是否即时展示。
        [Log.Module.MERGE] = false, -- Merge 模块是否即时展示。
        [Log.Module.REQUEST] = false, -- Request 模块是否即时展示。
        [Log.Module.GUIDE] = false, -- Guide 模块是否即时展示。
        [Log.Module.ORDER] = false, -- Order 模块是否即时展示。
        [Log.Module.BONUS] = false, -- Bonus 模块是否即时展示。
        [Log.Module.TEST] = false, -- Test 模块是否即时展示。
    },
    recordEnabled = true, -- 总开关开启时是否记录未展示日志，便于后续统一 dump。
    maxRecordCount = 200, -- 内存日志最大保留条数，超过后丢弃最早记录。
}

Log.missingModuleTips = {} -- 缺失模块配置的提示记录，避免同一模块重复刷屏。
Log.records = {} -- 内存日志记录；保存原始参数，真正输出时才按需 tts。

-- Unity 侧调试输出走 UError，非 Unity 侧保留 printx；后续若要换底层输出，只改这里。
function Log.output(...)
    if EnvUtil:isUnity() then
        UError(...)
    else
        printx(Log.Channel, ...)
    end
end

-- 设置日志总开关；关闭后所有模块都不输出。
function Log.setEnabled(enabled)
    Log.Config.enabled = enabled == true
end

-- 设置单个模块日志开关；moduleId 使用 Log.Module 中的常量。
function Log.setModuleEnabled(moduleId, enabled)
    if not moduleId then return end
    Log.Config.moduleSwitch[moduleId] = enabled == true
end

-- 设置内存日志记录开关；关闭后只按模块开关即时输出，不保留历史。
function Log.setRecordEnabled(enabled)
    Log.Config.recordEnabled = enabled == true
end

-- 设置内存日志最大保留条数；用于控制长时间试玩时的内存占用。
function Log.setMaxRecordCount(count)
    count = tonumber(count)
    if not count or count <= 0 then return end
    Log.Config.maxRecordCount = math.floor(count)
end

-- 获取模块展示名；未知模块保留 ID，方便定位遗漏的模块定义。
function Log.getModuleName(moduleId)
    return Log.ModuleName[moduleId] or tostring(moduleId)
end

-- 对缺失模块配置输出一次提示；用于发现忘记加枚举或忘记配置开关的调用点。
function Log.printMissingModuleTip(moduleId, reason)
    if not Log.Config.enabled then return end
    local key = tostring(reason) .. "_" .. tostring(moduleId)
    if Log.missingModuleTips[key] then return end
    Log.missingModuleTips[key] = true
    Log.output("[PengPeng2026]", "[Log]", reason, tostring(moduleId))
end

-- 判断指定模块是否允许输出日志；必须有模块枚举名且单模块开关显式为 true。
function Log.isEnabled(moduleId)
    if not Log.Config.enabled then return false end
    if Log.ModuleName[moduleId] == nil then
        Log.printMissingModuleTip(moduleId, "undefined log module")
        return false
    end

    local moduleEnabled = Log.Config.moduleSwitch[moduleId]
    if moduleEnabled == nil then
        Log.printMissingModuleTip(moduleId, "unconfigured log module")
        return false
    end
    return moduleEnabled == true
end

-- 格式化单个日志参数；table 是否 tts 由调用方的 needTts 决定。
function Log.formatValue(value, needTts)
    if needTts == true and type(value) == "table" then
        return tts(value)
    end
    return value
end

-- 组装最终输出参数；table 参数在这里按 needTts 决定是否转换。
function Log.buildPrintArgs(moduleId, needTts, values)
    local args = {
        "[PengPeng2026]",
        "[" .. Log.getModuleName(moduleId) .. "]",
    }
    for index = 1, #(values or {}) do
        table.insert(args, Log.formatValue(values[index], needTts))
    end
    return args
end

-- 记录一条内存日志；即时不展示的模块也能在需要时统一 dump。
function Log.record(moduleId, needTts, ...)
    if not Log.Config.recordEnabled then return end

    local values = {}
    local count = select("#", ...)
    for index = 1, count do
        local value = select(index, ...)
        table.insert(values, value)
    end

    table.insert(Log.records, {
        time = TimeKit:timeInMillis(),
        moduleId = moduleId,
        needTts = needTts == true,
        values = values,
    })

    while #Log.records > Log.Config.maxRecordCount do
        table.remove(Log.records, 1)
    end
end

-- 清空内存日志记录；用于新一轮调试前重置历史。
function Log.clearRecords()
    Log.records = {}
end

-- 输出内存日志记录；moduleId 为空时输出全部，needTtsOverride 可统一覆盖 tts 行为。
function Log.dump(moduleId, needTtsOverride)
    Log.output("[PengPeng2026]", "[Log]", "dump begin", "moduleId", tostring(moduleId), "count", #Log.records)
    local dumpCount = 0
    for _, record in ipairs(Log.records) do
        if moduleId == nil or record.moduleId == moduleId then
            dumpCount = dumpCount + 1
            local needTts = record.needTts
            if needTtsOverride ~= nil then
                needTts = needTtsOverride == true
            end
            local args = Log.buildPrintArgs(record.moduleId, needTts, record.values)
            table.insert(args, 3, "[History]")
            table.insert(args, 4, tostring(record.time))
            Log.output(unpack(args))
        end
    end
    Log.output("[PengPeng2026]", "[Log]", "dump end", "dumpCount", dumpCount)
    return dumpCount
end

-- 输出模块日志；table 参数可直接传入，只有 needTts 为 true 时才在最终输出前 tts。
function Log.print(moduleId, needTts, ...)
    Log.record(moduleId, needTts, ...)
    if not Log.isEnabled(moduleId) then return end

    local values = {}
    local count = select("#", ...)
    for index = 1, count do
        local value = select(index, ...)
        table.insert(values, value)
    end
    Log.output(unpack(Log.buildPrintArgs(moduleId, needTts, values)))
end

return Log
