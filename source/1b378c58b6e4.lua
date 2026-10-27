local IconEventCenter = require "amf.feature.mainscene.module.icon.event.IconEventCenter"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"

local ActivityCenterManager = class("ActivityCenterManager")

-- 本地调试开关：强制展示资讯福利站 icon，方便测试 banner 挂载位置。
local DEV_FORCE_SHOW_ACTIVITY_CENTER_ICON = false
-- 本地调试开关：注册资讯福利站 banner 测试按钮。
local DEV_ENABLE_BANNER_TEST_BUTTON = true

function ActivityCenterManager:setPopupNewActMgr(v)
    self._popupNewActMgr = v
end

function ActivityCenterManager:setActivityMgr(activityMgr)
    self._activityMgr = activityMgr
end

function ActivityCenterManager:ctor()
    self._model = require("amf.middleware.activity.activitycenter.model.ActivityCenterModel"):create()
    self._bannerModule = require("amf.middleware.activity.activitycenter.module.ActivityCenterBannerModule"):create(self)
end

function ActivityCenterManager:initialize()
    self:registerEvents()
    self:initTestButtons()
end

function ActivityCenterManager:initTestButtons()
    if not DEV_ENABLE_BANNER_TEST_BUTTON then return end

    local function testAdd()
        --
--
--
--
--
--
--

    end

    setTimeOut( testAdd, 2)
end

function ActivityCenterManager:isDevForceShowActivityCenterIcon()
    return DEV_FORCE_SHOW_ACTIVITY_CENTER_ICON and EnvUtil:isDevelopMode()
end

function ActivityCenterManager:setLocalCache(key, value)
    self._model:setLocalCache(key, value)
end

function ActivityCenterManager:getLocalCache(key)
    return self._model:getLocalCache(key)
end

function ActivityCenterManager:getVisibleDatas()
    return self._model:getVisibleDatas()
end

function ActivityCenterManager:setVisibleData(actId, data)
    self._model:setVisibleData(actId, data)
    self:updateHomeIconBtnStatus()
    self:updateActivityCenterBannerCandidate()
end

function ActivityCenterManager:cleanupInvalidData()
    self._model:cleanupInvalidData()
end

-- 活动按钮点击调用
function ActivityCenterManager:setReward(data, value)
    if data and data.actId then
        self:setLocalCache("HasReward" .. tostring(data.actId), value)
    end
end

function ActivityCenterManager:hasReward()
    for _, data in pairs(self:getVisibleDatas()) do
        if data.actId then
            local flag = self:getLocalCache("HasReward" .. tostring(data.actId))
            local bHasReward = data.buttonText ~= "" and data.hasReward and not flag
            if bHasReward then
                return true
            end
        end
    end

    return false
end

function ActivityCenterManager:hasRewardByActId(actId)
    for _, data in pairs(self:getVisibleDatas()) do
        if data.actId and actId == data.actId then
            local flag = self:getLocalCache("HasReward" .. tostring(data.actId))
            return data.buttonText ~= "" and data.hasReward and not flag
        end
    end
end

function ActivityCenterManager:getMsgNum()
    local msgNum = 0
    for _, data in pairs(self:getVisibleDatas()) do
        local actInfo = self._activityMgr:getActInfo(data.actId)
        if actInfo then
            msgNum = msgNum + actInfo.msgNum
        end
    end
    return msgNum
end

function ActivityCenterManager:registerEvents()
    IconEventCenter:register(IconEvent.ICON_SYSTEM_READY, self.onIconSystemReady, self)
    ActivityEventCenter:register(ActivityEvent.ACTIVITY_RESOLVE_OVER, self.onActivityResolveOver, self)
    _G.amfEC:registerFeature(self)
end

-- 检查当前活动中心是否可用
function ActivityCenterManager:isEnabled()
    if not FeatureSwitch:isOpen(FeatureSwitch.Type.ACT_CENTER) then return end
    if not self._activityMgr:isEnabled() then return false end

    if not self:checkLevel() then return false end

    return true
end

-- 检查玩家等级是否达到展示活动中心的要求
function ActivityCenterManager:checkLevel()
    return _G.getTopLevelId() >= self:getCanShowLevelId()
end

function ActivityCenterManager:getCanShowLevelId()
    return 79
end

function ActivityCenterManager:showActivityCenterPanel(closeCallback)
    self:cleanupInvalidData()

    if not next(self:getVisibleDatas()) then
        CommonTipWithBtn:showTip({
            tipStr = localize("activitycenter.end.desc"),
            okInfo = {
                btnStr = "知道了",
                callback = function()
                    self:removeActivityCenterIcon()
                    safeRunCall(closeCallback)
                end
            },
        })
        return false
    end

    local scene = require_debug "amf.middleware.activity.activitycenter.view.ActivityCenterPanelVM":create()
    scene:setCloseCallback(closeCallback)
    scene:popout()
    return true
end

function ActivityCenterManager:loadActivityRes(actId, successCallback, failCallback)
    self._activityMgr:loadActivityRes(actId):next(function()
        local data = self._model:getVisibleData(actId)
        if data then
            data.panelCls = require("activity/" .. data.panelClsName)
            if data.syncFileName then
                data.sync = require("activity/" .. data.syncFileName)
            end
            self:setVisibleData(actId, data)
            safeRunCall(successCallback, data)
        end
    end, failCallback)
end

function ActivityCenterManager:buildActivityCenterIcon()
    if not self._iconSystemReady then return end
    if self.activityCenterIcon then return end

    local ActivityCenterIcon = require "amf.feature.mainscene.module.icon.view.iconbutton.ActivityCenterIcon"
    local activityCenterIcon = ActivityCenterIcon:create()
    self.activityCenterIcon = activityCenterIcon
    IconEventCenter:addIconEvent(activityCenterIcon)
end

function ActivityCenterManager:removeActivityCenterIcon()
    if not self.activityCenterIcon then return end
    if self:isDevForceShowActivityCenterIcon() then return end

    IconEventCenter:removeIconEvent(self.activityCenterIcon.iconKey)
    self.activityCenterIcon = nil
end

function ActivityCenterManager:onActivityResolveOver(event)
    if not self:isEnabled() then
        return
    end
    local data = event:getData()

    local actId = data.actId
    local result = data.result
    local activityNode = data.activityNode

    if result then
        local config = activityNode:getConfig()
        if config and config.miniGameCenterAct then
            self:buildActivityCenterIcon()
            self:setVisibleData(actId, config)
        end
    end
end

function ActivityCenterManager:onIconSystemReady()
    self._iconSystemReady = true
    if not table.isEmpty(self:getVisibleDatas()) or self:isDevForceShowActivityCenterIcon() then
        self:buildActivityCenterIcon()
    end
end

function ActivityCenterManager:onActActInitOver()
    if not self:isEnabled() then
        return
    end

    if table.isEmpty(self:getVisibleDatas()) and self.activityCenterIcon then
        self:removeActivityCenterIcon()
    elseif self.activityCenterIcon and not table.isEmpty(self:getVisibleDatas()) then
        self:updateHomeIconBtnStatus()
    end

    self:updateActivityCenterBannerCandidate()
end

function ActivityCenterManager:onActEnterStage2()
    self._bannerModule:onActEnterStage2()
end

function ActivityCenterManager:onActEnterStage4()
    self._bannerModule:onActEnterStage4()
end

-- 待重写
function ActivityCenterManager:updateHomeIconBtnStatus()
    local icon = self.activityCenterIcon

    if icon then
        -- 发现新活动
        local info = self:getNewActInfo()

        if info.hasNew then
            local actBeginTime = tostring(info.data.getBeginTime())
            icon:handleNewFlagAnim(info.newActKey)

            --不再发现新活动了
            -- self._popupNewActMgr:addNewAutoPopPkgAct(info.newActKey, icon.iconKey, actBeginTime)
        end

        icon:updateState()
    end
end

function ActivityCenterManager:updateActivityCenterBannerCandidate()
    self._bannerModule:scheduleUpdateCandidate()
end

--- 获得最新活动信息
function ActivityCenterManager:getNewActInfo()
    local latestData
    for _, v in pairs(self:getVisibleDatas()) do
        if not latestData or (v.getBeginTime() > latestData.getBeginTime()) then
            latestData = v
        end
    end
    local info = {
        hasNew = latestData and true or false,
        data = latestData,
        newActKey = tostring(latestData and latestData.actId or "none")
    }
    return info
end

function ActivityCenterManager:getActName(data)
    local index = string.find(data.cid, "/")
    if index then
        return string.sub(data.cid, index + 1)
    end
    return "none"
end

return ActivityCenterManager
