local ActivityName = "GemMining"
local Meta = require'amf.feature.localactivity.gemmining.meta.Meta'
local LocalServer = class(ActivityName .. "LocalServer", AMFDataRef)

function LocalServer:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = ActivityName .. "LocalServer",
    }):as("db")
end

function LocalServer:__declare()
	self.actTime = nil 
	self.convert = nil 
	self.digOpRecordList = nil 
	self.doubleCollectBuffEndTime = nil 
	self.gemMaps = nil 
	self.guideIdSet = nil 
	self.initCollectNum = nil 
	self.livenessTag = nil 
	self.nowCollectNum = nil 
	self.nowMapId = nil 
	self.periodId = nil 
	self.score20BuffEndTime = nil 
	self.score50BuffEndTime = nil 
	self.localConfig = nil 
	self.collectionTipN = nil

	self.lastPassDay = nil
	self.tipTime = nil
	self.__localLoaded = nil 
	self.configMd5 = nil 
	self.info = nil 
	self.actPassLevel = nil 
	self.payTagIdToday = nil
	self.cachedActInfo = nil
end



function LocalServer:getConfigMd5()
    do return nil end
	return self:getDataByKey("configMd5")
end

function LocalServer:fromServer( serverData,skipSaveLocal )
	local parseConfig = function ( extra )
		if not extra then return end
		self:setValue("localConfig",extra)
		for k,v in pairs(extra) do
			if k == 'configMd5' then
				self:setValue("configMd5",v.serverMd5)
			end 
		end
	end
	for k,v in pairs(serverData) do
		if k == "extra" then
			parseConfig(table.deserialize(v))
		elseif k == "info" then 
			for _k,_v in pairs(v) do 
				self:setValue(_k,_v)
			end 
		else
			self:setValue(k,v)
		end
	end

	if not skipSaveLocal then
		self:flush()
	end

	local payTag = self:getDataByKey("payTagId",0)
	self:setDataByKey("payTagIdToday", payTag, true, true)
end


function LocalServer:getActBeginTime(  )
	if self.actTime then
		return tonumber(self.actTime.beginTime)
	end
	return 0
end

function LocalServer:getActMainBeginTime(  )
	if self.actTime then
		return tonumber(self.actTime.mainBeginTime)
	end
	return 0
end

function LocalServer:getActMainEndTime(  )
	if self.actTime then
		return tonumber(self.actTime.mainEndTime)
	end
	return 0
end

function LocalServer:getActEndTime(  )
	if self.actTime then
		return tonumber(self.actTime.endTime)
	end
	return 0
end

function LocalServer:isActInPre(  )

	if self.actTime then
		local now = TimeKit:timeInSec()
		local beginTime = self:getActBeginTime()
		local endTime = self:getActMainBeginTime()
		return now >= beginTime and now <= endTime
	end
end

function LocalServer:isActInMain(  )
	if self.actTime then
		local now = TimeKit:timeInSec()
		local beginTime = self:getActMainBeginTime()
		local endTime = self:getActMainEndTime()
		return now >= beginTime and now < endTime
	end
end
function LocalServer:isActInReward(  )
	if self.actTime then
		local now = TimeKit:timeInSec()
		local beginTime = self:getActMainEndTime()
		local endTime = self:getActEndTime()
		return now >= beginTime and now <= endTime
	end
end

function LocalServer:isInAct()
	if self.actTime then
		local now = TimeKit:timeInSec()
		local beginTime = self:getActBeginTime()
		local endTime = self:getActEndTime()
		return now >= beginTime and now <= endTime
	end

end




--------------------- 每次需要修改的函数 ---------------------
function LocalServer:setGuide( index )
	local guideInfo = self:getDataByKey("guideIdSet", {})
	table.insert(guideInfo, index)
	self:setDataByKey("guideIdSet", guideInfo, true)
end

function LocalServer:hasGuide( index )
	local guideInfo = self:getDataByKey("guideIdSet", {}, false)
	return table.find(guideInfo, function ( v )
		return v == index
	end)
end


--通过key获取data
function LocalServer:getDataByKey(key,defaultValue)
    local value = self:getValue(key) 
	if type(value) == "table" then 
		value = table.clone(value)
	end 
	if value then return value end 
	local config = self:getValue("localConfig")
	return config and config[key] or defaultValue
end

--清数据
function LocalServer:clearData()
    self:reset()
end

function LocalServer:resetForNewPeriod()
	local cachedActInfo = self:getCachedActInfo()
	self:reset()
	if cachedActInfo then
		self:setCachedActInfo(cachedActInfo)
	end
end

function LocalServer:clearDataByKey(key,needSave)
    self:setDataByKey(key,nil,needSave)
end

--更新单个数据
function LocalServer:setDataByKey(key,value,needSave,isNewkey)
    if not key then
        return
    end

    self:setValue(key,value,needSave)
end

function LocalServer:getCachedActInfo()
	local actInfo = self:getDataByKey("cachedActInfo")
	if type(actInfo) ~= "table" or next(actInfo) == nil then
		return nil
	end
	return actInfo
end

function LocalServer:setCachedActInfo(actInfo)
	if type(actInfo) ~= "table" or next(actInfo) == nil then
		return false
	end

	self:setDataByKey("cachedActInfo", table.clone(actInfo), true, true)
	return true
end

function LocalServer:clearCachedActInfo()
	self:clearDataByKey("cachedActInfo", true)
end

function LocalServer:isBaseDataEnabled()
	if not self.actTime then
        return false
    end

	-- if not self:getDataByKey("openActivity") then
	-- 	return false
	-- end

	if table.isEmpty(self.actTime) then
        return false
    end

	if not self:isInAct() then
		return false
	end

	return true
end

--判断数据是否准备就绪
function LocalServer:isDataEnabled()
	if not self.actTime then
        return false,1
    end

	if table.isEmpty(self.actTime) then
        return false,2
    end

	if not self:isActInMain() then
		return false,3
	end

	if not self.localConfig or table.isEmpty(self.localConfig) then
		return false,4
	end

    return true
end


function LocalServer:onPassDay()
	self:setDataByKey('lastPassDay',self:getDayFrom1970(),true,true)
	self:setDataByKey("tipTime",0,true,true)
end


function LocalServer:tryPassDay()
	local lastPassDay = self:getDataByKey('lastPassDay',0)
	if lastPassDay ~= self:getDayFrom1970() then
		self:onPassDay()
	end
end


-- 获取从1970.1.1开始服务器时间是第几天
function LocalServer:getDayFrom1970( time )
    local curDayStartTime = getDayStartTimeByTS(time or TimeKit:timeInSec())
    return math.ceil((curDayStartTime-8*60*60)/86400)
end


--------------------- 业务数据处理 ---------------------
function LocalServer:setMapBean(mapId,gemMapBean)
	if mapId == nil or not gemMapBean then return false end
	local gemMaps = self:getDataByKey("gemMaps", {})
	gemMaps[tostring(mapId)] = gemMapBean 
	self:setDataByKey("gemMaps",gemMaps)
	return true
end

function LocalServer:getMapIdList()
	local mapIdList = {}
	local mapIdSet = {}
	local gemMapMetas = self:getDataByKey("digGemMapMetaList", {})
	for _, mapMeta in pairs(gemMapMetas or {}) do
		local mapId = tonumber(mapMeta.mapId)
		if mapId and not mapIdSet[mapId] then
			mapIdSet[mapId] = true
			table.insert(mapIdList, mapId)
		end
	end

	if #mapIdList == 0 then
		local gemMaps = self:getDataByKey("gemMaps", {})
		for mapId in pairs(gemMaps or {}) do
			local numericMapId = tonumber(mapId)
			if numericMapId and not mapIdSet[numericMapId] then
				mapIdSet[numericMapId] = true
				table.insert(mapIdList, numericMapId)
			end
		end
	end

	table.sort(mapIdList)
	return mapIdList
end

function LocalServer:getMapNum()
	return #self:getMapIdList()
end

function LocalServer:getNowMapId()
	local gemMaps = self:getDataByKey("gemMaps", {})
	for _, mapId in ipairs(self:getMapIdList()) do
		local mapBean = gemMaps[tostring(mapId)]
		if mapBean and not mapBean.progressReward then
			return mapId
		end 
	end 
	return -1 
end

function LocalServer:hasClaimedAllMapRewards()
	local mapIdList = self:getMapIdList()
	if #mapIdList == 0 then return false end

	local gemMaps = self:getDataByKey("gemMaps", {})
	for _, mapId in ipairs(mapIdList) do
		local mapBean = gemMaps[tostring(mapId)]
		if not mapBean or not mapBean.progressReward then
			return false
		end
	end
	return true
end

function LocalServer:setMapRewardGet(mapId)
	local bean = self:getMapBeanById(tostring(mapId))
	if not bean then return false end
	bean.progressReward = true 
	self:setMapBean(tostring(mapId),bean)
	return true
end


function LocalServer:getMapBeanById(mapId)
	local gemMaps = self:getDataByKey("gemMaps", {})
	return gemMaps[tostring(mapId)] 
end

function LocalServer:getMapConfigById(mapId)
	local gemMapMetas = self:getDataByKey("digGemMapMetaList", {})
	for _,v in pairs(gemMapMetas) do
		if tonumber(v.mapId) == tonumber(mapId) then 
			return v 
		end 
	end 

end

function LocalServer:getNowMap()
	local nowMapId = self:getNowMapId()
	return self:getMapBeanById(nowMapId)
	
end

function LocalServer:getBuffEndTime()
	local time = math.floor(tonumber(self:getDataByKey("doubleCollectBuffEndTime", 0)) / 1000)
	return time
end 

function LocalServer:addBuffEndTime(mm)
	local time = math.max(self:getBuffEndTime(),TimeKit:timeInSec())
	time = time + mm * 60
	time = tostring(time * 1000)
	self:setDataByKey("doubleCollectBuffEndTime",time)
end


--分数buff加成
function LocalServer:get20BuffEndTime()
    local buffEndTime = self:getDataByKey('score20BuffEndTime', 0)
    if buffEndTime then
        return math.floor(tonumber(buffEndTime) / 1000)
    end
    return 0
end

function LocalServer:add20BuffEndTime(mm)
	local time = math.max(self:get20BuffEndTime(),TimeKit:timeInSec())
	time = time + mm * 60
	time = tostring(time * 1000)
	self:setDataByKey("score20BuffEndTime",time)
end

function LocalServer:get50BuffEndTime()
    local buffEndTime = self:getDataByKey('score50BuffEndTime', 0)
    if buffEndTime then
        return math.floor(tonumber(buffEndTime) / 1000)
    end
    return 0
end

function LocalServer:add50BuffEndTime(mm)
	local time = math.max(self:get50BuffEndTime(),TimeKit:timeInSec())
	time = time + mm * 60
	time = tostring(time * 1000)
	self:setDataByKey("score50BuffEndTime",time)
end




function LocalServer:getMapGemNum(mapId)
	local mapBean = self:getMapBeanById(mapId)
	if not mapBean then return 0,0 end
	local num = 0 
	local allNum = 0
	for _,gemBean in pairs(mapBean.pointMap or {}) do
		if gemBean.open then num = num + 1 end 
		allNum = allNum + 1 
	end 
	return num,allNum
end


function LocalServer:getNowMapLastBlock()
	local id = self:getNowMapId() 
	if not id or id == -1 then return 0 end 
	local mapBean = self:getMapBeanById(id)
	local stoneList = {}
    local cellStatus2 = mapBean.cellStatus2
    for k,v in pairs(cellStatus2) do 
        local row = tonumber(k) 
        local list = string.split(v,",")
		for id = 0,#list do 
			list[id] = list[id + 1 ]
		end
		stoneList[row] = list 
    end 
	local num = 0 
	for rowB,v in pairs(stoneList) do 
		for columnB,block  in pairs(v) do 
			if block == "0" then 
				num = num + 1 
			end 
		end 
	end 
	return num 
	
end


function LocalServer:setGemOpenStatsLocal(mapBean,rowClick,columnClick) --mock数据才调这个，正常跟后端通信
    local cellStatus2 = mapBean.cellStatus2
	local stoneList = {}
    for k,v in pairs(cellStatus2) do 
        local row = tonumber(k) - 1
        local list = string.split(v,",")
		for id = 0,#list do 
			list[id] = list[id + 1 ]
		end
		stoneList[row] = list 
    end 
	local hasClickGem = false 
	local hasClickSuperGem = false 
	local isOpenSuper = false 
	local hasAllOpen = true 
	for _,gemBean in pairs(mapBean.pointMap ) do 
		local gemId = gemBean.gemId 
		local row = gemBean.x 
		local column = gemBean.y 
		local gemConfig = Meta:getGemConfig(gemId)
		local oldOpen = gemBean.open 
		gemBean.open = true 

		for k,v in pairs(gemConfig.tapListBase) do
			local rowB =  v.row + row
			local columnB = v.column + column 
			if rowB == rowClick and columnClick == columnB then 
				hasClickGem = true
				if gemBean.superGem then 
					hasClickSuperGem = true 
				end  
			end 
			if stoneList[rowB][columnB] == "0" then 
				gemBean.open = false 
			end 
		end 
		if not oldOpen and gemBean.open and gemBean.superGem then 
			isOpenSuper = true 
		end 
		hasAllOpen = hasAllOpen and gemBean.open
	end 
	if hasClickGem then 
		local list = self:getDataByKey("digOpRecordList",{})
		table.insert(list,{x = rowClick,y = columnClick})
        self:setDataByKey("digOpRecordList",list)
	else 
        self:setDataByKey("digOpRecordList",{})
	end 

	return mapBean,isOpenSuper,hasAllOpen,hasClickSuperGem,hasClickGem
end

function LocalServer:delCollection(num)
	local nowCollectNum = self:getDataByKey("nowCollectNum") or 0 
	nowCollectNum = nowCollectNum - num  
	self:setDataByKey("nowCollectNum",nowCollectNum)
end

function LocalServer:addCollectNum(num)
	local nowCollectNum = self:getDataByKey("nowCollectNum") or 0 
	nowCollectNum = nowCollectNum + num  
	self:setDataByKey("nowCollectNum",nowCollectNum)
end



return LocalServer
