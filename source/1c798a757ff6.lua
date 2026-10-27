local AbstractPlug = require "amf.script.pattern.plug.AbstractPlug"
local ClimbTowerLocalPush = class("ClimbTowerLocalPush", AbstractPlug)

local SECONDS_PER_HOUR = 3600
local SECONDS_PER_DAY  = 86400

function ClimbTowerLocalPush:onInstall(installData)
    self._const = require(installData.const)
end

function ClimbTowerLocalPush:getConst()
    return self._const
end

function ClimbTowerLocalPush:_getGroupKey()
    return tostring(self:getConst().actId)
end

function ClimbTowerLocalPush:cancelPush()
    if not LocalPushConst then return end
    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
        action   = "remove",
        groupKey = self:_getGroupKey(),
    })
end

function ClimbTowerLocalPush:tryRegisterPush()
    if EnvUtil:isMiniGame() then return end
    if not LocalPushConst then return end

    self:cancelPush()

    if not self:callHost("isEnabled") then return end
    if not self:callHost("isInMainTime") then return end

    local pushType = self:_pickPushType()
    if not pushType then return end

    local Const     = self:getConst()
    local text      = Const.PushText[pushType]
    local offsets   = Const.PushHourOffsets[pushType]
    local groupKey  = self:_getGroupKey()
    local nowTime   = TimeKit:timeInSec()
    local mainEnd   = TimeKit:tryConvertMsToSec(self:callHost("getMainEndTime"))

    for _, dayOffset in ipairs({ 0, 1, 2, 3 }) do
        local dayStart = TimeKit:getDayStartTimeByTS(nowTime) + dayOffset * SECONDS_PER_DAY
        for _, hour in ipairs(offsets) do
            local ts = dayStart + hour * SECONDS_PER_HOUR
            if ts > nowTime and ts < mainEnd then
                _G.amfTransaction(TransactionEvent.LOCALPUSH, {
                    action    = "add",
                    type      = LocalPushConst.LocalPushType.ACTIVITY1,
                    timeStamp = ts,
                    title     = text.title,
                    message   = text.message,
                    groupKey  = groupKey,
                })
            end
        end
    end
end

function ClimbTowerLocalPush:_pickPushType()
    local Const = self:getConst()

    if self:callHost("isGrandPrizeClaimed") then return nil end

    local curLayerId  = self:callHost("getCurrentLayerId") or 0
    local grandLayer  = self:callHost("getGrandLayerId")

    if curLayerId >= (grandLayer - 1) then
        return Const.PushType.GRAND
    end

    if self:callHost("isCurrentLayerOnlyLevelUpLeft") then
        return Const.PushType.NEXT_LAYER
    end

    return nil
end

return ClimbTowerLocalPush
