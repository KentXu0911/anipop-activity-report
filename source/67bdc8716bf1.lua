local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"
local OperationQueue = require "amf.feature.localactivity.pengpeng2026.module.PengPeng2026OperationQueue"
local AttractPanelHelper = require "amf.feature.localactivity.pengpeng2026.module.PengPeng2026AttractPanelHelper"
local Meta = require "amf.feature.localactivity.pengpeng2026.config.PengPeng2026Config"
local Log = require "amf.feature.localactivity.pengpeng2026.config.PengPeng2026Log"

local Manager = class("PengPeng2026Manager", BaseFeatureManager)

-- Manager 初始化入口：只装配活动级子模块，不在这里拉取后端数据。
function Manager:_init()
    self:initSubFunction()

    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
    PropEventCenter:register(PropEvent.RESOLVE_ICON, self._onResolveIcon, self)
end

-- 初始化本地操作队列；队列只缓存操作，真实协议由 Manager 后续统一触发。
function Manager:initSubFunction()
    self.operationQueue = OperationQueue:create(self)
    self.operationQueue:initOperationList()
end

-- 返回活动常量路径，供 BaseFeatureManager 初始化 Config。
function Manager:_getConstPath()
    return "amf.feature.localactivity.pengpeng2026.config.PengPeng2026Config"
end

-- 返回活动数据模型路径，供 BaseFeatureManager 初始化 Model。
function Manager:_getModelPath()
    return "amf.feature.localactivity.pengpeng2026.model.PengPeng2026Model"
end

function Manager:setAutoPopupMgr(manager)
    self.autoPopupMgr = manager
end

-- 声明基础活动插件；协议和操作队列先按 module 管理，避免和 Plug 职责混在一起。
function Manager:_getExtraPlugsConfigList()
    return {
        {key = "Panel"},
        {key = "AutoPop"},
        {key = "Download"},
        {key = "Rewards"},
        {
            key = "ActSend",
            path = {
                plugPath = "amf.feature.localactivity.pengpeng2026.plug.PengPeng2026SendPlug",
            },
        },
    }
end

function Manager:_getAutoPopConfigList()
    local PCP = _G.PopupCheckPoint
    local PopStage = AutoPopupConst.PopStage

    return {
        -- 主面板在条件类中紧随开心对对碰场景4引流，每日仅在场景4强弹1次。
        {
            checkPoint = PCP.PENGPENG2026_MAIN_PANEL_STAGE4,
            stages = {PopStage.STAGE_FOUR},
            check = function()
                return self:checkCanPopMainPanelStage4()
            end,
            creator = function(_, onPopOver)
                return function()
                    self:popMainPanelStage4(onPopOver)
                end
            end,
        },
        -- 收集物达到50时，引流面板紧随主面板，每日场景4强弹1次。
        {
            checkPoint = PCP.PENGPENG2026_ATTRACT_PANEL_STAGE4,
            stages = {PopStage.STAGE_FOUR},
            check = function()
                return self:checkCanPopAttractPanel()
            end,
            creator = function(_, onPopOver)
                return function()
                    self:popAttractPanel(onPopOver)
                end
            end,
        },
    }
end

-- 主活动期可玩判断；时间字段缺失时 Model:isInMainTime 会自然返回 false。
function Manager:isEnabled()
    return self:getModel():isInMainTime()
end

-- 活动广义可见判断；主活动期和领奖期都允许入口或红点逻辑继续查询。
function Manager:isEnabled2()
    return self:getModel():isInMainTime() or self:getModel():isInRewardTime()
end

function Manager:isEnabledInLevel()
    return self:isEnabled()
end

function Manager:getActShowName()
    return self:getConst().actChName
end

function Manager:getMainEndTime()
    return self:getModel():getMainEndTime()
end

function Manager:createActIconNode()
    return UICreateUtil:createSpriteFile("amf/activity/pengpeng2026/icon.png")
end

function Manager:getCurAvailableBuffAndEndTime()
    local endTime = tonumber(self:getModel():getScoreBuff20EndTime()) or 0
    if endTime > TimeKit:timeInMillis() then
        return 0.2, endTime
    end
    return 0, 0
end

function Manager:getTimeLimitRateEndTime()
    return tonumber(self:getModel():getDoubleCollectBuffEndTime()) or 0
end

function Manager:getInLevelActData()
    local endTime = self:getTimeLimitRateEndTime()
    return {
        hasTimeLimiteBuff = endTime > TimeKit:timeInMillis(),
        buffEndTime = endTime,
    }
end

function Manager:updatePassLevelData(data, collectionCount, collectionMap)
    if not data or not data.settleMentState then return end

    AttractPanelHelper.consumeSuppressPassCount(self)

    local collectionId = tostring(self:getConst().inLevelCollectionId)
    local count = tonumber(collectionMap and collectionMap[collectionId]) or tonumber(collectionCount) or 0
    if count > 0 then
        -- 关卡外负责收集物的落库或换算；关卡内接入不修改任何关卡外业务字段。
        self:getModel():addLaunchOpportunity(count)
        self:updateTipView()
    end
end

-- 接收活动框架下发的数据和配置，统一写入 Model。
function Manager:fromServer(data, config)
    if not self.downloadPlug:checkDownloadSuccess() then
        self.downloadPlug:startDownload()
    end
    self:getModel():fromServer(data, config)
end

-- 打开正式活动面板；面板创建和关闭回调继续走活动框架 Panel 插件。
function Manager:openActivity(closeCallback, extra, userClick)
    self:callActFunc("openActivity", {
        failCallback = closeCallback,
        endCallback = closeCallback,
        extra = extra,
        userClick = userClick,
    })
end

function Manager:checkCanPopMainPanelStage4()
    if not self:isEnabled() then
        return false
    end
    local minLaunchOpportunity = self:getConst().MainPanel.MIN_LAUNCH_OPPORTUNITY
    local launchOpportunity = tonumber(self:getModel():getLaunchOpportunity()) or 0
    return launchOpportunity >= minLaunchOpportunity
end

function Manager:popMainPanelStage4(onPopOver)
    if not self:checkCanPopMainPanelStage4() then
        safeRunCall(onPopOver)
        return false
    end

    -- 同组内主面板优先；只在引流项实际入队时移除并记录三关延后。
    local attractCheckPoint = _G.PopupCheckPoint.PENGPENG2026_ATTRACT_PANEL_STAGE4
    local attractQueue = self.autoPopupMgr:getPopupQueueByCheckPoint(attractCheckPoint)
    local isAttractPanelOverlapped = attractQueue and
        attractQueue[attractCheckPoint] ~= nil and
        self:checkCanPopAttractPanel()
    self.autoPopupMgr:removePopupConfig(attractCheckPoint)
    if isAttractPanelOverlapped then
        self:markAttractPanelSuppressedByMainPanelAutoPop()
    end
    self:openActivity(onPopOver, {from = "auto_popup_stage4"}, false)
    return true
end

-- 主面板同轮强弹时调用；只记录后续三次过关抑制，不计入引流面板每日弹出次数。
function Manager:markAttractPanelSuppressedByMainPanelAutoPop()
    return AttractPanelHelper.markSuppressedByMainPanelAutoPop(self)
end

-- 只做引流面板可弹条件检测；不消耗过关抑制次数，也不维护框架每日次数。
function Manager:checkCanPopAttractPanel()
    if not self.downloadPlug:checkDownloadSuccess() then
        self.downloadPlug:startDownload()
        return false
    end
    return AttractPanelHelper.checkCanPop(self)
end

-- 弹出前再次校验，避免旧队列项绕过三关延后状态；按钮点击进入活动主界面。
function Manager:popAttractPanel(onPopOver, force)
    if not self.downloadPlug:checkDownloadSuccess() then
        safeRunCall(onPopOver)
        return false
    end
    local canPop = force == true or self:checkCanPopAttractPanel()
    if not canPop then
        safeRunCall(onPopOver)
        return false
    end
    return AttractPanelHelper.pop(self, onPopOver)
end

-- 记录一条本地操作；opType 使用 PengPeng2026Config.OpType，具体业务参数放在 info。
function Manager:addOperationInfo(opType, info)
    self.operationQueue:addOperation(info, opType)
end

-- 获取当前可发送的待同步操作，返回 sendIds 和 sendInfos 两个列表。
function Manager:getCanSendList()
    return self.operationQueue:getCanSendList()
end

-- 返回等待发送的操作数量，供活动侧判断批量同步触发点。
function Manager:getWaitToSendOperationCount()
    return self.operationQueue:getWaitToSendCount()
end

-- 标记一批操作正在发送；防止同一批操作被重复取出。
function Manager:markOperationSending(sendIds)
    self.operationQueue:markSending(sendIds)
end

-- 标记一批操作发送流程结束，并从本地队列清理。
function Manager:markOperationFinished(sendIds)
    self.operationQueue:markSendFinished(sendIds)
end

-- 按服务端已确认 lastSeq 重置后续新操作游标；确定性拒绝或主动丢弃本批后使用。
function Manager:resetOperationSeqFromServer()
    self.operationQueue:resetNextSeqFromServer()
end

-- 标记一批操作发送失败，恢复为待发送，等待下次同步重试。
function Manager:markOperationFailed(sendIds)
    self.operationQueue:markSendFailed(sendIds)
end

-- 清空本地操作队列；用于活动周期重置或后端状态强制覆盖。
function Manager:clearOperationList()
    self.operationQueue:clearOperationList()
end

-- 统一同步触发点；Cocos 活动侧 Model:flushOperationList 负责真实协议发送。
function Manager:flushOperationList(reason, callback)
    safeRunCall(callback, false, reason)
end

-- 协议发奖成功后写入普通奖励背包；展示动画由活动侧按 rewardList 控制。
function Manager:addRewardsNormal(rewardItems, params)
    self:callPlug("Rewards", "addRewardsNormal", rewardItems, params)
end

-- 输出一条活动日志；调用方传入模块 ID 和是否需要在最终输出时 tts table。
function Manager:printLog(moduleId, needTts, ...)
    Log.print(moduleId, needTts, ...)
end

-- 返回活动日志模块枚举，活动侧测试工具使用枚举避免硬编码模块 ID。
function Manager:getLogModule()
    return Log.Module
end

-- 输出内存日志历史；moduleId 为空时输出全部日志。
function Manager:dumpLog(moduleId, needTtsOverride)
    return Log.dump(moduleId, needTtsOverride)
end

function Manager:updateTipView()
    if not self:isEnabled() then return end
    self.actPlug:updateTipView()
end

function Manager:hasReward()
    local model = self:getModel()
    return model and model:hasProgressRewardToClaim() or false
end

function Manager:getMsgNum()
    -- Icon 角标数字只在正式期展示，预热期和领奖期统一清零。
    if not self:isEnabled() then return 0 end
    local model = self:getModel()
    return model and math.max(0, tonumber(model:getLaunchOpportunity()) or 0) or 0
end

function Manager:_onResolveIcon(event)
    if not event then return end
    local data = event:getData()
    if not data or not data.callback then return end

    local itemId = tonumber(data.itemId)
    local iconInfo = Meta.StaticItemIconInfo and Meta.StaticItemIconInfo[itemId]

    if iconInfo then
        data.callback({
            Atlas = iconInfo.Atlas or "",
            Frame = iconInfo.Frame,
            IsPropPng = iconInfo.IsPropPng,
        })
        return
    end
end

function Manager:_onCustomGain(event)
    if not event then return end
    local reward = event:getData()
    if not reward then return end

    local id = tonumber(reward.itemId)
    local num = tonumber(reward.num) or 0
    local Const = self:getConst()
    local model = self:getModel()

    if id == Const.collectId then
        model:addLaunchOpportunity(num)
        self:updateTipView()
    elseif id == Const.percent20Buff then
        model:addScoreBuff20Time(num)
    elseif id == Const.doubleBuff then
        model:addDoubleCollectBuffTime(num)
    end
end

return Manager
