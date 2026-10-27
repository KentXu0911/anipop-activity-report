local PromoteDailyEventCenter = require "amf.feature.dailyreward.promotedaily.event.PromoteDailyEventCenter"
local PromoteDailyAutoPopLogic = class("PromoteDailyAutoPopLogic")

-- 连过重燃介绍界面强弹：记录「已弹过的活动期」，保证活动期只弹一次
local REPAIR_STAGE2_POP_PERIOD_KEY = "repairStage2PopPeriod"

function PromoteDailyAutoPopLogic:init(mgr)
    self._promoteDailyMgr = mgr
    self:registerEvent()
end

function PromoteDailyAutoPopLogic:registerEvent()
    -- 连过重燃的活动数据来自 mainInfo（首次进主场景时常常还在路上），
    -- 所以数据 / 公共资源就绪后再补一次场景2强弹
    PromoteDailyEventCenter:register(PromoteDailyEvent.MAIN_INFO_LOAD_SUCCESS, self.tryPopRepairStage2, self)
    PromoteDailyEventCenter:register(PromoteDailyEvent.PUB_RES_READAY, self.tryPopRepairStage2, self)
end

-------------------------------- 连过重燃（活动期首次进主场景强弹） start ---------------------------------

-- 本期标识：repairPeriodId 优先，缺失时退回结束时间（与加入重燃打点的周期去重口径一致）
function PromoteDailyAutoPopLogic:_getRepairPeriodKey()
    local act = self._promoteDailyMgr:getRepairActData()
    if not act then return nil end
    local periodId = tonumber(act.repairPeriodId) or 0
    if periodId > 0 then
        return tostring(periodId)
    end
    local endTime = tonumber(act.endTime) or 0
    if endTime > 0 then
        return tostring(endTime)
    end
    return nil
end

function PromoteDailyAutoPopLogic:isRepairStage2Poped()
    local periodKey = self:_getRepairPeriodKey()
    if not periodKey then return false end
    return self._promoteDailyMgr:getLocalValue(REPAIR_STAGE2_POP_PERIOD_KEY) == periodKey
end

function PromoteDailyAutoPopLogic:markRepairStage2Poped()
    local periodKey = self:_getRepairPeriodKey()
    if not periodKey then return end
    self._promoteDailyMgr:setLocalValue(REPAIR_STAGE2_POP_PERIOD_KEY, periodKey)
end

-- 场景2强弹条件：功能可用（服务端数据 + 公共资源就绪）+ 活动进行中 + 进度还是 0 + 本期没弹过
-- 进度不为 0 说明已经打过至少一关，介绍界面（「任过 n 关，救回…」）没意义，不再弹
function PromoteDailyAutoPopLogic:canPopRepairStage2()
    if not self._promoteDailyMgr:isEnabled() then return false end
    if not self._promoteDailyMgr:isRepairActInProgress() then return false end
    if self._promoteDailyMgr:getRepairProgress() ~= 0 then return false end
    return not self:isRepairStage2Poped()
end

-- 场景2通知时入队（入队后由强弹框架在本场景统一消费，不用自己触发）
function PromoteDailyAutoPopLogic:doActEnterStage2()
    if not self:canPopRepairStage2() then return end
    self:_addRepairStage2Popup()
end

-- 场景2通知过程（含 tryInitIcon 里同步派发的 PUB_RES_READAY）：
-- 这段时间只入队，交给框架在本场景通知结束后统一消费，避免通知链里抢跑强弹状态机
function PromoteDailyAutoPopLogic:beginEnterStage2()
    self._inEnterStage2 = true
end

function PromoteDailyAutoPopLogic:endEnterStage2()
    self._inEnterStage2 = nil
end

-- 数据 / 资源就绪后补一次：此前入队条件不满足时（首次进主场景数据未到）不漏掉这次强弹
function PromoteDailyAutoPopLogic:tryPopRepairStage2()
    if not self:canPopRepairStage2() then return end
    -- 数据正好在场景2通知链里就绪：紧随其后的 doActEnterStage2 会入队，这里不重复处理
    if self._inEnterStage2 then return end
    local autoPopupMgr = _G.amfBean("AutoPopupMgr")
    if not autoPopupMgr or not autoPopupMgr:isInMainScene() then return end
    self:_addRepairStage2Popup(true)
end

function PromoteDailyAutoPopLogic:_addRepairStage2Popup(needTrigger)
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.PROMOTE_DAILY_REPAIR_STAGE2)
    end

    local function creator()
        -- 真正弹之前再判一次：排队期间活动可能已经结束 / 已达标
        if not self:canPopRepairStage2() then
            safeRunCall(onHandleOver)
            return
        end
        self:markRepairStage2Poped()
        -- strongPop：介绍文案「任过 n 关，救回…」，不按进度分段
        self._promoteDailyMgr:showRepairPanel({
            strongPop = true,
        }, onHandleOver)
    end

    local autoPopupMgr = _G.amfBean("AutoPopupMgr")
    autoPopupMgr:addPopupConfig(PopupCheckPoint.PROMOTE_DAILY_REPAIR_STAGE2, creator)
    if needTrigger and not autoPopupMgr:isRunnning() then
        autoPopupMgr:triggerStage2AutoPopup()
    end
end

-------------------------------- 连过重燃（活动期首次进主场景强弹） end -----------------------------------

-- 是否可以强弹满签
function PromoteDailyAutoPopLogic:checkCanPopFullSign()
    local year, month = self._promoteDailyMgr:getYear(), self._promoteDailyMgr:getMonth()
    if self:isFullSignPoped(year, month) then return end
    return self._promoteDailyMgr:isFullSign(year, month)
end

function PromoteDailyAutoPopLogic:isFullSignPoped(year, month)
    year = year or self._promoteDailyMgr:getYear()
    month = month or self._promoteDailyMgr:getMonth()
    local key = "popFullSignDate_".. year .. "_" .. month
    return self._promoteDailyMgr:getLocalValue(key)
end

-- 七天奖励是否可以领取
function PromoteDailyAutoPopLogic:checkCanPop7DayReward()
    if not self._promoteDailyMgr:getTaskCanReward() then return end
    return true
end

-- 场景4
function PromoteDailyAutoPopLogic:canPopStage4()
    if not self._promoteDailyMgr:isEnabled() then return false end
    local can = false
    can = self._promoteDailyMgr:checkCanPopGetRewards(true)
        or self:checkCanPopFullSign()
        or self:checkCanPop7DayReward()
        or self._promoteDailyMgr:hasTargetTaskCanReward()
    return can
end

function PromoteDailyAutoPopLogic:doActEnterStage4(data)
    if not self:canPopStage4() then return end
    local function onHandleOver()
        AutoPopEventCenter:dispatch(AutoPopEvent.SINGLE_POP_OVER, PopupCheckPoint.PROMOTE_DAILY)
    end
    local function creator()
        self._promoteDailyMgr:openMainPanel({
            autoPopout = true,
            closeCallback = onHandleOver
        })
    end

    _G.amfBean("AutoPopupMgr"):addPopupConfig(PopupCheckPoint.PROMOTE_DAILY, creator)
end

function PromoteDailyAutoPopLogic:create(mgr)
    local ret = PromoteDailyAutoPopLogic.new()
    ret:init(mgr)
    return ret
end

return PromoteDailyAutoPopLogic
