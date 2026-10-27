_G.UBF_NO_REQUIRE_LUA_FLAG()

local UBFuuuDiffLogic = {}

_G.UBFuuuDebugCore = { showPrintInfo = {} }

local _kvmap = {
    [1] = 1,
    [2] = 0.65,
    [3] = 0.4,
    [4] = 0.2,
}

local minDsCount = -5
local maxDsCount = 15

--[[
    if _stepDiff > 0 then
        if _stepDiff <= 3 then
            if _currRate > 4 then currDs = currDs + 3 end
        elseif _stepDiff <= 5 then
            if _currRate > 10 then currDs = currDs + 4 end
        elseif _stepDiff <= 10 then
            if _currRate > 15 then currDs = currDs + 3 end
        end
    end

    if _stepDiff <= v.stepDiff then
                if _currRate > v.rate then currDs = currDs + v.dsFix end

    ]]

--【-10】，【-9】，【-8】，【-7】，【-6】，【-5】，【-4】，【-3】，【-2】，【-1.6】，【-1.3】，【-1】，【-0.8】，【-0.6】，【-0.4】，【-0.2】，【0】，【0.5】，【1】，【1.5】，【2】，【3】，【4】，【5】

local _adjustConfigByDiffFixMap = {



    ------------------------增加难度--------------------------------
    [7] = {
        lineFix = -5,        --平移期望线
        defaultDsFix = -5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 0},
            {stepDiff = 5, rate = 10, dsFix = 0},
            {stepDiff = 10, rate = 15, dsFix = -1},
        },
        maxDs = 8,
        minDs = -5,
    },
    [6] = {
        lineFix = -4,        --平移期望线
        defaultDsFix = -4,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 0},
            {stepDiff = 5, rate = 10, dsFix = 0},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 10,
        minDs = -5,
    },
    [5] = {
        lineFix = -3,        --平移期望线
        defaultDsFix = -3,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 0},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 12,
        minDs = -5,
    },
    [4] = {
        lineFix = -2,        --平移期望线
        defaultDsFix = -2,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 13,
        minDs = -5,
    },
    [3] = {
        lineFix = -1,        --平移期望线
        defaultDsFix = -2,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 0},
        },
        maxDs = 15,
        minDs = -5,
    },
    [2] = {
        lineFix = -1,        --平移期望线
        defaultDsFix = -1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [1] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = -1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 1},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },

    ------------------------默认难度-------------------------------------
    [0] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },

    ------------------------降低难度-------------------------------------
    [-1] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0.35,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-2] = {
        lineFix = 0.3,        --平移期望线
        defaultDsFix = 0.5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-3] = {
        lineFix = 0.6,        --平移期望线
        defaultDsFix = 0.5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-4] = {
        lineFix = 1,        --平移期望线
        defaultDsFix = 0.65,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-5] = {
        lineFix = 1,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-6] = {
        lineFix = 1.3,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-7] = {
        lineFix = 1.6,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-8] = {
        lineFix = 2,        --平移期望线
        defaultDsFix = 1,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-9] = {
        lineFix = 2,        --平移期望线
        defaultDsFix = 2,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-10] = {
        lineFix = 3,        --平移期望线
        defaultDsFix = 2,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-11] = {
        lineFix = 3,        --平移期望线
        defaultDsFix = 3,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-12] = {
        lineFix = 4,        --平移期望线
        defaultDsFix = 3,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 3},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-13] = {
        lineFix = 4,        --平移期望线
        defaultDsFix = 4,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 2},
            {stepDiff = 5, rate = 10, dsFix = 3},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-14] = {
        lineFix = 5,        --平移期望线
        defaultDsFix = 5,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 3},
            {stepDiff = 5, rate = 10, dsFix = 3},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-15] = {
        lineFix = 6,        --平移期望线
        defaultDsFix = 6,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 3},
            {stepDiff = 5, rate = 10, dsFix = 3},
            {stepDiff = 10, rate = 15, dsFix = 2},
        },
        maxDs = 15,
        minDs = -5,
    },
    [-16] = {
        lineFix = 9,        --平移期望线
        defaultDsFix = 12,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 5},
            {stepDiff = 5, rate = 6, dsFix = 5},
            {stepDiff = 10, rate = 10, dsFix = 4},
        },
        maxDs = 15,
        minDs = -5,
    },
}

--[[
    StepFix :   过关剩余目标偏移值
                0 表示最后一步过关
                大于0 表示 剩N步 过关
                小于0 表示 差N步 过关
                
    StepFix 干预维度不再以 “单关统计难度” 作为调节目标，而是以 “单关剩余步数”为调节目标；
    换句话说，这个模式下，算法更关心追线的及时性，更关心Fuuu率
    此算法不考虑保底功能，即它在设计上不考虑需要极限压低难度到1的诉求，遇到难关，它的最大强度可能不能把难度压到1，但是对于失败时的fuuu率更加可控。 
    相较于成功过关时，剩余步数准不准，算法更关心失败时的虚拟步数差值准不准

]]
local _adjustConfigByStepFixMap = {
    [0] = {
        lineFix = 0,        --平移期望线
        defaultDsFix = 0,   --ds强度整体偏移
        stepDiffFix = {     --不同step区间内，ds的偏移值
            {stepDiff = 3, rate = 4, dsFix = 1},
            {stepDiff = 5, rate = 10, dsFix = 2},
            {stepDiff = 10, rate = 15, dsFix = 1},
        },
        maxDs = 15,
        minDs = -5,
    },
}

local _debug = false
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


function UBFuuuDiffLogic:onStartLevel(levelContext)
    -- local levelContextRawData = levelContext:getRawData()
    -- adjustData

    local levelContextRawData = levelContext:getRawData() --为了减少开销，使用rawData计算

    local adJustRawData = levelContextRawData[UBFLevelContext.adjustDataKey]

    -- if _debug then printx(1, "UBFuuuDiffLogic:onStartLevel preAddSteps =", preAddSteps, "addSteps =", addSteps ) end

    local _dcDataRaw = levelContext:getValue( UBFLevelContext.dcDataKey )
    if not _dcDataRaw.UBFuuu then
        _dcDataRaw.UBFuuu = {}
    end
    
    _dcDataRaw.UBFuuu.payTag = adJustRawData.payTag
    _dcDataRaw.UBFuuu.activityTag = adJustRawData.activityTag
    _dcDataRaw.UBFuuu.usedPreAddStep = adJustRawData.usedPreAddStep
    _dcDataRaw.UBFuuu.useOtherPreProp = adJustRawData.useOtherPreProp

    _dcDataRaw.UBFuuu.selfFeedbackCollect = adJustRawData.selfFeedbackCollect
    _dcDataRaw.UBFuuu.feedbackSelected = adJustRawData.feedbackSelected
    _dcDataRaw.UBFuuu.upK = adJustRawData.upK
    _dcDataRaw.UBFuuu.lowK = adJustRawData.lowK
    _dcDataRaw.UBFuuu.feedpath = adJustRawData.feedpath

    _dcDataRaw.UBFuuu.passCollectByUseProp = adJustRawData.passCollectByUseProp

    _dcDataRaw.UBFuuu.ubfuuCheckResult = adJustRawData.ubfuuCheckResult

end

function UBFuuuDiffLogic:calcPredictDeviation_old(gameBoardLogic, adJustRawData, lineFix, moveCount, staticMoveCount, preAddSteps)

    local deviation, deviationData = nil, nil

    local _fixedMoveCount = moveCount

    local _needLockDeviation = false
    local _lockedDeviation = nil

    local fixedLineFix = lineFix
    local _lineFixUp = math.ceil(lineFix) 
    local _lineFixDown = math.floor(lineFix) 
    if _lineFixUp ~= _lineFixDown then
        local levelContext = gameBoardLogic:getLevelContext()
        local boardContext = levelContext:getBoardContext(1)
        local randomSeed = boardContext:nextSeed("UBFuuu")

        fixedLineFix = self:randomByUpLowNumber(_lineFixDown, _lineFixUp, lineFix, randomSeed)
    end



    local function fixByEndAddStep()
        --在使用加5步后，停用干预
        if moveCount >= staticMoveCount + preAddSteps then
            adJustRawData.enableAdjust = false 
        end
    end

    local function fixMoveCount_G461()
        if moveCount >= staticMoveCount and moveCount <= staticMoveCount + preAddSteps then
            _fixedMoveCount = staticMoveCount
        end
    end

    if preAddSteps > 0 then --使用了前置加步数道具
        fixMoveCount_G461()
    end
    fixByEndAddStep()

   

    if _fixedMoveCount <= 0 then _fixedMoveCount = 1 end
    _fixedMoveCount = _fixedMoveCount + fixedLineFix

    if _debug then printx(1, "UBFuuuDiffLogic:calcPredictDeviation   moveCount =",moveCount, "staticMoveCount =", staticMoveCount, "alineFix =", fixedLineFix, "preAddSteps =" , preAddSteps, "_fixedMoveCount =",_fixedMoveCount ) end

    -- if _fixedMoveCount > staticMoveCount then _fixedMoveCount = staticMoveCount end
    if _lockedDeviation then
        deviation = _lockedDeviation.deviation
        deviationData = _lockedDeviation
    else
        -- if _debug then printx(1, "UBFuuuDiffLogic:calcPredictDeviation  gameBoardLogic.fuuuGraphLogicId --> getFuuuDeviation   ", "_fixedMoveCount =",_fixedMoveCount ) end
        deviation, deviationData = gameBoardLogic:callById( gameBoardLogic.fuuuGraphLogicId , "getFuuuDeviation" , true , true, _fixedMoveCount )
        -- if _debug then printx(1, "UBFuuuDiffLogic:calcPredictDeviation  gameBoardLogic.fuuuGraphLogicId --> deviationData =   ", tts(deviationData) ) end
    end

    if _needLockDeviation then
        adJustRawData.lockedDeviation = { deviation = deviationData.deviation, progress = deviationData.progress, expect = deviationData.expect }
    end

    if not deviation then
        deviation, deviationData = gameBoardLogic:callById( gameBoardLogic.fuuuGraphLogicId , "getFuuuDeviation" , true , false )
    end

    local resultData = {}

    resultData.deviation = deviationData.deviation
    resultData.curProgress = deviationData.progress
    resultData.currExpect = deviationData.expect

    if moveCount >= staticMoveCount and moveCount < staticMoveCount + preAddSteps then
        resultData.currExpect = 1 + (moveCount - staticMoveCount) / staticMoveCount
        resultData.deviation = (resultData.currExpect - resultData.curProgress) / resultData.currExpect
    end

    if _debug then printx( 1 , "UBFuuuDiffLogic:calcPredictDeviation -----------  staticMoveCount:" , staticMoveCount , "moveCount:" , moveCount ,"preAddSteps:",preAddSteps, 
                                "\n currExpect :", resultData.currExpect, "curProgress :", resultData.curProgress, "deviation :" , resultData.deviation ) end
    
    return resultData
end

function UBFuuuDiffLogic:randomByUpLowNumber( lowNum, upNum, tarNum, randomSeed )
    -- upNum = 4
    -- tarNum = 3.8
    -- lowNum = 3

    local lowDiffV = tarNum - lowNum --0.8
    local upDiffV =  upNum - tarNum --0.2

    local _r = upDiffV / (upDiffV + lowDiffV) --差值越大，随机到的概率越低
    -- _r = ( 0.2 / ( 0.2 + 0.8 ) )
    -- _r = 0.2
    
    if _debug then printx(1,"UBFuuuDiffLogic:randomByUpLowNumber ----------  lowNum:", lowNum, "upNum:", upNum,"tarNum:",tarNum, "randomSeed:", randomSeed, "lowDiffV:", lowDiffV, "upDiffV:", upDiffV) end

    local _random = nil
    if randomSeed then
        _random = UBFRandom:calcValue(randomSeed, 1, 1000) / 1000
    else
        _random = math.random()
    end
    
    if _debug then printx(1,"UBFuuuDiffLogic:randomByUpLowNumber ----------  _r = 1 - (upDiffV / (upDiffV + lowDiffV) = " , _r , "  _random =" , _random ) end

    -- _random > 0.99673
    local _resultNum = nil

    if _random > _r then
        _resultNum = upNum
    else
        _resultNum = lowNum
    end

    if _debug then printx(1,"UBFuuuDiffLogic:randomByUpLowNumber ----------  _resultNum:" , _resultNum) end

    return _resultNum
end

function UBFuuuDiffLogic:__calculateMaxDiffMove(gameBoardLogic, moveCount, staticMoveCount, fixedMoveCount, adJustRawData)

    local resultMap = nil

    local _fixedMove = moveCount

    if fixedMoveCount then 
        _fixedMove = fixedMoveCount 
    end

    if _fixedMove > staticMoveCount then 
        _fixedMove = staticMoveCount 
    end

    if fixedMoveCount then
        resultMap = gameBoardLogic:callById(gameBoardLogic.fuuuGraphLogicId , "calculateTargetStepDiff", true, _fixedMove)
    else
        resultMap = gameBoardLogic:callById(gameBoardLogic.fuuuGraphLogicId , "calculateTargetStepDiff")
    end
    
    
    local maxDiffMove = nil
    local maxDiffMoveTargetId = nil

    local _testDiffMove = 0
    local _c = 0

    -- if _debug then printx( 1 , "[U5] UBFuuuDiffLogic:__calculateMaxDiffMove  resultMap:", tts(resultMap) ) end

    if adJustRawData then
        printx(1, "adJustRawData.ubfuuCheckResult.stepFixEnable:" , adJustRawData.ubfuuCheckResult and adJustRawData.ubfuuCheckResult.stepFixEnable or "nil" )
        printx(1, "adJustRawData.ubfuuCheckResult.desiredStep:" , adJustRawData.ubfuuCheckResult and adJustRawData.ubfuuCheckResult.desiredStep or "nil" )
    end
    
    if resultMap and resultMap.targetStepDiff then

        
        for target_id, step in pairs( resultMap.targetStepDiff ) do
            
            -- step是当前搜集物的预期搜集步数（带小数）
            
            if _debug then printx( 1 , "[U5] UBFuuuDiffLogic:__calculateMaxDiffMove  target_id:", target_id, "step:" , step ) end
            if not maxDiffMoveTargetId then
                maxDiffMoveTargetId = target_id
                maxDiffMove = _fixedMove - step
            end

            if _fixedMove - step > maxDiffMove then
                maxDiffMoveTargetId = target_id
                maxDiffMove = _fixedMove - step
            end
            
            _testDiffMove = _testDiffMove + (_fixedMove - step)
            _c = _c + 1
        end

        -- if adJustRawData.ubfuuCheckResult and adJustRawData.ubfuuCheckResult.diffMoveMode == 1 then
        if adJustRawData and adJustRawData.ubfuuCheckResult and adJustRawData.ubfuuCheckResult.stepFixEnable then
            -- test
            -- maxDiffMove = _testDiffMove / _c
        end
    end

    if _debug then printx( 1 , "[U5] UBFuuuDiffLogic:__calculateMaxDiffMove  maxDiffMoveTargetId:", maxDiffMoveTargetId, "maxDiffMove:", maxDiffMove ) end
    -- maxDiffMove 期望步数 - 当前玩家步数 的差值，
    -- maxDiffMove 为 负数 意味着玩家超出预期，正数 表示不到预期

    if _debug then

        local m1 = "X"
        if maxDiffMove then
            m1 = math.floor(maxDiffMove * 100 + 0.5)/100
        end
        
        table.insert( _G.UBFuuuDebugCore.showPrintInfo, LevelProgressLogic:getTargetNameById(maxDiffMoveTargetId) .. ":" .. tostring(m1) )
    end

    return { maxDiffMove = maxDiffMove, maxDiffMoveTargetId = maxDiffMoveTargetId, detail = resultMap and resultMap.targetStepDiff }
end

-- 计算后置加步区间的基础贡献值。
-- 后置区间的 kAddMaxDiffMoveByStep 从 1 开始递增；如果 stackingPreValue=true，
-- 需要先加上前置区间已经贡献过的值，让后置加步接着前置加步继续累加。
-- 例：无前置加步时基础贡献为 0，后置第 1 步为 +1。
-- 例：旧逻辑前置 3 步贡献到 +3，后置第 1 步为 +4。
-- 例：step_item_adjust 弱化前置 3 步贡献到 +1，后置第 1 步为 +2。
local function calculatePostBaseContribution(preAddStepIntervalFix, preAddStepCount)
    if type(preAddStepCount) ~= "number" or preAddStepCount <= 0 then
        return 0
    end

    local preAddStepCountInt = math.floor(preAddStepCount)
    if not preAddStepIntervalFix then
        return preAddStepCountInt
    end

    if preAddStepIntervalFix.addStepAdjustMode == UBFuuuAddStepAdjustMode.kAddMaxDiffMoveByStep then
        local availableSteps = preAddStepIntervalFix.availableSteps
        if type(availableSteps) == "number" then
            return math.min(preAddStepCountInt, availableSteps)
        end
    elseif preAddStepIntervalFix.addStepAdjustMode == UBFuuuAddStepAdjustMode.kAddMaxDiffMoveByFixedValue then
        local targetMaxdiffMove = preAddStepIntervalFix.targetMaxdiffMove
        if type(targetMaxdiffMove) == "number" then
            return targetMaxdiffMove
        end
    elseif preAddStepIntervalFix.addStepAdjustMode == UBFuuuAddStepAdjustMode.kLockMaxDiffMove then
        local targetMaxdiffMove = preAddStepIntervalFix.targetMaxdiffMove
        if type(targetMaxdiffMove) == "number" then
            return targetMaxdiffMove
        end
    end

    return 0
end

-- 判断当前区间配置是否覆盖当前步。
local function isAddStepIntervalFixActive(intervalFixConfig, stepIndexInInterval)
    if not intervalFixConfig then
        return false
    end

    local availableSteps = intervalFixConfig.availableSteps
    if type(availableSteps) == "number" and (stepIndexInInterval < 0 or stepIndexInInterval >= availableSteps) then
        return false
    end

    return true
end


function UBFuuuDiffLogic:calculateDeviation(gameBoardLogic, adJustRawData, lineFix, moveCount, staticMoveCount, preAddSteps)

    local resultData = {}

    local _fixedMoveCount = math.min( moveCount, staticMoveCount )

    local fixedLineFix = lineFix
    local _lineFixUp = math.ceil(lineFix) 
    local _lineFixDown = math.floor(lineFix) 
    if _lineFixUp ~= _lineFixDown then

        local levelContext = gameBoardLogic:getLevelContext()
        local boardContext = levelContext:getBoardContext(1)
        local randomSeed = boardContext:nextSeed("UBFuuu")

        fixedLineFix = self:randomByUpLowNumber(_lineFixDown, _lineFixUp, lineFix, randomSeed)
    end
    
    
    local maxDiffMove = nil
    local fixedMaxDiffMove = nil

    if _debug then
        table.insert( _G.UBFuuuDebugCore.showPrintInfo, tostring(moveCount) .. "," )
    end

    maxDiffMove = self:__calculateMaxDiffMove(gameBoardLogic, moveCount, staticMoveCount, nil, adJustRawData).maxDiffMove
    fixedMaxDiffMove = maxDiffMove or 0

    if _debug then printx( 1 , "[U5] UBFuuuDiffLogic:calculateDeviation  fixedMaxDiffMove:", fixedMaxDiffMove, "maxDiffMove:", maxDiffMove, "preAddSteps:", preAddSteps ) end

    local _needLockDeviation = false
    local _preAddStepIntervalFix = nil
    local _postAddStepIntervalFix = nil
    local _adjustFixInfo = adJustRawData.ubfuuCheckResult and adJustRawData.ubfuuCheckResult.adjustFixInfo
    -- preAddSteps 来自外部关卡流程，这里只保留非负整数用于划分前置/后置加步区间。
    local _preAddStepCount = type(preAddSteps) == "number" and math.max(0, math.floor(preAddSteps)) or 0

    if _adjustFixInfo then
        _preAddStepIntervalFix = _adjustFixInfo[UBFuuuFixType.kPreAddStepIntervalFix]
        _postAddStepIntervalFix = _adjustFixInfo[UBFuuuFixType.kPostAddStepIntervalFix]
    end

    local _postBaseContribution = calculatePostBaseContribution(_preAddStepIntervalFix, _preAddStepCount)

    if _debug then
        UBFLogD( "[U5] UBFuuuDiffLogic:calculateDeviation  preAddFixMode:", _preAddStepIntervalFix and _preAddStepIntervalFix.addStepAdjustMode or "nil",
                    "preAddAvailableSteps:", _preAddStepIntervalFix and _preAddStepIntervalFix.availableSteps or "nil",
                    "postAddFixMode:", _postAddStepIntervalFix and _postAddStepIntervalFix.addStepAdjustMode or "nil",
                    "postAddAvailableSteps:", _postAddStepIntervalFix and _postAddStepIntervalFix.availableSteps or "nil",
                    "postBaseContribution:", _postBaseContribution )
    end

    if moveCount >= staticMoveCount then
        local _activeFixType = nil
        local _addStepIndexAfterStaticMove = moveCount - staticMoveCount

        -- 静态步数后的前 preAddStepCount 步属于前置加步区间。
        if _preAddStepCount > 0 and _addStepIndexAfterStaticMove >= 0 and _addStepIndexAfterStaticMove < _preAddStepCount then
            _activeFixType = UBFuuuFixType.kPreAddStepIntervalFix
            if isAddStepIntervalFixActive(_preAddStepIntervalFix, _addStepIndexAfterStaticMove) then
                local _preAddStepAdjustMode = _preAddStepIntervalFix.addStepAdjustMode
                if _preAddStepAdjustMode == UBFuuuAddStepAdjustMode.kDoNothing then
                    -- 配置明确要求前置加步区间不干预。
                    fixedMaxDiffMove = 0
                    adJustRawData.enableAdjust = false
                elseif _preAddStepAdjustMode == UBFuuuAddStepAdjustMode.kLockLastDs then
                    -- 沿用旧活动语义：本步计算出的 deviation 作为后续 lockedDeviation。
                    _needLockDeviation = true
                elseif _preAddStepAdjustMode == UBFuuuAddStepAdjustMode.kLockMaxDiffMove then
                    -- 锁定到固定 MaxDiffMove 目标值。
                    if type(_preAddStepIntervalFix.targetMaxdiffMove) == "number" then
                        fixedMaxDiffMove = _preAddStepIntervalFix.targetMaxdiffMove
                    end
                elseif _preAddStepAdjustMode == UBFuuuAddStepAdjustMode.kAddMaxDiffMoveByFixedValue then
                    -- step_item_adjust 前置弱化使用这个模式，把前置加步每一步都固定贡献同一个值。
                    if type(_preAddStepIntervalFix.targetMaxdiffMove) == "number" then
                        fixedMaxDiffMove = fixedMaxDiffMove + _preAddStepIntervalFix.targetMaxdiffMove
                    end
                elseif _preAddStepAdjustMode == UBFuuuAddStepAdjustMode.kAddMaxDiffMoveByStep then
                    -- 按前置区间内第几步递增贡献；如配置要求，也允许叠加 postBaseContribution。
                    local _stepContribution = _addStepIndexAfterStaticMove + 1
                    if _preAddStepIntervalFix.stackingPreValue == true then
                        _stepContribution = _stepContribution + _postBaseContribution
                    end
                    fixedMaxDiffMove = fixedMaxDiffMove + _stepContribution
                end
            else
                -- 前置区间配置不存在或未覆盖当前步时，保持旧逻辑：第 1/2/3 步分别贡献 +1/+2/+3。
                fixedMaxDiffMove = fixedMaxDiffMove + _addStepIndexAfterStaticMove + 1
            end
        else
            -- 前置区间结束后进入后置加步区间；无后置配置时沿用旧逻辑关闭调节。
            local _postIntervalStepIndex = moveCount - staticMoveCount - _preAddStepCount
            _activeFixType = UBFuuuFixType.kPostAddStepIntervalFix
            if isAddStepIntervalFixActive(_postAddStepIntervalFix, _postIntervalStepIndex) then
                local _postAddStepAdjustMode = _postAddStepIntervalFix.addStepAdjustMode
                if _postAddStepAdjustMode == UBFuuuAddStepAdjustMode.kDoNothing then
                    -- 配置明确要求后置加步区间不干预。
                    fixedMaxDiffMove = 0
                    adJustRawData.enableAdjust = false
                elseif _postAddStepAdjustMode == UBFuuuAddStepAdjustMode.kLockLastDs then
                    -- 沿用旧活动语义：本步计算出的 deviation 作为后续 lockedDeviation。
                    _needLockDeviation = true
                elseif _postAddStepAdjustMode == UBFuuuAddStepAdjustMode.kLockMaxDiffMove then
                    if type(_postAddStepIntervalFix.targetMaxdiffMove) == "number" then
                        fixedMaxDiffMove = _postAddStepIntervalFix.targetMaxdiffMove
                    end
                elseif _postAddStepAdjustMode == UBFuuuAddStepAdjustMode.kAddMaxDiffMoveByFixedValue then
                    if type(_postAddStepIntervalFix.targetMaxdiffMove) == "number" then
                        fixedMaxDiffMove = fixedMaxDiffMove + _postAddStepIntervalFix.targetMaxdiffMove
                    end
                elseif _postAddStepAdjustMode == UBFuuuAddStepAdjustMode.kAddMaxDiffMoveByStep then
                    -- 后置区间按步递增；stackingPreValue=true 时接着前置区间贡献继续累加。
                    local _stepContribution = _postIntervalStepIndex + 1
                    if _postAddStepIntervalFix.stackingPreValue == true then
                        _stepContribution = _stepContribution + _postBaseContribution
                    end
                    fixedMaxDiffMove = fixedMaxDiffMove + _stepContribution
                end
            else
                -- 后置区间配置不存在或未覆盖当前步时，保持旧逻辑：关闭 fuuu 调节。
                fixedMaxDiffMove = 0
                adJustRawData.enableAdjust = false
            end
        end

        if _activeFixType == UBFuuuFixType.kPreAddStepIntervalFix then
            if _debug then printx( 1 , "[U5] UBFuuuDiffLogic:calculateDeviation  61.1 fixedMaxDiffMove:", fixedMaxDiffMove, "moveCount:", moveCount, "staticMoveCount:", staticMoveCount ) end
            if _debug then printx( 1 , "[U5] UBFuuuDiffLogic:calculateDeviation  61.1.2 fixedMaxDiffMove:", fixedMaxDiffMove ) end
        elseif _activeFixType == UBFuuuFixType.kPostAddStepIntervalFix then
            if _preAddStepCount > 0 then
                if _debug then printx( 1 , "[U5] UBFuuuDiffLogic:calculateDeviation  61.2 fixedMaxDiffMove:", fixedMaxDiffMove ) end
            else
                if _debug then printx( 1 , "[U5] UBFuuuDiffLogic:calculateDeviation  61.3 fixedMaxDiffMove:", fixedMaxDiffMove ) end
            end
        end
    end

    resultData.fixedDiffMove1 = fixedMaxDiffMove

    local levelContext = gameBoardLogic:getLevelContext()
    if levelContext then
        local _dcDataRaw = levelContext:getValue( UBFLevelContext.dcDataKey )
        if not _dcDataRaw.UBFuuu then
            _dcDataRaw.UBFuuu = {}
        end

        if moveCount == staticMoveCount then
            _dcDataRaw.UBFuuu.maxDiffMoveOnStepN0 = maxDiffMove
            _dcDataRaw.UBFuuu.fixedMaxDiffMoveOnStepN0 = fixedMaxDiffMove
        elseif _preAddStepCount > 0 and moveCount == staticMoveCount + _preAddStepCount then
            _dcDataRaw.UBFuuu.maxDiffMoveOnStepN3 = maxDiffMove
            _dcDataRaw.UBFuuu.fixedMaxDiffMoveOnStepN3 = fixedMaxDiffMove
        end
    end

    if _debug then printx( 1 , "[U5] UBFuuuDiffLogic:calculateDeviation  S1 fixedMaxDiffMove:", fixedMaxDiffMove ) end
    fixedMaxDiffMove = fixedMaxDiffMove + fixedLineFix
    if _debug then printx( 1 , "[U5] UBFuuuDiffLogic:calculateDeviation  S2 fixedMaxDiffMove:", fixedMaxDiffMove, "lineFix:", fixedLineFix ) end
    

    resultData.originDiffMove = maxDiffMove
    resultData.lineFix = fixedLineFix
    resultData.diffMove = fixedMaxDiffMove
    resultData.currExpect = _fixedMoveCount / staticMoveCount
    resultData.curProgress = (_fixedMoveCount - fixedMaxDiffMove) / staticMoveCount

    local _diffmove = math.abs(fixedMaxDiffMove) 
    if _diffmove > staticMoveCount then
        _diffmove = staticMoveCount
    end

    if adJustRawData.lockedDeviation then
        resultData.deviation = adJustRawData.lockedDeviation
    else
        if fixedMaxDiffMove > 0 then
            resultData.deviation = _diffmove / staticMoveCount
        else
            resultData.deviation = _diffmove / staticMoveCount * -1
        end
    end

    if _needLockDeviation then
        adJustRawData.lockedDeviation = resultData.deviation
    else
        adJustRawData.lockedDeviation = nil
    end

    if _debug then printx( 1 , "[U5] UBFuuuDiffLogic:calculateDeviation  ===========  staticMoveCount:" , staticMoveCount , "moveCount:" , moveCount ,"preAddSteps:",preAddSteps, 
                                "resultData =" , tts(resultData) ) end
    
    if _debug then
        local mf = math.floor(resultData.diffMove * 100 + 0.5)/100
        table.insert( _G.UBFuuuDebugCore.showPrintInfo, "_" .. tostring(mf)  )
    end
    
    return resultData
end


function UBFuuuDiffLogic:_getConfigSet(adJustRawData)
    local _configSet = nil

    local _configSetMap = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.configs.UBFuuuDiffLogicConfigSetMap"

    if adJustRawData.ubfuuCheckResult and adJustRawData.ubfuuCheckResult.stepFixEnable then
        _configSet = _configSetMap.stepFixMap[adJustRawData.ubfuuCheckResult.stepFix]
    else
        _configSet = _configSetMap.diffFixMap[adJustRawData.diffFix]
    end
    return _configSet
end


function UBFuuuDiffLogic:onEnterWaiting(gameBoardLogic, levelContext)
    local levelContextRawData = levelContext:getRawData() --为了减少开销，使用rawData计算

    local adJustRawData = levelContextRawData[UBFLevelContext.adjustDataKey]
    local _leagueContextRaw = levelContextRawData[UBFConst.ContextType.kLeagueContext]
    
    local moveCount = _leagueContextRaw.moveCount
    local moveCountWithRevert = _leagueContextRaw.moveCountWithRevert
    local staticMoveCount = _leagueContextRaw.staticMoveCount
    
    local _addStepSource = _leagueContextRaw.addStepSource

    local stepRawList = levelContextRawData[UBFConst.ContextType.kStepContext]
    local currStepAdjustData = stepRawList[moveCountWithRevert].adjustData
    
    
    
    local _configSet = self:_getConfigSet(adJustRawData)

    if not _configSet then
        --todo
        return
    end

    local preAddSteps = _addStepSource.bySourceMap[UBFModSourceIdEnum.kPreProp] or 0
    local addSteps = _addStepSource.bySourceMap[UBFModSourceIdEnum.kProp] or 0

    -- local preAddSteps = _addStepSource.bySourceMap[UBFModSourceIdEnum.kPreProp] or 0

    if _debug then printx(1, "UBFuuuDiffLogic:onEnterWaiting preAddSteps =", preAddSteps, "addSteps =", addSteps, "moveCount =", moveCount ) end

    local _dcDataRaw = levelContext:getValue( UBFLevelContext.dcDataKey )
    if not _dcDataRaw.UBFuuu then
        _dcDataRaw.UBFuuu = {}
    end

    if _dcDataRaw.UBFuuu.fuuuGraphV3Enable == nil then
        if gameBoardLogic:callById( gameBoardLogic.fuuuGraphLogicId , "isProgressPredict" ) then
            _dcDataRaw.UBFuuu.fuuuGraphV3Enable = true
        else
            _dcDataRaw.UBFuuu.fuuuGraphV3Enable = false
        end
    end
    
    _dcDataRaw.UBFuuu.preAddSteps = preAddSteps
    _dcDataRaw.UBFuuu.addSteps = addSteps
    _dcDataRaw.UBFuuu.diffFix = adJustRawData.diffFix
    _dcDataRaw.UBFuuu.tarDiff = adJustRawData.tarDiff
    if adJustRawData.ubfuuCheckResult then
        _dcDataRaw.UBFuuu.stepFix = adJustRawData.ubfuuCheckResult.stepFix
    end
    

    if _debug then printx(1, "UBFuuuDiffLogic:onEnterWaiting _dcDataRaw =", tts(_dcDataRaw) ) end
    ------------ 平移期望线 ----------
    --[[
    {
        changeColorCount = 15,
        curProgress = 0.14285714285714,
        currExpect = 0.10714285714286,
        currRate = -25,
        deviation = -0.25,
        dropBird = 0,
        dropEff = 0,
        dropNum = 75,
        fixedRateChange = 0,
        maxColorIndex = 5,
        originDeviation = -0.092592592592593,
        originExpect = 0.12962962962963,
        originProgress = 0.14285714285714,
        rateCList = {
        },
        rateCVList = {
        },
        resultColorMap = {
            [1] = 0,
            [2] = 0,
            [3] = 15,
            [4] = 11,
            [5] = 34,
            [6] = 15,
        },
        step = 1,
        totalStep = 28,
    }
    ]]

    adJustRawData.enableAdjust = true

    local deviationData = nil

    if _configSet then
        deviationData = self:calculateDeviation(gameBoardLogic, adJustRawData, _configSet.lineFix, moveCount, staticMoveCount, preAddSteps)
    end

    if not deviationData then
        deviationData = self:calcPredictDeviation_old(gameBoardLogic, adJustRawData, _configSet.lineFix, moveCount, staticMoveCount, preAddSteps)
        if not _G.calcPredictDeviation_old_errror then
            _G.calcPredictDeviation_old_errror = true
            local _gameEnv = levelContext:getGameEnv() or {}
            he_log_error("ubfuuu_use_old_line_" .. tostring(_gameEnv.levelId) )
        end
    end

    currStepAdjustData.deviation = deviationData.deviation
    currStepAdjustData.curProgress = deviationData.curProgress
    currStepAdjustData.currExpect = deviationData.currExpect

    currStepAdjustData.currRate = math.floor( currStepAdjustData.deviation * 100 + 0.000001 )

    currStepAdjustData.originDiffMove = deviationData.originDiffMove
    currStepAdjustData.fixedDiffMove1 = deviationData.fixedDiffMove1
    currStepAdjustData.diffMove = deviationData.diffMove

    -- currStepAdjustData.rateChangeSpeed = 0
    if _debug then 
        printx( 1 , "UBFuuuDiffLogic:onEnterWaiting ----------- 111  moveCountWithRevert:" , moveCountWithRevert , "diffFix:" , adJustRawData.diffFix, "currRate:" , currStepAdjustData.currRate )
    end
    -- 1 2 3 4 5  6  7  8  9  10 11 12 13 14 15 16 17 18 19 20 21  22  23
    -- 0 1 4 7 18 39 45 46 35 23 25 15 5  12 9  7  14 3  -5 9  -3  10  5
    
    local rateChangValueList = {}
    local rateChangList = {}
    -- local rateList = {}
    
    local _cRate = currStepAdjustData.currRate
    -- table.insert( rateList, _cRate )

    for n = 1 , 4 do
        local _stepData = stepRawList[moveCountWithRevert - n]
        local _stepAdjustData = _stepData and _stepData.adjustData
        -- printx(1, "UBFuuuDiffLogic:onEnterWaiting   moveCountWithRevert:",moveCountWithRevert," ---------- index:",moveCountWithRevert - n,"_stepAdjustData:",_stepAdjustData)
        if moveCountWithRevert - n > 0 and _stepAdjustData then
            -- printx(1, "_stepAdjustData =", tts(_stepAdjustData) )
            local _rate = _stepAdjustData.currRate
            -- printx( 1 , "_cRate =" , _cRate, "_rate =" , _rate)
            -- printx( 1 , "_cRate - _rate =" , _cRate - _rate) 
            -- printx( 1 , "(_cRate - _rate)/_rate =" , (_cRate - _rate)/_rate)
            local _dv = _cRate - _rate
            table.insert( rateChangValueList, _dv )
            if _rate == 0 then
                if _dv > 50 then
                    table.insert( rateChangList, 1.6 )
                elseif _dv > 20 then
                    table.insert( rateChangList, 1.3 )
                elseif _dv > 5 then
                    table.insert( rateChangList, 1.1 )
                else
                    table.insert( rateChangList, 1 )
                end
            else
                table.insert( rateChangList, (_cRate - _rate)/_rate )
            end
            
            -- table.insert( rateList, _rate )
            _cRate = _rate
        end
    end
    
    local _tv = 0
    for k,v in ipairs(rateChangList) do
        _tv = _tv + v * _kvmap[k]
    end
    
    -- fixed_rate_change
    local fixedRateChange = _tv / #rateChangList
    if #rateChangList == 0 then fixedRateChange = 0 end

    currStepAdjustData.rateCVList = rateChangValueList
    currStepAdjustData.rateCList = rateChangList
    currStepAdjustData.fixedRateChange = fixedRateChange
    -- currStepAdjustData.rateList = rateList
    if _debug then 
        printx( 1 , "[U5] UBFuuuDiffLogic:onEnterWaiting ----------- 222  currStepAdjustData:" , tts(currStepAdjustData) )
    end
end



-- 基于当前盘面和历史信息，计算currDs
-- currDs 预期为一个 -100 ~100 的整数，正数表示进行正向干预，数值越大越强；负数表示负向干预，数值越大越强
function UBFuuuDiffLogic:calculateCurrDs(levelContext)
    
    local currDs = 0

    local levelContextRawData = levelContext:getRawData() --为了减少开销，使用rawData计算

    local adJustRawData = levelContextRawData[UBFLevelContext.adjustDataKey]
    local _leagueContextRaw = levelContextRawData[UBFConst.ContextType.kLeagueContext]
    local moveCountWithRevert = _leagueContextRaw.moveCountWithRevert
    local _staticMove = _leagueContextRaw.staticMoveCount
    local _addStepSource = _leagueContextRaw.addStepSource

    local _tarDiff = adJustRawData.tarDiff
    local _diffFix = adJustRawData.diffFix
    
    local _configSet = self:_getConfigSet(adJustRawData)
    if not _configSet then
        if _debug then printx( 1 , "UBFuuuDiffLogic:calculateCurrDs  Return 333  _adjustConfigByDiffFixMap[_diffFix] is nil,  _diffFix =" , _diffFix ) end
        --todo 
        return nil
    end
    

    if moveCountWithRevert == 0 then
        -- return {currDs = 5, dsP1 = 5, dsP2 = 5}
        if _debug then printx( 1 , "UBFuuuDiffLogic:calculateCurrDs  Return 111  moveCountWithRevert:" , moveCountWithRevert ) end
        return nil
    end

    if not adJustRawData.enableAdjust then
        if _debug then printx( 1 , "UBFuuuDiffLogic:calculateCurrDs  Return 222  enableAdjust:" , adJustRawData.enableAdjust ) end
        return nil
    end

    local stepRawList = levelContextRawData[UBFConst.ContextType.kStepContext]
    local currStepAdjustData = stepRawList[moveCountWithRevert].adjustData

    if _debug then
        printx( 1 , "================================================================== \nmoveCountWithRevert = " , moveCountWithRevert)
        printx( 1 , "adJustRawData = " , tts(adJustRawData))
        printx( 1 , "currStepAdjustData = " , tts(currStepAdjustData))
    end
    

    -- local _rate = math.floor( currStepAdjustData.currRate * 100 )
    local lastStepAdjustData = nil
    if moveCountWithRevert-1 > 0 and stepRawList[moveCountWithRevert-1] then
        lastStepAdjustData = stepRawList[moveCountWithRevert-1].adjustData
    end

    local _lastRate = 0
    local _lastCurrDs = 0
    local _lastDsP2 = 0
    if lastStepAdjustData then 
        _lastRate = lastStepAdjustData.currRate or 0
        _lastCurrDs = lastStepAdjustData.currDs or 0
        _lastDsP2 = lastStepAdjustData.dsP2 or 0
    end

    

    local _lastRateDiff = currStepAdjustData.rateCVList[1] or 0
    
    local _currRate = currStepAdjustData.currRate
    local _fixedRateChange = currStepAdjustData.fixedRateChange or 0
    
    

    
    if _debug then
        printx( 1 , "_currRate =" , _currRate, "_lastRate =", _lastRate , "_lastCurrDs =" , _lastCurrDs , "_fixedRateChange =" , _fixedRateChange)
        printx( 1 , "==================================================================\n")
    end

    local _ds1 = 0

    if _currRate > 0 then
        if _currRate <= 30 then
            _ds1 = math.ceil( (_currRate / 3) + 0.0001 )
        elseif _currRate <= 35 then
            _ds1 = 11
        elseif _currRate <= 40 then
            _ds1 = 12
        elseif _currRate <= 45 then
            _ds1 = 13
        elseif _currRate <= 50 then
            _ds1 = 14
        else
            _ds1 = 15
        end
    else
        if _currRate < -30 then
            _ds1 = -5
        elseif _currRate < -20 then
            _ds1 = -4
        elseif _currRate < -15 then
            _ds1 = -3
        elseif _currRate < -10 then
            _ds1 = -2
        elseif _currRate < -5 then
            _ds1 = -1
        end
    end

    local rateDiff = _currRate - _lastRate

    if _debug then printx( 1 , "_currRate - _lastRate =" , _currRate - _lastRate, "  _lastRateDiff =", _lastRateDiff, "_ds1 =======" , _ds1 ) end

    -- local lastR1 = _lastRate / _lastCurrDs

    

    local _tab1 = {
        { {0,5}, {0,10}, 1 },
        { {0,5}, {10,30}, 1 },
        { {0,5}, {30,999}, 2 },

        { {5,10}, {0,10}, 1 },
        { {5,10}, {10,30}, 2 },
        { {5,10}, {30,999}, 2 },

        { {10,20}, {0,10}, 2 },
        { {10,20}, {10,30}, 3 },
        { {10,20}, {30,999}, 3 },

        { {20,999}, {0,10}, 3 },
        { {20,999}, {10,30}, 4 },
        { {20,999}, {30,999}, 5 },
    }
    local _tab2 = {
        { {0,5}, {-999,-30}, -2 },
        { {0,5}, {-30,-15}, -1 },

        { {5,10}, {-999,-30}, -2 },
        { {5,10}, {-30,-15}, -1 },

        { {10,20}, {-999,-30}, -1 },
        { {10,20}, {-30,-15}, -1 },

        { {20,999}, {-999,-30}, -1 },
        { {20,999}, {-30,-15}, 0 },
    }
    local _tab3 = {
        { {-5,0}, {0,10}, 0 },
        { {-5,0}, {10,30}, 0 },
        { {-5,0}, {30,999}, -1 },

        { {-15,-5}, {0,10}, 0 },
        { {-15,-5}, {10,30}, 0 },
        { {-15,-5}, {30,999}, -1 },

        { {-999,-15}, {0,10}, 0 },
        { {-999,-15}, {10,30}, -1 },
        { {-999,-15}, {30,999}, -2 },
    }
    local _tab4 = {
        { {-5,0}, {-999,-30}, -1 },
        { {-5,0}, {-30,-15}, 0 },

        { {-15,-5}, {-999,-30}, 1 },
        { {-15,-5}, {-30,-15}, 0 },

        { {-999,-15}, {-999,-30}, 2 },
        { {-999,-15}, {-30,-15}, 1 },
    }

    local _rateChangeSpeed = math.floor( (_fixedRateChange * 100) + 0.00001 )

    local function _check(configData, currRate, rateChangeSpeed)
        for k,v in ipairs(configData) do
            if currRate >= v[1][1] and currRate <= v[1][2] then
                if rateChangeSpeed >= v[2][1] and rateChangeSpeed <= v[2][2] then
                    if _debug then printx( 1 , "_check:" , v[3], "  currRate =", currRate, "rateChangeSpeed =" , rateChangeSpeed ) end
                    return v[3]
                end
            end
        end
        if _debug then printx( 1 , "_check:" , 0 ) end
        return 0
    end

    local _ds2 = 0

    if _currRate > 0 then
        if _rateChangeSpeed > 0 then
            _ds2 = _ds1 + _check(_tab1, _currRate, _rateChangeSpeed)
        else
            _ds2 = _ds1 + _check(_tab2, _currRate, _rateChangeSpeed)
        end
    else
        if _rateChangeSpeed > 0 then
            _ds2 = _ds1 + _check(_tab3, _currRate, _rateChangeSpeed)
        else
            _ds2 = _ds1 + _check(_tab4, _currRate, _rateChangeSpeed)
        end
    end

    
    if _debug then printx( 1 , "_ds2 ===========" , _ds2 ) end

    
    currDs = _ds2

    local _stepDiff = _staticMove - moveCountWithRevert

    local fixedDsFix = _configSet.defaultDsFix
    local _fixedDsFixUp = math.ceil(fixedDsFix) 
    local _fixedDsFixDown = math.floor(fixedDsFix) 

    if _fixedDsFixUp ~= _fixedDsFixDown then

        local boardContext = levelContext:getBoardContext(1)
        local randomSeed = boardContext:nextSeed("UBFuuu")

        fixedDsFix = self:randomByUpLowNumber(_fixedDsFixDown, _fixedDsFixUp, _configSet.defaultDsFix, randomSeed)
    end

    currDs = currDs + fixedDsFix

    if _debug then printx( 1 , "_ds3 ===========" , currDs, "_configSet.defaultDsFix =", _configSet.defaultDsFix, "fixedDsFix =", fixedDsFix ) end
    
    if _configSet.stepDiffFix then
        for k,v in ipairs(_configSet.stepDiffFix) do
            if _stepDiff <= v.stepDiff then
                if _currRate > v.rate then 
                    currDs = currDs + v.dsFix 
                    if _debug then printx( 1 , "_ds4 ===========" , currDs , "_currRate =" , _currRate, "v.rate =" , v.rate, "v.dsFix  =" , v.dsFix  ) end
                    break
                end
            end
        end
    end
    
    
    if currDs < (_configSet.minDs or minDsCount) then
        currDs = _configSet.minDs or minDsCount 
    end
    if currDs > (_configSet.maxDs or maxDsCount) then
        currDs = _configSet.maxDs or maxDsCount 
    end

    if _debug then printx( 1 , "_ds5 ===========" , currDs, "_configSet.minDs =", _configSet.minDs, "_configSet.maxDs =", _configSet.maxDs ) end

    local _dcDataRaw = levelContext:getValue( UBFLevelContext.dcDataKey )
    if not _dcDataRaw.UBFuuu then
        _dcDataRaw.UBFuuu = {}
    end

    if not _dcDataRaw.UBFuuu.stepsP then 
        _dcDataRaw.UBFuuu.diffFix = _diffFix
        _dcDataRaw.UBFuuu.tarDiff = _tarDiff
		_dcDataRaw.UBFuuu.lastProgress = 0
		_dcDataRaw.UBFuuu.lastProgress2 = 0 
		_dcDataRaw.UBFuuu.stepsP = {}
		_dcDataRaw.UBFuuu.stepsE = {}
		_dcDataRaw.UBFuuu.stepsR = {}
		_dcDataRaw.UBFuuu.stepsDs = {}
	end

    local preAddSteps = _addStepSource.bySourceMap[UBFModSourceIdEnum.kPreProp] or 0

    if moveCountWithRevert == _staticMove and _dcDataRaw.UBFuuu.lastProgress ~= 0 then
        _dcDataRaw.UBFuuu.lastProgress = currStepAdjustData.curProgress
    elseif moveCountWithRevert == _staticMove + preAddSteps and _dcDataRaw.UBFuuu.lastProgress2 ~= 0 then
        _dcDataRaw.UBFuuu.lastProgress2 = currStepAdjustData.curProgress
    end
    
    if currStepAdjustData.curProgress then
        _dcDataRaw.UBFuuu.stepsP[moveCountWithRevert] = math.floor( (currStepAdjustData.curProgress * 1000) / 1000 )
    end

    -- _dcDataRaw.UBFuuu.stepsE[moveCountWithRevert] = currStepAdjustData.currExpect
    _dcDataRaw.UBFuuu.stepsR[moveCountWithRevert] = _currRate
    _dcDataRaw.UBFuuu.stepsDs[moveCountWithRevert] = currDs

    if _debug then printx( 1 , "[U5]  UBFuuuDiffLogic:calculateCurrDs ====  Fin currDs:", currDs, "currRate:" ,_currRate ) end
    if _debug then table.insert( _G.UBFuuuDebugCore.showPrintInfo, " ds:" .. tostring(currDs) ) end

    return {currDs = currDs, dsP1 = _ds1, dsP2 = _ds2}
end

function UBFuuuDiffLogic:setCurrDs(levelContext, datas)
    local levelContextRawData = levelContext:getRawData() 
    local moveCountWithRevert = levelContextRawData[UBFConst.ContextType.kLeagueContext].moveCountWithRevert
    local stepRawList = levelContextRawData[UBFConst.ContextType.kStepContext]
    local currStepAdjustData = stepRawList[moveCountWithRevert].adjustData

    if datas then
        currStepAdjustData.dsP1 = datas.dsP1
        currStepAdjustData.dsP2 = datas.dsP2
        currStepAdjustData.currDs = datas.currDs
    else
        currStepAdjustData.dsP1 = 0
        currStepAdjustData.dsP2 = 0
        currStepAdjustData.currDs = 0
    end
    
end

-- 基于 currDs ，计算应该生效的 dataset
-- dataset 是一组参数集，用于控制生成口的掉落概率
function UBFuuuDiffLogic:tryGetCurrDatasetByDs(currDs)
    
    local falsifyConfig = require "ubf.UBFGamePlayScene.logics.sceneModules.gameMod.modFolder.diffAdjust.ubfuuu.configs.UBFuuuFalsifyConfig"

    --[[
    local test = {
        --ruleA 每次掉落一个有颜色的元素时，如果本回合已经掉落的目标色（C色）小于等于n，则有m的概率将其强行变为目标色（C色）
        ruleA_n1 = 3,
        ruleA_m1 = 60,
        ruleA_n2 = 5,
        ruleA_m2 = 55,
        ruleA_n3 = 10,
        ruleA_m3 = 50,
        ruleA_n4 = 9999,
        ruleA_m4 = 40,

        --ruleB 单个掉落口，每掉落n个元素，目标色（C色）的数量不超过m个
        ruleB_n1 = 5,
        ruleB_m1 = 5,
        ruleB_n2 = 10,
        ruleB_m2 = 7,
        ruleB_n3 = 15,
        ruleB_m3 = 10,
        ruleB_n4 = 20,
        ruleB_m4 = 15,

        --ruleC 全局掉落口，最近n步之内，目标色（C色）的干预次数不超过m个
        ruleC_n1 = 1,
        ruleC_m1 = 15,
        ruleC_n2 = 2,
        ruleC_m2 = 20,
        ruleC_n3 = 3,
        ruleC_m3 = 40,
        ruleC_n4 = 5,
        ruleC_m4 = 9999,
    }
    ]]

    local _ds = currDs
    if _ds < minDsCount then _ds = minDsCount end
    if _ds > maxDsCount then _ds = maxDsCount end

    if currDs > 0 then
        local _config = falsifyConfig["Positive"][_ds]
        if _debug then printx( 1 , "UBFuuuDiffLogic:tryGetCurrDatasetByDs 111 ===========" , _config, "ds:",_ds,"currDs:",currDs ) end
        return _config
    elseif currDs < 0 then
        local _config = falsifyConfig["Negative"][math.abs(_ds)]
        if _debug then printx( 1 , "UBFuuuDiffLogic:tryGetCurrDatasetByDs 222 ===========" , _config, "ds:",_ds,"currDs:",currDs ) end
        return _config
    end

    if _debug then printx( 1 , "UBFuuuDiffLogic:tryGetCurrDatasetByDs 333 =========== WTF !!   ", "ds:",currDs ) end
    return nil
end

function UBFuuuDiffLogic:getProgressPercent(gameBoardLogic)
    local moveCount = gameBoardLogic:leagueCall( "getMoveCount" ) or 0
	local staticMove = gameBoardLogic:leagueCall( "getExpectedMove" ) or gameBoardLogic:leagueCall( "getStaticMoveCount" ) 
    local diffRef = self:__calculateMaxDiffMove(gameBoardLogic, moveCount, staticMove)
    local result = {}
    if diffRef and diffRef.maxDiffMove then
        local maxDiffMove = diffRef.maxDiffMove

        result.progress =  (moveCount-maxDiffMove)/staticMove
        result.maxDiffMove = maxDiffMove
        result.detail = diffRef.detail
        pcall(function()
            result.progressV1 = LevelProgressLogic:getProgressV1()
        end)

        result.expect = moveCount/staticMove
        if result.expect == 0 then
            result.deviation = 0
        elseif result.expect < result.progress then
            result.deviation = (result.expect - result.progress) / result.progress
        else
            result.deviation = (result.expect - result.progress) / result.expect 
        end
    end
    return result
end


return UBFuuuDiffLogic
