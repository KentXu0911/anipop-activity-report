require 'amf.middleware.levelarea.config.LevelAreaConst'
local LevelAreaUtil = require 'amf.middleware.levelarea.util.LevelAreaUtil'
local LevelUnlockConfigUtil = require 'amf.middleware.levelarea.levelconfig.util.LevelUnlockConfigUtil'

local LevelUnlockConfigParser = class("LevelUnlockConfigParser")

function LevelUnlockConfigParser:init()
    self.levelUnlockConfig = {}
    self.levelUnlockConfigOri = {}
    self:loadConfig()
end
------------------------------
------------配置加载
------------------------------

function LevelUnlockConfigParser:loadConfig()
    self:loadLevelUnlockConfig()
end

function LevelUnlockConfigParser:loadLevelUnlockConfig()
    local result = {}
    MetaConfigUtil:traverseConfigThenRelease("level_unlock_config", function(k, v)
        if k == "configVersion" then
            result[k] = tonumber(v)
        else
            local cfgList = v[1].unlockData
            local dataList = {}
            for i, rawData in ipairs(cfgList) do
                local dataPiece = {}
                for key, val in pairs(rawData) do
                    if key == "id" or key == "minVer" then
                        dataPiece[key] = tonumber(val)
                    elseif key == "startTime" then
                        local startTimeStr = tostring(val)
                        dataPiece[key] = tostring(val)
                        if startTimeStr then
                            dataPiece["startTimeStamp"] = os.time2(parseTime(startTimeStr))
                        end
                    elseif key == "areaIDs" then
                        if type(val) == "number" then
                            dataPiece[key] = {val}
                        else
                            local areaList = LevelUnlockConfigUtil:parseItemList(val)
                            if areaList then
                                table.sort(areaList, function(a,b) return a < b end)
                                dataPiece[key] = areaList
                            end
                        end
                    end
                end
                dataList[i] = dataPiece
            end
            result[k] = dataList
        end
    end)

    self.levelUnlockConfig = result
    self.levelUnlockConfigOri = table.clone(result)
end

function LevelUnlockConfigParser:resetConfig()
    self.levelUnlockConfig = table.clone(self.levelUnlockConfigOri)
end

------------------------------
------------计算isTopArea
------------------------------

function LevelUnlockConfigParser:refreshTopAreaFlagOnUserInit( isOffLine, lastUserTime )

    --在线登录使用当前时间初始化，离线登录使用记录的时间初始化
    local timeSec = 0
    if isOffLine then
        timeSec = lastUserTime or 0
    else
        timeSec = TimeKit:timeInSec()
    end
    self:refreshTopAreaFlag(timeSec)
end

function LevelUnlockConfigParser:refreshTopAreaFlagOnOnlineUnlock()
    local timeSec = TimeKit:timeInSec()
    self:refreshTopAreaFlag(timeSec)
end

function LevelUnlockConfigParser:refreshTopAreaFlag(timeSec)
    --重置配置，重新计算flag
    self:resetConfig()
    self:refreshTopAreaFlagByTime(timeSec)
end

function LevelUnlockConfigParser:refreshTopAreaFlagByTime( timeSec )
    local currTime = timeSec or TimeKit:timeInSec()

    -- 配置已经排好序
    local mainLevelConfig = self:getUnlockConfigListByConfigType(_G.levelUnlockConst.LevelUnlockConfigType.MAIN_LEVEL)
    local hiddenLevelConfig = self:getUnlockConfigListByConfigType(_G.levelUnlockConst.LevelUnlockConfigType.HIDDEN_LEVEL)

    -- for i=#mainLevelConfig-5, #mainLevelConfig do
    --     LevelAreaUtil:log("LevelUnlockConfigParser mainLevelConfig 1111", i, mainLevelConfig[i])
    -- end

    if mainLevelConfig then
        local param = {
            currTime = currTime,
            targetConfig = mainLevelConfig,
            isMainLevel = true,
        }
        self:setNextPeriodAreaAsTop(param)
    end
    if hiddenLevelConfig then
        local param = {
            currTime = currTime,
            targetConfig = hiddenLevelConfig,
            isMainLevel = false,
        }
        self:setNextPeriodAreaAsTop(param)
    end

    -- for i=#mainLevelConfig-5, #mainLevelConfig do
    --     LevelAreaUtil:log("LevelUnlockConfigParser mainLevelConfig 22222", i, mainLevelConfig[i])
    -- end
end

-- 主线 & 隐藏关，当前时间段的下一周为top区域
-- 原因：周五开新关前，会更新一版将top移到再下周的配置，本次重构将其之间节点提前，一开新关就移动top到下周
-- 详情可以咨询庄sir，每周发level_unlock_config_config的时候，最后一条是保底配置，倒数第二条是预览配置，真正的配置是从倒数第三条开始
function LevelUnlockConfigParser:setNextPeriodAreaAsTop(param)
    local currTime = param.currTime
    local targetConfig = param.targetConfig
    local isMainLevel = param.isMainLevel

    local start = #targetConfig
    local isFound = false

    if isMainLevel then
        -- top不能是最后那条9999保底，也不能是倒数第二条是待发布仅预览
        start = start + _G.levelUnlockConst.lastSafeConfigIndex
        local data = targetConfig[start]
        if data.startTimeStamp < currTime then
            -- 最高合法配置的时间就已经过期，说明没发新关、或者本地没有拉取到新关配置，强行认为最高配置就是最新
            data.lastOpenedArea = true
            data.isTopArea = true
            isFound = true
        end
    end

    if not isFound then
        for i = start, 2, -1 do
            local data = targetConfig[i]
            local formerData = targetConfig[i - 1]
            if data and formerData then
                --增加i==2, 兼容时间被调到很久之前，找不到配置的问题
                if (data.startTimeStamp > currTime) and (formerData.startTimeStamp <= currTime) or (i == 2) then
                    data.isTopArea = true
                    formerData.lastOpenedArea = true
                    break
                end
            end
        end
    end
end


------------------------------
------------使用
------------------------------

function LevelUnlockConfigParser:getLevelUnlockConfig()
    return self.levelUnlockConfig
end

-- 配置版本
function LevelUnlockConfigParser:getAreaUnlockConfigVersion()
    if self.levelUnlockConfig and self.levelUnlockConfig.configVersion then
        return self.levelUnlockConfig.configVersion
    end
    return 0
end

--根据配置类型获取解锁配置列表
--fourStarAdjustUnlock 应该没地方用了，4星跟主线一样开。
function LevelUnlockConfigParser:getUnlockConfigListByConfigType(configType)
    if self.levelUnlockConfig and configType then
        if configType == _G.levelUnlockConst.LevelUnlockConfigType.MAIN_LEVEL then
            return self.levelUnlockConfig.mainLevelUnlock
        elseif configType == _G.levelUnlockConst.LevelUnlockConfigType.HIDDEN_LEVEL then
            return self.levelUnlockConfig.hiddenLevelUnlock
        elseif configType == _G.levelUnlockConst.LevelUnlockConfigType.FOUR_STAR_ADJUST_LEVEL then
            return self.levelUnlockConfig.fourStarAdjustUnlock
        end
    end
    return nil
end

-- 当前最低未开放区域 + 之后的一个区域（不包含9999条目）
function LevelUnlockConfigParser:getMainAreaUnlockInfoOfTopAreas()
    local infoTable = {}
    local topAreaId = nil
    local mainLevelConfig = self:getUnlockConfigListByConfigType(_G.levelUnlockConst.LevelUnlockConfigType.MAIN_LEVEL)
    if mainLevelConfig then
        for i = #mainLevelConfig, 1, -1 do
            local v = mainLevelConfig[i]
            if v and v.isTopArea then
                table.insert(infoTable, v)
                table.insert(infoTable, mainLevelConfig[i+1])
                local topAreaIDs = v.areaIDs
                if topAreaIDs and #topAreaIDs > 0 then
                    topAreaId = topAreaIDs[#topAreaIDs]
                end
                break
            end
        end
    end

    table.sort(infoTable, function(a,b) return a.id < b.id end)

    return infoTable, topAreaId
end

function LevelUnlockConfigParser:getAreaConfigByAreaId(areaId)
    local unlockConfig = self:getUnlockConfigListByConfigType(_G.levelUnlockConst.LevelUnlockConfigType.MAIN_LEVEL)
    for i = #unlockConfig, 1, -1 do
        local v = unlockConfig[i]
        if v and v.areaIDs and table.exist(v.areaIDs, areaId) then
            return v
        end
    end
end

-- 获取主线关最低未开放区域集的ID信息
function LevelUnlockConfigParser:getAreaUnlockDataOfTopMainArea()
    local mainLevelConfig = self:getUnlockConfigListByConfigType(_G.levelUnlockConst.LevelUnlockConfigType.MAIN_LEVEL)
    if mainLevelConfig then
        for i = #mainLevelConfig, 1, -1 do
            local v = mainLevelConfig[i]
            if v and v.isTopArea == true then
                return v
            end
        end
    end
    return nil
end

-- 获取主线关当前已可解锁的顶部区  
function LevelUnlockConfigParser:getTopUnlockArea()
    return self:getAreaUnlockDataOfLastOpenedMainArea()
end

-- 获取主线关最高已开放区域的ID列表
-- lastOpenedArea 这个可以是上周的，也可以是跟isTopArea一个。
function LevelUnlockConfigParser:getAreaUnlockDataOfLastOpenedMainArea()
    local mainLevelConfig = self:getUnlockConfigListByConfigType(_G.levelUnlockConst.LevelUnlockConfigType.MAIN_LEVEL)
    if mainLevelConfig then
        for i = #mainLevelConfig, 1, -1 do
            local v = mainLevelConfig[i]
            if v and v.lastOpenedArea == true then
                return v
            end
        end
    end
    return nil
end

-- 根据配置id，获取主线的解锁配置
function LevelUnlockConfigParser:getAreaUnlockDataOnMainAreaById(configID)
    local mainLevelConfig = self:getUnlockConfigListByConfigType(_G.levelUnlockConst.LevelUnlockConfigType.MAIN_LEVEL)
    if mainLevelConfig then
        --先按有序找，找不到再遍历
        local configInfo = mainLevelConfig[configID]
        if configInfo and configInfo.id == configID then
            return configInfo
        end

        --遍历查询
        for i = #mainLevelConfig, 1, -1 do
            local v = mainLevelConfig[i]
            if v and v.id == configID then
                return v
            end
        end
    end
    return nil
end

------
--根据配置类型和数据ID获取解锁数据
function LevelUnlockConfigParser:getUnlockDataByDataID(targetUnlockConfig, configID)
    -- 一般来说应该是相等的，为了提高效率，先检查一波
    if targetUnlockConfig[configID] and (targetUnlockConfig[configID].id == tonumber(configID)) then
        return targetUnlockConfig[configID]
    end
    -- 未命中后的兜底
    for _, unlockData in pairs(targetUnlockConfig) do
        if unlockData.id == configID then
            return unlockData
        end
    end
    return nil
end

function LevelUnlockConfigParser:getMinAreaIDOfTargetConfig( configID, configType )
    if configID then
        local unlockConfigList = self:getUnlockConfigListByConfigType(configType)
        if unlockConfigList then
            local targetConfig = self:getUnlockDataByDataID(unlockConfigList, configID)
            if targetConfig and targetConfig.areaIDs and #targetConfig.areaIDs > 0 then
                return targetConfig.areaIDs[1] -- 是排好序的
            end
        end
    end
    -- 找不到
    return -1
end

--和targetAreaId 同时开放的一批区域中，最低的区域
--例如targetAreaId是某一次新发45关时开放的，涉及三个区域，40101，40102，40103，则返回40101
function LevelUnlockConfigParser:getMinAreaIdInAreaBound( areaId )
    local mainLevelConfig = self:getUnlockConfigListByConfigType(_G.levelUnlockConst.LevelUnlockConfigType.MAIN_LEVEL)
    if mainLevelConfig then
        for i = #mainLevelConfig, 1, -1 do
            local areaIDs = mainLevelConfig[i].areaIDs
            for _, areaID in ipairs(areaIDs) do
                if areaID == areaId then
                    return areaIDs[1], #areaIDs
                end
            end
        end
    end
    return areaId, 1
end

function LevelUnlockConfigParser:getAreaUnlockConfigByAreaId( areaId )
    local mainLevelConfig = self:getUnlockConfigListByConfigType(_G.levelUnlockConst.LevelUnlockConfigType.MAIN_LEVEL)
    if mainLevelConfig then
        for i = #mainLevelConfig, 1, -1 do
            local v = mainLevelConfig[i]
            if v and v.areaIDs and table.exist(v.areaIDs, areaId) then
                return v
            end
        end
    end
    return nil
end

function LevelUnlockConfigParser:getAreaOpenTime(areaId)
    local areaInfo = self:getAreaUnlockConfigByAreaId(areaId)
    if areaInfo then
        return areaInfo.startTimeStamp
    end
    return nil
end

-- 获得当前最低未开放隐藏区域
-- 可能是老旧的版本代码，以前隐藏关会上下一起开。
function LevelUnlockConfigParser:getAreaUnlockInfoOfTopHiddenAreas()
    local infoTable = {}
    local hiddenLevelConfig = self:getUnlockConfigListByConfigType(_G.levelUnlockConst.LevelUnlockConfigType.HIDDEN_LEVEL)
    if hiddenLevelConfig then
        for i = #hiddenLevelConfig, 1, -1 do
            local v = hiddenLevelConfig[i]
            if v and (v.isTopArea == true) then
                table.insert(infoTable, v)
            end
        end
        table.sort(infoTable, function(a,b) return a.id < b.id end)
    end
    return infoTable
end

-- 取主线关最低未开放区域集的最高区域ID（当有多个区域时，返回ID最大的）
function LevelUnlockConfigParser:getLastAreaIDOfTopMainArea()
    local topAreaUnlockData = self:getAreaUnlockDataOfTopMainArea()
    if topAreaUnlockData then
        local topAreaIDs = topAreaUnlockData.areaIDs
        if topAreaIDs and #topAreaIDs > 0 then
            -- 是排好序的
            return topAreaIDs[#topAreaIDs]
        end
    end
    return nil
end

--获取头部区域关卡数量（根据开放的区域数计算）
function LevelUnlockConfigParser:getTopAreaLevelCount()
    local topAreaUnlockData = self:getTopUnlockArea()
    if topAreaUnlockData then
        local topAreaIDs = topAreaUnlockData.areaIDs
        local topOpenAreaCount = #topAreaIDs
        return topOpenAreaCount*15
    end
    return 0
end

function LevelUnlockConfigParser:getAreaUnlockTime(areaId)
    local areaConfig = self:getAreaConfigByAreaId(areaId)
    if not areaConfig then return nil end 
    return areaConfig.startTimeStamp or nil
end

return LevelUnlockConfigParser