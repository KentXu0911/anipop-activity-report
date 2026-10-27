local BaseFeatureModel = require "amf.middleware.activity.base.BaseFeatureModel"
local Model = class("CoinPromotionsModel", BaseFeatureModel)

function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "CoinPromotionsModel"
    }):as("db")
end

function Model:_getConstPath()
	return "amf.feature.localactivity.coinpromotions.config.CoinPromotionsConst"
end 

-- Model
function Model:__declare()
    self:_initLocalData()
    self:_initLocalConfig()
    self:_initLocalKey()
end

function Model:_initLocalData()
    self.userInfo = {}
end

function Model:_initLocalConfig()
    self.localConfig = {}
end

function Model:_initLocalKey()
    self._localCache = {}
    self.showCountDownTip = nil
	self.showPanel = nil
	self.setOldProgressValue3 = nil
	self.showRedPocket = nil
	self.showBanner = nil
	self.showGift = nil
	self.finishAct = nil
	self.showTipTime = nil
	self.lastProgress = nil
	self.LastHours = nil
	self.extraRewardPop = nil
	self.showMainPanel = nil
	self.lastOpenNode = nil
	self.mainPanel_stage4 = nil
end

function Model:setLocalCache(key, value)
    self:setValue("_localCache."..key, value)
end

function Model:getLocalCache(key)
    return self:getValue("_localCache."..key)
end

function Model:fromServer( data,skipSaveLocal )
    -- printx(42,"awijoihjoswopwd",tts(data),debug.traceback())
    for k,v in pairs(data) do
		self:setValue(k, v)
	end

	if not skipSaveLocal then
		self:flush()
	end
end

--判断数据是否准备就绪
function Model:isDataEnabled()
	if not self:getValue("userInfo") then
        return false
    end
    if table.isEmpty(self:getValue("userInfo")) then
        return false
    end
    if not self:getValue("localConfig") then
        return false
    end
    if table.isEmpty(self:getValue("localConfig")) then
        return false
    end
    return true
end

function Model:getActBeginTime(  )
    return self:getBeginTime()
end

function Model:getActMainBeginTime(  )
    return self:getMainBeginTime()
end

function Model:getActMainEndTime(  )
    return self:getMainEndTime()
end

function Model:getActEndTime(  )
    return self:getEndTime()
end

function Model:isActInPre(  )
    return self:isInPreheatTime()
end

function Model:isInMainTime()
    local nowTime = TimeKit:timeInSec()
    printx(41,"nowTime",nowTime,TimeKit:tryConvertMsToSec(self:getMainBeginTime()),TimeKit:tryConvertMsToSec(self:getMainEndTime()))
    return nowTime > TimeKit:tryConvertMsToSec(self:getMainBeginTime()) and nowTime <= TimeKit:tryConvertMsToSec(self:getMainEndTime())
end

function Model:isActInMain(  )
    return self:isInMainTime()
end

function Model:isActInReward(  )
    return self:isInRewardTime()
end

function Model:setGuide( index )
	local guideInfo = self:getDataByKey("guideIds", {})
	table.insert(guideInfo, index)
	self:setDataByKey("guideIds", guideInfo, true)
end

function Model:hasGuide( index )
	local guideInfo = self:getDataByKey("guideIds", {}, false)
	return table.find(guideInfo, function ( v )
		return v == index
	end)
end

function Model:_getLocalKey(key)
    return key
end
    
--------------------- 业务数据处理 ---------------------
function Model:passDayClear()
	--存储
	self:clearData()
end

function Model:isBaseDataEnabled()
	return self:isDataEnabled() and self:isInMainTime()
end

--------------------- 业务数据处理 ---------------------
function Model:clearAll()
	self:clearData()
end

--分数buff加成结束时间
function Model:getBuffEndTime()
    local buffEndTime = self:getDataByKey('buffExpireTime', 0)
    if buffEndTime then
        return math.floor(tonumber(buffEndTime or 0 ) / 1000)
    end
    return 0
end 

function Model:addBuffEndTime(num)
    local buffEndTime = tonumber(self:getDataByKey('buffExpireTime', TimeKit:timeInSec() * 1000))
	buffEndTime = math.max(TimeKit:timeInSec() * 1000,buffEndTime)
	self:setDataByKey("buffExpireTime",buffEndTime + num * 60 * 1000,true)
end


function Model:setLocalPoint()
	self:saveFlagToLocalByKeyInt("lastOpenNode", nil, self:getProgressPoint())
end

function Model:getOldPoint()
	return self:getFlagFromLocalByKeyInt("lastOpenNode", nil, nil, -1)
end

function Model:getGearMeta(gearId)
	local gearId = gearId or self:getDataByKey("configGearId")
	local gearList = self:getConfigByKey("gearList")
	if not gearList then
		return {}
	end
	for k,v in pairs(gearList) do
		if v.gearId == gearId then 
			return v
		end 
	end
	return gearList[1] or {}
end

function Model:getSignMeta(gearId)
	local gearId = gearId or self:getDataByKey("configGearId")
	local signList = self:getConfigByKey("signList")
	for k,v in pairs(signList) do
		local t = string.split(v.gearIdRange.rawValue,"~")
		local a = tonumber(t[1])
		local b = tonumber(t[2] or a)
		if a <= gearId and gearId <= b then 
			return v
		end 
	end
	return signList[1] or {}
end

function Model:onBuyPayTags()
	return tonumber(self:getConfigByKey("onBuyPayTags"))
end

function Model:getGoodsIdMetaList()
	return self:getConfigByKey("goodsIdMetaList")
end


function Model:addConsumeNum(addNUm)
	local nowNum = self:getNowConsume()
	self:setDataByKey("coinConsumeNum",nowNum + addNUm)
end

function Model:getNowConsume()
	return self:getDataByKey("coinConsumeNum",0)
end
function Model:getProgressPoint(nowValue)
	local gearId = self:getDataByKey("configGearId")
	local gearMeta = self:getGearMeta(gearId)
	local point = 0 
	local nowValue = nowValue or self:getNowConsume()
	if not gearMeta.targetList then
		return 0
	end
	for id,v in ipairs(gearMeta.targetList) do 
		if v <= nowValue then 
			point = id
		end 
	end 
	return point
end

function Model:getNextProgressPoint(nowValue)--下一个要到达的目标
	local gearId = self:getDataByKey("configGearId")
	local gearMeta = self:getGearMeta(gearId)
	local point = 0 
	local nowValue = nowValue or self:getNowConsume()
	for id = #gearMeta.targetList, 1, -1 do
		local v = gearMeta.targetList[id]
		if v > nowValue then
			point = id
		end
	end	
	return point
end

function Model:getBefProgressPoint(nowValue)--下一个要到达的目标
	local gearId = self:getDataByKey("configGearId")
	local gearMeta = self:getGearMeta(gearId)
	local point = 0 
	local nowValue = nowValue or self:getNowConsume()
	for id,v in ipairs(gearMeta.targetList) do 
		if v <= nowValue then 
			point = id
		end 
	end 
	return point
end

function Model:getSignStartTime()
	local mgr = _G.amfBean("CoinPromotionsMgr")
	
    local actInfo = mgr:getActInfo()
    if actInfo and actInfo.extra then
        local extra = table.deserialize(actInfo.extra)
        local stTime = tonumber(extra.signPhaseStartTime or 0 ) / 1000
		return stTime
    end

	return tonumber(self:getDataByKey("signPhaseStartTime") or 0)/1000
end

function Model:isInSignState()
	local stTime = self:getSignStartTime()
	return stTime > 0 and TimeKit:timeInSec() >= stTime
end

function Model:getSignDay()
	local stTime = getDayStartTimeByTS(self:getSignStartTime())
	local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())
	if stTime > nowTime then 
		return 0
	end 
	
	return math.max(tonumber(self:getDataByKey("signPhaseCanSignNum") or 1),1)
	
end

function Model:hasSignChance()
	local day = self:getSignDay()
	local signStatus = self:getDataByKey("signStatus",{})
	for id = 1,day do 
		if not signStatus[id] then return true end 
	end 
end

function Model:hasSignDay(dayId)
	local signStatus = self:getDataByKey("signStatus",{})
	return signStatus[dayId] 
end


function Model:getPointNeed(pointId)
	local gearId = self:getDataByKey("configGearId")
	local gearMeta = self:getGearMeta(gearId)
	if gearMeta == {} then
		return 0
	end
	if not gearMeta.targetList then
		return 0
	end
	return tonumber(gearMeta.targetList[pointId] or 0 )
end

function Model:getPointGoldNum(pointId)
	local gearId = self:getDataByKey("configGearId")
	local gearMeta = self:getGearMeta(gearId)
	if pointId <= 2 then 
		return tonumber(gearMeta.rewardCoinsList[pointId] or 0 )
	else
		local rawValue = gearMeta.lastRewardShowRange.rawValue
		local t = string.split(rawValue,"~")
		local a = tonumber(t[1])
		local b = tonumber(t[2] or a) 
		return a,b
	end 
end

function Model:getSignReward(dayId)
	local meta = self:getSignMeta()
	if dayId == 1 then 
		return meta.day1Rewards.list
	elseif dayId == 2 then 
		return meta.day2Rewards.list
	else 
		return meta.day3Rewards.list
	end 
end

function Model:getGiftGoodsId()
	local gearId = self:getDataByKey("configGearId")
	local gearMeta = self:getGearMeta(gearId)
	return tonumber(gearMeta.rewardPkgId or 1)
end

function Model:getRewardStatus()
	local t = self:getDataByKey("rewardStatus") or {}
	for id = 1,3 do 
		if self:getPointNeed(id) <= 0 then 
			t[id] = true 
		end 
	end 
	return t 
end
function Model:getSignStatus()
	return self:getDataByKey("signStatus") or {}
end

function Model:getSignRewards()
	local meta = self:getSignMeta()
	return {meta.day1Rewards.list,meta.day2Rewards.list,meta.day3Rewards.list}
end



function Model:getSignDayReward(day)
	local list = self:getSignRewards()
	return list[day] 
end

function Model:hasBuyGift()
	return self:getDataByKey("boughtPkg",false)
end

function Model:setBuyGift()
	return self:setDataByKey("boughtPkg",true)
end
function Model:getCurrRoundId()
	return self:getDataByKey("roundId")
end

return Model