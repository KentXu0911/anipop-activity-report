local DailyLevelConst = require "amf.feature.localactivity.dailylevel.config.DailyLevelConst"
local Res = require "amf.feature.localactivity.dailylevel.config.Res"

local IconV2Config = {}

local function isMiniGame()
    if not EnvUtil or type(EnvUtil.isMiniGame) ~= "function" then return false end
    local ok, result = pcall(EnvUtil.isMiniGame, EnvUtil)
    return ok and result == true
end

local function currentWeekend()
    if type(isWeekend) ~= "function" or not TimeKit or type(TimeKit.timeInSec) ~= "function" then
        return false
    end
    local ok, result = pcall(isWeekend, TimeKit:timeInSec())
    return ok and result == true
end

local function buildAssetVariants()
    if isMiniGame() then
        return {
            weekday = { type = "spriteFile", path = Res.Texture.ICON_WEEKDAY_MINIGAME },
            weekend = { type = "spriteFile", path = Res.Texture.ICON_WEEKEND_MINIGAME },
        }
    end
    return {
        weekday = { type = "spine", path = Res.Spine.ICON_WEEKDAY_V2 },
        weekend = { type = "spine", path = Res.Spine.ICON_WEEKEND_V2, scale = 0.9 },
    }
end

function IconV2Config.create(manager, iconEventCenter)
    local IconConfig = require "amf.feature.mainscene.module.icon.config.IconConfig"
    local IconData = require "amf.feature.localactivity.dailylevel.icon.IconData"
    local DailyLevelPackageIcon = require "amf.feature.localactivity.dailylevel.icon.DailyLevelPackageIcon"
    local NewActivityRecordStore = require
        "amf.feature.mainscene.module.icon.v2.newactivity.NewActivityRecordStore"
    local ownerIconKey = IconKey.kDailyLevel
    local iconInfo = assert(IconConfig:getInfoByKey(ownerIconKey), "DAILY_LEVEL_ICON_INFO_REQUIRED")
    local provider = IconData:create(manager)
    local variants = buildAssetVariants()
    local defaultAssetKey = currentWeekend() and "weekend" or "weekday"
    local defaultAsset = variants[defaultAssetKey]

    return {
        ownerIconKey = ownerIconKey,
        ownerIdentity = manager,
        iconEventCenter = iconEventCenter,
        v2Class = DailyLevelPackageIcon,
        legacyFactory = function()
            return manager:createLegacyIcon()
        end,
        metadata = {
            actId = DailyLevelConst.ACT_ID,
            iconKey = ownerIconKey,
            iconInfo = iconInfo,
            poolType = iconInfo:getPoolType(),
            basePriority = iconInfo:getPriority(),
            label = DailyLevelConst.ACT_NAME,
            asset = {
                type = defaultAsset.type,
                path = defaultAsset.path,
                variants = variants,
                defaultAssetKey = defaultAssetKey,
            },
            newActivityType = "C",
            newActivityCycleKey = provider:resolveCycleKey(),
        },
        provider = provider,
        newActivityRecordStore = NewActivityRecordStore:create(function()
            return _G.amfBean and _G.amfBean("AutoPopupMgr") or nil
        end),
        newActivityCycleKeyResolver = function()
            return provider:resolveCycleKey()
        end,
        isNewActivityTimePermitted = function()
            return manager:isEnabled() == true
        end,
        countdownReachedCommand = function(_, payload)
            return manager:refreshV2Icon("countdown_reached", payload)
        end,
        lifecycleEndTimeResolver = function()
            if manager:isInMainTime() then
                return manager:getMainEndTimeInSec(), "main_end"
            end
            if manager:isInAwardTime() then
                return manager:getEndTimeInSec(), "activity_end"
            end
            return nil, "inactive"
        end,
        lifecycleBoundaryCommand = function(_, payload)
            return manager:handleV2IconLifecycleBoundary(payload)
        end,
        touchCommand = function()
            if manager:isIconEnabled() ~= true then
                return false, "DAILY_LEVEL_ICON_NOT_AVAILABLE", false
            end
            manager:openMainPanel({
                userClick = true,
                loading = true,
            })
            return true, nil, true
        end,
    }, provider
end

return IconV2Config
