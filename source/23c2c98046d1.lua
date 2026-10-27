local BaseFeatureModel = require "amf.middleware.activity.base.BaseFeatureModel"
local Model = class("BlockModel", BaseFeatureModel)

function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "BlockModel"
    }):as("db")
end

function Model:_getConstPath()
	return "amf.feature.localactivity.block.const.BlockConst"
end

function Model:__declare()
    self.userInfo = {}
    self.localConfig = {}
    self.clientMd5 = ""
    self.timeInfo = {}
    self._localCache = {}
end

function Model:setLocalCache(key, value)
    self:setValue("_localCache."..key, value)
end

function Model:getLocalCache(key)
    return self:getValue("_localCache."..key)
end

function Model:fromServer(data)
    for k, v in pairs(data) do
        self:setValue(k, v)
    end

    -- printx(36, tts(self.userInfo), tts(self.localConfig))
end

function Model:getConfigByKey(key, default)
    local ret = BaseFeatureModel.getConfigByKey(self, key, default)
    return table.clone(ret)
end

function Model:clearData()
    local introShow = self:getLocalCache(self:getConst().ACT_INTRO_KEY)
    self:reset()
    if introShow then
        self:setLocalCache(self:getConst().ACT_INTRO_KEY, true)
    end
end

function Model:setGuide( index )
	local guideInfo = self:getDataByKey("guideIdSet", {})
	table.insert(guideInfo, index)
	self:setDataByKey("guideIdSet", guideInfo)
end

function Model:hasGuide( index )
	local guideInfo = self:getDataByKey("guideIdSet", {}, false)
	return table.find(guideInfo, function ( v )
		return v == index
	end)
end

function Model:getBeginTime()
    local key = self:_getTimeKey("beginTime")
    return math.floor((self:getValue(key) or 0)/1000)
end

function Model:getMainBeginTime()
    local key = self:_getTimeKey("mainBeginTime")
    return math.floor((self:getValue(key) or 0)/1000)
end

function Model:getEndTime()
    local key = self:_getTimeKey("endTime")
    return math.floor((self:getValue(key) or 0)/1000)
end

function Model:getMainEndTime()
    local key = self:_getTimeKey("mainEndTime")
    return math.floor((self:getValue(key) or 0)/1000)
end

function Model:updateTimeInfo(time)
    self:setValue("timeInfo", time)
end

function Model:isDataEnabled()
    local localConfig = self:getValue("localConfig")
    if not localConfig or table.isEmpty(localConfig) then
        return false
    end

    local userInfo = self:getValue("userInfo")
	if not userInfo or table.isEmpty(userInfo) then
        return false
    end

    return true
end

function Model:getClientMd5()
    return self:getValue("clientMd5") or ""
end

function Model:getPeriodId()
    return self:getDataByKey("periodId", 0)
end

function Model:setPeriodId(id)
    self:setDataByKey("periodId", id)
end

function Model:getMapData()
    return self:getDataByKey("blockMapData", {})
end

function Model:setMapData(data)
    self:setDataByKey("blockMapData", data)
end

function Model:getMapId()
    return self:getDataByKey("blockMapData.mapId", 0)
end

function Model:getCellStatusMap()
    return self:getDataByKey("blockMapData.cellStatusMap", {})
end

function Model:setCellStatusMap(data)
    self:setDataByKey("blockMapData.cellStatusMap", data)
end

function Model:getBlockIdList()
    return self:getDataByKey("blockMapData.blockIdList", {})
end

function Model:setBlockIdList(list)
    self:setDataByKey("blockMapData.blockIdList", list)
end

function Model:getScore()
    if not self:isDataEnabled() then return end
    local mapId = self:getMapId()
    local meta = self:getConfigByKey("blockMapMetaList", {})
    local score = self:getDataByKey("blockMapData.eliminateScore", 0)
    if not self:checkInInfinite()then
        for _, v in pairs(meta) do
            if v.mapId == mapId then
                return score, v.progressScore
            end
        end
    else
        local lastCost, lastRound = 0, 0
        local endLessRound = self:getEndLessRound()
        for _, v in ipairs(meta) do
            if v.mapId == mapId and v.endLess then
                if v.endLessRound == endLessRound then
                    return score, v.progressScore
                elseif v.endLessRound < endLessRound then
                    score = score - v.progressScore
                    lastCost = v.progressScore
                    lastRound = v.endLessRound
                end
            end
        end
        if lastCost > 0 then
            return score - (endLessRound - lastRound - 1) * lastCost, lastCost
        end
    end

    return 0, 0
end

function Model:addScore(addNum)
    local score = self:getDataByKey("blockMapData.eliminateScore", 0)
    score = score + addNum
    self:setDataByKey("blockMapData.eliminateScore", score)
end

function Model:getTotalScore()
    return self:getDataByKey("blockMapData.eliminateScore", 0)
end

function Model:getPutBlockNum()
    return self:getDataByKey("blockMapData.putBlockNum", 0)
end

function Model:addPutBlockNum(num)
    self:setDataByKey("blockMapData.putBlockNum", self:getPutBlockNum() + num)
end

function Model:getEndLessRound()
    return self:getDataByKey("blockMapData.endLessRound", 0)
end

function Model:setEndLessRound(round)
    self:setDataByKey("blockMapData.endLessRound", round)
end

function Model:addScoreBuff(type, minute)
    local key = type == 1 and "score20BuffEndTime" or "score50BuffEndTime"
    local time = tonumber(self:getDataByKey(key, 0))
    time = math.max(TimeKit:timeInMillis(), time)
    time = time + minute * 60000
    self:setDataByKey(key, time)
end

function Model:getScoreBuff(type)
    local key = type == 1 and "score20BuffEndTime" or "score50BuffEndTime"
    return math.floor(tonumber(self:getDataByKey(key) or 0) / 1000)
end

function Model:setScore20BuffEndTime(time)
    self:setDataByKey("score20BuffEndTime", time)
end

function Model:setScore50BuffEndTime(time)
    self:setDataByKey("score50BuffEndTime", time)
end

function Model:getCollectionNum()
    return self:getDataByKey("nowCollectNum", 0)
end

function Model:addCollectionNum(num)
    self:setDataByKey("nowCollectNum", self:getCollectionNum() + num)
end

function Model:getHistoryMaxScore()
    return self:getDataByKey("historyMaxScore", 0)
end

function Model:getConvert()
    return self:getCollectionNum() > 0 and not self:getDataByKey("convert", false)
end

function Model:setConvert()
    self:setDataByKey("convert", true)
end

function Model:canGetRewards()
    local progress, maxProgress = self:getScore()
    if progress >= maxProgress then return true end

    if self:checkInInfinite() and not self:getFinalReward() then
        return true
    end

    return false
end

function Model:checkInInfinite()
    return self:getMapId() > self:getConst().maxNormalMapId
end

function Model:getMapMeta(mapId, endLessRound)
    mapId = mapId or self:getMapId()
    endLessRound = endLessRound or self:getEndLessRound()
    local meta = self:getConfigByKey("blockMapMetaList", {})
    for _, v in pairs(meta) do
        if v.mapId == mapId then
            if not v.endLess then
                return v
            elseif v.endLessRound == endLessRound then
                return v
            end
        end
    end
    return meta[#meta]
end

function Model:getFinalRewards()
    return self:getConfigByKey("finalRewardItemList", {})
end

function Model:getProgressRewards(mapId, bFullLevel)
    mapId = mapId or self:getMapId()
    local endLessRound = self:getEndLessRound()
    if endLessRound > 0 then
        local mapData = self:getMapData()
        return mapData.endLessRewardList
    end
    local meta = self:getMapMeta(mapId, endLessRound)
    if not meta then return {} end
    return bFullLevel and meta.fullRewardItemList or meta.noFullRewardItemList
end

function Model:passDayRefreshData()
    self:setLocalCache("yinliuCount",0) --第一次不需要检查，直接给过吧
    self:setLocalCache("yinliuTimes",0)
end

function Model:onYinliuPopout()
    local yinliuTimes = self:getLocalCache("yinliuTimes") or 0
    self:setLocalCache("yinliuCount",0) 
    self:setLocalCache("yinliuTimes",yinliuTimes + 1)
end

function Model:getFinalReward()
    return self:getDataByKey("finalReward", false)
end

function Model:setFinalReward()
    self:setDataByKey("finalReward", true)
end

function Model:saveAdjustInfo(delegate)
    -- printx(29,"saveAdjustInfo",tts(delegate))
    if delegate.putBlockNum then
        self:setDataByKey("blockMapData.putBlockNum", delegate.putBlockNum)
    end

    if delegate.createColorStep then
        self:setDataByKey("blockMapData.createColorStep", delegate.createColorStep)
    end

    if delegate.colorAdjustNum then
        self:setDataByKey("blockMapData.colorAdjustNum", delegate.colorAdjustNum)
    end

    if delegate.shapeAdjustNum then
        self:setDataByKey("blockMapData.shapeAdjustNum", delegate.shapeAdjustNum)
    end

    if delegate.randomSeed then
        self:setDataByKey("blockMapData.randomSeed", delegate.randomSeed)
    end
end

return Model