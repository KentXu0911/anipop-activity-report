local IconV2Config = {}
local Res = require "amf.feature.localactivity.musicmaster.config.Res"

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

function IconV2Config.getPreloadFiles()
    return { createIconAsset().path }
end

local function isNetworkAvailable()
    local networkStatusManager = _G.amfBean and _G.amfBean("NetworkStatusManager")
    if not networkStatusManager or type(networkStatusManager.getNetworkStatus) ~= "function" then
        return true
    end
    local noNetwork = _G.NetworkConst
        and _G.NetworkConst.NetworkStatusDes
        and _G.NetworkConst.NetworkStatusDes.NONETWORK
    if noNetwork == nil then
        return true
    end
    return networkStatusManager:getNetworkStatus() ~= noNetwork
end

function IconV2Config.create(manager, iconEventCenter)
    local IconConfig = require "amf.feature.mainscene.module.icon.config.IconConfig"
    local IconData = require "amf.feature.localactivity.musicmaster.icon.IconData"
    local ownerIconKey = IconKey.kMusicMasterIcon
    local info = assert(IconConfig:getInfoByKey(ownerIconKey), "MUSIC_MASTER_ICON_INFO_REQUIRED")
    local provider = IconData:create(manager)

    return {
        ownerIconKey = ownerIconKey,
        iconEventCenter = iconEventCenter,
        legacyFactory = function()
            return manager.musicMasterIconMudule:createLegacyIcon()
        end,
        metadata = {
            actId = manager:getConst().ACT_ID,
            iconKey = ownerIconKey,
            iconInfo = info,
            poolType = info:getPoolType(),
            basePriority = info:getPriority(),
            label = manager:getConst().ACT_CH_NAME,
            asset = createIconAsset(),
            newActivityType = "B",
            numericRankStyle = {
                color = { r = 255, g = 107, b = 208 },
                outlineColor = { r = 169, g = 45, b = 203 },
            },
        },
        provider = provider,
        newActivityCycleKeyResolver = function(config, icon)
            return provider:resolveCycleKey({
                config = config,
                icon = icon,
            })
        end,
        isNewActivityTimePermitted = function()
            return manager:isEnabled()
        end,
        touchCommand = function()
            if not manager:isEnabled2() then
                return false, "MUSIC_MASTER_ICON_NOT_AVAILABLE", false
            end
            if not isNetworkAvailable() then
                CommonTip:showTip("该功能需要联网，请检查您的网络连接状态。")
                return false, "MUSIC_MASTER_ICON_NETWORK_UNAVAILABLE", false
            end
            if manager:getData():isInMainTime() then
                manager:openActivity(false, function()
                    manager.musicMasterIconMudule:updateIcon("panel_close")
                end, true)
                return true, nil, true
            end
            if manager:getData():isInRewardTime() then
                manager:getAwardTimeReward()
                return true, nil, true
            end
            return false, "MUSIC_MASTER_ICON_TIME_INVALID", false
        end,
    }, provider
end

return IconV2Config
