local ResponseActShareCommonHandler = require "amf.middleware.share.openshare.handler.ResponseActShareCommonHandler"
local OpenShareUtil = require "amf.middleware.share.openshare.util.OpenShareUtil"
local OpenShareEventCenter = require "amf.middleware.share.openshare.event.OpenShareEventCenter"
local OpenShareDc = require "amf.middleware.share.openshare.dc.OpenShareDc"
local HappyMatchConst = require "amf.feature.localactivity.happymatch.config.HappyMatchConst"
local Handler = class("ResponseHappyMatchHelpShareHandler", ResponseActShareCommonHandler)

local HELP_TICKET_COUNT_DEFAULT = 0
local HELP_ACTIVITY_DC_VALUE = "help_activity"
local EMPTY_EXTRA_DATA = "{}"
local DC_VALUE_EMPTY = ""
local HELP_PANEL_SHOW_TYPE = {
    WX_HELP_TOKEN = 1,
    WEIBO_HELP_LINK = 2,
    WEIBO_SHARE_LINK = 3,
}
local FRIEND_TYPE = {
    FRIEND = 1,
    NOT_FRIEND = 2,
}
local HELP_FRAME_DC = {
    CATEGORY = "help_frame",
    REWARD_SHOW = "reward_show",
}
local HELP_REWARD_DC = {
    FEATURE = "vx_help",
    SOURCE = tostring(HappyMatchConst.actId) .. "_help",
}
local __instance

function Handler:create()
    if __instance then
        return __instance
    end

    __instance = ResponseActShareCommonHandler.create(self)
    return __instance
end

function Handler:init()
    ResponseActShareCommonHandler.init(self)
    OpenShareEventCenter:register(OpenShareEvent.DC_SHARE_ENTERGAME, self.onDcShareEnterGame, self)
end

function Handler:getConst()
    return HappyMatchConst
end

function Handler:getActId()
    return self:getConst().actId
end

function Handler:getActName()
    return self:getConst().actChName
end

function Handler:getActSource()
    return "happymatch/Config.lua"
end

function Handler:getShareType()
    return OpenShareConst.ShareType.HELP_ACTIVITY
end

function Handler:getLimitNum()
    return self:getConst().HELP_DAILY_LIMIT
end

function Handler:onDcShareEnterGame(evt)
    local data = evt:getData() or {}
    if table.isEmpty(data) then
        return
    end
    if not data.query then
        return
    end
    if not data.dcParam then
        return
    end
    if not self:isShareEnabled(data.query) then
        return
    end

    data.dcParam.t3 = self:getActId()
    data.dcParam.t4 = HELP_ACTIVITY_DC_VALUE
end

function Handler:helpSelfAlertPanel()
    self:showHelpResultWithoutRewardPanel({
        text = "自己不能帮助自己哦~",
        btnText = "知道了",
        needAddFriend = false,
    })
end

function Handler:_getHelpPanelShowType(query)
    query = query or {}
    if query.fromCopy then
        return HELP_PANEL_SHOW_TYPE.WX_HELP_TOKEN
    elseif query.shareKey then
        return HELP_PANEL_SHOW_TYPE.WEIBO_HELP_LINK
    end
    return HELP_PANEL_SHOW_TYPE.WEIBO_SHARE_LINK
end

function Handler:_getFriendType(helpUid)
    return OpenShareUtil:checkIsFriend(helpUid) and FRIEND_TYPE.FRIEND or FRIEND_TYPE.NOT_FRIEND
end

function Handler:_getResponseExtraData(respHelpContext)
    local response = respHelpContext and respHelpContext.response
    local respData = response and response.getData and response:getData() or {}
    local extraData = table.deserialize(respData.extra or EMPTY_EXTRA_DATA)
    if type(extraData) ~= "table" then return {} end
    return extraData
end

function Handler:_buildVxHelpShowDcParams(respHelpContext, helpNum)
    respHelpContext = respHelpContext or {}
    return {
        t1 = respHelpContext.helpUid,
        t2 = self:_getFriendType(respHelpContext.helpUid),
        t3 = HELP_ACTIVITY_DC_VALUE,
        t4 = self:getActId(),
        t5 = respHelpContext.shareType or DC_VALUE_EMPTY,
        panel_id = respHelpContext.panelId,
        help_num = tonumber(helpNum) or HELP_TICKET_COUNT_DEFAULT,
    }
end

function Handler:_buildHelpFrameRewardShowDcParams(respHelpContext, helpNum)
    respHelpContext = respHelpContext or {}
    local query = respHelpContext and respHelpContext.extraParam or {}
    return {
        t1 = self:getActId(),
        t2 = self:_getHelpPanelShowType(query),
        t3 = HELP_ACTIVITY_DC_VALUE,
        t5 = query.xxlId or DC_VALUE_EMPTY,
        help_num = tonumber(helpNum) or HELP_TICKET_COUNT_DEFAULT,
    }
end

function Handler:dcAfterHelpSuccess(respHelpContext)
    local query = respHelpContext and respHelpContext.extraParam or {}
    local extraData = self:_getResponseExtraData(respHelpContext)
    local helpNum = self:_getHelpTicketCount(extraData)

    if EnvUtil:isMiniGame() then
        local dcParams = self:_buildVxHelpShowDcParams(respHelpContext, helpNum)
        OpenShareDc:dcAfterHelpShow(query, dcParams)
    else
        local dcParams = self:_buildHelpFrameRewardShowDcParams(respHelpContext, helpNum)
        OpenShareDc:dc(HELP_FRAME_DC.CATEGORY, HELP_FRAME_DC.REWARD_SHOW, dcParams)
    end
end

function Handler:addRewards(rewards, feature, source)
    feature = feature or HELP_REWARD_DC.FEATURE
    source = source or HELP_REWARD_DC.SOURCE
    ResponseActShareCommonHandler.addRewards(self, rewards, feature, source)
end

function Handler:_getHelpTicketCount(extra)
    extra = extra or {}
    return tonumber(extra.ticketNum or extra.ticket or extra.helpTicketNum or extra.rewardNum) or HELP_TICKET_COUNT_DEFAULT
end

function Handler:getHelpSuccessAlerLabel(param)
    local ticketCount = self:_getHelpTicketCount(param.extra)
    if ticketCount > HELP_TICKET_COUNT_DEFAULT then
        return string.format("成功帮助好友获得%d张门票，奖励已发放，加油闯关吧~", ticketCount)
    end
    return "成功帮助好友获得门票，奖励已发放，加油闯关吧~"
end

function Handler:_makeNoFlyRewards(rewards)
    if table.isEmpty(rewards) then return rewards end

    local noFlyRewards = {}
    for index, reward in ipairs(rewards) do
        if type(reward) == "table" then
            noFlyRewards[index] = table.clone(reward) or {}
            noFlyRewards[index].doNotFly = true
        else
            noFlyRewards[index] = reward
        end
    end
    return noFlyRewards
end

function Handler:showHelpSuccessPanel(resHelpContext, rewards, extra)
    local text = self:getHelpSuccessAlerLabel({ extra = extra })
    local helpUid = resHelpContext.helpUid
    local isFriend = OpenShareUtil:checkIsFriend(helpUid)
    if EnvUtil:isApp() then
        isFriend = true
    end
    if rewards and not table.isEmpty(rewards) then
        self:showHelpResultPanel({
            title = self:getActName(),
            text = text,
            btnText = isFriend and "知道了" or "领取并添加",
            rewards = self:_makeNoFlyRewards(rewards),
            needAddFriend = not isFriend,
            uid = helpUid,
            panelId = resHelpContext.panelId,
        })
    else
        self:showHelpResultWithoutRewardPanel({
            title = self:getActName(),
            text = text,
            btnText = isFriend and "知道了" or "领取并添加",
            needAddFriend = not isFriend,
            uid = helpUid,
            panelId = resHelpContext.panelId,
        })
    end
end

return Handler
