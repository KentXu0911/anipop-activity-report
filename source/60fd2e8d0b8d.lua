require "amf.middleware.autopop.config.AutoPopupConst"
local PopStage = AutoPopupConst.PopStage

local NotificationCoordinator = {}
NotificationCoordinator.__index = NotificationCoordinator

local function emitDiagnostic(logger, code, data)
    if logger == nil then
        return
    end
    if type(logger) == "function" then
        pcall(logger, code, data)
        return
    end
    if type(logger) ~= "table" then
        return
    end
    local method = logger.warn or logger.log
    if type(method) == "function" then
        pcall(method, logger, code, data)
    end
end

local function safeCallback(callback, result, logger)
    if type(callback) ~= "function" then
        return
    end
    local ok, err = pcall(callback, result)
    if not ok then
        emitDiagnostic(logger, "ICON_V2_NOTIFICATION_COMPLETION_CALLBACK_ERROR", {
            error = tostring(err),
            stage = result and result.stage,
            token = result and result.token,
        })
    end
end

local function callRecordMethod(records, methodName, key)
    if records == nil or key == nil then
        return false
    end
    local method = records[methodName]
    if type(method) ~= "function" then
        return false
    end
    local ok, value = pcall(method, records, key)
    if not ok then
        return false
    end
    if methodName == "isConsumed" or methodName == "get" then
        return value == true or (type(value) == "number" and value > 0)
    end
    return value ~= false
end

local function isConsumed(records, key)
    if records == nil or key == nil then
        return false
    end
    if type(records.isConsumed) == "function" then
        return callRecordMethod(records, "isConsumed", key)
    end
    return callRecordMethod(records, "get", key)
end

local function consume(records, key)
    if records == nil or key == nil then
        return false
    end
    if type(records.consume) == "function" then
        return callRecordMethod(records, "consume", key)
    end
    return callRecordMethod(records, "set", key)
end

local function newRequest(callback)
    return {
        callback = callback,
        settled = false,
    }
end

local function settleRequest(request, result, logger)
    if request == nil or request.settled then
        return false
    end
    request.settled = true
    safeCallback(request.callback, result, logger)
    return true
end

function NotificationCoordinator.new(options)
    options = options or {}
    return setmetatable({
        presenter = options.presenter,
        records = options.records,
        logger = options.logger,
        entries = {},
        flowId = 0,
        stage2Status = "unavailable",
        fallbackRequests = {},
        nextBatchId = 0,
        activeBatch = nil,
        maxBatchSize = options.maxBatchSize,
    }, NotificationCoordinator)
end

function NotificationCoordinator.create(selfOrOptions, options)
    if selfOrOptions ~= NotificationCoordinator then
        options = selfOrOptions
    end
    return NotificationCoordinator.new(options)
end

function NotificationCoordinator:beginFlow(options)
    options = options or {}
    self.flowId = self.flowId + 1
    self.stage2Status = options.stage2Expected == true and "expected" or "unavailable"
    local previousFallbacks = self.fallbackRequests
    self.fallbackRequests = {}
    for index = 1, #previousFallbacks do
        settleRequest(previousFallbacks[index], {
            displayed = false,
            reason = "flow_replaced",
            flowId = self.flowId,
        }, self.logger)
    end
    return self.flowId
end

function NotificationCoordinator:_restartBatchBeforeVisible(reason)
    local batch = self.activeBatch
    if batch == nil or batch.visible then
        return false
    end
    batch.invalidated = true
    self.activeBatch = nil
    for index = 1, #batch.entries do
        local entry = batch.entries[index]
        if entry.state == "reserved" and entry.batchId == batch.id then
            entry.state = "pending"
            entry.batchId = nil
        end
    end
    if batch.control then
        batch.control:cancel(reason or "candidate_set_changed")
    end
    self:_startBatch(batch.stage, batch.requests)
    return true
end

function NotificationCoordinator:register(candidate)
    if type(candidate) ~= "table" or type(candidate.cycleKey) ~= "string" or candidate.cycleKey == "" then
        emitDiagnostic(self.logger, "ICON_V2_NOTIFICATION_CANDIDATE_INVALID", {
            cycleKey = candidate and candidate.cycleKey,
        })
        return false, "ICON_V2_NOTIFICATION_CANDIDATE_INVALID"
    end
    if isConsumed(self.records, candidate.noticeShownRecordKey) then
        self.entries[candidate.cycleKey] = {
            candidate = candidate,
            state = "consumed",
        }
        return false, "ICON_V2_NOTIFICATION_ALREADY_CONSUMED"
    end
    if isConsumed(self.records, candidate.newClearedRecordKey) then
        self.entries[candidate.cycleKey] = nil
        return false, "ICON_V2_NOTIFICATION_NEW_ALREADY_CLEARED"
    end

    local entry = self.entries[candidate.cycleKey]
    if entry and entry.state == "record_failed" then
        return false, "ICON_V2_NOTIFICATION_RECORD_WRITE_FAILED"
    end
    if entry and (entry.state == "reserved" or entry.state == "showing" or entry.state == "consumed") then
        return false, "ICON_V2_NOTIFICATION_ALREADY_ACTIVE"
    end
    self.entries[candidate.cycleKey] = {
        candidate = candidate,
        state = "pending",
    }
    self:_restartBatchBeforeVisible("candidate_registered_before_visible")
    return true
end

function NotificationCoordinator:getState(cycleKey)
    local entry = self.entries[cycleKey]
    return entry and entry.state or nil
end

function NotificationCoordinator:hasPendingCandidates()
    for _, entry in pairs(self.entries) do
        if entry.state == "pending" then
            return true
        end
    end
    return false
end

function NotificationCoordinator:_collectPending()
    local pending = {}
    for cycleKey, entry in pairs(self.entries) do
        if entry.state == "pending" then
            local candidate = entry.candidate
            if isConsumed(self.records, candidate.noticeShownRecordKey) then
                entry.state = "consumed"
            elseif isConsumed(self.records, candidate.newClearedRecordKey) then
                self.entries[cycleKey] = nil
            else
                table.insert(pending, entry)
            end
        end
    end
    table.sort(pending, function(left, right)
        local leftOrder = left.candidate.poolIdx or math.huge
        local rightOrder = right.candidate.poolIdx or math.huge
        if leftOrder == rightOrder then
            return left.candidate.cycleKey < right.candidate.cycleKey
        end
        return leftOrder < rightOrder
    end)
    if type(self.maxBatchSize) == "number" and self.maxBatchSize > 0 then
        while #pending > self.maxBatchSize do
            table.remove(pending)
        end
    end
    return pending
end

function NotificationCoordinator:_isCurrentBatch(batch)
    return self.activeBatch == batch and batch.invalidated ~= true
end

function NotificationCoordinator:_settleBatch(batch, result)
    if not self:_isCurrentBatch(batch) then
        return false
    end
    batch.invalidated = true
    self.activeBatch = nil
    for index = 1, #batch.requests do
        settleRequest(batch.requests[index], result, self.logger)
    end
    if batch.stage == PopStage.STAGE_TWO then
        self.stage2Status = result.displayed and "completed" or "failed"
        self:_drainFallbackRequests()
    end
    return true
end

function NotificationCoordinator:_releaseBeforeVisible(batch, reason)
    if not self:_isCurrentBatch(batch) then
        return false
    end
    for index = 1, #batch.entries do
        local entry = batch.entries[index]
        if entry.state == "reserved" and entry.batchId == batch.id then
            if isConsumed(self.records, entry.candidate.newClearedRecordKey) then
                self.entries[entry.candidate.cycleKey] = nil
            else
                entry.state = "pending"
                entry.batchId = nil
            end
        end
    end
    return self:_settleBatch(batch, {
        displayed = false,
        reason = reason or "before_visible_failure",
        stage = batch.stage,
        token = batch.token,
    })
end

function NotificationCoordinator:_markVisible(batch)
    if not self:_isCurrentBatch(batch) or batch.visible then
        return false
    end
    local visibleCount = 0
    for index = 1, #batch.entries do
        local entry = batch.entries[index]
        local candidate = entry.candidate
        if entry.state == "reserved" and entry.batchId == batch.id
            and not isConsumed(self.records, candidate.newClearedRecordKey)
        then
            visibleCount = visibleCount + 1
            local noticeWritten = consume(self.records, candidate.noticeShownRecordKey)
            if not noticeWritten then
                emitDiagnostic(self.logger, "ICON_V2_NOTICE_RECORD_WRITE_FAILED", {
                    cycleKey = candidate.cycleKey,
                    recordKey = candidate.noticeShownRecordKey,
                })
            end
            local featureWritten = true
            if candidate.temporaryC then
                featureWritten = consume(self.records, candidate.firstCRecordKey)
                if not featureWritten then
                    emitDiagnostic(self.logger, "ICON_V2_FIRST_C_RECORD_WRITE_FAILED", {
                        cycleKey = candidate.cycleKey,
                        recordKey = candidate.firstCRecordKey,
                    })
                end
            end
            if noticeWritten then
                entry.state = "showing"
            else
                entry.state = "record_failed"
            end
            batch.recordWriteFailed = batch.recordWriteFailed == true
                or not noticeWritten or not featureWritten
        elseif entry.state == "reserved" and entry.batchId == batch.id then
            self.entries[candidate.cycleKey] = nil
        end
    end
    if visibleCount == 0 then
        return self:_releaseBeforeVisible(batch, "cancelled_before_visible")
    end
    batch.visible = true
    return true
end

function NotificationCoordinator:_completeBatch(batch, reason)
    if not self:_isCurrentBatch(batch) then
        return false
    end
    if not batch.visible then
        return self:_releaseBeforeVisible(batch, reason or "completed_before_visible")
    end
    for index = 1, #batch.entries do
        local entry = batch.entries[index]
        if entry.batchId == batch.id then
            if entry.state == "showing" then
                entry.state = "consumed"
            end
            entry.batchId = nil
        end
    end
    local persistenceFailed = batch.recordWriteFailed == true
    return self:_settleBatch(batch, {
        displayed = true,
        reason = reason or (persistenceFailed and "record_write_failed" or "completed"),
        stage = batch.stage,
        token = batch.token,
        persistenceFailed = persistenceFailed,
    })
end

function NotificationCoordinator:_startBatch(stage, requests)
    local pending = self:_collectPending()
    if #pending == 0 then
        local result = {
            displayed = false,
            reason = "no_pending_candidate",
            stage = stage,
        }
        for index = 1, #requests do
            settleRequest(requests[index], result, self.logger)
        end
        if stage == PopStage.STAGE_TWO then
            self.stage2Status = "completed"
            self:_drainFallbackRequests()
        end
        return nil
    end

    self.nextBatchId = self.nextBatchId + 1
    local batch = {
        id = self.nextBatchId,
        flowId = self.flowId,
        stage = stage,
        entries = pending,
        requests = requests,
        visible = false,
    }
    batch.token = table.concat({ tostring(batch.flowId), stage, tostring(batch.id) }, ":")
    for index = 1, #pending do
        pending[index].state = "reserved"
        pending[index].batchId = batch.id
    end
    self.activeBatch = batch
    if stage == PopStage.STAGE_TWO then
        self.stage2Status = "running"
    end

    local hooks = {
        token = batch.token,
        onVisible = function()
            return self:_markVisible(batch)
        end,
        onComplete = function(reason)
            return self:_completeBatch(batch, reason)
        end,
        onFailure = function(reason)
            if batch.visible then
                return self:_completeBatch(batch, reason or "failure_after_visible")
            end
            return self:_releaseBeforeVisible(batch, reason)
        end,
    }

    if type(self.presenter) ~= "function" then
        self:_releaseBeforeVisible(batch, "presenter_missing")
        return batch.token
    end
    local candidates = {}
    for index = 1, #pending do
        candidates[index] = pending[index].candidate
    end
    local ok, control = pcall(self.presenter, candidates, hooks)
    if not ok then
        emitDiagnostic(self.logger, "ICON_V2_NOTIFICATION_PRESENTER_ERROR", {
            error = tostring(control),
            token = batch.token,
        })
        self:_releaseBeforeVisible(batch, "presenter_error")
    elseif type(control) == "table" then
        batch.control = control
    end
    return batch.token
end

function NotificationCoordinator:_drainFallbackRequests()
    if #self.fallbackRequests == 0 or self.activeBatch ~= nil then
        return
    end
    local requests = self.fallbackRequests
    self.fallbackRequests = {}
    self:_startBatch(PopStage.STAGE_FOUR, requests)
end

function NotificationCoordinator:request(stage, callback)
    assert(stage == PopStage.STAGE_TWO or stage == PopStage.STAGE_FOUR,
        "ICON_V2_NOTIFICATION_STAGE_INVALID")
    local request = newRequest(callback)
    local active = self.activeBatch
    if active ~= nil then
        if active.stage == stage then
            table.insert(active.requests, request)
        elseif stage == PopStage.STAGE_FOUR and active.stage == PopStage.STAGE_TWO then
            table.insert(self.fallbackRequests, request)
        else
            settleRequest(request, {
                displayed = false,
                reason = "another_batch_active",
                stage = stage,
            }, self.logger)
        end
        return active.token
    end

    if stage == PopStage.STAGE_TWO and self.stage2Status == "unavailable" then
        settleRequest(request, {
            displayed = false,
            reason = "stage2_unavailable",
            stage = stage,
        }, self.logger)
        return nil, "ICON_V2_NOTIFICATION_STAGE2_UNAVAILABLE"
    end
    if stage == PopStage.STAGE_FOUR
        and (self.stage2Status == "expected" or self.stage2Status == "running") then
        table.insert(self.fallbackRequests, request)
        return nil, "ICON_V2_NOTIFICATION_STAGE4_WAITING_FOR_STAGE2"
    end
    return self:_startBatch(stage, { request })
end

function NotificationCoordinator:markStage2Unavailable(reason)
    if self.stage2Status == "running" then
        return false, "ICON_V2_NOTIFICATION_STAGE2_RUNNING"
    end
    self.stage2Status = "unavailable"
    self:_drainFallbackRequests()
    return true, reason
end

function NotificationCoordinator:cancelBeforeVisible(cycleKey, reason)
    local entry = self.entries[cycleKey]
    if entry == nil then
        return false
    end
    local batch = self.activeBatch
    if entry.state == "pending" then
        self.entries[cycleKey] = nil
        return true
    end
    if entry.state == "reserved" and batch and entry.batchId == batch.id then
        self.entries[cycleKey] = nil
        entry.state = "cancelled"
        entry.batchId = nil
        local remaining = 0
        for index = 1, #batch.entries do
            local batchEntry = batch.entries[index]
            if batchEntry.state == "reserved" and batchEntry.batchId == batch.id then
                remaining = remaining + 1
            end
        end
        if remaining == 0 then
            if batch.control and type(batch.control.cancel) == "function" then
                pcall(batch.control.cancel, batch.control, reason)
            end
            self:_releaseBeforeVisible(batch, reason or "cancelled_before_visible")
        end
        return true
    end
    if entry.state == "showing" or entry.state == "record_failed" then
        if batch and batch.control and type(batch.control.skipToFinal) == "function" then
            pcall(batch.control.skipToFinal, batch.control, reason)
        end
        return false, "ICON_V2_NOTIFICATION_ALREADY_VISIBLE"
    end
    return false
end

return NotificationCoordinator
