local RightTopSlotResolver = {}
RightTopSlotResolver.__index = RightTopSlotResolver

local DefaultPriorityOrder = {
    "reward",
    "exclamation",
    "new",
    "count",
    "redDot",
}

local ValidReminderKinds = {
    reward = true,
    exclamation = true,
    new = true,
    count = true,
    redDot = true,
}

local function copyArray(source)
    local target = {}
    for index = 1, #source do
        target[index] = source[index]
    end
    return target
end

local function copyMap(source)
    local target = {}
    for key, value in pairs(source or {}) do
        target[key] = value
    end
    return target
end

local function first(state, paths, defaultValue)
    for pathIndex = 1, #paths do
        local value = state
        local path = paths[pathIndex]
        for index = 1, #path do
            if type(value) ~= "table" then
                value = nil
                break
            end
            value = value[path[index]]
        end
        if value ~= nil then
            return value
        end
    end
    return defaultValue
end

local function describePriorityOrder(order)
    if type(order) ~= "table" then
        return tostring(order)
    end
    local values = {}
    for key, value in pairs(order) do
        values[#values + 1] = tostring(key) .. "=" .. tostring(value)
    end
    table.sort(values)
    return table.concat(values, ",")
end

local function validatePriorityOrder(order)
    if order == nil then
        return copyArray(DefaultPriorityOrder)
    end
    if type(order) ~= "table" then
        return nil, "priority order must be a table"
    end

    local keyCount = 0
    for key in pairs(order) do
        keyCount = keyCount + 1
        if type(key) ~= "number" or key % 1 ~= 0 or key < 1 or key > #DefaultPriorityOrder then
            return nil, "priority order must be a dense array with at most five items"
        end
    end

    local seen = {}
    local copied = {}
    for index = 1, keyCount do
        local kind = order[index]
        if kind == nil then
            return nil, "priority order must be a dense array"
        end
        if not ValidReminderKinds[kind] then
            return nil, "unsupported reminder kind " .. tostring(kind)
        end
        if seen[kind] then
            return nil, "duplicate reminder kind " .. kind
        end
        seen[kind] = true
        copied[index] = kind
    end
    for index = 1, #DefaultPriorityOrder do
        local kind = DefaultPriorityOrder[index]
        if not seen[kind] then
            copied[#copied + 1] = kind
        end
    end
    return copied
end

local function resolveReminderDynamic(reminder, kind)
    -- Product policy: reward reminder animation is disabled.
    if kind == "reward" then
        return false
    end
    local dynamicKinds = type(reminder.dynamicKinds) == "table" and reminder.dynamicKinds or {}
    if dynamicKinds[kind] ~= nil then
        return dynamicKinds[kind] == true
    end
    return false
end

local function normalizeReminderIntent(intent)
    intent = type(intent) == "table" and intent or {}
    local priorityOrder, priorityError = validatePriorityOrder(intent.priorityOrder)
    if not priorityOrder then
        priorityOrder = copyArray(DefaultPriorityOrder)
    end
    local count = type(intent.count) == "number" and intent.count or 0
    local dynamicKinds = {}
    for kind in pairs(ValidReminderKinds) do
        dynamicKinds[kind] = resolveReminderDynamic(intent, kind)
    end
    return {
        visible = {
            reward = intent.rewardVisible == true,
            exclamation = intent.exclamationVisible == true,
            new = intent.newVisible == true,
            count = count > 0,
            redDot = intent.redDotVisible == true or intent.hintVisible == true,
        },
        count = count,
        dynamicKinds = dynamicKinds,
        priorityOrder = priorityOrder,
        priorityError = priorityError,
        prioritySignature = describePriorityOrder(intent.priorityOrder),
    }
end

local function normalizeDiscountIntent(intent)
    intent = type(intent) == "table" and intent or {}
    local discount = intent.discount
    local visible = intent.visible == true
    if visible then
        visible = discount ~= nil and discount < 10
    end
    return {
        visible = visible,
        discount = discount,
    }
end

local function reminderIntentFromState(state)
    local reminder = first(state, {
        {"reminder"},
    }, {}) or {}
    local rewardVisible = first(state, {
        {"reminder", "rewardVisible"},
        {"rewardReminderVisible"},
        {"rewardVisible"},
    }, false) == true
    return {
        rewardVisible = rewardVisible,
        exclamationVisible = first(state, {
            {"reminder", "exclamationVisible"},
            {"exclamationVisible"},
        }, false) == true,
        newVisible = first(state, {
            {"reminder", "newVisible"},
            {"newReminderVisible"},
            {"newVisible"},
        }, false) == true,
        count = first(state, {
            {"reminder", "count"},
            {"reminderCount"},
            {"redDotCount"},
        }, 0) or 0,
        redDotVisible = first(state, {
            {"reminder", "redDotVisible"},
            {"redDotVisible"},
            {"pureRedDotVisible"},
        }, false) == true,
        hintVisible = first(state, {
            {"reminder", "hintVisible"},
            {"hintVisible"},
        }, false) == true,
        dynamic = first(state, {
            {"reminder", "dynamic"},
            {"visual", "reminderDynamic"},
            {"visual", "rewardDynamic"},
            {"rewardDynamic"},
        }, rewardVisible) == true,
        dynamicKinds = copyMap(reminder.dynamicKinds),
        priorityOrder = reminder.priorityOrder,
    }
end

local function discountIntentFromState(state)
    local pay = first(state, {
        {"pay"},
        {"bubble", "pay"},
    })
    local enabled = type(pay) == "table" and pay.enabled ~= false
    return {
        visible = enabled and pay.discount ~= nil,
        discount = enabled and pay.discount or nil,
    }
end

local function selectReminder(reminder)
    for index = 1, #reminder.priorityOrder do
        local kind = reminder.priorityOrder[index]
        if reminder.visible[kind] then
            return {
                kind = kind,
                count = kind == "count" and reminder.count or nil,
                dynamic = reminder.dynamicKinds[kind] == true,
            }
        end
    end
end

local function visualFingerprint(snapshot)
    local reminder = snapshot.reminder or {}
    return table.concat({
        snapshot.kind,
        tostring(snapshot.discount),
        tostring(reminder.kind),
        tostring(reminder.count),
        tostring(reminder.dynamic),
        tostring(reminder.playAnimation),
    }, "|")
end

local function inputFingerprint(reminder, discount)
    local values = {
        tostring(discount.visible),
        tostring(discount.discount),
        tostring(reminder.count),
    }
    for index = 1, #DefaultPriorityOrder do
        local kind = DefaultPriorityOrder[index]
        values[#values + 1] = tostring(reminder.visible[kind])
        values[#values + 1] = tostring(reminder.dynamicKinds[kind])
        values[#values + 1] = reminder.priorityOrder[index]
    end
    return table.concat(values, "|")
end

function RightTopSlotResolver.getOrCreate(icon)
    local resolver = icon and icon.v2RightTopSlotResolver
    if resolver and resolver.icon == icon then
        return resolver
    end
    resolver = setmetatable({
        icon = icon,
        reminderIntent = normalizeReminderIntent(),
        discountIntent = normalizeDiscountIntent(),
        diagnostics = {},
        revision = 0,
    }, RightTopSlotResolver)
    if icon then
        icon.v2RightTopSlotResolver = resolver
    end
    return resolver
end

function RightTopSlotResolver:registerReminderRenderer(renderer)
    self.reminderRenderer = renderer
    if self.currentSnapshot then
        self:_applyReminderSnapshot(self.currentSnapshot)
    end
end

function RightTopSlotResolver:registerBubbleRenderer(renderer)
    self.bubbleRenderer = renderer
    if self.currentSnapshot then
        self:_applyBubbleSnapshot(self.currentSnapshot)
    end
end

function RightTopSlotResolver:unregisterReminderRenderer(renderer)
    if self.reminderRenderer == renderer then
        self.reminderRenderer = nil
    end
    self:_releaseIfUnused()
end

function RightTopSlotResolver:unregisterBubbleRenderer(renderer)
    if self.bubbleRenderer == renderer then
        self.bubbleRenderer = nil
    end
    self:_releaseIfUnused()
end

function RightTopSlotResolver:_releaseIfUnused()
    if self.reminderRenderer or self.bubbleRenderer then
        return
    end
    if self.icon and self.icon.v2RightTopSlotResolver == self then
        self.icon.v2RightTopSlotResolver = nil
    end
    self.icon = nil
end

function RightTopSlotResolver:_recordPriorityDiagnostic(reminder)
    if not reminder.priorityError then
        self.lastPriorityDiagnostic = nil
        return
    end
    local signature = reminder.priorityError .. ":" .. reminder.prioritySignature
    if self.lastPriorityDiagnostic == signature then
        return
    end
    self.lastPriorityDiagnostic = signature
    local diagnostic = {
        code = "ICON_V2_INVALID_REMINDER_PRIORITY_ORDER",
        detail = reminder.priorityError,
        configuredOrder = reminder.prioritySignature,
        iconKey = self.icon and self.icon.iconKey,
    }
    self.diagnostics[#self.diagnostics + 1] = diagnostic
    if ALog and ALog.error then
        ALog.error(diagnostic.code .. ": iconKey=" .. tostring(diagnostic.iconKey))
    end
end

function RightTopSlotResolver:_buildSnapshot(previousSnapshot)
    self.revision = self.revision + 1
    if self.discountIntent.visible and self.bubbleRenderer then
        return {
            slot = "rightTop",
            kind = "discount",
            discount = self.discountIntent.discount,
            revision = self.revision,
        }
    end

    local reminder = selectReminder(self.reminderIntent)
    if not reminder then
        return {
            slot = "rightTop",
            kind = "none",
            revision = self.revision,
        }
    end
    local recoveredFromDiscount = previousSnapshot and previousSnapshot.kind == "discount"
    reminder.playAnimation = reminder.dynamic and not recoveredFromDiscount
    return {
        slot = "rightTop",
        kind = "reminder",
        reminder = reminder,
        recoveredFromDiscount = recoveredFromDiscount == true,
        revision = self.revision,
    }
end

function RightTopSlotResolver:_applyReminderSnapshot(snapshot)
    local renderer = self.reminderRenderer
    if not renderer then
        return
    end
    if type(renderer.applyRightTopSlot) == "function" then
        return renderer:applyRightTopSlot(snapshot)
    end
    if snapshot.kind == "reminder" then
        local reminder = snapshot.reminder
        return renderer:show(reminder.kind, reminder.count, reminder.playAnimation)
    end
    return renderer:hide()
end

function RightTopSlotResolver:_applyBubbleSnapshot(snapshot)
    local renderer = self.bubbleRenderer
    if renderer and type(renderer.applyRightTopSlot) == "function" then
        return renderer:applyRightTopSlot(snapshot)
    end
end

function RightTopSlotResolver:_commit(snapshot)
    if snapshot.kind == "discount" then
        self:_applyReminderSnapshot(snapshot)
        self:_applyBubbleSnapshot(snapshot)
    else
        self:_applyBubbleSnapshot(snapshot)
        self:_applyReminderSnapshot(snapshot)
    end
end

function RightTopSlotResolver:_resolve(forceCommit)
    local currentInputFingerprint = inputFingerprint(self.reminderIntent, self.discountIntent)
    if forceCommit ~= true
        and self.currentSnapshot
        and self.lastInputFingerprint == currentInputFingerprint then
        return {
            changed = false,
            selectionChanged = false,
            snapshot = self.currentSnapshot,
            recoveredFromDiscount = self.currentSnapshot.recoveredFromDiscount == true,
        }
    end
    local previousSnapshot = self.currentSnapshot
    local snapshot = self:_buildSnapshot(previousSnapshot)
    local fingerprint = visualFingerprint(snapshot)
    local changed = forceCommit == true or fingerprint ~= self.lastVisualFingerprint
    self.currentSnapshot = snapshot
    self.lastInputFingerprint = currentInputFingerprint
    if changed then
        self.lastVisualFingerprint = fingerprint
        self:_commit(snapshot)
    end
    local previousReminderKind = previousSnapshot and previousSnapshot.reminder and previousSnapshot.reminder.kind
    local currentReminderKind = snapshot.reminder and snapshot.reminder.kind
    return {
        changed = changed,
        selectionChanged = previousSnapshot == nil
            or previousSnapshot.kind ~= snapshot.kind
            or previousReminderKind ~= currentReminderKind,
        snapshot = snapshot,
        recoveredFromDiscount = snapshot.recoveredFromDiscount == true,
    }
end

function RightTopSlotResolver:applyState(state)
    local reminder = normalizeReminderIntent(reminderIntentFromState(state or {}))
    self:_recordPriorityDiagnostic(reminder)
    self.reminderIntent = reminder
    self.discountIntent = normalizeDiscountIntent(discountIntentFromState(state or {}))
    return self:_resolve(false)
end

function RightTopSlotResolver:updateReminder(intent, forceCommit)
    local reminder = normalizeReminderIntent(intent)
    self:_recordPriorityDiagnostic(reminder)
    self.reminderIntent = reminder
    return self:_resolve(forceCommit == true)
end

function RightTopSlotResolver:rememberReminder(intent)
    local reminder = normalizeReminderIntent(intent)
    self:_recordPriorityDiagnostic(reminder)
    self.reminderIntent = reminder
end

function RightTopSlotResolver:updateDiscount(intent)
    self.discountIntent = normalizeDiscountIntent(intent)
    return self:_resolve(false)
end

function RightTopSlotResolver:isDiscountVisible()
    return self.discountIntent.visible == true
end

function RightTopSlotResolver:invalidate()
    self.lastVisualFingerprint = nil
    self.lastInputFingerprint = nil
end

function RightTopSlotResolver:getSnapshot()
    return self.currentSnapshot
end

function RightTopSlotResolver:getDiagnostics()
    return copyArray(self.diagnostics)
end

RightTopSlotResolver.DefaultPriorityOrder = DefaultPriorityOrder
RightTopSlotResolver.ValidReminderKinds = ValidReminderKinds

return RightTopSlotResolver
