local BaseFeatureModel = require "amf.middleware.activity.base.BaseFeatureModel"
local Model = class("SH01Model", BaseFeatureModel)

function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "SH01Model"
    }):as("db")
end

function Model:_getConstPath()
	return "amf.feature.localactivity.sh01.const.SH01Const"
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
    -- 
    self.tipPoped_1 = nil
    self.tipPoped_2 = nil
    self.tipPoped_3 = nil
    self.tipPoped_4 = nil
    self.sh01PopMain_ = nil
    self.canyuHadDC = nil
end

function Model:setLocalCache(key, value)
    self:setValue("_localCache."..key, value)
end

function Model:getLocalCache(key)
    return self:getValue("_localCache."..key)
end

function Model:fromServer( data,skipSaveLocal )
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
    
--------------------- 业务数据处理 ---------------------
function Model:saveValueToLocalByKey(outerKey, innnerKey, needTime, value)
    if not outerKey then return end
    if not innnerKey then return end

    local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())

    local saveValue = {
        time = nowTime,
        value = value
    }

    local saveRecordTableStr = self:getValue(outerKey) or "{}"
    local saveRecordTable = table.deserialize(saveRecordTableStr)
    saveRecordTable[innnerKey] = saveValue
    saveRecordTableStr = table.serialize(saveRecordTable)

    self:setValue(outerKey, saveRecordTableStr, true)
end

function Model:getValueFromLocalByKey(outerKey, innnerKey, needTime)
    if not outerKey then return end
    if not innnerKey then return end

    local saveRecordTableStr = self:getValue(outerKey) or "{}"
    local saveRecordTable = table.deserialize(saveRecordTableStr)

    local saveValue = saveRecordTable[innnerKey]
    if saveValue == nil then return end

    local nowTime = getDayStartTimeByTS(TimeKit:timeInSec())
    local bTimeIsOk = true

    -- 需要检查是否同一天 且 时间不同
    if needTime and saveValue.time ~= nowTime then
        bTimeIsOk = false
    end

    -- 检查是否同一天 且 不是同一天 返回空
    if needTime and not bTimeIsOk then
        return
    else
        return saveValue.value
    end
end

return Model