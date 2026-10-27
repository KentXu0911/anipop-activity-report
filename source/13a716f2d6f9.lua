local BaseIcon = require "amf.feature.mainscene.module.icon.view.BaseIcon"
local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local IconMeta = require "amf.feature.mainscene.module.icon.config.IconMeta"

local ActivityCenterIcon = class("ActivityCenterIcon", BaseIcon)

function ActivityCenterIcon:ctor()
    self.id = "ActivityCenterIcon"

    self._newActivityUniqueId = nil
end

function ActivityCenterIcon:create()
    local icon = ActivityCenterIcon.new()
    icon:init()
    return icon
end

function ActivityCenterIcon:init()
    BaseIcon.init(self, IconKey.kActCenter)
    self.mgr = _G.amfBean("ActivityCenterManager")
    self._serverCacheManager = _G.amfBean("ServerCacheManager")
    _G.amfEC:registerFeature(self)
    self:updateState()
end

function ActivityCenterIcon:getIconSpriteFrameName()
    return "fulizhan"
end

function ActivityCenterIcon:hasReward(...)
    if self.mgr then
        return self.mgr:hasReward()
    end
    return false
end

function ActivityCenterIcon:getMsgNum(...)
    if self.mgr then
        return self.mgr:getMsgNum()
    end
    return 0
end

function ActivityCenterIcon:handleNewFlagAnim(newActivityUniqueId)
    self._newActivityUniqueId = newActivityUniqueId

    local newFlagShowNum = _G.amfBean("AutoPopupMgr"):getPermanentShowNum(self._newActivityUniqueId)
    if newFlagShowNum < 1 then
        self:playHasNewFlagAni()
    else
        self:stopHasNewFlagAni()
    end
end

function ActivityCenterIcon:showNewActAnim()
    if self.isDisposed then return end
    -- 资讯福利站新字只展示角标，不播放父类的新活动光圈。
    self:getRedDot():showNewActDot()
end

-- 覆写父类新字播放，保留 newAct 状态给左下角菜单汇总使用。
function ActivityCenterIcon:playHasNewFlagAni(newFlagType, forcePlay)
    if forcePlay then
        self.newAct = false
        self:stopHasNewFlagAni()
    end

    self.newAct = true
    -- 只刷新新字角标状态，不触发父类 showOtherTip。
    self:updateState()
end

-- 这两个函数是否可以简化成onTouch呢？
function ActivityCenterIcon:handleTouchEventBefore()
    if self.isDisposed then return end
    if self.heGuide and not self.heGuide.isDisposed then
        self.heGuide:removeGuide()
        self.heGuide = nil
        self:endLeftCornerGuideLayoutLock()
    end

    if self._newActivityUniqueId then
        -- 新字
        _G.amfBean("AutoPopupMgr"):sendPermanentData(self._newActivityUniqueId)
        -- 手动点击后,移除可能加入的新活动强弹，并同步后端
        _G.amfBean("PopupNewActMgr"):removeNewAutoPopPkgAct(self._newActivityUniqueId)
        _G.amfBean("PopupNewActMgr"):sendPanelManualPopup(self._newActivityUniqueId)

        self._newActivityUniqueId = nil
    end
end

function ActivityCenterIcon:handleTouchEventAfter()
    if self.isDisposed then return end
    if _G.amfBean("PopoutManager"):haveWindowOnScreen() then return end

    self.mgr:showActivityCenterPanel()

    MainSceneDC:onActivityCenterIconTapped()
end

function ActivityCenterIcon:updateState()
    if self.isDisposed then return end
    BaseIcon.updateState(self)

    if self:isStrongReward() or self:isNewAct() then
        self:playIconAnim()
    else
        self:stopIconAnim()
    end
end

-- 资讯福利站入口迁移引导使用 GuideFlagConst 持久化，只播一次。
function ActivityCenterIcon:hasMoveGuideFlag()
    return self._serverCacheManager and self._serverCacheManager:hasGuideFlag(GuideFlagConst.kActivityCenterMoveGuide)
end

-- 入口存在、未播过，并避开周五新关头部玩家屏蔽时才加引导强弹。
function ActivityCenterIcon:canShowMoveGuide()
    if self.isDisposed then return false end
    if self:hasMoveGuideFlag() then return false end
    if _G.amfBean("AutoPopupMgr"):ignoreForTopLevelPlayer() then return false end
    return true
end

-- 获取左下角池，活动中心换位引导期间需要临时锁住布局。
function ActivityCenterIcon:getLeftCornerPool()
    local iconManager = _G.amfBean("IconManager")
    return iconManager and iconManager:getPool(IconMeta.PoolType.kLeftCorner)
end

-- HeGuide 会临时把 icon 换父节点；引导期间新增 icon 先保活延迟布局，避免目标位置被中途改写。
function ActivityCenterIcon:beginLeftCornerGuideLayoutLock()
    local leftCornerPool = self:getLeftCornerPool()
    if leftCornerPool and leftCornerPool.beginGuideLayoutLock then
        leftCornerPool:beginGuideLayoutLock(self)
    end
end

-- 释放左下角引导布局锁；delay 用于等待 HeGuide 恢复父节点，dispose 时可立即兜底释放。
function ActivityCenterIcon:releaseLeftCornerGuideLayoutLock(delay)
    local leftCornerPool = self:getLeftCornerPool()
    local owner = self
    local function release()
        if leftCornerPool and leftCornerPool.endGuideLayoutLock then
            leftCornerPool:endGuideLayoutLock(owner)
        end
    end

    if delay and delay > 0 then
        setTimeOut(release, delay)
    else
        release()
    end
end

-- HeGuide 恢复父节点有 0.2 秒延迟；解锁需稍后执行，再统一消费引导期间新增的 icon。
function ActivityCenterIcon:endLeftCornerGuideLayoutLock()
    self:releaseLeftCornerGuideLayoutLock(0.25)
end

-- 场景 2 检测入口迁移引导强弹。
function ActivityCenterIcon:onActEnterStage2()
    self:tryAddMoveGuideAutoPop()
end

-- 场景 4 检测入口迁移引导强弹。
function ActivityCenterIcon:onActEnterStage4()
    self:tryAddMoveGuideAutoPop()
end

-- 加入 condition 强弹队列，延迟两帧等待 icon 层完成创建。
function ActivityCenterIcon:tryAddMoveGuideAutoPop()
    if not self:canShowMoveGuide() then return end

    local function creator()
        setTimeOut(function()
            local icon = _G.amfBean("IconManager"):getIconByIconKey(IconKey.kActCenter)
            if icon and icon.showMoveGuide then
                icon:showMoveGuide()
            else
                AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.ACTIVITY_CENTER_MOVE_GUIDE)
            end
        end, 2 / 30)
    end
    _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.ACTIVITY_CENTER_MOVE_GUIDE, creator)
end

-- 播放资讯福利站入口迁移引导；使用 HeGuide 指向左下角菜单内的 icon。
function ActivityCenterIcon:showMoveGuide()
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.ACTIVITY_CENTER_MOVE_GUIDE)
    end

    if not self:canShowMoveGuide() then
        safeRunCall(onHandleOver)
        return
    end

    IconEventCenter:dispatch(IconEvent.OPEN_ICON_POOL, IconMeta.PoolType.kLeftCorner)

    setTimeOut(function()
        if self.isDisposed or not self:canShowMoveGuide() then
            safeRunCall(onHandleOver)
            return
        end

        self:beginLeftCornerGuideLayoutLock()
        local HeGuide = require "amf.middleware.ui.kit.component.HeGuide"
        local heGuide = HeGuide:create(self, true, nil, nil, true)
        heGuide:addAccurateGuide(self, {self})
        heGuide:setMinMaxTime(nil, 5)
        heGuide:setEndCall(function()
            self.heGuide = nil
            self:endLeftCornerGuideLayoutLock()
            safeRunCall(onHandleOver)
        end)
        local contentList = {
            {ttf = "资讯福利站", color = "00A5C8FF"},
            {ttf = "已更名为"},
            {ttf = "福利站", color = "00A5C8FF"},
            {ttf = "并移至左下角菜单内，记得常来看看哦~"},
        }
        heGuide:showNpc2(contentList, 60)
        self.heGuide = heGuide

        if self._serverCacheManager then
            self._serverCacheManager:setGuideFlag(GuideFlagConst.kActivityCenterMoveGuide)
        end
    end, 0.2)
end

function ActivityCenterIcon:dispose()
    _G.amfEC:unregisterFeature(self)
    self:endLeftCornerGuideLayoutLock()
    BaseIcon.dispose(self)
end

function ActivityCenterIcon:playIconAnim()
    if self.isDisposed then return end
    if not self.iconAnim then return end
    self.iconAnim:playByName("idle", true)
end

function ActivityCenterIcon:stopIconAnim()
    if self.isDisposed then return end
    if not self.iconAnim then return end
    self.iconAnim:gotoAndStop("idle", 0.001)
end

return ActivityCenterIcon
