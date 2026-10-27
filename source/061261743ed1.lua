local ActInfo = require "amf.feature.localactivity.dailylevel.model.ActInfo"
local Model = class("DailyLevelModel", AMFDataRef)

function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "DailyLevelModel",
    }):as("db")

    self:installPlug(AMFDataPlugsType.SYNC, {
        requests = {
            mainInfo = "amf.feature.localactivity.dailylevel.http.RequestMainInfo",
            boxReward = "amf.feature.localactivity.dailylevel.http.RequestBoxReward",
            finalReward = "amf.feature.localactivity.dailylevel.http.RequestFinalReward",
        }
    })
end

function Model:__declare()
    self.data = {}
    self.localConfig = {}
    self.actTimeCfg = {
        beginTime = 0,
        mainEndTime = 0,
        endTime = 0
    }

    -- 本地缓存
    self.localCache = {}
end

-- 解析主 info：处理换期清理、本地配置、商品包注册与 actInfo 同步。
function Model:parseMainInfo(data)
    local dataBean = data.dataBean or {}
    local serverVersionedConfig = data.serverVersionedConfig or {}
    local localConfig = self:getValue("localConfig") or {}
    local oldPeriodId = self:getValue("data.periodId")

    if oldPeriodId and dataBean.periodId and tostring(oldPeriodId) ~= tostring(dataBean.periodId) then
        self:setValue("data", {})
        self:setValue("localCache", {})
    end

    if serverVersionedConfig.config and serverVersionedConfig.config ~= "" then
        localConfig = table.deserialize(serverVersionedConfig.config) or {}
    end

    localConfig.serverMd5 = serverVersionedConfig.serverMd5 or self:getValue("localConfig.serverMd5") or ""
    dataBean.buyPackageMap = dataBean.buyPackageMap or {}
    self:parsePackagesPullResponse(data.packagesPullResponse)
    data.packagesPullResponse = nil
    ActInfo:syncMainInfo(dataBean)

    self:setValue("data", dataBean)
    self:setValue("localConfig", localConfig)
    self:setValue("actTimeCfg.beginTime", dataBean.beginTime or 0)
    self:setValue("actTimeCfg.mainEndTime", dataBean.mainEndTime or 0)
    self:setValue("actTimeCfg.endTime", dataBean.endTime or 0)
    self:setValue("data.fromServer", true)
end

-- 解析主 info 携带的 packagesPullResponse，仅注册到 GoodsManager，不落本地存储。
function Model:parsePackagesPullResponse(packagesPullResponse)
    if not packagesPullResponse then return end
    for packageId, goods in pairs(packagesPullResponse.packageMetas or {}) do
        GoodsManager:registerGoods({
            goodsId = packageId,
            packageMeta = goods.packageMeta,
            productId = goods.productId,
        })
    end
end

-- 数据是否可用：必须请求过主 info，且 actInfo 的 version/time 仍有效。
function Model:isEnabled()
    return self:getValue("data.fromServer") and ActInfo:isEnabled()
end

-- 当前是否处于正式活动期。
function Model:isInMainTime()
    return ActInfo:isInMainTime()
end

-- 当前是否处于领奖期。
function Model:isInAwardTime()
    return ActInfo:isInAwardTime()
end

-- 当前是否处于活动任意有效时间段。
function Model:isActTimeEnabled()
    return ActInfo:isTimeEnabled()
end

-- 主info
function Model:requestMainInfo(param, loading)
    return self.syncPlug:requestMainInfo(param, loading)
end

-- box奖励领取
function Model:requestBoxReward(param, loading)
    return self.syncPlug:requestBoxReward(param, loading)
end

-- 开奖
function Model:requestFinalReward(param, loading)
    return self.syncPlug:requestFinalReward(param, loading)
end

return Model
