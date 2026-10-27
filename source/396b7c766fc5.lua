local BaseFeatureModel = require "amf.middleware.activity.base.BaseFeatureModel"
local Model = class("ExploreMapGameModel", BaseFeatureModel)

local function _trace(...)
    -- if printx then
    --     printx(22, "[ExploreMapNpcTrace][UnityModel]", ...)
    -- else
    --     print("[ExploreMapNpcTrace][UnityModel]", ...)
    -- end
end

local function _contains(list, value)
    if type(list) ~= "table" then return false end
    for _, v in ipairs(list) do
        if v == value then return true end
    end
    return false
end

local function _isDoneValue(done)
    return done == true or done == 1 or done == "1" or done == "true"
end

local function _getDayKey(ts)
    return time2day(ts or TimeKit:timeInSec())
end

local function _toSec(ts)
    return math.floor((tonumber(ts) or 0) / 1000)
end

local ENERGY_GIFT_SHOW_DAY_KEY = "exploremap_energy_gift_show_day"
local ENERGY_GIFT_SHOW_COUNT_KEY = "exploremap_energy_gift_show_count"

local function _normalizeTaskDataMap(userBean, localConfig)
    userBean = userBean or {}
    if userBean.taskDataMap ~= nil then return userBean.taskDataMap end
    local progressMap = userBean.exploreTaskProgressMap or {}
    local claimedIds = userBean.claimedExploreTaskIds or {}
    local taskMetas = (localConfig and localConfig.exploreTaskMetas) or {}
    local out = {}

    for _, meta in ipairs(taskMetas) do
        if meta and meta.id ~= nil then
            local taskId = meta.id
            local current = progressMap[taskId] or progressMap[tostring(taskId)] or 0
            out[taskId] = {
                current = current,
                collections = {},
                finished = current >= (meta.targetCount or 1),
                claimed = _contains(claimedIds, taskId),
            }
        end
    end

    for taskId, current in pairs(progressMap) do
        local k = tonumber(taskId) or taskId
        if out[k] == nil then
            out[k] = {
                current = current or 0,
                collections = {},
                finished = false,
                claimed = _contains(claimedIds, k),
            }
        end
    end

    return out
end

function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "ExploreMapGameModel"
    }):as("db")
    self:installPlug(AMFDataPlugsType.SYNC, {
        requests = {
            mainInfo                  = "amf.feature.localactivity.exploremapgame.http.RequestMistyClearMapMainInfo",
            operateNode               = "amf.feature.localactivity.exploremapgame.http.RequestMistyClearMapOperateNode",
            claimExploreTaskReward    = "amf.feature.localactivity.exploremapgame.http.RequestMistyClearMapClaimExploreTaskReward",
            claimAllExploreTaskReward = "amf.feature.localactivity.exploremapgame.http.RequestMistyClearMapClaimAllExploreTaskReward",
            claimBattlePassReward     = "amf.feature.localactivity.exploremapgame.http.RequestMistyClearMapClaimBattlePassReward",
            claimPineappleReward      = "amf.feature.localactivity.exploremapgame.http.RequestMistyClearMapClaimPineappleReward",
            claimRewardHeap           = "amf.feature.localactivity.exploremapgame.http.RequestMistyClearMapClaimRewardHeap",
            ringTossConsume           = "amf.feature.localactivity.exploremapgame.http.RequestMistyClearMapRingTossConsume",
            balloonPop                = "amf.feature.localactivity.exploremapgame.http.RequestMistyClearMapBalloonPop",
            rewardEndlessPower        = "amf.feature.localactivity.exploremapgame.http.RequestMistyClearMapRewardEndlessPower",
            claimEndPeriodRewards     = "amf.feature.localactivity.exploremapgame.http.RequestMistyClearMapClaimEndPeriodRewards",
            activityAction            = "amf.feature.localactivity.exploremapgame.http.RequestActivityAction",
        }
    })
end

function Model:_getConstPath()
    return "amf.feature.localactivity.exploremapgame.const.ExploreMapGameConst"
end

function Model:__declare()
    self.userInfo            = {}
    self.localConfig         = {}
    self.timeInfo            = {}
    self.clientMd5           = ""
    self.autoPineappleRewards = {}
    self.packagesPullResponse = {}
    self.beforeBattlePass = nil
    self.yinliuTotalCollection = nil
    self.yinliuIntervalCollection = nil
    self.passLevelSuccessTime = nil
    self.popStage4GiftTime = nil
    self.yinliuPopTimes = nil
    self.pineappleDisplayedProgress = nil
    self.exploreTaskDisplayedCompletedCount = nil
    self.mainBattlePassTipValue = nil
    self.ignoreGiftPanel = nil
    self.energyGiftIgnoredTs = nil
    self.exploremap_energy_gift_show_day = nil
    self.exploremap_energy_gift_show_count = nil
    self.exploremap_progress_gift_pop_count = nil
    self.exploremap_sprint_gift_pop_count = nil
    self.exploremap_final_reward_preview_tip_ts = nil
    self.exploremap_graduation_firework_ts = nil
    self.exploremap_auto_wayfind_sound_count = nil
    self.canyuHadDC = nil
    self.canyuJoinHadDC = nil
    self.manualBalloonHitIdsByScreen = {}
end

-- §6.6
function Model:fromServer(data)
    if not data then return end
    local parsedConfig

    if data.serverVersionedConfig then
        local svc = data.serverVersionedConfig
        if svc.config and svc.config ~= "" then
            parsedConfig = table.deserialize(svc.config) or {}
            self:setValue("localConfig", parsedConfig)
        end
        if svc.clientMd5 then
            self:setValue("clientMd5", svc.clientMd5)
        end
        if svc.serverMd5 then
            self:setValue("clientMd5", svc.serverMd5)
        end
    end
    if data.userBean then
        local ub = data.userBean
        if ub.battlePassValue ~= nil or ub.battlePassFreeAlreadyGotIds ~= nil or ub.battlePassVipAlreadyGotIds ~= nil or ub.battlePassBuyVipTs ~= nil then
            ub.battlePass = ub.battlePass or {}
            if ub.battlePassValue ~= nil then ub.battlePass.value = ub.battlePassValue end
            if ub.battlePassFreeAlreadyGotIds ~= nil then ub.battlePass.freeAlreadyGotIds = ub.battlePassFreeAlreadyGotIds end
            if ub.battlePassVipAlreadyGotIds ~= nil then ub.battlePass.vipAlreadyGotIds = ub.battlePassVipAlreadyGotIds end
            if ub.battlePassBuyVipTs ~= nil then ub.battlePass.buyVipTs = ub.battlePassBuyVipTs end
        end
        ub.finalRewardClaimed = nil
        if ub.balloonScreenIndex ~= nil then ub.ringTossCurrentMapId = nil end
        if ub.poppedBalloonIds ~= nil then ub.ringTossRewardedSlotMap = nil end
        -- mainInfo 兼容旧拆分字段；内部统一为 TaskDataMap 供 UI 读取
        self:setDataByKey("taskDataMap", _normalizeTaskDataMap(ub, parsedConfig or self:getLocalConfig()), true)
        self:setValue("userInfo", ub)
    end
    self:setDataByKey("autoPineappleRewards", data.autoPineappleRewards or {}, true)
    if data.packagesPullResponse ~= nil then
        local packagesPullResponse = data.packagesPullResponse
        self:setDataByKey("packagesPullResponse", packagesPullResponse, true)
        for packageId, goods in pairs(packagesPullResponse.packageMetas or {}) do
            GoodsManager:registerGoods({
                goodsId = packageId,
                packageMeta = goods.packageMeta,
                productId = goods.productId,
            })
        end
    end
end

function Model:updateTimeInfo(time)
    self:setValue("timeInfo", time)
end

function Model:isDataEnabled()
    local userInfo = self:getValue("userInfo")
    if not userInfo or table.isEmpty(userInfo) then
        return false
    end
    return true
end

function Model:getClientMd5()
    return self:getValue("clientMd5") or ""
end

function Model:getMainBeginTime()
    local timeInfo = self:getValue("timeInfo") or {}
    return _toSec(timeInfo.mainBeginTime)
end

function Model:getBeginTime()
    local timeInfo = self:getValue("timeInfo") or {}
    return _toSec(timeInfo.beginTime or timeInfo.mainBeginTime)
end

function Model:getMainEndTime()
    local timeInfo = self:getValue("timeInfo") or {}
    return _toSec(timeInfo.mainEndTime)
end

function Model:getEndTime()
    local timeInfo = self:getValue("timeInfo") or {}
    return _toSec(timeInfo.endTime)
end

function Model:isInMainTime()
    local now = TimeKit:timeInSec()
    return now >= self:getMainBeginTime() and now <= self:getMainEndTime()
end

function Model:isInRewardTime()
    local now = TimeKit:timeInSec()
    return now > self:getMainEndTime() and now <= self:getEndTime()
end

function Model:clearData()
    BaseFeatureModel.clearData(self)
end

-- ============================== Network ==============================

function Model:requestMainInfo(params)
    return self.syncPlug:requestMainInfo(params or {})
end

function Model:onResponseMistyClearMapMainInfo(response)
    if not response:isSuccess() then return end
    local data = response:getData()
    if not data then return end

    self:fromServer(data)
end

function Model:requestOperateNode(params)
    return self.syncPlug:requestOperateNode(params or {})
end

function Model:onResponseMistyClearMapOperateNode(response, reqParam)
    if not response:isSuccess() then return end
    local data = response:getData()
    if not data then return end
    self:assignOperateNodeData(data, reqParam)
end

function Model:requestClaimExploreTaskReward(params)
    return self.syncPlug:requestClaimExploreTaskReward(params or {})
end

function Model:onResponseMistyClearMapClaimExploreTaskReward(response, reqParam)
    if not response:isSuccess() then return end
    local data = response:getData()
    if not data then return end
    self:assignClaimExploreTaskData(data, reqParam)
end

function Model:requestClaimAllExploreTaskReward(params)
    return self.syncPlug:requestClaimAllExploreTaskReward(params or {})
end

function Model:onResponseMistyClearMapClaimAllExploreTaskReward(response)
    if not response:isSuccess() then return end
    local data = response:getData()
    if not data then return end
    self:assignClaimAllExploreTaskData(data)
end

function Model:requestClaimBattlePassReward(params)
    return self.syncPlug:requestClaimBattlePassReward(params or {})
end

function Model:onResponseMistyClearMapClaimBattlePassReward(response)
    if not response:isSuccess() then return end
    local data = response:getData()
    if not data then return end
    self:assignClaimBattlePassData(data)
end

function Model:requestClaimPineappleReward(params)
    return self.syncPlug:requestClaimPineappleReward(params or {})
end

function Model:onResponseMistyClearMapClaimPineappleReward(response)
    if not response:isSuccess() then return end
    local data = response:getData()
    if not data then return end
    self:assignClaimPineappleData(data)
end

function Model:requestClaimRewardHeap(params)
    return self.syncPlug:requestClaimRewardHeap(params or {})
end

function Model:onResponseMistyClearMapClaimRewardHeap(response, reqParam)
    if not response:isSuccess() then return end
    -- 离线协议通常没有业务返回体，奖励堆领取状态按 reqParam 在本地推进。
    local data = response:getData() or {}
    self:assignClaimRewardHeapData(data, reqParam)
end

function Model:requestRingTossConsume(params)
    return self.syncPlug:requestRingTossConsume(params or {})
end

function Model:onResponseMistyClearMapRingTossConsume(response, reqParam)
    if not response:isSuccess() then return end
    local data = response:getData()
    if not data then return end
    self:assignRingTossConsumeData(data, reqParam)
end

function Model:requestBalloonPop(params)
    return self.syncPlug:requestBalloonPop(params or {})
end

function Model:onResponseMistyClearMapBalloonPop(response, reqParam)
    if not response:isSuccess() then return end
    local data = response:getData()
    if not data then return end
    self:assignBalloonPopData(data, reqParam)
end

function Model:requestRewardEndlessPower(params)
    return self.syncPlug:requestRewardEndlessPower(params or {})
end

function Model:onResponseMistyClearMapRewardEndlessPower(response)
    if not response:isSuccess() then return end
    local data = response:getData()
    if not data then return end
    self:assignRewardEndlessPowerData(data)
end

function Model:requestClaimEndPeriodRewards(params)
    return self.syncPlug:requestClaimEndPeriodRewards(params or {})
end

function Model:onResponseMistyClearMapClaimEndPeriodRewards(response)
    if not response:isSuccess() then return end
    local data = response:getData()
    if not data then return end
    self:assignClaimEndPeriodRewardsData(data)
end

function Model:requestActivityAction(params)
    return self.syncPlug:requestActivityAction(params or {})
end

function Model:requestPackagepull(params)
    return self.syncPlug:requestPackagepull(params or {})
end

function Model:onResponseActivityAction(response, reqParam)
    if not response:isSuccess() then return end
    self:assignActivityActionData(response:getData(), reqParam)
end

-- ============================== Assign ==============================

function Model:assignOperateNodeData(data, reqParam)
    local nodeId = reqParam and reqParam.nodeId
    _trace("assignOperateNodeData begin", "nodeId", nodeId, "reqSeg", reqParam and reqParam.segmentIndex or "nil", "done", tostring(data and data.done), "finishedSegments", data and tostring(data.finishedSegments) or "nil", "lastBefore", self:getLastOperatedNodeId(), "energyBefore", self:getEnergy())
    if data.energy ~= nil then self:setEnergy(data.energy) end
    if data.updatedBag then self:applyBagUpdate(data.updatedBag) end
    if data.updatedTaskDataMap then
        self:applyTaskDataMapUpdate(data.updatedTaskDataMap)
    end
    if data.battlePassValue ~= nil then self:setBattlePassValue(data.battlePassValue) end
    if data.remainingObstacleCount ~= nil then self:setRemainingObstacleCount(data.remainingObstacleCount) end
    if data.maxProgressId ~= nil and data.maxProgressId > self:getMaxProgressId() then
        self:setMaxProgressId(data.maxProgressId)
    end
    if data.stageRewards and #data.stageRewards > 0 then
        self:markClaimedStageRewardsByProgress(self:getMaxProgressId())
    end
    if nodeId and data.finishedSegments ~= nil then
        self:setNodeData(nodeId, data.finishedSegments, data.done)
        self:setLastOperatedNodeId(nodeId)
        _trace("assignOperateNodeData nodeData", "nodeId", nodeId, "finishedSegments", data.finishedSegments, "done", tostring(_isDoneValue(data.done)), "lastAfter", self:getLastOperatedNodeId())
    else
        _trace("assignOperateNodeData skip nodeData", "nodeId", nodeId, "hasFinishedSegments", tostring(data and data.finishedSegments ~= nil), "lastAfter", self:getLastOperatedNodeId())
    end
    -- rewards/stageRewards 仅供 UI 展示“恭喜获得”，状态变化通过 updatedBag/updatedTaskDataMap/battlePassValue 同步
end

function Model:markClaimedStageRewardsByProgress(maxProgressId)
    maxProgressId = maxProgressId or 0
    local cfg = self:getLocalConfig() or {}
    local metas = cfg.stageRewardMetas or {}
    for _, meta in ipairs(metas) do
        local lastProgressId = meta.lastProgressId or meta.id or 0
        if lastProgressId <= maxProgressId and not self:isStageRewardClaimed(meta.id) then
            self:addClaimedStageRewardId(meta.id)
        end
    end
end

function Model:assignClaimExploreTaskData(data, reqParam)
    -- §6.13 / §9.2: 返回单个 taskData Bean，覆盖写入对应 taskId 的 TaskData
    if data.energy ~= nil then self:setEnergy(data.energy) end
    if data.updatedBag then self:applyBagUpdate(data.updatedBag) end
    local taskId = data.taskId or (reqParam and reqParam.taskId)
    if taskId ~= nil and data.taskData ~= nil then
        self:_mergeOneTaskData(taskId, data.taskData)
    end
end

function Model:assignClaimAllExploreTaskData(data)
    -- §6.10
    if data.energy ~= nil then self:setEnergy(data.energy) end
    if data.updatedBag then self:applyBagUpdate(data.updatedBag) end
    if data.allExploreTaskRewardClaimed == true then
        self:setAllExploreTaskRewardClaimed(true)
    end
end

function Model:assignClaimBattlePassData(data)
    -- §6.2
    if data.energy ~= nil then self:setEnergy(data.energy) end
    if data.updatedBag then self:applyBagUpdate(data.updatedBag) end
    if data.freeAlreadyGotIds ~= nil and type(data.freeAlreadyGotIds) == "table" then
        self:setDataByKey("battlePass.freeAlreadyGotIds", data.freeAlreadyGotIds, true)
    end
    if data.vipAlreadyGotIds ~= nil and type(data.vipAlreadyGotIds) == "table" then
        self:setDataByKey("battlePass.vipAlreadyGotIds", data.vipAlreadyGotIds, true)
    end
    if data.hasVip ~= nil then
        self:setDataByKey("battlePass.hasVip", data.hasVip == true, true)
    end
end

function Model:assignClaimPineappleData(data)
    -- §6.3
    if data.energy ~= nil then self:setEnergy(data.energy) end
    if data.updatedBag then self:applyBagUpdate(data.updatedBag) end
    if data.pineappleClaimedNodeMap ~= nil and type(data.pineappleClaimedNodeMap) == "table" then
        self:setDataByKey("pineappleClaimedNodeMap", data.pineappleClaimedNodeMap, true)
    end
end

function Model:assignClaimRewardHeapData(data, reqParam)
    -- §6.11
    if data.energy ~= nil then self:setEnergy(data.energy) end
    if data.updatedBag then self:applyBagUpdate(data.updatedBag) end
    local nodeId = reqParam and reqParam.nodeId
    local rewardIndex = reqParam and reqParam.rewardIndex
    if (data.code == nil or data.code == 0) and nodeId ~= nil and rewardIndex ~= nil then
        self:addRewardHeapClaimed(nodeId, rewardIndex)
    end
    -- 石台探索任务的进度定义为“已全部领取的奖励堆数量”，领奖后立刻重算任务进度。
    self:applyRewardHeapTaskProgress()
end

function Model:getStoneRewardHeapSlotCountMap()
    local cfg = self:getLocalConfig() or {}
    local Const = self:getConst()
    local ret = {}
    -- rewardHeapMetas 是奖励堆 slot 定义；石台任务只统计 rewardHeapType == STONE 的奖励堆。
    for _, meta in ipairs(cfg.rewardHeapMetas or {}) do
        if meta and Const.isStoneRewardHeapType(meta.rewardHeapType) then
            local heapId = meta.rewardHeapId
            local slotIndex = meta.slotIndex
            if heapId ~= nil and slotIndex ~= nil then
                ret[heapId] = math.max(ret[heapId] or 0, slotIndex)
            end
        end
    end
    return ret
end

function Model:isStoneRewardHeapClaimedAll(nodeId, slotCountMap)
    local node = self:getNodeRuntimeParams(nodeId)
    local heapId = node and node.rewardHeapId
    if not heapId or heapId == 0 then return false end
    local total = slotCountMap and slotCountMap[heapId] or 0
    if total <= 0 then return false end
    for i = 1, total do
        if not self:isRewardHeapClaimed(nodeId, i) then return false end
    end
    return true
end

function Model:getStoneRewardHeapClaimedAllCount()
    local cfg = self:getLocalConfig() or {}
    local nodes = cfg.nodeMetas or cfg.nodes or {}
    local slotCountMap = self:getStoneRewardHeapSlotCountMap()
    local count = 0
    for _, node in ipairs(nodes) do
        local heapId = node and node.rewardHeapId
        if node and node.id ~= nil and heapId and heapId ~= 0 and slotCountMap[heapId] then
            if self:isStoneRewardHeapClaimedAll(node.id, slotCountMap) then
                count = count + 1
            end
        end
    end
    return count
end

function Model:applyRewardHeapTaskProgress()
    local cfg = self:getLocalConfig() or {}
    local Const = self:getConst()
    local actionType = Const and Const.ExploreTaskActionType and Const.ExploreTaskActionType.REWARD_HEAP_ALL_REWARDED
    if not actionType then return end
    local current = self:getStoneRewardHeapClaimedAllCount()
    for _, task in ipairs(cfg.exploreTaskMetas or {}) do
        if task and task.actionType == actionType then
            -- 服务端不回 taskData 时，本地用当前已全领石台数同步 REWARD_HEAP_ALL_REWARDED 任务。
            local taskId = task.id
            local td = self:getTaskData(taskId) or {}
            local targetCount = tonumber(task.targetCount) or 0
            local progress = current
            if targetCount > 0 and progress > targetCount then progress = targetCount end
            self:_mergeOneTaskData(taskId, {
                current = progress,
                finished = targetCount > 0 and progress >= targetCount or td.finished,
                claimed = td.claimed,
                collections = td.collections,
            })
        end
    end
end

function Model:applyConsumeItemTaskProgress(itemId, count)
    itemId = tonumber(itemId)
    count = tonumber(count) or 0
    if not itemId or count <= 0 then return end

    local cfg = self:getLocalConfig() or {}
    for _, task in ipairs(cfg.exploreTaskMetas or {}) do
        if task
            and task.actionType == "CONSUME_ITEM"
            and tonumber(task.targetItemId) == itemId then
            local taskId = task.id
            local td = self:getTaskData(taskId) or {}
            local targetCount = tonumber(task.targetCount) or 0
            local current = (tonumber(td.current) or 0) + count
            if targetCount > 0 and current > targetCount then current = targetCount end
            self:_mergeOneTaskData(taskId, {
                current = current,
                finished = targetCount > 0 and current >= targetCount or td.finished,
                claimed = td.claimed,
                collections = td.collections,
            })
        end
    end
end

local function _getConsumedDartCountFromReq(reqParam)
    if not reqParam then return 0 end
    if type(reqParam.balloonIds) == "table" then return #reqParam.balloonIds end
    local balloonId = reqParam.balloonId or reqParam.slotId
    if balloonId and balloonId ~= -1 then return 1 end
    return 0
end

function Model:assignRingTossConsumeData(data, reqParam)
    -- 扎气球沿用旧 ringTossConsume 通道名，状态字段以 balloon* 为准
    if data.energy ~= nil then self:setEnergy(data.energy) end
    if data.updatedBag then self:applyBagUpdate(data.updatedBag) end
    if data.updatedTaskDataMap then self:applyTaskDataMapUpdate(data.updatedTaskDataMap) end
    if data.taskDataMap then self:setDataByKey("taskDataMap", data.taskDataMap, true) end
    if not data.updatedTaskDataMap and not data.taskDataMap then
        self:applyConsumeItemTaskProgress(self:getConst().ItemId.RING, _getConsumedDartCountFromReq(reqParam))
    end
    local screenIndex = reqParam and (reqParam.screenIndex or reqParam.mapId)
    local balloonId = reqParam and (reqParam.balloonId or reqParam.slotId)
    if screenIndex and balloonId and balloonId ~= -1 then
        self:markBalloonPopped(screenIndex, balloonId)
    end
    if data.balloonScreenIndex ~= nil then
        self:setBalloonScreenIndex(data.balloonScreenIndex)
    end
    if data.poppedBalloonIds ~= nil then
        self:setPoppedBalloonIds(data.poppedBalloonIds)
    end
    if data.nextMapId ~= nil then
        self:setRingTossCurrentMapId(data.nextMapId)
        self:setPoppedBalloonIds({})
    end
end

function Model:assignBalloonPopData(data, reqParam)
    local oldScreenIndex = self:getBalloonScreenIndex()
    if data.energy ~= nil then self:setEnergy(data.energy) end
    if data.updatedBag then self:applyBagUpdate(data.updatedBag) end
    if data.updatedTaskDataMap then self:applyTaskDataMapUpdate(data.updatedTaskDataMap) end
    if data.taskDataMap then self:setDataByKey("taskDataMap", data.taskDataMap, true) end
    if not data.updatedTaskDataMap and not data.taskDataMap then
        self:applyConsumeItemTaskProgress(self:getConst().ItemId.RING, _getConsumedDartCountFromReq(reqParam))
    end
    if data.balloonScreenIndex ~= nil then
        self:setBalloonScreenIndex(data.balloonScreenIndex)
    end
    if data.poppedBalloonIds ~= nil then
        self:setPoppedBalloonIds(data.poppedBalloonIds)
    elseif data.balloonScreenIndex ~= nil and tonumber(data.balloonScreenIndex) ~= tonumber(oldScreenIndex) then
        self:setPoppedBalloonIds({})
    end
end

function Model:assignRewardEndlessPowerData(data)
    -- §6.9.2
    if data.rewardIndex ~= nil then
        self:setEndlessPowerRewardIndex(data.rewardIndex)
    end
    if data.unlockRound ~= nil then
        self:setDataByKey("endlessPower.unlockRound", data.unlockRound, true)
    end
    if data.nextNodeIndex ~= nil then
        self:setDataByKey("endlessPower.nextNodeIndex", data.nextNodeIndex, true)
    end
    if data.nextNodeIsPaid ~= nil then
        self:setDataByKey("endlessPower.nextNodeIsPaid", data.nextNodeIsPaid == true, true)
    end
end

function Model:applyEndlessPowerPaidUnlock()
    local ep = self:getEndlessPower() or {}
    ep.rewardIndex = (ep.rewardIndex or 0) + 1
    ep.unlockRound = (ep.unlockRound or 0) + 1
    self:setEndlessPower(ep)
end

function Model:applyPackageDeliverNotify(packageId, buyType, requestTs)
    local now = requestTs or (TimeKit and TimeKit.timeInSec and TimeKit:timeInSec()) or os.time()
    if buyType == "FLOW" and requestTs ~= nil then
        self:setLatestBuyFlowTs(math.max(self:getLatestBuyFlowTs(), requestTs))
    elseif buyType == "ENDLESS_POWER" then
        self:applyEndlessPowerPaidUnlock()
    elseif buyType == "RMB_ENERGY" and packageId ~= nil then
        self:addTodayBuyPackageTimes(packageId, now)
    elseif buyType == "CASH_ENERGY" then
        self:addTodayBuyEnergyTimes(packageId, now)
    end
end

function Model:addTodayBuyPackageTimes(packageId, requestTs)
    if packageId == nil then return end

    local dayKey = _getDayKey(requestTs)
    local perDayMap = self:getPerDayInfoMap() or {}
    local info = self:getPerDayInfo(dayKey)
    local map = info.buyPackageIdMap or {}
    map[packageId] = (map[packageId] or map[tostring(packageId)] or 0) + 1
    info.buyPackageIdMap = map
    perDayMap[dayKey] = info
    if tostring(dayKey) ~= dayKey then
        perDayMap[tostring(dayKey)] = nil
    end
    self:setDataByKey("perDayInfoMap", perDayMap, true)
end

function Model:addTodayBuyEnergyTimes(packageId, requestTs)
    local dayKey = _getDayKey(requestTs)
    local perDayMap = self:getPerDayInfoMap() or {}
    local info = self:getPerDayInfo(dayKey)
    info.buyEnergyTimes = (info.buyEnergyTimes or 0) + 1
    if packageId ~= nil then
        local map = info.buyPackageIdMap or {}
        map[packageId] = (map[packageId] or map[tostring(packageId)] or 0) + 1
        info.buyPackageIdMap = map
    end
    perDayMap[dayKey] = info
    if tostring(dayKey) ~= dayKey then
        perDayMap[tostring(dayKey)] = nil
    end
    self:setDataByKey("perDayInfoMap", perDayMap, true)
end

function Model:assignClaimEndPeriodRewardsData(data)
    -- §6.5
    if data.endRewardClaimed == true then
        self:setEndRewardClaimed(true)
    end
    if data.energy ~= nil then self:setEnergy(data.energy) end
    if data.updatedBag then self:applyBagUpdate(data.updatedBag) end
    if data.updatedTaskDataMap then self:applyTaskDataMapUpdate(data.updatedTaskDataMap) end
    if data.taskDataMap then self:setDataByKey("taskDataMap", data.taskDataMap, true) end
    if data.allExploreTaskRewardClaimed ~= nil then self:setAllExploreTaskRewardClaimed(data.allExploreTaskRewardClaimed == true) end
    if data.battlePass ~= nil then self:setDataByKey("battlePass", data.battlePass, true) end
    if data.freeAlreadyGotIds ~= nil then self:setDataByKey("battlePass.freeAlreadyGotIds", data.freeAlreadyGotIds, true) end
    if data.vipAlreadyGotIds ~= nil then self:setDataByKey("battlePass.vipAlreadyGotIds", data.vipAlreadyGotIds, true) end
    if data.pineappleClaimedNodeMap ~= nil then self:setDataByKey("pineappleClaimedNodeMap", data.pineappleClaimedNodeMap, true) end
    if data.rewardHeapClaimedMap ~= nil then self:setDataByKey("rewardHeapClaimedMap", data.rewardHeapClaimedMap, true) end
end

function Model:assignActivityActionData(_data, reqParam)
    if _data ~= nil and reqParam and reqParam.action == "notShowToday" then
        self:setLatestFlowTodayNotShowTs(TimeKit:timeInSec())
    end
end

-- ============================== Reads ==============================

function Model:getEnergy()
    return self:getDataByKey("energy", 0)
end

function Model:getYinliuTotalCollection()
    return self:getFlagFromLocalByKeyInt("yinliuTotalCollection", true, true)
end

function Model:getYinliuIntervalCollection()
    return self:getFlagFromLocalByKeyInt("yinliuIntervalCollection", true, true)
end

function Model:getYinliuPopTimes()
    return self:getFlagFromLocalByKeyInt("yinliuPopTimes", true, true)
end

function Model:getBag()
    return self:getDataByKey("bag", {})
end

function Model:getBagItemNum(itemId)
    local bag = self:getBag() or {}
    return bag[itemId] or bag[tostring(itemId)] or 0
end

function Model:getNodeDataMap()
    return self:getDataByKey("nodeDataMap", {})
end

function Model:getNodeData(nodeId)
    local map = self:getNodeDataMap() or {}
    return map[nodeId] or map[tostring(nodeId)]
end

function Model:isNodeDone(nodeId)
    local nd = self:getNodeData(nodeId)
    return nd and _isDoneValue(nd.done)
end

function Model:getNodeFinishedSegments(nodeId)
    local nd = self:getNodeData(nodeId)
    return nd and nd.finishedSegments or 0
end

function Model:getMaxProgressId()
    return self:getDataByKey("maxProgressId", 0)
end

-- §9.1 TaskData 系列接口

function Model:getTaskDataMap()
    return self:getDataByKey("taskDataMap", {})
end

function Model:getTaskData(taskId)
    local map = self:getTaskDataMap() or {}
    return map[taskId] or map[tostring(taskId)]
end

function Model:isTaskFinished(taskId)
    local td = self:getTaskData(taskId)
    return td ~= nil and td.finished == true
end

function Model:isTaskClaimed(taskId)
    local td = self:getTaskData(taskId)
    return td ~= nil and td.claimed == true
end

function Model:getTaskCurrent(taskId)
    local td = self:getTaskData(taskId)
    return (td and td.current) or 0
end

function Model:getTaskCollections(taskId)
    local td = self:getTaskData(taskId)
    return (td and td.collections) or {}
end

function Model:getExploreTaskProgressMap()
    local map = self:getTaskDataMap() or {}
    local out = {}
    for k, td in pairs(map) do
        out[k] = (td and td.current) or 0
    end
    return out
end

function Model:getExploreTaskProgress(taskId)
    return self:getTaskCurrent(taskId)
end

function Model:isExploreTaskClaimed(taskId)
    return self:isTaskClaimed(taskId)
end

function Model:isAllExploreTaskRewardClaimed()
    return self:getDataByKey("allExploreTaskRewardClaimed", false) == true
end

function Model:getBattlePass()
    return self:getDataByKey("battlePass", {
        value = 0,
        hasVip = false,
        freeAlreadyGotIds = {},
        vipAlreadyGotIds = {},
        buyVipTs = 0,
    })
end

function Model:getBattlePassValue()
    return self:getDataByKey("battlePass.value", 0)
end

function Model:hasBattlePassVip()
    if self:getDataByKey("battlePass.hasVip", false) == true then return true end
    return (self:getDataByKey("battlePass.buyVipTs", 0) or 0) > 0
end

function Model:getRemainingObstacleCount()
    return self:getDataByKey("remainingObstacleCount", -1)
end

function Model:getPineappleClaimedMap()
    return self:getDataByKey("pineappleClaimedNodeMap", {})
end

function Model:isPineappleClaimed(periodId, nodeId)
    local map = self:getPineappleClaimedMap() or {}
    local periodSet = map[periodId] or map[tostring(periodId)] or {}
    if type(periodSet) == "table" then
        for _, v in ipairs(periodSet) do
            if v == nodeId then return true end
        end
    end
    return false
end

function Model:getPineappleStationState(periodId)
    local map = self:getDataByKey("pineappleStationStateMap", {})
    return tonumber(map[periodId] or map[tostring(periodId)] or 0) or 0
end

function Model:getPineappleDisplayedProgress(periodId)
    local raw = self:getFlagFromLocalByKeyStr("pineappleDisplayedProgress", false, true)
    local map = table.deserialize(raw or "") or {}
    return map[periodId] or map[tostring(periodId)] or 0
end

function Model:setPineappleDisplayedProgress(periodId, progress)
    if periodId == nil then return end
    local raw = self:getFlagFromLocalByKeyStr("pineappleDisplayedProgress", false, true)
    local map = table.deserialize(raw or "") or {}
    map[tostring(periodId)] = math.floor(tonumber(progress) or 0)
    self:saveFlagToLocalByKeyStr("pineappleDisplayedProgress", false, table.serialize(map), true)
end

function Model:getExploreTaskDisplayedCompletedCount()
    return self:getFlagFromLocalByKeyInt("exploreTaskDisplayedCompletedCount", false, true) or 0
end

function Model:setExploreTaskDisplayedCompletedCount(count)
    self:saveFlagToLocalByKeyInt("exploreTaskDisplayedCompletedCount", false, math.floor(tonumber(count) or 0), true)
end

function Model:getEnergyGiftShowCountToday()
    local todayStart = TimeKit:getTodayStart()
    local day = self:getFlagFromLocalByKeyInt(ENERGY_GIFT_SHOW_DAY_KEY, true, true)
    if day ~= todayStart then return 0 end
    return self:getFlagFromLocalByKeyInt(ENERGY_GIFT_SHOW_COUNT_KEY, true, true) or 0
end

function Model:appendEnergyGiftShowCountToday()
    local todayStart = TimeKit:getTodayStart()
    local count = self:getEnergyGiftShowCountToday()
    self:saveFlagToLocalByKeyInt(ENERGY_GIFT_SHOW_DAY_KEY, true, todayStart, true)
    self:saveFlagToLocalByKeyInt(ENERGY_GIFT_SHOW_COUNT_KEY, true, count + 1, true)
end

function Model:getClaimedStageRewardIds()
    return self:getDataByKey("claimedStageRewardIds", {})
end

function Model:isStageRewardClaimed(stageId)
    for _, id in ipairs(self:getClaimedStageRewardIds() or {}) do
        if id == stageId then return true end
    end
    return false
end

function Model:getActivityLimitPackageIds()
    return self:getDataByKey("activityLimitPackageIds", {})
end

function Model:isActivityLimitPackageBought(packageId)
    for _, id in ipairs(self:getActivityLimitPackageIds() or {}) do
        if id == packageId then return true end
    end
    return false
end

function Model:getActShowTimes()
    return self:getDataByKey("actShowTimes", {})
end

function Model:getActShowTimesByType(buyType)
    if buyType == nil then return {} end
    local map = self:getActShowTimes() or {}
    local key = tostring(buyType)
    return map[key] or {}
end

function Model:getPerDayInfoMap()
    return self:getDataByKey("perDayInfoMap", {})
end

function Model:getPerDayInfo(day)
    day = day or _getDayKey()
    local map = self:getPerDayInfoMap() or {}
    local key = tonumber(day) or day
    return map[key] or map[tostring(key)] or {}
end

function Model:getPayTagV2Id(day)
    local info = self:getPerDayInfo(day) or {}
    return info.payTagV2Id or 0
end

function Model:getBuyEnergyTimes(day)
    local info = self:getPerDayInfo(day) or {}
    return info.buyEnergyTimes or 0
end

function Model:getBuyPackageTimes(day, packageId)
    if packageId == nil then return 0 end
    local info = self:getPerDayInfo(day) or {}
    local map = info.buyPackageIdMap or {}
    return map[packageId] or map[tostring(packageId)] or 0
end

function Model:getFlowNextShowIndex(day)
    local info = self:getPerDayInfo(day) or {}
    return info.flowNextShowIndex or 0
end

function Model:isGraduated()
    return self:getDataByKey("graduated", false) == true
end

function Model:getRingTossCurrentMapId()
    return self:getBalloonScreenIndex()
end

function Model:getRingTossRewardedSlotMap()
    return self:getDataByKey("poppedBalloonIds", {})
end

function Model:isRingTossSlotRewarded(mapId, slotId)
    if slotId == nil then return false end
    local screenIndex = self:getBalloonScreenIndex()
    if mapId ~= nil and screenIndex ~= 0 and tonumber(mapId) ~= tonumber(screenIndex) then return false end
    local list = self:getPoppedBalloonIds() or {}
    for _, v in ipairs(list) do
        if v == slotId then return true end
    end
    return false
end

function Model:isBalloonPopped(screenIndex, balloonId)
    return self:isRingTossSlotRewarded(screenIndex, balloonId)
end

function Model:getBalloonScreenIndex()
    return self:getDataByKey("balloonScreenIndex", self:getDataByKey("ringTossCurrentMapId", 0))
end

function Model:getPoppedBalloonIds()
    return self:getDataByKey("poppedBalloonIds", {})
end

function Model:isFinalRewardClaimed()
    return self:getDataByKey("finalRewardClaimed", false) == true
end

function Model:isEndRewardClaimed()
    return self:getDataByKey("endRewardClaimed", false) == true
end

function Model:getBuffExpireTs(buffType)
    local Const = self:getConst()
    if buffType == Const.BuffType.SCORE_20 then
        return self:getDataByKey("buffScore20ExpireTs", 0)
    elseif buffType == Const.BuffType.SCORE_50 then
        return self:getDataByKey("buffScore50ExpireTs", 0)
    elseif buffType == Const.BuffType.DOUBLE then
        return self:getDataByKey("buffDoubleExpireTs", 0)
    end
    return 0
end

function Model:getBuffExpireTsInSec(buffType)
    return math.floor((tonumber(self:getBuffExpireTs(buffType)) or 0) / 1000)
end

function Model:getEndlessPower()
    return self:getDataByKey("endlessPower", {
        periodId    = 0,
        rewardIndex = 0,
        unlockRound = 0,
        nextNodeIndex = 0,
        nextNodeIsPaid = false,
    })
end

function Model:getEndlessPowerNextNodeIndex()
    return self:getDataByKey("endlessPower.nextNodeIndex", 0)
end

function Model:isEndlessPowerNextNodePaid()
    return self:getDataByKey("endlessPower.nextNodeIsPaid", false) == true
end

function Model:getLatestBuyFlowTs()
    return tonumber(self:getDataByKey("latestBuyFlowTs", 0)) or 0
end

function Model:getLatestFlowTodayNotShowTs()
    return tonumber(self:getDataByKey("latestFlowTodayNotShowTs", 0)) or 0
end

function Model:getLastOperatedNodeId()
    return self:getDataByKey("lastOperatedNodeId", 0)
end

-- ============================== Runtime Config ==============================

function Model:getLocalConfig()
    return self:getValue("localConfig") or {}
end

function Model:getNodeRuntimeParams(nodeId)
    local cfg = self:getLocalConfig()
    local nodes = cfg and (cfg.nodeMetas or cfg.nodes)
    if not nodes then return nil end
    local node = nodes[nodeId] or nodes[tostring(nodeId)]
    if node and node.id ~= nil and node.id ~= nodeId then node = nil end
    if node then return node end
    for _, v in ipairs(nodes) do
        if v and v.id == nodeId then return v end
    end
    return nil
end

function Model:getFogRuntimeRule(fogId)
    local cfg = self:getLocalConfig()
    if not cfg or not cfg.fogs then return nil end
    return cfg.fogs[fogId]
end

function Model:getStoryRuntimeRule(storyId)
    local cfg = self:getLocalConfig()
    if not cfg or not cfg.stories then return nil end
    return cfg.stories[storyId]
end

function Model:getFragmentRuntimeSource(idx)
    local cfg = self:getLocalConfig()
    if not cfg or not cfg.fragments then return nil end
    return cfg.fragments[idx] or cfg.fragments[tostring(idx)]
end

function Model:getGuideFlagSet()
    return self:getDataByKey("guideFlagSet", {})
end

function Model:hasGuideFlag(index)
    for _, v in ipairs(self:getGuideFlagSet() or {}) do
        if v == index then return true end
    end
    return false
end

function Model:getRewardHeapClaimedMap()
    return self:getDataByKey("rewardHeapClaimedMap", {})
end

function Model:isRewardHeapClaimed(nodeId, rewardIndex)
    local map = self:getRewardHeapClaimedMap() or {}
    local list = map[nodeId] or map[tostring(nodeId)]
    if type(list) ~= "table" then return false end
    local target = tonumber(rewardIndex) or rewardIndex
    for _, v in ipairs(list) do
        if (tonumber(v) or v) == target then return true end
    end
    return false
end

function Model:getAutoPineappleRewards()
    return self:getDataByKey("autoPineappleRewards", {}) or {}
end

function Model:consumeAutoPineappleRewards()
    local r = self:getDataByKey("autoPineappleRewards")
    self:setDataByKey("autoPineappleRewards", {}, true)
    return r or {}
end

function Model:getPackagesPullResponse()
    return self:getDataByKey("packagesPullResponse", {}) or {}
end

function Model:getGiftPackages()
    local resp = self:getPackagesPullResponse()
    return {
        displayablePackages = resp.displayablePackages or {},
        packageMetas = resp.packageMetas or {},
        moduleExtraMap = resp.moduleExtraMap or {},
    }
end

function Model:getDisplayablePackages()
    local resp = self:getPackagesPullResponse()
    return resp.displayablePackages or {}
end

function Model:getPackageMetas()
    local resp = self:getPackagesPullResponse()
    return resp.packageMetas or {}
end

function Model:getModuleExtraMap()
    local resp = self:getPackagesPullResponse()
    return resp.moduleExtraMap or {}
end

function Model:getPackageIdByType(type)
    local packs = self:getDisplayablePackages()
    for i, v in pairs(packs) do
        if v.extra then
            local dic = table.deserialize(v.extra)
            if dic.type == type then
                return v.packageId
            end
        end
    end
    return nil
end

function Model:setDisplayablePackagesById(id, value)
    local packs = self:getDisplayablePackages()
    for i, v in pairs(packs) do
        if v.packageId == id then
            packs[i] = value
            return true
        end
    end
    return false
end

function Model:setDisplayablePackages(packages)
    local resp = self:getPackagesPullResponse()
    for k, v in pairs(packages) do
        resp[k] = v
    end
    self:setDataByKey("packagesPullResponse", resp, true)
end

function Model:getExtraOfGoodsById(id)
    local packs = self:getDisplayablePackages()
    for i, v in pairs(packs) do
        if v.packageId == id then
            return table.deserialize(v.extra)
        end
    end
    return nil
end

-- ============================== Writes ==============================

function Model:setEnergy(v)
    if v == nil then return end
    self:setDataByKey("energy", v, true)
end

function Model:addEnergy(num)
    self:setEnergy((self:getEnergy() or 0) + (tonumber(num) or 0))
end

function Model:onYinliuPopout()
    self:saveFlagToLocalByKeyInt("yinliuIntervalCollection", true, 0, true)
    self:saveFlagToLocalByKeyInt("yinliuPopTimes", true, self:getYinliuPopTimes() + 1, true)
end

function Model:applyBagUpdate(updatedBag)
    if not updatedBag then return end
    local bag = self:getBag() or {}
    for itemId, newCount in pairs(updatedBag) do
        local k = tonumber(itemId) or itemId
        local v = tonumber(newCount) or 0
        local sk = tostring(k)
        if v > 0 then
            bag[k] = v
            if sk ~= k then
                bag[sk] = nil
            end
        else
            bag[k] = nil
            if sk ~= k then
                bag[sk] = nil
            end
        end
    end
    self:setDataByKey("bag", bag, true)
end

-- addRewardsNormal 可能会先本地加普通奖励；这里只用回包里的权威 energy / updatedBag 覆盖奖励字段。
function Model:syncRewardFields(data)
    data = data or {}
    if data.energy ~= nil then self:setEnergy(data.energy) end
    if data.updatedBag then self:applyBagUpdate(data.updatedBag) end
    if data.graduated ~= nil then self:setGraduated(data.graduated == true) end
    if data.endRewardClaimed ~= nil then self:setEndRewardClaimed(data.endRewardClaimed == true) end
    if data.finalRewardClaimed ~= nil then self:setDataByKey("finalRewardClaimed", data.finalRewardClaimed == true, true) end
end

-- DEPRECATED: 改为 applyBagUpdate（updatedBag 是绝对快照而非 delta）
function Model:applyBagDelta(updatedBag)
    return self:applyBagUpdate(updatedBag)
end

function Model:setNodeData(nodeId, finishedSegments, done)
    local map = self:getNodeDataMap() or {}
    map[nodeId] = {
        finishedSegments = finishedSegments or 0,
        done             = _isDoneValue(done),
    }
    self:setDataByKey("nodeDataMap", map, true)
end

function Model:setMaxProgressId(v)
    self:setDataByKey("maxProgressId", v or 0, true)
end

function Model:setGraduated(b)
    self:setDataByKey("graduated", b == true, true)
end

function Model:setRemainingObstacleCount(count)
    self:setDataByKey("remainingObstacleCount", count or -1, true)
end

function Model:setRingTossCurrentMapId(mapId)
    self:setBalloonScreenIndex(mapId)
end

function Model:markRingTossSlotRewarded(mapId, slotId)
    if mapId == nil or slotId == nil then return end
    local currentScreen = self:getBalloonScreenIndex()
    local screenIndex = tonumber(mapId) or 0
    if currentScreen ~= 0 and screenIndex ~= currentScreen then return end
    local list = self:getPoppedBalloonIds() or {}
    for _, v in ipairs(list) do
        if v == slotId then return end
    end
    table.insert(list, slotId)
    self:setDataByKey("poppedBalloonIds", list, true)
end

function Model:markBalloonPopped(screenIndex, balloonId)
    return self:markRingTossSlotRewarded(screenIndex, balloonId)
end

function Model:setBalloonScreenIndex(screenIndex)
    self:setDataByKey("balloonScreenIndex", screenIndex or 0, true)
end

function Model:setPoppedBalloonIds(ids)
    self:setDataByKey("poppedBalloonIds", ids or {}, true)
end

function Model:addClaimedStageRewardId(stageId)
    if stageId == nil then return end
    local list = self:getClaimedStageRewardIds() or {}
    for _, id in ipairs(list) do
        if id == stageId then return end
    end
    table.insert(list, stageId)
    self:setDataByKey("claimedStageRewardIds", list, true)
end

function Model:addActivityLimitPackageId(packageId)
    if packageId == nil then return end
    local list = self:getActivityLimitPackageIds() or {}
    for _, id in ipairs(list) do
        if id == packageId then return end
    end
    table.insert(list, packageId)
    self:setDataByKey("activityLimitPackageIds", list, true)
end

function Model:appendActShowTime(buyType, ts)
    if buyType == nil or ts == nil then return end
    local map = self:getActShowTimes() or {}
    local key = tostring(buyType)
    local list = map[key]
    if type(list) ~= "table" then
        list = {}
    end
    table.insert(list, ts)
    map[key] = list
    self:setDataByKey("actShowTimes", map, true)
end

function Model:_mergeOneTaskData(taskId, taskDataBean)
    if taskId == nil or taskDataBean == nil then return end
    local map = self:getTaskDataMap() or {}
    local k = tonumber(taskId) or taskId
    local existing = map[k] or {}
    if taskDataBean.current ~= nil then existing.current = taskDataBean.current end
    if taskDataBean.collections ~= nil then existing.collections = taskDataBean.collections end
    if taskDataBean.finished ~= nil then existing.finished = taskDataBean.finished end
    if taskDataBean.claimed ~= nil then existing.claimed = taskDataBean.claimed end
    map[k] = existing
    self:setDataByKey("taskDataMap", map, true)
end

function Model:applyTaskDataMapUpdate(updatedMap)
    if not updatedMap then return end
    for taskId, taskDataBean in pairs(updatedMap) do
        self:_mergeOneTaskData(taskId, taskDataBean)
    end
end

function Model:setAllExploreTaskRewardClaimed(b)
    self:setDataByKey("allExploreTaskRewardClaimed", b == true, true)
end

function Model:setBattlePassValue(v)
    self:setDataByKey("battlePass.value", v or 0, true)
end

function Model:setBattlePassHasVip(hasVip)
    self:setDataByKey("battlePass.hasVip", hasVip == true, true)
end

function Model:addBattlePassGotId(id, vip)
    local key = vip and "battlePass.vipAlreadyGotIds" or "battlePass.freeAlreadyGotIds"
    local list = self:getDataByKey(key, {}) or {}
    for _, v in ipairs(list) do
        if v == id then return end
    end
    table.insert(list, id)
    self:setDataByKey(key, list, true)
end

function Model:addPineappleClaimedNode(periodId, nodeId)
    local map = self:getPineappleClaimedMap() or {}
    local periodList = map[periodId] or {}
    for _, v in ipairs(periodList) do
        if v == nodeId then return end
    end
    table.insert(periodList, nodeId)
    map[periodId] = periodList
    self:setDataByKey("pineappleClaimedNodeMap", map, true)
end

function Model:setEndlessPowerRewardIndex(idx)
    self:setDataByKey("endlessPower.rewardIndex", idx or 0, true)
end

function Model:setEndlessPower(ep)
    if not ep then return end
    self:setDataByKey("endlessPower", ep, true)
end

function Model:applyEndPeriodStateFromRewards(rewards)
    if table.isEmpty(rewards or {}) then return end
    local exchangeRewards = rewards.exchangeRewards or {}
    local pendingRewards = rewards.pendingRewards or {}
    self:setDataByKey("lastEndPeriodExchangeRewards", exchangeRewards, true)
    self:setDataByKey("lastEndPeriodPendingRewards", pendingRewards, true)
end

function Model:setEndRewardClaimed(b)
    self:setDataByKey("endRewardClaimed", b == true, true)
end

function Model:setLatestBuyFlowTs(ts)
    self:setDataByKey("latestBuyFlowTs", tonumber(ts) or 0, true)
end

function Model:setLatestFlowTodayNotShowTs(ts)
    self:setDataByKey("latestFlowTodayNotShowTs", tonumber(ts) or 0, true)
end

function Model:setLastOperatedNodeId(nodeId)
    _trace("setLastOperatedNodeId", "nodeId", nodeId, "lastBefore", self:getLastOperatedNodeId())
    self:setDataByKey("lastOperatedNodeId", nodeId or 0, true)
end

function Model:addGuideFlag(index)
    if not index then return end
    local list = self:getGuideFlagSet() or {}
    for _, v in ipairs(list) do
        if v == index then return end
    end
    table.insert(list, index)
    self:setDataByKey("guideFlagSet", list, true)
end

function Model:addRewardHeapClaimed(nodeId, rewardIndex)
    if nodeId == nil or rewardIndex == nil then return end
    local map = self:getRewardHeapClaimedMap() or {}
    local list = map[nodeId] or map[tostring(nodeId)] or {}
    local target = tonumber(rewardIndex) or rewardIndex
    for _, v in ipairs(list) do
        if (tonumber(v) or v) == target then return end
    end
    table.insert(list, rewardIndex)
    map[nodeId] = list
    self:setDataByKey("rewardHeapClaimedMap", map, true)
end

function Model:setBuffExpireTs(buffType, ts)
    local Const = self:getConst()
    if buffType == Const.BuffType.SCORE_20 then
        self:setDataByKey("buffScore20ExpireTs", ts or 0, true)
    elseif buffType == Const.BuffType.SCORE_50 then
        self:setDataByKey("buffScore50ExpireTs", ts or 0, true)
    elseif buffType == Const.BuffType.DOUBLE then
        self:setDataByKey("buffDoubleExpireTs", ts or 0, true)
    end
end

function Model:addBuffTime(buffType, minutes)
    local now = TimeKit:timeInMillis()
    local expireTs = tonumber(self:getBuffExpireTs(buffType)) or 0
    local addMillis = (tonumber(minutes) or 0) * 60 * 1000
    if now < expireTs then
        expireTs = expireTs + addMillis
    else
        expireTs = now + addMillis
    end
    self:setBuffExpireTs(buffType, expireTs)
end

return Model
