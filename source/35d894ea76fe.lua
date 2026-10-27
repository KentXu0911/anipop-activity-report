local BaseFeatureModel = require "amf.middleware.activity.base.BaseFeatureModel"
local WeekTaskEventCenter = require 'amf.feature.localactivity.weektask.event.WeekTaskEventCenter'
local Model = class("MusicMergeModel", BaseFeatureModel)

local flowerBoodHandStart = 20000
local flowerBoodHandEnd = 29999

function Model:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "MusicMergeModel"
    }):as("db")
    self:installPlug(AMFDataPlugsType.SYNC, {
        requests = {
            packagepull ='amf.feature.localactivity.musicmerge.http.RequestMusicMergePackagePull',
            activityaction ='amf.feature.localactivity.musicmerge.http.RequestActivityAction',
        }
    })
end

function Model:_getConstPath()
	return "amf.feature.localactivity.musicmerge.const.MusicMergeConst"
end

function Model:__declare()
    self.userInfo = {}
    self.localConfig = {}
    self.packageInfo = {}
    self.clientMd5 = ""
    self.timeInfo = {}
    self.dayPopGift = nil
    -- localKey
    self.firstOpenMain = false
    self.dailyOpenMain = false
    self.yinLiuPopCnt = 0
    self.dailyPopGift = false
    self.iconTip_1 = false
    self.iconTip_2 = false
    self.iconTip_3 = false
    self.beforeBattlePass = 0
    self.NotShowToday = false
    self.todayCostEnergy = 0
    self.bpTipIndex = 0
    self.dcQualify = false
    self.dcJoin = false
    self.firstBattlePassReward = false
end

function Model:fromServer(data)
    for k, v in pairs(data) do
        self:setValue(k, v)
    end

    -- printx(36, tts(self.userInfo), tts(self.localConfig))
end

function Model:clearData()
    if not self:isDataEnabled() then return end
    local buff20EndTs = self:getDataByKey("buff20EndTs") or 0
    local buff50EndTs = self:getDataByKey("buff50EndTs") or 0
    BaseFeatureModel.clearData(self)
    self:setDataByKey("buff20EndTs", buff20EndTs)
    self:setDataByKey("buff50EndTs", buff50EndTs)
end

function Model:getConfigByKey(key, default)
    local ret = BaseFeatureModel.getConfigByKey(self, key, default)
    if type(ret) == "table" then
        return table.clone(ret)
    end
    return ret
end

function Model:setGuide( index )
	local guideInfo = self:getDataByKey("guides", {})
	table.insert(guideInfo, index)
	self:setDataByKey("guides", guideInfo)
end

function Model:hasGuide( index )
	local guideInfo = self:getDataByKey("guides", {}, false)
	return table.find(guideInfo, function ( v )
		return v == index
	end)
end

function Model:getBeginTime()
    local key = self:_getTimeKey("beginTime")
    return math.floor((self:getValue(key) or 0) / 1000)
end

function Model:getMainBeginTime()
    local key = self:_getTimeKey("mainBeginTime")
    return math.floor((self:getValue(key) or 0) / 1000)
end

function Model:getEndTime()
    local key = self:_getTimeKey("endTime")
    return math.floor((self:getValue(key) or 0) / 1000)
end

function Model:getMainEndTime()
    local key = self:_getTimeKey("mainEndTime")
    return math.floor((self:getValue(key) or 0) / 1000)
end

function Model:updateTimeInfo(time)
    self:setValue("timeInfo", time)
end

function Model:isDataEnabled()
    local localConfig = self:getValue("localConfig")
    if not localConfig or table.isEmpty(localConfig) then
        return false
    end

    local userInfo = self:getValue("userInfo")
	if not userInfo or not userInfo.mapData then
        return false
    end

    return true
end

function Model:getClientMd5()
    return self:getValue("clientMd5") or ""
end

function Model:passDayRefreshData()
    local packageId = self:getPackageIdByType("FLOW")
    if packageId then
        self:setDisplayablePackagesById(packageId, nil)
    end
    self:setTodayCostEnergy(0)
end

function Model:getPeriodId()
    return self:getDataByKey("periodId", 0)
end

function Model:setPeriodId(id)
    self:setDataByKey("periodId", id)
end

function Model:getMapData()
    return self:getDataByKey("mapData", {})
end

function Model:setMapData(data)
    self:setDataByKey("mapData", data)
end

function Model:getMapStage()
    return self:getDataByKey("mapData.step", 0)
end

function Model:getMapId()
    return self:getDataByKey("mapData.curMapId", 0)
end

function Model:getMapStatus()
    return self:getDataByKey("mapData.mapStatus", 0)
end

function Model:setMapStatus(status)
    self:setDataByKey("mapData.mapStatus", status)
end

function Model:getTodayCostEnergy()
    return self:getFlagFromLocalByKey("todayCostEnergy",true) or 0
end

function Model:setTodayCostEnergy(num)
    self:saveFlagToLocalByKey("todayCostEnergy",true, num)
end

function Model:getCellStatus()
    return self:getDataByKey("mapData.cells", {})
end

function Model:setCellStatusMap(data)
    self:setDataByKey("mapData.cells", data)
end

function Model:getStoreChessList()
    return self:getDataByKey("mapData.storedChesses", {})
end

function Model:popStoreChessList(clear)
    local list = self:getDataByKey("mapData.storedChesses", {})
    local last = list[#list]
    list[#list] = nil
    self:setDataByKey("mapData.storedChesses", {})
    return last
end

function Model:getHandBookData()
    local finished = table.clone(self:getDataByKey("finishedBookIds", {}))
    local reward = self:getDataByKey("rewardBookIds", {})
    return finished, reward
end

local function handBookIdIsFlowerType(id)
    --判断是否是花的图鉴， AI求放过
    if id >= flowerBoodHandStart and id <= flowerBoodHandEnd then
        return true
    end
    return false
end

function Model:addHandBookFinish(ids)
    local finished = self:getDataByKey("finishedBookIds", {})
    local bAdd = false
    for _, id in ipairs(ids) do
        if not table.includes(finished, id) then
            finished[#finished + 1] = id
            bAdd = true

            self:dcHandbookUnlock(id)

            if handBookIdIsFlowerType(id) then
                WeekTaskEventCenter:dispatch(_G.WeekTaskEvent.ACT_TASK_COMPLETE, { type=_G.WeekTaskType.LITTLE_MERGE_UNLOCK_HANDBOOK, num=1})
            end
        end
    end

    if bAdd then
        self:setDataByKey("finishedBookIds", finished)
    end
end

function Model:dcHandbookUnlock(chessId)
    local feature = self:getConst().dcFeature
    local source = "handbook_unlock"
    DcUtil:UserTrack({
        category = feature,
        sub_category = source,
    })

    local GainPropLogic = require "amf.middleware.prop.propchange.logic.GainPropLogic"
    local dcGain = _G.DcDataCommon:create()
    dcGain:setGainProp({
        itemId = chessId,
        num = 1,
    })
    dcGain:setFeature(feature)
        :setSource(source)
    dcGain._extraMap = {
        item_name = "棋子" .. chessId,
    }

    dcGain:execute()
end

function Model:addHandBookReward(id)
    local reward = self:getDataByKey("rewardBookIds", {})
    if table.includes(reward, id) then return end

    table.insert(reward, id)
    self:setDataByKey("rewardBookIds", reward)
end

function Model:hasHandBookReward()
    local finished = self:getDataByKey("finishedBookIds", {})
    local reward = self:getDataByKey("rewardBookIds", {})
    return table.length(finished) > table.length(reward)
end

function Model:addScoreBuff(type, minute)
    local key = type == 1 and "buff20EndTs" or "buff50EndTs"
    local time = tonumber(self:getDataByKey(key, 0))
    time = math.max(TimeKit:timeInMillis(), time)
    time = time + minute * 60000
    self:setDataByKey(key, time)
end

function Model:getScoreBuff(type)
    local key = type == 1 and "buff20EndTs" or "buff50EndTs"
    return math.floor(tonumber(self:getDataByKey(key) or 0) / 1000)
end

function Model:setbuff20EndTs(time)
    self:setDataByKey("buff20EndTs", time)
end

function Model:setbuff50EndTs(time)
    self:setDataByKey("buff50EndTs", time)
end

function Model:getCollectionNum()
    return self:getDataByKey("leftEnergy", 0)
end

function Model:setCollectionNum(num)
    self:setDataByKey("leftEnergy", num)
end

function Model:addCollectionNum(num)
    if num < 0 then
        local cost = self:getTodayCostEnergy()
        self:setTodayCostEnergy(cost - num)
    end

    self:setDataByKey("leftEnergy", self:getCollectionNum() + num)
end

function Model:getGotFinalReward()
    return self:getDataByKey("gotFinalReward", false)
end

function Model:setGotFinalReward()
    self:setDataByKey("gotFinalReward", true)
end

function Model:getMaxProgressId()
    return self:getDataByKey("maxProgressId", 0)
end

function Model:setMaxProgressId(id)
    self:setDataByKey("maxProgressId", id)
end

function Model:getTodayBuyEnergyTimes()
    return self:getDataByKey("todayBuyEnergyTimes", 0)
end

function Model:addTodayBuyEnergyTimes()
    self:setDataByKey("todayBuyEnergyTimes", self:getTodayBuyEnergyTimes() + 1)
end

function Model:getConvert()
    return self:getDataByKey("leftEnergy", 0) > 0
end

function Model:setConvert()
    self:setDataByKey("leftEnergy", 0)
end

function Model:clearGetRewards(type)
    if type == 1 then
        self:clearMapReward()
    else
        self:clearBattlePassReward()
    end
end

function Model:hasMapReward()
    local status = self:getMapStatus()
    if status == self:getConst().MapStatus.FINISHED then
        local maxStage = self:getStageCount()
        local stage = self:getMapStage()
        if stage < maxStage then return false end
        return not self:getGotFinalReward()
    elseif status == self:getConst().MapStatus.LOCK then
        local chessId = self:getStepUnlockChessId()
        local finished = self:getDataByKey("finishedBookIds", {})

        return table.indexOf(finished, chessId)
    end

    return false
end

function Model:clearMapReward()
    if self:hasMapReward() then
        self:setMapStatus(self:getConst().MapStatus.FINISHED)
    end
end

function Model:getStepMeta(step)
    step = step or self:getMapStage()
    local meta = self:getConfigByKey("stepMeta", {})
    return meta[step] or meta[#meta]
end

function Model:getFinalRewards()
    return self:getConfigByKey("finalRewards", {})
end

function Model:getStepRewards(step)
    local meta = self:getStepMeta(step)
    return meta.rewardItems or {}
end

function Model:getStageCount()
    return #self:getConfigByKey("stepMeta", {})
end

function Model:getStepUnlockChessId(step)
    local meta = self:getStepMeta(step)
    return meta.needChessId or 20001
end

function Model:setNotShowToday(value)
    self:saveFlagToLocalByKey("NotShowToday",true,value)
end

function Model:getNotShowToday()
    return self:getFlagFromLocalByKey("NotShowToday", true)
end

-- BattlePass
function Model:getBattlePass()
    return self:getDataByKey("battlePass", {})
end

function Model:setBattlePass(data)
    self:setDataByKey("battlePass", data)
end


function Model:getBattlePassData(id)
    local cfg = self:getConfigByKey("battlePass", {})
    local idcfg = cfg[id]
    return idcfg or {}
end

---BattlePass的总数
function Model:getBattlePassSum()
    local cfg = self:getConfigByKey("battlePass", {})
    return #cfg
end

function Model:hasBattlePassReward()
    local value = self:getBattlePassValue()
    local hasVip = self:getBattlePassVip()
    local vipGot = self:getBattlePassRewardsId(true)
    local freeGot = self:getBattlePassRewardsId(false)
    local cfg = self:getConfigByKey("battlePass", {})

    local canGetFree = {}
    local canGetVip = {}

    for id, rewardCfg in ipairs(cfg) do
        local need = rewardCfg.need or 0
        local meetNeed = value >= need

        if meetNeed then
            if not freeGot[id] then
                table.insert(canGetFree, id)
            end

            if hasVip and not vipGot[id] then
                table.insert(canGetVip, id)
            end
        end
    end

    local hasReward = (#canGetFree > 0) or (#canGetVip > 0)
    return hasReward, canGetFree, canGetVip
end

function Model:clearBattlePassReward()
    local hasReward, canGetFree, canGetVip = self:hasBattlePassReward()

    if not table.isEmpty(canGetFree) then
        local ids = self:getDataByKey("battlePass.freeAlreadyGotIds", {})
        for _, v in ipairs(canGetFree) do
            table.insert(ids, v)
        end
        self:setDataByKey("battlePass.freeAlreadyGotIds", ids)
    end

    if not table.isEmpty(canGetVip) then
        local ids = self:getDataByKey("battlePass.vipAlreadyGotIds", {})
        for _, v in ipairs(canGetVip) do
            table.insert(ids, v)
        end
        self:setDataByKey("battlePass.vipAlreadyGotIds", ids)
    end
end

function Model:getBattlePassValue()
    return self:getDataByKey("battlePass.value", 0)
end

function Model:addBattlePassValue(value)
    local curValue = self:getBattlePassValue()
    self:setDataByKey("battlePass.value", curValue + value)
end

function Model:getBattlePassVip()
    return self:getDataByKey("battlePass.hasVip", false)
end

function Model:setBattlePassVip()
    self:setDataByKey("battlePass.hasVip", true)
end

function Model:getBattlePassRewardsId(bVip)
    local key = bVip and "battlePass.vipAlreadyGotIds" or "battlePass.freeAlreadyGotIds"
    return self:getDataByKey(key, {})
end

function Model:addBattlePassRewardsId(bVip, id)
    local key = bVip and "battlePass.vipAlreadyGotIds" or "battlePass.freeAlreadyGotIds"
    local ids = self:getDataByKey(key, {})
    table.insert(ids, id)
    self:setDataByKey(key, ids)
end

-- 棋子配置
function Model:getChessTypeMetas()
    return self:getConfigByKey("chessTypeMetas", {})
end

function Model:getChessTypeById(id)
    local metas = self:getChessTypeMetas()
    for _, meta in ipairs(metas) do
        for _, v in ipairs(meta.chessMetas) do
            if v.chessId == id then
                return v
            end
        end
    end
end

function Model:getChessTypeMap()
    local ret = {}
    local metas = self:getChessTypeMetas()
    for _, meta in ipairs(metas) do
        for _, v in ipairs(meta.chessMetas) do
            ret[v.chessId] = table.merge(v, {type = meta.chessType})
        end
    end
    return ret
end

-- 主题配置
function Model:getThemeConfig()
    return self:getConfigByKey("theme", {})
end

function Model:getSkin()
    local config = self:getThemeConfig()
    return config.resource
end

function Model:getThemeName()
    local config = self:getThemeConfig()
    return config.name
end

-- IconTip
function Model:getPopTipTime(index)
    local key = "iconTip_" .. index
    return self:getFlagFromLocalByKeyInt(key, true)
end

function Model:addPopTipTime(index, num)
    num = num or 1
    local key = "iconTip_" .. index
    local oriNum = self:getFlagFromLocalByKeyInt(key, true)
    self:saveFlagToLocalByKeyInt(key, true, oriNum + num)
end

function Model:getCanPopTipTime(index)
    if index == 1 then
        return self:getConfigByKey("dailyIconTipsLimit", 2)
    elseif index == 3 then
        return self:getConfigByKey("dailyIconPopLimit", 2)
    end

    return 0
end

function Model:getCanPopTipLimit()
    local meta = self:getStepMeta()
    return meta.iconPopWhenLeftEnergyOver or 20
end

function Model:requestPackagepull(params)
    return self.syncPlug:requestPackagepull(params)
end

function Model:requestActivityAction(params)
    return self.syncPlug:requestActivityaction(params)
end
-- function Model:onResponsePackagesPull()
    
-- end

--获得礼包信息
function Model:getGiftPackages()
    return self:getDataByKey("packageInfo", {})
end

--现实可见礼包
function Model:getDisplayablePackages()
    return self:getDataByKey("packageInfo.displayablePackages") or {}
end

function Model:getPackageMetas()
    return self:getDataByKey("packageInfo.packageMetas", {})
end

function Model:getModuleExtraMap()
    return self:getDataByKey("packageInfo.moduleExtraMap", {})
end

function Model:getPackageIdByType(type)
    local packs = self:getDisplayablePackages()
    -- printx(41,"djaosjd",tts(packs))
    for i, v in pairs(packs) do
        if v.extra then
            local dic = table.deserialize(v.extra)
            -- printx(41,"djaosjd",tts(dic))
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
    self:setDataByKey("packageInfo",packages)
end

function Model:getExtraOfGoodsById(id)
    local packs = self:getDisplayablePackages()
    -- printx(41,"djaosjd",tts(packs))
    for i, v in pairs(packs) do
        if v.packageId == id then
            return table.deserialize(v.extra)
        end
    end
    return nil
end

function Model:getMultiple()
    return self:getDataByKey("multiple", 1)
end

function Model:setMultiple(value)
    self:setDataByKey("multiple", value)
end

function Model:getBoxLv(step)
    local meta = self:getStepMeta(step)
    return meta.treasureChestChessId or 50001
end

function Model:getCanShowDoubleChessId()
    return self:getConfigByKey("canDoubleChessId", 20011)
end

function Model:getMaxStageOpLimit()
    return self:getConfigByKey("offlineRequestLimitCount", 10)
end

function Model:getMergeOnlineLevel()
    return self:getConfigByKey("lvLimit", 5)
end

function Model:isFinish()
    local maxStage = self:getStageCount()
    local stage = self:getMapStage()
    if stage < maxStage then return false end
    local status = self:getMapStatus()
    return status == self:getConst().MapStatus.MOSAIC
end

return Model
