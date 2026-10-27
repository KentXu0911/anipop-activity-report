local IconMeta = require "amf.feature.mainscene.module.icon.config.IconMeta"

local IconPriorityController = {}
IconPriorityController.__index = IconPriorityController

local RIGHT_SIDE_POOL = IconMeta.PoolType.kRightSide
-- Product gate: keep the creation-time business priority, but freeze it for the icon lifetime.
local DYNAMIC_PRIORITY_ENABLED = false

local function getPoolType(priority)
    return math.floor(priority / IconMeta.TypeMagicNum)
end

local function isFiniteNumber(value)
    return type(value) == "number"
        and value == value
        and value ~= math.huge
        and value ~= -math.huge
end

local function safeLog(logger, level, event, data)
    local logMethod = logger and (logger[level] or logger.log)
    if type(logMethod) == "function" then
        pcall(logMethod, logger, event, data)
        return
    end

    local alog = rawget(_G, "ALog")
    if alog and type(alog.strict_log_error) == "function" then
        pcall(
            alog.strict_log_error,
            "Icon V2 priority " .. tostring(event)
                .. ": " .. tostring(data and data.error or data and data.value)
        )
    end
end

function IconPriorityController.new(icon, options)
    options = options or {}
    local basePriority = assert(icon:getBasePriority(), "ICON_V2_BASE_PRIORITY_REQUIRED")
    return setmetatable({
        icon = icon,
        logger = options.logger,
        iconManager = options.iconManager,
        mountedResolver = options.mountedResolver,
        originalPoolType = icon:getPoolType() or getPoolType(basePriority),
        effectivePriority = basePriority,
        dynamicPriorityResolved = false,
    }, IconPriorityController)
end

function IconPriorityController.create(selfOrIcon, iconOrOptions, options)
    if selfOrIcon == IconPriorityController then
        return IconPriorityController.new(iconOrOptions, options)
    end
    return IconPriorityController.new(selfOrIcon, iconOrOptions)
end

function IconPriorityController:getEffectivePriority()
    return self.effectivePriority
end

function IconPriorityController:_isDynamicPriorityEnabled()
    return DYNAMIC_PRIORITY_ENABLED
end

function IconPriorityController:_isMounted()
    if type(self.mountedResolver) == "function" then
        local ok, mounted = pcall(self.mountedResolver, self.icon)
        if ok then
            return mounted == true
        end
        safeLog(self.logger, "error", "icon_priority_mounted_check_failed", {
            error = mounted,
            iconKey = self.icon and self.icon.iconKey,
        })
        return false
    end

    local capability = self.icon and self.icon.activityEventCapability
    return capability ~= nil and capability.mounted == true
end

function IconPriorityController:_validate(priority)
    if not isFiniteNumber(priority) then
        return false, "priority_not_finite_number"
    end
    if priority < IconMeta.PriorityBottom or priority > IconMeta.PriorityTop then
        return false, "priority_out_of_range"
    end
    if getPoolType(priority) ~= self.originalPoolType then
        return false, "priority_crosses_pool_type"
    end
    return true
end

function IconPriorityController:_resolveIconManager()
    if self.iconManager then
        return self.iconManager
    end
    if type(_G.amfBean) ~= "function" then
        return nil
    end
    local ok, manager = pcall(_G.amfBean, "IconManager")
    if ok then
        return manager
    end
    safeLog(self.logger, "error", "icon_priority_manager_resolve_failed", {
        error = manager,
        iconKey = self.icon and self.icon.iconKey,
    })
end

function IconPriorityController:_requestReorder(reason)
    local manager = self:_resolveIconManager()
    if not manager or type(manager.requestReorderIcon) ~= "function" then
        safeLog(self.logger, "error", "icon_priority_reorder_api_missing", {
            error = "IconManager:requestReorderIcon unavailable",
            iconKey = self.icon and self.icon.iconKey,
            reason = reason,
        })
        return
    end

    local ok, requested, requestError = pcall(manager.requestReorderIcon, manager, self.icon, reason)
    if not ok or requested == false then
        safeLog(self.logger, "error", "icon_priority_reorder_request_failed", {
            error = ok and requestError or requested,
            iconKey = self.icon and self.icon.iconKey,
            reason = reason,
        })
        return false
    end
    return true
end

function IconPriorityController:refresh(state, reason, payload)
    local basePriority = self.icon:getBasePriority()
    local dynamicPriorityEnabled = self:_isDynamicPriorityEnabled()
    local initialStaticResolution = not dynamicPriorityEnabled and not self.dynamicPriorityResolved
    local dynamicPriority = self.effectivePriority
    if dynamicPriorityEnabled or initialStaticResolution then
        local dynamicMethod = self.icon and self.icon.getDynamicPriority
        local ok
        ok, dynamicPriority = pcall(dynamicMethod, self.icon, state, reason, payload)
        if not ok then
            safeLog(self.logger, "error", "icon_priority_dynamic_callback_failed", {
                error = dynamicPriority,
                iconKey = self.icon and self.icon.iconKey,
                reason = reason,
            })
            dynamicPriority = basePriority
        elseif dynamicPriority == nil then
            dynamicPriority = basePriority
        else
            local valid, invalidReason = self:_validate(dynamicPriority)
            if not valid then
                safeLog(self.logger, "warn", "icon_priority_dynamic_value_rejected", {
                    error = invalidReason,
                    value = dynamicPriority,
                    iconKey = self.icon and self.icon.iconKey,
                    reason = reason,
                })
                dynamicPriority = basePriority
            end
        end
        self.dynamicPriorityResolved = true
    end

    if self.originalPoolType ~= RIGHT_SIDE_POOL and dynamicPriority ~= basePriority then
        safeLog(self.logger, "warn", "icon_priority_dynamic_value_rejected", {
            error = "dynamic_priority_unsupported_pool",
            value = dynamicPriority,
            iconKey = self.icon and self.icon.iconKey,
            reason = reason,
        })
        dynamicPriority = basePriority
    end

    local oldPriority = self.effectivePriority
    if oldPriority == dynamicPriority then
        return false
    end

    self.effectivePriority = dynamicPriority
    if self.originalPoolType == RIGHT_SIDE_POOL
        and self:_isMounted()
        and not initialStaticResolution
        and not self:_requestReorder(reason)
    then
        self.effectivePriority = oldPriority
        return false
    end
    return true
end

function IconPriorityController:dispose()
    self.icon = nil
    self.iconManager = nil
    self.mountedResolver = nil
    self.dynamicPriorityResolved = nil
end

return IconPriorityController
