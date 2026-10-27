local ResponseActShareCommonHandler = require "amf.middleware.share.openshare.handler.ResponseActShareCommonHandler"
local OpenShareEventCenter = require "amf.middleware.share.openshare.event.OpenShareEventCenter"
local SuperBirdShareConst = require "amf.feature.localactivity.superbirdshare.const.Const"

local Handler = class("ResponseSuperBirdShareHelpShareHandler", ResponseActShareCommonHandler)

-- 分享助力：被帮助方打开分享卡片时，框架把启动参数解析成 query 后派发 ResponseHelp 事件，
-- 这里接住 actId=8080 + shareType=bird_share（老卡片是 help_activity），
-- 再由基类发 RequestGetShareReward 并弹结果面板。
local __instance

function Handler:init()
    ResponseActShareCommonHandler.init(self)
    -- 求助面板曝光（vx_help/main_panel_show）的 t2 是混合口径：
    -- 1=精力赠送、2=区域解锁、3=邮箱、8080=复活卡分享，框架只负责发，
    -- 活动 id 得由各自的活动 handler 补，所以这里接住框架的派发事件。
    OpenShareEventCenter:register(OpenShareEvent.DC_ASK_PANEL, self.onDcAskPanel, self)
end

function Handler:create()
    if __instance then
        return __instance
    end

    __instance = ResponseActShareCommonHandler.create(self)
    return __instance
end

function Handler:onDcAskPanel(evt)
    local data = evt:getData() or {}
    if table.isEmpty(data) then return end

    local query = data.query or {}
    -- 只在求助面板曝光时补 t2，app_share_vx 那几条不打这个点
    if query.category ~= "vx_help" or query.subCategory ~= "main_panel_show" then return end
    if not self:isShareEnabled(query) then return end

    data.dcParam.t2 = SuperBirdShareConst.actId
end

-- 必须返回能 tonumber/tostring 的活动 id
function Handler:getActId()
    return SuperBirdShareConst.actId
end

-- checkActVaild 会 require("activity/" .. getActSource()) 拿活动 Config
function Handler:getActSource()
    return "superbirdshare/Config.lua"
end

function Handler:getShareType()
    -- 分享类型取活动自己的 bird_share，分享链接/卡片里带的就是它，
    -- 框架的 vx_help/enter_game（t4）和 help_frame/game_into（t3）都靠它区分。
    return SuperBirdShareConst.shareType
end

-- 兼容过渡：改分享类型前发出去的卡片/口令里带的是通用的 help_activity，
-- 老卡片被好友点开时也得能接住，否则助力会失败。
function Handler:isShareEnabled(query)
    if not tonumber(query.actId) or (tonumber(query.actId) ~= tonumber(self:getActId())) then return end

    local shareType = tostring(query.shareType)
    if shareType ~= tostring(self:getShareType()) and shareType ~= tostring(OpenShareConst.ShareType.HELP_ACTIVITY) then
        return
    end
    return true
end

function Handler:getActName()
    return SuperBirdShareConst.actName
end

-- 助力次数和是否可助力由服务端判断（回包 extra.errorType），这里只用于失败文案占位
function Handler:getLimitNum()
    return 0
end


-- 检查活动有效性
function Handler:checkActVaild(query)
    local function isFunc(func)
        return type(func) == "function"
    end
    local actId = self:getActId()
    if not _G.amfBean("ActivityMgr"):isActExist(actId) then
        self:actCheckAlertPanel("抱歉，未找到对应活动，无法参加！")
        return
    end

    local config = self:getConfig()
    if not config then return false end
    local respHelpContext = self:makeResHelpContext(query)
    if isFunc(config.isVersionSupport) and not config.isVersionSupport() then
        self:dcAfterHelpFail(respHelpContext)
        self:actCheckAlertPanel(736431)
        return
    end

    if isFunc(config.hasUpdateFlag) and not config.hasUpdateFlag() then
        self:dcAfterHelpFail(respHelpContext)
        self:actCheckAlertPanel(736431)
        return
    end

    if isFunc(config.isActBegin) and not config.isActBegin() then
        self:dcAfterHelpFail(respHelpContext)
        self:actCheckAlertPanel(localize("error.tip." .. tostring(736433), {
            actName = self:getActName()
        }))
        return
    end

    if isFunc(config.isActEnd) and config.isActEnd() then
        self:dcAfterHelpFail(respHelpContext)
        self:actCheckAlertPanel(localize("error.tip." .. tostring(736433), {
            actName = self:getActName()
        }))
        return
    end

    if isFunc(config.isUnSupportPkg) and config.isUnSupportPkg() then
        self:dcAfterHelpFail(respHelpContext)
        self:actCheckAlertPanel(localize("error.tip." .. tostring(736432), {
            actName = self:getActName()
        }))
        return
    end

    return true
end

function Handler:getLimitPassLevel()
    local config = self:getConfig()
    if config and config.passLevelId then
        return config.passLevelId
    end
    return 0
end

return Handler
