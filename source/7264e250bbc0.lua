local Meta = require 'amf.feature.localactivity.supermagicbird.config.SuperMagicBirdConst'
local BaseFeatureModel = require"amf.middleware.activity.base.BaseFeatureModel"

local ACT_NAME = "supermagicbirdmoney2025"
local LOCAL_PATH = 'amf.feature.localactivity.'..string.lower( ACT_NAME )
local ServerData = class("supermagicbird_data",BaseFeatureModel)

local testMode = false

local log = _G.SmbLog or doNothing

local smbDataMgr

function ServerData:_getConstPath()
    return LOCAL_PATH..'.config.SuperMagicBirdConst'
end

function ServerData:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "supermagicbirdmoney_data"
    }):as("db")
end

-- function ServerData:create( key )
-- 	local serverData = ServerData.new( key )
-- 	return serverData
-- end

function ServerData:__declare()
    self:_initLocalData()
    self:_initLocalConfig()
    self:_initLocalKey()
end

function ServerData:_initLocalData()
	self.userData = nil
	-- self.mainBeginTime = nil
	-- self.beginTime = nil
	-- self.endTime = nil
	-- self.mainEndTime = nil
	-- self.eInfo = nil
	-- self.costConfig = nil
	-- self.curCost = nil
	-- self.usePropInfos = nil
	-- self.costConfig2025 = nil
	-- self.costList = nil
end

function ServerData:_initLocalConfig()
	-- self.localConfig = nil
end

function ServerData:_initLocalKey()
	
end

-- function ServerData:passDayClear( )
-- 	--跨天
-- end

-- function ServerData:writeToLocal()
-- 	self:writeAll()
-- end

-- function ServerData:fromSever(data)
-- 	--从活动info 发来的信息拆分出 data 和 localConfig
-- 	--userData是后端数据，self.data.xxx可以自行添加不会覆盖删除
-- 	-- self.data = table.clone(data)
-- 	if not table.isEmpty(data) then
--     	--清空数据
-- 	    for k, v in pairs(data) do
-- 			if self:isDeclared(k) then
-- 				self:setValue(k, v)
-- 			end
-- 	    end
-- 	end
-- 	self:updatePropWorth()
-- end

-- function ServerData:fromLocal()
-- 	--从本地读取数据
-- 	LocalServerBase.fromLocal( self )

-- 	self:updatePropWorth()
-- end

function ServerData:fromActInfo(data)
	if not table.isEmpty(data) then
	    for k, v in pairs(data) do
			self:setSmbContextDataByKey(k, v, false)
	    end
		self:saveSmbContextData()
	end
	self:updatePropWorth()
end

-- function ServerData:getUserData( )
-- 	return self.data
-- end

function ServerData:init()
	BaseFeatureModel.init(self)

    require "amf.feature.localactivity.supermagicbird.model.SmbDataManager"
    smbDataMgr = SmbDataManager.getInstance()

	self:updatePropWorth()
end

function ServerData:getSmbContextDataByKey(key)
    return smbDataMgr:getDataByKey(key)
end

function ServerData:setSmbContextDataByKey(key, value, needSave)
    return smbDataMgr:setDataByKey(key, value, needSave)
end

function ServerData:saveSmbContextData()
    return smbDataMgr:saveData()
end

--获取data 设置data值  数字类型的增加
function ServerData:getDataByKey( key ,default)
	-- local value = self:getValue(key)
    -- if value then
    --     return value
    -- end

    -- return default

    local value = self:getSmbContextDataByKey(key)
    if value then
        return value
    end

    return default
end

function ServerData:setDataByKey(key,value, needSave)
    -- if not key then
    --     return
    -- end
    -- self:setValue(key,value)

    self:setSmbContextDataByKey(key, value, needSave)
end

function ServerData:getConfigByKey(key)
    return smbDataMgr:getConfigByKey(key)
end

function ServerData:getCostConfig()
	return self:getConfigByKey('costConfig')
end

function ServerData:getCostConfig2025()
	return self:getConfigByKey('costConfig2025')
end

------E相关
function ServerData:updatePropWorth()

	-- local costConfig = self:getDataByKey("costConfig")
	local costConfig = self:getCostConfig()
	if costConfig then
		local Map = {
			PropWorthMap = {},
			VideoPropWorthMap = {}
		}
		for _, v in ipairs(costConfig.normalCostMetas or {}) do
			Map.PropWorthMap[v.itemId] = v.cost
		end
		for _, v in ipairs(costConfig.videoCostMetas or {}) do
			Map.VideoPropWorthMap[v.itemId] = v.cost
		end
		local MXPropWorth = require "ubf.UBFGamePlayScene.logics.mess.MXPropWorth"
		MXPropWorth.Map = Map
	end

	-- local costConfigV2 = self:getDataByKey("costConfig2025")
	local costConfigV2 = self:getCostConfig2025()
	if costConfigV2 then
		local MXPropWorth = require "ubf.UBFGamePlayScene.logics.mess.RYPropWorth"
		MXPropWorth.Map = costConfigV2
		MXPropWorth.InitMap = nil
	end
end


function ServerData:getENum(bShowLog, levelState)
	--获取E值
	local eInfo = self:getDataByKey('eInfo')
	if eInfo == nil then 
		return false, {e=0, x=0, y=0}
	end

	local function checkHasTimeKey( costLogs )
		local bHasTimeKey = true
		for i,v in ipairs(costLogs) do
			if v.time == nil then
				bHasTimeKey = false
				break
			end
		end
		return bHasTimeKey
	end

	if not checkHasTimeKey(eInfo.costLogs) or not checkHasTimeKey(eInfo.extraRewardLogs) then 
		return false, {e=0, x=0, y=0}
	end

	local getPlayLevelNum = 100 --取100次打关数据

	local function sortFunc( a,b )
		return tonumber(a.time) > tonumber(b.time)
	end

	local copyCostLogs = {}
	if levelState == Meta.LevelStateList.kLevelLibrary then
		copyCostLogs = table.clone(eInfo.fullColorStarLogs)
	elseif levelState == Meta.LevelStateList.kRefreshStar then
		copyCostLogs = table.clone(eInfo.farmStarLogs)
	else
		copyCostLogs = table.clone(eInfo.costLogs)
	end
	table.sort( copyCostLogs, sortFunc )

	local newCostLogs = {}
	for i,v in ipairs(copyCostLogs) do
		if #newCostLogs < getPlayLevelNum then
			table.insert( newCostLogs, table.clone(v) )
		end
	end

	--找出第一关的时间，么么狐领取时间只要大于startTime 就加入判断
	local startTime = TimeKit:timeInSec()*1000
	if #newCostLogs > 0 then
 		startTime = tonumber(newCostLogs[#newCostLogs].time)
	end

	local newExtraRewardLogs = {}
	for i,v in ipairs(eInfo.extraRewardLogs) do
		if tonumber(v.time) >= startTime then
			table.insert( newExtraRewardLogs, table.clone(v) )
		end
	end

	--区分有鸟无鸟
	local birdCostLogs = {}
	local noBirdCostLogds = {}
	local allCost = 0
	local birdCost = 0
	local noBirdCost = 0

	for i, v in ipairs(newCostLogs) do
		if v.bird then
			table.insert(birdCostLogs, v)

			birdCost = birdCost + v.cost
		else
			table.insert(noBirdCostLogds, v)

			noBirdCost = noBirdCost + v.cost
		end

		allCost = allCost + v.cost
	end

	local actGetNum = 0 
	for i, v in ipairs(newExtraRewardLogs) do
		actGetNum = actGetNum + v.num
	end

	local birdLevelNum = #birdCostLogs
	local noBirdLevelNum = #noBirdCostLogds
	if noBirdLevelNum == 0 then noBirdLevelNum = 1 end
	if birdLevelNum == 0 then birdLevelNum = 1 end

	local x = noBirdCost / noBirdLevelNum
	local y = ( birdCost-actGetNum ) / birdLevelNum
	local e = y - x

	local bEnough = false

	if e > 0 then
		bEnough = true
	else
		bEnough = false
	end
	
	if bShowLog then
		log("*******getENum***********")
		
		log("eInfo", eInfo)
		log("allCost", allCost)
		log("birdCost", birdCost)
		log("noBirdCost", noBirdCost)
		log("noBirdLevelNum", noBirdLevelNum, noBirdCostLogds)
		log("birdLevelNum", birdLevelNum, birdCostLogs)
		log("actGetNum", actGetNum)
		log("x", x)
		log("y", y)
		log("e", e)

		log("*******getENum end***********", bEnough)
	end

	return bEnough, { e=e, x=x, y=y }
end

function ServerData:passLevelAddGoldNum( levelId, cost, bActive, bPassLevel, levelState )
	--过关添加付费信息
	local eInfo = self:getDataByKey('eInfo')
	if eInfo == nil then
		return
	end

	local addInfo = {
		level = levelId,
		bird = bActive,
		pass = bPassLevel,
		cost = cost,
		time = ''..TimeKit:timeInSec()*1000,
	}

	if levelState == Meta.LevelStateList.kLevelLibrary then
		table.insert( eInfo.fullColorStarLogs, addInfo )
	elseif levelState == Meta.LevelStateList.kRefreshStar then
		table.insert( eInfo.farmStarLogs, addInfo )
	else
		table.insert( eInfo.costLogs, addInfo )
	end

	-- log("passLevelAddGoldNum eInfo",eInfo)

	self:setDataByKey('eInfo', eInfo)
end

function ServerData:subActAddGold( from, num )
	--子活动获得风车币
	local eInfo = self:getDataByKey('eInfo')
	if eInfo == nil then
		return
	end

	local curTopLevel = _G.amfBean("LevelAreaManager"):getTopLevelId()
	local addInfo = {
		level = curTopLevel,
		num = num,
		from = from or Meta.extraRewardLogForm.kNone,
		time = ''..TimeKit:timeInSec()*1000,
	}
	table.insert( eInfo.extraRewardLogs, addInfo )

	self:setDataByKey('eInfo', eInfo)
end

function ServerData:updateEInfo( eInfo )
	self:setDataByKey('eInfo',eInfo)
end
----

function ServerData:passLevelAddGoldNumV2( levelId, cost, bActive, bPassLevel, levelState )
	--过关添加付费信息
	local usePropInfos = self:getDataByKey('usePropInfos')
	if usePropInfos == nil then
		return
	end

	local addInfo = {
		levelId = levelId,
		cost = cost,
		time = '' .. TimeKit:time(),
	}

	table.insert( usePropInfos, addInfo )

	self:setDataByKey('usePropInfos', usePropInfos)
end


function ServerData:get80PercentNum( bShowLog, topLevelId )
	--取出最近的100关消耗，并排序，找出80%位置，向上取整
	local getLevelCostNum = 100
	local usePropInfos = self:getDataByKey('usePropInfos')

	if bShowLog then
		log("***超鸟连胜fuuu判断V2*** *******get80PercentNum before***********")
		log("usePropInfos",usePropInfos)
		log("topLevelId",topLevelId)
		log("***超鸟连胜fuuu判断V2*** *******get80PercentNum before end***********")
	end
	
	if usePropInfos == nil then
		return 0
	end

	local curTime = TimeKit:timeInSec()

	--排序，取出最近100个来
	local function sortTimeFunc( a,b )
		return tonumber(a.time) > tonumber(b.time)
	end
	table.sort( usePropInfos, sortTimeFunc )

	local costList = {}
	for i=1, getLevelCostNum do
		if usePropInfos[i] and usePropInfos[i].levelId < topLevelId then
			table.insert( costList, table.clone(usePropInfos[i]))
		end
	end

	--取出来的付费排序
	local function sortTimeFunc( a,b )
		return tonumber(a.cost) < tonumber(b.cost)
	end
	table.sort( costList, sortTimeFunc )

	local listLength = #costList
	local percent80Index = math.ceil( listLength*0.8 )

	local percent80Cost = 0
	if costList[percent80Index] then
		percent80Cost = costList[percent80Index].cost
	end

	if bShowLog then
		log("***超鸟连胜fuuu判断V2*** *******get80PercentNum***********")
		
		log("***超鸟连胜fuuu判断V2*** usePropInfos", usePropInfos)
		log("***超鸟连胜fuuu判断V2*** costList", costList)
		log("***超鸟连胜fuuu判断V2*** listLength", listLength)
		log("***超鸟连胜fuuu判断V2*** percent80Index", percent80Index)
		log("***超鸟连胜fuuu判断V2*** percent80Cost", percent80Cost)

		log("***超鸟连胜fuuu判断V2*** *******get80PercentNum end***********", percent80Cost)
	end

	return percent80Cost
end


function ServerData:addCurCost( levelId, levelScene, cost )

	if LevelSceneFunc:isMainLevel(levelScene) then 
		local costList = self:getDataByKey('curCost') or {}

		local bFind = false
		for i,v in ipairs(costList) do
			if v.levelId == levelId  then
				v.cost = v.cost + cost
				bFind = true
				break
			end 
		end

		if not bFind then
			local info = {}
			info.levelId = levelId
			info.cost = cost
			table.insert(costList, info )
		end

		self:setDataByKey('curCost',costList)
	end
end

function ServerData:getCurCost( topLevelId, levelStep, bShowLog )
	--获取当前花费的钱, 以topLevelId往前数levelStep -1关
	local srcLevelStep = levelStep
	local costList = self:getDataByKey('curCost') or {}

	local costNum = 0
	
	local maxLevelId = topLevelId
	local hasCanUseLength = 0

	for i,v in ipairs(costList) do
		if v.levelId <= maxLevelId then
			hasCanUseLength = hasCanUseLength + 1
		end 
	end

	--如果现有数据长度不满足levelStep, 重置levelStep
	if hasCanUseLength < levelStep then
		levelStep = hasCanUseLength
	end

	--获取最小关, 如果是45关，那么获取44关的
	local minLevelId = maxLevelId - levelStep

	for i,v in ipairs(costList) do
		if v.levelId >= minLevelId and v.levelId <= maxLevelId then
			costNum = costNum + v.cost
		end 
	end

	if bShowLog then
		log("***超鸟连胜fuuu判断V2*** *******getCurCost***********")
		log("***超鸟连胜fuuu判断V2*** costList", costList)
		log("***超鸟连胜fuuu判断V2*** minLevelId", minLevelId)
		log("***超鸟连胜fuuu判断V2*** maxLevelId", maxLevelId)
		log("***超鸟连胜fuuu判断V2*** srcLevelStep", srcLevelStep)
		log("***超鸟连胜fuuu判断V2*** costNum", costNum)
		log("***超鸟连胜fuuu判断V2*** levelStep", levelStep)
		log("***超鸟连胜fuuu判断V2*** *******getCurCost end***********")
	end

	return costNum, levelStep
end

------------------------------

return ServerData