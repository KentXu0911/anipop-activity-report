local BaseIcon = require "amf.feature.mainscene.module.icon.view.BaseIcon"
local FriendIcon = class("FriendIcon", BaseIcon)
local FriendEventCenter = require "amf.feature.friend.event.FriendEventCenter"

function FriendIcon:create()
    local icon = FriendIcon.new()
    icon:init()
    return icon
end

function FriendIcon:dispose()
    _G.amfEC:unregisterFeature(self)

    BaseIcon.dispose(self)
end

function FriendIcon:init()
    BaseIcon.init(self, IconKey.kFriend)
    self._serverCacheManager = _G.amfBean("ServerCacheManager")
    _G.amfEC:registerFeature(self)
    self.needShowGuide =
        (_G.getTopLevelId() > _G.amfBean("FriendManager"):getUnlockLevel()) and EnvUtil:isWXMiniGame() and
            not self._serverCacheManager:hasGuideFlag(GuideFlagConst.WechatFriendGuide)

    FriendEventCenter:register(FriendEventConst.FRIEND_DATA_INIT, self.onFriendDataChange, self)
    self:updateState()
end

function FriendIcon:getIconSpriteFrameName()
    return "friends"
end

function FriendIcon:getMsgNum(...)
    -- body
    local redNum = _G.amfBean("FriendManager"):getAddFriendsNum()
    return redNum
end

function FriendIcon:hasHint()
    local serverCacheManager = _G.amfBean("ServerCacheManager")
    return (not serverCacheManager:hasGuideFlag(_G.GuideFlagConst.kWechatFriendRank)) and EnvUtil:isWXMiniGame()
end

function FriendIcon:onTouch()
    BaseIcon.onTouch(self)
    if self.isDisposed then
        return
    end
    if self.heGuide and not self.heGuide.isDisposed then
        self.heGuide:removeGuide()
        self.heGuide = nil
    end
    self:popoutFriendPanel()
    if not self:isTodayClicked() then
		self:setTodayClicked()
	end
end

function FriendIcon:popoutFriendPanel()
    _G.amfBean("FriendManager"):openFriendPanel()
end

function FriendIcon:canShow()
    return _G.amfBean("FriendManager"):isUnlocked()
end

function FriendIcon:showGuide()
    self.needShowGuide = false
    self._serverCacheManager:setGuideFlag(GuideFlagConst.WechatFriendGuide)


    if _G.amfBean("IconManager"):useUIBottomBarTest() then
        local IconMeta = require "amf.feature.mainscene.module.icon.config.IconMeta"
        local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
        IconEventCenter:dispatch(IconEvent.OPEN_ICON_POOL, IconMeta.PoolType.kRightCorner)
    end

    local HeGuide = require 'amf.middleware.ui.kit.component.HeGuide'
    local heGuide = HeGuide:create(nil, true, nil, nil, true)
    heGuide:addAccurateGuide(self.icon, {self})

    self:addGuideHand()
    heGuide:setEndCall(function()
        self.heGuide = nil
        if self.cancelAutoPopup then
            self.cancelAutoPopup()
        end
    end)
    local contentList = {{
        ttf = "在【小伙伴们】查看微信和游戏内好友排名，还能添加伙伴一起畅玩哦~"
    }}
    heGuide:showNpc2(contentList, 100)
    self.heGuide = heGuide
end

function FriendIcon:onFriendDataChange()
    self:updateState()
end

--加小手
function FriendIcon:addGuideHand()
    local GuideHand = require "amf.middleware.ui.kit.animation.guide.GuideHand"
    self.handAnim = GuideHand:createHandClick(0, nil, true)
    self.ui:addChild(self.handAnim)
    UICreateUtil:move(self.handAnim, 0, 15)
end

function FriendIcon:removeGuideHand()
    if self.handAnim then
        self.handAnim:removeFromParentAndCleanup(true)
        self.handAnim = nil
    end
end


function FriendIcon:onActEnterStage4()
    if not self.needShowGuide then
        return
    end

    local function creator()
        self.cancelAutoPopup = _G.convert2ThrowawayFunction(function()
            AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.WECHAT_FRIEND_GUIDE)

            self:removeGuideHand()
            if self.heGuide and not self.heGuide.isDisposed then
                self.heGuide:removeGuide()
                self.heGuide = nil
            end
        end, 10)

        self:showGuide()
    end
    _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.WECHAT_FRIEND_GUIDE, creator)
end

function FriendIcon:onActEnterStage2(evt)
    if not _G.amfBean("IconManager"):useUIBottomBarTest() then return end
    if not EnvUtil:isMiniGame() then return end
    local serverCacheManager = _G.amfBean("ServerCacheManager")
    if serverCacheManager:hasGuideFlag(_G.GuideFlagConst.kMiniGameFriendMoveGuide) then return end

    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.MINI_FRIEND_MOVE)
    end

    local creator = function ()

        setTimeOut(function()
            local icon = _G.amfBean("IconManager"):getIconByIconKey(IconKey.kFriend)
            if icon then
                icon:showMoveGuide(onHandleOver,false)
            else
                safeRunCall(onHandleOver)
            end
        end,2/30) --延2帧，这强弹比iconlayer创的还早。。
    end
    _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.MINI_FRIEND_MOVE, creator)
end


function FriendIcon:showMoveGuide(done,isFirst)
    if not self:canShow() then safeRunCall(done) return end
    setTimeOut(function()
        local serverCacheManager = _G.amfBean("ServerCacheManager")
        if serverCacheManager:hasGuideFlag(_G.GuideFlagConst.kMiniGameFriendMoveGuide) then
            safeRunCall(done)
            return
        end


        if _G.amfBean("IconManager"):useUIBottomBarTest() then
            local IconMeta = require "amf.feature.mainscene.module.icon.config.IconMeta"
            local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
            IconEventCenter:dispatch(IconEvent.OPEN_ICON_POOL, IconMeta.PoolType.kRightCorner)
        end

        local HeGuide = require"amf.middleware.ui.kit.component.HeGuide"
        local heGuide = HeGuide:create(self, true,nil,nil,true)
        local function endCall(clickPos)
            safeRunCall(done)
        end
        heGuide:addAccurateGuide(self,{self})
        heGuide:setEndCall(endCall)
        local contentList = {}
        contentList = {
            {ttf = "为了更好的游戏体验，"},
            {ttf = "小伙伴",color =  "00a5c8ff"},
            {ttf = "移动到“+”内啦~"},

        }

        heGuide:setMinMaxTime(nil,3)
        heGuide:showNpc2(contentList, 100)
        self.guide = heGuide

        local serverCacheManager = _G.amfBean("ServerCacheManager")
        serverCacheManager:setGuideFlag(_G.GuideFlagConst.kMiniGameFriendMoveGuide)
    end,(isFirst or not EnvUtil:isMiniGame()) and 1/30 or 30/30)
end


function FriendIcon:todayCanShow()
    return self:canShow() and not self:isTodayClicked()
end

function FriendIcon:isTodayClicked()
    local iconKey = self:getInfo():getIconKey()
    return _G.amfBean("IconManager"):getDailyCount(iconKey) > 0
end

function FriendIcon:setTodayClicked()
	local iconKey = self:getInfo():getIconKey()
    _G.amfBean("IconManager"):addDailyCount(iconKey, 1)
end


return FriendIcon
