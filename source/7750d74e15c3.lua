local INextLevelCalc = require "amf.feature.recommendlevel.recommendstrategy.abstract.INextLevelCalc"
local RecommendLevelUtil = require "amf.feature.recommendlevel.RecommendLevelUtil"

local DefaultNextLevelCalc = class("DefaultNextLevelCalc").implement(INextLevelCalc)

function DefaultNextLevelCalc:getNextMainLevel(curLevelId, params)
    local nextLevelScene = UBFLevelSceneType.kMain
    -- 本次是刷分
    if params.levelFarmingType == _G.UBFLevelFarmingType.FARM_SCORE then
        local _userStateManager = _G.amfBean("UserStateManager")
        local userState = _userStateManager:getUserSegmentState()
        local nextLevelId
        local nextLevelType = _G.RecommendLevelConst.NextLevelType.FARM_SCORE_LEVEL
        if userState > _G.UserStateConst.UserSegmentState.FMC then
            if curLevelId + 1 <= _G.getTopLevelId() then
                nextLevelId = curLevelId + 1
            end
        end
        return nextLevelId, nextLevelType, nextLevelScene
    end

    -- 本次是补星
    if params.levelFarmingType == _G.UBFLevelFarmingType.FARM_STAR then
        local unlockManager = _G.amfBean("UnlockManager")
        -- 打前15关且能解锁
        if _G.getTopLevelId() - curLevelId < 15 and unlockManager:canUnlockArea() then
            return _G.getTopPassedLevelId() + 1, _G.RecommendLevelConst.NextLevelType.TOP_LEVEL, nextLevelScene
        else
            local nextLevelType = _G.RecommendLevelConst.NextLevelType.FARM_STAR_LEVEL
            local nextLevelId = RecommendLevelUtil:getMainNotFullYellowLevel(curLevelId + 1)
            if not nextLevelId then nextLevelId = RecommendLevelUtil:getMainNotFullYellowLevel(1, curLevelId - 1) end
            if not nextLevelId then nextLevelId = RecommendLevelUtil:getMainNotFullColorfulLevel(curLevelId + 1) end
            if not nextLevelId then nextLevelId = RecommendLevelUtil:getMainNotFullColorfulLevel(1, curLevelId - 1) end
            return nextLevelId, nextLevelType, nextLevelScene
        end
    end

    -- 正常打关
    local nextLevelId = _G.getTopLevelId()
    local nextLevelType = _G.RecommendLevelConst.NextLevelType.TOP_LEVEL
    if nextLevelId == curLevelId then
        nextLevelId = nextLevelId + 1
    end
    return nextLevelId, nextLevelType, nextLevelScene
end

function DefaultNextLevelCalc:getNextHiddenLevel(curLevelId, params)
    local nextLevelScene = UBFLevelSceneType.kHide
    local nextLevelType = _G.RecommendLevelConst.NextLevelType.HIDDEN_LEVEL
    -- 刷分没有下一关
    if params.levelFarmingType == _G.UBFLevelFarmingType.FARM_SCORE then
        return nil, nextLevelType, nextLevelScene
    end

    -- 补星推荐补星
    if params.levelFarmingType == _G.UBFLevelFarmingType.FARM_STAR then
        local nextLevelId = RecommendLevelUtil:getHiddenFarmLevel(curLevelId + 1)
        if not nextLevelId then nextLevelId = RecommendLevelUtil:getHiddenFarmLevel(1, curLevelId - 1) end
        return nextLevelId, nextLevelType, nextLevelScene
    end

    local nextLevelId = RecommendLevelUtil:getHiddenNotPassLevel(curLevelId + 1)
    if not nextLevelId then nextLevelId = RecommendLevelUtil:getHiddenNotPassLevel(1, curLevelId - 1) end
    return nextLevelId, nextLevelType, nextLevelScene
end

return DefaultNextLevelCalc
