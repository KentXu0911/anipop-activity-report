local ActivityCenterDC = require "amf.middleware.activity.activitycenter.dc.ActivityCenterDC"

local ActivityCenterPanelVM = class("ActivityCenterPanelVM", AMFBasePanelVM)

function ActivityCenterPanelVM:_createPanel(...)
    local ActivityCenterPanel = require "amf.middleware.activity.activitycenter.view.ActivityCenterPanel"
    return ActivityCenterPanel:create(ActivityCenterPanelVM, ...)
end

function ActivityCenterPanelVM:init()
    self._activityCenterManager = _G.amfBean("ActivityCenterManager")

    self.panel_id = UICreateUtil:getPanelId("ActivityCenterMainPanel")
end

function ActivityCenterPanelVM:firstLoadCompleted()
    self:initData()
end

function ActivityCenterPanelVM:secondLoadCompleted()
    self:callViewFunc("pretreat")
    self:callViewFunc("initItems", self.itemDatas)
end

function ActivityCenterPanelVM:recycle()
    AMFBasePanelVM.recycle(self)
    self:_unscheduleUpdate()
    self._activityCenterManager:updateHomeIconBtnStatus()
end

function ActivityCenterPanelVM:onEnterPanelRun()
    self:activateTimer(1) -- 每秒刷新一次
end

function ActivityCenterPanelVM:initData()
    local datas = table.clone(self._activityCenterManager:getVisibleDatas())
    local newActData
    self.itemDatas = {}

    for _, data in pairs(datas) do
        data.redTag = nil
        data.panel_id = self.panel_id
        self.itemDatas[#self.itemDatas + 1] = data
        local beginTime1 = data.getBeginTime()
        local beginTime2 = newActData and newActData.getBeginTime() or nil
        if not newActData or (beginTime1 > beginTime2 or (beginTime1 == beginTime2 and data.actId > newActData.actId)) then
            newActData = data
        end
    end
    if newActData then
        newActData.yellowTag = false
        newActData.redTag = true
    end
    table.sort(self.itemDatas, function(a, b)
        local top_a = a.needTop()
        local top_b = b.needTop()
        if top_a ~= top_b then return top_a end
        local beginTime_a = a.getBeginTime()
        local beginTime_b = b.getBeginTime()
        if beginTime_a ~= beginTime_b then return beginTime_a > beginTime_b end
        return a.actId > b.actId
    end)
end

-- 有活动结束，移除刷新
function ActivityCenterPanelVM:refreshView()
    if self.isDisposed then return end
    local deletedDatas = {}
    for _, v in ipairs(self.itemDatas) do
        if not v:isSupport() then
            table.insert(deletedDatas, v)
        end
    end

    if #deletedDatas > 0 then
        for _, v in ipairs(deletedDatas) do
            local data, index = table.findItem(self.itemDatas, v)
            self:callViewFunc("removeItemNode", data, index)
            table.remove(self.itemDatas, index)
        end
        self:callViewFunc("refreshView")

        if #self.itemDatas == 0 then
            CommonTip:showTip(localize("activitycenter.end.desc"))
            self:onCloseBtnTapped()
            self._activityCenterManager:removeActivityCenterIcon()
        else
            CommonTip:showTip("资讯福利站内容已更新~")
        end
    end
end

-- ViewModel层：处理业务逻辑，决定显示什么类型的面板
function ActivityCenterPanelVM:handleItemPanel(data)
    if self.isDisposed then return end

    if not data.panelCls then
        self:callViewFunc("showLoadingPanel", data)
        self._activityCenterManager:loadActivityRes(data.actId, function(data)
            if self.isDisposed then return end
            self:callViewFunc("showItemPanel", data)
        end, function()
            ALog.error("ActivityCenterPanelVM:handleItemPanel() - Failed to load activity resources for actId:",
                data.actId)
        end)
    elseif data.panelCls then
        self:callViewFunc("showItemPanel", data)
    end
end

-- 激活定时器，间隔interval刷新一次
function ActivityCenterPanelVM:activateTimer(interval)
    if self.isDisposed then return end
    self:_scheduleUpdate(interval)
end

function ActivityCenterPanelVM:_onTick()
    if self.isDisposed then return end
    self:refreshView()
end

function ActivityCenterPanelVM:_scheduleUpdate(interval)
    self:_unscheduleUpdate()

    self._tickId = CCDirector:sharedDirector():getScheduler():scheduleScriptFunc(function()
        self:_onTick()
    end, interval, false)
end

function ActivityCenterPanelVM:_unscheduleUpdate()
    if self._tickId then
        CCDirector:sharedDirector():getScheduler():unscheduleScriptEntry(self._tickId)
        self._tickId = nil
    end
end

-- 展示出某个活动打点
function ActivityCenterPanelVM:showActDc(positionY, height, itemHeight)
    if self.isDisposed then return end
    self.actDcList = self.actDcList or {}
    local itemVerticalMargin = 5
    for i, v in ipairs(self.itemDatas) do
        if not self.actDcList[v.actId] then
            local interval = (i - 1) * itemVerticalMargin
            local interval2 = math.max(interval - itemVerticalMargin, 0)
            local maxY = i * itemHeight + interval - 22
            local minY = (i - 1) * itemHeight + interval2 - height + 6.5
            if positionY >= minY and positionY <= maxY then
                self.actDcList[v.actId] = true
                ActivityCenterDC:dc("brilliant", "message_show", self._activityCenterManager:getActName(v), nil, nil,
                    nil, { panel_id = self.panel_id })
            end
        end
    end
end

-- 展示面板时时的操作
function ActivityCenterPanelVM:showPanelDc()
    -- 1 = self.fromGuide and 2 or 1
    ActivityCenterDC:dc("brilliant", "main_panel_show", 1, nil, nil, nil,
        { panel_id = self.panel_id })
end

return ActivityCenterPanelVM
