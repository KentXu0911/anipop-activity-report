---@type EnergyActV2Config
local config = require "amf.feature.localactivity.energyactv2.config.EnergyActV2Config"
---@type EnergyActV2DC
local Dc = require "amf.feature.localactivity.energyactv2.dc.EnergyActV2DC"
---@type EnergyActV2Meta
local Meta = require "amf.feature.localactivity.energyactv2.config.EnergyActV2Meta"
---@type EnergyActV2Events
local Events = require "amf.feature.localactivity.energyactv2.event.EnergyActV2Events"
---@type EnergyActV2EventCenter
local EventCenter = require "amf.feature.localactivity.energyactv2.event.EnergyActV2EventCenter"
local OpenShareEventCenter = require "amf.middleware.share.openshare.event.OpenShareEventCenter"

local baseShareHandler = require "amf.middleware.share.openshare.handler.ResponseActShareCommonHandler"
local Handler = class("EnergyActV2AskHelpHandler", baseShareHandler)

---@type EnergyActV2Mgr
local Manager

function Handler:init()
    baseShareHandler.init(self)
    OpenShareEventCenter:register(OpenShareEvent.DC_SHARE_ENTERGAME, self.onDcShareEnterGame, self)
end

-- 必须返回string
function Handler:getActId()
    return config.actId
end

function Handler:getShareType()
    return config.shareType
end

function Handler:getActSource()
    return "energyactv2/Config.lua"
end

-- 帮助次数限制
function Handler:getLimitNum()
    return 3
end

function Handler:preCheck(query)
    -- 本活动，允许帮助自己
    return true
end

function Handler:responsePureShareProcess(query)
    self:responseHelpProcess(query)
end

function Handler:responseHelpProcess(query)
    if not query then return end
    local resHelpContext = self:makeResHelpContext(query)
    self:requestGetShareReward(resHelpContext)
end

-- 领奖http
function Handler:requestGetShareReward(resHelpContext)
    Manager = _G.amfBean("EnergyActV2Mgr")
    --- 解析奖励数据
    local data = resHelpContext or {}
    if not data.extraParam or not data.extraParam.actId or tonumber(data.extraParam.actId) ~= config.actId then return end
    local shareData = {
        shareKey = data.extraParam.shareKey,
        inviteCode = data.extraParam.invitecode or data.extraParam.uid,
        openId = data.extraParam.openId,
        source = data.extraParam.WXToken and 1 or 2, -- 1-微信 2-微博
    }
    self:RequestRewardAndShow(shareData)
end

--region 处理3种分享领奖（分享码、小程序卡片、链接）

function Handler:RequestRewardAndShow(shareData, done)
    if not shareData then safeRunCall(done) return end

    if shareData.shareKey then
        self:handleCopyCodeShare(shareData, done) ---- 微信、微博、小游戏卡片
    elseif shareData.inviteCode then
        if shareData.openId then
            self:handleMiniShare(shareData, done) ---- 原小程序的处理，兼容(可能废弃了，检查代码覆盖率后，可以删掉)
        else
            self:handleLinkShare(shareData, done) ---- Feed（朋友圈/QQ空间）
        end
    else
        safeRunCall(done)
    end
end

function Handler:handleCopyCodeShare(shareData, done)
    Dc:dcShowLinkRewardSuccess(shareData.source)
    if shareData.source == 2 then
        Dc:featureDc('ingame_zzy')
    end

    local apiCall = function(success, error, finally)
        Manager:getReward({
            type = 3,
            shareKey = shareData.shareKey,
            param = shareData.source,
            inviteCode = shareData.inviteCode,
            dcSource = "help_reward",
        }, nil, success, error, finally)
    end
    self:callApiWithHandlers(apiCall, done)
end

function Handler:handleMiniShare(shareData, done)
    Dc:featureDc('ingame_xcx')

    local apiCall = function(success, error, finally)
        Manager:getReward({
            type = 4,
            inviteCode = shareData.inviteCode,
            openId = shareData.openId,
        }, function(_)
        end, success, error, finally)
    end
    self:callApiWithHandlers(apiCall, done)
end

function Handler:handleLinkShare(shareData, done)
    Dc:featureDc('ingame_zzy')

    local apiCall = function(success, error, finally)
        Manager:getReward({
            type = 3,
            inviteCode = shareData.inviteCode,
            dcSource = "help_reward",
        }, nil, success, error, finally)
    end
    self:callApiWithHandlers(apiCall, done)
end

--endregion 处理3种分享

--- 显示奖励 或 错误提示
function Handler:callApiWithHandlers(apiCall, done)
    local successCallback = function(rewards, params)
        self:handleHelpSelf(rewards, params)
        local rewardItem, energy = self:extractRewardAndEnergy(rewards)
        if rewardItem then
            self:showRewardPanel(rewardItem, energy, done)
        else
            safeRunCall(done)
        end
    end

    local errorCallback = function(evt)
        self:handleShareError(evt, done)
    end

    apiCall(successCallback, errorCallback, done)
end

function Handler:handleHelpSelf(rewards, params)
    local me = tostring(_G.amfBean("ProfileManager"):getXxlId())
    if tostring(params.inviteCode) == me then
        local energy
        for _, v in ipairs(rewards or {}) do
            if v.itemId == Meta.OTHER_ENERGY then
                energy = v.num
            end
        end
        if not energy then return end
        EventCenter:dispatch(Events.kDailyBeHelpedChange, energy)
    end
end

function Handler:extractRewardAndEnergy(rewards)
    local rewardItem, energy
    for _, v in ipairs(rewards or {}) do
        if v.itemId == Meta.OTHER_ENERGY then
            energy = v.num
        else
            rewardItem = v
        end
    end
    return rewardItem, energy
end


function Handler:showRewardPanel(rewardItem, energy, done)
    local vmCls = require "amf.feature.localactivity.energyactv2.view.EnergyActV2HelpRewardPanelVM"
    ---@type EnergyActV2HelpRewardPanelBuilder
    local builder = vmCls.Builder.new()
    local vm = builder:setRewardItem(rewardItem)
                      :setCloseCallback(done)
                      :setEnergy(energy)
                      :build()
    vm:popout()
end

function Handler:handleShareError(evt, done)
    local errCode = Manager:getErrorCode(evt)
    Manager:showErrorTip(errCode, done)
    Dc:dcShowLinkRewardFail(errCode)
end

-- 进游戏打点,依靠scene字符串后4位确定进入游戏的类型（链接、扫码、点击私聊卡片）
function Handler:onDcShareEnterGame(evt)
    local data = evt:getData() or {}
    if table.isEmpty(data) then return end
    if (not data.query) or table.isEmpty(data.query) then return end
    local query = data.query
    if not tonumber(query.actId) or (tonumber(query.actId) ~= tonumber(self:getActId())) then return end
    
    data.dcParam.t1 = self:getShareType()
    data.dcParam.t4 = nil
end

return Handler