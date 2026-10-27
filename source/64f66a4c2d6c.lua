local BaseFeatureModel = require"amf.middleware.activity.base.BaseFeatureModel"
local CanteenModel = class("canteen_data", BaseFeatureModel)

function CanteenModel:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "canteen_data"
    }):as("db")
end

function CanteenModel:_getConstPath()
	return  "amf.feature.localactivity.canteen.config.Meta.lua"
end 

-- CanteenModel
function CanteenModel:__declare()
    self:_initLocalData()
    self:_initLocalConfig()
    self:_initLocalKey()
end

function CanteenModel:_initLocalData()
    self.data = nil
	self.roundCache = nil --跨期清空
	self.dailyCache = nil --每日清空
	self.actRound = nil 
end




function CanteenModel:_initLocalConfig()
    self.localConfig = nil
    self.configMd5 = nil
end

function CanteenModel:_initLocalKey()
	local round = self:getConst().ACT_ROUND
	for i=round, round+5 do
		self['CanTeen_Join_Group_Round_'..i] = nil
	end

	for i=1, 10 do
		self['TodayShowRankIconTip'..i] = nil
		self['TodayShowRankIconTop3Tip'..i] = nil
	end
end

function CanteenModel:fromServer( CanteenModel,skipSaveLocal )

	self:setValue('data', {} )
	if self.localConfig == nil then
		self:setValue('localConfig', {} )
	end

	local parseConfig = function ( extra )
		for k,v in pairs(extra) do
			self.localConfig[k] = v
		end
	end

	for k,v in pairs(CanteenModel) do
		if k == "extra" then
			parseConfig(v)
		elseif k == 'serverVersionedConfig' then
			-- self:setConfigMd5(v.serverMd5)
			self:setValue('configMd5', v.serverMd5 )
			if v.config then
				parseConfig(table.deserialize(v.config))
			end
		elseif k == "userBean" then
			self.data[k] = v
		else
			self.data[k] = v
		end
	end

	if not skipSaveLocal then
		self:flush()
	end

	-- printx(12,"fromServer data",tts(self.data))
	-- printx(12,"fromServer configMd5",tts(self.configMd5))
	-- printx(12,"fromServer config",tts(self.localConfig))

end

function CanteenModel:getConfigMd5(  )
	return self.configMd5 or '12345'
end

function CanteenModel:getActBeginTime(  )
	if self.data.actTime then
		return self.data.actTime.beginTime
	end
	return 0
end

function CanteenModel:getActMainBeginTime(  )
	if self.data.actTime then
		return self.data.actTime.mainBeginTime
	end
	return 0
end

function CanteenModel:getActMainEndTime(  )
	if self.data.actTime then
		return self.data.actTime.mainEndTime
	end
	return 0
end

function CanteenModel:getActEndTime(  )
	if self.data.actTime then
		return self.data.actTime.endTime
	end
	return 0
end

function CanteenModel:isActInPre(  )
	if self.data.actTime then
		local now = TimeKit:timeInSec()
		local beginTime = self:getActBeginTime()
		local endTime = self:getActMainBeginTime()
		return now >= beginTime and now <= endTime
	end
end

function CanteenModel:isActInMain(  )
	if self.data.actTime then
		local now = TimeKit:timeInSec()
		local beginTime = self:getActMainBeginTime()
		local endTime = self:getActMainEndTime()
		return now >= beginTime and now <= endTime
	end
end
function CanteenModel:isActInReward(  )
	if self.data.actTime then
		local now = TimeKit:timeInSec()
		local beginTime = self:getActMainEndTime()
		local endTime = self:getActEndTime()
		return now >= beginTime and now <= endTime
	end
end


function CanteenModel:hasPassLevel(  )
	if self.data.actPassLevel then
		local levelId = _G.getTopLevelId()
		return levelId > self.data.actPassLevel
	end
end

function CanteenModel:setGuide( index )
	local guideInfo = self:getDataByKey("guideIdSet", {})
	table.insert(guideInfo, index)
	self:setDataByKey("guideIdSet", guideInfo, true)
end

function CanteenModel:hasGuide( index )
	local guideInfo = self:getDataByKey("guideIdSet", {}, false)
	return table.find(guideInfo, function ( v )
		return v == index
	end)
end



--------------------- 每次需要修改的函数 ---------------------
---copy的时候去掉data方法的cachekey参数，应当改用dailycache或者roundcache
---这里只是为了方便迁移到新数据结构

--通过key获取data
function CanteenModel:getDataByKey(key,defaultValue,copyTable)
    --返回值
    if copyTable == nil then copyTable = true end
    local retValue = defaultValue

    local function copy( t )
        if copyTable and type(t) == "table" then
            local ansValue = table.clone(t)
            return ansValue
        end
        return t
    end
	
	local data = self:getValue("data")

    if not key or not data or table.isEmpty(data) then
        return retValue
    end

    if data[key] ~= nil then
        retValue = data[key]
        retValue = copy(retValue)
        return retValue
    end

	if data['userBean'] and data['userBean'][key] ~= nil then
        retValue = data['userBean'][key]
        retValue = copy(retValue)
        return retValue

	end


    if self.localConfig and self.localConfig[key] ~= nil then
        retValue = self.localConfig[key]
        retValue = copy(retValue)
        return retValue
    end


    if data.localConfig and data.localConfig[key] ~= nil then
        retValue = data.localConfig[key]
        retValue = copy(retValue)
        return retValue
    end

	local roundCache = self:getValue("roundCache")
	if roundCache and roundCache[key] ~= nil then 
        retValue = roundCache[key]
        retValue = copy(retValue)
        return retValue
	end 

    retValue = copy(retValue)
    return retValue
end

--更新单个数据
function CanteenModel:setDataByKey(key,value,needSave,isCacheKey)
	local data = self:getValue("data") or {}
    if not key or not data then
        return
    end

	local roundCache = self:getValue("roundCache") or {}

	if needSave == nil then needSave = true end

    if data[key] ~= nil then
        data[key] = value
		self:setValue("data",data,needSave)
	elseif data['userBean'] and data['userBean'][key] ~= nil then
        data['userBean'][key] = value
		self:setValue("data",data,needSave)
    elseif data.instanceInfo and data.instanceInfo[key] ~= nil then
        data.instanceInfo[key] = value
		self:setValue("data",data,needSave)
	elseif roundCache and roundCache[key] then 
		roundCache[key] = value
		self:setValue("roundCache",roundCache,needSave)
    else
        if isCacheKey then
			roundCache[key] = value
			self:setValue("roundCache",roundCache,needSave)
        else
            return
        end
    end

end




function CanteenModel:setDailyCache(key,value)
	local dailyCache = self:getValue("dailyCache") or {}
	dailyCache[key] = value
	self:setValue("dailyCache",dailyCache,true)
end

function CanteenModel:getDailyCache(key,defaultValue)
	local dailyCache = self:getValue("dailyCache") or {}
	return dailyCache[key] or defaultValue
end

function CanteenModel:setRoundCache(key,value)
	local roundCache = self:getValue("roundCache") or {}
	roundCache[key] = value
	self:setValue("roundCache",roundCache,true)
	
end

function CanteenModel:getRoundCache(key,defaultValue)
	local roundCache = self:getValue("roundCache") or {}
	return roundCache[key] or defaultValue
end

function CanteenModel:onPassRound()
	self:setValue("roundCache",{})
end

function CanteenModel:onPassDay()
	self:setDataByKey('todayTriggeredTimes',0)
	self:setDataByKey('afterLastTimeTrigger',0)
	self:setValue('dailyCache',{})
end
--判断数据是否准备就绪
function CanteenModel:isDataEnabled()
	if not self.data then
        return false
    end

	if table.isEmpty(self.data) then
        return false
    end

	if not self:isActInMain() then
		return false
	end

	if not self:hasPassLevel() then
		return false
	end

	if not self.localConfig or table.isEmpty(self.localConfig) then
		return false
	end

	if not self:getDataByKey('menuList') then
		return false
	end


    -- if (not self:getDataByKey("localConfig")) or (not self:getDataByKey("canUseCollectNum"))then
    --     return false
    -- end

    return true
end

function CanteenModel:getBuffEndTime()
	local time = math.floor(tonumber(self:getDataByKey("doubleCollectBuffEndTime",0))/1000)
	return time
end


function CanteenModel:getAddScore20Time()
	local time = math.floor(tonumber(self:getDataByKey("buffEndTs",0))/1000)
	return time
end

function CanteenModel:addScoreBuff(timeAdd)
	local time = math.max(math.floor(tonumber(self:getDataByKey("buffEndTs",0))/1000) ,TimeKit:timeInSec())
	self:setDataByKey("buffEndTs",(time + timeAdd*60 )*1000)

end

--------------------- 业务数据处理 ---------------------

function CanteenModel:getLimitTimeMenus(isCopy)
	isCopy = isCopy or false
	local menuList = self:getDataByKey('menuList', {}, isCopy)
	local menu = {}
	for _,v in pairs(menuList) do
		if v.menuType == 2 then
			table.insert(menu, v)
		end
	end
	return menu
end



function CanteenModel:getMenuById(id,isCopy)
	local menuList = self:getDataByKey('menuList',{},isCopy)
	for k,v in pairs(menuList) do
		if v.menuId == id then
			return v
		end
	end
end


function CanteenModel:getLimitMenu(isCopy)
	local menus = self:getLimitTimeMenus(isCopy)
	for k,v in pairs(menus) do
		local time = tonumber(v.expireAtTs or 0)/ 1000
		if time > TimeKit:timeInSec() then
			return v
		end
	end

end


function CanteenModel:onMenuMake(menuId)
	self:setMenuMakeOver(menuId)
	local menuBean = self:getMenuById(menuId)
    local materialMap = self:getDataByKey('materialMap',{},false)
    if not menuBean or not materialMap then return false end
    for id,needNum in pairs(menuBean.needMaterialMap) do
        if materialMap[id] then
			materialMap[id] = materialMap[id] - needNum
        end
    end
end

function CanteenModel:setMenuMakeOver(menuId)
	local finishMap = self:getDataByKey('finishedMenuIdSet',{},false)
	if not table.includes(finishMap,menuId) then
		table.insert(finishMap,menuId)
		self:setDataByKey('finishedMenuIdSet', finishMap)
	end
end


function CanteenModel:setLimitTimeMenuOver(id)
	local materialMap  = self:getDataByKey('materialMap',{},false)
	for k,v in pairs(materialMap) do
		if k == self:getConst().materialIds.kSpA or k == self:getConst().materialIds.kSpB then
			materialMap[k] = 0
		end
	end
	materialMap  = self:getDataByKey('materialMap',{},true)
end

function CanteenModel:getSpANum()
	local materialMap  = self:getDataByKey('materialMap',{},false)
	for k,v in pairs(materialMap) do
		if k == self:getConst().materialIds.kSpA then
			return v
		end
	end
end

function CanteenModel:getSpBNum()
	local materialMap  = self:getDataByKey('materialMap',{},false)
	for k,v in pairs(materialMap) do
		if k == self:getConst().materialIds.kSpB then
			return v
		end
	end
end


function CanteenModel:setNewMenu(menuId,menuBean)
	local menuList = self:getDataByKey('menuList',{},false)
	for k,v in pairs(menuList) do
		if v.menuId == menuId then
			menuList[k] = menuBean
		end
	end
end



function CanteenModel:setLimitMenuAndGift(menuId,goodsId,goodsExpireAtTs)

	local menuExpireAtTs = goodsExpireAtTs
	if not goodsExpireAtTs then
		local limitTime = 0 * 1000
		local temporaryGoodsMetaList = self:getDataByKey('temporaryGoodsMetaList')
		for k,v in pairs(temporaryGoodsMetaList) do
			if v.lastGoodsId == goodsId and v.expireAfterMinute and tonumber(v.expireAfterMinute) > 0 then
				limitTime  = tonumber(v.expireAfterMinute ) * 60 * 1000
			end
		end
		goodsExpireAtTs = tostring( TimeKit:timeInMillis() + tonumber(limitTime) )


		local limitTime2 = 0 * 1000
		local menuMetaList = self:getDataByKey('menuMetaList')
		for k,v in pairs(menuMetaList) do
			if v.menuId == menuId and v.expireAfterMinutes and tonumber(v.expireAfterMinutes) > 0 then
				limitTime2  = tonumber(v.expireAfterMinutes ) * 60 * 1000
			end
		end
		menuExpireAtTs = tostring( TimeKit:timeInMillis() + tonumber(limitTime2) )

	end

	local expireTime = tonumber(goodsExpireAtTs)/ 1000
	local time = TimeKit:timeInSec()
	if  TimeKit:getDayStartTimeByTS2(expireTime) > TimeKit:getDayStartTimeByTS2(time) then
		goodsExpireAtTs =  (TimeKit:getDayStartTimeByTS2(expireTime)-1) * 1000
	end

	local expireTime = tonumber(menuExpireAtTs)/ 1000
	if  TimeKit:getDayStartTimeByTS2(expireTime) > TimeKit:getDayStartTimeByTS2(time) then
		menuExpireAtTs = (TimeKit:getDayStartTimeByTS2(expireTime)-1) * 1000
	end




	self:setDataByKey('goodsId',goodsId)
	self:setDataByKey('goodsExpireAtTs',goodsExpireAtTs)
	local menu = self:getMenuById(menuId,false)
	if menu then
		menu.expireAtTs = menuExpireAtTs
	else --第一次加
		self:clearLimitMenu()
		local temporaryMenuList = self:getDataByKey('temporaryMenuList')
		for k,v in pairs(temporaryMenuList) do
			if v.menuId == menuId then
				local menuBean = table.clone(v)
				menuBean.expireAtTs = menuExpireAtTs
				self:addNewMenu(menuBean)
				break
			end
		end
	end
end

function CanteenModel:addNewMenu(menuBean)
	local menuList = self:getDataByKey('menuList', {},false)
	table.insert(menuList,menuBean)
	self:setDataByKey("menuList",menuList,true)
end

--删除旧的过期限时食谱，保证同时只有一个限时食谱
function CanteenModel:clearLimitMenu(menuBean)
	local menuList = self:getDataByKey('menuList', {},false)
	local needClearId
	for k,v in pairs(menuList) do
		local time = tonumber(v.expireAtTs or 0)/ 1000
		if  v.menuType == 2 and time <= TimeKit:timeInSec() then
			needClearId = v.menuId
			break
		end
	end
	if needClearId then
		self:setNewMenu(needClearId,nil)
	end
end


function CanteenModel:getMeniList(isCopy)
	isCopy = isCopy or false
	return self:getDataByKey('menuList', {}, isCopy)
end

function CanteenModel:getFinishedMenu(isCopy)
	isCopy = isCopy or false
	local fMenu = self:getDataByKey('finishedMenuIdSet', {}, isCopy)
	return fMenu
end

function CanteenModel:getNormalMenu(isCopy)
	isCopy = isCopy or false
	local menuList = self:getDataByKey('menuList', {}, isCopy)
	local menu = {}
	for _,v in pairs(menuList) do
		if v.menuType == 1 then
			table.insert(menu, v)
		end
	end
	return menu
end

function CanteenModel:getNormalMenuCfg()
	local cfg = self:getDataByKey('menuMetaList', {}, true)
	local menu = {}
	for _,v in pairs(cfg) do
		if v.temporary == false then
			table.insert(menu, v)
		end
	end
	return menu
end

function CanteenModel:getLimitTimeMenuCfg()
	local cfg = self:getDataByKey('menuMetaList', {}, true)
	local menu = {}
	for _,v in pairs(cfg) do
		if v.temporary == true then
			table.insert(menu, v)
		end
	end
	return menu
end

function CanteenModel:getTodayTriggeredTimes()
	return self:getDataByKey('todayTriggeredTimes', 0, false)
end

function CanteenModel:getAfterLastTimeTrigger()
	return self:getDataByKey('afterLastTimeTrigger', 0, false)
end

function CanteenModel:getTriggerTemporaryNeed()
	return self:getDataByKey('triggerTemporaryNeed', 3, false)
end

function CanteenModel:getAlreadShow(type)
	return self:getDataByKey('alreadyShow'..tostring(type), false, false)
end

function CanteenModel:setAlreadShow(b,type)
	self:setDataByKey('alreadyShow'..tostring(type), b, true,true)
end

function CanteenModel:canTriger()
	local time = self:getTodayTriggeredTimes()
	local maxTime = self:getDataByKey('triggeredTimeLimit')
	local afterLastTimeTrigger = self:getDataByKey('afterLastTimeTrigger',0)
	local needPass = self:getTriggerTemporaryNeed()
	return time < maxTime and afterLastTimeTrigger >= needPass
end


function CanteenModel:onTriger()
	printx(29,'ontrigger')
	self:setDataByKey('afterLastTimeTrigger',0)
	local time = self:getTodayTriggeredTimes()
	self:setDataByKey('todayTriggeredTimes', time + 1)
	self:setLimitTimeMenuOver()
end

function CanteenModel:addMaterial(materialId,num)
    local materialMap = self:getDataByKey('materialMap',{},false)
	local nowNum = materialMap[materialId] or 0
	materialMap[materialId] = nowNum + num
	self:setDataByKey("materialMap",materialMap)
end

function CanteenModel:setGoodsBuy(goodsId)
	goodsId = tostring(goodsId)
    local alreadyBuyGoodsIdMap = self:getDataByKey('alreadyBuyGoodsIdMap',{},false)
	local hasBuyNum = alreadyBuyGoodsIdMap[goodsId] or 0
	alreadyBuyGoodsIdMap[goodsId]  = hasBuyNum + 1

	printx(29,"setGoodsBuy",goodsId,tts(alreadyBuyGoodsIdMap))

	self:setDataByKey('alreadyBuyGoodsIdMap',alreadyBuyGoodsIdMap,true)
    local alreadyBuyGoodsIdMap = self:getDataByKey('alreadyBuyGoodsIdMap',{},false)
	printx(29,"setGoodsBuy2",goodsId,tts(alreadyBuyGoodsIdMap))

end

function CanteenModel:hasBuyGift()
	local goodsId = tostring( self:getDataByKey('goodsId') )
    local alreadyBuyGoodsIdMap = self:getDataByKey('alreadyBuyGoodsIdMap',{},true)
	local limitNum = self:getDataByKey("goodsBuyLimit")
	printx(29, alreadyBuyGoodsIdMap[goodsId] and alreadyBuyGoodsIdMap[goodsId] , tts(alreadyBuyGoodsIdMap),limitNum ,'hasBuyGift')
	if alreadyBuyGoodsIdMap[goodsId] and alreadyBuyGoodsIdMap[goodsId] >= limitNum then
		return true
	end
	return false
end



function CanteenModel:isInGiftTime()

    local time = tonumber(self:getDataByKey('goodsExpireAtTs',0)) / 1000
    if time > TimeKit:timeInSec() then
        return true
    else
        return false
    end
end

function CanteenModel:passLevel()
	local afterLastTimeTrigger = self:getDataByKey('afterLastTimeTrigger',0)
	self:setDataByKey('afterLastTimeTrigger',afterLastTimeTrigger + 1,true,true)
end

function CanteenModel:passLevel_normal()
	if self:isInGiftTime() then
		local passLevelTime = self:getDailyCache(self:getConst().limitTimePassLevelKey,0)
		self:setDailyCache(self:getConst().limitTimePassLevelKey,passLevelTime + 1 ,true,true)
	end
end


-- 获取从1970.1.1开始服务器时间是第几天
function CanteenModel:getDayFrom1970( time )
    local curDayStartTime = getDayStartTimeByTS(time or TimeKit:timeInSec())
    return math.ceil((curDayStartTime-8*60*60)/86400)
end



--关卡内用的参数A，具体参考技术文档https://rzvo5fieru.feishu.cn/wiki/KbzowVq6MiBNdwkoo0GcmVoInHd
function CanteenModel:getA()
	local makeTimes = 0
	local menuList = self:getDataByKey('menuList',{})
	for k,v in pairs(menuList) do
		makeTimes = makeTimes + v.makeTimes
	end

	printx(229,'厨神食堂:已经制作的数量',makeTimes)
	local checkN = 5
	local canGetA,makeIdMpas= self:checkCanMakeTimes(checkN  - makeTimes)
	if not canGetA then return nil end
	printx(229,'厨神食堂:至少可以制作的菜谱列表',tts(makeIdMpas))
	local menuList = self:getDataByKey('menuList',{})
	local materialMap = table.clone( self:getDataByKey('materialMap',{},false))
	local Mlist = {}
	for k,v in pairs(menuList) do
		local M1 = 0
		local M2 = 0
		for id,needNum in pairs(v.needMaterialMap) do
			M2 = M2 + needNum
			if not materialMap[id] or  materialMap[id] < needNum then
				M1 = M1 + ( materialMap[id] or 0)
			else
				M1 = M1 + needNum
			end
		end
		local M = M1*1.0/M2
		if M < 1 then
			table.insert(Mlist,{
				M = M,
				menuBean = v
			})
		end
		printx(229,"厨神食堂:食谱ID" .. v.menuId .. "的完成度M = ",M)
	end

	local randomList = {}
	table.sort(Mlist,function(a,b)
		return a.M > b.M
	end)
	for k,v in ipairs(Mlist) do
		if #randomList > 0 then break end
		local maxMBean = v.menuBean
		local isInLimit = self:getLimitMenu() and true or false
		if maxMBean.menuType == 2 and not isInLimit then
			--donothing
		else
			for id,needNum in pairs(maxMBean.needMaterialMap) do
				if not materialMap[id] or  materialMap[id] < needNum and id ~= "8" and id ~= "7" then
					table.insert(randomList,id)
				end
			end
		end
	end
	if #randomList == 0 then return 0 end
	return randomList[math.random(1,#randomList)]
end

--判断能做的菜是否大于这个值
function CanteenModel:checkCanMakeTimes(needNum)
	local menuList = self:getDataByKey('menuList',{})
	local makeIdMap = {}
	local materialMap = table.clone( self:getDataByKey('materialMap',{},false))


	local checkCanMake = function(materialMap,needMaterialMap)
		for id,needNum in pairs(needMaterialMap) do
			if not materialMap[id] or  materialMap[id] < needNum then
				return false
			end
		end
	end

	local doMake = function(materialMap,needMaterialMap,menuId)
		for id,needNum in pairs(needMaterialMap) do
			materialMap[id] = materialMap[id] - needNum
		end
		table.insert(makeIdMap,menuId)
		return materialMap
	end

	local revertMake = function(materialMap,needMaterialMap,menuId)
		for id,needNum in pairs(needMaterialMap) do
			materialMap[id] = materialMap[id] + needNum
		end
		table.remove(makeIdMap,#makeIdMap)
		return materialMap
	end

	local find
	find = function(materialMap)
		if #makeIdMap > needNum then
			printx(29,"可制作的菜谱",tts(makeIdMap))
			return false
		end
		for k,menuBean in pairs(menuList) do
			local isInLimit = self:getLimitMenu() and true or false
			if menuBean.menuType == 2 and not isInLimit then
				--donothing
			elseif checkCanMake(materialMap,menuBean.needMaterialMap) then
				doMake(materialMap,menuBean.needMaterialMap)
				if find(materialMap) then return true end
				revertMake(materialMap,menuBean.needMaterialMap)
			end
		end
		return true
	end


	return find(materialMap),makeIdMap

end



return CanteenModel