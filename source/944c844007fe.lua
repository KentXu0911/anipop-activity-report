local deferred = require "amf.script.sugar.deferred"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local ActInfosModel = class("ActInfosModel", AMFDataRef)

function ActInfosModel:__installPlugs()
    self:installPlug(AMFDataPlugsType.SYNC, {
        requests = {
            mainInfo = "amf.middleware.activity.http.RequestActInfos",
        }
    })
end

function ActInfosModel:__declare()
    self._actInfos = {}
    self._activityParticipationTags = nil
    self._isUpdatingActInfo = false
end

function ActInfosModel:__init()

end

function ActInfosModel:requestMainInfo(params)
    return self.syncPlug:requestMainInfo(params)
end

function ActInfosModel:initActInfos(actInfos)
    local distributionData = {}
    for k, v in ipairs(actInfos) do
        distributionData[tostring(v.actId)] = v
    end
    self:setValue("_actInfos",distributionData)
end

function ActInfosModel:updateInfo()
    local d = deferred.new()

    if self:getValue("_isUpdatingActInfo") then 
        d:reject()
        return d
    end

    self:setValue("_isUpdatingActInfo", true)

    self:requestMainInfo():next(function()
        d:resolve()
    end, function()
        ALog.log("activity", "load actInfo fail")
        d:reject()
    end)
    return d
end

function ActInfosModel:onResponseGetActInfos2024(response)
    self:setValue("_isUpdatingActInfo", false) 
    if response:isSuccess() then
        local data = response:getData()
        local actInfos = data.actInfos
        local distributionData = {}
        for k, v in ipairs(actInfos) do
            distributionData[tostring(v.actId)] = v
        end
        self:setValue("_actInfos",distributionData)
        self:setValue("_activityParticipationTags", data.activityParticipationTags)

        ActivityEventCenter:dispatch(ActivityEvent.ACT_INFOS_UPDATE, {
            actInfos = distributionData,
            activityParticipationTags = data.activityParticipationTags,
            -- 从服务器更新的
            fromServer = true,
        })
    end
end

function ActInfosModel:tryNotifyActInfo()
    local actInfos = self:getValue("_actInfos")
    if actInfos and not table.isEmpty(actInfos) then
        ActivityEventCenter:dispatch(ActivityEvent.ACT_INFOS_UPDATE, {
            actInfos = actInfos,
            activityParticipationTags = self:getValue("_activityParticipationTags"),
            -- 从服务器更新的
            fromServer = true,
        })
    end
end

function ActInfosModel:setActInfo(actId, info)
    self:setValue("_actInfos." .. tostring(actId), info)
    ActivityEventCenter:dispatch(ActivityEvent.ACT_INFOS_UPDATE, {
        actInfos = {
            [tostring(actId)] = info
        }
    })
end

function ActInfosModel:getActInfo(actId)
    return self:getValue("_actInfos." .. tostring(actId))
end

function ActInfosModel:getActivityParticipationTags()
    return self:getValue("_activityParticipationTags")
end

function ActInfosModel:removeActInfo(actId)
    self:setValue("_actInfos." .. tostring(actId), nil)
end

return ActInfosModel
