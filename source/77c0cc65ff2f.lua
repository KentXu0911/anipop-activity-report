local BaseIcon
local IconMeta
if _G.MainSceneFloderVersion and _G.MainSceneFloderVersion >= 1.1 then
    BaseIcon = require "amf.feature.mainscene.module.icon.view.BaseIcon"
    IconMeta = require "amf.feature.mainscene.module.icon.config.IconMeta"
elseif not _G.MainSceneFloderVersion then
    BaseIcon = require "amf.feature.mainscene.icon.view.BaseIcon"
    IconMeta = require "amf.feature.mainscene.icon.config.IconMeta"
end

local ActionUtil = require "amf.middleware.ui.util.ActionUtil"
local UIEventCenter = require "amf.middleware.ui.event.UIEventCenter"
local CollectCardIcon = class("CollectCardIcon", BaseIcon)
local CollectCardEventCenter = require "amf.feature.localactivity.collectcard.event.CollectCardEventCenter"

local WINDOW_STATE_CHANGED_EVENT = _G.UIEvent.Popout.WINDOW_STATE_CHANGED
local ICON_SPINE_PATH = "amf/activity/collectcard/icon/jika_icon2.skel"

local FRAMETIME = 1/30
local PLAY_TYPE = {
    IDLE = 1,     -- 待机状态
    LOCK = 2,     -- 锁定状态
}

function CollectCardIcon:create(needShowLockedState)
    local icon = CollectCardIcon.new()
    icon:init(needShowLockedState)
    return icon
end

function CollectCardIcon:init(needShowLockedState)
    self.mgr = _G.amfBean("CollectCardManager")
    BaseIcon.init(self, IconKey.kCollectCardIcon)
    self.playType = nil
    self.needShowLockedState = needShowLockedState
    self._wasUnderFullScreenWindow = false
    self._refreshIconSpineScheduled = false
    self:updateState()
    self.endTime = self.mgr:getModel():getEndTime()
    self:startCountdownVer1({{
                type = "activity",
                labelText = "新卡礼包",
                endTimeInSec = self.endTime,
                startTimeInSec = 0,
                reachText = "00:00:00",
                endCallback = function()
                    self.mgr:updateGiftIcon()
                end,
            }})
    self:registerEvent()
    UIEventCenter:register(WINDOW_STATE_CHANGED_EVENT, self.onWindowStateChanged, self)
    self.mgr:dcActPlug():dcQualify()

    local newFlagShowNum = _G.amfBean("AutoPopupMgr"):getPermanentShowNum(self:getDiscoverNewActKey().."_panel")
    if newFlagShowNum < 1 then
        self:playHasNewFlagAni()
    end
end

function CollectCardIcon:registerEvent()
    CollectCardEventCenter:register(CollectCardEvent.CARD_NUM_UPDATE, self.onCardNumUpdate, self)
    CollectCardEventCenter:register(CollectCardEvent.ON_STARNUM_REDPOINT, self.updateState, self)
end

function CollectCardIcon:unregisterEvent()
    CollectCardEventCenter:unregister(CollectCardEvent.CARD_NUM_UPDATE, self.onCardNumUpdate, self)
    CollectCardEventCenter:unregister(CollectCardEvent.ON_STARNUM_REDPOINT, self.updateState, self)
end

function CollectCardIcon:onCardNumUpdate()
    self:updateState()
    if self._tip and not self.mgr:getProgressTipInfo() then
        self:removeTip()
    end
end

function CollectCardIcon:onWindowStateChanged(event)
    if self.isDisposed then return end
    local data = event and event:getData()
    if not data then return end

    if data.hasFullScreenWindow == true then
        self._wasUnderFullScreenWindow = true
        return
    end
    if data.hasFullScreenWindow ~= false or not self._wasUnderFullScreenWindow then
        return
    end

    self._wasUnderFullScreenWindow = false
    if self._refreshIconSpineScheduled then return end
    self._refreshIconSpineScheduled = true
    setNextFrame(function()
        self._refreshIconSpineScheduled = false
        if self.isDisposed then return end
        self:refreshIconSpine()
    end)
end

function CollectCardIcon:refreshIconSpine()
    if self.isDisposed or not self.baseLayer then return end

    local newIconSp = UICreateUtil:createSpine(ICON_SPINE_PATH)
    if not newIconSp then
        return
    end

    newIconSp:setPosition(ccp(50, 13))
    newIconSp.keepPlayingOnMainScenePopout = EnvUtil:isMiniGame()
    newIconSp:stopAtStart("idle")

    local oldIconSp = self.iconSp
    if oldIconSp and not oldIconSp.isDisposed then
        oldIconSp:removeFromParentAndCleanup(true)
    end
    self.iconSp = newIconSp
    self.baseLayer:addChild(newIconSp)
    self._isPlayingIconIdleAnim = false
    if self.playType == PLAY_TYPE.LOCK then
        self.iconSp:setScale(0)
    else
        self:showIdleIcon()
    end
end

function CollectCardIcon:initData(...)
    BaseIcon.initData(self, ...)
    if _G.amfBean("IconManager"):useUIBottomBarTest() then
        self.info:setPriority(11 + IconMeta.TypeMagicNum * 3)
    end
end

function CollectCardIcon:buildIcon()
    local base = Sprite:createEmpty()
    base:setContentSize(CCSizeMake(100,100))
    self.iconSp = UICreateUtil:createSpine(ICON_SPINE_PATH)
    self.iconSp:stopAtStart("idle")
    self.iconSp:setPosition(ccp(50,13))
    self.iconSp.keepPlayingOnMainScenePopout = EnvUtil:isMiniGame()
    base:addChild(self.iconSp)
    self.baseLayer = base
    return base
end

-- function CollectCardIcon:getOffsetPos()
--     return ccp(0, self.iconSize.height / 2)
-- end

function CollectCardIcon:updateState()
    BaseIcon.updateState(self)
    self:updateLabelShow()
    self:updateIconSpine()
end

function CollectCardIcon:getMsgNum()
    return self.mgr and self.mgr:getMsgNum() or 0
end

function CollectCardIcon:getMsgNumLimit()
    return 99
end

function CollectCardIcon:updateLabelShow()
    if self.isDisposed then return end
    if not self.mgr:isTopLevelSupport() then
        self:setLabelStr("开心卡册")
    elseif not self.mgr:isInActTime() then
        self:setLabelStr("即将开始")
    elseif not self.mgr:isLocalVersionSupport() or not self.mgr:isBundleVersionSupport() then
        self:setLabelStr("即将开始")
    else
        local allCardNum = self.mgr:getDataByKey("allCardNum", 0)
        local unlockCardNum = self.mgr:getDataByKey("unlockCardNum", 0)
        if allCardNum > 0 then
            self:setLabelStr(string.format("%d/%d", unlockCardNum, allCardNum))
        else
            self:setLabelStr("开心卡册")
        end
    end
end

function CollectCardIcon:updateIconSpine()
    if self.isDisposed then return end
    if self.needShowLockedState then
        if self.playType ~= PLAY_TYPE.LOCK then
            self:showLockedIcon()
            self.playType = PLAY_TYPE.LOCK
        end
    else
        if self.playType ~= PLAY_TYPE.IDLE then
            self.playType = PLAY_TYPE.IDLE
        end
        self:showIdleIcon()
    end
end

function CollectCardIcon:isInLockedType()
    return self.playType == PLAY_TYPE.LOCK
end

function CollectCardIcon:showLockedIcon()
    local lockedIcon = UICreateUtil:createSpriteFile("amf/activity/collectcard/icon/lockedIcon.png")
    lockedIcon:setAnchorPoint(ccp(0.5, 0.5))
    lockedIcon:setPositionXY(50, 50)
    self.baseLayer:addChild(lockedIcon)
    local lock = UICreateUtil:createSpineManuallyRelease("amf/mainscene/icon/spine/Bottom_Icon.skel")
    lock:playLoop("Unlock_freeze")
    lock:setPositionXY(50, 39)
    self.baseLayer:addChild(lock)

    self.lockedIcon = lockedIcon
    self.lockAnim = lock
    self.iconSp:setScale(0)
end

function CollectCardIcon:showIdleIcon()
    if self.lockAnim then
        self.lockAnim:removeFromParentAndCleanup(true)
        self.lockAnim = nil
    end
    if self.lockedIcon then
        self.lockedIcon:removeFromParentAndCleanup(true)
        self.lockedIcon = nil
    end

    if self:hasHint() then
        if self._isPlayingIconIdleAnim then return end
        self._isPlayingIconIdleAnim = true
        self.iconSp:playLoop("idle")
    else
        if self._isPlayingIconIdleAnim then
            self.iconSp:stopAtStart("idle")
            self._isPlayingIconIdleAnim = false
        end
    end
end

-- 等级到达后播解锁动画
function CollectCardIcon:playUnlockAnim(callback)
    if self.playType ~= PLAY_TYPE.LOCK then safeRunCall(callback) return end
    self.playType = PLAY_TYPE.IDLE
    self.needShowLockedState = false
    if not _G.amfBean("IconManager"):useUIBottomBarTest() then
        safeRunCall(callback)
        return
    end

    if self.lockedIcon and not self.lockedIcon.isDisposed then
        self.lockedIcon:runAction(ActionUtil:sequence{
            CCDelayTime:create(18*FRAMETIME),
            CCCallFunc:create(function()
                if self.isDisposed then return end
                self.lockedIcon:setVisible(false)
            end),
        })
    end
    if self.lockAnim and not self.lockAnim.isDisposed then
        self.lockAnim:playOnceAndDispose("Unlock")
    end
    if self.iconSp and not self.iconSp.isDisposed then
        self.iconSp:runAction(ActionUtil:sequence{
            CCDelayTime:create(18*FRAMETIME),
            CCCallFunc:create(function()
                if self.isDisposed then return end
                self.iconSp:setScale(0.5)
            end),
            CCEaseSineOut:create(CCScaleTo:create(4*FRAMETIME, 1.3)),
            CCDelayTime:create(3*FRAMETIME),
            CCEaseSineInOut:create(CCScaleTo:create(4*FRAMETIME, 0.95)),
            CCEaseSineInOut:create(CCScaleTo:create(2*FRAMETIME, 1)),
            CCCallFunc:create(function()
                if self.isDisposed then return end
                self:showIdleIcon()
                safeRunCall(callback)
            end),
        })
    end
end

function CollectCardIcon:hasHint()
    if not self.mgr:isActValid() then return false end
    local hasNew = self.mgr:isStarExchangeRedPoint()
    self.mgr:getModel():foreachCardData(function(cardData)
        local isNewCard = self.mgr:isNewCard(cardData.cardId)
        if isNewCard then
            hasNew = true
        end
    end)
    return hasNew
end

function CollectCardIcon:onTouch()
    if self.isDisposed then return end
    BaseIcon.onTouch(self)
    self:removeTip()
    if not self.mgr:isActValid() then
        if not self.mgr:isTopLevelSupport() then
            CommonTip:showTip("通过第210关可解锁本功能")
        elseif not self.mgr:isInActTime() then
            self:showNoOpenTimeTip()
        elseif not self.mgr:isLocalVersionSupport() or not self.mgr:isBundleVersionSupport() then
            CommonTip:showTip("请升级版本后再来哦~")
        end
    else
        _G.amfBean("CollectCardManager"):openActivity(nil, nil, true)
    end
    _G.amfBean("PopupNewActMgr"):sendPanelManualPopup(self:getDiscoverNewActKey())
end

function CollectCardIcon:showNoOpenTimeTip()
    local beginTime = self.mgr:getModel():getBeginTime()
    local mainBeginTime = self.mgr:getModel():getMainBeginTime()
    local now = TimeKit:timeInSec()
    if now >= beginTime and now < mainBeginTime then
        local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
        local timeTb = TimeUtil:convert2DHMS(mainBeginTime - now)
        local str = ""
        if timeTb.d > 0 then
            str = string.format("%d天%d小时后活动开启", timeTb.d, timeTb.h)
        else
            str = string.format("%02d:%02d:%02d后活动开启", timeTb.h, timeTb.m, timeTb.s)
        end
        local tip = UITip.Builder.new()
        :setTarget(self)
        :setTitle(str)
        :build()
        LayoutUtil:move(tip, 0, 25)
    else
        CommonTip:showTip("敬请期待新的一期活动～")
    end
end

function CollectCardIcon:dispose()
    UIEventCenter:unregister(WINDOW_STATE_CHANGED_EVENT, self.onWindowStateChanged, self)
    self:unregisterEvent()
    BaseIcon.dispose(self)
end

function CollectCardIcon:getDiscoverNewActKey()
    local uniqueKey = "collect_card_found_new_act"
    return uniqueKey
end

function CollectCardIcon:tryPopFoundNewAct()
    local popupNewActMgr = _G.amfBean("PopupNewActMgr")
    popupNewActMgr:addNewAutoPopPkgAct(self:getDiscoverNewActKey(), IconKey.kCollectCardIcon, "开心卡册")
    popupNewActMgr:handleNewIconActAutoPopup()
end

---进度提示气泡
function CollectCardIcon:showProgressTip(progressInfo)
    if self._tip or not progressInfo then return false end
    local MultiLabel = require "amf.middleware.ui.kit.component.multilabel.MultiLabel"
    local normalColor = hex2ccc4("9d4d12FF")
    local highlightColor = hex2ccc4("F45600FF")
    local labels
    if progressInfo.tier == "a" then
        labels = {
            {text = "已有", fontSize = 22, color = normalColor},
            {text = tostring(progressInfo.threshold) .. "套", fontSize = 22, color = highlightColor},
            {text = "卡册快集齐啦，加油！", fontSize = 22, color = normalColor},
        }
    elseif progressInfo.tier == "b" then
        labels = {
            {text = "已有", fontSize = 22, color = normalColor},
            {text = tostring(progressInfo.threshold) .. "套", fontSize = 22, color = highlightColor},
            {text = "卡册快集齐啦，继续冲！", fontSize = 22, color = normalColor},
        }
    elseif progressInfo.tier == "c" then
        labels = {
            {text = "厉害！快集齐的卡册已超过一半！", fontSize = 22, color = normalColor},
        }
    else
        labels = {
            {text = "仅剩", fontSize = 22, color = normalColor},
            {text = tostring(progressInfo.incompleteAlbumNum) .. "套", fontSize = 22, color = highlightColor},
            {text = "卡册就集齐啦，加油！", fontSize = 22, color = normalColor},
        }
    end
    local label = MultiLabel:createEasyMultiLabel(CCSizeMake(200, 0), labels)
    local size = label:getContentSize()
    local container = Layer:create()
    container:setName("collect-tip")
    local hei = 50
    container:changeWidthAndHeight(size.width, hei)
    container:setAnchorPoint(ccp(0.5, 1))
    container:addChild(label)
    local tip_builder = UITip.Builder.new()
    :setTarget(self)
    :setAutoCloseTime(5)
    :setContent(container, false)
    :setCloseCallback(function ()
        self._tip = nil
    end)
    -- tip_builder.outsideTouchClose = false
    local tip = tip_builder:build()
    LayoutUtil:move(tip, 0, 25)
    container:setPositionXY(size.width, hei)

    UIEventCenter:unregister(UIEvent.Remove.AUTO_TIP, tip.removeSelfByEvent)
    UIEventCenter:unregisterGlobal(NormalEvent.KEY_BACK_TAPPED, tip.removeSelfByEvent, nil, NormalEventPriority.KeyBack.REMOVE_TIP)
    self._tip = tip
    return true
end

function CollectCardIcon:removeTip()
    if self._tip then
        self._tip:close(true)
        self._tip = nil
    end
end

return CollectCardIcon
