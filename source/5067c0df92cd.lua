local BaseFeatureModel = require "amf.middleware.activity.base.BaseFeatureModel"
local PetConfig = require "amf.feature.localactivity.pet.config.PetConfig"

local LOCAL_PATH = PetConfig.LOCAL_PATH

local PetModel = class("PetModel", BaseFeatureModel)

local GUIDE_ID_SET_KEY = "userInfo.guideIdSet"
local WING_AUTHORITY_KEY = "wingAuthority"
local WING_DAILY_LEFT_THROW_TIMES_KEY = "wingDailyLeftThrowTimes"

local function toSeconds(value)
    local numericValue = tonumber(value)
    if not numericValue then return nil end
    return tonumber(TimeKit:tryConvertMsToSec(numericValue))
end

function PetModel:_getConstPath()
    return LOCAL_PATH .. ".config.PetConfig"
end

function PetModel:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "PetModel"
    }):as("db")
end

function PetModel:__declare()
    self.userInfo = {}
    self.localConfig = {}
    self.configVersion = ""
    self.timeInfo = {}
    self.localCache = {}
    self.dcQualify = false
    self.wingAuthority = {}
    self.packagesPullResponse = {}
    self.dcQualify = false
    self._wingSwitchEnabled = nil
end


function PetModel:clearLocalData()
    self:setValue("userInfo", {})
    self:setValue("data", {})
end

function PetModel:_isSuccessData(data)
    if not data then return false end
    return data.ret == nil or tonumber(data.ret) == 0
end

function PetModel:_toBool(value, default)
    if value == nil then return default end
    return value == true or value == 1 or value == "1" or value == "true"
end

function PetModel:_arrayToMap(list, value)
    local map = {}
    for _, id in ipairs(list or {}) do
        map[tostring(id)] = value == nil and true or value
    end
    return map
end

function PetModel:_appendUnique(list, value)
    if value == nil then return end
    list = list or {}
    local key = tostring(value)
    for _, item in ipairs(list) do
        if tostring(item) == key then return list end
    end
    table.insert(list, value)
    return list
end

function PetModel:fromServer(data)
    if type(data) ~= "table" then return end
    for k, v in pairs(data) do
        self:setValue(k, v)
    end
end

function PetModel:_splitNumberList(value)
    if type(value) ~= "string" then return value end

    local list = {}
    for item in string.gmatch(value, "[^,]+") do
        local num = tonumber(item)
        if num ~= nil then
            table.insert(list, num)
        end
    end
    return list
end

function PetModel:_normalizeFoodMeta(foodMeta)
    if type(foodMeta) ~= "table" then return end

    if foodMeta.foodItemId == nil then
        foodMeta.foodItemId = foodMeta.itemId or foodMeta.feedItemId or foodMeta.foodCollectionId
    end
end

function PetModel:_normalizeLocalConfig(localConfig)
    if type(localConfig) ~= "table" then return localConfig end

    local config = localConfig.config or localConfig
    if type(config) ~= "table" then return localConfig end

    config.feedMultipliers = self:_splitNumberList(config.feedMultipliers)

    if type(config.foodMetas) == "table" then
        for _, foodMeta in pairs(config.foodMetas) do
            self:_normalizeFoodMeta(foodMeta)
        end
    end

    return localConfig
end

function PetModel:_getServerDay(time)
    local currentTime = toSeconds(time) or TimeKit:timeInSec()
    return TimeKit:getDayStartTimeByTS(currentTime)
end

function PetModel:_getWingDeco(enableDecos)
    return self:_getDecoByPart(enableDecos, PetConfig.DecoPartType.Wing)
end

function PetModel:_getDecoByPart(enableDecos, partType)
    if type(enableDecos) ~= "table" then return nil end
    return enableDecos[partType] or enableDecos[tostring(partType)]
end

function PetModel:_buildWingProgress(wing)
    wing = wing or self:getDataByKey("wing", {})
    return {
        continuousLoginDays = tonumber(wing.continuousLoginDays) or 0,
        unlockProgressDays = tonumber(wing.unlockProgressDays) or 0,
        needUnlockDays = tonumber(wing.needUnlockDays) or 0,
    }
end

function PetModel:_buildWingSummary()
    return {
        activated = self:isWingActivated(),
    }
end

function PetModel:_updateWingTransition(before, after, source, optimistic)
    if before.activated == after.activated then return end

    local transition = {
        fromActivated = before.activated,
        toActivated = after.activated,
        source = source,
        serverDay = self:_getServerDay(),
        optimistic = optimistic == true,
    }
    self:setValue(WING_AUTHORITY_KEY .. ".lastTransition", transition)
end

function PetModel:_installPetActivityInfo(payload)
    local wing = payload.data.wing
    local userInfo = table.clone(self:getData(), true)
    userInfo.wing = table.clone(wing, true)
    userInfo.enableDecos = table.clone(payload.data.enableDecos, true)
    userInfo[PetConfig.DeprecatedDataKey.WEARING_DECOS] = nil
    self:setValue("userInfo", userInfo)

    if payload.config ~= nil then
        self:setValue("localConfig", self:_normalizeLocalConfig(table.clone(payload.config, true)))
    end
    self:setValue("configVersion", payload.configVersion)
    self:setValue("packagesPullResponse", table.clone(payload.packagesPullResponse or {}, true))

    self:setValue(WING_AUTHORITY_KEY .. ".lastValidServerLoginDay", self:_getServerDay())
end

function PetModel:_installGetActInfo(payload)
    local userInfo = table.clone(self:getData(), true)
    userInfo[PetConfig.DeprecatedDataKey.WEARING_DECOS] = nil
    userInfo.enableDecos = table.clone(payload.enableDecos, true)
    if payload.wingBeginTs ~= nil then
        userInfo.wingBeginTs = payload.wingBeginTs
    end
    if payload.wingEndTs ~= nil then
        userInfo.wingEndTs = payload.wingEndTs
    end
    self:setValue("userInfo", userInfo)
end

function PetModel:_installServerPayload(source, payload, shouldFlush)
    local before = self:_buildWingSummary()
    if source == PetConfig.ServerPayloadSource.PET_ACTIVITY_INFO then
        self:_installPetActivityInfo(payload)
    elseif source == PetConfig.ServerPayloadSource.GET_ACT_INFO then
        self:_installGetActInfo(payload)
    end

    local after = self:_buildWingSummary()
    self:_updateWingTransition(before, after, source, false)
    if shouldFlush ~= false then
        self:flush()
    end
end

function PetModel:installServerPayload(source, payload)
    self:_installServerPayload(source, payload, true)
end

function PetModel:updateTimeInfo(time)
    if type(time) ~= "table" then return end

    local timeInfo = self:getValue("timeInfo") or {}
    for key, value in pairs(time) do
        if value ~= nil then
            timeInfo[key] = value
        end
    end
    self:setValue("timeInfo", timeInfo)
end

function PetModel:updateMainInfo(data, init)
    if init then
        self:setValue("_wingSwitchEnabled", self:_resolveWingSwitchEnabled())
        printx(44, "self._wingSwitchEnabled", self._wingSwitchEnabled)
    end

    self:_installServerPayload(PetConfig.ServerPayloadSource.PET_ACTIVITY_INFO, {
        data = data.userInfo,
        config = data.localConfig,
        configVersion = data.configVersion,
        packagesPullResponse = data.packagesPullResponse,
    }, false)

    local currentUserInfo = self:getData()
    local userInfo = table.clone(data.userInfo, true)
    userInfo.wing = type(currentUserInfo.wing) == "table" and table.clone(currentUserInfo.wing, true) or nil
    userInfo.enableDecos = type(currentUserInfo.enableDecos) == "table"
        and table.clone(currentUserInfo.enableDecos, true) or nil
    userInfo[PetConfig.DeprecatedDataKey.WEARING_DECOS] = nil
    userInfo.wingBeginTs = currentUserInfo.wingBeginTs
    userInfo.wingEndTs = currentUserInfo.wingEndTs
    self:setValue("userInfo", userInfo)

    for key, value in pairs(data) do
        if key ~= "userInfo" and key ~= "localConfig" and key ~= "configVersion"
            and key ~= "packagesPullResponse"
            and key ~= "periodBeginTime" and key ~= "periodMainBeginTime"
            and key ~= "periodMainEndTime" and key ~= "periodEndTime"
        then
            self:setValue(key, value)
        end
    end
    self:flush()
end

function PetModel:getConfig()
    local localConfig = self:getValue("localConfig")
    if type(localConfig) ~= "table" then
        return {}
    end
    return localConfig.config or localConfig
end

function PetModel:getData()
    return self:getValue("userInfo") or {}
end

function PetModel:getDataByKey(key, default, copyTable)
    local value = self:getData()[key]
    if value == nil then
        return default
    end
    if copyTable and type(value) == "table" then
        return table.clone(value, true)
    end
    return value
end

function PetModel:getSettings()
    return {
        showInLevelPet = self:isShowPetEnabled(),
    }
end

function PetModel:getInLevelPetNotify()
    return self:getValue("inLevelPetNotify") or {}
end

function PetModel:getInitDecoList()
    return self:getConfigByKey("initDecoList", {})
end

function PetModel:setLocalCache(key, value)
    if key == nil then return end
    self:setValue("localCache." .. key, value)
end

function PetModel:getLocalCache(key)
    if key == nil then return nil end
    return self:getValue("localCache." .. key)
end

function PetModel:getClientMd5()
    return self:getValue("configVersion") or ""
end


function PetModel:getBeginTime()
    return self:getValue("timeInfo.beginTime") or 0
end

function PetModel:getMainBeginTime()
    return self:getValue("timeInfo.mainBeginTime") or 0
end

function PetModel:getMainEndTime()
    return self:getValue("timeInfo.mainEndTime") or 0
end

function PetModel:getEndTime()
    return self:getValue("timeInfo.endTime") or 0
end

function PetModel:isDataEnabled()
    local localConfig = self:getValue("localConfig")
    if not localConfig or table.isEmpty(localConfig) then
        return false
    end

    local data = self:getValue("data")
    local userInfo = self:getValue("userInfo")
	if (not data or table.isEmpty(data)) and (not userInfo or table.isEmpty(userInfo)) then
        return false
    end

    return true
end

function PetModel:isInPreheatTime()
    local now = TimeKit:timeInSec()
    return now >= self:getBeginTime() and now < self:getMainBeginTime()
end

function PetModel:isInMainTime()
    local now = TimeKit:timeInSec()
    return now >= self:getMainBeginTime() and now < self:getMainEndTime()
end

function PetModel:isInRewardTime()
    local now = TimeKit:timeInSec()
    return now >= self:getMainEndTime() and now < self:getEndTime()
end

function PetModel:isOpen()
    local now = TimeKit:timeInSec()
    local beginTime = toSeconds(self:getBeginTime()) or 0
    local endTime = toSeconds(self:getEndTime()) or 0
    return now >= beginTime and now < endTime
end

function PetModel:getFreshness()
    local storedAuthority = self:getValue(WING_AUTHORITY_KEY) or {}
    local currentServerDay = self:_getServerDay()
    local lastValidServerLoginDay = tonumber(storedAuthority.lastValidServerLoginDay)
    return {
        currentServerDay = currentServerDay,
        lastValidServerLoginDay = lastValidServerLoginDay,
        isFresh = lastValidServerLoginDay == tonumber(currentServerDay),
    }
end

function PetModel:_isWingContextAvailable()
    if not self:isDataEnabled() then return false end
    if not self:isOpen() then return false end
    if not self:isClientVersionMatch() then return false end
    return self:getFreshness().isFresh == true
end

function PetModel:_resolveWingSwitchEnabled()
    if not MaintenanceManager or not MaintenanceManager.getInstance then return true end
    return not MaintenanceManager:getInstance():isEnabledInGroup(
        PetConfig.WingSwitch.NAME,
        PetConfig.WingSwitch.CLOSED_GROUP
    )
end

function PetModel:_isWingSwitchEnabled()
    return self._wingSwitchEnabled ~= false
end

function PetModel:getWingFeatureTiming(currentTime)
    local now = toSeconds(currentTime) or TimeKit:timeInSec()
    local beginTimeValue = self:getDataByKey("wingBeginTs")
    local endTimeValue = self:getDataByKey("wingEndTs")
    local beginTime = toSeconds(beginTimeValue)
    local endTime = toSeconds(endTimeValue)
    local contextAvailable = self:_isWingContextAvailable()
    local afterBegin = beginTime == nil or beginTime == 0 or now >= beginTime
    local beforeEnd = endTime == 0 or (endTime ~= nil and now < endTime)
    local featureEnabled = self:_isWingSwitchEnabled()
        and contextAvailable
        and afterBegin
        and beforeEnd

    return {
        currentTs = now,
        beginTs = beginTime,
        endTs = endTime,
        featureEnabled = featureEnabled,
        countdownVisible = featureEnabled and endTime ~= nil and endTime > 0,
        remainingSeconds = featureEnabled and endTime and endTime > 0 and math.max(0, endTime - now) or 0,
    }
end

function PetModel:isWingFeatureEnabled(currentTime)
    return self:getWingFeatureTiming(currentTime).featureEnabled == true
end

function PetModel:getEnabledDecoMap()
    return table.clone(self:getDataByKey("enableDecos", {}), true)
end

function PetModel:isWingActivated()
    local wingDeco = self:_getWingDeco(self:getDataByKey("enableDecos", {}))
    return type(wingDeco) == "table" and self:_toBool(wingDeco.enable, false) == true
end

function PetModel:getWingDailyLeftThrowTimes()
    return tonumber(self:getDataByKey(WING_DAILY_LEFT_THROW_TIMES_KEY))
end

function PetModel:consumeWingDailyThrowTime()
    local leftThrowTimes = self:getWingDailyLeftThrowTimes()
    if leftThrowTimes == nil or leftThrowTimes <= 0 then
        return false
    end

    self:setDataByKey(WING_DAILY_LEFT_THROW_TIMES_KEY, math.max(0, leftThrowTimes - 1), true)
    return true
end

function PetModel:isWingEffective(currentTime)
    return self:isWingFeatureEnabled(currentTime) and self:isWingActivated()
end

function PetModel:getWingProgress()
    return self:_buildWingProgress()
end

function PetModel:getPackageData()
    return table.clone(self:getValue("packagesPullResponse") or {}, true)
end

function PetModel:getWingTransition()
    local transition = self:getValue(WING_AUTHORITY_KEY .. ".lastTransition")
    if type(transition) ~= "table" then return nil end
    return {
        fromActivated = transition.fromActivated,
        toActivated = transition.toActivated,
        source = transition.source,
        serverDay = transition.serverDay,
        optimistic = transition.optimistic,
    }
end

function PetModel:getWingFrequencyContext()
    local freshness = self:getFreshness()
    return {
        serverDay = freshness.currentServerDay,
        isFresh = freshness.isFresh,
        transition = self:getWingTransition(),
    }
end

function PetModel:hasShownMainPanel(serverDay)
    local shownServerDay = self:getLocalCache(PetConfig.WingAutoPop.MAIN_PANEL_SHOWN_DAY_KEY)
    return tonumber(shownServerDay) == tonumber(serverDay)
end

function PetModel:markMainPanelShown(serverDay)
    self:setLocalCache(PetConfig.WingAutoPop.MAIN_PANEL_SHOWN_DAY_KEY, serverDay)
    self:flush()
end

function PetModel:hasShownWingPanel(serverDay)
    local shownServerDay = self:getLocalCache(PetConfig.WingAutoPop.PANEL_SHOWN_DAY_KEY)
    return tonumber(shownServerDay) == tonumber(serverDay)
end

function PetModel:markWingPanelShown(serverDay)
    self:setLocalCache(PetConfig.WingAutoPop.PANEL_SHOWN_DAY_KEY, serverDay)
    self:flush()
end

function PetModel:hasConsumedWingDailyProgressAnimation(serverDay)
    local consumedServerDay = self:getLocalCache(
        PetConfig.WingAutoPop.DAILY_PROGRESS_ANIMATION_DAY_KEY
    )
    return tonumber(consumedServerDay) == tonumber(serverDay)
end

function PetModel:markWingDailyProgressAnimationConsumed(serverDay)
    serverDay = tonumber(serverDay) or self:_getServerDay()
    self:setLocalCache(PetConfig.WingAutoPop.DAILY_PROGRESS_ANIMATION_DAY_KEY, serverDay)
    self:flush()
end

function PetModel:applyPurchaseOptimisticActivation()
    local userInfo = table.clone(self:getData(), true)
    local wing = userInfo.wing
    local needLoginDays = tonumber(self:getConfigByKey("wingNeedLoginDays"))
    local wingDeco = self:_getWingDeco(userInfo.enableDecos)
    local before = self:_buildWingSummary()
    wing.unlockProgressDays = needLoginDays
    wing.needUnlockDays = 0
    wingDeco.enable = true
    self:setValue("userInfo", userInfo)

    local after = self:_buildWingSummary()
    self:_updateWingTransition(before, after, "purchase", true)
    self:flush()
end

function PetModel:isClientVersionMatch()
    return tonumber(self:getConfigByKey("clientVersion", 0)) == tonumber(PetConfig.clientVersion)
end

function PetModel:setClientVersion(clientVersion)
    self:setConfigByKey("clientVersion", clientVersion)
end



function PetModel:getConfigByKey(key, default)
    local config = self:getConfig()
    if config and config[key] ~= nil then
        if type(config[key]) == "table" then
            return table.clone(config[key], true)
        end
        return config[key]
    end
    return default
end

function PetModel:isActivated()
    local data = self:getData()
    if data.activated ~= nil then
        return data.activated == true
    end
    return true --self:getWearingDecoByPart(PetConfig.DecoPartType.Image) ~= 0
end

function PetModel:getLevel()
    return tonumber(self:getData().level) or 1
end

function PetModel:getExp()
    return tonumber(self:getData().exp) or 0
end

function PetModel:getLevelConfig(level)
    level = tonumber(level) or self:getLevel()
    local levelConfigList = self:getConfigByKey("levelMetas", {})
    for _, cfg in ipairs(levelConfigList) do
        if tonumber(cfg.level) == level then
            return cfg
        end
    end
    return {}
end

function PetModel:getCurLevelNeedExp()
    local cfg = self:getLevelConfig(self:getLevel())
    return tonumber(cfg.needTotalExp) or 0
end

function PetModel:getFeedItemId()
    local foodMeta = self:getFoodMeta()
    return foodMeta and (foodMeta.foodItemId or foodMeta.foodCollectionId) or PetConfig.defaultFeedItemId
end

function PetModel:getFoodMetas()
    return self:getConfigByKey("foodMetas", {}, true) or {}
end

function PetModel:getFoodMeta(foodItemId)
    local foodMetas = self:getConfigByKey("foodMetas", {})
    if type(foodMetas) ~= "table" then return nil end
    if foodItemId ~= nil then
        for _, foodMeta in ipairs(foodMetas) do
            if tostring(foodMeta.foodItemId or foodMeta.foodCollectionId) == tostring(foodItemId) then
                return foodMeta
            end
        end
        return nil
    end
    return foodMetas[1]
end

function PetModel:getFoodNum(foodItemId)
    local mainData = self:getData()
    local foodMap = mainData.foodMap
    local feedItemId = foodItemId or self:getFeedItemId()
    if type(foodMap) == "table" and feedItemId ~= nil then
        local value = foodMap[tostring(feedItemId)] or foodMap[tonumber(feedItemId)]
        if value ~= nil then
            return tonumber(value) or 0
        end
    end
    return tonumber(mainData.foodNum) or 0
end

function PetModel:getFoodMap()
    return table.clone(self:getData().foodMap or {}, true)
end

function PetModel:getFeedExp(foodItemId)
    local feed = self:getConfigByKey("feed", {})
    local foodMeta = self:getFoodMeta(foodItemId or self:getFeedItemId())
    if foodMeta then
        return tonumber(foodMeta.foodToExp or foodMeta.feedExpValue or 1) or 1
    end
    return tonumber(feed.foodToExp or self:getConfigByKey("feedExp", 1)) or 1
end

function PetModel:getFeedMultipleList()
    local feed = self:getConfigByKey("feed", {})
    local multipliers = self:_splitNumberList(self:getConfigByKey("feedMultipliers"))
    if type(multipliers) == "table" and #multipliers > 0 then
        return multipliers
    end
    return feed.supportFeedMultiple or PetConfig.defaultFeedMultipleList
end

function PetModel:getMaxFeedNumPerRequest()
    local feed = self:getConfigByKey("feed", {})
    return tonumber(feed.maxFeedNumPerRequest) or 0
end

function PetModel:getSelectedFeedMultiple()
    local multiple = self:getLocalCache("selectedFeedMultiple")
    if multiple then return multiple end
    local list = self:getFeedMultipleList()
    return list[1] or 1
end

function PetModel:setSelectedFeedMultiple(multiple)
    self:setLocalCache("selectedFeedMultiple", multiple or 1)
end

function PetModel:getRewardedLevels()
    return self:getData().rewardedLevels or {}
end

function PetModel:getRewardedLevelMap()
    return self:_arrayToMap(self:getRewardedLevels())
end

function PetModel:getCanRewardLevels()
    return self:getData().canRewardLevels or {}
end

function PetModel:getCanRewardLevelMap()
    return self:_arrayToMap(self:getCanRewardLevels())
end

function PetModel:isFinalLevelMaxExpReached()
    local levelMetas = self:getConfigByKey("levelMetas", {})
    if type(levelMetas) ~= "table" or #levelMetas <= 0 then
        return false
    end
    local finalNeedTotalExp = tonumber(levelMetas[#levelMetas].needTotalExp)
    return finalNeedTotalExp ~= nil and self:getExp() >= finalNeedTotalExp
end

function PetModel:isLevelRewarded(level)
    return self:getRewardedLevelMap()[tostring(level)] == true
end

function PetModel:canClaimReward(level)
    if level ~= nil then
        return self:getCanRewardLevelMap()[tostring(level)] == true
    end
    return #(self:getCanRewardLevels()) > 0
end

function PetModel:isFoodNumEnough()
    local levelMetas = self:getConfigByKey("levelMetas", {})
    if type(levelMetas) ~= "table" or #levelMetas <= 0 then
        return false
    end

    local targetNeedExp = 0
    for _, cfg in ipairs(levelMetas) do
        targetNeedExp = math.max(targetNeedExp, tonumber(cfg.needTotalExp) or 0)
    end

    if targetNeedExp <= 0 then
        return false
    end

    local totalExp = self:getExp()
    for _, foodMeta in ipairs(self:getFoodMetas()) do
        local foodItemId = foodMeta.foodItemId or foodMeta.foodCollectionId
        local foodNum = self:getFoodNum(foodItemId)
        local feedExp = self:getFeedExp(foodItemId)
        totalExp = totalExp + foodNum * feedExp
    end

    return totalExp >= targetNeedExp
end

function PetModel:hasReward()
    return self:canClaimReward()
end

function PetModel:getOwnedDecos()
    return self:getData().ownedDecos or {}
end

function PetModel:getOwnedDecoMap()
    return self:_arrayToMap(self:getOwnedDecos())
end

function PetModel:hasOwnedDeco(decoId)
    return self:getOwnedDecoMap()[tostring(decoId)] == true
end

function PetModel:getWearingDecos()
    return self:getWearingDecoMap()
end

function PetModel:getWearingDecoMap()
    local map = {}
    local enableDecos = self:getDataByKey("enableDecos", {})
    if type(enableDecos) ~= "table" then
        return map
    end

    for partType, decoInfo in pairs(enableDecos) do
        if type(decoInfo) == "table" and self:_toBool(decoInfo.enable, false) then
            map[tostring(partType)] = tonumber(decoInfo.itemId) or decoInfo.itemId or 0
        end
    end
    return map
end

function PetModel:getWearingDecoByPart(partType)
    return self:getWearingDecoMap()[tostring(partType)] or 0
end

function PetModel:getNewDecos()
    return self:getData().newDecos or {}
end

function PetModel:getNewDecoMap()
    return self:_arrayToMap(self:getNewDecos())
end

function PetModel:isNewDeco(decoId)
    return self:getNewDecoMap()[tostring(decoId)] == true
end


function PetModel:getActId()
    return self:getConst().actId
end

function PetModel:getPeriodId()
    return self:getConfigByKey("periodId", 0)
end


function PetModel:_getGuideIdSet()
    local guideIdSet = self:getValue(GUIDE_ID_SET_KEY)
    if type(guideIdSet) ~= "table" then
        guideIdSet = {}
        self:setValue(GUIDE_ID_SET_KEY, guideIdSet)
    end
    return guideIdSet
end

function PetModel:_setGuideIdSet(guideIdSet, flush)
    if type(guideIdSet) ~= "table" then
        guideIdSet = {}
    end
    self:setValue(GUIDE_ID_SET_KEY, guideIdSet, flush)
end

function PetModel:hasGuideId(guideId)
    return table.exist(self:_getGuideIdSet(), guideId)
end

function PetModel:addGuideId(guideId)
    local guideIdSet = self:_getGuideIdSet()
    if not table.exist(guideIdSet, guideId) then
        table.insert(guideIdSet, guideId)
        self:_setGuideIdSet(guideIdSet)
    end
    self:flush()
end

function PetModel:getSetting(key, default)
    local value = self:getDataByKey(key)
    if value ~= nil then
        return value
    end
    return default
end

function PetModel:isShowPetEnabled()
    return self:_toBool(self:getDataByKey("showInLevelPet", true), true) == true
end

function PetModel:updateFeedData(data)
    if not data or not self:_isSuccessData(data) then return false end
    local mainData = table.clone(self:getData())
    if data.foodMap ~= nil then mainData.foodMap = data.foodMap end
    if data.exp ~= nil then mainData.exp = data.exp end
    if data.level ~= nil then mainData.level = data.level end
    if data.canRewardLevels ~= nil then mainData.canRewardLevels = data.canRewardLevels end
    self:setValue("userInfo", mainData)
    self:flush()
    return true
end

function PetModel:addDecoRewards(decoRewards)
    if type(decoRewards) ~= "table" then return false end

    local mainData = table.clone(self:getData(), true)
    mainData.ownedDecos = table.clone(mainData.ownedDecos or {})
    mainData.newDecos = table.clone(mainData.newDecos or {})

    for _, deco in ipairs(decoRewards) do
        local decoId = deco and (deco.itemId or deco.decoId)
        if decoId then
            self:_appendUnique(mainData.ownedDecos, decoId)
            self:_appendUnique(mainData.newDecos, decoId)
        end
    end

    self:setValue("userInfo", mainData)
    self:flush()
    return true
end


function PetModel:updateClaimRewardData(data)
    if not data or not self:_isSuccessData(data) then return false end
    local mainData = table.clone(self:getData())
    self:setLocalCache("lastRewardList", data.rewardList or {})
    self:setLocalCache("lastDecoRewards", data.decoRewards or {})

    if data.rewardedLevels ~= nil then
        mainData.rewardedLevels = data.rewardedLevels
    end
    if data.canRewardLevels ~= nil then
        mainData.canRewardLevels = data.canRewardLevels
    end
    if data.foodMap ~= nil then mainData.foodMap = data.foodMap end
    if data.foodNum ~= nil then mainData.foodNum = data.foodNum end
    if data.exp ~= nil then mainData.exp = data.exp end
    if data.level ~= nil then mainData.level = data.level end

    mainData.ownedDecos = table.clone(mainData.ownedDecos or {})
    mainData.newDecos = table.clone(mainData.newDecos or {})
    for _, deco in ipairs(data.decoRewards or {}) do
        local decoId = deco.itemId or deco.decoId
        self:_appendUnique(mainData.ownedDecos, decoId)
        self:_appendUnique(mainData.newDecos, decoId)
    end
    self:setValue("userInfo", mainData)
    self:flush()
    return true
end

function PetModel:updateWearingDeco(partType, decoId)
    if type(partType) == "table" then
        decoId = partType.itemId or partType.decoId
        partType = partType.partType
    end
    if partType == nil then return false end

    local mainData = table.clone(self:getData(), true)
    local enableDecos = table.clone(mainData.enableDecos or {}, true)
    local decoInfo = self:_getDecoByPart(enableDecos, partType)
    if type(decoInfo) ~= "table" then return false end

    decoInfo.itemId = tonumber(decoId) or decoId or 0
    mainData.enableDecos = enableDecos
    mainData[PetConfig.DeprecatedDataKey.WEARING_DECOS] = nil
    self:setValue("userInfo", mainData)
    self:flush()
    return true
end

function PetModel:updateWearingDecos(wearingDecos)
    if type(wearingDecos) ~= "table" then return false end

    local mainData = table.clone(self:getData(), true)
    local enableDecos = table.clone(mainData.enableDecos or {}, true)
    local existingPartTypes = {
        PetConfig.DecoPartType.Image,
        PetConfig.DecoPartType.Accessory,
        PetConfig.DecoPartType.Eye,
        PetConfig.DecoPartType.Wing,
    }
    for _, partType in ipairs(existingPartTypes) do
        local decoInfo = self:_getDecoByPart(enableDecos, partType)
        if type(decoInfo) == "table" then
            decoInfo.itemId = 0
        end
    end

    for _, wearingDeco in ipairs(wearingDecos) do
        local partType = type(wearingDeco) == "table" and wearingDeco.partType
        local decoId = type(wearingDeco) == "table" and wearingDeco.decoId
        local decoInfo = self:_getDecoByPart(enableDecos, partType)
        if type(decoInfo) ~= "table" then return false end
        decoInfo.itemId = tonumber(decoId) or decoId or 0
    end

    mainData.enableDecos = enableDecos
    mainData[PetConfig.DeprecatedDataKey.WEARING_DECOS] = nil
    self:setValue("userInfo", mainData)
    self:flush()
    return true
end

function PetModel:updateSetting(key, value)
    local mainData = table.clone(self:getData())
    if type(key) == "table" then
        for k, v in pairs(key) do
            mainData[k] = v
        end
    elseif key ~= nil then
        mainData[key] = value
    end

    self:setValue("userInfo", mainData)
    self:flush()
    return true
end

function PetModel:updateGuideData(data)
    if not data or not self:_isSuccessData(data) then return false end
    self:_setGuideIdSet(data.guideIdSet or {}, true)
    self:flush()
    return true
end

function PetModel:markDecoViewed(decoId)
    local mainData = table.clone(self:getData())
    local newDecos = {}
    for _, id in ipairs(mainData.newDecos or {}) do
        if tostring(id) ~= tostring(decoId) then
            table.insert(newDecos, id)
        end
    end
    mainData.newDecos = newDecos
    self:setValue("userInfo", mainData)
    self:flush()
    return true
end

function PetModel:getCurConfigMd5()
    local localConfig = self:getValue("localConfig")
    if localConfig and localConfig.configVersion and not table.isEmpty(localConfig.config) then
        return localConfig.configVersion
    end
    return ""
end

function PetModel:getNoHugeBuffData()
    return self:getDataByKey("noHugeBuffData", {})
end

function PetModel:getNoHugeBuffConfig()
    return self:getConfigByKey("noHugeBuffConfig", {})
end

function PetModel:getUBFuuuConfig()
    return self:getConfigByKey("ubfuuuEnd", {})
end

function PetModel:updateNoHugeBuffData(data)
    if type(data) ~= "table" then return end
    printx(44, "updateNoHugeBuffData", tts(data))
    local noHugeBuffData = table.clone(self:getNoHugeBuffData() or {}, true)
    printx(44, "noHugeBuffData", tts(noHugeBuffData))
    for key, value in pairs(data) do
        noHugeBuffData[key] = value
    end
    printx(44, "final noHugeBuffData", tts(noHugeBuffData))
    self:setDataByKey("noHugeBuffData", noHugeBuffData)
    printx(44, "getNoHugeBuffData()", tts(self:getNoHugeBuffData()))
end

return PetModel
