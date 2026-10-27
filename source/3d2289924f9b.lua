local Const = require "amf.feature.localactivity.returngift.config.ReturnGiftConst"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"

local ReturnGiftActInfo = {}

function ReturnGiftActInfo:ensureRegisterActInfoUpdate()
    if self._actInfoUpdateRegistered then return end
    self._actInfoUpdateRegistered = true
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActInfosUpdate, self)
end

function ReturnGiftActInfo:onActInfosUpdate(event)
    local data = event and event:getData() or {}
    if not data.fromServer then return end

    local actInfos = data.actInfos or {}
    local actInfo = actInfos[tostring(Const.ActId)] or actInfos[Const.ActId]
    self._actInfo = actInfo
end

function ReturnGiftActInfo:getActInfo()
    self:ensureRegisterActInfoUpdate()
    if self._actInfo then return self._actInfo end

    local activityMgr = _G.amfBean("ActivityMgr")
    if not activityMgr or not activityMgr.getActInfo then return nil end
    return activityMgr:getActInfo(Const.ActId)
end

function ReturnGiftActInfo:getExtra(actInfo)
    actInfo = actInfo or self:getActInfo()
    if not actInfo or not actInfo.extra then return nil end
    if type(actInfo.extra) == "table" then return actInfo.extra end
    return table.deserialize(actInfo.extra or "")
end

function ReturnGiftActInfo:isShowableStatus(extra)
    -- do return true end --debug
    local status = tonumber((extra or {}).status) or 0
    return status == 1 or status == 2
end

function ReturnGiftActInfo:getNextPackagePullTs(extra)
    return tonumber((extra or {}).nextPackagePullTs) or -1
end

---活动数据，礼包类型，1、3认为是一个类型1.
function ReturnGiftActInfo:getPackageType()
    local extra = self:getExtra()
    local type = tonumber((extra or {}).packageType) or 1
    if type == 2 then return 2 end
    return 1
end

function ReturnGiftActInfo:isActInfoEnabled()
    local extra = self:getExtra()
    if not self:isShowableStatus(extra) then return false end
    return self:getNextPackagePullTs(extra) >= 0
end

function ReturnGiftActInfo:canRequestPackagesPull()
    -- do return true end --debug
    if EnvUtil:isOhos() then return false end
    local extra = self:getExtra()
    if not self:isShowableStatus(extra) then return false end

    local nextPackagePullTs = self:getNextPackagePullTs(extra)
    if nextPackagePullTs < 0 then return true end
    return TimeKit:timeInMillis() >= nextPackagePullTs
end

return ReturnGiftActInfo
