
local LevelAreaConfigParser = class("LevelAreaConfigParser")

function LevelAreaConfigParser:init()
    self.levelAreaConfig = {}
    self:loadConfig()
end

------------------------------
------------配置加载
------------------------------

function LevelAreaConfigParser:loadConfig()
    self:loadConfigForMainLevel()
end

--主线关配置加载
function LevelAreaConfigParser:loadConfigForMainLevel()
    local result = {}
    local localConfigMaxLevel = 0
    MetaConfigUtil:traverseConfigThenRelease("level_area", function(_, value)
        local singleConfig = {
            id = 0,
            maxLevel = 0,
            minLevel = 0,
            star = 0,
            unlockTaskLevelId = nil,
            starList = {},
        }
        for singleConfigKey, singleConfigValue in pairs(value) do
            if singleConfigKey == "starAreaABTestStr" then
                for i,v2 in pairs(string.split(singleConfigValue,",")) do
                    singleConfig.starList[i] = tonumber(v2)
                end
            elseif type(singleConfigKey) == "string" then
                singleConfig[singleConfigKey] = tonumber(singleConfigValue)
            end
        end

        if singleConfig.maxLevel > localConfigMaxLevel and singleConfig.maxLevel < _G.levelUnlockConst.ImpossibleMaxLevel then
            localConfigMaxLevel = singleConfig.maxLevel
        end

        result[tonumber(singleConfig.id)] = singleConfig
    end)
    self.localConfigMaxLevel = localConfigMaxLevel
    self.levelAreaConfig = result
end


------------------------------
----------使用
------------------------------

function LevelAreaConfigParser:getLevelAreaConfigMaxLevel()
    return self.localConfigMaxLevel
end

function LevelAreaConfigParser:getLevelAreaConfig()
    return self.levelAreaConfig
end

function LevelAreaConfigParser:getLevelAreaById(areaId)
    return self.levelAreaConfig[areaId]
end

function LevelAreaConfigParser:getAreaIDByLevelID(levelId)
    for k,v in pairs(self.levelAreaConfig) do
        if tonumber(v.minLevel) <= levelId and
                levelId <= tonumber(v.maxLevel) then
            return v.id
        end
    end
    return nil
end

function LevelAreaConfigParser:getLevelAreaByLevelId(levelId)
    for k,v in pairs(self.levelAreaConfig) do
        if tonumber(v.minLevel) <= levelId and
                levelId <= tonumber(v.maxLevel) then
            return v
        end
    end
    return nil
end

function LevelAreaConfigParser:isMinLevelAreaId(levelId)
    for i,v in pairs(self.levelAreaConfig) do
        if v.minLevel == levelId then return true end
    end
    return false
end

function LevelAreaConfigParser:isMaxLevelAreaId(levelId)
    for i,v in pairs(self.levelAreaConfig) do
        if v.maxLevel == levelId then return true end
    end
    return false
end

--解锁区域所需要的星星数
function LevelAreaConfigParser:getNeededStar( cloudId )

    local maintenanceName = 'level_area2026'
    local bOpenTest = MaintenanceManager:getInstance():isEnabledInGroup(maintenanceName, "G4") 

    for _, v in pairs(self.levelAreaConfig) do
        if tonumber(v.id) == cloudId then
            local baseStar = tonumber(v.starArea)
            local unlockStar = baseStar
            if bOpenTest then
                if v.starList[5] then
                    unlockStar = tonumber(v.starList[5])
                end
            end
            
            return unlockStar
        end
    end
    return 38
end

return LevelAreaConfigParser