local IconV2Config = {}
local Res = require "amf.feature.localactivity.waterfallgift.config.Res"

local function createIconAsset()
    if EnvUtil:isMiniGame() then
        return {
            type = "spriteFile",
            path = Res.Texture.ICON_MINIGAME,
        }
    end
    return {
        type = "spine",
        path = Res.Spine.ICON_V2,
        animations = { idle = "idle1", reward = "idle2" },
    }
end

function IconV2Config.getPreloadFiles()
    return {
        createIconAsset().path,
        Res.Texture.ICON_V2_BG,
    }
end

function IconV2Config.create(manager, iconEventCenter)
    local IconConfig = require "amf.feature.mainscene.module.icon.config.IconConfig"
    local IconData = require "amf.feature.localactivity.waterfallgift.icon.IconData"
    local ownerIconKey = IconKey.kWaterfallGift
    local iconInfo = assert(IconConfig:getInfoByKey(ownerIconKey), "WATERFALL_GIFT_ICON_INFO_REQUIRED")
    local provider = IconData:create(manager)

    return {
        ownerIconKey = ownerIconKey,
        iconEventCenter = iconEventCenter,
        legacyFactory = function()
            return manager:createLegacyIcon()
        end,
        metadata = {
            actId = 3076,
            iconKey = ownerIconKey,
            ambientIdle2Eligible = true,
            iconInfo = iconInfo,
            label = "敢买敢送",
            asset = createIconAsset(),
            surface = {
                size = { width = 136, height = 136 },
                layers = {
                    {
                        id = "giftBg",
                        zOrder = 0,
                        asset = {
                            type = "spriteFile",
                            path = Res.Texture.ICON_V2_BG,
                        },
                    },
                },
            },
            newActivityType = "none",
        },
        provider = provider,
        touchCommand = function()
            manager:onTouchIcon(7)
            return true, nil, true
        end,
    }, provider
end

return IconV2Config
