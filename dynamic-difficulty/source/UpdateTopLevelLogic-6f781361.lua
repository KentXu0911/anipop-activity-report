local UpdateTopLevelLogic = class("UpdateTopLevelLogic")

function UpdateTopLevelLogic:execute(passLevelContext)
    local levelId = passLevelContext.levelId
    local levelScene = passLevelContext.levelScene
    local newStar = passLevelContext.star
    local logicalWin = passLevelContext.logicalWin
    local logicalFail = passLevelContext.logicalFail
    local isJumpLevel = passLevelContext.isJumpLevel
    local isBeHelped = passLevelContext.isBeHelped

    local levelAreaManager = _G.amfBean("LevelAreaManager")
    local topLevelId = levelAreaManager:getTopLevelId()
    
    if levelId == topLevelId and UBFLevelSceneFunc:isMainLevel(levelScene) then
        -- 代打跳关也算胜利
        if newStar > 0 or isJumpLevel or isBeHelped then
            -- 胜利
            levelAreaManager:setTopLevelFailCount(0)
            levelAreaManager:setTopLevelLogicalFailCount(0)
            UserTagManager:onTopLevelChanged()
            
            if levelAreaManager:isTopNoPassLevel(levelId) then
                levelAreaManager:addTopLevelWinCount(1)
                if logicalWin then
                    levelAreaManager:addTopLevelLogicalWinCount(1)
                else
                    levelAreaManager:setTopLevelLogicalWinCount(0)
                end
            end

            local lastScore = levelAreaManager:getUserScore(levelId, levelScene)
            if not lastScore or lastScore.star <= 0 then
                --区域最后一关交给区域解锁去更新topLevelId
                if levelId % 15 ~= 0 then
                    levelAreaManager:setTopLevelId(topLevelId + 1)
                    levelAreaManager:updateLastTopLevelUpdateTime()
                end
            end
        else
            -- 失败
            if levelAreaManager:isTopNoPassLevel(levelId) then
                levelAreaManager:setTopLevelWinCount(0)
                levelAreaManager:setTopLevelLogicalWinCount(0)
            end

            levelAreaManager:setTopLevelContinueWinCount(0)

            -- 只加逻辑失败，是因为普通失败已经在进关时加过了
            if logicalFail then
                levelAreaManager:addTopLevelLogicalFailCount()
            end
        end
    end
end

return UpdateTopLevelLogic