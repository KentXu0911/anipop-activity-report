_G.UBFLevelIdUtil = {}

-- _G.UBFLevelSceneType = {
--     kDefault = "MAIN",            --同kMain  
--     kMain = "MAIN",               --主线大藤蔓
--     kHide = "HIDE",               --精英关
--     kRace2020 = "WEEK_MATCH_2020", --2020赛季关
--     kLib = "RANDOM_CHALLENGE_2023", --满星关卡库 后端要用，暂时不改了
--     kFullLevelLibrary = "RANDOM_CHALLENGE_2023",--这个也是满星关卡库，兼容旧的
--     kAnniversary11th = "ANNIVERSAY_2025_BIG_MAP", --11周年大地图
-- }
-- 详细枚举请看 ubf.UBFPlay.utils.UBFLevelScene.lua
require "ubf.UBFPlay.utils.UBFLevelSceneEnum"


--是否为副本活动关
local ActLevelSceneType = {
    [UBFLevelSceneType.kAnniversary11th] = true,
    [UBFLevelSceneType.kMatchFestival2025] = true,
    [UBFLevelSceneType.kSpringFestival2026] = true,
    [UBFLevelSceneType.kDailyLevelGameplay] = true,
    [UBFLevelSceneType.kCustomMatch] = true,
}

_G.LevelScene = _G.UBFLevelSceneType

UBFLevelSceneFunc = {}
LevelSceneFunc = UBFLevelSceneFunc

function UBFLevelSceneFunc:isMainLevel(levelScene)
    return not levelScene or levelScene == UBFLevelSceneType.kMain
end

function UBFLevelSceneFunc:isHideLevel(levelScene)
    return levelScene == UBFLevelSceneType.kHide
end

function UBFLevelSceneFunc:isMainOrHiddenLevel(levelScene)
    return UBFLevelSceneFunc:isMainLevel(levelScene) or UBFLevelSceneFunc:isHideLevel(levelScene)
end

function UBFLevelSceneFunc:isFullLevelLib(levelScene)
    return levelScene == UBFLevelSceneType.kFullLevelLibrary
end

function UBFLevelSceneFunc:isWeeklyRace(levelScene)
    return levelScene == UBFLevelSceneType.kRace2020
end

function UBFLevelSceneFunc:isActLevelScene(levelScene)
    return ActLevelSceneType[levelScene]
end

--主动放弃时是否需要强制发送oplog
function UBFLevelSceneFunc:isPassLevelGiveUpForceSendOpLog(levelScene)
    local forceSendOpLogSceneType = {
        [UBFLevelSceneType.kAnniversary11th] = true,
        [UBFLevelSceneType.kMatchFestival2025] = true,
        [UBFLevelSceneType.kSpringFestival2026] = true,
        [UBFLevelSceneType.kDailyLevelGameplay] = true,
    }
    return forceSendOpLogSceneType[levelScene]
end

--[[
    创建 levelkey
    levelScene, levelExp, levelGroup，均可以缺省
    字符串会自动处理缺省，按尽可能 短 的规则创建
        - 以下效果等效
        - 2986:main:default:default
        - 2986:main:default:default
        - 2986:main
        - 2986
]]
local _tmpLevelKeyList = {};
function UBFLevelIdUtil:createLevelKey(levelId, levelScene, levelExp, levelGroup)
    local _levelScene = levelScene
    local _levelExp = levelExp
    local _levelGroup = levelGroup
    
    if not levelExp then
        _levelExp = "default"
        _levelGroup = "default"
    end

    if not levelGroup then
        _levelGroup = "default"
    end

    if not levelScene then
        _levelScene = UBFLevelSceneType.kMain
    end

    for k, v in pairs(_tmpLevelKeyList) do _tmpLevelKeyList[k] = nil end

    _tmpLevelKeyList[1] = tostring(levelId)
    _tmpLevelKeyList[2] = _levelScene
    _tmpLevelKeyList[3] = _levelExp
    _tmpLevelKeyList[4] = _levelGroup
    
    if _levelGroup == "default" then 
        _tmpLevelKeyList[4] = nil
        if _levelExp == "default" then
            _tmpLevelKeyList[3] = nil
            if _levelScene == UBFLevelSceneType.kMain then
                _tmpLevelKeyList[2] = nil
            end
        else
            if __WIN32 then 
                UBFThrow("levelExp怎么回事？要是default都应该是default！")
            end
        end
    end

    return table.concat(_tmpLevelKeyList, ":")
end


--创建冗余的levelKey后半段(因为冗余，所以只能和冗余做key)，目前的逻辑这个比较常用，拼上levelId就是levelKey了
function UBFLevelIdUtil:createRedundancyLevelKeyPartWithLevelSceneAndExpGroup(levelScene, expGroup)
    if expGroup == "default:default" then expGroup = "default" end
    if not expGroup then expGroup = "default" end
    if not levelScene then levelScene = UBFLevelSceneType.kMain end
    return levelScene .. ":" .. expGroup
end

UBFLevelIdUtil.DEFAULT_LEVEL_KEY_PART = _G.UBFLevelSceneType.kMain .. ":default"

--[[
    使用 levelKeyData 来创建 levelKey
]]
function UBFLevelIdUtil:createLevelKeyByData(levelkeyData)
    return self:createLevelKey(levelkeyData.levelId, levelkeyData.levelScene, levelkeyData.levelExp, levelkeyData.levelGroup)
end

function UBFLevelIdUtil:traversalDefault(levelId, levelScene, expGroup, func)
    if not func then func = alwaysTrue end

    local config = UBFLevelConfigManager:getLevelGroupConfig()
    local groupRule = config.ruleMap[expGroup]
    if not groupRule then return nil end

    local function getMappingUUID(expGroup)
        return UBFLevelConfigManager:getLevelUuidByLevelKeyParams(levelId, levelScene, expGroup)
    end

    local mLevelId, mLevelScene = UBFLevelIdUtil:mappingLevelIdScene(levelId, levelScene)

    local uuid = getMappingUUID(expGroup)
    if uuid then 
        local ret = func(expGroup, mLevelId, mLevelScene)
        if ret then return ret, expGroup, uuid end 
    end

    local routing = groupRule.fallbackRules or {}
    
    for i = 1, #routing do 
        local currExpGroup = routing[i]
        local uuid = getMappingUUID(currExpGroup)
        if uuid then 
            local ret = func(currExpGroup, mLevelId, mLevelScene)
            if ret then return ret, currExpGroup, uuid end 
        end
    end

    return nil
end

local LEVEL_KEY_DATA_METHODS = {
    fallback = function(self, func) return UBFLevelIdUtil:traversalDefault(self.levelId, self.levelScene, self.levelExpGroup, func) end,
}

function UBFLevelIdUtil:createLevelKeyData(levelId, levelScene, levelExp, levelGroup)
    local levelKeyData = {
        levelId = levelId,
        levelScene = levelScene or UBFLevelSceneType.kMain,
        levelExp = levelExp or "default",
        levelGroup = levelGroup or "default",
    }
    if levelKeyData.levelExp == "default" then 
        levelKeyData.levelExpGroup = "default"
    else
        levelKeyData.levelExpGroup = levelExp .. ":" .. levelGroup
    end
    setmetatable(levelKeyData, { __index = LEVEL_KEY_DATA_METHODS })
    return levelKeyData
end

--[[
    使用 levelKey 来创建 levelKeyData
]]
function UBFLevelIdUtil:createLevelKeyDataByLevelKey(levelkey)
    if not levelkey then return nil end
    local _arr = string.split(levelkey, ":")
    return self:createLevelKeyData(unpack(_arr))
end

--[[
    自动计算玩家某一关的关卡分组，然后以此创建 levelkey
]]
function UBFLevelIdUtil:createLevelKeyDataWithAutoLevelGroup(levelId, levelScene)
    levelScene = levelScene or UBFLevelSceneType.kMain
    local levelKeyData = { levelId = levelId, levelScene = levelScene }
    local levelExpGroup = UBFLevelConfigManager:userConfig():getLevelGroup(levelId, levelScene)
    if levelExpGroup == "default" then 
        levelKeyData.levelExp = "default"
        levelKeyData.levelGroup = "default"
        levelKeyData.levelExpGroup = "default"
    else
        local _arr = string.split(levelExpGroup, ":")
        levelKeyData.levelExp = _arr[1]
        levelKeyData.levelGroup = _arr[2]
        levelKeyData.levelExpGroup = levelExpGroup
    end
    setmetatable(levelKeyData, { __index = LEVEL_KEY_DATA_METHODS })
    return levelKeyData
end

function UBFLevelIdUtil:tryGetCurrLevelScene()
    if not UBFProcessManager then return end
    local process = UBFProcessManager:getCurrStartProcess()
	if process then 
		local runtime = process:getResult("runtime")
		if runtime then return runtime:getLevelScene() end
	end
	
	local inst = UBFGameSceneManager and UBFGameSceneManager:getInstance()
	if inst then return inst:getLevelInfo().levelScene  end

	return nil
end

--mapping后的字段只能作为临时字段，不允许存储！！！
function UBFLevelIdUtil:mappingLevelIdScene(levelId, levelScene) 
    if levelScene == UBFLevelSceneType.kLib then 
        return levelId, UBFLevelSceneType.kMain, true
    end
    return levelId, levelScene, false
end

return UBFLevelIdUtil