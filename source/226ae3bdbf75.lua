local IProcessor = require "amf.middleware.activity.processor.IProcessor"
local IconProcessor = class("IconProcessor").implement(IProcessor)
local ActivityDebugLog = require "amf.middleware.activity.debug.ActivityDebugLog"

local DATA_DRIVEN_ICON_CLASS = "amf.feature.mainscene.module.icon.v2.view.DataDrivenActivityIconButton"
local ICON_V2_EXPERIMENT = "amf.feature.mainscene.module.icon.v2.experiment.IconV2Experiment"
local ACTIVITY_OWNER_RELEASE_COORDINATOR =
    "amf.middleware.activity.processor.ActivityOwnerReleaseCoordinator"
local NEW_ACTIVITY_NOTIFICATION_CONTRACT = {
    DATA_DRIVEN = "dataDriven",
    LEGACY = "legacy",
    NONE = "none",
}
local DATA_DRIVEN_CLEANUP_FAILED = "data_driven_cleanup_failed"
local DATA_DRIVEN_NOT_PRESENT = "data_driven_not_present"
local DATA_DRIVEN_OWNER_RELEASE_FAILED = "data_driven_owner_release_failed"

local function deepCopyTable(source, seen)
    seen = seen or {}
    if seen[source] then
        return seen[source]
    end
    local copied = {}
    seen[source] = copied
    for key, value in pairs(source) do
        copied[key] = type(value) == "table" and deepCopyTable(value, seen) or value
    end
    return copied
end

local function copyAsset(asset)
    if type(asset) ~= "table" or next(asset) == nil then
        return nil
    end
    return deepCopyTable(asset)
end

local function resolveMiniGameNotificationAsset(config, iconBtn)
    local iconConfig = type(config) == "table" and config.icon or nil
    if type(iconConfig) ~= "table" then
        return nil
    end

    local asset = copyAsset(iconConfig.miniGameNotificationAsset)
        or copyAsset(iconConfig.miniGameAsset)
        or copyAsset(iconBtn and iconBtn.assetConfig)
    if asset then
        return asset
    end

    local assets = iconConfig.miniGameAssets
    local defaultAssetKey = iconConfig.defaultAssetKey
    return copyAsset(type(assets) == "table" and assets[defaultAssetKey] or nil)
end

local function getExplicitNewActivityCycleKey(config)
    local iconConfig = type(config) == "table" and config.icon or nil
    local cycleKey = type(iconConfig) == "table" and iconConfig.newActivityCycleKey or nil
    if type(cycleKey) == "string" and cycleKey ~= "" then
        return cycleKey
    end
end

local function callCleanupMethod(iconBtn, methodName)
    if type(iconBtn[methodName]) ~= "function" then
        return false, "missing " .. methodName
    end

    local success, result, detail = pcall(iconBtn[methodName], iconBtn)
    if not success then
        return false, result
    end
    if result == false then
        return false, detail or (methodName .. " returned false")
    end
    return true
end

function IconProcessor:ctor()
    self._iconSystemReady = false
end

function IconProcessor:create(source, actId)
    local cls = self.new()
    cls:init(source, actId)
    return cls
end

function IconProcessor:init(source, actId)
    self._source = source
    self._actId = actId

    self._iconSystemReady = false
    self._failedCleanupIcon = nil
    self._failedCleanupNeedsRemove = false
    self._failedCleanupNeedsDispose = false
    self._failedCleanupError = nil
    self._ownerReleaseCoordinator = nil
end

function IconProcessor:setIconSystemReady(ready)
    self._iconSystemReady = ready
end

function IconProcessor:setPopTimeEnabled(enabled)
    self._popTimeEnabled = enabled
end

function IconProcessor:process(actInfo)
    if not self._iconSystemReady then return end
    if self:checkNoIcon() then return end

    local ownerReleaseCoordinator = self._ownerReleaseCoordinator
    if ownerReleaseCoordinator and ownerReleaseCoordinator:isReleased() then
        return true, "released"
    end
    if ownerReleaseCoordinator and ownerReleaseCoordinator:hasPendingRelease() then
        return ownerReleaseCoordinator:retryRelease({
            reason = "retry",
        })
    end

    local config = require("activity/" .. self._source)
    local result
    if type(config) == "table" and config.isSupport then
        pcall(function(...)
            result = config.isSupport()
        end)
    end
    if self:checkNoIcon() then return end
    if not result then
        return false
    end

    if self.iconBtn and self.iconBtn.isDisposed then
        self.iconBtn = nil
        self._isDataDrivenIcon = nil
        self._explicitNewActivityCycleKey = nil
    end

    if self._failedCleanupIcon then
        local cleaned, cleanupError = self:cleanupFailedDataDrivenIcon()
        if not cleaned then
            return false, cleanupError
        end
    end

    if self.iconBtn
        and self._isDataDrivenIcon == true
        and self.iconBtn._structuralCleanupPending == true
    then
        local destroyed, destroyError = self:destroyDataDrivenIconBtn()
        if not destroyed then
            return false, destroyError
        end
    end

    local explicitCycleKey = getExplicitNewActivityCycleKey(config)
    if self.iconBtn
        and self._isDataDrivenIcon == true
        and self._explicitNewActivityCycleKey ~= explicitCycleKey
    then
        return self:rebuildIcon(actInfo)
    end

    if not self.iconBtn then
        local iconBtn, isDataDrivenIcon, mountResult, notificationContract, buildError =
            self:buildIconBtn(self._source, actInfo)
        if mountResult == DATA_DRIVEN_CLEANUP_FAILED then
            ActivityDebugLog:log(self._actId .. " Icon V2清理未完成，暂不创建")
            return
        end
        if mountResult == DATA_DRIVEN_OWNER_RELEASE_FAILED then
            return false, buildError
        end
        if mountResult == DATA_DRIVEN_NOT_PRESENT then
            return true, mountResult
        end
        self.iconBtn = iconBtn
        self._isDataDrivenIcon = isDataDrivenIcon == true
        self._explicitNewActivityCycleKey = self._isDataDrivenIcon
            and explicitCycleKey or nil

        notificationContract = notificationContract
            or (isDataDrivenIcon
                and NEW_ACTIVITY_NOTIFICATION_CONTRACT.DATA_DRIVEN
                or NEW_ACTIVITY_NOTIFICATION_CONTRACT.LEGACY)
        if self._popTimeEnabled
            and notificationContract ~= NEW_ACTIVITY_NOTIFICATION_CONTRACT.NONE
        then
            self:tryAddNewIconActAutoPopup(
                self._source,
                notificationContract == NEW_ACTIVITY_NOTIFICATION_CONTRACT.DATA_DRIVEN
            )
        end
        if not isDataDrivenIcon then
            self.iconBtn:addToUI()
        end
        ActivityDebugLog:log(self._actId .. "icon创建成功")
    end

    self:refreshActIconFlag(actInfo)
end

--活动没icon
function IconProcessor:checkNoIcon()
    local config = require("activity/" .. self._source)
    return not config.icon
end

function IconProcessor:rebuildIcon(actInfo)
    local cleaned, cleanupError = self:cleanupFailedDataDrivenIcon()
    if not cleaned then
        return false, cleanupError
    end
    if self._isDataDrivenIcon == true then
        local destroyed, destroyError = self:destroyDataDrivenIconBtn()
        if not destroyed then
            return false, destroyError
        end
    else
        self:removeIconBtn()
    end
    return self:process(actInfo)
end

function IconProcessor:removeIconBtn()
    local iconBtn = self.iconBtn
    self.iconBtn = nil
    self._isDataDrivenIcon = nil
    self._explicitNewActivityCycleKey = nil
    if iconBtn and not iconBtn.isDisposed then
        iconBtn:removeFromUI()
    end
end

function IconProcessor:destroyDataDrivenIconBtn()
    local iconBtn = self.iconBtn
    self.iconBtn = nil
    self._isDataDrivenIcon = nil
    self._explicitNewActivityCycleKey = nil
    if not iconBtn or iconBtn.isDisposed then
        return true
    end

    self._failedCleanupIcon = iconBtn
    self._failedCleanupNeedsRemove = true
    self._failedCleanupNeedsDispose = true
    self._failedCleanupError = nil
    return self:cleanupFailedDataDrivenIcon()
end

function IconProcessor:_disposeUnmountedDataDrivenIcon(iconBtn)
    if not iconBtn or iconBtn.isDisposed then
        return true
    end
    self._failedCleanupIcon = iconBtn
    self._failedCleanupNeedsRemove = false
    self._failedCleanupNeedsDispose = true
    self._failedCleanupError = nil
    return self:cleanupFailedDataDrivenIcon()
end

function IconProcessor:_getOrCreateOwnerReleaseCoordinator()
    if self._ownerReleaseCoordinator then
        return self._ownerReleaseCoordinator
    end
    local ActivityOwnerReleaseCoordinator = require(ACTIVITY_OWNER_RELEASE_COORDINATOR)
    self._ownerReleaseCoordinator = ActivityOwnerReleaseCoordinator.create({
        getActivityConfig = function()
            return require("activity/" .. self._source)
        end,
        cleanupIcon = function()
            return self:_disposeIconLocally()
        end,
        retryPendingIconCleanup = function()
            return self:cleanupFailedDataDrivenIcon()
        end,
        hasPendingIconCleanup = function()
            return self._failedCleanupIcon ~= nil, self._failedCleanupError
        end,
    })
    return self._ownerReleaseCoordinator
end

function IconProcessor:requestOwnerRelease(iconBtn, providerResult, context)
    if iconBtn and self.iconBtn and iconBtn ~= self.iconBtn then
        return true, "stale_icon"
    end
    local coordinator = self._ownerReleaseCoordinator
    if not coordinator then
        return false, "ICON_V2_ACTIVITY_OWNER_RELEASE_COORDINATOR_REQUIRED"
    end
    return coordinator:requestRelease(providerResult, context)
end

function IconProcessor:cleanupFailedDataDrivenIcon()
    local iconBtn = self._failedCleanupIcon
    if not iconBtn then
        self._failedCleanupIcon = nil
        self._failedCleanupNeedsRemove = false
        self._failedCleanupNeedsDispose = false
        self._failedCleanupError = nil
        return true
    end

    if self._failedCleanupNeedsRemove then
        local removed, removeError = callCleanupMethod(iconBtn, "removeFromUI")
        if not removed then
            self._failedCleanupError = removeError
            ActivityDebugLog:logError(
                "[IconV2] failed icon cleanup failed source=" .. tostring(self._source)
                .. " actId=" .. tostring(self._actId)
                .. " stage=removeFromUI reason=" .. tostring(removeError)
            )
            return false, removeError
        end
        self._failedCleanupNeedsRemove = false
        if iconBtn.isDisposed then
            self._failedCleanupNeedsDispose = false
        end
    end

    if self._failedCleanupNeedsDispose then
        local disposed, disposeError = callCleanupMethod(iconBtn, "dispose")
        if not disposed then
            self._failedCleanupError = disposeError
            ActivityDebugLog:logError(
                "[IconV2] failed icon cleanup failed source=" .. tostring(self._source)
                .. " actId=" .. tostring(self._actId)
                .. " stage=dispose reason=" .. tostring(disposeError)
            )
            return false, disposeError
        end
    end

    self._failedCleanupIcon = nil
    self._failedCleanupNeedsRemove = false
    self._failedCleanupNeedsDispose = false
    self._failedCleanupError = nil
    return true
end

function IconProcessor:buildIconBtn(source, actInfo)
    local config = require("activity/" .. source)

    if self:shouldUseDataDrivenIcon(config) then
        local iconBtn, mountResult, buildError = self:buildDataDrivenIconBtn(config, actInfo)
        if mountResult == DATA_DRIVEN_CLEANUP_FAILED then
            return nil, true, mountResult, NEW_ACTIVITY_NOTIFICATION_CONTRACT.NONE, buildError
        end
        if mountResult == DATA_DRIVEN_NOT_PRESENT
            or mountResult == DATA_DRIVEN_OWNER_RELEASE_FAILED
        then
            return nil, true, mountResult, NEW_ACTIVITY_NOTIFICATION_CONTRACT.NONE, buildError
        end
        if iconBtn then
            return iconBtn, true, mountResult,
                NEW_ACTIVITY_NOTIFICATION_CONTRACT.DATA_DRIVEN
        end
        return self:buildLegacyIconBtn(config), false, nil,
            NEW_ACTIVITY_NOTIFICATION_CONTRACT.NONE
    end

    return self:buildLegacyIconBtn(config), false, nil,
        NEW_ACTIVITY_NOTIFICATION_CONTRACT.LEGACY
end

function IconProcessor:buildDataDrivenIconBtn(config, actInfo)
    if self._failedCleanupIcon then
        return nil, DATA_DRIVEN_CLEANUP_FAILED, self._failedCleanupError
    end

    local iconBtn = nil
    local mountResult = nil
    local notPresentResult = nil
    local stage = "require"
    local success, err = pcall(function()
        local DataDrivenActivityIconButton = require(DATA_DRIVEN_ICON_CLASS)

        stage = "instantiate"
        assert(type(DataDrivenActivityIconButton.new) == "function", "missing new")
        iconBtn = DataDrivenActivityIconButton.new()
        assert(iconBtn, "new returned nil")
        stage = "owner_release_coordinator"
        self:_getOrCreateOwnerReleaseCoordinator()
        local ownerReleaseRequester = function(requestIcon, providerResult, context)
            return self:requestOwnerRelease(requestIcon, providerResult, context)
        end
        if type(iconBtn.setOwnerReleaseRequester) == "function" then
            iconBtn:setOwnerReleaseRequester(ownerReleaseRequester)
        else
            iconBtn._ownerReleaseRequester = ownerReleaseRequester
        end

        stage = "initialize"
        assert(type(iconBtn.init) == "function", "missing init")
        local initialized, initError = iconBtn:init(config)
        if initialized == false or initError ~= nil then
            error(initError or "init returned false", 0)
        end

        if actInfo and type(iconBtn.onActivityStatusChange) == "function" then
            stage = "initialize_act_info"
            local refreshed, refreshError = iconBtn:onActivityStatusChange(actInfo)
            if refreshed == false then
                error(refreshError or "initial actInfo refresh returned false", 0)
            end
        end

        stage = "activate_mount_state"
        assert(type(iconBtn.activateMountState) == "function", "missing activateMountState")
        local activated, activateResult, activateDetail = iconBtn:activateMountState()
        if activated ~= true then
            error(activateResult or "activateMountState returned false", 0)
        end
        if activateResult == "not_present" then
            mountResult = DATA_DRIVEN_NOT_PRESENT
            notPresentResult = activateDetail
            return
        end
        assert(activateResult == "mounted", "invalid activateMountState result")
        mountResult = activateResult
    end)
    if success then
        if mountResult == DATA_DRIVEN_NOT_PRESENT then
            local coordinator = self:_getOrCreateOwnerReleaseCoordinator()
            coordinator:stageRelease(notPresentResult)
            local cleaned, cleanupError = self:_disposeUnmountedDataDrivenIcon(iconBtn)
            if not cleaned then
                return nil, DATA_DRIVEN_CLEANUP_FAILED, cleanupError
            end
            local released, releaseError = coordinator:requestRelease(nil, {
                reason = "provider_not_present_before_mount",
            })
            if not released then
                return nil, DATA_DRIVEN_OWNER_RELEASE_FAILED, releaseError
            end
            return nil, DATA_DRIVEN_NOT_PRESENT, notPresentResult
        end
        self:notifyDataDrivenIconMounted(config)
        return iconBtn, mountResult
    end

    self:logDataDrivenFallback(stage, err)
    local cleaned, cleanupError = self:disposeFailedDataDrivenIcon(iconBtn)
    if not cleaned then
        return nil, DATA_DRIVEN_CLEANUP_FAILED, cleanupError
    end
end

function IconProcessor:notifyDataDrivenIconMounted(config)
    local iconConfig = type(config) == "table" and rawget(config, "icon") or nil
    local onMounted = type(iconConfig) == "table" and rawget(iconConfig, "onMounted") or nil
    if type(onMounted) ~= "function" then return end

    local success, err = pcall(onMounted)
    if success then return end

    pcall(function()
        ActivityDebugLog:logError(
            "[IconV2] onMounted failed source=" .. tostring(self._source)
            .. " actId=" .. tostring(self._actId)
            .. " reason=" .. tostring(err)
        )
    end)
end

function IconProcessor:shouldUseDataDrivenIcon(config)
    if type(config) ~= "table" or type(config.icon) ~= "table" then
        return false
    end
    if config.icon.mode ~= "dataDriven" then
        return false
    end
    if type(config.icon.dataProvider) ~= "string" or config.icon.dataProvider == "" then
        self:logDataDrivenFallback("config", "invalid dataProvider")
        return false
    end

    local success, enabled = pcall(function()
        local IconV2Experiment = require(ICON_V2_EXPERIMENT)
        return IconV2Experiment:isEnabled()
    end)
    if not success then
        self:logDataDrivenFallback("experiment", enabled)
        return false
    end
    if enabled ~= true then
        self:logDataDrivenFallback("experiment", "NewVineicon_v2/ON disabled or missing")
        return false
    end

    local useDataDrivenWhen = rawget(config.icon, "useDataDrivenWhen")
    if useDataDrivenWhen == nil then
        return true
    end
    if type(useDataDrivenWhen) ~= "function" then
        self:logDataDrivenFallback("selection", "icon.useDataDrivenWhen must be a function")
        return false
    end

    local selected, shouldUse = pcall(useDataDrivenWhen)
    if not selected then
        self:logDataDrivenFallback("selection", shouldUse)
        return false
    end
    if type(shouldUse) ~= "boolean" then
        self:logDataDrivenFallback(
            "selection",
            "icon.useDataDrivenWhen must return a boolean"
        )
        return false
    end

    return shouldUse
end

function IconProcessor:buildLegacyIconBtn(config)
    local iconBtn = nil
    if type(config.icon) == "string" then
        iconBtn = ActivityIconButton:create(config)
    elseif type(config.icon) == "table" then
        local uri = "activity/" .. config.icon.startLua
        iconBtn = require(uri):create()
    end

    return iconBtn
end

function IconProcessor:logDataDrivenFallback(stage, reason)
    ActivityDebugLog:logError(
        "[IconV2] fallback source=" .. tostring(self._source)
        .. " actId=" .. tostring(self._actId)
        .. " stage=" .. tostring(stage)
        .. " reason=" .. tostring(reason)
    )
end

function IconProcessor:disposeFailedDataDrivenIcon(iconBtn)
    if not iconBtn then return true end

    self._failedCleanupIcon = iconBtn
    self._failedCleanupNeedsRemove = not iconBtn.isDisposed
    self._failedCleanupNeedsDispose = not iconBtn.isDisposed
    self._failedCleanupError = nil
    return self:cleanupFailedDataDrivenIcon()
end

function IconProcessor:refreshActIconFlag(actInfo)

    if actInfo then
        if not actInfo or tonumber(actInfo.actId) ~= tonumber(self._actId) then
            return
        end

        if self.iconBtn and not self.iconBtn.isDisposed and actInfo then
            self.iconBtn:onActivityStatusChange({
                actId = self._actId,
                reward = actInfo.reward,
                msgNum = actInfo.msgNum,
                rank = actInfo.rank,
                progress = actInfo.progress,
                maxProgress = actInfo.maxProgress
            })
        end
    else
        --没有actInfo的活动icon尝试刷新
        if self.iconBtn then
            self.iconBtn:updateState()
        end
    end
end

--添加发现新活动强弹
function IconProcessor:tryAddNewIconActAutoPopup(source, isDataDrivenIcon)
    local config = require("activity/" .. source)
    if isDataDrivenIcon then
        if not self.iconBtn or type(self.iconBtn.buildNewActivityNotificationCandidate) ~= "function" then
            return
        end
        local iconLabelStr = self.iconBtn.btnLabel
        if type(iconLabelStr) ~= "string" or iconLabelStr == "" then
            iconLabelStr = config.icon and (config.icon.btnLabel or config.icon.iconLabel)
        end
        local candidate = self.iconBtn:buildNewActivityNotificationCandidate({
            source = source,
            actId = config.actId,
            iconKey = tostring(config.actId),
            iconLabelStr = iconLabelStr,
            miniGameStaticIconAsset = resolveMiniGameNotificationAsset(config, self.iconBtn),
            v2Notification = true,
        })
        if candidate then
            _G.amfBean("PopupNewActMgr"):addDataDrivenNewActivityCandidate(source, candidate)
        end
        return
    end
    --is new act
	local uniqueKey = ActivityUtil:getActUniqueKey(config)
	if uniqueKey then
		local panelShowNum = _G.amfBean("AutoPopupMgr"):getPermanentShowNum(uniqueKey .. "_panel")
        local tbl = {
            uniqueKey = uniqueKey,
            iconKey = tostring(config.actId),
            iconLabel = config.icon and config.icon.iconLabel,
        }

        if panelShowNum < 1 then
            _G.amfBean("PopupNewActMgr"):addNewAutoPopAct(source, tbl)
        end
	end
end

function IconProcessor:_disposeIconLocally()
    local cleaned, cleanupError = self:cleanupFailedDataDrivenIcon()
    if not cleaned then
        return false, cleanupError
    end

    if self._isDataDrivenIcon == true then
        local destroyed, destroyError = self:destroyDataDrivenIconBtn()
        if not destroyed then
            return false, destroyError
        end
    else
        self:removeIconBtn()
    end
    return true
end

function IconProcessor:dispose()
    if self._ownerReleaseCoordinator then
        return self._ownerReleaseCoordinator:handleProcessorDispose({
            isDataDrivenIcon = self._isDataDrivenIcon == true,
        })
    end
    return self:_disposeIconLocally()
end

return IconProcessor
