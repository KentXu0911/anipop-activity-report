local UBFuuuSelectAdjust = {}

--
--
--
--



local diffIndexMin = -9
local diffIndexMax = 9

local minDiffFix = -16
local maxDiffFix = 7

local minStepFix = 0
local maxStepFix = 27

local maxLevelStar = 4   -- 主线满星（彩星）档位，达到即视为刷分；与成就侧 oldStar < 4 门槛一致

local activityIndexMin = 1
local activityIndexMax = 16

local paymentIndexMin = 1
local paymentIndexMax = 16

-- D3 只在 topLevel 不超过该值时才参与计算，超过后走 legacy 区域限制
local d3TopLevelLimit = 12000

local levelFlag0 = 1
local levelFlag1 = 8896
local levelFlag2 = 60
local levelFlag3 = 10861

local topStr = "Top"
local secTopStr = "secTop"

local TimeUtil = require "amf.middleware.ui.util.TimeUtil"

-- Cxx配置分组，对哪些开关名启用。默认ubfuuu_switch_config命中的开关名会自动启用，这个列表里配置的是额外还有哪些开关名要启用
-- 必须是“ubfuuu_”开头的配置名才行！！！
local CGroupSwitchNameList = {
    "diff_test_5k",
}

-- CA配置分组，对哪些开关名启用。默认ubfuuu_switch_config命中的开关名会自动启用，这个列表里配置的是额外还有哪些开关名要启用
-- 必须是“ubfuuu_”开头的配置名才行！！！
local CAGroupSwitchNameList = {
    "super_magic_bird_charge_act",
    -- "return_booster", --已经作废了，被下面的pet_diff_test夺舍了
    "pet_diff_test",
    "pet_wings_switch",
}

_G.UBFuuuConfigIdToNameMap = {}
for k,v in pairs(UBFuuuConfigNameId) do
    UBFuuuConfigIdToNameMap[v] = k
end

function UBFuuuSelectAdjust:timeInSec()
    return TimeKit:timeInSec()
end

function UBFuuuSelectAdjust:getDiffFixRange()
    return {max = maxDiffFix, min = minDiffFix}
end

function UBFuuuSelectAdjust:getStepFixRange()
    return {max = maxStepFix, min = minStepFix}
end


function UBFuuuSelectAdjust:createConfigGroupMap(cfgGroup, CAGroup)

    local _cfgGroupMap = {}
    for k,v in pairs(cfgGroup or {}) do
        if UBFuuuConfigIdToNameMap[k] then
            _cfgGroupMap[ UBFuuuConfigIdToNameMap[k] ] = v
        end
    end

    if CAGroup then
        for k,v in pairs(CAGroup) do
            _cfgGroupMap[k] = v
        end
    end

    return _cfgGroupMap
end

local _maintenance = "UBFuuu2025"
local _switchInfos = nil

function UBFuuuSelectAdjust:_checkPlatform( platforms )

    local platformList = nil
    if type(platforms) ~= "table" then
		platformList = platforms:split(",")
	else
		platformList = platforms
	end

    if self.debugMode then printx(1, "UBFuuuSelectAdjust:_checkPlatform  platformList =" , tts(platformList)) end

	local curPlatform = _G._PLATFORM_NAME
	local isCurPlatform = false
	local isMiniGame = EnvUtil:isMiniGame()

	if platformList then
		if (EnvUtil:isApp() or __WIN32) and table.indexOf(platformList, "app_all") then
            if self.debugMode then printx(1, "UBFuuuSelectAdjust:_checkPlatform  111") end
			isCurPlatform = true
		elseif isMiniGame and table.indexOf(platformList, "minigame_all") then
            if self.debugMode then printx(1, "UBFuuuSelectAdjust:_checkPlatform  222") end
			isCurPlatform = true
		elseif (table.indexOf(platformList, "default") ~= nil) or (table.indexOf(platformList, curPlatform) ~= nil) then
            if self.debugMode then printx(1, "UBFuuuSelectAdjust:_checkPlatform  333,  curPlatform =", curPlatform) end
			isCurPlatform = true
		end
	end

	return isCurPlatform
end


function UBFuuuSelectAdjust:_findSwitch(ubfuuu_switch_config)
    
    local _groupId = 1

    if self.debugMode then printx(1, "UBFuuuSelectAdjust:_findSwitch  ubfuuu_switch_config =" , tts(ubfuuu_switch_config)) end

    for k,v in ipairs(ubfuuu_switch_config) do
        if v.groupId == _groupId then

            local _platformIsOk = true
            if v.platform and v.platform ~= "" then

                if self.debugMode then printx(1, "UBFuuuSelectAdjust:_findSwitch  _checkPlatform v.platform =" , v.platform) end
                _platformIsOk = self:_checkPlatform(v.platform)
            end

            if self.debugMode then printx(1, "UBFuuuSelectAdjust:_findSwitch  _checkPlatform _platformIsOk =" , _platformIsOk) end

            if _platformIsOk then
                local _startTime = nil
                local _endTime = nil

                if v.startTime then
                    _startTime = TimeUtil:parseTimeString(v.startTime, true) 
                end

                if v.endTime then
                    _endTime = TimeUtil:parseTimeString(v.endTime, true) 
                end

                local _now = self:timeInSec()

                if self.debugMode then printx(1, "UBFuuuSelectAdjust:_findSwitch  _startTime:" , _startTime, "_endTime:",_endTime, "_now:",_now) end
                
                local _b1 = true
                local _b2 = true

                if _startTime then
                    _b1 = _now >= _startTime
                end
                if _endTime then
                    _b2 = _now <= _endTime
                end
                
                if self.debugMode then printx(1, "UBFuuuSelectAdjust:_findSwitch  _b1:" , _b1, "_b2:",_b2) end

                if _b1 and _b2 then
                    local _maintenanceId = v.switchId
                    if self.debugMode then printx(1, "UBFuuuSelectAdjust:_findSwitch  _maintenanceId:" , _maintenanceId) end
                    return MaintenanceManager:getInstance():getMaintenanceNameById(_maintenanceId), _maintenanceId
                end
            end
        end
    end
    return nil
end

function UBFuuuSelectAdjust:getSwitchInfo()
    local ubfuuu_switch_config = require "ubf.metaConfig.ubfuuu_switch_config"
    local _newMaintenanceName, _maintenanceId = self:_findSwitch(ubfuuu_switch_config)
    if not _newMaintenanceName then return end

    -- local _returnData = self:createSwitchInfos()
    -- return _maintenanceId, _newMaintenanceName, _returnData

    return _maintenanceId, _newMaintenanceName
end

function UBFuuuSelectAdjust:createSwitchInfos(passCache)
    -- 注意，这个方法只运行一次，预期只能包含静态检测

    local _returnData = nil

    if passCache then 
        _returnData = {
            cfgGroup = {},
            modGroup = {},
            CAGroup = {},
        }
    else
        if _switchInfos and _switchInfos.CAGroup then return _switchInfos end
        _switchInfos = {
            cfgGroup = {},
            modGroup = {},
            CAGroup = {},
        }
        _returnData = _switchInfos
    end
    
    local ubfuuu_switch_config = require "ubf.metaConfig.ubfuuu_switch_config"
    local _newMaintenanceName, _maintenanceId = self:_findSwitch(ubfuuu_switch_config)

    if _newMaintenanceName then 
        _maintenance = _newMaintenanceName 
    else
        _maintenance = "UBFuuu2025"
    end

    if self.debugMode then printx(1, "UBFuuuSelectAdjust:createSwitchInfos  maintenance name =" , _maintenance, "  _newMaintenanceName =", _newMaintenanceName ) end

    -- 解析Cxx开关
    local function createCGroupSwitch( switchName )     
        for i = 1, 9 do
            for ia = 1, 9 do
                if MaintenanceManager:getInstance():isEnabledInGroup( switchName , "C" .. tostring(i) .. tostring(ia)  ) then  _returnData.cfgGroup[i] = ia end
            end
        end
    end

    createCGroupSwitch(_maintenance)
    for k,v in ipairs(CGroupSwitchNameList) do
        createCGroupSwitch(v)
    end


    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "A3"  ) then _returnData.modGroup.A3 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "A4"  ) then _returnData.modGroup.A4 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "A5"  ) then _returnData.modGroup.A5 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "A6"  ) then _returnData.modGroup.A6 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "A7"  ) then _returnData.modGroup.A7 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "A8"  ) then _returnData.modGroup.A8 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "D2"  ) then _returnData.modGroup.D2 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "baodiV1"  ) then _returnData.modGroup.baodiV1 = true end
    -- 刷星保底（独立于 baodiV1）：只影响刷星分支（0 < levelStar < maxLevelStar），见 __getDesiredDiffAvgFix
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "baodiV2"  ) then _returnData.modGroup.baodiV2 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "D3"  ) then _returnData.modGroup.D3 = true end

    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "B3"  ) then _returnData.modGroup.B3 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "B4"  ) then _returnData.modGroup.B4 = true end

    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "E2"  ) then _returnData.modGroup.E2 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "E3"  ) then _returnData.modGroup.E3 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "E4"  ) then _returnData.modGroup.E4 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "E6"  ) then _returnData.modGroup.E6 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "E7"  ) then _returnData.modGroup.E7 = true end

    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "CoreL1"  ) then _returnData.modGroup.CoreL1 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "birdAbility"  ) then _returnData.modGroup.birdAbility = true end

    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "T1"  ) then _returnData.modGroup.T1 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "T2"  ) then _returnData.modGroup.T2 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "T3"  ) then _returnData.modGroup.T3 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup( _maintenance , "T31"  ) then _returnData.modGroup.T31 = true end

    if EnvUtil:isOhos() then
        -- oh开关写死E5,B5模块&C12配置调整到C10&上线A8,CA8_5测试
        -- https://project.feishu.cn/animal-proj/story/detail/7025224793
        _returnData.modGroup.B5 = true 
        _returnData.modGroup.E5 = true
    end

    -- 开关 1419（ubfuuu_step_item_adjust）：加步数道具调节迭代（独立开关，不走主开关 _maintenance）
    if MaintenanceManager:getInstance():isEnabledInGroup("ubfuuu_step_item_adjust", "add3_5") then _returnData.modGroup.add3_5 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup("ubfuuu_step_item_adjust", "add3") then _returnData.modGroup.add3 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup("ubfuuu_step_item_adjust", "add5") then _returnData.modGroup.add5 = true end
    if MaintenanceManager:getInstance():isEnabledInGroup("ubfuuu_step_item_adjust", "add5_alluser") then _returnData.modGroup.add5_alluser = true end
    if MaintenanceManager:getInstance():isEnabledInGroup("ubfuuu_step_item_adjust", "add3_5_alluser") then _returnData.modGroup.add3_5_alluser = true end

    -- 解析CA开关
    local function getCANameList()
        local _map = {}
        local _list = {}
        for _, v in pairs(UBFuuuConfigNameId or {}) do
            if type(v) == "string" and string.match(v, "^CA%d+$") and not _map[v] then
                _map[v] = true
                table.insert(_list, v)
            end
        end

        table.sort(_list, function(a, b)
            return (tonumber(string.match(a, "%d+")) or 0) < (tonumber(string.match(b, "%d+")) or 0)
        end)

        return _list
    end

    local caNameList = getCANameList()
    local function createCAGroupSwitch( switchName )
        for _, _str in ipairs(caNameList) do
            if MaintenanceManager:getInstance():isEnabledInGroup( switchName , _str ) then 
                _returnData.CAGroup[_str] = 0 
            end

            for ia = 1, 9 do
                local _str2 = _str .. "_" .. tostring(ia)
                if MaintenanceManager:getInstance():isEnabledInGroup( switchName , _str2 ) then 
                    _returnData.CAGroup[_str] = ia 
                end
            end
        end
    end

    createCAGroupSwitch(_maintenance)

    for k,v in ipairs(CAGroupSwitchNameList) do
        createCAGroupSwitch(v)
    end
    
    -- for test
    --  _returnData.CAGroup["CA4"] = 2
    --  _returnData.modGroup.A4 = true
     
     _returnData.switchName = _maintenance
     _returnData.switchId = _maintenanceId
     
    --  printx(1, "UBFuuuSelectAdjust:createSwitchInfos(passCache) --------- ", tts(_returnData))
    return _returnData
end

function UBFuuuSelectAdjust:getTopAreaId( adjustContext )
    local _maxLevelId = adjustContext.maxLevelId
    return math.ceil( (_maxLevelId - adjustContext.topRangeLength) / 15 )
end

function UBFuuuSelectAdjust:getSecTopAreaId( adjustContext )
    local _maxLevelId = adjustContext.maxLevelId
    return math.ceil( (_maxLevelId - adjustContext.topRangeLength - adjustContext.secTopRangeLength) / 15 )
end

function UBFuuuSelectAdjust:_isUBFuuuLevelRange( levelId, maxLevel )
    if (levelId >= levelFlag0 and levelId <= maxLevel) then 
        return true
    end
    return false
end

function UBFuuuSelectAdjust:checkEnable( levelId, levelScene )

    -- local _ubfuuuON = MaintenanceManager:getInstance():isEnabledInGroup( "UBFuuu2024" , "ON"  )
    if levelScene and levelScene ~= UBFLevelSceneType.kMain then
        return false
    end

    local _maxLevel = nil

    if EnvUtil then
        _maxLevel =  _G.amfBean("LevelUnLockManager"):getUserMaxLevelId()
    else
        _maxLevel = UBFLevelRangeUtil:getMaxLevelForAdjust()
    end

    if log then printx( 1 , "Ald2024ActManager Start Level !!!  levelId:", levelId, "maxLevel:", _maxLevel, "isTopLevelRange:", _isTopLevel, "ubfuuuON:", _ubfuuuON ) end
    
    -- 8896~8925
    -- 8926~8955
    
    if self:_isUBFuuuLevelRange(levelId, _maxLevel) then 
        return true
    end

    return false
end

function UBFuuuSelectAdjust:rebuildContext( levelId, datas )
    -- printx(1 , "UBFuuuSelectAdjust:rebuildContext ----------- ", levelId)

    local levelKeyData = UBFLevelIdUtil:createLevelKeyDataWithAutoLevelGroup(levelId, UBFLevelSceneType.kMain)
    local ret, meetGroup, uuid = levelKeyData:fallback()
    local levelExpGroupArr = nil

    if meetGroup then
        levelExpGroupArr = string.split(meetGroup, ":")
    end

    local adjustContext = {}

    adjustContext.levelId = levelId
    adjustContext.areaId = math.ceil( levelId / 15 )

    adjustContext.levelExp = (levelExpGroupArr and levelExpGroupArr[1]) or "default"
    adjustContext.levelGroup = (levelExpGroupArr and levelExpGroupArr[2]) or "default"

    adjustContext.cfgGroup = {}

    if datas then
        for k,v in pairs(datas) do
            adjustContext[k] = v
        end
    end

    local switchInfos = self:createSwitchInfos(true)

    if EnvUtil:isMiniGame() then
        switchInfos.modGroup.enableFixScore = false
        switchInfos.modGroup.enableFixIceCombo = levelId >= levelFlag3
    else
        switchInfos.modGroup.enableFixScore = levelId < levelFlag3
        switchInfos.modGroup.enableFixIceCombo = levelId >= levelFlag3
    end

    -- 9.18 新关无冰块砍分(开关1576 new_score_level): ON 组内 9.18 起(关卡号 >= extra 配置边界)的当周新关不做冰块连消砍分。
    -- 先判开关再读 extra, 非 ON 组不读; 新关判定与 scorelogic_test_rust 走同一口径(isTopNewMainOrHideLevel), 老关由那套 bothOFF 逻辑处理。
    local maintenanceManager = MaintenanceManager:getInstance()
    if maintenanceManager:isEnabledInGroup("new_score_level", "ON")
        and _G.amfBean("LevelUnLockManager"):isTopNewMainOrHideLevel(levelId, UBFLevelSceneType.kMain)
        and levelId >= maintenanceManager:getLevelRangesByExtra("new_score_level")[1].startLevel then
        switchInfos.modGroup.enableFixIceCombo = false
    end

    local scoreLogicTestRustDebugInfo = {
        levelId = levelId,
        isInRust = adjustContext.isInRust,
    }

    do
        local scoreLogicTestRustMinMinorVersion = 159
        local scoreLogicTestRustAppMaintenance = "scorelogic_test_rust_APP"
        local scoreLogicTestRustOtherMaintenance = "scorelogic_test_rust_other"
        local scoreLogicTestRustOhMaintenance = "scorelogic_test_oh"

        local function checkScoreLogicTestRustVersion()
            local versionArr = string.split(tostring(_G.bundleVersion or ""), ".")
            local minorVersion = tonumber(versionArr and versionArr[2]) or 0

            return minorVersion >= scoreLogicTestRustMinMinorVersion
        end

        local function isScoreLogicTestRustLevel(levelId)
            local isTopNewLevel = _G.amfBean("LevelUnLockManager"):isTopNewMainOrHideLevel(levelId, UBFLevelSceneType.kMain)
            return levelId >= 1 and isTopNewLevel == false
        end

        local function getScoreLogicTestRustGroupName(maintenanceManager, maintenanceName)
            local maintenanceFeature = maintenanceManager:getMaintenanceByKey(maintenanceName)
            local groupName = nil

            if maintenanceFeature and maintenanceFeature.enable then
                local isBothOFF = maintenanceManager:isEnabledInGroup(maintenanceName, "bothOFF")
                local inFixAGroup = maintenanceManager:isEnabledInGroup(maintenanceName, "fixA")
                local inFixCGroup = maintenanceManager:isEnabledInGroup(maintenanceName, "fixC")

                groupName = "OFF"
                if isBothOFF then
                    groupName = "bothOFF"
                elseif inFixAGroup and inFixCGroup then
                    groupName = "fixA,fixC"
                elseif inFixAGroup then
                    groupName = "fixA"
                elseif inFixCGroup then
                    groupName = "fixC"
                end
            end

            return groupName
        end

        local function getScoreLogicTestRustMaintenanceName()
            if EnvUtil:isMiniGame() then
                return nil
            end

            if EnvUtil:isOhos() then
                return scoreLogicTestRustOhMaintenance
            end

            if EnvUtil:isAndroidPlatform(PlatformNameEnum.kHE) or EnvUtil:isIOS() then
                return scoreLogicTestRustOtherMaintenance
            end

            if EnvUtil:isApp() then
                return scoreLogicTestRustAppMaintenance
            end

            return scoreLogicTestRustOtherMaintenance
        end

        local versionOk = checkScoreLogicTestRustVersion()
        local levelOk = isScoreLogicTestRustLevel(levelId)
        local rustOk = adjustContext.isInRust == true

        scoreLogicTestRustDebugInfo.versionOk = versionOk
        scoreLogicTestRustDebugInfo.levelOk = levelOk
        scoreLogicTestRustDebugInfo.gateOk = versionOk and rustOk and levelOk
        if not versionOk then
            scoreLogicTestRustDebugInfo.skipReason = "version"
        elseif not rustOk then
            scoreLogicTestRustDebugInfo.skipReason = "notRust"
        elseif not levelOk then
            scoreLogicTestRustDebugInfo.skipReason = "topNewLevel"
        end

        if scoreLogicTestRustDebugInfo.gateOk then
            local maintenanceManager = MaintenanceManager:getInstance()
            local maintenanceName = getScoreLogicTestRustMaintenanceName()
            scoreLogicTestRustDebugInfo.maintenanceName = maintenanceName

            if maintenanceName then
                local groupName = getScoreLogicTestRustGroupName(maintenanceManager, maintenanceName)
                scoreLogicTestRustDebugInfo.groupName = groupName

                if groupName and groupName ~= "OFF" then
                    scoreLogicTestRustDebugInfo.applied = true
                    switchInfos.modGroup.enableFixScore = groupName == "fixA" or groupName == "fixA,fixC"
                    switchInfos.modGroup.enableFixIceCombo = groupName == "fixC" or groupName == "fixA,fixC"
                    printx(0, "[ScoreLogicTestRustApp]", "apply", "maintenance", maintenanceName, "levelId", levelId, "fixA", tostring(switchInfos.modGroup.enableFixScore), "fixC", tostring(switchInfos.modGroup.enableFixIceCombo), "isInRust", tostring(adjustContext.isInRust))
                elseif groupName == nil then
                    scoreLogicTestRustDebugInfo.skipReason = "noGroup"
                end
            else
                scoreLogicTestRustDebugInfo.skipReason = "noMaintenance"
            end
        end
    end

    --
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--
--

    

    for k,v in pairs(switchInfos) do
        adjustContext[k] = v
    end

    adjustContext.selfFeedbackCollect = 1
    adjustContext.luckyBagPartyEnabledAndHasEffect = false
    
    if EnvUtil then
        adjustContext.userCreateTime = math.floor( tonumber( _G.amfBean("AccountManager"):getUserCreateTime() ) / 1000 )
    else
        adjustContext.userCreateTime = math.floor( tonumber( UserManager:getInstance().mark.createTime ) / 1000 )
    end
    
    local createDay = time2day( adjustContext.userCreateTime ) 
    local nowDay = time2day( self:timeInSec() ) 
    adjustContext.userCreateDays = nowDay - createDay

    local UBFuuuAdjustManager = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuAdjustManager"
    local ubfuuuStatisticInfo = UBFuuuAdjustManager:getAdjustContextData()

    -- 刷星保底：失败次数取进关时快照（本地缓存与服务端下发合并后的当前值），本局结算结果只影响下一次进关
    adjustContext.farmStarFailCount = UBFuuuAdjustManager:getFarmStarFailCount(levelId)

    if ubfuuuStatisticInfo.logicVer then
        adjustContext.ubfuuuStatisticInfo = ubfuuuStatisticInfo
        adjustContext.areaStatisticInfoList = ubfuuuStatisticInfo.areaStatisticInfoList
        adjustContext.initState = UBFuuuAdjustManager:getAdjustContextIniteState()
        adjustContext.clientReceiveTime = ubfuuuStatisticInfo.clientReceiveTime
    end

    adjustContext.topLevel = UserManager:getInstance():getUserRef():getTopLevelId()
    adjustContext.topLevelAreaId = math.ceil( adjustContext.topLevel / 15 )
    adjustContext.oldMaxLevelId = UBFLevelRangeUtil:getCanPlayTopLevel()
    adjustContext.maxLevelId = UBFLevelRangeUtil:getMaxLevelForAdjust()
    adjustContext.topRangeLength = UBFLevelRangeUtil:getTopLevelRangeLength() or 30
    adjustContext.secTopRangeLength = UBFLevelRangeUtil:getSecTopLevelRangeLength()

    if EnvUtil then
        adjustContext.topLevelFailCount = _G.amfBean("LevelAreaManager"):getTopLevelLogicalFailCount() or 0
    else
        adjustContext.topLevelFailCount = UserTagManager:getTopLevelLogicalFailCounts() or 0
    end
    
    local levelScore = UserManager:getInstance():getUserScore(adjustContext.levelId, adjustContext.levelScene)
	if levelScore and levelScore.star and levelScore.star > 0 then
		adjustContext.levelStar = levelScore.star
	else
		adjustContext.levelStar = 0
	end
    
    adjustContext.topLevelLastPLayDiffIndex = ubfuuuStatisticInfo.topLevelLastPLayDiffIndex
    adjustContext.toplevelBaoDiFlag = ubfuuuStatisticInfo.toplevelBaoDiFlag
    adjustContext.toplevelBaoDiLevel = ubfuuuStatisticInfo.toplevelBaoDiLevel
    adjustContext.todayPassLevelCount = ubfuuuStatisticInfo.todayPassLevelCount
    adjustContext.todayStreakWinCount = ubfuuuStatisticInfo.todayStreakWinCount
    adjustContext.todayStreakWinBreakCount = ubfuuuStatisticInfo.todayStreakWinBreakCount


    local desiredDiffAvg = 0

    local UBFuuuLevelTargetAvg = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuLevelTargetAvg"
    local targetDiffData = UBFuuuLevelTargetAvg:getTargetDiffAvg( adjustContext.levelId, adjustContext.levelScene )
    if targetDiffData then

        local _str = nil
        if adjustContext.cfgGroup[UBFuuuConfigNameId["ubfuuu_ds_avg_map"]] then
            _str = "_" .. tostring(adjustContext.cfgGroup[UBFuuuConfigNameId["ubfuuu_ds_avg_map"]])
        end

        -- printx(1 , "UBFuuuSelectAdjust:rebuildContext   ------- ",levelId , adjustContext.maxLevelId, adjustContext.topRangeLength,_str, tts(targetDiffData) ,tts(adjustContext.cfgGroup) )

        if levelId > adjustContext.maxLevelId - adjustContext.topRangeLength then
            if _str then
                desiredDiffAvg = targetDiffData["avg_Top" .. _str] or targetDiffData["avg_Top"] or targetDiffData["avg" .. _str] or targetDiffData["avg"] or 0
            else
                desiredDiffAvg = targetDiffData["avg_Top"] or targetDiffData["avg"] or 0
            end
        else
            if _str then
                desiredDiffAvg = targetDiffData["avg" .. _str] or targetDiffData["avg"] or 0
            else
                desiredDiffAvg = targetDiffData["avg"] or 0
            end
        end
    end

    adjustContext.desiredDiffAvg = desiredDiffAvg

    adjustContext.returnState = UBFTagManager:checkReturnBackState(
                                                _G.ReturnUserActivityType.kAllPlayLevel, 
                                                7, 
                                                _G.ReturnUserActivityType.kAllPlayLevel, 
                                                7
                                            )
    adjustContext.lostDay = UBFTagManager:getDaysBeforeReturnBack(ReturnUserActivityType.kAllPlayLevel)
    adjustContext.returnDayIndex = UBFTagManager:getDaysAfterReturnBack(ReturnUserActivityType.kAllPlayLevel, ReturnUserActivityType.kAllPlayLevel)
    adjustContext.todayFirstStartLevelId, _dayindex = UBFTagManager:getTodayFirstStartLevelId(true)

    -- printx(1 , "UBFuuuSelectAdjust:rebuildContext   ------- todayFirstStartLevelId :", adjustContext.todayFirstStartLevelId, " dayindex:", _dayindex )

    return adjustContext
end

function UBFuuuSelectAdjust:getContext()
    return self.adjustContext
end

function UBFuuuSelectAdjust:setContext( adjustContext )
    self.adjustContext = adjustContext
end

-------------------------------------------------------------------------------

function UBFuuuSelectAdjust:findActivityIndexInMap(adjustContext, UBFuuuActivityIndexMap, fixedPlayCount, topLevelAreaId, configGroup)

    if not configGroup then configGroup = 0 end

    if UBFuuuActivityIndexMap and fixedPlayCount and topLevelAreaId then
        
        _activityIndexMapCache = {}
        
        for k,v in ipairs(UBFuuuActivityIndexMap) do

            local _group = tonumber(v.group) or 0

            if _group == configGroup then

                local _areaId = v.areaId or 99999
                if _areaId == topStr then
                    _areaId = self:getTopAreaId(adjustContext)
                elseif _areaId == secTopStr then
                    _areaId = self:getSecTopAreaId(adjustContext)
                end

                if topLevelAreaId <= _areaId then
                    for i = activityIndexMin,  activityIndexMax do
                        local _configValue = v["A" .. tostring(i)]
                        if _configValue and fixedPlayCount <= tonumber(_configValue) then
                            return i
                        end
                    end
                end
            end
        end
    end 

    return 0
end

local _paymentIndexMapCache = nil
function UBFuuuSelectAdjust:findPaymentIndexInMap(adjustContext, UBFuuuPaymentIndexMap, fixedAddStepCount, topLevelAreaId, configGroup)

    -- if not _G.isLocalDevelopMode then
    --     if _paymentIndexMapCache and fixedAddStepCount then
    --         for k,v in ipairs(_paymentIndexMapCache) do
    --             if fixedAddStepCount <= v.max then
    --                 return v.index
    --             end
    --         end
    --     end
    -- end

    if not configGroup then configGroup = 0 end

    if UBFuuuPaymentIndexMap and fixedAddStepCount then
        
        for k,v in ipairs(UBFuuuPaymentIndexMap) do

            local _group = v.group or 0

            if _group == configGroup then

                -- if self.debugMode then printx(1, "UBFuuuSelectAdjust:findPaymentIndexInMap _group:" , _group, " v.areaId =" , v.areaId, " --------------") end
                local _areaId = v.areaId or 99999
                if _areaId == topStr then
                    _areaId = self:getTopAreaId(adjustContext)
                elseif _areaId == secTopStr then
                    _areaId = self:getSecTopAreaId(adjustContext)
                end

                if topLevelAreaId <= _areaId then

                    -- if self.debugMode then printx(1, "UBFuuuSelectAdjust:findPaymentIndexInMap select area:", _areaId, " topLevelAreaId:", topLevelAreaId) end

                    for i = 1 , 16 do

                        -- if self.debugMode then printx(1, "UBFuuuSelectAdjust:findPaymentIndexInMap index:", i, " value:", v["index" .. tostring(i)], " fixedAddStepCount:", fixedAddStepCount ) end

                        if fixedAddStepCount <= v["index" .. tostring(i)] then
                            -- if self.debugMode then printx(1, "UBFuuuSelectAdjust:findPaymentIndexInMap return index:", i) end
                            return i
                        end
                    end

                    break
                end
            end
        end
    end 
    -- if self.debugMode then printx(1, "UBFuuuSelectAdjust:findPaymentIndexInMap find nothing , return index:", 0) end
    return 0
end

local _diffIndexMapCache = {}
function UBFuuuSelectAdjust:findDiffIndexInMap(UBFuuuDiffIndexMap, activityIndex, paymentIndex, configGroup)

    local _mapstr = tostring(UBFuuuDiffIndexMap)
    if not _G.isLocalDevelopMode then
        if _diffIndexMapCache[_mapstr] then
            if _diffIndexMapCache[_mapstr][activityIndex] and _diffIndexMapCache[_mapstr][activityIndex][paymentIndex] then
                return _diffIndexMapCache[_mapstr][activityIndex][paymentIndex]
            end
        end
    end

    if not configGroup then configGroup = 0 end

    _diffIndexMapCache[_mapstr] = {}

    if UBFuuuDiffIndexMap then
        for k,v in ipairs(UBFuuuDiffIndexMap) do
            if tonumber(v.group) == configGroup then
                if v.activity then
                    if not _diffIndexMapCache[_mapstr][v.activity] then
                        _diffIndexMapCache[_mapstr][v.activity] = {}
                    end
                    
                    for payindex = paymentIndexMin, paymentIndexMax do
                        local paykey = "pay" .. tostring(payindex)
                        if v[paykey] then
                            _diffIndexMapCache[_mapstr][v.activity][payindex] = tonumber(v[paykey])
                        end
                    end
                end
            end
        end
    end

    if _diffIndexMapCache[_mapstr][activityIndex] and _diffIndexMapCache[_mapstr][activityIndex][paymentIndex] then
        return _diffIndexMapCache[_mapstr][activityIndex][paymentIndex]
    end

    return 0
end

local _finalDiffMapCache = nil
function UBFuuuSelectAdjust:findFinalDiffFixInMap(UBFuuuFinalDiffMap, desiredDiffAvg, diffIndex, configGroup, playId)
    
    if self.debugMode then
        -- diffIndex = -5.1
        -- diffIndex = 5.1
    end

    local _diffIndex = diffIndex
    local diffIndex_up = math.ceil(diffIndex)
    local diffIndex_low = math.floor(diffIndex)

    if diffIndex_up ~= diffIndex_low and playId then

        local md5str = HeMathUtils:md5(playId)
        local randomSeed = hex2number(string.sub(md5str, -8))

        --[[
            -0.7 ----->   30% : 0      70% : -1
                    upDiff:  0 - -0.7 = 0.7
                    lowDiff: -0.7 - -1 = 0.3

            0.7  ----->   30% : 0      70% : 1
                    upDiff:  1 - 0.7 = 0.3
                    lowDiff: 0.7 - 0 = 0.7
        ]]

        local upDiff = diffIndex_up - diffIndex       
        local lowDiff = diffIndex - diffIndex_low 

        require "ubf.UBF.utils.UBFRandom"

        local _ran = UBFRandom:calcValue( randomSeed , 1 , 1000 )
        if self.debugMode then
            printx(1 , "UBFuuuSelectAdjust:findFinalDiffFixInMap ------------------------ playId:", playId )
            printx(1 , "findFinalDiffFixInMap desiredDiffAvg:", desiredDiffAvg, "diffIndex:", diffIndex, "randomSeed:",randomSeed )
            printx(1 , "findFinalDiffFixInMap diffIndex_up:", diffIndex_up, "diffIndex_low:", diffIndex_low, "upDiff:",upDiff, "lowDiff:",lowDiff )
            printx(1 , "findFinalDiffFixInMap _ran =", _ran, "upDiff * 1000 =", upDiff * 1000, " _ran > upDiff * 1000  --> diffIndex_up" )
        end

        if _ran > upDiff * 1000 then
            _diffIndex = diffIndex_up
        else
            _diffIndex = diffIndex_low
        end

        if self.debugMode then
            printx(1 , "findFinalDiffFixInMap  _diffIndex =", _diffIndex )
        end
    end
    
    local function _check(cacheMap)

        for k,v in ipairs(cacheMap) do
            if desiredDiffAvg <= v.desiredDiff then
                return v[_diffIndex]
            end
        end
    end

    if not _G.isLocalDevelopMode then --dev模式下不走缓存
        if _finalDiffMapCache then
            local _returnDiffAvg = _check(_finalDiffMapCache)
            if _returnDiffAvg then return _returnDiffAvg else return desiredDiffAvg end
        end
    end

    if not configGroup then configGroup = 0 end

    if UBFuuuFinalDiffMap then
        
        _finalDiffMapCache = {}

        table.sort(UBFuuuFinalDiffMap, function(a, b) 
            return a.desiredDiff < b.desiredDiff
        end)

        for k,v in ipairs(UBFuuuFinalDiffMap) do

            if tonumber(v.group) == configGroup then
                local _tab = { desiredDiff = v.desiredDiff }

                for diffidx = diffIndexMin, diffIndexMax do

                    local keystr = nil
                    if diffidx < 0 then
                        keystr = "diffIndexN" .. tostring(diffidx * -1)
                    else
                        keystr = "diffIndex" .. tostring(diffidx)
                    end

                    if v[keystr] then
                        _tab[diffidx] = tonumber(v[keystr])
                    end
                end

                table.insert(_finalDiffMapCache, _tab)
            end
        end

        -- if self.debugMode then printx(1, "UBFuuuSelectAdjust:findFinalDiffFixInMap ======= " , tts(_finalDiffMapCache) ) end

        local _returnDiffAvg = _check(_finalDiffMapCache)
        if _returnDiffAvg then return _returnDiffAvg else return desiredDiffAvg end
    end

    return desiredDiffAvg
end

function UBFuuuSelectAdjust:findBaoDiCountInMap(UBFuuuBaoDiMap, desiredDiffAvgFix, failCount, configGroup)

    if not configGroup then configGroup = 0 end
    
    for k,v in ipairs(UBFuuuBaoDiMap) do
        local _group = v.group or 0
        if _group == configGroup and desiredDiffAvgFix <= v.max then
            local _config = { baodiCount = v.baodiCount }
            local _currAvg = nil
            for i = 1, 9 do
                if v["Count" .. tostring(i)] then
                    _currAvg = v["Avg" .. tostring(i)]
                    if failCount <= tonumber(v["Count" .. tostring(i)]) then
                        if self.debugMode then printx(1, "UBFuuuSelectAdjust:findBaoDiCountInMap failCount =" , failCount, "desiredDiffAvgFix =", desiredDiffAvgFix, "configGroup =", configGroup , "i =", i, "Count =", tonumber(v["Count" .. tostring(i)]),  "Avg =" , _currAvg ) end
                        _config.diffAvg = _currAvg
                        break
                    end
                else
                    break
                end
            end

            if not _config.diffAvg then --配置容错
                if self.debugMode then printx(1, "UBFuuuSelectAdjust:findBaoDiCountInMap config error!!!  ",  "Avg =" , _currAvg ) end
                _config.diffAvg = _currAvg
            end

            return _config
        end
    end

    return nil
end

function UBFuuuSelectAdjust:getBaoDiLookupDiffAvg(adjustContext, desiredDiffAvgFix2)
    if not (adjustContext and adjustContext.modGroup and adjustContext.modGroup.baodiV1) then
        return desiredDiffAvgFix2
    end

    return self:__getBaoDiLookupDiffAvg(adjustContext, desiredDiffAvgFix2)
end

-- 保底查表输入的统一规则：fix2 高于原始目标难度时改用原始目标难度查表。
-- 该函数不带任何开关门禁，baodiV1（首闯）与 baodiV2（刷星）各自决定是否调用。
function UBFuuuSelectAdjust:__getBaoDiLookupDiffAvg(adjustContext, desiredDiffAvgFix2)
    local desiredDiffAvg = tonumber(adjustContext and adjustContext.desiredDiffAvg)
    local lookupDiffAvg = tonumber(desiredDiffAvgFix2)
    if desiredDiffAvg and lookupDiffAvg and lookupDiffAvg > desiredDiffAvg then
        return desiredDiffAvg
    end

    return desiredDiffAvgFix2
end

function UBFuuuSelectAdjust:findDefaultAbilityInMap(adjustContext, UBFuuuDefaultAbilityMap, areaId)
    for k,v in ipairs(UBFuuuDefaultAbilityMap) do

        local _areaId = v.areaId
        if _areaId == topStr then
            _areaId = self:getTopAreaId(adjustContext)
        elseif _areaId == secTopStr then
            _areaId = self:getSecTopAreaId(adjustContext)
        end

        if areaId <= _areaId then
            return v.defaultAbility
        end
    end

    return 0
end

function UBFuuuSelectAdjust:findAbilityFixValueInMap(adjustContext, UBFuuuAbilityFixValueMap, areaId, playerAbility, configGroup)

    if not configGroup then configGroup = 0 end

    for k,v in ipairs(UBFuuuAbilityFixValueMap) do
        local _group = v.group or 0
        
        if _group == configGroup then

            local _areaId = v.areaId
            if _areaId == topStr then
                _areaId = self:getTopAreaId(adjustContext)
            elseif _areaId == secTopStr then
                _areaId = self:getSecTopAreaId(adjustContext)
            end

            if areaId <= _areaId then
                local fixv = 0
                if playerAbility >= 0 then
                    fixv = v["ability_" .. tostring(playerAbility)] or 0
                else
                    fixv = v["ability_N" .. tostring(playerAbility * -1)] or 0
                end
                return fixv
            end
        end
    end
    return 0
end

function UBFuuuSelectAdjust:_findValueInMap(configMap, inputValue, configGroup)

    if not configGroup then configGroup = 0 end

    for k,v in ipairs(configMap) do
        local _group = v.group or 0
        if _group == configGroup then
            if inputValue <= v.input then
                return v.output
            end
        end
    end
    return nil
end

function UBFuuuSelectAdjust:findActivityIndexLimitByReturnUserInMap(adjustContext, UBFuuuConfigMap, returnDayIndex, paymentIndex, configGroup)

    if not configGroup then configGroup = 0 end

    if returnDayIndex and returnDayIndex >= 0 then
        for k,v in ipairs(UBFuuuConfigMap) do
            local _group = v.group or 0
            
            if _group == configGroup then
                if paymentIndex >= v.paymentIndexLower and paymentIndex <= v.paymentIndexUpper and returnDayIndex <= v.returnDayIndex then
                    return v.upperLimit, v.lowerLimit
                end
            end
        end
    end
    return nil
end

function UBFuuuSelectAdjust:findPaymentIndexAreaFixByReturnUserInMap(adjustContext, UBFuuuConfigMap, lostDay, configGroup)

    if not configGroup then configGroup = 0 end

    if lostDay and lostDay >= 0 then
        for k,v in ipairs(UBFuuuConfigMap) do
            local _group = v.group or 0
            
            if _group == configGroup then
                if lostDay >= v.lostDay then
                    return v.areaFix
                end
            end
        end
    end
    return nil
end

function UBFuuuSelectAdjust:changeValueByAdjustFixInfo(adjustContext, adjustFixInfo, originValue)

    local _returnValue = originValue
    local _inRange = true
    adjustFixInfo.input = originValue

    if adjustFixInfo.rangeMin and originValue < adjustFixInfo.rangeMin then
        _inRange = false
    end
    if adjustFixInfo.rangeMax and originValue > adjustFixInfo.rangeMax then
        _inRange = false
    end

    if _inRange then

        local _newValue = originValue

        if adjustFixInfo.fixMode == UBFuuuFixMode.kaddVaule then
            _newValue = _newValue + (adjustFixInfo.value or 0)
        elseif adjustFixInfo.fixMode == UBFuuuFixMode.kMultiplyVaule then
            _newValue = math.floor( _newValue * (adjustFixInfo.value or 0) * 1000 ) / 1000
        elseif adjustFixInfo.fixMode == UBFuuuFixMode.kSetVaule then
            _newValue = adjustFixInfo.value or 0
        elseif (
                    adjustFixInfo.fixMode == UBFuuuFixMode.kMapping
                    or adjustFixInfo.fixMode == UBFuuuFixMode.kMappingAddVaule
                    or adjustFixInfo.fixMode == UBFuuuFixMode.kMappingMultiplyValue
                ) 
                and adjustFixInfo.stringValue then

            local _mappingConfig = require("ubf.metaConfig." .. tostring(adjustFixInfo.stringValue) .. "_config")
            if _mappingConfig then
                local configCAGroup = self:__getConfigGroupByFileName( adjustContext, adjustFixInfo.stringValue )
                local _mappingResult = self:_findValueInMap(_mappingConfig, originValue, configCAGroup or 0)

                -- _mappingResult 为 nil 时保持 _newValue 不变，等价无调整
                if _mappingResult ~= nil then
                    if adjustFixInfo.fixMode == UBFuuuFixMode.kMapping then
                        _newValue = _mappingResult
                    elseif adjustFixInfo.fixMode == UBFuuuFixMode.kMappingAddVaule then
                        _newValue = _newValue + _mappingResult
                    elseif adjustFixInfo.fixMode == UBFuuuFixMode.kMappingMultiplyValue then
                        _newValue = math.floor( _newValue * _mappingResult * 1000 ) / 1000
                    else
                        _newValue = _mappingResult
                    end
                end
            end
        end

        if adjustFixInfo.resultMin then
            if originValue >= adjustFixInfo.resultMin and _newValue < adjustFixInfo.resultMin then
                _newValue = adjustFixInfo.resultMin
            elseif originValue < adjustFixInfo.resultMin then
                _newValue = nil
            end
        end

        if _newValue and adjustFixInfo.resultMax then
            if originValue <= adjustFixInfo.resultMax and _newValue > adjustFixInfo.resultMax then
                _newValue = adjustFixInfo.resultMax
            elseif originValue > adjustFixInfo.resultMax then
                _newValue = nil
            end
        end

        if _newValue then _returnValue = _newValue end

        if adjustFixInfo.minValue and _returnValue < adjustFixInfo.minValue then
            _returnValue = adjustFixInfo.minValue
        end
        if adjustFixInfo.maxValue and _returnValue > adjustFixInfo.maxValue then
            _returnValue = adjustFixInfo.maxValue
        end
    end

    adjustFixInfo.output = _returnValue
    return _returnValue
end

function UBFuuuSelectAdjust:changeActivityIndex1ByFixInfo(adjustContext, activityIndex1)
    if adjustContext.activityIndex1FixInfo then
        for k,v in ipairs(adjustContext.activityIndex1FixInfo) do
            activityIndex1 = self:changeValueByAdjustFixInfo(adjustContext, v, activityIndex1)
        end
    end
    return activityIndex1
end

function UBFuuuSelectAdjust:__getConfigGroupByFileName( adjustContext, confiFileName )

    local _configNameId = UBFuuuConfigNameId[confiFileName]
    if not _configNameId then
        -- Numeric-suffix tables inherit the base group for compatibility.
        -- A suffix-specific switch group must be explicitly registered in UBFuuuConfigNameId.
        local baseConfigName = string.match(tostring(confiFileName), "^(.*)_[0-9]+$")
        _configNameId = baseConfigName and UBFuuuConfigNameId[baseConfigName]
    end
    -- printx(1 , "UBFuuuSelectAdjust:__getConfigGroupByFileName confiFileName =" , confiFileName, "_configNameId =", _configNameId )

    if adjustContext and _configNameId then
        if adjustContext.cfgGroup and adjustContext.cfgGroup[_configNameId] then
            return adjustContext.cfgGroup[_configNameId]
        elseif adjustContext.CAGroup and adjustContext.CAGroup[_configNameId] then
            return adjustContext.CAGroup[_configNameId]
        end
    end

    return 0
end

-- A8: 28天活跃×日均闯关 二维查表
function UBFuuuSelectAdjust:findActivityIndexBy28ActiveDayPlayCount(configMap, group, loginDayCount28, avgPlayCountPerDay)
    if not configMap then
        printx(0, "UBFuuuSelectAdjust:findActivityIndexBy28ActiveDayPlayCount configMap is nil")
        return 1
    end

    for k, v in ipairs(configMap) do
        local _group = tonumber(v.group) or 0
        if _group == group then
            if avgPlayCountPerDay <= v.playcount then
                local dayKey = "day" .. tostring(loginDayCount28)
                local result = v[dayKey]
                if result == nil then
                    printx(0, "UBFuuuSelectAdjust:findActivityIndexBy28ActiveDayPlayCount nil value at dayKey=" .. dayKey .. " playcount=" .. tostring(v.playcount) .. " group=" .. tostring(group))
                    return 1
                end
                return result
            end
        end
    end

    return 1
end

function UBFuuuSelectAdjust:__fixActivityIndexByMapRule(adjustContext, paymentIndex, activityIndex, levelCount)

    local configMap = require("ubf.metaConfig.ubfuuu_activity_index_fix_rule_config") 
    if not configMap then
        return nil
    end

    local configGroup = self:__getConfigGroupByFileName( adjustContext, "ubfuuu_activity_index_fix_rule" )

    if not configGroup then configGroup = 0 end

    for k,v in ipairs(configMap) do
        local _group = v.group or 0
        
        if _group == configGroup then
            if  ( (not v.payLower)          or   paymentIndex >= v.payLower ) and 
                ( (not v.payUpper)          or   paymentIndex <= v.payUpper ) and 
                ( (not v.activityLower)     or   activityIndex >= v.activityLower ) and 
                ( (not v.activityUpper)     or   activityIndex <= v.activityUpper )
            then
                return v.levelCount, v.fixValue or 1, v.activityAdjustMax
            end
        end
    end

    return nil
end

local function getAreaDiffIndex(areaStatisticInfo)
    if type(areaStatisticInfo) ~= "table" then
        return nil
    end
    return tonumber(areaStatisticInfo.regionDiffAdjustIndexV2)
        or tonumber(areaStatisticInfo.regionDiffAdjustIndex)
end

local function copyAreaStatisticInfo(areaStatisticInfo)
    if type(areaStatisticInfo) ~= "table" then
        return nil
    end

    local copiedAreaStatisticInfo = {}
    for key, value in pairs(areaStatisticInfo) do
        copiedAreaStatisticInfo[key] = value
    end
    return copiedAreaStatisticInfo
end

-- 缺失位优先向更新（下标更小）一侧寻找最近的已知区域；
-- 只有更新一侧完全没有可用数据时，才改用更旧（下标更大）一侧最近的已知区域。
local function findNearestAreaStatisticInfo(areaStatisticInfoList, index, maxIndex)
    for candidateIndex = index - 1, 1, -1 do
        local areaStatisticInfo = areaStatisticInfoList[candidateIndex]
        if getAreaDiffIndex(areaStatisticInfo) ~= nil then
            return areaStatisticInfo
        end
    end

    for candidateIndex = index + 1, maxIndex do
        local areaStatisticInfo = areaStatisticInfoList[candidateIndex]
        if getAreaDiffIndex(areaStatisticInfo) ~= nil then
            return areaStatisticInfo
        end
    end

    return nil
end

function UBFuuuSelectAdjust:__buildD3AreaStatisticInfoList(areaStatisticInfoList)
    if type(areaStatisticInfoList) ~= "table" then
        return nil
    end

    local maxIndex = 0
    local hasUsableAreaStatisticInfo = false
    for index, areaStatisticInfo in pairs(areaStatisticInfoList) do
        if type(index) == "number" and index >= 1 and index % 1 == 0 then
            if index > maxIndex then
                maxIndex = index
            end
            if getAreaDiffIndex(areaStatisticInfo) ~= nil then
                hasUsableAreaStatisticInfo = true
            end
        end
    end

    if not hasUsableAreaStatisticInfo then
        return nil
    end

    local d3AreaStatisticInfoList = {}
    for index = 1, 3 do
        local areaStatisticInfo = areaStatisticInfoList[index]
        if getAreaDiffIndex(areaStatisticInfo) == nil then
            areaStatisticInfo = findNearestAreaStatisticInfo(areaStatisticInfoList, index, maxIndex)
        end
        d3AreaStatisticInfoList[index] = copyAreaStatisticInfo(areaStatisticInfo)
    end

    return d3AreaStatisticInfoList
end

function UBFuuuSelectAdjust:applyAreaDiffIndexLimit(adjustContext, diffIndex3)
    local levelStatisticInfo = (adjustContext and adjustContext.ubfuuuStatisticInfo) or {}
    local legacyPreviousArea = tonumber(levelStatisticInfo.diffIndexOnLastArea)
        or tonumber(adjustContext and adjustContext.diffIndexOnLastArea)
        or 6
    local legacyLimit = legacyPreviousArea + 2
    local topLevel = tonumber(adjustContext and adjustContext.topLevel)
    local d3Enabled = adjustContext
        and adjustContext.modGroup
        and adjustContext.modGroup.D3 == true
        and topLevel ~= nil
        and topLevel <= d3TopLevelLimit

    if d3Enabled then
        local d3AreaStatisticInfoList = self:__buildD3AreaStatisticInfoList(adjustContext.areaStatisticInfoList)
        local area1 = d3AreaStatisticInfoList and d3AreaStatisticInfoList[1]
        local area2 = d3AreaStatisticInfoList and d3AreaStatisticInfoList[2]
        local area3 = d3AreaStatisticInfoList and d3AreaStatisticInfoList[3]

        local area1DiffIndex = getAreaDiffIndex(area1)
        local area2DiffIndex = getAreaDiffIndex(area2)
        local area3DiffIndex = getAreaDiffIndex(area3)

        if area1DiffIndex ~= nil and area2DiffIndex ~= nil and area3DiffIndex ~= nil then
            local d3Limit = area1DiffIndex + 1
            if area2DiffIndex > area3DiffIndex or area1DiffIndex > area2DiffIndex then
                d3Limit = math.min(d3Limit, math.max(area1DiffIndex, area2DiffIndex))
            end
            return math.min(diffIndex3, d3Limit)
        end
    end

    return math.min(diffIndex3, legacyLimit)
end

function UBFuuuSelectAdjust:__calculateDiffIndex( adjustContext )

    local levelStatisticInfo = adjustContext.ubfuuuStatisticInfo


    --############################ 计算 付费指数 ############################
    local fixedAddStepCount = 0

    if levelStatisticInfo.add2StepOnLast30Areas then

        if adjustContext.modGroup and adjustContext.modGroup.E4 and levelStatisticInfo.hammerOnLast30Areas then
            fixedAddStepCount = levelStatisticInfo.add2StepOnLast30Areas * 0.5 + levelStatisticInfo.videoAddStepCount * 0.1 + levelStatisticInfo.add5StepOnLast30Areas 
                                + levelStatisticInfo.hammerOnLast30Areas * 0.5 + levelStatisticInfo.rocketOnLast30Areas + levelStatisticInfo.linebrushOnLast30Areas
        else
            fixedAddStepCount = levelStatisticInfo.add2StepOnLast30Areas * 0.5 + levelStatisticInfo.videoAddStepCount * 0.1 + levelStatisticInfo.add5StepOnLast30Areas
        end
    end
    

    -- local UBFuuuPaymentIndexMap = require("ubf.UBFPlay.configs.adjust.UBFuuuPaymentIndexMap")
    local UBFuuuPaymentIndexMap = require("ubf.metaConfig.ubfuuu_payment_index_map_config")

    -- if self.debugMode then printx(1, "UBFuuuSelectAdjust:__calculateDiffIndex fin_fixedAddStepCount =" , fixedAddStepCount, "topLevelAreaId =" , adjustContext.topLevelAreaId, "group =", adjustContext.cfgGroup[UBFuuuConfigNameId["ubfuuu_payment_index_map"]]  ) end
    local _paymentIndexCount = levelStatisticInfo.v250801CashValue or fixedAddStepCount --E5模块全开 2026.03.23

    if EnvUtil:isOhos() then
        _paymentIndexCount = fixedAddStepCount
        if adjustContext.modGroup then
            if adjustContext.modGroup.E5 then
                _paymentIndexCount = levelStatisticInfo.v250801CashValue or fixedAddStepCount
            end
        end
    end
    
    if adjustContext.modGroup then
        if adjustContext.modGroup.E6 then
            _paymentIndexCount = levelStatisticInfo.v250801CashValue or fixedAddStepCount
        end

         if adjustContext.modGroup.E7 and levelStatisticInfo.v250801CashValue and levelStatisticInfo.v250801FarmCashValue then
            _paymentIndexCount = levelStatisticInfo.v250801CashValue + levelStatisticInfo.v250801FarmCashValue
        end
    end
    local paymentIndex = self:findPaymentIndexInMap( adjustContext, UBFuuuPaymentIndexMap, _paymentIndexCount, adjustContext.topLevelAreaId, adjustContext.cfgGroup[UBFuuuConfigNameId["ubfuuu_payment_index_map"]] )
    local paymentIndex1 = paymentIndex
    local paymentIndex2 = paymentIndex1
    -- if self.debugMode then printx(1, "UBFuuuSelectAdjust:__calculateDiffIndex origin  paymentIndex =" , paymentIndex ) end

    if adjustContext.adjustFixInfo and adjustContext.adjustFixInfo[UBFuuuFixType.kPaymentIndex] then
        for k,v in ipairs(adjustContext.adjustFixInfo[UBFuuuFixType.kPaymentIndex]) do
            paymentIndex2 = self:changeValueByAdjustFixInfo(adjustContext, v, paymentIndex2)
        end
    end
    paymentIndex = paymentIndex2

    if paymentIndex > paymentIndexMax then
        paymentIndex = paymentIndexMax
    end
    if paymentIndex < paymentIndexMin then
        paymentIndex = paymentIndexMin
    end
    -- if self.debugMode then printx(1, "UBFuuuSelectAdjust:__calculateDiffIndex final  paymentIndex =" , paymentIndex ) end




    --############################ 计算 活跃指数 ############################
    local activityIndex = nil
    local activityIndex1 = nil
    local isNewUserFaked = false
    local fixedLoginDayCount28 = nil
    local fixedPlayCount28 = nil
    local avgPlayCountPerDay = nil

    if adjustContext.modGroup and adjustContext.modGroup.A8 then
        local _isTopLevelRange = adjustContext.levelId > adjustContext.maxLevelId - adjustContext.topRangeLength
        if _isTopLevelRange then
            activityIndex1 = 16
        else
            local configMap = require("ubf.metaConfig.ubfuuu_activity_index_map_by_28activeday_playcount_v202604_config")
            local group = self:__getConfigGroupByFileName(adjustContext, "ubfuuu_activity_index_map_by_28activeday_playcount_v202604")

            local _loginDayCount28 = levelStatisticInfo.loginDayCount28 or 0
            local _playCount28 = levelStatisticInfo.playCount28 or 0

            if (adjustContext.userCreateDays or 0) <= 28 then
                local fakeDays = 28 - (adjustContext.userCreateDays or 0)
                _loginDayCount28 = _loginDayCount28 + fakeDays
                fixedPlayCount28 = fakeDays * 20
                isNewUserFaked = true
            end
            fixedLoginDayCount28 = _loginDayCount28

            avgPlayCountPerDay = 0
            if _loginDayCount28 > 0 then
                avgPlayCountPerDay = _playCount28 / _loginDayCount28
            end

            activityIndex1 = self:findActivityIndexBy28ActiveDayPlayCount(configMap, group, _loginDayCount28, avgPlayCountPerDay)
        end
        activityIndex = activityIndex1
    else
        -- 原有逻辑（含 A7 分支）保持不变
        -- local UBFuuuActivityIndexMap = require("ubf.UBFPlay.configs.adjust.UBFuuuActivityIndexMap")
        local UBFuuuActivityIndexMap = require("ubf.metaConfig.ubfuuu_activity_index_map_config")

        local _loginDays = levelStatisticInfo.loginDayCount7 or 0
        local _fixUserCreateDays = adjustContext.userCreateDays or 1

        local _fixedPlayCount1 = levelStatisticInfo.fixedPlayCount1 or 0
        local _fixedPlayCount2 = levelStatisticInfo.fixedPlayCount2 or 0

        if self.debugMode then printx(1, "UBFuuuSelectAdjust:__calculateDiffIndex _loginDays :" , _loginDays, "_fixUserCreateDays :", _fixUserCreateDays ) end

        local _c = _fixedPlayCount1

        if adjustContext.modGroup and adjustContext.modGroup.A7 then
            if _fixedPlayCount2 < _fixedPlayCount1 then
                _c = _fixedPlayCount2
            end
        end
        
        if _fixUserCreateDays > 0 then
            _c = _c * _loginDays / math.min( _fixUserCreateDays, 7 )
        end
        
        levelStatisticInfo.fixedPlayCount = math.floor( _c * 100 ) / 100 
        if self.debugMode then printx(1, "UBFuuuSelectAdjust:__calculateDiffIndex fixedPlayCount :" , levelStatisticInfo.fixedPlayCount ) end

        activityIndex = self:findActivityIndexInMap( adjustContext, UBFuuuActivityIndexMap, levelStatisticInfo.fixedPlayCount, adjustContext.topLevelAreaId, adjustContext.cfgGroup[UBFuuuConfigNameId["ubfuuu_activity_index_map"]] )
        
        activityIndex1 = activityIndex
    end
    activityIndex1 = self:changeActivityIndex1ByFixInfo(adjustContext, activityIndex1)
    activityIndex = activityIndex1
    local activityIndex2 = activityIndex1

    --[[
    if not adjustContext.A1 then
        -- 需要对用户活跃度分档做一个矫正，兼顾到那些虽然最近闯关挺多，但是活跃天数太低的用户，我们整体往低了算
        -- 通过获取过去28天内的活跃天数做计算（注意这个天数不要算当天登录，只能算之前的天）
        if (adjustContext.userCreateDays or 0) > 0 then
            activityIndex2 = math.min( activityIndex1, levelStatisticInfo.loginDayCount28 * math.max( 1, 28 / adjustContext.userCreateDays ) )
        end
    end
    ]]

    local activityIndexUpperLimit, activityIndexLowerLimit = nil, nil
    local _flag = false

    if adjustContext.modGroup and adjustContext.modGroup.A4 and adjustContext.levelId <= adjustContext.maxLevelId - adjustContext.topRangeLength then
        local _fileName = "ubfuuu_activity_index_limit_by_return_user"
        local _configMap = require("ubf.metaConfig." .. _fileName .. "_config")
        local _group = self:__getConfigGroupByFileName( adjustContext, _fileName )

        activityIndexUpperLimit, activityIndexLowerLimit = self:findActivityIndexLimitByReturnUserInMap(adjustContext, _configMap, adjustContext.returnDayIndex, paymentIndex, _group)
        
        if activityIndexUpperLimit then
            if activityIndex2 >= activityIndexUpperLimit then
                activityIndex2 = activityIndexUpperLimit
                _flag = true
            end
        end
    end

    -- 但是，但是，需要考虑一种特别的情况，就是一个回流玩家进来之后，活跃得分很低，对应难度也低
    -- 他可能会利用这个漏洞来参加活动等，获得更大的过关数值上的优势，所以还得做一个将他活跃度上调的补丁
    local activityIndex3 = activityIndex2

    if levelStatisticInfo.todayPassLevelCount then

        local _num = 10
        local _maxChange = nil
        if adjustContext.modGroup then
            if adjustContext.modGroup.A3 then
                _num = 20
            elseif adjustContext.modGroup.A5 then
                _num = 99999999
            elseif adjustContext.modGroup.A6 then
                local levelCount, fixValue, maxChange = self:__fixActivityIndexByMapRule(adjustContext, paymentIndex, activityIndex2, levelStatisticInfo.todayPassLevelCount)
                _num = levelCount
                _maxChange = maxChange
            end
        end
        
        local changeValue = nil
        if _flag then
            changeValue = math.max( math.floor( (levelStatisticInfo.todayPassLevelCount - _num) / _num ), 0 )
            if _maxChange and changeValue > _maxChange then
                changeValue = _maxChange
            end
            activityIndex3 = activityIndex2 + changeValue
        else
            changeValue = math.floor( levelStatisticInfo.todayPassLevelCount / _num )
            if _maxChange and changeValue > _maxChange then
                changeValue = _maxChange
            end
            activityIndex3 = activityIndex2 + changeValue
        end
    end     

    activityIndex3 = math.floor( activityIndex3 + 0.5 )

    local activityIndex4 = activityIndex3

    if adjustContext.adjustFixInfo and adjustContext.adjustFixInfo[UBFuuuFixType.kActivityIndex] then
        for k,v in ipairs(adjustContext.adjustFixInfo[UBFuuuFixType.kActivityIndex]) do
            activityIndex4 = self:changeValueByAdjustFixInfo(adjustContext, v, activityIndex4)
        end
    end

    if activityIndex4 > activityIndexMax then
        activityIndex4 = activityIndexMax
    end
    if activityIndex4 < activityIndexMin then
        activityIndex4 = activityIndexMin
    end

    activityIndex = activityIndex4

    

    --############################ 计算 难度指数 ############################
    -- local UBFuuuDiffIndexMap = require("ubf.UBFPlay.configs.adjust.UBFuuuDiffIndexMap")
    local UBFuuuDiffIndexMap = nil

    -- if adjustContext.adjustFixInfo and adjustContext.adjustFixInfo[UBFuuuFixType.kReplaceUBFuuuConfigFile] then
    --     printx(1, "UBFuuuSelectAdjust:__calculateDiffIndex replace ubfuuu_diff_index_map_config --------------\nadjustContext.adjustFixInfo =", tts(adjustContext.adjustFixInfo) )
    -- end

    local _ubfuuu_diff_index_map_name = "ubfuuu_diff_index_map"
    local _ubfuuu_diff_index_map_id = tostring(UBFuuuConfigNameId["ubfuuu_diff_index_map"])

    if adjustContext.adjustFixInfo 
        and adjustContext.adjustFixInfo[UBFuuuFixType.kReplaceUBFuuuConfigFile] 
        and adjustContext.adjustFixInfo[UBFuuuFixType.kReplaceUBFuuuConfigFile][_ubfuuu_diff_index_map_id] then
            local _replaceInfo = adjustContext.adjustFixInfo[UBFuuuFixType.kReplaceUBFuuuConfigFile][_ubfuuu_diff_index_map_id]
            -- 兼容旧格式（string）和新格式（{sourceName, configName}）
            _ubfuuu_diff_index_map_name = type(_replaceInfo) == "table" and tostring(_replaceInfo.configName) or tostring(_replaceInfo)
    end

    UBFuuuDiffIndexMap = require("ubf.metaConfig." .. _ubfuuu_diff_index_map_name .. "_config")

    local diffIndex1 = self:findDiffIndexInMap( UBFuuuDiffIndexMap, activityIndex, paymentIndex, self:__getConfigGroupByFileName( adjustContext, _ubfuuu_diff_index_map_name ) )

    local _playerAbility = levelStatisticInfo.playerAbility or 0
    -- if not adjustContext.B1 then
    --     local UBFuuuDefaultAbilityMap = require("ubf.metaConfig.ubfuuu_player_ability_default_map_config")
    --     _playerAbility = self:findDefaultAbilityInMap(adjustContext, UBFuuuDefaultAbilityMap, adjustContext.areaId)
    -- end
    local fixByAbility = 0

    local UBFuuuAbilityFixValueMap = require("ubf.metaConfig.ubfuuu_player_ability_fixvalue_map_config")
    fixByAbility = self:findAbilityFixValueInMap(adjustContext, UBFuuuAbilityFixValueMap, adjustContext.areaId, _playerAbility, adjustContext.cfgGroup[UBFuuuConfigNameId["ubfuuu_player_ability_fixvalue_map"]] )

    local diffIndex2 = diffIndex1
    if fixByAbility > 0 then
        if diffIndex1 < 6 then
            if diffIndex1 + fixByAbility > 6 then
                diffIndex2 = 6
            else
                diffIndex2 = diffIndex1 + fixByAbility
            end
        end
    else
        diffIndex2 = diffIndex1 + fixByAbility
    end
        
    if diffIndex2 < diffIndexMin then diffIndex2 = diffIndexMin end
    if diffIndex2 > diffIndexMax then diffIndex2 = diffIndexMax end

    local diffIndex3 = diffIndex2

    if adjustContext.adjustFixInfo and adjustContext.adjustFixInfo[UBFuuuFixType.kDiffIndex] then
        for k,v in ipairs(adjustContext.adjustFixInfo[UBFuuuFixType.kDiffIndex]) do
            diffIndex3 = self:changeValueByAdjustFixInfo(adjustContext, v, diffIndex3)
        end
    end

    local diffIndex4 = self:applyAreaDiffIndexLimit(adjustContext, diffIndex3)

    if diffIndex4 < diffIndexMin then diffIndex4 = diffIndexMin end
    if diffIndex4 > diffIndexMax then diffIndex4 = diffIndexMax end

    local resultData = {

        playId = adjustContext.playId,

        levelId = adjustContext.levelId,
        toplevel = adjustContext.topLevel,
        maxLevelId = adjustContext.maxLevelId,
        topRangeLength = adjustContext.topRangeLength,
        secTopRangeLength = adjustContext.secTopRangeLength,

        diffIndex = diffIndex4,
        diffIndex1 = diffIndex1,
        diffIndex2 = diffIndex2,
        diffIndex3 = diffIndex3,

        playCount3 = levelStatisticInfo.playCount3,
        playCount7 = levelStatisticInfo.playCount7,
        playCount30 = levelStatisticInfo.playCount30,
        todayPlayCount = levelStatisticInfo.todayPlayCount,

        fixedPlayCount1 = levelStatisticInfo.fixedPlayCount1,
        fixedPlayCount2 = levelStatisticInfo.fixedPlayCount2,
        fixedPlayCount = levelStatisticInfo.fixedPlayCount,
        
        loginDayCount7 = levelStatisticInfo.loginDayCount7,
        loginDayCount28 = levelStatisticInfo.loginDayCount28,
        activityIndex = activityIndex,
        activityIndex1 = activityIndex1,
        activityIndex2 = activityIndex2,
        activityIndex3 = activityIndex3,

        addStep2 = levelStatisticInfo.add2StepOnLast30Areas,
        addStep5 = levelStatisticInfo.add5StepOnLast30Areas,
        addStep2Video = levelStatisticInfo.videoAddStepCount,

        hammer_eternal = levelStatisticInfo.hammerOnLast30Areas,
        rocket_eternal = levelStatisticInfo.rocketOnLast30Areas,
        linebrush_eternal = levelStatisticInfo.linebrushOnLast30Areas,

        hammer_limit = levelStatisticInfo.timeHammerOnLast30Areas,
        rocket_limit = levelStatisticInfo.timeRocketOnLast30Areas,
        linebrush_limit = levelStatisticInfo.timeLinebrushOnLast30Areas,
        
        fixedAddStepCount = fixedAddStepCount,
        paymentIndexCount = _paymentIndexCount,
        
        paymentIndex1 = paymentIndex1,
        paymentIndex = paymentIndex,

        playerAbility = levelStatisticInfo.playerAbility,
        playerAbilityValue = levelStatisticInfo.playerAbilityValue,
        newUserLevelSkillValue = levelStatisticInfo.newUserLevelSkillValue,
        topPlayerAbilityValue = levelStatisticInfo.topPlayerAbilityValue,
        newUserAbility20250110Value = levelStatisticInfo.newUserAbility20250110Value,
        newUserAbility20250110Index = levelStatisticInfo.newUserAbility20250110Index,

        avgAbilityV250521Value = levelStatisticInfo.avgAbilityV250521Value,
        abilityV250521Index = levelStatisticInfo.abilityV250521Index,

        -- areaAbilityDCStr = levelStatisticInfo.areaAbilityDCStr,

        prevLogicDiffIndex = adjustContext.topLevelLastPLayDiffIndex,
        diffIndexOnLastArea = levelStatisticInfo.diffIndexOnLastArea or adjustContext.diffIndexOnLastArea,
        topLevelFailCount = adjustContext.topLevelFailCount,

        todayPassLevelCount = adjustContext.todayPassLevelCount,
        toplevelBaoDiFlag = adjustContext.toplevelBaoDiFlag,
        toplevelBaoDiLevel = adjustContext.toplevelBaoDiLevel,

        initState = adjustContext.initState,
        clientReceiveTime = adjustContext.clientReceiveTime,

        userCreateTime = adjustContext.userCreateTime,
        userCreateDays = adjustContext.userCreateDays,
        fixUserCreateDays = _fixUserCreateDays,

        v250801PropUsageMap_forDC = levelStatisticInfo.v250801PropUsageMap_forDC,
        v250801CashValue = levelStatisticInfo.v250801CashValue,

        v250801FarmPropUsageMap_forDC = levelStatisticInfo.v250801FarmPropUsageMap_forDC,
        v250801FarmCashValue = levelStatisticInfo.v250801FarmCashValue,

        returnState = adjustContext.returnState,
        lostDay = adjustContext.lostDay,
        returnDayIndex = adjustContext.returnDayIndex,

        switchName = adjustContext.switchName,
        switchId = adjustContext.switchId,

        playCount28 = levelStatisticInfo.playCount28,
        fixedPlayCount28 = fixedPlayCount28,
        fixedLoginDayCount28 = fixedLoginDayCount28,
        avgPlayCountPerDay = avgPlayCountPerDay,
        isNewUserFaked = isNewUserFaked,
        isTopLevelRangeActivityIndexOverride = (adjustContext.modGroup and adjustContext.modGroup.A8 and adjustContext.levelId > adjustContext.maxLevelId - adjustContext.topRangeLength) or false,
        a9ReturnActivityInfo = adjustContext.a9ReturnActivityInfo,
    }

    resultData.configGroup = self:createConfigGroupMap(adjustContext.cfgGroup, adjustContext.CAGroup)
    resultData.modGroup = adjustContext.reportModGroup or adjustContext.modGroup
    return resultData
end

function UBFuuuSelectAdjust:__getDesiredDiffAvgFix( adjustContext )

    
    local desiredDiffAvgFix = adjustContext.desiredDiffAvg or 5
    local desiredDiffAvgFix1 = desiredDiffAvgFix
    local desiredDiffAvgFix2 = desiredDiffAvgFix

    -- local levelStatisticInfo = adjustContext.ubfuuuStatisticInfo

    local _resultData = self:__calculateDiffIndex(adjustContext)
    
    --############################ 计算 预期难度的偏移数 ############################
    local UBFuuuFinalDiffMap = require("ubf.metaConfig.ubfuuu_final_diff_map_config")

    if adjustContext.desiredDiffAvg and adjustContext.desiredDiffAvg > 0 then
        -- local UBFuuuFinalDiffMap = require("ubf.UBFPlay.configs.adjust.UBFuuuFinalDiffMap")
        
        desiredDiffAvgFix1 = self:findFinalDiffFixInMap( 
                                        UBFuuuFinalDiffMap, 
                                        adjustContext.desiredDiffAvg, 
                                        _resultData.diffIndex, 
                                        adjustContext.cfgGroup[UBFuuuConfigNameId["ubfuuu_final_diff_map"]],
                                        adjustContext.playId
                                    )
        desiredDiffAvgFix2 = desiredDiffAvgFix1
        desiredDiffAvgFix = desiredDiffAvgFix2
    end

    if adjustContext.adjustFixInfo and adjustContext.adjustFixInfo[UBFuuuFixType.kDesiredDiffAvgBeforeBaodi] then
        for k,v in ipairs(adjustContext.adjustFixInfo[UBFuuuFixType.kDesiredDiffAvgBeforeBaodi]) do
            desiredDiffAvgFix2 = self:changeValueByAdjustFixInfo(adjustContext, v, desiredDiffAvgFix2)
        end
        if desiredDiffAvgFix2 < 1 then desiredDiffAvgFix2 = 1 end
        desiredDiffAvgFix = desiredDiffAvgFix2
    end

    --############################ 尝试进行保底 ############################
    if adjustContext.levelId == adjustContext.topLevel then

        if adjustContext.levelStar == 0 then

            local _enableBaoDi = false

            -- 尝试检测是否需要保底
            local UBFuuuBaoDiMap = require("ubf.metaConfig.ubfuuu_baodi_count_map_config")
            -- _resultData.baodiDiffAvg = self:findBaoDiCountInMap( UBFuuuBaoDiMap, desiredDiffAvgFix, adjustContext.cfgGroup[UBFuuuConfigNameId["ubfuuu_baodi_count_map"]]  ) or desiredDiffAvgFix
            local baodiLookupDiffAvg = self:getBaoDiLookupDiffAvg(adjustContext, desiredDiffAvgFix2)
            local baodiConfig = self:findBaoDiCountInMap( 
                                                            UBFuuuBaoDiMap, 
                                                            baodiLookupDiffAvg,
                                                            adjustContext.topLevelFailCount, 
                                                            adjustContext.cfgGroup[UBFuuuConfigNameId["ubfuuu_baodi_count_map"]]  
                                                        ) 
            if self.debugMode then printx(1, "UBFuuuSelectAdjust:__getDesiredDiffAvgFix ", "baodiConfig =" , tts(baodiConfig), "desiredDiffAvgFix2 =", desiredDiffAvgFix2, "baodiLookupDiffAvg =", baodiLookupDiffAvg, "topLevelFailCount =" , adjustContext.topLevelFailCount ) end

            if _resultData.toplevelBaoDiFlag then
                if _resultData.toplevelBaoDiLevel == adjustContext.topLevel then
                    -- 锁定保底状态，在 _resultData.toplevelBaoDiLevel 上持续生效
                    _enableBaoDi = true
                else
                    -- _resultData.toplevelBaoDiLevel 已发生变化，不执行保底
                    _resultData.toplevelBaoDiFlag = false
                    _resultData.toplevelBaoDiLevel = nil
                end
            else
                
                
                if baodiConfig and baodiConfig.baodiCount then
                    _resultData.baodiDiffAvg = baodiConfig.baodiCount 
                else
                    _resultData.baodiDiffAvg = desiredDiffAvgFix2
                end

                _enableBaoDi = adjustContext.topLevelFailCount >= _resultData.baodiDiffAvg

                if _enableBaoDi then
                    _resultData.toplevelBaoDiFlag = true
                    _resultData.toplevelBaoDiLevel = adjustContext.topLevel
                else
                    _resultData.toplevelBaoDiFlag = false
                    _resultData.toplevelBaoDiLevel = nil
                end
            end

            if self.debugMode then printx(1, "UBFuuuSelectAdjust:__getDesiredDiffAvgFix ", "_enableBaoDi =" , _enableBaoDi) end
            if self.debugMode then 
                if baodiConfig then printx(1, "UBFuuuSelectAdjust:__getDesiredDiffAvgFix ", "baodiConfig.diffAvg =" , baodiConfig.diffAvg) end
            end

            if _enableBaoDi then
                -- 执行保底策略
                local _diffindex_BaoDi = nil

                if baodiConfig and baodiConfig.diffAvg and baodiConfig.diffAvg < desiredDiffAvgFix then
                    desiredDiffAvgFix = baodiConfig.diffAvg
                end
            end 
        else
            _resultData.toplevelBaoDiFlag = false
            _resultData.toplevelBaoDiLevel = nil
        end
    end

    --############################ 刷星保底（baodiV2） ############################
    -- 刷星口径沿用 UBFuuu 既有判定：只看星级数与 topLevel，不引入新的关卡类型字段。
    -- 首闯 = levelId == topLevel 且 levelStar == 0（上方分支已处理）；刷星 = 已过关且未满星（0 < levelStar < maxLevelStar）。
    -- 与首闯保底状态完全隔离，不读写 toplevelBaoDiFlag / toplevelBaoDiLevel。
    -- 计数取进关快照 adjustContext.farmStarFailCount，本局结算产生的新计数只影响下一次进关。
    local _levelStar = tonumber(adjustContext.levelStar) or 0
    if _levelStar > 0 and _levelStar < maxLevelStar
        and adjustContext.modGroup and adjustContext.modGroup.baodiV2 then

        local _farmStarFailCount = tonumber(adjustContext.farmStarFailCount) or 0
        if _farmStarFailCount < 0 then _farmStarFailCount = 0 end

        local UBFuuuBaoDiMap = require("ubf.metaConfig.ubfuuu_baodi_count_map_config")
        local baodiLookupDiffAvg = self:__getBaoDiLookupDiffAvg(adjustContext, desiredDiffAvgFix2)
        local baodiConfig = self:findBaoDiCountInMap(
                                                        UBFuuuBaoDiMap,
                                                        baodiLookupDiffAvg,
                                                        _farmStarFailCount,
                                                        adjustContext.cfgGroup[UBFuuuConfigNameId["ubfuuu_baodi_count_map"]]
                                                    )

        local _enableFarmStarBaoDi = false
        if baodiConfig and baodiConfig.baodiCount then
            _enableFarmStarBaoDi = _farmStarFailCount >= baodiConfig.baodiCount
        end

        _resultData.farmStarFailCount = _farmStarFailCount
        _resultData.farmStarBaoDiCount = baodiConfig and baodiConfig.baodiCount
        _resultData.farmStarBaoDiFlag = _enableFarmStarBaoDi

        if self.debugMode then printx(1, "UBFuuuSelectAdjust:__getDesiredDiffAvgFix FARM_STAR baodi", "farmStarFailCount =", _farmStarFailCount, "baodiLookupDiffAvg =", baodiLookupDiffAvg, "baodiConfig =", tts(baodiConfig), "_enableFarmStarBaoDi =", _enableFarmStarBaoDi) end

        if _enableFarmStarBaoDi and baodiConfig.diffAvg and baodiConfig.diffAvg < desiredDiffAvgFix then
            desiredDiffAvgFix = baodiConfig.diffAvg
        end
    end

    return { 
                desiredDiffAvgFix1 = desiredDiffAvgFix1,
                desiredDiffAvgFix2 = desiredDiffAvgFix2,
                desiredDiffAvgFix = desiredDiffAvgFix, 
                calculateDiffIndexResult = _resultData 
            }
end

local _log_flag_1 = false
local _log_flag_2 = false

function UBFuuuSelectAdjust:__getFixedTargetAvg( adjustContext )

    local _levelId = nil
    if adjustContext and adjustContext.levelId then
        _levelId = adjustContext.levelId
    end

    if not (adjustContext and adjustContext.ubfuuuStatisticInfo and adjustContext.ubfuuuStatisticInfo.fixedPlayCount) then
        local UBFuuuAdjustManager = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuAdjustManager"
        UBFuuuAdjustManager:updateAdjustContextData()
        if not _log_flag_1 then
            he_log_error("UBFuuuSelectAdjust_ubfuuuStatisticInfo_is_nil_levelId_" .. tostring(_levelId) )
            _log_flag_1 = true
        end
        return nil
    end

    if adjustContext.desiredDiffAvg and adjustContext.desiredDiffAvg < 1 then
        if not _log_flag_2 then
            he_log_error("UBFuuuSelectAdjust_desiredDiffAvg_out_range_levelId_" .. tostring(_levelId))
            _log_flag_2 = true
        end
        return nil
    end

    local _result = self:__getDesiredDiffAvgFix( adjustContext )
    
    _result.desiredDiffAvg = adjustContext.desiredDiffAvg
    
    _result.fixedDesiredDiffAvg = _result.desiredDiffAvgFix    

    if adjustContext.adjustFixInfo and adjustContext.adjustFixInfo[UBFuuuFixType.kFixedDesiredDiffAvg] then
        for k,v in ipairs(adjustContext.adjustFixInfo[UBFuuuFixType.kFixedDesiredDiffAvg]) do
            _result.fixedDesiredDiffAvg = self:changeValueByAdjustFixInfo(adjustContext, v, _result.fixedDesiredDiffAvg)
        end
        if _result.fixedDesiredDiffAvg < 1 then _result.fixedDesiredDiffAvg = 1 end
    end

    return _result
end

function UBFuuuSelectAdjust:saveTopLevelLastPLayDiffIndex( diffIndex )

    local UBFuuuAdjustManager = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuAdjustManager"
    
    local ubfuuuStatisticInfo = UBFuuuAdjustManager:getAdjustContextData()
    ubfuuuStatisticInfo.topLevelLastPLayDiffIndex = diffIndex

    UBFuuuAdjustManager:setAdjustContextData(ubfuuuStatisticInfo)

end

function UBFuuuSelectAdjust:updateBaoDi( ubfuuCheckResult )

    local UBFuuuAdjustManager = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuAdjustManager"

    local ubfuuuStatisticInfo = UBFuuuAdjustManager:getAdjustContextData()

    if ubfuuuStatisticInfo.toplevelBaoDiFlag ~= ubfuuCheckResult.toplevelBaoDiFlag or ubfuuuStatisticInfo.toplevelBaoDiLevel ~= ubfuuCheckResult.toplevelBaoDiLevel then
        ubfuuuStatisticInfo.toplevelBaoDiFlag = ubfuuCheckResult.toplevelBaoDiFlag
        ubfuuuStatisticInfo.toplevelBaoDiLevel = ubfuuCheckResult.toplevelBaoDiLevel
    end

    UBFuuuAdjustManager:setAdjustContextData(ubfuuuStatisticInfo)
end

function UBFuuuSelectAdjust:checkAdjustStrategy( adjustContext )
    
    -- local desiredDiffAvgFix = self:__getDesiredDiffAvgFix( adjustContext ).desiredDiffAvgFix
    if not adjustContext then return { reason = UbfuuuDisableReason.kAdjustContextIsNil } end

    if not (adjustContext.ubfuuuStatisticInfo and adjustContext.ubfuuuStatisticInfo.dailyPlayCountList) then
        return { reason = UbfuuuDisableReason.kUbfuuuStatisticInfoIsNil }
    end

    local _result = self:__getFixedTargetAvg( adjustContext ) 

    if not _result then
        return {reason = UbfuuuDisableReason.kDesiredDiffAvgInvalid2}
    end

    local fixedDesiredDiffAvg = _result.fixedDesiredDiffAvg
    local calculateDiffIndexResult = _result.calculateDiffIndexResult

    local selectedDiffFix = nil

    local levelId = adjustContext.levelId
    local levelScene = adjustContext.levelScene
    local maxLevelId = adjustContext.maxLevelId
    local isTopLevel = levelId > maxLevelId - adjustContext.topRangeLength
    
    local _tarAvg = nil
    local feedbackResult = nil
    local feedbackResult_stepFix = nil

    local adjustFixInfo = adjustContext.adjustFixInfo
    
    if fixedDesiredDiffAvg and fixedDesiredDiffAvg > 0 then

        local UBFuuuSelfFeedback = require("ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuSelfFeedback")

        local _poolKey = nil
        if adjustContext.adjustFixInfo and adjustContext.adjustFixInfo[UBFuuuFixType.kSelfFeedbackPoolkey] then
            _poolKey = adjustContext.adjustFixInfo[UBFuuuFixType.kSelfFeedbackPoolkey].selectKey
        end
        feedbackResult = UBFuuuSelfFeedback:findDiffFixByDesiredDiff(
                                                                        levelId, 
                                                                        fixedDesiredDiffAvg, 
                                                                        {
                                                                            usedPreAddStep = 0, 
                                                                            isTopLevelRange = isTopLevel,
                                                                            poolkey = _poolKey,
                                                                        },
                                                                        levelScene
                                                                    )
        selectedDiffFix = feedbackResult.diffFix
    end

    if ( not feedbackResult.diffFix ) and feedbackResult.failReason then
        return { reason = feedbackResult.failReason }
    end
    
    local diffFix1 = selectedDiffFix

    if selectedDiffFix then

        if adjustFixInfo and adjustFixInfo[UBFuuuFixType.kDiffFix] then
            for k,v in ipairs(adjustFixInfo[UBFuuuFixType.kDiffFix]) do
                selectedDiffFix = self:changeValueByAdjustFixInfo(adjustContext, v, selectedDiffFix)
            end
        end

        if selectedDiffFix > maxDiffFix then selectedDiffFix = maxDiffFix end
        if selectedDiffFix < minDiffFix then selectedDiffFix = minDiffFix end
    end

    -- if not selectedDiffFix then
    --     selectedDiffFix = 0
    -- end
    _result.diffFix1 = diffFix1
    _result.diffFix = selectedDiffFix

    _result.stepFixEnable = false
    _result.stepFix = nil
    _result.desiredStep = nil

    if adjustFixInfo then
        if adjustFixInfo[UBFuuuFixType.kDesiredStep] then
            if not _result.desiredStep then _result.desiredStep = 0 end
            
            for k,v in ipairs(adjustFixInfo[UBFuuuFixType.kDesiredStep]) do
                _result.desiredStep = self:changeValueByAdjustFixInfo(adjustContext, v, _result.desiredStep)
            end
        end
    end

    --
--
--
--
--
--


    if _result.desiredStep then
        local UBFuuuSelfFeedback = require("ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuSelfFeedback")
        feedbackResult_stepFix = UBFuuuSelfFeedback:findStepFixByDesiredStep(
                                                                    levelId, 
                                                                    _result.desiredStep, 
                                                                    {
                                                                        usedPreAddStep = 0, 
                                                                        isTopLevelRange = isTopLevel,
                                                                        poolKey = _poolKey,
                                                                    },
                                                                    levelScene
                                                                )
        _result.stepFix = feedbackResult_stepFix.stepFix

        if self.debugMode then printx(1, "UBFuuuSelectAdjust:checkAdjustStrategy  findStepFixByDesiredStep  desiredStep: ", _result.desiredStep, " feedbackResult_stepFix: ", tts(feedbackResult_stepFix)) end

    end

    if adjustFixInfo then
        if adjustFixInfo[UBFuuuFixType.kStepFix] then
            if not _result.stepFix then _result.stepFix = 1 end
            
            for k,v in ipairs(adjustFixInfo[UBFuuuFixType.kStepFix]) do
                _result.stepFix = self:changeValueByAdjustFixInfo(adjustContext, v, _result.stepFix)
            end
        end
    end

    --
--
--
--
--
--


    if _result.stepFix then
        _result.stepFixEnable = true
    end
    -- _result.stepFixEnable = true
    -- _result.desiredStep = 0
    -- _result.stepFix = 2
    
    return { diffFix = _result.diffFix , diffFix1 = diffFix1, checkResult = _result, feedbackResult = feedbackResult }
end



return UBFuuuSelectAdjust
