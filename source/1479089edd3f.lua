local BaseFeatureModel = require "amf.middleware.activity.base.BaseFeatureModel"
local Model = class("BigVineSkinActModel", BaseFeatureModel)

function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "BigVineSkinActModel"
    }):as("db")

    self:installPlug(AMFDataPlugsType.SYNC, {
        requests = {
            reward = "amf.feature.localactivity.bigvineskinact.request.bigVineSkinReward",
        }
    })
end

function Model:_getConstPath()
    return "amf.feature.localactivity.bigvineskinact.const.BigVineSkinActConst"
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
    self.AwardTimeShowed = nil
    self.TodayTopLevelOffsetPlayer = nil
    self.mainPanelTipPopCount = nil
    self.BigVineSkinActMainLocalPush = nil
    self.BigVineSkinActQualifyDC = nil
    self.BigVineSkinActJoinDC = nil
end

function Model:setLocalCache(key, value)
    self:setValue("_localCache." .. key, value)
end

function Model:getLocalCache(key)
    return self:getValue("_localCache." .. key)
end

function Model:fromServer(data, skipSaveLocal)
    for k, v in pairs(data) do
        self:setValue(k, v)
    end

    if not skipSaveLocal then
        self:flush()
    end
end

function Model:requestReward(params)
    return self.syncPlug:requestReward(params or {})
end

-- 判断数据是否准备就绪
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

function Model:setGuide(index)
    local guideInfo = self:getDataByKey("guideSet", {})
    table.insert(guideInfo, index)
    self:setDataByKey("guideSet", guideInfo, true)
end

function Model:hasGuide(index)
    local guideInfo = self:getDataByKey("guideSet", {}, false)
    return table.find(guideInfo, function(v)
        return v == index
    end)
end

function Model:_getLocalKey(key)
    return key
end

--------------------- 业务数据处理 ---------------------
function Model:passDayClear()
    self:clearData()
end

-- 添加一个add的方法
function Model:addIntToLocalByKey(key, needTime, addNum, needActStartTimeCheck)
    if not addNum then addNum = 1 end
    local value = self:getFlagFromLocalByKeyInt(key, needTime, needActStartTimeCheck, 0)
    self:setLocalValueByKey(key, needTime, value + addNum, needActStartTimeCheck)
end

return Model
