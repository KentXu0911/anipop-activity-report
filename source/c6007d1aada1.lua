local BaseFeatureManager = require "amf.middleware.activity.base.BaseFeatureManager"
require "amf.middleware.autopop.config.AutoPopupConst"
local Event = _G["MidAutumnNationalDay2026Event"] or require "amf.feature.localactivity.midautumnnationalday2026.event.Event"

local Manager = class("MidAutumnNationalDay2026Manager", BaseFeatureManager)
Manager.ACT_CH_NAME = "双节签到"

--[[
Manager 职责：
1. 对外提供活动 facade：打开活动、面板托管、奖励入账和打点等常用入口。
2. 保存活动是否存在的最小宿主状态；Icon 的 `reward/msgNum` 直接按公共 `ActInfo` 规则提供。
3. Act/Notify 使用 BaseFeatureManager 默认 Plug，不在额外 Plug 中重复声明。
]]

-- =============================================================================
-- BaseFeatureManager 配置
-- =============================================================================

function Manager:_getConstPath()
    return "amf.feature.localactivity.midautumnnationalday2026.const.Const"
end

function Manager:_getModelPath()
    return "amf.feature.localactivity.midautumnnationalday2026.model.Model"
end

function Manager:_getExtraPlugsConfigList()
    -- 基础打点由 BaseFeatureManager 提供；ActSend 负责接入联动奖励协议。
    return {
        { key = "Panel" },
        { key = "Rewards" },
        { key = "AutoPop" },
        {
            key = "ActSend",
            path = {
                plugPath = "amf.feature.localactivity.midautumnnationalday2026.plug.ActSendPlug",
            },
        },
    }
end

function Manager:setAutoPopupMgr(manager)
    self.autoPopupMgr = manager
end

function Manager:_getAutoPopConfigList()
    local PopStage = AutoPopupConst.PopStage

    return {
        -- 签到正式期领奖期触发，每日最多一次；仅场景2，排在活动入口之后。
        -- 强弹次数由 AutoPopupLimit 控制，业务 check/pop 仅预留活动条件和主界面打开入口。
        {
            checkPoint = PopupCheckPoint.MID_AUTUMN_NATIONAL_DAY_2026_MAIN_POP_STAGE_2,
            -- 手动打开活动后同步标记该 checkpoint，避免当天再次进入强弹。
            manualOpen = self:getActId(),
            stages = { PopStage.STAGE_TWO },
            check = function()
                return self:checkCanPopMainPanel()
            end,
            creator = function(_, onPopOver)
                return function()
                    self:popMainPanel(onPopOver)
                end
            end,
        },
    }
end

function Manager:checkCanPopMainPanel()
    return self:isEnabled() and not self:getModel():isInPreheatTime()
end

function Manager:popMainPanel(onPopOver)
    if not self:checkCanPopMainPanel() then
        safeRunCall(onPopOver)
        return
    end

    self:openActivity({
        failCallback = onPopOver,
        endCallback = onPopOver,
        userClick = false,
    })
end

function Manager:_init()
    self:addEventDispatcher()
    self:registerEvents()
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

-- ActSendPlug 对外提供给集卡联动面板的活动信息。
function Manager:getActShowName()
    return self.ACT_CH_NAME
end

function Manager:isOpen()
    return self:isEnabled()
end

function Manager:getMainEndTime()
    return self:getModel():getMainEndTime()
end

function Manager:hasReward()
    local actInfo = self:callActFunc("getActInfo") or {}
    return actInfo.reward == true or tonumber(actInfo.reward) == 1
end

function Manager:getMsgNum()
    return 0
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
end

function Manager:onActInfosUpdate(event)
    local data = event and event:getData() or {}
    local actInfos = data.actInfos or {}
    local actInfo = actInfos[tostring(self:getActId())] or actInfos[self:getActId()]
    if not actInfo then
        for _, item in pairs(actInfos) do
            if type(item) == "table" and tonumber(item.actId) == self:getActId() then
                actInfo = item
                break
            end
        end
    end
    if not data.fromServer then
        return
    end

    self:syncActInfo(actInfo)
    if not actInfo then
        self:updateTipView()
    end
end

function Manager:getDataByKey(key, default)
    return self:getModel():getDataByKey(key, default)
end

function Manager:setDataByKey(key, value, needSave)
    self:getModel():setDataByKey(key, value, needSave)
end

function Manager:updateData(data)
    self:getModel():updateData(data)
end

function Manager:getActInfo()
    return self:getModel():getActInfo()
end

function Manager:dcQualify()
    local dc = self:getConst().DC
    if not dc then
        return false
    end
    if not self:getFlagFromLocalByKey("dc_qualify", true) then
        self:dcUserTrack(dc.Category.Canyu, dc.SubCategory.Qualify, {
            actid = self:getActId(),
        })
        self:setFlagToLocalByKey("dc_qualify", true, true)
        return true
    end
    return false
end

-- =============================================================================
-- 奖励入账
-- =============================================================================

function Manager:addRewardsNormal(rewards, params)
    return self:callRewardsFunc("addRewardsNormal", rewards or {}, params)
end

-- =============================================================================
-- 通用本地缓存薄代理
-- =============================================================================
function Manager:getCacheLocalKey(key)
    return "localCache." .. tostring(key or "defaultKey")
end

function Manager:setFlagToLocalByKey(key, needTime, value)
    if not key then return end
    if value == nil then value = true end
    self:getModel():saveFlagToLocalByKey(self:getCacheLocalKey(key), needTime, value, true)
end

function Manager:getFlagFromLocalByKey(key, needTime)
    return self:getModel():getFlagFromLocalByKey(self:getCacheLocalKey(key), needTime, true)
end

-- Base NotifyPlug:onInstall() 会把 Manager 注册到 amfEC feature bus。
function Manager:onActPassDay()
    BaseFeatureManager.onActPassDay(self)
    self:updateTipView()

    local closed = self:closeAllPanels()
    if closed then
        if self:isEnabled() then
            CommonTip:showTip("新的一天开始了，数据已更新，\n请尝试重进活动~")
        else
            CommonTip:showTip(self.ACT_CH_NAME .. "活动已结束！")
        end
    end
end

return Manager
