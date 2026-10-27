local DiffAdjustModMgr = class2("DiffAdjustModMgr", UBFGameModManager)
DiffAdjustModMgr.ACT_KEY = UBFModSourceIdEnum.kDiffAdjustModMgr
UBFGameModManagerOrganizer:register(DiffAdjustModMgr.ACT_KEY , DiffAdjustModMgr)

_G.UbfuuuDisableReason = {
    kCheckResultInvalid = 1,
    kDesiredDiffAvgInvalid = 2,
    kDiffFixIsNil = 3,
    kCheckResultIsNil = 4,
    kAdjustContextIsNil = 5,
    kUbfuuuStatisticInfoIsNil = 6,
    kDesiredDiffAvgInvalid2 = 7,
    kFeedback_NoDiffDsMap = 8,
    kFeedback_NoDesiredDiff = 9,
    kModEnableFailed = 10,
}

local levelFlag3 = 10861
local POST_ADD_STEP_AVAILABLE_STEPS = 1000000

local _debug = false
--
--
--
--
--
--
--
--


function DiffAdjustModMgr:isWillingEnabled(runtime, sourceId)
    if not UBFLevelSceneFunc:isMainLevel(runtime:getLevelScene()) then return end
    local processType = runtime:getProcessType()
    return processType == UBFProcessTypeEnum.START_LEVEL
end

function DiffAdjustModMgr:isEnabled(event)
    return true
end

function DiffAdjustModMgr:notifyEventStatic(event)
    UBFGameModManager.notifyEventStatic(DiffAdjustModMgr,event)

    local eventName = event:getEventName()
    local runtime = event:getRuntime()
    local eventData = event:getOrigin()
    local modMgr = runtime:getModMgr()
    local UBFuuuAdjustManager = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuAdjustManager"

    lua_switch(eventName) {
        -- [UBFGameModEventEnum.LOAD_MOD] = function()
        --     modMgr:setModEnabled(UBFModSourceIdEnum.kDiffAdjustModMgr, true)
        --     if _debug then printx(1 , "DiffAdjustModMgr:notifyEventStatic  LOAD_MOD !!!!!!!!!!" ) end
        -- end,

        [UBFGameModEventEnum.BEFORE_PASS_LEVEL] = function()
            if _debug then printx(1 , "DiffAdjustModMgr:notifyEventStatic  BEFORE_PASS_LEVEL !!!!!!!!!!" ) end
            UBFuuuAdjustManager:onEndLevel( runtime )
        end,

        [UBFGameModEventEnum.BEFORE_FAIL_LEVEL] = function()
            if _debug then printx(1 , "DiffAdjustModMgr:notifyEventStatic  BEFORE_FAIL_LEVEL !!!!!!!!!!" ) end
            UBFuuuAdjustManager:onEndLevel( runtime )
        end,

        [UBFGameModEventEnum.BEFORE_QUIT_LEVEL] = function(evt)
            if _debug then printx(1 , "DiffAdjustModMgr:notifyEventStatic  BEFORE_QUIT_LEVEL !!!!!!!!!! " ) end
            UBFuuuAdjustManager:onEndLevel( runtime )
        end,
    }
end

function DiffAdjustModMgr:checkModIsEnabled(runtime)
    return true
end

function DiffAdjustModMgr:dummyCheck(levelId)
    local UBFuuuSelectAdjust = require("ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuSelectAdjust")
    local _ubfuuuAdjustContext = UBFuuuSelectAdjust:rebuildContext(levelId, { levelScene = UBFLevelSceneType.kMain, playId = "DiffAdjustModMgr:dummyCheck" })

    local _resultDatas = UBFuuuSelectAdjust:checkAdjustStrategy( _ubfuuuAdjustContext )

    return _resultDatas
end

function DiffAdjustModMgr:getUBFuuuInfoByCheckResultData(resultData)
    local _ubfuuCheckResult = resultData.checkResult
    local _calculateDiffIndexResult = _ubfuuCheckResult and _ubfuuCheckResult.calculateDiffIndexResult

    local _info = {}

    if _calculateDiffIndexResult then
        _info.activityIndex = _calculateDiffIndexResult.activityIndex
        _info.paymentIndex = _calculateDiffIndexResult.paymentIndex
        _info.playerAbility = _calculateDiffIndexResult.playerAbility
        _info.diffIndex = _calculateDiffIndexResult.diffIndex

        _info.desiredDiffAvg = _ubfuuCheckResult.desiredDiffAvg
        _info.fixedDesiredDiffAvg = _ubfuuCheckResult.fixedDesiredDiffAvg
        _info.diffFix = resultData.diffFix
    end
    
    return _info
end


--正常打关模式
function DiffAdjustModMgr:createModSourceENVDataFromPlay(ubfSLRuntime)

    _G.CurrStageUbfuuuDisableReason = -1

    -- 初始化其他功能
    local UBFuuuAdjustManager = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuAdjustManager"
    UBFuuuAdjustManager:onStartLevel( ubfSLRuntime )

    --
--
--
--


    local modMgr = ubfSLRuntime:getModMgr()
    local levelId = ubfSLRuntime:getLevelId()
    local playId = ubfSLRuntime:getPlayId()

    local UBFuuuSelectAdjust = require("ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuSelectAdjust")
    local _ubfuuu_enable = UBFuuuSelectAdjust:checkEnable(levelId, ubfSLRuntime.levelScene)

    if _debug then printx( 1 , "DiffAdjustModMgr:createModData  _ubfuuu_enable =", _ubfuuu_enable) end
    if not _ubfuuu_enable then 
        _G.CurrStageUbfuuuDisableReason = UbfuuuDisableReason.kModEnableFailed
        return nil 
    end

    -- _ubfuuu_enable = true --todo test

    -- builder:addMod( sourceId , { 
    --     itemType = UBFGameItemType.kModExample,
    --     collectionColor = UBFAnimalColorType.kRed,
    -- } ) 
    -- printx(16,debug.traceback())
    local modEnvData = {}

    local _isInRust = ubfSLRuntime.isInRust and ubfSLRuntime:isInRust()
    local _ubfuuuAdjustContext = UBFuuuSelectAdjust:rebuildContext(levelId, { levelScene = ubfSLRuntime:getLevelScene(), playId = playId, isInRust = _isInRust })
    local okAdjustContextTestHelper, UBFuuuAdjustContextTestHelper = pcall(require, "ubf.debug.UBFuuuAdjustContextTestHelper")
    if okAdjustContextTestHelper and UBFuuuAdjustContextTestHelper and UBFuuuAdjustContextTestHelper.applyPendingPatch then
        _ubfuuuAdjustContext = UBFuuuAdjustContextTestHelper:applyPendingPatch(_ubfuuuAdjustContext, {
            levelId = levelId,
            levelScene = ubfSLRuntime:getLevelScene(),
            playId = playId,
            source = "DiffAdjustModMgr:createModSourceENVDataFromPlay",
        })
    end
    local UBFuuuA9ReturnActivityAdapter = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuA9ReturnActivityAdapter"
    UBFuuuA9ReturnActivityAdapter:normalizeContext(_ubfuuuAdjustContext)

    -- if _debug then printx( 1 , "DiffAdjustModMgr:createModData  rebuildContext   _ubfuuuAdjustContext =", tts(_ubfuuuAdjustContext) ) end

    modEnvData.ubfuuu = true
    modEnvData.selfFeedbackCollect = _ubfuuuAdjustContext.selfFeedbackCollect --开启自反馈采集逻辑
    modEnvData.S1 = _ubfuuuAdjustContext.S1
    modEnvData.ubfuuuG4Idx = _ubfuuuAdjustContext.ubfuuuG4Idx
    modEnvData.cfgGroup = _ubfuuuAdjustContext.cfgGroup
    modEnvData.modGroup = _ubfuuuAdjustContext.modGroup
    modEnvData.usedPreAddStep = 0
    modEnvData.useOtherPreProp = false
    
    local propIdMap = _G.AMFPropId

    local prePropModContextData = modMgr:getModContextData(UBFModSourceIdEnum.kPreProp)
    local prePropInfoData = prePropModContextData.prePropInfoData 
    for i, v in pairs(prePropInfoData or {}) do
        if v.isSelected then

            -- local propMgr = UBFGlobal:getLogic("PropManager")
            -- local addStepCount = propMgr:getAddStepCount(v.propId)
            -- todo reast

            if v.propId == propIdMap.ADD_THREE_STEP 
                or v.propId == propIdMap.TIMELIMIT_ADD_THREE_STEP
                or v.propId == propIdMap.INFINITE_PRE_ADD_3_STEP_ONE_MINUTE 
                then
                    modEnvData.usedPreAddStep = 1
            else
                modEnvData.useOtherPreProp = true
                modEnvData.selfFeedbackCollect = 0
            end
        end
    end
    

    -- setTimeOut( function () CommonTip:showTip("usedPreAddStep:" .. tostring(modEnvData.usedPreAddStep) .. "  useOtherPreProp:" .. tostring(modEnvData.useOtherPreProp), nil, nil, 999) end, 5 )

    if _ubfuuuAdjustContext.luckyBagPartyEnabledAndHasEffect then
        modEnvData.selfFeedbackCollect = 0
    end

    local enabledWinningStreak = ubfSLRuntime:getWinningStreakInfo()
    if enabledWinningStreak then
        --[[
            enabledWinningStreak = {
                [1] = {
                    modSourceId = 0,                                                    --[必需]
                    winningStreakCount = 0,                                             --[必需]

                    logicTypeMap = {                                                    --[必需]
                        [UBFWinningStreakLogicType.kAddScore] = true,
                        [UBFWinningStreakLogicType.kAddEffectOnBoard] = true,
                    },              
                    sourceName = "",                                                    
                    datas = nil,                                                        --[可选]
                }
            }
        ]]
        
        if _debug then printx( 1 , "DiffAdjustModMgr:createModData  enabledWinningStreak =", tts(enabledWinningStreak) ) end

        for k,v in ipairs(enabledWinningStreak) do
            if v.logicTypeMap and v.logicTypeMap[UBFWinningStreakLogicType.kAddEffectOnBoard] then
                if v.winningStreakCount and v.winningStreakCount > 1 then --上线试试，如果不行就全部关掉（改为大于0都不采集）
                    if log then printx( 1 , "DiffAdjustModMgr:createModData  winningStreakCount:", v.winningStreakCount ) end
                    modEnvData.selfFeedbackCollect = 0
                end
            end
        end
    end


    if modEnvData.modGroup then
        if modEnvData.modGroup.T1 then
            if levelId >= 301 then
                ubfSLRuntime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByActivityIndex(DiffAdjustModMgr.ACT_KEY, 2, UBFuuuFixMode.kaddVaule)
                ubfSLRuntime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByPaymentIndex(DiffAdjustModMgr.ACT_KEY, 2, UBFuuuFixMode.kaddVaule)
            end
        end
        
        if modEnvData.modGroup.T2 then
            if _ubfuuuAdjustContext.todayFirstStartLevelId == 0 or _ubfuuuAdjustContext.todayFirstStartLevelId == levelId then
                ubfSLRuntime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByDesiredDiffAvgBeforeBaodi(
                    tostring(DiffAdjustModMgr.ACT_KEY) .. "_T2_" .. tostring(_ubfuuuAdjustContext.todayFirstStartLevelId) , 
                    0.5, 
                    UBFuuuFixMode.kMultiplyVaule, 
                    { 
                        rangeMin = 2,
                        minValue = 2,
                        maxValue = 5,
                    }
                )
            end
        end

        if modEnvData.modGroup.T3 and _ubfuuuAdjustContext.topLevel <= 1000 and _ubfuuuAdjustContext.returnState then
            local currWinComboNum = nil
            local WinningStreakMgr = _G.amfBean("WinningStreakManager")
            if WinningStreakMgr then
                currWinComboNum = WinningStreakMgr:getGlobalWinningCount()
            end

            if currWinComboNum and currWinComboNum >= 2 and (_ubfuuuAdjustContext.todayPassLevelCount and _ubfuuuAdjustContext.todayPassLevelCount < 10) then
                ubfSLRuntime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByDesiredDiffAvgBeforeBaodi(
                    tostring(DiffAdjustModMgr.ACT_KEY) .. "_T3_" .. tostring(currWinComboNum) , 
                    1.5,
                    UBFuuuFixMode.kMultiplyVaule, 
                    { 
                        rangeMax = 3,
                        maxValue = 3,
                    }
                )
            end
        end

        local _todayStreakWinCount = _ubfuuuAdjustContext.todayStreakWinCount or 0
        local _todayStreakWinBreakCount = _ubfuuuAdjustContext.todayStreakWinBreakCount or 0
        local _todayPassLevelCount = _ubfuuuAdjustContext.todayPassLevelCount or 0
        -- printx(1, "DiffAdjustModMgr:createModSourceENVDataFromPlay  _todayStreakWinCount:", _todayStreakWinCount, " _todayStreakWinBreakCount:", _todayStreakWinBreakCount, " _todayPassLevelCount:", _todayPassLevelCount)
        if modEnvData.modGroup.T31 and _ubfuuuAdjustContext.returnState and _ubfuuuAdjustContext.topLevel <= 1000
            and _todayStreakWinCount >= 2 and _todayStreakWinBreakCount == 0 and _todayPassLevelCount <= 10 then
            ubfSLRuntime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByDesiredDiffAvgBeforeBaodi(
                tostring(DiffAdjustModMgr.ACT_KEY) .. "_T31_" .. tostring(_todayStreakWinCount),
                1.5,
                UBFuuuFixMode.kMultiplyVaule,
                {
                    rangeMax = 2,
                    maxValue = 2,
                }
            )
        end

        -- D2 模块：非难关标记关卡通过 adjustFixInfo 替换 diff_index_map 配置表
        if modEnvData.modGroup.D2 then
            local _d2_levelStar = _ubfuuuAdjustContext.levelStar or 0
            local _d2_isTopLevelRange = levelId > _ubfuuuAdjustContext.maxLevelId - _ubfuuuAdjustContext.topRangeLength

            if _d2_levelStar == 0 and not _d2_isTopLevelRange then

                local _d2_levelDifficultFlag = _G.amfBean("MetaManager"):getLevelDifficultFlag(levelId, UBFLevelSceneType.kMain)
                -- local _d2_levelDifficultFlag = MetaManager:getInstance():getLevelDifficultFlag(levelId, ubfSLRuntime:getLevelScene())

                if _d2_levelDifficultFlag and _d2_levelDifficultFlag == LevelDiffcultFlag.kNormal then
                    ubfSLRuntime.UBFuuuAdjustLogic:replaceUBFuuuConfigFile(
                        "D2_nohardmark",
                        UBFuuuConfigNameId["ubfuuu_diff_index_map"],
                        "ubfuuu_diff_index_map_nohardmark"
                    )
                end
            end
        end

        -- 开关 1419：加步数道具调节迭代
        do
            local _fixInfo = ubfSLRuntime.UBFuuuAdjustLogic:getUbfuuuAdjustFixInfo()
            local _existingAddStepFix = _fixInfo and _fixInfo[UBFuuuFixType.kAddStepFix]
            local _existingPreAddStepIntervalFix = _fixInfo and _fixInfo[UBFuuuFixType.kPreAddStepIntervalFix]
            local _existingPostAddStepIntervalFix = _fixInfo and _fixInfo[UBFuuuFixType.kPostAddStepIntervalFix]

            -- Rust 已经支持
            if not _existingAddStepFix and not _existingPreAddStepIntervalFix and not _existingPostAddStepIntervalFix then
                local _modGroup = modEnvData.modGroup or {}
                local _isPreAddStepWeakGroup = _modGroup.add3_5 or _modGroup.add3_5_alluser or _modGroup.add3
                local _isLimitedPostAddStepGroup = _modGroup.add3_5 or _modGroup.add5
                local _isAllUserPostAddStepGroup = _modGroup.add5_alluser or _modGroup.add3_5_alluser
                local _enablePreAddStepFix = false
                local _enablePostAddStepFix = false
                local _payTag = nil
                local _levelDifficultFlag = nil

                if _isPreAddStepWeakGroup then
                    _levelDifficultFlag = _G.amfBean("MetaManager"):getLevelDifficultFlag(levelId, UBFLevelSceneType.kMain)
                    if _levelDifficultFlag and _levelDifficultFlag ~= LevelDiffcultFlag.kNormal then
                        _enablePreAddStepFix = true
                    end
                end

                if _isLimitedPostAddStepGroup or _isAllUserPostAddStepGroup then
                    _payTag = UserTagManager:getUserPaymentTag2ServerVersion()
                end

                if _isAllUserPostAddStepGroup then
                    _enablePostAddStepFix = true
                elseif _isLimitedPostAddStepGroup then
                    if _payTag == UsetPaymentTagServer.kNone or _payTag == UsetPaymentTagServer.kLow then
                        _enablePostAddStepFix = true
                    end
                end

                if _enablePreAddStepFix then
                    ubfSLRuntime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByPreAddStepInterval(
                        DiffAdjustModMgr.ACT_KEY,
                        {
                            addStepAdjustMode = UBFuuuAddStepAdjustMode.kAddMaxDiffMoveByFixedValue,
                            targetMaxdiffMove = 1,
                        }
                    )
                end

                if _enablePostAddStepFix then
                    ubfSLRuntime.UBFuuuAdjustLogic:updateUbfuuuAdjustFixInfoByPostAddStepInterval(
                        DiffAdjustModMgr.ACT_KEY,
                        {
                            availableSteps = POST_ADD_STEP_AVAILABLE_STEPS,
                            addStepAdjustMode = UBFuuuAddStepAdjustMode.kAddMaxDiffMoveByStep,
                            stackingPreValue = true,
                        }
                    )
                end

                if _debug then UBFLogD("DiffAdjustModMgr:step_item_adjust", "pre:", tostring(_enablePreAddStepFix), "post:", tostring(_enablePostAddStepFix), "limitedPostGroup:", tostring(_isLimitedPostAddStepGroup), "allUserPostGroup:", tostring(_isAllUserPostAddStepGroup), "payTag:", tostring(_payTag), "levelDifficultFlag:", tostring(_levelDifficultFlag)) end
            else
                if _debug then UBFLogD("DiffAdjustModMgr:step_item_adjust skip", "isInRust:", tostring(_isInRust), "existingAddStep:", tostring(_existingAddStepFix), "existingPre:", tostring(_existingPreAddStepIntervalFix), "existingPost:", tostring(_existingPostAddStepIntervalFix)) end
            end
        end
        
    end

    if _isInRust then
        -- 出关反馈池：Rust + 超鸟 → RUST_bird，Rust + 无超鸟 → RUST
        local _collectKey = _G.SelfFeedbackPoolkey.kRUST
        local _existingInfo = ubfSLRuntime.UBFuuuAdjustLogic:getUbfuuuAdjustFixInfo()
        if _existingInfo 
            and _existingInfo[UBFuuuFixType.kSelfFeedbackPoolkey] 
            and _existingInfo[UBFuuuFixType.kSelfFeedbackPoolkey].collectKey == _G.SelfFeedbackPoolkey.kSuperBird then
            _collectKey = _G.SelfFeedbackPoolkey.kRUST_bird
        end
        ubfSLRuntime.UBFuuuAdjustLogic:setSelfFeedbackPoolkey("RUST", _G.SelfFeedbackPoolkey.kRUST, _collectKey)
    end

    UBFuuuA9ReturnActivityAdapter:beforeCheck(ubfSLRuntime, _ubfuuuAdjustContext, modEnvData)
    _ubfuuuAdjustContext.adjustFixInfo = ubfSLRuntime.UBFuuuAdjustLogic:getUbfuuuAdjustFixInfo()

    if _ubfuuuAdjustContext.adjustFixInfo and _ubfuuuAdjustContext.adjustFixInfo[UBFuuuFixType.kSelfFeedbackEnableFlag] then
        if _ubfuuuAdjustContext.adjustFixInfo[UBFuuuFixType.kSelfFeedbackEnableFlag].enableFlag then
            modEnvData.selfFeedbackCollect = 1
        else
            modEnvData.selfFeedbackCollect = 0
        end
    end

    -- 开始计算“生效的预期难度”
    local _resultDatas = UBFuuuSelectAdjust:checkAdjustStrategy( _ubfuuuAdjustContext )

    _resultDatas.ubfuuuAdjustContext = _ubfuuuAdjustContext
    if okAdjustContextTestHelper and UBFuuuAdjustContextTestHelper and UBFuuuAdjustContextTestHelper.recordCheckResult then
        UBFuuuAdjustContextTestHelper:recordCheckResult(_resultDatas)
    end

    local _ubfuuCheckResult = _resultDatas.checkResult
    local _feedbackResult = _resultDatas.feedbackResult
    local _diffFix = _resultDatas.diffFix

    if _debug then printx( 1 , "DiffAdjustModMgr:createModData  checkAdjustStrategy   _resultDatas =", tts(_resultDatas) ) end

    if _feedbackResult and _feedbackResult.diffFix then
        modEnvData.feedbackSelected = true
        modEnvData.upK = _feedbackResult.upK
        modEnvData.lowK = _feedbackResult.lowK
        modEnvData.feedpath = _feedbackResult.feedpath
    end

    if _ubfuuCheckResult 
        and _ubfuuCheckResult.desiredDiffAvg and _ubfuuCheckResult.desiredDiffAvg >= 1 
        and _ubfuuCheckResult.fixedDesiredDiffAvg and _ubfuuCheckResult.fixedDesiredDiffAvg >= 1 
        and _diffFix then

        _ubfuuCheckResult.adjustFixInfo = _ubfuuuAdjustContext.adjustFixInfo
        _ubfuuCheckResult.realDiffAvgByDiffFix = _feedbackResult and _feedbackResult.realDiffAvgByDiffFix

        modEnvData.ubfuuCheckResult = _ubfuuCheckResult
        modEnvData.ubfuuCheckResult.ubfuuuAdjustSelectEnable = true
        modEnvData.enableUBFuuu = true
        modEnvData.paymentIndex = _ubfuuCheckResult.paymentIndex

        ubfSLRuntime.adjustData = {
            enableUBFuuu = modEnvData.enableUBFuuu,
            mode = ProductItemDiffChangeMode.kAIAddColor,
            ds = 5,
            reason = "UBFuuu2025",
            lastReason = "UBFuuu2025",

            activityIndex = _ubfuuCheckResult.activityIndex,
            paymentIndex = _ubfuuCheckResult.paymentIndex,
            playerAbility = _ubfuuCheckResult.playerAbility,
            diffIndex = _ubfuuCheckResult.diffIndex,

            desiredDiffAvg = _ubfuuCheckResult.desiredDiffAvg,
            fixedDesiredDiffAvg = _ubfuuCheckResult.fixedDesiredDiffAvg,
            diffFix = _diffFix,

            toplevelBaoDiFlag = _ubfuuCheckResult.toplevelBaoDiFlag,
            toplevelBaoDiLevel = _ubfuuCheckResult.toplevelBaoDiLevel,
        }

        -- if _ubfuuCheckResult.stepFixEnable then
        --     ubfSLRuntime.adjustData.diffFix = nil
        -- end

        -- ubfSLRuntime.dcData = ubfSLRuntime.dcData or {}
        -- ubfSLRuntime.dcData.adjustDCData = ubfSLRuntime.adjustData

        local ProphetLaunchStrategy = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ProphetLaunchStrategy"
        ProphetLaunchStrategy:applySafely(ubfSLRuntime, _resultDatas)

        modEnvData.adjustData = ubfSLRuntime.adjustData

        UBFuuuSelectAdjust:updateBaoDi( _ubfuuCheckResult )

        local UBFuuuAdjustManager = require("ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.UBFuuuAdjustManager")
        UBFuuuAdjustManager:setLastAdjustResultData( modEnvData.ubfuuCheckResult )

        -- modEnvData.ubfuuuDisableReason = {code = -1} -- -1表示没有异常
        _G.CurrStageUbfuuuDisableReason = 0

        return modEnvData
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
--
--
--
--


        local _reason = {}
        _reason.datas = {}

        if _resultDatas.reason then
            _reason.code = _resultDatas.reason
            _reason.datas = _resultDatas.datas
        else
            if _ubfuuCheckResult then
                if not(_ubfuuCheckResult.desiredDiffAvg and _ubfuuCheckResult.desiredDiffAvg >= 1) then
                    _reason.code = UbfuuuDisableReason.kCheckResultInvalid
                    _reason.datas = _ubfuuCheckResult.desiredDiffAvg
                elseif not(_ubfuuCheckResult.fixedDesiredDiffAvg and _ubfuuCheckResult.fixedDesiredDiffAvg >= 1) then
                    _reason.code = UbfuuuDisableReason.kDesiredDiffAvgInvalid
                    _reason.datas = _ubfuuCheckResult.fixedDesiredDiffAvg
                elseif not _diffFix then
                    _reason.code = UbfuuuDisableReason.kDiffFixIsNil
                end
            else
                _reason.code = UbfuuuDisableReason.kCheckResultIsNil
            end
        end

        _G.CurrStageUbfuuuDisableReason = _reason.code
        modEnvData.ubfuuuDisableReason = _reason
    end

    return nil
end

function DiffAdjustModMgr:createModSourceENVDataFromAIAutoPlay(ubfSLRuntime, actData)
    local aiParamKey = actData and actData.actKey
    if not aiParamKey or aiParamKey ~= DiffAdjustModMgr.ACT_KEY  then return end

    actData.enableUBFuuu = true

    local diffFix = tonumber(actData.adjustData.diffFix)

    local adjustData = {
        enableUBFuuu = true,
        mode = ProductItemDiffChangeMode.kAIAddColor,
        ds = 5,
        reason = "UBFuuu2025ByAI",
        lastReason = "UBFuuu2025ByAI",

        diffFix = diffFix or 0,
    }

    if tostring(diffFix) ~= tostring(actData.adjustData.diffFix) then

        local _arr = string.split(actData.adjustData.diffFix, "_")

        actData.ubfuuCheckResult = {
            stepFixEnable = true,
            stepFix = tonumber(_arr[2]),
            desiredStep = tonumber(_arr[2]),
        }
    end

    actData.adjustData = table.merge(actData.adjustData, adjustData)
    ubfSLRuntime.adjustData = actData.adjustData
    actData.ubfuuCheckResult = {
        calculateDiffIndexResult = {
            modGroup = {
                enableFixScore = ubfSLRuntime.levelId < levelFlag3,
                enableFixIceCombo = ubfSLRuntime.levelId >= levelFlag3
            }
        }
    }

    if actData.scoreTest then
        actData.ubfuuCheckResult.calculateDiffIndexResult.modGroup.enableFixScore = actData.scoreTest.fixA
        actData.ubfuuCheckResult.calculateDiffIndexResult.modGroup.enableFixIceCombo = actData.scoreTest.fixC
    end

    return actData
end

function DiffAdjustModMgr:createModSourceENVDataFromEditorPlay(ubfSLRuntime)
    local ubfuuuInfo = _G.lastEditorData and _G.lastEditorData.ubfuuu
    if not ubfuuuInfo then
        return
    end
    local actData = {}
    actData.adjustData = {}
    actData.enableUBFuuu = true

    local adjustData = {
        enableUBFuuu = true,
        mode = ProductItemDiffChangeMode.kAIAddColor,
        ds = 5,
        reason = "UBFuuu2025Editor",
        lastReason = "UBFuuu2025Editor",

        diffFix = tonumber(ubfuuuInfo.diffFix) or 0,
    }
    actData.adjustData = table.merge(actData.adjustData, adjustData)
    ubfSLRuntime.adjustData = actData.adjustData
    return actData
end

--加载mod资源
function DiffAdjustModMgr:loadModRes(runtime)
end

--卸载mod资源
function DiffAdjustModMgr:unLoadModRes(runtime)
end

return DiffAdjustModMgr:staticInit()
