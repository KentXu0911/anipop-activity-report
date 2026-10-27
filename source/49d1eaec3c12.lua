require "amf.feature.dailyreward.promotedaily.config.PromoteDailyConst"
local PromoteDailyEventCenter = require "amf.feature.dailyreward.promotedaily.event.PromoteDailyEventCenter"
local ActivityEventCenter = require "amf.middleware.activity.event.ActivityEventCenter"
local PropEventCenter = require "amf.middleware.prop.event.PropEventCenter"
local MainPanelConfig = require "amf.feature.dailyreward.promotedaily.config.MainPanelConfig"
local Utils = require "amf.feature.dailyreward.promotedaily.util.Utils"
local PromoteDailyMgr = class("PromoteDailyMgr")

local channels = {27}
function PromoteDailyMgr:log(...)
    if not EnvUtil:isDevelopMode() then return end
    for i, v in ipairs(channels) do
        printx(v, "PromoteDailyLog :" , ...)
        -- UError(v, "PromoteDailyLog :", ...)
    end
end

function PromoteDailyMgr:ctor()
    self._optionalDataManager = nil
    self._iconManager = nil
end

function PromoteDailyMgr:setIconManager(mgr)
    self._iconManager = mgr
end

function PromoteDailyMgr:setOptionalDataManager(mgr)
    self._optionalDataManager = mgr
end

function PromoteDailyMgr:initialize()
    -- models
    self.actInfo = require("amf.feature.dailyreward.promotedaily.model.ActInfo").new()
    -- 初始化user给的数据
    local actInfoJson = self._optionalDataManager:getTempOptionalDataValue("promoteDailyInfo") or ""
    self.actInfo:parseData(actInfoJson)

    self.model = require("amf.feature.dailyreward.promotedaily.model.Model"):create()

    -- banner
    self._infoNodeLogic = require("amf.feature.dailyreward.promotedaily.logic.PromoteDailyInfoNodeLogic"):create(self)
    -- 重燃 banner（独立于原 banner）
    self._repairBannerLogic = require("amf.feature.dailyreward.promotedaily.logic.PromoteDailyRepairBannerLogic"):create(self)
    -- 关卡相关
    self._levelLogic = require("amf.feature.dailyreward.promotedaily.logic.PromoteDailyLevelLogic"):create(self)
    -- 网络相关
    self._httpLogic = require("amf.feature.dailyreward.promotedaily.logic.PromoteDailyHttpLogic"):create(self, self.model)
    -- Icon
    self._iconLogic = require("amf.feature.dailyreward.promotedaily.logic.PromoteDailyIconLogic"):create(self)
    -- 界面相关
    self._panelLogic = require("amf.feature.dailyreward.promotedaily.logic.PromoteDailyPanelLogic"):create(self, self.model)
    -- 计算相关
    self._modelLogic = require("amf.feature.dailyreward.promotedaily.logic.PromoteDailyModelLogic"):create(self, self.model)
    -- 强弹相关
    self._autoPopLogic = require("amf.feature.dailyreward.promotedaily.logic.PromoteDailyAutoPopoutLogic"):create(self)
    -- 资源相关
    self._resLogic = require("amf.feature.dailyreward.promotedaily.logic.PromoteDailyResLogic"):create(self)
    -- 签到banner
    require("amf.feature.dailyreward.promotedaily.logic.PromoteDailyMarkLogic"):create(self)

    self._modelLogic:resetTodayInfo()
    self:registerEvent()
    -- 下载资源
    TimerUtil.addAlarm(function()
        -- public资源
        self:tryLoadPublicRes()
        self:tryLoadRes()
        if self:isLocalEnabled() then
            self:requestMainInfoOnLightStart()
        end
    end, 1/30)

    require("amf.feature.dailyreward.promotedaily.share.AskHandHandler"):create()
    self._hasInited = true
end


--------------------- panelLogic接口 start ---------------
function PromoteDailyMgr:addToMgr(vm)
    self._panelLogic:addToMgr(vm)
end

--------------------- panelLogic接口 end ---------------

--------------------- resLogic接口 start ---------------
function PromoteDailyMgr:tryLoadPublicRes()
    return self._resLogic:tryLoadPublicRes()
end
function PromoteDailyMgr:tryLoadRes()
    return self._resLogic:tryLoadRes()
end

function PromoteDailyMgr:isPublicResReady()
    return self._resLogic:isPublicResReady()
end

function PromoteDailyMgr:isResReady()
    return self._resLogic:isResReady()
end

--------------------- resLogic接口 end ---------------


-- 领取七日奖励，新任务奖励，选择目标
function PromoteDailyMgr:tryGetTaskReward(inLevel)
    return self._httpLogic:tryGetTaskReward(inLevel)
end
function PromoteDailyMgr:registerEvent()
    PromoteDailyEventCenter:registerFeature(self)
    PromoteDailyEventCenter:registerSystem(self)
    PropEventCenter:register(PropEvent.CUSTOM_GAIN, self._onCustomGain, self)
    PropEventCenter:register(PropEvent.CUSTOM_CONSUME, self._onCustomConsume, self)
    -- 活动信息更新事件在 ActivityEventCenter 上派发，registerFeature 不代劳，必须显式注册
    ActivityEventCenter:register(ActivityEvent.ACT_INFOS_UPDATE, self.onActInfoUpdate, self)
end

function PromoteDailyMgr:registerProp()
    if self._hasRegisterProp then return end
    self._hasRegisterProp = true
    require "amf.feature.dailyreward.promotedaily.prop.AMFProp_57088"
    require "amf.feature.dailyreward.promotedaily.prop.AMFProp_57089"
    require "amf.feature.dailyreward.promotedaily.prop.AMFProp_57455"
end

--------------------- 连过重燃活动 start ---------------
-- 解析活动标记 repairFlag：0 没有 / 1 可能有 / 2 已经有；解析失败按 0
function PromoteDailyMgr:parseRepairFlag(extra)
    if not extra or extra == "" then return 0 end
    -- actInfo.extra 是服务端下发的 JSON 字符串（联调 mock 需用 table.serialize 生成）
    local tb = table.deserialize(extra)
    if type(tb) ~= "table" then
        self:log("parseRepairFlag: extra is not a table:", tostring(extra))
        return 0
    end
    local flag = tonumber(tb.repairFlag)
    if flag == nil or flag < 0 or flag > 2 then
        self:log("parseRepairFlag: invalid flag:", tostring(tb.repairFlag))
        return 0
    end
    return flag
end

-- 活动信息更新：只用于「提示补拉主信息」，活动是否可用以 mainInfo.repairTaskInfo 为准
--   1 / 2：本地没有任务数据时补拉一次（1 是「可能有」，见下面的冷却）
--   1 / 2 -> 0：任务结束或完成，新旧七日任务数据可能已经变化，补拉一次
function PromoteDailyMgr:onActInfoUpdate(evt)
    local data = evt and evt:getData()
    if not data or not data.fromServer then return end
    local actInfos = data.actInfos or {}
    -- 没有这条 actInfo（活动没配 / 已下线）不处理
    local actInfo = actInfos[tostring(PromoteDailyConst.REPAIR_ACT_ID)]
    if not actInfo then return end
    local flag = self:parseRepairFlag(actInfo.extra)
    -- 缓存最近一次 repairFlag（getRepairFlag 读取；supportRepairTask 现在固定 true）
    self._repairFlagCache = flag
    local lastFlag = self._lastActInfoFlag
    self._lastActInfoFlag = flag
    -- 标记变了就清掉「flag = 1 且没有任务」的冷却：换了状态说明后端任务数据已经变化
    if lastFlag ~= nil and lastFlag ~= flag then
        self._repairFlag1NoTaskCdEndTime = nil
    end

    local needRequest
    if flag == 0 then
        -- 1/2 -> 0：任务结束或完成，七日任务（新旧）数据可能已经变化，补拉一次
        needRequest = lastFlag == 1 or lastFlag == 2
    else
        -- 1/2：本地已经有任务数据就不请求
        needRequest = not self:isRepairActValid()
        -- flag = 1 后端「可能有也可能没有任务」：上次请求确认没有任务后冷却期内不再请求
        if needRequest and flag == 1 then
            local cdEndTime = self._repairFlag1NoTaskCdEndTime
            needRequest = cdEndTime == nil or TimeKit:timeInSec() >= cdEndTime
        end
        -- 同一个标记连续触发时，请求已经在飞就不重复发
        if needRequest and self._repairMainInfoRequesting then
            needRequest = false
        end
    end
    if not needRequest then return end
    -- 标记翻转（1/2 -> 0）要补发的那次不等上一次返回，直接发
    self:requestRepairMainInfo()
end

-- 补拉主信息（活动标记驱动）
function PromoteDailyMgr:requestRepairMainInfo()
    self._repairMainInfoRequesting = true
    self._httpLogic:requestMainInfo(false):next(function()
        self._repairMainInfoRequesting = false
        -- flag = 1 且这次回来确认没有任务 -> 记冷却；请求失败 / 取消不计
        if self._lastActInfoFlag == 1 and not self:isRepairActValid() then
            self._repairFlag1NoTaskCdEndTime =
                TimeKit:timeInSec() + PromoteDailyConst.REPAIR_FLAG1_NO_TASK_CD
        end
    end, function()
        self._repairMainInfoRequesting = false
    end)
end

-- 读取当前 actInfo 的 repairFlag：0 没有 / 1 可能有 / 2 已经有；读取失败回退到最近一次缓存，再回退 0
function PromoteDailyMgr:getRepairFlag()
    local activityMgr = _G.amfBean("ActivityMgr")
    local actInfo = activityMgr and type(activityMgr.getActInfo) == "function"
        and activityMgr:getActInfo(PromoteDailyConst.REPAIR_ACT_ID) or nil
    if actInfo and actInfo.extra ~= nil then
        local flag = self:parseRepairFlag(actInfo.extra)
        self._repairFlagCache = flag
        return flag
    end
    return self._repairFlagCache or 0
end

-- 主信息请求参数：supportRepairTask 固定 true，后端按自己的 flag 决定是否真的下发 repairTaskInfo
function PromoteDailyMgr:needSupportRepairTask()
    return true
end

-- 重燃活动数据唯一来源：mainInfo 下的 repairTaskInfo 字段（后端 RepairTaskInfoBean），直接读取，不做额外缓存
-- 后端字段 → 客户端字段：repairPeriodId/startTimeSecond/endTimeSecond/targetProgress/progress
--                          → repairPeriodId/beginTime/endTime/target/progress
-- 字段缺失/非法返回 nil（非法记日志）
function PromoteDailyMgr:getRepairActData()
    local task = self:getDataValue(PromoteDailyConst.REPAIR_ACT_FIELD)
    if task == nil then return nil end
    if type(task) ~= "table" then
        UError("PromoteDailyMgr: mainInfo." .. tostring(PromoteDailyConst.REPAIR_ACT_FIELD) .. " is not a table")
        return nil
    end
    local beginTime = tonumber(task.startTimeSecond) or 0
    local endTime = tonumber(task.endTimeSecond) or 0
    local target = tonumber(task.targetProgress) or 0
    if beginTime <= 0 or endTime <= beginTime or target <= 0 then
        UError("PromoteDailyMgr: repairTaskInfo invalid, startTimeSecond/endTimeSecond/targetProgress =",
            beginTime, endTime, target)
        return nil
    end
    -- 后端 progress 为 byte（0~255），非法值（负数 / 超过目标）按 [0, target] 收敛并记日志，
    -- 避免负进度被 isRepairActInProgress 误判为「进行中」、或超过目标后影响进度展示
    local progress = tonumber(task.progress) or 0
    if progress < 0 or progress > target then
        UError("PromoteDailyMgr: repairTaskInfo.progress out of range:",
            progress, "target =", target)
        if progress < 0 then
            progress = 0
        else
            progress = target
        end
    end
    return {
        repairPeriodId = tonumber(task.repairPeriodId) or 0,
        beginTime = beginTime,
        endTime = endTime,
        target = target,
        progress = progress,
    }
end

-- 刷新活动数据（主信息成功后调用）：数据不缓存，只派发事件让 UI 重算
function PromoteDailyMgr:refreshRepairAct()
    local ok = self:getRepairActData() ~= nil
    PromoteDailyEventCenter:dispatch(PromoteDailyEvent.REPAIR_ACT_UPDATE)
    -- 打点：加入重燃（同一次活动只上报一次）
    self:dcRepairJoin()
    -- 重燃活动的结束是纯时间判定，没有任何服务器回调会在到期这一刻通知客户端，
    -- 所以拿到活动数据后自己排一个到点定时器
    self:_scheduleRepairActEndRefresh()
    return ok
end

-- 活动结束后的界面刷新：只派发本地 UI 事件，不请求主信息
-- Banner / 吊牌 / 任务区 / 底栏走 REPAIR_ACT_UPDATE（Banner 逻辑自己会摘 Banner 并让原 Banner 重判），
-- icon 走 UPDATE_ICON 退出冰封态
function PromoteDailyMgr:refreshRepairActUI()
    PromoteDailyEventCenter:dispatch(PromoteDailyEvent.REPAIR_ACT_UPDATE)
    PromoteDailyEventCenter:dispatch(PromoteDailyEvent.UPDATE_ICON)
end

-- 未达标且已到期时，冻结的旧连过失效；当天的重燃签到恢复为未签到，
-- 这样到期后的第一关自然按普通签到从 1 天开始。一次活动到期只处理一次，避免过关后的新连过被覆盖。
function PromoteDailyMgr:settleExpiredRepairAct()
    local act = self:getRepairActData()
    if not act or act.progress >= act.target or TimeKit:timeInSec() < act.endTime then
        return false
    end
    local changed = false
    if not self._expiredRepairActSettled then
        self._expiredRepairActSettled = true
        self:setDataValue(PromoteDailyConst.CONTINUOUS_PASS_FIELD, 0)
        changed = true
    end
    local year, month, day = self:getYear(), self:getMonth(), self:getDay()
    if self:getSignState(year, month, day) == PromoteDailyConst.SignState.REPAIR then
        self:setSignState(year, month, day, PromoteDailyConst.SignState.NONE)
        self:resetContinuseInfo()
        changed = true
    end
    return changed
end

-- 活动到期定时器：到点在本地把界面刷回非活动态。
-- 只有「进行中」的活动需要排：已达标（结束由过关结算链路负责刷新，见 PromoteDailyLevelLogic:doActPlayLevelEnd）、
-- 未开始、无活动数据都不排；活动数据每次刷新（主信息返回 / 跨天 / 本地加进度）都重排一次，避免拿到旧 endTime。
function PromoteDailyMgr:_scheduleRepairActEndRefresh()
    if self._repairActEndAlarmId then
        TimerUtil.removeAlarm(self._repairActEndAlarmId)
        self._repairActEndAlarmId = nil
    end
    if not self:isRepairActInProgress() then return end
    self._expiredRepairActSettled = false
    local delay = self:getRepairActEndTime() - TimeKit:timeInSec()
    -- delay <= 0 说明已经到点，交给下一次刷新处理，不排一个「延迟 1 秒」（TimerUtil 会把 <=0 收敛成 1 秒）
    if delay <= 0 then return end
    self._repairActEndAlarmId = TimerUtil.addAlarm(function()
        self._repairActEndAlarmId = nil
        self:settleExpiredRepairAct()
        self:refreshRepairActUI()
    end, delay, 1)
end

-- 打点：加入重燃（活动进行中判到）
-- 以 repairPeriodId 作为一次活动的周期标识（同一周期后端最多生成一条任务），缺失时回退 endTime；
-- 同一周期内只上报一次（key 只在内存，杀进程重启后会重新上报，口径与活动强弹一致）
-- t1 = 冻结时连续签到天数，t2 = 断签的日期区间 yyyyMMdd_yyyyMMdd
function PromoteDailyMgr:dcRepairJoin()
    local act = self:getRepairActData()
    if not act or not self:isRepairActInProgress() then return end
    local key = act.repairPeriodId > 0 and tostring(act.repairPeriodId) or tostring(act.endTime)
    if self._repairJoinDcKey == key then return end
    self._repairJoinDcKey = key
    self:dc(PromoteDailyConst.FEATURE, "repair_join", {
        t1 = self:getRepairFrozenContiNum(),
        t2 = self:getRepairBreakDateRange(),
    })
end

-- 打点：修复进度（活动期间每过一关上报一次）
-- t1 = 冻结时连续签到天数，t2 = 当前修复进度，t3 = 1 修复完成 / 2 未修复完成
function PromoteDailyMgr:dcFreezeRepair()
    local act = self:getRepairActData()
    if not act then return end
    self:dc(PromoteDailyConst.FEATURE, "freeze_repair", {
        t1 = self:getRepairFrozenContiNum(),
        t2 = act.progress,
        t3 = act.progress >= act.target and 1 or 2,
    })
end

-- 打点用：冻结时（断连那一刻）的连续签到天数
-- 活动期间「状态 5」不计入连过天数，服务端下发的 continuousPassingDay 在活动期内就是冻结时的值
function PromoteDailyMgr:getRepairFrozenContiNum()
    return self:getContinousPassDayCount()
end

-- 上一段连过区间的开始 / 结束（dayNum，找不到返回 0, 0）：口径同连过天数
function PromoteDailyMgr:getLastContinousPassRange(fromNum, minNum)
    return self._modelLogic:getLastContinousPassRange(fromNum, minNum)
end

-- 打点用：断签的日期区间 yyyyMMdd_yyyyMMdd（例 20260101_20260102）
-- 口径（与连过天数的算法 PromoteDailyModelLogic:resetContinuseInfo / calculateMaxContiNum 同源）：
--   ① 从今天前一天往前找「上一段连过」的开始 / 结束（状态 SIGN / SHIELD 才算连过），
--      往前最多回溯到功能开启那天（PromoteDailyConst.ACT_OPEN_DAYNUM，与 calculateMaxContiNum 同一个下限）；
--   ② 再从连过结束那天开始往今天遍历，取这段里未签到（status = 0）的第一个 / 最后一个日子，
--      返回「区间第一天_今天前的最后未签到那天」；只有一天时只返回那一天（不带 "_"）。
function PromoteDailyMgr:getRepairBreakDateRange()
    local lastNum = self:getTodayNum() - 1
    if lastNum <= 0 then return "" end
    -- 功能开启那天：断签只可能发生在它之后，作为往前回溯的下限
    local minNum = PromoteDailyConst.ACT_OPEN_DAYNUM
    -- ① 上一段连过：功能开启以来都没有连过（新号 / 数据缺失）时，从功能开启那天开始算
    local _, contiEndNum = self:getLastContinousPassRange(lastNum, minNum)
    if contiEndNum <= 0 then
        self:log("getRepairBreakDateRange: no continous pass range, fallback to ACT_OPEN_DAYNUM =", minNum)
    end
    local startNum = contiEndNum > 0 and contiEndNum or minNum
    if startNum < minNum then startNum = minNum end
    -- ② 从连过结束那天开始往今天遍历，取未签到的第一个 / 最后一个日子
    local firstUnsignNum, lastUnsignNum
    for dayNum = startNum, lastNum do
        if self:_isRepairUnsignDay(dayNum) then
            firstUnsignNum = firstUnsignNum or dayNum
            lastUnsignNum = dayNum
        end
    end
    if not firstUnsignNum then
        self:log("getRepairBreakDateRange: no unsign day, startNum =", startNum, "lastNum =", lastNum)
        return ""
    end
    -- 只有一天：不上报 "_"，直接给单个日期
    if firstUnsignNum == lastUnsignNum then
        return self:_getRepairDateStr(firstUnsignNum)
    end
    return self:_getRepairDateStr(firstUnsignNum) .. "_" .. self:_getRepairDateStr(lastUnsignNum)
end

-- 某天（dayNum：70 年起的天数）是否未签到（status = 0）
function PromoteDailyMgr:_isRepairUnsignDay(dayNum)
    local date = Utils:getYMDByDayCount(dayNum)
    return self:getSignState(date.year, date.month, date.day) == PromoteDailyConst.SignState.NONE
end

-- dayNum → yyyyMMdd
function PromoteDailyMgr:_getRepairDateStr(dayNum)
    local date = Utils:getYMDByDayCount(dayNum)
    return string.format("%04d%02d%02d", date.year, date.month, date.day)
end

-- 活动数据是否合法：存在 mainInfo.repairTaskInfo 且字段合法
function PromoteDailyMgr:isRepairActValid()
    return self:getRepairActData() ~= nil
end

-- 是否在重燃活动时间内（ts 缺省用当前服务端时间）
function PromoteDailyMgr:isRepairActInTime(ts)
    local act = self:getRepairActData()
    if not act then return false end
    ts = ts or TimeKit:timeInSec()
    return ts >= act.beginTime and ts < act.endTime
end

-- 是否已完成目标关数（成功）
function PromoteDailyMgr:isRepairActCompleted()
    local act = self:getRepairActData()
    return act ~= nil and act.progress >= act.target
end

-- 活动是否进行中：数据合法、未完成目标、且在活动时间内
function PromoteDailyMgr:isRepairActInProgress()
    local act = self:getRepairActData()
    if not act then return false end
    return act.progress < act.target and self:isRepairActInTime()
end

-- 活动未达标且已经过结束时间；用于过关结算准备阶段兜底开启每日一关流程。
function PromoteDailyMgr:isRepairActExpiredUncompleted()
    local act = self:getRepairActData()
    if not act or act.progress >= act.target then return false end
    return TimeKit:timeInSec() >= act.endTime
end

-- 活动是否已结束：完成目标关数 或 结束时间到（数据非法视为已结束）
-- 与 isRepairActInProgress() 互为补集；Banner 等「活动生效才展示」的判断用它更直观
function PromoteDailyMgr:isRepairActFinished()
    local act = self:getRepairActData()
    if not act then return true end
    return act.progress >= act.target or not self:isRepairActInTime()
end

function PromoteDailyMgr:getRepairTarget()
    local act = self:getRepairActData()
    return act and act.target or 0
end

function PromoteDailyMgr:getRepairProgress()
    local act = self:getRepairActData()
    return act and act.progress or 0
end

function PromoteDailyMgr:getRepairActBeginTime()
    local act = self:getRepairActData()
    return act and act.beginTime or 0
end

function PromoteDailyMgr:getRepairActEndTime()
    local act = self:getRepairActData()
    return act and act.endTime or 0
end

function PromoteDailyMgr:getRepairRemainTime()
    local act = self:getRepairActData()
    if not act then return 0 end
    return math.max(0, act.endTime - TimeKit:timeInSec())
end

-- 是否刷新了历史最高连过纪录（历史最高仍由客户端推算）
function PromoteDailyMgr:isNewContiRecord()
    local cur = self:getContinousPassDayCount()
    return cur > 0 and cur > self:getLastContiMaxCount()
end

-- 活动期间过关：本地累加活动进度（已完成关数）
-- 说明：进度最终以服务端下发的 mainInfo.repairTaskInfo.progress 为准，这里先把本地表现推进，
--       主信息刷新后会被服务端值覆盖；上限按 target 截断，避免本地超过目标关数。
function PromoteDailyMgr:addRepairProgress(count)
    count = tonumber(count) or 0
    if count <= 0 then return self:getRepairProgress() end
    local task = self:getDataValue(PromoteDailyConst.REPAIR_ACT_FIELD)
    if type(task) ~= "table" then return self:getRepairProgress() end
    local beginTime = tonumber(task.startTimeSecond) or 0
    local endTime = tonumber(task.endTimeSecond) or 0
    local target = tonumber(task.targetProgress) or 0
    if beginTime <= 0 or endTime <= beginTime or target <= 0 then
        return self:getRepairProgress()
    end
    local progress = tonumber(task.progress) or 0
    progress = progress + count
    if progress > target then progress = target end
    if progress < 0 then progress = 0 end
    task.progress = progress
    self:setDataValue(PromoteDailyConst.REPAIR_ACT_FIELD, task)
    -- 达标当关：先留住 Banner 播「光效飞向 icon → Banner 消失」，播完再摘
    if progress >= target and self._repairBannerLogic then
        self._repairBannerLogic:waitSignFlowForFinish()
    end
    -- 本地进度到顶即视为活动已达标，刷新 UI
    PromoteDailyEventCenter:dispatch(PromoteDailyEvent.REPAIR_ACT_UPDATE)
    -- 达标后活动不再是「进行中」，顺手把到期定时器撤掉（达标结束由过关结算链路刷新）
    self:_scheduleRepairActEndRefresh()
    return progress
end

-- 非活动期间过关（当天首次签到）：本地累加连过天数
-- 说明：连过天数最终以服务端下发的 mainInfo.continuousPassingDay 为准，这里先本地推进表现，
--       主信息刷新后会被服务端值覆盖。
function PromoteDailyMgr:addContinousPassNum(count)
    count = tonumber(count) or 0
    local num = self:getContinousPassDayCount() + count
    if num < 0 then num = 0 end
    num = math.floor(num)
    self:setDataValue(PromoteDailyConst.CONTINUOUS_PASS_FIELD, num)
    PromoteDailyEventCenter:dispatch(PromoteDailyEvent.REPAIR_ACT_UPDATE)
    return num
end
--------------------- 连过重燃活动 end ---------------

-- 是否有奖励可以领取
function PromoteDailyMgr:checkCanPopGetRewards(containToday)
    return self._modelLogic:checkCanPopGetRewards(containToday)
end

-- 满签界面
function PromoteDailyMgr:showFullSignPanel(param)
    return self._panelLogic:showFullSignPanel(param)
end

function PromoteDailyMgr:showMedalShowPanel(param)
    self._panelLogic:showMedalShowPanel(param)
end

function PromoteDailyMgr:isMainScene()
    local scene = Director:sharedDirector():getRunningSceneLua()
    return scene and scene:isScene("MainScene")
end

function PromoteDailyMgr:getInLevelGetRewardData()
    return self._levelLogic:getInLevelGetRewardData()
end

-- 跨天
function PromoteDailyMgr:onActPassDay()
    if not self:isLocalEnabled() then return end
    self._modelLogic:doPassDay()
    self._panelLogic:doPassDay()
    self._infoNodeLogic:doPassDay()
    if self._repairBannerLogic then
        self._repairBannerLogic:doPassDay()
    end
    -- 跨天时活动数据不变（本周期已上报过加入重燃），这里只兜底补一次加入重燃判定
    self:dcRepairJoin()
    PromoteDailyEventCenter:dispatch(PromoteDailyEvent.UPDATE_ICON, {
        isInit = true
    })
end

function PromoteDailyMgr:onActPlayLevelEnd(evt)
    self._levelLogic:doActPlayLevelEnd(evt)
end

function PromoteDailyMgr:isToday(year, month, day)
    return self:getYear() == year and self:getMonth() == month and self:getDay() == day
end

function PromoteDailyMgr:getYear()
    return self._modelLogic:getYear()
end

function PromoteDailyMgr:getMonth()
    return self._modelLogic:getMonth()
end

function PromoteDailyMgr:getDay()
    return self._modelLogic:getDay()
end

function PromoteDailyMgr:getTodayNum()
    return self._modelLogic:getTodayNum()
end

-- 重置连续过关信息
function PromoteDailyMgr:resetContinuseInfo()
    self._modelLogic:resetContinuseInfo()
end

-- 判断使用盾牌是否播放过
function PromoteDailyMgr:isUseShieldShowed(dayNum)
    return self._modelLogic:isUseShieldShowed(dayNum)
end

-- 设置使用盾牌已经播过了
function PromoteDailyMgr:setUseShieldShowed(dayNum)
    self._modelLogic:setUseShieldShowed(dayNum)
end

-- 获得最近的两个shiled类型的数据
function PromoteDailyMgr:getShiledDateInfoByLimit(limitCount)
    return self._modelLogic:getShiledDateInfoByLimit(limitCount)
end

function PromoteDailyMgr:resetTaskData()
    self._modelLogic:resetTaskData()
end

-- 本地配置是否可用
function PromoteDailyMgr:isLocalEnabled()
    if not FeatureSwitch:isOpen(FeatureSwitch.Type.PROMOTE_DAILY) then return false, "FeatureSwitch is not open" end
    if EnvUtil:isIOS() and MaintenanceManager:getInstance():isInReview() then return false, "提审期间不开放，iOS不开放" end
    if not self._hasInited then return false, "disable 未初始化" end
    local userVersion = self:getActValue("version2")
    -- 前后端版本判断
    if userVersion ~= PromoteDailyConst.VERSION then
        return false, "disable 前后端版本不一致，不可用"
    end
    -- 版本判断
    local ver = tonumber(string.split(_G.bundleVersion, ".")[2])
    local cfgMinVer = tonumber(string.split(self:getActValue("minVersion"), ".")[2]) or 0
    if ver < cfgMinVer then
        return false, "disable 版本过低，不可用" .. ver .. "_" .. cfgMinVer
    end
    -- 开启等级判断
    local openLevel = self:getActValue("activityOpenLevel")
    if _G.getTopPassedLevelId() < openLevel then
        return false, "disable 等级过低，不可用" .. openLevel
    end
    -- 是否在开启时间内
    local beginTime = self:getActValue("beginTime") or 0
    local endTime = self:getActValue("endTime") or 0
    local curTime = TimeKit:timeInSec()
    if curTime <= beginTime or curTime >= endTime then
        return false, "disable 不在开启时间内"
    end

    return true, "ok"
end

-- 资源配置是否可用
function PromoteDailyMgr:isResCfgEnabled(year, month)
    local tmYear, tmMonth
    if year and month then
        tmYear = year
        tmMonth = month
    else
        tmYear = self:getYear()
        tmMonth = self:getMonth()
    end
    return MainPanelConfig:isMonthSupported(tmYear, tmMonth)
end

function PromoteDailyMgr:isDataEnabled()
    if not self:isLocalEnabled() then return false end
    if not self:isResCfgEnabled() then return false end
    if not self:getDataValue("isFromServer") then return false end
    return true
end

-- 是否可用
function PromoteDailyMgr:isEnabled()
    if not self:isLocalEnabled() then return false end
    if not self:isResCfgEnabled() then return false end
    if not self:isPublicResReady() then return false end
    if not self:isResReady() then return false end
    if not self:getDataValue("isFromServer") then return false end
    -- 先加个判断，如果服务器返回的是0就不显示icon
    local groupType = self:getDataValue("groupType") or 0
    if groupType == 0 then return false end
    return true
end

function PromoteDailyMgr:getSignState(year, month, day)
    return self._modelLogic:getSignState(year, month, day)
end

function PromoteDailyMgr:setSignState(year, month, day, state)
    self._modelLogic:setSignState(year, month, day, state)
end

-- 今天的签到类型
function PromoteDailyMgr:getTodaySignState()
    return self._modelLogic:getTodaySignState()
end

-- 奖字
function PromoteDailyMgr:hasRewards()
    return self._modelLogic:hasRewards()
end

-- 数字红点
function PromoteDailyMgr:getShowMsgNum()
    return 0
end

function PromoteDailyMgr:getCurrentTargetPro()
    return self._modelLogic:getCurrentTargetPro()
end

function PromoteDailyMgr:getUnsignTimeRange()
    return self._modelLogic:getUnsignTimeRange()
end

-- 打开分享界面前先请求
function PromoteDailyMgr:requestPreShowOff(param)
    return self._httpLogic:requestPreShowOff(param)
end

-- 分享奖励领取
function PromoteDailyMgr:requestShareReward(param)
    return self._httpLogic:requestShareReward(param)
end

-- 主info
function PromoteDailyMgr:requestMainInfo(loading)
    return self._httpLogic:requestMainInfo(loading)
end

function PromoteDailyMgr:requestMainInfoOnLightStart()
    return self._httpLogic:requestMainInfo(false, "lightStart")
end

function PromoteDailyMgr:requestMainInfoOnAutoPopout()
    return self._httpLogic:requestMainInfo(false, "autoPopout")
end

function PromoteDailyMgr:calculateMaxContiNum()
    return self._modelLogic:calculateMaxContiNum()
end

function PromoteDailyMgr:getLastContiMaxCount()
    return self._modelLogic:getLastContiMaxCount()
end

-- 是否有月度奖牌可以领取
function PromoteDailyMgr:checkCanRewardMonthMedal(year, month)
    return self._modelLogic:checkCanRewardMonthMedal(year, month)
end

-- 获得目标月的最后一天
function PromoteDailyMgr:getLastDayByYM(year, month)
    return self._modelLogic:getLastDayByYM(year, month)
end

-- 是否领取了月度奖励
function PromoteDailyMgr:hasRewardMonthMedal(medalId)
    return self._modelLogic:hasRewardMonthMedal(medalId)
end

function PromoteDailyMgr:getMonthDataByYM(year, month)
    return self._modelLogic:getMonthDataByYM(year, month)
end

-- 获得对应天的过关次数
function PromoteDailyMgr:getPassLevelCount(year, month, day)
    return self._modelLogic:getPassLevelCount(year, month, day)
end

-- 获得连续过关天数
function PromoteDailyMgr:getContinousPassDayCount()
    return self._modelLogic:getContinousPassDayCount()
end

function PromoteDailyMgr:getContinousPassEndNum()
    return self._modelLogic:getContinousPassEndNum()
end

function PromoteDailyMgr:getContinousPassBeginNum()
    return self._modelLogic:getContinousPassBeginNum()
end

-- 客户端自己按日历算出来的当前连过天数（含今天；状态 0 / 5 不算连过）
--   【只给七日条铺位用】：唯一消费方是 getSevenDaySlotIndex；
--   展示 / 比较 / 打点 / 里程碑判断一律走 getContinousPassDayCount（服务端值），两者不要混用
function PromoteDailyMgr:getLocalContinousPassDayCount()
    return self._modelLogic:getLocalContinousPassDayCount()
end

-- 出关七日条：今天在第几格（新旧七天任务统一 = 自算连过天数 % 7；
-- 见 PromoteDailyModelLogic:getSevenDaySlotIndex）
function PromoteDailyMgr:getSevenDaySlotIndex()
    return self._modelLogic:getSevenDaySlotIndex()
end

-- 七日数据取数口（出关七日条 / 七天任务条专用）：7 格 = 今天所在的那个连过周期（日期 / 星期 / 签到状态）
-- 今天之前是刚连过的日子、之后是还没到的日子；状态 0 / 5 都不算连过，取数时不会出现，
-- 消费方拿不到 5
-- （见 PromoteDailyModelLogic:getSevenDaySlots）
function PromoteDailyMgr:getSevenDaySlots()
    return self._modelLogic:getSevenDaySlots()
end

-- 是否是连续过关天数
function PromoteDailyMgr:isContinousPassDay(year, month, day)
    return self._modelLogic:isContinousPassDay(year, month, day)
end

-- 是否是最近的连过那天
function PromoteDailyMgr:isNewestContiPassday(year, month, day)
    return self._modelLogic:isNewestContiPassday(year, month, day)
end

-- 获得未来x天内有没有纪念日
function PromoteDailyMgr:getFutureKeyDayByLimit(limit)
    return self._modelLogic:getFutureKeyDayByLimit(limit)
end

-- 检查这个月最近的纪念日
function PromoteDailyMgr:getCurMonthNearestKeyMedal()
    return self._modelLogic:getCurMonthNearestKeyMedal()
end

-- 获得所有的纪念日勋章配置列表
function PromoteDailyMgr:getKeyDayMedalCfgListByYear(year)
    return self._modelLogic:getKeyDayMedalCfgListByYear(year)
end

-- 根据年月日检查是否有纪念日配置
function PromoteDailyMgr:hasKeyDayMedal(year, month, day)
    return self._modelLogic:hasKeyDayMedal(year, month, day)
end

-- 获得某年的所有纪念日勋章
function PromoteDailyMgr:getKeyDayMedalCfgList(year)
    return self._modelLogic:getKeyDayMedalCfgList(year)
end

-- 根据id获得纪念日勋章配置
function PromoteDailyMgr:getKeyDayMedalCfgById(medalId)
    return self._modelLogic:getKeyDayMedalCfgById(medalId)
end

-- 判断是否已经领取了纪念日勋章
function PromoteDailyMgr:hasRewardedKeyDayMedal(medalId)
    return self._modelLogic:hasRewardedKeyDayMedal(medalId)
end

-- 获取monthmedalMeta
function PromoteDailyMgr:getYMMedalMeta(year, month)
    return self._modelLogic:getYMMedalMeta(year, month)
end

-- 根据月度勋章id获得monthMedalCfg
function PromoteDailyMgr:getMonthMedalCfgById(medalId)
    return self._modelLogic:getMonthMedalCfgById(medalId)
end

-- 是否有月度奖牌
function PromoteDailyMgr:hasMonthMedal(year, month)
    return self:getYMMedalMeta(year, month)
end

-- 根据y m获得头像框id
function PromoteDailyMgr:getHeadFrameId(year, month)
    return self._modelLogic:getHeadFrameId(year, month)
end

-- 7日任务限时头像框奖励
function PromoteDailyMgr:getTaskExtraReward()
    return self._modelLogic:getTaskExtraReward()
end

function PromoteDailyMgr:setTaskFinshiCount(count)
    return self._modelLogic:setTaskFinshiCount(count)
end

-- 获得七天任务完成了几天
function PromoteDailyMgr:getTaskFinishCount()
    return self._modelLogic:getTaskFinishCount()
end

-- 获得七天任务上次增加进度的时间
function PromoteDailyMgr:getTaskLastProgressTime()
    return self._modelLogic:getTaskLastProgressTime()
end

function PromoteDailyMgr:setTaskLastProgressTime(time)
    self._modelLogic:setTaskLastProgressTime(time)
end

-- 七天任务是否可以领取
function PromoteDailyMgr:getTaskCanReward()
    return self._modelLogic:getTaskCanReward()
end

-- 设置任务领取奖励时间
function PromoteDailyMgr:setTaskRewardTime(time)
    return self._modelLogic:setTaskRewardTime(time)
end

-- 七天任务是否已经领取
function PromoteDailyMgr:getTaskRewarded()
    return self._modelLogic:getTaskRewarded()
end

-- 获得今年所有的头像框和月度勋章奖励
function PromoteDailyMgr:getYearAllRewards(year)
    return self._modelLogic:getYearAllRewards(year)
end

-- 月度勋章创建有特殊处理
function PromoteDailyMgr:getPropIcon(reward)
    local monthCfg = self:getMonthMedalCfgById(reward.itemId)
    if monthCfg then
        -- 这里目前除了主界面不会展示到月度勋章，所以勋章资源跟着主界面走就行，一定会加载
        local medalIcon = Sprite:createWithSpriteFrameName(
            MainPanelConfig.FramePreProp .. monthCfg.year .. "_month_" .. monthCfg.month)
        return medalIcon
    end
    return GameItemCreator:getPropIcon(reward)
end

-- 商城的恭喜获得
function PromoteDailyMgr:showShopRewardsPanel(randomReward, params)
    return self._panelLogic:showShopRewardsPanel(randomReward, params)
end

-- 普通的恭喜获得
function PromoteDailyMgr:showNormalRewardsPanel(rewards, params)
    return self._panelLogic:showNormalRewardsPanel(rewards, params)
end

-- 尝试领取所有奖励，containToday:是否包含今天
function PromoteDailyMgr:tryGetAllRewards(containToday)
    return self._httpLogic:tryGetAllRewards(containToday)
end

-- 获得可以领取的月度奖励dayNumlist
function PromoteDailyMgr:getCanRewardMonthDayList(containToday)
    return self._modelLogic:getCanRewardMonthDayList(containToday)
end

-- 获得可以领取的纪念勋章dayNumList
function PromoteDailyMgr:getCanRewardMedalDayList(containToday)
    return self._modelLogic:getCanRewardMedalDayList(containToday)
end

-- 是否满签到了
function PromoteDailyMgr:isFullSign(year, month)
    return self._modelLogic:isFullSign(year, month)
end

-- 复数领奖
function PromoteDailyMgr:requestRewardMulti(param)
    return self._httpLogic:requestRewardMulti(param)
end

-- 领取新任务奖励
function PromoteDailyMgr:requestNewTaskReward(idxList, noLoading)
    return self._httpLogic:requestNewTaskReward(idxList, noLoading)
end

-- 领奖V2
function PromoteDailyMgr:requestRewardV2(param, noLoading)
    return self._httpLogic:requestRewardV2(param, noLoading)
end

-- 领奖
function PromoteDailyMgr:requestReward(param)
    return self._httpLogic:requestReward(param)
end

-- 根据year获得最高记录数据
function PromoteDailyMgr:getMaxRecordDataByYear(year, key)
    return self._modelLogic:getMaxRecordDataByYear(year, key)
end

-- 获取记录by year，month
function PromoteDailyMgr:getRecordDataByYM(year, month)
    return self._modelLogic:getRecordDataByYM(year, month)
end

-- 补翻
function PromoteDailyMgr:requestSign(param)
    return self._httpLogic:requestSign(param)
end

--保护小技巧：装备盾牌
function PromoteDailyMgr:todoEquipShield(callback)
    return self._panelLogic:todoEquipShield(callback)
end

--保护小技巧：安装组件
function PromoteDailyMgr:todoInstallComponent()
    return self._panelLogic:todoInstallComponent()
end

--保护小技巧：打开通知
function PromoteDailyMgr:todoOpenNotice(callback)
    return self._panelLogic:todoOpenNotice(callback)
end

function PromoteDailyMgr:openShieldPanel(closeCall)
    return self._panelLogic:openShieldPanel(closeCall)
end

function PromoteDailyMgr:getProtectTipPanelParams()
    return self._modelLogic:getProtectTipPanelParams()
end

function PromoteDailyMgr:openProtectTipPanel(closeCall)
    self._panelLogic:openProtectTipPanel(closeCall)
end

function PromoteDailyMgr:openShieldConfirmPanel(confirmCallback, closeCallback)
    self._panelLogic:openShieldConfirmPanel(confirmCallback, closeCallback)
end

function PromoteDailyMgr:openMainPanel(param)
    self._panelLogic:openMainPanel(param)
end

-- 获取7日任务进度
function PromoteDailyMgr:getTaskProgress()
    return self._modelLogic:getTaskProgress()
end

-- 获取7日任务奖励列表
function PromoteDailyMgr:getTaskRewardList()
    return self._modelLogic:getTaskRewardList()
end

-- 翻牌道具增减
function PromoteDailyMgr:addHandProp(num)
    return self._modelLogic:addHandProp(num)
end

-- 翻牌道具增减 购买的
function PromoteDailyMgr:addBuyHandProp(num)
    return self._modelLogic:addBuyHandProp(num)
end

function PromoteDailyMgr:getTotalHandPropNum()
    return self:getHandPropNum() + self:getBuyHandPropNum()
end

function PromoteDailyMgr:getHandPropNum()
    return self._modelLogic:getHandPropNum()
end

function PromoteDailyMgr:getBuyHandPropNum()
    return self._modelLogic:getBuyHandPropNum()
end

-- 引导
function PromoteDailyMgr:hasGuideIndex(index)
    return self._modelLogic:hasGuideIndex(index)
end

function PromoteDailyMgr:addGuideIndex(index)
    return self._modelLogic:addGuideIndex(index)
end

-- 获得补签的goodsId
function PromoteDailyMgr:getMakeUpGoodsId(year, month)
    return self._modelLogic:getMakeUpGoodsId(year, month)
end

-- 获得了累签到了多少天
function PromoteDailyMgr:getMonthSignCount(year,month)
	return self._modelLogic:getMonthSignCount(year,month)
end

-- 是否有新纪录
function PromoteDailyMgr:getNewRecordState()
    return self._modelLogic:getNewRecordState()
end

function PromoteDailyMgr:getTempValue(key)
    return self.model:getTempData(key)
end

function PromoteDailyMgr:setTempValue(key, value)
    return self.model:setTempData(key, value)
end

function PromoteDailyMgr:getActValue(key)
    return self.actInfo and self.actInfo[key]
end

function PromoteDailyMgr:getDataValue(key)
    local data = self.model and self.model:getValue("data")
    return data and data[key]
end

function PromoteDailyMgr:setDataValue(key, value)
    local data = self.model and self.model:getValue("data")
    if data then
        data[key] = value
        self.model:setValue("data", data)
    end
end

function PromoteDailyMgr:getConfigValue(key)
    local config = self.model and self.model:getValue("config")
    return config and config[key]
end

function PromoteDailyMgr:getLocalValue(key)
    local localSaveTb = self.model and self.model:getValue("localSaveTb") or {}
    return localSaveTb[key]
end

function PromoteDailyMgr:setLocalValue(key, value)
    local localSaveTb = self.model and self.model:getValue("localSaveTb") or {}
    localSaveTb[key] = value
    self.model:setValue("localSaveTb", localSaveTb)
end

function PromoteDailyMgr:setIconTipPopCount(num)
    return self._iconLogic:setIconTipPopCount(num)
end

function PromoteDailyMgr:getOpenMainPanelDay()
    local dayNum = self:getDataValue("openMainPanelDay")
    return dayNum or 0
end

function PromoteDailyMgr:setOpenMainPanelDay(num)
    if not num then return end
    self:setDataValue("openMainPanelDay", num)
end

-- 打点101
function PromoteDailyMgr:dc(category, subCategory, extraData)
    local params = {
        category = category,
        sub_category = subCategory,
    }

    for k, v in pairs(extraData or {}) do
        params[k] = v
    end
    -- self:log("PromoteDaily Dc:", tts(params))
    DcUtil:UserTrack(params)
end

function PromoteDailyMgr:createSunLight()
    local sp = Sprite:createWithSpriteFrameName(MainPanelConfig.FramePreProp.."sun")
    return sp
end

function PromoteDailyMgr:createShiledIcon()
    local sp = Sprite:createWithSpriteFrameName(MainPanelConfig.FramePreProp.."shield")
    return sp
end

function PromoteDailyMgr:showHelpRecordPanel(closeCallback)
    return self._panelLogic:showHelpRecordPanel(closeCallback)
end

function PromoteDailyMgr:openNameCardInfoPanel(param)
    self._panelLogic:openNameCardInfoPanel(param)
end

function PromoteDailyMgr:tryGetHandPropReward()
    return self._httpLogic:tryGetHandPropReward()
end

function PromoteDailyMgr:showSelectTargetPanel(ubfDelegate)
    return self._panelLogic:showSelectTargetPanel(ubfDelegate)
end

function PromoteDailyMgr:showActIntroPanel(pageIndex, closeCallback)
    return self._panelLogic:showActIntroPanel(pageIndex, closeCallback)
end

function PromoteDailyMgr:createDailyPass(delegate)
    local DailyPass = require "amf.feature.dailyreward.promotedaily.view.comps.dailypass.DailyPass"
    local item = DailyPass:create(delegate)
    return item
end

function PromoteDailyMgr:showTargetPanel(closeCallback)
    return self._panelLogic:showTargetPanel(closeCallback)
end

function PromoteDailyMgr:showArriveDailyPanel(params, closeCallback)
    return self._panelLogic:showArriveDailyPanel(params, closeCallback)
end

-- 重燃活动结算界面
function PromoteDailyMgr:showRepairPanel(params, closeCallback)
    return self._panelLogic:showRepairPanel(params, closeCallback)
end

function PromoteDailyMgr:getActAutoPopUniqueKey()
	return self._iconLogic:getActAutoPopUniqueKey()
end

function PromoteDailyMgr:clearActAutoPopUniqueKey()
    return self._iconLogic:clearActAutoPopUniqueKey()
end

function PromoteDailyMgr:getNextTaskByTask(taskInfo)
    return self._modelLogic:getNextTaskByTask(taskInfo)
end

function PromoteDailyMgr:getPreTaskByTask(taskInfo)
    return self._modelLogic:getPreTaskByTask(taskInfo)
end

function PromoteDailyMgr:getShieldNum()
    return self._modelLogic:getShieldNum()
end

function PromoteDailyMgr:addShieldNum(num)
    return self._modelLogic:addShieldNum(num)
end

-- 获得帮助数据
function PromoteDailyMgr:isCanGetBeHelpedReward()
    return self._modelLogic:isCanGetBeHelpedReward()
end

-- 获得所有可领取的任务index
function PromoteDailyMgr:getAllTargetCanRewardList()
    return self._modelLogic:getAllTargetCanRewardList()
end

-- 获取选择目标数据
function PromoteDailyMgr:getTargetValue(key)
    local chooseData = self:getDataValue("chooseProgressTaskData") or {}
    return chooseData[key]
end

-- 设置选择目标数据
function PromoteDailyMgr:setTargetValue(key, value)
    local chooseData = self:getDataValue("chooseProgressTaskData") or {}
    chooseData[key] = value
    self:setDataValue("chooseProgressTaskData", chooseData)
end

-- 获得是否是当前的目标
function PromoteDailyMgr:isCurTarget(year, month, day)
    return self._modelLogic:isCurTarget(year, month, day)
end

function PromoteDailyMgr:getCurTaskTargetData()
    return self._modelLogic:getCurTaskTargetData()
end

function PromoteDailyMgr:getLastTaskTargetData()
    return self._modelLogic:getLastTaskTargetData()
end

function PromoteDailyMgr:hasTargetTaskCanReward()
    return self._modelLogic:hasTargetTaskCanReward()
end

function PromoteDailyMgr:isTargetTaskCanReward(index)
    return self._modelLogic:isTargetTaskCanReward(index)
end

-- 获取选择目标任务数据
function PromoteDailyMgr:getTargetTaskData(index)
    return self._modelLogic:getTargetTaskData(index)
end

function PromoteDailyMgr:checkShareState()
    local isSupportShare, isWeiboInstalled, isWeixinInstalled, _ = ShareCenterUtil:checkShareState()
    if EnvUtil:isOhos() then
        isSupportShare = false
    end
    return isSupportShare, isWeiboInstalled, isWeixinInstalled, _
end

-- 获取当前的所有任务
function PromoteDailyMgr:getTargetTaskDataAll()
    return self._modelLogic:getTargetTaskDataAll()
end

-- 是否是里程目标
function PromoteDailyMgr:isMileTask(target)
    return self._modelLogic:isMileTask(target)
end

-- 获得盾牌使用记录
-- isUse: true:使用 false:获得的
function PromoteDailyMgr:getShieldRecordList(isUse)
    return self._modelLogic:getShieldRecordList(isUse)
end

function PromoteDailyMgr:setShiledRecordListShowed()
    return self._modelLogic:setShiledRecordListShowed()
end

function PromoteDailyMgr:isUseNewUI(year, month)
    year = year or self:getYear()
    month = month or self:getMonth()
    return MainPanelConfig:isNewUI(year, month)
end

function PromoteDailyMgr:openAskForHandPanel(closeCall, param)
    return self._panelLogic:openAskForHandPanel(closeCall, param)
end

-- 关卡内事件
function PromoteDailyMgr:onActEndlevelProgressPrepare(event)
    if not self:isEnabled() then return end
    local data = event:getData()
    self._levelLogic:doActEndlevelProgressPrepare(data)
end

function PromoteDailyMgr:onActEndlevelProgressThirdPartStart( event )
	local data = event:getData()
    if not data or data.processNodeKey ~= UBFProcessNodeEnum.PROMOTE_DAILY_CLIMB then return end
    self._levelLogic:doActEndlevelProgressThirdPartStart( data )
end

function PromoteDailyMgr:tryInitIcon()
    if not self:isLocalEnabled() then 
        return 
    end
    local isAllReaday = true
    if not self:isPublicResReady() then 
        self:tryLoadPublicRes()
        isAllReaday = false
    end
    if not self:getDataValue("isFromServer") then
        self:requestMainInfoOnLightStart()
        isAllReaday = false
    end
    if isAllReaday then
        -- 刷新一下icon
        PromoteDailyEventCenter:dispatch(PromoteDailyEvent.PUB_RES_READAY)
    end
end

function PromoteDailyMgr:onActEnterStage2(evt)
    -- 连过重燃：活动期首次进主场景强弹「限时救回连过」介绍界面（每期一次，见 PromoteDailyAutoPopoutLogic）
    self._autoPopLogic:beginEnterStage2()
    self:tryInitIcon()
    self._autoPopLogic:doActEnterStage2()
    self._autoPopLogic:endEnterStage2()
end

function PromoteDailyMgr:onActEnterStage4()
    if not self:isEnabled() then return end
    self._autoPopLogic:doActEnterStage4()
end

function PromoteDailyMgr:canPopStage4()
    return self._autoPopLogic:canPopStage4()
end

function PromoteDailyMgr:onActEndlevelProgressForceComplete( event )
	local data = event:getData()
    if not data or data.processNodeKey ~= UBFProcessNodeEnum.PROMOTE_DAILY_CLIMB then return end
    self._levelLogic:resetData()
end

function PromoteDailyMgr:hasBeenProtected()
    return self._iconLogic:hasBeenProtected()
end

function PromoteDailyMgr:getBannerCountDownRange()
    return self._iconLogic:getBannerCountDownRange()
end

function PromoteDailyMgr:checkIconTip(config)
    return self._iconLogic:checkIconTip(config)
end

function PromoteDailyMgr:isPromoteDailyIconV2Active()
    return self._iconLogic and self._iconLogic:isV2IconActive() or false
end

-- 重燃 Banner 是否正等「达标当关」的过关光效（见 PromoteDailyRepairBannerLogic:waitSignFlowForFinish）
function PromoteDailyMgr:isRepairBannerSignFlowPending()
    return self._repairBannerLogic ~= nil and self._repairBannerLogic:isSignFlowPending()
end

function PromoteDailyMgr:createPromoteDailyPassLevelAnimationTask(options)
    if not self._iconLogic then return nil end
    return self._iconLogic:createPassLevelAnimationTask(options)
end

-- 目前没用
function PromoteDailyMgr:onActCollectAnimJumped()
    self._infoNodeLogic:clearInfoNode()
    self._iconLogic:playJumAnim()
end

function PromoteDailyMgr:onActEnterMainScene(evt)
    if not self:isEnabled() then return end
    local data = evt:getData() or {}
    -- 如果要飞动画就不要刷新banner了，等飞完自己会刷新的
    if self:isCanPlayBannerAni() then
        local levelPlayInfo = data.levelPlayInfo
        -- 可能是从每日寻宝出来的，该玩法不走场景3，需要在这里直接播放。
        if levelPlayInfo and levelPlayInfo.levelScene == UBFLevelSceneType.kDailyLevelGameplay then
            self._levelLogic:doActLevelCollectionNewAni(data)
        end
        return
    end
    -- 主场景没有待播的过关动画：达标 Banner 不必再等光效，直接按最新状态判定去留
    if self._repairBannerLogic then
        self._repairBannerLogic:onMainSceneEnteredWithoutAni()
    end
    self._infoNodeLogic:doActEnterMainScene(data)
end

--大藤蔓飞活动收集物到活动Icon
function PromoteDailyMgr:onActLevelCollectionNewAni(event)
	if not self:isEnabled() then return end
    local data = event:getData()
	self._levelLogic:doActLevelCollectionNewAni(data)
end

function PromoteDailyMgr:setCanPlayBannerAni(value)
    self._canPlayBannerAni = value
end

function PromoteDailyMgr:isCanPlayBannerAni()
    return self._canPlayBannerAni
end

-- 本关是否为「重燃任务达标当关」（在 doActPlayLevelEnd 里按每次过关刷新）：
-- 达标当关的过关光效由重燃 Banner 播，光效播完 icon 退出冰封态并照常在 icon spine 上播翻牌
-- （icon 侧不再按这个标记跳过翻牌，标记保留给测试沙箱还原真实过关链路）
function PromoteDailyMgr:setRepairActCompletePass(value)
    self._repairActCompletePass = value == true
end

function PromoteDailyMgr:isRepairActCompletePass()
    return self._repairActCompletePass == true
end

function PromoteDailyMgr:retainResOnce(files)
    self._resLogic:retainResOnce(files)
end

function PromoteDailyMgr:releaseRes(fileList)
    self._resLogic:releaseRes(fileList)
end

---------------------------------- CUSTOM_GAIN / CUSTOM_CONSUME ----------------------------------

function PromoteDailyMgr:_onCustomGain(event)
    local reward = event:getData()
    local itemId = reward.itemId
    if itemId == PromoteDailyConst.SHIELD_ID then
        self:addShieldNum(reward.num or 1)
    elseif itemId == PromoteDailyConst.SIGN_PROP_ID then
        self:addHandProp(reward.num or 1)
    elseif itemId == PromoteDailyConst.SIGN_PROP_BUY_ID then
        self:addBuyHandProp(reward.num or 1)
    end
end

function PromoteDailyMgr:_onCustomConsume(event)
    local reward = event:getData()
    local itemId = reward.itemId
    if itemId == PromoteDailyConst.SHIELD_ID then
        self:addShieldNum(-1)
    elseif itemId == PromoteDailyConst.SIGN_PROP_ID then
        self:addHandProp(-1)
    elseif itemId == PromoteDailyConst.SIGN_PROP_BUY_ID then
        self:addBuyHandProp(-1)
    end
end

return PromoteDailyMgr
