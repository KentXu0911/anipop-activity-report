local ActSentPlug =
    require "amf.middleware.activitylinkage.ability.sendextraprop.plug.ActSentPlug"
local Const =
    require "amf.feature.localactivity.layeredtilematch.const.Const"
local ActivityFakeIconFactory =
    require "amf.feature.mainscene.module.icon.util.ActivityFakeIconFactory"

local LayeredTileMatchSentPlug =
    class("LayeredTileMatchSentPlug", ActSentPlug)

function LayeredTileMatchSentPlug:initRewardInfo()
    self.rewardInfo = {
        [Const.ItemId.CHALLENGE_TOKEN] = {
            actKey = self.actKey,
            flyFunc = function(
                reward,
                startWorldPos,
                bubbleScale,
                innerFlyEndCall
            )
                return self:flyCollection(
                    reward,
                    startWorldPos,
                    bubbleScale,
                    innerFlyEndCall
                )
            end,
        },
    }
end

function LayeredTileMatchSentPlug:flyCollection(
    reward,
    startWorldPos,
    bubbleScale,
    innerFlyEndCall
)
    if not innerFlyEndCall
        and type(bubbleScale) == "function" then
        innerFlyEndCall = bubbleScale
        bubbleScale = nil
    end
    if type(innerFlyEndCall) == "number" then
        innerFlyEndCall = nil
    end

    local scene = Director:sharedDirector():getRunningScene()
    if scene and scene:is(UBFGamePlayScene) then
        safeRunCall(innerFlyEndCall)
        return
    end

    local actIcon = self:callHost("callActFunc", "getActIcon")
    if not startWorldPos or not isSafeCocosObj(actIcon) then
        safeRunCall(innerFlyEndCall)
        return
    end

    local function createFakeIcon()
        return ActivityFakeIconFactory:create(actIcon)
    end

    local function iconCreator()
        return GameItemCreator:getPropIcon(reward)
    end

    local RewardFlyHelper =
        require "amf.feature.localactivity.processgiftautopopup.RewardFlyHelper"
    RewardFlyHelper:rewardFlyFunc(
        true,
        reward,
        startWorldPos,
        actIcon:getPositionInWorldSpace(),
        iconCreator,
        innerFlyEndCall,
        CCSizeMake(126, 126),
        createFakeIcon,
        0.7,
        nil,
        nil,
        nil,
        {
            finishCallbackStartDelay = 0.4,
        }
    )
end

function LayeredTileMatchSentPlug:isOpen()
    return self:callHost("isEnabled")
        and self:callHost("isInMainTime")
end

function LayeredTileMatchSentPlug:addReward(reward)
    -- self:callHost("addActItem", reward)
end

return LayeredTileMatchSentPlug
