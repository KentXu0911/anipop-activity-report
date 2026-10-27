---@class EnergyActV2ViewUtil
local ViewUtil = class("EnergyActV2ViewUtil")

--- 奖品飞行
function ViewUtil.rewardFly(startNode, rewards)
    local RewardFlyHelper = require 'amf.feature.localactivity.processgiftautopopup.RewardFlyHelper'
    local startWorldPos = startNode:getPositionInWorldSpace()
    RewardFlyHelper:rewardFlyFunc(false, rewards[1], startWorldPos)
end

return ViewUtil