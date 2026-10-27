local IconV2Config = {}
local IconV2VisualAssets =
    require "amf.feature.mainscene.module.icon.v2.render.IconV2VisualAssets"
local ICON_MINIGAME = "amf/activity/newbiegiftoptimize/spine/tiaoxuanyige_minigame.png"

local function isMiniGame()
    return EnvUtil
        and type(EnvUtil.isMiniGame) == "function"
        and EnvUtil:isMiniGame() == true
end

local function createIconAsset(path)
    if isMiniGame() then
        return {
            type = "spriteFile",
            path = ICON_MINIGAME,
        }
    end
    return {
        type = "spine",
        path = path,
        animations = { idle = "idle1", reward = "idle2" },
    }
end

local function createSurface()
    return {
        size = { width = 136, height = 136 },
        layers = {
            {
                id = "giftBg",
                zOrder = 0,
                asset = {
                    type = "spriteFile",
                    path = IconV2VisualAssets.GiftPurpleBackground,
                },
            },
        },
    }
end

function IconV2Config.getPreloadFiles(path)
    local files = { path }
    if isMiniGame() then
        files[#files + 1] = ICON_MINIGAME
    end
    files[#files + 1] = IconV2VisualAssets.GiftPurpleBackground
    return files
end

function IconV2Config.create(manager, giftType, iconEventCenter)
    local IconConfig = require "amf.feature.mainscene.module.icon.config.IconConfig"
    local IconData = require "amf.feature.localactivity.newbiegiftoptimize.icon.NewbieGiftChoiceIconData"
    local ownerIconKey = manager.ICONKEY[giftType]
    local info = assert(IconConfig:getInfoByKey(ownerIconKey), "NEWBIE_GIFT_CHOICE_ICON_INFO_REQUIRED")
    local path = assert(manager.ICONSPINE[giftType], "NEWBIE_GIFT_CHOICE_ICON_ASSET_REQUIRED")
    local label = manager:getGiftIconLabelText(giftType)
    local provider = IconData:create(manager)

    return {
        ownerIconKey = ownerIconKey,
        ownerIdentity = manager,
        iconEventCenter = iconEventCenter,
        legacyFactory = function()
            return manager:createLegacyActivityIcon(giftType, path)
        end,
        metadata = {
            actId = manager.ACT_ID,
            iconKey = ownerIconKey,
            iconInfo = info,
            poolType = info:getPoolType(),
            basePriority = info:getPriority(),
            label = label,
            ambientIdle2Eligible = true,
            asset = createIconAsset(path),
            surface = createSurface(),
            newActivityType = "none",
        },
        provider = provider,
        ownerReleaseCommand = function(receivedIcon)
            local icon = manager:getActivityIcon(giftType)
            if icon and receivedIcon and icon ~= receivedIcon then
                return false, "NEWBIE_GIFT_CHOICE_ICON_OWNER_MISMATCH"
            end
            icon = icon or receivedIcon
            local removed, removeError = manager:removeActivityIcon(icon, giftType)
            if removed == false then
                return false, removeError or "NEWBIE_GIFT_CHOICE_ICON_OWNER_RELEASE_FAILED"
            end
            return true
        end,
        touchCommand = function()
            if manager:checkTypeEnabled(giftType) ~= true then
                return false, "NEWBIE_GIFT_CHOICE_ICON_NOT_AVAILABLE", false
            end
            manager:openActivity(giftType, {}, true)
            return true, nil, true
        end,
    }, provider
end

return IconV2Config
