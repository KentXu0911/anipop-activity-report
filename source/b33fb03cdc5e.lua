local AbstractPlug = require "amf.script.pattern.plug.AbstractPlug"
local MusicMergeLocalPush = class("MusicMergeLocalPush", AbstractPlug)

function MusicMergeLocalPush:onInstall(installData)
    self._const = require(installData.const)
end

function MusicMergeLocalPush:getConst()
    return self._const
end

function MusicMergeLocalPush:cancelPush()
    _G.amfTransaction(TransactionEvent.LOCALPUSH, {
        action = "remove",
        groupKey = self:getConst().actId
    })
end

function MusicMergeLocalPush:tryRegisterSinglePush()
    self:cancelPush()

    if not self:callHost("isEnabled") then
        return
    end

    local curTime = TimeKit:timeInSec()
    local mainEndTime = self:callHost("getMainEndTime")
    local title = "妙音合合"
    local text = "妙音合合进行中，海量好礼等你来拿！"
    local dayStartTime = getDayStartTimeByTS(curTime)
    local t = {
        dayStartTime + 3600 * 12,
        dayStartTime + 3600 * 18,
        dayStartTime + 3600 * 20,
    }

    for _, v in ipairs(t) do
        if v < mainEndTime and curTime < v then
            _G.amfTransaction(TransactionEvent.LOCALPUSH, {
                action = "add",
                timeStamp = v,
                title = title,
                message = text,
                type = LocalPushConst.LocalPushType.ACTIVITY1,
                groupKey = self:getConst().actId,
            })
        end
    end
end

return MusicMergeLocalPush
