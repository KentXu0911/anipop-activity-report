
local AutoPopupLimit = require "amf.middleware.autopop.config.AutoPopupLimit"

local PopupModel = class("PopupModel", AMFDataRef)
local MAX_SCENE_LOG_ROUNDS = 2

function PopupModel:__installPlugs()
    self:installPlug(AMFDataPlugsType.STORAGE, {
        fileName = "popup_cache_" .. AutoPopupConst.CacheVersion,
    }):as("db")
    self:installPlug(AMFDataPlugsType.SYNC, {
        requests = {
            syncClientPopupRecord = "amf.middleware.autopop.http.ClientPopupRecord",
        }
    })
end

function PopupModel:__declare()
	-- server data
	self._permanentPopupOrders = {}
	self._dailyPopupOrders = {}
	self._serverPopupConfig = {}
    -- local cache data
	self._lastLimitTime = nil
	self._lastPopupSum = 0
	self._dailyPopTypeInfo = {}
	-- 每个强弹场景最近一次完整调试快照，仅供本地调试面板读取。
	self._lastPopupSceneSnapshots = {}
end

function PopupModel:__init()
	self:initLocalData()
end

function PopupModel:syncServerRecord(data)
	if not data or type(data) ~= "table" then return end
	if table.isEmpty(data) then return end
	local popupInfo = data.popupInfo or {}
	self:setValue("_permanentPopupOrders", popupInfo.popupOrders or {})
	local dailyPopupInfo = data.dailyPopupInfo or {}
	self:setValue("_dailyPopupOrders", dailyPopupInfo.popupOrders or {})
	local popupInfoV2SceneMap = data.popupInfoV2SceneMap or {}
	self:setValue("_serverPopupConfig", popupInfoV2SceneMap)
end

function PopupModel:getServerPopupConfig()
    return self._serverPopupConfig
end

local function normalizePopupSceneStage(popStage)
    local stageId = tonumber(popStage)
    if stageId == 2 or stageId == 3 or stageId == 4 then
        return tostring(stageId)
    end
end

-- 追加一轮调试快照：每个场景只保留最近 MAX_SCENE_LOG_ROUNDS 轮。
function PopupModel:setLastPopupSceneSnapshot(popStage, snapshot)
    local stageKey = normalizePopupSceneStage(popStage)
    if not stageKey then return end

    local rounds = self._lastPopupSceneSnapshots[stageKey] or {}
    table.insert(rounds, 1, snapshot)
    while #rounds > MAX_SCENE_LOG_ROUNDS do
        table.remove(rounds)
    end
    self._lastPopupSceneSnapshots[stageKey] = rounds
    self:setValue("_lastPopupSceneSnapshots", self._lastPopupSceneSnapshots, true)
end

-- 每个场景最近的调试快照轮次，仅供本地调试面板读取。
function PopupModel:getLastPopupSceneSnapshotRounds()
    return self._lastPopupSceneSnapshots
end

function PopupModel:clearLastPopupSceneSnapshots()
    self._lastPopupSceneSnapshots = {}
    self:setValue("_lastPopupSceneSnapshots", self._lastPopupSceneSnapshots, true)
end

function PopupModel:sendPermanentData(uniqueKey)
    if not uniqueKey then return end

	local permanentOrders = self:getValue("_permanentPopupOrders") or {}
	permanentOrders[uniqueKey] = (permanentOrders[uniqueKey] or 0) + 1
	self:setValue("_permanentPopupOrders", permanentOrders)

	self.syncPlug:requestSyncClientPopupRecord({popupType = uniqueKey, daily = false})
end

function PopupModel:sendDailyData(uniqueKey)
	if not uniqueKey then return end

	------------old------------
	-- local curNum = self.dailyPopupOrders[uniqueKey] or 0
	-- self.dailyPopupOrders[uniqueKey] = curNum + 1
	-- self.dailyPopupInfo.popupOrders = self.dailyPopupOrders
	------------new------------
	-- uniqueKey中有.，会有问题，先改一下
	-- local curNum = self:getValue("_dailyPopupOrders." .. uniqueKey) or 0
	-- self:setValue("_dailyPopupOrders." .. uniqueKey, curNum + 1)
	local _dailyPopupOrders = self:getValue("_dailyPopupOrders") or {}
	local curNum = _dailyPopupOrders[uniqueKey] or 0
	_dailyPopupOrders[uniqueKey] = curNum + 1
	self:setValue("_dailyPopupOrders", _dailyPopupOrders)
	---------------------------

    self.syncPlug:requestSyncClientPopupRecord({popupType = uniqueKey, daily = true})
end

function PopupModel:getDailyPopupNum(uniqueKey)
	-- return self.dailyPopupOrders[uniqueKey] or 0
	-- return self:getValue("_dailyPopupOrders." .. uniqueKey) or 0
	-- uniqueKey中有.，会有问题，
	local tb = self:getValue("_dailyPopupOrders") or {}
	return tb[uniqueKey] or 0
end

function PopupModel:getPermanentShowNum(uniqueKey)
	-- return self.permanentPopupOrders[uniqueKey] or 0
	-- return self:getValue("_permanentPopupOrders." .. uniqueKey) or 0
	local _permanentPopupOrders = self:getValue("_permanentPopupOrders") or {}
	return _permanentPopupOrders[uniqueKey] or 0
end

function PopupModel:resetdDailyPopupOrders()
	-- self.dailyPopupInfo = {}
	-- self.dailyPopupOrders = {}
	self:setValue("_dailyPopupOrders", {})
end

-- 跨天自动调用
function PopupModel:resetDailyData()
	self:resetdDailyPopupOrders()
	self:resetDailyPopTypeInfo()
end

function PopupModel:initLocalData()
	self:initStage2LastPopupInfo()
	self:initDailyPopTypeInfo()
end

-----------BEGIN 两次场景2之间弹出限制-----------
function PopupModel:initStage2LastPopupInfo()
	if self._lastLimitTime then
        local currentTime = TimeKit:timeInSec()
		if currentTime - self._lastLimitTime > AutoPopupLimit.Stage2PopupInterval then
            self:setValue("_lastLimitTime", 0, false)
            self:setValue("_lastPopupSum", 0, false)
		end
	else
        self:setValue("_lastLimitTime", 0, false)
        self:setValue("_lastPopupSum", 0, false)
	end
end

-- 记录场景2上次弹出时间
function PopupModel:setStage2LastPopupInfo(time, sum)
    self:setValue("_lastLimitTime", time)
    self:setValue("_lastPopupSum", sum)
end

function PopupModel:getStage2LastPopupTime()
	return self._lastLimitTime
end

function PopupModel:getStage2LastPopupSum()
	return self._lastPopupSum
end
-----------两次场景2之间弹出限制 END-----------

-----------BEGIN 每天某一类强弹，次数限制-----------
function PopupModel:initDailyPopTypeInfo()
	local today = TimeKit:getTodayStart()
	if not self._dailyPopTypeInfo then
        self:setValue("_dailyPopTypeInfo.updateDay", today, false)
	else
		local cacheDay = self._dailyPopTypeInfo.updateDay or 0
		if today ~= cacheDay then
            self:setValue("_dailyPopTypeInfo.updateDay", today, false)
		end
	end
end

function PopupModel:resetDailyPopTypeInfo()
	local today = TimeKit:getTodayStart()
    self:setValue("_dailyPopTypeInfo.updateDay", today, false)
end

function PopupModel:getDailyPopTypePopNum(popType)
	return self._dailyPopTypeInfo[popType] or 0
end

function PopupModel:setDailyPopTypePopNum(popType, num)
    self:setValue("_dailyPopTypeInfo.popType", num)
end
-----------每天某一类强弹，次数限制 END-----------

return PopupModel
