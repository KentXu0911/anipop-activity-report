local BaseIcon = require "amf.feature.mainscene.module.icon.view.BaseIcon"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local IconMeta = require "amf.feature.mainscene.module.icon.config.IconMeta"

-- 福袋派对右下角入口。入口是否展示跟随活动本地 ready 状态，避免活动未开启时空展示。
local LuckyBagPartyIcon = class("LuckyBagPartyIcon", BaseIcon)

LuckyBagPartyIcon.MOVE_GUIDE_END_VER = 162
-- 本地调试开关：强制展示福袋派对右下角入口，方便检查入口迁移样式。
local DEV_FORCE_SHOW_LUCKY_BAG_PARTY_ICON = false

-- 创建 icon 实例。
function LuckyBagPartyIcon:create()
    local icon = LuckyBagPartyIcon.new()
    icon:init()
    return icon
end

-- 初始化入口、事件监听、新字状态和强弹场景监听。
function LuckyBagPartyIcon:init()
    BaseIcon.init(self, IconKey.kLuckyBagParty)
    self.mgr = _G.amfBean("LuckyBagPartyMgr")
    self._serverCacheManager = _G.amfBean("ServerCacheManager")
    _G.amfEC:registerFeature(self)
    self:registerEvents()
    self:initNewFlag()
    self:refreshActEndTimer()
    self:updateState()
end

-- 使用主场景 icon 图集里的福袋帧。
function LuckyBagPartyIcon:getIconSpriteFrameName()
    return "luckyBag"
end

-- 延迟获取 mgr，避免初始化顺序导致空引用。
function LuckyBagPartyIcon:getMgr()
    if not self.mgr then
        self.mgr = _G.amfBean("LuckyBagPartyMgr")
    end
    return self.mgr
end

function LuckyBagPartyIcon:isDevForceShowOnly()
    return DEV_FORCE_SHOW_LUCKY_BAG_PARTY_ICON and EnvUtil:isDevelopMode()
end

-- 活动 Config.isSupport 已完整通过后，才展示迁移后的右下角入口。
function LuckyBagPartyIcon:canShow()
    if self:isDevForceShowOnly() then return true end

    local mgr = self:getMgr()
    if not mgr then return false end
    return mgr.hasConfigSupportPassed and mgr:hasConfigSupportPassed()
end

-- actInfo.extra 里带后端下发的活动时间等动态信息。
function LuckyBagPartyIcon:getActInfoExtra()
    local mgr = self:getMgr()
    local actInfo = mgr and mgr:getActInfo()
    if actInfo and actInfo.extra then
        return table.deserialize(actInfo.extra)
    end
end

-- actInfo 时间是毫秒，icon 新字 uniqueKey 使用秒级开始时间。
function LuckyBagPartyIcon:getActInfoBeginTime()
    local extra = self:getActInfoExtra()
    local beginTs = extra and tonumber(extra.beginTs)
    if beginTs and beginTs > 0 then
        return math.floor(beginTs / 1000)
    end
end

-- 新字记录 key 只取 actInfo 开始时间；福袋入口可能早于活动 Config 初始化，不能兜底读 Config 时间。
function LuckyBagPartyIcon:getNewActUniqueKey()
    local mgr = self:getMgr()
    local beginTime = self:getActInfoBeginTime()
    if beginTime and mgr then
        return mgr.ACT_ID .. "_" .. beginTime
    end
end

-- 新字展示时间只跟随 actInfo；没有完整时间说明活动数据未就绪，不展示新字。
function LuckyBagPartyIcon:isInNewFlagTime()
    local extra = self:getActInfoExtra()
    local beginTs = extra and tonumber(extra.beginTs)
    local endTs = extra and tonumber(extra.endTs)
    if beginTs and endTs then
        local now = TimeKit:timeInSec()
        return now >= math.floor(beginTs / 1000) and now <= math.floor(endTs / 1000)
    end
    return false
end

-- 读取当前入口展示结束时间，优先使用 actInfo，其次兜底本地活动数据。
function LuckyBagPartyIcon:getActDisplayEndTime()
    local extra = self:getActInfoExtra()
    local endTs = extra and tonumber(extra.endTs)
    if endTs and endTs > 0 then
        return math.floor(endTs / 1000)
    end

    local mgr = self:getMgr()
    local localDataServer = mgr and mgr.getLocalDataServer and mgr:getLocalDataServer()
    if localDataServer and localDataServer.getActMainEndTime then
        local endTime = localDataServer:getActMainEndTime()
        if endTime and endTime > 0 then
            return endTime
        end
    end
end

-- 停止活动结束刷新 timer，避免 icon dispose 后旧回调继续访问节点。
function LuckyBagPartyIcon:stopActEndTimer()
    if self.actEndTimerId then
        TimerUtil.removeAlarm(self.actEndTimerId)
        self.actEndTimerId = nil
    end
end

-- 注册活动结束刷新 timer；到期后入口需要主动触发右下角池重算并删除自己。
function LuckyBagPartyIcon:refreshActEndTimer()
    self:stopActEndTimer()
    if self:isDevForceShowOnly() then return end

    local endTime = self:getActDisplayEndTime()
    local now = TimeKit:timeInSec()
    if not endTime or endTime <= now then return end

    -- isActInMain 使用 now <= endTime，延后一秒刷新，确保边界秒已经跨出活动期。
    self.actEndTimerId = TimerUtil.addAlarm(function()
        if self.isDisposed then return end
        self.actEndTimerId = nil
        self:onActDisplayExpired()
    end, math.max(endTime - now + 1, 0.1))
end

-- 活动展示到期后清理新字状态，并要求右下角 born icon 列表重新按 canShow 计算。
function LuckyBagPartyIcon:onActDisplayExpired()
    if self.isDisposed then return end

    self:stopHasNewFlagAni()
    local mgr = self:getMgr()
    if mgr and mgr.setConfigSupportPassed then
        mgr:setConfigSupportPassed(false)
    end
    local rightCornerPool = _G.amfBean("IconManager"):getPool(IconMeta.PoolType.kRightCorner)
    if rightCornerPool and rightCornerPool.updateBornClass then
        rightCornerPool:updateBornClass()
    end
end

-- 获取右下角池，福袋换位引导期间需要临时锁住布局。
function LuckyBagPartyIcon:getRightCornerPool()
    local iconManager = _G.amfBean("IconManager")
    return iconManager and iconManager:getPool(IconMeta.PoolType.kRightCorner)
end

-- HeGuide 会临时把 icon 换父节点；引导期间新增 icon 先保活延迟布局，避免福袋原布局被中途改写。
function LuckyBagPartyIcon:beginRightCornerGuideLayoutLock()
    local rightCornerPool = self:getRightCornerPool()
    if rightCornerPool and rightCornerPool.beginGuideLayoutLock then
        rightCornerPool:beginGuideLayoutLock(self)
    end
end

-- 释放右下角引导布局锁；delay 用于等待 HeGuide 恢复父节点，dispose 时可立即兜底释放。
function LuckyBagPartyIcon:releaseRightCornerGuideLayoutLock(delay)
    local rightCornerPool = self:getRightCornerPool()
    local owner = self
    local function release()
        if rightCornerPool and rightCornerPool.endGuideLayoutLock then
            rightCornerPool:endGuideLayoutLock(owner)
        end
    end

    if delay and delay > 0 then
        setTimeOut(release, delay)
    else
        release()
    end
end

-- HeGuide 恢复父节点有 0.2 秒延迟；解锁需稍后执行，再统一消费引导期间新增的 icon。
function LuckyBagPartyIcon:endRightCornerGuideLayoutLock()
    self:releaseRightCornerGuideLayoutLock(0.25)
end

-- 初始化新字角标。
function LuckyBagPartyIcon:initNewFlag()
    if self:canShowNewFlag() then
        self:playHasNewFlagAni()
    else
        self:stopHasNewFlagAni()
    end
end

-- 新字只看活动唯一 key 是否已记录展示，以及当前是否处于活动展示时间。
function LuckyBagPartyIcon:canShowNewFlag()
    -- 仅为本地看样式强制展示入口时，不伪造新字，避免读取未完整初始化的活动时间配置。
    if self:isDevForceShowOnly() then return false end

    local uniqueKey = self:getNewActUniqueKey()
    if not uniqueKey then return false end

    local newFlagShowNum = _G.amfBean("AutoPopupMgr"):getPermanentShowNum(uniqueKey) or 0
    return newFlagShowNum < 1 and self:isInNewFlagTime()
end

function LuckyBagPartyIcon:showNewActAnim()
    if self.isDisposed then return end
    -- 福袋新字只展示角标，不播放父类的新活动光圈。
    self:getRedDot():showNewActDot()
end

-- 覆写父类新字播放，保留 newAct 状态给右下角加号汇总使用。
function LuckyBagPartyIcon:playHasNewFlagAni(newFlagType, forcePlay)
    if forcePlay then
        self.newAct = false
        self:stopHasNewFlagAni()
    end

    self.newAct = true
    -- 只刷新新字角标状态，不触发父类 showOtherTip。
    self:updateState()
end

-- 右下角收起态汇总是否把福袋作为“新”展示。
function LuckyBagPartyIcon:todayCanShow()
    return self:canShow() and self:canShowNewFlag()
end

-- 活动面板打开后清除新字记录。
function LuckyBagPartyIcon:cancelNewActState()
    local uniqueKey = self:getNewActUniqueKey()
    if uniqueKey then
        _G.amfBean("AutoPopupMgr"):sendPermanentData(uniqueKey)
    end
    self:stopHasNewFlagAni()
end

-- 监听活动打开事件，活动框架拉起成功后清新字。
function LuckyBagPartyIcon:registerEvents()
    self.onActivityOpened = function(event)
        local data = event:getData()
        local mgr = self:getMgr()
        if mgr and tonumber(data.actId) == tonumber(mgr.ACT_ID) then
            self:cancelNewActState()
        end
    end
    ActivityEventCenter:register(ActivityEvent.ACTIVITY_OPENED, self.onActivityOpened)

    self.onActInfosUpdate = function()
        if self.isDisposed then return end
        setTimeOut(function()
            if self.isDisposed then return end
            self:refreshActEndTimer()
            if not self:canShow() then
                self:onActDisplayExpired()
            end
        end, 0)
    end
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActInfosUpdate)
end

-- 释放活动事件监听。
function LuckyBagPartyIcon:unregisterEvents()
    if self.onActivityOpened then
        ActivityEventCenter:unregister(ActivityEvent.ACTIVITY_OPENED, self.onActivityOpened)
        self.onActivityOpened = nil
    end
    if self.onActInfosUpdate then
        ActivityEventCenter:unregister(ActivityEvent.ACT_INFOS_UPDATE, self.onActInfosUpdate)
        self.onActInfosUpdate = nil
    end
end

-- 福袋换位引导使用 GuideFlagConst 持久化，只播一次。
function LuckyBagPartyIcon:hasMoveGuideFlag()
    return self._serverCacheManager and self._serverCacheManager:hasGuideFlag(GuideFlagConst.kLuckyBagPartyMoveGuide)
end

-- 换位引导需入口可展示、未播过，并避开周五新关头部玩家屏蔽。
function LuckyBagPartyIcon:canShowMoveGuide()
    if not self:canShow() then return false end
    if not self:isMoveGuideVersionSupport() then return false end
    if self:hasMoveGuideFlag() then return false end
    if _G.amfBean("AutoPopupMgr"):ignoreForTopLevelPlayer() then return false end
    return true
end

-- 福袋换位引导在 160 版本后失效。
function LuckyBagPartyIcon:isMoveGuideVersionSupport()
    local versionParts = string.split(tostring(_G.bundleVersion or ""), ".")
    local ver = tonumber(string.match(tostring(versionParts[2] or ""), "^(%d+)"))
    return ver and ver <= self.MOVE_GUIDE_END_VER
end

-- 场景 2 检测换位引导强弹。
function LuckyBagPartyIcon:onActEnterStage2()
    self:tryAddMoveGuideAutoPop()
end

-- 场景 4 检测换位引导强弹。
function LuckyBagPartyIcon:onActEnterStage4()
    self:tryAddMoveGuideAutoPop()
end

-- 加入 condition 强弹队列，延迟两帧等待 icon 层完成创建。
function LuckyBagPartyIcon:tryAddMoveGuideAutoPop()
    if not self:canShowMoveGuide() then return end

    local function creator()
        setTimeOut(function()
            local icon = _G.amfBean("IconManager"):getIconByIconKey(IconKey.kLuckyBagParty)
            if icon and icon.showMoveGuide then
                icon:showMoveGuide()
            else
                AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.LUCKY_BAG_PARTY_MOVE_GUIDE)
            end
        end, 2 / 30)
    end
    _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.LUCKY_BAG_PARTY_MOVE_GUIDE, creator)
end

-- 播放福袋换位引导；使用 HeGuide 指向右下角池内的福袋 icon。
function LuckyBagPartyIcon:showMoveGuide()
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.LUCKY_BAG_PARTY_MOVE_GUIDE)
    end

    if not self:canShowMoveGuide() then
        safeRunCall(onHandleOver)
        return
    end

    IconEventCenter:dispatch(IconEvent.OPEN_ICON_POOL, IconMeta.PoolType.kRightCorner)

    setTimeOut(function()
        if self.isDisposed or not self:canShowMoveGuide() then
            safeRunCall(onHandleOver)
            return
        end

        self:beginRightCornerGuideLayoutLock()
        local HeGuide = require "amf.middleware.ui.kit.component.HeGuide"
        local heGuide = HeGuide:create(self, true, nil, nil, true)
        heGuide:addAccurateGuide(self, {self})
        heGuide:setMinMaxTime(nil, 5)
        heGuide:setEndCall(function()
            self.heGuide = nil
            self:endRightCornerGuideLayoutLock()
            safeRunCall(onHandleOver)
        end)
        local contentList = {
            {ttf = "福袋派对", color = "00A5C8FF"},
            {ttf = "已开启，以后请到右下角“+”内寻找福袋派对哦~"},
        }
        heGuide:showNpc2(contentList, 60)
        self.heGuide = heGuide

        if self._serverCacheManager then
            self._serverCacheManager:setGuideFlag(GuideFlagConst.kLuckyBagPartyMoveGuide)
        end
    end, 0.2)
end

-- 点击入口拉起福袋活动。
function LuckyBagPartyIcon:onTouch()
    BaseIcon.onTouch(self)
    if self.isDisposed then return end
    if self.heGuide and not self.heGuide.isDisposed then
        self.heGuide:removeGuide()
        self.heGuide = nil
        self:endRightCornerGuideLayoutLock()
    end

    local mgr = self:getMgr()
    if mgr then
        mgr:openActivity(nil, nil, true)
    end
end

-- 释放 feature 事件和活动事件监听。
function LuckyBagPartyIcon:dispose()
    _G.amfEC:unregisterFeature(self)
    self:stopActEndTimer()
    self:unregisterEvents()
    self:endRightCornerGuideLayoutLock()
    BaseIcon.dispose(self)
end

return LuckyBagPartyIcon
