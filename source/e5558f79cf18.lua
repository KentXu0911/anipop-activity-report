local BaseFeatureModel = require "amf.middleware.activity.base.BaseFeatureModel"
local Config = require "amf.feature.localactivity.pengpeng2026.config.PengPeng2026Config"

local Model = class("PengPeng2026Model", BaseFeatureModel)

-- 安装本地存储插件；当前只保存后端透传的活动基础数据。
function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "PengPeng2026Model"
    }):as("db")
end

-- 返回活动常量路径，供 BaseFeatureModel 解析数据根节点。
function Model:_getConstPath()
    return "amf.feature.localactivity.pengpeng2026.config.PengPeng2026Config"
end

-- 声明活动框架基础数据；后端业务字段未定前只保留分组容器，不提前拆字段。
function Model:__declare()
    self:_initServerData()
    self:_initConfigData()
    self:_initLocalData()
end

-- 后端返回字段：活动时间和 userData 先按活动框架原始结构保存。
function Model:_initServerData()
    self.updateDataTime = nil
    self.userData = nil
    self.beginTime = nil
    self.endTime = nil
    self.mainBeginTime = nil
    self.mainEndTime = nil
end

-- 配置字段：保存 mainInfo 下发并反序列化后的 localConfig。
function Model:_initConfigData()
    self.localConfig = nil
end

-- 本地字段：后续只放纯本地展示/缓存 key，不放后端权威业务数据。
function Model:_initLocalData()
    self.canyuHadDC = nil
    self.joinHadDC = nil
    self.lastViewedProgressScore = nil
    self.attractPanelDailyShown = nil
    self.attractPanelSuppressCount = nil
end


-- 跨天清理入口；具体本地日维度字段确定后在这里清。
function Model:passDayClear()
end

-- 清空后端返回和配置缓存；活动下线或服务端返回空数据时使用。
function Model:clearLocalData()
    self:setValue("updateDataTime", nil)
    self:setValue("userData", nil)
    self:setValue("beginTime", nil)
    self:setValue("endTime", nil)
    self:setValue("mainBeginTime", nil)
    self:setValue("mainEndTime", nil)

    self:setValue("localConfig", nil)
end

-- 本地数据变更后的收口；用于记录更新时间，并触发跨天清理。
function Model:fromLocalChangeEnd()
    local bPassDay = false
    local curTime = TimeKit:timeInSec()
    if self.updateDataTime then
        if getDayStartTimeByTS(curTime) ~= getDayStartTimeByTS(self.updateDataTime) then  
            bPassDay = true
        end
        self:setValue("updateDataTime", curTime)
    else
        self:setValue("updateDataTime", curTime)
    end

    if bPassDay then  
        self:passDayClear()
    end
end

-- 合并服务端活动数据和配置；data.userData 使用后端 ColorfulBump2026UserBean 结构。
function Model:fromServer(data, config)
    -- data 是后端返回活动数据，config.config 是后端下发配置字符串。
    if table.isEmpty(data) then
        self:clearLocalData()
    else
        for k, v in pairs(data) do
            self:setValue(k, v)
        end
    end

    if config and not table.isEmpty(config) and config.config ~= '' then
        if type(config.config) == "string" then
            config.config = table.deserialize(config.config)
        end
        self:setValue("localConfig", config)
    end
    
    self:flush()
end

-- 获取反序列化后的活动配置；调用方不直接读 localConfig 外层结构。
function Model:getConfig()
    local localConfig = self:getValue("localConfig")
    if localConfig and localConfig.config then
        return localConfig.config
    end

    return {}
end

-- 从后端 userData 或 Model 顶层读取字段；后端字段名确定前只做通用读取。
function Model:getDataByKey(key, default)
    local value = self:getValue(key)
    if value ~= nil then
        return value
    end

    local userData = self:getValue("userData")
    if userData and userData[key] ~= nil then
        return userData[key]
    end

    return default
end

-- 写回已存在的后端 userData 字段；避免随意新增未知后端字段。
function Model:setDataByKey(key, value, needSave)
    local userData = self:getValue("userData")

    if userData and userData[key] ~= nil then
        userData[key] = value
        self:setValue("userData", userData, needSave)
    end
end

-- 写回 userData 字段，允许新增本地已确认需要回写的字段。
function Model:setDataByKeyIgnoreNil(key, value, needSave)
    local userData = self:getValue("userData")

    if userData then
        userData[key] = value
        self:setValue("userData", userData, needSave)
    end
end

-- 对 userData 中的数字字段做累加；仅用于已确认是数字资产或进度的字段。
function Model:addDataByKey(key, value)
    local userData = self:getValue("userData")
    if userData and type(userData[key]) == 'number' then
        userData[key] = userData[key] + value
        self:setValue("userData", userData, true)
    end
end

-- 写入 Model 顶层扩展字段；仅用于明确属于本地缓存的字段。
function Model:setExDataByKey(key, value, needSave)
    self:setValue(key, value, needSave)
end

-- 按 key 获取活动配置项。
function Model:getConfigByKey(key)
    local config = self:getConfig()
    if config and config[key] then
        return config[key]
    end
end


function Model:getGuides()
    -- 引导标记
    return self:getDataByKey('guideIdSet') or {}
end

function Model:addGuides(index)
    -- 添加引导标记

    local guideInfo = self:getDataByKey('guideIdSet')
    table.insert(guideInfo, index)
    self:setDataByKey('guideIdSet', guideInfo, true)

    self:flush()
end

function Model:checkGuide(index)
    -- 检查引导标记
    local guideInfo = self:getDataByKey('guideIdSet') or {}

    return table.exist(guideInfo, index)
end

function Model:setGuideIndex(index)
    self:addGuides(index)

    local ActCommonHttp = require("amf.middleware.activity.http.ActCommonHttp")
    ActCommonHttp:setActGuideFlag(_G.amfBean("PengPeng2026Manager"):getConst().actId, index)
end

------------------

-- 当前玩法版本配置，直接来自后端 versionMetas。
function Model:getCurrentVersionMeta()
    local config = self:getConfig()
    local targetVersion = tonumber(self:getConfigVersion())
    for _, versionMeta in ipairs(config.versionMetas or {}) do
        if tonumber(versionMeta.configVersion) == targetVersion then
            return versionMeta
        end
    end
    return {}
end

-- 获取当前版本的全部棋子配置，字段保持后端 PieceMeta 原始结构。
function Model:getPieceMetas()
    return table.clone((self:getCurrentVersionMeta() or {}).pieceMetas or {})
end

-- 按等级查找后端 PieceMeta；找不到返回空表，让调用方按配置缺失处理。
function Model:getPieceMeta(level)
    level = tonumber(level)
    for _, pieceMeta in ipairs(self:getPieceMetas() or {}) do
        if tonumber(pieceMeta.level) == level then
            return table.clone(pieceMeta)
        end
    end
    return {}
end

-- 获取当前版本的订单池配置，字段保持后端 OrderPoolMeta 原始结构。
function Model:getOrderPoolMetas()
    return table.clone((self:getCurrentVersionMeta() or {}).orderPoolMetas or {})
end

-- 清屏雨触发阈值来自后端 boardPieceMinCount；投放数量从后端 bonusCupCountRange 内随机。
function Model:getClearRainConfig()
    local config = self:getConfig()
    local versionMeta = self:getCurrentVersionMeta() or {}
    local minCount = tonumber(versionMeta.boardPieceMinCount) or 0
    local bonusCupCountRange = versionMeta.bonusCupCountRange or config.bonusCupCountRange
    local cupCount = self:_getRandomClearRainCupCount(bonusCupCountRange)
    local enabled = minCount > 0 and cupCount > 0
    if self.printLog then
        self:printLog("BONUS", true, "clear rain config", {
            enabled = enabled,
            boardPieceMinCount = versionMeta.boardPieceMinCount,
            versionBonusCupCountRange = versionMeta.bonusCupCountRange,
            rootBonusCupCountRange = config.bonusCupCountRange,
            bonusCupCountRange = bonusCupCountRange,
            triggerCupCount = minCount,
            cupCount = cupCount,
        })
    end
    return {
        enabled = enabled,
        triggerCupCount = minCount,
        cupCount = cupCount,
        bonusCupCountRange = bonusCupCountRange,
    }
end

-- 按后端 bonusCupCountRange 生成本次清屏雨投放数量；配置缺失或非法时不投放。
function Model:_getRandomClearRainCupCount(countRange)
    if type(countRange) ~= "table" then return 0 end

    local minCount = tonumber(countRange[1])
    local maxCount = tonumber(countRange[2])
    if not minCount or not maxCount then return 0 end

    minCount = math.floor(minCount)
    maxCount = math.floor(maxCount)
    if minCount > maxCount then
        minCount, maxCount = maxCount, minCount
    end
    if maxCount <= 0 then return 0 end
    minCount = math.max(minCount, 0)

    return math.random(minCount, maxCount)
end

-- 满额自动磁铁阈值来自后端 boardPieceMaxCount，达到后以 magnet(reason=full) 执行且不扣能量。
function Model:getFullMagnetConfig()
    local versionMeta = self:getCurrentVersionMeta() or {}
    local maxCount = tonumber(versionMeta.boardPieceMaxCount) or 0
    return {
        enabled = maxCount > 0,
        triggerCupCount = maxCount,
    }
end

--------------------------------------------
-----------下面是数据处理-------------
--------------------------------------------

-- 当前活动期 ID，来自后端 ColorfulBump2026UserBean.periodId，用于区分周期数据。
function Model:getPeriodId()
    return self:getDataByKey("periodId", 0)
end

-- 当前配置版本号，来自后端 ColorfulBump2026UserBean.configVersion，用于判断配置和用户数据是否同源。
function Model:getConfigVersion()
    return self:getDataByKey("configVersion", 0)
end

-- 是否处于正式游玩阶段；活动阶段以活动时间窗口为准，不依赖后端透传的固定字段。
function Model:isMainPhase()
    return self:isInMainTime()
end

-- 是否处于领奖阶段；活动阶段以活动时间窗口为准，不依赖后端透传的固定字段。
function Model:isRewardPhase()
    return self:isInRewardTime()
end

-- 当前可发射次数，来自后端 userData；发射、道具发放和协议回包成功后更新。
function Model:getLaunchOpportunity()
    return self:getDataByKey("launchOpportunity", 0)
end

-- 写回可发射次数；只通过 setDataByKey 修改后端字段，避免绕开 Model 的存储收口。
function Model:setLaunchOpportunity(value, needSave)
    self:setDataByKey("launchOpportunity", tonumber(value) or 0, needSave)
end

-- 累加可发射次数；用于服务端成功回包或本地已确认的同步结果回写。
function Model:addLaunchOpportunity(delta)
    self:addDataByKey("launchOpportunity", tonumber(delta) or 0)
end

-- 当前能量值，来自后端 userData；磁铁次数会优先按能量消耗配置实时换算。
function Model:getEnergy()
    return self:getDataByKey("energy", 0)
end

-- 写回能量值；协议成功后刷新本地后端字段。
function Model:setEnergy(value, needSave)
    self:setDataByKey("energy", tonumber(value) or 0, needSave)
end

-- 累加能量值；用于合成、积分兑换等已确认结果。
function Model:addEnergy(delta)
    self:addDataByKey("energy", tonumber(delta) or 0)
end

-- 当前 period 初始能量是否已领取；由 mainInfo.userBean.initialEnergyRewardClaimed 下发。
function Model:isInitialEnergyRewardClaimed()
    return self:getDataByKey("initialEnergyRewardClaimed", false) == true
end

-- 写回当前 period 初始能量领取标记；领取协议成功后本地立即同步，避免重复请求。
function Model:setInitialEnergyRewardClaimed(claimed, needSave)
    self:setDataByKeyIgnoreNil("initialEnergyRewardClaimed", claimed == true, needSave)
end

-- 每次磁铁消耗的能量，来自配置 energy.energyCost。
function Model:getEnergyCost()
    local energyMeta = (self:getCurrentVersionMeta() or {}).energyMeta or {}
    return tonumber(energyMeta.energyCost) or 0
end

-- 根据后端 comboEnergyMetas 区间配置计算当前连击应获得的能量。
function Model:getEnergyByCombo(comboCount)
    comboCount = tonumber(comboCount) or 0
    for _, meta in ipairs((self:getCurrentVersionMeta() or {}).comboEnergyMetas or {}) do
        local minCombo = tonumber(meta.minComboInclusive) or 0
        local maxCombo = tonumber(meta.maxComboInclusive) or -1
        if comboCount >= minCombo and (maxCombo < 0 or comboCount <= maxCombo) then
            return tonumber(meta.energy) or 0
        end
    end
    return 0
end

-- 当前可用磁铁次数；优先由能量和配置实时计算，配置缺失时回退后端字段。
function Model:getMagnetUsableCount()
    local energyCost = self:getEnergyCost()
    if energyCost > 0 then
        return math.floor(self:getEnergy() / energyCost)
    end
    return self:getDataByKey("magnetUsableCount", 0)
end

-- 当前积分，来自后端 userData；进度奖励和订单完成都以该值为准。
function Model:getScore()
    return self:getDataByKey("score", 0)
end

-- 写回积分；协议成功后刷新本地后端字段。
function Model:setScore(value, needSave)
    self:setDataByKey("score", tonumber(value) or 0, needSave)
end

-- 累加积分；用于本地操作同步成功后的权威结果落地。
function Model:addScore(delta)
    self:setScore((tonumber(self:getScore()) or 0) + (tonumber(delta) or 0), true)
end

-- 当前订单队列，来自后端 userData；返回 clone，避免调用方直接改 Model 内部表。
function Model:getOrderQueue()
    return table.clone(self:getDataByKey("orderQueue", {}) or {})
end

-- 写回订单队列；只在后端回包或同步成功确认新队列后调用。
function Model:setOrderQueue(orderQueue, needSave)
    self:setDataByKey("orderQueue", table.clone(orderQueue or {}), needSave)
end

-- 当前订单目标等级，取订单队列首位。
function Model:getCurrentOrderLevel()
    local orderQueue = self:getOrderQueue()
    return self:getOrderEntryLevel(orderQueue[1])
end

-- 下一个订单目标等级，给 UI 预览和补队列逻辑使用。
function Model:getNextOrderLevel()
    local orderQueue = self:getOrderQueue()
    return self:getOrderEntryLevel(orderQueue[2])
end

-- 兼容旧的纯等级订单队列和新后端 OrderEntryBean。
function Model:getOrderEntryLevel(entry)
    if type(entry) == "table" then
        return tonumber(entry.level)
    end
    return tonumber(entry)
end

-- 当前棋盘快照，来自后端 userData.boardSnapshot；返回 clone，避免外部直接修改缓存。
function Model:getBoardSnapshot()
    return table.clone(self:getDataByKey("boardSnapshot", {}) or {})
end

-- 写回棋盘快照；用于同步协议成功后保存服务端认可的棋盘状态。
function Model:setBoardSnapshot(snapshot, needSave)
    self:setDataByKey("boardSnapshot", table.clone(snapshot or {}), needSave)
end

-- 当前待发射棋子，来自后端 boardSnapshot.nextCup；面板初始化必须读取该值，不本地重抽。
function Model:getNextCup()
    local snapshot = self:getBoardSnapshot()
    return table.clone(snapshot.nextCup or {})
end

-- 写回 boardSnapshot.nextCup；真实发射成功后生成的新 nextCup 要和 shoot op 及断面一致。
function Model:setNextCup(nextCup, needSave)
    local snapshot = self:getBoardSnapshot()
    snapshot.nextCup = table.clone(nextCup or {})
    self:setBoardSnapshot(snapshot, needSave)
end

-- 最近一次服务端确认的操作序号，来自后端 userData.lastSeq。
function Model:getLastSeq()
    return self:getDataByKey("lastSeq", 0)
end

-- 写回最近确认序号；操作队列同步成功后用于续传和去重。
function Model:setLastSeq(lastSeq, needSave)
    self:setDataByKey("lastSeq", tonumber(lastSeq) or 0, needSave)
end

-- 服务端记录的最大棋子 ID；所有新增棋子都必须从 maxCupId + 1 继续。
function Model:getMaxCupId()
    return self:getDataByKey("maxCupId")
end

-- 写回最大棋子 ID；Runtime 每新增一颗棋子后推进。
function Model:setMaxCupId(maxCupId, needSave)
    self:setDataByKey("maxCupId", tonumber(maxCupId) or 0, needSave)
end

-- 已领取普通进度奖励节点 ID 列表；后端只返回 lastClaimedRewardIndex，这里为现有 UI 派生展示口径。
function Model:getNormalRewardClaimedIds()
    local lastClaimedIndex = tonumber(self:getDataByKey("lastClaimedRewardIndex", 0)) or 0
    local ids = {}
    local normalProgress = self:getNormalProgressConfig() or {}
    for index, nodeCfg in ipairs(normalProgress) do
        local rewardIndex = tonumber(nodeCfg.nodeId) or tonumber(nodeCfg.incrementScore) or 0
        if rewardIndex > 0 and index <= lastClaimedIndex then
            ids[#ids + 1] = rewardIndex
        end
    end
    return ids
end

-- 已领取无尽进度奖励索引列表；后端只返回 lastClaimedRewardIndex，这里为现有 UI 派生展示口径。
function Model:getEndlessRewardClaimedIndexes()
    local lastClaimedIndex = tonumber(self:getDataByKey("lastClaimedRewardIndex", 0)) or 0
    local endlessClaimedCount = lastClaimedIndex - #(self:getNormalProgressConfig() or {})
    local indexes = {}
    for index = 1, math.max(endlessClaimedCount, 0) do
        indexes[#indexes + 1] = index
    end
    return indexes
end

-- 20% 加分 buff 到期时间，来自后端 userData；后端按字符串毫秒时间戳下发，Model 保持原值。
function Model:getScoreBuff20EndTime()
    return self:getDataByKey("scoreBuff20EndTime", "0")
end

-- 叠加 20% 加分 buff 时长；customGain 的 reward.num 语义为分钟，内部换算成毫秒结束时间。
function Model:addScoreBuff20Time(minutes)
    self:setDataByKey("scoreBuff20EndTime", self:_calcAddedBuffEndTime(self:getScoreBuff20EndTime(), minutes), true)
end

-- 双倍收集物 buff 到期时间，来自后端 userData；后端按字符串毫秒时间戳下发，Model 保持原值。
function Model:getDoubleCollectBuffEndTime()
    return self:getDataByKey("doubleCollectBuffEndTime", "0")
end

-- 叠加双倍收集物 buff 时长；customGain 的 reward.num 语义为分钟，内部换算成毫秒结束时间。
function Model:addDoubleCollectBuffTime(minutes)
    self:setDataByKey("doubleCollectBuffEndTime", self:_calcAddedBuffEndTime(self:getDoubleCollectBuffEndTime(), minutes), true)
end

-- 按当前过期时间叠加 buff 时长；未生效则从当前时间重新计算，保存形态保持后端字符串毫秒时间戳。
function Model:_calcAddedBuffEndTime(currentEndTime, minutes)
    local now = TimeKit:timeInMillis()
    local endTime = tonumber(currentEndTime) or 0
    local addMillis = (tonumber(minutes) or 0) * 60 * 1000
    if now < endTime then
        return tostring(endTime + addMillis)
    end
    return tostring(now + addMillis)
end

-- 判断当前是否有 20% 加分 buff；比较时局部转数字，不改变后端字符串字段形态。
function Model:hasScoreBuff20(now)
    now = now or TimeKit:timeInMillis()
    return (tonumber(self:getScoreBuff20EndTime()) or 0) > now
end

-- 判断当前是否有双倍收集物 buff；比较时局部转数字，不改变后端字符串字段形态。
function Model:hasDoubleCollectBuff(now)
    now = now or TimeKit:timeInMillis()
    return (tonumber(self:getDoubleCollectBuffEndTime()) or 0) > now
end

-- 是否存在可领取进度奖励，来自后端聚合标记；红点和领奖入口使用。
function Model:hasClaimableReward()
    return self:getDataByKey("hasClaimableReward", false) == true
end

-- 写回可领奖标记；领奖协议成功或服务端同步刷新后调用。
function Model:setHasClaimableReward(value, needSave)
    self:setDataByKey("hasClaimableReward", value == true, needSave)
end

-- 当前是否有可领取进度奖励；优先尊重后端聚合标记，缺失或未刷新时按本地分数与配置兜底计算。
function Model:hasProgressRewardToClaim()
    if self:hasClaimableReward() then
        return true
    end
    return self:_hasNormalProgressRewardToClaim() or self:_hasEndlessProgressRewardToClaim()
end

-- 普通进度奖励按累计阈值和全局已领游标判断。
function Model:_hasNormalProgressRewardToClaim()
    local score = tonumber(self:getScore()) or 0
    local lastClaimedIndex = tonumber(self:getDataByKey("lastClaimedRewardIndex", 0)) or 0
    for index, nodeCfg in ipairs(self:getNormalProgressConfig() or {}) do
        if index > lastClaimedIndex and score >= (tonumber(nodeCfg.incrementScore) or 0) then
            return true
        end
    end
    return false
end

-- 无尽进度奖励按普通进度结束后的循环节点数判断。
function Model:_hasEndlessProgressRewardToClaim()
    local normalCount = #(self:getNormalProgressConfig() or {})
    local claimedEndlessCount = math.max(0, (tonumber(self:getDataByKey("lastClaimedRewardIndex", 0)) or 0) - normalCount)
    local completedEndlessCount = self:_getCompletedEndlessRewardCount()
    return completedEndlessCount > claimedEndlessCount
end

-- 根据当前总分计算已达成的无尽奖励节点数量。
function Model:_getCompletedEndlessRewardCount()
    local normalEndScore = self:_getNormalProgressEndScore()
    local remainScore = (tonumber(self:getScore()) or 0) - normalEndScore
    if remainScore <= 0 then return 0 end

    local endlessList = self:getEndlessProgressConfig() or {}
    if table.isEmpty(endlessList) then return 0 end

    local count = 0
    while remainScore > 0 do
        local progressed = false
        for _, nodeCfg in ipairs(endlessList) do
            local needScore = tonumber(nodeCfg.incrementScore) or 0
            if needScore > 0 then
                if remainScore >= needScore then
                    count = count + 1
                    remainScore = remainScore - needScore
                    progressed = true
                else
                    return count
                end
            end
        end
        if not progressed then return count end
    end
    return count
end

-- 普通进度的最终累计分数，用于无尽奖励起点换算。
function Model:_getNormalProgressEndScore()
    local score = 0
    for _, nodeCfg in ipairs(self:getNormalProgressConfig() or {}) do
        score = math.max(score, tonumber(nodeCfg.incrementScore) or 0)
    end
    return score
end

-- 获取杯子等级配置，直接来自后端 pieceMetas。
function Model:getCupLevelConfig(level)
    return self:getPieceMeta(level)
end

-- 获取指定杯子等级订单积分，来自后端 PieceMeta.orderScore。
function Model:getScoreByLevel(level)
    return tonumber(self:getPieceMeta(level).orderScore) or 0
end

-- 获取普通进度奖励配置；requiredScore 是后端增量，这里只为现有进度 UI 计算累计展示坐标。
function Model:getNormalProgressConfig()
    local ret = {}
    local accumulatedScore = 0
    for _, rewardMeta in ipairs((self:getCurrentVersionMeta() or {}).progressRewardMetas or {}) do
        accumulatedScore = accumulatedScore + (tonumber(rewardMeta.requiredScore) or 0)
        ret[#ret + 1] = {
            nodeId = tonumber(rewardMeta.rewardId) or #ret + 1,
            incrementScore = accumulatedScore,
            rewardList = table.clone(rewardMeta.rewardItems or {}),
        }
    end
    return ret
end

-- 获取无尽进度奖励配置；无尽节点保持后端 requiredScore 的单段增量。
function Model:getEndlessProgressConfig()
    local ret = {}
    for _, rewardMeta in ipairs((self:getCurrentVersionMeta() or {}).endlessRewardMetas or {}) do
        ret[#ret + 1] = {
            cycleId = tonumber(rewardMeta.rewardId) or #ret + 1,
            incrementScore = tonumber(rewardMeta.requiredScore) or 0,
            rewardList = table.clone(rewardMeta.rewardItems or {}),
        }
    end
    return ret
end

-- 获取同步配置段，包含批量上限和高等级即时同步阈值。
function Model:getSyncConfig()
    return {
        maxBatchCount = tonumber(Config.Sync and Config.Sync.maxBatchCount) or 10,
        highLevelSyncThreshold = tonumber((self:getCurrentVersionMeta() or {}).highLevelSyncThreshold) or 0,
    }
end

-- 获取高等级杯子即时同步阈值；达到该等级的关键操作需要更及时同步。
function Model:getHighLevelSyncThreshold()
    local syncConfig = self:getSyncConfig()
    return tonumber(syncConfig.highLevelSyncThreshold) or 0
end

return Model
