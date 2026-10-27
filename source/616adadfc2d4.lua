-- @ref 强弹框架: 场景调度顺序
--
-- checkPoint 是唯一身份（身份 = 业务规则 = 队列槽位），所以调度只回答一个问题：
-- 本场景里所有候选 checkPoint 的消费顺序是什么。
--
-- 静态顺序由业务定义的 PopType 场景顺序 + 组内优先级决定；resolver（例如 AI
-- 推荐权重）可以在同一批 checkPoint 上重排，但不能增删候选，也不能把候选搬到
-- 别的槽位 —— 已经没有"别的槽位"这回事了。

local AutoPopupDebugLog = require "amf.middleware.autopop.AutoPopupDebugLog"
require "amf.middleware.autopop.config.AutoPopupConst"

local PopupSchedule = class("PopupSchedule")

local function getStageKey(popStage)
	return tostring(AutoPopupConst.PopStageKeyMapping[tostring(popStage)] or popStage)
end

local function getStageId(popStage)
	local numericStage = tonumber(popStage)
	if numericStage then return numericStage end
	for stageId, mappedStage in pairs(AutoPopupConst.PopStageKeyMapping) do
		if mappedStage == popStage then return tonumber(stageId) end
	end
	return nil
end

local function normalizePopStage(popStage)
	return AutoPopupConst.PopStageKeyMapping[tostring(popStage)] or popStage
end

function PopupSchedule:create(autoPopupMgr)
	local inst = PopupSchedule.new()
	inst:init(autoPopupMgr)
	return inst
end

function PopupSchedule:init(autoPopupMgr)
	self._autoPopupMgr = autoPopupMgr
	self._resolver = nil
	self:reset()
end

-- 清空本场景的调度缓存。队列重建、场景切换、外部排序依据变化时调用。
function PopupSchedule:reset()
	self._stageCache = {}
	self._candidateOrder = {}
	self._runtimeCandidates = {}
end

function PopupSchedule:invalidate()
	self:reset()
end

function PopupSchedule:setResolver(resolver)
	assert(resolver == nil or type(resolver) == "function",
		"popup schedule resolver must be a function or nil")
	self._resolver = resolver
	self:reset()
end

-- 队列内容变化后调用；下一次 prepare 会重新计算顺序。
function PopupSchedule:markDirty()
	for _, stageCache in pairs(self._stageCache) do
		stageCache.dirty = true
	end
end

function PopupSchedule:_getStageCache(popStage)
	local stageKey = getStageKey(popStage)
	local cache = self._stageCache[stageKey]
	if not cache then
		cache = {orderedCheckPoints = {}, dirty = true}
		self._stageCache[stageKey] = cache
	end
	return cache
end

-- 静态顺序：场景的 PopType 顺序优先，其次组内优先级，最后用 checkPoint 名兜底，
-- 保证同一批候选在任何设备上的顺序都稳定。
function PopupSchedule:_sortStatically(popStage, candidates)
	local normalizedPopStage = normalizePopStage(popStage)
	table.sort(candidates, function(left, right)
		local order = self:comparePriority(
			normalizedPopStage, left.checkPoint, right.checkPoint
		)
		if order ~= 0 then return order < 0 end
		return tostring(left.checkPoint) < tostring(right.checkPoint)
	end)
	return candidates
end

-- resolver 只能重排同一批 checkPoint；任何增删、重复或未知值都整体回退静态顺序。
function PopupSchedule:_applyResolver(popStage, candidates)
	if #candidates < 2 or not self._resolver then return candidates end

	local byCheckPoint = {}
	local resolverInput = {}
	for index, candidate in ipairs(candidates) do
		byCheckPoint[candidate.checkPoint] = candidate
		resolverInput[index] = {
			checkPoint = candidate.checkPoint,
			source = candidate.source or "config",
			actId = candidate.actId,
			metaId = candidate.metaId,
			popType = candidate.popType,
		}
	end

	local context = {
		popStageId = getStageId(popStage),
		popStage = normalizePopStage(popStage),
	}
	local ok, resolved = pcall(self._resolver, resolverInput, context)
	if not ok or type(resolved) ~= "table" or #resolved ~= #candidates then
		if not ok then
			AutoPopupDebugLog:log("PopupSchedule:resolver failed, fallback", tostring(resolved))
		end
		return candidates
	end

	local ordered = {}
	local seen = {}
	for index, value in ipairs(resolved) do
		local checkPoint = value.checkPoint or value
		local candidate = byCheckPoint[checkPoint]
		if not candidate or seen[checkPoint] then
			AutoPopupDebugLog:log("PopupSchedule:resolver returned invalid order, fallback")
			return candidates
		end
		seen[checkPoint] = true
		ordered[index] = candidate
	end
	return ordered
end

-- 场景候选顺序 = 注册式定义快照（含未通过 check 的候选）+ 本场景配置式候选。
function PopupSchedule:prepareDefinitions(popStage, definitions)
	local stageKey = getStageKey(popStage)
	if self._candidateOrder[stageKey] then
		return self._candidateOrder[stageKey]
	end

	local registration = self._autoPopupMgr and self._autoPopupMgr._popupRegistration
	local source = definitions or
		(registration and registration:getSceneLogDefinitions(popStage)) or {}

	local candidates = {}
	local seen = {}
	for _, identity in ipairs(source) do
		local checkPoint = identity.checkPoint
		if checkPoint and not seen[checkPoint] then
			seen[checkPoint] = true
			candidates[#candidates + 1] = {
				checkPoint = checkPoint,
				source = identity.source or "registered",
				actId = identity.actId,
				metaId = identity.metaId,
				popType = identity.popType,
			}
		end
	end

	-- 运行时候选只属于本次解析，不能回写注册中心的定义快照。
	for checkPoint, identity in pairs(self._runtimeCandidates[stageKey] or {}) do
		if not seen[checkPoint] then
			seen[checkPoint] = true
			candidates[#candidates + 1] = identity
		end
	end

	local staticOrder = self:_sortStatically(popStage, candidates)
	local ordered = self:_applyResolver(popStage, staticOrder)
	local order = {byCheckPoint = {}, originalByCheckPoint = {}, count = #ordered}
	for rank, candidate in ipairs(ordered) do
		order.byCheckPoint[candidate.checkPoint] = rank
		-- resolver 只是重排同一批候选，所以 staticOrder[rank] 就是被挪到这个顺序
		-- 位置的候选所挤掉的原位置候选。
		order.originalByCheckPoint[candidate.checkPoint] = staticOrder[rank]
	end
	self._candidateOrder[stageKey] = order
	self:publishScheduleOrder(popStage)
	return order
end

-- 把整份候选顺序（顺序位置 + 被挤掉的原位置候选）发布给日志。未入队的候选
-- 同样有位置，日志才不用退回观察顺序；重复发布是幂等的。
function PopupSchedule:publishScheduleOrder(popStage)
	local order = self:getCandidateOrder(popStage)
	AutoPopupDebugLog:recordPopupScheduleRanks(order.byCheckPoint, self:_collectInterventions(order))
end

-- 被 resolver 挪动位置的候选：本来排在这个位置上的是谁，那个候选的 actId 是多少。
function PopupSchedule:_collectInterventions(order)
	local interventions = {}
	for checkPoint, original in pairs(order.originalByCheckPoint) do
		if original.checkPoint ~= checkPoint then
			interventions[checkPoint] = {
				checkPoint = original.checkPoint,
				actId = self:_getOriginalActId(original),
			}
		end
	end
	return interventions
end

-- 原位置候选的 actId 优先取队列里的真实 entry；那一轮没入队时退回它的注册/配置声明。
function PopupSchedule:_getOriginalActId(original)
	local queue = self._autoPopupMgr:getPopupQueueByCheckPoint(original.checkPoint)
	local originalEntry = queue and queue[original.checkPoint]
	return (originalEntry and originalEntry.actId) or original.actId
end

function PopupSchedule:getCandidateOrder(popStage)
	local stageKey = getStageKey(popStage)
	return self._candidateOrder[stageKey] or self:prepareDefinitions(popStage)
end

function PopupSchedule:getRank(popStage, checkPoint)
	if checkPoint == nil then return nil end
	local order = self:getCandidateOrder(popStage)
	return order and order.byCheckPoint[checkPoint] or nil
end

-- 登记本次场景出现过的配置式候选（含被限流挡在队列外的），让下一个解析周期
-- 把它纳入排序；只有拿到调度位置的候选，日志才能按真实顺序而不是观察顺序排列。
function PopupSchedule:recordRuntimeCandidate(popupEntry)
	if not popupEntry or popupEntry.source ~= "config" then return end
	local popStage = AutoPopupDebugLog:getPopupSceneStage()
	if not popStage then return end
	local checkPoint = popupEntry.checkPoint
	if not checkPoint then return end

	local stageKey = getStageKey(popStage)
	local runtime = self._runtimeCandidates[stageKey] or {}
	local registered = runtime[checkPoint]
	if registered then
		-- 同一候选可能先被挡住、之后才真正入队（或反过来）。活动归属要补齐，
		-- 否则 resolver 会因为拿不到 actId 而漏算这个候选的优先级。
		if registered.actId == nil and popupEntry.actId ~= nil then
			registered.actId = popupEntry.actId
			self._candidateOrder[stageKey] = nil
			self:markDirty()
		end
		return
	end
	runtime[checkPoint] = {
		checkPoint = checkPoint,
		source = "config",
		actId = popupEntry.actId,
	}
	self._runtimeCandidates[stageKey] = runtime
	self._candidateOrder[stageKey] = nil
	self:markDirty()
end

-- 把当前各 PopType 队列里的候选整理成本场景的消费顺序，并写入调度序号。
function PopupSchedule:prepare(popStage)
	local stageCache = self:_getStageCache(popStage)
	if not stageCache.dirty then return stageCache end

	local mgr = self._autoPopupMgr
	local candidates = {}
	for _, popType in ipairs(mgr:getPopupCheckList(popStage) or {}) do
		for checkPoint, popupEntry in pairs(mgr:getPopupQueueByPopType(popType) or {}) do
			candidates[#candidates + 1] = {
				checkPoint = checkPoint,
				source = popupEntry.source or "config",
				actId = popupEntry.actId,
				popType = popType,
				popupEntry = popupEntry,
			}
		end
	end

	-- 声明式顺序是基线；不在定义快照里的配置式候选排在基线之后，彼此保持
	-- 静态优先级顺序。
	local candidateOrder = self:getCandidateOrder(popStage)
	local rankBase = candidateOrder and candidateOrder.count or 0
	local ranked = {}
	for index, candidate in ipairs(candidates) do
		ranked[#ranked + 1] = {
			candidate = candidate,
			rank = candidateOrder and candidateOrder.byCheckPoint[candidate.checkPoint] or nil,
			index = index,
		}
	end
	table.sort(ranked, function(left, right)
		if left.rank and right.rank and left.rank ~= right.rank then
			return left.rank < right.rank
		end
		if left.rank and not right.rank then return true end
		if right.rank and not left.rank then return false end
		return left.index < right.index
	end)

	stageCache.orderedCheckPoints = {}
	for index, item in ipairs(ranked) do
		local candidate = item.candidate
		local checkPoint = candidate.checkPoint

		stageCache.orderedCheckPoints[#stageCache.orderedCheckPoints + 1] = checkPoint

		local rank = item.rank or (rankBase + index)
		self:_recordIntervention(candidate.popupEntry, checkPoint, candidateOrder)
		AutoPopupDebugLog:recordPopupScheduleOrder(candidate.popupEntry, rank, checkPoint)
	end
	stageCache.dirty = false
	return stageCache
end

-- 把"被 resolver 挤出原顺序位置"的结果写在真实 popupEntry 上：原位置的候选身份，
-- 以及该候选的 actId。actId 优先取队列里的真实 entry；原位置候选这轮没入队时退回
-- 它的注册/配置声明，两者都取不到才留空。曝光打点与场景日志共用这一份数据。
function PopupSchedule:_recordIntervention(popupEntry, checkPoint, candidateOrder)
	local original = candidateOrder and candidateOrder.originalByCheckPoint[checkPoint]
	if original and original.checkPoint ~= checkPoint then
		popupEntry.originalCheckPoint = original.checkPoint
		popupEntry.originalActId = self:_getOriginalActId(original)
	else
		popupEntry.originalCheckPoint = nil
		popupEntry.originalActId = nil
	end
end

function PopupSchedule:getOrderedCheckPoints(popStage)
	return self:prepare(popStage).orderedCheckPoints
end

-- 与真实调度共用的纯比较逻辑：先比较当前场景的 PopType 顺序，再比较组内优先级。
function PopupSchedule:comparePriority(popStage, leftCheckPoint, rightCheckPoint)
	if leftCheckPoint == rightCheckPoint then return 0 end

	local mgr = self._autoPopupMgr
	local normalizedPopStage = normalizePopStage(popStage)
	local popTypeOrder = mgr:getPopupCheckList(normalizedPopStage)
	local leftPopType = mgr:getPopType(leftCheckPoint)
	local rightPopType = mgr:getPopType(rightCheckPoint)
	if leftPopType ~= rightPopType then
		local leftOrder = #popTypeOrder + 1
		local rightOrder = #popTypeOrder + 1
		for index, popType in ipairs(popTypeOrder) do
			if popType == leftPopType then leftOrder = index end
			if popType == rightPopType then rightOrder = index end
		end
		if leftOrder ~= rightOrder then
			return leftOrder < rightOrder and -1 or 1
		end
		return 0
	end

	local leftPriority = mgr:getPriority(leftCheckPoint)
	local rightPriority = mgr:getPriority(rightCheckPoint)
	if leftPriority == rightPriority then return 0 end
	return leftPriority < rightPriority and -1 or 1
end

return PopupSchedule
