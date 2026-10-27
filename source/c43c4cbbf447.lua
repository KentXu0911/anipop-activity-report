local BaseFeatureModel = require "amf.middleware.activity.base.BaseFeatureModel"
local Model = class("BattlePassModel", BaseFeatureModel)

function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "BattlePassModel"
    }):as("db")
end

function Model:_getConstPath()
    return "amf.feature.localactivity.battlepass.const.BattlePassConst"
end

function Model:__declare()
    self.userInfo = {}
    self.localConfig = {}
    self.clientMd5 = ""
    self.timeInfo = {}
    -- local key
    self.beforeBattlePass = 0
    self.play_level_state = nil  -- 进关时的关卡状态快照（本地缓存，不持久化）
    self.todayQualifyDC = nil
    self.todayJoinDC = nil
    self.taskSuccessDCIndex = 0  -- 已打点的最大完成任务档 index
    self.iconTipShownTierIndex = 0  -- 已弹出抽条的最大档位 index
end

function Model:getPlayLevelState()
    return self:getLocalValueByKey("play_level_state")
end

function Model:setPlayLevelState(state)
    self:setLocalValueByKey("play_level_state", false, state)
end

function Model:fromServer(data)
    for k, v in pairs(data) do
        self:setValue(k, v)
    end
end

function Model:getClientMd5()
    return self:getValue("clientMd5") or ""
end

---------------------------------------------------------------------------
-- UserData accessors
---------------------------------------------------------------------------
function Model:getJoinStatus()
    return self:getDataByKey("joinStatus", 0)
end

function Model:getTaskFlag()
    return self:getDataByKey("taskFlag", "")
end

function Model:setTaskFlag(flag)
    self:setDataByKey("taskFlag", flag)
end

function Model:getPeriodId()
    return self:getDataByKey("periodId", 0)
end

function Model:getBattlePassId()
    return self:getDataByKey("battlePassId", 0)
end

---------------------------------------------------------------------------
-- Time
---------------------------------------------------------------------------
function Model:getMainEndTime()
    local key = self:_getTimeKey("mainEndTime")
    return math.floor((self:getValue(key) or 0) / 1000)
end

function Model:getEndTime()
    local key = self:_getTimeKey("endTime")
    return math.floor((self:getValue(key) or 0) / 1000)
end

function Model:getMainBeginTime()
    local key = self:_getTimeKey("mainBeginTime")
    return math.floor((self:getValue(key) or 0) / 1000)
end

function Model:isInMainTime()
    local now = TimeKit:timeInSec()
    return now >= self:getMainBeginTime() and now <= self:getMainEndTime()
end

function Model:isInRewardTime()
    local now = TimeKit:timeInSec()
    return now > self:getMainEndTime() and now <= self:getEndTime()
end

---------------------------------------------------------------------------
-- Data helpers (reuse BaseFeatureModel key-chain)
---------------------------------------------------------------------------
function Model:getDataByKey(key, default)
    local fullKey = self:getConst().infoPrefix .. "." .. key
    local val = self:getValue(fullKey)
    if val == nil then return default end
    return val
end

function Model:setDataByKey(key, value)
    local fullKey = self:getConst().infoPrefix .. "." .. key
    self:setValue(fullKey, value)
end

function Model:getConfigByKey(key, default)
    local fullKey = self:getConst().configPrefix .. "." .. key
    local val = self:getValue(fullKey)
    if val == nil then return default end
    return val
end

function Model:_getTimeKey(key)
    return self:getConst().timePrefix .. "." .. key
end

function Model:updateTimeInfo(time)
    if not time then return end
    local prefix = self:getConst().timePrefix
    for k, v in pairs(time) do
        self:setValue(prefix .. "." .. k, v)
    end
end

---------------------------------------------------------------------------
-- isDataEnabled
---------------------------------------------------------------------------
function Model:isDataEnabled()
    local bp = self:getDataByKey("battlePass", nil)
    return bp ~= nil
end

---------------------------------------------------------------------------
-- BattlePass Data
---------------------------------------------------------------------------
function Model:getBattlePass()
    return self:getDataByKey("battlePass", {})
end

function Model:setBattlePass(data)
    self:setDataByKey("battlePass", data)
end

function Model:getBattlePassData(id)
    local cfg = self:getConfigByKey("battlePass", {})
    for _, v in ipairs(cfg) do
        if v.id == id then
            return v
        end
    end
    return {}
end

function Model:getBattlePassSum()
    local cfg = self:getConfigByKey("battlePass", {})
    return #cfg
end

function Model:getBattlePassValue()
    return self:getDataByKey("battlePass.value", 0)
end

function Model:addBattlePassValue(value)
    local curValue = self:getBattlePassValue()
    local newValue = curValue + value
    self:setDataByKey("battlePass.value", newValue)
end

function Model:getBattlePassVip()
    return self:getDataByKey("battlePass.hasVip", false)
end

function Model:setBattlePassVip()
    self:setDataByKey("battlePass.hasVip", true)
end

function Model:getBattlePassRewardsId(bVip)
    local key = bVip and "battlePass.vipAlreadyGotIds" or "battlePass.freeAlreadyGotIds"
    return self:getDataByKey(key, {})
end

function Model:addBattlePassRewardsId(bVip, id)
    local key = bVip and "battlePass.vipAlreadyGotIds" or "battlePass.freeAlreadyGotIds"
    local ids = self:getDataByKey(key, {})
    table.insert(ids, id)
    self:setDataByKey(key, ids)
end

-- 将数组转为 set {[value]=true} 便于 O(1) 查找
local function arrayToSet(arr)
    local set = {}
    for _, v in ipairs(arr or {}) do
        set[v] = true
    end
    return set
end

function Model:getMaxFinishedTaskIndex()
    local value = self:getBattlePassValue()
    local cfg = self:getConfigByKey("battlePass", {})
    local maxIndex = 0
    for index, rewardCfg in ipairs(cfg) do
        if value >= (rewardCfg.need or 0) then
            maxIndex = index
        end
    end
    return maxIndex
end

function Model:hasBattlePassReward()
    local value = self:getBattlePassValue()
    local hasVip = self:getBattlePassVip()
    local vipGotSet = arrayToSet(self:getBattlePassRewardsId(true))
    local freeGotSet = arrayToSet(self:getBattlePassRewardsId(false))
    local cfg = self:getConfigByKey("battlePass", {})

    local canGetFree = {}
    local canGetVip = {}

    for _, rewardCfg in ipairs(cfg) do
        local id = rewardCfg.id
        local need = rewardCfg.need or 0
        local meetNeed = value >= need

        if meetNeed then
            if not freeGotSet[id] then
                table.insert(canGetFree, id)
            end
            if hasVip and not vipGotSet[id] then
                table.insert(canGetVip, id)
            end
        end
    end

    local hasReward = (#canGetFree > 0) or (#canGetVip > 0)
    return hasReward, canGetFree, canGetVip
end

function Model:clearBattlePassReward()
    local hasReward, canGetFree, canGetVip = self:hasBattlePassReward()

    if not table.isEmpty(canGetFree) then
        local ids = self:getDataByKey("battlePass.freeAlreadyGotIds", {})
        for _, v in ipairs(canGetFree) do
            table.insert(ids, v)
        end
        self:setDataByKey("battlePass.freeAlreadyGotIds", ids)
    end

    if not table.isEmpty(canGetVip) then
        local ids = self:getDataByKey("battlePass.vipAlreadyGotIds", {})
        for _, v in ipairs(canGetVip) do
            table.insert(ids, v)
        end
        self:setDataByKey("battlePass.vipAlreadyGotIds", ids)
    end
end

---------------------------------------------------------------------------
-- Package / Goods
---------------------------------------------------------------------------


function Model:getDisplayablePackages()
    return self:getDataByKey("packageInfo", {}).displayablePackages
end

function Model:getPackageMetaById(id)
    local metas = self:getDataByKey("packageInfo", {}).packageMetas
    if not metas then return nil end
    for k, v in pairs(metas) do
        if k == tostring(id) then
            return v.packageMeta
        end
    end
end

function Model:getPackageMetas()
    local metas = {}
    local packageInfo = self:getDisplayablePackages()
    if not packageInfo then return metas end
    for _, v in pairs(packageInfo) do
        if v.packageId then
            metas[v.packageId] = v
        end
    end
    return metas
end

function Model:getPackageIdByType(type)
    local packs = self:getDisplayablePackages()
    if not packs then return nil end
    for _, v in pairs(packs) do
        if v.extra then
            local dic = table.deserialize(v.extra)
            if dic.type == type then
                return v.packageId
            end
        end
    end
    return nil
end

---------------------------------------------------------------------------
-- Data persistence
---------------------------------------------------------------------------
function Model:clearData()
    self:reset()
end

return Model
