local ResponseActShareCommonHandler = require "amf.middleware.share.openshare.handler.ResponseActShareCommonHandler"
local OpenShareEventCenter = require "amf.middleware.share.openshare.event.OpenShareEventCenter"
local Handler = class("ResponseAskHelpShareHandler", ResponseActShareCommonHandler)

Handler.t1Table = {
    k4001 = 8,  -- 卡片进
    k4007 = 6,  -- 链接进
    k1002 = 7,  -- 扫码进
    k4002 = 7, -- 苹果扫码进
    k4003 = 7, -- 苹果扫码进
}

function Handler:init()
    ResponseActShareCommonHandler.init(self)
    OpenShareEventCenter:register(OpenShareEvent.DC_SHARE_ENTERGAME, self.onDcShareEnterGame, self)
end

-- 必须返回string
function Handler:getActId()
    return tostring(_G.amfBean("UnderTheSinMgr"):getConst().actId)
end

function Handler:getActSource()
    return "underthesin/Config.lua"
end
-- 帮助次数限制
function Handler:getLimitNum()
    return 3
end

function Handler:getActName()
    return _G.amfBean("UnderTheSinMgr"):getConst().actChName
end

function Handler:getShareType()
    return OpenShareConst.ShareType.HELP_ACTIVITY
end

-- 进游戏打点,依靠scene字符串后4位确定进入游戏的类型（链接、扫码、点击私聊卡片）
function Handler:onDcShareEnterGame(evt)
    if not EnvUtil:isDYMiniGame() then return end
    local data = evt:getData() or {}
    if table.isEmpty(data) then return end
    if (not data.query) or table.isEmpty(data.query) then return end
    local query = data.query
    if not tonumber(query.actId) or (tonumber(query.actId) ~= tonumber(self:getActId())) then return end
    
    local sceneStr = data.query.scene
    local last4 = string.sub(sceneStr, -4)
    if not last4 then return end
    local key = 'k'..last4
    if EnvUtil:isDevelopMode() then
        UError("last4key:", key, Handler.t1Table[key])
    end
    data.dcParam.t1 = Handler.t1Table[key]
end

function Handler:getLimitPassLevel()
    return 100
end

-- App 帮助成功面板走活动自己的 UI（需求「好友助力成功面板」：帮助成功 + 道具×n + 实物 banner + 去看看）：
-- 面板和纹理都在主包内，奖励在 onGetShareRewardSuccess 里已经发过了，这里只管展示。
-- 小游戏不走这条：需求「小游戏助力反馈」里小游戏有自己的帮助成功面板（加好友 + 道具气泡），仍走框架 SecondPanel。
function Handler:showHelpSuccessPanel(resHelpContext, rewards, extra)
    if not EnvUtil:isMiniGame() and not table.isEmpty(rewards) then
        local SuccessHelpTipPanelVM = require "amf.feature.localactivity.underthesin.view.SuccessHelpTipPanelVM"
        SuccessHelpTipPanelVM.Builder.new()
            :setRewards(rewards)
            :build()
            :popout(nil, true, SceneLayerShowKey.SHARE_LAYER)
        return
    end
    ResponseActShareCommonHandler.showHelpSuccessPanel(self, resHelpContext, rewards, extra)
end

return Handler
