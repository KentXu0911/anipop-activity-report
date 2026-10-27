local ActivityName = "LuckyBagParty"
local LocalServer = class(ActivityName .. "LocalServer", AMFDataRef)

function LocalServer:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = ActivityName .. "LocalServer",
    }):as("db")
end

function LocalServer:__declare()
    self.data = {}
    self.localConfig = {}
end

function LocalServer:clearAll()
    self:setValue("data", {})
    self:setValue("localConfig", {})
    self:flush()
end

function LocalServer:fromServer(serverData,skipSaveLocal)
	for k,v in pairs(serverData) do
        if k == "extra" then
            for kk,vv in pairs(v) do
                self:setValue("data." .. kk, vv)
            end
        else
            self:setValue("data." .. k, v)
        end
	end

	if not skipSaveLocal then
		self:flush()
	end
    -- self:showInfo()
end

--判断数据是否准备就绪
function LocalServer:isDataEnabled()
    if not self.data then
        return false
    end

	if table.isEmpty(self.data) then
        return false
    end

	if not self:isActInMain() then
		return false
	end

    return true
end

function LocalServer:getFullData()
    return self:getValue("data")
end

function LocalServer:clearDataByKey(key,needSave)
    self:setDataByKey("data." .. key,nil,needSave)
end

--更新单个数据
function LocalServer:setDataByKey(key,value,needSave,isNewkey)
    if not key then
        return
    end

    self:setValue("data." .. key,value,needSave)
end

--通过key获取data
function LocalServer:getDataByKey(key,defaultValue)
    return self:getValue("data." .. key) or defaultValue
end

function LocalServer:getActMainBeginTime(  )
    local beginTs = self:getDataByKey("beginTs", 0)
	return math.floor(tonumber(beginTs) / 1000)
end

function LocalServer:getActMainEndTime(  )
    local endTs = self:getDataByKey("endTs", 0)
	return math.floor(tonumber(endTs) / 1000)
end

function LocalServer:getSourceVersion()
    local clientVersion = self:getDataByKey("clientVersion", 0)
    return tonumber(clientVersion) or 0
end

function LocalServer:isActInMain( ... )
	local now = TimeKit:timeInSec()
	local beginTime = self:getActMainBeginTime()
	local endTime = self:getActMainEndTime()
    printx(33, "beginTime", beginTime, "endTime", endTime, "now", now)
	
	return now >= beginTime and now <= endTime
end

return LocalServer