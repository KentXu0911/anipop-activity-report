local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
local Event = _G["superbirdshareEvent"] or require "amf.feature.localactivity.superbirdshare.event.Event"

local Manager = class("superbirdshareManager", BaseFeatureManager)

--[[
Manager 职责：
1. 对外提供活动 facade：打开活动、面板托管、引导标记、本地缓存、打点等常用入口。
2. 同步服务端 actInfo 到 Model；核心业务状态仍放 Model。
3. 提供跨天/跨期业务 hook；Act/Notify 使用 BaseFeatureManager 默认 Plug，不在额外 Plug 中重复声明。
]]

-- =============================================================================
-- BaseFeatureManager 配置
-- =============================================================================

function Manager:_getConstPath()
    return "amf.feature.localactivity.superbirdshare.const.Const"
end

function Manager:_getModelPath()
    return "amf.feature.localactivity.superbirdshare.model.Model"
end

function Manager:_getExtraPlugsConfigList()
    -- TODO: 根据活动需要增删 Plug，如 Download/Buy/Rewards/Scheduler/AutoPop/LocalPush
    return {
        {
            key = "Panel",
            path = {
                plugPath = "amf.feature.localactivity.superbirdshare.plug.PanelPlug",
            },
        },
        {
            key = "DC",
            path = {
                plugPath = "amf.feature.localactivity.superbirdshare.plug.DCPlug",
            },
        },
        {
            key = "AutoPop",
        },
    }
end

-- LocalActivityDI 注入 AutoPopupMgr 时由 Spring 调用；仅保存引用，避免在业务层复制框架计数。
function Manager:setAutoPopupMgr(manager)
    self.autoPopupMgr = manager
end

-- 强弹的业务 check 与面板 creator 暂保留模板入口；业务字段和真实面板接入后再补齐。
function Manager:_getAutoPopConfigList()
    local PopStage = AutoPopupConst.PopStage

    return {
        {
            -- 正式期首次参与活动，主面板场景4强弹1次；按期频次由框架限制控制。
            checkPoint = PopupCheckPoint.SUPER_BIRD_SHARE_FIRST_STAGE4,
            stages = { PopStage.STAGE_FOUR },
            check = function()
                return self:checkCanPopFirstMainPanelStage4()
            end,
            creator = function(_, onPopOver)
                return function()
                    self:popFirstMainPanelStage4(onPopOver)
                end
            end,
        },
        {
            -- 有活动奖励可领取时，主面板场景2/4强弹；场景2每天最多一次，场景4不限制。
            checkPoint = PopupCheckPoint.SUPER_BIRD_SHARE_REWARD,
            stages = { PopStage.STAGE_TWO, PopStage.STAGE_FOUR },
            check = function(stageParams)
                return self:checkCanPopRewardMainPanel(stageParams)
            end,
            creator = function(stageParams, onPopOver)
                return function()
                    self:popRewardMainPanel(onPopOver, stageParams)
                end
            end,
        },
    }
end

-- 强弹的平台保护：只在本活动支持的端生效。
-- 口径必须和包外 Config.isPlatformSupport 保持一致（那边是 isSupport 的入口判断）：
-- 小游戏只认微信/抖音，App 端不含鸿蒙。服务端下发了 actInfo 但端不支持时，强弹也不许弹。
function Manager:isPlatformSupport()
    if not EnvUtil then return false end
    -- 新规则：鸿蒙端不上本活动
    if EnvUtil:isOhos() then return false end
    if EnvUtil:isMiniGame() then
        return EnvUtil:isWXMiniGame() or EnvUtil:isDYMiniGame()
    end
    return EnvUtil:isApp()
end

-- TODO: 读取正式期、首次参与等已确认的业务状态；不要在此维护强弹次数。
function Manager:checkCanPopFirstMainPanelStage4()
    if not self:isPlatformSupport() then return false end
    if not self:isEnabled() then return false end
    if not self:getModel():isInMainTime() then return false end

    local cacheKey = self:getConst().LocalCacheKey.MainPanelOpened
    return not self:getFlagFromLocalByKey(cacheKey, false)
end

function Manager:popFirstMainPanelStage4(onPopOver)
    if not self:checkCanPopFirstMainPanelStage4() then
        safeRunCall(onPopOver)
        return
    end

    -- 需求：场景4出现前若玩家手动进入过活动，则不再强弹。
    self:setFlagToLocalByKey(self:getConst().LocalCacheKey.MainPanelOpened, false, true)

    local opened = self:openActivity({
        userClick = false,
        endCallback = onPopOver,
        failCallback = onPopOver,
        extra = {
            source = "auto_popup_first_stage4",
            autoPopType = "first",
        },
    })
    if opened == false then safeRunCall(onPopOver) end
end

--- 奖励强弹资格。
--- 场景2每天最多强弹一次（needTime=true 的本地标记按自然日失效），场景4不做次数限制。
--- @param stageParams table|nil 框架透传的场景参数，含 popStage
function Manager:checkCanPopRewardMainPanel(stageParams)
    if not self:isPlatformSupport() then return false end
    if not self:isEnabled() then return false end
    if not self:getModel():isInMainTime() then return false end

    -- 奖励资格由服务端判断，Manager 只读取主协议结果。
    if self:getDataByKey("canReceiveReward", false) ~= true then return false end

    if not self:isRewardPopStageTwo(stageParams) then return true end

    -- 场景2每天只弹一次：needTime=true 的本地标记按自然日失效，跨天自动重置。
    local cacheKey = self:getConst().LocalCacheKey.RewardMainPanelPoppedToday
    return not self:getFlagFromLocalByKey(cacheKey, true)
end

--- 是否为场景2的奖励强弹（只有场景2受次数限制）
function Manager:isRewardPopStageTwo(stageParams)
    return type(stageParams) == "table"
        and stageParams.popStage == AutoPopupConst.PopStage.STAGE_TWO
end

function Manager:popRewardMainPanel(onPopOver, stageParams)
    if not self:checkCanPopRewardMainPanel(stageParams) then
        safeRunCall(onPopOver)
        return
    end

    -- 场景2弹过就落当日标记，避免同一天重复弹；场景4不落标记，不做限制。
    if self:isRewardPopStageTwo(stageParams) then
        self:setFlagToLocalByKey(self:getConst().LocalCacheKey.RewardMainPanelPoppedToday, true, true)
    end

    local opened = self:openActivity({
        userClick = false,
        endCallback = onPopOver,
        failCallback = onPopOver,
        extra = {
            source = "auto_popup_reward",
            autoPopType = "reward",
        },
    })
    if opened == false then safeRunCall(onPopOver) end
end

function Manager:_init()
    self:addEventDispatcher()
    self:registerEvents()
    -- 打点统一收口在 dc/Dc.lua，包外通过 Manager:getDC() 取。
    self._dc = require("amf.feature.localactivity.superbirdshare.dc.Dc")
    self._dc:init(self)
    -- 分享助力：被帮助方打开分享卡片时会派发 ResponseHelp 事件，必须注册处理器才会发助力协议
    self._responseHelpHandler = require("amf.feature.localactivity.superbirdshare.share.ResponseSuperBirdShareHelpShareHandler"):create()
    self:getModel():onTimeChanged(function()
        self:_registerCrossPeriodCallbacks()
    end)
    -- 非首次登录：本地缓存已有时间，直接触发注册
    local model = self:getModel()
    if model:getMainBeginTimeInSec() and model:getMainBeginTimeInSec() > 0 then
        self:_registerCrossPeriodCallbacks()
    end
end

function Manager:registerEvents()
    self:callActFunc("registerActInfoUpdate", "onActInfosUpdate")
end

-- =============================================================================
-- 基础状态 / Icon
-- =============================================================================

function Manager:getActId()
    return self:getConst().actId
end

function Manager:isEnabled()
    return self:getModel():isDataEnabled()
end

-- icon 奖字：今日是否有待领取的奖励。
-- 奖励资格口径和强弹 checkCanPopRewardMainPanel() 一致，都读 Model.canReceiveReward；
-- 强弹在场景2还有「每天最多一次」的本地标记限制，icon 不受该限制影响。
-- 这个字段两个渠道都会写：主协议 rewardPending、actInfo.extra.rewardPending。
-- 框架 ActPlug:updateTipView() 读这里的结果写回 actInfo.reward，再刷 icon。
function Manager:hasReward()
    if not self:isEnabled() then return false end
    return self:getModel():getDataByKey("canReceiveReward", false) == true
end

function Manager:getMsgNum()
    if not self:isEnabled() then return 0 end
    return self:getModel():getMsgNum()
end

function Manager:updateTipView()
    self:callActFunc("updateTipView")
end

-- =============================================================================
-- 打开活动 / 面板托管
-- =============================================================================

function Manager:openActivity(delegate)
    delegate = delegate or {}
    delegate.actId = delegate.actId or self:getActId()
    self:callActFunc("openActivity", delegate)
end

function Manager:managePanelVM(panelVM)
    self:callPanelFunc("managePanelVM", panelVM)
end

function Manager:getPanelVMByName(panelVMName)
    return self:callPanelFunc("getPanelVMByName", panelVMName)
end

function Manager:closeAllPanels()
    local observerNum = self:getObserverNum()

    self:notify(Event.kCloseAllPanel)

    return observerNum > 0
end

-- =============================================================================
-- 服务端 actInfo / 数据 / 配置
-- =============================================================================

function Manager:syncActInfo(actInfo)
    self:getModel():syncActInfo(actInfo)
    -- Model:updateFromExtraData 已从 actInfo.extra 提取时间，时间变更会通过 onTimeChanged 回调自动注册
end

function Manager:onActInfosUpdate(event)
    local data = event and event:getData() or {}
    local actInfos = data.actInfos or {}
    local actInfo = actInfos[tostring(self:getActId())]
    if not data.fromServer or not actInfo then
        return
    end

    self:syncActInfo(actInfo)
end

function Manager:getDataByKey(key, default)
    return self:getModel():getDataByKey(key, default)
end

function Manager:setDataByKey(key, value, needSave)
    self:getModel():setDataByKey(key, value, needSave)
end

function Manager:getConfigByKey(key, default)
    return self:getModel():getConfigByKey(key, default)
end

function Manager:setConfigByKey(key, value, needSave)
    self:getModel():setConfigByKey(key, value, needSave)
end

function Manager:updateData(data)
    self:getModel():updateData(data)
end

-- =============================================================================
-- 本地缓存（保持旧活动常用方法名和签名）
-- =============================================================================

function Manager:getCacheLocalKey(key)
    return "localCache." .. (key or "defaultKey")
end

function Manager:setFlagToLocalByKey(key, needTime, value)
    if not key then return end
    if value == nil then value = true end
    self:getModel():saveFlagToLocalByKey(self:getCacheLocalKey(key), needTime, value, true)
end

function Manager:getFlagFromLocalByKey(key, needTime)
    return self:getModel():getFlagFromLocalByKey(self:getCacheLocalKey(key), needTime, true)
end

function Manager:addIntToLocalByKey(key, needTime, addNum)
    if not key then return end
    if addNum == nil then addNum = 1 end
    local beforeNum = self:getModel():getFlagFromLocalByKeyInt(self:getCacheLocalKey(key), needTime, true) or 0
    self:getModel():saveFlagToLocalByKeyInt(self:getCacheLocalKey(key), needTime, beforeNum + addNum, true)
end

function Manager:setIntFromLocalByKey(key, needTime, setNum)
    if not key then return end
    if setNum == nil then setNum = 0 end
    self:getModel():saveFlagToLocalByKeyInt(self:getCacheLocalKey(key), needTime, setNum, true)
end

function Manager:getIntFromLocalByKey(key, needTime)
    return self:getModel():getFlagFromLocalByKeyInt(self:getCacheLocalKey(key), needTime, true) or 0
end

function Manager:setStringToLocalByKey(key, needTime, value)
    if not key then return end
    if value == nil then value = "" end
    self:getModel():saveFlagToLocalByKeyStr(self:getCacheLocalKey(key), needTime, value, true)
end

function Manager:getStringFromLocalByKey(key, needTime)
    return self:getModel():getFlagFromLocalByKeyStr(self:getCacheLocalKey(key), needTime, true) or ""
end

-- =============================================================================
-- 引导标记
-- =============================================================================

function Manager:hasGuideIndex(index, checkLocalData)
    local hasIndex = self:getModel():hasGuide(index)

    if checkLocalData == nil then checkLocalData = true end
    if checkLocalData then
        local hasLocal = self:getFlagFromLocalByKey("LocalGuideId" .. index, false)
        if hasLocal then
            if not hasIndex then self:addGuideIndex(index, false) end
            hasIndex = true
        end
    end
    return hasIndex
end

function Manager:addGuideIndex(index, needSaveLocal)
    self:getModel():setGuide(index)

    if needSaveLocal == nil then needSaveLocal = true end
    if needSaveLocal then
        self:setFlagToLocalByKey("LocalGuideId" .. index, false, true)
    end

    -- TODO: 需要后端永久标记时打开。部分活动只需要本地标记，不要默认发协议。
    -- local ActCommonHttp = require "amf.middleware.activity.http.ActCommonHttp"
    -- ActCommonHttp:setActGuideFlag(self:getActId(), index, true)
end

-- =============================================================================
-- 打点
-- =============================================================================

-- 活动自己的 DC 出口（DCPlug 实例），实际打点逻辑在 dc/Dc.lua。
function Manager:dcPlug()
    return self:_getPlug("DC")
end

-- 打点模块：口径枚举、参数拼装、按天去重都在 dc/Dc.lua。
function Manager:getDC()
    return self._dc
end

function Manager:dcAct(subCategory, extraData)
    -- TODO: 按真实打点填入 subCategory，示例来自 Const.DC
    self:callDCFunc("dcAct", nil, subCategory, extraData)
end

function Manager:dcUserTrack(subCategory, extraData)
    -- TODO: 按真实打点填入 subCategory，示例来自 Const.DC
    self:callDCFunc("dcUserTrack", nil, subCategory, extraData)
end



-- =============================================================================
-- 跨天 / 跨期
-- =============================================================================

-- 活动时间确认入口
-- Config.lua:setAttributes 从 info.xml 拿到时间后通过 config.getMgr() 调用
-- 多期活动的当期时间由 Model:updateFromExtraData 从 actInfo.extra 自动提取，不经过此处
function Manager:onActivityTimeConfirmed(timeData)
    self:getModel():updateActivityTime(timeData)
    -- Model:updateActivityTime 变更时会通过 onTimeChanged 回调自动触达 _registerCrossPeriodCallbacks
end

function Manager:_registerCrossPeriodCallbacks()
    local PassDayTimer = require "amf.script.tool.timer.PassDayTimer"
    local model = self:getModel()

    self:_unregisterCrossPeriodCallbacks()

    local mainBegin = model:getMainBeginTimeInSec()
    local mainEnd = model:getMainEndTimeInSec()
    local actEnd = model:getEndTimeInSec()

    if mainBegin and mainBegin > 0 then
        if mainEnd and mainEnd ~= mainBegin then
            self._cbMainBegin = function() self:onActPassMainBegin() end
            self._cbMainEnd = function() self:onActPassMainEnd() end
            PassDayTimer:registerEndTimeCallback(mainBegin, self._cbMainBegin)
            PassDayTimer:registerEndTimeCallback(mainEnd, self._cbMainEnd)
        end
        if actEnd and actEnd ~= mainEnd then
            self._cbActEnd = function() self:onActPassActEnd() end
            PassDayTimer:registerEndTimeCallback(actEnd, self._cbActEnd)
        end
    end
end

function Manager:_unregisterCrossPeriodCallbacks()
    local PassDayTimer = require "amf.script.tool.timer.PassDayTimer"
    local model = self:getModel()
    if self._cbMainBegin then
        PassDayTimer:unregisterEndTimeCallback(model:getMainBeginTimeInSec(), self._cbMainBegin)
        self._cbMainBegin = nil
    end
    if self._cbMainEnd then
        PassDayTimer:unregisterEndTimeCallback(model:getMainEndTimeInSec(), self._cbMainEnd)
        self._cbMainEnd = nil
    end
    if self._cbActEnd then
        PassDayTimer:unregisterEndTimeCallback(model:getEndTimeInSec(), self._cbActEnd)
        self._cbActEnd = nil
    end
end

-- Base NotifyPlug:onInstall() 会把 Manager 注册到 amfEC feature bus。
-- PassDayTimer 跨天时会发送 FeatureEvent.PASS_DAY，FeatureEventBus 按 onAct 前缀调用到这里。
function Manager:onActPassDay()
    self:getModel():onPassDay()
    self:updateTipView()

    local closed = self:closeAllPanels()
    if closed then
        -- TODO: 按需替换为业务定制提示文案
        CommonTip:showTip("新的一天开始了，数据已更新，\n请尝试重进活动~")
    end
end

function Manager:onActPassMainBegin()
    self:getModel():onActPassMainBegin()

    local closed = self:closeAllPanels()
    self:updateTipView()

    if closed then
        -- TODO: 按需替换为业务定制提示文案
        CommonTip:showTip(self:getConst().actName .. "活动已正式开启，\n请尝试重进活动~")
    end
end

function Manager:onActPassMainEnd()
    self:getModel():onActPassMainEnd()

    local closed = self:closeAllPanels()
    self:updateTipView()

    if closed then
        -- TODO: 按需替换为业务定制提示文案
        CommonTip:showTip(self:getConst().actName .. "活动已结束！")
    end
end

function Manager:onActPassActEnd()
    self:getModel():onActPassActEnd()

    local closed = self:closeAllPanels()
    self:updateTipView()

    if closed then
        -- TODO: 按需替换为业务定制提示文案
        CommonTip:showTip(self:getConst().actName .. "活动已结束！")
    end
end

return Manager
