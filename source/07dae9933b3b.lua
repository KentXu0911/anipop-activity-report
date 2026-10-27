local BaseFeatureModel = require"amf.middleware.activity.base.BaseFeatureModel"
local Meta = require 'amf.feature.localactivity.merge.config.MergeConfig'
local BoardMeta = require 'amf.feature.localactivity.merge.config.BoardMeta'

local ACT_NAME = "merge"
local LOCAL_PATH = 'amf.feature.localactivity.'..string.lower( ACT_NAME )
local RESTAURANT_RATING_DATA_KEY = "restaurantRatingData"
local RESTAURANT_RATING_META_LIST_KEY = "restaurantRatingMetaList"
local DEFAULT_RESTAURANT_RATING_REWARD_LEVEL = 0
local RESTAURANT_PRAISE_DATA_KEY = "restaurantPraiseData"
local RESTAURANT_PRAISE_TARGET_NUM_KEY = "restaurantPraiseTargetNum"
local RESTAURANT_PRAISE_TARGET_NUM_STR_KEY = "restaurantPraiseTargetNumStr"
local RESTAURANT_PRAISE_GUIDE_TARGET_NUM_KEY = "restaurantPraiseGuideTargetNum"
local RESTAURANT_PRAISE_POWER_META_LIST_KEY = "restaurantPraisePowerMetaList"
local RESTAURANT_PRAISE_REWARD_META_LIST_KEY = "restaurantPraiseRewardMetaList"
local LAUNCHER_POWER_META_LIST_KEY = "launcherPowerMetaList"
local DEFAULT_RESTAURANT_PRAISE_TARGET_NUM = 12
local DEFAULT_RESTAURANT_PRAISE_GUIDE_TARGET_NUM = 3
local VIDEO_REMAIN_INFO_KEY = "spring2025MainBVideoRemainInfo"

local function safeToNumber(value, default)
	if value == nil then return default end
	return tonumber(value) or default
end

local MergeModel = class("MergeManager_data", BaseFeatureModel)

function MergeModel:_getConstPath()
    return LOCAL_PATH..'.config.MergeConfig'
end

function MergeModel:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "merge_data"
    }):as("db")

	self:installPlug(AMFDataPlugsType.SYNC, {
        requests = {
            activityAction = "amf.feature.localactivity.merge.http.RequestActivityAction",
        }
    })
end

function MergeModel:requestNotShowToday(isFlow)
	local actionStr = "energyOrBuffNotShowToday"
	if isFlow then
		actionStr = "notShowToday"
	end
	self.syncPlug:requestActivityAction({
        actId = Meta.actId,
        action = actionStr,
    })
end

-- MergeModel
function MergeModel:__declare()
    self:_initLocalData()
    self:_initLocalConfig()
    self:_initLocalKey()
end

function MergeModel:_initLocalData()
    self.updateDataTime = nil
    self.userData = nil
    self.beginTime = nil
    self.endTime = nil
    self.mainBeginTime = nil
    self.mainEndTime = nil
    self.restaurantRatingData = nil
    self.restaurantPraiseData = nil
    self.spring2025MainBVideoRemainInfo = nil
end

function MergeModel:_initLocalConfig()
    self.localConfig = nil
end

function MergeModel:_initLocalKey()
    -- self.savePopCongraKey = nil
    self.MainPanelOpenTimes = nil
    self.ignoreGiftPanel = nil
    self.ignoreEnergyNotEnoughGiftPanel = nil
    self.popStage4GiftTime = nil
    self.popMainGiftTime = nil
    self.popedGiftList = nil
    self.restaurantRatingPanelSnapshot = nil
    self.restaurantRatingLightGuideDay = nil
    self.userEnergy = nil
    self.Merge_powerTotal = nil
    self.order_complete_info = nil
	self.MergeAct_ProgressAwardMaxGroupRank = nil
	self.todayTryOpenPreheatGetReward = nil
	self.saoGuangFlag = nil
	self.saoGuangCnt = nil
	self.MergetAct_orderHistory = nil
	self.EnergyNotEnoughPopCnt = nil
	self.dailyShowGiftTipKey = nil
	self.pop_bubble_discount_panel = nil
	self.end_soon_tip_pop = nil
	self.praise_feedback_half_tip_round = nil
	self.praise_feedback_full_tip_round = nil
	self.goodGiftCompletedOrderCount = nil
	self.goodGiftTriggerResult1 = nil
	self.goodGiftTriggerResult2 = nil
	self.goodGiftTriggerResult3 = nil
	self.goodGiftEndingState = nil

	local allItemList = BoardMeta:getAllItemList(  )
	for i,v in ipairs(allItemList) do
		self["show_max_item_tip_"..v] = nil
	end
	
    self.MergeAct2024_rankTapped = nil
	self.nationDailyDrainPop = nil
	self.strength_pk_last_value = nil
	self.passLevelSuccessTime = nil
	self.strength_pk_last_rank =nil
	self.strength_pk_last_round = nil
	self.OpenEggWeekIdx1 = nil
	self.OpenEggWeekIdx2 = nil
	self.OpenEggWeekIdx3 = nil
	self.merge_act_second_confirm_panel = nil
	self.pop_buy_tujian_half = nil
	self.pop_buy_jindu_half_gift = nil
	self.pop_buy_jindu_full_gift = nil
	self.yinLiuPopCnt = nil
	self.lastTotalMoney = nil
	self.pop_buy_energy_gift_round = nil
	self.show_national_rank_reward = nil
	self._3zh2NationDailyPoped = nil
	self.newYearFoodOrderData = nil
	self.newYearFoodOrderPoped = nil
	self.circleEndLessRound = nil
	self.OpenEggGiftNotice = nil

	self.canyuHadDC = nil
	self.joinHadDC = nil
	self.Merge_power_full_pop_tip = nil
	self.popedGiftListnew = nil

	self.robotCollcetLastNum1 = nil
	self.robotCollcetLastNum2 = nil
	self.robotCollcetLastNum3 = nil
	self.robotCollcetLastNum4 = nil
	self.myCollcetLastNum = nil

	self.iconTipKing_30 = nil
	self.iconTipKing_60 = nil
	self.chickenTip = nil
	self.Merge_powerMultiplier = nil
end

function MergeModel:passDayClear()
    -- 跨天
    self:setDataByKey("todayRewardLuckyBagKeys", {})
end

function MergeModel:clearLocalData()

	self:setValue("updateDataTime", nil)
	self:setValue("userData", nil)
	self:setValue("beginTime", nil)
	self:setValue("endTime", nil)
	self:setValue("mainBeginTime", nil)
	self:setValue("mainEndTime", nil)

	self:setValue("localConfig", nil)
end

function MergeModel:fromLocalChangeEnd()
	--加一个跨天判断 
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

function MergeModel:fromServer(data, config)
    -- 从活动info 发来的信息拆分出 data 和 localConfig
    -- userData是后端数据，self.data.xxx可以自行添加不会覆盖删除

    if table.isEmpty(data) then
    	--清空数据
	    self:clearLocalData()
    else
	    for k, v in pairs(data) do
	        self:setValue(k, v)
	    end
	end

    if config and not table.isEmpty(config) and config.config ~= '' then
        config.config = table.deserialize(config.config)
        self:setValue("localConfig", config)
    end
    
    -- printx(12,'fromServer',tts(self:getValue("userData")),tts(self:getValue("localConfig")))

    self:flush()
end

function MergeModel:getConfig()
    local localConfig = self:getValue("localConfig")
    if localConfig and localConfig.config then
        return localConfig.config
    end

    return {}
end

-- 获取data 设置data值  数字类型的增加
function MergeModel:getDataByKey(key, default)
    local value = self:getValue(key)
    if value then
        return value
    end

    local userData = self:getValue("userData")
    if userData and userData[key] ~= nil then
        return userData[key]
    end

    return default
end

function MergeModel:setDataByKey(key, value, needSave)
    local userData = self:getValue("userData")

    if userData and userData[key] ~= nil then
        userData[key] = value
        self:setValue("userData", userData, needSave)
    end
end

function MergeModel:setDataByKeyIgnoreNil(key, value, needSave)
    local userData = self:getValue("userData")

    if userData then
        userData[key] = value
        self:setValue("userData", userData, needSave)
    end
end

function MergeModel:addDataByKey(key, value)
    local userData = self:getValue("userData")
    if userData and type(userData[key]) == 'number' then
        userData[key] = userData[key] + value
        self:setValue("userData", userData, true)
    end
end

function MergeModel:setExDataByKey(key, value, needSave)
    self:setValue(key, value, needSave)
end

-- 获取配置
function MergeModel:getConfigByKey(key)
    local config = self:getConfig()
    if config and config[key] then
        return config[key]
    end
end

function MergeModel:getFrozenFoodData()
    -- 冰冻棋子动态数据来自 fromServer.userData.frozenFoodData。
    return self:getDataByKey("frozenFoodData") or {}
end

function MergeModel:setFrozenFoodData(frozenFoodData, needSave)
    self:setDataByKeyIgnoreNil("frozenFoodData", frozenFoodData or {}, needSave)
end

function MergeModel:getVideoRemainInfo()
    return self:getDataByKey(VIDEO_REMAIN_INFO_KEY) or {}
end

function MergeModel:updateVideoRemainInfo(videoRemainInfo, needSave)
    self:setDataByKeyIgnoreNil(VIDEO_REMAIN_INFO_KEY, videoRemainInfo or {}, needSave)
end

function MergeModel:getPowerVideoRemainInfo()
    local info = self:getVideoRemainInfo()
    return {
        remainCount = safeToNumber(info.powerRemainCount, 0),
        maxCount = safeToNumber(info.powerMaxCount, 0),
        rewardPower = safeToNumber(info.rewardPower, 0),
    }
end

function MergeModel:getOrder2VideoRemainInfo()
    local info = self:getVideoRemainInfo()
    return {
        dailyRemainCount = safeToNumber(info.order2DailyRemainCount, 0),
        dailyMaxCount = safeToNumber(info.order2DailyMaxCount, 0),
        remainCount = safeToNumber(info.order2RemainCount, 0),
        remainCdSecond = safeToNumber(info.order2RemainCdSecond, 0),
        cdTime = safeToNumber(info.order2CdTime, 0),
    }
end

function MergeModel:getFrozenFoodPhase()
    -- 单格只保存 kFrozen 状态，1/2 阶段统一由 frozenFoodData.phase 区分。
    local frozenFoodData = self:getFrozenFoodData()
    return tonumber(frozenFoodData.phase) or 0
end

function MergeModel:getFrozenFoodBuyPowerGoodsIdSet()
    -- 后端未触发/未配置时可能不下发该集合；调用方统一按空表处理。
    return self:getConfigByKey("frozenFoodBuyPowerGoodsIdSet") or {}
end

function MergeModel:checkFrozenFoodBuyPowerGoods(goodsId)
    local goodsHolder = self:getFrozenFoodBuyPowerGoodsIdSet()
    if not goodsId or type(goodsHolder) ~= "table" then
        return false
    end

    if goodsHolder[goodsId] or goodsHolder["" .. goodsId] then
        return true
    end

    for _, v in pairs(goodsHolder) do
        if v == goodsId or tostring(v) == tostring(goodsId) then
            return true
        end

        if type(v) == "table" then
            local holderGoodsId = v.goodsId or v.id
            if holderGoodsId == goodsId or tostring(holderGoodsId) == tostring(goodsId) then
                return true
            end
        end
    end

    return false
end

function MergeModel:getGuides()
    -- 引导标记
    return self:getDataByKey('guideIdSet') or {}
end

function MergeModel:addGuides(index)
    -- 添加引导标记

    local guideInfo = self:getDataByKey('guideIdSet')
    table.insert(guideInfo, index)
    self:setDataByKey('guideIdSet', guideInfo, true)

    self:flush()
end

function MergeModel:checkGuide(index)
    -- 检查引导标记
    local guideInfo = self:getDataByKey('guideIdSet') or {}

    return table.exist(guideInfo, index)
end

function MergeModel:setGuideIndex(index)
    self:addGuides(index)

    local ActCommonHttp = require("amf.middleware.activity.http.ActCommonHttp")
    ActCommonHttp:setActGuideFlag(_G.amfBean("MergeManager").ACT_ID, index)
end


-------------------------------


function MergeModel:getActivityLimitGoodIds()
	local activityLimitGoodIds = self:getDataByKey('activityLimitGoodIds')
	return activityLimitGoodIds
end

function MergeModel:addActivityLimitGoodsHadBuy( goodsId )
	--添加活动期限购礼包
	local activityLimitGoodIds = self:getActivityLimitGoodIds()
	if not table.exist(activityLimitGoodIds, goodsId) then
		table.insert( activityLimitGoodIds, goodsId )
	end
	self:setDataByKey('activityLimitGoodIds', activityLimitGoodIds)
end

function MergeModel:checkActivityLimitGoodsHadBuy( goodsId )
	--检测活动期限购礼包是否已购买
	local activityLimitGoodIds = self:getActivityLimitGoodIds()
	return table.exist(activityLimitGoodIds, goodsId)
end


function MergeModel:getOrderSize()
	local orderSize = self:getDataByKey('orderSize')
	return orderSize
end


function MergeModel:getPayTag()
	local payTag = self:getDataByKey('payTag')
	return payTag
end

function MergeModel:getFinishOrderNum()
	local finishOrderNum = self:getDataByKey('finishOrderNum')
	return finishOrderNum
end

function MergeModel:getFoodOrders()
	local foodOrders = self:getDataByKey('foodOrders')
	return foodOrders
end

-- 更新皇帝订单信息
function MergeModel:updateKingOrderInfo(orderInfo)
	self:setDataByKeyIgnoreNil('kingOrderData', orderInfo)
end 

-- 获取皇帝订单信息
function MergeModel:getKingOrderInfo()
	local kingOrderData = self:getDataByKey('kingOrderData')
	if kingOrderData  then
		local endTime = tonumber(kingOrderData.endTime) or 0
		if kingOrderData.orderIndex == -1 then
			return nil
		end
	end
	return kingOrderData
end

function MergeModel:setKingOrderAnimComplete()
	local kingOrderData = self:getKingOrderInfo()
	kingOrderData.cannotClose = false
	self:updateKingOrderInfo(kingOrderData)
end

-- 获取皇帝订单信息, 已激活未到期才返回数据
function MergeModel:getActiveKingOrderInfo()
	local kingOrderData = self:getDataByKey('kingOrderData')
	local curTime = TimeKit:timeInMillis()
	if kingOrderData  then
		local endTime = tonumber(kingOrderData.endTime) or 0
		if kingOrderData.orderIndex == -1 then
			return nil
		elseif curTime > endTime then
			return nil
		end
	end
	return kingOrderData
end

-- 今日是否触发过皇帝订单
function MergeModel:checkTodayIsHadActKingOrder()
	local kingOrderData = self:getDataByKey('kingOrderData')
	local curTime = TimeKit:timeInMillis()
	if kingOrderData  then
		local endTime = tonumber(kingOrderData.endTime) or 0
		if kingOrderData.orderIndex == -1 then
			return false
		elseif curTime > endTime and time2day(curTime/1000) ~= time2day(endTime/1000) then
			return false
		else 
			return true
		end
	end

	return false
end

function MergeModel:getKingOrderItemList()
	local kingOrderData = self:getActiveKingOrderInfo()

	if not kingOrderData then
		return {}
	end

	--开启后获取要展示的订单， 如果是0,取数组1的
	local curIndex = kingOrderData.orderIndex + 1
    local orderData = kingOrderData.orderDataList[curIndex] or {}
	return orderData.foodIds or {}
end

function MergeModel:checkItemIsKingOrderItem( itemId )
	local itemList = self:getKingOrderItemList()
	return table.exist(itemList,itemId)
end

-- 保存协议回包中的好礼订单 Bean；只覆盖服务端明确返回的数据，不在客户端推进订单状态。
function MergeModel:updateGoodGiftOrderInfo(orderInfo)
	self:setDataByKeyIgnoreNil('goodGiftOrderData', orderInfo)
end

-- 返回服务端原始好礼订单 Bean，供活动业务层组装展示数据。
function MergeModel:getGoodGiftOrderInfo()
	return self:getDataByKey('goodGiftOrderData')
end

-- 返回今天已开启且尚未到截止时间的有效当前订单；毫秒 endTime 统一经 tonumber 归一化。
function MergeModel:getActiveGoodGiftOrderInfo()
	local orderInfo = self:getGoodGiftOrderInfo()
	if type(orderInfo) ~= 'table' then
		return nil
	end
	if not self:checkGoodGiftHasOpenedToday() then
		return nil
	end

	local orderIndex = orderInfo.orderIndex
	if type(orderIndex) ~= 'number'
		or orderIndex ~= math.floor(orderIndex)
		or orderIndex < 0
		or orderIndex >= 5 then
		return nil
	end
	local endTime = tonumber(orderInfo.endTime)
	if not endTime or TimeKit:timeInMillis() >= endTime then
		return nil
	end

	local orderDataList = orderInfo.orderDataList
	local currentOrder = type(orderDataList) == 'table' and orderDataList[orderIndex + 1]
	if type(currentOrder) ~= 'table'
		or type(currentOrder.foodIds) ~= 'table' then
		return nil
	end
	return orderInfo
end

-- 判断今天是否已经开启过一轮好礼；完成或过期仍返回 true，用于限制当天重复开启。
function MergeModel:checkGoodGiftHasOpenedToday()
	local orderInfo = self:getGoodGiftOrderInfo()
	return type(orderInfo) == 'table'
		and orderInfo.day == time2day(TimeKit:timeInSec())
end

-- 判断今天进行中的好礼订单是否已经到达截止时间；已完成、未开启或非法时间不算过期态。
function MergeModel:checkGoodGiftIsExpiredToday()
	local orderInfo = self:getGoodGiftOrderInfo()
	if not self:checkGoodGiftHasOpenedToday() then
		return false
	end
	local orderIndex = orderInfo.orderIndex
	if type(orderIndex) ~= 'number'
		or orderIndex ~= math.floor(orderIndex)
		or orderIndex < 0
		or orderIndex >= 5 then
		return false
	end
	local endTime = tonumber(orderInfo.endTime)
	return endTime ~= nil and TimeKit:timeInMillis() >= endTime
end

-- 返回 orderDataList 中当前 orderIndex 对应的订单；服务端下标从 0 开始，Lua 数组从 1 开始。
function MergeModel:getCurrentGoodGiftOrder()
	local orderInfo = self:getActiveGoodGiftOrderInfo()
	if not orderInfo then
		return nil
	end
	return orderInfo.orderDataList[orderInfo.orderIndex + 1]
end

-- 返回当前好礼订单的 foodIds 原始顺序，供订单标记、maker 和保护逻辑共同使用。
function MergeModel:getGoodGiftOrderItemList()
	local orderData = self:getCurrentGoodGiftOrder()
	if not orderData or type(orderData.foodIds) ~= 'table' then
		return {}
	end
	return orderData.foodIds
end

-- 判断指定棋子是否属于服务端当前好礼订单，不包含历史单和已完成轮次。
function MergeModel:checkItemIsGoodGiftOrderItem(itemId)
	return table.exist(self:getGoodGiftOrderItemList(), itemId)
end

-- 返回本地保存的当天真实订单完成数；缓存按服务器日期和当前活动批次隔离。
function MergeModel:getTodayGoodGiftCompletedOrderCount()
	return self:getFlagFromLocalByKeyInt('goodGiftCompletedOrderCount', true, true, 0)
end

-- 本地保存当天真实订单完成数；不写入服务端 perDayData，跨天或活动换批后自动失效。
function MergeModel:setTodayGoodGiftCompletedOrderCount(count)
	self:saveFlagToLocalByKeyInt('goodGiftCompletedOrderCount', true, count, true)
end

-- 返回当天指定订单数的好礼概率结果；-1 表示未计算，0 表示未命中，1 表示命中。
function MergeModel:getTodayGoodGiftTriggerResult(orderCount)
	return self:getFlagFromLocalByKeyInt('goodGiftTriggerResult' .. orderCount, true, true, -1)
end

-- 保存当天指定订单数的好礼概率结果；缓存按服务器日期和当前活动批次隔离。
function MergeModel:setTodayGoodGiftTriggerResult(orderCount, result)
	self:saveFlagToLocalByKeyInt('goodGiftTriggerResult' .. orderCount, true, result, true)
end

-- 从单一本地字符串读取好礼结束提示状态，统一维护待弹日期和已展示日期。
local function getGoodGiftEndingState(model)
	local raw = model:getFlagFromLocalByKeyStr('goodGiftEndingState', false, true)
	return table.deserialize(raw or '') or {}
end

-- 将好礼结束提示状态整体写回本地，避免多个独立 key 产生组合状态。
local function saveGoodGiftEndingState(model, state)
	model:saveFlagToLocalByKeyStr('goodGiftEndingState', false, table.serialize(state), true)
end

-- 返回好礼结束提示的待弹日期；0 表示当前没有待弹记录。
function MergeModel:getGoodGiftEndingPendingDay()
	return getGoodGiftEndingState(self).pendingDay or 0
end

-- 保存好礼结束提示的待弹日期，供当天返回主面板后继续消费。
function MergeModel:setGoodGiftEndingPending(day)
	local state = getGoodGiftEndingState(self)
	state.pendingDay = day
	saveGoodGiftEndingState(self, state)
end

-- 判断好礼结束提示今天是否已经展示，避免同一轮结束重复强弹。
function MergeModel:checkGoodGiftEndingShownToday()
	return getGoodGiftEndingState(self).shownDay == time2day(TimeKit:timeInSec())
end

-- 在结束提示实际初始化完成时标记今天已展示，并清除待弹记录。
function MergeModel:markGoodGiftEndingShownToday()
	local state = getGoodGiftEndingState(self)
	state.shownDay = time2day(TimeKit:timeInSec())
	state.pendingDay = 0
	saveGoodGiftEndingState(self, state)
end

-- 返回好礼连连独立配置根节点；配置缺失时返回 nil，不使用旧字段或默认配置兜底。
function MergeModel:getGoodGiftConfig()
	return self:getConfigByKey('merge2026GoodGiftConfig')
end

-- 返回服务端配置的好礼连连首次开启最小钞票数；字段缺失时由活动侧 Meta 兜底。
function MergeModel:getGoodGiftOpenMoneyMin()
	local goodGiftConfig = self:getGoodGiftConfig()
	return goodGiftConfig and goodGiftConfig.openMoneyMin
end

-- 返回服务端配置的好礼连连开启体力上限；字段缺失时由活动侧 Meta 兜底。
function MergeModel:getGoodGiftOpenPowerMax()
	local goodGiftConfig = self:getGoodGiftConfig()
	return goodGiftConfig and goodGiftConfig.openPowerMax
end

-- 返回好礼连连订单配置列表；列表中的 orderIndex 使用配置口径 1..5。
function MergeModel:getGoodGiftOrderMetaList()
	local goodGiftConfig = self:getGoodGiftConfig()
	return goodGiftConfig and goodGiftConfig.goodGiftOrderMetaList
end

-- 按配置 orderIndex 1..5 查询订单配置；1..4 仅允许 difficulty=0，第 5 单必须提供难度且不隐式转换运行态下标。
function MergeModel:getGoodGiftOrderMeta(orderIndex, difficulty)
	if type(orderIndex) ~= 'number'
		or orderIndex ~= math.floor(orderIndex)
		or orderIndex < 1
		or orderIndex > 5 then
		return nil
	end

	local targetDifficulty = difficulty
	if orderIndex < 5 then
		if targetDifficulty == nil then
			targetDifficulty = 0
		elseif targetDifficulty ~= 0 then
			return nil
		end
	end
	if type(targetDifficulty) ~= 'number'
		or targetDifficulty ~= math.floor(targetDifficulty) then
		return nil
	end

	local metaList = self:getGoodGiftOrderMetaList()
	if type(metaList) ~= 'table' then
		return nil
	end

	for _, orderMeta in ipairs(metaList) do
		if orderMeta.orderIndex == orderIndex
			and orderMeta.difficulty == targetDifficulty then
			return orderMeta
		end
	end
end

function MergeModel:getQueenMatchMeta(matchLevel)
	local metaList = self:getConfigByKey("cookMatchMetaList") or {}
	for i, v in ipairs(metaList) do
		if v.level == matchLevel then
			return v
		end
	end
	return nil
end

-- 排名奖励列表
function MergeModel:getRankRewardList(rank)
	local matchData = self:getQueenMatchInfo()
	if table.isEmpty(matchData) then return end
	local tmpRank = rank == 3 and 2 or rank
	if not table.isEmpty(matchData.rankRewardMap) and not table.isEmpty(matchData.rankRewardMap[tostring(tmpRank)]) then
		return matchData.rankRewardMap[tostring(tmpRank)]
	end
	local cfg = self:getQueenMatchMeta(matchData.matchLevel) or {}
	if rank == 1 then
		return cfg.firstRewardList or {}
	end
	return cfg.secondRewardList or {}
end

-- 需要获得第一名的次数
function MergeModel:getMatchLevelUp1stNeedCount(titleLevel)
	local metaList = self:getConfigByKey("cookMatchMetaList") or {}
	local count = 0
	for i, v in ipairs(metaList) do
		if v.titlelevel == titleLevel then
			count = count + 1
		end
	end
	return count
end

function MergeModel:getTitleLevelBy1stCount(num)
	local metaList = self:getConfigByKey("cookMatchMetaList") or {}
	local count = 0
	if num >= #metaList then
		return metaList[#metaList].titlelevel
	end
	for i, v in ipairs(metaList) do
		count = count + 1
		if count > num then
			return v.titlelevel
		end
	end
	return 1
end

-- 获得我当前titleLevel获得了几次第一名
function MergeModel:getHas1stNumByLevel(titleLevel, matchLevel)
	local metaList = self:getConfigByKey("cookMatchMetaList") or {}
	local count = 0
	for i, v in ipairs(metaList) do
		if v.titlelevel == titleLevel and matchLevel > v.level then
			count = count + 1
		end
	end
	return count
end

function MergeModel:getMatchTitleLevel(matchLevel)
	local meta = self:getQueenMatchMeta(matchLevel)
	return meta and meta.titlelevel
end

-- 更新甄嬛订单信息
function MergeModel:updateQueenOrderInfo(orderInfo)
	self:setDataByKeyIgnoreNil('queenOrderData', orderInfo)
end

-- 甄嬛订单
function MergeModel:getQueenOrder()
	local queenOrderData = self:getDataByKey('queenOrderData')
	if queenOrderData and queenOrderData.npcIndex == 0 then
		return nil
	end
	return queenOrderData
end

--更换npc
function MergeModel:changeQueenOrderNpc(npcIndex)
	local queenOrder = self:getQueenOrder()
	if queenOrder then
		queenOrder.npcIndex = npcIndex
		self:updateQueenOrderInfo( queenOrder )
	end
end

function MergeModel:getQueenOrderItemList()
	local queenOrderData = self:getQueenOrder()
	if not queenOrderData then
		return {}
	end
	local perOrderData = queenOrderData.perOrderData or {}
    return perOrderData.foodIds or {}
end

function MergeModel:checkItemIsQueenOrderItem( itemId )
	local itemList = self:getQueenOrderItemList()
	return table.exist(itemList,itemId)
end

-- 更新订单5信息
function MergeModel:updateTopFoodCleanOrderInfo(orderInfo)
	self:setDataByKeyIgnoreNil('topFoodCleanOrderData', orderInfo)
end

-- 订单5
function MergeModel:getTopFoodCleanOrder()
	local orderData = self:getDataByKey('topFoodCleanOrderData')
	if orderData and orderData.exist then
		return orderData
	end
	return nil
end

function MergeModel:getTopFoodCleanOrderItemList()
	local orderData = self:getTopFoodCleanOrder()
	if not orderData then
		return {}
	end

	local ret = {}
	for i, itemId in ipairs(orderData.foodIds or {}) do
		if itemId and itemId > 0 then
			table.insert(ret, itemId)
		end
	end
	return ret
end

function MergeModel:checkItemIsTopFoodCleanOrderItem(itemId)
	local itemList = self:getTopFoodCleanOrderItemList()
	return table.exist(itemList, itemId)
end

-- 后宫厨神赛结构
function MergeModel:getQueenMatchInfo()
	local matchData = self:getDataByKey('cookMatchData')
	-- 赋值titleLevel
	if not matchData.titleLevel then
		local titleLevel = self:getMatchTitleLevel(matchData.matchLevel)
		matchData.titleLevel = titleLevel
	end
	if matchData.rank == 0 then
		matchData.rank = self:getMatchMyRank()
	end
	return matchData
end

function MergeModel:getMatchMyRank()
	local list = self:getMatchRankSortList()
	for i, v in ipairs(list) do
		if v.isMe then
			return i
		end
	end
	return 5
end

function MergeModel:getMatchRankSortList()
	local matchData = self:getDataByKey('cookMatchData')
	local all0 = true
	local list = {}
    for i, v in ipairs(matchData.robotList or {}) do
        local t = {
            idx = i,
            collectNum = v.collectNum or 0,
			finishTime = tonumber(v.robotFinishTime) or 0, -- finishTime貌似全都一样的
			robotUid = tonumber(v.robotUid) or 0
        }
        if v.collectNum > 0 then
            all0 = false
        end
        table.insert(list, t)
    end
    if all0 then
		local tmp = {}
        table.insert(tmp, {
            isMe = true,
            collectNum = matchData.userCollectNum
        })
        if list[2] then
            table.insert(tmp, list[2])
        end
        if list[3] then
            table.insert(tmp, list[3])
        end
		if list[1] then
            table.insert(tmp, list[1])
        end
        if list[4] then
            table.insert(tmp, list[4])
        end
		list = tmp
    else
        table.sort(list, function(a, b)
			-- 收集物不相同，大的在前
			if a.collectNum ~= b.collectNum then
				return a.collectNum > b.collectNum  -- 收集数量多的排前面
			end
			-- 收集物相同判断时间, finishTime为更新时间
			if a.finishTime ~= b.finishTime then
				return a.finishTime < b.finishTime
			end
			-- 时间相同判断uid
			return a.robotUid < b.robotUid
        end)
        if (matchData.rank or 0) > 0 then
            table.insert(list, matchData.rank, {
                isMe = true,
                collectNum = matchData.userCollectNum
            })
        else
			local insert = false
            -- 需要自己算
            for i, v in ipairs(list) do
                if matchData.userCollectNum >= v.collectNum then
					insert = true
                    table.insert(list, i,  {
                        isMe = true,
                        collectNum = matchData.userCollectNum
                    })
                    break
                end
            end
			if not insert then
				table.insert(list,  {
					isMe = true,
					collectNum = matchData.userCollectNum
				})
			end
        end
    end
	return list
end

-- 更新后宫厨神信息
function MergeModel:updateQueenMatchInfo(mathInfo)
	self:setDataByKeyIgnoreNil('cookMatchData', mathInfo)
end

function MergeModel:isInLimitOrderTime()
	--是否在订单大比拼时间内
	local bOpen, configTb = self:checkStepIsOpen(Meta.StepTypes.kDailyPK)
	return bOpen
end

function MergeModel:limitOrderIsUnlock()
	-- 订单比拼是否解锁 应该判断什么时候不能显示
	-- 订单数不满足
	local finishOrderNum = self:getDataByKey("finishOrderNum")
	if finishOrderNum < Meta.creteExtraItemNeedCompleteNum then
		return false
	end

	-- 无data
    local limitOrderData = self:getNewYearFoodOrderData()
    if not next(limitOrderData) then
		return false
	end

	-- 时间不符合
	local bOpen, configTb = self:checkStepIsOpen(Meta.StepTypes.kDailyPK)
	if not bOpen then
		return false
	end

	return true
end

function MergeModel:normalOrderIsUnlock( orderIndex )
    local orderSize = self:getDataByKey("orderSize")
	return orderSize >= orderIndex
end

function MergeModel:canMakeExtraItem()
	--是否可以生成饺子
    local bOpen, openConfig = self:checkStepIsOpen(Meta.StepTypes.kDailyPK)
	if bOpen then
	    local finishOrderNum = self:getDataByKey("finishOrderNum")
		return finishOrderNum >= Meta.creteExtraItemNeedCompleteNum
	end

	return false
end

function MergeModel:checkItemIsOrderItem( itemId )
	--检测是否是普通订单道具
	local bOrderItem = false
	local orderIndex= 0

	local foodOrders = self:getFoodOrders()
	local orderSize = self:getOrderSize()
	-- printx(12,'foodOrders',tts(foodOrders))

	for i=1, orderSize do
		local v = foodOrders[i]
		local orderId = v.orderId
		local orderMeta = self:getOrderMetaByOrderId( orderId )
		local needItemList = orderMeta.needItemList
		local orderShowItem = orderMeta.orderShowItem

		if i == 2 then
			bOrderItem = orderShowItem == itemId
		else
			if orderMeta.randomTopFood then
				bOrderItem = v.randomNeedFoodId == itemId
			else
				local index = table.indexOf( needItemList, itemId )
				if index then
					bOrderItem = true
				end
			end
		end

		if bOrderItem then
			orderIndex = i
			break
		end
	end

	return bOrderItem, orderIndex
end

function MergeModel:getNormalOrderByIndex( orderIndex )
	--获取对应位置的道具需要
	local foodOrders = self:getFoodOrders()
	local orderInfo = foodOrders[orderIndex]
	if orderInfo then
		local orderId = orderInfo.orderId

		local orderMeta = self:getOrderMetaByOrderId( orderId )
		if orderMeta.randomTopFood then
			return true, {orderInfo.randomNeedFoodId}
		end
		return true, orderMeta.needItemList
	else
		return false, {}
	end
end

function MergeModel:getNormalOrderInfoByIndex( orderIndex )
	--获取对应位置的订单信息，道具需要
	local foodOrders = self:getFoodOrders()
	local orderInfo = foodOrders[orderIndex]
	if orderInfo then
		local orderId = orderInfo.orderId

		local orderMeta = self:getOrderMetaByOrderId( orderId )
		if orderMeta.randomTopFood then
			return true, orderInfo, {orderInfo.randomNeedFoodId}
		end
		return true, orderInfo, orderMeta.needItemList
	else
		return false, {}
	end
end

function MergeModel:updateMachineOrderInfo( orderInfo )
	--更新order2信息
	local foodOrders = self:getFoodOrders()
	foodOrders[2] = orderInfo
	self:setDataByKey('foodOrders',foodOrders)
end

function MergeModel:getMachineOrder()
	--获取机器任务
	local foodOrders = self:getFoodOrders()
	return foodOrders[2]
end

function MergeModel:getMachineOrderAllInput()
	--获取机器任务是否都填入了
	local machineOrder = self:getMachineOrder()
	local orderStatus = machineOrder.orderStatus
	local bAllInput = true
	for i,v in ipairs(orderStatus) do
		if v == false then
			bAllInput = false
			break
		end
	end
	return bAllInput
end

function MergeModel:updateMachineOrderEndTime( endTime )
	--更新机器任务时间
	local foodOrders = self:getFoodOrders()
	local machineOrder = foodOrders[2]
	machineOrder.orderFinishTime = endTime
	self:setDataByKey('foodOrders', foodOrders)
end

function MergeModel:getMachineOrderInfo()
	--获取机器信息
	local machineOrder = self:getMachineOrder()
	local orderId = machineOrder.orderId
	local orderStatus = machineOrder.orderStatus
	local orderFinishTime = machineOrder.orderFinishTime

	local orderMeta = self:getOrderMetaByOrderId(orderId)
	local needItemList = orderMeta.needItemList
	local showItemId = orderMeta.orderShowItem

	local bAllInput = self:getMachineOrderAllInput()

	local curTime = TimeKit:timeInSec()
	local bInCdTime = false
	local bCanGetReward = false

	local endTime = math.floor( tonumber(orderFinishTime)/1000 )
	if bAllInput then
		if curTime < endTime then
			bInCdTime = true
		else
			bCanGetReward = true
		end
	end

	local params = {
		orderId = orderId,
		endTime = endTime,
		orderStatus = orderStatus,
		needItemList = needItemList,
		showItemId = showItemId,
		bInCdTime = bInCdTime,
		bAllInput = bAllInput,
		bCanGetReward = bCanGetReward,
	}
	return params
end

function MergeModel:checkIsMachineNeedItem( itemId )
	--检测是否是小鸡需要的道具，并且没有填入
	local orderInfo = self:getMachineOrderInfo()

	local needItemList = orderInfo.needItemList
	local orderStatus = orderInfo.orderStatus

	local bNeedItem = false
	local bHadInsert = false
	if table.exist( needItemList, itemId ) then
		bNeedItem = true
		local index = table.indexOf( needItemList, itemId )
		if index and orderStatus[index] then
			bHadInsert = true
		end
	end
	return bNeedItem, bHadInsert

end

function MergeModel:tryInsertMachineNeedItem( itemId )
	--给小鸡所需道具
	local foodOrders = self:getFoodOrders()
	local orderId = foodOrders[2].orderId
	local orderStatus = foodOrders[2].orderStatus
	local orderFinishTime = foodOrders[2].orderFinishTime

	local orderMeta = self:getOrderMetaByOrderId(orderId)
	local needItemList = orderMeta.needItemList

	if table.exist( needItemList, itemId ) then
		local index = table.indexOf( needItemList, itemId )
		if index and orderStatus[index] ~= nil then
			orderStatus[index] = true
			self:setDataByKey('foodOrders', foodOrders)
			return true, index
		end
	end
	return false, 0
 end

function MergeModel:getLimitOrderInfo()
	local limitFoodOrder = self:getDataByKey('limitFoodOrder')
	return limitFoodOrder
end

function MergeModel:updateLimitOrderInfo( limitFoodOrder )
	local curLimitFoodOrder = self:getDataByKey("limitFoodOrder")

	self:setDataByKeyIgnoreNil("limitFoodOrder", limitFoodOrder)

end

-- 设置订单pk已结算
function MergeModel:updateLimitOrderPkReward()
	local limitFoodOrder = self:getDataByKey("limitFoodOrder")
	if limitFoodOrder and next(limitFoodOrder) and self:isCurPKDataWin(limitFoodOrder) then
		limitFoodOrder.pkReward = true
		self:setDataByKey("limitFoodOrder", limitFoodOrder)
	end
end

-- 设置订单预热进度已结算
function MergeModel:updateLimitOrderProgressReward()
	local limitFoodOrder = self:getDataByKey("limitFoodOrder")
	if limitFoodOrder and next(limitFoodOrder) and limitFoodOrder.finishIndex >= 2 and not limitFoodOrder.progressReward then
		limitFoodOrder.progressReward = true
		self:setDataByKey("limitFoodOrder", limitFoodOrder)
	end
end

function MergeModel:checkItemIsLimitOrderItem( itemId )
	--检测是否是限时订单道具
	local bOrderItem = false
	local orderIndex = 0

	local isInLimitOrderTime = self:isInLimitOrderTime()
	local limitFoodOrder = self:getLimitOrderInfo()
	if limitFoodOrder and isInLimitOrderTime then
		local finishIndex = limitFoodOrder.finishIndex
		local orderIds = limitFoodOrder.orderIds
		if finishIndex >= #orderIds then
			return false, orderIndex
		end

		if not orderIds[finishIndex+2] then
			return false, orderIndex
		end

		local orderId = orderIds[finishIndex+2]
		local orderMeta = self:getYearOrderMetaByOrderId( orderId )
		local needItemList = orderMeta.needItemList
		local specialItemId = limitFoodOrder.specialItemIds[finishIndex+2]
		local orderShowItem = orderMeta.orderShowItem

		-- printx(12,"checkItemIsLimitOrderItem itemId",itemId, orderId)
		-- printx(12,"checkItemIsLimitOrderItem orderMeta",tts(orderMeta))
		-- printx(12,"checkItemIsLimitOrderItem specialItemId",specialItemId)
		-- printx(12,"checkItemIsLimitOrderItem limitFoodOrder",tts(limitFoodOrder))

		if orderShowItem ~= 0 then
			bOrderItem = orderShowItem == itemId
		else
			local index = table.indexOf( needItemList, itemId )
			if index then
				bOrderItem = true
				orderIndex = finishIndex+2
			end

			if specialItemId == itemId then
				bOrderItem = true
				orderIndex = finishIndex+2
			end
		end
	end

	return bOrderItem, orderIndex
end

function MergeModel:checkLimitOrderHadGetReward()
	--限时订单是否都已领取
	local limitFoodOrder = self:getLimitOrderInfo()
	if limitFoodOrder then
		return limitFoodOrder.progressReward
	else
		return false
	end
end

function MergeModel:checkLimitOrderIsComplete()
	--检测限时订单是否都完成
	local limitFoodOrder = self:getLimitOrderInfo()
	if limitFoodOrder and limitFoodOrder.finishIndex+1 == #limitFoodOrder.orderIds then
		return true
	end
	return false
end

function MergeModel:getLimitOrderTarget()
	--获取限时订单目标
	local bComplete = self:checkLimitOrderIsComplete()
	if not bComplete then
		local limitFoodOrder = self:getLimitOrderInfo()
		if limitFoodOrder then
			local orderId = limitFoodOrder.orderIds[limitFoodOrder.finishIndex+2]
            if orderId then
                local orderMeta = self:getYearOrderMetaByOrderId( orderId )
                return true, orderMeta.needItemList
            end
		end
	end

	return false, {}
end

function MergeModel:getLimitOrderSpecialTarget()
	--获取限时订单特殊目标
	local bComplete = self:checkLimitOrderIsComplete()
	if not bComplete then
		local limitFoodOrder = self:getLimitOrderInfo()
		if limitFoodOrder then
			local specialItemIds = limitFoodOrder.specialItemIds
			local targetId = specialItemIds[limitFoodOrder.finishIndex+2]
            return true, targetId
		end
	end

	return false, {}
end

function MergeModel:checkCanGetLimitOrderReward()
	--是否可以领取限时订单奖励，完成并且未领取
	local bComplete = self:checkLimitOrderIsComplete()
	local bGetReward = self:checkLimitOrderHadGetReward()

	return bComplete and not bGetReward
end

function MergeModel:getTravelChick()
	local travelChick = self:getDataByKey('travelChick')
	return travelChick
end

function MergeModel:checkCanGetMatchReward()
	local matchInfo = self:getQueenMatchInfo()
	if not matchInfo then return end
	if matchInfo.hasRankReward or matchInfo.hasUpLevelReward then
		return true
	end
	return false
end

function MergeModel:updateTravelChick( travelChick )
	self:setDataByKey('travelChick', travelChick )
end

function MergeModel:setTravelChickBackTime( backTime )
	local travelChick = self:getDataByKey('travelChick')
	travelChick.backTime = backTime
	self:updateTravelChick(travelChick)
end

function MergeModel:setTravelChickBackRewards( backRewardList )
	local travelChick = self:getDataByKey('travelChick')
	travelChick.backRewardList = backRewardList
	self:updateTravelChick(travelChick)
end

function MergeModel:updateChickenBackTime( backTime )
	local travelChick = self:getTravelChick()
	travelChick.backTime = backTime
	self:updateTravelChick(travelChick)
end

function MergeModel:checkIsChickenNeedItem( itemId )
	--检测是否是小鸡需要的道具，并且没有填入
	local travelChick = self:getTravelChick()

	local needItemIds = travelChick.needItemIds

	local bNeedItem = false
	local bHadInsert = false
	if table.exist( needItemIds, itemId ) then
		bNeedItem = true
		local index = table.indexOf( needItemIds, itemId )
		if index and travelChick.status[index] then
			bHadInsert = true
		end
	end
	return bNeedItem, bHadInsert

end

function MergeModel:tryInsertTravelNeedItem( itemId )
	--给小鸡所需道具
	local travelChick = self:getTravelChick()

	local needItemIds = travelChick.needItemIds
	if table.exist( needItemIds, itemId ) then
		local index = table.indexOf( needItemIds, itemId )
		if index and travelChick.status[index] ~= nil then
			travelChick.status[index] = true
			self:updateTravelChick(travelChick)
			return true, index
		end
	end
	return false, 0
 end

function MergeModel:checkChickenIsTraval()
	--小鸡是否出门了， 全部填上了，并且没有获取到回归奖励
	local travelChick = self:getTravelChick()

	local curTime = TimeKit:timeInSec()*1000
	local endTime = tonumber(travelChick.backTime)

	local bAllInput = true
	for i,v in ipairs(travelChick.status) do
		if  v == false then
			bAllInput = false
			break
		end
	end

	if bAllInput and #travelChick.backRewardList == 0 then
		return true
	end

	return false
end

function MergeModel:checkChickenIsTravalAndNoFinish()
	--小鸡是否出门了，并且还在cd中. 就可以买了
	local travelChick = self:getTravelChick()

	local curTime = TimeKit:timeInSec()*1000
	local endTime = tonumber(travelChick.backTime)

	local isTraval = self:checkChickenIsTraval()

	if isTraval and curTime < endTime then
		return true
	end

	return false
end

function MergeModel:checkChickenIsTravalAndFinish()
	--小鸡是否出门了，并且已经完成了
	local travelChick = self:getTravelChick()
	if not travelChick then
		-- printx(42, "travelChick不存在")
		return false
	end

	local curTime = TimeKit:timeInSec()*1000
	local endTime = tonumber(travelChick.backTime)

	local isTraval = self:checkChickenIsTraval()

	if isTraval and curTime >= endTime and endTime > 0 then
		return true
	end

	return false
end

function MergeModel:checkCanGetTravalReward()
	--是否可以领小鸡奖励, 有backRewardList
	local travelChick = self:getTravelChick()
	if not travelChick then
		return false
	end
	if #travelChick.backRewardList > 0 then
		return true
	end

	return false
end

function MergeModel:checkChickIsUnlock()
	--鸡是否解锁
	local bUnlock = false
	local money = self:getMoney()
	local bGetSucess, bNeedNum = self:getProgressSpecialItemUnlockNeedNum(BoardMeta.Chicken)
	if bGetSucess then
		return money >= bNeedNum, bNeedNum
	end
	return false, 0
end

function MergeModel:checkMachineIsUnlock()
	--机器是否解锁
	local bUnlock = false
	local money = self:getMoney()
	local finishOrderNum = self:getFinishOrderNum()
	local needCompleteNum = Meta.unlockOrder2NeedCompleteNum
	local bGetSucess, bNeedNum = self:getProgressSpecialItemUnlockNeedNum(BoardMeta.Machine)
	if bGetSucess then
		local bUnlock = (money >= bNeedNum ) -- 去掉完成数量判断，and (finishOrderNum >= needCompleteNum)
		return bUnlock, bNeedNum
	end
	return bUnlock, 0
end

function MergeModel:getMoney()
	local money = self:getDataByKey('money')
	return money
end

function MergeModel:addOrCostMoney( addNum )
	self:addDataByKey('money', addNum )
end

function MergeModel:getPowerTotal()
	local powerTotal = self:getDataByKey('powerTotal')
	return powerTotal
end

-- 获取无限体力结束时间
function MergeModel:getInfPowerEndTime()
	local infPowerEndTime = self:getDataByKey('infinitePowerEndTime') or '0'
	return tonumber(infPowerEndTime)
end

function MergeModel:addInfPowerEndTime( addTimeSec )
	--增加无限体力时间
	local infPowerEndTime = self:getInfPowerEndTime()
	local curTime = TimeKit:timeInSec()*1000
	if curTime < infPowerEndTime then
		infPowerEndTime = infPowerEndTime + addTimeSec*1000
	else
		infPowerEndTime = curTime + addTimeSec*1000
	end
	self:setDataByKey('infinitePowerEndTime', ''..infPowerEndTime)
end

-- 是否无限体力
function MergeModel:isInfPower()
	return self:getInfPowerEndTime() > TimeKit:timeInSec()*1000
end

function MergeModel:addOrCostPower( addNum )
	local powerTotal = self:getDataByKey('powerTotal')
    if addNum < 0 then
        self:addPKCostPower(addNum)
        _G.amfBean("MergeManager"):addUserEnergy(-addNum)
    end
	local newNum = powerTotal + addNum
	-- 记录一个小于30体力的power值用于弹出体力已满tip
	if newNum < self:getPowerTipPowerConfig() then
		_G.amfBean("MergeManager"):saveFlagToLocalByKeyInt("Merge_powerTotal", false, newNum)
	end
	-- 体力减少到60以下，更新体力心跳时间
	local autoAddMaxPowerConfig = self:getAutoAddMaxPowerConfig()
	if powerTotal >= autoAddMaxPowerConfig and newNum < autoAddMaxPowerConfig then
		self:updateLastPowerTickTime()
	elseif self:getLastPowerTickTime() <= 0 then
		-- 开始第一次发射
		self:updateLastPowerTickTime()
	end
	newNum = math.min(Meta.MaxPowerConfig, newNum)
	self:setDataByKey('powerTotal', newNum )
end

function MergeModel:getLastPowerTickTime()
	local lastPowerTickTime = self:getDataByKey('lastPowerTickTime')
	return tonumber(lastPowerTickTime)
end

function MergeModel:updateLastPowerTickTime()
	local lastPowerTickTime = TimeKit:timeInSec()*1000
	self:setDataByKey('lastPowerTickTime',lastPowerTickTime)
end

function MergeModel:getChartMap()
	local chartMap = self:getDataByKey('chartMap')
	return chartMap
end

function MergeModel:unlockChart( itemId )
    if itemId and tonumber(itemId) == 0 then return end
    if table.exist(BoardMeta.noJoinTuJianItemIds, itemId ) then return end

	--解锁图鉴
	local chartMap = self:getChartMap()
	if chartMap[''..itemId] == nil then
		chartMap[''..itemId] = false
        self:checkGetSingleTypeChart(itemId)
		self:setDataByKey('chartMap',chartMap)
	end
end

function MergeModel:checkGetSingleTypeChart(itemId)
    local itemData = BoardMeta:getItemDataByItemId(itemId)
	local itemType = itemData.itemType
    local itemList = BoardMeta:getItemListByType(itemType)

	local chartMap = self:getChartMap()
    local bUnlockAll = true
    for _, v in pairs(itemList) do
        if chartMap[''..v] == nil then
            bUnlockAll = false
            break
        end
    end

    if bUnlockAll then
        _G.amfBean("MergeManager"):dc("happy_merge", "handbook_success", itemType)
    end
end

function MergeModel:checkChartInfo( itemId )
	--检测图鉴是否开始，是否领取
	local bOpen = false
	local bGetReward = false

	local chartMap = self:getChartMap()
	if chartMap[''..itemId] ~= nil then
		bOpen = true
		if chartMap[''..itemId] == true then
			bGetReward = true
		end
	end
	return bOpen, bGetReward
end

function MergeModel:setChartGetReward(itemId)
    local chartMap = self:getChartMap()
	if chartMap[''..itemId] ~= nil then
		chartMap[''..itemId] = true
	end
    self:setDataByKey('chartMap', chartMap)
end

function MergeModel:checkChartIsGetAll()
	--是否获得所有图鉴，
	local allItemList = BoardMeta:getAllHandBookItemList(  )
	local allItemNum = #allItemList

	local chartMap = self:getChartMap()
	local hadChartNum = 0
	for i,v in pairs(chartMap) do
		hadChartNum = hadChartNum + 1
	end

	if hadChartNum == allItemNum then
		return true, hadChartNum, allItemNum
	end

	return false, hadChartNum, allItemNum
end

function MergeModel:checkCanGetHeadFrameReward()
	--是否可以领取图鉴头像框奖励
	local bCanGet = false
	local bCanGetIndexList = {}

	local bGetAllChart, hadChartNum, allItemNum = self:checkChartIsGetAll()
	for i=1, 3 do
		local bNeedNum = self:getHeadFrameNeedNum(i)
		if hadChartNum >= bNeedNum and not self:checkHeadFrameIsGet(i) then
			table.insert( bCanGetIndexList, i )
		end
	end
	if #bCanGetIndexList > 0 then
		bCanGet = true
	end
	return bCanGet, bCanGetIndexList
end

function MergeModel:checkHeadFrameIsGet( headIndex )
	local chartProgressRewardIdList  = self:getDataByKey('chartProgressRewardIdList')
	return table.exist( chartProgressRewardIdList, headIndex )
end

function MergeModel:setGetHeadFrameSucess(headIndex)
	local chartProgressRewardIdList  = self:getDataByKey('chartProgressRewardIdList')
	table.insert(chartProgressRewardIdList, headIndex )
	self:setDataByKey('chartProgressRewardIdList', chartProgressRewardIdList)
end

function MergeModel:getHeadFrameNeedNum( headIndex )
	local ChartProgressRewardMeta = self:getConfigByKey("chartProgressRewardMetaList")
	for i,v in ipairs(ChartProgressRewardMeta) do
		if headIndex == v.rewardId then
			return v.needChartNum
		end
	end
	return 0
end

function MergeModel:getFinalHeadFrameReward( )
	local ChartProgressRewardMeta = self:getConfigByKey("chartProgressRewardMetaList") or {}
	for i,v in ipairs(ChartProgressRewardMeta) do
		if 3 == v.rewardId then
			return v.rewardList
		end
	end
	return { }
end


function MergeModel:checkChartCanGetReward()
	--检测图鉴可以领奖
	local canGetRewardIds = {}
	local chartMap = self:getChartMap()
	for i,v in pairs(chartMap) do
		if v == false then
			table.insert(canGetRewardIds,tonumber(i))
		end
	end

	return #canGetRewardIds>0, canGetRewardIds
end

function MergeModel:getProgressRewardIndex()
	local progressRewardIndex = self:getDataByKey('progressRewardIndex')
	return progressRewardIndex
end

function MergeModel:setProgressRewardIndex( progressRewardIndex )
	self:setDataByKey('progressRewardIndex',progressRewardIndex)
end

function MergeModel:getProgressSpecialItemUnlockNeedNum( itemId )
	--获取进度奖励中特殊道具解锁需要的数量
	local moneyProgressRewardMetaList = self:getMoneyProgressRewardMetaList()
	local needNum = 0

	for i,v in ipairs(moneyProgressRewardMetaList) do

		local rewards = v.rewardList
		needNum = needNum + v.needValue

		for j,k in ipairs(rewards) do
			if k.itemId == itemId then
				return true, needNum
			end
		end
	end

	return false, 0
end


function MergeModel:checkHasProgressReward(  )
	--判断是否可以领取进度奖励
	local progressRewardIndex = self:getProgressRewardIndex()
	local money = self:getMoney()
	local moneyProgressRewardMetaList = self:getMoneyProgressRewardMetaList()

	local noCareIndexs = {3,6} --小鸡，机器不关心
	local needNum = 0
	for i,v in ipairs(moneyProgressRewardMetaList) do
		if v.rewardId > progressRewardIndex and not table.exist(noCareIndexs, v.rewardId) then
			if money >= needNum + v.needValue then
				return true
			end
		end

		needNum = needNum + v.needValue
	end
	return false
end

function MergeModel:getScoreBuff20EndTime()
	local scoreBuff20EndTime = self:getDataByKey('scoreBuff20EndTime') or '0'
	return tonumber(scoreBuff20EndTime)
end

function MergeModel:setScoreBuff20EndTime( scoreBuff20EndTime )
	self:setDataByKey('scoreBuff20EndTime', tostring(scoreBuff20EndTime))
end

function MergeModel:addScoreBuff20(num)
    local scoreBuff20EndTime = self:getScoreBuff20EndTime()
    local curTime = TimeKit:timeInMillis()
    local addTimeNum = num*60*1000
    if curTime < scoreBuff20EndTime then
        scoreBuff20EndTime = scoreBuff20EndTime + addTimeNum
    else
        scoreBuff20EndTime = curTime + addTimeNum
    end
    self:setScoreBuff20EndTime(scoreBuff20EndTime)
end

function MergeModel:getScoreBuff50EndTime()
	local scoreBuff50EndTime = self:getDataByKey('scoreBuff50EndTime') or '0'
	return tonumber(scoreBuff50EndTime)
end

function MergeModel:setScoreBuff50EndTime( scoreBuff50EndTime )
	self:setDataByKey('scoreBuff50EndTime', tostring(scoreBuff50EndTime))
end

function MergeModel:addScoreBuff50(num)
    local scoreBuff50EndTime = self:getScoreBuff50EndTime()
    local curTime = TimeKit:timeInMillis()
    local addTimeNum = num*60*1000
    if curTime < scoreBuff50EndTime then
        scoreBuff50EndTime = scoreBuff50EndTime + addTimeNum
    else
        scoreBuff50EndTime = curTime + addTimeNum
    end
    self:setScoreBuff50EndTime(scoreBuff50EndTime)
end

function MergeModel:getMoneyBuffEndTime()
	local moneyBuffEndTime = self:getDataByKey('moneyBuffEndTime') or '0'
	return tonumber(moneyBuffEndTime)
end

function MergeModel:setMoneyBuffEndTime( moneyBuffEndTime )
	self:setDataByKey('moneyBuffEndTime', tostring(moneyBuffEndTime))
end

function MergeModel:addMoneyBuff(num)
    local moneyBuffEndTime = self:getMoneyBuffEndTime()
    local curTime = TimeKit:timeInMillis()
    local addTimeNum = num*60*1000
    if curTime < moneyBuffEndTime then
        moneyBuffEndTime = moneyBuffEndTime + addTimeNum
    else
        moneyBuffEndTime = curTime + addTimeNum
    end
    self:setMoneyBuffEndTime(moneyBuffEndTime)
end

function MergeModel:checkIsInBuffTime( buffEndTime )
	local curTime = TimeKit:timeInSec()
	return curTime < math.floor(buffEndTime/1000)
end

function MergeModel:checkIsHaveScoreBuff(  )
	--当前是否有加分buff生效
	return self:checkIsHaveScoreBuff20() or self:checkIsHaveScoreBuff50()
end

function MergeModel:checkIsHaveScoreBuff20(  )
	--当前是否有buff生效 加分20
	local buffEndTime = self:getScoreBuff20EndTime()
	return self:checkIsInBuffTime( buffEndTime )
end

function MergeModel:checkIsHaveScoreBuff50(  )
	--当前是否有buff生效 加分50
	local buffEndTime = self:getScoreBuff50EndTime()
	return self:checkIsInBuffTime( buffEndTime )
end

function MergeModel:checkIsHaveMoneyDoubleBuff(  )
	--当前是否有buff生效 双倍收集物
	local buffEndTime = self:getMoneyBuffEndTime()
	return self:checkIsInBuffTime( buffEndTime )
end

function MergeModel:getRewardDeskList()
	local rewardDeskList = self:getDataByKey('rewardDeskList')
	return rewardDeskList
end

function MergeModel:addItemToRewardDeskList( itemId )
	local rewardDeskList = self:getDataByKey('rewardDeskList')

	local itemData = BoardMeta:getItemDataByItemId( itemId )
	local bMagicItem = BoardMeta:checkItemTypeIsMagicItem( itemData.itemType )

	if bMagicItem then
		table.insert( rewardDeskList, 1, itemId )
	else
		table.insert( rewardDeskList, itemId )
	end
	self:setDataByKey('rewardDeskList', rewardDeskList)
end

function MergeModel:getRewardDeskOneItem()
	local rewardDeskList = self:getRewardDeskList()
	if #rewardDeskList > 0 then
		return true, rewardDeskList[1]
	else
		return false, 0
	end
end


function MergeModel:removeRewardDeskListTop(  )
	local rewardDeskList = self:getRewardDeskList()
	if #rewardDeskList > 0 then
		table.remove( rewardDeskList, 1 )
		self:updateRewardDeskList( rewardDeskList  )
	end
end

function MergeModel:updateRewardDeskList( rewardDeskList )
	self:setDataByKey('rewardDeskList', rewardDeskList )
end

function MergeModel:getPerDayMap()
	-- 二期冰冻逻辑需要读取当天购买体力数据；perDayMap 缺失时兜底为空表，避免一期数据崩溃。
	local perDayMap = self:getDataByKey('perDayMap') or {}
	return perDayMap
end

function MergeModel:getEmptyPerDayInfo(  )
	local perDayInfo = {}
	perDayInfo.payTag = 0
	perDayInfo.freeFood = false
	perDayInfo.buyPowerNum = 0
    perDayInfo.freeFoodList = {}
    perDayInfo.fourItemGoodIdsList = {}
    perDayInfo.foodItemIdList = {}
    perDayInfo.buyGoodsIdMap = {}
	perDayInfo.buyFoodIdMap = {}
	return perDayInfo
end

function MergeModel:getTodayPerDayMap( curTime )
	--获取某个时间的每日信息
	local curTime = curTime or TimeKit:timeInSec()

	local perDayMap = self:getPerDayMap()
	local day = time2day(curTime)
	if perDayMap[''..day] then
		return perDayMap[''..day]
	else
		local info = self:getEmptyPerDayInfo()
		perDayMap[''..day] = info
		self:setDataByKey("perDayMap", perDayMap )
		return perDayMap[''..day]
	end
end

function MergeModel:checkFreeItemCanGet(  )
	--每日奖是否可以领取
	local perDayInfo = self:getTodayPerDayMap()
	return not perDayInfo.freeFood
end

function MergeModel:getBuyFoodCount(itemId)
    local perDayInfo = self:getTodayPerDayMap()
    return perDayInfo.buyFoodIdMap["" .. itemId] or 0
end

function MergeModel:addBuyFoodCount(itemId, num)
    num = num or 1
    local buyFoodIdMap = self:getTodayPerDayMap().buyFoodIdMap
    if not buyFoodIdMap["" .. itemId] then
        buyFoodIdMap["" .. itemId] = num
    else
        buyFoodIdMap["" .. itemId] = buyFoodIdMap["" .. itemId] + num
    end
    self:setTodayPerDayMap("buyFoodIdMap", buyFoodIdMap)
end

function MergeModel:getBuyGoodsCount(goodsId)
    local perDayInfo = self:getTodayPerDayMap()
    return perDayInfo.buyGoodsIdMap["" .. goodsId] or 0
end

function MergeModel:addBuyGoodsCount(goodsId, num)
    num = num or 1
    local buyGoodsIdMap = self:getTodayPerDayMap().buyGoodsIdMap
    if not buyGoodsIdMap["" .. goodsId] then
        buyGoodsIdMap["" .. goodsId] = num
    else
        buyGoodsIdMap["" .. goodsId] = buyGoodsIdMap["" .. goodsId] + num
    end
    self:setTodayPerDayMap("buyGoodsIdMap", buyGoodsIdMap)
end

function MergeModel:getRealItemList()
	local realItemList = self:getDataByKey('realItemList')
	return realItemList
end

function MergeModel:checkHasGetRealItem()
	--是否获得实物了
	local realItemList = self:getRealItemList()
	return #realItemList > 0
end

function MergeModel:getContact()
	local contact = self:getDataByKey('contact')
	return contact
end

function MergeModel:setContact()
	--填写地址
	self:setDataByKey('contact',true)
end

local PKStatus = {
    NONE = 0,
    INIT = 1,
    OPEN = 2,
    CD = 3,
}

function MergeModel:getPKStatus()
    return self:getDataByKey("pkMatchStatus")
end

function MergeModel:setPKStatus(value)
    self:setDataByKey("pkMatchStatus", value)
end

function MergeModel:getPKCostPower()
    return self:getDataByKey("costPower") or 0
end

function MergeModel:setPKCostPower(value)
    self:setDataByKey("costPower", value)
end

function MergeModel:addPKCostPower(num)
    num = num or 0
    if num >= 0 then return end
    if not self:isInPKStatus() then return end
    local matchBeginTime = self:getMatchBeginTime()
    local ts = TimeKit:timeInMillis()
    if (ts < matchBeginTime) or (ts > (matchBeginTime + 2 * 3600 * 1000)) then return end
    local power = self:getPKCostPower()
    power = power - num
    self:setPKCostPower(power)
end

function MergeModel:isInPKStatus()
    local status = self:getPKStatus()
    return status == PKStatus.OPEN
end

function MergeModel:getPKSettle()
    return self:getDataByKey("settleMatch")
end

function MergeModel:setPKSettle()
    self:setDataByKey("settleMatch", true)
end

function MergeModel:getPKRank()
    return self:getDataByKey("rank")
end

function MergeModel:setPKRank(rank)
    self:setDataByKey("rank", rank)
end

function MergeModel:getHasGotPKRankReward()
    return self:getDataByKey("rankReward")
end

function MergeModel:setHasGotPKRankReward()
    self:setDataByKey("rankReward", true)
end

function MergeModel:getHasGotCostReward()
    return self:getDataByKey("costReward")
end

function MergeModel:setHasGotPKCostReward()
    self:setDataByKey("costReward", true)
end

function MergeModel:getMatchEndTime()
    return tonumber(self:getDataByKey("matchCdEndTime"))
end

function MergeModel:setMatchCdEndTime(time)
    time = time or (TimeKit:timeInMillis() + 12 * 3600 * 1000)
    self:setDataByKey("matchCdEndTime", tostring(time))
end

function MergeModel:getMatchBeginTime()
    return tonumber(self:getDataByKey("matchBeginTime"))
end

function MergeModel:resetPKData()
    self:setPKCostPower(0)
    self:setDataByKey("settleMatch", false)
    self:setDataByKey("rankReward", false)
    self:setDataByKey("costReward", false)

    local rank = self:getPKRank()
    local matchNum = self:getDataByKey("matchNum")
    _G.amfBean("MergeManager"):saveFlagToLocalByKeyInt(Meta.Keys.STRENGTH_PK_LAST_RANK, false, rank, true)
    _G.amfBean("MergeManager"):saveFlagToLocalByKeyInt(Meta.Keys.STRENGTH_PK_LAST_VALUE, false, 0, true)
    _G.amfBean("MergeManager"):saveFlagToLocalByKeyInt(Meta.Keys.STRENGTH_PK_LAST_ROUND, false, matchNum, true)
end

function MergeModel:checkHasEnergyPKRankReward()
    if not self:isInPKStatus() then return false end
    local bSettle = self:getPKSettle()
    if not bSettle then return false end
    local rank = self:getPKRank()
    if rank > 0 and rank <= 3 then
        return not self:getHasGotPKRankReward()
    else
        return false
    end
end

function MergeModel:checkHasEnergyPKCostReward()
    if not self:isInPKStatus() then return false end
    local costEnergy = self:getPKCostPower()
    return costEnergy >= Meta.ENERGY_PK_COST_MAX and not self:getHasGotCostReward()
end

function MergeModel:getCellMap()
	--获取棋盘信息， 只有初始化棋盘的时候用过，之后使用棋盘自己的数据
	local cellMap = self:getDataByKey('cellMap')
	return cellMap
end

function MergeModel:refreshCellMap( cellMap )
	--统一刷新内容，后端发来的时候更新
	self:setDataByKey('cellMap', cellMap)
end

function MergeModel:updateCellMap( x,y, info )
	--更新棋盘数据，操作过程中更新
	local cellMap = self:getCellMap()

	if cellMap[x] and cellMap[x][y] then
		cellMap[x][y] = info
	end
	self:refreshCellMap(cellMap)
end

function MergeModel:canGetPkReward( )
	--是否有体力比拼奖 todo
	return false
end

function MergeModel:canBuyCDItemNum( timeSec )
	--给一个时间获取需要买几个减cd道具
	local baseGoodsId = self:getBaseGoodsId()
	local buyNum = math.ceil2( timeSec/ 15 )
	return baseGoodsId, buyNum
end

function MergeModel:canBuy30CDItemNum( timeSec )
	--给一个时间获取需要买几个减cd道具
	local base30GoodsId = self:getBase30GoodsId()
	local buyNum = math.ceil2( timeSec/ Meta.MACHINE_TIME_PER_GOLD )
	return base30GoodsId, buyNum
end

function MergeModel:canGetSurpriseDailyReward()
	--是否可以领取每日的惊喜助力
	local bCurInRewardTime = self:checkStepIsOpen(Meta.StepTypes.kSurriseAssist)

	local perDayData = self:getTodayPerDayMap()
	local surpriseReward = perDayData.surpriseReward
	-- printx(12,'canGetSurpriseDailyReward', surpriseReward, bCurInRewardTime )
	if not surpriseReward and bCurInRewardTime then
		return true
	end

	return false
end

function MergeModel:setSurpriseGetSucess()
    self:setTodayPerDayMap("surpriseReward", true)
end


----------配置部分

-- function MergeModel:getSurpriseHelpMetaList()
-- 	local surpriseHelpMetaList = self:getConfigByKey('surpriseHelpMetaList')
-- 	return surpriseHelpMetaList
-- end

function MergeModel:getBaseGoodsId()
	local base15SecondGoodsId = self:getConfigByKey('base15SecondGoodsId')
	return base15SecondGoodsId
end

function MergeModel:getBase30GoodsId()
	local base30SecondGoodsId = self:getConfigByKey('base30SecondGoodsId')
	return base30SecondGoodsId
end

function MergeModel:getChickGoodsId()
	local chickGoodsId = self:getConfigByKey('chickGoodsId')
	return chickGoodsId
end

function MergeModel:getMoneyProgressRewardMetaList()
	local moneyProgressRewardMetaList = self:getConfigByKey('moneyProgressRewardMetaList')
	return moneyProgressRewardMetaList
end

function MergeModel:getMoneyProgressRewardInfoByRewardId( rewardId )
	--根据rewardId获取进度奖励配置
	local moneyProgressRewardMetaList = self:getMoneyProgressRewardMetaList()
	for i,v in ipairs(moneyProgressRewardMetaList) do
		if v.rewardId == rewardId then
			return v
		end
	end

    return moneyProgressRewardMetaList[#moneyProgressRewardMetaList]
end

function MergeModel:getMoneyProgressRandomRewardList()
	local moneyProgressRandomRewardList = self:getConfigByKey('moneyProgressRandomRewardList')
	return moneyProgressRandomRewardList
end

function MergeModel:getLauncherMetaList()
	--获取发射器配置
	local launcherMetaList = self:getConfigByKey('launcherMetaList')
	return launcherMetaList
end

function MergeModel:getLauncherMetaById( launcherId )
	--根据发射器id获取发射器的配置
	local launcherMetaList = self:getLauncherMetaList()
	for i,v in ipairs(launcherMetaList) do
		if v.launcherId == launcherId then
			return v
		end
	end
end

function MergeModel:getOrderMetaList()
	--获取订单配置
	local orderMetaList = self:getConfigByKey('orderMetaList')
	return orderMetaList
end

function MergeModel:getOrderMetaByOrderId( orderId )
	--根据发射器id获取发射器的配置
	local orderMetaList = self:getOrderMetaList()
	for i,v in ipairs(orderMetaList) do
		if v.orderId == orderId then
			return v
		end
	end
end

function MergeModel:getYearOrderMetaList()
	--获取订单配置
	local orderMetaList = self:getConfigByKey('yearOrderMetaList')
	return orderMetaList
end

function MergeModel:getYearOrderMetaByOrderId( orderId )
	--根据发射器id获取发射器的配置
	local orderMetaList = self:getYearOrderMetaList()
	for i,v in ipairs(orderMetaList) do
		if v.orderId == orderId then
			return v
		end
	end
end

function MergeModel:getPerChartReward()
	local perChartReward = self:getConfigByKey('perChartReward')
	return perChartReward
end

function MergeModel:getPowerGoodsMetaList()
	--获取买体力配置
	local powerGoodsMetaList = self:getConfigByKey('powerGoodsMetaList')
	return powerGoodsMetaList
end

function MergeModel:getPowerGoodsMetaByBuyNum( buyNum )
	--根据发射器id获取发射器的配置
	local powerGoodsMetaList = self:getPowerGoodsMetaList()
	for i,v in ipairs(powerGoodsMetaList) do
		if v.buyNum == buyNum then
			return v
		end
	end

	--找不到就返回最后一个
	return powerGoodsMetaList[#powerGoodsMetaList]
end

function MergeModel:getLevelGoodsIdMetaList()
	--获取道具购买信息
	local levelGoodsIdMetaList = self:getConfigByKey('levelGoodsIdMetaList')
	return levelGoodsIdMetaList
end

function MergeModel:getLevelGoodsId( itemId )
	--根据道具id获取购买他对应的配置
	local levelGoodsIdMetaList = self:getLevelGoodsIdMetaList()
	local itemData = BoardMeta:getItemDataByItemId(itemId)
	local itemLevel = itemData.level

	for i,v in ipairs(levelGoodsIdMetaList) do
		if v.level == itemLevel then
			return v
		end
	end
end

function MergeModel:getGroupRankRealMetaList()
	--排行榜实物奖励
	local groupRankRealMetaList = self:getConfigByKey('groupRankRealMetaList')
	return groupRankRealMetaList
end

function MergeModel:getGroupRankRealMetaByRank( rank )
	--根据排名获取排行榜实物奖励
	local groupRankRealMetaList = self:getGroupRankRealMetaList()
	for i,v in ipairs(groupRankRealMetaList) do
		if rank >= v.rankMin and rank <= v.rankMax then
			return v
		end
	end
end

function MergeModel:getGroupRankRewardMetaList()
	--排行榜奖励
	local groupRankRewardMetaList = self:getConfigByKey('groupRankRewardMetaList')
	return groupRankRewardMetaList
end

function MergeModel:getGroupRankRewardMetaBtRank( rank )
	--根据排名获取对应的排行榜奖励
	local groupRankRewardMetaList = self:getGroupRankRewardMetaList()
	for i,v in ipairs(groupRankRewardMetaList) do
		if rank >= v.rankMin and rank <= v.rankMax then
			return v
		end
	end
end

function MergeModel:getBuyCDInfo( endTime )
	--获取购买时间所需的道具数量
end

function MergeModel:getPKConfig()
    local metaList = self:getPKGroupRankRewardMetaList()
    local rewards ={}
    for _, v in ipairs(metaList) do
        table.insert(rewards, v.rewardList)
    end

    return {
        showStrength = Meta.ENERGY_PK_TRIGGER_ENERGY,
        showMoney = Meta.ENERGY_PK_TRIGGER_MONEY,
        max = Meta.ENERGY_PK_MAX_ENERGY,
        refund = self:getPKCostRewardNum(),
        rewards = rewards,
    }
end

function MergeModel:getPKCostRewardNum()
    local rewards = self:getConfigByKey("pkCostRewardList") or {}
    return rewards[1] and rewards[1].num
end

function MergeModel:getPKGroupRankRewardMetaList()
    return self:getConfigByKey('pkGroupRankRewardMetaList')
end

function MergeModel:getSuperRate(powerLevel)
	local launcherPowerMeta = self:getLauncherPowerMeta(powerLevel)
	return tonumber(launcherPowerMeta and launcherPowerMeta.superRate) or 0
end

function MergeModel:getSuperMaxNum()
	local bubbleRateMeta = self:getConfigByKey('bubbleRateMeta')
	if bubbleRateMeta then
	    return bubbleRateMeta.superMaxNum
	end
	return 0
end

function MergeModel:getBubbleMaxLevel()
	local bubbleRateMeta = self:getConfigByKey('bubbleRateMeta')
	if bubbleRateMeta then
	    return bubbleRateMeta.bubbleMaxLevel
	end
	return 0
end

function MergeModel:getBubble7TimeInterval()
	local bubbleRateMeta = self:getConfigByKey('bubbleRateMeta')
	if bubbleRateMeta then
	    return bubbleRateMeta.bubble7TimeInterval
	end
	return 0
end

function MergeModel:getBubbleSpecialTimeInterval ()
	local bubbleRateMeta = self:getConfigByKey('bubbleRateMeta')
	if bubbleRateMeta then
	    return bubbleRateMeta.bubble4SpecialTimeInterval
	end
	return 0
end

function MergeModel:getBubblebubbleRateMeta()
	local bubbleRateMeta = self:getConfigByKey('bubbleRateMeta')
	return bubbleRateMeta
end

function MergeModel:getLauncherPowerMeta(powerLevel)
	powerLevel = tonumber(powerLevel)
	if not powerLevel then return nil end

	for _, launcherPowerMeta in ipairs(self:getConfigByKey(LAUNCHER_POWER_META_LIST_KEY) or {}) do
		if tonumber(launcherPowerMeta.powerLevel) == powerLevel then
			return launcherPowerMeta
		end
	end
end

function MergeModel:getLuckyLaunchConfig(powerLevel)
	local launcherPowerMeta = self:getLauncherPowerMeta(powerLevel)
	if not launcherPowerMeta then return nil end

	return {
		showLuckRate = launcherPowerMeta.showLuckRate,
		luckyFoodLevelWeights = launcherPowerMeta.luckyFoodLevelWeights,
	}
end

-- 按倍率档位、PK 状态和当前订单限定棋子等级查询非引导饺子的特殊生成配置。
function MergeModel:getJiaoziSpecialLaunchConfig(powerLevel, specialItemLevel, bInPk)
	specialItemLevel = tonumber(specialItemLevel)
	local launcherPowerMeta = self:getLauncherPowerMeta(powerLevel)
	if not launcherPowerMeta or not specialItemLevel then return nil end

	local rateMap = bInPk and launcherPowerMeta.specialRatePk or launcherPowerMeta.specialRateNoPk
	if type(rateMap) ~= "table" then return nil end

	local percent = tonumber(rateMap[specialItemLevel] or rateMap[tostring(specialItemLevel)])
	if percent == nil then return nil end

	return {
		makeLevel = specialItemLevel,
		percent = percent,
	}
end

function MergeModel:getLaunchCount()
	local launchCount = self:getDataByKey('launchCount')
	return launchCount
end

function MergeModel:addLaunchCount()
	local launchCount = self:getLaunchCount()
	launchCount = launchCount + 1
	self:setDataByKey( 'launchCount', launchCount )
end

function MergeModel:updateLaunchCount(launchCount)
	self:setDataByKey( 'launchCount', launchCount )
end

function MergeModel:getShowSuperCount()
	local launchLuckyCount = self:getDataByKey('launchLuckyCount')
	return launchLuckyCount
end

function MergeModel:setShowSuperCount()
	local launchCount = self:getLaunchCount()
	self:setDataByKey( 'launchLuckyCount', launchCount )
end

function MergeModel:updateLaunchLuckyCount(launchLuckyCount)
	self:setDataByKey( 'launchLuckyCount', launchLuckyCount )
end

-----------------------------------------
---------志刚end-------------
-----------------------------------------


------------------ haoqing -------------------

function MergeModel:getTwoMoneyProgressRewardMeta()
	local moneyProgressRewardMetaList = self:getMoneyProgressRewardMetaList()
    local normalRet, randomRet = {}, {}

	for i,v in ipairs(moneyProgressRewardMetaList) do
		if v.randomReward then
            table.insert(randomRet, v)
        else
            table.insert(normalRet, v)
        end
	end

	return normalRet, randomRet
end

function MergeModel:getCurMoney()
    local money = self:getMoney()
    local progressRewardIndex = self:getProgressRewardIndex()
	local moneyProgressRewardMetaList = self:getMoneyProgressRewardMetaList()

    local ret = money
    local isEnd = false

	for i,v in ipairs(moneyProgressRewardMetaList) do
		if progressRewardIndex >= v.rewardId then
            ret = ret - v.needValue
        else
            isEnd = true
            break
		end
	end

    if not isEnd then
        local endCircleMeta = moneyProgressRewardMetaList[#moneyProgressRewardMetaList]
        local curIndex = endCircleMeta.rewardId

        while true do
            if progressRewardIndex >= curIndex then
                curIndex = curIndex + 1
                ret = ret - endCircleMeta.needValue
            else
                break
            end
        end
    end

	return ret
end

----------------------------------------------
---------------------zonghao------------------------------------

function MergeModel:getYueSaiCollectionCntByFoodId(foodId)
	local foodMetaList = self:getConfigByKey("foodMetaList") or {}
	for i,v in ipairs(foodMetaList) do
		if v.foodId == foodId then
			if v.fireItem then
				return v.fireItem.num or 0
			else
				return 0
			end
		end
	end
	return 0
end

-- 按棋子 ID 查询食材配置。
function MergeModel:getFoodMetaByFoodId(foodId)
    foodId = tonumber(foodId)
    if not foodId then return nil end

    for _, foodMeta in ipairs(self:getConfigByKey("foodMetaList") or {}) do
        if tonumber(foodMeta.foodId) == foodId then
            return foodMeta
        end
    end
end

-- 按类型和等级查询体力箱子/瓶子的使用配置。
function MergeModel:getFoodUseMeta(foodType, level)
    level = tonumber(level)
    if not foodType or not level then return nil end

    for _, foodUseMeta in ipairs(self:getConfigByKey("foodUseMetaList") or {}) do
        if foodUseMeta.type == foodType and tonumber(foodUseMeta.level) == level then
            return foodUseMeta
        end
    end
end

-- 体力箱子只有同 ID、使用次数相等且都达到配置次数时才能合成。
function MergeModel:checkEnergyBoxCanMerge(itemId, itemUseCount, otherItemId, otherUseCount)
	if tonumber(itemId) ~= tonumber(otherItemId) then return false end
	if tonumber(itemUseCount) ~= tonumber(otherUseCount) then return false end

	local foodMeta = self:getFoodMetaByFoodId(itemId)
    if not foodMeta or foodMeta.type ~= "POWER_CHEST" then return true end

    local foodUseMeta = self:getFoodUseMeta(foodMeta.type, foodMeta.level)
    local useCount = tonumber(foodUseMeta and foodUseMeta.useCount)
    if useCount == nil then return false end

    return tonumber(itemUseCount) == useCount and tonumber(otherUseCount) == useCount
end

function MergeModel:getTopFoodMetaByFoodId(foodId)
	--根据food id获取
	local metaList = self:getConfigByKey("topFoodMetaList") or {}
	for i,v in ipairs(metaList) do
		if v.foodId == foodId then
			return v
		end
	end
end

function MergeModel:getRestaurantRatingData()
	return self:getDataByKey(RESTAURANT_RATING_DATA_KEY)
end

function MergeModel:updateRestaurantRatingData(restaurantRatingData)
	self:setDataByKeyIgnoreNil(RESTAURANT_RATING_DATA_KEY, restaurantRatingData)
end

function MergeModel:getRestaurantRatingMetaList()
	return self:getConfigByKey(RESTAURANT_RATING_META_LIST_KEY) or {}
end

function MergeModel:getRestaurantRatingMaxLevel()
	local maxLevel = DEFAULT_RESTAURANT_RATING_REWARD_LEVEL
	for _, meta in ipairs(self:getRestaurantRatingMetaList()) do
		local ratingLevel = tonumber(meta.ratingLevel) or DEFAULT_RESTAURANT_RATING_REWARD_LEVEL
		if ratingLevel > maxLevel then
			maxLevel = ratingLevel
		end
	end
	return maxLevel
end

function MergeModel:checkRestaurantRatingDayCanGetReward(dayData)
	if not dayData or not dayData.exist or not dayData.moneyOk then return false end

	local finishOrderNum = tonumber(dayData.finishOrderNum) or 0
	local rewardLevel = tonumber(dayData.rewardLevel) or DEFAULT_RESTAURANT_RATING_REWARD_LEVEL
	for _, meta in ipairs(self:getRestaurantRatingMetaList()) do
		local ratingLevel = tonumber(meta.ratingLevel) or DEFAULT_RESTAURANT_RATING_REWARD_LEVEL
		local needOrderNum = tonumber(meta.needOrderNum) or 0
		if ratingLevel > rewardLevel and finishOrderNum >= needOrderNum then
			return true, ratingLevel, meta
		end
	end
	return false
end

function MergeModel:checkCanGetRestaurantRatingReward()
	local ratingData = self:getRestaurantRatingData()
	if not ratingData then return false end

	local dayDataMap = ratingData.dayDataMap or {}
	for _, dayData in pairs(dayDataMap) do
		local canGet = self:checkRestaurantRatingDayCanGetReward(dayData)
		if canGet then return true end
	end

	return self:checkRestaurantRatingDayCanGetReward(ratingData)
end

function MergeModel:canShowRestaurantRatingIcon()
	local ratingData = self:getRestaurantRatingData()
	if not ratingData or not ratingData.exist or not ratingData.moneyOk then return false end
	if self:checkCanGetRestaurantRatingReward() then return true end

	local maxLevel = self:getRestaurantRatingMaxLevel()
	if maxLevel <= DEFAULT_RESTAURANT_RATING_REWARD_LEVEL then return true end

	local rewardLevel = tonumber(ratingData.rewardLevel) or DEFAULT_RESTAURANT_RATING_REWARD_LEVEL
	return rewardLevel < maxLevel
end

function MergeModel:getRestaurantPraiseData()
	-- 好评回馈后端主数据。restaurantPraiseData 缺失时按未开启处理。
	return self:getDataByKey(RESTAURANT_PRAISE_DATA_KEY) or {}
end

function MergeModel:updateRestaurantPraiseData(restaurantPraiseData, needSave)
	-- 刷新好评回馈主数据，用于 Info/Reward/BoardOp 回包同步。
	self:setDataByKeyIgnoreNil(RESTAURANT_PRAISE_DATA_KEY, restaurantPraiseData or {}, needSave)
end

function MergeModel:getRestaurantPraiseTargetNum()
	-- 普通轮目标小手数，后端配置缺失时默认 12。
	local targetNum = self:getConfigByKey(RESTAURANT_PRAISE_TARGET_NUM_KEY)
	return safeToNumber(targetNum, DEFAULT_RESTAURANT_PRAISE_TARGET_NUM)
end

function MergeModel:getRestaurantPraiseTargetNumList()
	local targetNumStr = self:getConfigByKey(RESTAURANT_PRAISE_TARGET_NUM_STR_KEY)
	if type(targetNumStr) ~= "string" or targetNumStr == "" then return {} end

	local targetNumList = {}
	for _, value in ipairs(string.split(targetNumStr, ",")) do
		local targetNum = tonumber(value)
		if not targetNum or targetNum <= 0 then
			return {}
		end
		table.insert(targetNumList, targetNum)
	end
	return targetNumList
end

function MergeModel:getRestaurantPraiseTargetNumByRound(round)
	local targetNumList = self:getRestaurantPraiseTargetNumList()
	if #targetNumList <= 0 then return nil end

	round = math.max(math.floor(safeToNumber(round, 1)), 1)
	return targetNumList[math.min(round, #targetNumList)]
end

function MergeModel:isRestaurantPraiseGuideRound(round)
	local targetNumList = self:getRestaurantPraiseTargetNumList()
	round = math.floor(safeToNumber(round, 0))
	if round <= 0 then return false end
	if #targetNumList > 1 then
		-- 最后一项是超过配置轮次后持续使用的普通轮目标，前面的轮次均为引导轮。
		return round < #targetNumList
	end
	return round == 1
end

function MergeModel:getRestaurantPraiseGuideTargetNum()
	-- 引导轮目标小手数，后端配置缺失时默认 3。
	local guideTargetNum = self:getConfigByKey(RESTAURANT_PRAISE_GUIDE_TARGET_NUM_KEY)
	return safeToNumber(guideTargetNum, DEFAULT_RESTAURANT_PRAISE_GUIDE_TARGET_NUM)
end

function MergeModel:getRestaurantPraisePowerMetaList()
	-- 小手数量按订单体力区间配置；客户端只读取，不自行推导后端结果。
	return self:getConfigByKey(RESTAURANT_PRAISE_POWER_META_LIST_KEY) or {}
end

function MergeModel:getRestaurantPraiseRewardMetaList()
	-- 好评回馈进度奖励配置；真实奖励内容以后端回包为准。
	return self:getConfigByKey(RESTAURANT_PRAISE_REWARD_META_LIST_KEY) or {}
end

function MergeModel:getRestaurantPraiseCurrentTargetNum()
	-- 后端回包优先；否则按轮次配置取值，最后兼容旧的引导/普通目标配置。
	local praiseData = self:getRestaurantPraiseData()
	if praiseData.targetNum ~= nil then
		return safeToNumber(praiseData.targetNum, self:getRestaurantPraiseTargetNum())
	end

	local round = safeToNumber(praiseData.round, 0)
	local roundTargetNum = self:getRestaurantPraiseTargetNumByRound(round)
	if roundTargetNum then
		return roundTargetNum
	end

	if round == 1 then
		return self:getRestaurantPraiseGuideTargetNum()
	end

	return self:getRestaurantPraiseTargetNum()
end

function MergeModel:checkCanGetPraiseFeedbackReward()
	-- 奖字判断：已开启且当前进度达到目标值。补领历史若后端另给字段，再在这里收口。
	local praiseData = self:getRestaurantPraiseData()
	local round = safeToNumber(praiseData.round, 0)
	if round <= 0 then return false end

	local progress = safeToNumber(praiseData.progress, 0)
	local targetNum = self:getRestaurantPraiseCurrentTargetNum()
	return targetNum > 0 and progress >= targetNum
end

function MergeModel:canShowPraiseFeedbackIcon()
	-- 倒计时旁入口展示判断：round > 0 表示好评回馈已开启。
	local praiseData = self:getRestaurantPraiseData()
	return safeToNumber(praiseData.round, 0) > 0
end

function MergeModel:getPraiseFeedbackOrderLikeInfo(orderType, orderIndex, orderData)
	-- 订单小手角标只认后端下发的 praiseNum；orderType/orderIndex 原样返回给活动侧定位使用。
	local praiseNum = safeToNumber(orderData and orderData.praiseNum, 0)
	return {
		orderType = orderType,
		orderIndex = orderIndex,
		praiseNum = praiseNum,
		canShow = praiseNum > 0,
	}
end

function MergeModel:getPraiseFeedbackOrder6Data()
	-- 订单 6 是好评回馈专属订单，数据挂在 restaurantPraiseData.order6Data。
	local praiseData = self:getRestaurantPraiseData()
	return praiseData.order6Data or {}
end

function MergeModel:canShowPraiseFeedbackOrder6()
	-- 订单 6 展示只看 order6Round/finish/foodIds，不复用订单 5 的 exist 或数据源。
	local order6Data = self:getPraiseFeedbackOrder6Data()
	local order6Round = safeToNumber(order6Data.order6Round, 0)
	local foodIds = order6Data.foodIds or {}
	return order6Round > 0 and order6Data.finish ~= true and not table.isEmpty(foodIds)
end

function MergeModel:getPraiseFeedbackOrder6ItemList()
	local order6Data = self:getPraiseFeedbackOrder6Data()
	local foodIds = order6Data.foodIds or {}
	local ret = {}
	for _, itemId in ipairs(foodIds) do
		if itemId and itemId > 0 then
			table.insert(ret, itemId)
		end
	end
	return ret
end

function MergeModel:checkItemIsPraiseFeedbackOrder6Item(itemId)
	if not self:canShowPraiseFeedbackOrder6() then
		return false
	end
	return table.exist(self:getPraiseFeedbackOrder6ItemList(), itemId)
end

-- function MergeModel:isNormalOrderProduceHammer(itemId)
-- 	--检测是否含有锤子 true, orderMeta.needItemList
-- 	local foodOrders = self:getFoodOrders()
-- 	local orderInfo = foodOrders[1]
-- 	if orderInfo then
-- 		local orderId = orderInfo.orderId
-- 		local orderMeta = self:getOrderMetaByOrderId( orderId )
-- 		if orderMeta.needItemList[1] == itemId and orderMeta.rewardHammerNum and orderMeta.rewardHammerNum > 0 then
-- 			return true, 1
-- 		end
-- 	end

-- 	local orderInfo = foodOrders[3]
-- 	if orderInfo then
-- 		local orderId = orderInfo.orderId
-- 		local orderMeta = self:getOrderMetaByOrderId( orderId )
-- 		if orderMeta.needItemList[1] == itemId and orderMeta.rewardHammerNum and orderMeta.rewardHammerNum > 0 then
-- 			return true, 3
-- 		end
-- 	end
-- 	return false, 0
-- end

function MergeModel:checkLimitOrderProgressReward(limitOrderData)
	if not limitOrderData then
		limitOrderData = self:getLimitOrderInfo() or {}
	end

	if not next(limitOrderData) then
		return false
	end
	return limitOrderData.finishIndex >= 2 and limitOrderData.progressReward == false
end

function MergeModel:checkLimitOrderPKReward(limitOrderData)
	if not limitOrderData then
		limitOrderData = self:getLimitOrderInfo() or {}
	end

	if not next(limitOrderData) then
		return false
	end

	if limitOrderData.pkRound < 1 then
		return false
	end

	if not self:isCurPKDataWin(limitOrderData) then
		return false
	end

	return limitOrderData.pkReward == false
end

-- 是否能获得锤子
function MergeModel:canGetHammerCollectItem()

    -- 钱是否够
    local money = self:getMoney() or 0
    if money < Meta.OpenEggMoneyLimit then
        return false
    end

    -- 是否在产生锤子期间
    local bOpen, openConfig = self:checkStepIsOpen(Meta.StepTypes.kCrushEgg)
    if not bOpen then
        return false
    end

    -- 订单比拼不为空
    local limitOrderData = self:getNewYearFoodOrderData()
    if next(limitOrderData) then
		-- 是否预热未领取
		if self:checkLimitOrderProgressReward(limitOrderData) then
			return false
		end
        -- 是否比拼结算
        if self:checkLimitOrderPKReward(limitOrderData) then
            return false
        end
        -- 是否累计奖励也领完
		if self:checkPKContinueWinReward() then
			return false
		end
    end

    -- 上一期砸蛋已经结算
    local eggData = self:getDataByKey("crushEggData") or {}
    if not next(eggData) then
        -- 没有砸蛋数据
        return false
    elseif self:getCurWeek() ~= eggData.periodId then
        -- 周期数不一样，没结算完
        return false
	-- elseif self:getCurWeek() == eggData.periodId then
	-- 	local bGiftBought = eggData.buySpecialGoods
	-- 	local bFreeGift = self:canGetOpenEggDataFreeGiftCnt(eggData) > 0
	-- 	local bFinalReward = eggData.finalReward
	-- 	-- 当期大奖拿完 and 礼包买完 and 免费领完
	-- 	if bFinalReward and ((bGiftBought and not bFreeGift) or (not bGiftBought)) then
	-- 		return false
	-- 	end
    end

    return true
end

function MergeModel:isCurPKDataWin(pkData, bZeroFail)
	local data = nil
	if pkData then
		data = pkData
	else
		data = self:getNewYearFoodOrderData()
	end
	local myFinishNum = (data.pkRound-1)*3 + 1 + data.finishIndex
	local otherFinishNum = data.robotMemberData.pkFinishNum
	if myFinishNum < otherFinishNum then
		return false
	elseif myFinishNum > otherFinishNum then
		return true
	end

	-- 判断为0失败 且 完成数量=0
	if bZeroFail and myFinishNum == 0 then
		return false
	end

	-- 输了相等，取时间最早的胜利
	if tonumber(data.finishTime) < tonumber(data.robotMemberData.updateNumTime) then
		return true
	else
		return false
	end
	return false
end

function MergeModel:getNewYearFoodOrderData()
	return self:getLimitOrderInfo() or {}
end

-- function MergeModel:isWinStreak()
-- 	return false
-- end

-- 最大体力值配置
function MergeModel:getMaxPowerConfig()
    return Meta.MaxPowerConfig
end

-- 最大自然恢复体力值配置
function MergeModel:getAutoAddMaxPowerConfig()
    return Meta.AutoAddMaxPowerConfig
end

function MergeModel:getPowerTipPowerConfig()
	return Meta.PowerTipPowerConfig
end

function MergeModel:getTodayBuyPowerNum()
	local perDayData = self:getTodayPerDayMap()
	local buyCnt = perDayData.buyPowerNum or 0
	return buyCnt
end

-- 获得 今日还可享受几次折扣
function MergeModel:getLeftBuyPowerDiscountNum()
	local perDayData = self:getTodayPerDayMap()
	local buyCnt = perDayData.buyPowerNum or 0
	return Meta.MaxBuyPowerDiscountTime - buyCnt
end

function MergeModel:getBuyPowerGoodsInfo()
	local perDayData = self:getTodayPerDayMap()
	local buyCnt = perDayData.buyPowerNum or 0
	buyCnt = buyCnt+1
	if buyCnt > Meta.MaxBuyPowerDiscountTime then
		buyCnt = Meta.MaxBuyPowerDiscountTime + 1
	end
	local goodsList = self:getPowerGoodsMetaList()
	local goodsId = nil
	for k, v in ipairs(goodsList) do
		if buyCnt == v.buyNum then
			goodsId = v.goodsId
		end
	end

	local valueConfig = Meta.BuyPowerValueConfig[buyCnt]
	return goodsId, valueConfig.gold, valueConfig.discount
end

function MergeModel:setTodayPerDayMap(key, value)
	--获取某个时间的每日信息
	local curTime = TimeKit:timeInSec()

	local perDayMap = self:getPerDayMap()
	local day = time2day(curTime)
	local todayPerDayMap = nil
	if perDayMap[''..day] then
		todayPerDayMap = perDayMap[''..day]
	else
		local todayPerDayMap = self:getEmptyPerDayInfo()
		perDayMap[''..day] = todayPerDayMap
	end
	-- 购买体力收集物处理
	if key == "buyPowerNum" then
		todayPerDayMap[key] = todayPerDayMap[key] + 1
	else
		todayPerDayMap[key] = value
	end
	self:setDataByKey("perDayMap", perDayMap)
end

function MergeModel:addTodayBuyPowerCostCash(goodsId)
	--冰冻棋子每日购买体力花费
	if not self:checkFrozenFoodBuyPowerGoods(goodsId) then
		return
	end

	local goodsObj = GoodsManager:getGoods(goodsId)
	local costCash = tonumber(goodsObj and goodsObj:getPrice()) or 0
	if costCash <= 0 then
		return
	end

	local todayPerDayMap = self:getTodayPerDayMap()
	local oldCostCash = tonumber(todayPerDayMap.buyPowerCostCash) or 0
	local newCostCash = oldCostCash + costCash
	self:setTodayPerDayMap("buyPowerCostCash", newCostCash)
end

function MergeModel:getCurCountryRank()
	return self:getDataByKey("countryRank")
end

function MergeModel:getCurGroupRank()
	return self:getDataByKey("groupRank")
end

function MergeModel:setCurGroupRank(rankNum)
	self:setDataByKey("groupRank", rankNum)
end

function MergeModel:checkHasGetGroupRankReward()
    return self:getDataByKey("groupReward")
end

function MergeModel:setHasGetGroupRankReward()
    self:setDataByKey("groupReward", true)
end

function MergeModel:getHasConvert()
    return self:getDataByKey("convert")
end

function MergeModel:setHasConvert()
    self:setDataByKey("convert", true)
end

-- 体力回复到60需要的秒数
function MergeModel:getPowerFullTimeInSec()
	if self:getPowerTotal() >= Meta.AutoAddMaxPowerConfig then
		return 0
	end
	local time1 = 10*60 - (TimeKit:timeInSec() - math.floor(self:getLastPowerTickTime()/1000))
	local time2 = (Meta.AutoAddMaxPowerConfig - self:getPowerTotal() - 1)*10*60
	return time1 + time2
end


function MergeModel:getCrushEggRewardConfig()
	local crushEggData = self:getDataByKey("crushEggData")
	local payTag = crushEggData.payTag
	local isGiftPaid = crushEggData.buySpecialGoods
	local freeRewardIndexList = crushEggData.freeRewardIndexList
	local crushGifts = self:getConfigByKey("crushGiftMetaList")
	local giftConfig = {}
	for i = 1, #crushGifts do
		if table.find(crushGifts[i].payTagIds, function (v) return v == payTag end)  then
			giftConfig = crushGifts[i]
		end
	end
	
	local freeGiftInfo = {}
	local isGotten = false
	if table.find(freeRewardIndexList, function (v) return v == 0 end) then isGotten = true end
	freeGiftInfo[1] = {
		isGotten = isGotten,
		rewards = giftConfig.freeList
	}
	if giftConfig.freeNum == 2 then
		isGotten = false
		if table.find(freeRewardIndexList, function (v) return v == 1 end) then isGotten = true end
		freeGiftInfo[2] = {
			isGotten = isGotten,
			rewards = giftConfig.freeList2
		}
	end

	return {
		isGiftPaid = isGiftPaid,
		goodsId = giftConfig.goodsId,
		freeGiftInfo = freeGiftInfo,
 	}
end

---------------------------------------------------------
----周年新增
function MergeModel:getCurWeek()
	local bGet, weekInfo = self:checkStepIsOpen(Meta.StepTypes.kWeekRank)
	local weekNum = 1 --默认认为是第一周
	if bGet then
		weekNum = weekInfo.periodId
	end
	return weekNum
end

function MergeModel:checkStepIsOpen( stepType )
	--检测活动是否开启,并返回内容
	local stepPeriodMetaList = self:getConfigByKey('stepPeriodMetaList')

	local curTime = TimeKit:timeInSec()*1000

	for i,v in ipairs(stepPeriodMetaList) do
		if v.stepType == stepType then
			if curTime >= tonumber(v.beginTime) and curTime <= tonumber(v.endTime) then
				return true, v
			end
		end
	end

	return false, {}
end


function MergeModel:getEndlessPowerData(  )
	local endLessPowerData = self:getDataByKey('endLessPowerData')
	return endLessPowerData
end

function MergeModel:updateEndlessPowerData( endLessPowerData )
	self:setDataByKey('endLessPowerData',endLessPowerData)
end

function MergeModel:addEndlessPowerData(  )
	local endlessPowerData = self:getEndlessPowerData()
	endlessPowerData.rewardIndex = endlessPowerData.rewardIndex + 1
	if endlessPowerData.rewardIndex %3 == 0 then
		endlessPowerData.unlockRound = endlessPowerData.unlockRound + 1
	end
	self:updateEndlessPowerData( endlessPowerData )
end

function MergeModel:getEndlessPowerMeta(  )
	local endlessPowerMeta = self:getConfigByKey('endlessPowerMetaList')
	return endlessPowerMeta
end

function MergeModel:getCircleEndLessRound(  )
	--获取无限体力循环的轮数
	local circleEndLessRound = self:getFlagFromLocalByKeyInt("circleEndLessRound")
	if circleEndLessRound ~= nil and circleEndLessRound > 0 then
		return circleEndLessRound
	else
		local endlessPowerMeta = self:getEndlessPowerMeta()
		for i,v in ipairs(endlessPowerMeta) do
			if v.circle then
				circleEndLessRound = v.round
				self:saveFlagToLocalByKeyInt("circleEndLessRound", false, circleEndLessRound)
				return circleEndLessRound
			end
		end
	end
end

function MergeModel:getEndlessConfigByRound( round )
	--根据轮数获取本轮的信息
	local endlessPowerMeta = self:getEndlessPowerMeta()

	local circleRound = self:getCircleEndLessRound()
	local findRound = round
	if round >= circleRound then
		findRound = circleRound
	end

	local configInfo = {}
	for i,v in ipairs(endlessPowerMeta) do
		if v.round == findRound then
			table.insert( configInfo, table.clone(v) )
		end
	end
	return configInfo
end

function MergeModel:getEndlessConfigByRewardIndex( rewardIndex )
	local endlessPowerMeta = self:getEndlessPowerMeta()
	local circleRound = self:getCircleEndLessRound()

	local circleStartRewardIndex = (circleRound-1)*3+1
	local findRewardIndex = rewardIndex
	if rewardIndex >= circleStartRewardIndex then
		--从循环里找
		local findPos = rewardIndex%3
		if findPos == 0 then findPos = 3 end

		findRewardIndex = circleStartRewardIndex + findPos - 1
	end

	local configInfo = {}
	for i,v in ipairs(endlessPowerMeta) do
		if v.rewardIndex == findRewardIndex then
			configInfo = table.clone(v)
			break
		end
	end
	return configInfo
end

function MergeModel:checkPKContinueWinReward(limitOrderData)
	if not limitOrderData then
		limitOrderData = self:getLimitOrderInfo() or {}
	end

	if not next(limitOrderData) then
		return false
	end
	local pkVictoryCnt = limitOrderData.pkVictoryNum or 0
	local pkRewardIndex = limitOrderData.pkProgressRewardId or 0
	return pkRewardIndex < math.floor(pkVictoryCnt/2)
end

function MergeModel:getPkVictoryNum()
	local limitOrderData = self:getLimitOrderInfo() or {}

	return limitOrderData.pkVictoryNum or 0
end

function MergeModel:canGetOpenEggDataFreeGiftCnt(eggData)
    if not eggData then
        eggData =  self:getDataByKey("crushEggData") or {mapData = {}}
    end

	if eggData.buySpecialGoods then
		if eggData.payTag >= Meta.highPayTag then
			return 2 - table.length(eggData.freeRewardIndexList)
		else
			return 1 - table.length(eggData.freeRewardIndexList)
		end
	end
    return 0
end

-- 检查砸蛋礼包免费是否还有 checkInPeriod活动期内检查
function MergeModel:checkOpenEggGift(eggData, checkInPeriod)
	if not eggData then
		eggData = self:getDataByKey("crushEggData") or {}
	end
	if not next(eggData) then
		return false
	end

	if not checkInPeriod then
		local bOpen, openConfig = self:checkStepIsOpen(Meta.StepTypes.kCrushEgg)
		if eggData.periodId == self:getCurWeek() and bOpen then
			return false
		end
	end

	if not eggData.buySpecialGoods then
		return false
	end

	local allClear = false
	if eggData.payTag >= Meta.highPayTag then
		allClear = table.length(eggData.freeRewardIndexList) >= 2
	else
		allClear = table.length(eggData.freeRewardIndexList) >= 1
	end
	if allClear then
		return false
	end

	return true
end

function MergeModel:checkOpenEggBigReward(eggData)
	if not eggData then
		eggData = self:getDataByKey("crushEggData") or {}
	end
	if not next(eggData) then
		return false
	end

	return eggData.chickNum >= Meta.openEggNeedChickenNum  and eggData.finalReward == false
end

function MergeModel:addOpenEggHammerCount(cnt)
	if not cnt then
		return
	end
	local eggData = self:getDataByKey("crushEggData") or {}
	if not next(eggData) then
		return
	end
	
	eggData.hammerNum = eggData.hammerNum + cnt
	self:setDataByKey("crushEggData", eggData)
end

function MergeModel:setOpenEggFinalReward(flag)
	local eggData = self:getDataByKey("crushEggData") or {}
	if not next(eggData) then
		return
	end
	
	eggData.finalReward = true
	self:setDataByKey("crushEggData", eggData)
end

function MergeModel:getPkWinRewardId()
	local limitFood = self:getLimitOrderInfo() or {}
    local winId = limitFood.pkProgressRewardId or 0
	return winId
end

function MergeModel:setOpenEggHammerConvert()
	local eggData = self:getDataByKey("crushEggData") or {}
	
	if not next(eggData) then
		return
	end
	-- todo设置convert
	eggData.convert = true
	eggData.hammerNum = 0
	self:setDataByKey("crushEggData", eggData)
end

function MergeModel:setLimitOrderConvert()
	local data = self:getLimitOrderInfo() or {}
	
	if not next(data) then
		return
	end
	local curWeek = self:getCurWeek()
	local bOpen, configTb = self:checkStepIsOpen(Meta.StepTypes.kDailyPK)
	-- 期数不对 或者 没开放
	if curWeek ~= data.periodId or (not bOpen) then
		data.convert = true
		self:setDataByKey("limitFoodOrder", data)
	end
end

-- 设置免费礼包全部领取
function MergeModel:setOpenEggFreeGift()
	local eggData = self:getDataByKey("crushEggData") or {}
	
	if not next(eggData) then
		return
	end
	eggData.freeRewardIndexList = {0, 1}
	self:setDataByKey("crushEggData", eggData)
end

function MergeModel:checkOpenEggNeedRefresh()
	local money = self:getMoney() or 0
    if money < Meta.OpenEggMoneyLimit then
        return false
    end

	local bOpen, configTb = self:checkStepIsOpen(Meta.StepTypes.kCrushEgg)
	if not bOpen then
		-- printx(42, "砸蛋未开启")
		return false
	end

	local eggData = self:getDataByKey("crushEggData") or {}
	local curWeek = self:getCurWeek()
	if not next(eggData) or eggData.periodId == 0 then
		-- printx(42, "砸蛋已经完成，请求新数据0")
		return true
	elseif eggData.periodId ~= curWeek 
		and not self:checkOpenEggGift(eggData) 
		and not self:checkOpenEggBigReward(eggData)
		and eggData.convert then
			-- printx(42, "砸蛋已经完成，请求新数据")
			return true
	end
	return false
end

function MergeModel:checkLimitOrderNeedRefresh()
	if not self:limitOrderIsUnlock() then
		return false
	end
	local bOpen, configTb = self:checkStepIsOpen(Meta.StepTypes.kDailyPK)
	if not bOpen then
		-- printx(42, "订单pk未开启")
		return false
	end
	local limitOrderData = self:getLimitOrderInfo() or {}
	if not next(limitOrderData) then
		-- printx(42, "pk已经完成，请求新数据0")
		return true  
	elseif not _G.amfBean("MergeManager"):isCurLimitOrderSameDay(limitOrderData) 
		and not self:checkLimitOrderPKReward(limitOrderData)
		and not self:checkLimitOrderProgressReward(limitOrderData)
		and not self:checkPKContinueWinReward(limitOrderData)
		and limitOrderData.convert then
			-- printx(42, "pk已经完成，请求新数据")
			return true
	end
	return false
end

-- 拿到全国周榜排名
function MergeModel:getWeekCountryRank(weekIndex)
	local weekDataList = self:getDataByKey("weekDataMap") or {}
	local weekData = weekDataList[weekIndex]
	if not weekData or (not next(weekData)) then
		return -1
	end

	return weekData.countryRank
end

function MergeModel:setPkWinRewardId(idx)
	local orderData = self:getLimitOrderInfo() or {}
	if not next(orderData) then
		return
	end
	
	orderData.pkProgressRewardId = idx
	self:setDataByKey("limitFoodOrder", orderData)
end


--发射器概率
function MergeModel:getItemMakerMakeItemRate( launcherId )
	local launcherMeta = self:getLauncherMetaById(launcherId)
	
	if launcherId == BoardMeta.ShiHeLV1 then
		local itemData = BoardMeta:getItemDataByItemId(launcherId)
		local itemList = itemData.makeItemList
		local rateList = {}

		for i,v in ipairs(itemList) do
			local itemId = v
			local itemData2 = BoardMeta:getItemDataByItemId(itemId)
			local itemType = itemData2.itemType
			
			if itemType == launcherMeta.foodType1 then
				table.insert( rateList, launcherMeta.foodType1Rate )
			elseif itemType == launcherMeta.foodType2 then
				table.insert( rateList, launcherMeta.foodType2Rate )
			end
		end
		return rateList[1] or 100, rateList[2] or 0
	end
	return 100, 0
end

------------
---折扣气泡
------------
function MergeModel:getFirBuyDiscountList()
	local discountFirstGoodsId = self:getDataByKey("discountFirstGoodsId")
	return discountFirstGoodsId or {}
end

function MergeModel:checkFistDiscountIsHadBuy( itemLevel )
	local discountFirstGoodsId = self:getFirBuyDiscountList()
	if table.exist(discountFirstGoodsId, itemLevel) then
		return true
	end
	return false
end

function MergeModel:setFistDiscountBuySucess( itemLevel )
	local discountFirstGoodsId = self:getFirBuyDiscountList()
	if not table.exist(discountFirstGoodsId, itemLevel) then
		table.insert(discountFirstGoodsId,itemLevel)
		self:setDataByKey("discountFirstGoodsId", discountFirstGoodsId)
	end
end

function MergeModel:getDiscountBubbleRateMeta()
	return self:getConfigByKey("discountBubbleRateMetaList") or {}
end

-- 按折扣气泡阶段区分周中和周末配置
function MergeModel:getCommonBubbleWeekType()
	return self:checkStepIsOpen(Meta.StepTypes.kBubbleDiscount) and 2 or 1
end

function MergeModel:getCommonBubbleRateMeta(powerLevel, bubbleType)
	powerLevel = tonumber(powerLevel)
	bubbleType = tonumber(bubbleType)
	local weekType = self:getCommonBubbleWeekType()
	if not powerLevel or not bubbleType or not weekType then return nil end

	for _, bubbleRateMeta in ipairs(self:getDiscountBubbleRateMeta()) do
		if tonumber(bubbleRateMeta.powerLevel) == powerLevel
			and tonumber(bubbleRateMeta.weekType) == weekType
			and tonumber(bubbleRateMeta.bubbleType) == bubbleType then
			return bubbleRateMeta
		end
	end
end

function MergeModel:getCommonBubbleRate(itemLevel, powerLevel, bubbleType)
	itemLevel = tonumber(itemLevel)
	if not itemLevel then return nil end

	local bubbleRateMeta = self:getCommonBubbleRateMeta(powerLevel, bubbleType)
	local rateKey = "bubble" .. itemLevel .. "Rate"
	return tonumber(bubbleRateMeta and bubbleRateMeta[rateKey])
end

function MergeModel:getBubbleCreateRate(itemLevel, powerLevel)
	return self:getCommonBubbleRate(itemLevel, powerLevel, 1)
end

function MergeModel:getNormalBubbleCreateRate(itemLevel, powerLevel)
	return self:getCommonBubbleRate(itemLevel, powerLevel, 2)
end

function MergeModel:getDiscountBubbleRate(itemLevel, powerLevel)
	return self:getCommonBubbleRate(itemLevel, powerLevel, 3)
end

function MergeModel:getBubbleSpecialRate(powerLevel)
	local bubbleRateMeta = self:getCommonBubbleRateMeta(powerLevel, 1)
	return tonumber(bubbleRateMeta and bubbleRateMeta.bubble4Special) or 0
end

--------

function MergeModel:checkCanMergeNewItemMaker( )
	--是否可以合成新发射器，只判断时间
	local curTime = TimeKit:timeInSec()
	local unlockTime = 1779033600
	return curTime > unlockTime
end

function MergeModel:getChooseFoodMeta( )
	--获取自选道具配置
	local chooseFoodMeta = self:getConfigByKey("chooseFoodMeta")
	return chooseFoodMeta
end


return MergeModel
