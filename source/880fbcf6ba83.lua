local IconV2Config = {}
local Res = require "amf.feature.localactivity.shopreward.const.Res"

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
        animations = { idle = "idle1" },
    }
end

function IconV2Config.create(module, iconEventCenter)
    local IconConfig = require "amf.feature.mainscene.module.icon.config.IconConfig"
    local IconData = require "amf.feature.giftpackage.module.singleicon.shopreward.IconData"
    local ShopRewardConst = require "amf.feature.localactivity.shopreward.const.ShopRewardConst"
    local ownerIconKey = IconKey.kShopReward
    local info = assert(IconConfig:getInfoByKey(ownerIconKey), "SHOP_REWARD_ICON_INFO_REQUIRED")
    local label = info:getLabelStr() or ""
    local provider = IconData:create(module, label)

    return {
        ownerIconKey = ownerIconKey,
        iconEventCenter = iconEventCenter,
        legacyFactory = function()
            return module:createLegacyIcon(true)
        end,
        metadata = {
            actId = ShopRewardConst.actId,
            iconKey = ownerIconKey,
            iconInfo = info,
            poolType = info:getPoolType(),
            basePriority = info:getPriority(),
            label = label,
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
            newActivityType = "B",
        },
        provider = provider,
        newActivityCycleKeyResolver = function(config, icon)
            return provider:resolveCycleKey({
                config = config,
                icon = icon,
            })
        end,
        isNewActivityTimePermitted = function()
            local manager = module:getManager()
            return manager and manager:isEnabled() == true or false
        end,
        touchCommand = function()
            if module:isIconEnabled() ~= true then
                return false, "SHOP_REWARD_ICON_NOT_AVAILABLE", false
            end
            module:onIconTapped(function()
                module:removeIcon()
            end)
            return true, nil, true
        end,
    }, provider
end

return IconV2Config
