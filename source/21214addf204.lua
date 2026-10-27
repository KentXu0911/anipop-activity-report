local BaseFeatureModel = require "amf.middleware.activity.base.BaseFeatureModel"
local jsonDecode = require "amf.script.encode.jsonDecode"
local Model = class("AIPopupModel", BaseFeatureModel)

-- 服务端 aiAutoPopInfo 是「自然天编号 -> 当天预测」的 map，value 是一段 JSON 字符串：
--   20705 = '{"target_date":"2026-09-08","prediction_id":"popuprec_20260908_191040_001",
--             "strategy":"model","predictions":{"6074":0.0933,"4046":0.0001,...}}'
-- key 是这条数据的归属天：服务端没取到当天预测时，会把前一天的 payload 挂在今天的 key 下
-- 返回，此时按 key（今天）来用；payload 里的 target_date 原样保留，打点回传时不能改写。
-- 活动范围和活动 ID 以服务端返回为准：返回的活动都参与排序，权重不合法的按约定兜底。

-- 本地只保留最近几天，够当天用即可。
local MAX_PREDICTION_DAYS = 3

-- 排序权重：服务端给的值不在 [0,1] 内（含非数值）时按约定兜底。
local DEFAULT_DEPTH_SCORE = 0.12

function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "AIPopupModel",
    }):as("db")
    self:installPlug(AMFDataPlugsType.SYNC, {
        requests = {
            aiAutoPopInfo = "amf.feature.localactivity.aipopup.http.RequestAiAutoPopInfo",
        },
    })
end

function Model:_getConstPath()
    return "amf.feature.localactivity.aipopup.config.AIPopupConst"
end

function Model:__declare()
    self.predictionId = nil
    self.strategy = nil
    self.predictions = {}
    self.lastFetchTime = 0
end

function Model:isDataEnabled()
    return not table.isEmpty(self.predictions)
end

local function copyDepthScores(predictions)
    local result = {}
    if type(predictions) ~= "table" then
        return result
    end
    for actId, score in pairs(predictions) do
        local numberScore = tonumber(score)
        if not (numberScore and numberScore >= 0 and numberScore <= 1) then
            numberScore = DEFAULT_DEPTH_SCORE
        end
        result[tostring(actId)] = numberScore
    end
    return result
end

local function decodePayload(rawInfo)
    if type(rawInfo) ~= "string" or rawInfo == "" then return nil end
    return jsonDecode(rawInfo)
end

-- 一条服务端记录 -> 本地一天的数据。aiPopupRecInfo 原样保留服务端 payload 供打点回传。
local function buildPrediction(day, info)
    return {
        targetDate = tostring(day),
        depthScores = copyDepthScores(info.predictions),
        predictionId = info.prediction_id,
        strategy = info.strategy,
        aiPopupRecInfo = info,
    }
end

local function collectPredictions(data)
    local entries = {}
    local responseMap = type(data) == "table" and data.aiAutoPopInfo or nil
    if type(responseMap) ~= "table" then
        return entries
    end

    for day, rawInfo in pairs(responseMap) do
        local info = decodePayload(rawInfo)
        if type(info) == "table" then
            entries[#entries + 1] = buildPrediction(day, info)
        end
    end
    return entries
end

local function findPrediction(predictions, day)
    for _, prediction in ipairs(predictions or {}) do
        if prediction.targetDate == day then return prediction end
    end
end

local function trimPredictions(predictions)
    table.sort(predictions, function(left, right)
        return left.targetDate > right.targetDate
    end)
    while #predictions > MAX_PREDICTION_DAYS do
        table.remove(predictions)
    end
end

local function savePredictions(model, predictions)
    trimPredictions(predictions)
    model:setDataByKey("predictions", predictions, true)
    local latest = predictions[1]
    model:setDataByKey("predictionId", latest and latest.predictionId, false)
    model:setDataByKey("strategy", latest and latest.strategy, false)
end

-- 用一次响应整体替换本地预测数据。
function Model:assignPredictionData(data)
    if type(data) ~= "table" then return false end
    savePredictions(self, collectPredictions(data))
    return true
end

-- 按自然天合并推荐数据：同一天已有本地记录时不覆盖。
function Model:mergePredictionData(data)
    if type(data) ~= "table" then return false, false end

    local incoming = collectPredictions(data)
    local predictions = self:getPredictions() or {}
    local changed = false
    for _, prediction in ipairs(incoming) do
        if not findPrediction(predictions, prediction.targetDate) then
            predictions[#predictions + 1] = prediction
            changed = true
        end
    end

    if changed then
        savePredictions(self, predictions)
    end
    return true, changed
end

function Model:getPredictionId()
    return self:getDataByKey("predictionId")
end

function Model:getStrategy()
    return self:getDataByKey("strategy")
end

function Model:getLastFetchTime()
    return tonumber(self:getDataByKey("lastFetchTime", 0)) or 0
end

function Model:setLastFetchTime(timestamp)
    self:setDataByKey("lastFetchTime", tonumber(timestamp) or 0, true)
end

function Model:requestAiAutoPopInfo()
    return self.syncPlug:requestAiAutoPopInfo()
end

function Model:getPredictions()
    return self:getDataByKey("predictions", {})
end

-- day 是归属天（服务端 key，如 20705），字符串或数字都可以。
function Model:getDepthScoresByDate(day)
    if day == nil then return nil end
    local prediction = findPrediction(self:getPredictions(), tostring(day))
    return prediction and (prediction.depthScores or {})
end

function Model:getAiPopupRecInfoByDate(day)
    if day == nil then return nil end
    local prediction = findPrediction(self:getPredictions(), tostring(day))
    return prediction and prediction.aiPopupRecInfo
end

function Model:getActivityPriority(day, actId)
    local depthScores = self:getDepthScoresByDate(day)
    if not depthScores or actId == nil then
        return nil
    end
    return depthScores[tostring(actId)]
end

-- 返回 resolver 使用的归属天，和服务端 key 同为自然天编号。
function Model:getCurrentTargetDate(now)
    local currentDay = TimeKit:time2day(now or TimeKit:timeInSec())
    if currentDay == nil then return nil end
    return tostring(currentDay)
end

return Model
