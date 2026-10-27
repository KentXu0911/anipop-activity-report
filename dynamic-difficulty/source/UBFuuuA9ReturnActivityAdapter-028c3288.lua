local UBFuuuA9ReturnActivityAdapter = {}

local ACT_KEY = "A9_return_activity"
local ACTIVITY_INDEX_MIN = 1
local ACTIVITY_INDEX_MAX = 16

local function getA9Info(adjustContext)
    adjustContext.a9ReturnActivityInfo = adjustContext.a9ReturnActivityInfo or {}
    return adjustContext.a9ReturnActivityInfo
end

local function boolValue(value)
    return value == true or value == 1 or value == "1" or value == "true"
end

local function safeCall(func, ...)
    local ok, ret = pcall(func, ...)
    if ok then
        return ret
    end
    return nil
end

local function cloneMap(source)
    local target = {}
    if type(source) == "table" then
        for k, v in pairs(source) do
            target[k] = v
        end
    end
    return target
end

local function isTopLevel(adjustContext)
    if type(adjustContext) ~= "table" then
        return false
    end
    local levelId = tonumber(adjustContext.levelId)
    local maxLevelId = tonumber(adjustContext.maxLevelId)
    local topRangeLength = tonumber(adjustContext.topRangeLength)
    if not levelId or not maxLevelId or not topRangeLength then
        return false
    end
    return levelId > maxLevelId - topRangeLength
end

local function getStatisticInfo(adjustContext)
    return adjustContext and adjustContext.ubfuuuStatisticInfo or {}
end

local function getDailyPlayCountList(adjustContext)
    local statisticInfo = getStatisticInfo(adjustContext)
    if type(statisticInfo.dailyPlayCountList) == "table" then
        return statisticInfo.dailyPlayCountList
    end
    if type(adjustContext.dailyPlayCountList) == "table" then
        return adjustContext.dailyPlayCountList
    end
    return {}
end

local function getTodayPlayCount(adjustContext)
    local statisticInfo = getStatisticInfo(adjustContext)
    local todayPlayCount = tonumber(adjustContext.todayPlayCount or statisticInfo.todayPlayCount)
    if todayPlayCount ~= nil then
        return todayPlayCount
    end
    local dailyPlayCountList = getDailyPlayCountList(adjustContext)
    return tonumber(dailyPlayCountList[1]) or 0
end

local function getCurrentNaturalDay()
    local nowTime = nil
    local ok, UBFuuuAdjustManager = pcall(require, "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuAdjustManager")
    if ok and UBFuuuAdjustManager and UBFuuuAdjustManager.timeInSec then
        nowTime = UBFuuuAdjustManager:timeInSec()
    end

    nowTime = nowTime or os.time()
    if time2day then
        return time2day(nowTime)
    end
    return nil
end

function UBFuuuA9ReturnActivityAdapter:loadReturnDayConfig()
    local ok, config = pcall(require, "zoo.config.meta.ubfuuu_activity_index_map_by_returnday_playcount_config")
    if ok and type(config) == "table" then
        return config, "zoo.config.meta"
    end

    ok, config = pcall(require, "ubf.metaConfig.ubfuuu_activity_index_map_by_returnday_playcount_config")
    if ok and type(config) == "table" then
        return config, "ubf.metaConfig"
    end

    return nil, "missing"
end

function UBFuuuA9ReturnActivityAdapter:getReturnDayForA9(adjustContext)
    local returnDayIndex = tonumber(adjustContext and adjustContext.returnDayIndex) or 0
    if returnDayIndex <= 0 then
        return 0
    end
    return math.max(returnDayIndex - 1, 0)
end

function UBFuuuA9ReturnActivityAdapter:calcReturnAvgPlayCount(adjustContext, returnDayForA9)
    local dayCount = math.max((tonumber(returnDayForA9) or 0) + 1, 1)
    local dailyPlayCountList = getDailyPlayCountList(adjustContext)
    local playCount = getTodayPlayCount(adjustContext)

    if dayCount > 1 then
        for i = 2, dayCount do
            playCount = playCount + (tonumber(dailyPlayCountList[i]) or 0)
        end
    end

    return playCount / dayCount, playCount, dayCount
end

function UBFuuuA9ReturnActivityAdapter:findA9ActivityIndex(configMap, group, returnDayForA9, avgPlayCount)
    if type(configMap) ~= "table" then
        return nil, "config_nil"
    end

    local dayKey = "day" .. tostring(returnDayForA9 or 0)
    local selectedRow = nil
    for _, row in ipairs(configMap) do
        if tonumber(row.group) == tonumber(group) and (tonumber(avgPlayCount) or 0) <= (tonumber(row.playcount) or 0) then
            selectedRow = row
            break
        end
    end

    if not selectedRow then
        return nil, "row_not_found"
    end

    local value = selectedRow[dayKey]
    if value == nil or value == "" then
        return nil, "empty"
    end

    local activityIndex = tonumber(value)
    if not activityIndex then
        return nil, "invalid_value"
    end

    return activityIndex, nil, selectedRow
end

function UBFuuuA9ReturnActivityAdapter:_readReturnKeyFromTag()
    local UBFTagManager = rawget(_G, "UBFTagManager")
    local ReturnUserActivityType = rawget(_G, "ReturnUserActivityType")
    if UBFTagManager and ReturnUserActivityType and UBFTagManager.getReturnTime then
        return safeCall(function()
            return UBFTagManager:getReturnTime(ReturnUserActivityType.kAllPlayLevel)
        end)
    end
end

function UBFuuuA9ReturnActivityAdapter:normalizeContext(adjustContext)
    if type(adjustContext) ~= "table" then
        return adjustContext
    end

    adjustContext.modGroup = adjustContext.modGroup or {}
    adjustContext.CAGroup = adjustContext.CAGroup or {}
    adjustContext.reportModGroup = adjustContext.reportModGroup or cloneMap(adjustContext.modGroup)

    local info = getA9Info(adjustContext)
    local enabled = info.enabled
    if enabled == nil then
        if adjustContext.modGroup.A9 ~= nil then
            enabled = boolValue(adjustContext.modGroup.A9)
        elseif adjustContext.switchName then
            local maintenanceManager = MaintenanceManager and MaintenanceManager.getInstance and MaintenanceManager:getInstance()
            if maintenanceManager and maintenanceManager.isEnabledInGroup then
                enabled = maintenanceManager:isEnabledInGroup(adjustContext.switchName, "A9") == true
            else
                enabled = false
            end
        else
            enabled = false
        end
    else
        enabled = boolValue(enabled)
    end

    info.enabled = enabled
    info.a8InjectedByA9 = nil
    adjustContext.a8InjectedByA9 = nil
    adjustContext.modGroup.A9 = enabled or nil
    adjustContext.reportModGroup.A9 = enabled or nil

    if enabled then
        -- A9 只在外层追加 activityIndex1 fix；基础活跃档位仍复用现有 A8 逻辑。
        if not adjustContext.reportModGroup.A8 then
            info.a8InjectedByA9 = true
            adjustContext.a8InjectedByA9 = true
        end
        adjustContext.modGroup.A8 = true
    end

    info.group = tonumber(info.group or adjustContext.CAGroup.CA10) or 1
    info.returnKey = info.returnKey or adjustContext.returnKey or adjustContext.returnTime or self:_readReturnKeyFromTag()
    if info.returnKey == nil and adjustContext.returnState then
        info.returnKey = tostring(adjustContext.lostDay or "lost") .. "_" .. tostring(adjustContext.returnDayIndex or "day")
    end

    return adjustContext
end

function UBFuuuA9ReturnActivityAdapter:isEnabled(adjustContext)
    local info = getA9Info(adjustContext or {})
    return info.enabled == true
end

function UBFuuuA9ReturnActivityAdapter:_getServerSmoothMaxValue(adjustContext, info)
    local statisticInfo = getStatisticInfo(adjustContext)
    local latestActivityIndex1 = tonumber(statisticInfo.latestActivityIndex1 or adjustContext.latestActivityIndex1)
    local latestActivityIndex1Day = tonumber(statisticInfo.latestActivityIndex1Day or adjustContext.latestActivityIndex1Day)
    local currentDay = getCurrentNaturalDay()

    info.latestActivityIndex1 = latestActivityIndex1
    info.latestActivityIndex1Day = latestActivityIndex1Day
    info.currentDay = currentDay

    if not latestActivityIndex1 or latestActivityIndex1 < ACTIVITY_INDEX_MIN then
        return nil, "latest_activity_index_invalid"
    end
    if not latestActivityIndex1Day or not currentDay then
        return nil, "latest_activity_day_invalid"
    end
    if latestActivityIndex1Day > currentDay then
        return nil, "latest_activity_day_after_current_day"
    end

    return math.min(latestActivityIndex1 + 2, ACTIVITY_INDEX_MAX)
end

function UBFuuuA9ReturnActivityAdapter:_appendActivityIndex1Fix(adjustContext, sourceName, value, fixMode, datas)
    if type(adjustContext) ~= "table" then
        return false
    end

    adjustContext.activityIndex1FixInfo = adjustContext.activityIndex1FixInfo or {}
    datas = datas or {}
    local fixInfo = {
        sourceName = sourceName,
        value = value or 0,
        fixMode = fixMode or UBFuuuFixMode.kaddVaule,
        rangeMin = datas.rangeMin,
        rangeMax = datas.rangeMax,
        resultMin = datas.resultMin,
        resultMax = datas.resultMax,
        minValue = datas.minValue,
        maxValue = datas.maxValue,
    }
    table.insert(adjustContext.activityIndex1FixInfo, fixInfo)
    return true
end

function UBFuuuA9ReturnActivityAdapter:beforeCheck(ubfSLRuntime, adjustContext, modEnvData)
    self:normalizeContext(adjustContext)
    local info = getA9Info(adjustContext)
    modEnvData = modEnvData or {}

    if not info.enabled then
        info.source = "Disabled"
        return
    end

    if isTopLevel(adjustContext) then
        info.source = "TopLevel"
        info.a9ActivityIndex = ACTIVITY_INDEX_MAX
        self:_appendActivityIndex1Fix(adjustContext, ACT_KEY .. "_top_level", ACTIVITY_INDEX_MAX, UBFuuuFixMode.kSetVaule, {
            minValue = ACTIVITY_INDEX_MIN,
            maxValue = ACTIVITY_INDEX_MAX,
        })
        return
    end

    if not adjustContext.returnState then
        info.source = "NotReturn"
        info.fallbackReason = "not_return"
        return
    end

    local configMap, configSource = self:loadReturnDayConfig()
    info.configSource = configSource
    if not configMap then
        info.source = "A8Fallback"
        info.fallbackReason = "config_nil"
        return
    end

    local returnDayForA9 = self:getReturnDayForA9(adjustContext)
    local avgPlayCount, totalPlayCount, dayCount = self:calcReturnAvgPlayCount(adjustContext, returnDayForA9)
    local group = tonumber(info.group or adjustContext.CAGroup.CA10) or 1
    local activityIndex, fallbackReason, selectedRow = self:findA9ActivityIndex(configMap, group, returnDayForA9, avgPlayCount)

    info.group = group
    info.returnDayForA9 = returnDayForA9
    info.returnAvgPlayCount = avgPlayCount
    info.returnTotalPlayCount = totalPlayCount
    info.returnDayCount = dayCount
    info.selectedConfigId = selectedRow and selectedRow.id or nil

    if activityIndex then
        info.source = "A9"
        info.a9ActivityIndex = activityIndex
        self:_appendActivityIndex1Fix(adjustContext, ACT_KEY, activityIndex, UBFuuuFixMode.kSetVaule, {
            minValue = ACTIVITY_INDEX_MIN,
            maxValue = ACTIVITY_INDEX_MAX,
        })
        return
    end

    info.source = "A8Fallback"
    info.fallbackReason = fallbackReason or "empty"

    local maxValue, smoothReason = self:_getServerSmoothMaxValue(adjustContext, info)
    info.maxValue = maxValue

    if maxValue then
        self:_appendActivityIndex1Fix(adjustContext, ACT_KEY .. "_smooth", 0, UBFuuuFixMode.kaddVaule, {
            maxValue = maxValue,
        })
    else
        info.fallbackReason = info.fallbackReason .. "_" .. tostring(smoothReason or "missing_latest_activity_index")
    end
end

return UBFuuuA9ReturnActivityAdapter
