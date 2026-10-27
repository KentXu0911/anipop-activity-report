local UBFuuuAdjustManager = {}
UBFuuuAdjustManager.adjustContextIniteState = 0

--[[
user

参数
返回
String ubfuuuTop30FinishedInfo 最高30关采集的完成情况

示例：{"8888,exp,expGroup":"-10,-9,1,2,3"}
String ubfuuuLevelDiffFixMap 返回的难度信息

示例
{
    "8888,exp,expGroup": {
        "-10": "3.333_2.333_1.111_-1", // 总难度_最近300次难度_最近1000次难度_最近10000次难度 -1表示没算出来
        "-9": "3.333_2.333_1.111_-1"
    },
    ...
}

passLevel / cancelCrashResumePanel 协议返回
参数
新结构体 ubFuuuCollectMeta
UBFuuuCollectMeta {
    /**
     * 前置道具步数
     */
    int preAddSteps;
    /**
     * 关卡内道具步数
     */
    int addSteps;
    int diffFix;//难度修正
    int payTag;//付费标签
    int actTag;//活跃标签
}
闪退不恢复需补上 List<GroupExpLevelRequestBean> groupExpLevelRequestList

ubfuuuGetNext30DiffFixData
参数
List<String> levelKeys
返回
String ubfuuuLevelDiffFixMap

{
        "8888,exp,expGroup": {
                "-1": {
                        "diff_300": 2.0,
                        "diff_all": 2.0,
                        "diff_1000": 2.0,
                        "diff_10000": 2.0
                },
                "-2": {
                        "diff_300": 1.8571428571428573,
                        "diff_all": 1.8571428571428573,
                        "diff_1000": 1.8571428571428573,
                        "diff_10000": 1.8571428571428573
                },
                "-3": {
                        "diff_300": 2.8,
                        "diff_all": 2.8,
                        "diff_1000": 2.8,
                        "diff_10000": 2.8
                },
            }
}

]]
local _selfFeedbackVer = 3

local _collectFlagMap = nil
local _diff_ds_Map = nil
local _diff_ds_update_Map = nil

local _step_ds_Map = nil

local _UBFuuuContextFileName = "ubfuuu_contextData"
local _lastAdjustResultFileName = "ubfuuu_lastResult"

local _diff_ds_MapFileName = "ubfuuu_diff_ds_Map"
local _diff_ds_update_MapFileName = "ubfuuu_diff_ds_update_Map"

local _step_ds_MapFileName = "ubfuuu_step_ds_Map"

-- 刷星保底：按 levelId 维护的失败次数（服务端下发为长期权威，本地结算先写乐观值）
local _farm_star_fail_count_mapFileName = "ubfuuu_farm_star_fail_count_map"
local _farm_star_fail_count_maxKeep = 500
local _farm_star_fail_count_expireTime = 3600 * 24 * 30      -- 本地冷数据窗口，独立于 diff 映射的 4 天离线窗口
local _max_level_star = 4                                    -- 主线满星（彩星）档位，达到即视为刷分
-- 刷星保底：服务端下发字段名（对齐服务端 proto：UBFuuuGetNext30DiffFixDataResponseBean.ubfuuuLevelFarmStarFailCountMap = 3）
local _farmStarFailCountFieldName = "ubfuuuLevelFarmStarFailCountMap"
local _farm_star_fail_Map = nil

local _debug = false
local _validityTime = 1800
local _validityTime_Top30_to_60 = 120
local _validityTime_Top30 = 1
local _validityTime_offline = 3600 * 24 * 4 --离线状态，映射表只生效四天

local ExpMaintenanceName = "UBFuuu2024"

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


function UBFuuuAdjustManager:getSelfFeedbackVer()
    return _selfFeedbackVer
end

function UBFuuuAdjustManager:init()
    require("ubf.UBF.utils.UBFCommonRequire")("*")
    _G.amfEC:registerNormal(NormalEvent.USER_LOGIN, function (evt)
        self:onGameLaunch()
    end)

    self:onGameLaunch()
end

function UBFuuuAdjustManager:timeInSec()
    return TimeKit:timeInSec()
end

function UBFuuuAdjustManager:saveData(data, fileName)

    local _uid = _G.amfBean("ProfileManager"):getUid()

    local fObj = LocalDB:createFileObject(fileName .. "_" .. tostring(_uid))
    fObj:setContent(data)
    fObj:save()
end

function UBFuuuAdjustManager:loadData(fileName)

    local _uid = _G.amfBean("ProfileManager"):getUid()

    local fObj = LocalDB:createFileObject(fileName .. "_" .. tostring(_uid))

    if not (fObj and fObj:getContent()) then
        if tonumber( self:timeInSec() ) < 1746006420 then
            fObj = LocalDB:createFileObject(fileName)
        end
    end

    return ( fObj and fObj:getContent() ) or {}
end

function UBFuuuAdjustManager:injectUser( userRequestBody, offlineMode )
    -- UserManager:getInstance():getUserRef():getTopLevelId()
    local topLevelId = userRequestBody._topLevelId


    if not topLevelId then
        he_log_error("UBFuuuAdjustManager_injectUser_topLevelId_is_nil")
        --
--
--
--
--
--
--

        return
    end

    local levelGroupConfig = UBFLevelConfigManager:getLevelGroupConfig()
    local levelkeys = {}
    local usePreAddStep = 0
    
    if not _G.SelfFeedbackPoolkey then --UBFPlayConst.lua 加载顺序有问题, to be fix next
        require("ubf.UBFPlay.declares.SelfFeedbackPoolkey")
    end
    
    for k,v in ipairs(levelGroupConfig.rules) do     
        local _arr = string.split(v.group, ":")
        -- local _key = string.format("%s,%s,%s,%s,%s", tostring(topLevelId), _arr[1] or "default", _arr[2] or "default", usePreAddStep, self:getSelfFeedbackVer())
        local _key = self:createLevelKey( tostring(topLevelId), _arr[1] or "default", _arr[2] or "default", usePreAddStep, self:getSelfFeedbackVer())
        table.insert(levelkeys, _key)

        local _key2 = self:createLevelKey( tostring(topLevelId), _arr[1] or "default", _arr[2] or "default", usePreAddStep, self:getSelfFeedbackVer(), {poolkey = _G.SelfFeedbackPoolkey.kSuperBird} )
        table.insert(levelkeys, _key2)

        local _key3 = self:createLevelKey( tostring(topLevelId), _arr[1] or "default", _arr[2] or "default", usePreAddStep, self:getSelfFeedbackVer(), {poolkey = _G.SelfFeedbackPoolkey.kRUST} )
        table.insert(levelkeys, _key3)
    end
    
    -- local UBFuuuSelectAdjust = require("ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuSelectAdjust")
    -- local switchInfos = UBFuuuSelectAdjust:createSwitchInfos(true)
    -- local configGroup = UBFuuuSelectAdjust:createConfigGroupMap(switchInfos.cfgGroup, switchInfos.CAGroup)

    local ubfuuuInfo = {}
    ubfuuuInfo.maxLevelId =  UBFLevelRangeUtil:getMaxLevelForAdjust()
    ubfuuuInfo.topRangeLength = UBFLevelRangeUtil:getTopLevelRangeLength() or 30
    ubfuuuInfo.secTopRangeLength = UBFLevelRangeUtil:getSecTopLevelRangeLength()
    
    ubfuuuInfo.diffDsMapKeys = levelkeys
    

    if _debug then printx(1, "UBFuuuAdjustManager:injectUser  ubfuuuInfo ----- " , tts(ubfuuuInfo)  ) end

    userRequestBody.ubfuuuInfo = ubfuuuInfo
end

function UBFuuuAdjustManager:createLevelKey( levelId, exp, group, preProp, ver, datas, levelScene )

    local _preProp = 0
    -- 看代码，这个dsMap只会在Main生效，所以没必要levelScene，不过这里暂时传入一下，让后面好接入
    local levelScene = levelScene or UBFLevelIdUtil:tryGetCurrLevelScene() or UBFLevelSceneType.kMain
    -- if preProp and preProp > 0 then
    --     _preProp = 1
    -- end

    local _str = string.format("%s,%s,%s,%s,%s", tostring(levelId), exp or "default", group or "default", _preProp, ver or 1) 
    
    if datas then
        if datas.poolkey == _G.SelfFeedbackPoolkey.kSuperBird then 
            _str = _str .. "," .. tostring(100)
        elseif datas.poolkey == _G.SelfFeedbackPoolkey.kRUST then 
            _str = _str .. "," .. tostring(200)
        elseif datas.poolkey == _G.SelfFeedbackPoolkey.kRUST_bird then 
            _str = _str .. "," .. tostring(201)
        end
    end

    return _str
end

function UBFuuuAdjustManager:_registerEvents()
    if self._eventsRegistered then
        return
    end
    self._eventsRegistered = true

    _G.amfEC:registerNormal(NormalEvent.PASS_DAY,  self.onActPassDay, self)
    _G.amfEC:registerNormal(NormalEvent.GLOBAL_WINNING_STREAK_INCREASED, self._onGlobalStreakIncreased, self)
    _G.amfEC:registerNormal(NormalEvent.GLOBAL_WINNING_STREAK_BROKEN, self._onGlobalStreakBroken, self)
end

function UBFuuuAdjustManager:_onGlobalStreakIncreased()
    local contextData = self:getAdjustContextData() or {}
    contextData.todayStreakWinCount = (contextData.todayStreakWinCount or 0) + 1
    self:setAdjustContextData(contextData)
end

function UBFuuuAdjustManager:_onGlobalStreakBroken()
    local contextData = self:getAdjustContextData() or {}
    contextData.todayStreakWinBreakCount = (contextData.todayStreakWinBreakCount or 0) + 1
    contextData.todayStreakWinCount = 0
    self:setAdjustContextData(contextData)
end

function UBFuuuAdjustManager:onGameLaunch( userResp )

    self:_registerEvents()

    local UBFuuuLevelTargetAvg = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuLevelTargetAvg"
    UBFuuuLevelTargetAvg:initByMetaConfig()
    

    local userData = UserManager:getInstance():getUserRef()
	local topLevel = userData:getTopLevelId()

    local ubfuuuInfo = nil
    
    ubfuuuInfo = _G.amfBean("LevelAdjustManger"):getDataValue("ubfuuuInfo")

    -- printx(1,"FUCKKKKKKKKKKKKKKKKKK userResp.ubfuuuTop30FinishedInfo =",userResp.ubfuuuTop30FinishedInfo, type(userResp.ubfuuuTop30FinishedInfo))

    if ubfuuuInfo then

        if _debug then printx(1, "UBFuuuAdjustManager:onGameLaunch  userResp.ubfuuuInfo = " , tts(ubfuuuInfo)  ) end

        if ubfuuuInfo.statisticInfo then
            self:onUpdateAdjustContextData( ubfuuuInfo.statisticInfo )
        end

        if ubfuuuInfo.diffDsMap then
            if ubfuuuInfo.diffDsMap.ubfuuuLevelDiffFixMap then
                self:onUpdateDiffDsMap( table.deserialize(ubfuuuInfo.diffDsMap.ubfuuuLevelDiffFixMap) )
            end
            if ubfuuuInfo.diffDsMap[_farmStarFailCountFieldName] then
                self:onUpdateFarmStarFailCountMap( ubfuuuInfo.diffDsMap[_farmStarFailCountFieldName] )
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

    else
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

    end

    local _now = self:timeInSec()

    local function claenLocalData( configKey, configData )

        if not configData then
            configData = self:loadData( configKey ) or {}
        end

        local _needRemoveKeys = {}
        for k,v in pairs(configData) do
            if type(v) == "number" then
                if _now - v > _validityTime_offline then
                    table.insert( _needRemoveKeys, k )
                end
            else
                if (not v.updateTime) or _now - v.updateTime > _validityTime_offline then
                    table.insert( _needRemoveKeys, k )
                end
            end
        end

        if #_needRemoveKeys > 0 then --登录时尝试清理冷数据
            for k2,v2 in ipairs(_needRemoveKeys) do
                configData[v2] = nil
            end
            self:saveData( configData, configKey )
        end

        return configData
    end

    _diff_ds_Map = claenLocalData(_diff_ds_MapFileName, _diff_ds_Map)
    _step_ds_Map = claenLocalData(_step_ds_MapFileName, _step_ds_Map)
    _diff_ds_update_Map = claenLocalData(_diff_ds_update_MapFileName, _diff_ds_update_Map)

    if _debug then printx(1, "UBFuuuAdjustManager:onGameLaunch  _diff_ds_update_Map ----- " , tts(_diff_ds_update_Map)  ) end

    self:checkUpdateTop30DiffDsMap(topLevel)
    self.topLevelWhenLogin = topLevel
    self:updateAdjustContextData()
    -- debug.debug()
end

function UBFuuuAdjustManager:checkUpdateTop30DiffDsMap(topLevel, levelScene)

    
    local maxCanPlayLevel = UBFLevelRangeUtil:getCanPlayTopLevel()

    -- printx(1,"FUCKKKKKKKKKKKKKKKKKK   topLevel =",topLevel)
    -- printx(1,"FUCKKKKKKKKKKKKKKKKKK   maxCanPlayLevel =",maxCanPlayLevel)
    if not _diff_ds_update_Map then
        _diff_ds_update_Map = self:loadData( _diff_ds_update_MapFileName ) or {}
    end

    local _maxLevel = UBFLevelRangeUtil:getMaxLevelForAdjust()
    local _vTime = _validityTime
    if topLevel >= _maxLevel - 29 then 
        _vTime = _validityTime_Top30
    elseif topLevel >= _maxLevel - 89 then 
        --Top30 ~ Top 60
        _vTime = _validityTime_Top30_to_60
    end

    local levelIds = {}
    for _level = topLevel, topLevel+29 do

        if _level <= maxCanPlayLevel then
            local _time = _diff_ds_update_Map[tostring(_level)]
            if not _time then
                table.insert(levelIds, _level)
            elseif self:timeInSec() - _time > _vTime then
            -- elseif self:timeInSec() - _time > 3600 * 4 then
                table.insert(levelIds, _level)
            end
        end
    end

    self:updateDiffDsMap(levelIds, nil, levelScene)
end

function UBFuuuAdjustManager:checkUpdateDiffDsMapByLevelId(levelId, levelScene)

    if not levelId then return end

    if not UBFLevelRangeUtil:isMainLevel(levelId, levelScene) then
        return
    end
    

    local _vTime = _validityTime
    local _maxLevel = UBFLevelRangeUtil:getMaxLevelForAdjust()

    if levelId >= _maxLevel - 29 then 
        _vTime = _validityTime_Top30
    elseif levelId >= _maxLevel - 89 then 
        --Top30 ~ Top 60
        _vTime = _validityTime_Top30_to_60
    end

    if not _diff_ds_update_Map then
        _diff_ds_update_Map = self:loadData( _diff_ds_update_MapFileName ) or {}
    end

    local function checkNeedUpdate(lv)
        local _time = _diff_ds_update_Map[tostring(lv)]
        if (not _time) or (self:timeInSec() - _time > _vTime) then
            return lv
        end
        return nil
    end

    local _list = {}
    if checkNeedUpdate(levelId) then
        table.insert(_list, levelId)
    end

    local maxCanPlayLevel = UBFLevelRangeUtil:getCanPlayTopLevel() or 0
    
    if not self.topLevelWhenLogin then
        local userData = UserManager:getInstance():getUserRef()
	    local topLevel = userData:getTopLevelId()
        self.topLevelWhenLogin = topLevel
    end
    
    if levelId >= self.topLevelWhenLogin and levelId + 30 <= maxCanPlayLevel then
        if checkNeedUpdate(levelId + 30) then
            table.insert(_list, levelId + 30)
        end
    end
    
    self:updateDiffDsMap(_list, nil, levelScene)
end

function UBFuuuAdjustManager:onUpdateDiffDsMap( diffDatas )
    
    -- if _debug then printx( 1 , "UBFuuuAdjustManager:onUpdateDiffDsMap " , debug.traceback() ) end
    -- if _debug then printx( 1 , "UBFuuuAdjustManager:onUpdateDiffDsMap --------- diffDatas =" , tts(diffDatas) ) end

    if not _diff_ds_update_Map then
        _diff_ds_update_Map = self:loadData( _diff_ds_update_MapFileName ) or {}
    end

    if not _diff_ds_Map then
        _diff_ds_Map = self:loadData( _diff_ds_MapFileName ) or {}
    end

    local _new_dataMap = {}
    local _now = self:timeInSec()

    for levelKey, v in pairs(diffDatas) do

        local _levelinfo = string.split(levelKey, ",")
        local _levelId = tonumber(_levelinfo[1])
        local _levelExp = _levelinfo[2]
        local _levelGroup = _levelinfo[3]
        local _useAddStep = tonumber(_levelinfo[4])
        local _ver = tonumber(_levelinfo[5])

        local _levelDataMap = _diff_ds_Map[levelKey] or {}
        _levelDataMap.updateTime = _now
        _diff_ds_update_Map[tostring(_levelId)] = _now

        -- if _debug and _levelId == 10028 then printx( 1 , "UBFuuuAdjustManager:onUpdateDiffDsMap --------- _levelId =" , _levelId, levelKey ) end

        for diffFix, v2 in pairs(v) do
            local _diffData = _levelDataMap[tostring(diffFix)] or {}
            local _arr = string.split(v2, ",")
            local _old_diff_all = _diffData.diff_all

            _diffData.diff_all = tonumber(_arr[1])
            _diffData.diff_300 = tonumber(_arr[2])
            _diffData.diff_1000 = tonumber(_arr[3])
            _diffData.diff_10000 = tonumber(_arr[4])

            _diffData.levelId = _levelId
            _diffData.levelExp = _levelExp
            _diffData.levelGroup = _levelGroup
            _diffData.useAddStep = _useAddStep
            _diffData.ver = _ver

            -- if _debug and _levelId == 10028 then printx( 1 , "UBFuuuAdjustManager:onUpdateDiffDsMap --------- +++++++++++ diffFix =" , diffFix , tostring(_diffData.diff_all),tostring(_diffData.diff_300),tostring(_diffData.diff_1000),tostring(_diffData.diff_10000) ) end

            if _old_diff_all and _old_diff_all > 0 then

                if _diffData.changeRateUpdateTime then
                    if _now - _diffData.changeRateUpdateTime > 3600 * 24 then
                        _diffData.oldDiff = _old_diff_all
                        _diffData.changeRate = math.abs(_diffData.diff_all - _old_diff_all) / _old_diff_all
                        _diffData.changeRateUpdateTime = _now
                    else
                        local _rate = math.abs(_diffData.diff_all - _old_diff_all) / _old_diff_all
                        if _diffData.changeRate and _rate > _diffData.changeRate then
                            _diffData.changeRate = _rate
                        end
                    end
                else
                    _diffData.oldDiff = _old_diff_all
                    _diffData.changeRate = math.abs(_diffData.diff_all - _old_diff_all) / _old_diff_all
                    _diffData.changeRateUpdateTime = _now
                end
            else
                _diffData.oldDiff = _diffData.diff_all
                _diffData.changeRate = 0
                _diffData.changeRateUpdateTime = _now
            end

            _levelDataMap[tostring(diffFix)] = _diffData
        end 

        _diff_ds_Map[levelKey] = _levelDataMap
    end

    self:saveData( _diff_ds_Map, _diff_ds_MapFileName )
    self:saveData( _diff_ds_update_Map, _diff_ds_update_MapFileName )

    if _debug then printx( 1 , "UBFuuuAdjustManager:onUpdateDiffDsMap --------- _diff_ds_update_Map =" , tts(_diff_ds_update_Map) ) end
    -- if _debug then printx( 1 , "UBFuuuAdjustManager:onUpdateDiffDsMap --------- _diff_ds_Map =" , tts(_diff_ds_Map) ) end
end

function UBFuuuAdjustManager:onUpdateStepDsMap(stepDatas)
    
    if not _step_ds_Map then
        _step_ds_Map = self:loadData( _step_ds_MapFileName ) or {}
    end

    for levelKey, v in pairs(stepDatas) do
        
        local _data = {}
        _data.updateTime = self:timeInSec()

        local _levelinfo = string.split(levelKey, ",")
        local _levelId = tonumber(_levelinfo[1])
        local _levelExp = _levelinfo[2]
        local _levelGroup = _levelinfo[3]
        local _useAddStep = tonumber(_levelinfo[4])
        local _ver = tonumber(_levelinfo[5])

        _step_ds_Map[levelKey] = _data

        for stepFix, v2 in pairs(v) do
            local _stepData = {}

            _data[tostring(stepFix)] = _stepData

            _stepData.step = tonumber(v2)

            _stepData.levelId = _levelId
            _stepData.levelExp = _levelExp
            _stepData.levelGroup = _levelGroup
            _stepData.useAddStep = _useAddStep
            _stepData.ver = _ver
        end 
    end

    self:saveData( _step_ds_Map, _step_ds_MapFileName )

    -- if _debug then printx( 1 , "UBFuuuAdjustManager:onUpdateStepDsMap --------- _step_ds_Map =" , tts(_step_ds_Map) ) end

end

function UBFuuuAdjustManager:_updateDiffDsMap(levelKeys, callback)
    local getUBFuuuDsToDiffMapHttp = require("ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.GetUBFuuuDsToDiffMapHttp")
    getUBFuuuDsToDiffMapHttp:post({levelKeys = levelKeys}):next(

        function ( response )
            -- printx( 1 , "UBFuuuAdjustManager:onUpdateDiffDsMap --------- evt.data.ubfuuuLevelDiffFixMap =" ,evt.data.ubfuuuLevelDiffFixMap )

            local data = response:getData()
            if data then

                if data.ubfuuuLevelDiffFixMap then
                    self:onUpdateDiffDsMap( table.deserialize(data.ubfuuuLevelDiffFixMap) )
                end

                if data.ubfuuuLevelStepFixMap then
                    self:onUpdateStepDsMap( table.deserialize(data.ubfuuuLevelStepFixMap) )
                end

                if data[_farmStarFailCountFieldName] then
                    self:onUpdateFarmStarFailCountMap( data[_farmStarFailCountFieldName] )
                end
                
                if callback then callback(true) end
            else
                if callback then callback(false) end
            end
        end,

        function ( response )
            -- body
            if callback then callback(false) end
        end
    )
end

function UBFuuuAdjustManager:updateDiffDsMap( levelIds, callback, levelScene)
    --ubfuuuLevelDiffFixMap

    if not levelIds then return end
    if #levelIds == 0 then return end
    levelScene = levelScene or UBFLevelSceneType.kMain

    local levelKeys = {}
    
    for k,levelId in ipairs(levelIds) do
        
        -- local levelGroup = UBFPlaySwitch:getLevelGroup(levelId, levelScene)
        -- local ret, meetGroup, uuid = UBFLevelConfigManager:traversalDefault(levelGroup, levelId)
        local levelKeyData = UBFLevelIdUtil:createLevelKeyDataWithAutoLevelGroup(levelId, levelScene)
        local ret, meetGroup, uuid = levelKeyData:fallback()

        local usePreProp = 1
        local notUsePreProp = 0

        if meetGroup then

            local _arr = string.split(meetGroup, ":")
            local datas = {}
            
            local levelKey1 = self:createLevelKey( tostring(levelId), _arr[1] or "default", _arr[2] or "default", notUsePreProp, _selfFeedbackVer, datas, levelScene )
            table.insert(levelKeys, levelKey1)

            local levelKey2 = self:createLevelKey( tostring(levelId), _arr[1] or "default", _arr[2] or "default", notUsePreProp, _selfFeedbackVer, {poolkey = _G.SelfFeedbackPoolkey.kSuperBird}, levelScene )
            table.insert(levelKeys, levelKey2)

            local levelKey3 = self:createLevelKey( tostring(levelId), _arr[1] or "default", _arr[2] or "default", notUsePreProp, _selfFeedbackVer, {poolkey = _G.SelfFeedbackPoolkey.kRUST}, levelScene )
            table.insert(levelKeys, levelKey3)

            -- local levelKey2 = self:createLevelKey( tostring(levelId), _arr[1] or "default", _arr[2] or "default", usePreProp, _selfFeedbackVer, datas )
            -- table.insert(levelKeys, levelKey2)
        end
        
    end
    if _debug then printx( 1 , "UBFuuuAdjustManager:updateDiffDsMap --------- levelKeys =" , tts(levelKeys) ) end
    -- debug.debug()

    if #levelKeys > 0 then
        self:_updateDiffDsMap(levelKeys, callback)
    end
end

function UBFuuuAdjustManager:getDiffDsMap(levelId, usePreAdStep, datas, levelScene)
    -- local levelGroup = UBFPlaySwitch:getLevelGroup(levelId)
    -- local ret, meetGroup, uuid = UBFLevelConfigManager:traversalDefault(levelGroup, levelId)
    local levelKeyData = UBFLevelIdUtil:createLevelKeyDataWithAutoLevelGroup(levelId, levelScene)
    local ret, meetGroup, uuid = levelKeyData:fallback()
    local _arr = string.split(meetGroup, ":")
    local levelKey = self:createLevelKey( tostring(levelId), _arr[1], _arr[2] or "default", usePreAdStep, _selfFeedbackVer, datas, levelScene )

    if not _diff_ds_Map then
        _diff_ds_Map = self:loadData( _diff_ds_MapFileName ) or {}
    end

    if _debug then printx( 1 , "UBFuuuAdjustManager:getDiffDsMap --------- levelKey =" , levelKey , _diff_ds_Map[levelKey] ) end

    return _diff_ds_Map[levelKey]
end

function UBFuuuAdjustManager:getStepDsMap(levelId, usePreAdStep, datas, levelScene)
    -- local levelGroup = UBFPlaySwitch:getLevelGroup(levelId)
    -- local ret, meetGroup, uuid = UBFLevelConfigManager:traversalDefault(levelGroup, levelId)
    local levelKeyData = UBFLevelIdUtil:createLevelKeyDataWithAutoLevelGroup(levelId, levelScene)
    local ret, meetGroup, uuid = levelKeyData:fallback()
    local _arr = string.split(meetGroup, ":")
    local levelKey = self:createLevelKey( tostring(levelId), _arr[1], _arr[2] or "default", usePreAdStep, _selfFeedbackVer, datas, levelScene )

    if not _step_ds_Map then
        _step_ds_Map = self:loadData( _step_ds_MapFileName ) or {}
    end

    if _debug then printx( 1 , "UBFuuuAdjustManager:getStepDsMap --------- levelKey =" , levelKey ) end

    return _step_ds_Map[levelKey]
end

------------------------------------------------
-- 刷星保底：失败次数本地缓存 / 服务端合并
------------------------------------------------

local function _farmStarLevelKey(levelId)
    if levelId == nil then return nil end
    return tostring(levelId)
end

-- 解析服务端下发的刷星失败次数（JSON 字符串或 table），非法值按缺失处理
function UBFuuuAdjustManager:parseFarmStarFailCountMap(rawData)
    local _raw = rawData
    if type(_raw) == "string" then
        if _raw == "" then return {} end
        local _parsed = table.deserialize(_raw)
        if type(_parsed) ~= "table" then
            he_log_error("UBFuuuAdjustManager_parseFarmStarFailCountMap_deserialize_fail")
            return {}
        end
        _raw = _parsed
    end

    if type(_raw) ~= "table" then return {} end

    local _map = {}
    for k, v in pairs(_raw) do
        local _levelId = tonumber(k)
        local _count = tonumber(v)
        if _levelId and _levelId > 0 and _count and _count >= 0 and _count == math.floor(_count) then
            _map[tostring(_levelId)] = _count
        else
            he_log_error("UBFuuuAdjustManager_parseFarmStarFailCountMap_invalid k=" .. tostring(k) .. " v=" .. tostring(v))
        end
    end
    return _map
end

function UBFuuuAdjustManager:getFarmStarFailCountMap()
    if not _farm_star_fail_Map then
        _farm_star_fail_Map = self:loadData( _farm_star_fail_count_mapFileName ) or {}
    end
    return _farm_star_fail_Map
end

-- 进关决策使用的失败次数（进关时快照）
function UBFuuuAdjustManager:getFarmStarFailCount(levelId)
    local _key = _farmStarLevelKey(levelId)
    if not _key then return 0 end

    local _map = self:getFarmStarFailCountMap()
    local _data = _map[_key]
    local _count = (type(_data) == "table" and tonumber(_data.count)) or 0
    if _count < 0 then _count = 0 end
    return _count
end

-- 纯函数（可单测）：根据结算 runtime 的最终状态决定刷星计数动作
-- state = { isWin, star, oldStar, failReason }
-- 刷星口径与决策侧一致：只看星级数（首闯 0 星、满星刷分不参与），不依赖关卡类型字段
-- 返回 "reset"（升星清零）/ "increment"（未升星正常完成）/ nil（不更新）
function UBFuuuAdjustManager.resolveFarmStarResultAction(state)
    if type(state) ~= "table" then return nil end

    local _oldStar = tonumber(state.oldStar) or 0
    -- 首闯（0 星）与满星刷分（>= maxLevelStar）不参与刷星计数
    if _oldStar <= 0 or _oldStar >= _max_level_star then return nil end

    local _failReason = state.failReason
    local _failReasonConst = _G.UBFGameFailReason or {}
    -- 中途退出 / 重玩不计入
    if _failReason == _failReasonConst.kDropout or _failReason == _failReasonConst.kRetry then
        return nil
    end

    local _isWin = state.isWin == true
    local _isNormalFail = (not _isWin) and (_failReason == _failReasonConst.kNoLife
        or _failReason == _failReasonConst.kDeadBoard
        or _failReason == _failReasonConst.kStarLack)

    -- 既不是正常过关也不是正常失败（含闪退恢复失败等）：fail-closed
    if (not _isWin) and (not _isNormalFail) then return nil end

    local _star = tonumber(state.star) or 0
    if _isWin and _star > _oldStar then
        return "reset"
    end

    return "increment"
end

-- 结算写入本地乐观值；后续下发同一关时以服务端为准
function UBFuuuAdjustManager:applyFarmStarFailCountResult(levelId, action)
    local _key = _farmStarLevelKey(levelId)
    if not _key then return end

    local _map = self:getFarmStarFailCountMap()
    local _oldData = _map[_key]
    if type(_oldData) ~= "table" then _oldData = {} end

    local _oldCount = tonumber(_oldData.count) or 0
    if _oldCount < 0 then _oldCount = 0 end

    local _count = nil
    if action == "reset" then
        _count = 0
    elseif action == "increment" then
        _count = _oldCount + 1
    else
        return
    end

    local _data = {
        count = _count,
        localRevision = (tonumber(_oldData.localRevision) or 0) + 1,
        updateTime = self:timeInSec(),
    }
    _map[_key] = _data

    self:trimFarmStarFailCountMap(_map)
    self:saveData(_map, _farm_star_fail_count_mapFileName)

    if _debug then printx(1, "UBFuuuAdjustManager:applyFarmStarFailCountResult levelId =", _key, "action =", action, "count =", _data.count) end
end

-- 纯函数（可单测）：服务端下发与本地缓存合并，返回新表
-- 服务端下发该 key 即覆盖；未下发的关卡仍保留本地乐观值
function UBFuuuAdjustManager.mergeFarmStarFailCountMap(localMap, serverMap, nowTime)
    local _result = {}
    for k, v in pairs(localMap or {}) do
        if type(v) == "table" then
            _result[k] = {
                count = v.count,
                localRevision = v.localRevision,
                updateTime = v.updateTime,
            }
        end
    end

    local _now = nowTime or 0
    for k, _serverCount in pairs(serverMap or {}) do
        local _local = _result[k]
        if not _local then
            _result[k] = { count = _serverCount, updateTime = _now }
        else
            _local.count = _serverCount
            _local.updateTime = _now
        end
    end

    return _result
end

-- 冷数据审计：仅当 serverMap 存在（即最近一次服务端下发）时才按 30 天窗口清理
function UBFuuuAdjustManager:auditFarmStarFailCountMap(_map, serverMap)
    local _now = self:timeInSec()
    local _changed = false

    for k, v in pairs(_map or {}) do
        if type(v) ~= "table" then
            _map[k] = nil
            _changed = true
        else
            if v.pending ~= nil or v.pendingAction ~= nil or v.pendingPlayId ~= nil then
                v.pending, v.pendingAction, v.pendingPlayId = nil, nil, nil
                _changed = true
            end
            if not v.updateTime then
                v.updateTime = _now
                _changed = true
            elseif serverMap and (not serverMap[k]) and (_now - v.updateTime > _farm_star_fail_count_expireTime) then
                _map[k] = nil
                _changed = true
            end
        end
    end

    return _changed
end

function UBFuuuAdjustManager:trimFarmStarFailCountMap(_map)
    local _total = 0
    for _ in pairs(_map or {}) do _total = _total + 1 end
    if _total <= _farm_star_fail_count_maxKeep then return false end

    local _candidates = {}
    for k, v in pairs(_map) do
        table.insert(_candidates, { key = k, time = (type(v) == "table" and v.updateTime) or 0 })
    end
    table.sort(_candidates, function(a, b) return a.time < b.time end)

    local _needRemove = _total - _farm_star_fail_count_maxKeep
    for i = 1, math.min(_needRemove, #_candidates) do
        _map[_candidates[i].key] = nil
    end

    return true
end

-- 服务端下发入口（登录 diffDsMap 与 ubfuuuGetNext30DiffFixDataV2 共用）
function UBFuuuAdjustManager:onUpdateFarmStarFailCountMap(serverData)
    if serverData == nil then return end

    local _serverMap = self:parseFarmStarFailCountMap(serverData)
    if not next(_serverMap) then return end

    local _map = self:getFarmStarFailCountMap()
    local _merged = UBFuuuAdjustManager.mergeFarmStarFailCountMap(_map, _serverMap, self:timeInSec())
    self:auditFarmStarFailCountMap(_merged, _serverMap)
    self:trimFarmStarFailCountMap(_merged)

    _farm_star_fail_Map = _merged
    self:saveData(_merged, _farm_star_fail_count_mapFileName)

    if _debug then printx(1, "UBFuuuAdjustManager:onUpdateFarmStarFailCountMap serverMap =", tts(_serverMap)) end
end

-- 进关时做一次冷数据审计（含旧版本遗留字段清理）
function UBFuuuAdjustManager:cleanFarmStarFailCountOnStartLevel(ubfSLRuntime)
    local _map = self:getFarmStarFailCountMap()
    local _changed = self:auditFarmStarFailCountMap(_map, nil)
    if self:trimFarmStarFailCountMap(_map) then _changed = true end
    if _changed then
        _farm_star_fail_Map = _map
        self:saveData(_map, _farm_star_fail_count_mapFileName)
    end
end

------------------------------------------------

function UBFuuuAdjustManager:onStartLevel( ubfSLRuntime )

    local levelId = nil
    levelId = ubfSLRuntime.levelId

    if _debug then printx(1 , "UBFuuuAdjustManager:onStartLevel  ", levelId ) end

    self:cleanFarmStarFailCountOnStartLevel(ubfSLRuntime)

    local contextData = self:getAdjustContextData() or {}

    local nowtime = self:timeInSec()
    local nowtimeDay = time2day(nowtime)

    local _needSave = false
    local _doUpdate = false

    local isMainLevel = UBFLevelRangeUtil:isMainLevel(levelId, ubfSLRuntime.levelScene)
    if isMainLevel then

        local areaId = math.floor( (levelId - 1) / 15 )
        if _debug then printx(1 , "UBFuuuAdjustManager:onStartLevel  levelId:", levelId, "areaId:", areaId, "contextData.currAreaId:", contextData.currAreaId ) end

        if not contextData.currAreaId then
            contextData.currAreaId = areaId
            _needSave = true
        else
            if areaId > contextData.currAreaId then
                _doUpdate = true
            end
        end

        local topLevel = nil
        if ubfSLRuntime then
            topLevel = ubfSLRuntime:getUserTopLevel()
        end

        if _debug then printx(1 , "UBFuuuAdjustManager:onStartLevel  topLevel =", topLevel ) end

        if topLevel and topLevel <= 100 then
            _doUpdate = true
        end
    end
                                       
    if (not contextData.timeDay) or contextData.timeDay ~= nowtimeDay then
        contextData.timeDay = nowtimeDay

        contextData.todayPlayCount = 0
        contextData.todayPassLevelCount = 0
        contextData.todayStreakWinCount = 0
        contextData.todayStreakWinBreakCount = 0
        _needSave = true
        _doUpdate = true
    end

    if _doUpdate then
        self:updateAdjustContextData()
    end

    if _needSave then
        self:setAdjustContextData(contextData)
    end
end


-- 这个方法仅用于小游戏，待统一
function UBFuuuAdjustManager:onEndLevel( ubfELRuntime )

    -- if _debug then printx(1 , "UBFuuuAdjustManager:onEndLevel  endLevelData =", tts(ubfELRuntime) ) end

    --levelId, score, star, isLogicalFail
    local levelId = ubfELRuntime:getLevelId()
    local isWin = ubfELRuntime:isWin()
    local isLogicalFail = ubfELRuntime:isLogicalFail()

    if _debug then printx(1 , "UBFuuuAdjustManager:onPassLevel -========================= \n", "levelId:", levelId, "isWin:", isWin, "isLogicalFail:", isLogicalFail ) end

    local isMainLevel = ubfELRuntime:getLevelType() == GameLevelType.kMainLevel
    if not isMainLevel then return end


    local _endGameData = ubfELRuntime:getEndLevelData()

    local passCollectByUseProp = false

    local levelInfo = UBFGameSceneManager:getInstance():getLevelInfo()
    if levelInfo.usePropList then
        local _propPassMap = {
            [UBFPropUnitType.kRefresh] = true,
            [UBFPropUnitType.kRevert] = true,
            [UBFPropUnitType.kAddStep5] = true,
            [UBFPropUnitType.kAddStep15] = true,
        }

        for k,v in ipairs(levelInfo.usePropList) do
            if not _propPassMap[v.propUnitType] and not v.isPreprop then
                passCollectByUseProp = true
                break
            end
        end
    end

    if _endGameData and _endGameData.dcData and _endGameData.dcData.UBFuuu then
        _endGameData.dcData.UBFuuu.passCollectByUseProp = passCollectByUseProp
    end



    if isWin or isLogicalFail then
        local contextData = self:getAdjustContextData()

        if not contextData.todayPlayCount then contextData.todayPlayCount = 0 end
        contextData.todayPlayCount = contextData.todayPlayCount + 1

        if isWin then

            if not contextData.todayPassLevelCount then
                contextData.todayPassLevelCount = 0
            end

            contextData.todayPassLevelCount = contextData.todayPassLevelCount + 1
        end

        self:setAdjustContextData(contextData)
    end

    -- 刷星失败次数：本局最终状态直接更新本地乐观值，联网后由服务端下发覆盖
    -- 退出/重玩/非正常结束由纯函数 fail-closed 过滤，首闯 0 星与满星不参与
    local _farmStarAction = UBFuuuAdjustManager.resolveFarmStarResultAction({
        isWin = isWin,
        star = ubfELRuntime:getStar(),
        oldStar = ubfELRuntime:getOldStar(),
        failReason = ubfELRuntime:getLevelFailReason(),
    })
    if _farmStarAction then
        self:applyFarmStarFailCountResult(levelId, _farmStarAction)
    end
end

-- 这个方法仅用于app，待统一
function UBFuuuAdjustManager:onPassLevel( levelId, score, star, isLogicalFail )
    if _debug then printx(1 , "UBFuuuAdjustManager:onPassLevel -========================= \n", "levelId:", levelId, "score:", score, "star:", star, "isLogicalFail:", isLogicalFail ) end

    local levelScene = UBFLevelIdUtil:tryGetCurrLevelScene()
    local isMainLevel = UBFLevelSceneFunc:isMainLevel(levelScene)
    if not isMainLevel then return end

    if star > 0 or isLogicalFail then
        local contextData = self:getAdjustContextData()

        if not contextData.todayPlayCount then contextData.todayPlayCount = 0 end
        contextData.todayPlayCount = contextData.todayPlayCount + 1

        if star > 0 then

            if not contextData.todayPassLevelCount then
                contextData.todayPassLevelCount = 0
            end

            contextData.todayPassLevelCount = contextData.todayPassLevelCount + 1
        end
        
        self:setAdjustContextData(contextData)
    end
end

function UBFuuuAdjustManager:onActPassDay()
    local contextData = self:getAdjustContextData()
    contextData.todayPlayCount = 0
    contextData.todayPassLevelCount = 0
    contextData.todayStreakWinCount = 0
    contextData.todayStreakWinBreakCount = 0
    self:setAdjustContextData(contextData)

    if _debug then printx( 1, "UBFuuuAdjustManager:onActPassDay ------------  contextData =" , contextData ) end
end


function UBFuuuAdjustManager:getAdjustContextIniteState()
    return self.adjustContextIniteState
end

function UBFuuuAdjustManager:getAdjustContextData()
    if not self.contextData then
        self.contextData = self:loadData(_UBFuuuContextFileName) or {}
    end
    return self.contextData
end

function UBFuuuAdjustManager:setAdjustContextData( newContextData, donotSaveToFile )
    self.contextData = newContextData
    if not donotSaveToFile then
        self:saveData(self.contextData, _UBFuuuContextFileName)
    end
end

function UBFuuuAdjustManager:__getDcMapByPropUsageMap(propUsageMap)
    local _propUsageMap_forDC = {}

    if propUsageMap then
        for k,v in pairs(propUsageMap) do

            _propUsageMap_forDC[ tostring(k) .. "_bagItemCount" ] = v.bagItemCount
            _propUsageMap_forDC[ tostring(k) .. "_discountItemCount" ] = v.discountItemCount
            _propUsageMap_forDC[ tostring(k) .. "_videoItemCount" ] = v.videoItemCount
            
        end
    end
    return _propUsageMap_forDC
end

function UBFuuuAdjustManager:__creatContextDataByServerResponseBean( datas )
    local _contextData = {}

    --新用户闯关能力标签值（0-99）
    _contextData.newUserLevelSkillValue = datas.newUserLevelSkillValue 

    --新用户闯关能力标签，1-8，  标签有可能延迟生成，注意兼容
    _contextData.newUserLevelSkillTag = datas.newUserLevelSkillTag 

    --过去 28 天的登录次数的列表（不包含今天），每天一个槽位，列表第一个是昨天（时间越靠前，列表越靠后）
    --值为0或1的数字，0表示当日为登录，1表示当日有登录
    _contextData.dailyLoginCountList = datas.activeDayInLast28Days
    
    --过去 30 天的闯关次数（不包含今天），每天一个槽位，列表第一个是昨天（时间越靠前，列表越靠后）
    _contextData.dailyPlayCountList = datas.challengeCountInLast30Days --注意，这个字段同时用于判断整个数据的合法性，不能随便改名或者删除

    --最近最多30个区域的统计信息列表
    _contextData.areaStatisticInfoList = datas.areaSummaryBeans

    --最近一次服务端计算并落库的 activityIndex1 原始查表值，以及对应自然日
    _contextData.latestActivityIndex1 = datas.latestActivityIndex1
    _contextData.latestActivityIndex1Day = datas.latestActivityIndex1Day

    --当日闯关次数
    _contextData.todayPlayCount = 0

    _contextData.playCount3 = 0
    _contextData.playCount7 = 0
    _contextData.playCount30 = 0

    if _contextData.dailyPlayCountList then
        for k,v in ipairs(_contextData.dailyPlayCountList) do
            if k == 1 then
                _contextData.todayPlayCount = v
            elseif k <= 4 then
                _contextData.playCount3 = _contextData.playCount3 + v
                _contextData.playCount7 = _contextData.playCount7 + v
                _contextData.playCount30 = _contextData.playCount30 + v
            elseif k <= 8 then
                _contextData.playCount7 = _contextData.playCount7 + v
                _contextData.playCount30 = _contextData.playCount30 + v
            else
                _contextData.playCount30 = _contextData.playCount30 + v
            end
        end
    end

    -- 过去28天（不含今天）的总闯关次数
    _contextData.playCount28 = 0
    if _contextData.dailyPlayCountList then
        for k,v in ipairs(_contextData.dailyPlayCountList) do
            if k >= 2 and k <= 29 then  -- index 2=昨天, index 29=28天前
                _contextData.playCount28 = _contextData.playCount28 + v
            end
        end
    end

    --修正后的 最近30天的 加权 打关次数
    _contextData.fixedPlayCount1 = math.floor( (_contextData.playCount3/3*1 + _contextData.playCount7/7*2 + _contextData.playCount30/30*2) / 5 + 0.5 )
    _contextData.fixedPlayCount2 = math.floor( (_contextData.playCount3/3*1 + _contextData.playCount7/7*3 + _contextData.playCount30/30*16) / 20 + 0.5 )
    _contextData.fixedPlayCount = _contextData.fixedPlayCount1

    --最近28的 登录天数
    _contextData.loginDayCount28 = 0
    _contextData.loginDayCount7 = 0

    if _contextData.dailyLoginCountList then
        for k,v in ipairs(_contextData.dailyLoginCountList) do
            if v > 0 then
                _contextData.loginDayCount28 = _contextData.loginDayCount28 + 1
                if k <= 7 then
                    _contextData.loginDayCount7 = _contextData.loginDayCount7 + 1
                end
            end
        end
    end

    --最近30区域的 加二步 使用数
    _contextData.add2StepOnLast30Areas = 0

    --最近30区域的 激励视频加二步 使用数
    _contextData.videoAddStepCount = 0

    --最近30区域的 加五步 使用数
    _contextData.add5StepOnLast30Areas = 0

    _contextData.hammerOnLast30Areas = 0
    _contextData.rocketOnLast30Areas = 0
    _contextData.linebrushOnLast30Areas = 0
    _contextData.timeHammerOnLast30Areas = 0
    _contextData.timeRocketOnLast30Areas = 0
    _contextData.timeLinebrushOnLast30Areas = 0
    
    --最近30区域的 用户打关能力 修正系数
    _contextData.playerAbility = datas.playerAbility or 0
    _contextData.newUserLevelSkillValue = datas.newUserLevelSkillValue or -1
    _contextData.topPlayerAbilityValue = datas.topPlayerAbilityValue or -1
    _contextData.newUserAbility20250110Value = datas.newUserAbility20250110Value or -1
    _contextData.newUserAbility20250110Index = datas.newUserAbility20250110Index or -1

    _contextData.avgAbilityV250521Value = datas.avgAbilityV250521Value or -1
    _contextData.abilityV250521Index = datas.abilityV250521Index or -1

    _contextData.areaAbilityDCStr = nil
    _contextData.areaAbilityV250521DCStr = nil

    --上一个区域的 难度指数
    _contextData.diffIndexOnLastArea = 6 --todo

    _contextData.topLevelLastPLayDiffIndex = datas.prevLogicDiffIndex

    --当前topLevel是否处于保底状态
    _contextData.toplevelBaoDiFlag = datas.toplevelBaoDiFlag

    if _contextData.toplevelBaoDiFlag then
        _contextData.toplevelBaoDiLevel = UserManager:getInstance():getUserRef():getTopLevelId()
    end
    

    --当日的过关次数
    _contextData.todayPassLevelCount = datas.todayPassLevelCount
    _contextData.todayStreakWinCount = datas.todayStreakWinCount or 0
    _contextData.todayStreakWinBreakCount = datas.todayStreakWinBreakCount or 0
    -- printx( 1, "UBFuuuAdjustManager:__creatContextDataByServerResponseBean ------------  todayPassLevelCount =", _contextData.todayPassLevelCount, "  todayStreakWinCount:", datas.todayStreakWinCount, "  todayStreakWinBreakCount:", datas.todayStreakWinBreakCount )

    local _abilitySum = 0
    local _abilityCount = 0
    local _areaAbilityDCStrTime = nil

    local _areaCashValueDcString = nil
    local _areaFarmCashValueDcString = nil
    local _areaTotalCashValueDcString = nil

    if _contextData.areaStatisticInfoList then
        for k,areaStatisticInfo in ipairs(_contextData.areaStatisticInfoList) do

            if areaStatisticInfo.areaId > 40002 or areaStatisticInfo.areaId == 0 then
                _contextData.add2StepOnLast30Areas = _contextData.add2StepOnLast30Areas + (areaStatisticInfo.add2StepCount or 0)
                _contextData.videoAddStepCount = _contextData.videoAddStepCount + (areaStatisticInfo.videoAddStepCount or 0)
                _contextData.add5StepOnLast30Areas = _contextData.add5StepOnLast30Areas + (areaStatisticInfo.add5StepCount or 0)

                if areaStatisticInfo.areaId ~= 40003 then
                    _contextData.hammerOnLast30Areas = _contextData.hammerOnLast30Areas + (areaStatisticInfo.hammerCount or 0)
                    _contextData.timeHammerOnLast30Areas = _contextData.timeHammerOnLast30Areas + (areaStatisticInfo.timeHammerCount or 0)
                end
                _contextData.rocketOnLast30Areas = _contextData.rocketOnLast30Areas + (areaStatisticInfo.rocketCount or 0)
                _contextData.timeRocketOnLast30Areas = _contextData.timeRocketOnLast30Areas + (areaStatisticInfo.timeRocketCount or 0)
                _contextData.linebrushOnLast30Areas = _contextData.linebrushOnLast30Areas + (areaStatisticInfo.lineBrushCount or 0)
                _contextData.timeLinebrushOnLast30Areas = _contextData.timeLinebrushOnLast30Areas + (areaStatisticInfo.timeLineBrushCount or 0)
            end

            if not _areaCashValueDcString then
                _areaCashValueDcString = tostring( areaStatisticInfo.v250801CashValue or 0 )
            else
                _areaCashValueDcString = _areaCashValueDcString .. "_" .. tostring( areaStatisticInfo.v250801CashValue or 0 )
            end

            if not _areaFarmCashValueDcString then
                _areaFarmCashValueDcString = tostring( areaStatisticInfo.v250801FarmCashValue or 0 )
            else
                _areaFarmCashValueDcString = _areaFarmCashValueDcString .. "_" .. tostring( areaStatisticInfo.v250801FarmCashValue or 0 )
            end

            if not _areaTotalCashValueDcString then
                _areaTotalCashValueDcString = tostring( (areaStatisticInfo.v250801CashValue or 0) + (areaStatisticInfo.v250801FarmCashValue or 0) )
            else
                _areaTotalCashValueDcString = _areaTotalCashValueDcString .. "_" .. tostring( (areaStatisticInfo.v250801CashValue or 0) + (areaStatisticInfo.v250801FarmCashValue or 0) )
            end
            
            local _num = tonumber(areaStatisticInfo.regionChallengeAbility or 0)
            local _num_top = tonumber(areaStatisticInfo.topRegionChallengeAbility or 0)
            
            local _numStr = "0"

            if _num > 0 then
                _numStr = tostring( math.floor(_num * 1000) / 1000 )
            elseif _num_top > 0 then
                _numStr = "T" .. tostring( math.floor(_num_top * 1000) / 1000 )
            end
            
            --区域15关平均闯关能力（1-8）
            if _contextData.areaAbilityDCStr then
                _contextData.areaAbilityDCStr = _contextData.areaAbilityDCStr .. "_" .. _numStr
            else
                _contextData.areaAbilityDCStr = _numStr
            end

            if areaStatisticInfo.abilityV250521 then

                local _numV250521 = tonumber( areaStatisticInfo.abilityV250521 )
                
                if _numV250521 > 0 then
                    local _str = tostring( math.floor(_numV250521 * 1000) / 1000 )
                    if _contextData.areaAbilityV250521DCStr then
                        _contextData.areaAbilityV250521DCStr = _contextData.areaAbilityV250521DCStr .. "_" .. _str
                    else
                        _contextData.areaAbilityV250521DCStr = _str
                    end
                end
            end

            _areaAbilityDCStrTime = self:timeInSec()

            if areaStatisticInfo.regionChallengeAbility and areaStatisticInfo.regionChallengeAbility ~= 0 then
                _abilitySum = _abilitySum + areaStatisticInfo.regionChallengeAbility
                _abilityCount = _abilityCount + 1
            end
            

            if k == 1 then
                if areaStatisticInfo.regionDiffAdjustIndexV2 then
                    _contextData.diffIndexOnLastArea = areaStatisticInfo.regionDiffAdjustIndexV2
                else
                    _contextData.diffIndexOnLastArea = areaStatisticInfo.regionDiffAdjustIndex or 6
                end
            end
        end
    end

    _contextData._areaCashValueDcString = _areaCashValueDcString
    _contextData._areaFarmCashValueDcString = _areaFarmCashValueDcString
    _contextData._areaTotalCashValueDcString = _areaTotalCashValueDcString

    _contextData.v250801PropUsageMap = datas.v250801PropUsageMap
    _contextData.v250801PropUsageMap_forDC = self:__getDcMapByPropUsageMap( datas.v250801PropUsageMap )
    _contextData.v250801CashValue = datas.v250801CashValue

    _contextData.v250801FarmPropUsageMap = datas.v250801FarmPropUsageMap
    _contextData.v250801FarmPropUsageMap_forDC = self:__getDcMapByPropUsageMap( datas.v250801FarmPropUsageMap )
    _contextData.v250801FarmCashValue = datas.v250801FarmCashValue

    if _areaAbilityDCStrTime then
        _contextData.areaAbilityDCStrTime = _areaAbilityDCStrTime
    end

    if _abilitySum ~= 0 and _abilityCount ~= 0 then
        _contextData.playerAbilityValue = math.floor((_abilitySum / _abilityCount) * 1000) / 1000
    else
        _contextData.playerAbilityValue = 0
    end
    
    local nowtime = self:timeInSec()
    local nowtimeDay = time2day(nowtime)
    _contextData.timeDay = nowtimeDay

    local topLevel = UserManager:getInstance():getUserRef():getTopLevelId()
    _contextData.currAreaId = math.floor( (topLevel - 1) / 15)

    if _debug then printx(1 , "UBFuuuAdjustManager:__creatContextDataByServerResponseBean  topLevel:", topLevel, "contextData.currAreaId:", _contextData.currAreaId ) end

    return _contextData
end




function UBFuuuAdjustManager:onUpdateAdjustContextData( datas )

    self.adjustContextIniteState = self.adjustContextIniteState + 2

    local newContextData = self:__creatContextDataByServerResponseBean( datas )
    newContextData.logicVer = 1
    newContextData.clientReceiveTime = self:timeInSec()

    if _debug then printx(1, "UBFuuuAdjustManager:onUpdateAdjustContextData  newContextData =", newContextData, newContextData.todayPlayCount, newContextData.todayPassLevelCount ) end

    self:setAdjustContextData(newContextData, false)
    self.adjustContextIniteState = self.adjustContextIniteState + 4
end

function UBFuuuAdjustManager:_updateAdjustContextData( datas, callback )
    local getUBFuuuStatisticInfoHttp = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.GetUBFuuuStatisticInfoHttp"
    getUBFuuuStatisticInfoHttp:post(datas):next(

    function ( response )
        local data = response:getData()

        if _debug then printx(1 , "UBFuuuAdjustManager:updateAdjustContextData   GetUBFuuuStatisticInfoHttp  ---- kSussece " , tts(data) ) end

        if data then
            self:onUpdateAdjustContextData( data )
            if callback then callback(true) end
        else
            if callback then callback(false) end
        end
    end,

    function ( response )
        -- body
        if _debug then printx(1 , "UBFuuuAdjustManager:updateAdjustContextData   GetUBFuuuStatisticInfoHttp  ---- kError " , tts(response:getData()) ) end
        if callback then callback(false) end
    end
    )
end

function UBFuuuAdjustManager:updateAdjustContextData( callback )

    if _debug then printx(1 , "UBFuuuAdjustManager:updateAdjustContextData   UBFGetLevelStatisticInfoHttp" ) end

    self.adjustContextIniteState = self.adjustContextIniteState + 1

    local UBFuuuSelectAdjust = require("ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuSelectAdjust")
    local switchInfos = UBFuuuSelectAdjust:createSwitchInfos(true)
    local configGroup = UBFuuuSelectAdjust:createConfigGroupMap(switchInfos.cfgGroup, switchInfos.CAGroup)

    local datas = {}
    datas.configGroup = configGroup
    
    datas.maxLevelId = UBFLevelRangeUtil:getMaxLevelForAdjust()
    datas.topRangeLength = UBFLevelRangeUtil:getTopLevelRangeLength() or 30
    datas.secTopRangeLength = UBFLevelRangeUtil:getSecTopLevelRangeLength()

    self:_updateAdjustContextData( datas, callback )
end

------------------------------

function UBFuuuAdjustManager:getLastAdjustResultData() --不保证时效性和正确性，仅用于宏观统计打点，不要用于业务逻辑计算！
    local uid = UserManager:getInstance():getUID()
    local _resultData = self:loadData( _lastAdjustResultFileName .. "_" .. tostring(uid) )
    return _resultData
end

function UBFuuuAdjustManager:setLastAdjustResultData( resultData )
    local uid = UserManager:getInstance():getUID()
    self:saveData(resultData, _lastAdjustResultFileName .. "_" .. tostring(uid))
end


function UBFuuuAdjustManager:getPlayerAbility() --获取当前本地数据中的闯关能力档位，可能不是最新
    local ubfuuuStatisticInfo = self:getAdjustContextData()
    local playerAbility = ubfuuuStatisticInfo.playerAbility or 0
    return playerAbility
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


return UBFuuuAdjustManager
