local AbstractPlug = require "amf.script.pattern.plug.AbstractPlug"
local MergeEvolutionLocalPush = class("MergeEvolutionLocalPush", AbstractPlug)

function MergeEvolutionLocalPush:onInstall(installData)
    self._const = require(installData.const)
end

function MergeEvolutionLocalPush:getConst()
    return self._const
end

function MergeEvolutionLocalPush:cancelPush()
    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
        action = "remove",
        groupKey = self:getConst().actId
    })
end

function MergeEvolutionLocalPush:tryRegisterSinglePush()
    self:cancelPush()

    if not self:callHost("isEnabled") then
        return
    end

    local pushType = 73
    if not pushType then
        return
    end

    local curTime = TimeKit:timeInSec()
    local mainEndTime = self:callHost("getMainEndTime")
    local dayStartTime = getDayStartTimeByTS(curTime)
    local t = {
        dayStartTime + 3600 * 12,
    }

    for _, v in ipairs(t) do
        if v < mainEndTime and curTime < v then
            _G.amfTransaction(TransactionEvent.LOCALPUSH, {
                action = "add",
                timeStamp = v,
                type = pushType,
                groupKey = self:getConst().actId,
            })
        end
    end
end

return MergeEvolutionLocalPush
