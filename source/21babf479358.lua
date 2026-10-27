local PromoteDailyEventCenter = require "amf.feature.dailyreward.promotedaily.event.PromoteDailyEventCenter"
local deferred = require "amf.script.sugar.deferred"
local Utils = require "amf.feature.dailyreward.promotedaily.util.Utils"
local TimeUtil = require "amf.middleware.ui.util.TimeUtil"
local PromoteDailyModelLogic = class("PromoteDailyModelLogic")

function PromoteDailyModelLogic:init(mgr, model)
    self._promoteDailyMgr = mgr
    self._model = model
end

function PromoteDailyModelLogic:create(mgr)
    local ret = PromoteDailyModelLogic.new()
    ret:init(mgr)
    return ret
end

-- 是否有奖励可以领取
function PromoteDailyModelLogic:checkCanPopGetRewards(containToday)
    local monthDayListEnable = false
    local medalDayListEnable = false
    self:getCanRewardMonthDayList(containToday):next(function(monthDayList)
        monthDayListEnable = not table.isEmpty(monthDayList)
    end)
    self:getCanRewardMedalDayList(containToday):next(function(medalDayList)
        medalDayListEnable = not table.isEmpty(medalDayList)
    end)
    return monthDayListEnable or medalDayListEnable
end

-- 重置今天的信息
function PromoteDailyModelLogic:resetTodayInfo()
    local sec = TimeKit:timeInSec()
    local tb = os.date2(sec)
    self._year = tb.year
    self._month = tb.month
    self._day = tb.day
    self._todayNum = time2day(sec)
    self:resetContinuseInfo()
    local yesterday = TimeKit:getDayStartTimeByTS(sec - 2)
    local yesDate = os.date2(yesterday)
    local bPassMonth = yesDate.month ~= tb.month
    if bPassMonth then
        self:resetMonthInfo()
    end
end

-- 重置盾的数据
function PromoteDailyModelLogic:resetMainInfoChange()
    -- 盾牌为0 不处理
    local shiledNum = self:getShieldNum()
    if shiledNum == 0 then return end
    -- 昨天是否打关了,不是0就不处理了
    local yesterdayNum = self:getTodayNum() - 1
    local yesterDayDate = Utils:getYMDByDayCount(yesterdayNum)
    local signState = self:getSignState(yesterDayDate.year, yesterDayDate.month, yesterDayDate.day)
    if signState ~= PromoteDailyConst.SignState.NONE then
        return
    end

    -- 前天是否打关或者shield
    local checkDayNum = yesterdayNum - 1
    local qiantianDate = Utils:getYMDByDayCount(checkDayNum)
    signState = self:getSignState(qiantianDate.year, qiantianDate.month, qiantianDate.day)
    if not PromoteDailyConst.isContinousState(signState) then
        return
    end
    -- 可以保护了
    -- 减去1个盾
    self:addShieldNum(-1)
    self:setSignState(yesterDayDate.year, yesterDayDate.month, yesterDayDate.day, PromoteDailyConst.SignState.SHIELD)
    -- 再刷新一下连过信息
    self:resetContinuseInfo()
end

-- 跨天重置任务数据
function PromoteDailyModelLogic:resetModel()
    local rewardTime = self:getTaskRewardTime()
    local lastProTime = self:getTaskLastProgressTime()
    local finishProgress = self:getTaskFinishCount()
    local diaryTaskData = self._promoteDailyMgr:getDataValue("diaryTaskData") or {}
    -- 检查一下任务，如果是昨天领完奖，今天是不会刷新的，只会等到passlevel的时候，这时候打开主界面会显示已领取，处理一下
    local rewardDay = TimeUtil:getDayIdxSince1970(rewardTime)
    local updateDay = TimeUtil:getDayIdxSince1970(lastProTime)
    local todayNum = self._todayNum
    if self:getTaskRewarded() then
        if rewardDay ~= todayNum then
            diaryTaskData.finishProgress = 0
            diaryTaskData.rewardTime = 0
            diaryTaskData.lastUpdateProgressTime = 0
        end
    elseif self:getTaskCanReward() then
        -- 可以领奖不操作
    else
        -- 没有领奖也 不可领奖，超过一天重置
        if finishProgress > 0 and todayNum - updateDay > 1 then
            diaryTaskData.finishProgress = 0
            diaryTaskData.rewardTime = 0
            diaryTaskData.lastUpdateProgressTime = 0
        end
    end
    self._promoteDailyMgr:setDataValue("diaryTaskData", diaryTaskData)
end

function PromoteDailyModelLogic:doPassDay()
    self:resetTodayInfo()
    self:resetMainInfoChange()
    self:resetModel()
end

-- 重置连续过关信息
function PromoteDailyModelLogic:resetContinuseInfo()
    local count = 0
    -- 今天是第几天
    local dayNum = self._todayNum
    local endNum = 0
    local startNum = 0
    while true do
        local date = Utils:getYMDByDayCount(dayNum)
        local signState = self:getSignState(date.year, date.month, date.day)
        -- 次数>0说明是有passCount的，可以算连过天数
        if PromoteDailyConst.isContinousState(signState) then
            if endNum == 0 then
                endNum = dayNum
            end
            count = count + 1
            dayNum = dayNum - 1
        else
            if dayNum == self._todayNum then
                dayNum = dayNum - 1
            else
                startNum = dayNum + 1
                break
            end
        end
    end
    -- 仅本地推导值，连过天数展示/比较以服务端 mainInfo.continuousPassingDay 为准；
    -- 过关的本地 +1 走 PromoteDailyMgr:addContinousPassNum（活动期间改为累加 repairTaskInfo.progress）
    self.continousPassNum = count
    self.continousPassBeginNum = startNum
    self.continousPassEndNum = endNum
end

-- 重制帮助记录信息
function PromoteDailyModelLogic:resetMonthInfo()
    local helpData = self._promoteDailyMgr:getDataValue("helpData") or {}
    local beHelpedList = helpData.beHelpRecordList or {}
    local newList = {}
    for _, v in ipairs(beHelpedList) do
        if not v.rewardMonth or v.rewardMonth == 0 then
            newList[#newList + 1] = v
        end
    end
    helpData.beHelpRecordList = newList
    self._promoteDailyMgr:setDataValue("helpData", helpData)
end

-- 判断使用盾牌是否播放过
function PromoteDailyModelLogic:isUseShieldShowed(dayNum)
    local useShowedList = self._promoteDailyMgr:getLocalValue("useShiledPlayedList") or {}
    return table.exist(useShowedList, dayNum)
end

-- 设置使用盾牌已经播过了
function PromoteDailyModelLogic:setUseShieldShowed(dayNum)
    local useShowedList = self._promoteDailyMgr:getLocalValue("useShiledPlayedList") or {}
    if not table.exist(useShowedList, dayNum) then
        table.insert(useShowedList, dayNum)
        self._promoteDailyMgr:setLocalValue("useShiledPlayedList", useShowedList)
    end
end

-- 获得最近的两个shiled类型的数据
function PromoteDailyModelLogic:getShiledDateInfoByLimit(limitCount)
    local list = {}
    -- 今天是第几天
    local dayNum = self._todayNum
    while true do
        local date = Utils:getYMDByDayCount(dayNum)
        local signState = self:getSignState(date.year, date.month, date.day)
        if signState == PromoteDailyConst.SignState.SHIELD then
            date.dayNum = dayNum
            table.insert(list, 1, date)
        end
        if table.count(list) >= limitCount then
            break
        end
        dayNum = dayNum - 1
        -- 保护一下，万一数据错了死循环了
        if dayNum < PromoteDailyConst.ACT_OPEN_DAYNUM then
            break
        end
    end
    return list
end

function PromoteDailyModelLogic:resetTaskValue()
    self:setTaskFinshiCount(0)
    self:setTaskRewardTime(0)
    self:setTaskLastProgressTime(0)
end

function PromoteDailyModelLogic:resetTaskData()
    -- 检查一下任务，如果是昨天领完奖，今天是不会刷新的，只会等到passlevel的时候，这时候打开主界面会显示已领取，处理一下
    local diaryTaskData = self._promoteDailyMgr:getDataValue("diaryTaskData") or {}
    local rewardDay = TimeUtil:getDayIdxSince1970(diaryTaskData.rewardTime)
    local updateDay = TimeUtil:getDayIdxSince1970(diaryTaskData.lastUpdateProgressTime)
    local todayNum = TimeUtil:getDayIdxSince1970(TimeKit:timeInSec())
    if self:getTaskRewarded() then
        if rewardDay ~= todayNum then
            self:resetTaskValue()
        end
    elseif self:getTaskCanReward() then
        -- 可以领奖不操作
    else
        -- 没有领奖也 不可领奖，超过一天重置
        if diaryTaskData.lastUpdateProgressTime > 0 and todayNum - updateDay > 1 then
            self:resetTaskValue()
        end
    end
end

function PromoteDailyModelLogic:getSignState(year, month, day)
    day = tonumber(day)
    local monthData = self:getMonthDataByYM(year, month)
    if monthData and monthData.dayMarkStatus then
        return monthData.dayMarkStatus[day] or PromoteDailyConst.SignState.NONE
    end
    return PromoteDailyConst.SignState.NONE
end

function PromoteDailyModelLogic:setSignState(year, month, day, state)
    local key = string.format("%d_%d", year, month - 1)
    local monthStatMap = self._promoteDailyMgr:getDataValue("monthStatMap") or {}
    if monthStatMap[key] and monthStatMap[key].dayMarkStatus then
        monthStatMap[key].dayMarkStatus[tonumber(day)] = state
        self._promoteDailyMgr:setDataValue("monthStatMap", monthStatMap)
    end
end

function PromoteDailyModelLogic:getCurrentTargetPro()
    local chooseTaskOK = self._promoteDailyMgr:getDataValue("chooseTaskOK")
    local curPro, fullTarget, lastTarget
    if chooseTaskOK then
        local curTaskInfo = self:getCurTaskTargetData()
        local lastTaskInfo = self:getLastTaskTargetData()
        curPro = self:getContinousPassDayCount()
        fullTarget = curTaskInfo and curTaskInfo.target or PromoteDailyConst.TASK_REWARD_DAY
        lastTarget = lastTaskInfo and lastTaskInfo.target or 0
        return curPro - lastTarget, fullTarget - lastTarget
    else
        curPro = self:getTaskFinishCount()
        fullTarget = PromoteDailyConst.TASK_REWARD_DAY
        return curPro, fullTarget
    end
end

function PromoteDailyModelLogic:getUnsignTimeRange()
    local testTimeRange = self._promoteDailyMgr:getConfigValue("clientCd") or "00:00:00-19:59:59"
    local pattern = "(%d+):(%d+):(%d+)-(%d+):(%d+):(%d+)"
    local sh, sm, ss, eh, em, es = string.match(testTimeRange, pattern)
    return {
        startTime = sh * 3600 + sm * 60 + ss,
        endTime = eh * 3600 + em * 60 + es
    }
end

-- 是否有月度奖牌可以领取
function PromoteDailyModelLogic:checkCanRewardMonthMedal(year, month)
    if not self:isFullSign(year, month) then
        return false
    end
    local medalCfg = self:hasMonthMedal(year, month)
    if not medalCfg then
        return false
    end
    if self:hasRewardMonthMedal(medalCfg.medalId) then
        return false
    end
    return true
end

-- 获得目标月的最后一天
function PromoteDailyModelLogic:getLastDayByYM(year, month)
    local monthData = self:getMonthDataByYM(year, month)
    if monthData and monthData.dayMarkStatus then
        return #monthData.dayPassNums
    end
    return 1
end

-- 是否领取了月度奖励
function PromoteDailyModelLogic:hasRewardMonthMedal(medalId)
    local monthMedalIdList = self._promoteDailyMgr:getDataValue("monthMedalIdList") or {}
    return table.exist(monthMedalIdList, medalId)
end

function PromoteDailyModelLogic:getMonthDataByYM(year, month)
    local key = string.format("%d_%d", year, month - 1)
    local monthData = self._promoteDailyMgr:getDataValue("monthStatMap") or {}
    return monthData[key]
end

-- 获得对应天的过关次数
function PromoteDailyModelLogic:getPassLevelCount(year, month, day)
    local monthData = self:getMonthDataByYM(year, month)
    if monthData and monthData.dayPassNums then
        return monthData.dayPassNums[day]
    end
    return 0
end

-- 获得连续过关天数
function PromoteDailyModelLogic:getContinousPassDayCount()
    -- 唯一来源改为服务端下发的 mainInfo.continuousPassingDay
    local num = tonumber(self._promoteDailyMgr:getDataValue(PromoteDailyConst.CONTINUOUS_PASS_FIELD))
    if num == nil or num < 0 then
        return 0
    end
    return math.floor(num)
end

function PromoteDailyModelLogic:getContinousPassEndNum()
    return self.continousPassEndNum or 0
end

function PromoteDailyModelLogic:getContinousPassBeginNum()
    return self.continousPassBeginNum or 0
end

-- 客户端自己按日历算出来的「当前连过天数」（含今天；状态 0 没签到 / 状态 5 重燃冰封都不算连过，
--   碰到就把连过截断）—— 来源是 resetContinuseInfo 的连续段统计。
-- 【只在这里用】唯一消费方是 getSevenDaySlotIndex（出关七日条「今天在第几格」）；
--   其余任何展示 / 比较 / 打点 / 里程碑判断都必须走服务端值 getContinousPassDayCount
--   （mainInfo.continuousPassingDay；它可能被重燃「救回来」，和自算值本来就不是一个数）。
function PromoteDailyModelLogic:getLocalContinousPassDayCount()
    local num = tonumber(self.continousPassNum)
    if num == nil or num < 0 then
        return 0
    end
    return math.floor(num)
end

-- 出关七日条：今天落在第几格（1~7）= ((连过天数 - 1) % 7) + 1，连过天数含今天这一关
--   新旧七天任务**统一**用「客户端自己算出来的当前连过天数」（2026-09-18 统一口径）：
--   新七天任务（连过里程碑）本来就是这么算的（2026-09-17 产品口径：连过天数后端值可能是重燃
--     「救回来」的旧值，位置要用自己算的，这样今天在第几格、前面补的格子、真正算连过的日子三者自洽）；
--   旧七天任务原先用服务端 diaryTaskData.finishProgress 定位，但它和「算连过的日子」不是一个口径
--     （状态 5 那天、被数据工具改过的那天都会算进任务进度、却不进七日数据），进度比连过天数大时
--     今天左边就会空出格子，2026-09-18 修掉这个空日期后与上面收敛成同一条。
--   注意：finishProgress 只用于七日任务自身的进度 / 领奖判断，不再参与「今天在第几格」。
function PromoteDailyModelLogic:getSevenDaySlotIndex()
    local progress = self:getLocalContinousPassDayCount()
    if progress < 1 then
        progress = 1
    end
    return (progress - 1) % PromoteDailyConst.TASK_REWARD_DAY + 1
end

-- 七日数据取数口（出关七日条 / 七天任务条专用）：取 7 个格子 = 今天所在的那个 7 天连过周期
--   今天在第 getSevenDaySlotIndex() 格（新旧任务统一 = 自算连过天数）
--   索引 1~7 = 七日条从左到右：
--     今天之前那几格 = 今天之前刚连过的日子（日期从今天往前顺推：自算连过天数 ≥ 今天所在格，
--       所以这几格一定都是算连过的日子，直接读日历就是点亮态，不需要再判断）；
--     今天这格 = 读今天的签到态（状态 5 按未签兜底）；
--     今天之后那几格 = 还没到的日子，一定未签，直接给 NONE（不读日历）。
-- 口径：状态 0（没签到）与状态 5（重燃期间打关，算签到但不算连过）都不算连过，因此都不会出现在
--   七日数据里（不占格子、不点亮），也就不会出现「空的日期」（2026-09-17 产品口径）。
--   状态 5 的表达只留给主面板月历（Calendar / Card），主面板仍走 getSignState（保留 5）。
function PromoteDailyModelLogic:getSevenDaySlots()
    local today = self:getTodayNum()
    local todaySlotIndex = self:getSevenDaySlotIndex()
    local slots = {}
    for i = 1, PromoteDailyConst.TASK_REWARD_DAY do
        -- 相对今天的天数偏移：负 = 今天之前（刚连过的日子）、0 = 今天、正 = 还没到的日子
        local offset = i - todaySlotIndex
        local date = Utils:getYMDByDayCount(today + offset)
        local signState
        if offset > 0 then
            signState = PromoteDailyConst.SignState.NONE
        else
            signState = self:getSignState(date.year, date.month, date.day)
            -- 状态 5 不进七日数据：该天按未签处理（该格不点亮）
            if signState == PromoteDailyConst.SignState.REPAIR then
                signState = PromoteDailyConst.SignState.NONE
            end
        end
        slots[i] = {
            index = i,
            date = date,
            -- 星期几：1 = 周一 ... 7 = 周日
            weekIndex = Utils:getWeekDayByTime(date),
            signState = signState,
            isToday = i == todaySlotIndex,
        }
    end
    return slots
end

-- 上一段连过（连续过关）区间的开始 / 结束 dayNum：找不到返回 0, 0
-- 口径与 resetContinuseInfo 一致（状态 SIGN / SHIELD 才算连过），区别是遇到「当前这段断签」不退出，
-- 继续往前找第一段连过；找这段连过的「结束日」时最多回溯到 minNum（0 / 缺省表示不设下限）
function PromoteDailyModelLogic:getLastContinousPassRange(fromNum, minNum)
    fromNum = tonumber(fromNum) or self._todayNum
    minNum = tonumber(minNum) or 0
    local endNum = 0
    local dayNum = fromNum
    while dayNum > 0 and (minNum <= 0 or dayNum >= minNum) do
        if self:_isContinousDayNum(dayNum) then
            endNum = dayNum
            break
        end
        dayNum = dayNum - 1
    end
    if endNum <= 0 then return 0, 0 end
    local beginNum = endNum
    while beginNum > 1 do
        if not self:_isContinousDayNum(beginNum - 1) then break end
        beginNum = beginNum - 1
    end
    return beginNum, endNum
end

-- 某天（dayNum：70 年起的天数）是否算连过（状态 SIGN / SHIELD）
function PromoteDailyModelLogic:_isContinousDayNum(dayNum)
    local date = Utils:getYMDByDayCount(dayNum)
    return PromoteDailyConst.isContinousState(self:getSignState(date.year, date.month, date.day))
end

-- 是否是连续过关天数
function PromoteDailyModelLogic:isContinousPassDay(year, month, day)
    local dayNum = Utils:getDayNumByYMD(year, month, day)
    if dayNum >= self.continousPassBeginNum and dayNum <= self.continousPassEndNum then
        return true
    end
    return false
end

-- 是否是最近的连过那天
function PromoteDailyModelLogic:isNewestContiPassday(year, month, day)
    local dayNum = Utils:getDayNumByYMD(year, month, day)
    return dayNum == self.continousPassEndNum
end

-- 获得未来x天内有没有纪念日
function PromoteDailyModelLogic:getFutureKeyDayByLimit(limit)
    limit = limit or 3
    local curDayNum = self._todayNum
    for i = 0, limit do
        local nextNum = curDayNum + i
        local date = Utils:getYMDByDayCount(nextNum)
        local medalMeta = self:hasKeyDayMedal(date.year, date.month, date.day)
        -- 有配置，并且勋章那边有id，说明已经更到了, 没有配置也不行
        if medalMeta and _G.amfBean("PropManager"):isNameMedalProp(medalMeta.medalId) and self._promoteDailyMgr:isResCfgEnabled(date.year, date.month) then
            return medalMeta, i
        end
    end
    return nil, nil
end

-- 检查这个月最近的纪念日
function PromoteDailyModelLogic:getCurMonthNearestKeyMedal()
    local eventMedalList = self._promoteDailyMgr:getConfigValue("eventMedalList") or {}
    for i, v in ipairs(eventMedalList) do
        if v.year == self:getYear() and v.month == self:getMonth() and v.day > self:getDay() then
            return v
        end
    end
    return nil
end

-- 获得所有的纪念日勋章配置列表
function PromoteDailyModelLogic:getKeyDayMedalCfgListByYear(year)
    year = year or self._year
    local list = {}
    local eventMedalList = self._promoteDailyMgr:getConfigValue("eventMedalList") or {}
    for i, v in ipairs(eventMedalList) do
        if v.year == year then
            table.insert(list, v)
        end
    end
    return list
end

-- 根据年月日检查是否有纪念日配置
function PromoteDailyModelLogic:hasKeyDayMedal(year, month, day)
    local eventMedalList = self._promoteDailyMgr:getConfigValue("eventMedalList") or {}
    for i, v in ipairs(eventMedalList) do
        if v.year == year and v.month == month and v.day == day then
            return v
        end
    end
    return nil
end

-- 获得某年的所有纪念日勋章
function PromoteDailyModelLogic:getKeyDayMedalCfgList(year)
    year = year or self._year
    local list = {}
    local eventMedalList = self._promoteDailyMgr:getConfigValue("eventMedalList") or {}
    for i, v in ipairs(eventMedalList) do
        if v.year == year then
            table.insert(list, v)
        end
    end
    return list
end

-- 根据id获得纪念日勋章配置
function PromoteDailyModelLogic:getKeyDayMedalCfgById(medalId)
    local eventMedalList = self._promoteDailyMgr:getConfigValue("eventMedalList") or {}
    for i, v in ipairs(eventMedalList) do
        if v.medalId == medalId then
            return v
        end
    end
    return nil
end

-- 判断是否已经领取了纪念日勋章
function PromoteDailyModelLogic:hasRewardedKeyDayMedal(medalId)
    local eventMedalIdList = self._promoteDailyMgr:getDataValue("eventMedalIdList") or {}
    return table.exist(eventMedalIdList, medalId)
end

-- 获取monthmedalMeta
function PromoteDailyModelLogic:getYMMedalMeta(year, month)
    year = tonumber(year)
    month = tonumber(month)
    local monthMedalList = self._promoteDailyMgr:getConfigValue("monthMedalList") or {}
    for i, v in ipairs(monthMedalList) do
        if v.year == year and v.month == month then
            return v
        end
    end
    return nil
end

-- 根据月度勋章id获得monthMedalCfg
function PromoteDailyModelLogic:getMonthMedalCfgById(medalId)
    medalId = tonumber(medalId)
    local monthMedalList = self._promoteDailyMgr:getConfigValue("monthMedalList") or {}
    for i, v in ipairs(monthMedalList) do
        if v.medalId == medalId then
            return v
        end
    end
    return nil
end

-- 根据y m获得头像框id
function PromoteDailyModelLogic:getHeadFrameId(year, month)
    local headFrameId = nil
    local monthMedal = self:hasMonthMedal(year, month)
    if not monthMedal then
        return headFrameId
    end
    for i, v in ipairs(monthMedal.rewardItemList) do
        if _G.amfBean("PropManager"):isHeadFrame(v.itemId) then
            headFrameId = v.itemId
            break
        end
    end
    return headFrameId
end

-- 7日任务限时头像框奖励
function PromoteDailyModelLogic:getTaskExtraReward()
    local diaryTaskData = self._promoteDailyMgr:getDataValue("diaryTaskData") or {}
    if diaryTaskData.limitedTimeAvatarFrame then
        return diaryTaskData.limitedTimeAvatarFrame[1]
    end
    return nil
end

function PromoteDailyModelLogic:setTaskFinshiCount(count)
    local diaryTaskData = self._promoteDailyMgr:getDataValue("diaryTaskData") or {}
    diaryTaskData.finishProgress = count
    self._promoteDailyMgr:setDataValue("diaryTaskData", diaryTaskData)
end

-- 获得七天任务完成了几天
function PromoteDailyModelLogic:getTaskFinishCount()
    local diaryTaskData = self._promoteDailyMgr:getDataValue("diaryTaskData") or {}
    return diaryTaskData.finishProgress or 0
end

-- 获得七天任务上次增加进度的时间
function PromoteDailyModelLogic:getTaskLastProgressTime()
    local diaryTaskData = self._promoteDailyMgr:getDataValue("diaryTaskData") or {}
    return math.floor(diaryTaskData.lastUpdateProgressTime or 0)
end

function PromoteDailyModelLogic:setTaskLastProgressTime(time)
    local diaryTaskData = self._promoteDailyMgr:getDataValue("diaryTaskData") or {}
    diaryTaskData.lastUpdateProgressTime = math.floor(time)
    self._promoteDailyMgr:setDataValue("diaryTaskData", diaryTaskData)
end

-- 七天任务是否可以领取
function PromoteDailyModelLogic:getTaskCanReward()
    if self._promoteDailyMgr:getDataValue("chooseTaskOK") then return false end
    local finishCount = self:getTaskFinishCount()
    local lastProTime = self:getTaskLastProgressTime()
    local rewardTime = self:getTaskRewardTime()
    return lastProTime > 0
        and finishCount == PromoteDailyConst.TASK_REWARD_DAY
        and TimeUtil:getDayIdxSince1970(lastProTime) ~= TimeUtil:getDayIdxSince1970(rewardTime)
end

-- 七天任务上次领取奖励的时间
function PromoteDailyModelLogic:getTaskRewardTime()
    local diaryTaskData = self._promoteDailyMgr:getDataValue("diaryTaskData") or {}
    return math.floor(diaryTaskData.rewardTime or 0)
end

-- 设置任务领取奖励时间
function PromoteDailyModelLogic:setTaskRewardTime(time)
    local diaryTaskData = self._promoteDailyMgr:getDataValue("diaryTaskData") or {}
    diaryTaskData.rewardTime = math.floor(time)
    self._promoteDailyMgr:setDataValue("diaryTaskData", diaryTaskData)
end

-- 七天任务是否已经领取
function PromoteDailyModelLogic:getTaskRewarded()
    local finishCount = self:getTaskFinishCount()
    local rewardTime = self:getTaskRewardTime()
    local lastProTime = self:getTaskLastProgressTime()
    return rewardTime > 0
        and finishCount == 0
        and TimeUtil:getDayIdxSince1970(rewardTime) == TimeUtil:getDayIdxSince1970(lastProTime)
end

-- 是否有月度奖牌
function PromoteDailyModelLogic:hasMonthMedal(year, month)
    return self:getYMMedalMeta(year, month)
end

-- 获得今年所有的头像框和月度勋章奖励
function PromoteDailyModelLogic:getYearAllRewards(year)
    year = year or self._year
    local list = {}
    local isFirst = true
    for i = 1, 12, 1 do
        local monthCfg = self:hasMonthMedal(year, i)
        if monthCfg then
            local t = {
                year = year,
                month = i,
                medalId = monthCfg.medalId,
            }
            for _, v in ipairs(monthCfg.rewardItemList) do
                if _G.amfBean("PropManager"):isHeadFrame(v.itemId) then
                    t.headFrameId = v.itemId
                    break
                end
            end
            if t.headFrameId and HeadFrameType:isDefineHeadFrameId(_G.amfBean("PropManager"):getHeadFrameId(t.headFrameId)) then
                -- 是第一次有值，那么把之前的全删掉，因为23年是从4月开始的
                if isFirst then
                    isFirst = false
                    list = {}
                end
                table.insert(list, t)
            else
                -- 如果没有定义就插个空的
                table.insert(list, { year = year, month = i, isEmpty = true })
            end
        else
            -- 如果没有定义就插个空的
            table.insert(list, { year = year, month = i, isEmpty = true })
        end
    end
    return list
end

-- 获得可以领取的月度奖励dayNumlist
function PromoteDailyModelLogic:getCanRewardMonthDayList(containToday)
    local monthDayList = {}
    local tempYear, tempMonth = self._year, self._month
    if not containToday then
        tempYear, tempMonth = Utils:getLeftYM(tempYear, tempMonth)
    end
    while true do
        local monthData = self:getMonthDataByYM(tempYear, tempMonth)
        if not monthData then
            break
        end
        if self:canRewardMonthMedal(tempYear, tempMonth) then
            local n = Utils:getDayNumByYMD(tempYear, tempMonth, #monthData.dayMarkStatus)
            table.insert(monthDayList, n)
        end
        tempYear, tempMonth = Utils:getLeftYM(tempYear, tempMonth)
    end
    return deferred.success(monthDayList)
end

-- 获得可以领取的纪念勋章dayNumList
function PromoteDailyModelLogic:getCanRewardMedalDayList(containToday)
    local keyDayNumList = {}
    -- 纪念章
    -- 今天是第几天
    local dayNum = self:getTodayNum()
    if not containToday then
        dayNum = dayNum - 1
    end
    while true do
        local date = Utils:getYMDByDayCount(dayNum)
        local monthData = self:getMonthDataByYM(date.year, date.month)
        if not monthData then
            break
        end
        if self:canRewardKeyDayMedal(date.year, date.month, date.day) then
            table.insert(keyDayNumList, dayNum)
        end
        dayNum = dayNum - 1
    end
    return deferred.success(keyDayNumList)
end

-- 检查是否可以领取纪念日勋章
function PromoteDailyModelLogic:canRewardKeyDayMedal(year, month, day)
    local signState = self:getSignState(year, month, day)
    -- 不是正常签到不能领（重燃活动期间打关状态 5 与正常签到同权）
    if signState ~= PromoteDailyConst.SignState.SIGN
        and signState ~= PromoteDailyConst.SignState.REPAIR then
        return false
    end
    -- 判断是否有纪念日勋章
    local medalMeta = self:hasKeyDayMedal(year, month, day)
    if not medalMeta then
        return false
    end
    -- 判断是否已经获得了
    if self:hasRewardedKeyDayMedal(medalMeta.medalId) then
        return false
    end
    return true
end

-- 检查是否可以领取月度勋章
function PromoteDailyModelLogic:canRewardMonthMedal(year, month)
    local monthMedalCfg = self:hasMonthMedal(year, month)
    if not monthMedalCfg then return false end
    if self:hasRewardMonthMedal(monthMedalCfg.medalId) then
        return false
    end
    if not self:isFullSign(year, month) then
        return false
    end
    return true
end

-- 是否满签到了
function PromoteDailyModelLogic:isFullSign(year, month)
    local monthData = self:getMonthDataByYM(year, month)
    if monthData and monthData.dayMarkStatus then
        for _, v in ipairs(monthData.dayMarkStatus) do
            if v == PromoteDailyConst.SignState.NONE then
                return false
            end
        end
    end
    return true
end

-- 根据year获得最高记录数据
function PromoteDailyModelLogic:getMaxRecordDataByYear(year, key)
    year = year or self._year
    local tempData = nil
    for i = 1, 12, 1 do
        local monthData = self:getMonthDataByYM(year, i)
        if monthData and (self._year ~= year or (self._year == year and i <= self._month)) then
            if not tempData then
                tempData = monthData
            else
                if tempData[key] <= monthData[key] then
                    tempData = monthData
                end
            end
        end
    end
    return tempData
end

-- 获取记录by year，month
function PromoteDailyModelLogic:getRecordDataByYM(year, month)
    year = year or self._year
    month = month or self._month
    local monthData = self:getMonthDataByYM(year, month)
    if monthData and (self._year ~= year or (self._year == year and month <= self._month)) then
        return monthData
    end
    return {}
end

function PromoteDailyModelLogic:getProtectTipPanelParams()
    local installWidget
    local WidgetManager = _G.amfBean("DesktopWidgetManager")
    if WidgetManager and WidgetManager:isEnabled() then
        if WidgetManager:isWidgetInstall() then
            installWidget = true
        else
            installWidget = false
        end
    end
    local notice = nil
    if EnvUtil:isApp() or EnvUtil:isWindowsMockApp() then
        local LocalPushSDK = require "amf.middleware.notification.localpush.LocalPushSDK"
        notice = LocalPushSDK:hasOpenNotification()
    end
    return {
        EquipShield = self:getShieldNum() > 0,
        InstallComponent = installWidget,
        OpenNotice = notice,
    }
end

-- 获取7日任务进度
function PromoteDailyModelLogic:getTaskProgress()
    local taskData = self._promoteDailyMgr:getDataValue("diaryTaskData") or {}
    return taskData.finishProgress or 0
end

-- 获取7日任务奖励列表
function PromoteDailyModelLogic:getTaskRewardList()
    local taskData = self._promoteDailyMgr:getDataValue("diaryTaskData") or {}
    return taskData.sevenRewardPoolList or {}
end

-- 翻牌道具增减
function PromoteDailyModelLogic:addHandProp(num)
    local markPropsNum = self._promoteDailyMgr:getDataValue("markPropsNum") or 0
    markPropsNum = markPropsNum + num
    if markPropsNum < 0 then
        markPropsNum = 0
    end
    self._promoteDailyMgr:setDataValue("markPropsNum", markPropsNum)
end

-- 翻牌道具增减 购买的
function PromoteDailyModelLogic:addBuyHandProp(num)
    local buyMarkPropsNum = self._promoteDailyMgr:getDataValue("buyMarkPropsNum") or 0
    buyMarkPropsNum = buyMarkPropsNum + num
    if buyMarkPropsNum < 0 then
        buyMarkPropsNum = 0
    end
    self._promoteDailyMgr:setDataValue("buyMarkPropsNum", buyMarkPropsNum)
end

-- 引导
function PromoteDailyModelLogic:hasGuideIndex(index)
    local guideIdSet = self._promoteDailyMgr:getDataValue("guideIdSet") or {}
    return table.exist(guideIdSet, index)
end

function PromoteDailyModelLogic:addGuideIndex(index)
    if self:hasGuideIndex(index) then return end

    local guideIdSet = self._promoteDailyMgr:getDataValue("guideIdSet") or {}
    table.insert(guideIdSet, index)
    self._promoteDailyMgr:setDataValue("guideIdSet", guideIdSet)
    -- 引导标记
    local SetActGuidFlag = require "amf.middleware.activity.http.SetActGuidFlag"
    SetActGuidFlag:post({
        actId = PromoteDailyConst.ACT_ID,
        index = index
    })
end

-- 获得补签的goodsId
function PromoteDailyModelLogic:getMakeUpGoodsId(year, month)
    local makeUpCount = self:getMonthMakeUpCount(year, month)
    local markStepMetaList = self._promoteDailyMgr:getConfigValue("markStepMetaList") or {}
    local compCount = makeUpCount + 1
    for i, v in ipairs(markStepMetaList) do
        if compCount >= v.min and compCount <= v.max then
            return v.goodsId
        end
    end
    return nil
end

-- 获得当月补签次数  购买补签
function PromoteDailyModelLogic:getMonthMakeUpCount(year, month)
    local monthData = self:getMonthDataByYM(year, month)
    if not monthData then return 0 end
    local count = 0
    for i, v in ipairs(monthData.dayMarkStatus) do
        if v == PromoteDailyConst.SignState.MAKEUP_BUY then
            count = count + 1
        end
    end
    return count
end

-- 获得了累签到了多少天
function PromoteDailyModelLogic:getMonthSignCount(year,month)
	local monthData = self:getMonthDataByYM(year,month)
	if not monthData then return 0 end
	local count = 0
	for i,v in ipairs(monthData.dayMarkStatus) do
		if v ~= PromoteDailyConst.SignState.NONE then
			count = count + 1
		end
	end
	return count
end

function PromoteDailyModelLogic:getHandPropNum()
    return self._promoteDailyMgr:getDataValue("markPropsNum") or 0
end

function PromoteDailyModelLogic:getBuyHandPropNum()
    return self._promoteDailyMgr:getDataValue("buyMarkPropsNum") or 0
end

-- 是否有新纪录
function PromoteDailyModelLogic:getNewRecordState()
    local cacheRecord = self._promoteDailyMgr:getLocalValue("cacheRecords_" .. self:getYear() .. "_" .. self:getMonth()) or {
        maxTogetherWinNum = 0,
        maxTotalPassNum = 0,
        maxTotalStarNum = 0,
        maxTogetherWinNumTime = 0,
        maxTotalPassNumTime = 0,
        maxTotalStarNumTime = 0
    }
    -- 最高连胜记录
    local contiData = self:getMaxRecordDataByYear(nil, "maxTogetherWinNum")
    -- 最多过关记录
    local passLevelData = self:getMaxRecordDataByYear(nil, "maxTotalPassNum")
    -- 最多摘星记录
    local starData = self:getMaxRecordDataByYear(nil, "maxTotalStarNum")
    local curRecord = {
        maxTogetherWinNum = contiData.maxTogetherWinNum,
        maxTotalPassNum = passLevelData.maxTotalPassNum,
        maxTotalStarNum = starData.maxTotalStarNum,
        maxTogetherWinNumTime = contiData.maxTogetherWinNumTime,
        maxTotalPassNumTime = passLevelData.maxTotalPassNumTime,
        maxTotalStarNumTime = starData.maxTotalStarNumTime
    }
    if cacheRecord.maxTogetherWinNum < curRecord.maxTogetherWinNum or
        cacheRecord.maxTotalPassNum < curRecord.maxTotalPassNum or
        cacheRecord.maxTotalStarNum < curRecord.maxTotalStarNum
    then
        return true
    end
    return false
end

function PromoteDailyModelLogic:isTargetTaskCanReward(index)
    local data = self:getTargetTaskData(index)
    if not data then return false end

    local curProgress = self._promoteDailyMgr:getTargetValue("nowProgress")
    if curProgress >= data.target and not data.reward then
        return true
    end
    return false
end

-- 获取选择目标任务数据
function PromoteDailyModelLogic:getTargetTaskData(index)
    local chooseData = self._promoteDailyMgr:getDataValue("chooseProgressTaskData") or {}
    local taskList = chooseData.perTaskDataList or {}
    return taskList[index]
end

-- 获取当前的所有任务
function PromoteDailyModelLogic:getTargetTaskDataAll()
    if not self._promoteDailyMgr:getDataValue("chooseTaskOK") then
        return {
            {
                target = 7,
                taskType = 1
            }
        }
    end
    local chooseData = self._promoteDailyMgr:getDataValue("chooseProgressTaskData") or {}
    local chooseIndex = chooseData.chooseIndex or 1
    local selectOpIndex = chooseData.selectOpIndex or 0
    local taskList = chooseData.perTaskDataList or {}
    local ret = {}

    if selectOpIndex >= chooseIndex then
        for i = 1, selectOpIndex do
            table.insert(ret, taskList[i])
        end
    else
        ret = {
            taskList[chooseIndex]
        }
    end
    return ret
end

-- 是否是里程目标
function PromoteDailyModelLogic:isMileTask(target)
    if not target or not self._promoteDailyMgr:getDataValue("chooseTaskOK") then return false end
    local chooseData = self._promoteDailyMgr:getDataValue("chooseProgressTaskData") or {}
    if chooseData.selectOpIndex and chooseData.selectOpIndex > chooseData.chooseIndex then
        for i = 1, chooseData.selectOpIndex - 1 do
            if target == chooseData.perTaskDataList[i].target then
                return true
            end
        end
    end
    return false
end

-- 获得盾牌使用记录
-- isUse: true:使用 false:获得的
function PromoteDailyModelLogic:getShieldRecordList(isUse)
    local list = self._promoteDailyMgr:getDataValue("shieldRecordList") or {}
    local ret = {}
    if not isUse then
        for i, v in ipairs(list) do
            if v.buy == false and not v.show and not v.use then
                table.insert(ret, v)
            end
        end
        table.sort(ret, function(a, b)
            return a.showTime < b.showTime
        end)
    else
        for i, v in ipairs(list) do
            if v.use then
                table.insert(ret, v)
            end
        end
        table.sort(ret, function(a, b)
            return a.showTime > b.showTime
        end)
        ret = table.headn(ret, 2)
    end
    return ret
end

function PromoteDailyModelLogic:setShiledRecordListShowed()
    local list = self._promoteDailyMgr:getDataValue("shieldRecordList") or {}
    for i, v in ipairs(list) do
        v.show = true
    end
    self._promoteDailyMgr:setDataValue("shieldRecordList", list)
end

function PromoteDailyModelLogic:getYear()
    return self._year
end

function PromoteDailyModelLogic:getMonth()
    return self._month
end

function PromoteDailyModelLogic:getDay()
    return self._day
end

function PromoteDailyModelLogic:getTodayNum()
    return self._todayNum
end

function PromoteDailyModelLogic:getShieldNum()
    return self._promoteDailyMgr:getDataValue("shieldNum") or 0
end

function PromoteDailyModelLogic:addShieldNum(num)
    local shiledNum = self:getShieldNum()
    local ret = shiledNum + num
    ret = ret < 0 and 0 or ret
    self._promoteDailyMgr:setDataValue("shieldNum", ret)
end

-- 获得帮助数据
function PromoteDailyModelLogic:isCanGetBeHelpedReward()
    local helpData = self._promoteDailyMgr:getDataValue("helpData") or {}
    local list = helpData.beHelpRecordList or {}
    local count = 0
    for i, v in ipairs(list) do
        if v.rewardMonth == 0 then
            count = count + 1
        end
    end
    return count >= PromoteDailyConst.BeHelpCanRewardCount
end

-- 奖字
function PromoteDailyModelLogic:hasRewards()
    if self:getTaskCanReward() then return true end
    if self:checkCanPopGetRewards(true) then return true end
    local shieldFreeList = self:getShieldRecordList(false)
    if #shieldFreeList > 0 then return true end
    if self:isCanGetBeHelpedReward() then return true end
    if self:hasTargetTaskCanReward() then return true end
    return false
end

function PromoteDailyModelLogic:hasTargetTaskCanReward()
    local list = self:getAllTargetCanRewardList()
    return #list > 0
end

-- 获得所有可领取的任务index
function PromoteDailyModelLogic:getAllTargetCanRewardList()
    local chooseData = self._promoteDailyMgr:getDataValue("chooseProgressTaskData") or {}
    local curProgress = self._promoteDailyMgr:getTargetValue("nowProgress") or 0
    local taskList = chooseData.perTaskDataList or {}
    local list = {}
    for i, v in ipairs(taskList) do
        if curProgress >= v.target and not v.reward then
            table.insert(list, i)
        end
    end
    return list
end

-- 今天的签到类型
function PromoteDailyModelLogic:getTodaySignState()
    return self:getSignState(self:getYear(), self:getMonth(), self:getDay())
end

-- 获得是否是当前的目标
function PromoteDailyModelLogic:isCurTarget(year, month, day)
    if not self._promoteDailyMgr:getDataValue("chooseTaskOK") then return false end
    local dayNum = Utils:getDayNumByYMD(year, month, day)
    local curProgress = self._promoteDailyMgr:getTargetValue("nowProgress")
    local todaySigned = self:getTodaySignState() ~= PromoteDailyConst.SignState.NONE
    local todayNum = self:getTodayNum()
    local chooseData = self._promoteDailyMgr:getDataValue("chooseProgressTaskData") or {}
    local taskList = chooseData.perTaskDataList or {}
    local curTarget = nil
    for i, v in ipairs(taskList) do
        if v.target > curProgress then
            curTarget = v.target
            break
        end
    end
    if curTarget then
        local targetDayNum = todayNum + curTarget - curProgress
        if not todaySigned then
            -- 没签到就减去一天
            targetDayNum = targetDayNum - 1
        end
        return targetDayNum == dayNum
    end
    return false
end

function PromoteDailyModelLogic:getCurTaskTargetData()
    local curProgress = self._promoteDailyMgr:getTargetValue("nowProgress")
    local chooseData = self._promoteDailyMgr:getDataValue("chooseProgressTaskData") or {}
    local taskList = chooseData.perTaskDataList or {}
    local curTargetData = nil
    local idx = 1
    for i, v in ipairs(taskList) do
        if v.target > curProgress then
            curTargetData = table.simpleClone(v)
            idx = i
            break
        end
    end
    if curTargetData then
        return curTargetData, idx
    end
    return taskList[#taskList], #taskList
end

function PromoteDailyModelLogic:getLastTaskTargetData()
    local curTagetData, idx = self:getCurTaskTargetData()
    local chooseData = self._promoteDailyMgr:getDataValue("chooseProgressTaskData") or {}
    local taskList = chooseData.perTaskDataList or {}
    if not taskList[idx-1] then
        return {
            target = chooseData.lastProgress or 0
        }
    end
    return taskList[idx - 1]
end

function PromoteDailyModelLogic:getNextTaskByTask(taskInfo)
    local target = taskInfo.target
    local taskType = taskInfo.taskType

    if target == 7 then
        return {
            target = 14,
            taskType = 1,
        }
    end

    local nextTarget = target + 10
    local nextType = taskType + 1
    nextType = nextType == 4 and 1 or nextType
    if target >= 65 then
        nextTarget =  target + (taskType == 2 and 20 or 15)
    elseif target <= 14 then nextTarget = 21
    elseif target == 21 then nextTarget = 25
    end

    return {
        target = nextTarget,
        taskType = nextType
    }
end

function PromoteDailyModelLogic:getPreTaskByTask(taskInfo)
    local target = taskInfo.target
    local taskType = taskInfo.taskType

    if target == 7 then
        return {
            target = 0,
            taskType = 1,
        }
    end

    local preTarget = target - 10
    local preType = taskType - 1
    preType = preType == 0 and 3 or preType
    if target >= 80 then
        preTarget =  target - (taskType == 3 and 20 or 15)
    elseif target <= 14 then
        preTarget = 7
        preType = 1
    elseif target == 21 then preTarget = 14
    elseif target == 25 then preTarget = 21
    end
    return {
        target = preTarget,
        taskType = preType
    }
end

function PromoteDailyModelLogic:calculateMaxContiNum()
    local count = 0
    -- 今天是第几天
    local dayNum = self.continousPassBeginNum - 1
    local maxCount = 0
    local minDayNum = Utils:getDayNumByYMD(2023, 4, 1)
    while true do
        if dayNum < minDayNum then break end

        local date = Utils:getYMDByDayCount(dayNum)
        local signState = self:getSignState(date.year, date.month, date.day)
        -- 次数>0说明是有passCount的，可以算连过天数
        if PromoteDailyConst.isContinousState(signState) then
            count = count + 1
            dayNum = dayNum - 1
        else
            dayNum = dayNum - 1
            maxCount = math.max(maxCount, count)
            count = 0
        end
    end
    self.maxContinouseCount = maxCount
end

function PromoteDailyModelLogic:getLastContiMaxCount()
    return self.maxContinouseCount or 0
end

return PromoteDailyModelLogic
