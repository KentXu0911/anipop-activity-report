local IconV2Config = {}
local IconV2VisualAssets =
    require "amf.feature.mainscene.module.icon.v2.render.IconV2VisualAssets"
local ICON_V2_SPINE = "amf/activity/collectcard/icon/jika_icon_v2.skel"
local ICON_V2_MINIGAME = "amf/activity/collectcard/icon/jika_icon_v2_minigame.png"

local function isMiniGame()
    return EnvUtil
        and type(EnvUtil.isMiniGame) == "function"
        and EnvUtil:isMiniGame() == true
end

local function createIconAsset()
    if isMiniGame() then
        return {
            type = "spriteFile",
            path = ICON_V2_MINIGAME,
        }
    end
    return {
        type = "spine",
        path = ICON_V2_SPINE,
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

function IconV2Config.getPreloadFile()
    return isMiniGame() and ICON_V2_MINIGAME or ICON_V2_SPINE
end

function IconV2Config.getPreloadFiles(path)
    return {
        path,
        IconV2Config.getPreloadFile(),
        IconV2VisualAssets.GiftPurpleBackground,
    }
end

function IconV2Config.create(manager, iconEventCenter)
    local IconConfig = require "amf.feature.mainscene.module.icon.config.IconConfig"
    local IconData = require "amf.feature.localactivity.collectcard.icon.CollectCardGiftIconData"
    local CollectCardGiftPackageIcon = require
        "amf.feature.localactivity.collectcard.icon.CollectCardGiftPackageIcon"
    local ownerIconKey = IconKey.kCollectCardGiftIcon
    local info = assert(IconConfig:getInfoByKey(ownerIconKey), "COLLECT_CARD_GIFT_ICON_INFO_REQUIRED")
    local provider = IconData:create(manager)

    return {
        ownerIconKey = ownerIconKey,
        ownerIdentity = assert(manager.iconModule, "COLLECT_CARD_GIFT_ICON_OWNER_REQUIRED"),
        iconEventCenter = iconEventCenter,
        v2Class = CollectCardGiftPackageIcon,
        legacyFactory = function()
            return manager.iconModule:createLegacyGiftIcon()
        end,
        metadata = {
            actId = manager.ACT_ID,
            iconKey = ownerIconKey,
            iconInfo = info,
            poolType = info:getPoolType(),
            basePriority = info:getPriority(),
            label = "新卡礼包",
            ambientIdle2Eligible = true,
            asset = createIconAsset(),
            surface = createSurface(),
            newActivityType = "B",
        },
        provider = provider,
        newActivityRecordStore = manager:createCollectCardGiftIconNewActivityRecordStore(),
        newActivityCycleKeyResolver = function()
            return provider:resolveCycleKey()
        end,
        countdownReachedCommand = function()
            local iconModule = manager.iconModule
            if not iconModule or type(iconModule.clearGiftIcon) ~= "function" then
                return false, "COLLECT_CARD_GIFT_ICON_OWNER_CLEANUP_REQUIRED"
            end
            if iconModule.giftIconAdapter == nil and iconModule.giftIcon == nil then
                return true
            end
            return iconModule:clearGiftIcon()
        end,
        isNewActivityTimePermitted = function()
            return manager.iconModule:needShowGiftIcon()
        end,
        touchCommand = function()
            if not manager.iconModule:needShowGiftIcon() then
                return false, "COLLECT_CARD_GIFT_ICON_NOT_AVAILABLE", false
            end
            manager:onGiftIconTapped()
            return true, nil, true
        end,
    }, provider
end

return IconV2Config
