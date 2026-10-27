---@type EnergyActV2Meta
local Meta = require "amf.feature.localactivity.energyactv2.config.EnergyActV2Meta"
---@type EnergyActV2Config
local config = require "amf.feature.localactivity.energyactv2.config.EnergyActV2Config"
---@type EnergyActV2Events
local Events = require "amf.feature.localactivity.energyactv2.event.EnergyActV2Events"
---@type EnergyActV2EventCenter
local EventCenter = require "amf.feature.localactivity.energyactv2.event.EnergyActV2EventCenter"
local Dc = require "amf.feature.localactivity.energyactv2.dc.EnergyActV2DC"

local BaseFeatureManager = require"amf.middleware.activity.base.BaseFeatureManager"
---@class EnergyActV2Mgr : BaseFeatureManager
local Manager = class("EnergyActV2Mgr", BaseFeatureManager)

-- 如果有自己需要初始化的内容，覆写这个
function Manager:_init()
    require("amf.feature.localactivity.energyactv2.share.EnergyActV2AskHelpHandler"):create()
end

--- 请求奖励
function Manager:getReward(params, successHandler, sucCb, failCb, cancelCb)
    local function onSuccess(evt)
        if not evt.data then return end
        local rewards = evt.data.rewards or {}
        self:addRewards(rewards, params.type, params.dcSource)
        safeRunCall(successHandler, rewards, evt)
        self:checkDataAfterHttp(evt)
        local t2
        if params.type == 3 then
            t2 = 2
        end
        Dc:featureDc("help_success", params.inviteCode, t2)
        safeRunCall(sucCb, rewards, params)
    end

    local function onFail(evt)
        if not params or not (params.type == 3 or params.type == 4) then
            self:showErrorTip(evt)
        end
        local t2
        if params.type == 3 then
            t2 = 2
        end
        Dc:featureDc("help_failed", params.inviteCode, t2)
        safeRunCall(failCb, evt)
    end

    Manager:requestServerData("amf.feature.localactivity.energyactv2.http.EnergyActV2RequestShareRewards",
            params, onSuccess, onFail, cancelCb)
end

-- 在线请求统一入口
-- 强强表示必须一个协议一个Request文件，自己建request去吧
function Manager:requestServerData(requestClassPath, reqParams, onSuccess, onFail, onCancel, noLoading)
    if noLoading == nil then noLoading = true end
    local request = require(requestClassPath)
    request:post(reqParams, nil, not noLoading):next(onSuccess, function(response)
        if response:isCancel() then
            safeRunCall(onCancel, response)
        else
            safeRunCall(onFail, response)
        end
    end)
end

--- 添加奖励
function Manager:addRewards(rewardItems, type, source)
    for _, reward in pairs(rewardItems or {}) do
        if reward.itemId == Meta.ACT_ENERGY then
            local oldBuff = _G.amfBean("UserEnergyManager"):getInfiniteEnergyEndTime()
            local newBuff = 0
            if oldBuff < TimeKit:time() then
                newBuff = TimeKit:time() + 60 * 1000 * reward.num
            else
                newBuff = oldBuff + 60 * 1000 * reward.num
            end
            _G.amfBean("UserEnergyManager"):setInfiniteEnergyEndTime(newBuff)
            self:addMultiRewards({reward}, source)
        elseif reward.itemId == Meta.OTHER_ENERGY then
            self:addMultiRewards({{itemId = Meta.OTHER_ENERGY, num = 1}}, source)
        else
            local propSource = 0
            _G.amfBean("UserManager"):addReward(reward, propSource)
            self:addMultiRewards({reward}, source)
        end
    end
end

-- 前端通用奖励添加
function Manager:addMultiRewards(rewards, source)
    _G.GainPropData:create()
      :setFeature(config.dcFeature)
      :setSource(source or "act_" .. config.actId)
      :setProps(rewards)
      :execute()
end

--- 请求后更新领奖信息
function Manager:checkDataAfterHttp(evt)
    local data = evt.data or {}
    if data.energyRewarded ~= nil then
        -- 助力导致 能量值 变化，领取状态变化
        EventCenter:dispatch(Events.kEnergyRewardedChange, data.energyRewarded)
    end
end

--- 显示错误提示
function Manager:showErrorTip(evt, callback)
    local errCode = self:getErrorCode(evt)
    if errCode then
        local text = Localization:getInstance():getText("error.tip." .. tostring(errCode))
        if errCode >= 731776 and errCode <= 731779 then
            CommonTipWithBtn:showTip({
                tipStr = text,
                okInfo = { btnStr = "知道了" },
                colorType = PanelColorConst.ColorType.kBlue
            }, "negative", nil, nil, nil, true)
        else
            CommonTip:showTip(text, "negative", callback)
        end
    else
        safeRunCall(callback)
    end
end

---获取消息的错误码
function Manager:getErrorCode(evt)
    return type(evt) == 'number' and evt or (type(evt) == 'table' and evt.data or nil)
end

return Manager