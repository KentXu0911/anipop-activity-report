local UnlockConfigCheck = class("UnlockConfigCheck")

function UnlockConfigCheck:create( mainAreaConfigParser, hideAreaConfigParser, levelUnlockConfigParser, topAreaInfoLogic )
	local instance = UnlockConfigCheck.new()
	instance:init( mainAreaConfigParser, hideAreaConfigParser, levelUnlockConfigParser, topAreaInfoLogic )
	return instance
end

function UnlockConfigCheck:init( mainAreaConfigParser, hideAreaConfigParser, levelUnlockConfigParser, topAreaInfoLogic )
	self.mainAreaConfigParser = mainAreaConfigParser
    self.hideAreaConfigParser = hideAreaConfigParser
	self.levelUnlockConfigParser = levelUnlockConfigParser
	self.topAreaInfoLogic = topAreaInfoLogic
end

--上次发新关时间
function UnlockConfigCheck:getLastOpenNewLevelTime()
    local curMaxNormalLevel = self.topAreaInfoLogic:getLocalTopLevel(false)
    local lastOpenAreaId = math.floor((curMaxNormalLevel-1)/15) + 40000 + 1
    return self.levelUnlockConfigParser:getAreaOpenTime(lastOpenAreaId), lastOpenAreaId
end

--下次发新关时间
function UnlockConfigCheck:getNextOpenNewLevelTime()
    local curMaxNormalLevel = self.topAreaInfoLogic:getLocalTopLevel(false)
    local waitingOpenAreaId = math.floor((curMaxNormalLevel+1)/15) + 40000 + 1
    return self.levelUnlockConfigParser:getAreaOpenTime(waitingOpenAreaId), waitingOpenAreaId
end

--获取当前开启的区域数
function UnlockConfigCheck:getLastOpenNewAreaNum() 
    local newLevelOpenTime, countDownAreaId = self:getLastOpenNewLevelTime()
    local _, areaNum = self.levelUnlockConfigParser:getMinAreaIdInAreaBound(countDownAreaId) --上次发的新关信息
    return areaNum
end

--获取即将开启的区域数
function UnlockConfigCheck:getNextOpenNewAreaNum() 
    local newLevelOpenTime, countDownAreaId = self:getNextOpenNewLevelTime()
    local _, areaNum = self.levelUnlockConfigParser:getMinAreaIdInAreaBound(countDownAreaId) --上次发的新关信息
    return areaNum
end

function UnlockConfigCheck:isInNewLevelTime(deltaTime)
    local curMaxNormalLevel = self.topAreaInfoLogic:getLocalTopLevel(false)
    local areaId = self.mainAreaConfigParser:getAreaIDByLevelID(curMaxNormalLevel)
    if not areaId then return false end
    local areaOpenTime = self.levelUnlockConfigParser:getAreaOpenTime(areaId)
    if not areaOpenTime then return false end
    if not deltaTime then
        deltaTime = 14400 -- 4 * 60 * 60
    end
    local now = TimeKit:timeInSec()
    if now <= areaOpenTime + deltaTime and now >= areaOpenTime then
        return true
    end
    return false
end

function UnlockConfigCheck:isTopNewMainLevel(levelId)
    local curMaxNormalLevel = self.topAreaInfoLogic:getLocalTopLevel(false)
    local maxLevelAreaId = self.mainAreaConfigParser:getAreaIDByLevelID(curMaxNormalLevel)
    local maxAreaConfig = self.levelUnlockConfigParser:getAreaUnlockConfigByAreaId(maxLevelAreaId)
    local nowAreaId = self.mainAreaConfigParser:getAreaIDByLevelID(levelId)
    if maxAreaConfig.areaIDs and table.includes(maxAreaConfig.areaIDs, nowAreaId) then
        return true
    end
    return false
end

function UnlockConfigCheck:isTopNewMainOrHideLevel(levelId, levelScene)
    local curMaxNormalLevel = self.topAreaInfoLogic:getLocalTopLevel(false)
    local maxLevelAreaId = self.mainAreaConfigParser:getAreaIDByLevelID(curMaxNormalLevel)
    local maxAreaConfig = self.levelUnlockConfigParser:getAreaUnlockConfigByAreaId(maxLevelAreaId)
    if not maxAreaConfig or not maxAreaConfig.areaIDs then return end

    if UBFLevelSceneFunc:isMainLevel(levelScene) then
        local nowAreaId = self.mainAreaConfigParser:getAreaIDByLevelID(levelId)
        if table.includes(maxAreaConfig.areaIDs, nowAreaId) then
            return true
        end
    elseif UBFLevelSceneFunc:isHideLevel(levelScene) then
        local hideAreaConfig = self.hideAreaConfigParser:getHiddenAreaByHiddenLevelId(levelId)
        for _, areaId in ipairs(maxAreaConfig.areaIDs) do
            local levelAreaData = self.mainAreaConfigParser:getLevelAreaById(areaId)
            if levelAreaData then
                if hideAreaConfig then
                    if hideAreaConfig.startNormalLevel == levelAreaData.minLevel then
                        return true
                    end
                else
                    if EnvUtil:isDevelopMode() then
                        CommonTip:showTip('hide_area_config 缺失配置 levelId=', levelId)
                    end
                end
            end
        end
    end
    return false
end


return UnlockConfigCheck