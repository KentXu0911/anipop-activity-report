local LevelAreaUtil = require 'amf.middleware.levelarea.util.LevelAreaUtil'
local UnlockUtil = require 'amf.middleware.levelarea.unlock.util.UnlockUtil'
local TopAreaInfoModel = require 'amf.middleware.levelarea.unlock.model.TopAreaInfoModel'

local TopAreaInfoLogic = class("TopAreaInfoLogic")

function TopAreaInfoLogic:create(levelUnlockConfigParser, levelAreaConfigParser, hideAreaConfigParser, levelAreaManager, unlockManager)
    local instance = TopAreaInfoLogic.new()
    instance:init( levelUnlockConfigParser, levelAreaConfigParser, hideAreaConfigParser, levelAreaManager, unlockManager )
    return instance
end

function TopAreaInfoLogic:init(levelUnlockConfigParser, levelAreaConfigParser, hideAreaConfigParser, levelAreaManager, unlockManager )
    --初始mgr, 并计算数据
    self.levelUnlockConfigParser = levelUnlockConfigParser
    self.levelAreaConfigParser = levelAreaConfigParser
    self.hideAreaConfigParser = hideAreaConfigParser
    self.unlockManager = unlockManager
    self.levelAreaManager = levelAreaManager

    self.topAreaInfoModel = TopAreaInfoModel:create()
end

------------------------------
------------初始刷新时机 user后、解锁
------------------------------

function TopAreaInfoLogic:refreshTopAreaFlagOnUserInit()
    self:refreshMainAreaAndHiddenAreaOpenData()
    self:refreshMaxNormalLevel()
end

function TopAreaInfoLogic:refreshTopAreaMaxNormalLevelOnUnlock()
    self:refreshMaxNormalLevel()
end

------------------------------
------------初始、刷新数据 unlockData hideUnlockData
------------------------------

function TopAreaInfoLogic:refreshMainAreaAndHiddenAreaOpenData()
    self:refreshMainLevelAreaOpenData()
    self:refreshHiddenAreaOpenData()
end

function TopAreaInfoLogic:refreshHiddenAreaOpenData()

    if self.levelUnlockConfigParser == nil then return end

    local hideUnlockData = {}
    local hideUnlockConfig = self.levelUnlockConfigParser:getAreaUnlockInfoOfTopHiddenAreas()
    --隐藏关
    if #hideUnlockConfig > 0 then
        for _, unlockConfigData in ipairs(hideUnlockConfig) do
            local areaIDs = unlockConfigData.areaIDs
            for _, areaID in ipairs(areaIDs) do
                local hideAreaData = self.hideAreaConfigParser:getHiddenAreaByAreaID(areaID)
                if hideAreaData then
                    local data = {}
                    data.id = areaID
                    data.continueLevels = hideAreaData.continueLevels
                    data.hideLevelRange = hideAreaData.hideLevelRange
                    data.checkState = self.unlockManager:getAreaCheckState(areaID)
                    data.startTime = unlockConfigData.startTime
                    data.unlockTime = unlockConfigData.startTimeStamp
                    table.insert(hideUnlockData, data)
                end
            end
        end
    end
    self:setHideUnlockData(hideUnlockData)
    LevelAreaUtil:log("refreshHiddenAreaOpenData_hideunlockData", hideUnlockData)
end

function TopAreaInfoLogic:refreshMainLevelAreaOpenData()

    if self.levelUnlockConfigParser == nil then return end

    local unlockData = {}
    local mainUnlockConfig, topAreaId = self.levelUnlockConfigParser:getMainAreaUnlockInfoOfTopAreas()
    local topLevelId = self.levelAreaManager:getTopLevelId()
    -- 不走unlockManager的getLocalMaxOpenLevel，走我们自己的
    local maxOpenLevel = self:getLocalMaxOpenLevel()
    topLevelId = math.min(topLevelId, maxOpenLevel)
    --本地有有效的主线关倒计时解锁数据 --主线
    if mainUnlockConfig and #mainUnlockConfig > 0 then
        for _, unlockConfigData in ipairs(mainUnlockConfig) do
            local areaIDs = unlockConfigData.areaIDs
            for _, areaID in ipairs(areaIDs) do
                local levelAreaData = self.levelAreaConfigParser:getLevelAreaById(areaID)
                if levelAreaData and levelAreaData.minLevel > topLevelId then
                    local data = {}
                    data.id = areaID
                    data.minLevel = levelAreaData.minLevel
                    data.maxLevel = levelAreaData.maxLevel
                    data.checkState = self.unlockManager:getAreaCheckState(areaID)
                    data.unlockTime = unlockConfigData.startTimeStamp
                    data.minVer = unlockConfigData.minVer
                    table.insert(unlockData, data)  -- unlockData:配有top的条目(登录时最低的未解锁区域集)+之后的一个区域中，比当前玩家topLevel要高的区域
                    if areaID == (topAreaId + 1) then
                        --标记的top区域以上的 只处理一个, 下次开新关的第一个区域
                        data.isNext = true
                        break
                    end
                end
            end
        end
    end
    self:setUnlockData(unlockData)
    LevelAreaUtil:log("refreshMainLevelAreaOpenData_unlockData", unlockData)
end


------------------------------
------------maxNormalLevelByLevelArea 数据
------------------------------
-- 配置了top的情况下返回top条目的maxLevel，否则返回配置中非9999的最大level
function TopAreaInfoLogic:getMaxNormalLevelByLevelArea()
    local maxLevel = self:getMaxNormalLevelByLevelAreaFromModel() or 0
    if maxLevel == 0 then
        maxLevel = self:refreshMaxNormalLevel()
    end
    return maxLevel
end

function TopAreaInfoLogic:refreshMaxNormalLevel()
    local maxLevel = 0
    local topAreaID = self.levelUnlockConfigParser:getLastAreaIDOfTopMainArea()
    if topAreaID then
        local topAreaMeta = self.levelAreaConfigParser:getLevelAreaById(topAreaID)
        if topAreaMeta then
            maxLevel = topAreaMeta.maxLevel
        end
    end

    -- 没有标记为最高区域的区域，选取配置中maxLevel（非9999之外）最大的
    local levelAreaConfig = self.levelAreaConfigParser:getLevelAreaConfig()
    if maxLevel == 0 then
        for k,v in pairs(levelAreaConfig) do
            if v.maxLevel > maxLevel and v.maxLevel < _G.levelUnlockConst.ImpossibleMaxLevel then
                maxLevel = v.maxLevel
            end
        end
    end

    self:setMaxNormalLevelByLevelArea(maxLevel)

    return maxLevel
end

------------------------------
------------使用
------------------------------

function TopAreaInfoLogic:setUnlockData(unlockData)
    self.topAreaInfoModel:setUnlockData(unlockData)
end

function TopAreaInfoLogic:getUnlockData()
    return self.topAreaInfoModel:getUnlockData()
end

function TopAreaInfoLogic:setHideUnlockData(hideUnlockData)
    self.topAreaInfoModel:setHideUnlockData(hideUnlockData)
end

function TopAreaInfoLogic:getHideUnlockData()
    return self.topAreaInfoModel:getHideUnlockData()
end

function TopAreaInfoLogic:setMaxNormalLevelByLevelArea(maxNormalLevelByLevelArea)
    self.topAreaInfoModel:setMaxNormalLevelByLevelArea(maxNormalLevelByLevelArea)
end

function TopAreaInfoLogic:getMaxNormalLevelByLevelAreaFromModel()
    return self.topAreaInfoModel:getMaxNormalLevelByLevelArea()
end

function TopAreaInfoLogic:getUnlockCheckState(areaId)
    return self.topAreaInfoModel:getUnlockCheckState(areaId)
end

function TopAreaInfoLogic:getNextCountdownArea()
    --获取下次开新关倒计时区域id  isNext=true的。
    local topLevelId = self.levelAreaManager:getTopLevelId()
    local topLevelPassed = self.levelAreaManager:hasPassed(topLevelId, UBFLevelSceneType.kMain)
    local unlockData = self:getUnlockData()
    for i,v in ipairs(unlockData) do
        if topLevelPassed and v.isNext == true then
            return v.id
        end
    end
end

function TopAreaInfoLogic:getCurCountdownArea(checkTime)
    --获取当前topLevel的下一个区域 checkTime 为true强校验开启时间，否则下一个开启区域就是。
    local topLevelId = self.levelAreaManager:getTopLevelId()
    local now = TimeKit:timeInSec()
    local unlockData = self:getUnlockData()
    for i, v in ipairs(unlockData) do
        if not v.isNext and topLevelId < v.minLevel and
                v.checkState == _G.levelUnlockConst.OnlineCheckState.NEED then

            if not checkTime or now < tonumber(v.unlockTime) then
                return v.id
            end
        end
    end
end

-- function TopAreaInfoLogic:isCountdownArea(areaId, checkTime)
--     local id = self:getCurCountdownArea(checkTime)
--     return id == areaId
-- end

local unlockTimeCache = {}
function TopAreaInfoLogic:getCountdownEndTime(areaId)
    if not unlockTimeCache[areaId] then
        unlockTimeCache[areaId] = self.topAreaInfoModel:getCountdownEndTime(areaId)
    end
    return unlockTimeCache[areaId]
end

-- function TopAreaInfoLogic:isMaxLevelCountdown(maxLevel)
--     local unlockData = self:getValue("unlockData")
--     for i,v in ipairs(unlockData) do
--         if v.maxLevel == maxLevel and
--                 v.checkState == _G.levelUnlockConst.OnlineCheckState.NEED then
--             return true
--         end
--     end
--     return false
-- end

--考虑到主线关倒计时解锁情况 获得当前可打最高关
--old：如有配置startLevel的区域，返回它之下的第一个区域，否则返回配置了top的区域，再否则，返回配置中的最高关
--  new：在登录时未解锁的最低区域集(top区域集)+1的区域中，找到比玩家当前区域高的下一区域，若它属于top区域集且需联网解锁，
--      返回它之下的第一个区域，否则返回配置了top的区域，再否则，返回配置中的最高关
--      感觉主要是排除一下需要联网解锁的区域，一般来说就是还没解锁的新关区域
function TopAreaInfoLogic:getCanPlayTopLevel()
    local unlockData = self:getUnlockData()
    local topLevelId = self.levelAreaManager:getTopLevelId()
    local curCountdownArea
    for i,v in ipairs(unlockData) do
        if not v.isNext and topLevelId < v.minLevel and
                v.checkState == _G.levelUnlockConst.OnlineCheckState.NEED then
            curCountdownArea = v
            break
        end
    end
    if curCountdownArea then
        return self.levelAreaConfigParser:getLevelAreaById(curCountdownArea.id - 1).maxLevel
    else
        return self:getMaxNormalLevelByLevelArea()
    end
end

function TopAreaInfoLogic:getHideAreaEndTime(areaId)
    return self.topAreaInfoModel:getHideAreaEndTime(areaId)
end

function TopAreaInfoLogic:isOnlineCheckHideArea(areaId)
    return self.topAreaInfoModel:isOnlineCheckHideArea(areaId)
end

function TopAreaInfoLogic:isHideAreaCountdownOver(areaId)
    return self.topAreaInfoModel:isHideAreaCountdownOver(areaId)
end

function TopAreaInfoLogic:isHideAreaCountdownIng(areaId)
    return self.topAreaInfoModel:isHideAreaCountdownIng(areaId)
end

function TopAreaInfoLogic:isOnlineCheckHideAreaLevel(levelId)
    local areaData = self.levelAreaConfigParser:getHiddenAreaByHiddenLevelId(levelId)
    if areaData then
        return self:isOnlineCheckHideArea(areaData.id), areaData.id
    else
        return false
    end
end

--当前可打的应倒计时区域 是否倒计时结束
function TopAreaInfoLogic:isCurCountdownAreaOver()
    local countdownAreaId = self:getCurCountdownArea()
    if countdownAreaId then
        local endTime = self:getCountdownEndTime(countdownAreaId)
        local now = TimeKit:timeInSec()
        local isOver = now >= endTime
        return isOver, countdownAreaId
    end
    return true, nil
end

--获取当前可打最高关
function TopAreaInfoLogic:getLocalTopLevel(needUnlockCheck)
    local isOver, countdownAreaId = self:isCurCountdownAreaOver()
    if not isOver then
        return self.levelAreaConfigParser:getLevelAreaById(countdownAreaId - 1).maxLevel
    end

    if not countdownAreaId or not needUnlockCheck then
        return self:getMaxNormalLevelByLevelArea()
    end

    local checkState = self:getUnlockCheckState(countdownAreaId)
    if checkState and checkState == _G.levelUnlockConst.OnlineCheckState.NEED then
        return self.levelAreaConfigParser:getLevelAreaById(countdownAreaId - 1).maxLevel
    else
        return self:getMaxNormalLevelByLevelArea()
    end
end

--获取满紫数量
function TopAreaInfoLogic:getFullStarInHiddenRegion(excludeUnlock)
    local result = 0
    local branchList = self.hideAreaConfigParser:getHiddenLevelAreaConfig()
    local configTopLevel = self:getLocalTopLevel(true)
    for index = 1, #branchList do
        if branchList[index].isOpened then
            local function doAdd()
                result = result + (branchList[index].endHiddenLevel - branchList[index].startHiddenLevel + 1) * 3
            end

            if excludeUnlock then
                local endTime = self:getHideAreaEndTime(branchList[index].id)
                local isOver
                if endTime then
                   local curTime = TimeKit:timeInSec()
                   isOver = curTime >= endTime
                end
                local endNormalLevel = branchList[index].endNormalLevel
                local isLock = endTime and not isOver
                if not isLock and endNormalLevel <= configTopLevel then
                    doAdd()
                end
            else
                doAdd()
            end
        end
    end
    return result
end

--本地开放的最高关卡（有些平台限制最高关卡）
function TopAreaInfoLogic:getLocalMaxOpenLevel()
    local forceLimitLevelId
    if (EnvUtil:isPrePackage()) then
        forceLimitLevelId = _G.levelUnlockConst.PrePackageLimitLevel
    else
        forceLimitLevelId = _G.levelUnlockConst.ForceLimitLevelId
    end
    local configOpenLevel = self:getLocalTopLevel(false)
    return math.min(forceLimitLevelId, configOpenLevel), forceLimitLevelId < configOpenLevel
end

--获取可以打的最高关
function TopAreaInfoLogic:getUserMaxLevelId()
    local unlockData = self.levelUnlockConfigParser:getAreaUnlockDataOfLastOpenedMainArea()
    if  not unlockData then
        return
    end
    local maxLevelFromMark = 0
    if unlockData and unlockData.areaIDs then
        local maxLevel = 0
        for k , id in pairs( unlockData.areaIDs ) do
            local levelAreaData = self.levelAreaConfigParser:getLevelAreaById(id)
            if levelAreaData then maxLevel = math.max( levelAreaData.maxLevel , maxLevel ) end
        end
        maxLevelFromMark = maxLevel > 0 and maxLevel or 0
    end
    local maxLevelId = self:getCanPlayTopLevel()
    return math.max(maxLevelFromMark, maxLevelId)
end

function TopAreaInfoLogic:getNextLevelAreaByLevelId(levelId)
    local curLevelArea  = self.levelAreaConfigParser:getLevelAreaByLevelId(levelId)
    local nextLevelArea = false

    if curLevelArea then
        local curLevelAreaMaxLevel = tonumber(curLevelArea.maxLevel)
        if curLevelAreaMaxLevel <= self.TopAreaInfoLogic:getMaxNormalLevelByLevelArea() then     --保证当前check的关卡是在当前版本配置允许的最高关之内
            local nextLevelAreaMinLevel = curLevelAreaMaxLevel + 1
            nextLevelArea = self.levelAreaConfigParser:getLevelAreaByLevelId(nextLevelAreaMinLevel)
        end
    end

    return nextLevelArea
end

--是否是倒计时等待开放的区域(发新关区域)
function TopAreaInfoLogic:isNextFridayArea(areaId)
    local cloudId = UnlockUtil:levelIdToCloudId(areaId)
    return self:isNextFridayCloud(cloudId)
end

--是否是倒计时等待开放的云(发新关区域)
function TopAreaInfoLogic:isNextFridayCloud(cloudId)
    local waitingCloud = self:getCurCountdownArea(true)
    return waitingCloud == cloudId
end


return TopAreaInfoLogic