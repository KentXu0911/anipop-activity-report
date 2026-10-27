local ActivityName = "NewbieGiftOptimize"
local Meta = require('amf.feature.localactivity.'..string.lower(ActivityName)..'.config.'..ActivityName..'Meta')
local Model = class(ActivityName .. "Model", AMFDataRef)

function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = ActivityName .. "LocalServer",
    }):as("db")
end

function Model:__declare()
    self.data = {}
    self.localConfig = {}
    self.localCache = {}
end

function Model:parseServerData(serverData)
	local localMd5 = self:getDataByKey(nil, "serverMd5", "")
	if serverData.serverVersionedConfig and serverData.serverVersionedConfig.serverMd5 and serverData.serverVersionedConfig.serverMd5 ~= localMd5 then
		local serverConfig = table.deserialize(serverData.serverVersionedConfig.config)
		serverConfig.serverMd5 = serverData.serverVersionedConfig.serverMd5
		serverData.localConfig = serverConfig
		serverData.serverVersionedConfig = nil
	end
	return serverData
end

function Model:fromServer(serverData,skipSaveLocal)
    local data = self:parseServerData(serverData)

    local giftPackActivityInfoList = data.giftPackActivityInfoList or {}
    for _, info in pairs(giftPackActivityInfoList) do
		local localGiftInfo = self:getGiftData(info.id)
		for k, v in pairs(info) do
			localGiftInfo[k] = v
		end
        self:setGiftData(info.id, localGiftInfo)
	end

    if data.localConfig then
        self:setConfig(data.localConfig)
    end
    self:setGuideSet(data.guideSet or {})

    if not skipSaveLocal then
		self:flush()
	end
end

function Model:getGiftData(giftType)
    local giftData = self:getValue("data."..tostring(giftType)) or {}
    return giftData
end

function Model:setGiftData(giftType, giftData, needSave)
    self:setValue("data."..tostring(giftType), giftData, needSave)
end

function Model:setConfig(config, needSave)
    self:setValue("localConfig", config, needSave)
end

function Model:setGuideSet(guideSet, needSave)
    self:setValue("localConfig.guideSet", guideSet, needSave)
end

function Model:syncFromActInfo(data)
    local Mgr = _G.amfBean("NewbieGiftOptimizeMgr")
	local giftPackActivityList = data.giftPackActivityList or {}
    for _, type in pairs(Mgr.GIFT_TYPE) do
        local info = table.find(giftPackActivityList, function ( v )
            return v.id == type
        end)
        if not info then
            self:setGiftData(type, {})
        else
            if not self:checkTypeDataEnabled(type) then
                printx(33, "new gift type appear!", type)
                Mgr:setHasNewGiftValid()
            end

            local localGiftInfo = self:getGiftData(type)
            local oldActEndTime = tonumber(localGiftInfo.endTime) or 0
            for k, v in pairs(info) do
                -- 购买完成后避免后端旧的endTime覆盖前端设置的endTime
                if type == Mgr.GIFT_TYPE.BUYANDFREE and k == "endTime" then
                    if tonumber(v) > oldActEndTime then
                        localGiftInfo[k] = v
                    end
                else
                    localGiftInfo[k] = v
                end
            end
            self:setGiftData(type, localGiftInfo)
        end
    end
    self:flush()
end

function Model:checkTypeDataEnabled(giftType)
    if not giftType then return end
    if table.isEmpty(self:getGiftData(giftType)) then return end
    return true
end

function Model:clearGiftTypeData(giftType)
    if not giftType then return end
    self:setGiftData(giftType, {})
end

function Model:getClientControlVersion(giftType)
    local info = self:getGiftData(giftType)
    if info and info.clientControlVersion then
        return info.clientControlVersion
    end
    return 0
end

function Model:getOpenIdx(giftType)
    local info = self:getGiftData(giftType)
    if info and info.periodId then
        return info.periodId
    end
    return 1
end

function Model:getActEndTime(giftType)
	local info = self:getGiftData(giftType)
    if not info then return 0 end
    local endTime = info.endTime or 0
    -- 瀑布流结束时间特殊规则
    local Mgr = _G.amfBean("NewbieGiftOptimizeMgr")
    if giftType == Mgr.GIFT_TYPE.BUYANDFREE then
        local buyEndTime = info.buyEndTime
        if buyEndTime and TimeKit:timeInMillis() < tonumber(buyEndTime) then
            endTime = tonumber(buyEndTime)
        end
    end
	return math.floor(endTime/1000)
end

function Model:getBuyAndFreeBuyEndTime()
    local Mgr = _G.amfBean("NewbieGiftOptimizeMgr")
    local buyEndTime = self:getDataByKey(Mgr.GIFT_TYPE.BUYANDFREE, "buyEndTime") or math.huge
    return math.floor(buyEndTime/1000)
end

function Model:setGuide( index )
	local guideInfo = self:getDataByKey(nil, "guideSet", {})
	table.insert(guideInfo, index)
	self:setDataByKey("guideInfo", guideInfo, true)
end

function Model:hasGuide( index )
	local guideInfo = self:getDataByKey(nil, "guideSet", {}, false)
	return table.find(guideInfo, function ( v )
		return v == index
	end)
end

function Model:getDataByKey(giftType, key, defaultValue, copyTable)
    --返回值
    if copyTable == nil then copyTable = true end
    local retValue = defaultValue

    local function copy( t )
        if copyTable and type(t) == "table" then
            return table.clone(t)
        end
        return t
    end

    if self:getValue("localConfig."..key) ~= nil then
        retValue = self:getValue("localConfig."..key)
        return copy(retValue)
    end

    local giftData = self:getValue("data."..tostring(giftType))
    if not giftType or not key or not giftData or table.isEmpty(giftData) then
        return copy(retValue)
    end

    if giftData[key] ~= nil then
        retValue = giftData[key]
        return copy(retValue)
    end

    return copy(retValue)
end

function Model:setDataByKey(giftType, key, value, needSave, isNewkey)
    if not giftType or not key then
        return
    end

    local giftData = self:getValue("data."..tostring(giftType))
    if giftData and giftData[key] then
        self:setValue("data."..tostring(giftType).."."..key, value, needSave)
    else
        if isNewkey then
            self:setValue("data."..tostring(giftType).."."..key, value, needSave)
        else
            return
        end
    end
end

function Model:setCache(key, data)
    self:setValue("localCache."..key, data)
end

function Model:getCache(key)
    return self:getValue("localCache."..key)
end

--判断数据是否准备就绪
function Model:isDataEnabled(checkType)
	if not self.data then
        return false
    end

	if table.isEmpty(self.data) then
        return false
    end

    if (table.isEmpty(self.localConfig)) then
        return false
    end

	if checkType then
		if self:checkTypeDataEnabled(checkType) then
			return false
		end
	end

    return true
end

return Model